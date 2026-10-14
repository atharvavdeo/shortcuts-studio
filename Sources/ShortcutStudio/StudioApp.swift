import SwiftUI
import AppKit
import UserNotifications
import WorkflowCore

// Select the property wrapper explicitly: the macOS 27 CLT SDK also exports
// a State macro whose SwiftUIMacros plugin is not bundled with Command Line Tools.
typealias ViewState<Value> = SwiftUI.State<Value>

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) { UNUserNotificationCenter.current().delegate = self }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions { [.banner, .sound, .list] }
    private var pendingOpenURLs: [URL] = []
    var openHandler: (([URL]) -> Void)? {
        didSet {
            if let openHandler, !pendingOpenURLs.isEmpty {
                let urls = pendingOpenURLs; pendingOpenURLs.removeAll(); openHandler(urls)
            }
        }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func application(_ application: NSApplication, open urls: [URL]) {
        if let openHandler { openHandler(urls) } else { pendingOpenURLs.append(contentsOf: urls) }
    }
}

@main struct ShortcutStudioApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var store = StudioStore()
    @Environment(\.openWindow) private var openWindow
    var body: some Scene {
        WindowGroup("Shortcut Studio") {
            StudioWorkspace().environmentObject(store)
                .frame(minWidth: 900, minHeight: 640)
                .onAppear { delegate.openHandler = { urls in urls.forEach { store.importURL($0) } }; store.messenger.loadBootstrap() }
        }
        .defaultSize(width: 1380, height: 880)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Describe a Shortcut…") { store.isDescribing = true }.disabled(!store.canEdit)
                Button("New Shortcut") { store.create() }.keyboardShortcut("n").disabled(!store.canEdit)
                Button("Import Shortcut…") { store.importFile() }.keyboardShortcut("o").disabled(!store.canEdit)
                Button("Export Shortcut…") { store.exportSelected() }.keyboardShortcut("e", modifiers: [.command, .shift]).disabled(store.selected == nil)
            }
            CommandGroup(replacing: .undoRedo) {
                Button("Undo") { store.undo() }.keyboardShortcut("z").disabled(store.undoDocuments.isEmpty || !store.canEdit)
                Button("Redo") { store.redo() }.keyboardShortcut("z", modifiers: [.command, .shift]).disabled(store.redoDocuments.isEmpty || !store.canEdit)
            }
            CommandMenu("Messenger") { Button("Phone Messenger…") { openWindow(id: "messenger") } }
            CommandMenu("Shortcut") {
                Button("Run") { store.runSelected() }.keyboardShortcut("r").disabled(!store.canEdit || store.selected == nil || store.saveFailure != nil)
                Button("Stop") { store.stop() }.keyboardShortcut(".").disabled(!store.isRunning)
                Divider()
                Button("Duplicate") { store.duplicate() }.keyboardShortcut("d").disabled(!store.canEdit || store.selected == nil)
                Button("Move to Trash") { store.trash() }.disabled(!store.canEdit || store.selected == nil)
            }
            CommandGroup(replacing: .help) { Button("Shortcut Studio Handbook") { store.openHandbook() } }
            CommandGroup(replacing: .appInfo) {
                Button("About Shortcut Studio") { NSApp.orderFrontStandardAboutPanel(options: [.applicationName: "Shortcut Studio", .applicationVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development", .credits: NSAttributedString(string: "Independent workflow editor and runtime.\nApple engine integration uses the installed shortcuts command.")]) }
            }
        }
        Window("Phone Messenger", id: "messenger") {
            MessengerView(connector: store.messenger, isWindow: true).environmentObject(store)
        }.defaultSize(width: 760, height: 820)
    }
}

enum StudioStyle {
    static let colors: [String] = ["purple", "blue", "pink", "orange", "green", "red", "teal", "gray"]
    static func color(_ name: String) -> Color {
        switch name { case "blue": return .blue; case "pink": return .pink; case "orange": return .orange; case "green": return .green; case "red": return .red; case "teal": return .teal; case "gray": return .gray; default: return .purple }
    }
    // Opaque surfaces keep white labels readable in light and dark appearance.
    static let tileHex: [String: UInt32] = ["purple": 0x6236AF, "blue": 0x165DAC, "pink": 0xA52F75, "orange": 0x9B450D, "green": 0x1A6938, "red": 0xB02A38, "teal": 0x09696F, "gray": 0x55555F]
    static func tileColor(_ name: String, shade: Double = 1) -> Color {
        let rgb = tileHex[name] ?? tileHex["purple"]!
        return Color(.sRGB, red: Double((rgb >> 16) & 255) / 255 * shade, green: Double((rgb >> 8) & 255) / 255 * shade, blue: Double(rgb & 255) / 255 * shade, opacity: 1)
    }
    static let symbols = ["square.stack.3d.up.fill", "bolt.fill", "star.fill", "heart.fill", "sun.max.fill", "moon.fill", "hand.wave.fill", "list.bullet", "curlybraces", "number", "doc.text.fill", "calendar", "folder.fill", "globe", "music.note", "camera.fill", "terminal.fill", "leaf.fill"]
}

