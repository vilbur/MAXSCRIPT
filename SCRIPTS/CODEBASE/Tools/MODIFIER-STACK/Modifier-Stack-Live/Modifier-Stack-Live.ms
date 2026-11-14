/* Modifier Stack Live - standalone tool launcher.
   File version: 0.012 | Project version: 0.012.
*/

global modifier_stack_live_project_version
global modifier_stack_live_file_version_entry = 0.012
global modifier_stack_live_stored_project_version_entry = 0.012
global modifier_stack_live_main_path
global modifier_stack_live_ini_path
global modifierStackLiveUI
global SCRIPT_MANAGER_RUNTIME_MODE
global EPOLY_TOOLS_RUNTIME_MODE

if modifier_stack_live_project_version == undefined or modifier_stack_live_stored_project_version_entry > modifier_stack_live_project_version then
(
    modifier_stack_live_project_version = modifier_stack_live_stored_project_version_entry
)

(
    local source_file = getSourceFileName()
    if source_file == undefined or source_file == "" then throw "Launch from the saved Modifier-Stack-Live.ms file."
    local source_folder = getFilenamePath source_file
    modifier_stack_live_main_path = source_file
    modifier_stack_live_ini_path = source_folder + "Modifier-Stack-Live.ini"

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
            throw ("Modifier Stack Live: missing shared UI framework and sibling bundled framework: " + bundled_framework)
        )
        fileIn bundled_framework
    )

    /* Embedded loads define tool API only; Script-Manager embeds the UI companion itself. */
    local loader_mode = SCRIPT_MANAGER_RUNTIME_MODE
    if loader_mode == undefined then loader_mode = EPOLY_TOOLS_RUNTIME_MODE
    local standalone_mode = loader_mode == undefined or loader_mode == #standalone

    if standalone_mode then
    (
        DialogHost.destroyToolDialogs "Modifier-Stack-Live"
        if modifierStackLiveUI != undefined then
        (
            DialogHost.unregisterDockableDialog modifierStackLiveUI
            try (destroyDialog modifierStackLiveUI) catch (format "Modifier Stack Live dialog cleanup: %\n" (getCurrentException()))
        )
    )

    fileIn (source_folder + "Modifier-Stack-Live-FN.ms")

    if standalone_mode then
    (
        fileIn (source_folder + "Modifier-Stack-Live-UI.ms")
        DialogHost.createManagedDialog modifierStackLiveUI modifier_stack_live_ini_path "MainUI" \
            tool_key:"Modifier-Stack-Live" default_width:336 default_height:840 min_height:840
        windows.processPostedMessages()
    )
)
