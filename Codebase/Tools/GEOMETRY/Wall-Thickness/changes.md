2026-10-07
- Wall Thickness 1.017: audit the remaining corner-special-case paths for the same N-level vertical-loop rule without adding any new corner classification.
- Generalize ordinary / non-mirrored FIX T EDGE CORNERS cases to use the same directly connected anchor->continuation source-chain collector already used by segmented T-Corners, so one native ConnectEdges pass crosses every stacked strip level instead of stopping after two levels.
- Generalize the existing FIX INNER CORNERS lower-opening boundary guard from exactly two stacked source members to any directly connected stack with two or more levels; preserve the same lowest-member protection while leaving the later 3+/2/1, exact-T-stack, and general stack repair rules unchanged.
- Confirm by code audit that the rotation-invariant 3+/2/1 repair, exact vertical T-stack repair, and general vertical-stack alignment already iterate all stack members, while FIX OUTER CORNERS remains edge-driven and has no vertical-level count assumption.
- Keep the genuinely two-member parallel-strip branch as a two-member rule; when additional levels exist the existing >=3 stack rules remain the authority.
- Update Wall-Thickness-Test.ms to 0.021 / project 1.017 and add TEST PART 21 for the N-level corner-rule audit.

2026-10-07
- Wall Thickness 1.016: restore the confirmed 1.008 T-Corner topology rule and remove the 1.014/1.015 terminal-propagation experiment; no new corner classification or endpoint rule is introduced.
- Generalize only the number of vertical strip segments inside the same detected T-Corner: follow the directly connected source anchor->continuation X/Y stack, select the branch plus every corresponding strip cross-edge in the same native ConnectEdges operation, and preserve the original source-chain order.
- Preserve the stable two-level behavior exactly when the corner has only two source levels. For additional segmented levels, the same cut operation scales to N levels, with final per-case topology +N vertices / +(N-1) polygons / +(2N-1) edges after the existing upper-cut weld.
- Restore correctness-critical T-edge Edit Poly binding before native ConnectEdges, DivideEdge, ConnectVertices, MoveSelection, and weld work instead of relying on the optimized cached modifier-panel state; broader UI/batch/QUIET behavior remains unchanged.
- Treat EditPolyMod.DivideEdge return values as status only. Rebind the exact T-edge modifier after Commit and resolve the appended vertex from verified +1 vertex / +0 polygon / +1 edge topology deltas, avoiding the `OK` return-type failure.
- Update Wall-Thickness-Test.ms to 0.020 / project 1.016 and replace the experimental terminal-propagation regressions with checks for stable segmented T-Corner scaling and per-operation Edit Poly rebinding.

2026-10-07
- Wall Thickness 1.015: fix FIX T EDGE CORNERS on multi-level T-Corners where the mirrored cut must continue beyond the first upper/lower strip pair to the terminal corner edge.
- Re-synchronize the already-current T-edge Edit Poly after topology-changing commits by reasserting PrimaryNode / stack-selection / selectMode / cage / component-level state without reselecting the same modifier; this fixes live GetNum* collapsing to zero immediately after DivideEdge.
- Walk the complete same-X/Y source corner stack from anchor through continuation to its terminal level. Divide every remaining source-to-generated cross-edge at 50 percent, connect each new cut vertex to the previous cut vertex, and log the live target edge IDs so cases like Object021 naturally propagate through the edge identified at runtime as E45 instead of hard-coding an edge number.
- Move every propagated cut vertex onto the fixed anchor X/Y while preserving its own Z, and generalize the expected topology deltas by the number of extra propagated corner levels.
- Keep the existing ordinary T-edge path, branch-anchor planning, weld contract, material correction, EXTRUDE, and FIX INNER CORNERS behavior unchanged.
- Update Wall-Thickness-Test.ms to 0.019 / project 1.015 and add TEST PART 20 for post-topology context synchronization plus terminal corner-edge propagation.

2026-10-07
- Wall Thickness 1.014: fix the T-Corner mirror DivideEdge runtime contract exposed by `No ">" function for OK`; treat EditPolyMod.DivideEdge as a status-only native call, commit it, verify exact live topology deltas, and resolve the appended vertex from the post-commit vertex count.
- Propagate the mirrored T-Corner cut through the full ordered local chain `branch anchor -> upper cut -> lower cut`; reuse existing segments, create every missing consecutive edge segment, and verify the chain live before move/weld continues.
- Keep the established mirror pre-weld topology contract (+3 vertices / +2 polygons / +5 edges from case start) and the existing move/weld/material stages unchanged.
- Revoke the attempted 1.013 STABLE designation after runtime failure; restore the versioned filename to `Wall-Thickness_1.013.ms`.
- Update `Wall-Thickness-Test.ms` to 0.018 / project 1.014 and add TEST PART 19 for DivideEdge status handling and explicit T-Corner edge-chain propagation.

2026-10-07
- Wall Thickness 1.013: optimize Modify-panel stack activation by reusing the already-current exact stack item on the already-selected wall instead of reselecting/rebinding the same modifier repeatedly.
- Centralize stack activation in `ensureWallThicknessStackItemCurrent()`: only switch to Modify mode, select the wall, call `SetPrimaryNode`, and call `modPanel.setCurrentObject` when the requested node/modifier context actually differs.
- Reuse the guarded activation helper in shared Edit Poly preprocessing/component-selection paths and keep `subObjectLevel` unchanged when the requested level is already active.
- Upgrade the existing persistent QUIET control to `QUIET MODE`: suppress routine Wall Thickness Listener trace, including FIX INNER CORNERS/T-edge progress diagnostics, while preserving required errors, exceptions, verification failures, and recovery warnings.
- Update `Wall-Thickness-Test.ms` to 0.017 / project 1.013 and add TEST PART 18 for guarded modifier activation, sub-object-level reuse, QUIET MODE trace gating, and fatal-diagnostic preservation.

2026-10-07
- Wall Thickness 1.012: add a combined multi-object `EXTRUDE + FINISH` action in the EXTRUDE group.
- Run each selected wall sequentially through `EXTRUDE / UPDATE` with automatic FIX INNER CORNERS, then run the existing FINISH WALLS / FIX T EDGE CORNERS backend only when extrusion succeeds.
- Reuse the 1.011 batch contract: suppress intermediate modal dialogs for multi-object runs, collect failures, select all failed walls at completion, and show one final summary; when nothing fails, keep the last successful T-edge modifier active.
- Render `EXTRUDE + FINISH` as a WinForms `.NET` button using the shared dark button style with semantic green foreground text.
- Update `Wall-Thickness-Test.ms` to 0.016 / project 1.012 and add TEST PART 17 for the combined batch button, green .NET styling, sequential backend calls, and final failed-object handling.

2026-10-07
- Wall Thickness 1.011: suppress intermediate modal message boxes during multi-object EXTRUDE / UPDATE, FINISH WALLS, EXTRUDE ONLY, FIX INNER CORNERS, FIX T EDGE CORNERS, and FIX OUTER CORNERS batches.
- Keep single-object modal behavior unchanged through one shared `showWallThicknessMessage()` gate; the automatic FIX INNER CORNERS failure message is now silent while a batch continues.
- Collect failed nodes for every multi-object batch, select all failed objects at completion, and show one final summary dialog. When a T-edge batch has no failures, keep the previous last-successful T-edge modifier selection behavior.
- Restore the batch-silent flag before rethrowing any unexpected batch exception so later dialogs cannot remain accidentally suppressed.
- Update `Wall-Thickness-Test.ms` to 0.015 / project 1.011 and add TEST PART 16 for batch modal suppression and failed-object selection.

