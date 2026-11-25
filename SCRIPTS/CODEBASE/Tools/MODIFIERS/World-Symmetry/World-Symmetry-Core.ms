/* World-Symmetry-Core.ms
   Development module 0.001, 2026-10-23.
   Independent MAXScript feature core; no UI dependencies.
   Change handlers are session-only and intentionally ignore animation.
*/

global world_symmetry_entries = #()
global world_symmetry_handler = undefined
global world_symmetry_running = false
global world_symmetry_updating = false

/*
Returns the exact managed stack name for axis 0 (X), 1 (Y), or 2 (Z).
Returns undefined for an invalid axis.
*/
function worldSymmetryNameForAxis axis_index =
(
    case axis_index of
    (
        0: "--- WORLD SYMMETRY X ---"
        1: "--- WORLD SYMMETRY Y ---"
        2: "--- WORLD SYMMETRY Z ---"
        default: undefined
    )
    -- return
)

/*
Recognizes only native Symmetry modifiers with an exact managed name.
Does not claim or modify ordinary user Symmetry modifiers.
*/
function worldSymmetryIsManaged stack_mod =
(
    (classOf stack_mod == Symmetry) and
    (
        stack_mod.name == "--- WORLD SYMMETRY X ---" or
        stack_mod.name == "--- WORLD SYMMETRY Y ---" or
        stack_mod.name == "--- WORLD SYMMETRY Z ---"
    )
    -- return
)

/*
Finds the currently active managed Symmetry first, otherwise the topmost match.
Returns undefined if the node has no managed Symmetry modifier.
*/
function worldSymmetryFind target_node =
(
    local matching_mod = undefined
    if isValidNode target_node then
    (
        if getCommandPanelTaskMode() == #modify then
        (
            local current_mod = modPanel.getCurrentObject()
            for stack_mod in target_node.modifiers while matching_mod == undefined do
            (
                if stack_mod == current_mod and worldSymmetryIsManaged stack_mod then
                (
                    matching_mod = stack_mod
                )
            )
        )
        if matching_mod == undefined then
        (
            for stack_mod in target_node.modifiers while matching_mod == undefined do
            (
                if worldSymmetryIsManaged stack_mod then matching_mod = stack_mod
            )
        )
    )
    matching_mod
    -- return
)

/*
Creates the requested managed Symmetry only if none exists on this node.
Otherwise activates the existing modifier without changing its settings.
*/
function worldSymmetrySelectOrAdd target_node axis_index flip_enabled =
(
    local result_mod = undefined
    local new_name = worldSymmetryNameForAxis axis_index
    if not isValidNode target_node then
    (
        format "WORLD SYMMETRY ERROR | invalid target node: %\n" target_node
    )
    else if new_name == undefined then
    (
        format "WORLD SYMMETRY ERROR | invalid axis index: %\n" axis_index
    )
    else
    (
        result_mod = worldSymmetryFind target_node
        if result_mod == undefined then
        (
            local created_mod = Symmetry()
            created_mod.axis = axis_index
            created_mod.flip = flip_enabled
            created_mod.name = new_name
            undo "Add World Symmetry" on
            (
                addModifier target_node created_mod
            )
            result_mod = created_mod
        )
        max modify mode
        modPanel.setCurrentObject result_mod node:target_node
        if modPanel.getCurrentObject() != result_mod then
        (
            format "WORLD SYMMETRY ERROR | failed to activate modifier | node:% | mod:%\n" target_node.name result_mod.name
        )
    )
    result_mod
    -- return
)

/*
Changes the selected managed Symmetry's axis and exact stack name.
Does not add a modifier or alter unrelated Symmetry instances.
*/
function worldSymmetrySetAxis target_node axis_index =
(
    local result_ok = false
    local new_name = worldSymmetryNameForAxis axis_index
    if not isValidNode target_node or new_name == undefined then
    (
        format "WORLD SYMMETRY ERROR | SetAxis | node:% axis:%\n" target_node axis_index
    )
    else
    (
        local target_mod = worldSymmetryFind target_node
        if target_mod != undefined then
        (
            undo "World Symmetry Axis" on
            (
                target_mod.axis = axis_index
                target_mod.name = new_name
            )
            result_ok = true
        )
        else
        (
            format "WORLD SYMMETRY ERROR | no managed modifier on node:%\n" target_node.name
        )
    )
    result_ok
    -- return
)

