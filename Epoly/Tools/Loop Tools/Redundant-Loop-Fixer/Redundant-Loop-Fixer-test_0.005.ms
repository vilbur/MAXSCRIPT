/*
    Redundant-Loop-Fixer regression test 0.005
    Shared project version 1.138
*/

global epoly_tools_project_version
global RedundantLoopFixerTestFileVersion = 0.005
global RedundantLoopFixerTestProjectVersion = 1.138
global RedundantLoopFixerTestNodes = #()
global RedundantLoopFixerTestPassed = true

if epoly_tools_project_version == undefined or epoly_tools_project_version < RedundantLoopFixerTestProjectVersion then
(
    epoly_tools_project_version = RedundantLoopFixerTestProjectVersion
)

/*
Loads the canonical tool and builds the persistent viewport test scene.
The created objects remain in the scene so later stages and Undo can be inspected manually.
*/
function partOfTest1 =
(
    source_directory = getFilenamePath (getSourceFileName())
    source_path = source_directory + "Redundant-Loop-Fixer.ms"

    if not(doesFileExist source_path) then throw ("Missing canonical source: " + source_path)

    fileIn source_path quiet:true

    if RedundantLoopFixer == undefined then throw "RedundantLoopFixer did not load"
    RedundantLoopFixer.hideUI()

    RedundantLoopFixerTestNodes = #()
    RedundantLoopFixerTestPassed = true

    undo "RLF TEST 1 - Build Scene" on
    (
        plain_data = RedundantLoopFixer.createDividerTestObject creased:false x_offset:0.0
        plain_node = plain_data[1]
        plain_node.name = uniqueName "RLF_TEST_PLAIN_"
        append RedundantLoopFixerTestNodes plain_node

        crease_data = RedundantLoopFixer.createDividerTestObject creased:true x_offset:25.0
        crease_node = crease_data[1]
        crease_node.name = uniqueName "RLF_TEST_CREASE_"
        append RedundantLoopFixerTestNodes crease_node

        corner_data = RedundantLoopFixer.createBorderCornerTestObject x_offset:50.0
        corner_node = corner_data[1]
        corner_node.name = uniqueName "RLF_TEST_BORDER_CORNER_"
        append RedundantLoopFixerTestNodes corner_node

    )

    select RedundantLoopFixerTestNodes
    completeRedraw()
    format "RLF TEST 1 | scene objects:% | PASSED:true\n" RedundantLoopFixerTestNodes.count
    true
    -- return
)

