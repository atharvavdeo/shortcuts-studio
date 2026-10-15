# Android-first agent: model and execution research

Reviewed 15 October 2026. Target specified by owner: OnePlus Nord CE5, 8 GB RAM, up to 50 GB model storage. The existing Mac application is preserved. This report and candidate registry do not constitute an Android implementation, a supported-model list, or device benchmark results. No weights were downloaded in this pass.

## Findings that determine model choice

The phone uses MediaTek Dimensity 8350 Apex, not Qualcomm. Qualcomm/Apple benchmark speeds cannot be transferred to this device. NPU execution is not assumed. Begin with a supported CPU backend, evaluate a compatible GPU backend, and publish accelerator use only after measuring it.

Bonsai is a serious candidate. The current official Bonsai 8B GGUF card lists Q1_0 weights, a roughly 1.16 GB file and an Android OpenCL measurement on Samsung S25 Ultra. Its older announcement emphasized Apple/NVIDIA, so relying only on that announcement would incorrectly exclude current Android work. The quantization requires compatible kernels; GGUF extension alone does not establish compatibility. Weight footprint excludes KV cache, activations, vision encoder and application memory. No Nord CE5 speed, heat or memory result exists in this project.

Liquid's LFM2.5 offers small Instruct, Thinking and vision-language variants, Android deployment via LEAP and published GGUF paths. That makes 1.2B Instruct a strong first evaluation candidate for ordinary tasks, with Thinking reserved for requests needing extra reasoning. Manufacturer benchmark claims are not measurements on this phone.

Qwen3.5 0.8B/2B are alternative small multimodal candidates. Model-family/runtime support and multimodal projector compatibility must be checked for the exact conversion. Larger 4B choices compete with the shopping apps for RAM. Gemma 4 E2B/E4B are additional candidates, not the sole engine. Do not infer total parameter count or loaded RAM from the effective-size name.

The 20-candidate JSON records official repository revisions, declared licenses, access gates and roles. All device support flags remain false, artifact selection is null and download is disabled. This deliberately separates repository verification from Android runtime support. Downloadable artifacts need pinned revision, exact file/hash/size, runtime version and license handling before activation.

## Initial evaluation order

| Priority | Candidate | Why evaluate | Main uncertainty |
|---|---|---|---|
| 1 | LFM2.5-1.2B-Instruct | Small default language/tool planner | Actual structured-action accuracy on device |
| 2 | Bonsai 4B and 8B Q1_0 | Unusually compact text models | Q1_0 kernels and CPU/GPU behavior on MediaTek |
| 3 | Qwen3.5-2B | Combined text and image understanding | Exact mobile conversion and total memory |
| 4 | LFM2.5-VL-1.6B | Image/notes explanation | Encoder and image-token memory overhead |
| 5 | Gemma 4 E2B | Another multimodal backend | Working Android artifact and accelerator path |
| 6 | LFM2.5-1.2B-Thinking | Optional reasoning comparison | Extra tokens, latency and heat vs Instruct |

Baselines and specialists remain in the registry to compare tradeoffs, not to inflate the shipped-model count. FunctionGemma is a task-specific tool-routing candidate requiring appropriate training/evaluation; EmbeddingGemma supports retrieval, not chat or device control. Text-only Bonsai/Phi/Llama/SmolLM variants do not directly perform image OCR.

## OCR and explanation

Use bundled ML Kit Text Recognition for supported scripts as the first text-extraction path. Include needed Latin/Devanagari models explicitly; bundled and dynamically downloaded variants have different offline readiness. Preserve extracted text, page/source regions and extraction failures. A language model can explain extracted notes; a vision model is an alternative for layout/diagrams. Do not silently correct uncertain numbers, product names or handwritten text. Handwriting and poor image quality require separate validation.

## Runtime and storage design

