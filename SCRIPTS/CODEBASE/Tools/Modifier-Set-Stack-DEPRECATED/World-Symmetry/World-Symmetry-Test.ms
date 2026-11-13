/* World-Symmetry-Test.ms
   Run in an EMPTY disposable scene after loading World-Symmetry-Core.ms.
   The script creates and deletes one temporary box.
*/

/*
Tests exact naming, axis/Flip behavior, and world-plane position compensation.
Stops service and restores the selection after the fixture test.
*/
function testWorldSymmetry =
(
    if objects.count != 0 then
    (
        format "TEST ABORT | use an empty scene; object count:%\n" objects.count
        false
    )
    else
    (
        local test_node = box name:"WORLD_SYMMETRY_TEST_BOX"
        local target_mod = undefined
        local result_ok = false
        try
        (
            target_mod = worldSymmetrySelectOrAdd test_node 0 false
            local name_ok = target_mod.name == "--- WORLD SYMMETRY X ---"
            local again_mod = worldSymmetrySelectOrAdd test_node 2 true
            local reuse_ok = (again_mod == target_mod and test_node.modifiers.count == 1 and target_mod.axis == 0)
            local axis_ok = worldSymmetrySetAxis test_node 1
            local flip_ok = worldSymmetrySetFlip test_node true
            local settings_ok = axis_ok and flip_ok and target_mod.axis == 1 and target_mod.flip == true and target_mod.name == "--- WORLD SYMMETRY Y ---"
            local world_before = target_mod.mirror.value * test_node.transform
            local running_ok = worldSymmetryStartService()
            test_node.position = [100,20,30]
            completeRedraw()
            local world_after = target_mod.mirror.value * test_node.transform
            result_ok = name_ok and reuse_ok and settings_ok and running_ok and (world_before == world_after)
            format "WORLD SYMMETRY TEST | names:% reuse:% settings:% service:% world_lock:%\n" name_ok reuse_ok settings_ok running_ok (world_before == world_after)
            format "WORLD SYMMETRY TEST | expected world matrix:% | actual:%\n" world_before world_after
        )
        catch
        (
            local exception_text = getCurrentException()
            format "WORLD SYMMETRY TEST ERROR | %\n" exception_text
            result_ok = false
        )
        worldSymmetryStopService()
        if isValidNode test_node then delete test_node
        clearSelection()
        result_ok
    )
    -- return
)

format "WORLD SYMMETRY TEST RESULT: %\n" (testWorldSymmetry())