/*
Runs non-destructive production selection plus native-loop, debug-remap, and evaluated-stack regressions.
Selection modifiers and diagnostic test objects are intentionally left in the scene for viewport inspection.
*/
function partOfTest2 =
(
    if RedundantLoopFixer == undefined then throw "Run partOfTest1() first"
    if RedundantLoopFixerTestNodes.count < 3 then throw "RLF test scene is incomplete"

    plain_node = RedundantLoopFixerTestNodes[1]
    crease_node = RedundantLoopFixerTestNodes[2]
    corner_node = RedundantLoopFixerTestNodes[3]

    stage_ok = true

    undo "RLF TEST 2 - Selection Regressions" on
    (
        plain_result = RedundantLoopFixer.selectRedundantLoopsOnNode plain_node face_threshold:0.1 straight_threshold:5.0 debug_output:true select_debug_output:true
        plain_ok = plain_result[1] and plain_result[3] > 0 and plain_result[5] != undefined
        format "RLF TEST 2A | planar divider selected:% | loops:% | edges:% | error:%\n" plain_ok plain_result[2] plain_result[3] plain_result[4]
        if not plain_ok then stage_ok = false

        crease_result = RedundantLoopFixer.selectRedundantLoopsOnNode crease_node face_threshold:0.1 straight_threshold:5.0 debug_output:true select_debug_output:true
        crease_ok = crease_result[1] and crease_result[3] == 0
        format "RLF TEST 2B | creased divider rejected:% | edges:% | error:%\n" crease_ok crease_result[3] crease_result[4]
        if not crease_ok then stage_ok = false

        corner_result = RedundantLoopFixer.selectRedundantLoopsOnNode corner_node face_threshold:0.1 straight_threshold:5.0 debug_output:true select_debug_output:true
        corner_ok = corner_result[1] and corner_result[3] == 0
        format "RLF TEST 2C | border-corner divider rejected:% | edges:% | error:%\n" corner_ok corner_result[3] corner_result[4]
        if not corner_ok then stage_ok = false

        native_multi_result = RedundantLoopFixer.testNativeEditablePolyMultiEdgeLoop()
        native_multi_node = native_multi_result[2]
        if native_multi_node != undefined then
        (
            native_multi_node.name = uniqueName "RLF_TEST_NATIVE_MULTI_"
            append RedundantLoopFixerTestNodes native_multi_node
        )
        format "RLF TEST 2D | native EditablePoly multi-edge loop expansion:% | error:%\n" native_multi_result[1] native_multi_result[3]
        if not native_multi_result[1] then stage_ok = false

        detection_result = RedundantLoopFixer.testNativeEditablePolyLoopPath()
        detection_node = detection_result[2]
        if detection_node != undefined then
        (
            detection_node.name = uniqueName "RLF_TEST_EPOLY_DETECTION_"
            append RedundantLoopFixerTestNodes detection_node
        )
        format "RLF TEST 2E | native EditablePoly loop path keeps valid singleton divider:% | error:%\n" detection_result[1] detection_result[3]
        if not detection_result[1] then stage_ok = false

        debug_result = RedundantLoopFixer.testDebugSelectionMapping()
        debug_node = debug_result[2]
        if debug_node != undefined then
        (
            debug_node.name = uniqueName "RLF_TEST_DEBUG_REMAP_"
            append RedundantLoopFixerTestNodes debug_node
        )
        format "RLF TEST 2F | debug analysis/live remap:% | error:%\n" debug_result[1] debug_result[3]
        if not debug_result[1] then stage_ok = false

        evaluated_result = RedundantLoopFixer.testEvaluatedAnalysisUsesTopOfStack()
        evaluated_node = evaluated_result[2]
        if evaluated_node != undefined then
        (
            evaluated_node.name = uniqueName "RLF_TEST_EVALUATED_STACK_"
            append RedundantLoopFixerTestNodes evaluated_node
        )
        format "RLF TEST 2G | true evaluated top-of-stack analysis:% | error:%\n" evaluated_result[1] evaluated_result[3]
        if not evaluated_result[1] then stage_ok = false

        zero_data = RedundantLoopFixer.createDividerTestObject creased:false x_offset:215.0
        zero_node = zero_data[1]
        zero_edge = zero_data[2]
        zero_node.name = uniqueName "RLF_TEST_ZERO_CLEAR_"
        append RedundantLoopFixerTestNodes zero_node

        first_zero_result = RedundantLoopFixer.selectRedundantLoopsOnNode zero_node face_threshold:0.1 straight_threshold:5.0 debug_output:true select_debug_output:true
        zero_selector = first_zero_result[5]
        first_zero_selection = if zero_selector != undefined then copy (zero_selector.GetSelection #Edge node:zero_node) else #{}

        zero_poly = zero_node.baseObject
        if not(polyop.getEDataChannelSupport zero_poly 2) then polyop.setEDataChannelSupport zero_poly 2 true
        polyop.setEDataValue zero_poly 2 #{zero_edge} 1.0
        update zero_node

        second_zero_result = RedundantLoopFixer.selectRedundantLoopsOnNode zero_node face_threshold:0.1 straight_threshold:5.0 debug_output:true select_debug_output:true
        second_zero_selection = if zero_selector != undefined then copy (zero_selector.GetSelection #Edge node:zero_node) else #{1}
        zero_clear_ok = first_zero_result[1] and first_zero_selection.numberSet > 0 and second_zero_result[1] and second_zero_result[3] == 0 and second_zero_selection.numberSet == 0 and second_zero_result[5] == zero_selector
        format "RLF TEST 2H | zero-result LMB clears stale SELECT REDUNDANT LOOPS edges:% | before:% | after:% | error:%\n" zero_clear_ok first_zero_selection second_zero_selection second_zero_result[4]
        if not zero_clear_ok then stage_ok = false

        no_selector_data = RedundantLoopFixer.createBorderCornerTestObject x_offset:240.0
        no_selector_node = no_selector_data[1]
        no_selector_node.name = uniqueName "RLF_TEST_ZERO_NO_SELECTOR_"
        append RedundantLoopFixerTestNodes no_selector_node
        no_selector_before = RedundantLoopFixer.findSelectionModifier no_selector_node
        no_selector_result = RedundantLoopFixer.selectRedundantLoopsOnNode no_selector_node face_threshold:0.1 straight_threshold:5.0 debug_output:true select_debug_output:true
        no_selector_after = RedundantLoopFixer.findSelectionModifier no_selector_node
        no_selector_ok = no_selector_before == undefined and no_selector_result[1] and no_selector_result[3] == 0 and no_selector_after == undefined and no_selector_result[5] == undefined
        format "RLF TEST 2I | zero-result does not create selector:% | error:%\n" no_selector_ok no_selector_result[4]
        if not no_selector_ok then stage_ok = false

        live_data = RedundantLoopFixer.createDividerTestObject creased:false x_offset:270.0
        live_node = live_data[1]
        live_edge = live_data[2]
        live_node.name = uniqueName "RLF_TEST_CURRENT_EDIT_POLY_"
        append RedundantLoopFixerTestNodes live_node
        live_edit_poly = Edit_Poly name:"RLF TEST CURRENT EDIT POLY"
        live_edit_poly.showCage = false
        addModifier live_node live_edit_poly
        select live_node
        max modify mode
        live_edit_poly.SetPrimaryNode live_node
        live_edit_poly.useStackSelection = false
        live_edit_poly.selectMode = 0
        live_edit_poly.showCage = false
        modPanel.setCurrentObject live_edit_poly node:live_node
        live_detection = RedundantLoopFixer.detectRedundantLoops live_node face_threshold:0.1 near_face_threshold:1.0 straight_threshold:5.0 debug_output:true
        live_select_result = RedundantLoopFixer.selectRedundantLoopsOnNode live_node face_threshold:0.1 straight_threshold:5.0 debug_output:true select_debug_output:true
        live_selector = live_select_result[5]
        source_index = 0
        selector_index = 0

        for stack_index = 1 to live_node.modifiers.count do
        (
            if live_node.modifiers[stack_index] == live_edit_poly then source_index = stack_index
            if live_node.modifiers[stack_index] == live_selector then selector_index = stack_index
        )

        live_current_ok = live_detection[1] and live_detection.count >= 7 and live_detection[7] == #edit_poly and live_detection[3][live_edge] and live_select_result[1] and live_selector != undefined and selector_index > 0 and source_index > 0 and selector_index < source_index
        format "RLF TEST 2J | current Edit Poly analyzed directly and selector inserted above it:% | source:% | selectorIndex:% | sourceIndex:% | error:%\n" live_current_ok live_detection[7] selector_index source_index live_select_result[4]
        if not live_current_ok then stage_ok = false
    )

    if not stage_ok then RedundantLoopFixerTestPassed = false
    select RedundantLoopFixerTestNodes
    completeRedraw()
    format "RLF TEST 2 | PASSED:%\n" stage_ok
    stage_ok
    -- return
)

/*
Runs the destructive RMB contract plus the explicit no-op failure case.
The removed and no-op objects remain selected in their final tested state for manual inspection.
*/
function partOfTest3 =
(
    if RedundantLoopFixer == undefined then throw "Run partOfTest1() first"

    stage_ok = true
    remove_node = undefined
    no_op_node = undefined

    undo "RLF TEST 3 - RMB Setup" on
    (
        remove_data = RedundantLoopFixer.createDividerTestObject creased:false x_offset:245.0
        remove_node = remove_data[1]
        remove_node.name = uniqueName "RLF_TEST_RMB_REMOVE_"
        append RedundantLoopFixerTestNodes remove_node

        no_op_data = RedundantLoopFixer.createBorderCornerTestObject x_offset:270.0
        no_op_node = no_op_data[1]
        no_op_node.name = uniqueName "RLF_TEST_RMB_NO_OP_"
        append RedundantLoopFixerTestNodes no_op_node
    )

    select remove_node
    select_result = RedundantLoopFixer.selectRedundantLoopsOnNode remove_node face_threshold:0.1 straight_threshold:5.0 debug_output:true select_debug_output:true
    remove_selector = select_result[5]
    before_vertices = if remove_selector != undefined then EditPolyMod.GetNumVertices remove_selector node:remove_node else 0
    before_edges = if remove_selector != undefined then EditPolyMod.GetNumEdges remove_selector node:remove_node else 0
    remove_result = RedundantLoopFixer.removeSelectedRedundantLoops face_threshold:0.1 straight_threshold:5.0
    after_vertices = if remove_selector != undefined then EditPolyMod.GetNumVertices remove_selector node:remove_node else before_vertices
    after_edges = if remove_selector != undefined then EditPolyMod.GetNumEdges remove_selector node:remove_node else before_edges
    remove_ok = select_result[1] and remove_selector != undefined and remove_result and after_vertices < before_vertices and after_edges < before_edges
    format "RLF TEST 3A | RMB topology removal:% | verts:%->% | edges:%->%\n" remove_ok before_vertices after_vertices before_edges after_edges
    if not remove_ok then stage_ok = false

    select no_op_node
    no_op_result = RedundantLoopFixer.removeSelectedRedundantLoops face_threshold:0.1 straight_threshold:5.0
    no_op_ok = not no_op_result
    format "RLF TEST 3B | RMB no-op reports failure:%\n" no_op_ok
    if not no_op_ok then stage_ok = false

    if not stage_ok then RedundantLoopFixerTestPassed = false

    select #(remove_node, no_op_node)
    completeRedraw()

    format "RLF TEST 3 | PASSED:%\n" stage_ok
    format "RLF TEST COMPLETE | PASSED:%\n" RedundantLoopFixerTestPassed
    format "UNDO ORDER:\n"
    format "  1. Remove Redundant Loops - restores RMB geometry.\n"
    format "  2. RLF TEST 3 - RMB Setup - removes the RMB test objects.\n"
    format "  3. RLF TEST 2 - Selection Regressions - removes test selection/debug changes.\n"
    format "  4. RLF TEST 1 - Build Scene - removes the base regression scene.\n"

    stage_ok
    -- return
)

/*
Checks the real Object019 ground-truth edge set supplied from the production scene.
The expected selection is the union of the user-confirmed redundant-loop edge commands; missing and extra IDs are printed explicitly.
*/
function partOfTest4 =
(
    if RedundantLoopFixer == undefined then throw "Run partOfTest1() first"

    target_node = getNodeByName "Object019"

    if target_node == undefined then
    (
        format "RLF TEST 4 | Object019 not found | SKIPPED:true\n"
        return true
    )

    expected_edges = #{2..6, 10, 12..14, 16..17, 19..20, 23..24, 26..27, 29..31, 33, 35, 37..38, 46..48, 55, 58, 60, 64, 66, 69, 72, 74, 78, 80, 82, 84, 86, 89, 91, 93..94, 103..104, 108..109}
    stage_ok = false

    undo "RLF TEST 4 - Object019 Ground Truth" on
    (
        select target_node
        result_data = RedundantLoopFixer.selectRedundantLoopsOnNode target_node face_threshold:0.1 straight_threshold:20.0 debug_output:true select_debug_output:true
        actual_edges = if result_data[1] and result_data[5] != undefined then copy (result_data[5].GetSelection #Edge node:target_node) else #{}
        missing_edges = expected_edges - actual_edges
        extra_edges = actual_edges - expected_edges
        stage_ok = result_data[1] and actual_edges == expected_edges

        format "RLF TEST 4 | Object019 ground truth:% | expected:% | actual:%\n" stage_ok expected_edges actual_edges
        format "RLF TEST 4 | missing:% | extra:% | error:%\n" missing_edges extra_edges result_data[4]
    )

    if not stage_ok then RedundantLoopFixerTestPassed = false
    format "RLF TEST COMPLETE | PASSED:%\n" RedundantLoopFixerTestPassed
    format "UNDO ORDER ADDITION:\n"
    format "  1. RLF TEST 4 - Object019 Ground Truth - restores Object019 selector state.\n"

    stage_ok
    -- return
)

partOfTest1()
partOfTest2()
partOfTest3()
partOfTest4()