2026-10-07
- Wall Thickness 1.010: start Edit Poly interaction optimization for FIX T EDGE CORNERS without changing geometry/topology algorithms.
- Bind `WALL THICKNESS FIX T EDGE CORNERS` to the Command Panel once per wall, then remove repeated `select` / `max modify mode` / `SetPrimaryNode` / `modPanel.setCurrentObject` calls from ConnectEdges and per-vertex move helpers.
- Centralize T-edge component-level selection; `subObjectLevel` is now assigned only when the requested Vertex/Edge/Face level differs, so consecutive vertex moves no longer toggle the global sub-object state repeatedly.
- Route the mirrored T-Corner ConnectVertices selection through the same already-bound T-edge selection helper. Preserve the original modifier activation at the compound-operation boundary and restore the prior UI state once at the end.
- Update `Wall-Thickness-Test.ms` to 0.014 / project 1.010 and add TEST PART 15 guarding the single-bind T-edge Edit Poly session.

2026-10-07
- Wall Thickness 1.009: add a `FINISH WALLS` button directly below `EXTRUDE / UPDATE` in the EXTRUDE group.
- `FINISH WALLS` is a UI copy of the existing multi-object `FIX T EDGE CORNERS` action and uses the same backend/selection behavior.
- Keep the original manual `FIX T EDGE CORNERS` button unchanged in MANUAL-PROCESS; no geometry algorithm changed.
- Update `Wall-Thickness-Test.ms` to 0.013 / project 1.009 and add TEST PART 14 for the duplicated finishing action and placement.

2026-10-07
- Wall Thickness 1.008 marked STABLE after runtime confirmation of the corrected FIX T EDGE CORNERS move/weld path on the 180-degree-Y / upside-down fixture. No code change and no version bump; canonical Wall-Thickness.ms remains 1.008.

2026-10-07
- Wall Thickness 1.008: fix FIX T EDGE CORNERS move/weld on walls rotated 180 degrees around Y by keeping Edit Poly `MoveSelection` deltas in the same local/object coordinate domain returned by `EditPolyMod.GetVertex`.
- Remove the extra `objectTransform` conversion from `moveWallThicknessTEdgeVertexToPosition()`. The failing mirrored fixture proved that conversion reversed the required local X direction: the branch anchor moved `+0.01009` instead of the mirrored `-0.01009`, leaving the cut vertices separated so the weld could not execute.
- Keep detector, topology creation, T-Corner planning, weld operation, extrusion, FIX INNER CORNERS, material handling, and multi-object wrappers unchanged; once the cut vertices reach the anchor, the existing weld path is reused unchanged.
- Update `Wall-Thickness-Test.ms` to 0.012 / project 1.008 and add TEST PART 13 guarding the local/object-domain move-delta contract.

2026-10-07
- Wall Thickness 1.007: make the canonical `Wall-Thickness.ms` self-contained by embedding the existing `planWallThicknessInnerCorners()` implementation directly in the entry script.
- Remove the startup dependency on sibling `Wall-Thickness-Inner-Corners.ms`, which could be absent from a local Google Drive mirror and abort launch before the UI opened.
- Inner-corner planning behavior is unchanged; the embedded function is copied from the existing extracted module without geometry-algorithm edits.
- Update `Wall-Thickness-Test.ms` to 0.011 / project 1.007 and add TEST PART 12 to ensure the canonical production script contains the planner and no longer loads/throws on the external module.

2026-10-07
- Wall Thickness 1.006: fix the final FIX T EDGE CORNERS cut-edge move on walls rotated 180 degrees around Y / upside down in local space.
- Keep the proven transformed single-vertex Edit Poly move path and move the upper and lower cut vertices independently to the branch-anchor XY instead of relying on one shared two-vertex MoveSelection delta.
- Preserve each cut vertex local Z exactly; no detector, planner, extrusion, inner-corner, T-Corner topology, material, or multi-object wrapper logic changed.
- Update `Wall-Thickness-Test.ms` to 0.010 / project 1.006 and add TEST PART 11 for the 180-degree-Y live T-edge cut move.

2026-10-07
- Wall Thickness 1.005: make EXTRUDE / UPDATE, EXTRUDE ONLY, FIX INNER CORNERS, FIX T EDGE CORNERS, and FIX OUTER CORNERS process every selected wall sequentially, one object at a time.
- Snapshot the selected node array before processing so per-object selection changes do not truncate the batch; snapshot thickness and CHANGE MATERIAL IDS UI values before EXTRUDE/FIX INNER loops so selection callbacks cannot change later-object inputs.
- Keep every existing single-object geometry/fix function unchanged; each object retains its existing undo/error/recovery behavior.
- Restore the original multi-selection after EXTRUDE, EXTRUDE ONLY, FIX INNER CORNERS, and FIX OUTER CORNERS. For FIX T EDGE CORNERS, keep the last successfully repaired wall active with its canonical T-edge Edit Poly selected.
- Update `Wall-Thickness-Test.ms` to 0.009 / project 1.005 and add TEST PART 10 for the multi-object EXTRUDE/FIX UI wrappers.

2026-10-07
- Wall Thickness 1.004 marked STABLE after runtime confirmation of the transformed-node T-Corner repair. No code change and no version bump; the canonical development source remains 1.004.

2026-10-07
- Wall Thickness 1.004: fix FIX T EDGE CORNERS coordinate-space handling on translated/rotated/scaled nodes by reconstructing authoring targets from the current live Edit Poly endpoints plus the stored branch fraction instead of reusing absolute positions from the baked planner copy.
- Convert live Edit Poly `MoveSelection` deltas through `source_node.objectTransform`, matching the verified T-edge movement path; committed positions are still verified in the live Edit Poly coordinate domain.
- Complete the paired T-Corner mirror topology path observed at runtime: its second ConnectEdges pass legitimately adds only two strip vertices / one polygon / three edges, so explicitly divide the mirror branch at the planned fraction and connect that anchor to the new upper cut before the normal move/weld stage.
- Preserve the final per-side +2 vertex / +1 polygon / +3 edge repair contract and keep all topology edits inside the same removable `WALL THICKNESS FIX T EDGE CORNERS` Edit Poly.
- Update `Wall-Thickness-Test.ms` to 0.008 / project 1.004 and add TEST PART 9 for transformed-node live-coordinate movement.

2026-10-07
- Wall Thickness 1.003: fix T-Corner detection/authoring after the 1.002 runtime log showed only one base T case on the two-sided corner fixture.
- Treat a source T anchor with exactly four incident source edges as a corner endpoint: keep the proven first T plan, then synthesize the mirrored side by swapping its branch and continuing-plan edges and solving the mirrored source-edge intersection.
- Pair T-Corner cases by the same source anchor/continuation with swapped branch/plan neighbors instead of the incorrect reciprocal-endpoint rule from 1.002.
- Author the mirrored side in the same `WALL THICKNESS FIX T EDGE CORNERS` Edit Poly using the live upper/lower sub-edges preserved by the primary cut, so the second case does not try to reuse the original strip edges after they have been split.
- Preserve the ordinary mid-wall T-junction path unchanged; only degree-4 source anchors can expand into the mirrored T-Corner case.
- Update `Wall-Thickness-Test.ms` to 0.007 / project 1.003 and correct TEST PART 8 for same-anchor mirrored T-Corner pairing.

