# Redundant-Loop-Fixer Design

## Clean rewrite status

- `Redundant-Loop-Fixer_1.151.ms` is the current clean rewrite development file.
- `Redundant-Loop-Fixer.ms` must stay byte-for-byte synchronized with the latest released versioned script.
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
- A canonical `.NET` `tool title button` sits at the top with the project-specific requested height of `32 px`, 12 px side margins, and tool-name-only label `Redundant-Loop-Fixer`.
- The title button uses shared `ScriptReload.ms` and `ToolTitleButton.ms`; LMB calls `restartTool` and replaces the old bottom restart button.
- The native dialog title remains versioned from the current global project version.
- Primary action: 32 px `USELESS LOOPS SELECT \ REMOVE` button.
- One 32 px border-selection row follows it: `BORDER ALL`, `OUTER`, and `INNER`.
- Debug buttons 1–4 are also 32 px high.
- `GET ANGLE` is also 32 px high; all button controls use actual 32 px control height rather than simulated padding.
- `QUIET` follows the debug controls.
- Final row keeps `ANGLE`, units, and `GET ANGLE`; disabled controls remain visible.
- The title button resizes horizontally with the owning rollout width.
- `RESTART` is not duplicated at the bottom while the title button provides restart.

## Object019 regression contract

`Object019` IDs are regression expectations only; they are never production inputs.

For the supplied production `Object019` at `ANGLE = 20`, the last user-confirmed redundant-edge regression set is:

`#{2..6, 10, 12..14, 16..17, 19..20, 23..24, 26..27, 29..31, 33, 35, 37..38, 46..48, 55, 58, 60, 64, 66, 69, 72, 74, 78, 80, 82, 84, 86, 89, 91, 93..94, 103..104, 108..109}`

The separate test harness may compare missing/extra IDs against this set. The production script must not contain this BitArray or use it for detection.
