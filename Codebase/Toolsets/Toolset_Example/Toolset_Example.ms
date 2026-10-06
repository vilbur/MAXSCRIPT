/*
Toolset Example main entry file.
Loads Tool and Toolset dependencies, then executes the Toolset.
*/


global toolset_example_version = "0.01"
global toolset_example_source = getSourceFileName()


/*
Returns the directory containing the Toolset Example main file.
The Toolset must be executed from a saved .ms file.
*/
function getToolsetExampleDirectory =
(
    if toolset_example_source == undefined or toolset_example_source == "" then
    (
        throw "Toolset_Example.ms must be executed from a saved .ms file."
    )


    getFilenamePath toolset_example_source -- return
)


/*
Loads one Toolset Example dependency by path relative to the Toolset directory.
Fails immediately when the required file is missing.
*/
function loadToolsetExampleFile relative_path =
(
    local full_path = getToolsetExampleDirectory() + relative_path


    if not doesFileExist full_path then
    (
        throw ("Missing Toolset Example dependency: " + full_path)
    )


    fileIn full_path
    true -- return
)


/*
Loads Toolset Example dependencies in architecture order.
The Tool main file is not loaded because Toolsets embed Tool frontend and backend without opening the standalone Tool dialog.
*/
function loadToolsetExample =
(
    loadToolsetExampleFile "..\\..\\Functions\\Functions_Example\\Functions_Example_0.02.ms"
    loadToolsetExampleFile "..\\..\\Operations\\Operations_Example\\Operations_Example_0.02.ms"
    loadToolsetExampleFile "..\\..\\Tools\\Tool_Example\\Tool_Example-FN.ms"
    loadToolsetExampleFile "..\\..\\Tools\\Tool_Example\\Tool_Example-UI.ms"
    loadToolsetExampleFile "Toolset_Example-FN.ms"
    loadToolsetExampleFile "Toolset_Example-UI.ms"


    true -- return
)


/*
Executes Toolset Example.
Loads all required files and opens the Toolset dialog.
*/
function executeToolsetExample =
(
    loadToolsetExample()
    openToolsetExampleUi() -- return
)


/*
Tests the complete Toolset Example package.
Loads the package and verifies backend and frontend entry points.
*/
function testToolsetExample =
(
    local loaded = loadToolsetExample()
    local backend_ready = (::ToolsetExample != undefined)
    local frontend_ready = (::openToolsetExampleUi != undefined)
    local tool_backend_ready = (::runToolExample != undefined)
    local tool_frontend_ready = (::toolExampleRollout != undefined)
    local test_passed = loaded and backend_ready and frontend_ready and tool_backend_ready and tool_frontend_ready


    format "Toolset_Example package test: %\n" (if test_passed then "PASS" else "FAIL")


    test_passed -- return
)


executeToolsetExample()