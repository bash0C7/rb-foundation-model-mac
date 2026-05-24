import Foundation
import FoundationModels
import os

final class FMMSession: @unchecked Sendable {
    let session: LanguageModelSession
    init(instructions: String?) {
        if let i = instructions, !i.isEmpty {
            self.session = LanguageModelSession(
                model: SystemLanguageModel.default,
                instructions: i
            )
        } else {
            self.session = LanguageModelSession(model: SystemLanguageModel.default)
        }
    }
}

private final class Box<T>: @unchecked Sendable {
    var value: T
    init(_ value: T) { self.value = value }
}

final class FMMStream: @unchecked Sendable {
    struct State {
        var queue: [String] = []
        var done: Bool = false
        var caught: Error? = nil
        var cancelled: Bool = false
    }
    let state = OSAllocatedUnfairLock<State>(initialState: State())
    let signal = DispatchSemaphore(value: 0)
    var task: Task<Void, Never>? = nil

    func enqueue(_ chunk: String) {
        state.withLock {
            if $0.cancelled { return }
            $0.queue.append(chunk)
        }
        signal.signal()
    }

    func finish(_ err: Error?) {
        state.withLock {
            $0.done = true
            $0.caught = err
        }
        signal.signal()
    }

    func cancel() {
        task?.cancel()
        state.withLock {
            $0.cancelled = true
            $0.done = true
        }
        signal.signal()
    }

    func dequeue() -> (chunk: String?, done: Bool, caught: Error?) {
        return state.withLock { s in
            let c = s.queue.isEmpty ? nil : s.queue.removeFirst()
            return (c, s.done, s.caught)
        }
    }
}

@c
public func fmm_availability_check() -> UnsafeMutablePointer<CChar>? {
    switch SystemLanguageModel.default.availability {
    case .available:
        return nil
    case .unavailable(let reason):
        return strdup("\(reason)")
    }
}

@c
public func fmm_session_new(
    _ instructions: UnsafePointer<CChar>?,
    _ error_out: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>
) -> UnsafeMutableRawPointer? {
    error_out.pointee = nil
    let instr = instructions.map { String(cString: $0) }
    let s = FMMSession(instructions: instr)
    return Unmanaged.passRetained(s).toOpaque()
}

@c
public func fmm_session_free(_ ptr: UnsafeMutableRawPointer) {
    Unmanaged<FMMSession>.fromOpaque(ptr).release()
}

@c
public func fmm_session_respond(
    _ ptr: UnsafeMutableRawPointer,
    _ prompt: UnsafePointer<CChar>,
    _ error_out: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>
) -> UnsafeMutablePointer<CChar>? {
    error_out.pointee = nil
    let s = Unmanaged<FMMSession>.fromOpaque(ptr).takeUnretainedValue()
    let p = String(cString: prompt)

    let sem = DispatchSemaphore(value: 0)
    let outBox = Box<Result<String, Error>?>(nil)
    Task {
        do {
            let r = try await s.session.respond(to: p)
            outBox.value = .success(r.content)
        } catch {
            outBox.value = .failure(error)
        }
        sem.signal()
    }
    sem.wait()

    switch outBox.value! {
    case .success(let txt):
        return strdup(txt)
    case .failure(let e):
        error_out.pointee = strdup("\(e)")
        return nil
    }
}

@c
public func fmm_stream_start(
    _ ptr: UnsafeMutableRawPointer,
    _ prompt: UnsafePointer<CChar>,
    _ stop_strings: UnsafePointer<UnsafePointer<CChar>?>?,
    _ stop_count: Int32
) -> UnsafeMutableRawPointer {
    let s = Unmanaged<FMMSession>.fromOpaque(ptr).takeUnretainedValue()
    let p = String(cString: prompt)
    let stream = FMMStream()

    var stops: [String] = []
    if let arr = stop_strings, stop_count > 0 {
        for i in 0..<Int(stop_count) {
            if let cstr = arr[i] {
                stops.append(String(cString: cstr))
            }
        }
    }

    let task = Task {
        var caught: Error? = nil
        do {
            var prev = ""
            var cumulative = ""
            for try await partial in s.session.streamResponse(to: p) {
                if Task.isCancelled { break }
                let cum = partial.content
                var chunk: String? = nil
                if cum.hasPrefix(prev) && cum.count > prev.count {
                    chunk = String(cum.dropFirst(prev.count))
                    prev = cum
                } else if cum != prev {
                    chunk = cum
                    prev = cum
                }
                if let c = chunk {
                    cumulative += c
                    stream.enqueue(c)
                    if !stops.isEmpty {
                        for stop in stops {
                            if cumulative.contains(stop) {
                                stream.finish(nil)
                                return
                            }
                        }
                    }
                }
            }
        } catch {
            caught = error
        }
        stream.finish(caught)
    }
    stream.task = task

    return Unmanaged.passRetained(stream).toOpaque()
}

// Returns the next chunk as a strdup'd CString, or NULL when the stream
// has finished. Errors are surfaced via error_out (also indicates done).
@c
public func fmm_stream_next(
    _ ptr: UnsafeMutableRawPointer,
    _ error_out: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>
) -> UnsafeMutablePointer<CChar>? {
    error_out.pointee = nil
    let stream = Unmanaged<FMMStream>.fromOpaque(ptr).takeUnretainedValue()

    while true {
        let (chunk, isDone, caught) = stream.dequeue()
        if let c = chunk {
            return strdup(c)
        }
        if isDone {
            if let e = caught {
                error_out.pointee = strdup("\(e)")
            }
            return nil
        }
        stream.signal.wait()
    }
}

@c
public func fmm_stream_free(_ ptr: UnsafeMutableRawPointer) {
    Unmanaged<FMMStream>.fromOpaque(ptr).release()
}

@c
public func fmm_stream_cancel(_ ptr: UnsafeMutableRawPointer) {
    let stream = Unmanaged<FMMStream>.fromOpaque(ptr).takeUnretainedValue()
    stream.cancel()
}
