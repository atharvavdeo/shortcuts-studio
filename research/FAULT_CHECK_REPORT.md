# Research fault review

Date: 13 October 2026. Scope: the four added dossiers, their source claims, local evidence, and document integrity. This is a documentation review, not runtime qualification of recreated apps.

## Corrections and discrepancies preserved

| Potential false claim | Evidence reviewed | Correct treatment |
|---|---|---|
| All four apps are absent | Common roots and installed bundle inventory | Image Playground is installed; iWork absent in checked roots |
| Image Playground is always on-device | WWDC24 versus WWDC26 | Versioned historical local and current PCC descriptions |
| ImageCreator works headlessly on OS 27 | SDK deprecation plus initializer documentation | Deprecated; documented notSupported boundary, not locally exercised |
| AsyncSequence is partial-pixel streaming | CreatedImage declares cgImage; API describes image delivery | Only asynchronous image results established |
| UI SDK exposes a generation progress stream | Completion/cancellation/glyph declarations | No such public progress stream established |
| Animation style means animated file | Style name only | Do not infer motion/video output |
| Requested size is exact | `closest(to:)` declaration | Actual dimensions must be recorded |
| Static latency 60 is measured seconds | Private plist has estimated_latency integer | Units and guarantee unknown; no measured latency |
| WWDC sample availability name matches SDK | Scoped SDK search | supportsImageGeneration/supportsImagePlayground mismatch flagged |
| All cloud paths have PCC guarantees | PCC source and ChatGPT source | External provider treated separately |
| Pages has one text/document model | Apple's document-mode guide | Body-flow and page-layout modes distinct |
| Numbers sheets equal single tables | Apple's table guide | Multiple tables per sheet |
| Pivot always reflects current source | Pivot refresh guide | Explicit refresh contract |
| Numbers has one verified exact function count | Approximate counts differ across sources | No exact compatibility total claimed |
| Exported copy proves full native compatibility | Target-specific export documentation | Qualification split by format and editable/visual behavior |
| Live collaboration reveals Apple's merge algorithm | Public behavior only | Protocol and convergence implementation unknown |

## Checks actually performed

Read official Apple support/developer/security sources. Read installed Image Playground Info.plist and executable dependency declarations. Read and preserve its public macOS 27 SDK interface. Inspect provider/style resources and preserve hashes/paths. Observe the empty gallery and generation editor without submitting a request. Check three common application roots for iWork bundles. Review each dossier's evidence/proposal separation and fault matrices. Document-integrity results are saved separately in `evidence/research-document-integrity.json`.

## Evidence not available

No Pages/Keynote/Numbers app sessions or native files; no native decompilation; no Image Playground generation; no network capture, private payload or endpoint recovery; no runtime callback harness; no measured cloud-routing, quality, quota, latency or fault result. Therefore “everything verified” would be unsupported. All proposed fault rows are explicitly NOT EXECUTED.

## Qualification gate for future implementation

Freeze a reference version and a fixture corpus; reproduce a finite supported behavior set; inspect independently reopened/exported results; compare semantic content as well as visuals; execute stated fault scenarios; preserve unresolved differences; and state the exact tested scope. A document-link check or API declaration does not substitute for those gates.

