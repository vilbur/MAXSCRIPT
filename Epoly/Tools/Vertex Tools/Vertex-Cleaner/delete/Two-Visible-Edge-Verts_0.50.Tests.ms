/*
    Two Visible Edge Verts 0.50 manual REMOVE VERT regression test.
    Verifies one stored selected vertex is removed per call, highest ID first, and the next lower stored ID becomes the only selected vertex.
*/

global manual_remove_test_editable
global manual_remove_test_edit_poly
global manual_remove_test_modifier
global TwoVisibleEdgeVerts
global EPOLY_TOOLS_RUNTIME_MODE

/*
Loads the exact 0.50 tool revision under test in library mode.
The production rollout remains closed while the API is exercised directly.
*/
function loadTestTool =
(
    tool_path = getFilenamePath (getSourceFileName()) + "Two-Visible-Edge-Verts_0.50.ms"
    if not(doesFileExist tool_path) then throw ("Missing test target: " + tool_path)

    previous_runtime_mode = EPOLY_TOOLS_RUNTIME_MODE
    EPOLY_TOOLS_RUNTIME_MODE = #library
    fileIn tool_path quiet:true
    EPOLY_TOOLS_RUNTIME_MODE = previous_runtime_mode

    if TwoVisibleEdgeVerts == undefined then throw "TwoVisibleEdgeVerts failed to load."
    if TwoVisibleEdgeVerts.file_version != 0.50 then throw "Unexpected TwoVisibleEdgeVerts file version."
    if TwoVisibleEdgeVerts.project_version != 0.50 then throw "Unexpected TwoVisibleEdgeVerts project version."

    true
    -- return
)

/*
Creates one eight-sided Editable Poly polygon with simple sequential vertex IDs.
Selected test targets 2, 3, 4, and 5 are consecutive so highest-to-lowest index stability is observable.
*/
function createManualTestPoly object_name object_position =
(
    poly_node = editable_mesh name:object_name
    convertTo poly_node Editable_Poly

    polyop.createVert poly_node [0,0,0]
    polyop.createVert poly_node [20,0,0]
    polyop.createVert poly_node [40,0,0]
    polyop.createVert poly_node [60,0,0]
    polyop.createVert poly_node [60,30,0]
    polyop.createVert poly_node [40,30,0]
    polyop.createVert poly_node [20,30,0]
    polyop.createVert poly_node [0,30,0]
    polyop.createPolygon poly_node #(1,2,3,4,5,6,7,8)

    poly_node.position = object_position
    poly_node.showCage = off
    update poly_node

    poly_node
    -- return
)

/*
Builds the Editable Poly and Edit Poly objects used by the manual stepper test.
Each object starts with eight polygon vertices.
*/
function partOfTest1 =
(
    undo "TEST 1 - Create Manual Remove Objects" on
    (
        old_editable = getNodeByName "TEST_Manual_Remove_Editable"
        if old_editable != undefined and isValidNode old_editable then delete old_editable

        old_edit_poly = getNodeByName "TEST_Manual_Remove_EditPoly"
        if old_edit_poly != undefined and isValidNode old_edit_poly then delete old_edit_poly

        manual_remove_test_editable = createManualTestPoly "TEST_Manual_Remove_Editable" [-80,0,0]
        manual_remove_test_edit_poly = createManualTestPoly "TEST_Manual_Remove_EditPoly" [80,0,0]

        manual_remove_test_modifier = Edit_Poly()
        manual_remove_test_modifier.name = "TEST MANUAL REMOVE"
        manual_remove_test_modifier.showCage = off
        addModifier manual_remove_test_edit_poly manual_remove_test_modifier
    )

    true
    -- return
)

/*
Selects the same four consecutive valid two-edge vertices on both test objects.
The first REMOVE VERT call must capture the queue #(2,3,4,5) and process ID 5 first.
*/
function partOfTest2 =
(
    undo "TEST 2 - Select Manual Remove Queue" on
    (
        TwoVisibleEdgeVerts.ignore_border_corners = false
        TwoVisibleEdgeVerts.resetManualRemoveState()

        polyop.setVertSelection manual_remove_test_editable #{2,3,4,5}

        select manual_remove_test_edit_poly
        max modify mode
        manual_remove_test_modifier.SetPrimaryNode manual_remove_test_edit_poly
        manual_remove_test_modifier.useStackSelection = false
        manual_remove_test_modifier.selectMode = 0
        manual_remove_test_modifier.showCage = false
        modPanel.setCurrentObject manual_remove_test_modifier node:manual_remove_test_edit_poly
        manual_remove_test_modifier.SetEPolySelLevel #Vertex
        subObjectLevel = 1

        old_selection = manual_remove_test_modifier.GetSelection #Vertex node:manual_remove_test_edit_poly
        if old_selection == undefined then old_selection = #{}
        if old_selection.numberSet > 0 then manual_remove_test_modifier.Select #Vertex old_selection select:false node:manual_remove_test_edit_poly
        manual_remove_test_modifier.Select #Vertex #{2,3,4,5} select:true node:manual_remove_test_edit_poly
        manual_remove_test_modifier.RefreshScreen()
    )

    true
    -- return
)

