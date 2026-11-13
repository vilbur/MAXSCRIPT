/*
Scene Asset Manager v0.001
Read-only prototype: instance groups and linked scene children.
Reference-branch classification is deliberately not guessed.
*/

global sceneAssetManagerRollout

/*
Collect scene nodes sharing the selected node's base object.
Uses the native instance manager.
*/
function sceneAssetCollectInstances source_node =
(
    local result_nodes = #()
    if isValidNode source_node then
    (
        instanceMgr.GetInstances source_node &result_nodes
    )
    result_nodes -- return
)

/*
Add scene-linked children recursively beneath a TreeView item.
Does not change parenting or transforms.
*/
function sceneAssetAddLinkedChildren scene_node tree_item =
(
    for child_node in scene_node.children do
    (
        local child_item = dotNetObject "System.Windows.Forms.TreeNode" (child_node.name + " [Linked]")
        child_item.Tag = dotNetMXSValue child_node
        tree_item.Nodes.Add child_item
        sceneAssetAddLinkedChildren child_node child_item
    )
    true -- return
)

/*
Build the initial read-only relationship display.
Reference inheritance branches require a separate verified dependency walker.
*/
function sceneAssetPopulateTree tree_control source_node =
(
    tree_control.Nodes.Clear()
    if isValidNode source_node then
    (
        local root_item = dotNetObject "System.Windows.Forms.TreeNode" (source_node.name + " [Selected]")
        root_item.Tag = dotNetMXSValue source_node
        tree_control.Nodes.Add root_item
        sceneAssetAddLinkedChildren source_node root_item

        local instance_nodes = sceneAssetCollectInstances source_node
        for instance_node in instance_nodes where instance_node != source_node do
        (
            local instance_item = dotNetObject "System.Windows.Forms.TreeNode" (instance_node.name + " [Instance]")
            instance_item.Tag = dotNetMXSValue instance_node
            root_item.Nodes.Add instance_item
            sceneAssetAddLinkedChildren instance_node instance_item
        )
        root_item.Expand()
    )
    else
    (
        format "Scene Asset Manager: Select one scene node before refreshing.\n"
    )
    true -- return
)

try (destroyDialog sceneAssetManagerRollout) catch ()

rollout sceneAssetManagerRollout "Scene Asset Manager v0.001" width:410 height:530
(
    dotNetControl tree_nodes "System.Windows.Forms.TreeView" pos:[8,8] width:394 height:476
    button btn_refresh "Refresh Selected" pos:[8,492] width:394 height:28

    on sceneAssetManagerRollout open do
    (
        tree_nodes.HideSelection = false
        if selection.count == 1 then
        (
            sceneAssetPopulateTree tree_nodes selection[1]
        )
    )

    on btn_refresh pressed do
    (
        if selection.count == 1 then
        (
            sceneAssetPopulateTree tree_nodes selection[1]
        )
        else
        (
            format "Scene Asset Manager: Select exactly one scene node.\n"
        )
    )

    on tree_nodes AfterSelect sender event_args do
    (
        local selected_item = event_args.Node
        if selected_item != undefined then
        (
            local scene_node = selected_item.Tag.value
            if isValidNode scene_node then select scene_node
        )
    )
)

createDialog sceneAssetManagerRollout style:#(#style_titlebar, #style_sysmenu, #style_resizing)
