/*
Wall Cleaner pipeline checklist with per-block scene persistence.
File version: 0.06
Project version: 0.06
*/

global wall_cleaner_checklist_file_version = 0.06
global wall_cleaner_checklist_project_version
global wall_cleaner_checklist_title
global wall_cleaner_checklist_source_file
global WallCleanerChecklist
global wall_cleaner_checklist_rollout

/*
Closes all already-open Wall Cleaner Checklist dialogs before this version is initialized.
*/
function closePreviousChecklistDialogs =
(
    closed_count = 0
    popup_handles = UIAccessor.GetPopupDialogs()

    for popup_handle in popup_handles do
    (
        popup_title = UIAccessor.GetWindowText popup_handle

        if (findString popup_title "Wall Cleaner Checklist " == 1) then
        (
            UIAccessor.CloseDialog popup_handle
            closed_count += 1
        )
    )

    if wall_cleaner_checklist_rollout != undefined then
    (
        try (destroyDialog wall_cleaner_checklist_rollout) catch ()
    )

    closed_count
    -- return
)

closePreviousChecklistDialogs()

/*
Shows the standard 3ds Max rename-style text entry dialog.
Returns the entered string when confirmed, or undefined when cancelled.
*/
function wallCleanerAskString dialog_title default_value:"" =
(
    rename_dialog = dotNetObject "MaxCustomControls.RenameInstanceDialog" default_value
    rename_dialog.text = dialog_title
    modal_result = rename_dialog.ShowModal()
    result_text = undefined

    if ((modal_result as string) == "OK") then
    (
        result_text = rename_dialog.InstanceName
    )

    result_text
    -- return
)

if (wall_cleaner_checklist_project_version == undefined or wall_cleaner_checklist_project_version < 0.06) then
(
    wall_cleaner_checklist_project_version = 0.06
)

wall_cleaner_checklist_title = "Wall Cleaner Checklist " + (wall_cleaner_checklist_project_version as string)
wall_cleaner_checklist_source_file = getSourceFileName()