2026-10-06
- Wall Thickness 1.002: add paired T-Corner support for two reciprocal T-junction repairs on opposite ends of the same source branch edge.
- Fix the live T-edge writer so the new branch anchor is moved from ConnectEdges' temporary 50% midpoint to the exact intersection position already computed by the planner before the vertical strip cut is aligned and welded.
- Keep the existing ConnectEdges topology sequence and per-case +2 vertex / +1 polygon / +3 edge contract; all cases are still planned before the first topology edit and authored in one removable `WALL THICKNESS FIX T EDGE CORNERS` Edit Poly.
- Add explicit reciprocal-case T-Corner pairing diagnostics and `testWallThicknessTCornerSelected()` for the selected two-sided corner fixture.
- Update `Wall-Thickness-Test.ms` to 0.006 / project 1.002 and add TEST PART 8 for reciprocal T-Corner pairing plus exact planned-anchor movement.

2026-10-06
- Wall Thickness 1.001: fix the multi-object `REMOVE MODIFIERS` catch rethrow so it uses MAXScript's required bare `throw()` syntax instead of the invalid `throw exception_text`.
- Preserve the existing exception logging and editing-state restoration before rethrowing; no removal behavior, T-edge behavior, geometry, topology, or material logic changed.
- Update `Wall-Thickness-Test.ms` to 0.005 / project 1.001 and add TEST PART 7 to guard against reintroducing the invalid argument-bearing catch rethrow.

2026-10-06
- Wall Thickness 1.000: make `REMOVE MODIFIERS` process every currently selected object in one undo/redraw batch instead of requiring exactly one selected wall.
- Preserve unrelated modifiers and base geometry on every selected node; the UI log reports reset and failed object counts.
- After a successful `FIX T EDGE CORNERS`, select the canonical `WALL THICKNESS FIX T EDGE CORNERS` Edit Poly as the current modifier in the Modify panel.
- Keep the T-edge geometry/topology/material algorithm and its existing result tuple unchanged; modifier-selection failure is reported as a UI warning without fabricating geometry failure.
- Update `Wall-Thickness-Test.ms` to 0.004 / project 1.000, add multi-object REMOVE MODIFIERS and T-edge modifier-selection tests, and extend the focused T-edge regression to require the new modifier to remain current.
- Preserve the three-decimal version display at the 0.999 -> 1.000 boundary.

2026-10-06
- Wall Thickness 0.999: fix the shared .NET tool-title restart helper path for the current `Codebase\Tools\GEOMETRY\Wall-Thickness` repository layout.
- Resolve `UI\Default\ScriptReload.ms` and `UI\Default\ToolTitleButton.ms` from the shared MaxScript agent root; retain the legacy `Modules` relative layout as a fallback.
- Keep the 0.998 .NET `WALL THICKNESS` title button and restart behavior unchanged; no geometry, PREP, EXTRUDE, FIX INNER CORNERS, FIX T EDGE CORNERS, material, or cleanup behavior changed.
- Update `Wall-Thickness-Test.ms` to 0.003 / project 0.999 and add TEST PART 4 for shared UI helper path resolution and loaded restart globals.

2026-10-06
- Wall Thickness 0.997: second cleanup/refactor pass; merge duplicated implementations while preserving existing public function names and behavior.
- Centralize exact modifier lookup behind one shared name/class/property-aware helper; existing specialized getters remain as compatibility wrappers.
- Merge duplicated boolean node-property parsing/writing for FIX INNER CORNERS and Material ID mode.
- Merge generated-only and all-simple open-loop traversal into one shared loop collector with the original generated-vertex filter preserved by wrapper.
- Merge full and pre-extrude STL validation into one shared check loop while preserving each validator's original test set, redraw behavior, messages, failure retention, and result tuple.
- Merge PRE-PROCESS preparation into one shared core; the existing normal/select wrappers preserve whether the current PREP stage is rebuilt or retained.
- Merge T-edge edge-record construction, coplanar source-region grouping, and source-anchor detection into shared live/base cores. Edit Poly and baked Editable Poly topology-editing operations remain separate because their native APIs and destructive behavior differ.
- Reduce production source from 508,161 bytes / 8,935 lines in 0.996 to 463,525 bytes / 8,496 lines without removing public entry points.
- Update `Wall-Thickness-Test.ms` to 0.002 / project 0.997 and add TEST PART 3 for shared modifier lookup filters, open-loop filtering, and shared T-edge core availability.

2026-10-06
- Wall Thickness 0.996: first structural cleanup pass only; production geometry algorithms are unchanged.
- Remove all whitespace-only blank lines from the production source and extracted code files.
- Move regression tests and test-fixture builders out of the production script into `Wall-Thickness-Test.ms`; remove the production TESTS rollout group and its callbacks.
- Move `planWallThicknessInnerCorners()` unchanged into `Wall-Thickness-Inner-Corners.ms` and load that module from the production script at the original definition boundary.
- Add two lightweight structural checks at the end of `Wall-Thickness-Test.ms` to verify the production/module load and representative extracted test functions.
- Pass 2 duplication merging is intentionally deferred.

2026-10-05
- Wall Thickness 0.995: allow the main dialog to dock on the left or right side of 3ds Max while remaining floatable.
- Register the rollout as a CUI dialog bar with left/right docking and floating enabled; top/bottom docking remains disabled.
- Before reloading/destroying an existing docked rollout, unregister it from CUI first so RESTART TOOL continues to work with docked instances.
- Process posted window messages once after dialog creation/registration so the dialog paints immediately.
- No geometry, EXTRUDE, PREP, FIX INNER CORNERS, FIX T EDGE CORNERS, material, or QUIET behavior changed.

2026-10-04
- Wall Thickness 0.994: extend QUIET mode to suppress per-vertex EXTRUDE diagnostics.
- When QUIET is enabled, the automatic inner-corner pass no longer emits one `SOURCE VERTEX` record per source vertex or one `NON-DESTRUCTIVE FIX TARGET` record per corrected vertex.
- EXTRUDE summaries, topology mismatch messages, failures, and other error diagnostics remain visible.
- Geometry, Reset XForm, FIX INNER CORNERS, and FIX T EDGE CORNERS behavior are unchanged.

2026-10-04
- Wall Thickness 0.993: add a persistent `QUIET` checkbutton directly below `RESTART TOOL`.
- QUIET suppresses the routine Listener line emitted by `setWallThicknessUILog` after each UI action while keeping the on-screen LOG field updated.
- Errors and diagnostic/debug output remain visible so failures are not hidden.
- QUIET is stored in `Wall-Thickness.ini` and restored when the tool is reopened or restarted.
- No geometry, EXTRUDE, FIX INNER CORNERS, FIX T EDGE CORNERS, material, or preprocessing algorithms changed.

2026-10-04
- Wall Thickness 0.992: make PREP `01 RESET XFORM` a true hard reset that runs on every click instead of skipping objects that were previously marked XFormed.
- PREP 01 now executes `ResetXForm`, collapses the full current stack to bake that transform, then executes `ResetPivot` so the pivot returns to its creation position/orientation before Wall Thickness processing.
- The per-object `WallThickness_<handle>_XFormed` user property remains as a completion marker, but it no longer blocks future explicit PREP 01 hard resets.
- PREP 01 now reports real exceptions in the Listener instead of silently swallowing reset failures.
- Updated the PREP 01 tooltip/status and regression test: a second run must execute again, restore deliberately moved pivots, reset scale, and bake a modifier added before the second hard reset.
- EXTRUDE, FIX INNER CORNERS, and the confirmed stable FIX T EDGE CORNERS geometry paths from 0.991 are unchanged.

