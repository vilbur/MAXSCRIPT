/* Modifier Manager - standalone tool launcher.
   File version: 0.032 | Project version: 0.032.
*/

global modifier_manager_project_version
global modifier_manager_file_version_entry = 0.032
global modifier_manager_stored_project_version_entry = 0.032
global modifier_manager_main_path
global modifier_manager_ini_path
global modifierManagerUI
global SCRIPT_MANAGER_RUNTIME_MODE
global EPOLY_TOOLS_RUNTIME_MODE

if modifier_manager_project_version == undefined or modifier_manager_stored_project_version_entry > modifier_manager_project_version then
(
    modifier_manager_project_version = modifier_manager_stored_project_version_entry
)

(
    local source_file = getSourceFileName()
    if source_file == undefined or source_file == "" then throw "Launch from the saved Modifier-Manager.ms file."
    local source_folder = getFilenamePath source_file
    modifier_manager_main_path = source_file
    modifier_manager_ini_path = source_folder + "Modifier-Manager.ini"

    /* Bundle the exact UI helpers with this tool to keep it independent of its parent folders. */
    local framework_file = source_folder + "Modifier-Manager-Framework.ms"
    if not doesFileExist framework_file then
    (
        throw ("Modifier Manager: missing bundled UI framework: " + framework_file)
    )
    fileIn framework_file

    /* Embedded loads define child rollouts; Script-Manager adds the main UI companion. */
    local loader_mode = SCRIPT_MANAGER_RUNTIME_MODE
    if loader_mode == undefined then loader_mode = EPOLY_TOOLS_RUNTIME_MODE
    local standalone_mode = loader_mode == undefined or loader_mode == #standalone

    if standalone_mode then
    (
        DialogHost.destroyToolDialogs "Modifier-Manager"
        if modifierManagerUI != undefined then
        (
            DialogHost.unregisterDockableDialog modifierManagerUI
            try (destroyDialog modifierManagerUI) catch (format "Modifier Manager dialog cleanup: %\n" (getCurrentException()))
        )
    )

    fileIn (source_folder + "Modifier-Manager-FN.ms")
    fileIn (source_folder + "Modifier-Manager-Presets.ms")
    fileIn (source_folder + "Modifier-Manager-Preset-UI.ms")
    fileIn (source_folder + "Modifier-Manager-Slice.ms")
    fileIn (source_folder + "Modifier-Manager-Slice-UI.ms")

    if standalone_mode then
    (
        fileIn (source_folder + "Modifier-Manager-UI.ms")
        DialogHost.createManagedDialog modifierManagerUI modifier_manager_ini_path "MainUI" \
            tool_key:"Modifier-Manager" default_width:336 default_height:840 min_height:840
        windows.processPostedMessages()
    )
)
