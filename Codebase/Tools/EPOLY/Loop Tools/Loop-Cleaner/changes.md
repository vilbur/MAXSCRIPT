# Loop-Cleaner Changes

## 2026-10-06 — direct DivideEdge insert + left/right docking 1.167

- Updated `Loop-Cleaner` to `1.167`.
- Replaced the unverified batched `#InsertVertexInEdge` path with the working `EPoly-Stack-Test_1.20.ms` pattern: one direct `Edit_Poly.DivideEdge`, immediate `Commit()`, exact `+1` vertex / `+1` edge / unchanged face-count verification, then a full live topology rebuild before another split or weld.
- A missing opposite inner-border vertex no longer stops with the old v1.163 `This fixer does not create new vertices` behavior; the fixer inserts one opposite-edge vertex and continues through the existing align/weld verification path.
- Cached component IDs are not reused after `DivideEdge`; each subsequent repair pass starts from freshly rebuilt Edit Poly topology.
- Standalone Loop-Cleaner is now registered as a CUI dialog bar with left/right vertical docking and floating support; top/bottom docking remains disabled.
- Dialog shutdown unregisters the CUI dialog bar before `destroyDialog`.
- Static source checks passed; 3ds Max runtime verification is still required.

## 2026-10-06 — Broken-T batched DivideEdge commit 1.166

- Updated `Loop-Cleaner` to `1.166`.
- Runtime v1.165 proved the insert itself succeeds visually, but immediately querying the Edit Poly after committing a single `DivideEdge` can report a transient vertex count of `0`.
- Reworked missing-opposite-vertex repair into explicit `#InsertVertexInEdge` batches: all currently safe `DivideEdge` calls are queued first, then one `Commit()` closes the whole insert batch.
- A batch queues at most one divide per current target edge. Multiple T sources on one long target edge are handled across successive batches with a full topology rebuild between them, avoiding stale split-edge IDs.
- Removed the old per-vertex `DivideEdge -> Commit -> immediate live-count` path.
- After each batch commit the modifier is refreshed and polygon topology is rebuilt. The batch must add exactly the queued number of vertices and reduce the number of broken-T cases that still lack an opposite vertex.
- Inserted targets are tracked from their original T-source world positions so the weld phase still preserves the original T source: inserted opposite vertex -> move to T source -> weld into T source.
- Pre-existing opposite vertices keep the previous preservation rule: T source -> move to existing opposite vertex -> weld into existing target.
- Static source checks passed; 3ds Max runtime verification is still required.

## 2026-10-06 — Broken-T transient post-DivideEdge verification 1.165

- Updated `Loop-Cleaner` to `1.165`.
- Runtime v1.164 confirmed that `DivideEdge` successfully creates the opposite-edge vertex, but the fix stopped because the full `buildEditPolyBorderTopology()` snapshot was too strict immediately after the divide.
- Removed the immediate full face/border topology rebuild from the post-`DivideEdge` verification stage.
- The inserted vertex is now resolved directly from live Edit Poly data using `GetNumVertices`, `GetNumEdges`, `GetVertex`, and valid `GetEdgeVertex` connections.
- Verification still requires exactly one added live vertex and one unique candidate at the expected projected position connected to both original target-edge endpoints. The edge count may exceed the mathematical `+1` during the transient modifier state, but it may not be lower than the expected split-edge count.
- Full border topology is rebuilt only after the inserted vertex is aligned and welded, where it is again used to verify that the broken-T case count decreases.
- No detection tolerances, border classification, existing-target weld behavior, or unrelated Loop-Cleaner features changed.
- Static source checks passed; 3ds Max runtime verification is still required.

## 2026-10-06 — Broken-T insert-on-edge fallback 1.164

- Updated `Loop-Cleaner` to `1.164`.
- Fixed the v1.163 RMB failure when a broken-T seam has no already-existing coincident opposite inner-border vertex.
- Kept the existing-vertex path as the first choice: when one unique opposite vertex already exists, the T source is aligned and welded into that preserved target.
- Added a missing-target fallback that sets the Edit Poly operation to `#InsertVertexInEdge`, calls `EditPolyMod.DivideEdge` at the detected target-edge fraction, commits the operation, and re-reads live topology.
- The fixer does not trust the raw `DivideEdge` return value as a vertex ID. It requires exactly `+1` live vertex and `+1` live edge, then resolves one unique inserted vertex at the projected target position that connects to both original target-edge endpoints.
- The inserted vertex is aligned onto the T source and welded into the preserved T source. No neighboring edge vertices are pre-removed.
- Existing destructive safety remains: each weld must remove exactly one live vertex and reduce the broken-T case count before the next repair pass.
- Removed the failed v1.162 command-mode strategy from this path; insertion uses the Edit Poly `#InsertVertexInEdge` operation plus direct `DivideEdge` and `Commit()`.
- Updated the broken-T tooltip and design contract. The separate `T BORDER` endpoint miss remains open in `known-issues.md`.
- Static syntax/safety checks passed; runtime verification in 3ds Max is still required.

