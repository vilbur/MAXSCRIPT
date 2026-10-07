# Loop-Cleaner Changes

## 2026-10-07 — restore required Broken-T topology rebind boundaries 1.210

- Updated `Loop-Cleaner` to `1.210`.
- Runtime on `BLOCK-A-MATERIAL002` proved the 1.207 activation-lock optimisation was too aggressive: after a partial Divide produced five valid move pairs, the following MOVE stage read `GetNumVertices == 0` when it only synchronized Edge/Vertex state and did not force a fresh binding of the same Edit Poly.
- Added one explicit same-modifier rebind helper for topology-change synchronization boundaries. It reselects the same node/Edit Poly and calls `modPanel.setCurrentObject` on the same `SELECT BROKEN T JUNCTIONS` instance before live ID-dependent reads continue.
- Batch MOVE now performs that full same-modifier rebind once after the Divide stage, before its first live vertex-count read. This restores the previously stable post-Divide behavior without reactivating the modifier before every stage.
- WELD keeps the same modifier current during a pair, but after each `WeldVertices -> Commit` it performs the same full rebind once before verifying the new live vertex count and continuing to the next pair.
- No extra rebind is added between MOVE and WELD because MoveSelection does not change topology. The next Divide cycle only switches the existing modifier back to Edge context after the final post-weld rebind.
- DivideEdge, MoveSelection, WeldVertices, pair ordering, topology-ID handling, position precision, and both Broken-T production button event paths are otherwise unchanged.
- Static delimiter, version, prohibited-syntax, and protected-identifier checks passed. Runtime verification in 3ds Max is still required.

## 2026-10-07 — restore FIX T BORDER HOLES batch button 1.209

- Updated `Loop-Cleaner` to `1.209`.
- Added the production button `FIX T BORDER HOLES` below the merged `BROKEN T JUNCTIONS SELECT \ FIX` control.
- LMB on `FIX T BORDER HOLES` calls the existing `fixTBorderHoles()` wrapper, which runs Broken-T selection first and then the complete batch `DIVIDE EDGE -> MOVE VERTICES -> WELD VERTICES` repair with no modal stage dialogs.
- The merged Broken-T LMB/RMB control remains unchanged.
- Shifted only the controls below the Broken-T production section down by one 44 px row and increased rollout height accordingly.
- No Broken-T detection, Divide, Move, Weld, modifier-lock, topology-ID, or position-precision logic changed.
- Runtime verification in 3ds Max is still required for the restored batch button wiring.

## 2026-10-07 — merge Broken-T select/fix UI and remove step debug buttons 1.208

- Updated `Loop-Cleaner` to `1.208`.
- Replaced the separate `BROKEN T SELECT`, `BATCH BROKEN T FIX`, and `FIX T BORDER HOLES` production buttons with one `BROKEN T JUNCTIONS SELECT \ FIX` button.
- LMB runs the existing non-destructive Broken-T selector and stores the result in `SELECT BROKEN T JUNCTIONS`.
- RMB runs the existing `fixTBorderHoles()` wrapper, so it refreshes the Broken-T selection first and then runs the stable batch `DIVIDE EDGE -> MOVE VERTICES -> WELD VERTICES` repair with no modal stage dialogs.
- Removed the temporary step-by-step UI controls `TEST MOVE VERTEX`, `TEST MOVE SELECTED VERTEX`, and `TEST WELD SELECTED VERTICES`. Their backend diagnostic functions remain available in code but are no longer exposed in the production rollout.
- Compacted the rollout by moving the remaining legacy debug selectors and settings upward; no Broken-T topology, move, weld, modifier-lock, or position-precision logic changed.
- Runtime verification in 3ds Max is still required for the merged LMB/RMB UI wiring.

## 2026-10-07 — Broken-T modifier activation locked for batch 1.207

- Updated `Loop-Cleaner` to `1.207`.
- `BATCH BROKEN T FIX` now activates `SELECT BROKEN T JUNCTIONS` at most once. After that exact modifier becomes current, every later Divide/Move/Weld stage and every later batch cycle reuses the same modifier instance without calling `modPanel.setCurrentObject` again.
- Split Broken-T context handling into one stack-activation helper and one Edge/Vertex synchronization helper. The synchronization path never selects the node, enters Modify mode, or changes the current modifier.
- Preserved the 1.204 safety requirement after topology-changing commits: `SetPrimaryNode`, `useStackSelection = false`, `selectMode = 0`, `showCage = off`, `SetEPolySelLevel`, and matching `subObjectLevel` are still reasserted where live Edit Poly topology must be read reliably.
- Removed the redundant pre-weld context reset before every weld pair. After each `WeldVertices -> Commit`, the Vertex context is still synchronized once before verifying the new live vertex count.
- `FIX T BORDER HOLES` keeps its 1.206 `BROKEN T SELECT -> BATCH BROKEN T FIX` behavior; when selection already leaves `SELECT BROKEN T JUNCTIONS` current, the repair batch performs no additional modifier-stack activation.
- DivideEdge, MoveSelection, WeldVertices, pair ordering, topology-ID handling, and position precision are unchanged.
- Runtime verification in 3ds Max is required before this activation-lock optimisation can be called stable.

