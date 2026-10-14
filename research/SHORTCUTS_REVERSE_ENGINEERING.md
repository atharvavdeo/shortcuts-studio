# Apple Shortcuts recreation: evidence and behavior specification

Research date: 13 October 2026. Implementation target remains undecided. Android work follows the Apple behavior study.

## Scope and evidence standard

This document records an initial examination of the installed macOS Shortcuts application, its bundle, command contracts, action metadata, and native interface. It is a foundation for recreation, not a claim that Apple's complete implementation has been recovered. No workflow was run, no action was added, no settings were changed, and no native code was decompiled during this pass. An existing empty shortcut was opened for observation. User shortcut names and contents are omitted from saved evidence.

Each finding uses one of four statuses: observed in the live interface; extracted from installed static artifacts; documented by Apple; or a proposed design/experiment. Framework names and link declarations do not prove which code executes for a given action. A setting being present does not prove how it behaves under every condition.

## 1. Reference version

Installed path: `/System/Applications/Shortcuts.app`. Bundle identifier: `com.apple.shortcuts`. Marketing version: `10.0`. Build: `5037.0.19`. Host OS: macOS `27.0.1`, build `26A434`. These are measured from `sw_vers` and the installed `Info.plist`; they are the authority for this local study. Findings must not be silently generalized to earlier versions or to iPhone/iPad.

`evidence/installed-shortcuts-inventory.json` preserves the bundle metadata, executable SHA-256, link declarations, scripting dictionary, CLI help, and application resource inventory. It provides a reproducible reference for future comparisons.

## 2. Live interface findings

### Library

The sidebar exposes Gallery, Automation, All Shortcuts, Share Sheet, Quick Actions, and folders. The main library can switch between icon and list views. Toolbar controls include New Folder, Sidebar, New Shortcut, Share, Edit, and Search. The selected shortcut has a summary pane and a `Describe a change` input. A summary changed from a loading message to readable prose during observation; the generation mechanism and whether it used local or remote inference were not inspected.

Recreation implication: library organization, launch, editing, summary presentation, and natural-language modification are distinct interactions. Searching shortcuts and searching actions require separate scopes. Folder membership must not be confused with an invocation capability such as Share Sheet.

### Editor

Opening the existing empty shortcut produces a separate editor window. The main canvas is empty with the instruction `Add actions from the right to create a shortcut.` The toolbar has icon editing, an editable title, Share, Run, `Describe a shortcut`, and inspector switching between Action Library and Shortcut Details.

The action browser groups entries under All Actions, Automation, Scripting, Controls, Device, Location, Media, Sharing, Documents, and Web. It also exposes an Apps section. Observed list entries include Open App, Comment, Show Content, Show Alert, Ask for Input, Count, Choose from Menu, If, and Repeat. The accessibility tree initially showed an empty action table, then a populated table on reopening. Loading and populated states must both be represented; the initial empty table was not evidence that actions were unavailable.

Visual observation: a dark central canvas, a lighter right inspector, a vertical pane divider, rounded search/control surfaces, blue category icons, and a compact title/toolbar area. The screenshot supports relative layout and appearance; it does not establish exact CSS colors, font sizes, corner radii, or animation durations. Those require measured capture if pixel parity is chosen later.

### Details inspector

Three pages are present: Details, Storage, and Setup. Details exposes Show in Share Sheet, Show in Spotlight, Receive Input from Spotlight, Use as Quick Action, Finder, Services Menu, Provide Output, Add Keyboard Shortcut, and Allow Running When Locked.

For the observed empty shortcut, Spotlight and Allow Running When Locked were on; the other displayed switches were off. These are per-shortcut observed values, not proven defaults for every new shortcut. The relationship between the Quick Action parent switch and the Finder/Services options was not exercised.

Recreation implication: invocation routes, accepted input, returned output, and locked-device policy must be persisted as workflow settings rather than hidden inside an action chain.

### Storage inspector

The UI says: `Manage content stored in this shortcut. Use storage actions to access and change stored values.` It shows a value list, an Add New Value control, Remove Selected Value, and Edit. The empty reference shortcut has no values. This directly supports the existence of editor-managed stored values accessed through actions.

Unresolved: allowed types, scope outside this shortcut, synchronization, import/export behavior, reset semantics, concurrent writes, secret handling, and transactional guarantees. Persistent content must not be treated as equivalent to a temporary variable.

### Setup inspector

The UI explains that questions are asked when the shortcut is imported on a different device and that answers are filled into the shortcut. It exposes a question list, Add New Question, Remove Selected Question, and Edit.

