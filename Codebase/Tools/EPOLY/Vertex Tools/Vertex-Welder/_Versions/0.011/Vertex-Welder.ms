/*
    Vertex Welder Main 0.011
    Canonical Tool entry. Loads shared UI helpers, backend FN, frontend UI, then opens the standalone dialog.
*/

global VertexWelder
global VertexWelder_UI
global vertexWelderOpenUi
global vertex_welder_project_version
global vertex_welder_file_version = 0.011
global vertex_welder_stored_project_version = 0.011
global vertex_welder_script_path = getSourceFileName()
global vertex_welder_script_directory
global vertex_welder_tool_title
global vertex_welder_ui_framework_directory
global vertex_welder_ui_ini_path
global vertex_welder_ui_ini_section = "MainUI"
global vertex_welder_script_prefix = "Vertex-Welder"
global vertex_welder_dialog_key = "Vertex-Welder"
global DialogHost

if vertex_welder_project_version == undefined or vertex_welder_project_version < vertex_welder_stored_project_version then
(
    vertex_welder_project_version = vertex_welder_stored_project_version
)

vertex_welder_tool_title = "Vertex Welder " + (vertex_welder_project_version as string)

/*
Resolves the directory containing the canonical Vertex Welder package.
The Tool must be executed from a saved .ms file so package-relative dependencies and settings remain deterministic.
*/
function vertexWelderGetScriptDirectory =
(
    if vertex_welder_script_path == undefined or vertex_welder_script_path == "" then
    (
        throw "Vertex-Welder.ms must be executed from a saved .ms file."
    )

    getFilenamePath vertex_welder_script_path
    -- return
)

/*
Resolves the shared UI framework from the canonical Maxscript/Codebase package location.
The Codebase marker is a downward shared-dependency root, not a search for any parent Toolset or manager.
*/
function vertexWelderGetUiFrameworkDirectory =
(
    lower_directory = toLower vertex_welder_script_directory
    marker_text = "\\Codebase\\"
    marker_index = findString lower_directory (toLower marker_text)

    if marker_index == undefined then return ""

    maxscript_root = substring vertex_welder_script_directory 1 (marker_index - 1)
    framework_directory = maxscript_root + "\\UI\\Default\\"

    if not(doesFileExist (framework_directory + "IniSettings.ms")) then return ""
    if not(doesFileExist (framework_directory + "DialogHost.ms")) then return ""
    if not(doesFileExist (framework_directory + "ScriptReload.ms")) then return ""
    if not(doesFileExist (framework_directory + "ToolTitleButton.ms")) then return ""

    framework_directory
    -- return
)

/*
Loads one canonical shared UI helper required by the frontend.
Missing shared dependencies fail immediately with the exact expected path.
*/
function vertexWelderLoadUiFrameworkHelper helper_name =
(
    if vertex_welder_ui_framework_directory == undefined or vertex_welder_ui_framework_directory == "" then
    (
        throw "Vertex Welder cannot resolve the shared UI framework directory from the canonical Codebase path."
    )

    helper_path = vertex_welder_ui_framework_directory + helper_name

    if not(doesFileExist helper_path) then
    (
        throw ("Vertex Welder missing shared UI helper: " + helper_path)
    )

    fileIn helper_path quiet:true
    true
    -- return
)

/*
Loads one package-relative Vertex Welder source module.
The main entry remains the only package file that auto-executes the Tool.
*/
function vertexWelderLoadPackageFile file_name =
(
    package_path = vertex_welder_script_directory + file_name

    if not(doesFileExist package_path) then
    (
        throw ("Vertex Welder missing package file: " + package_path)
    )

    fileIn package_path quiet:true
    true
    -- return
)

/*
Closes stale Vertex Welder dialogs before the frontend rollout is redefined.
Dialog teardown is harmless reload cleanup, so stale close-callback errors must never block startup.
*/
function vertexWelderCloseExistingDialog =
(
    if DialogHost != undefined then
    (
        DialogHost.destroyToolDialogs vertex_welder_dialog_key
    )

    if VertexWelder_UI != undefined then
    (
        try
        (
            if DialogHost != undefined then DialogHost.unregisterDockableDialog VertexWelder_UI
            if VertexWelder_UI.inDialog then destroyDialog VertexWelder_UI
        )
        catch()
    )

    true
    -- return
)

/*
Loads the current package and opens the standalone dialog.
Backend and frontend files remain independently loadable and never auto-open themselves.
*/
function vertexWelderExecute =
(
    vertex_welder_script_directory = vertexWelderGetScriptDirectory()
    vertex_welder_ui_ini_path = vertex_welder_script_directory + "Vertex-Welder.ini"
    vertex_welder_ui_framework_directory = vertexWelderGetUiFrameworkDirectory()

    vertexWelderLoadUiFrameworkHelper "IniSettings.ms"
    vertexWelderLoadUiFrameworkHelper "DialogHost.ms"
    vertexWelderLoadUiFrameworkHelper "ScriptReload.ms"
    vertexWelderLoadUiFrameworkHelper "ToolTitleButton.ms"

    vertexWelderCloseExistingDialog()

    vertexWelderLoadPackageFile "Vertex-Welder-FN.ms"
    vertex_welder_tool_title = "Vertex Welder " + (vertex_welder_project_version as string)

    if VertexWelder == undefined then
    (
        throw "Vertex Welder backend did not initialize."
    )

    vertexWelderLoadPackageFile "Vertex-Welder-UI.ms"

    if VertexWelder_UI == undefined or vertexWelderOpenUi == undefined then
    (
        throw "Vertex Welder frontend did not initialize."
    )

    if not(vertexWelderOpenUi()) then
    (
        throw "Vertex Welder dialog could not be opened."
    )

    true
    -- return
)

vertexWelderExecute()