struct StudioWorkspace: View {
    @EnvironmentObject var store: StudioStore
    @ViewState private var newFolder = false
    @ViewState private var folderName = ""
    var body: some View {
        NavigationSplitView {
            List(selection: $store.section) {
                Section {
                    Label("Gallery", systemImage: "square.grid.2x2.fill").tag("gallery")
                    Label("Automation", systemImage: "clock.fill").tag("automations")
                }
                Section("Library") {
                    sidebarRow("All Shortcuts", "square.stack.fill", "all", store.liveWorkflows.count)
                    sidebarRow("Favorites", "star.fill", "favorites", store.liveWorkflows.filter(\.isFavorite).count)
                    Label("Apple Shortcuts", systemImage: "square.stack").tag("apple")
                    Label("Run History", systemImage: "clock.arrow.circlepath").tag("history")
                    sidebarRow("Trash", "trash", "trash", store.library.workflows.filter { $0.deletedAt != nil }.count)
                }
                Section("Folders") {
                    ForEach(store.library.folders) { folder in
                        sidebarRow(folder.name, "folder.fill", "folder:\(folder.id.uuidString)", store.liveWorkflows.filter { $0.folderID == folder.id }.count)
                            .contextMenu { Button("Remove Folder; Keep Shortcuts") { store.deleteFolder(folder.id) }.disabled(!store.canEdit) }
                    }
                    Button { newFolder = true } label: { Label("New Folder", systemImage: "folder.badge.plus") }.buttonStyle(.plain).disabled(!store.canEdit)
                }
                Section {
                    VStack(alignment: .leading, spacing: 4) { Text("SHORTCUT STUDIO").font(.caption2.weight(.semibold)); Text("Local workflows. Real actions.").font(.caption2) }.foregroundStyle(.secondary).padding(.vertical, 6)
                }
            }
            .listStyle(.sidebar).navigationSplitViewColumnWidth(min: 190, ideal: 210, max: 260)
        } detail: {
            VStack(spacing: 0) {
                if let failure = store.loadFailure {
                    statusBanner(failure, color: .red) { Button("Restore Backup") { store.restoreBackup() }; Button("Show Library") { NSWorkspace.shared.selectFile(store.libraryPath, inFileViewerRootedAtPath: "") } }
                }
                if let failure = store.saveFailure { statusBanner(failure, color: .orange) { Button("Retry Save") { store.save() } } }
                Group {
                    switch store.section {
                    case "gallery": GalleryView()
                    case "apple": AppleLibraryView()
                    case "automations": AutomationView()
                    case "history": HistoryView()
                    default:
                        GeometryReader { geometry in
                            if geometry.size.width >= 900 {
                                HSplitView { WorkflowLibraryView().frame(minWidth: 240, idealWidth: 330, maxWidth: 420); WorkflowEditorView().frame(minWidth: 660) }
                            } else {
                                VStack(spacing: 0) {
                                    HStack {
                                        Picker("Shortcut", selection: $store.selectedID) {
                                            Text("Choose a Shortcut").tag(Optional<UUID>.none)
                                            ForEach(store.visible) { Text($0.name).tag(Optional($0.id)) }
                                        }.accessibilityLabel("Select Shortcut")
                                        TextField("Search shortcuts", text: $store.search).textFieldStyle(.roundedBorder).frame(maxWidth: 240)
                                    }.padding(12)
                                    Divider()
                                    WorkflowEditorView().frame(minWidth: 660)
                                }
                            }
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItemGroup {
                    Button("Describe a Shortcut", systemImage: "sparkles") { store.isDescribing = true }.disabled(!store.canEdit)
                    Button { store.importFile() } label: { Image(systemName: "square.and.arrow.down") }.help("Import shortcut").accessibilityLabel("Import Shortcut").disabled(!store.canEdit)
                    Button { store.create() } label: { Image(systemName: "plus") }.help("New shortcut").accessibilityLabel("New Shortcut").disabled(!store.canEdit)
                    Button { store.exportSelected() } label: { Image(systemName: "square.and.arrow.up") }.help("Export shortcut").accessibilityLabel("Export Shortcut").disabled(store.selected == nil)
                }
            }
        }
        .onChange(of: store.section) { _, section in
            if section == "all" || section == "favorites" || section == "trash" || section.hasPrefix("folder:") {
                if !store.visible.contains(where: { $0.id == store.selectedID }) { store.selectedID = store.visible.first?.id }
            }
        }
        .tint(.accentColor)
        .alert("Shortcut Studio", isPresented: Binding(get: { store.alertMessage != nil }, set: { if !$0 { store.alertMessage = nil } })) { Button("OK") { store.alertMessage = nil } } message: { Text(store.alertMessage ?? "") }
        .sheet(isPresented: $store.isDescribing) { ModelDraftView().environmentObject(store) }
        .sheet(isPresented: $newFolder) {
            VStack(alignment: .leading, spacing: 20) {
                Text("New Folder").font(.title2.bold()); TextField("Folder name", text: $folderName).textFieldStyle(.roundedBorder)
                HStack { Button("Cancel") { newFolder = false }; Spacer(); Button("Create") { store.addFolder(folderName); folderName = ""; newFolder = false }.keyboardShortcut(.defaultAction).disabled(folderName.trimmingCharacters(in: .whitespaces).isEmpty) }
            }.padding(24).frame(width: 360)
        }
    }
    func sidebarRow(_ title: String, _ symbol: String, _ tag: String, _ count: Int) -> some View {
        HStack { Label(title, systemImage: symbol); Spacer(); Text("\(count)").foregroundStyle(.secondary).font(.caption) }.tag(tag)
    }
    func statusBanner<Content: View>(_ text: String, color: Color, @ViewBuilder controls: () -> Content) -> some View {
        HStack { Image(systemName: "exclamationmark.triangle.fill"); Text(text).font(.caption); Spacer(); controls() }.padding(10).background(color.opacity(0.15))
    }
}

struct WorkflowLibraryView: View {
    @EnvironmentObject var store: StudioStore
    private var title: String {
        if store.section == "favorites" { return "Favorites" }; if store.section == "trash" { return "Trash" }
        if store.section.hasPrefix("folder:"), let id = UUID(uuidString: String(store.section.dropFirst(7))) { return store.library.folders.first { $0.id == id }?.name ?? "Folder" }; return "All Shortcuts"
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack { Text(title).font(.title2.bold()); Spacer(); Button { store.gridView.toggle() } label: { Image(systemName: store.gridView ? "list.bullet" : "square.grid.2x2") }.buttonStyle(.borderless) }
            TextField("Search shortcuts", text: $store.search).textFieldStyle(.roundedBorder)
            ScrollView {
                if store.visible.isEmpty { ContentUnavailableView("No Shortcuts", systemImage: "square.stack", description: Text("Create a shortcut or add one from the Gallery.")) }
                LazyVGrid(columns: store.gridView ? [GridItem(.flexible()), GridItem(.flexible())] : [GridItem(.flexible())], spacing: 10) {
                    ForEach(store.visible) { workflow in
                        Button { store.selectedID = workflow.id } label: {
                            ShortcutTile(workflow: workflow, selected: store.selectedID == workflow.id, compact: !store.gridView)
                        }.buttonStyle(.plain).help("Open \(workflow.name)")
                            .contextMenu {
                                Button("Run") { store.run(workflow) }.disabled(store.isRunning || workflow.deletedAt != nil)
                                Button("Duplicate") { store.selectedID = workflow.id; store.duplicate() }.disabled(!store.canEdit)
                                Button(workflow.deletedAt == nil ? "Move to Trash" : "Restore") { store.selectedID = workflow.id; if workflow.deletedAt == nil { store.trash() } else { store.restore() } }.disabled(!store.canEdit)
                            }
                    }
                }
            }
            Text("\(store.visible.count) shortcuts").font(.caption).foregroundStyle(.secondary)
        }.padding(20).background(Color(nsColor: .windowBackgroundColor))
    }
}

struct ShortcutTile: View {
    let workflow: Workflow
    var selected = false
    var compact = false
    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 10 : 22) {
            HStack { Image(systemName: workflow.symbol).font(.title3.weight(.semibold)); Spacer(); if workflow.isFavorite { Image(systemName: "star.fill").font(.caption) } }
            Text(workflow.name).font(.system(size: 14, weight: .semibold)).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
            if !compact { Text("\(workflow.actions.count) actions").font(.caption2).foregroundStyle(.white) }
        }
        .foregroundStyle(.white).padding(14).frame(maxWidth: .infinity, minHeight: compact ? 85 : 130, alignment: .topLeading)
        .background(LinearGradient(colors: [StudioStyle.tileColor(workflow.color), StudioStyle.tileColor(workflow.color, shade: 0.8)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(selected ? Color.primary : Color.clear, lineWidth: 2)).contentShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(workflow.name), \(workflow.actions.count) actions")
        .accessibilityValue(selected ? "Selected" : "")
    }
}

struct WorkflowEditorView: View {
    @EnvironmentObject var store: StudioStore
    @ViewState private var inspector = "Actions"
    @ViewState private var showOutput = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        if let workflow = store.selected {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: workflow.symbol).font(.title2).foregroundStyle(StudioStyle.color(workflow.color))
                    TextField("Shortcut name", text: Binding(get: { store.selected?.name ?? "" }, set: { value in store.updateSelected { $0.name = value } })).font(.title3.weight(.semibold)).textFieldStyle(.plain).disabled(!store.canEdit)
                    Spacer()
                    StudioGlassControls { HStack(spacing: 10) {
                    if workflow.deletedAt != nil { Button("Restore") { store.restore() }.disabled(!store.canEdit) }
                    Button { store.updateSelected { $0.isFavorite.toggle() } } label: { Image(systemName: workflow.isFavorite ? "star.fill" : "star") }.studioGlassButton().accessibilityLabel(workflow.isFavorite ? "Remove from Favorites" : "Add to Favorites").disabled(!store.canEdit)
                    Button { store.duplicate() } label: { Image(systemName: "doc.on.doc") }.studioGlassButton().help("Duplicate shortcut").accessibilityLabel("Duplicate Shortcut").disabled(!store.canEdit)
                    Button { if store.isRunning { store.stop() } else { store.runSelected() } } label: { Label(store.isRunning ? "Stop" : "Run", systemImage: store.isRunning ? "stop.fill" : "play.fill") }.studioGlassButton(prominent: true).disabled(workflow.deletedAt != nil || store.loadFailure != nil || store.saveFailure != nil)
                    } }
                }.padding(18)
                Divider()
                HSplitView {
                    VStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Toggle("Text Input", isOn: $store.selectedProvidesInput).toggleStyle(.switch).controlSize(.small).disabled(store.isRunning)
                                Spacer()
                                if store.selectedProvidesInput { Text("\(store.selectedTextInput.count) characters").font(.caption2).foregroundStyle(.secondary) }
                                Button { showOutput.toggle() } label: { Image(systemName: "terminal") }.studioGlassIcon().help("Show run output").accessibilityLabel("Toggle Run Output")
                            }
                            if store.selectedProvidesInput {
                                TextEditor(text: $store.selectedTextInput).font(.system(size: 12, design: .monospaced)).frame(height: 76)
                                    .scrollContentBackground(.hidden).padding(6)
                                    .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                                    .accessibilityLabel("Shortcut text input").disabled(store.isRunning)
                                Text("Passed as Text, including line breaks. An empty field passes empty Text.").font(.caption2).foregroundStyle(.secondary)
                            }
                        }.font(.caption).padding(12)
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: store.selectedProvidesInput)
                        Divider()
                        ScrollViewReader { proxy in
                            ScrollView {
                                VStack(spacing: 12) {
                                    if workflow.actions.isEmpty {
                                        ContentUnavailableView("Build Your Shortcut", systemImage: "square.stack.3d.up", description: Text("Add actions from the library on the right.\nEach action passes its result to the next."))
                                            .padding(.top, 90)
                                    }
                                    ForEach(Array(workflow.actions.enumerated()), id: \.element.id) { index, action in
                                        ActionCard(action: action, index: index, preceding: Array(workflow.actions.prefix(index)))
                                            .padding(.leading, CGFloat(WorkflowValidator.indentation(workflow.actions, at: index)) * 18)
                                            .id(action.id)
                                            .draggable(action.id.uuidString)
                                            .dropDestination(for: String.self) { items, _ in guard let string = items.first, let id = UUID(uuidString: string) else { return false }; store.dropAction(id, before: action.id); return true }
                                    }
                                    if !workflow.actions.isEmpty { Text("End of shortcut").font(.caption).foregroundStyle(.tertiary).padding(.vertical, 14) }
                                }.padding(20)
                            }.background(Color(nsColor: .underPageBackgroundColor))
                            .onChange(of: store.activeAction) { _, id in if let id, store.runningWorkflowID == workflow.id { withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) { proxy.scrollTo(id, anchor: .center) } } }
                            .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.85), value: workflow.actions.map(\.id))
                        }
                        let issues = WorkflowValidator.validate(workflow)
                        if !issues.isEmpty { VStack(alignment: .leading, spacing: 4) { ForEach(issues.prefix(3)) { issue in Label("Action \(issue.index + 1): \(issue.message)", systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(.orange) } }.frame(maxWidth: .infinity, alignment: .leading).padding(12).background(.orange.opacity(0.08)) }
                        if showOutput { OutputPanel().frame(minHeight: 150, maxHeight: 240) }
                    }.frame(minWidth: 370)
                    VStack(spacing: 0) {
                        Picker("Inspector", selection: $inspector) { Text("Actions").tag("Actions"); Text("Details").tag("Details"); Text("Storage").tag("Storage"); Text("Setup").tag("Setup") }.pickerStyle(.segmented).labelsHidden().padding(12)
                        Divider()
                        switch inspector { case "Details": DetailsInspector(); case "Storage": StorageInspector(); case "Setup": SetupInspector(); default: ActionBrowser() }
                    }.frame(minWidth: 280, idealWidth: 305, maxWidth: 360).background(Color(nsColor: .controlBackgroundColor))
                }
            }
        } else { ContentUnavailableView("Select a Shortcut", systemImage: "square.stack.3d.up", description: Text("Choose a shortcut from your library, or create a new one.")) }
    }
}

