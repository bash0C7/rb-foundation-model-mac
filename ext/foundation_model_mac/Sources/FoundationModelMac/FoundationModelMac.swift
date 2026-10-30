import Dispatch
import FoundationModels
import os

/// Reports why the on-device system language model cannot be used.
///
/// - Returns: The name of the `SystemLanguageModel.Availability.UnavailableReason` case, such as
///   `"appleIntelligenceNotEnabled"`, or `nil` when the model is available.
func unavailableReason() -> String? {
    switch SystemLanguageModel.default.availability {
    case .available: nil
    case .unavailable(let reason): "\(reason)"
    }
}

/// Streams the response to one prompt as incremental text chunks to a thread that polls ``next()``.
///
/// A background task iterates `LanguageModelSession.streamResponse(to:options:)` and queues the text each cumulative
/// snapshot adds to the previous one. Once the response contains a stop string, or after ``cancel()``, the task is
/// cancelled and the response stream runs to its end without queueing more text. ``next()`` reports the end only
/// after that, so the session accepts its next prompt as soon as ``next()`` returns `nil`.
///
/// The request runs under `TranscriptErrorHandlingPolicy.preserveTranscript`. A stopped response stays in the
/// transcript with all the text the model generated before it stopped, which can extend past the last chunk
/// ``next()`` returned. When the response fails with any error other than cancellation before it is stopped, the
/// transcript is restored to its state before the prompt. ``next()`` throws every error other than cancellation.
final class ChunkStream: Sendable {
    private struct State {
        var chunks: [String] = []
        var cancelled = false
        var finished = false
        var error: (any Error)?
        var task: Task<Void, Never>?
    }

    private let state = OSAllocatedUnfairLock(initialState: State())
    private let changed = DispatchSemaphore(value: 0)

    /// Starts generating the response to `prompt`.
    ///
    /// - Parameters:
    ///   - session: The session that keeps the conversation.
    ///   - prompt: The prompt text.
    ///   - stops: Strings that end generation as soon as the response contains any of them. The chunk that completes
    ///     a stop string is still delivered.
    init(session: LanguageModelSession, prompt: String, stops: [String]) {
        let task = Task { [self] in
            let failure: (any Error)?
            do {
                try await generate(session: session, prompt: prompt, stops: stops)
                failure = nil
            } catch {
                failure = error
            }
            state.withLock {
                $0.finished = true
                $0.error = failure
            }
            changed.signal()
        }
        state.withLock { $0.task = task }
    }

    private func generate(session: LanguageModelSession, prompt: String, stops: [String]) async throws {
        let transcript = session.transcript
        session.transcriptErrorHandlingPolicy = .preserveTranscript
        defer { session.transcriptErrorHandlingPolicy = nil }
        do {
            try await forward(session.streamResponse(to: prompt), stops: stops)
        } catch is CancellationError {
        } catch {
            if !state.withLock({ $0.cancelled }) {
                session.transcript = transcript
            }
            throw error
        }
    }

    private func forward(_ response: LanguageModelSession.ResponseStream<String>, stops: [String]) async throws {
        var previous = ""
        for try await snapshot in response {
            let text = snapshot.content
            let added = text.utf8.starts(with: previous.utf8)
                ? String(decoding: text.utf8.dropFirst(previous.utf8.count), as: UTF8.self)
                : text
            previous = text
            let cancelled = state.withLock { state in
                if !state.cancelled {
                    if !added.isEmpty {
                        state.chunks.append(added)
                    }
                    state.cancelled = stops.contains(where: text.contains)
                }
                return state.cancelled
            }
            changed.signal()
            if cancelled {
                withUnsafeCurrentTask { $0?.cancel() }
            }
        }
    }

    /// Blocks until the next chunk is available or the response stream has ended.
    ///
    /// - Returns: The next chunk, or `nil` once the response stream has ended.
    /// - Throws: The error the response stream threw, other than cancellation.
    func next() throws -> String? {
        while true {
            let (chunk, finished, error) = state.withLock { state in
                (state.chunks.isEmpty ? nil : state.chunks.removeFirst(), state.finished, state.error)
            }
            if let chunk {
                return chunk
            }
            if finished {
                if let error {
                    throw error
                }
                return nil
            }
            changed.wait()
        }
    }

    /// Cancels generation and drops every chunk not yet returned by ``next()``.
    ///
    /// Safe to call from any thread. A blocked ``next()`` keeps waiting until the response stream has ended.
    func cancel() {
        let task = state.withLock { state in
            state.cancelled = true
            state.chunks.removeAll()
            return state.task
        }
        task?.cancel()
        changed.signal()
    }
}