## 2026-10-06 — Broken-T existing-vertex weld 1.163

- Updated `Loop-Cleaner` to `1.163`.
- Changed RMB broken-T repair to the user-confirmed rule: **do not create a new opposite-edge vertex** and do not pre-remove neighboring edge vertices.
- For each detected broken-T case, the fixer now searches the current live inner-border topology for an already-existing non-neighbor vertex at the T source position within the existing explicit `0.1 mm` tolerance and on the detected opposite target-edge line.
- When exactly one valid target exists, the T source is moved onto that existing target and welded with the existing target as the weld target (`WeldVertices target source`).
- If no valid existing target exists, or equally close targets are ambiguous, the fix stops instead of inventing topology.
- Removed the broken-T `DivideEdge` repair path entirely; this fixer now creates zero vertices.
- Existing safety remains: the weld must reduce the live vertex count by exactly one and the broken-T case count must decrease before another repair pass.
- Updated the RMB tooltip and design contract. The separate `T BORDER` end-of-degenerate-hole selection miss remains open in `known-issues.md`.
- Static syntax/safety checks passed; runtime verification in 3ds Max is still required.

## 2026-10-06 — Broken-T DivideEdge command-mode fix 1.162

- Updated `Loop-Cleaner` to `1.162`.
- Runtime 1.161 proved that calling `DivideEdge` and then `Commit()` did not materialize the requested split: the live Edit Poly vertex count stayed unchanged.
- The broken-T fixer now explicitly enters Edit Poly `#DivideEdge` command mode at Edge level before calling `DivideEdge`, then exits that command mode before any vertex-ID-dependent stage.
- Removed the immediate post-`DivideEdge` `Commit()` from this stage. The divide must already persist after leaving command mode; otherwise the fixer stops.
- The raw `DivideEdge` return remains ignored because the user's runtime reports `OK`; success is verified only by an exact `+1` live-vertex count and a readable new vertex.
- The helper fails instead of disturbing another active Edit Poly command mode.
- Weld verification and broken-case-count reduction checks are unchanged.
- The separate `T BORDER` last-edge/end-of-degenerate-hole miss remains open in `known-issues.md`.
- Static syntax/safety checks passed; runtime verification in 3ds Max is still required.

## 2026-10-06 — Broken-T DivideEdge runtime return fix 1.161

- Updated `Loop-Cleaner` to `1.161`.
- Fixed the RMB broken-T repair crash `No "<" function for OK` at the `divide opposite border edge` stage.
- `EditPolyMod.DivideEdge` is no longer treated as though its raw return value is always a numeric new-vertex ID. The runtime-reported `OK` value is now ignored.
- After the divide is committed, the repair requires the live vertex count to increase by exactly one, resolves that single appended vertex from the post-divide topology, and only then continues with alignment and weld verification.
- Existing destructive safety remains: the weld must remove exactly one vertex and each pass must reduce the broken-T case count before success can continue.
- The unresolved `T BORDER` last-edge/end-of-degenerate-hole selection miss is now tracked in `known-issues.md`.
- Static syntax/safety checks passed; runtime verification in 3ds Max is still required.

## 2026-10-06 — T BORDER endpoint experiment 1.160

- Updated `Loop-Cleaner` to `1.160`.
- Added a positional endpoint association attempt for `T BORDER` using the existing explicit `0.1 mm` broken-border tolerance.
- Runtime feedback still showed missed T stems when the junction lies on the last edge/end of a degenerate inner-border run, so this remains unresolved and is tracked as a known issue.

## 2026-10-06 — T BORDER component-end T junctions 1.159

- Updated `Loop-Cleaner` to `1.159`.
- Fixed the remaining `T BORDER` miss when an exact T junction lies on the first or last edge of a detected broken inner-border component.
- The 1.158 rule looked only at local broken seam source vertices, so a valid perpendicular T-stem could be skipped when the broken-border case was detected from a neighboring source vertex on the same degenerate component.
- `T BORDER` now derives the complete broken inner-border edge components first, finds every exact T-junction vertex incident to those component edges, and selects only those vertices' T-stem edges. Parallel continuation edges remain excluded.
- This selection no longer depends on whether the T vertex is the seam source, an endpoint of the broken run, or encountered as an intermediate T during loop tracing.
- `T MESH` keeps complete traced loops only when they contain no selected `T BORDER` stem edge.
- No fixed scene edge IDs, new tolerance, epsilon, rounding, or geometric threshold was added; the existing explicit `0.1 mm` broken-border detector is unchanged.
- Static syntax/safety checks passed; runtime verification in 3ds Max is still required.

