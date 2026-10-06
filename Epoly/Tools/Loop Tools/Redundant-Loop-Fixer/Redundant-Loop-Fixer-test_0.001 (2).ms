/*
    Redundant-Loop-Fixer regression test 0.001
    Shared project version 1.131
*/

global epoly_tools_project_version
global RedundantLoopFixerTestFileVersion = 0.001
global RedundantLoopFixerTestProjectVersion = 1.131
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

        native_node = RedundantLoopFixer.createNativeLoopGridTestObject x_offset:80.0
        native_node.name = uniqueName "RLF_TEST_NATIVE_GRID_"
        append RedundantLoopFixerTestNodes native_node
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
    if RedundantLoopFixerTestNodes.count < 4 then throw "RLF test scene is incomplete"

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

        native_result = RedundantLoopFixer.testNativeLoopPreservation()
        native_node = native_result[2]
        if native_node != undefined then
        (
            native_node.name = uniqueName "RLF_TEST_NATIVE_WHOLE_LOOP_"
            append RedundantLoopFixerTestNodes native_node
        )
        format "RLF TEST 2D | native loop preserved whole:% | error:%\n" native_result[1] native_result[3]
        if not native_result[1] then stage_ok = false

        debug_result = RedundantLoopFixer.testDebugSelectionMapping()
        debug_node = debug_result[2]
        if debug_node != undefined then
        (
            debug_node.name = uniqueName "RLF_TEST_DEBUG_REMAP_"
            append RedundantLoopFixerTestNodes debug_node
        )
        format "RLF TEST 2E | debug analysis/live remap:% | error:%\n" debug_result[1] debug_result[3]
        if not debug_result[1] then stage_ok = false

        evaluated_result = RedundantLoopFixer.testEvaluatedAnalysisUsesTopOfStack()
        evaluated_node = evaluated_result[2]
        if evaluated_node != undefined then
        (
            evaluated_node.name = uniqueName "RLF_TEST_EVALUATED_STACK_"
            append RedundantLoopFixerTestNodes evaluated_node
        )
        format "RLF TEST 2F | true evaluated top-of-stack analysis:% | error:%\n" evaluated_result[1] evaluated_result[3]
        if not evaluated_result[1] then stage_ok = false
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

partOfTest1()
partOfTest2()
partOfTest3()
