/*
Loads the Print-Debug backend and UI from this script's own directory.
File version: 0.01
Project version: 0.01
*/
global print_debug_global_project_version
if print_debug_global_project_version == undefined then
(
    print_debug_global_project_version = 0.01
)
else if print_debug_global_project_version < 0.01 then
(
    print_debug_global_project_version = 0.01
)

(
    local entry_file_path = getSourceFileName()
    local tool_folder = getFilenamePath entry_file_path
    fileIn (tool_folder + "Print-Debug-FN.ms")
    fileIn (tool_folder + "Print-Debug-UI.ms")
    PrintDebugUI.show()
)
