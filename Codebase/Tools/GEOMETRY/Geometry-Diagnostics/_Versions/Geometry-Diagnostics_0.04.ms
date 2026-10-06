/*
Geometry Diagnostics main entry file.
Loads shared UI helpers, backend, frontend, then opens the Tool.
*/

global geometry_diagnostics_main_version = "0.04"
global geometry_diagnostics_main_project_version = "0.07"
global geometry_diagnostics_project_version
global geometry_diagnostics_source_file = getSourceFileName()
global geometry_diagnostics_directory
global geometry_diagnostics_ui_default_directory
global geometry_diagnostics_ini_helper_path
global geometry_diagnostics_dialog_helper_path
global geometry_diagnostics_reload_helper_path
global geometry_diagnostics_title_helper_path
global geometry_diagnostics_vertex_color_painter_path
global geometry_diagnostics_fn_path
global geometry_diagnostics_ui_path
global geometry_diagnostics_ini_path

if geometry_diagnostics_project_version == undefined then
(
    geometry_diagnostics_project_version = geometry_diagnostics_main_project_version
)
else if (geometry_diagnostics_project_version as float) < (geometry_diagnostics_main_project_version as float) then
(
    geometry_diagnostics_project_version = geometry_diagnostics_main_project_version
)

if geometry_diagnostics_source_file == undefined or geometry_diagnostics_source_file == "" then
(
    throw "Geometry-Diagnostics.ms must be executed from a saved .ms file."
)

geometry_diagnostics_directory = getFilenamePath geometry_diagnostics_source_file

geometry_diagnostics_ui_default_directory = geometry_diagnostics_directory + "..\\..\\..\\..\\UI\\Default\\"

if not doesFileExist (geometry_diagnostics_ui_default_directory + "IniSettings.ms") then
(
    geometry_diagnostics_ui_default_directory = geometry_diagnostics_directory + "..\\..\\..\\UI\\Default\\"
)

geometry_diagnostics_ini_helper_path = geometry_diagnostics_ui_default_directory + "IniSettings.ms"
geometry_diagnostics_dialog_helper_path = geometry_diagnostics_ui_default_directory + "DialogHost.ms"
geometry_diagnostics_reload_helper_path = geometry_diagnostics_ui_default_directory + "ScriptReload.ms"
geometry_diagnostics_title_helper_path = geometry_diagnostics_ui_default_directory + "ToolTitleButton.ms"
geometry_diagnostics_vertex_color_painter_path = geometry_diagnostics_directory + "..\\..\\..\\Operations\\Vertex-Color-Painter\\Vertex-Color-Painter.ms"

if not doesFileExist geometry_diagnostics_vertex_color_painter_path then
(
    geometry_diagnostics_vertex_color_painter_path = geometry_diagnostics_directory + "..\\..\\Operations\\Vertex-Color-Painter\\Vertex-Color-Painter.ms"
)

geometry_diagnostics_fn_path = geometry_diagnostics_directory + "Geometry-Diagnostics-FN.ms"
geometry_diagnostics_ui_path = geometry_diagnostics_directory + "Geometry-Diagnostics-UI.ms"
geometry_diagnostics_ini_path = geometry_diagnostics_directory + "Geometry-Diagnostics.ini"

if not doesFileExist geometry_diagnostics_ini_helper_path then
(
    throw ("Missing Geometry Diagnostics dependency: " + geometry_diagnostics_ini_helper_path)
)

if not doesFileExist geometry_diagnostics_dialog_helper_path then
(
    throw ("Missing Geometry Diagnostics dependency: " + geometry_diagnostics_dialog_helper_path)
)

if not doesFileExist geometry_diagnostics_reload_helper_path then
(
    throw ("Missing Geometry Diagnostics dependency: " + geometry_diagnostics_reload_helper_path)
)

if not doesFileExist geometry_diagnostics_title_helper_path then
(
    throw ("Missing Geometry Diagnostics dependency: " + geometry_diagnostics_title_helper_path)
)

if not doesFileExist geometry_diagnostics_vertex_color_painter_path then
(
    throw ("Missing Geometry Diagnostics operation dependency: " + geometry_diagnostics_vertex_color_painter_path)
)

if not doesFileExist geometry_diagnostics_fn_path then
(
    throw ("Missing Geometry Diagnostics backend: " + geometry_diagnostics_fn_path)
)

if not doesFileExist geometry_diagnostics_ui_path then
(
    throw ("Missing Geometry Diagnostics frontend: " + geometry_diagnostics_ui_path)
)

fileIn geometry_diagnostics_ini_helper_path
fileIn geometry_diagnostics_dialog_helper_path
fileIn geometry_diagnostics_reload_helper_path
fileIn geometry_diagnostics_title_helper_path
fileIn geometry_diagnostics_vertex_color_painter_path
fileIn geometry_diagnostics_fn_path
fileIn geometry_diagnostics_ui_path

openGeometryDiagnostics()
