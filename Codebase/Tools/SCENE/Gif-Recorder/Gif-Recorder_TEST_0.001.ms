/*
GIF Recorder test 0.001.
Runs focused camera, timing, and optional capture checks against the current 3ds Max scene.
*/

(
    global gif_recorder_project_version
    global gif_recorder_project_version_text

    test_file_version = "0.001"
    stored_project_version = 0.001
    stored_project_version_text = "0.001"
    test_source_file = getSourceFileName()

    if test_source_file == undefined or test_source_file == "" then
    (
        throw "GIF Recorder test must be run from a saved .ms file."
    )

    test_directory = getFilenamePath test_source_file
    core_path = test_directory + "Gif-Recorder-Core_0.001.ms"

    if not doesFileExist core_path then
    (
        throw ("Missing GIF Recorder test dependency: " + core_path)
    )

    fileIn core_path

    if gif_recorder_project_version == undefined then
    (
        gif_recorder_project_version = stored_project_version
        gif_recorder_project_version_text = stored_project_version_text
    )
    else if gif_recorder_project_version < stored_project_version then
    (
        gif_recorder_project_version = stored_project_version
        gif_recorder_project_version_text = stored_project_version_text
    )
    else if gif_recorder_project_version_text == undefined then
    (
        gif_recorder_project_version_text = stored_project_version_text
    )

    test_settings_path = (getDir #temp) + "\\Gif-Recorder-TEST.ini"
    GifRecorderCore.configure test_directory test_settings_path

    /*
    Fails the test immediately when one expected condition is false.
    */
    function testCheck condition_value message_text =
    (
        if not condition_value then
        (
            throw ("GIF Recorder TEST FAILED: " + message_text)
        )

        format "PASS: %\n" message_text
        true
    )

    /*
    Creates a visible scene object and establishes a Perspective viewport for the test.
    */
    function partOfTest1 =
    (
        undo "GIF Recorder Test 1 - Scene" on
        (
            test_node = getNodeByName "GIF_RECORDER_TEST_BOX" exact:true ignoreCase:false

            if test_node == undefined then
            (
                test_node = Box name:"GIF_RECORDER_TEST_BOX" length:100 width:100 height:100 pos:[0,0,0]
            )

            select test_node
            viewport.setType #view_persp_user
        )

        testCheck ((viewport.getType()) == #view_persp_user) "Perspective viewport is active."
        true
    )

    /*
    Stores the current view and verifies that the dedicated GIF Recorder camera exists.
    */
    function partOfTest2 =
    (
        stored = false

        undo "GIF Recorder Test 2 - Camera" on
        (
            stored = GifRecorderCore.storeCurrentView true
        )

        testCheck stored "Current Perspective view stores successfully."
        camera_node = GifRecorderCore.findCamera()
        testCheck (camera_node != undefined and isValidNode camera_node) "GIF Recorder camera exists."
        testCheck (camera_node.orthoProjection == false) "Perspective checkbox semantics map to camera perspective projection."
        true
    )

    /*
    Verifies the orthographic switch and the complete fixed delay table.
    */
    function partOfTest3 =
    (
        undo "GIF Recorder Test 3 - Projection" on
        (
            GifRecorderCore.setCameraPerspective false
        )

        camera_node = GifRecorderCore.findCamera()
        testCheck (camera_node.orthoProjection == true) "Perspective OFF maps to orthographic camera projection."

        undo "GIF Recorder Test 3 - Restore Projection" on
        (
            GifRecorderCore.setCameraPerspective true
        )

        delay_values = GifRecorderCore.getDelayValues()
        testCheck (delay_values.count == 12) "Delay dropdown contains 12 quarter-second values."
        testCheck (delay_values[1] == 0.25) "Delay range starts at 0.25 seconds."
        testCheck (delay_values[12] == 3.00) "Delay range ends at 3.00 seconds."
        true
    )

    /*
    Captures one 320x180 frame when the current test scene is already saved.
    */
    function partOfTest4 =
    (
        if GifRecorderCore.isSceneSaved() then
        (
            captured_path = GifRecorderCore.captureFrame 320 180 0.50 true
            testCheck (captured_path != undefined) "Saved-scene viewport capture returns a frame path."
            testCheck (doesFileExist captured_path) "Captured PNG exists on disk."
            format "Capture test frame: %\n" captured_path
        )
        else
        (
            format "SKIP: Capture test requires the current .max scene to be saved first.\n"
        )

        true
    )

    partOfTest1()
    partOfTest2()
    partOfTest3()
    partOfTest4()

    format "GIF Recorder test finished.\n"
    format "Undo order from newest to oldest:\n"
    format "1. GIF Recorder Test 3 - Restore Projection\n"
    format "2. GIF Recorder Test 3 - Projection\n"
    format "3. GIF Recorder Test 2 - Camera\n"
    format "4. GIF Recorder Test 1 - Scene\n"
)
