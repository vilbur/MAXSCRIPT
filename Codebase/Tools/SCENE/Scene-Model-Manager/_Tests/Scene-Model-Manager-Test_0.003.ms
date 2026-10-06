/*
Scene Model Manager 0.003 focused MODEL NODE pivot / ORTHO test.
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

partOfTest1()
partOfTest2()
partOfTest3()

format "\nUNDO ORDER:\n"
format "1. SMM TEST 3 - Pivot And Ortho State\n"
format "2. SMM TEST 2 - Create Model Node\n"
format "3. SMM TEST 1 - Create Geometry\n\n"
