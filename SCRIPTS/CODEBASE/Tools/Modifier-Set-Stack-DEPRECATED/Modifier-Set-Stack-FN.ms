/* Modifier Set Stack - core data and operations.
   File version: 0.020 | Project version: 0.086 | Prototype.
*/

global modifier_set_stack_project_version
global modifier_set_stack_file_version = 0.020
global modifier_set_stack_stored_project_version = 0.086
global modifier_set_stack_scene_ca
global modifierSetStack

if modifier_set_stack_project_version == undefined or modifier_set_stack_stored_project_version > modifier_set_stack_project_version then
(
    modifier_set_stack_project_version = modifier_set_stack_stored_project_version
)

/* Keep persistent group membership as real scene references, not stack offsets.
   Each slot of member_* arrays has the same index; zero group ID means ungrouped.
*/
modifier_set_stack_scene_ca = attributes modifierSetStackSceneCA version:1 attribID:#(0x71A938F2, 0x5D08A422)
(
    parameters main
    (
        data_version type:#integer default:1
        group_names type:#stringTab tabSize:0 tabSizeVariable:true
        group_enabled type:#boolTab tabSize:0 tabSizeVariable:true
        member_nodes type:#nodeTab tabSize:0 tabSizeVariable:true
        member_mods type:#maxObjectTab tabSize:0 tabSizeVariable:true
        member_groups type:#intTab tabSize:0 tabSizeVariable:true
    )
)

