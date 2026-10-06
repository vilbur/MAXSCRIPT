# Vertex Cleaner — Changes

## 2026-10-06 — project 0.839

- Renamed the canonical Tool identity to `Vertex-Cleaner` / **Vertex Cleaner**. The repository folder, current main/backend/UI/audit filenames, package sibling references, restart prefix, INI filename, UI titles/messages, integration display name, audit expectations, and current documentation now use the new identity; existing `TwoEdgeVerts` globals and the `two-edge-verts` integration key remain unchanged for compatibility.
- `Vertex-Cleaner.ms` advances to 0.09, `Vertex-Cleaner-FN.ms` to 0.81, `Vertex-Cleaner-UI.ms` to 0.79, and the audit targets project 0.839. This change is naming-only; geometry classification and topology behavior are unchanged.

## 2026-10-05 — project 0.838

- `SEARCH 2-EDGE VERTS` FORCE LMB is no longer completely unfiltered. `Vertex-Cleaner-FN.ms` advances to 0.80 / project 0.838 and now requires exactly two actually visible edges whose directions deviate by no more than **15 degrees** from a straight 180-degree continuation. FORCE still ignores the filtered T-junction/border-corner class exclusions and still does not populate the manual remove queue.
- `Vertex-Cleaner-UI.ms` advances to 0.78 / project 0.838 with the FORCE tooltip updated for the 15-degree limit. `Vertex-Cleaner-Audit-Test.ms` advances to project 0.838/backend 0.80/frontend 0.78, updates the hidden-branch classification fixture to expect only its two near-straight FORCE vertices, and adds a dedicated 10-degree-pass / 20-degree-fail FORCE test for both Editable Poly and Edit Poly.

## 2026-10-05 — project 0.837

- `Vertex-Cleaner-UI.ms` advances to 0.77 / project 0.837. The bottom native `RESTART` button is removed and replaced by a full-width `.NET` tool title button at the top labeled `Vertex Cleaner`; its LMB uses the canonical main-entry restart path. The standalone rollout is now registered as a CUI dialog bar that may float or dock only left/right, with top/bottom docking excluded.
- Added floating-dialog position persistence in `Vertex-Cleaner.ini` under the 3ds Max plugcfg directory. Floating moves are remembered and restored on the next standalone open, while left/right docked movement does not overwrite the saved floating position; registered dialog bars are unregistered before destruction. `Vertex-Cleaner-Audit-Test.ms` advances to project 0.837 and verifies the title button plus valid floating/left/right CUI registration. Backend geometry remains 0.79 / project 0.836 and is unchanged.

## 2026-10-05 — project 0.836

- Split `SEARCH 2-EDGE VERTS` into two non-destructive search modes. LMB is now FORCE search and selects every live vertex with exactly two visible incident edges, without the existing T-junction/border-corner angle/class exclusions. RMB keeps the previous filtered redundant-vertex classification and stores that filtered result for the existing `SELECT \ REMOVE` manual queue.
- Moved the former SEARCH RMB fixed-point cleanup to a dedicated `REMOVE` button. `REMOVE` keeps the existing filtered live re-search/removal behavior; `FIX SELECTED VERT` and `SELECT \ REMOVE` remain separate. `Vertex-Cleaner-FN.ms` advances to 0.79 and `Vertex-Cleaner-UI.ms` to 0.76, both on project 0.836. The audit advances to project 0.836/backend 0.79 and verifies FORCE vs filtered SEARCH on Editable Poly and Edit Poly.

## 2026-10-05 — project 0.835

