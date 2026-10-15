# Google AI Edge Gallery source investigation and Android foundation

Date: 2026-10-15. Target: OnePlus Nord CE5, 8 GB RAM; 50 GB maximum model storage. This is source analysis and the first implementation slice, not a claim of Android device qualification.

## Decision

Build a separate Kotlin/Jetpack Compose Android application on supported inference libraries. Use Gallery as a source reference, not as our product shell. Do not reverse engineer a binary when the complete relevant source is available. No Kotlin/framework login is needed. Hugging Face authentication and model license acceptance are separate, model-specific steps.

Keep Shortcut Studio and its gateway intact. Android execution is primary; the optional Mac bridge is a later independent executor. Apple Foundation Models remain on an eligible Mac, never described as an Android runtime.

## Reproducible source snapshots

| Project | Commit inspected | License | Purpose |
|---|---|---|---|
| Google AI Edge Gallery | `8f5f2a0bdb7c81693384dbdecbabec9b1e8d7f4e` | Apache-2.0 | Android UI, model discovery/download, task examples, tool dispatch |
| LiteRT-LM | `83ceffcf1b271c40b4921d610101c1da39083c2c` | Apache-2.0 | Kotlin API, JNI/native runtime, engine/conversation lifecycle |

Both source trees are under ignored `.tools/reference/`, not vendored in the release. A default LiteRT-LM checkout started fetching Git LFS prebuilt libraries. That fetch was stopped and the checkout completed with `GIT_LFS_SKIP_SMUDGE=1`; building a source inspection does not require fetching all native prebuilts. No inference/model execution took place. These source commits and Maven 0.18.0 are separate identities; they must not be treated as an exact source-to-binary reproducibility proof.

## 1. What each layer does

```text
Compose screens / ViewModels
  → model manager / task configuration / local model path
  → LiteRT-LM Kotlin EngineConfig and Engine.initialize()
  → JNI bridge → native LiteRT-LM → selected supported CPU/GPU/NPU backend
  → Conversation.sendMessageAsync() → partial Message callbacks / Flow
  → rendered answer OR returned tool proposals
  → Android tools / intents, subject to permissions and platform restrictions
```

Kotlin is the application language, Compose the native UI toolkit. Gallery is an example/application. LiteRT-LM is the inference framework. Gemma and FunctionGemma are model families. A `.litertlm` package is an exported runtime artifact, not arbitrary original training weights. GGUF is another format and is not a drop-in LiteRT-LM model.

Gallery's inspected build uses AGP 9.0.1, Kotlin/Compose plugin 2.2.21, Gradle 9.2.1, Compose BOM 2026.02.00, min SDK 31, compile/target SDK 37, LiteRT-LM Android 0.18.0. Firebase/analytics, MCP, camera, audio, OAuth, semantic indexing and other demonstration dependencies are optional product choices, not prerequisites for local text inference. Our foundation does not copy that dependency tree.

