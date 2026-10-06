/*
    Vertex Welder Test 0.016
    Executable regression coverage for WELD, PER ELEMENT, and BORDERS on Editable Poly and Edit Poly.
*/

global vertex_welder_test_file_version = 0.016
global vertex_welder_test_project_version = 0.016
global vertex_welder_test_directory = getFilenamePath (getSourceFileName())
global vertex_welder_test_script_path = vertex_welder_test_directory + "..\\Vertex-Welder.ms"
global vertex_welder_main_script_path = vertex_welder_test_script_path
global vertex_welder_test_failures = #()
global vertex_welder_test_nodes = #()
global dialog_host_registry

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
        edit_poly_mod.useStackSelection = false
        edit_poly_mod.selectMode = 0
        addModifier fixture_node edit_poly_mod
        edit_poly_mod.SetPrimaryNode fixture_node
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

    if target_data[1] == #edit_poly then
    (
        if not(VertexWelder.prepareEditPolyVertexContext target_data) then
        (
            vertexWelderTestAssert false (case_label + " Edit Poly context could not be prepared.")
            return false
        )
    )
    else
    (
        select target_data[2]
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
Counts current vertices whose world position exactly matches one supplied reference point.
The regression intentionally uses exact equality so no private geometry tolerance is introduced.
*/
function vertexWelderTestCountVerticesAtWorldPosition target_data world_position =
(
    match_count = 0
    vertex_count = VertexWelder.getVertexCount target_data

    if vertex_count <= 0 or world_position == undefined then return match_count

    for vertex_id = 1 to vertex_count do
    (
        current_position = VertexWelder.getVertexWorldPosition target_data vertex_id
        if current_position != undefined and current_position == world_position then match_count += 1
    )

    match_count
    -- return
)

/*
Creates a long segmented seam whose two open-border loops turn in opposite directions at both seam ends.
The first non-seam continuation remains inside the weld threshold, so BORDERS must stop by orientation rather than proximity alone.
*/
function vertexWelderTestCreateBorderLoopTurnFixture node_name =
(
    vertexWelderTestDeleteNamedNode node_name

    threshold_value = VertexWelder.thresholdMmToSystemUnits 0.1
    gap_value = threshold_value * 0.2
    side_offset = threshold_value * 0.2
    step_value = units.decodeValue "2mm"
    seam_vertex_count = 7
    mesh_vertices = #()
    mesh_faces = #()

    for vertex_index = 0 to (seam_vertex_count - 1) do
    (
        y_value = step_value * vertex_index
        append mesh_vertices [0,y_value,0]
    )

    for vertex_index = 0 to (seam_vertex_count - 1) do
    (
        y_value = step_value * vertex_index
        append mesh_vertices [-side_offset,y_value,0]
    )

    for vertex_index = 0 to (seam_vertex_count - 1) do
    (
        y_value = step_value * vertex_index
        append mesh_vertices [gap_value,y_value,0]
    )

    for vertex_index = 0 to (seam_vertex_count - 1) do
    (
        y_value = step_value * vertex_index
        append mesh_vertices [gap_value + side_offset,y_value,0]
    )

    left_seam_start = 1
    left_outer_start = seam_vertex_count + 1
    right_seam_start = (seam_vertex_count * 2) + 1
    right_outer_start = (seam_vertex_count * 3) + 1

    for segment_index = 0 to (seam_vertex_count - 2) do
    (
        left_seam_a = left_seam_start + segment_index
        left_seam_b = left_seam_a + 1
        left_outer_a = left_outer_start + segment_index
        left_outer_b = left_outer_a + 1

        append mesh_faces [left_outer_a,left_seam_a,left_seam_b]
        append mesh_faces [left_outer_a,left_seam_b,left_outer_b]

        right_seam_a = right_seam_start + segment_index
        right_seam_b = right_seam_a + 1
        right_outer_a = right_outer_start + segment_index
        right_outer_b = right_outer_a + 1

        append mesh_faces [right_seam_a,right_outer_a,right_outer_b]
        append mesh_faces [right_seam_a,right_outer_b,right_seam_b]
    )

    fixture_node = mesh name:node_name vertices:mesh_vertices faces:mesh_faces
    convertToPoly fixture_node
    fixture_node.baseObject.showCage = off
    append vertex_welder_test_nodes fixture_node

    fixture_node
    -- return
)

/*
Creates two original elements with two separated close seam runs between the same element pair.
The first stitched run joins the live topology; the second run verifies preserved original source-side identity.
*/
function vertexWelderTestCreateBorderTwoRunFixture node_name =
(
    vertexWelderTestDeleteNamedNode node_name

    threshold_value = VertexWelder.thresholdMmToSystemUnits 0.1
    gap_value = threshold_value * 0.2
    step_value = units.decodeValue "10mm"

    mesh_vertices = #(
        [0,0,0],
        [step_value,0,0],
        [step_value * 2.0,0,0],
        [step_value * 2.0,step_value,0],
        [step_value * 2.0,step_value * 2.0,0],
        [step_value,step_value * 2.0,0],
        [0,step_value * 2.0,0],
        [0,step_value,0],
        [step_value,step_value,0],

        [step_value,-step_value,0],
        [(step_value * 2.0) - gap_value,0,0],
        [(step_value * 2.0) - gap_value,step_value,0],
        [(step_value * 2.0) - gap_value,step_value * 2.0,0],
        [step_value,step_value * 3.0,0],
        [gap_value,step_value * 2.0,0],
        [gap_value,step_value,0],
        [gap_value,0,0],
        [step_value,step_value,0]
    )

    mesh_faces = #()

    for perimeter_index = 1 to 8 do
    (
        next_index = perimeter_index + 1
        if next_index > 8 then next_index = 1
        append mesh_faces [9,perimeter_index,next_index]
    )

    for perimeter_index = 10 to 17 do
    (
        next_index = perimeter_index + 1
        if next_index > 17 then next_index = 10
        append mesh_faces [18,perimeter_index,next_index]
    )

    fixture_node = mesh name:node_name vertices:mesh_vertices faces:mesh_faces
    convertToPoly fixture_node
    fixture_node.baseObject.showCage = off
    append vertex_welder_test_nodes fixture_node

    fixture_node
    -- return
)

