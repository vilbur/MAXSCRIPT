## 2026-10-09 — Project 0.37

- Diagnosed direction fixes returning zero despite valid detection: Edit Poly primary-node binding fails and its attempted MoveSelection produces readbacks at the node transform origin.
- Added a topology-verified base Editable Poly repair path only when the stack contains exactly the Geometry Diagnostics owned selection-only Edit Poly, with unchanged vertex/edge IDs and all initial positions equal within the selected position precision.
- The repair retains the existing Edit Poly for selection and display, but writes the matching base vertex directly with polyop.setVert; post-move readback and exact-edge verification use the same verified base geometry.
- Complex stacks, mismatched topology, and dead base topology do not take this new base path; their existing guarded modifier workflow is unchanged.
- Added Part 31 translated-node regression: confirm the actual base vertex moves and no other vertices or modifiers change. 3ds Max runtime verification is pending.
- FN 0.29 and test 0.29; project version 0.37. UI and entry script remain unchanged.

## 2026-10-09 — Project 0.36

- `Geometry-Diagnostics-UI.ms` 0.22: split direction controls into a 2 x 2 grid: VERTICAL / SKEWED \ FIX, HORIZONTAL / SLOPED \ FIX.
- Left controls retain exact-edge LMB selection and the original RMB/CTRL+RMB shortcuts. Each new right control uses LMB to select off-axis edges and RMB to perform the existing trusted-reference fix.
- Styled only this tool's .NET restart title button with blue-on-charcoal text/border and hover/pressed states. Preserved the shared title helper, tool-name label, 18 px height, and LMB restart action.
- Increased the minimum dialog height for the second row while preserving INI-backed dialog state.

## 2026-10-09 — Project 0.35

- Ortho RMB no longer skips its horizontal pass when vertical repair reports unresolved components. Both passes execute independently on each selected object, in the original vertical-then-horizontal order.
- Both Ortho RMB and direction CTRL+RMB now retain counts for verified repaired edges even when another component on the same object remains unresolved; incomplete work stays flagged rather than being reported as success.
- The final owned direction Edit Poly remains active when a pass makes partial progress. UI status reports repaired counts alongside unresolved-object counts.
- Added regression Part 30 with disconnected wall elements: the no-reference vertical component must remain unchanged while an independent, properly referenced horizontal component can still be repaired.
- Backend advances to 0.28, UI to 0.21, regression script to 0.28; shared project version advances to 0.35. Main entry file is unchanged. Static patch construction only; 3ds Max runtime verification is required.

## 2026-10-09 — Project 0.34

- Updated the `.NET` tool title/restart button to the current shared style: `18 px` height, existing title colors/flat borderless states preserved, and the current button font size increased by `2.0` through the shared `ToolTitleButton` helper.
- Geometry behavior is unchanged. `Geometry-Diagnostics-UI.ms` advances to file `0.20`; backend, main, and regression files are unchanged.

## 2026-10-07 — Project 0.33

- Fixed the runtime CTRL+RMB failure shown by the supplied `BLOCK-A-MATERIAL001` log without changing ordinary vertical/horizontal RMB detection.
- Replaced static `EditPolyMod.GetVertex`-style direction reads with the proven instance API (`edit_poly_mod.GetVertex ... node:`) used by the shared Epoly transform source; world targets still convert to object-space deltas before `MoveSelection -> Commit` and read-back verification.
- Simplified both vertical and horizontal repair to one exact same-loop continuation rule. A component moves only when an unselected visible edge continues the component in the opposite principal-axis direction and is already exact within `postion preccision`.
- Removed the over-strict whole-neighborhood wall-plane fit that rejected valid wall corners. The exact continuation edge now supplies the trusted 3D alignment line, correcting both wall-depth and in-wall drift while preserving the requested principal-axis coordinate.
- Multiple continuation anchors must agree within `postion preccision`; missing, same-side branch, or conflicting references leave that component untouched. No averaging, lowest-vertex fallback, projection guess, or invented target is used.
- Added translated-node regression coverage so an Edit Poly vertex read cannot silently collapse to the node transform origin, plus existing no-reference/no-movement safety coverage.

## 2026-10-07 — Project 0.32

