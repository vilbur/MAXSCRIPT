/*
Scene Model Manager main entry.
File version: 0.017
Project version: 0.017
*/

global scene_model_manager_project_version
global scene_model_manager_dump
global scene_model_manager_dump_path

if (scene_model_manager_project_version == undefined or scene_model_manager_project_version < 0.017) then
(
    scene_model_manager_project_version = 0.017
)

/*
Loads the shared DEV DUMP logger when available.
Logging failure never changes Scene Model Manager functional behavior.
*/
function initializeSceneModelManagerDump source_dir source_file =
(
    dump_module_file = source_dir + "..\\DUMP\\DUMP.ms"
    scene_model_manager_dump_path = source_dir + "logs\\Scene-Model-Manager-DUMP.txt"
    scene_model_manager_dump = undefined

    if doesFileExist dump_module_file then
    (
        try
        (
            fileIn dump_module_file
            scene_model_manager_dump = DumpDevLoggerStruct()

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
    else
    (
        format "Scene Model Manager DUMP module not found: %\n" dump_module_file
        false
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
