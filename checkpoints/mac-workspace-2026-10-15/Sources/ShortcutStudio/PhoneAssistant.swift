import Foundation
import FoundationModels
import AppKit
import UserNotifications
import CryptoKit
import WorkflowCore

@MainActor enum AssistantSettings {
    static var modelsEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "assistant.modelsEnabled") as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: "assistant.modelsEnabled") }
    }
    static var folderRoots: [String] {
        get { UserDefaults.standard.stringArray(forKey: "assistant.folderRoots") ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: "assistant.folderRoots") }
    }
    static func requireModel() throws {
        guard modelsEnabled else { throw StudioError.message("Studio model use is off. Send ‘model on’ to enable it. Explicit file and app commands still work.") }
        guard !ProcessInfo.processInfo.isLowPowerModeEnabled else { throw StudioError.message("Mac Low Power Mode is on; Studio has paused model inference. Explicit commands still work.") }
        guard ![ProcessInfo.ThermalState.serious, .critical].contains(ProcessInfo.processInfo.thermalState) else { throw StudioError.message("The Mac is hot; Studio has paused model inference. Retry after it cools.") }
    }
    static func folder(_ path: String, desktop: Bool) throws -> URL {
        var roots = folderRoots.map { URL(fileURLWithPath: $0).resolvingSymlinksInPath().standardizedFileURL }
        if desktop { roots.append(FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0].resolvingSymlinksInPath()) }
        let clean = path.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        let candidates: [URL]
        if clean.hasPrefix("/") || clean.hasPrefix("~") { candidates = [URL(fileURLWithPath: (clean as NSString).expandingTildeInPath)] }
        else {
            candidates = roots.map { root in
                let parts = clean.split(separator: "/", maxSplits: 1).map(String.init)
                if parts.first?.lowercased() == root.lastPathComponent.lowercased() { return parts.count == 1 ? root : root.appendingPathComponent(parts[1]) }
                return root.appendingPathComponent(clean)
            }
        }
        let matches = candidates.map { $0.resolvingSymlinksInPath().standardizedFileURL }.filter { candidate in
            roots.contains { candidate.path == $0.path || candidate.path.hasPrefix($0.path + "/") } && FileManager.default.fileExists(atPath: candidate.path)
        }
        let unique = Array(Set(matches))
        guard unique.count == 1 else { throw StudioError.message("Use an existing, unambiguous path inside an approved folder. On the Mac, Phone Messenger → Approve Folder grants read access to that folder and its children.") }
        return unique[0]
    }
    static func files(_ path: String, desktop: Bool, read: Bool) throws -> String {
        let url = try folder(path, desktop: desktop)
        let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey])
        if read {
            guard values.isRegularFile == true, ["txt","md","csv","json","log","swift","py","js","ts","html","css","yaml","yml","xml"].contains(url.pathExtension.lowercased()) else { throw StudioError.message("Read supports regular UTF-8 text/code files. PDF, Office, image and binary extraction are not enabled.") }
            let handle = try FileHandle(forReadingFrom: url); defer { try? handle.close() }
            let data = try handle.read(upToCount: 24_577) ?? Data()
            guard let text = String(data: data.prefix(24_576), encoding: .utf8) else { throw StudioError.message("This file is not valid UTF-8 text, or its preview ends within a character. Try a smaller UTF-8 file.") }
            return url.lastPathComponent + "\n\n" + text + (data.count > 24_576 ? "\n[Preview truncated at 24 KiB]" : "")
        }
        guard values.isDirectory == true else { throw StudioError.message("This path is a file. Use ‘read file <path>’ for its text.") }
        let entries = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]).sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
        return url.path + "\n" + entries.prefix(200).map { $0.lastPathComponent + ((try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true ? "/" : "") }.joined(separator: "\n") + (entries.count > 200 ? "\n[More entries omitted]" : "")
    }
}

