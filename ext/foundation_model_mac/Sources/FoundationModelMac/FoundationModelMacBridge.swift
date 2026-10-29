import Foundation
import FoundationModels

/// Calls ``unavailableReason()`` from C as `foundation_model_mac_unavailable_reason`.
///
/// - Returns: `NULL` when the system language model is available, otherwise a newly allocated NUL-terminated UTF-8
///   string owned by the caller. Release it with ``cFree(_:)``.
@c(foundation_model_mac_unavailable_reason)
public func cUnavailableReason() -> UnsafeMutablePointer<CChar>? {
    unavailableReason().map { strdup($0)! }
}

/// Creates a `LanguageModelSession` on the default system language model, exposed to C as
/// `foundation_model_mac_session_new`.
///
/// - Parameter instructions: A NUL-terminated UTF-8 string that steers every response, or `NULL`.
/// - Returns: An opaque retained session. Release it with ``cSessionFree(_:)``.
@c(foundation_model_mac_session_new)
public func cSessionNew(_ instructions: UnsafePointer<CChar>?) -> UnsafeMutableRawPointer {
    let session = LanguageModelSession(instructions: instructions.map { String(cString: $0) })
    return Unmanaged.passRetained(session).toOpaque()
}

/// Releases a session returned by ``cSessionNew(_:)``, exposed to C as `foundation_model_mac_session_free`.
///
/// - Parameter session: The opaque session.
@c(foundation_model_mac_session_free)
public func cSessionFree(_ session: UnsafeMutableRawPointer) {
    Unmanaged<LanguageModelSession>.fromOpaque(session).release()
}

/// Starts a ``ChunkStream`` from C as `foundation_model_mac_stream_start`.
///
/// - Parameters:
///   - session: An opaque session from ``cSessionNew(_:)``.
///   - prompt: A NUL-terminated UTF-8 prompt.
///   - stops: `stopCount` NUL-terminated UTF-8 stop strings, or `NULL` when `stopCount` is `0`.
///   - stopCount: The number of stop strings.
/// - Returns: An opaque retained stream. Release it with ``cStreamFree(_:)`` after ``cStreamNext(_:_:)`` returns `NULL`.
@c(foundation_model_mac_stream_start)
public func cStreamStart(
    _ session: UnsafeMutableRawPointer,
    _ prompt: UnsafePointer<CChar>,
    _ stops: UnsafePointer<UnsafePointer<CChar>>?,
    _ stopCount: Int
) -> UnsafeMutableRawPointer {
    let stream = ChunkStream(
        session: Unmanaged<LanguageModelSession>.fromOpaque(session).takeUnretainedValue(),
        prompt: String(cString: prompt),
        stops: UnsafeBufferPointer(start: stops, count: stopCount).map { String(cString: $0) }
    )
    return Unmanaged.passRetained(stream).toOpaque()
}

/// Calls ``ChunkStream/next()`` from C as `foundation_model_mac_stream_next`.
///
/// - Parameters:
///   - stream: An opaque stream from ``cStreamStart(_:_:_:_:)``.
///   - error: Receives a newly allocated error description when generation fails, or `NULL` otherwise.
/// - Returns: A newly allocated NUL-terminated UTF-8 chunk, or `NULL` once the stream has ended. Release every returned
///   buffer and every error description with ``cFree(_:)``.
@c(foundation_model_mac_stream_next)
public func cStreamNext(
    _ stream: UnsafeMutableRawPointer,
    _ error: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>
) -> UnsafeMutablePointer<CChar>? {
    error.pointee = nil
    do {
        let stream = Unmanaged<ChunkStream>.fromOpaque(stream).takeUnretainedValue()
        return try stream.next().map { strdup($0)! }
    } catch let failure {
        error.pointee = strdup("\(failure)")!
        return nil
    }
}

/// Calls ``ChunkStream/cancel()`` from C as `foundation_model_mac_stream_cancel`, from any thread.
///
/// - Parameter stream: An opaque stream from ``cStreamStart(_:_:_:_:)``.
@c(foundation_model_mac_stream_cancel)
public func cStreamCancel(_ stream: UnsafeMutableRawPointer) {
    Unmanaged<ChunkStream>.fromOpaque(stream).takeUnretainedValue().cancel()
}

/// Releases a stream returned by ``cStreamStart(_:_:_:_:)``, exposed to C as `foundation_model_mac_stream_free`.
///
/// - Parameter stream: The opaque stream.
@c(foundation_model_mac_stream_free)
public func cStreamFree(_ stream: UnsafeMutableRawPointer) {
    Unmanaged<ChunkStream>.fromOpaque(stream).release()
}

/// Releases a buffer returned by the functions above, exposed to C as `foundation_model_mac_free`.
///
/// - Parameter ptr: The buffer to release, or `nil`.
@c(foundation_model_mac_free)
public func cFree(_ ptr: UnsafeMutablePointer<CChar>?) {
    free(ptr)
}
