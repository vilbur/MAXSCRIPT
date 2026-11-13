# Geometry Diagnostics — Design


## Purpose


Geometry Diagnostics is a MaxScript Tool for visually inspecting mesh problems through vertex-color / paint overlays.


The user-facing topology model is:


- logical wall / surface regions;
- Editable Poly polygon faces;
- visible Editable Poly edges;
- Editable Poly vertices.


TriMesh triangles, invisible triangulation diagonals, and temporary evaluated mesh data are implementation details only. Triangle IDs must never be exposed through the public Tool interface.


## Architecture


Keep analysis and painting separate. Geometry Diagnostics now consumes a reusable Operation named `VertexColorPainter_v`; the Tool no longer owns the low-level paint implementation.


```text
Diagnostics
    -> produce vertex / edge / face / surface-region results
VertexColorPainter_v instance
    -> binds one node + one topology level
    -> caches topology / map correspondence
    -> writes direct channel 0 or PaintLayerMod data
3ds Max viewport
    -> displays the diagnostic overlay
```


The reusable painter must not contain diagnostic rules such as planarity, orthogonality, valence, duplicate-vertex detection, or wall classification. Future diagnostics call the same painter API.


## Vertex Color Painter authority


`Codebase/Operations/Vertex-Color-Painter/` is the source of truth for all reusable vertex-color painting behavior used by Geometry Diagnostics.


The Geometry Diagnostics helper is intentionally named `addGeometryDiagnosticsTestTessellateTarget` and mirrors the canonical `vertexColorPainterTestAddTessellateTarget` fixture rather than maintaining a separate Edit Poly tessellation recipe.


Geometry Diagnostics must consume the canonical `VertexColorPainter_v` / `VertexColorPainter` public API instead of maintaining its own competing implementation. PaintLayer ownership, supported stack-target classes, topology-domain rules, cache invalidation, direct channel-0 behavior, modifier placement, exact-corner painting, and `clearPaint()` semantics follow that Operation and its regression test.


The canonical `Vertex-Color-Painter-Test.ms` Tessellate fixture is also the reference fixture for Geometry Diagnostics modifier-paint regression: a clean Editable Poly box, a real `Tessellate` target configured with face-center tessellation, and generated paint-test vertices `#{21..26}`.


## VertexColorPainter public API


`VertexColorPainter_v` represents one paint session bound to one object and one topology level. The canonical shared instance is `VertexColorPainter`, and other Tools may instantiate additional `VertexColorPainter_v()` sessions when they need simultaneous independent targets.


### Public target properties


```text
source_node
    Bound scene node.


stack_index
    0  = Editable Poly base object.
    >0 = exact supported stack target used as the polygon-topology target; currently `Edit_Poly` or `Tessellate`.


map_channel
    Vertex-color map channel. Default: 0.
```


`source_node` and `stack_index` are state of the painter instance so paint methods do not repeatedly receive them. External callers must bind the target through `setTarget()` rather than mutating cached target state manually.


For positive stack indices the instance also stores the exact supported target modifier reference. When the painter inserts its own PaintLayerMod immediately above that target, modifier indices move; `stack_index` is synchronized to the target modifier's current index.


### Public methods


```text
setTarget target_node target_stack_index
    Bind one node and one topology level and build its cache.


refresh()
    Rebuild the current target snapshot and topology caches.


invalidate()
    Mark the current topology cache stale after an external topology edit.


isTargetValid()
    Validate that the cached target still exists and retains the cached topology counts.


beginPaint()
    Start a paint transaction and acquire reusable paint state when required.


paintCorner geo_vertex_id face_id color_value
    Paint one exact face/vertex color entry.


paintVertex geo_vertex_id color_value
    Paint all face-corner representations of one geometry vertex.


paintVertices vertex_ids color_value
    Paint an Integer, BitArray, or Array of geometry vertices with one color.


paintEdge edge_id color_value
    Paint both edge vertices on every polygon face adjacent to the edge.


paintFace face_id color_value
    Paint every color entry of one Editable Poly polygon face.


paintCorners paint_data
    Bulk exact-corner API. Each row is #(geo_vertex_id, face_id, color_value).


endPaint()
    Apply/release one cached VertexPaintState and finish the transaction.


clearPaint()
    Restore direct base colors or remove only the painter-owned PaintLayerMod.
```


The key low-level identity is:


```text
geo_vertex_id + face_id -> exact face-corner color entry
```


For the direct base backend this pair is resolved to the matching channel-0 map vertex by pairing polygon corner order with map-face corner order. For the modifier backend the same pair is sent to `VertexPaintState.SetFaceVertColor`. The API never assumes `geometry vertex ID == map vertex ID`.


### Cached topology


After `setTarget()` / `refresh()`, the instance keeps reusable data for repeated diagnostics:


```text
evaluated_mesh
vertex_count / edge_count / face_count
face_vertices
face_edges
edge_vertices
edge_faces
vertex_faces
face_map_vertices       -- direct base backend
geo_to_map_vertices     -- direct base backend
```


The temporary evaluated mesh is cached for geometry analysis only. Its TriMesh face IDs are never part of the public polygon-face API. Editable Poly / Edit Poly component IDs come from the exact bound polygon topology.


