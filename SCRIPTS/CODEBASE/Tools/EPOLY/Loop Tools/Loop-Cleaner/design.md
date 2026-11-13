# Loop-Cleaner Design

## Clean rewrite status

- `Loop-Cleaner.ms` is the canonical clean rewrite development file and currently carries version `1.218`.
- The canonical Drive file keeps its existing file ID and filename; version identity is stored inside the script rather than by creating duplicate release copies.
- File version, stored project version, and visible title version are one identical version number.
- `1.214` is the user-confirmed stable reference for the `T BORDER HOLES SELECT \ FIX` production control. `1.212` introduced redraw/rebind optimization, `1.213` removed duplicated first-cycle Broken-T detection, `1.214` optimized Edit Poly topology construction plus Broken-T candidate discovery, `1.215` finished the redundant non-destructive analysis pass, `1.216` reduced Listener and child-edge lookup overhead, `1.217` locks the active Broken-T node/modifier/sub-object state whenever it is already correct, and `1.218` leaves all successfully repaired preserved T-junction vertices selected after a successful RMB repair while preserving `1.214` as the stable checkpoint.
- Regression edge/vertex IDs belong only in the separate test harness. Production detection must never depend on fixed scene IDs.

## Production redundant-loop detection

`SELECT | REMOVE` uses one direct subtraction pipeline. The restored border-corner and wall-corner routines are classification masks, not post-validation stages.

1. **VISIBLE / SELECTABLE DOMAIN**
   - Start from edges whose Editable Poly edge-visibility flag is visible and whose current Editable Poly state can actually store/select them.
   - Hidden/unselectable edges are excluded before topology classification.

2. **BORDER MASK**
   - Detect true mesh border edges from the polygon topology.
   - Subtract those border edges from the visible/selectable domain.

3. **BORDER-CORNER LOOP MASK**
   - Run the restored working border-corner loop classifier/tracer on the remaining internal visible edges.
   - Reuse that established helper behavior unchanged.
   - The production pipeline does not add a second border-terminal or border-angle validator after this mask is built.

4. **WALL-CORNER LOOP MASK**
   - Run the restored working wall-corner loop classifier on the same internal visible edge domain.
   - Reuse the existing fixed adjacent-face-plane classification used by the restored helper.

5. **FINAL RESULT**
   - `redundantEdges = visibleSelectableEdges - borderEdges - borderCornerLoopEdges - wallCornerLoopEdges`
   - No candidate-chain construction, `rejectBorder`, terminal validation, degree validation, or user `ANGLE` validation participates in the production result.
   - LMB stores the exact remainder in the dedicated `SELECT REDUNDANT LOOPS` Edit Poly.
   - Zero-result runs do not create a new selector; an existing exact selector is cleared.
   - RMB removes exactly the stored selector BitArray with `#RemoveEdgeRemoveVertices` and verifies topology reduction before renaming it `DELETED REDUNDANT LOOPS`.

## Topology source

- Analyze the current poly domain first.
- Current `Edit_Poly`: use `EditPolyMod` geometry queries.
- Base `Editable_Poly`: use `polyop`.
- Before any base `Editable_Poly` stage reads vertex/edge/face IDs, check `polyop.getHasDeadStructs`.
- If dead topology exists, call `polyop.collapseDeadStructs` before reading or caching any component IDs, then read fresh topology.
- Do not run `collapseDeadStructs` on the base object underneath an active `Edit_Poly`; reject that bridge instead of silently reindexing topology below the modifier.
- If a disposable fallback is ever required, it must stay polygonal; never use `snapshotAsMesh` / TriMesh for production polygon detection.
- Do not collapse/convert/retriangulate the user's geometry for detection; `collapseDeadStructs` is allowed only as the explicit dead-index data cleanup above.
- Keep the Editable Poly / Edit Poly API split strict.

## Border selection contract

