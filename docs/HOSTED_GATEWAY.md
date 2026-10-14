# Hosted messenger gateway

## Current deployment

The single-owner Cloudflare Worker is deployed at:

**https://shortcut-studio-messenger.drishti-console.workers.dev**

It serves the Android browser companion and forwards authenticated protocol requests to a SQLite-backed Durable Object. No domain, inbound router port, local Node relay or Quick Tunnel is required for this hosted path. Execution and Apple model inference remain on the connected Mac. This is a hosted single-owner deployment; it is not yet an automatic installer or a multi-user service.

## Migration

1. Use the hosted URL as the Mac gateway origin. The existing Mac gateway credential is installed as a Cloudflare Worker secret; the script and source never embed it.
2. Connect Studio. Approve only the workflows you intend to share. Editing the Assistant's application list changes its revision and requires its checkbox to be checked again by the owner.
3. Open the hosted URL in Android Chrome. Create a pairing code on the Mac, enter it on the phone, compare the fingerprint, and approve that specific phone yourself. Browser credentials are origin-scoped, so migration from the temporary URL needs this initial pairing.
4. Enable notifications on this new origin and run Echo. The old origin's notification subscription does not automatically migrate.
5. Once the new phone connection works, stop the old relay/tunnel deliberately. Do not run two connectors against the same Mac workflow engine.

Routine future reconnects use this URL and the persisted phone key. A sleeping, shut-down or offline Mac still cannot execute tasks. The relay never performs model inference or substitutes generated content for app/file results.

## Implementation

- `gateway/protocol.mjs`: shared protocol validation, roles, pairing, expiry, grants, ciphertext routing, cancellation, notifications and result ownership.
- `gateway/server.mjs`: local Node HTTP/filesystem adapter.
- `gateway/cloudflare/worker.mjs`: Worker assets, bounded Request adapter, push delivery through `fetch`, and per-owner Durable Object storage.
- SQLite stores separate metadata/device/pair/run rows, rather than one potentially oversized session blob. Changed rows are committed synchronously in a transaction before responses acknowledge mutations. State, VAPID keys and unused pairing challenges survive process/object recreation.
- Browser response security headers and exact-origin checks match the Node relay. The request body limit is 64 KiB. Existing per-device ownership, single active run and 1,000-run session bound remain.
- Push destinations remain restricted to approved providers. Notifications contain a generic run ID hint; the phone fetches and decrypts its result.
- Cloudflare stores ciphertext and routing/authentication metadata. It also serves the browser JavaScript, which remains a trust boundary. Do not advertise independently reviewed end-to-end messenger security.

## Personal installation

Use `scripts/setup-personal-gateway.sh` after installing pinned gateway dependencies and authenticating your own Cloudflare account. Each installation gets its own generated Worker name and private credential. See [phone authoring and ownership](PHONE_AUTHORING.md).

## Deployment and recovery

Install pinned dependencies with `npm ci --prefix gateway`. Authorize your own Cloudflare account with Wrangler. The current configuration names one Worker and its SQLite Durable Object migration. For a different owner, use that owner's account; do not reuse this owner's Mac credential or deployment.

```bash
gateway/node_modules/.bin/wrangler deploy --dry-run --config gateway/cloudflare/wrangler.jsonc
gateway/node_modules/.bin/wrangler deploy --config gateway/cloudflare/wrangler.jsonc
gateway/node_modules/.bin/wrangler secret put MAC_TOKEN --config gateway/cloudflare/wrangler.jsonc < .gateway-runtime/mac-token
```

The secret is a server credential, never a phone credential. Keep the private runtime directory out of source distributions. New deployments return `GATEWAY_NOT_CONFIGURED` until the secret exists. Do not overwrite an unrelated Worker. The owner must authorize account/deployment and OS permissions; this application does not auto-approve them.

For local conformance checks, use a synthetic Mac token, an isolated persistent directory, and `gateway/test/worker-conformance.mjs`; restarting the local Worker and using `--resume` checks credential/result/challenge restoration. `gateway/test/mac-integration.mjs` supports an external gateway and a private Mac-token file for actual Swift CryptoKit/WebCrypto protocol checks. Its fixture owns only Echo/Wait workflows, uses an in-memory vault, and revokes its test phone afterward. It does not establish native app-control permission or real Android notification display.

## Evidence

The deployed gateway passed an actual Swift connector round trip, including encrypted Unicode output, replay/duplicate retrieval, changed revisions, forged ciphertext, oversized input rejection, cancellation and zero per-command credential reads. Local Worker checks cover role separation, single-use pairing, approval, ownership, busy/conflict handling, terminal monotonicity, destination/origin restrictions and restart persistence. Physical Android pairing and notification display on this new origin are separate acceptance steps.

## Packaging and permissions

Old development bundles retained for running-executable safety now use `.bundle-backup`, not `.app`. The packager unregisters the outgoing bundle from Launch Services and registers the new destination. This prevents retained builds from being offered as the current application. Existing staged app copies were removed from Launch Services; their files were retained.

This changes application registration, not macOS privacy grants. Ad hoc signed updates can still change signing requirements. A stable Developer ID release is required for dependable public update trust. Studio must report actual `AXIsProcessTrusted()` status; a toggled stale permission entry is not evidence that current app control works.
