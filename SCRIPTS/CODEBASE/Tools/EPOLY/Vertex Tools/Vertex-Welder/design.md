# Vertex Welder — Design

## Purpose

`Vertex Welder` is a focused MaxScript utility for repairing close or unwelded vertex topology on Editable Poly and Edit Poly geometry.

The tool provides one explicit weld threshold in millimeters and four weld modes:

1. **WELD** — normal threshold weld. The tool repeatedly finds the closest weldable border-vertex pair inside the threshold and welds it to the midpoint.
2. **PER ELEMENT** — same threshold weld, but a pair is eligible only when both vertices belong to the same connected element. Separate elements are never joined by this mode.
3. **BORDERS** — stitches corresponding open borders from two different elements. Pairing begins from the best compatible border-edge pair, then advances synchronously along both border chains instead of repeatedly doing an unrestricted nearest-neighbour search.
4. **PER ELEMENT BORDER** — stitches close matching open-border chains that already belong to the same current element, mainly as a post-fix after a partial border weld has connected the source regions.

The tool supports both an `Editable_Poly` base object and an `Edit_Poly` modifier.

## Package

The current package follows the canonical Codebase Tool layout:

- `Vertex-Welder.ms` — unversioned main entry and the only file that auto-executes the Tool;
- `Vertex-Welder-FN.ms` — backend-only welding, topology, fixture, and Tool coordination module;
- `Vertex-Welder-UI.ms` — frontend-only rollout and managed-dialog module;
- `test/Vertex-Welder-Test_0.017.ms` — current executable regression script;
- `_Versions/` — versioned historical source/test snapshots;
- `design.md` — feature and algorithm contract;
- `changes.md` — concise project change history.

The main entry loads shared UI dependencies, then backend FN, then frontend UI, and finally opens the Tool. The FN and UI files remain independently loadable and never auto-open the Tool. Geometry work remains inside the `VertexWelder_v` backend struct and rollout callbacks remain thin.

## Version

Current main file version: `0.016`; current UI file version: `0.011`.

Current backend FN file version: `0.015`.

Current shared project version: `0.017`.

The dialog title displays the current global project version. Current source filenames stay unversioned in the Tool root; historical release files are kept under `_Versions/`.

## Threshold contract

The UI threshold is entered in **millimeters**.

The default is `0.1 mm`.

The backend converts that explicit user value to current 3ds Max system units with `units.decodeValue "1mm"`.

There is no second hidden positional tolerance, no rounding, no snapping, and no private epsilon used to decide whether vertices are close enough to weld.

A pair is inside the weld limit when its world-space distance is less than or equal to the converted user threshold.

## Target topology

The tool resolves exactly one selected object.

Target priority is:

1. the currently active `Edit_Poly` modifier when it belongs to the selected node;
2. otherwise the highest `Edit_Poly` modifier on the selected node;
3. otherwise the selected node's `Editable_Poly` base object.

Every Editable Poly used by the tool has `showCage = off`.

Every Edit Poly used by the tool has `showCage = off`, `useStackSelection = false`, and `selectMode = 0` when the tool needs to manipulate its vertex selection.

Raw topology IDs are never transferred between Editable Poly, Edit Poly, and TriMesh representations.

## Editable Poly dead-topology synchronization

Before an index-sensitive Editable Poly analysis phase, the tool checks `polyop.getHasDeadStructs`.

If dead structures exist, it runs `polyop.collapseDeadStructs` before collecting any topology IDs for that phase.

A successful weld marks topology dirty. For an independent weld operation, cached IDs are discarded before the next analysis stage. `polyop.weldVerts` may compact the Editable Poly vertex list immediately as part of the native weld itself, so a deleted endpoint must never be queried afterward as though it remained in a dead slot.

`polyop.collapseDeadStructs` is never inserted explicitly between individual welds of one BORDERS run. The border run instead controls native reindexing: each pair keeps the lower endpoint as the survivor, deletes the higher endpoint, and executes disposable higher IDs in descending order. Removing a higher index cannot renumber any lower endpoint still needed by a later pair. After the run, the backend performs one dead-topology synchronization check and discards every pre-run topology ID before another analysis begins.

The tool never collapses the base Editable Poly underneath an Edit Poly modifier as an automatic cleanup step.

## Shared weld execution rule

