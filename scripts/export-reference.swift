import Foundation

@main struct ExportReference {
    static func main() throws {
        let root = URL(fileURLWithPath: CommandLine.arguments[1])
        let docs = root.appendingPathComponent("docs")
        func cell(_ text: String) -> String { text.replacingOccurrences(of: "|", with: "\\|").replacingOccurrences(of: "\n", with: "<br>") }
        var markdown = "# Action reference\n\nGenerated from `ActionCatalog.definitions`. Regenerate with `bash scripts/generate-reference.sh`. This is the current catalog, not Apple’s full action catalog.\n\n"
        markdown += "\(ActionCatalog.definitions.count) action definitions. Parameter values are authored as strings and resolved by the interpreter. Omitted values may differ from editor defaults when constructing an action manually: use `definition.action` to start with defaults.\n\n"
        var records: [[String: Any]] = []
        for d in ActionCatalog.definitions {
            markdown += "## \(d.title) (`\(d.kind)`)\n\nCategory: \(d.category).\n\n\(d.detail)\n\n"
            if d.parameters.isEmpty { markdown += "No parameters.\n\n" }
            else {
                markdown += "| Key | Editor label | Default | Choices |\n|---|---|---|---|\n"
                for p in d.parameters { markdown += "| `\(p.key)` | \(cell(p.title)) | `\(cell(p.defaultValue))` | \(cell(p.choices.joined(separator: ", "))) |\n" }
                markdown += "\n"
            }
            records.append(["kind": d.kind, "title": d.title, "category": d.category, "symbol": d.symbol, "description": d.detail, "parameters": d.parameters.map { ["key": $0.key, "title": $0.title, "defaultValue": $0.defaultValue, "choices": $0.choices] as [String: Any] }])
        }
        try markdown.write(to: docs.appendingPathComponent("ACTION_REFERENCE.md"), atomically: true, encoding: .utf8)
        try JSONSerialization.data(withJSONObject: records, options: [.prettyPrinted, .sortedKeys]).write(to: docs.appendingPathComponent("action-catalog.json"), options: .atomic)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let values: [String: WorkflowValue] = ["nothing": .null, "text": .text("Hello"), "number": .number(3), "boolean": .bool(true), "list": .list([.text("One"), .number(2)]), "dictionary": .dictionary(["name": .text("World")])]
        try encoder.encode(values).write(to: docs.appendingPathComponent("workflow-value-encoding.json"), options: .atomic)
        print("Generated \(records.count) action definitions and tagged value examples.")
    }
}