struct ActionCard: View {
    @EnvironmentObject var store: StudioStore
    let action: WorkflowAction
    let index: Int
    let preceding: [WorkflowAction]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ViewState private var expanded = true
    var body: some View {
        let definition = ActionCatalog.definition(action.kind)
        let current = store.runningWorkflowID == store.selectedID
        let active = current && store.activeAction == action.id
        let completed = current && store.completedActions.contains(action.id)
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: definition?.symbol ?? "questionmark.square").foregroundStyle(.purple).font(.title3).frame(width: 25)
                Text(definition?.title ?? action.kind).font(.system(size: 14, weight: .semibold))
                Spacer()
                if active { ProgressView().controlSize(.small).accessibilityLabel("Action running") } else if completed { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).accessibilityLabel("Action completed") }
                Text("\(index + 1)").font(.caption.monospacedDigit()).foregroundStyle(.tertiary)
                if !(definition?.parameters.isEmpty ?? true) { Button { expanded.toggle() } label: { Image(systemName: expanded ? "chevron.up" : "chevron.down") }.accessibilityLabel(expanded ? "Collapse Action" : "Expand Action").buttonStyle(.borderless) }
                Menu {
                    Button("Move Up") { store.moveAction(action.id, by: -1) }.disabled(index == 0)
                    Button("Move Down") { store.moveAction(action.id, by: 1) }
                    Button("Duplicate Action") { store.duplicateAction(action.id) }
                    Menu("Insert Action Below") { ForEach(ActionCatalog.definitions.filter { !["else", "endIf", "endRepeat"].contains($0.kind) }) { d in Button(d.title) { store.addAction(d.kind, after: action.id) } } }
                    if !["if", "else", "endIf", "repeat", "repeatEach", "endRepeat"].contains(action.kind) {
                        Button(action.isEnabled ? "Disable Action" : "Enable Action") { store.updateSelected { w in if let i = w.actions.firstIndex(where: { $0.id == action.id }) { w.actions[i].isEnabled.toggle() } } }
                    }
                    Divider(); Button("Remove Action", role: .destructive) { store.removeAction(action.id) }
                } label: { Image(systemName: "ellipsis") }.accessibilityLabel("Action Options").menuStyle(.borderlessButton).fixedSize().disabled(!store.canEdit)
            }
            if expanded, let definition {
                ForEach(definition.parameters) { parameter in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(parameter.title).font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            ReferenceMenu(binding: store.parameterBinding(actionID: action.id, key: parameter.key), preceding: preceding)
                        }
                        if !parameter.choices.isEmpty {
                            Picker(parameter.title, selection: store.parameterBinding(actionID: action.id, key: parameter.key)) { ForEach(parameter.choices, id: \.self) { Text($0).tag($0) } }.labelsHidden()
                        } else if ["text", "items", "json", "body", "headers", "prompt", "instructions"].contains(parameter.key) {
                            TextEditor(text: store.parameterBinding(actionID: action.id, key: parameter.key))
                                .font(.system(size: 12, design: .monospaced)).scrollContentBackground(.hidden)
                                .padding(6).frame(height: parameter.key == "items" || parameter.key == "json" ? 88 : 65)
                                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
                                .accessibilityLabel(parameter.title)
                        } else {
                            TextField(parameter.title, text: store.parameterBinding(actionID: action.id, key: parameter.key), axis: .vertical).textFieldStyle(.roundedBorder).lineLimit(1...8)
                        }
                    }
                }.disabled(!store.canEdit)
            }
        }.padding(14)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(active ? Color.purple : Color.primary.opacity(0.06), lineWidth: active ? 2 : 1))
            .scaleEffect(active && !reduceMotion ? 1.012 : 1)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: active)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: expanded)
            .opacity(action.isEnabled ? 1 : 0.45)
    }
}

