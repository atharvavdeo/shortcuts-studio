import SwiftUI
import AppKit
import UserNotifications
import AVFoundation
import WorkflowCore
import UniformTypeIdentifiers

struct AppleShortcut: Identifiable {
    let id: String
    let name: String
}
struct StepLog: Identifiable {
    let id = UUID()
    let time = Date()
    let message: String
}

@MainActor final class StudioStore: ObservableObject, WorkflowHost {
    @Published var library: LibraryDocument
    @Published var selectedID: UUID?
    @Published var section = "all"
    @Published var search = ""
    @Published private var textInputs: [UUID: String] = [:]
    @Published private var enabledInputs: Set<UUID> = []
    @Published var gridView = true
    @Published var isRunning = false
    @Published var activeAction: UUID?
    @Published var completedActions: Set<UUID> = []
    @Published var runningWorkflowID: UUID?
    @Published var runStatus = "Ready"
    @Published var output: WorkflowValue = .null
    @Published var logs: [StepLog] = []
    @Published var alertMessage: String?
    @Published var loadFailure: String?
    @Published var saveFailure: String?
    @Published var appleShortcuts: [AppleShortcut] = []
    @Published var appleLoading = false
    @Published var isImporting = false
    @Published var isGenerating = false
    @Published var isDescribing = false
    @Published var isShowingMessenger = false
    lazy var messenger = MessengerConnector(store: self)
    private var remoteMode = false
    @Published var undoDocuments: [LibraryDocument] = []
    @Published var redoDocuments: [LibraryDocument] = []
    private let repository: LibraryRepository
    private var runTask: Task<Void, Never>?
    private var runID: UUID?
    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []
    private var dialogWindow: NSWindow?
    private var startupDate = Date()
    private var speech: AVSpeechSynthesizer?
    private var lastClipboardCount = NSPasteboard.general.changeCount
    private var activeApp: String?

