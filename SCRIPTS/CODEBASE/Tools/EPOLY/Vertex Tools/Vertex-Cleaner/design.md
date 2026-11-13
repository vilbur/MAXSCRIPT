# Vertex Cleaner — Design

## Purpose

`Vertex Cleaner` is a Vertex Tools utility for finding and cleaning redundant or diagnostic vertex topology on Editable Poly and Edit Poly. The canonical repository folder and package filenames use `Vertex-Cleaner`; the existing `TwoEdgeVerts` globals and `two-edge-verts` integration key are retained for EPolyTools compatibility.

The tool keeps the audited manual true-two-edge workflow and adds exact-position duplicate selection/collapse plus dedicated T-junction, border-T-junction, and split inner/outer border-corner selection.

## Package

The current Tool package contains three production scripts in this folder:

- `Vertex-Cleaner.ms` — main executable entry.
- `Vertex-Cleaner-FN.ms` — backend only.
- `Vertex-Cleaner-UI.ms` — frontend only.

`Vertex-Cleaner.ms` is the only file intended to auto-run the Tool. It loads the backend, loads the frontend, and opens the standalone UI when appropriate.

`Vertex-Cleaner-FN.ms` must remain usable without opening any dialog.

`Vertex-Cleaner-UI.ms` owns rollout controls and callbacks only. Geometry processing belongs in the backend.

The main entry resolves `Vertex-Cleaner-FN.ms` and `Vertex-Cleaner-UI.ms` as the canonical siblings and may accept the older `Two-Edge-Verts-FN.ms` / `Two-Edge-Verts-UI.ms` names only as a transition fallback for partially synchronized folders. Canonical names always have priority. Standalone startup failures must be visible through a startup error dialog instead of returning a silent false result.

`Vertex-Cleaner.ms` is part of every Tool change set. Vertex Cleaner uses one Tool version only: every modified package script with a version value, including the audit, must use a file version equal to its project version, and both must equal the current Tool project version. The standalone rollout title must display that same version. Versioned snapshots for one change set use that same version suffix; independent main/backend/UI version sequences are not allowed. This keeps file, title, snapshot, and project versions identical.

A successful standalone `Vertex-Cleaner.ms` run must finish with the `TwoEdgeVerts_UI` rollout open. Library and embedded modes remain headless by contract.

Do not create redundant standalone `*_Test.ms` files for normal revisions of this Tool.

## Supported topology

The Tool supports:

- Editable Poly base objects.
- Edit Poly modifiers.

Editable Poly uses `polyop` topology/selection methods.

Edit Poly uses the Edit Poly modifier API and its own stored selection.

For `2-EDGE VERTS \ FIX`, target resolution is top-of-stack aware. An object with no modifiers and an Editable Poly base keeps the base-object path. When the modifier stack is non-empty, SEARCH must operate on the evaluated stack top: reuse the exact top modifier when it is `Edit_Poly`; otherwise add one new tool-owned `Edit_Poly` at visual stack index 1 and operate there. Never adopt a lower Edit Poly for this SEARCH path because lower topology does not represent the evaluated stack top. Existing modifiers below the inserted Edit Poly must remain untouched and in the same relative order.

Do not transfer raw edge IDs between Editable Poly, Edit Poly, and evaluated TriMesh representations.

## Editable Poly dead-topology synchronization

Every index-sensitive `Editable_Poly` phase begins at one controlled synchronization boundary. `ensureCleanEditablePolyTopology()` checks `polyop.getHasDeadStructs`; when no dead structures exist it leaves topology untouched, and when dead structures exist it invalidates persistent component-ID state before any further ID-dependent work.

If dead structures exist and there is no `Edit_Poly` modifier above the base, the boundary calls `polyop.collapseDeadStructs`, verifies that dead structures are gone, and returns `#collapsed`. A collapse invalidates all pre-collapse vertex, edge, and face IDs, topology BitArrays, adjacency data, and endpoint mappings. Callers that entered the boundary with an explicit component ID or BitArray must abort or rebuild from the current topology when `#collapsed` is returned.

If an `Edit_Poly` modifier exists above the base, the boundary returns `#blocked` instead of collapsing the base. The Tool never reindexes an Editable Poly base underneath Edit Poly as an automatic cleanup step. Edit Poly workflows continue through the modifier API and do not call `polyop.collapseDeadStructs` on the base.

