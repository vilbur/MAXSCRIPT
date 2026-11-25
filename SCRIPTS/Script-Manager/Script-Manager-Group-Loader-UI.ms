/*
GROUP MANAGER: one horizontal dialog for user groups, script members and toolbars.
Script member rows show filenames only; the backend retains their full paths.
*/

global script_manager_group_loader_ui
global script_manager
global scriptManagerLayoutGroupLoader
global script_manager_group_loader_version_text
global script_manager_group_loader_title

/*
Derives GROUP MANAGER title labels from the active Script-Manager version.
The standalone script-member editor is no longer created.
*/
script_manager_group_loader_version_text = formattedPrint script_manager.file_version format:"1.3f"
script_manager_group_loader_title = "GROUP MANAGER v" + script_manager_group_loader_version_text

/*
Resizes all three listboxes together while leaving the dialog width fixed.
Action rows and the shared preview/status remain aligned after vertical resizing.
*/
function scriptManagerLayoutGroupLoader dialog_size =
(
    if script_manager_group_loader_ui == undefined then return false
    local height_value = amax 430 dialog_size.y
    local list_height = amax 120 (height_value - 190)
    local actions_y = 66 + list_height
    local second_actions_y = actions_y + 30
    local preview_y = actions_y + 62
    local status_y = actions_y + 88

    script_manager_group_loader_ui.lb_groups.Height = list_height
    script_manager_group_loader_ui.lb_members.Height = list_height
    script_manager_group_loader_ui.lb_toolbars.Height = list_height

    script_manager_group_loader_ui.btn_new_group.pos = [4,actions_y]
    script_manager_group_loader_ui.btn_delete_group.pos = [212,actions_y]
    script_manager_group_loader_ui.btn_load_group.pos = [4,second_actions_y]

    script_manager_group_loader_ui.btn_add_group.pos = [420,actions_y]
    script_manager_group_loader_ui.btn_remove_member.pos = [628,actions_y]

    script_manager_group_loader_ui.btn_new_toolbar.pos = [836,actions_y]
    script_manager_group_loader_ui.btn_delete_toolbar.pos = [1044,actions_y]
    script_manager_group_loader_ui.btn_add_group_to_toolbar.pos = [836,second_actions_y]
    script_manager_group_loader_ui.btn_load_toolbar.pos = [1076,second_actions_y]

    script_manager_group_loader_ui.lbl_selection.pos = [4,preview_y]
    script_manager_group_loader_ui.lbl_status.pos = [4,status_y]
    true
    -- return
)


global script_manager_group_context_menus
global script_manager_group_context_items
global scriptManagerCreateGroupContextMenu
global scriptManagerGroupContextOpening
global scriptManagerGroupContextClick
global scriptManagerGroupListMouseDown
global scriptManagerClearGroupContextMenus
script_manager_group_context_menus = #()
script_manager_group_context_items = #()

/*
Selects the item under the right mouse button before showing its action menu.
Clicking empty list space clears selection but retains creation actions.
*/
function scriptManagerGroupListMouseDown sender event_args =
(
    if event_args.Button.ToString() == "Right" then
    (
        local hit_index = sender.IndexFromPoint event_args.X event_args.Y
        if hit_index != sender.SelectedIndex then sender.SelectedIndex = hit_index
    )
    true
    -- return
)

/*
Creates one persistent dark context menu for a GROUP MANAGER listbox.
Menu actions invoke the same backend methods as the buttons below that list.
*/
function scriptManagerCreateGroupContextMenu list_control role action_names =
(
    local menu = dotNetObject "System.Windows.Forms.ContextMenuStrip"
    local color_class = dotNetClass "System.Drawing.Color"
    local dark_color = color_class.FromArgb 45 45 48
    local text_color = color_class.FromArgb 225 225 225
    menu.BackColor = dark_color
    menu.ForeColor = text_color
    menu.ShowImageMargin = false
    menu.Tag = role
    local menu_items = menu.Items
    for action_name in action_names do
    (
        local menu_item = dotNetObject "System.Windows.Forms.ToolStripMenuItem" action_name
        menu_item.Tag = action_name
        menu_item.BackColor = dark_color
        menu_item.ForeColor = text_color
        menu_items.Add menu_item
        dotNet.addEventHandler menu_item "Click" scriptManagerGroupContextClick
        append script_manager_group_context_items menu_item
    )
    dotNet.addEventHandler menu "Opening" scriptManagerGroupContextOpening
    list_control.Tag = role
    list_control.ContextMenuStrip = menu
    append script_manager_group_context_menus menu
    true
    -- return
)

