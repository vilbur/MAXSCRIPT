/*
Layers Sorter Test 0.03
Performs source-level crash-safety checks, then loads the canonical tool once for a safe smoke test.
*/

global layers_sorter_test_source = getSourceFileName()
global layers_sorter_test_file_version = 0.03
global layers_sorter_test_project_version = 0.04

/*
Returns the directory containing this test.
The test must be executed from a saved .ms file.
*/
function getLayersSorterTestDirectory =
(
    if layers_sorter_test_source == undefined or layers_sorter_test_source == "" then
    (
        throw "Layers-Sorter-Test.ms must be executed from a saved .ms file."
    )

    getFilenamePath layers_sorter_test_source
    -- return
)

/*
Returns the complete canonical Layers Sorter source as one string.
The file is read without executing it so teardown ordering can be checked safely.
*/
function getLayersSorterTestSourceText =
(
    local tool_path = getLayersSorterTestDirectory() + "Layers-Sorter.ms"
    local file_stream = openFile tool_path mode:"rt"
    local source_text = ""

    if file_stream == undefined then
    (
        throw ("Layers Sorter test: cannot open source: " + tool_path)
    )

    while not eof file_stream do
    (
        source_text += readLine file_stream
        source_text += "\n"
    )

    close file_stream

    source_text
    -- return
)

/*
Loads the canonical Layers Sorter source exactly once.
This test intentionally avoids a second immediate CUI teardown/recreation cycle.
*/
function loadLayersSorterTestTool =
(
    local tool_path = getLayersSorterTestDirectory() + "Layers-Sorter.ms"

    if not doesFileExist tool_path then
    (
        throw ("Layers Sorter test: missing canonical tool: " + tool_path)
    )

    fileIn tool_path quiet:true
    true
    -- return
)

/*
Requires one condition to be true.
*/
function requireLayersSorterTest condition message =
(
    if not condition then
    (
        throw ("Layers Sorter test failed: " + message)
    )

    true
    -- return
)

/*
Verifies that reload cleanup executes before the main rollout is redefined.
The old hierarchy must be detached while the old parent is still alive.
*/
function partOfTest1 =
(
    local source_text = getLayersSorterTestSourceText()
    local cleanup_call_index = findString source_text "ascClosePreviousLayersSorterDialog()"
    local rollout_index = findString source_text "rollout asc_main_rollout"

    requireLayersSorterTest (cleanup_call_index != undefined) "Early dialog cleanup call is missing."
    requireLayersSorterTest (rollout_index != undefined) "Main rollout definition is missing."
    requireLayersSorterTest (cleanup_call_index < rollout_index) "Dialog cleanup must run before the rollout is redefined."
    requireLayersSorterTest ((findString source_text "existing_dialog.clearLayerHierarchy()") != undefined) "Old dynamic hierarchy is not detached before dialog teardown."
    requireLayersSorterTest ((findString source_text "cui.UnRegisterDialogBar existing_dialog") != undefined) "CUI dialog bar is not unregistered before destruction."
    requireLayersSorterTest ((findString source_text "existing_dialog.hwnd") == undefined) "Reload cleanup still probes HWND state."
    requireLayersSorterTest ((findString source_text "rollout asc_main_rollout layers_sorter_rollout_title") != undefined) "Main rollout does not use the pre-resolved versioned title."
    requireLayersSorterTest ((findString source_text "asc_main_rollout.title =") == undefined) "Unsafe rollout title mutation is present."
    requireLayersSorterTest ((findString source_text "dotNetControl btn_add_default \"System.Windows.Forms.Button\"") != undefined) "Default .NET layer button is missing."
    requireLayersSorterTest ((findString source_text "rollout_creator.addControl #dotNetControl #btn_add_selection \"System.Windows.Forms.Button\"") != undefined) "Generated branch .NET layer button is missing."
    requireLayersSorterTest ((findString source_text "System.Drawing.Font\" \"Segoe UI\" 10.0") != undefined) "Larger 10 pt layer-button font is missing."

    true
    -- return
)

/*
Verifies that the rollout close handler stays lightweight during native window destruction.
It must not recursively remove child subrollouts while the parent dialog is closing.
*/
function partOfTest2 =
(
    local source_text = getLayersSorterTestSourceText()
    local close_start = findString source_text "on asc_main_rollout close do"
    local close_end = undefined
    local close_length = 0
    local close_text = ""

    requireLayersSorterTest (close_start != undefined) "Main rollout close handler is missing."

    close_end = findString (substring source_text close_start (source_text.count - close_start + 1)) "on btn_refresh_layers pressed do"
    requireLayersSorterTest (close_end != undefined) "Could not resolve the end of the close handler."

    close_length = close_end - 1
    close_text = substring source_text close_start close_length

    requireLayersSorterTest ((findString close_text "clearLayerHierarchy()") == undefined) "Close handler still removes dynamic subrollouts during native destruction."

    true
    -- return
)

/*
Loads the canonical tool once and verifies that its current dialog starts successfully.
Repeated reload is intentionally a manual follow-up after 3ds Max has returned to its message loop.
*/
function partOfTest3 =
(
    loadLayersSorterTestTool()

    requireLayersSorterTest (::asc_main_rollout != undefined) "Main rollout was not defined."
    requireLayersSorterTest (try(asc_main_rollout.inDialog)catch(false)) "Main rollout is not in a CreateDialog window."
    requireLayersSorterTest (layers_sorter_file_version >= 0.04) "Expected file version 0.04 or newer."
    requireLayersSorterTest (try(asc_main_rollout.btn_add_default.GetType().FullName == "System.Windows.Forms.Button")catch(false)) "Default control is not a Windows Forms Button."
    requireLayersSorterTest (try(asc_main_rollout.btn_add_default.Font.Size >= 10.0)catch(false)) "Default layer button font is not enlarged."
    requireLayersSorterTest (asc_main_rollout.title == layers_sorter_rollout_title) "Rollout title does not match the pre-resolved title."

    true
    -- return
)

partOfTest1()
partOfTest2()
partOfTest3()

format "\nLAYERS SORTER TEST PASSED\n"
format "The test performs one UI load only. Run Layers-Sorter.ms again manually after this test to verify normal reload replacement.\n"
format "Undo order: none. This test does not modify scene geometry.\n"
