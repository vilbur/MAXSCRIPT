# Missing Loop Rebuilder — Design

## Goal

Reconstruct missing pieces of an edge loop/ring from mesh topology without relying on the test-generator settings.

The first implementation deliberately targets a simple, controlled case: a segmented planar Editable Poly where one or more connected internal edges have been removed, creating an n-gon. The tool detects the missing topology and rebuilds the missing edges between existing vertices.

## Terminology

Keep standard 3ds Max / modeling terminology in the UI and implementation: edge, vertex, face, edge loop, ring, n-gon, Editable Poly, Edit Poly.

## Core behavior

- Work with Editable Poly and Edit Poly workflows.
- Ignore border-only reconstruction candidates. A candidate missing edge must represent internal topology.
- Do not create duplicate vertices when the required vertices already exist.
- Reconstruct only clearly missing topology.
- Preserve already-correct edges and faces outside the missing region.
- The reconstruction logic must infer the missing topology from the mesh itself. Test-generator values are never inputs to the repair algorithm.

## Phase 1 — planar missing-edge reconstruction

Create a segmented plane/grid and remove internal edges to produce one or more n-gons.

The repair algorithm must find the n-gon created by the missing edge or edges, determine which existing vertices should be connected, and recreate the missing edge topology.

A valid damaged region may contain:

- one missing edge;
- multiple connected missing edges in the edge-loop direction;
- multiple neighboring missing edges in the ring direction;
- a combination of both directions.

The initial target includes an n-gon with six vertices produced by two missing connected edges.

## Test object generator

The test UI contains two independent controls:

- `Missing Count Loop` — number of connected edges removed in the edge-loop direction.
- `Missing Count Ring` — number of neighboring missing edges removed across the ring direction.

Examples:

- Loop = 1, Ring = 0: one missing edge.
- Loop = 2, Ring = 0: two connected missing edges in one edge loop.
- Loop = 0, Ring = 2: missing edges distributed across the ring direction.
- Loop = 2, Ring = 2: four missing edges forming a combined damaged region.

The generator exists only to create deterministic test meshes. The production detector/rebuilder must not read these values when deciding what to repair.

## Detection principles

For the first version:

1. Inspect internal n-gons created by removed edges.
2. Use surrounding intact quad topology to infer the continuation of the original grid/edge flow.
3. Identify pairs of existing vertices that should have an edge between them.
4. Reject ambiguous cases rather than guessing.
5. Rebuild only the clear missing edges.

## Future direction — broken loop across polygon chains

The architecture must allow the detector to grow beyond a single n-gon.

The intended later behavior is:

1. Detect an internal T-junction where an existing edge loop terminates into damaged topology.
2. Infer the direction/topology of the incoming edge loop and its corresponding ring.
3. Trace the expected missing loop through one or more affected polygons.
4. Intermediate faces may be ordinary polygons or additional n-gons depending on which vertices/edges survived.
5. Continue through the same clear ring; do not choose a path merely because it is geometrically or topologically shortest.
6. Stop at the corresponding internal T-junction where the intact edge loop resumes.
7. Reconnect existing vertices along that path and split intervening polygons as required.

Conceptually:

`T-junction -> trace missing edge loop through its ring -> opposite T-junction -> rebuild missing edges`

## Safety / ambiguity

The tool should prefer no change over an uncertain reconstruction. A route is valid only when surrounding topology gives a clear continuation. Border T-junctions and border damage are outside the intended reconstruction set.

## UI / project requirements

- Production filename: `Missing-Loop-Rebuilder.ms`.
- Keep processing logic separate from UI logic where practical.
- Include test code for the geometry behavior.
- Test object must be Editable Poly.
- Editable Poly cage must be off.
- Keep the implementation ready for later multi-polygon reconstruction rather than hard-coding one plane orientation or one missing-edge axis.