struct AssistantPlan: Decodable { let intent:String;let app:String;let text:String }
@MainActor enum PhoneAssistant {
    static func explicitPlan(_ text:String) -> AssistantPlan? {
        let input=text.trimmingCharacters(in:.whitespacesAndNewlines),lower=input.lowercased()
        for prefix in ["open folder ", "list folder ", "show folder ", "read file "] where lower.hasPrefix(prefix) {
            return AssistantPlan(intent: prefix == "read file " ? "readFile" : prefix == "open folder " ? "openFolder" : "listFolder", app: "", text: String(input.dropFirst(prefix.count)))
        }
        for prefix in ["new chat in ", "new task in "] where lower.hasPrefix(prefix) { return AssistantPlan(intent: "newChat", app: String(input.dropFirst(prefix.count)), text: "") }
        if lower == "check the weather" || lower == "check weather" || lower == "weather" { return AssistantPlan(intent: "weather", app: "", text: "") }
        if lower.contains("desktop") && ["what","list","file","name","show"].contains(where:lower.contains) {return AssistantPlan(intent:"desktop",app:"",text:input)}
        if lower=="open framer"||lower.contains("framer")&&lower.contains("subframe") {return AssistantPlan(intent:"framer",app:"",text:input)}
        if lower.hasPrefix("search google for "){return AssistantPlan(intent:"search",app:"",text:String(input.dropFirst(18)))}
        if lower.hasPrefix("google "){return AssistantPlan(intent:"search",app:"",text:String(input.dropFirst(7)))}
        if lower.hasPrefix("open "){return AssistantPlan(intent:"open",app:String(input.dropFirst(5)),text:"")}
        for prefix in ["in ","ask ","send to "] where lower.hasPrefix(prefix) {
            let remaining=String(input.dropFirst(prefix.count))
            if let colon=remaining.firstIndex(of:":"){return AssistantPlan(intent:"send",app:String(remaining[..<colon]).trimmingCharacters(in:.whitespaces),text:String(remaining[remaining.index(after:colon)...]).trimmingCharacters(in:.whitespacesAndNewlines))}
        }
        return nil
    }
    static func plan(_ input:String) async throws -> AssistantPlan {
        if let plan=explicitPlan(input){return plan}
        guard AssistantSettings.modelsEnabled, #available(macOS 26.0,*),SystemLanguageModel.default.isAvailable else{return AssistantPlan(intent:"answer",app:"",text:input)}
        try AssistantSettings.requireModel()
        let schema=try GenerationSchema(root:DynamicGenerationSchema(name:"PhoneIntent",properties:[
            .init(name:"intent",description:"Choose answer for knowledge questions; desktop for Desktop file names; search for Google search; framer for Framer/Subframe; open to open an app; inspect for visible app text; send to type and submit the requested prompt into a named app. Use openFolder/listFolder/readFile for explicit paths (text must preserve the exact user path); newChat to start a new chat in an explicitly named app; weather for the Weather app. Shell/file mutations use unsupported.",schema:DynamicGenerationSchema(name:"Intent",anyOf:["answer","desktop","search","framer","open","inspect","send","openFolder","listFolder","readFile","newChat","weather","unsupported"])),
            .init(name:"app",description:"User's named target application; empty for answer/desktop/search/framer. Never invent a target.",schema:DynamicGenerationSchema(type:String.self)),
            .init(name:"text",description:"Exact requested search query or prompt for the named target. For answer preserve the user's question. No generated commands, paths or scripts.",schema:DynamicGenerationSchema(type:String.self))
        ]),dependencies:[])
        let session=LanguageModelSession(model:SystemLanguageModel.default,instructions:"Classify the user's single request. Return one intent. Folder/file tools require an explicit user path, preserved exactly in text. Never invent a path. New chat requires a named app. Knowledge questions use answer. Never perform actions or invent tool access. Destructive, shell, file write requests use unsupported. App send requires an explicit named target and request to submit text. Preserve the user's text.")
        let response=try await session.respond(to:input,schema:schema,options:GenerationOptions(temperature:0,maximumResponseTokens:400))
        try Task.checkCancellation()
        return try JSONDecoder().decode(AssistantPlan.self,from:Data(response.content.jsonString.utf8))
    }
    static func resolveApp(_ name:String,allowed:[String]) throws -> String {
        let clean=name.lowercased().trimmingCharacters(in:.whitespacesAndNewlines)
        let alias:[String:String]=["codex":"com.openai.codex","weather":"com.apple.weather","chatgpt":"com.openai.chat","chatgpt classic":"com.openai.chat","chrome":"com.google.Chrome","google chrome":"com.google.Chrome","subframe":"com.subframe.desktop","finder":"com.apple.finder","calculator":"com.apple.calculator","safari":"com.apple.Safari"]
        if let known=alias[clean],allowed.contains(known){return known}
        if let bundle=allowed.first(where:{$0.lowercased()==clean||AppControl.appName($0).lowercased()==clean}){return bundle}
        throw StudioError.message("This app is not approved for the assistant. Add its bundle identifier to the Phone Assistant action on your Mac and approve the edited workflow again.")
    }
    static func execute(_ input:String,allowed:[String],desktop:Bool,onSnapshot:(String)->Void) async throws -> WorkflowValue {
        guard !input.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty,input.count<=4000 else{throw StudioError.message("Enter a command or question in 1–4,000 characters.")}
        if input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "reminder status" {
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            let pending = await center.pendingNotificationRequests().filter { $0.identifier.hasPrefix("studio.reminder.") }
            let delivered = await center.deliveredNotifications().filter { $0.request.identifier.hasPrefix("studio.reminder.") }
            var lines = ["Mac reminder status", "Authorization: " + String(settings.authorizationStatus.rawValue) + " (2 = authorized)", "Banners: " + String(settings.alertSetting.rawValue) + " (2 = enabled)", "Notification Centre: " + String(settings.notificationCenterSetting.rawValue) + " (2 = enabled)", "Pending: " + String(pending.count), "Delivered records: " + String(delivered.count)]
            for request in pending { lines.append("Pending: " + request.content.body + " · " + String(describing: (request.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate())) }
            for notification in delivered { lines.append("Delivered: " + notification.request.content.body + " · " + notification.date.description) }
            return .text(lines.joined(separator: "\n"))
        }
        if let reminder = try ReminderRequest.parse(input) {
            let center = UNUserNotificationCenter.current()
            guard try await center.requestAuthorization(options: [.alert, .sound]) else { throw StudioError.message("Allow Shortcut Studio notifications in macOS Notifications settings. No reminder was scheduled.") }
            try Task.checkCancellation()
            let content = UNMutableNotificationContent(); content.title = "Shortcut Studio"; content.body = reminder.message; content.sound = .default
            var calendar = Calendar.current
            calendar.timeZone = TimeZone.current
            var components = reminder.repeats ? DateComponents(hour: reminder.hour, minute: reminder.minute) : calendar.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.date)
            components.calendar = calendar; components.timeZone = calendar.timeZone
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: reminder.repeats)
            let digest = SHA256.hash(data: Data((reminder.message + "|" + String(reminder.hour) + "|" + String(reminder.minute) + "|" + (reminder.repeats ? "daily" : reminder.date.description)).utf8)).map { String(format: "%02x", $0) }.joined()
            let id = "studio.reminder." + digest
            try await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
            let requests = await center.pendingNotificationRequests()
            guard let stored = requests.first(where: { $0.identifier == id }), let next = (stored.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate() else { throw StudioError.message("macOS did not retain the reminder. Check notification settings.") }
            let formatter = DateFormatter(); formatter.dateStyle = .medium; formatter.timeStyle = .short
            return .text("Scheduled on this Mac: " + formatter.string(from: next) + " (" + calendar.timeZone.identifier + "). " + (reminder.repeats ? "Repeats daily." : "Once only; no repeat.") + "\n" + reminder.message + "\nmacOS holds this notification; Studio inference is not used. Focus or notification settings may suppress the banner.")
        }
        let control = input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if ["model on", "models on", "model off", "models off", "model status"].contains(control) {
            if control != "model status" { AssistantSettings.modelsEnabled = control.hasSuffix("on") }
            return .text("Studio model use: \(AssistantSettings.modelsEnabled ? "on, on demand only" : "off"). \(OnDeviceIntelligence.status). No background inference runs while waiting for commands.")
        }
        onSnapshot("Understanding your request…")
        let plan=try await plan(input);try Task.checkCancellation()
        switch plan.intent {
        case "desktop":guard desktop else{throw StudioError.message("Desktop filename access is not approved in this workflow.")};return try AppControl.readDesktop()
        case "openFolder", "listFolder", "readFile":
            let result = try AssistantSettings.files(plan.text, desktop: desktop, read: plan.intent == "readFile")
            if plan.intent == "openFolder" { NSWorkspace.shared.open(try AssistantSettings.folder(plan.text, desktop: desktop)) }
            return .text(result)
        case "newChat":
            let bundle = try resolveApp(plan.app, allowed: allowed)
            return .text(try await AppControl.newChat(bundle))
        case "weather":
            let bundle = try resolveApp("weather", allowed: allowed)
            try await AppControl.open(bundle)
            return .text(try await AppControl.waitForText(bundle))
        case "search":
            guard allowed.contains("com.google.Chrome"),let app=NSWorkspace.shared.urlForApplication(withBundleIdentifier:"com.google.Chrome") else{throw StudioError.message("Chrome is not approved or installed.")}
            var url=URLComponents(string:"https://www.google.com/search")!;url.queryItems=[URLQueryItem(name:"q",value:plan.text)]
            try await NSWorkspace.shared.open([url.url!],withApplicationAt:app,configuration:NSWorkspace.OpenConfiguration());return .text("Google search: " + plan.text + "\n\n" + (try await AppControl.waitForText("com.google.Chrome", expectedURL: url.url!)))
        case "framer":
            guard allowed.contains("com.google.Chrome"),allowed.contains("com.subframe.desktop"),let chrome=NSWorkspace.shared.urlForApplication(withBundleIdentifier:"com.google.Chrome") else{throw StudioError.message("Approve Chrome and Subframe in the assistant workflow.")}
            try await NSWorkspace.shared.open([URL(string:"https://framer.com/")!],withApplicationAt:chrome,configuration:NSWorkspace.OpenConfiguration());try await AppControl.open("com.subframe.desktop");return .text("Framer opened in Chrome and Subframe launched on your Mac.")
        case "open":let bundle=try resolveApp(plan.app,allowed:allowed);try await AppControl.open(bundle);return .text("Opened \(AppControl.appName(bundle)) on your Mac.")
        case "inspect":let bundle=try resolveApp(plan.app,allowed:allowed);try await AppControl.open(bundle);return .text(try AppControl.visibleText(bundle))
        case "send":let bundle=try resolveApp(plan.app,allowed:allowed);return .text(try await AppControl.sendAndRead(plan.text,bundle:bundle,onSnapshot:onSnapshot))
        case "answer":return .text(try await OnDeviceIntelligence.generate(prompt:input,instructions:"Answer the user's question concisely. You have no live screen or file access in this answer. Never claim to perform a task. If it needs a tool beyond this assistant's supported tasks, explain the limitation.",onSnapshot:onSnapshot))
        default:return .text("Supported: questions, Desktop filenames, Google search, opening approved apps, reading their visible text, and sending a prompt to an approved app. Arbitrary shell commands and file mutations are not enabled.")
        }
    }
}
