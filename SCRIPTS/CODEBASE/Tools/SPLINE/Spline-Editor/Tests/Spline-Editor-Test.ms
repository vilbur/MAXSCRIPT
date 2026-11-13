/*
Spline Editor - standalone v0.003 operation smoke tests.
File version: 0.003 | Project version: 0.003
Run after loading Spline-Editor-FN.ms. Creates named test objects and retains Undo history.
*/

/*
Creates three open Editable Spline curves with unique positions for isolated tests.
*/
function splineEditorTestCreateShape test_name =
(
    local test_node = splineShape name:(uniqueName test_name)
    for spline_index = 1 to 3 do
    (
        addNewSpline test_node
        local x_value = (spline_index as float) * 40.0
        addKnot test_node spline_index #corner #line [x_value,0,0]
        addKnot test_node spline_index #corner #line [x_value + 15.0,0,0]
        addKnot test_node spline_index #corner #line [x_value + 30.0,0,0]
    )
    updateShape test_node
    test_node
    -- return
)

/*
Displays a PASS/FAIL result without confusing a failed API with an empty selection.
*/
function splineEditorTestCheck label_text expected_value actual_value =
(
    local test_ok = expected_value == actual_value
    format "SPLINE-EDITOR TEST | % | expected:% actual:% PASS:%\n" label_text expected_value actual_value test_ok
    test_ok
    -- return
)

/*
Runs independent tests for segment division, material IDs and detach variants.
*/
function splineEditorTestRun =
(
    local original_selection = selection as array
    local original_level = subObjectLevel
    local successful_tests = 0
    local total_tests = 0
    local target_node = splineEditorTestCreateShape "SE_TEST_BASE_"
    select target_node
    max modify mode

    subObjectLevel = 2
    setSegSelection target_node 1 #(1)
    local before_segments = numSegments target_node 1
    local division_ok = SplineEditor.divideSelected 2
    total_tests += 1
    if (splineEditorTestCheck "Divide 2" (before_segments + 2) (numSegments target_node 1)) and division_ok then successful_tests += 1

    subObjectLevel = 3
    setSplineSelection target_node #(2,3)
    local id_ok = SplineEditor.assignSplineMaterialIDs all_splines:false
    total_tests += 1
    if (splineEditorTestCheck "Spline 2 ID" 1 (getMaterialID target_node 2 1)) and id_ok then successful_tests += 1
    total_tests += 1
    if (splineEditorTestCheck "Spline 3 ID" 2 (getMaterialID target_node 3 1)) and id_ok then successful_tests += 1

    setSplineSelection target_node #(2)
    local before_splines = numSplines target_node
    local duplicate_ok = SplineEditor.duplicateSplinesInside()
    total_tests += 1
    if (splineEditorTestCheck "Spline copy inside" (before_splines + 1) (numSplines target_node)) and duplicate_ok then successful_tests += 1

    select target_node
    setSplineSelection target_node #(1)
    local object_copy_ok = SplineEditor.detachToObject true
    total_tests += 1
    if (splineEditorTestCheck "Object clone retains source" (before_splines + 1) (numSplines target_node)) and object_copy_ok then successful_tests += 1

    select target_node
    subObjectLevel = 3
    setSplineSelection target_node #(3)
    local count_before_move = numSplines target_node
    local object_move_ok = SplineEditor.detachToObject false
    total_tests += 1
    if (splineEditorTestCheck "Detach to object moves curve" (count_before_move - 1) (numSplines target_node)) and object_move_ok then successful_tests += 1

    local source_a = splineEditorTestCreateShape "SE_TEST_ATTACH_A_"
    local source_b = splineEditorTestCreateShape "SE_TEST_ATTACH_B_"
    local count_before_attach = numSplines source_a
    select #(source_a,source_b)
    local attach_ok = SplineEditor.attachSelectedObjects()
    total_tests += 1
    if (splineEditorTestCheck "Attach Selected" (count_before_attach + 3) (numSplines source_a)) and attach_ok then successful_tests += 1

    format "SPLINE-EDITOR TEST SUMMARY | Passed:% Total:%\n" successful_tests total_tests
    format "SPLINE-EDITOR TEST NOTE | Interactive Cross Insert, native Detach dialog, renderer UI state and left/right docking need manual verification.\n"
    if original_selection.count > 0 then
    (
        select original_selection
    )
    else
    (
        clearSelection()
    )
    if original_level != undefined then
    (
        subObjectLevel = original_level
    )
    successful_tests == total_tests
    -- return
)

splineEditorTestRun()
