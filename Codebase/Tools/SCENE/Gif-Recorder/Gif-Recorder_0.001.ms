/*
GIF Recorder UI 0.001.
Fixed-width workflow capture UI with preview, frame ordering, timing, and GIF build controls.
*/

(
    global gif_recorder_project_version
    global gif_recorder_project_version_text

    ui_file_version = "0.001"
    stored_project_version = 0.001
    stored_project_version_text = "0.001"
    source_file_path = getSourceFileName()

    if source_file_path == undefined or source_file_path == "" then
    (
        throw "GIF Recorder must be run from a saved .ms file."
    )

    script_directory = getFilenamePath source_file_path
    shared_ui_directory = script_directory + "..\\..\\UI\\Default\\"

    /*
    Loads one required shared UI helper.
    */
    function loadSharedUiHelper helper_name =
    (
        helper_path = shared_ui_directory + helper_name

        if not doesFileExist helper_path then
        (
            throw ("Missing shared UI helper: " + helper_path)
        )

        fileIn helper_path
        true
    )

    loadSharedUiHelper "IniSettings.ms"
    loadSharedUiHelper "RolloutState.ms"
    loadSharedUiHelper "DialogHost.ms"
    loadSharedUiHelper "ScriptReload.ms"

    core_baseline_path = script_directory + "Gif-Recorder-Core_0.001.ms"
    core_script_path = ScriptReload.findNewestVersionedScript core_baseline_path "Gif-Recorder-Core"

    if not doesFileExist core_script_path then
    (
        throw ("Missing GIF Recorder core: " + core_script_path)
    )

    fileIn core_script_path

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

    settings_file_path = (getDir #userScripts) + "\\Gif-Recorder.ini"
    ui_section_name = "MainUI"
    script_prefix = "Gif-Recorder"
    gif_recorder_title = "GIF Recorder - v" + gif_recorder_project_version_text

    GifRecorderCore.configure script_directory settings_file_path

    rollout gifRecorderRollout gif_recorder_title width:288 height:720
    (
        local frame_records = #()
        local updating_grid = false
        local preview_image = undefined

        button btn_store_view "SET FROM VIEW" pos:[12,12] width:126 height:24 tooltip:"LMB: Store the active Perspective or Camera view into the GIF Recorder camera."
        button btn_apply_preset "APPLY PRESET" pos:[150,12] width:126 height:24 tooltip:"LMB: Recreate and activate the stored GIF Recorder camera preset."
        checkbox chk_perspective "Perspective" pos:[12,48] width:126 height:24 checked:true tooltip:"ON: Use perspective projection.\n\nOFF: Use orthographic projection."
        spinner spn_width "W:" pos:[12,72] width:126 height:24 range:[1,8192,960] type:#integer fieldWidth:78 tooltip:"Output frame width in pixels."
        spinner spn_height "H:" pos:[150,72] width:126 height:24 range:[1,8192,540] type:#integer fieldWidth:78 tooltip:"Output frame height in pixels."

        dotNetControl preview_box "System.Windows.Forms.PictureBox" pos:[12,108] width:264 height:149
        dotNetControl grd_frames "System.Windows.Forms.DataGridView" pos:[12,269] width:264 height:235

        dropdownlist ddl_default_delay "" pos:[12,516] width:126 height:24 items:#("0.25", "0.50", "0.75", "1.00", "1.25", "1.50", "1.75", "2.00", "2.25", "2.50", "2.75", "3.00") selection:2 tooltip:"Default delay in seconds for new captures."
        button btn_set_delay "SET DELAY" pos:[150,516] width:126 height:24 tooltip:"LMB: Apply the selected delay to all selected frames."

        button btn_capture "CAPTURE" pos:[12,552] width:126 height:24 tooltip:"LMB: Capture the GIF Recorder camera into a new PNG frame."
        button btn_refresh "REFRESH" pos:[150,552] width:126 height:24 tooltip:"LMB: Rescan the scene capture directory for PNG frames."

        button btn_up "UP" pos:[12,588] width:84 height:24 tooltip:"LMB: Move selected frames one position earlier."
        button btn_down "DOWN" pos:[102,588] width:84 height:24 tooltip:"LMB: Move selected frames one position later."
        button btn_delete "DELETE" pos:[192,588] width:84 height:24 tooltip:"LMB: Delete selected frame images from disk and from the GIF sequence."

        button btn_build "BUILD GIF" pos:[12,624] width:264 height:24 tooltip:"LMB: Build the animated GIF.\n\nFFmpeg is downloaded automatically on first use when missing."
        label lbl_status "Ready." pos:[12,660] width:264 height:18
        button btn_restart "Restart" pos:[12,684] width:264 height:24 tooltip:"LMB: Reload the newest Gif-Recorder_*.ms version from this repository."

        /*
        Writes a short status message into the bottom status line.
        */
        function setStatus status_text =
        (
            lbl_status.text = status_text
            true
        )

        /*
        Returns the current default delay selected in the dropdown.
        */
        function getDefaultDelay =
        (
            delay_value = 0.50

            if ddl_default_delay.selection >= 1 and ddl_default_delay.selection <= ddl_default_delay.items.count then
            (
                delay_value = ddl_default_delay.items[ddl_default_delay.selection] as float
            )

            GifRecorderCore.normalizeDelay delay_value default_delay:0.50
        )

        /*
        Returns the canonical display label for one supported delay value.
        */
        function getDelayLabel delay_value =
        (
            delay_values = GifRecorderCore.getDelayValues()
            delay_labels = GifRecorderCore.getDelayLabels()
            delay_index = findItem delay_values delay_value
            delay_label = "0.50"

            if delay_index > 0 then delay_label = delay_labels[delay_index]
            delay_label
        )

        /*
        Configures the frame preview PictureBox.
        */
        function setupPreview =
        (
            preview_box.SizeMode = (dotNetClass "System.Windows.Forms.PictureBoxSizeMode").Zoom
            preview_box.BorderStyle = (dotNetClass "System.Windows.Forms.BorderStyle").FixedSingle
            true
        )

        /*
        Disposes the current preview image so source frame files remain unlocked.
        */
        function clearPreview =
        (
            preview_box.Image = undefined

            if preview_image != undefined then
            (
                preview_image.Dispose()
                preview_image = undefined
            )

            true
        )

        /*
        Loads one frame image into the preview without keeping the source file locked.
        */
        function showPreview frame_path =
        (
            preview_loaded = false
            clearPreview()

            if frame_path != undefined and doesFileExist frame_path then
            (
                try
                (
                    image_class = dotNetClass "System.Drawing.Image"
                    source_image = image_class.FromFile frame_path
                    preview_image = dotNetObject "System.Drawing.Bitmap" source_image
                    source_image.Dispose()
                    preview_box.Image = preview_image
                    preview_loaded = true
                )
                catch
                (
                    exception_text = getCurrentException()
                    format "GIF Recorder preview error: %\n" exception_text
                    clearPreview()
                )
            )

            preview_loaded
        )

        /*
        Configures the DataGridView used for frame order and per-frame delay editing.
        */
        function setupFrameGrid =
        (
            grd_frames.AllowUserToAddRows = false
            grd_frames.AllowUserToDeleteRows = false
            grd_frames.AllowUserToResizeRows = false
            grd_frames.AllowUserToOrderColumns = false
            grd_frames.MultiSelect = true
            grd_frames.RowHeadersVisible = false
            grd_frames.SelectionMode = (dotNetClass "System.Windows.Forms.DataGridViewSelectionMode").FullRowSelect
            grd_frames.EditMode = (dotNetClass "System.Windows.Forms.DataGridViewEditMode").EditOnEnter
            grd_frames.AutoGenerateColumns = false
            grd_frames.Columns.Clear()

            frame_column = dotNetObject "System.Windows.Forms.DataGridViewTextBoxColumn"
            frame_column.Name = "Frame"
            frame_column.HeaderText = "Frame"
            frame_column.ReadOnly = true
            frame_column.AutoSizeMode = (dotNetClass "System.Windows.Forms.DataGridViewAutoSizeColumnMode").Fill
            frame_column.SortMode = (dotNetClass "System.Windows.Forms.DataGridViewColumnSortMode").NotSortable

            delay_column = dotNetObject "System.Windows.Forms.DataGridViewComboBoxColumn"
            delay_column.Name = "Delay"
            delay_column.HeaderText = "Delay"
            delay_column.Width = 72
            delay_column.SortMode = (dotNetClass "System.Windows.Forms.DataGridViewColumnSortMode").NotSortable
            delay_column.FlatStyle = (dotNetClass "System.Windows.Forms.FlatStyle").Flat

            for delay_label in GifRecorderCore.getDelayLabels() do
            (
                delay_column.Items.Add delay_label
            )

            grd_frames.Columns.Add frame_column
            grd_frames.Columns.Add delay_column
            true
        )

        /*
        Rebuilds the frame grid from the current in-memory ordered frame records.
        */
        function populateFrameGrid select_file_name:"" =
        (
            updating_grid = true
            grd_frames.Rows.Clear()
            selected_row_index = -1

            for frame_index = 1 to frame_records.count do
            (
                frame_record = frame_records[frame_index]
                row_index = grd_frames.Rows.Add()
                grd_frames.Rows.Item[row_index].Cells.Item[0].Value = frame_record.file_name
                grd_frames.Rows.Item[row_index].Cells.Item[1].Value = getDelayLabel frame_record.delay_seconds

                if select_file_name != "" and toLower frame_record.file_name == toLower select_file_name then
                (
                    selected_row_index = row_index
                )
            )

            grd_frames.ClearSelection()

            if selected_row_index >= 0 then
            (
                grd_frames.Rows.Item[selected_row_index].Selected = true
                grd_frames.CurrentCell = grd_frames.Rows.Item[selected_row_index].Cells.Item[0]
            )
            else if grd_frames.Rows.Count > 0 then
            (
                grd_frames.Rows.Item[0].Selected = true
                grd_frames.CurrentCell = grd_frames.Rows.Item[0].Cells.Item[0]
            )

            updating_grid = false
            true
        )

        /*
        Returns selected frame indices as sorted one-based MaxScript indices.
        */
        function getSelectedFrameIndices =
        (
            selected_indices = #()

            for selected_row in grd_frames.SelectedRows do
            (
                append selected_indices (selected_row.Index + 1)
            )

            sort selected_indices
            selected_indices
        )

        /*
        Selects frame rows using one-based MaxScript frame indices.
        */
        function selectFrameIndices frame_indices =
        (
            grd_frames.ClearSelection()

            for frame_index in frame_indices do
            (
                if frame_index >= 1 and frame_index <= grd_frames.Rows.Count then
                (
                    grd_frames.Rows.Item[frame_index - 1].Selected = true
                )
            )

            if frame_indices.count > 0 then
            (
                first_index = frame_indices[1]

                if first_index >= 1 and first_index <= grd_frames.Rows.Count then
                (
                    grd_frames.CurrentCell = grd_frames.Rows.Item[first_index - 1].Cells.Item[0]
                )
            )

            true
        )

        /*
        Saves the current in-memory frame order and delays to the scene manifest.
        */
        function saveFrameState =
        (
            capture_directory = GifRecorderCore.getSceneCaptureDirectory()
            state_saved = false

            if capture_directory != undefined and doesDirectoryExist capture_directory then
            (
                state_saved = GifRecorderCore.saveFrameRecords capture_directory frame_records
            )

            state_saved
        )

        /*
        Refreshes frame records from the scene capture directory.
        */
        function refreshFrames select_file_name:"" =
        (
            capture_directory = GifRecorderCore.getSceneCaptureDirectory()

            if capture_directory == undefined then
            (
                frame_records = #()
                populateFrameGrid()
                clearPreview()
                setStatus "Save the .max scene to start."
                false
            )
            else
            (
                GifRecorderCore.ensureDirectory capture_directory
                frame_records = GifRecorderCore.loadFrameRecords capture_directory default_delay:(getDefaultDelay())
                populateFrameGrid select_file_name:select_file_name

                if GifRecorderCore.last_error != "" then
                (
                    setStatus GifRecorderCore.last_error
                    false
                )
                else
                (
                    setStatus ((frame_records.count as string) + " frame(s).")
                    true
                )
            )
        )

        /*
        Updates the preview from the currently selected frame row.
        */
        function updatePreviewFromSelection =
        (
            capture_directory = GifRecorderCore.getSceneCaptureDirectory()

            if capture_directory != undefined and grd_frames.CurrentRow != undefined then
            (
                row_index = grd_frames.CurrentRow.Index + 1

                if row_index >= 1 and row_index <= frame_records.count then
                (
                    showPreview (capture_directory + frame_records[row_index].file_name)
                )
            )
            else
            (
                clearPreview()
            )

            true
        )

        /*
        Applies the default delay dropdown value to all selected frames.
        */
        function setSelectedFrameDelay =
        (
            selected_indices = getSelectedFrameIndices()
            delay_value = getDefaultDelay()

            for frame_index in selected_indices do
            (
                frame_records[frame_index].delay_seconds = delay_value
            )

            if selected_indices.count > 0 then
            (
                saveFrameState()
                populateFrameGrid()
                selectFrameIndices selected_indices
                setStatus ("Delay set to " + (getDelayLabel delay_value) + " s.")
            )

            true
        )

        /*
        Moves the selected frames one position earlier while preserving group order.
        */
        function moveSelectedFramesUp =
        (
            selected_indices = getSelectedFrameIndices()

            for list_index = 1 to selected_indices.count do
            (
                frame_index = selected_indices[list_index]

                if frame_index > 1 and (findItem selected_indices (frame_index - 1)) == 0 then
                (
                    previous_record = frame_records[frame_index - 1]
                    frame_records[frame_index - 1] = frame_records[frame_index]
                    frame_records[frame_index] = previous_record
                    selected_indices[list_index] = frame_index - 1
                )
            )

            if selected_indices.count > 0 then
            (
                sort selected_indices
                saveFrameState()
                populateFrameGrid()
                selectFrameIndices selected_indices
            )

            true
        )

        /*
        Moves the selected frames one position later while preserving group order.
        */
        function moveSelectedFramesDown =
        (
            selected_indices = getSelectedFrameIndices()

            for list_index = selected_indices.count to 1 by -1 do
            (
                frame_index = selected_indices[list_index]

                if frame_index < frame_records.count and (findItem selected_indices (frame_index + 1)) == 0 then
                (
                    next_record = frame_records[frame_index + 1]
                    frame_records[frame_index + 1] = frame_records[frame_index]
                    frame_records[frame_index] = next_record
                    selected_indices[list_index] = frame_index + 1
                )
            )

            if selected_indices.count > 0 then
            (
                sort selected_indices
                saveFrameState()
                populateFrameGrid()
                selectFrameIndices selected_indices
            )

            true
        )

        /*
        Deletes selected frame image files and removes them from the sequence.
        */
        function deleteSelectedFrames =
        (
            selected_indices = getSelectedFrameIndices()
            capture_directory = GifRecorderCore.getSceneCaptureDirectory()
            deleted_count = 0

            if capture_directory != undefined then
            (
                for list_index = selected_indices.count to 1 by -1 do
                (
                    frame_index = selected_indices[list_index]
                    frame_path = capture_directory + frame_records[frame_index].file_name

                    if doesFileExist frame_path then
                    (
                        if deleteFile frame_path then deleted_count += 1
                    )

                    deleteItem frame_records frame_index
                )

                saveFrameState()
                populateFrameGrid()
                updatePreviewFromSelection()
                setStatus ((deleted_count as string) + " frame file(s) deleted.")
            )

            true
        )

        /*
        Loads persisted user-facing UI settings.
        */
        function loadUiState =
        (
            chk_perspective.checked = IniSettings.getBoolean settings_file_path ui_section_name "Perspective" default_value:true
            spn_width.value = IniSettings.getInteger settings_file_path ui_section_name "OutputWidth" default_value:960
            spn_height.value = IniSettings.getInteger settings_file_path ui_section_name "OutputHeight" default_value:540
            RolloutState.loadDropdown ddl_default_delay settings_file_path ui_section_name "DefaultDelay" default_value:2
            true
        )

        /*
        Saves persisted user-facing UI settings.
        */
        function saveUiState =
        (
            IniSettings.setBoolean settings_file_path ui_section_name "Perspective" chk_perspective.checked
            IniSettings.setInteger settings_file_path ui_section_name "OutputWidth" spn_width.value
            IniSettings.setInteger settings_file_path ui_section_name "OutputHeight" spn_height.value
            RolloutState.saveDropdown ddl_default_delay settings_file_path ui_section_name "DefaultDelay"
            true
        )

        /*
        Reflows only vertical positions and the frame-list height for the fixed-width dialog.
        */
        function layoutUi dialog_height =
        (
            restart_y = dialog_height - 36
            status_y = restart_y - 24
            build_y = status_y - 36
            edit_y = build_y - 36
            capture_y = edit_y - 36
            delay_y = capture_y - 36
            grid_height = delay_y - 12 - grd_frames.pos.y

            if grid_height < 96 then grid_height = 96

            grd_frames.height = grid_height
            ddl_default_delay.pos = [12, delay_y]
            btn_set_delay.pos = [150, delay_y]
            btn_capture.pos = [12, capture_y]
            btn_refresh.pos = [150, capture_y]
            btn_up.pos = [12, edit_y]
            btn_down.pos = [102, edit_y]
            btn_delete.pos = [192, edit_y]
            btn_build.pos = [12, build_y]
            lbl_status.pos = [12, status_y]
            btn_restart.pos = [12, restart_y]
            true
        )

        on gifRecorderRollout open do
        (
            setupPreview()
            setupFrameGrid()
            loadUiState()
            GifRecorderCore.setCameraPerspective chk_perspective.checked
            dialog_size = getDialogSize gifRecorderRollout
            layoutUi dialog_size.y
            refreshFrames()
            updatePreviewFromSelection()
        )

        on gifRecorderRollout moved dialog_pos do
        (
            DialogHost.saveDialogPosition gifRecorderRollout settings_file_path ui_section_name
        )

        on gifRecorderRollout resized dialog_size do
        (
            layoutUi dialog_size.y
            DialogHost.saveDialogHeight gifRecorderRollout settings_file_path ui_section_name min_height:624
        )

        on gifRecorderRollout close do
        (
            saveUiState()
            DialogHost.saveDialogState gifRecorderRollout settings_file_path ui_section_name min_height:624
            clearPreview()
        )

        on gifRecorderRollout help do
        (
            ScriptReload.reloadLatest source_file_path script_prefix
        )

        on btn_store_view pressed do
        (
            undo "GIF Recorder Store View" on
            (
                if GifRecorderCore.storeCurrentView chk_perspective.checked then
                (
                    setStatus "Camera stored from active view."
                )
                else
                (
                    setStatus GifRecorderCore.last_error
                )
            )
        )

        on btn_apply_preset pressed do
        (
            undo "GIF Recorder Apply Preset" on
            (
                if GifRecorderCore.applyCameraPreset perspective_override:chk_perspective.checked then
                (
                    setStatus "Camera preset applied."
                )
                else
                (
                    setStatus GifRecorderCore.last_error
                )
            )
        )

        on chk_perspective changed state do
        (
            IniSettings.setBoolean settings_file_path ui_section_name "Perspective" state
            GifRecorderCore.setCameraPerspective state
            setStatus (if state then "Perspective projection." else "Orthographic projection.")
        )

        on spn_width changed numeric_value do
        (
            IniSettings.setInteger settings_file_path ui_section_name "OutputWidth" numeric_value
        )

        on spn_height changed numeric_value do
        (
            IniSettings.setInteger settings_file_path ui_section_name "OutputHeight" numeric_value
        )

        on ddl_default_delay selected item_index do
        (
            RolloutState.saveDropdown ddl_default_delay settings_file_path ui_section_name "DefaultDelay"
        )

        on btn_set_delay pressed do
        (
            setSelectedFrameDelay()
        )

        on btn_capture pressed do
        (
            captured_path = GifRecorderCore.captureFrame spn_width.value spn_height.value (getDefaultDelay()) chk_perspective.checked

            if captured_path != undefined then
            (
                captured_name = filenameFromPath captured_path
                refreshFrames select_file_name:captured_name
                updatePreviewFromSelection()
                setStatus ("Captured " + captured_name)
            )
            else
            (
                setStatus GifRecorderCore.last_error
            )
        )

        on btn_refresh pressed do
        (
            refreshFrames()
            updatePreviewFromSelection()
        )

        on btn_up pressed do
        (
            moveSelectedFramesUp()
            updatePreviewFromSelection()
        )

        on btn_down pressed do
        (
            moveSelectedFramesDown()
            updatePreviewFromSelection()
        )

        on btn_delete pressed do
        (
            deleteSelectedFrames()
        )

        on btn_build pressed do
        (
            saveFrameState()
            setStatus "Preparing FFmpeg / building GIF..."
            windows.processPostedMessages()
            gif_path = GifRecorderCore.buildGif frame_records spn_width.value spn_height.value

            if gif_path != undefined then
            (
                setStatus ("Built " + filenameFromPath gif_path)
            )
            else
            (
                setStatus GifRecorderCore.last_error
            )
        )

        on btn_restart pressed do
        (
            ScriptReload.reloadLatest source_file_path script_prefix
        )

        on grd_frames SelectionChanged sender event_args do
        (
            if not updating_grid then updatePreviewFromSelection()
        )

        on grd_frames CurrentCellDirtyStateChanged sender event_args do
        (
            if grd_frames.IsCurrentCellDirty then
            (
                commit_context = (dotNetClass "System.Windows.Forms.DataGridViewDataErrorContexts").Commit
                grd_frames.CommitEdit commit_context
            )
        )

        on grd_frames CellValueChanged sender event_args do
        (
            if not updating_grid and event_args.RowIndex >= 0 and event_args.ColumnIndex == 1 then
            (
                frame_index = event_args.RowIndex + 1

                if frame_index >= 1 and frame_index <= frame_records.count then
                (
                    cell_value = grd_frames.Rows.Item[event_args.RowIndex].Cells.Item[1].Value

                    if cell_value != undefined then
                    (
                        frame_records[frame_index].delay_seconds = GifRecorderCore.normalizeDelay ((cell_value as string) as float) default_delay:(getDefaultDelay())
                        saveFrameState()
                    )
                )
            )
        )
    )

    DialogHost.createManagedDialog gifRecorderRollout settings_file_path ui_section_name default_width:288 default_height:720 min_height:624
    windows.processPostedMessages()
)