- Completed a strict Editable Poly dead-topology/index-safety audit. `Vertex-Cleaner-FN.ms` advances to 0.78 / project 0.835 with one controlled `ensureCleanEditablePolyTopology()` boundary: index-sensitive Editable Poly phases now validate `polyop.getHasDeadStructs` before counts, selections, ID loops, adjacency, or endpoint mapping; dead structures are collapsed only at that boundary; persistent component-ID state is invalidated whenever dead topology is detected and after every topology-changing operation. If an Edit Poly modifier exists above the base, automatic base collapse is blocked instead of reindexing topology underneath the modifier.
- Fixed stale-ID paths in true-two-edge/T-junction/border/duplicate detectors, selection writes, manual candidate stepping, native Remove/fallback weld verification, duplicate collapse, neighbor lookup, explicit candidate storage, fixed-point cleanup, and `FIX SELECTED VERT`. Pre-change source IDs and BitArrays are rejected or reacquired after collapse; post-operation Editable Poly counts are read only after synchronization; manual candidate queues are rebuilt from fresh topology after successful removal. Edit Poly fallback paths now reacquire the source from current modifier topology after native Remove attempts rather than reusing pre-operation IDs.
- `Vertex-Cleaner-Audit-Test.ms` advances to project 0.835/backend 0.78. It now checks that production Editable Poly destructive paths return with compact topology before fresh ID reads and adds a dead-topology synchronization stage covering controlled collapse, cached-ID invalidation, and the guard that refuses to collapse an Editable Poly base when an Edit Poly modifier exists above it. No geometry classification tolerance or unrelated UI behavior changed.

## 2026-10-03 — project 0.834

- Fixed `FIX SELECTED VERT` LMB so it no longer uses native Remove Vertex as its primary operation. The direct fix now target-welds the selected live true-two-edge source into its closest actually visible neighbor, keeping the opposite source edge as the direct edge between the two surviving neighbors and preserving the chosen target neighbor position. `Vertex-Cleaner-FN.ms` advances to 0.77 / project 0.834; stored/manual `SELECT \\ REMOVE` and SEARCH RMB cleanup keep their existing audited native Remove Vertex primary path.
- `Vertex-Cleaner-UI.ms` advances to 0.75 / project 0.834 with the direct-fix tooltip updated to state the edge-preserving target-weld behavior. The audit advances to project 0.834 and now requires both Editable Poly and Edit Poly direct fixes to remove exactly one vertex, preserve an edge between the source's two surviving visible neighbors, and keep the chosen target neighbor at its exact original position.

## 2026-10-03 — project 0.833

- Fixed standalone startup after the package rename. `Vertex-Cleaner.ms` advances to 0.08 / project 0.833, resolves the renamed backend/UI siblings first and accepts the pre-rename sibling filenames only as a transition fallback for partially synchronized Google Drive folders. Missing/failed backend or UI loads now preserve a concrete startup error and show it when the canonical main is run standalone instead of silently returning false.
- `Vertex-Cleaner-UI.ms` advances to 0.74 / project 0.833 and verifies that `createDialog` leaves a real open dialog; dialog creation exceptions are reported with the original exception text. `Vertex-Cleaner-Audit-Test.ms` advances to project 0.833 with a dedicated standalone-startup stage that executes the canonical main in `#standalone`, requires startup success, verifies `TwoEdgeVerts_UI.inDialog`, then closes the test dialog. Geometry/backend behavior is unchanged.


## 2026-10-03 — project 0.832

- Renamed the canonical Tool repository folder from `Two-Edge-Verts` to `Vertex-Cleaner`, matching the rollout title **Vertex Cleaner**. Renamed the current package files in place to `Vertex-Cleaner.ms`, `Vertex-Cleaner-FN.ms`, `Vertex-Cleaner-UI.ms`, and `Vertex-Cleaner-Audit-Test.ms`; Drive file/folder IDs are preserved. Legacy `TwoEdgeVerts` globals and the `two-edge-verts` integration key remain unchanged for compatibility.
- `Vertex-Cleaner.ms` advances to 0.07 / project 0.832 and now loads the renamed `-FN` and `-UI` siblings. `Vertex-Cleaner-UI.ms` advances to 0.73 / project 0.832 with its package-entry reference updated. The audit advances to project 0.832, loads the renamed canonical main entry, and verifies the canonical main filename/version. Backend code is unchanged at 0.76 / project 0.831; only its canonical Drive filename changes. Added new-name snapshots `Vertex-Cleaner_0.07.ms`, `Vertex-Cleaner-UI_0.73.ms`, and `Vertex-Cleaner-Audit-Test_0.832.ms` under `_Versions`.

