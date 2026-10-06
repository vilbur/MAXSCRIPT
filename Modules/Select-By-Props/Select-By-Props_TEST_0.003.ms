/*
    Select-By-Props 0.003 test.
    Tests camera-facing polygon selection, the tight normal/view threshold, and Restart version resolution.
*/

global sbp_test_file_version = "0.003"
global sbp_test_project_version = "0.003"
global sbp_test_source_path = getSourceFileName()
global sbp_test_directory = getFilenamePath sbp_test_source_path
global sbp_test_tool_path = sbp_test_directory + "Select-By-Props_0.003.ms"
global sbp_test_editable_poly
global sbp_test_edit_poly_node
global sbp_test_edit_poly_mod
global sbp_test_camera
global sbp_test_target
global sbp_test_result_1 = false
global sbp_test_result_2 = false
global sbp_test_result_3 = false
global sbp_test_result_4 = false
global sbp_test_result_5 = false

/*
Loads the production script and creates one Editable Poly box, one Edit Poly box, and a target camera.
The camera looks toward the boxes from negative Y so exactly one box side should face it.
*/
function partOfTest1 =
(
    local setup_ok = false

    fileIn sbp_test_tool_path

    undo "SBP Test 1 - Create Camera Face Test" on
    (
        sbp_test_editable_poly = box name:"SBP_Test_EditablePoly" length:100 width:100 height:100 pos:[-70,0,0]
        convertToPoly sbp_test_editable_poly
        sbp_test_editable_poly.baseObject.showCage = off

        sbp_test_edit_poly_node = box name:"SBP_Test_EditPoly" length:100 width:100 height:100 pos:[70,0,0]
        sbp_test_edit_poly_mod = Edit_Poly()
        sbp_test_edit_poly_mod.name = "SBP TEST EDIT POLY"
        sbp_test_edit_poly_mod.showCage = off
        addModifier sbp_test_edit_poly_node sbp_test_edit_poly_mod

        sbp_test_target = targetObject name:"SBP_Test_Camera_Target" pos:[0,0,0]
        sbp_test_camera = targetCamera name:"SBP_Test_Camera" pos:[0,-300,0] target:sbp_test_target
        viewport.setCamera sbp_test_camera

        select sbp_test_editable_poly
        setup_ok = isValidNode sbp_test_editable_poly and isValidNode sbp_test_edit_poly_node and isValidNode sbp_test_camera
    )

    format "TEST 1 setup: %\n" setup_ok

    -- return
    setup_ok
)

/*
Runs camera-facing selection on the Editable Poly test box.
Exactly one polygon face is expected to point toward the test camera.
*/
function partOfTest2 =
(
    local test_ok = false
    local selected_faces = #{}

    if isValidNode sbp_test_editable_poly then
    (
        undo "SBP Test 2 - Editable Poly Camera Faces" on
        (
            select sbp_test_editable_poly
            ascSelectFaces #cameraFacing
            selected_faces = polyop.getFaceSelection sbp_test_editable_poly
            test_ok = selected_faces.numberSet == 1
        )
    )

    format "TEST 2 Editable Poly camera faces: % selection:%\n" test_ok selected_faces

    -- return
    test_ok
)

/*
Runs camera-facing selection on the primitive carrying an Edit Poly modifier.
Exactly one polygon face is expected in the modifier's face selection.
*/
function partOfTest3 =
(
    local test_ok = false
    local selected_faces = #{}

    if isValidNode sbp_test_edit_poly_node then
    (
        undo "SBP Test 3 - Edit Poly Camera Faces" on
        (
            select sbp_test_edit_poly_node
            ascSelectFaces #cameraFacing
            selected_faces = sbp_test_edit_poly_mod.GetSelection #Face node:sbp_test_edit_poly_node
            test_ok = selected_faces.numberSet == 1
        )
    )

    format "TEST 3 Edit Poly camera faces: % selection:%\n" test_ok selected_faces

    -- return
    test_ok
)

/*
Checks the tightened camera-facing normal threshold directly.
A strongly aligned normal must pass while a broader front-facing normal must fail.
*/
function partOfTest4 =
(
    local identity_tm = matrix3 [1,0,0] [0,1,0] [0,0,1] [0,0,0]
    local tight_normal = normalize [0.0,1.0,4.0]
    local broad_normal = normalize [0.0,1.0,3.0]
    local tight_match = ascFaceNormalMatchesView tight_normal identity_tm
    local broad_match = ascFaceNormalMatchesView broad_normal identity_tm
    local test_ok = tight_match and (not broad_match)

    format "TEST 4 camera threshold: % tight:% broad:% threshold:%\n" test_ok tight_match broad_match asc_camera_face_alignment_threshold

    -- return
    test_ok
)

/*
Checks that Restart resolves the production script and ignores the TEST filename.
No reload is executed so the final test scene remains available for inspection.
*/
function partOfTest5 =
(
    local resolved_path = ascFindNewestVersionFile sbp_test_tool_path
    local test_ok = resolved_path == sbp_test_tool_path

    format "TEST 5 Restart resolver: % path:%\n" test_ok resolved_path

    -- return
    test_ok
)

sbp_test_result_1 = partOfTest1()
sbp_test_result_2 = partOfTest2()
sbp_test_result_3 = partOfTest3()
sbp_test_result_4 = partOfTest4()
sbp_test_result_5 = partOfTest5()

format "\nSelect-By-Props 0.003 test results: setup:% editablePoly:% editPoly:% cameraThreshold:% restartResolver:%\n" sbp_test_result_1 sbp_test_result_2 sbp_test_result_3 sbp_test_result_4 sbp_test_result_5
format "Undo order from newest to oldest:\n"
format "1. SBP Test 3 - Edit Poly Camera Faces\n"
format "2. SBP Test 2 - Editable Poly Camera Faces\n"
format "3. SBP Test 1 - Create Camera Face Test\n"
format "The test scene is intentionally left in place for visual inspection.\n"