## 2026-10-07 — FIX T BORDER HOLES select + batch repair 1.206

- Updated `Loop-Cleaner` to `1.206`.
- Added the production button `FIX T BORDER HOLES`.
- The new action runs `BROKEN T SELECT` first with modal dialogs disabled, then immediately runs the existing stable `BATCH BROKEN T FIX` chain on the same selected object.
- If the selection stage finds no Broken-T holes and no selector exists, the action reports a clean no-op success instead of entering the repair chain.
- The existing `BROKEN T SELECT`, `BATCH BROKEN T FIX`, Divide/Move/Weld implementation, modifier-context optimisation, topology-ID handling, and position precision remain unchanged.
- Increased the rollout height by one 44 px control row and shifted only the controls below the Broken-T production section.
- Runtime verification in 3ds Max is required for the new wrapper button.

## 2026-10-07 — Broken-T optimisation step 1: keep one stack modifier active 1.205

- Updated `Loop-Cleaner` to `1.205`.
- This optimisation changes only modifier-stack activation in the Broken-T batch path. The exact `SELECT BROKEN T JUNCTIONS` Edit Poly remains the working modifier across `DIVIDE -> MOVE -> WELD`.
- `modPanel.setCurrentObject` now runs only when that exact Edit Poly is not already the current Modify-panel object.
- The 1.204 safety reset is otherwise preserved: every destructive stage still explicitly calls `SetPrimaryNode`, disables stack selection, resets `selectMode`, keeps `showCage = off`, forces the required Edit Poly Edge/Vertex selection level, and writes the matching `subObjectLevel`.
- This intentionally isolates modifier-stack switching from sub-object-level switching so runtime testing can show whether the stack reselection itself is unnecessary.
- No DivideEdge, move, weld, pair ordering, topology-ID, or position-precision logic changed.
- Runtime verification in 3ds Max is required before this optimisation can be called stable.

## 2026-10-07 — rollback unsafe Edit Poly context caching 1.204

- Updated `Loop-Cleaner` to `1.204`.
- Reverted the 1.203 Broken-T context-reuse optimisation back to the user-verified 1.202 activation sequence at the destructive stage boundaries.
- Runtime on `BLOCK-A-MATERIAL002` showed that after a partial Divide, skipping the explicit Modify-panel/Edit Poly rebind caused `GetNumVertices` to return `0` at the start of MOVE VERTICES even though five valid move pairs existed.
- `BATCH BROKEN T FIX` again performs the full known-good Edit Poly activation before MOVE and the known-good reactivation sequence around WELD commits. Divide/Move/Weld geometry logic itself is unchanged from stable 1.202.
- This establishes Edit Poly activation after committed topology changes as a required synchronization boundary; future optimisation must avoid removing that boundary.

## 2026-10-07 — batch Broken-T staged chain 1.202

- Updated `Loop-Cleaner` to `1.202`.
- Renamed the combined action to `BATCH BROKEN T FIX`.
- The batch now chains the three user-verified stages directly: `DIVIDE EDGE -> MOVE VERTICES -> WELD VERTICES`, with modal stage dialogs disabled for the batch path.
- A partial `DIVIDE EDGE` result is no longer treated as an immediate batch failure when it produced valid pending source/inserted pairs. The batch moves and welds those pairs, then starts a fresh Divide cycle on the remaining live topology.
- The cycle repeats until `DIVIDE EDGE` reports no remaining Broken-T cases and produces no pending pairs. A Divide failure with no usable handoff, a Move failure, or a Weld failure still aborts and logs the exact failed stage.
- The standalone staged functions keep their existing behavior and can still show their normal dialogs when run directly.
- Runtime verification in 3ds Max is required for the new combined batch loop.

## 2026-10-07 — first combined Broken-T chain 1.201

- Added the first single-button `DIVIDE EDGE -> MOVE VERTICES -> WELD VERTICES` chain.
- Runtime on `BLOCK-A-MATERIAL001` showed `DIVIDE EDGE` successfully created 5 inserted vertices and 5 move pairs, then hit the known later-group stale edge state (`liveEdgeCount:0`).
- The 1.201 combined action aborted at that partial Divide result instead of consuming the valid 5-pair handoff, which is corrected by 1.202.

## 2026-10-07 — selected Edit Poly vertex weld test 1.200

- Updated `Loop-Cleaner` to `1.200`.
- Added `TEST WELD SELECTED VERTICES` as a debug-only Edit Poly weld proof.
- The test requires the current Modify-panel object to be an `Edit_Poly` with exactly two selected vertices. It keeps the lower vertex ID as the target and uses the higher vertex ID as the disposable source.
- The test calls native `EditPolyMod.WeldVertices target source -> Commit`, refreshes the modifier, and reports success only when the live vertex count decreases by exactly one.
- The test does not move either vertex, does not introduce a weld threshold or hidden position tolerance, and does not change the production Broken-T weld path.
- Runtime verification in 3ds Max is still required.