## 2026-10-06 — T BORDER perpendicular broken-seam stems 1.158

- Updated `Loop-Cleaner` to `1.158`.
- Corrected `T BORDER` so it no longer selects the parallel continuation of a T-junction loop after that loop is associated with a broken inner border.
- `T BORDER` now reuses the existing broken-inner-border case records and selects only the exact T-stem edge at each broken seam source endpoint.
- If one traced T loop connects two broken seam source endpoints, both endpoint stem edges are selected; the loop is still counted once in the Listener summary.
- `T MESH` continues to keep complete traced loops only when they have no broken seam endpoint.
- No scene-specific edge IDs were added to production code, and no new geometric tolerance or epsilon was introduced; the existing explicit `0.1 mm` broken-border detector is unchanged.
- Updated the `T BORDER` / `T MESH` tooltips. Unrelated border selection, broken-T repair, redundant-loop selection/removal, and debug behavior are unchanged.
- Static syntax/safety checks passed; runtime verification in 3ds Max is still required.

## 2026-10-06 — T BORDER broken-inner-border termination rule 1.157

- Updated `Loop-Cleaner` to `1.157`.
- Changed `T BORDER` classification to the user-confirmed rule: select a traced T-junction loop only when its traced start or terminal endpoint belongs to a broken inner-border component.
- Reused the existing broken-inner-border detector and its explicit `0.1 mm` positional contract; merely touching any true mesh border no longer qualifies a loop as `T BORDER`.
- `T MESH` is now the complementary traced T-junction set whose endpoints do not belong to a broken inner-border component.
- Extended the T-loop trace record with its actual terminal vertex so termination can be classified directly without edge-ID or iteration-order inference.
- Updated the `T BORDER` and `T MESH` tooltips. Unrelated border, broken-T fixer, useless-loop, and debug behavior is unchanged.
- Static syntax/safety checks passed; runtime verification in 3ds Max is still required.

## 2026-10-06 — topology-stable T-junction tracing 1.156

- Updated `Loop-Cleaner` to `1.156`.
- Fixed the T-junction loop tracer inconsistency reported on `BLOCK-A-MATERIAL001`, where topologically equivalent loops could produce different selected edges.
- Removed the ordinary-vertex fallback that called the generic geometric loop scorer with a permissive `-2.0` limit. That path could accept an invalid continuation and resolve equal/failed scores by ascending edge ID, making results dependent on component numbering.
- Ordinary non-T continuation is now topology-only: continue only through the unique incident candidate edge that shares no polygon face with the incoming edge. Ambiguous or missing topology-opposite continuations stop instead of choosing an edge by ID/order.
- Exact T-vertex stem/through behavior, `T BORDER` / `T MESH` classification, selectors, broken-T fixer, and unrelated Loop-Cleaner behavior are unchanged.
- Static syntax/safety checks passed; runtime verification in 3ds Max is still required.

## 2026-10-06 — broken inner-border T-junction selector/fixer 1.155

- Updated `Loop-Cleaner` to `1.155`.
- Added one full-width 32 px `BROKEN T JUCTIONS SELECT \ FIX` button.
- LMB detects degenerate **inner** borders by finding an inner-border vertex within the explicit fixed `0.1 mm` world-space tolerance of the strict interior of another non-incident inner-border edge while at least one source border edge lies on that same target line, then expands the hit to the complete connected inner-border component(s).
- LMB stores the result in a dedicated reusable `SELECT BROKEN T JUNCTIONS` Edit Poly and leaves `SELECT BORDERS`, `SELECT T JUNCTIONS`, and `SELECT REDUNDANT LOOPS` untouched.
- RMB reuses that selector as the topology-editing layer. For each current case it re-reads live Edit Poly topology, divides the opposite border edge at the projected fraction, moves the new vertex exactly onto the existing T vertex, target-welds the new vertex into the source, and verifies the broken-T case count decreases.
- Topology is rebuilt after every weld so multiple T vertices on one long opposite edge are processed without reusing stale edge IDs.
- A successful repair requires every current broken-T case to be removed, then renames the modifier to `FIXED BROKEN T JUNCTIONS`. Failures are reported and remain undoable.
- Added a direct Edit Poly polygon-topology snapshot builder for this fix using verified `GetNum*`, `GetVertex`, `GetEdgeVertex`, `GetFaceDegree`, and `GetFaceVertex` APIs; no TriMesh component IDs are used.
- Existing useless-loop, border, normal T-junction, debug, and redundant-loop RMB behavior is unchanged.
- Static syntax/safety checks passed; runtime verification in 3ds Max is still required.

## 2026-10-06 — T-junction loop selectors 1.154

