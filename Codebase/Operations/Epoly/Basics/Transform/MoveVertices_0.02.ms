/*
===============================================================================
Module:         MoveVertices
File version:   0.02
Status:         DEVELOPMENT
Purpose:        Reusable Edit_Poly vertex movement through Select ->
                MoveSelection -> Commit, plus repeated DivideEdge -> Commit
                insertion with explicit position precision and ordered targets.
===============================================================================
*/

global epoly_move_vertices_file_version = 0.02


/*
Resolves one canonical millimeter position-precision label to current scene/system units.
Returns undefined for unsupported labels instead of inventing a fallback precision.
*/
function resolveEditPolyMovePositionPrecision position_precision_text =
(
    case position_precision_text of
    (
        "1mm": (units.decodeValue "1mm")
        "0.1mm": (units.decodeValue "0.1mm")
        "0.01mm": (units.decodeValue "0.01mm")
        default:
        (
            format "MoveVertices POSITION PRECISION ERROR | supplied:% | expected:#(\"1mm\", \"0.1mm\", \"0.01mm\")\n" position_precision_text
            undefined
        )
    )
    -- return
)

/*
Rounds one temporary Point3 copy to the explicit position precision.
The rounded value is comparison-only and is never written back to scene geometry.
*/
function roundEditPolyMovePosition position_value position_precision =
(
    if position_value == undefined or classOf position_value != Point3 then return undefined
    if position_precision == undefined or position_precision <= 0.0 then return undefined

    [
        (round (position_value.x / position_precision)) * position_precision,
        (round (position_value.y / position_precision)) * position_precision,
        (round (position_value.z / position_precision)) * position_precision
    ]
    -- return
)

