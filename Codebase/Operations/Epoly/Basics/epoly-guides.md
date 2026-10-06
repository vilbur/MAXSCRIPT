# Epoly Guides

`Epoly` is the shared project term for both:

- an `Editable_Poly` base object;
- an `Edit_Poly` modifier.

Use the rules in this file whenever a MaxScript tool reads, modifies, or selects Epoly sub-objects.

## Core principle

Editable Poly base objects and Edit Poly modifiers use different selection APIs.

Do not mix them unless there is a specific, justified reason.

For an `Editable_Poly` base object, use `polyop`:

```maxscript
polyop.setVertSelection obj vertex_bits
polyop.setEdgeSelection obj edge_bits
polyop.setFaceSelection obj face_bits
```

For an `Edit_Poly` modifier, use the modifier selection API:

```maxscript
modifier.Select #Vertex vertex_bits
modifier.Select #Edge edge_bits
modifier.Select #Face face_bits
```

When the goal is an interactive tool where LMB must visibly select components in the Modify panel, prefer `.Select`.

Do not rely on `SetSelection` as the primary interactive selection mechanism.


## Setting sub-object selection

Selection data and visible sub-object UI state are separate concerns.

Prefer setting selection through code without changing the Modify panel whenever visible interactive selection is not required.

### Editable_Poly base object

For an `Editable_Poly` base object, write component selection with `polyop`:

```maxscript
polyop.setVertSelection node vertex_bits
polyop.setEdgeSelection node edge_bits
polyop.setFaceSelection node face_bits
```

Do not enter Modify mode or sub-object mode merely to store selection data.

Only when the selection must be visibly shown to the user, select the node, enter Modify mode, and set the matching global sub-object level:

```maxscript
select node
max modify mode
```

Vertex:

```maxscript
subObjectLevel = 1
```

Edge:

```maxscript
subObjectLevel = 2
```

Face / Polygon:

```maxscript
subObjectLevel = 4
```

The actual selection still comes from `polyop.set...Selection`; `subObjectLevel` only controls the active visible component level.

Do not reselect the node afterward unless required, because reselection can disturb the current sub-object state.

### Edit_Poly modifier

For an `Edit_Poly` modifier, use the modifier selection API, not `polyop`:

```maxscript
modifier.Select #Vertex vertex_bits
modifier.Select #Edge edge_bits
modifier.Select #Face face_bits
```

For visible interactive selection, prepare the modifier once:

```maxscript
select node
max modify mode

modifier.SetPrimaryNode node
modifier.useStackSelection = false
modifier.selectMode = 0

modPanel.setCurrentObject modifier node:node
```

Then set the matching Edit Poly level and global sub-object level directly.

Vertex:

```maxscript
modifier.SetEPolySelLevel #Vertex
subObjectLevel = 1
```

Edge:

```maxscript
modifier.SetEPolySelLevel #Edge
subObjectLevel = 2
```

Face / Polygon:

```maxscript
modifier.SetEPolySelLevel #Face
subObjectLevel = 4
```

Then write the selection with `.Select` and refresh only when visible feedback is required:

```maxscript
modifier.Select #Face face_bits
modifier.RefreshScreen()
completeRedraw()
```

Do not use `selectMode = 1` to enter a component level.

Do not use `polyop.set...Selection` to write selection into an `Edit_Poly` modifier.

Do not call `modPanel.setCurrentObject`, reselect the node, or reselect the same modifier repeatedly when the correct state is already active.

### Direct level switching

When changing component level, switch directly to the next required level.

Example:

```maxscript
subObjectLevel = 2
subObjectLevel = 4
```

Do not unnecessarily pass through:

```maxscript
subObjectLevel = 0
```

Batch operations at the same component level before changing to another level.

## Edit Poly modifier — required sequence

Before selecting components in an Edit Poly modifier:

```maxscript
select node
max modify mode

modifier.SetPrimaryNode node
modifier.useStackSelection = false
modifier.selectMode = 0

modPanel.setCurrentObject modifier node:node
```

Then activate the required sub-object level.

Vertex:

```maxscript
modifier.SetEPolySelLevel #Vertex
subObjectLevel = 1
```

Edge:

```maxscript
modifier.SetEPolySelLevel #Edge
subObjectLevel = 2
```

Face / Polygon:

```maxscript
modifier.SetEPolySelLevel #Face
subObjectLevel = 4
```

Then select directly:

```maxscript
modifier.Select #Vertex vertex_bits
modifier.Select #Edge edge_bits
modifier.Select #Face face_bits
```

Always finish interactive selection with:

```maxscript
modifier.RefreshScreen()
completeRedraw()
```

## selectMode rule

Always use:

```maxscript
modifier.selectMode = 0
```

Never use:

```maxscript
modifier.selectMode = 1
```

Do not use `selectMode` to enter Vertex / Edge / Face mode.

Use:

```maxscript
modifier.SetEPolySelLevel ...
subObjectLevel = ...
```

instead.

## Stack selection rule

For tool-owned Edit Poly modifiers, use:

```maxscript
modifier.useStackSelection = false
```

This ensures the modifier uses its own local stored selection instead of depending on selection coming from lower in the modifier stack.

## Clearing existing selection

If a modifier is newly created, do not add unnecessary clearing logic.

Just select directly:

```maxscript
modifier.Select #Face face_bits
```

If an existing tool modifier is reused, clear only the relevant existing selection:

```maxscript
old_faces = modifier.GetSelection #Face

if old_faces.numberSet > 0 then
(
    modifier.Select #Face old_faces select:false
)

modifier.Select #Face new_faces
```

Equivalent pattern for vertices:

```maxscript
old_vertices = modifier.GetSelection #Vertex

if old_vertices.numberSet > 0 then
(
    modifier.Select #Vertex old_vertices select:false
)

modifier.Select #Vertex new_vertices
```

Equivalent pattern for edges:

```maxscript
old_edges = modifier.GetSelection #Edge

if old_edges.numberSet > 0 then
(
    modifier.Select #Edge old_edges select:false
)

modifier.Select #Edge new_edges
```

## Do not mix selection systems

Avoid sequences like:

```maxscript
modifier.SetSelection #Face #{}
modifier.Select #Face face_bits
modifier.SetSelection #Face face_bits
```

Do not mix multiple APIs without a concrete reason.

For an interactive Edit Poly tool, the default selection path should simply be:

```text
activate modifier
→ set sub-object level
→ modifier.Select ...
→ refresh
```

## Topology identity rule

Never assume vertex, edge, or face IDs from one topology representation are valid in another.

Unsafe example:

```text
analyze temporary collapsed mesh
→ detect face 17
→ select face 17 in Edit Poly
```

This is unsafe because topology IDs may differ between:

- Editable Poly base object;
- Edit Poly modifier;
- evaluated modifier stack;
- temporary copied object;
- collapsed object;
- Mesh / TriMesh;
- polygon topology;
- triangulated topology.

Whenever possible, analyze the exact same topology that will receive the selection.

Preferred architecture:

```text
activate target Edit Poly modifier
→ read topology from that modifier
→ detect component IDs
→ select those same component IDs on that modifier
```

If analysis must use another representation, map geometry back explicitly.

Do not blindly transfer component indices.

## Edge identity rule

For edges, avoid treating raw edge index as persistent identity.

A safer edge identity is the unordered pair of its endpoint vertices:

```text
(vertexA, vertexB)
```

or, if vertex IDs may differ:

```text
(endpointPositionA, endpointPositionB)
```

Then resolve the actual current Editable Poly edge that connects those endpoints.

Use the resulting current edge index only as the final local execution handle.

Do not trust TriMesh edge IDs because triangulation can introduce hidden/invisible diagonal edges and different numbering.

## Face identity rule

For faces, do not transfer a face index from a temporary or collapsed representation into an Edit Poly modifier unless topology correspondence is explicitly verified.

Remember that `$.mesh` is a `TriMesh`. Its face indices refer to triangles, not Editable Poly polygon faces. A single Epoly polygon may be represented by multiple TriMesh triangle faces, so `$.mesh` face IDs do not match Epoly face IDs and must never be copied directly into `polyop` or Edit Poly face selection.

Unsafe example:

```maxscript
tri_face_id = 17 -- from $.mesh
modifier.Select #Face #{tri_face_id}
```

Do not assume that triangle 17 in `$.mesh` corresponds to polygon 17 in Editable Poly / Edit Poly.

Prefer detecting directly on the target Edit Poly modifier or Editable Poly polygon topology.

If TriMesh analysis is unavoidable, map the result back by geometry, such as polygon vertex membership, triangle vertices, positions, or another explicitly verified correspondence.

If mapping is required, identify the face by its polygon vertex set / geometry and resolve the current target face before selection.

