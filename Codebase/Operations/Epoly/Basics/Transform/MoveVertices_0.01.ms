/*
===============================================================================
Module:         MoveVertices
File version:   0.01
Status:         STABLE
Purpose:        Reusable Edit_Poly vertex movement through Select ->
                MoveSelection -> Commit, with exact selection isolation,
                state restoration, and post-move verification.
===============================================================================
*/

global epoly_move_vertices_file_version = 0.01

/*
Returns true when the exact Edit Poly modifier instance belongs to the node.
*/
function editPolyMoveModifierBelongsToNode node_value edit_poly_mod =
(
    if not isValidNode node_value then return false
    if edit_poly_mod == undefined or classOf edit_poly_mod != Edit_Poly then return false

    local modifier_found = false

    for stack_mod in node_value.modifiers while not modifier_found do
    (
        if stack_mod == edit_poly_mod then
        (
            modifier_found = true
        )
    )

    modifier_found
    -- return
)

/*
Validates one Edit Poly vertex BitArray against the modifier topology.
Returns true only when every requested vertex ID currently exists.
*/
function validateEditPolyMoveVertexBits node_value edit_poly_mod vertex_bits =
(
    if not editPolyMoveModifierBelongsToNode node_value edit_poly_mod then return false
    if classOf vertex_bits != BitArray or vertex_bits.numberSet == 0 then return false

    local vertex_count = edit_poly_mod.GetNumVertices node:node_value
    if vertex_count < 1 then return false

    for vertex_id in vertex_bits do
    (
        if vertex_id < 1 or vertex_id > vertex_count then return false
    )

    true
    -- return
)

/*
Replaces the Edit Poly vertex selection with exactly the supplied BitArray.
Returns true only when GetSelection confirms the exact requested selection.
*/
function setExactEditPolyMoveVertexSelection node_value edit_poly_mod vertex_bits =
(
    if not editPolyMoveModifierBelongsToNode node_value edit_poly_mod then return false
    if classOf vertex_bits != BitArray then return false

    local current_vertices = edit_poly_mod.GetSelection #Vertex node:node_value
    if current_vertices == undefined then return false

    if current_vertices.numberSet > 0 then
    (
        edit_poly_mod.Select #Vertex current_vertices select:false node:node_value
    )

    if vertex_bits.numberSet > 0 then
    (
        edit_poly_mod.Select #Vertex vertex_bits node:node_value
    )

    local stored_vertices = edit_poly_mod.GetSelection #Vertex node:node_value
    stored_vertices != undefined and stored_vertices == vertex_bits
    -- return
)

/*
Restores the Edit Poly state changed by the move operation.
Returns true only when the original vertex selection was restored exactly.
*/
function restoreEditPolyMoveState node_value edit_poly_mod original_primary_node original_level original_use_stack_selection original_select_mode original_selection =
(
    local selection_restored = setExactEditPolyMoveVertexSelection node_value edit_poly_mod original_selection

    edit_poly_mod.useStackSelection = original_use_stack_selection
    edit_poly_mod.selectMode = original_select_mode

    if original_level != undefined then
    (
        edit_poly_mod.SetEPolySelLevel original_level
    )

    if original_primary_node != undefined and isValidNode original_primary_node then
    (
        edit_poly_mod.SetPrimaryNode original_primary_node
    )

    selection_restored
    -- return
)