struct WallCleanerChecklist_v
(
    file_version = 0.06,
    project_version = 0.06,
    data_node_name = "__WALL_CLEANER_CHECKLIST_DATA__",
    data_node_marker_key = "WCC_DATA_NODE",
    preset_names_key = "WCC_PRESET_NAMES",
    preset_states_key = "WCC_PRESET_STATES",
    active_preset_key = "WCC_ACTIVE_PRESET",
    item_count = 21,

    /*
    Returns one unchecked checklist-state array.
    */
    function getEmptyState =
    (
        state_values = #()

        for item_index = 1 to item_count do
        (
            append state_values false
        )

        state_values
        -- return
    ),

    /*
    Returns the hidden scene helper that owns checklist data.
    */
    function findDataNode =
    (
        data_node = undefined

        for helper_node in helpers while data_node == undefined do
        (
            if (isValidNode helper_node and getUserPropVal helper_node data_node_marker_key == true) then
            (
                data_node = helper_node
            )
        )

        data_node
        -- return
    ),

    /*
    Creates the hidden scene helper only when persistent data must be written.
    */
    function ensureDataNode =
    (
        data_node = findDataNode()

        if data_node == undefined then
        (
            data_node = Point \
                name:(uniqueName data_node_name) \
                size:1.0 \
                centermarker:false \
                axistripod:false \
                cross:false \
                box:false \
                constantscreensize:true \
                drawontop:false

            hide data_node
            setUserPropVal data_node data_node_marker_key true
            setUserPropVal data_node preset_names_key #("Block A")

            initial_states = #()
            append initial_states (getEmptyState())
            setUserPropVal data_node preset_states_key initial_states
            setUserPropVal data_node active_preset_key 1
        )

        data_node
        -- return
    ),

    /*
    Returns stored block names or the default unsaved Block A state.
    */
    function getPresetNames =
    (
        data_node = findDataNode()
        preset_names = #("Block A")

        if data_node != undefined then
        (
            stored_names = getUserPropVal data_node preset_names_key

            if (stored_names != undefined and classOf stored_names == Array and stored_names.count > 0) then
            (
                preset_names = stored_names
            )
        )

        preset_names
        -- return
    ),

    /*
    Normalizes checklist states and migrates the 0.01 22-item layout to the current 21-item layout.
    New or renamed checks are never marked complete unless an exact legacy equivalent exists.
    */
    function normalizeStateValues state_values =
    (
        normalized_state = undefined

        if (state_values != undefined and classOf state_values == Array) then
        (
            if state_values.count == item_count then
            (
                normalized_state = copy state_values
            )
            else if (state_values.count == 22 and item_count == 21) then
            (
                normalized_state = getEmptyState()

                for item_index = 1 to 16 do
                (
                    normalized_state[item_index] = state_values[item_index]
                )

                /*
                Item 17 WALL GEOMETRY CHECK is new in the current Main Pipeline.
                Leave it unchecked rather than inferring completion from a different legacy check.
                */
                normalized_state[18] = state_values[18]
                normalized_state[19] = state_values[20]
                normalized_state[20] = state_values[21]
                normalized_state[21] = state_values[22]
            )
        )

        normalized_state
        -- return
    ),

    /*
    Returns normalized per-block checklist states without inventing completed items.
    */
    function getPresetStates =
    (
        preset_names = getPresetNames()
        data_node = findDataNode()
        stored_states = undefined
        preset_states = #()

        if data_node != undefined then
        (
            stored_states = getUserPropVal data_node preset_states_key
        )

        for preset_index = 1 to preset_names.count do
        (
            state_values = undefined

            if (stored_states != undefined and classOf stored_states == Array and preset_index <= stored_states.count) then
            (
                candidate_state = stored_states[preset_index]

                if (candidate_state != undefined and classOf candidate_state == Array) then
                (
                    state_values = normalizeStateValues candidate_state
                )
            )

            if state_values == undefined then
            (
                state_values = getEmptyState()
            )

            append preset_states state_values
        )

        preset_states
        -- return
    ),

    /*
    Returns the active block index clamped to the currently available block list.
    */
    function getActivePresetIndex =
    (
        preset_names = getPresetNames()
        active_index = 1
        data_node = findDataNode()

        if data_node != undefined then
        (
            stored_index = getUserPropVal data_node active_preset_key

            if (stored_index != undefined and classOf stored_index == Integer) then
            (
                active_index = stored_index
            )
        )

        if active_index < 1 then active_index = 1
        if active_index > preset_names.count then active_index = preset_names.count

        active_index
        -- return
    ),

    /*
    Writes all checklist data back to the hidden scene helper.
    */
    function writeAllData preset_names preset_states active_index =
    (
        data_node = ensureDataNode()

        if data_node == undefined then
        (
            false
        )
        else
        (
            setUserPropVal data_node preset_names_key preset_names
            setUserPropVal data_node preset_states_key preset_states
            setUserPropVal data_node active_preset_key active_index
            true
        )
        -- return
    ),

    /*
    Selects which block is active without changing any checklist values.
    */
    function setActivePresetIndex active_index =
    (
        preset_names = getPresetNames()
        preset_states = getPresetStates()

        if active_index < 1 then active_index = 1
        if active_index > preset_names.count then active_index = preset_names.count

        writeAllData preset_names preset_states active_index
        -- return
    ),

    /*
    Writes the current checklist state into the active block.
    */
    function setCurrentPresetState state_values =
    (
        if (state_values == undefined or classOf state_values != Array or state_values.count != item_count) then
        (
            false
        )
        else
        (
            preset_names = getPresetNames()
            preset_states = getPresetStates()
            active_index = getActivePresetIndex()
            preset_states[active_index] = copy state_values
            writeAllData preset_names preset_states active_index
        )
        -- return
    ),

    /*
    Returns the checklist state for the active block.
    */
    function getCurrentPresetState =
    (
        preset_states = getPresetStates()
        active_index = getActivePresetIndex()
        copy preset_states[active_index]
        -- return
    ),

    /*
    Returns true when the supplied block name is not already used.
    */
    function isPresetNameAvailable preset_name =
    (
        preset_names = getPresetNames()
        (findItem preset_names preset_name) == 0
        -- return
    ),

    /*
    Returns a suggested sequential block name such as Block B or Block C.
    */
    function getSuggestedPresetName =
    (
        preset_names = getPresetNames()
        next_index = preset_names.count + 1

        if next_index <= 26 then
        (
            "Block " + substring "ABCDEFGHIJKLMNOPQRSTUVWXYZ" next_index 1
        )
        else
        (
            "Block " + (next_index as string)
        )
        -- return
    ),

    /*
    Adds one new block with a completely unchecked checklist.
    */
    function addPreset preset_name =
    (
        clean_name = preset_name

        if clean_name == "" then
        (
            false
        )
        else if not isPresetNameAvailable clean_name then
        (
            false
        )
        else
        (
            preset_names = getPresetNames()
            preset_states = getPresetStates()
            append preset_names clean_name
            append preset_states (getEmptyState())
            writeAllData preset_names preset_states preset_names.count
        )
        -- return
    ),

    /*
    Renames the active block while preserving its checklist state.
    */
    function renameActivePreset preset_name =
    (
        clean_name = preset_name
        preset_names = getPresetNames()
        preset_states = getPresetStates()
        active_index = getActivePresetIndex()

        if clean_name == "" then
        (
            false
        )
        else if (clean_name != preset_names[active_index] and not isPresetNameAvailable clean_name) then
        (
            false
        )
        else
        (
            preset_names[active_index] = clean_name
            writeAllData preset_names preset_states active_index
        )
        -- return
    ),

    /*
    Deletes the active block when at least one other block remains.
    */
    function deleteActivePreset =
    (
        preset_names = getPresetNames()
        preset_states = getPresetStates()
        active_index = getActivePresetIndex()

        if preset_names.count <= 1 then
        (
            false
        )
        else
        (
            deleteItem preset_names active_index
            deleteItem preset_states active_index

            if active_index > preset_names.count then active_index = preset_names.count
            writeAllData preset_names preset_states active_index
        )
        -- return
    ),

    /*
    Resets only the active block to an unchecked checklist.
    */
    function resetActivePreset =
    (
        preset_names = getPresetNames()
        preset_states = getPresetStates()
        active_index = getActivePresetIndex()
        preset_states[active_index] = getEmptyState()
        writeAllData preset_names preset_states active_index
        -- return
    )
)