A topology-changing external operation must call `invalidate()` and then `refresh()` before reusing component IDs. Cache rebuilding is a topology-state boundary; the painter does not repeatedly rediscover map correspondence on every paint call.


`VertexPaintState` is held only during `beginPaint()` -> paint calls -> `endPaint()`, allowing large diagnostics to apply many colors with one state acquisition/application.


## Channel 0 rules


Map channel `0` is the vertex-color channel.


Production painting must preserve existing channel-0 topology.


Do not call `polyop.setNumMapFaces` on channel 0.


When channel 0 does not exist, the direct Editable Poly backend may create a default white vertex-color map using the native mapping API before painting.


A paint session captures the original channel-0 state before the first modification.


Restoration rules:


- if channel 0 did not exist before the session, remove debugger-created channel-0 support;
- if channel 0 already existed, restore its original map-vertex color values;
- restore only when geometry and map-face topology still match the captured state;
- if topology changed, refuse unsafe restoration instead of applying stale map-vertex IDs.


## Surface-region model


Diagnostics must reason about visible Editable Poly topology, not raw triangulation.


Example: a box wall vertically subdivided into two Editable Poly polygons is still one logical wall when the internal subdivision is not a real wall boundary.


A geometry vertex on a real box corner where two walls meet can require two channel-0 map vertices even if several Editable Poly polygons or many mesh triangles touch that point.


Map-color splits should eventually follow logical surface boundaries rather than raw triangle count.


Smoothing groups may be used as a signal, but they are not the only definition of a logical wall.


## First version — 0.01


Version 0.01 proves the direct Editable Poly channel-0 backend before adding any diagnostic algorithms.


### Test object


Create a standard 1×1×1-segment Box, convert it to Editable Poly, and build deliberately face-split channel-0 topology:


- 8 geometry vertices;
- 6 polygon faces;
- 24 channel-0 map vertices;
- four unique map vertices per polygon face.


After the split channel-0 map is built, `CREATE TEST BOX` adds the canonical real `Tessellate` modifier through `modPanel.addModToSelection (tessellate ()) ui:on` with `faceType = 1`, `type = 0`, `tension = 0`, and `iterations = 0`. The Tessellate target is left selected for normal UI use. Direct-base regression stages explicitly select the Editable Poly base before testing channel-0 writes.


This test topology is intentionally more split than a production wall map. It exists only to prove that separate face-corner colors remain visually independent at shared geometry vertices.


### Six-color test


Assign one solid color to each box polygon:


1. red;
2. green;
3. blue;
4. yellow;
5. cyan;
6. magenta.


Expected viewport result:


- six solid polygon colors;
- hard color seams at polygon boundaries;
- no averaging of red/green/blue face-corner values into one gray geometry-vertex value.


### First UI


Standalone Tool dialog with:


- canonical `.NET` tool title / restart button;
- `CREATE TEST BOX`;
- `PAINT FACE COLORS`;
- `RESTORE COLORS`;
- `DUMP CHANNEL 0`;
- one status line.


The native dialog title displays the current shared project version.


The dialog remembers position and height through the shared UI framework.


Geometry Diagnostics stores `Geometry-Diagnostics.ini` in the same folder as the tool scripts, not in the global 3ds Max user-scripts directory.


## Reload / dialog ownership


Before `Geometry-Diagnostics.ms` reloads the frontend, it saves the existing dialog state to the tool-local INI, unregisters the old rollout from CUI, destroys it, and clears any other dialog registered under the stable `Geometry-Diagnostics` DialogHost key. The newly loaded UI registers under the same key. This keeps reload/restart single-instance while preserving position and height.


## Test / Listener output


Development output should report:


- geometry vertex count;
- polygon face count;
- channel-0 map-vertex count;
- every polygon face's map-vertex IDs;
- every referenced map-vertex color value.


The dedicated test script keeps all test stages in one `.ms` file and leaves the final painted box in the scene for visual inspection.


## Second version — 0.02


Version 0.02 validates the geometry-vertex side of the paint interface and the reversible paint-session path.


### Geometry-vertex fan-out test


On the same fully face-split test box, geometry vertex `1` belongs to polygon faces `1`, `3`, and `6`.


For the generated test topology it resolves to channel-0 map vertices:


```text
#(1, 9, 22)
```


Painting geometry vertex `1` must:


- change exactly those three map vertices;
- preserve all other face-corner colors exactly;
- preserve all channel-0 map-face topology exactly.


The test uses a distinct orange color so the three affected face corners are visually obvious.


### Restore test


After the face-color and geometry-vertex paint stages, `RESTORE COLORS` must return the original 24 split test map vertices to white and close the stored paint-session backup.


After restore verification, the test repaints the six face colors plus the orange geometry-vertex fan-out and leaves that state in the scene for visual inspection.




## Paint backend routing


Routing is explicit in the reusable painter instance.