/*
Compares two Point3 values through the explicit position-precision contract.
Returns false when either position or the supplied precision is invalid.
*/
function editPolyMovePositionsMatch position_a position_b position_precision =
(
    local rounded_a = roundEditPolyMovePosition position_a position_precision
    local rounded_b = roundEditPolyMovePosition position_b position_precision

    if rounded_a == undefined or rounded_b == undefined then return false

    rounded_a == rounded_b
    -- return
)

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
function moveEditPolyVertices node_value edit_poly_mod vertex_bits move_delta position_precision_text refresh:true =
(
    if not validateEditPolyMoveVertexBits node_value edit_poly_mod vertex_bits then return false
    if classOf move_delta != Point3 then return false
    if edit_poly_mod.currentOperation != 0 then return false

    local position_precision = resolveEditPolyMovePositionPrecision position_precision_text
    if position_precision == undefined then return false

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

            if not editPolyMovePositionsMatch actual_position expected_position position_precision then
            (
                local rounded_expected = roundEditPolyMovePosition expected_position position_precision
                local rounded_actual = roundEditPolyMovePosition actual_position position_precision
                format "moveEditPolyVertices MOVE VERIFY ERROR | vertex:% | expectedRaw:% | actualRaw:% | expectedRounded:% | actualRounded:% | precision:%\n" vertex_id expected_position actual_position rounded_expected rounded_actual position_precision_text
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
function moveEditPolyVerticesByRecords node_value edit_poly_mod move_records position_precision_text refresh:true =
(
    if not editPolyMoveModifierBelongsToNode node_value edit_poly_mod then return false
    if classOf move_records != Array or move_records.count == 0 then return false
    if edit_poly_mod.currentOperation != 0 then return false

    local position_precision = resolveEditPolyMovePositionPrecision position_precision_text
    if position_precision == undefined then return false

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

            if not editPolyMovePositionsMatch actual_position expected_position position_precision then
            (
                local rounded_expected = roundEditPolyMovePosition expected_position position_precision
                local rounded_actual = roundEditPolyMovePosition actual_position position_precision
                format "moveEditPolyVerticesByRecords MOVE VERIFY ERROR | vertex:% | expectedRaw:% | actualRaw:% | expectedRounded:% | actualRounded:% | precision:%\n" vertex_id expected_position actual_position rounded_expected rounded_actual position_precision_text
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

/*
Finds one current Edit Poly edge by its two endpoint positions using explicit position precision.
Returns 0 unless exactly one current edge matches in either endpoint order.
*/
function findEditPolyMoveEdgeByEndpointPositions node_value edit_poly_mod endpoint_a endpoint_b position_precision =
(
    if not editPolyMoveModifierBelongsToNode node_value edit_poly_mod then return 0
    if classOf endpoint_a != Point3 or classOf endpoint_b != Point3 then return 0
    if position_precision == undefined or position_precision <= 0.0 then return 0

    local edge_count = edit_poly_mod.GetNumEdges node:node_value
    local found_edge_id = 0
    local match_count = 0

    for edge_id = 1 to edge_count do
    (
        local vertex_a = edit_poly_mod.GetEdgeVertex edge_id 1 node:node_value
        local vertex_b = edit_poly_mod.GetEdgeVertex edge_id 2 node:node_value
        local position_a = edit_poly_mod.GetVertex vertex_a node:node_value
        local position_b = edit_poly_mod.GetVertex vertex_b node:node_value
        local forward_match = editPolyMovePositionsMatch position_a endpoint_a position_precision and editPolyMovePositionsMatch position_b endpoint_b position_precision
        local reverse_match = editPolyMovePositionsMatch position_a endpoint_b position_precision and editPolyMovePositionsMatch position_b endpoint_a position_precision

        if forward_match or reverse_match then
        (
            found_edge_id = edge_id
            match_count += 1
        )
    )

    if match_count == 1 then
    (
        found_edge_id
    )
    else
    (
        format "MoveVertices EDGE RESOLVE ERROR | endpointA:% | endpointB:% | matches:%\n" endpoint_a endpoint_b match_count
        0
    )
    -- return
)

/*
Finds one current Edit Poly vertex by position using explicit position precision.
Returns 0 unless exactly one current vertex matches.
*/
function findEditPolyMoveVertexByPosition node_value edit_poly_mod target_position position_precision =
(
    if not editPolyMoveModifierBelongsToNode node_value edit_poly_mod then return 0
    if classOf target_position != Point3 then return 0
    if position_precision == undefined or position_precision <= 0.0 then return 0

    local vertex_count = edit_poly_mod.GetNumVertices node:node_value
    local found_vertex_id = 0
    local match_count = 0

    for vertex_id = 1 to vertex_count do
    (
        local current_position = edit_poly_mod.GetVertex vertex_id node:node_value

        if editPolyMovePositionsMatch current_position target_position position_precision then
        (
            found_vertex_id = vertex_id
            match_count += 1
        )
    )

    if match_count == 1 then
    (
        found_vertex_id
    )
    else
    (
        format "MoveVertices VERTEX RESOLVE ERROR | target:% | matches:%\n" target_position match_count
        0
    )
    -- return
)

/*
Sorts Point3 values from one edge end toward the other by projection on the source-edge direction.
Returns undefined when the supplied positions or direction are invalid.
*/
function sortEditPolyMovePositionsAlongEdge position_values edge_origin edge_direction =
(
    if classOf position_values != Array or position_values.count == 0 then return undefined
    if classOf edge_origin != Point3 or classOf edge_direction != Point3 then return undefined
    if length edge_direction == 0.0 then return undefined

    local sort_records = #()

    for position_value in position_values do
    (
        if classOf position_value != Point3 then return undefined

        local projection_value = dot (position_value - edge_origin) edge_direction
        append sort_records #(projection_value, position_value)
    )

    if sort_records.count > 1 then
    (
        for record_index_a = 1 to (sort_records.count - 1) do
        (
            for record_index_b = (record_index_a + 1) to sort_records.count do
            (
                if sort_records[record_index_b][1] < sort_records[record_index_a][1] then
                (
                    local temporary_record = sort_records[record_index_a]
                    sort_records[record_index_a] = sort_records[record_index_b]
                    sort_records[record_index_b] = temporary_record
                )
            )
        )
    )

    local sorted_positions = #()

    for sort_record in sort_records do
    (
        append sorted_positions sort_record[2]
    )

    sorted_positions
    -- return
)

/*
Inserts one vertex per target position on one Edit Poly edge, then moves them one-by-one to ordered targets.
Each split uses DivideEdge -> Commit -> geometric edge re-resolution; each move uses MoveSelection -> Commit.
*/
function insertAndMoveEditPolyEdgeVerticesToPositions node_value edit_poly_mod source_edge_id target_positions position_precision_text refresh:true =
(
    if not editPolyMoveModifierBelongsToNode node_value edit_poly_mod then return false
    if classOf source_edge_id != Integer then return false
    if classOf target_positions != Array or target_positions.count == 0 then return false
    if edit_poly_mod.currentOperation != 0 then return false

    local position_precision = resolveEditPolyMovePositionPrecision position_precision_text
    if position_precision == undefined then return false

    local edge_count = edit_poly_mod.GetNumEdges node:node_value
    if source_edge_id < 1 or source_edge_id > edge_count then return false

    local target_positions_copy = #()

    for target_position in target_positions do
    (
        if classOf target_position != Point3 then return false
        append target_positions_copy target_position
    )

    if target_positions_copy.count > 1 then
    (
        for target_index_a = 1 to (target_positions_copy.count - 1) do
        (
            for target_index_b = (target_index_a + 1) to target_positions_copy.count do
            (
                if editPolyMovePositionsMatch target_positions_copy[target_index_a] target_positions_copy[target_index_b] position_precision then
                (
                    format "MoveVertices TARGET ERROR | duplicate target positions | a:% | b:% | precision:%\n" target_positions_copy[target_index_a] target_positions_copy[target_index_b] position_precision_text
                    return false
                )
            )
        )
    )

    edit_poly_mod.SetPrimaryNode node_value
    edit_poly_mod.showCage = off

    local source_vertex_a = edit_poly_mod.GetEdgeVertex source_edge_id 1 node:node_value
    local source_vertex_b = edit_poly_mod.GetEdgeVertex source_edge_id 2 node:node_value
    local endpoint_a = edit_poly_mod.GetVertex source_vertex_a node:node_value
    local endpoint_b = edit_poly_mod.GetVertex source_vertex_b node:node_value
    local edge_direction = endpoint_b - endpoint_a

    if length edge_direction == 0.0 then return false

    local ordered_targets = sortEditPolyMovePositionsAlongEdge target_positions_copy endpoint_a edge_direction
    if ordered_targets == undefined or ordered_targets.count != target_positions_copy.count then return false

    local inserted_positions = #()
    local segment_start = endpoint_a
    local segment_end = endpoint_b
    local target_count = ordered_targets.count
    local operation_exception = undefined
    local operation_succeeded = false

    try
    (
        for insert_index = 1 to target_count do
        (
            local current_edge_id = findEditPolyMoveEdgeByEndpointPositions node_value edit_poly_mod segment_start segment_end position_precision

            if current_edge_id == 0 then
            (
                format "MoveVertices INSERT ERROR | could not resolve segment | insert:%/% | start:% | end:% | precision:%\n" insert_index target_count segment_start segment_end position_precision_text
                throw "insertAndMoveEditPolyEdgeVerticesToPositions: current edge segment could not be resolved."
            )

            local remaining_vertex_count = target_count - insert_index + 1
            local split_fraction = 1.0 / (remaining_vertex_count + 1.0)
            local inserted_position = segment_start + ((segment_end - segment_start) * split_fraction)
            local vertex_count_before = edit_poly_mod.GetNumVertices node:node_value

            edit_poly_mod.DivideEdge current_edge_id split_fraction node:node_value
            edit_poly_mod.Commit()

            local vertex_count_after = edit_poly_mod.GetNumVertices node:node_value

            if vertex_count_after != (vertex_count_before + 1) then
            (
                format "MoveVertices INSERT ERROR | DivideEdge vertex count | insert:%/% | edge:% | before:% | after:%\n" insert_index target_count current_edge_id vertex_count_before vertex_count_after
                throw "insertAndMoveEditPolyEdgeVerticesToPositions: DivideEdge did not add exactly one vertex."
            )

            append inserted_positions inserted_position
            segment_start = inserted_position
        )

        local ordered_inserted_positions = sortEditPolyMovePositionsAlongEdge inserted_positions endpoint_a edge_direction

        if ordered_inserted_positions == undefined or ordered_inserted_positions.count != ordered_targets.count then
        (
            throw "insertAndMoveEditPolyEdgeVerticesToPositions: inserted/target ordering could not be resolved."
        )

        local ordered_inserted_vertex_ids = #()

        for inserted_position in ordered_inserted_positions do
        (
            local inserted_vertex_id = findEditPolyMoveVertexByPosition node_value edit_poly_mod inserted_position position_precision

            if inserted_vertex_id == 0 then
            (
                format "MoveVertices MOVE ERROR | could not resolve inserted vertex before movement | inserted:% | precision:%\n" inserted_position position_precision_text
                throw "insertAndMoveEditPolyEdgeVerticesToPositions: inserted vertex IDs could not be resolved before movement."
            )

            append ordered_inserted_vertex_ids inserted_vertex_id
        )

        for move_index = 1 to ordered_targets.count do
        (
            local current_vertex_id = ordered_inserted_vertex_ids[move_index]
            local target_position = ordered_targets[move_index]
            local current_position = edit_poly_mod.GetVertex current_vertex_id node:node_value
            local move_delta = target_position - current_position
            local move_records = #(#(current_vertex_id, move_delta))
            local move_ok = moveEditPolyVerticesByRecords node_value edit_poly_mod move_records position_precision_text refresh:false

            if not move_ok then
            (
                format "MoveVertices MOVE ERROR | move helper returned false | move:%/% | vertex:% | current:% | target:%\n" move_index ordered_targets.count current_vertex_id current_position target_position
                throw "insertAndMoveEditPolyEdgeVerticesToPositions: vertex move did not complete."
            )
        )

        operation_succeeded = true
    )
    catch
    (
        operation_exception = getCurrentException()
    )

    if refresh then
    (
        edit_poly_mod.RefreshScreen()
        completeRedraw()
    )

    if operation_exception != undefined then
    (
        format "insertAndMoveEditPolyEdgeVerticesToPositions ERROR: %\n" operation_exception
        throw operation_exception
    )

    operation_succeeded
    -- return
)


/*
Snapshots the supplied target-vertex positions, then inserts and moves one new source-edge vertex per target.
Target IDs are consumed only before DivideEdge changes topology; later pairing uses the stored target positions.
*/
function insertAndMoveEditPolyEdgeVerticesToTargetVertices node_value edit_poly_mod source_edge_id target_vertex_bits position_precision_text refresh:true =
(
    if not validateEditPolyMoveVertexBits node_value edit_poly_mod target_vertex_bits then return false

    local target_positions = #()

    for target_vertex_id in target_vertex_bits do
    (
        append target_positions (edit_poly_mod.GetVertex target_vertex_id node:node_value)
    )

    insertAndMoveEditPolyEdgeVerticesToPositions \
        node_value \
        edit_poly_mod \
        source_edge_id \
        target_positions \
        position_precision_text \
        refresh:refresh
    -- return
)
