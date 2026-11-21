/* Modifier Manager - scoped native modifier parameter editors.
   File version: 0.032 | Project version: 0.032.
*/
global modifierManagerUI
global modifierManager
global mmVolumeRollout
global mmMaterialRollout
global mmPushRollout
global mmSymmetryRollout
global mmMeshSmoothRollout
global mmChamferRollout
global mmSliceRollout
global modifier_manager_project_version
global modifier_manager_file_version_ui = 0.032
global modifier_manager_stored_project_version_ui = 0.032
if modifier_manager_project_version == undefined or modifier_manager_stored_project_version_ui > modifier_manager_project_version then
(
    modifier_manager_project_version = modifier_manager_stored_project_version_ui
)
global modifier_manager_title = "Modifier Manager | v" + (formattedPrint modifier_manager_project_version format:".3f")

/* Remote parameters for existing Volume Select modifiers.
   Values are applied only when the user changes a control.
*/
rollout mmVolumeRollout "Volume Select" height:158
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
        target_mods = modifierManagerUI.getTargets #volume
        level_info = modifierManager.readCommonProperty target_mods #level
        volume_info = modifierManager.readCommonProperty target_mods #volume
        id_info = modifierManager.readCommonProperty target_mods #matID
        fit_info = modifierManager.readCommonProperty target_mods #autofit
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
        modifierManagerUI.applyRemote #volume #level (item_index - 1)
    )

    on ddl_volume selected item_index do
    (
        modifierManagerUI.applyRemote #volume #volume (item_index - 1)
        if item_index == 6 then modifierManagerUI.applyRemote #volume #level 2
    )

    on spn_matid changed new_value do
    (
        modifierManagerUI.applyRemote #volume #matID new_value
    )

    on chk_autofit changed state_value do
    (
        modifierManagerUI.applyRemote #volume #autofit state_value
    )
)

/* Material modifier parameter remote control.
   Material ID is explicit and never derived from a stack index.
*/
rollout mmMaterialRollout "Material" height:75
(
    spinner spn_id "Material ID" pos:[10,8] width:178 range:[1,65535,1] type:#integer fieldWidth:64
    label lbl_state "No Material targets" pos:[10,38] width:270

    /* Read material IDs without modifying native modifier values.
       A mixed selection keeps the first value and shows MIXED.
    */
    function refreshValues =
    (
        target_mods = modifierManagerUI.getTargets #material
        info_value = modifierManager.readCommonProperty target_mods #materialID
        if info_value[2] then spn_id.value = info_value[1]
        lbl_state.text = if target_mods.count == 0 then "No Material targets" else \
            ((target_mods.count as string) + " target(s)" + (if info_value[3] then " | MIXED values" else ""))
        true -- return
    )

    on spn_id changed new_value do
    (
        modifierManagerUI.applyRemote #material #materialID new_value
    )
)

/* Push modifier amount control.
   The native numeric value is measured in scene system units.
*/
rollout mmPushRollout "Push" height:74
(
    spinner spn_amount "Amount" pos:[10,8] width:192 range:[-100000.0,100000.0,0.0] type:#worldunits fieldWidth:72
    label lbl_unit "scene units" pos:[210,10] width:72
    label lbl_state "No Push targets" pos:[10,40] width:270

    /* Display one Push amount or a mixed-state indication.
       Reading never forces a common value on different modifiers.
    */
    function refreshValues =
    (
        target_mods = modifierManagerUI.getTargets #push
        info_value = modifierManager.readCommonProperty target_mods #Push_Value
        if info_value[2] then spn_amount.value = info_value[1]
        lbl_state.text = if target_mods.count == 0 then "No Push targets" else \
            ((target_mods.count as string) + " target(s)" + (if info_value[3] then " | MIXED values" else ""))
        true -- return
    )

    on spn_amount changed new_value do
    (
        modifierManagerUI.applyRemote #push #Push_Value new_value
    )
)