## 2026-10-07 — Broken-T MOVE VERTICES uses proven selected-vertex move path 1.199

- Updated `Loop-Cleaner` to `1.199`.
- Replaced the Broken-T pending-pair move implementation with the same active-Edit-Poly Vertex-selection / `MoveSelection -> Commit` path proven by `TEST MOVE SELECTED VERTEX`.
- Each stored `#(sourceVertexID, insertedVertexID)` pair isolates only the inserted vertex, reads both live positions, moves by `sourcePosition - insertedPosition`, and verifies the result at the active `postion preccision`.
- `MOVE VERTICES` performs no `DivideEdge` and no weld. Pending pairs are cleared only after every move completes successfully.
- Runtime verification in 3ds Max is still required.

## 2026-10-07 — selected Edit Poly vertex movement test 1.198

- Updated `Loop-Cleaner` to `1.198`.
- Added `TEST MOVE SELECTED VERTEX`.
- The test uses the first object in the current node selection, requires its current Modify-panel object to be an `Edit_Poly`, reads that modifier's current Vertex selection, and chooses the first selected vertex ID rather than hard-coding vertex 1.
- It isolates only that selected vertex, moves it exactly `1000mm` on Z with `MoveSelection -> Commit()`, leaves the moved vertex selected, and verifies the live post-move position at the active `postion preccision`.
- No Broken-T Divide, production MOVE VERTICES, weld, or topology behavior changed.
- Static source checks passed; runtime verification in 3ds Max is still required.

## 2026-10-06 — Edit Poly move test vertex 1 -> vertex 2 1.197

- Updated `Loop-Cleaner` to `1.197`.
- Changed only the explicit `TEST MOVE VERTEX` diagnostic: it creates a Plane with one Edit Poly, selects only vertex 1, reads live Edit Poly positions for vertices 1 and 2, and moves vertex 1 by `vertex2Position - vertex1Position` using `MoveSelection -> Commit()`.
- The test verifies vertex 1 reaches vertex 2 at the active `postion preccision` and verifies vertex 2 itself did not move.
- No Broken-T Divide or production move behavior changed. Runtime verification in 3ds Max is still required.

## 2026-10-06 — Edit Poly move test Plane runtime fix 1.196

- Updated `Loop-Cleaner` to `1.196`.
- Fixed the `TEST MOVE VERTEX` runtime error `Mesh operation on non-mesh: Plane`.
- Removed the invalid `update test_node` call after `Edit_Poly.MoveSelection -> Commit()`; the test now refreshes through the Edit Poly modifier and redraw only.
- The test contract is unchanged: create one Plane, add one Edit Poly, select vertex 1, move it exactly `1000mm` on Z, and verify the live Edit Poly vertex position.
- Static source checks passed; runtime verification in 3ds Max is still required.

## 2026-10-06 — MOVE VERTICES all-vertex +1000 mm Z proof 1.194

- Updated `Loop-Cleaner` to `1.194`.
- Temporarily changed the `MOVE VERTICES` button into a direct movement proof: it selects every live vertex in the working Broken-T `Edit_Poly` and moves the complete selection by exactly `1000mm` on Z with one native `MoveSelection` followed by `Commit()`.
- The 1000 mm value is converted with `units.decodeValue "1000mm"`; no hidden scene-unit assumption is used.
- The test verifies a live sample vertex after commit against `before + [0,0,1000mm]` using the existing explicit `postion preccision` contract and prints raw before/after/actual-delta diagnostics.
- Pending Broken-T source/inserted move pairs are intentionally preserved; this proof does not divide, weld, or consume the pending pair state.
- Static delimiter, syntax, protected-identifier, version, and changed-path checks passed. Runtime verification in 3ds Max is still required.

## 2026-10-06 — Broken-T MOVE VERTICES reliability 1.192

- Updated `Loop-Cleaner` to `1.192`.
- Replaced the staged Broken-T move loop with the shared stable Edit Poly movement pattern: switch the exact working modifier to Vertex mode, replace the vertex selection exactly for each inserted vertex, read the live source/inserted positions, compute `moveDelta = sourcePosition - insertedPosition`, run `MoveSelection`, then `Commit()`.
- `MOVE VERTICES` still performs no `DivideEdge`, no weld, and no extra post-move position-equality gate.
- The move stage now validates the pending pair record shape/IDs before geometry changes, restores the previous Edit Poly vertex selection and editing state afterwards, and keeps the pending pairs on failure for retry.
- Pending Broken-T move pairs are preserved across a Loop-Cleaner script reload when the previous live tool instance still points to the same valid node/Edit Poly. This allows loading 1.192 after a partial 1.191 Divide run and immediately using `MOVE VERTICES` without re-dividing the already split edge.
- The mistaken multi-object RMB-removal 1.192 change was rolled back; `USELESS LOOPS SELECT \ REMOVE` remains on the prior single-object contract.
- Static delimiter, `fn`, `if ... do`, identifier, version, and touched return-contract checks passed. Runtime verification in 3ds Max is still required.

## 2026-10-06 — Broken-T pending move Array handoff fix 1.191