WallCleanerChecklist = WallCleanerChecklist_v()

rollout wall_cleaner_checklist_rollout wall_cleaner_checklist_title width:384 height:900
(
    local ui_is_loading = false
    local checklist_model = WallCleanerChecklist
    local checklist_label_default_color = undefined
    local checklist_label_checked_color = undefined

    groupBox grp_model_setup "MODEL SETUP" pos:[12,12] width:360 height:108
    dropdownList ddl_blocks "Block:" pos:[24,36] width:336 height:24 items:#("Block A") selection:1
    button btn_new_block "NEW" pos:[24,72] width:96 height:24 \
        toolTip:"Create a new block with an empty checklist."
    button btn_rename_block "RENAME" pos:[132,72] width:96 height:24 \
        toolTip:"Rename the active block without changing its checklist state."
    button btn_delete_block "DELETE" pos:[240,72] width:96 height:24 \
        toolTip:"Delete the active block and its saved checklist state."

    groupBox grp_preprocess "PRE-PROCESS" pos:[12,132] width:360 height:96
    checkbox chk_01 "" pos:[24,156] width:18 height:20
    dotNetControl lbl_01 "System.Windows.Forms.Label" text:"CHECK / FIX ORTHO" pos:[48,156] width:312 height:20
    checkbox chk_02 "" pos:[24,180] width:18 height:20
    dotNetControl lbl_02 "System.Windows.Forms.Label" text:"CHECK HORIZONTAL / VERTICAL EDGES" pos:[48,180] width:312 height:20
    checkbox chk_03 "" pos:[24,204] width:18 height:20
    dotNetControl lbl_03 "System.Windows.Forms.Label" text:"EXPLODE WALLS" pos:[48,204] width:312 height:20

    groupBox grp_slicing "SLICING / TOPOLOGY CLEANUP" pos:[12,240] width:360 height:144
    checkbox chk_04 "" pos:[24,264] width:18 height:20
    dotNetControl lbl_04 "System.Windows.Forms.Label" text:"SLICE HORIZONTAL / VERTICAL" pos:[48,264] width:312 height:20
    checkbox chk_05 "" pos:[24,288] width:18 height:20
    dotNetControl lbl_05 "System.Windows.Forms.Label" text:"SLICE CLEANUP" pos:[48,288] width:312 height:20
    checkbox chk_06 "" pos:[48,312] width:18 height:20
    dotNetControl lbl_06 "System.Windows.Forms.Label" text:"2-EDGE VERTS FIX" pos:[72,312] width:288 height:20
    checkbox chk_07 "" pos:[48,336] width:18 height:20
    dotNetControl lbl_07 "System.Windows.Forms.Label" text:"DEGENERATE FACES FIX" pos:[72,336] width:288 height:20
    checkbox chk_08 "" pos:[48,360] width:18 height:20
    dotNetControl lbl_08 "System.Windows.Forms.Label" text:"SELECT + WELD BORDER" pos:[72,360] width:288 height:20

    groupBox grp_extrude_prepare "EXTRUDE PREPARE" pos:[12,396] width:360 height:216
    checkbox chk_09 "" pos:[24,420] width:18 height:20
    dotNetControl lbl_09 "System.Windows.Forms.Label" text:"ATTACH WALLS TO ONE OBJECT" pos:[48,420] width:312 height:20
    checkbox chk_10 "" pos:[24,444] width:18 height:20
    dotNetControl lbl_10 "System.Windows.Forms.Label" text:"FLOORS — ASSIGN MATERIAL ID PER FLOOR" pos:[48,444] width:312 height:20
    checkbox chk_11 "" pos:[24,468] width:18 height:20
    dotNetControl lbl_11 "System.Windows.Forms.Label" text:"DETACH BY FLOOR" pos:[48,468] width:312 height:20
    checkbox chk_12 "" pos:[24,492] width:18 height:20
    dotNetControl lbl_12 "System.Windows.Forms.Label" text:"CORNER CLEANUP / MATCH WALL TOPOLOGY PER FLOOR" pos:[48,492] width:312 height:20
    checkbox chk_13 "" pos:[24,516] width:18 height:20
    dotNetControl lbl_13 "System.Windows.Forms.Label" text:"REBUILD MESH" pos:[48,516] width:312 height:20
    checkbox chk_14 "" pos:[24,540] width:18 height:20
    dotNetControl lbl_14 "System.Windows.Forms.Label" text:"EXTRUDE SOURCE CHECK" pos:[48,540] width:312 height:20
    checkbox chk_15 "" pos:[24,564] width:18 height:20
    dotNetControl lbl_15 "System.Windows.Forms.Label" text:"ASSIGN EXTRUDE MATERIAL GROUPS" pos:[48,564] width:312 height:20
    checkbox chk_16 "" pos:[24,588] width:18 height:20
    dotNetControl lbl_16 "System.Windows.Forms.Label" text:"EXPLODE BY MATERIAL" pos:[48,588] width:312 height:20

    groupBox grp_extrude_walls "EXTRUDE WALLS" pos:[12,624] width:360 height:96
    checkbox chk_17 "" pos:[24,648] width:18 height:20
    dotNetControl lbl_17 "System.Windows.Forms.Label" text:"WALL GEOMETRY CHECK" pos:[48,648] width:312 height:20
    checkbox chk_18 "" pos:[24,672] width:18 height:20
    dotNetControl lbl_18 "System.Windows.Forms.Label" text:"WALLS EXTRUDE" pos:[48,672] width:312 height:20
    checkbox chk_19 "" pos:[24,696] width:18 height:20
    dotNetControl lbl_19 "System.Windows.Forms.Label" text:"FINISH WALLS — FIX CORNERS" pos:[48,696] width:312 height:20

    groupBox grp_postprocess "POST-PROCESS CHECK" pos:[12,732] width:360 height:60
    checkbox chk_20 "" pos:[24,756] width:18 height:20
    dotNetControl lbl_20 "System.Windows.Forms.Label" text:"STL CHECK" pos:[48,756] width:312 height:20

    groupBox grp_ready "READY" pos:[12,804] width:360 height:48
    checkbox chk_21 "" pos:[24,826] width:18 height:20
    dotNetControl lbl_21 "System.Windows.Forms.Label" text:"READY" pos:[48,826] width:120 height:20
    dotNetControl lbl_progress "System.Windows.Forms.Label" text:"0 / 21 complete" pos:[192,826] width:168 height:20

    button btn_reset_block "RESET BLOCK" pos:[12,864] width:120 height:24 \
        toolTip:"Clear every checklist item only in the active block."
    button btn_restart "RESTART" pos:[252,864] width:120 height:24 \
        toolTip:"Reload the newest Wall Cleaner Checklist script from this script folder."

    /*
    Initializes .NET checklist labels for the 3ds Max dark UI.
    */
    function initializeChecklistLabelStyles =
    (
        drawing_color = dotNetClass "System.Drawing.Color"
        content_alignment = dotNetClass "System.Drawing.ContentAlignment"
        cursor_types = dotNetClass "System.Windows.Forms.Cursors"
        checklist_labels = #(lbl_01, lbl_02, lbl_03, lbl_04, lbl_05, lbl_06, lbl_07, lbl_08, lbl_09, lbl_10, lbl_11, lbl_12, lbl_13, lbl_14, lbl_15, lbl_16, lbl_17, lbl_18, lbl_19, lbl_20, lbl_21)

        checklist_label_default_color = drawing_color.FromArgb 220 220 220
        checklist_label_checked_color = drawing_color.FromArgb 76 175 80

        for checklist_label in checklist_labels do
        (
            checklist_label.AutoSize = false
            checklist_label.BackColor = checklist_label.Parent.BackColor
            checklist_label.ForeColor = checklist_label_default_color
            checklist_label.TextAlign = content_alignment.MiddleLeft
            checklist_label.Cursor = cursor_types.Hand
        )

        lbl_progress.AutoSize = false
        lbl_progress.BackColor = lbl_progress.Parent.BackColor
        lbl_progress.ForeColor = checklist_label_default_color
        lbl_progress.TextAlign = content_alignment.MiddleRight

        true
        -- return
    )

    /*
    Sets every checklist label to green when its matching checkbox is checked.
    */
    function updateChecklistLabelColors =
    (
        checkbox_controls = #(chk_01, chk_02, chk_03, chk_04, chk_05, chk_06, chk_07, chk_08, chk_09, chk_10, chk_11, chk_12, chk_13, chk_14, chk_15, chk_16, chk_17, chk_18, chk_19, chk_20, chk_21)
        checklist_labels = #(lbl_01, lbl_02, lbl_03, lbl_04, lbl_05, lbl_06, lbl_07, lbl_08, lbl_09, lbl_10, lbl_11, lbl_12, lbl_13, lbl_14, lbl_15, lbl_16, lbl_17, lbl_18, lbl_19, lbl_20, lbl_21)

        if (checklist_label_default_color != undefined and checklist_label_checked_color != undefined) then
        (
            for item_index = 1 to checklist_labels.count do
            (
                checklist_labels[item_index].ForeColor = if checkbox_controls[item_index].checked then checklist_label_checked_color else checklist_label_default_color
            )
        )

        true
        -- return
    )

    /*
    Returns all checkbox values in persistent pipeline order.
    */
    function getUiState =
    (
        #(
            chk_01.checked,
            chk_02.checked,
            chk_03.checked,
            chk_04.checked,
            chk_05.checked,
            chk_06.checked,
            chk_07.checked,
            chk_08.checked,
            chk_09.checked,
            chk_10.checked,
            chk_11.checked,
            chk_12.checked,
            chk_13.checked,
            chk_14.checked,
            chk_15.checked,
            chk_16.checked,
            chk_17.checked,
            chk_18.checked,
            chk_19.checked,
            chk_20.checked,
            chk_21.checked
        )
        -- return
    )

    /*
    Updates the completion counter for the visible active block.
    */
    function updateProgress =
    (
        state_values = getUiState()
        completed_count = 0

        for state_value in state_values do
        (
            if state_value then completed_count += 1
        )

        lbl_progress.text = (completed_count as string) + " / 21 complete"
        updateChecklistLabelColors()
        completed_count
        -- return
    )

    /*
    Applies one persistent checklist state to all visible checkboxes.
    */
    function setUiState state_values =
    (
        previous_loading_state = ui_is_loading
        ui_is_loading = true

        if (state_values != undefined and classOf state_values == Array and state_values.count == 21) then
        (
            chk_01.checked = state_values[1]
            chk_02.checked = state_values[2]
            chk_03.checked = state_values[3]
            chk_04.checked = state_values[4]
            chk_05.checked = state_values[5]
            chk_06.checked = state_values[6]
            chk_07.checked = state_values[7]
            chk_08.checked = state_values[8]
            chk_09.checked = state_values[9]
            chk_10.checked = state_values[10]
            chk_11.checked = state_values[11]
            chk_12.checked = state_values[12]
            chk_13.checked = state_values[13]
            chk_14.checked = state_values[14]
            chk_15.checked = state_values[15]
            chk_16.checked = state_values[16]
            chk_17.checked = state_values[17]
            chk_18.checked = state_values[18]
            chk_19.checked = state_values[19]
            chk_20.checked = state_values[20]
            chk_21.checked = state_values[21]
        )

        ui_is_loading = previous_loading_state
        updateProgress()
        true
        -- return
    )

    /*
    Saves the current visible checklist into the active scene block.
    */
    function saveUiState =
    (
        if ui_is_loading then
        (
            false
        )
        else
        (
            save_ok = checklist_model.setCurrentPresetState (getUiState())
            updateProgress()
            save_ok
        )
        -- return
    )

    /*
    Toggles one two-state native checkbox from its .NET label click.
    */
    function toggleChecklistCheckbox checkbox_control =
    (
        previous_loading_state = ui_is_loading
        ui_is_loading = true
        checkbox_control.checked = not checkbox_control.checked
        ui_is_loading = previous_loading_state
        saveUiState()
        true
        -- return
    )

    /*
    Reloads block names, active selection, and active checklist from scene data.
    */
    function refreshUi =
    (
        previous_loading_state = ui_is_loading
        ui_is_loading = true
        preset_names = checklist_model.getPresetNames()
        active_index = checklist_model.getActivePresetIndex()
        ddl_blocks.items = preset_names
        ddl_blocks.selection = active_index
        setUiState (checklist_model.getCurrentPresetState())
        ui_is_loading = previous_loading_state
        true
        -- return
    )

    /*
    Reloads the newest versioned Wall Cleaner Checklist script from this folder.
    */
    function restartChecklist =
    (
        source_file = wall_cleaner_checklist_source_file

        if (source_file == undefined or source_file == "") then
        (
            messageBox "The current script path is unavailable." title:wall_cleaner_checklist_title
            false
        )
        else
        (
            source_folder = getFilenamePath source_file
            candidate_files = getFiles (source_folder + "Wall-Cleaner-Checklist_*.ms")
            newest_file = source_file
            newest_version = wall_cleaner_checklist_file_version

            for candidate_file in candidate_files do
            (
                candidate_name = getFilenameFile candidate_file
                name_parts = filterString candidate_name "_"

                if name_parts.count > 1 then
                (
                    candidate_version = name_parts[name_parts.count] as float

                    if candidate_version > newest_version then
                    (
                        newest_version = candidate_version
                        newest_file = candidate_file
                    )
                )
            )

            fileIn newest_file
            true
        )
        -- return
    )

    on wall_cleaner_checklist_rollout open do
    (
        initializeChecklistLabelStyles()
        refreshUi()
    )

    on ddl_blocks selected selected_index do
    (
        if not ui_is_loading then
        (
            checklist_model.setActivePresetIndex selected_index
            setUiState (checklist_model.getCurrentPresetState())
        )
    )

    on btn_new_block pressed do
    (
        suggested_name = checklist_model.getSuggestedPresetName()
        new_name = wallCleanerAskString "New block name:" default_value:suggested_name

        if new_name != undefined then
        (
            if checklist_model.addPreset new_name then
            (
                refreshUi()
            )
            else
            (
                messageBox "Block name is empty or already exists." title:wall_cleaner_checklist_title
            )
        )
    )

    on btn_rename_block pressed do
    (
        preset_names = checklist_model.getPresetNames()
        active_index = checklist_model.getActivePresetIndex()
        new_name = wallCleanerAskString "Rename active block:" default_value:preset_names[active_index]

        if new_name != undefined then
        (
            if checklist_model.renameActivePreset new_name then
            (
                refreshUi()
            )
            else
            (
                messageBox "Block name is empty or already exists." title:wall_cleaner_checklist_title
            )
        )
    )

    on btn_delete_block pressed do
    (
        preset_names = checklist_model.getPresetNames()
        active_index = checklist_model.getActivePresetIndex()

        if preset_names.count <= 1 then
        (
            messageBox "At least one block must remain." title:wall_cleaner_checklist_title
        )
        else if queryBox ("Delete block '" + preset_names[active_index] + "' and its checklist state?") title:wall_cleaner_checklist_title then
        (
            checklist_model.deleteActivePreset()
            refreshUi()
        )
    )

    on btn_reset_block pressed do
    (
        if queryBox "Clear every checklist item in the active block?" title:wall_cleaner_checklist_title then
        (
            checklist_model.resetActivePreset()
            refreshUi()
        )
    )

    on btn_restart pressed do
    (
        restartChecklist()
    )


    on lbl_01 Click sender event_args do (toggleChecklistCheckbox chk_01)
    on lbl_02 Click sender event_args do (toggleChecklistCheckbox chk_02)
    on lbl_03 Click sender event_args do (toggleChecklistCheckbox chk_03)
    on lbl_04 Click sender event_args do (toggleChecklistCheckbox chk_04)
    on lbl_05 Click sender event_args do (toggleChecklistCheckbox chk_05)
    on lbl_06 Click sender event_args do (toggleChecklistCheckbox chk_06)
    on lbl_07 Click sender event_args do (toggleChecklistCheckbox chk_07)
    on lbl_08 Click sender event_args do (toggleChecklistCheckbox chk_08)
    on lbl_09 Click sender event_args do (toggleChecklistCheckbox chk_09)
    on lbl_10 Click sender event_args do (toggleChecklistCheckbox chk_10)
    on lbl_11 Click sender event_args do (toggleChecklistCheckbox chk_11)
    on lbl_12 Click sender event_args do (toggleChecklistCheckbox chk_12)
    on lbl_13 Click sender event_args do (toggleChecklistCheckbox chk_13)
    on lbl_14 Click sender event_args do (toggleChecklistCheckbox chk_14)
    on lbl_15 Click sender event_args do (toggleChecklistCheckbox chk_15)
    on lbl_16 Click sender event_args do (toggleChecklistCheckbox chk_16)
    on lbl_17 Click sender event_args do (toggleChecklistCheckbox chk_17)
    on lbl_18 Click sender event_args do (toggleChecklistCheckbox chk_18)
    on lbl_19 Click sender event_args do (toggleChecklistCheckbox chk_19)
    on lbl_20 Click sender event_args do (toggleChecklistCheckbox chk_20)
    on lbl_21 Click sender event_args do (toggleChecklistCheckbox chk_21)

    on chk_01 changed state do (saveUiState())
    on chk_02 changed state do (saveUiState())
    on chk_03 changed state do (saveUiState())
    on chk_04 changed state do (saveUiState())
    on chk_05 changed state do (saveUiState())
    on chk_06 changed state do (saveUiState())
    on chk_07 changed state do (saveUiState())
    on chk_08 changed state do (saveUiState())
    on chk_09 changed state do (saveUiState())
    on chk_10 changed state do (saveUiState())
    on chk_11 changed state do (saveUiState())
    on chk_12 changed state do (saveUiState())
    on chk_13 changed state do (saveUiState())
    on chk_14 changed state do (saveUiState())
    on chk_15 changed state do (saveUiState())
    on chk_16 changed state do (saveUiState())
    on chk_17 changed state do (saveUiState())
    on chk_18 changed state do (saveUiState())
    on chk_19 changed state do (saveUiState())
    on chk_20 changed state do (saveUiState())
    on chk_21 changed state do (saveUiState())
)