/*
Creates two face-connected polygon elements that share only the two seam endpoint vertices.
Interior seam vertices remain duplicated and close, reproducing split-surface topology where point-only contact must not merge element identity.
*/
function vertexWelderTestCreateSharedEndpointBorderFixture node_name =
(
    vertexWelderTestDeleteNamedNode node_name

    threshold_value = VertexWelder.thresholdMmToSystemUnits 0.1
    gap_value = threshold_value * 0.4
    step_value = units.decodeValue "2mm"
    outer_offset = units.decodeValue "3mm"
    interior_count = 5
    seam_position_count = interior_count + 2
    mesh_vertices = #()
    mesh_faces = #()

    append mesh_vertices [0,0,0]

    for interior_index = 1 to interior_count do
    (
        append mesh_vertices [0,step_value * interior_index,0]
    )

    append mesh_vertices [0,step_value * (seam_position_count - 1),0]

    left_seam_ids = for vertex_id = 1 to seam_position_count collect vertex_id
    left_outer_ids = #()

    for position_index = 0 to (seam_position_count - 1) do
    (
        append mesh_vertices [-outer_offset,step_value * position_index,0]
        append left_outer_ids mesh_vertices.count
    )

    right_seam_ids = #(1)

    for interior_index = 1 to interior_count do
    (
        append mesh_vertices [gap_value,step_value * interior_index,0]
        append right_seam_ids mesh_vertices.count
    )

    append right_seam_ids seam_position_count
    right_outer_ids = #()

    for position_index = 0 to (seam_position_count - 1) do
    (
        append mesh_vertices [gap_value + outer_offset,step_value * position_index,0]
        append right_outer_ids mesh_vertices.count
    )

    for segment_index = 1 to (seam_position_count - 1) do
    (
        left_seam_a = left_seam_ids[segment_index]
        left_seam_b = left_seam_ids[segment_index + 1]
        left_outer_a = left_outer_ids[segment_index]
        left_outer_b = left_outer_ids[segment_index + 1]

        append mesh_faces [left_outer_a,left_seam_a,left_seam_b]
        append mesh_faces [left_outer_a,left_seam_b,left_outer_b]

        right_seam_a = right_seam_ids[segment_index]
        right_seam_b = right_seam_ids[segment_index + 1]
        right_outer_a = right_outer_ids[segment_index]
        right_outer_b = right_outer_ids[segment_index + 1]

        append mesh_faces [right_seam_a,right_outer_a,right_outer_b]
        append mesh_faces [right_seam_a,right_outer_b,right_seam_b]
    )

    fixture_node = mesh name:node_name vertices:mesh_vertices faces:mesh_faces
    convertToPoly fixture_node
    fixture_node.baseObject.showCage = off
    append vertex_welder_test_nodes fixture_node

    fixture_node
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

    border_threshold = VertexWelder.thresholdMmToSystemUnits 0.1
    border_seed = VertexWelder.findBestBorderSeed border_target border_threshold
    planned_border_pairs = VertexWelder.buildBorderPairRun border_target border_seed border_threshold
    planned_endpoint_positions = #()

    for pair_record in planned_border_pairs do
    (
        append planned_endpoint_positions #(
            VertexWelder.getVertexWorldPosition border_target pair_record[1],
            VertexWelder.getVertexWorldPosition border_target pair_record[2],
            pair_record[5])
    )

    preserved_right_bottom = VertexWelder.getVertexWorldPosition border_target 6
    preserved_right_top = VertexWelder.getVertexWorldPosition border_target 7

    vertexWelderTestAssert (planned_border_pairs.count == 2) "Editable BORDERS canonical fixture plans exactly two corresponding seam pairs before welding."

    ordered_border_pairs = VertexWelder.sortPairsDescendingByHighVertex planned_border_pairs
    ordered_pair_ids_ok = ordered_border_pairs.count == 2

    if ordered_pair_ids_ok then
    (
        first_pair_high = if ordered_border_pairs[1][1] > ordered_border_pairs[1][2] then ordered_border_pairs[1][1] else ordered_border_pairs[1][2]
        second_pair_high = if ordered_border_pairs[2][1] > ordered_border_pairs[2][2] then ordered_border_pairs[2][1] else ordered_border_pairs[2][2]
        ordered_pair_ids_ok = first_pair_high == 8 and second_pair_high == 5
    )

    vertexWelderTestAssert ordered_pair_ids_ok "Editable BORDERS executes disposable seam IDs in descending order so native compaction cannot renumber a later planned pair."

    planned_pair_keys = #()
    for pair_record in planned_border_pairs do append planned_pair_keys (VertexWelder.getVertexPairKey pair_record[1] pair_record[2])
    vertexWelderTestAssert (findItem planned_pair_keys "3:8" > 0 and findItem planned_pair_keys "2:5" > 0) "Editable BORDERS canonical fixture plans seam pairs 3/8 and 2/5 before the compound weld begins."

    undo "Vertex Welder Test 2C - Editable BORDERS" on
    (
        vertexWelderTestRunCase "Editable BORDERS" border_target #borders 2 1
    )

    vertexWelderTestAssert (VertexWelder.getEdgeCount border_target == 9) "Editable BORDERS compacts the stitched seam to nine polygon edges without a duplicate seam edge."
    vertexWelderTestAssert (vertexWelderTestCountVerticesAtWorldPosition border_target preserved_right_bottom == 1) "Editable BORDERS preserves the lower far-right corner instead of welding it by a stale vertex ID."
    vertexWelderTestAssert (vertexWelderTestCountVerticesAtWorldPosition border_target preserved_right_top == 1) "Editable BORDERS preserves the upper far-right corner instead of welding it by a stale vertex ID."

    planned_pair_positions_ok = planned_endpoint_positions.count == 2

    if planned_pair_positions_ok then
    (
        for endpoint_record in planned_endpoint_positions do
        (
            endpoint_a = endpoint_record[1]
            endpoint_b = endpoint_record[2]
            target_world = endpoint_record[3]

            if endpoint_a == undefined or endpoint_b == undefined or target_world == undefined then planned_pair_positions_ok = false
            if vertexWelderTestCountVerticesAtWorldPosition border_target target_world != 1 then planned_pair_positions_ok = false
            if endpoint_a != target_world and vertexWelderTestCountVerticesAtWorldPosition border_target endpoint_a != 0 then planned_pair_positions_ok = false
            if endpoint_b != target_world and vertexWelderTestCountVerticesAtWorldPosition border_target endpoint_b != 0 then planned_pair_positions_ok = false
        )
    )

    vertexWelderTestAssert planned_pair_positions_ok "Editable BORDERS welds both planned seam pairs to their requested targets while preserving later lower IDs."
    vertexWelderTestAssert (polyop.getHasDeadStructs border_node.baseObject == 0) "Editable BORDERS leaves no dead topology after the compound run boundary."

    border_face_orientation_ok = true
    border_face_count = polyop.getNumFaces border_node.baseObject

    for face_id = 1 to border_face_count do
    (
        face_plane = VertexWelder.getFaceWorldPlane border_target face_id

        if face_plane == undefined or face_plane[1].z <= 0.0 then
        (
            border_face_orientation_ok = false
        )
    )

    vertexWelderTestAssert border_face_orientation_ok "Editable BORDERS preserves the positive face orientation of the canonical seam fixture."

    loop_turn_node = undefined

    undo "Vertex Welder Test 2D - Create Loop-Turn Border Fixture" on
    (
        loop_turn_node = vertexWelderTestCreateBorderLoopTurnFixture "VW_TEST_BORDERS_LOOP_TURN"
    )

    vertexWelderTestAssert (isValidNode loop_turn_node) "Editable BORDERS loop-turn regression fixture was created."

    if isValidNode loop_turn_node then
    (
        loop_turn_target = VertexWelder.getTargetFromNode loop_turn_node prefer_active:false
        loop_turn_threshold = VertexWelder.thresholdMmToSystemUnits 0.1
        loop_turn_seed = VertexWelder.findBestBorderSeed loop_turn_target loop_turn_threshold
        loop_turn_pairs = VertexWelder.buildBorderPairRun loop_turn_target loop_turn_seed loop_turn_threshold debug:true

        vertexWelderTestAssert (loop_turn_pairs.count == 7) "Editable BORDERS stops at both opposite loop turns and plans only the seven corresponding seam vertices."

        bottom_left_outer = VertexWelder.getVertexWorldPosition loop_turn_target 8
        bottom_right_outer = VertexWelder.getVertexWorldPosition loop_turn_target 22
        top_left_outer = VertexWelder.getVertexWorldPosition loop_turn_target 14
        top_right_outer = VertexWelder.getVertexWorldPosition loop_turn_target 28

        close_turns_inside_threshold = false

        if bottom_left_outer != undefined and bottom_right_outer != undefined and top_left_outer != undefined and top_right_outer != undefined then
        (
            close_turns_inside_threshold = (distance bottom_left_outer bottom_right_outer) <= loop_turn_threshold and (distance top_left_outer top_right_outer) <= loop_turn_threshold
        )

        vertexWelderTestAssert close_turns_inside_threshold "Editable BORDERS loop-turn fixture keeps the first wrong continuation inside threshold so orientation is the required stop condition."

        undo "Vertex Welder Test 2E - Editable BORDERS Loop Turn" on
        (
            vertexWelderTestRunCase "Editable BORDERS LOOP TURN" loop_turn_target #borders 7 1
        )

        vertexWelderTestAssert (vertexWelderTestCountVerticesAtWorldPosition loop_turn_target bottom_left_outer == 1) "Editable BORDERS preserves the lower left outer-loop corner."
        vertexWelderTestAssert (vertexWelderTestCountVerticesAtWorldPosition loop_turn_target bottom_right_outer == 1) "Editable BORDERS preserves the lower right outer-loop corner."
        vertexWelderTestAssert (vertexWelderTestCountVerticesAtWorldPosition loop_turn_target top_left_outer == 1) "Editable BORDERS preserves the upper left outer-loop corner."
        vertexWelderTestAssert (vertexWelderTestCountVerticesAtWorldPosition loop_turn_target top_right_outer == 1) "Editable BORDERS preserves the upper right outer-loop corner."
    )

    two_run_node = undefined

    undo "Vertex Welder Test 2F - Create Two-Run Border Fixture" on
    (
        two_run_node = vertexWelderTestCreateBorderTwoRunFixture "VW_TEST_BORDERS_TWO_RUN"
    )

    vertexWelderTestAssert (isValidNode two_run_node) "Editable BORDERS two-run regression fixture was created."

    if isValidNode two_run_node then
    (
        two_run_target = VertexWelder.getTargetFromNode two_run_node prefer_active:false
        two_run_threshold = VertexWelder.thresholdMmToSystemUnits 0.1
        source_face_groups = VertexWelder.buildFaceGroupMap two_run_target
        first_seed = VertexWelder.findBestBorderSeed two_run_target two_run_threshold face_group_ids:source_face_groups
        first_run = VertexWelder.buildBorderPairRun two_run_target first_seed two_run_threshold face_group_ids:source_face_groups debug:true

        vertexWelderTestAssert (VertexWelder.getElementCount two_run_target == 2) "Editable BORDERS two-run fixture starts as exactly two connected elements."
        vertexWelderTestAssert (first_run.count == 3) "Editable BORDERS two-run fixture exposes one three-pair seam before the first stitch."

        detour_bottom_a = VertexWelder.getVertexWorldPosition two_run_target 2
        detour_top_a = VertexWelder.getVertexWorldPosition two_run_target 6
        detour_bottom_b = VertexWelder.getVertexWorldPosition two_run_target 10
        detour_top_b = VertexWelder.getVertexWorldPosition two_run_target 14

        undo "Vertex Welder Test 2G - Editable BORDERS Two Runs" on
        (
            vertexWelderTestRunCase "Editable BORDERS TWO RUNS" two_run_target #borders 6 1
        )

        vertexWelderTestAssert (vertexWelderTestCountVerticesAtWorldPosition two_run_target detour_bottom_a == 1) "Editable BORDERS two-run fixture preserves source-A bottom detour."
        vertexWelderTestAssert (vertexWelderTestCountVerticesAtWorldPosition two_run_target detour_top_a == 1) "Editable BORDERS two-run fixture preserves source-A top detour."
        vertexWelderTestAssert (vertexWelderTestCountVerticesAtWorldPosition two_run_target detour_bottom_b == 1) "Editable BORDERS two-run fixture preserves source-B bottom detour."
        vertexWelderTestAssert (vertexWelderTestCountVerticesAtWorldPosition two_run_target detour_top_b == 1) "Editable BORDERS two-run fixture preserves source-B top detour."

        remaining_seed = VertexWelder.findBestBorderSeed two_run_target two_run_threshold face_group_ids:source_face_groups
        vertexWelderTestAssert (remaining_seed == undefined) "Editable BORDERS finishes every eligible seam between the same two original source groups."
    )

    shared_endpoint_node = undefined

    undo "Vertex Welder Test 2H - Create Shared-Endpoint Border Fixture" on
    (
        shared_endpoint_node = vertexWelderTestCreateSharedEndpointBorderFixture "VW_TEST_BORDERS_SHARED_ENDPOINTS"
    )

    vertexWelderTestAssert (isValidNode shared_endpoint_node) "Editable BORDERS shared-endpoint regression fixture was created."

    if isValidNode shared_endpoint_node then
    (
        shared_endpoint_target = VertexWelder.getTargetFromNode shared_endpoint_node prefer_active:false
        shared_endpoint_threshold = VertexWelder.thresholdMmToSystemUnits 0.1
        shared_endpoint_groups = VertexWelder.buildFaceGroupMap shared_endpoint_target
        shared_endpoint_group_count = VertexWelder.getElementCountFromMap shared_endpoint_groups

        vertexWelderTestAssert (VertexWelder.getElementCount shared_endpoint_target == 2) "Editable BORDERS treats face regions that touch only at seam endpoints as two polygon elements."
        vertexWelderTestAssert (shared_endpoint_group_count == 2) "Editable BORDERS source face-group map preserves the two point-connected source elements."

        shared_bottom_world = VertexWelder.getVertexWorldPosition shared_endpoint_target 1
        shared_top_world = VertexWelder.getVertexWorldPosition shared_endpoint_target 7
        shared_endpoint_seed = VertexWelder.findBestBorderSeed shared_endpoint_target shared_endpoint_threshold face_group_ids:shared_endpoint_groups
        shared_endpoint_pairs = VertexWelder.buildBorderPairRun shared_endpoint_target shared_endpoint_seed shared_endpoint_threshold face_group_ids:shared_endpoint_groups debug:true

        vertexWelderTestAssert (shared_endpoint_seed != undefined) "Editable BORDERS finds a seam seed across two face-connected source elements that already share endpoint vertices."
        vertexWelderTestAssert (shared_endpoint_pairs.count == 5) "Editable BORDERS plans only the five duplicated interior seam pairs and excludes both already-shared endpoints."

        no_self_pairs = true

        for pair_record in shared_endpoint_pairs do
        (
            if pair_record[1] == pair_record[2] then no_self_pairs = false
        )

        vertexWelderTestAssert no_self_pairs "Editable BORDERS never creates a self-weld pair for an already-shared seam endpoint."

        undo "Vertex Welder Test 2I - Editable BORDERS Shared Endpoints" on
        (
            vertexWelderTestRunCase "Editable BORDERS SHARED ENDPOINTS" shared_endpoint_target #borders 5 1
        )

        vertexWelderTestAssert (vertexWelderTestCountVerticesAtWorldPosition shared_endpoint_target shared_bottom_world == 1) "Editable BORDERS preserves the existing lower shared seam endpoint."
        vertexWelderTestAssert (vertexWelderTestCountVerticesAtWorldPosition shared_endpoint_target shared_top_world == 1) "Editable BORDERS preserves the existing upper shared seam endpoint."
        vertexWelderTestAssert (polyop.getHasDeadStructs shared_endpoint_node.baseObject == 0) "Editable BORDERS shared-endpoint run leaves no dead topology after its final synchronization."
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

    base_local = polyop.getVert weld_node.baseObject 2
    expected_world = base_local * weld_node.objectTransform
    doubled_world = expected_world * weld_node.objectTransform
    actual_world = VertexWelder.getVertexWorldPosition weld_target 2
    coordinate_path_ok = false

    if actual_world != undefined then
    (
        expected_distance = distance actual_world expected_world
        local_distance = distance actual_world base_local
        doubled_distance = distance actual_world doubled_world

        format "Edit Poly coordinate check | actual:% | expected:% | localDistance:% | expectedDistance:% | doubledDistance:%\n" actual_world expected_world local_distance expected_distance doubled_distance
        coordinate_path_ok = expected_distance < local_distance and expected_distance < doubled_distance
    )

    vertexWelderTestAssert coordinate_path_ok "Part 3 Edit Poly translated vertex read follows the single-transform world-position path."

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
Test part 4 validates the managed dialog, tool title button style, and persisted control ranges.
*/
function partOfTest4 =
(
    reload_exception = undefined

    try
    (
        fileIn vertex_welder_main_script_path quiet:true
    )
    catch
    (
        reload_exception = getCurrentException()
        format "Vertex Welder RELOAD TEST ERROR | %\n" reload_exception
    )

    vertexWelderTestAssert (reload_exception == undefined) "Part 4 canonical main reload replaces an existing dialog without startup failure."

    dialog_ok = VertexWelder_UI != undefined and VertexWelder_UI.inDialog
    vertexWelderTestAssert dialog_ok "Part 4 managed dialog is open after canonical reload."
    vertexWelderTestAssert (doesFileExist vertex_welder_main_script_path) "Part 4 canonical Vertex-Welder.ms main file exists above the test folder."
    vertexWelderTestAssert (doesFileExist (vertex_welder_script_directory + "Vertex-Welder-FN.ms")) "Part 4 canonical Vertex-Welder-FN.ms backend exists beside the main entry."
    vertexWelderTestAssert (doesFileExist (vertex_welder_script_directory + "Vertex-Welder-UI.ms")) "Part 4 canonical Vertex-Welder-UI.ms frontend exists beside the main entry."
    vertexWelderTestAssert (doesFileExist (vertex_welder_ui_framework_directory + "IniSettings.ms")) "Part 4 shared UI framework resolves from the Codebase package path."
    vertexWelderTestAssert (vertex_welder_ui_ini_path == (vertex_welder_script_directory + "Vertex-Welder.ini")) "Part 4 UI INI is stored beside the canonical main script."
    vertexWelderTestAssert (vertex_welder_project_version == 0.016) "Part 4 shared project version is 0.016."
    vertexWelderTestAssert (vertex_welder_file_version == 0.016 and vertex_welder_ui_file_version == 0.010) "Part 4 main file version is 0.016 and UI file version is 0.010."
    vertexWelderTestAssert (VertexWelder.file_version == 0.014 and VertexWelder.project_version == 0.016) "Part 4 backend file version is 0.014 and project version is 0.016."
    vertexWelderTestAssert (vertex_welder_dialog_key == "Vertex-Welder") "Part 4 stable dialog registry key is configured."

    registry_count = 0

    if dialog_host_registry != undefined then
    (
        for registry_entry in dialog_host_registry do
        (
            if registry_entry != undefined and registry_entry.count >= 2 and registry_entry[1] == vertex_welder_dialog_key then
            (
                registry_count += 1
            )
        )
    )

    vertexWelderTestAssert (registry_count == 1) "Part 4 DialogHost owns exactly one registered Vertex Welder dialog."

    if dialog_ok then
    (
        dialog_size = getDialogSize VertexWelder_UI
        title_button = VertexWelder_UI.btn_tool_title
        back_color = title_button.BackColor
        fore_color = title_button.ForeColor
        hover_color = title_button.FlatAppearance.MouseOverBackColor
        pressed_color = title_button.FlatAppearance.MouseDownBackColor

        vertexWelderTestAssert (VertexWelder_UI.title == vertex_welder_tool_title) "Part 4 native dialog title matches current project version."
        vertexWelderTestAssert (title_button.Text == "Vertex Welder") "Part 4 tool title button contains the tool name only."
        vertexWelderTestAssert (title_button.height == 16) "Part 4 tool title button uses the current shared 16 px height."
        vertexWelderTestAssert (title_button.FlatAppearance.BorderSize == 0) "Part 4 tool title button border is disabled."
        vertexWelderTestAssert (back_color.R == 45 and back_color.G == 45 and back_color.B == 48) "Part 4 tool title button background matches the shared style."
        vertexWelderTestAssert (hover_color.R == 45 and hover_color.G == 45 and hover_color.B == 48) "Part 4 tool title button hover background matches the shared style."
        vertexWelderTestAssert (pressed_color.R == 45 and pressed_color.G == 45 and pressed_color.B == 48) "Part 4 tool title button pressed background matches the shared style."
        vertexWelderTestAssert (fore_color.R == 62 and fore_color.G == 158 and fore_color.B == 255) "Part 4 tool title button text color matches the shared style."
        vertexWelderTestAssert (dialog_size.x == 336 and dialog_size.y >= 240) "Part 4 managed dialog size contract."
        vertexWelderTestAssert (VertexWelder_UI.spn_threshold_mm.value >= 0.0 and VertexWelder_UI.spn_threshold_mm.value <= 1000000.0) "Part 4 restored threshold is valid."
        mode_button_count = 0
        if VertexWelder_UI.btn_mode_weld.checked then mode_button_count += 1
        if VertexWelder_UI.btn_mode_per_element.checked then mode_button_count += 1
        if VertexWelder_UI.btn_mode_borders.checked then mode_button_count += 1

        vertexWelderTestAssert (mode_button_count == 1) "Part 4 mode buttons keep exactly one active pressed selection."
        vertexWelderTestAssert (VertexWelder_UI.getUiModeIndex() >= 1 and VertexWelder_UI.getUiModeIndex() <= 3) "Part 4 restored mode-button selection is valid."
        vertexWelderTestAssert (IniSettings != undefined and DialogHost != undefined and ScriptReload != undefined and ToolTitleButton != undefined) "Part 4 shared UI helpers are loaded."
    )

    true
    -- return
)

/*
Test part 5 reports the final regression result and documents the undo sequence.
*/
function partOfTest5 =
(
    completeRedraw()

    if vertex_welder_test_failures.count > 0 then
    (
        format "Vertex Welder Test 0.016 | FAILED | % failure(s).\n" vertex_welder_test_failures.count

        for failure_text in vertex_welder_test_failures do
        (
            format "FAILURE | %\n" failure_text
        )

        format "UNDO ORDER | Edit Poly BORDERS -> Edit Poly PER ELEMENT -> Edit Poly WELD -> Editable BORDERS Shared Endpoints -> Create Shared-Endpoint Border Fixture -> Editable BORDERS Two Runs -> Create Two-Run Border Fixture -> Editable BORDERS Loop Turn -> Create Loop-Turn Border Fixture -> Editable BORDERS -> Editable PER ELEMENT -> Editable WELD -> Create Fixtures.\n"
        throw ("Vertex Welder regression failed: " + (vertex_welder_test_failures.count as string) + " failure(s).")
    )
    else
    (
        format "Vertex Welder Test 0.016 | PASS | geometry and managed-dialog checks passed.\n"
        format "UNDO ORDER | Edit Poly BORDERS -> Edit Poly PER ELEMENT -> Edit Poly WELD -> Editable BORDERS Shared Endpoints -> Create Shared-Endpoint Border Fixture -> Editable BORDERS Two Runs -> Create Two-Run Border Fixture -> Editable BORDERS Loop Turn -> Create Loop-Turn Border Fixture -> Editable BORDERS -> Editable PER ELEMENT -> Editable WELD -> Create Fixtures.\n"
    )

    true
    -- return
)

-- EXECUTION QUEUE
partOfTest1()
partOfTest2()
partOfTest3()
partOfTest4()
partOfTest5()
