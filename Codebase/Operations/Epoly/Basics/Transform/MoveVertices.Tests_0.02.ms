/*
===============================================================================
Module:         MoveVertices.Tests
File version:   0.02
Purpose:        Interactive regression test for MoveVertices_0.02.ms.
===============================================================================

Execution queue:
1. partOfTest1() - create one Editable Poly fixture with an Edit Poly modifier.
2. partOfTest2() - batch-move two vertices by the same delta and verify state.
3. partOfTest3() - move two vertices by different deltas and verify state.
4. partOfTest4() - divide one edge five times and move the five new vertices to ordered targets.

Undo order after execution:
1. Restore the five-vertex divide/move fixture.
2. Restore the individual-delta moves.
3. Restore the shared-delta move.
4. Restore the scene before fixture creation.
*/

global epoly_move_vertices_test_file_version = 0.02
global epoly_move_vertices_test_node = undefined
global epoly_move_vertices_test_mod = undefined
global epoly_move_vertices_test_failures = #()
global epoly_move_vertices_edge_test_node = undefined
global epoly_move_vertices_edge_test_mod = undefined
global epoly_move_vertices_test_position_precision = "0.01mm"

global epoly_move_vertices_test_root = getFilenamePath (getSourceFileName())
global epoly_move_vertices_test_operation_path = epoly_move_vertices_test_root + "MoveVertices_0.02.ms"

if not doesFileExist epoly_move_vertices_test_operation_path then
(
    throw ("Missing operation: " + epoly_move_vertices_test_operation_path)
)

fileIn epoly_move_vertices_test_operation_path quiet:true

/*
Records one test failure without stopping the remaining assertions.
*/
function moveVerticesTestAssert condition_value message_text =
(
    if not condition_value then
    (
        append epoly_move_vertices_test_failures message_text
    )
)

/*
Creates a fresh one-quad Editable Poly fixture and one Edit Poly modifier.
*/
function partOfTest1 =
(
    undo "Move Vertices Test - Setup" on
    (
        local old_node = getNodeByName "EPOLY_MOVE_VERTICES_TEST" exact:true
        if isValidNode old_node then
        (
            delete old_node
        )

        epoly_move_vertices_test_node = Plane \
            name:"EPOLY_MOVE_VERTICES_TEST" \
            length:40.0 \
            width:40.0 \
            lengthsegs:1 \
            widthsegs:1

        convertToPoly epoly_move_vertices_test_node
        epoly_move_vertices_test_node.baseObject.showCage = off

        epoly_move_vertices_test_mod = Edit_Poly()
        epoly_move_vertices_test_mod.name = "MOVE VERTICES TEST"
        epoly_move_vertices_test_mod.showCage = off
        epoly_move_vertices_test_mod.useStackSelection = false
        epoly_move_vertices_test_mod.selectMode = 0
        addModifier epoly_move_vertices_test_node epoly_move_vertices_test_mod

        epoly_move_vertices_test_mod.SetPrimaryNode epoly_move_vertices_test_node
        epoly_move_vertices_test_mod.SetEPolySelLevel #Vertex
        epoly_move_vertices_test_mod.Select #Vertex #{2,4} node:epoly_move_vertices_test_node
    )

    moveVerticesTestAssert (isValidNode epoly_move_vertices_test_node) "Fixture node was not created."
    moveVerticesTestAssert (epoly_move_vertices_test_mod != undefined) "Edit Poly modifier was not created."
    moveVerticesTestAssert ((epoly_move_vertices_test_mod.GetNumVertices node:epoly_move_vertices_test_node) == 4) "Fixture does not contain exactly four vertices."
    true
    -- return
)

