/*
===============================================================================
Module:         MoveVertices.Tests
File version:   0.01
Purpose:        Interactive regression test for MoveVertices_0.01.ms.
===============================================================================

Execution queue:
1. partOfTest1() - create one Editable Poly fixture with an Edit Poly modifier.
2. partOfTest2() - batch-move two vertices by the same delta and verify state.
3. partOfTest3() - move two vertices by different deltas and verify state.

Undo order after execution:
1. Restore the individual-delta moves.
2. Restore the shared-delta move.
3. Restore the scene before fixture creation.
*/

global epoly_move_vertices_test_file_version = 0.01
global epoly_move_vertices_test_node = undefined
global epoly_move_vertices_test_mod = undefined
global epoly_move_vertices_test_failures = #()

global epoly_move_vertices_test_root = getFilenamePath (getSourceFileName())
global epoly_move_vertices_test_operation_path = epoly_move_vertices_test_root + "MoveVertices_0.01.ms"

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
        moveVerticesTestAssert (actual_position == expected_position) ("Shared-delta position mismatch at vertex " + (vertex_id as string) + ".")
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
            refresh:false
    )

    moveVerticesTestAssert move_result "Individual-delta move returned false."
    moveVerticesTestAssert ((epoly_move_vertices_test_mod.GetNumVertices node:epoly_move_vertices_test_node) == vertex_count_before) "Individual-delta move changed topology."
    moveVerticesTestAssert ((epoly_move_vertices_test_mod.GetSelection #Vertex node:epoly_move_vertices_test_node) == original_selection) "Individual-delta move did not restore the original selection."
    moveVerticesTestAssert ((epoly_move_vertices_test_mod.GetVertex 2 node:epoly_move_vertices_test_node) == (position_2_before + [0.0, 5.0, 0.0])) "Vertex 2 did not receive its requested delta."
    moveVerticesTestAssert ((epoly_move_vertices_test_mod.GetVertex 4 node:epoly_move_vertices_test_node) == (position_4_before + [0.0, 0.0, 7.0])) "Vertex 4 did not receive its requested delta."

    epoly_move_vertices_test_mod.RefreshScreen()
    completeRedraw()

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
    format "Undo order: individual deltas, shared delta, setup.\n"
    true
    -- return
)

partOfTest1()
partOfTest2()
partOfTest3()
