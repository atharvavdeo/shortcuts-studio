# Verification record

Date: 2026-10-13. Host: this local Mac, macOS 27, Swift 6.4 Command Line Tools. This record covers a local development build, not full Apple Shortcuts parity or release qualification.

## Automated checks

`bash scripts/test.sh` passed 34 tests across six Swift Testing suites. Coverage includes typed references, nested branching/loops and scope, missing/stale output rejection, numeric errors, budgets, cancellation, storage failure, recursive calls, block edits/remapping, persistence corruption/backup, import validation, daily and weekday scheduling, schedule persistence, multiline/empty input semantics, and model draft validation. These tests do not execute macOS permission prompts, every platform action, or actual model inference.

The CLT installation needs explicit registration of its bundled Testing macro plugin; the script handles this. Linker warnings about absent CLT developer framework search paths remain; build completion is recorded separately.

## Observed native app checks

- List Playground: native result sheet displayed `1. One`, `2. Two`, `3. Three`; Continue completed the run. An initial missing-main-window failure was repaired by resolving the active sheet parent.
- Persistent Counter: output 1, persisted storage shown, quit/relaunch, output 2.
- Ask for Input cancellation: Cancel stopped the workflow before later actions.
- JSON Explorer export/import: saved `.studio` file, decoded its format/version/actions, reimported with new identity, ran imported workflow to output `World`.
- Apple bridge: created the isolated Apple shortcut `Studio Bridge Check — text only`, containing one Text action; discovery, Add to Studio, and Run completed with exact Unicode output `Studio bridge verified — UTF-8 ✓`. Existing user workflows were not run. The clearly named fixture remains in Apple's library and Studio for review.

## Foundation Models

`verification/model-probe.swift` explicitly selects `SystemLanguageModel.default`, starts a session without tools, and streams a synthetic arithmetic prompt. Current output in `verification/model-probe.txt`: availability available, eight snapshots, response `2 plus 3 equals 5.` This proves a live on-device Foundation Models call on this host. It does not prove general reasoning accuracy, measured latency, NPU utilization, NPU-only execution, model size, or operation on other hardware.

The app's Use On-Device Model action was run in the native UI and returned `2 plus 3 equals 5.` The reproducible `bash scripts/validate-model.sh` harness compiles the actual core and model service, performs live inference, rejects an empty prompt, generates and executes two drafts, and checks cancellation both before generation and after streaming starts. The latest record is `verification/model-validation.txt` and ends with `VALIDATION PASS`.

The two generated workflow fixtures were checked against explicit action sets and exact expected outputs: Text → Show returns `Hello from the on-device draft`; Split → Unique → Combine → Show returns `One\nTwo` from repeated input lines. The first draft was also generated, reviewed, added, and run through the native app to the exact result dialog and completed status. This is scoped success on two fixtures, not accuracy evidence for arbitrary natural-language requests.

Initial generation attempts invented references, shortened a requested literal, or reused original input instead of the preceding output. Those failures led to strict reference validation and two-pass generation: select an action plan, then fill schemas derived from each selected action. Generated input parameters now follow a pipeline; more complex bindings remain manually editable. The final draft-preview area was visually inspected and repaired after its original flexible height collapsed in a native sheet.

## UI and automation checks added in this pass

- All six automation presets are present: Time of Day, App Activates, App Quits, Mac Wakes, Mac Sleeps, and Clipboard Changes. A preset-sheet state bug was repaired by giving configuration its own view/state.
- A real Calculator quit event claimed the enabled test rule and ran Text Input · Validation to a completed history record. Both temporary verification automation rules were explicitly observed disabled afterward. Calculator was reopened with its previous display intact.
- Native multiline input preserved line breaks and Unicode. Command-R used the same configured input as Run. The running Wait action's highlight/spinner and prior action's completion checkmark were visually observed; switching to another workflow showed its own input setting and Ready state.
- `bash scripts/validate-store.sh` passed seven checks using the actual app store and isolated temporary storage: prepared input reaches the runtime, input isolation/restoration, empty Text semantics, edit preservation of automation identity/disabled state, reload persistence, and invalid schedule rejection without publishing the candidate. Results are in `verification/store-validation.txt`.
- Animation code respects Reduce Motion. Visual review covers this host's current appearance and window size; no claim is made for exhaustive VoiceOver or every display configuration.

## Real application workflows

- Google Search in Chrome: imported the supplied `.studio` fixture and ran Open App → URL → Open URL. Studio recorded completed execution. Chrome's actual address bar showed the requested Google search and its results page rendered.
- Framer to Subframe: imported the `.studio` fixture and ran URL → Open URL in Chrome → Open App. Studio recorded completed execution and Subframe's native window was observed. The user separately confirmed the Framer sequence works. The agent did not independently retain a rendered Framer page observation; subsequent Chrome reads showed the user's other active tab.
- These are explicit workflows. Manual website visits are not monitored. No arbitrary existing user workflow was executed.

## Build evidence

The release build script completed, packaged the native `.app`, applied an ad hoc signature, and passed strict signature verification. `verification/build-manifest.json` records hashes for the current source, validation files, and packaged executable. The build is local and is not Developer ID signed or notarized.

## Remaining checks and limits

No claim is made for full catalog parity, signed Apple file interchange, iCloud, Siri, widgets/extensions, unattended background automation, Android, every permission-denied path, exhaustive malformed imports, or end-to-end Pages/Keynote/Numbers/Image Playground integration. Those applications' research dossiers are separate from this implementation. Cloud model routing is not implemented. Hardware execution was not profiled.

