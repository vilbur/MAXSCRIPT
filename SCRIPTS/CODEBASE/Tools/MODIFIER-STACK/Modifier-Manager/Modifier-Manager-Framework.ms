/* Modifier Manager - bundled UI framework (self-contained copy of shared UI helpers).
   File version: 0.022 | Project version: 0.022.
   Sources: shared MaxScript UI/Default; keep its helper APIs compatible with this tool.
*/

/*
Generic INI persistence helpers for MaxScript UI code.
Keep feature logic independent from this file.
*/

struct IniSettings_v
(
    /*
    Returns a string setting or the supplied default value.
    */
    function getString file_path section_name key_name default_value:"" =
    (
        local value = getINISetting file_path section_name key_name

        if value == "" then
        (
            default_value
        )
        else
        (
            value
        )
    ),

    /*
    Writes one string setting.
    */
    function setString file_path section_name key_name value =
    (
        setINISetting file_path section_name key_name (value as string)
        true
    ),

    /*
    Returns an integer setting or the supplied default value.
    */
    function getInteger file_path section_name key_name default_value:0 =
    (
        local value = getINISetting file_path section_name key_name

        if value == "" then
        (
            default_value
        )
        else
        (
            try (value as integer) catch (default_value)
        )
    ),

    /*
    Writes one integer setting.
    */
    function setInteger file_path section_name key_name value =
    (
        setINISetting file_path section_name key_name ((value as integer) as string)
        true
    ),

    /*
    Returns a float setting or the supplied default value.
    */
    function getFloat file_path section_name key_name default_value:0.0 =
    (
        local value = getINISetting file_path section_name key_name

        if value == "" then
        (
            default_value
        )
        else
        (
            try (value as float) catch (default_value)
        )
    ),

    /*
    Writes one float setting.
    */
    function setFloat file_path section_name key_name value =
    (
        setINISetting file_path section_name key_name ((value as float) as string)
        true
    ),

    /*
    Returns a boolean setting or the supplied default value.
    */
    function getBoolean file_path section_name key_name default_value:false =
    (
        local value = toLower (getINISetting file_path section_name key_name)

        case value of
        (
            "true": true
            "1": true
            "yes": true
            "false": false
            "0": false
            "no": false
            default: default_value
        )
    ),

    /*
    Writes one boolean setting.
    */
    function setBoolean file_path section_name key_name value =
    (
        setINISetting file_path section_name key_name (if value then "true" else "false")
        true
    ),

    /*
    Returns a Point2 setting stored as two integer keys.
    */
    function getPoint2 file_path section_name key_x key_y default_value:[0, 0] =
    (
        local x_value = getInteger file_path section_name key_x default_value:default_value.x
        local y_value = getInteger file_path section_name key_y default_value:default_value.y

        [x_value, y_value]
    ),

    /*
    Writes a Point2 setting as two integer keys.
    */
    function setPoint2 file_path section_name key_x key_y value =
    (
        setInteger file_path section_name key_x value.x
        setInteger file_path section_name key_y value.y
        true
    ),

    on create do
    (
    )
)

global IniSettings
IniSettings = IniSettings_v()


/*
Generic rollout-control persistence helpers.
This file belongs to the UI layer and must not contain feature processing logic.
*/

struct RolloutState_v
(
    /*
    Loads one checkbox state from INI.
    */
    function loadCheckbox control ini_path section_name key_name default_value:false =
    (
        if control != undefined then
        (
            control.checked = IniSettings.getBoolean ini_path section_name key_name default_value:default_value
        )
    ),

    /*
    Saves one checkbox state to INI.
    */
    function saveCheckbox control ini_path section_name key_name =
    (
        if control != undefined then
        (
            IniSettings.setBoolean ini_path section_name key_name control.checked
        )
    ),

    /*
    Loads one spinner value from INI.
    */
    function loadSpinner control ini_path section_name key_name default_value:0.0 =
    (
        if control != undefined then
        (
            control.value = IniSettings.getFloat ini_path section_name key_name default_value:default_value
        )
    ),

    /*
    Saves one spinner value to INI.
    */
    function saveSpinner control ini_path section_name key_name =
    (
        if control != undefined then
        (
            IniSettings.setFloat ini_path section_name key_name control.value
        )
    ),

    /*
    Loads one dropdown selection index from INI.
    */
    function loadDropdown control ini_path section_name key_name default_value:1 =
    (
        if control != undefined then
        (
            local selection_value = IniSettings.getInteger ini_path section_name key_name default_value:default_value

            if selection_value < 1 then selection_value = 1
            if selection_value > control.items.count then selection_value = control.items.count

            if control.items.count > 0 then control.selection = selection_value
        )
    ),

    /*
    Saves one dropdown selection index to INI.
    */
    function saveDropdown control ini_path section_name key_name =
    (
        if control != undefined then
        (
            IniSettings.setInteger ini_path section_name key_name control.selection
        )
    ),

    /*
    Loads one edit-text value from INI.
    */
    function loadEditText control ini_path section_name key_name default_value:"" =
    (
        if control != undefined then
        (
            control.text = IniSettings.getString ini_path section_name key_name default_value:default_value
        )
    ),

    /*
    Saves one edit-text value to INI.
    */
    function saveEditText control ini_path section_name key_name =
    (
        if control != undefined then
        (
            IniSettings.setString ini_path section_name key_name control.text
        )
    ),

    on create do
    (
    )
)

