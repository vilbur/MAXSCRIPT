/*
Edit Poly vertex functions. Version 0.01.
Depends on EpolyCore.ms and EpolySelection.ms.
*/

/*
Reads one vertex position from the exact modifier's evaluated topology.
*/
function epolyGetVertexPosition node_value edit_poly_mod vertex_id =
(
    local position_value = undefined
    if epolyHasContext node_value edit_poly_mod then position_value = edit_poly_mod.GetVertex vertex_id node:node_value
    position_value
    -- return
)

/*
Moves all supplied vertices by a shared local/object-space delta in one batch.
The previous vertex selection is restored; no per-vertex reads or redraws.
*/
function epolyMoveVertices node_value edit_poly_mod vertex_bits delta =
(
    local operation_ok = epolyHasContext node_value edit_poly_mod
    if operation_ok then
    (
        local previous_bits = edit_poly_mod.GetSelection #Vertex node:node_value
        edit_poly_mod.SetEPolySelLevel #Vertex
        operation_ok = edit_poly_mod.SetSelection #Vertex vertex_bits node:node_value
        if operation_ok then
        (
            edit_poly_mod.MoveSelection delta
            edit_poly_mod.Commit()
            edit_poly_mod.SetSelection #Vertex previous_bits node:node_value
        )
    )
    if not operation_ok then format "EPOLY MOVE FAILED | node:% | vertices:% | delta:%\n" node_value vertex_bits delta
    operation_ok
    -- return
)

/*
Moves one existing vertex to a specified modifier-local Point3 position.
No redundant post-move coordinate verification is performed.
*/
function epolySetVertexPosition node_value edit_poly_mod vertex_id target_position =
(
    local operation_ok = epolyHasContext node_value edit_poly_mod
    if operation_ok then
    (
        local current_position = edit_poly_mod.GetVertex vertex_id node:node_value
        operation_ok = epolyMoveVertices node_value edit_poly_mod (epolySingleBit vertex_id) (target_position - current_position)
    )
    operation_ok
    -- return
)

/*
Removes selected vertices with the native Remove Vertex operation.
*/
function epolyRemoveVertices node_value edit_poly_mod vertex_bits =
(
    epolyRunBatch node_value edit_poly_mod #Vertex vertex_bits #RemoveVertex
    -- return
)

/*
Deletes selected vertices and their connected geometry.
*/
function epolyDeleteVertices node_value edit_poly_mod vertex_bits =
(
    epolyRunBatch node_value edit_poly_mod #Vertex vertex_bits #DeleteVertex
    -- return
)

/*
Welds all supplied vertices using the modifier's native threshold operation.
The threshold is passed in explicitly and remains in system units.
*/
function epolyWeldVertices node_value edit_poly_mod vertex_bits threshold_value =
(
    local operation_ok = epolyHasContext node_value edit_poly_mod
    if operation_ok then
    (
        edit_poly_mod.weldVertexThreshold = threshold_value
        operation_ok = epolyRunBatch node_value edit_poly_mod #Vertex vertex_bits #WeldVertex
    )
    operation_ok
    -- return
)

/*
Moves the source vertex to the target position and welds the explicit pair.
Does not use a proximity-only weld selection, which could merge other vertices.
*/
function epolyTargetWeld node_value edit_poly_mod source_id target_id =
(
    local operation_ok = epolyHasContext node_value edit_poly_mod
    if operation_ok then
    (
        local target_position = edit_poly_mod.GetVertex target_id node:node_value
        local source_position = edit_poly_mod.GetVertex source_id node:node_value
        edit_poly_mod.SetEPolySelLevel #Vertex
        operation_ok = edit_poly_mod.SetSelection #Vertex (epolySingleBit source_id) node:node_value
        if operation_ok then
        (
            edit_poly_mod.MoveSelection (target_position - source_position)
            edit_poly_mod.Commit()
            edit_poly_mod.WeldVertices source_id target_id node:node_value
            edit_poly_mod.Commit()
        )
    )
    operation_ok
    -- return
)

/*
Moves every source in the requested (source,target) pairs first, then welds pairs.
Pairs must be disjoint and indices stable until the batch is finished; no dead-structure collapse.
*/
function epolyTargetWeldBatch node_value edit_poly_mod pair_records =
(
    local operation_ok = epolyHasContext node_value edit_poly_mod
    if operation_ok then
    (
        local previous_bits = edit_poly_mod.GetSelection #Vertex node:node_value
        edit_poly_mod.SetEPolySelLevel #Vertex
        for pair_data in pair_records do
        (
            local source_id = pair_data[1]
            local target_id = pair_data[2]
            local position_delta = (edit_poly_mod.GetVertex target_id node:node_value) - (edit_poly_mod.GetVertex source_id node:node_value)
            edit_poly_mod.SetSelection #Vertex (epolySingleBit source_id) node:node_value
            edit_poly_mod.MoveSelection position_delta
            edit_poly_mod.Commit()
        )
        for pair_data in pair_records do
        (
            edit_poly_mod.WeldVertices pair_data[1] pair_data[2] node:node_value
        )
        edit_poly_mod.Commit()
        edit_poly_mod.SetSelection #Vertex previous_bits node:node_value
    )
    operation_ok
    -- return
)

/*
Collapses the specified vertex selection through one native operation.
*/
function epolyCollapseVertices node_value edit_poly_mod vertex_bits =
(
    epolyRunBatch node_value edit_poly_mod #Vertex vertex_bits #CollapseVertex
    -- return
)