- Updated `Loop-Cleaner` to `1.154`.
- Added 32 px `T JUNCTIONS`, `T BORDER`, and `T MESH` buttons plus public methods `selectAllTJunctions()`, `selectBorderTJunctions()`, and `selectMeshTJunctions()`.
- T-junction detection is topological and exact: a T vertex has exactly three incident live edges, one perfectly collinear opposite pair, and one remaining non-border stem edge. No angular tolerance or hidden epsilon is used.
- Whole visible/selectable internal loop paths are traced from T stems with the existing loop-continuation helper. Arrival through another T stem terminates the trace, while arrival on that T's straight-through pair continues across it.
- `T BORDER` means the starting or terminal T-stem vertex lies on true mesh border topology; `T MESH` means those T-stem vertices are internal.
- T-junction selections use a dedicated reusable `SELECT T JUNCTIONS` Edit Poly and do not overwrite `SELECT BORDERS` or `SELECT REDUNDANT LOOPS`.
- Existing redundant-loop, border-selector, debug, and RMB removal behavior is unchanged.
- Static syntax/safety checks passed; runtime verification in 3ds Max is still required.


## 2026-10-06 — shared UI dependency path fix 1.153

- Updated `Loop-Cleaner` to `1.153`.
- Fixed the shared UI helper path for the canonical `Codebase/Tools/EPOLY/Loop Tools/Loop-Cleaner/` location: the script now walks five parent directories to the `Maxscript` root before loading `UI/Default/ScriptReload.ms` and `UI/Default/ToolTitleButton.ms`.
- No geometry, selection, border-classification, or removal behavior changed.
- Static syntax/safety checks passed; runtime verification in 3ds Max is still required.

## 2026-10-06 — tool rename 1.152

- Renamed the tool from `Redundant-Loop-Fixer` to `Loop-Cleaner`.
- Renamed the canonical script to `Loop-Cleaner.ms` and the new versioned release to `Loop-Cleaner_1.152.ms`.
- Replaced every exact `Redundant-Loop-Fixer` string in the running script with `Loop-Cleaner`, including UI titles, tool-title restart prefix, Listener/error prefixes, and the INI filename.
- Internal MaxScript globals/functions remain unchanged to avoid unrelated refactoring; geometry, selection, border, and removal behavior are unchanged.
- Static syntax/safety checks passed; runtime verification in 3ds Max is still required.

## 2026-10-06 — border selectors 1.151

- Updated clean rewrite to `Redundant-Loop-Fixer_1.151.ms`; filename version, internal file version, project version, and native dialog title version are synchronized.
- Added `BORDER ALL`, `OUTER`, and `INNER` 32 px selection buttons plus public methods `selectAllBorders()`, `selectOuterBorders()`, and `selectInnerBorders()`.
- Border classification uses true polygon border topology. Border edges are grouped into connected boundary components, and face connectivity groups the mesh into connected surface shells.
- For each connected surface shell, the border component with the greatest exact world-space perimeter is classified as the outer border; all remaining border components are classified as inner-hole borders.
- Selection writes only currently visible/selectable members of the classified border set into a dedicated reusable `SELECT BORDERS` Edit Poly so border testing does not overwrite `SELECT REDUNDANT LOOPS`.
- Existing redundant-loop detection/removal behavior is unchanged.
- Static syntax/safety checks passed; runtime verification in 3ds Max is still required.

## 2026-10-06 — uniform 32 px buttons 1.150

- Updated clean rewrite to `Redundant-Loop-Fixer_1.150.ms`; filename version, internal file version, project version, and native dialog title version are synchronized.
- Set every button control in the standalone UI to an actual `32 px` height, including the `.NET` tool title button, primary action, debug buttons, and `GET ANGLE`; no extra height is simulated with padding.
- Renamed the primary action button to `USELESS LOOPS SELECT \ REMOVE`.
- Preserved the shared tool-title styling/restart helper and explicitly reapplied the requested 32 px title height after helper setup/resize.
- Detector, selection, and removal behavior are unchanged.
- Static syntax/safety checks passed; runtime UI verification in 3ds Max is still required.

## 2026-10-06 — shared .NET tool title restart 1.149

- Updated clean rewrite to `Redundant-Loop-Fixer_1.149.ms`; filename version, internal file version, project version, and native dialog title version are synchronized.
- Reworked the standalone dialog to follow the shared MaxScript UI rules: 336 px dialog width, 12 px grid/margins, 24 px standard controls, and a 48 px primary action.
- Added the canonical `.NET` `tool title button` at the top of the dialog using shared `ScriptReload.ms` and `ToolTitleButton.ms`.
- The title button label is exactly `Redundant-Loop-Fixer`; LMB calls the shared `restartTool` helper to load the newest matching versioned script or reload the current script.
- Removed the duplicate bottom `RESTART` button and the tool-local restart helper functions.
- Added horizontal title-button resize handling and kept the native dialog title versioned from the current global project version.
- Detector and removal behavior are unchanged.
- Static syntax/safety checks passed; runtime UI verification in 3ds Max is still required.