- `stack_index == 0`: use the direct Editable Poly channel-0 backend. Existing channel topology is preserved; a missing channel may be initialized before paint.
- `stack_index > 0`: the index must identify a target class supported by the canonical `VertexColorPainter` Operation. Current regression-proven targets are `Edit_Poly` and `Tessellate`. The painter creates/reuses only its own `PaintLayerMod` immediately above that exact target.
- Unrelated user VertexPaint / PaintLayerMod instances are never reused or removed.
- The painter stores the exact target modifier reference so insertion/removal of its own paint layer cannot lose target identity when stack indices shift.
- The base object underneath an active Edit Poly is never compacted by the modifier backend.
- Component IDs passed to `paintCorner`, `paintVertex`, `paintEdge`, and `paintFace` always belong to the same topology cached by the instance.


Geometry Diagnostics follows the current Modify-panel stack selection. When the Editable Poly base is selected, painting binds stack index `0` and writes channel 0 directly. When a supported modifier is selected, Geometry Diagnostics binds `VertexColorPainter` to that exact modifier index; the Operation then owns creation, placement, reuse, and removal of its `PaintLayerMod` immediately above that target.


An unsupported selected modifier is refused rather than silently painting another topology level. If the painter-owned `PaintLayerMod` itself becomes the selected stack item, Geometry Diagnostics resolves it back to the exact target modifier stored by the active `VertexColorPainter` session.


### Modifier-paint regression fixture


The current Geometry Diagnostics modifier-paint regression uses the same proven fixture as the canonical `Vertex-Color-Painter-Test.ms`:


1. create the standard Geometry Diagnostics test box, which is an 8-vertex / 6-polygon Editable Poly base with one canonical real `Tessellate` modifier already added through `modPanel.addModToSelection (tessellate ()) ui:on`;
2. verify that Tessellate uses `faceType = 1`, `type = 0`, `tension = 0`, and `iterations = 0`;
3. bind `VertexColorPainter` to that exact Tessellate instance;
4. verify the evaluated/cached topology contains generated vertices `21` through `26`;
5. first paint the selected Tessellate faces through the public face-paint path, proving that modifier selection creates the painter-owned `PaintLayerMod`; then paint exactly `#{21..26}` through the public Geometry Diagnostics vertex-paint call;
6. verify the painter-owned `PaintLayerMod` sits above Tessellate and the base channel remains untouched;
7. clear only the owned paint layer and preserve the exact Tessellate target;
8. rebuild the visible final state on the same generated vertices.


This fixture replaces the earlier Geometry Diagnostics-specific Edit Poly tessellation fixture so the Tool regression and reusable painter regression exercise the same topology source.


### Fourth version — 0.04


Version 0.04 originally strengthened generated-vertex testing. Its current successor is the shared Tessellate fixture above, sourced directly from the canonical Vertex Color Painter regression.


The executable test calls `clearListener()` immediately before the numbered test queue so each run begins with clean Listener output.




## Reusable painter extraction — 0.06


Project 0.06 extracts all reusable paint-session behavior from Geometry Diagnostics into `Codebase/Operations/Vertex-Color-Painter/Vertex-Color-Painter.ms`.


Geometry Diagnostics now remains responsible for test geometry, UI, dumps, and future diagnostic algorithms. Painting is delegated to `VertexColorPainter_v`. The shared Operation provides the same direct channel-0 and Edit Poly + PaintLayerMod behaviors already proven by the 0.01-0.04 regression tests, while adding cached topology and explicit face-corner / edge / face API methods for reuse by other diagnostic Tools.


The dedicated Operation regression additionally verifies:


1. direct `paintCorner geo_vertex_id face_id color_value` resolves one exact split map vertex;
2. `paintVertex`, `paintEdge`, and `paintFace` operate from cached polygon topology;
3. direct `clearPaint()` restores the original channel-0 state;
4. Edit Poly tessellation is cached as the positive stack target;
5. tessellation-created vertices can be painted through the inserted PaintLayerMod without changing the base channel;
6. exact `geo_vertex_id + face_id` modifier painting stores one `VertexPaintState` face/vertex color entry;
7. `clearPaint()` removes only the painter-owned PaintLayerMod and preserves the target Edit Poly.




## Orthogonal edge diagnostic — current


`CHECK ORTHO EDGES` analyzes the exact selected paint topology using principal world-axis direction plus two explicit off-axis distance thresholds.


The diagnostic operates on the exact topology selected in the Modify panel and uses only visible/selectable Editable Poly polygon edges. For positive supported modifier targets, Geometry Diagnostics builds a disposable exact-target Editable Poly analysis copy, removes stack layers above the bound target, validates its polygon/edge IDs against the cached `VertexColorPainter` topology, then discards the copy. User geometry is not changed by analysis.


`postion preccision` is the strict valid-ortho cutoff. The supported values are `1mm`, `0.1mm`, and `0.01mm`, default `0.01mm`; the chosen millimeter value is converted with `units.decodeValue`.


`ortho tolerance` is the second distance cutoff for skewed/sloped geometry that is not strictly orthogonal but is still accepted as valid. The UI choices are `1.00mm`, `2.00mm`, `5.00mm`, and `10.00mm`, default `1.00mm`. The backend requires `ortho tolerance >= postion preccision`.


