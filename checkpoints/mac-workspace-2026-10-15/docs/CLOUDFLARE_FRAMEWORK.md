# Standard internet setup framework

**Status: hosted single-owner Worker/Durable Object adapter implemented and deployed.** See [Hosted gateway](HOSTED_GATEWAY.md) for the stable URL and validation. Automatic per-owner provisioning, public template distribution and a native Android installer remain future work.

## Desired owner journey

1. Install a signed/notarized Mac companion. Its setup window remains available while other apps execute.
2. Choose **Set up my internet gateway**. Authorize deployment into the owner's Cloudflare account through the official OAuth/deploy workflow, select the account when more than one exists, and show resources/hosting policy before provisioning.
3. Deploy a pinned gateway release, generate independent secrets, and obtain a stable `workers.dev` URL or configured domain.
4. Save Mac credentials in Keychain under a stable signing identity. Show a QR code/link containing a short-lived pairing challenge, never a long-lived bearer secret.
5. Open/install the companion on Android and pair with Mac confirmation. Cloudflare owns hosting authorization; pairing/workflow grants own execution authorization.
6. Run setup checks for on-device model availability, Desktop permission, app-control permission, notification subscription and a harmless Echo round trip.
7. Choose approved workflows/apps. Input/output travel through the gateway. Actual inference/actions remain on the Mac.

Android installation alone cannot provide Apple's Foundation Models or authorize a person's Mac. The Mac companion must exist, be paired, remain awake/reachable and have an eligible/enabled/ready Apple on-device model. A phone-only product would need a separate Android/cloud model provider and executor; that is a different runtime.

## Cloudflare-supported distribution paths

Cloudflare documents **Deploy to Cloudflare** buttons/templates for deploying an application into another owner's account. The button requires a real source template/repository and its deployment metadata; this checkout is currently local. Wrangler supports official OAuth login, authentication inspection and Worker deployment. Being signed into the Cloudflare website is not a credential this app should read or silently reuse. The deployment authorization is a separate explicit OAuth/account step.

References: [Deploy buttons](https://developers.cloudflare.com/workers/platform/deploy-buttons/), [templates](https://developers.cloudflare.com/workers/get-started/quickstarts/), [Wrangler authentication](https://developers.cloudflare.com/workers/wrangler/commands/general/), [Worker deployment](https://developers.cloudflare.com/workers/wrangler/commands/workers/).

Recommended first public distribution: one gateway per owner's account. A centrally operated multi-user service additionally requires owner accounts, tenant isolation, abuse/quotas, credential recovery, retention/deletion operations, privacy/support terms and ongoing service ownership. Do not advertise the current single-owner Node process as that service.

## Framework boundaries

| Module | Contract |
|---|---|
| Deployment adapter | Official account authorization, versioned provisioning, secret storage, URL capture, rollback and resource inventory |
| Gateway runtime | Durable command/result ownership, pairing/expiry/revocation, authenticated routing and bounded push hints |
| Mac agent SDK | Awaitable run ownership, versioned grants, cached session keys, deterministic validators and cancellation |
| Permission/readiness UI | Actual OS/model states, user-triggered permission requests, clear denied/revoked paths and harmless checks |
| Phone UI | Shared visual tokens, workflow cards/input/output/history, pairing, install affordance and notification status |
| Model providers | Apple system model on eligible Mac; future providers explicitly configured, never silent cloud fallback |
| Release/update path | Stable Developer ID identity, notarization, signed version/channel metadata and migration compatibility |

The Worker/Durable Object adapter now shares the encrypted protocol with the Node relay and uses durable SQLite rows plus fetch-based push transport. Cross-runtime and restart checks pass for the current single-owner deployment. Automatic per-owner deployment and public template distribution remain separate work.

## Permissions in one place

- **Cloudflare:** authorize deploying the named gateway resources; do not collect browser cookies or put management tokens in phone code.
- **macOS app control:** public AX APIs require the owner's OS permission. Current macOS 27 names the panel Device Control and Data Access; earlier macOS calls it Accessibility. The application cannot grant this to itself.
- **Desktop:** filesystem privacy applies separately; filenames-only workflow avoids arbitrary file content/path access.
- **Foundation Models:** use public availability reasons (ineligible, disabled, model-not-ready). The SDK cannot make unsupported hardware eligible or force download/readiness silently.
- **Android browser notifications:** request on owner action; validate registration, test a generic alert, preserve inbox when denied. Provider receipt is not device display.
- **Execution:** pair identity, workflow revision and application allowlist are explicit grants. No shell/code/file-mutation route is added automatically by deploying a gateway.

Onboarding can request, guide, verify and persist these choices. OS permissions, account authorization and model prerequisites remain real platform boundaries.

## Password and window repairs

The connector now caches relay/device credentials in memory after unlocking the session. AES-GCM reads the cached device key rather than calling Keychain for every command/snapshot. Revoked relay devices are removed from the local paired-device list, avoiding obsolete-key prompts. Isolated tests count credential reads during real encrypted command/result/cancel flows.

Messenger now uses a dedicated SwiftUI Window instead of a modal sheet tied to the authoring window. Opening other apps leaves the setup window available. During development, replacing an ad hoc signed app can still change its OS trust identity; a stable Developer ID signing/update pipeline is needed before claiming seamless public setup. This repair does not promise that a locked Keychain or first authorization never asks the owner.

## Release gates

1. Package and validate the current UI/key-cache fixes on this Mac and Android phone.
2. Build the durable Cloudflare adapter and automatic account-specific deployment transaction; validate locally and through a scoped real account.
3. Publish the pinned template and signed Mac artifact at owner-approved destinations.
4. Test clean-machine setup, Android install/pairing, permission denial/revocation, key caching, updates, model readiness, offline/crash/reconnect and notification delivery.
5. Measure setup completion and failure recovery on multiple devices; no universal-installation claim from one phone.