- `BORDER ALL` selects every current true mesh border edge that is visible/selectable.
- `OUTER` and `INNER` first split true border edges into connected boundary components.
- Polygon face connectivity splits the mesh into connected surface shells.
- On each connected surface shell, the border component with the greatest exact world-space perimeter is the outer border.
- Every other border component on that shell is an inner-hole border.
- All three modes share one dedicated Edit Poly named `SELECT BORDERS`; switching modes replaces only that selector's Edge BitArray and does not overwrite `SELECT REDUNDANT LOOPS`.
- Border classification uses complete border topology, then intersects the requested result with the current visible/selectable edge domain before writing selection.


## T-junction loop selection contract

- `T JUNCTIONS` selects all visible/selectable internal loop paths traced from exact T-junction stems.
- An exact T-junction vertex has exactly three incident live topology edges, exactly one perfectly collinear opposite edge pair, and one remaining non-border stem edge.
- No angular tolerance, epsilon, rounding, or hidden threshold is used to decide whether the through pair is straight.
- T-junction classification uses complete live polygon topology; only the final traced edge selection is limited to the current visible/selectable domain.
- Tracing starts from the T stem. At another exact T junction, arrival through its stem terminates the trace; arrival on its straight-through pair continues across the other through edge.
- At every ordinary non-T vertex, continuation is topology-only: the next edge must be the single current candidate edge that shares no polygon face with the incoming edge. If there is no such edge or more than one, tracing stops.
- T-junction tracing must never resolve an ambiguous ordinary-vertex continuation by edge ID, iteration order, geometric score, or a permissive fallback threshold. Equivalent topology must produce the same path classification independent of component numbering.
- `T BORDER` first detects the complete broken inner-border components with the selected `postion preccision` value, then finds exact T-junction vertices associated with those broken border runs. It selects only each qualifying vertex's T-stem edge, never the parallel continuation along the border or traced loop.
- The intended contract includes T junctions on the first or last edge of a broken inner-border run, but this endpoint case is still not reliable in the current build and is tracked in `known-issues.md`.
- The T-stem is the existing exact T-junction third edge: the non-border edge left after the one perfectly collinear through pair is identified. No new angle tolerance, epsilon, edge-ID rule, or scene-specific component ID is introduced.
- `T MESH` keeps complete traced T-junction loops only when the traced loop contains no `T BORDER` stem edge.
- All three modes share one dedicated Edit Poly named `SELECT T JUNCTIONS`; switching modes replaces only that selector's Edge BitArray and does not overwrite `SELECT BORDERS` or `SELECT REDUNDANT LOOPS`.

## Broken inner-border T-junction staged repair contract