Low-level Editable Poly adjacency/endpoint helpers are phase-local: they assume the caller already synchronized the base and that no topology-changing operation occurs before the helper chain finishes. They do not independently collapse topology inside inner loops.

After every completed topology-changing operation, persistent component-ID state is invalidated unconditionally. Before the next Editable Poly phase that reads counts, selections, adjacency, or component IDs, the synchronization boundary runs again. Only non-ID data such as exact positions and scalar counts may be carried across that boundary; current IDs are reacquired afterward.

## Core two-edge definition

A valid true two-edge candidate is a vertex with exactly two actually visible incident edges according to the active topology, after excluding vertices owned by the T-junction and border-corner classifiers.

Invisible / hidden triangulation edges do not count as valid visible connections.

The visible-edge rule is a hard invariant for detection and removal.

The three base topology classifications remain mutually exclusive:

- **true two-edge vertex** — exactly two actually visible incident edges, not a T-junction, and not a border corner;
- **T-junction vertex** — exactly three live topology edges with at least one straight-through edge pair; this classification still owns the vertex when the third branch edge is hidden/invisible;
- **border-corner vertex** — not a T-junction, has exactly two border/open edges, and those two border edges are not a straight-through pair under the existing straight-pair rule. Border corners are further split into **inner** and **outer** subclasses by the oriented border turn relative to adjacent face winding: inner corners belong to hole/reflex borders; outer corners belong to the exterior perimeter.

The filtered true-two-edge classifier used by `SELECT \ REMOVE` and `REMOVE` must never accept a vertex classified as a T-junction or border corner. `2-EDGE VERTS \ FIX` uses FORCE semantics: LMB selects the FORCE set, while RMB repeats fresh FORCE reverse batches highest-ID-first until the set reaches zero or the next pass starts with the same candidate count. FORCE ignores the filtered class exclusions and uses only the visible two-edge count plus its explicit near-straight angle limit. Dedicated T-junction and inner/outer border-corner selectors remain available for those classes.

A **border T-junction** is a dedicated subset of the T-junction class: it has exactly two open border edges, those two border edges form the straight-through pair, and the third edge is the branch. The general T-junction selector includes border T-junctions; the dedicated border-T selector returns only that subset.

Exact-position duplicates are an orthogonal defect class. Two or more live vertices are duplicates only when their `Point3` positions compare exactly equal. No distance tolerance, quantization, string key, rounding, or weld threshold is used for this classification.

For Edit Poly detection, candidate identity always begins with the exact live modifier vertex ID. Evaluated TriMesh data may be used only to validate whether a live edge endpoint pair is visible; candidate IDs must never be recovered by nearest-position remapping.

True two-edge detection also carries an explicit success state. A successful search with zero candidates and a failed topology/snapshot read are different outcomes even though the compatibility candidate return remains a BitArray in both cases. `wasLastTwoEdgeDetectionSuccessful()` reports the state of the most recent true two-edge detector call. SEARCH, candidate storage, manual removal, and fixed-point batch cleanup must abort or report incomplete work when detection failed; they must never interpret detector failure as a clean zero-candidate result.

For Edit Poly selection/reselection immediately before a target weld, a failed `GetSelection #Vertex` read is an operation failure. It must not be normalized to an empty selection because the tool must know that only the intended source vertex is active before `MoveSelection` and `WeldVertices`.

## UI

The production rollout contains:

### `FIX SELECTED VERT`

LMB:

1. Require exactly one selected supported object and exactly one selected vertex on its active Editable Poly / Edit Poly topology.
2. Fix that selected source with an edge-preserving target weld to its closest actually visible neighbor. Native Remove Vertex is not used by this direct action.
3. The selected source disappears, the chosen target neighbor stays at its exact original position, and the source's opposite visible edge becomes the direct edge between the two surviving neighbors.
4. Revalidate the selected source as a live true-two-edge vertex before topology changes; non-candidates are not modified.
5. Do not require SEARCH or stored manual candidate state.
6. After a successful direct fix, clear component selection and reset stored manual candidate state because vertex IDs may have changed.

The control is intentionally taller and placed directly below the live vertex-count label so the direct action is easy to find.

### Vertex info

The top info line displays the active single supported target as `VERTS <all> - SEL <selected> \ UNSEL <unselected>`. Counts come from the same active Editable Poly or Edit Poly topology that receives Tool selections. The label refreshes when the rollout opens and on a lightweight UI timer so manual viewport vertex-selection changes are reflected. This path is strictly read-only: it must never call `collapseDeadStructs`, invalidate manual candidate state, change geometry, or change component selection. If an Editable Poly has dead structures, the info read returns no counts and the label shows placeholder dashes until an explicit operation owns topology synchronization.

