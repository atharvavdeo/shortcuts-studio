import Foundation
import WorkflowCore

@MainActor final class ExampleHost: WorkflowHost {
    var workflows: [Workflow] = []
    var storage: [UUID: [String: WorkflowValue]] = [:]
    func perform(_ kind: String, parameters: [String: WorkflowValue], input: WorkflowValue) async throws -> WorkflowValue {
        throw StudioError.message("This example does not enable platform actions: \(kind)")
    }
    func workflow(named name: String) -> Workflow? { workflows.first { $0.name == name } }
    func persistStorage(_ values: [String: WorkflowValue], workflowID: UUID) throws { storage[workflowID] = values }
    func stepStarted(_ actionID: UUID, title: String) { print("→ \(title)") }
    func stepFinished(_ actionID: UUID, output: WorkflowValue) { print("  \(output.typeName): \(output.text)") }
}
@main struct EngineClient {
    @MainActor static func main() async throws {
        let host = ExampleHost() // Keep the host alive: WorkflowEngine holds it unowned.
        let workflow = Workflow(name: "Swift API Example", actions: [
            WorkflowAction(kind: "text", parameters: ["text": "Hello, world!"]),
            WorkflowAction(kind: "uppercase", parameters: ["input": "{{previous}}", "case": "uppercase"])
        ])
        let issues = WorkflowValidator.validate(workflow)
        guard issues.isEmpty else { throw StudioError.message(issues.map(\.message).joined(separator: " ")) }
        let result = try await WorkflowEngine(host: host).run(workflow)
        guard result == .text("HELLO, WORLD!") else { throw StudioError.message("Unexpected example output") }
        print("EXAMPLE PASS: \(result.text)")
    }
}
