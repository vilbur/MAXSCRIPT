/*
Modifier Manager native Slice child rollout.
File version: 0.022 | Project version: 0.022.
*/
global mmSliceRollout
global modifierManagerUI
global modifierSliceManager
global modifier_manager_project_version
global modifier_manager_file_version_slice_ui = 0.022
global modifier_manager_stored_project_version_slice_ui = 0.022
if modifier_manager_project_version == undefined or modifier_manager_stored_project_version_slice_ui > modifier_manager_project_version then
(
    modifier_manager_project_version = modifier_manager_stored_project_version_slice_ui
)

/*
Signed sliders span the active modifier-context bounding box.
Axis checkbuttons lock movement; radio buttons select movement axes.
*/
rollout mmSliceRollout "Slice" height:426
(
    local loading = false
    local cached_node = undefined
    checkbutton btn_gizmo "Gizmo Mode" pos:[10,8] width:292 height:24 tooltip:"Enter or leave native Slice Plane sub-object mode."
    radioButtons rdo_coords "Movement axes" labels:#("Local", "Gizmo", "World") columns:3 default:1 pos:[10,40] width:292 tooltip:"Choose the coordinate system for slider translation."
    groupBox grp_motion "Bounding box position (%)" pos:[8,94] width:296 height:150
    checkbutton chk_x "X" pos:[14,119] width:38 height:22 checked:true tooltip:"Enable or lock X-axis movement."
    slider sl_x "" pos:[57,119] width:242 height:24 range:[-100,100,0] type:#integer ticks:5 tooltip:"Move the gizmo between the negative and positive X bounds."
    checkbutton chk_y "Y" pos:[14,158] width:38 height:22 checked:true tooltip:"Enable or lock Y-axis movement."
    slider sl_y "" pos:[57,158] width:242 height:24 range:[-100,100,0] type:#integer ticks:5 tooltip:"Move the gizmo between the negative and positive Y bounds."
    checkbutton chk_z "Z" pos:[14,197] width:38 height:22 checked:true tooltip:"Enable or lock Z-axis movement."
    slider sl_z "" pos:[57,197] width:242 height:24 range:[-100,100,0] type:#integer ticks:5 tooltip:"Move the gizmo between the negative and positive Z bounds."
    label lbl_signed "-100%                         0                         +100%" pos:[56,225] width:243 height:16
    radioButtons rdo_slice "Slice Type" labels:#("Refine", "Split", "Remove +", "Remove -") columns:2 default:1 pos:[10,257] width:292 tooltip:"Refine or split the intersection, or remove one side of the plane."
    radioButtons rdo_operate "Operate On" labels:#("Automatic", "Poly", "Mesh") columns:3 default:2 pos:[10,323] width:292 tooltip:"Automatic chooses Polygon for poly stacks, Face for mesh stacks."
    button btn_add "Add Slice" pos:[10,369] width:140 height:24 tooltip:"Add a native Slice modifier to each selected compatible object."
    button btn_center "Center Gizmo" pos:[161,369] width:141 height:24 tooltip:"Move enabled axes to the bounding box center without rotating the plane."
    label lbl_state "Select a Slice modifier." pos:[10,404] width:292 height:18

    /* Resolve the radio selection into the native slice manager's axis symbol. */
    function getAxisMode =
    (
        case rdo_coords.state of
        (
            1: #local
            2: #gizmo
            default: #world
        )
        -- return
    )

    /* Lock a slider when its axis checkbutton is turned off. */
    function syncAxisEnabled =
    (
        sl_x.enabled = chk_x.checked
        sl_y.enabled = chk_y.checked
        sl_z.enabled = chk_z.checked
        true -- return
    )

    /* Present the selected native modifier and freeze its current bbox. */
    function refreshValues =
    (
        scene_node = modifierManager.getSelectedNode()
        target_mods = modifierManagerUI.getTargets #slice
        if scene_node != cached_node then
        (
            modifierSliceManager.clearCache()
            cached_node = scene_node
        )
        loading = true
        if isValidNode scene_node and target_mods.count > 0 then
        (
            target_mod = target_mods[1]
            axis_mode = mmSliceRollout.getAxisMode()
            sl_x.value = modifierSliceManager.getAxisPercent scene_node target_mod axis_mode 1
            sl_y.value = modifierSliceManager.getAxisPercent scene_node target_mod axis_mode 2
            sl_z.value = modifierSliceManager.getAxisPercent scene_node target_mod axis_mode 3
            rdo_slice.state = target_mod.Slice_Type + 1
            rdo_operate.state = modifierSliceManager.getOperateMode target_mod
            btn_gizmo.checked = (modPanel.getCurrentObject() == target_mod and subObjectLevel == 1)
            lbl_state.text = (target_mods.count as string) + " Slice modifier(s) in scope"
        )
        else
        (
            btn_gizmo.checked = false
            lbl_state.text = "Select a Slice modifier in the stack."
        )
        mmSliceRollout.syncAxisEnabled()
        loading = false
        true -- return
    )

    /* Move each scoped Slice instance using frozen bounds and the chosen axes. */
    function moveAxis axis_index percent_value =
    (
        moved_count = 0
        enabled_axis = case axis_index of
        (
            1: chk_x.checked
            2: chk_y.checked
            default: chk_z.checked
        )
        if not loading and enabled_axis then
        (
            scene_node = modifierManager.getSelectedNode()
            if isValidNode scene_node then
            (
                for target_mod in (modifierManagerUI.getTargets #slice) do
                (
                    if modifierSliceManager.setAxisPercent scene_node target_mod (mmSliceRollout.getAxisMode()) axis_index percent_value then moved_count += 1
                )
            )
            modifierManagerUI.setStatus ((moved_count as string) + " Slice gizmo(s) moved.")
            if moved_count > 0 then redrawViews()
        )
        moved_count -- return
    )

    /* Set all scoped native Slice types without adding scripted modifiers. */
    function updateSliceType native_type_id =
    (
        changed_count = 0
        for target_mod in (modifierManagerUI.getTargets #slice) do
        (
            if modifierSliceManager.setSliceType target_mod native_type_id then changed_count += 1
        )
        modifierManagerUI.setStatus ((changed_count as string) + " Slice type(s) updated.")
        true -- return
    )

    /* Store Automatic as AppData because the native modifier has only two modes. */
    function updateOperateMode selection_id =
    (
        changed_count = 0
        scene_node = modifierManager.getSelectedNode()
        if isValidNode scene_node then
        (
            for target_mod in (modifierManagerUI.getTargets #slice) do
            (
                if modifierSliceManager.setOperateMode scene_node target_mod selection_id then changed_count += 1
            )
        )
        modifierManagerUI.setStatus ((changed_count as string) + " Slice operation mode(s) updated.")
        true -- return
    )

    on mmSliceRollout open do
    (
        mmSliceRollout.syncAxisEnabled()
        mmSliceRollout.refreshValues()
    )

    on btn_gizmo changed new_state do
    (
        if not loading then
        (
            scene_node = modifierManager.getSelectedNode()
            target_mods = modifierManagerUI.getTargets #slice
            if target_mods.count > 0 and isValidNode scene_node then
            (
                enabled_ok = modifierSliceManager.activateGizmoMode scene_node target_mods[1] new_state
                modifierManagerUI.setStatus (if enabled_ok then "Slice Plane gizmo mode updated." else "Could not activate native Slice Plane mode.")
            )
            else
            (
                btn_gizmo.checked = false
                modifierManagerUI.setStatus "Select a Slice modifier first."
            )
        )
    )

    on rdo_coords changed state_value do
    (
        if not loading then
        (
            modifierSliceManager.clearCache()
            mmSliceRollout.refreshValues()
        )
    )
    on chk_x changed state_value do (mmSliceRollout.syncAxisEnabled())
    on chk_y changed state_value do (mmSliceRollout.syncAxisEnabled())
    on chk_z changed state_value do (mmSliceRollout.syncAxisEnabled())
    on sl_x changed new_value do (mmSliceRollout.moveAxis 1 new_value)
    on sl_y changed new_value do (mmSliceRollout.moveAxis 2 new_value)
    on sl_z changed new_value do (mmSliceRollout.moveAxis 3 new_value)
    on rdo_slice changed state_value do
    (
        if not loading then mmSliceRollout.updateSliceType (state_value - 1)
    )
    on rdo_operate changed state_value do
    (
        if not loading then mmSliceRollout.updateOperateMode state_value
    )

    on btn_add pressed do
    (
        added_count = 0
        first_new_mod = undefined
        for scene_node in selection where isValidNode scene_node do
        (
            if validModifier scene_node SliceModifier then
            (
                new_mod = SliceModifier()
                new_mod.Faces___Polygons_Toggle = 1
                addModifier scene_node new_mod
                if first_new_mod == undefined then first_new_mod = new_mod
                added_count += 1
            )
        )
        modifierSliceManager.clearCache()
        modifierManagerUI.refreshFromScene()
        if first_new_mod != undefined then modifierManagerUI.focusModifier first_new_mod
        modifierManagerUI.setStatus ((added_count as string) + " native Slice modifier(s) added.")
    )

    on btn_center pressed do
    (
        if chk_x.checked then mmSliceRollout.moveAxis 1 0
        if chk_y.checked then mmSliceRollout.moveAxis 2 0
        if chk_z.checked then mmSliceRollout.moveAxis 3 0
        mmSliceRollout.refreshValues()
    )
)
