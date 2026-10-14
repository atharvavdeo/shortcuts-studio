import Foundation

public struct ActionParameter: Identifiable, Sendable {
    public var id: String { key }
    public let key: String
    public let title: String
    public let defaultValue: String
    public let choices: [String]
    public init(_ key: String, _ title: String, _ value: String = "", choices: [String] = []) {
        self.key = key; self.title = title; self.defaultValue = value; self.choices = choices
    }
}
public struct ActionDefinition: Identifiable, Sendable {
    public var id: String { kind }
    public let kind: String
    public let title: String
    public let category: String
    public let symbol: String
    public let detail: String
    public let parameters: [ActionParameter]
    public var action: WorkflowAction { WorkflowAction(kind: kind, parameters: Dictionary(uniqueKeysWithValues: parameters.map { ($0.key, $0.defaultValue) })) }
}

public enum ActionCatalog {
    public static let categories = ["All Actions", "Intelligence", "Scripting", "Text", "Numbers", "Lists", "Dictionaries", "Web", "Files", "Mac", "Storage"]
    public static let definitions: [ActionDefinition] = {
        let input = ActionParameter("input", "Input", "{{previous}}")
        func d(_ kind: String, _ title: String, _ category: String, _ symbol: String, _ detail: String, _ p: [ActionParameter] = []) -> ActionDefinition {
            ActionDefinition(kind: kind, title: title, category: category, symbol: symbol, detail: detail, parameters: p)
        }
        return [
            d("onDeviceModel", "Use On-Device Model", "Intelligence", "sparkles", "Stream text from Apple’s on-device Foundation Model. Requires available Apple Intelligence; no cloud fallback.", [.init("prompt", "Prompt", "Summarize: {{previous}}"), .init("instructions", "Instructions", "Be concise and accurate.")]),
            d("phoneAssistant", "Phone Assistant", "Intelligence", "bubble.left.and.bubble.right", "Route a phone command through Apple on-device intelligence to approved Mac tasks or an answer. App control requires Accessibility permission.", [.init("prompt", "Command or question", "{{input}}"), .init("applications", "Approved application bundle IDs", "com.openai.codex,com.openai.chat,com.google.Chrome,com.subframe.desktop,com.apple.finder,com.apple.calculator,com.apple.weather"), .init("desktop", "Allow Desktop filenames", "true", choices: ["true", "false"])]),
            d("desktopNames", "Get Desktop File Names", "Mac", "desktopcomputer", "List visible Desktop filenames, up to 200 entries; no file contents or arbitrary paths."),
            d("appControl", "Control Application", "Mac", "macwindow", "Open, inspect, type into, or submit text to the configured app using public Accessibility APIs.", [.init("bundle", "Application bundle ID", "com.openai.chat"), .init("operation", "Operation", "inspect", choices: ["open", "inspect", "type", "send"]), .init("text", "Text", "{{input}}")]),
            d("text", "Text", "Text", "text.alignleft", "Create text. Insert variables using the reference picker.", [.init("text", "Text", "Hello, world!")]),
            d("number", "Number", "Numbers", "number", "Create a finite numeric value.", [.init("number", "Number", "1")]),
            d("boolean", "Boolean", "Scripting", "switch.2", "Create true or false.", [.init("value", "Value", "true", choices: ["true", "false"])]),
            d("comment", "Comment", "Scripting", "text.bubble", "Document a step without changing its output.", [.init("text", "Comment")]),
            d("input", "Shortcut Input", "Scripting", "tray.and.arrow.down", "Get the input supplied when this shortcut starts."),
            d("setVariable", "Set Variable", "Scripting", "v.square", "Store a typed value for this run.", [.init("name", "Name", "Value"), input]),
            d("getVariable", "Get Variable", "Scripting", "v.square.fill", "Retrieve a named variable.", [.init("name", "Name", "Value")]),
            d("if", "If", "Scripting", "arrow.triangle.branch", "Run a block when its condition is true.", [input, .init("comparison", "Condition", "has value", choices: ["has value", "equals", "not equals", "contains", "greater than", "less than", "is true"]), .init("value", "Compare to")]),
            d("else", "Otherwise", "Scripting", "arrow.turn.down.right", "Alternate branch of the current If block."),
            d("endIf", "End If", "Scripting", "arrow.turn.up.left", "Close the current If block."),
            d("repeat", "Repeat", "Scripting", "repeat", "Repeat the block and collect its outputs.", [.init("count", "Times", "3")]),
            d("repeatEach", "Repeat with Each", "Scripting", "repeat.circle", "Run the block for every item. Use Repeat Item and Repeat Index.", [input]),
            d("endRepeat", "End Repeat", "Scripting", "arrow.turn.up.left", "Close the current Repeat block."),
            d("wait", "Wait", "Scripting", "clock", "Pause cooperatively; Stop cancels the wait.", [.init("seconds", "Seconds", "1")]),
            d("stop", "Stop and Output", "Scripting", "stop.circle", "End this shortcut and return the selected value.", [input]),
            d("runWorkflow", "Run Shortcut", "Scripting", "square.stack.3d.up", "Run another Studio shortcut by name or identifier.", [.init("workflow", "Shortcut"), input]),
            d("ask", "Ask for Input", "Scripting", "questionmark.bubble", "Show a text prompt. Cancel stops the run.", [.init("prompt", "Prompt", "What is your name?"), .init("default", "Default answer")]),
            d("choose", "Choose from List", "Lists", "list.bullet.rectangle", "Ask the user to select one list item.", [input, .init("prompt", "Prompt", "Choose an item")]),
            d("show", "Show Result", "Scripting", "eye", "Present a result in a native dialog.", [input]),
            d("alert", "Show Alert", "Scripting", "exclamationmark.bubble", "Display an alert and continue with the existing input.", [.init("title", "Title", "Shortcut"), .init("message", "Message", "{{previous}}")]),
            d("notification", "Show Notification", "Mac", "bell", "Post a system notification when permission is granted.", [.init("title", "Title", "Shortcut Studio"), .init("message", "Message", "{{previous}}")]),
            d("uppercase", "Change Case", "Text", "textformat", "Change the case of text.", [input, .init("case", "Case", "uppercase", choices: ["uppercase", "lowercase", "title case"])]),
            d("trim", "Trim Whitespace", "Text", "textformat.size", "Remove whitespace at both ends.", [input]),
            d("replace", "Replace Text", "Text", "arrow.left.arrow.right", "Replace literal text or a regular expression.", [input, .init("find", "Find"), .init("replacement", "Replace with"), .init("regex", "Regular expression", "false", choices: ["false", "true"])]),
            d("match", "Match Text", "Text", "magnifyingglass", "Find regex matches as a list.", [input, .init("pattern", "Pattern", "\\w+")]),
            d("split", "Split Text", "Text", "text.line.first.and.arrowtriangle.forward", "Split text using a literal separator.", [input, .init("separator", "Separator", "\\n")]),
            d("combine", "Combine Text", "Text", "text.append", "Join list items with a separator.", [input, .init("separator", "Separator", "\\n")]),
            d("base64", "Base64 Encode / Decode", "Text", "chevron.left.forwardslash.chevron.right", "Convert UTF-8 text to or from Base64.", [input, .init("mode", "Mode", "encode", choices: ["encode", "decode"])]),
            d("urlEncode", "URL Encode / Decode", "Web", "link", "Percent-encode text or decode percent escapes.", [input, .init("mode", "Mode", "encode", choices: ["encode", "decode"])]),
            d("calculate", "Calculate", "Numbers", "plus.forwardslash.minus", "Apply an arithmetic operation to two numbers.", [.init("a", "First number", "{{previous}}"), .init("operation", "Operation", "+", choices: ["+", "-", "×", "÷", "mod", "power"]), .init("b", "Second number", "1")]),
            d("round", "Round Number", "Numbers", "number.square", "Round to a specified decimal precision.", [input, .init("places", "Decimal places", "0")]),
            d("random", "Random Number", "Numbers", "dice", "Generate an integer in an inclusive range.", [.init("min", "Minimum", "1"), .init("max", "Maximum", "100")]),
            d("statistics", "Calculate Statistics", "Numbers", "sum", "Compute statistics over a numeric list.", [input, .init("statistic", "Statistic", "sum", choices: ["sum", "average", "minimum", "maximum", "count"])]),
            d("list", "List", "Lists", "list.bullet", "Create a list with one text item per line.", [.init("items", "Items", "One\nTwo\nThree")]),
            d("count", "Count", "Lists", "number.circle", "Count items, words, or characters.", [input, .init("unit", "Count", "items", choices: ["items", "words", "characters"])]),
            d("getItem", "Get Item from List", "Lists", "list.number", "Retrieve a one-based item, first item, last item, or random item.", [input, .init("index", "Index", "1")]),
            d("sort", "Sort List", "Lists", "arrow.up.arrow.down", "Sort items as text or numeric values.", [input, .init("order", "Order", "ascending", choices: ["ascending", "descending"]), .init("type", "Compare", "text", choices: ["text", "number"])]),
            d("reverse", "Reverse List", "Lists", "arrow.uturn.backward", "Reverse item order.", [input]),
            d("unique", "Remove Duplicates", "Lists", "line.3.horizontal.decrease", "Keep the first occurrence of each typed value.", [input]),
            d("filter", "Filter List", "Lists", "line.3.horizontal.decrease.circle", "Keep text items containing a string.", [input, .init("contains", "Contains")]),
            d("dictionary", "Dictionary", "Dictionaries", "curlybraces", "Create a dictionary from JSON.", [.init("json", "JSON", "{\"name\":\"World\"}")]),
            d("parseJSON", "Get Dictionary from Input", "Dictionaries", "curlybraces.square", "Parse JSON into typed values.", [input]),
            d("getValue", "Get Dictionary Value", "Dictionaries", "key", "Follow a dot-separated dictionary key path.", [input, .init("key", "Key", "name")]),
            d("setValue", "Set Dictionary Value", "Dictionaries", "key.fill", "Set a top-level key on a copy of the dictionary.", [input, .init("key", "Key", "name"), .init("value", "Value", "World")]),
            d("keys", "Get Dictionary Keys", "Dictionaries", "list.bullet.indent", "Return dictionary keys in sorted order.", [input]),
            d("json", "Convert to JSON", "Dictionaries", "chevron.left.forwardslash.chevron.right", "Serialize a typed value to JSON.", [input]),
            d("url", "URL", "Web", "link.circle", "Create and validate an HTTP or HTTPS URL.", [.init("url", "URL", "https://example.com")]),
            d("http", "Get Contents of URL", "Web", "network", "Make an HTTP request; unsuccessful responses fail the run.", [.init("url", "URL", "{{previous}}"), .init("method", "Method", "GET", choices: ["GET", "POST", "PUT", "PATCH", "DELETE"]), .init("headers", "Headers (JSON)", "{}"), .init("body", "Request body"), .init("response", "Response", "text", choices: ["text", "json"])]),
            d("openURL", "Open URL", "Web", "safari", "Open a URL in the default app or a chosen browser/application.", [input, .init("bundle", "Application bundle ID (optional)")]),
            d("date", "Current Date", "Mac", "calendar", "Return the current timestamp in ISO 8601 format."),
            d("formatDate", "Format Date", "Mac", "calendar.badge.clock", "Format an ISO 8601 timestamp.", [input, .init("format", "Date format", "EEEE, d MMMM yyyy")]),
            d("clipboard", "Get Clipboard", "Mac", "doc.on.clipboard", "Read text from the system clipboard."),
            d("copy", "Copy to Clipboard", "Mac", "doc.on.doc", "Copy text to the system clipboard.", [input]),
            d("openApp", "Open App", "Mac", "app.badge", "Open an app using its bundle identifier.", [.init("bundle", "Bundle identifier", "com.apple.Safari")]),
            d("speak", "Speak Text", "Mac", "speaker.wave.2", "Read text aloud using system speech.", [input]),
            d("selectFile", "Select File", "Files", "folder", "Choose a file using a native open panel."),
            d("readFile", "Read Text File", "Files", "doc.text", "Read a UTF-8 file, limited to 10 MB.", [.init("path", "File path", "{{previous}}")]),
            d("saveFile", "Save Text File", "Files", "square.and.arrow.down", "Choose where to save text using a native save panel.", [input, .init("name", "Suggested filename", "Result.txt")]),
            d("fileInfo", "Get File Details", "Files", "doc.badge.gearshape", "Return file name, size, extension, and path.", [.init("path", "File path", "{{previous}}")]),
            d("storageGet", "Get Stored Value", "Storage", "externaldrive", "Get a value persisted across runs of this shortcut.", [.init("key", "Key", "counter")]),
            d("storageSet", "Set Stored Value", "Storage", "externaldrive.fill", "Persist a value immediately; cancellation does not undo committed writes.", [.init("key", "Key", "counter"), input]),
            d("storageDelete", "Remove Stored Value", "Storage", "externaldrive.badge.minus", "Remove a stored key from this shortcut.", [.init("key", "Key", "counter")]),
            d("appleShortcut", "Run Apple Shortcut", "Mac", "square.stack.3d.up.fill", "Delegate to Apple's installed engine by shortcut name or identifier.", [.init("shortcut", "Apple shortcut"), input])
        ]
    }()
    public static func definition(_ kind: String) -> ActionDefinition? { definitions.first { $0.kind == kind } }
    public static func block(_ kind: String) -> [WorkflowAction] {
        guard let d = definition(kind) else { return [] }
        if kind == "if" { return [d.action, definition("else")!.action, definition("endIf")!.action] }
        if kind == "repeat" || kind == "repeatEach" { return [d.action, definition("endRepeat")!.action] }
        return [d.action]
    }
    public static let galleryTemplates: [Workflow] = [
        Workflow(name: "Hello, You", symbol: "hand.wave.fill", color: "purple", actions: [definition("ask")!.action, WorkflowAction(kind: "text", parameters: ["text": "Hello, {{previous}}! 👋"]), definition("show")!.action]),
        Workflow(name: "Morning Note", symbol: "sun.max.fill", color: "orange", actions: [definition("date")!.action, definition("formatDate")!.action, WorkflowAction(kind: "text", parameters: ["text": "Today is {{previous}}.\n\nMy three priorities:\n1.\n2.\n3."]), definition("copy")!.action]),
        Workflow(name: "List Playground", symbol: "list.bullet", color: "blue", actions: [definition("list")!.action, definition("repeatEach")!.action, WorkflowAction(kind: "text", parameters: ["text": "{{repeatIndex}}. {{repeatItem}}"]), definition("endRepeat")!.action, definition("combine")!.action, definition("show")!.action]),
        Workflow(name: "Persistent Counter", symbol: "number", color: "green", actions: [definition("storageGet")!.action, WorkflowAction(kind: "if", parameters: ["input": "{{previous}}", "comparison": "has value", "value": ""]), definition("calculate")!.action, definition("else")!.action, definition("number")!.action, definition("endIf")!.action, definition("storageSet")!.action, definition("show")!.action]),
        Workflow(name: "JSON Explorer", symbol: "curlybraces", color: "pink", actions: [definition("dictionary")!.action, definition("getValue")!.action, definition("show")!.action])
    ]
    public static let templates: [Workflow] = [
        Workflow(name: "Mac Assistant", symbol: "bubble.left.and.bubble.right", color: "teal", actions: [definition("phoneAssistant")!.action]),
        Workflow(name: "Desktop File Names", symbol: "desktopcomputer", color: "blue", actions: [definition("desktopNames")!.action]),
        galleryTemplates[1]
    ]
}
