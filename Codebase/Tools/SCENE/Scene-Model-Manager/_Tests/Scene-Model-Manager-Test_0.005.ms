/*
Scene Model Manager 0.005 focused MODEL NODE pivot / node-only ORTHO test.
Run Scene-Model-Manager-FN.ms before this file.
*/

/*
Creates simple geometry in a clean inspection area.
UNDO: removes the created test geometry.
*/
function partOfTest1 =
(
    undo "SMM TEST 1 - Create Geometry" on
    (
        test_box_a = Box name:"SMM_TEST_A" length:400.0 width:600.0 height:300.0 pos:[0,0,150]
        test_box_b = Box name:"SMM_TEST_B" length:300.0 width:300.0 height:450.0 pos:[700,0,225]
        test_box_external = Box name:"SMM_TEST_EXTERNAL" length:250.0 width:250.0 height:250.0 pos:[1400,500,125]
        setUserPropVal rootNode "SMM_TEST_EXTERNAL_HANDLE" test_box_external.inode.handle
        select #(test_box_a, test_box_b)
    )

    true
    -- return
)

/*
Creates a visible MODEL NODE from the two selected test boxes.
UNDO: removes the MODEL NODE and restores the original hierarchy.
*/
function partOfTest2 =
(
    undo "SMM TEST 2 - Create Model Node" on
    (
        member_nodes = selection as array
        pivot_point = SceneModelManager.getNodesBoundsCenter member_nodes
        model_node = SceneModelManager.createModelNode "TEST BLOCK" member_nodes pivot_point 150 (units.decodeValue "100cm")
        setUserPropVal rootNode "SMM_TEST_MODEL_HANDLE" model_node.inode.handle
    )

    true
    -- return
)

/*
Moves the MODEL NODE pivot exactly to vector START and validates ORTHO definition behavior.
With ROTATION OFF the node orientation stays unchanged.
With ROTATION ON the node rotates to the nearest world X/Y axis while member world transforms stay unchanged.
UNDO: restores the MODEL NODE transform, helper state, and stored ORTHO metadata.
*/
function partOfTest3 =
(
    model_handle = getUserPropVal rootNode "SMM_TEST_MODEL_HANDLE"
    model_node = maxOps.getNodeByHandle model_handle

    if model_node == undefined then
    (
        format "SMM TEST FAIL: MODEL NODE not found.\n"
        false
    )
    else
    (
        undo "SMM TEST 3 - Pivot And Ortho State" on
        (
            member_nodes = SceneModelManager.getModelNodeMembers model_node
            original_member_transforms = #()

            for member_node in member_nodes do
            (
                append original_member_transforms member_node.transform
            )

            original_rotation = model_node.rotation
            vector_start = [100.0,200.0,0.0]
            vector_end = vector_start + [1000.0,400.0,0.0]
            picked_vector = vector_end - vector_start

            move_result = SceneModelManager.moveModelNodePivot model_node vector_start
            direction_point = model_node.pos + picked_vector
            ortho_off_result = SceneModelManager.setModelNodeOrthoFromDirection model_node direction_point
            pivot_matches = model_node.pos == vector_start
            rotation_unchanged_when_off = model_node.rotation == original_rotation

            helper_node = SceneModelManager.createOffsetHelper()
            setUserPropVal helper_node "SO_MAIN_ROTATION_ACTIVE" true

            ortho_on_result = SceneModelManager.setModelNodeOrthoFromDirection model_node direction_point
            source_angle = getUserPropVal model_node "SMM_SOURCE_ANGLE_Z"
            rotation_delta = getUserPropVal model_node "SMM_ORTHO_DELTA_Z"
            snapped_angle = source_angle + rotation_delta
            rotation_snapped_when_on = model_node.rotation == (quat snapped_angle [0,0,1])
            setUserPropVal helper_node "SO_MAIN_ROTATION_ACTIVE" false
            members_preserved = true

            for member_index = 1 to member_nodes.count do
            (
                if member_nodes[member_index].transform != original_member_transforms[member_index] then
                (
                    members_preserved = false
                )
            )

            format "SMM TEST Move result: %\n" move_result
            format "SMM TEST ORTHO OFF result: %\n" ortho_off_result
            format "SMM TEST ORTHO ON result: %\n" ortho_on_result
            format "SMM TEST Pivot exact: %\n" pivot_matches
            format "SMM TEST Rotation unchanged while OFF: %\n" rotation_unchanged_when_off
            format "SMM TEST Rotation snapped while ON: %\n" rotation_snapped_when_on
            format "SMM TEST Members preserved: %\n" members_preserved

            if (move_result[1] and ortho_off_result[1] and ortho_on_result[1] and pivot_matches and rotation_unchanged_when_off and rotation_snapped_when_on and members_preserved) then
            (
                format "SMM TEST PASS\n"
            )
            else
            (
                format "SMM TEST FAIL\n"
            )
        )

        true
    )
    -- return
)

