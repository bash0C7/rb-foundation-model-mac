import Foundation
import FoundationModels

guard let prompt = CommandLine.arguments.dropFirst().first else {
    FileHandle.standardError.write(Data("usage: xcrun swift examples/foundation_model_mac.swift <prompt>\n".utf8))
    exit(1)
}

if case .unavailable(let reason) = SystemLanguageModel.default.availability {
    FileHandle.standardError.write(Data("Apple Intelligence unavailable: \(reason)\n".utf8))
    exit(1)
}

let session = LanguageModelSession()
var previous = ""
for try await snapshot in session.streamResponse(to: prompt) {
    print(snapshot.content.dropFirst(previous.count), terminator: "")
    fflush(stdout)
    previous = snapshot.content
}
print()