Every destructive weld path is verified from live topology. The native return value from `polyop.weldVerts` is not used as the success contract.

Independent Editable Poly pair welds verify an exact one-vertex count reduction after their topology boundary is synchronized. Inside one Editable Poly BORDERS run, each planned weld verifies an immediate one-vertex count reduction and verifies that the lower-ID survivor remains at the requested target. The implementation never queries the removed higher endpoint after the weld, because the native weld may already have compacted that index out of range.

If those verification contracts fail, the destructive operation is reported as incomplete rather than success.

For deterministic index handling, pair execution treats the higher current vertex ID as disposable source and the lower current vertex ID as survivor. Editable Poly passes the survivor first and the disposable source second to `polyop.weldVerts`; Edit Poly likewise calls `WeldVertices target_id source_id`.

### Editable Poly pair weld

Editable Poly uses:

`polyop.weldVerts poly target_id source_id weld_position node:node`

The weld position is supplied in world coordinates through the node-aware call.

Only border vertices are weldable through this API, so normal and per-element candidate discovery is restricted to current open-border vertices.

### Edit Poly pair weld

Edit Poly follows the shared working target-weld sequence while keeping the requested weld point explicit:

1. read the original source and destination positions;
2. keep the lower-ID destination fixed and move only the higher-ID disposable source onto that destination with `MoveSelection`, then `Commit`;
3. verify that the source move did not change topology;
4. call `WeldVertices target_id source_id node:node`; the first argument survives and the second argument is killed;
5. `Commit`, rebind the modifier context, and verify exactly one removed vertex;
6. move the surviving lower-ID destination vertex to the requested midpoint or border-plane target;
7. verify that the post-weld target move does not change topology.

This order deliberately avoids moving both vertices before the native weld. It mirrors the shared proven Edit Poly workflow: the disposable source is first collapsed onto the survivor, the pair is welded, and only the known surviving vertex is moved afterward to the requested result position.

If the weld does not change topology, the moved source is restored to its original position before the pair is treated as failed. If the live vertex count changes to any unexpected value, or if the surviving vertex cannot be moved to the requested result after a successful weld, the operation is treated as an incomplete destructive failure rather than success.

### Edit Poly coordinate contract

The translated-node regression establishes the coordinate rule used by this project:

- Editable Poly vertices are read in local object space and transformed once by `node.objectTransform`;
- node-scoped `EditPolyMod.GetVertex ... node:node` values are consumed directly by the welding backend in the coordinate path used by `MoveSelection`;
- the Edit Poly value must not be multiplied by `node.objectTransform` a second time.

The regression does not require exact Point3 equality between two independently evaluated coordinate paths. Instead, without introducing any tolerance, it requires the Edit Poly read to be closer to the single-transform reference than to either the untransformed local point or a deliberately double-transformed point. This catches both missing-transform and double-transform errors without hidden rounding or epsilon behavior.

## Mode 1 — WELD

`WELD` is a normal proximity weld over current open-border vertices.

Algorithm:

1. synchronize/read the current topology;
2. collect current open-border vertices;
3. find the closest eligible pair whose world-space distance is within the threshold;
4. use the midpoint of the two current world positions as the weld point;
5. weld and verify exactly one removed vertex;
6. discard all topology IDs and repeat on the new topology;
7. stop when no eligible pair remains.

Pairs that are inside the distance limit but are rejected by the native weld operation are blocked for the current unchanged topology so the tool does not retry the same failed pair forever.

After any successful weld, the blocked-pair list is cleared because topology has changed.

## Mode 2 — PER ELEMENT

`PER ELEMENT` uses the same closest-pair and midpoint rule as `WELD`, with one additional invariant:

> both candidate vertices must belong to the same connected element before the weld.

Connected elements follow Editable Poly polygon-element semantics: faces belong to the same element only when they are connected through shared topology edges. Two face regions that touch only at one vertex remain separate elements.

For `PER ELEMENT`, each current vertex stores every face-element membership that touches it. A point-junction vertex may therefore belong to more than one element without merging those elements; two candidate vertices are eligible only when their membership sets share at least one element ID.

Because the face-element map and vertex memberships are rebuilt after every successful weld, stale element IDs are never carried across a topology change.

