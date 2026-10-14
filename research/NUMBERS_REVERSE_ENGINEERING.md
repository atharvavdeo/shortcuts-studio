# Numbers: recreation dossier and fault plan

Date: 13 October 2026. Scope: macOS reference behavior and proposed architecture; implementation and Android translation follow later.

## Evidence and version

No Numbers app bundle was found in `/Applications`, `/System/Applications`, or `~/Applications`; the scoped record is `evidence/iwork-installation-check.json`. Current canonical guide/get-started sources identify Numbers 15.4 [N1, N2]. A regional guide result identified 15.3 during this research. Guide versions are source-specific; no installed Numbers version is established.

No native file, formula engine, binary, UI session, or numerical result has been measured. DOCUMENTED claims cite Apple; PROPOSED contracts and fault expectations are our design; UNKNOWN identifies gaps. The matrix is a validation plan, not a completed test suite.

## How, why, and when

DOCUMENTED: Numbers organizes spreadsheets into sheets containing movable tables and other objects. A sheet can contain multiple tables. Templates establish a starting arrangement. Formula cells, categories, filters, pivots, and charts support analysis [N1, N3, N4].

PROPOSED: model a sheet as a canvas containing named tables, rather than treating a sheet as one infinite grid. Small independent tables support readable dashboards and reports, but create identity/reference problems across tables. Cell editing, table-object selection, and sheet-object editing require separate focus states. The active table cannot be inferred from the visible sheet alone.

## Behavior inventory

| Surface | Research questions | Proposed representation |
|---|---|---|
| Template/sheet setup | Language/region, style, dimensions | Workbook settings and sheet IDs |
| Table canvas | Move, resize, rename, lock, selection | Table identity, geometry, rows/columns |
| Cell editor | Raw input, rich content, controls, commit/cancel | Typed cell value and independent editor buffer |
| Formula editor | Parse, reference picker, relative/absolute rules | Formula syntax tree and resolved references |
| Formatting | Number/currency/date/duration, locale | Display format separate from stored value |
| Structure | Insert/delete/move rows, merge, headers/footers | Structural operations with reference updates |
| Organization | Sort/filter/category operations | View state distinguished from source structure |
| Pivot | Fields, groups, aggregation, refresh | Source snapshot plus refresh state |
| Chart | Source references, series, visible/category data | Chart model linked to selected ranges |
| Files/export | Native save, XLSX, CSV/TSV, PDF | Target-specific mapping and loss report |
| Intelligent fill | Suggestions, accept/reject, availability | Optional proposal flow separate from formulas |
| Collaboration | Concurrent cell/structure edits | Permissions and operation conflict rules |

Exact UI defaults, complete function set, sorting/coercion/error precedence, and private computation implementation remain UNKNOWN.

## Formula semantics and reference identity

DOCUMENTED: formulas can reference cells, ranges, entire rows/columns, other tables, and other sheets. The editor presents formula errors and links to causative cell references. Apple's Mac guide notes a categorized-table range may not automatically include a newly inserted row [N5].

PROPOSED formula engine: tokenize locale-aware input; parse an AST; resolve sheet/table/row/column identities; construct dependency edges; detect cycles; evaluate affected cells; retain typed results and errors; then apply display formatting. Keep a formula's authored text, semantic reference, evaluated value, and display string distinct.

Do not use host-language `eval` for user formulas. A grammar and function registry allow deterministic errors, finite resource limits, and compatibility tests. A circular-reference policy needs an explicit documented failure; no iterative-calculation capability is assumed. Precise rules for empty cells, strings, booleans, dates, durations, and floating-point edge cases require fixtures.

Proposed structural edits use stable identities so renaming a table does not sever references. Copy/fill behavior transforms relative reference offsets while preserving absolute components. Insert/delete behavior is a separate transformation, not the same rule as copy/fill. Apple's exact internal identity schema is UNKNOWN.

Avoid claiming a fixed function count: one official help source says more than 300 functions, while another formula page says more than 250 [N5, N6]. Build a versioned function inventory when the reference app becomes available. Declare the supported subset individually instead of inheriting either approximate total as a compatibility guarantee.

## Recalculation, charts, and pivots

DOCUMENTED: charts update when their source table data changes [N7]. Pivot tables require refresh after source changes [N8]. Pivot source constraints include needing non-header data and not having cells merged across adjacent rows [N9]. These are different update contracts.

PROPOSED: cell results carry a recalculation revision; charts identify their source range and revision; pivots retain a source/refresh revision and display stale state until refreshed. A recalculated formula must not imply a pivot refresh. A chart tied to a pivot can be current relative to the pivot while the pivot itself is stale relative to its source.

