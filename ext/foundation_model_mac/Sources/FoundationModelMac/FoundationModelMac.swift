import Foundation
import FoundationModels

@MainActor
func performGenerate(prompt: String, instructions: String?) -> String {
    let session: LanguageModelSession
    if let instructions = instructions, !instructions.isEmpty {
        session = LanguageModelSession(instructions: Instructions(instructions))
    } else {
        session = LanguageModelSession()
    }

    let semaphore = DispatchSemaphore(value: 0)
    var result = ""

    Task {
        defer { semaphore.signal() }
        do {
            let response = try await session.respond(to: Prompt(prompt))
            result = response.content
        } catch {
            result = ""
        }
    }

    semaphore.wait()
    return result
}

private let sessionRegistryQueue = DispatchQueue(label: "rb.foundation_model_mac.sessions")
nonisolated(unsafe) private var sessionRegistry: [UInt64: LanguageModelSession] = [:]
nonisolated(unsafe) private var nextSessionHandle: UInt64 = 1

@MainActor
func sessionCreate(instructions: String?) -> UInt64 {
    let session: LanguageModelSession
    if let instructions = instructions, !instructions.isEmpty {
        session = LanguageModelSession(instructions: Instructions(instructions))
    } else {
        session = LanguageModelSession()
    }
    return sessionRegistryQueue.sync { () -> UInt64 in
        let handle = nextSessionHandle
        nextSessionHandle += 1
        sessionRegistry[handle] = session
        return handle
    }
}

@MainActor
func sessionRespond(handle: UInt64, prompt: String) -> String {
    guard let session = sessionRegistryQueue.sync(execute: { sessionRegistry[handle] }) else {
        return ""
    }

    var result = ""
    let semaphore = DispatchSemaphore(value: 0)
    Task {
        defer { semaphore.signal() }
        do {
            let response = try await session.respond(to: Prompt(prompt))
            result = response.content
        } catch {
            result = ""
        }
    }
    semaphore.wait()
    return result
}

func sessionDestroy(handle: UInt64) {
    sessionRegistryQueue.sync { _ = sessionRegistry.removeValue(forKey: handle) }
}

func sessionExists(handle: UInt64) -> Bool {
    sessionRegistryQueue.sync { sessionRegistry[handle] != nil }
}