- Replaced the separate vertical/horizontal CTRL+RMB repair strategies with one unified no-guess wall-loop method. Both directions now consume the matching RMB skewed/sloped set when available and fall back to the same RMB detection only when needed.
- Each selected same-axis component first resolves a trusted local wall plane from neighboring face vertices outside the component. The reference geometry must provide at least three usable vertices and all reference vertices must fit that plane within the explicit `postion preccision`; corners, ambiguous planes, and insufficient reference geometry are left unresolved.
- Alignment now requires an unselected visible continuation edge on the same loop that is already exact for the same X/Y/Z principal axis and lies on the trusted wall plane. Multiple references must agree within `postion preccision`; no mean coordinate, lowest-vertex target, or guessed fallback is allowed.
- Reference/anchor vertices are never moved. Non-anchor vertices keep the coordinate along the desired edge direction and receive only the constrained coordinates from the trusted reference; the solved target must also remain on the wall plane within `postion preccision`.
- Components without a trustworthy plane/reference, conflicting references, or shared X/Y horizontal junctions remain completely untouched and are reported as unresolved instead of shifting otherwise valid wall geometry.
- Updated direction-button tooltips plus regression Parts 27-28 for vertical/horizontal wall-plane repair, no-reference no-op safety, preservation of unrelated wall vertices, and the ordered CHECK ORTHO EDGES RMB batch.

## 2026-10-07 — Project 0.31

- Fixed `VERTICAL\SKEWED CTRL+RMB` without changing the now-working ordinary RMB selection path.
- Vertical CTRL+RMB now consumes the current Geometry Diagnostics RMB skewed-edge selection from the exact owned direction `Edit_Poly`; if CTRL+RMB is used first, it runs the same RMB detection once as a fallback.
- Replaced the 0.30 vertical coordinate-anchor solver with connected selected-edge components. Each component uses its lowest world-space vertex as the stable XY anchor, aligns every component vertex to that XY, and preserves every original Z coordinate.
- The repair restores the original vertex selection, restores the same RMB edge BitArray visibly, verifies every repaired selected edge against `postion preccision`, and leaves the Modify panel active at Edge level.
- Horizontal CTRL+RMB remains on the 0.30 solver; this change is intentionally isolated to the reported vertical repair failure.
- Updated regression Part 27 so vertical repair is tested as the real UI sequence: RMB selection first, then CTRL+RMB, with exact selection preservation, bottom-anchor preservation, XY alignment, and final Edge-level state.

## 2026-10-07 — Project 0.30

- Reworked `VERTICAL\SKEWED` and `HORIZONTAL SLOPED` `CTRL+RMB` instead of inheriting Wall-Fixer's selected-loop target bug. `CTRL+RMB` now self-detects the current beyond-precision direction edges before repair, so it no longer depends on a previous RMB selection or stale Edit Poly vertex-selection state.
- Replaced the old single-target loop alignment with per-coordinate world-axis constraints. Vertical Z edges solve X/Y equality; horizontal X edges solve Y/Z equality; horizontal Y edges solve X/Z equality, matching the Geometry Diagnostics classifier exactly.
- Exact unselected neighboring edges are used as coordinate anchors when available. If no reliable anchor exists, the selected constraint component uses its mean coordinate, minimizing total movement without an angle threshold.
- Edit Poly vertex moves now follow the shared stable Select -> MoveSelection -> Commit pattern using object-space deltas derived from world targets, with explicit postion-preccision read-back diagnostics.
- `CHECK ORTHO EDGES` RMB keeps the requested vertical-LMB/CTRL+RMB then horizontal-LMB/CTRL+RMB order; each CTRL+RMB step now initializes its own skewed selection before solving.
- Strengthened regression coverage so CTRL+RMB is called directly with no preceding RMB, horizontal lateral drift is tested in addition to Z slope, and the ortho batch starts from true beyond-precision X/Y/Z displacement.

## 2026-10-07 — Project 0.29