This mode is intended for cleaning duplicated/near vertices inside individual elements without accidentally sewing neighbouring elements together.

## Mode 3 — BORDERS

`BORDERS` is specifically for stitching two different elements along close open-border chains.

It must not do unrestricted nearest-neighbour welding after each vertex.

### Border seed

The tool examines pairs of current open border edges from different face-connected polygon elements.

For two candidate edges it compares both endpoint orientations:

- A1 ↔ B1 and A2 ↔ B2;
- A1 ↔ B2 and A2 ↔ B1.

The orientation with the smaller maximum endpoint distance is preferred.

A seed is valid only when both paired endpoint distances are inside the user threshold.

Among valid seeds, the smallest maximum endpoint distance wins.

### Sequential border walk

Once the seed fixes the correspondence and orientation, both borders are walked synchronously.

From each current vertex, the next border step must be unambiguous: exactly one unused open border edge may continue the chain after the edge we came from.

If either side branches, ends, loops back into an already-used vertex, the two walks reach the same existing vertex ID, or the next paired vertices exceed the threshold, that direction stops.

Each synchronous continuation must also travel in the same spatial direction on both border loops. The backend compares the exact dot-product sign of the two current-to-next step vectors and continues only when it is positive. A zero or negative dot product stops that walk direction. This prevents a valid shared seam from turning around a closed outer border when the two loop continuations leave the seam endpoint in opposite directions, even when those next outer vertices are still inside the weld threshold. This is an orientation rule, not a private numeric tolerance.

The seed is extended in both directions so the complete locally compatible border run is collected.

This sequential pairing is the main protection against cross-pairing parallel nearby loops or welding back into the same element.

### Original source-group rule

At the start of one BORDERS operation, the tool computes face-connected polygon elements from shared-edge adjacency, captures that element identity for every face, and keeps the resulting face-group map unchanged until the operation ends.

A border seed is eligible only when its two open edges belong to different original source face groups. Point-only contact does not merge source groups: two pieces may already share a seam endpoint vertex while the surrounding faces remain separate polygon elements.

This deliberately does not rely on current connected-element membership after every seam run: the first partial stitch may join two live elements while another disconnected seam between those same original pieces is still unwelded.

Border walking also stays on the original source face group of each side. Every current open edge uses its adjacent face ID to recover the preserved source group, preventing a walk from crossing the newly stitched connection into the opposite side.

The face count must remain unchanged while the preserved map is active. If a weld unexpectedly changes face topology, BORDERS fails rather than applying stale face-group IDs.

After one stitched run, current vertex/edge topology is synchronized and the next seed is searched with the same preserved original face groups. This allows multiple disconnected seam runs between one original element pair.

When both synchronous walks arrive at the same existing vertex ID, that point is already stitched and is a hard end of the weld run. It is not added as a `vertex_id <-> same vertex_id` weld pair. A seed that contains one already-shared endpoint may still produce the remaining real weld pairs; a one-pair run is valid.

For Editable Poly border runs, the complete compatible pair sequence is planned from one clean topology state. The runtime contract established by the regression is that `polyop.weldVerts` can compact the vertex list immediately, even though the tool itself never calls `collapseDeadStructs` between planned pairs. The backend therefore does not attempt to inspect a removed endpoint with `polyop.isVertDead` after a weld.

Instead, every pair is normalized to `target_id = lower endpoint` and `source_id = higher endpoint`, and pairs execute by descending `source_id`. Editable Poly calls `polyop.weldVerts poly target_id source_id target_world`: the verified first endpoint survives at the target and the higher second endpoint is removed. Because each removed source is higher than every endpoint needed by later pairs, native compaction leaves those later lower IDs numerically stable. Each pair must reduce the live vertex count by exactly one and leave the surviving target ID at the requested position. One final dead-topology synchronization check runs after the sequence, then all pre-run topology IDs are discarded before another border seed or element analysis. No world-position re-resolution, hidden tolerance, rounding, or epsilon is used between planned welds. A completed two-quad seam must remove both duplicate seam vertices and the duplicate seam edge; the canonical four-triangle fixture ends with six vertices and nine polygon edges. Its face normals must retain the fixture's positive orientation; a weld may not reverse one side of the seam.

## Border weld position — adjacent face-plane intersection