### `2-EDGE VERTS \ FIX`

LMB — FORCE:

1. Require exactly one selected object.
2. Resolve the SEARCH target at the evaluated top of the stack: use an unmodified Editable Poly base directly, reuse a top `Edit_Poly`, or add one tool Edit Poly at visual stack index 1 when another modifier is currently on top.
3. Require exactly two actually visible incident edges on that resolved topology.
4. Require the two visible edge directions to deviate by no more than **15 degrees** from a straight 180-degree continuation.
5. Do not apply the filtered T-junction/border-corner class exclusions; the 15-degree geometry limit is the FORCE-mode filter.
6. Do not populate the manual remove queue from FORCE mode.

RMB — repeated FORCE reverse cleanup:

1. Require exactly one selected object.
2. Resolve the same top-of-stack SEARCH target used by LMB. If the current top is not Edit Poly and the object is not an unmodified Editable Poly base, add one tool Edit Poly at visual stack index 1 before detection.
3. Run a fresh FORCE detector pass at the start of each outer cleanup pass.
4. If the fresh pass returns zero candidates, cleanup is complete.
5. If the fresh pass returns the same candidate count as the previous outer pass started with, stop before running another batch so a non-converging topology cannot loop forever.
6. Otherwise capture that FORCE set, sort candidate IDs ascending, and process them backwards, highest vertex ID to lowest.
7. Inside each pass, preserve the stable project-0.847 highest-ID-first target-weld geometry and ordering: prepare the Edit Poly / Modify-panel context once, keep Edit Poly editing live for topology validation, suppress redraw for the loop, and use one batch undo record.
8. For each captured candidate, run only local live FORCE validation, then use the same edge-preserving target-weld operation as the stable `SELECT \ REMOVE` workflow.
9. If a captured candidate is no longer valid when reached, skip it and continue the reverse loop. The next outer pass performs a fresh FORCE search and can pick up surviving/reindexed candidates.
10. Do not re-run the full-object FORCE detector between individual removals and do not call per-candidate `RefreshScreen` / `completeRedraw`; refresh once per completed batch pass.

### `REMOVE`

LMB runs the fixed-point filtered cleanup that previously belonged to SEARCH RMB:

1. Search the complete live topology for the current filtered true-two-edge set.
2. Remove only one current valid source, then discard stale topology IDs.
3. Re-search the changed topology before choosing another source.
4. Repeat until a fresh filtered search returns zero candidates.
5. Stop and report a real operation failure rather than retrying the same source forever.
6. Clear stale manual state when cleanup finishes.

### `SELECT \ REMOVE`

LMB:

1. Require exactly one supported object.
2. Resolve its current Editable Poly / Edit Poly target.
3. Run a fresh filtered true-two-edge detector pass directly from this control; SEARCH RMB is not a prerequisite.
4. Rebuild the live manual candidate set from that pass.
5. Select only the highest current candidate and arm that exact vertex for RMB removal.
6. Do not alter topology.

RMB:

1. Use the exact candidate armed by LMB; if manual state was lost, one currently selected live filtered true-two-edge vertex may be adopted as the arm.
2. Re-select and revalidate that exact armed source ID against the live true-two-edge topology. Do not abort solely because another component selection is currently active or the source was deselected.
3. Target-weld that exact source into its closest actually visible neighbor.
4. Do not call native Remove Vertex; the source disappears while its opposite visible edge survives as the direct edge between the two surviving neighbors.
5. Treat the operation as successful only when exactly one vertex is removed.
6. Rebuild all manual candidate IDs from the changed live topology after success; no pre-change ID survives.
7. Clear the component selection.
8. Do not automatically select the next candidate.
9. Do not fall through to the separate `FIX SELECTED VERT` action.

The user explicitly advances to the next candidate with the next LMB.

### `SELECT DUPLICATE VERTS`

LMB selects every live vertex that belongs to an exact-position duplicate group. Exact `Point3` equality is required.

### `COLLAPSE DUPLICATE VERTS`

LMB collapses every exact-position duplicate group to one surviving vertex. The implementation welds one exact pair at a time, verifies a one-vertex count drop, reacquires current live IDs after every successful weld, and never introduces a distance threshold.

### `SELECT T-JUNCTION VERTS`

LMB selects all topology T-junctions with exactly three live edges and a straight-through pair.