- Ported Wall-Fixer's `CTRL+RMB` selected-direction loop repair to Geometry Diagnostics for both `VERTICAL\SKEWED` and `HORIZONTAL SLOPED`. The repair keeps the current selected edge set, resolves logical loop targets, moves only the selected loop vertices, restores the edge selection, and leaves the owned direction Edit Poly active at Edge level.
- Kept the Geometry Diagnostics direction contract position-based: no edge angle is calculated. Principal-axis membership and repair verification use the selected `postion preccision`.
- Bound `CTRL+RMB` on both direction `.NET` buttons to the new repair path; ordinary RMB still selects beyond-precision skewed/sloped edges and LMB still selects within-precision direction edges.
- Added `CHECK ORTHO EDGES` RMB batch repair in the requested order: vertical LMB selection -> vertical CTRL+RMB repair -> horizontal LMB selection -> horizontal CTRL+RMB repair. LMB on `CHECK ORTHO EDGES` keeps the existing severity-paint diagnostic.
- Added regression coverage for vertical and horizontal CTRL+RMB repair plus the ordered `CHECK ORTHO EDGES` RMB batch, including final Modify-panel / Edge-level state.

## 2026-10-07 — Project 0.28

- Added `CLEAR OBJECT` to the bottom of the `DEBUG` group as a dark `.NET` button with destructive warning text.
- `CLEAR OBJECT` removes every modifier from each selected geometry object, including user modifiers and Geometry Diagnostics selection/paint modifiers.
- For an Editable Poly base, `CLEAR OBJECT` removes map channel `0` support so stored base vertex paint is deleted, then disables vertex-color viewport display.
- The shared `VertexColorPainter` session is safely cleared before stack deletion when it is bound to the target, ownership rows are pruned afterwards, and the operation finishes in the Modify panel at Object level.
- Added regression coverage for Tessellate + PaintLayerMod + base channel-0 cleanup and final Modify-panel state.

## 2026-10-07 — Project 0.27

- Converted `CHECK ORTHO EDGES` to the same dark WinForms `.NET` button style used by the other `TESTS` actions.
- All `TESTS` action buttons now use the shared `.NET` styling helper; the two direction buttons keep their orange foreground override.
- Moved `1. CHECK AND MAKE WALLS PLANAR` to the bottom of the `TESTS` group without changing its LMB/RMB behavior.
- Increased the dialog minimum/default height by one 12px UI grid step for the taller `.NET` ortho button.

## 2026-10-07 — Project 0.26

- Moved `postion preccision` and `ortho tolerance` to the first row of the `TESTS` group.
- Placed both controls side by side on one row; diagnostic behavior and persisted values are unchanged.
- Reduced the dialog minimum/default height to match the more compact layout.


## 2026-10-07 — Project 0.25

- Kept diagnostic controls in the `TESTS` group.
- Wrapped the utility buttons `CREATE TEST BOX`, `PAINT FACE COLORS`, `RESTORE COLORS`, and `DUMP CHANNEL 0` into a separate `DEBUG` group and moved that group to the bottom of the dialog.
- Increased the dialog minimum/default height to preserve the grouped layout; backend behavior is unchanged.


## 2026-10-07 — Project 0.24

- Renamed the Geometry Diagnostics `DEBUG` UI group to `TESTS`.
- Moved `1. CHECK AND MAKE WALLS PLANAR` into `TESTS` as the first control; its LMB/RMB behavior is unchanged.
- No backend or regression-test logic changed in this UI-only revision.


## 2026-10-07 — Project 0.23

- Added the first Geometry Diagnostics action button, `1. CHECK AND MAKE WALLS PLANAR`, using the working Wall-Fixer planar-wall workflow.
- LMB splits evaluated triangles into wall clusters at sharp corners of 45° or more, resolves each cluster's dominant plane, and selects detected outlier vertices at Vertex level.
- RMB removes only the exact Geometry Diagnostics temporary `NON PLANAR VERTS` marker, repairs detected outliers against their owning wall-cluster plane or shared-plane intersection, verifies planarity, and collapses to Editable Poly only when the real stack requires repair.
- Preserved Wall-Fixer's planarity defaults for the port: planar fitting tolerance `1.0`, normal-orientation aid `5°`, and wall-corner split `45°`.
- Added regression coverage on a deliberately warped quad for LMB outlier selection, RMB repair, verification, and final Modify-panel state.


# Changes

## 2026-10-06 — Project 0.22

