/*
Surface-Intersections 0.09
Project version: 0.13
Canonical entry/loader for the live surface intersection Tool.
Loads the backend and frontend independently, opening the dialog even when no source geometry nodes are selected.
*/
global si_project_version
global si_surface_intersections_entry_version = "0.09"
global si_surface_intersections_main_path = getSourceFileName()
global si_surface_intersections_directory = getFilenamePath si_surface_intersections_main_path
if si_project_version == undefined then
(
    si_project_version = "0.13"
)
else if (si_project_version as float) < 0.13 then
(
    si_project_version = "0.13"
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
        fileIn backend_path
        fileIn ui_path
        /* The UI is available with an empty selection; generation still requires two sources. */
        siOpenSurfaceIntersectionsUI()
    )
    else
    (
        format "SURFACE INTERSECTIONS LOAD FAILED | FN:% exists:% | UI:% exists:%\n" backend_path (doesFileExist backend_path) ui_path (doesFileExist ui_path)
    )
)
