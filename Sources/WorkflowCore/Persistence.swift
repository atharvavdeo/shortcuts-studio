import Foundation

public final class LibraryRepository {
    public let url: URL
    public var backupURL: URL { url.appendingPathExtension("backup") }
    public init(url: URL) { self.url = url }
    public func load() throws -> LibraryDocument {
        let data = try Data(contentsOf: url)
        let document = try JSONDecoder().decode(LibraryDocument.self, from: data)
        try validate(document); return document
    }
    public func save(_ document: LibraryDocument) throws {
        try validate(document)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(document)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: url.path) {
            let old = try Data(contentsOf: url)
            // Never rotate corrupt bytes into the last known-good backup.
            if let decoded = try? JSONDecoder().decode(LibraryDocument.self, from: old), (try? validate(decoded)) != nil { try old.write(to: backupURL, options: .atomic) }
        }
        try data.write(to: url, options: .atomic)
    }
    public func restoreBackup() throws -> LibraryDocument {
        let data = try Data(contentsOf: backupURL); let document = try JSONDecoder().decode(LibraryDocument.self, from: data); try validate(document)
        if FileManager.default.fileExists(atPath: url.path) {
            let preserved = url.deletingLastPathComponent().appendingPathComponent("library-corrupt-\(UUID().uuidString).json")
            try FileManager.default.copyItem(at: url, to: preserved)
        }
        try data.write(to: url, options: .atomic); return document
    }
    private func validate(_ document: LibraryDocument) throws {
        guard document.schemaVersion == 1 else { throw StudioError.message("Unsupported library version: \(document.schemaVersion).") }
        guard Set(document.workflows.map(\.id)).count == document.workflows.count, Set(document.folders.map(\.id)).count == document.folders.count, Set(document.automations.map(\.id)).count == document.automations.count else { throw StudioError.message("Library contains duplicate identities.") }
        for rule in document.automations {
            guard (0...23).contains(rule.hour), (0...59).contains(rule.minute), rule.weekdays == nil || (!rule.weekdays!.isEmpty && rule.weekdays!.allSatisfy { (1...7).contains($0) }) else { throw StudioError.message("An automation has an invalid schedule.") }
        }
        for workflow in document.workflows {
            guard Set(workflow.actions.map(\.id)).count == workflow.actions.count else { throw StudioError.message("A shortcut contains duplicate action identities.") }
        }
    }
    public static func encodeWorkflow(_ workflow: Workflow) throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; return try encoder.encode(WorkflowFile(workflow: workflow))
    }
    public static func decodeWorkflow(_ data: Data) throws -> Workflow {
        guard data.count <= 20_000_000 else { throw StudioError.message("Shortcut file exceeds 20 MB.") }
        let file = try JSONDecoder().decode(WorkflowFile.self, from: data)
        guard file.format == "studio.shortcut", file.version == 1 else { throw StudioError.message("Unsupported shortcut format/version.") }
        guard file.workflow.actions.count <= 5000 else { throw StudioError.message("Shortcut exceeds 5000 actions.") }
        let issues = WorkflowValidator.validate(file.workflow)
        guard issues.isEmpty else { throw StudioError.message("Imported shortcut is invalid: \(issues[0].message)") }
        guard file.workflow.questions.allSatisfy({ q in file.workflow.actions.contains { $0.id == q.actionID && $0.parameters[q.parameter] != nil } }) else { throw StudioError.message("Import question points to a missing parameter.") }
        return file.workflow
    }
}