- Updated `Loop-Cleaner` to `1.191`.
- Fixed the 1.190 runtime exception `Unknown property: "count" in OK` after a partially successful `DIVIDE EDGE`.
- Root cause: the partial-success path used `copy divide_result[3]` on an Array; in this runtime that expression returns `OK`, so `pending_broken_t_move_records` became `OK` instead of the expected move-pair Array.
- Partial Divide now stores the returned move-pair Array directly, matching the complete-success path. `MOVE VERTICES` also consumes that Array directly instead of using `copy` on it.
- Added an explicit pending-state type check before `.count`, so invalid handoff state reports a controlled Broken-T MOVE failure instead of throwing a rollout exception.
- DivideEdge and MoveSelection geometry behavior are unchanged. Runtime verification in 3ds Max is still required.

## 2026-10-06 — preserve partial Broken-T move pairs 1.190

- Updated `Loop-Cleaner` to `1.190`.
- Fixed `MOVE VERTICES` reporting `Run DIVIDE EDGE first; no pending Broken-T move pairs are stored.` after a partially successful `DIVIDE EDGE` run.
- `prepareBrokenTDivideStage()` already returned every successfully created `#(sourceVertexID, insertedVertexID)` pair even when a later target group failed; the caller discarded that partial handoff because it stored pending state only on complete Divide success.
- On Divide failure, any non-empty returned move-pair set is now retained in the normal pending Broken-T state, so `MOVE VERTICES` can immediately process the successfully divided group.
- Divide still reports failure for the later unresolved group; this change does not turn a partial Divide into full success and does not alter DivideEdge, MoveSelection, weld, or position-precision behavior.
- Static delimiter, `fn`, `if ... do`, protected-identifier, and version checks passed. Runtime verification in 3ds Max is still required.

## 2026-10-06 — 1.189 semi-stable Broken-T divide checkpoint

- Marked `Loop-Cleaner 1.189` as the current semi-stable Broken-T divide checkpoint; no code or version change was made.
- Runtime on `BLOCK-A-MATERIAL001` with `postion preccision = 1mm` detected 6 Broken-T cases across 2 components and selected 10 edges.
- One original target-edge group completed successfully, producing 5 inserted vertices and 5 stored move pairs.
- The next target group then failed because its previously stored original edge ID `138` was no longer live after the earlier committed splits (`liveEdgeCount:0`, preserved endpoints `14` and `86`).
- This proves the direct `DivideEdge -> Commit()` group itself is working, while stored original edge IDs for later independent groups can become stale after prior topology changes.
- Preserve 1.189 as the recovery/reference point before changing multi-group target re-resolution.

## 2026-10-06 — direct stored target-edge Divide 1.189

- Updated `Loop-Cleaner` to `1.189`.
- `DIVIDE EDGE` no longer searches for the first planned Broken-T edge by endpoint pair. It uses the exact target edge ID captured by the Broken-T detector, removing ambiguity when duplicate/overlapping topology shares the same endpoint pair.
- The stored target edge is oriented by its preserved endpoint vertex IDs, not by rounded positions.
- After each successful `DivideEdge -> Commit()`, continuation still uses the exact `(newly appended vertex ID, untouched far endpoint vertex ID)` child edge.
- `MOVE VERTICES` is unchanged. No weld behavior was added.
- Static syntax/delimiter/version checks passed; runtime verification in 3ds Max is still required.

## 2026-10-06 — Broken-T exact target-edge identity 1.188

- Updated `Loop-Cleaner` to `1.188`.
- Fixed `DIVIDE EDGE` failing before the first split with `Could not resolve exactly one live edge for a planned Broken-T target segment`, especially at coarse `postion preccision` values such as `1mm`.
- Root cause: missing-target plans were grouped by precision-quantized endpoint positions, so distinct nearby target edges could collapse into one group and the first live edge lookup could become ambiguous before any `DivideEdge` ran.
- Missing-target plans now preserve the original target edge ID plus its two endpoint vertex IDs. Groups are keyed by that exact pre-divide target edge ID instead of rounded endpoint positions.
- Before each group, the live target edge is resolved by the preserved endpoint vertex pair. After every committed split, the remaining child segment is resolved by the exact pair `(newly appended vertex ID, untouched far endpoint vertex ID)`, so repeated splits no longer depend on positional edge re-resolution.
- Position precision remains active for Broken-T detection and position-based comparisons, but it no longer merges distinct topology edges for Divide grouping/continuation.
- `DIVIDE EDGE` still performs only committed splits and stores ordered source/inserted move pairs. `MOVE VERTICES` remains unchanged and performs no divide or weld.
- Static delimiter, `fn`, `if ... do`, protected-identifier, version, and stale pre-split failure-path checks passed. Runtime verification in 3ds Max is still required.

## 2026-10-06 — split Broken-T Divide / Move stages 1.187

