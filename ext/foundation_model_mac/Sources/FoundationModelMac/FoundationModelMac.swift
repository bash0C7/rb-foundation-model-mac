import Foundation
import FoundationModels

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

private struct CallbackHolder: @unchecked Sendable {
    let cb: @convention(c) (UnsafePointer<CChar>) -> Void
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
public func fmm_session_stream(
    _ ptr: UnsafeMutableRawPointer,
    _ prompt: UnsafePointer<CChar>,
    _ callback: @convention(c) (UnsafePointer<CChar>) -> Void,
    _ error_out: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>
) {
    error_out.pointee = nil
    let s = Unmanaged<FMMSession>.fromOpaque(ptr).takeUnretainedValue()
    let p = String(cString: prompt)
    let holder = CallbackHolder(cb: callback)

    let sem = DispatchSemaphore(value: 0)
    let caughtBox = Box<Error?>(nil)
    Task {
        do {
            var prev = ""
            for try await partial in s.session.streamResponse(to: p) {
                let cum = partial.content
                if cum.hasPrefix(prev) && cum.count > prev.count {
                    let inc = String(cum.dropFirst(prev.count))
                    inc.withCString { holder.cb($0) }
                    prev = cum
                } else if cum != prev {
                    cum.withCString { holder.cb($0) }
                    prev = cum
                }
            }
        } catch {
            caughtBox.value = error
        }
        sem.signal()
    }
    sem.wait()

    if let e = caughtBox.value {
        error_out.pointee = strdup("\(e)")
    }
}