2026-10-04
- Wall Thickness 0.991: fix EXTRUDE on valid Editable Poly sources that contain dead sub-object structures.
- The failing case reported `Edit Poly verts 30 | snapshot verts 25 | Edit Poly polygons 16`: the Edit Poly count included dead vertex slots while `snapshotAsMesh` compacted them to the 25 live vertices. The existing Wall Thickness mapping requires contiguous source IDs because generated vertices are addressed as `source_id + source_vert_count`.
- Before creating `WALL THICKNESS`, when the source is a bare Editable Poly with no remaining modifiers, inspect `polyop.GetHasDeadStructs` and call the documented `polyop.CollapseDeadStructs` only when dead structures exist. Verify no dead structures remain and log the before/after vertex-slot counts.
- Keep the 0.990 live Edit Poly vs snapshot topology guard after compaction. FIX INNER CORNERS and FIX T EDGE CORNERS geometry/material logic are unchanged.
- Runtime confirmation on `VERTICAL SEGMENTS - ERROR` is pending.

2026-10-04
- Wall Thickness 0.990: fix EXTRUDE falsely reporting `Source topology changed while creating thickness` on valid vertically segmented Editable Poly sources.
- Capture the empty `WALL THICKNESS` Edit Poly vertex count, polygon count, polygon vertex loops, and source Material IDs before any additional `snapshotAsMesh` evaluation. The live Edit Poly remains the polygon/topology-ID authority.
- Use the TriMesh snapshot only for world-space offset positions/normals and open-border discovery, then compare its vertex count against the already captured live Edit Poly count. A real mismatch still aborts and now prints both counts to the Listener.
- Rebind the same Edit Poly after snapshot evaluation before `CreateVertex` / `CreateFace`, preventing snapshot evaluation from leaving the live writer in a stale local topology context.
- FIX INNER CORNERS and the confirmed working FIX T EDGE CORNERS geometry path are unchanged. Runtime confirmation on `VERTICAL SEGMENTS - ERROR` is pending.

2026-10-04
- Wall Thickness 0.984: remove the failing `prepareWallThicknessTEdgeStackModifier()` readiness gate and drive FIX T EDGE CORNERS with the verified `EPoly-Stack-Test_1.10.ms` stacked Edit Poly sequence directly on the real wall node.
- FIX T EDGE CORNERS now creates exactly one normal `WALL THICKNESS FIX T EDGE CORNERS` Edit Poly above `WALL THICKNESS`: configure it, `addModifier`, select the node, enter Modify mode, `SetPrimaryNode`, make the modifier current with `node:source_node`, and immediately read/write the lower-stack topology through node-scoped Edit Poly APIs.
- Keep the working three-edge ConnectEdges operation unchanged: select the live branch/upper/lower edge IDs resolved from endpoint vertices, use one segment with zero pinch/slide, `SetOperation #ConnectEdges`, `Commit`, refresh, and verify the exact +3 vertex / +2 polygon / +5 edge intermediate topology.
- Resolve the three new vertices from that same live Edit Poly, then move anchor/upper/lower vertices with the verified node-scoped vertex-selection + `MoveSelection` + `Commit` + `GetVertex` read-back pattern. Upper/lower cuts share anchor X/Y while each preserves its own Z.
- Weld the coincident upper cut into the anchor with normal Edit Poly `WeldVertices`, verify the stable final +2 vertex / +1 polygon / +3 edge contract per T case, and retain the proven generated-side Material ID correction from the stable implementation.
- Remove unused T-edge authoring-copy, blind-selection, probe-ID writer, and Cut helper functions from the execution architecture. Baked probes remain only in the read-only regression comparison; they are never topology-ID authorities for the live writer.
- Temporarily remove only the deformation-only `WALL THICKNESS FIX INNER CORNERS` while inserting T-edge, then restore the same modifier above T-edge without changing its logic. On T-edge failure, preserve the failed Edit Poly in the stack for inspection whenever FIX INNER CORNERS was successfully restored.
- Update `testWallThicknessTEdgeCornersSelected()` for the single-modifier stack and retain checks for unchanged Editable Poly base, exact topology delta, stack order, and disabling T-edge restoring the exact pre-T evaluated geometry/material result. Runtime 3ds Max confirmation is still required; no runtime success is claimed by this source-only change.

2026-10-04
- Wall Thickness 0.983: replace the failed collapsed-copy / local-data-transfer T-edge authoring architecture with direct stacked Edit Poly authoring on the real wall object, following the proven `EPoly-Stack-Test_1.10.ms` workflow.
- Each T-edge case now adds a normal `Edit_Poly` directly above `WALL THICKNESS`, binds it with `addModifier -> SetPrimaryNode -> modPanel.setCurrentObject node:source_node`, then reads and edits lower-stack topology directly through node-scoped Edit Poly getters and selections. No author copy, no collapse, no `addModifierWithLocalData`, and no probe-derived component IDs are used by the writer.
- Keep the working three-edge `#ConnectEdges` operation and verify the exact +3 vertex / +2 polygon / +5 edge pre-weld topology directly from the same stacked modifier. Resolve the three new vertices from the modifier itself, move them through node-scoped stored vertex selections, weld the upper cut to the branch anchor, and verify the stable +2 vertex / +1 polygon / +3 edge final contract directly in Edit Poly.
- Temporarily remove only the deformation-only `FIX INNER CORNERS` layer while T-edge topology is authored, then restore it above the new T-edge Edit Poly layer(s). `FIX INNER CORNERS` planning/behavior is unchanged.
- Runtime confirmation is still required on Object015 in 3ds Max.

2026-10-04
- Wall Thickness 0.982: preserve the failed temporary T-edge authoring copy instead of deleting it when FIX T EDGE CORNERS aborts, while still restoring the real wall to the stable WALL THICKNESS + FIX INNER CORNERS state.
- Rename the preserved debug object to `<source> T EDGE FAILED 0.982` and its active authoring Edit Poly to `WALL THICKNESS FIX T EDGE CORNERS FAILED`, so the exact partial topology can be inspected in 3ds Max after the failure instead of being erased by rollback cleanup.
- Successful runs still delete the temporary authoring copy exactly as before. No T-edge topology algorithm, FIX INNER CORNERS logic, geometry tolerance, or material rule changed in this release.
- Runtime success remains pending; this release is intentionally diagnostic so the next failing stage can be inspected directly.

2026-10-04
- Wall Thickness 0.981: keep the working ConnectEdges topology creation unchanged and fix the following vertex-move stage using the same node-scoped Edit Poly selection workflow.
- `setWallThicknessTEdgeModifierSelectionBlind` now binds the current Edit Poly to the target node, clears/selects components with `node:source_node`, reads the stored selection back with `GetSelection ... node:source_node`, and aborts if the requested selection was not actually stored.
- Refresh/redraw immediately after `MoveSelection` + `Commit` before the collapsed verification probe is created. FIX INNER CORNERS and the T-edge topology contract remain unchanged.
- Runtime confirmation is still required on Object015.

2026-10-04
- Wall Thickness 0.980: replace the failed T-edge DivideEdge/Cut topology writer with the documented Edit Poly edge-selection Connect workflow supplied from the working 3ds Max path.
- On the collapsed Editable Poly authoring copy, select the mapped branch, upper-strip, and lower-strip edges together through `EditPolyMod.Select ... node:` and execute one `#ConnectEdges` operation with one segment, zero pinch, and zero slide. This creates the exact pre-weld topology contract in one commit: +3 vertices, +2 polygons, +5 edges.
- Resolve the three created vertices only from the collapsed polygon result, move the branch anchor to the planner target, align the upper/lower cut vertices to that anchor XY while preserving Z, then keep the existing target-weld/material/transfer verification path. No operation status value is interpreted as a vertex ID.
- FIX INNER CORNERS and the T-edge detector/planner remain unchanged. Runtime success remains pending Object015 confirmation in 3ds Max.

