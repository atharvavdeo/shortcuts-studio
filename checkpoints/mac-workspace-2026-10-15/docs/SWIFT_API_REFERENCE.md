# Swift and Apple API reference

## WorkflowCore public contract

The code is authoritative. Public types currently live in `Sources/WorkflowCore`. This is a source-level library API, not a promised stable ABI or dynamic plugin interface.

| Type | Use | Important constraints |
|---|---|---|
| `WorkflowValue` | `.null`, `.text`, `.number`, `.bool`, `.list`, `.dictionary`; text/numeric/items/JSON conversions | `fromJSON` converts raw JSON; Codable storage is a different tagged representation; finite numbers are required by numeric actions |
| `WorkflowAction` | UUID, kind, string parameters, enabled flag | Initialization alone does not fill catalog defaults |
| `Workflow` | Name/icon/color, actions, folders, storage, setup questions, favorite/trash/update metadata | `duplicated()` remaps internal identities/references/questions |
| `ActionParameter` / `ActionDefinition` | Labels, defaults, choices, category, symbol, details | `definition.action` produces an action with defaults |
| `ActionCatalog` | Definitions, category order, block builders and templates | Static catalog; there is no public dynamic registration API |
| `WorkflowValidator` / `ValidationIssue` | Structural issues and visual indentation | Runtime resolution/type/range/system checks still occur later |
| `WorkflowHost` | Platform operations, named workflow lookup, storage commits, step callbacks | MainActor protocol; host owns platform permissions and effects |
| `WorkflowEngine` | `run(_:input:) async throws -> WorkflowValue`; configurable `maximumSteps` | MainActor; host retained unowned; serialize runs; default 10,000 steps |
| `WorkflowEdits` | Whole-block span/move/duplicate/remove | Maintains structural invariants and remaps references/questions |
| `LibraryRepository` | Load/save/recover library; encode/decode exported workflow | Atomic writes, bounded imports, prior valid backup, fail-closed version/ID/schedule validation |
| `AutomationRule` / `AutomationSchedule` | Trigger/time/day/claim model; pure `isDue` | Optional weekdays 1–7 (Sunday–Saturday); local Calendar semantics |
| `ModelDraft` | Decode untrusted generated action/parameter arrays into a local Workflow | Local IDs, <=20 actions, allowed keys/choices, strict reference syntax, structural validation |
| `LibraryDocument`, `WorkflowFile`, `RunRecord`, `WorkflowFolder`, `ImportQuestion` | Persistence envelopes and supporting records | Library and exported file versions are separate; history and stored values can be personal |

## Implement a host

```swift
import Foundation
import WorkflowCore

@MainActor final class MinimalHost: WorkflowHost {
    var workflows: [Workflow] = []
    var storage: [UUID: [String: WorkflowValue]] = [:]

    func perform(_ kind: String, parameters: [String: WorkflowValue],
                 input: WorkflowValue) async throws -> WorkflowValue {
        throw StudioError.message("Platform action is not enabled: \(kind)")
    }
    func workflow(named name: String) -> Workflow? {
        workflows.first { $0.name == name }
    }
    func persistStorage(_ value: [String: WorkflowValue], workflowID: UUID) throws {
        storage[workflowID] = value // In production, make the required durable write here.
    }
    func stepStarted(_ actionID: UUID, title: String) {}
    func stepFinished(_ actionID: UUID, output: WorkflowValue) {}
}
```

The executable, checked example is `examples/EngineClient`. This minimal host refuses external actions and stores only in memory. It does not promise the app's durable storage semantics.

## UI and lifecycle APIs in the app