- Matched the working Wall-Fixer direction-selection failure semantics shown by the runtime trace: `prepareStraightEdgeFixerModifier()` may report a primary-node binding exception while later direct Edit Poly topology reads and edge selection still succeed.
- Geometry Diagnostics no longer treats an initial `ensureEditPolyPrimaryNode` failure as fatal in the adapter/display/selection transport. The helper still reports the native failure, but the workflow continues to the same direct `EditPolyMod.GetNumEdges` / `SetSelection` / final read-back path used by Wall-Fixer.
- Removed the extra Geometry Diagnostics requirement that immediate selection read-back and display activation must both be true before selection can count as applied. As in Wall-Fixer, the decisive selection result is the final edge BitArray; display state is diagnosed separately.
- Direction actions explicitly reactivate the owned Edit Poly after selection and verify that the command panel is `#modify`, the exact Edit Poly is current, and Edge sub-object level `2` is active.
- Extended primitive regression coverage so LMB and RMB both verify final Modify-panel / Edge-level state.

## 2026-10-06 — Project 0.21

- Direction-button actions now explicitly finish in the 3ds Max Modify panel instead of allowing the Wall-Fixer-style Create-mode topology preflight to remain visible.
- After the selected-object loop, the last successful direction `Edit_Poly` is reactivated at Edge level and the command-panel mode is verified as `#modify`.
- If no direction result is available, the command panel is still switched back to Modify mode rather than being left in Create mode.
- Added regression assertions that primitive vertical and horizontal LMB actions both leave the Modify panel active.


## 2026-10-06 — Project 0.20

- `VERTICAL\SKEWED` / `HORIZONTAL SLOPED` now consume the current geometry-object selection directly, matching Wall-Fixer instead of routing through the Editable-Poly-only Geometry Diagnostics paint target resolver.
- The same Wall-Fixer-style Edit Poly adapter path now works on unconverted geometry primitives as well as Editable Poly nodes.
- Added primitive-box regression coverage: vertical LMB selects 4 edges and horizontal LMB selects 8 edges without pre-converting the source object.
- Bumped the modified backend/test/UI files for the finalized direction-button selection path; no angle calculation is introduced and `postion preccision` remains the endpoint-position cutoff.



## 2026-10-06 — Project 0.19


- Rebuilt `VERTICAL\SKEWED` / `HORIZONTAL SLOPED` direction selection from the working Wall-Fixer checker path instead of the previous Geometry Diagnostics-specific selection wrapper.
- Ported Wall-Fixer's geometry-adapter recovery behavior: acquire the exact session-owned Edit Poly, prepare live topology, and if a valid Editable Poly base still reports zero live Edit Poly edges, rebuild that exact owned modifier once and prepare again.
- Direction scanning now uses the Wall-Fixer adapter sequence for edge count, edge vertex IDs, object/world vertex positions, selection write, `SetSelection` read-back, `Select` fallback, Modify-panel activation, redraw, and final selection read-back.
- The only intentional classifier change remains the requested one: no angle is calculated. `postion preccision` compares endpoint off-axis distance (vertical = XY; X-running horizontal = YZ; Y-running horizontal = XZ).
- Native selection read failures are no longer converted into a valid empty selection; they remain explicit failures with Listener diagnostics.
- Updated direction-selection regression coverage to exercise the Wall-Fixer-style adapter directly and verify LMB/RMB reuse the same exact direction Edit Poly with final BitArray read-back.


## 2026-10-06 — Project 0.18


- Fixed the direction-button selection path: the 0.17 backend called two ownership helpers that were never defined, so `VERTICAL\SKEWED` / `HORIZONTAL SLOPED` could never complete a valid selection workflow.
- Ported Wall-Fixer's live Edit Poly preparation sequence for direction selection: Create-panel preparation, primary-node binding, Edge selection level, evaluated-topology wake-up, `useStackSelection = false`, and `showCage = off`.
- Ported Wall-Fixer's selection commit sequence: activate the Edit Poly at Edge level, `SetSelection`, immediate read-back, `Select` fallback, node update, display reactivation, redraw, then final read-back.
- Direction selection now fails loudly when the final BitArray or active Edge display state differs from the requested selection; diagnostics print requested, immediate, final, current Modify-panel object, sub-object level, and stack-selection state.
- Preserved the Geometry Diagnostics exact-instance ownership rule instead of Wall-Fixer's display-name lookup; same-name foreign modifiers are never adopted.
- Added regression coverage for both LMB and RMB selection on one live Edit Poly adapter, including replacement of the LMB set by the RMB set and final post-update read-back.


## 2026-10-06 — Project 0.17


