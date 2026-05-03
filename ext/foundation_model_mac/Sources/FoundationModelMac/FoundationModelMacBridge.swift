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