global RolloutState
RolloutState = RolloutState_v()


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


/*
Generic script reload helper for F1 UI reload behavior.
This file belongs to the UI infrastructure layer.
*/

struct ScriptReload_v
(
    /*
    Extracts a numeric version suffix from <prefix>_<version>.ms.
    */
    function getFileVersion file_path file_prefix =
    (
        local file_name = getFilenameFile file_path
        local prefix_text = file_prefix + "_"
        local version_value = -1.0

        if matchPattern file_name pattern:(prefix_text + "*") ignoreCase:true then
        (
            local version_text = substring file_name (prefix_text.count + 1) (file_name.count - prefix_text.count)
            local version_parts = filterString version_text "-"

            if version_parts.count > 0 then
            (
                local parsed_version = version_parts[1] as float

                if parsed_version != undefined then
                (
                    version_value = parsed_version
                )
            )
        )

        version_value
        -- return
    ),

    /*
    Reports whether a versioned script is the preferred -LATEST alias.
    */
    function isLatestVersionAlias file_path =
    (
        local file_name = getFilenameFile file_path
        local is_latest = matchPattern file_name pattern:"*-LATEST" ignoreCase:true

        is_latest
        -- return
    ),

    /*
    Finds the newest matching versioned script in the current script directory.
    */
    function findNewestVersionedScript current_script file_prefix =
    (
        local newest_file = current_script
        local newest_version = -1.0

        if current_script != undefined and current_script != "" then
        (
            local script_dir = getFilenamePath current_script
            local candidate_files = getFiles (script_dir + file_prefix + "_*.ms")

            newest_version = getFileVersion current_script file_prefix

            for candidate_file in candidate_files do
            (
                local candidate_version = getFileVersion candidate_file file_prefix

                if candidate_version > newest_version then
                (
                    newest_version = candidate_version
                    newest_file = candidate_file
                )
                else if candidate_version == newest_version and candidate_version >= 0.0 then
                (
                    if isLatestVersionAlias candidate_file and not isLatestVersionAlias newest_file then
                    (
                        newest_file = candidate_file
                    )
                )
            )
        )

        newest_file
        -- return
    ),

    /*
    Reloads the newest matching versioned script or the current script as fallback.
    */
    function reloadLatest current_script file_prefix =
    (
        local target_file = findNewestVersionedScript current_script file_prefix
        local loaded = false

        if target_file != undefined and target_file != "" and doesFileExist target_file then
        (
            fileIn target_file
            loaded = true
        )

        loaded
        -- return
    ),

    on create do
    (
    )
)

global ScriptReload
ScriptReload = ScriptReload_v()


/*
Reusable tool title button helper for MaxScript dialogs and docked tool UIs.
The tool title button uses the production host appearance and LMB restart pattern.
*/

struct ToolTitleButton_v
(
    file_version = "0.07",

    /*
    Applies the canonical tool title button appearance and tool-name label.
    */
    function setupToolTitleButton button_control tool_name =
    (
        if button_control == undefined then return false
        if tool_name == undefined or tool_name == "" then return false

        local color_class = dotNetClass "System.Drawing.Color"
        local flat_style_class = dotNetClass "System.Windows.Forms.FlatStyle"
        local dark_color = color_class.FromArgb 45 45 48
        local title_color = color_class.FromArgb 62 158 255
        local font_style_type = dotNetClass "System.Drawing.FontStyle"
        local graphics_unit_type = dotNetClass "System.Drawing.GraphicsUnit"
        local font_size = 14

        button_control.Text = tool_name
        button_control.UseVisualStyleBackColor = false
        button_control.FlatStyle = flat_style_class.Flat
        button_control.AutoSize = false
        button_control.TabStop = false

        button_control.BackColor = dark_color
        button_control.ForeColor = title_color

        button_control.FlatAppearance.BorderSize = 0
        button_control.FlatAppearance.BorderColor = dark_color
        button_control.FlatAppearance.MouseOverBackColor = dark_color
        button_control.FlatAppearance.MouseDownBackColor = dark_color

        button_control.height = font_size + 6

        button_control.Font = dotNetObject "System.Drawing.Font" \
            "Segoe UI" (font_size as float) font_style_type.Bold graphics_unit_type.Pixel

        true
        -- return
    ),

    /*
    Resizes the tool title button to the full available width and canonical font-size-plus-6 height.
    */
    function resizeToolTitleButton button_control available_width =
    (
        if button_control == undefined then return false

        if available_width < 1 then available_width = 1

        local font_size = 14

        button_control.width = available_width
        button_control.height = font_size + 6

        true
        -- return
    ),

    on create do
    (
    )
)

global ToolTitleButton
ToolTitleButton = ToolTitleButton_v()

/*
Restarts the owning tool through the shared reload helper.
The tool title button LMB action calls this function.
*/
function restartTool current_script file_prefix =
(
    if current_script == undefined or current_script == "" then return false
    if file_prefix == undefined or file_prefix == "" then return false

    ScriptReload.reloadLatest current_script file_prefix
    -- return
)

