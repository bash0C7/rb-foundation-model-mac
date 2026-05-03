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
