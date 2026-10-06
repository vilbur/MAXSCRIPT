/*
Vertex Level Aligner Main 0.073
Main executable entry. Loads backend FN and frontend UI, then opens or registers the Tool.
*/

global EPOLY_TOOLS_RUNTIME_MODE
global EPolyToolsIntegration
global epoly_tools_project_version
global vertex_level_aligner
global vertex_level_aligner_ui
global vertex_level_aligner_rollout
global vertex_level_aligner_main_source
global vertex_level_aligner_main_version
global reloadVertexLevelAlignerMain
global vertexLevelAlignerWriteLog
global vertexLevelAlignerStartLog

vertex_level_aligner_main_version = 0.073
vertex_level_aligner_main_source = getSourceFileName()

/*
Returns the directory containing the Vertex Level Aligner package.
The Tool must be executed from a saved .ms file.
*/
function getVertexLevelAlignerDirectory =
(
    if vertex_level_aligner_main_source == undefined or vertex_level_aligner_main_source == "" then
    (
        throw "Vertex-Level-Aligner.ms must be executed from a saved .ms file."
    )

    getFilenamePath vertex_level_aligner_main_source
    -- return
)

/*
Loads one required Vertex Level Aligner package file.
Missing dependencies fail immediately with the exact expected path.
*/
function loadVertexLevelAlignerFile relative_path =
(
    full_path = getVertexLevelAlignerDirectory() + relative_path

    if not(doesFileExist full_path) then
    (
        throw ("Missing Vertex Level Aligner dependency: " + full_path)
    )

    fileIn full_path quiet:true
    true
    -- return
)

/*
Loads backend first and frontend second without auto-opening either module.
The main entry remains the only file that executes the Tool.
*/
function loadVertexLevelAligner =
(
    loadVertexLevelAlignerFile "Vertex-Level-Aligner-FN.ms"

    if vertex_level_aligner == undefined then
    (
        throw "Vertex Level Aligner backend did not initialize."
    )

    vertexLevelAlignerStartLog vertex_level_aligner_main_source
    vertexLevelAlignerWriteLog "001 MAIN execution started"
    vertexLevelAlignerWriteLog "020 MAIN before UI load"

    loadVertexLevelAlignerFile "Vertex-Level-Aligner-UI.ms"

    vertexLevelAlignerWriteLog "021 MAIN after UI load"

    if vertex_level_aligner_ui == undefined or vertex_level_aligner_rollout == undefined then
    (
        throw "Vertex Level Aligner frontend did not initialize."
    )

    true
    -- return
)


/*
Reloads the canonical main package after explicitly closing the standalone UI.
The frontend delegates RESTART and F1 here so dependency loading remains owned by the main entry.
*/
function reloadVertexLevelAlignerMain =
(
    main_path = vertex_level_aligner_main_source
    if main_path == undefined or main_path == "" then return false
    if not(doesFileExist main_path) then return false

    if vertex_level_aligner_ui != undefined then
    (
        try(vertex_level_aligner_ui.hideUI())catch()
    )

    fileIn main_path quiet:true
    true
    -- return
)

/*
Executes the Tool according to the current EPolyTools runtime mode.
Standalone opens the dialog; embedded/library loading stays headless or registers with the host.
*/
function executeVertexLevelAligner =
(
    loadVertexLevelAligner()

    runtime_mode = EPOLY_TOOLS_RUNTIME_MODE
    if runtime_mode == undefined then runtime_mode = #standalone

    vertexLevelAlignerWriteLog ("030 MAIN runtime mode = " + (runtime_mode as string))

    if epoly_tools_project_version == undefined or epoly_tools_project_version < 0.783 then
    (
        epoly_tools_project_version = 0.783
    )

    if runtime_mode == #standalone then
    (
        vertexLevelAlignerWriteLog "031 MAIN before showUI"
        vertex_level_aligner_ui.showUI()
        vertexLevelAlignerWriteLog "032 MAIN after showUI"
    )
    else if runtime_mode == #embedded and EPolyToolsIntegration != undefined then
    (
        vertexLevelAlignerWriteLog "040 MAIN before embedded registration"
        EPolyToolsIntegration.registerTool "vertex-level-aligner" "Vertex Level Aligner" vertex_level_aligner vertex_level_aligner_rollout vertex_level_aligner.file_version 0.783 vertex_level_aligner_main_source capabilities:#(#detect, #selection, #vertex, #editable_poly, #edit_poly, #ui)
        vertexLevelAlignerWriteLog "041 MAIN embedded registration complete"
    )

    vertexLevelAlignerWriteLog "099 MAIN execution complete"
    true
    -- return
)

executeVertexLevelAligner()