## 2026-10-03 — project 0.831

- Hardened true two-edge detection failure handling so a failed detector pass can no longer masquerade as a valid zero-candidate result. `Two-Edge-Verts-FN.ms` advances to 0.76 / project 0.831 with `wasLastTwoEdgeDetectionSuccessful()`: both Editable Poly and Edit Poly detection explicitly publish success state, `SEARCH 2-EDGE VERTS`, candidate storage, manual removal, and fixed-point RMB cleanup abort safely when that state is false, and incomplete batch cleanup reports detector/selection-clear failures instead of claiming completion.
- Hardened Edit Poly selection reads on selection/reselection paths used before native Remove Vertex and target-weld fallback. A failed `GetSelection #Vertex` read now aborts the affected operation instead of being normalized to `#{}`. The audit advances to project 0.831 with a dedicated valid-empty vs failed-detector state test and continues to cover both Editable Poly and Edit Poly workflows.

## 2026-10-03 — project 0.830

- Added a prominent 48 px `FIX SELECTED VERT` button directly below the live vertex-count label. It requires exactly one selected vertex and fixes that live true-two-edge source immediately through the existing audited native Remove Vertex / visible-neighbor weld fallback, without requiring SEARCH/manual queue state. Successful direct fixes clear component selection and reset stored manual candidate state so changed vertex IDs cannot leave a stale queue.
- `SELECT \ REMOVE` RMB keeps the repaired 0.829 queue-aware path first and now falls back to the direct selected-vertex fix only if the stored path cannot run. `Two-Edge-Verts-FN.ms` advances to 0.75 / project 0.830 with `fixSelectedVertex()`, `Two-Edge-Verts-UI.ms` advances to 0.72 / project 0.830 with the larger direct-fix control and RMB fallback, and the audit advances to project 0.830 with direct-fix coverage for Editable Poly and Edit Poly.

## 2026-10-03 — project 0.829

- Fixed manual `SELECT \ REMOVE` RMB so removal no longer depends on the armed source still being the only selected vertex. The stored object/topology context and highest armed ID remain authoritative; RMB now proceeds into the existing low-level remove path, which re-selects the exact armed source and revalidates it as a live true-two-edge vertex before native Remove Vertex / fallback. The stable `SEARCH 2-EDGE VERTS` RMB batch path is unchanged. `Two-Edge-Verts-FN.ms` advances to 0.74 / project 0.829. The audit advances to project 0.829 and explicitly clears component selection after LMB before RMB on both Editable Poly and Edit Poly, requiring one vertex to still be removed successfully.

## 2026-10-03 — project 0.828

- Replaced the static top info text with a live vertex counter: `VERTS <all> - SEL <selected> \ UNSEL <unselected>`. `Two-Edge-Verts-FN.ms` advances to 0.73 with `getSelectedVertexCounts()`, reading counts from the active single Editable Poly/Edit Poly topology without changing geometry or selection. `Two-Edge-Verts-UI.ms` advances to 0.71 and refreshes the label on rollout open plus a lightweight timer so viewport sub-object selection changes are reflected live.


## 2026-10-02 — project 0.827

- `SEARCH 2-EDGE VERTS` RMB keeps the stable fixed-point batch-removal geometry unchanged but now runs in quiet mode. Successful batch passes suppress Edit Poly search diagnostics, per-source native-remove/fallback status, the backend completion summary, and the UI completion echo; invalid input, real operation errors, and incomplete cleanup remain visible. `Two-Edge-Verts-FN.ms` advances to 0.72 and `Two-Edge-Verts-UI.ms` to 0.70.


## 2026-10-02 — project 0.826