Simple midpoint collapse can progressively bend two originally planar faces. `BORDERS` therefore computes a geometry-preserving target for each paired border vertex.

For each side:

1. take the seed/walk border edge associated with that vertex;
2. resolve its single adjacent face;
3. calculate that face plane in world space from the face's ordered polygon vertices.

For the two adjacent face planes:

- if the planes have a unique intersection line, project the pair midpoint onto that line and use that point as the weld target;
- if the planes are exactly parallel, no unique intersection line exists, so use the pair midpoint as the explicit fallback.

The final target must still be within the user's weld threshold from both source vertices. If it is not, the border walk stops at that pair.

No hidden angle or plane tolerance is introduced.

## Mode 4 — PER ELEMENT BORDER

`PER ELEMENT BORDER` is a sequential border cleanup mode for close twin border chains that already belong to the same current face-connected polygon element.

Its main use is recovery after a partial border stitch: once an earlier weld has created at least one shared topology edge, both source regions can become one current element and a fresh `BORDERS` run no longer has a different-element seed. `PER ELEMENT BORDER` deliberately searches the opposite relation.

Algorithm:

1. synchronize/read the current topology;
2. build the current face-connected element map;
3. search open border-edge pairs whose adjacent faces belong to the same current element;
4. choose the best seed with the same endpoint-orientation and threshold scoring used by `BORDERS`;
5. build the full compatible pair run with the same unambiguous synchronous border walk, exact continuation-orientation gate, shared-endpoint stop rule, and face-plane weld targets;
6. weld the complete run through the same verified compound weld executor;
7. discard stale topology IDs, rebuild the current element map, and search again;
8. stop when no compatible same-element border seed remains.

Unlike `PER ELEMENT`, this mode does not perform unrestricted closest-pair welding. It keeps the sequential border-chain correspondence used by `BORDERS`, so it is intended for twin seam cleanup rather than arbitrary close vertices inside an element.

Face count must remain unchanged during the cleanup. Any unexpected face-count change is treated as an incomplete destructive failure.

## UI

The standalone dialog follows the shared MaxScript UI framework and 12 px layout grid.

The native dialog title displays the current global project version. The dialog body contains:

- a top `.NET` **tool title button** labeled only `Vertex Welder`;
- `Threshold` spinner, interpreted as millimeters, default `0.1`;
- four native action buttons: `WELD`, `PER ELEMENT`, `BORDERS`, `PER ELEMENT BORDER`;
- one status line.

The tool title button uses the canonical shared `ToolTitleButton.ms` style: RGB `45,45,48` background for normal/hover/pressed states, RGB `62,158,255` text, no border, and 16 px height.

LMB on the tool title button restarts the tool through the shared `ScriptReload.ms` helper. F1 uses the same restart path. Because current Tool source files are unversioned in the package root and release history lives under `_Versions/`, normal restart reloads the canonical `Vertex-Welder.ms` main entry. There is no duplicate bottom restart button.

The dialog uses the shared `DialogHost.ms` helper with a locked 336 px width, minimum/default 240 px height, vertical resizing, immediate post-create message processing, persisted position, and persisted height.

The dialog is registered under the stable `Vertex-Welder` DialogHost tool key. Main-entry reload cleanup first asks `DialogHost` to destroy any registered instance, then performs one harmless fallback `destroyDialog` cleanup for pre-registry/stale rollout instances. Close-callback errors from that stale fallback must not block package reload; the newly created managed dialog becomes the single registered instance.

User-facing state is stored in one stable `Vertex-Welder.ini` beside the canonical `Vertex-Welder.ms` main script. Only the threshold is persisted; weld modes are direct actions and have no selected-mode state. Missing or invalid threshold values fall back to `0.1 mm`.

The four weld controls are normal native `button` controls. Pressing one runs that exact backend mode immediately; there is no separate shared action button and no checkbutton/radio selection state.