/*
Moves vertices 1 and 3 together and verifies geometry plus selection restoration.
*/
function partOfTest2 =
(
    if not isValidNode epoly_move_vertices_test_node or epoly_move_vertices_test_mod == undefined then
    (
        throw "partOfTest1() must run before partOfTest2()."
    )

    local target_vertices = #{1,3}
    local original_selection = epoly_move_vertices_test_mod.GetSelection #Vertex node:epoly_move_vertices_test_node
    local before_positions = #()
    local vertex_count_before = epoly_move_vertices_test_mod.GetNumVertices node:epoly_move_vertices_test_node
    local move_delta = [10.0, 0.0, 0.0]

    for vertex_id = 1 to vertex_count_before do
    (
        append before_positions (epoly_move_vertices_test_mod.GetVertex vertex_id node:epoly_move_vertices_test_node)
    )

    local move_result = false

    undo "Move Vertices Test - Shared Delta" on
    (
        move_result = moveEditPolyVertices \
            epoly_move_vertices_test_node \
            epoly_move_vertices_test_mod \
            target_vertices \
            move_delta \
            epoly_move_vertices_test_position_precision \
            refresh:false
    )

    moveVerticesTestAssert move_result "Shared-delta move returned false."
    moveVerticesTestAssert ((epoly_move_vertices_test_mod.GetNumVertices node:epoly_move_vertices_test_node) == vertex_count_before) "Shared-delta move changed topology."
    moveVerticesTestAssert ((epoly_move_vertices_test_mod.GetSelection #Vertex node:epoly_move_vertices_test_node) == original_selection) "Shared-delta move did not restore the original selection."

    for vertex_id = 1 to vertex_count_before do
    (
        local expected_position = before_positions[vertex_id]
        if target_vertices[vertex_id] then
        (
            expected_position += move_delta
        )

        local actual_position = epoly_move_vertices_test_mod.GetVertex vertex_id node:epoly_move_vertices_test_node
        local position_precision = resolveEditPolyMovePositionPrecision epoly_move_vertices_test_position_precision
        moveVerticesTestAssert (editPolyMovePositionsMatch actual_position expected_position position_precision) ("Shared-delta position mismatch at vertex " + (vertex_id as string) + ".")
    )

    true
    -- return
)

/*
Moves vertices 2 and 4 by different deltas and verifies geometry plus selection restoration.
*/
function partOfTest3 =
(
    if not isValidNode epoly_move_vertices_test_node or epoly_move_vertices_test_mod == undefined then
    (
        throw "partOfTest1() must run before partOfTest3()."
    )

    local original_selection = epoly_move_vertices_test_mod.GetSelection #Vertex node:epoly_move_vertices_test_node
    local vertex_count_before = epoly_move_vertices_test_mod.GetNumVertices node:epoly_move_vertices_test_node
    local position_2_before = epoly_move_vertices_test_mod.GetVertex 2 node:epoly_move_vertices_test_node
    local position_4_before = epoly_move_vertices_test_mod.GetVertex 4 node:epoly_move_vertices_test_node
    local move_records = #(
        #(2, [0.0, 5.0, 0.0]),
        #(4, [0.0, 0.0, 7.0])
    )
    local move_result = false

    undo "Move Vertices Test - Individual Deltas" on
    (
        move_result = moveEditPolyVerticesByRecords \
            epoly_move_vertices_test_node \
            epoly_move_vertices_test_mod \
            move_records \
            epoly_move_vertices_test_position_precision \
            refresh:false
    )

    moveVerticesTestAssert move_result "Individual-delta move returned false."
    moveVerticesTestAssert ((epoly_move_vertices_test_mod.GetNumVertices node:epoly_move_vertices_test_node) == vertex_count_before) "Individual-delta move changed topology."
    moveVerticesTestAssert ((epoly_move_vertices_test_mod.GetSelection #Vertex node:epoly_move_vertices_test_node) == original_selection) "Individual-delta move did not restore the original selection."
    local position_precision = resolveEditPolyMovePositionPrecision epoly_move_vertices_test_position_precision
    moveVerticesTestAssert (editPolyMovePositionsMatch (epoly_move_vertices_test_mod.GetVertex 2 node:epoly_move_vertices_test_node) (position_2_before + [0.0, 5.0, 0.0]) position_precision) "Vertex 2 did not receive its requested delta."
    moveVerticesTestAssert (editPolyMovePositionsMatch (epoly_move_vertices_test_mod.GetVertex 4 node:epoly_move_vertices_test_node) (position_4_before + [0.0, 0.0, 7.0]) position_precision) "Vertex 4 did not receive its requested delta."

    epoly_move_vertices_test_mod.RefreshScreen()
    completeRedraw()

    true
    -- return
)

/*
Finds the unique bottom border edge on the one-quad edge-move fixture.
Uses the explicit position precision for all position-based comparisons.
*/
function moveVerticesTestFindBottomEdge node_value edit_poly_mod position_precision =
(
    local vertex_count = edit_poly_mod.GetNumVertices node:node_value
    local edge_count = edit_poly_mod.GetNumEdges node:node_value
    local minimum_y = undefined

    for vertex_id = 1 to vertex_count do
    (
        local vertex_position = edit_poly_mod.GetVertex vertex_id node:node_value
        local rounded_position = roundEditPolyMovePosition vertex_position position_precision

        if rounded_position == undefined then return 0

        if minimum_y == undefined or rounded_position.y < minimum_y then
        (
            minimum_y = rounded_position.y
        )
    )

    local found_edge_id = 0
    local match_count = 0

    for edge_id = 1 to edge_count do
    (
        local vertex_a = edit_poly_mod.GetEdgeVertex edge_id 1 node:node_value
        local vertex_b = edit_poly_mod.GetEdgeVertex edge_id 2 node:node_value
        local position_a = roundEditPolyMovePosition (edit_poly_mod.GetVertex vertex_a node:node_value) position_precision
        local position_b = roundEditPolyMovePosition (edit_poly_mod.GetVertex vertex_b node:node_value) position_precision

        if position_a != undefined and position_b != undefined and position_a.y == minimum_y and position_b.y == minimum_y then
        (
            found_edge_id = edge_id
            match_count += 1
        )
    )

    if match_count == 1 then found_edge_id else 0
    -- return
)

/*
Divides one edge five times and moves each new vertex individually to its ordered target position.
The fixture intentionally uses five targets to exercise the requested repeated DivideEdge/Commit path.
*/
function partOfTest4 =
(
    local position_precision = resolveEditPolyMovePositionPrecision epoly_move_vertices_test_position_precision

    if position_precision == undefined then
    (
        throw "MoveVertices test precision could not be resolved."
    )

    undo "Move Vertices Test - Insert And Move Five" on
    (
        local old_node = getNodeByName "EPOLY_MOVE_VERTICES_EDGE_TEST" exact:true
        if isValidNode old_node then
        (
            delete old_node
        )

        epoly_move_vertices_edge_test_node = Plane \
            name:"EPOLY_MOVE_VERTICES_EDGE_TEST" \
            length:20.0 \
            width:60.0 \
            lengthsegs:1 \
            widthsegs:1

        convertToPoly epoly_move_vertices_edge_test_node
        epoly_move_vertices_edge_test_node.baseObject.showCage = off

        epoly_move_vertices_edge_test_mod = Edit_Poly()
        epoly_move_vertices_edge_test_mod.name = "INSERT AND MOVE FIVE TEST"
        epoly_move_vertices_edge_test_mod.showCage = off
        epoly_move_vertices_edge_test_mod.useStackSelection = false
        epoly_move_vertices_edge_test_mod.selectMode = 0
        addModifier epoly_move_vertices_edge_test_node epoly_move_vertices_edge_test_mod

        epoly_move_vertices_edge_test_mod.SetPrimaryNode epoly_move_vertices_edge_test_node
        epoly_move_vertices_edge_test_mod.SetEPolySelLevel #Edge

        local source_edge_id = moveVerticesTestFindBottomEdge epoly_move_vertices_edge_test_node epoly_move_vertices_edge_test_mod position_precision
        moveVerticesTestAssert (source_edge_id > 0) "Five-vertex fixture source edge could not be resolved."

        if source_edge_id > 0 then
        (
            local source_vertex_a = epoly_move_vertices_edge_test_mod.GetEdgeVertex source_edge_id 1 node:epoly_move_vertices_edge_test_node
            local source_vertex_b = epoly_move_vertices_edge_test_mod.GetEdgeVertex source_edge_id 2 node:epoly_move_vertices_edge_test_node
            local endpoint_a = epoly_move_vertices_edge_test_mod.GetVertex source_vertex_a node:epoly_move_vertices_edge_test_node
            local endpoint_b = epoly_move_vertices_edge_test_mod.GetVertex source_vertex_b node:epoly_move_vertices_edge_test_node
            local edge_direction = endpoint_b - endpoint_a
            local target_positions = #()

            for target_index = 1 to 5 do
            (
                local target_fraction = (target_index as float) / 6.0
                append target_positions (endpoint_a + (edge_direction * target_fraction) + [0.0, 0.0, 10.0])
            )

            local vertex_count_before = epoly_move_vertices_edge_test_mod.GetNumVertices node:epoly_move_vertices_edge_test_node
            local edge_count_before = epoly_move_vertices_edge_test_mod.GetNumEdges node:epoly_move_vertices_edge_test_node
            local face_count_before = epoly_move_vertices_edge_test_mod.GetNumFaces node:epoly_move_vertices_edge_test_node
            local move_result = insertAndMoveEditPolyEdgeVerticesToPositions \
                epoly_move_vertices_edge_test_node \
                epoly_move_vertices_edge_test_mod \
                source_edge_id \
                target_positions \
                epoly_move_vertices_test_position_precision \
                refresh:false

            moveVerticesTestAssert move_result "Five-vertex divide/move operation returned false."
            moveVerticesTestAssert ((epoly_move_vertices_edge_test_mod.GetNumVertices node:epoly_move_vertices_edge_test_node) == (vertex_count_before + 5)) "Five-vertex divide/move did not add exactly five vertices."
            moveVerticesTestAssert ((epoly_move_vertices_edge_test_mod.GetNumEdges node:epoly_move_vertices_edge_test_node) == (edge_count_before + 5)) "Five-vertex divide/move did not add exactly five edges."
            moveVerticesTestAssert ((epoly_move_vertices_edge_test_mod.GetNumFaces node:epoly_move_vertices_edge_test_node) == face_count_before) "Five-vertex divide/move changed the face count."

            for target_position in target_positions do
            (
                local moved_vertex_id = findEditPolyMoveVertexByPosition epoly_move_vertices_edge_test_node epoly_move_vertices_edge_test_mod target_position position_precision
                moveVerticesTestAssert (moved_vertex_id > 0) ("Five-vertex target position was not occupied: " + (target_position as string))
            )
        )

        epoly_move_vertices_edge_test_mod.RefreshScreen()
        completeRedraw()
    )

    if epoly_move_vertices_test_failures.count > 0 then
    (
        format "MoveVertices test: % failure(s).\n" epoly_move_vertices_test_failures.count

        for failure_text in epoly_move_vertices_test_failures do
        (
            format "FAIL: %\n" failure_text
        )

        throw ("MoveVertices test failed: " + (epoly_move_vertices_test_failures.count as string))
    )

    format "MoveVertices test: PASS.\n"
    format "Precision: % | Five DivideEdge/Commit operations verified.\n" epoly_move_vertices_test_position_precision
    format "Undo order: five-vertex divide/move, individual deltas, shared delta, setup.\n"
    true
    -- return
)

partOfTest1()
partOfTest2()
partOfTest3()
partOfTest4()
