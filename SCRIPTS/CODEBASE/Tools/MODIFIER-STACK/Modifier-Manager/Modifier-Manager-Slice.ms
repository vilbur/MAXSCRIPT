/*
Modifier Manager native Slice parameter and gizmo operations.
File version: 0.022 | Project version: 0.022.
*/
global modifierSliceManager
global modifier_manager_project_version
global modifier_manager_file_version_slice = 0.022
global modifier_manager_stored_project_version_slice = 0.022
if modifier_manager_project_version == undefined or modifier_manager_stored_project_version_slice > modifier_manager_project_version then
(
    modifier_manager_project_version = modifier_manager_stored_project_version_slice
)

/*
Keep bounding box extents fixed during slider drags, even if a Slice
modifier later removes geometry and changes the evaluated node bounds.
*/
struct modifierSliceManager_v
(
    bounds_cache = #(),
    last_error = "",
    operate_appdata_id = 1763145911,

    /* Forget cached bounds when the active selection or axis system changes. */
    function clearCache =
    (
        bounds_cache = #()
        true -- return
    ),

    /* Select the matrix that defines the requested movement directions. */
    function getBasisTM scene_node target_mod axis_mode =
    (
        basis_tm = matrix3 1
        if isValidNode scene_node and classOf target_mod == SliceModifier then
        (
            case axis_mode of
            (
                #local: (basis_tm = scene_node.transform)
                #gizmo:
                (
                    context_tm = getModContextTM scene_node target_mod
                    if context_tm == undefined then context_tm = scene_node.transform
                    basis_tm = (target_mod.slice_plane.rotation as matrix3) * context_tm
                )
                default: (basis_tm = matrix3 1)
            )
        )
        basis_tm -- return
    ),

    /* Transform the pre-Slice modifier-context box into selected axes. */
    function makeBoundsEntry scene_node target_mod axis_mode =
    (
        entry_data = undefined
        if isValidNode scene_node and classOf target_mod == SliceModifier then
        (
            context_tm = getModContextTM scene_node target_mod
            if context_tm == undefined then context_tm = scene_node.transform
            basis_tm = this.getBasisTM scene_node target_mod axis_mode
            inverse_basis = inverse basis_tm
            context_low = getModContextBBoxMin scene_node target_mod
            context_high = getModContextBBoxMax scene_node target_mod
            if context_low != undefined and context_high != undefined then
            (
                first_point = true
                bbox_low = [0,0,0]
                bbox_high = [0,0,0]
                for x_value in #(context_low.x, context_high.x) do
                (
                    for y_value in #(context_low.y, context_high.y) do
                    (
                        for z_value in #(context_low.z, context_high.z) do
                        (
                            current_basis = ([x_value,y_value,z_value] * context_tm) * inverse_basis
                            if first_point then
                            (
                                bbox_low = copy current_basis
                                bbox_high = copy current_basis
                                first_point = false
                            )
                            else
                            (
                                if current_basis.x < bbox_low.x then bbox_low.x = current_basis.x
                                if current_basis.y < bbox_low.y then bbox_low.y = current_basis.y
                                if current_basis.z < bbox_low.z then bbox_low.z = current_basis.z
                                if current_basis.x > bbox_high.x then bbox_high.x = current_basis.x
                                if current_basis.y > bbox_high.y then bbox_high.y = current_basis.y
                                if current_basis.z > bbox_high.z then bbox_high.z = current_basis.z
                            )
                        )
                    )
                )
                entry_data = #(scene_node, target_mod, axis_mode, basis_tm, bbox_low, bbox_high, context_tm)
                append bounds_cache entry_data
            )
            else
            (
                last_error = "Unable to read the Slice modifier context bounding box."
                format "Modifier Manager Slice | no bounding box | node:% modifier:%\n" scene_node.name target_mod
            )
        )
        entry_data -- return
    ),

    /* Reuse frozen context bounds for repeated slider changes. */
    function getBounds scene_node target_mod axis_mode =
    (
        entry_data = undefined
        for saved_entry in bounds_cache while entry_data == undefined do
        (
            if saved_entry[1] == scene_node and saved_entry[2] == target_mod and saved_entry[3] == axis_mode then entry_data = saved_entry
        )
        if entry_data == undefined then entry_data = this.makeBoundsEntry scene_node target_mod axis_mode
        entry_data -- return
    ),

    /* Map signed slider percentage onto the selected bounding box axis. */
    function percentToValue axis_low axis_high signed_percent =
    (
        half_width = (axis_high - axis_low) * 0.5
        center_value = (axis_low + axis_high) * 0.5
        clamped_percent = signed_percent
        if clamped_percent < -100.0 then clamped_percent = -100.0
        if clamped_percent > 100.0 then clamped_percent = 100.0
        center_value + clamped_percent * 0.01 * half_width -- return
    ),

    /* Map a current axis coordinate back to signed slider percent. */
    function valueToPercent axis_low axis_high axis_value =
    (
        half_width = (axis_high - axis_low) * 0.5
        result_value = 0.0
        if (abs half_width) > 0.0000001 then result_value = (axis_value - ((axis_low + axis_high) * 0.5)) / half_width * 100.0
        if result_value < -100.0 then result_value = -100.0
        if result_value > 100.0 then result_value = 100.0
        result_value -- return
    ),

    /* Read current gizmo origin in the chosen Local / Gizmo / World axes. */
    function getCurrentBasisPosition scene_node target_mod axis_mode =
    (
        axis_pos = undefined
        entry_data = this.getBounds scene_node target_mod axis_mode
        if entry_data != undefined then
        (
            world_pos = target_mod.slice_plane.position * entry_data[7]
            axis_pos = world_pos * (inverse entry_data[4])
        )
        axis_pos -- return
    ),

    /* Read one slider's signed percentage without moving the Slice plane. */
    function getAxisPercent scene_node target_mod axis_mode axis_index =
    (
        result_percent = 0.0
        entry_data = this.getBounds scene_node target_mod axis_mode
        current_pos = this.getCurrentBasisPosition scene_node target_mod axis_mode
        if entry_data != undefined and current_pos != undefined and axis_index >= 1 and axis_index <= 3 then
        (
            result_percent = this.valueToPercent entry_data[5][axis_index] entry_data[6][axis_index] current_pos[axis_index]
        )
        result_percent -- return
    ),

    /* Translate only one chosen axis; leave the Slice plane rotation untouched. */
    function setAxisPercent scene_node target_mod axis_mode axis_index signed_percent =
    (
        moved_ok = false
        last_error = ""
        entry_data = this.getBounds scene_node target_mod axis_mode
        current_pos = this.getCurrentBasisPosition scene_node target_mod axis_mode
        if entry_data != undefined and current_pos != undefined and axis_index >= 1 and axis_index <= 3 then
        (
            new_axis_pos = copy current_pos
            new_axis_pos[axis_index] = this.percentToValue entry_data[5][axis_index] entry_data[6][axis_index] signed_percent
            new_world_pos = new_axis_pos * entry_data[4]
            new_context_pos = new_world_pos * (inverse entry_data[7])
            undo "Modifier Manager | Move Slice Gizmo" on
            (
                target_mod.slice_plane.position = new_context_pos
            )
            moved_ok = true
        )
        else
        (
            last_error = "Choose a valid Slice modifier and axis."
        )
        moved_ok -- return
    ),

    /* Write the four native Slice types: Refine, Split, Top, Bottom. */
    function setSliceType target_mod slice_type_id =
    (
        changed_ok = false
        if classOf target_mod == SliceModifier and slice_type_id >= 0 and slice_type_id <= 3 then
        (
            target_mod.Slice_Type = slice_type_id
            changed_ok = true
        )
        changed_ok -- return
    ),

    /* Resolve Automatic to face mode for mesh stacks and poly for poly stacks. */
    function getAutomaticNativeMode scene_node target_mod =
    (
        native_mode = 0
        if isValidNode scene_node then
        (
            if classOf scene_node.baseObject == Editable_Poly then native_mode = 1
            target_index = modifierManager.getStackIndex scene_node target_mod
            if target_index > 0 then
            (
                for mod_index = (target_index + 1) to scene_node.modifiers.count do
                (
                    if classOf scene_node.modifiers[mod_index] == Edit_Poly then native_mode = 1
                )
            )
        )
        native_mode -- return
    ),

    /* Set UI Automatic / Poly / Mesh using the two native Slice face modes. */
    function setOperateMode scene_node target_mod selection_id =
    (
        changed_ok = false
        if classOf target_mod == SliceModifier and selection_id >= 1 and selection_id <= 3 then
        (
            native_mode = case selection_id of
            (
                1: (this.getAutomaticNativeMode scene_node target_mod)
                2: 1
                3: 0
            )
            target_mod.Faces___Polygons_Toggle = native_mode
            mode_tag = case selection_id of
            (
                1: "Automatic"
                2: "Poly"
                3: "Mesh"
            )
            setAppData target_mod operate_appdata_id mode_tag
            changed_ok = true
        )
        changed_ok -- return
    ),

    /* Restore the non-native Automatic UI choice from its modifier AppData. */
    function getOperateMode target_mod =
    (
        selection_id = 2
        if classOf target_mod == SliceModifier then
        (
            stored_mode = getAppData target_mod operate_appdata_id
            case stored_mode of
            (
                "Automatic": (selection_id = 1)
                "Mesh": (selection_id = 3)
                "Poly": (selection_id = 2)
                default: (selection_id = if target_mod.Faces___Polygons_Toggle == 0 then 3 else 2)
            )
        )
        selection_id -- return
    ),

    /* Enter or leave the actual native Slice Plane sub-object gizmo mode. */
    function activateGizmoMode scene_node target_mod state_value =
    (
        changed_ok = false
        if isValidNode scene_node and classOf target_mod == SliceModifier and (modifierManager.getStackIndex scene_node target_mod) > 0 then
        (
            max modify mode
            modPanel.setCurrentObject target_mod node:scene_node
            subObjectLevel = if state_value then 1 else 0
            changed_ok = (subObjectLevel == (if state_value then 1 else 0))
        )
        changed_ok -- return
    ),

    on create do
    (
        bounds_cache = #()
        last_error = ""
    )
)

modifierSliceManager = modifierSliceManager_v()
