/*
Scene Model Manager 0.009 focused MODEL NODE double-click layer-focus backend test.
Run Scene-Model-Manager-FN.ms before this file.

Goal:
- Selected MODEL member layers and every parent layer become visible.
- Descendant object layers inside the selected member hierarchy are included.
- Other MODEL NODE member/source layers become hidden.
- Unrelated scene layers keep their existing visibility state.
*/

/*
Builds two MODEL NODE layer branches, focuses NODE A, and validates visibility behavior.
UNDO: removes the complete test scene and restores test-layer state when supported by 3ds Max undo.
*/
function runModelNodeLayerFocusTest =
(
    test_ok = false

    undo "SMM TEST 0.009 - MODEL LAYER FOCUS" on
    (
        top_name = "SMM_FOCUS_TOP"
        nested_name = "SMM_FOCUS_NESTED"
        node_a_name = "SMM_FOCUS_NODE_A"
        node_a_detail_name = "SMM_FOCUS_NODE_A_DETAIL"
        node_b_name = "SMM_FOCUS_NODE_B"
        unrelated_name = "SMM_FOCUS_UNRELATED"

        top_layer = LayerManager.getLayerFromName top_name
        if top_layer == undefined then top_layer = LayerManager.newLayerFromName top_name

        nested_layer = LayerManager.getLayerFromName nested_name
        if nested_layer == undefined then nested_layer = LayerManager.newLayerFromName nested_name

        node_a_layer = LayerManager.getLayerFromName node_a_name
        if node_a_layer == undefined then node_a_layer = LayerManager.newLayerFromName node_a_name

        node_a_detail_layer = LayerManager.getLayerFromName node_a_detail_name
        if node_a_detail_layer == undefined then node_a_detail_layer = LayerManager.newLayerFromName node_a_detail_name

        node_b_layer = LayerManager.getLayerFromName node_b_name
        if node_b_layer == undefined then node_b_layer = LayerManager.newLayerFromName node_b_name

        unrelated_layer = LayerManager.getLayerFromName unrelated_name
        if unrelated_layer == undefined then unrelated_layer = LayerManager.newLayerFromName unrelated_name

        nested_parent_ok = nested_layer.setParent top_layer
        node_a_parent_ok = node_a_layer.setParent nested_layer
        node_a_detail_parent_ok = node_a_detail_layer.setParent node_a_layer
        node_b_parent_ok = node_b_layer.setParent nested_layer

        root_a = Box name:"SMM_FOCUS_ROOT_A" length:100.0 width:100.0 height:100.0 pos:[0,0,50]
        child_a = Box name:"SMM_FOCUS_CHILD_A" length:50.0 width:50.0 height:50.0 pos:[150,0,25]
        root_b = Box name:"SMM_FOCUS_ROOT_B" length:100.0 width:100.0 height:100.0 pos:[0,300,50]
        unrelated_node = Box name:"SMM_FOCUS_UNRELATED_BOX" length:80.0 width:80.0 height:80.0 pos:[400,300,40]

        node_a_layer.addNode root_a
        node_a_detail_layer.addNode child_a
        node_b_layer.addNode root_b
        unrelated_layer.addNode unrelated_node

        child_a_tm = child_a.transform
        child_a.parent = root_a
        child_a.transform = child_a_tm

        text_size = units.decodeValue "100cm"
        model_a = SceneModelManager.createModelNode node_a_name #(root_a, child_a) undefined 150 text_size
        model_b = SceneModelManager.createModelNode node_b_name #(root_b) undefined 150 text_size

        top_layer.isHidden = true
        nested_layer.isHidden = true
        node_a_layer.isHidden = true
        node_a_detail_layer.isHidden = true
        node_b_layer.isHidden = false
        unrelated_layer.isHidden = false

        focus_result = if model_a == undefined then #(false,0,0,"MODEL A missing") else SceneModelManager.focusModelNodeMemberLayers model_a

        hierarchy_layers_ok = (
            not top_layer.isHidden and
            not nested_layer.isHidden and
            not node_a_layer.isHidden and
            not node_a_detail_layer.isHidden
        )
        other_model_hidden_ok = node_b_layer.isHidden
        unrelated_unchanged_ok = not unrelated_layer.isHidden
        parent_setup_ok = nested_parent_ok and node_a_parent_ok and node_a_detail_parent_ok and node_b_parent_ok
        model_nodes_ok = model_a != undefined and model_b != undefined

        format "SMM TEST 0.009 focus result: %\n" focus_result
        format "SMM TEST 0.009 parent setup: %\n" parent_setup_ok
        format "SMM TEST 0.009 model nodes created: %\n" model_nodes_ok
        format "SMM TEST 0.009 selected chain visible: %\n" hierarchy_layers_ok
        format "SMM TEST 0.009 other MODEL layer hidden: %\n" other_model_hidden_ok
        format "SMM TEST 0.009 unrelated layer unchanged: %\n" unrelated_unchanged_ok

        test_ok = (
            focus_result[1] and
            parent_setup_ok and
            model_nodes_ok and
            hierarchy_layers_ok and
            other_model_hidden_ok and
            unrelated_unchanged_ok
        )

        if test_ok then
        (
            format "SMM TEST 0.009 PASS\n"
        )
        else
        (
            format "SMM TEST 0.009 FAIL\n"
        )
    )

    test_ok
    -- return
)

runModelNodeLayerFocusTest()