/*
Moves all supplied Edit Poly vertices by one shared object-space delta.
Returns false only for invalid input before geometry is changed.
Unexpected native/verification/restoration failures throw after state cleanup.
*/
function moveEditPolyVertices node_value edit_poly_mod vertex_bits move_delta refresh:true =
(
    if not validateEditPolyMoveVertexBits node_value edit_poly_mod vertex_bits then return false
    if classOf move_delta != Point3 then return false
    if edit_poly_mod.currentOperation != 0 then return false

    local original_primary_node = edit_poly_mod.GetPrimaryNode()
    local original_level = edit_poly_mod.GetEPolySelLevel()
    local original_use_stack_selection = edit_poly_mod.useStackSelection
    local original_select_mode = edit_poly_mod.selectMode
    local original_selection = edit_poly_mod.GetSelection #Vertex node:node_value

    if original_selection == undefined then return false
    original_selection = copy original_selection

    local original_positions = #()

    for vertex_id in vertex_bits do
    (
        append original_positions #(vertex_id, edit_poly_mod.GetVertex vertex_id node:node_value)
    )

    local operation_exception = undefined
    local operation_succeeded = false

    try
    (
        edit_poly_mod.SetPrimaryNode node_value
        edit_poly_mod.useStackSelection = false
        edit_poly_mod.selectMode = 0
        edit_poly_mod.showCage = off
        edit_poly_mod.SetEPolySelLevel #Vertex

        if not setExactEditPolyMoveVertexSelection node_value edit_poly_mod vertex_bits then
        (
            throw "moveEditPolyVertices: could not isolate the requested vertex selection."
        )

        edit_poly_mod.MoveSelection move_delta
        edit_poly_mod.Commit()

        for position_record in original_positions do
        (
            local vertex_id = position_record[1]
            local expected_position = position_record[2] + move_delta
            local actual_position = edit_poly_mod.GetVertex vertex_id node:node_value

            if actual_position != expected_position then
            (
                throw ("moveEditPolyVertices: move verification failed for vertex " + (vertex_id as string) + ".")
            )
        )

        operation_succeeded = true
    )
    catch
    (
        operation_exception = getCurrentException()
    )

    local restore_succeeded = false
    local restore_exception = undefined

    try
    (
        restore_succeeded = restoreEditPolyMoveState \
            node_value \
            edit_poly_mod \
            original_primary_node \
            original_level \
            original_use_stack_selection \
            original_select_mode \
            original_selection
    )
    catch
    (
        restore_exception = getCurrentException()
    )

    local refresh_exception = undefined

    if refresh then
    (
        try
        (
            edit_poly_mod.RefreshScreen()
        )
        catch
        (
            refresh_exception = getCurrentException()
        )
    )

    if operation_exception != undefined then
    (
        if restore_exception != undefined then
        (
            format "moveEditPolyVertices RESTORE ERROR: %\n" restore_exception
        )

        if refresh_exception != undefined then
        (
            format "moveEditPolyVertices REFRESH ERROR: %\n" refresh_exception
        )

        format "moveEditPolyVertices ERROR: %\n" operation_exception
        throw operation_exception
    )

    if restore_exception != undefined then
    (
        format "moveEditPolyVertices RESTORE ERROR: %\n" restore_exception
        throw restore_exception
    )

    if not restore_succeeded then
    (
        throw "moveEditPolyVertices: vertex movement completed but the original vertex selection could not be restored."
    )

    if refresh_exception != undefined then
    (
        format "moveEditPolyVertices REFRESH ERROR: %\n" refresh_exception
        throw refresh_exception
    )

    operation_succeeded
    -- return
)

