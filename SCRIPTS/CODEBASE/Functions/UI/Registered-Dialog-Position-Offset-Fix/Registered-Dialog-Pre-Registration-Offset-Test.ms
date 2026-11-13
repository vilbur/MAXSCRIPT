/*
Registered Dialog Pre-Registration Offset — four-button test dialog.
Version 0.04. Reusable methods live in Registered-Dialog-Pre-Registration-Offset.ms.
*/

global rdpf_pre_test_source = getSourceFileName()
global rdpf_pre_test_directory = getFilenamePath rdpf_pre_test_source
global rdpf_pre_test_ini = rdpf_pre_test_directory + "Registered-Dialog-Pre-Registration-Offset.ini"
global rdpf_pre_test_rollout

if rdpf_pre_test_rollout != undefined then
(
    if rdpf_pre_test_rollout.dialogBar then cui.UnRegisterDialogBar rdpf_pre_test_rollout
    try (destroyDialog rdpf_pre_test_rollout) catch (format "RDPF PRE | Old dialog cleanup: %\n" (getCurrentException()))
)

fileIn (rdpf_pre_test_directory + "Registered-Dialog-Pre-Registration-Offset.ms")

rollout rdpf_pre_test_rollout "REGISTERED DIALOG OFFSET TEST v0.04" width:360 height:236
(
    label lbl_state "State: unregistered" pos:[12, 12] width:336 height:20

    button btn_register "REGISTER" pos:[12, 42] width:160 height:28
    button btn_unregister "UNREGISTER" pos:[188, 42] width:160 height:28
    button btn_save "SAVE" pos:[12, 80] width:160 height:28
    button btn_load "LOAD" pos:[188, 80] width:160 height:28

    edittext edt_log "" pos:[12, 120] width:336 height:100 readOnly:true multiLine:true

    /*
    Refreshes the visible raw geometry and INI data without moving the dialog.
    */
    function refreshReport action_text =
    (
        local current_geometry = RegisteredDialogPreRegistrationOffset.captureGeometry rdpf_pre_test_rollout
        local saved_geometry = RegisteredDialogPreRegistrationOffset.loadGeometry rdpf_pre_test_ini "TestDialog"
        local saved_text = if saved_geometry == undefined then "not saved" else saved_geometry as string

        lbl_state.text = "State: " + (current_geometry[3] as string)
        edt_log.text = "ACTION: " + action_text + "\n" + \
            "POSITION: " + (current_geometry[1] as string) + "\n" + \
            "SIZE: " + (current_geometry[2] as string) + "\n" + \
            "REGISTER OFFSET: " + (RegisteredDialogPreRegistrationOffset.pre_register_offset as string) + "\n" + \
            "UNREGISTER OFFSET: " + (RegisteredDialogPreRegistrationOffset.post_unregister_offset as string) + "\n" + \
            "SAVED: " + saved_text + "\n" + \
            "INI: " + rdpf_pre_test_ini
        true
    )

    on rdpf_pre_test_rollout open do
    (
        refreshReport "OPEN"
    )

    on btn_register pressed do
    (
        local operation_ok = RegisteredDialogPreRegistrationOffset.registerDialog rdpf_pre_test_rollout
        refreshReport (if operation_ok then "REGISTERED" else "REGISTER SKIPPED / FAILED")
    )

    on btn_unregister pressed do
    (
        local operation_ok = RegisteredDialogPreRegistrationOffset.unregisterDialog rdpf_pre_test_rollout
        refreshReport (if operation_ok then "UNREGISTERED" else "UNREGISTER SKIPPED / FAILED")
    )

    on btn_save pressed do
    (
        local save_ok = RegisteredDialogPreRegistrationOffset.saveGeometry rdpf_pre_test_rollout rdpf_pre_test_ini "TestDialog"
        refreshReport (if save_ok then "SAVED" else "SAVE FAILED")
    )

    on btn_load pressed do
    (
        local restore_ok = RegisteredDialogPreRegistrationOffset.restoreGeometry rdpf_pre_test_rollout rdpf_pre_test_ini "TestDialog"
        refreshReport (if restore_ok then "RESTORED" else "RESTORE MISMATCH - SEE LISTENER")
    )
)

createDialog rdpf_pre_test_rollout pos:[220, 180] width:360 height:236 \
    style:#(#style_titlebar, #style_border, #style_sysmenu, #style_resizing)

if hasINISetting rdpf_pre_test_ini "TestDialog" "SavedState" then
(
    RegisteredDialogPreRegistrationOffset.restoreGeometry rdpf_pre_test_rollout rdpf_pre_test_ini "TestDialog"
)

