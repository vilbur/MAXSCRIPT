# Vertex Color Painter Design

## Purpose

`VertexColorPainter_v` is a reusable stateful Operation for painting diagnostic or analytical colors onto geometry without owning any diagnostic classification logic or UI. It supports direct painting on an Editable Poly base object and modifier-stack painting through an owned `PaintLayerMod`.

The package is intentionally placed directly under `Codebase/Operations/Vertex-Color-Painter/`, not under `Operations/Epoly/`, because it is not an Edit Poly operation. Editable Poly and supported stack modifiers are topology sources; the operation itself is a general vertex-color painting service.

## Public contract

Canonical shared instance:

```maxscript
VertexColorPainter
```

Independent sessions may be created with:

```maxscript
VertexColorPainter_v()
```

Public workflow:

```maxscript
VertexColorPainter.setTarget source_node stack_index
VertexColorPainter.beginPaint()
VertexColorPainter.paintCorner geo_vertex_id face_id color_value
VertexColorPainter.paintVertex geo_vertex_id color_value
VertexColorPainter.paintVertices vertex_ids color_value
VertexColorPainter.paintEdge edge_id color_value
VertexColorPainter.paintFace face_id color_value
VertexColorPainter.paintCorners paint_data
VertexColorPainter.endPaint()
VertexColorPainter.invalidate()
VertexColorPainter.refresh()
VertexColorPainter.isTargetValid()
VertexColorPainter.clearPaint()
```

`stack_index == 0` binds the Editable Poly base object. Positive indices bind a verified supported modifier target. Current verified positive target classes are `Edit_Poly` and `Tessellate`.

## Topology domain

All component IDs supplied after `setTarget()` belong to the exact cached topology for that target. IDs from another stack level must never be mixed into the session.

Base targets cache Editable Poly polygon/edge/vertex IDs directly. Positive stack targets are evaluated on a temporary copy, stripped above the bound target, converted to Editable Poly, and cached from that evaluated polygon result. The user's real stack is not collapsed or rewritten.

`snapshotAsMesh` is implementation data only. Its triangle face IDs must never be substituted for cached polygon face IDs.

After any external topology-changing operation, callers must execute:

```maxscript
VertexColorPainter.invalidate()
VertexColorPainter.refresh()
```

before reusing component IDs.

## Direct base backend

For `stack_index == 0`, painting writes channel 0 map data directly on the Editable Poly base object.

Before first paint, the operation captures reversible channel-0 state. Missing channel support is created only when painting actually begins. Geometry-to-map correspondence is cached per polygon corner so one geometry vertex may have multiple independent map representations.

`paintCorner geo_vertex_id face_id color_value` is the exact primitive. Vertex, edge, and face paint methods resolve into one or more exact polygon corners.

`clearPaint()` restores the original channel support, map topology, and colors when the cached topology still matches the captured state. It refuses unsafe restoration after incompatible topology changes.

## Modifier backend

For a positive supported stack target, the operation inserts one owned `PaintLayerMod` immediately above the bound target and paints through `VertexPaintState`.

Modifier-array indices are top-to-bottom. To insert immediately above target index `T`:

- `T == 1`: add the PaintLayerMod at the top;
- `T > 1`: use `before:(T - 1)`.

Placement is verified after insertion.

The modifier backend supports independent polygon-corner colors. The same geometry vertex may resolve to different raw VertexPaint entries on adjacent faces. This behavior is regression-tested.

## Ownership

PaintLayer ownership is exact-instance only.

The string `VERTEX COLOR PAINTER` is a display name and is never an ownership token. The operation must never adopt, edit, or delete an unrelated `PaintLayerMod` merely because it has the same name.

If the owned instance reference is lost, `getPaintLayerMod()` returns `undefined`; it does not search by name.

`clearPaint()` removes only the exact owned PaintLayerMod instance.

## Display state

The operation captures the node's vertex-color display state before painting and enables color display for the session. `clearPaint()` restores the saved display state.

Tests may deliberately rebuild visible color after cleanup so the final scene remains inspectable. That visual test state is not part of production ownership semantics.

## Failure behavior

The operation fails rather than fabricating valid-looking data when:

- the source node is invalid;
- the selected stack level is unsupported;
- the bound target modifier disappears;
- evaluated topology cannot be cached consistently;
- component IDs are outside the cached topology;
- PaintLayer placement is wrong;
- `AcquirePaintState` / `ApplyPaintState` fails;
- direct map restoration is unsafe because topology changed.

Critical exceptions are reported with the original exception text.

## Dead-topology safety

Base Editable Poly topology may be compacted only at a safe topology-state boundary and only when no active modifier stack depends on the base indices. The operation must never call `polyop.collapseDeadStructs` on the base object underneath active modifiers as a speculative repair.

Temporary evaluated copies may be compacted before their cached IDs are read because those copies are disposable and are not used by the user's modifier stack.

## Verified regression coverage

The canonical regression test covers:

- direct Editable Poly channel-0 painting;
- exact base face-corner mapping;
- vertex, edge, and face APIs;
- reversible `clearPaint()` on the base backend;
- a real topology-changing `Tessellate` target;
- generated vertices `#{21..26}` painted through `PaintLayerMod`;
- correct PaintLayer placement immediately above the target;
- unchanged base channel while modifier paint is active;
- independent raw face-corner colors for one generated geometry vertex;
- exact-instance PaintLayer ownership when an unrelated same-name layer exists;
- cleanup that preserves the target modifier and unrelated modifiers;
- a final visual inspection state for both backends.

## Integration rules

Higher-level Tools should delegate color storage to this Operation and keep classification/detection logic outside it.

A caller should:

1. choose the exact topology level it analyzes;
2. call `setTarget()` for that same level;
3. paint only IDs from that cached domain;
4. call `invalidate()` after external topology changes;
5. call `clearPaint()` when the diagnostic paint session ends.

Do not copy the painting implementation into Tools. Do not use modifier names as ownership. Do not translate TriMesh face IDs into polygon IDs by assumption.

## Non-goals

This package does not:

- detect geometry problems;
- decide what colors mean;
- author or commit Edit Poly operations;
- perform tessellation, weld, connect, or other topology edits;
- own UI;
- persist PaintLayer ownership across module reloads by name.