struct ReferenceMenu: View {
    @Binding var binding: String
    let preceding: [WorkflowAction]
    @EnvironmentObject var store: StudioStore
    func insert(_ token: String) { binding = binding.isEmpty || binding == "{{previous}}" ? token : binding + token }
    var body: some View {
        Menu {
            Button("Previous Output") { insert("{{previous}}") }
            Button("Shortcut Input") { insert("{{input}}") }
            Button("Repeat Item") { insert("{{repeatItem}}") }
            Button("Repeat Index") { insert("{{repeatIndex}}") }
            Divider()
            ForEach(Array(preceding.enumerated()), id: \.element.id) { index, action in
                Button("\(index + 1). \(ActionCatalog.definition(action.kind)?.title ?? action.kind)") { insert("{{output:\(action.id.uuidString)}}") }
            }
            let names = Array(Set(preceding.filter { $0.kind == "setVariable" }.compactMap { $0.parameters["name"] })).sorted()
            if !names.isEmpty { Divider(); ForEach(names, id: \.self) { name in Button("Variable: \(name)") { insert("{{variable:\(name)}}") } } }
            if let workflow = store.selected, !workflow.storage.isEmpty { Divider(); ForEach(workflow.storage.keys.sorted(), id: \.self) { key in Button("Stored: \(key)") { insert("{{storage:\(key)}}") } } }
        } label: { Image(systemName: "tag").font(.caption) }.menuStyle(.borderlessButton).fixedSize().help("Insert a value reference").accessibilityLabel("Insert Value Reference")
    }
}

