/*
Spline Editor - canonical entry point.
File version: 0.004 | Project version: 0.004
*/

(
    local main_file_version = "0.004"
    local stored_project_version = "0.004"
    global spline_editor_project_version

    if spline_editor_project_version == undefined then
    (
        spline_editor_project_version = stored_project_version
    )
    else if (spline_editor_project_version as float) < (stored_project_version as float) then
    (
        spline_editor_project_version = stored_project_version
    )
    global spline_editor_entry_path = getSourceFileName()
    global spline_editor_directory
    global spline_editor_ini_path
    global spline_editor_ui_framework_path

    if spline_editor_entry_path == undefined or spline_editor_entry_path == "" then
    (
        throw "Spline Editor | Run the saved Spline-Editor.ms file using File > Run Script."
    )

    spline_editor_directory = getFilenamePath spline_editor_entry_path
    spline_editor_ini_path = spline_editor_directory + "Spline-Editor.ini"

    /*
    Set this once to the canonical shared UI location on the workstation.
    The shared framework remains read-only and is never copied into this Tool.
    */
    if spline_editor_ui_framework_path == undefined then
    (
        spline_editor_ui_framework_path = @"G:\AI\AGENTS\Maxscript\UI\Default\"
    )

    /*
    Loads a required native MaxScript dependency from its actual file path.
    Missing files abort the tool rather than creating a fake working UI.
    */
    function splineEditorLoadDependency dependency_path =
    (
        if not (doesFileExist dependency_path) then
        (
            format "Spline Editor | Missing dependency: %\n" dependency_path
            throw ("Spline Editor | Missing dependency: " + dependency_path)
        )

        fileIn dependency_path
        true
        -- return
    )

    splineEditorLoadDependency (spline_editor_ui_framework_path + "IniSettings.ms")
    splineEditorLoadDependency (spline_editor_ui_framework_path + "RolloutState.ms")
    splineEditorLoadDependency (spline_editor_ui_framework_path + "DialogHost.ms")
    splineEditorLoadDependency (spline_editor_ui_framework_path + "ScriptReload.ms")
    splineEditorLoadDependency (spline_editor_ui_framework_path + "ToolTitleButton.ms")

    splineEditorLoadDependency (spline_editor_directory + "Spline-Editor-FN.ms")
    splineEditorLoadDependency (spline_editor_directory + "Spline-Editor-UI.ms")

    splineEditorShowDialog()
)
