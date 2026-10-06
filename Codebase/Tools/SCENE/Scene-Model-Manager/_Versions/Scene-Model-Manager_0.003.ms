/*
Scene Model Manager main entry.
File version: 0.003
Project version: 0.003
*/

global scene_model_manager_project_version

if (scene_model_manager_project_version == undefined or scene_model_manager_project_version < 0.003) then
(
    scene_model_manager_project_version = 0.003
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

    if doesFileExist backend_file then
    (
        fileIn backend_file
    )
    else
    (
        throw ("Scene Model Manager backend not found: " + backend_file)
    )

    if doesFileExist ui_file then
    (
        fileIn ui_file
    )
    else
    (
        throw ("Scene Model Manager UI not found: " + ui_file)
    )

    openSceneModelManager()
    true
    -- return
)

launchSceneModelManager()