## 2026-10-05 — direct subtraction detector 1.148

- Updated clean rewrite to `Redundant-Loop-Fixer_1.148.ms`; filename version, internal file version, project version, and visible title are identical.
- Replaced the production chain/terminal validator with the requested direct mask subtraction.
- Production LMB is now exactly: visible/selectable edges -> subtract border edges -> subtract restored border-corner loop edges -> subtract restored wall-corner loop edges -> store the remainder in `SELECT REDUNDANT LOOPS`.
- Removed `rejectBorder`, terminal, degree, and ANGLE validation from the production result path. Existing restored border-corner and wall-corner helper behavior is reused unchanged.
- Production Listener summary now reports `visible`, `border`, `internal`, `borderCorner`, `wallCorner`, and final `redundant` counts.
- `ANGLE` is disabled in the UI because it no longer affects `SELECT | REMOVE`.
- RMB removal behavior is unchanged.
- Static syntax/safety checks passed; runtime verification in 3ds Max is still required.

## 2026-10-05 — restore border/wall corner debug selectors 1.147

- Updated clean rewrite to `Redundant-Loop-Fixer_1.147.ms`; filename version, internal file version, project version, and visible title are identical.
- Restored the working `0.819` border-corner topology classifier/tracer for `2  SELECT BORDER CORNER LOOPS`, adapted only to the clean rewrite topology-data layout and current safe selection writer.
- Restored the working `0.819` wall-corner diagnostic for `3  SELECT WALL CORNER LOOP`, using the same 1-degree adjacent-face-plane classification as the current geometry-corner threshold.
- Border-corner debug output excludes wall-corner edges exactly as the old debug button did.
- Both debug buttons now store their result in the existing `SELECT REDUNDANT LOOPS` Edit Poly through the clean rewrite selection path; zero-result runs do not create a new selector.
- The production `SELECT | REMOVE` detector and RMB removal behavior were not changed.
- Canonical `Redundant-Loop-Fixer.ms` is synchronized byte-for-byte with 1.147.
- Static syntax/safety checks passed; runtime verification in 3ds Max is still required.

## 2026-10-05 — whole-chain tracer fix 1.146

- Updated clean rewrite to `Redundant-Loop-Fixer_1.146.ms`; filename version, internal file version, project version, and visible title are identical.
- Runtime 1.145 on `BLOCK-A-MATERIAL001` produced 542 candidates but fragmented them into 236 components and rejected all 236, proving the mutual-unique continuation graph was over-restrictive.
- Replaced the precomputed unique-partner graph with whole-chain tracing in both directions from each candidate seed.
- Continuation now chooses the connected candidate that leaves the best complete straight-through ring pairing within `ANGLE`; the chain itself may turn freely.
- Whole-chain validation runs only after tracing: closed loops validate their ring topology, border-terminated open chains are rejected, and internal T-terminals require a complete straight-through remaining ring pair.
- Removed the 1.145 ambiguity-as-terminal rule. No fixed-point pruning and no native `SelectEdgeLoop()` were introduced.
- Final Listener summary now includes rejection buckets for border, terminal, angle, and degree failures.
- Canonical `Redundant-Loop-Fixer.ms` was intended to match 1.146; the canonical file is now synchronized by the 1.147 release.
- Static syntax/safety checks passed; runtime verification in 3ds Max is still required.

## 2026-10-05 — canonical clean detector + LMB/RMB 1.145

- Updated clean rewrite to `Redundant-Loop-Fixer_1.145.ms`; filename version, internal file version, project version, and visible title are identical.
- `SELECT | REMOVE` LMB now runs one canonical detector instead of the stage-1 visible-edge probe.
- Detector pipeline is now: visible/selectable edges -> protect border/crease/invalid edges -> protect non-coplanar geometry-corner edges -> build explicit continuation relations from `ANGLE` ring straightness -> build chain/loop components -> validate terminals -> select the accepted union.
- Removed the fixed-point mutual-support production architecture and did not use native `SelectEdgeLoop()`.
- Ambiguous continuation vertices are not resolved by scoring; they become protected terminals.
- Internal T-junction/single-edge terminals are accepted only when the remaining incident topology pairs straight-through within `ANGLE`; border terminals are rejected.
- LMB stores the result in the exact `SELECT REDUNDANT LOOPS` Edit Poly; zero-result runs do not create a selector and clear an existing exact selector.
- `SELECT | REMOVE` RMB is now wired: it removes exactly the stored selector edges with `#RemoveEdgeRemoveVertices`, verifies vertex/edge topology decreases, then renames the modifier `DELETED REDUNDANT LOOPS`.
- QUIET now suppresses the expected visible-vs-selectable diagnostic; one final SELECT or REMOVE summary remains.
- Canonical `Redundant-Loop-Fixer.ms` is synchronized byte-for-byte with 1.145.
- Static syntax/safety checks passed; runtime verification in 3ds Max is still required.

