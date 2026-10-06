/* Material-ID-Manager Scene Data test 0.060
   Tests rootNode managed records, unpaired Volume Select preservation, orphan recovery, relink, and transform locking.
*/

global materialIdManagerCore
global materialIdManagerSelectFacesRollout
global materialIdManagerSceneDataRollout
global material_id_manager_scene_data_test_record_id = 0
global material_id_manager_scene_data_test_replacement = undefined

/* Require one test condition and stop immediately on failure.
   A failed condition throws its exact test description.
*/
function requireSceneDataTest test_condition failure_text =
(
    if not test_condition then
    (
        throw failure_text
    )

    true -- return
)

/* Create one Editable Poly node used by the Scene Data test.
   The new node starts with every transform lock disabled.
*/
function createSceneDataTestNode node_name node_position =
(
    test_node = box name:node_name length:100.0 width:100.0 height:100.0 pos:node_position
    convertToPoly test_node
    test_node.showCage = off
    setTransformLockFlags test_node #none
    test_node -- return
)

/* PART 1: Create one managed source, remove its paired Material modifier, and persist the unpaired Volume Select.
   Verifies that Volume Select alone defines managed-node identity and that list refresh does not repair the deleted Material modifier.
*/
function partOfTest1 =
(
    requireSceneDataTest (materialIdManagerCore != undefined) "Material ID Manager must be loaded before this test."

    source_node = createSceneDataTestNode "MIDM_SCENE_DATA_TEST_SOURCE" [0,0,0]
    select source_node
    max modify mode
    modPanel.setCurrentObject source_node.baseObject node:source_node
    subObjectLevel = 0

    add_result = materialIdManagerCore.addVolumeSelect()
    requireSceneDataTest add_result "PART 1: Material ID Manager could not create the test Volume Select."

    stack_entries = materialIdManagerCore.getVolumeSelectStackEntries source_node
    requireSceneDataTest (stack_entries.count == 1) "PART 1: Expected exactly one Volume Select entry."

    volume_select_mod = stack_entries[1][2]
    material_mod = stack_entries[1][4]
    requireSceneDataTest (material_mod != undefined) "PART 1: The freshly created test set has no paired Material modifier."

    remove_material_result = materialIdManagerCore.removeModifierInstance source_node material_mod
    requireSceneDataTest remove_material_result "PART 1: Could not remove the paired Material modifier for the unpaired test."

    materialIdManagerSelectFacesRollout.refreshVolumeSelectList()
    stack_entries = materialIdManagerCore.getVolumeSelectStackEntries source_node
    requireSceneDataTest (stack_entries.count == 1) "PART 1: Volume Select disappeared after list refresh."
    requireSceneDataTest (stack_entries[1][4] == undefined) "PART 1: List refresh recreated the deleted Material modifier."

    sync_result = materialIdManagerCore.syncSceneDataNode source_node
    requireSceneDataTest sync_result "PART 1: Could not synchronize the managed source to rootNode Scene Data."

    scene_records = materialIdManagerCore.loadSceneDataRecords()
    record_index = materialIdManagerCore.findSceneDataRecordIndexByHandle scene_records source_node.inode.handle
    requireSceneDataTest (record_index > 0) "PART 1: No rootNode Scene Data record was created for the managed source."
    requireSceneDataTest (scene_records[record_index][5].count == 1) "PART 1: Stored record does not contain exactly one Volume Select backup."
    requireSceneDataTest (scene_records[record_index][5][1][1] == 0) "PART 1: Unpaired Volume Select was not stored with Material ID zero."

    material_id_manager_scene_data_test_record_id = scene_records[record_index][1]
    requireSceneDataTest ((getTransformLockFlags source_node).numberSet == 9) "PART 1: Managed source transforms are not fully locked."

    format "PART 1 PASS - managed source record ID: %\n" material_id_manager_scene_data_test_record_id
    true -- return
)