### `SELECT BORDER T-JUNCTIONS`

LMB selects only the border-T subset whose two straight-through edges are open border edges.

### `SELECT INNER BORDER CORNERS`

LMB selects only the hole/reflex subset of non-T border corners, such as the four corners of an inner square opening.

### `SELECT OUTTER BORDER CORNERS`

LMB selects only the exterior-perimeter subset of non-T border corners, opposite to the inner-hole class.

The compatibility backend `getBorderCornerVerts()` / `selectBorderCornerVerts()` behavior remains the union of both classes so true-two-edge exclusion and external callers are unchanged.

### Tool title button / restart

A full-width `.NET System.Windows.Forms.Button` named `Vertex Cleaner` is fixed at the top of the standalone rollout. It uses the shared tool-title-button dark style and contains no version text. LMB restarts the complete canonical Tool through the existing main-entry reload path; there is no duplicate bottom `RESTART` button.

The standalone rollout is registered as a CUI dialog bar that may float or dock only on the left or right side of 3ds Max. Top and bottom docking are not allowed. The last floating dialog position is stored in `Vertex-Cleaner.ini` under the 3ds Max plugcfg directory and restored on the next standalone open. Docked movement never overwrites the remembered floating position. A registered dialog bar is unregistered before `destroyDialog`.

F1 performs the same Tool reload path. Before falling back to the canonical main script, the reload logic checks the main script directory for a newer matching versioned sibling.

## Candidate state

`SELECT \ REMOVE` LMB rebuilds its own fresh filtered candidate IDs from the current live object/topology target on every click and always chooses the highest current ID. SEARCH LMB/RMB use a separate top-of-stack target resolver: an unmodified Editable Poly base stays on the base path; otherwise the exact top Edit Poly is reused or one new tool Edit Poly is inserted at the visual top. SEARCH RMB then captures one fresh FORCE candidate set per outer pass and processes that frozen set from highest ID to lowest through the confirmed-stable 0.847 batch path. The next outer pass runs only when the fresh candidate count changed; an unchanged count stops the loop. FORCE LMB never populates manual state.

The manual workflow processes candidates from highest stored vertex ID toward lower IDs.

`SELECT \ REMOVE` LMB is selection-only while topology remains unchanged. If an Editable Poly dead-topology synchronization collapses/reindexes the mesh before LMB can use stored IDs, the stale queue is discarded and rebuilt from a fresh current detector pass before a new candidate can be armed.

`SELECT \ REMOVE` RMB never carries a pre-change candidate queue across a topology-changing operation. After a successful fix, all stored component IDs are rebuilt from a fresh current detector pass; the processed source ID and every other pre-change ID are discarded.

If a destructive operation fails after topology may have changed, persistent component-ID state remains invalidated rather than preserving a possibly stale queue.

## Removal topology rule

For stored/manual `SELECT \\ REMOVE` and SEARCH RMB cleanup, the removal path is **target weld only**. Native Remove Vertex is not used because it can delete the source edge path. The source is welded to its closest actually visible neighbor so the other source edge survives as the direct edge between the two surviving neighbors.

`FIX SELECTED VERT` is intentionally different: it uses a closest-visible-neighbor target weld as the primary and only direct-fix topology operation so the source's opposite edge path stays connected after the source disappears. The chosen target neighbor must remain at its exact original position.

The closest-visible-neighbor helper defines the required target for stored/manual removal, SEARCH RMB, `REMOVE` fixed-point cleanup, and `FIX SELECTED VERT`. A target must be connected to the source by an actually visible edge; hidden/invisible edges are never eligible.

## Editable Poly removal

For Editable Poly:

1. Resolve the source by its exact live vertex ID.
2. Revalidate it against the current true-two-edge detector.
3. Select only that source vertex.
4. Target-weld the source into its closest actually visible neighbor.
5. Verify that exactly one vertex disappeared.
6. Verify the surviving target stays at its exact original position and the opposite source edge remains as the direct edge to the other surviving neighbor.

The selected source is the vertex that must disappear; neighboring vertices remain in place.

## Edit Poly removal

For Edit Poly:

1. Resolve the source on the live Edit Poly modifier.
2. Revalidate it against the current true-two-edge detector.
3. Select only that live source vertex.
4. Move the source exactly onto its closest actually visible neighbor and weld the source to that target.
5. Refresh and verify that exactly one vertex disappeared.
6. Verify the surviving target stays at its exact original position and the opposite source edge remains as the direct edge to the other surviving neighbor.