For each edge the dominant world axis is chosen first:


```text
Z-dominant
    off-axis drift = XY distance
    direction class = vertical


X-dominant
    off-axis drift = YZ distance
    direction class = horizontal


Y-dominant
    off-axis drift = XZ distance
    direction class = horizontal
```


Three-level classification contract:


```text
valid ortho
    off-axis drift <= postion preccision
    color = white


valid skewed / sloped
    postion preccision < off-axis drift <= ortho tolerance
    color = green -> blue


invalid skewed / sloped
    off-axis drift > ortho tolerance
    color = yellow -> red
```


The invalid yellow-to-red band reaches full red at `2 * ortho tolerance` and stays clamped red beyond that distance. This gives the open-ended invalid range a deterministic distance scale without reintroducing an angle threshold.


This is an explicit distance-tolerance feature, not hidden rounding. Actual geometry positions are never snapped or rewritten.


The result stores `visible_edges`, exact `horizontal_edges` / `vertical_edges`, `orthogonal_edges`, `valid_skewed_edges`, `invalid_edges`, and one indexed `edge_deviation_distances` entry per target edge. `suspicious_edges` remains a compatibility alias of `invalid_edges`.


Invalid edge IDs are also converted to exact face-corner vertex identities:


```text
#(geo_vertex_id, face_id)
```


The complete visible edge domain is painted by severity. Shared face-corners keep the largest incident off-axis distance, so a more severe edge cannot be hidden by a milder neighboring edge.


### Face-local edge color


An edge can be colored on only one polygon face.


For one edge plus one adjacent polygon face, Geometry Diagnostics paints only:


```text
#(edge_vertex_a, face_id)
#(edge_vertex_b, face_id)
```


The same geometry edge on the neighboring polygon face uses different face-corner color entries and can remain unchanged. This is exact face-local vertex-color data, not an edge-render primitive: the viewport interpolates vertex colors across the polygon, so the visual result is an edge-biased color gradient/band rather than a raster line.




## Future diagnostics


Planned diagnostics remain outside the paint backend.


### Face / wall


- face planarity;
- face normal direction;
- wall/surface-region classification;
- out-of-angle surface highlighting.


### Edge


Only visible Editable Poly edges are user-facing.


Current checks:


- horizontal / vertical orthogonal severity (`CHECK ORTHO EDGES`);
- `VERTICAL\SKEWED` LMB/RMB edge selection;
- `HORIZONTAL SLOPED` LMB/RMB edge selection.


Future checks:


- additional edge-angle / topology diagnostics.


Invisible triangulation edges remain an implementation detail.


### Vertex


Potential checks:


- vertex valence;
- multiple / coincident vertices;
- topology anomalies;
- other vertex-level mesh problems.


### Combined heat map


A later Geometry Diagnostics mode can run several diagnostics over the whole mesh and present a green / warning / error visual overview.


## Non-goals for 0.01


Version 0.01 does not yet implement:


- planarity detection;
- edge-angle detection;
- logical-wall detection;
- vertex-valence heat maps;
- duplicate-vertex detection;


Those features will be added above or beside the proven channel-0 paint backend after the direct Editable Poly path is confirmed in 3ds Max.


## Orthogonal severity colors — current


`CHECK ORTHO EDGES` paints the complete visible/selectable edge domain from the raw off-axis endpoint distance selected by the principal world axis.


Color levels are intentionally discontinuous at the validity boundaries:


- `off-axis drift <= postion preccision` -> white (`255,255,255`), valid ortho.
- `postion preccision < drift <= ortho tolerance` -> linear green (`0,255,0`) to blue (`0,0,255`), valid skewed/sloped.
- `drift > ortho tolerance` -> starts yellow (`255,255,0`) and blends to red (`255,0,0`) at `2 * ortho tolerance`; larger values remain red.


Because channel-0 / VertexPaint face-corner color data is shared by the two incident face edges at a polygon corner, the ortho overlay resolves corner conflicts by keeping the largest incident off-axis distance. This makes high-severity geometry deterministic and prevents a later mild edge from overwriting a severe shared corner.


## Direction buttons — 0.16


The DEBUG direction row mirrors the Wall-Fixer interaction model with `VERTICAL\SKEWED` on the left and `HORIZONTAL SLOPED` on the right. The Angle spinner is removed as redundant.


Both controls are dark WinForms buttons with orange text and explicit `.NET MouseUp` routing.


- `LMB` selects the matching principal-direction edges whose off-axis drift is `<= postion preccision`.
- `RMB` selects the matching principal-direction edges whose off-axis drift is `> postion preccision`.
- Vertical uses Z-dominant edges and measures XY endpoint distance.
- Horizontal first chooses X or Y as the dominant direction. X-direction edges measure YZ drift; Y-direction edges measure XZ drift.


The result is a real edge selection, not an orange paint proxy. Geometry Diagnostics creates/reuses its exact session-owned `Edit_Poly`, writes the BitArray, verifies selection read-back, activates that modifier in the Modify panel, sets Edge sub-object level, disables stack selection, and keeps `showCage = off`.


