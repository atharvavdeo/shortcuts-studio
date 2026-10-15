# Create and run shortcuts from your phone

Phone shortcuts are real workflows saved in the paired Mac’s local library. Your phone controls your Mac. Another owner pairs with their own Mac and deploys their own gateway; neither their shortcuts nor credentials belong to this installation.

## Use

1. Connect Mac Studio to its hosted gateway. Review and enable the **Phone · Assistant** sharing checkbox. It must be a single Assistant action whose prompt is `{{input}}`. Its approved apps and folders define the scope inherited by phone shortcuts.
2. Pair your phone once, comparing its fingerprint on the Mac. Existing pairing persists at the same gateway origin.
3. On the phone choose **My Shortcuts → Create Shortcut**. Enter a name and ordered commands. For example, name **Documents list**, command `list folder Documents`.
4. Tap **Save Shortcut**. The Mac persists it before returning success. Open its tile and tap **Run**. Results return to the phone inbox; configured completion alerts notify you.
5. **Edit** retrieves the commands through the encrypted channel. Saving updates that Mac workflow; conflicting revisions fail rather than overwrite another edit.

Up to ten commands and 4,000 UTF-8 bytes per shortcut. Use `{{previous}}` for the prior result and `{{input}}` for optional run input. A draft persists across page refresh. An offline Mac cannot save or execute; drafting remains available with cached approved Assistant metadata.

## Model controls and energy

Open **Assistant** on the phone: **Turn AI off**, **Turn AI on**, **AI status**. Equivalent commands are `model off`, `model on`, `model status`. If a run is active, press **Stop** in its output card, wait for cancellation, then turn AI off. On the Mac, disable **Messenger → Phone Messenger → Use Apple model on demand**; this also requests cancellation of the current Studio run.

New installations default to AI off. Studio does not prewarm a model or keep a background inference loop. Enabled AI runs only when required, with bounded generation. Low Power Mode and serious/critical thermal state block new inference; streaming checks the gate again. Turning it off controls Studio calls, not system-wide Apple Intelligence or unrelated apps. System model storage is managed by macOS; Studio does not delete those assets. Disabling inference does not guarantee immediate reclamation of system caches.

## Scope and ownership

Save inherits the already approved Assistant scope; it cannot add an app, grant a folder, or approve an OS prompt. Revoking or changing that parent scope disables its phone children. Demo cards are hidden from the phone, while their existing Mac library files are preserved.

This phone editor sequences Assistant commands. It is not yet the native 67-action drag-and-drop editor. Explicit app control still requires the current Mac app’s actual OS permission. PDF/Office/binary extraction and arbitrary shell execution are not implemented.

## Each owner’s internet gateway

Install pinned dependencies with `npm ci --prefix gateway`, authorize your own Cloudflare account with the included Wrangler, then run `scripts/setup-personal-gateway.sh`. It creates a unique Worker name and private Mac token, deploys a gateway, and writes a private bootstrap connection for that local installation. Source configuration has no hard-coded Cloudflare account ID. Connect/restart Studio and pair your own phone. This is a setup script, not an automatic native OAuth installer or a shared multi-user hosted service.

## Validation boundary

Hosted Swift/WebCrypto checks cover save/load/edit/run, inherited grants, revocation, malformed input and forged ciphertext. Browser UI checks use an isolated Mac fixture with no app/file permissions. Real Android pairing and notification display on the hosted origin remain user acceptance steps. Passing these does not establish Apple Shortcuts parity or OS app-control permission.

## Local Mac reminders

Explicit commands such as `today at 11am send Good Morning! Lets rock this day` and `every day at 10am send Good Morning! Lets rock this day` now register a macOS calendar notification directly, without model inference. These notify the Mac, not the phone. The command returns success only after reading back the pending request and its next trigger date. `today` means one dated request with no repeat; past times fail and are not silently moved to tomorrow. Daily times roll forward when today's time has passed. AM/PM and the Mac's local time zone are required by this parser; broader calendar prose is not implemented.

macOS owns delivery after registration; there is no inference loop or sleeping workflow. Identical schedule/message requests use the same identifier to replace rather than duplicate a pending reminder. `reminder status` reads pending requests, delivered records, and app notification settings. A delivered record does not prove that a banner was visible; Focus and notification presentation settings can suppress it. The app handles foreground notification presentation with banner, list and sound options. Notification permission must be authorized by the owner.

Validation caveat: the local 11 AM reminder passed registration/readback but did not produce user-confirmed visible delivery; subsequent diagnostics found no delivered record after the app was rebuilt/relaunched. The cause is unresolved. Treat calendar notification registration as implemented, with visible scheduled delivery still requiring acceptance testing. Immediate Show Result was visibly verified.