- `T BORDER HOLES SELECT \\ FIX` is the production Broken-T control. LMB is the non-destructive detector: it classifies broken inner-border components with the selected `postion preccision` value and stores the visible/selectable result in the dedicated reusable `SELECT BROKEN T JUNCTIONS` Edit Poly. RMB refreshes that same selection first, then runs the complete batch repair.
- `DIVIDE EDGE` is stage 1 of the split repair workflow. If the selector does not exist yet, it runs the same Broken-T selection first.
- Stage 1 captures missing opposite targets before topology changes and preserves each source's original target edge ID plus the two endpoint vertex IDs. Sources are grouped by that exact original target edge ID, never by rounded/precision-quantized endpoint positions.
- For each group, the first split uses the exact target edge ID captured by the detector and confirms its preserved endpoint vertex IDs. The stage performs exactly `N` committed `DivideEdge` operations for `N` required inserted vertices. After every split, the old edge ID is discarded and the remaining child segment is resolved from the exact pair `(newly appended vertex ID, untouched far endpoint vertex ID)`.
- Every split must add exactly one live vertex. The `DivideEdge` return value is never treated as a vertex ID. Source vertices and appended vertices are ordered along the same preserved original edge direction, producing transient `#(sourceVertexID, insertedVertexID)` move pairs.
- `DIVIDE EDGE` stops there: it does not call `MoveSelection` and it does not weld. If a later independent target group fails after one or more earlier groups already completed, every successfully produced source/inserted pair remains stored as the pending move handoff even though the Divide action itself still reports failure.
- `MOVE VERTICES` consumes the pending `#(sourceVertexID, insertedVertexID)` pairs. For each pair it activates the working `Edit_Poly` in Vertex context, isolates only the inserted vertex, reads both live positions, runs `MoveSelection (sourcePosition - insertedPosition) -> Commit`, and verifies the inserted vertex reaches the source at the explicit `postion preccision`.
- `BATCH BROKEN T FIX` reuses the exact `SELECT BROKEN T JUNCTIONS` modifier for the complete repair. The 1.203 and 1.209 runtime failures (`GetNumVertices == 0` after Divide) proved that a full same-modifier rebind must remain available after topology commits. `1.217` changes that boundary from unconditional UI churn to verified recovery: the current node/modifier/Vertex state is kept untouched and a live vertex-count probe is attempted first. If that probe is stale, the tool retries after `RefreshScreen()` / `update node` without changing the active node/modifier/level; `modPanel.setCurrentObject` is called only if that state-preserving refresh still cannot expose the expected live topology. The fallback rebind still performs the proven full binding sequence before IDs are read again.
- `1.213` keeps the initial Broken-T selection analysis alive only across the selection-only boundary before the first Divide cycle. `fixTBorderHoles()` receives the exact topology snapshot, case records, and position precision that produced `SELECT BROKEN T JUNCTIONS`, and the first Divide cycle reuses them instead of rebuilding topology and finding the same cases again. Reuse is allowed only when the working Edit Poly still reports the same live vertex, edge, and face counts; otherwise the old fresh-build/fresh-detect path is used.
- The first `DivideEdge -> Commit()` invalidates that precomputed analysis. Every later Divide cycle after any topology change rebuilds live Edit Poly topology and reruns Broken-T case detection from scratch; no vertex/edge/face IDs are cached across a topology-changing commit.
- `getBrokenTJunctionBorderSelection()` classifies border topology once and passes the resulting inner-border Edge BitArray into `findBrokenTJunctionCases()`. The case finder still classifies on its own when called without a preclassified inner-border set, so unrelated callers keep their previous behavior.
- `1.214` keeps the same `buildEditPolyBorderTopology()` result layout but replaces global `edge_keys` string scans with per-vertex neighbor/edge lookup tables. Duplicate endpoint edges still abort, and each face boundary pair still resolves to one exact native Edit Poly edge ID before adjacency is accepted.
- `1.214` replaces the Broken-T `innerVertices × innerEdges` brute-force candidate loop with a conservative sweep-line broad phase. The sweep axis is the largest inner-border coordinate extent; target edge intervals are expanded only by the existing explicit `position_tolerance`, and full XYZ tolerance-expanded bounds are checked before the unchanged exact point-to-segment projection and parallel-source-edge tests.
- The sweep broad phase cannot create or reject a case by itself: every accepted case still passes the same exact downstream geometry tests and the same nearest-distance / shorter-target tie rule. Final case records are rebuilt in ascending source-vertex order, and candidate target edges remain processed in ascending edge-ID order so repair ordering stays compatible with the previous detector.
- `1.215` reuses one connected border-component Array inside the Broken-T border-analysis path instead of rebuilding the same components once for classification and again for broken-component expansion. `classifyBorderEdges()` keeps its existing five-field caller contract, and `getBrokenTJunctionBorderSelection()` keeps its existing three-field caller contract through internal reuse helpers.
- `1.215` also builds the current inner-border Edge BitArray and inner-border Vertex BitArray once per insert-plan topology snapshot. Every case reuses those exact sets when resolving an already-existing opposite vertex, so full border classification is no longer repeated once per Broken-T case and non-inner mesh vertices are never scanned as weld-target candidates.
- The initial non-destructive Broken-T selection now carries its already-classified inner-border Edge/Vertex BitArrays alongside the precomputed topology/cases into the first Divide cycle when the existing live-count reuse check succeeds. Later fresh batch cycles likewise pass their newly classified inner-border sets into the insert-plan stage. These sets are valid only before the next `DivideEdge`; the first topology-changing commit invalidates them with the rest of that cycle's topology snapshot.
- Border component ordering, outer/inner classification, existing-target ambiguity behavior, source/target case order, explicit position precision, and every Divide/Move/Weld synchronization boundary remain unchanged in `1.215`.
- `1.216` changes exact vertex-pair edge re-resolution to query native `Edit_Poly.GetVertexEdgeCount` / `GetVertexEdge` adjacency from the first endpoint before scanning the complete edge domain. Every candidate is still verified by exact endpoint vertex IDs; one unique local match returns immediately, multiple local matches remain ambiguous and return zero, and a zero local match falls back to the complete legacy edge scan for compatibility with transient Edit Poly states. No position matching, tolerance, or cached post-commit topology is introduced.
- In `1.216`, `QUIET` suppresses successful per-pair Broken-T MOVE/WELD start and verification diagnostics, including the equivalent legacy move helper chatter. Fatal diagnostics remain unconditional, and one stage/final summary remains visible so failures and overall batch state are still diagnosable.
- `1.217` makes Broken-T Command Panel synchronization state-diff based. When the selected node, current `SELECT BROKEN T JUNCTIONS` modifier, and requested Edge/Vertex level already match, no node reselection, `SetPrimaryNode`, `modPanel.setCurrentObject`, `SetEPolySelLevel`, or `subObjectLevel` write is issued. Common modifier properties are written only when their current value differs.
- `1.217` keeps every target group in Edge context throughout the complete Divide pass. Completed groups retain only their appended vertex IDs plus stored source ordering data; after all possible groups have split (or a later stale target group stops the pass), the stage switches to Vertex context once, resolves all completed-group move pairs, and preserves the same partial-Divide handoff contract.
- `1.217` also suppresses the selector-stage viewport refresh/redraw on the non-modal RMB path. LMB selection still refreshes visibly. After Divide and after each weld commit, live topology is probed in the unchanged current Vertex context first. A state-preserving `RefreshScreen()` / `update node` retry is attempted next; a full same-modifier rebind occurs only if the required appended ID is still not visible or the post-weld vertex count is still not the exact expected value.
- `1.218` accumulates the preserved T-junction vertex ID from every source/inserted pair only after that cycle's complete WELD stage succeeds. Because the weld contract preserves the lower source ID and removes only higher appended disposable IDs in descending order, those repaired source IDs remain stable through later batch cycles. After the final fresh Divide cycle reports no remaining pairs, the tool switches the already-active `SELECT BROKEN T JUNCTIONS` modifier to Vertex context once, replaces its Vertex selection with exactly the accumulated repaired vertices, refreshes once, and leaves those vertices visibly selected. Failed/incomplete cycles are never added to the final selection.
- `MOVE VERTICES` performs no `DivideEdge` and no weld. The batch path preserves the pending pairs for the following weld stage. `1.212` keeps one `MoveSelection -> Commit()` per distinct move delta but removes explicit `RefreshScreen()` / `completeRedraw()` from the per-pair loop; direct standalone stage calls may refresh once at stage end, while the production batch defers visible refresh/redraw until the complete repair finishes.
- `WELD VERTICES` consumes the same pending pairs after movement, preserves the source vertex, welds the inserted disposable vertex into it in descending disposable-ID order, and requires one live vertex to disappear per pair. `1.212` removed explicit per-weld viewport refresh/redraw. From `1.217`, each post-commit verification first reads the exact expected vertex count without changing the current node/modifier/Vertex state, then retries through a state-preserving refresh/update if needed; the historical full rebind is used only when both reads are stale.
- `BATCH BROKEN T FIX` runs `DIVIDE EDGE -> MOVE VERTICES -> WELD VERTICES` without modal stage dialogs. When Divide returns partial failure but has produced a non-empty valid handoff, the batch deliberately continues through Move and Weld, then starts a fresh Divide cycle against the now-updated live topology. It finishes only when a fresh Divide cycle finds zero remaining cases/pairs. If geometry changed, `1.212` performs one final `RefreshScreen()` / `completeRedraw()` after the complete batch rather than explicit redraws inside MOVE/WELD pair loops.
- The RMB path uses the existing `fixTBorderHoles()` wrapper: it runs the Broken-T selector first without modal dialogs, then runs `BATCH BROKEN T FIX` on the same selected object. A zero-hole selection is a clean no-op success.
- A batch Divide failure with no pending handoff, any Move failure, or any Weld failure is a real batch failure and stops the chain with Listener diagnostics.
- The temporary Move/Weld proof functions remain available in backend code for diagnostics, but their step-by-step UI buttons are removed from the production rollout.
- The split stage handoff is runtime state. Reloading Loop-Cleaner preserves it when the previous live tool instance still references the same valid node/Edit Poly and a non-empty move-pair Array; restarting 3ds Max still clears it.
- Position-based Broken-T detection and comparison use only the explicit `postion preccision` setting. Divide-stage topology identity uses preserved edge/vertex IDs instead, so coarse precision cannot merge distinct target edges. Actual scene geometry is not rounded or snapped by the comparison helpers.
- Divide, Move, Weld, and proof helpers remain independently callable for diagnostics, but the production rollout exposes only the merged Broken-T LMB/RMB control.
- The staged repair modifies only the working `Edit_Poly` modifier and never modifies the Editable Poly base directly or uses TriMesh edge IDs.

