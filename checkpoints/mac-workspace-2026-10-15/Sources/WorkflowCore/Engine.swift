import Foundation

@MainActor public protocol WorkflowHost: AnyObject {
    func perform(_ kind: String, parameters: [String: WorkflowValue], input: WorkflowValue) async throws -> WorkflowValue
    func workflow(named: String) -> Workflow?
    func persistStorage(_ storage: [String: WorkflowValue], workflowID: UUID) throws
    func stepStarted(_ actionID: UUID, title: String)
    func stepFinished(_ actionID: UUID, output: WorkflowValue)
}

public struct ValidationIssue: Identifiable, Equatable {
    public var id: String { "\(index):\(message)" }
    public let index: Int
    public let message: String
}

public enum WorkflowValidator {
    public static func validate(_ workflow: Workflow) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []; var stack: [(kind: String, index: Int, hasElse: Bool)] = []; var ids = Set<UUID>()
        for (i, action) in workflow.actions.enumerated() {
            if !ids.insert(action.id).inserted { issues.append(.init(index: i, message: "Duplicate action identifier.")) }
            if ActionCatalog.definition(action.kind) == nil { issues.append(.init(index: i, message: "Unknown action: \(action.kind).")) }
            guard action.isEnabled else {
                if ["if", "else", "endIf", "repeat", "repeatEach", "endRepeat"].contains(action.kind) { issues.append(.init(index: i, message: "Control-flow markers cannot be disabled.")) }; continue
            }
            switch action.kind {
            case "if", "repeat", "repeatEach": stack.append((action.kind, i, false))
            case "else":
                if let last = stack.last, last.kind == "if", !last.hasElse { stack[stack.count - 1].hasElse = true }
                else { issues.append(.init(index: i, message: "Otherwise must belong to an If and appear only once.")) }
            case "endIf":
                if stack.last?.kind == "if" { stack.removeLast() } else { issues.append(.init(index: i, message: "End If has no matching If.")) }
            case "endRepeat":
                if let kind = stack.last?.kind, ["repeat", "repeatEach"].contains(kind) { stack.removeLast() } else { issues.append(.init(index: i, message: "End Repeat has no matching Repeat.")) }
            default: break
            }
            if stack.count > 32 { issues.append(.init(index: i, message: "Blocks are nested more than 32 levels.")) }
        }
        for block in stack { issues.append(.init(index: block.index, message: "\(block.kind) is missing its closing action.")) }
        return issues
    }
    public static func indentation(_ actions: [WorkflowAction], at index: Int) -> Int {
        var level = 0
        for a in actions.prefix(index) {
            if ["if", "repeat", "repeatEach"].contains(a.kind) { level += 1 }
            if ["endIf", "endRepeat"].contains(a.kind) { level = max(0, level - 1) }
        }
        if ["else", "endIf", "endRepeat"].contains(actions[index].kind) { level = max(0, level - 1) }
        return min(level, 8)
    }
}

@MainActor public final class WorkflowEngine {
    private unowned let host: WorkflowHost
    private var steps = 0
    public var maximumSteps = 10_000
    public init(host: WorkflowHost) { self.host = host }