- Split the production `SELECT BORDER CORNERS` control into `SELECT INNER BORDER CORNERS` and `SELECT OUTTER BORDER CORNERS`. The base border-corner rule is unchanged; inner vs outer is determined from the oriented turn of the two open border edges relative to their adjacent face winding, so inner square-hole corners and exterior perimeter corners are selected separately even when the whole mesh normal orientation is flipped.
- `Two-Edge-Verts-FN.ms` advances to 0.71 / project 0.826 with inner/outer border-corner getters and selectors while retaining `getBorderCornerVerts()` / `selectBorderCornerVerts()` as the compatibility union. `Two-Edge-Verts-UI.ms` advances to 0.69 / project 0.826 with the two separate buttons. The audit advances to project 0.826 and adds square-ring coverage for Editable Poly and Edit Poly, requiring four inner corners, four outer corners, disjoint sets, and exact reconstruction of the legacy union.

## 2026-10-02 — project 0.825

- `SEARCH 2-EDGE VERTS` RMB is now a fixed-point cleanup instead of a frozen candidate batch. It searches the complete live object, removes only the highest current true-two-edge vertex, re-runs SEARCH on the changed topology, and repeats until a fresh pass finds zero candidates. This fixes adjacent/related candidates becoming invalid after another vertex is removed and also handles newly exposed candidates across separate elements automatically.
- `Two-Edge-Verts-FN.ms` advances to 0.70 / project 0.825 with `removeTwoEdgeVertsUntilStable()`. `removeSelectedTwoEdgeVertsBatch()` remains as a compatibility wrapper. `Two-Edge-Verts-UI.ms` advances to 0.68 / project 0.825 and delegates RMB directly to the backend. The audit harness advances to project 0.825 and verifies fixed-point cleanup leaves no true-two-edge candidates on fresh Editable Poly and Edit Poly fixtures.

## 2026-10-02 — project 0.824

- `SEARCH 2-EDGE VERTS` now has RMB batch removal. It rebuilds the existing manual candidate queue from the currently selected true-two-edge vertices, then repeatedly runs the audited highest-ID-first `SELECT \ REMOVE` backend path until the queue is empty. Every source keeps the existing live revalidation and native Remove Vertex / visible-neighbor fallback behavior; if any candidate cannot be selected or fixed, the batch stops without silently consuming the remaining queue.
- `Two-Edge-Verts-UI.ms` advances to 0.67 / project 0.824 with the SEARCH RMB callback and LMB/RMB tooltip. Backend 0.68 / project 0.823 is unchanged because RMB reuses its existing candidate-state and one-candidate fix APIs; the audit harness is unchanged for the same reason.

## 2026-10-02 — project 0.823

- Expanded the tool display identity to **Vertex Cleaner** while preserving the existing `Two-Edge-Verts*.ms` package filenames, globals, and integration key for compatibility. `Two-Edge-Verts.ms` advances to 0.06, `Two-Edge-Verts-UI.ms` to 0.66, and `Two-Edge-Verts-FN.ms` to 0.68.
- Added exact-position duplicate-vertex support for Editable Poly and Edit Poly. `getDuplicatePositionVerts()` selects every vertex in an exact `Point3` duplicate group; `collapseDuplicatePositionVerts()` / `collapseDuplicatePositionVertsOnSelection()` collapse each group pairwise, reacquire live IDs after every weld, verify every one-vertex count drop, and use no tolerance or threshold.
- Re-enabled `SELECT T-JUNCTION VERTS`, added `SELECT BORDER T-JUNCTIONS`, and exposed `SELECT BORDER CORNERS` in the production UI. Border T-junctions are the T-junction subset with exactly two straight open-border edges plus one branch edge. The existing true-two-edge classification and manual remove workflow remain unchanged.
- Updated the existing audit harness to project 0.823/backend 0.68, verify border-T detection on the hidden-branch fixture, and verify exact duplicate selection/collapse on both Editable Poly and Edit Poly.

## 2026-10-01 — project 0.822

