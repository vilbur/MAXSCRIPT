/* Missing Loop Rebuilder dead-topology regression
   Version 0.001 | Project 1.130 */

global missingLoopRebuilderTestVersion = 0.001
global missingLoopRebuilderTestProjectVersion = 1.130

/* Loads the canonical tool from this test file directory. */
function partOfTest1 =
(
    test_directory = getFilenamePath (getSourceFileName())
    tool_path = test_directory + "Missing-Loop-Rebuilder.ms"

    if not doesFileExist tool_path then throw ("MLR Test: missing tool: " + tool_path)
    fileIn tool_path quiet:true

    if MissingLoopRebuilder == undefined then throw "MLR Test: tool API was not created."
    true
    -- return
)

/* Creates dirty Editable Poly topology and verifies the next ID phase synchronizes it. */
function partOfTest2 =
(
    undo "MLR Dead Topology Sync Test" on
    (
        test_node = MissingLoopRebuilder.createTestGrid x_segments:4 y_segments:4
        test_node.name = "MLR_DEAD_TOPOLOGY_TEST"

        if not MissingLoopRebuilder.ensureCleanEditablePolyTopology test_node then throw "MLR Test: initial topology synchronization failed."

        poly_value = test_node.baseObject
        edge_count = polyop.getNumEdges poly_value
        internal_edge_id = 0

        for edge_index = 1 to edge_count while internal_edge_id == 0 do
        (
            edge_faces = polyop.getFacesUsingEdge poly_value edge_index
            if edge_faces.numberSet == 2 then internal_edge_id = edge_index
        )

        if internal_edge_id == 0 then throw "MLR Test: no internal edge found."

        polyop.deleteEdges poly_value #{internal_edge_id} delIsoVerts:false
        update test_node

        border_verts = MissingLoopRebuilder.getBorderVerts test_node

        if polyop.getHasDeadStructs poly_value != 0 then throw "MLR Test: dead topology survived an index-sensitive phase boundary."
        if classOf border_verts != BitArray then throw "MLR Test: border vertex result is not a BitArray."

        select test_node
        true
    )
    -- return
)

/* Verifies Edit Poly stacks are rejected instead of compacting the base topology underneath them. */
function partOfTest3 =
(
    undo "MLR Edit Poly Guard Test" on
    (
        test_node = MissingLoopRebuilder.createTestGrid x_segments:4 y_segments:4
        test_node.name = "MLR_EDIT_POLY_GUARD_TEST"
        edit_poly_mod = Edit_Poly()
        addModifier test_node edit_poly_mod

        if MissingLoopRebuilder.isSupportedNode test_node then throw "MLR Test: Edit Poly stack was accepted by base Editable Poly path."
        if MissingLoopRebuilder.ensureCleanEditablePolyTopology test_node then throw "MLR Test: cleanup was allowed underneath Edit Poly."

        select test_node
        true
    )
    -- return
)

partOfTest1()
partOfTest2()
partOfTest3()

format "MLR dead-topology regression complete. Undo order: Edit Poly guard test, dead topology sync test.\n"