## Editable Poly base object rule

For base Editable Poly selection, use only `polyop` selection functions:

```maxscript
polyop.setVertSelection poly vertex_bits
polyop.setEdgeSelection poly edge_bits
polyop.setFaceSelection poly face_bits
```

Do not try to use Edit Poly modifier `.Select` methods on the base object.

## Edit Poly modifier rule

For Edit Poly modifier selection, use:

```maxscript
modifier.Select #Vertex bits
modifier.Select #Edge bits
modifier.Select #Face bits
```

Do not use `polyop.set...Selection` to try to modify the modifier's local selection.

## LMB behavior rule

When a UI button LMB means “find and select”:

1. Detect components.
2. Acquire or create the correct Edit Poly modifier.
3. Select the node.
4. Enter Modify mode.
5. Make the modifier current.
6. Set `selectMode = 0`.
7. Set `useStackSelection = false`.
8. Enter the correct sub-object level.
9. Call `.Select`.
10. Refresh and redraw.
11. Do not reselect the object afterward in a way that exits sub-object mode or changes the current modifier.

Do not perform object reselection after successful component selection unless absolutely necessary.

## Multi-object rule

If processing multiple objects:

- analyze them independently;
- store results independently;
- do not constantly switch the Modify panel inside inner topology loops;
- only activate the Modify panel when necessary for final visible selection;
- after processing, avoid operations that destroy the active sub-object state.

If the final UI is meant to show one object's component selection, activate that object/modifier only at the end.

If the goal is only batch processing, do not unnecessarily manipulate the Modify panel for every component.

## Detection vs UI rule

Detection logic and visible-selection logic are separate problems.

If the listener says:

```text
found faces: #{6}
```

but nothing is visibly selected, do not change detection.

Debug only:

- target modifier;
- current Modify panel object;
- `SetEPolySelLevel`;
- `subObjectLevel`;
- `.Select`;
- stored selection;
- screen refresh.

Do not rewrite working geometry detection just because the visible selection failed.

## Debug verification

During development, immediately verify selection after writing it.

Example:

```maxscript
modifier.Select #Face face_bits

stored_faces = modifier.GetSelection #Face

format "requested:% stored:%\n" face_bits stored_faces
```

For edges:

```maxscript
modifier.Select #Edge edge_bits
stored_edges = modifier.GetSelection #Edge
```

For vertices:

```maxscript
modifier.Select #Vertex vertex_bits
stored_vertices = modifier.GetSelection #Vertex
```

A successful interactive selection requires both:

1. `GetSelection` returns the expected BitArray.
2. The components are visibly selected in the active Edit Poly modifier.

Do not consider only one of those conditions sufficient.

## Reusable face selection helper

Use this pattern:

```maxscript
/*
Activates one Edit Poly modifier and visibly selects the supplied faces.
The modifier remains in selectMode 0.
*/
function selectEditPolyFaces node modifier face_bits =
(
    if node == undefined or modifier == undefined then return false
    if classOf modifier != Edit_Poly then return false

    select node
    max modify mode

    modifier.SetPrimaryNode node
    modifier.useStackSelection = false
    modifier.selectMode = 0

    modPanel.setCurrentObject modifier node:node

    modifier.SetEPolySelLevel #Face
    subObjectLevel = 4

    old_faces = modifier.GetSelection #Face

    if old_faces.numberSet > 0 then
    (
        modifier.Select #Face old_faces select:false
    )

    modifier.Select #Face face_bits

    modifier.RefreshScreen()
    completeRedraw()

    true
)
```

## Reusable edge selection helper

```maxscript
/*
Activates one Edit Poly modifier and visibly selects the supplied edges.
The modifier remains in selectMode 0.
*/
function selectEditPolyEdges node modifier edge_bits =
(
    if node == undefined or modifier == undefined then return false
    if classOf modifier != Edit_Poly then return false

    select node
    max modify mode

    modifier.SetPrimaryNode node
    modifier.useStackSelection = false
    modifier.selectMode = 0

    modPanel.setCurrentObject modifier node:node

    modifier.SetEPolySelLevel #Edge
    subObjectLevel = 2

    old_edges = modifier.GetSelection #Edge

    if old_edges.numberSet > 0 then
    (
        modifier.Select #Edge old_edges select:false
    )

    modifier.Select #Edge edge_bits

    modifier.RefreshScreen()
    completeRedraw()

    true
)
```

