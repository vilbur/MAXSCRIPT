/*
    Two Visible Edge Verts 0.48 RMB indexed-selection regression test.
    Verifies stored selected vertex IDs are processed from highest to lowest and that non-selected vertices are never consumed by the weld loop.
*/

global two_edge_test_editable
global two_edge_test_edit_poly
global two_edge_test_modifier
global TwoVisibleEdgeVerts
global EPOLY_TOOLS_RUNTIME_MODE

/*
Loads the exact tool revision under test without forcing its standalone dialog open.
*/
function loadTestTool =
(
    tool_path = getFilenamePath (getSourceFileName()) + "Two-Visible-Edge-Verts_0.48.ms"
    if not(doesFileExist tool_path) then throw ("Missing test target: " + tool_path)

    previous_runtime_mode = EPOLY_TOOLS_RUNTIME_MODE
    EPOLY_TOOLS_RUNTIME_MODE = #library
    fileIn tool_path quiet:true
    EPOLY_TOOLS_RUNTIME_MODE = previous_runtime_mode

    if TwoVisibleEdgeVerts == undefined then throw "TwoVisibleEdgeVerts failed to load."
    if TwoVisibleEdgeVerts.file_version != 0.48 then throw "Unexpected TwoVisibleEdgeVerts file version."
    if TwoVisibleEdgeVerts.project_version != TwoVisibleEdgeVerts.file_version then throw "Project version must equal file version."

    true
    -- return
)

/*
Creates one eight-sided single-face Editable Poly whose vertices all have exactly two polygon edges.
*/
function createEightSidedPoly object_name object_position =
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
Part 1 creates clean Editable Poly and Edit Poly regression objects.
*/
function partOfTest1 =
(
    undo "TEST 1 - Create 2-Edge RMB Objects" on
    (
        old_editable = getNodeByName "TEST_2Edge_RMB_Editable"
        if old_editable != undefined and isValidNode old_editable then delete old_editable

        old_edit_poly = getNodeByName "TEST_2Edge_RMB_EditPoly"
        if old_edit_poly != undefined and isValidNode old_edit_poly then delete old_edit_poly

        two_edge_test_editable = createEightSidedPoly "TEST_2Edge_RMB_Editable" [-80,0,0]
        two_edge_test_edit_poly = createEightSidedPoly "TEST_2Edge_RMB_EditPoly" [80,0,0]

        two_edge_test_modifier = Edit_Poly()
        two_edge_test_modifier.name = "TEST 2-EDGE RMB"
        two_edge_test_modifier.showCage = off
        addModifier two_edge_test_edit_poly two_edge_test_modifier
    )

    true
    -- return
)

/*
Part 2 stores four separated valid 2-edge targets so every intended weld destination starts as an unselected vertex.
*/
function partOfTest2 =
(
    undo "TEST 2 - Select Even Vertices" on
    (
        TwoVisibleEdgeVerts.ignore_border_corners = false

        polyop.setVertSelection two_edge_test_editable #{2,4,6,8}

        select two_edge_test_edit_poly
        max modify mode
        two_edge_test_modifier.SetPrimaryNode two_edge_test_edit_poly
        two_edge_test_modifier.useStackSelection = false
        two_edge_test_modifier.selectMode = 0
        two_edge_test_modifier.showCage = false
        modPanel.setCurrentObject two_edge_test_modifier node:two_edge_test_edit_poly
        two_edge_test_modifier.SetEPolySelLevel #Vertex
        subObjectLevel = 1

        old_selection = two_edge_test_modifier.GetSelection #Vertex node:two_edge_test_edit_poly
        if old_selection == undefined then old_selection = #{}
        if old_selection.numberSet > 0 then two_edge_test_modifier.Select #Vertex old_selection select:false node:two_edge_test_edit_poly
        two_edge_test_modifier.Select #Vertex #{2,4,6,8} select:true node:two_edge_test_edit_poly
        two_edge_test_modifier.RefreshScreen()
    )

    true
    -- return
)

/*
Part 3 runs public RMB removal, verifies four vertices disappear, and confirms the original non-selected vertex positions survive.
*/
function partOfTest3 =
(
    editable_keep_positions = for vertex_index in #(1,3,5,7) collect (polyop.getVert two_edge_test_editable vertex_index)

    select two_edge_test_editable
    editable_before = polyop.getNumVerts two_edge_test_editable
    editable_ok = TwoVisibleEdgeVerts.removeTwoEdgeVerts()
    editable_after = polyop.getNumVerts two_edge_test_editable

    if not(editable_ok) then throw "Editable Poly RMB removal returned false."
    if editable_before - editable_after != 4 then throw ("Editable Poly expected 4 removed verts, got " + ((editable_before - editable_after) as string) + ".")

    for keep_position in editable_keep_positions do
    (
        if TwoVisibleEdgeVerts.findEditablePolyVertexByPosition two_edge_test_editable.baseObject keep_position <= 0 then
        (
            throw ("Editable Poly removed an originally unselected vertex at " + (keep_position as string) + ".")
        )
    )

    select two_edge_test_edit_poly
    max modify mode
    two_edge_test_modifier.SetPrimaryNode two_edge_test_edit_poly
    two_edge_test_modifier.useStackSelection = false
    two_edge_test_modifier.selectMode = 0
    two_edge_test_modifier.showCage = false
    modPanel.setCurrentObject two_edge_test_modifier node:two_edge_test_edit_poly
    two_edge_test_modifier.SetEPolySelLevel #Vertex
    subObjectLevel = 1

    edit_poly_keep_positions = for vertex_index in #(1,3,5,7) collect (EditPolyMod.GetVertex two_edge_test_modifier vertex_index node:two_edge_test_edit_poly)
    edit_poly_before = EditPolyMod.GetNumVertices two_edge_test_modifier node:two_edge_test_edit_poly
    edit_poly_ok = TwoVisibleEdgeVerts.removeTwoEdgeVerts()
    edit_poly_after = EditPolyMod.GetNumVertices two_edge_test_modifier node:two_edge_test_edit_poly

    if not(edit_poly_ok) then throw "Edit Poly RMB removal returned false."
    if edit_poly_before - edit_poly_after != 4 then throw ("Edit Poly expected 4 removed verts, got " + ((edit_poly_before - edit_poly_after) as string) + ".")

    for keep_position in edit_poly_keep_positions do
    (
        if TwoVisibleEdgeVerts.findEditPolyVertexByPosition two_edge_test_edit_poly two_edge_test_modifier keep_position <= 0 then
        (
            throw ("Edit Poly removed an originally unselected vertex at " + (keep_position as string) + ".")
        )
    )

    format "Two Edge RMB TEST PASS | Editable Poly removed:% | Edit Poly removed:%\n" (editable_before - editable_after) (edit_poly_before - edit_poly_after)
    format "UNDO ORDER (top first): Remove 2-Edge Verts [Edit Poly] -> Remove 2-Edge Verts [Editable Poly] -> TEST 2 - Select Even Vertices -> TEST 1 - Create 2-Edge RMB Objects\n"

    true
    -- return
)

loadTestTool()
partOfTest1()
partOfTest2()
partOfTest3()