2026-10-04
- Wall Thickness 0.979: replace the failing EditPolyMod.DivideEdge/CreateEdge T-edge authoring sequence with the documented Edit Poly Cut workflow on the collapsed authoring copy.
- Keep FIX INNER CORNERS and T-edge detection/planning unchanged. CUT 1 starts on the mapped T branch edge at the planned anchor and ends on the upper strip cross-edge midpoint; CUT 2 starts from that new upper cut vertex and ends on the lower strip cross-edge midpoint.
- Resolve every created vertex from the next collapsed Editable Poly probe by position/topology instead of trusting the native return value. `GetLastCutEnd()` is diagnostic only. Verify the exact +3 vertex / +2 polygon / +5 edge pre-weld contract, then keep the existing re-ortho, target-weld, material correction, local-data transfer, and final +2/+1/+3 contract.
- Runtime success remains pending Object015 confirmation in 3ds Max.

2026-10-04
- Wall Thickness 0.976: keep the 0.975 collapsed-copy/local-data transfer architecture and fix the authoring Edit Poly aborting before topology work because its geometry getters were queried before the modifier had an evaluated local context.
- Restore the proven 0.943 Edit Poly evaluation bootstrap on the collapsed authoring copy: make the modifier current, force one evaluated-stack request, discard that temporary TriMesh immediately, then read vertex/edge/face counts from the Edit Poly itself. The snapshot is evaluation-only and is never used for topology IDs.
- Keep FIX INNER CORNERS and the proven T-edge divide/connect/re-ortho/weld/material sequence unchanged. Add `FIX T EDGE CORNERS AUTHOR PREPARE` diagnostics so Object015 reports the exact Edit Poly vertex/polygon/edge counts immediately before authoring begins.
- Runtime success remains pending 3ds Max confirmation.

2026-10-04
- Wall Thickness 0.975: keep FIX INNER CORNERS unchanged and replace direct T-edge topology authoring on the real stack with a collapsed-copy/local-data transfer workflow.
- Duplicate the raw WALL THICKNESS result after temporarily removing only the deformation-only FIX INNER CORNERS layer, `collapseStack` the duplicate to Editable Poly, and require its Edit Poly modifier to expose the exact 1:1 polygon vertex/edge/face topology before any T-edge edit. No `snapshotAsMesh` topology identity is used in the T-edge planner/probe/author path.
- Author the proven 0.943/0.969 T-edge sequence on that collapsed copy: branch divide, both 50% strip divides, both connects, independent XY re-ortho with preserved Z, target weld, stable +2 vertex / +1 polygon / +3 edge contract, and generated-side material correction.
- Transfer the fully authored Edit Poly to the real object with Autodesk `addModifierWithLocalData`, so the modifier-local topology edits are cloned onto the identical evaluated WALL THICKNESS input instead of being authored against lower-modifier-generated topology. Verify the transferred result against a collapsed copy of the authored result for exact polygon topology/positions and face Material IDs before restoring FIX INNER CORNERS above it.
- Update `testWallThicknessTEdgeCornersSelected()` to use only collapsed Editable Poly copies for evaluated topology/position/material comparisons and to verify that disabling the single T-edge modifier restores the exact pre-T result. Runtime success is still pending Object015 confirmation in 3ds Max.

2026-10-04
- Wall Thickness 0.974: keep the working deformation-only FIX INNER CORNERS path unchanged and isolate the remaining non-destructive T-edge failure to topology creation in removable modifier history.
- Replace all persistent Edit Poly topology reads in FIX T EDGE CORNERS with temporary baked Editable Poly probes of the real evaluated stack. Probe vertex/edge/face IDs are mapped before each topology command and a fresh probe verifies the result immediately afterward.
- The persistent T-edge Edit Poly now executes only verified native EditPolyMod operations: DivideEdge, CreateEdge, MoveSelection, WeldVertices, and SetMaterial. No modifier hydration, Turn To Poly dependency, or zero-valued GetNumVertices/GetVertex precondition is used.
- Use one fresh FIX T EDGE CORNERS Edit Poly layer per planned T case so welded/dead internal slots from one case cannot contaminate IDs for a later case. Failure removes every tool-owned T-edge case layer and restores the original FIX INNER CORNERS modifier.
- Update the focused selected-wall regression to measure the +2 vertex / +1 polygon / +3 edge contract from baked polygon probes and to disable every T-edge case layer when verifying that the exact pre-T evaluated result is restored.

2026-10-04
- Wall Thickness 0.973: redesign FIX T EDGE CORNERS around separate planning and modifier execution instead of extending the failed 0.965-0.972 topology-interface experiments.
- Plan/detect on a temporary baked copy of the fully evaluated stable FIX INNER CORNERS result using the proven 0.969/0.959 base T-edge detector; the real source Editable Poly is never converted, collapsed, or written.
- Execute the persistent T-edge topology directly above the existing WALL THICKNESS Edit Poly. The first branch DivideEdge is addressed by an explicitly mapped unordered endpoint pair from WALL THICKNESS, without querying fresh T-edge modifier topology first; only after that real topology operation succeeds is the new modifier queried for subsequent live topology.
- Preserve the proven branch divide, 50% upper/lower strip divides, two connects, independent XY re-ortho with per-vertex Z preservation, target weld, +2 vertex / +1 polygon / +3 edge net contract, and generated-side material correction. Restore the unchanged deformation-only FIX INNER CORNERS modifier above T-edge after execution.
- Add focused stage diagnostics for planner cases, mapped edges, pre/post topology counts, returned divide vertex IDs, connect results, re-ortho positions, weld deltas, material correction, and exact Editable Poly base topology/position signature. Any failure removes the partial T-edge modifier and restores the stable lower state.
- Remove the unused experimental helper that rebuilt FIX INNER CORNERS as Edit Poly for T-edge. Keep legacy Turn To Poly cleanup only so old scene stacks are removed safely.
- Expand `testWallThicknessTEdgeCornersSelected()` to verify base preservation, modifier stack order, polygon topology deltas, and that disabling FIX T EDGE CORNERS restores the exact evaluated pre-T-edge geometry/material result. Runtime success is intentionally not claimed until the Object015 case is confirmed in 3ds Max.

2026-10-04
- Wall Thickness 0.972: fix the polygon-editable FIX INNER CORNERS layer used by the modifier T-edge workflow aborting before topology creation because `EditPolyMod.SetSelection` was incorrectly treated as a Boolean success result.
- Use the shared Edit Poly selection workflow (`.Select` via `selectModifierComponents`), verify the stored vertex selection with `GetSelection`, then apply the existing `MoveSelection` + `Commit` move and verify the moved vertex directly from the same Edit Poly topology.
- Keep the 0.969/0.955 T-edge divide/connect/re-ortho/weld/material sequence unchanged. Add precise inner-layer diagnostics so any remaining failure reports whether selection, move, or position verification failed.

2026-10-04
- Wall Thickness 0.971: fix the 0.970 modifier T-edge path failing on the unsupported Edit Poly operation token `#TransformVertex`.
- Remove all three `SetOperation #TransformVertex` calls from the new modifier workflow and use the same proven `EditPolyMod.MoveSelection ...` + `Commit` sequence already used elsewhere in the working codebase.
- Keep the 0.970 modifier-stack architecture, stable inner-corner planner, T-edge topology algorithm, world-space deltas, fallback restoration, and all geometry tolerances unchanged.

