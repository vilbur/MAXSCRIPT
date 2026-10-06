/*
Tests the current Functions -> Operations -> Tools -> Toolsets package architecture.
Version 0.03.
*/


global architecture_test_version = "0.03"
global architecture_test_source = getSourceFileName()


/*
Returns the folder containing this architecture test.
The test must be executed from a saved .ms file.
*/
function getArchitectureTestDirectory =
(
    if architecture_test_source == undefined or architecture_test_source == "" then
    (
        throw "Architecture test must be executed from a saved .ms file."
    )


    getFilenamePath architecture_test_source -- return
)


/*
Builds one path relative to the Architecture folder.
*/
function getArchitecturePath relative_path =
(
    getArchitectureTestDirectory() + "..\\" + relative_path -- return
)


/*
Loads one required architecture file.
*/
function loadArchitectureTestFile relative_path =
(
    local full_path = getArchitecturePath relative_path


    if not doesFileExist full_path then
    (
        throw ("Missing architecture test file: " + full_path)
    )


    fileIn full_path
    true -- return
)


/*
Requires one test condition to be true.
*/
function requireArchitectureTest condition message =
(
    if not condition then
    (
        throw ("Architecture test failed: " + message)
    )


    true -- return
)


/*
Loads Functions, Operations, Tool FN/UI, and Toolset FN/UI.
*/
function partOfTest1 =
(
    loadArchitectureTestFile "Functions\\Functions_Example\\Functions_Example_0.02.ms"
    loadArchitectureTestFile "Operations\\Operations_Example\\Operations_Example_0.02.ms"
    loadArchitectureTestFile "Tools\\Tool_Example\\Tool_Example-FN.ms"
    loadArchitectureTestFile "Tools\\Tool_Example\\Tool_Example-UI.ms"
    loadArchitectureTestFile "Toolsets\\Toolset_Example\\Toolset_Example-FN.ms"
    loadArchitectureTestFile "Toolsets\\Toolset_Example\\Toolset_Example-UI.ms"


    format "partOfTest1 PASS - package dependencies loaded.\n"
    true -- return
)


/*
Verifies that Tool and Toolset main entry files exist.
*/
function partOfTest2 =
(
    requireArchitectureTest (doesFileExist (getArchitecturePath "Tools\\Tool_Example\\Tool_Example.ms")) "Tool main file is missing."
    requireArchitectureTest (doesFileExist (getArchitecturePath "Toolsets\\Toolset_Example\\Toolset_Example.ms")) "Toolset main file is missing."


    format "partOfTest2 PASS - main entry files exist.\n"
    true -- return
)


/*
Tests the Tool backend through the Operation layer.
*/
function partOfTest3 =
(
    local tool_result = runToolExample 25.0 0.0 10.0


    requireArchitectureTest tool_result[1] "Tool backend reported failure."
    requireArchitectureTest (tool_result[2] == 10.0) "Tool backend returned an unexpected value."


    format "partOfTest3 PASS - Tool backend result: %\n" tool_result[2]
    true -- return
)


/*
Tests Toolset backend membership and readiness.
*/
function partOfTest4 =
(
    local tool_names = ToolsetExample.getToolNames()


    requireArchitectureTest ToolsetExample.isReady() "Toolset backend is not ready."
    requireArchitectureTest ((findItem tool_names "Tool_Example") > 0) "Toolset does not list Tool_Example."


    format "partOfTest4 PASS - Toolset backend is ready.\n"
    true -- return
)


/*
Opens the Toolset frontend for visual inspection.
*/
function partOfTest5 =
(
    local opened = openToolsetExampleUi()


    requireArchitectureTest opened "Toolset frontend could not open."


    format "partOfTest5 PASS - Toolset frontend opened.\n"
    true -- return
)


partOfTest1()
partOfTest2()
partOfTest3()
partOfTest4()
partOfTest5()


format "Architecture test 0.03 finished.\n"
format "Undo order: none. This test changes UI state only and does not modify scene geometry.\n"