/*
Surface Intersections tool-local managed dialog host.
File version: 0.02 | Project version: 1.01.
Forks the confirmed Registered Dialog Pre-Registration Offset v0.04.
*/

global dialog_host_registry

if dialog_host_registry == undefined then
(
    dialog_host_registry = #()
)

struct DialogHost_v
(
    is_restoring = false,

    /*
    Unregisters only after identifying the registered dialog state.
    */
    function unregisterDockableDialog rollout_ref =
    (
        if rollout_ref == undefined then return false
        if rollout_ref.dialogBar then
        (
            local dialog_state = SIRegisteredDialogOffset.getDialogState rollout_ref
            if dialog_state == #registered_floating then
            (
                if not (SIRegisteredDialogOffset.unregisterDialog rollout_ref) then
                (
                    format "SI DIALOG UNREGISTER FAILED | rollout:% state:%\n" rollout_ref dialog_state
                    return false
                )
            )
            else
            (
                /* CUI owns docking positions; do not set dialog position here. */
                cui.UnRegisterDialogBar rollout_ref
            )
            if rollout_ref.dialogBar then
            (
                format "SI DIALOG UNREGISTER FAILED | CUI still owns rollout:%\n" rollout_ref
                return false
            )
        )
        true
        -- return
    ),

    /*
    Registers and floats through the approved pre-registration correction.
    */
    function registerDockableDialog rollout_ref =
    (
        if rollout_ref == undefined then return false
        if rollout_ref.dialogBar then
        (
            format "SI DIALOG REGISTER FAILED | Already registered: %\n" rollout_ref
            return false
        )
        SIRegisteredDialogOffset.registerDialog rollout_ref
        -- return
    ),

    /*
    Destroys every managed instance for this tool without overwriting saved geometry.
    */
    function destroyToolDialogs tool_key =
    (
        if tool_key == undefined or tool_key == "" then return false
        local prior_restoring = is_restoring
        is_restoring = true
        for entry_index = dialog_host_registry.count to 1 by -1 do
        (
            local entry_value = dialog_host_registry[entry_index]
            if entry_value != undefined and entry_value.count >= 2 and entry_value[1] == tool_key then
            (
                local rollout_ref = entry_value[2]
                if rollout_ref != undefined then
                (
                    if not (unregisterDockableDialog rollout_ref) then
                    (
                        is_restoring = prior_restoring
                        return false
                    )
                    try (destroyDialog rollout_ref) catch ()
                )
                deleteItem dialog_host_registry entry_index
            )
        )
        is_restoring = prior_restoring
        true
        -- return
    ),

    /*
    Registers a managed rollout reference under the stable tool key.
    */
    function registerToolDialog tool_key rollout_ref =
    (
        if tool_key == undefined or tool_key == "" or rollout_ref == undefined then return false
        append dialog_host_registry #(tool_key, rollout_ref)
        true
        -- return
    ),

    /*
    Restores a CUI dialog bar, including saved left/right docking or floating.
    Every success path ends with the dialog registered and verified.
    */
    function createManagedDialog rollout_ref ini_path section_name tool_key:"" default_width:320 default_height:500 min_height:180 =
    (
        local prior_restoring = is_restoring
        is_restoring = true
        local operation_ok = false
        try
        (
            if tool_key != "" then
            (
                if not (destroyToolDialogs tool_key) then throw "Existing tool dialog could not be unregistered."
            )

            if rollout_ref.dialogBar then
            (
                if not (unregisterDockableDialog rollout_ref) then throw "Existing rollout could not be unregistered."
            )
            try (destroyDialog rollout_ref) catch ()

            local saved_pos = IniSettings.getPoint2 ini_path section_name "PosX" "PosY" default_value:[100,100]
            local saved_height = IniSettings.getInteger ini_path section_name "Height" default_value:default_height
            local has_saved_state = hasINISetting ini_path section_name "SavedState"
            local has_legacy_pos = (hasINISetting ini_path section_name "PosX") and (hasINISetting ini_path section_name "PosY")
            local saved_dock_side = IniSettings.getString ini_path section_name "DockSide" default_value:"floating"
            local creation_pos = saved_pos
            local creation_height = amax min_height saved_height

            if not has_saved_state and has_legacy_pos then
            (
                /* Legacy PosX/PosY stored the already-registered floating position. */
                creation_pos -= (SIRegisteredDialogOffset.pre_register_offset + SIRegisteredDialogOffset.measured_native_register_shift)
                creation_height = amax min_height (saved_height - SIRegisteredDialogOffset.measured_registered_size_shift.y)
            )

            createDialog rollout_ref width:default_width height:creation_height pos:creation_pos lockWidth:true lockHeight:false autoLayoutOnResize:true
            windows.processPostedMessages()

            if has_saved_state then
            (
                operation_ok = SIRegisteredDialogOffset.restoreGeometry rollout_ref ini_path section_name
                if not operation_ok and rollout_ref.dialogBar then
                (
                    /* A strict pixel correction may fail on a different display/DPI while docking is still usable. */
                    format "SI DIALOG GEOMETRY WARNING | Restored registration; floating position/size did not match exactly.\n"
                    operation_ok = true
                )
            )
            else
            (
                operation_ok = registerDockableDialog rollout_ref
                if operation_ok and has_legacy_pos then
                (
                    local actual_pos = getDialogPos rollout_ref
                    format "SI DIALOG LEGACY POSITION | expected:% actual:% delta:%\n" saved_pos actual_pos (actual_pos - saved_pos)
                )
                if operation_ok then operation_ok = SIRegisteredDialogOffset.saveGeometry rollout_ref ini_path section_name
            )

            /* Legacy SavedState=unregistered must never leave the tool unable to dock. */
            if not rollout_ref.dialogBar then
            (
                operation_ok = registerDockableDialog rollout_ref
                if operation_ok then operation_ok = SIRegisteredDialogOffset.saveGeometry rollout_ref ini_path section_name
            )

            if operation_ok then
            (
                local expected_dock_state = #cui_floatable
                case saved_dock_side of
                (
                    "left":
                    (
                        expected_dock_state = #cui_dock_left
                        cui.DockDialogBar rollout_ref #cui_dock_left
                    )
                    "right":
                    (
                        expected_dock_state = #cui_dock_right
                        cui.DockDialogBar rollout_ref #cui_dock_right
                    )
                    default:
                    (
                        if (cui.getDockState rollout_ref) != #cui_floatable then cui.FloatDialogBar rollout_ref
                    )
                )
                windows.processPostedMessages()
                operation_ok = rollout_ref.dialogBar and (cui.getDockState rollout_ref) == expected_dock_state
                if not operation_ok then format "SI DIALOG DOCK RESTORE FAILED | requested:%\n" saved_dock_side
            )

            if operation_ok and tool_key != "" then operation_ok = registerToolDialog tool_key rollout_ref
        )
        catch
        (
            format "SI DIALOG CREATE FAILED | section:% error:%\n" section_name (getCurrentException())
            operation_ok = false
        )
        is_restoring = prior_restoring
        if not operation_ok then format "SI DIALOG RESTORE FAILED | section:% rollout:%\n" section_name rollout_ref
        operation_ok
        -- return
    ),

    /*
    Persists floating geometry or the left/right CUI dock side without moving the dialog.
    Docked windows never overwrite their last floating position or size.
    */
    function saveDialogPosition rollout_ref ini_path section_name =
    (
        if is_restoring or rollout_ref == undefined or not rollout_ref.dialogBar then return false
        local dock_state = cui.getDockState rollout_ref
        local side_text = case dock_state of
        (
            #cui_dock_left: "left"
            #cui_dock_right: "right"
            #cui_floatable: "floating"
            default: undefined
        )
        if side_text == undefined then return false
        local side_saved = true
        if (getINISetting ini_path section_name "DockSide") != side_text then
        (
            side_saved = setINISetting ini_path section_name "DockSide" side_text forceUTF16:false
        )
        if dock_state == #cui_floatable then
        (
            side_saved and (SIRegisteredDialogOffset.saveGeometry rollout_ref ini_path section_name)
        )
        else side_saved
        -- return
    ),

    /*
    Stores measured client height as part of the source fork's geometry record.
    */
    function saveDialogHeight rollout_ref ini_path section_name min_height:180 =
    (
        saveDialogPosition rollout_ref ini_path section_name
        -- return
    ),

    /*
    Persists complete actual geometry before the managed rollout is unregistered.
    */
    function saveDialogState rollout_ref ini_path section_name min_height:180 =
    (
        saveDialogPosition rollout_ref ini_path section_name
        -- return
    ),

    on create do
    (
    )
)

global DialogHost
DialogHost = DialogHost_v()
