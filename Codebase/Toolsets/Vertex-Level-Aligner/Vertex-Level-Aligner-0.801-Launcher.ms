/*
Vertex Level Aligner 0.801 Launcher 0.02
Loads the preserved project 0.801 backend/UI snapshots without touching the current canonical package.
*/

global vertex_level_aligner_0801_launcher_source
global vertex_level_aligner
global vertex_level_aligner_ui
global vertex_level_aligner_rollout
global reloadVertexLevelAlignerMain
global vertexLevelAlignerStartLog

vertex_level_aligner_0801_launcher_source = getSourceFileName()

/*
Returns the folder that contains this launcher.
The launcher is intended to live in the Vertex Level Aligner project root beside _Versions.
*/
function getVertexLevelAligner0801LauncherDirectory =
(
    if vertex_level_aligner_0801_launcher_source == undefined or vertex_level_aligner_0801_launcher_source == "" then
    (
        throw "Vertex-Level-Aligner-0.801-Launcher.ms must be executed from a saved .ms file."
    )

    getFilenamePath vertex_level_aligner_0801_launcher_source
    -- return
)

/*
Loads one preserved project-0.801 dependency from the _Versions folder.
*/
function loadVertexLevelAligner0801File versioned_file_name =
(
    versions_directory = getVertexLevelAligner0801LauncherDirectory() + "_Versions\\"
    versioned_file_path = versions_directory + versioned_file_name

    if not(doesFileExist versioned_file_path) then
    (
        throw ("Missing Vertex Level Aligner 0.801 file: " + versioned_file_path)
    )

    fileIn versioned_file_path quiet:true
    true
    -- return
)

/*
Reloads this launcher so the stable 0.801 RESTART/F1 path never jumps to the current canonical package.
*/
function reloadVertexLevelAlignerMain =
(
    launcher_path = vertex_level_aligner_0801_launcher_source

    if launcher_path == undefined or launcher_path == "" then return false
    if not(doesFileExist launcher_path) then return false

    if vertex_level_aligner_ui != undefined then
    (
        hide_ok = true

        try
        (
            hide_ok = vertex_level_aligner_ui.hideUI()
        )
        catch
        (
            launcher_hide_exception = getCurrentException()
            hide_ok = false
        )

        if not(hide_ok) then return false
    )

    fileIn launcher_path quiet:true
    true
    -- return
)

/*
Loads the exact preserved project 0.801 runtime: FN 0.041 plus UI 0.181, then opens it standalone.
*/
function launchVertexLevelAligner0801 =
(
    if vertex_level_aligner_ui != undefined then
    (
        hide_ok = true

        try
        (
            hide_ok = vertex_level_aligner_ui.hideUI()
        )
        catch
        (
            launcher_hide_exception = getCurrentException()
            hide_ok = false
        )

        if not(hide_ok) then return false
    )

    loadVertexLevelAligner0801File "Vertex-Level-Aligner-FN_0.041.ms"

    if vertex_level_aligner == undefined then
    (
        throw "Vertex Level Aligner 0.801 backend did not initialize."
    )

    if vertexLevelAlignerStartLog != undefined then
    (
        vertexLevelAlignerStartLog vertex_level_aligner_0801_launcher_source
    )

    loadVertexLevelAligner0801File "Vertex-Level-Aligner-UI_0.181.ms"

    if vertex_level_aligner_ui == undefined or vertex_level_aligner_rollout == undefined then
    (
        throw "Vertex Level Aligner 0.801 frontend did not initialize."
    )

    show_ok = vertex_level_aligner_ui.showUI()
    if not(show_ok) then return false

    true
    -- return
)

launchVertexLevelAligner0801()
