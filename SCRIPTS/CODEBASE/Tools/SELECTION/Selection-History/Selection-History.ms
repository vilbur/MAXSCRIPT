/* Selection-History entry point. File version 0.001; project version 0.001. */
(
    local source_file = getSourceFileName()
    if source_file == undefined or source_file == "" then
    (
        throw "Selection-History must run from its saved .ms file."
    )
    local tool_dir = getFilenamePath source_file
    local framework_dir = @"G:\AI\AGENTS\Maxscript\UI\Default\"
    for helper_name in #("IniSettings.ms", "RolloutState.ms", "DialogHost.ms", "ScriptReload.ms", "ToolTitleButton.ms") do
    (
        local helper_path = framework_dir + helper_name
        if not doesFileExist helper_path then throw ("Missing shared UI dependency: " + helper_path)
        fileIn helper_path
    )
    fileIn (tool_dir + "Selection-History-FN.ms")
    fileIn (tool_dir + "Selection-History-UI.ms")
    DialogHost.createManagedDialog selection_history_dialog "Selection-History" "MainUI" tool_key:"Selection-History" default_width:336 default_height:216 min_height:180
    windows.processPostedMessages()
)
