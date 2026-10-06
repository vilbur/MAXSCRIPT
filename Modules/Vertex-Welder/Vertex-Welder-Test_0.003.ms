/*
    Vertex Welder Test 0.003
    Executable regression coverage for WELD, PER ELEMENT, and BORDERS on Editable Poly and Edit Poly.
*/

global vertex_welder_test_file_version = 0.003
global vertex_welder_test_project_version = 0.003
global vertex_welder_test_directory = getFilenamePath (getSourceFileName())
global vertex_welder_test_script_path = vertex_welder_test_directory + "Vertex-Welder_0.003.ms"
global vertex_welder_test_failures = #()
global vertex_welder_test_nodes = #()

if not doesFileExist vertex_welder_test_script_path then
(
    throw ("Missing production script: " + vertex_welder_test_script_path)
)

fileIn vertex_welder_test_script_path quiet:true

/*
Records one test failure when the supplied condition is false.
Returns the same Boolean condition value.
*/
function vertexWelderTestAssert condition_value message_text =
(
    if not condition_value then
    (
        append vertex_welder_test_failures message_text
        format "FAIL | %\n" message_text
    )
    else
    (
        format "PASS | %\n" message_text
    )

    condition_value
    -- return
)

/*
Deletes one previous test node by exact name when it exists.
*/
function vertexWelderTestDeleteNamedNode node_name =
(
    existing_node = getNodeByName node_name exact:true

    if isValidNode existing_node then delete existing_node

    true
    -- return
)

/*
Creates one production fixture, offsets it for inspection, and optionally adds Edit Poly.
Returns #(node, target_data).
*/
function vertexWelderTestCreateFixture mode_value node_name position_value add_edit_poly:false =
(
    vertexWelderTestDeleteNamedNode node_name

    fixture_node = undefined
    threshold_mm = 0.1

    if mode_value == #weld then fixture_node = VertexWelder.createWeldFixture node_name threshold_mm
    if mode_value == #per_element then fixture_node = VertexWelder.createPerElementFixture node_name threshold_mm
    if mode_value == #borders then fixture_node = VertexWelder.createBordersFixture node_name threshold_mm

    if not isValidNode fixture_node then return undefined

    fixture_node.pos = position_value

    if add_edit_poly then
    (
        edit_poly_mod = Edit_Poly()
        edit_poly_mod.name = node_name + " EDIT POLY"
        edit_poly_mod.showCage = off
        addModifier fixture_node edit_poly_mod
    )

    append vertex_welder_test_nodes fixture_node
    target_data = VertexWelder.getTargetFromNode fixture_node prefer_active:false

    #(fixture_node, target_data)
    -- return
)

/*
Runs one production weld mode and verifies expected weld and element-count results.
*/
function vertexWelderTestRunCase case_label target_data mode_value expected_welds expected_elements =
(
    if target_data == undefined then
    (
        vertexWelderTestAssert false (case_label + " target was not resolved.")
        return false
    )

    before_count = VertexWelder.getVertexCount target_data
    before_elements = VertexWelder.getElementCount target_data
    welded_count = VertexWelder.runModeOnTarget target_data mode_value 0.1 debug:true
    after_count = VertexWelder.getVertexCount target_data
    after_elements = VertexWelder.getElementCount target_data

    format "CASE | % | verts:% -> % | elements:% -> % | welded:% | status:%\n" case_label before_count after_count before_elements after_elements welded_count VertexWelder.last_message

    count_ok = vertexWelderTestAssert (welded_count == expected_welds) (case_label + " welded-count contract.")
    vertex_ok = vertexWelderTestAssert (after_count == (before_count - expected_welds)) (case_label + " vertex-count contract.")
    element_ok = vertexWelderTestAssert (after_elements == expected_elements) (case_label + " element-count contract.")

    count_ok and vertex_ok and element_ok
    -- return
)

/*
Test part 1 creates all six source fixtures and leaves them arranged in the scene.
*/
function partOfTest1 =
(
    vertex_welder_test_nodes = #()

    undo "Vertex Welder Test 1 - Create Fixtures" on
    (
        vertexWelderTestCreateFixture #weld "VW_TEST_WELD_EDITABLE" [-60,30,0] add_edit_poly:false
        vertexWelderTestCreateFixture #per_element "VW_TEST_ELEMENT_EDITABLE" [0,30,0] add_edit_poly:false
        vertexWelderTestCreateFixture #borders "VW_TEST_BORDERS_EDITABLE" [60,30,0] add_edit_poly:false

        vertexWelderTestCreateFixture #weld "VW_TEST_WELD_EDITPOLY" [-60,-30,0] add_edit_poly:true
        vertexWelderTestCreateFixture #per_element "VW_TEST_ELEMENT_EDITPOLY" [0,-30,0] add_edit_poly:true
        vertexWelderTestCreateFixture #borders "VW_TEST_BORDERS_EDITPOLY" [60,-30,0] add_edit_poly:true
    )

    vertexWelderTestAssert (vertex_welder_test_nodes.count == 6) "Part 1 created six test fixtures."

    if vertex_welder_test_nodes.count == 6 then select vertex_welder_test_nodes

    completeRedraw()
    true
    -- return
)

