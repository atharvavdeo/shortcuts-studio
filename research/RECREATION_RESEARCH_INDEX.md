# Apple app recreation research

Updated: 13 October 2026. Current task: reverse-engineer and document behavior before choosing an implementation. Android is a later phase.

| Dossier | Evidence available | Verification boundary |
|---|---|---|
| [Shortcuts](SHORTCUTS_REVERSE_ENGINEERING.md) | Installed app, UI, CLI, metadata | Execution and serialization unresolved |
| [Pages](PAGES_REVERSE_ENGINEERING.md) | Official Mac behavior documentation | No installed app, native fixtures, or runtime |
| [Keynote](KEYNOTE_REVERSE_ENGINEERING.md) | Official Mac behavior documentation | No installed app, native fixtures, or runtime |
| [Numbers](NUMBERS_REVERSE_ENGINEERING.md) | Official Mac behavior documentation | No native formula/export results |
| [Image Playground](IMAGE_PLAYGROUND_REVERSE_ENGINEERING.md) | Installed app, UI, macOS 27 SDK, resources, official API/cloud documentation | No image request or transport trace |

Each dossier covers product behavior, proposed functional boundaries, data representation, compatibility boundaries, fault cases, unresolved questions, and source references. Proposed architecture is explicitly distinguished from recovered internals. Runtime fault matrices have not been executed.

The four new dossiers do not install apps, implement recreations, or claim complete parity. Their fault review is [FAULT_CHECK_REPORT.md](FAULT_CHECK_REPORT.md). The existing Shortcuts dossier remains the prior research artifact.

## Cross-product design proposal

Reusable components could include semantic text and object models, asset storage, undoable commands, schema migration, atomic save, format-specific exports, permission-aware collaboration, and an image-provider adapter. This is a proposal for our implementation; shared Apple private engines have not been established for the absent iWork binaries.

The hard contracts differ: Pages needs flow/pagination and fixed layouts; Keynote needs temporal builds and transitions; Numbers needs typed values, references, and recalculation; Image Playground needs asynchronous generation lifecycle and durable output. Choose a UI/runtime platform after fixing a finite supported contract for each.

## Next evidence prerequisites

Pages/Keynote/Numbers: a reference app session and controlled native/export fixtures. Their iCloud web clients can provide separate web observations but cannot qualify native behavior. Image Playground: controlled generation and callback experiments on the present app/SDK, with route evidence when available. Shortcuts: controlled synthetic workflow runs and export fixtures. These prerequisites explain what remains unverified; they do not prevent the documentation phase delivered here.

