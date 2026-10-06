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

Keep analysis and painting separate.

```text
Diagnostics
    -> produce vertex / edge / face / surface-region results
Paint Backend
    -> converts those results to channel-0 vertex-color data
3ds Max viewport
    -> displays the diagnostic overlay
```

The paint backend must not contain diagnostic rules such as planarity, orthogonality, valence, or duplicate-vertex detection.

Future diagnostics call the same paint interface.

## Public paint model

Two coloring levels are required.

### Geometry vertex color

Color one or more Editable Poly geometry vertices everywhere they are represented in the vertex-color map.

Public behavior:

```text
paintGeometryVertices node vertex_bits color
```

A geometry vertex can correspond to multiple map vertices. The caller must not need to know that mapping.

The backend resolves this fan-out explicitly by pairing each Editable Poly polygon corner from `polyop.getFaceVerts` with the same corner index from channel-0 `polyop.getMapFace`. It does not rely on geometry-vertex IDs matching map-vertex IDs or on implicit native fan-out behavior.

### Face-corner color

Color the channel-0 map vertices used by one Editable Poly polygon face.

Public behavior:

```text
paintFaceCorners node face_id color
```

If channel-0 topology is split between neighboring polygons, this allows the same geometry vertex to display different colors on different polygon faces.

The backend must never assume:

```text
geometry vertex ID == map vertex ID
```

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
- VertexPaint modifier output.

Those features will be added above or beside the proven channel-0 paint backend after the direct Editable Poly path is confirmed in 3ds Max.
