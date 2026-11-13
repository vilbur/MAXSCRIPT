/* Modifier Sets - independent named modifier-set editor.
   File version: 0.012 | Project version: 0.012.
   Uses scene-backed membership compatible with Modifier-Set-Stack v0.087.
*/
global modifierSetsUI
global modifierSets
global modifier_sets_project_version
global modifier_sets_file_version_ui = 0.012
global modifier_sets_stored_project_version_ui = 0.012
if modifier_sets_project_version == undefined or modifier_sets_stored_project_version_ui > modifier_sets_project_version then
(
    modifier_sets_project_version = modifier_sets_stored_project_version_ui
)
global modifier_sets_title = "Modifier Sets | v" + (formattedPrint modifier_sets_project_version format:".3f")

rollout modifierSetsUI modifier_sets_title width:288 height:792
(
    local stack_handles = #()
    local member_handles = #()
    local set_ids = #()
    local ui_sync = false

    dotNetControl btn_tool_title "System.Windows.Forms.Button" pos:[12,8] width:264 height:18 tooltip:"LMB: Restart the latest version of this tool."
    label lbl_object "Select one object." pos:[12,36] width:264 height:18
    multiListBox lb_stack "AVAILABLE MODIFIERS" pos:[12,64] width:264 height:9 items:#()
    button btn_native "Native selection" pos:[12,259] width:126 height:24
    button btn_refresh "Refresh" pos:[150,259] width:126 height:24

    listBox lb_sets "SETS" pos:[12,294] width:264 height:4 items:#()
    editText txt_set "Set name" pos:[12,396] width:264 text:""
    button btn_add_set "+ Set" pos:[12,430] width:80 height:24
    button btn_rename_set "Rename" pos:[104,430] width:80 height:24
    button btn_delete_set "Delete" pos:[196,430] width:80 height:24
    multiListBox lb_members "SET MEMBERS" pos:[12,469] width:264 height:8 items:#()
    button btn_assign "Assign selected" pos:[12,640] width:126 height:24 tooltip:"Assign available modifiers to the chosen set."
    button btn_ungroup "Ungroup selected" pos:[150,640] width:126 height:24 tooltip:"Remove selected members without deleting modifiers."
    button btn_on "ON" pos:[12,674] width:80 height:24
    button btn_off "OFF" pos:[104,674] width:80 height:24
    button btn_toggle "Toggle" pos:[196,674] width:80 height:24
    dropdownList ddl_scope "ENABLE SCOPE" pos:[12,709] width:264 items:#("Selected", "Current Set") selection:1
    label lbl_status "Ready." pos:[12,760] width:264 height:18

    /* Show tool feedback independently of other modifier tools. */
    function setStatus status_text =
    (
        lbl_status.text = status_text
        true
    )

    /* Return a concrete modifier for an available-stack row. */
    function getStackRowMod row_index =
    (
        result_mod = undefined
        scene_node = modifierSets.getSelectedNode()
        if row_index > 0 and row_index <= stack_handles.count then
        (
            result_mod = modifierSets.resolveHandle scene_node stack_handles[row_index]
        )
        result_mod
    )

    /* Get the persistent set ID or undefined for no set selection. */
    function getSelectedGroupId =
    (
        group_id = undefined
        if lb_sets.selection > 0 and lb_sets.selection <= set_ids.count then group_id = set_ids[lb_sets.selection]
        group_id
    )

    /* Rebuild modifiers and named sets from the selected scene node. */
    function refreshFromScene =
    (
        if not ui_sync then
        (
            ui_sync = true
            old_group_id = modifierSetsUI.getSelectedGroupId()
            selected_handles = #()
            for row_index in lb_stack.selection do
            (
                if row_index <= stack_handles.count then append selected_handles stack_handles[row_index]
            )
            stack_handles = #()
            stack_items = #()
            set_ids = #(0)
            set_items = #("Ungrouped")
            scene_node = modifierSets.getSelectedNode()
            if isValidNode scene_node then
            (
                lbl_object.text = scene_node.name
                modifierSets.cleanStaleRecords()
                for target_mod in scene_node.modifiers do
                (
                    append stack_handles (getHandleByAnim target_mod)
                    append stack_items (target_mod.name + " (" + (classOf target_mod as string) + ")")
                )
                store_value = modifierSets.getStore()
                if store_value != undefined then
                (
                    for group_id = 1 to store_value.group_names.count do
                    (
                        if store_value.group_names[group_id] != "" then
                        (
                            append set_ids group_id
                            append set_items store_value.group_names[group_id]
                        )
                    )
                )
            )
            else
            (
                lbl_object.text = "Select exactly one object."
            )
            lb_stack.items = stack_items
            selected_bits = #{}
            for row_index = 1 to stack_handles.count do
            (
                if findItem selected_handles stack_handles[row_index] > 0 then selected_bits[row_index] = true
            )
            lb_stack.selection = selected_bits
            lb_sets.items = set_items
            lb_sets.selection = 1
            for item_index = 1 to set_ids.count do
            (
                if set_ids[item_index] == old_group_id then lb_sets.selection = item_index
            )
            ui_sync = false
            modifierSetsUI.refreshMembers()
        )
        true
    )

    /* Refresh only the currently selected set's member list. */
    function refreshMembers =
    (
        if not ui_sync then
        (
            ui_sync = true
            member_handles = #()
            member_items = #()
            group_id = modifierSetsUI.getSelectedGroupId()
            scene_node = modifierSets.getSelectedNode()
            if isValidNode scene_node and group_id != undefined then
            (
                for target_mod in (modifierSets.getGroupModifiers scene_node group_id) do
                (
                    append member_handles (getHandleByAnim target_mod)
                    append member_items (target_mod.name + " (" + (classOf target_mod as string) + ")")
                )
                store_value = modifierSets.getStore()
                if group_id == 0 then txt_set.text = "" else txt_set.text = store_value.group_names[group_id]
            )
            lb_members.items = member_items
            lb_members.selection = #{}
            ui_sync = false
        )
        true
    )

    /* Toggle selected native modifiers, or every member of the current set. */
    function applyEnabled enabled_state =
    (
        scene_node = modifierSets.getSelectedNode()
        target_mods = #()
        if isValidNode scene_node then
        (
            if ddl_scope.selection == 2 then
            (
                group_id = modifierSetsUI.getSelectedGroupId()
                if group_id != undefined then target_mods = modifierSets.getGroupModifiers scene_node group_id
            )
            else
            (
                if lb_members.selection.numberSet > 0 then
                (
                    for row_index in lb_members.selection do
                    (
                        if row_index <= member_handles.count then
                        (
                            target_mod = modifierSets.resolveHandle scene_node member_handles[row_index]
                            if target_mod != undefined then appendIfUnique target_mods target_mod
                        )
                    )
                )
                else
                (
                    for row_index in lb_stack.selection do
                    (
                        target_mod = modifierSetsUI.getStackRowMod row_index
                        if target_mod != undefined then appendIfUnique target_mods target_mod
                    )
                )
            )
            undo "Modifier Sets enabled" on
            (
                changed_count = modifierSets.setEnabled scene_node target_mods enabled_state
            )
            if ddl_scope.selection == 2 and enabled_state != #toggle then
            (
                group_id = modifierSetsUI.getSelectedGroupId()
                store_value = modifierSets.getStore()
                if store_value != undefined and group_id != undefined and group_id > 0 then store_value.group_enabled[group_id] = enabled_state
            )
            modifierSetsUI.setStatus ((changed_count as string) + " modifier(s) changed.")
        )
        true
    )

    /* Rebuild the active object's modifier list after scene updates. */
    function requestReadyRefresh =
    (
        modifierSetsUI.refreshFromScene()
        true
    )

    /* Divide extra vertical space between the stacked modifier lists. */
    function fitSetsLayout dialog_height =
    (
        if dialog_height < 792 then dialog_height = 792
        local extra_height = dialog_height - 792
        local extra_rows = (floor (extra_height / 20.0)) as integer
        local stack_extra_rows = (floor (extra_rows / 2.0)) as integer
        local member_extra_rows = extra_rows - stack_extra_rows
        local stack_offset = stack_extra_rows * 20
        local total_offset = (stack_extra_rows + member_extra_rows) * 20
        lb_stack.height = 9 + stack_extra_rows
        lb_members.height = 8 + member_extra_rows
        btn_native.pos = [12, 259 + stack_offset]
        btn_refresh.pos = [150, 259 + stack_offset]
        lb_sets.pos = [12, 294 + stack_offset]
        txt_set.pos = [12, 396 + stack_offset]
        btn_add_set.pos = [12, 430 + stack_offset]
        btn_rename_set.pos = [104, 430 + stack_offset]
        btn_delete_set.pos = [196, 430 + stack_offset]
        lb_members.pos = [12, 469 + stack_offset]
        btn_assign.pos = [12, 640 + total_offset]
        btn_ungroup.pos = [150, 640 + total_offset]
        btn_on.pos = [12, 674 + total_offset]
        btn_off.pos = [104, 674 + total_offset]
        btn_toggle.pos = [196, 674 + total_offset]
        ddl_scope.pos = [12, 709 + total_offset]
        lbl_status.pos = [12, dialog_height - 32]
        ToolTitleButton.resizeToolTitleButton btn_tool_title (modifierSetsUI.width - 24)
        true
    )

    on modifierSetsUI open do
    (
        ToolTitleButton.setupToolTitleButton btn_tool_title "Modifier Sets"
        modifierSetsUI.fitSetsLayout modifierSetsUI.height
        RolloutState.loadDropdown ddl_scope modifier_sets_ini_path "MainUI" "EnableScope" default_value:1
        callbacks.removeScripts id:#msSetsSelectionChanged
        callbacks.removeScripts id:#msSetsModifierAdded
        callbacks.removeScripts id:#msSetsModifierDeleted
        callbacks.addScript #selectionSetChanged "if modifierSetsUI != undefined then modifierSetsUI.requestReadyRefresh()" id:#msSetsSelectionChanged persistent:false
        callbacks.addScript #postModifierAdded "if modifierSetsUI != undefined then modifierSetsUI.refreshFromScene()" id:#msSetsModifierAdded persistent:false
        callbacks.addScript #postModifierDeleted "if modifierSetsUI != undefined then modifierSetsUI.refreshFromScene()" id:#msSetsModifierDeleted persistent:false
        modifierSetsUI.refreshFromScene()
    )
    on modifierSetsUI moved dialog_pos do
    (
        DialogHost.saveDialogPosition modifierSetsUI modifier_sets_ini_path "MainUI"
    )

    on modifierSetsUI resized dialog_size do
    (
        modifierSetsUI.fitSetsLayout dialog_size.y
        DialogHost.saveDialogHeight modifierSetsUI modifier_sets_ini_path "MainUI" min_height:792
    )

    on btn_tool_title Click sender event_args do
    (
        restartTool modifier_sets_main_path "Modifier-Sets"
    )

    on modifierSetsUI close do
    (
        RolloutState.saveDropdown ddl_scope modifier_sets_ini_path "MainUI" "EnableScope"
        DialogHost.saveDialogState modifierSetsUI modifier_sets_ini_path "MainUI" min_height:792
        callbacks.removeScripts id:#msSetsSelectionChanged
        callbacks.removeScripts id:#msSetsModifierAdded
        callbacks.removeScripts id:#msSetsModifierDeleted
    )
    on ddl_scope selected item_index do
    (
        RolloutState.saveDropdown ddl_scope modifier_sets_ini_path "MainUI" "EnableScope"
    )
    on btn_refresh pressed do (modifierSetsUI.refreshFromScene())
    on btn_native pressed do
    (
        scene_node = modifierSets.getSelectedNode()
        active_mod = modPanel.getCurrentObject()
        selected_bits = #{}
        if isValidNode scene_node then
        (
            for row_index = 1 to stack_handles.count do
            (
                candidate_mod = modifierSets.resolveHandle scene_node stack_handles[row_index]
                if candidate_mod != undefined and candidate_mod == active_mod then selected_bits[row_index] = true
            )
        )
        lb_members.selection = #{}
        lb_stack.selection = selected_bits
    )
    on lb_stack selected item_index do (if not ui_sync then lb_members.selection = #{})
    on lb_sets selected item_index do (if not ui_sync then modifierSetsUI.refreshMembers())
    on btn_add_set pressed do
    (
        new_id = modifierSets.addGroup txt_set.text
        modifierSetsUI.refreshFromScene()
        if new_id > 0 then
        (
            for index_value = 1 to set_ids.count do
            (
                if set_ids[index_value] == new_id then lb_sets.selection = index_value
            )
            modifierSetsUI.refreshMembers()
            modifierSetsUI.setStatus "Set created or selected."
        )
        else
        (
            modifierSetsUI.setStatus "Enter a nonempty set name."
        )
    )
    on btn_rename_set pressed do
    (
        group_id = modifierSetsUI.getSelectedGroupId()
        success_value = false
        if group_id != undefined and group_id > 0 then success_value = modifierSets.renameGroup group_id txt_set.text
        modifierSetsUI.refreshFromScene()
        if success_value then modifierSetsUI.setStatus "Set renamed." else modifierSetsUI.setStatus "Choose a unique set name."
    )
    on btn_delete_set pressed do
    (
        group_id = modifierSetsUI.getSelectedGroupId()
        success_value = false
        if group_id != undefined and group_id > 0 then success_value = modifierSets.deleteGroup group_id
        modifierSetsUI.refreshFromScene()
        if success_value then modifierSetsUI.setStatus "Set removed; modifiers untouched." else modifierSetsUI.setStatus "Choose a named set."
    )
    on btn_assign pressed do
    (
        scene_node = modifierSets.getSelectedNode()
        group_id = modifierSetsUI.getSelectedGroupId()
        changed_count = 0
        if isValidNode scene_node and group_id != undefined then
        (
            for row_index in lb_stack.selection do
            (
                target_mod = modifierSetsUI.getStackRowMod row_index
                if modifierSets.assignGroup scene_node target_mod group_id then changed_count += 1
            )
        )
        modifierSetsUI.refreshFromScene()
        modifierSetsUI.setStatus ((changed_count as string) + " modifier(s) assigned.")
    )
    on btn_ungroup pressed do
    (
        scene_node = modifierSets.getSelectedNode()
        changed_count = 0
        if isValidNode scene_node then
        (
            for row_index in lb_members.selection do
            (
                if row_index <= member_handles.count then
                (
                    target_mod = modifierSets.resolveHandle scene_node member_handles[row_index]
                    if modifierSets.assignGroup scene_node target_mod 0 then changed_count += 1
                )
            )
        )
        modifierSetsUI.refreshFromScene()
        modifierSetsUI.setStatus ((changed_count as string) + " modifier(s) ungrouped.")
    )
    on btn_on pressed do (modifierSetsUI.applyEnabled true)
    on btn_off pressed do (modifierSetsUI.applyEnabled false)
    on btn_toggle pressed do (modifierSetsUI.applyEnabled #toggle)
)
