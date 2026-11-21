/* Modifier Stack Live - fast native modifier-stack mirror.
   File version: 0.012 | Project version: 0.012.
*/
global modifierStackLiveUI
global mslLiveStackRollout
global modifierStackLive
global modifier_stack_live_project_version
global modifier_stack_live_file_version_ui = 0.012
global modifier_stack_live_stored_project_version_ui = 0.012
if modifier_stack_live_project_version == undefined or modifier_stack_live_stored_project_version_ui > modifier_stack_live_project_version then
(
    modifier_stack_live_project_version = modifier_stack_live_stored_project_version_ui
)
global modifier_stack_live_title = "Modifier Stack Live | v" + (formattedPrint modifier_stack_live_project_version format:".3f")

/* Display thirty real modifier rows in a dedicated, independently scrollable rollout.
   The owning rollout maintains stack handles and all editing behavior.
*/
rollout mslLiveStackRollout "LIVE STACK" width:294 height:620
(
    multiListBox lb_stack "" pos:[10,8] width:270 height:30 items:#()

    on lb_stack selected item_index do
    (
        modifierStackLiveUI.onLiveStackSelected()
    )
)


/* Top-level LIVE STACK editor. No dependency on Modifier Sets or Modifier Manager. */
rollout modifierStackLiveUI modifier_stack_live_title width:336 height:840
(
    local stack_handles = #()
    local ui_sync = false
    dotNetControl btn_tool_title "System.Windows.Forms.Button" pos:[12,8] width:312 height:18 tooltip:"LMB: Restart the latest version of this tool."
    label lbl_object "Select one object." pos:[12,36] width:312 height:18
    subRollout sr_stack "" pos:[-4,60] width:344 height:648 scrollBar:#asNeeded
    button btn_native "Native selection" pos:[12,720] width:150 height:24 tooltip:"Use the active native modifier as the list selection."
    button btn_refresh "Refresh" pos:[174,720] width:150 height:24
    button btn_on "ON" pos:[12,756] width:96 height:24
    button btn_off "OFF" pos:[120,756] width:96 height:24
    button btn_toggle "Toggle" pos:[228,756] width:96 height:24
    label lbl_status "Ready." pos:[12,800] width:312 height:18

    /* Display feedback without editing the current scene. */
    function setStatus status_text =
    (
        lbl_status.text = status_text
        true
    )

    /* Map LIVE STACK list rows back to real stack modifier references. */
    function getStackRowMod row_index =
    (
        result_mod = undefined
        scene_node = modifierStackLive.getSelectedNode()
        if row_index > 0 and row_index <= stack_handles.count then
        (
            result_mod = modifierStackLive.resolveHandle scene_node stack_handles[row_index]
        )
        result_mod
    )

    /* Selection changes are confined to this tool. */
    function onLiveStackSelected =
    (
        true
    )

    /* Rebuild LIVE STACK from the selected object's native stack. */
    function refreshFromScene =
    (
        if not ui_sync then
        (
            ui_sync = true
            old_selected = #()
            for row_index in mslLiveStackRollout.lb_stack.selection do
            (
                if row_index <= stack_handles.count then append old_selected stack_handles[row_index]
            )
            stack_handles = #()
            stack_items = #()
            scene_node = modifierStackLive.getSelectedNode()
            if isValidNode scene_node then
            (
                lbl_object.text = scene_node.name
                for index_value = 1 to scene_node.modifiers.count do
                (
                    target_mod = scene_node.modifiers[index_value]
                    append stack_handles (getHandleByAnim target_mod)
                    append stack_items ((index_value as string) + "  " + target_mod.name + " (" + (classOf target_mod as string) + ")")
                )
            )
            else
            (
                lbl_object.text = "Select exactly one object."
            )
            mslLiveStackRollout.lb_stack.items = stack_items
            selected_bits = #{}
            for index_value = 1 to stack_handles.count do
            (
                if (findItem old_selected stack_handles[index_value]) > 0 then selected_bits[index_value] = true
            )
            mslLiveStackRollout.lb_stack.selection = selected_bits
            ui_sync = false
        )
        true
    )

    /* Change activation only on the selected real modifiers. */
    function applyEnabled enabled_state =
    (
        scene_node = modifierStackLive.getSelectedNode()
        target_mods = #()
        if isValidNode scene_node then
        (
            for row_index in mslLiveStackRollout.lb_stack.selection do
            (
                target_mod = modifierStackLiveUI.getStackRowMod row_index
                if target_mod != undefined then appendIfUnique target_mods target_mod
            )
            undo "LIVE STACK enabled" on
            (
                changed_count = modifierStackLive.setEnabled scene_node target_mods enabled_state
            )
            modifierStackLiveUI.setStatus ((changed_count as string) + " modifier(s) changed.")
            modifierStackLiveUI.refreshFromScene()
        )
        true
    )

    /* Refresh stack selection after a change to the native Modify panel. */
    function requestReadyRefresh =
    (
        callbacks.removeScripts id:#mslWaitPanelReady
        modifierStackLiveUI.refreshFromScene()
        scene_node = modifierStackLive.getSelectedNode()
        if isValidNode scene_node and not (modifierStackLive.isPanelReady scene_node) then
        (
            callbacks.addScript #modPanelObjPostChange "if modifierStackLiveUI != undefined then modifierStackLiveUI.finishReadyRefresh()" id:#mslWaitPanelReady persistent:false
        )
        true
    )

    /* Complete a pending refresh after the native panel becomes ready. */
    function finishReadyRefresh =
    (
        scene_node = modifierStackLive.getSelectedNode()
        if isValidNode scene_node and modifierStackLive.isPanelReady scene_node then
        (
            callbacks.removeScripts id:#mslWaitPanelReady
            modifierStackLiveUI.refreshFromScene()
        )
        true
    )

    /* Keep LIVE STACK as tall as the available dialog height while preserving bottom actions. */
    function fitStackLayout dialog_height =
    (
        if dialog_height < 840 then dialog_height = 840
        sr_stack.height = dialog_height - sr_stack.pos.y - 132
        btn_native.pos = [12, dialog_height - 120]
        btn_refresh.pos = [174, dialog_height - 120]
        btn_on.pos = [12, dialog_height - 84]
        btn_off.pos = [120, dialog_height - 84]
        btn_toggle.pos = [228, dialog_height - 84]
        lbl_status.pos = [12, dialog_height - 40]
        ToolTitleButton.resizeToolTitleButton btn_tool_title (modifierStackLiveUI.width - 24)
        true
    )

    on modifierStackLiveUI open do
    (
        ToolTitleButton.setupToolTitleButton btn_tool_title "Modifier Stack Live"
        addSubRollout sr_stack mslLiveStackRollout
        modifierStackLiveUI.fitStackLayout modifierStackLiveUI.height
        callbacks.removeScripts id:#mslSelectionChanged
        callbacks.removeScripts id:#mslPanelChanged
        callbacks.removeScripts id:#mslModifierAdded
        callbacks.removeScripts id:#mslModifierDeleted
        callbacks.addScript #selectionSetChanged "if modifierStackLiveUI != undefined then modifierStackLiveUI.requestReadyRefresh()" id:#mslSelectionChanged persistent:false
        callbacks.addScript #modPanelSelChanged "if modifierStackLiveUI != undefined then modifierStackLiveUI.finishReadyRefresh()" id:#mslPanelChanged persistent:false
        callbacks.addScript #postModifierAdded "if modifierStackLiveUI != undefined then modifierStackLiveUI.refreshFromScene()" id:#mslModifierAdded persistent:false
        callbacks.addScript #postModifierDeleted "if modifierStackLiveUI != undefined then modifierStackLiveUI.refreshFromScene()" id:#mslModifierDeleted persistent:false
        modifierStackLiveUI.requestReadyRefresh()
    )

    on modifierStackLiveUI moved dialog_pos do
    (
        DialogHost.saveDialogPosition modifierStackLiveUI modifier_stack_live_ini_path "MainUI"
    )

    on modifierStackLiveUI resized dialog_size do
    (
        modifierStackLiveUI.fitStackLayout dialog_size.y
        DialogHost.saveDialogHeight modifierStackLiveUI modifier_stack_live_ini_path "MainUI" min_height:840
    )

    on btn_tool_title Click sender event_args do
    (
        restartTool modifier_stack_live_main_path "Modifier-Stack-Live"
    )

    on modifierStackLiveUI close do
    (
        DialogHost.saveDialogState modifierStackLiveUI modifier_stack_live_ini_path "MainUI" min_height:840
        callbacks.removeScripts id:#mslSelectionChanged
        callbacks.removeScripts id:#mslPanelChanged
        callbacks.removeScripts id:#mslModifierAdded
        callbacks.removeScripts id:#mslModifierDeleted
        callbacks.removeScripts id:#mslWaitPanelReady
    )

    on btn_refresh pressed do (modifierStackLiveUI.refreshFromScene())
    on btn_native pressed do
    (
        scene_node = modifierStackLive.getSelectedNode()
        target_mod = modPanel.getCurrentObject()
        chosen_bits = #{}
        if isValidNode scene_node then
        (
            for index_value = 1 to stack_handles.count do
            (
                candidate_mod = modifierStackLive.resolveHandle scene_node stack_handles[index_value]
                if candidate_mod != undefined and candidate_mod == target_mod then chosen_bits[index_value] = true
            )
        )
        mslLiveStackRollout.lb_stack.selection = chosen_bits
    )
    on btn_on pressed do (modifierStackLiveUI.applyEnabled true)
    on btn_off pressed do (modifierStackLiveUI.applyEnabled false)
    on btn_toggle pressed do (modifierStackLiveUI.applyEnabled #toggle)
)
