# Keynote: recreation dossier and fault plan

Date: 13 October 2026. Scope: macOS reference research before choosing implementation. Android follows later. Status: documented behavior and proposed reconstruction contracts; no native runtime or binary verification.

## Evidence and version

No Keynote bundle was found in the three common app roots checked; see `evidence/iwork-installation-check.json`. Apple's current Mac guide identifies Keynote 15.4 [K1]. No executable, theme package, scripting dictionary, native presentation, or native playback trace has been inspected. Web-client behavior cannot establish native playback timing or format compatibility.

Evidence labels: DOCUMENTED means a cited Apple source; PROPOSED means a design or acceptance condition; UNKNOWN means unavailable evidence. No fault row below represents a passed test.

## How, why, and when

DOCUMENTED: Keynote starts presentations from themes and slide layouts, supports positioned objects and media, animations, presentation modes, and collaboration. The current guide also advertises Creator Studio features including slide cleanup and generated presenter notes [K1].

PROPOSED: the product has three coupled responsibilities: semantic slide authoring, time-based playback, and export. A slideshow of flattened images covers only a small output subset. Preserving editable text, object identity, timing, and presenter information requires an underlying model. Theme/layout editing is valuable when a deck needs consistent updates; object animation is valuable when sequence explains the content; presenter view is valuable when audience and speaker need different information.

## Behavior inventory

| Surface | Research questions | Proposed model |
|---|---|---|
| Theme chooser | Layout variants, placeholder inheritance, localization | Theme and reusable layout definitions |
| Slide navigator | Insert, duplicate, reorder, group, skip | Ordered stable slide identities |
| Canvas | Selection, snap guides, z-order, transform, groups | Scene graph with semantic text and assets |
| Inspector | Context-sensitive format versus animation controls | Selection-specific property editor |
| Builds | Build in/action/build out; timing and dependencies | Event graph separate from object geometry |
| Transition | Duration, direction, trigger, cross-slide matching | Transition definition on a slide boundary |
| Presentation | Advance, back, jump, pause, restart, links | Playback state machine |
| Presenter display | Notes, timing, next slide, audience separation | Independent presenter/audience render surfaces |
| Media | Video/audio/live input/recorded narration | Media clocks and availability states |
| Export | Editable PPTX, static PDF, timed movie, GIF/HTML | Format-specific conversion contracts |
| Sharing | Copy versus live edits and presenter roles | Permissions and synchronized state |

The table is a proposed research inventory, not evidence that every listed rule has been experimentally measured. Visual measurements, exact shortcuts, defaults, rendering and audio scheduling remain UNKNOWN.

## Object identity and Magic Move

DOCUMENTED: Magic Move links the visual change of common objects across two slides. Apple's recommended method duplicates a slide and then changes the objects. Objects absent on the second slide fade out; new objects fade in [K2]. The source also exposes text matching and timing options.

PROPOSED: preserve object identities when duplicating a slide, with separate per-slide geometry. Matching by nearest position or text alone can animate the wrong object when a slide contains duplicates. Apple's exact correspondence algorithm, tie-breaking, easing curves, and intermediate rendering remain UNKNOWN.

Reference fixtures should isolate movement, scale, rotation, cropping, text change, changed group membership, duplicate-looking objects, removed objects, and reversed playback. Record the matching pairs and frames at fixed timestamps. Pixel comparison needs aligned capture dimensions and fonts; playback frame drops must not be mistaken for the intended easing curve.

## Timeline and scheduling

DOCUMENTED: build order may interleave objects. Start options include After Transition, On Click, With Build, and After Build, with delays where supported [K3]. Some adjacent builds cannot run together. These are dependencies, not merely a list of animation names.

PROPOSED scheduler: a click or transition event releases eligible build groups; a monotonic clock determines animation progress; completed builds release dependent groups; media events and navigation can interrupt playback. Store duration, delay, trigger, target identity, and dependency in the model. Reject invalid dependencies and dangling object references.