2026-10-04
- Wall Thickness 0.970: make `FIX T EDGE CORNERS` non-destructive again by keeping the full repair in the modifier stack instead of baking the evaluated wall to Editable Poly.
- Before T-edge topology editing, replace the normal deformation-only `WALL THICKNESS FIX INNER CORNERS` SimpleMod with an equivalent Edit Poly vertex-transform layer driven by the unchanged stable inner-corner planner; this removes the SimpleMod -> Edit Poly topology-interface break that caused 0.965-0.968 to report zero local topology.
- Build `WALL THICKNESS FIX T EDGE CORNERS` directly above that polygon-editable inner-fix layer, reuse the existing stable divide/connect/move/weld/material sequence, and verify the evaluated topology while leaving the Editable Poly base untouched. Modifier vertex moves now convert local target deltas through the object transform so rotated/transformed walls do not inherit the old coordinate-space bug.
- If the modifier build fails, remove the partial T-edge/inner Edit Poly layers and restore the stable WALL THICKNESS + deformation-only FIX INNER CORNERS state.

2026-10-04
- Wall Thickness 0.969: restore `FIX T EDGE CORNERS` from the known-good `Wall-Thickness_0.959-MVP.ms` implementation after the 0.965-0.968 modifier experiments stopped the pass from working.
- Restore the MVP execution contract exactly: ensure FIX INNER CORNERS first, bake the evaluated result to Editable Poly, then run the proven direct T-edge detect/divide/connect/move/weld/material repair sequence.
- Remove automatic preservation/recreation of the experimental T-edge modifier/input layers from EXTRUDE / UPDATE and thickness-spinner rebuilds. T-edge is again a manual finalizing pass; any leftover experimental T-edge helper layers are removed before rebuild/repair.
- Restore the MVP T-edge focused tests and update the button tooltip to describe the direct baked workflow. The newer non-destructive EXTRUDE / UPDATE and FIX INNER CORNERS behavior remains unchanged until T-edge is explicitly run.

2026-10-04
- Wall Thickness 0.968: initialize the dedicated FIX T EDGE CORNERS Edit Poly local component data before querying topology.
- After the Turn To Poly input helper is added, temporarily select incoming vertex 1 through the documented Edit Poly `.Select` workflow, verify the modifier stores that local selection, clear it, and return to Object level; no geometry operation is committed by this initialization.
- Keep the 0.955 T-edge detection/topology sequence and the non-destructive stack architecture unchanged. Add a clearer failure when Edit Poly local topology still does not match the evaluated T-edge input.

2026-10-04
- Wall Thickness 0.967: fix `FIX T EDGE CORNERS` receiving zero Edit Poly topology above the scripted FIX INNER CORNERS deformation layer.
- Add a `WALL THICKNESS FIX T EDGE INPUT` Turn To Poly conversion directly below `WALL THICKNESS FIX T EDGE CORNERS`; the pair is created, removed, and rebuilt together, while the source/base object remains untouched.
- Validate the new T-edge Edit Poly against the evaluated 16-vertex input after conversion, then run the existing stable 0.955 T-junction topology sequence unchanged. If no T-edge case is detected or the pass fails, both T-edge-owned modifiers are removed together.

2026-10-04
- Wall Thickness 0.966: fix the new non-destructive `FIX T EDGE CORNERS` modifier rejecting valid input when Edit Poly retains dead/internal vertex slots.
- Validate T-edge input and all vertex-count topology deltas using live Edit Poly vertices (`GetVertex != undefined`) instead of raw `GetNumVertices` slot count; keep face/edge checks and the stable 0.955 repair sequence unchanged.
- Add one T-edge input diagnostic showing evaluated vertex count, live Edit Poly vertex count, and raw vertex-slot count so any remaining stack-count mismatch is explicit.

2026-10-04
- Wall Thickness 0.965: make `FIX T EDGE CORNERS` a non-destructive dedicated `WALL THICKNESS FIX T EDGE CORNERS` Edit Poly modifier above the evaluated thickness/inner-corner stack instead of baking/collapsing the object to Editable Poly.
- Preserve the stable T-junction operation order and net topology contract (+2 vertices, +1 polygon, +3 polygon edges per repaired T), including the 0.955 skewed-cut behavior by moving the upper and lower cut vertices independently to the fixed-anchor X/Y before the target weld.
- Manual `FIX T EDGE CORNERS` still ensures `FIX INNER CORNERS` first. If the T-edge modifier already exists, later `EXTRUDE / UPDATE` and thickness-spinner rebuilds recreate it after rebuilding the lower stack; `EXTRUDE ONLY` removes it and leaves a raw thickness result.
- Update the focused T-edge regressions to validate the live Edit Poly modifier result and confirm the Editable Poly base topology remains unchanged.

2026-10-04
- Wall Thickness 0.964: make `EXTRUDE / UPDATE` the normal one-click pipeline: rebuild raw WALL THICKNESS, automatically run the stable FIX INNER CORNERS planner, and create `WALL THICKNESS FIX INNER CORNERS` only when correction targets exist.
- Rename the `POST-PROCESS` UI group to `MANUAL-PROCESS` and add `EXTRUDE ONLY` as its first action. `EXTRUDE ONLY` creates only the raw WALL THICKNESS result and keeps later spinner rebuilds raw-only until `FIX INNER CORNERS` is run manually.
- Keep the separate `FIX INNER CORNERS` button for manual/debug use; running it enables automatic inner-corner reapplication for later thickness updates.
- Fix `RESTART TOOL` to scan the current script directory for the highest `Wall-Thickness_<version>*.ms` release, preferring `-LATEST` when versions tie, instead of simply restarting the currently loaded file.

2026-10-04
- Wall Thickness 0.963: fix the non-destructive FIX INNER CORNERS SimpleMod coordinate-space bug exposed by Object018 runtime logging.
- The stable planner returns evaluated/world-space target positions; convert those targets through `inverse source_node.objectTransform` before storing them in the deformation modifier, because `SimpleMod.map` operates in object/modifier space.
- Verify corrected vertices directly against the original planner world targets instead of transforming those targets a second time. This removes the doubled object-translation offset while keeping the two-modifier non-destructive stack and 0.959 planner unchanged.

2026-10-04
- Wall Thickness 0.962: replace the failing in-Edit-Poly FIX INNER CORNERS write stage with a separate deformation-only scripted SimpleMod above WALL THICKNESS.
- Keep the proven 0.959 corner planner unchanged; store only planned generated vertex IDs and local-space target positions in `WALL THICKNESS FIX INNER CORNERS`, with no topology edits and no source/base-object writes.
- Thickness updates remove/rebuild the raw WALL THICKNESS modifier from the untouched source, rerun the planner, and recreate the FIX INNER CORNERS deformation modifier so corrected positions track the new thickness without accumulated deltas.
- Update inner-corner regression checks to inspect the evaluated two-modifier result; FIX T EDGE CORNERS remains separate and unchanged.
- The FIX INNER CORNERS layer is a scene-stored scripted modifier class; load the Wall Thickness script before opening scenes that contain it so 3ds Max can resolve the modifier definition.

2026-10-04
- Wall Thickness 0.961: fix the 0.960 non-destructive FIX INNER CORNERS rebuild after successful planning could return `#(FALSE, badEdges, 0)`.
- Preserve the MVP operation order inside the single WALL THICKNESS modifier: create and commit the complete raw extrusion topology first, then move only the planned generated corner vertices to their verified targets.
- Apply each planned move through the existing Edit Poly vertex-selection/move API with exact world-space delta and read-back verification; the base Editable Poly remains untouched and no second FIX INNER CORNERS modifier is created.
- Add rebuild-failure DUMP markers for topology, source movement, and target verification so a remaining runtime failure identifies the exact rejected stage.

