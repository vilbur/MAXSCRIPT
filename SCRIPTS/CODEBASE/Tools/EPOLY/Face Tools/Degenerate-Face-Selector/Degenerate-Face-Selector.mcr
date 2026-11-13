/*
Degenerate-Face-Selector toolbar MacroScript.
File Version: 0.01
Project Version: 0.01
*/

global VILBUR_TOOLS_TOOLBAR_PROJECT_VERSION

if (VILBUR_TOOLS_TOOLBAR_PROJECT_VERSION == undefined or VILBUR_TOOLS_TOOLBAR_PROJECT_VERSION < 0.01) then
(
    VILBUR_TOOLS_TOOLBAR_PROJECT_VERSION = 0.01
)

macroScript VilburTools_DegenerateFaceSelector
category:"Vilbur Tools"
toolTip:"Open Degenerate Face Selector"
buttonText:"Bad Faces"
(
    on execute do
    (
        local script_path = (getFilenamePath (getSourceFileName())) + "Degenerate-Face-Selector.ms"

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
