# Vertex Welder — Design

## Purpose

`Vertex Welder` is a focused MaxScript utility for repairing close or unwelded vertex topology on Editable Poly and Edit Poly geometry.

The first release provides one explicit weld threshold in millimeters and three weld modes:

1. **WELD** — normal threshold weld. The tool repeatedly finds the closest weldable border-vertex pair inside the threshold and welds it to the midpoint.
2. **PER ELEMENT** — same threshold weld, but a pair is eligible only when both vertices belong to the same connected element. Separate elements are never joined by this mode.
3. **BORDERS** — stitches corresponding open borders from two different elements. Pairing begins from the best compatible border-edge pair, then advances synchronously along both border chains instead of repeatedly doing an unrestricted nearest-neighbour search.

The tool supports both an `Editable_Poly` base object and an `Edit_Poly` modifier.

## Package

The current package contains:

- `Vertex-Welder_0.005.ms` — current production backend plus managed persistent UI.
- `Vertex-Welder-Test_0.005.ms` — current executable regression/test scene script.
- `design.md` — feature and algorithm contract.
- `changes.md` — concise project change history.

This is a single-rollout tool, so the production file keeps the UI and backend in one script while still keeping geometry work inside the `VertexWelder_v` backend struct. Rollout callbacks remain thin.

## Version

Current production file version: `0.005`.

Current shared project version: `0.005`.

The dialog title displays the current global project version.

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

A successful weld changes topology, so all previously collected vertex, edge, face, adjacency, border, and element IDs are considered invalid after the operation. The next analysis starts again from a fresh topology synchronization boundary.

The tool never collapses the base Editable Poly underneath an Edit Poly modifier as an automatic cleanup step.

## Shared weld execution rule

Every weld is verified by the live vertex count. The native return value from `polyop.weldVerts` is not a Boolean success contract and must not be used in an `if` test.

A successful pair weld must reduce the current vertex count by exactly one.

If an attempted pair does not remove one vertex, it is not counted as success.

For deterministic index handling, pair execution always uses the higher current vertex ID as the source and the lower current vertex ID as the surviving destination ID.

### Editable Poly pair weld

Editable Poly uses:

`polyop.weldVerts poly source_id target_id weld_position node:node`

The weld position is supplied in world coordinates through the node-aware call.

Only border vertices are weldable through this API, so normal and per-element candidate discovery is restricted to current open-border vertices.

### Edit Poly pair weld

Edit Poly uses its verified target-weld pattern:

1. read the two original vertex positions;
2. move the lower-ID destination vertex to the requested weld point with `MoveSelection`, then `Commit`;
3. move the higher-ID source vertex to that same weld point with `MoveSelection`, then `Commit`;
4. explicitly leave only the source vertex selected;
5. call `WeldVertices source_id target_id node:node` while the source remains the active vertex selection;
6. `Commit` and verify the vertex-count drop.

The source-last ordering follows the working shared Edit Poly target-weld reference and prevents the final pre-weld selection from pointing at the destination instead of the source.

If the weld does not change topology, both moved vertices are restored to their recorded original positions before the pair is treated as failed. If the live vertex count changes to any unexpected value, the operation is treated as an incomplete destructive failure rather than a harmless rejected pair.

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

Connected elements are calculated from the current live vertex/edge graph.

Because the element map is rebuilt after every successful weld, stale element IDs are never carried across a topology change.

This mode is intended for cleaning duplicated/near vertices inside individual elements without accidentally sewing neighbouring elements together.

## Mode 3 — BORDERS

`BORDERS` is specifically for stitching two different elements along close open-border chains.

It must not do unrestricted nearest-neighbour welding after each vertex.

### Border seed

The tool examines pairs of current open border edges from different connected elements.

For two candidate edges it compares both endpoint orientations:

- A1 ↔ B1 and A2 ↔ B2;
- A1 ↔ B2 and A2 ↔ B1.

The orientation with the smaller maximum endpoint distance is preferred.

A seed is valid only when both paired endpoint distances are inside the user threshold.

Among valid seeds, the smallest maximum endpoint distance wins.

### Sequential border walk

Once the seed fixes the correspondence and orientation, both borders are walked synchronously.

From each current vertex, the next border step must be unambiguous: exactly one unused open border edge may continue the chain after the edge we came from.

If either side branches, ends, loops back into an already-used vertex, or the next paired vertices exceed the threshold, that direction stops.

The seed is extended in both directions so the complete locally compatible border run is collected.

This sequential pairing is the main protection against cross-pairing parallel nearby loops or welding back into the same element.

### Different-element rule

A border seed is considered only when its two edges belong to different connected elements.

After one stitched chain is welded, topology and element membership are rebuilt before another border seed is searched.

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

## UI

The standalone dialog follows the shared MaxScript UI framework and 12 px layout grid.

The native dialog title displays the current global project version. The dialog body contains:

- a top `.NET` **tool title button** labeled only `Vertex Welder`;
- `Threshold` spinner, interpreted as millimeters, default `0.1`;
- three mode radio buttons: `WELD`, `PER ELEMENT`, `BORDERS`;
- one large `WELD` action button;
- one `TEST` button;
- one status line.

The tool title button uses the canonical shared `ToolTitleButton.ms` style: RGB `45,45,48` background for normal/hover/pressed states, RGB `62,158,255` text, no border, and 24 px height.

LMB on the tool title button restarts the tool through the shared `ScriptReload.ms` helper. F1 uses the same restart path. Restart first loads the newest matching `Vertex-Welder_*.ms` version in the current script directory and otherwise reloads the current script. There is no duplicate bottom restart button.

The dialog uses the shared `DialogHost.ms` helper with a locked 336 px width, minimum/default 240 px height, vertical resizing, immediate post-create message processing, persisted position, and persisted height.

User-facing state is stored in `Vertex-Welder.ini` under the user scripts directory. The threshold and selected weld mode are saved when changed and again when the dialog closes. Missing or invalid stored values fall back to `0.1 mm` and `WELD`.

The production UI loads the canonical shared `IniSettings.ms`, `DialogHost.ms`, `ScriptReload.ms`, and `ToolTitleButton.ms` helpers from the shared `UI\Default` framework directory resolved from the standard Modules repository layout.

### WELD button

LMB runs the selected mode on exactly one selected supported node.

The whole operation is one undo entry.

The Listener prints one summary line containing mode, threshold, vertex count before/after, successful weld count, and final status.

### TEST button

LMB creates a fresh test fixture for the currently selected mode and stores that node as the tool's current test object.

RMB runs the currently selected weld mode on that stored test object using the current threshold.

The two callbacks deliberately separate source creation from execution so the user can inspect the source topology before welding and the result afterward.

RMB prints detailed test diagnostics to the Listener.

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

## Regression test script

`Vertex-Welder-Test_0.005.ms` is the current executable test file.

It contains numbered functions and an explicit execution queue at the bottom.

It tests all three modes on:

- Editable Poly;
- Edit Poly.

It also validates the managed dialog, native version title, canonical tool title button appearance, restored control ranges, and availability of the shared UI helpers.

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