struct ActionBrowser: View {
    @EnvironmentObject var store: StudioStore
    @ViewState private var query = ""
    @ViewState private var category = "All Actions"
    var definitions: [ActionDefinition] { ActionCatalog.definitions.filter { (category == "All Actions" || $0.category == category) && (query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) || $0.detail.localizedCaseInsensitiveContains(query)) } }
    var body: some View {
        VStack(spacing: 12) {
            TextField("Search actions", text: $query).textFieldStyle(.roundedBorder).padding(.horizontal, 12).padding(.top, 12)
            Picker("Category", selection: $category) { ForEach(ActionCatalog.categories, id: \.self) { Text($0).tag($0) } }.padding(.horizontal, 12)
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(definitions) { definition in
                        Button { store.appendAction(definition.kind) } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: definition.symbol).font(.title3).foregroundStyle(.purple).frame(width: 25)
                                VStack(alignment: .leading, spacing: 4) { Text(definition.title).font(.system(size: 13, weight: .medium)); Text(definition.detail).font(.caption2).foregroundStyle(.secondary).lineLimit(3) }
                                Spacer(minLength: 0); Image(systemName: "plus").font(.caption).foregroundStyle(.tertiary)
                            }.padding(12).contentShape(Rectangle())
                        }.buttonStyle(.plain).disabled(!store.canEdit)
                        Divider().padding(.leading, 48)
                    }
                }
            }
            Text("\(definitions.count) actions · click to add").font(.caption2).foregroundStyle(.secondary).padding(.bottom, 12)
        }
    }
}

