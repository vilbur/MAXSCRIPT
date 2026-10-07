# Loop-Cleaner Design

## Clean rewrite status

- `Loop-Cleaner.ms` is the canonical clean rewrite development file and currently carries version `1.210`.
- The canonical Drive file keeps its existing file ID and filename; version identity is stored inside the script rather than by creating duplicate release copies.
- File version, stored project version, and visible title version are one identical version number.
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

- `BROKEN T JUNCTIONS SELECT \\ FIX` is the production Broken-T control. LMB is the non-destructive detector: it classifies broken inner-border components with the selected `postion preccision` value and stores the visible/selectable result in the dedicated reusable `SELECT BROKEN T JUNCTIONS` Edit Poly. RMB refreshes that same selection first, then runs the complete batch repair.
- `DIVIDE EDGE` is stage 1 of the split repair workflow. If the selector does not exist yet, it runs the same Broken-T selection first.
- Stage 1 captures missing opposite targets before topology changes and preserves each source's original target edge ID plus the two endpoint vertex IDs. Sources are grouped by that exact original target edge ID, never by rounded/precision-quantized endpoint positions.
- For each group, the first split uses the exact target edge ID captured by the detector and confirms its preserved endpoint vertex IDs. The stage performs exactly `N` committed `DivideEdge` operations for `N` required inserted vertices. After every split, the old edge ID is discarded and the remaining child segment is resolved from the exact pair `(newly appended vertex ID, untouched far endpoint vertex ID)`.
- Every split must add exactly one live vertex. The `DivideEdge` return value is never treated as a vertex ID. Source vertices and appended vertices are ordered along the same preserved original edge direction, producing transient `#(sourceVertexID, insertedVertexID)` move pairs.
- `DIVIDE EDGE` stops there: it does not call `MoveSelection` and it does not weld. If a later independent target group fails after one or more earlier groups already completed, every successfully produced source/inserted pair remains stored as the pending move handoff even though the Divide action itself still reports failure.
- `MOVE VERTICES` consumes the pending `#(sourceVertexID, insertedVertexID)` pairs. For each pair it activates the working `Edit_Poly` in Vertex context, isolates only the inserted vertex, reads both live positions, runs `MoveSelection (sourcePosition - insertedPosition) -> Commit`, and verifies the inserted vertex reaches the source at the explicit `postion preccision`.
- `BATCH BROKEN T FIX` reuses the exact `SELECT BROKEN T JUNCTIONS` modifier for the complete repair. Ordinary stage changes do not toggle to another modifier. However, a topology-changing `Commit()` creates a required live-topology synchronization boundary: before MOVE reads IDs after Divide, and after each WELD commit before the next live count/ID read, the same Edit Poly is deliberately rebound with `modPanel.setCurrentObject` plus the normal `SetPrimaryNode`/selection-level state. The 1.203 and 1.209 runtime failures (`GetNumVertices == 0` after Divide) prove that sub-object synchronization alone is insufficient at that boundary.
- `MOVE VERTICES` performs no `DivideEdge` and no weld. The batch path preserves the pending pairs for the following weld stage.
- `WELD VERTICES` consumes the same pending pairs after movement, preserves the source vertex, welds the inserted disposable vertex into it in descending disposable-ID order, and requires one live vertex to disappear per pair.
- `BATCH BROKEN T FIX` runs `DIVIDE EDGE -> MOVE VERTICES -> WELD VERTICES` without modal stage dialogs. When Divide returns partial failure but has produced a non-empty valid handoff, the batch deliberately continues through Move and Weld, then starts a fresh Divide cycle against the now-updated live topology. It finishes only when a fresh Divide cycle finds zero remaining cases/pairs.
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
- Production controls are `USELESS LOOPS SELECT \ REMOVE`, `BORDER ALL`, `OUTER`, `INNER`, `T JUNCTIONS`, `T BORDER`, `T MESH`, `BROKEN T JUNCTIONS SELECT \ FIX`, and `FIX T BORDER HOLES`.
- On `BROKEN T JUNCTIONS SELECT \ FIX`, LMB runs selection only and RMB runs selection followed by the stable batch repair. `FIX T BORDER HOLES` provides a separate LMB-only batch action that runs the same select-then-fix wrapper. The underlying `BATCH BROKEN T FIX`, Divide, Move, and Weld functions remain backend operations rather than separate production controls.
- The temporary `TEST MOVE VERTEX`, `TEST MOVE SELECTED VERTEX`, and `TEST WELD SELECTED VERTICES` controls are removed from the production rollout. The older border/wall-corner debug selectors remain, followed by `QUIET`, `postion preccision`, disabled `ANGLE`, and disabled `GET ANGLE`.
- One `postion preccision` dropdown provides `1mm`, `0.1mm`, and `0.01mm`, default `0.01mm`; the selected label persists in `Loop-Cleaner.ini` and is converted explicitly from millimeters to current system units before backend position operations.
- The title button resizes horizontally with the owning rollout width. The standalone dialog remains a left/right-dockable CUI dialog bar and does not duplicate a bottom restart button.

## Object019 regression contract

`Object019` IDs are regression expectations only; they are never production inputs.

For the supplied production `Object019` at `ANGLE = 20`, the last user-confirmed redundant-edge regression set is:

`#{2..6, 10, 12..14, 16..17, 19..20, 23..24, 26..27, 29..31, 33, 35, 37..38, 46..48, 55, 58, 60, 64, 66, 69, 72, 74, 78, 80, 82, 84, 86, 89, 91, 93..94, 103..104, 108..109}`

The separate test harness may compare missing/extra IDs against this set. The production script must not contain this BitArray or use it for detection.