- Updated `Loop-Cleaner` to `1.187`.
- Replaced the combined `BROKEN T JUCTIONS SELECT \ FIX` UI action with explicit `BROKEN T SELECT`, `DIVIDE EDGE`, and `MOVE VERTICES` controls.
- `DIVIDE EDGE` now runs only the missing-opposite multi-`DivideEdge` stage, committing each split and storing ordered `#(sourceVertexID, insertedVertexID)` pairs in transient tool state. It performs no vertex movement and no weld.
- `MOVE VERTICES` consumes only those pending pairs and runs the existing one-by-one `Select #Vertex -> MoveSelection -> Commit()` sequence. It performs no `DivideEdge` and no weld.
- The move-pair state is kept after a failed move so the move stage can be retried; it is cleared after a successful move or when a new Divide stage starts.
- Added an explicit Edge-context reset before every independent target-edge group so multiple Divide groups do not inherit Vertex context from the previous group.
- Static delimiter, `fn`, `if ... do`, protected `modifier` identifier, stale-control-name, and version checks passed. Runtime verification in 3ds Max is still required.

## 2026-10-06 — position-precision runtime round fix 1.186

- Updated `Loop-Cleaner` to `1.186`.
- Runtime on `BLOCK-A-MATERIAL001` failed before the first Broken-T split with `Call needs function or class, got: undefined`; the failing call was the unverified `round()` global inside position-precision quantization.
- Replaced that call with explicit nearest-step scalar quantization using verified `floor()` arithmetic, including symmetric handling for negative coordinates.
- `roundPositionToPrecision()` still quantizes temporary comparison copies only; scene geometry is not snapped or rounded.
- The Broken-T `DivideEdge`, move, and weld sequence is otherwise unchanged.
- Static delimiter, `fn`, `if ... do`, and remaining `round()` call checks passed. Runtime verification in 3ds Max is still required.

## 2026-10-06 — Stage-06 multi-Divide + ordered Broken-T move 1.184

- Updated `Loop-Cleaner` to `1.184`.
- Replaced the free `POSITION` spinner with the shared `postion preccision` dropdown: `1mm`, `0.1mm`, `0.01mm`, default `0.01mm`; the selected millimeter value is persisted and converted explicitly to current system units.
- Broken-T edge identity/re-resolution now compares temporary position copies quantized to the selected precision; actual vertex positions are never snapped or rounded.
- Reworked the missing-target insert pass to generalize the proven `EPoly-Stack-Test` Stage 06 method: for `N` required vertices it performs exactly `N` `DivideEdge` calls, commits after every split, and re-resolves the remaining child segment geometrically before the next split. The `DivideEdge` return value is not used as a vertex ID.
- The insert helper records the appended vertex ID after each verified `+1` vertex split. Source vertices and inserted vertices are both sorted along the same preserved target-edge direction before pairing, preventing reversed-edge ordering from shifting the pairs.
- The move pass now stores only `#(sourceVertexID, insertedVertexID)` pairs, switches to Vertex context, reads both live positions immediately before each move, isolates one inserted vertex, runs `MoveSelection`, commits, then continues to the next pair. No extra post-move position-equality gate is applied.
- Existing descending inserted-ID weld order and final Broken-T topology verification remain unchanged.
- Static delimiter, `if ... do`, `fn`, protected-identifier, and stale-control-name checks passed. Runtime verification in 3ds Max is still required.

## 2026-10-06 — 288 px dialog width 1.183

- Updated `Loop-Cleaner` to `1.183`.
- Set the standalone rollout width from `336 px` to `288 px`.
- Refit the existing controls to the narrower dialog while preserving the current vertical layout, 32 px button heights, left/right docking behavior, tool-title restart behavior, and all geometry/selection logic.
- Full-width controls now use `240 px` inside the existing 24 px content margins; the title button uses `264 px` inside 12 px margins.
- No Broken-T, topology, tolerance, selection, or removal behavior changed.
- Static source/layout checks passed; runtime UI verification in 3ds Max is still required.

## 2026-10-06 — Broken-T post-DivideEdge vertex-context read fix 1.182

- Updated `Loop-Cleaner` to `1.182`.
- Runtime 1.181 proved the appended vertex selection itself was correct (`#{142}`), but both the appended/source `GetVertex` reads performed immediately after the grouped `DivideEdge` stage while Edit Poly was still at Edge level returned `[0,0,0]`. The resulting delta was therefore computed from zero even though `MoveSelection` acted on the real live appended vertex.
- The repair now switches the active Edit Poly to `#Vertex` / `subObjectLevel = 1` immediately after the multi-insert commit and refresh, before reading appended positions, sorting inserted records, re-reading source positions, or building MVOE move records.
- Removed the 1.181 `parent:node.objectTransform` experiment. MVOE is back to the proven `Select #Vertex -> MoveSelection move_delta -> Commit()` sequence with the corrected post-insert vertex reads.
- Added one `BROKEN T POST INSERT VERTEX CONTEXT` diagnostic showing the active level, current vertex selection, and appended ID range before those reads.
- `addMultipleVerticesToEdge()`, grouped insertion count/order, welding, and the explicit `POSITION` tolerance are unchanged.
- Static syntax/safety validation passed; runtime verification in 3ds Max is still required.

