/*
Modifier Manager feature test.
File version 0.011 | Project version 0.011.
Run in a disposable 3ds Max 2023/2026 scene; test objects remain for inspection.
*/
global mm_test_mesh_a
global mm_test_mesh_b
global mm_test_source_mod
global mm_test_preset_id
global mm_test_chamfer_id

/*
Report a precise failed contract without suppressing the native exception.
The test stops at the first failed requirement.
*/
function testAssert condition_value description_text =
(
    if not condition_value then
    (
        format "MM TEST FAILED | %\n" description_text
        throw ("MM TEST FAILED | " + description_text)
    )
    true -- return
)

/*
Create the pair of objects used in instance and unique tests.
Leaves both objects in the scene for undo inspection.
*/
function partOfTest1 =
(
    undo "MM Test | Create Nodes" on
    (
        mm_test_mesh_a = box name:(uniqueName "MM_TEST_A_")
        mm_test_mesh_b = box name:(uniqueName "MM_TEST_B_") pos:[150,0,0]
    )
    testAssert (isValidNode mm_test_mesh_a and isValidNode mm_test_mesh_b) "Two test nodes created"
)

/*
Verify that saving MeshSmooth stores the native property snapshot in the scene.
The source instance is already attached to an actual object.
*/
function partOfTest2 =
(
    undo "MM Test | Save MeshSmooth" on
    (
        mm_test_source_mod = MeshSmooth()
        mm_test_source_mod.iterations = 2
        mm_test_source_mod.sepByMats = true
        mm_test_source_mod.sepBySmGroups = true
        addModifier mm_test_mesh_a mm_test_source_mod
        mm_test_settings = modifierPresetManager.readSettings #meshsmooth mm_test_source_mod
        mm_test_preset_id = modifierPresetManager.savePreset #meshsmooth mm_test_settings mm_test_source_mod
    )
    testAssert (mm_test_preset_id > 0) "Preset ID created"
    loaded_settings = modifierPresetManager.getPresetSettings #meshsmooth mm_test_preset_id
    testAssert (loaded_settings[1] == 2 and loaded_settings[4] == true and loaded_settings[5] == true) "MeshSmooth values saved and loaded"
)

/*
Confirm that shared Add attaches the exact source instance, while unique Add does not.
No existing modifiers are deleted by either action.
*/
function partOfTest3 =
(
    undo "MM Test | Add Shared And Unique" on
    (
        select mm_test_mesh_b
        shared_count = modifierPresetManager.addToSelection #meshsmooth mm_test_preset_id false
        testAssert (shared_count == 1) "Shared add affected one node"
        testAssert (mm_test_mesh_b.modifiers[1] == mm_test_source_mod) "Shared add uses exact instance"
        unique_count = modifierPresetManager.addToSelection #meshsmooth mm_test_preset_id true
        testAssert (unique_count == 1) "Unique add affected one node"
        testAssert (mm_test_mesh_b.modifiers[1] != mm_test_source_mod) "Unique add produced independent modifier"
        testAssert (mm_test_mesh_b.modifiers[2] == mm_test_source_mod) "Previous shared instance preserved"
    )
)

/*
Re-instance only one topmost same-type modifier on each selected object.
Verify stack counts and the other MeshSmooth copy stay unchanged.
*/
function partOfTest4 =
(
    previous_count = mm_test_mesh_b.modifiers.count
    undo "MM Test | Re-instance MeshSmooth" on
    (
        select #(mm_test_mesh_a, mm_test_mesh_b)
        replaced_count = modifierPresetManager.reinstanceSelection #meshsmooth mm_test_preset_id
        testAssert (replaced_count == 1) "Only one unique modifier replaced"
    )
    testAssert (mm_test_mesh_b.modifiers.count == previous_count) "Stack count preserved"
    testAssert (mm_test_mesh_b.modifiers[1] == mm_test_source_mod) "Topmost now shares preset instance"
    testAssert (mm_test_mesh_b.modifiers[2] == mm_test_source_mod) "Lower same-type modifier untouched"
)

/*
Verify Chamfer Inset parameters and native material/smoothing filters.
Readback must return the exact saved values.
*/
function partOfTest5 =
(
    chamfer_mod = Chamfer()
    chamfer_mod.amount = 3.0
    chamfer_mod.segments = 3
    chamfer_mod.addinset = true
    chamfer_mod.insetamount = 0.3
    chamfer_mod.insetoffset = 0.2
    chamfer_mod.insetsegments = 2
    chamfer_mod.materialoption = 1
    chamfer_mod.smoothingoption = 2
    chamfer_settings = modifierPresetManager.readSettings #chamfer chamfer_mod
    mm_test_chamfer_id = modifierPresetManager.savePreset #chamfer chamfer_settings undefined
    restored_chamfer = modifierPresetManager.getPresetSettings #chamfer mm_test_chamfer_id
    testAssert (restored_chamfer[1] == 3.0 and restored_chamfer[2] == 3) "Chamfer amount and segments restored"
    testAssert (restored_chamfer[10] == true and restored_chamfer[11] == 0.3 and restored_chamfer[12] == 0.2 and restored_chamfer[13] == 2) "One-row Inset values restored"
    testAssert (restored_chamfer[8] == 1 and restored_chamfer[9] == 2) "Material and smoothing filters restored"
)

/*
Attach unique Chamfers to both nodes and then re-instance them via the scene.
Verify that the native filter and Inset values survive real stack insertion.
*/
function partOfTestChamferApply =
(
    undo "MM Test | Chamfer Apply" on
    (
        select #(mm_test_mesh_a, mm_test_mesh_b)
        added_count = modifierPresetManager.addToSelection #chamfer mm_test_chamfer_id true
        testAssert (added_count == 2) "Unique Chamfer attached to both selected nodes"
        testAssert (mm_test_mesh_a.modifiers[1] != mm_test_mesh_b.modifiers[1]) "Unique Chamfer instances remain independent"
        replaced_count = modifierPresetManager.reinstanceSelection #chamfer mm_test_chamfer_id
        testAssert (replaced_count == 2) "Both native Chamfers re-instanced"
    )
    testAssert (mm_test_mesh_a.modifiers[1] == mm_test_mesh_b.modifiers[1]) "Native Chamfer instance now shared"
    testAssert (mm_test_mesh_a.modifiers[1].materialoption == 1) "Material filter preserved on real modifier"
    testAssert (mm_test_mesh_a.modifiers[1].addinset and mm_test_mesh_a.modifiers[1].insetsegments == 2) "Inset settings preserved on real modifier"
)

/*
Print the tested state and the meaning of each undo step.
The test deliberately leaves its objects and scene presets in the scene.
*/
function partOfTest6 =
(
    format "MM TEST | PASS | Presets:% MeshSmooth instances on B:%\n" mm_test_preset_id mm_test_mesh_b.modifiers.count
    format "UNDO ORDER | 1: Chamfer Apply | 2: Re-instance MeshSmooth | 3: Add Shared And Unique | 4: Save MeshSmooth | 5: Create Nodes\n"
    true -- return
)

/*
Load only the backend and shared preset engine, without opening the dialog.
Test one feature chain in its documented stage order.
*/
(
    source_folder = getFilenamePath (getSourceFileName())
    fileIn (source_folder + "Modifier-Manager-FN.ms")
    fileIn (source_folder + "Modifier-Manager-Presets.ms")
    partOfTest1()
    partOfTest2()
    partOfTest3()
    partOfTest4()
    partOfTest5()
    partOfTestChamferApply()
    partOfTest6()
)
