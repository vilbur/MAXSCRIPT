/*
    Two Visible Edge Verts 0.51 manual REMOVE VERT callback regression test.
    Verifies SELECT 2-EDGE VERTS stores data, REMOVE VERT LMB only selects the highest candidate, and REMOVE VERT RMB fixes/removes only that candidate from stored data.
*/

global manual_remove_test_editable
global manual_remove_test_edit_poly
global manual_remove_test_modifier
global TwoVisibleEdgeVerts
global EPOLY_TOOLS_RUNTIME_MODE

/*
Loads the exact 0.51 tool revision under test in library mode.
The production rollout remains closed while the API is exercised directly.
*/
function loadTestTool =
(
    tool_path = getFilenamePath (getSourceFileName()) + "Two-Visible-Edge-Verts_0.51.ms"
    if not(doesFileExist tool_path) then throw ("Missing test target: " + tool_path)

    previous_runtime_mode = EPOLY_TOOLS_RUNTIME_MODE
    EPOLY_TOOLS_RUNTIME_MODE = #library
    fileIn tool_path quiet:true
    EPOLY_TOOLS_RUNTIME_MODE = previous_runtime_mode

    if TwoVisibleEdgeVerts == undefined then throw "TwoVisibleEdgeVerts failed to load."
    if TwoVisibleEdgeVerts.file_version != 0.51 then throw "Unexpected TwoVisibleEdgeVerts file version."
    if TwoVisibleEdgeVerts.project_version != 0.51 then throw "Unexpected TwoVisibleEdgeVerts project version."

    true
    -- return
)

/*
Creates one eight-sided Editable Poly polygon with four collinear border vertices.
With border-corner filtering enabled, the expected stored 2-edge IDs are #(2,3,6,7).
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
Builds one Editable Poly and one Edit Poly object for callback-state testing.
The final scene remains available for manual inspection after the test finishes.
*/
function partOfTest1 =
(
    undo "TEST 1 - Create Manual Callback Objects" on
    (
        old_editable = getNodeByName "TEST_Manual_Callback_Editable"
        if old_editable != undefined and isValidNode old_editable then delete old_editable

        old_edit_poly = getNodeByName "TEST_Manual_Callback_EditPoly"
        if old_edit_poly != undefined and isValidNode old_edit_poly then delete old_edit_poly

        manual_remove_test_editable = createManualTestPoly "TEST_Manual_Callback_Editable" [-80,0,0]
        manual_remove_test_edit_poly = createManualTestPoly "TEST_Manual_Callback_EditPoly" [80,0,0]

        manual_remove_test_modifier = Edit_Poly()
        manual_remove_test_modifier.name = "TEST MANUAL CALLBACK"
        manual_remove_test_modifier.showCage = off
        addModifier manual_remove_test_edit_poly manual_remove_test_modifier
    )

    true
    -- return
)

/*
Runs the SELECT 2-EDGE VERTS LMB workflow on Editable Poly and verifies it stores the detected IDs.
The stored data must be #(2,3,6,7) before REMOVE VERT is used.
*/
function partOfTest2 =
(
    undo "TEST 2 - Store Editable Poly Candidates" on
    (
        TwoVisibleEdgeVerts.ignore_border_corners = true
        TwoVisibleEdgeVerts.resetManualRemoveState()
        select manual_remove_test_editable

        select_ok = TwoVisibleEdgeVerts.selectTwoEdgeVerts()
        if not(select_ok) then throw "Editable Poly SELECT 2-EDGE VERTS failed."

        store_ok = TwoVisibleEdgeVerts.storeManualRemoveStateFromCurrentSelection()
        if not(store_ok) then throw "Editable Poly candidate storage failed."

        if TwoVisibleEdgeVerts.manual_remove_vertex_ids != #(2,3,6,7) then
        (
            throw ("Editable Poly stored IDs mismatch: " + (TwoVisibleEdgeVerts.manual_remove_vertex_ids as string))
        )
    )

    true
    -- return
)

/*
Steps the Editable Poly data manually: LMB selects only the candidate and RMB fixes/removes it from stored data.
Expected candidate order is 7, 6, 3, 2; LMB changes no topology and RMB leaves no candidate selected automatically.
*/
function partOfTest3 =
(
    expected_ids = #(7,6,3,2)

    for step_index = 1 to expected_ids.count do
    (
        expected_id = expected_ids[step_index]
        before_select_count = polyop.getNumVerts manual_remove_test_editable
        before_queue_count = TwoVisibleEdgeVerts.manual_remove_vertex_ids.count

        lmb_ok = TwoVisibleEdgeVerts.selectNextManualRemoveCandidate()
        if not(lmb_ok) then throw ("Editable Poly REMOVE VERT LMB failed at candidate " + (expected_id as string) + ".")
        if polyop.getNumVerts manual_remove_test_editable != before_select_count then throw "Editable Poly LMB changed topology."
        if TwoVisibleEdgeVerts.manual_remove_vertex_ids.count != before_queue_count then throw "Editable Poly LMB changed stored data."
        if TwoVisibleEdgeVerts.manual_remove_candidate_id != expected_id then throw "Editable Poly LMB armed the wrong candidate."

        selected_bits = polyop.getVertSelection manual_remove_test_editable
        expected_bits = #{}
        expected_bits[expected_id] = true
        if selected_bits != expected_bits then throw ("Editable Poly LMB selected " + (selected_bits as string) + " instead of " + (expected_bits as string) + ".")

        before_fix_count = polyop.getNumVerts manual_remove_test_editable
        rmb_ok = TwoVisibleEdgeVerts.fixManualRemoveCandidate()
        after_fix_count = polyop.getNumVerts manual_remove_test_editable

        if not(rmb_ok) then throw ("Editable Poly REMOVE VERT RMB failed at candidate " + (expected_id as string) + ".")
        if before_fix_count - after_fix_count != 1 then throw "Editable Poly RMB did not remove exactly one vertex."
        if TwoVisibleEdgeVerts.manual_remove_candidate_id != 0 then throw "Editable Poly RMB left a candidate armed."

        selected_bits = polyop.getVertSelection manual_remove_test_editable
        if selected_bits.numberSet != 0 then throw ("Editable Poly RMB auto-selected another candidate: " + (selected_bits as string))

        expected_remaining = expected_ids.count - step_index
        if TwoVisibleEdgeVerts.manual_remove_vertex_ids.count != expected_remaining then throw "Editable Poly RMB removed the wrong amount of stored data."
    )

    true
    -- return
)