## 2026-10-06 — Broken-T object-space MoveSelection fix 1.181

- Updated `Loop-Cleaner` to `1.181`.
- Runtime testing proved the appended Broken-T move lands correctly when the node is at the world origin but is offset when the node is translated, so the previous default `MoveSelection` coordinate context was wrong for the stored Edit Poly vertex delta.
- Kept the existing source/inserted `GetVertex` positions and `move_delta = source_target_position - original_position` unchanged.
- The appended-vertex MVOE pass now calls `MoveSelection move_delta parent:node.objectTransform`, using the native Edit Poly `parent:` coordinate-system argument so the delta is applied in the same object geometry space from which the vertex positions were read.
- Added `moveParent` to the existing MVOE BEFORE diagnostic so the exact transform used by the move remains visible in Listener output.
- `addMultipleVerticesToEdge()`, insertion ordering/count logic, welding, and the explicit `POSITION` tolerance are unchanged.
- Static syntax/safety validation passed; 3ds Max runtime verification is still required.

## 2026-10-06 — Broken-T appended-vertex move context fix 1.180

- Updated `Loop-Cleaner` to `1.180`.
- Fixed the appended Broken-T MVOE pass running immediately after `addMultipleVerticesToEdge()` while the active Edit Poly sub-object context was still Edge level from the insertion stage.
- Before clearing/selecting appended vertices, `moveBrokenTVertexRecords()` now explicitly activates the target node and Edit Poly modifier, disables stack selection, sets `selectMode = 0`, disables the cage, switches the Edit Poly selection level to `#Vertex`, and sets `subObjectLevel = 1`.
- The actual per-vertex operation remains the proven sequence: isolate one appended vertex with `Select #Vertex`, call `MoveSelection move_delta`, `Commit()`, read the moved vertex, and verify it against the stored source target using the existing explicit `POSITION` tolerance.
- `addMultipleVerticesToEdge()`, insertion ordering, movement math, POSITION tolerance, transforms, and welding logic are unchanged.
- Existing MVOE numeric diagnostics remain in place so the runtime result is still visible if movement fails.
- Static syntax/safety validation passed; 3ds Max runtime verification is still required.

## 2026-10-06 — Broken-T MVOE runtime instrumentation 1.179

- Updated `Loop-Cleaner` to `1.179` for a diagnostic-only Broken-T move pass; no weld behavior or coordinate conversion was changed.
- Kept `addMultipleVerticesToEdge()` unchanged.
- The appended-vertex MVOE stage now prints the active Edit Poly selection level/current operation, pre-existing Vertex and Edge selections, and verifies that the Vertex selection is fully cleared before the per-record move loop.
- For every appended vertex, Listener output now includes the preserved source vertex ID, appended vertex ID, exact selected Vertex BitArray immediately before `MoveSelection`, original appended position, stored pre-`DivideEdge` source target position, move delta, expected position, actual position after `Commit()`, measured distance, and the configured `POSITION` tolerance.
- The repair also re-reads each preserved source vertex after all `DivideEdge` commits and prints its distance from the stored pre-insert source target, allowing stale/reindexed source IDs to be distinguished from a movement failure.
- Selection-isolation, selection-clear, invalid-ID, undefined-position, and cleanup-read failures now emit explicit diagnostics before the existing failure path.
- This version intentionally does not change `SetEPolySelLevel`, transforms, movement math, welding, or the `POSITION` threshold. Runtime output from 3ds Max is required before choosing the functional fix.
- Static syntax/safety validation passed; 3ds Max runtime verification is still required.

## 2026-10-06 — tolerant child-edge re-resolution 1.178

- Updated `Loop-Cleaner` to `1.178`.
- Fixed `addMultipleVerticesToEdge()` failing after a successful first `DivideEdge` because the remaining child edge was still re-resolved with exact Point3 equality.
- The helper now receives the same configured Broken-T `POSITION` tolerance and matches the inserted endpoint plus the untouched far endpoint with `distance(...) <= positionTolerance`.
- After the child edge is resolved, the next split continues from the actual live Edit Poly endpoint positions read from that resolved edge instead of the theoretical pre-commit Point3, preventing accumulated float drift across repeated inserts.
- The Broken-T move and weld stages are unchanged.
- Static syntax/safety validation passed; 3ds Max runtime verification is still required.

## 2026-10-06 — unified Broken-T position threshold 1.177

- Updated `Loop-Cleaner` to `1.177`.
- Added one persistent `POSITION` spinner in millimeters for all Broken-T positional comparisons. The spinner range is `0.01 .. 1.0 mm`, step `0.01 mm`, with requested default `0.01 mm`; values such as `0.01`, `0.1`, and `1.0 mm` use the same single backend threshold.
- Changed the previous fixed `0.1 mm` Broken-T tolerance to this UI-controlled value and persisted it in `Loop-Cleaner.ini` as `BrokenTPositionToleranceMM`.
- The same configured threshold now controls Broken-T detection, existing-target lookup, child-edge/insert geometry checks, existing-target move verification, and the appended-vertex MVOE post-`Commit()` verification.
- Replaced the MVOE exact Point3 equality gate with `distance(actual, expected) <= positionTolerance`; the vertex itself is not rounded or snapped.
- Added Listener diagnostics for a failed MVOE position verification, including vertex ID, original position, delta, expected/actual positions, measured distance, and active tolerance.
- Existing `Select #Vertex -> MoveSelection -> Commit()` movement and weld ordering are unchanged.
- Static syntax/safety validation passed; 3ds Max runtime verification is still required.

