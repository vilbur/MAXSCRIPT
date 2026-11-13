# EPoly-Stack-Test — Design

## Purpose

`EPoly-Stack-Test` is a diagnostic MaxScript module for proving that topology created by one `Edit_Poly` modifier can be read and modified correctly by later `Edit_Poly` modifiers higher in the same modifier stack.

The test is intentionally small and sequential. Every stage owns exactly one named `Edit_Poly` modifier. No stage may collapse the stack or depend on hardcoded vertex, edge, or face IDs.

The final expected stack is:

```text
04 WELD RESULT
03 ADD LOOPS
02 MAKE OPEN BOX
01 CREATE CROSS
Plane
```

The base object remains a parametric one-segment Plane.

## Core design constraints

- Keep the Plane parametric.
- Never collapse the modifier stack.
- Every meaningful topology-changing stage gets its own `Edit_Poly`.
- Later stages must read the topology that actually reaches their own modifier.
- Do not transfer raw component IDs from lower modifiers.
- Do not use hardcoded component IDs.
- Resolve topology geometrically or from the active modifier itself.
- Use `useStackSelection = false`.
- Use `selectMode = 0`.
- Prefer one bulk BitArray selection over repeated per-component selection.
- Do not use hidden geometry tolerances or rounding.
- Exact position comparisons remain exact unless a tolerance becomes an explicit part of the test contract.
- Every stage must validate its result before allowing later stages to be treated as valid.
- Leave the final scene state intact for visual inspection and undo stepping.

## Base object

Create one Plane:

```text
length segments: 1
width segments: 1
```

The Plane starts as one quad.

Default test size is 100 system units.

The base Plane itself is not converted to Editable Poly.

## Stage 00 — SETUP PLANE

Responsibilities:

- Delete the previous dedicated `EPOLY_STACK_TEST` node when present.
- Create a fresh one-segment Plane.
- Keep it parametric.
- Select it.
- Leave the scene ready for Stage 01.

Expected incoming topology for Stage 01:

```text
4 vertices
4 edges
1 face
```

## Stage 01 — CREATE CROSS

Modifier name:

```text
01 CREATE CROSS
```

Goal:

Create a flat plus-shaped cross made from exactly five square quads.

Expected plan view:

```text
        +---+
        |   |
    +---+---+---+
    |   |   |   |
    +---+---+---+
        |   |
        +---+
```

Topology requirements:

- The original Plane quad remains the center face.
- One square face is added beyond each of its four border edges.
- Final face count must be exactly 5.
- The center face must share one edge with each of the four arm faces.
- The outer boundary remains open.
- No tessellation is allowed.

The stage must identify the original border geometry from the active `Edit_Poly` input rather than from hardcoded IDs.

### Current diagnostic issue

The first implementation used sequential native `#ExtrudeEdge` operations on the four original border edges.

Runtime feedback showed:

```text
01 FAILED | cross validation | faces:7 centerFace:0
```

Therefore the current edge-extrusion strategy is not yet considered valid.

The diagnostic logger records the face count after every extrusion plus a complete topology snapshot when validation fails. Stage 01 must be corrected and proven to produce exactly five quads before work proceeds to later stages.

## Stage 02 — MAKE OPEN BOX

Modifier name:

```text
02 MAKE OPEN BOX
```

Input:

The validated five-face cross from Stage 01.

Goal:

Fold the four arm faces upward by 90 degrees so the center quad becomes the bottom of an open box.

Expected result:

- Center quad = bottom.
- Four arm quads = vertical side walls.
- No top face.
- Vertical corner seams are geometrically coincident but intentionally unwelded.
- Each wall remains connected to the bottom along its original shared edge.
- Stage 02 operates only on topology visible to `02 MAKE OPEN BOX`.

The intentionally duplicated/coincident corner vertices are required because Stage 04 must prove that a later modifier can weld topology originating below it.

## Stage 03 — ADD LOOPS

Modifier name:

```text
03 ADD LOOPS
```

Input:

The open unwelded box produced by Stage 02.

Goal:

Create clearly visible new side-wall topology in a higher `Edit_Poly` modifier.

Current intended operation:

- Detect the vertical side edges from the current incoming geometry.
- Select the appropriate edge pairs.
- Use `#ConnectEdges`.
- Create two horizontal side-loop segments.
- Validate that both edge count and face count increase.

This is the principal proof that an upper Edit Poly modifier can create new topology on geometry that was itself created or reshaped in lower Edit Poly modifiers.

No component IDs from Stage 01 or Stage 02 may be reused blindly.

## Stage 04 — WELD RESULT

Modifier name:

```text
04 WELD RESULT
```

Input:

The box including loops created by Stage 03.

Goal:

Weld the intentionally coincident corner vertices while preserving the loops.

Requirements:

- Detect duplicate vertices by exact position.
- Re-read topology after every weld.
- Never keep stale vertex IDs after a topology-changing weld.
- Do not use an invented weld tolerance.
- Final result must be one connected open box with the Stage 03 loops preserved.

## Modifier ownership

Each stage owns exactly one modifier:

| Stage | Modifier |
| --- | --- |
| 01 | `01 CREATE CROSS` |
| 02 | `02 MAKE OPEN BOX` |
| 03 | `03 ADD LOOPS` |
| 04 | `04 WELD RESULT` |

If a stage is being executed as part of a fresh sequential test, its modifier should not already exist.

The diagnostic implementation may search for named stage modifiers, but it must never silently treat an invalid pre-existing partial stage as successful.

## Topology identity

Raw component IDs are local to the topology state being queried and must not be assumed stable across topology-changing modifier stages.

Preferred approach:

1. Activate the target `Edit_Poly`.
2. Read topology from that modifier.
3. Identify components from current geometry/topological relationships.
4. Select and modify those same current components.
5. Commit the operation.
6. Re-read topology after any operation that changes topology.

Safe identity data includes:

- current face adjacency;
- current edge endpoint vertex IDs;
- exact endpoint positions where appropriate;
- current face vertex membership;
- geometric orientation when exact and deterministic.

Unsafe design:

- caching a face/edge/vertex ID in Stage 01 and reusing it in Stage 03;
- using TriMesh face IDs as Edit Poly polygon IDs;
- assuming component numbering remains stable after connect, extrusion, or weld.

## Validation

Each stage is responsible for proving its own result.

Examples:

### Stage 01

Must prove:

```text
face count == 5
center face exists
```

### Stage 02

Must prove:

```text
four wall faces resolved
coincident unwelded corner vertices exist
```

### Stage 03

Must prove:

```text
edge count increased
face count increased
```

### Stage 04

Must prove:

```text
at least one intended duplicate pair was welded
vertex count decreases after each weld
no intended exact duplicate corner pairs remain
```

A failed stage must log failure and prevent `RUN ALL` from treating later stages as valid.

## UI

The diagnostic rollout exposes every stage independently:

```text
00 SETUP PLANE
01 CREATE CROSS
02 MAKE OPEN BOX
03 ADD LOOPS
04 WELD RESULT
RUN ALL
RESTART
```

Purpose of separate buttons:

- isolate failures;
- inspect the modifier stack after each operation;
- visually inspect topology before continuing;
- preserve useful undo boundaries.

The dialog title displays the current global project version.

## Undo behavior

Each meaningful scene-changing stage owns one named undo entry.

Expected undo order from the final state:

```text
04 Weld Result
03 Add Loops
02 Make Open Box
01 Create Cross
00 Setup Plane
```

The script never deletes the finished test object after the test completes.

## Diagnostic logging

Each script load starts a fresh log file:

```text
<module root>\logs\EPoly-Stack-Test-DUMP.txt
```

The shared `Modules/DUMP/DUMP.ms` logger is used.

The logger mirrors diagnostic lines to:

1. 3ds Max Listener
2. repository-local DUMP file

The log is truncated at the start of each new script run so the file always represents the current diagnostic session.

Important logged events include:

- script/file/project version;
- stage start;
- setup result;
- incoming topology counts;
- topology-changing operation results;
- per-operation before/after counts;
- validation failures;
- runtime exceptions;
- full topology snapshot for difficult failures;
- final pass/fail state.

The logging system is diagnostic only. Test behavior must not depend on logging being enabled.

## Error handling

Normal validation should use explicit checks rather than broad exception suppression.

When a stage encounters a real runtime exception:

- capture `getCurrentException()`;
- write the exception to the DUMP log;
- rethrow so 3ds Max still reports the real failure.

Silent `catch()` is reserved for harmless cleanup such as destroying an already-closed rollout.

## Numeric precision

This test does not introduce hidden tolerances.

Do not use:

- rounding;
- snapping;
- arbitrary epsilon values;
- approximate position equality;
- spinner precision as backend precision.

If a future operation genuinely requires a weld or position tolerance, it must become an explicit named test parameter.

## Development rule

Stage 01 is currently the active blocker.

Do not debug or redesign Stages 02–04 based on an invalid seven-face Stage 01 result.

Required progression:

```text
prove 01 CREATE CROSS
→ prove 02 MAKE OPEN BOX
→ prove 03 ADD LOOPS
→ prove 04 WELD RESULT
```

Only move forward when the previous stage produces its specified topology and validation passes.

## Versioning

`design.md` documents the architecture and does not itself increment the code/project version.

Any MaxScript code change must:

- increment the modified script's internal file version by `0.01`;
- increment the shared project version by `0.01`;
- store the new project version in the modified code file;
- keep unchanged code-file versions untouched;
- keep the UI displaying the global project version.