2026-10-04
- Wall Thickness 0.960: redesign FIX INNER CORNERS as a non-destructive single-modifier rebuild.
- FIX INNER CORNERS now runs the stable 0.959 detection/planning logic against the evaluated raw WALL THICKNESS result, then rebuilds the same WALL THICKNESS Edit Poly with corrected generated vertex positions; it no longer collapses the stack, converts the node to Editable Poly, or writes source/base vertices.
- Store FIX INNER CORNERS state per wall so later thickness changes and EXTRUDE / UPDATE rebuild from the untouched source and automatically reapply the same corner fix at the new thickness.
- Preserve the per-wall CHANGE MATERIAL IDS mode during rebuilds; REMOVE MODIFIERS/reset clears the stored rebuild state.
- Keep FIX T EDGE CORNERS separate and topology-changing for now; this 0.960 redesign changes only EXTRUDE + FIX INNER CORNERS.
- Add `testWallThicknessNonDestructiveInnerFixUpdate()` and adapt inner-corner regressions to verify the live WALL THICKNESS modifier instead of a baked Editable Poly result.

2026-10-04
- Wall Thickness 0.959 marked MVP baseline after the current EXTRUDE and FIX INNER CORNERS behavior proved more stable across the tested corner cases, including rotated equivalents.
- No code change; `Wall-Thickness_0.959.ms` is renamed in place to `Wall-Thickness_0.959-MVP.ms`. `Wall-Thickness_0.959-LATEST.ms` remains the current working/latest pointer.

2026-10-03
- Wall Thickness 0.959: make the 3/2/1 vertical inner-corner stack repair rotation-invariant.
- For stacks containing a 3+ face junction member, a 2-face sharp corner member, and a 1-face terminal member, derive the generated corner XY from the intersection of the two neighboring generated border lines instead of trusting a member chosen by local Z order.
- Align only the generated members of that vertical stack to the solved XY while preserving every Z and topology; keep the existing two-member parallel-strip repair and stable T-edge pass unchanged.
- Add `testWallThicknessRotationInvariantInnerCorner()` with the uploaded 3-face / 8-vertex topology in both original and baked 180-degree Y-rotated orientations.

2026-10-03
- Wall Thickness 0.958: replace the one-shot `CHANGE MATERIAL IDS` button with a persistent checkbox in the EXTRUDE group.
- Checkbox OFF (default): EXTRUDE / UPDATE preserves source Material IDs and inherits them onto generated inner/strip faces. Checkbox ON: EXTRUDE / UPDATE assigns source/outer = 1, generated inner = 2, border strip = 3.
- Persist `CHANGE MATERIAL IDS` in `Wall-Thickness.ini`; toggling the checkbox changes the mode only and does not mutate existing geometry until EXTRUDE / UPDATE runs.
- Update `testWallThicknessChangeMaterialIds()` to verify both checkbox modes on a source quad with Material ID 7.

2026-10-03
- Wall Thickness 0.957: EXTRUDE / UPDATE no longer forces Material IDs 1/2/3. Existing source faces keep their Material IDs; generated inner faces inherit the corresponding source polygon Material ID; border strips inherit the adjacent source face Material ID.
- Add explicit `CHANGE MATERIAL IDS` action. It applies the previous convention only on demand: source/outer = 1, generated inner = 2, border strip = 3.
- Add `testWallThicknessChangeMaterialIds()` regression coverage: a source quad at Material ID 7 must stay ID 7 through EXTRUDE, then change to 1/2/3 only after the explicit action.

2026-10-02
- Wall Thickness 0.956: FIX INNER CORNERS now handles the special two-member vertical border corner where the upper source vertex belongs to three or more source faces and the lower endpoint belongs to one.
- When a clean parallel vertical strip confirms the lower endpoint carries the established extrusion offset, keep the lower generated XY fixed and move only the skewed upper generated corner to that XY while preserving Z and topology. The stable two-face T-stack rule remains unchanged.
- Add `testWallThicknessParallelStripCorner()` regression coverage for the uploaded four-quad case, including the clean reference strip equivalent to vertices `#{1,5,11,15}`.
- Wall Thickness 0.955 marked STABLE after both corner-fix passes passed the 3ds Max regression objects.
- Wall Thickness 0.955: FIX T EDGE CORNERS no longer requires the two newly divided vertical-cut vertices to already share XY before the move.
- Move each cut vertex independently to the exact fixed-anchor XY while preserving its own Z, then continue the existing coincident-edge collapse/weld path. This fixes valid cases where tiny independent strip-offset drift previously left the +3-vertex intermediate topology in the scene.
- Add `testWallThicknessTEdgeSkewedVerticalCut()` regression coverage with an explicit 0.02 mm pre-move XY mismatch against the existing 0.01 mm verification tolerance.
- Wall Thickness 0.954: FIX INNER CORNERS now repairs exact 3+ member vertical T stacks without depending on accidental XY drift to create a bad-edge candidate.
- Use source-face topology to identify continuing stack members versus one-face terminal members; keep the continuing generated XY fixed and move only terminal generated members to that XY while preserving Z and topology.
- Add `testWallThicknessExactVerticalStackInnerCorner()` regression coverage for a zero-XY-drift 3-member stack.
- Wall Thickness 0.953: add DEV DUMP instrumentation to FIX INNER CORNERS only; geometry behavior is unchanged from 0.952.
- Write each FIX INNER CORNERS run to `logs\Wall-Thickness-FIX-INNER-CORNERS-DUMP.txt` through the shared `Modules\DUMP\DUMP.ms` logger, mirrored to the 3ds Max Listener.
- Log source/generated vertex mapping, source-face use counts, border neighbors, protected/sharp classification, bad-edge tests, candidate/plan resolution, two-member T-stack accept/reject reasons, final planned targets, vertex writes, verification, and errors.
- FIX T EDGE CORNERS and EXTRUDE code are unchanged.

2026-10-01
- Wall Thickness 0.952: FIX INNER CORNERS now handles two-member vertical T stacks where the upper source vertex participates in multiple source faces and the lower member participates in only one.
- Propagate the already-correct upper generated XY to the lower generated member while preserving Z; this prepares the corner geometry so FIX T EDGE CORNERS only needs to add/connect its topology.
- Keep the 0.951 near-loop repair, 3+ member vertical-stack compatibility behavior, EXTRUDE, and FIX T EDGE CORNERS topology code unchanged.

2026-09-28
- Wall Thickness 0.951: restrict the 0.946 vertical-stack compatibility alignment to candidate source edges whose XY drift is within the existing 1 mm stack tolerance.
- Real horizontal near-loop FIX INNER CORNERS candidates now keep their exact planned 100 mm targets instead of being overwritten by unrelated/global vertical-stack alignment.
- Preserve the near-vertical stack alignment required by the working T-junction input; FIX T EDGE CORNERS code itself is unchanged.

2026-09-28
- Wall Thickness 0.950: revert the 0.948 global FIX INNER CORNERS anchor-freeze behavior because it changed the geometry consumed by the stable T-edge repair.
- Restore the 0.947 FIX INNER CORNERS planning/alignment geometry so FIX T EDGE CORNERS receives the same input it had before the regression.
- Keep the 0.947 near-loop detection, but update verification so a corner anchor that is itself legitimately planned to move is checked against its planned final position instead of being required to stay at its original position.
- Keep the 0.949 RESTART TOOL path fix; EXTRUDE and FIX T EDGE CORNERS code are unchanged.

2026-09-28
- Wall Thickness 0.949: fix RESTART TOOL so it reloads the exact script file that launched the current tool instead of preferring a sibling `Wall-Thickness.ms` that may be stale.
- Keep the fixed-name sibling only as a fallback when the original loaded source file no longer exists.
- Update the RESTART TOOL path test and tooltip for the corrected behavior; geometry, EXTRUDE, FIX INNER CORNERS, and FIX T EDGE CORNERS are unchanged.

