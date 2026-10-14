import SwiftUI
import AppKit
import WorkflowCore

struct MessengerView: View {
    @ObservedObject var connector: MessengerConnector
    var isWindow = false
    @Environment(\.dismissWindow) var dismissWindow
    @EnvironmentObject var store: StudioStore
    @Environment(\.dismiss) var dismiss
    @ViewState private var url = ""
    @ViewState private var credential = ""
    @ViewState private var desktopStatus = "Desktop access not checked"
    @AppStorage("assistant.modelsEnabled") private var modelsEnabled = false
    @ViewState private var roots = AssistantSettings.folderRoots
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 16) {
            HStack { Label("Phone Messenger", systemImage: "iphone.and.arrow.forward").font(.title2.bold()); Spacer(); Button("Done") { if isWindow { dismissWindow(id: "messenger") } else { dismiss() } }.studioGlassButton().keyboardShortcut(.cancelAction) }
            HStack { Circle().fill(connector.isConnected ? Color.green : Color.gray).frame(width: 8, height: 8); Text(connector.status); Spacer(); Button(connector.isConnected ? "Disconnect" : "Connect") { if connector.isConnected { connector.disconnect() } else { connector.error = nil; connector.connect() } }.studioGlassButton(prominent: true).disabled(connector.configuration.url.isEmpty) }
            if let error = connector.error { HStack { Text(error).font(.caption).foregroundStyle(.red); Spacer(); Button("Dismiss") { connector.error = nil } } }
            DisclosureGroup("Gateway connection") {
                TextField("HTTPS gateway origin", text: $url).textFieldStyle(.roundedBorder)
                SecureField("Mac gateway credential", text: $credential).textFieldStyle(.roundedBorder)
                HStack { Button("Save Connection") { do { try connector.configure(url: url, credential: credential); credential = ""; connector.error = nil } catch { connector.error = error.localizedDescription } }.disabled(credential.isEmpty); Text("Keychain is unlocked once per connection; commands use cached session keys.").font(.caption).foregroundStyle(.secondary) }
            }
            Toggle("Use Apple model on demand", isOn: $modelsEnabled)
                .onChange(of: modelsEnabled) { _, enabled in if !enabled { store.stop() } }
            Text("No background inference. Low Power Mode or serious heat pauses model requests. Phone commands: model on / model off / model status. This controls Studio inference, not system-wide Apple Intelligence.").font(.caption).foregroundStyle(.secondary)
            DisclosureGroup("Approved folders for phone reading") {
                ForEach(roots, id: \.self) { root in
                    HStack { Text(root).font(.caption).textSelection(.enabled); Spacer(); Button("Remove") { roots.removeAll { $0 == root }; AssistantSettings.folderRoots = roots } }
                }
                Button("Approve Folder…") {
                    let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.allowsMultipleSelection = false
                    panel.message = "Allow your paired phone to list and read text files in this folder and its children."
                    if panel.runModal() == .OK, let path = panel.url?.resolvingSymlinksInPath().path, !roots.contains(path) { roots.append(path); AssistantSettings.folderRoots = roots }
                }
                Text("Desktop remains available when enabled in the workflow. Other folders require explicit approval here. Use: open folder <path>, list folder <path>, read file <path>.").font(.caption).foregroundStyle(.secondary)
            }
            HStack { Text(OnDeviceIntelligence.status).font(.caption); Spacer(); Button(AppControl.isTrusted ? "Accessibility Enabled" : "Enable App Control") { AppControl.requestPermission() }.disabled(AppControl.isTrusted) }
            HStack {
                Text(desktopStatus).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Check Desktop Access") { do { _ = try AppControl.readDesktop(); desktopStatus = "Desktop filename access ready" } catch { desktopStatus = "Desktop access requires macOS approval" } }
                Button("Privacy Settings") { Task { try? await AppControl.open("com.apple.systempreferences") } }
            }
            Text("App control: Privacy & Security → Device Control and Data Access (Accessibility on earlier macOS). Desktop access is separate. Permissions are requested by macOS; approving a workflow does not grant them.").font(.caption2).foregroundStyle(.secondary)
            Divider()
            HStack { Text("Pair your Android phone").font(.headline); Spacer(); Button("Create Pairing Code") { connector.newPairingCode() }.studioGlassButton().disabled(!connector.isConnected) }
            if !connector.pairingCode.isEmpty && connector.pairingExpires > Date() {
                Text(connector.pairingCode).font(.system(size: 32, weight: .bold, design: .monospaced)).textSelection(.enabled)
                Text("Open \(connector.configuration.url) in Chrome on your phone. Enter this code, then verify the fingerprint below. Code expires in five minutes.").font(.caption).textSelection(.enabled)
            }
            ForEach(connector.pendingPairs) { pair in
                HStack { VStack(alignment: .leading) { Text(pair.label); Text("Fingerprint: \(connector.fingerprint(pair))").font(.system(.caption, design: .monospaced)).textSelection(.enabled) }; Spacer(); Button("Reject") { connector.reject(pair) }; Button("Approve Phone") { connector.approve(pair) } }
            }
            ForEach(connector.configuration.devices) { device in HStack { Label(device.label, systemImage: "iphone"); Text(device.fingerprint).font(.caption.monospaced()); Spacer(); Button("Revoke") { connector.revoke(device) } } }
            Divider()
            HStack { Text("Approved workflows").font(.headline); Spacer(); Button("Simplify & Enable Codex/Weather") { connector.simplifyWorkflows() }.disabled(!store.canEdit); Button("Add Assistant Workflows") { connector.installExamples() }.disabled(!store.canEdit) }
            Text("Only checked, unchanged workflows can run remotely. Editing actions requires approval again. Show Result returns to the phone without a Mac dialog. AI runs only in workflows marked AI.").font(.caption).foregroundStyle(.secondary)
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(store.liveWorkflows) { workflow in
                        HStack {
                            Toggle(isOn: Binding(get: { connector.isGranted(workflow) }, set: { connector.grant(workflow, enabled: $0) })) { Text(workflow.name) }.disabled(MessengerConnector.policyError(workflow) != nil || store.isRunning)
                            if workflow.actions.contains(where: { ($0.kind == "onDeviceModel" || $0.kind == "phoneAssistant") && $0.isEnabled }) { Text("AI").font(.caption.bold()).foregroundStyle(.purple) }
                            if let reason = MessengerConnector.policyError(workflow) { Text(reason).font(.caption).foregroundStyle(.secondary).frame(maxWidth: 210, alignment: .trailing) }
                        }
                    }
                }
            }.frame(minHeight: 150)
            Text("Keep this Mac awake and Studio open. Disconnect stops an active phone run. Your configured gateway routes encrypted commands and results. Workflow execution and Apple model inference stay on this Mac.").font(.caption).foregroundStyle(.secondary)
        }.padding(24) }.frame(minWidth: 700, idealWidth: 760, minHeight: 740, idealHeight: 840).onAppear { url = connector.configuration.url }
    }
}