Sources: [version catalogue](https://github.com/google-ai-edge/gallery/blob/8f5f2a0bdb7c81693384dbdecbabec9b1e8d7f4e/Android/src/gradle/libs.versions.toml), [Android build](https://github.com/google-ai-edge/gallery/blob/8f5f2a0bdb7c81693384dbdecbabec9b1e8d7f4e/Android/src/app/build.gradle.kts), [JNI bridge](https://github.com/google-ai-edge/LiteRT-LM/blob/83ceffcf1b271c40b4921d610101c1da39083c2c/kotlin/java/com/google/ai/edge/litertlm/jni/litertlm.cc).

## 2. Model discovery, authentication and delivery

`ModelManagerViewModel` fetches an app-version-specific JSON allowlist from the Gallery repository's main branch. For app 1.0.20, inspect `model_allowlists/1_0_20.json`. The root `model_allowlist.json` contains older preview entries and is not the current app catalogue.

Entries carry the repository, artifact filename, upstream commit, file size, device RAM recommendation, modality support, task roles, supported accelerators and defaults. Hugging Face discovery/custom imports are additional paths. Account sign-in provides download authorization for gated files; it does not make inference cloud-hosted.

`DownloadWorker` uses WorkManager, foreground download progress, HTTP streams, `.tmp` files, optional Range resume, cancellation checks, final rename and optional archive extraction. Model weights are stored in app-managed directories; they are not all loaded simply because they are downloaded.

Do not copy its downloader unchanged:

- The inspected worker logs a prefix of an access token. Our code must never log any token substring.
- Its resume branch accepts HTTP 200 or 206 and opens output in append mode. If a server ignores Range and returns 200, an existing partial file must instead be truncated/restarted. Validate Content-Range offsets and identity before append.
- File size and a repository commit are not a downloaded artifact SHA-256. Our installer needs an approved artifact digest and expected length, atomic finalization, free-space reserve and a 50 GB quota including partial files/cache.
- Model archives need bounded extraction, traversal/symlink checks and decompressed-byte limits.
- A downloaded model is not an approved model. Qualification is bound to artifact digest, runtime version, device fingerprint, backend, context and modality settings.
- Remote catalogue updates may propose candidates but cannot grant device capabilities or replace a qualified artifact silently.

Sources: [model manager](https://github.com/google-ai-edge/gallery/blob/8f5f2a0bdb7c81693384dbdecbabec9b1e8d7f4e/Android/src/app/src/main/java/com/google/ai/edge/gallery/ui/modelmanager/ModelManagerViewModel.kt), [download worker](https://github.com/google-ai-edge/gallery/blob/8f5f2a0bdb7c81693384dbdecbabec9b1e8d7f4e/Android/src/app/src/main/java/com/google/ai/edge/gallery/worker/DownloadWorker.kt), [current catalogue](https://github.com/google-ai-edge/gallery/blob/8f5f2a0bdb7c81693384dbdecbabec9b1e8d7f4e/model_allowlists/1_0_20.json).

## 3. Loading, streaming, cancellation and release

`LlmChatModelHelper.initialize()` chooses CPU/GPU/NPU, optional vision/audio backends, a local model path and token configuration. It creates an `Engine`, calls `initialize()`, then creates a `Conversation`. Model initialization must run away from the UI thread. Each model can hold an instance; this alone is not a global one-model invariant.

`runInference()` assembles image/audio/text contents and calls asynchronous inference. Partial `Message` callbacks contain response text and optional thought channels. `onDone` ends the response; errors and native cancellation have distinct paths. An ephemeral conversation can share an existing engine. Multiple conversations are still memory consumers even if there is one weight allocation.

`stopResponse()` calls `cancelProcess()`. Cleanup closes conversations and then the engine, clears model state and metrics. The source explicitly offloads ephemeral `close()` away from callback threads to avoid self-joining a native worker. Cancelling a coroutine alone is not a complete native teardown strategy.

For our implementation: one heavyweight worker process and one active lease, no prewarming, no idle model retention; Stop first invalidates the task generation and queued actions, requests native cancellation, then closes on a worker thread. A separate supervisor kills the worker if cancellation exceeds two seconds. A replacement cannot acquire the slot until confirmed worker exit. Neither supervisor nor isolated inference worker is wired in this first slice; the Kotlin lease encodes the slot state only.

The inspected LiteRT-LM config distinguishes `EngineConfig.maxNumTokens` (input plus output/KV capacity) from `ConversationConfig.maxOutputToken` (output, including thinking). Use bounded 2048 context and 512 output, not Gallery's larger defaults. API behavior must also be checked against the pinned Maven binary before activation.

Sources: [Gallery helper](https://github.com/google-ai-edge/gallery/blob/8f5f2a0bdb7c81693384dbdecbabec9b1e8d7f4e/Android/src/app/src/main/java/com/google/ai/edge/gallery/ui/llmchat/LlmChatModelHelper.kt), [runtime configuration](https://github.com/google-ai-edge/LiteRT-LM/blob/83ceffcf1b271c40b4921d610101c1da39083c2c/kotlin/java/com/google/ai/edge/litertlm/Config.kt), [conversation implementation](https://github.com/google-ai-edge/LiteRT-LM/blob/83ceffcf1b271c40b4921d610101c1da39083c2c/kotlin/java/com/google/ai/edge/litertlm/Conversation.kt).

## 4. Why Mobile Actions works, and what it does not do

Gallery's dedicated Mobile Actions task uses `litert-community/functiongemma-270m-ft-mobile-actions`, a specialised fine-tune, not unrestricted generic phone control. Its Kotlin tool set offers flashlight on/off, contact creation, email, map location, Wi-Fi settings and calendar event creation. Android APIs/intents execute those functions.

Opening an email composer is not proof the email was sent. Opening a calendar editor is not proof an event was saved. A tool name such as “send email” must not become a delivery claim in our results. The observed `createCalendarEvent` helper falls back to the current time on invalid model dates; our validator must instead reject invalid or ambiguous dates.

Gallery's broader agent path uses modular skills, intent handling, JavaScript and MCP; it is distinct from the small Mobile Actions task. `RunIntentTool` validates known intent names, dispatches through `IntentHandler`, and can request permissions through its execution context. These remain explicitly implemented integrations. They do not unlock arbitrary third-party private APIs.

LiteRT-LM's `automaticToolCalling` defaults to true. Our agent must set it false: a model proposes, our router checks the schema, allowlist, task bounds, current screen, permission and any required confirmation, then the executor acts. Results go back to the model as observed tool results. App/web page text remains untrusted data, never authority to grant tools or bypass user intent.

Sources: [Mobile Actions tools](https://github.com/google-ai-edge/gallery/blob/8f5f2a0bdb7c81693384dbdecbabec9b1e8d7f4e/Android/src/app/src/main/java/com/google/ai/edge/gallery/customtasks/mobileactions/MobileActionsTools.kt), [Android action implementation](https://github.com/google-ai-edge/gallery/blob/8f5f2a0bdb7c81693384dbdecbabec9b1e8d7f4e/Android/src/app/src/main/java/com/google/ai/edge/gallery/customtasks/mobileactions/MobileActionsViewModel.kt), [agent intent tool](https://github.com/google-ai-edge/gallery/blob/8f5f2a0bdb7c81693384dbdecbabec9b1e8d7f4e/Android/src/app/src/main/java/com/google/ai/edge/gallery/tools/RunIntentTool.kt), [intent handler](https://github.com/google-ai-edge/gallery/blob/8f5f2a0bdb7c81693384dbdecbabec9b1e8d7f4e/Android/src/app/src/main/java/com/google/ai/edge/gallery/intents/IntentHandler.kt).

## 5. Memory and thermal gaps relative to our contract

Gallery's `MemoryWarning.isMemoryLow()` compares model minimum-device-RAM metadata with total/advertised physical RAM. It can display a “proceed anyway” choice, and missing metadata does not deny the model. Its HF size helper additionally compares file bytes with a fraction of total RAM. Neither calculation measures combined runtime peak.

Its `MemoryMonitor` samples `Debug.getPss()` for the current process. Metrics collection is useful for measurement; it does not impose a physical-memory cap or account for every separate process/shared accelerator allocation. PSS is proportional accounting, not an interchangeable exact RSS ceiling. The inspected paths do not establish our battery, thermal, two-second worker-kill or aggregate allocation requirements.

Our resource contract remains stricter: combined 3,000,000,000-byte agent budget, admission below 2,250,000,000 bytes, early stop at 2,700,000,000 observed bytes, 2 GB system reserve, one heavyweight slot, thermal MODERATE or above stops/unloads, battery >=20%, no Saver/low-battery inference, unknown/stale telemetry denied. LIGHT requires an implemented reduced-workload policy; a flag alone is insufficient. Native allocations must be accounted before models are enabled. A public Android app cannot claim a universally enforced physical RSS cap merely from sampled telemetry or Java heap settings.

The added Kotlin governor implements admission decisions and denial reasons; it is not yet connected to Android telemetry, an allocator or a worker supervisor. All current models remain disabled.

Sources: [memory warning](https://github.com/google-ai-edge/gallery/blob/8f5f2a0bdb7c81693384dbdecbabec9b1e8d7f4e/Android/src/app/src/main/java/com/google/ai/edge/gallery/ui/common/MemoryWarning.kt), [PSS monitor](https://github.com/google-ai-edge/gallery/blob/8f5f2a0bdb7c81693384dbdecbabec9b1e8d7f4e/Android/src/app/src/main/java/com/google/ai/edge/gallery/common/metrics/MemoryMonitor.kt), [local resource contract](../../android-agent/policy/RESOURCE_CONTRACT.md).

## 6. First artifacts to evaluate

| Artifact from current Gallery allowlist | File bytes | Meaning for our build |
|---|---:|---|
| FunctionGemma mobile-actions Q8 | 288,964,608 | Small routing experiment for its known tools; not broad reasoning/vision |
| Gemma3 1B INT4 | 584,417,280 | Small text/runtime baseline; still needs measured peak and accounting |
| Gemma4 E2B | 2,588,147,712 | File alone exceeds our admission threshold; excluded from activation pending a different qualifying artifact |

These sizes come from source metadata, not downloaded hashes or measured resident memory. See [artifact metadata](gallery-artifacts.json). Do not mistake Gemma's effective parameter count for its physical footprint.

LiteRT-LM is the first supported integration path for these exported artifacts. Bonsai Q1_0 needs compatible PrismML/llama.cpp kernels and a separate adapter; standard GGUF support does not guarantee Q1_0 support. LFM/Qwen artifacts need exact export/backend validation. Backend names in Kotlin are not proof the Nord's MediaTek NPU is supported. Google's current [NPU setup guide](https://developers.google.com/edge/litert/next/litert_lm_npu#mediatek-neuropilot), checked on 2026-10-15, lists MediaTek Gemma3 1B artifacts for MT6989 and MT6991 and requires matching SoC-specific exports and dispatch libraries. This does not establish support for this Nord's reported SoC; obtain `ro.soc.model` from the authorized device before selecting an artifact. Start with a measured supported backend; unaccounted GPU/NPU stays off. Do not load two model backends concurrently.

## 7. Product architecture

1. **Kotlin + Compose app:** commands, accessible large text, task timeline, evidence cards, installed-model management, permission explanations and settings. No mandatory login for local use.
2. **Deterministic router:** explicit commands, saved rules, then specialised tools such as OCR; model planning only if necessary. Do not use a language model to open Wi-Fi settings.
3. **Task coordinator:** bounded steps/calls/time, cancellation generation, pause/resume and observed outcomes. Persist task history, not running model state.
4. **Capability executor:** Android intents and supported APIs first; scoped document picker for file access, on-demand OCR, explicit optional Accessibility adapter for personally installed agent control. Never auto-enable permissions. General agentic Accessibility use needs its own distribution-policy review before Play release.
5. **Resource supervisor:** fresh OS signals, backend accounting, admission, deadline, child-worker lifecycle and the single lease. Default deny.
6. **Inference worker:** supported LiteRT-LM first, future compatible GGUF adapter. No direct app mutations or credentials in the worker. Manual tool proposals only.
7. **Notification presenter:** real task stage, Stop, optional RemoteInput refinement and compact observed results; private lock-screen content redacted. Full offers/evidence in the app. Android foreground-service types/background-start restrictions must be designed for the actual task; never hide perpetual inference behind a generic service label.
8. **Optional remote executor:** paired Mac capability requests when specifically chosen. Mac sleeping/offline is an explicit state. Local Android logic does not depend on it.

Shopping must obtain current, location-specific offers from real app/API observations. Compare exact SKU/pack/quantity, stock, known fees and timestamps. Say “lowest observed among checked offers.” No invented live prices or checkout implied by a search. Protected/ambiguous screens stop rather than guessing.

## 8. What landed in this pass

- Standalone `android-agent/` Gradle project, an SDK-independent Kotlin `core` module and opt-in native Compose `app` module.
- Kotlin admission governor with fail-closed memory/battery/thermal checks, cooldown and profile requirements.
- Single inference-lease state machine; stopping retains ownership until confirmed worker exit.
- Explicit command router: status, stop, Wi-Fi settings and validated HTTPS open; everything else is classified as needing an unavailable model/tool, never represented as executed.
- Native app source with those deterministic actions and a read-only 20-model research catalogue; no automatic permissions, no network downloader, no native model is initialized.
- Pinned LiteRT-LM Android 0.18.0 dependency; runtime adapter and worker are not wired yet.
- Reproducible Gradle distribution checksum and wrapper attribution.

## 9. Build and next acceptance gates

Core compilation does not require an Android SDK: `cd android-agent && ./gradlew :core:compileKotlin --no-daemon` with Java 21. The APK command is `./gradlew -Pandroid=true :app:assembleDebug --no-daemon` after SDK setup and owner acceptance of Google's SDK license. No license is accepted automatically. No APK or physical-phone behavior is claimed until the build/device run actually happens.

Next implementation sequence:

1. Owner installs SDK through Android Studio; resolve Android build and compile the deterministic shell.
2. Install with explicit device authorization; demonstrate opening Wi-Fi settings and a real URL. No model required.
3. Add isolated worker IPC, supervisor and fresh combined telemetry; qualify native allocation accounting before enabling inference. This is the critical gate, not a cosmetic settings switch.
4. Verify the pinned runtime binary's APIs, then wire streaming, native cancellation, manual tool proposals and release. Start with one small exact artifact, not 20 simultaneous downloads.
5. Measure device peak memory, system responsiveness, repeated cancellation, battery/thermal transitions, app backgrounding and screen lock. Rejected profiles stay unavailable.
6. Add OCR + note explanation, then one real supported shopping app journey with result extraction. Expand app adapters from observed successes.
7. Add notification controls and optional Mac routing; preserve the same resource and permission gates.

This sequence separates native inference from app execution. Improving the language model does not by itself implement a missing Android integration.
