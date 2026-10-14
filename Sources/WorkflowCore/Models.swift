import Foundation

public enum WorkflowValue: Codable, Equatable, Sendable {
    case null, text(String), number(Double), bool(Bool), list([WorkflowValue]), dictionary([String: WorkflowValue])

    public var text: String {
        switch self {
        case .null: return ""
        case .text(let s): return s
        case .number(let n): return n.isFinite ? String(format: "%.15g", n) : String(n)
        case .bool(let b): return b ? "true" : "false"
        case .list(let values): return values.map(\.text).joined(separator: "\n")
        case .dictionary: return jsonText
        }
    }
    public var number: Double? { if case .number(let n) = self { return n }; return Double(text) }
    public var items: [WorkflowValue] { if case .list(let a) = self { return a }; return self == .null ? [] : [self] }
    public var typeName: String {
        switch self { case .null: return "Nothing"; case .text: return "Text"; case .number: return "Number"; case .bool: return "Boolean"; case .list: return "List"; case .dictionary: return "Dictionary" }
    }
    public var jsonObject: Any {
        switch self {
        case .null: return NSNull()
        case .text(let s): return s
        case .number(let n): return n
        case .bool(let b): return b
        case .list(let a): return a.map(\.jsonObject)
        case .dictionary(let d): return d.mapValues(\.jsonObject)
        }
    }
    public var jsonText: String {
        guard let data = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.fragmentsAllowed, .prettyPrinted, .sortedKeys]), let s = String(data: data, encoding: .utf8) else { return "null" }; return s
    }
    public static func fromJSON(_ data: Data) throws -> WorkflowValue {
        func convert(_ x: Any) -> WorkflowValue {
            if x is NSNull { return .null }
            if let n = x as? NSNumber { return CFGetTypeID(n) == CFBooleanGetTypeID() ? .bool(n.boolValue) : .number(n.doubleValue) }
            if let s = x as? String { return .text(s) }
            if let a = x as? [Any] { return .list(a.map(convert)) }
            if let d = x as? [String: Any] { return .dictionary(d.mapValues(convert)) }
            return .null
        }
        return convert(try JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed))
    }
}
import CoreFoundation

public struct WorkflowAction: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var kind: String
    public var parameters: [String: String]
    public var isEnabled: Bool
    public init(kind: String, parameters: [String: String] = [:], id: UUID = UUID()) {
        self.id = id; self.kind = kind; self.parameters = parameters; self.isEnabled = true
    }
}

public struct ImportQuestion: Codable, Identifiable, Equatable, Sendable {
    public var id = UUID()
    public var title: String
    public var actionID: UUID
    public var parameter: String
    public var defaultAnswer: String
    public init(title: String, actionID: UUID, parameter: String, defaultAnswer: String = "") {
        self.title = title; self.actionID = actionID; self.parameter = parameter; self.defaultAnswer = defaultAnswer
    }
}

public struct Workflow: Codable, Identifiable, Equatable, Sendable {
    public var id = UUID()
    public var name: String
    public var symbol: String
    public var color: String
    public var folderID: UUID?
    public var origin: String?
    public var parentWorkflowID: UUID?
    public var actions: [WorkflowAction]
    public var storage: [String: WorkflowValue]
    public var questions: [ImportQuestion]
    public var isFavorite = false
    public var deletedAt: Date?
    public var updatedAt = Date()
    public init(name: String = "New Shortcut", symbol: String = "square.stack.3d.up.fill", color: String = "purple", actions: [WorkflowAction] = []) {
        self.name = name; self.symbol = symbol; self.color = color; self.actions = actions; self.storage = [:]; self.questions = []
    }
    public func duplicated() -> Workflow {
        var copy = self; copy.id = UUID(); copy.name += " Copy"; copy.deletedAt = nil
        let remap = Dictionary(uniqueKeysWithValues: actions.map { ($0.id, UUID()) })
        copy.actions = actions.map { action in
            var a = action; a.id = remap[action.id]!
            a.parameters = a.parameters.mapValues { value in
                var text = value
                for (old, new) in remap { text = text.replacingOccurrences(of: old.uuidString, with: new.uuidString) }
                return text
            }; return a
        }
        copy.questions = questions.map { q in var q = q; q.id = UUID(); q.actionID = remap[q.actionID] ?? q.actionID; return q }
        return copy
    }
}

public struct WorkflowFolder: Codable, Identifiable, Equatable, Sendable {
    public var id = UUID()
    public var name: String
    public init(name: String) { self.name = name }
}

public struct AutomationRule: Codable, Identifiable, Equatable, Sendable {
    public var id = UUID()
    public var workflowID: UUID
    public var name: String
    public var isEnabled = true
    public var trigger: String
    public var hour: Int
    public var minute: Int
    public var weekdays: [Int]?
    public var lastFired: Date?
    public init(workflowID: UUID, name: String, trigger: String = "time", hour: Int = 9, minute: Int = 0, weekdays: [Int]? = nil) {
        self.workflowID = workflowID; self.name = name; self.trigger = trigger; self.hour = hour; self.minute = minute; self.weekdays = weekdays
    }
}

public struct RunRecord: Codable, Identifiable, Sendable {
    public var id = UUID()
    public var workflowID: UUID
    public var workflowName: String
    public var startedAt: Date
    public var duration: Double
    public var status: String
    public var output: String
    public init(workflowID: UUID, workflowName: String, startedAt: Date, duration: Double, status: String, output: String) {
        self.workflowID = workflowID; self.workflowName = workflowName; self.startedAt = startedAt; self.duration = duration; self.status = status; self.output = output
    }
}

public struct LibraryDocument: Codable, Sendable {
    public var schemaVersion = 1
    public var workflows: [Workflow]
    public var folders: [WorkflowFolder]
    public var automations: [AutomationRule]
    public var history: [RunRecord]
    public init(workflows: [Workflow] = [], folders: [WorkflowFolder] = [], automations: [AutomationRule] = [], history: [RunRecord] = []) {
        self.workflows = workflows; self.folders = folders; self.automations = automations; self.history = history
    }
}

public struct WorkflowFile: Codable {
    public var format = "studio.shortcut"
    public var version = 1
    public var workflow: Workflow
    public init(workflow: Workflow) { self.workflow = workflow }
}

public enum StudioError: LocalizedError {
    case message(String)
    public var errorDescription: String? { switch self { case .message(let s): return s } }
}
