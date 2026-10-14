# Phone Messenger: setup, use and implementation

**Version 0.3.0 · implemented browser companion and test gateway.** A native Android APK and permanent cloud deployment are not included. The first phone test uses Chrome on Android and a temporary HTTPS link. The owner selected an internet-reachable gateway and approved Mac workflows, with AI only when the selected workflow needs it.

## Test with your Android phone

1. Keep the Mac awake with Shortcut Studio open. Open **Messenger → Phone Messenger**.
2. Connect to the configured gateway. Choose **Add Phone Examples**, then check the workflows to approve. Review the actions before sharing a workflow.
3. Choose **Create Pairing Code**. Open the shown HTTPS URL in Android Chrome and enter the six-digit code.
4. Compare the phone's fingerprint with the Mac's pending request, then choose **Approve Phone**. Code is single use and expires after five minutes. Both the Mac and gateway must be reachable.
5. Choose **Phone · Echo**, type a short message and **Send to Mac**. The result should read `Received from your phone: …`.
6. Choose **Phone · Google in Chrome**, type a query and Send. Chrome opens the encoded Google query on the Mac; the phone gets a completion result. A launch callback does not verify that remote web content loaded.
7. **Phone · Framer to Subframe** opens Framer in Chrome and launches Subframe on the Mac. **Phone · On-Device Answer** explicitly calls the Mac model. It requires ready Apple Intelligence on a supported Mac. Other examples do not call AI.
8. Tap **Enable notifications** on the phone. Allow the browser notification prompt if wanted. Results remain in the inbox when permission is denied.
9. Use Stop for an active run. Stop is cooperative and cannot undo completed browser or other side effects. Revoke devices or Disconnect on the Mac when finished.

The phone web app can be added to the Android home screen through Chrome's install/add menu. Actual install and background notification behavior depend on the Chrome/Android version and phone settings; verify on the phone before claiming support.

## Start a new test session from source

Prerequisites: Node.js supporting built-in fetch/node:test, npm, Python 3, a built Mac app, and an official `cloudflared` binary. Install gateway dependencies using the lock file:

```sh
npm ci --prefix gateway --ignore-scripts
STUDIO_CLOUDFLARED=/absolute/path/to/cloudflared bash scripts/start-messenger.sh
```

Run from the source root. The startup script creates a loopback gateway at `127.0.0.1:8787`, starts a Quick Tunnel, and writes a one-time bootstrap file in the app's Application Support directory. Restart Studio to import it. The Mac credential is saved in Keychain, and the bootstrap file is removed. The script does not automatically enable the connector, approve a phone or share a workflow.

