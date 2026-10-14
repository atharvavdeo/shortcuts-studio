# Are we better than Apple Shortcuts?

There is no evidence that Shortcut Studio is generally better, faster, safer, easier, or more capable. It has a smaller independent feature set. The useful differentiator today is **engineering control over this implementation**.

## Evidence-based comparison

| Topic | Shortcut Studio today | Apple Shortcuts / comparison boundary |
|---|---|---|
| Inspect and modify execution | Source, named Swift library API, tests and documented semantics available in this checkout | Apple's public CLI does not expose its private engine source; our source is not yet publicly licensed/hosted |
| Versionable authoring | Own readable JSON envelope and stable action kinds; generated catalog | Easier to inspect for our own format; no measured collaboration advantage and no Apple signed-format interchange |
| Predictable bounded control | Explicit step/loop/call budgets and commit/cancellation semantics | These are documented design choices, not evidence that Apple's runtime is unsafe or unbounded |
| Model integration | Explicit on-device service, inspectable prompts/schemas, streaming and review | Apple also supports intelligent actions; this is not a unique AI capability |
| Action/content breadth | 64 kinds; Text/Number/Boolean/List/Dictionary | Apple's guide includes text, images, webpages and richer ecosystem integrations; standalone parity is absent |
| Apple integration | Delegates installed workflows through Apple's supported CLI | The delegated capability remains Apple's; it is not an independent superiority claim |
| Ecosystem convenience | Local Mac library and app-open triggers | Apple documents iCloud synchronization across devices; Studio has no iCloud/Siri/widgets/App Intents integration |
| Android control | Browser messenger, test relay and Mac grants implemented; no native APK | The companion can support cross-platform ownership; Android could also drive an authorized Mac CLI bridge, so this is not a new Apple engine primitive |
| Performance/reliability/usability | Named synthetic and live local checks | No matched benchmarks, representative user study, accessibility certification or production reliability data |

Apple references: [variables/content](https://support.apple.com/guide/shortcuts-mac/apdb5506f698/mac), [iCloud sync](https://support.apple.com/guide/shortcuts-mac/apdb3a4240b0/mac), [CLI](https://support.apple.com/guide/shortcuts-mac/apd455c82f02/mac), [intelligent actions on supported Apple devices](https://support.apple.com/guide/shortcuts/use-apple-intelligence-in-shortcuts-tpg3vrvwmclv/ios). Platform/version availability differs; the intelligence reference does not establish every Mac feature in every release.

## Where this implementation may be preferable

- A Swift developer wants to alter an action's behavior and write regression tests.
- A project needs its own data/action contract with explicit budgets and predictable storage commits.
- A maintainer wants guided generation tied to a catalog they control and can inspect.
- A future owner wants a narrowly authorized Android controller with explicit device/workflow grants.

Those are suitability arguments from the architecture, not measured wins. A user wanting broad Apple integrations, automatic device sync and polished system extensions will have reasons to prefer Apple's product today.

## How to establish an actual advantage

Use identical tasks and data, with Apple-only actions labeled delegated. Include pure pipelines, nested blocks, external apps/URLs, HTTP/files, import/recovery, unavailable permissions and model failures. Measure completion/correction effort, failure/recovery rate, latency distributions, memory/energy, accessibility task success and ongoing maintenance. Use independent fixtures and real users; publish OS/build/model availability and sample sizes.

Do not count two arithmetic/draft checks as general reasoning superiority. Do not count successful launch callbacks as verified webpage load. Do not claim NPU-only execution, total privacy, or cloud cost savings from selecting an on-device API. The present honest claim is: **a working, inspectable macOS workflow implementation with tested local examples and a documented extension path**.