struct DetailsInspector: View {
    @EnvironmentObject var store: StudioStore
    var body: some View {
        if let workflow = store.selected {
            Form {
                Section("Appearance") {
                    Picker("Color", selection: Binding(get: { workflow.color }, set: { v in store.updateSelected { $0.color = v } })) { ForEach(StudioStyle.colors, id: \.self) { name in Label(name.capitalized, systemImage: "circle.fill").foregroundStyle(StudioStyle.color(name)).tag(name) } }
                    Picker("Icon", selection: Binding(get: { workflow.symbol }, set: { v in store.updateSelected { $0.symbol = v } })) { ForEach(StudioStyle.symbols, id: \.self) { symbol in Label(symbol, systemImage: symbol).tag(symbol) } }
                    Picker("Folder", selection: Binding(get: { workflow.folderID?.uuidString ?? "none" }, set: { v in store.updateSelected { $0.folderID = UUID(uuidString: v) } })) {
                        Text("None").tag("none"); ForEach(store.library.folders) { f in Text(f.name).tag(f.id.uuidString) }
                    }
                    Toggle("Favorite", isOn: Binding(get: { workflow.isFavorite }, set: { v in store.updateSelected { $0.isFavorite = v } }))
                }
                Section("Execution") {
                    Text("Runs locally. Interactive actions use native dialogs. Only one workflow runs at a time.").font(.caption).foregroundStyle(.secondary)
                    Text("Nested shortcut depth: 16. Repeat limit: 1,000. Execution limit: 10,000 steps.").font(.caption).foregroundStyle(.secondary)
                }
                Section("Integration") {
                    Text("Use Run Apple Shortcut for actions supplied by Apple or installed apps. Studio files have their own JSON format.").font(.caption).foregroundStyle(.secondary)
                    Text("Siri, widgets, Finder Quick Actions, Share Sheet extensions, and iCloud sync are not provided by this build.").font(.caption).foregroundStyle(.secondary)
                }
                Button("Move to Trash", role: .destructive) { store.trash() }
                Text(workflow.id.uuidString).font(.caption2.monospaced()).textSelection(.enabled).foregroundStyle(.tertiary)
            }.formStyle(.grouped).disabled(!store.canEdit)
        }
    }
}

struct StorageInspector: View {
    @EnvironmentObject var store: StudioStore
    @ViewState private var key = ""
    @ViewState private var value = ""
    @ViewState private var error = ""
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Stored Values").font(.headline)
                Text("Values survive future runs. Importing a Studio shortcut includes its stored values, so review them before sharing.").font(.caption).foregroundStyle(.secondary)
                if let workflow = store.selected {
                    ForEach(workflow.storage.keys.sorted(), id: \.self) { name in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack { Text(name).font(.subheadline.bold()); Spacer(); Button { key = name; value = workflow.storage[name]!.jsonText } label: { Image(systemName: "pencil") }; Button { store.updateSelected { $0.storage.removeValue(forKey: name) } } label: { Image(systemName: "minus.circle") } }
                            Text(workflow.storage[name]!.text).font(.caption.monospaced()).lineLimit(5).textSelection(.enabled)
                            Text(workflow.storage[name]!.typeName).font(.caption2).foregroundStyle(.tertiary)
                        }.padding(10).background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                    }
                }
                Divider(); TextField("Key", text: $key).textFieldStyle(.roundedBorder)
                TextField("JSON value or plain text", text: $value, axis: .vertical).textFieldStyle(.roundedBorder).lineLimit(2...8)
                Text("Valid JSON keeps its type. Plain text is stored as text.").font(.caption2).foregroundStyle(.secondary)
                Button("Save Value") {
                    guard !key.isEmpty else { error = "A key is required."; return }
                    let stored = (try? WorkflowValue.fromJSON(Data(value.utf8))) ?? .text(value)
                    store.updateSelected { $0.storage[key] = stored }; key = ""; value = ""; error = ""
                }
                if !error.isEmpty { Text(error).font(.caption).foregroundStyle(.red) }
            }.padding(16).disabled(!store.canEdit)
        }
    }
}

