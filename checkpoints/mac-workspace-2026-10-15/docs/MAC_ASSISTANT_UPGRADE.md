# Mac assistant, files, power and remote access

## Version 0.5.0

Implemented: explicit folder listing/opening, bounded UTF-8 file previews, a semantic New Chat/New Task action, Google visible results, Weather visible results, Studio model on/off commands, Low Power Mode/thermal inference gates, and reduced idle polling. Actual native app adapters still require App Control permission and readable accessibility controls. A build is not proof of successful Codex/Weather interaction.

## First use

1. Open Phone Messenger in the updated Mac app.
2. Choose **Simplify & Enable Codex/Weather**. Unmodified counter/JSON/list demos move to recoverable Trash. The old Google launch-only workflow also moves to Trash. Edited demo workflows are preserved; use normal Trash controls for those. Phone Assistant gains Codex and Weather in its application list, invalidating its old revision grant.
3. Check Phone · Assistant again to approve that revision. Other paired-device credentials are preserved.
4. Under **Approved folders for phone reading**, choose **Approve Folder…**. This grants paired assistant commands read access to that folder and its children. macOS file privacy permission may still be needed. Remove a folder here to revoke future access; previously delivered results remain in the phone's inbox.
5. Refresh Android Chrome. Choose Assistant and enter a command below.

| Command | Result |
|---|---|
| `model off` | Disable Studio's inference; explicit tools remain usable |
| `model on` | Allow inference on demand, subject to availability/power/thermal checks |
| `model status` | Return Studio's setting and Apple model readiness |
| `list folder Desktop` | Actual visible entries in an allowed folder |
| `open folder Desktop/My Folder` | Open the folder in Finder and return entries |
| `read file Desktop/My Folder/note.md` | Actual UTF-8 text preview |
| `new chat in Codex` | Press an exposed exact New Chat/New Task control, then return visible app text |
| `Google <query>` | Open Chrome, verify the search document URL/query and return visible results |
| `check the weather` | Open Weather and return its currently displayed location/conditions |
| `In ChatGPT: <prompt>` | Submit into an empty approved compose field and return changing visible app text |

Natural phrasing can be classified by Apple's model when enabled. Commands preserve explicit paths and app targets. The model is not an OS permission grant or an unrestricted computer-use agent. The current planner chooses one task per request; it does not yet execute arbitrary multi-step plans. App text is tool output, not instructions to perform further actions.

## File limits

- A file/folder must resolve inside an explicitly approved root (or Desktop when the workflow permits it). Canonical path boundaries reject `..`, symlink escapes and sibling-prefix tricks.
- Listings skip hidden entries and show at most 200 names. Opening folders does not change their contents.
- Reading supports regular `.txt`, `.md`, `.csv`, `.json`, `.log`, `.swift`, `.py`, `.js`, `.ts`, `.html`, `.css`, `.yaml`, `.yml`, and `.xml` files. Maximum preview is 24 KiB; the transport's existing 12 KiB result bound can truncate it further, with a marker.
- No recursive bulk extraction, PDF/Office/image parsing, file mutations, or shell execution. Files are returned to the paired phone; file contents are not automatically sent to ChatGPT or another cloud service.

## What the power controls do

Studio explicitly uses `SystemLanguageModel.default`. It creates sessions only to classify non-explicit requests, answer questions, or draft workflows; there is no idle inference loop or model prewarming. Sessions are not retained across commands. Turning off Studio inference blocks new model requests and checks the gate again during streamed answers. It does not switch off Apple Intelligence system-wide or control Apple's OS-managed model residency.

Mac Low Power Mode pauses Studio inference. Serious/critical thermal states also pause it. Explicit file/open/list/model-setting commands continue. Use the phone Stop action to cancel an active workflow before sending another command; only one run can execute at once. Idle connector polling changed from once per second to once per four seconds; active runs retain one-second delivery checks.

There is no measured battery/temperature guarantee. The tunnel, relay, app, network wakeups and requested tasks still consume power. An asleep/shut-down Mac cannot execute commands. A powered, awake Mac at home with its display off is the intended remote-use setup. Studio does not silently prevent sleep or change macOS energy settings. Public Foundation Models availability remains a real requirement: [Apple documentation](https://developer.apple.com/documentation/FoundationModels/generating-content-and-performing-tasks-with-foundation-models).

## Permanent connection

Pairing is remembered; the phone and Mac do not need to stay physically together or share Wi-Fi after pairing. The current Quick Tunnel URL lasts only for that tunnel instance and can change on restart: [Cloudflare Quick Tunnels](https://developers.cloudflare.com/tunnel/get-started/quick-tunnels/).

A named Cloudflare Tunnel with a configured HTTPS hostname is the smallest upgrade for the existing Node relay. Use the owner account to create a named tunnel and route the hostname to `http://127.0.0.1:8787`. Keep its token in a private file; never put it in phone code or documentation. The launcher now supports this mode:

```bash
STUDIO_GATEWAY_ORIGIN=https://your-owned-hostname.example \
STUDIO_TUNNEL_TOKEN_FILE=/absolute/private/path/tunnel-token \
bash scripts/start-messenger.sh
```

This configures an existing named tunnel, not automatic account/resource provisioning. Do not start a second relay against the same runtime directory/port. Stop the temporary relay/tunnel deliberately when migrating. A different origin requires initial phone pairing again because browser credentials are origin-scoped. Once paired to the stable hostname, routine tunnel reconnection uses the same link. An independently hosted durable relay is now implemented and deployed; see [Hosted gateway](HOSTED_GATEWAY.md).

SMS is not implemented. An SMS transport would need a service/provider and account, and its message body must not directly authorize Mac execution; it would still need authenticated pairing and replay protection. It does not remove the requirement for a reachable Mac. The HTTPS messenger already returns encrypted results and push alerts across different networks.

## Evidence and remaining work

The assistant validation covers actual file content/listings, canonical boundaries, explicit parsing, model toggles, file use with AI disabled, rejection of disabled inference, and a live Apple model answer/stream. Store, encrypted messenger and distribution checks remain separate evidence.

Native Codex New Chat, Chrome search extraction and Weather results require a live, OS-authorized app check. Button discovery is bounded and exact; inaccessible controls return an error without guessing a keyboard shortcut. Returned Weather text is the app's selected location, not an invented answer for an arbitrary requested city. General app navigation, multi-step planning, structured search/weather adapters, sleep recovery and measured energy profiling remain work.
