import Foundation
import FoundationModels
import WorkflowCore

@MainActor enum OnDeviceIntelligence {
    static var status: String {
        guard #available(macOS 26.0, *) else { return "Requires macOS 26 or later." }
        switch SystemLanguageModel.default.availability {
        case .available: return "Apple on-device model available"
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible: return "This device is not eligible for Apple Intelligence."
            case .appleIntelligenceNotEnabled: return "Apple Intelligence is not enabled."
            case .modelNotReady: return "Apple’s on-device model is not ready."
            @unknown default: return "Apple’s on-device model is unavailable."
            }
        }
    }

    static func draft(description: String) async throws -> Workflow {
        try AssistantSettings.requireModel()
        guard #available(macOS 26.0, *), SystemLanguageModel.default.isAvailable else { throw StudioError.message(status) }
        guard !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, description.count <= 1500 else { throw StudioError.message("Describe a shortcut in 1–1,500 characters.") }
        try Task.checkCancellation()
        let definitions = ActionCatalog.definitions.filter { $0.kind != "onDeviceModel" } + ActionCatalog.definitions.filter { $0.kind == "onDeviceModel" }
        let string = DynamicGenerationSchema(type: String.self)
        let kind = DynamicGenerationSchema(name: "Kind", anyOf: definitions.map(\.kind))
        let planSchema = try GenerationSchema(root: DynamicGenerationSchema(name: "ActionPlan", properties: [
            .init(name: "kinds", description: "Ordered action identifiers that implement the user request. Do not generate parameters yet.", schema: DynamicGenerationSchema(arrayOf: kind, minimumElements: 1, maximumElements: 20))
        ]), dependencies: [])
        let catalog = definitions.map { $0.kind + ": " + $0.title }.joined(separator: "\n")
        let planner = LanguageModelSession(model: SystemLanguageModel.default, instructions: "Select the shortest ordered action plan that satisfies the request. A shortcut name is metadata, never a setVariable action. Do not add input, setVariable, or comment unless necessary. Honor any explicit list of allowed actions. For literal text use text, for output use show. Use onDeviceModel only when model inference is requested. Balance if/else/endIf and repeat/endRepeat. Catalog:\n" + catalog)
        let plan = try await planner.respond(to: description, schema: planSchema, options: GenerationOptions(temperature: 0, maximumResponseTokens: 256))
        try Task.checkCancellation()
        struct Plan: Decodable { let kinds: [String] }
        let kinds = try JSONDecoder().decode(Plan.self, from: Data(plan.content.jsonString.utf8)).kinds
        guard (1...20).contains(kinds.count), kinds.allSatisfy({ ActionCatalog.definition($0) != nil }) else { throw StudioError.message("Model produced an invalid action plan.") }
        // The second pass cannot invent action kinds or parameter keys: each step
        // has its own schema, derived from the selected public catalog definition.
        var properties: [DynamicGenerationSchema.Property] = [.init(name: "name", description: "Shortcut name requested by the user.", schema: string)]
        for (index, kind) in kinds.enumerated() {
            let definition = ActionCatalog.definition(kind)!
            if definition.parameters.isEmpty { continue }
            let fields = definition.parameters.map { parameter -> DynamicGenerationSchema.Property in
                var value = string
                if !parameter.choices.isEmpty { value = DynamicGenerationSchema(name: "Choice\(index)_\(parameter.key)", anyOf: parameter.choices) }
                if parameter.key == "input" {
                    // Drafts use the standard pipeline: initial shortcut input, then
                    // preceding output. Richer bindings remain editable in Studio.
                    value = DynamicGenerationSchema(name: "Input\(index)", anyOf: [index == 0 ? "{{input}}" : "{{previous}}"])
                }
                return .init(name: parameter.key, description: "\(parameter.title) for \(definition.title). Default: \(parameter.defaultValue). Preserve user-requested literal text exactly. Only references like {{previous}} and {{input}}; no dotted references.", schema: value)
            }
            properties.append(.init(name: "step\(index + 1)", description: "Parameters for action \(index + 1): \(definition.title)", schema: DynamicGenerationSchema(name: "Step\(index + 1)", properties: fields)))
        }
        let schema = try GenerationSchema(root: DynamicGenerationSchema(name: "WorkflowParameters", description: "Implement exactly: \(description)", properties: properties), dependencies: [])
        let session = LanguageModelSession(model: SystemLanguageModel.default, instructions: "Fill the planned workflow parameters to satisfy the user request. Preserve quoted text exactly. Use {{previous}} for the prior action output and {{input}} for shortcut input; never dot syntax. Text actions create literal text. Split and Combine use \\n for line separators. No actions are executed.")
        let response = try await session.respond(to: description, schema: schema, options: GenerationOptions(temperature: 0, maximumResponseTokens: 2048))
        try Task.checkCancellation()
        guard let object = try JSONSerialization.jsonObject(with: Data(response.content.jsonString.utf8)) as? [String: Any], let name = object["name"] as? String else { throw StudioError.message("Model returned invalid workflow parameters.") }
        var actions: [[String: Any]] = []
        for (index, kind) in kinds.enumerated() {
            let empty = ActionCatalog.definition(kind)!.parameters.isEmpty
            guard let parameters = empty ? [:] : object["step\(index + 1)"] as? [String: String] else { throw StudioError.message("Model omitted a workflow step.") }
            actions.append(["kind": kind, "parameters": parameters.map { ["key": $0.key, "value": $0.value] }])
        }
        return try ModelDraft.decode(JSONSerialization.data(withJSONObject: ["name": name, "actions": actions]))
    }

    static func generate(prompt: String, instructions: String, onSnapshot: (String) -> Void) async throws -> String {
        try AssistantSettings.requireModel()
        guard #available(macOS 26.0, *) else { throw StudioError.message(status) }
        guard SystemLanguageModel.default.isAvailable else { throw StudioError.message(status) }
        guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw StudioError.message("Enter a model prompt.") }
        guard prompt.count + instructions.count <= 6000 else { throw StudioError.message("Model prompt and instructions exceed 6,000 characters. Shorten the input.") }
        try Task.checkCancellation()
        // Explicitly select the on-device model, with no tools and no cloud fallback.
        // Each action starts a fresh session; the workflow chooses its inputs.
        let session = LanguageModelSession(model: SystemLanguageModel.default, instructions: instructions)
        var result = ""
        for try await snapshot in session.streamResponse(to: prompt, options: GenerationOptions(maximumResponseTokens: 1024)) {
            try Task.checkCancellation()
            // Foundation Models streams cumulative snapshots, not token deltas.
            try AssistantSettings.requireModel()
            result = snapshot.content
            onSnapshot(result)
        }
        try Task.checkCancellation()
        return result
    }
}