## 2026-10-06 — exact MVOE Broken-T vertex move 1.176

- Updated `Loop-Cleaner` to `1.176`.
- Replaced the per-vertex Broken-T move helper with the exact `MOVE SELECTED VERTS OUT` structure from `EPoly-Stack-Test_1.24.ms`.
- Before moving anything, the repair builds `move_records` as `#(vertexID, originalPosition, moveDelta)` using the appended vertex's current `Edit_Poly.GetVertex` position and the pre-`DivideEdge` source target position captured in the same Edit Poly coordinate space.
- The move pass clears the current vertex selection once, then for each record isolates exactly one appended vertex with `Select #Vertex`, calls `MoveSelection moveDelta`, commits, verifies `GetVertex == originalPosition + moveDelta` exactly, and deselects the isolated vertex.
- `RefreshScreen()` and `completeRedraw()` run after the complete move pass, matching the proven MVOE pattern instead of resetting Edit Poly context around every individual move.
- No object/world transform conversion, new tolerance, rounding, or scene-specific vertex ID was introduced.
- Welds still begin only after every appended vertex has completed the verified move pass, then run in descending appended-vertex ID order.
- Static syntax/safety validation passed; 3ds Max runtime verification is still required.

## 2026-10-06 — raw Edit Poly MoveSelection path 1.175

- Updated `Loop-Cleaner` to `1.175`.
- Replaced the inserted Broken-T vertex move with the exact working `EPoly-Stack-Test` pattern: isolate one vertex with `Select #Vertex`, compute one direct delta in Edit Poly vertex coordinates, call `MoveSelection`, `Commit()`, refresh, then deselect that vertex.
- Before any `DivideEdge` changes the target edge, each Broken-T source vertex position is captured directly with `edit_poly_mod.GetVertex source_vertex_id node:node`. That raw Point3 is carried through the insert stage as the move target.
- The appended vertex is then moved with `move_delta = source_target_position - current_position`; no `node.objectTransform`, inverse transform, world-space conversion, source re-resolution, or post-move alignment gate participates in this inserted-vertex move.
- Existing multi-insert grouping, descending weld order, explicit `0.1 mm` detection tolerance, and unrelated UI behavior are unchanged.
- Static syntax/safety checks passed; 3ds Max runtime verification is still required.

## 2026-10-06 — direct stored-point Broken-T move 1.174

- Updated `Loop-Cleaner` to `1.174`.
- Removed the inserted-vertex alignment path that targeted a preserved source vertex through a second vertex lookup and then rejected the operation through post-move geometry checks.
- After the multi-insert succeeds, each appended vertex now receives the already stored Broken-T source Point3 directly. The move is exactly: read the appended Edit Poly vertex, transform that current point to world space, compute `storedSourceWorld - currentWorld`, select only that appended vertex, call `MoveSelection`, then `Commit()`.
- No source-position equality gate or post-move alignment comparison remains in this inserted-vertex stage. The following weld and its exact one-vertex topology reduction are the destructive success check.
- Source ordering is also computed against the stored world-space target-edge endpoints, so source Point3 ordering is never mixed with raw Edit Poly vertex coordinates.
- Existing multi-insert grouping, descending weld order, explicit `0.1 mm` detection tolerance, UI behavior, and unrelated tools are unchanged.
- Static syntax/safety validation passed; 3ds Max runtime verification is still required.

## 2026-10-06 — 00-08 batch UI 1.173

- Updated `Loop-Cleaner` to `1.173`.
- Numbered the production UI actions `00` through `08`.
- Split Broken-T into separate `07 BROKEN T SELECT` and `08 BROKEN T FIX` buttons so selection and destructive repair can be independently included in a batch.
- Added one checkbox immediately before every `00`-`08` production button.
- Added `BATCH RUN`, which executes only checked production actions in numeric order using each button's normal LMB behavior; `08` calls the explicit Broken-T repair action.
- Batch checkbox states are saved to and restored from the existing `Loop-Cleaner.ini` under a dedicated `Batch` section with keys `00` through `08`.
- Existing debug 1-4 controls, QUIET, ANGLE, and unrelated geometry behavior are unchanged.
- Static delimiter/version checks passed; 3ds Max runtime UI verification is still required.

## 2026-10-06 — direct move after multi-insert 1.172

