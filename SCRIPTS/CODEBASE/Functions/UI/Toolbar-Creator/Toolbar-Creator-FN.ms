/*
Toolbar-Creator backend 0.17 | shared project 0.33
Standalone creation, replacement, and deletion of script toolbars.

button_data format:
#(
    #(script_path, button_text, tooltip),
    #(script_path, button_text, tooltip)
)

Public API:
manageScriptToolbar #create "My Toolbar" button_data:button_data
manageScriptToolbar #update "My Toolbar" button_data:button_data
manageScriptToolbar #delete "My Toolbar"
*/

global toolbarCreatorProjectVersion
global toolbarCreatorFileVersion
global toolbarCreatorBackendProjectVersion
global manageScriptToolbar
global collectToolbarScripts
global listManagedScriptToolbars
global getManagedScriptToolbarRecords
global getManagedScriptToolbarButtons
global renameManagedScriptToolbar
global toolbarCreatorMakeScriptManagerGroupReference
global toolbarCreatorIsScriptManagerGroupReference
global toolbarCreatorParseScriptManagerGroupReference

toolbarCreatorFileVersion = 0.17
toolbarCreatorBackendProjectVersion = 0.33

if toolbarCreatorProjectVersion == undefined or toolbarCreatorProjectVersion < toolbarCreatorBackendProjectVersion then
(
    toolbarCreatorProjectVersion = toolbarCreatorBackendProjectVersion
)

/*
Internal backend helpers are defined outside the public function.
Their names are uniquely prefixed so MAXScript does not capture outer locals.
*/
/*
Prints one fatal workflow diagnostic with a consistent prefix.
Returns false for direct assignment to a Boolean operation flag.
*/
function toolbarCreatorReportFailure failure_text =
(
    format "[Toolbar-Creator] FAILED | %\n" failure_text
    false
    -- return
)

/*
Escapes text embedded inside a generated MAXScript string literal.
Returns an escaped String without changing the source value.
*/
function toolbarCreatorEscapeString source_text =
(
    escaped_text = source_text as string
    escaped_text = substituteString escaped_text "\\" "\\\\"
    escaped_text = substituteString escaped_text "\"" "\\\""
    escaped_text = substituteString escaped_text "\r" ""
    escaped_text = substituteString escaped_text "\n" "\\n"
    escaped_text
    -- return
)

/*
Returns the configured userScripts directory without a trailing separator.
This base is used for whole-directory, case-insensitive prefix matches.
*/
function toolbarCreatorGetUserScriptsRoot =
(
    directory_path = getDir #userScripts
    if directory_path == undefined then directory_path = ""
    directory_path = substituteString directory_path "/" "\\"

    while directory_path.count > 3 and (substring directory_path directory_path.count 1) == "\\" do
    (
        directory_path = substring directory_path 1 (directory_path.count - 1)
    )

    directory_path
    -- return
)

/*
Expands $userScripts and its children for .NET path APIs, which do not
understand MAXScript symbolic pathnames. All other paths are unchanged.
*/
function toolbarCreatorResolveScriptPath source_path =
(
    resolved_path = source_path

    if classOf source_path == String then
    (
        normalized_source = substituteString source_path "/" "\\"
        source_lower = toLower normalized_source
        symbolic_root = "$userScripts"
        symbolic_prefix = (toLower symbolic_root) + "\\"
        user_scripts_root = toolbarCreatorGetUserScriptsRoot()

        if user_scripts_root != "" then
        (
            if source_lower == (toLower symbolic_root) then
            (
                resolved_path = user_scripts_root
            )
            else if (substring source_lower 1 symbolic_prefix.count) == symbolic_prefix then
            (
                suffix_text = substring normalized_source (symbolic_prefix.count + 1) (normalized_source.count - symbolic_prefix.count)
                resolved_path = user_scripts_root + "\\" + suffix_text
            )
        )
    )

    resolved_path
    -- return
)

/*
Shortens only the exact userScripts directory or paths under its boundary.
For example, C:\Scripts\CODEBASE becomes $userScripts\CODEBASE when
getDir #userScripts returns C:\Scripts. Sibling folders remain unchanged.
*/
function toolbarCreatorToPortablePath source_path =
(
    portable_path = source_path

    if classOf source_path == String then
    (
        user_scripts_root = toolbarCreatorGetUserScriptsRoot()
        normalized_source = substituteString (toolbarCreatorResolveScriptPath source_path) "/" "\\"
        root_prefix = (toLower user_scripts_root) + "\\"

        if user_scripts_root != "" then
        (
            if (toLower normalized_source) == (toLower user_scripts_root) then
            (
                portable_path = "$userScripts"
            )
            else if (substring (toLower normalized_source) 1 root_prefix.count) == root_prefix then
            (
                suffix_text = substring normalized_source (root_prefix.count + 1) (normalized_source.count - root_prefix.count)
                portable_path = "$userScripts\\" + suffix_text
            )
        )
    )

    portable_path
    -- return
)


/*
Builds one special toolbar-script reference that points to a Script-Manager
user group rather than a single script file.
Format: __SCRIPT_MANAGER_GROUP__|<portable_manager_path>|<group_name>
*/
function toolbarCreatorMakeScriptManagerGroupReference manager_source_path group_name =
(
    local manager_path = toolbarCreatorToPortablePath manager_source_path
    if classOf manager_path != String or manager_path == "" then return undefined
    if classOf group_name != String or group_name == "" then return undefined
    "__SCRIPT_MANAGER_GROUP__|" + manager_path + "|" + group_name
    -- return
)

/*
Returns true when a toolbar button holds a saved Script-Manager user-group reference.
Only the reference prefix is inspected; no file or CUIX data is changed.
*/
function toolbarCreatorIsScriptManagerGroupReference source_path =
(
    classOf source_path == String and source_path.count > 26 and (substring source_path 1 25) == "__SCRIPT_MANAGER_GROUP__|"
    -- return
)

/*
Parses one Script-Manager user-group reference.
Returns #(resolved_manager_script_path, group_name, portable_manager_source_path)
or undefined on invalid input.
*/
function toolbarCreatorParseScriptManagerGroupReference source_path =
(
    if not(toolbarCreatorIsScriptManagerGroupReference source_path) then return undefined
    local body_text = substring source_path 26 (source_path.count - 25)
    local separator_index = findString body_text "|"
    if separator_index == undefined or separator_index < 2 or separator_index >= body_text.count then return undefined
    local portable_manager_path = substring body_text 1 (separator_index - 1)
    local group_name = substring body_text (separator_index + 1) (body_text.count - separator_index)
    if group_name == "" then return undefined
    local resolved_manager_path = toolbarCreatorResolveScriptPath portable_manager_path
    #(resolved_manager_path, group_name, portable_manager_path)
    -- return
)

/*
Converts arbitrary display text to a valid compact identifier fragment.
Returns Item when no alphanumeric identifier characters remain.
*/
function toolbarCreatorMakeIdentifierFragment source_text max_length:24 =
(
    allowed_characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_"
    identifier_text = ""
    source_value = source_text as string

    for character_index = 1 to source_value.count do
    (
        current_character = source_value[character_index]
        if (findString allowed_characters current_character) != undefined then identifier_text += current_character
    )

    if identifier_text == "" then identifier_text = "Item"
    if identifier_text.count > max_length then identifier_text = substring identifier_text 1 max_length
    if (findString "0123456789" identifier_text[1]) != undefined then identifier_text = "N_" + identifier_text

    identifier_text
    -- return
)

/*
Computes a stable positive path hash that stays inside 32-bit Integer range.
Returns an Integer in the inclusive range zero through 999982.
*/
function toolbarCreatorGetStablePathHash source_text =
(
    hash_value = 17
    normalized_text = toLower (source_text as string)

    for character_index = 1 to normalized_text.count do
    (
        character_value = bit.charAsInt normalized_text[character_index]
        hash_value = mod ((hash_value * 131) + character_value) 999983
    )

    hash_value
    -- return
)

