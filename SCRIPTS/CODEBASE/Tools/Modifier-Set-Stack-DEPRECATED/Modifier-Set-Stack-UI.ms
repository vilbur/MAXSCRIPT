/* Modifier Set Stack - standalone remote control UI.
   File version: 0.021 | Project version: 0.087 | Prototype.
*/

global modifier_set_stack_project_version
global modifier_set_stack_file_version_ui = 0.021
global modifier_set_stack_stored_project_version_ui = 0.087
global modifierSetStack
global modifierSetStackUI
global mssLiveStackRollout
global mssVolumeRollout
global mssMaterialRollout
global mssPushRollout
global mssSymmetryRollout

if modifier_set_stack_project_version == undefined or modifier_set_stack_stored_project_version_ui > modifier_set_stack_project_version then
(
    modifier_set_stack_project_version = modifier_set_stack_stored_project_version_ui
)

/* Remote parameters for existing Volume Select modifiers.
   Values are applied only when the user changes a control.
*/
rollout mssVolumeRollout "Volume Select" height:158
(
    dropdownList ddl_level "Selection level" items:#("Object", "Vertex", "Face") pos:[10,8] width:260
    dropdownList ddl_volume "Select by" items:#("Box", "Sphere", "Cylinder", "Mesh Object", "Texture Map", "Material ID", "Smoothing Group") pos:[10,53] width:260
    spinner spn_matid "Material ID" pos:[10,101] width:170 range:[1,65535,1] type:#integer fieldWidth:64
    checkbox chk_autofit "Auto Fit" pos:[188,105]
    label lbl_state "No Volume Select targets" pos:[10,133] width:270

    /* Load only common parameter values for the chosen scope.
       Mixed values are reported without overwriting existing modifiers.
    */
    function refreshValues =
    (
        target_mods = modifierSetStackUI.getTargets #volume
        level_info = modifierSetStack.readCommonProperty target_mods #level
        volume_info = modifierSetStack.readCommonProperty target_mods #volume
        id_info = modifierSetStack.readCommonProperty target_mods #matID
        fit_info = modifierSetStack.readCommonProperty target_mods #autofit
        mixed_value = false

        if level_info[2] then
        (
            ddl_level.selection = (level_info[1] + 1)
            mixed_value = mixed_value or level_info[3]
        )

        if volume_info[2] then
        (
            ddl_volume.selection = (volume_info[1] + 1)
            mixed_value = mixed_value or volume_info[3]
        )

        if id_info[2] then
        (
            spn_matid.value = id_info[1]
            mixed_value = mixed_value or id_info[3]
        )

        if fit_info[2] then
        (
            chk_autofit.checked = fit_info[1]
            mixed_value = mixed_value or fit_info[3]
        )

        lbl_state.text = if target_mods.count == 0 then "No Volume Select targets" else \
            ((target_mods.count as string) + " target(s)" + (if mixed_value then " | MIXED values" else ""))
        true -- return
    )

    on ddl_level selected item_index do
    (
        modifierSetStackUI.applyRemote #volume #level (item_index - 1)
    )

    on ddl_volume selected item_index do
    (
        modifierSetStackUI.applyRemote #volume #volume (item_index - 1)
        if item_index == 6 then modifierSetStackUI.applyRemote #volume #level 2
    )

    on spn_matid changed new_value do
    (
        modifierSetStackUI.applyRemote #volume #matID new_value
    )

    on chk_autofit changed state_value do
    (
        modifierSetStackUI.applyRemote #volume #autofit state_value
    )
)

/* Material modifier parameter remote control.
   Material ID is explicit and never derived from a stack index.
*/
rollout mssMaterialRollout "Material" height:75
(
    spinner spn_id "Material ID" pos:[10,8] width:178 range:[1,65535,1] type:#integer fieldWidth:64
    label lbl_state "No Material targets" pos:[10,38] width:270

    /* Read material IDs without modifying native modifier values.
       A mixed selection keeps the first value and shows MIXED.
    */
    function refreshValues =
    (
        target_mods = modifierSetStackUI.getTargets #material
        info_value = modifierSetStack.readCommonProperty target_mods #materialID
        if info_value[2] then spn_id.value = info_value[1]
        lbl_state.text = if target_mods.count == 0 then "No Material targets" else \
            ((target_mods.count as string) + " target(s)" + (if info_value[3] then " | MIXED values" else ""))
        true -- return
    )

    on spn_id changed new_value do
    (
        modifierSetStackUI.applyRemote #material #materialID new_value
    )
)

