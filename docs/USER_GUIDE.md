# User guide

## 1. Install and start

Unzip `dist/Shortcut-Studio-macOS.zip`, then open **Shortcut Studio.app**. You can place it in Applications. The local build is signed ad hoc; it is not a notarized public download. Do not disable Gatekeeper to install a future public release; use a properly signed/notarized package or build from a source checkout you trust. The app targets macOS 14+, but current live checks cover this Mac on macOS 27.0.1. On-device model features require macOS 26+ and available Apple Intelligence.

The app needs no Studio account. Normal workflow actions do not require Apple Intelligence. macOS permissions and installed applications still determine whether a particular action can work.

## 2. Understand the workspace

- **All Shortcuts:** your live workflows; select a card or switch to list display.
- **Favorites / Folders:** organize the same workflows; these are not separate copies.
- **Gallery:** local starter workflows. Add makes a new editable copy.
- **Automation:** event and schedule rules that run existing workflows while Studio is open.
- **Apple Shortcuts:** discover Apple's installed library and add a bridge workflow.
- **Run History:** the latest 100 completed, failed, or cancelled runs.
- **Trash:** recoverable removed workflows. A deleted workflow cannot run.
- **Editor:** ordered actions and input; the right inspector has Actions, Details, Storage, and Setup.

Library changes autosave to your own Studio library. The app does not edit Apple's Shortcuts database.

## 3. Build your first workflow

1. Choose **File → New Shortcut** or the toolbar plus button.
2. Give it a recognizable name.
3. Search **Text** in the action browser and add it.
4. Enter `Hello, world!` in the Text action.
5. Add **Show Result**. Keep Input as `{{previous}}`.
6. Run. A native result sheet displays your text. Continue finishes; Stop cancels the run.

The previous action's output becomes the next action's normal input. The reference picker inserts named variables, shortcut input, loop item/index, or a particular earlier action's identity.

## 4. Supply text input

Turn on **Text Input** above the action list, enter one or more lines, and add **Shortcut Input** if you want to start by returning that input. Empty input with the switch on is empty Text; switch off is Nothing. Input is retained independently per workflow for this app session, not saved to the library.

The editor Run button and Command-R use this configured input. An automation runs without editor input. A context-menu run of a workflow also uses the runtime's default input; use the editor when supplying text deliberately.

## 5. Edit actions and control flow

Use the action's options menu to move, duplicate, insert, disable, or remove it. Dragging is an additional way to move an action. Inserting If or Repeat also inserts its closing markers. Moving or duplicating an opening block operates on the whole block; references within duplicates are remapped. Standalone Otherwise/End markers are protected from edits that break structure.

The editor shows structural errors before execution. Runtime errors identify the failing action. A disabled ordinary action is skipped; control-flow markers cannot be disabled. Undo/redo covers authoring; starting a run clears authoring undo so committed runtime writes cannot be undone accidentally.

## 6. Use logic, lists, dictionaries, and stored values

- **If:** conditions include has value, equality/inequality, contains, numeric greater/less, and is true. Studio equality compares text forms.
- **Repeat:** a bounded count; **Repeat with Each:** a typed list. Inside a loop use `{{repeatItem}}` and `{{repeatIndex}}`. Loop outputs form a list.
- **Dictionary / Parse JSON:** construct typed nested values. Get Dictionary Value follows dot-separated keys. Set Dictionary Value changes a top-level key in a copy.
- **Set Variable / Get Variable:** values last for the current run.
- **Stored Value:** values belong to the current workflow and survive restarts. A successful Set/Remove writes immediately. Later cancellation does not undo that write.

[Action reference](ACTION_REFERENCE.md) lists every parameter and default. Some display conversions are specific to Studio and are not proven equivalents to Apple's Content Graph.

## 7. Run, stop, and inspect

Run displays the active action, a spinner, completed checkmarks, typed output, and logs. The output area shows only the selected workflow's current/last session run. Stop requests cooperative cancellation; it can stop waits, streamed responses, dialogs, and the CLI process. It cannot undo a launched app, a request already sent, a file already written, or an Apple action already committed.

Bounds protect the local runtime: 10,000 executed steps, 1,000 repeat iterations/items, 32 authored block levels, 16 nested calls without recursion, Wait up to 300 seconds, HTTP response/read text up to 10 MB, import up to 20 MB and 5,000 actions. Visible output is capped at 20,000 characters; history output at 4,000. Regex has no separate execution isolation; pathological regex can block the app.

## 8. Real app/browser workflows

**Google Search in Chrome** is an importable example in `verification/Google Search in Chrome.studio`. It opens `com.google.Chrome`, creates a Google search URL, and opens it explicitly in Chrome. Change the search URL in the editor to customize the query.

**Framer to Subframe** opens `https://framer.com/` in Chrome, then opens `com.subframe.desktop`. The installed apps must resolve from those bundle identifiers. This sequence runs when you select Run. Manual browser visits are not automatically monitored.

Open URL's optional application bundle ID selects an installed browser/app. Leave it empty for the system's registered handler. Open URL accepts HTTP, HTTPS, and mailto; URL construction accepts HTTP/HTTPS. HTTPS is recommended for network requests; the app does not add a global ATS exemption.

## 9. Configure automations