Recreation implication: import configuration is a separate lifecycle from an Ask for Input action during execution. A future schema should represent an import question's destination parameter, prompt, and expected answer type. Exact Apple's mapping format remains unexamined.

## 3. Static application anatomy

The executable declares links to WorkflowEditor, WorkflowKit, WorkflowUI, WorkflowUICore, WorkflowUIServices, ActionKit, ActionKitUI, ContentKit, CardKit, VoiceShortcutClient, ShortcutsAgent, and other frameworks. It also declares public AppKit, SwiftUI, AppIntents, FoundationModels, and related framework dependencies. These are binary link declarations, not a runtime trace. A weak AppleInternal debug-menu reference is also present; it does not establish that the debug framework exists or loads.

The installed app includes ShortcutsWidgetExtension, ShortcutLiveActivityWidgetExtension, ShortcutsActionExtension, QuickLookExtension, and ThumbnailExtension. WorkflowKit's resource inventory additionally exposes helper XPC services and a ShortcutsIntents extension. This indicates a product distributed across an app and integration components; actual IPC protocols have not been recovered.

WorkflowKit contains a `Shortcuts.momd` resource with numbered model versions through v13. That supports the presence of versioned Core Data model artifacts. It does not establish the active persistence schema, database location, migration algorithm, or synchronization semantics.

The application declares URL schemes `shortcuts`, `shortcuts-production`, and `workflow`; these are declared routes, not a complete recovered URL grammar. It declares `.shortcut` as `com.apple.shortcut` and `.wflow` as `com.apple.shortcuts.workflow-file`; the latter conforms to `com.apple.property-list`. File contents, signed envelope details, and interchange compatibility remain unknown.

## 4. Action metadata and discovery

The app's `Metadata.appintents/extract.actionsdata` is JSON and contains 15 action entries, two entities, and three queries. Examples include CreateWorkflowAction, GenerateShortcutAction, ChangeShortcutIconAction, CreateFolderAction, GetShortcutAttributesAction, and MoveShortcutToFolderAction. These are metadata entries in this one file, not the full Shortcuts catalog.

The inspected ActionKit metadata file contains 19 action entries, eight entities, eight enums, and eight queries. Examples include GetMultitaskingModeAction, TimeMachineAction, TranscribeAudioAction, and several cellular-related actions. Inclusion in a shared metadata file does not prove macOS availability.

An inspected GetMultitaskingModeAction record contains title, description, search keywords, parameter summary, availability annotations, output type, discoverability, openAppWhenRun, supportedModes, authenticationPolicy, and requiredCapabilities. Numerical enums must be decoded against an authoritative contract before assigning them meanings. These records demonstrate that discovery and presentation depend on richer metadata than an action name plus a callback.

Derived evidence is saved in `evidence/shortcuts-app-metadata.json` and `evidence/actionkit-metadata.json`, each with its source path and content hash.

Proposed recreation contract: stable action identifier and version; localized presentation; typed parameters and outputs; execution handler; supported environments; permissions and capabilities; interaction/foreground needs; cancellation and error semantics. This is our proposed contract, not a recovered Apple internal interface.

## 5. External command contracts

The installed `shortcuts` command supports four subcommands:

| Command | Observed help contract | Meaning for recreation |
|---|---|---|
| `run` | Name or identifier; repeated input paths; output path; output type in UTI format | Execution accepts external input and may return typed output |
| `list` | Folder filter, folder listing, show identifiers | Stable identity is separate from display name |
| `view` | Shortcut name | Opening the editor is separate from running |
| `sign` | Input/output files; `anyone` or `people-who-know-me` mode | Sharing has a signed-file lifecycle that needs separate study |

The scripting dictionary exposes shortcuts and folders. Shortcut properties include name, subtitle, identifier, folder, color, icon, accepts input, and action count. Folder assignment is writable while several other shortcut properties are read-only in this scripting surface. The `run` command accepts arbitrary input and returns arbitrary output at the scripting contract level. Its description names Shortcuts Events for background execution.

No AppleScript command or workflow was executed. CLI exit behavior, error payloads, result conversion, multi-input ordering, and background execution guarantees remain unmeasured.

## 6. Documented content and execution concepts

Apple documents variables as containers for content such as text, images, webpages, and dictionaries. Its Content Graph documentation describes conversions between content representations. Consequently, recreation needs explicit value types, collection behavior, conversion rules, and property extraction. Passing an untyped string between every card would not reproduce this model.

The proposed execution model is: resolve invocation input; evaluate each action's parameter references; validate/coerce inputs using explicit rules; execute the action; retain its output for subsequent references; handle structured control flow; yield for user interaction where needed; report completion, cancellation, or failure. This is a working hypothesis to validate, not Apple's recovered algorithm.