/*
Builds one stable MacroScript action name from toolbar and script identity.
The path-derived suffix keeps action names stable when button order changes.
*/
function toolbarCreatorGetMacroName target_toolbar_name script_path =
(
    toolbar_fragment = toolbarCreatorMakeIdentifierFragment target_toolbar_name max_length:18
    local identity_text = "Group"
    if toolbarCreatorIsScriptManagerGroupReference script_path then
    (
        local group_reference = toolbarCreatorParseScriptManagerGroupReference script_path
        if group_reference != undefined then identity_text = group_reference[2]
    )
    else
    (
        identity_text = getFilenameFile script_path
    )
    script_fragment = toolbarCreatorMakeIdentifierFragment identity_text max_length:24
    hash_source = target_toolbar_name + "|" + script_path
    hash_text = formattedPrint (toolbarCreatorGetStablePathHash hash_source) format:"06d"
    "ToolbarCreator_" + toolbar_fragment + "_" + script_fragment + "_" + hash_text
    -- return
)

/*
Returns the complete active CUIX path from the current CUI configuration.
Returns an empty String when the path cannot be resolved to an existing file.
*/
function toolbarCreatorGetActiveCuixPath =
(
    config_file_name = cui.getConfigFile()
    resolved_cuix_path = ""

    if config_file_name != undefined and config_file_name != "" then
    (
        if doesFileExist config_file_name then
        (
            resolved_cuix_path = config_file_name
        )
        else
        (
            config_directory = cui.getDir()

            if config_directory != undefined and config_directory != "" then
            (
                final_character = substring config_directory config_directory.count 1
                if final_character != "\\" and final_character != "/" then config_directory += "\\"
                candidate_cuix_path = config_directory + config_file_name
                if doesFileExist candidate_cuix_path then resolved_cuix_path = candidate_cuix_path
            )
        )
    )

    resolved_cuix_path
    -- return
)

