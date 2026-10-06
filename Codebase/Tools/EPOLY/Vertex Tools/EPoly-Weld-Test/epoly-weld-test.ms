/*
    EPoly Weld Test 0.01
    Tests selected-vertex Weld, scripted target weld, and native Target Weld mode on Editable Poly and Edit Poly.
*/

global EPolyWeldTest
global EPolyWeldTest_UI
global EPolyToolsIntegration
global EPOLY_TOOLS_RUNTIME_MODE
global EPOLY_TOOLS_MANAGER_PATH
global EPOLY_TOOLS_MANAGER_PREVIOUS_RUNTIME_MODE
global EPOLY_TOOLS_MANAGER_LOAD_ERROR
global EPOLY_TOOLS_MANAGER_SEARCH_DIRECTORY
global EPOLY_TOOLS_MANAGER_PARENT_DIRECTORY
global EPOLY_TOOLS_MANAGER_CANDIDATE_PATH
global EPOLY_TOOLS_MANAGER_SEARCH_DEPTH
global EPOLY_TOOLS_MANAGER_SEARCH_PATH_WITHOUT_SEPARATOR
global epoly_tools_project_version

if EPolyToolsIntegration == undefined then
(
    EPOLY_TOOLS_MANAGER_PATH = undefined
    EPOLY_TOOLS_MANAGER_SEARCH_DIRECTORY = getFilenamePath (getSourceFileName())
    EPOLY_TOOLS_MANAGER_PARENT_DIRECTORY = undefined
    EPOLY_TOOLS_MANAGER_CANDIDATE_PATH = undefined
    EPOLY_TOOLS_MANAGER_SEARCH_DEPTH = 0

    while EPOLY_TOOLS_MANAGER_PATH == undefined and EPOLY_TOOLS_MANAGER_SEARCH_DIRECTORY != "" and EPOLY_TOOLS_MANAGER_SEARCH_DEPTH < 16 do
    (
        EPOLY_TOOLS_MANAGER_CANDIDATE_PATH = EPOLY_TOOLS_MANAGER_SEARCH_DIRECTORY + "PolyToosManager.ms"

        if doesFileExist EPOLY_TOOLS_MANAGER_CANDIDATE_PATH then
        (
            EPOLY_TOOLS_MANAGER_PATH = EPOLY_TOOLS_MANAGER_CANDIDATE_PATH
        )
        else
        (
            EPOLY_TOOLS_MANAGER_SEARCH_PATH_WITHOUT_SEPARATOR = EPOLY_TOOLS_MANAGER_SEARCH_DIRECTORY

            if EPOLY_TOOLS_MANAGER_SEARCH_PATH_WITHOUT_SEPARATOR.count > 0 and EPOLY_TOOLS_MANAGER_SEARCH_PATH_WITHOUT_SEPARATOR[EPOLY_TOOLS_MANAGER_SEARCH_PATH_WITHOUT_SEPARATOR.count] == "\\" then
            (
                EPOLY_TOOLS_MANAGER_SEARCH_PATH_WITHOUT_SEPARATOR = substring EPOLY_TOOLS_MANAGER_SEARCH_PATH_WITHOUT_SEPARATOR 1 (EPOLY_TOOLS_MANAGER_SEARCH_PATH_WITHOUT_SEPARATOR.count - 1)
            )

            EPOLY_TOOLS_MANAGER_PARENT_DIRECTORY = getFilenamePath EPOLY_TOOLS_MANAGER_SEARCH_PATH_WITHOUT_SEPARATOR

            if EPOLY_TOOLS_MANAGER_PARENT_DIRECTORY == EPOLY_TOOLS_MANAGER_SEARCH_DIRECTORY then
            (
                EPOLY_TOOLS_MANAGER_SEARCH_DIRECTORY = ""
            )
            else
            (
                EPOLY_TOOLS_MANAGER_SEARCH_DIRECTORY = EPOLY_TOOLS_MANAGER_PARENT_DIRECTORY
            )
        )

        EPOLY_TOOLS_MANAGER_SEARCH_DEPTH += 1
    )

    EPOLY_TOOLS_MANAGER_PREVIOUS_RUNTIME_MODE = EPOLY_TOOLS_RUNTIME_MODE
    EPOLY_TOOLS_MANAGER_LOAD_ERROR = undefined
    EPOLY_TOOLS_RUNTIME_MODE = #library

    if EPOLY_TOOLS_MANAGER_PATH != undefined then
    (
        try
        (
            fileIn EPOLY_TOOLS_MANAGER_PATH quiet:true -- resolved parent PolyToosManager.ms
        )
        catch
        (
            EPOLY_TOOLS_MANAGER_LOAD_ERROR = getCurrentException()
        )
    )
    else
    (
        EPOLY_TOOLS_MANAGER_LOAD_ERROR = "PolyToosManager.ms was not found in any parent EPolyTools directory."
    )

    EPOLY_TOOLS_RUNTIME_MODE = EPOLY_TOOLS_MANAGER_PREVIOUS_RUNTIME_MODE
    EPOLY_TOOLS_MANAGER_PREVIOUS_RUNTIME_MODE = undefined
    EPOLY_TOOLS_MANAGER_PATH = undefined
    EPOLY_TOOLS_MANAGER_SEARCH_DIRECTORY = undefined
    EPOLY_TOOLS_MANAGER_PARENT_DIRECTORY = undefined
    EPOLY_TOOLS_MANAGER_CANDIDATE_PATH = undefined
    EPOLY_TOOLS_MANAGER_SEARCH_DEPTH = undefined
    EPOLY_TOOLS_MANAGER_SEARCH_PATH_WITHOUT_SEPARATOR = undefined

    if EPOLY_TOOLS_MANAGER_LOAD_ERROR != undefined then
    (
        throw EPOLY_TOOLS_MANAGER_LOAD_ERROR
    )
)