Questions that require controlled runs: whether an action with no input consumes the previous output; whether lists are mapped item-by-item; behavior of empty or missing values; how branch results merge; order of repeat outputs; nested-loop scope; failed conversion behavior; and when stored values are committed.

Apple's current Mac guide also documents natural-language shortcut creation. The live `Describe a shortcut` and `Describe a change` controls make this relevant to the reference version. Whether we reproduce AI authoring is a later product decision; observing the control does not establish the model, prompt, or service contract.

## 7. Experiment matrix before choosing implementation

Use dedicated research fixtures with fixed synthetic values. Preserve existing user shortcuts. Record the fixture, app/OS version, input, invocation route, observed output, errors, and expected behavior. Do not run existing messaging, payment, file-deletion, or other consequential shortcuts as test fixtures.

| Fixture | Purpose | Evidence still required |
|---|---|---|
| Text to Show Content | Simplest sequential run | UI result, completion behavior, output |
| Two texts with explicit references | Distinguish prior output from selected output | Reference identity, rename/reorder effects |
| Text/number/list/dictionary conversions | Recover value rules | Scalar/list behavior and conversion failures |
| If with both branches | Recover condition and branch result semantics | True/false/empty inputs and output selection |
| Repeat and Repeat with Each | Recover loop scope/order | Repeat index/item references and aggregated result |
| Nested If/Repeat | Recover block structure | Insertion, movement, deletion and scope rules |
| Ask for Input then cancel | Recover interaction suspension | Cancellation propagation and returned state |
| Stored value write/read across runs | Recover persistence | Lifetime, update timing and export behavior |
| Import question bound to a parameter | Recover import lifecycle | Where answers are stored and type validation |
| Harmless deliberate failure | Recover error policy | Stops/continues, result and editor feedback |
| Same fixture from editor and CLI | Recover route differences | Input/output conversion and presentation |
| Signed export/reimport | Recover serialization boundaries | Stable IDs, parameters, storage, setup questions |

Full behavior parity cannot be claimed until these experiments establish a finite supported contract. Automation triggers require another matrix per platform; macOS observations cannot establish iPhone trigger behavior.

## 8. REA's role in the next investigation

`rea` was absent from the current command path. This pass used native UI observation, installed static resources, Apple's CLI help, and official documentation. It has not produced REA Evidence records.

For deeper analysis, first check the currently published REA version, actual tool schemas, and task-specific provider readiness. The repository documents different capability boundaries for its source branch and published packages. Inventory and bundle metadata are sufficient for anatomy; recovering selected native implementations requires a supported disassembler/decompiler and accessible target bytes. Framework code may reside in the dyld shared cache rather than as a conventional loose executable file; availability must be inspected before promising decompilation.

A useful REA question would be bounded: trace the serialization or execution path for one synthetic action sequence, preserve the artifact identity and function evidence, then compare the static explanation with an observed run. Whole-app recovery is not a single supported operation.

## 9. Design decisions to defer

Choose implementation platform after the content/flow experiments. Decide whether the goal is visual parity, semantic parity for a finite action subset, or broader system integration. Decide the initial action catalog, storage/sync model, imported-file compatibility, AI authoring scope, and plugin contracts from the measured behavior. Android translation follows that specification.

Recommended first completed behavior slice: text, number, list, dictionary, explicit output references, If, Repeat, user prompt, output display, and persistent value. The recommendation is a proposed research/implementation boundary, not an assertion of existing implementation.

## Sources

Local evidence: installed app bundle and the two framework/app metadata files described above; native accessibility observations of Library, Editor, Details, Storage, and Setup on the reference version.

- [Apple Mac Shortcuts guide](https://support.apple.com/guide/shortcuts-mac/welcome/mac)
- [Apple: Variables](https://support.apple.com/guide/shortcuts-mac/intro-to-variables-apdb5506f698/mac)
- [Apple: Content Graph](https://support.apple.com/en-gb/guide/shortcuts-mac/apd4618db957/mac)
- [Apple: Adjust variables](https://support.apple.com/en-gb/guide/shortcuts-mac/apda36b9018b/mac)
- [Apple: Create a shortcut](https://support.apple.com/en-ge/guide/shortcuts-mac/apd84c576f8c/mac)
- [REA Apple inventory guide](https://github.com/morluto/rea/blob/main/docs/apple-application-analysis.md)
- [REA installation and release boundaries](https://github.com/morluto/rea/blob/main/docs/installation.md)

Next required evidence: controlled synthetic execution traces and exported fixture files. This initial dossier establishes the installed reference and observed authoring surfaces; execution, exact file grammar, private IPC, and complete action availability remain unresolved.
