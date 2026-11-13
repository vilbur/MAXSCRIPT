/* Modifier-Sets - independent tool backend.
   File version: 0.001 | Project version: 0.001.
   Split from Modifier-Set-Stack v0.087 without modifying the source.
*/
global modifier_sets_project_version = 0.001
global modifierSets
global modifier_sets_scene_ca

modifier_sets_scene_ca = attributes modifierSetStackSceneCA version:1 attribID:#(0x71A938F2, 0x5D08A422)
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

/* Backend functions are callable without loading a UI. */
struct modifierSets_v
(
    active_node = undefined,
    last_error = "",

    /* getStore - retained native modifier operation. */
    function getStore create:false =
    (
        store_value = custAttributes.get rootNode modifier_sets_scene_ca baseObject:false

        if store_value == undefined and create then
        (
            custAttributes.add rootNode modifier_sets_scene_ca baseObject:false
            store_value = custAttributes.get rootNode modifier_sets_scene_ca baseObject:false
        )

        store_value -- return
    ),

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

    /* findGroup - retained native modifier operation. */
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

    /* addGroup - retained native modifier operation. */
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

    /* renameGroup - retained native modifier operation. */
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

    /* deleteGroup - retained native modifier operation. */
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

    /* findRecord - retained native modifier operation. */
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

    /* getGroupId - retained native modifier operation. */
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

    /* assignGroup - retained native modifier operation. */
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

    /* cleanStaleRecords - retained native modifier operation. */
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

    /* getGroupModifiers - retained native modifier operation. */
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

    /* setEnabled - retained native modifier operation. */
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

    on create do
    (
        active_node = undefined
        last_error = ""
    )
)

modifierSets = modifierSets_v()
