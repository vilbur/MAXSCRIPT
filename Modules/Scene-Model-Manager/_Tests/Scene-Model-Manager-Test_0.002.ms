/*
Scene Model Manager 0.002 focused MODEL NODE pivot / ORTHO test.
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
Moves the MODEL NODE pivot exactly, then stores an ORTHO direction.
Both operations must preserve linked member world transforms.
UNDO: restores the MODEL NODE transform and stored ORTHO metadata.
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
        undo "SMM TEST 3 - Move Pivot And Set Ortho" on
        (
            member_nodes = SceneModelManager.getModelNodeMembers model_node
            original_member_transforms = #()

            for member_node in member_nodes do
            (
                append original_member_transforms member_node.transform
            )

            target_pivot = [100.0,200.0,0.0]
            move_result = SceneModelManager.moveModelNodePivot model_node target_pivot
            move_members_preserved = true

            for member_index = 1 to member_nodes.count do
            (
                if member_nodes[member_index].transform != original_member_transforms[member_index] then
                (
                    move_members_preserved = false
                )
            )

            direction_point = model_node.pos + [1000.0,0.0,0.0]
            ortho_result = SceneModelManager.setModelNodeOrthoFromDirection model_node direction_point
            ortho_members_preserved = true

            for member_index = 1 to member_nodes.count do
            (
                if member_nodes[member_index].transform != original_member_transforms[member_index] then
                (
                    ortho_members_preserved = false
                )
            )

            pivot_matches = model_node.pos == target_pivot
            member_count = member_nodes.count

            format "SMM TEST Move result: %\n" move_result
            format "SMM TEST Ortho result: %\n" ortho_result
            format "SMM TEST Pivot exact: %\n" pivot_matches
            format "SMM TEST Members after pivot move preserved: %\n" move_members_preserved
            format "SMM TEST Members after direction set preserved: %\n" ortho_members_preserved
            format "SMM TEST Member count: %\n" member_count

            if (move_result[1] and ortho_result[1] and pivot_matches and move_members_preserved and ortho_members_preserved and member_count == 2) then
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
format "1. SMM TEST 3 - Move Pivot And Set Ortho\n"
format "2. SMM TEST 2 - Create Model Node\n"
format "3. SMM TEST 1 - Create Geometry\n\n"
