/*
Toolbar-Creator UI entry point 0.12 | shared project 0.14.
Only open the full UI when no Toolbar-Creator dialog is already displayed.
Keeping this guard outside the rollout implementation avoids recompiling or
destroying live .NET controls when the launcher is executed a second time.
*/

global toolbarCreatorUiFileVersion
global toolbarCreatorUiProjectVersion
global toolbarCreatorUiRollout

toolbarCreatorUiFileVersion = 0.12
toolbarCreatorUiProjectVersion = 0.14

toolbar_creator_ui_entry_path = getSourceFileName()
if toolbar_creator_ui_entry_path == undefined or toolbar_creator_ui_entry_path == "" then
(
    throw "Toolbar-Creator UI must be loaded from a saved .ms file."
)

toolbar_creator_ui_core_path = (getFilenamePath toolbar_creator_ui_entry_path) + "Toolbar-Creator-UI-Core.ms"
if not doesFileExist toolbar_creator_ui_core_path then
(
    throw ("Missing Toolbar-Creator UI core: " + toolbar_creator_ui_core_path)
)

toolbar_creator_ui_already_open = false
if isKindOf toolbarCreatorUiRollout RolloutClass then
(
    toolbar_creator_ui_already_open = toolbarCreatorUiRollout.isDisplayed
)

if toolbar_creator_ui_already_open then
(
    try (setForegroundWindow toolbarCreatorUiRollout)
    catch (try (setFocus toolbarCreatorUiRollout) catch ())
    format "[Toolbar-Creator UI] Already running; focused the existing dialog.\n"
)
else
(
    fileIn toolbar_creator_ui_core_path quiet:true
)