/*
Test part 2 executes all three modes on Editable Poly fixtures.
*/
function partOfTest2 =
(
    weld_node = getNodeByName "VW_TEST_WELD_EDITABLE" exact:true
    element_node = getNodeByName "VW_TEST_ELEMENT_EDITABLE" exact:true
    border_node = getNodeByName "VW_TEST_BORDERS_EDITABLE" exact:true

    if not isValidNode weld_node or not isValidNode element_node or not isValidNode border_node then
    (
        throw "Part 1 Editable Poly fixtures are missing."
    )

    weld_target = VertexWelder.getTargetFromNode weld_node prefer_active:false
    element_target = VertexWelder.getTargetFromNode element_node prefer_active:false
    border_target = VertexWelder.getTargetFromNode border_node prefer_active:false

    undo "Vertex Welder Test 2A - Editable WELD" on
    (
        vertexWelderTestRunCase "Editable WELD" weld_target #weld 2 1
    )

    undo "Vertex Welder Test 2B - Editable PER ELEMENT" on
    (
        vertexWelderTestRunCase "Editable PER ELEMENT" element_target #per_element 1 2
    )

    undo "Vertex Welder Test 2C - Editable BORDERS" on
    (
        vertexWelderTestRunCase "Editable BORDERS" border_target #borders 2 1
    )

    true
    -- return
)

/*
Test part 3 executes all three modes on Edit Poly modifier fixtures.
*/
function partOfTest3 =
(
    weld_node = getNodeByName "VW_TEST_WELD_EDITPOLY" exact:true
    element_node = getNodeByName "VW_TEST_ELEMENT_EDITPOLY" exact:true
    border_node = getNodeByName "VW_TEST_BORDERS_EDITPOLY" exact:true

    if not isValidNode weld_node or not isValidNode element_node or not isValidNode border_node then
    (
        throw "Part 1 Edit Poly fixtures are missing."
    )

    weld_target = VertexWelder.getTargetFromNode weld_node prefer_active:false
    element_target = VertexWelder.getTargetFromNode element_node prefer_active:false
    border_target = VertexWelder.getTargetFromNode border_node prefer_active:false

    undo "Vertex Welder Test 3A - Edit Poly WELD" on
    (
        vertexWelderTestRunCase "Edit Poly WELD" weld_target #weld 2 1
    )

    undo "Vertex Welder Test 3B - Edit Poly PER ELEMENT" on
    (
        vertexWelderTestRunCase "Edit Poly PER ELEMENT" element_target #per_element 1 2
    )

    undo "Vertex Welder Test 3C - Edit Poly BORDERS" on
    (
        vertexWelderTestRunCase "Edit Poly BORDERS" border_target #borders 2 1
    )

    true
    -- return
)

/*
Test part 4 reports the final regression result and documents the undo sequence.
*/
function partOfTest4 =
(
    completeRedraw()

    if vertex_welder_test_failures.count > 0 then
    (
        format "Vertex Welder Test 0.003 | FAILED | % failure(s).\n" vertex_welder_test_failures.count

        for failure_text in vertex_welder_test_failures do
        (
            format "FAILURE | %\n" failure_text
        )

        format "UNDO ORDER | Edit Poly BORDERS -> Edit Poly PER ELEMENT -> Edit Poly WELD -> Editable BORDERS -> Editable PER ELEMENT -> Editable WELD -> Create Fixtures.\n"
        throw ("Vertex Welder regression failed: " + (vertex_welder_test_failures.count as string) + " failure(s).")
    )
    else
    (
        format "Vertex Welder Test 0.003 | PASS | all six mode/target cases passed.\n"
        format "UNDO ORDER | Edit Poly BORDERS -> Edit Poly PER ELEMENT -> Edit Poly WELD -> Editable BORDERS -> Editable PER ELEMENT -> Editable WELD -> Create Fixtures.\n"
    )

    true
    -- return
)

-- EXECUTION QUEUE
partOfTest1()
partOfTest2()
partOfTest3()
partOfTest4()