struct SetupInspector: View {
    @EnvironmentObject var store: StudioStore
    @ViewState private var title = ""
    @ViewState private var actionID = ""
    @ViewState private var parameter = ""
    @ViewState private var answer = ""
    var selectedAction: WorkflowAction? { store.selected?.actions.first { $0.id.uuidString == actionID } }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Import Questions").font(.headline)
                Text("Ask these questions when someone imports this shortcut. Answers fill the action parameters.").font(.caption).foregroundStyle(.secondary)
                if let workflow = store.selected {
                    ForEach(workflow.questions) { q in HStack { VStack(alignment: .leading) { Text(q.title).font(.subheadline); Text(q.parameter).font(.caption2).foregroundStyle(.secondary) }; Spacer(); Button { store.updateSelected { $0.questions.removeAll { $0.id == q.id } } } label: { Image(systemName: "minus.circle") } } }
                    Divider()
                    TextField("Question", text: $title).textFieldStyle(.roundedBorder)
                    Picker("Action", selection: $actionID) { Text("Select action").tag(""); ForEach(workflow.actions.filter { !$0.parameters.isEmpty }) { a in Text(ActionCatalog.definition(a.kind)?.title ?? a.kind).tag(a.id.uuidString) } }
                    Picker("Parameter", selection: $parameter) { Text("Select parameter").tag(""); if let a = selectedAction { ForEach(a.parameters.keys.sorted(), id: \.self) { Text($0).tag($0) } } }
                    TextField("Default answer", text: $answer).textFieldStyle(.roundedBorder)
                    Button("Add Question") {
                        guard let id = UUID(uuidString: actionID) else { return }; store.updateSelected { $0.questions.append(ImportQuestion(title: title, actionID: id, parameter: parameter, defaultAnswer: answer)) }; title = ""; answer = ""
                    }.disabled(title.isEmpty || selectedAction?.parameters[parameter] == nil)
                }
            }.padding(16).disabled(!store.canEdit)
        }.onChange(of: actionID) { _, _ in parameter = "" }
    }
}

struct OutputPanel: View {
    @EnvironmentObject var store: StudioStore
    @ViewState private var tab = "Result"
    var body: some View {
        let belongsToSelection = store.runningWorkflowID == store.selectedID
        let output = belongsToSelection ? store.output : .null
        let status = belongsToSelection ? store.runStatus : (store.isRunning ? "Another shortcut is running…" : "Ready")
        VStack(alignment: .leading, spacing: 8) {
            HStack { Circle().fill(store.isRunning ? .orange : store.runStatus == "Failed" ? .red : .green).frame(width: 6, height: 6); Text(status).font(.caption); Spacer(); Picker("Output", selection: $tab) { Text("Result").tag("Result"); Text("Log").tag("Log") }.pickerStyle(.segmented).labelsHidden().frame(width: 120); Text(output.typeName).font(.caption2).foregroundStyle(.secondary) }
            ScrollView {
                if tab == "Result" { Text(output == .null ? "Run this shortcut to see its output." : String(output.jsonText.prefix(20_000))).font(.system(size: 12, design: .monospaced)).frame(maxWidth: .infinity, alignment: .topLeading).textSelection(.enabled) }
                else { VStack(alignment: .leading, spacing: 5) { ForEach(belongsToSelection ? store.logs : []) { entry in HStack(alignment: .top) { Text(entry.time, style: .time).foregroundStyle(.tertiary); Text(entry.message) }.font(.caption.monospaced()) } }.frame(maxWidth: .infinity, alignment: .leading) }
            }
        }.padding(12).background(Color(nsColor: .textBackgroundColor)).overlay(alignment: .top) { Divider() }
    }
}

struct GalleryView: View {
    @EnvironmentObject var store: StudioStore
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Do more.\nOne shortcut at a time.").font(.system(size: 42, weight: .bold, design: .rounded))
                    Text("Useful starting points you can make your own.").font(.title3).foregroundStyle(.secondary)
                }.padding(.vertical, 16)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 230, maximum: 320))], spacing: 20) {
                    ForEach(ActionCatalog.templates) { workflow in VStack(alignment: .leading, spacing: 10) { ShortcutTile(workflow: workflow); Text(workflow.actions.compactMap { ActionCatalog.definition($0.kind)?.title }.joined(separator: " → ")).font(.caption).foregroundStyle(.secondary).lineLimit(3); Button("Add Shortcut") { store.create(workflow) }.disabled(!store.canEdit) } }
                }
                Text("All templates run in Studio. Review actions before running imported workflows.").font(.caption).foregroundStyle(.secondary)
            }.padding(36)
        }
    }
}

