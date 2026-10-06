/*
Preset-Manager reusable Operation.
File version: 0.01
Project version: 0.01
*/

global preset_manager_project_version
global preset_manager_operation_file_version = 0.01
global preset_manager_operation_stored_project_version = 0.01

if preset_manager_project_version == undefined or preset_manager_operation_stored_project_version > preset_manager_project_version then
(
    preset_manager_project_version = preset_manager_operation_stored_project_version
)

struct PresetManager_v
(
    file_version = 0.01,
    project_version = 0.01,
    reserved_format_key = "__PresetManagerFormat",
    preset_format_version = "1",

    /*
    Normalizes one preset name and rejects characters that would make INI section names ambiguous.
    */
    function normalizePresetName preset_name =
    (
        local normalized_name = undefined

        if classOf preset_name == String then
        (
            normalized_name = trimRight (trimLeft preset_name)

            if normalized_name == "" then normalized_name = undefined
            if normalized_name != undefined and findString normalized_name "[" != undefined then normalized_name = undefined
            if normalized_name != undefined and findString normalized_name "]" != undefined then normalized_name = undefined
            if normalized_name != undefined and findString normalized_name "|" != undefined then normalized_name = undefined
            if normalized_name != undefined and findString normalized_name "\r" != undefined then normalized_name = undefined
            if normalized_name != undefined and findString normalized_name "\n" != undefined then normalized_name = undefined
        )

        normalized_name
        -- return
    ),

    /*
    Validates one section prefix used to isolate a caller's preset namespace.
    */
    function normalizeSectionPrefix section_prefix =
    (
        local normalized_prefix = undefined

        if classOf section_prefix == String then
        (
            normalized_prefix = trimRight (trimLeft section_prefix)

            if normalized_prefix == "" then normalized_prefix = undefined
            if normalized_prefix != undefined and findString normalized_prefix "[" != undefined then normalized_prefix = undefined
            if normalized_prefix != undefined and findString normalized_prefix "]" != undefined then normalized_prefix = undefined
            if normalized_prefix != undefined and findString normalized_prefix "|" != undefined then normalized_prefix = undefined
            if normalized_prefix != undefined and findString normalized_prefix "\r" != undefined then normalized_prefix = undefined
            if normalized_prefix != undefined and findString normalized_prefix "\n" != undefined then normalized_prefix = undefined
        )

        normalized_prefix
        -- return
    ),

    /*
    Builds the complete INI section name for one preset.
    */
    function getPresetSectionName preset_name section_prefix:"Preset" =
    (
        local normalized_name = normalizePresetName preset_name
        local normalized_prefix = normalizeSectionPrefix section_prefix

        if normalized_name == undefined or normalized_prefix == undefined then return undefined

        normalized_prefix + "|" + normalized_name
        -- return
    ),

    /*
    Returns true when one section belongs to the requested preset namespace.
    */
    function isPresetSectionName section_name section_prefix:"Preset" =
    (
        local normalized_prefix = normalizeSectionPrefix section_prefix
        local prefix_text = undefined
        local matches_section = false

        if classOf section_name == String and normalized_prefix != undefined then
        (
            prefix_text = normalized_prefix + "|"

            if section_name.count > prefix_text.count then
            (
                matches_section = (substring section_name 1 prefix_text.count) == prefix_text
            )
        )

        matches_section
        -- return
    ),

    /*
    Validates an array of string key/value pairs accepted by the generic preset store.
    */
    function validateEntries entries =
    (
        local entries_valid = classOf entries == Array

        if entries_valid then
        (
            for entry_value in entries while entries_valid do
            (
                if classOf entry_value != Array or entry_value.count != 2 then
                (
                    entries_valid = false
                )
                else if classOf entry_value[1] != String or classOf entry_value[2] != String then
                (
                    entries_valid = false
                )
                else if entry_value[1] == "" or entry_value[1] == reserved_format_key then
                (
                    entries_valid = false
                )
                else if findString entry_value[1] "=" != undefined or findString entry_value[1] "\r" != undefined or findString entry_value[1] "\n" != undefined then
                (
                    entries_valid = false
                )
            )
        )

        entries_valid
        -- return
    ),

    /*
    Reads all user-owned key/value pairs from one preset section while hiding internal format metadata.
    */
    function getSectionEntries ini_path section_name =
    (
        local entries = #()
        local key_names = #()

        if classOf ini_path != String or ini_path == "" then return entries
        if classOf section_name != String or section_name == "" then return entries

        key_names = getINISetting ini_path section_name

        for key_name in key_names do
        (
            if key_name != reserved_format_key then
            (
                append entries #(key_name, getINISetting ini_path section_name key_name)
            )
        )

        entries
        -- return
    ),

    /*
    Replaces one complete preset section and removes stale keys from older values.
    */
    function replaceSection ini_path section_name entries =
    (
        local write_ok = false

        if classOf ini_path != String or ini_path == "" then return false
        if classOf section_name != String or section_name == "" then return false
        if not validateEntries entries then return false

        delIniSetting ini_path section_name
        write_ok = setINISetting ini_path section_name reserved_format_key preset_format_version

        if write_ok then
        (
            for entry_value in entries while write_ok do
            (
                write_ok = setINISetting ini_path section_name entry_value[1] entry_value[2]
            )
        )

        if not write_ok then
        (
            delIniSetting ini_path section_name
        )

        write_ok
        -- return
    ),

    /*
    Returns all valid named presets in one caller namespace, sorted alphabetically.
    */
    function getPresetNames ini_path section_prefix:"Preset" =
    (
        local preset_names = #()
        local section_names = #()
        local normalized_prefix = normalizeSectionPrefix section_prefix
        local prefix_text = undefined

        if classOf ini_path != String or ini_path == "" then return preset_names
        if normalized_prefix == undefined then return preset_names

        prefix_text = normalized_prefix + "|"
        section_names = getINISetting ini_path

        for section_name in section_names do
        (
            if isPresetSectionName section_name section_prefix:normalized_prefix then
            (
                if getINISetting ini_path section_name reserved_format_key == preset_format_version then
                (
                    append preset_names (substring section_name (prefix_text.count + 1) (section_name.count - prefix_text.count))
                )
            )
        )

        sort preset_names
        preset_names
        -- return
    ),

    /*
    Returns whether one valid preset exists in the requested namespace.
    */
    function hasPreset ini_path preset_name section_prefix:"Preset" =
    (
        local section_name = getPresetSectionName preset_name section_prefix:section_prefix

        if classOf ini_path != String or ini_path == "" then return false
        if section_name == undefined then return false

        getINISetting ini_path section_name reserved_format_key == preset_format_version
        -- return
    ),

    /*
    Saves or replaces one named preset and restores the previous preset if the replacement write fails.
    */
    function savePreset ini_path preset_name entries section_prefix:"Preset" =
    (
        local section_name = getPresetSectionName preset_name section_prefix:section_prefix
        local previous_exists = false
        local previous_entries = #()
        local save_ok = false
        local rollback_ok = true

        if classOf ini_path != String or ini_path == "" then return false
        if section_name == undefined then return false
        if not validateEntries entries then return false

        previous_exists = hasPreset ini_path preset_name section_prefix:section_prefix

        if previous_exists then
        (
            previous_entries = getSectionEntries ini_path section_name
        )

        save_ok = replaceSection ini_path section_name entries

        if not save_ok and previous_exists then
        (
            rollback_ok = replaceSection ini_path section_name previous_entries

            if not rollback_ok then
            (
                format "Preset Manager: failed to restore preset \"%\" after a failed save.\n" preset_name
            )
        )

        save_ok
        -- return
    ),

    /*
    Loads one named preset as an array of string key/value pairs or undefined when the preset does not exist.
    */
    function loadPreset ini_path preset_name section_prefix:"Preset" =
    (
        local section_name = getPresetSectionName preset_name section_prefix:section_prefix

        if section_name == undefined then return undefined
        if not hasPreset ini_path preset_name section_prefix:section_prefix then return undefined

        getSectionEntries ini_path section_name
        -- return
    ),

    /*
    Removes one named preset and confirms that its section no longer exists.
    */
    function removePreset ini_path preset_name section_prefix:"Preset" =
    (
        local section_name = getPresetSectionName preset_name section_prefix:section_prefix

        if classOf ini_path != String or ini_path == "" then return false
        if section_name == undefined then return false
        if not hasPreset ini_path preset_name section_prefix:section_prefix then return false

        delIniSetting ini_path section_name
        not (hasINISetting ini_path section_name)
        -- return
    ),

    on create do
    (
    )
)

global PresetManager
PresetManager = PresetManager_v()
