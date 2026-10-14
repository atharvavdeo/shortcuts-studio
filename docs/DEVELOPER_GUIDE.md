# Developer guide

## Prerequisites and checkout

The source tree is a Swift package. Use macOS with a toolchain that includes SwiftUI/AppKit and the Foundation Models SDK, currently the Swift 6.4 / macOS 27 Command Line Tools installation used here. The package language declaration is Swift tools 5.10; that alone does not provide a recent SDK. Full Xcode is recommended for distribution, accessibility tooling, Instruments, and layered icon work. The executable deployment target is macOS 14, with model calls gated at macOS 26.

No remote Git repository is configured. Work from the source ZIP or this directory. A public source license has not been selected; do not infer an MIT license from the use of Swift or from the REA research reference.

```sh
cd ShortcutStudio
bash scripts/test.sh
bash scripts/validate-store.sh
bash scripts/validate-model.sh
swift run --package-path examples/EngineClient
bash scripts/generate-reference.sh
python3 scripts/render-handbook.py
bash scripts/build-app.sh release
python3 scripts/validate-distribution.py
```

Model validation requires an available on-device model; it actually performs inference. The other validation commands use synthetic inputs and isolated storage. Default packaging signs locally and does not upload or notarize anything.

## Source map

| File | Responsibility |
|---|---|
| `Sources/WorkflowCore/Models.swift` | Typed values, actions, workflows, import questions, folders, automations, run records, library/export envelopes |
| `Catalog.swift` | 64 definitions, editor defaults, choices, symbols, categories, and starter workflows |
| `Engine.swift` | MainActor host protocol, structural validator, reference resolution, bounded interpreter, core actions |
| `WorkflowEdits.swift` | Whole-block movement/duplication/removal, identity/reference/question remapping |
| `Persistence.swift` | Version/ID/schedule checks, atomic library save/backup, recovery and workflow import/export |
| `AutomationSchedule.swift` | Pure calendar/time-window/weekday/claimed-day decision |
| `ModelDraft.swift` | Untrusted model draft decoding and validation |
| `Sources/ShortcutStudio/StudioStore.swift` | Observable app state, mutation/undo, session inputs, run lifecycle, native actions, automations, imports, Apple library |
| `StudioApp.swift` | Scene/menus, sidebar, library/editor/inspectors/gallery/history, model draft sheet |
| `AutomationView.swift` | Presets, creation/editing form, weekday controls, rule list |
| `OnDeviceIntelligence.swift` | Availability, fresh model sessions, streamed text and two-pass guided authoring |
| `ProcessRunner.swift` | Argument-safe child process, cancellation, timeout, temporary output capture |
| `scripts/` | Tests, probes, generated references, handbook rendering, packaging, signing, artifact validation |
| `verification/` | Dated synthetic logs, fixtures and build provenance; never the user's real library |

## Use the public Swift library

The package exports **WorkflowCore** as a library product. A neighboring Swift package can depend on the local checkout:

```swift
// In the client's Package.swift:
dependencies: [.package(path: "../ShortcutStudio")]
// In a target's dependencies:
.product(name: "WorkflowCore", package: "shortcutstudio")
```

Import `WorkflowCore`, instantiate a host, build a `Workflow`, validate, and call `WorkflowEngine.run`. The complete executable example is in `examples/EngineClient`; its own package path is `../..` because it lives inside this checkout. It checks the exact `HELLO, WORLD!` result. See [Swift API reference](SWIFT_API_REFERENCE.md).

`WorkflowEngine` holds its host **unowned**. Keep the host alive for the entire run. The engine and host protocol are MainActor isolated. Use a fresh engine per run or serialize access; its mutable step counter is not a concurrency scheduler. The app store itself permits only one active workflow. `WorkflowCore` currently targets the Apple/macOS toolchain; this is not an Android library binary.

## Follow the data path

1. The editor obtains `definition.action`, which fills parameter defaults.
2. The store mutates a selected workflow, records authoring undo where appropriate, and saves.
3. Run snapshots the workflow and input, clears authoring undo, creates a task and engine.
4. Structural validation rejects unknown kinds, duplicate IDs, mismatched markers, disabled markers, and deep nesting.
5. Parameters are resolved just before each action. An exact reference retains a typed value; interpolation yields text.
6. Core actions execute in the interpreter. Host actions call `WorkflowHost.perform` with resolved parameters and the selected input.
7. Host storage persistence must succeed before the interpreter updates committed state.
8. Step callbacks update live output/progress. Run completion inserts a bounded history record and saves.

The interpreter's control logic is deterministic; Date, Random, network responses, system apps, and models naturally have variable outputs. Validation of structure is not full validation of every parameter or future external effect.

## Add a core action

This is an edit to the implementation, not runtime plugin registration. The catalog is static.