Select a preset, choose a workflow, and Create. Creation enables the rule. Time of Day can repeat daily or on selected weekdays. App rules use bundle identifiers, not window titles or website addresses. Edit preserves the rule's identity and enabled state; changing its trigger/workflow clears its previous claim. Test Run runs immediately without claiming the scheduled trigger.

| Trigger | Behavior |
|---|---|
| Time of Day | Polls every 15 seconds; only the 60-second scheduled window; no missed-day replay or late-startup catch-up |
| App Activates | Fires when the target app becomes active, not on each new browser tab |
| App Quits | Fires on a target app termination notification |
| Mac Wakes | Fires on a workspace wake notification |
| Mac Sleeps | Starts on will-sleep; macOS can suspend the app before it finishes |
| Clipboard Changes | Detects pasteboard change count; Studio's own Copy suppresses self-triggering |

One workflow runs at a time. Busy triggers are skipped; there is no queue. Event rules have a 10-second cooldown; the first eligible event rule wins. A schedule claim is saved before execution. Keep Studio open. No launch agent, unattended service, login item, or remote listener is installed.

## 10. Use Apple Shortcuts

Open Apple Shortcuts in the sidebar, refresh, and select Add to Studio. Run Apple Shortcut delegates by name or UUID; UUID avoids ambiguity if names collide. Open in Apple Shortcuts opens Apple's editor. Studio sends text as a temporary UTF-8 input file and receives text or a Base64 dictionary for binary output.

The bridge has a 120-second timeout and argument-safe process invocation. Stop can terminate the command; it cannot guarantee cancellation of Apple's independent engine. Native `.shortcut`/`.wflow` imports open in Apple's app. Studio exports its own `.studio` JSON format, not Apple's signed format. Apple's permissions remain Apple's responsibility. [Apple's CLI guide](https://support.apple.com/guide/shortcuts-mac/apd455c82f02/mac) documents the supported interface.

## 11. Use on-device intelligence

**Use On-Device Model:** enter a prompt and instructions. Each action starts a fresh session. Reference earlier input explicitly; no conversation is retained between actions. Cumulative text snapshots replace the visible response. The final Text is passed onward. Inputs are bounded to 6,000 characters including instructions and responses to 1,024 tokens, subject to framework limits. Model errors fail the action; no cloud retry is configured.

**Describe a Shortcut:** use the toolbar or File menu. Enter what the workflow should do, optionally use an example, then Generate Draft. The model first plans action kinds, then fills constrained parameter schemas. The app validates the result. Review the action preview, choose Add to Library, inspect the editor, and Run yourself. Drafts have at most 20 actions and a 1,500-character description. The standard generated pipeline uses original input at the first step and preceding output afterward. Manually edit richer bindings as needed.

Availability messages distinguish ineligible hardware, Apple Intelligence disabled, and model not ready. Apple selects the system model and its hardware execution. This app cannot promise NPU-only execution or correct reasoning for arbitrary prompts.

## 12. Share, back up, and recover

Export saves a `.studio` document. Stored values and import questions are included; inspect them before sharing. Import validates version, size, IDs, questions, and blocks, asks setup questions, and assigns new identities. Workflows with HTTP/file/Apple bridge actions can have external effects when run.

The library is at `~/Library/Application Support/ShortcutStudio/library.json`. The last valid save is backed up to `library.json.backup`. If loading fails, the app preserves bytes and blocks editing/running. Restore Backup preserves the corrupt file under a unique name, then restores the valid backup. Close the app before manually copying or restoring its library folder. Copy the whole folder to preserve recovery evidence.

## 13. Keyboard and help

| Command | Shortcut |
|---|---|
| New workflow | Command-N |
| Import | Command-O |
| Export | Shift-Command-E |
| Run configured input | Command-R |
| Stop | Command-Period |
| Duplicate | Command-D |
| Undo / Redo | Command-Z / Shift-Command-Z |
| Quit | Command-Q |

Use the Help menu for this offline handbook. Library cards are buttons so keyboard/assistive input can activate them. Move actions with options menus as an alternative to dragging. Appearance uses native controls and semantic surfaces; custom tile surfaces are opaque and contrast-checked. Motion respects Reduce Motion. Full VoiceOver/Switch Control/alternate-input coverage remains a release verification item.

## 14. Troubleshooting

| Symptom | Check / recovery |
|---|---|
| Model unavailable | Read the availability message; Apple Intelligence eligibility/readiness is required |
| Browser/app not found | Verify the bundle ID and installation; leave Open URL's bundle field empty for the default handler |
| Apple shortcut fails | Run it in Apple's app to resolve its own permissions; confirm its UUID; consider prompt-free workflows |
| HTTP fails | URL, method, response status, ATS/HTTPS, connectivity, and local-network permission |
| Automation did not fire | Enabled state, target ID, selected day, open app, busy run, cooldown, missed window |
| File read fails | Accessible path, UTF-8 encoding, and 10 MB limit; selection panels can help choose the exact file |
| Library/save failure | Preserve the library; use the error banner and backup; do not repeatedly overwrite corrupt evidence |
| App shows old output | Output is session-scoped to the last selected workflow run; run again if you need current evidence |

If reporting a bug, provide app version, macOS version, minimal synthetic `.studio` fixture, expected/actual output, and relevant redacted logs. Do not include personal history, stored secrets, model prompts, or file paths unnecessarily.