struct EPolyWeldTest_v
(
    file_version = 0.01,
    project_version = 0.19,
    source_vertex = 0,
    target_vertex = 0,
    pair_node = undefined,
    test_normal_node = undefined,
    test_target_node = undefined,
    test_normal_pair = #(),
    test_target_pair = #(),

    /*
    Forces an Editable Poly or Edit Poly target into normal component-selection mode.
    Show Cage is always disabled for project consistency.
    */
    function forceSelectModeZero poly_target =
    (
        if poly_target == undefined then return false

        try(poly_target.selectMode = 0)catch()
        try(poly_target.showCage = false)catch()
        true
        -- return
    ),

    /*
    Returns true when an Edit Poly modifier belongs to the supplied node.
    This prevents acting on an unrelated current modifier.
    */
    function modifierBelongsToNode node modifier =
    (
        if node == undefined or modifier == undefined then return false
        if not(isValidNode node) then return false
        if classOf modifier != Edit_Poly then return false

        for modifier_index = 1 to node.modifiers.count do
        (
            if node.modifiers[modifier_index] == modifier then return true
        )

        false
        -- return
    ),

    /*
    Resolves the active Editable Poly or Edit Poly target for one selected node.
    An active Edit Poly modifier wins; otherwise the Editable Poly base object is used.
    */
    function getSelectionTarget show_message:true =
    (
        if selection.count != 1 then
        (
            if show_message then messageBox "Select exactly one Editable Poly / Edit Poly object." title:"EPoly Weld Test"
            return undefined
        )

        node = selection[1]
        if node == undefined or not(isValidNode node) then return undefined

        current_object = try(modPanel.getCurrentObject())catch(undefined)

        if classOf current_object == Edit_Poly and modifierBelongsToNode node current_object then
        (
            forceSelectModeZero current_object
            return #(#EditPoly, node, current_object)
        )

        if classOf node.baseObject == Editable_Poly then
        (
            forceSelectModeZero node.baseObject
            return #(#EditablePoly, node, node.baseObject)
        )

        if show_message then messageBox "The selected object has no active Edit Poly target and no Editable Poly base object." title:"EPoly Weld Test"
        undefined
        -- return
    ),

    /*
    Sets one Editable Poly vertex selection and makes Vertex sub-object mode visible.
    Selection is written only through polyop.
    */
    function setEditablePolySelection node poly_value vertex_bits =
    (
        if node == undefined or poly_value == undefined then return false
        if classOf node.baseObject != Editable_Poly then return false

        select node
        max modify mode
        forceSelectModeZero poly_value
        try(modPanel.setCurrentObject poly_value)catch()
        polyop.setVertSelection poly_value vertex_bits
        subObjectLevel = 1
        update node
        completeRedraw()

        (polyop.getVertSelection poly_value) == vertex_bits
        -- return
    ),

    /*
    Sets one Edit Poly vertex selection using only the modifier selection API.
    The modifier is made current before the selection is changed.
    */
    function setEditPolySelection node modifier vertex_bits =
    (
        if node == undefined or modifier == undefined then return false
        if not(isValidNode node) or classOf modifier != Edit_Poly then return false

        select node
        max modify mode

        modifier.SetPrimaryNode node
        modifier.useStackSelection = false
        modifier.selectMode = 0
        modifier.showCage = false
        modPanel.setCurrentObject modifier node:node
        modifier.SetEPolySelLevel #Vertex
        subObjectLevel = 1

        old_vertices = modifier.GetSelection #Vertex node:node
        if old_vertices == undefined then old_vertices = #{}

        if old_vertices.numberSet > 0 then
        (
            modifier.Select #Vertex old_vertices select:false node:node
        )

        if vertex_bits.numberSet > 0 then
        (
            modifier.Select #Vertex vertex_bits select:true node:node
        )

        modifier.RefreshScreen()
        update node
        completeRedraw()

        actual_selection = modifier.GetSelection #Vertex node:node
        if actual_selection == undefined then actual_selection = #{}

        actual_selection == vertex_bits
        -- return
    ),

    /*
    Returns the current vertex selection for the supplied EPoly target.
    The result is always a bitArray.
    */
    function getTargetVertexSelection target =
    (
        if target == undefined then return #{}

        target_type = target[1]
        node = target[2]
        target_value = target[3]
        vertex_bits = #{}

        if target_type == #EditablePoly then
        (
            vertex_bits = polyop.getVertSelection target_value
        )
        else if target_type == #EditPoly then
        (
            vertex_bits = target_value.GetSelection #Vertex node:node
            if vertex_bits == undefined then vertex_bits = #{}
        )

        vertex_bits
        -- return
    ),

    /*
    Converts a bitArray into an integer array in ascending component-ID order.
    This gives captured weld pairs a deterministic default direction.
    */
    function bitArrayToArray bits_value =
    (
        values = #()

        for bit_index in bits_value do
        (
            append values bit_index
        )

        values
        -- return
    ),

    /*
    Refreshes the source and target labels when the standalone or embedded rollout exists.
    Missing UI instances are ignored safely.
    */
    function refreshPairUI =
    (
        source_text = if source_vertex > 0 then (source_vertex as string) else "-"
        target_text = if target_vertex > 0 then (target_vertex as string) else "-"

        try(EPolyWeldTest_UI.lbl_source.text = "Source: " + source_text)catch()
        try(EPolyWeldTest_UI.lbl_target.text = "Target: " + target_text)catch()
        true
        -- return
    ),

    /*
    Captures exactly two currently selected vertices as source and target.
    The lower component ID becomes source until SWAP is pressed.
    */
    function captureSelectedPair =
    (
        target = getSelectionTarget()
        if target == undefined then return false

        vertex_bits = getTargetVertexSelection target

        if vertex_bits.numberSet != 2 then
        (
            messageBox "Select exactly two vertices, then capture the pair." title:"EPoly Weld Test"
            return false
        )

        pair_values = bitArrayToArray vertex_bits
        pair_node = target[2]
        source_vertex = pair_values[1]
        target_vertex = pair_values[2]
        refreshPairUI()

        format "EPoly Weld Test | CAPTURE | node:% | source:% | target:%\n" pair_node.name source_vertex target_vertex
        true
        -- return
    ),

    /*
    Swaps the captured source and target vertex IDs.
    This reverses the destination used by scripted target weld.
    */
    function swapPair =
    (
        if source_vertex <= 0 or target_vertex <= 0 then
        (
            messageBox "Capture two vertices first." title:"EPoly Weld Test"
            return false
        )

        old_source = source_vertex
        source_vertex = target_vertex
        target_vertex = old_source
        refreshPairUI()
        true
        -- return
    ),

    /*
    Welds the current vertex selection using the normal threshold-based Weld operation.
    Editable Poly uses polyop; Edit Poly uses its native Weld Vertex button operation.
    */
    function weldSelected threshold:0.1 =
    (
        target = getSelectionTarget()
        if target == undefined then return false

        target_type = target[1]
        node = target[2]
        target_value = target[3]
        vertex_bits = getTargetVertexSelection target

        if vertex_bits.numberSet < 2 then
        (
            messageBox "Select at least two vertices to test Weld." title:"EPoly Weld Test"
            return false
        )

        if threshold < 0.0 then threshold = 0.0
        before_count = 0
        after_count = 0

        undo "EPoly Weld Test - Weld Selected" on
        (
            if target_type == #EditablePoly then
            (
                before_count = polyop.getNumVerts target_value
                target_value.weldThreshold = threshold
                polyop.weldVertsByThreshold target_value vertex_bits
                update node
                after_count = polyop.getNumVerts target_value
            )
            else if target_type == #EditPoly then
            (
                before_count = target_value.GetNumVertices node:node
                setEditPolySelection node target_value vertex_bits
                target_value.weldVertexThreshold = threshold
                target_value.ButtonOp #WeldVertex
                target_value.Commit()
                target_value.RefreshScreen()
                update node
                after_count = target_value.GetNumVertices node:node
            )
        )

        completeRedraw()
        format "EPoly Weld Test | WELD | node:% | target:% | threshold:% | verts:% -> % | welded:%\n" node.name target_type threshold before_count after_count (before_count - after_count)
        after_count < before_count
        -- return
    ),

    /*
    Performs a scripted source-to-target weld from the captured two-vertex pair.
    Editable Poly uses polyop.weldVerts at the target position; Edit Poly moves source onto target then welds the pair.
    */
    function targetWeldCaptured =
    (
        target = getSelectionTarget()
        if target == undefined then return false

        node = target[2]

        if pair_node != node or source_vertex <= 0 or target_vertex <= 0 then
        (
            if not(captureSelectedPair()) then return false
            target = getSelectionTarget()
            if target == undefined then return false
            node = target[2]
        )

        target_type = target[1]
        target_value = target[3]
        before_count = 0
        after_count = 0
        operation_ok = true

        undo "EPoly Weld Test - Target Weld" on
        (
            if target_type == #EditablePoly then
            (
                before_count = polyop.getNumVerts target_value

                if source_vertex > before_count or target_vertex > before_count then
                (
                    operation_ok = false
                )
                else
                (
                    target_position = polyop.getVert target_value target_vertex
                    operation_ok = polyop.weldVerts target_value source_vertex target_vertex target_position
                    update node
                )

                after_count = polyop.getNumVerts target_value
            )
            else if target_type == #EditPoly then
            (
                before_count = target_value.GetNumVertices node:node

                if source_vertex > before_count or target_vertex > before_count then
                (
                    operation_ok = false
                )
                else
                (
                    source_position = target_value.GetVertex source_vertex node:node
                    target_position = target_value.GetVertex target_vertex node:node
                    source_bits = #{source_vertex}

                    setEditPolySelection node target_value source_bits
                    move_amount = target_position - source_position
                    target_value.MoveSelection move_amount
                    target_value.Commit()
                    target_value.WeldVertices source_vertex target_vertex node:node
                    target_value.Commit()
                    target_value.RefreshScreen()
                    update node
                )

                after_count = target_value.GetNumVertices node:node
            )
        )

        completeRedraw()
        operation_ok = operation_ok and (after_count < before_count)
        format "EPoly Weld Test | TARGET WELD | node:% | target:% | source:% | destination:% | verts:% -> % | ok:%\n" node.name target_type source_vertex target_vertex before_count after_count operation_ok

        if operation_ok then
        (
            source_vertex = 0
            target_vertex = 0
            pair_node = undefined
            refreshPairUI()
        )

        operation_ok
        -- return
    ),

    /*
    Enters the native interactive Target Weld command mode for the current vertex target.
    This is useful for comparing scripted pair welding against the actual viewport tool.
    */
    function enterTargetWeldMode =
    (
        target = getSelectionTarget()
        if target == undefined then return false

        target_type = target[1]
        node = target[2]
        target_value = target[3]

        select node
        max modify mode

        if target_type == #EditablePoly then
        (
            forceSelectModeZero target_value
            modPanel.setCurrentObject target_value
            subObjectLevel = 1
            target_value.toggleCommandMode #Weld
        )
        else if target_type == #EditPoly then
        (
            target_value.SetPrimaryNode node
            target_value.useStackSelection = false
            target_value.selectMode = 0
            target_value.showCage = false
            modPanel.setCurrentObject target_value node:node
            target_value.SetEPolySelLevel #Vertex
            subObjectLevel = 1
            target_value.SetOperation #TargetWeldVertex
            target_value.EnterCommandMode #Weld
            target_value.RefreshScreen()
        )

        format "EPoly Weld Test | TARGET WELD MODE | node:% | target:%\n" node.name target_type
        true
        -- return
    ),

    /*
    Creates one Editable Poly plane with one deliberately short or long open border edge.
    The two vertices of that border edge are selected and returned with the node.
    */
    function createTestObjectInternal name_prefix edge_length:0.05 position_value:[0,0,0] =
    (
        test_node = plane name:(uniqueName name_prefix) width:20.0 length:20.0 widthsegs:1 lengthsegs:1 pos:position_value
        convertTo test_node Editable_Poly
        poly_value = test_node.baseObject
        forceSelectModeZero poly_value

        open_edges = polyop.getOpenEdges poly_value
        edge_index = 0

        for current_edge in open_edges while edge_index == 0 do
        (
            edge_index = current_edge
        )

        if edge_index == 0 then return undefined

        edge_vertices = polyop.getEdgeVerts poly_value edge_index
        source_id = edge_vertices[1]
        target_id = edge_vertices[2]
        source_position = polyop.getVert poly_value source_id
        original_target_position = polyop.getVert poly_value target_id
        edge_direction = original_target_position - source_position

        if (length edge_direction) < 0.000001 then
        (
            edge_direction = [1,0,0]
        )
        else
        (
            edge_direction = normalize edge_direction
        )

        new_target_position = source_position + (edge_direction * edge_length)
        polyop.setVert poly_value #{target_id} new_target_position
        test_bits = #{source_id, target_id}
        polyop.setVertSelection poly_value test_bits
        update test_node

        #(#node, test_node, #pair, #(source_id, target_id))
        -- return
    ),

    /*
    Creates a manual weld-test object and leaves its border pair selected.
    The default short edge is inside the rollout's default Weld threshold.
    */
    function createTestObject =
    (
        test_data = undefined

        undo "EPoly Weld Test - Create Test Object" on
        (
            test_data = createTestObjectInternal "EPOLY_WELD_TEST_" edge_length:0.05 position_value:[0,0,0]
        )

        if test_data == undefined then return false

        test_node = test_data[2]
        test_pair = test_data[4]
        select test_node
        setEditablePolySelection test_node test_node.baseObject #{test_pair[1], test_pair[2]}
        source_vertex = test_pair[1]
        target_vertex = test_pair[2]
        pair_node = test_node
        refreshPairUI()
        true
        -- return
    ),

    /*
    Test part 1 creates separate normal-Weld and Target-Weld Editable Poly fixtures.
    Each fixture keeps its test border pair available for later stages.
    */
    function partOfTest1 =
    (
        normal_data = undefined
        target_data = undefined

        undo "EPoly Weld Test 1 - Create Fixtures" on
        (
            normal_data = createTestObjectInternal "EPOLY_WELD_NORMAL_" edge_length:0.05 position_value:[-15,0,0]
            target_data = createTestObjectInternal "EPOLY_TARGET_WELD_" edge_length:5.0 position_value:[15,0,0]
        )

        if normal_data == undefined or target_data == undefined then return false

        test_normal_node = normal_data[2]
        test_target_node = target_data[2]
        test_normal_pair = normal_data[4]
        test_target_pair = target_data[4]
        true
        -- return
    ),

    /*
    Test part 2 performs threshold Weld on the short-edge fixture and verifies a vertex disappears.
    The fixture remains in the welded state for undo inspection.
    */
    function partOfTest2 =
    (
        if test_normal_node == undefined or not(isValidNode test_normal_node) then return false

        select test_normal_node
        pair_bits = #{test_normal_pair[1], test_normal_pair[2]}
        setEditablePolySelection test_normal_node test_normal_node.baseObject pair_bits
        before_count = polyop.getNumVerts test_normal_node.baseObject
        test_normal_node.baseObject.weldThreshold = 0.1

        undo "EPoly Weld Test 2 - Normal Weld" on
        (
            polyop.weldVertsByThreshold test_normal_node.baseObject pair_bits
            update test_normal_node
        )

        after_count = polyop.getNumVerts test_normal_node.baseObject
        test_ok = after_count == (before_count - 1)
        format "EPoly Weld Test AUTO | normal weld | verts:% -> % | PASS:%\n" before_count after_count test_ok
        test_ok
        -- return
    ),

    /*
    Test part 3 performs source-to-target weld on the long-edge fixture and verifies a vertex disappears.
    The scene is intentionally left in this final tested state.
    */
    function partOfTest3 =
    (
        if test_target_node == undefined or not(isValidNode test_target_node) then return false

        poly_value = test_target_node.baseObject
        source_id = test_target_pair[1]
        target_id = test_target_pair[2]
        before_count = polyop.getNumVerts poly_value
        target_position = polyop.getVert poly_value target_id
        weld_ok = false

        undo "EPoly Weld Test 3 - Target Weld" on
        (
            weld_ok = polyop.weldVerts poly_value source_id target_id target_position
            update test_target_node
        )

        after_count = polyop.getNumVerts poly_value
        test_ok = weld_ok and after_count == (before_count - 1)
        select test_target_node
        completeRedraw()

        format "EPoly Weld Test AUTO | target weld | verts:% -> % | PASS:%\n" before_count after_count test_ok
        format "UNDO ORDER: 1) Target Weld  2) Normal Weld  3) Create Fixtures\n"
        test_ok
        -- return
    ),

    /*
    Runs the complete three-stage automated weld comparison test.
    Results print to the Listener and the final scene remains available for visual inspection.
    */
    function runAutomatedTest =
    (
        test_1_ok = partOfTest1()
        if not(test_1_ok) then return false

        test_2_ok = partOfTest2()
        test_3_ok = partOfTest3()
        overall_ok = test_1_ok and test_2_ok and test_3_ok
        format "EPoly Weld Test AUTO | COMPLETE | PASS:%\n" overall_ok
        overall_ok
        -- return
    ),

    /*
    Opens the standalone tool dialog.
    Embedded and library loads can call this explicitly when UI is desired.
    */
    function showUI =
    (
        this.hideUI()
        createDialog EPolyWeldTest_UI style:#(#style_titlebar, #style_sysmenu, #style_toolwindow)
        refreshPairUI()
        true
        -- return
    ),

    /*
    Closes the standalone tool dialog without changing the public API instance.
    */
    function hideUI =
    (
        try(destroyDialog EPolyWeldTest_UI)catch()
        true
        -- return
    ),

    on create do
    (
    )
)

