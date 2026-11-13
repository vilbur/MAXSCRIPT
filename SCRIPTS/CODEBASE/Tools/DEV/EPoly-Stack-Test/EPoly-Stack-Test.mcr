/*
EPoly-Stack-Test toolbar MacroScript.
File Version: 0.01
Project Version: 0.01
*/

global VILBUR_TOOLS_TOOLBAR_PROJECT_VERSION

if (VILBUR_TOOLS_TOOLBAR_PROJECT_VERSION == undefined or VILBUR_TOOLS_TOOLBAR_PROJECT_VERSION < 0.01) then
(
    VILBUR_TOOLS_TOOLBAR_PROJECT_VERSION = 0.01
)

macroScript VilburTools_EPolyStackTest
category:"Vilbur Tools"
toolTip:"Open EPoly Stack Test"
buttonText:"EP Stack"
(
    on execute do
    (
        local script_path = (getFilenamePath (getSourceFileName())) + "EPoly-Stack-Test.ms"

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
