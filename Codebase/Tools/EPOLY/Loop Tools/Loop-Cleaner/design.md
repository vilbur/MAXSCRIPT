# Loop-Cleaner Design

## Clean rewrite status

- `Loop-Cleaner.ms` is the canonical clean rewrite development file and currently carries version `1.167`.
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
- `T BORDER` first detects the complete broken inner-border components with the existing explicit `0.1 mm` seam detector, then finds exact T-junction vertices associated with those broken border runs. It selects only each qualifying vertex's T-stem edge, never the parallel continuation along the border or traced loop.
- The intended contract includes T junctions on the first or last edge of a broken inner-border run, but this endpoint case is still not reliable in the current build and is tracked in `known-issues.md`.
- The T-stem is the existing exact T-junction third edge: the non-border edge left after the one perfectly collinear through pair is identified. No new angle tolerance, epsilon, edge-ID rule, or scene-specific component ID is introduced.
- `T MESH` keeps complete traced T-junction loops only when the traced loop contains no `T BORDER` stem edge.
- All three modes share one dedicated Edit Poly named `SELECT T JUNCTIONS`; switching modes replaces only that selector's Edge BitArray and does not overwrite `SELECT BORDERS` or `SELECT REDUNDANT LOOPS`.

## Broken inner-border T-junction fix contract

- `BROKEN T JUCTIONS SELECT \ FIX` is a dedicated LMB/RMB repair control for degenerate inner-hole borders.
- LMB classifies inner borders with the existing per-shell border logic, then finds any inner-border vertex lying within an explicit `0.1 mm` world-space tolerance of the strict interior of another non-incident inner-border edge, with at least one of the source vertex’s own inner-border edges lying on that same target line within the same tolerance.
- The valid rectangular inner hole remains unselected when it contains no such vertex-on-edge seam.
- LMB expands every local broken-T hit to the complete connected inner-border component(s) involved and stores the visible/selectable result in a dedicated reusable `SELECT BROKEN T JUNCTIONS` Edit Poly.
- RMB uses that dedicated selector as the working Edit Poly and re-reads live polygon topology before every repair.
- For each broken-T source the fixer first resolves an already-existing non-neighbor inner-border vertex within the explicit `0.1 mm` positional tolerance and on the detected opposite target-edge line.
- When one unique existing opposite-side vertex exists, it remains the weld target. The disposable T source is moved onto that target and welded into it with `WeldVertices target source`.
- When a current broken-T case has no existing opposite-side vertex, the fixer uses the verified `EPoly-Stack-Test_1.20.ms` pattern: call `Edit_Poly.DivideEdge` directly on the current target edge, immediately `Commit()`, and verify exactly `+1` live vertex, `+1` live edge, and unchanged face count.
- Only one missing opposite vertex is inserted per topology-changing pass. After `Commit()`, every cached vertex/edge/face ID is considered invalid; live Edit Poly topology and broken-T cases are rebuilt before another split or weld. This also handles multiple T sources on one long edge without reusing a stale split-edge ID.
- The raw `DivideEdge` return value is not used as a vertex ID. Inserted targets are resolved only from the freshly rebuilt topology and the stored pre-insert T-source world position.
- Vertices created by the insert phase are tracked by their pre-insert T-source world positions. During the weld phase the newly inserted opposite vertex is moved onto the original T source and welded into that preserved source. Pre-existing opposite vertices keep the existing behavior: the T source is moved onto the preserved opposite vertex and welded into it.
- Each completed weld must remove exactly one live vertex and reduce the currently detected broken-T case count before another weld is attempted.
- On complete success the working modifier is renamed `FIXED BROKEN T JUNCTIONS`. A failed partial repair is reported as failure and remains undoable; success is never reported unless no broken-T cases remain.
- The repair does not modify the Editable Poly base directly and does not use TriMesh edge IDs.

## Selection / modifier contract

- LMB is non-destructive detection.
- Store the final edge result in an Edit Poly modifier named `SELECT REDUNDANT LOOPS`.
- Reuse that exact selector if it already exists.
- Keep `.showCage = off`.
- Do not consume arbitrary unrelated component selections.
- Zero result must not create a new selector; clear stale selection only when an existing exact selector is being reused.

## RMB removal contract

- RMB operates only on the exact Edge BitArray stored in `SELECT REDUNDANT LOOPS`.
- If no selector exists, run the same new detector first.
- Use `SetOperation #RemoveEdgeRemoveVertices` followed by `Commit()`.
- Verify topology decreases before reporting success or renaming the selector to `DELETED REDUNDANT LOOPS`.

## UI layout

- Standalone dialog width is `336 px` and follows the shared 12 px layout grid.
- A canonical `.NET` `tool title button` sits at the top with the project-specific requested height of `32 px`, 12 px side margins, and tool-name-only label `Loop-Cleaner`.
- The title button uses shared `ScriptReload.ms` and `ToolTitleButton.ms`; LMB calls `restartTool` and replaces the old bottom restart button.
- From the canonical `Codebase/Tools/EPOLY/Loop Tools/Loop-Cleaner/` package path, shared UI helpers resolve from the `Maxscript/UI/Default/` folder by walking five parent directories to the `Maxscript` root.
- The native dialog title remains versioned from the current global project version.
- Primary action: 32 px `USELESS LOOPS SELECT \ REMOVE` button.
- One 32 px border-selection row follows it: `BORDER ALL`, `OUTER`, and `INNER`.
- One 32 px T-junction row follows it: `T JUNCTIONS`, `T BORDER`, and `T MESH`.
- One full-width 32 px `BROKEN T JUCTIONS SELECT \\ FIX` button follows the T-junction row; LMB selects degenerate inner-border components and RMB repairs their vertex-on-edge seams.
- Debug buttons 1–4 are also 32 px high.
- `GET ANGLE` is also 32 px high; all button controls use actual 32 px control height rather than simulated padding.
- `QUIET` follows the debug controls.
- Final row keeps `ANGLE`, units, and `GET ANGLE`; disabled controls remain visible.
- The title button resizes horizontally with the owning rollout width.
- The standalone dialog is registered as a CUI dialog bar with `#cui_dock_vert`, `#cui_floatable`, and `#cui_handles`, allowing left/right docking while keeping top/bottom docking disabled.
- `RESTART` is not duplicated at the bottom while the title button provides restart.

## Object019 regression contract

`Object019` IDs are regression expectations only; they are never production inputs.

For the supplied production `Object019` at `ANGLE = 20`, the last user-confirmed redundant-edge regression set is:

`#{2..6, 10, 12..14, 16..17, 19..20, 23..24, 26..27, 29..31, 33, 35, 37..38, 46..48, 55, 58, 60, 64, 66, 69, 72, 74, 78, 80, 82, 84, 86, 89, 91, 93..94, 103..104, 108..109}`

The separate test harness may compare missing/extra IDs against this set. The production script must not contain this BitArray or use it for detection.