/* Push modifier amount control.
   The native numeric value is measured in scene system units.
*/
rollout mssPushRollout "Push" height:74
(
    spinner spn_amount "Amount" pos:[10,8] width:192 range:[-100000.0,100000.0,0.0] type:#worldunits fieldWidth:72
    label lbl_unit "scene units" pos:[210,10] width:72
    label lbl_state "No Push targets" pos:[10,40] width:270

    /* Display one Push amount or a mixed-state indication.
       Reading never forces a common value on different modifiers.
    */
    function refreshValues =
    (
        target_mods = modifierSetStackUI.getTargets #push
        info_value = modifierSetStack.readCommonProperty target_mods #Push_Value
        if info_value[2] then spn_amount.value = info_value[1]
        lbl_state.text = if target_mods.count == 0 then "No Push targets" else \
            ((target_mods.count as string) + " target(s)" + (if info_value[3] then " | MIXED values" else ""))
        true -- return
    )

    on spn_amount changed new_value do
    (
        modifierSetStackUI.applyRemote #push #Push_Value new_value
    )
)

/* Align Symmetry Mirror plane origins in world space without breaking instancing.
   Inputs are explicit targets; changing a spinner alone never edits the scene.
*/
rollout mssSymmetryRollout "Symmetry" height:224
(
    spinner spn_x "World X" pos:[10,8] width:188 range:[-100000000.0,100000000.0,0.0] type:#worldunits fieldWidth:82 scale:0.1
    label lbl_x_unit "scene units" pos:[205,10] width:75
    spinner spn_y "World Y" pos:[10,38] width:188 range:[-100000000.0,100000000.0,0.0] type:#worldunits fieldWidth:82 scale:0.1
    label lbl_y_unit "scene units" pos:[205,40] width:75
    spinner spn_z "World Z" pos:[10,68] width:188 range:[-100000000.0,100000000.0,0.0] type:#worldunits fieldWidth:82 scale:0.1
    label lbl_z_unit "scene units" pos:[205,70] width:75
    dropdownList ddl_precision "postion preccision" pos:[10,102] width:270 items:#("1mm", "0.1mm", "0.01mm") selection:3 tooltip:"Position comparison precision after alignment; coordinates are not rounded."
    button btn_read "Read first plane" pos:[10,144] width:132 height:24 tooltip:"Load the first target Mirror origin in world coordinates without editing the scene."
    button btn_align "Align scope" pos:[148,144] width:132 height:24 tooltip:"Move scoped Symmetry planes to the entered world position without breaking modifier instances."
    button btn_all "All selected objects" pos:[10,175] width:270 height:24 tooltip:"Align every Symmetry plane on every selected object, including instanced modifiers."
    label lbl_state "No Symmetry targets" pos:[10,204] width:274 height:18

    /* Convert the explicitly chosen millimeter precision into system units.
       The value is used only for verifying the final plane position.
    */
    function getPositionPrecision =
    (
        precision_value = case ddl_precision.selection of
        (
            1: (units.decodeValue "1mm")
            2: (units.decodeValue "0.1mm")
            default: (units.decodeValue "0.01mm")
        )
        precision_value -- return
    )

    /* Return the target Point3 without formatting or rounding any spinner values. */
    function getWorldTarget =
    (
        [spn_x.value, spn_y.value, spn_z.value] -- return
    )

    /* Refresh only the target count; do not replace user-entered world coordinates. */
    function refreshValues =
    (
        target_mods = modifierSetStackUI.getTargets #symmetry
        selected_pairs = modifierSetStack.getSelectedSymmetryContexts()
        lbl_state.text = ((target_mods.count as string) + " in scope | " + (selected_pairs.count as string) + " across selection")
        true -- return
    )

    /* Load a concrete Mirror origin using the node-specific modifier context. */
    on btn_read pressed do
    (
        scene_node = modifierSetStack.getSelectedNode()
        source_pairs = #()
        if isValidNode scene_node then
        (
            for target_mod in (modifierSetStackUI.getTargets #symmetry) do append source_pairs #(scene_node, target_mod)
        )
        else
        (
            source_pairs = modifierSetStack.getSelectedSymmetryContexts()
        )
        if source_pairs.count > 0 then
        (
            current_world = modifierSetStack.getSymmetryWorldPosition source_pairs[1][1] source_pairs[1][2]
            if current_world != undefined then
            (
                spn_x.value = current_world.x
                spn_y.value = current_world.y
                spn_z.value = current_world.z
                modifierSetStackUI.setStatus "Read world position from first Symmetry plane."
            )
            else
            (
                modifierSetStackUI.setStatus ("Symmetry read failed: " + modifierSetStack.last_error)
            )
        )
        else
        (
            modifierSetStackUI.setStatus "No Symmetry plane in scope or selection."
        )
    )

    /* Align Symmetry modifiers in the existing Selected / Set / Type scope. */
    on btn_align pressed do
    (
        scene_node = modifierSetStack.getSelectedNode()
        target_pairs = #()
        if isValidNode scene_node then
        (
            for target_mod in (modifierSetStackUI.getTargets #symmetry) do append target_pairs #(scene_node, target_mod)
        )
        modifierSetStackUI.alignSymmetryPairs target_pairs (mssSymmetryRollout.getWorldTarget()) (mssSymmetryRollout.getPositionPrecision())
    )

    /* Explicitly collect all selected objects rather than requiring one active node. */
    on btn_all pressed do
    (
        target_pairs = modifierSetStack.getSelectedSymmetryContexts()
        modifierSetStackUI.alignSymmetryPairs target_pairs (mssSymmetryRollout.getWorldTarget()) (mssSymmetryRollout.getPositionPrecision())
    )
)

/* Display thirty real modifier rows in a dedicated, independently scrollable rollout.
   The owning rollout maintains stack handles and all editing behavior.
*/
rollout mssLiveStackRollout "LIVE STACK" width:294 height:620
(
    multiListBox lb_stack "" pos:[10,8] width:270 height:30 items:#()

    on lb_stack selected item_index do
    (
        modifierSetStackUI.onLiveStackSelected()
    )
)

/* Select and edit real modifiers without navigating the native TreeView.
   Multiselection is managed in this independent list; native active modifier is importable.
*/
global modifier_set_stack_rollout_title = "Modifier Set Stack | v" + (formattedPrint modifier_set_stack_project_version format:".3f")
rollout modifierSetStackUI modifier_set_stack_rollout_title width:640 height:775
(
    local stack_handles = #()
    local set_ids = #()
    local member_handles = #()
    local ui_sync = false

    label lbl_object "Select one object to start." pos:[10,8] width:294
    subRollout sr_stack "" pos:[10,29] width:294 height:648 scrollBar:#asNeeded
    button btn_native "Use Active Native Modifier" pos:[10,690] width:144 height:24 tooltip:"Select the active modifier from the native Modify panel in the remote list."
    button btn_refresh "Refresh" pos:[160,690] width:144 height:24 tooltip:"Rebuild the list from the actual object's modifier stack."

    listBox lb_sets "SETS" pos:[330,8] width:294 height:6 items:#()
    editText txt_set "Set name" pos:[330,129] width:294 text:""
    button btn_add_set "+ Set" pos:[330,157] width:92 height:23
    button btn_rename_set "Rename" pos:[431,157] width:92 height:23
    button btn_delete_set "Delete Set" pos:[532,157] width:92 height:23
    multiListBox lb_members "SET MEMBERS" pos:[330,190] width:294 height:5 items:#()
    button btn_assign "Assign selected" pos:[330,295] width:144 height:24 tooltip:"Assign selected LIVE STACK modifiers to this set without changing stack order."
    button btn_ungroup "Ungroup selected" pos:[480,295] width:144 height:24 tooltip:"Remove selected SET MEMBERS from their set without deleting modifiers."
    button btn_on "ON" pos:[330,326] width:92 height:24
    button btn_off "OFF" pos:[431,326] width:92 height:24
    button btn_toggle "Toggle" pos:[532,326] width:92 height:24
    dropdownList ddl_scope "PARAMETER EDIT SCOPE" pos:[330,358] width:294 items:#("Selected", "Current Set", "All of Type") selection:1 tooltip:"Selected edits checked remote-list items. Current Set edits members. All of Type edits every matching modifier on this object."
    subRollout sr_params "" pos:[330,414] width:294 height:318 scrollBar:#asNeeded
    label lbl_status "Ready." pos:[10,744] width:614 height:22

    /* Show status feedback without altering the scene.
       Messages also appear in MAXScript Listener for diagnostics.
    */
    function setStatus status_text =
    (
        lbl_status.text = status_text
        format "Modifier Set Stack: %\n" status_text
        true -- return
    )

    /* Return a checked row's valid real modifier from its AnimHandle.
       This does not assume a TreeView index equals a stack index.
    */
    function getStackRowMod row_index =
    (
        result_mod = undefined
        scene_node = modifierSetStack.getSelectedNode()
        if row_index > 0 and row_index <= stack_handles.count then
        (
            result_mod = modifierSetStack.resolveHandle scene_node stack_handles[row_index]
        )
        result_mod -- return
    )

    /* Clear competing member selection after a LIVE STACK selection change.
       The list is hosted by a child rollout but scope editing remains unchanged.
    */
    function onLiveStackSelected =
    (
        if not ui_sync then
        (
            lb_members.selection = #{}
            modifierSetStackUI.refreshEditorValues()
        )
        true -- return
    )

    /* Resolve the currently selected group ID, including zero Ungrouped.
       Missing selection is undefined and never interpreted as group zero.
    */
    function getSelectedGroupId =
    (
        group_id = undefined
        if lb_sets.selection > 0 and lb_sets.selection <= set_ids.count then
        (
            group_id = set_ids[lb_sets.selection]
        )
        group_id -- return
    )

    /* Classify modifier references using native MAXScript class objects.
       Other modifier classes remain visible but cannot use typed editors yet.
    */
    function matchesType target_mod type_id =
    (
        is_match = false

        if target_mod != undefined then
        (
            is_match = case type_id of
            (
                #volume: (classOf target_mod == VolumeSelect)
                #material: (classOf target_mod == Materialmodifier)
                #push: (classOf target_mod == Push)
                #symmetry: (classOf target_mod == Symmetry)
                #all: true
                default: false
            )
        )

        is_match -- return
    )

    /* Collect the remote scope from the real stack and saved memberships.
       The Selected scope prefers member-list selection, otherwise stack-list selection.
    */
    function getTargets type_id =
    (
        target_mods = #()
        source_mods = #()
        scene_node = modifierSetStack.getSelectedNode()

        if isValidNode scene_node then
        (
            case ddl_scope.selection of
            (
                1:
                (
                    if lb_members.selection.numberSet > 0 then
                    (
                        for row_index in lb_members.selection do
                        (
                            if row_index <= member_handles.count then
                            (
                                target_mod = modifierSetStack.resolveHandle scene_node member_handles[row_index]
                                if target_mod != undefined then appendIfUnique source_mods target_mod
                            )
                        )
                    )
                    else
                    (
                        for row_index in mssLiveStackRollout.lb_stack.selection do
                        (
                            target_mod = modifierSetStackUI.getStackRowMod row_index
                            if target_mod != undefined then appendIfUnique source_mods target_mod
                        )
                    )
                )
                2:
                (
                    group_id = modifierSetStackUI.getSelectedGroupId()
                    if group_id != undefined then source_mods = modifierSetStack.getGroupModifiers scene_node group_id
                )
                3:
                (
                    source_mods = for target_mod in scene_node.modifiers collect target_mod
                )
            )

            for target_mod in source_mods do
            (
                if modifierSetStackUI.matchesType target_mod type_id then
                (
                    append target_mods target_mod
                )
            )
        )

        target_mods -- return
    )

    /* Write a native parameter to matching modifiers and refresh readouts.
       A mixed source state remains unchanged unless a user explicitly edits it.
    */
    function applyRemote type_id property_name value_data =
    (
        if not ui_sync then
        (
            scene_node = modifierSetStack.getSelectedNode()
            target_mods = modifierSetStackUI.getTargets type_id
            write_count = modifierSetStack.writeProperty scene_node target_mods property_name value_data
            modifierSetStackUI.setStatus ((write_count as string) + " modifier(s) updated.")
            modifierSetStackUI.refreshEditorValues()
        )
        true -- return
    )

    /* Apply the selected world point to all concrete node/modifier pairs.
       The backend rolls back unsuccessful batches; scene selection is untouched.
    */
    function alignSymmetryPairs target_pairs world_pos position_precision =
    (
        operation_info = modifierSetStack.alignSymmetryPlanes target_pairs world_pos position_precision
        if operation_info[3] then
        (
            modifierSetStackUI.setStatus ((operation_info[1] as string) + " Symmetry plane(s) aligned in world.")
        )
        else
        (
            modifierSetStackUI.setStatus ("Symmetry alignment failed: " + modifierSetStack.last_error)
        )
        modifierSetStackUI.refreshEditorValues()
        operation_info[3] -- return
    )

    /* Read all remote controls while preventing generated value-change writes.
       Other modifier types are ignored without side effects.
    */
    function refreshEditorValues =
    (
        ui_sync = true
        mssVolumeRollout.refreshValues()
        mssMaterialRollout.refreshValues()
        mssPushRollout.refreshValues()
        mssSymmetryRollout.refreshValues()
        ui_sync = false
        true -- return
    )

    /* Rebuild real stack handles, groups, and grouped member handles.
       Preserve checked LIVE STACK rows by their transient AnimHandles.
    */
    function refreshFromScene =
    (
        if not ui_sync then
        (
            ui_sync = true
            old_stack_selected = #()
            for row_index in mssLiveStackRollout.lb_stack.selection do
            (
                if row_index <= stack_handles.count then append old_stack_selected stack_handles[row_index]
            )
            old_group_id = modifierSetStackUI.getSelectedGroupId()
            scene_node = modifierSetStack.getSelectedNode()
            stack_items = #()
            stack_handles = #()
            set_items = #("Ungrouped")
            set_ids = #(0)
            member_handles = #()

            if isValidNode scene_node then
            (
                lbl_object.text = scene_node.name
                modifierSetStack.cleanStaleRecords()

                for index_value = 1 to scene_node.modifiers.count do
                (
                    target_mod = scene_node.modifiers[index_value]
                    append stack_handles (getHandleByAnim target_mod)
                    append stack_items ((index_value as string) + "  " + target_mod.name + " (" + (classOf target_mod as string) + ")")
                )

                store_value = modifierSetStack.getStore()
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

            mssLiveStackRollout.lb_stack.items = stack_items
            selection_bits = #{}
            for index_value = 1 to stack_handles.count do
            (
                if (findItem old_stack_selected stack_handles[index_value]) > 0 then selection_bits[index_value] = true
            )
            mssLiveStackRollout.lb_stack.selection = selection_bits
            lb_sets.items = set_items
            new_set_index = 1
            for index_value = 1 to set_ids.count do
            (
                if set_ids[index_value] == old_group_id then new_set_index = index_value
            )
            lb_sets.selection = new_set_index
            ui_sync = false
            modifierSetStackUI.refreshMembers()
        )
        true -- return
    )

    /* Update the selected group's member list from valid actual modifiers.
       The member rows never include gizmo, center, or UI TreeView items.
    */
    function refreshMembers =
    (
        if not ui_sync then
        (
            ui_sync = true
            scene_node = modifierSetStack.getSelectedNode()
            group_id = modifierSetStackUI.getSelectedGroupId()
            member_items = #()
            member_handles = #()

            if isValidNode scene_node and group_id != undefined then
            (
                target_mods = modifierSetStack.getGroupModifiers scene_node group_id
                for target_mod in target_mods do
                (
                    append member_items (target_mod.name + " (" + (classOf target_mod as string) + ")")
                    append member_handles (getHandleByAnim target_mod)
                )

                store_value = modifierSetStack.getStore()
                if group_id == 0 then txt_set.text = "" else txt_set.text = store_value.group_names[group_id]
            )
            lb_members.items = member_items
            lb_members.selection = #{}
            ui_sync = false
            modifierSetStackUI.refreshEditorValues()
        )
        true -- return
    )

    /* Apply enabled-state changes to selected modifier targets.
       Current Set mode additionally stores its set activation flag.
    */
    function applyEnabled state_value =
    (
        scene_node = modifierSetStack.getSelectedNode()
        target_mods = modifierSetStackUI.getTargets #all
        changed_count = 0

        if isValidNode scene_node then
        (
            undo "Modifier Set Stack enabled" on
            (
                changed_count = modifierSetStack.setEnabled scene_node target_mods state_value
            )

            if ddl_scope.selection == 2 and state_value != #toggle then
            (
                group_id = modifierSetStackUI.getSelectedGroupId()
                store_value = modifierSetStack.getStore()
                if store_value != undefined and group_id != undefined and group_id > 0 then
                (
                    store_value.group_enabled[group_id] = state_value
                )
            )
        )

        modifierSetStackUI.setStatus ((changed_count as string) + " modifier(s) enabled state changed.")
        true -- return
    )

    /* Refresh only after the native Modify panel has resolved the new node.
       This imports the source's deferred #modPanelObjPostChange pattern.
    */
    function requestReadyRefresh =
    (
        scene_node = modifierSetStack.getSelectedNode()
        callbacks.removeScripts id:#mssWaitPanelReady

        modifierSetStackUI.refreshFromScene()

        if not (isValidNode scene_node) then
        (
            modifierSetStack.active_node = undefined
        )
        else
        (
            modifierSetStack.active_node = scene_node
            if not (modifierSetStack.isPanelReady scene_node) then
            (
                callbacks.addScript #modPanelObjPostChange "if modifierSetStackUI != undefined then modifierSetStackUI.finishReadyRefresh()" id:#mssWaitPanelReady persistent:false
            )
        )
        true -- return
    )

    /* Complete deferred refresh when the panel belongs to the selected node.
       Stale callbacks are ignored and removed on a later selection change.
    */
    function finishReadyRefresh =
    (
        scene_node = modifierSetStack.getSelectedNode()
        if isValidNode scene_node and modifierSetStack.isPanelReady scene_node then
        (
            callbacks.removeScripts id:#mssWaitPanelReady
            modifierSetStackUI.refreshFromScene()
        )
        true -- return
    )

    on modifierSetStackUI open do
    (
        addSubRollout sr_stack mssLiveStackRollout
        addSubRollout sr_params mssVolumeRollout
        addSubRollout sr_params mssMaterialRollout
        addSubRollout sr_params mssPushRollout
        addSubRollout sr_params mssSymmetryRollout

        callbacks.removeScripts id:#mssSelectionChanged
        callbacks.removeScripts id:#mssPanelChanged
        callbacks.removeScripts id:#mssModifierAdded
        callbacks.removeScripts id:#mssModifierDeleted
        callbacks.removeScripts id:#mssWaitPanelReady
        callbacks.addScript #selectionSetChanged "if modifierSetStackUI != undefined then modifierSetStackUI.requestReadyRefresh()" id:#mssSelectionChanged persistent:false
        callbacks.addScript #modPanelSelChanged "if modifierSetStackUI != undefined then modifierSetStackUI.finishReadyRefresh()" id:#mssPanelChanged persistent:false
        callbacks.addScript #postModifierAdded "if modifierSetStackUI != undefined then modifierSetStackUI.refreshFromScene()" id:#mssModifierAdded persistent:false
        callbacks.addScript #postModifierDeleted "if modifierSetStackUI != undefined then modifierSetStackUI.refreshFromScene()" id:#mssModifierDeleted persistent:false
        modifierSetStackUI.requestReadyRefresh()
    )

    on modifierSetStackUI close do
    (
        callbacks.removeScripts id:#mssSelectionChanged
        callbacks.removeScripts id:#mssPanelChanged
        callbacks.removeScripts id:#mssModifierAdded
        callbacks.removeScripts id:#mssModifierDeleted
        callbacks.removeScripts id:#mssWaitPanelReady
    )

    on btn_refresh pressed do
    (
        modifierSetStackUI.refreshFromScene()
    )

    on btn_native pressed do
    (
        scene_node = modifierSetStack.getSelectedNode()
        active_mod = modPanel.getCurrentObject()
        chosen_bits = #{}
        if isValidNode scene_node then
        (
            for index_value = 1 to stack_handles.count do
            (
                target_mod = modifierSetStack.resolveHandle scene_node stack_handles[index_value]
                if target_mod != undefined and target_mod == active_mod then chosen_bits[index_value] = true
            )
        )
        lb_members.selection = #{}
        mssLiveStackRollout.lb_stack.selection = chosen_bits
        modifierSetStackUI.refreshEditorValues()
    )

    on lb_members selected item_index do
    (
        if not ui_sync then modifierSetStackUI.refreshEditorValues()
    )

    on lb_sets selected item_index do
    (
        if not ui_sync then modifierSetStackUI.refreshMembers()
    )

    on ddl_scope selected item_index do
    (
        if not ui_sync then modifierSetStackUI.refreshEditorValues()
    )

    on btn_add_set pressed do
    (
        new_group_id = modifierSetStack.addGroup txt_set.text
        modifierSetStackUI.refreshFromScene()
        if new_group_id > 0 then
        (
            for item_index = 1 to set_ids.count do
            (
                if set_ids[item_index] == new_group_id then lb_sets.selection = item_index
            )
            modifierSetStackUI.refreshMembers()
            modifierSetStackUI.setStatus "Set created or selected."
        )
        else
        (
            modifierSetStackUI.setStatus "Enter a nonempty set name."
        )
    )

    on btn_rename_set pressed do
    (
        group_id = modifierSetStackUI.getSelectedGroupId()
        success_value = false
        if group_id != undefined and group_id > 0 then success_value = modifierSetStack.renameGroup group_id txt_set.text
        modifierSetStackUI.refreshFromScene()
        if success_value then modifierSetStackUI.setStatus "Set renamed." else modifierSetStackUI.setStatus "Choose a named set and a unique new name."
    )

    on btn_delete_set pressed do
    (
        group_id = modifierSetStackUI.getSelectedGroupId()
        success_value = false
        if group_id != undefined and group_id > 0 then success_value = modifierSetStack.deleteGroup group_id
        modifierSetStackUI.refreshFromScene()
        if success_value then modifierSetStackUI.setStatus "Set removed. Modifiers are untouched." else modifierSetStackUI.setStatus "Choose a named set."
    )

    on btn_assign pressed do
    (
        scene_node = modifierSetStack.getSelectedNode()
        group_id = modifierSetStackUI.getSelectedGroupId()
        changed_count = 0
        if isValidNode scene_node and group_id != undefined then
        (
            for row_index in mssLiveStackRollout.lb_stack.selection do
            (
                target_mod = modifierSetStackUI.getStackRowMod row_index
                if modifierSetStack.assignGroup scene_node target_mod group_id then changed_count += 1
            )
        )
        modifierSetStackUI.refreshFromScene()
        modifierSetStackUI.setStatus ((changed_count as string) + " modifier(s) assigned.")
    )

    on btn_ungroup pressed do
    (
        scene_node = modifierSetStack.getSelectedNode()
        changed_count = 0
        if isValidNode scene_node then
        (
            for row_index in lb_members.selection do
            (
                if row_index <= member_handles.count then
                (
                    target_mod = modifierSetStack.resolveHandle scene_node member_handles[row_index]
                    if modifierSetStack.assignGroup scene_node target_mod 0 then changed_count += 1
                )
            )
        )
        modifierSetStackUI.refreshFromScene()
        modifierSetStackUI.setStatus ((changed_count as string) + " modifier(s) ungrouped.")
    )

    on btn_on pressed do (modifierSetStackUI.applyEnabled true)
    on btn_off pressed do (modifierSetStackUI.applyEnabled false)
    on btn_toggle pressed do (modifierSetStackUI.applyEnabled #toggle)
)
