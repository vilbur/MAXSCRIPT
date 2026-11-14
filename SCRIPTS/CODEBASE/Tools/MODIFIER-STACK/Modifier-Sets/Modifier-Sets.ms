/* Modifier Sets - standalone tool launcher.
   File version: 0.022 | Project version: 0.022.
*/

global modifier_sets_project_version
global modifier_sets_file_version_entry = 0.022
global modifier_sets_stored_project_version_entry = 0.022
global modifier_sets_main_path
global modifier_sets_ini_path
global modifierSetsUI
global SCRIPT_MANAGER_RUNTIME_MODE
global EPOLY_TOOLS_RUNTIME_MODE

if modifier_sets_project_version == undefined or modifier_sets_stored_project_version_entry > modifier_sets_project_version then
(
    modifier_sets_project_version = modifier_sets_stored_project_version_entry
)

(
    local source_file = getSourceFileName()
    if source_file == undefined or source_file == "" then throw "Launch from the saved Modifier-Sets.ms file."
    local source_folder = getFilenamePath source_file
    modifier_sets_main_path = source_file
    modifier_sets_ini_path = source_folder + "Modifier-Sets.ini"

    /* Resolve canonical shared UI helpers upward from this standalone tool, not a parent Toolset. */
    local probe_folder = source_folder
    local ui_framework_dir = ""
    for probe_index = 1 to 9 while ui_framework_dir == "" do
    (
        local candidate_dir = probe_folder + "UI\\Default\\"
        if doesFileExist (candidate_dir + "IniSettings.ms") then
        (
            ui_framework_dir = candidate_dir
        )
        else
        (
            probe_folder += "..\\"
        )
    )
    /* Fall back to the sibling tool's self-contained UI helpers when UI\Default is absent. */
    if ui_framework_dir != "" then
    (
        for helper_name in #("IniSettings.ms", "RolloutState.ms", "DialogHost.ms", "ScriptReload.ms", "ToolTitleButton.ms") do
        (
            fileIn (ui_framework_dir + helper_name)
        )
    )
    else
    (
        local bundled_framework = source_folder + "..\\Modifier-Manager\\Modifier-Manager-Framework.ms"
        if not(doesFileExist bundled_framework) then
        (
            throw ("Modifier Sets: missing shared UI framework and sibling bundled framework: " + bundled_framework)
        )
        fileIn bundled_framework
    )

    /* Embedded loads define tool API only; Script-Manager embeds the UI companion itself. */
    local loader_mode = SCRIPT_MANAGER_RUNTIME_MODE
    if loader_mode == undefined then loader_mode = EPOLY_TOOLS_RUNTIME_MODE
    local standalone_mode = loader_mode == undefined or loader_mode == #standalone

    if standalone_mode then
    (
        DialogHost.destroyToolDialogs "Modifier-Sets"
        if modifierSetsUI != undefined then
        (
            DialogHost.unregisterDockableDialog modifierSetsUI
            try (destroyDialog modifierSetsUI) catch (format "Modifier Sets dialog cleanup: %\n" (getCurrentException()))
        )
    )

    fileIn (source_folder + "Modifier-Sets-FN.ms")

    if standalone_mode then
    (
        fileIn (source_folder + "Modifier-Sets-UI.ms")
        DialogHost.createManagedDialog modifierSetsUI modifier_sets_ini_path "MainUI" \
            tool_key:"Modifier-Sets" default_width:288 default_height:792 min_height:792
        windows.processPostedMessages()
    )
)