A single deterministic timeline representation should feed rehearsal, presentation, and movie export. Interactive playback can accept user input while movie export resolves click events into chosen timings. This design is an inference for recreation, not a recovered Apple engine. It prevents separate exporters from silently changing the authored sequence.

## Export and format boundaries

DOCUMENTED: Keynote exports copies to PPTX, PDF, movie, images, GIF, and HTML; the original is unaffected. PDF can include build stages, notes, and skipped slides. Movie export has playback/timing choices. HTML export includes animations/builds [K4]. GIF export offers slide ranges, resolution, frame rate, and auto-advance timing [K5].

PROPOSED qualification: validate editable PPTX separately from appearance-only export. Unsupported effects need a loss report rather than a silent approximation. Inspect text, slide order, hyperlinks, notes, charts, and media relationships after round-trip. For movie/GIF compare event timing as well as individual frames. A PDF cannot establish animation parity.

UNKNOWN: native `.key` serialization, theme/asset internals, private rendering APIs, code paths, and collaboration network protocols. No speculative ZIP/IWA/Protobuf grammar is presented as recovered evidence.

## Calls and execution seams

Proposed calls include `applySlideEdit`, `resolveLayout`, `scheduleBuildGroup`, `advancePresentation`, `renderFrame`, `saveSnapshot`, and `exportPresentation`. These are our functional boundaries, not Apple's symbol names. Commands should work on semantic state and produce undoable edits; render surfaces should consume that state.

REA can later inventory a Keynote bundle and trace selected functions from an authorized native artifact. Controlled fixture exports can answer much more about behavior than searching unrelated strings. Multi-presenter collaboration and remote controls need paired-device evidence; they cannot be established on one unavailable app.

## Fault matrix

| Fault/fixture | Proposed acceptance condition | Measurement |
|---|---|---|
| Duplicate/reorder/delete slide | Links/build targets stay valid; undo restores | Semantic identities before/after |
| Duplicate-looking objects in Magic Move | Matching is explainable and stable | Matched IDs plus reference frames |
| Build with missing target/dependency cycle | Explicit diagnostic; playback does not hang | Scheduler trace |
| Rapid next/back during build | No orphan effects; known slide state | Input/event/frame timestamps |
| Missing video or unsupported codec | Recoverable placeholder or clear failure | Asset/decoder result |
| Long narration/video drift | Defined audio/video synchronization tolerance | Media clock comparison |
| Font substitution | Text remains editable; overflow disclosed | Font map and bounding boxes |
| External display disconnect | Audience/presenter states recover | Display-event trace |
| PPTX round-trip | Unsupported behavior reported; content retained | Reopened deck object inventory |
| Movie versus live playback | Same authored event ordering | Timeline comparison |
| Interrupted export/disk full | No success claim for truncated file | Output verification |
| Concurrent object delete/edit | Defined conflict behavior | Two-client traces |

All runtime fault checks: NOT EXECUTED. Recommended first reference corpus: three slides, theme placeholders, one text object, one image, a Magic Move pair, sequential and simultaneous builds, notes, and PDF/PPTX/movie exports. This corpus defines a manageable parity claim; it does not qualify the entire product.

## Fault check of this dossier

Verified in primary sources: theme/layout authoring, Magic Move's documented visual behavior, build dependencies, and export choices. Verified locally: absence in checked roots. Not verified: native execution, internal correspondence algorithm, exact frame behavior, private calls, collaboration convergence, or export fidelity. Native reference availability is the next evidence prerequisite.

## Sources

- [K1 — Keynote Mac guide, 15.4](https://support.apple.com/guide/keynote/welcome/mac)
- [K2 — Transitions and Magic Move](https://support.apple.com/guide/keynote/add-transitions-tanff5ae749e/mac)
- [K3 — Build order and timing](https://support.apple.com/guide/keynote/change-build-order-and-timing-tan3ad5f8d82/mac)
- [K4 — Export formats and settings](https://support.apple.com/en-lamr/guide/keynote/tana0d19882a/mac)
- [K5 — GIF export](https://support.apple.com/en-gb/guide/keynote/tan30ff1f63c/mac)