/*
Opens the Wall Cleaner Checklist rollout as a single dialog.
*/
function openWallCleanerChecklist =
(
    try (destroyDialog wall_cleaner_checklist_rollout) catch ()
    createDialog wall_cleaner_checklist_rollout width:384 height:900 lockWidth:true lockHeight:true
    windows.processPostedMessages()
    true
    -- return
)

/*
Checks scene-persistence data shape without changing any checklist values.
*/
function testWallCleanerChecklistPersistence =
(
    preset_names = WallCleanerChecklist.getPresetNames()
    preset_states = WallCleanerChecklist.getPresetStates()
    active_index = WallCleanerChecklist.getActivePresetIndex()
    states_ok = true

    for state_values in preset_states while states_ok do
    (
        if (state_values == undefined or classOf state_values != Array or state_values.count != WallCleanerChecklist.item_count) then
        (
            states_ok = false
        )
    )

    test_ok = \
        preset_names.count > 0 and \
        preset_states.count == preset_names.count and \
        active_index >= 1 and \
        active_index <= preset_names.count and \
        states_ok

    format "Wall Cleaner Checklist test | presets:% | states:% | items:% | active:% | ok:%\n" \
        preset_names.count preset_states.count WallCleanerChecklist.item_count active_index test_ok

    test_ok
    -- return
)

