/*
GIF Recorder core 0.001.
Camera preset, viewport capture, frame timing manifest, and FFmpeg GIF assembly.
*/

global gif_recorder_project_version
global gif_recorder_project_version_text

if gif_recorder_project_version == undefined then
(
    gif_recorder_project_version = 0.001
    gif_recorder_project_version_text = "0.001"
)
else if gif_recorder_project_version < 0.001 then
(
    gif_recorder_project_version = 0.001
    gif_recorder_project_version_text = "0.001"
)
else if gif_recorder_project_version_text == undefined then
(
    gif_recorder_project_version_text = "0.001"
)

struct GifRecorderFrame_v
(
    file_name = "",
    delay_seconds = 0.50,

    on create do
    (
    )
)

struct GifRecorderCameraPreset_v
(
    transform_value = matrix3 1,
    fov_value = 45.0,
    target_distance = 160.0,
    perspective_state = true,

    on create do
    (
    )
)

struct GifRecorderCore_v
(
    file_version = "0.001",
    stored_project_version = "0.001",
    project_root_path = "",
    settings_file_path = "",
    camera_name = "GIF_RECORDER_CAMERA",
    camera_preset_section = "CameraPreset",
    manifest_file_name = "frames.txt",
    ffconcat_file_name = "frames.ffconcat",
    ffmpeg_download_url = "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip",
    last_error = "",

    /*
    Stores project paths used by the core.
    */
    function configure project_root settings_file =
    (
        project_root_path = project_root
        settings_file_path = settings_file
        clearError()
        true
    ),

    /*
    Clears the last operation error.
    */
    function clearError =
    (
        last_error = ""
        true
    ),

    /*
    Stores and reports an operation error.
    */
    function setError message_text =
    (
        last_error = message_text
        format "GIF Recorder ERROR: %\n" message_text
        false
    ),

    /*
    Returns the fixed supported frame delays in seconds.
    */
    function getDelayValues =
    (
        #(0.25, 0.50, 0.75, 1.00, 1.25, 1.50, 1.75, 2.00, 2.25, 2.50, 2.75, 3.00)
    ),

    /*
    Returns display labels for the fixed frame delays.
    */
    function getDelayLabels =
    (
        #("0.25", "0.50", "0.75", "1.00", "1.25", "1.50", "1.75", "2.00", "2.25", "2.50", "2.75", "3.00")
    ),

    /*
    Returns a supported delay or the explicit default delay.
    */
    function normalizeDelay delay_value default_delay:0.50 =
    (
        delay_values = getDelayValues()
        normalized_delay = default_delay

        if (findItem delay_values delay_value) > 0 then
        (
            normalized_delay = delay_value
        )

        normalized_delay
    ),

    /*
    Creates a directory when it does not already exist.
    */
    function ensureDirectory directory_path =
    (
        directory_ready = false

        if directory_path != undefined and directory_path != "" then
        (
            if doesDirectoryExist directory_path then
            (
                directory_ready = true
            )
            else
            (
                directory_ready = makeDir directory_path all:true
            )
        )

        directory_ready
    ),

    /*
    Returns true when the current 3ds Max scene has a saved file path.
    */
    function isSceneSaved =
    (
        maxFileName != undefined and maxFileName != "" and maxFilePath != undefined and maxFilePath != ""
    ),

    /*
    Returns the scene-relative GIF Recorder capture directory.
    */
    function getSceneCaptureDirectory =
    (
        capture_directory = undefined

        if isSceneSaved() then
        (
            scene_base_name = getFilenameFile maxFileName
            capture_directory = maxFilePath + "Gif-Recorder\\" + scene_base_name + "\\"
        )

        capture_directory
    ),

    /*
    Returns and creates the scene-relative capture directory.
    */
    function ensureSceneCaptureDirectory =
    (
        clearError()
        capture_directory = getSceneCaptureDirectory()

        if capture_directory == undefined then
        (
            setError "Save the .max scene before capturing frames."
            undefined
        )
        else if not ensureDirectory capture_directory then
        (
            setError ("Cannot create capture directory: " + capture_directory)
            undefined
        )
        else
        (
            capture_directory
        )
    ),

    /*
    Returns the manifest path for a capture directory.
    */
    function getManifestPath capture_directory =
    (
        capture_directory + manifest_file_name
    ),

    /*
    Returns the FFconcat path for a capture directory.
    */
    function getConcatPath capture_directory =
    (
        capture_directory + ffconcat_file_name
    ),

    /*
    Returns the bundled FFmpeg executable path.
    */
    function getFfmpegPath =
    (
        project_root_path + "lib\\ffmpeg.exe"
    ),

    /*
    Returns the output GIF path for the current scene.
    */
    function getGifOutputPath capture_directory =
    (
        scene_base_name = if isSceneSaved() then getFilenameFile maxFileName else "Gif-Recorder"
        capture_directory + scene_base_name + ".gif"
    ),

    /*
    Returns the named GIF Recorder camera when it exists in the scene.
    */
    function findCamera =
    (
        camera_node = getNodeByName camera_name exact:true ignoreCase:false

        if camera_node != undefined and not isValidNode camera_node then camera_node = undefined
        if camera_node != undefined and superClassOf camera_node != Camera then camera_node = undefined

        camera_node
    ),

    /*
    Returns the GIF Recorder camera, creating a free camera when needed.
    */
    function ensureCamera =
    (
        camera_node = findCamera()

        if camera_node == undefined then
        (
            camera_node = freeCamera()
            camera_node.name = camera_name
            camera_node.baseObject.targetDistance = 160.0
        )

        camera_node
    ),

    /*
    Converts a numeric value to a high-precision INI string.
    */
    function numberToSettingString numeric_value =
    (
        formattedPrint numeric_value format:"19.17g"
    ),

    /*
    Writes one numeric camera preset setting.
    */
    function setPresetNumber key_name numeric_value =
    (
        if settings_file_path == "" then
        (
            false
        )
        else
        (
            setINISetting settings_file_path camera_preset_section key_name (numberToSettingString numeric_value)
            true
        )
    ),

    /*
    Reads one numeric camera preset setting and returns undefined on invalid data.
    */
    function getPresetNumber key_name =
    (
        setting_text = getINISetting settings_file_path camera_preset_section key_name
        numeric_value = undefined

        if setting_text != "" then
        (
            try
            (
                numeric_value = setting_text as float
            )
            catch
            (
                exception_text = getCurrentException()
                format "GIF Recorder preset parse error for %: %\n" key_name exception_text
                numeric_value = undefined
            )
        )

        numeric_value
    ),

    /*
    Saves the current GIF Recorder camera as the cross-scene camera preset.
    */
    function saveCameraPreset camera_node perspective_state =
    (
        clearError()
        preset_saved = false

        if camera_node == undefined or not isValidNode camera_node then
        (
            setError "Cannot save camera preset because the GIF Recorder camera is missing."
        )
        else if settings_file_path == "" then
        (
            setError "Cannot save camera preset because the settings file path is not configured."
        )
        else
        (
            camera_tm = camera_node.transform
            target_distance_value = camera_node.baseObject.targetDistance

            setPresetNumber "M11" camera_tm.row1.x
            setPresetNumber "M12" camera_tm.row1.y
            setPresetNumber "M13" camera_tm.row1.z
            setPresetNumber "M21" camera_tm.row2.x
            setPresetNumber "M22" camera_tm.row2.y
            setPresetNumber "M23" camera_tm.row2.z
            setPresetNumber "M31" camera_tm.row3.x
            setPresetNumber "M32" camera_tm.row3.y
            setPresetNumber "M33" camera_tm.row3.z
            setPresetNumber "M41" camera_tm.row4.x
            setPresetNumber "M42" camera_tm.row4.y
            setPresetNumber "M43" camera_tm.row4.z
            setPresetNumber "FOV" camera_node.fov
            setPresetNumber "TargetDistance" target_distance_value
            setINISetting settings_file_path camera_preset_section "Perspective" (if perspective_state then "true" else "false")
            setINISetting settings_file_path camera_preset_section "Valid" "true"
            preset_saved = true
        )

        preset_saved
    ),

    /*
    Loads the cross-scene camera preset when every required value is valid.
    */
    function loadCameraPreset =
    (
        clearError()
        preset_record = undefined

        if settings_file_path == "" then
        (
            setError "Cannot load camera preset because the settings file path is not configured."
        )
        else if toLower (getINISetting settings_file_path camera_preset_section "Valid") != "true" then
        (
            setError "No stored GIF Recorder camera preset exists yet."
        )
        else
        (
            preset_numbers = #(
                getPresetNumber "M11", getPresetNumber "M12", getPresetNumber "M13",
                getPresetNumber "M21", getPresetNumber "M22", getPresetNumber "M23",
                getPresetNumber "M31", getPresetNumber "M32", getPresetNumber "M33",
                getPresetNumber "M41", getPresetNumber "M42", getPresetNumber "M43",
                getPresetNumber "FOV", getPresetNumber "TargetDistance"
            )
            preset_valid = true

            for numeric_value in preset_numbers while preset_valid do
            (
                if numeric_value == undefined then preset_valid = false
            )

            if not preset_valid then
            (
                setError "The stored camera preset is incomplete or invalid."
            )
            else
            (
                perspective_text = toLower (getINISetting settings_file_path camera_preset_section "Perspective")
                perspective_state = perspective_text != "false"
                preset_tm = matrix3 \
                    [preset_numbers[1], preset_numbers[2], preset_numbers[3]] \
                    [preset_numbers[4], preset_numbers[5], preset_numbers[6]] \
                    [preset_numbers[7], preset_numbers[8], preset_numbers[9]] \
                    [preset_numbers[10], preset_numbers[11], preset_numbers[12]]

                preset_record = GifRecorderCameraPreset_v \
                    transform_value:preset_tm \
                    fov_value:preset_numbers[13] \
                    target_distance:preset_numbers[14] \
                    perspective_state:perspective_state
            )
        )

        preset_record
    ),

    /*
    Stores the active Perspective or Camera view into the GIF Recorder camera.
    */
    function storeCurrentView perspective_state =
    (
        clearError()
        stored = false
        view_type = viewport.getType()
        source_camera_node = undefined
        source_tm = undefined
        source_fov = undefined
        source_target_distance = undefined

        if view_type == #view_camera then
        (
            source_camera_node = viewport.getCamera()

            if source_camera_node != undefined and isValidNode source_camera_node then
            (
                source_tm = source_camera_node.transform
                source_fov = source_camera_node.fov

                if source_camera_node.target != undefined then
                (
                    source_target_distance = source_camera_node.targetDistance
                )
                else
                (
                    source_target_distance = source_camera_node.baseObject.targetDistance
                )
            )
        )
        else if view_type == #view_persp_user then
        (
            source_tm = inverse (getViewTM())
            source_fov = getViewFOV()
            source_target_distance = viewport.getFocalDistance()
        )

        if source_tm == undefined or source_fov == undefined or source_target_distance == undefined then
        (
            setError "Use a Perspective or Camera viewport, then press SET FROM VIEW."
        )
        else
        (
            camera_node = ensureCamera()
            camera_node.transform = source_tm
            camera_node.fov = source_fov
            camera_node.baseObject.targetDistance = source_target_distance
            camera_node.orthoProjection = not perspective_state
            viewport.setCamera camera_node
            redrawViews()
            stored = saveCameraPreset camera_node perspective_state
        )

        stored
    ),

    /*
    Applies the stored camera preset and activates the GIF Recorder camera.
    */
    function applyCameraPreset perspective_override:undefined =
    (
        preset_record = loadCameraPreset()
        applied = false

        if preset_record != undefined then
        (
            camera_node = ensureCamera()
            perspective_state = if perspective_override == undefined then preset_record.perspective_state else perspective_override

            camera_node.transform = preset_record.transform_value
            camera_node.fov = preset_record.fov_value
            camera_node.baseObject.targetDistance = preset_record.target_distance
            camera_node.orthoProjection = not perspective_state
            viewport.setCamera camera_node
            redrawViews()
            applied = saveCameraPreset camera_node perspective_state
        )

        applied
    ),

    /*
    Changes Perspective versus orthographic projection for the GIF Recorder camera or stored preset.
    */
    function setCameraPerspective perspective_state =
    (
        clearError()
        camera_node = findCamera()

        if camera_node != undefined then
        (
            camera_node.orthoProjection = not perspective_state
            saveCameraPreset camera_node perspective_state
            redrawViews()
        )
        else if settings_file_path != "" and toLower (getINISetting settings_file_path camera_preset_section "Valid") == "true" then
        (
            setINISetting settings_file_path camera_preset_section "Perspective" (if perspective_state then "true" else "false")
        )

        true
    ),

    /*
    Makes the GIF Recorder camera active and ready for a frame capture.
    */
    function prepareCameraForCapture perspective_state =
    (
        clearError()
        camera_node = findCamera()
        prepared_camera = undefined

        if camera_node == undefined then
        (
            if applyCameraPreset perspective_override:perspective_state then
            (
                prepared_camera = findCamera()
            )
        )
        else
        (
            camera_node.orthoProjection = not perspective_state
            viewport.setCamera camera_node
            redrawViews()

            if saveCameraPreset camera_node perspective_state then
            (
                prepared_camera = camera_node
            )
        )

        if prepared_camera == undefined and last_error == "" then
        (
            setError "No GIF Recorder camera exists. Press SET FROM VIEW first."
        )

        prepared_camera
    ),

    /*
    Parses one delay value and returns undefined when text is invalid.
    */
    function parseDelay delay_text =
    (
        parsed_delay = undefined

        try
        (
            parsed_delay = delay_text as float
        )
        catch
        (
            exception_text = getCurrentException()
            format "GIF Recorder delay parse error: %\n" exception_text
            parsed_delay = undefined
        )

        parsed_delay
    ),

    /*
    Returns true when a frame record array already contains a filename.
    */
    function hasFrameName frame_records file_name =
    (
        name_found = false
        search_name = toLower file_name

        for frame_record in frame_records while not name_found do
        (
            if toLower frame_record.file_name == search_name then name_found = true
        )

        name_found
    ),

    /*
    Saves ordered frame filenames and per-frame delays to the scene manifest.
    */
    function saveFrameRecords capture_directory frame_records =
    (
        clearError()
        manifest_path = getManifestPath capture_directory
        manifest_stream = createFile manifest_path
        saved = false

        if manifest_stream == undefined then
        (
            setError ("Cannot write frame manifest: " + manifest_path)
        )
        else
        (
            for frame_record in frame_records do
            (
                format "%|%\n" frame_record.file_name (numberToSettingString frame_record.delay_seconds) to:manifest_stream
            )

            close manifest_stream
            saved = true
        )

        saved
    ),

    /*
    Loads ordered frame records and appends PNG files not yet listed in the manifest.
    */
    function loadFrameRecords capture_directory default_delay:0.50 =
    (
        clearError()
        frame_records = #()
        manifest_path = getManifestPath capture_directory
        normalized_default = normalizeDelay default_delay default_delay:0.50

        if doesFileExist manifest_path then
        (
            manifest_stream = openFile manifest_path mode:"rt"

            if manifest_stream == undefined then
            (
                setError ("Cannot read frame manifest: " + manifest_path)
            )
            else
            (
                while not eof manifest_stream do
                (
                    manifest_line = readLine manifest_stream

                    if manifest_line != undefined and manifest_line != "" then
                    (
                        line_parts = filterString manifest_line "|"

                        if line_parts.count >= 2 then
                        (
                            frame_file_name = line_parts[1]
                            parsed_delay = parseDelay line_parts[2]
                            frame_path = capture_directory + frame_file_name

                            if parsed_delay != undefined and doesFileExist frame_path then
                            (
                                append frame_records (GifRecorderFrame_v file_name:frame_file_name delay_seconds:(normalizeDelay parsed_delay default_delay:normalized_default))
                            )
                        )
                    )
                )

                close manifest_stream
            )
        )

        if last_error == "" then
        (
            png_files = getFiles (capture_directory + "*.png")
            sort png_files

            for png_path in png_files do
            (
                png_name = filenameFromPath png_path

                if not hasFrameName frame_records png_name then
                (
                    append frame_records (GifRecorderFrame_v file_name:png_name delay_seconds:normalized_default)
                )
            )

            saveFrameRecords capture_directory frame_records
        )

        frame_records
    ),

    /*
    Returns the next unused generated frame path.
    */
    function getNextFramePath capture_directory =
    (
        frame_files = getFiles (capture_directory + "frame_*.png")
        highest_index = 0

        for frame_path in frame_files do
        (
            frame_base_name = getFilenameFile frame_path

            if frame_base_name.count > 6 then
            (
                index_text = substring frame_base_name 7 (frame_base_name.count - 6)
                parsed_index = undefined

                try
                (
                    parsed_index = index_text as integer
                )
                catch
                (
                    parsed_index = undefined
                )

                if parsed_index != undefined and parsed_index > highest_index then highest_index = parsed_index
            )
        )

        next_index = highest_index + 1
        capture_directory + "frame_" + (formattedPrint next_index format:"04d") + ".png"
    ),

    /*
    Returns the horizontal FOV needed before cropping a wide viewport to the target aspect.
    */
    function getCaptureFov source_fov viewport_aspect target_aspect =
    (
        capture_fov = source_fov

        if viewport_aspect > target_aspect then
        (
            target_vertical_fov = 2.0 * atan ((tan (source_fov / 2.0)) / target_aspect)
            capture_fov = 2.0 * atan ((tan (target_vertical_fov / 2.0)) * viewport_aspect)
        )

        capture_fov
    ),

    /*
    Rounds an image-space coordinate to the nearest whole pixel by explicit contract.
    */
    function roundPixel pixel_value =
    (
        floor (pixel_value + 0.5)
    ),

    /*
    Crops a viewport bitmap to the target aspect and rescales it to exact output dimensions.
    */
    function saveCroppedBitmap source_bitmap output_path output_width output_height =
    (
        clearError()
        saved = false
        source_width = source_bitmap.width
        source_height = source_bitmap.height
        crop_width = source_width
        crop_height = source_height
        crop_x = 0
        crop_y = 0

        if (source_width * output_height) > (source_height * output_width) then
        (
            crop_width = roundPixel ((source_height as float) * (output_width as float) / (output_height as float))
            crop_x = floor (((source_width - crop_width) as float) / 2.0)
        )
        else if (source_width * output_height) < (source_height * output_width) then
        (
            crop_height = roundPixel ((source_width as float) * (output_height as float) / (output_width as float))
            crop_y = floor (((source_height - crop_height) as float) / 2.0)
        )

        cropped_bitmap = bitmap crop_width crop_height
        output_bitmap = bitmap output_width output_height filename:output_path
        source_box = box2 crop_x crop_y crop_width crop_height

        pasteBitmap source_bitmap cropped_bitmap source_box [0, 0]
        copy cropped_bitmap output_bitmap
        saved = save output_bitmap quiet:true

        close cropped_bitmap
        close output_bitmap

        if not saved then setError ("Cannot save captured frame: " + output_path)
        saved
    ),

    /*
    Captures the active GIF Recorder camera into an exact-size PNG frame.
    */
    function captureFrame output_width output_height delay_seconds perspective_state =
    (
        clearError()
        captured_path = undefined
        capture_directory = undefined
        camera_node = undefined
        source_bitmap = undefined

        if output_width < 1 or output_height < 1 then
        (
            setError "Capture width and height must be greater than zero."
        )
        else
        (
            capture_directory = ensureSceneCaptureDirectory()
        )

        if capture_directory != undefined then
        (
            camera_node = prepareCameraForCapture perspective_state
        )

        if camera_node != undefined then
        (
            viewport_size = getViewSize()

            if viewport_size.x < 1 or viewport_size.y < 1 then
            (
                setError "The active viewport has an invalid size."
            )
            else
            (
                output_path = getNextFramePath capture_directory
                original_fov = camera_node.fov
                viewport_aspect = (viewport_size.x as float) / (viewport_size.y as float)
                target_aspect = (output_width as float) / (output_height as float)
                capture_fov = getCaptureFov original_fov viewport_aspect target_aspect

                camera_node.fov = capture_fov
                redrawViews()

                try
                (
                    source_bitmap = gw.getViewportDib()
                )
                catch
                (
                    exception_text = getCurrentException()
                    setError ("Viewport capture failed: " + exception_text)
                    source_bitmap = undefined
                )

                camera_node.fov = original_fov
                redrawViews()

                if source_bitmap != undefined then
                (
                    if saveCroppedBitmap source_bitmap output_path output_width output_height then
                    (
                        frame_records = loadFrameRecords capture_directory default_delay:delay_seconds
                        new_file_name = filenameFromPath output_path
                        frame_index = 0

                        for record_index = 1 to frame_records.count while frame_index == 0 do
                        (
                            if toLower frame_records[record_index].file_name == toLower new_file_name then frame_index = record_index
                        )

                        if frame_index > 0 then
                        (
                            frame_records[frame_index].delay_seconds = normalizeDelay delay_seconds default_delay:0.50
                            saveFrameRecords capture_directory frame_records
                            captured_path = output_path
                        )
                    )

                    close source_bitmap
                )
            )
        )

        captured_path
    ),

    /*
    Downloads and extracts FFmpeg into the project lib folder when it is missing.
    */
    function ensureFfmpeg =
    (
        clearError()
        ffmpeg_path = getFfmpegPath()
        ffmpeg_ready = doesFileExist ffmpeg_path

        if not ffmpeg_ready then
        (
            lib_directory = project_root_path + "lib\\"
            temp_root = (getDir #temp) + "\\GifRecorder-FFmpeg\\"
            zip_path = temp_root + "ffmpeg.zip"
            extract_directory = temp_root + "extract\\"

            if project_root_path == "" then
            (
                setError "GIF Recorder project root is not configured."
            )
            else if not ensureDirectory lib_directory then
            (
                setError ("Cannot create FFmpeg library directory: " + lib_directory)
            )
            else
            (
                directory_class = dotNetClass "System.IO.Directory"
                file_class = dotNetClass "System.IO.File"

                try
                (
                    if directory_class.Exists temp_root then directory_class.Delete temp_root true
                    directory_class.CreateDirectory temp_root
                    directory_class.CreateDirectory extract_directory

                    web_client = dotNetObject "System.Net.WebClient"
                    web_client.DownloadFile ffmpeg_download_url zip_path
                    web_client.Dispose()

                    dotNet.loadAssembly "System.IO.Compression.FileSystem"
                    zip_class = dotNetClass "System.IO.Compression.ZipFile"
                    zip_class.ExtractToDirectory zip_path extract_directory

                    search_option = (dotNetClass "System.IO.SearchOption").AllDirectories
                    ffmpeg_candidates = directory_class.GetFiles extract_directory "ffmpeg.exe" search_option

                    if ffmpeg_candidates.Length < 1 then
                    (
                        setError "FFmpeg archive was downloaded, but ffmpeg.exe was not found inside it."
                    )
                    else
                    (
                        file_class.Copy ffmpeg_candidates.GetValue(0) ffmpeg_path true
                        ffmpeg_ready = doesFileExist ffmpeg_path

                        if not ffmpeg_ready then setError "FFmpeg extraction completed, but lib\\ffmpeg.exe is still missing."
                    )

                    if directory_class.Exists temp_root then directory_class.Delete temp_root true
                )
                catch
                (
                    exception_text = getCurrentException()
                    setError ("FFmpeg setup failed: " + exception_text)

                    if directory_class.Exists temp_root then
                    (
                        try
                        (
                            directory_class.Delete temp_root true
                        )
                        catch
                        (
                            cleanup_exception = getCurrentException()
                            format "GIF Recorder FFmpeg cleanup warning: %\n" cleanup_exception
                        )
                    )
                )
            )
        )

        ffmpeg_ready
    ),

    /*
    Writes an FFconcat file preserving each frame's individual duration.
    */
    function writeConcatFile capture_directory frame_records =
    (
        clearError()
        concat_path = getConcatPath capture_directory
        concat_stream = createFile concat_path
        written = false

        if concat_stream == undefined then
        (
            setError ("Cannot write FFconcat file: " + concat_path)
        )
        else if frame_records.count < 1 then
        (
            close concat_stream
            deleteFile concat_path
            setError "There are no frames to build into a GIF."
        )
        else
        (
            format "ffconcat version 1.0\n" to:concat_stream

            for frame_record in frame_records do
            (
                format "file '%'\n" frame_record.file_name to:concat_stream
                format "duration %\n" (numberToSettingString frame_record.delay_seconds) to:concat_stream
            )

            format "file '%'\n" frame_records[frame_records.count].file_name to:concat_stream
            close concat_stream
            written = true
        )

        written
    ),

    /*
    Runs FFmpeg without opening a console window and returns its exit code.
    */
    function runFfmpeg ffmpeg_path capture_directory arguments_text =
    (
        process_exit_code = -1
        process_info = dotNetObject "System.Diagnostics.ProcessStartInfo"
        ffmpeg_process = dotNetObject "System.Diagnostics.Process"

        process_info.FileName = ffmpeg_path
        process_info.Arguments = arguments_text
        process_info.WorkingDirectory = capture_directory
        process_info.UseShellExecute = false
        process_info.CreateNoWindow = true
        process_info.RedirectStandardError = true
        ffmpeg_process.StartInfo = process_info

        try
        (
            process_started = ffmpeg_process.Start()

            if process_started then
            (
                error_text = ffmpeg_process.StandardError.ReadToEnd()
                ffmpeg_process.WaitForExit()
                process_exit_code = ffmpeg_process.ExitCode

                if process_exit_code != 0 then
                (
                    setError ("FFmpeg failed with exit code " + (process_exit_code as string) + ": " + error_text)
                )
            )
            else
            (
                setError "FFmpeg process could not be started."
            )
        )
        catch
        (
            exception_text = getCurrentException()
            setError ("FFmpeg process failed: " + exception_text)
        )

        ffmpeg_process.Dispose()
        process_exit_code
    ),

    /*
    Builds an animated GIF from the ordered frame records and current output size.
    */
    function buildGif frame_records output_width output_height =
    (
        clearError()
        output_path = undefined
        capture_directory = ensureSceneCaptureDirectory()

        if capture_directory != undefined and frame_records.count < 1 then
        (
            setError "There are no frames to build into a GIF."
        )

        if last_error == "" and not writeConcatFile capture_directory frame_records then
        (
            output_path = undefined
        )
        else if last_error == "" and ensureFfmpeg() then
        (
            ffmpeg_path = getFfmpegPath()
            gif_path = getGifOutputPath capture_directory
            scale_filter = "scale=" + (output_width as string) + ":" + (output_height as string) + ":flags=lanczos"
            filter_text = scale_filter + ",split[s0][s1];[s0]palettegen=stats_mode=diff[p];[s1][p]paletteuse=dither=sierra2_4a"
            arguments_text = "-hide_banner -loglevel error -y -f concat -safe 0 -i \"" + ffconcat_file_name + "\" -fps_mode vfr -filter_complex \"" + filter_text + "\" -loop 0 \"" + gif_path + "\""
            process_exit_code = runFfmpeg ffmpeg_path capture_directory arguments_text

            if process_exit_code == 0 and doesFileExist gif_path then
            (
                output_path = gif_path
            )
            else if last_error == "" then
            (
                setError "FFmpeg finished without creating the expected GIF file."
            )
        )

        output_path
    ),

    on create do
    (
    )
)

global GifRecorderCore
GifRecorderCore = GifRecorderCore_v()
