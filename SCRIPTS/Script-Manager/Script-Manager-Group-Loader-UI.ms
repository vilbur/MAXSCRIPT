/*
GROUP MANAGER: standalone, vertically resizable user interface for Script-Manager.
The manager owns explicit group storage and loading; this file owns the dialog and its layout.
*/

global script_manager_group_loader_ui
global script_manager
global scriptManagerLayoutGroupLoader
global script_manager_group_loader_version_text
global script_manager_group_loader_title

/*
Derives both GROUP MANAGER title labels from the active Script-Manager version.
Loading a newer UI module cannot leave an old hard-coded version visible.
*/
script_manager_group_loader_version_text = formattedPrint script_manager.file_version format:"1.3f"
script_manager_group_loader_title = "GROUP MANAGER v" + script_manager_group_loader_version_text

/*
Resizes both GROUP MANAGER lists proportionally and anchors actions/status beneath them.
The dialog width is locked; the list heights follow its available vertical space.
*/
function scriptManagerLayoutGroupLoader dialog_size =
(
    if script_manager_group_loader_ui == undefined then return false
    local height_value = amax 442 dialog_size.y
    local extra_height = height_value - 642
    local first_offset = (floor (extra_height / 2.0)) as integer
    local second_offset = extra_height - first_offset
    local first_height = amax 80 (180 + first_offset)
    local second_height = amax 80 (180 + second_offset)
    local bottom_offset = (first_height - 180) + (second_height - 180)
    local first_shift = first_height - 180

    script_manager_group_loader_ui.lb_groups.Height = first_height
    script_manager_group_loader_ui.btn_new_group.pos = [4,244 + first_shift]
    script_manager_group_loader_ui.btn_add_group.pos = [176,244 + first_shift]
    script_manager_group_loader_ui.btn_delete_group.pos = [348,244 + first_shift]
    script_manager_group_loader_ui.btn_load_group.pos = [4,274 + first_shift]
    script_manager_group_loader_ui.btn_edit_members.pos = [264,274 + first_shift]
    script_manager_group_loader_ui.lbl_toolbars.pos = [4,310 + first_shift]
    script_manager_group_loader_ui.lb_toolbars.pos = [4,330 + first_shift]
    script_manager_group_loader_ui.lb_toolbars.Height = second_height
    script_manager_group_loader_ui.btn_new_toolbar.pos = [4,514 + bottom_offset]
    script_manager_group_loader_ui.btn_add_group_to_toolbar.pos = [4,542 + bottom_offset]
    script_manager_group_loader_ui.btn_load_toolbar.pos = [264,542 + bottom_offset]
    script_manager_group_loader_ui.lbl_selection.pos = [4,568 + bottom_offset]
    script_manager_group_loader_ui.lbl_status.pos = [4,596 + bottom_offset]
    true
    -- return
)

rollout script_manager_group_loader_ui script_manager_group_loader_title width:520 height:642
(
    dotNetControl btn_title "System.Windows.Forms.Button" pos:[4,4] width:512 height:28
    label lbl_groups "USER GROUPS" pos:[4,40] width:512 height:18
    dotNetControl lb_groups "System.Windows.Forms.ListBox" pos:[4,60] width:512 height:180
    button btn_new_group "NEW GROUP" pos:[4,244] width:168 height:24
    button btn_add_group "ADD TREE SELECTION" pos:[176,244] width:168 height:24 enabled:false
    button btn_delete_group "DELETE GROUP" pos:[348,244] width:168 height:24 enabled:false
    button btn_load_group "LOAD SELECTED GROUP" pos:[4,274] width:252 height:24 enabled:false
    button btn_edit_members "EDIT GROUP SCRIPTS" pos:[264,274] width:252 height:24
    label lbl_toolbars "CUSTOM TOOLBARS" pos:[4,310] width:512 height:18
    dotNetControl lb_toolbars "System.Windows.Forms.ListBox" pos:[4,330] width:512 height:180
    button btn_new_toolbar "NEW TOOLBAR" pos:[4,514] width:512 height:24
    button btn_add_group_to_toolbar "ADD SELECTED GROUP TO TOOLBAR" pos:[4,542] width:256 height:24 enabled:false
    button btn_load_toolbar "LOAD TOOLBAR AS GROUP" pos:[264,542] width:252 height:24 enabled:false
    label lbl_selection "Select a user group or toolbar to view its scripts." pos:[4,568] width:512 height:22
    label lbl_status "" pos:[4,596] width:512 height:36

    on script_manager_group_loader_ui open do
    (
        script_manager.styleToolTitleButton btn_title
        btn_title.Text = "GROUP MANAGER | REFRESH  |  v" + script_manager_group_loader_version_text
        for list_control in #(lb_groups,lb_toolbars) do
        (
            list_control.BackColor = (dotNetClass "System.Drawing.Color").FromArgb 45 45 48
            list_control.ForeColor = (dotNetClass "System.Drawing.Color").FromArgb 225 225 225
            list_control.BorderStyle = (dotNetClass "System.Windows.Forms.BorderStyle").FixedSingle
            list_control.IntegralHeight = false
            list_control.HorizontalScrollbar = true
        )
        script_manager.group_loader_group_items = lb_groups.Items
        script_manager.group_loader_toolbar_items = lb_toolbars.Items
        scriptManagerLayoutGroupLoader [script_manager_group_loader_ui.width,script_manager_group_loader_ui.height]
        script_manager.refreshGroupLoader()
    )

    on script_manager_group_loader_ui resized dialog_size do
    (
        scriptManagerLayoutGroupLoader dialog_size
    )

    on btn_title Click sender event_args do (script_manager.refreshGroupLoader())
    on lb_groups SelectedIndexChanged sender event_args do (script_manager.updateGroupLoaderSelection #tree)
    on lb_toolbars SelectedIndexChanged sender event_args do (script_manager.updateGroupLoaderSelection #toolbar)
    on lb_groups DoubleClick sender event_args do (script_manager.loadGroupLoaderSelection #tree)
    on lb_toolbars DoubleClick sender event_args do (script_manager.loadGroupLoaderSelection #toolbar)
    on btn_new_group pressed do (script_manager.createUserGroupFromSelection())
    on btn_add_group pressed do (script_manager.addTreeSelectionToUserGroup())
    on btn_delete_group pressed do (script_manager.deleteSelectedUserGroup())
    on btn_edit_members pressed do (script_manager.editSelectedGroupMembers())
    on btn_load_group pressed do (script_manager.loadGroupLoaderSelection #tree)
    on btn_new_toolbar pressed do (script_manager.createToolbarFromGroupLoader())
    on btn_add_group_to_toolbar pressed do (script_manager.addSelectedUserGroupToToolbar())
    on btn_load_toolbar pressed do (script_manager.loadGroupLoaderSelection #toolbar)
)