/* Align Symmetry Mirror plane origins in world space without breaking instancing.
   Inputs are explicit targets; changing a spinner alone never edits the scene.
*/
rollout mmSymmetryRollout "Symmetry" height:224
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
        target_mods = modifierManagerUI.getTargets #symmetry
        selected_pairs = modifierManager.getSelectedSymmetryContexts()
        lbl_state.text = ((target_mods.count as string) + " in scope | " + (selected_pairs.count as string) + " across selection")
        true -- return
    )

    /* Load a concrete Mirror origin using the node-specific modifier context. */
    on btn_read pressed do
    (
        scene_node = modifierManager.getSelectedNode()
        source_pairs = #()
        if isValidNode scene_node then
        (
            for target_mod in (modifierManagerUI.getTargets #symmetry) do append source_pairs #(scene_node, target_mod)
        )
        else
        (
            source_pairs = modifierManager.getSelectedSymmetryContexts()
        )
        if source_pairs.count > 0 then
        (
            current_world = modifierManager.getSymmetryWorldPosition source_pairs[1][1] source_pairs[1][2]
            if current_world != undefined then
            (
                spn_x.value = current_world.x
                spn_y.value = current_world.y
                spn_z.value = current_world.z
                modifierManagerUI.setStatus "Read world position from first Symmetry plane."
            )
            else
            (
                modifierManagerUI.setStatus ("Symmetry read failed: " + modifierManager.last_error)
            )
        )
        else
        (
            modifierManagerUI.setStatus "No Symmetry plane in scope or selection."
        )
    )

    /* Align Symmetry modifiers in the existing Selected / Set / Type scope. */
    on btn_align pressed do
    (
        scene_node = modifierManager.getSelectedNode()
        target_pairs = #()
        if isValidNode scene_node then
        (
            for target_mod in (modifierManagerUI.getTargets #symmetry) do append target_pairs #(scene_node, target_mod)
        )
        modifierManagerUI.alignSymmetryPairs target_pairs (mmSymmetryRollout.getWorldTarget()) (mmSymmetryRollout.getPositionPrecision())
    )

    /* Explicitly collect all selected objects rather than requiring one active node. */
    on btn_all pressed do
    (
        target_pairs = modifierManager.getSelectedSymmetryContexts()
        modifierManagerUI.alignSymmetryPairs target_pairs (mmSymmetryRollout.getWorldTarget()) (mmSymmetryRollout.getPositionPrecision())
    )
)


/* Modifier Manager owns the shared parameter subrollout slot.
   All child rollouts originate from the original Modifier Set Stack.
*/
rollout modifierManagerUI modifier_manager_title width:336 height:840
(
    local modifier_handles = #()
    local ui_sync = false
    dotNetControl btn_tool_title "System.Windows.Forms.Button" pos:[12,8] width:312 height:18 tooltip:"LMB: Restart the latest version of this tool."
    label lbl_object "Select one object." pos:[12,36] width:312 height:18
    multiListBox lb_modifiers "MODIFIERS" pos:[12,64] width:312 height:10 items:#()
    button btn_native "Native selection" pos:[12,253] width:150 height:24
    button btn_refresh "Refresh" pos:[174,253] width:150 height:24
    dropdownList ddl_scope "PARAMETER EDIT SCOPE" pos:[12,292] width:312 items:#("Selected", "All of Type") selection:1 tooltip:"Edit selected modifiers or every modifier of the same class on this object."
    subRollout sr_params "" pos:[-4,342] width:344 height:452 scrollBar:#asNeeded
    label lbl_status "Ready." pos:[12,810] width:312 height:18

    /* Display feedback without mutating scene data. */
    function setStatus status_text =
    (
        lbl_status.text = status_text
        true
    )

    /* Test the supported native modifier classes. */
    function matchesType target_mod type_id =
    (
        if target_mod == undefined then return false
        case type_id of
        (
            #volume: (classOf target_mod == VolumeSelect)
            #material: (classOf target_mod == Materialmodifier)
            #push: (classOf target_mod == Push)
            #symmetry: (classOf target_mod == Symmetry)
            #meshsmooth: (classOf target_mod == MeshSmooth)
            #chamfer: (classOf target_mod == Chamfer)
            #slice: (classOf target_mod == SliceModifier)
            #all: true
            default: false
        )
    )

    /* Resolve the selected scope from concrete stack references. */
    function getTargets type_id =
    (
        scene_node = modifierManager.getSelectedNode()
        target_mods = #()
        if isValidNode scene_node then
        (
            if ddl_scope.selection == 2 then
            (
                for target_mod in scene_node.modifiers do
                (
                    if modifierManagerUI.matchesType target_mod type_id then append target_mods target_mod
                )
            )
            else
            (
                for row_index in lb_modifiers.selection do
                (
                    if row_index <= modifier_handles.count then
                    (
                        target_mod = modifierManager.resolveHandle scene_node modifier_handles[row_index]
                        if modifierManagerUI.matchesType target_mod type_id then appendIfUnique target_mods target_mod
                    )
                )
            )
        )
        target_mods
    )

    /* Select the exact newly created modifier in the manager's native stack list. */
    function focusModifier target_mod =
    (
        selected_bits = #{}
        if target_mod != undefined then
        (
            target_handle = getHandleByAnim target_mod
            for row_index = 1 to modifier_handles.count do
            (
                if modifier_handles[row_index] == target_handle then selected_bits[row_index] = true
            )
        )
        lb_modifiers.selection = selected_bits
        modifierManagerUI.refreshEditorValues()
        selected_bits.numberSet > 0 -- return
    )

    /* Update a supported native property only for verified targets. */
    function applyRemote type_id property_name value_data =
    (
        if not ui_sync then
        (
            scene_node = modifierManager.getSelectedNode()
            target_mods = modifierManagerUI.getTargets type_id
            write_count = modifierManager.writeProperty scene_node target_mods property_name value_data
            if type_id == #meshsmooth or type_id == #chamfer then
            (
                for target_mod in target_mods do modifierPresetManager.refreshTaggedPreset type_id target_mod
            )
            modifierManagerUI.setStatus ((write_count as string) + " modifier(s) updated.")
            modifierManagerUI.refreshEditorValues()
        )
        true
    )

    /* Align verified node/modifier Symmetry contexts using the original backend. */
    function alignSymmetryPairs target_pairs world_pos position_precision =
    (
        operation_info = modifierManager.alignSymmetryPlanes target_pairs world_pos position_precision
        if operation_info[3] then
        (
            modifierManagerUI.setStatus ((operation_info[1] as string) + " Symmetry plane(s) aligned.")
        )
        else
        (
            modifierManagerUI.setStatus ("Symmetry alignment failed: " + modifierManager.last_error)
        )
        modifierManagerUI.refreshEditorValues()
        operation_info[3]
    )

    /* Load parameter readouts without writing values back to modifiers. */
    function refreshEditorValues =
    (
        ui_sync = true
        mmVolumeRollout.refreshValues()
        mmMaterialRollout.refreshValues()
        mmPushRollout.refreshValues()
        mmSymmetryRollout.refreshValues()
        mmMeshSmoothRollout.refreshValues()
        mmChamferRollout.refreshValues()
        mmSliceRollout.refreshValues()
        ui_sync = false
        true
    )

    /* Keep real modifier selection stable across a refresh. */
    function refreshFromScene =
    (
        if not ui_sync then
        (
            ui_sync = true
            selected_handles = #()
            for row_index in lb_modifiers.selection do
            (
                if row_index <= modifier_handles.count then append selected_handles modifier_handles[row_index]
            )
            modifier_handles = #()
            modifier_items = #()
            scene_node = modifierManager.getSelectedNode()
            if isValidNode scene_node then
            (
                lbl_object.text = scene_node.name
                for target_mod in scene_node.modifiers do
                (
                    append modifier_handles (getHandleByAnim target_mod)
                    append modifier_items (target_mod.name + " (" + (classOf target_mod as string) + ")")
                )
            )
            else
            (
                lbl_object.text = "Select exactly one object."
            )
            lb_modifiers.items = modifier_items
            selected_bits = #{}
            for row_index = 1 to modifier_handles.count do
            (
                if findItem selected_handles modifier_handles[row_index] > 0 then selected_bits[row_index] = true
            )
            lb_modifiers.selection = selected_bits
            ui_sync = false
            modifierManagerUI.refreshEditorValues()
        )
        true
    )

    /* Refresh after selection changes and wait for the Modify panel if needed. */
    function requestReadyRefresh =
    (
        callbacks.removeScripts id:#mmWaitPanelReady
        modifierManagerUI.refreshFromScene()
        scene_node = modifierManager.getSelectedNode()
        if isValidNode scene_node and not (modifierManager.isPanelReady scene_node) then
        (
            callbacks.addScript #modPanelObjPostChange "if modifierManagerUI != undefined then modifierManagerUI.finishReadyRefresh()" id:#mmWaitPanelReady persistent:false
        )
        true
    )

    /* Complete panel-dependent refresh if the native panel is ready. */
    function finishReadyRefresh =
    (
        scene_node = modifierManager.getSelectedNode()
        if isValidNode scene_node and modifierManager.isPanelReady scene_node then
        (
            callbacks.removeScripts id:#mmWaitPanelReady
            modifierManagerUI.refreshFromScene()
        )
        true
    )

    /* Fit the subrollout container to the remaining dialog height. */
    function fitSubrolloutSlot dialog_height =
    (
        slot_height = dialog_height - sr_params.pos.y - 46
        if slot_height < 242 then slot_height = 242
        sr_params.height = slot_height
        lbl_status.pos = [12, dialog_height - 30]
        ToolTitleButton.resizeToolTitleButton btn_tool_title (modifierManagerUI.width - 24)
        true
    )

    /* Restore UI-only scope and comparison precision without modifying native modifiers. */
    function restoreUiState =
    (
        RolloutState.loadDropdown ddl_scope modifier_manager_ini_path "MainUI" "EditScope" default_value:1
        RolloutState.loadDropdown mmSymmetryRollout.ddl_precision modifier_manager_ini_path "Symmetry" "PositionPrecision" default_value:3
        true
    )

    on modifierManagerUI open do
    (
        ToolTitleButton.setupToolTitleButton btn_tool_title "Modifier Manager"
        addSubRollout sr_params mmVolumeRollout
        addSubRollout sr_params mmMaterialRollout
        addSubRollout sr_params mmPushRollout
        addSubRollout sr_params mmSymmetryRollout
        addSubRollout sr_params mmMeshSmoothRollout
        addSubRollout sr_params mmChamferRollout
        addSubRollout sr_params mmSliceRollout
        callbacks.removeScripts id:#mmSelectionChanged
        callbacks.removeScripts id:#mmPanelChanged
        callbacks.removeScripts id:#mmModifierAdded
        callbacks.removeScripts id:#mmModifierDeleted
        callbacks.addScript #selectionSetChanged "if modifierManagerUI != undefined then modifierManagerUI.requestReadyRefresh()" id:#mmSelectionChanged persistent:false
        callbacks.addScript #modPanelSelChanged "if modifierManagerUI != undefined then modifierManagerUI.finishReadyRefresh()" id:#mmPanelChanged persistent:false
        callbacks.addScript #postModifierAdded "if modifierManagerUI != undefined then modifierManagerUI.refreshFromScene()" id:#mmModifierAdded persistent:false
        callbacks.addScript #postModifierDeleted "if modifierManagerUI != undefined then modifierManagerUI.refreshFromScene()" id:#mmModifierDeleted persistent:false
        modifierManagerUI.restoreUiState()
        modifierManagerUI.fitSubrolloutSlot modifierManagerUI.height
        modifierManagerUI.requestReadyRefresh()
    )

    on modifierManagerUI moved dialog_pos do
    (
        DialogHost.saveDialogPosition modifierManagerUI modifier_manager_ini_path "MainUI"
    )

    on modifierManagerUI resized dialog_size do
    (
        modifierManagerUI.fitSubrolloutSlot dialog_size.y
        DialogHost.saveDialogHeight modifierManagerUI modifier_manager_ini_path "MainUI" min_height:840
    )

    on btn_tool_title Click sender event_args do
    (
        restartTool modifier_manager_main_path "Modifier-Manager"
    )

    on modifierManagerUI close do
    (
        RolloutState.saveDropdown ddl_scope modifier_manager_ini_path "MainUI" "EditScope"
        RolloutState.saveDropdown mmSymmetryRollout.ddl_precision modifier_manager_ini_path "Symmetry" "PositionPrecision"
        DialogHost.saveDialogState modifierManagerUI modifier_manager_ini_path "MainUI" min_height:840
        callbacks.removeScripts id:#mmSelectionChanged
        callbacks.removeScripts id:#mmPanelChanged
        callbacks.removeScripts id:#mmModifierAdded
        callbacks.removeScripts id:#mmModifierDeleted
        callbacks.removeScripts id:#mmWaitPanelReady
    )

    on lb_modifiers selected item_index do
    (
        if not ui_sync then modifierManagerUI.refreshEditorValues()
    )
    on ddl_scope selected item_index do
    (
        RolloutState.saveDropdown ddl_scope modifier_manager_ini_path "MainUI" "EditScope"
        if not ui_sync then modifierManagerUI.refreshEditorValues()
    )
    on btn_refresh pressed do
    (
        modifierSliceManager.clearCache()
        modifierManagerUI.refreshFromScene()
    )
    on btn_native pressed do
    (
        scene_node = modifierManager.getSelectedNode()
        target_mod = modPanel.getCurrentObject()
        selected_bits = #{}
        if isValidNode scene_node then
        (
            for row_index = 1 to modifier_handles.count do
            (
                candidate_mod = modifierManager.resolveHandle scene_node modifier_handles[row_index]
                if candidate_mod != undefined and candidate_mod == target_mod then selected_bits[row_index] = true
            )
        )
        lb_modifiers.selection = selected_bits
        modifierManagerUI.refreshEditorValues()
    )
)

