# Privacy, security and permissions

## What is local

Studio's library, workflows, stored values and bounded run history live in `~/Library/Application Support/ShortcutStudio`. Session input is held in memory per workflow. The app has no Studio account, analytics uploader, cloud sync, Android listener or telemetry endpoint. Use On-Device Model explicitly selects Apple's system on-device model and does not configure a cloud fallback.

Local workflow/history files are plaintext JSON. Stored values can contain personal or confidential content. The app does not encrypt them with an app-managed key. OS user-account/disk protections and sharing practices matter. The library backup and preserved corrupt snapshots may retain earlier content.

## What can leave the device

A user-authored HTTP action transmits its configured URL/headers/body to the chosen server. Open URL hands a URL to the selected/default app; that app can contact its own services. Notifications, speech, clipboard and file actions interact with system services or accessible local resources. Delegated Apple shortcuts can perform whatever their authored actions and permissions permit. “Local app” does not mean all workflows are offline or that third-party destinations are private.

The bundled privacy manifest declares no developer tracking or developer collection for the present implementation. It does not promise that workflow destinations, browsers, Apple's platform services or future features perform no data processing. Reevaluate the declaration whenever a collector, SDK, cloud service, required-reason API or remote transport is introduced.

## Current permission behavior

- Notification permission is requested when Show Notification is invoked. Denial fails the action.
- Local-network purpose text explains authored workflow requests to user-chosen local services. No Bonjour discovery or remote service is enabled.
- File panels are native; direct path read is currently available to the nonsandboxed local app within the user's OS permissions. There are no security-scoped bookmarks or sandbox grant store yet.
- Open App/URL resolves installed handlers through NSWorkspace; it does not gain Accessibility control of other apps.
- Apple's Shortcuts engine owns its own permission prompts and action execution.
- Foundation Models availability is checked; the app does not turn Apple Intelligence on or change system settings.

Usage-description strings explain access. They do not grant it or replace TCC/user authorization. The app does not require Full Disk Access or Accessibility permission for its normal authoring/open-app/URL path.

## Imported and generated workflows

Import validates file/version/size/structure/identities/setup questions. Runtime resolves values and enforces budgets. A structurally valid workflow can still send data, read accessible files, save output or invoke an existing Apple workflow when the user runs it. Inspect parameter values and destinations before running someone else's workflow.

Model generation is untrusted authoring data. The app constrains schemas, validates references, and requires review/acceptance. It never automatically runs a generated draft or registers model-generated code. The model has no direct tools in its session. Correct structure is not semantic correctness or a permission decision.

## Process and resource limits

The Apple CLI bridge uses separate arguments, temporary UTF-8 input/output and bounded capture. There is no shell-command action. Process output file sizes are checked after exit; a malicious/noisy child can use disk before that check. Process cancellation terminates and later may kill the CLI child, but cannot reverse external effects or guarantee stopping Apple's engine. Regex is synchronous on MainActor and is not separately isolated. These are explicit hardening opportunities, not hidden guarantees.

## Managing your data

Export includes stored values and setup questions. Run history may include user input, model output and server responses. Redact these before sharing a fixture, screenshot or bug report. Source/download packaging uses only the project directory and synthetic verification data, never your application-support library or Keychain.

Back up before troubleshooting. Quit Studio before manual library-folder edits. To remove all local Studio library/history/recovery files, the owner can remove the entire Studio application-support folder after quitting, including backups and preserved corrupt snapshots; the next launch creates starter workflows. This is destructive and the app does not currently offer a dedicated permanent data-purge UI. Deleting a workflow into Trash is recoverable and is not a permanent privacy erasure.

## Future Android boundary

Pairing must be explicit and revocable. Grant workflow-specific authority, not a generic execution endpoint. Store credentials in platform secret stores; require authenticated encrypted transport, ownership-filtered results, request journaling and no silent replay. No transport or pairing implementation exists today. [Proposed protocol](REMOTE_PROTOCOL_PROPOSAL.md) defines the work to do before accepting phone commands.

## Verification limits

Tests cover named corruption, budget, reference, cancellation, schedule and model fixtures. They do not constitute a penetration test, privacy certification, exhaustive fuzzing, App Review or sandbox qualification. A public release needs its selected channel's signing/privacy/permissions review and real-machine verification. [Apple standards audit](APPLE_STANDARDS_AUDIT.md) records those gates.

## 0.2.0 messenger privacy boundary

When explicitly connected, Studio sends approved workflow metadata, presence, paired identity metadata and encrypted run payloads to the configured gateway. The temporary phone test uses Cloudflare Tunnel and browser Web Push; those providers process delivery metadata. Gateway routing credentials, ciphertext and VAPID material remain in the private runtime directory, excluded from archives. Mac device/relay secrets use Keychain; browser credentials and a nonextractable AES key use IndexedDB. The gateway-served web code is a trust boundary; encryption does not protect against maliciously replaced browser code. No model runs on the relay. See [Messenger guide](MESSENGER_GUIDE.md).

The prior no-cloud/no-account statements apply to local workflows with the messenger disconnected. The optional relay changes the data flow. The current ad hoc local build is not an App Store submission; its privacy manifest does not replace disclosure of optional service processing or accurate future App Store privacy answers.

## Optional app-control and Desktop scope, 0.3.0

An approved Phone Assistant/Desktop action can send Desktop filenames to the paired phone. An approved app-control target can read bounded accessible text from its active window and enter/submit the requested text. The app uses public Accessibility APIs and macOS permission; the owner chooses approved bundle IDs. Browser inspection targets the active web document instead of other tab/address-bar text. App UI content can be private; review the workflow and targets before granting it to a phone. Prompt submission to ChatGPT or another app may send text to that app's external service under its existing login. The gateway still performs no inference. App UI control is explicitly separate from a direct OpenAI API integration.