- Changed `CHECK ORTHO EDGES` to three explicit distance-based validity levels: valid ortho, valid skewed/sloped, and invalid skewed/sloped.
- Valid ortho now uses white instead of green and is defined only by `off-axis drift <= postion preccision`.
- Added the persisted `ortho tolerance` dropdown with `1.00mm`, `2.00mm`, `5.00mm`, and `10.00mm`; default is `1.00mm` and the backend requires tolerance to be at least the selected position precision.
- Valid skewed/sloped edges are above position precision through ortho tolerance and use a green -> blue distance gradient.
- Invalid skewed/sloped edges are above ortho tolerance and use a yellow -> red distance gradient; full red is reached at `2 * ortho tolerance` and clamped beyond.
- Removed angular severity from the ortho result/paint path. The result now stores `edge_deviation_distances`, `valid_skewed_edges`, and `invalid_edges`; `suspicious_edges` remains an alias of invalid edges for compatibility.
- Updated regression coverage for tolerance resolution, three-level reconstruction, white/green-blue/yellow-red color anchors, and distance storage.


## 2026-10-06 — Project 0.16


- Removed the redundant directional Angle spinner and stopped reading/writing the obsolete `Debug / EdgeAngle` INI value.
- `VERTICAL\SKEWED` and `HORIZONTAL SLOPED` now behave as real Wall-Fixer-style edge selection controls instead of orange paint diagnostics: LMB selects the within-precision set, RMB selects the beyond-precision set.
- Added a session-owned `GEOMETRY DIAGNOSTICS` Edit Poly selection modifier with exact-instance ownership, verified selection read-back, Modify-panel activation, Edge sub-object level, `useStackSelection = false`, and `showCage = off`.
- Reinterpreted `postion preccision` for directional checks as the explicit off-axis endpoint-distance cutoff: Z uses XY drift, X uses YZ drift, and Y uses XZ drift.
- Aligned `CHECK ORTHO EDGES` correct/suspicious classification to the same principal-axis distance rule while preserving the green -> blue -> red angular severity overlay.
- Replaced Angle-bounded direction regression with position-difference cases and added an actual Edit Poly selection workflow test.


## 2026-10-06 — Project 0.15


- Reworked `CHECK ORTHO EDGES` from binary red suspicious-edge paint to angular severity coloring across the complete visible edge domain.
- Exact rounded horizontal/vertical edges are green; the start of skew/sloping remains near green, `15°` is blue, and `45°` is red, with linear interpolation between anchors.
- Ortho analysis now stores each visible edge's deviation from the nearest world horizontal/vertical axis in `edge_deviation_angles`; exact rounded ortho edges are forced to `0°`, while collapsed/degenerate rounded edges are treated as maximum severity.
- Shared face-corners use the highest incident edge deviation before color resolution, preventing paint order from hiding a more severe edge at a common corner.
- Added regression coverage for zero-degree base-box severity and the green -> blue -> red color anchors.


## 2026-10-06 — Project 0.14


- Added the Wall-Fixer-style DEBUG direction row with `VERTICAL SKEWED` on the left, Angle in the center, and `HORIZONTAL SLOPED` on the right, correcting the flipped direction order.
- Direction buttons use the same dark WinForms styling and orange foreground as Wall-Fixer, with explicit `.NET MouseUp` LMB/RMB routing.
- `LMB` diagnoses exact horizontal/vertical edges using the selected `postion preccision`; `RMB` diagnoses non-exact skewed/sloped edges from above `0°` through Angle.
- Added the Wall-Fixer Angle spinner contract (`0.1° .. 45.0°`, default `45.0°`, one-decimal step, RMB min/max toggle) and persisted it in `Geometry-Diagnostics.ini`.
- Direction diagnostics remain non-destructive: the Wall-Fixer `CTRL+RMB` geometry-fix branch is not imported. Matched edges are converted to exact face-corner vertex data and painted orange through `VertexColorPainter`.
- Added backend regression coverage for exact vertical/horizontal and Angle-bounded skewed/sloped classification.


## 2026-10-06 — Project 0.13


- Fixed the runtime `Call needs function or class, got: undefined` in ortho position precision: MAXScript does not provide the assumed `round()` global used by the new quantization helper.
- Added `quantizeGeometryDiagnosticsScalar()` using the proven nearest-step `floor()` method with symmetric negative-coordinate handling, and routed `roundGeometryDiagnosticsPosition()` through it.
- Position precision semantics are unchanged: temporary comparison positions are quantized to `1mm`, `0.1mm`, or `0.01mm`; scene geometry is never snapped or rewritten.
- Extended regression with positive/negative scalar quantization and Point3 precision checks.


