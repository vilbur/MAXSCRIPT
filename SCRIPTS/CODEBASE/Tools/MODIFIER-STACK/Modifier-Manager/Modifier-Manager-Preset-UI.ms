/*
Modifier Manager reusable preset list and native MeshSmooth / Chamfer editors.
File version: 0.011 | Project version: 0.011.
*/
global modifier_manager_project_version
global modifierManagerUI
if modifier_manager_project_version == undefined or modifier_manager_project_version < 0.011 then modifier_manager_project_version = 0.011
global mmMeshSmoothRollout
global mmChamferRollout
global mm_mesh_preset_list
global mm_chamfer_preset_list

/*
The shared list controller maps display rows to stable scene preset IDs.
Both modifier rollouts use exactly the same Save, Load, Add, and Re-instance behavior.
*/
struct modifierPresetList_v
(
    type_id = #undefined,
    row_ids = #(),

    /* Refresh a native listbox while preserving its selected preset ID. */
    function refreshList list_control =
    (
        selected_id = this.getSelectedId list_control
        rows = modifierPresetManager.getPresetRows type_id
        row_ids = for row_data in rows collect row_data[1]
        list_control.items = for row_data in rows collect row_data[2]
        selected_index = findItem row_ids selected_id
        list_control.selection = selected_index
        rows.count -- return
    ),

    /* Resolve the currently highlighted item into its stable scene ID. */
    function getSelectedId list_control =
    (
        row_index = list_control.selection
        if row_index > 0 and row_index <= row_ids.count then row_ids[row_index] else 0
        -- return
    ),

    /* Save typed editor values, optionally tagging an existing native modifier. */
    function saveValues list_control setting_values source_mod =
    (
        new_id = modifierPresetManager.savePreset type_id setting_values source_mod
        if new_id > 0 then
        (
            this.refreshList list_control
            new_row = findItem row_ids new_id
            if new_row > 0 then list_control.selection = new_row
        )
        new_id -- return
    ),

    /* Load scene values into the editor without silently changing a modifier. */
    function loadValues list_control =
    (
        preset_id = this.getSelectedId list_control
        if preset_id > 0 then (modifierPresetManager.getPresetSettings type_id preset_id) else undefined
        -- return
    ),

    /* Apply selected preset to all selected compatible nodes, shared or unique. */
    function addPreset list_control unique_mode =
    (
        preset_id = this.getSelectedId list_control
        if preset_id > 0 then (modifierPresetManager.addToSelection type_id preset_id unique_mode) else 0
        -- return
    ),

    /* Replace the topmost same-type modifier on each selected compatible node. */
    function reinstancePreset list_control =
    (
        preset_id = this.getSelectedId list_control
        if preset_id > 0 then (modifierPresetManager.reinstanceSelection type_id preset_id) else 0
        -- return
    ),

    on create do
    (
        row_ids = #()
    )
)

mm_mesh_preset_list = modifierPresetList_v type_id:#meshsmooth
mm_chamfer_preset_list = modifierPresetList_v type_id:#chamfer