/*
Resolves the generated MacroScript source path for one toolbar.
Uses the caller path when supplied, otherwise writes to #userMacros.
*/
function toolbarCreatorGetGeneratedMacroPath target_toolbar_name requested_macro_path =
(
    resolved_macro_path = requested_macro_path

    if resolved_macro_path == undefined or resolved_macro_path == "" then
    (
        toolbar_hash_text = formattedPrint (toolbarCreatorGetStablePathHash target_toolbar_name) format:"06d"
        macro_file_name = "Toolbar-Creator-" + (toolbarCreatorMakeIdentifierFragment target_toolbar_name max_length:40) + "-" + toolbar_hash_text + ".mcr"
        resolved_macro_path = (getDir #userMacros) + "\\" + macro_file_name
    )

    resolved_macro_path
    -- return
)

/*
Reads one complete UTF text file through the .NET file API.
Returns undefined and prints the original exception when reading fails.
*/
function toolbarCreatorReadTextFile source_path =
(
    source_text = undefined
    file_type = dotNetClass "System.IO.File"

    try
    (
        source_text = file_type.ReadAllText source_path
    )
    catch
    (
        exception_text = getCurrentException()
        format "[Toolbar-Creator] FAILED | File read | path:% | exception:%\n" source_path exception_text
    )

    source_text
    -- return
)

/*
Writes one complete UTF-8 text file with a byte-order mark.
Returns true only when the file write completes and the file exists.
*/
function toolbarCreatorWriteTextFile target_path target_text =
(
    write_ok = true
    file_type = dotNetClass "System.IO.File"
    directory_type = dotNetClass "System.IO.Directory"
    encoding_value = dotNetObject "System.Text.UTF8Encoding" true
    target_directory = getFilenamePath target_path

    try
    (
        if target_directory != "" and not(directory_type.Exists target_directory) then directory_type.CreateDirectory target_directory
        file_type.WriteAllText target_path target_text encoding_value
        write_ok = file_type.Exists target_path
    )
    catch
    (
        exception_text = getCurrentException()
        format "[Toolbar-Creator] FAILED | File write | path:% | exception:%\n" target_path exception_text
        write_ok = false
    )

    write_ok
    -- return
)

/*
Copies one file with overwrite enabled through the .NET file API.
Returns true only when the destination exists after the copy.
*/
function toolbarCreatorCopyFile source_path target_path =
(
    copy_ok = true
    file_type = dotNetClass "System.IO.File"

    try
    (
        file_type.Copy source_path target_path true
        copy_ok = file_type.Exists target_path
    )
    catch
    (
        exception_text = getCurrentException()
        format "[Toolbar-Creator] FAILED | File copy | source:% | target:% | exception:%\n" source_path target_path exception_text
        copy_ok = false
    )

    copy_ok
    -- return
)

/*
Deletes one file when present and treats an absent file as already clean.
Returns false only when an existing file cannot be removed.
*/
function toolbarCreatorDeleteFile target_path =
(
    delete_ok = true

    if target_path != undefined then
    (
        if target_path != "" then
        (
            if doesFileExist target_path then
            (
                delete_ok = deleteFile target_path
                if not delete_ok then format "[Toolbar-Creator] FAILED | File delete | path:%\n" target_path
            )
        )
    )

    delete_ok
    -- return
)

/*
Saves the current 3ds Max UI configuration to the requested CUIX path.
Returns false and prints the native exception when saveConfigAs fails.
*/
function toolbarCreatorSaveConfig target_path =
(
    save_ok = false

    try
    (
        native_result = cui.saveConfigAs target_path
        save_ok = (native_result != false and native_result != undefined and doesFileExist target_path)
    )
    catch
    (
        exception_text = getCurrentException()
        format "[Toolbar-Creator] FAILED | CUIX save | path:% | exception:%\n" target_path exception_text
    )

    save_ok
    -- return
)

/*
Loads one 3ds Max UI configuration from the requested CUIX path.
Returns false and prints the native exception when loadConfig fails.
*/
function toolbarCreatorLoadConfig source_path =
(
    load_ok = false

    try
    (
        native_result = cui.loadConfig source_path
        load_ok = (native_result != false and native_result != undefined)
    )
    catch
    (
        exception_text = getCurrentException()
        format "[Toolbar-Creator] FAILED | CUIX load | path:% | exception:%\n" source_path exception_text
    )

    load_ok
    -- return
)

/*
Finds the first toolbar Window node with an exact objectName match.
Returns undefined when the named toolbar is absent.
*/
function toolbarCreatorFindXmlNode windows_node target_toolbar_name =
(
    toolbar_node = undefined
    child_nodes = windows_node.ChildNodes

    for child_index = 0 to (child_nodes.Count - 1) while toolbar_node == undefined do
    (
        candidate_node = child_nodes.ItemOf[child_index]
        if candidate_node.Name == "Window" and (candidate_node.GetAttribute "objectName") == target_toolbar_name then
        (
            toolbar_node = candidate_node
        )
    )

    toolbar_node
    -- return
)

/*
Checks whether a toolbar Window contains generated Toolbar-Creator actions.
Native toolbar renaming must not remove this identity.
*/
function toolbarCreatorIsManagedXmlNode toolbar_node =
(
    is_managed = false
    if toolbar_node != undefined and toolbar_node.Name == "Window" and (toolbar_node.GetAttribute "type") == "T" then
    (
        items_node = toolbar_node.SelectSingleNode "Items"
        if items_node != undefined then
        (
            item_nodes = items_node.ChildNodes
            for item_index = 0 to (item_nodes.Count - 1) while not is_managed do
            (
                item_node = item_nodes.ItemOf[item_index]
                if item_node.Name == "Item" then
                (
                    action_id = item_node.GetAttribute "actionID"
                    if (findString action_id "ToolbarCreator_") == 1 then is_managed = true
                )
            )
        )
    )
    is_managed
    -- return
)

/*
Returns the native toolbar's visible title. The name attribute is authoritative;
objectName is a stable toolbar identifier, never a display-name override.
Repeated native renames may leave objectName and MacroScript filenames unchanged.
*/
function toolbarCreatorGetManagedDisplayName toolbar_node =
(
    local object_name = toolbar_node.GetAttribute "objectName"
    local display_name = toolbar_node.GetAttribute "name"
    if display_name != "" then display_name else object_name
    -- return
)

/*
Collects #(visible_name, object_name, ordered_action_signature) for managed toolbars.
The signature survives native renaming of both name attributes.
*/
function toolbarCreatorCollectManagedRecords windows_node =
(
    managed_records = #()
    if windows_node != undefined then
    (
        window_nodes = windows_node.ChildNodes
        for window_index = 0 to (window_nodes.Count - 1) do
        (
            window_node = window_nodes.ItemOf[window_index]
            if toolbarCreatorIsManagedXmlNode window_node then
            (
                object_name = window_node.GetAttribute "objectName"
                display_name = toolbarCreatorGetManagedDisplayName window_node
                signature_text = ""
                items_node = window_node.SelectSingleNode "Items"
                item_nodes = items_node.ChildNodes
                for item_index = 0 to (item_nodes.Count - 1) do
                (
                    item_node = item_nodes.ItemOf[item_index]
                    if item_node.Name == "Item" then signature_text += (item_node.GetAttribute "actionID") + "\n"
                )
                if object_name != "" and display_name != "" then append managed_records #(display_name, object_name, signature_text)
            )
        )
    )
    managed_records
    -- return
)

/*
Finds a managed toolbar by native objectName first, then visible name.
Does not use display names when selecting unrelated system toolbars.
*/
function toolbarCreatorFindManagedXmlNode windows_node target_toolbar_name =
(
    found_node = undefined
    if windows_node != undefined then found_node = toolbarCreatorFindXmlNode windows_node target_toolbar_name
    if found_node == undefined and windows_node != undefined then
    (
        window_nodes = windows_node.ChildNodes
        for window_index = 0 to (window_nodes.Count - 1) while found_node == undefined do
        (
            window_node = window_nodes.ItemOf[window_index]
            if (toolbarCreatorIsManagedXmlNode window_node) and ((window_node.GetAttribute "name") == target_toolbar_name) then
            (
                found_node = window_node
            )
        )
    )
    found_node
    -- return
)

/*
Suppresses stale native-rename aliases with identical generated action IDs.
Keeps the last CUIX entry (the latest renamed copy) without deleting toolbars.
Distinct toolbar action sets remain independent.
*/
function toolbarCreatorFilterRenamedRecords managed_records =
(
    local unique_records = #()
    if classOf managed_records != Array then return unique_records
    for current_record in managed_records do
    (
        local duplicate_index = 0
        if current_record[3] != "" then
        (
            for existing_index = 1 to unique_records.count while duplicate_index == 0 do
            (
                if unique_records[existing_index][3] == current_record[3] then duplicate_index = existing_index
            )
        )
        if duplicate_index > 0 then deleteItem unique_records duplicate_index
        append unique_records current_record
    )
    unique_records
    -- return
)

/*
Returns distinct visible names for managed Toolbar-Creator action sets.
Retains only the newest renamed alias when native CUIX retains both entries.
*/
function toolbarCreatorCollectManagedNames windows_node =
(
    local managed_names = #()
    local managed_records = toolbarCreatorFilterRenamedRecords (toolbarCreatorCollectManagedRecords windows_node)
    for record in managed_records do
    (
        if (findItem managed_names record[1]) == 0 then append managed_names record[1]
    )
    managed_names
    -- return
)

/*
Synchronizes native Customize UI edits to the active CUIX without changing the
active UI scheme or reloading any toolbar. Returns false on failure.
*/
function toolbarCreatorSyncLiveToolbarNames =
(
    local active_cuix_path = toolbarCreatorGetActiveCuixPath()
    if active_cuix_path == "" then return toolbarCreatorReportFailure "Live toolbar refresh: active CUIX path is unavailable."
    local sync_ok = false
    try
    (
        local save_result = cui.saveConfig()
        sync_ok = save_result != false and doesFileExist active_cuix_path
    )
    catch
    (
        format "[Toolbar-Creator] FAILED | Live CUIX synchronization | path:% | exception:%\n" active_cuix_path (getCurrentException())
    )
    if not sync_ok then toolbarCreatorReportFailure ("Live toolbar refresh failed | CUIX:" + active_cuix_path)
    sync_ok
    -- return
)

/*
Reads managed toolbar records, optionally saving the current live CUI state
first so native Customize > Rename edits appear on every subsequent refresh.
*/
function getManagedScriptToolbarRecords sync_live:false =
(
    local active_cuix_path = toolbarCreatorGetActiveCuixPath()
    local managed_records = undefined
    if active_cuix_path == "" then
    (
        toolbarCreatorReportFailure "Cannot inspect managed toolbars: active CUIX path is unavailable."
    )
    else if sync_live and not (toolbarCreatorSyncLiveToolbarNames()) then
    (
        toolbarCreatorReportFailure "Cannot inspect managed toolbars: live CUIX synchronization failed."
    )
    else
    (
        try
        (
            local xml_document = dotNetObject "System.Xml.XmlDocument"
            xml_document.Load active_cuix_path
            local windows_node = xml_document.SelectSingleNode "/ADSK_CUI/CUIWindows"
            if windows_node == undefined then
            (
                toolbarCreatorReportFailure "Cannot inspect managed toolbars: CUIWindows is missing."
            )
            else
            (
                managed_records = toolbarCreatorCollectManagedRecords windows_node
            )
        )
        catch
        (
            format "[Toolbar-Creator] FAILED | Managed toolbar records | path:% | exception:%\n" active_cuix_path (getCurrentException())
        )
    )
    managed_records
    -- return
)

/*
Lists managed toolbar display names from the current UI after explicit sync.
The optional sync_live keyword is also used by Script-Manager's refresh path.
*/
function listManagedScriptToolbars sync_live:false =
(
    local managed_records = getManagedScriptToolbarRecords sync_live:sync_live
    local managed_names = undefined
    if classOf managed_records == Array then
    (
        managed_names = #()
        local filtered_records = toolbarCreatorFilterRenamedRecords managed_records
        for record in filtered_records do append managed_names record[1]
    )
    managed_names
    -- return
)

/*
Extracts macro action names and their original MaxScript paths from the
generated .mcr source. Paths are stored as escaped MAXScript string literals.
Returns an ordered Array of #(macro_action_name, script_path) records.
*/
function toolbarCreatorParseGeneratedMacroPaths source_text =
(
    macro_paths = #()
    active_macro_name = ""

    if classOf source_text == String then
    (
        source_lines = filterString source_text "\r\n"

        for source_line in source_lines do
        (
            trimmed_line = trimLeft (trimRight source_line)

            if (findString trimmed_line "macroScript ") == 1 then
            (
                macro_tokens = filterString trimmed_line " \t"
                active_macro_name = if macro_tokens.count >= 2 then macro_tokens[2] else ""
            )
            else if active_macro_name != "" and (findString trimmed_line "target_script_path = \"") == 1 then
            (
                quote_index = findString trimmed_line "\""

                if quote_index != undefined and (substring trimmed_line trimmed_line.count 1) == "\"" then
                (
                    escaped_path = substring trimmed_line (quote_index + 1) (trimmed_line.count - quote_index - 1)
                    original_path = substituteString escaped_path "\\\\" "\\"
                    append macro_paths #(active_macro_name, original_path)
                    active_macro_name = ""
                )
            )
        )
    )

    macro_paths
    -- return
)

/*
Maps saved toolbar Item actionIDs to their generated MacroScript paths.
Returns undefined for missing, mixed, or unreadable button mappings rather
than exposing an incomplete script list that could overwrite the toolbar.
*/
function toolbarCreatorCollectToolbarButtonData toolbar_node macro_paths =
(
    collected_buttons = undefined

    if toolbar_node != undefined and (toolbar_node.GetAttribute "type") == "T" and classOf macro_paths == Array then
    (
        items_node = toolbar_node.SelectSingleNode "Items"

        if items_node != undefined and items_node.ChildNodes.Count > 0 then
        (
            collected_buttons = #()
            item_nodes = items_node.ChildNodes

            for item_index = 0 to (item_nodes.Count - 1) while collected_buttons != undefined do
            (
                item_node = item_nodes.ItemOf[item_index]
                action_id = if item_node.Name == "Item" then item_node.GetAttribute "actionID" else ""
                separator_index = findString action_id "`"
                action_name = if separator_index != undefined then substring action_id 1 (separator_index - 1) else ""
                matching_path = undefined

                if (findString action_name "ToolbarCreator_") == 1 then
                (
                    for macro_record in macro_paths while matching_path == undefined do
                    (
                        if macro_record[1] == action_name then matching_path = macro_record[2]
                    )
                )

                if matching_path == undefined or matching_path == "" then
                (
                    format "[Toolbar-Creator] FAILED | Cannot map saved toolbar action: %\n" action_id
                    collected_buttons = undefined
                )
                else
                (
                    button_text = item_node.GetAttribute "label"
                    if button_text == "" then button_text = getFilenameFile matching_path
                    tooltip_text = item_node.GetAttribute "tip"
                    append collected_buttons #((toolbarCreatorToPortablePath matching_path), button_text, tooltip_text)
                )
            )
        )
    )

    collected_buttons
    -- return
)

/*
Tests whether one generated .mcr contains every toolbar action in order.
Unrelated or incomplete MacroScript files never qualify for fallback lookup.
*/
function toolbarCreatorMacroPathsMatchToolbar toolbar_node macro_paths =
(
    matches_all = false
    if toolbar_node != undefined and classOf macro_paths == Array and macro_paths.count > 0 then
    (
        items_node = toolbar_node.SelectSingleNode "Items"
        if items_node != undefined and items_node.ChildNodes.Count > 0 then
        (
            matches_all = true
            item_nodes = items_node.ChildNodes
            for item_index = 0 to (item_nodes.Count - 1) while matches_all do
            (
                item_node = item_nodes.ItemOf[item_index]
                action_id = if item_node.Name == "Item" then item_node.GetAttribute "actionID" else ""
                separator_index = findString action_id "`"
                action_name = if separator_index != undefined then substring action_id 1 (separator_index - 1) else ""
                found_action = false
                if (findString action_name "ToolbarCreator_") == 1 then
                (
                    for macro_record in macro_paths while not found_action do
                    (
                        if macro_record[1] == action_name then found_action = true
                    )
                )
                if not found_action then matches_all = false
            )
        )
    )
    matches_all
    -- return
)

/*
Finds the original generated .mcr by matching CUIX action identifiers.
Native Customize renames do not rename generated MacroScript files.
*/
function toolbarCreatorFindManagedMacroPath toolbar_node requested_toolbar_name requested_macro_path:undefined =
(
    matched_path = undefined
    if requested_macro_path != undefined and requested_macro_path != "" then
    (
        if doesFileExist requested_macro_path then matched_path = requested_macro_path
    )
    else if toolbar_node != undefined then
    (
        candidates = #()
        object_name = toolbar_node.GetAttribute "objectName"
        visible_name = toolbar_node.GetAttribute "name"
        for candidate_name in #(object_name, visible_name, requested_toolbar_name) do
        (
            if candidate_name != "" then
            (
                candidate_path = toolbarCreatorGetGeneratedMacroPath candidate_name undefined
                if (findItem candidates candidate_path) == 0 then append candidates candidate_path
            )
        )
        generated_files = getFiles ((getDir #userMacros) + "\\Toolbar-Creator-*.mcr")
        for candidate_path in generated_files do
        (
            if (findItem candidates candidate_path) == 0 then append candidates candidate_path
        )
        for candidate_path in candidates while matched_path == undefined do
        (
            if doesFileExist candidate_path then
            (
                source_text = toolbarCreatorReadTextFile candidate_path
                if classOf source_text == String then
                (
                    macro_paths = toolbarCreatorParseGeneratedMacroPaths source_text
                    if toolbarCreatorMacroPathsMatchToolbar toolbar_node macro_paths then matched_path = candidate_path
                )
            )
        )
    )
    matched_path
    -- return
)

/*
Reads any managed toolbar by native name or objectName without changing it.
Locates the original MacroScript even after a native toolbar rename.
*/
function getManagedScriptToolbarButtons toolbar_name macro_file_path:undefined =
(
    saved_buttons = undefined
    active_cuix_path = toolbarCreatorGetActiveCuixPath()
    if active_cuix_path == "" then
    (
        toolbarCreatorReportFailure "Cannot load managed toolbar scripts: active CUIX path is unavailable."
    )
    else
    (
        try
        (
            xml_document = dotNetObject "System.Xml.XmlDocument"
            xml_document.Load active_cuix_path
            windows_node = xml_document.SelectSingleNode "/ADSK_CUI/CUIWindows"
            toolbar_node = toolbarCreatorFindManagedXmlNode windows_node toolbar_name
            if toolbar_node != undefined then
            (
                generated_macro_path = toolbarCreatorFindManagedMacroPath toolbar_node toolbar_name requested_macro_path:macro_file_path
                if generated_macro_path != undefined then
                (
                    macro_source = toolbarCreatorReadTextFile generated_macro_path
                    if classOf macro_source == String then
                    (
                        macro_paths = toolbarCreatorParseGeneratedMacroPaths macro_source
                        saved_buttons = toolbarCreatorCollectToolbarButtonData toolbar_node macro_paths
                    )
                )
                else
                (
                    format "[Toolbar-Creator] FAILED | Generated .mcr not found for native toolbar: %\n" toolbar_name
                )
            )
        )
        catch
        (
            format "[Toolbar-Creator] FAILED | Managed toolbar script read | toolbar:% CUIX:% exception:%\n" toolbar_name active_cuix_path (getCurrentException())
        )
        if saved_buttons == undefined then
        (
            format "[Toolbar-Creator] FAILED | Incomplete managed toolbar data | toolbar:%\n" toolbar_name
        )
    )
    saved_buttons
    -- return
)

/*
Creates one CUIX toolbar Window node and all supplied MacroScript buttons.
Returns the detached XML node ready to append under CUIWindows.
*/
function toolbarCreatorBuildXmlNode xml_document target_toolbar_name target_macro_category source_button_data macro_names display_name:undefined =
(
    toolbar_node = xml_document.CreateElement "Window"
    toolbar_node.SetAttribute "objectName" target_toolbar_name
    if display_name == undefined or display_name == "" then display_name = target_toolbar_name
    toolbar_node.SetAttribute "name" display_name
    toolbar_node.SetAttribute "type" "T"
    toolbar_node.SetAttribute "cType" "1"
    toolbar_node.SetAttribute "toolbarRows" "1"

    items_node = xml_document.CreateElement "Items"
    toolbar_node.AppendChild items_node

    for button_index = 1 to source_button_data.count do
    (
        button_record = source_button_data[button_index]
        button_text = trimLeft (trimRight button_record[2])
        if button_text.count > 10 then button_text = substring button_text 1 10
        tooltip_text = if button_record.count >= 3 then button_record[3] else ("Run " + getFilenameFile button_record[1])
        button_width = button_text.count * 7 + 12
        if button_width < 40 then button_width = 40

        button_node = xml_document.CreateElement "Item"
        button_node.SetAttribute "typeID" "2"
        button_node.SetAttribute "type" "CTB_MACROBUTTON"
        button_node.SetAttribute "width" (button_width as string)
        button_node.SetAttribute "height" "0"
        button_node.SetAttribute "controlID" "0"
        button_node.SetAttribute "macroTypeID" "3"
        button_node.SetAttribute "macroType" "MB_TYPE_ACTION"
        button_node.SetAttribute "actionTableID" "647394"
        button_node.SetAttribute "imageID" "-1"
        button_node.SetAttribute "imageName" ""
        button_node.SetAttribute "actionID" (macro_names[button_index] + "`" + target_macro_category)
        button_node.SetAttribute "tip" tooltip_text
        button_node.SetAttribute "label" button_text
        items_node.AppendChild button_node
    )

    toolbar_node
    -- return
)

/*
Builds the generated MacroScript definitions for every toolbar button.
Each action loads its source script directly and has no manager dependency.
*/
function toolbarCreatorBuildMacroSource source_button_data target_macro_category macro_names =
(
    source_text = "-- Generated by Toolbar-Creator " + (toolbarCreatorProjectVersion as string) + "\r\n\r\n"

    for button_index = 1 to source_button_data.count do
    (
        button_record = source_button_data[button_index]
        original_source = button_record[1]
        is_group_button = toolbarCreatorIsScriptManagerGroupReference original_source
        script_path = if is_group_button then original_source else toolbarCreatorToPortablePath original_source
        button_text = trimLeft (trimRight button_record[2])
        if button_text.count > 10 then button_text = substring button_text 1 10
        tooltip_text = if button_record.count >= 3 then button_record[3] else (if is_group_button then "Load Script-Manager group" else ("Run " + getFilenameFile script_path))

        escaped_category = toolbarCreatorEscapeString target_macro_category
        escaped_button_text = toolbarCreatorEscapeString button_text
        escaped_tooltip_text = toolbarCreatorEscapeString tooltip_text

        source_text += "macroScript " + macro_names[button_index] + " category:\"" + escaped_category + "\" buttonText:\"" + escaped_button_text + "\" tooltip:\"" + escaped_tooltip_text + "\"\r\n"
        source_text += "(\r\n"

        if is_group_button then
        (
            local group_reference = toolbarCreatorParseScriptManagerGroupReference original_source
            local manager_script_path = if group_reference != undefined then group_reference[3] else ""
            local group_name = if group_reference != undefined then group_reference[2] else ""
            local escaped_manager_script_path = toolbarCreatorEscapeString manager_script_path
            local escaped_group_name = toolbarCreatorEscapeString group_name
            local escaped_group_reference = toolbarCreatorEscapeString original_source
            source_text += "    target_script_path = \"" + escaped_group_reference + "\"\r\n"
            source_text += "    manager_script_path = \"" + escaped_manager_script_path + "\"\r\n"
            source_text += "    target_group_name = \"" + escaped_group_name + "\"\r\n"
            source_text += "    if script_manager == undefined or script_manager.file_version < 1.243 then\r\n"
            source_text += "    (\r\n"
            source_text += "        if doesFileExist manager_script_path then fileIn manager_script_path quiet:true else format \"[Toolbar-Creator] Script-Manager not found: %\\n\" manager_script_path\r\n"
            source_text += "    )\r\n"
            source_text += "    if script_manager != undefined and script_manager.file_version >= 1.243 then\r\n"
            source_text += "    (\r\n"
            source_text += "        if not script_manager.openUserGroupByName target_group_name then format \"[Toolbar-Creator] Script-Manager group load failed: %\\n\" target_group_name\r\n"
            source_text += "    )\r\n"
            source_text += "    else\r\n"
            source_text += "    (\r\n"
            source_text += "        format \"[Toolbar-Creator] Script-Manager unavailable for group: %\\n\" target_group_name\r\n"
            source_text += "    )\r\n"
        )
        else
        (
            escaped_script_path = toolbarCreatorEscapeString script_path
            source_text += "    target_script_path = \"" + escaped_script_path + "\"\r\n"
            source_text += "    if doesFileExist target_script_path then\r\n"
            source_text += "    (\r\n"
            source_text += "        fileIn target_script_path quiet:true\r\n"
            source_text += "    )\r\n"
            source_text += "    else\r\n"
            source_text += "    (\r\n"
            source_text += "        format \"[Toolbar-Creator] Script not found: %\\n\" target_script_path\r\n"
            source_text += "    )\r\n"
        )

        source_text += ")\r\n\r\n"
    )

    source_text
    -- return
)

/*
Validates operation, toolbar identity, MacroScript category, and button records.
Returns true only when the complete parameter contract is safe to process.
*/
function toolbarCreatorValidateInputs requested_operation target_toolbar_name source_button_data target_macro_category =
(
    validation_ok = true

    if (findItem #(#create, #update, #delete) requested_operation) == 0 then
    (
        validation_ok = toolbarCreatorReportFailure ("Unsupported operation: " + (requested_operation as string))
    )

    if validation_ok then
    (
        if classOf target_toolbar_name != String then
        (
            validation_ok = toolbarCreatorReportFailure "Toolbar name must be a non-empty String."
        )
        else if trimLeft (trimRight target_toolbar_name) == "" then
        (
            validation_ok = toolbarCreatorReportFailure "Toolbar name must be a non-empty String."
        )
    )

    if validation_ok then
    (
        if (findString target_toolbar_name "\r") != undefined or (findString target_toolbar_name "\n") != undefined then
        (
            validation_ok = toolbarCreatorReportFailure "Toolbar name cannot contain line breaks."
        )
    )

    if validation_ok and requested_operation != #delete then
    (
        if classOf target_macro_category != String then
        (
            validation_ok = toolbarCreatorReportFailure "MacroScript category must be a non-empty String."
        )
        else if trimLeft (trimRight target_macro_category) == "" then
        (
            validation_ok = toolbarCreatorReportFailure "MacroScript category must be a non-empty String."
        )
    )

    if validation_ok and requested_operation != #delete then
    (
        if (findString target_macro_category "`") != undefined or (findString target_macro_category "\r") != undefined or (findString target_macro_category "\n") != undefined then
        (
            validation_ok = toolbarCreatorReportFailure "MacroScript category cannot contain a backtick or line break."
        )
    )

    if validation_ok and requested_operation != #delete then
    (
        if classOf source_button_data != Array then
        (
            validation_ok = toolbarCreatorReportFailure "Create and update require a button-data Array."
        )
        else if source_button_data.count == 0 then
        (
            validation_ok = toolbarCreatorReportFailure "Create and update require at least one button record."
        )
    )

    normalized_paths = #()

    if validation_ok and requested_operation != #delete then
    (
        for button_index = 1 to source_button_data.count while validation_ok do
        (
            button_record = source_button_data[button_index]

            if classOf button_record != Array then
            (
                validation_ok = toolbarCreatorReportFailure ("Button record must be an Array | index:" + (button_index as string))
            )
            else if button_record.count < 2 or button_record.count > 3 then
            (
                validation_ok = toolbarCreatorReportFailure ("Button record must contain path, text, and optional tooltip | index:" + (button_index as string))
            )
            else if classOf button_record[1] != String then
            (
                validation_ok = toolbarCreatorReportFailure ("Button script path must be a non-empty String | index:" + (button_index as string))
            )
            else if button_record[1] == "" then
            (
                validation_ok = toolbarCreatorReportFailure ("Button script path must be a non-empty String | index:" + (button_index as string))
            )
            else if toolbarCreatorIsScriptManagerGroupReference button_record[1] then
            (
                if toolbarCreatorParseScriptManagerGroupReference button_record[1] == undefined then
                (
                    validation_ok = toolbarCreatorReportFailure ("Invalid Script-Manager group reference | index:" + (button_index as string) + " | path:" + button_record[1])
                )
            )
            else if not doesFileExist (toolbarCreatorResolveScriptPath button_record[1]) then
            (
                validation_ok = toolbarCreatorReportFailure ("Button script does not exist | index:" + (button_index as string) + " | path:" + button_record[1])
            )
            else if classOf button_record[2] != String then
            (
                validation_ok = toolbarCreatorReportFailure ("Button text must be a non-empty String | index:" + (button_index as string))
            )
            else if trimLeft (trimRight button_record[2]) == "" then
            (
                validation_ok = toolbarCreatorReportFailure ("Button text must be a non-empty String | index:" + (button_index as string))
            )
            else if button_record.count == 3 then
            (
                if classOf button_record[3] != String then
                (
                    validation_ok = toolbarCreatorReportFailure ("Button tooltip must be a String | index:" + (button_index as string))
                )
            )

            if validation_ok then
            (
                if toolbarCreatorIsScriptManagerGroupReference button_record[1] then
                (
                    normalized_path = toLower button_record[1]
                )
                else
                (
                    normalized_path = toLower (substituteString (toolbarCreatorResolveScriptPath button_record[1]) "/" "\\")
                )
                if findItem normalized_paths normalized_path != 0 then
                (
                    validation_ok = toolbarCreatorReportFailure ("Duplicate script path | index:" + (button_index as string) + " | path:" + button_record[1])
                )
                else
                (
                    append normalized_paths normalized_path
                )
            )
        )
    )

    validation_ok
    -- return
)

/*
Generates stable action names and rejects the unlikely event of a collision.
Returns an empty Array when any two buttons resolve to the same action name.
*/
function toolbarCreatorBuildMacroNames target_toolbar_name source_button_data =
(
    macro_names = #()
    names_ok = true

    for button_record in source_button_data while names_ok do
    (
        macro_name = toolbarCreatorGetMacroName target_toolbar_name (toolbarCreatorToPortablePath button_record[1])
        if (findItem macro_names macro_name) != 0 then
        (
            format "[Toolbar-Creator] FAILED | MacroScript action-name collision | action:% | path:%\n" macro_name button_record[1]
            names_ok = false
        )
        else
        (
            append macro_names macro_name
        )
    )

    if not names_ok then macro_names = #()
    macro_names
    -- return
)

/*
Restores the generated MacroScript source to its pre-operation state.
Re-evaluates the former source when registration was requested.
*/
function toolbarCreatorRestoreMacro macro_path macro_existed former_macro_source should_register =
(
    restore_ok = true

    if macro_existed then
    (
        restore_ok = toolbarCreatorWriteTextFile macro_path former_macro_source

        if restore_ok and should_register then
        (
            try
            (
                fileIn macro_path quiet:true
            )
            catch
            (
                exception_text = getCurrentException()
                format "[Toolbar-Creator] FAILED | MacroScript rollback registration | path:% | exception:%\n" macro_path exception_text
                restore_ok = false
            )
        )
    )
    else
    (
        restore_ok = toolbarCreatorDeleteFile macro_path
    )

    restore_ok
    -- return
)

/*
Restores the original active CUIX bytes and reloads that configuration.
Returns true only when both copy and CUI reload complete.
*/
function toolbarCreatorRestoreCuix backup_cuix_path original_cuix_path =
(
    restore_ok = toolbarCreatorCopyFile backup_cuix_path original_cuix_path
    if restore_ok then restore_ok = toolbarCreatorLoadConfig original_cuix_path
    restore_ok
    -- return
)

/*
Creates, updates, or deletes one toolbar using only supplied parameters.
Returns true only when the requested CUIX and MacroScript changes complete.
*/
function manageScriptToolbar operation toolbar_name button_data:#() macro_category:"Toolbar-Creator" save_ui:true show_toolbar:true macro_file_path:undefined delete_macro_file:true register_macros:true =
(
    operation_ok = toolbarCreatorValidateInputs operation toolbar_name button_data macro_category
    normalized_toolbar_name = ""
    normalized_macro_category = ""
    if classOf toolbar_name == String then normalized_toolbar_name = trimLeft (trimRight toolbar_name)
    if classOf macro_category == String then normalized_macro_category = trimLeft (trimRight macro_category)
    active_cuix_path = ""
    temporary_cuix_path = ""
    backup_cuix_path = ""
    generated_macro_path = ""
    macro_names = #()
    macro_file_existed = false
    former_macro_source = undefined
    macro_state_changed = false
    backup_ready = false

    if operation_ok and macro_file_path != undefined then
    (
        if classOf macro_file_path != String then operation_ok = toolbarCreatorReportFailure "MacroScript file path must be a String or undefined."
    )

    if operation_ok then
    (
        active_cuix_path = toolbarCreatorGetActiveCuixPath()
        if active_cuix_path == "" then operation_ok = toolbarCreatorReportFailure "Active CUIX path could not be resolved."
    )

    if operation_ok then
    (
        generated_macro_path = toolbarCreatorGetGeneratedMacroPath normalized_toolbar_name macro_file_path
        temporary_suffix = (timestamp()) as string
        temporary_cuix_path = (getDir #temp) + "\\Toolbar-Creator-" + temporary_suffix + ".cuix"
        backup_cuix_path = (getDir #temp) + "\\Toolbar-Creator-Backup-" + temporary_suffix + ".cuix"
        operation_ok = toolbarCreatorCopyFile active_cuix_path backup_cuix_path
        backup_ready = operation_ok
    )

    if operation_ok then operation_ok = toolbarCreatorSaveConfig temporary_cuix_path

    xml_document = undefined
    windows_node = undefined
    existing_toolbar_node = undefined

    if operation_ok then
    (
        xml_document = dotNetObject "System.Xml.XmlDocument"
        xml_document.PreserveWhitespace = true

        try
        (
            xml_document.Load temporary_cuix_path
            windows_node = xml_document.SelectSingleNode "/ADSK_CUI/CUIWindows"
        )
        catch
        (
            exception_text = getCurrentException()
            format "[Toolbar-Creator] FAILED | CUIX XML read | path:% | exception:%\n" temporary_cuix_path exception_text
            operation_ok = false
        )

        if operation_ok and windows_node == undefined then operation_ok = toolbarCreatorReportFailure "CUIX does not contain /ADSK_CUI/CUIWindows."
    )

    preserved_display_name = normalized_toolbar_name
    if operation_ok then
    (
        existing_toolbar_node = toolbarCreatorFindXmlNode windows_node normalized_toolbar_name
        if existing_toolbar_node == undefined then existing_toolbar_node = toolbarCreatorFindManagedXmlNode windows_node normalized_toolbar_name

        if existing_toolbar_node != undefined and operation != #create then
        (
            original_toolbar_name = existing_toolbar_node.GetAttribute "objectName"
            native_display_name = toolbarCreatorGetManagedDisplayName existing_toolbar_node
            if native_display_name != "" then preserved_display_name = native_display_name
            matching_macro_path = toolbarCreatorFindManagedMacroPath existing_toolbar_node normalized_toolbar_name requested_macro_path:macro_file_path
            if matching_macro_path != undefined then
            (
                generated_macro_path = matching_macro_path
            )
            else if macro_file_path == undefined then
            (
                generated_macro_path = toolbarCreatorGetGeneratedMacroPath original_toolbar_name undefined
            )
            normalized_toolbar_name = original_toolbar_name
        )

        case operation of
        (
            #create:
            (
                if existing_toolbar_node != undefined then operation_ok = toolbarCreatorReportFailure ("Create target already exists | toolbar:" + normalized_toolbar_name)
            )
            #update:
            (
                if existing_toolbar_node == undefined then operation_ok = toolbarCreatorReportFailure ("Update target does not exist | toolbar:" + normalized_toolbar_name)
            )
            #delete:
            (
                if existing_toolbar_node == undefined then
                (
                    operation_ok = toolbarCreatorReportFailure ("Delete target does not exist | toolbar:" + normalized_toolbar_name)
                )
                else if not (toolbarCreatorIsManagedXmlNode existing_toolbar_node) then
                (
                    operation_ok = toolbarCreatorReportFailure ("Refusing to delete a toolbar not managed by Toolbar-Creator | toolbar:" + normalized_toolbar_name)
                )
            )
        )
    )

    if operation_ok and existing_toolbar_node != undefined then
    (
        removed_toolbar_node = windows_node.RemoveChild existing_toolbar_node
        if removed_toolbar_node == undefined then operation_ok = toolbarCreatorReportFailure ("CUIX toolbar removal returned undefined | toolbar:" + normalized_toolbar_name)
    )

    if operation_ok and operation != #delete then
    (
        macro_names = toolbarCreatorBuildMacroNames normalized_toolbar_name button_data
        if macro_names.count != button_data.count then operation_ok = false
    )

    if operation_ok and operation != #delete then
    (
        new_toolbar_node = toolbarCreatorBuildXmlNode xml_document normalized_toolbar_name normalized_macro_category button_data macro_names display_name:preserved_display_name
        appended_toolbar_node = windows_node.AppendChild new_toolbar_node
        if appended_toolbar_node == undefined then operation_ok = toolbarCreatorReportFailure ("CUIX toolbar append returned undefined | toolbar:" + normalized_toolbar_name)
    )

    if operation_ok then
    (
        try
        (
            xml_document.Save temporary_cuix_path
        )
        catch
        (
            exception_text = getCurrentException()
            format "[Toolbar-Creator] FAILED | CUIX XML write | path:% | exception:%\n" temporary_cuix_path exception_text
            operation_ok = false
        )
    )

    if operation_ok then
    (
        macro_file_existed = doesFileExist generated_macro_path
        if macro_file_existed then former_macro_source = toolbarCreatorReadTextFile generated_macro_path
        if macro_file_existed and former_macro_source == undefined then operation_ok = false
    )

    if operation_ok and operation != #delete then
    (
        generated_macro_source = toolbarCreatorBuildMacroSource button_data normalized_macro_category macro_names
        macro_state_changed = true
        operation_ok = toolbarCreatorWriteTextFile generated_macro_path generated_macro_source

        if operation_ok and register_macros then
        (
            try
            (
                fileIn generated_macro_path quiet:true
            )
            catch
            (
                exception_text = getCurrentException()
                format "[Toolbar-Creator] FAILED | MacroScript registration | path:% | exception:%\n" generated_macro_path exception_text
                operation_ok = false
            )
        )
    )

    if operation_ok and operation == #delete and delete_macro_file and doesFileExist generated_macro_path then
    (
        macro_state_changed = true
        operation_ok = toolbarCreatorDeleteFile generated_macro_path
    )

    if operation_ok then
    (
        operation_ok = toolbarCreatorLoadConfig temporary_cuix_path
    )

    if operation_ok and operation != #delete and show_toolbar then
    (
        try
        (
            toolbar_show_result = cui.showToolbar preserved_display_name
            operation_ok = (toolbar_show_result != false and toolbar_show_result != undefined)
        )
        catch
        (
            exception_text = getCurrentException()
            format "[Toolbar-Creator] FAILED | Toolbar show | toolbar:% | exception:%\n" normalized_toolbar_name exception_text
            operation_ok = false
        )

        if not operation_ok then format "[Toolbar-Creator] FAILED | Toolbar could not be shown | toolbar:%\n" normalized_toolbar_name
    )

    /*
    Deletes must commit the edited XML bytes directly.
    Re-serializing the live UI with saveConfigAs can restore a toolbar that
    was removed from the CUIX while still registered in the active session.
    */
    if operation_ok and save_ui then
    (
        if operation == #delete then
        (
            operation_ok = toolbarCreatorCopyFile temporary_cuix_path active_cuix_path
        )
        else
        (
            operation_ok = toolbarCreatorSaveConfig active_cuix_path
        )

        if operation_ok then operation_ok = toolbarCreatorLoadConfig active_cuix_path
    )

    /*
    Verify deletion against the CUIX actually left active after reload.
    Do not report success if 3ds Max reintroduced the toolbar in the file.
    */
    if operation_ok and operation == #delete then
    (
        verification_cuix_path = if save_ui then active_cuix_path else temporary_cuix_path

        try
        (
            verification_document = dotNetObject "System.Xml.XmlDocument"
            verification_document.Load verification_cuix_path
            verification_windows = verification_document.SelectSingleNode "/ADSK_CUI/CUIWindows"

            if verification_windows == undefined then
            (
                operation_ok = toolbarCreatorReportFailure ("Deletion verification: CUIWindows missing | path:" + verification_cuix_path)
            )
            else if (toolbarCreatorFindXmlNode verification_windows normalized_toolbar_name) != undefined then
            (
                operation_ok = toolbarCreatorReportFailure ("Deletion verification: toolbar remains | name:" + normalized_toolbar_name + " | path:" + verification_cuix_path)
            )
        )
        catch
        (
            exception_text = getCurrentException()
            format "[Toolbar-Creator] FAILED | Deletion verification | toolbar:% path:% exception:%\n" normalized_toolbar_name verification_cuix_path exception_text
            operation_ok = false
        )
    )

    if not operation_ok then
    (
        if backup_ready and backup_cuix_path != "" and doesFileExist backup_cuix_path then
        (
            restore_ui_ok = toolbarCreatorRestoreCuix backup_cuix_path active_cuix_path
            if not restore_ui_ok then format "[Toolbar-Creator] FAILED | Original CUIX rollback failed | backup:% | target:%\n" backup_cuix_path active_cuix_path
        )

        if macro_state_changed then
        (
            restore_macro_ok = toolbarCreatorRestoreMacro generated_macro_path macro_file_existed former_macro_source register_macros
            if not restore_macro_ok then format "[Toolbar-Creator] FAILED | Generated MacroScript rollback failed | path:%\n" generated_macro_path
        )
    )

    if operation_ok and save_ui then
    (
        toolbarCreatorDeleteFile temporary_cuix_path
    )

    if backup_cuix_path != "" then toolbarCreatorDeleteFile backup_cuix_path

    if operation_ok then
    (
        reported_button_count = 0
        if classOf button_data == Array then reported_button_count = button_data.count
        format "[Toolbar-Creator] % | toolbar:% | buttons:% | macro:%\n" operation normalized_toolbar_name reported_button_count generated_macro_path
    )

    operation_ok
    -- return
)

/*
Renames one managed toolbar while retaining ordered buttons, labels, and tooltips.
Creates the replacement first; if removal of the original fails, removes the replacement.
*/
function renameManagedScriptToolbar old_toolbar_name new_toolbar_name button_data:#() macro_category:"Toolbar-Creator" save_ui:true show_toolbar:true old_macro_file_path:undefined new_macro_file_path:undefined register_macros:true =
(
    rename_ok = true

    if classOf old_toolbar_name != String or classOf new_toolbar_name != String then
    (
        rename_ok = toolbarCreatorReportFailure "Rename requires existing and new toolbar names as Strings."
    )

    if rename_ok then
    (
        old_toolbar_name = trimLeft (trimRight old_toolbar_name)
        new_toolbar_name = trimLeft (trimRight new_toolbar_name)

        if old_toolbar_name == "" or new_toolbar_name == "" then
        (
            rename_ok = toolbarCreatorReportFailure "Rename requires non-empty old and new toolbar names."
        )
        else if (toLower old_toolbar_name) == (toLower new_toolbar_name) then
        (
            rename_ok = toolbarCreatorReportFailure "Rename requires a different new toolbar name."
        )
    )

    if rename_ok then
    (
        managed_names = listManagedScriptToolbars()
        if classOf managed_names != Array then
        (
            rename_ok = toolbarCreatorReportFailure "Rename could not inspect the active managed-toolbar list."
        )
        else if (findItem managed_names old_toolbar_name) == 0 then
        (
            rename_ok = toolbarCreatorReportFailure ("Cannot rename a toolbar that is not managed by Toolbar-Creator: " + old_toolbar_name)
        )
        else if (findItem managed_names new_toolbar_name) != 0 then
        (
            rename_ok = toolbarCreatorReportFailure ("Rename target already exists: " + new_toolbar_name)
        )
    )

    if rename_ok then
    (
        old_macro_path = toolbarCreatorGetGeneratedMacroPath old_toolbar_name old_macro_file_path
        try
        (
            xml_document = dotNetObject "System.Xml.XmlDocument"
            xml_document.Load (toolbarCreatorGetActiveCuixPath())
            windows_node = xml_document.SelectSingleNode "/ADSK_CUI/CUIWindows"
            toolbar_node = toolbarCreatorFindManagedXmlNode windows_node old_toolbar_name
            if toolbar_node != undefined then
            (
                found_macro_path = toolbarCreatorFindManagedMacroPath toolbar_node old_toolbar_name requested_macro_path:old_macro_file_path
                if found_macro_path != undefined then old_macro_path = found_macro_path
            )
        )
        catch
        (
            format "[Toolbar-Creator] FAILED | Rename macro lookup | %\n" (getCurrentException())
            rename_ok = false
        )
        new_macro_path = toolbarCreatorGetGeneratedMacroPath new_toolbar_name new_macro_file_path

        if rename_ok and (toLower old_macro_path) == (toLower new_macro_path) then
        (
            rename_ok = toolbarCreatorReportFailure "Rename source and target MacroScript files must be different."
        )
    )

    if rename_ok then
    (
        if classOf button_data == Array and button_data.count == 0 then
        (
            button_data = getManagedScriptToolbarButtons old_toolbar_name macro_file_path:old_macro_file_path
        )

        rename_ok = toolbarCreatorValidateInputs #create new_toolbar_name button_data macro_category
    )

    if rename_ok then
    (
        rename_ok = manageScriptToolbar #create new_toolbar_name button_data:button_data \
            macro_category:macro_category save_ui:save_ui show_toolbar:show_toolbar \
            macro_file_path:new_macro_file_path register_macros:register_macros

        if rename_ok then
        (
            rename_ok = manageScriptToolbar #delete old_toolbar_name \
                save_ui:save_ui show_toolbar:false \
                macro_file_path:old_macro_file_path register_macros:register_macros

            if not rename_ok then
            (
                format "[Toolbar-Creator] FAILED | Rename could not remove original toolbar: % | attempting rollback of: %\n" old_toolbar_name new_toolbar_name
                rollback_ok = manageScriptToolbar #delete new_toolbar_name \
                    save_ui:save_ui show_toolbar:false \
                    macro_file_path:new_macro_file_path register_macros:register_macros
                if not rollback_ok then
                (
                    format "[Toolbar-Creator] FAILED | Rename rollback could not remove replacement: %\n" new_toolbar_name
                )
            )
        )
    )

    if rename_ok then format "[Toolbar-Creator] Rename completed | old:% | new:%\n" old_toolbar_name new_toolbar_name

    rename_ok
    -- return
)

/*
Builds a readable default button label from a script's filename.
Dashes, underscores and repeated whitespace are normalized to one space.
Only the display name changes; paths and explicit caller labels are untouched.
*/
function toolbarCreatorSanitizeScriptDisplayName script_path =
(
    file_base_name = getFilenameFile script_path
    spaced_name = substituteString file_base_name "-" " "
    spaced_name = substituteString spaced_name "_" " "
    name_parts = filterString spaced_name " \t"
    clean_name = ""

    for part_index = 1 to name_parts.count do
    (
        if clean_name != "" then clean_name += " "
        clean_name += name_parts[part_index]
    )

    if clean_name == "" then clean_name = "Script"
    clean_name
    -- return
)

/*
Adds a canonical script path to shared result Arrays only once.
Returns the count of collected toolbar button records.
*/
function toolbarCreatorAppendCollectedScript script_path collected_buttons collected_path_keys path_type =
(
    canonical_path = path_type.GetFullPath script_path
    canonical_key = toLower canonical_path

    if (findItem collected_path_keys canonical_key) == 0 then
    (
        append collected_path_keys canonical_key
        button_label = toolbarCreatorSanitizeScriptDisplayName canonical_path
        append collected_buttons #((toolbarCreatorToPortablePath canonical_path), button_label, ("Run " + button_label))
    )

    collected_buttons.count
    -- return
)

/*
Collects unique MaxScript files from folders and individual file paths.
Returns ordered toolbar-button records, or undefined if a source cannot be scanned.
*/
function collectToolbarScripts source_paths recursive:true =
(
    collected_buttons = #()
    collected_path_keys = #()
    scan_ok = true
    path_type = dotNetClass "System.IO.Path"

    if classOf source_paths != Array then
    (
        format "[Toolbar-Creator] FAILED | Script sources must be an Array | actual:%\n" (classOf source_paths)
        scan_ok = false
    )

    if scan_ok then
    (
        for source_value in source_paths while scan_ok do
        (
            if classOf source_value != String then
            (
                format "[Toolbar-Creator] FAILED | Script source must be a String | actual:%\n" (classOf source_value)
                scan_ok = false
            )
            else if (trimLeft (trimRight source_value)) == "" then
            (
                format "[Toolbar-Creator] FAILED | Script source path is empty.\n"
                scan_ok = false
            )
            else
            (
                normalized_source = undefined

                try
                (
                    normalized_source = path_type.GetFullPath (toolbarCreatorResolveScriptPath source_value)
                )
                catch
                (
                    exception_text = getCurrentException()
                    format "[Toolbar-Creator] FAILED | Invalid source path:% | exception:%\n" source_value exception_text
                    scan_ok = false
                )

                if scan_ok then
                (
                    if doesDirectoryExist normalized_source then
                    (
                        discovered_files = undefined

                        try
                        (
                            discovered_files = getFiles (normalized_source + "\\*.ms") recurse:recursive
                        )
                        catch
                        (
                            exception_text = getCurrentException()
                            format "[Toolbar-Creator] FAILED | Directory scan | path:% | exception:%\n" normalized_source exception_text
                            scan_ok = false
                        )

                        if scan_ok then
                        (
                            sort discovered_files
                            for discovered_path in discovered_files do toolbarCreatorAppendCollectedScript discovered_path collected_buttons collected_path_keys path_type
                        )
                    )
                    else if doesFileExist normalized_source then
                    (
                        if (toLower (getFilenameType normalized_source)) == ".ms" then
                        (
                            toolbarCreatorAppendCollectedScript normalized_source collected_buttons collected_path_keys path_type
                        )
                        else
                        (
                            format "[Toolbar-Creator] FAILED | Only .ms source files are supported | path:%\n" normalized_source
                            scan_ok = false
                        )
                    )
                    else
                    (
                        format "[Toolbar-Creator] FAILED | Source path does not exist | path:%\n" normalized_source
                        scan_ok = false
                    )
                )
            )
        )
    )

    if scan_ok then collected_buttons else undefined
    -- return
)

