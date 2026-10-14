# Investigation 1: Shortcuts target and prerequisites

Started only after checkpoint 7a45d545fc5f1b47baf3c42aa672e79e14107155 was successfully pushed. Studio was closed and is not launched by this static pass. Working checkout: this repository; the prior unrelated parent Git repository is untouched.

REA 6.5.0 was acquired through version-pinned npm execution. Node 22.22.3 satisfies its published range. Its bundled reverse-engineer-anything skill v42 is read. No MCP setup or agent registration was changed.

Actual REA Evidence records are retained under `rea-evidence/`, with identifiers in `index.json`. `inspect-artifact` completed an inventory substep; this establishes bounded bundle anatomy, not function behavior. `inspect-plist` reports com.apple.shortcuts, version 10.0, build 5037.0.19, with declared AppleScript support. `inspect-macho` identifies a selected arm64e slice, minimum macOS 27.0, SDK 27.0 and executable load metadata. Main executable SHA256: 2a3c512667ec596a00668e17845f0bf4cbba1e0407621a1cc85e8b1042356775.

Provider readiness confirmed Ghidra unconfigured, Hopper launcher absent, IDA unconfigured. Java 21.0.6 is installed. The official Ghidra 12.1.4 archive was acquired in ignored `.tools`; SHA256 ddac49f903da9d5bac833e5cc79395098b9c33cfd3279be5f31bd00387d2d4db matches the official release asset digest. The missing Mac ARM native decompiler was built from shipped source with two low-priority jobs and placed in the expected mac_arm_64 location. All nine scoped REA doctor checks now pass, including Java, version and native decompiler. Tooling is excluded from publication. A Ghidra inspect pass against the main executable has started. No Apple permissions or live message transmission occurred.

## Bounded reconstruction questions

- Where do a synthetic Text -> Show workflow's action parameters, identity and import questions serialize? Do not inspect personal workflow libraries.
- Which executable/framework boundaries dispatch action providers? Load metadata supplies candidate boundaries; decompilation must establish call sites before runtime claims.
- What does the native Mac client expose for automation editing versus the phone client? Mac observations do not prove Android/iPhone behavior.
- Where are cancellation, failed execution and action-result states represented? Correlate one harmless failure fixture with a trace.
- What system/API boundary provides location events and recipient-aware message delivery? No inference from framework presence alone.

Points 2–5 follow this evidence pass: public API contracts; shared device-specific rules; verified application adapters; real and synthetic event/delivery validation. No location or messaging capability has been implemented by this initial inspection.

## First boundary findings

The REA Mach-O record contains load declarations for WorkflowKit, ActionKit, WorkflowEditor, WorkflowUI, ContentKit, VoiceShortcutClient and public AppIntents. This makes framework dispatch a concrete next trace target, not a proven runtime call graph. The merged export inventory is explicitly incomplete for stripped binaries. Imported WorkflowUI symbols include OpenWorkflowOptions/ActionError-related names, which are candidates for error-path inspection; their names alone do not establish semantics.

Do not copy private-framework calls into the portable product. Recover contracts through bounded original-client fixtures, then implement supported public APIs or explicit Apple CLI delegation. A model router and generic AX text input are not substitutes for provider discovery, typed recipient parameters or execution receipts.