/*
Tests the correction against the measured native [6,29] registration shift.
*/
function testPreRegistrationOffset =
(
    local expected_pre_position = [226, 178]
    local calculated_position = RegisteredDialogPreRegistrationOffset.getPreRegistrationPosition [220, 180]
    local expected_offset = [6, -2]
    local expected_unregistration_offset = [-8, 0]
    local expected_registered_raw = [232, 207]
    local calculated_registered_raw = calculated_position + RegisteredDialogPreRegistrationOffset.measured_native_register_shift
    local calculated_return_raw = calculated_registered_raw + [-4, -27] + expected_unregistration_offset
    local offset_ok = RegisteredDialogPreRegistrationOffset.pre_register_offset == expected_offset and \
        calculated_position == expected_pre_position and \
        RegisteredDialogPreRegistrationOffset.post_unregister_offset == expected_unregistration_offset and \
        calculated_registered_raw == expected_registered_raw and calculated_return_raw == [220, 180]

    if RegisteredDialogPreRegistrationOffset.last_before_position != undefined and \
        RegisteredDialogPreRegistrationOffset.last_pre_registration_position != undefined then
    (
        offset_ok = offset_ok and \
            (RegisteredDialogPreRegistrationOffset.last_pre_registration_position - RegisteredDialogPreRegistrationOffset.last_before_position) == expected_offset
    )

    format "RDPF PRE TEST | before:[220,180] expected_pre:% calculated_pre:% registered_raw:% returned_raw:% register_correction:% unregister_correction:% result:%\n" \
        expected_pre_position calculated_position calculated_registered_raw calculated_return_raw expected_offset expected_unregistration_offset (if offset_ok then "PASS" else "FAIL")
    offset_ok
)

/*
Tests five complete register/unregister cycles without visible movement or size growth.
*/
function testRegistrationTransitionNoDrift cycle_count:5 =
(
    local before_geometry = undefined
    local passed = false

    if (RegisteredDialogPreRegistrationOffset.getDialogState rdpf_pre_test_rollout) == #registered_floating then \
        RegisteredDialogPreRegistrationOffset.unregisterDialog rdpf_pre_test_rollout

    before_geometry = RegisteredDialogPreRegistrationOffset.captureGeometry rdpf_pre_test_rollout
    passed = before_geometry[3] == #unregistered

    for cycle_index = 1 to cycle_count do
    (
        local registered_ok = RegisteredDialogPreRegistrationOffset.registerDialog rdpf_pre_test_rollout
        local registered_geometry = RegisteredDialogPreRegistrationOffset.captureGeometry rdpf_pre_test_rollout
        local unregistered_ok = RegisteredDialogPreRegistrationOffset.unregisterDialog rdpf_pre_test_rollout
        local after_geometry = RegisteredDialogPreRegistrationOffset.captureGeometry rdpf_pre_test_rollout
        local cycle_ok = registered_ok and unregistered_ok and \
            after_geometry[1] == before_geometry[1] and after_geometry[2] == before_geometry[2]

        format "RDPF PRE TEST | TOGGLE cycle:% registered_raw:% expected_unregistered:% actual_unregistered:% result:%\n" \
            cycle_index registered_geometry[1] before_geometry after_geometry (if cycle_ok then "PASS" else "FAIL")
        passed = passed and cycle_ok
    )
    passed
)

/*
Tests INI persistence over repeated loads in the current registration state.
*/
function testPreRegistrationSaveLoad cycle_count:5 =
(
    local before_geometry = RegisteredDialogPreRegistrationOffset.captureGeometry rdpf_pre_test_rollout
    local passed = true

    for cycle_index = 1 to cycle_count do
    (
        local saved_ok = RegisteredDialogPreRegistrationOffset.saveGeometry rdpf_pre_test_rollout rdpf_pre_test_ini "Regression"
        local restored_ok = RegisteredDialogPreRegistrationOffset.restoreGeometry rdpf_pre_test_rollout rdpf_pre_test_ini "Regression"
        local after_geometry = RegisteredDialogPreRegistrationOffset.captureGeometry rdpf_pre_test_rollout
        local cycle_ok = saved_ok and restored_ok and \
            before_geometry[1] == after_geometry[1] and before_geometry[2] == after_geometry[2] and \
            before_geometry[3] == after_geometry[3]

        format "RDPF PRE TEST | SAVE LOAD cycle:% expected:% actual:% result:%\n" \
            cycle_index before_geometry after_geometry (if cycle_ok then "PASS" else "FAIL")
        passed = passed and cycle_ok
    )
    passed
)