## 2026-10-05 — visible/selectable edge domain 1.144

- Updated clean rewrite to `Redundant-Loop-Fixer_1.144.ms`; file version, project version, and visible title are identical.
- Runtime 1.143 proved the current mismatch was not caused by dead topology: the requested Edge BitArray remained unchanged after the dead-structure boundary.
- Base `Editable_Poly` stage 1 now distinguishes raw `getEdgeVis` from the edges the current Editable Poly can actually store as an edge selection.
- The final stage-1 set is `edgeVisEdges ∩ selectableEdges`; the temporary all-edge probe restores the prior edge selection before the final result is written.
- Base selection write/read verification now uses the exact same `Editable_Poly` base object as analysis instead of switching the `polyop` receiver to the node.
- Added one Listener diagnostic splitting `edgeVis == true` but non-selectable edges into hidden-vertex, hidden-face, and other groups.
- Canonical `Redundant-Loop-Fixer.ms` is synchronized to the same 1.144 bytes.
- Static checks passed; runtime verification in 3ds Max is still required.

## 2026-10-05 — dead topology cleanup boundary 1.143

- Updated clean rewrite to `Redundant-Loop-Fixer_1.143.ms`; file version, project version, and visible title are identical.
- Added a single base `Editable_Poly` topology-clean boundary before index-sensitive work: check `polyop.getHasDeadStructs`, run `polyop.collapseDeadStructs` only when required, then read fresh IDs.
- Active `Edit_Poly` paths do not collapse the Editable Poly base underneath the modifier; a dead-base bridge is rejected instead of reindexing the modifier's input topology.
- This adds the requested defensive dead-topology boundary. Subsequent 1.143 runtime output showed that dead topology was not the cause of the current stage-1 selection mismatch.
- Canonical `Redundant-Loop-Fixer.ms` is synchronized to the same 1.143 bytes.
- Static source checks passed; 3ds Max runtime verification is still required.

## 2026-10-05 — selection verification/API fix 1.142

- Updated clean rewrite to `Redundant-Loop-Fixer_1.142.ms`; file version, project version, and visible title remain identical.
- `SELECT | REMOVE` now uses the verified shared EPoly selection API sequence: base `Editable_Poly` writes through `polyop` on the node; `Edit_Poly` uses `.GetSelection/.Select` on the active modifier without a `node:` override.
- Selection verification now compares missing/extra set membership and prints `requested`, `stored`, `missing`, and `extra` edge BitArrays on mismatch.
- Updated canonical `Redundant-Loop-Fixer.ms` in place to the same 1.142 bytes.
- Static source checks passed; 3ds Max runtime execution is still required.

## 2026-10-05 — unified version identity 1.141

- Version identity is now singular: file version = stored project version = visible title version.
- Current clean rewrite is `Redundant-Loop-Fixer_1.141.ms`.
- `SELECT | REMOVE` remains wired to the clean stage-1 visible-edge selection function.
- Updated canonical `Redundant-Loop-Fixer.ms` in place to the same 1.141 bytes.
- Static source checks passed; 3ds Max runtime execution has not been performed.

## 2026-10-05 — clean rewrite shell 0.835

- Added new development file `Redundant-Loop-Fixer_0.835.ms` from scratch; the old `0.834` detector was not copied into it.
- Shared project version advanced to `1.139` in the new code file.
- Preserved the current UI layout while disabling controls whose new implementation does not exist yet; `RESTART` remains active.
- The clean rewrite intentionally contains no fixed-point/network redundant detector and no embedded regression/test functions.
- Updated `design.md` to make the new production direction explicit: visible edges -> remove border edges -> remove geometry-corner edges -> build connected chains/loops -> reject border/T-junction terminals -> select the remainder.
- Existing canonical `Redundant-Loop-Fixer.ms` remains untouched as reference until the clean rewrite is intentionally promoted.
- Static source checks for the new shell passed; 3ds Max runtime execution has not been performed.

## 2026-10-05 — current-poly analysis + QUIET 0.834

- Updated `Redundant-Loop-Fixer.ms` to file version `0.834` and shared project version `1.138`.
- Added persistent `QUIET` (default ON): normal processing suppresses per-edge/per-loop/setup diagnostics and keeps errors plus one final SELECT/REMOVE summary.
- Production detection now reads the current `Edit_Poly` directly through `EditPolyMod` or the current base `Editable_Poly` through `polyop`; unsupported current stack states fall back to a disposable evaluated Editable Poly copy.
- Explicitly avoids `snapshotAsMesh`/TriMesh for production polygon detection so fallback analysis does not replace polygon identity with triangulated mesh topology.
- New `SELECT REDUNDANT LOOPS` is created only after a non-empty redundant-edge result and is inserted immediately above the analyzed current poly domain; zero-result runs never create a new selector.
- Empty debug results also do not create a selector when none exists.
- Updated `Redundant-Loop-Fixer-test.ms` to `0.005` / project `1.138` with regressions for zero-result no-selector creation, direct current Edit Poly analysis/selector placement, and the 48-edge `Object019` ground truth.
- Updated `design.md` to match the current topology-network production detector and QUIET/no-selector contracts.

