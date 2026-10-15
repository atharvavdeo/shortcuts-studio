import Foundation

public enum WorkflowEdits {
    public static func span(_ id: UUID, in workflow: Workflow) throws -> Range<Int> {
        guard let start = workflow.actions.firstIndex(where: { $0.id == id }) else { throw StudioError.message("Action not found.") }
        let kind = workflow.actions[start].kind
        guard !["else", "endIf", "endRepeat"].contains(kind) else { throw StudioError.message("Edit the opening If or Repeat to move, duplicate, or remove the whole block.") }
        guard ["if", "repeat", "repeatEach"].contains(kind) else { return start..<(start + 1) }
        var depth = 0
        for i in (start + 1)..<workflow.actions.count {
            let kind = workflow.actions[i].kind
            if ["if", "repeat", "repeatEach"].contains(kind) { depth += 1 }
            else if ["endIf", "endRepeat"].contains(kind) { if depth == 0 { return start..<(i + 1) }; depth -= 1 }
        }
        throw StudioError.message("Repair the unclosed block before editing it.")
    }
    public static func remove(_ id: UUID, from workflow: inout Workflow) throws {
        let range = try span(id, in: workflow); let ids = Set(workflow.actions[range].map(\.id)); workflow.actions.removeSubrange(range); workflow.questions.removeAll { ids.contains($0.actionID) }
    }
    public static func duplicate(_ id: UUID, in workflow: inout Workflow) throws {
        let range = try span(id, in: workflow); let source = Array(workflow.actions[range]); let remap = Dictionary(uniqueKeysWithValues: source.map { ($0.id, UUID()) })
        let copies = source.map { a -> WorkflowAction in
            var a = a; a.id = remap[a.id]!
            a.parameters = a.parameters.mapValues { value in var value = value; for (old, new) in remap { value = value.replacingOccurrences(of: old.uuidString, with: new.uuidString) }; return value }; return a
        }
        workflow.actions.insert(contentsOf: copies, at: range.upperBound)
    }
    public static func move(_ id: UUID, before target: UUID?, in workflow: inout Workflow) throws {
        let range = try span(id, in: workflow)
        if let target, workflow.actions[range].contains(where: { $0.id == target }) { return }
        var candidate = workflow; let moving = Array(candidate.actions[range]); candidate.actions.removeSubrange(range)
        let destination: Int
        if let target { guard let i = candidate.actions.firstIndex(where: { $0.id == target }) else { throw StudioError.message("Drop target not found.") }; destination = i } else { destination = candidate.actions.count }
        candidate.actions.insert(contentsOf: moving, at: destination)
        guard WorkflowValidator.validate(candidate).isEmpty else { throw StudioError.message("That move would break a control-flow block.") }; workflow = candidate
    }
    public static func move(_ id: UUID, offset: Int, in workflow: inout Workflow) throws {
        let range = try span(id, in: workflow)
        if offset < 0 {
            guard range.lowerBound > 0 else { return }
            var previous = range.lowerBound - 1
            if ["endIf", "endRepeat"].contains(workflow.actions[previous].kind) {
                for i in (0..<range.lowerBound).reversed() where ["if", "repeat", "repeatEach"].contains(workflow.actions[i].kind) {
                    if try span(workflow.actions[i].id, in: workflow).upperBound == range.lowerBound { previous = i; break }
                }
            }
            try move(id, before: workflow.actions[previous].id, in: &workflow)
        } else {
            guard range.upperBound < workflow.actions.count else { return }
            let nextRange = try span(workflow.actions[range.upperBound].id, in: workflow)
            let target = nextRange.upperBound < workflow.actions.count ? workflow.actions[nextRange.upperBound].id : nil
            try move(id, before: target, in: &workflow)
        }
    }
}
