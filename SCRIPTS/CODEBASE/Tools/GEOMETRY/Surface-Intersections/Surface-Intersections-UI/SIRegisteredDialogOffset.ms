/*
Registered Dialog Pre-Registration Offset — reusable MaxScript UI helper.
Fork version 0.01 | Project version 0.89. Based on tested source v0.04.
Tool-local source fork; no dependency on the original Drive project.
*/

struct SIRegisteredDialogOffset_v
(
    pre_register_offset = [6, -2],
    post_unregister_offset = [-8, 0],
    measured_native_register_shift = [6, 29],
    measured_registered_size_shift = [16, 39],
    registration_style = #(#cui_dock_vert, #cui_floatable, #cui_handles),
    original_geometry_cache = #(),
    last_before_position = undefined,
    last_pre_registration_position = undefined,
    last_registered_position = undefined,

    /*
    Returns the native registration state of a rollout.
    */
    function getDialogState rollout_ref =
    (
        if rollout_ref.dialogBar then
        (
            if (cui.getDockState rollout_ref) == #cui_floatable then #registered_floating else #registered_docked
        )
        else
        (
            #unregistered
        )
    ),

    /*
    Captures uncorrected GetDialogPos, GetDialogSize, and registration state.
    */
    function captureGeometry rollout_ref =
    (
        #((getDialogPos rollout_ref), (getDialogSize rollout_ref), (getDialogState rollout_ref))
    ),

    /*
    Returns the exact unregistered position to set BEFORE registration.
    */
    function getPreRegistrationPosition raw_position =
    (
        raw_position + pre_register_offset
    ),

    /*
    Applies the original registered-dialog corrections while the rollout is movable.
    */
    function fixDialogPosOnDocking rollout_ref register_or_unregister =
    (
        local position_offset = if register_or_unregister == #REGISTER then pre_register_offset else post_unregister_offset
        local dialog_position = getDialogPos rollout_ref
        dialog_position += position_offset
        setDialogPos rollout_ref dialog_position
        dialog_position
    ),

    /*
    Saves a previous unregistered position and size for a single rollout.
    */
    function rememberUnregisteredGeometry rollout_ref =
    (
        local geometry_data = captureGeometry rollout_ref
        local entry_found = false

        for entry_data in original_geometry_cache do
        (
            if entry_data[1] == rollout_ref then
            (
                entry_data[2] = geometry_data
                entry_found = true
            )
        )

        if not entry_found then append original_geometry_cache #(rollout_ref, geometry_data)
        geometry_data
    ),

    /*
    Retrieves the remembered unregistered geometry of a specific rollout.
    */
    function getRememberedGeometry rollout_ref =
    (
        local geometry_data = undefined
        for entry_data in original_geometry_cache do
        (
            if entry_data[1] == rollout_ref then geometry_data = entry_data[2]
        )
        geometry_data
    ),

    /*
    Applies [6,-2] BEFORE registration, preserving the original framework's sequence.
    */
    function registerDialog rollout_ref =
    (
        local operation_ok = false
        local before_geometry = captureGeometry rollout_ref
        local requested_pre_position = undefined
        local after_geometry = undefined

        if before_geometry[3] == #unregistered then
        (
            rememberUnregisteredGeometry rollout_ref
            last_before_position = before_geometry[1]
            requested_pre_position = getPreRegistrationPosition before_geometry[1]
            last_pre_registration_position = fixDialogPosOnDocking rollout_ref #REGISTER
            format "RDPF PRE | BEFORE REGISTER | raw_before:% applied_offset:% raw_pre_registration:%\n" \
                last_before_position pre_register_offset last_pre_registration_position

            cui.RegisterDialogBar rollout_ref style:registration_style
            cui.FloatDialogBar rollout_ref
            windows.processPostedMessages()

            after_geometry = captureGeometry rollout_ref
            last_registered_position = after_geometry[1]
            operation_ok = after_geometry[3] == #registered_floating and \
                last_pre_registration_position == requested_pre_position

            format "RDPF PRE | AFTER REGISTER | raw_pre_registration:% raw_registered:% native_delta:% size_before:% size_registered:% pass:%\n" \
                last_pre_registration_position last_registered_position \
                (last_registered_position - last_pre_registration_position) \
                before_geometry[2] after_geometry[2] operation_ok
        )
        operation_ok
    ),

    /*
    Applies [-8,0] AFTER unregistration and restores the unregistered size.
    */
    function unregisterDialog rollout_ref restore_unregistered_size:true =
    (
        local operation_ok = false
        local before_geometry = captureGeometry rollout_ref
        local native_geometry = undefined
        local remembered_geometry = undefined
        local after_geometry = undefined
        local expected_unregistered_position = undefined

        if before_geometry[3] == #registered_floating then
        (
            cui.UnRegisterDialogBar rollout_ref
            windows.processPostedMessages()

            native_geometry = captureGeometry rollout_ref
            remembered_geometry = getRememberedGeometry rollout_ref
            expected_unregistered_position = native_geometry[1] + post_unregister_offset

            fixDialogPosOnDocking rollout_ref #UNREGISTER

            if restore_unregistered_size then
            (
                if remembered_geometry != undefined then setDialogSize rollout_ref remembered_geometry[2]
            )

            after_geometry = captureGeometry rollout_ref
            operation_ok = after_geometry[3] == #unregistered and after_geometry[1] == expected_unregistered_position

            format "RDPF PRE | UNREGISTER | registered_raw:% expected_after_correction:% native_unregistered:% native_delta:% final_unregistered:% restored_size:% pass:%\n" \
                before_geometry[1] expected_unregistered_position native_geometry[1] (native_geometry[1] - before_geometry[1]) \
                after_geometry[1] restore_unregistered_size operation_ok
        )
        operation_ok
    ),

    /*
    Saves position, size, and registration state into an independently named INI section.
    */
    function saveGeometry rollout_ref ini_path section_name =
    (
        local geometry_data = captureGeometry rollout_ref
        local state_text = if geometry_data[3] == #registered_floating then "registered_floating" else "unregistered"
        local save_ok = true
        local values_to_save = #(
            #("PosX", geometry_data[1].x as string),
            #("PosY", geometry_data[1].y as string),
            #("Width", geometry_data[2].x as string),
            #("Height", geometry_data[2].y as string),
            #("SavedState", state_text)
        )

        for setting_data in values_to_save do
        (
            if (setINISetting ini_path section_name setting_data[1] setting_data[2] forceUTF16:false) != true then save_ok = false
        )

        format "RDPF PRE | SAVE | section:% geometry:% pass:%\n" section_name geometry_data save_ok
        save_ok
    ),

    /*
    Reads a saved geometry, rejecting missing or invalid INI entries.
    */
    function loadGeometry ini_path section_name =
    (
        local geometry_data = undefined

        if hasINISetting ini_path section_name "SavedState" then
        (
            try
            (
                local saved_position = [
                    ((getINISetting ini_path section_name "PosX") as integer),
                    ((getINISetting ini_path section_name "PosY") as integer)]
                local saved_size = [
                    ((getINISetting ini_path section_name "Width") as integer),
                    ((getINISetting ini_path section_name "Height") as integer)]
                local state_text = getINISetting ini_path section_name "SavedState"
                local saved_state = case state_text of
                (
                    "registered_floating": #registered_floating
                    "unregistered": #unregistered
                    default: undefined
                )

                if saved_size.x > 0 and saved_size.y > 0 and saved_state != undefined then
                    geometry_data = #(saved_position, saved_size, saved_state)
            )
            catch
            (
                format "RDPF PRE | LOAD INI FAILED | section:% error:%\n" section_name (getCurrentException())
            )
        )
        geometry_data
    ),

    /*
    Restores saved state; registered restore applies [+6,+29] BEFORE registration.
    */
    function restoreGeometry rollout_ref ini_path section_name =
    (
        local saved_geometry = loadGeometry ini_path section_name
        local restore_ok = false
        local create_position = undefined
        local create_size = undefined
        local retry_size = undefined
        local actual_geometry = undefined
        local position_residual = undefined
        local size_residual = undefined

        if saved_geometry != undefined then
        (
            if rollout_ref.dialogBar then cui.UnRegisterDialogBar rollout_ref

            create_position = saved_geometry[1]
            create_size = saved_geometry[2]

            if saved_geometry[3] == #registered_floating then
            (
                create_position -= (pre_register_offset + measured_native_register_shift)
            )

            setDialogSize rollout_ref create_size
            setDialogPos rollout_ref create_position

            if saved_geometry[3] == #registered_floating then registerDialog rollout_ref

            actual_geometry = captureGeometry rollout_ref

            if saved_geometry[3] == #registered_floating and actual_geometry[2] != saved_geometry[2] then
            (
                retry_size = saved_geometry[2] - measured_registered_size_shift
                format "RDPF PRE | Registered size mismatch; retrying with unregistered size:%\n" retry_size
                unregisterDialog rollout_ref restore_unregistered_size:false
                setDialogSize rollout_ref retry_size
                setDialogPos rollout_ref create_position
                registerDialog rollout_ref
                actual_geometry = captureGeometry rollout_ref
            )

            position_residual = actual_geometry[1] - saved_geometry[1]
            size_residual = actual_geometry[2] - saved_geometry[2]

            restore_ok = actual_geometry[3] == saved_geometry[3] and \
                position_residual == [0, 0] and size_residual == [0, 0]

            format "RDPF PRE | RESTORE | section:% saved:% create_raw:% actual:% position_residual:% size_residual:% pass:%\n" \
                section_name saved_geometry create_position actual_geometry position_residual size_residual restore_ok
        )
        restore_ok
    ),

    on create do
    (
    )
)

global SIRegisteredDialogOffset
SIRegisteredDialogOffset = SIRegisteredDialogOffset_v()