## 2026-10-06 — Project 0.12


- Fixed the `roundGeometryDiagnosticsPosition()` parser error by replacing the multi-line Point3 literal with explicit rounded X/Y/Z locals and a single-line Point3 return.
- Geometry/precision behavior is unchanged; the fix only removes the MaxScript end-of-line ambiguity reported at the Z component.


## 2026-10-06 — Project 0.11


- Added a bottom `DEBUG` UI section with the required persisted `postion preccision` dropdown (`1mm`, `0.1mm`, `0.01mm`, default `0.01mm`) and a `CHECK ORTHO EDGES` button.
- Added visible/selectable-edge analysis on the exact selected Editable Poly / supported modifier topology, using the proven Straight-Edge-Fixer world-axis semantics: horizontal compares endpoint world Z and vertical compares endpoint world X/Y. Geometry Diagnostics applies the explicit position-precision rounding contract instead of a hidden tolerance; suspicious edges are the visible domain minus the horizontal/vertical union.
- Ortho results now retain edge BitArrays plus exact `#(geo_vertex_id, face_id)` vertex data. `CHECK ORTHO EDGES` replaces the previous owned overlay and paints suspicious corners red through `VertexColorPainter`.
- Added `paintGeometryDiagnosticsEdgeOnFace()` so the two endpoints of one edge can be colored on only one adjacent polygon face without changing the neighboring face-corner entries.
- Extended regression coverage for the 12-edge base box (8 horizontal / 4 vertical / 0 suspicious), exact face-local edge color, explicit position precision, and suspicious Tessellate-edge painting while preserving the base channel.


## 2026-10-06 — Project 0.10


- `CREATE TEST BOX` now adds the canonical Tessellate modifier immediately after building the Editable Poly base and split channel-0 map.
- The generated Tessellate uses `faceType = 1`, `type = 0`, `tension = 0`, and `iterations = 0`, and remains selected after creation.
- Direct-base regression explicitly selects the Editable Poly base, while the modifier regression reuses the Tessellate already created on the test box instead of adding a second modifier.
- Updated the create-button tooltip/status and regression assertions for the new default test-box stack.


## 2026-10-06 — Project 0.09


- Kept `Geometry-Diagnostics.ms` current: main file version is now `0.05`, shared project version is `0.09`, and reload saves the old dialog state before unregistering/destroying the previous instance.
- Geometry Diagnostics now follows the exact Modify-panel stack selection for painting. Selected Editable Poly/base uses direct channel 0; a supported selected modifier uses canonical `VertexColorPainter` and its owned `PaintLayerMod` immediately above that exact target.
- `PAINT FACE COLORS` no longer forces stack index `0`; it paints the currently selected supported topology level and cycles the six-color diagnostic palette across all cached polygon faces.
- The test Tessellate target now uses the requested Modify-panel setup: `modPanel.addModToSelection (tessellate ()) ui:on`, then `faceType = 1`, `type = 0`, `tension = 0`, and `iterations = 0`.
- Regression now verifies both face-color painting on selected Tessellate and orange painting of generated vertices `#{21..26}`, while the Editable Poly base channel remains unchanged.
- The production UI now registers its managed dialog under the stable `Geometry-Diagnostics` DialogHost key so reload cannot leave duplicate dialogs behind.


## 2026-10-06 — Project 0.08


- Declared the canonical `Codebase/Operations/Vertex-Color-Painter/` package and its regression test as the source of truth for Geometry Diagnostics paint behavior.
- Replaced the Geometry Diagnostics-specific Edit Poly tessellation fixture with the proven `Tessellate` modifier fixture from `Vertex-Color-Painter-Test.ms`.
- Geometry Diagnostics now selects stack targets through `VertexColorPainter.isSupportedStackTarget()` instead of hard-coding `Edit_Poly`.
- Modifier-paint regression now targets the canonical generated Tessellate vertices `#{21..26}`, verifies the exact Tessellate instance remains intact, and keeps the Editable Poly base channel untouched.


## 2026-10-06 — Project 0.07


- Updated Geometry Diagnostics for `VertexColorPainter` 0.02: cleanup now calls `clearPaint()` instead of the collision-prone `clear()` name.
- Corrected the shared Operation dependency path to the canonical `Codebase/Operations/Vertex-Color-Painter` repository used by the current synchronized workspace.
- Updated the standalone regression loader to the same canonical Operation path.


