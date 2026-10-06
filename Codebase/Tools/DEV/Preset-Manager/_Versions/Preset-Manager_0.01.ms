/*
Preset-Manager sandbox Tool entry point.
File version: 0.01
Project version: 0.01
*/

global preset_manager_project_version
global preset_manager_tool_file_version = 0.01
global preset_manager_tool_stored_project_version = 0.01
global preset_manager_tool_source_path = getSourceFileName()
global preset_manager_tool_dir
global preset_manager_tool_ini_path
global preset_manager_operation_path
global preset_manager_ui_framework_dir

if preset_manager_project_version == undefined or preset_manager_tool_stored_project_version > preset_manager_project_version then
(
    preset_manager_project_version = preset_manager_tool_stored_project_version
)

preset_manager_tool_dir = if preset_manager_tool_source_path != undefined and preset_manager_tool_source_path != "" then getFilenamePath preset_manager_tool_source_path else ""
preset_manager_tool_ini_path = preset_manager_tool_dir + "Preset-Manager.ini"
preset_manager_operation_path = preset_manager_tool_dir + "..\\..\\..\\Operations\\Preset-Manager\\Preset-Manager.ms"
preset_manager_ui_framework_dir = preset_manager_tool_dir + "..\\..\\..\\..\\UI\\Default\\"

/*
Loads one required dependency and stops with a clear error when the file cannot be resolved.
*/
function presetManagerLoadRequired dependency_path =
(
    if classOf dependency_path != String or dependency_path == "" then
    (
        throw "Preset Manager: invalid dependency path."
    )

    if not doesFileExist dependency_path then
    (
        throw ("Preset Manager: missing dependency: " + dependency_path)
    )

    fileIn dependency_path
    true
    -- return
)

if preset_manager_tool_dir == "" then
(
    throw "Preset Manager: run the Tool from a saved .ms file."
)

presetManagerLoadRequired (preset_manager_ui_framework_dir + "IniSettings.ms")
presetManagerLoadRequired (preset_manager_ui_framework_dir + "RolloutState.ms")
presetManagerLoadRequired (preset_manager_ui_framework_dir + "DialogHost.ms")
presetManagerLoadRequired (preset_manager_ui_framework_dir + "ScriptReload.ms")
presetManagerLoadRequired (preset_manager_ui_framework_dir + "ToolTitleButton.ms")
presetManagerLoadRequired preset_manager_operation_path
presetManagerLoadRequired (preset_manager_tool_dir + "Preset-Manager-FN.ms")
presetManagerLoadRequired (preset_manager_tool_dir + "Preset-Manager-UI.ms")

if not PresetManagerTool.configure preset_manager_tool_ini_path then
(
    throw "Preset Manager: could not configure sandbox storage."
)

DialogHost.createManagedDialog preset_manager_tool_rollout preset_manager_tool_ini_path "MainUI" tool_key:"Preset-Manager" default_width:336 default_height:336 min_height:312
windows.processPostedMessages()