## 2026-10-05 — version/title/canonical synchronization 0.833

- Updated `Redundant-Loop-Fixer.ms` to file version `0.833` and shared project version `1.137`.
- The visible rollout title and `getDisplayTitle()` now use `file_version`, so the numeric versioned filename, internal file version, and visible tool title all report `0.833`.
- Updated the unversioned canonical `Redundant-Loop-Fixer.ms` in place to the exact latest 0.833 bytes while preserving its existing Drive file ID.
- Permanent repository rule: after every release, the unversioned canonical file must equal the latest numeric versioned file byte-for-byte.

## 2026-10-04 — topology-network redundant-edge detector 0.832

- Updated `Redundant-Loop-Fixer.ms` to file version `0.832` and shared project version `1.136`.
- Replaced production LMB native `SelectEdgeLoop()` dependency with local removable-topology detection: internal non-border/non-crease candidates, fixed `1°` wall protection, endpoint continuation/terminal validation, and fixed-point pruning.
- Complete loops, open chains, broken redundant-loop fragments, vertical loops, and valid singleton dividers use the same production rule.
- Production `ANGLE` evaluates transverse/ring straight-through support; the redundant path itself may turn.
- Updated `Redundant-Loop-Fixer-test.ms` to test version `0.005` / project `1.136`.
- Updated Object019 ground truth at ANGLE 20 to the user-confirmed 48-edge set `#{2..6, 10, 12..14, 16..17, 19..20, 23..24, 26..27, 29..31, 33, 35, 37..38, 46..48, 55, 58, 60, 64, 66, 69, 72, 74, 78, 80, 82, 84, 86, 89, 91, 93..94, 103..104, 108..109}`.

## 2026-10-04 — native EditablePoly loop repair + Object019 ground truth 0.830

- Updated `Redundant-Loop-Fixer.ms` to file version `0.830` and shared project version `1.134`.
- Restored actual native 3ds Max Editable Poly loop identity with the correct receiver: loop expansion runs on the disposable analysis node through `analysis_node.EditablePoly`, while base Editable Poly edge selection is read/written with `polyop`.
- Detection now always uses a disposable evaluated/collapsed copy, eliminating the previous live-state restore failure.
- Complete native loops containing protected/non-candidate members are rejected whole instead of clipped.
- Singleton native results are accepted only when the existing isolated-divider topology validation succeeds, preserving real one-edge dividers while rejecting random triangulation diagonals.
- Production and debug discovery now share the same native loop source.
- Added native multi-edge expansion and valid-singleton regressions.
- Updated `Redundant-Loop-Fixer-test.ms` to test version `0.004` / project `1.134`.
- Added the user-confirmed `Object019` ground-truth regression at ANGLE 20 expecting `#{12,16,19,29,31,33,35,38,41,48,55,60,64,66,69,74,78,80,84,86,89,93..94,108,111}` and printing missing/extra IDs.
- Updated `design.md` with the strict Editable_Poly / EditablePoly interface / Edit_Poly API split.
- Static validation passed; 3ds Max runtime verification is still required.

## 2026-10-04 — restore topology-traced LMB selection 0.829

- Updated `Redundant-Loop-Fixer.ms` to file version `0.829` and shared project version `1.133`.
- Removed the 0.824+ production dependency on Editable Poly `SelectEdgeLoop()` and restored the near-working 0.823 topology tracer for loop/chain construction.
- Removed invalid `GetEPolySelLevel` / `SetEPolySelLevel` calls from the Editable Poly analysis path; those methods remain only on actual `Edit_Poly` modifiers.
- Production LMB now detects on evaluated topology only, then maps the final Edge BitArray into the dedicated `SELECT REDUNDANT LOOPS` modifier.
- Kept the 0.828 stale-zero-result clear/rollback behavior and live Edit Poly selection verification.
- Updated `design.md` so production detection is explicitly independent of Modify-panel selection state and native Editable Poly UI loop commands.
- Updated `Redundant-Loop-Fixer-test.ms` to test version `0.003` / project `1.133` with a direct Editable Poly production-detection regression.
- Static validation passed; 3ds Max runtime execution is still required.

## 2026-10-04 — SELECT REDUNDANT LOOPS stale-selection fix 0.828

