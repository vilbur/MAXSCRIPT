/*
Tests the Functions -> Operations -> Tools -> Toolsets architecture.
Version 0.01.
*/


global architecture_test_version = "0.01"
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
Loads one architecture layer file by path relative to the Architecture folder.
Fails immediately when the required file is missing.
*/
function loadArchitectureTestFile relative_path =
(
    local full_path = getArchitectureTestDirectory() + relative_path


    if not doesFileExist full_path then
    (
        throw ("Missing architecture test file: " + full_path)
    )


    fileIn full_path
    true -- return
)


/*
Requires one test condition to be true.
Throws the supplied message when the condition fails.
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
Loads all four architecture layers in dependency order.
*/
function partOfTest1 =
(
    loadArchitectureTestFile "Functions\\Functions-Template_0.01.ms"
    loadArchitectureTestFile "Operations\\Operations-Template_0.01.ms"
    loadArchitectureTestFile "Tools\\Tool-Template_0.01.ms"
    loadArchitectureTestFile "Toolsets\\Toolset-Template_0.01.ms"


    format "partOfTest1 PASS - all architecture files loaded.\n"
    true -- return
)


/*
Tests the atomic Function layer directly.
*/
function partOfTest2 =
(
    local result_value = clampTemplateValue 25.0 0.0 10.0


    requireArchitectureTest (result_value == 10.0) "Function layer returned an unexpected value."


    format "partOfTest2 PASS - Function result: %\n" result_value
    true -- return
)


/*
Tests the Operation layer and its Function dependency.
*/
function partOfTest3 =
(
    local operation_result = prepareTemplateValue 25.0 0.0 10.0


    requireArchitectureTest operation_result[1] "Operation reported failure."
    requireArchitectureTest (operation_result[2] == 10.0) "Operation returned an unexpected value."


    format "partOfTest3 PASS - Operation result: %\n" operation_result[2]
    true -- return
)


/*
Opens the Toolset so the Tool rollout can be inspected manually.
*/
function partOfTest4 =
(
    local opened = ToolsetTemplate.openToolset width:320 height:220


    requireArchitectureTest opened "Toolset could not open the Tool rollout."


    format "partOfTest4 PASS - Toolset dialog opened.\n"
    true -- return
)


partOfTest1()
partOfTest2()
partOfTest3()
partOfTest4()


format "Architecture test 0.01 finished.\n"
format "Undo order: none. This test changes UI state only and does not modify scene geometry.\n"