/* Modifier Manager - standalone tool launcher.
   File version: 0.022 | Project version: 0.022.
*/

global modifier_manager_project_version
global modifier_manager_file_version_entry = 0.022
global modifier_manager_stored_project_version_entry = 0.022
global modifier_manager_main_path
global modifier_manager_ini_path
global modifierManagerUI

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

    /* Close the previous dockable dialog before redefining the owning rollout. */
    DialogHost.destroyToolDialogs "Modifier-Manager"
    if modifierManagerUI != undefined then
    (
        DialogHost.unregisterDockableDialog modifierManagerUI
        try (destroyDialog modifierManagerUI) catch (format "Modifier Manager dialog cleanup: %\n" (getCurrentException()))
    )

    fileIn (source_folder + "Modifier-Manager-FN.ms")
    fileIn (source_folder + "Modifier-Manager-Presets.ms")
    fileIn (source_folder + "Modifier-Manager-Preset-UI.ms")
    fileIn (source_folder + "Modifier-Manager-Slice.ms")
    fileIn (source_folder + "Modifier-Manager-Slice-UI.ms")
    fileIn (source_folder + "Modifier-Manager-UI.ms")
    DialogHost.createManagedDialog modifierManagerUI modifier_manager_ini_path "MainUI" \
        tool_key:"Modifier-Manager" default_width:336 default_height:840 min_height:840
    windows.processPostedMessages()
)
