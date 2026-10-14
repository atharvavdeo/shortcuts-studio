import Foundation

/// Model output is untrusted authoring data. Identity and persisted state are local.
public enum ModelDraft {
    private struct Draft: Decodable {
        var name: String
        var actions: [Action]
        struct Action: Decodable {
            var kind: String
            var parameters: [Parameter]
        }
        struct Parameter: Decodable { var key: String; var value: String }
    }
    public static func decode(_ data: Data) throws -> Workflow {
        guard data.count <= 100_000 else { throw StudioError.message("Model draft exceeds 100 KB.") }
        let draft = try JSONDecoder().decode(Draft.self, from: data)
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 120, (1...20).contains(draft.actions.count) else { throw StudioError.message("Model draft needs a name and 1–20 actions.") }
        var actions: [WorkflowAction] = []
        for item in draft.actions {
            guard let definition = ActionCatalog.definition(item.kind) else { throw StudioError.message("Model invented an unsupported action: \(item.kind).") }
            var action = definition.action
            var keys = Set<String>()
            for parameter in item.parameters {
                guard keys.insert(parameter.key).inserted, let spec = definition.parameters.first(where: { $0.key == parameter.key }), parameter.value.count <= 6000 else { throw StudioError.message("Model supplied an invalid parameter for \(item.kind).") }
                guard spec.choices.isEmpty || spec.choices.contains(parameter.value) else { throw StudioError.message("Model supplied an invalid choice for \(spec.title).") }
                guard !parameter.value.contains("{{output:") else { throw StudioError.message("Model draft contains an invented action reference.") }
                let regex = try NSRegularExpression(pattern: "\\{\\{([^{}]+)\\}\\}")
                let source = parameter.value as NSString
                let matches = regex.matches(in: parameter.value, range: NSRange(location: 0, length: source.length))
                for match in matches {
                    let token = source.substring(with: match.range(at: 1))
                    let plain = ["previous", "input", "repeatItem", "repeatIndex"].contains(token)
                    let named = (token.hasPrefix("variable:") || token.hasPrefix("storage:")) && !token.split(separator: ":").dropFirst().joined().isEmpty
                    guard plain || named else { throw StudioError.message("Model invented a value reference: {{\(token)}}.") }
                }
                let remainder = regex.stringByReplacingMatches(in: parameter.value, range: NSRange(location: 0, length: source.length), withTemplate: "")
                guard !remainder.contains("{{"), !remainder.contains("}}") else { throw StudioError.message("Model draft contains malformed reference syntax.") }
                action.parameters[parameter.key] = parameter.value
            }
            actions.append(action)
        }
        let workflow = Workflow(name: name, actions: actions)
        let issues = WorkflowValidator.validate(workflow)
        guard issues.isEmpty else { throw StudioError.message("Model draft has invalid control flow: \(issues.map(\.message).joined(separator: " "))") }
        return workflow
    }
}
