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

## VertexColorPainter public API

`VertexColorPainter_v` represents one paint session bound to one object and one topology level. The canonical shared instance is `VertexColorPainter`, and other Tools may instantiate additional `VertexColorPainter_v()` sessions when they need simultaneous independent targets.

### Public target properties

```text
source_node
    Bound scene node.

stack_index
    0  = Editable Poly base object.
    >0 = exact Edit Poly modifier used as the polygon-topology target.

map_channel
    Vertex-color map channel. Default: 0.
```

`source_node` and `stack_index` are state of the painter instance so paint methods do not repeatedly receive them. External callers must bind the target through `setTarget()` rather than mutating cached target state manually.

For positive stack indices the instance also stores the exact target modifier reference. When the painter inserts its own PaintLayerMod immediately above that target, modifier indices move; `stack_index` is synchronized to the target modifier's current index.

### Public methods

```text
setTarget target_node target_stack_index
    Bind one node and one topology level and build its cache.

refresh()
    Rebuild the current target snapshot and topology caches.

invalidate()
    Mark the current topology cache stale after an external topology edit.

isTargetValid()
    Validate that the cached node / modifier binding still exists for the current session. External topology edits must call invalidate() before refresh().

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

clear()
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

The temporary evaluated mesh is cached for geometry analysis only. Its TriMesh face IDs are never part of the public polygon-face API. Editable Poly component IDs come directly from the base object. Positive Edit Poly targets are evaluated on a temporary copied node stripped above the bound modifier and collapsed to Editable Poly; public polygon/edge/vertex IDs come from that exact evaluated polygon topology rather than from TriMesh triangles or Modify-panel-dependent Edit Poly query state.

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

Create a standard 1×1×1-segment Box and convert it to Editable Poly.

Build deliberately face-split channel-0 topology:

- 8 geometry vertices;
- 6 polygon faces;
- 24 channel-0 map vertices;
- four unique map vertices per polygon face.

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
- `stack_index > 0`: the index must identify an `Edit_Poly` modifier. The painter creates/reuses only its own `PaintLayerMod` immediately above that exact modifier.
- Unrelated user VertexPaint / PaintLayerMod instances are never reused or removed.
- The painter stores the exact target modifier reference so insertion/removal of its own paint layer cannot lose target identity when stack indices shift.
- The base object underneath an active Edit Poly is never compacted by the modifier backend.
- Component IDs passed to `paintCorner`, `paintVertex`, `paintEdge`, and `paintFace` always belong to the same topology cached by the instance.

Geometry Diagnostics may choose the topmost Edit Poly as its Tool-level default, but that automatic choice belongs to Geometry Diagnostics. `VertexColorPainter_v` itself always receives an explicit target through `setTarget()`.

### Third version — 0.03

Version 0.03 proves painting above topology-changing stack edits.

The modifier-path test:

1. creates a fresh Editable Poly test box;
2. keeps its 8-vertex / 6-polygon base object unchanged;
3. adds an Edit Poly modifier;
4. tessellates the six base polygons in that Edit Poly, increasing evaluated vertex count;
5. calls the same public geometry-vertex paint function;
6. verifies that a tool-owned VertexPaint modifier is created above the Edit Poly;
7. verifies that VertexPaint sees more than the base 24 raw face-corner entries;
8. verifies evaluated vertex `1` stores the requested orange diagnostic color;
9. verifies all 24 base channel-0 values remain white;
10. removes only the diagnostic VertexPaint layer and proves the tessellated Edit Poly remains;
11. rebuilds the modifier paint state and leaves it in the scene for visual stack inspection.

This establishes the non-destructive rule: when evaluated topology differs from the base object, diagnostic color belongs above the edit in VertexPaint rather than being baked into the Editable Poly base channel.



### Fourth version — 0.04

Version 0.04 strengthens the modifier-path test by targeting only vertices that exist after the Edit Poly tessellation.

The test records the base Editable Poly vertex count before tessellation and the evaluated vertex count after tessellation. Every evaluated vertex ID above the original base range is collected as a tessellation-created target.

The VertexPaint test must then:

1. paint that complete evaluated-only vertex set through the public `paintGeometryDiagnosticsVertices` interface;
2. verify every tessellation-created vertex stores the requested orange diagnostic color in the `PaintLayerMod`;
3. verify the original 24 channel-0 map vertices on the Editable Poly base remain white and unchanged;
4. remove only the Geometry Diagnostics VertexPaint layer while preserving the Edit Poly tessellation;
5. rebuild the final VertexPaint state on those newly created evaluated vertices for visual inspection.

This specifically proves that diagnostic paint is not limited to vertices that already existed on the base object.

The executable test calls `clearListener()` immediately before the numbered test queue so each run begins with clean Listener output.


## Reusable painter extraction — 0.06

Project 0.06 extracts all reusable paint-session behavior from Geometry Diagnostics into `Codebase/Operations/Epoly/Vertex-Color-Painter/Vertex-Color-Painter.ms`.

Geometry Diagnostics now remains responsible for test geometry, UI, dumps, and future diagnostic algorithms. Painting is delegated to `VertexColorPainter_v`. The shared Operation provides the same direct channel-0 and Edit Poly + PaintLayerMod behaviors already proven by the 0.01-0.04 regression tests, while adding cached topology and explicit face-corner / edge / face API methods for reuse by other diagnostic Tools.

The dedicated Operation regression additionally verifies:

1. direct `paintCorner geo_vertex_id face_id color_value` resolves one exact split map vertex;
2. `paintVertex`, `paintEdge`, and `paintFace` operate from cached polygon topology;
3. direct `clear()` restores the original channel-0 state;
4. Edit Poly tessellation is cached as the positive stack target;
5. tessellation-created vertices can be painted through the inserted PaintLayerMod without changing the base channel;
6. exact `geo_vertex_id + face_id` modifier painting stores one `VertexPaintState` face/vertex color entry;
7. `clear()` removes only the painter-owned PaintLayerMod and preserves the target Edit Poly.


## Future diagnostics

Planned diagnostics remain outside the paint backend.

### Face / wall

- face planarity;
- face normal direction;
- wall/surface-region classification;
- out-of-angle surface highlighting.

### Edge

Only visible Editable Poly edges are user-facing.

Potential checks:

- orthogonal edge direction;
- skewed edges;
- sloped edges;
- edge-angle checks.

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
