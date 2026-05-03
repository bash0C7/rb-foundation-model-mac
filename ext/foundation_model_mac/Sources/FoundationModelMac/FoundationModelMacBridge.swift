import Foundation

@c @MainActor
public func foundation_model_mac_generate(
    _ prompt: UnsafePointer<CChar>,
    _ instructions: UnsafePointer<CChar>?
) -> UnsafeMutablePointer<CChar> {
    let promptStr = String(cString: prompt)
    let instructionsStr: String?
    if let instructions = instructions {
        instructionsStr = String(cString: instructions)
    } else {
        instructionsStr = nil
    }
    let result = performGenerate(prompt: promptStr, instructions: instructionsStr)
    return strdup(result)!
}

@c
public func foundation_model_mac_free(_ ptr: UnsafeMutablePointer<CChar>?) {
    free(ptr)
}

@c
@MainActor
public func foundation_model_mac_session_create(
    _ instructions: UnsafePointer<CChar>?
) -> UInt64 {
    let instructionsStr: String?
    if let instructions = instructions {
        instructionsStr = String(cString: instructions)
    } else {
        instructionsStr = nil
    }
    return sessionCreate(instructions: instructionsStr)
}

@c
@MainActor
public func foundation_model_mac_session_respond(
    _ handle: UInt64,
    _ prompt: UnsafePointer<CChar>
) -> UnsafeMutablePointer<CChar> {
    let promptStr = String(cString: prompt)
    let result = sessionRespond(handle: handle, prompt: promptStr)
    return strdup(result)!
}

@c
public func foundation_model_mac_session_destroy(_ handle: UInt64) {
    sessionDestroy(handle: handle)
}

@c
public func foundation_model_mac_session_exists(_ handle: UInt64) -> Bool {
    sessionExists(handle: handle)
}