/*
Moves vertices through one Edit Poly modifier using individual per-vertex deltas.
move_records must contain #(vertex_id, point3_delta) pairs with unique vertex IDs.
Returns false only for invalid input before geometry is changed.
Unexpected native/verification/restoration failures throw after state cleanup.
*/
function moveEditPolyVerticesByRecords node_value edit_poly_mod move_records refresh:true =
(
    if not editPolyMoveModifierBelongsToNode node_value edit_poly_mod then return false
    if classOf move_records != Array or move_records.count == 0 then return false
    if edit_poly_mod.currentOperation != 0 then return false

    local vertex_count = edit_poly_mod.GetNumVertices node:node_value
    if vertex_count < 1 then return false

    local seen_vertices = #{}
    local validated_records = #()

    for move_record in move_records do
    (
        if classOf move_record != Array or move_record.count != 2 then return false

        local vertex_id = move_record[1]
        local move_delta = move_record[2]

        if classOf vertex_id != Integer then return false
        if vertex_id < 1 or vertex_id > vertex_count then return false
        if classOf move_delta != Point3 then return false
        if seen_vertices[vertex_id] then return false

        seen_vertices[vertex_id] = true
        append validated_records #(vertex_id, edit_poly_mod.GetVertex vertex_id node:node_value, move_delta)
    )

    local original_primary_node = edit_poly_mod.GetPrimaryNode()
    local original_level = edit_poly_mod.GetEPolySelLevel()
    local original_use_stack_selection = edit_poly_mod.useStackSelection
    local original_select_mode = edit_poly_mod.selectMode
    local original_selection = edit_poly_mod.GetSelection #Vertex node:node_value

    if original_selection == undefined then return false
    original_selection = copy original_selection

    local operation_exception = undefined
    local operation_succeeded = false

    try
    (
        edit_poly_mod.SetPrimaryNode node_value
        edit_poly_mod.useStackSelection = false
        edit_poly_mod.selectMode = 0
        edit_poly_mod.showCage = off
        edit_poly_mod.SetEPolySelLevel #Vertex

        if not setExactEditPolyMoveVertexSelection node_value edit_poly_mod #{} then
        (
            throw "moveEditPolyVerticesByRecords: could not clear the current vertex selection."
        )

        for move_record in validated_records do
        (
            local vertex_id = move_record[1]
            local original_position = move_record[2]
            local move_delta = move_record[3]
            local vertex_bits = #{}
            vertex_bits[vertex_id] = true

            if not setExactEditPolyMoveVertexSelection node_value edit_poly_mod vertex_bits then
            (
                throw ("moveEditPolyVerticesByRecords: could not isolate vertex " + (vertex_id as string) + ".")
            )

            edit_poly_mod.MoveSelection move_delta
            edit_poly_mod.Commit()

            local expected_position = original_position + move_delta
            local actual_position = edit_poly_mod.GetVertex vertex_id node:node_value

            if actual_position != expected_position then
            (
                throw ("moveEditPolyVerticesByRecords: move verification failed for vertex " + (vertex_id as string) + ".")
            )
        )

        operation_succeeded = true
    )
    catch
    (
        operation_exception = getCurrentException()
    )

    local restore_succeeded = false
    local restore_exception = undefined

    try
    (
        restore_succeeded = restoreEditPolyMoveState \
            node_value \
            edit_poly_mod \
            original_primary_node \
            original_level \
            original_use_stack_selection \
            original_select_mode \
            original_selection
    )
    catch
    (
        restore_exception = getCurrentException()
    )

    local refresh_exception = undefined

    if refresh then
    (
        try
        (
            edit_poly_mod.RefreshScreen()
        )
        catch
        (
            refresh_exception = getCurrentException()
        )
    )

    if operation_exception != undefined then
    (
        if restore_exception != undefined then
        (
            format "moveEditPolyVerticesByRecords RESTORE ERROR: %\n" restore_exception
        )

        if refresh_exception != undefined then
        (
            format "moveEditPolyVerticesByRecords REFRESH ERROR: %\n" refresh_exception
        )

        format "moveEditPolyVerticesByRecords ERROR: %\n" operation_exception
        throw operation_exception
    )

    if restore_exception != undefined then
    (
        format "moveEditPolyVerticesByRecords RESTORE ERROR: %\n" restore_exception
        throw restore_exception
    )

    if not restore_succeeded then
    (
        throw "moveEditPolyVerticesByRecords: vertex movement completed but the original vertex selection could not be restored."
    )

    if refresh_exception != undefined then
    (
        format "moveEditPolyVerticesByRecords REFRESH ERROR: %\n" refresh_exception
        throw refresh_exception
    )

    operation_succeeded
    -- return
)
