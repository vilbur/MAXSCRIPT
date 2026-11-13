/*
Scene Asset Manager smoke test.
Run after Scene-Asset-Manager.ms in a disposable scene.
*/
undo "Scene Asset Manager Test" on
(
    local base_node = box name:"SAM_TEST_BASE"
    local instance_node = instance base_node
    instance_node.name = "SAM_TEST_INSTANCE"
    local linked_node = box name:"SAM_TEST_LINKED"
    linked_node.parent = base_node

    local found_nodes = sceneAssetCollectInstances base_node
    format "TEST instances: expected >= 2, actual %\n" found_nodes.count
    format "TEST linked parent: %\n" (linked_node.parent == base_node)
    select base_node
    sceneAssetPopulateTree sceneAssetManagerRollout.tree_nodes base_node
    format "TEST tree root count: %\n" sceneAssetManagerRollout.tree_nodes.Nodes.Count
)