## 0.1.1 standards and handbook pass

Adds keyboard-accessible library buttons, named toolbar controls, system accent, opaque tile colors, a compact editor layout, original connected-node icon, About version metadata, workflow UTI, privacy declaration, buffered cold file-open handling and bundled offline Help. Distribution checks cover generated reference freshness, handbook links/assets, metadata, signature/runtime flags, source/binary provenance and archive checksums. These checks do not establish full HIG compliance or exhaustive accessibility.

Developer ID/notarization, clean-machine Gatekeeper, formal VoiceOver and full appearance/display acceptance remain outstanding. The Android internet messenger gateway is a documented proposal; no relay/phone implementation or notification delivery has been tested. AI is optional within approved Mac workflows.

Current pass results: `verification/core-validation.txt` records 34/34 passing tests in six suites; the isolated store harness again passes seven checks. Debug and release compilation pass. The packaged app's accessibility tree shows library cards as named Buttons with Selected state and toolbar/action controls with their new labels; the Help menu exposes Shortcut Studio Handbook. The browser tool rejected file-URL inspection, so rendered offline handbook visual acceptance is still pending. Internal HTML links and bundled bytes are checked mechanically. Live model validation records are retained from the earlier pass; model generation was not rerun after the owner's gateway clarification.

## 0.2.0 messenger implementation — 14 October 2026

- Ten relay tests pass: authentication roles, single-use pending pairing, offline rejection, duplicate/conflicting IDs and busy rejection, run ownership, expiry, terminal-state monotonicity, revocation, push endpoint restrictions, and malformed/oversized commands. `verification/gateway-validation.txt`.
- `scripts/validate-messenger.sh` passes using the actual Swift connector/store/engine, temporary library, in-memory test credential vault and a separate loopback relay. It verifies Web Crypto/CryptoKit ECDH/HKDF/AES-GCM interoperability, exact multiline Unicode round trip, dialog-free Show, one echo execution under identical delivery, revision/schema/ciphertext/size rejection, restart→Interrupted handling and cooperative cancellation before a later action. `verification/messenger-validation.txt`.
- The public HTTPS test link responds to health checks; native Mac UI shows paired phone entries and approved example grants. The live Mac journal contains two Completed remote records. This does not establish which physical device performed those commands or confirm phone notification delivery.
- Mobile companion pairing UI visually inspected at 390×844; desktop layout also inspected. The paired inbox/notification behavior still needs actual Android acceptance. No native APK is built.
- Browser notifications are implemented through Web Push/VAPID, generic result hints and authenticated lookup. Actual Android background/lock-screen delivery is not yet confirmed. The temporary relay runs on this Mac through a Quick Tunnel, not an independently available hosted cloud service.
- Payload encryption does not remove the trust in gateway-served browser code; formal security assessment, permanent hosting, credential recovery/rotation and operational retention remain release gates. No cloud inference endpoint is added.

## 0.3.0 assistant and app-control pass

User confirmed Echo returns the phone message. Initial notification inspection found no registered subscription; after enabling, the OnePlus subscription was present. A high-priority test push received HTTP 201 and the user confirmed “Yes, the notification appeared.” That is a user-confirmed test notification, not a delivery reliability benchmark.

`verification/assistant-validation.txt` passes fixture Desktop filename-only listing, explicit Desktop/app intent routing, approved ChatGPT target resolution, unapproved target rejection, actual Apple model knowledge-question routing, arithmetic answer and streaming snapshots. The model reported available. It does not prove general intent accuracy or app UI compatibility. New catalog actions: Phone Assistant, Get Desktop File Names, Control Application (67 definitions total). App Accessibility/actual ChatGPT submission and reply extraction remain pending native permission and live application acceptance.

Native assistant UI shows Apple on-device model available and the newly approved Assistant/Desktop workflows. The host's privacy UI labels the AX permission Device Control and Data Access. Files & Folders/assistive Accessibility settings are separate. App control is not marked verified until the app reports trusted and a live app prompt round trip is observed.

## 0.4.0 password/window/phone UI repairs

- Connector stores session keys in memory and uses them for command decryption and output encryption. The isolated messenger integration explicitly counts credential reads and passes “commands and streams use session keys without repeated credential reads.” Initial session unlock remains a real Keychain operation. Revoked relay devices are reconciled and removed locally.
- Messenger becomes a dedicated SwiftUI Window, independent from the authoring window. The setup view includes model readiness, app-control status and user-triggered Desktop access check/privacy settings.
- Phone browser now mirrors the Swift app's palette, shortcut tiles, sidebar, per-workflow text draft, approved action-title preview and output/result/log structure. Full remote authoring is not added.
- Cloudflare automatic deployment is an architectural plan, not a completed hosted framework. The public template, Worker/Durable Object adapter, OAuth deployment transaction and stable signing/distribution remain outstanding.

### Running-process packaging fault

Scoped macOS ShortcutStudio crash reports showed SIGKILL (Code Signature Invalid), CODESIGNING / Invalid Page during local rebuilds. The former packager copied the new executable into the live app path. Packaging now builds/signs a separate `.build/app-stage.*` bundle, moves the previous app into the excluded stage directory, then installs the new bundle. It does not mutate the running executable inode. A live process/heartbeat check is required before marking this repair verified. No crash report contents, private credentials or runtime state are included in the source archive.

Live staged packaging validation passed: the original running process remained alive through the build/install, heartbeat age was below one second and the relay reported Ready. `verification/packaging-process-validation.json`. This establishes the named live update case on this host; ad hoc trust across arbitrary updates is not a public release guarantee.