/*
MeshSmooth uses the shared list controller and native properties only.
The scene holds settings, while actual modifiers can be shared or unique.
*/
rollout mmMeshSmoothRollout "Mesh Smooth" height:364
(
    local loading = false
    listbox lb_presets "SCENE PRESETS" pos:[10,8] width:292 height:5 tooltip:"Select a scene preset.\n\nRMB: Load its settings into the controls."
    button btn_save "Save (RMB: Load)" pos:[10,134] width:142 height:24 tooltip:"LMB: Save the current settings as a new scene preset.\n\nRMB: Load the selected preset into these controls."
    button btn_load "Load" pos:[158,134] width:144 height:24 tooltip:"Read selected preset settings into the controls without changing the scene."
    button btn_add "Add" pos:[10,164] width:92 height:24 tooltip:"Apply this scene preset to all selected compatible objects."
    checkbox chk_unique "Unique" pos:[111,169] width:86 tooltip:"Create one independent native modifier per selected object."
    button btn_reinstance "Re-instance" pos:[207,164] width:95 height:24 tooltip:"Replace the topmost MeshSmooth on each selected object with this shared instance."
    groupbox grp_parameters "Subdivision" pos:[8,195] width:296 height:143
    spinner spn_iterations "Viewport" pos:[12,216] width:140 range:[0,10,1] type:#integer fieldWidth:58
    spinner spn_render "Render" pos:[161,216] width:140 range:[0,10,1] type:#integer fieldWidth:58
    checkbox chk_use_render "Use render iterations" pos:[12,243] width:274
    checkbox chk_materials "Separate by Material" pos:[12,270] width:142
    checkbox chk_smoothing "Separate by SG" pos:[163,270] width:136
    checkbox chk_whole "Whole mesh" pos:[12,300] width:138
    checkbox chk_enabled "Enabled" pos:[163,300] width:132 checked:true
    label lbl_state "Ready." pos:[10,345] width:292 height:17

    /* Convert control values into the shared native MeshSmooth schema. */
    function getValues =
    (
        #(spn_iterations.value, spn_render.value, chk_use_render.checked, chk_materials.checked, chk_smoothing.checked, chk_whole.checked, chk_enabled.checked)
        -- return
    )

    /* Populate controls without emitting remote modifier edits. */
    function setValues setting_values =
    (
        if setting_values != undefined and setting_values.count == 7 then
        (
            loading = true
            spn_iterations.value = setting_values[1]
            spn_render.value = setting_values[2]
            chk_use_render.checked = setting_values[3]
            chk_materials.checked = setting_values[4]
            chk_smoothing.checked = setting_values[5]
            chk_whole.checked = setting_values[6]
            chk_enabled.checked = setting_values[7]
            loading = false
        )
        true -- return
    )

    /* Send one deliberate property change to the existing modifier-manager scope. */
    function editProperty property_name new_value =
    (
        if not loading then modifierManagerUI.applyRemote #meshsmooth property_name new_value
        true -- return
    )

    /* Sync a live selected modifier, keeping controls usable without one. */
    function refreshValues =
    (
        mm_mesh_preset_list.refreshList lb_presets
        target_mods = modifierManagerUI.getTargets #meshsmooth
        if target_mods.count > 0 then mmMeshSmoothRollout.setValues (modifierPresetManager.readSettings #meshsmooth target_mods[1])
        lbl_state.text = ((target_mods.count as string) + " in scope | " + (mm_mesh_preset_list.row_ids.count as string) + " presets")
        true -- return
    )

    /* Load the highlighted scene preset into this rollout only. */
    function loadSelected =
    (
        values = mm_mesh_preset_list.loadValues lb_presets
        if values != undefined then
        (
            mmMeshSmoothRollout.setValues values
            modifierManagerUI.setStatus "MeshSmooth preset loaded into controls."
        )
        else modifierManagerUI.setStatus "Choose a valid MeshSmooth scene preset."
        true -- return
    )

    on mmMeshSmoothRollout open do
    (
        mm_mesh_preset_list.refreshList lb_presets
        mmMeshSmoothRollout.refreshValues()
    )
    on btn_save pressed do
    (
        target_mods = modifierManagerUI.getTargets #meshsmooth
        source_mod = if target_mods.count > 0 then target_mods[1] else undefined
        current_values = if source_mod != undefined then (modifierPresetManager.readSettings #meshsmooth source_mod) else (mmMeshSmoothRollout.getValues())
        new_id = mm_mesh_preset_list.saveValues lb_presets current_values source_mod
        if new_id > 0 then modifierManagerUI.setStatus ("Saved MeshSmooth preset #" + (new_id as string) + ".")
        else modifierManagerUI.setStatus ("Preset save failed: " + modifierPresetManager.last_error)
        modifierManagerUI.refreshFromScene()
    )
    on btn_save rightclick do (mmMeshSmoothRollout.loadSelected())
    on btn_load pressed do (mmMeshSmoothRollout.loadSelected())
    on lb_presets doubleClicked row_index do (mmMeshSmoothRollout.loadSelected())
    on lb_presets rightClick row_index do
    (
        if row_index > 0 then lb_presets.selection = row_index
        mmMeshSmoothRollout.loadSelected()
    )
    on btn_add pressed do
    (
        added_count = mm_mesh_preset_list.addPreset lb_presets chk_unique.checked
        if (mm_mesh_preset_list.getSelectedId lb_presets) == 0 then modifierManagerUI.setStatus "Select a MeshSmooth scene preset first."
        else if added_count == 0 then modifierManagerUI.setStatus ("MeshSmooth Add failed: " + modifierPresetManager.last_error)
        else modifierManagerUI.setStatus ((added_count as string) + " MeshSmooth modifier(s) added.")
        modifierManagerUI.refreshFromScene()
    )
    on btn_reinstance pressed do
    (
        replaced_count = mm_mesh_preset_list.reinstancePreset lb_presets
        if (mm_mesh_preset_list.getSelectedId lb_presets) == 0 then modifierManagerUI.setStatus "Select a MeshSmooth scene preset first."
        else if replaced_count == 0 then modifierManagerUI.setStatus "No MeshSmooth modifiers required replacement."
        else modifierManagerUI.setStatus ((replaced_count as string) + " MeshSmooth modifier(s) re-instanced.")
        modifierManagerUI.refreshFromScene()
    )
    on spn_iterations changed new_value do (mmMeshSmoothRollout.editProperty #iterations new_value)
    on spn_render changed new_value do (mmMeshSmoothRollout.editProperty #renderIterations new_value)
    on chk_use_render changed new_value do (mmMeshSmoothRollout.editProperty #useRenderIterations new_value)
    on chk_materials changed new_value do (mmMeshSmoothRollout.editProperty #sepByMats new_value)
    on chk_smoothing changed new_value do (mmMeshSmoothRollout.editProperty #sepBySmGroups new_value)
    on chk_whole changed new_value do (mmMeshSmoothRollout.editProperty #Apply_To_Whole_Mesh new_value)
    on chk_enabled changed new_value do (mmMeshSmoothRollout.editProperty #enabled new_value)
)

/*
Chamfer reuses the same preset-list controller and supports native edge filters.
Its Inset enable, amount, offset, and segments share one compact row.
*/
rollout mmChamferRollout "Chamfer" height:461
(
    local loading = false
    listbox lb_presets "SCENE PRESETS" pos:[10,8] width:292 height:5 tooltip:"Select a scene preset.\n\nRMB: Load its settings into the controls."
    button btn_save "Save (RMB: Load)" pos:[10,134] width:142 height:24 tooltip:"LMB: Save the current settings as a new scene preset.\n\nRMB: Load the selected preset into these controls."
    button btn_load "Load" pos:[158,134] width:144 height:24 tooltip:"Read selected preset settings into the controls without changing the scene."
    button btn_add "Add" pos:[10,164] width:92 height:24 tooltip:"Apply this Chamfer preset to all selected compatible objects."
    checkbox chk_unique "Unique" pos:[111,169] width:86 tooltip:"Create one independent Chamfer modifier per selected object."
    button btn_reinstance "Re-instance" pos:[207,164] width:95 height:24 tooltip:"Replace the topmost Chamfer on each selected object with this shared instance."
    groupbox grp_parameters "Chamfer parameters" pos:[8,195] width:296 height:243
    spinner spn_amount "Amount" pos:[10,216] width:144 range:[0.0,100000.0,1.0] type:#worldunits fieldWidth:58
    spinner spn_segments "Segments" pos:[160,216] width:141 range:[1,99,1] type:#integer fieldWidth:56
    dropdownList ddl_type "Type" pos:[10,245] width:142 items:#("Quad", "Standard") selection:1
    spinner spn_tension "Tension" pos:[160,245] width:141 range:[0.0,1.0,1.0] type:#float fieldWidth:58 scale:0.05
    checkbox chk_open "Open" pos:[12,280] width:132
    checkbox chk_enabled "Enabled" pos:[160,280] width:130 checked:true
    dropdownList ddl_selection "Selection" pos:[10,308] width:292 items:#("From Stack", "Selected Edges", "Selected Faces Edges", "Selected Faces Borders", "Edge Verts", "All Edges", "Selected Vertices", "All Vertices") selection:1
    dropdownList ddl_material "Material" pos:[10,354] width:142 items:#("Off", "Different", "Same") selection:1
    dropdownList ddl_smoothing "Smoothing" pos:[160,354] width:142 items:#("Off", "Smoothed", "Unsmoothed") selection:1
    checkbox chk_inset "Inset" pos:[10,409] width:51
    spinner spn_inset_amount "Amt" pos:[61,408] width:75 range:[-100000.0,100000.0,0.5] type:#float fieldWidth:42 scale:0.05
    spinner spn_inset_offset "Off" pos:[141,408] width:76 range:[-100000.0,100000.0,0.0] type:#float fieldWidth:42 scale:0.05
    spinner spn_inset_segments "Seg" pos:[222,408] width:80 range:[0,99,0] type:#integer fieldWidth:42
    label lbl_state "Ready." pos:[10,444] width:292 height:17

    /* Read the complete supported Chamfer native-property snapshot from UI. */
    function getValues =
    (
        #(spn_amount.value, spn_segments.value, chk_open.checked, chk_enabled.checked, ddl_selection.selection - 1, ddl_type.selection - 1, spn_tension.value, ddl_material.selection - 1, ddl_smoothing.selection - 1, chk_inset.checked, spn_inset_amount.value, spn_inset_offset.value, spn_inset_segments.value)
        -- return
    )

    /* Read Chamfer settings without firing remote-edit handlers. */
    function setValues setting_values =
    (
        if setting_values != undefined and setting_values.count == 13 then
        (
            loading = true
            spn_amount.value = setting_values[1]
            spn_segments.value = setting_values[2]
            chk_open.checked = setting_values[3]
            chk_enabled.checked = setting_values[4]
            ddl_selection.selection = setting_values[5] + 1
            ddl_type.selection = setting_values[6] + 1
            spn_tension.value = setting_values[7]
            ddl_material.selection = setting_values[8] + 1
            ddl_smoothing.selection = setting_values[9] + 1
            chk_inset.checked = setting_values[10]
            spn_inset_amount.value = setting_values[11]
            spn_inset_offset.value = setting_values[12]
            spn_inset_segments.value = setting_values[13]
            loading = false
        )
        true -- return
    )

    /* Update only the explicitly scoped native Chamfer modifiers. */
    function editProperty property_name new_value =
    (
        if not loading then modifierManagerUI.applyRemote #chamfer property_name new_value
        true -- return
    )

    /* Load values for the selected native scope without changing modifiers. */
    function refreshValues =
    (
        mm_chamfer_preset_list.refreshList lb_presets
        target_mods = modifierManagerUI.getTargets #chamfer
        if target_mods.count > 0 then mmChamferRollout.setValues (modifierPresetManager.readSettings #chamfer target_mods[1])
        lbl_state.text = ((target_mods.count as string) + " in scope | " + (mm_chamfer_preset_list.row_ids.count as string) + " presets")
        true -- return
    )

    /* Load the selected scene preset into the editor only. */
    function loadSelected =
    (
        values = mm_chamfer_preset_list.loadValues lb_presets
        if values != undefined then
        (
            mmChamferRollout.setValues values
            modifierManagerUI.setStatus "Chamfer preset loaded into controls."
        )
        else modifierManagerUI.setStatus "Choose a valid Chamfer scene preset."
        true -- return
    )

    on mmChamferRollout open do
    (
        mm_chamfer_preset_list.refreshList lb_presets
        mmChamferRollout.refreshValues()
    )
    on btn_save pressed do
    (
        target_mods = modifierManagerUI.getTargets #chamfer
        source_mod = if target_mods.count > 0 then target_mods[1] else undefined
        current_values = if source_mod != undefined then (modifierPresetManager.readSettings #chamfer source_mod) else (mmChamferRollout.getValues())
        new_id = mm_chamfer_preset_list.saveValues lb_presets current_values source_mod
        if new_id > 0 then modifierManagerUI.setStatus ("Saved Chamfer preset #" + (new_id as string) + ".")
        else modifierManagerUI.setStatus ("Preset save failed: " + modifierPresetManager.last_error)
        modifierManagerUI.refreshFromScene()
    )
    on btn_save rightclick do (mmChamferRollout.loadSelected())
    on btn_load pressed do (mmChamferRollout.loadSelected())
    on lb_presets doubleClicked row_index do (mmChamferRollout.loadSelected())
    on lb_presets rightClick row_index do
    (
        if row_index > 0 then lb_presets.selection = row_index
        mmChamferRollout.loadSelected()
    )
    on btn_add pressed do
    (
        added_count = mm_chamfer_preset_list.addPreset lb_presets chk_unique.checked
        if (mm_chamfer_preset_list.getSelectedId lb_presets) == 0 then modifierManagerUI.setStatus "Select a Chamfer scene preset first."
        else if added_count == 0 then modifierManagerUI.setStatus ("Chamfer Add failed: " + modifierPresetManager.last_error)
        else modifierManagerUI.setStatus ((added_count as string) + " Chamfer modifier(s) added.")
        modifierManagerUI.refreshFromScene()
    )
    on btn_reinstance pressed do
    (
        replaced_count = mm_chamfer_preset_list.reinstancePreset lb_presets
        if (mm_chamfer_preset_list.getSelectedId lb_presets) == 0 then modifierManagerUI.setStatus "Select a Chamfer scene preset first."
        else if replaced_count == 0 then modifierManagerUI.setStatus "No Chamfer modifiers required replacement."
        else modifierManagerUI.setStatus ((replaced_count as string) + " Chamfer modifier(s) re-instanced.")
        modifierManagerUI.refreshFromScene()
    )
    on spn_amount changed new_value do (mmChamferRollout.editProperty #amount new_value)
    on spn_segments changed new_value do (mmChamferRollout.editProperty #segments new_value)
    on chk_open changed new_value do (mmChamferRollout.editProperty #openchamfer new_value)
    on chk_enabled changed new_value do (mmChamferRollout.editProperty #enabled new_value)
    on ddl_selection selected row_index do (mmChamferRollout.editProperty #selectionoption (row_index - 1))
    on ddl_type selected row_index do (mmChamferRollout.editProperty #chamfertype (row_index - 1))
    on spn_tension changed new_value do (mmChamferRollout.editProperty #tension new_value)
    on ddl_material selected row_index do (mmChamferRollout.editProperty #materialoption (row_index - 1))
    on ddl_smoothing selected row_index do (mmChamferRollout.editProperty #smoothingoption (row_index - 1))
    on chk_inset changed new_value do (mmChamferRollout.editProperty #addinset new_value)
    on spn_inset_amount changed new_value do (mmChamferRollout.editProperty #insetamount new_value)
    on spn_inset_offset changed new_value do (mmChamferRollout.editProperty #insetoffset new_value)
    on spn_inset_segments changed new_value do (mmChamferRollout.editProperty #insetsegments new_value)
)