| API | Actual role | Reference |
|---|---|---|
| `SwiftUI.App`, `WindowGroup`, `NavigationSplitView` | Native scene/window/sidebar composition | [SwiftUI](https://developer.apple.com/documentation/swiftui) |
| `ObservableObject`, `@Published`, `@StateObject` | MainActor store drives rendering | [ObservableObject](https://developer.apple.com/documentation/combine/observableobject) |
| `SwiftUI.State` via `ViewState` alias | Local form/sheet/control state | [State](https://developer.apple.com/documentation/swiftui/state) |
| `Button`, `Menu`, `TextEditor`, `Picker`, `Form`, `List` | Native controls, menu alternatives, multiline input | [Controls and indicators](https://developer.apple.com/documentation/swiftui/controls-and-indicators) |
| `accessibilityLabel`, `accessibilityValue`, element containment, `accessibilityReduceMotion` | Descriptive controls, selected state, motion adaptation | [SwiftUI accessibility](https://developer.apple.com/documentation/swiftui/accessibility) |
| `NSApplicationDelegate`, `NSApplication` | File open delivery, app lifecycle, About panel | [AppKit](https://developer.apple.com/documentation/appkit) |
| `NSAlert.beginSheetModal` | Ask/choose/show/alert with Continue/Cancel | [NSAlert](https://developer.apple.com/documentation/appkit/nsalert) |
| `NSOpenPanel`, `NSSavePanel` | Native file selection/import/export/save | [NSOpenPanel](https://developer.apple.com/documentation/appkit/nsopenpanel), [NSSavePanel](https://developer.apple.com/documentation/appkit/nssavepanel) |
| `UTType(exportedAs:conformingTo:)` | `tools.shortcutstudio.workflow` conforms to `public.json` | [Type declaration](https://developer.apple.com/documentation/uniformtypeidentifiers/defining-file-and-data-types-for-your-app) |

The State alias addresses a missing SwiftUIMacros plugin in this CLT installation; it does not modify Apple's SDK. Standard controls still require actual keyboard/VoiceOver/layout testing. The app currently shares one store between its WindowGroup scenes; it is not a complete document-window architecture.

## System action APIs

| API | Actual role | Behavior / reference |
|---|---|---|
| `NSWorkspace.urlForApplication(withBundleIdentifier:)` | Resolve installed browser/app | Throws a workflow error when absent; [NSWorkspace](https://developer.apple.com/documentation/appkit/nsworkspace) |
| `NSWorkspace.openApplication(at:configuration:)` | Open App | Successful launch callback is not proof that an app's remote content loaded |
| `NSWorkspace.open(_:withApplicationAt:configuration:)` | Explicit browser Open URL | Separate URL/application values, no shell |
| `NSWorkspace.open(_:)` | Registered URL handler; native Apple file import; local handbook | UI/system launch errors handled; network/app policies remain external |
| `NSPasteboard.general` | Clipboard read/write and change-count trigger | Studio's own Copy updates the tracked count to avoid self-triggering; [NSPasteboard](https://developer.apple.com/documentation/appkit/nspasteboard) |
| `UNUserNotificationCenter` | Request authorization and add notifications | Permission denial fails the action; [UserNotifications](https://developer.apple.com/documentation/usernotifications) |
| `AVSpeechSynthesizer`, `AVSpeechUtterance` | Speak Text | Cooperative waiting; stopSpeaking on cancellation; [speech](https://developer.apple.com/documentation/avfaudio/avspeechsynthesizer) |
| `NSWorkspace.notificationCenter` | Activation, termination, wake, will-sleep | App-specific observer events; no browser URL visibility |
| `Timer`, `Calendar` | 15-second polling and daily/weekday scheduling | Timer depends on the running app; calendar/time-zone/DST behavior needs fixtures |
| `URLSession.bytes(for:)` | Stream and bound HTTP bodies | 30-second timeout, status validation, <=10 MB response; [URLSession](https://developer.apple.com/documentation/foundation/urlsession) |
| `FileManager`, `Data.write(.atomic)`, `URL.resourceValues` | Library, backups, UTF-8 data and file sizes | No bookmark/sandbox grant system is implemented; [FileManager](https://developer.apple.com/documentation/foundation/filemanager) |
| `NSRegularExpression` | Match, replace, reference parsing | Synchronous on MainActor; no worker isolation; [regex](https://developer.apple.com/documentation/foundation/nsregularexpression) |
| `Process`, `FileHandle`, cancellation task, `Darwin.kill` | CLI bridge capture/timeout/termination | Separate arguments; outputs bounded after process exit; [Process](https://developer.apple.com/documentation/foundation/process) |

The app uses public APIs. Spawning `/usr/bin/shortcuts` is delegation to Apple's engine. It does not register App Intents, acquire privileged entitlements, bypass TCC, or expose Apple's private action engine to Android.

## Foundation Models calls

The model service is internal to the macOS executable; it is not exported by the WorkflowCore library. Its current methods are `status`, `generate(prompt:instructions:onSnapshot:)`, and `draft(description:)`.

```swift
import FoundationModels

// Execute inside a macOS-26 availability gate and check model availability first.
let model = SystemLanguageModel.default
let session = LanguageModelSession(model: model, instructions: "Be concise.")
var final = ""
for try await snapshot in session.streamResponse(
    to: "Summarize this text...",
    options: GenerationOptions(maximumResponseTokens: 1024)
) {
    try Task.checkCancellation()
    final = snapshot.content // Cumulative snapshot: replace, do not append.
}
```

This excerpt needs an async context, an availability guard, and caller error handling. The actual service includes those checks. No tool objects or cloud models are passed. [Apple's framework](https://developer.apple.com/documentation/foundationmodels) provides model/session/guided-generation APIs; [WWDC introduction](https://developer.apple.com/videos/play/wwdc2025/286/) explains the on-device use case.

Drafting uses `DynamicGenerationSchema`, `GenerationSchema`, enum choices, per-step properties and `session.respond(to:schema:options:)`. Temperature is 0, but semantic correctness is still not guaranteed. The schema constrains action/parameter shape and simple input wiring; `ModelDraft` verifies the accepted result. The service intentionally avoids `@Generable` macro dependency in this CLT environment.

## Intended extension points, not implemented APIs

The browser messenger now has a separate authenticated relay, run completion callbacks, workflow grants, idempotency journal and filtered encrypted results. `StudioStore.run` returns whether it started and accepts a completion callback; the messenger owns its run journal and only streams the current owned remote run. Global UI output is not exposed as an unrestricted endpoint. [Remote protocol proposal](REMOTE_PROTOCOL_PROPOSAL.md) defines a new contract to implement before connecting the outbound Mac messenger to an internet gateway.
