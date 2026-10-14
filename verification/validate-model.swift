import Foundation

@MainActor final class ValidationHost: WorkflowHost {
    var workflows: [Workflow] = []
    var storage: [UUID: [String: WorkflowValue]] = [:]
    var snapshots = 0
    func perform(_ kind: String, parameters: [String: WorkflowValue], input: WorkflowValue) async throws -> WorkflowValue {
        if kind == "show" { return input }
        if kind == "onDeviceModel" { return .text(try await OnDeviceIntelligence.generate(prompt: parameters["prompt"]?.text ?? "", instructions: parameters["instructions"]?.text ?? "") { _ in self.snapshots += 1 }) }
        throw StudioError.message("Unapproved validation host action: \(kind)")
    }
    func workflow(named: String) -> Workflow? { workflows.first { $0.name == named } }
    func persistStorage(_ value: [String: WorkflowValue], workflowID: UUID) throws { storage[workflowID] = value }
    func stepStarted(_ actionID: UUID, title: String) {}
    func stepFinished(_ actionID: UUID, output: WorkflowValue) {}
}
@main struct ModelValidation {
    @MainActor static func main() async {
        setbuf(stdout, nil)
        let host = ValidationHost()
        print("Availability: \(OnDeviceIntelligence.status)")
        do {
            let w = Workflow(actions: [WorkflowAction(kind: "onDeviceModel", parameters: ["prompt": "What is 2 plus 3? Reply in one short sentence.", "instructions": "Be concise and accurate."])])
            let value = try await WorkflowEngine(host: host).run(w)
            guard host.snapshots > 0, value.text.contains("5") || value.text.lowercased().contains("five") else { throw StudioError.message("Arithmetic validation failed.") }
            print("PASS model action: \(host.snapshots) snapshots; \(value.text)")
            do { _ = try await OnDeviceIntelligence.generate(prompt: "", instructions: "") { _ in }; throw StudioError.message("Empty prompt was accepted.") }
            catch let error as StudioError { guard error.localizedDescription.contains("Enter a model prompt") else { throw error }; print("PASS empty prompt rejected") }
            let descriptions = [
                "Create a shortcut named Model Draft Check. Create literal Text containing exactly \"Hello from the on-device draft\", then Show Result using previous output. Use only text and show actions.",
                "Create a shortcut named Text List Check. Split shortcut input into lines using split with input {{input}}, remove duplicates using unique, combine using combine, and show using show."
            ]
            for (index, description) in descriptions.enumerated() {
                let draft = try await OnDeviceIntelligence.draft(description: description)
                print("Draft generated: \(draft.actions.map { $0.kind + String(describing: $0.parameters) })")
                let allowed = index == 0 ? Set(["text", "show"]) : Set(["split", "unique", "combine", "show"])
                guard draft.actions.allSatisfy({ allowed.contains($0.kind) }) else { throw StudioError.message("Draft did not follow requested action set: \(draft.actions.map(\.kind))") }
                let input: WorkflowValue = index == 0 ? .null : .text("One\nOne\nTwo")
                let result = try await WorkflowEngine(host: host).run(draft, input: input)
                let expected = index == 0 ? "Hello from the on-device draft" : "One\nTwo"
                guard result.text == expected else { throw StudioError.message("Draft output differs: \(result.text)") }
                print("PASS draft \(index + 1): \(draft.actions.map(\.kind)); result \(result.text.debugDescription)")
            }
            let task = Task { @MainActor in try await OnDeviceIntelligence.generate(prompt: "Write a long story about a friendly robot.", instructions: "Be creative.") { _ in } }
            task.cancel()
            do { _ = try await task.value; throw StudioError.message("Cancelled request completed.") } catch is CancellationError { print("PASS model cancellation") }
            var streamTask: Task<String, Error>?
            var cancelSnapshots = 0
            streamTask = Task { @MainActor in
                try await OnDeviceIntelligence.generate(prompt: "Write a detailed story about a robot learning to garden.", instructions: "Write a story with several paragraphs.") { _ in
                    cancelSnapshots += 1
                    if cancelSnapshots >= 2 { streamTask?.cancel() }
                }
            }
            do { _ = try await streamTask!.value; throw StudioError.message("Streaming cancellation did not stop generation.") }
            catch is CancellationError { guard cancelSnapshots >= 2 else { throw StudioError.message("Cancellation happened before streaming.") }; print("PASS cancellation during streaming after \(cancelSnapshots) snapshots") }
            streamTask = nil
            print("VALIDATION PASS")
        } catch { print("VALIDATION FAIL: \(error)"); exit(1) }
    }
}