/*
Rebuilds action captions from the current group, script, toolbar and tree selection.
No menu collections are cleared or recreated while the popup is open.
*/
function scriptManagerGroupContextOpening sender event_args =
(
    if script_manager_group_loader_ui == undefined then return false
    if not(script_manager.isGroupLoaderOpen()) then return false
    local group_name = script_manager.group_loader_selected_group
    local toolbar_name = script_manager.group_loader_selected_toolbar
    local member_name = "selected script"
    local member_index = script_manager_group_loader_ui.lb_members.SelectedIndex + 1
    if member_index > 0 and member_index <= script_manager.group_loader_member_paths.count then
    (
        member_name = scriptManagerGetDisplayScriptName script_manager.group_loader_member_paths[member_index]
    )
    local tree_name = "tree selection"
    if group_name != "" then
    (
        local tree_items = script_manager.getSelectedTreeScriptsForUserGroup()
        if tree_items.count == 1 then
        (
            local tree_path = tree_items[1]
            tree_name = if doesDirectoryExist tree_path then ScriptManagerIntegration.getFolderName tree_path else scriptManagerGetDisplayScriptName tree_path
        )
        else if tree_items.count > 1 then tree_name = (tree_items.count as string) + " tree items"
    )
    local menu_items = sender.Items
    for index = 0 to (menu_items.Count - 1) do
    (
        local item = menu_items.Item[index]
        local action_name = item.Tag as string
        case action_name of
        (
            "new_group":
            (
                item.Text = "New group"
                item.Enabled = script_manager_group_loader_ui.btn_new_group.enabled
            )
            "delete_group":
            (
                item.Text = if group_name != "" then "Delete " + group_name else "Delete group"
                item.Enabled = script_manager_group_loader_ui.btn_delete_group.enabled
            )
            "load_group":
            (
                item.Text = if group_name != "" then "Load " + group_name + " as group" else "Load group"
                item.Enabled = script_manager_group_loader_ui.btn_load_group.enabled
            )
            "add_tree":
            (
                item.Text = "Add " + tree_name + " to group" + (if group_name != "" then " " + group_name else "")
                item.Enabled = script_manager_group_loader_ui.btn_add_group.enabled
            )
            "remove_member":
            (
                item.Text = "Remove " + member_name + (if group_name != "" then " from " + group_name else " from group")
                item.Enabled = script_manager_group_loader_ui.btn_remove_member.enabled
            )
            "new_toolbar":
            (
                item.Text = "New toolbar"
                item.Enabled = script_manager_group_loader_ui.btn_new_toolbar.enabled
            )
            "delete_toolbar":
            (
                item.Text = if toolbar_name != "" then "Delete " + toolbar_name else "Delete toolbar"
                item.Enabled = script_manager_group_loader_ui.btn_delete_toolbar.enabled
            )
            "add_group_to_toolbar":
            (
                item.Text = "Add " + (if group_name != "" then group_name else "group") + " to " + (if toolbar_name != "" then toolbar_name else "toolbar")
                item.Enabled = script_manager_group_loader_ui.btn_add_group_to_toolbar.enabled
            )
            "load_toolbar":
            (
                item.Text = if toolbar_name != "" then "Load " + toolbar_name + " as group" else "Load toolbar as group"
                item.Enabled = script_manager_group_loader_ui.btn_load_toolbar.enabled
            )
        )
    )
    true
    -- return
)