    private final class Context {
        let workflow: Workflow
        let input: WorkflowValue
        var previous: WorkflowValue
        var variables: [String: WorkflowValue] = [:]
        var outputs: [UUID: WorkflowValue] = [:]
        var storage: [String: WorkflowValue]
        var repeatItem: WorkflowValue = .null
        var repeatIndex: WorkflowValue = .null
        var stopped = false
        init(_ workflow: Workflow, _ input: WorkflowValue) { self.workflow = workflow; self.input = input; self.previous = input; self.storage = workflow.storage }
    }
    public func run(_ workflow: Workflow, input: WorkflowValue = .null) async throws -> WorkflowValue {
        steps = 0
        return try await runInternal(workflow, input: input, chain: [])
    }
    private func runInternal(_ workflow: Workflow, input: WorkflowValue, chain: [UUID]) async throws -> WorkflowValue {
        try Task.checkCancellation()
        guard !chain.contains(workflow.id), chain.count < 16 else { throw StudioError.message("Shortcut recursion detected or nesting limit exceeded.") }
        let issues = WorkflowValidator.validate(workflow)
        guard issues.isEmpty else { throw StudioError.message("Action \(issues[0].index + 1): \(issues[0].message)") }
        let context = Context(workflow, input)
        try await execute(workflow.actions, range: 0..<workflow.actions.count, context: context, chain: chain + [workflow.id])
        return context.previous
    }
    private func resolveToken(_ token: String, _ c: Context) throws -> WorkflowValue {
        switch token {
        case "previous": return c.previous
        case "input": return c.input
        case "repeatItem": return c.repeatItem
        case "repeatIndex": return c.repeatIndex
        default:
            if token.hasPrefix("variable:") {
                let name = String(token.dropFirst(9)); guard let value = c.variables[name] else { throw StudioError.message("Variable ‘\(name)’ has not been set.") }; return value
            }
            if token.hasPrefix("storage:") { return c.storage[String(token.dropFirst(8))] ?? .null }
            if token.hasPrefix("output:"), let id = UUID(uuidString: String(token.dropFirst(7))), let value = c.outputs[id] { return value }
            throw StudioError.message("Unknown or unavailable reference: {{\(token)}}.")
        }
    }
    private func resolve(_ text: String, _ c: Context) throws -> WorkflowValue {
        let regex = try NSRegularExpression(pattern: "\\{\\{([^{}]+)\\}\\}")
        let ns = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: ns.length))
        if matches.count == 1, matches[0].range.length == ns.length { return try resolveToken(ns.substring(with: matches[0].range(at: 1)), c) }
        var result = text
        for match in matches.reversed() {
            let value = try resolveToken(ns.substring(with: match.range(at: 1)), c)
            if let range = Range(match.range, in: result) { result.replaceSubrange(range, with: value.text) }
        }
        return .text(result)
    }
    private func bounds(_ actions: [WorkflowAction], start: Int) throws -> (end: Int, otherwise: Int?) {
        var depth = 0; var otherwise: Int?
        for i in (start + 1)..<actions.count {
            let kind = actions[i].kind
            if ["if", "repeat", "repeatEach"].contains(kind) { depth += 1 }
            else if ["endIf", "endRepeat"].contains(kind) {
                if depth == 0 { return (i, otherwise) }; depth -= 1
            } else if kind == "else", depth == 0 { otherwise = i }
        }
        throw StudioError.message("Unclosed block.")
    }
    private func execute(_ actions: [WorkflowAction], range: Range<Int>, context c: Context, chain: [UUID]) async throws {
        var index = range.lowerBound
        while index < range.upperBound, !c.stopped {
            try Task.checkCancellation(); await Task.yield()
            steps += 1; guard steps <= maximumSteps else { throw StudioError.message("Execution exceeded \(maximumSteps) steps.") }
            let a = actions[index]; index += 1
            guard a.isEnabled else { continue }
            host.stepStarted(a.id, title: ActionCatalog.definition(a.kind)?.title ?? a.kind)
            var p: [String: WorkflowValue] = [:]
            do {
                for (key, value) in a.parameters { p[key] = try resolve(value, c) }
                let input = p["input"] ?? c.previous
                if a.kind == "if" {
                    let b = try bounds(actions, start: index - 1)
                    if try condition(input, comparison: p["comparison"]?.text ?? "has value", other: p["value"] ?? .null) {
                        try await execute(actions, range: index..<(b.otherwise ?? b.end), context: c, chain: chain)
                    } else if let otherwise = b.otherwise { try await execute(actions, range: (otherwise + 1)..<b.end, context: c, chain: chain) }
                    index = b.end + 1
                } else if a.kind == "repeat" || a.kind == "repeatEach" {
                    let b = try bounds(actions, start: index - 1)
                    let items: [WorkflowValue]
                    if a.kind == "repeat" {
                        guard let number = p["count"]?.number, number.isFinite, number.rounded() == number, number >= 0, number <= 1000 else { throw StudioError.message("Repeat count must be an integer from 0 to 1000.") }
                        items = (0..<Int(number)).map { .number(Double($0 + 1)) }
                    } else { items = input.items; guard items.count <= 1000 else { throw StudioError.message("Repeat supports at most 1000 items.") } }
                    let oldItem = c.repeatItem, oldIndex = c.repeatIndex
                    let blockOutputIDs = Set(actions[index..<b.end].map(\.id))
                    var results: [WorkflowValue] = []
                    for (i, item) in items.enumerated() {
                        for id in blockOutputIDs { c.outputs.removeValue(forKey: id) }
                        c.repeatItem = item; c.repeatIndex = .number(Double(i + 1)); c.previous = a.kind == "repeatEach" ? item : input
                        try await execute(actions, range: index..<b.end, context: c, chain: chain)
                        results.append(c.previous); if c.stopped { break }
                    }
                    c.repeatItem = oldItem; c.repeatIndex = oldIndex
                    if !c.stopped { c.previous = .list(results) }; index = b.end + 1
                } else if a.kind == "runWorkflow" {
                    guard let name = p["workflow"]?.text, let workflow = host.workflow(named: name) else { throw StudioError.message("The referenced shortcut was not found.") }
                    c.previous = try await runInternal(workflow, input: input, chain: chain)
                } else {
                    c.previous = try await perform(a.kind, p, input, c)
                }
                c.outputs[a.id] = c.previous
                try Task.checkCancellation()
                host.stepFinished(a.id, output: c.previous)
            } catch is CancellationError { throw CancellationError() }
            catch { if Task.isCancelled { throw CancellationError() }; throw StudioError.message("\(ActionCatalog.definition(a.kind)?.title ?? a.kind) (action \(index)): \(error.localizedDescription)") }
        }
    }
    private func condition(_ input: WorkflowValue, comparison: String, other: WorkflowValue) throws -> Bool {
        switch comparison {
        case "has value": return input != .null && !input.text.isEmpty && input != .list([])
        case "equals": return input.text == other.text
        case "not equals": return input.text != other.text
        case "contains": return input.text.contains(other.text)
        case "is true": return input == .bool(true) || input.text.lowercased() == "true"
        case "greater than", "less than":
            guard let a = input.number, let b = other.number else { throw StudioError.message("Numeric comparison requires two numbers.") }; return comparison == "greater than" ? a > b : a < b
        default: throw StudioError.message("Unsupported condition.")
        }
    }
    private func perform(_ kind: String, _ p: [String: WorkflowValue], _ input: WorkflowValue, _ c: Context) async throws -> WorkflowValue {
        func s(_ key: String) -> String { p[key]?.text ?? "" }
        func numeric(_ key: String) throws -> Double {
            guard let n = p[key]?.number, n.isFinite else { throw StudioError.message("\(key) must be a finite number.") }; return n
        }
        switch kind {
        case "text": return .text(p["text"]?.text ?? "")
        case "number": return .number(try numeric("number"))
        case "boolean": return .bool(s("value") == "true")
        case "comment": return c.previous
        case "input": return c.input
        case "setVariable": guard !s("name").isEmpty else { throw StudioError.message("Variable name is required.") }; c.variables[s("name")] = input; return input
        case "getVariable": guard let value = c.variables[s("name")] else { throw StudioError.message("Variable has not been set.") }; return value
        case "stop": c.stopped = true; return input
        case "wait":
            let seconds = try numeric("seconds"); guard seconds >= 0, seconds <= 300 else { throw StudioError.message("Wait must be between 0 and 300 seconds.") }
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000)); return c.previous
        case "uppercase": return .text(s("case") == "lowercase" ? input.text.lowercased() : s("case") == "title case" ? input.text.capitalized : input.text.uppercased())
        case "trim": return .text(input.text.trimmingCharacters(in: .whitespacesAndNewlines))
        case "replace":
            if s("regex") == "true" { let regex = try NSRegularExpression(pattern: s("find")); return .text(regex.stringByReplacingMatches(in: input.text, range: NSRange(input.text.startIndex..., in: input.text), withTemplate: s("replacement"))) }
            return .text(input.text.replacingOccurrences(of: s("find"), with: s("replacement")))
        case "match":
            let regex = try NSRegularExpression(pattern: s("pattern")); let text = input.text as NSString
            return .list(regex.matches(in: input.text, range: NSRange(location: 0, length: text.length)).map { .text(text.substring(with: $0.range)) })
        case "split":
            let sep = s("separator").replacingOccurrences(of: "\\n", with: "\n").replacingOccurrences(of: "\\t", with: "\t")
            guard !sep.isEmpty else { return .list(input.text.map { .text(String($0)) }) }; return .list(input.text.components(separatedBy: sep).map { .text($0) })
        case "combine": return .text(input.items.map(\.text).joined(separator: s("separator").replacingOccurrences(of: "\\n", with: "\n").replacingOccurrences(of: "\\t", with: "\t")))
        case "base64":
            if s("mode") == "decode" { guard let data = Data(base64Encoded: input.text), let text = String(data: data, encoding: .utf8) else { throw StudioError.message("Input is not Base64 UTF-8 text.") }; return .text(text) }
            return .text(Data(input.text.utf8).base64EncodedString())
        case "urlEncode":
            if s("mode") == "decode" { guard let text = input.text.removingPercentEncoding else { throw StudioError.message("Invalid percent escapes.") }; return .text(text) }
            return .text(input.text.addingPercentEncoding(withAllowedCharacters: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))) ?? "")
        case "calculate":
            let a = try numeric("a"), b = try numeric("b"); let result: Double
            switch s("operation") { case "+": result = a + b; case "-": result = a - b; case "×": result = a * b; case "÷": guard b != 0 else { throw StudioError.message("Division by zero.") }; result = a / b; case "mod": guard b != 0 else { throw StudioError.message("Division by zero.") }; result = a.truncatingRemainder(dividingBy: b); case "power": result = pow(a, b); default: throw StudioError.message("Unknown arithmetic operation.") }
            guard result.isFinite else { throw StudioError.message("The arithmetic result is not finite.") }; return .number(result)
        case "round":
            guard let n = input.number, n.isFinite else { throw StudioError.message("Input must be numeric.") }; let places = try numeric("places")
            guard places >= -12, places <= 12, places.rounded() == places else { throw StudioError.message("Precision must be an integer from -12 to 12.") }
            let scale = pow(10, places); let result = (n * scale).rounded() / scale
            guard result.isFinite else { throw StudioError.message("Rounding overflow.") }; return .number(result)
        case "random":
            let a = try numeric("min"), b = try numeric("max")
            guard a >= -1_000_000_000, b <= 1_000_000_000, a <= b, a.rounded() == a, b.rounded() == b else { throw StudioError.message("Provide ordered integer bounds within ±1 billion.") }; return .number(Double(Int.random(in: Int(a)...Int(b))))
        case "statistics":
            if s("statistic") == "count" { return .number(Double(input.items.count)) }
            let numbers = try input.items.map { value -> Double in guard let n = value.number, n.isFinite else { throw StudioError.message("Every item must be numeric.") }; return n }
            guard !numbers.isEmpty else { throw StudioError.message("The list is empty.") }
            let result: Double
            switch s("statistic") { case "average": result = numbers.reduce(0,+) / Double(numbers.count); case "minimum": result = numbers.min()!; case "maximum": result = numbers.max()!; default: result = numbers.reduce(0,+) }
            guard result.isFinite else { throw StudioError.message("Statistic overflow.") }; return .number(result)
        case "list": return .list(s("items").components(separatedBy: "\n").map { .text($0) })
        case "count": return .number(Double(s("unit") == "characters" ? input.text.count : s("unit") == "words" ? input.text.split(whereSeparator: { $0.isWhitespace }).count : input.items.count))
        case "getItem":
            let items = input.items; guard !items.isEmpty else { throw StudioError.message("The list is empty.") }
            if s("index") == "first" { return items[0] }; if s("index") == "last" { return items.last! }; if s("index") == "random" { return items.randomElement()! }
            guard let i = Int(s("index")), i > 0, i <= items.count else { throw StudioError.message("Index is outside the list (indices start at 1).") }; return items[i - 1]
        case "sort":
            var items = input.items
            if s("type") == "number" {
                guard items.allSatisfy({ $0.number?.isFinite == true }) else { throw StudioError.message("Every item must be numeric.") }; items.sort { $0.number! < $1.number! }
            } else { items.sort { $0.text.localizedStandardCompare($1.text) == .orderedAscending } }
            return .list(s("order") == "descending" ? Array(items.reversed()) : items)
        case "reverse": return .list(Array(input.items.reversed()))
        case "unique": var out: [WorkflowValue] = []; for value in input.items where !out.contains(value) { out.append(value) }; return .list(out)
        case "filter": return .list(input.items.filter { $0.text.localizedCaseInsensitiveContains(s("contains")) })
        case "dictionary", "parseJSON":
            let value = try WorkflowValue.fromJSON(Data((kind == "dictionary" ? s("json") : input.text).utf8))
            if kind == "dictionary", case .dictionary = value { return value }
            if kind == "dictionary" { throw StudioError.message("JSON must be an object.") }; return value
        case "getValue":
            var value = input
            for key in s("key").components(separatedBy: ".") {
                guard case .dictionary(let dict) = value, let next = dict[key] else { throw StudioError.message("Dictionary path not found: \(s("key")).") }; value = next
            }; return value
        case "setValue": guard case .dictionary(var dict) = input, !s("key").isEmpty else { throw StudioError.message("Dictionary input and a key are required.") }; dict[s("key")] = p["value"] ?? .null; return .dictionary(dict)
        case "keys": guard case .dictionary(let dict) = input else { throw StudioError.message("Input must be a dictionary.") }; return .list(dict.keys.sorted().map { .text($0) })
        case "json": return .text(input.jsonText)
        case "url": return .text(try webURL(s("url")).absoluteString)
        case "http":
            var request = URLRequest(url: try webURL(s("url"))); request.httpMethod = s("method"); request.timeoutInterval = 30
            guard ["GET", "POST", "PUT", "PATCH", "DELETE"].contains(request.httpMethod!) else { throw StudioError.message("Unsupported HTTP method.") }
            guard case .dictionary(let headers) = try WorkflowValue.fromJSON(Data(s("headers").utf8)) else { throw StudioError.message("Headers must be a JSON object.") }
            for (key, value) in headers { request.setValue(value.text, forHTTPHeaderField: key) }
            if !s("body").isEmpty { request.httpBody = Data(s("body").utf8) }
            let (bytes, response) = try await URLSession.shared.bytes(for: request)
            guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else { throw StudioError.message("HTTP request returned an unsuccessful status.") }
            var data = Data(); for try await byte in bytes { if data.count >= 10_000_000 { throw StudioError.message("Response exceeds 10 MB.") }; data.append(byte); if data.count % 8192 == 0 { try Task.checkCancellation() } }
            if s("response") == "json" { return try WorkflowValue.fromJSON(data) }
            guard let text = String(data: data, encoding: .utf8) else { throw StudioError.message("Response is not UTF-8 text.") }; return .text(text)
        case "date": return .text(ISO8601DateFormatter().string(from: Date()))
        case "formatDate": guard let date = ISO8601DateFormatter().date(from: input.text) else { throw StudioError.message("Input must be an ISO 8601 timestamp.") }; let f = DateFormatter(); f.dateFormat = s("format"); return .text(f.string(from: date))
        case "readFile":
            let url = URL(fileURLWithPath: NSString(string: s("path")).expandingTildeInPath)
            let values = try url.resourceValues(forKeys: [.fileSizeKey]); guard (values.fileSize ?? Int.max) <= 10_000_000 else { throw StudioError.message("File exceeds 10 MB.") }
            return try await Task.detached { .text(try String(contentsOf: url, encoding: .utf8)) }.value
        case "fileInfo":
            let url = URL(fileURLWithPath: NSString(string: s("path")).expandingTildeInPath); let values = try url.resourceValues(forKeys: [.fileSizeKey])
            return .dictionary(["name": .text(url.lastPathComponent), "path": .text(url.path), "extension": .text(url.pathExtension), "size": .number(Double(values.fileSize ?? 0))])
        case "storageGet": return c.storage[s("key")] ?? .null
        case "storageSet", "storageDelete":
            guard !s("key").isEmpty else { throw StudioError.message("Storage key is required.") }
            var storage = c.storage; if kind == "storageSet" { storage[s("key")] = input } else { storage.removeValue(forKey: s("key")) }
            try host.persistStorage(storage, workflowID: c.workflow.id); c.storage = storage; return input
        default: return try await host.perform(kind, parameters: p, input: input)
        }
    }
    private func webURL(_ text: String) throws -> URL {
        guard let url = URL(string: text), ["http", "https"].contains(url.scheme?.lowercased() ?? ""), url.host != nil else { throw StudioError.message("Provide a valid HTTP or HTTPS URL.") }; return url
    }
}