The Wall-Fixer `CTRL+RMB` geometry-fix branch is still intentionally not imported into Geometry Diagnostics.


## Direction-button selection mechanics — 0.19


The direction controls now use the Wall-Fixer direction-checker transport and recovery path rather than a Geometry Diagnostics-specific selection wrapper.


For each LMB/RMB action:


1. resolve or create the exact session-owned Geometry Diagnostics `Edit_Poly`;
2. switch to Create-panel context before live-topology reads;
3. bind the Edit Poly primary node explicitly;
4. set `useStackSelection = false`, `showCage = off`, and Edit Poly selection level `#Edge`;
5. force an evaluated topology read when the modifier initially exposes zero live edges;
6. if the Editable Poly base has edges but the owned Edit Poly still exposes zero live edges, delete only that exact owned modifier, rebuild it once, and repeat the Wall-Fixer preparation path;
7. read edge count, endpoint vertex IDs, object positions, and world positions through the same adapter sequence used by Wall-Fixer;
8. classify the edge from endpoint positions with `postion preccision` only; no edge angle is calculated;
9. activate the exact Edit Poly in Modify mode at Edge sub-object level;
10. write the requested edge BitArray with `EditPolyMod.SetSelection`;
11. if immediate read-back differs, clear and retry through `EditPolyMod.Select`;
12. update the node, reactivate the same Edit Poly/Edge display state, redraw, and read the final selection again;
13. report failure unless the final BitArray exactly matches the request and the Edit Poly remains active at Edge level.


The `.NET` buttons retain the Wall-Fixer dark-button style and explicit `MouseUp` LMB/RMB routing. Geometry Diagnostics intentionally does not import Wall-Fixer's CTRL+RMB geometry-fix branch.


The only intentional behavior difference from Wall-Fixer is the classifier:


- vertical: Z-dominant edge, compare endpoint XY drift;
- horizontal X-direction: compare endpoint YZ drift;
- horizontal Y-direction: compare endpoint XZ drift;
- LMB: drift `<= postion preccision`;
- RMB: drift `> postion preccision`;
- no angle calculation is used.

## Direction-button selection input — 0.20

The two direction buttons now consume the current geometry-object selection directly, matching Wall-Fixer's checker entry path rather than using the Geometry Diagnostics paint-target resolver.

A selected geometry primitive does not need to be converted to Editable Poly before the check. The direction adapter creates/reuses its Edit Poly, scans that live topology, stores the requested edge BitArray, activates the modifier in Modify mode, and leaves Edge sub-object level active.

The classifier remains position based: no angle is calculated. `postion preccision` is the only cutoff used by the direction-button exact/skewed selection.

## Direction-button command-panel state — 0.21

The Wall-Fixer-style Create-panel phase is an internal live-topology preparation step only. A completed `VERTICAL\SKEWED` or `HORIZONTAL SLOPED` action must finish with the 3ds Max **Modify panel active**.

When at least one direction result succeeds, Geometry Diagnostics reactivates the exact last successful session-owned `Edit_Poly`, keeps Edge sub-object level active, and verifies `getCommandPanelTaskMode() == #modify`. If no result is available, the action still returns the Command Panel to Modify mode rather than leaving the temporary Create-panel preflight visible.

## Wall-Fixer bind-failure compatibility — 0.22

The Wall-Fixer runtime trace proves that `ensureEditPolyPrimaryNode` can fail during the Create-panel preparation pass while the same `Edit_Poly` still exposes live topology and accepts the requested edge selection afterwards. That preparation failure is therefore diagnostic/advisory for this workflow, not an automatic abort condition.

Geometry Diagnostics mirrors that behavior for `VERTICAL\SKEWED` and `HORIZONTAL SLOPED`:

- attempt the same primary-node binding and report its native failure;
- do not discard the adapter solely because that preparation step returned false;
- continue with the direct `EditPolyMod.GetNumEdges` topology read;
- activate the exact owned Edit Poly in Modify mode;
- write the requested edge BitArray through `SetSelection`, with `Select` fallback;
- update, reactivate, redraw, and use the final `GetSelection` BitArray as the decisive selection result;
- finish with the Modify panel active, the exact owned Edit Poly current, and Edge sub-object level `2`.

The position classifier remains the only intentional difference from Wall-Fixer: Geometry Diagnostics uses `postion preccision` endpoint-distance comparison and does not calculate an angle.

## Planar wall diagnostic — 0.23

The first user-facing action is the Wall-Fixer-derived `.NET` button `1. CHECK AND MAKE WALLS PLANAR`. Its geometry behavior is intentionally sourced from the working Wall-Fixer planar-wall check/fix path.

