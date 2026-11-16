/*
Surface-Intersections 0.10
Project version: 1.02
Canonical entry/loader for the live surface intersection Tool.
Loads the backend and frontend independently, opening the dialog even when no source geometry nodes are selected.
*/
global si_project_version
global si_surface_intersections_entry_version = "0.10"
global si_surface_intersections_main_path = getSourceFileName()
global si_surface_intersections_directory = getFilenamePath si_surface_intersections_main_path
if si_project_version == undefined then
(
    si_project_version = "1.02"
)
else if (si_project_version as float) < 1.02 then
(
    si_project_version = "1.02"
)

/*
Keep loader paths local to this parenthesized expression.
MAXScript does not allow local declarations at file top level.
*/
(
    local backend_path = si_surface_intersections_directory + "Surface-Intersections-FN.ms"
    local ui_path = si_surface_intersections_directory + "Surface-Intersections-UI.ms"

    if (doesFileExist backend_path) and (doesFileExist ui_path) then
    (
        local loading_path = backend_path
        local load_error = undefined
        local previous_opener = globalVars.get #siOpenSurfaceIntersectionsUI
        local ui_opener = undefined

        try
        (
            fileIn backend_path
            loading_path = ui_path
            /* Require the current UI load to publish its own opener. */
            globalVars.set #siOpenSurfaceIntersectionsUI undefined
            fileIn ui_path
            ui_opener = globalVars.get #siOpenSurfaceIntersectionsUI
            if classOf ui_opener != MAXScriptFunction then
            (
                load_error = "UI script did not define siOpenSurfaceIntersectionsUI."
            )
        )
        catch
        (
            load_error = getCurrentException()
        )

        if load_error != undefined then
        (
            globalVars.set #siOpenSurfaceIntersectionsUI previous_opener
            throw ("SURFACE INTERSECTIONS LOAD FAILED | " + loading_path + " | " + load_error)
        )

        ui_opener()
    )
    else
    (
        format "SURFACE INTERSECTIONS LOAD FAILED | FN:% exists:% | UI:% exists:%\n" backend_path (doesFileExist backend_path) ui_path (doesFileExist ui_path)
    )
)
