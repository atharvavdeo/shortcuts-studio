# Pages: recreation dossier and fault plan

Date: 13 October 2026. Scope: macOS behavior research before implementation; Android follows later. Status: source-backed specification, not native binary recovery or runtime verification.

## Evidence and version

No Pages bundle was found under `/Applications`, `/System/Applications`, or `~/Applications`. This is a scoped installation check, not a search of every disk. Evidence: `evidence/iwork-installation-check.json`. Apple's current Mac guide identifies Pages 15.4 [P1]. No local version, exact interface geometry, executable dependencies, scripting dictionary, file encoder, or collaboration protocol has been measured. Official screenshots and instructions can establish documented behavior; they cannot establish private implementation.

Use four evidence labels throughout future work: DOCUMENTED for Apple statements, OBSERVED for measured behavior on a stated build, PROPOSED for our recreation design, and UNKNOWN for unestablished internals. The architecture and acceptance conditions below are PROPOSED unless a source is explicitly attached.

## Product boundary: how, why, when

DOCUMENTED: Pages combines templates, text formatting, object placement, publishing, review, and collaboration [P1]. Its defining distinction is between a word-processing document with body text that flows onto automatically created pages and a page-layout document with manually created pages and positioned text boxes [P2]. Reports and letters favor flow; posters and flyers favor placement. This distinction changes page insertion, deletion, anchoring, export, and selection behavior.

PROPOSED: represent document mode explicitly. A text editor with a decorative page background is insufficient because it lacks pagination, page objects, and the two lifecycles. A canvas alone lacks a flowing body story. Mode conversion must be a deliberate transformation with a recoverable history entry and a loss report for unsupported content.

## Behavior inventory and research scope

| Surface | Questions to recover | Proposed representation |
|---|---|---|
| Creation | Template selection, language/region, initial mode and styles | Template snapshot with mode and style definitions |
| Body editing | Selection, composition, paste, paragraphs, lists, links | Semantic text tree with character/paragraph runs |
| Layout | Margins, page size, sections, columns, headers/footers | Section settings and derived page layout |
| Text boxes | Independent stories, overflow, linked boxes | Story identity plus ordered frames |
| Objects | Crop, wrap, group, layer, lock, anchor | Object identity and transform independent of pixels |
| Tables/charts | Cell values, formula results, data references | Typed table/chart objects |
| Review | Comments, tracked changes, accept/reject | Anchored annotations and revision operations |
| Persistence | Save, autosave, reopen, versions, missing assets | Atomic snapshots, asset references, schema version |
| Sharing | Copy/export versus live shared document | Separate export and collaboration operations |
| Intelligent tools | Available editing/generation surfaces, subscription gates | Optional adapters with explicit availability |

This table is a research checklist. It does not claim all behavior has been recovered from the guide. Exact default styles, nested-object rules, keyboard behavior, typography, page-break heuristics, and malformed-file handling remain UNKNOWN.

## Text flow, objects, and layout

DOCUMENTED: in word-processing documents an object can remain at a page location or move with its text anchor. It can also sit inline. Wrapping includes around, above/below, inline, and none. Linked text boxes have restrictions: they must stay on the page and cannot be inline [P3].

PROPOSED implementation sequence: parse semantic content; shape text using the selected fonts and locale; compute line breaks; fit paragraphs into available regions; apply wrap exclusions and pagination constraints; place anchored objects; recompute affected regions; render selection and navigation overlays. Each step needs an explicit contract and a reference fixture. This is a plausible recreation pipeline, not recovered Apple code.

The main risk is a feedback loop: object placement changes available text width, which changes line breaks, which moves the anchor. The solver needs a convergence policy and a visible overflow state. A maximum iteration bound must report unresolved layout rather than hide text. Word-processing mode and page-layout mode should share object rendering while retaining different text/page ownership.

Store text and structure rather than screen coordinates for body content. Store positions for fixed frames. Maintain fonts, styles, asset IDs, and logical anchors separately from transient glyph bounds. Font substitution must trigger layout recomputation and a compatibility notice. Undo should reverse the semantic edit and recompute layout rather than depend on old viewport geometry.

## Review and collaboration

DOCUMENTED: Pages tracks changes in supported text locations and provides accept/reject controls. Hiding markup does not stop tracking. Tracking must be resolved before it is turned off. Apple's guide says Pages for iCloud becomes view-only for a shared document with change tracking enabled [P4].

