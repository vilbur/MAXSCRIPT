/* Modifier-Stack-Live - independent tool backend.
   File version: 0.001 | Project version: 0.001.
   Split from Modifier-Set-Stack v0.087 without modifying the source.
*/
global modifier_stack_live_project_version = 0.001
global modifierStackLive
/* Backend functions are callable without loading a UI. */
struct modifierStackLive_v
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

modifierStackLive = modifierStackLive_v()