The main entry resolves the MaxScript root from the canonical `\Codebase\` path segment and loads `IniSettings.ms`, `DialogHost.ms`, `ScriptReload.ms`, and `ToolTitleButton.ms` from the shared sibling `UI\Default\` framework directory before the frontend is loaded. It does not search for or depend on a parent Toolset/manager.

### Weld action buttons

Each of the four weld buttons runs its named mode on exactly one selected supported node using the current threshold.

Each whole operation is one undo entry.

The Listener prints one summary line containing mode, threshold, vertex count before/after, successful weld count, and final status.


## Test fixtures

All fixture dimensions are expressed in real millimeters with `units.decodeValue`.

### WELD fixture

Two disconnected coplanar quads contain one close two-vertex seam inside the threshold.

Expected result with the default threshold: two successful welds and one joined element.

### PER ELEMENT fixture

One connected U-shaped element contains a narrow slit whose two mouth vertices are inside the threshold while the slit widens beyond the threshold toward its connected far end. A second element is positioned close enough to tempt a cross-element weld.

Expected result: the two close slit-mouth vertices inside the first element weld, while the separate element remains separate.

### BORDERS fixture

Two disconnected rectangular faces form a shallow V with close corresponding open seam edges.

Their adjacent face planes intersect between the two source border edges.

Expected result: both seam vertex pairs weld to the plane-intersection line, joining the elements without a midpoint-only progressive bend.

### BORDERS loop-turn regression fixture

Two disconnected segmented planar strips expose closed open-border loops. Seven corresponding seam vertices are close enough to weld, while the first outer-loop vertices beyond both seam endpoints are also deliberately kept inside the same weld threshold.

At each seam end, however, the two loop continuations travel in opposite spatial directions. The border walker must therefore stop by the continuation-orientation rule and weld only the seven seam pairs. The four outer-loop corner vertices must remain untouched.

### BORDERS shared-endpoint regression fixture

Two planar face strips share the same lower and upper seam endpoint vertices but do not share any edge before welding. Their five interior seam vertices are duplicated and remain inside the weld threshold.

The source must report two polygon elements despite the point-only endpoint contacts. BORDERS must plan and weld exactly the five duplicated interior pairs, never create a self-weld for either shared endpoint, preserve those endpoint vertices, and finish as one face-connected element.

### BORDERS two-run regression fixture

Two original source elements expose two separated three-pair seams. Welding the first seam makes the live topology one element, but the second seam must remain eligible from the immutable original face-group map. All six pairs must weld.

### PER ELEMENT BORDER post-fix regression fixture

Two face regions begin as different polygon elements while sharing the two seam endpoint vertices. One controlled interior seam pair is welded first, creating a shared topology edge and turning the source regions into one current face-connected element while four interior twin pairs remain unwelded.

A fresh `BORDERS` run must find zero eligible different-element pairs from that post-fix state. `PER ELEMENT BORDER` must then weld exactly the four remaining twin pairs while preserving one element and unchanged face count. The same regression runs on Editable Poly and Edit Poly.

## Regression test script

`test/Vertex-Welder-Test_0.017.ms` is the current executable test file.

It contains numbered functions and an explicit execution queue at the bottom.

It tests all four modes on:

- Editable Poly;
- Edit Poly.

It also validates a shared-endpoint Editable Poly BORDERS fixture where two face regions touch only at seam endpoint vertices, plus a two-run fixture where the first seam joins the live elements and the second seam must still weld from the preserved original source groups; the translated Edit Poly world-position contract, the canonical three-file Tool package, Codebase-to-`UI\Default` framework resolution, the INI path beside the main entry, project/file version consistency, a live main-entry reload while a dialog already exists, single-instance DialogHost registration, the managed dialog, native version title, canonical tool title button appearance, restored threshold range, four direct weld action buttons, and availability of the shared UI helpers.

Each scene-changing stage has a named undo entry, the final tested objects remain in the scene, and the script prints the undo order at completion.

The test uses the production backend and does not duplicate its geometry algorithm.

## Failure behavior

The backend stores a human-readable `last_message` separately from numeric return values.

Public weld-mode functions return an Integer:

- `0+` = number of verified successful pair welds;
- `-1` = invalid target or a real/incomplete operation failure.

A failed destructive operation is never reported as success.

The UI reports real failures visibly and leaves Listener diagnostics available for debugging.

## Initial non-goals

The first release does not attempt to:

- bridge borders with different vertex counts by creating new topology;
- resample borders;
- solve ambiguous branched border networks automatically;
- infer a threshold beyond the explicit UI value;
- weld arbitrary non-border Editable Poly vertices, because the native `polyop.weldVerts` contract only welds border vertices;
- silently collapse the base object under an active Edit Poly modifier.