- LMB snapshots the evaluated geometry, groups adjacent triangles into wall clusters while shared-edge angle stays below `45°`, finds a robust majority plane for each cluster, merges true outlier vertex IDs, and selects those vertices. Connected objects containing several walls, including boxes, remain one object while each wall plane is analyzed independently.
- A current top `Edit_Poly` is reused for the LMB vertex selection. When no editable top level exists, Geometry Diagnostics creates an exact session-owned `NON PLANAR VERTS` marker and never adopts/deletes a same-name foreign modifier.
- RMB removes only that exact owned temporary marker before deciding whether the real stack must be repaired. If the source still has modifiers or a non-Editable-Poly base, it follows Wall-Fixer and collapses the evaluated result to Editable Poly before moving geometry.
- Each detected outlier is projected to its owning wall plane. Shared corner vertices are solved against every touching wall-cluster plane, using the strongest independent plane intersection when multiple planes meet. The result is re-analyzed and RMB reports failure if any non-planar outliers remain.
- The inherited Wall-Fixer numeric contract is preserved for this port: planar fitting tolerance `1.0`, orientation aid `5°`, wall-cluster corner split `45°`, and Wall-Fixer's internal robust-plane numeric guards.
- Both LMB and RMB finish with the 3ds Max Modify panel active; LMB leaves Vertex sub-object level active when outliers are selected.



## Tests UI organization — 0.24

The former `DEBUG` rollout group is user-facing as `TESTS`. `1. CHECK AND MAKE WALLS PLANAR` is the first control inside that group, followed by the existing position/ortho controls and edge diagnostics. This is a UI organization change only; the planarity LMB/RMB contract and backend behavior remain unchanged.

## Tests / Debug UI organization — 0.25

The main diagnostic controls remain in the `TESTS` group. The development utility controls `CREATE TEST BOX`, `PAINT FACE COLORS`, `RESTORE COLORS`, and `DUMP CHANNEL 0` are grouped separately under `DEBUG`, and `DEBUG` is the bottom section of the dialog. This is a UI-only organization change; diagnostic and backend behavior are unchanged.

## Tests threshold row — 0.26

`postion preccision` and `ortho tolerance` are the first controls in the `TESTS` group and share one horizontal row. `1. CHECK AND MAKE WALLS PLANAR` follows below them. This is a UI-only layout change; persisted threshold values and backend behavior are unchanged.
## Tests button styling and order — 0.27

All action buttons inside `TESTS` use the Wall-Fixer-derived dark WinForms `.NET` button style. The threshold dropdowns remain the first row, followed by the vertical/horizontal direction buttons and `CHECK ORTHO EDGES`. `1. CHECK AND MAKE WALLS PLANAR` is the bottom action in `TESTS`. This is a UI-only change; diagnostic behavior is unchanged.
## Clear object — 0.28

`CLEAR OBJECT` is a destructive development utility in the bottom `DEBUG` group.

- It operates on the current geometry-object selection.
- It removes **every** modifier from each selected object, including user-created modifiers; this is intentionally broader than normal Geometry Diagnostics exact-instance ownership cleanup.
- When the base object is `Editable_Poly`, map channel `0` support is disabled so stored base vertex paint is removed as well.
- Vertex-color viewport display is disabled after cleanup.
- If the shared `VertexColorPainter` is bound to the target, its current paint session is cleared first so no held `VertexPaintState` or base-color backup can later restore deleted paint.
- Geometry Diagnostics edge/planar ownership rows are pruned after the stack has been cleared.
- The operation is undoable, verifies that the modifier stack is empty and Editable Poly channel `0` is disabled, and finishes with the Modify panel active at Object level.




## Direction CTRL+RMB repair and Ortho RMB batch — 0.29

The two direction controls now import Wall-Fixer's selected-direction loop repair interaction as `CTRL+RMB`. Wall-Fixer's source event routing uses LMB for exact selection, RMB for skewed selection, and `CTRL+RMB` for `fixSelectedDirectionEdges`; Geometry Diagnostics keeps the same event contract while retaining its position-based classifier.

Geometry Diagnostics intentionally does not import Wall-Fixer's angle threshold into this repair. Loop candidates use the same principal-axis endpoint classification as the direction buttons. Within-precision reference edges, loop-target grouping, final moved-edge verification, and position read-back use the explicit `postion preccision`. Vertical repair constrains selected loop vertices to one world XY target while preserving Z. Horizontal repair constrains them to one world Z target while preserving XY.

The repair preserves the current edge selection, restores any pre-existing vertex selection used as a manual Wall-Fixer-style loop anchor, reactivates the exact session-owned direction `Edit_Poly`, and finishes in the Modify panel at Edge sub-object level with `showCage = off`.

`CHECK ORTHO EDGES` remains a two-event control:

- LMB runs the existing white / green-blue / yellow-red severity paint diagnostic.
- RMB executes the requested ordered repair batch on each selected geometry object: `VERTICAL\SKEWED` LMB selection, vertical `CTRL+RMB` repair, `HORIZONTAL SLOPED` LMB selection, horizontal `CTRL+RMB` repair. The batch uses the same backend entry points as the individual buttons and leaves the final direction Edit Poly active at Edge level.


## Direction CTRL+RMB constraint solver — 0.30

Project 0.30 replaces the Wall-Fixer loop-target repair that was imported in 0.29. The source workflow assumes a different horizontal definition and also consumes whatever edge/vertex selection already exists. Those assumptions are not valid for Geometry Diagnostics.

`CTRL+RMB` is now self-initializing. For each selected geometry node it first runs the same `#skewed` position-based direction detection used by ordinary RMB, stores that exact edge BitArray in the owned direction `Edit_Poly`, then repairs that detected set. A previous RMB click is no longer required and stale vertex selection is not used as a target hint.

