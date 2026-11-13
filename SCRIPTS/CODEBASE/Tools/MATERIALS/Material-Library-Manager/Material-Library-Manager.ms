/* Material-Library-Manager canonical entry. File version 0.02; project version 0.02.
Loads canonical shared UI helpers and sibling backend/frontend, then opens one tool dialog.
*/
global mlm_project_version
if mlm_project_version == undefined or mlm_project_version < 0.02 then
(
    mlm_project_version = 0.02
)
global mlm_entry_file_version = 0.02
global mlm_entry_project_version = 0.02
global mlm_entry_test_mode
/* Validates that a directory contains the complete canonical UI helper set.
Returns true only when every required helper exists.
*/
function isMlmUiFrameworkDir ui_framework_dir =
(
    local required_helpers = #("IniSettings.ms", "RolloutState.ms", "DialogHost.ms", "ScriptReload.ms", "ToolTitleButton.ms")
    local normalized_dir = ""
    if ui_framework_dir != undefined then normalized_dir = trimRight (ui_framework_dir as string) "\\/"
    local framework_valid = normalized_dir != ""
    if framework_valid then
    (
        normalized_dir += "\\"
        for helper_name in required_helpers while framework_valid do
        (
            framework_valid = doesFileExist (normalized_dir + helper_name)
        )
    )
    framework_valid
    -- return
)
/* Resolves the canonical UI framework and repairs an invalid stored dependency path.
Prompts only when no valid stored or repository-relative framework is available.
*/
function resolveMlmUiFrameworkDir tool_dir config_path prompt_for_path:true =
(
    local stored_dir = getINISetting config_path "Dependencies" "UiFrameworkDir"
    local codebase_relative = tool_dir + "..\\..\\..\\..\\UI\\Default\\"
    local agents_relative = tool_dir + "..\\..\\..\\..\\..\\..\\AI\\AGENTS\\Maxscript\\UI\\Default\\"
    local candidate_dirs = #(stored_dir, codebase_relative, agents_relative)
    local resolved_dir = ""
    for candidate_dir in candidate_dirs while resolved_dir == "" do
    (
        if isMlmUiFrameworkDir candidate_dir then
        (
            resolved_dir = (trimRight candidate_dir "\\/") + "\\"
        )
    )
    if resolved_dir == "" and prompt_for_path then
    (
        local selected_dir = getSavePath caption:"Locate shared MaxScript UI/Default folder (saved for future runs)"
        if selected_dir != undefined then
        (
            selected_dir = (trimRight selected_dir "\\/") + "\\"
            if isMlmUiFrameworkDir selected_dir then
            (
                resolved_dir = selected_dir
            )
            else
            (
                throw ("Selected folder does not contain the complete shared UI framework: " + selected_dir)
            )
        )
    )
    if resolved_dir == "" then
    (
        throw "Material Library Manager requires the canonical UI/Default framework folder."
    )
    local normalized_stored_dir = if stored_dir == "" then "" else (trimRight stored_dir "\\/") + "\\"
    if (toLower normalized_stored_dir) != (toLower resolved_dir) then
    (
        setINISetting config_path "Dependencies" "UiFrameworkDir" resolved_dir
    )
    resolved_dir
    -- return
)
if mlm_entry_test_mode == undefined or mlm_entry_test_mode == false then
(
    local entry_file = getSourceFileName()
    local tool_dir = getFilenamePath entry_file
    local config_path = tool_dir + "Material-Library-Manager.ini"
    local ui_framework_dir = resolveMlmUiFrameworkDir tool_dir config_path
    for helper_name in #("IniSettings.ms", "RolloutState.ms", "DialogHost.ms", "ScriptReload.ms", "ToolTitleButton.ms") do
    (
        local helper_path = ui_framework_dir + helper_name
        fileIn helper_path
    )
    DialogHost.destroyToolDialogs "Material-Library-Manager"
    fileIn (tool_dir + "Material-Library-Manager-FN.ms")
    MaterialLibraryManager.log_path = tool_dir + "logs\\Material-Library-Manager.log"
    fileIn (tool_dir + "Material-Library-Manager-UI.ms")
    openMaterialLibraryManager entry_file
)
