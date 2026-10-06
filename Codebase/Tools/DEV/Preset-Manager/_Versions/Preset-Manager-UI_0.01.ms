/*
Preset-Manager sandbox Tool frontend.
File version: 0.01
Project version: 0.01
*/

global preset_manager_project_version
global preset_manager_tool_ui_file_version = 0.01
global preset_manager_tool_ui_stored_project_version = 0.01
global preset_manager_tool_rollout_title
global preset_manager_tool_rollout

if preset_manager_project_version == undefined or preset_manager_tool_ui_stored_project_version > preset_manager_project_version then
(
    preset_manager_project_version = preset_manager_tool_ui_stored_project_version
)

preset_manager_tool_rollout_title = "Preset Manager - v" + (formattedPrint preset_manager_project_version format:".2f")

rollout preset_manager_tool_rollout preset_manager_tool_rollout_title width:336 height:336
(
    dotNetControl btn_tool_title "System.Windows.Forms.Button" pos:[12,12] width:312 height:24

    dropdownlist ddl_presets "" pos:[12,42] width:192 height:24 items:#("<Preset>") selection:1 tooltip:"Select a named preset to restore the sandbox values."
    button btn_save_remove "SAVE \\ REMOVE" pos:[210,42] width:114 height:24 tooltip:"LMB: Save the current sandbox values as a named preset.\n\nRMB: Remove the preset selected in the dropdown."

    groupbox grp_values "SANDBOX VALUES" pos:[12,78] width:312 height:138
    checkbox chk_enabled "Enabled" pos:[24,102] width:132 height:24 checked:true
    spinner spn_amount "Amount" pos:[168,102] width:132 height:24 range:[0.0,100.0,1.0] type:#float fieldWidth:72
    dropdownlist ddl_mode "Mode" pos:[24,138] width:132 height:24 items:#("Mode A","Mode B","Mode C") selection:1
    edittext edt_value "Value" pos:[168,138] width:132 height:48 text:""

    button btn_run_test "RUN SELF TEST" pos:[12,228] width:312 height:24 tooltip:"Runs save, list, load, overwrite, validation, and remove checks without keeping a test preset."
    label lbl_status "Ready." pos:[12,264] width:312 height:48

    local updating_preset_dropdown = false

    /*
    Updates the visible status line from one concise message.
    */
    function setStatus message_text =
    (
        if classOf message_text == String then
        (
            lbl_status.text = message_text
        )

        true
        -- return
    )

    /*
    Saves only frontend state that is independent from named preset storage.
    */
    function saveUiState =
    (
        RolloutState.saveCheckbox chk_enabled preset_manager_tool_ini_path "MainUI" "Enabled"
        RolloutState.saveSpinner spn_amount preset_manager_tool_ini_path "MainUI" "Amount"
        RolloutState.saveDropdown ddl_mode preset_manager_tool_ini_path "MainUI" "Mode"
        RolloutState.saveEditText edt_value preset_manager_tool_ini_path "MainUI" "Value"
        true
        -- return
    )

    /*
    Restores the last sandbox values shown before the Tool was closed.
    */
    function loadUiState =
    (
        RolloutState.loadCheckbox chk_enabled preset_manager_tool_ini_path "MainUI" "Enabled" default_value:true
        RolloutState.loadSpinner spn_amount preset_manager_tool_ini_path "MainUI" "Amount" default_value:1.0
        RolloutState.loadDropdown ddl_mode preset_manager_tool_ini_path "MainUI" "Mode" default_value:1
        RolloutState.loadEditText edt_value preset_manager_tool_ini_path "MainUI" "Value" default_value:""
        true
        -- return
    )

    /*
    Returns the selected named preset or undefined for the neutral dropdown item.
    */
    function getSelectedPresetName =
    (
        if ddl_presets.selection <= 1 then return undefined
        if ddl_presets.selection > ddl_presets.items.count then return undefined

        ddl_presets.items[ddl_presets.selection]
        -- return
    )

    /*
    Refreshes the preset dropdown without allowing its selection callback to load a preset accidentally.
    */
    function refreshPresetDropdown preferred_name:undefined =
    (
        local preset_names = PresetManagerTool.getPresetNames()
        local dropdown_items = #("<Preset>")
        local selected_index = 1

        for preset_name in preset_names do
        (
            append dropdown_items preset_name
        )

        if preferred_name != undefined then
        (
            for item_index = 2 to dropdown_items.count while selected_index == 1 do
            (
                if dropdown_items[item_index] == preferred_name then selected_index = item_index
            )
        )

        updating_preset_dropdown = true
        ddl_presets.items = dropdown_items
        ddl_presets.selection = selected_index
        updating_preset_dropdown = false

        true
        -- return
    )

    /*
    Opens the standard 3ds Max rename dialog and returns a validated preset name or undefined when cancelled.
    */
    function askPresetName default_value:"" =
    (
        local dialog_value = dotNetObject "MaxCustomControls.RenameInstanceDialog" default_value
        local modal_result = undefined
        local preset_name = undefined

        dialog_value.text = "Save Preset"
        modal_result = dialog_value.ShowModal()
        preset_name = PresetManager.normalizePresetName dialog_value.InstanceName

        preset_name
        -- return
    )

    /*
    Applies one decoded sandbox preset to controls and persists the resulting frontend state.
    */
    function applyPresetValues preset_values =
    (
        if classOf preset_values != Array or preset_values.count != 4 then return false

        chk_enabled.checked = preset_values[1]
        spn_amount.value = preset_values[2]
        ddl_mode.selection = preset_values[3]
        edt_value.text = preset_values[4]
        saveUiState()

        true
        -- return
    )

    /*
    Keeps the title button and status width aligned to the locked dialog width.
    */
    function layoutDialog dialog_size =
    (
        local content_width = dialog_size.x - 24

        ToolTitleButton.resizeToolTitleButton btn_tool_title content_width
        lbl_status.width = content_width
        true
        -- return
    )

    on preset_manager_tool_rollout open do
    (
        ToolTitleButton.setupToolTitleButton btn_tool_title "Preset Manager"
        layoutDialog (getDialogSize preset_manager_tool_rollout)
        loadUiState()
        refreshPresetDropdown()
        setStatus PresetManagerTool.last_message
    )

    on preset_manager_tool_rollout moved dialog_pos do
    (
        DialogHost.saveDialogPosition preset_manager_tool_rollout preset_manager_tool_ini_path "MainUI"
    )

    on preset_manager_tool_rollout resized dialog_size do
    (
        layoutDialog dialog_size
        DialogHost.saveDialogHeight preset_manager_tool_rollout preset_manager_tool_ini_path "MainUI" min_height:312
    )

    on preset_manager_tool_rollout close do
    (
        saveUiState()
        DialogHost.saveDialogState preset_manager_tool_rollout preset_manager_tool_ini_path "MainUI" min_height:312
    )

    on btn_tool_title Click sender event_args do
    (
        restartTool preset_manager_tool_source_path "Preset-Manager"
    )

    on chk_enabled changed state do
    (
        saveUiState()
    )

    on spn_amount changed spinner_value do
    (
        saveUiState()
    )

    on ddl_mode selected item_index do
    (
        saveUiState()
    )

    on edt_value entered text_value do
    (
        saveUiState()
    )

    on btn_save_remove pressed do
    (
        local preset_name = askPresetName()
        local save_confirmed = true

        if preset_name == undefined then
        (
            setStatus "Preset save cancelled or the name is invalid."
        )
        else
        (
            if PresetManagerTool.hasPreset preset_name then
            (
                save_confirmed = queryBox ("Preset \"" + preset_name + "\" already exists. Replace it?") title:"Preset Manager"
            )

            if save_confirmed then
            (
                if PresetManagerTool.saveSandboxPreset preset_name chk_enabled.checked spn_amount.value ddl_mode.selection edt_value.text then
                (
                    refreshPresetDropdown preferred_name:preset_name
                )

                setStatus PresetManagerTool.last_message
            )
        )
    )

    on btn_save_remove rightclick do
    (
        local preset_name = getSelectedPresetName()
        local remove_confirmed = false

        if preset_name == undefined then
        (
            setStatus "Select a preset before removing it."
        )
        else
        (
            remove_confirmed = queryBox ("Remove preset \"" + preset_name + "\"?") title:"Preset Manager"

            if remove_confirmed then
            (
                PresetManagerTool.removeSandboxPreset preset_name
                refreshPresetDropdown()
                setStatus PresetManagerTool.last_message
            )
        )
    )

    on ddl_presets selected item_index do
    (
        if not updating_preset_dropdown then
        (
            local preset_name = getSelectedPresetName()
            local load_confirmed = false
            local preset_values = undefined

            if preset_name != undefined then
            (
                load_confirmed = queryBox ("Load preset \"" + preset_name + "\"?") title:"Preset Manager"

                if load_confirmed then
                (
                    preset_values = PresetManagerTool.loadSandboxPreset preset_name

                    if preset_values != undefined then
                    (
                        applyPresetValues preset_values
                    )

                    setStatus PresetManagerTool.last_message
                )
                else
                (
                    refreshPresetDropdown()
                )
            )
        )
    )

    on btn_run_test pressed do
    (
        local test_result = PresetManagerTool.runSelfTest()

        refreshPresetDropdown()
        setStatus test_result.message
    )
)