The selected source is the vertex that must disappear; neighboring vertices remain in place.

## Backend API

The backend should expose reusable input/output functions so other scripts can use the feature without depending on the rollout.

Current public responsibilities include:

- detecting true two-edge vertices without T-junction or border-corner overlap;
- exposing whether the most recent true two-edge detection completed successfully so callers can distinguish valid zero candidates from detector failure;
- detecting T-junction vertices independently;
- detecting border-T-junction vertices as a dedicated T-junction subset;
- detecting the compatibility border-corner union independently;
- detecting inner-hole and exterior border-corner subsets independently from oriented face/border winding;
- detecting exact-position duplicate vertex groups with exact Point3 equality;
- selecting T-junction, border-T-junction, inner-border-corner, outer-border-corner, compatibility border-corner union, or duplicate-position classes through dedicated backend functions;
- collapsing exact-position duplicate groups without a tolerance;
- returning visible neighbor vertex IDs;
- returning the closest visible neighbor vertex ID;
- storing candidate IDs;
- returning stored candidate IDs;
- returning the next stored candidate ID;
- selecting a candidate by ID;
- fixing a candidate by ID.

Backend functions must not reference rollout controls or create dialogs.

## Frontend responsibilities

The frontend is intentionally thin.

It should:

- translate LMB/RMB callbacks into backend calls, including the prominent direct selected-vertex fix action;
- present the current Tool controls;
- display the current Vertex Cleaner project version in the rollout title, derived from `TwoEdgeVertsUI.project_version` so `file_version == title version == project_version`;
- register the rollout with EPolyTools when embedded;
- open/close the standalone dialog through explicit UI functions.

It must not duplicate geometry logic from the backend.

## Stability constraints

The following behavior is considered stable and must not be changed accidentally:

- exact source candidate identity within one synchronized topology phase;
- Editable Poly dead structures are validated before every index-sensitive phase, with `collapseDeadStructs` used only at controlled phase boundaries;
- no vertex/edge/face ID, topology BitArray, adjacency map, or endpoint mapping collected before an Editable Poly collapse may survive after that collapse;
- an Editable Poly base is never auto-collapsed underneath an `Edit_Poly` modifier;
- topology-changing operations invalidate persistent component-ID state before the next ID-dependent phase;
- manual candidate stepping;
- highest-ID-first stored candidate order;
- actual visible-edge filtering;
- FORCE SEARCH accepts only two-visible-edge vertices within 15 degrees of a straight continuation;
- `2-EDGE VERTS \ FIX` resolves the evaluated stack top: reuse a top `Edit_Poly`; otherwise add exactly one tool Edit Poly above existing modifiers, preserve all modifiers below it, and reuse that same top Edit Poly on later SEARCH calls;
- mutually exclusive true-two-edge / T-junction / border-corner base classification;
- inner and outer border-corner selectors remain disjoint subclasses whose union preserves the existing border-corner compatibility class;
- border-T-junction selection as an explicit subset of T-junctions;
- exact-position duplicate detection/collapse with no hidden tolerance;
- target-weld-only removal for stored/manual removal, SEARCH RMB, and `REMOVE` fixed-point cleanup; native Remove Vertex is not used because the two-neighbor edge path must survive;
- `FIX SELECTED VERT` uses closest-visible-neighbor target weld directly and must preserve one edge between the source's two surviving visible neighbors;
- `2-EDGE VERTS \ FIX` RMB repeats fresh FORCE reverse batches until zero candidates remain or the next outer pass starts with the same candidate count; every inner batch preserves the confirmed-stable 0.847 highest-ID-first target-weld behavior;
- each SEARCH RMB inner batch performs Modify-panel setup once, uses one undo record, suppresses redraw during the reverse loop, keeps Edit Poly editing live for topology validation, and refreshes the UI once after that pass;
- `REMOVE` fixed-point cleanup performs a fresh full-object true-two-edge search after every successful removal and stops only at zero live candidates or a real removal/detection failure;
- a detector failure is never treated as a valid zero-candidate result, and a failed Edit Poly selection read immediately before removal never authorizes a destructive operation;
- successful `REMOVE` fixed-point cleanup remains quiet in the Listener; only invalid input, real operation errors, or incomplete cleanup may report;
- no automatic next-candidate selection after RMB;
- Editable Poly and Edit Poly support;
- backend/frontend separation.

Any future change to those rules should update this `design.md` in the same change set.