struct AppleLibraryView: View {
    @EnvironmentObject var store: StudioStore
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack { VStack(alignment: .leading, spacing: 8) { Text("Apple Shortcuts").font(.largeTitle.bold()); Text("Use workflows already installed in Apple's app through its supported command-line engine.").foregroundStyle(.secondary) }; Spacer(); Button("Refresh") { store.refreshAppleShortcuts() }.disabled(store.appleLoading) }
            if store.appleLoading { ProgressView("Reading Apple library…") }
            List(store.appleShortcuts) { shortcut in
                HStack { Image(systemName: "square.stack.3d.up.fill").foregroundStyle(.pink); Text(shortcut.name); Spacer(); Button("Open in Apple Shortcuts") { store.openAppleEditor(shortcut) }; Button("Add to Studio") { store.bridge(shortcut) }.disabled(!store.canEdit) }.padding(.vertical, 6)
            }
            Text("Apple workflows stay in Apple's library. Studio passes text input and receives text or Base64 binary output. Stopping the command cannot guarantee reversal of actions already performed by Apple's engine.").font(.caption).foregroundStyle(.secondary)
        }.padding(28).onAppear { store.refreshAppleShortcuts() }
    }
}

struct HistoryView: View {
    @EnvironmentObject var store: StudioStore
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Run History").font(.largeTitle.bold())
            Text("The latest 100 runs. Outputs may contain personal data and are stored locally.").foregroundStyle(.secondary)
            List(store.library.history) { record in
                DisclosureGroup {
                    Text(record.output.isEmpty ? "No output" : record.output).font(.caption.monospaced()).textSelection(.enabled).padding(.vertical, 8)
                } label: {
                    HStack { Image(systemName: record.status == "Completed" ? "checkmark.circle.fill" : record.status == "Cancelled" ? "stop.circle" : "exclamationmark.circle.fill").foregroundStyle(record.status == "Completed" ? .green : .orange); VStack(alignment: .leading) { Text(record.workflowName); Text(record.startedAt.formatted()).font(.caption).foregroundStyle(.secondary) }; Spacer(); Text(record.status).font(.caption); Text(String(format: "%.2fs", record.duration)).font(.caption.monospacedDigit()).foregroundStyle(.secondary) }
                }
            }
        }.padding(28)
    }
}

struct ModelDraftView: View {
    @EnvironmentObject var store: StudioStore
    @Environment(\.dismiss) private var dismiss
    @ViewState private var description = ""
    @ViewState private var draft: Workflow?
    @ViewState private var error: String?
    @ViewState private var task: Task<Void, Never>?
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Describe a Shortcut").font(.title2.bold())
            Text(OnDeviceIntelligence.status).font(.caption).foregroundStyle(.secondary)
            Text("What would you like your shortcut to do?").font(.headline)
            TextEditor(text: $description).font(.body).scrollContentBackground(.hidden).padding(8).accessibilityLabel("Describe your shortcut").frame(height: 118).background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 10)).disabled(store.isGenerating)
            HStack {
                Button("Greeting") { description = "Create a shortcut that asks for my name, creates a friendly greeting using the previous answer, and shows it." }
                Button("Summarize Input") { description = "Create a shortcut that uses the on-device model to summarize shortcut input in three bullet points, then shows the response." }
                Button("Text List") { description = "Create a shortcut that splits shortcut input into lines, removes duplicates, combines the lines, and shows the result." }
            }.controlSize(.small).disabled(store.isGenerating)
            Text("\(description.count)/1,500 characters").font(.caption2).foregroundStyle(.secondary)
            Text("Apple’s on-device model drafts actions. Review parameters in the editor before running.").font(.caption).foregroundStyle(.secondary)
            if let error { Text(error).font(.caption).foregroundStyle(.red).lineLimit(6).help(error).textSelection(.enabled) }
            if let draft {
                Text(draft.name).font(.headline)
                ScrollView { VStack(alignment: .leading, spacing: 8) { ForEach(draft.actions) { action in
                    VStack(alignment: .leading) { Text(ActionCatalog.definition(action.kind)?.title ?? action.kind).bold(); Text(action.parameters.sorted { $0.key < $1.key }.map { "\($0.key): \($0.value)" }.joined(separator: "\n")).font(.caption).textSelection(.enabled) }
                } } }.padding(12).frame(height: 180).frame(maxWidth: .infinity, alignment: .leading).background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
            }
            HStack {
                Button("Cancel") { task?.cancel(); dismiss() }
                Spacer()
                if store.isGenerating { ProgressView().controlSize(.small) }
                Button("Generate Draft") {
                    draft = nil; error = nil; store.isGenerating = true
                    task = Task { @MainActor in
                        defer { store.isGenerating = false; task = nil }
                        do { let generated = try await OnDeviceIntelligence.draft(description: description); try Task.checkCancellation(); draft = generated }
                        catch is CancellationError {} catch { self.error = error.localizedDescription }
                    }
                }.disabled(store.isGenerating || description.count > 1500 || description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button("Add to Library") { if let draft { store.create(draft); dismiss() } }.disabled(draft == nil || store.isGenerating)
            }
        }.padding(24).frame(width: 620)
        .onDisappear { task?.cancel() }
    }
}
