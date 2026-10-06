/*
Preset-Manager sandbox Tool backend.
File version: 0.02
Project version: 0.02
*/


global preset_manager_project_version
global preset_manager_tool_fn_file_version = 0.02
global preset_manager_tool_fn_stored_project_version = 0.02


if preset_manager_project_version == undefined or preset_manager_tool_fn_stored_project_version > preset_manager_project_version then
(
    preset_manager_project_version = preset_manager_tool_fn_stored_project_version
)


struct PresetManagerSelfTestResult_v
(
    passed = false,
    message = ""
)


struct PresetManagerTool_v
(
    file_version = 0.02,
    project_version = 0.02,
    ini_path = "",
    section_prefix = "SandboxPreset",
    last_message = "Ready.",


    /*
    Configures the sandbox Tool storage file without binding the backend to rollout controls.
    */
    function configure ini_path_value =
    (
        if classOf ini_path_value != String or ini_path_value == "" then return false


        ini_path = ini_path_value
        true
        -- return
    ),


    /*
    Finds one value by key in a generic preset entry array.
    */
    function findEntryValue entries key_name =
    (
        local found_value = undefined


        if classOf entries == Array and classOf key_name == String then
        (
            for entry_value in entries while found_value == undefined do
            (
                if classOf entry_value == Array and entry_value.count == 2 and entry_value[1] == key_name then
                (
                    found_value = entry_value[2]
                )
            )
        )


        found_value
        -- return
    ),


    /*
    Compares two generic preset entry arrays without depending on array deep-equality behavior.
    */
    function entriesEqual first_entries second_entries =
    (
        local entries_equal = classOf first_entries == Array and classOf second_entries == Array


        if entries_equal and first_entries.count != second_entries.count then
        (
            entries_equal = false
        )


        if entries_equal then
        (
            for first_entry in first_entries while entries_equal do
            (
                if classOf first_entry != Array or first_entry.count != 2 then
                (
                    entries_equal = false
                )
                else
                (
                    local second_value = findEntryValue second_entries first_entry[1]


                    if second_value == undefined or second_value != first_entry[2] then
                    (
                        entries_equal = false
                    )
                )
            )
        )


        entries_equal
        -- return
    ),


    /*
    Returns the current sandbox preset names from the reusable Operation.
    */
    function getPresetNames =
    (
        if ini_path == "" then return #()


        PresetManager.getPresetNames ini_path section_prefix:section_prefix
        -- return
    ),


    /*
    Returns whether one sandbox preset exists.
    */
    function hasPreset preset_name =
    (
        if ini_path == "" then return false


        PresetManager.hasPreset ini_path preset_name section_prefix:section_prefix
        -- return
    ),


    /*
    Encodes the sandbox controls as generic string data and saves one preset.
    */
    function saveSandboxPreset preset_name enabled_state amount_value mode_index text_value =
    (
        local entries = #()
        local save_ok = false


        if ini_path == "" then return false
        if enabled_state != true and enabled_state != false then return false
        if classOf amount_value != Float and classOf amount_value != Integer then return false
        if classOf mode_index != Integer then return false
        if classOf text_value != String then return false


        entries = #(
            #("Enabled", if enabled_state then "true" else "false"),
            #("Amount", amount_value as string),
            #("Mode", mode_index as string),
            #("Value", text_value)
        )


        save_ok = PresetManager.savePreset ini_path preset_name entries section_prefix:section_prefix
        last_message = if save_ok then ("Saved preset: " + preset_name) else ("Could not save preset: " + preset_name)


        save_ok
        -- return
    ),


    /*
    Decodes one sandbox preset into Enabled, Amount, Mode, and Value values.
    */
    function loadSandboxPreset preset_name =
    (
        local entries = undefined
        local enabled_text = undefined
        local amount_text = undefined
        local mode_text = undefined
        local value_text = undefined
        local enabled_value = false
        local amount_value = undefined
        local mode_value = undefined
        local decoded_values = undefined


        if ini_path == "" then return undefined


        entries = PresetManager.loadPreset ini_path preset_name section_prefix:section_prefix
        if entries == undefined then return undefined


        enabled_text = findEntryValue entries "Enabled"
        amount_text = findEntryValue entries "Amount"
        mode_text = findEntryValue entries "Mode"
        value_text = findEntryValue entries "Value"


        if enabled_text == undefined or amount_text == undefined or mode_text == undefined or value_text == undefined then
        (
            last_message = "Preset is missing one or more sandbox values."
            return undefined
        )


        if toLower enabled_text == "true" then
        (
            enabled_value = true
         else if toLower enabled_text == "false" then
        (
            enabled_value = false
        )
        else
        (
            last_message = "Preset contains an invalid Enabled value."
            return undefined
        )


        try
        (
            amount_value = amount_text as float
            mode_value = mode_text as integer
        )
        catch
        (
            local exception_text = getCurrentException()
            format "Preset Manager Tool: preset decode failed: %\n" exception_text
            last_message = "Preset contains invalid numeric values."
            amount_value = undefined
            mode_value = undefined
        )


        if amount_value == undefined or mode_value == undefined then return undefined
        if mode_value < 1 or mode_value > 3 then
        (
            last_message = "Preset contains an invalid Mode value."
            return undefined
        )


        decoded_values = #(enabled_value, amount_value, mode_value, value_text)
        last_message = "Loaded preset: " + preset_name


        decoded_values
        -- return
    ),


    /*
    Renames one sandbox preset without overwriting a different existing preset.
    */
    function renameSandboxPreset old_preset_name new_preset_name =
    (
        local rename_ok = false


        if ini_path == "" then return false


        rename_ok = PresetManager.renamePreset ini_path old_preset_name new_preset_name section_prefix:section_prefix
        last_message = if rename_ok then ("Renamed preset: " + old_preset_name + " -> " + new_preset_name) else ("Could not rename preset: " + old_preset_name)


        rename_ok
        -- return
    ),


    /*
    Removes one sandbox preset through the reusable Operation.
    */
    function removeSandboxPreset preset_name =
    (
        local remove_ok = false


        if ini_path == "" then return false


        remove_ok = PresetManager.removePreset ini_path preset_name section_prefix:section_prefix
        last_message = if remove_ok then ("Removed preset: " + preset_name) else ("Could not remove preset: " + preset_name)


        remove_ok
        -- return
    ),


    /*
    Runs a complete non-destructive preset workflow test and removes all self-test data before returning.
    */
    function runSelfTest =
    (
        local test_result = PresetManagerSelfTestResult_v()
        local test_name = "__PRESET_MANAGER_SELF_TEST__"
        local renamed_test_name = "__PRESET_MANAGER_SELF_TEST_RENAMED__"
        local wrapper_renamed_name = "__PRESET_MANAGER_SELF_TEST_WRAPPER_RENAMED__"
        local generic_prefix = "PresetManagerSelfTest"
        local first_entries = #(#("Alpha", "one"), #("Beta", "two"))
        local second_entries = #(#("Alpha", "updated"))
        local loaded_entries = undefined
        local preset_names = #()
        local test_ok = true
        local wrapper_values = undefined


        if ini_path == "" then
        (
            test_result.message = "Self test cannot run before the Tool storage path is configured."
            return test_result
        )


        if PresetManager.hasPreset ini_path test_name section_prefix:generic_prefix then
        (
            PresetManager.removePreset ini_path test_name section_prefix:generic_prefix
        )


        if PresetManager.hasPreset ini_path renamed_test_name section_prefix:generic_prefix then
        (
            PresetManager.removePreset ini_path renamed_test_name section_prefix:generic_prefix
        )


        if hasPreset test_name then
        (
            removeSandboxPreset test_name
        )


        if hasPreset wrapper_renamed_name then
        (
            removeSandboxPreset wrapper_renamed_name
        )


        if not PresetManager.savePreset ini_path test_name first_entries section_prefix:generic_prefix then test_ok = false
        if test_ok and not PresetManager.hasPreset ini_path test_name section_prefix:generic_prefix then test_ok = false


        if test_ok then
        (
            preset_names = PresetManager.getPresetNames ini_path section_prefix:generic_prefix
            if findItem preset_names test_name == 0 then test_ok = false
        )


        if test_ok then
        (
            loaded_entries = PresetManager.loadPreset ini_path test_name section_prefix:generic_prefix
            if loaded_entries == undefined or not entriesEqual loaded_entries first_entries then test_ok = false
        )


        if test_ok and not PresetManager.savePreset ini_path test_name second_entries section_prefix:generic_prefix then test_ok = false


        if test_ok then
        (
            loaded_entries = PresetManager.loadPreset ini_path test_name section_prefix:generic_prefix
            if loaded_entries == undefined or not entriesEqual loaded_entries second_entries then test_ok = false
        )


        if test_ok and not PresetManager.renamePreset ini_path test_name renamed_test_name section_prefix:generic_prefix then test_ok = false
        if test_ok and PresetManager.hasPreset ini_path test_name section_prefix:generic_prefix then test_ok = false
        if test_ok and not PresetManager.hasPreset ini_path renamed_test_name section_prefix:generic_prefix then test_ok = false


        if test_ok then
        (
            loaded_entries = PresetManager.loadPreset ini_path renamed_test_name section_prefix:generic_prefix
            if loaded_entries == undefined or not entriesEqual loaded_entries second_entries then test_ok = false
        )


        if test_ok and not (PresetManager.renamePreset ini_path renamed_test_name renamed_test_name section_prefix:generic_prefix) then test_ok = false
        if test_ok and PresetManager.normalizePresetName "Bad|Name" != undefined then test_ok = false


        if test_ok and not saveSandboxPreset test_name true 12.5 3 "Sandbox self test" then test_ok = false
        if test_ok and not renameSandboxPreset test_name wrapper_renamed_name then test_ok = false
        if test_ok and hasPreset test_name then test_ok = false
        if test_ok and not hasPreset wrapper_renamed_name then test_ok = false


        if test_ok then
        (
            wrapper_values = loadSandboxPreset wrapper_renamed_name


            if wrapper_values == undefined then
            (
                test_ok = false
            )
            else if wrapper_values[1] != true or wrapper_values[2] != 12.5 or wrapper_values[3] != 3 or wrapper_values[4] != "Sandbox self test" then
            (
                test_ok = false
            )
        )


        if PresetManager.hasPreset ini_path renamed_test_name section_prefix:generic_prefix then
        (
            if not PresetManager.removePreset ini_path renamed_test_name section_prefix:generic_prefix then test_ok = false
        )


        if hasPreset wrapper_renamed_name then
        (
            if not removeSandboxPreset wrapper_renamed_name then test_ok = false
        )


        if PresetManager.hasPreset ini_path test_name section_prefix:generic_prefix then test_ok = false
        if PresetManager.hasPreset ini_path renamed_test_name section_prefix:generic_prefix then test_ok = false
        if hasPreset test_name then test_ok = false
        if hasPreset wrapper_renamed_name then test_ok = false


        test_result.passed = test_ok
        test_result.message = if test_ok then "SELF TEST PASS" else "SELF TEST FAIL - see Listener output."
        last_message = test_result.message


        format "Preset Manager self test | PASS:%\n" test_ok
        test_result
        -- return
    ),


    on create do
    (
    )
)


global PresetManagerTool
PresetManagerTool = PresetManagerTool_v()