## 2026-10-06 — Project 0.06


- Extracted reusable vertex-color painting from Geometry Diagnostics into `Codebase/Operations/Epoly/Vertex-Color-Painter/Vertex-Color-Painter.ms`.
- Added stateful `VertexColorPainter_v` / `VertexColorPainter` API with bound `source_node` + `stack_index`, cached polygon topology, cached evaluated mesh, explicit `paintCorner`, `paintVertex`, `paintVertices`, `paintEdge`, `paintFace`, bulk `paintCorners`, and paint transaction methods.
- Positive stack targets now bind to an exact `Edit_Poly` reference and place the operation-owned `PaintLayerMod` immediately above it; stack-index shifts are tracked without losing target identity.
- Geometry Diagnostics backend now delegates paint work to `VertexColorPainter` instead of owning duplicate channel-0 / PaintLayerMod logic.
- Geometry Diagnostics main entry now loads the shared Operation dependency before the backend and supports both the canonical `Tools/GEOMETRY/Geometry-Diagnostics` path and the previous direct `Tools/Geometry-Diagnostics` path while locating shared UI helpers.
- Added `Vertex-Color-Painter-Test.ms` regression coverage for exact base corner mapping, vertex/edge/face painting, restore, Edit Poly tessellation, evaluated-only vertex painting, exact modifier face/vertex painting, and safe PaintLayer removal.
- Updated Geometry Diagnostics regression loading and PaintState release behavior for the extracted Operation.


## 2026-10-06 — Project 0.05


- Fixed the standalone entry dependency path for the current `Codebase/Tools/Geometry-Diagnostics` location so shared `UI/Default` helpers resolve from the MaxScript project root.
- Moved `Geometry-Diagnostics.ini` persistence from the 3ds Max user-scripts directory to the Geometry Diagnostics script folder.
- Updated `Geometry-Diagnostics.ms` and `Geometry-Diagnostics-UI.ms`; backend and tests are unchanged.


## 2026-10-06 — Project 0.04


- Updated `debug/Geometry-Diagnostics-Test.ms` so the VertexPaint modifier test targets only evaluated vertex IDs created by Edit Poly tessellation, instead of repainting base vertex `1`.
- The modifier-path validation now verifies every tessellation-created evaluated vertex receives the diagnostic orange color while the Editable Poly base channel remains untouched.
- Added `clearListener()` immediately before the test execution queue so every test run starts with clean Listener output.


## 2026-10-06 — Project 0.02


- Reworked geometry-vertex painting to resolve every channel-0 face-corner map vertex explicitly from Editable Poly polygon topology.
- Removed dependence on implicit geometry-vertex/map-vertex ID correspondence for geometry-vertex painting.
- Added map-resolution validation for Integer, BitArray, and Array geometry-vertex targets.
- Extended `debug/Geometry-Diagnostics-Test.ms` to verify geometry vertex `1` fans out to map vertices `#(1, 9, 22)`, changes only those three colors, preserves map topology, restores the original white map, and rebuilds the final visual state.


## 2026-10-06 — Project 0.01


- Project 0.01: created the first Geometry Diagnostics Tool package.
- Added the direct Editable Poly channel-0 paint backend with reversible paint-session backup/restore.
- Added geometry-vertex and face-corner public paint functions without assuming geometry-vertex IDs equal map-vertex IDs.
- Added a generated six-face Editable Poly test box with 24 fully split channel-0 map vertices and six independent face colors.
- Added the standalone UI with canonical .NET tool title/restart button, test creation, paint, restore, and channel dump controls.
- Added `debug/Geometry-Diagnostics-Test.ms` with one executable numbered test workflow and inspectable undo stages.
- No mesh diagnostics are implemented yet; version 0.01 proves the paint/display layer only.
- Project 0.03: added automatic VertexPaint modifier routing when a node has a modifier stack.
- Added a tool-owned `PaintLayerMod` on channel 0 that paints evaluated geometry without changing the Editable Poly base channel.
- Added safe removal of only the Geometry Diagnostics paint layer while preserving unrelated modifiers.
- Added an Edit Poly tessellation test proving the evaluated topology changes, VertexPaint paints above it, and the 24-entry base color map remains untouched.