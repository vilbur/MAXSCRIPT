/*
Scene Model Manager 0.010 focused empty MODEL NODE creation test.
Run Scene-Model-Manager-FN.ms before this file.

Goal:
- CREATE MODEL NODE works with no source members.
- Empty node is created at world origin.
- MODEL name, scene node name, and visible Text are identical.
- MODEL MEMBERS stays empty.
*/

/*
Creates one empty MODEL NODE and validates its initial state.
UNDO: removes the created MODEL NODE.
*/
function runEmptyModelNodeCreationTest =
(
    test_ok = false

    undo "SMM TEST 0.010 - EMPTY MODEL NODE" on
    (
        model_name = "SMM_EMPTY_MODEL_TEST"
        text_size = units.decodeValue "100cm"
        model_node = SceneModelManager.createModelNode model_name #() undefined 150 text_size

        if model_node == undefined then
        (
            format "SMM TEST 0.010 FAIL: empty MODEL NODE creation returned undefined.\n"
            test_ok = false
        )
        else
        (
            member_nodes = SceneModelManager.getModelNodeMembers model_node
            stored_name = getUserPropVal model_node "SMM_MODEL_NAME"

            position_ok = model_node.pos == [0.0,0.0,0.0]
            members_ok = member_nodes.count == 0
            stored_name_ok = stored_name == model_name
            scene_name_ok = model_node.name == model_name
            text_ok = model_node.text == model_name
            ratio_ok = (getUserPropVal model_node "SMM_RATIO") == 150

            format "SMM TEST 0.010 position origin: %\n" position_ok
            format "SMM TEST 0.010 zero members: %\n" members_ok
            format "SMM TEST 0.010 stored name exact: %\n" stored_name_ok
            format "SMM TEST 0.010 scene name exact: %\n" scene_name_ok
            format "SMM TEST 0.010 text exact: %\n" text_ok
            format "SMM TEST 0.010 ratio stored: %\n" ratio_ok

            test_ok = (
                position_ok and
                members_ok and
                stored_name_ok and
                scene_name_ok and
                text_ok and
                ratio_ok
            )

            if test_ok then
            (
                format "SMM TEST 0.010 PASS\n"
            )
            else
            (
                format "SMM TEST 0.010 FAIL\n"
            )
        )
    )

    test_ok
    -- return
)

runEmptyModelNodeCreationTest()
