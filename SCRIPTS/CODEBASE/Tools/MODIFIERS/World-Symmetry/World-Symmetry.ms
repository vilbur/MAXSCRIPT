/* World-Symmetry.ms
   Canonical entry for the World-Symmetry child-module development package.
   Run when the owning Modifier Sets main rollout is already open.
*/

global materialIdManagerRollout
global material_id_manager_ini_path

/*
Loads and embeds the child rollout into an already open Modifier Sets UI.
Does not alter or overwrite the owning project's source file.
*/
function worldSymmetryInstall =
(
    if materialIdManagerRollout == undefined then
    (
        format "WORLD SYMMETRY ERROR | Open Modifier Sets first; no owning rollout exists.\n"
        false
    )
    else
    (
        local source_file = getSourceFileName()
        if source_file == undefined or source_file == "" then
        (
            format "WORLD SYMMETRY ERROR | Run this installer from a saved .ms file.\n"
            false
        )
        else
        (
            local source_dir = getFilenamePath source_file
            local core_file = source_dir + "World-Symmetry-Core.ms"
            local ui_file = source_dir + "World-Symmetry-Rollout.ms"
            if doesFileExist core_file and doesFileExist ui_file then
            (
                fileIn core_file
                fileIn ui_file
                addSubRollout materialIdManagerRollout.sub_rollouts worldSymmetryRollout
                format "WORLD SYMMETRY | rollout added to Modifier Sets.\n"
                true
            )
            else
            (
                format "WORLD SYMMETRY ERROR | missing module files | core:% | ui:%\n" core_file ui_file
                false
            )
        )
    )
    -- return
)

worldSymmetryInstall()