- Updated `Redundant-Loop-Fixer.ms` to file version `0.828` and shared project version `1.132`.
- Fixed LMB zero-result behavior: an existing `SELECT REDUNDANT LOOPS` modifier is reused and its stale Edge selection is explicitly cleared and verified instead of being preserved.
- Kept zero-result clearing transactional: if clearing or verification fails, the previous Edge selection is restored through the existing rollback path.
- LMB UI runs now print per-object selection failures and a final `DEBUG SELECT LOOPS COMPLETE` summary when `select_debug_output` is enabled.
- Updated `Redundant-Loop-Fixer-test.ms` to test version `0.002` / project `1.132` with a regression that first stores a valid redundant edge, changes it into a crease, reruns LMB, and verifies the same selector remains with an empty Edge BitArray.
- Static validation passed for changed source and test files; 3ds Max runtime execution is still required.

## 2026-10-04 — evaluated-stack regression correction 0.827

- Updated `Redundant-Loop-Fixer.ms` to file version `0.827` and shared project version `1.131`.
- Restored true evaluated top-of-stack analysis when `SELECT REDUNDANT LOOPS` is buried; modifiers above the selector are no longer hidden from detection.
- Kept selector reuse and strict analysis-to-live topology bijection, so topology-changing upper modifiers now fail safely instead of analyzing the wrong mesh domain.
- Added a regression that applies a topology-changing Edit Poly above a buried selector and verifies the disposable analysis copy matches the true evaluated top-of-stack edge count.
- Added `Redundant-Loop-Fixer-test.ms` / `Redundant-Loop-Fixer-test_0.001.ms` with numbered `partOfTest1()`, `partOfTest2()`, and `partOfTest3()` stages, persistent viewport results, and printed Undo order.
- Static validation passed for source and test harness. Runtime execution in 3ds Max is still required.

## 2026-10-04 — native-loop integrity repair 0.826

- Updated `Redundant-Loop-Fixer.ms` to file version `0.826` and shared project version `1.130`.
- Preserved complete native Editable Poly `SelectEdgeLoop()` BitArrays; candidate edges now seed discovery only and never clip loop records into fragments.
- Mapped all debug edge selections from analysis topology into the live `SELECT REDUNDANT LOOPS` Edit Poly before writing selection.
- Made DEBUG 2 show complete border-corner loops independently of wall-corner classification.
- When the dedicated selector is buried in the stack, analysis now trims modifiers above it on the disposable copy so detection and selection use the same topology domain.
- Removed unused positional endpoint remapping and undocumented geometry/crease epsilons from active classification paths.
- RMB now reports failure when no removable redundant-loop selection exists instead of returning success after doing nothing.
- Added regression coverage for whole native-loop preservation, debug edge-ID remapping, and RMB no-op failure semantics.
- Static validation passed; 3ds Max runtime execution is still required.

## 2026-10-03 — debug selection diagnostics 0.820

- Updated `Redundant-Loop-Fixer.ms` to file version `0.820` and shared project version `1.123`.
- Production `SELECT | REMOVE` LMB now prints the exact `ANGLE` setup plus the final selected Edge BitArray/count for every processed object, while leaving the older verbose per-loop detector trace disabled.
- `ANGLE` spinner edits now print the saved degree value, and `GET ANGLE` prints the exact selected input edges/count plus the measured angle. Loop detection, selection, filtering, and RMB removal geometry are unchanged.

## 2026-09-30 — compile fix 0.813

- Updated `Redundant-Loop-Fixer.ms` to file version `0.813` and shared project version `0.819`.
- Fixed illegal `throw <value>` expressions inside rollback `catch` scopes. MAXScript permits only bare `throw()` while evaluating a catch expression.
- Rollback validation now records explicit rollback error text instead of throwing a new argument-bearing exception from inside a catch scope.
- Added static validation that no argument-bearing `throw` exists inside any catch expression.

## 2026-09-30 — audit hardening

- Updated `Redundant-Loop-Fixer.ms` to file version `0.812` and shared project version `0.818`.
- Preserved the `design.md` loop-selection algorithm while hardening selection, topology, modifier-stack, rollback, and destructive-operation contracts.
- Reused `SELECT REDUNDANT LOOPS` across the full modifier stack instead of creating a duplicate when the selector is not the top modifier.
- Mapped evaluated detected edges onto the actual Edit Poly topology before writing selections.
- Distinguished legitimate empty selections from failed/unresolved selection reads.
- Revalidated stored RMB selections against current evaluated redundant-loop topology before removal.
- Verified destructive RMB operations change topology before reporting success or renaming the selector to `DELETED REDUNDANT LOOPS`.
- Removed operation-critical silent exception handling and preserved original exception text in diagnostics.
- Added rollback verification for failed selector writes and debug writes.
- Added focused regression coverage for failed `selectMode` writes and buried-selector reuse.
- Coordinated the stored project version with `epoly_tools_project_version` and dynamic tool title generation.

Static/source validation passed. Runtime verification in 3ds Max is still required.