- `Two-Edge-Verts-FN.ms` 0.67 restores the proven native Remove Vertex path for manual RMB cleanup: Editable Poly uses `EditablePoly.Remove selLevel:#Vertex`, Edit Poly uses `ButtonOp #RemoveVertex`, and the armed source is revalidated as a current true two-edge vertex immediately before removal. The existing closest-visible-neighbor target weld remains only as a fallback when native Remove leaves the vertex count unchanged. Queue consumption still occurs only after exactly one vertex is confirmed removed.
- `Two-Edge-Verts-Audit-Test.ms` now requires backend 0.67 / project 0.822 and keeps the post-removal topology checks while referring to the surviving neighbor rather than assuming the primary operation is a weld. `design.md` now records native Remove Vertex as the primary manual cleanup path. Added backend snapshot `Two-Edge-Verts-FN_0.67.ms`.

## 2026-10-01 — project 0.821

- `Two-Edge-Verts-FN.ms` 0.66 separates the three vertex classifications. True 2-edge detection still requires exactly two actually visible incident edges, but now rejects any vertex owned by the topology T-junction classifier or the border-corner classifier. A topology T-junction remains a T-junction even when its branch edge is hidden, so hidden branches cannot leak into `SEARCH 2-EDGE VERTS`. Border corners are detected independently from two border/open edges that are not straight-through under the existing straight-pair rule; no new geometry tolerance is introduced. Added dedicated `getBorderCornerVerts()` and `selectBorderCornerVerts()` backend APIs while preserving the existing T-junction APIs and manual removal behavior.
- `Two-Edge-Verts-Audit-Test.ms` now builds separate true-two-edge and hidden-branch T-junction fixtures and verifies that true 2-edge, T-junction, and border-corner sets are mutually exclusive on Editable Poly and Edit Poly.
- `design.md` now defines the three classifications as mutually exclusive and makes `SEARCH 2-EDGE VERTS` responsible only for the true 2-edge class. Added versioned backend snapshot `Two-Edge-Verts-FN_0.66.ms`.

## 2026-10-01 — project 0.820

- `Two-Edge-Verts-FN.ms` 0.65: removed the remaining fragile `copy` return-value usage from manual candidate-queue updates, verifies queue writes by ordered values, and uses explicit Boolean weld-operation state instead of native/`try` return values.
- `Two-Edge-Verts-Audit-Test.ms`: now requires backend 0.65 / project 0.820 so runtime verification covers the corrected queue-consumption and Edit Poly success-reporting paths.

## 2026-10-01 — audit harness, project 0.819

- Audit hardening: added aggregate PASS/FAIL/EXCEPTION counters, phase-level exception reporting, explicit end-of-file stage execution, and post-removal assertions that surviving neighbors remain edge-connected and the weld target stays at its original position for both Editable Poly and Edit Poly.

## 2026-09-30 — project 0.819

- `Two-Edge-Verts-FN.ms` 0.64: fixed the public candidate-state API so `storeCandidateIds()` and `getStoredCandidateIds()` return real Arrays in 3ds Max instead of the `OK` value produced by `copy` as a standalone final expression.
- `Two-Edge-Verts-Audit-Test.ms`: now targets backend 0.64 / project 0.819, verifies both candidate-array return contracts explicitly, and type-guards array/BitArray checks so API regressions report `FAIL` instead of crashing the audit.
- Audit correction: stored candidate Array readback is compared by count and ordered element values instead of MAXScript Array `==`, preventing false failures when separate Arrays contain identical IDs.

## 2026-09-30 — project 0.818

- `Two-Edge-Verts-FN.ms` 0.63: removed the legacy bulk RMB/remap path and border-corner exclusion; Edit Poly detection now preserves live vertex identity and caches evaluated visible-edge endpoint pairs; protected `modifier` identifiers were renamed; manual removal remains closest-visible-neighbor only.
- `Two-Edge-Verts-UI.ms` 0.65: removed SEARCH RMB, border-corner checkbox, and debug clear control; SEARCH now requires one object; added F1 reload and immediate dialog message processing.
- `Two-Edge-Verts.ms` 0.05: added generic versioned-sibling reload resolution used by RESTART/F1.
- `design.md`: documented single-object candidate state, no border-corner exception, and live Edit Poly candidate identity.

Compatibility note: frontend self-registration with `EPolyToolsIntegration` is retained because the current manager/API registry still consumes that contract. Moving registration fully upward requires a coordinated EPolyManager change outside this Tool repository.
