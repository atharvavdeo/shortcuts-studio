import SwiftUI
import WorkflowCore

struct AutomationPreset: Identifiable {
    var id: String { trigger }
    let title: String
    let symbol: String
    let trigger: String
    let detail: String
    static let all: [Self] = [
        .init(title: "Time of Day", symbol: "clock.fill", trigger: "time", detail: "Every day or selected weekdays"),
        .init(title: "App Activates", symbol: "app.fill", trigger: "app", detail: "When an app comes to the front"),
        .init(title: "App Quits", symbol: "app.badge", trigger: "quit", detail: "When an app terminates"),
        .init(title: "Mac Wakes", symbol: "sun.max.fill", trigger: "wake", detail: "When the Mac wakes from sleep"),
        .init(title: "Mac Sleeps", symbol: "moon.fill", trigger: "sleep", detail: "Before sleep; completion may be suspended"),
        .init(title: "Clipboard Changes", symbol: "doc.on.clipboard", trigger: "clipboard", detail: "Detect text or other clipboard changes")
    ]
}

struct AutomationView: View {
    @EnvironmentObject var store: StudioStore
    @ViewState private var selectedPreset: AutomationPreset?
    @ViewState private var editingRule: AutomationRule?
    private let dayLabels = [(1, "Sun"), (2, "Mon"), (3, "Tue"), (4, "Wed"), (5, "Thu"), (6, "Fri"), (7, "Sat")]
    private func configure(_ preset: AutomationPreset) { selectedPreset = preset }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack { Text("Automation").font(.largeTitle.bold()); Spacer(); Button("New Automation", systemImage: "plus") { configure(AutomationPreset.all[0]) }.studioGlassButton(prominent: true).disabled(!store.canEdit || store.liveWorkflows.isEmpty) }
            Text("Run a shortcut when an event happens. Studio must be open; busy runs skip other triggers. Time triggers use a 60-second window.").foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(AutomationPreset.all) { preset in
                    Button { configure(preset) } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Label(preset.title, systemImage: preset.symbol).font(.headline)
                            Text(preset.detail).font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                        }.padding(14).frame(maxWidth: .infinity, minHeight: 75, alignment: .leading)
                    }.buttonStyle(.bordered).disabled(!store.canEdit || store.liveWorkflows.isEmpty)
                }
            }
            Text("Your Automations").font(.title3.bold())
            if store.library.automations.isEmpty { ContentUnavailableView("No Automations Yet", systemImage: "bolt.circle", description: Text("Choose a trigger above and select a shortcut.")) }
            List {
                ForEach(store.library.automations) { rule in
                    HStack(spacing: 14) {
                        Image(systemName: AutomationPreset.all.first { rule.trigger == $0.trigger || rule.trigger.hasPrefix($0.trigger + ":") }?.symbol ?? "bolt").foregroundStyle(.purple).font(.title2)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(rule.name).font(.headline)
                            Text("\(description(rule)) → \(store.library.workflows.first { $0.id == rule.workflowID }?.name ?? "Missing shortcut")").font(.caption).foregroundStyle(.secondary)
                            if let date = rule.lastFired { Text("Last triggered: \(date.formatted())").font(.caption2).foregroundStyle(.secondary) }
                        }
                        Spacer()
                        Button("Edit") { editingRule = rule }.disabled(!store.canEdit)
                        Button("Test Run") { if let w = store.liveWorkflows.first(where: { $0.id == rule.workflowID }) { store.run(w) } }.disabled(!store.canEdit || !store.liveWorkflows.contains { $0.id == rule.workflowID }).help("Run the shortcut now without claiming its scheduled trigger")
                        Toggle("Enable \(rule.name)", isOn: Binding(get: { rule.isEnabled }, set: { _ in store.toggleAutomation(rule.id) })).labelsHidden().disabled(!store.canEdit)
                        Button { store.removeAutomation(rule.id) } label: { Image(systemName: "trash") }.buttonStyle(.borderless).disabled(!store.canEdit).help("Remove automation")
                    }.padding(.vertical, 10).accessibilityElement(children: .contain)
                }
            }
        }.padding(28)
        .sheet(item: $selectedPreset) { preset in AutomationForm(preset: preset, initialWorkflowID: store.liveWorkflows.first?.id.uuidString ?? "").environmentObject(store) }
        .sheet(item: $editingRule) { rule in AutomationForm(rule: rule).environmentObject(store) }
    }
    private func description(_ rule: AutomationRule) -> String {
        if rule.trigger == "time" {
            let repeatLabel = rule.weekdays.map { days in dayLabels.filter { days.contains($0.0) }.map(\.1).joined(separator: ", ") } ?? "Every day"
            return String(format: "%@ at %02d:%02d", repeatLabel, rule.hour, rule.minute)
        }
        if rule.trigger == "wake" { return "When Mac wakes" }; if rule.trigger == "sleep" { return "Before Mac sleeps" }; if rule.trigger == "clipboard" { return "When clipboard changes" }
        if rule.trigger.hasPrefix("quit:") { return "When \(rule.trigger.dropFirst(5)) quits" }
        return "When \(rule.trigger.replacingOccurrences(of: "app:", with: "")) activates"
    }
}

