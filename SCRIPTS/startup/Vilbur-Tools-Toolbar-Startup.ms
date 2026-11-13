/*
Registers the Vilbur Tools toolbar MacroScripts and shows the toolbar.
File Version: 0.02
Project Version: 0.02
*/

global VILBUR_TOOLS_TOOLBAR_PROJECT_VERSION
global vilbur_tools_macro_files

if (VILBUR_TOOLS_TOOLBAR_PROJECT_VERSION == undefined or VILBUR_TOOLS_TOOLBAR_PROJECT_VERSION < 0.02) then
(
    VILBUR_TOOLS_TOOLBAR_PROJECT_VERSION = 0.02
)

vilbur_tools_macro_files = #(
    @"C:\GoogleDrive\CODE\MAXSCRIPT\Script-Manager\Script-Manager.mcr",
    @"C:\GoogleDrive\AI\AGENTS\Maxscript\Codebase\Tools\DEV\Preset-Manager\Preset-Manager.mcr",
    @"C:\GoogleDrive\AI\AGENTS\Maxscript\Codebase\Tools\DEV\EPoly-Stack-Test\EPoly-Stack-Test.mcr",
    @"C:\GoogleDrive\AI\AGENTS\Maxscript\Codebase\Tools\LAYERS\Object-Layer-Manager\Object-Layer-Manager.mcr",
    @"C:\GoogleDrive\AI\AGENTS\Maxscript\Codebase\Tools\SELECTION\Select-By-Props\Select-By-Props.mcr",
    @"C:\GoogleDrive\AI\AGENTS\Maxscript\Codebase\Tools\GEOMETRY\Geometry-Diagnostics\Geometry-Diagnostics.mcr",
    @"C:\GoogleDrive\AI\AGENTS\Maxscript\Codebase\Tools\GEOMETRY\Rebuild-Mesh\Rebuild-Mesh.mcr",
    @"C:\GoogleDrive\AI\AGENTS\Maxscript\Codebase\Tools\GEOMETRY\Wall-Thickness\Wall-Thickness.mcr",
    @"C:\GoogleDrive\AI\AGENTS\Maxscript\Codebase\Tools\EPOLY\Edge Tools\Straight-Edge-Fixer\Straight-Edge-Fixer.mcr",
    @"C:\GoogleDrive\AI\AGENTS\Maxscript\Codebase\Tools\EPOLY\Face Tools\Degenerate-Face-Selector\Degenerate-Face-Selector.mcr",
    @"C:\GoogleDrive\AI\AGENTS\Maxscript\Codebase\Tools\EPOLY\Loop Tools\Loop-Cleaner\Loop-Cleaner.mcr",
    @"C:\GoogleDrive\AI\AGENTS\Maxscript\Codebase\Tools\EPOLY\Loop Tools\Missing-Loop-Rebuilder\Missing-Loop-Rebuilder.mcr",
    @"C:\GoogleDrive\AI\AGENTS\Maxscript\Codebase\Tools\EPOLY\Loop Tools\Redundant-Ring-Collapser\Redundant-Ring-Collapser.mcr",
    @"C:\GoogleDrive\AI\AGENTS\Maxscript\Codebase\Tools\EPOLY\Vertex Tools\EPoly-Weld-Test\EPoly-Weld-Test.mcr",
    @"C:\GoogleDrive\AI\AGENTS\Maxscript\Codebase\Tools\EPOLY\Vertex Tools\Vertex-Cleaner\Vertex-Cleaner.mcr",
    @"C:\GoogleDrive\AI\AGENTS\Maxscript\Codebase\Tools\EPOLY\Vertex Tools\Vertex-Welder\Vertex-Welder.mcr",
    @"C:\GoogleDrive\AI\AGENTS\Maxscript\Codebase\Tools\SCENE\Gif-Recorder\Gif-Recorder.mcr",
    @"C:\GoogleDrive\AI\AGENTS\Maxscript\Codebase\Tools\SCENE\Scene-Model-Manager\Scene-Model-Manager.mcr",
    @"C:\GoogleDrive\AI\AGENTS\Maxscript\Codebase\Tools\SCENE\Scene-Offset-Tool\Scene-Offset-Tool.mcr",
    @"C:\GoogleDrive\AI\AGENTS\Maxscript\Codebase\Tools\MATERIALS\Material-ID-Manager\Material-ID-Manager.mcr",
    @"C:\GoogleDrive\AI\AGENTS\Maxscript\Codebase\Tools\DUMP\DUMP.mcr"
)

for macro_file_path in vilbur_tools_macro_files do
(
    if (doesFileExist macro_file_path) then
    (
        fileIn macro_file_path
    )
    else
    (
        format "VILBUR TOOLS: Missing MacroScript: %\n" macro_file_path
    )
)

if (cui.showToolbar "Vilbur SCRIPT-MANAGER") == false then
(
    format "VILBUR TOOLS: Toolbar is not present in the active CUIX.\n"
)
