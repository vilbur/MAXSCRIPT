/* Modifier Set Stack - entry point.
   File version: 0.011 | Project version: 0.087 | Prototype.
*/

global modifier_set_stack_project_version
global modifier_set_stack_file_version_entry = 0.011
global modifier_set_stack_stored_project_version_entry = 0.087

if modifier_set_stack_project_version == undefined or modifier_set_stack_stored_project_version_entry > modifier_set_stack_project_version then
(
    modifier_set_stack_project_version = modifier_set_stack_stored_project_version_entry
)

source_folder = getFilenamePath (getSourceFileName())
fileIn (source_folder + "Modifier-Set-Stack-FN.ms")
fileIn (source_folder + "Modifier-Set-Stack-UI.ms")

try
(
    destroyDialog modifierSetStackUI
)
catch
(
    format "Modifier Set Stack: no existing dialog to destroy: %\n" (getCurrentException())
)
createDialog modifierSetStackUI width:640 height:775 style:#(#style_titlebar, #style_sysmenu, #style_resizing)
