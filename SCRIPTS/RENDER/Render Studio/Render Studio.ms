/*
Render Studio Tool entry point.
File version: 0.10
Project version: 0.13
*/


global render_studio_project_version
global render_studio_main_file_version = 0.10
global render_studio_main_stored_project_version = 0.13
global render_studio_source_path = getSourceFileName()
global render_studio_tool_dir
global render_studio_ini_path
global render_studio_ui_framework_dir


if render_studio_project_version == undefined or render_studio_main_stored_project_version > render_studio_project_version then
(
    render_studio_project_version = render_studio_main_stored_project_version
)


render_studio_tool_dir = if render_studio_source_path != undefined and render_studio_source_path != "" then getFilenamePath render_studio_source_path else ""
render_studio_ini_path = render_studio_tool_dir + "Render Studio.ini"


/*
Resolves the canonical shared UI framework.
The relative path is preferred; the legacy AGENTS location remains a migration fallback.
*/
function renderStudioResolveUiFrameworkDir =
(
    local relative_ui_dir = render_studio_tool_dir + "..\\..\\UI\\Default\\"
    local migration_ui_dir = @"G:\AI\AGENTS\Maxscript\UI\Default\"
    local resolved_ui_dir = ""


    if doesFileExist (relative_ui_dir + "IniSettings.ms") then
    (
        resolved_ui_dir = relative_ui_dir
    )
    else if doesFileExist (migration_ui_dir + "IniSettings.ms") then
    (
        resolved_ui_dir = migration_ui_dir
    )


    resolved_ui_dir
    -- return
)


/*
Loads one required dependency and stops with a clear error when it cannot be resolved.
*/
function renderStudioLoadRequired dependency_path =
(
    if classOf dependency_path != String or dependency_path == "" then
    (
        throw "Render Studio: invalid dependency path."
    )


    if not doesFileExist dependency_path then
    (
        throw ("Render Studio: missing dependency: " + dependency_path)
    )


    fileIn dependency_path
    true
    -- return
)


if render_studio_tool_dir == "" then
(
    throw "Render Studio: run the Tool from its saved Render Studio.ms entry file."
)


render_studio_ui_framework_dir = renderStudioResolveUiFrameworkDir()


if render_studio_ui_framework_dir == "" then
(
    throw "Render Studio: shared UI framework was not found. Expected MAXSCRIPT\\UI\\Default or the migration AGENTS UI path."
)


renderStudioLoadRequired (render_studio_ui_framework_dir + "IniSettings.ms")
renderStudioLoadRequired (render_studio_ui_framework_dir + "RolloutState.ms")
renderStudioLoadRequired (render_studio_ui_framework_dir + "DialogHost.ms")
renderStudioLoadRequired (render_studio_ui_framework_dir + "ScriptReload.ms")
renderStudioLoadRequired (render_studio_ui_framework_dir + "ToolTitleButton.ms")
renderStudioLoadRequired (render_studio_tool_dir + "Render Studio-FN.ms")
renderStudioLoadRequired (render_studio_tool_dir + "Render Studio-UI.ms")


/*
Creates the registered/floating Render Studio dialog with the measured position correction for the current 3ds Max setup.
The final registered position is restored from the saved screen position instead of drifting by the CUI registration offset.
*/
function renderStudioCreateManagedDialog =
(
    local saved_pos = IniSettings.getPoint2 render_studio_ini_path "MainUI" "PosX" "PosY" default_value:[100, 100]
    local saved_height = IniSettings.getInteger render_studio_ini_path "MainUI" "Height" default_value:744
    local position_correction = [6,29]
    local registered_ok = false


    if saved_height < 744 then saved_height = 744


    DialogHost.destroyToolDialogs "Render Studio"
    DialogHost.unregisterDockableDialog render_studio_rollout
    try (destroyDialog render_studio_rollout) catch ()


    createDialog \
        render_studio_rollout \
        width:288 \
        height:saved_height \
        pos:(saved_pos - position_correction) \
        style:#(#style_titlebar, #style_sysmenu, #style_resizing) \
        lockWidth:true \
        lockHeight:false \
        autoLayoutOnResize:true


    registered_ok = DialogHost.registerDockableDialog render_studio_rollout


    if not registered_ok then
    (
        throw "Render Studio: could not register the dialog as a dockable/floating dialog."
    )


    DialogHost.registerToolDialog "Render Studio" render_studio_rollout
    true
    -- return
)


renderStudioCreateManagedDialog()
windows.processPostedMessages()