/*
Sets Flip on the managed Symmetry of the supplied node.
Does not add a modifier.
*/
function worldSymmetrySetFlip target_node flip_enabled =
(
    local target_mod = worldSymmetryFind target_node
    if target_mod != undefined then
    (
        undo "World Symmetry Flip" on
        (
            target_mod.flip = flip_enabled
        )
        true
    )
    else
    (
        format "WORLD SYMMETRY ERROR | Flip | no managed Symmetry on node:%\n" target_node
        false
    )
    -- return
)

/*
Counts tracked modifier instances in the currently running service.
Returns zero while the service is stopped.
*/
function worldSymmetryTrackedCount =
(
    if world_symmetry_running then world_symmetry_entries.count else 0
    -- return
)

/*
Ends only this service's registered change handler and clears its cached state.
No modifier, geometry, or external callback is deleted.
*/
function worldSymmetryStopService =
(
    deleteAllChangeHandlers id:#worldSymmetryTransformService
    world_symmetry_handler = undefined
    world_symmetry_entries = #()
    world_symmetry_running = false
    world_symmetry_updating = false
    true
    -- return
)

/*
Updates the gizmo of each managed modifier on a node after an actual TM change.
The captured world plane is held by compensating with inverse node TM.
*/
function worldSymmetryOnNodeChanged changed_node =
(
    if world_symmetry_running and not world_symmetry_updating and isValidNode changed_node then
    (
        world_symmetry_updating = true
        try
        (
            local new_node_tm = changed_node.transform
            for entry_index = 1 to world_symmetry_entries.count do
            (
                local entry = world_symmetry_entries[entry_index]
                if entry[1] == changed_node and new_node_tm != entry[4] then
                (
                    local stack_mod = entry[2]
                    local still_present = false
                    for candidate_mod in changed_node.modifiers while not still_present do
                    (
                        if candidate_mod == stack_mod then still_present = true
                    )
                    if still_present and worldSymmetryIsManaged stack_mod then
                    (
                        stack_mod.mirror.value = entry[3] * (inverse new_node_tm)
                        entry[4] = new_node_tm
                    )
                    else
                    (
                        format "WORLD SYMMETRY WARNING | tracked modifier removed/renamed | node:%\n" changed_node.name
                    )
                )
            )
        )
        catch
        (
            local exception_text = getCurrentException()
            format "WORLD SYMMETRY ERROR | transform handler | node:% | %\n" changed_node.name exception_text
            world_symmetry_updating = false
            worldSymmetryStopService()
        )
        world_symmetry_updating = false
    )
    true
    -- return
)

/*
Scans scene geometry and registers one redraw-deferred transform handler.
Captures each managed gizmo's current world transform as its lock anchor.
*/
function worldSymmetryStartService =
(
    worldSymmetryStopService()
    local watched_nodes = #()
    local seen_mods = #()
    local invalid_instance_count = 0
    for target_node in geometry do
    (
        for stack_mod in target_node.modifiers do
        (
            if worldSymmetryIsManaged stack_mod then
            (
                if (findItem seen_mods stack_mod) > 0 then
                (
                    invalid_instance_count += 1
                    format "WORLD SYMMETRY ERROR | instanced managed Symmetry is shared | node:% | mod:%\n" target_node.name stack_mod.name
                )
                else
                (
                    append seen_mods stack_mod
                    append world_symmetry_entries #(target_node, stack_mod, (stack_mod.mirror.value * target_node.transform), target_node.transform)
                    if (findItem watched_nodes target_node) == 0 then append watched_nodes target_node
                )
            )
        )
    )
    if invalid_instance_count > 0 then
    (
        format "WORLD SYMMETRY ERROR | start aborted | shared modifier instances:%\n" invalid_instance_count
        worldSymmetryStopService()
        false
    )
    else if watched_nodes.count == 0 then
    (
        format "WORLD SYMMETRY | no managed modifiers found. Service remains stopped.\n"
        worldSymmetryStopService()
        false
    )
    else
    (
        world_symmetry_handler = when transform watched_nodes changes id:#worldSymmetryTransformService handleAt:#redrawViews changed_node do
        (
            worldSymmetryOnNodeChanged changed_node
        )
        world_symmetry_running = true
        format "WORLD SYMMETRY | service started | nodes:% | modifiers:%\n" watched_nodes.count world_symmetry_entries.count
        true
    )
    -- return
)

/*
Refreshes registration after a new managed modifier has been added.
Existing active gizmo planes are recaptured in their current world position.
*/
function worldSymmetryRescanIfRunning =
(
    if world_symmetry_running then worldSymmetryStartService() else false
    -- return
)

/*
Prevents duplicate handlers when the feature file is reloaded.
*/
worldSymmetryStopService()
