import Foundation
import SwiftUI
import CryptoKit
import Security
import WorkflowCore

struct MessengerGrant: Codable { var id: UUID; var revision: String }
struct MessengerDevice: Codable, Identifiable { var id: String; var label: String; var key: String; var fingerprint: String }
struct MessengerRecord: Codable, Identifiable {
    var id: String; var deviceID: String; var digest: String; var state: String; var output: String?; var message: String
}
struct MessengerConfiguration: Codable {
    var url = ""; var grants: [MessengerGrant] = []; var devices: [MessengerDevice] = []; var journal: [MessengerRecord] = []
}
struct MessengerPair: Decodable, Identifiable { var id: String; var label: String; var publicKey: String }
private struct RelayCommand: Decodable { var id: String; var deviceID: String; var payload: String; var expiresAt: Double; var cancelRequested: Bool; var state: String? }
private struct RelayPoll: Decodable { var pairs: [MessengerPair]; var commands: [RelayCommand]; var activeDevices: [String]?; var revokedDevices: [String]? }
private struct PhoneCommand: Decodable { var id: String; var deviceID: String; var workflowID: UUID; var workflowRevision: String; var input: String; var expiresAt: Double }

@MainActor final class MessengerConnector: ObservableObject {
    static let allowedKinds: Set<String> = ["phoneAssistant","desktopNames","appControl","text","number","boolean","comment","input","setVariable","getVariable","if","else","endIf","repeat","repeatEach","endRepeat","wait","stop","uppercase","trim","replace","match","split","combine","base64","urlEncode","calculate","round","random","statistics","list","count","getItem","sort","reverse","unique","filter","dictionary","parseJSON","getValue","setValue","keys","json","url","openURL","openApp","date","formatDate","show","onDeviceModel"]
    @Published var configuration = MessengerConfiguration()
    @Published var status = "Disconnected"
    @Published var isConnected = false
    @Published var pairingCode = ""
    @Published var pairingExpires = Date.distantPast
    @Published var pendingPairs: [MessengerPair] = []
    @Published var error: String?
    private weak var store: StudioStore?
    private var task: Task<Void, Never>?
    private var session: URLSession
    private var token = ""
    private var deviceKeys: [String: SymmetricKey] = [:]
    private var didBootstrap = false
    private var decisions: [[String: Any]] = []
    private var revoked: [String] = []
    private var activeRun: String?
    private var sentUpdates: [String: String] = [:]
    private var lastStreamText: String?
    private let file: URL
    private let credentialAccess: ((String, String?) throws -> String)?
    init(store: StudioStore, directory: URL? = nil, credentialAccess: ((String, String?) throws -> String)? = nil) {
        self.credentialAccess = credentialAccess
        self.store = store
        let root = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("ShortcutStudio")
        file = root.appendingPathComponent("messenger.json")
        let config = URLSessionConfiguration.ephemeral; config.timeoutIntervalForRequest = 8; config.timeoutIntervalForResource = 12
        session = URLSession(configuration: config)
        if FileManager.default.fileExists(atPath: file.path) {
            do { configuration = try JSONDecoder().decode(MessengerConfiguration.self, from: Data(contentsOf: file)) }
            catch { self.error = "Messenger configuration could not be read; it was preserved." }
        }
        for i in configuration.journal.indices where ["Accepted", "Running"].contains(configuration.journal[i].state) {
            configuration.journal[i].state = "Interrupted"; configuration.journal[i].message = "Mac restarted; outcome may include prior side effects."
        }
        if error == nil { try? persist() }
    }
    func loadBootstrap() {
        guard !didBootstrap else { return }; didBootstrap = true
        let bootstrap = file.deletingLastPathComponent().appendingPathComponent("messenger-bootstrap.json")
        guard FileManager.default.fileExists(atPath: bootstrap.path) else { return }
        do {
            let body = try JSONSerialization.jsonObject(with: Data(contentsOf: bootstrap)) as? [String: String]
            guard let url = body?["url"], let key = body?["token"] else { throw StudioError.message("Invalid gateway setup file.") }
            try configure(url: url, credential: key); try FileManager.default.removeItem(at: bootstrap)
        } catch { self.error = error.localizedDescription }
    }
    static func revision(_ workflow: Workflow) -> String {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let data = (try? encoder.encode(workflow.actions)) ?? Data()
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
    static func policyError(_ workflow: Workflow) -> String? {
        guard !workflow.actions.isEmpty, workflow.actions.count <= 100 else { return "Share a workflow with 1–100 actions." }
        for a in workflow.actions where a.isEnabled {
            if !allowedKinds.contains(a.kind) { return "\(ActionCatalog.definition(a.kind)?.title ?? a.kind) requires a local-only capability." }
            if a.parameters.values.contains(where: { $0.contains("{{storage:") }) { return "Stored-value references are not shared." }
        }
        return nil
    }
    func isGranted(_ workflow: Workflow) -> Bool {
        guard configuration.grants.contains(where: { $0.id == workflow.id && $0.revision == Self.revision(workflow) }) else { return false }
        if workflow.origin == "phone" {
            guard let id = workflow.parentWorkflowID, let parent = store?.liveWorkflows.first(where: { $0.id == id }), parent.origin != "phone", parent.actions.count == 1, parent.actions[0].kind == "phoneAssistant", parent.actions[0].parameters["prompt"] == "{{input}}",
                  configuration.grants.contains(where: { $0.id == id && $0.revision == Self.revision(parent) }) else { return false }
            let scope = parent.actions[0].parameters.filter { $0.key != "prompt" }
            guard workflow.actions.allSatisfy({ $0.kind == "phoneAssistant" && $0.parameters.filter { $0.key != "prompt" } == scope }) else { return false }
        }
        return true
    }
    func grant(_ workflow: Workflow, enabled: Bool) {
        if enabled, let reason = Self.policyError(workflow) { error = reason; return }
        configuration.grants.removeAll { $0.id == workflow.id }
        if enabled && configuration.grants.count >= 50 { error = "Share at most 50 workflows per gateway session."; return }
        if enabled { configuration.grants.append(MessengerGrant(id: workflow.id, revision: Self.revision(workflow))) }
        saveOrDisconnect()
    }
    private func secret(account: String, value: String? = nil) throws -> String {
        if let credentialAccess { return try credentialAccess(account, value) }
        var query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "tools.shortcutstudio.messenger", kSecAttrAccount as String: account]
        if let value {
            let data = Data(value.utf8)
            let result = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
            if result == errSecItemNotFound { query[kSecValueData as String] = data; query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly; guard SecItemAdd(query as CFDictionary, nil) == errSecSuccess else { throw StudioError.message("Unable to save messenger credential in Keychain.") } }
            else if result != errSecSuccess { throw StudioError.message("Unable to update messenger credential.") }
            return value
        }
        query[kSecReturnData as String] = true; query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?; guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data, let text = String(data: data, encoding: .utf8) else { throw StudioError.message("Gateway credential is missing. Configure the connection again.") }
        return text
    }
    func configure(url: String, credential: String) throws {
        guard let u = URL(string: url), u.scheme == "https" || (u.scheme == "http" && ["localhost","127.0.0.1"].contains(u.host ?? "")), u.user == nil, u.password == nil, u.query == nil, u.fragment == nil, u.path.isEmpty || u.path == "/", credential.utf8.count >= 32 else { throw StudioError.message("Use an HTTPS gateway origin and its Mac credential. HTTP is allowed only on loopback.") }
        disconnect(); token = try secret(account: "relay", value: credential); configuration.url = url.trimmingCharacters(in: CharacterSet(charactersIn: "/")); try persist()
    }
    func connect() {
        guard !isConnected, error == nil, !configuration.url.isEmpty else { return }
        do {
            if token.isEmpty { token = try secret(account: "relay") }
        } catch { self.error = error.localizedDescription; return }
        isConnected = true; sentUpdates = [:]; status = "Connecting…"
        task = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                do {
                    try await self.snapshot()
                    let data = try await self.request("mac/poll")
                    let poll = try JSONDecoder().decode(RelayPoll.self, from: data)
                    if let revoked = poll.revokedDevices, !revoked.isEmpty {
                        self.configuration.devices.removeAll { revoked.contains($0.id) }
                        for id in revoked { self.deviceKeys.removeValue(forKey: id) }
                        self.saveOrDisconnect()
                    }
                    do {
                        for device in self.configuration.devices where self.deviceKeys[device.id] == nil && (poll.activeDevices?.contains(device.id) ?? true) {
                            guard let bytes = Data(base64Encoded: try self.secret(account: "device:\(device.id)")) else { throw StudioError.message("Invalid paired-device credential.") }
                            self.deviceKeys[device.id] = SymmetricKey(data: bytes)
                        }
                    } catch {
                        self.error = "Paired-device Keychain unlock was cancelled or unavailable. Connect again when ready; it will not retry in the background."
                        self.disconnect(); return
                    }
                    self.pendingPairs = poll.pairs; self.status = self.activeRun == nil ? "Connected · waiting for phone" : "Running phone command"
                    for command in poll.commands { try self.receive(command) }
                } catch is CancellationError { break }
                catch { self.status = "Connection interrupted · retrying" }
                try? await Task.sleep(nanoseconds: self.activeRun == nil ? 4_000_000_000 : 1_000_000_000)
            }
        }
    }
    func disconnect() {
        task?.cancel(); task = nil; isConnected = false; status = "Disconnected"; pairingCode = ""; pendingPairs = []
        if activeRun != nil { store?.stop() }
    }
    private func request(_ path: String, body: [String: Any]? = nil) async throws -> Data {
        guard let url = URL(string: configuration.url + "/" + path) else { throw StudioError.message("Invalid gateway URL.") }
        var r = URLRequest(url: url); r.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let body { r.httpMethod = "POST"; r.setValue("application/json", forHTTPHeaderField: "Content-Type"); r.httpBody = try JSONSerialization.data(withJSONObject: body) }
        let (data, response) = try await session.data(for: r)
        guard data.count <= 2_000_000, let http = response as? HTTPURLResponse, http.statusCode == 200 else { throw StudioError.message("Gateway rejected the request.") }
        return data
    }
    func newPairingCode() {
        guard isConnected else { return }
        Task { do {
            let data = try await request("mac/challenge", body: [:]); let b = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            pairingCode = b?["code"] as? String ?? ""; pairingExpires = Date(timeIntervalSince1970: (b?["expiresAt"] as? Double ?? 0) / 1000)
        } catch { self.error = "Could not create a pairing code." } }
    }
    func fingerprint(_ pair: MessengerPair) -> String {
        guard let data = Data(base64Encoded: pair.publicKey) else { return "Invalid identity" }
        return SHA256.hash(data: data).prefix(8).map { String(format: "%02x", $0) }.joined()
    }
    func approve(_ pair: MessengerPair) {
        guard !configuration.devices.contains(where: { $0.id == pair.id }) else { return }
        do {
            guard let raw = Data(base64Encoded: pair.publicKey) else { throw StudioError.message("Invalid phone identity.") }
            let peer = try P256.KeyAgreement.PublicKey(x963Representation: raw)
            let privateKey = P256.KeyAgreement.PrivateKey()
            let shared = try privateKey.sharedSecretFromKeyAgreement(with: peer)
            let key = shared.hkdfDerivedSymmetricKey(using: SHA256.self, salt: Data("studio.messenger/1".utf8), sharedInfo: Data(pair.id.utf8), outputByteCount: 32)
            let encoded = key.withUnsafeBytes { Data($0).base64EncodedString() }
            _ = try secret(account: "device:\(pair.id)", value: encoded)
            deviceKeys[pair.id] = key
            configuration.devices.append(MessengerDevice(id: pair.id, label: pair.label, key: "Keychain", fingerprint: fingerprint(pair)))
            try persist()
            decisions.append(["id": pair.id, "approved": true, "macPublicKey": privateKey.publicKey.x963Representation.base64EncodedString()]); pendingPairs.removeAll { $0.id == pair.id }; pairingCode = ""
        } catch { self.error = "Could not approve the phone: \(error.localizedDescription)" }
    }
    func reject(_ pair: MessengerPair) { decisions.append(["id": pair.id, "approved": false]); pendingPairs.removeAll { $0.id == pair.id } }
    func revoke(_ device: MessengerDevice) {
        configuration.devices.removeAll { $0.id == device.id }; deviceKeys.removeValue(forKey: device.id); revoked.append(device.id)
        if let id = activeRun, configuration.journal.first(where: { $0.id == id })?.deviceID == device.id { store?.stop() }
        saveOrDisconnect()
    }
    private func key(_ device: String) throws -> SymmetricKey {
        guard configuration.devices.contains(where: { $0.id == device }), let key = deviceKeys[device] else { throw StudioError.message("Paired-device session is not unlocked. Reconnect once to unlock it.") }
        return key
    }
    private func encrypted(_ text: String, device: String, id: String) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: ["text": String(decoding: text.utf8.prefix(12000), as: UTF8.self), "truncated": text.utf8.count > 12000])
        let box = try AES.GCM.seal(data, using: key(device), authenticating: Data("result|\(device)|\(id)".utf8))
        guard let combined = box.combined else { throw StudioError.message("Unable to encode response.") }; return combined.base64EncodedString()
    }
    private func receive(_ c: RelayCommand) throws {
        let digest = SHA256.hash(data: Data(c.payload.utf8)).map { String(format: "%02x", $0) }.joined()
        if let existing = configuration.journal.first(where: { $0.id == c.id }) {
            guard existing.deviceID == c.deviceID, existing.digest == digest else { return }
            if c.cancelRequested && activeRun == c.id { store?.stop() }
            return
        }
        guard configuration.journal.count < 1000 else { throw StudioError.message("Messenger session journal is full.") }
        func reject(_ message: String) throws { configuration.journal.append(MessengerRecord(id: c.id, deviceID: c.deviceID, digest: digest, state: "Rejected", output: nil, message: message)); try persist() }
        guard c.state == nil || c.state == "Sent" else { try reject("Interrupted; no matching Mac receipt. Not replayed."); return }
        guard configuration.devices.contains(where: { $0.id == c.deviceID }) else { try reject("Device revoked or not paired."); return }
        guard c.payload.utf8.count <= 50000, let sealed = Data(base64Encoded: c.payload) else { try reject("Invalid command."); return }
        let clear: Data
        do { clear = try AES.GCM.open(AES.GCM.SealedBox(combined: sealed), using: key(c.deviceID), authenticating: Data("command|\(c.deviceID)|\(c.id)".utf8)) }
        catch { try reject("Command authentication failed."); return }
        let command: PhoneCommand
        let permittedKeys: Set<String> = ["id","deviceID","workflowID","workflowRevision","input","expiresAt"]
        guard clear.count <= 32768, let object = try? JSONSerialization.jsonObject(with: clear) as? [String: Any], Set(object.keys) == permittedKeys else { try reject("Invalid command schema."); return }
        do { command = try JSONDecoder().decode(PhoneCommand.self, from: clear) } catch { try reject("Invalid command format."); return }
        guard command.id == c.id, command.deviceID == c.deviceID, command.input.utf8.count <= 16384, command.expiresAt > Date().timeIntervalSince1970 * 1000, command.expiresAt < Date().timeIntervalSince1970 * 1000 + 120000, c.expiresAt > Date().timeIntervalSince1970 * 1000 else { try reject("Expired or oversized command."); return }
        guard !c.cancelRequested else { try reject("Cancelled before acceptance."); return }
        guard let store, !store.isRunning, store.canEdit, store.saveFailure == nil else { try reject("Mac busy or library unavailable."); return }
        guard let w = store.liveWorkflows.first(where: { $0.id == command.workflowID }), isGranted(w), Self.revision(w) == command.workflowRevision, Self.policyError(w) == nil else { try reject("Workflow changed or not approved."); return }
        configuration.journal.append(MessengerRecord(id: c.id, deviceID: c.deviceID, digest: digest, state: "Accepted", output: nil, message: "Accepted by Mac"))
        do { try persist() } catch { disconnect(); throw error }
        if command.input.hasPrefix("studio.shortcut/1\n") {
            do {
                guard w.origin != "phone", w.actions.count == 1, w.actions[0].kind == "phoneAssistant", w.actions[0].parameters["prompt"] == "{{input}}" else { throw StudioError.message("Phone authoring requires an approved single-action Assistant.") }
                let response = try store.managePhoneShortcut(String(command.input.dropFirst("studio.shortcut/1\n".count)), parent: w)
                if let created = response.workflow { grant(created, enabled: true) }
                guard isConnected, error == nil else { throw StudioError.message("Shortcut saved, but its sharing grant could not be persisted. Check the Mac.") }
                let i = configuration.journal.firstIndex { $0.id == c.id }!
                configuration.journal[i].state = "Completed"; configuration.journal[i].message = "Shortcut saved"
                configuration.journal[i].output = try encrypted(response.text, device: c.deviceID, id: c.id)
            } catch {
                let i = configuration.journal.firstIndex { $0.id == c.id }!
                configuration.journal[i].state = "Failed"; configuration.journal[i].message = "Shortcut request failed"
                configuration.journal[i].output = try encrypted(String(error.localizedDescription.prefix(500)), device: c.deviceID, id: c.id)
            }
            try persist(); return
        }
        activeRun = c.id; lastStreamText = nil
        let started = store.run(w, input: .text(command.input), remotely: true) { [weak self] state, result in
            guard let self, let i = self.configuration.journal.firstIndex(where: { $0.id == c.id }) else { return }
            self.configuration.journal[i].state = state; self.configuration.journal[i].message = state
            self.configuration.journal[i].output = try? self.encrypted(result, device: c.deviceID, id: c.id)
            self.activeRun = nil; self.saveOrDisconnect()
        }
        if started { if let i = configuration.journal.firstIndex(where: { $0.id == c.id }) { configuration.journal[i].state = "Running" }; try persist() }
        else { activeRun = nil; if let i = configuration.journal.firstIndex(where: { $0.id == c.id }) { configuration.journal[i].state = "Rejected"; configuration.journal[i].message = "Mac busy" }; try persist() }
    }
    private func snapshot() async throws {
        let workflows = store?.liveWorkflows.filter { isGranted($0) && Self.policyError($0) == nil }.map { w in ["id":w.id.uuidString,"name":String(decoding: w.name.utf8.prefix(160), as: UTF8.self),"revision":Self.revision(w),"color":w.color,"symbol":w.symbol,"actionCount":w.actions.count,"actionTitles":Array(w.actions.prefix(6)).map { String((ActionCatalog.definition($0.kind)?.title ?? $0.kind).prefix(64)) },"userCreated":w.origin == "phone","requiresInput":w.actions.contains { $0.parameters.values.contains { $0.contains("{{input}}") } },"canCreate":w.origin != "phone" && w.actions.count == 1 && w.actions[0].kind == "phoneAssistant" && w.actions[0].parameters["prompt"] == "{{input}}","usesModel":w.actions.contains { $0.isEnabled && ($0.kind == "onDeviceModel" || $0.kind == "phoneAssistant") }] as [String: Any] } ?? []
        if let activeRun, let i = configuration.journal.firstIndex(where: { $0.id == activeRun }), let store {
            if lastStreamText != store.output.text { configuration.journal[i].output = try? encrypted(store.output.text, device: configuration.journal[i].deviceID, id: activeRun); lastStreamText = store.output.text }
        }
        let dirty = configuration.journal.reversed().filter { sentUpdates[$0.id] != $0.state + "|" + ($0.output ?? "") + "|" + $0.message }
        let records = Array(dirty.prefix(1))
        let updates = records.map { r in ["id":r.id,"state":r.state,"message":r.message,"output":r.output as Any? ?? NSNull()] as [String: Any] }
        let sentDecisions = decisions, sentRevocations = revoked
        _ = try await request("mac/snapshot", body: ["workflows":workflows,"status":store?.isRunning == true ? "Busy" : "Ready","decisions":sentDecisions,"revoke":sentRevocations,"updates":updates])
        for r in records { sentUpdates[r.id] = r.state + "|" + (r.output ?? "") + "|" + r.message }
        decisions.removeFirst(min(sentDecisions.count, decisions.count)); revoked.removeFirst(min(sentRevocations.count, revoked.count))
    }
    private func persist() throws { try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true); let data = try JSONEncoder().encode(configuration); try data.write(to: file, options: .atomic); try FileManager.default.setAttributes([.posixPermissions:0o600], ofItemAtPath: file.path) }
    private func saveOrDisconnect() { do { try persist() } catch { self.error = "Messenger journal could not be saved. Execution stopped."; disconnect() } }
    func simplifyWorkflows() {
        guard let store, store.canEdit else { return }
        store.checkpoint()
        for i in store.library.workflows.indices {
            let w = store.library.workflows[i]
            let demo = ActionCatalog.galleryTemplates.first { ["List Playground", "Persistent Counter", "JSON Explorer"].contains($0.name) && $0.name == w.name }
            if let demo, w.storage.isEmpty, w.actions.count == demo.actions.count,
               zip(w.actions, demo.actions).allSatisfy({ $0.kind == $1.kind && $0.parameters == $1.parameters && $0.isEnabled == $1.isEnabled }) {
                store.library.workflows[i].deletedAt = Date()
                configuration.grants.removeAll { $0.id == w.id }
            }
            if w.name == "Phone · Google in Chrome", w.actions.map(\.kind) == ["urlEncode", "url", "openURL", "text"] {
                store.library.workflows[i].deletedAt = Date(); configuration.grants.removeAll { $0.id == w.id }
            }
            if w.name == "Phone · Assistant" {
                for j in store.library.workflows[i].actions.indices where store.library.workflows[i].actions[j].kind == "phoneAssistant" {
                    var apps = (store.library.workflows[i].actions[j].parameters["applications"] ?? "").split(separator: ",").map(String.init)
                    for bundle in ["com.openai.codex", "com.apple.weather"] where !apps.contains(bundle) { apps.append(bundle) }
                    store.library.workflows[i].actions[j].parameters["applications"] = apps.joined(separator: ",")
                }
            }
        }
        store.save(); saveOrDisconnect()
    }
    func installExamples() {
        guard let store, store.canEdit else { return }
        let definitions: [Workflow] = [
            Workflow(name: "Phone · Assistant", symbol: "bubble.left.and.bubble.right", color: "teal", actions: [ActionCatalog.definition("phoneAssistant")!.action]),
            Workflow(name: "Phone · Desktop File Names", symbol: "desktopcomputer", color: "blue", actions: [WorkflowAction(kind: "desktopNames")]),
            Workflow(name: "Phone · Echo", symbol: "text.bubble", color: "teal", actions: [WorkflowAction(kind: "text", parameters: ["text":"Received from your phone: {{input}}"])]),
            Workflow(name: "Phone · Framer to Subframe", symbol: "app.badge", color: "purple", actions: [WorkflowAction(kind: "url", parameters: ["url":"https://framer.com/"]),WorkflowAction(kind: "openURL", parameters: ["input":"{{previous}}","bundle":"com.google.Chrome"]),WorkflowAction(kind: "openApp", parameters: ["bundle":"com.subframe.desktop"]),WorkflowAction(kind: "text", parameters: ["text":"Framer opened in Chrome; Subframe launched on your Mac."])]),
            Workflow(name: "Phone · On-Device Answer", symbol: "sparkles", color: "pink", actions: [WorkflowAction(kind: "onDeviceModel", parameters: ["prompt":"{{input}}","instructions":"Respond concisely to the user's question. You have no tools."])])
        ]
        for w in definitions where !store.liveWorkflows.contains(where: { $0.name == w.name }) { store.create(w) }
    }
}