/*
Runs four manual REMOVE VERT steps on Editable Poly and verifies next-ID selection after every click-equivalent call.
The expected selected sequence after each removal is 4, then 3, then 2, then empty.
*/
function partOfTest3 =
(
    TwoVisibleEdgeVerts.ignore_border_corners = false
    TwoVisibleEdgeVerts.resetManualRemoveState()
    polyop.setVertSelection manual_remove_test_editable #{2,3,4,5}
    select manual_remove_test_editable

    before_count = polyop.getNumVerts manual_remove_test_editable
    expected_next_ids = #(4,3,2,0)

    for step_index = 1 to expected_next_ids.count do
    (
        step_before = polyop.getNumVerts manual_remove_test_editable
        step_ok = TwoVisibleEdgeVerts.removeNextTwoEdgeVert()
        step_after = polyop.getNumVerts manual_remove_test_editable

        if not(step_ok) then throw ("Editable Poly manual step " + (step_index as string) + " returned false.")
        if step_before - step_after != 1 then throw ("Editable Poly manual step " + (step_index as string) + " did not remove exactly one vertex.")

        selected_bits = polyop.getVertSelection manual_remove_test_editable
        expected_vertex = expected_next_ids[step_index]
        expected_bits = #{}
        if expected_vertex > 0 then expected_bits[expected_vertex] = true

        if selected_bits != expected_bits then
        (
            throw ("Editable Poly manual step " + (step_index as string) + " expected selection " + (expected_bits as string) + ", got " + (selected_bits as string) + ".")
        )
    )

    after_count = polyop.getNumVerts manual_remove_test_editable
    if before_count - after_count != 4 then throw "Editable Poly manual queue did not remove four vertices total."
    if TwoVisibleEdgeVerts.manual_remove_vertex_ids.count != 0 then throw "Editable Poly manual queue was not cleared after the final step."

    true
    -- return
)

/*
Runs four manual REMOVE VERT steps on Edit Poly and verifies the same next-ID selection sequence.
The modifier must expose exactly one selected next source after each intermediate step.
*/
function partOfTest4 =
(
    TwoVisibleEdgeVerts.ignore_border_corners = false
    TwoVisibleEdgeVerts.resetManualRemoveState()

    select manual_remove_test_edit_poly
    max modify mode
    manual_remove_test_modifier.SetPrimaryNode manual_remove_test_edit_poly
    manual_remove_test_modifier.useStackSelection = false
    manual_remove_test_modifier.selectMode = 0
    manual_remove_test_modifier.showCage = false
    modPanel.setCurrentObject manual_remove_test_modifier node:manual_remove_test_edit_poly
    manual_remove_test_modifier.SetEPolySelLevel #Vertex
    subObjectLevel = 1

    old_selection = manual_remove_test_modifier.GetSelection #Vertex node:manual_remove_test_edit_poly
    if old_selection == undefined then old_selection = #{}
    if old_selection.numberSet > 0 then manual_remove_test_modifier.Select #Vertex old_selection select:false node:manual_remove_test_edit_poly
    manual_remove_test_modifier.Select #Vertex #{2,3,4,5} select:true node:manual_remove_test_edit_poly
    manual_remove_test_modifier.RefreshScreen()

    before_count = EditPolyMod.GetNumVertices manual_remove_test_modifier node:manual_remove_test_edit_poly
    expected_next_ids = #(4,3,2,0)

    for step_index = 1 to expected_next_ids.count do
    (
        step_before = EditPolyMod.GetNumVertices manual_remove_test_modifier node:manual_remove_test_edit_poly
        step_ok = TwoVisibleEdgeVerts.removeNextTwoEdgeVert()
        step_after = EditPolyMod.GetNumVertices manual_remove_test_modifier node:manual_remove_test_edit_poly

        if not(step_ok) then throw ("Edit Poly manual step " + (step_index as string) + " returned false.")
        if step_before - step_after != 1 then throw ("Edit Poly manual step " + (step_index as string) + " did not remove exactly one vertex.")

        selected_bits = manual_remove_test_modifier.GetSelection #Vertex node:manual_remove_test_edit_poly
        if selected_bits == undefined then selected_bits = #{}
        expected_vertex = expected_next_ids[step_index]
        expected_bits = #{}
        if expected_vertex > 0 then expected_bits[expected_vertex] = true

        if selected_bits != expected_bits then
        (
            throw ("Edit Poly manual step " + (step_index as string) + " expected selection " + (expected_bits as string) + ", got " + (selected_bits as string) + ".")
        )
    )

    after_count = EditPolyMod.GetNumVertices manual_remove_test_modifier node:manual_remove_test_edit_poly
    if before_count - after_count != 4 then throw "Edit Poly manual queue did not remove four vertices total."
    if TwoVisibleEdgeVerts.manual_remove_vertex_ids.count != 0 then throw "Edit Poly manual queue was not cleared after the final step."

    format "REMOVE VERT MANUAL TEST PASS | Editable Poly removed:4 | Edit Poly removed:4\n"
    format "EXPECTED MANUAL SELECTION SEQUENCE: 4 -> 3 -> 2 -> empty\n"
    format "UNDO ORDER (top first): 4x Remove One 2-Edge Vert [Edit Poly] -> 4x Remove One 2-Edge Vert [Editable Poly] -> TEST 2 - Select Manual Remove Queue -> TEST 1 - Create Manual Remove Objects\n"

    true
    -- return
)

loadTestTool()
partOfTest1()
partOfTest2()
partOfTest3()
partOfTest4()
