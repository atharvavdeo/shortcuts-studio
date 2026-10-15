import Foundation
import FoundationModels
@main struct ModelProbe {
    static func main() async {
        guard #available(macOS 26.0, *) else { print("unavailable: requires macOS 26"); return }
        let model = SystemLanguageModel.default
        print("availability: \(model.availability)")
        guard model.isAvailable else { return }
        do {
            let session = LanguageModelSession(model: model, instructions: "Answer concisely.")
            var snapshots = 0
            var final = ""
            for try await snapshot in session.streamResponse(to: "What is 2 plus 3? Reply in one short sentence.", options: GenerationOptions(maximumResponseTokens: 64)) {
                snapshots += 1; final = snapshot.content
            }
            print("snapshots: \(snapshots)"); print("response: \(final)")
        } catch { print("generation failed: \(error)") }
    }
}