- Updated `Loop-Cleaner` to `1.172`.
- Removed the pre-move source-position validation that compared a world-space stored Broken-T source point against the object-space value returned by `Edit_Poly.GetVertex`; that false mismatch stopped the repair before any new vertex was moved.
- After `addMultipleVerticesToEdge()` succeeds, appended vertices are now moved immediately onto their paired preserved source vertices through the existing Edit Poly vertex-move helper.
- The source vertex IDs remain the pre-insert IDs while the new divided vertices occupy the appended ID range, so the move stage no longer performs the invalid cross-space equality gate.
- All inserted vertices are still moved before welding, and welds still run in descending inserted-vertex ID order so remaining IDs stay stable.
- No new tolerance, coordinate rounding, or scene-specific vertex IDs were introduced.
- Static syntax/safety validation passed; 3ds Max runtime verification is still required.

## 2026-10-06 — appended-ID move and descending weld 1.171

- Updated `Loop-Cleaner` to `1.171`.
- Runtime diagnostics confirmed the grouped multi-insert stage succeeds and appends the new target-edge vertices as one contiguous ID range after the pre-insert vertex count.
- The Broken-T repair now uses that appended live ID range directly instead of trying to re-resolve inserted vertices from their temporary evenly spaced positions.
- Newly inserted vertices and stored Broken-T sources are both sorted along the same live target-edge direction, paired by order, and every inserted vertex is moved onto its preserved T-source position before any weld occurs.
- After all moves complete, inserted/source pairs are welded in descending inserted-vertex ID order. Because inserted IDs are above all preserved source IDs, each weld removes the current highest disposable vertex without invalidating the IDs of remaining inserted vertices or preserved T sources.
- The stored source vertex ID is retained in the pre-insert plan and validated against its unchanged source position before alignment.
- Topology is rebuilt only after the complete move/weld group finishes, then the existing broken-T case-count verification continues.
- No scene-specific vertex IDs are used in production code; diagnostic IDs such as `142..146` remain runtime observations only.
- Existing `0.1 mm` Broken-T tolerance, multi-insert helper, docking behavior, and unrelated Loop-Cleaner features are unchanged.
- Static syntax/safety validation passed; 3ds Max runtime verification is still required.

## 2026-10-06 — grouped multi-vertex DivideEdge helper 1.170

- Updated `Loop-Cleaner` to `1.170`.
- Replaced the active Broken-T missing-target insertion sequence with the user-provided `addMultipleVerticesToEdge()` method.
- Missing Broken-T sources are grouped by their original target edge. One call inserts the full required vertex count on that edge, committing every `DivideEdge` and re-resolving the remaining child edge geometrically after each split.
- The inserted vertices are created evenly along the target edge, then paired with the stored T sources in edge order, moved onto those source positions, and welded into the preserved T-source vertices. This keeps vertex order stable even when the actual T positions are not evenly spaced.
- Multiple missing sources on one original edge therefore no longer depend on Broken-T rediscovery or the previous child-edge point resolver. Multiple independent target edges are processed the same way.
- Each edge group verifies exact `+N` vertices, `+N` edges, unchanged face count, and rebuilds live Edit Poly topology before welding.
- Existing `0.1 mm` Broken-T tolerance, existing-target weld behavior, left/right docking, and unrelated Loop-Cleaner behavior are unchanged.
- Static syntax/safety validation passed; 3ds Max runtime verification is still required.

## 2026-10-06 — stored multi-insert plan for repeated target edge splits 1.169

- Updated `Loop-Cleaner` to `1.169`.
- Runtime feedback proved the current target edge is correctly resolved and one `DivideEdge` succeeds, but only one vertex was added when several Broken-T source points required splits on that same original edge. Diagnostic edge ID `236` is not hard-coded.
- Root cause: after the first split, the previous path rebuilt `findBrokenTJunctionCases()` and depended on it to rediscover the remaining source point. The first successful split changes the strict vertex-on-edge classification, so later required points can disappear before they are inserted.
- Missing targets are now captured before the first split as a topology-independent insertion plan containing the source world point, source-neighbor world points, and original target-edge endpoint world points.
- Each planned point independently resolves the current child edge that contains it, runs direct `Edit_Poly.DivideEdge` + `Commit()`, verifies exact `+1` vertex / `+1` edge / unchanged faces, rebuilds topology, re-resolves the preserved source and inserted vertex geometrically, aligns, and welds immediately.
- Two or more required vertices on one original edge now follow the proven Stage 06 strategy from `EPoly-Stack-Test_1.20.ms`: split, commit, discard the old edge ID, resolve the correct child segment from geometry, and split again. Multiple target edges use the same plan.
- No new tolerance, rounding, base Editable Poly cleanup, or TriMesh component mapping was added. Existing `0.1 mm` Broken-T tolerance and unrelated Loop-Cleaner behavior remain unchanged.
- Static syntax/safety validation passed; 3ds Max runtime verification is still required.

## 2026-10-06 — atomic Broken-T split/weld investigation 1.168

- Updated `Loop-Cleaner` to `1.168` during investigation of repeated inserts on one target edge.
- The version confirmed that direct `DivideEdge` + `Commit()` is the correct insertion primitive, but runtime feedback showed the remaining multi-insert sequencing was still incomplete: only the first required point on the target edge was materialized.
- This intermediate version is preserved as the previous version; `1.169` replaces the rediscovery-dependent sequence with a stored geometry plan.

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