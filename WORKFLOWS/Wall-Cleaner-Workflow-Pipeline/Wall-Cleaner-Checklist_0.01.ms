/*
Wall Cleaner pipeline checklist with per-block scene persistence.
File version: 0.01
Project version: 0.01
*/

global wall_cleaner_checklist_file_version = 0.01
global wall_cleaner_checklist_project_version
global wall_cleaner_checklist_title
global wall_cleaner_checklist_source_file
global WallCleanerChecklist
global wall_cleaner_checklist_rollout

if (wall_cleaner_checklist_project_version == undefined or wall_cleaner_checklist_project_version < 0.01) then
(
    wall_cleaner_checklist_project_version = 0.01
)

wall_cleaner_checklist_title = "Wall Cleaner Checklist " + (wall_cleaner_checklist_project_version as string)
wall_cleaner_checklist_source_file = getSourceFileName()

struct WallCleanerChecklist_v
(
    file_version = 0.01,
    project_version = 0.01,
    data_node_name = "__WALL_CLEANER_CHECKLIST_DATA__",
    data_node_marker_key = "WCC_DATA_NODE",
    preset_names_key = "WCC_PRESET_NAMES",
    preset_states_key = "WCC_PRESET_STATES",
    active_preset_key = "WCC_ACTIVE_PRESET",
    item_count = 22,

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

                if (candidate_state != undefined and classOf candidate_state == Array and candidate_state.count == item_count) then
                (
                    state_values = copy candidate_state
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

rollout wall_cleaner_checklist_rollout wall_cleaner_checklist_title width:384 height:924
(
    local ui_is_loading = false

    groupBox grp_model_setup "MODEL SETUP" pos:[12,12] width:360 height:108
    dropdownList ddl_blocks "Block:" pos:[24,36] width:336 height:24 items:#("Block A") selection:1
    button btn_new_block "NEW" pos:[24,72] width:96 height:24 \
        toolTip:"Create a new block with an empty checklist."
    button btn_rename_block "RENAME" pos:[132,72] width:96 height:24 \
        toolTip:"Rename the active block without changing its checklist state."
    button btn_delete_block "DELETE" pos:[240,72] width:96 height:24 \
        toolTip:"Delete the active block and its saved checklist state."

    groupBox grp_preprocess "PRE-PROCESS" pos:[12,132] width:360 height:96
    checkbox chk_01 "CHECK / FIX ORTHO" pos:[24,156] width:336 height:20
    checkbox chk_02 "CHECK HORIZONTAL / VERTICAL EDGES" pos:[24,180] width:336 height:20
    checkbox chk_03 "EXPLODE WALLS" pos:[24,204] width:336 height:20

    groupBox grp_slicing "SLICING / TOPOLOGY CLEANUP" pos:[12,240] width:360 height:144
    checkbox chk_04 "SLICE HORIZONTAL / VERTICAL" pos:[24,264] width:336 height:20
    checkbox chk_05 "SLICE CLEANUP" pos:[24,288] width:336 height:20
    checkbox chk_06 "2-EDGE VERTS FIX" pos:[48,312] width:312 height:20
    checkbox chk_07 "DEGENERATE FACES FIX" pos:[48,336] width:312 height:20
    checkbox chk_08 "SELECT + WELD BORDER" pos:[48,360] width:312 height:20

    groupBox grp_extrude_prepare "EXTRUDE PREPARE" pos:[12,396] width:360 height:216
    checkbox chk_09 "ATTACH WALLS TO ONE OBJECT" pos:[24,420] width:336 height:20
    checkbox chk_10 "FLOORS — ASSIGN MATERIAL ID PER FLOOR" pos:[24,444] width:336 height:20
    checkbox chk_11 "DETACH BY FLOOR" pos:[24,468] width:336 height:20
    checkbox chk_12 "CORNER CLEANUP / MATCH WALL TOPOLOGY PER FLOOR" pos:[24,492] width:336 height:20
    checkbox chk_13 "REBUILD MESH" pos:[24,516] width:336 height:20
    checkbox chk_14 "EXTRUDE SOURCE CHECK" pos:[24,540] width:336 height:20
    checkbox chk_15 "ASSIGN EXTRUDE MATERIAL GROUPS" pos:[24,564] width:336 height:20
    checkbox chk_16 "EXPLODE BY MATERIAL" pos:[24,588] width:336 height:20

    groupBox grp_extrude_walls "EXTRUDE WALLS" pos:[12,624] width:360 height:120
    checkbox chk_17 "BORDER CORNER CHECK" pos:[24,648] width:336 height:20
    checkbox chk_18 "WALLS EXTRUDE" pos:[24,672] width:336 height:20
    checkbox chk_19 "CHECK EXTRUSION" pos:[24,696] width:336 height:20
    checkbox chk_20 "FINISH WALLS — FIX CORNERS" pos:[24,720] width:336 height:20

    groupBox grp_postprocess "POST-PROCESS CHECK" pos:[12,756] width:360 height:60
    checkbox chk_21 "STL CHECK" pos:[24,780] width:336 height:20

    groupBox grp_ready "READY" pos:[12,828] width:360 height:48
    checkbox chk_22 "READY" pos:[24,850] width:144 height:20
    label lbl_progress "0 / 22 complete" pos:[192,850] width:168 height:20

    button btn_reset_block "RESET BLOCK" pos:[12,888] width:120 height:24 \
        toolTip:"Clear every checklist item only in the active block."
    button btn_restart "RESTART" pos:[252,888] width:120 height:24 \
        toolTip:"Reload the newest Wall Cleaner Checklist script from this script folder."

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
            chk_21.checked,
            chk_22.checked
        )
        -- return
    )

    /*
    Applies one persistent checklist state to all visible checkboxes.
    */
    function setUiState state_values =
    (
        previous_loading_state = ui_is_loading
        ui_is_loading = true

        if (state_values != undefined and classOf state_values == Array and state_values.count == 22) then
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
            chk_22.checked = state_values[22]
        )

        ui_is_loading = previous_loading_state
        updateProgress()
        true
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

        lbl_progress.text = (completed_count as string) + " / 22 complete"
        completed_count
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
            save_ok = WallCleanerChecklist.setCurrentPresetState (getUiState())
            updateProgress()
            save_ok
        )
        -- return
    )

    /*
    Reloads block names, active selection, and active checklist from scene data.
    */
    function refreshUi =
    (
        previous_loading_state = ui_is_loading
        ui_is_loading = true
        preset_names = WallCleanerChecklist.getPresetNames()
        active_index = WallCleanerChecklist.getActivePresetIndex()
        ddl_blocks.items = preset_names
        ddl_blocks.selection = active_index
        setUiState (WallCleanerChecklist.getCurrentPresetState())
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
        refreshUi()
    )

    on ddl_blocks selected selected_index do
    (
        if not ui_is_loading then
        (
            WallCleanerChecklist.setActivePresetIndex selected_index
            setUiState (WallCleanerChecklist.getCurrentPresetState())
        )
    )

    on btn_new_block pressed do
    (
        suggested_name = WallCleanerChecklist.getSuggestedPresetName()
        new_name = getString "New block name:" default:suggested_name

        if new_name != undefined then
        (
            if WallCleanerChecklist.addPreset new_name then
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
        preset_names = WallCleanerChecklist.getPresetNames()
        active_index = WallCleanerChecklist.getActivePresetIndex()
        new_name = getString "Rename active block:" default:preset_names[active_index]

        if new_name != undefined then
        (
            if WallCleanerChecklist.renameActivePreset new_name then
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
        preset_names = WallCleanerChecklist.getPresetNames()
        active_index = WallCleanerChecklist.getActivePresetIndex()

        if preset_names.count <= 1 then
        (
            messageBox "At least one block must remain." title:wall_cleaner_checklist_title
        )
        else if queryBox ("Delete block '" + preset_names[active_index] + "' and its checklist state?") title:wall_cleaner_checklist_title then
        (
            WallCleanerChecklist.deleteActivePreset()
            refreshUi()
        )
    )

    on btn_reset_block pressed do
    (
        if queryBox "Clear every checklist item in the active block?" title:wall_cleaner_checklist_title then
        (
            WallCleanerChecklist.resetActivePreset()
            refreshUi()
        )
    )

    on btn_restart pressed do
    (
        restartChecklist()
    )

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
    on chk_22 changed state do (saveUiState())
)

/*
Opens the Wall Cleaner Checklist rollout as a single dialog.
*/
function openWallCleanerChecklist =
(
    try (destroyDialog wall_cleaner_checklist_rollout) catch ()
    createDialog wall_cleaner_checklist_rollout width:384 height:924 lockWidth:true lockHeight:true
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
    test_ok = \
        preset_names.count > 0 and \
        preset_states.count == preset_names.count and \
        active_index >= 1 and \
        active_index <= preset_names.count

    format "Wall Cleaner Checklist test | presets:% | states:% | active:% | ok:%\n" \
        preset_names.count preset_states.count active_index test_ok

    test_ok
    -- return
)

openWallCleanerChecklist()
