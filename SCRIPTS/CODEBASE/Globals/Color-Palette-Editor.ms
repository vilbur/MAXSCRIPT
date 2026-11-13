/*
Color Palette Editor - editable interface for numeric material/color IDs.
FILE_VERSION: 0.008 | PROJECT_VERSION: 0.009
Reads Codebase/Globals/ColorPaletteService.ms; all material-ID data lives in ColorPalette.ini.
*/








(
    global palette_editor_state
    global ColorPaletteService








    struct PaletteEditorState_v
    (
        entries = #(),
        ini_path = "",
        source_path = "",
        row_height = 20,
        target_height = 576,
        on create do
        (
        )
    )








    palette_editor_state = PaletteEditorState_v()
    palette_editor_state.source_path = getSourceFileName()
    if palette_editor_state.source_path == undefined or palette_editor_state.source_path == "" then
    (
        throw "Run Color-Palette-Editor.ms from its saved Globals folder."
    )
    palette_editor_state.ini_path = (getFilenamePath palette_editor_state.source_path) + "Color-Palette-Editor.ini"
    /*
    Migrates only the old editor's window layout, not shared color records.
    */
    local previous_ui_ini = (getFilenamePath palette_editor_state.source_path) + "Color-Palette-Editor-Test.ini"
    if not (doesFileExist palette_editor_state.ini_path) and (doesFileExist previous_ui_ini) then
    (
        if not (copyFile previous_ui_ini palette_editor_state.ini_path) then
        (
            format "PALETTE UI | Previous dialog settings could not be copied: %\n" previous_ui_ini
        )
    )








    /*
    Loads the shared color service and standard UI controls from canonical paths.
    The editor has no independent material-ID storage.
    */
    function loadPaletteEditorDependencies =
    (
        local globals_dir = getFilenamePath palette_editor_state.source_path
        local ui_dir = globals_dir + "..\\..\\UI\\Default\\"
        local service_path = globals_dir + "ColorPaletteService.ms"
        local helper_names = #("IniSettings.ms", "RolloutState.ms", "DialogHost.ms", "ScriptReload.ms", "ToolTitleButton.ms")
        if not doesFileExist service_path then
        (
            throw ("Missing shared color service: " + service_path)
        )
        fileIn service_path
        if ::ColorPaletteService == undefined then
        (
            throw ("Shared ColorPaletteService did not initialize: " + service_path)
        )
        for helper_name in helper_names do
        (
            local helper_path = ui_dir + helper_name
            if not doesFileExist helper_path then
            (
                throw ("Missing shared UI helper: " + helper_path)
            )
            fileIn helper_path
        )
        true
        -- return
    )








    /*
    Produces an editable copy of a shared service record.
    */
    function makePaletteEntry palette_id name_text color_value description_text is_transparent:false =
    (
        ::ColorPaletteService.makeEntry palette_id name_text color_value description_text is_transparent:is_transparent
        -- return
    )








    /*
    Returns whether an ID already exists in editable rows, optionally ignoring one row.
    */
    function paletteIdExists palette_id ignored_index:0 =
    (
        local found_id = false
        for entry_index = 1 to palette_editor_state.entries.count while not found_id do
        (
            if entry_index != ignored_index and palette_editor_state.entries[entry_index].palette_id == palette_id then found_id = true
        )
        found_id
        -- return
    )








    /*
    Validates the editor's candidate records using the canonical service.
    */
    function validatePaletteIds =
    (
        ::ColorPaletteService.validateEntries palette_editor_state.entries
        -- return
    )








    /*
    Parses a material ID using the canonical service ID range.
    */
    function parsePaletteId entered_text =
    (
        ::ColorPaletteService.parseId entered_text
        -- return
    )








    /*
    Retrieves independent source records from the service.
    */
    function loadPaletteRecords =
    (
        palette_editor_state.entries = ::ColorPaletteService.getEntries()
        true
        -- return
    )








    /*
    Commits edits to the shared service and saves them to the canonical INI.
    Invalid entries do not replace existing service values.
    */
    function savePaletteRecords =
    (
        local save_ok = ::ColorPaletteService.setEntries palette_editor_state.entries
        if save_ok then save_ok = ::ColorPaletteService.save()
        save_ok
        -- return
    )








    /*
    Returns the next available ID from the current unsaved editor records.
    */
    function nextPaletteId =
    (
        ::ColorPaletteService.nextFreeId palette_editor_state.entries
        -- return
    )








    /*
    Computes a screen-aware height for all palette rows without unnecessary scrolling.
    Compact rows are selected when the available work area is smaller.
    */
    function calculatePaletteDialogHeight =
    (
        local screen_height = (dotNetClass "System.Windows.Forms.Screen").PrimaryScreen.WorkingArea.Height
        local available_height = screen_height - 72
        if available_height < 360 then available_height = 360
        local row_candidates = #(21, 19, 17)
        local row_height = row_candidates[row_candidates.count]
        for possible_height in row_candidates while row_height == row_candidates[row_candidates.count] do
        (
            if (palette_editor_state.entries.count * possible_height + 182) <= available_height then row_height = possible_height
        )
        palette_editor_state.row_height = row_height
        local target_height = palette_editor_state.entries.count * row_height + 182
        if target_height > available_height then target_height = available_height
        if target_height < 330 then target_height = 330
        palette_editor_state.target_height = target_height
        target_height
        -- return
    )




    loadPaletteEditorDependencies()
    loadPaletteRecords()
    calculatePaletteDialogHeight()
    /*
    Keep stored height large enough to display the current palette.
    */
    local previous_height = IniSettings.getInteger palette_editor_state.ini_path "Dialog" "Height" default_value:0
    if previous_height < palette_editor_state.target_height then
    (
        IniSettings.setInteger palette_editor_state.ini_path "Dialog" "Height" palette_editor_state.target_height
    )








    rollout paletteEditorRollout "Color Palette Editor 0.009" width:576 height:576
    (
        dotNetControl btn_title "System.Windows.Forms.Button" pos:[12, 9] width:552 height:18
        dotNetControl dgv_colors "System.Windows.Forms.DataGridView" pos:[12, 42] width:552 height:432
        button btn_add "Add" pos:[12, 492] width:96 height:24
        button btn_delete "Delete" pos:[120, 492] width:96 height:24
        button btn_transparent "Toggle Transparent" pos:[228, 492] width:144 height:24
        button btn_save "Save" pos:[384, 492] width:96 height:24
        label lbl_status "Double-click a color to edit its swatch." pos:[12, 528] width:552 height:36








        /*
        Shows a nonblocking status or validation error beside the editor.
        */
        function setPaletteStatus status_text =
        (
            lbl_status.text = status_text
            -- return
        )








        /*
        Updates the displayed 4-column table from sorted underlying records.
        */
        /*
        No vertical scrollbar when all rows are visible; fallback on smaller screens.
        */
        function updatePaletteGridScrolling =
        (
            local required_height = palette_editor_state.entries.count * palette_editor_state.row_height + dgv_colors.ColumnHeadersHeight + 12
            local scroll_mode = dotNetClass "System.Windows.Forms.ScrollBars"
            dgv_colors.ScrollBars = if dgv_colors.Height >= required_height then scroll_mode.None else scroll_mode.Vertical
            -- return
        )




        function refreshPaletteGrid =
        (
            qsort palette_editor_state.entries colorPaletteCompareIds
            dgv_colors.Rows.Clear()
            dgv_colors.RowCount = palette_editor_state.entries.count
            updatePaletteGridScrolling()
            local drawing_colors = dotNetClass "System.Drawing.Color"








            for entry_index = 1 to palette_editor_state.entries.count do
            (
                local entry_value = palette_editor_state.entries[entry_index]
                local grid_row = dgv_colors.Rows.Item[entry_index - 1]
                grid_row.Cells.Item[0].Value = entry_value.palette_id as string
                grid_row.Cells.Item[1].Value = entry_value.name_text
                grid_row.Cells.Item[2].Value = if entry_value.is_transparent then "TRANSPARENT" else "RGB"
                grid_row.Cells.Item[3].Value = entry_value.description_text








                local cell_color = drawing_colors.FromArgb (entry_value.color_value.r as integer) (entry_value.color_value.g as integer) (entry_value.color_value.b as integer)
                local dark_text = drawing_colors.FromArgb 25 25 25
                local light_text = drawing_colors.FromArgb 255 255 255
                local is_light = (entry_value.color_value.r * 0.299 + entry_value.color_value.g * 0.587 + entry_value.color_value.b * 0.114) > 152
                local swatch_cell = grid_row.Cells.Item[2]
                swatch_cell.Style.BackColor = cell_color
                swatch_cell.Style.SelectionBackColor = cell_color
                swatch_cell.Style.ForeColor = if is_light then dark_text else light_text
                swatch_cell.Style.SelectionForeColor = if is_light then dark_text else light_text
            )
            -- return
        )








        /*
        Creates the editable grid columns and practical dark UI styling.
        */
        function configurePaletteGrid =
        (
            local color_class = dotNetClass "System.Drawing.Color"
            dgv_colors.AllowUserToAddRows = false
            dgv_colors.AllowUserToDeleteRows = false
            dgv_colors.AllowUserToOrderColumns = false
            dgv_colors.AllowUserToResizeRows = false
            dgv_colors.RowHeadersVisible = false
            dgv_colors.MultiSelect = false
            dgv_colors.SelectionMode = (dotNetClass "System.Windows.Forms.DataGridViewSelectionMode").FullRowSelect
            dgv_colors.AutoSizeColumnsMode = (dotNetClass "System.Windows.Forms.DataGridViewAutoSizeColumnsMode").Fill
            dgv_colors.BackgroundColor = color_class.FromArgb 48 48 48
            dgv_colors.GridColor = color_class.FromArgb 75 75 75
            dgv_colors.DefaultCellStyle.BackColor = color_class.FromArgb 58 58 58
            dgv_colors.DefaultCellStyle.ForeColor = color_class.FromArgb 220 220 220
            dgv_colors.DefaultCellStyle.SelectionBackColor = color_class.FromArgb 70 92 112
            dgv_colors.DefaultCellStyle.SelectionForeColor = color_class.FromArgb 255 255 255
            dgv_colors.ColumnHeadersHeight = 26
            dgv_colors.RowTemplate.Height = palette_editor_state.row_height
            dgv_colors.ColumnCount = 4
            dgv_colors.Columns.Item[0].Name = "ID"
            dgv_colors.Columns.Item[1].Name = "NAME"
            dgv_colors.Columns.Item[2].Name = "COLOR (double-click)"
            dgv_colors.Columns.Item[3].Name = "DESCRIPTION"
            dgv_colors.Columns.Item[0].FillWeight = 9
            dgv_colors.Columns.Item[1].FillWeight = 24
            dgv_colors.Columns.Item[2].FillWeight = 25
            dgv_colors.Columns.Item[3].FillWeight = 42
            dgv_colors.Columns.Item[2].ReadOnly = true








            for column_index = 0 to 3 do
            (
                dgv_colors.Columns.Item[column_index].SortMode = (dotNetClass "System.Windows.Forms.DataGridViewColumnSortMode").NotSortable
            )
            refreshPaletteGrid()
            -- return
        )








        /*
        Returns the one selected palette row, or undefined if no row is selected.
        */
        function getSelectedPaletteRow =
        (
            if dgv_colors.CurrentCell == undefined then
            (
                undefined
            )
            else
            (
                local row_number = dgv_colors.CurrentCell.RowIndex + 1
                if row_number >= 1 and row_number <= palette_editor_state.entries.count then row_number else undefined
            )
            -- return
        )








        on paletteEditorRollout open do
        (
            ToolTitleButton.setupToolTitleButton btn_title "Color Palette Editor"
            ToolTitleButton.resizeToolTitleButton btn_title (paletteEditorRollout.width - 24)
            configurePaletteGrid()
            local actual_size = getDialogSize paletteEditorRollout
            if actual_size != undefined then
            (
                local list_height = actual_size.y - 144
                if list_height < 168 then list_height = 168
                dgv_colors.height = list_height
                btn_add.pos = [12, list_height + 60]
                btn_delete.pos = [120, list_height + 60]
                btn_transparent.pos = [228, list_height + 60]
                btn_save.pos = [384, list_height + 60]
                lbl_status.pos = [12, list_height + 96]
                updatePaletteGridScrolling()
            )
            setPaletteStatus ((palette_editor_state.entries.count as string) + " palette IDs loaded. IDs remain unique.")
        )








        on paletteEditorRollout moved dialog_pos do
        (
            /*
            Save the actual position from the move event before the dialog is destroyed.
            */
            if classOf dialog_pos == Point2 then
            (
                IniSettings.setPoint2 palette_editor_state.ini_path "Dialog" "PosX" "PosY" dialog_pos
            )
            else
            (
                format "PALETTE UI ERROR | Invalid dialog position from moved event: %\n" dialog_pos
            )
        )








        on paletteEditorRollout resized dialog_size do
        (
            local new_grid_height = dialog_size.y - 144
            if new_grid_height < 168 then new_grid_height = 168
            dgv_colors.height = new_grid_height
            updatePaletteGridScrolling()
            btn_add.pos = [12, new_grid_height + 60]
            btn_delete.pos = [120, new_grid_height + 60]
            btn_transparent.pos = [228, new_grid_height + 60]
            btn_save.pos = [384, new_grid_height + 60]
            lbl_status.pos = [12, new_grid_height + 96]
            ToolTitleButton.resizeToolTitleButton btn_title (dialog_size.x - 24)
            DialogHost.saveDialogHeight paletteEditorRollout palette_editor_state.ini_path "Dialog" min_height:330
        )








        on paletteEditorRollout close do
        (
            /*
            Avoid querying the position of a dialog during teardown; it was saved on move.
            */
            DialogHost.saveDialogHeight paletteEditorRollout palette_editor_state.ini_path "Dialog" min_height:330
            if not savePaletteRecords() then
            (
                format "PALETTE SAVE FAILED | duplicate or invalid ID; data not committed.\n"
            )
        )








        on btn_title Click sender event_args do
        (
            dgv_colors.EndEdit()
            if savePaletteRecords() then
            (
                /*
                Save the height before restarting the dialog.
                */
                DialogHost.saveDialogHeight paletteEditorRollout palette_editor_state.ini_path "Dialog" min_height:330
                restartTool palette_editor_state.source_path "Color-Palette-Editor"
            )
        )








        on dgv_colors CellValidating sender event_args do
        (
            local row_number = event_args.RowIndex + 1
            local column_number = event_args.ColumnIndex
            if row_number > 0 and row_number <= palette_editor_state.entries.count then
            (
                local candidate_text = event_args.FormattedValue as string
                if column_number == 0 then
                (
                    local candidate_id = parsePaletteId candidate_text
                    if candidate_id == undefined then
                    (
                        event_args.Cancel = true
                        setPaletteStatus "ID must be a whole number between 1 and 60000."
                    )
                    else if paletteIdExists candidate_id ignored_index:row_number then
                    (
                        event_args.Cancel = true
                        setPaletteStatus ("Duplicate ID " + (candidate_id as string) + " is not allowed.")
                    )
                )
                else if column_number == 1 and candidate_text == "" then
                (
                    event_args.Cancel = true
                    setPaletteStatus "Name cannot be empty."
                )
            )
        )








        on dgv_colors CellEndEdit sender event_args do
        (
            local row_number = event_args.RowIndex + 1
            local column_number = event_args.ColumnIndex
            if row_number > 0 and row_number <= palette_editor_state.entries.count then
            (
                local entry_value = palette_editor_state.entries[row_number]
                local current_text = dgv_colors.Rows.Item[row_number - 1].Cells.Item[column_number].Value as string
                case column_number of
                (
                    0: (entry_value.palette_id = parsePaletteId current_text)
                    1: (entry_value.name_text = current_text)
                    3: (entry_value.description_text = current_text)
                )
                if column_number == 0 then
                (
                    setPaletteStatus "ID changed. Click Save to sort the list numerically."
                )
                else
                (
                    setPaletteStatus "Edited value ready. Save to persist."
                )
            )
        )








        on dgv_colors CellDoubleClick sender event_args do
        (
            if event_args.ColumnIndex == 2 and event_args.RowIndex >= 0 then
            (
                local row_number = event_args.RowIndex + 1
                local entry_value = palette_editor_state.entries[row_number]
                local dialog_color = dotNetObject "System.Windows.Forms.ColorDialog"
                dialog_color.FullOpen = true
                dialog_color.Color = (dotNetClass "System.Drawing.Color").FromArgb (entry_value.color_value.r as integer) (entry_value.color_value.g as integer) (entry_value.color_value.b as integer)
                if dialog_color.ShowDialog() == (dotNetClass "System.Windows.Forms.DialogResult").OK then
                (
                    entry_value.color_value = (color (dialog_color.Color.R as integer) (dialog_color.Color.G as integer) (dialog_color.Color.B as integer))
                    entry_value.is_transparent = false
                    refreshPaletteGrid()
                    setPaletteStatus "Swatch color changed. Save to persist."
                )
                dialog_color.Dispose()
            )
        )








        on btn_add pressed do
        (
            dgv_colors.EndEdit()
            local new_id = nextPaletteId()
            if new_id == undefined then
            (
                setPaletteStatus "No free numeric IDs in 1..60000."
            )
            else
            (
                append palette_editor_state.entries (makePaletteEntry new_id "NEW_COLOR" (color 215 215 215) "New entry")
                refreshPaletteGrid()
                setPaletteStatus ("Added ID " + (new_id as string) + ".")
            )
        )








        on btn_delete pressed do
        (
            dgv_colors.EndEdit()
            local row_number = getSelectedPaletteRow()
            if row_number != undefined then
            (
                local removed_id = palette_editor_state.entries[row_number].palette_id
                deleteItem palette_editor_state.entries row_number
                refreshPaletteGrid()
                setPaletteStatus ("Deleted ID " + (removed_id as string) + ". Save to persist.")
            )
        )








        on btn_transparent pressed do
        (
            dgv_colors.EndEdit()
            local row_number = getSelectedPaletteRow()
            if row_number != undefined then
            (
                local entry_value = palette_editor_state.entries[row_number]
                entry_value.is_transparent = not entry_value.is_transparent
                refreshPaletteGrid()
                setPaletteStatus "Transparency flag changed. Save to persist."
            )
        )








        on btn_save pressed do
        (
            dgv_colors.EndEdit()
            if savePaletteRecords() then
            (
                refreshPaletteGrid()
                setPaletteStatus ("Saved " + (palette_editor_state.entries.count as string) + " palette entries; sorted by ID.")
            )
            else
            (
                setPaletteStatus "Save blocked: duplicate or invalid ID."
            )
        )
    )








    if not validatePaletteIds() then
    (
        throw "Initial palette IDs are not unique."
    )
    if palette_editor_state.entries.count > 0 then
    (
        local first_id = palette_editor_state.entries[1].palette_id
        if not (paletteIdExists first_id) or (paletteIdExists first_id ignored_index:1) then
        (
            throw "PALETTE SELF-TEST FAILED | duplicate-ID exclusion logic."
        )
    )
    if (parsePaletteId "1.5") != undefined or (parsePaletteId "0") != undefined then
    (
        throw "PALETTE SELF-TEST FAILED | invalid ID parser."
    )
    format "PALETTE SELF-TEST | PASS: % IDs unique; invalid IDs rejected.\n" palette_editor_state.entries.count








    DialogHost.createManagedDialog paletteEditorRollout palette_editor_state.ini_path "Dialog" tool_key:"Color-Palette-Editor" default_width:576 default_height:palette_editor_state.target_height min_height:330
    windows.processPostedMessages()
)