/*
Routes a right-click menu command through its existing GROUP MANAGER action.
The same selection validation and deletion confirmation remain in the backend.
*/
function scriptManagerGroupContextClick sender event_args =
(
    if script_manager_group_loader_ui == undefined then return false
    if not(script_manager.isGroupLoaderOpen()) then return false
    case (sender.Tag as string) of
    (
        "new_group": (script_manager.createUserGroupFromSelection())
        "delete_group": (script_manager.deleteSelectedUserGroup())
        "load_group": (script_manager.loadGroupLoaderSelection #tree)
        "add_tree": (script_manager.addTreeSelectionToUserGroup())
        "remove_member": (script_manager.removeSelectedGroupMember())
        "new_toolbar": (script_manager.createToolbarFromGroupLoader())
        "delete_toolbar": (script_manager.deleteSelectedManagedToolbar())
        "add_group_to_toolbar": (script_manager.addSelectedUserGroupToToolbar())
        "load_toolbar": (script_manager.loadGroupLoaderSelection #toolbar)
    )
    true
    -- return
)

/*
Releases WinForms menu events and objects when GROUP MANAGER closes.
Persistent listbox context menus are never rebuilt during selection changes.
*/
function scriptManagerClearGroupContextMenus =
(
    for menu_item in script_manager_group_context_items do
    (
        try (dotNet.removeAllEventHandlers menu_item) catch ()
    )
    for menu in script_manager_group_context_menus do
    (
        try (dotNet.removeAllEventHandlers menu) catch ()
        try (menu.Dispose()) catch ()
    )
    script_manager_group_context_items = #()
    script_manager_group_context_menus = #()
    true
    -- return
)

rollout script_manager_group_loader_ui script_manager_group_loader_title width:1248 height:430
(
    dotNetControl btn_title "System.Windows.Forms.Button" pos:[4,4] width:1240 height:28

    label lbl_groups "USER GROUPS" pos:[4,40] width:408 height:18
    dotNetControl lb_groups "System.Windows.Forms.ListBox" pos:[4,60] width:408 height:240
    button btn_new_group "NEW GROUP" pos:[4,306] width:200 height:24
    button btn_delete_group "DELETE GROUP" pos:[212,306] width:200 height:24 enabled:false
    button btn_load_group "LOAD SELECTED GROUP" pos:[4,336] width:408 height:24 enabled:false

    label lbl_members "GROUP SCRIPTS" pos:[420,40] width:408 height:18
    dotNetControl lb_members "System.Windows.Forms.ListBox" pos:[420,60] width:408 height:240
    button btn_add_group "ADD TREE SELECTION" pos:[420,306] width:200 height:24 enabled:false
    button btn_remove_member "REMOVE SELECTED SCRIPT" pos:[628,306] width:200 height:24 enabled:false

    label lbl_toolbars "CUSTOM TOOLBARS" pos:[836,40] width:408 height:18
    dotNetControl lb_toolbars "System.Windows.Forms.ListBox" pos:[836,60] width:408 height:240
    button btn_new_toolbar "NEW TOOLBAR" pos:[836,306] width:200 height:24
    button btn_delete_toolbar "DELETE TOOLBAR" pos:[1044,306] width:200 height:24 enabled:false
    button btn_add_group_to_toolbar "ADD SELECTED GROUP TO TOOLBAR" pos:[836,336] width:236 height:24 enabled:false
    button btn_load_toolbar "LOAD TOOLBAR AS GROUP" pos:[1076,336] width:168 height:24 enabled:false

    label lbl_selection "Select a user group or toolbar to view its scripts." pos:[4,368] width:1240 height:22
    label lbl_status "" pos:[4,394] width:1240 height:28

    on script_manager_group_loader_ui open do
    (
        script_manager.styleToolTitleButton btn_title
        btn_title.Text = "GROUP MANAGER | REFRESH  |  v" + script_manager_group_loader_version_text
        for list_control in #(lb_groups,lb_members,lb_toolbars) do
        (
            list_control.BackColor = (dotNetClass "System.Drawing.Color").FromArgb 45 45 48
            list_control.ForeColor = (dotNetClass "System.Drawing.Color").FromArgb 225 225 225
            list_control.BorderStyle = (dotNetClass "System.Windows.Forms.BorderStyle").FixedSingle
            list_control.IntegralHeight = false
            list_control.HorizontalScrollbar = true
        )
        script_manager.group_loader_group_items = lb_groups.Items
        script_manager.group_loader_member_items = lb_members.Items
        script_manager.group_loader_toolbar_items = lb_toolbars.Items
        scriptManagerCreateGroupContextMenu lb_groups "groups" #("new_group","delete_group","load_group")
        scriptManagerCreateGroupContextMenu lb_members "members" #("add_tree","remove_member")
        scriptManagerCreateGroupContextMenu lb_toolbars "toolbars" #("new_toolbar","delete_toolbar","add_group_to_toolbar","load_toolbar")
        scriptManagerLayoutGroupLoader [script_manager_group_loader_ui.width,script_manager_group_loader_ui.height]
        script_manager.refreshGroupLoader()
    )

    on script_manager_group_loader_ui resized dialog_size do
    (
        scriptManagerLayoutGroupLoader dialog_size
    )

    on script_manager_group_loader_ui close do
    (
        scriptManagerClearGroupContextMenus()
    )

    on lb_groups MouseDown sender event_args do (scriptManagerGroupListMouseDown sender event_args)
    on lb_members MouseDown sender event_args do (scriptManagerGroupListMouseDown sender event_args)
    on lb_toolbars MouseDown sender event_args do (scriptManagerGroupListMouseDown sender event_args)

    on btn_title Click sender event_args do (script_manager.refreshGroupLoader())
    on lb_groups SelectedIndexChanged sender event_args do (script_manager.updateGroupLoaderSelection #tree)
    on lb_members SelectedIndexChanged sender event_args do (script_manager.updateGroupMemberSelection())
    on lb_toolbars SelectedIndexChanged sender event_args do (script_manager.updateGroupLoaderSelection #toolbar)
    on lb_groups DoubleClick sender event_args do (script_manager.loadGroupLoaderSelection #tree)
    on lb_toolbars DoubleClick sender event_args do (script_manager.loadGroupLoaderSelection #toolbar)
    on btn_new_group pressed do (script_manager.createUserGroupFromSelection())
    on btn_delete_group pressed do (script_manager.deleteSelectedUserGroup())
    on btn_load_group pressed do (script_manager.loadGroupLoaderSelection #tree)
    on btn_add_group pressed do (script_manager.addTreeSelectionToUserGroup())
    on btn_remove_member pressed do (script_manager.removeSelectedGroupMember())
    on btn_new_toolbar pressed do (script_manager.createToolbarFromGroupLoader())
    on btn_delete_toolbar pressed do (script_manager.deleteSelectedManagedToolbar())
    on btn_add_group_to_toolbar pressed do (script_manager.addSelectedUserGroupToToolbar())
    on btn_load_toolbar pressed do (script_manager.loadGroupLoaderSelection #toolbar)
)
