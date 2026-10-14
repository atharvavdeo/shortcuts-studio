# Checkpoint before automation expansion

Reviewed 14 October 2026. This is a scoped development implementation, not Apple Shortcuts parity, Apple certification, or a production-qualified release.

## Implemented

- SwiftUI/AppKit macOS editor, library, typed workflow interpreter, variable/reference validation, branching/loops, imports, persistence and history; 67 action definitions.
- Six automation triggers: time, application activation/quit, wake/sleep and clipboard changes. Busy runs may skip triggers; time rules use a 60-second window.
- Optional supported Apple Shortcuts CLI delegation. Independent actions do not inherit Apple's entire action registry or trigger services.
- Apple Foundation Models on-demand drafting/answers/streaming. New installations default to inference off. Low Power Mode and serious/critical heat gate calls. No background inference loop, cloud-model fallback or measured NPU-only claim.
- Encrypted browser companion, pairing, scoped grants, cancellation, results and Web Push; hosted Cloudflare Worker/SQLite Durable Object adapter plus local Node adapter.
- Phone shortcut save/load/edit/run persists real workflows on the owner's Mac and inherits an approved Assistant scope. Ten command steps, 4,000 bytes; this is not the full native action editor on Android.
- Explicit approved folder listing/opening and bounded UTF-8 text/code reads. Canonical root checks reject escaping paths. PDF/Office/binary extraction and arbitrary shell execution are absent.
- App-control adapters attempt approved application opening, visible text, prompt submission and New Chat. Actual current-build Accessibility trust was denied; general application control is not verified.
- Studio model on/off/status through phone and native controls. System Apple model assets are outside Studio's storage control.
- Native Liquid Glass on key controls using availability/accessibility fallbacks; workflow content stays on standard surfaces. Full HIG conformance and rendering cost were not established.
- Explicit reminder commands register one-time/daily macOS notifications without inference, reading back pending requests. Reminder status reports authorization, pending and delivered records.

## Evidence and failures

- Latest core validation: 35 tests / 7 suites passed. Release build and 479 mechanical distribution checks passed. These counts establish their covered checks only.
- User confirmed creating, saving and running Documents list from Android with Studio AI off. Hosted-origin push display remains a separate acceptance step; old-origin alert display was previously confirmed.
- Isolated encrypted fixtures cover creation/edit/run, duplicate retrieval, invalid revisions/ciphertext/schema/size, cancellation, inherited grants and parent revocation; no real app/file permissions were used.
- Repeated password prompts were repaired by connection-session key caching. OS Keychain and privacy approvals remain owner-controlled.
- App control remained denied despite prior permission UI changes. Retained builds were unregistered from Launch Services and renamed as backups; this did not grant privacy access. Stable Developer ID signing/notarization is absent.
- Today-only 11 AM greeting registered before its time and returned a read-back confirmation. User did not see a banner; later status after rebuild/relaunch showed pending=0, delivered=0 despite enabled settings. Cause unresolved; timed visible delivery is NOT verified.
- An inappropriate Codex reminder fallback was created, then paused. User instead requested Show Now; a native Text -> Show Result shortcut visibly displayed the exact greeting. This is immediate dialog evidence, not scheduled delivery evidence.
- Latest idle snapshot showed Studio at 0% CPU, about 100 MB RSS. A separate Codex renderer had transient high CPU. No sustained power/heat benchmark was conducted. Local test fixtures stopped; runtime process state must be refreshed.

## Distribution and ownership

Local app/source ZIPs were built with an ad hoc hardened signature; no public notarized installer or APK exists. Public repository publication is a source checkpoint, not a signed release. Personal gateway setup generates a separate worker name/private token per installation; it is a CLI script, not a native account onboarding system. Each owner uses their own Mac library, Cloudflare account and credentials.

Private runtime credentials, live pairing material, app libraries, push subscriptions, personal research inventories, build caches and node_modules are excluded from publication. Public documentation retains architecture and scoped validation conclusions. Raw research inventories remain local.

## Missing functionality

No location source, geofence rules, Android background agent, phone executor, recipient-aware messaging action, action-provider registry, or robust cross-device event queue exists. Generic AX prompt submission is insufficient to prove recipient-specific message delivery. The UI and relay do not solve these gaps.

## Ordered next investigation (starts after repository checkpoint push)

1. REA evidence: inspect installed Shortcuts artifacts and bounded synthetic fixtures for serialization, scheduling, app-action dispatch, cancellation and failures. Record target hashes, provider readiness and evidence IDs; distinguish static clues from runtime observations.
2. Map recovered contracts to public platform APIs. Mac Core Location and Android native geofencing have different background/awake/permission constraints. Do not assume the browser companion can monitor background phone arrival reliably.
3. Design and implement shared rules with explicit trigger device and execution device, arrival/exit/dwell, duplicate suppression, expiry, offline behavior and execution history. No continuous model reasoning for event detection.
4. Build verified per-app actions with explicit recipients/content and a visible automation scope. Distinguish prepare, submit, failure and delivery confirmation. Do not auto-grant OS permissions or send live messages without a specific authorized destination/content.
5. Validate real device transitions and synthetic repeated/offline events before claiming parity. Physical location and app-delivery checks remain separate from simulated event tests.

REA was absent from PATH and no configured REA native provider was found in the preceding pass; official npm package metadata reports 6.5.0. Prior research used static resources, official docs and UI observation, not REA decompilation. Installation/readiness and bounded analysis are the next actual actions.
