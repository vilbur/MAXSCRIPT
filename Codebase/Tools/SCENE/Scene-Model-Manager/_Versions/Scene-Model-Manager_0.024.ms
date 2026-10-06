/*
Scene Model Manager main entry.
File version: 0.024
Project version: 0.033
*/

global scene_model_manager_project_version
global scene_model_manager_dump
global scene_model_manager_dump_path
global scene_model_manager_dump_module_loaded
global scene_model_manager_dump_module_file
global scene_model_manager_dump_constructor
global openSceneModelManager

if (scene_model_manager_project_version == undefined or scene_model_manager_project_version < 0.033) then
(
    scene_model_manager_project_version = 0.033
)

/*
Loads the shared DUMP type in top-level script scope before any initializer function tries to construct it.
Loading it from inside a function keeps the struct definition out of the compiled global constructor lookup.
*/
scene_model_manager_dump_module_loaded = false
scene_model_manager_dump_constructor = undefined
scene_model_manager_dump_module_file = getFilenamePath (getSourceFileName()) + "..\\DUMP\\DUMP.ms"

if doesFileExist scene_model_manager_dump_module_file then
(
    try
    (
        fileIn scene_model_manager_dump_module_file

        if DumpDevLoggerStruct != undefined then
        (
            scene_model_manager_dump_constructor = DumpDevLoggerStruct
            scene_model_manager_dump_module_loaded = true
        )
    )
    catch
    (
        dump_load_error_text = getCurrentException()
        scene_model_manager_dump_module_loaded = false
        format "Scene Model Manager DUMP module load failed: %\n" dump_load_error_text
    )
)
else
(
    format "Scene Model Manager DUMP module not found: %\n" scene_model_manager_dump_module_file
)

/*
Loads the shared DEV DUMP logger when available.
Logging failure never changes Scene Model Manager functional behavior.
*/
function initializeSceneModelManagerDump source_dir source_file =
(
    scene_model_manager_dump_path = source_dir + "logs\\Scene-Model-Manager-DUMP.txt"
    scene_model_manager_dump = undefined

    if not scene_model_manager_dump_module_loaded then
    (
        false
    )
    else if scene_model_manager_dump_constructor == undefined then
    (
        format "Scene Model Manager DUMP constructor is unavailable after module load.\n"
        false
    )
    else
    (
        try
        (
            scene_model_manager_dump = scene_model_manager_dump_constructor()

            if scene_model_manager_dump.start scene_model_manager_dump_path then
            (
                scene_model_manager_dump.log ("RUN START | project=" + (scene_model_manager_project_version as string))
                scene_model_manager_dump.log ("SOURCE | " + source_file)
                true
            )
            else
            (
                scene_model_manager_dump = undefined
                format "Scene Model Manager DUMP start failed: %\n" scene_model_manager_dump_path
                false
            )
        )
        catch
        (
            dump_error_text = getCurrentException()
            scene_model_manager_dump = undefined
            format "Scene Model Manager DUMP init failed: %\n" dump_error_text
            false
        )
    )
    -- return
)

/*
Loads the Toolset backend and frontend from this package and opens the manager.
The main entry is the only package file that auto-executes the UI.
*/
function launchSceneModelManager =
(
    source_file = getSourceFileName()
    source_dir = getFilenamePath source_file
    backend_file = source_dir + "Scene-Model-Manager-FN.ms"
    ui_file = source_dir + "Scene-Model-Manager-UI.ms"
    model_nodes_ui_file = source_dir + "Scene-Model-Manager-Model-Nodes-UI.ms"

    initializeSceneModelManagerDump source_dir source_file

    if scene_model_manager_dump != undefined then
    (
        scene_model_manager_dump.log ("LOAD BACKEND | " + backend_file)
    )

    if doesFileExist backend_file then
    (
        fileIn backend_file
    )
    else
    (
        throw ("Scene Model Manager backend not found: " + backend_file)
    )

    if scene_model_manager_dump != undefined then
    (
        scene_model_manager_dump.log "BACKEND LOADED"
        scene_model_manager_dump.log ("LOAD UI | " + ui_file)
    )

    if doesFileExist ui_file then
    (
        fileIn ui_file
    )
    else
    (
        throw ("Scene Model Manager UI not found: " + ui_file)
    )

    if scene_model_manager_dump != undefined then
    (
        scene_model_manager_dump.log "UI LOADED"
        scene_model_manager_dump.log ("LOAD MODEL NODES UI | " + model_nodes_ui_file)
    )

    if doesFileExist model_nodes_ui_file then
    (
        fileIn model_nodes_ui_file
    )
    else
    (
        throw ("Scene Model Manager MODEL NODES UI not found: " + model_nodes_ui_file)
    )

    if scene_model_manager_dump != undefined then
    (
        scene_model_manager_dump.log "MODEL NODES UI LOADED"
    )

    if openSceneModelManager == undefined then
    (
        if scene_model_manager_dump != undefined then
        (
            scene_model_manager_dump.log "ERROR | UI ENTRY UNAVAILABLE | openSceneModelManager"
        )

        throw ("Scene Model Manager UI entry function unavailable after loading: " + ui_file)
    )

    openSceneModelManager()

    if scene_model_manager_dump != undefined then
    (
        scene_model_manager_dump.log "DIALOG OPENED"
    )

    true
    -- return
)

launchSceneModelManager()
