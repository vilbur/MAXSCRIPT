# Redundant-Loop-Fixer Changes

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