private struct AutomationForm: View {
    @EnvironmentObject var store: StudioStore
    @Environment(\.dismiss) private var dismiss
    private var editingID: UUID?
    @ViewState private var name: String
    @ViewState private var workflowID: String
    @ViewState private var trigger: String
    @ViewState private var time = Date()
    @ViewState private var bundle = "com.apple.Safari"
    @ViewState private var repetition = "Every Day"
    @ViewState private var days: Set<Int> = [2, 3, 4, 5, 6]
    private let dayLabels = [(1, "Sun"), (2, "Mon"), (3, "Tue"), (4, "Wed"), (5, "Thu"), (6, "Fri"), (7, "Sat")]
    init(preset: AutomationPreset, initialWorkflowID: String) {
        _name = ViewState(initialValue: preset.title)
        _trigger = ViewState(initialValue: preset.trigger)
        _workflowID = ViewState(initialValue: initialWorkflowID)
    }
    init(rule: AutomationRule) {
        editingID = rule.id
        _name = ViewState(initialValue: rule.name)
        _workflowID = ViewState(initialValue: rule.workflowID.uuidString)
        let parts = rule.trigger.split(separator: ":", maxSplits: 1).map(String.init)
        _trigger = ViewState(initialValue: parts.first ?? "time")
        _bundle = ViewState(initialValue: parts.count > 1 ? parts[1] : "com.apple.Safari")
        _time = ViewState(initialValue: Calendar.current.date(bySettingHour: rule.hour, minute: rule.minute, second: 0, of: Date()) ?? Date())
        _repetition = ViewState(initialValue: rule.weekdays == nil ? "Every Day" : "Selected Days")
        _days = ViewState(initialValue: Set(rule.weekdays ?? [2, 3, 4, 5, 6]))
    }
    var body: some View {
            Form {
                Text(editingID == nil ? "New Automation" : "Edit Automation").font(.title2.bold())
                TextField("Name", text: $name)
                Picker("Shortcut", selection: $workflowID) { ForEach(store.liveWorkflows) { Text($0.name).tag($0.id.uuidString) } }
                Picker("Trigger", selection: $trigger) { ForEach(AutomationPreset.all) { Text($0.title).tag($0.trigger) } }
                if trigger == "time" {
                    DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                    Picker("Repeat", selection: $repetition) { Text("Every Day").tag("Every Day"); Text("Selected Days").tag("Selected Days") }
                    if repetition == "Selected Days" { HStack { ForEach(dayLabels, id: \.0) { day, label in Toggle(label, isOn: Binding(get: { days.contains(day) }, set: { if $0 { days.insert(day) } else { days.remove(day) } })).toggleStyle(.button) } } }
                }
                if trigger == "app" || trigger == "quit" {
                    TextField("Bundle identifier", text: $bundle)
                    Button("Use Safari") { bundle = "com.apple.Safari" }.controlSize(.small)
                }
                if trigger == "sleep" { Text("macOS may suspend execution immediately. Use brief actions; completion before sleep is not guaranteed.").font(.caption).foregroundStyle(.secondary) }
                Text(editingID == nil ? "Creating enables this automation. You can turn it off from the list." : "Saving preserves the enabled state. Changing the trigger clears its previous claim.").font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button("Cancel") { dismiss() }; Spacer()
                    Button(editingID == nil ? "Create" : "Save") {
                        if let id = UUID(uuidString: workflowID) {
                            let c = Calendar.current.dateComponents([.hour, .minute], from: time)
                            let key = ["app", "quit"].contains(trigger) ? "\(trigger):\(bundle.trimmingCharacters(in: .whitespaces))" : trigger
                            let weekdays = trigger == "time" && repetition == "Selected Days" ? days.sorted() : nil
                            if let editingID { store.updateAutomation(editingID, workflowID: id, name: name, trigger: key, hour: c.hour ?? 9, minute: c.minute ?? 0, weekdays: weekdays) }
                            else { store.addAutomation(workflowID: id, name: name, trigger: key, hour: c.hour ?? 9, minute: c.minute ?? 0, weekdays: weekdays) }
                            dismiss()
                        }
                    }.keyboardShortcut(.defaultAction).disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || !store.liveWorkflows.contains(where: { $0.id.uuidString == workflowID }) || (["app", "quit"].contains(trigger) && bundle.trimmingCharacters(in: .whitespaces).isEmpty) || (trigger == "time" && repetition == "Selected Days" && days.isEmpty))
                }
            }.formStyle(.grouped).padding(20).frame(width: 580, height: 470)
    }
}