1. Choose a stable, unique `kind`; changing it breaks saved workflows unless you migrate them.
2. Add an `ActionDefinition` through Catalog's local `d` helper, with keys, defaults, choices, category, symbol and honest capability description.
3. Implement the kind in `WorkflowEngine.perform` for pure/data operations. Use resolved `WorkflowValue`; reject invalid numeric/range/type input clearly.
4. If it opens apps, asks permissions, interacts with files/UI, or uses a platform service, implement it in the macOS host instead.
5. Add positive, malformed-input, cancellation, persistence and side-effect tests as applicable. Test block/reference behavior if relevant.
6. Regenerate reference files and the handbook. Update privacy/API inventory and the standards audit.
7. Check model drafting: it derives its action-plan enum and per-step parameter schemas from the catalog, so new actions are exposed to generation automatically.

Illustrative insertion for a new pure text action:

```swift
// Catalog definition (inside its definitions closure):
d("reverseText", "Reverse Text", "Text", "textformat", "Reverse text by Character.", [input])
// Engine switch (where helper s resolves parameter text):
case "reverseText": return .text(String(s("input").reversed()))
```

Those fragments require insertion into their named scopes; they are not an already-registered action. A test should use `{{previous}}` from a Text action and verify Unicode Character behavior. Avoid arbitrary evaluation of model-produced code.

## Add a platform action

Register it in the catalog and handle it in `StudioStore.perform`. `try Task.checkCancellation()` runs before host dispatch; cooperative loops need further cancellation checks. Native sheets must have a valid parent. An OS error should fail the action, not silently pass input as if it succeeded. Request only the service's required permission when the user invokes the capability; a usage-description key is an explanation, not authorization.

Do not add global ATS exemptions, broad sandbox exceptions, shell interpolation, private frameworks, or unused entitlements to make a feature appear to work. Update the action's capability/permission notes and verify on actual hardware. If a capability needs a target/extension or signing entitlement, specify that dependency explicitly.

## Persistence, format and migrations

`LibraryDocument.schemaVersion == 1` and `WorkflowFile(format: "studio.shortcut", version: 1)` are separate envelopes. Swift's synthesized Codable representation of `WorkflowValue` is a **tagged enum**, not the raw JSON produced by `jsonText`. [Encoding examples](workflow-value-encoding.json) are generated from actual code. Keep this distinction when writing a parser in Kotlin or another language.

The current library model's optional `weekdays` lets older automation documents decode without a migration. Adding a nonoptional field with a Swift default does not necessarily make synthesized decoding tolerate its absence; test old fixtures. A new format requires explicit version support/migration, preservation of original bytes, and rejected unsupported versions. Never rotate corrupt bytes into the last valid backup.

Imported workflows get a new workflow/action/question identity map. Runtime storage may be included in exports. Do not include user library/history in source ZIPs, issues, model fixtures, or build artifacts.

## Extend automation

Pure time eligibility belongs in `AutomationSchedule`. OS observers belong in the macOS host; configuration belongs in `AutomationView`. Maintain claim-before-run persistence, one-run serialization, busy behavior, cooldowns, weekday/time-zone semantics and missing/deleted workflow handling.

A browser URL visit is **not** an app activation. Such a trigger would need a deliberate browser integration and permissions plus host/authentication tests. A background/login service would need its own lifecycle, ownership and platform-policy work; the current timer is not that service.

## Extend intelligence

Keep explicit model selection, availability checks and cancellation. Current text streaming uses cumulative snapshots. Draft generation makes two fresh sessions: a catalog action plan and per-step schema filling. Never execute a draft during generation. Validate it, display it, and require explicit acceptance and Run. Do not infer context size, model weights or processor placement from the API name.

Model text is untrusted. Guided generation constrains shape; it cannot certify semantic correctness. Check examples against requested kinds and expected outputs, not just decodable JSON. Limit response/prompt size and document errors rather than introducing hidden cloud fallback.

## Test and release discipline

- The core test suite is Swift Testing, with explicit CLT macro plugin registration when necessary.
- Store validation compiles the actual app store into an isolated synthetic harness.
- Model validation compiles the actual core/service and checks live streams, drafts and cancellation.
- Native UI observations cover prompts, import/export, input, model generation and actual app/browser effects.
- Packaging validates bundle metadata, handbook freshness, catalog coverage, contrast arithmetic, privacy declaration, signature and archives. It cannot certify HIG compliance or App Review.

Use small synthetic fixtures. Preserve logs and exact build hashes. See [Release guide](RELEASE_GUIDE.md) for public distribution gates and [Apple standards audit](APPLE_STANDARDS_AUDIT.md) for manual design/accessibility checks.

## Messenger extension

The 0.3.0 browser companion connects through a separate Node messenger and outbound Mac polling actor. See [Messenger guide](MESSENGER_GUIDE.md) for setup, crypto formats, authorization, lifecycle and limits. `StudioStore.run` now returns Bool and optionally accepts `remotely` and a completion callback. The messenger journals acceptance before invoking it and rejects unsupported capabilities. `MessengerConnector` accepts an optional credential-access closure for isolated tests; the default production path is Keychain. Never replace the default with a plaintext credential store in a distributed app.
