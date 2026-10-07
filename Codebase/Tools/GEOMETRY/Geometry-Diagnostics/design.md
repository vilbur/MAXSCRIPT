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