Stop the script with Control-C to stop its gateway/tunnel. If those were launched separately, stop their exact process/session instead. No login item or persistent daemon is installed. A Quick Tunnel hostname changes at restart and has no uptime guarantee. [Cloudflare Quick Tunnels](https://developers.cloudflare.com/tunnel/get-started/quick-tunnels/).

The relay can run on another host behind HTTPS: `gateway/server.mjs` is separate from the app and receives the Mac's outbound polling connection. Configure that stable origin and its independently generated Mac credential in the Mac connection form. The included test has the relay running on this Mac through the tunnel; it is not an independently available cloud deployment. Secure deployment, identity/account recovery, retention operations and provider setup require a separate release pass.

## Implemented contract

- Public static mobile interface; private operations require separate Mac and phone bearer credentials. No CORS policy permitting other sites; browser mutations check the exact origin.
- One-time code → pending phone identity → visible Mac approval. P-256 ECDH derives a device key using HKDF-SHA256, salt `studio.messenger/1` and device ID as context.
- AES-256-GCM command and result payloads. Swift CryptoKit and browser Web Crypto use the same raw public key, nonce/tag format and authenticated context. AAD is `command|deviceID|runID` or `result|deviceID|runID`.
- Mac credentials/device keys in Keychain; browser device credential and nonextractable AES key in IndexedDB. Relay retains bearer routing credentials and ciphertext, not the derived AES key.
- All paired phones share the same owner-approved workflow list in this single-owner version; separate grants per phone remain future work. Mac-side grants bind workflow ID to SHA-256 of JSONEncoder sorted-key action configuration. Editing actions invalidates sharing. Only a bounded action allowlist is shareable. File/clipboard/storage/network-fetch/Apple-delegation/nested-workflow and interactive input actions are excluded. Show Result returns its value to the phone.
- Text input ≤16 KiB UTF-8; decrypted schema ≤32 KiB; relay body ≤64 KiB; capped ciphertext/events/results (phone result text is capped at 12 KiB and marked when shortened); shared workflows ≤50, paired relay devices ≤20; ≤1000 journal entries per session. A full session rejects new commands; it does not erase idempotency records automatically.
- Mac journal acceptance is atomically saved before engine execution. Identical command ID/digest is never re-executed; conflicting bodies are rejected. Accepted/running journal records recover as Interrupted after app restart. Unknown already-accepted relay commands are not executed from scratch.
- New commands require a recent Mac heartbeat. Sent commands expire after 60 seconds before acceptance. There is no offline execution queue. One active run; busy requests rejected.
- Mac uploads only changed, bounded run snapshots. Phone receives state and cumulative encrypted text, replaces snapshots, and retrieves its own results. It cannot read the Mac's full history/library.
- Permission failures become run failures; remote errors are sanitized. Phone notification taps and Refresh perform read-only run lookup, never execute a workflow.

This is protection against accidental disclosure and unauthorized command submission under the paired, trusted-client/server design. The browser code is served by the relay: a malicious relay/web origin can replace that code at load time. Payload encryption does not eliminate that web distribution trust, conceal routing metadata or make this a reviewed secure-messaging protocol. Independent trusted client distribution and a formal security review remain release work.

## Notifications

The service worker subscribes with Web Push/VAPID using `web-push`. Push carries only the run ID and displays a generic result-ready notification under a stable tag. The authenticated app fetches and decrypts content when opened. The gateway restricts push destinations to supported browser push service hostnames to prevent arbitrary server-side fetches.

Notification denial, Doze, force-stop, network loss, browser/device configuration and push-provider delivery can delay/prevent alerts. Inbox recovery remains available when the gateway is online. Push is not a run acknowledgment. Sensitive result text is not put in push or lock-screen notification content. [Web Push implementation](https://github.com/web-push-libs/web-push), [service-worker notifications](https://developer.mozilla.org/en-US/docs/Web/API/ServiceWorkerRegistration/showNotification).

## Files and operation

- `Sources/ShortcutStudio/MessengerConnector.swift`: connection, grants, CryptoKit, Keychain, journal and engine handoff.
- `MessengerView.swift`: native connection/pairing/grant/revocation controls.
- `gateway/server.mjs`: bounded authenticated messenger, presence, delivery state and push dispatch.
- `gateway/public/`: responsive UI, Web Crypto, IndexedDB, service worker and manifest.
- `.gateway-runtime/`: private runtime Mac token, relay state, VAPID keys and test tunnel logs; excluded from downloads/source ZIP.
- `~/Library/Application Support/ShortcutStudio/messenger.json`: grant/device identifiers and encrypted run journal, permission 0600. Workflow/history storage is still plaintext locally, as documented in the privacy chapter.

The current gateway is a single-owner/single-Mac process. It has no multi-tenant account service, production metrics/backups, automatic retention cleanup, credential recovery/rotation UI, native APK, or permanent cloud deployment. Paired phone sessions do not expire automatically; revoke them explicitly. Stop the temporary server/tunnel when the test is finished.

## Validation

```sh
node --test gateway/test/*.test.mjs
bash scripts/test.sh
bash scripts/validate-store.sh
```

Relay tests cover authentication, single-use pending pairing, offline/busy behavior, duplicate/conflicting requests, ownership, expiry, terminal-state monotonicity, revocation, push destination restrictions and malformed/oversized commands. Separate live browser/Mac and actual Android checks are recorded in [verification](../VERIFICATION.md). Passing relay tests alone does not prove CryptoKit/browser interoperability or actual background phone delivery.

## Command assistant and actual Mac apps, 0.3.0

Select **Phone · Assistant** in the phone workflow picker. On the Mac, Add Phone Examples creates this workflow; review it and approve its checkbox. Examples:

- `What is two plus two?` — Apple on-device model answer, streamed back through the gateway.
- `What is on my Desktop?` — visible filenames only, up to 200 entries; macOS Desktop access may be requested.
- `Search Google for Swift Foundation Models` — opens Chrome on the Mac.
- `Open Calculator` — opens an approved installed app.
- `In ChatGPT: explain gravity in one sentence` — enters/submits the prompt in the actual native ChatGPT Classic app, then returns bounded visible app text. It does not use an OpenAI API credential.

**Enable App Control** in the Mac messenger sheet requests macOS Accessibility permission. Enable Shortcut Studio under System Settings → Privacy & Security → Accessibility; on the currently observed macOS 27 UI, this permission is under **Device Control and Data Access**. macOS controls this permission; the app cannot grant it to itself. Sign in to the target app locally if needed. The assistant action's approved bundle IDs determine which apps may be targeted. Adding apps changes the workflow revision and requires renewed sharing approval. Default targets are ChatGPT Classic (`com.openai.chat`), Chrome, Subframe, Finder and Calculator. Other apps can be added explicitly by their installed bundle identifier.

Explicit supported requests route directly; other requests use a bounded on-device intent schema. Generated app names resolve only against the workflow allowlist. Generated shell/code/file mutations are not execution routes. Desktop filenames require the action's Desktop option. No arbitrary filesystem path or file contents are read by this action.

Actual app UI control depends on exposed accessibility elements. It refuses to overwrite a nonempty compose field, verifies typed text before submitting, and returns accessible visible text rather than claiming a response API. Target apps, versions, login/foreground state, dialogs and accessibility quality may prevent input or reply extraction. Unchanged/unstable visible output has a bounded 90-second timeout. Generic app control is implemented; universal app compatibility is not established. Clipboard access is not used for typing.

On the phone, **Test alert** sends a generic result-ready notification for an existing owned terminal run. Completion alerts use high-priority Web Push; provider acceptance still differs from physical device display. The owner confirmed a test alert appeared on the OnePlus phone after the push service accepted it with HTTP 201.

## Persistent setup window and shared phone design

Messenger opens as a dedicated Mac window; switching to ChatGPT or another target does not dismiss it. The phone browser uses the same opaque shortcut palette, library cards, sidebar sections, text input/action preview and result/log output structure as the Swift app. The preview exposes approved action titles, not private configuration values. The phone can run approved workflows; it does not yet provide full Mac workflow authoring. Draft text is stored per selected workflow.

Relay/device keys are cached in memory after session unlock. The app no longer requests Keychain data for each command or streamed output snapshot. Initial Keychain authorization or ad hoc build replacement can still require owner interaction. See [standard setup framework](CLOUDFLARE_FRAMEWORK.md) for the public onboarding/signing path.

## Version 0.5.0

Read [Mac assistant upgrade](MAC_ASSISTANT_UPGRADE.md) before using folder reads, Codex/Weather controls, model on/off or named tunnel mode. Folder reads require explicit approved roots. Existing Assistant workflows need the Codex/Weather bundle list update and revision approval.
