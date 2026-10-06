/* Material-ID-Manager_UI_TEST_0.061.ms
   File version: 0.061
   Project version: 0.061
   Tests one shared native rollout stack, requested rollout order, and native collapse state.
*/

global material_id_manager_ui_test_file_version = 0.061
global material_id_manager_ui_test_project_version = 0.061

global materialIdManagerRollout
global materialIdManagerSceneDataRollout
global materialIdManagerMaterialSetupRollout
global materialIdManagerIdsRollout
global materialIdManagerEditMeshRollout
global materialIdManagerSelectFacesRollout

/*
Requires one UI test condition and stops on failure.
The failure text identifies the exact UI contract that failed.
*/
function requireMaterialIdManagerUiTest test_condition failure_text =
(
    if not test_condition then
    (
        throw failure_text
    )

    true -- return
)

/*
PART 1 verifies that all production rollouts live in one shared subRollout.
It also verifies Material Setup is directly above Material IDs in native stack order.
*/
function partOfTest1 =
(
    requireMaterialIdManagerUiTest (materialIdManagerRollout != undefined) "PART 1: Material ID Manager must be loaded before the UI test."

    rollout_stack = materialIdManagerRollout.sub_rollouts.rollouts

    requireMaterialIdManagerUiTest (rollout_stack.count == 5) "PART 1: Expected exactly five rollouts in the shared native subRollout."
    requireMaterialIdManagerUiTest (rollout_stack[1] == materialIdManagerSceneDataRollout) "PART 1: Scene Data is not first."
    requireMaterialIdManagerUiTest (rollout_stack[2] == materialIdManagerMaterialSetupRollout) "PART 1: Material Setup is not second."
    requireMaterialIdManagerUiTest (rollout_stack[3] == materialIdManagerIdsRollout) "PART 1: Material IDs is not directly below Material Setup."
    requireMaterialIdManagerUiTest (rollout_stack[4] == materialIdManagerEditMeshRollout) "PART 1: EDIT MESH is not fourth."
    requireMaterialIdManagerUiTest (rollout_stack[5] == materialIdManagerSelectFacesRollout) "PART 1: Material Select Modifier Sets is not fifth."

    format "PART 1 PASS - all rollouts share one native subRollout in the requested order.\n"
    true -- return
)

/*
PART 2 verifies native rollout open/closed state inside the shared slot.
Closing Material Setup must not force Material IDs closed, and both states are restored after the test.
*/
function partOfTest2 =
(
    original_setup_open = materialIdManagerMaterialSetupRollout.open
    original_ids_open = materialIdManagerIdsRollout.open

    materialIdManagerMaterialSetupRollout.open = true
    materialIdManagerIdsRollout.open = true

    materialIdManagerMaterialSetupRollout.open = false

    requireMaterialIdManagerUiTest (not materialIdManagerMaterialSetupRollout.open) "PART 2: Material Setup did not roll up natively."
    requireMaterialIdManagerUiTest materialIdManagerIdsRollout.open "PART 2: Rolling up Material Setup incorrectly closed Material IDs."

    materialIdManagerMaterialSetupRollout.open = true
    requireMaterialIdManagerUiTest materialIdManagerMaterialSetupRollout.open "PART 2: Material Setup did not roll down natively."

    materialIdManagerMaterialSetupRollout.open = original_setup_open
    materialIdManagerIdsRollout.open = original_ids_open

    format "PART 2 PASS - child rollouts roll up/down independently in the shared native slot.\n"
    true -- return
)

/*
PART 3 verifies the Scene Data controls fit below the five-row list region.
This guards the requested list expansion from overlapping the transform-lock checkbox.
*/
function partOfTest3 =
(
    list_bottom = materialIdManagerSceneDataRollout.lb_data_nodes.pos.y + materialIdManagerSceneDataRollout.lb_data_nodes.height
    checkbox_top = materialIdManagerSceneDataRollout.chk_lock_transforms.pos.y
    checkbox_bottom = checkbox_top + materialIdManagerSceneDataRollout.chk_lock_transforms.height

    requireMaterialIdManagerUiTest (checkbox_top > list_bottom) "PART 3: Scene Data transform-lock checkbox overlaps the list box."
    requireMaterialIdManagerUiTest (materialIdManagerSceneDataRollout.height >= checkbox_bottom) "PART 3: Scene Data rollout is too short for the five-row list and transform-lock control."

    format "PART 3 PASS - Scene Data list and transform-lock control do not overlap.\n"
    true -- return
)

partOfTest1()
partOfTest2()
partOfTest3()

format "\nMaterial ID Manager UI TEST 0.061 PASSED.\n"
