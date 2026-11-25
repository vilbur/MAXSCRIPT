/* World-Symmetry-Rollout.ms
   Development child rollout 0.001, 2026-10-23.
   Load World-Symmetry-Core.ms first.
   Embed with: addSubRollout materialIdManagerRollout.sub_rollouts worldSymmetryRollout
   UI inherits the owning Modifier Sets dialog shell.
*/

global world_symmetry_ui_refreshing = false

/*
Reads the persisted creation preferences from the owning Modifier Sets INI.
Does not overwrite values on any existing scene modifier.
*/
function worldSymmetryGetPreferredAxis =
(
    local preferred_axis = 0
    if material_id_manager_ini_path != undefined and material_id_manager_ini_path != "" then
    (
        local text_value = getINISetting material_id_manager_ini_path "WorldSymmetry" "Axis"
        if text_value == "1" then preferred_axis = 1
        if text_value == "2" then preferred_axis = 2
    )
    preferred_axis
    -- return
)

/*
Reads whether newly added managed Symmetry modifiers should start flipped.
*/
function worldSymmetryGetPreferredFlip =
(
    if material_id_manager_ini_path != undefined and material_id_manager_ini_path != "" then
    (
        getINISetting material_id_manager_ini_path "WorldSymmetry" "Flip" == "true"
    )
    else false
    -- return
)

/*
Persists creation preferences in the owning Modifier Sets INI file.
*/
function worldSymmetrySavePreferences axis_index flip_enabled =
(
    if material_id_manager_ini_path != undefined and material_id_manager_ini_path != "" then
    (
        setINISetting material_id_manager_ini_path "WorldSymmetry" "Axis" (axis_index as string)
        setINISetting material_id_manager_ini_path "WorldSymmetry" "Flip" (flip_enabled as string)
    )
    true
    -- return
)

rollout worldSymmetryRollout "WORLD SYMMETRY" width:264 height:156
(
    button btn_symmetry "Symmetry — Add / Select" pos:[12,12] width:240 height:24 tooltip:"Select an existing WORLD SYMMETRY modifier, or add one if none exists."
    checkbutton chk_axis_x "X" pos:[12,48] width:72 height:24 checked:true
    checkbutton chk_axis_y "Y" pos:[96,48] width:72 height:24
    checkbutton chk_axis_z "Z" pos:[180,48] width:72 height:24
    checkbutton chk_flip "Flip" pos:[12,84] width:240 height:24
    checkbutton chk_service "Start Service" pos:[12,120] width:144 height:24 tooltip:"Monitor named Symmetry modifiers across the scene. This is not saved with the scene."
    label lbl_service "STOPPED" pos:[168,124] width:84 height:18

    /*
    Synchronizes axis, Flip, and service status with one selected object.
    With no managed modifier, retains axis/Flip as preferences for creation.
    */
    function refreshControls =
    (
        world_symmetry_ui_refreshing = true
        if selection.count == 1 then
        (
            local selected_mod = worldSymmetryFind selection[1]
            if selected_mod != undefined then
            (
                chk_axis_x.checked = (selected_mod.axis == 0)
                chk_axis_y.checked = (selected_mod.axis == 1)
                chk_axis_z.checked = (selected_mod.axis == 2)
                chk_flip.checked = selected_mod.flip
            )
        )
        chk_service.checked = world_symmetry_running
        chk_service.text = if world_symmetry_running then "Stop Service" else "Start Service"
        lbl_service.text = if world_symmetry_running then ((worldSymmetryTrackedCount() as string) + " tracked") else "STOPPED"
        world_symmetry_ui_refreshing = false
        true
        -- return
    )

    /*
    Applies one mutually-exclusive axis without ever adding a modifier.
    */
    function setSelectedAxis axis_index =
    (
        if selection.count == 1 then
        (
            if worldSymmetryFind selection[1] != undefined then worldSymmetrySetAxis selection[1] axis_index
        )
        world_symmetry_ui_refreshing = true
        chk_axis_x.checked = (axis_index == 0)
        chk_axis_y.checked = (axis_index == 1)
        chk_axis_z.checked = (axis_index == 2)
        world_symmetry_ui_refreshing = false
        worldSymmetrySavePreferences axis_index chk_flip.checked
        -- return
    )

    on worldSymmetryRollout open do
    (
        local preferred_axis = worldSymmetryGetPreferredAxis()
        world_symmetry_ui_refreshing = true
        chk_axis_x.checked = (preferred_axis == 0)
        chk_axis_y.checked = (preferred_axis == 1)
        chk_axis_z.checked = (preferred_axis == 2)
        chk_flip.checked = worldSymmetryGetPreferredFlip()
        world_symmetry_ui_refreshing = false
        refreshControls()
    )

    on btn_symmetry pressed do
    (
        if selection.count == 1 then
        (
            local axis_index = if chk_axis_x.checked then 0 else if chk_axis_y.checked then 1 else 2
            local was_missing = (worldSymmetryFind selection[1] == undefined)
            local chosen_mod = worldSymmetrySelectOrAdd selection[1] axis_index chk_flip.checked
            if chosen_mod != undefined then
            (
                if was_missing then worldSymmetryRescanIfRunning()
                refreshControls()
            )
        )
        else
        (
            format "WORLD SYMMETRY | Add/Select expects exactly one selected object; found:%\n" selection.count
        )
    )

    on chk_axis_x changed state do
    (
        if not world_symmetry_ui_refreshing then setSelectedAxis 0
    )
    on chk_axis_y changed state do
    (
        if not world_symmetry_ui_refreshing then setSelectedAxis 1
    )
    on chk_axis_z changed state do
    (
        if not world_symmetry_ui_refreshing then setSelectedAxis 2
    )

    on chk_flip changed state do
    (
        if not world_symmetry_ui_refreshing then
        (
            if selection.count == 1 and worldSymmetryFind selection[1] != undefined then worldSymmetrySetFlip selection[1] state
            local axis_index = if chk_axis_x.checked then 0 else if chk_axis_y.checked then 1 else 2
            worldSymmetrySavePreferences axis_index state
        )
    )

    on chk_service changed state do
    (
        if not world_symmetry_ui_refreshing then
        (
            if state then worldSymmetryStartService() else worldSymmetryStopService()
            refreshControls()
        )
    )
)