The repair constraint matches the Geometry Diagnostics classifier exactly:

- Z-dominant vertical edge -> endpoint X and Y must match; Z remains free.
- X-dominant horizontal edge -> endpoint Y and Z must match; X remains free.
- Y-dominant horizontal edge -> endpoint X and Z must match; Y remains free.

Selected edges are converted into independent coordinate-constraint components. For each constrained coordinate, exact visible unselected neighbor edges that constrain the same coordinate provide anchors. Anchor values are grouped with the explicit `postion preccision`; the strongest group wins. When no anchor exists, the selected component uses the mean of its original coordinate values, giving the minimum-displacement fallback without inventing an angle threshold. All target coordinates are solved before any vertex is moved.

Edit Poly movement follows the shared Epoly stable pattern: isolate the exact vertex selection with `.Select`, apply `MoveSelection`, `Commit`, and verify the resulting world position. World-space targets are converted to object-space deltas before `MoveSelection`; this avoids inheriting Wall-Fixer's implicit coordinate-space assumption. No topology changes occur, so no dead-structure compaction is part of this operation.

After movement, every originally detected skewed edge is rechecked with `postion preccision`. The detected edge BitArray is restored visibly, the owned direction Edit Poly remains current, and the tool finishes in Modify mode at Edge level.

`CHECK ORTHO EDGES` RMB retains the requested order: vertical LMB, vertical CTRL+RMB, horizontal LMB, horizontal CTRL+RMB. Because each CTRL+RMB now performs its own skewed detection, the LMB selection is only the requested visible step and cannot seed the repair with the wrong exact-edge set.

## Vertical CTRL+RMB selected-component repair — 0.31

Project 0.31 isolates the reported `VERTICAL\SKEWED CTRL+RMB` failure. Ordinary vertical RMB selection is already working and is not changed.

Vertical CTRL+RMB now treats the RMB-selected skewed vertical edge BitArray as the repair domain. It never expands the repair through unselected loop edges. If the user invokes CTRL+RMB without a preceding RMB, Geometry Diagnostics runs the same vertical RMB detection once and uses that resulting BitArray.

The selected vertical edges are split into connected components through shared selected-edge vertices. For each component:

- the lowest world-space component vertex is the deterministic anchor;
- the anchor XY is preserved exactly;
- every vertex in the component receives the anchor X and Y while retaining its own original Z;
- only vertices belonging to the selected vertical component are moved;
- final selected edges must satisfy the existing Z-dominant vertical classifier within the explicit `postion preccision`.

This removes the Wall-Fixer-derived target-initialization ambiguity from the vertical repair. The operation still uses the exact owned direction `Edit_Poly`, restores the caller's vertex selection, restores the original RMB edge BitArray, refreshes once, and finishes with the Modify panel active at Edge level. No topology is changed.



## Unified no-guess direction repair — 0.32

`VERTICAL\SKEWED CTRL+RMB` and `HORIZONTAL SLOPED CTRL+RMB` now share one repair algorithm. The requested direction changes only which principal world axis is considered free: Z for vertical, X for X-running horizontal edges, and Y for Y-running horizontal edges.

The repair domain is the current matching RMB skewed/sloped edge selection when one exists. If CTRL+RMB is invoked without such a selection, Geometry Diagnostics runs the same RMB detection once and uses that result. Selected edges are split into connected components by their principal axis so X-, Y-, and Z-running components are never mixed.

For every component Geometry Diagnostics performs a read-only trust preflight before any vertex is moved:

1. Snapshot the evaluated node and require the temporary mesh vertex count / component vertex positions to match the live direction Edit Poly ID domain within `postion preccision`.
2. Collect faces touching the selected component, then collect their vertices that are outside the selected component. At least three such reference vertices are required.
3. Resolve one plane from those neighboring vertices and require every reference vertex to lie on that plane within `postion preccision`. If the local topology represents a corner, several wall planes, non-planar reference geometry, or too little reference geometry, the component is unresolved.
4. Search the component boundary for an unselected visible edge that continues the same principal axis, is already exact within `postion preccision`, and has both endpoints on the trusted wall plane. This is the same-loop direction reference.
5. If several valid references exist, their constrained coordinates must agree within `postion preccision`. Conflicting references are unresolved; the tool never averages or votes them into a new target.

A valid reference vertex is an anchor and is never moved. For every non-anchor vertex, the coordinate along the desired edge direction is preserved exactly while the other two coordinates are copied from the trusted anchor:

```text
Z-running vertical:   keep Z, use anchor X/Y
X-running horizontal: keep X, use anchor Y/Z
Y-running horizontal: keep Y, use anchor X/Z
```

The resulting world-space target must also remain on the trusted wall plane within `postion preccision`. This simultaneously removes the out-of-wall-plane deviation and the in-wall skew/sloping without moving the vertex along the desired edge direction. If the axis-aligned target cannot stay on the trusted plane, the component is unresolved rather than forced.

