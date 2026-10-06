/*
Vertex Level Aligner Main 0.080
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

vertex_level_aligner_main_version = 0.080
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
Migrates the synced 0.169 frontend source to the 0.170 TreeView-label build before loading it.
The migration is idempotent and only runs against the exact 0.169 formatter/label source.
*/
function migrateVertexLevelAlignerUi0790 ui_path =
(
    if ui_path == undefined or ui_path == "" then return false
    if not(doesFileExist ui_path) then return false

    ui_stream = openFile ui_path mode:"rt"
    if ui_stream == undefined then return false

    ui_text = ""
    while not(eof ui_stream) do ui_text += readLine ui_stream + "\n"
    close ui_stream

    if (findString ui_text "Vertex Level Aligner UI 0.169") == undefined then return false
    if (findString ui_text "function formatWorldZPosition value =") == undefined then return false
    if (findString ui_text "level_text = formatWorldZPosition level_data[1]") == undefined then return false

    old_formatter_text = "    /*\n    Formats one world-Z position as plain numeric text without a Z prefix or unit suffix.\n    */\n    function formatWorldZPosition value =\n    (\n        formatted_value = try(units.formatValue value)catch(value as string)\n        numeric_text = \"\"\n\n        for character_index = 1 to formatted_value.count do\n        (\n            character_text = formatted_value[character_index] as string\n\n            if findString \"-+0123456789.,eE\" character_text != undefined then\n            (\n                numeric_text += character_text\n            )\n        )\n\n        if numeric_text == \"\" then numeric_text = value as string\n\n        numeric_text\n        -- return\n    )\n\n"
    new_formatter_text = "    /*\n    Formats one scene-space distance while removing only meter letters from the displayed item value.\n    Other TreeView label text remains unchanged.\n    */\n    function formatWorldItemValue value =\n    (\n        formatted_value = try(units.formatValue value)catch(value as string)\n        formatted_value = substituteString formatted_value \"m\" \"\"\n        substituteString formatted_value \"M\" \"\"\n        -- return\n    )\n\n"
    old_group_text = "    function getGroupText group_index group_data =\n    (\n        center_z = group_data[1]\n\n        formatWorldZPosition center_z\n        -- return\n    )\n\n"
    new_group_text = "    function getGroupText group_index group_data =\n    (\n        center_z = group_data[1]\n        min_z = group_data[2]\n        max_z = group_data[3]\n        vertex_count = group_data[4].numberSet\n        exact_levels = group_data[5]\n        exact_level_count = if isKindOf exact_levels Array then exact_levels.count else 0\n        is_broken = group_data[6]\n\n        if is_broken then\n        (\n            \"BROKEN | Group \" + (group_index as string) + \" | center \" + formatWorldItemValue center_z + \" | spread \" + formatWorldItemValue (max_z - min_z) + \" | \" + (vertex_count as string) + \" verts | \" + (exact_level_count as string) + \" levels\"\n        )\n        else\n        (\n            if vertex_level_aligner.threshold_value == 0.0 then\n            (\n                \"Level \" + (group_index as string) + \" | \" + formatWorldItemValue center_z + \" | \" + (vertex_count as string) + \" verts\"\n            )\n            else\n            (\n                \"Group \" + (group_index as string) + \" | \" + formatWorldItemValue center_z + \" | \" + (vertex_count as string) + \" verts\"\n            )\n        )\n        -- return\n    )\n\n"

    ui_text = substituteString ui_text "Vertex Level Aligner UI 0.169" "Vertex Level Aligner UI 0.170"
    ui_text = substituteString ui_text "file_version = 0.169," "file_version = 0.170,"
    ui_text = substituteString ui_text "project_version = 0.789," "project_version = 0.790,"
    ui_text = substituteString ui_text "Vertex Level Aligner 0.789" "Vertex Level Aligner 0.790"
    ui_text = substituteString ui_text old_formatter_text new_formatter_text
    ui_text = substituteString ui_text old_group_text new_group_text
    ui_text = substituteString ui_text "                                    level_text = formatWorldZPosition level_data[1]" "                                    level_text = formatWorldItemValue level_data[1] + \" | \" + (level_data[2].numberSet as string) + \" verts\""

    if (findString ui_text "Vertex Level Aligner UI 0.170") == undefined then return false
    if (findString ui_text "function formatWorldItemValue value =") == undefined then return false
    if (findString ui_text "level_text = formatWorldItemValue level_data[1]") == undefined then return false

    ui_stream = createFile ui_path
    if ui_stream == undefined then return false
    format "%" ui_text to:ui_stream
    close ui_stream

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

    ui_path = getVertexLevelAlignerDirectory() + "Vertex-Level-Aligner-UI.ms"
    migrateVertexLevelAlignerUi0790 ui_path
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

    if epoly_tools_project_version == undefined or epoly_tools_project_version < 0.790 then
    (
        epoly_tools_project_version = 0.790
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
        EPolyToolsIntegration.registerTool "vertex-level-aligner" "Vertex Level Aligner" vertex_level_aligner vertex_level_aligner_rollout vertex_level_aligner.file_version 0.790 vertex_level_aligner_main_source capabilities:#(#detect, #selection, #vertex, #editable_poly, #edit_poly, #ui)
        vertexLevelAlignerWriteLog "041 MAIN embedded registration complete"
    )

    vertexLevelAlignerWriteLog "099 MAIN execution complete"
    true
    -- return
)

executeVertexLevelAligner()