/*
Runs the same stored-data and LMB/RMB sequence on Edit Poly.
The modifier selection must remain empty after each RMB until the next explicit REMOVE VERT LMB.
*/
function partOfTest4 =
(
    TwoVisibleEdgeVerts.ignore_border_corners = true
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

    select_ok = TwoVisibleEdgeVerts.selectTwoEdgeVerts()
    if not(select_ok) then throw "Edit Poly SELECT 2-EDGE VERTS failed."

    store_ok = TwoVisibleEdgeVerts.storeManualRemoveStateFromCurrentSelection()
    if not(store_ok) then throw "Edit Poly candidate storage failed."

    if TwoVisibleEdgeVerts.manual_remove_vertex_ids != #(2,3,6,7) then
    (
        throw ("Edit Poly stored IDs mismatch: " + (TwoVisibleEdgeVerts.manual_remove_vertex_ids as string))
    )

    expected_ids = #(7,6,3,2)

    for step_index = 1 to expected_ids.count do
    (
        expected_id = expected_ids[step_index]
        before_select_count = EditPolyMod.GetNumVertices manual_remove_test_modifier node:manual_remove_test_edit_poly
        before_queue_count = TwoVisibleEdgeVerts.manual_remove_vertex_ids.count

        lmb_ok = TwoVisibleEdgeVerts.selectNextManualRemoveCandidate()
        if not(lmb_ok) then throw ("Edit Poly REMOVE VERT LMB failed at candidate " + (expected_id as string) + ".")
        if EditPolyMod.GetNumVertices manual_remove_test_modifier node:manual_remove_test_edit_poly != before_select_count then throw "Edit Poly LMB changed topology."
        if TwoVisibleEdgeVerts.manual_remove_vertex_ids.count != before_queue_count then throw "Edit Poly LMB changed stored data."
        if TwoVisibleEdgeVerts.manual_remove_candidate_id != expected_id then throw "Edit Poly LMB armed the wrong candidate."

        selected_bits = manual_remove_test_modifier.GetSelection #Vertex node:manual_remove_test_edit_poly
        if selected_bits == undefined then selected_bits = #{}
        expected_bits = #{}
        expected_bits[expected_id] = true
        if selected_bits != expected_bits then throw ("Edit Poly LMB selected " + (selected_bits as string) + " instead of " + (expected_bits as string) + ".")

        before_fix_count = EditPolyMod.GetNumVertices manual_remove_test_modifier node:manual_remove_test_edit_poly
        rmb_ok = TwoVisibleEdgeVerts.fixManualRemoveCandidate()
        after_fix_count = EditPolyMod.GetNumVertices manual_remove_test_modifier node:manual_remove_test_edit_poly

        if not(rmb_ok) then throw ("Edit Poly REMOVE VERT RMB failed at candidate " + (expected_id as string) + ".")
        if before_fix_count - after_fix_count != 1 then throw "Edit Poly RMB did not remove exactly one vertex."
        if TwoVisibleEdgeVerts.manual_remove_candidate_id != 0 then throw "Edit Poly RMB left a candidate armed."

        selected_bits = manual_remove_test_modifier.GetSelection #Vertex node:manual_remove_test_edit_poly
        if selected_bits == undefined then selected_bits = #{}
        if selected_bits.numberSet != 0 then throw ("Edit Poly RMB auto-selected another candidate: " + (selected_bits as string))

        expected_remaining = expected_ids.count - step_index
        if TwoVisibleEdgeVerts.manual_remove_vertex_ids.count != expected_remaining then throw "Edit Poly RMB removed the wrong amount of stored data."
    )

    format "REMOVE VERT CALLBACK TEST PASS | candidates: 7 -> 6 -> 3 -> 2 | Editable Poly + Edit Poly\n"
    format "CALLBACK CONTRACT: SELECT LMB stores -> REMOVE LMB selects only -> REMOVE RMB fixes/removes stored ID -> next LMB advances\n"
    format "UNDO ORDER (top first): 4x Remove One 2-Edge Vert [Edit Poly] -> 4x Remove One 2-Edge Vert [Editable Poly] -> TEST 2 - Store Editable Poly Candidates -> TEST 1 - Create Manual Callback Objects\n"

    true
    -- return
)

loadTestTool()
partOfTest1()
partOfTest2()
partOfTest3()
partOfTest4()
