/*
Scene-Offset-Tool toolbar MacroScript.
File Version: 0.01
Project Version: 0.01
*/

global VILBUR_TOOLS_TOOLBAR_PROJECT_VERSION

if (VILBUR_TOOLS_TOOLBAR_PROJECT_VERSION == undefined or VILBUR_TOOLS_TOOLBAR_PROJECT_VERSION < 0.01) then
(
    VILBUR_TOOLS_TOOLBAR_PROJECT_VERSION = 0.01
)

macroScript VilburTools_SceneOffsetTool
category:"Vilbur Tools"
toolTip:"Open Scene Offset Tool"
buttonText:"Offset"
(
    on execute do
    (
        local script_path = (getFilenamePath (getSourceFileName())) + "Scene-Offset-Tool_0.13.ms"

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