## Selection / modifier contract

- LMB is non-destructive detection.
- Store the final edge result in an Edit Poly modifier named `SELECT REDUNDANT LOOPS`.
- Reuse that exact selector if it already exists.
- Keep `.showCage = off`.
- Do not consume arbitrary unrelated component selections.
- Zero result must not create a new selector; clear stale selection only when an existing exact selector is being reused.

## RMB removal contract

- RMB operates only on the exact Edge BitArray stored in `SELECT REDUNDANT LOOPS`.
- If no selector exists, run the same detector first.
- Use `SetOperation #RemoveEdgeRemoveVertices` followed by `Commit()`.
- Verify topology decreases before reporting success or renaming the selector to `DELETED REDUNDANT LOOPS`.

## UI layout

- Standalone dialog width is `288 px`; the canonical `.NET` `tool title button` remains `32 px` high with 12 px side margins and tool-name-only label `Loop-Cleaner`.
- The title button uses shared `ScriptReload.ms` and `ToolTitleButton.ms`; LMB calls `restartTool`.
- Production controls are `USELESS LOOPS SELECT \ REMOVE`, `BORDER ALL`, `OUTER`, `INNER`, `T JUNCTIONS`, `T BORDER`, `T MESH`, and `T BORDER HOLES SELECT \ FIX`.
- On `T BORDER HOLES SELECT \ FIX`, LMB runs the Broken-T selection only and RMB runs `fixTBorderHoles()`, which refreshes that selection and performs the stable batch repair. The separate `FIX T BORDER HOLES` button is removed. The underlying `BATCH BROKEN T FIX`, Divide, Move, and Weld functions remain backend operations rather than separate production controls.
- The temporary `TEST MOVE VERTEX`, `TEST MOVE SELECTED VERTEX`, and `TEST WELD SELECTED VERTICES` controls are removed from the production rollout. The older border/wall-corner debug selectors remain, followed by `QUIET`, `postion preccision`, disabled `ANGLE`, and disabled `GET ANGLE`.
- One `postion preccision` dropdown provides `1mm`, `0.1mm`, and `0.01mm`, default `0.01mm`; the selected label persists in `Loop-Cleaner.ini` and is converted explicitly from millimeters to current system units before backend position operations.
- The title button resizes horizontally with the owning rollout width. The standalone dialog remains a left/right-dockable CUI dialog bar and does not duplicate a bottom restart button.

## Object019 regression contract

`Object019` IDs are regression expectations only; they are never production inputs.

For the supplied production `Object019` at `ANGLE = 20`, the last user-confirmed redundant-edge regression set is:

`#{2..6, 10, 12..14, 16..17, 19..20, 23..24, 26..27, 29..31, 33, 35, 37..38, 46..48, 55, 58, 60, 64, 66, 69, 72, 74, 78, 80, 82, 84, 86, 89, 91, 93..94, 103..104, 108..109}`

The separate test harness may compare missing/extra IDs against this set. The production script must not contain this BitArray or use it for detection.
