/*
Layers Sorter Test 0.01
Reloads the canonical tool twice to exercise dialog teardown, dynamic rollout rebuild, and current UI startup.
*/

global layers_sorter_test_source = getSourceFileName()

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
Loads the canonical Layers Sorter source from the same directory.
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
Loads the current tool once and verifies the standalone dialog is alive.
*/
function partOfTest1 =
(
    loadLayersSorterTestTool()

    requireLayersSorterTest (::asc_main_rollout != undefined) "Main rollout was not defined."
    requireLayersSorterTest (try(asc_main_rollout.inDialog)catch(false)) "Main rollout is not in a CreateDialog window."
    requireLayersSorterTest (try(asc_main_rollout.hwnd != 0)catch(false)) "Main rollout has no live HWND."
    requireLayersSorterTest (layers_sorter_file_version >= 0.02) "Expected file version 0.02 or newer."

    true
    -- return
)

/*
Reloads the current tool while its dialog is open.
The test passes only if the previous dialog can be replaced without a MAXScript error or hard crash.
*/
function partOfTest2 =
(
    loadLayersSorterTestTool()

    requireLayersSorterTest (try(asc_main_rollout.inDialog)catch(false)) "Reloaded rollout is not in a CreateDialog window."
    requireLayersSorterTest (try(asc_main_rollout.hwnd != 0)catch(false)) "Reloaded rollout has no live HWND."

    true
    -- return
)

/*
Verifies that the crash-hardening source no longer uses Windows Forms buttons.
*/
function partOfTest3 =
(
    local tool_path = getLayersSorterTestDirectory() + "Layers-Sorter.ms"
    local file_stream = openFile tool_path mode:"rt"
    local source_text = ""
    local test_ok = true

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

    if (findString source_text "System.Windows.Forms") != undefined then test_ok = false
    if (findString source_text "dotNetControl") != undefined then test_ok = false
    if (findString source_text "ascCloseExistingToolDialog") == undefined then test_ok = false
    if (findString source_text "existing_dialog.hwnd") == undefined then test_ok = false

    requireLayersSorterTest test_ok "Crash-hardening source checks failed."

    true
    -- return
)

partOfTest1()
partOfTest2()
partOfTest3()

format "\nLAYERS SORTER TEST PASSED\n"
format "Dialog reload completed twice without a MAXScript error.\n"