/* PART 2: Delete the original managed host and verify that its rootNode record survives as missing.
   This simulates the host disappearing through an attach/delete workflow without losing the recovery data.
*/
function partOfTest2 =
(
    source_node = getNodeByName "MIDM_SCENE_DATA_TEST_SOURCE" exact:true
    requireSceneDataTest (source_node != undefined and isValidNode source_node) "PART 2: Test source node is missing before deletion."

    delete source_node

    scene_records = materialIdManagerCore.loadSceneDataRecords()
    record_index = materialIdManagerCore.findSceneDataRecordIndexById scene_records material_id_manager_scene_data_test_record_id
    requireSceneDataTest (record_index > 0) "PART 2: RootNode Scene Data record disappeared with the source node."
    requireSceneDataTest (materialIdManagerCore.getSceneDataRecordNode scene_records[record_index] == undefined) "PART 2: Deleted source record did not become a missing-host record."

    materialIdManagerSceneDataRollout.refreshStoredList preferred_record_id:material_id_manager_scene_data_test_record_id
    format "PART 2 PASS - source deleted, rootNode recovery record remains.\n"
    true -- return
)

/* PART 3: Relink the missing record to a new Editable Poly and verify exact managed-state recovery.
   The restored Volume Select remains unpaired because the stored source was deliberately unpaired.
*/
function partOfTest3 =
(
    replacement_node = createSceneDataTestNode "MIDM_SCENE_DATA_TEST_REPLACEMENT" [200,0,0]
    material_id_manager_scene_data_test_replacement = replacement_node
    select replacement_node

    relink_result = materialIdManagerCore.relinkSceneDataRecord material_id_manager_scene_data_test_record_id replacement_node
    requireSceneDataTest relink_result "PART 3: Missing Scene Data record could not be relinked to the replacement node."

    stack_entries = materialIdManagerCore.getVolumeSelectStackEntries replacement_node
    requireSceneDataTest (stack_entries.count == 1) "PART 3: Replacement does not contain exactly one restored Volume Select."
    requireSceneDataTest (stack_entries[1][4] == undefined) "PART 3: Relink incorrectly recreated a Material modifier for the stored unpaired Volume Select."
    requireSceneDataTest ((getTransformLockFlags replacement_node).numberSet == 9) "PART 3: Relinked managed-node transforms are not fully locked."

    scene_records = materialIdManagerCore.loadSceneDataRecords()
    record_index = materialIdManagerCore.findSceneDataRecordIndexById scene_records material_id_manager_scene_data_test_record_id
    requireSceneDataTest (record_index > 0) "PART 3: Relinked rootNode record is missing."
    requireSceneDataTest (materialIdManagerCore.getSceneDataRecordNode scene_records[record_index] == replacement_node) "PART 3: RootNode record does not resolve to the replacement node."

    format "PART 3 PASS - missing record relinked to replacement.\n"
    true -- return
)

/* PART 4: Verify the scene-level transform-lock preference restores and reapplies locks.
   The test ends with locking enabled, matching the production default.
*/
function partOfTest4 =
(
    replacement_node = material_id_manager_scene_data_test_replacement
    requireSceneDataTest (replacement_node != undefined and isValidNode replacement_node) "PART 4: Replacement node is not valid."

    unlock_result = materialIdManagerCore.setSceneDataTransformLockEnabled false
    requireSceneDataTest unlock_result "PART 4: Could not disable managed-node transform locking."
    requireSceneDataTest ((getTransformLockFlags replacement_node).numberSet == 0) "PART 4: Original replacement transform lock flags were not restored."

    lock_result = materialIdManagerCore.setSceneDataTransformLockEnabled true
    requireSceneDataTest lock_result "PART 4: Could not re-enable managed-node transform locking."
    requireSceneDataTest ((getTransformLockFlags replacement_node).numberSet == 9) "PART 4: Managed-node transform locking was not reapplied."

    materialIdManagerSceneDataRollout.refreshStoredList preferred_record_id:material_id_manager_scene_data_test_record_id
    format "PART 4 PASS - transform lock preference restores and reapplies correctly.\n"
    true -- return
)

undo "MIDM Scene Data Test 1 - Create Managed Source" on
(
    partOfTest1()
)

undo "MIDM Scene Data Test 2 - Delete Source" on
(
    partOfTest2()
)

undo "MIDM Scene Data Test 3 - Relink Replacement" on
(
    partOfTest3()
)

undo "MIDM Scene Data Test 4 - Transform Locks" on
(
    partOfTest4()
)

format "\nMaterial ID Manager Scene Data TEST 0.060 PASSED.\n"
format "Undo order:\n"
format "  1. Transform Locks\n"
format "  2. Relink Replacement\n"
format "  3. Delete Source\n"
format "  4. Create Managed Source\n"
