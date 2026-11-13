/* Modifier-Manager - independent tool backend.
   File version: 0.011 | Project version: 0.011.
   Split from Modifier-Set-Stack v0.087 without modifying the source.
*/
global modifier_manager_project_version
if modifier_manager_project_version == undefined or modifier_manager_project_version < 0.011 then modifier_manager_project_version = 0.011
global modifierManager
/* Backend functions are callable without loading a UI. */
struct modifierManager_v
(
    active_node = undefined,
    last_error = "",

    /* getSelectedNode - retained native modifier operation. */
    function getSelectedNode =
    (
        scene_node = undefined

        if selection.count == 1 and isValidNode selection[1] then
        (
            scene_node = selection[1]
        )

        scene_node -- return
    ),

    /* getStackIndex - retained native modifier operation. */
    function getStackIndex scene_node target_mod =
    (
        stack_index = 0

        if isValidNode scene_node and target_mod != undefined then
        (
            for index_value = 1 to scene_node.modifiers.count while stack_index == 0 do
            (
                if scene_node.modifiers[index_value] == target_mod then
                (
                    stack_index = index_value
                )
            )
        )

        stack_index -- return
    ),

    /* resolveHandle - retained native modifier operation. */
    function resolveHandle scene_node anim_handle =
    (
        resolved_mod = undefined

        if anim_handle != undefined and isValidNode scene_node then
        (
            candidate_mod = getAnimByHandle anim_handle

            if candidate_mod != undefined and (this.getStackIndex scene_node candidate_mod) > 0 then
            (
                resolved_mod = candidate_mod
            )
        )

        resolved_mod -- return
    ),

    /* isPanelReady - retained native modifier operation. */
    function isPanelReady scene_node =
    (
        is_ready = false

        if isValidNode scene_node then
        (
            current_entry = modPanel.getCurrentObject()

            if current_entry != undefined then
            (
                is_ready = current_entry == scene_node.baseObject

                if not is_ready then
                (
                    is_ready = (this.getStackIndex scene_node current_entry) > 0
                )
            )
        )

        is_ready -- return
    ),

    /* writeProperty - retained native modifier operation. */
    function writeProperty scene_node target_mods property_name value_data =
    (
        changed_count = 0
        this.last_error = ""

        if isValidNode scene_node then
        (
            undo "Modifier Set Stack remote edit" on
            (
                for target_mod in target_mods do
                (
                    if (this.getStackIndex scene_node target_mod) > 0 and isProperty target_mod property_name then
                    (
                        try
                        (
                            setProperty target_mod property_name value_data
                            changed_count += 1
                        )
                        catch
                        (
                            this.last_error = getCurrentException() as string
                            format "Modifier Set Stack write failed: %\n" this.last_error
                        )
                    )
                )
            )
        )

        changed_count -- return
    ),

    /* readCommonProperty - retained native modifier operation. */
    function readCommonProperty target_mods property_name =
    (
        result_value = undefined
        has_value = false
        is_mixed = false
        valid_count = 0

        for target_mod in target_mods do
        (
            if target_mod != undefined and isProperty target_mod property_name then
            (
                current_value = getProperty target_mod property_name
                valid_count += 1

                if not has_value then
                (
                    result_value = current_value
                    has_value = true
                )
                else if result_value != current_value then
                (
                    is_mixed = true
                )
            )
        )

        #(result_value, has_value, is_mixed, valid_count) -- return
    ),

    /* getSelectedSymmetryContexts - retained native modifier operation. */
    function getSelectedSymmetryContexts =
    (
        context_pairs = #()
        for scene_node in selection where isValidNode scene_node do
        (
            for target_mod in scene_node.modifiers where classOf target_mod == Symmetry do
            (
                append context_pairs #(scene_node, target_mod)
            )
        )
        context_pairs -- return
    ),

    /* getSymmetryWorldPosition - retained native modifier operation. */
    function getSymmetryWorldPosition scene_node target_mod =
    (
        world_position = undefined
        if isValidNode scene_node and classOf target_mod == Symmetry and (this.getStackIndex scene_node target_mod) > 0 then
        (
            try
            (
                context_tm = getModContextTM scene_node target_mod
                world_position = target_mod.mirror.position * (inverse context_tm) * scene_node.objectTransform
            )
            catch
            (
                this.last_error = getCurrentException() as string
                format "Modifier Set Stack | Symmetry world position failed | node:% modifier:% error:%\n" scene_node.name target_mod.name this.last_error
            )
        )
        else
        (
            format "Modifier Set Stack | Symmetry world position: invalid (node, modifier) reference.\n"
        )
        world_position -- return Point3 or undefined on failure
    ),

    /* symmetryPositionMatches - retained native modifier operation. */
    function symmetryPositionMatches expected_pos actual_pos position_precision =
    (
        matches = false
        if position_precision > 0.0 and isKindOf expected_pos Point3 and isKindOf actual_pos Point3 then
        (
            expected_x = (round (expected_pos.x / position_precision)) * position_precision
            expected_y = (round (expected_pos.y / position_precision)) * position_precision
            expected_z = (round (expected_pos.z / position_precision)) * position_precision
            actual_x = (round (actual_pos.x / position_precision)) * position_precision
            actual_y = (round (actual_pos.y / position_precision)) * position_precision
            actual_z = (round (actual_pos.z / position_precision)) * position_precision
            expected_rounded = [expected_x, expected_y, expected_z]
            actual_rounded = [actual_x, actual_y, actual_z]
            matches = expected_rounded == actual_rounded
            if not matches then
            (
                format "Modifier Set Stack | Symmetry mismatch | target raw:% actual raw:% target rounded:% actual rounded:% precision:%\n" \
                    expected_pos actual_pos expected_rounded actual_rounded position_precision
            )
        )
        else
        (
            format "Modifier Set Stack | Invalid symmetry position comparison | expected:% actual:% precision:%\n" \
                expected_pos actual_pos position_precision
        )
        matches -- return
    ),

    /* alignSymmetryPlanes - retained native modifier operation. */
    function alignSymmetryPlanes context_pairs desired_world position_precision =
    (
        success_count = 0
        expected_count = context_pairs.count
        success_value = false
        prepared = #()
        this.last_error = ""
        operation_ok = expected_count > 0 and isKindOf desired_world Point3 and position_precision > 0.0

        if not operation_ok then
        (
            this.last_error = "At least one Symmetry context, a world Point3 and valid position precision are required."
            format "Modifier Set Stack | Symmetry preflight failed | count:% world:% precision:%\n" expected_count desired_world position_precision
        )

        /* Prepare every node-specific matrix before changing any scene data. */
        if operation_ok then
        (
            for context_pair in context_pairs while operation_ok do
            (
                scene_node = context_pair[1]
                target_mod = context_pair[2]
                if not (isValidNode scene_node) or classOf target_mod != Symmetry or (this.getStackIndex scene_node target_mod) == 0 then
                (
                    operation_ok = false
                    this.last_error = "Target is not a live Symmetry modifier on its node."
                    format "Modifier Set Stack | Symmetry invalid target | node:% modifier:%\n" scene_node target_mod
                )
                else
                (
                    /* getModContextTM can throw on invalid native context.
                       A non-invertible object transform is also rejected here.
                    */
                    try
                    (
                        old_context_tm = getModContextTM scene_node target_mod
                        target_obj_pos = desired_world * (inverse scene_node.objectTransform)
                        linear_tm = matrix3 old_context_tm.row1 old_context_tm.row2 old_context_tm.row3 [0,0,0]
                        new_context_tm = copy old_context_tm
                        new_context_tm.row4 = target_mod.mirror.position - (target_obj_pos * linear_tm)
                        append prepared #(scene_node, target_mod, old_context_tm, new_context_tm)
                    )
                    catch
                    (
                        operation_ok = false
                        this.last_error = getCurrentException() as string
                        format "Modifier Set Stack | Symmetry context preflight failed | node:% modifier:% world:% error:%\n" \
                            scene_node.name target_mod.name desired_world this.last_error
                    )
                )
            )
        )

        if operation_ok then
        (
            /* Keep all writes in one undo record; rollback if any target fails. */
            undo "Align Symmetry Planes In World" on
            (
                for prepared_pair in prepared while operation_ok do
                (
                    scene_node = prepared_pair[1]
                    target_mod = prepared_pair[2]
                    new_context_tm = prepared_pair[4]
                    try
                    (
                        setModContextTM scene_node target_mod new_context_tm
                        actual_world = this.getSymmetryWorldPosition scene_node target_mod
                        if actual_world != undefined and (this.symmetryPositionMatches desired_world actual_world position_precision) then
                        (
                            success_count += 1
                        )
                        else
                        (
                            operation_ok = false
                            this.last_error = "Mirror origin did not reach the requested world position."
                            format "Modifier Set Stack | Symmetry postcondition failed | node:% modifier:% expected:% actual:% precision:%\n" \
                                scene_node.name target_mod.name desired_world actual_world position_precision
                        )
                    )
                    catch
                    (
                        operation_ok = false
                        this.last_error = getCurrentException() as string
                        format "Modifier Set Stack | Symmetry alignment failed | node:% modifier:% error:%\n" scene_node.name target_mod.name this.last_error
                    )
                )

                /* Changing another instanced modifier context must not move earlier planes.
                   Confirm all world origins after the entire batch has been applied.
                */
                if operation_ok then
                (
                    for prepared_pair in prepared while operation_ok do
                    (
                        scene_node = prepared_pair[1]
                        target_mod = prepared_pair[2]
                        actual_world = this.getSymmetryWorldPosition scene_node target_mod
                        if actual_world == undefined or not (this.symmetryPositionMatches desired_world actual_world position_precision) then
                        (
                            operation_ok = false
                            this.last_error = "Final Symmetry plane world position changed during batch."
                            format "Modifier Set Stack | Symmetry batch verification failed | node:% modifier:% expected:% actual:% precision:%\n" \
                                scene_node.name target_mod.name desired_world actual_world position_precision
                        )
                    )
                )

                if not operation_ok then
                (
                    for prepared_pair in prepared do
                    (
                        try
                        (
                            setModContextTM prepared_pair[1] prepared_pair[2] prepared_pair[3]
                        )
                        catch
                        (
                            rollback_error = getCurrentException() as string
                            format "Modifier Set Stack | Symmetry rollback FAILED | node:% modifier:% error:%\n" \
                                prepared_pair[1] prepared_pair[2] rollback_error
                        )
                    )
                    success_count = 0
                )
            )
        )

        success_value = operation_ok and success_count == expected_count
        if success_value then redrawViews()
        #(success_count, expected_count, success_value) -- return
    ),

    on create do
    (
        active_node = undefined
        last_error = ""
    )
)

modifierManager = modifierManager_v()

