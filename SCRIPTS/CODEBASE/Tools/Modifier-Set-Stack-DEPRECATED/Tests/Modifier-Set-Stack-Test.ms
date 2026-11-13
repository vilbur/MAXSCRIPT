/* Modifier Set Stack - isolated core smoke tests.
   File version: 0.020 | Project version: 0.086.
   Creates a temporary object and preserves current user selection.
*/

global modifier_set_stack_project_version
global modifier_set_stack_file_version_test = 0.020
global modifier_set_stack_stored_project_version_test = 0.086
global modifierSetStack

if modifier_set_stack_project_version == undefined or modifier_set_stack_stored_project_version_test > modifier_set_stack_project_version then
(
    modifier_set_stack_project_version = modifier_set_stack_stored_project_version_test
)

if modifierSetStack == undefined then
(
    fileIn ((getFilenamePath (getSourceFileName())) + "..\\Modifier-Set-Stack-FN.ms")
)

/* Fail early if one concrete core behavior is not respected.
   Test assertions intentionally leave a descriptive Listener message.
*/
function mssAssert condition_value message_text =
(
    if not condition_value then throw message_text
    true -- return
)

/* Exercise scene references, set reassignment, and direct remote parameters.
   Runs on a fresh test object, does not reset or save the current scene.
*/
function mssRunTests =
(
    saved_selection = for scene_node in selection collect scene_node
    test_node = undefined
    test_group_id = 0
    success_value = true
    error_text = ""

    try
    (
        test_node = box name:(uniqueName "MSS_TEST_") length:25 width:25 height:25
        vol_a = VolumeSelect()
        mat_a = Materialmodifier()
        mat_b = Materialmodifier()
        push_a = Push()
        addModifier test_node vol_a
        addModifier test_node mat_a
        addModifier test_node mat_b
        addModifier test_node push_a
        select test_node

        mssAssert (test_node.modifiers.count == 4) "Expected four native modifiers."
        mssAssert ((modifierSetStack.getStackIndex test_node vol_a) > 0) "Volume Select not mapped."
        mssAssert ((modifierSetStack.resolveHandle test_node (getHandleByAnim vol_a)) == vol_a) "AnimHandle lookup failed."
        test_group_name = "MSS_ISOLATED_TEST_" + ((getHandleByAnim test_node) as string)
        test_group_id = modifierSetStack.addGroup test_group_name
        mssAssert (test_group_id > 0) "Group creation failed."
        mssAssert (modifierSetStack.assignGroup test_node vol_a test_group_id) "Assignment failed."
        mssAssert (modifierSetStack.assignGroup test_node mat_a test_group_id) "Second assignment failed."
        mssAssert ((modifierSetStack.getGroupModifiers test_node test_group_id).count == 2) "Group membership count incorrect."
        mssAssert (modifierSetStack.assignGroup test_node vol_a 0) "Ungroup assignment failed."
        mssAssert ((modifierSetStack.getGroupModifiers test_node test_group_id).count == 1) "Ungroup didn't take effect."

        mat_a.materialID = 3
        mat_b.materialID = 7
        mixed_info = modifierSetStack.readCommonProperty #(mat_a,mat_b) #materialID
        mssAssert (mixed_info[3] == true) "Mixed IDs not detected."
        count_value = modifierSetStack.writeProperty test_node #(mat_a,mat_b) #materialID 11
        mssAssert (count_value == 2) "Remote write failed."
        mssAssert (mat_a.materialID == 11 and mat_b.materialID == 11) "Values were not propagated."
        mssAssert ((modifierSetStack.writeProperty test_node #(vol_a) #volume 5) == 1) "Volume Select mode write failed."
        mssAssert ((modifierSetStack.writeProperty test_node #(vol_a) #matID 3) == 1) "Volume Select Material ID write failed."
        mssAssert (vol_a.volume == 5 and vol_a.matID == 3) "Volume Select changes did not persist."
        mssAssert ((modifierSetStack.writeProperty test_node #(push_a) #Push_Value 2.5) == 1) "Push write failed."
        mssAssert (abs (push_a.Push_Value - 2.5) < 0.0001) "Push value was not updated."
        count_value = modifierSetStack.setEnabled test_node #(mat_a,mat_b) false
        mssAssert (mat_a.enabled == false and mat_b.enabled == false) "Bulk OFF failed."
        count_value = modifierSetStack.setEnabled test_node #(mat_a,mat_b) #toggle
        mssAssert (mat_a.enabled == true and mat_b.enabled == true) "Bulk Toggle failed."
        mssAssert (modifierSetStack.deleteGroup test_group_id) "Group deletion failed."
        test_group_id = 0
    )
    catch
    (
        success_value = false
        error_text = getCurrentException() as string
        format "Modifier Set Stack TEST FAILED: %\n" error_text
    )

    if test_group_id > 0 then modifierSetStack.deleteGroup test_group_id
    if isValidNode test_node then delete test_node
    modifierSetStack.cleanStaleRecords()
    select saved_selection
    if success_value then format "Modifier Set Stack TEST PASSED.\n"
    success_value -- return
)

mssRunTests()

/* Verify world-space Symmetry alignment with shared modifier instances.
   Tests independent nodes, different object transforms, and rollback preflight.
*/
function mssRunSymmetryTests =
(
    saved_selection = for scene_node in selection collect scene_node
    test_nodes = #()
    success_value = true
    error_text = ""

    try
    (
        node_a = box name:(uniqueName "MSS_SYM_A_") length:20 width:30 height:10 pos:[85,20,40]
        node_b = box name:(uniqueName "MSS_SYM_B_") length:20 width:30 height:10 pos:[-44,105,-35]
        node_c = box name:(uniqueName "MSS_SYM_C_") length:20 width:30 height:10 pos:[35,-55,70]
        test_nodes = #(node_a, node_b, node_c)
        node_b.rotation = eulerAngles 0 0 35
        node_c.scale = [1.5, 0.75, 2.0]

        shared_sym = Symmetry()
        separate_sym = Symmetry()
        second_sym = Symmetry()
        addModifier #(node_a,node_b) shared_sym
        addModifier node_a second_sym
        addModifier node_c separate_sym
        mssAssert ((modifierSetStack.getStackIndex node_a shared_sym) > 0 and \
            (modifierSetStack.getStackIndex node_b shared_sym) > 0) "Expected a shared Symmetry modifier instance."

        shared_sym.mirror.position = [2,3,4]
        separate_sym.mirror.position = [-5,1,9]
        second_sym.mirror.position = [8,-3,2]
        shared_original_pos = shared_sym.mirror.position
        original_axis = shared_sym.axis
        target_world = [14.25, -20.5, 33.75]
        position_precision = units.decodeValue "0.01mm"

        select test_nodes
        context_pairs = modifierSetStack.getSelectedSymmetryContexts()
        mssAssert (context_pairs.count == 4) "Expected all four Symmetry contexts across selected nodes."
        result_info = modifierSetStack.alignSymmetryPlanes context_pairs target_world position_precision
        mssAssert result_info[3] "Instanced Symmetry plane alignment failed."
        mssAssert (result_info[1] == 4) "Unexpected number of aligned Symmetry planes."
        mssAssert (shared_sym.mirror.position == shared_original_pos) "Shared Mirror local controller was changed."
        mssAssert (shared_sym.axis == original_axis) "Symmetry axis was changed."
        mssAssert ((modifierSetStack.getStackIndex node_a shared_sym) > 0 and \
            (modifierSetStack.getStackIndex node_b shared_sym) > 0) "Symmetry instancing was broken."
        for context_pair in context_pairs do
        (
            actual_world = modifierSetStack.getSymmetryWorldPosition context_pair[1] context_pair[2]
            mssAssert (modifierSetStack.symmetryPositionMatches target_world actual_world position_precision) \
                ("Plane not aligned on " + context_pair[1].name)
        )

        /* An unresolved target must abort before changing any valid context. */
        before_world = modifierSetStack.getSymmetryWorldPosition node_a shared_sym
        invalid_sym = Symmetry()
        invalid_pairs = #( #(node_a,shared_sym), #(node_a,invalid_sym) )
        result_info = modifierSetStack.alignSymmetryPlanes invalid_pairs [0,0,0] position_precision
        mssAssert (result_info[3] == false) "Invalid Symmetry batch unexpectedly succeeded."
        after_world = modifierSetStack.getSymmetryWorldPosition node_a shared_sym
        mssAssert (modifierSetStack.symmetryPositionMatches before_world after_world position_precision) \
            "Invalid batch changed an existing Symmetry plane."
    )
    catch
    (
        success_value = false
        error_text = getCurrentException() as string
        format "Modifier Set Stack SYMMETRY TEST FAILED: %\n" error_text
    )

    for scene_node in test_nodes where isValidNode scene_node do delete scene_node
    select saved_selection
    if success_value then format "Modifier Set Stack SYMMETRY TEST PASSED.\n"
    success_value -- return
)

mssRunSymmetryTests()