/*
Activates ORTHO on the MODEL NODE Text only.
Linked members and an unrelated external scene root must keep exact world transforms and hierarchy.
ORIGINAL must restore the MODEL NODE rotation exactly without touching the rest of the scene.
*/
function partOfTest4 =
(
    model_handle = getUserPropVal rootNode "SMM_TEST_MODEL_HANDLE"
    external_handle = getUserPropVal rootNode "SMM_TEST_EXTERNAL_HANDLE"
    model_node = maxOps.getNodeByHandle model_handle
    external_node = maxOps.getNodeByHandle external_handle

    if (model_node == undefined or external_node == undefined) then
    (
        format "SMM TEST FAIL: MODEL NODE or external root not found.\n"
        false
    )
    else
    (
        undo "SMM TEST 4 - Node Only Ortho" on
        (
            member_nodes = SceneModelManager.getModelNodeMembers model_node
            original_member_transforms = #()

            for member_node in member_nodes do
            (
                append original_member_transforms member_node.transform
            )

            original_external_transform = external_node.transform
            original_external_parent = external_node.parent
            original_model_rotation = model_node.rotation

            activate_result = SceneModelManager.activateModelNodeOrtho model_node
            active_on_node = SceneModelManager.isModelNodeOrthoActive model_node
            model_rotation_changed = model_node.rotation != original_model_rotation
            external_unchanged_in_ortho = (external_node.parent == original_external_parent and external_node.transform == original_external_transform)
            members_unchanged_in_ortho = true

            for member_index = 1 to member_nodes.count do
            (
                if member_nodes[member_index].transform != original_member_transforms[member_index] then
                (
                    members_unchanged_in_ortho = false
                )
            )

            restore_result = SceneModelManager.restoreOrthoView model_node:model_node
            active_cleared = not SceneModelManager.isModelNodeOrthoActive model_node
            model_rotation_restored = model_node.rotation == original_model_rotation
            external_unchanged_after_restore = (external_node.parent == original_external_parent and external_node.transform == original_external_transform)
            members_unchanged_after_restore = true

            for member_index = 1 to member_nodes.count do
            (
                if member_nodes[member_index].transform != original_member_transforms[member_index] then
                (
                    members_unchanged_after_restore = false
                )
            )

            format "SMM TEST Activate result: %\n" activate_result
            format "SMM TEST Selected node owns ORTHO state: %\n" active_on_node
            format "SMM TEST MODEL NODE rotation changed: %\n" model_rotation_changed
            format "SMM TEST External root unchanged in ORTHO: %\n" external_unchanged_in_ortho
            format "SMM TEST Members unchanged in ORTHO: %\n" members_unchanged_in_ortho
            format "SMM TEST Restore result: %\n" restore_result
            format "SMM TEST Active state cleared: %\n" active_cleared
            format "SMM TEST MODEL NODE rotation restored: %\n" model_rotation_restored
            format "SMM TEST External root unchanged after restore: %\n" external_unchanged_after_restore
            format "SMM TEST Members unchanged after restore: %\n" members_unchanged_after_restore

            if (activate_result[1] and active_on_node and model_rotation_changed and external_unchanged_in_ortho and members_unchanged_in_ortho and restore_result[1] and active_cleared and model_rotation_restored and external_unchanged_after_restore and members_unchanged_after_restore) then
            (
                format "SMM TEST PASS\n"
            )
            else
            (
                format "SMM TEST FAIL\n"
            )
        )

        true
    )
    -- return
)

partOfTest1()
partOfTest2()
partOfTest3()
partOfTest4()

format "\nUNDO ORDER:\n"
format "1. SMM TEST 4 - Node Only Ortho\n"
format "2. SMM TEST 3 - Pivot And Ortho State\n"
format "3. SMM TEST 2 - Create Model Node\n"
format "4. SMM TEST 1 - Create Geometry\n\n"