/*
Checks the public model and rollout callbacks that previously failed as undefined calls.
*/
function testWallCleanerChecklistApi =
(
    model_ready = WallCleanerChecklist != undefined
    active_method_ready = model_ready and isProperty WallCleanerChecklist #getActivePresetIndex
    names_method_ready = model_ready and isProperty WallCleanerChecklist #getPresetNames
    rollout_ready = wall_cleaner_checklist_rollout != undefined
    progress_method_ready = rollout_ready and isProperty wall_cleaner_checklist_rollout #updateProgress
    test_ok = active_method_ready and names_method_ready and progress_method_ready

    if test_ok then
    (
        active_index = WallCleanerChecklist.getActivePresetIndex()
        preset_names = WallCleanerChecklist.getPresetNames()
        progress_count = wall_cleaner_checklist_rollout.updateProgress()
        test_ok = active_index >= 1 and active_index <= preset_names.count and progress_count >= 0
    )

    format "Wall Cleaner Checklist API test | model:% | active:% | names:% | progress:% | ok:%\n" \
        model_ready active_method_ready names_method_ready progress_method_ready test_ok

    test_ok
    -- return
)

/*
Checks that checklist UI exposes .NET labels and only Boolean two-state checkbox values.
*/
function testWallCleanerChecklistUi =
(
    rollout_ready = wall_cleaner_checklist_rollout != undefined
    labels_ready = rollout_ready and isProperty wall_cleaner_checklist_rollout #lbl_01 and isProperty wall_cleaner_checklist_rollout #lbl_21
    state_values = if rollout_ready then wall_cleaner_checklist_rollout.getUiState() else #()
    two_state_ok = state_values.count == 21

    for state_value in state_values while two_state_ok do
    (
        if not (state_value == true or state_value == false) then
        (
            two_state_ok = false
        )
    )

    test_ok = labels_ready and two_state_ok

    format "Wall Cleaner Checklist UI test | labels:% | two-state:% | ok:%\n" labels_ready two_state_ok test_ok

    test_ok
    -- return
)

/*
Tests migration from the legacy 0.01 22-item checklist without changing scene data.
*/
function testWallCleanerChecklistMigration =
(
    legacy_state = #()

    for item_index = 1 to 22 do
    (
        append legacy_state false
    )

    legacy_state[1] = true
    legacy_state[18] = true
    legacy_state[20] = true
    legacy_state[21] = true
    legacy_state[22] = true

    migrated_state = WallCleanerChecklist.normalizeStateValues legacy_state

    test_ok = \
        migrated_state != undefined and \
        migrated_state.count == 21 and \
        migrated_state[1] == true and \
        migrated_state[17] == false and \
        migrated_state[18] == true and \
        migrated_state[19] == true and \
        migrated_state[20] == true and \
        migrated_state[21] == true

    format "Wall Cleaner Checklist migration test | legacy:22 | current:% | ok:%\n" \
        WallCleanerChecklist.item_count test_ok

    test_ok
    -- return
)

openWallCleanerChecklist()