/* Operates on real modifiers while preserving the native modifier stack.
   No UI controls or source-library dependencies are used here.
*/
struct modifierSetStack_v
(
    active_node = undefined,
    last_error = "",

    /* Locate scene storage and add the isolated CA only when requested.
       Reading data without create:true does not change the scene.
    */
    function getStore create:false =
    (
        store_value = custAttributes.get rootNode modifier_set_stack_scene_ca baseObject:false

        if store_value == undefined and create then
        (
            custAttributes.add rootNode modifier_set_stack_scene_ca baseObject:false
            store_value = custAttributes.get rootNode modifier_set_stack_scene_ca baseObject:false
        )

        store_value -- return
    ),

    /* Return the single currently selected scene node.
       Multi-object selection is deliberately not edited in version one.
    */
    function getSelectedNode =
    (
        scene_node = undefined

        if selection.count == 1 and isValidNode selection[1] then
        (
            scene_node = selection[1]
        )

        scene_node -- return
    ),

    /* Map one real modifier reference to the selected node's stack index.
       Child tracks such as Center and Gizmo are never enumerated.
    */
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

    /* Check that a handle still resolves to a modifier on the selected node.
       Handles are only UI-session identifiers, not persistent scene IDs.
    */
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

    /* Find the persistent index for a scene group by its exact name.
       Empty names are tombstones for deleted groups.
    */
    function findGroup group_name =
    (
        group_id = 0
        store_value = this.getStore()

        if store_value != undefined then
        (
            for index_value = 1 to store_value.group_names.count while group_id == 0 do
            (
                if store_value.group_names[index_value] == group_name and group_name != "" then
                (
                    group_id = index_value
                )
            )
        )

        group_id -- return
    ),

    /* Add a unique, nonempty group without disturbing previous IDs.
       Existing groups are returned rather than duplicated.
    */
    function addGroup group_name =
    (
        group_id = 0
        clean_name = trimLeft (trimRight group_name) " \t"

        if clean_name != "" then
        (
            group_id = this.findGroup clean_name

            if group_id == 0 then
            (
                store_value = this.getStore create:true
                group_id = store_value.group_names.count + 1
                store_value.group_names[group_id] = clean_name
                store_value.group_enabled[group_id] = true
            )
        )

        group_id -- return
    ),

    /* Rename a group if the target name is available.
       Membership references remain associated with its unchanged ID.
    */
    function renameGroup group_id group_name =
    (
        success_value = false
        clean_name = trimLeft (trimRight group_name) " \t"
        store_value = this.getStore()

        if store_value != undefined and group_id > 0 and group_id <= store_value.group_names.count and clean_name != "" then
        (
            existing_id = this.findGroup clean_name

            if existing_id == 0 or existing_id == group_id then
            (
                store_value.group_names[group_id] = clean_name
                success_value = true
            )
        )

        success_value -- return
    ),

    /* Remove a group non-destructively and ungroup its members.
       No modifier is deleted or rearranged in the native stack.
    */
    function deleteGroup group_id =
    (
        success_value = false
        store_value = this.getStore()

        if store_value != undefined and group_id > 0 and group_id <= store_value.group_names.count then
        (
            for record_index = 1 to store_value.member_groups.count do
            (
                if store_value.member_groups[record_index] == group_id then
                (
                    store_value.member_groups[record_index] = 0
                )
            )

            store_value.group_names[group_id] = ""
            store_value.group_enabled[group_id] = false
            success_value = true
        )

        success_value -- return
    ),

    /* Find membership of a concrete (node, modifier) pair.
       One modifier on each node has at most one active set membership.
    */
    function findRecord scene_node target_mod =
    (
        record_index = 0
        store_value = this.getStore()

        if store_value != undefined and isValidNode scene_node then
        (
            for index_value = 1 to store_value.member_groups.count while record_index == 0 do
            (
                if store_value.member_nodes[index_value] == scene_node and store_value.member_mods[index_value] == target_mod then
                (
                    record_index = index_value
                )
            )
        )

        record_index -- return
    ),

    /* Return a modifier's group ID, or zero for Ungrouped.
       A deleted group never appears as an assigned set.
    */
    function getGroupId scene_node target_mod =
    (
        group_id = 0
        record_index = this.findRecord scene_node target_mod
        store_value = this.getStore()

        if record_index > 0 and store_value != undefined then
        (
            group_id = store_value.member_groups[record_index]
            if group_id > store_value.group_names.count then group_id = 0
            if group_id > 0 and store_value.group_names[group_id] == "" then group_id = 0
        )

        group_id -- return
    ),

    /* Reassign a node's modifier, using CA references saved with the scene.
       Group ID zero removes its assignment without deleting the modifier.
    */
    function assignGroup scene_node target_mod group_id =
    (
        success_value = false

        if isValidNode scene_node and (this.getStackIndex scene_node target_mod) > 0 then
        (
            store_value = this.getStore create:true
            group_valid = group_id == 0

            if group_id > 0 and group_id <= store_value.group_names.count then
            (
                group_valid = store_value.group_names[group_id] != ""
            )

            if group_valid then
            (
                record_index = this.findRecord scene_node target_mod

                if record_index == 0 then
                (
                    record_index = store_value.member_groups.count + 1
                    store_value.member_nodes[record_index] = scene_node
                    store_value.member_mods[record_index] = target_mod
                )

                store_value.member_groups[record_index] = group_id
                success_value = true
            )
        )

        success_value -- return
    ),

    /* Remove obsolete scene references without shifting persistent record IDs.
       A removed modifier is recognized by verifying its actual node stack.
    */
    function cleanStaleRecords =
    (
        cleaned_count = 0
        store_value = this.getStore()

        if store_value != undefined then
        (
            for record_index = 1 to store_value.member_groups.count do
            (
                scene_node = store_value.member_nodes[record_index]
                target_mod = store_value.member_mods[record_index]
                is_stale = true

                if isValidNode scene_node and target_mod != undefined then
                (
                    is_stale = (this.getStackIndex scene_node target_mod) == 0
                )

                if is_stale then
                (
                    store_value.member_nodes[record_index] = undefined
                    store_value.member_mods[record_index] = undefined
                    store_value.member_groups[record_index] = 0
                    cleaned_count += 1
                )
            )
        )

        cleaned_count -- return
    ),

    /* Gather modifiers in a group, or all ungrouped modifiers for ID zero.
       The native stack, not the custom list, determines membership order.
    */
    function getGroupModifiers scene_node group_id =
    (
        result_mods = #()

        if isValidNode scene_node then
        (
            for target_mod in scene_node.modifiers do
            (
                if (this.getGroupId scene_node target_mod) == group_id then
                (
                    append result_mods target_mod
                )
            )
        )

        result_mods -- return
    ),

    /* Collect exactly one modifier class from the actual node stack.
       This is independent of current native TreeView expansion state.
    */
    function getTypeModifiers scene_node type_name =
    (
        result_mods = #()

        if isValidNode scene_node then
        (
            for target_mod in scene_node.modifiers do
            (
                if (classOf target_mod as string) == type_name then
                (
                    append result_mods target_mod
                )
            )
        )

        result_mods -- return
    ),

    /* Toggle enabled state of concrete valid modifiers only.
       The operation changes existing instances and never changes stack order.
    */
    function setEnabled scene_node target_mods state_value =
    (
        changed_count = 0

        if isValidNode scene_node then
        (
            for target_mod in target_mods do
            (
                if (this.getStackIndex scene_node target_mod) > 0 then
                (
                    desired_value = if state_value == #toggle then (not target_mod.enabled) else state_value
                    if target_mod.enabled != desired_value then
                    (
                        target_mod.enabled = desired_value
                        changed_count += 1
                    )
                )
            )
        )

        changed_count -- return
    ),

    /* Apply a confirmed native property to the verified target list.
       Shared modifier instances receive the same changes elsewhere in the scene.
    */
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

    /* Read one property across a selection without losing mixed-value state.
       Returns #(value, has_value, mixed, target_count).
    */
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

    /* Resolve all actual Symmetry modifiers from selected scene nodes.
       Node/modifier pairs retain independent modifier contexts even for shared instances.
    */
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

    /* Read the Mirror plane origin in world coordinates for a specific node.
       A shared Symmetry modifier can have different modifier contexts on each node.
    */
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

    /* Compare two world positions at an explicit millimeter-based precision.
       Only temporary comparison values are rounded; modifier coordinates remain raw.
    */
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

    /* Align one or many Mirror plane origins to one absolute world position.
       Change only each node's modifier context translation, never the shared
       modifier's Mirror controller, axis, rotation, scale, or instance links.
       Input pairs are #(scene_node, symmetry_mod). Returns #(count, total, success).
       Preflight all transforms first; a failed write attempts rollback of all contexts.
    */
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

    /* Check whether the Modify panel has resolved the currently selected node.
       This implements the self-contained onModifyStackReady source pattern.
    */
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

    on create do
    (
        active_node = undefined
        last_error = ""
    )
)

modifierSetStack = modifierSetStack_v()
