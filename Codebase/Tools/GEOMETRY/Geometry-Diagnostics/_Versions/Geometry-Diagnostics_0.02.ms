/*
Geometry Diagnostics main entry file.
Loads shared UI helpers, backend, frontend, then opens the Tool.
*/

global geometry_diagnostics_main_version = "0.02"
global geometry_diagnostics_main_project_version = "0.05"
global geometry_diagnostics_project_version
global geometry_diagnostics_source_file = getSourceFileName()
global geometry_diagnostics_directory
global geometry_diagnostics_ini_helper_path
global geometry_diagnostics_dialog_helper_path
global geometry_diagnostics_reload_helper_path
global geometry_diagnostics_title_helper_path
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

geometry_diagnostics_ini_helper_path = geometry_diagnostics_directory + "..\\..\\..\\UI\\Default\\IniSettings.ms"
geometry_diagnostics_dialog_helper_path = geometry_diagnostics_directory + "..\\..\\..\\UI\\Default\\DialogHost.ms"
geometry_diagnostics_reload_helper_path = geometry_diagnostics_directory + "..\\..\\..\\UI\\Default\\ScriptReload.ms"
geometry_diagnostics_title_helper_path = geometry_diagnostics_directory + "..\\..\\..\\UI\\Default\\ToolTitleButton.ms"
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
fileIn geometry_diagnostics_fn_path
fileIn geometry_diagnostics_ui_path

openGeometryDiagnostics()