2026-09-28
- Wall Thickness 0.948: keep every generated FIX INNER CORNERS anchor immutable for the complete repair pass.
- A generated vertex used as the fixed corner of any detected bad edge is excluded from both remote-stack target planning and later vertical-stack alignment.
- Keep 0.947 near-loop detection unchanged; FIX T EDGE CORNERS and EXTRUDE are unchanged.

2026-09-28
- Wall Thickness 0.947: restore FIX INNER CORNERS near-loop corner detection without changing EXTRUDE or FIX T EDGE CORNERS.
- Restore the precise 0.939 detection tolerances for source-plan neighbor filtering, sharp-corner classification, source-edge validity, and crossed-edge qualification.
- Keep the newer candidate-resolution and vertical-stack compatibility logic unchanged; only the first-pass inner-corner detector was adjusted.

2026-09-27
- Wall Thickness 0.946: refine FIX INNER CORNERS for vertical source stacks with small XY drift.
- Treat source-stack plan differences inside the existing 1 mm stack tolerance as vertical instead of using them as a 100 mm corner direction.
- For source XY stacks with three or more height members, keep the highest member's generated vertex fixed and align the other generated members to that XY while preserving each Z; this matches the EXTRUDED / AFTER FIX / CORRECT regression dump without changing topology.
- EXTRUDE 0.945 world/object-space fix and FIX T EDGE CORNERS logic are unchanged.

2026-09-27
- Wall Thickness 0.945: fix EXTRUDE world/object-space mixing on rotated or otherwise transformed nodes.
- `snapshotAsMesh` geometry is evaluated in world space, while `EditPolyMod.CreateVertex` receives object-space positions; generated offset targets are now converted through the inverse current `objectTransform` before vertex creation.
- The extrusion offset is still solved in world space, preserving the existing horizontal-thickness behavior and keeping identity-transform meshes unchanged.

2026-09-27
- Wall Thickness 0.943: replace the first FIX T EDGE CORNERS implementation with the exact snapshot workflow.
- Enforce the operation order `EXTRUDE -> FIX INNER CORNERS -> FIX T EDGE CORNERS`; when WALL THICKNESS is still live, FIX T EDGE CORNERS runs FIX INNER CORNERS first.
- Resolve the fixed anchor from the intersection of the source T branch with the corrected generated continuing-wall edge instead of placing it by a fixed travel distance along the branch.
- Build the local T topology exactly as in the reference snapshots: divide the branch edge, divide both strip cross-edges at 50%, connect anchor-to-upper-cut and upper-cut-to-lower-cut, then move the complete new vertical cut in X/Y onto the anchor while preserving both Z values.
- Target-weld the coincident upper cut vertex into the fixed anchor and verify the weld removes one vertex, one degenerate polygon, and two redundant edges. Net topology per repaired T junction is +2 vertices, +1 polygon, and +3 polygon edges.
- Correct only the generated-side half of the repaired strip by copying Material ID from the unchanged generated wall polygon across the original generated vertical edge. No normal-majority material reassignment is used.
- Update the focused FIX T EDGE CORNERS regression check for the new net topology.

2026-09-27
- Wall Thickness 0.942: add a new independent `WALL THICKNESS FIX T EDGE CORNERS` Edit Poly post-process layer; EXTRUDE and the existing FIX INNER CORNERS algorithm are unchanged.
- FIX T EDGE CORNERS reads the evaluated mesh from the modifier stack directly below itself, so lower fixes feed the next fix instead of re-reading only the Editable Poly base.
- Detect partial-height T junctions from source polygon topology without fixture vertex IDs, insert the fixed anchor exactly one wall thickness along the T branch, insert a disposable vertex on the corresponding generated continuation edge, move it to the anchor, and target-weld disposable -> fixed.
- Repair only local material IDs around the welded anchor by grouping incident polygons with the same normal and copying the established matching wall material; no material number is hardcoded for the correction.
- Add the `FIX T EDGE CORNERS` POST-PROCESS button and include the new modifier in REMOVE MODIFIERS.
- Keep file version, stored project version, project version, and UI title on the same `0.942` value.

2026-09-27
- Wall Thickness 0.941: enforce one version source of truth. `wall_thickness_file_version`, project version, and rollout title now always resolve to exactly the same version on every load.
- Remove stale-session version carry-over; project version is reset from file version instead of preserving a previously loaded higher global.
- UI READY text and versioned runtime diagnostics read the file version directly.

2026-09-27
- Wall Thickness 0.940: improve FIX INNER CORNERS for T-junction half-corners without changing EXTRUDE.
- Widen the straight-continuation tolerance to 5 degrees so nearly straight border continuations are not misclassified as fixed corners.
- Restore long crossed-edge corner candidates, but resolve all candidate targets per source-XY stack instead of first-match wins.
- When multiple fixed corners can target the same generated stack, choose the exact 100 mm target requiring the smallest move from the current generated position.
- Preserve the lower member of a two-vertex vertical opening stack so lower opening boundaries are not dragged into the T-junction repair.
- Keep direct absolute `polyop.setVert` assignment, preserve each moved vertex Z, preserve topology, and leave EXTRUDE unchanged.
- Add `TEST_T_JUNCTION_HALF_CORNER.ms` covering a long T branch, ambiguous target resolution, and the lower-opening guard.

2026-09-26
- Wall Thickness 0.939: improve FIX INNER CORNERS detection without changing EXTRUDE.
- Long valid generated wall edges are no longer marked bad only because of small cross-track deviation; cross-track is considered only inside the 100 mm local-corner range.
- Replace hardcoded wall-ending vertex IDs with automatic source-XY stack endpoint detection from the source border graph.
- Remove global generated-stack normalization. FIX INNER CORNERS now writes only generated vertical stacks explicitly reached from a reversed/short local corner edge.
- Keep the 0.938 direct absolute `polyop.setVert` write technique, preserve Z, preserve topology, and leave all unrelated vertices unchanged.

2026-09-26
- Wall Thickness 0.938: protect source wall-ending vertices `#{1,6,8..9,11..12}` from FIX INNER CORNERS.
- Their generated counterparts `#{16,21,23..24,26..27}` are also excluded from bad-edge targeting and stack normalization.
- Stack normalization now applies only to interior source-XY corner groups.
- No source wall-ending vertex or generated ending counterpart is moved by FIX INNER CORNERS.

2026-09-26
- Wall Thickness 0.936: FIX INNER CORNERS now expands every detected bad source endpoint to its complete vertical source-XY stack.
- All generated vertices corresponding to the same source XY receive the same corrected target XY while each vertex preserves its own Z.
- This fixes full corner loops such as generated stacks 18/22/25 and 28/29/30 instead of correcting only one or two height-level vertices.
- Direct absolute `polyop.setVert` assignment remains in use; no Edit Poly selection/move transform path was reintroduced.

2026-09-26
- Wall Thickness 0.935: FIX INNER CORNERS no longer uses EditPolyMod.SetSelection or EditPolyMod.MoveSelection.
- Direct absolute-position implementation: evaluate WALL THICKNESS, calculate target positions, bake the evaluated result to Editable Poly with `convertToPoly`, then assign each generated vertex using `polyop.setVert`.
- Each written vertex is read back with `polyop.getVert` and verified against the exact target.
- Important stack consequence: direct `polyop.setVert` requires the generated vertices to exist on the Editable Poly base object, so FIX INNER CORNERS now bakes/collapses the current WALL THICKNESS result before assignment.