DOCUMENTED: Pages shares documents through iCloud with access and editing permissions [P5]. This does not reveal whether Apple uses CRDTs, operational transformation, a particular transport, or a private serialized operation format.

PROPOSED: comments need stable anchors, author metadata, and resolution state; revisions need explicit insertion/deletion history and acceptance state. Collaboration must validate permissions on the server, handle stale clients, and preserve undo ownership. A visible collaborator cursor does not establish conflict correctness. Measure simultaneous edits, reconnect, revoked access, and conflicting revisions before claiming parity.

## Files and export

DOCUMENTED: export creates a copy without changing the original. TXT includes body text and excludes objects; page-layout documents cannot export as TXT. RTF/RTFD also has mode and object restrictions. Smart annotations do not survive every export format [P6].

UNKNOWN: native `.pages` object serialization, encryption, object IDs, compression, archive entry rules, and migration are not inspected. Do not assume renaming a ZIP or writing a PDF produces an editable native file. PDF visual fidelity, DOCX editability, and native-format round-trip are separate qualification targets.

PROPOSED export adapter contract: validated semantic snapshot; explicit target format/options; feature coverage report; output path; warnings; and durable success only after the artifact is written and reopened by an independent compatible consumer. Test text extraction as well as appearance. Render-only similarity can conceal missing tables, links, accessibility tags, and reading order.

## Calls and dependencies

No native Pages call graph or endpoint list is available from this host. Proposed functional seams are `openDocument`, `applyEdit`, `layoutAffectedRegion`, `saveSnapshot`, `exportCopy`, and `applyRemoteOperation`; these are design names, not Apple's APIs. Each mutation should validate document mode, permissions, references, and asset availability before committing.

REA can later inventory an obtained app bundle, identify its executable and frameworks, and inspect selected code using a supported provider. Native app access or sample files are prerequisites for runtime/binary claims. Pages for iCloud can support web behavior research, but it is a different client and must not be treated as proof of native behavior.

## Fault matrix: acceptance conditions to execute later

| Fault/fixture | Proposed acceptance condition | Evidence needed |
|---|---|---|
| Long paragraph plus image anchor | No missing or duplicate text; stable wrap after reflow | Before/after render and text inventory |
| Missing font | Substitution reported; layout stays editable | Font map, page count, glyph bounds |
| Page break/section deletion | Content movement follows mode; undo restores | Semantic diff and render |
| Linked-frame overflow | Overflow remains detectable; order is preserved | Full story extraction and frame mapping |
| RTL, emoji, CJK, combining marks | Caret/selection do not split graphemes incorrectly | Input and selection traces |
| Tracked insertion/deletion | Accept/reject preserves correct text | Revision and reopened document diff |
| PDF/DOCX/TXT export | Target-specific loss disclosed | Independent consumer comparison |
| Interrupted save/disk full | Previous valid file remains recoverable | Failure injection and reopen |
| Missing media | Placeholder and repair path; no silent deletion | Asset inventory |
| Two clients edit same span | Deterministic convergence or explicit conflict | Paired session logs |
| Permission revoked while open | Unauthorized writes stop | Server-side access result |
| Corrupt/unsupported document | Readable failure; no partial destructive save | Parser diagnostics |

Runtime status for every row: NOT EXECUTED. First parity slice: one flowing report, one fixed-layout flyer, one anchored-image case, one tracked-change case, and PDF/DOCX exports. Expand only after native reference fixtures exist.

## Fault check of this dossier

Confirmed documentary distinctions: two modes, anchor/wrap rules, review behavior, iCloud collaboration, export losses. Confirmed local fact: bundle absent in checked roots. Explicitly unresolved: native UI measurements, binary architecture, native file grammar, private calls, and actual fault outcomes. No implementation or tests have passed because no recreation has been implemented.

## Sources

- [P1 — Pages Mac guide, current guide identifies 15.4](https://support.apple.com/guide/pages/welcome/mac)
- [P2 — Word processing and page layout](https://support.apple.com/en-euro/guide/pages/tan6129a1862/mac)
- [P3 — Object anchoring and text wrapping](https://support.apple.com/en-euro/guide/pages/tand6205cf6d/mac)
- [P4 — Track changes](https://support.apple.com/en-euro/guide/pages/tan2685b84ff/mac)
- [P5 — Collaboration](https://support.apple.com/en-euro/guide/pages/tan72489eaa/mac)
- [P6 — Export contracts](https://support.apple.com/guide/pages/export-to-word-pdf-or-another-file-format-tance1161f26/mac)

