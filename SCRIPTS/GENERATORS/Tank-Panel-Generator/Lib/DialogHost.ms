/*
Generic floating-dialog state helpers.
The UI owns these calls; feature modules must not depend on this file.
*/

global dialog_host_registry

if dialog_host_registry == undefined then
(
    dialog_host_registry = #()
)

struct DialogHost_v
(
    /*
    Unregisters a rollout from the CUI dialog-bar system before it is destroyed.
    */
    function unregisterDockableDialog rollout_ref =
    (
        if rollout_ref == undefined then return false

        local is_dialog_bar = try (rollout_ref.dialogBar) catch (false)

        if is_dialog_bar then
        (
            try (cui.UnRegisterDialogBar rollout_ref) catch ()
        )

        true
    ),

    /*
    Registers a dialog as floatable and dockable only on the left or right side.
    */
    function registerDockableDialog rollout_ref =
    (
        if rollout_ref == undefined then return false

        unregisterDockableDialog rollout_ref

        try
        (
            cui.RegisterDialogBar rollout_ref style:#(#cui_dock_vert, #cui_floatable, #cui_handles)
            true
        )
        catch
        (
            false
        )
    ),

    /*
    Destroys every dialog registered for one stable, version-independent tool key.
    */
    function destroyToolDialogs tool_key =
    (
        if tool_key == undefined or tool_key == "" then return false

        for entry_index = dialog_host_registry.count to 1 by -1 do
        (
            local entry_value = dialog_host_registry[entry_index]

            if entry_value != undefined and entry_value.count >= 2 and entry_value[1] == tool_key then
            (
                local rollout_ref = entry_value[2]

                if rollout_ref != undefined then
                (
                    unregisterDockableDialog rollout_ref
                    try (destroyDialog rollout_ref) catch ()
                )

                deleteItem dialog_host_registry entry_index
            )
        )

        true
    ),

    /*
    Registers one currently owned dialog under a stable, version-independent tool key.
    */
    function registerToolDialog tool_key rollout_ref =
    (
        if tool_key == undefined or tool_key == "" or rollout_ref == undefined then return false

        append dialog_host_registry #(tool_key, rollout_ref)
        true
    ),

    /*
    Creates a dialog with locked width and vertically resizable height.
    */
    function createManagedDialog rollout_ref ini_path section_name tool_key:"" default_width:320 default_height:500 min_height:180 =
    (
        local saved_pos = IniSettings.getPoint2 ini_path section_name "PosX" "PosY" default_value:[100, 100]
        local saved_height = IniSettings.getInteger ini_path section_name "Height" default_value:default_height

        if saved_height < min_height then saved_height = min_height

        if tool_key != "" then
        (
            destroyToolDialogs tool_key
        )

        unregisterDockableDialog rollout_ref
        try (destroyDialog rollout_ref) catch ()

        createDialog rollout_ref width:default_width height:saved_height pos:saved_pos lockWidth:true lockHeight:false autoLayoutOnResize:true
        registerDockableDialog rollout_ref

        if tool_key != "" then
        (
            registerToolDialog tool_key rollout_ref
        )

        true
    ),

    /*
    Saves the current dialog position.
    */
    function saveDialogPosition rollout_ref ini_path section_name =
    (
        local dialog_pos = try (getDialogPos rollout_ref) catch (undefined)

        if dialog_pos != undefined then
        (
            IniSettings.setPoint2 ini_path section_name "PosX" "PosY" dialog_pos
        )
    ),

    /*
    Saves the current dialog height.
    */
    function saveDialogHeight rollout_ref ini_path section_name min_height:180 =
    (
        local dialog_size = try (getDialogSize rollout_ref) catch (undefined)

        if dialog_size != undefined then
        (
            local saved_height = if dialog_size.y < min_height then min_height else dialog_size.y
            IniSettings.setInteger ini_path section_name "Height" saved_height
        )
    ),

    /*
    Saves both dialog position and height.
    */
    function saveDialogState rollout_ref ini_path section_name min_height:180 =
    (
        saveDialogPosition rollout_ref ini_path section_name
        saveDialogHeight rollout_ref ini_path section_name min_height:min_height
        true
    ),

    on create do
    (
    )
)

global DialogHost
DialogHost = DialogHost_v()
