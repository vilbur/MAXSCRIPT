/*
Scene Model Manager 0.006 focused MODEL MEMBERS hierarchy/layer-binding test.
Run Scene-Model-Manager-FN.ms before this file.

Goal:
- CREATE MODEL NODE stores only top hierarchy roots.
- BIND MATCHING LAYER uses the exact MODEL NODE/layer name.
- Child hierarchies stay untouched.
- A child whose true hierarchy root is outside the matching layer is not detached.
*/

/*
Builds one hierarchy test scene and validates MODEL MEMBERS behavior.
UNDO: removes the complete test scene created by this function.
*/
function runModelMembersTest =
(
    test_ok = false

    undo "SMM TEST 0.006 - MODEL MEMBERS" on
    (
        target_layer_name = "SMM_MEMBERS_TEST"
        outside_layer_name = "SMM_MEMBERS_OUTSIDE"

        target_layer = LayerManager.getLayerFromName target_layer_name
        if target_layer == undefined then target_layer = LayerManager.newLayerFromName target_layer_name

        outside_layer = LayerManager.getLayerFromName outside_layer_name
        if outside_layer == undefined then outside_layer = LayerManager.newLayerFromName outside_layer_name

        root_a = Box name:"SMM_MEM_ROOT_A" length:120.0 width:120.0 height:120.0 pos:[0,0,60]
        child_a = Box name:"SMM_MEM_CHILD_A" length:60.0 width:60.0 height:60.0 pos:[180,0,30]
        standalone_a = Box name:"SMM_MEM_STANDALONE_A" length:100.0 width:100.0 height:100.0 pos:[360,0,50]

        target_layer.addNode root_a
        target_layer.addNode child_a
        target_layer.addNode standalone_a

        child_a_tm = child_a.transform
        child_a.parent = root_a
        child_a.transform = child_a_tm

        source_nodes = #(root_a, child_a, standalone_a)
        model_node = SceneModelManager.createModelNode target_layer_name source_nodes undefined 150 (units.decodeValue "100cm")

        create_members = if model_node == undefined then #() else SceneModelManager.getModelNodeMembers model_node
        create_root_count_ok = create_members.count == 2
        create_root_parent_ok = model_node != undefined and root_a.parent == model_node
        create_child_parent_ok = child_a.parent == root_a
        create_standalone_parent_ok = model_node != undefined and standalone_a.parent == model_node

        root_b = Box name:"SMM_MEM_ROOT_B" length:100.0 width:100.0 height:100.0 pos:[0,300,50]
        child_b = Box name:"SMM_MEM_CHILD_B" length:50.0 width:50.0 height:50.0 pos:[150,300,25]

        target_layer.addNode root_b
        target_layer.addNode child_b

        child_b_tm = child_b.transform
        child_b.parent = root_b
        child_b.transform = child_b_tm

        outside_root = Box name:"SMM_MEM_OUTSIDE_ROOT" length:100.0 width:100.0 height:100.0 pos:[400,300,50]
        outside_child = Box name:"SMM_MEM_OUTSIDE_CHILD" length:50.0 width:50.0 height:50.0 pos:[550,300,25]

        outside_layer.addNode outside_root
        target_layer.addNode outside_child

        outside_child_tm = outside_child.transform
        outside_child.parent = outside_root
        outside_child.transform = outside_child_tm

        bind_result = if model_node == undefined then #(false,0,0,"MODEL NODE missing") else SceneModelManager.bindMatchingLayerToModelNode model_node
        bound_members = if model_node == undefined then #() else SceneModelManager.getModelNodeMembers model_node

        bind_success_ok = bind_result[1] == true
        bind_added_one_ok = bind_result[2] == 1
        total_root_count_ok = bound_members.count == 3
        root_b_parent_ok = model_node != undefined and root_b.parent == model_node
        child_b_parent_ok = child_b.parent == root_b
        outside_hierarchy_ok = outside_child.parent == outside_root

        format "SMM TEST 0.006 create root count: %\n" create_root_count_ok
        format "SMM TEST 0.006 root A linked: %\n" create_root_parent_ok
        format "SMM TEST 0.006 child A preserved: %\n" create_child_parent_ok
        format "SMM TEST 0.006 standalone linked: %\n" create_standalone_parent_ok
        format "SMM TEST 0.006 bind result: %\n" bind_result
        format "SMM TEST 0.006 bind success: %\n" bind_success_ok
        format "SMM TEST 0.006 exactly one new top root added: %\n" bind_added_one_ok
        format "SMM TEST 0.006 total stored roots = 3: %\n" total_root_count_ok
        format "SMM TEST 0.006 root B linked: %\n" root_b_parent_ok
        format "SMM TEST 0.006 child B preserved: %\n" child_b_parent_ok
        format "SMM TEST 0.006 outside-root hierarchy preserved: %\n" outside_hierarchy_ok

        test_ok = (
            create_root_count_ok and
            create_root_parent_ok and
            create_child_parent_ok and
            create_standalone_parent_ok and
            bind_success_ok and
            bind_added_one_ok and
            total_root_count_ok and
            root_b_parent_ok and
            child_b_parent_ok and
            outside_hierarchy_ok
        )

        if test_ok then
        (
            format "SMM TEST 0.006 PASS\n"
        )
        else
        (
            format "SMM TEST 0.006 FAIL\n"
        )
    )

    test_ok
    -- return
)

runModelMembersTest()
