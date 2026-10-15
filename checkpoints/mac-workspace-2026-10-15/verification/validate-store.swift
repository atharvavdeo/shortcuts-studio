import Foundation
import AppKit

@main struct StoreValidation {
    @MainActor static func main() async {
        _ = NSApplication.shared
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("studio-store-check-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        func check(_ condition: Bool, _ message: String) throws { guard condition else { throw StudioError.message(message) }; print("PASS \(message)") }
        do {
            let store = StudioStore(directory: directory)
            store.create(Workflow(name: "Input Check", actions: [ActionCatalog.definition("input")!.action]))
            let firstID = store.selectedID!
            store.selectedProvidesInput = true; store.selectedTextInput = "Keyboard input\nUnicode ✓"
            store.runSelected()
            while store.isRunning { try await Task.sleep(nanoseconds: 10_000_000) }
            try check(store.output == .text("Keyboard input\nUnicode ✓"), "prepared input reaches runtime")
            store.create(Workflow(name: "Other", actions: [ActionCatalog.definition("number")!.action]))
            let secondID = store.selectedID!
            try check(!store.selectedProvidesInput && store.selectedTextInput.isEmpty, "inputs are isolated by shortcut")
            store.selectedID = firstID
            try check(store.selectedProvidesInput && store.selectedTextInput == "Keyboard input\nUnicode ✓", "switching back restores session input")
            store.selectedTextInput = ""; store.runSelected()
            while store.isRunning { try await Task.sleep(nanoseconds: 10_000_000) }
            try check(store.output == .text(""), "empty configured input remains Text")
            store.addAutomation(workflowID: firstID, name: "Edit Check", trigger: "time", hour: 9, minute: 0)
            let id = store.library.automations.last!.id
            store.toggleAutomation(id)
            store.updateAutomation(id, workflowID: secondID, name: "Weekday Check", trigger: "time", hour: 10, minute: 30, weekdays: [2, 3, 4, 5, 6])
            let rule = store.library.automations.last!
            try check(rule.id == id && !rule.isEnabled && rule.workflowID == secondID && rule.weekdays == [2, 3, 4, 5, 6], "automation editing preserves identity and disabled state")
            let reload = StudioStore(directory: directory)
            try check(reload.library.automations.last == rule, "edited automation persists across reload")
            store.updateAutomation(id, workflowID: secondID, name: "Invalid", trigger: "time", hour: 10, minute: 30, weekdays: [8])
            try check(store.library.automations.last == rule && store.saveFailure != nil, "invalid schedule update fails without publishing")
            print("STORE VALIDATION PASS")
        } catch { print("STORE VALIDATION FAIL: \(error)"); exit(1) }
    }
}