All target plans are solved before movement. Horizontal X/Y components that share a selected vertex are treated as ambiguous junctions and remain untouched. Resolved vertices are moved through the established Edit Poly `Select -> MoveSelection -> Commit` path and read back against `postion preccision`; the original RMB edge BitArray is restored for inspection.

The safety rule is explicit: **no trustworthy wall plane + no trustworthy same-loop exact reference = no geometry change for that component**. Safe components may still be repaired while unresolved components stay in place and are reported. `CHECK ORTHO EDGES` RMB keeps the requested sequence: vertical LMB -> vertical CTRL+RMB -> horizontal LMB -> horizontal CTRL+RMB.

## Same-loop no-guess direction repair — 0.33

`VERTICAL\SKEWED CTRL+RMB` and `HORIZONTAL SLOPED CTRL+RMB` keep one shared repair method, but the 0.32 whole-neighborhood wall-plane fit is removed. Runtime testing showed that collecting every face vertex around a selected component mixes valid corner walls and rejects otherwise repairable components.

The trusted reference is now the exact continuation of the same topological loop:

1. Keep the ordinary RMB skewed/sloped edge BitArray unchanged as the repair domain.
2. Split the selected set into connected components by principal axis.
3. At a component boundary, inspect unselected visible incident edges.
4. A candidate reference must use the same principal axis, already be exact within `postion preccision`, and leave the shared anchor vertex in the opposite free-axis direction from at least one selected component edge. This opposite-direction rule rejects same-side branches.
5. If no candidate exists, the component is unresolved and does not move.
6. If several anchors exist, their constrained coordinates must agree within `postion preccision`. Conflicting anchors leave the component unresolved.
7. Anchor vertices and reference edges are never moved.
8. Every non-anchor selected vertex preserves its coordinate along the requested direction and copies only the two constrained coordinates from the trusted anchor:

```text
Z-running vertical:   keep Z, use anchor X/Y
X-running horizontal: keep X, use anchor Y/Z
Y-running horizontal: keep Y, use anchor X/Z
```

The trusted continuation edge already lies on the wall loop and therefore supplies the 3D target line. Snapping a bad component onto that line corrects both kinds of deviation described by the tool contract: depth away from the wall and lateral skew/sloping inside the wall. No separate plane average or projection is needed.

Safety remains strict: **no trustworthy same-loop continuation = no geometry change**. There is no mean-coordinate fallback, lowest-vertex fallback, plane guess, or automatic shift of otherwise valid surrounding geometry.

Edit Poly coordinate access follows the shared Epoly transform pattern: instance calls such as `edit_poly_mod.GetVertex vertex_id node:source_node`, object-space `MoveSelection` deltas, `Commit`, and explicit read-back through `postion preccision`. This fixes the runtime case where static-style reads produced the node transform origin instead of the requested vertex position.

## Ortho RMB independent passes and partial accounting — 0.35

The ordered vertical-first, horizontal-second Ortho RMB batch must attempt horizontal detection and repair even when a vertical component cannot be resolved. The existing no-guess same-loop reference rule remains unchanged, and an unresolved component is never forced into a guessed target.

Each verified repaired edge contributes to the batch count even when other components are unresolved. The batch reports the affected object as unresolved/failed while retaining the verified repaired-edge count, and preserves the exact owned Edit Poly selection/display workflow. This does not mean that partial completion is full success.


## Direction button grid and title styling — 0.36

The TESTS group exposes two paired rows of equal-size WinForms buttons: `VERTICAL` beside `SKEWED \ FIX`; `HORIZONTAL` beside `SLOPED \ FIX`. Left direction buttons retain `LMB` exact-edge selection, `RMB` off-axis selection, and `CTRL+RMB` repair. Right buttons expose the same existing backend workflows directly: `LMB` selects off-axis skewed/sloped edges, and `RMB` repairs only components with a trusted exact same-loop reference.

The .NET restart title button retains the canonical `ToolTitleButton` label, 18 px height, resize-to-dialog-width behavior, and `LMB` reload action. Geometry Diagnostics adds local blue-accented dark styling after shared setup without changing the shared helper. The default/minimum dialog height is 564 px.

## Safe selection-only Editable Poly base repair — 0.37

When direction fixing a node with precisely one modifier, the script-owned `GEOMETRY DIAGNOSTICS` Edit Poly, and an Editable Poly base, validate that both levels have identical counts, ordered edge endpoint IDs (allowing reverse orientation), and vertex positions within the configured `postion preccision` before choosing the base as the repair geometry adapter. Do not collapse dead base topology after edge IDs have been cached; refuse the base repair path if dead structure exists. The owned modifier still owns the selected-edge BitArray, selection restoration, and active Edge-level display.

For this exact verified selection-only stack, use `polyop.setVert` on the base with explicitly converted object-local target coordinates, and verify repaired vertex positions plus final exact-edge directions against that base geometry. This bypasses modifier primary-node / `MoveSelection` context failures and is guarded against using base vertex IDs where other modifiers or topology changes could make them unsafe. For any other stack retain the existing Edit Poly path without hidden fallback. This does not relax the exact same-loop reference safety rule, and unresolved components remain unchanged.
