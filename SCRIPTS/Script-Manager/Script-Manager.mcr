/*
Script-Manager toolbar MacroScript.
File Version: 0.02
Project Version: 0.02
*/

global VILBUR_TOOLS_TOOLBAR_PROJECT_VERSION

if (VILBUR_TOOLS_TOOLBAR_PROJECT_VERSION == undefined or VILBUR_TOOLS_TOOLBAR_PROJECT_VERSION < 0.02) then
(
    VILBUR_TOOLS_TOOLBAR_PROJECT_VERSION = 0.02
)

macroScript VilburTools_ScriptManager
category:"Vilbur Tools"
toolTip:"Open Script Manager"
buttonText:"Scripts"
(
    on execute do
    (
        local script_path = @"C:\GoogleDrive\CODE\MAXSCRIPT\Script-Manager\Script-Manager.ms"

        if (doesFileExist script_path) then
        (
            fileIn script_path
        )
        else
        (
            format "VILBUR TOOLS: Missing script: %\n" script_path
        )
    )
)