EPolyWeldTest = EPolyWeldTest_v()

rollout EPolyWeldTest_UI "EPoly Weld Test" width:286 height:270
(
    label lbl_info "Vertex weld behavior test" pos:[12,10] width:262 height:18 align:#left
    spinner spn_threshold "Weld threshold:" pos:[12,34] width:210 height:16 range:[0.0,100000.0,0.1] type:#worldunits scale:0.01
    label lbl_units "units" pos:[226,34] width:48 height:16 align:#left
    button btn_weld "WELD SELECTED" pos:[12,58] width:262 height:28 tooltip:"LMB: Run normal threshold-based vertex Weld on the current Editable Poly or Edit Poly vertex selection."
    button btn_capture "CAPTURE 2 SELECTED" pos:[12,92] width:164 height:26 tooltip:"LMB: Capture exactly two selected vertices. Lower ID becomes source; use SWAP to reverse direction."
    button btn_swap "SWAP" pos:[182,92] width:92 height:26 tooltip:"LMB: Swap the captured source and target vertex IDs."
    label lbl_source "Source: -" pos:[12,124] width:126 height:18 align:#left
    label lbl_target "Target: -" pos:[148,124] width:126 height:18 align:#left
    button btn_target "TARGET WELD PAIR" pos:[12,146] width:262 height:28 tooltip:"LMB: Weld the captured source vertex to the captured target vertex. Editable Poly uses polyop.weldVerts at the target position; Edit Poly moves source onto target then welds the pair."
    button btn_target_mode "TARGET WELD MODE" pos:[12,180] width:262 height:28 tooltip:"LMB: Enter the native interactive Target Weld command mode for direct viewport comparison."
    button btn_create "CREATE TEST OBJECT" pos:[12,214] width:128 height:28 tooltip:"LMB: Create an Editable Poly plane with a short open border edge and select its two test vertices."
    button btn_auto "RUN AUTO TEST" pos:[146,214] width:128 height:28 tooltip:"LMB: Create two fixtures, test normal Weld and target weld, print PASS results, and leave the tested scene intact for undo inspection."

    on EPolyWeldTest_UI open do
    (
        EPolyWeldTest.refreshPairUI()
    )

    on btn_weld pressed do
    (
        EPolyWeldTest.weldSelected threshold:spn_threshold.value
    )

    on btn_capture pressed do
    (
        EPolyWeldTest.captureSelectedPair()
    )

    on btn_swap pressed do
    (
        EPolyWeldTest.swapPair()
    )

    on btn_target pressed do
    (
        EPolyWeldTest.targetWeldCaptured()
    )

    on btn_target_mode pressed do
    (
        EPolyWeldTest.enterTargetWeldMode()
    )

    on btn_create pressed do
    (
        EPolyWeldTest.createTestObject()
    )

    on btn_auto pressed do
    (
        EPolyWeldTest.runAutomatedTest()
    )
)

if EPolyToolsIntegration != undefined then
(
    EPolyToolsIntegration.registerTool "epoly-weld-test" "EPoly Weld Test" EPolyWeldTest EPolyWeldTest_UI EPolyWeldTest.file_version EPolyWeldTest.project_version (getSourceFileName()) capabilities:#(#test, #weld, #repair, #selection, #vertex, #editable_poly, #edit_poly, #ui)

    if EPolyToolsIntegration.shouldAutoOpenUI() then EPolyWeldTest.showUI()
)
else
(
    EPolyWeldTest.showUI()
)
