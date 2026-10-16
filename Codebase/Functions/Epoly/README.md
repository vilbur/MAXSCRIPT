# Epoly shared functions — first development version 0.01

Source root: `Codebase/Functions/Epoly/`. These are reusable MAXScript functions, not UI tools.

## Files and load order

1. `EpolyCore.ms` — context and batch selection-operation helpers
2. `EpolySelection.ms` — 5 selection functions
3. `EpolyVertices.ms` — 9 vertex functions
4. `EpolyEdges.ms` — 6 edge functions
5. `EpolyFaces.ms` — 5 polygon functions
6. `EpolyTopology.ms` — 3 topology functions
7. `EpolyCut.ms` — 6 construction/cut functions
8. `test/test.ms` — one test UI, physically beside the library

Total: **34 requested public functions** (plus 3 shared support functions). The names use an `epoly` prefix to avoid clashes with MAXScript native names. This is a **development baseline**, not a verified 3ds Max release.

## Design

Use one node and its existing exact `Edit_Poly` modifier. The caller owns the working context and Undo boundary. The functions do not repeatedly select objects, activate the command panel, switch the modifier stack, or redraw the viewport. Use explicit BitArrays and batch native operations. A topology-changing function invalidates stale downstream component IDs; retrieve current IDs before starting another ID-dependent phase. Do not collapse the underlying `Editable_Poly` below a modifier.

For `epolyTargetWeldBatch`, the caller supplies `#( #(source_id, target_id), ... )` with **independent, disjoint pairs** and stable IDs throughout that batch; move all sources first, then native pair welds, without collapsing dead topology inside the batch. This is deliberately not a broad threshold weld. Do not call it with overlapping pairs or when previous individual welds have already reindexed the mesh.

`epolyGetBorderLoops` initially returns connected open-border **Edge BitArrays** rather than guaranteed ordered cyclic walks. This matters for branched/nonmanifold open boundaries; an ordering mode can be added separately if needed.

The six new cut/build functions are: `epolyCreateVertex`, `epolyDivideEdge`, `epolyDivideFace`, `epolyCreateEdge`, `epolyCutVertexToEdge`, and `epolyCutEdgeToEdge`. Direct vertex-to-vertex cut is covered by `epolyCreateEdge`. Cut methods expect valid existing IDs, legal same-face connectivity and object-space parameters. Errors from native methods are deliberately not swallowed.

### Important API notes

- `Edit_Poly.GetVertex` returns the modifier's vertex coordinate; `MoveSelection` uses a Point3 delta.
- `SetSelection` stores selection without forcing visible viewport interaction; interactive visible selection is a separate UI responsibility.
- `ButtonOp`-based functions call the corresponding documented Edit Poly operation and commit once for the batch.
- All lengths/distances are current Max scene system units. No hidden unit conversion, rounding or tolerance.
- `epolySetVertexPosition` moves one vertex, then returns. It does **not** read it again to verify its position.

## Testing

Open `test/test.ms`. It creates its own small named fixture for testing, with a new `Edit_Poly` modifier. Run an individual scenario with the shared UI. Tests print `PASS`, `FAIL` or `ERROR` only from observed results. Geometry effects can be inspected and undone. There is intentionally no per-vertex post-operation check in production functions.

**Runtime execution in 3ds Max has not been performed in this environment.** Native behavior (especially compound cut, weld, and any ButtonOp requiring active Modify context) must be confirmed in the test UI before promoting these functions to stable status.

Autodesk MAXScript Edit_Poly API reference: https://help.autodesk.com/cloudhelp/2026/ENU/MAXScript-Help/files/3ds-Max-Objects-and-Interfaces/Modifier-MAXWrapper-and/Modifier-and-SpacewarpModifier/Modifiers/Mesh-Editing/GUID-9CA2E6DA-08C2-4279-87C9-B64351C0147E.html