Sort/filter/category operations need fixtures to distinguish view rearrangement from movement of cell identities. Test whether summaries and charts include hidden, filtered, or collapsed data; use each feature's documented rule and direct observation rather than imposing one global rule.

## Export and compatibility

DOCUMENTED: Excel export can map each table or each sheet to worksheets. CSV/TSV export can create separate table files or combine tables. CSV exports cell contents as values [N10]. These choices expose the mismatch between Numbers' canvas model and a conventional worksheet grid.

PROPOSED: conversion should publish the mapping, preserve names where possible, and disclose formula/style/object losses. CSV parity is about values, quoting, delimiters, encoding, locale, and table boundaries; it cannot preserve editable formula graphs or charts. XLSX parity requires an independent consumer to recalculate supported formulas and inspect references. A cached number in a generated workbook is not proof its formula works.

UNKNOWN: native `.numbers` archive/object format, internal formula opcodes, encryption, migration, cloud merge protocol, and data-provider calls. No file-format grammar or private endpoint is claimed to be recovered.

## Calls and execution seams

Proposed boundaries: `commitCellEdit`, `resolveFormula`, `recalculateAffectedCells`, `applyStructuralEdit`, `refreshPivot`, `updateChart`, `saveSnapshot`, and `exportWorkbook`. These are recreation design names. Mutations should validate table identity, type/format, reference integrity, permissions, and resource limits.

REA can help inspect an authorized native bundle and selected functions later. External spreadsheet libraries can aid a recreation, but success in another engine does not establish Numbers semantics. Web Numbers can provide separate client observations if accessed later; no iCloud login or document access occurred in this pass.

## Fault matrix

| Fixture/fault | Proposed acceptance condition | Measurement |
|---|---|---|
| Cross-table/sheet reference plus rename | Reference retains intended target | Semantic reference and value diff |
| Copy/fill mixed absolute references | Expected offsets preserved | Formula AST/reference comparison |
| Insert/delete/move referenced rows | Defined reference adjustment; no silent target shift | Identity trace |
| Cycle, divide by zero, invalid type | Deterministic visible error | Error category and propagation |
| Blank versus empty string versus zero | Documented coercion for each function | Frozen input/result corpus |
| Locale decimal/date ambiguity | Stored type and display are distinguishable | Parse/format round-trip |
| Large fan-out dependency graph | Bounded calculation; no stale success | Dirty/revision trace |
| Source changes without pivot refresh | Stale pivot remains identifiable | Source and refresh revision |
| Filter/collapse chart source | Selected-series rules reproduced | Range inventory and plotted points |
| XLSX round-trip | Supported formulas independently recalculate | Reopen in reference/consumer |
| CSV embedded commas/newlines | Correct value and encoding round-trip | Parsed output cells |
| Two-client row-delete/formula edit | Defined conflict behavior | Paired operation logs |
| Interrupted save | Prior valid workbook remains recoverable | Failure injection and reopen |

All runtime checks: NOT EXECUTED. First reference slice: two sheets, multiple tables, cross-table formulas, copied references, locale formats, a chart, a stale/refreshed pivot, and XLSX/CSV exports. Each function needs expected values from the reference app before numerical parity can be claimed.

## Fault check of this dossier

Checked contradictions: guide-version differences and approximate function counts are explicitly retained; automatic chart update is not conflated with pivot refresh; sheet/table mapping is explicit. Installed-app absence is scoped to searched roots. Neither formula correctness nor file compatibility has been runtime verified.

## Sources

- [N1 — Numbers Mac guide](https://support.apple.com/guide/numbers/welcome/mac)
- [N2 — Get started, version requirements](https://support.apple.com/guide/numbers/get-started-with-numbers-tan398cb0564/15.4/mac/1.0)
- [N3 — Multiple tables on a sheet](https://support.apple.com/guide/numbers/add-or-delete-a-table-tandfc7ebc28/mac)
- [N4 — Create a spreadsheet](https://support.apple.com/guide/numbers/create-a-spreadsheet-tanc33201f3f/mac)
- [N5 — Formula editor and references](https://support.apple.com/en-ae/guide/numbers/tan727173a8/mac)
- [N6 — Function help](https://support.apple.com/en-lamr/guide/numbers/tana56212d7c/mac)
- [N7 — Chart data updates](https://support.apple.com/guide/numbers/select-data-to-make-a-chart-tan1c3c6123b/mac)
- [N8 — Explicit pivot refresh](https://support.apple.com/guide/numbers/refresh-a-pivot-table-tanaac8c7972/mac)
- [N9 — Pivot source constraints](https://support.apple.com/guide/numbers/create-a-pivot-table-tan7f62056cf/15.4/mac/1.0)
- [N10 — Export mappings](https://support.apple.com/en-gb/guide/numbers/tan3b922d4ad/mac)

