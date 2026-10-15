# Resource contract: Android agent

15 October 2026. Owner requirement: phone responsiveness takes priority over finishing an agent task. Existing Mac Studio remains unchanged. This is a mandatory design contract, not a claim of working phone-side enforcement; no Android executor or runtime is installed yet.

## Fixed ceiling and conservative operation

Use exactly 3,000,000,000 bytes (3 decimal GB) for the combined agent budget, never a 3 GB allowance per model or per process. Start only with a verified exact artifact/runtime profile whose estimated aggregate task peak is below 2.25 GB, leaving at least 2 GB system memory free after the proposed load. Stop at 2.7 GB observed aggregate use, before reaching the budget. Models exceeding the profile are disabled even if downloaded. File size is not peak memory.

Charge weights, KV cache, prompt/image tensors, model buffers, OCR workspace, UI/service allocations, IPC and transfers. Separately account GPU/NPU/shared allocations; disable a backend when its costs cannot be bounded. Do not mislabel Java heap limits, storage limits, mmap file length or RLIMIT_AS as physical RAM caps.

A strict allocation limit requires the actual inference backend to reserve memory through an accounting allocator before allocating or mapping bounded buffers. Java/native/GPU allocations outside that allocator are not magically capped by a JSON setting. Android offers memory telemetry and process-lifecycle controls, not a universal normal-app API guaranteeing an exact combined physical RSS ceiling. The 3 GB allocator budget is enforceable for controlled allocations; aggregate-process monitoring and worker termination are a second, sampled protection layer and can have delay. A backend whose complete working set cannot be accounted for must not be advertised as strictly capped or enabled for this target.

## One model, no overlap

Use one admission controller and exclusive heavyweight lease across all runtimes, including OCR/vision work with material memory requirements. A model switch must cancel work, dispose its session, terminate its isolated process if needed and confirm exit before another is admitted. Do not load the next model alongside the prior model. A large vision model and text planner cannot run concurrently. Idle retention and prewarming default to zero.

## Logic first

Exact app commands, saved rules, timers, arithmetic, filters, sorting, unit-price comparisons and supported OCR extraction use deterministic/specialized tools. Model routing is for interpretation, explanation, ambiguity and planning only when deterministic handling is insufficient. Validate the plan and each resulting observation outside the model. The planner has no authority to change budgets or bypass a denied gate. If a required model is unavailable, report that limitation rather than silently inventing a result or changing backends.

## Responsive UI and bounded worker

Keep JNI/inference, tokenization, image decoding and disk loading off the UI thread in a separate worker process. Main UI/notification service remains independent. Bound context, image sizes, output, steps, retries and wall time. Reject stale/missing memory readings and unknown profiles. Observe memory pressure while other apps run, not only at load. A stop operation invalidates queued actions, requests cooperative cancellation, then kills an unresponsive worker after two seconds. No automatic task replay after a kill. No busy retry loop, indefinite wake lock, background model loop or retained screenshot stream.

## Battery, temperature and background policy

Block inference in Battery Saver or on battery-low signal. Require at least 20% charge at admission and cancel when the low-battery gate activates. Charging does not bypass heat checks. Android LIGHT thermal status reduces work; MODERATE or higher cancels and unloads inference. Unknown thermal state does not count as cool. Use supported thermal callbacks/headroom where reliable, with no universal battery-temperature threshold falsely treated as a CPU sensor. Wait at least 60 seconds in an acceptable state and require a new explicit task after heat cancellation.

App UI going into the background during a user-started cross-app task is distinct from idle background reasoning. Only an explicitly active, bounded task may continue with a visible supported task notification. Locking the phone pauses heavyweight inference by default. Event listeners enqueue bounded work and do not keep a model warm. Respect Android's service/background restrictions; do not ask the owner to disable all battery optimizations as the default solution.

## Admission and acceptance

Admission checks exact artifact/runtime, available RAM, owned allocation budget, aggregate app/process use, thermal status, Battery Saver, low-battery state, task visibility/lock state and exclusive lease. Denial occurs before executing an action. Runtime supervision rechecks gates during the task and owns cancellation independently of model output.

Before calling this enforced, the native implementation must demonstrate on the actual Nord CE5: allocator denials at boundary values; no overlapping worker PIDs/models during switches; cancellation under a stuck worker; short-context OCR/notes tasks while shopping apps remain usable; memory-pressure refusal; thermal and low-battery stop; screen-lock/background transition behavior; bounded repeated runs without increasing retained memory. No such hardware validation has happened. No model is enabled solely because its upstream repository exists.

We can enforce our allocation/task contracts and shed our workload. We cannot guarantee that every other app, Android component, charging condition or ambient temperature keeps the entire phone smooth at every moment. No zero-heat, zero-battery-cost or cannot-crash guarantee should appear in product claims. If the required resource behavior cannot be demonstrated for a model/backend, it stays unavailable.

Sources:
- https://developer.android.com/games/optimize/adpf/thermal
- https://developer.android.com/topic/performance/memory-overview
- https://developer.android.com/topic/performance/memory
