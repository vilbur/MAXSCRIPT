/*
Toolbar-Creator launcher 0.01 | shared project 0.12.
Run this script to open Toolbar-Creator-UI.ms.
The independent backend is implemented in Toolbar-Creator-FN.ms.
*/

global toolbarCreatorLauncherFileVersion
global toolbarCreatorLauncherProjectVersion

toolbarCreatorLauncherFileVersion = 0.01
toolbarCreatorLauncherProjectVersion = 0.12

toolbar_creator_launcher_source_path = getSourceFileName()
if toolbar_creator_launcher_source_path == undefined or toolbar_creator_launcher_source_path == "" then
(
    throw "Toolbar-Creator launcher must be loaded from a saved .ms file."
)

toolbar_creator_launcher_directory = getFilenamePath toolbar_creator_launcher_source_path
toolbar_creator_launcher_ui_path = toolbar_creator_launcher_directory + "Toolbar-Creator-UI.ms"

if not doesFileExist toolbar_creator_launcher_ui_path then
(
    throw ("Missing Toolbar-Creator UI: " + toolbar_creator_launcher_ui_path)
)

fileIn toolbar_creator_launcher_ui_path quiet:true
