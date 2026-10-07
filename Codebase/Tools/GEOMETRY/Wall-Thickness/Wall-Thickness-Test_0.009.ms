/*
Wall Thickness Tests 0.009
Project version 1.005.
Contains regression helpers and test-fixture builders extracted from the production tool.
*/
global wall_thickness_test_file_version = 0.009
global wall_thickness_test_stored_project_version = 1.005
global wall_thickness_test_source_file_path = getSourceFileName()
global wall_thickness_test_production_path = (getFilenamePath wall_thickness_test_source_file_path) + "Wall-Thickness_1.005.ms"
if doesFileExist wall_thickness_test_production_path then
(
        fileIn wall_thickness_test_production_path
)
else
(
        throw ("Missing Wall Thickness production script: " + wall_thickness_test_production_path)
)
/*
Tests the live Edit Poly T-edge cut movement when the two cut vertices start with different X/Y.
Both vertices must land on exact anchor X/Y while each original Z remains unchanged.
*/
function testWallThicknessTEdgeSkewedVerticalCut =
(
        tolerance = units.decodeValue "0.01mm"
        skew_amount = units.decodeValue "0.02mm"
        top_start_position = [0, 0, units.decodeValue "100mm"]
        bottom_start_position = [skew_amount, 0, 0]
        fixed_anchor_position = [units.decodeValue "250mm", units.decodeValue "125mm", 0]
        undo "Create T Edge Skew Test" on
        (
                test_node = box length:(units.decodeValue "1m") width:(units.decodeValue "1m") height:(units.decodeValue "1m")
                test_node.name = "TEST T EDGE SKEWED CUT"
                convertToPoly test_node
                try (test_node.showCage = off) catch ()
                try (test_node.baseObject.showCage = off) catch ()
                top_vertex_id = 1
                bottom_vertex_id = 2
                top_bits = #{}
                top_bits[top_vertex_id] = true
                bottom_bits = #{}
                bottom_bits[bottom_vertex_id] = true
                polyop.setVert test_node.baseObject top_bits top_start_position
                polyop.setVert test_node.baseObject bottom_bits bottom_start_position
                update test_node
        )
        original_top_position = test_node.GetVertex top_vertex_id
        original_bottom_position = test_node.GetVertex bottom_vertex_id
        undo "Move T Edge Skew Test Cut" on
        (
                move_succeeded = moveWallThicknessTEdgeBaseVerticalCutToAnchor test_node top_vertex_id bottom_vertex_id fixed_anchor_position tolerance
        )
        moved_top_position = test_node.GetVertex top_vertex_id
        moved_bottom_position = test_node.GetVertex bottom_vertex_id
        top_matches =
                abs (moved_top_position.x - fixed_anchor_position.x) <= tolerance and
                abs (moved_top_position.y - fixed_anchor_position.y) <= tolerance and
                moved_top_position.z == original_top_position.z
        bottom_matches =
                abs (moved_bottom_position.x - fixed_anchor_position.x) <= tolerance and
                abs (moved_bottom_position.y - fixed_anchor_position.y) <= tolerance and
                moved_bottom_position.z == original_bottom_position.z
        test_passed = move_succeeded and top_matches and bottom_matches
        format "Wall Thickness T EDGE SKEWED CUT TEST: % | top:% -> % | bottom:% -> % | anchor:%\n" (if test_passed then "PASS" else "FAIL") original_top_position moved_top_position original_bottom_position moved_bottom_position fixed_anchor_position
        format "Undo order: Move T Edge Skew Test Cut, Create T Edge Skew Test.\n"
        test_passed
        -- return
)
/*
Runs the focused paired T-Corner regression on the currently selected wall.
A T-Corner requires one detected T case plus its mirrored branch/plan case, and both must complete inside the same removable T-edge Edit Poly.
*/
function testWallThicknessTCornerSelected =
(
        if selection.count != 1 then
        (
                format "Wall Thickness T-CORNER TEST: FAIL - select exactly one T-Corner wall object.\n"
                false
        )
        else
        (
                test_node = selection[1]
                inner_result = fixWallThicknessInnerCorners test_node
                if inner_result == undefined or inner_result[1] != true then
                (
                        format "Wall Thickness T-CORNER TEST: FAIL - FIX INNER CORNERS setup failed.\n"
                        false
                )
                else
                (
                        plan_data = planWallThicknessTEdgeModifierRepairs test_node
                        plan_ok = plan_data != undefined and plan_data.count >= 2 and plan_data[1] == true
                        planned_cases = if plan_ok then plan_data[2] else #()
                        t_corner_pairs = getWallThicknessTCornerCasePairs planned_cases
                        before_probe = if t_corner_pairs.count > 0 then createWallThicknessTEdgePolyProbe test_node "T CORNER BEFORE" else undefined
                        before_counts = if before_probe != undefined then getWallThicknessTEdgeProbeCounts before_probe else #(0, 0, 0)
                        result_data = if before_probe != undefined then fixWallThicknessTEdgeCorners test_node else #(false, 0, 0, 0)
                        after_probe = if result_data[1] then createWallThicknessTEdgePolyProbe test_node "T CORNER AFTER" else undefined
                        after_counts = if after_probe != undefined then getWallThicknessTEdgeProbeCounts after_probe else #(0, 0, 0)
                        expected_case_count = planned_cases.count
                        topology_ok =
                                before_probe != undefined and
                                after_probe != undefined and
                                result_data[2] == expected_case_count and
                                after_counts[1] == (before_counts[1] + (expected_case_count * 2)) and
                                after_counts[2] == (before_counts[2] + expected_case_count) and
                                after_counts[3] == (before_counts[3] + (expected_case_count * 3))
                        t_edge_modifier = getWallThicknessTEdgeFixModifier test_node
                        t_edge_modifiers = getWallThicknessTEdgeFixModifiers test_node
                        modifier_ok = t_edge_modifier != undefined and t_edge_modifiers.count == 1
                        test_passed = plan_ok and t_corner_pairs.count > 0 and result_data[1] and topology_ok and modifier_ok
                        format "Wall Thickness T-CORNER TEST: % | planned:% | pairs:% | repaired:% | verts:%->% | faces:%->% | edges:%->%\n" (if test_passed then "PASS" else "FAIL") planned_cases.count t_corner_pairs.count result_data[2] before_counts[1] after_counts[1] before_counts[2] after_counts[2] before_counts[3] after_counts[3]
                        if before_probe != undefined then deleteWallThicknessTEdgePolyProbe before_probe "T CORNER BEFORE"
                        if after_probe != undefined then deleteWallThicknessTEdgePolyProbe after_probe "T CORNER AFTER"
                        test_passed
                )
        )
        -- return
)
/*
Compares two evaluated TriMesh snapshots for the exact pre/post modifier geometry contract.
The existing Wall Thickness tolerance is used only for vertex-position verification; face topology and material IDs remain exact.
*/
function wallThicknessEvaluatedMeshesMatch mesh_a mesh_b tolerance =
(
        if mesh_a == undefined or mesh_b == undefined then return false
        vertex_count_a = meshop.getNumVerts mesh_a
        vertex_count_b = meshop.getNumVerts mesh_b
        face_count_a = meshop.getNumFaces mesh_a
        face_count_b = meshop.getNumFaces mesh_b
        if vertex_count_a != vertex_count_b or face_count_a != face_count_b then return false
        matches = true
        for vertex_id = 1 to vertex_count_a while matches do
        (
                if distance (getVert mesh_a vertex_id) (getVert mesh_b vertex_id) > tolerance then matches = false
        )
        for face_id = 1 to face_count_a while matches do
        (
                if getFace mesh_a face_id != getFace mesh_b face_id then matches = false
                if matches and meshop.getFaceMatID mesh_a face_id != meshop.getFaceMatID mesh_b face_id then matches = false
        )
        matches
        -- return
)
/*
Runs the focused non-destructive T-edge regression on the currently selected wall.
Collapsed Editable Poly copies are used only for read-only before/after regression comparison; all authoring IDs come from the live T-edge Edit Poly.
*/
function testWallThicknessTEdgeCornersSelected =
(
        if selection.count != 1 then
        (
                format "Wall Thickness FIX T EDGE CORNERS TEST: FAIL - select exactly one wall object.\n"
                false
        )
        else
        (
                test_node = selection[1]
                inner_result = fixWallThicknessInnerCorners test_node
                if inner_result == undefined or inner_result[1] != true then
                (
                        format "Wall Thickness FIX T EDGE CORNERS TEST: FAIL - FIX INNER CORNERS setup failed.\n"
                        false
                )
                else
                (
                        base_signature_before = getWallThicknessBaseTopologySignature test_node
                        before_probe = createWallThicknessTEdgePolyProbe test_node "TEST BEFORE T EDGE"
                        before_probe_ok = before_probe != undefined
                        before_polygon_counts = if before_probe_ok then getWallThicknessTEdgeProbeCounts before_probe else #(0, 0, 0)
                        before_signature = if before_probe_ok then getWallThicknessBaseTopologySignature before_probe else undefined
                        result_data = if before_probe_ok then fixWallThicknessTEdgeCorners test_node else #(false, 0, 0, 0)
                        after_probe = createWallThicknessTEdgePolyProbe test_node "TEST AFTER T EDGE"
                        after_probe_ok = after_probe != undefined
                        after_polygon_counts = if after_probe_ok then getWallThicknessTEdgeProbeCounts after_probe else #(0, 0, 0)
                        base_signature_after = getWallThicknessBaseTopologySignature test_node
                        base_unchanged = wallThicknessBaseTopologySignaturesMatch base_signature_before base_signature_after
                        t_edge_modifiers = getWallThicknessTEdgeFixModifiers test_node
                        t_edge_modifier = getWallThicknessTEdgeFixModifier test_node
                        current_stack_object = undefined
                        try (current_stack_object = modPanel.getCurrentObject()) catch ()
                        modifier_selected_ok =
                                t_edge_modifier != undefined and
                                current_stack_object == t_edge_modifier and
                                selection.count == 1 and
                                selection[1] == test_node
                        inner_modifier = getWallThicknessInnerCornerFixModifier test_node
                        thickness_modifier = getWallThicknessModifier test_node
                        inner_index = 0
                        thickness_index = 0
                        t_edge_indices = #()
                        for modifier_id = 1 to test_node.modifiers.count do
                        (
                                stack_item = test_node.modifiers[modifier_id]
                                if stack_item == inner_modifier then inner_index = modifier_id
                                if stack_item == thickness_modifier then thickness_index = modifier_id
                                if (findItem t_edge_modifiers stack_item) > 0 then
                                (
                                        append t_edge_indices modifier_id
                                )
                        )
                        stack_order_ok =
                                t_edge_modifier != undefined and
                                classOf t_edge_modifier == Edit_Poly and
                                t_edge_modifiers.count == 1 and
                                result_data[2] > 0 and
                                thickness_index > 0 and
                                t_edge_indices.count == t_edge_modifiers.count
                        if stack_order_ok then
                        (
                                for t_edge_index in t_edge_indices while stack_order_ok do
                                (
                                        if t_edge_index >= thickness_index then stack_order_ok = false
                                        if inner_modifier != undefined and (inner_index < 1 or t_edge_index >= inner_index) then stack_order_ok = false
                                )
                        )
                        polygon_delta_ok =
                                before_probe_ok and
                                after_probe_ok and
                                after_polygon_counts[1] == (before_polygon_counts[1] + (result_data[2] * 2)) and
                                after_polygon_counts[2] == (before_polygon_counts[2] + result_data[2]) and
                                after_polygon_counts[3] == (before_polygon_counts[3] + (result_data[2] * 3))
                        disable_restore_ok = false
                        disabled_probe = undefined
                        t_edge_enabled_states = for t_edge_case_modifier in t_edge_modifiers collect t_edge_case_modifier.enabled
                        if t_edge_modifiers.count > 0 and before_signature != undefined then
                        (
                                for t_edge_case_modifier in t_edge_modifiers do
                                (
                                        t_edge_case_modifier.enabled = false
                                )
                                update test_node
                                disabled_probe = createWallThicknessTEdgePolyProbe test_node "TEST T EDGE DISABLED"
                                if disabled_probe != undefined then
                                (
                                        disabled_signature = getWallThicknessBaseTopologySignature disabled_probe
                                        disable_restore_ok = wallThicknessBaseTopologySignaturesMatch before_signature disabled_signature and wallThicknessTEdgeProbeMaterialsMatch before_probe disabled_probe
                                )
                                for modifier_index = 1 to t_edge_modifiers.count do
                                (
                                        t_edge_modifiers[modifier_index].enabled = t_edge_enabled_states[modifier_index]
                                )
                                update test_node
                        )
                        expected_vertex_count = before_polygon_counts[1] + (result_data[2] * 2)
                        test_passed =
                                result_data[1] and
                                result_data[2] > 0 and
                                base_unchanged and
                                stack_order_ok and
                                modifier_selected_ok and
                                polygon_delta_ok and
                                disable_restore_ok and
                                after_polygon_counts[1] == expected_vertex_count
                        format "Wall Thickness FIX T EDGE CORNERS DIRECT-STACK TEST: % | cases:% | polygon V/F/E:% -> % | expected verts:% | base unchanged:% | stack order:% | modifier selected:% | polygon delta:% | disable restores exact pre-T:%\n" (if test_passed then "PASS" else "FAIL") result_data[2] before_polygon_counts after_polygon_counts expected_vertex_count base_unchanged stack_order_ok modifier_selected_ok polygon_delta_ok disable_restore_ok
                        format "Undo order: Wall Thickness - Fix T Edge Corners, Wall Thickness - Fix Inner Corners.\n"
                        if before_probe != undefined and isValidNode before_probe then deleteWallThicknessTEdgePolyProbe before_probe "TEST BEFORE CLEANUP"
                        if after_probe != undefined and isValidNode after_probe then deleteWallThicknessTEdgePolyProbe after_probe "TEST AFTER CLEANUP"
                        if disabled_probe != undefined and isValidNode disabled_probe then deleteWallThicknessTEdgePolyProbe disabled_probe "TEST DISABLED CLEANUP"
                        test_passed
                )
        )
        -- return
)
/*
Quadrifies the angle-test wall in a dedicated Edit Poly modifier.
The modifier is left visible so the quad result can be inspected directly.
*/
function quadrifyWallThicknessTestObject test_node =
(
        if not isValidNode test_node then
        (
                false
        )
        else
        (
                quadrify_succeeded = false
                quadrify_modifier = Edit_Poly()
                quadrify_modifier.name = "TEST QUADRIFY"
                quadrify_modifier.showCage = off
                addModifier test_node quadrify_modifier
                try
                (
                        select test_node
                        max modify mode
                        WallThicknessPreprocess.prepareEditPoly test_node quadrify_modifier selection_level:#Object
                        modPanel.setCurrentObject quadrify_modifier node:test_node
                        subObjectLevel = 0
                        macros.run "PolyTools" "Quadrify"
                        update test_node
                        quadrify_succeeded = clearWallSmoothingGroupsOnEditPoly test_node quadrify_modifier
                )
                catch
                (
                        try (deleteModifier test_node quadrify_modifier) catch ()
                        quadrify_succeeded = false
                )
                quadrify_succeeded
        )
        -- return
)
/*
Creates the current uploaded complex source/outer-wall reference used for Wall Thickness testing.
RMB on CREATE ANGLE TEST WALLS calls this function; topology, coordinates, material ID 1, smoothing 0, and WallThickness 0.35 come from the uploaded diagnostic.
*/
function createWallThicknessUploadedTest =
(
        test_vertices = #(
                [-3.75159,-10.3163,3.78754],
                [-3.64014,-10.2408,3.78754],
                [2.60706,-6.00934,3.78754],
                [4.76929,7.36407,-2.78748],
                [4.76929,7.36414,-2.93628],
                [5.14587,7.61926,-2.93634],
                [5.14587,7.61926,-2.78748],
                [1.94604,5.45178,-2.78748],
                [1.94604,5.45178,-2.93622],
                [2.07837,5.54163,-2.93622],
                [2.07837,5.54163,-2.78748],
                [4.76929,7.36407,-1.13684],
                [5.146,7.61926,-1.1369],
                [1.08069,4.86572,0.587158],
                [1.08069,4.86572,0.437561],
                [1.58582,5.20782,0.437561],
                [-2.92261,2.1543,0.587524],
                [-2.92249,2.1543,0.437561],
                [-1.22925,3.30115,0.437561],
                [1.08069,4.86572,2.23749],
                [-2.92249,2.1543,2.23755],
                [-1.22925,3.30109,2.23755],
                [-1.22925,3.30115,3.78754],
                [-2.92249,2.1543,3.78754],
                [1.94604,5.45172,-1.13684],
                [2.07837,5.54156,-1.13684],
                [1.08069,4.86578,3.78754],
                [1.58569,5.20795,3.78754],
                [1.94592,5.4519,3.78754],
                [2.07837,5.54163,3.78754],
                [2.19421,5.62006,3.78754],
                [-2.51855,1.55817,2.23755],
                [-2.51855,1.55817,0.587402],
                [2.36316,-5.64917,0.586853],
                [2.36316,-5.64917,0.437561],
                [1.76587,-4.7674,0.437561],
                [-2.51855,1.55817,0.437561],
                [2.60706,-6.00934,2.23669],
                [2.60706,-6.00934,0.586792],
                [1.76587,-4.7674,3.78754],
                [2.36316,-5.64917,3.78754],
                [-2.51855,1.55811,3.78754],
                [2.03296,5.32349,-1.13684],
                [2.03284,5.32349,-2.78748],
                [5.6051,0.0494385,-3.78748],
                [4.6405,1.47345,-3.78748],
                [4.6405,1.47351,-2.93597],
                [5.6051,0.0494385,-2.93585],
                [2.03284,5.32349,-2.93616],
                [4.6405,1.47351,-2.78748],
                [5.60522,0.0494385,-1.13727],
                [5.6051,0.0494385,-2.78748],
                [7.47534,-2.71185,-1.13757],
                [7.47534,-2.71185,-2.78748],
                [7.23157,-2.35162,-2.78748],
                [7.04639,-2.07837,-2.78748],
                [7.23145,-2.35168,0.586914],
                [7.45276,-2.72717,0.437561],
                [7.23132,-2.35168,0.437561],
                [1.95044,5.98016,0.587402],
                [1.95044,5.98016,0.437561],
                [0.556763,8.03766,0.437561],
                [1.95032,5.9801,2.23755],
                [0.556641,8.03766,2.23773],
                [0.556763,8.0376,3.78754],
                [1.95044,5.9801,3.78754],
                [-7.47546,6.52246,0.437561],
                [-7.47546,6.52246,-0.412476],
                [-7.47546,6.52246,3.78754],
                [-7.47546,6.52246,2.23816],
                [-1.87439,10.3163,0.437561],
                [-1.87439,10.3163,3.78754],
                [-1.87439,10.3163,-0.412476],
                [2.07849,5.54156,0.437561],
                [1.94604,5.45166,0.437561],
                [4.76917,7.36414,0.437561],
                [2.19421,5.62,0.437561],
                [2.19421,5.62,-1.13684],
                [5.14587,7.61926,0.437561],
                [7.04626,-2.07849,0.437561],
                [5.60498,0.0493774,0.437561],
                [4.6405,1.47345,0.437561],
                [2.03284,5.32349,0.437561],
                [4.76929,7.36407,-3.78748],
                [5.14587,7.61926,-3.78748],
                [1.94592,5.45178,-3.78748],
                [2.07837,5.54156,-3.78748],
                [2.03284,5.32349,-3.78748],
                [1.08069,4.86572,-0.412476],
                [1.58582,5.20782,-0.412476],
                [-2.92249,2.1543,-0.412476],
                [-1.22925,3.30109,-0.412476],
                [2.36316,-5.64917,-0.412476],
                [1.76587,-4.7674,-0.412476],
                [-2.51855,1.55817,-0.412476],
                [1.95044,5.98016,-0.412476],
                [0.556763,8.03766,-0.412476],
                [-3.75146,-10.3163,0.58728],
                [-3.64014,-10.2408,-2.78748],
                [2.60706,-6.0094,-2.78748],
                [2.99609,-5.74579,0.586792],
                [2.79321,-5.88318,0.586792],
                [2.79321,-5.88318,-2.78748],
                [2.99609,-5.74573,-2.78748],
                [4.81763,-4.51196,-2.78748],
                [5.02466,-4.37177,-2.78748],
                [5.02466,-4.37177,0.587036],
                [-3.75159,-10.3163,-2.78748],
                [1.58582,5.20782,0.587158],
                [-1.22925,3.30115,0.587402],
                [0.556763,8.03766,0.587463],
                [-7.47546,6.52246,0.587646],
                [2.07849,5.54156,0.587158],
                [1.94604,5.45172,0.587158],
                [4.76917,7.36414,0.587097],
                [2.19421,5.62,0.587158],
                [5.14587,7.61926,0.58728],
                [2.03284,5.32349,0.587158],
                [-3.64014,-10.2407,0.587219],
                [1.76587,-4.7674,0.586914],
                [-1.87439,10.3163,0.587585],
                [7.04639,-2.07849,0.586975],
                [5.60498,0.0493774,0.587036],
                [4.64062,1.47345,0.587158],
                [4.81763,-4.51196,0.587036],
                [7.45276,-2.72717,0.586914],
                [1.58569,5.20789,2.23749],
                [1.94592,5.4519,2.23749],
                [2.07837,5.54163,2.23743],
                [2.19421,5.62006,2.23743],
                [2.36316,-5.64917,2.23682],
                [1.76587,-4.7674,2.23682],
                [-1.87439,10.3163,2.23804],
                [-3.75146,-10.3163,2.23615],
                [-3.64014,-10.2408,2.23615],
                [4.6405,1.47345,-1.13721],
                [7.23145,-2.35168,-1.13751],
                [7.04639,-2.07837,-1.13745],
                [4.81763,-4.51196,-1.13837],
                [-3.64014,-10.2408,-1.13806],
                [2.60706,-6.0094,-1.13831],
                [2.79321,-5.88318,-1.13831],
                [2.99609,-5.74573,-1.13831],
                [-3.75146,-10.3163,-1.13806],
                [5.02466,-4.37177,-1.13837],
                [-3.64014,-10.2407,0.437561],
                [2.60706,-6.00934,0.437561],
                [2.79321,-5.88312,0.437561],
                [2.99622,-5.74573,0.437561],
                [5.02466,-4.37177,0.437561],
                [4.81763,-4.51196,0.437561],
                [-3.75146,-10.3163,0.437603],
                [-0.51654,-8.12509,3.78754],
                [-0.516541,-8.12509,-2.78748],
                [-0.516541,-8.12503,0.587006],
                [-0.51654,-8.12509,2.23642],
                [-0.516541,-8.12509,-1.13818],
                [-0.516541,-8.125,0.437561],
                [-2.07834,-9.18294,-2.78748],
                [-2.07834,-9.18288,0.587112],
                [-2.07834,-9.18294,-1.13812],
                [-2.07834,-9.18283,0.437561],
                [-2.07834,-9.18297,3.78754],
                [-2.07834,-9.18297,2.23628]
        )
        test_faces = #(
                [5,6,7],
                [7,4,5],
                [9,10,11],
                [11,8,9],
                [4,7,13],
                [13,12,4],
                [17,110,22],
                [22,21,17],
                [23,24,21],
                [21,22,23],
                [26,25,8],
                [8,11,26],
                [20,27,23],
                [23,22,20],
                [127,28,27],
                [27,20,127],
                [114,128,127],
                [127,109,114],
                [128,29,28],
                [28,127,128],
                [113,129,128],
                [128,114,113],
                [129,30,29],
                [29,128,129],
                [116,130,129],
                [129,113,116],
                [130,31,30],
                [30,129,130],
                [33,17,21],
                [21,32,33],
                [132,40,41],
                [41,131,132],
                [120,132,131],
                [131,34,120],
                [32,42,40],
                [40,132,32],
                [21,24,42],
                [42,32,21],
                [43,44,8],
                [8,25,43],
                [46,47,48],
                [48,45,46],
                [49,9,8],
                [8,44,49],
                [136,51,52],
                [52,50,136],
                [56,138,137],
                [137,55,56],
                [31,130,63],
                [63,66,31],
                [73,68,67],
                [67,71,73],
                [74,75,25],
                [25,26,74],
                [76,77,78],
                [78,12,76],
                [77,74,26],
                [26,78,77],
                [79,76,12],
                [12,13,79],
                [80,59,137],
                [137,138,80],
                [81,80,138],
                [138,51,81],
                [82,81,51],
                [51,136,82],
                [83,82,136],
                [136,43,83],
                [75,83,43],
                [43,25,75],
                [84,85,6],
                [6,5,84],
                [86,87,10],
                [10,9,86],
                [50,52,48],
                [48,47,50],
                [88,86,9],
                [9,49,88],
                [89,90,16],
                [16,15,89],
                [91,92,19],
                [19,18,91],
                [93,94,36],
                [36,35,93],
                [95,91,18],
                [18,37,95],
                [53,137,59],
                [59,58,53],
                [96,97,62],
                [62,61,96],
                [113,114,75],
                [75,74,113],
                [115,116,77],
                [77,76,115],
                [116,113,74],
                [74,77,116],
                [117,115,76],
                [76,79,117],
                [122,57,59],
                [59,80,122],
                [123,122,80],
                [80,81,123],
                [124,123,81],
                [81,82,124],
                [118,124,82],
                [82,83,118],
                [114,118,83],
                [83,75,114],
                [2,1,134],
                [134,135,2],
                [139,143,104],
                [104,105,139],
                [145,139,105],
                [105,106,145],
                [142,141,100],
                [100,103,142],
                [15,16,109],
                [109,14,15],
                [18,19,110],
                [110,17,18],
                [37,18,17],
                [17,33,37],
                [61,62,111],
                [111,60,61],
                [71,67,112],
                [112,121,71],
                [38,156,155],
                [155,39,38],
                [35,36,120],
                [120,34,35],
                [64,63,60],
                [60,111,64],
                [70,133,121],
                [121,112,70],
                [146,162,160],
                [160,119,146],
                [148,149,101],
                [101,102,148],
                [152,146,119],
                [119,98,152],
                [58,59,57],
                [57,126,58],
                [14,109,127],
                [127,20,14],
                [39,34,131],
                [131,38,39],
                [116,60,63],
                [63,130,116],
                [65,66,63],
                [63,64,65],
                [69,72,133],
                [133,70,69],
                [98,119,135],
                [135,134,98],
                [3,153,156],
                [156,38,3],
                [54,55,137],
                [137,53,54],
                [151,149,143],
                [143,139,151],
                [150,151,139],
                [139,145,150],
                [53,58,150],
                [150,145,53],
                [148,147,141],
                [141,142,148],
                [99,159,161],
                [161,140,99],
                [103,104,143],
                [143,142,103],
                [108,99,140],
                [140,144,108],
                [140,161,162],
                [162,146,140],
                [142,143,149],
                [149,148,142],
                [125,101,149],
                [149,151,125],
                [107,125,151],
                [151,150,107],
                [58,126,107],
                [107,150,58],
                [102,39,147],
                [147,148,102],
                [106,54,53],
                [53,145,106],
                [38,131,41],
                [41,3,38],
                [144,140,146],
                [146,152,144],
                [164,160,155],
                [155,156,164],
                [147,39,155],
                [155,158,147],
                [163,164,156],
                [156,153,163],
                [100,141,157],
                [157,154,100],
                [141,147,158],
                [158,157,141],
                [158,155,160],
                [160,162,158],
                [154,157,161],
                [161,159,154],
                [157,158,162],
                [162,161,157],
                [135,119,160],
                [160,164,135],
                [2,135,164],
                [164,163,2]
        )
        test_node = mesh vertices:test_vertices faces:test_faces
        test_node.name = uniqueName "WallThickness_ComplexSource_TEST_"
        convertToPoly test_node
        try (test_node.baseObject.showCage = off) catch ()
        all_faces = #{1..210}
        polyop.setFaceMatID test_node all_faces 1
        polyop.setFaceSmoothGroup test_node all_faces 0
        polyop.setFaceSmoothGroup test_node #{187,188} 1
        setUserProp test_node wall_thickness_user_prop 0.2
        setUserProp test_node wall_thickness_source_vert_count_prop 164
        setUserProp test_node wall_thickness_source_face_count_prop 210
        update test_node
        select test_node
        /*
        The uploaded reference has one enabled STRAIGHT EDGE FIXER Edit Poly with faces 70 and 95 selected.
        The evaluated diagnostic geometry is already reconstructed in the base object; this modifier preserves the reference stack/selection context without changing geometry.
        */
        reference_modifier = Edit_Poly()
        reference_modifier.name = "STRAIGHT EDGE FIXER"
        reference_modifier.showCage = off
        addModifier test_node reference_modifier
        if WallThicknessPreprocess.prepareEditPoly test_node reference_modifier selection_level:#Face then
        (
                EditPolyMod.SetSelection reference_modifier #Face #{70,95} node:test_node
                reference_modifier.RefreshScreen()
        )
        quadrify_succeeded = quadrifyWallThicknessTestObject test_node
        centerPivot test_node
        test_node.pos = [0,0,0]
        update test_node
        max modify mode
        subObjectLevel = 0
        completeRedraw()
        format "Wall Thickness COMPLEX SOURCE TEST: base verts:% | base faces:% | Straight Edge Fixer selection:2 | quadrify:% | pivot/position:[0,0,0] | WallThickness:0.2.\n" (polyop.getNumVerts test_node.baseObject) (polyop.getNumFaces test_node.baseObject) quadrify_succeeded
        test_node
        -- return
)
/*
Tests exact reconstruction of the uploaded Object010 diagnostic mesh.
The created object remains in the scene for direct inspection and undo.
*/
function testWallThicknessUploadedTestObject =
(
        test_node = undefined
        undo "Create Complex Wall Thickness Source Test" on
        (
                test_node = createWallThicknessUploadedTest()
        )
        test_passed = isValidNode test_node
        base_verts_ok = false
        base_faces_ok = false
        reference_modifier_ok = false
        reference_selection_ok = false
        quadrify_ok = false
        position_ok = false
        bounds_center_ok = false
        thickness_ok = false
        source_counts_ok = false
        if test_passed then
        (
                base_verts_ok = (polyop.getNumVerts test_node.baseObject == 164)
                base_faces_ok = (polyop.getNumFaces test_node.baseObject == 210)
                reference_modifier = getWallThicknessNamedModifier test_node "STRAIGHT EDGE FIXER"
                reference_modifier_ok = reference_modifier != undefined
                if reference_modifier_ok then
                (
                        reference_selection = reference_modifier.GetSelection #Face node:test_node
                        reference_selection_ok = (reference_selection == #{70,95})
                )
                quadrify_modifier = getWallThicknessNamedModifier test_node "TEST QUADRIFY"
                quadrify_ok = quadrify_modifier != undefined
                position_ok = (distance test_node.pos [0,0,0]) < 0.000001
                bounds_center = (test_node.min + test_node.max) * 0.5
                bounds_center_ok = (length bounds_center) < 0.01
                stored_thickness = getUserProp test_node wall_thickness_user_prop
                thickness_ok = stored_thickness != undefined and (abs ((stored_thickness as float) - 0.2) < 0.000001)
                stored_source_verts = getUserProp test_node wall_thickness_source_vert_count_prop
                stored_source_faces = getUserProp test_node wall_thickness_source_face_count_prop
                source_counts_ok = (stored_source_verts as integer) == 164 and (stored_source_faces as integer) == 210
                test_passed = base_verts_ok and base_faces_ok and reference_modifier_ok and reference_selection_ok and quadrify_ok and position_ok and bounds_center_ok and thickness_ok and source_counts_ok
        )
        format "Wall Thickness COMPLEX SOURCE OBJECT TEST: % | base verts:% | base faces:% | reference modifier:% | faces 70,95:% | quadrify:% | pos0:% | bounds centered:% | thickness/source props:%.\n" (if test_passed then "PASS" else "FAIL") base_verts_ok base_faces_ok reference_modifier_ok reference_selection_ok quadrify_ok position_ok bounds_center_ok (thickness_ok and source_counts_ok)
        format "Undo order: Create Complex Wall Thickness Source Test.\n"
        test_passed
        -- return
)
/*
Creates connected one-sided exterior test walls with varied plan angles directly as a quadrified Editable Poly.
Each wall segment is created as one native quad; no TEST QUADRIFY or other modifier is added.
*/
function createWallThicknessTest =
(
        wall_height = units.decodeValue "4m"
        plan_scale = wall_height / 100.0
        corner_edge_distance = units.decodeValue "0.40m"
        corner_points = #(
                [0, 0, 0],
                [120, 0, 0],
                [120, 90, 0],
                [200, 90, 0],
                [200, 170, 0],
                [155, 225, 0],
                [75, 190, 0],
                [5, 245, 0],
                [-70, 245, 0],
                [-70, 150, 0],
                [-145, 150, 0]
        )
        for point_id = 1 to corner_points.count do
        (
                corner_points[point_id] *= plan_scale
        )
        plan_points = #(corner_points[1])
        for corner_id = 2 to (corner_points.count - 1) do
        (
                previous_point = corner_points[corner_id - 1]
                corner_point = corner_points[corner_id]
                next_point = corner_points[corner_id + 1]
                incoming_vector = previous_point - corner_point
                outgoing_vector = next_point - corner_point
                incoming_length = length incoming_vector
                outgoing_length = length outgoing_vector
                if incoming_length > 0.000001 and outgoing_length > 0.000001 then
                (
                        incoming_distance = amin corner_edge_distance (incoming_length * 0.25)
                        outgoing_distance = amin corner_edge_distance (outgoing_length * 0.25)
                        incoming_point = corner_point + ((normalize incoming_vector) * incoming_distance)
                        outgoing_point = corner_point + ((normalize outgoing_vector) * outgoing_distance)
                        append plan_points incoming_point
                        append plan_points corner_point
                        append plan_points outgoing_point
                )
                else
                (
                        append plan_points corner_point
                )
        )
        append plan_points corner_points[corner_points.count]
        test_node = editable_mesh name:"WallThickness_Angles_TEST"
        convertTo test_node Editable_Poly
        test_poly = test_node.baseObject
        try (test_poly.showCage = off) catch ()
        for plan_point in plan_points do
        (
                polyop.createVert test_poly [plan_point.x, plan_point.y, 0]
                polyop.createVert test_poly [plan_point.x, plan_point.y, wall_height]
        )
        for segment_id = 1 to (plan_points.count - 1) do
        (
                bottom_a = ((segment_id - 1) * 2) + 1
                top_a = bottom_a + 1
                bottom_b = bottom_a + 2
                top_b = bottom_a + 3
                /* One native quad per wall panel keeps the same winding as the former triangle pair. */
                polyop.createPolygon test_poly #(bottom_a, bottom_b, top_b, top_a)
        )
        face_count = polyop.getNumFaces test_poly
        if face_count > 0 then
        (
                all_faces = #{1..face_count}
                polyop.setFaceMatID test_poly all_faces 1
                polyop.setFaceSmoothGroup test_poly all_faces 0
        )
        update test_node
        select test_node
        format "Wall Thickness ANGLE TEST: height 4m | corner support edges:0.40m | vertical edges:% | native quad panels:% | no TEST QUADRIFY modifier.\n" plan_points.count face_count
        test_node
        -- return
)
/*
Tests that the basic angle-test object is generated directly as a quadrified Editable Poly with no TEST QUADRIFY modifier.
The object remains in the scene so the added vertical edges around every interior corner can be inspected directly.
*/
function testWallThicknessAngleTestObject =
(
        test_node = createWallThicknessTest()
        height_ok = false
        no_test_modifier_ok = false
        corner_support_topology_ok = false
        face_degree_ok = true
        smoothing_groups_ok = true
        if isValidNode test_node then
        (
                test_height = test_node.max.z - test_node.min.z
                expected_height = units.decodeValue "4m"
                height_ok = abs (test_height - expected_height) <= (amax 0.001 (expected_height * 0.000001))
                no_test_modifier_ok = getWallThicknessNamedModifier test_node "TEST QUADRIFY" == undefined
                test_poly = test_node.baseObject
                vertex_count = polyop.getNumVerts test_poly
                face_count = polyop.getNumFaces test_poly
                corner_support_topology_ok = vertex_count == 58 and face_count == 28
                for face_id = 1 to face_count while face_degree_ok do
                (
                        face_vertices = polyop.getFaceVerts test_poly face_id
                        face_degree_ok = face_vertices.count == 4
                )
                test_mesh = snapshotAsMesh test_node
                if test_mesh == undefined then
                (
                        smoothing_groups_ok = false
                )
                else
                (
                        mesh_face_count = getNumFaces test_mesh
                        for face_id = 1 to mesh_face_count while smoothing_groups_ok do
                        (
                                smoothing_groups_ok = getFaceSmoothGroup test_mesh face_id == 0
                        )
                        free test_mesh
                )
        )
        test_passed = height_ok and no_test_modifier_ok and corner_support_topology_ok and face_degree_ok and smoothing_groups_ok
        format "Wall Thickness ANGLE TEST OBJECT TEST: % | height 4m:% | 58v/28q:% | no TEST QUADRIFY:% | all native quads:% | smoothing 0:%\n" (if test_passed then "PASS" else "FAIL") height_ok corner_support_topology_ok no_test_modifier_ok face_degree_ok smoothing_groups_ok
        test_passed
        -- return
)
/*
Creates a narrow orthogonal wall path with a run shorter than the requested thickness.
The test validates strict face-normal extrusion and corner stitching without averaged vertex motion.
*/
function createWallThicknessOverlapTest =
(
        test_node = undefined
        undo "Create Wall Thickness Overlap Test" on
        (
                wall_height = 100.0
                plan_points = #(
                        [0, 0, 0],
                        [120, 0, 0],
                        [120, 24, 0],
                        [35, 24, 0],
                        [35, 120, 0]
                )
                test_vertices = #()
                for plan_point in plan_points do
                (
                        append test_vertices [plan_point.x, plan_point.y, 0]
                        append test_vertices [plan_point.x, plan_point.y, wall_height]
                )
                test_faces = #()
                for segment_id = 1 to (plan_points.count - 1) do
                (
                        bottom_a = ((segment_id - 1) * 2) + 1
                        top_a = bottom_a + 1
                        bottom_b = bottom_a + 2
                        top_b = bottom_a + 3
                        append test_faces [bottom_a, bottom_b, top_b]
                        append test_faces [bottom_a, top_b, top_a]
                )
                test_node = mesh vertices:test_vertices faces:test_faces
                test_node.name = "WallThickness_Overlap_TEST"
                convertToPoly test_node
                update test_node
                select test_node
        )
        applyWallThickness test_node 40.0
        test_node
        -- return
)
/*
Runs the strict face-normal shell through the complete non-collapsing CLEANUP history and reports whether open edges remain.
The test object stays in the scene so every preprocessing and cleanup modifier can be inspected directly.
*/
function testWallThicknessFinishOverlap =
(
        test_node = createWallThicknessOverlapTest()
        cleanup_succeeded = cleanupWallThickness test_node
        open_edge_count = -1
        if cleanup_succeeded then
        (
                result_mesh = snapshotAsMesh test_node
                if result_mesh != undefined then
                (
                        open_edge_count = (meshop.getOpenEdges result_mesh).numberSet
                        free result_mesh
                )
        )
        test_passed = cleanup_succeeded and (open_edge_count == 0)
        format "Wall Thickness STRICT NORMAL TEST: % | open edges: %\n" (if test_passed then "PASS" else "FAIL") open_edge_count
        format "Undo order: Cleanup Wall Thickness -> Wall Thickness Preprocess + Thickness -> Create Wall Thickness Overlap Test.\n"
        test_passed
        -- return
)
/*
Runs a practical validation on the selected generated wall.
Checks the Edit Poly modifier and required material IDs 1, 2 and 3.
*/
function testWallThicknessResult =
(
        if selection.count != 1 then
        (
                format "Wall Thickness TEST: FAIL - select one generated wall.\n"
                false
        )
        else
        (
                source_node = selection[1]
                edit_modifier = getWallThicknessModifier source_node
                if edit_modifier == undefined then
                (
                        format "Wall Thickness TEST: FAIL - WALL THICKNESS Edit Poly modifier not found.\n"
                        false
                )
                else
                (
                        face_count = edit_modifier.GetNumFaces node:source_node
                        id_1_count = 0
                        id_2_count = 0
                        id_3_count = 0
                        for face_id = 1 to face_count do
                        (
                                material_id = edit_modifier.GetFaceMaterial face_id node:source_node
                                case material_id of
                                (
                                        1: id_1_count += 1
                                        2: id_2_count += 1
                                        3: id_3_count += 1
                                )
                        )
                        test_passed = (id_1_count > 0) and (id_2_count > 0) and (id_3_count > 0)
                        format "Wall Thickness TEST:\n"
                        format "  Edit Poly: %\n" (classOf edit_modifier == Edit_Poly)
                        format "  Material ID 1 outer/source wall faces: %\n" id_1_count
                        format "  Material ID 2 inner/extruded wall faces: %\n" id_2_count
                        format "  Material ID 3 strip faces: %\n" id_3_count
                        format "  RESULT: %\n" (if test_passed then "PASS" else "FAIL")
                        test_passed
                )
        )
        -- return
)
/*
Tests metric scaled-thickness formatting with the requested 0.003 meter example.
The expected compact result is exactly 3 mm.
*/
function testWallThicknessScaledUnits =
(
        test_value = units.decodeValue "0.003m"
        metric_data = getWallThicknessNiceMetricValue test_value
        test_passed = ((abs (metric_data[1] - 3.0)) < 0.0001) and (metric_data[2] == "mm")
        format "Wall Thickness SCALED UNIT TEST: % | value:% %\n" (if test_passed then "PASS" else "FAIL") metric_data[1] metric_data[2]
        test_passed
        -- return
)
/*
Tests RESET by creating a live thickness modifier and removing it again.
The generated test wall stays in the scene so the modifier stack can be inspected after the test.
*/
function testWallThicknessReset =
(
        test_node = createWallThicknessOverlapTest()
        live_before = getWallThicknessModifier test_node
        reset_succeeded = resetWallThickness test_node
        live_after = getWallThicknessModifier test_node
        finished_after = getFinishedWallThicknessModifier test_node
        test_passed = (live_before != undefined) and reset_succeeded and (live_after == undefined) and (finished_after == undefined)
        format "Wall Thickness RESET TEST: %\n" (if test_passed then "PASS" else "FAIL")
        test_passed
        -- return
)
/*
Tests the isolated cleanup builder on one four-edge generated-style hole.
The test leaves the Editable Poly pyramid and cleanup modifier in the scene for inspection.
*/
function testWallThicknessPostProcessCleanup =
(
        test_node = undefined
        undo "Create Wall Thickness Cleanup Test" on
        (
                test_node = mesh name:"WallThickness_Cleanup_Test" vertices:#([0,0,0], [100,0,0], [100,100,0], [0,100,0], [50,50,100]) faces:#([1,2,5], [2,3,5], [3,4,5], [4,1,5])
                convertToPoly test_node
                try (test_node.showCage = off) catch ()
        )
        test_mesh = snapshotAsMesh test_node
        cleanup_loops = getWallThicknessSimpleOpenLoops test_mesh
        build_data = undefined
        undo "Wall Thickness Cleanup Test" on
        (
                build_data = buildWallThicknessCleanupModifier test_node test_mesh cleanup_loops
        )
        free test_mesh
        validation_mesh = snapshotAsMesh test_node
        open_edge_count = if validation_mesh != undefined then (meshop.getOpenEdges validation_mesh).numberSet else -1
        if validation_mesh != undefined then free validation_mesh
        test_passed = (cleanup_loops.count == 1) and build_data[1] and (build_data[5] == 1) and (open_edge_count == 0)
        format "Wall Thickness POSTPROCESS CLEANUP TEST: % | loops: % | quads: % | open edges: %\n" (if test_passed then "PASS" else "FAIL") cleanup_loops.count build_data[5] open_edge_count
        format "Undo order: Wall Thickness Cleanup Test -> Create Wall Thickness Cleanup Test.\n"
        select test_node
        test_passed
        -- return
)
/*
Tests that CLEANUP remains a visible modifier history and never collapses the source object.
The object stays in the final cleaned state for direct stack inspection.
*/
function testWallThicknessCleanupHistory =
(
        test_node = createWallThicknessOverlapTest()
        base_class_before = classOf test_node.baseObject
        cleanup_succeeded = cleanupWallThickness test_node
        quadrify_modifier = getWallThicknessNamedModifier test_node wall_thickness_cleanup_quadrify_modifier_name
        cap_modifier = getWallThicknessNamedModifier test_node wall_thickness_cleanup_cap_modifier_name
        weld_modifier = getWallThicknessNamedModifier test_node wall_thickness_cleanup_weld_modifier_name
        multiple_modifier = getWallThicknessNamedModifier test_node wall_thickness_cleanup_multiple_modifier_name
        cleanup_modifier = getWallThicknessCleanupModifier test_node
        thickness_modifier = getWallThicknessModifier test_node
        test_passed = cleanup_succeeded
        test_passed = test_passed and (base_class_before == classOf test_node.baseObject)
        test_passed = test_passed and (thickness_modifier != undefined)
        test_passed = test_passed and hasCompletedWallThicknessCleanupHistory test_node
        format "Wall Thickness CLEANUP HISTORY TEST: % | base:% | modifiers:% | quadrify:% cap:% weld:% multiple:% loop-fill:%\n" (if test_passed then "PASS" else "FAIL") (classOf test_node.baseObject) test_node.modifiers.count (quadrify_modifier != undefined) (cap_modifier != undefined) (weld_modifier != undefined) (multiple_modifier != undefined) (cleanup_modifier != undefined)
        test_passed
        -- return
)
/*
Tests the five split PRE-PROCESS actions in numbered order.
Every stage must remain visible after step 05 and WELD SOURCE must keep threshold 0.0.
*/
/*
Tests PREP 01 hard Reset XForm on multiple selected objects.
Every run must bake the current stack, restore the creation pivot, and execute again even when the completion user property already exists.
*/
function testWallThicknessResetXFormSelected =
(
        test_a = box name:(uniqueName "WallThickness_ResetXForm_A_") width:100 length:100 height:100 pos:[-150,0,0]
        test_b = box name:(uniqueName "WallThickness_ResetXForm_B_") width:100 length:100 height:100 pos:[150,0,0]
        created_pivot_a = test_a.pivot
        created_pivot_b = test_b.pivot
        test_a.scale = [2,1,1]
        test_b.scale = [1,3,1]
        test_a.pivot = created_pivot_a + [25,10,5]
        test_b.pivot = created_pivot_b + [-20,15,7]
        select #(test_a, test_b)
        first_result = preprocessWallThicknessResetXFormSelected (selection as array)
        first_state_ok = first_result[1] and (first_result[2] == 2) and (first_result[3] == 0) and (first_result[4] == 0)
        first_state_ok = first_state_ok and (test_a.scale == [1,1,1]) and (test_b.scale == [1,1,1])
        first_state_ok = first_state_ok and (test_a.pivot == created_pivot_a) and (test_b.pivot == created_pivot_b)
        first_state_ok = first_state_ok and hasWallThicknessXFormApplied test_a and hasWallThicknessXFormApplied test_b
        user_edit_poly = Edit_Poly()
        user_edit_poly.name = "USER MODIFIER BEFORE SECOND HARD RESET"
        user_edit_poly.showCage = off
        addModifier test_a user_edit_poly
        test_a.scale = [1,1.5,1]
        test_b.scale = [0.75,1,1]
        test_a.pivot = created_pivot_a + [10,20,30]
        test_b.pivot = created_pivot_b + [-10,-20,15]
        update test_a
        update test_b
        second_result = preprocessWallThicknessResetXFormSelected (selection as array)
        second_state_ok = second_result[1] and (second_result[2] == 2) and (second_result[3] == 0) and (second_result[4] == 0)
        second_state_ok = second_state_ok and (test_a.scale == [1,1,1]) and (test_b.scale == [1,1,1])
        second_state_ok = second_state_ok and (test_a.pivot == created_pivot_a) and (test_b.pivot == created_pivot_b)
        second_state_ok = second_state_ok and (getWallThicknessNamedModifier test_a "USER MODIFIER BEFORE SECOND HARD RESET" == undefined)
        test_passed = first_state_ok and second_state_ok
        format "Wall Thickness HARD RESET XFORM TEST: % | first applied:% | second applied:% | pivots reset:% | second stack baked:%\n" (if test_passed then "PASS" else "FAIL") first_result[2] second_result[2] ((test_a.pivot == created_pivot_a) and (test_b.pivot == created_pivot_b)) (getWallThicknessNamedModifier test_a "USER MODIFIER BEFORE SECOND HARD RESET" == undefined)
        test_passed
        -- return
)
function testWallThicknessPreWeld =
(
        test_node = plane name:"WallThickness_Preprocess_Test" length:100 width:100 lengthsegs:1 widthsegs:1
        convertToPoly test_node
        try (test_node.baseObject.showCage = off) catch ()
        select test_node
        step_results = #()
        for step_number = 1 to 6 do
        (
                append step_results (preprocessWallThicknessStep test_node step_number)
        )
        remove_generated_modifier = getWallThicknessNamedModifier test_node wall_thickness_remove_generated_modifier_name
        pre_weld_modifier = getWallThicknessPreWeldModifier test_node
        degenerate_modifier = getWallThicknessNamedModifier test_node wall_thickness_degenerate_modifier_name
        multiple_modifier = getWallThicknessNamedModifier test_node wall_thickness_multiple_edges_modifier_name
        border_modifier = getWallThicknessNamedModifier test_node wall_thickness_border_check_modifier_name
        test_passed = true
        for step_result in step_results while test_passed do
        (
                test_passed = step_result
        )
        test_passed = test_passed and (remove_generated_modifier != undefined)
        test_passed = test_passed and (pre_weld_modifier != undefined)
        test_passed = test_passed and (degenerate_modifier != undefined)
        test_passed = test_passed and (multiple_modifier != undefined)
        test_passed = test_passed and (border_modifier != undefined)
        if test_passed then
        (
                test_passed = (abs pre_weld_modifier.threshold) < 0.000001
        )
        format "Wall Thickness SPLIT PREPROCESS TEST: % | stages:% | source weld threshold:%
" (if test_passed then "PASS" else "FAIL") 6 (if pre_weld_modifier != undefined then pre_weld_modifier.threshold else undefined)
        format "Undo order: PREP 06 -> PREP 05 -> PREP 04 -> PREP 03 -> PREP 02 -> PREP 01.
"
        test_passed
        -- return
)
/*
Tests that EXTRUDE keeps the exact PRE-PROCESS modifier instances already visible in the stack.
No PREP stage may be deleted or rebuilt between PRE-PROCESS SOURCE and EXTRUDE.
*/
/*
Tests the EXTRUDE / UPDATE single-modifier contract on a deliberately triangulated source wall.
After extrusion the node must contain exactly one modifier named WALL THICKNESS, with no automatic Quadrify modifier, and the source triangles must remain triangles.
*/
function testWallThicknessSingleModifierExtrude =
(
        test_vertices = #(
                [0,0,0],
                [100,0,0],
                [100,0,100],
                [0,0,100]
        )
        test_faces = #(
                [1,2,3],
                [1,3,4]
        )
        test_node = mesh vertices:test_vertices faces:test_faces
        test_node.name = uniqueName "WallThickness_SingleModifier_TEST_"
        convertToPoly test_node
        try (test_node.baseObject.showCage = off) catch ()
        select test_node
        extrude_succeeded = applyWallThickness test_node 10.0
        thickness_modifier = getWallThicknessModifier test_node
        auto_quadrify_modifier = getWallThicknessNamedModifier test_node wall_thickness_auto_quadrify_modifier_name
        single_modifier_ok = test_node.modifiers.count == 1 and thickness_modifier != undefined and auto_quadrify_modifier == undefined
        source_triangles_ok = false
        if thickness_modifier != undefined then
        (
                source_triangles_ok = true
                for face_id = 1 to 2 while source_triangles_ok do
                (
                        if thickness_modifier.GetFaceDegree face_id node:test_node != 3 then
                        (
                                source_triangles_ok = false
                        )
                )
        )
        test_passed = extrude_succeeded and single_modifier_ok and source_triangles_ok
        format "Wall Thickness SINGLE MODIFIER EXTRUDE TEST: % | one WALL THICKNESS modifier:% | source triangles preserved:%\n" (if test_passed then "PASS" else "FAIL") single_modifier_ok source_triangles_ok
        test_passed
        -- return
)
/*
Tests EXTRUDE on the clean modifier-free native angle-test source.
The path must initialize WALL THICKNESS correctly, keep one shared offset vertex per source vertex, and produce 28 material-ID 2 quad polygons with hidden triangulation.
*/
function testWallThicknessV008Extrude =
(
        test_node = createWallThicknessTest()
        test_thickness = units.decodeValue "0.20m"
        source_mesh = snapshotAsMesh test_node
        source_vert_count = if source_mesh != undefined then meshop.getNumVerts source_mesh else 0
        if source_mesh != undefined then free source_mesh
        source_polygon_face_count = polyop.getNumFaces test_node.baseObject
        extrude_succeeded = applyWallThickness test_node test_thickness
        thickness_modifier = getWallThicknessModifier test_node
        generated_vert_count = 0
        material_ids_preserved = true
        inner_quad_count = 0
        inner_hidden_triangulation_ok = true
        if thickness_modifier != undefined then
        (
                generated_vert_count = (EditPolyMod.GetNumVertices thickness_modifier node:test_node) - source_vert_count
                for face_id = 1 to source_polygon_face_count while material_ids_preserved do
                (
                        source_material_id = polyop.getFaceMatID test_node.baseObject face_id
                        outer_material_id = thickness_modifier.GetFaceMaterial face_id node:test_node
                        inner_face_id = source_polygon_face_count + face_id
                        inner_material_id = thickness_modifier.GetFaceMaterial inner_face_id node:test_node
                        material_ids_preserved = (outer_material_id == source_material_id) and (inner_material_id == source_material_id)
                        if thickness_modifier.GetFaceDegree inner_face_id node:test_node == 4 then
                        (
                                inner_quad_count += 1
                        )
                        else
                        (
                                inner_hidden_triangulation_ok = false
                        )
                )
        )
        test_passed =
                extrude_succeeded and
                (thickness_modifier != undefined) and
                (generated_vert_count == source_vert_count) and
                material_ids_preserved and
                (inner_quad_count == source_polygon_face_count) and
                inner_hidden_triangulation_ok
        format "Wall Thickness v0.08 EXTRUDE TEST: % | source/outer verts:% | generated offset verts:% | Material IDs preserved:% | generated inner quads:% | hidden triangulation:%\n" (if test_passed then "PASS" else "FAIL") source_vert_count generated_vert_count material_ids_preserved inner_quad_count inner_hidden_triangulation_ok
        test_passed
        -- return
)
/*
Tests both states of the CHANGE MATERIAL IDS mode used by EXTRUDE / UPDATE.
A source quad with Material ID 7 stays ID 7 while the mode is off and rebuilds to outer/inner/strip IDs 1/2/3 while the mode is on.
*/
function testWallThicknessChangeMaterialIds =
(
        test_node = plane name:(uniqueName "WallThickness_MaterialIds_TEST_") length:100 width:100 lengthsegs:1 widthsegs:1
        convertToPoly test_node
        polyop.setFaceMatID test_node.baseObject #{1} 7
        update test_node
        select test_node
        extrude_preserve_succeeded = applyWallThickness test_node (units.decodeValue "100mm") change_material_ids:false
        thickness_modifier = getWallThicknessModifier test_node
        preserved_with_mode_off = false
        changed_with_mode_on = false
        if extrude_preserve_succeeded and thickness_modifier != undefined then
        (
                live_face_count = thickness_modifier.GetNumFaces node:test_node
                preserved_with_mode_off = live_face_count >= 3
                for face_id = 1 to live_face_count while preserved_with_mode_off do
                (
                        preserved_with_mode_off = thickness_modifier.GetFaceMaterial face_id node:test_node == 7
                )
        )
        extrude_change_succeeded = applyWallThickness test_node (units.decodeValue "100mm") change_material_ids:true
        thickness_modifier = getWallThicknessModifier test_node
        if extrude_change_succeeded and thickness_modifier != undefined then
        (
                source_face_count = (getUserProp test_node wall_thickness_source_face_count_prop) as integer
                required_face_count = source_face_count * 2
                live_face_count = thickness_modifier.GetNumFaces node:test_node
                changed_with_mode_on = live_face_count >= required_face_count
                for face_id = 1 to source_face_count while changed_with_mode_on do
                (
                        changed_with_mode_on = thickness_modifier.GetFaceMaterial face_id node:test_node == 1
                )
                for face_id = (source_face_count + 1) to required_face_count while changed_with_mode_on do
                (
                        changed_with_mode_on = thickness_modifier.GetFaceMaterial face_id node:test_node == 2
                )
                if changed_with_mode_on and live_face_count > required_face_count then
                (
                        for face_id = (required_face_count + 1) to live_face_count while changed_with_mode_on do
                        (
                                changed_with_mode_on = thickness_modifier.GetFaceMaterial face_id node:test_node == 3
                        )
                )
        )
        test_passed = extrude_preserve_succeeded and extrude_change_succeeded and preserved_with_mode_off and changed_with_mode_on
        format "Wall Thickness CHANGE MATERIAL IDS CHECKBOX TEST: % | OFF kept ID 7:% | ON changed to 1/2/3:%\n" (if test_passed then "PASS" else "FAIL") preserved_with_mode_off changed_with_mode_on
        format "Undo order: Wall Thickness Extrude (mode ON), Wall Thickness Extrude (mode OFF).\n"
        test_passed
        -- return
)
function testWallThicknessExtrudePreservesPreprocess =
(
        test_node = plane name:(uniqueName "WallThickness_PreservePreprocess_TEST_") length:100 width:100 lengthsegs:1 widthsegs:1
        convertToPoly test_node
        select test_node
        preprocess_succeeded = preprocessWallThickness test_node
        remove_generated_before = getWallThicknessNamedModifier test_node wall_thickness_remove_generated_modifier_name
        weld_before = getWallThicknessNamedModifier test_node wall_thickness_source_weld_modifier_name
        degenerate_before = getWallThicknessNamedModifier test_node wall_thickness_degenerate_modifier_name
        multiple_before = getWallThicknessNamedModifier test_node wall_thickness_multiple_edges_modifier_name
        border_before = getWallThicknessNamedModifier test_node wall_thickness_border_check_modifier_name
        extrude_succeeded = applyWallThickness test_node 10.0
        test_passed = preprocess_succeeded and extrude_succeeded
        test_passed = test_passed and (remove_generated_before == getWallThicknessNamedModifier test_node wall_thickness_remove_generated_modifier_name)
        test_passed = test_passed and (weld_before == getWallThicknessNamedModifier test_node wall_thickness_source_weld_modifier_name)
        test_passed = test_passed and (degenerate_before == getWallThicknessNamedModifier test_node wall_thickness_degenerate_modifier_name)
        test_passed = test_passed and (multiple_before == getWallThicknessNamedModifier test_node wall_thickness_multiple_edges_modifier_name)
        test_passed = test_passed and (border_before == getWallThicknessNamedModifier test_node wall_thickness_border_check_modifier_name)
        format "Wall Thickness EXTRUDE PRESERVES PREPROCESS TEST: %\n" (if test_passed then "PASS" else "FAIL")
        test_passed
        -- return
)
/*
Tests that EXTRUDE runs directly on a clean mesh without creating PRE-PROCESS modifiers.
Only WALL THICKNESS may be added by this action.
*/
function testWallThicknessExtrudeWithoutPreprocess =
(
        test_node = plane name:(uniqueName "WallThickness_DirectExtrude_TEST_") length:100 width:100 lengthsegs:1 widthsegs:1
        convertToPoly test_node
        select test_node
        extrude_succeeded = applyWallThickness test_node 10.0
        prep_count = 0
        if getWallThicknessNamedModifier test_node wall_thickness_remove_generated_modifier_name != undefined then prep_count += 1
        if getWallThicknessNamedModifier test_node wall_thickness_source_weld_modifier_name != undefined then prep_count += 1
        if getWallThicknessNamedModifier test_node wall_thickness_degenerate_modifier_name != undefined then prep_count += 1
        if getWallThicknessNamedModifier test_node wall_thickness_multiple_edges_modifier_name != undefined then prep_count += 1
        if getWallThicknessNamedModifier test_node wall_thickness_border_check_modifier_name != undefined then prep_count += 1
        test_passed = extrude_succeeded and prep_count == 0 and getWallThicknessModifier test_node != undefined
        format "Wall Thickness DIRECT EXTRUDE TEST: % | PREP modifiers created: %\n" (if test_passed then "PASS" else "FAIL") prep_count
        test_passed
        -- return
)
/*
Tests that PREP 04 keeps multiple edges selected as a warning without failing preprocessing.
Three closed tetrahedral shells share one source edge so the object has a non-manifold multiple edge but no open border.
*/
function testWallThicknessMultipleEdgeWarning =
(
        test_node = undefined
        undo "Create Wall Thickness Multiple Edge Warning Test" on
        (
                test_vertices = #(
                        [0,0,0], [100,0,0],
                        [25,30,30], [25,-30,30],
                        [50,30,-30], [50,-30,-30],
                        [75,30,30], [75,-30,30]
                )
                test_faces = #(
                        [1,2,3], [1,4,2], [1,3,4], [2,4,3],
                        [1,2,5], [1,6,2], [1,5,6], [2,6,5],
                        [1,2,7], [1,8,2], [1,7,8], [2,8,7]
                )
                test_node = mesh name:"WallThickness_MultipleEdgeWarning_TEST" vertices:test_vertices faces:test_faces
                convertToPoly test_node
                try (test_node.showCage = off) catch ()
                select test_node
        )
        preprocess_data = undefined
        undo "Wall Thickness Multiple Edge Warning Preprocess" on
        (
                preprocess_data = runWallThicknessPreprocess test_node
        )
        multiple_modifier = getWallThicknessNamedModifier test_node wall_thickness_multiple_edges_modifier_name
        selected_edges = if multiple_modifier != undefined then multiple_modifier.GetSelection #Edge node:test_node else #{}
        test_passed = preprocess_data != undefined and preprocess_data[1] and (multiple_modifier != undefined) and (selected_edges.numberSet > 0)
        format "Wall Thickness MULTIPLE EDGE WARNING TEST: % | selected warnings: % | message: %\n" (if test_passed then "PASS" else "FAIL") selected_edges.numberSet (if preprocess_data != undefined then preprocess_data[2] else undefined)
        format "Undo order: Wall Thickness Multiple Edge Warning Preprocess -> Create Wall Thickness Multiple Edge Warning Test.\n"
        test_passed
        -- return
)
/*
Tests that the final degenerate-border gate still blocks a disconnected border vertex lying on another border edge.
Multiple-edge warnings are permissive, but PREP 05 remains a hard source-topology gate.
*/
function testWallThicknessDegenerateBorderGate =
(
        test_node = undefined
        undo "Create Wall Thickness Degenerate Border Test" on
        (
                test_node = mesh name:"WallThickness_DegenerateBorder_TEST" vertices:#([0,0,0], [100,0,0], [0,100,0], [50,0,0], [50,-50,0], [75,-50,0]) faces:#([1,2,3], [4,5,6])
                convertToPoly test_node
                try (test_node.showCage = off) catch ()
                select test_node
        )
        apply_succeeded = applyWallThickness test_node 10.0
        border_modifier = getWallThicknessNamedModifier test_node wall_thickness_border_check_modifier_name
        thickness_modifier = getWallThicknessModifier test_node
        selected_edges = if border_modifier != undefined then border_modifier.GetSelection #Edge node:test_node else #{}
        test_passed = (not apply_succeeded) and (border_modifier != undefined) and (thickness_modifier == undefined) and (selected_edges.numberSet > 0)
        format "Wall Thickness DEGENERATE BORDER GATE TEST: % | selected border errors: %\n" (if test_passed then "PASS" else "FAIL") selected_edges.numberSet
        format "Undo order: Wall Thickness Preprocess + Thickness -> Create Wall Thickness Degenerate Border Test.\n"
        test_passed
        -- return
)
/*
Tests that EXTRUDE / UPDATE does not create a temporary STL CHECK before WALL THICKNESS.
A clean open source must receive WALL THICKNESS directly with no STL CHECK modifier.
*/
function testWallThicknessPreExtrudeSTL =
(
        test_node = plane name:(uniqueName "WALL_THICKNESS_NO_PRE_STL_") width:20 length:20 widthsegs:1 lengthsegs:1
        convertTo test_node Editable_Poly
        try (test_node.baseObject.showCage = off) catch ()
        select test_node
        extrude_succeeded = applyWallThickness test_node 2.0
        thickness_modifier = getWallThicknessModifier test_node
        stl_modifier = getWallThicknessSTLCheckModifier test_node
        test_passed = extrude_succeeded and (thickness_modifier != undefined) and (stl_modifier == undefined) and (test_node.modifiers.count == 1)
        format "Wall Thickness NO PRE-EXTRUDE STL TEST: % | WALL THICKNESS only:%\n" (if test_passed then "PASS" else "FAIL") test_passed
        test_passed
        -- return
)
/*
Tests the FINAL STL CHECK pass/fail contract on one closed box and one open plane.
PASS must remove the temporary modifier; FAIL must keep it on Open Edge.
*/
function testWallThicknessSTLValidation =
(
        closed_node = box name:(uniqueName "WALL_THICKNESS_STL_PASS_") width:20 length:20 height:20
        convertTo closed_node Editable_Poly
        closed_node.showCage = off
        closed_result = validateWallThicknessSTL closed_node show_messages:false
        closed_ok = closed_result[1] and (getWallThicknessSTLCheckModifier closed_node == undefined)
        open_node = plane name:(uniqueName "WALL_THICKNESS_STL_FAIL_") width:20 length:20 widthsegs:1 lengthsegs:1
        convertTo open_node Editable_Poly
        open_node.showCage = off
        open_result = validateWallThicknessSTL open_node show_messages:false
        open_modifier = getWallThicknessSTLCheckModifier open_node
        open_ok = (not open_result[1]) and (open_result[2] == "Open Edge") and (open_modifier != undefined)
        if open_modifier != undefined then open_ok = open_ok and (open_modifier.Selection_Type == 0)
        test_passed = closed_ok and open_ok
        format "Wall Thickness FINAL STL CHECK TEST: % | closed:% | open:%\n" (if test_passed then "PASS" else "FAIL") closed_ok open_ok
        test_passed
        -- return
)
/*
Tests successful CLEANUP state when redundant cleanup modifiers are pruned.
No-op cleanup stages are allowed to be absent while FIX CHAMFERS still sees CLEANUP as complete.
*/
function testWallThicknessCleanupCompletionGate =
(
        test_node = plane name:(uniqueName "WallThickness_CleanupGate_TEST_") length:100 width:100 lengthsegs:1 widthsegs:1
        convertToPoly test_node
        try (test_node.baseObject.showCage = off) catch ()
        select test_node
        extrude_succeeded = applyWallThickness test_node 5.0
        cleanup_succeeded = if extrude_succeeded then cleanupWallThickness test_node else false
        cleanup_complete = hasCompletedWallThicknessCleanupHistory test_node
        multiple_modifier = getWallThicknessNamedModifier test_node wall_thickness_cleanup_multiple_modifier_name
        weld_modifier = getWallThicknessNamedModifier test_node wall_thickness_cleanup_weld_modifier_name
        test_passed = extrude_succeeded and cleanup_succeeded and cleanup_complete
        test_passed = test_passed and (multiple_modifier == undefined)
        test_passed = test_passed and (weld_modifier == undefined)
        format "Wall Thickness CLEANUP NO-OP PRUNE TEST: % | weld kept:% | multiple kept:%\n" (if test_passed then "PASS" else "FAIL") (weld_modifier != undefined) (multiple_modifier != undefined)
        test_passed
        -- return
)
/*
Tests signed source-corner classification used by the separate inner and outer buttons.
*/
function testWallThicknessCornerModes =
(
        edge_direction = [0,0,1]
        inner_signed = dot (cross [1,0,0] [0,1,0]) edge_direction
        outer_signed = dot (cross [0,1,0] [1,0,0]) edge_direction
        test_passed = (inner_signed > 0.0001) and (outer_signed < -0.0001)
        format "Wall Thickness CORNER MODE TEST: % | inner:% | outer:%\\n" (if test_passed then "PASS" else "FAIL") inner_signed outer_signed
        test_passed
        -- return
)
/*
Creates the four-quad boundary-corner regression where one vertical strip is twisted by a three-face upper source corner.
The opposite clean vertical strip provides the established extrusion offset that the skewed strip must match.
*/
function createWallThicknessParallelStripCornerTest =
(
        test_node = undefined
        undo "Create Parallel Strip Corner Test" on
        (
                test_node = editable_mesh name:"WallThickness_ParallelStripCorner_TEST"
                convertTo test_node Editable_Poly
                test_poly = test_node.baseObject
                try (test_poly.showCage = off) catch ()
                wall_width = units.decodeValue "1.0m"
                wall_top = units.decodeValue "1.7m"
                wall_bottom = units.decodeValue "2.65m"
                right_extension = units.decodeValue "1.0m"
                side_extension = units.decodeValue "1.4m"
                polyop.createVert test_poly [wall_width, 0, 0]
                polyop.createVert test_poly [wall_width, 0, wall_top]
                polyop.createVert test_poly [0, 0, wall_top]
                polyop.createVert test_poly [0, 0, 0]
                polyop.createVert test_poly [wall_width, 0, -wall_bottom]
                polyop.createVert test_poly [0, 0, -wall_bottom]
                polyop.createVert test_poly [wall_width + right_extension, 0, 0]
                polyop.createVert test_poly [wall_width + right_extension, 0, wall_top]
                polyop.createVert test_poly [0, -side_extension, 0]
                polyop.createVert test_poly [0, -side_extension, wall_top]
                polyop.createPolygon test_poly #(1, 2, 3, 4)
                polyop.createPolygon test_poly #(1, 4, 6, 5)
                polyop.createPolygon test_poly #(7, 8, 2, 1)
                polyop.createPolygon test_poly #(4, 3, 10, 9)
                face_count = polyop.getNumFaces test_poly
                if face_count > 0 then
                (
                        polyop.setFaceMatID test_poly #{1..face_count} 1
                        polyop.setFaceSmoothGroup test_poly #{1..face_count} 0
                )
                update test_node
                select test_node
        )
        test_node
        -- return
)
/*
Tests the three-face upper / one-face lower vertical border corner against a clean parallel strip reference.
The lower simple generated endpoint and all source vertices stay fixed; only the skewed upper generated endpoint moves in X/Y and keeps Z.
*/
function testWallThicknessParallelStripCorner =
(
        test_node = createWallThicknessParallelStripCornerTest()
        test_thickness = units.decodeValue "0.45m"
        test_tolerance = units.decodeValue "0.01mm"
        test_stack_xy_tolerance = units.decodeValue "1mm"
        test_passed = false
        source_unchanged = true
        topology_unchanged = false
        skew_exists_before = false
        reference_is_clean = false
        target_matches = false
        lower_endpoint_fixed = false
        reference_fixed = false
        target_z_preserved = false
        matching_reference_offset = false
        fix_data = #(false, 0, 0)
        if isValidNode test_node then
        (
                extrude_succeeded = applyWallThickness test_node test_thickness
                if extrude_succeeded then
                (
                        thickness_modifier = getWallThicknessModifier test_node
                        source_vert_count_value = getUserProp test_node wall_thickness_source_vert_count_prop
                        source_vert_count = if source_vert_count_value != undefined then source_vert_count_value as integer else 0
                        if thickness_modifier != undefined and source_vert_count == 10 then
                        (
                                reference_source_upper_id = 1
                                reference_source_lower_id = 5
                                skew_source_upper_id = 4
                                skew_source_lower_id = 6
                                reference_generated_upper_id = source_vert_count + reference_source_upper_id
                                reference_generated_lower_id = source_vert_count + reference_source_lower_id
                                skew_generated_upper_id = source_vert_count + skew_source_upper_id
                                skew_generated_lower_id = source_vert_count + skew_source_lower_id
                                before_vertex_count = thickness_modifier.GetNumVertices node:test_node
                                before_face_count = thickness_modifier.GetNumFaces node:test_node
                                before_source_positions = for source_id = 1 to source_vert_count collect (EditPolyMod.GetVertex thickness_modifier source_id node:test_node)
                                reference_source_lower_position = EditPolyMod.GetVertex thickness_modifier reference_source_lower_id node:test_node
                                skew_source_lower_position = EditPolyMod.GetVertex thickness_modifier skew_source_lower_id node:test_node
                                before_reference_upper = EditPolyMod.GetVertex thickness_modifier reference_generated_upper_id node:test_node
                                before_reference_lower = EditPolyMod.GetVertex thickness_modifier reference_generated_lower_id node:test_node
                                before_skew_upper = EditPolyMod.GetVertex thickness_modifier skew_generated_upper_id node:test_node
                                before_skew_lower = EditPolyMod.GetVertex thickness_modifier skew_generated_lower_id node:test_node
                                if reference_source_lower_position != undefined and skew_source_lower_position != undefined and before_reference_upper != undefined and before_reference_lower != undefined and before_skew_upper != undefined and before_skew_lower != undefined then
                                (
                                        reference_plan_delta = [before_reference_upper.x - before_reference_lower.x, before_reference_upper.y - before_reference_lower.y, 0]
                                        skew_plan_delta = [before_skew_upper.x - before_skew_lower.x, before_skew_upper.y - before_skew_lower.y, 0]
                                        reference_offset = [before_reference_lower.x - reference_source_lower_position.x, before_reference_lower.y - reference_source_lower_position.y, 0]
                                        skew_simple_offset = [before_skew_lower.x - skew_source_lower_position.x, before_skew_lower.y - skew_source_lower_position.y, 0]
                                        reference_is_clean = length reference_plan_delta <= test_stack_xy_tolerance
                                        skew_exists_before = length skew_plan_delta > test_tolerance
                                        matching_reference_offset = distance reference_offset skew_simple_offset <= test_stack_xy_tolerance
                                        expected_target_position = [before_skew_lower.x, before_skew_lower.y, before_skew_upper.z]
                                        fix_data = fixWallThicknessInnerCorners test_node
                                        fixed_modifier = getWallThicknessModifier test_node
                                        after_vertex_count = if fixed_modifier != undefined then fixed_modifier.GetNumVertices node:test_node else 0
                                        after_face_count = if fixed_modifier != undefined then fixed_modifier.GetNumFaces node:test_node else 0
                                        evaluated_mesh = snapshotAsMesh test_node
                                        inverse_object_tm = inverse test_node.objectTransform
                                        after_skew_upper = if evaluated_mesh != undefined then (getVert evaluated_mesh skew_generated_upper_id) * inverse_object_tm else undefined
                                        after_skew_lower = if evaluated_mesh != undefined then (getVert evaluated_mesh skew_generated_lower_id) * inverse_object_tm else undefined
                                        after_reference_upper = if evaluated_mesh != undefined then (getVert evaluated_mesh reference_generated_upper_id) * inverse_object_tm else undefined
                                        after_reference_lower = if evaluated_mesh != undefined then (getVert evaluated_mesh reference_generated_lower_id) * inverse_object_tm else undefined
                                        topology_unchanged = before_vertex_count == after_vertex_count and before_face_count == after_face_count
                                        target_matches = after_skew_upper != undefined and distance after_skew_upper expected_target_position <= test_tolerance
                                        lower_endpoint_fixed = after_skew_lower != undefined and distance after_skew_lower before_skew_lower <= test_tolerance
                                        reference_fixed = after_reference_upper != undefined and after_reference_lower != undefined and distance after_reference_upper before_reference_upper <= test_tolerance and distance after_reference_lower before_reference_lower <= test_tolerance
                                        target_z_preserved = after_skew_upper != undefined and after_skew_upper.z == before_skew_upper.z
                                        for source_id = 1 to source_vert_count while source_unchanged do
                                        (
                                                after_source_position = if evaluated_mesh != undefined then (getVert evaluated_mesh source_id) * inverse_object_tm else undefined
                                                if after_source_position == undefined or distance after_source_position before_source_positions[source_id] > test_tolerance then source_unchanged = false
                                        )
                                        if evaluated_mesh != undefined then free evaluated_mesh
                                )
                        )
                )
        )
        test_passed = fix_data[1] and fix_data[3] > 0 and topology_unchanged and source_unchanged and skew_exists_before and reference_is_clean and matching_reference_offset and target_matches and lower_endpoint_fixed and reference_fixed and target_z_preserved
        format "Wall Thickness PARALLEL STRIP CORNER TEST: % | moved:% | skew before:% | clean reference:% | matching offset:% | target:% | lower fixed:% | reference fixed:% | topology unchanged:% | source unchanged:% | Z preserved:%\n" (if test_passed then "PASS" else "FAIL") fix_data[3] skew_exists_before reference_is_clean matching_reference_offset target_matches lower_endpoint_fixed reference_fixed topology_unchanged source_unchanged target_z_preserved
        format "Undo order: FIX INNER CORNERS, EXTRUDE / UPDATE, Create Parallel Strip Corner Test.\n"
        test_passed
        -- return
)
/*
Creates the 3/2/1 vertical corner stack from the rotated-corner regression.
When flipped is true, X and Z are both inverted, equivalent to a baked 180-degree Y rotation.
*/
function createWallThicknessRotationInvariantCornerTest flipped:false =
(
        test_node = undefined
        undo "Create Rotation Invariant Corner Test" on
        (
                test_node = editable_mesh name:(if flipped then "WallThickness_RotatedCorner180_TEST" else "WallThickness_RotatedCorner0_TEST")
                convertTo test_node Editable_Poly
                test_poly = test_node.baseObject
                try (test_poly.showCage = off) catch ()
                rotation_sign = if flipped then -1.0 else 1.0
                wall_width = units.decodeValue "2.345m"
                wall_run = units.decodeValue "2.4m"
                lower_height = units.decodeValue "0.815m"
                upper_height = units.decodeValue "0.905m"
                polyop.createVert test_poly [wall_width * rotation_sign, 0, 0]
                polyop.createVert test_poly [0, 0, 0]
                polyop.createVert test_poly [0, 0, -lower_height * rotation_sign]
                polyop.createVert test_poly [wall_width * rotation_sign, 0, -lower_height * rotation_sign]
                polyop.createVert test_poly [wall_width * rotation_sign, wall_run, upper_height * rotation_sign]
                polyop.createVert test_poly [wall_width * rotation_sign, 0, upper_height * rotation_sign]
                polyop.createVert test_poly [wall_width * rotation_sign, wall_run, 0]
                polyop.createVert test_poly [wall_width * rotation_sign, wall_run, -lower_height * rotation_sign]
                polyop.createPolygon test_poly #(4, 1, 2, 3)
                polyop.createPolygon test_poly #(7, 5, 6, 1)
                polyop.createPolygon test_poly #(7, 1, 4, 8)
                face_count = polyop.getNumFaces test_poly
                if face_count > 0 then
                (
                        polyop.setFaceMatID test_poly #{1..face_count} 9
                        polyop.setFaceSmoothGroup test_poly #{1..face_count} 0
                )
                update test_node
        )
        test_node
        -- return
)
/*
Tests that the same 3/2/1 inner corner is repaired identically before and after a 180-degree Y rotation.
The generated stack for source vertices 1/4/6 must share one XY and the generated 1-2 edge must remain parallel to source edge 1-2.
*/
function testWallThicknessRotationInvariantInnerCorner =
(
        test_nodes = #(createWallThicknessRotationInvariantCornerTest flipped:false, createWallThicknessRotationInvariantCornerTest flipped:true)
        test_thickness = units.decodeValue "0.45m"
        test_tolerance = units.decodeValue "0.01mm"
        test_passed = true
        result_rows = #()
        for test_node in test_nodes while test_passed do
        (
                node_passed = false
                if isValidNode test_node then
                (
                        extrude_succeeded = applyWallThickness test_node test_thickness change_material_ids:false
                        if extrude_succeeded then
                        (
                                fix_data = fixWallThicknessInnerCorners test_node
                                source_vert_count_value = getUserProp test_node wall_thickness_source_vert_count_prop
                                source_vert_count = if source_vert_count_value != undefined then source_vert_count_value as integer else 0
                                fixed_modifier = getWallThicknessModifier test_node
                                if fix_data[1] and source_vert_count == 8 and fixed_modifier != undefined then
                                (
                                        evaluated_mesh = snapshotAsMesh test_node
                                        if evaluated_mesh != undefined and meshop.getNumVerts evaluated_mesh >= (source_vert_count + 6) then
                                        (
                                                source_1 = getVert evaluated_mesh 1
                                                source_2 = getVert evaluated_mesh 2
                                                generated_1 = getVert evaluated_mesh (source_vert_count + 1)
                                                generated_2 = getVert evaluated_mesh (source_vert_count + 2)
                                                generated_4 = getVert evaluated_mesh (source_vert_count + 4)
                                                generated_6 = getVert evaluated_mesh (source_vert_count + 6)
                                                source_direction = [source_2.x - source_1.x, source_2.y - source_1.y, 0]
                                                generated_delta = [generated_2.x - generated_1.x, generated_2.y - generated_1.y, 0]
                                                if length source_direction > test_tolerance then
                                                (
                                                        source_direction = normalize source_direction
                                                        generated_projection = dot generated_delta source_direction
                                                        generated_cross_track = length (generated_delta - (source_direction * generated_projection))
                                                        stack_14_delta = [generated_4.x - generated_1.x, generated_4.y - generated_1.y, 0]
                                                        stack_16_delta = [generated_6.x - generated_1.x, generated_6.y - generated_1.y, 0]
                                                        stack_aligned = length stack_14_delta <= test_tolerance and length stack_16_delta <= test_tolerance
                                                        edge_parallel = generated_cross_track <= test_tolerance
                                                        node_passed = stack_aligned and edge_parallel
                                                        append result_rows #(test_node.name, stack_aligned, edge_parallel, generated_cross_track, generated_1, generated_4, generated_6)
                                                )
                                        )
                                        if evaluated_mesh != undefined then free evaluated_mesh
                                )
                        )
                )
                if not node_passed then test_passed = false
        )
        format "Wall Thickness ROTATION-INVARIANT INNER CORNER TEST: % | results:%\n" (if test_passed then "PASS" else "FAIL") result_rows
        format "Undo order: FIX INNER CORNERS / EXTRUDE for each test node, then Create Rotation Invariant Corner Test nodes.\n"
        test_passed
        -- return
)
/*
Creates the exact vertical T-stack regression geometry where stacked source vertices have zero XY drift.
The lower terminal member must receive the same generated XY as the continuing stack while preserving its Z.
*/
function createWallThicknessExactVerticalStackTest =
(
        test_node = editable_mesh name:"WallThickness_ExactVerticalStack_TEST"
        convertTo test_node Editable_Poly
        test_poly = test_node.baseObject
        try (test_poly.showCage = off) catch ()
        wall_run = units.decodeValue "3.135m"
        wall_width = units.decodeValue "0.88m"
        wall_top = units.decodeValue "2.65m"
        lower_drop = units.decodeValue "1.395m"
        far_lower_drop = units.decodeValue "1.445m"
        polyop.createVert test_poly [0, 0, 0]
        polyop.createVert test_poly [-wall_width, 0, 0]
        polyop.createVert test_poly [-wall_width, 0, wall_top]
        polyop.createVert test_poly [0, 0, wall_top]
        polyop.createVert test_poly [0, 0, -lower_drop]
        polyop.createVert test_poly [0, wall_run, 0]
        polyop.createVert test_poly [0, wall_run, wall_top]
        polyop.createVert test_poly [0, wall_run, -far_lower_drop]
        polyop.createPolygon test_poly #(2, 1, 4, 3)
        polyop.createPolygon test_poly #(5, 8, 6, 1)
        polyop.createPolygon test_poly #(6, 7, 4, 1)
        face_count = polyop.getNumFaces test_poly
        if face_count > 0 then
        (
                polyop.setFaceMatID test_poly #{1..face_count} 1
                polyop.setFaceSmoothGroup test_poly #{1..face_count} 0
        )
        update test_node
        select test_node
        test_node
        -- return
)
/*
Tests that an exact 3-member vertical T stack is repaired without relying on accidental XY drift.
Only the generated terminal member may move; source topology and source positions must remain unchanged.
*/
function testWallThicknessExactVerticalStackInnerCorner =
(
        test_node = createWallThicknessExactVerticalStackTest()
        test_thickness = units.decodeValue "0.45m"
        test_tolerance = units.decodeValue "0.01mm"
        test_passed = false
        source_unchanged = true
        topology_unchanged = false
        target_matches = false
        target_changed = false
        target_z_preserved = false
        fix_data = #(false, 0, 0)
        if isValidNode test_node then
        (
                extrude_succeeded = applyWallThickness test_node test_thickness
                if extrude_succeeded then
                (
                        thickness_modifier = getWallThicknessModifier test_node
                        source_vert_count_value = getUserProp test_node wall_thickness_source_vert_count_prop
                        source_vert_count = if source_vert_count_value != undefined then source_vert_count_value as integer else 0
                        if thickness_modifier != undefined and source_vert_count == 8 then
                        (
                                target_generated_id = source_vert_count + 5
                                anchor_generated_id = source_vert_count + 4
                                before_vertex_count = thickness_modifier.GetNumVertices node:test_node
                                before_face_count = thickness_modifier.GetNumFaces node:test_node
                                before_source_positions = for source_id = 1 to source_vert_count collect (EditPolyMod.GetVertex thickness_modifier source_id node:test_node)
                                before_target_position = EditPolyMod.GetVertex thickness_modifier target_generated_id node:test_node
                                before_anchor_position = EditPolyMod.GetVertex thickness_modifier anchor_generated_id node:test_node
                                if before_target_position != undefined and before_anchor_position != undefined then
                                (
                                        expected_target_position = [before_anchor_position.x, before_anchor_position.y, before_target_position.z]
                                        fix_data = fixWallThicknessInnerCorners test_node
                                        fixed_modifier = getWallThicknessModifier test_node
                                        after_vertex_count = if fixed_modifier != undefined then fixed_modifier.GetNumVertices node:test_node else 0
                                        after_face_count = if fixed_modifier != undefined then fixed_modifier.GetNumFaces node:test_node else 0
                                        evaluated_mesh = snapshotAsMesh test_node
                                        inverse_object_tm = inverse test_node.objectTransform
                                        after_target_position = if evaluated_mesh != undefined then (getVert evaluated_mesh target_generated_id) * inverse_object_tm else undefined
                                        topology_unchanged = before_vertex_count == after_vertex_count and before_face_count == after_face_count
                                        target_matches = after_target_position != undefined and distance after_target_position expected_target_position <= test_tolerance
                                        target_changed = after_target_position != undefined and distance after_target_position before_target_position > test_tolerance
                                        target_z_preserved = after_target_position != undefined and after_target_position.z == before_target_position.z
                                        for source_id = 1 to source_vert_count while source_unchanged do
                                        (
                                                after_source_position = if evaluated_mesh != undefined then (getVert evaluated_mesh source_id) * inverse_object_tm else undefined
                                                if after_source_position == undefined or distance after_source_position before_source_positions[source_id] > test_tolerance then source_unchanged = false
                                        )
                                        if evaluated_mesh != undefined then free evaluated_mesh
                                )
                        )
                )
        )
        test_passed = fix_data[1] and fix_data[3] > 0 and topology_unchanged and source_unchanged and target_matches and target_changed and target_z_preserved
        format "Wall Thickness EXACT VERTICAL STACK TEST: % | moved:% | topology unchanged:% | source unchanged:% | target:% | changed:% | Z preserved:%\n" (if test_passed then "PASS" else "FAIL") fix_data[3] topology_unchanged source_unchanged target_matches target_changed target_z_preserved
        format "Undo order: FIX INNER CORNERS, EXTRUDE / UPDATE, Create Exact Vertical Stack Test.\n"
        test_passed
        -- return
)
/*
Tests the non-destructive FIX INNER CORNERS state across a later thickness update.
The Editable Poly source must stay untouched while WALL THICKNESS and the deformation-only FIX INNER CORNERS modifier are rebuilt with the corner still corrected.
*/
function testWallThicknessNonDestructiveInnerFixUpdate =
(
        test_node = createWallThicknessExactVerticalStackTest()
        first_thickness = units.decodeValue "0.45m"
        second_thickness = units.decodeValue "0.70m"
        test_tolerance = units.decodeValue "0.01mm"
        test_passed = false
        fix_data = #(false, 0, 0)
        update_succeeded = false
        two_modifier_ok = false
        source_base_unchanged = false
        persistent_fix_ok = false
        corrected_after_update = false
        if isValidNode test_node and classOf test_node.baseObject == Editable_Poly then
        (
                base_vertex_count = polyop.getNumVerts test_node.baseObject
                base_face_count = polyop.getNumFaces test_node.baseObject
                extrude_succeeded = applyWallThickness test_node first_thickness change_material_ids:false
                if extrude_succeeded then
                (
                        fix_data = fixWallThicknessInnerCorners test_node change_material_ids:false
                        first_modifier = getWallThicknessModifier test_node
                        if fix_data[1] and first_modifier != undefined then
                        (
                                wall_thickness_target = test_node
                                update_succeeded = updateDynamicWallThickness second_thickness change_material_ids:false
                                fixed_modifier = getWallThicknessModifier test_node
                                source_vert_count_value = getUserProp test_node wall_thickness_source_vert_count_prop
                                source_vert_count = if source_vert_count_value != undefined then source_vert_count_value as integer else 0
                                two_modifier_ok =
                                        fixed_modifier != undefined and
                                        test_node.modifiers.count == 2 and
                                        getWallThicknessInnerCornerFixModifier test_node != undefined and
                                        getWallThicknessInnerCornerWeldModifier test_node == undefined
                                source_base_unchanged =
                                        classOf test_node.baseObject == Editable_Poly and
                                        polyop.getNumVerts test_node.baseObject == base_vertex_count and
                                        polyop.getNumFaces test_node.baseObject == base_face_count
                                persistent_fix_ok =
                                        getObjectWallThicknessInnerFixEnabled test_node and
                                        abs (getObjectWallThickness test_node - second_thickness) <= test_tolerance
                                if fixed_modifier != undefined and source_vert_count == 8 then
                                (
                                        target_generated_id = source_vert_count + 5
                                        anchor_generated_id = source_vert_count + 4
                                        evaluated_mesh = snapshotAsMesh test_node
                                        if evaluated_mesh != undefined and target_generated_id <= meshop.getNumVerts evaluated_mesh and anchor_generated_id <= meshop.getNumVerts evaluated_mesh then
                                        (
                                                target_position = getVert evaluated_mesh target_generated_id
                                                anchor_position = getVert evaluated_mesh anchor_generated_id
                                                target_xy = [target_position.x, target_position.y, 0]
                                                anchor_xy = [anchor_position.x, anchor_position.y, 0]
                                                corrected_after_update = distance target_xy anchor_xy <= test_tolerance
                                        )
                                        if evaluated_mesh != undefined then free evaluated_mesh
                                )
                        )
                )
        )
        test_passed = fix_data[1] and fix_data[3] > 0 and update_succeeded and two_modifier_ok and source_base_unchanged and persistent_fix_ok and corrected_after_update
        format "Wall Thickness NON-DESTRUCTIVE INNER FIX UPDATE TEST: % | first moved:% | update:% | two modifiers:% | source base unchanged:% | persistent fix:% | corrected after update:%\n" (if test_passed then "PASS" else "FAIL") fix_data[3] update_succeeded two_modifier_ok source_base_unchanged persistent_fix_ok corrected_after_update
        format "Undo order: FIX INNER CORNERS, EXTRUDE / UPDATE, Create Exact Vertical Stack Test. Thickness update rebuild is intentionally undo-off like the production spinner.\n"
        test_passed
        -- return
)
/*
Tests FIX INNER CORNERS as a non-destructive deformation-only post modifier above WALL THICKNESS.
Vertex/face counts and every source vertex must remain unchanged while at least one bad generated neighbor moves.
*/
function testWallThicknessInnerCornerChainExpansion =
(
        test_node = createWallThicknessTest()
        test_thickness = units.decodeValue "0.60m"
        test_passed = false
        source_unchanged = true
        changed_vertex_count = 0
        before_vertex_count = 0
        after_vertex_count = 0
        before_face_count = 0
        after_face_count = 0
        fix_data = #(false, 0, 0)
        if isValidNode test_node then
        (
                extrude_succeeded = applyWallThickness test_node test_thickness
                if extrude_succeeded then
                (
                        before_mesh = snapshotAsMesh test_node
                        source_vert_count_value = getUserProp test_node wall_thickness_source_vert_count_prop
                        source_vert_count = if source_vert_count_value != undefined then source_vert_count_value as integer else 0
                        before_positions = #()
                        if before_mesh != undefined then
                        (
                                before_vertex_count = meshop.getNumVerts before_mesh
                                before_face_count = meshop.getNumFaces before_mesh
                                before_positions = for vertex_id = 1 to before_vertex_count collect (getVert before_mesh vertex_id)
                                free before_mesh
                        )
                        fix_data = fixWallThicknessInnerCorners test_node
                        after_mesh = snapshotAsMesh test_node
                        if after_mesh != undefined then
                        (
                                after_vertex_count = meshop.getNumVerts after_mesh
                                after_face_count = meshop.getNumFaces after_mesh
                                if after_vertex_count == before_positions.count then
                                (
                                        for vertex_id = 1 to after_vertex_count do
                                        (
                                                after_position = getVert after_mesh vertex_id
                                                if distance after_position before_positions[vertex_id] > units.decodeValue "0.01mm" then
                                                (
                                                        changed_vertex_count += 1
                                                        if vertex_id <= source_vert_count then source_unchanged = false
                                                )
                                        )
                                )
                                else
                                (
                                        source_unchanged = false
                                )
                                free after_mesh
                        )
                )
        )
        test_passed =
                fix_data[1] and
                fix_data[2] > 0 and
                fix_data[3] > 0 and
                before_vertex_count == after_vertex_count and
                before_face_count == after_face_count and
                source_unchanged and
                changed_vertex_count == fix_data[3]
        format "Wall Thickness INNER CORNER DEFORMATION-MODIFIER TEST: % | bad edges:% | moved:% | changed:% | verts:%/% | faces:%/% | source unchanged:%\n" (if test_passed then "PASS" else "FAIL") fix_data[2] fix_data[3] changed_vertex_count before_vertex_count after_vertex_count before_face_count after_face_count source_unchanged
        format "Undo order: FIX INNER CORNERS, EXTRUDE / UPDATE, Create Wall Thickness Angle Test.\n"
        test_passed
        -- return
)
/*
Tests inner-wall collapse repair separately from the existing outer-corner miter repair.
The inner case deliberately uses thickness larger than several source segments so generated inner-wall edges must collapse instead of reversing.
*/
function testWallThicknessFixChamfers =
(
        inner_thickness = units.decodeValue "3.0m"
        outer_thickness = units.decodeValue "0.20m"
        inner_node = createWallThicknessTest()
        inner_extrude_succeeded = applyWallThickness inner_node inner_thickness
        inner_data = if inner_extrude_succeeded then fixWallThicknessInnerCorners inner_node else #(false, 0, 0)
        inner_second_data = if inner_extrude_succeeded then fixWallThicknessInnerCorners inner_node else #(false, 0, 0)
        outer_node = createWallThicknessTest()
        outer_node.pos.x += units.decodeValue "14m"
        outer_extrude_succeeded = applyWallThickness outer_node outer_thickness
        outer_data = if outer_extrude_succeeded then fixWallThicknessOuterCorners outer_node else #(false, 0, 0)
        angle_90_ok = canFixWallThicknessChamferAngle [1,0,0] [0,1,0]
        angle_wide_ok = canFixWallThicknessChamferAngle [1,0,0] [0.5,0.8660254,0]
        angle_sharp_rejected = not (canFixWallThicknessChamferAngle [1,0,0] [-0.5,0.8660254,0])
        angle_gate_ok = angle_90_ok and angle_wide_ok and angle_sharp_rejected
        inner_two_modifier_ok = (countWallThicknessNamedModifiers inner_node wall_thickness_modifier_name) == 1 and (getWallThicknessInnerCornerFixModifier inner_node != undefined) and (getWallThicknessInnerCornerWeldModifier inner_node == undefined)
        inner_ok = inner_data[1] and (inner_data[2] > 0) and (inner_data[3] > 0) and inner_second_data[1] and inner_two_modifier_ok
        outer_ok = outer_data[1] and (outer_data[2] > 0) and (outer_data[3] > 0) and (getWallThicknessChamferFixModifier outer_node != undefined)
        test_passed = inner_extrude_succeeded and outer_extrude_succeeded and inner_ok and outer_ok and angle_gate_ok
        format "Wall Thickness INNER COLLAPSE / OUTER CORNER FIX TEST: % | inner bad edges:% moved:% two modifiers:% | outer edges:% moved:% | outer angle gate:%\n" (if test_passed then "PASS" else "FAIL") inner_data[2] inner_data[3] inner_two_modifier_ok outer_data[2] outer_data[3] angle_gate_ok
        test_passed
        -- return
)
/*
Tests that CLEANUP Quadrify uses the current Edit Poly without creating another modifier.
The test object remains in the scene for visual inspection.
*/
function testWallThicknessCurrentModifierCleanupPolicy =
(
        test_node = createWallThicknessTest()
        test_modifier = Edit_Poly()
        test_modifier.name = "TEST CURRENT EDIT POLY"
        test_modifier.showCage = off
        addModifier test_node test_modifier
        test_passed = false
        if isValidNode test_node then
        (
                before_modifier_count = test_node.modifiers.count
                select test_node
                max modify mode
                WallThicknessPreprocess.prepareEditPoly test_node test_modifier selection_level:#Object
                modPanel.setCurrentObject test_modifier node:test_node
                cleanup_succeeded = quadrifyCurrentWallThicknessModifier test_node
                after_modifier_count = test_node.modifiers.count
                current_modifier = modPanel.getCurrentObject()
                test_passed = cleanup_succeeded and before_modifier_count == after_modifier_count and current_modifier == test_modifier
        )
        format "Wall Thickness CURRENT MODIFIER CLEANUP TEST: %\n" (if test_passed then "PASS" else "FAIL")
        test_passed
        -- return
)
/*
Tests the no-new-modifier smoothing exception on a dedicated generic Edit Poly stage.
The basic angle-test creator itself remains modifier-free.
*/
function testWallThicknessSmoothingResetPolicy =
(
        test_node = createWallThicknessTest()
        test_modifier = Edit_Poly()
        test_modifier.name = "TEST SMOOTHING EDIT POLY"
        test_modifier.showCage = off
        addModifier test_node test_modifier
        test_passed = false
        if isValidNode test_node then
        (
                before_modifier_count = test_node.modifiers.count
                WallThicknessPreprocess.prepareEditPoly test_node test_modifier selection_level:#Object
                reset_succeeded = clearWallSmoothingGroupsOnEditPoly test_node test_modifier
                after_modifier_count = test_node.modifiers.count
                smoothing_groups_ok = true
                test_mesh = snapshotAsMesh test_node
                if test_mesh == undefined then
                (
                        smoothing_groups_ok = false
                )
                else
                (
                        mesh_face_count = getNumFaces test_mesh
                        for face_id = 1 to mesh_face_count while smoothing_groups_ok do
                        (
                                smoothing_groups_ok = getFaceSmoothGroup test_mesh face_id == 0
                        )
                        free test_mesh
                )
                test_passed = reset_succeeded and before_modifier_count == after_modifier_count and smoothing_groups_ok
        )
        format "Wall Thickness SMOOTHING RESET TEST: %\n" (if test_passed then "PASS" else "FAIL")
        test_passed
        -- return
)
/*
Tests that the shared ScriptReload helper resolves an existing Wall Thickness reload target.
This test resolves the path only and does not reload the script.
*/
function testWallThicknessLatestReloadPath =
(
        current_script = wall_thickness_source_file_path
        latest_script_path = ScriptReload.findNewestVersionedScript current_script "Wall-Thickness"
        test_passed = latest_script_path != undefined and latest_script_path != "" and doesFileExist latest_script_path
        format "Wall Thickness TITLE RESTART PATH TEST: % | %\n" (if test_passed then "PASS" else "FAIL") latest_script_path
        test_passed
        -- return
)
try
(
        if wallThicknessRollout.dialogBar then
        (
                cui.UnRegisterDialogBar wallThicknessRollout
        )
        destroyDialog wallThicknessRollout
)
catch
(
)
/*
Formats one function result for the compact UI log.
*/
/*
Tests the LMB SELECT / RMB remove-fix split for PREP 01 and PREP 03.
The two test objects remain in the scene so SELECT/DELETED modifier history can be inspected with undo.
*/
function testWallThicknessSelectRemoveWorkflow =
(
        generated_node = mesh name:(uniqueName "WallThickness_SelectRemove_Generated_") vertices:#([0,0,0],[100,0,0],[100,100,0],[0,100,0]) faces:#([1,2,3],[1,3,4])
        convertToPoly generated_node
        try (generated_node.baseObject.showCage = off) catch ()
        polyop.setFaceMatID generated_node #{1} 1
        polyop.setFaceMatID generated_node #{2} 2
        setUserProp generated_node wall_thickness_source_face_count_prop 1
        select generated_node
        generated_select_ok = preprocessWallThicknessStep generated_node 2
        generated_select_modifier = getWallThicknessNamedModifier generated_node wall_thickness_remove_generated_modifier_name
        generated_selected_count = if generated_select_modifier != undefined then (generated_select_modifier.GetSelection #Face node:generated_node).numberSet else 0
        generated_delete_ok = preprocessWallThicknessRemoveStep generated_node 2
        generated_deleted_modifier = getWallThicknessNamedModifier generated_node wall_thickness_deleted_generated_modifier_name
        generated_result_ok = generated_select_ok and generated_delete_ok and (generated_selected_count == 1) and (generated_deleted_modifier != undefined)
        degenerate_node = mesh name:(uniqueName "WallThickness_SelectRemove_Degenerate_") vertices:#([0,0,0],[100,0,0],[200,0,0],[0,100,0]) faces:#([1,2,3],[1,4,2])
        convertToPoly degenerate_node
        try (degenerate_node.baseObject.showCage = off) catch ()
        select degenerate_node
        degenerate_select_ok = preprocessWallThicknessStep degenerate_node 4
        degenerate_select_modifier = getWallThicknessNamedModifier degenerate_node wall_thickness_degenerate_modifier_name
        degenerate_selected_count = if degenerate_select_modifier != undefined then (degenerate_select_modifier.GetSelection #Face node:degenerate_node).numberSet else 0
        degenerate_fix_ok = preprocessWallThicknessRemoveStep degenerate_node 4
        degenerate_deleted_modifier = getWallThicknessNamedModifier degenerate_node wall_thickness_deleted_degenerate_modifier_name
        degenerate_result_ok = degenerate_select_ok and degenerate_fix_ok and (degenerate_selected_count > 0) and (degenerate_deleted_modifier != undefined)
        test_passed = generated_result_ok and degenerate_result_ok
        format "Wall Thickness SELECT/RMB TEST: % | generated selected:% | degenerate selected:%\n" (if test_passed then "PASS" else "FAIL") generated_selected_count degenerate_selected_count
        format "Undo order includes PREP 03 RMB/LMB and PREP 01 RMB/LMB for visual inspection.\n"
        test_passed
        -- return
)
/*
Checks that the production script and extracted inner-corner module loaded before regressions are run.
This structural stage does not modify scene geometry.
*/
function partOfTest1 =
(
        test_passed = (globalVars.isGlobal #applyWallThickness) and (globalVars.isGlobal #planWallThicknessInnerCorners)
        format "Wall Thickness TEST PART 1 - MODULE LOAD: %\n" (if test_passed then "PASS" else "FAIL")
        test_passed
        -- return
)
/*
Checks that representative extracted regression functions are available from this test file.
This structural stage does not modify scene geometry.
*/
function partOfTest2 =
(
        test_passed = (globalVars.isGlobal #testWallThicknessTEdgeSkewedVerticalCut) and (globalVars.isGlobal #testWallThicknessResult) and (globalVars.isGlobal #testWallThicknessSelectRemoveWorkflow)
        format "Wall Thickness TEST PART 2 - EXTRACTED TESTS: %\n" (if test_passed then "PASS" else "FAIL")
        test_passed
        -- return
)
/*
Tests the shared Pass 2 lookup/open-loop helpers without changing their public wrapper contracts.
The test leaves one inspection node in the scene and verifies class/property filtering plus generated-loop filtering.
*/
function partOfTest3 =
(
        test_passed = false
        undo "Wall Thickness Pass 2 Shared Helpers" on
        (
                test_node = box name:(uniqueName "WallThickness_Pass2_Shared_") length:100 width:100 height:100
                convertToPoly test_node
                try (test_node.baseObject.showCage = off) catch ()
                preview_mod = Edit_Poly()
                preview_mod.name = wall_thickness_modifier_name
                addModifier test_node preview_mod
                wrong_preview_mod = VertexWeld()
                wrong_preview_mod.name = wall_thickness_modifier_name
                wrong_preview_mod.threshold = 0.0
                addModifier test_node wrong_preview_mod
                inner_weld_mod = VertexWeld()
                inner_weld_mod.name = wall_thickness_inner_weld_modifier_name
                inner_weld_mod.threshold = 0.0
                addModifier test_node inner_weld_mod
                wrong_inner_weld_mod = Edit_Poly()
                wrong_inner_weld_mod.name = wall_thickness_inner_weld_modifier_name
                addModifier test_node wrong_inner_weld_mod
                named_lookup_ok = (getWallThicknessNamedModifier test_node wall_thickness_modifier_name) == wrong_preview_mod
                filtered_preview_ok = (getWallThicknessModifier test_node) == preview_mod
                filtered_weld_ok = (getWallThicknessInnerCornerWeldModifier test_node) == inner_weld_mod
                loop_mesh = mesh vertices:#([0,0,0],[100,0,0],[100,100,0],[0,100,0]) faces:#([1,2,3],[1,3,4])
                simple_loops = getWallThicknessSimpleOpenLoops loop_mesh
                generated_loops = getWallThicknessGeneratedOpenLoops loop_mesh 0
                source_filtered_loops = getWallThicknessGeneratedOpenLoops loop_mesh 4
                loop_filter_ok = simple_loops.count == 1 and generated_loops.count == 1 and source_filtered_loops.count == 0
                free loop_mesh
                shared_t_edge_ok =
                        (globalVars.isGlobal #buildWallThicknessTEdgeRecordsCore) and
                        (globalVars.isGlobal #getWallThicknessTEdgeSourceRegionsCore) and
                        (globalVars.isGlobal #detectWallThicknessTEdgeCasesCore)
                test_passed = named_lookup_ok and filtered_preview_ok and filtered_weld_ok and loop_filter_ok and shared_t_edge_ok
        )
        format "Wall Thickness TEST PART 3 - PASS 2 SHARED HELPERS: %\n" (if test_passed then "PASS" else "FAIL")
        test_passed
        -- return
)
/*
Checks that Wall Thickness resolves the shared UI helpers from the actual source layout.
This structural stage verifies both helper files and loaded globals without restarting the tool.
*/
function partOfTest4 =
(
        shared_ui_folder = getWallThicknessSharedUiFolder()
        helpers_exist = false
        if shared_ui_folder != undefined then
        (
                helpers_exist =
                        (doesFileExist (shared_ui_folder + "ScriptReload.ms")) and
                        (doesFileExist (shared_ui_folder + "ToolTitleButton.ms"))
        )
        framework_loaded =
                (globalVars.isGlobal #ScriptReload) and
                (globalVars.isGlobal #ToolTitleButton) and
                (globalVars.isGlobal #restartTool)
        test_passed = helpers_exist and framework_loaded
        format "Wall Thickness TEST PART 4 - SHARED UI PATH: % | %\n" (if test_passed then "PASS" else "FAIL") shared_ui_folder
        test_passed
        -- return
)
/*
Tests REMOVE MODIFIERS across two nodes while preserving unrelated stack modifiers.
The two nodes remain in the scene after the test so the surviving unrelated modifiers can be inspected.
*/
function partOfTest5 =
(
        undo "Wall Thickness Multi Remove Setup" on
        (
                test_node_a = box name:(uniqueName "WallThickness_MultiRemove_A_") length:100 width:100 height:100
                test_node_b = box name:(uniqueName "WallThickness_MultiRemove_B_") length:100 width:100 height:100
                test_node_b.pos = [150, 0, 0]
                convertToPoly test_node_a
                convertToPoly test_node_b
                try (test_node_a.baseObject.showCage = off) catch ()
                try (test_node_b.baseObject.showCage = off) catch ()
                for test_node in #(test_node_a, test_node_b) do
                (
                        thickness_modifier = Edit_Poly()
                        thickness_modifier.name = wall_thickness_modifier_name
                        thickness_modifier.showCage = off
                        addModifier test_node thickness_modifier
                        t_edge_modifier = Edit_Poly()
                        t_edge_modifier.name = wall_thickness_t_edge_fix_modifier_name
                        t_edge_modifier.showCage = off
                        addModifier test_node t_edge_modifier
                        unrelated_modifier = Edit_Poly()
                        unrelated_modifier.name = "USER MODIFIER - KEEP"
                        unrelated_modifier.showCage = off
                        addModifier test_node unrelated_modifier
                )
        )
        result_data = resetWallThicknessSelected #(test_node_a, test_node_b)
        node_a_ok =
                getWallThicknessModifier test_node_a == undefined and
                getWallThicknessTEdgeFixModifier test_node_a == undefined and
                getWallThicknessNamedModifier test_node_a "USER MODIFIER - KEEP" != undefined
        node_b_ok =
                getWallThicknessModifier test_node_b == undefined and
                getWallThicknessTEdgeFixModifier test_node_b == undefined and
                getWallThicknessNamedModifier test_node_b "USER MODIFIER - KEEP" != undefined
        test_passed = result_data[1] and result_data[2] == 2 and result_data[3] == 0 and node_a_ok and node_b_ok
        format "Wall Thickness TEST PART 5 - MULTI REMOVE MODIFIERS: % | reset:% | failed:%\n" (if test_passed then "PASS" else "FAIL") result_data[2] result_data[3]
        format "Undo order: Reset Wall Thickness Selected, Wall Thickness Multi Remove Setup.\n"
        test_passed
        -- return
)
/*
Tests selection of the canonical FIX T EDGE CORNERS modifier in the Modify panel.
The test object remains selected with the T-edge modifier current for visual inspection.
*/
function partOfTest6 =
(
        undo "Wall Thickness T Edge Modifier Selection Setup" on
        (
                test_node = box name:(uniqueName "WallThickness_TEdge_Select_") length:100 width:100 height:100
                convertToPoly test_node
                try (test_node.baseObject.showCage = off) catch ()
                t_edge_modifier = Edit_Poly()
                t_edge_modifier.name = wall_thickness_t_edge_fix_modifier_name
                t_edge_modifier.showCage = off
                addModifier test_node t_edge_modifier
        )
        selection_succeeded = selectWallThicknessTEdgeFixModifier test_node
        current_stack_object = undefined
        try (current_stack_object = modPanel.getCurrentObject()) catch ()
        test_passed =
                selection_succeeded and
                selection.count == 1 and
                selection[1] == test_node and
                current_stack_object == t_edge_modifier
        format "Wall Thickness TEST PART 6 - T EDGE MODIFIER SELECTED: %\n" (if test_passed then "PASS" else "FAIL")
        format "Undo order: Wall Thickness T Edge Modifier Selection Setup.\n"
        test_passed
        -- return
)

/*
Checks that catch rethrows use MAXScript's required bare throw() syntax.
This source-level guard prevents argument-bearing rethrows from reaching the compiler again.
*/
function partOfTest7 =
(
        production_stream = openFile wall_thickness_test_production_path mode:"rt"
        if production_stream == undefined then
        (
                format "Wall Thickness TEST PART 7 - CATCH RETHROW SYNTAX: FAIL | could not open production source.\n"
                false
        )
        else
        (
                production_text = ""
                while not eof production_stream do
                (
                        production_text += (readLine production_stream) + "\n"
                )
                close production_stream
                illegal_rethrow_found = findString production_text "throw exception_text" != undefined
                test_passed = not illegal_rethrow_found
                format "Wall Thickness TEST PART 7 - CATCH RETHROW SYNTAX: %\n" (if test_passed then "PASS" else "FAIL")
                test_passed
        )
        -- return
)
/*
Tests same-anchor mirrored T-Corner pairing and exact planned-anchor movement in Edit Poly.
The created box remains in the scene with the moved test vertex available for inspection.
*/
function partOfTest8 =
(
        synthetic_cases = #(
                #(4, 2, 5, 9, 0.25, [10,0,0], [10,0,-10], #t_corner_primary, 2),
                #(4, 9, 5, 2, 0.75, [20,0,0], [20,0,-10], #t_corner_mirror, 1),
                #(20, 21, 22, 23, 0.5, [30,0,0], [30,0,-10], #standard, 0)
        )
        case_pairs = getWallThicknessTCornerCasePairs synthetic_cases
        pair_ok =
                case_pairs.count == 1 and
                case_pairs[1][1] == 1 and
                case_pairs[1][2] == 2 and
                synthetic_cases[1][8] == #t_corner_primary and
                synthetic_cases[2][8] == #t_corner_mirror
        undo "Wall Thickness T-Corner Anchor Move Setup" on
        (
                test_node = box name:(uniqueName "WallThickness_TCorner_Anchor_") length:100 width:100 height:100
                convertToPoly test_node
                try (test_node.showCage = off) catch ()
                try (test_node.baseObject.showCage = off) catch ()
                edit_modifier = Edit_Poly()
                edit_modifier.name = "TEST T-CORNER ANCHOR MOVE"
                edit_modifier.showCage = off
                addModifier test_node edit_modifier
                select test_node
                max modify mode
                edit_modifier.SetPrimaryNode test_node
                modPanel.setCurrentObject edit_modifier node:test_node
        )
        start_position = edit_modifier.GetVertex 1 node:test_node
        target_position = start_position + [units.decodeValue "37mm", units.decodeValue "19mm", 0]
        tolerance = units.decodeValue "0.01mm"
        undo "Wall Thickness T-Corner Anchor Move" on
        (
                move_ok = moveWallThicknessTEdgeVertexToPosition edit_modifier test_node 1 target_position tolerance
        )
        moved_position = edit_modifier.GetVertex 1 node:test_node
        anchor_ok = move_ok and moved_position != undefined and distance moved_position target_position <= tolerance
        test_passed = pair_ok and anchor_ok
        format "Wall Thickness TEST PART 8 - T-CORNER PAIR/ANCHOR: % | pair:% | start:% | target:% | moved:%\n" (if test_passed then "PASS" else "FAIL") pair_ok start_position target_position moved_position
        format "Undo order: Wall Thickness T-Corner Anchor Move, Wall Thickness T-Corner Anchor Move Setup.\n"
        test_passed
        -- return
)
/*
Tests T-edge live target reconstruction and MoveSelection transform handling on a transformed node.
The expected anchor is derived only from live Edit Poly endpoints plus the stored fraction.
*/
function partOfTest9 =
(
        undo "Wall Thickness T Edge Live Coordinate Setup" on
        (
                test_node = box name:(uniqueName "WallThickness_TEdge_LiveCoord_") length:100 width:100 height:100
                convertToPoly test_node
                try (test_node.showCage = off) catch ()
                try (test_node.baseObject.showCage = off) catch ()
                test_node.rotation = quat 0 0 0.382683 0.92388
                test_node.position = [units.decodeValue "137mm", units.decodeValue "-83mm", units.decodeValue "19mm"]
                edit_modifier = Edit_Poly()
                edit_modifier.name = "TEST T-EDGE LIVE COORDINATE"
                edit_modifier.showCage = off
                addModifier test_node edit_modifier
                select test_node
                max modify mode
                edit_modifier.SetPrimaryNode test_node
                modPanel.setCurrentObject edit_modifier node:test_node
        )
        anchor_start = edit_modifier.GetVertex 1 node:test_node
        branch_end = edit_modifier.GetVertex 2 node:test_node
        fraction_from_anchor = 0.37
        live_target = anchor_start + ((branch_end - anchor_start) * fraction_from_anchor)
        tolerance = units.decodeValue "0.01mm"
        undo "Wall Thickness T Edge Live Coordinate Move" on
        (
                move_ok = moveWallThicknessTEdgeVertexToPosition edit_modifier test_node 1 live_target tolerance
        )
        moved_position = edit_modifier.GetVertex 1 node:test_node
        test_passed = move_ok and moved_position != undefined and distance moved_position live_target <= tolerance
        format "Wall Thickness TEST PART 9 - T EDGE LIVE COORDINATE MOVE: % | target:% | moved:%\n" (if test_passed then "PASS" else "FAIL") live_target moved_position
        format "Undo order: Wall Thickness T Edge Live Coordinate Move, Wall Thickness T Edge Live Coordinate Setup.\n"
        test_passed
        -- return
)

/*
Checks that every EXTRUDE and FIX UI action snapshots the current selection and loops object by object.
This source-level regression protects the multi-object wrapper without changing the existing single-object geometry functions.
*/
function partOfTest10 =
(
        production_stream = openFile wall_thickness_test_production_path mode:"rt"
        if production_stream == undefined then
        (
                format "Wall Thickness TEST PART 10 - MULTI-OBJECT EXTRUDE/FIX WRAPPERS: FAIL | could not open production source.\n"
                false
        )
        else
        (
                production_text = ""
                while not eof production_stream do
                (
                        production_text += (readLine production_stream) + "\n"
                )
                close production_stream
                create_ok =
                        findString production_text "on btn_create pressed do" != undefined and
                        findString production_text "applyWallThickness source_node batch_thickness change_material_ids:batch_change_material_ids auto_fix_inner:true" != undefined
                extrude_only_ok =
                        findString production_text "on btn_extrude_only pressed do" != undefined and
                        findString production_text "applyWallThickness source_node batch_thickness change_material_ids:batch_change_material_ids auto_fix_inner:false" != undefined
                inner_ok =
                        findString production_text "on btn_fix_inner pressed do" != undefined and
                        findString production_text "fixWallThicknessInnerCorners source_node change_material_ids:batch_change_material_ids" != undefined
                t_edge_ok =
                        findString production_text "on btn_fix_t_edge pressed do" != undefined and
                        findString production_text "fixWallThicknessTEdgeCorners source_node" != undefined
                outer_ok =
                        findString production_text "on btn_fix_outer pressed do" != undefined and
                        findString production_text "fixWallThicknessOuterCorners source_node" != undefined
                selection_snapshot_ok =
                        findString production_text "selected_nodes = selection as array" != undefined and
                        findString production_text "for source_node in selected_nodes do" != undefined
                test_passed = create_ok and extrude_only_ok and inner_ok and t_edge_ok and outer_ok and selection_snapshot_ok
                format "Wall Thickness TEST PART 10 - MULTI-OBJECT EXTRUDE/FIX WRAPPERS: % | update:% | raw:% | inner:% | t-edge:% | outer:% | snapshot:%\n" (if test_passed then "PASS" else "FAIL") create_ok extrude_only_ok inner_ok t_edge_ok outer_ok selection_snapshot_ok
                test_passed
        )
        -- return
)
partOfTest1()
partOfTest2()
partOfTest3()
partOfTest4()
partOfTest5()
partOfTest6()
partOfTest7()
partOfTest8()
partOfTest9()
partOfTest10()
