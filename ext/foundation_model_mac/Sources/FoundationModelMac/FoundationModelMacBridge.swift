import Foundation

@c
public func foundation_model_mac_perform(_ input: UnsafePointer<CChar>) -> UnsafeMutablePointer<CChar> {
    let s = String(cString: input)
    let result = foundation_model_mac_perform(s)
    return strdup(result)!
}

@c
public func foundation_model_mac_free(_ ptr: UnsafeMutablePointer<CChar>?) {
    free(ptr)
}
