/*
Scene Model Manager 0.008 focused BIND MATCHING LAYER authoritative layer synchronization test.
Run Scene-Model-Manager-FN.ms before this file.

Goal:
- BIND MATCHING LAYER state is stored as MODEL NODE user property SMM_BIND_MATCHING_LAYER.
- Exact same-named layer is authoritative for top-root MODEL MEMBERS.
- New layer roots are linked and stale roots moved out of the layer are unlinked.
- World transforms and child/outside hierarchies remain untouched.
*/

/*
Builds one authoritative-layer synchronization scene and validates add/remove hierarchy behavior.
UNDO: removes the complete test scene created by this function.
*/
function runModelMembersBindMatchingLayerTest =
(
    test_ok = false

    undo "SMM TEST 0.008 - BIND MATCHING LAYER MODEL MEMBERS" on
    (
        target_layer_name = "SMM_BIND_LAYER_TEST"
        outside_layer_name = "SMM_BIND_LAYER_OUTSIDE"

        target_layer = LayerManager.getLayerFromName target_layer_name
        if target_layer == undefined then target_layer = LayerManager.newLayerFromName target_layer_name

        outside_layer = LayerManager.getLayerFromName outside_layer_name
        if outside_layer == undefined then outside_layer = LayerManager.newLayerFromName outside_layer_name

        keep_root = Box name:"SMM_BIND_KEEP_ROOT" length:120.0 width:120.0 height:120.0 pos:[0,0,60]
        keep_child = Box name:"SMM_BIND_KEEP_CHILD" length:60.0 width:60.0 height:60.0 pos:[180,0,30]
        stale_root = Box name:"SMM_BIND_STALE_ROOT" length:100.0 width:100.0 height:100.0 pos:[360,0,50]

        target_layer.addNode keep_root
        target_layer.addNode keep_child
        target_layer.addNode stale_root

        keep_child_tm = keep_child.transform
        keep_child.parent = keep_root
        keep_child.transform = keep_child_tm

        model_node = SceneModelManager.createModelNode target_layer_name #(keep_root, keep_child, stale_root) undefined 150 (units.decodeValue "100cm")

        if model_node == undefined then
        (
            format "SMM TEST 0.008 FAIL: MODEL NODE creation failed.\n"
            test_ok = false
        )
        else
        (
            initial_property_ok = (getUserPropVal model_node "SMM_BIND_MATCHING_LAYER") == false
            mode_ok = SceneModelManager.setModelNodeBindMatchingLayer model_node true

            new_root = Box name:"SMM_BIND_NEW_ROOT" length:110.0 width:110.0 height:110.0 pos:[0,300,55]
            target_layer.addNode new_root

            outside_root = Box name:"SMM_BIND_OUTSIDE_ROOT" length:100.0 width:100.0 height:100.0 pos:[360,300,50]
            outside_child = Box name:"SMM_BIND_OUTSIDE_CHILD" length:50.0 width:50.0 height:50.0 pos:[510,300,25]
            outside_layer.addNode outside_root
            target_layer.addNode outside_child

            outside_child_tm = outside_child.transform
            outside_child.parent = outside_root
            outside_child.transform = outside_child_tm

            outside_layer.addNode stale_root

            keep_root_before = keep_root.transform
            keep_child_before = keep_child.transform
            stale_root_before = stale_root.transform
            new_root_before = new_root.transform
            outside_root_before = outside_root.transform
            outside_child_before = outside_child.transform

            sync_result = SceneModelManager.syncBoundMatchingLayerMembers model_node
            members_after = SceneModelManager.getModelNodeMembers model_node

            mode_stored_ok = (getUserPropVal model_node "SMM_BIND_MATCHING_LAYER") == true
            sync_success_ok = sync_result[1] == true
            added_one_ok = sync_result[2] == 1
            removed_one_ok = sync_result[3] == 1
            desired_two_ok = sync_result[4] == 2
            member_count_ok = members_after.count == 2
            keep_member_ok = (findItem members_after keep_root) > 0 and keep_root.parent == model_node
            new_member_ok = (findItem members_after new_root) > 0 and new_root.parent == model_node
            stale_removed_ok = (findItem members_after stale_root) == 0 and stale_root.parent == undefined
            keep_child_hierarchy_ok = keep_child.parent == keep_root
            outside_hierarchy_ok = outside_child.parent == outside_root and outside_root.parent == undefined
            transforms_ok = (
                keep_root.transform == keep_root_before and
                keep_child.transform == keep_child_before and
                stale_root.transform == stale_root_before and
                new_root.transform == new_root_before and
                outside_root.transform == outside_root_before and
                outside_child.transform == outside_child_before
            )

            format "SMM TEST 0.008 property exists OFF on create: %\n" initial_property_ok
            format "SMM TEST 0.008 mode stored ON: %\n" mode_stored_ok
            format "SMM TEST 0.008 sync result: %\n" sync_result
            format "SMM TEST 0.008 sync success: %\n" sync_success_ok
            format "SMM TEST 0.008 added exactly one: %\n" added_one_ok
            format "SMM TEST 0.008 removed exactly one: %\n" removed_one_ok
            format "SMM TEST 0.008 desired roots = 2: %\n" desired_two_ok
            format "SMM TEST 0.008 member count = 2: %\n" member_count_ok
            format "SMM TEST 0.008 keep root linked: %\n" keep_member_ok
            format "SMM TEST 0.008 new root linked: %\n" new_member_ok
            format "SMM TEST 0.008 stale root unlinked: %\n" stale_removed_ok
            format "SMM TEST 0.008 child hierarchy preserved: %\n" keep_child_hierarchy_ok
            format "SMM TEST 0.008 outside hierarchy preserved: %\n" outside_hierarchy_ok
            format "SMM TEST 0.008 world transforms exact: %\n" transforms_ok

            test_ok = (
                initial_property_ok and
                mode_ok and
                mode_stored_ok and
                sync_success_ok and
                added_one_ok and
                removed_one_ok and
                desired_two_ok and
                member_count_ok and
                keep_member_ok and
                new_member_ok and
                stale_removed_ok and
                keep_child_hierarchy_ok and
                outside_hierarchy_ok and
                transforms_ok
            )

            if test_ok then
            (
                format "SMM TEST 0.008 PASS\n"
            )
            else
            (
                format "SMM TEST 0.008 FAIL\n"
            )
        )
    )

    test_ok
    -- return
)

runModelMembersBindMatchingLayerTest()