    init(directory: URL? = nil) {
        let directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("ShortcutStudio")
        repository = LibraryRepository(url: directory.appendingPathComponent("library.json"))
        if FileManager.default.fileExists(atPath: repository.url.path) {
            do { library = try repository.load() } catch { library = LibraryDocument(); loadFailure = "Your library could not be read. It has been preserved. \(error.localizedDescription)" }
        } else {
            library = LibraryDocument(workflows: ActionCatalog.templates)
            do { try repository.save(library) } catch { saveFailure = error.localizedDescription }
        }
        selectedID = library.workflows.first?.id
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in Task { @MainActor in self?.tick() } }
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] n in
            let bundle = (n.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier
            Task { @MainActor in
                guard let self, let bundle, bundle != self.activeApp else { return }; self.activeApp = bundle
                self.fireEvent("app:\(bundle)")
            }
        })
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [weak self] n in
            let bundle = (n.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier
            Task { @MainActor in if let bundle { self?.fireEvent("quit:\(bundle)") } }
        })
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in Task { @MainActor in self?.fireEvent("sleep") } })
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in Task { @MainActor in self?.fireEvent("wake") } })
    }
    var selected: Workflow? { library.workflows.first { $0.id == selectedID } }
    var liveWorkflows: [Workflow] { library.workflows.filter { $0.deletedAt == nil } }
    var visible: [Workflow] {
        library.workflows.filter { w in
            let included: Bool
            if section == "trash" { included = w.deletedAt != nil }
            else if w.deletedAt != nil { included = false }
            else if section == "favorites" { included = w.isFavorite }
            else if section.hasPrefix("folder:"), let id = UUID(uuidString: String(section.dropFirst(7))) { included = w.folderID == id }
            else { included = true }
            return included && (search.isEmpty || w.name.localizedCaseInsensitiveContains(search) || w.actions.contains { ActionCatalog.definition($0.kind)?.title.localizedCaseInsensitiveContains(search) == true })
        }
    }
    var libraryPath: String { repository.url.path }
    var selectedTextInput: String {
        get { selectedID.flatMap { textInputs[$0] } ?? "" }
        set { if let id = selectedID, !isRunning { textInputs[id] = newValue } }
    }
    var selectedProvidesInput: Bool {
        get { selectedID.map { enabledInputs.contains($0) } ?? false }
        set { if let id = selectedID, !isRunning { if newValue { enabledInputs.insert(id) } else { enabledInputs.remove(id) } } }
    }
    func runSelected() { run(input: selectedProvidesInput ? .text(selectedTextInput) : .null) }
    var canEdit: Bool { loadFailure == nil && !isRunning && !isImporting && !isGenerating }
    func updateSelected(_ transform: (inout Workflow) -> Void, recordUndo: Bool = true) {
        guard canEdit, let index = library.workflows.firstIndex(where: { $0.id == selectedID }) else { return }
        if recordUndo { checkpoint() }
        transform(&library.workflows[index]); library.workflows[index].updatedAt = Date(); save()
    }
    func checkpoint() { undoDocuments.append(library); if undoDocuments.count > 60 { undoDocuments.removeFirst() }; redoDocuments.removeAll() }
    func save() {
        guard loadFailure == nil else { return }
        do { try repository.save(library); saveFailure = nil } catch { saveFailure = "Changes are in memory but could not be saved: \(error.localizedDescription)" }
    }
    func undo() {
        guard canEdit, let previous = undoDocuments.popLast() else { return }; redoDocuments.append(library); library = previous; save()
    }
    func redo() {
        guard canEdit, let next = redoDocuments.popLast() else { return }; undoDocuments.append(library); library = next; save()
    }
    func restoreBackup() {
        do { library = try repository.restoreBackup(); loadFailure = nil; selectedID = library.workflows.first?.id } catch { alertMessage = error.localizedDescription }
    }
    func create(_ template: Workflow? = nil) {
        guard canEdit else { return }; checkpoint(); var w = template ?? Workflow()
        if template != nil { w = w.duplicated(); w.name = template!.name }
        if section.hasPrefix("folder:") { w.folderID = UUID(uuidString: String(section.dropFirst(7))) }
        library.workflows.append(w); selectedID = w.id; if ["gallery", "apple", "automations", "history", "trash"].contains(section) { section = "all" }; save()
    }
    func duplicate() { guard let w = selected, canEdit else { return }; checkpoint(); let copy = w.duplicated(); library.workflows.append(copy); selectedID = copy.id; save() }
    func trash() { updateSelected { $0.deletedAt = Date() } }
    func restore() { updateSelected { $0.deletedAt = nil } }
    func addFolder(_ name: String) { guard canEdit, !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }; checkpoint(); library.folders.append(WorkflowFolder(name: name)); save() }
    func deleteFolder(_ id: UUID) {
        guard canEdit else { return }; checkpoint(); library.folders.removeAll { $0.id == id }
        for i in library.workflows.indices where library.workflows[i].folderID == id { library.workflows[i].folderID = nil }; section = "all"; save()
    }
    func appendAction(_ kind: String) { updateSelected { $0.actions.append(contentsOf: ActionCatalog.block(kind)) } }
    func addAction(_ kind: String, after id: UUID) { updateSelected { w in if let i = w.actions.firstIndex(where: { $0.id == id }) { w.actions.insert(contentsOf: ActionCatalog.block(kind), at: i + 1) } } }
    private func editActions(_ operation: (inout Workflow) throws -> Void) {
        guard canEdit, var candidate = selected else { return }
        do { try operation(&candidate); updateSelected { $0 = candidate } } catch { alertMessage = error.localizedDescription }
    }
    func removeAction(_ id: UUID) { editActions { try WorkflowEdits.remove(id, from: &$0) } }
    func duplicateAction(_ id: UUID) { editActions { try WorkflowEdits.duplicate(id, in: &$0) } }
    func moveAction(_ id: UUID, by offset: Int) { editActions { try WorkflowEdits.move(id, offset: offset, in: &$0) } }
    func dropAction(_ id: UUID, before target: UUID) { editActions { try WorkflowEdits.move(id, before: target, in: &$0) } }
    func parameterBinding(actionID: UUID, key: String) -> Binding<String> {
        Binding(get: { self.selected?.actions.first { $0.id == actionID }?.parameters[key] ?? "" }, set: { value in self.updateSelected { w in if let i = w.actions.firstIndex(where: { $0.id == actionID }) { w.actions[i].parameters[key] = value } } })
    }
    @discardableResult
    func run(_ workflow: Workflow? = nil, input: WorkflowValue = .null, remotely: Bool = false, completion: ((String, String) -> Void)? = nil) -> Bool {
        guard !isRunning, !isImporting && !isGenerating, loadFailure == nil, saveFailure == nil, let w = workflow ?? selected, w.deletedAt == nil else { return false }
        // Authoring undo must not rewind committed storage or trigger claims after execution.
        undoDocuments.removeAll(); redoDocuments.removeAll()
        remoteMode = remotely
        isRunning = true; runningWorkflowID = w.id; completedActions = []; activeAction = nil; output = .null; logs = []; runStatus = "Running \(w.name)…"
        let token = UUID(); runID = token; let started = Date()
        runTask = Task { [weak self] in
            guard let self else { return }
            var status = "Completed"; var final = ""
            do { let value = try await WorkflowEngine(host: self).run(w, input: input); self.output = value; final = String(value.text.prefix(4000)); self.runStatus = "Completed in \(String(format: "%.2f", Date().timeIntervalSince(started)))s" }
            catch is CancellationError { status = "Cancelled"; self.runStatus = "Stopped" }
            catch { status = "Failed"; final = error.localizedDescription; self.runStatus = "Failed"; if !remotely { self.alertMessage = final } }
            guard self.runID == token else { return }
            self.logs.append(StepLog(message: "\(status)\(final.isEmpty ? "" : ": \(String(final.prefix(180)))")"))
            self.library.history.insert(RunRecord(workflowID: w.id, workflowName: w.name, startedAt: started, duration: Date().timeIntervalSince(started), status: status, output: final), at: 0)
            if self.library.history.count > 100 { self.library.history = Array(self.library.history.prefix(100)) }
            self.isRunning = false; self.activeAction = nil; self.runTask = nil; self.remoteMode = false; self.save()
            completion?(status, remotely && status == "Failed" ? self.remoteFailure(final) : (remotely && status == "Completed" ? self.output.text : final))
        }
        return true
    }
    private func remoteFailure(_ detail: String) -> String {
        for marker in ["Accessibility", "Desktop", "approved", "Apple Intelligence", "on-device model", "not installed", "Enter a", "characters", "application window", "accessible", "app input", "submit"] where detail.localizedCaseInsensitiveContains(marker) { return String(detail.prefix(500)) }
        return "An action failed. Check the Mac run log."
    }
    func stop() { runTask?.cancel(); if let dialogWindow { dialogWindow.sheetParent?.endSheet(dialogWindow, returnCode: .cancel) }; speech?.stopSpeaking(at: .immediate) }
    func stepStarted(_ actionID: UUID, title: String) { activeAction = actionID; if logs.count >= 500 { logs.removeFirst() }; logs.append(StepLog(message: title)) }
    func stepFinished(_ actionID: UUID, output: WorkflowValue) { self.output = output; completedActions.insert(actionID) }
    func workflow(named name: String) -> Workflow? { liveWorkflows.first { $0.id.uuidString == name || $0.name == name } }
    func persistStorage(_ storage: [String: WorkflowValue], workflowID: UUID) throws {
        guard let i = library.workflows.firstIndex(where: { $0.id == workflowID }) else { throw StudioError.message("Shortcut was removed during execution.") }
        var next = library; next.workflows[i].storage = storage; try repository.save(next); library = next
    }
    func managePhoneShortcut(_ json: String, parent: Workflow) throws -> (workflow: Workflow?, text: String) {
        guard canEdit, parent.actions.count == 1, parent.actions[0].kind == "phoneAssistant", parent.actions[0].parameters["prompt"] == "{{input}}", parent.origin != "phone" else { throw StudioError.message("An approved Assistant is required for phone authoring.") }
        guard let body = try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any], Set(body.keys).isSubset(of: ["operation","id","revision","name","steps"]) else { throw StudioError.message("Invalid shortcut request.") }
        let operation = body["operation"] as? String ?? ""
        let id = (body["id"] as? String).flatMap(UUID.init(uuidString:))
        let existing = id.flatMap { id in liveWorkflows.first { $0.id == id && $0.origin == "phone" && $0.parentWorkflowID == parent.id } }
        if operation == "load" {
            guard let existing, messenger.isGranted(existing) else { throw StudioError.message("This phone shortcut is unavailable or no longer approved.") }
            let result: [String: Any] = ["kind":"shortcutLoaded","id":existing.id.uuidString,"revision":MessengerConnector.revision(existing),"name":existing.name,"steps":existing.actions.map { $0.parameters["prompt"] ?? "" }]
            return (nil, String(decoding: try JSONSerialization.data(withJSONObject: result), as: UTF8.self))
        }
        guard operation == "save", let name = body["name"] as? String, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, name.count <= 80, !name.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }),
              let steps = body["steps"] as? [String], (1...10).contains(steps.count), steps.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !$0.hasPrefix("studio.shortcut/1") }), steps.reduce(0, { $0 + $1.utf8.count }) <= 4000 else { throw StudioError.message("Use a shortcut name and 1–10 commands, up to 4,000 bytes total.") }
        if body["id"] != nil { guard let existing, body["revision"] as? String == MessengerConnector.revision(existing) else { throw StudioError.message("Shortcut changed or is unavailable. Reload it before editing.") } }
        if existing == nil && messenger.configuration.grants.count >= 50 { throw StudioError.message("The shared shortcut limit is 50. Remove an existing sharing grant before creating another.") }
        var workflow = existing ?? Workflow(name: name, symbol: "square.stack.3d.up.fill", color: "purple")
        workflow.name = name; workflow.origin = "phone"; workflow.parentWorkflowID = parent.id; workflow.updatedAt = Date()
        workflow.actions = steps.map { command in var parameters = parent.actions[0].parameters; parameters["prompt"] = command; return WorkflowAction(kind: "phoneAssistant", parameters: parameters) }
        guard MessengerConnector.policyError(workflow) == nil else { throw StudioError.message("Shortcut uses a capability that is not approved for phone sharing.") }
        var candidate = library
        if let i = candidate.workflows.firstIndex(where: { $0.id == workflow.id }) { candidate.workflows[i] = workflow } else { candidate.workflows.append(workflow) }
        try repository.save(candidate); checkpoint(); library = candidate; saveFailure = nil
        let result: [String: Any] = ["kind":"shortcutSaved","id":workflow.id.uuidString,"name":workflow.name]
        return (workflow, String(decoding: try JSONSerialization.data(withJSONObject: result), as: UTF8.self))
    }
    func perform(_ kind: String, parameters p: [String: WorkflowValue], input: WorkflowValue) async throws -> WorkflowValue {
        func s(_ key: String) -> String { p[key]?.text ?? "" }
        try Task.checkCancellation()
        if remoteMode && kind == "show" { return input }
        if remoteMode && !MessengerConnector.allowedKinds.contains(kind) { throw StudioError.message("This action requires local attention.") }
        switch kind {
        case "phoneAssistant":
            return try await PhoneAssistant.execute(s("prompt"), allowed: s("applications").split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }, desktop: s("desktop") == "true") { [weak self] text in self?.output = .text(text) }
        case "desktopNames": return try AppControl.readDesktop()
        case "appControl":
            let bundle = s("bundle")
            switch s("operation") {
            case "open": try await AppControl.open(bundle); return .text("Application opened on your Mac.")
            case "type": try await AppControl.type(s("text"), bundle: bundle, submit: false); return .text("Text entered in the Mac application.")
            case "send": return .text(try await AppControl.sendAndRead(s("text"), bundle: bundle) { [weak self] text in self?.output = .text(text) })
            default: try await AppControl.open(bundle); return .text(try AppControl.visibleText(bundle))
            }
        case "onDeviceModel":
            return .text(try await OnDeviceIntelligence.generate(prompt: s("prompt"), instructions: s("instructions")) { [weak self] text in self?.output = .text(text) })
        case "ask":
            let field = NSTextField(string: s("default")); field.frame = NSRect(x: 0, y: 0, width: 340, height: 28)
            let alert = NSAlert(); alert.messageText = s("prompt"); alert.addButton(withTitle: "Continue"); alert.addButton(withTitle: "Cancel"); alert.accessoryView = field
            guard try await present(alert) == .alertFirstButtonReturn else { throw CancellationError() }; return .text(field.stringValue)
        case "choose":
            guard !input.items.isEmpty else { throw StudioError.message("No items to choose from.") }
            let menu = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 340, height: 28), pullsDown: false); menu.addItems(withTitles: input.items.map { String($0.text.prefix(200)) })
            let alert = NSAlert(); alert.messageText = s("prompt"); alert.addButton(withTitle: "Choose"); alert.addButton(withTitle: "Cancel"); alert.accessoryView = menu
            guard try await present(alert) == .alertFirstButtonReturn else { throw CancellationError() }; return input.items[menu.indexOfSelectedItem]
        case "show", "alert":
            let alert = NSAlert(); alert.messageText = kind == "show" ? "Result" : s("title"); alert.informativeText = String((kind == "show" ? input.text : s("message")).prefix(8000)); alert.addButton(withTitle: "Continue"); alert.addButton(withTitle: "Stop")
            guard try await present(alert) == .alertFirstButtonReturn else { throw CancellationError() }; return input
        case "clipboard": return .text(NSPasteboard.general.string(forType: .string) ?? "")
        case "copy": NSPasteboard.general.clearContents(); NSPasteboard.general.setString(input.text, forType: .string); lastClipboardCount = NSPasteboard.general.changeCount; return input
        case "openURL":
            guard let url = URL(string: input.text), ["http", "https", "mailto"].contains(url.scheme?.lowercased() ?? "") else { throw StudioError.message("Only HTTP, HTTPS, and mailto URLs are supported.") }
            if s("bundle").trimmingCharacters(in: .whitespaces).isEmpty {
                guard NSWorkspace.shared.open(url) else { throw StudioError.message("No application could open this URL.") }
            } else {
                guard let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: s("bundle")) else { throw StudioError.message("Requested browser/application is not installed.") }
                try await NSWorkspace.shared.open([url], withApplicationAt: app, configuration: NSWorkspace.OpenConfiguration())
            }
            return input
        case "openApp":
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: s("bundle")) else { throw StudioError.message("Application not found.") }
            try await NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()); return .text(s("bundle"))
        case "notification":
            guard try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) else { throw StudioError.message("Notifications are not permitted.") }
            let content = UNMutableNotificationContent(); content.title = s("title"); content.body = s("message")
            try await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)); return input
        case "speak":
            let synth = AVSpeechSynthesizer(); speech = synth
            synth.speak(AVSpeechUtterance(string: input.text))
            defer { synth.stopSpeaking(at: .immediate); speech = nil }
            while synth.isSpeaking { try await Task.sleep(nanoseconds: 100_000_000) }; return input
        case "selectFile":
            let panel = NSOpenPanel(); panel.canChooseDirectories = false; panel.allowsMultipleSelection = false
            guard try await present(panel) == .OK, let url = panel.url else { throw CancellationError() }; return .text(url.path)
        case "saveFile":
            let panel = NSSavePanel(); panel.nameFieldStringValue = s("name")
            guard try await present(panel) == .OK, let url = panel.url else { throw CancellationError() }
            try Data(input.text.utf8).write(to: url, options: .atomic); return .text(url.path)
        case "appleShortcut":
            guard !s("shortcut").isEmpty else { throw StudioError.message("An Apple shortcut name or identifier is required.") }
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent("studio-bridge-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: directory) }
            let resultURL = directory.appendingPathComponent("result")
            var args = ["run", s("shortcut"), "--output-path", resultURL.path]
            if input != .null {
                let inputURL = directory.appendingPathComponent("input.txt"); try Data(input.text.utf8).write(to: inputURL, options: .atomic); args += ["--input-path", inputURL.path]
            }
            let standard = try await ProcessRunner.run("/usr/bin/shortcuts", arguments: args)
            if FileManager.default.fileExists(atPath: resultURL.path) {
                guard (try resultURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max) <= 10_000_000 else { throw StudioError.message("Apple shortcut result exceeds 10 MB.") }
                let data = try Data(contentsOf: resultURL)
                if let text = String(data: data, encoding: .utf8) { return .text(text) }
                return .dictionary(["encoding": .text("base64"), "data": .text(data.base64EncodedString())])
            }
            return .text(standard)
        default: throw StudioError.message("Unsupported action: \(kind).")
        }
    }
    private var dialogParent: NSWindow? {
        NSApp.mainWindow ?? NSApp.keyWindow?.sheetParent ?? NSApp.keyWindow ?? NSApp.windows.first { $0.isVisible && $0.canBecomeMain && !$0.isSheet }
    }
    private func present(_ alert: NSAlert) async throws -> NSApplication.ModalResponse {
        guard let window = dialogParent else { throw StudioError.message("This action requires an open app window.") }
        return try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return await withCheckedContinuation { continuation in
                dialogWindow = alert.window
                alert.beginSheetModal(for: window) { [weak self] response in self?.dialogWindow = nil; continuation.resume(returning: response) }
            }
        } onCancel: { Task { @MainActor [weak self] in if let sheet = self?.dialogWindow { sheet.sheetParent?.endSheet(sheet, returnCode: .cancel) } } }
    }
    private func present(_ panel: NSSavePanel) async throws -> NSApplication.ModalResponse {
        guard let window = dialogParent else { throw StudioError.message("This action requires an open app window.") }
        return try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return await withCheckedContinuation { continuation in dialogWindow = panel; panel.beginSheetModal(for: window) { [weak self] response in self?.dialogWindow = nil; continuation.resume(returning: response) } }
        } onCancel: { Task { @MainActor [weak self] in if let sheet = self?.dialogWindow { sheet.sheetParent?.endSheet(sheet, returnCode: .cancel) } } }
    }
    func refreshAppleShortcuts() {
        guard !appleLoading else { return }; appleLoading = true
        Task {
            defer { appleLoading = false }
            do {
                let text = try await ProcessRunner.run("/usr/bin/shortcuts", arguments: ["list", "--show-identifiers"], timeout: 20)
                let regex = try NSRegularExpression(pattern: "([0-9A-Fa-f]{8}-[0-9A-Fa-f-]{27,})")
                appleShortcuts = text.components(separatedBy: "\n").compactMap { line in
                    let ns = line as NSString; guard let match = regex.firstMatch(in: line, range: NSRange(location: 0, length: ns.length)) else { return nil }
                    let id = ns.substring(with: match.range); let name = line.replacingOccurrences(of: id, with: "").trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "()[]")))
                    return AppleShortcut(id: id, name: name)
                }
            } catch { alertMessage = error.localizedDescription }
        }
    }
    func bridge(_ shortcut: AppleShortcut) { create(Workflow(name: shortcut.name, symbol: "square.stack.3d.up.fill", color: "pink", actions: [WorkflowAction(kind: "appleShortcut", parameters: ["shortcut": shortcut.id, "input": "{{input}}"])])) }
    func openAppleEditor(_ shortcut: AppleShortcut) {
        Task { do { _ = try await ProcessRunner.run("/usr/bin/shortcuts", arguments: ["view", shortcut.name], timeout: 20) } catch { alertMessage = error.localizedDescription } }
    }
    func openHandbook() {
        guard let url = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "Handbook") else { alertMessage = "The handbook is included in the packaged app. Build with scripts/build-app.sh or open docs/HANDBOOK.md in the source checkout."; return }
        if !NSWorkspace.shared.open(url) { alertMessage = "No application could open the handbook." }
    }
    func exportSelected() {
        guard let workflow = selected else { return }; let panel = NSSavePanel(); panel.nameFieldStringValue = workflow.name + ".studio"
        panel.allowedContentTypes = [UTType(exportedAs: "tools.shortcutstudio.workflow", conformingTo: .json)]
        panel.canCreateDirectories = true
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            do { try LibraryRepository.encodeWorkflow(workflow).write(to: url, options: .atomic) } catch { self?.alertMessage = error.localizedDescription }
        }
    }
    func importFile() {
        guard canEdit else { return }; let panel = NSOpenPanel(); panel.allowsMultipleSelection = false; panel.canChooseDirectories = false
        panel.allowedContentTypes = [UTType(exportedAs: "tools.shortcutstudio.workflow", conformingTo: .json)] + ["shortcut", "wflow"].compactMap { UTType(filenameExtension: $0) }
        panel.begin { [weak self] response in guard response == .OK, let url = panel.url else { return }; self?.importURL(url) }
    }
    func importURL(_ url: URL) {
        guard canEdit else { return }
        if ["shortcut", "wflow"].contains(url.pathExtension.lowercased()) { NSWorkspace.shared.open(url); return }
        isImporting = true
        Task {
            defer { isImporting = false }
            do {
                guard (try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max) <= 20_000_000 else { throw StudioError.message("Import exceeds 20 MB.") }
                var workflow = try LibraryRepository.decodeWorkflow(Data(contentsOf: url))
                for question in workflow.questions {
                    let answer = try await perform("ask", parameters: ["prompt": .text(question.title), "default": .text(question.defaultAnswer)], input: .null)
                    if let i = workflow.actions.firstIndex(where: { $0.id == question.actionID }) { workflow.actions[i].parameters[question.parameter] = answer.text }
                }
                isImporting = false; create(workflow)
            } catch is CancellationError {} catch { alertMessage = error.localizedDescription }
        }
    }
    func addAutomation(workflowID: UUID, name: String, trigger: String, hour: Int, minute: Int, weekdays: [Int]? = nil) {
        guard canEdit, liveWorkflows.contains(where: { $0.id == workflowID }), !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, (0...23).contains(hour), (0...59).contains(minute), weekdays == nil || (!weekdays!.isEmpty && weekdays!.allSatisfy { (1...7).contains($0) }) else { return }; checkpoint(); library.automations.append(AutomationRule(workflowID: workflowID, name: name, trigger: trigger, hour: hour, minute: minute, weekdays: weekdays)); save()
    }
    func updateAutomation(_ id: UUID, workflowID: UUID, name: String, trigger: String, hour: Int, minute: Int, weekdays: [Int]?) {
        guard canEdit, let index = library.automations.firstIndex(where: { $0.id == id }), liveWorkflows.contains(where: { $0.id == workflowID }), !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        var candidate = library
        var rule = candidate.automations[index]
        if rule.trigger != trigger || rule.hour != hour || rule.minute != minute || rule.weekdays != weekdays || rule.workflowID != workflowID { rule.lastFired = nil }
        rule.workflowID = workflowID; rule.name = name; rule.trigger = trigger; rule.hour = hour; rule.minute = minute; rule.weekdays = weekdays
        candidate.automations[index] = rule
        do { try repository.save(candidate); checkpoint(); library = candidate; saveFailure = nil } catch { saveFailure = error.localizedDescription }
    }
    func toggleAutomation(_ id: UUID) { guard canEdit, let i = library.automations.firstIndex(where: { $0.id == id }) else { return }; checkpoint(); library.automations[i].isEnabled.toggle(); save() }
    func removeAutomation(_ id: UUID) { guard canEdit else { return }; checkpoint(); library.automations.removeAll { $0.id == id }; save() }
    private func tick() {
        let now = Date()
        if NSPasteboard.general.changeCount != lastClipboardCount { lastClipboardCount = NSPasteboard.general.changeCount; fireEvent("clipboard") }
        for rule in library.automations where rule.isEnabled && rule.trigger == "time" {
            guard AutomationSchedule.isDue(rule, now: now, appStartedAt: startupDate) else { continue }
            fire(rule)
        }
    }
    private func fireEvent(_ trigger: String) {
        guard !isRunning else { return }
        if let rule = library.automations.first(where: { rule in rule.isEnabled && liveWorkflows.contains(where: { $0.id == rule.workflowID }) && rule.trigger == trigger && Date().timeIntervalSince(rule.lastFired ?? .distantPast) > 10 }) { fire(rule) }
    }
    private func fire(_ rule: AutomationRule) {
        guard !isRunning, !isImporting && !isGenerating, loadFailure == nil, saveFailure == nil, let workflow = liveWorkflows.first(where: { $0.id == rule.workflowID }), let i = library.automations.firstIndex(where: { $0.id == rule.id }) else { return }
        // Claim before launching. A failed save prevents the run; no automatic replay of side effects.
        var next = library; next.automations[i].lastFired = Date()
        do { try repository.save(next); library = next; run(workflow) } catch { saveFailure = error.localizedDescription }
    }
}
