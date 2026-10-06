/*
Scene Model Manager 0.007 focused live MODEL NODE Ratio / Size backend contract test.
Run Scene-Model-Manager-FN.ms before this file.

Goal:
- The existing MODEL NODE update operation changes Ratio and Text size exactly.
- MODEL name and MODEL MEMBERS remain unchanged.
- Member hierarchy remains linked to the MODEL NODE.
*/

/*
Builds one simple MODEL NODE, applies the values used by the live UI spinners, and verifies preservation.
UNDO: removes the complete test scene created by this function.
*/
function runModelNodeLiveSettingsTest =
(
    test_ok = false

    undo "SMM TEST 0.007 - LIVE NODE SETTINGS" on
    (
        target_layer_name = "SMM_LIVE_SETTINGS_TEST"
        target_layer = LayerManager.getLayerFromName target_layer_name
        if target_layer == undefined then target_layer = LayerManager.newLayerFromName target_layer_name

        member_root = Box name:"SMM_LIVE_SETTINGS_ROOT" length:100.0 width:100.0 height:100.0 pos:[0,0,50]
        target_layer.addNode member_root

        initial_size = units.decodeValue "100cm"
        target_size = units.decodeValue "125cm"
        model_node = SceneModelManager.createModelNode target_layer_name #(member_root) undefined 150 initial_size

        if model_node == undefined then
        (
            format "SMM TEST 0.007 FAIL: MODEL NODE creation failed.\n"
            test_ok = false
        )
        else
        (
            original_name = getUserPropVal model_node "SMM_MODEL_NAME"
            original_members = SceneModelManager.getModelNodeMembers model_node

            update_ok = SceneModelManager.updateModelNodeSettings model_node original_name 275 target_size

            updated_name = getUserPropVal model_node "SMM_MODEL_NAME"
            updated_ratio = getUserPropVal model_node "SMM_RATIO"
            updated_members = SceneModelManager.getModelNodeMembers model_node

            ratio_ok = updated_ratio == 275
            size_ok = model_node.size == target_size
            name_ok = updated_name == original_name
            member_count_ok = updated_members.count == original_members.count
            member_root_ok = updated_members.count == 1 and updated_members[1] == member_root
            hierarchy_ok = member_root.parent == model_node

            format "SMM TEST 0.007 update result: %\n" update_ok
            format "SMM TEST 0.007 ratio exact: %\n" ratio_ok
            format "SMM TEST 0.007 size exact: %\n" size_ok
            format "SMM TEST 0.007 name preserved: %\n" name_ok
            format "SMM TEST 0.007 member count preserved: %\n" member_count_ok
            format "SMM TEST 0.007 member root preserved: %\n" member_root_ok
            format "SMM TEST 0.007 hierarchy preserved: %\n" hierarchy_ok

            test_ok = (
                update_ok and
                ratio_ok and
                size_ok and
                name_ok and
                member_count_ok and
                member_root_ok and
                hierarchy_ok
            )

            if test_ok then
            (
                format "SMM TEST 0.007 PASS\n"
            )
            else
            (
                format "SMM TEST 0.007 FAIL\n"
            )
        )
    )

    test_ok
    -- return
)

runModelNodeLiveSettingsTest()