## Reusable vertex selection helper

```maxscript
/*
Activates one Edit Poly modifier and visibly selects the supplied vertices.
The modifier remains in selectMode 0.
*/
function selectEditPolyVertices node modifier vertex_bits =
(
    if node == undefined or modifier == undefined then return false
    if classOf modifier != Edit_Poly then return false

    select node
    max modify mode

    modifier.SetPrimaryNode node
    modifier.useStackSelection = false
    modifier.selectMode = 0

    modPanel.setCurrentObject modifier node:node

    modifier.SetEPolySelLevel #Vertex
    subObjectLevel = 1

    old_vertices = modifier.GetSelection #Vertex

    if old_vertices.numberSet > 0 then
    (
        modifier.Select #Vertex old_vertices select:false
    )

    modifier.Select #Vertex vertex_bits

    modifier.RefreshScreen()
    completeRedraw()

    true
)
```

## Modify panel optimization

Minimize use of the Modify panel and Command Panel UI state as much as possible.

- Prefer direct API operations when the Modify panel is not required.
- Enter Modify mode only when an operation genuinely requires the active Edit Poly modifier or visible interactive sub-object selection.
- If Modify mode is not required, prefer leaving the Create panel visible while the script is running.
- Do not switch repeatedly between Create and Modify panels during batch processing.
- Do not call `modPanel.setCurrentObject` repeatedly when the required modifier is already current.
- Do not reselect the same modifier in the stack when it is already active.
- Keep a required modifier current for a whole batch of related operations instead of bouncing between modifiers.

## Sub-object batching

Minimize sub-object level changes.

If several operations use the same sub-object level, perform them together before changing level.

If the next required operation uses another sub-object level, switch directly to that level.

For example, when moving from Edge to Face / Polygon:

```text
Edge: subObjectLevel = 2
→ Face / Polygon: subObjectLevel = 4
```

Do not unnecessarily pass through:

```text
subObjectLevel = 0
```

Avoid leaving sub-object mode between consecutive sub-object operations unless object level is actually required.

## Modifier stack batching

When multiple operations target the same Edit Poly modifier:

- acquire the modifier once;
- make it current only if necessary;
- keep it active through the related operations;
- avoid repeated stack searches inside inner loops;
- avoid repeated `SetPrimaryNode`, `setCurrentObject`, and object reselection when the current state is already correct.

Prefer direct modifier API calls over Command Panel interaction whenever the API supports the required operation.

## Viewport redraw optimization

For larger batch operations, minimize viewport redraw work.

When safe and appropriate:

```maxscript
disableSceneRedraw()
```

Run the batch operation, then restore redraw with:

```maxscript
enableSceneRedraw()
completeRedraw()
```

Do not disable and re-enable redraw repeatedly inside inner loops.

Disable redraw once around the batch and always ensure it is enabled again even if the operation fails.

Do not use redraw suppression when the operation depends on interactive viewport feedback.

## Final rule summary

Always follow these rules:

1. Editable Poly base object → use `polyop.set...Selection`.
2. Edit Poly modifier → activate modifier and use `.Select`.
3. Always use `selectMode = 0`.
4. Use `SetEPolySelLevel` + `subObjectLevel` for component level.
5. Use `useStackSelection = false` for tool-owned local modifier selection.
6. Do not mix `polyop`, `SetSelection`, `.Select`, and stack selection without a specific reason.
7. Never blindly transfer sub-object IDs between different topology representations.
8. For edges, prefer endpoint identity over raw edge index.
9. For faces, analyze the same modifier topology whenever possible. Never treat `$.mesh` TriMesh triangle face IDs as Epoly polygon face IDs.
10. Detection success and visible-selection success are separate concerns.
11. During debugging, verify with `GetSelection`.
12. A UI LMB “select” action is successful only when the expected components are both stored and visibly selected.
13. Never use `selectMode = 1`.
14. Do not reselect the object after successful sub-object selection if that may disturb the active Modify-panel state.
15. Keep the final selection operation simple: activate → level → `.Select` → refresh.
16. Minimize Modify panel usage when direct API access is sufficient.
17. Keep the Create panel visible when Modify mode is not required.
18. Batch work at the same sub-object level and switch directly between required levels.
19. Do not reselect an already-active modifier in the stack.
20. Batch operations on the same modifier before switching elsewhere.
21. Minimize viewport redraws during non-interactive batch work.
