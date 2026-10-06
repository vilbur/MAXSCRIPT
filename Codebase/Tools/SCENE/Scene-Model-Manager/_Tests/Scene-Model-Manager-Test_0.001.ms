/*
Scene Model Manager 0.001 focused MODEL NODE test.
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
UNDO: removes the MODEL NODE.
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
Stores an exact +X ORTHO direction and validates MODEL NODE membership.
UNDO: restores the MODEL NODE transform and user properties.
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
        undo "SMM TEST 3 - Set Ortho" on
        (
            direction_point = model_node.pos + [1000.0,0.0,0.0]
            result_value = SceneModelManager.setModelNodeOrthoFromDirection model_node direction_point
            member_count = SceneModelManager.getModelNodeMembers(model_node).count

            format "SMM TEST Ortho result: %\n" result_value
            format "SMM TEST Member count: %\n" member_count
            format "SMM TEST Model text: %\n" model_node.text

            if (result_value[1] and member_count == 2) then
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
format "1. SMM TEST 3 - Set Ortho\n"
format "2. SMM TEST 2 - Create Model Node\n"
format "3. SMM TEST 1 - Create Geometry\n\n"
