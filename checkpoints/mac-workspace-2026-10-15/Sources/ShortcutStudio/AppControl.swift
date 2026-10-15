import Foundation
import AppKit
import ApplicationServices
import WorkflowCore

@MainActor enum AppControl {
    static var isTrusted: Bool { AXIsProcessTrusted() }
    static func requestPermission() { _ = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String:true] as CFDictionary) }
    static func readDesktop(from directory: URL? = nil) throws -> WorkflowValue {
        let folder = directory ?? FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0]
        do {
            let urls = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
            let names = urls.map(\.lastPathComponent).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
            if names.isEmpty { return .text("Your Desktop has no visible files or folders.") }
            let suffix = names.count > 200 ? ["… \(names.count - 200) more entries (not shown)."] : []
            return .list((Array(names.prefix(200)) + suffix).map { .text($0) })
        } catch { throw StudioError.message("macOS could not read Desktop filenames. Allow Shortcut Studio to access Desktop in System Settings → Privacy & Security → Files and Folders, then retry.") }
    }
    static func appName(_ bundle: String) -> String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundle) else { return bundle }
        return url.deletingPathExtension().lastPathComponent
    }
    static func open(_ bundle: String) async throws {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundle) else { throw StudioError.message("\(bundle) is not installed.") }
        try await NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }
    private static func attribute(_ e: AXUIElement, _ name: String) -> AnyObject? {
        var value: CFTypeRef?; guard AXUIElementCopyAttributeValue(e, name as CFString, &value) == .success else { return nil }; return value
    }
    private static func string(_ e: AXUIElement, _ name: String) -> String { attribute(e,name) as? String ?? "" }
    private static func descendants(_ root: AXUIElement) -> [AXUIElement] {
        var nodes:[AXUIElement]=[], queue:[(AXUIElement,Int)]=[(root,0)], index=0
        while index<queue.count && nodes.count<600 {
            let (e,depth)=queue[index];index+=1;nodes.append(e)
            guard depth<16 else {continue}
            let children=attribute(e,kAXChildrenAttribute) as? [AXUIElement] ?? []
            queue.append(contentsOf:children.prefix(60).map{($0,depth+1)})
        };return nodes
    }
    private static func content(_ bundle: String) throws -> (AXUIElement, [AXUIElement], pid_t) {
        guard isTrusted else {throw StudioError.message("Enable Accessibility for Shortcut Studio in System Settings → Privacy & Security → Accessibility to control apps.")}
        guard let app=NSRunningApplication.runningApplications(withBundleIdentifier:bundle).first else {throw StudioError.message("Application is not running.")}
        let root=AXUIElementCreateApplication(app.processIdentifier);AXUIElementSetMessagingTimeout(root,0.5)
        guard let value=attribute(root,kAXMainWindowAttribute) ?? (attribute(root,kAXWindowsAttribute) as? [AXUIElement])?.first else {throw StudioError.message("No accessible application window. Open the app and sign in locally if needed.")}
        let window=value as! AXUIElement
        let all=descendants(window)
        // Read the active web document instead of other browser tabs/address bars.
        if let web=all.first(where:{string($0,kAXRoleAttribute)=="AXWebArea"}) {return (window,descendants(web),app.processIdentifier)}
        return (window,all,app.processIdentifier)
    }
    static func visibleText(_ bundle:String) throws -> String {
        let (_,nodes,_)=try content(bundle);var lines:[String]=[]
        for e in nodes {
            let role=string(e,kAXRoleAttribute)
            guard ["AXStaticText","AXTextArea","AXTextField","AXHeading"].contains(role) else{continue}
            let value=string(e,kAXValueAttribute),title=string(e,kAXTitleAttribute)
            let text=String((value.isEmpty ? title:value).prefix(1000))
            if !text.isEmpty && lines.last != text {lines.append(text)}
        }
        return String(lines.joined(separator:"\n").prefix(14000))
    }
    static func waitForText(_ bundle: String, expectedURL: URL? = nil) async throws -> String {
        guard isTrusted else { throw StudioError.message("App opened, but returning its results requires App Control permission in Phone Messenger.") }
        var last = "", stable = 0
        for _ in 0..<15 {
            try Task.checkCancellation()
            try await Task.sleep(nanoseconds: 1_000_000_000)
            if let expectedURL {
                let nodes = try content(bundle).1
                let actual = nodes.compactMap { e -> URL? in
                    guard string(e, kAXRoleAttribute) == "AXWebArea", let raw = attribute(e, kAXURLAttribute) else { return nil }
                    return (raw as? URL) ?? (raw as? String).flatMap(URL.init(string:))
                }.first
                let expectedQuery = URLComponents(url: expectedURL, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "q" }?.value
                let actualQuery = actual.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }?.queryItems?.first { $0.name == "q" }?.value
                guard actual?.host == expectedURL.host, actual?.path == expectedURL.path, actualQuery == expectedQuery else { continue }
            }
            let text = try visibleText(bundle)
            if text == last { stable += 1 } else { last = text; stable = 0 }
            if !last.isEmpty && stable >= 2 { return "Visible text from \(appName(bundle)):\n" + last }
        }
        guard !last.isEmpty else { throw StudioError.message("The app opened but exposes no readable result. It may need local setup, login, location permission, or an accessible window.") }
        return "Visible text from \(appName(bundle)) (still changing):\n" + last
    }
    static func newChat(_ bundle: String) async throws -> String {
        try await open(bundle)
        try await Task.sleep(nanoseconds: 1_000_000_000)
        let (_, nodes, _) = try content(bundle)
        let labels = ["new chat", "new task", "start new chat", "start new task"]
        guard let button = nodes.first(where: { e in
            guard ["AXButton", "AXMenuItem"].contains(string(e, kAXRoleAttribute)) else { return false }
            return [string(e, kAXTitleAttribute), string(e, kAXDescriptionAttribute)].contains { labels.contains($0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)) }
        }), AXUIElementPerformAction(button, kAXPressAction as CFString) == .success else { throw StudioError.message("No accessible New Chat/New Task control found in this app. No guessed keyboard shortcut was sent.") }
        return "Pressed New Chat/New Task in \(appName(bundle)).\n" + (try await waitForText(bundle))
    }
    static func type(_ text:String, bundle:String, submit:Bool) async throws {
        guard !text.isEmpty,text.count<=6000 else{throw StudioError.message("App input must contain 1–6,000 characters.")}
        try await open(bundle)
        var found:(AXUIElement,[AXUIElement],pid_t)?
        for _ in 0..<10 {
            try Task.checkCancellation()
            found=try? content(bundle)
            if found?.1.contains(where:{["AXTextArea","AXTextField"].contains(string($0,kAXRoleAttribute))}) == true {break}
            try await Task.sleep(nanoseconds:300_000_000)
        }
        guard let (window,nodes,pid)=found else{throw StudioError.message(isTrusted ? "No accessible app input." : "Enable Accessibility for Shortcut Studio in System Settings → Privacy & Security → Accessibility.")}
        let fields=nodes.filter{["AXTextArea","AXTextField"].contains(string($0,kAXRoleAttribute))}
        let preferred=fields.first{let label=(string($0,kAXDescriptionAttribute)+" "+string($0,kAXTitleAttribute)).lowercased();return label.contains("prompt")||label.contains("message")||label.contains("ask")||label.contains("chat")}
        guard let field=preferred ?? fields.first(where:{string($0,kAXRoleAttribute)=="AXTextArea"}) else{throw StudioError.message("No accessible text input. Click the intended app input on the Mac and retry.")}
        guard string(field,kAXValueAttribute).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw StudioError.message("The app input already contains text. Clear the compose field on your Mac before submitting this prompt.") }
        NSRunningApplication(processIdentifier:pid)?.activate(options:[]);_ = AXUIElementPerformAction(window,kAXRaiseAction as CFString)
        _ = AXUIElementSetAttributeValue(field,kAXFocusedAttribute as CFString,kCFBooleanTrue)
        let result=AXUIElementSetAttributeValue(field,kAXValueAttribute as CFString,text as CFString)
        if result != .success {
            guard let source=CGEventSource(stateID:.combinedSessionState) else{throw StudioError.message("Keyboard input unavailable.")}
            // Target Unicode input at the approved process; no clipboard, shell or URL-bar script.
            let units=Array(text.utf16)
            for offset in stride(from:0,to:units.count,by:20) {
                try Task.checkCancellation();let part=Array(units[offset..<min(offset+20,units.count)])
                guard let down=CGEvent(keyboardEventSource:source,virtualKey:0,keyDown:true),let up=CGEvent(keyboardEventSource:source,virtualKey:0,keyDown:false) else{throw StudioError.message("Keyboard input unavailable.")}
                part.withUnsafeBufferPointer{buffer in down.keyboardSetUnicodeString(stringLength:buffer.count,unicodeString:buffer.baseAddress);up.keyboardSetUnicodeString(stringLength:buffer.count,unicodeString:buffer.baseAddress)}
                down.postToPid(pid);up.postToPid(pid)
            }
        }
        if submit {
            try await Task.sleep(nanoseconds:300_000_000);try Task.checkCancellation()
            let typed = string(field,kAXValueAttribute)
            guard typed.contains(text) else { throw StudioError.message("Could not verify text in the app input. No submit action was sent.") }
            let fresh=try content(bundle).1
            if let send=fresh.first(where:{string($0,kAXRoleAttribute)=="AXButton" && (string($0,kAXTitleAttribute)+" "+string($0,kAXDescriptionAttribute)).lowercased().contains("send")}),AXUIElementPerformAction(send,kAXPressAction as CFString) == .success {return}
            guard let down=CGEvent(keyboardEventSource:nil,virtualKey:36,keyDown:true),let up=CGEvent(keyboardEventSource:nil,virtualKey:36,keyDown:false) else{throw StudioError.message("Submit unavailable.")}
            down.postToPid(pid);up.postToPid(pid)
        }
    }
    static func sendAndRead(_ text:String,bundle:String,onSnapshot:(String)->Void) async throws -> String {
        let before=(try? visibleText(bundle)) ?? ""
        try await type(text,bundle:bundle,submit:true)
        var last="",stable=0
        for index in 0..<90 {
            try await Task.sleep(nanoseconds:1_000_000_000);try Task.checkCancellation()
            let value=(try? visibleText(bundle)) ?? ""
            if !value.isEmpty && value != before {onSnapshot("Visible text in \(appName(bundle)):\n"+value)}
            if value==last {stable+=1}else{stable=0;last=value}
            let generating = (try? content(bundle).1.contains { e in
                guard string(e,kAXRoleAttribute) == "AXButton" else { return false }
                let label = (string(e,kAXTitleAttribute) + " " + string(e,kAXDescriptionAttribute)).lowercased().trimmingCharacters(in:.whitespaces)
                return label == "stop" || label.contains("stop generating")
            }) ?? false
            if !generating && index>=8 && stable>=4 && !last.isEmpty && last != before {return "Visible text in \(appName(bundle)):\n"+last}
        }
        return "Prompt submitted to \(appName(bundle)). No stable visible response was detected within 90 seconds. Check the app on your Mac."
    }
}