- One heavyweight generation session at a time; no permanent reasoning loop or model prewarming by default.
- A 20-entry catalogue is a choice of downloadable models, not 20 loaded engines. Start with one text model, OCR, and optionally one vision model.
- Owner's 50 GB is a ceiling. Initial proposed download allocation is 40 GB with 10 GB reserved for temporary conversions/downloads and workspace; expose actual usage and let the owner choose a lower cap.
- Model admission uses measured available RAM, Android memory pressure, context/image limits and the other running apps. A proposed 3 GB working budget is an initial engineering target, not a verified allowance.
- Bounded context, output tokens, task steps and execution time; unload on explicit stop and memory pressure. Stop cancels outstanding actions as well as generation where the backend supports cancellation.
- Use thermal/battery signals to reduce or pause inference. Zero heat or battery consumption cannot be promised.
- Apple Foundation Models remain an optional paired-Mac backend, clearly labelled remote inference. Android-local tasks and downloaded Android models do not depend on that Mac.

## Shopping task contract

Input: three product descriptions, quantity/pack constraints, accepted substitutions, selected stores and delivery locality already configured in those apps. Local planning still needs internet for live shopping data.

For each store, prefer a supported integration or explicit navigation adapter. Extract actual visible product identifiers, variant/pack, price, availability, URL/deep link and observation time. Product text is untrusted data, never authority to issue unrelated actions. Compare exact variants and normalize unit price; include delivery/handling/minimum-order charges when actually known. Membership coupons and account-specific prices must be labelled. An unreadable price is an error, not a generated estimate. Report “lowest observed among checked offers,” never a universal cheapest claim.

The planner selects actions; a deterministic executor validates target package, arguments, current screen and action budget. After each action, observe whether the expected change occurred. On a loop, protected screen, missing recipient/product, ambiguous result or authentication barrier, stop or request the missing information. Searching and comparing do not imply checkout authorization. A sent tap is not a verified purchase or message delivery.

## Notifications as the primary task surface

Use an Android foreground task notification when permitted for that work. Show current stage, bounded progress, model/backend, task summary and Stop. Expanded results show the three requested products and their best observed offers; actions open results/store or accept text refinement using RemoteInput. Completed OCR/notes show an excerpt plus Open/Copy where supported. Private content should be redacted on a locked screen.

Notifications have restricted space and platform/OEM behavior. Do not promise a full interactive app or all shopping rows inside the shade. Keep complete evidence/history in the app and expose it from the notification. Notification buttons are control surfaces, not a way to bypass background activity-launch restrictions. Reaching another app may require the phone unlocked and visible; not every agentic task can execute invisibly in the background.

## Distribution constraint

Google Play's current Accessibility policy prohibits general apps from autonomously initiating, planning and executing actions through Accessibility. It separately permits deterministic human-defined rules and has an exemption for genuine disability-assistance tools. Merely asking for one confirmation does not establish policy compliance. A personal sideload build and a Play-distributed version need distinct feasibility assessments; do not claim this general autonomous controller is Play-compatible or mislabel it as a disability tool. Android OS permissions and protected-screen restrictions still apply to a personal build.

## Evidence needed before shipping a default

Actual-phone comparisons must cover: exact runtime/artifact loading; model and context peak RAM while Amazon/Blinkit are open; first-token and full-task latency; OCR extraction accuracy; valid action schema rate; recovery from changed screens; observed product-match/price accuracy; cancellation; background/lock-screen behavior; repeated-task thermal and battery behavior. Judge agents by verified task completion and incorrect-action rate, not chat benchmark marketing alone. None of these device results has been measured in this pass.

## Primary sources

- Device: https://www.oneplus.com/il/nord-ce5/specs
- Bonsai current card: https://huggingface.co/prism-ml/Bonsai-8B-gguf
- Bonsai 4B: https://huggingface.co/prism-ml/Bonsai-4B-gguf
- Liquid release/deployment: https://www.liquid.ai/blog/introducing-lfm2-5-the-next-generation-of-on-device-ai
- Liquid Thinking: https://www.liquid.ai/blog/lfm2-5-1-2b-thinking-on-device-reasoning-under-1gb
- Qwen small multimodal: https://huggingface.co/Qwen/Qwen3.5-2B
- LiteRT-LM: https://developers.google.com/edge/litert-lm/overview
- OCR: https://developers.google.com/ml-kit/vision/text-recognition/v2/android
- Notifications: https://developer.android.com/develop/ui/views/notifications/custom-notification
- Accessibility distribution policy: https://support.google.com/googleplay/android-developer/answer/10964491
- Model-specific sources, revisions and access gates: `model-candidates.json`.
