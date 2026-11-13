/*
    Script-Manager 1.211
    Generic MaxScript loader, per-subdirectory rollout dialogs, script registry, and persisted manager UI.
*/

/*==============================================================================
    INTEGRATION RUNTIME
================================================================================*/

global SCRIPT_MANAGER_RUNTIME_MODE
global SCRIPT_MANAGER_REGISTRY
global script_manager_project_version
global ScriptManagerIntegration
global EPOLY_TOOLS_RUNTIME_MODE
global EPOLY_TOOLS_REGISTRY
global epoly_tools_project_version
global EPolyToolsIntegration

global scriptManagerGetRegistrationPosition

/*
Returns the raw CreateDialog position for restoring a floating registered dialog.
The working CODEBASE/Functions/UI offset helper uses pre-register [6,-2] and native shift [6,29].
*/
function scriptManagerGetRegistrationPosition dialog_position dock_text =
(
    if dock_text == "float" then
    (
        dialog_position - ([6,-2] + [6,29])
    )
    else
    (
        dialog_position
    )
    -- return
)

global scriptManagerApplyPreRegistrationOffset

/*
Applies the CODEBASE registered-dialog [+6,-2] correction before CUI registration.
The resulting raw position is saved_position-[6,29]; registered dialogs must never be moved.
*/
function scriptManagerApplyPreRegistrationOffset dialog_value saved_position dock_text =
(
    if dock_text != "float" then return true
    if dialog_value == undefined then return false

    local target_position = scriptManagerGetRegistrationPosition saved_position dock_text
    target_position += [6,-2]

    try
    (
        if dialog_value.dialogBar then return false
        if (getDialogPos dialog_value) != target_position then
        (
            setDialogPos dialog_value target_position
            windows.processPostedMessages()
        )
        ((getDialogPos dialog_value) == target_position)
    )
    catch
    (
        format "[Script-Manager] CUI pre-registration positioning failed: %\n" (getCurrentException())
        false
    )
    -- return
)

global scriptManagerTraceDialogPosition

/*
Prints registered rollout X/Y and the delta from saved INI coordinates.
Missing/unavailable rollout positions are reported without changing the dialog.
*/
function scriptManagerTraceDialogPosition dialog_name stage_name dialog_value saved_position:undefined dock_text:"" =
(
    observed_position = undefined
    if dialog_value != undefined then
    (
        try
        (
            if dialog_value.inDialog then observed_position = getDialogPos dialog_value
        )
        catch
        (
            observed_position = undefined
        )
    )

    offset_position = if observed_position != undefined and saved_position != undefined then (observed_position - saved_position) else undefined
    format "[Script-Manager][XY] % | % | dock:% | saved:% | actual:% | delta:%\n" dialog_name stage_name dock_text saved_position observed_position offset_position
    true
    -- return
)

struct ScriptManagerEntry_v
(
    tool_id = "",
    display_name = "",
    api_value = undefined,
    rollout_value = undefined,
    file_version = 0.0,
    project_version = 0.0,
    source_path = "",
    capabilities = #(),

    /*
    Returns whether this registered tool declares one integration capability.
    Capabilities are stored as names such as #selection, #repair, #edge, or #ui.
    */
    function hasCapability capability_name =
    (
        (findItem this.capabilities capability_name) > 0
        -- return
    ),

    on create do
    (
    )
)

struct ScriptManagerIntegration_v
(
    file_version = 1.211,
    project_version = 1.211,
    registry = undefined,

    /*
    Registers the Script-Manager project version and preserves the highest loaded manager value.
    Registered script project versions do not control the manager UI title.
    */
    function registerProjectVersion version_value =
    (
        if script_manager_project_version == undefined then
        (
            script_manager_project_version = version_value
        )
        else if version_value > script_manager_project_version then
        (
            script_manager_project_version = version_value
        )

        script_manager_project_version
        -- return
    ),

    /*
    Returns the active Script-Manager runtime mode.
    Undefined mode is treated as #standalone for backward-compatible direct execution.
    */
    function getRuntimeMode =
    (
        runtime_mode = SCRIPT_MANAGER_RUNTIME_MODE
        if runtime_mode == undefined then runtime_mode = EPOLY_TOOLS_RUNTIME_MODE
        if runtime_mode == undefined then runtime_mode = #standalone

        runtime_mode
        -- return
    ),

    /*
    Sets the runtime mode used by subsequently loaded scripts.
    Supported project modes are #standalone, #library, and #embedded.
    */
    function setRuntimeMode runtime_mode =
    (
        SCRIPT_MANAGER_RUNTIME_MODE = runtime_mode
        EPOLY_TOOLS_RUNTIME_MODE = runtime_mode

        SCRIPT_MANAGER_RUNTIME_MODE
        -- return
    ),

    /*
    Returns whether a tool should create its standalone dialog after loading.
    Library and embedded loads remain headless while still defining API and rollout values.
    */
    function shouldAutoOpenUI =
    (
        (this.getRuntimeMode()) == #standalone
        -- return
    ),

    /*
    Returns the final folder name for one directory path.
    Trailing path separators are accepted.
    */
    function getFolderName directory_path =
    (
        folder_path = substituteString directory_path "/" "\\"

        if folder_path.count > 0 then
        (
            if folder_path[folder_path.count] == "\\" then
            (
                folder_path = substring folder_path 1 (folder_path.count - 1)
            )
        )

        pathConfig.stripPathToLeaf folder_path
        -- return
    ),

    /*
    Normalizes one directory path to Windows separators with exactly one trailing separator.
    Empty input remains empty.
    */
    function normalizeDirectoryPath directory_path =
    (
        if directory_path == undefined or directory_path == "" then return ""

        normalized_path = substituteString directory_path "/" "\\"
        if normalized_path[normalized_path.count] != "\\" then normalized_path += "\\"

        normalized_path
        -- return
    ),

    /*
    Reads the numeric suffix from <folder>_<version>.ms.
    Non-versioned or malformed names return undefined.
    */
    function getVersionValue script_path folder_name =
    (
        file_name = getFilenameFile script_path
        expected_prefix = folder_name + "_"

        if file_name.count <= expected_prefix.count then return undefined
        if (substring file_name 1 expected_prefix.count) != expected_prefix then return undefined

        version_text = substring file_name (expected_prefix.count + 1) (file_name.count - expected_prefix.count)
        version_value = undefined

        try
        (
            version_value = version_text as float
        )
        catch
        (
            exception_text = getCurrentException()
            version_value = undefined
        )

        version_value
        -- return
    ),

    /*
    Resolves the canonical/versioned script in one compatibility tool directory.
    Canonical <FolderName>.ms wins; otherwise the highest numeric versioned filename wins.
    */
    function getToolScript directory_path =
    (
        folder_name = this.getFolderName directory_path
        if folder_name == undefined or folder_name == "" then return undefined

        canonical_path = directory_path + folder_name + ".ms"
        if doesFileExist canonical_path then return canonical_path

        versioned_files = getFiles (directory_path + folder_name + "_*.ms")
        best_file = undefined
        best_version = undefined

        for script_path in versioned_files do
        (
            version_value = this.getVersionValue script_path folder_name

            if version_value != undefined then
            (
                if best_version == undefined or version_value > best_version then
                (
                    best_file = script_path
                    best_version = version_value
                )
            )
        )

        if best_file != undefined then return best_file

        undefined
        -- return
    ),

    /*
    Registers or refreshes one script/API entry in the shared registry.
    Re-registering the same stable ID replaces its descriptor without duplicating the entry.
    */
    function registerScript script_id display_name api_value rollout_value file_version_value project_version_value source_path capabilities:#() =
    (
        if script_id == undefined or script_id == "" then return undefined

        entry_data = ScriptManagerEntry_v()
        entry_data.tool_id = script_id
        entry_data.display_name = display_name
        entry_data.api_value = api_value
        entry_data.rollout_value = rollout_value
        entry_data.file_version = file_version_value
        entry_data.project_version = project_version_value
        entry_data.source_path = source_path
        entry_data.capabilities = copy capabilities

        PutDictValue this.registry script_id entry_data

        entry_data
        -- return
    ),

    /*
    Compatibility wrapper for existing EPoly tools that still call registerTool().
    New generic scripts should prefer registerScript().
    */
    function registerTool tool_id display_name api_value rollout_value file_version_value project_version_value source_path capabilities:#() =
    (
        if epoly_tools_project_version == undefined or epoly_tools_project_version < project_version_value then
        (
            epoly_tools_project_version = project_version_value
        )

        this.registerScript tool_id display_name api_value rollout_value file_version_value project_version_value source_path capabilities:capabilities
        -- return
    ),

    /*
    Returns true when a stable tool ID exists in the registry.
    */
    /*
    Returns true when one generic script/API ID exists in the registry.
    */
    function hasScript script_id =
    (
        HasDictValue this.registry script_id
        -- return
    ),

    /*
    Returns one generic script/API registry descriptor or undefined.
    */
    function getScript script_id =
    (
        if not(HasDictValue this.registry script_id) then return undefined

        GetDictValue this.registry script_id
        -- return
    ),

    /*
    Returns sorted IDs for all registered generic script/API entries.
    */
    function getScriptIds =
    (
        script_ids = GetDictKeys this.registry
        sort script_ids

        script_ids
        -- return
    ),

    /*
    Compatibility wrapper that returns whether one legacy tool ID exists in the generic registry.
    */
    function hasTool tool_id =
    (
        this.hasScript tool_id
        -- return
    ),

    /*
    Returns one registered tool descriptor or undefined when the ID is unknown.
    */
    function getTool tool_id =
    (
        if not(HasDictValue this.registry tool_id) then return undefined

        GetDictValue this.registry tool_id
        -- return
    ),

    /*
    Returns one registered tool's public API struct instance.
    */
    function getApi tool_id =
    (
        tool_data = this.getTool tool_id
        if tool_data == undefined then return undefined

        tool_data.api_value
        -- return
    ),

    /*
    Returns one registered tool rollout for embedding in another rollout or manager.
    */
    function getRollout tool_id =
    (
        tool_data = this.getTool tool_id
        if tool_data == undefined then return undefined

        tool_data.rollout_value
        -- return
    ),

    /*
    Returns sorted stable IDs for every currently registered script/API entry.
    */
    function getToolIds =
    (
        this.getScriptIds()
        -- return
    ),

    /*
    Returns whether one registered tool declares the requested capability name.
    */
    function hasCapability tool_id capability_name =
    (
        tool_data = this.getTool tool_id
        if tool_data == undefined then return false

        tool_data.hasCapability capability_name
        -- return
    ),

    /*
    Normalizes one file path for case-insensitive registry source comparisons.
    */
    function normalizeFilePath file_path =
    (
        if file_path == undefined or file_path == "" then return ""

        toLower (substituteString file_path "/" "\\")
        -- return
    ),

    /*
    Returns whether one file path belongs to the supplied directory tree.
    */
    function isFilePathUnderDirectory file_path directory_path =
    (
        normalized_file_path = this.normalizeFilePath file_path
        normalized_directory_path = toLower (this.normalizeDirectoryPath directory_path)

        if normalized_file_path == "" or normalized_directory_path == "" then return false
        if normalized_file_path.count < normalized_directory_path.count then return false

        (substring normalized_file_path 1 normalized_directory_path.count) == normalized_directory_path
        -- return
    ),

    /*
    Removes stale registry descriptors whose source lives below one project root but is not in the supplied keep list.
    Registrations from unrelated roots remain untouched.
    */
    function pruneRegistryForRoot root_directory keep_source_paths:#() =
    (
        if this.registry == undefined then return false

        normalized_root = this.normalizeDirectoryPath root_directory
        if normalized_root == "" then return false

        keep_paths = #()

        for keep_source_path in keep_source_paths do
        (
            normalized_keep_path = this.normalizeFilePath keep_source_path
            if normalized_keep_path != "" and (findItem keep_paths normalized_keep_path) == 0 then append keep_paths normalized_keep_path
        )

        tool_ids = GetDictKeys this.registry

        for tool_id in tool_ids do
        (
            tool_data = GetDictValue this.registry tool_id

            if tool_data != undefined and this.isFilePathUnderDirectory tool_data.source_path normalized_root then
            (
                normalized_source_path = this.normalizeFilePath tool_data.source_path

                if (findItem keep_paths normalized_source_path) == 0 then
                (
                    RemoveDictValue this.registry tool_id
                )
            )
        )

        true
        -- return
    ),

    /*
    Loads one script under a temporary runtime mode and restores both generic and EPoly compatibility modes afterward.
    Optional rethrow prints the native source/line/stack and propagates the original exception to the Listener; otherwise returns #(success, error, script_path).
    */
    function loadScript script_path runtime_mode:#library quiet:true rethrow_exception:false =
    (
        if script_path == undefined or not(doesFileExist script_path) then return #(false, "Script not found.", script_path)

        previous_script_mode = SCRIPT_MANAGER_RUNTIME_MODE
        previous_epoly_mode = EPOLY_TOOLS_RUNTIME_MODE
        load_succeeded = false
        load_error = undefined

        SCRIPT_MANAGER_RUNTIME_MODE = runtime_mode
        EPOLY_TOOLS_RUNTIME_MODE = runtime_mode

        try
        (
            fileIn script_path quiet:quiet
            load_succeeded = true
        )
        catch
        (
            load_error = getCurrentException()

            if rethrow_exception then
            (
                error_file = getErrorSourceFileName()
                error_line = getErrorSourceFileLine()
                error_stack = getCurrentExceptionStackTrace()
                format "[Script-Manager][TREE LOAD] NATIVE EXCEPTION | source:% | line:% | error:%\n" error_file error_line load_error
                if error_stack != undefined and error_stack != "" then format "[Script-Manager][TREE LOAD] STACK TRACE:\n%\n" error_stack

                SCRIPT_MANAGER_RUNTIME_MODE = previous_script_mode
                EPOLY_TOOLS_RUNTIME_MODE = previous_epoly_mode
                throw()
            )
        )

        SCRIPT_MANAGER_RUNTIME_MODE = previous_script_mode
        EPOLY_TOOLS_RUNTIME_MODE = previous_epoly_mode

        #(load_succeeded, load_error, script_path)
        -- return
    ),

    /*
    Compatibility wrapper for callers using the previous loadTool() API.
    */
    function loadTool script_path runtime_mode:#library quiet:true =
    (
        this.loadScript script_path runtime_mode:runtime_mode quiet:quiet
        -- return
    ),

    /*
    Compatibility helper that resolves and loads one folder-named EPoly tool.
    Returns #(success, error, script_path).
    */
    function loadToolDirectory directory_path runtime_mode:#library quiet:true =
    (
        script_path = this.getToolScript directory_path
        if script_path == undefined then return #(false, "No current compatibility tool script found.", undefined)

        this.loadScript script_path runtime_mode:runtime_mode quiet:quiet
        -- return
    ),

    /*
    Compatibility helper that collects canonical folder-named EPoly tool scripts recursively.
    A directory may contain nested category directories at any depth.
    */
    function collectToolScriptsRecursive directory_path script_paths =
    (
        normalized_path = this.normalizeDirectoryPath directory_path
        if normalized_path == "" then return script_paths

        directory_name = this.getFolderName normalized_path
        if matchPattern directory_name pattern:"Script-Manager" ignoreCase:true then return script_paths

        script_path = this.getToolScript normalized_path

        if script_path != undefined then
        (
            append script_paths script_path
            return script_paths
        )

        child_directories = getDirectories (normalized_path + "*")
        sort child_directories

        for child_directory in child_directories do
        (
            this.collectToolScriptsRecursive child_directory script_paths
        )

        script_paths
        -- return
    ),

    /*
    Compatibility helper that returns canonical folder-named tool scripts below one root.
    The root manager file itself is never treated as a tool.
    */
    function getToolScriptsRecursive root_directory =
    (
        root_path = this.normalizeDirectoryPath root_directory
        tool_scripts = #()

        if root_path == "" then return tool_scripts

        child_directories = getDirectories (root_path + "*")
        sort child_directories

        for child_directory in child_directories do
        (
            this.collectToolScriptsRecursive child_directory tool_scripts
        )

        tool_scripts
        -- return
    ),

    /*
    Compatibility helper that loads every canonical folder-named tool script below one root.
    Directory nesting is transparent to API callers and runtime-mode restoration is preserved per tool.
    */
    function loadAllTools root_directory runtime_mode:#library quiet:true =
    (
        load_results = #()
        tool_scripts = this.getToolScriptsRecursive root_directory

        for script_path in tool_scripts do
        (
            append load_results (this.loadScript script_path runtime_mode:runtime_mode quiet:quiet)
        )

        load_results
        -- return
    ),

    on create do
    (
        if SCRIPT_MANAGER_REGISTRY == undefined then SCRIPT_MANAGER_REGISTRY = Dictionary #string
        this.registry = SCRIPT_MANAGER_REGISTRY
        this.registerProjectVersion this.project_version
    )
)

ScriptManagerIntegration = ScriptManagerIntegration_v()
EPOLY_TOOLS_REGISTRY = SCRIPT_MANAGER_REGISTRY
EPolyToolsIntegration = ScriptManagerIntegration


/*==============================================================================
    MANAGER
================================================================================*/

global script_manager
global script_manager_ui
global script_manager_host_ui
global script_manager_loader_ui
global script_manager_presets_ui
global script_manager_options_ui
global script_manager_sources_ui
global script_manager_show_ui
global script_manager_ignore_ui
global script_manager_scripts_ui
global script_manager_title
global script_manager_host_title
global script_manager_version_text
global SCRIPT_MANAGER_AUTO_OPEN
global SCRIPT_MANAGER_STARTUP_LAUNCH
global SCRIPT_MANAGER_STARTUP_PRESET_APPLIED
global scriptManagerTreeExpandContextHandler
global scriptManagerTreeCollapseContextHandler
global scriptManagerTreeExpandAllContextHandler
global scriptManagerTreeExpandEnabledContextHandler
global scriptManagerTreeCollapseAllContextHandler
global scriptManagerTreeLoadContextHandler
global scriptManagerTreeStartupContextHandler
global scriptManagerRefreshButtonMouseUpHandler
global scriptManagerInitialLoaderTickHandler
global scriptManagerTreeOpenGroupContextHandler
global scriptManagerPersistIgnoreMask
global scriptManagerTreeOpenExplorerContextHandler
global scriptManagerSourceTreeExpandAllContextHandler
global scriptManagerSourceTreeCollapseAllContextHandler
global scriptManagerSourceTreeLoadDialogContextHandler

/*
Expands the currently selected SCRIPTS tree branch from the .NET context-menu callback.
The handler is global because dotNet.addEventHandler requires a global function.
*/
function scriptManagerTreeExpandContextHandler sender_value event_args =
(
    if script_manager != undefined then script_manager.expandSelectedScriptTreeNode()
)

/*
Collapses the currently selected SCRIPTS tree branch from the .NET context-menu callback.
The handler is global because dotNet.addEventHandler requires a global function.
*/
function scriptManagerTreeCollapseContextHandler sender_value event_args =
(
    if script_manager != undefined then script_manager.collapseSelectedScriptTreeNode()
)

/*
Expands the complete SCRIPTS tree from the .NET context-menu callback.
*/
function scriptManagerTreeExpandAllContextHandler sender_value event_args =
(
    if script_manager != undefined then script_manager.expandAllScriptTree()
)

/*
Expands only SCRIPTS branches containing HOST or DIRECT scripts from the context menu.
*/
function scriptManagerTreeExpandEnabledContextHandler sender_value event_args =
(
    if script_manager != undefined then script_manager.expandEnabledScriptTree()
)

/*
Collapses the complete SCRIPTS tree from the .NET context-menu callback.
*/
function scriptManagerTreeCollapseAllContextHandler sender_value event_args =
(
    if script_manager != undefined then script_manager.collapseAllScriptTree()
)

/*
Loads only the currently selected SCRIPTS leaf from the .NET context-menu callback.
The selected script does not need to be enabled in the persisted load set.
*/
function scriptManagerTreeLoadContextHandler sender_value event_args =
(
    if script_manager != undefined then script_manager.loadSelectedScriptTreeItem()
)

/*
Toggles the selected script's dedicated 3ds Max user-startup launcher.
Only Script-Manager-owned launchers are added or removed.
*/
function scriptManagerTreeStartupContextHandler sender_value event_args =
(
    if script_manager != undefined then script_manager.toggleSelectedScriptStartup()
)

/*
Dispatches the main .NET title button MouseUp by the actual mouse button.
LMB commits pending IGNORE and ROOT PATH edits; RMB keeps the version reload behavior.
*/
function scriptManagerRefreshButtonMouseUpHandler sender_value event_args =
(
    if script_manager == undefined or event_args == undefined then return false

    mouse_buttons_type = dotNetClass "System.Windows.Forms.MouseButtons"

    if event_args.Button == mouse_buttons_type.Left then return script_manager.handleManualRefresh()
    if event_args.Button == mouse_buttons_type.Right then return script_manager.reloadLatestManagerScript()

    false
    -- return
)

/*
Completes the one-time loader initialization after the manager dialog returns to the Windows UI message loop.
*/
function scriptManagerInitialLoaderTickHandler sender_value event_args =
(
    if script_manager != undefined then script_manager.finishInitialLoaderInitialization sender_value
    -- return
)

/*
Loads every script below the right-clicked SCRIPTS folder into a single shared dialog.
The one-time HOST override does not modify saved load-mode settings.
*/
function scriptManagerTreeOpenGroupContextHandler sender_value event_args =
(
    if script_manager != undefined then script_manager.openSelectedScriptTreeGroup()
)

/*
Opens the currently selected SCRIPTS tree item in Windows Explorer from the .NET context-menu callback.
*/
function scriptManagerTreeOpenExplorerContextHandler sender_value event_args =
(
    if script_manager != undefined then script_manager.openSelectedScriptTreeItemInExplorer()
)

/*
Expands the complete SOURCES tree from the .NET context-menu callback.
*/
function scriptManagerSourceTreeExpandAllContextHandler sender_value event_args =
(
    if script_manager != undefined then script_manager.expandAllSourceTree()
)

/*
Collapses the complete SOURCES tree from the .NET context-menu callback.
*/
function scriptManagerSourceTreeCollapseAllContextHandler sender_value event_args =
(
    if script_manager != undefined then script_manager.collapseAllSourceTree()
)

/*
Loads or reloads only the batch dialog represented by the selected checked SOURCES item.
*/
function scriptManagerSourceTreeLoadDialogContextHandler sender_value event_args =
(
    if script_manager != undefined then script_manager.loadSelectedSourceDialog()
)

if SCRIPT_MANAGER_STARTUP_LAUNCH == undefined then SCRIPT_MANAGER_STARTUP_LAUNCH = false
if SCRIPT_MANAGER_STARTUP_PRESET_APPLIED == undefined then SCRIPT_MANAGER_STARTUP_PRESET_APPLIED = false

SCRIPT_MANAGER_AUTO_OPEN = ScriptManagerIntegration.shouldAutoOpenUI()

if SCRIPT_MANAGER_AUTO_OPEN then
(
    if script_manager != undefined then
    (
        cleanup_ok = false

        try
        (
            cleanup_ok = script_manager.destroyManagerDialog()

            if cleanup_ok and script_manager_ui != undefined then
            (
                if script_manager_ui.inDialog then cleanup_ok = false
            )

            if cleanup_ok and script_manager_host_ui != undefined then
            (
                if script_manager_host_ui.inDialog then cleanup_ok = false
            )
        )
        catch
        (
            exception_text = getCurrentException()
            cleanup_ok = false
            format "[Script-Manager] Previous manager cleanup failed: %\n" exception_text
        )

        if not cleanup_ok then throw "Previous Script-Manager dialogs could not be cleaned up safely."
    )
    else
    (
        fallback_cleanup_ok = true

        if script_manager_host_ui != undefined then
        (
            try
            (
                if script_manager_host_ui.inDialog then
                (
                    if script_manager_host_ui.dialogBar then cui.UnRegisterDialogBar script_manager_host_ui
                    destroyDialog script_manager_host_ui
                )
            )
            catch
            (
                exception_text = getCurrentException()
                fallback_cleanup_ok = false
                format "[Script-Manager] Previous host rollout cleanup failed: %\n" exception_text
            )
        )

        if script_manager_ui != undefined then
        (
            try
            (
                if script_manager_ui.inDialog then
                (
                    if script_manager_ui.dialogBar then cui.UnRegisterDialogBar script_manager_ui
                    destroyDialog script_manager_ui
                )
            )
            catch
            (
                exception_text = getCurrentException()
                fallback_cleanup_ok = false
                format "[Script-Manager] Previous loader rollout cleanup failed: %\n" exception_text
            )
        )

        if not fallback_cleanup_ok then throw "Previous Script-Manager rollouts could not be cleaned up safely."
    )
)

/*
Persists one SCRIPTS ignore mask outside the large manager struct's method-local frame.
This also centralizes the verified INI write and in-memory activation.
*/
function scriptManagerPersistIgnoreMask manager_value requested_mask =
(
    if manager_value == undefined then
    (
        format "[Script-Manager] IGNORE save failed | manager is unavailable.\n"
        return false
    )

    local mask_value = if requested_mask == undefined then "" else requested_mask
    local target_ini = manager_value.ini_path
    if target_ini == undefined or target_ini == "" then
    (
        format "[Script-Manager] IGNORE save failed | INI path is empty.\n"
        return false
    )

    local parsed_patterns = manager_value.buildScriptIgnorePatterns mask_value
    if not(setINISetting target_ini "Filter" "ScriptIgnoreMask" mask_value forceUTF16:false) then
    (
        format "[Script-Manager] IGNORE save failed | INI:% | value:%\n" target_ini mask_value
        return false
    )

    local persisted_mask = getINISetting target_ini "Filter" "ScriptIgnoreMask"
    if persisted_mask != mask_value then
    (
        format "[Script-Manager] IGNORE save verification failed | INI:% | expected:% | actual:%\n" target_ini mask_value persisted_mask
        return false
    )

    manager_value.source_ignore_mask = mask_value
    manager_value.source_ignore_patterns = parsed_patterns
    manager_value.source_ignore_regexes = parsed_patterns
    format "[Script-Manager] IGNORE saved and verified | INI:% | value:%\n" target_ini persisted_mask
    true
    -- return
)

struct script_manager_v
(
    file_version = 1.211,
    project_version = 1.211,
    root_directory = "",
    ini_path = "",
    loaded_rollouts = #(),
    loaded_rollout_names = #(),
    loaded_rollout_group_paths = #(),
    loaded_script_paths = #(),
    loaded_script_names = #(),
    loaded_script_keys = #(),
    available_script_names = #(),
    available_script_keys = #(),
    available_script_group_paths = #(),
    available_script_tree_group_paths = #(),
    available_script_directories = #(),
    available_script_paths = #(),
    available_source_names = #(),
    available_source_directories = #(),
    available_source_selectable = #(),
    show_versioned_files = true,
    show_clean_scripts_only = false,
    show_unclear_scripts = false,
    collapse_script_dirs = true,
    script_filter_text = "",
    source_ignore_mask = ".git",
    source_ignore_patterns = #(),
    source_ignore_regexes = #(),
    available_group_paths = #(),
    available_group_tree_paths = #(),
    available_group_names = #(),
    available_group_directories = #(),
    available_group_displayable = #(),
    group_rollouts = #(),
    group_rollout_paths = #(),
    group_rollout_symbol_names = #(),
    group_build_id = 0,
    host_dialogs = #(),
    host_dialog_paths = #(),
    host_dialog_symbol_names = #(),
    host_dialog_build_id = 0,
    loaded_host_script_paths = #(),
    loaded_host_script_dialog_paths = #(),
    loader_rollout = undefined,
    preset_rollout = undefined,
    options_rollout = undefined,
    source_rollout = undefined,
    show_rollout = undefined,
    ignore_rollout = undefined,
    script_rollout = undefined,
    loader_rollout_open = true,
    preset_rollout_open = true,
    options_rollout_open = true,
    source_rollout_open = true,
    show_ignore_rollout_open = true,
    show_rollout_open = true,
    ignore_rollout_open = true,
    script_rollout_open = true,
    preset_rollout_content_height = 72,
    options_rollout_content_height = 54,
    source_rollout_content_height = 524,
    show_rollout_content_height = 30,
    ignore_rollout_content_height = 42,
    script_rollout_content_height = 1096,
    loader_content_height = 1942,
    script_tree_file_count = 0,
    script_tree_required_height = 1032,
    script_tree_base_font_height = 0,
    script_tree_font_height = 0,
    script_tree_font_pixel_increase = 2,
    script_tree_state_images = undefined,
    script_tree_folder_font = undefined,
    script_tree_batch_palette = undefined,
    script_tree_batch_hosts = undefined,
    source_tree_state_images = undefined,
    script_tree_context_menu = undefined,
    script_tree_open_separator = undefined,
    script_tree_expand_separator = undefined,
    script_tree_open_group_item = undefined,
    script_tree_load_item = undefined,
    script_tree_startup_item = undefined,
    last_tree_load_error = "",
    script_tree_open_explorer_item = undefined,
    script_tree_expand_item = undefined,
    script_tree_collapse_item = undefined,
    script_tree_expand_all_item = undefined,
    script_tree_expand_enabled_item = undefined,
    script_tree_collapse_all_item = undefined,
    source_tree_context_menu = undefined,
    source_tree_open_separator = undefined,
    source_tree_expand_separator = undefined,
    source_tree_load_dialog_item = undefined,
    source_tree_expand_all_item = undefined,
    source_tree_collapse_all_item = undefined,
    script_tree_syncing_checks = false,
    source_tree_syncing_checks = false,
    source_tree_initialized = false,
    script_tree_initialized = false,
    loader_init_timer = undefined,
    preset_dropdown_syncing = false,
    tree_expansion_syncing = false,
    debug_logging = false,
    manager_source_path = "",
    loader_collapsed_height = 24,
    rollout_header_height = 24,
    subrollout_extra_height = 24,
    hierarchy_layout_signature = "",
    hierarchy_layout_pending_passes = 0,
    is_reloading = false,
    -- Suppress transient move/resize writes while restoring CUI dialog geometry.
    dialog_restore_depth = 0,
    is_destroying_host = false,
    is_destroying_manager = false,

    /*
    Registers this Script-Manager project version through the generic integration runtime.
    */
    function registerProjectVersion =
    (
        script_manager_project_version = ScriptManagerIntegration.registerProjectVersion project_version
        script_manager_project_version
        -- return
    ),

    /*
    Resolves the managed script root from the Script-Manager source path.
    When the manager lives in its dedicated Script-Manager folder, the managed root is that folder's parent.
    */
    function getProjectRootDirectory =
    (
        source_directory = ScriptManagerIntegration.normalizeDirectoryPath (getFilenamePath manager_source_path)
        if source_directory == "" then return ""

        source_folder_name = ScriptManagerIntegration.getFolderName source_directory

        if matchPattern source_folder_name pattern:"Script-Manager" ignoreCase:true then
        (
            source_directory_no_slash = substring source_directory 1 (source_directory.count - 1)
            root_path = pathConfig.removePathLeaf source_directory_no_slash
            ScriptManagerIntegration.normalizeDirectoryPath root_path
        )
        else
        (
            source_directory
        )
        -- return
    ),

    /*
    Resolves the permanent INI beside Script-Manager.ms, shared by versioned entry files.
    Migrates the previous per-3ds-Max plugcfg INI once, without changing its original copy.
    */
    function initializeSettingsFile =
    (
        manager_directory = ScriptManagerIntegration.normalizeDirectoryPath (getFilenamePath manager_source_path)
        if manager_directory == "" then
        (
            format "[Script-Manager] INI initialization failed | manager source:%\n" manager_source_path
            return false
        )

        target_ini = manager_directory + "script_manager.ini"
        previous_ini = (getDir #plugcfg) + "\\script_manager.ini"

        if not(doesFileExist target_ini) and doesFileExist previous_ini then
        (
            if not(copyFile previous_ini target_ini) then
            (
                format "[Script-Manager] INI migration failed | from:% | to:%\n" previous_ini target_ini
                return false
            )
            format "[Script-Manager] Migrated settings | from:% | to:%\n" previous_ini target_ini
        )

        ini_path = target_ini
        true
        -- return
    ),

    /*
    Saves one custom SOURCES root directory.
    The directory must exist; the persisted value is read back to verify the write before it becomes active.
    */
    function saveSourceRootDirectory directory_path =
    (
        if ini_path == undefined or ini_path == "" then
        (
            format "[Script-Manager] ROOT PATH save failed | INI path is empty.\n"
            return false
        )

        normalized_path = ScriptManagerIntegration.normalizeDirectoryPath directory_path
        directory_type = dotNetClass "System.IO.Directory"

        if normalized_path == "" or not(directory_type.Exists normalized_path) then
        (
            format "[Script-Manager] ROOT PATH invalid | path:%\n" directory_path
            return false
        )

        if not(setINISetting ini_path "Options" "SourceRootDirectory" normalized_path forceUTF16:false) then
        (
            format "[Script-Manager] ROOT PATH save failed | INI:% | value:%\n" ini_path normalized_path
            return false
        )

        stored_path = ScriptManagerIntegration.normalizeDirectoryPath (getINISetting ini_path "Options" "SourceRootDirectory")
        if stored_path != normalized_path then
        (
            format "[Script-Manager] ROOT PATH save verification failed | INI:% | expected:% | actual:%\n" ini_path normalized_path stored_path
            return false
        )

        root_directory = normalized_path
        true
        -- return
    ),

    /*
    Loads the persisted SOURCES root directory.
    Missing or unavailable stored paths fall back to the root derived from the Script-Manager source location.
    */
    function loadSourceRootDirectory =
    (
        default_root = this.getProjectRootDirectory()
        stored_path = getINISetting ini_path "Options" "SourceRootDirectory"
        selected_path = default_root
        directory_type = dotNetClass "System.IO.Directory"

        if stored_path != "" then
        (
            normalized_stored_path = ScriptManagerIntegration.normalizeDirectoryPath stored_path

            if normalized_stored_path != "" and directory_type.Exists normalized_stored_path then
            (
                selected_path = normalized_stored_path
            )
            else
            (
                selected_path = normalized_stored_path
                format "[Script-Manager] ROOT PATH unavailable (setting preserved) | stored:% | INI:%\n" stored_path ini_path
            )
        )

        root_directory = ScriptManagerIntegration.normalizeDirectoryPath selected_path
        root_directory
        -- return
    ),

    /*
    Returns whether one directory is the dedicated manager package directory.
    Manager package files are excluded from managed discovery and execution.
    */
    function isManagerPackageDirectory directory_path =
    (
        normalized_path = ScriptManagerIntegration.normalizeDirectoryPath directory_path
        manager_directory = ScriptManagerIntegration.normalizeDirectoryPath (getFilenamePath manager_source_path)

        normalized_path != "" and manager_directory != "" and normalized_path == manager_directory
        -- return
    ),


    /*
    Returns one normalized path relative to the manager root without a trailing separator.
    Paths outside the manager root return an empty string.
    */
    function getRelativeDirectoryPath directory_path =
    (
        root_path = ScriptManagerIntegration.normalizeDirectoryPath root_directory
        target_path = ScriptManagerIntegration.normalizeDirectoryPath directory_path

        if root_path == "" or target_path == "" then return ""
        if target_path.count <= root_path.count then return ""
        if (substring target_path 1 root_path.count) != root_path then return ""

        relative_path = substring target_path (root_path.count + 1) (target_path.count - root_path.count)
        if relative_path.count > 0 and relative_path[relative_path.count] == "\\" then relative_path = substring relative_path 1 (relative_path.count - 1)

        relative_path
        -- return
    ),

    /*
    Returns the relative parent path for one discovered directory path.
    Direct children of the manager root return an empty string.
    */
    function getParentRelativePath relative_path =
    (
        if relative_path == undefined or relative_path == "" then return ""

        path_parts = filterString relative_path "\\"
        if path_parts.count <= 1 then return ""

        parent_path = path_parts[1]
        for part_index = 2 to (path_parts.count - 1) do
        (
            parent_path += "\\" + path_parts[part_index]
        )

        parent_path
        -- return
    ),

    /*
    Recursively discovers supported scripts and script-bearing directories.
    Every discovered script is assigned to the rollout group matching its containing directory.
    */
    /*
    Returns whether one path is a loadable MaxScript source handled by Script-Manager.
    */
    function isSupportedScriptPath script_path =
    (
        if script_path == undefined or script_path == "" then return false

        extension_text = toLower (getFilenameType script_path)
        extension_text == ".ms" or extension_text == ".mcr" or extension_text == ".mse"
        -- return
    ),

    /*
    Returns the stable root-relative key for one managed script path.
    */
    function getScriptKey script_path =
    (
        if not(this.isSupportedScriptPath script_path) then return ""

        script_directory = ScriptManagerIntegration.normalizeDirectoryPath (getFilenamePath script_path)
        relative_directory = this.getRelativeDirectoryPath script_directory
        script_leaf = pathConfig.stripPathToLeaf script_path

        if relative_directory == "" then script_leaf else (relative_directory + "\\" + script_leaf)
        -- return
    ),

    /*
    Returns whether one directory subtree contains at least one managed script outside the manager package.
    */
    /*
    Returns a stable persisted key for one selectable source directory.
    The managed root itself represents root-level script files only.
    */
    function getSourceKey source_directory =
    (
        normalized_path = ScriptManagerIntegration.normalizeDirectoryPath source_directory
        normalized_root = ScriptManagerIntegration.normalizeDirectoryPath root_directory

        if normalized_path == "" or normalized_root == "" then return ""
        if normalized_path == normalized_root then return "__ROOT__"

        relative_path = this.getRelativeDirectoryPath normalized_path
        relative_path
        -- return
    ),

    /*
    Returns the persisted enabled state for one source directory.
    Sources default to disabled so unrelated repository trees are never scanned until selected.
    */
    function getSourceEnabled source_directory =
    (
        source_key = this.getSourceKey source_directory
        if source_key == "" then return false

        (getINISetting ini_path "Sources" source_key) == "1"
        -- return
    ),

    /*
    Persists whether one source directory participates in script discovery.
    */
    function saveSourceEnabled source_directory enabled =
    (
        source_key = this.getSourceKey source_directory
        if source_key == "" then return false

        mode_text = if enabled then "1" else "0"
        if not(setINISetting ini_path "Sources" source_key mode_text forceUTF16:false) then
        (
            format "[Script-Manager] SOURCES save failed | INI:% | key:% | value:%\n" ini_path source_key mode_text
            return false
        )

        stored_text = getINISetting ini_path "Sources" source_key
        if stored_text != mode_text then
        (
            format "[Script-Manager] SOURCES verification failed | INI:% | key:% | expected:% | actual:%\n" ini_path source_key mode_text stored_text
            return false
        )
        true
        -- return
    ),

    /*
    Returns whether one source directory has at least one child directory outside the manager package.
    */
    function hasSourceChildDirectory directory_path =
    (
        normalized_path = ScriptManagerIntegration.normalizeDirectoryPath directory_path
        if normalized_path == "" then return false

        child_directories = getDirectories (normalized_path + "*")
        for child_directory in child_directories do
        (
            if not(this.isManagerPackageDirectory child_directory) then return true
        )

        false
        -- return
    ),

    /*
    Returns the canonical same-name .ms file for one tool directory, or an empty string when none exists.
    Example: Tool\Tool.ms.
    */
    function getSourceToolScriptPath directory_path =
    (
        normalized_path = ScriptManagerIntegration.normalizeDirectoryPath directory_path
        if normalized_path == "" then return ""

        folder_name = ScriptManagerIntegration.getFolderName normalized_path
        if folder_name == "" then return ""

        folder_name_lower = toLower folder_name
        for script_path in (getFiles (normalized_path + "*.ms")) do
        (
            if (toLower (getFilenameFile script_path)) == folder_name_lower then return script_path
        )

        ""
        -- return
    ),

    /*
    Returns whether one source directory has no files and no child directories.
    */
    function isSourceDirectoryEmpty directory_path =
    (
        normalized_path = ScriptManagerIntegration.normalizeDirectoryPath directory_path
        if normalized_path == "" then return false

        if (getFiles (normalized_path + "*")).count > 0 then return false
        if (getDirectories (normalized_path + "*")).count > 0 then return false

        true
        -- return
    ),

    /*
    Hidden Git repositories are excluded from SOURCES and script recursion by default.
    This built-in exclusion does not change the editable SCRIPTS IGNORE setting.
    */
    function isDefaultExcludedSourceDirectory directory_path =
    (
        normalized_path = ScriptManagerIntegration.normalizeDirectoryPath directory_path
        if normalized_path == "" then return false
        (toLower (ScriptManagerIntegration.getFolderName normalized_path)) == ".git"
        -- return
    ),

    /*
    Finds real .ms/.mcr/.mse files in a subtree, independently of SCRIPTS display filters.
    Results are cached for this SOURCES discovery pass to avoid re-scanning child trees.
    */
    function sourceDirectoryHasMaxScripts directory_path presence_cache =
    (
        normalized_path = ScriptManagerIntegration.normalizeDirectoryPath directory_path
        if normalized_path == "" then return false
        if this.isManagerPackageDirectory normalized_path then return false
        if this.isDefaultExcludedSourceDirectory normalized_path then return false

        cache_key = toLower normalized_path
        if HasDictValue presence_cache cache_key then return (GetDictValue presence_cache cache_key)

        script_found = false
        for extension_pattern in #("*.ms", "*.mcr", "*.mse") while not script_found do
        (
            if (getFiles (normalized_path + extension_pattern)).count > 0 then script_found = true
        )

        if not script_found then
        (
            for child_directory in (getDirectories (normalized_path + "*")) while not script_found do
            (
                if this.sourceDirectoryHasMaxScripts child_directory presence_cache then script_found = true
            )
        )

        PutDictValue presence_cache cache_key script_found
        script_found
        -- return
    ),

    /*
    Appends visible SOURCES rows in parent-before-child order.
    A directory becomes a hierarchy stopper when it contains an unversioned same-name .ms file, for example Tool\Tool.ms.
    Directories without any .ms/.mcr/.mse descendants are excluded from SOURCES.
    Every visible stopper row is display-only without a checkbox and its children are not shown, regardless of nesting depth.
    */
    function collectSourceDirectoriesRecursive directory_path presence_cache =
    (
        normalized_path = ScriptManagerIntegration.normalizeDirectoryPath directory_path
        normalized_root = ScriptManagerIntegration.normalizeDirectoryPath root_directory
        if normalized_path == "" then return false

        child_directories = getDirectories (normalized_path + "*")
        sort child_directories

        for child_directory in child_directories do
        (
            if not(this.isManagerPackageDirectory child_directory) and not(this.isDefaultExcludedSourceDirectory child_directory) and (this.sourceDirectoryHasMaxScripts child_directory presence_cache) then
            (
                normalized_child = ScriptManagerIntegration.normalizeDirectoryPath child_directory

                tool_script_path = this.getSourceToolScriptPath normalized_child
                is_empty_directory = this.isSourceDirectoryEmpty normalized_child
                is_hierarchy_stopper = (tool_script_path != "") or is_empty_directory
                source_selectable = not is_hierarchy_stopper

                append available_source_names (ScriptManagerIntegration.getFolderName normalized_child)
                append available_source_directories normalized_child
                append available_source_selectable source_selectable

                if not source_selectable and this.getSourceEnabled normalized_child then
                (
                    this.saveSourceEnabled normalized_path true
                    this.saveSourceEnabled normalized_child false
                )

                if not is_hierarchy_stopper then
                (
                    this.collectSourceDirectoriesRecursive normalized_child presence_cache
                )
            )
        )

        true
        -- return
    ),

    /*
    Discovers the visible SOURCES hierarchy below the managed root.
    Selectable category rows and display-only nested terminal-directory rows stay aligned by array index.
    */
    function discoverSources =
    (
        timing_start = timestamp()
        available_source_names = #()
        available_source_directories = #()
        available_source_selectable = #()

        if root_directory == "" then return false

        presence_cache = Dictionary #string
        this.collectSourceDirectoriesRecursive root_directory presence_cache
        timing_elapsed_ms = timestamp() - timing_start
        format "[Script-Manager][TIMING] SOURCES DATA PREP | % ms | folders:%\n" timing_elapsed_ms available_source_directories.count
        true
        -- return
    ),

    /*
    Returns whether one child directory is strictly below one parent directory.
    Normalized directory paths include a trailing separator, preventing partial-name prefix matches.
    */
    function isDirectoryBelowDirectory child_directory parent_directory =
    (
        child_path = ScriptManagerIntegration.normalizeDirectoryPath child_directory
        parent_path = ScriptManagerIntegration.normalizeDirectoryPath parent_directory

        if child_path == "" or parent_path == "" then return false
        if child_path.count <= parent_path.count then return false

        (substring child_path 1 parent_path.count) == parent_path
        -- return
    ),

    /*
    Returns enabled source directories without duplicate nested scans.
    When an enabled parent source already covers a checked descendant, only the parent is scanned.
    */
    function getEnabledSourceDirectories =
    (
        enabled_directories = #()

        for source_index = 1 to available_source_directories.count do
        (
            source_directory = available_source_directories[source_index]
            source_selectable = false
            if source_index <= available_source_selectable.count then source_selectable = available_source_selectable[source_index]

            if source_selectable and this.getSourceEnabled source_directory then
            (
                covered_by_parent = false

                for enabled_directory in enabled_directories while not covered_by_parent do
                (
                    if this.isDirectoryBelowDirectory source_directory enabled_directory then covered_by_parent = true
                )

                if not covered_by_parent then append enabled_directories source_directory
            )
        )

        enabled_directories
        -- return
    ),

    /*
    Activates first-level selectable SOURCES for a fresh root when no source has been chosen.
    Explicit all-OFF selections remain OFF unless the user changed to a different root.
    */
    function initializeSourceSelection new_root:false =
    (
        if (this.getEnabledSourceDirectories()).count > 0 then return true
        if not new_root and (this.getIniSectionEntries "Sources").count > 0 then
        (
            format "[Script-Manager] SCRIPTS empty | no SOURCES are checked; enable a SOURCES checkbox.\n"
            return true
        )

        enabled_count = 0
        for source_index = 1 to available_source_directories.count do
        (
            if available_source_selectable[source_index] then
            (
                source_directory = available_source_directories[source_index]
                relative_path = this.getRelativeDirectoryPath source_directory
                if relative_path != "" and (this.getParentRelativePath relative_path) == "" then
                (
                    if not(this.saveSourceEnabled source_directory true) then return false
                    enabled_count += 1
                )
            )
        )

        if enabled_count > 0 then format "[Script-Manager] SOURCES initialized | root:% | checked top-level:%\n" root_directory enabled_count
        true
        -- return
    ),

    /*
    Returns whether a filename suffix is a numeric version identifier such as 0.28 or 1.121.
    */
    function isNumericVersionText version_text =
    (
        if version_text == undefined or version_text == "" then return false

        digit_found = false
        dot_count = 0

        for char_index = 1 to version_text.count do
        (
            char_text = version_text[char_index]

            if (findString "0123456789" char_text) != undefined then
            (
                digit_found = true
            )
            else if char_text == "." then
            (
                dot_count += 1
                if dot_count > 1 then return false
            )
            else
            (
                return false
            )
        )

        digit_found and version_text[1] != "." and version_text[version_text.count] != "."
        -- return
    ),

    /*
    Returns #(is_versioned, family_stem, numeric_version) for one script path.
    Versioned files use a final _<number> suffix before the extension.
    */
    function getScriptVersionInfo script_path =
    (
        script_stem = getFilenameFile script_path
        underscore_index = 0

        for char_index = script_stem.count to 1 by -1 while underscore_index == 0 do
        (
            if script_stem[char_index] == "_" then underscore_index = char_index
        )

        if underscore_index <= 1 or underscore_index >= script_stem.count then return #(false, script_stem, undefined)

        version_text = substring script_stem (underscore_index + 1) (script_stem.count - underscore_index)
        if not(this.isNumericVersionText version_text) then return #(false, script_stem, undefined)

        family_stem = substring script_stem 1 (underscore_index - 1)
        version_value = execute version_text
        #(true, family_stem, version_value as float)
        -- return
    ),

    /*
    Returns whether the first script file is newer than the second by last-write timestamp.
    Equal timestamps preserve the current order.
    */
    function isScriptFileNewer first_script_path second_script_path =
    (
        if first_script_path == undefined or first_script_path == "" then return false
        if second_script_path == undefined or second_script_path == "" then return true

        first_file_info = dotNetObject "System.IO.FileInfo" first_script_path
        second_file_info = dotNetObject "System.IO.FileInfo" second_script_path

        (first_file_info.LastWriteTimeUtc.CompareTo second_file_info.LastWriteTimeUtc) > 0
        -- return
    ),

    /*
    Returns a copy of one script-path array sorted by last-write time, newest first.
    Sorting is local to one directory so folder hierarchy order stays unchanged.
    */
    function sortScriptPathsNewestFirst script_paths =
    (
        sorted_paths = #()

        for script_path in script_paths do
        (
            insert_index = sorted_paths.count + 1

            for existing_index = 1 to sorted_paths.count while insert_index == (sorted_paths.count + 1) do
            (
                if this.isScriptFileNewer script_path sorted_paths[existing_index] then insert_index = existing_index
            )

            insertItem script_path sorted_paths insert_index
        )

        sorted_paths
        -- return
    ),

    /*
    Normalizes one SCRIPTS ignore token for native wildcard matching.
    Legacy regex-style ".*" shorthand is converted to "*" so existing masks such as .*-DELETED keep working.
    */
    function normalizeScriptIgnorePattern pattern_text =
    (
        if pattern_text == undefined then return ""

        normalized_pattern = trimRight (trimLeft pattern_text)
        if normalized_pattern == "" then return ""

        substituteString normalized_pattern ".*" "*"
        -- return
    ),

    /*
    Compatibility wrapper for callers using the previous SOURCES ignore helper name.
    */
    function normalizeSourceIgnorePattern pattern_text =
    (
        this.normalizeScriptIgnorePattern pattern_text
        -- return
    ),

    /*
    Builds the pipe-delimited SCRIPTS ignore-pattern list.
    Empty tokens, including a trailing |, are ignored.
    */
    function buildScriptIgnorePatterns mask_text =
    (
        ignore_patterns = #()
        if mask_text == undefined or mask_text == "" then return ignore_patterns

        for mask_token in (filterString mask_text "|") do
        (
            normalized_pattern = this.normalizeScriptIgnorePattern mask_token
            if normalized_pattern != "" then append ignore_patterns normalized_pattern
        )

        ignore_patterns
        -- return
    ),

    /*
    Compatibility wrapper for callers using the previous SOURCES ignore helper name.
    */
    function buildSourceIgnorePatterns mask_text =
    (
        this.buildScriptIgnorePatterns mask_text
        -- return
    ),

    /*
    Compatibility wrapper for older callers that referenced buildSourceIgnoreRegexes.
    Ignore matching uses native wildcard patterns instead of .NET Regex objects.
    */
    function buildSourceIgnoreRegexes mask_text =
    (
        this.buildScriptIgnorePatterns mask_text
        -- return
    ),

    /*
    Preserves the public saveScriptIgnoreMask API while routing persistence through
    a standalone function, avoiding the oversized struct's local-frame binding.
    */
    function saveScriptIgnoreMask input_mask =
    (
        scriptManagerPersistIgnoreMask this input_mask
        -- return
    ),

    /*
    Compatibility wrapper for callers using the previous SOURCES ignore persistence helper name.
    */
    function saveSourceIgnoreMask mask_text =
    (
        this.saveScriptIgnoreMask mask_text
        -- return
    ),

    /*
    Loads the persisted SCRIPTS ignore mask.
    The previous SourceIgnoreMask key is accepted as a migration fallback; missing settings default to .git.
    */
    function loadScriptIgnoreMask =
    (
        default_mask = ".git"
        stored_mask = default_mask

        if hasINISetting ini_path "Filter" "ScriptIgnoreMask" then
        (
            stored_mask = getINISetting ini_path "Filter" "ScriptIgnoreMask"
        )
        else if hasINISetting ini_path "Filter" "SourceIgnoreMask" then
        (
            stored_mask = getINISetting ini_path "Filter" "SourceIgnoreMask"
        )

        source_ignore_mask = stored_mask
        source_ignore_patterns = this.buildScriptIgnorePatterns stored_mask
        source_ignore_regexes = source_ignore_patterns
        source_ignore_mask
        -- return
    ),

    /*
    Compatibility wrapper for callers using the previous SOURCES ignore load helper name.
    */
    function loadSourceIgnoreMask =
    (
        this.loadScriptIgnoreMask()
        -- return
    ),

    /*
    Returns whether one visible SCRIPTS item name matches the current ignore list.
    Plain entries match exactly; * and ? use native case-insensitive wildcard matching.
    */
    function doesScriptTreeNameMatchIgnore item_name =
    (
        if item_name == undefined or item_name == "" then return false

        item_name_lower = toLower item_name

        for ignore_pattern in source_ignore_patterns do
        (
            has_wildcard = (findString ignore_pattern "*") != undefined or (findString ignore_pattern "?") != undefined

            if has_wildcard then
            (
                if matchPattern item_name pattern:ignore_pattern ignoreCase:true then return true
            )
            else
            (
                if item_name_lower == (toLower ignore_pattern) then return true
            )
        )

        false
        -- return
    ),

    /*
    Returns whether one directory row and its complete subtree should be omitted from SCRIPTS.
    SOURCES is intentionally unaffected by this filter.
    */
    function isScriptTreeDirectoryIgnored directory_path =
    (
        normalized_path = ScriptManagerIntegration.normalizeDirectoryPath directory_path
        if normalized_path == "" then return false

        folder_name = ScriptManagerIntegration.getFolderName normalized_path
        this.doesScriptTreeNameMatchIgnore folder_name
        -- return
    ),

    /*
    Returns whether one script leaf should be omitted from SCRIPTS.
    Both the displayed filename and its extension-free basename are checked.
    */
    function isScriptTreeScriptIgnored script_path =
    (
        if script_path == undefined or script_path == "" then return false

        script_leaf = pathConfig.stripPathToLeaf script_path
        script_stem = getFilenameFile script_path
        (this.doesScriptTreeNameMatchIgnore script_leaf) or (this.doesScriptTreeNameMatchIgnore script_stem)
        -- return
    ),

    /*
    Compatibility wrapper for previous source-directory ignore callers.
    New production discovery uses the ignore list only for SCRIPTS.
    */
    function isSourceDirectoryIgnored directory_path =
    (
        this.isScriptTreeDirectoryIgnored directory_path
        -- return
    ),

    /*
    Returns whether one MCR script is shadowed by an MS script with the same basename in the same directory.
    Exact same-basename MS/MCR pairs expose only the MS script as a managed load target.
    */
    function isShadowedMcrScriptPath script_path =
    (
        if script_path == undefined or script_path == "" then return false
        if (toLower (getFilenameType script_path)) != ".mcr" then return false

        sibling_ms_path = getFilenamePath script_path + getFilenameFile script_path + ".ms"
        doesFileExist sibling_ms_path
        -- return
    ),

    /*
    Returns raw supported script files directly inside one directory before version filtering.
    Auto-loaded UI companions remain hidden as separate load targets.
    MCR files are hidden when an MS file with the same basename exists beside them.
    Files are returned newest first by last-write time.
    */
    function getRawScriptFilesInDirectory directory_path =
    (
        normalized_path = ScriptManagerIntegration.normalizeDirectoryPath directory_path
        script_files = #()

        if normalized_path == "" then return script_files

        for script_pattern in #("*.ms", "*.mcr", "*.mse") do
        (
            pattern_files = getFiles (normalized_path + script_pattern)

            for script_path in pattern_files do
            (
                if not(this.isAutoCompanionScriptPath script_path) and not(this.isShadowedMcrScriptPath script_path) then append script_files script_path
            )
        )

        this.sortScriptPathsNewestFirst script_files
        -- return
    ),

    /*
    Saves the SHOW VERSIONED FILES filter state.
    */
    function saveShowVersionedFiles enabled =
    (
        show_versioned_files = enabled
        setINISetting ini_path "Filter" "ShowVersionedFiles" (if enabled then "1" else "0") forceUTF16:false
        true
        -- return
    ),

    /*
    Loads the SHOW VERSIONED FILES filter state.
    */
    function loadShowVersionedFiles =
    (
        -- A missing INI key defaults to ON; explicitly saved 0/1 still wins.
        saved_filter_value = getINISetting ini_path "Filter" "ShowVersionedFiles"
        show_versioned_files = (saved_filter_value == "" or saved_filter_value == "1")
        show_versioned_files
        -- return
    ),

    /*
    Returns the current CLEAN SCRIPTS state: 0=all, 1=strict match, 2=strict with fallback.
    The legacy Boolean stays valid for existing consumers and tests.
    */
    function getCleanScriptsMode =
    (
        if not show_clean_scripts_only then 0 else if show_unclear_scripts then 2 else 1
        -- return
    ),

    /*
    Returns the next CLEAN SCRIPTS checkbox state in the explicit 0 -> 1 -> 2 -> 0 cycle.
    The checkbox changed event supplies only a Boolean, not the third-state integer.
    */
    function getNextCleanScriptsMode current_mode =
    (
        if current_mode >= 2 or current_mode < 0 then 0 else (current_mode + 1)
        -- return
    ),

    /*
    Persists the three-state CLEAN SCRIPTS mode using the existing INI setting.
    Existing 0/1 settings retain their original meaning; 2 enables unclear-script fallback.
    */
    function saveCleanScriptsMode requested_mode =
    (
        clean_mode = if requested_mode == 2 then 2 else if requested_mode == 1 then 1 else 0
        show_clean_scripts_only = (clean_mode != 0)
        show_unclear_scripts = (clean_mode == 2)
        setINISetting ini_path "Filter" "CleanScriptsOnly" (clean_mode as string) forceUTF16:false
        true
        -- return
    ),

    /*
    Compatibility setter for the original two-state CLEAN SCRIPTS API.
    Boolean true selects strict cleaning; false disables cleaning.
    */
    function saveShowCleanScriptsOnly enabled =
    (
        this.saveCleanScriptsMode (if enabled then 1 else 0)
        -- return
    ),

    /*
    Restores the three-state CLEAN SCRIPTS setting with legacy 0/1 compatibility.
    The Boolean return value preserves the previous loader/test contract.
    */
    function loadShowCleanScriptsOnly =
    (
        saved_mode = getINISetting ini_path "Filter" "CleanScriptsOnly"
        show_clean_scripts_only = (saved_mode == "1" or saved_mode == "2")
        show_unclear_scripts = (saved_mode == "2")
        show_clean_scripts_only
        -- return
    ),

    /*
    Saves the SCRIPTS-only redundant directory display mode to the project INI.
    This changes tree presentation only and does not change script source paths.
    */
    function saveCollapseScriptDirs enabled =
    (
        collapse_script_dirs = enabled
        setINISetting ini_path "Filter" "CollapseDirs" (if enabled then "1" else "0") forceUTF16:false
        true
        -- return
    ),

    /*
    Restores COLLAPSE DIRS, defaulting to the previous compact tree layout.
    Explicitly saved OFF preserves the complete discovered folder hierarchy.
    */
    function loadCollapseScriptDirs =
    (
        saved_filter_value = getINISetting ini_path "Filter" "CollapseDirs"
        collapse_script_dirs = (saved_filter_value == "" or saved_filter_value == "1")
        collapse_script_dirs
        -- return
    ),

    /*
    Returns a stable INI key for one directory TreeView node.
    Script leaf nodes return an empty string because only folder expansion is persisted.
    */
    function getTreeExpansionKey tree_node =
    (
        if tree_node == undefined then return ""

        node_path = tree_node.ToolTipText
        if node_path == undefined or node_path == "" then return ""
        if this.isSupportedScriptPath node_path then return ""

        this.getRelativeDirectoryPath node_path
        -- return
    ),

    /*
    Saves one folder-node expanded state in the requested INI section.
    */
    function saveTreeNodeOpenState tree_node section_name =
    (
        state_key = this.getTreeExpansionKey tree_node
        if state_key == "" then return false

        setINISetting ini_path section_name state_key (if tree_node.IsExpanded then "1" else "0") forceUTF16:false
        true
        -- return
    ),

    /*
    Loads one folder-node expansion state from INI, using the caller's default when unset.
    */
    function loadTreeNodeOpenState tree_node section_name default_expanded:true =
    (
        state_key = this.getTreeExpansionKey tree_node
        if state_key == "" then return default_expanded

        this.getIniBoolean section_name state_key default_expanded
        -- return
    ),

    /*
    Saves expanded states recursively for one TreeView branch.
    */
    function saveTreeExpansionBranch tree_node section_name =
    (
        if tree_node == undefined then return false

        if not(this.isSupportedScriptPath tree_node.ToolTipText) then
        (
            this.saveTreeNodeOpenState tree_node section_name

            for child_index = 0 to (tree_node.Nodes.Count - 1) do
            (
                this.saveTreeExpansionBranch tree_node.Nodes.Item[child_index] section_name
            )
        )

        true
        -- return
    ),

    /*
    Saves every folder expanded state for one TreeView.
    */
    function saveTreeExpansionStates tree_control section_name =
    (
        if tree_control == undefined then return false

        for root_index = 0 to (tree_control.Nodes.Count - 1) do
        (
            this.saveTreeExpansionBranch tree_control.Nodes.Item[root_index] section_name
        )

        true
        -- return
    ),

    /*
    Returns whether one selected source subtree contains at least one visible managed script.
    */
    function directoryHasManagedScripts directory_path =
    (
        normalized_path = ScriptManagerIntegration.normalizeDirectoryPath directory_path
        if normalized_path == "" then return false
        if this.isManagerPackageDirectory normalized_path then return false
        if this.isDefaultExcludedSourceDirectory normalized_path then return false
        if this.isScriptTreeDirectoryIgnored normalized_path then return false

        for script_path in (this.getScriptFilesInDirectory normalized_path) do
        (
            if not(this.isScriptTreeScriptIgnored script_path) then return true
        )

        child_directories = getDirectories (normalized_path + "*")
        sort child_directories

        for child_directory in child_directories do
        (
            normalized_child = ScriptManagerIntegration.normalizeDirectoryPath child_directory
            if this.directoryHasManagedScripts normalized_child then return true
        )

        false
        -- return
    ),

    /*
    Returns one SCRIPTS display path rooted at the checked SOURCES directory that owns the scan.
    Unchecked ancestors above that selected source are omitted from the visible SCRIPTS hierarchy.
    */
    function getScriptTreeSourceDisplayPath directory_path source_directory =
    (
        normalized_path = ScriptManagerIntegration.normalizeDirectoryPath directory_path
        normalized_source = ScriptManagerIntegration.normalizeDirectoryPath source_directory
        if normalized_path == "" or normalized_source == "" then return ""

        if normalized_source == ScriptManagerIntegration.normalizeDirectoryPath root_directory then
        (
            return this.getRelativeDirectoryPath normalized_path
        )

        source_name = ScriptManagerIntegration.getFolderName normalized_source
        if source_name == "" then return this.getRelativeDirectoryPath normalized_path
        if normalized_path == normalized_source then return source_name
        if not(this.isDirectoryBelowDirectory normalized_path normalized_source) then return this.getRelativeDirectoryPath normalized_path

        relative_below_source = substring normalized_path (normalized_source.count + 1) (normalized_path.count - normalized_source.count)
        if relative_below_source.count > 0 and relative_below_source[relative_below_source.count] == "\\" then
        (
            relative_below_source = substring relative_below_source 1 (relative_below_source.count - 1)
        )

        if relative_below_source == "" then source_name else (source_name + "\\" + relative_below_source)
        -- return
    ),

    /*
    Finds .ms, .mcr, .mzp, or .mse anywhere in a SCRIPTS directory subtree.
    Caches each result for one discovery pass and skips ignored/excluded branches.
    This is directory visibility only: it does not change executable script types.
    */
    function scriptDirectoryHasSourceFiles directory_path presence_cache =
    (
        normalized_path = ScriptManagerIntegration.normalizeDirectoryPath directory_path
        if normalized_path == "" then return false
        if this.isManagerPackageDirectory normalized_path then return false
        if this.isDefaultExcludedSourceDirectory normalized_path then return false
        if this.isScriptTreeDirectoryIgnored normalized_path then return false

        cache_key = toLower normalized_path
        if HasDictValue presence_cache cache_key then return (GetDictValue presence_cache cache_key)

        script_found = false
        for extension_pattern in #("*.ms", "*.mcr", "*.mzp", "*.mse") while not script_found do
        (
            if (getFiles (normalized_path + extension_pattern)).count > 0 then script_found = true
        )

        if not script_found then
        (
            for child_directory in (getDirectories (normalized_path + "*")) while not script_found do
            (
                if this.scriptDirectoryHasSourceFiles child_directory presence_cache then script_found = true
            )
        )

        PutDictValue presence_cache cache_key script_found
        script_found
        -- return
    ),

    /*
    Recursively discovers only SCRIPTS directories containing a supported source file,
    either directly or in a nested directory. Unchecked ancestors remain hidden.
    Empty and non-script branches are pruned even with COLLAPSE DIRS turned off.
    */
    function discoverDirectory directory_path source_directory presence_cache =
    (
        normalized_path = ScriptManagerIntegration.normalizeDirectoryPath directory_path
        if normalized_path == "" then return false
        if not(this.scriptDirectoryHasSourceFiles normalized_path presence_cache) then return true

        relative_path = this.getRelativeDirectoryPath normalized_path
        if relative_path == "" then return false

        tree_group_path = this.getScriptTreeSourceDisplayPath normalized_path source_directory

        append available_group_paths relative_path
        append available_group_tree_paths tree_group_path
        append available_group_names (ScriptManagerIntegration.getFolderName normalized_path)
        append available_group_directories normalized_path
        append available_group_displayable (this.getSourceToolScriptPath normalized_path == "")

        if debug_logging then format "[Script-Manager] GROUP: % | TREE: %\n" relative_path tree_group_path

        for script_path in (this.getScriptFilesInDirectory normalized_path) do
        (
            if not(this.isScriptTreeScriptIgnored script_path) then
            (
                script_name = getFilenameFile script_path
                script_key = this.getScriptKey script_path

                append available_script_names script_name
                append available_script_keys script_key
                append available_script_group_paths relative_path
                append available_script_tree_group_paths tree_group_path
                append available_script_directories normalized_path
                append available_script_paths script_path

                if debug_logging then format "[Script-Manager] SCRIPT: % | GROUP: % | LOAD PATH: %\n" script_key relative_path script_path
            )
        )

        child_directories = getDirectories (normalized_path + "*")
        sort child_directories

        for child_directory in child_directories do
        (
            normalized_child = ScriptManagerIntegration.normalizeDirectoryPath child_directory
            this.discoverDirectory normalized_child source_directory presence_cache
        )

        true
        -- return
    ),

    /*
    Discovers supported scripts and directories containing .ms/.mcr/.mzp/.mse sources.
    Directory eligibility is cached for the discovery pass; script loads are unchanged.
    */
    function discoverScripts =
    (
        timing_start = timestamp()
        available_script_names = #()
        available_script_keys = #()
        available_script_group_paths = #()
        available_script_tree_group_paths = #()
        available_script_directories = #()
        available_script_paths = #()
        available_group_paths = #()
        available_group_tree_paths = #()
        available_group_names = #()
        available_group_directories = #()
        available_group_displayable = #()
        presence_cache = Dictionary #string

        if root_directory == "" then return false
        if available_source_directories.count == 0 then this.discoverSources()

        root_directory = ScriptManagerIntegration.normalizeDirectoryPath root_directory
        if debug_logging then format "[Script-Manager] ROOT PATH: %\n" root_directory

        enabled_sources = this.getEnabledSourceDirectories()
        has_selectable_source = false
        for source_state in available_source_selectable while not has_selectable_source do
        (
            if source_state then has_selectable_source = true
        )

        if enabled_sources.count == 0 and not has_selectable_source then
        (
            append enabled_sources root_directory
            format "[Script-Manager] ROOT contains no selectable SOURCES folders; discovering root scripts directly: %\n" root_directory
        )

        for source_directory in enabled_sources do
        (
            normalized_source = ScriptManagerIntegration.normalizeDirectoryPath source_directory

            if normalized_source == root_directory then
            (
                if not has_selectable_source then
                (
                    for child_directory in (getDirectories (root_directory + "*")) do
                    (
                        if not(this.isManagerPackageDirectory child_directory) then
                        (
                            this.discoverDirectory child_directory root_directory presence_cache
                        )
                    )
                )

                for script_path in (this.getScriptFilesInDirectory root_directory) do
                (
                    if not(this.isScriptTreeScriptIgnored script_path) then
                    (
                        script_name = getFilenameFile script_path
                        script_key = this.getScriptKey script_path

                        append available_script_names script_name
                        append available_script_keys script_key
                        append available_script_group_paths ""
                        append available_script_tree_group_paths ""
                        append available_script_directories root_directory
                        append available_script_paths script_path

                        if debug_logging then format "[Script-Manager] SCRIPT: % | GROUP: <root> | LOAD PATH: %\n" script_key script_path
                    )
                )
            )
            else
            (
                this.discoverDirectory normalized_source normalized_source presence_cache
            )
        )

        timing_elapsed_ms = timestamp() - timing_start
        format "[Script-Manager][TIMING] SCRIPTS DATA PREP | % ms | folders:% | scripts:%\n" timing_elapsed_ms available_group_paths.count available_script_paths.count
        true
        -- return
    ),

    /*
    Returns one persisted script load mode: #skip, #host, or #direct.
    Legacy INI values remain compatible: 0/missing = #skip and 1 = #host; 2 stores #direct.
    */
    function getScriptLoadMode script_key =
    (
        stored_text = getINISetting ini_path "Scripts" script_key

        case stored_text of
        (
            "1": #host
            "2": #direct
            default: #skip
        )
        -- return
    ),

    /*
    Persists one script load mode as 0=#skip, 1=#host, or 2=#direct.
    */
    function saveScriptLoadMode script_key load_mode =
    (
        if script_key == undefined or script_key == "" then return false

        stored_text = case load_mode of
        (
            #host: "1"
            #direct: "2"
            default: "0"
        )

        setINISetting ini_path "Scripts" script_key stored_text forceUTF16:false
        true
        -- return
    ),


    /*
    Returns the INI section name used by one Script-Manager preset.
    Preset names are isolated from regular manager settings by the Preset| prefix.
    */
    function getPresetSectionName preset_name =
    (
        "Preset|" + preset_name
        -- return
    ),

    /*
    Normalizes one preset name before it is used as an INI section suffix.
    Empty names and INI section delimiters are rejected.
    */
    function normalizePresetName preset_name =
    (
        normalized_name = undefined

        if classOf preset_name == String then
        (
            candidate_name = trimRight (trimLeft preset_name)

            if (
                candidate_name != "" and
                findString candidate_name "[" == undefined and
                findString candidate_name "]" == undefined and
                findString candidate_name "|" == undefined and
                findString candidate_name "\n" == undefined and
                findString candidate_name "\r" == undefined
            ) then
            (
                normalized_name = candidate_name
            )
        )

        normalized_name
        -- return
    ),

    /*
    Returns all stored Script-Manager preset names sorted alphabetically.
    Only INI sections using the Preset| prefix participate in the dropdown.
    */
    function getPresetNames =
    (
        preset_names = #()
        section_names = getINISetting ini_path

        if classOf section_names != Array then section_names = #()

        for section_name in section_names do
        (
            preset_prefix = "Preset|"

            if section_name.count > preset_prefix.count and (substring section_name 1 preset_prefix.count) == preset_prefix then
            (
                preset_name = substring section_name (preset_prefix.count + 1) (section_name.count - preset_prefix.count)
                if preset_name != "" then append preset_names preset_name
            )
        )

        sort preset_names
        preset_names
        -- return
    ),

    /*
    Returns whether one normalized Script-Manager preset section already exists.
    Invalid names return false without touching the INI file.
    */
    function hasPreset preset_name =
    (
        normalized_name = this.normalizePresetName preset_name
        if normalized_name == undefined then return false

        hasINISetting ini_path (this.getPresetSectionName normalized_name)
        -- return
    ),

    /*
    Reads one complete INI section into #(key, value) pairs for rollback-safe writes.
    Missing sections return an empty array.
    */
    function getIniSectionEntries section_name =
    (
        section_entries = #()
        key_names = getINISetting ini_path section_name

        if classOf key_names != Array then return section_entries

        for key_name in key_names do
        (
            append section_entries #(key_name, getINISetting ini_path section_name key_name)
        )

        section_entries
        -- return
    ),

    /*
    Replaces one complete INI section with supplied #(key, value) pairs.
    The function returns false immediately when any persisted write fails.
    */
    function replaceIniSection section_name section_entries =
    (
        if section_name == undefined or section_name == "" then return false
        if classOf section_entries != Array then return false

        if hasINISetting ini_path section_name then
        (
            delINISetting ini_path section_name
            if hasINISetting ini_path section_name then return false
        )

        for entry_data in section_entries do
        (
            if classOf entry_data != Array or entry_data.count != 2 then return false
            if entry_data[1] == undefined or entry_data[1] == "" then return false

            if not(setINISetting ini_path section_name entry_data[1] (entry_data[2] as string) forceUTF16:false) then return false
        )

        true
        -- return
    ),

    /*
    Builds one compact preset snapshot from enabled SOURCES and non-skipped script modes.
    Missing entries naturally mean disabled source or #skip script state when restored.
    */
    function buildPresetEntries =
    (
        preset_entries = #()
        enabled_source_keys = #()
        configured_script_entries = #()
        source_keys = getINISetting ini_path "Sources"
        script_keys = getINISetting ini_path "Scripts"

        if classOf source_keys != Array then source_keys = #()
        if classOf script_keys != Array then script_keys = #()

        sort source_keys
        sort script_keys

        for source_key in source_keys do
        (
            if (getINISetting ini_path "Sources" source_key) == "1" then append enabled_source_keys source_key
        )

        for script_key in script_keys do
        (
            mode_text = getINISetting ini_path "Scripts" script_key

            if mode_text == "1" or mode_text == "2" then
            (
                append configured_script_entries #(script_key, mode_text)
            )
        )

        append preset_entries #("PresetFormat", "1")
        append preset_entries #("SourceCount", enabled_source_keys.count as string)

        for source_index = 1 to enabled_source_keys.count do
        (
            append preset_entries #("Source_" + (source_index as string), enabled_source_keys[source_index])
        )

        append preset_entries #("ScriptCount", configured_script_entries.count as string)

        for script_index = 1 to configured_script_entries.count do
        (
            script_entry = configured_script_entries[script_index]
            append preset_entries #("Script_" + (script_index as string) + "_Key", script_entry[1])
            append preset_entries #("Script_" + (script_index as string) + "_Mode", script_entry[2])
        )

        preset_entries
        -- return
    ),

    /*
    Saves the current Script-Manager loader configuration into one named preset section.
    Existing preset data is restored automatically if the replacement write fails.
    */
    function savePreset preset_name =
    (
        normalized_name = this.normalizePresetName preset_name
        if normalized_name == undefined then return false

        preset_section = this.getPresetSectionName normalized_name
        previous_entries = this.getIniSectionEntries preset_section
        preset_entries = this.buildPresetEntries()

        if not(this.replaceIniSection preset_section preset_entries) then
        (
            if not(this.replaceIniSection preset_section previous_entries) then
            (
                format "[Script-Manager] Preset rollback failed after save error: %\n" normalized_name
            )

            return false
        )

        true
        -- return
    ),

    /*
    Decodes one stored preset into #(source_entries, script_entries).
    Invalid or incomplete preset data returns undefined before manager settings are changed.
    */
    function readPresetData preset_name =
    (
        normalized_name = this.normalizePresetName preset_name
        if normalized_name == undefined then return undefined

        preset_section = this.getPresetSectionName normalized_name
        if not(hasINISetting ini_path preset_section) then return undefined
        if (getINISetting ini_path preset_section "PresetFormat") != "1" then return undefined

        source_count = this.getIniInteger preset_section "SourceCount" -1
        script_count = this.getIniInteger preset_section "ScriptCount" -1
        if source_count < 0 or script_count < 0 then return undefined

        source_entries = #()
        script_entries = #()
        source_keys = #()
        script_keys = #()
        preset_valid = true

        for source_index = 1 to source_count while preset_valid do
        (
            source_key = getINISetting ini_path preset_section ("Source_" + (source_index as string))

            if source_key == "" or (findItem source_keys source_key) > 0 then
            (
                preset_valid = false
            )
            else
            (
                append source_keys source_key
                append source_entries #(source_key, "1")
            )
        )

        for script_index = 1 to script_count while preset_valid do
        (
            script_key = getINISetting ini_path preset_section ("Script_" + (script_index as string) + "_Key")
            mode_text = getINISetting ini_path preset_section ("Script_" + (script_index as string) + "_Mode")

            if script_key == "" or (findItem script_keys script_key) > 0 or not(mode_text == "1" or mode_text == "2") then
            (
                preset_valid = false
            )
            else
            (
                append script_keys script_key
                append script_entries #(script_key, mode_text)
            )
        )

        if preset_valid then #(source_entries, script_entries) else undefined
        -- return
    ),

    /*
    Refreshes SOURCES and SCRIPTS controls after preset state is written without rebuilding the active rollout.
    Running scripts remain untouched and no configured script is executed by this refresh.
    */
    function refreshPresetConfiguration =
    (
        if script_manager_ui == undefined then return false

        refresh_ok = true

        try
        (
            if not(this.discoverSources()) then throw "discoverSources returned false"
            if not(this.discoverScripts()) then throw "discoverScripts returned false"
            if not(this.populateSourceTree()) then throw "populateSourceTree returned false"
            if not(this.populateScriptTree()) then throw "populateScriptTree returned false"
            if not(this.prepareScriptHost()) then throw "prepareScriptHost returned false"
            if not(this.layoutManager [script_manager_ui.width, script_manager_ui.height]) then throw "layoutManager returned false"
        )
        catch
        (
            exception_text = getCurrentException()
            refresh_ok = false
            format "[Script-Manager] Preset configuration refresh failed: %\n" exception_text
        )

        refresh_ok
        -- return
    ),

    /*
    Loads one named preset without executing configured scripts.
    SOURCES are restored before discovery, then the existing loader controls are synchronized to restored script modes.
    */
    function loadPreset preset_name =
    (
        normalized_name = this.normalizePresetName preset_name
        if normalized_name == undefined then return false

        preset_data = this.readPresetData normalized_name
        if preset_data == undefined then return false

        previous_source_entries = this.getIniSectionEntries "Sources"
        previous_script_entries = this.getIniSectionEntries "Scripts"
        restore_ok = true

        if not(this.replaceIniSection "Sources" preset_data[1]) then restore_ok = false
        if restore_ok and not(this.replaceIniSection "Scripts" preset_data[2]) then restore_ok = false

        if not restore_ok then
        (
            this.replaceIniSection "Sources" previous_source_entries
            this.replaceIniSection "Scripts" previous_script_entries
            return false
        )

        if not(this.refreshPresetConfiguration()) then
        (
            source_rollback_ok = this.replaceIniSection "Sources" previous_source_entries
            script_rollback_ok = this.replaceIniSection "Scripts" previous_script_entries

            if source_rollback_ok and script_rollback_ok then
            (
                this.refreshPresetConfiguration()
            )
            else
            (
                format "[Script-Manager] Preset rollback failed after loader refresh error: %\n" normalized_name
            )

            return false
        )

        this.refreshPresetDropdown preferred_name:normalized_name
        true
        -- return
    ),

    /*
    Applies one named preset and then executes its configured script set.
    Hard reload is the default so the active HOST layout exactly follows the selected preset.
    */
    function loadPresetAndScripts preset_name hard_reload:true =
    (
        if not(this.loadPreset preset_name) then
        (
            format "[Script-Manager] Preset configuration load failed: %\n" preset_name
            return false
        )

        execution_ok = if hard_reload then this.loadScripts() else this.updateScripts()

        if not execution_ok then
        (
            format "[Script-Manager] Preset script execution failed: % | hard reload:%\n" preset_name hard_reload
        )

        execution_ok
        -- return
    ),

    /*
    Returns the canonical unversioned Script-Manager path for generated preset actions and startup loaders.
    The running source is used only when the canonical matching-name entry file cannot be resolved.
    */
    function getCanonicalManagerScriptPath =
    (
        if manager_source_path == undefined or manager_source_path == "" then return undefined

        manager_directory = ScriptManagerIntegration.normalizeDirectoryPath (getFilenamePath manager_source_path)
        manager_folder_name = ScriptManagerIntegration.getFolderName manager_directory
        if manager_directory == "" or manager_folder_name == "" then return manager_source_path

        canonical_path = manager_directory + manager_folder_name + ".ms"
        if doesFileExist canonical_path then canonical_path else manager_source_path
        -- return
    ),

    /*
    Escapes one value for safe insertion into a generated MAXScript string literal.
    */
    function escapeMaxScriptString text_value =
    (
        if classOf text_value != String then return ""

        escaped_text = substituteString text_value "\\" "\\\\"
        escaped_text = substituteString escaped_text "\"" "\\\""
        escaped_text = substituteString escaped_text "\t" "\\t"
        escaped_text = substituteString escaped_text "\n" "\\n"
        escaped_text = substituteString escaped_text "\r" "\\r"
        escaped_text
        -- return
    ),

    /*
    Returns a unique, repeatable user-startup launcher path for a source script.
    The launcher filename contains a short SHA-256 digest of the full source path.
    */
    function getScriptStartupLauncherPath script_path startup_directory:"" =
    (
        if not(this.isSupportedScriptPath script_path) then return ""

        target_directory = startup_directory
        if target_directory == "" then target_directory = getDir #userStartupScripts
        normalized_directory = ScriptManagerIntegration.normalizeDirectoryPath target_directory
        if normalized_directory == "" then return ""

        path_text = toLower script_path
        script_name = getFilenameFile script_path
        if script_name.count > 32 then script_name = substring script_name 1 32

        digest_text = ""
        hash_provider = undefined
        try
        (
            utf8 = (dotNetClass "System.Text.Encoding").UTF8
            hash_provider = (dotNetClass "System.Security.Cryptography.SHA256").Create()
            digest_bytes = hash_provider.ComputeHash (utf8.GetBytes path_text)
            digest_text = substituteString ((dotNetClass "System.BitConverter").ToString digest_bytes) "-" ""
            hash_provider.Dispose()
            hash_provider = undefined
        )
        catch
        (
            if hash_provider != undefined then (try (hash_provider.Dispose()) catch ())
            format "[Script-Manager][STARTUP] Hash calculation failed: %\n" (getCurrentException())
            return ""
        )

        if digest_text.count < 20 then return ""
        normalized_directory + "Script-Manager-Autostart-" + script_name + "-" + (substring digest_text 1 20) + ".ms"
        -- return
    ),

    /*
    Identifies a launcher generated by Script-Manager for precisely this script.
    Other files in 3ds Max startup are never treated as owned launchers.
    */
    function isScriptInStartup script_path startup_directory:"" =
    (
        launcher_path = this.getScriptStartupLauncherPath script_path startup_directory:startup_directory
        if launcher_path == "" or not(doesFileExist launcher_path) then return false

        file_stream = undefined
        owned = false
        try
        (
            file_stream = openFile launcher_path
            if file_stream != undefined then
            (
                first_line = readLine file_stream
                owned = first_line == ("-- SCRIPT-MANAGER-AUTOSTART | " + script_path)
                close file_stream
                file_stream = undefined
            )
        )
        catch
        (
            owned = false
            if file_stream != undefined then (try (close file_stream) catch ())
        )
        owned
        -- return
    ),

    /*
    Builds one lightweight startup launcher that fileIns the original script.
    The source file and its sibling dependencies remain at their original paths.
    */
    function buildScriptStartupLauncherText script_path =
    (
        source_literal = this.escapeMaxScriptString script_path
        loader_text = "-- SCRIPT-MANAGER-AUTOSTART | " + script_path + "\n"
        loader_text += "(\n"
        loader_text += "    local script_path = \"" + source_literal + "\"\n"
        loader_text += "    try\n"
        loader_text += "    (\n"
        loader_text += "        if doesFileExist script_path then fileIn script_path quiet:true\n"
        loader_text += "        else format \"[Script-Manager][STARTUP] FAILED | missing:%\\n\" script_path\n"
        loader_text += "    )\n"
        loader_text += "    catch\n"
        loader_text += "    (\n"
        loader_text += "        format \"[Script-Manager][STARTUP] FAILED | script:% | error:%\\n\" script_path (getCurrentException())\n"
        loader_text += "    )\n"
        loader_text += ")\n"
        loader_text
        -- return
    ),

    /*
    Installs a Script-Manager-owned startup launcher without modifying the original script.
    Existing foreign files are never overwritten, even when their names match.
    */
    function addScriptToStartup script_path startup_directory:"" =
    (
        if not(this.isSupportedScriptPath script_path) or not(doesFileExist script_path) then return false
        launcher_path = this.getScriptStartupLauncherPath script_path startup_directory:startup_directory
        if launcher_path == "" then return false
        if this.isScriptInStartup script_path startup_directory:startup_directory then return true
        if doesFileExist launcher_path then
        (
            format "[Script-Manager][STARTUP] REFUSED | foreign launcher exists:%\n" launcher_path
            return false
        )

        launcher_text = this.buildScriptStartupLauncherText script_path
        output_stream = undefined
        write_ok = false
        try
        (
            output_stream = createFile launcher_path
            if output_stream == undefined then throw "createFile returned undefined"
            format "%" launcher_text to:output_stream
            close output_stream
            output_stream = undefined
            write_ok = this.isScriptInStartup script_path startup_directory:startup_directory
        )
        catch
        (
            format "[Script-Manager][STARTUP] ADD FAILED | file:% | %\n" script_path (getCurrentException())
            if output_stream != undefined then (try (close output_stream) catch ())
        )

        if not write_ok then
        (
            -- This path did not exist before creation, so even a partial write is safe to clean up.
            if doesFileExist launcher_path then deleteFile launcher_path
            format "[Script-Manager][STARTUP] ADD FAILED | file:% | launcher:%\n" script_path launcher_path
        )
        else format "[Script-Manager][STARTUP] ADDED | file:% | launcher:%\n" script_path launcher_path
        write_ok
        -- return
    ),

    /*
    Removes only a verified Script-Manager-owned startup launcher for this script.
    Unrelated startup scripts and the original script are never deleted.
    */
    function removeScriptFromStartup script_path startup_directory:"" =
    (
        launcher_path = this.getScriptStartupLauncherPath script_path startup_directory:startup_directory
        if launcher_path == "" or not(this.isScriptInStartup script_path startup_directory:startup_directory) then return false

        remove_ok = false
        try (remove_ok = deleteFile launcher_path) catch (format "[Script-Manager][STARTUP] REMOVE FAILED | %\n" (getCurrentException()))
        if remove_ok then format "[Script-Manager][STARTUP] REMOVED | file:% | launcher:%\n" script_path launcher_path
        remove_ok
        -- return
    ),

    /*
    Toggles startup registration for the selected SCRIPTS TreeView script leaf.
    The context-menu label is refreshed to reflect the registered state.
    */
    function toggleSelectedScriptStartup =
    (
        tree_control = this.getScriptTreeControl()
        if tree_control == undefined or tree_control.SelectedNode == undefined then return false
        script_path = tree_control.SelectedNode.ToolTipText
        if not(this.isSupportedScriptPath script_path) then return false

        was_registered = this.isScriptInStartup script_path
        action_ok = if was_registered then this.removeScriptFromStartup script_path else this.addScriptToStartup script_path
        if not action_ok then messageBox ("Failed to " + (if was_registered then "remove" else "add") + " the startup script:\n" + script_path) title:"Script-Manager Startup"
        this.updateScriptTreeContextMenuState()
        action_ok
        -- return
    ),

    /*
    Returns the preset configured to load from the Script-Manager startup loader.
    Missing, invalid, or deleted preset names return undefined.
    */
    function getStartupPresetName =
    (
        startup_name = getINISetting ini_path "Presets" "StartupPreset"
        normalized_name = this.normalizePresetName startup_name
        if normalized_name == undefined then return undefined
        if not(this.hasPreset normalized_name) then return undefined

        normalized_name
        -- return
    ),

    /*
    Returns the dedicated user-startup loader path used to launch the startup preset.
    An optional directory override is used by regression tests without touching the real startup folder.
    */
    function getStartupPresetLoaderPath startup_directory:"" =
    (
        target_directory = startup_directory
        if target_directory == "" then target_directory = getDir #userStartupScripts

        normalized_directory = ScriptManagerIntegration.normalizeDirectoryPath target_directory
        if normalized_directory == "" then return ""

        normalized_directory + "Script-Manager-Startup.ms"
        -- return
    ),

    /*
    Builds the startup loader source that launches the canonical manager in standalone mode.
    Runtime-mode globals are restored after the manager has handled its startup preset.
    */
    function buildStartupPresetLoaderText =
    (
        manager_path = this.getCanonicalManagerScriptPath()
        if manager_path == undefined or manager_path == "" then return undefined

        manager_literal = this.escapeMaxScriptString manager_path
        loader_text = "(\n"
        loader_text += "    global SCRIPT_MANAGER_RUNTIME_MODE\n"
        loader_text += "    global EPOLY_TOOLS_RUNTIME_MODE\n"
        loader_text += "    global SCRIPT_MANAGER_STARTUP_LAUNCH\n"
        loader_text += "    local previous_script_manager_mode = SCRIPT_MANAGER_RUNTIME_MODE\n"
        loader_text += "    local previous_epoly_mode = EPOLY_TOOLS_RUNTIME_MODE\n"
        loader_text += "    SCRIPT_MANAGER_RUNTIME_MODE = #standalone\n"
        loader_text += "    EPOLY_TOOLS_RUNTIME_MODE = #standalone\n"
        loader_text += "    SCRIPT_MANAGER_STARTUP_LAUNCH = true\n"
        loader_text += "    try\n"
        loader_text += "    (\n"
        loader_text += "        if doesFileExist \"" + manager_literal + "\" then\n"
        loader_text += "        (\n"
        loader_text += "            fileIn \"" + manager_literal + "\" quiet:true\n"
        loader_text += "        )\n"
        loader_text += "        else\n"
        loader_text += "        (\n"
        loader_text += "            format \"[Script-Manager] Startup loader missing manager: %\\n\" \"" + manager_literal + "\"\n"
        loader_text += "        )\n"
        loader_text += "    )\n"
        loader_text += "    catch\n"
        loader_text += "    (\n"
        loader_text += "        local exception_text = getCurrentException()\n"
        loader_text += "        format \"[Script-Manager] Startup preset loader failed: %\\n\" exception_text\n"
        loader_text += "    )\n"
        loader_text += "    SCRIPT_MANAGER_STARTUP_LAUNCH = false\n"
        loader_text += "    SCRIPT_MANAGER_RUNTIME_MODE = previous_script_manager_mode\n"
        loader_text += "    EPOLY_TOOLS_RUNTIME_MODE = previous_epoly_mode\n"
        loader_text += ")\n"

        loader_text
        -- return
    ),

    /*
    Writes or refreshes the dedicated user-startup loader for the selected startup preset.
    */
    function installStartupPresetLoader startup_directory:"" =
    (
        loader_path = this.getStartupPresetLoaderPath startup_directory:startup_directory
        loader_text = this.buildStartupPresetLoaderText()

        if loader_path == "" then
        (
            format "[Script-Manager] Startup loader path could not be resolved.\n"
            return false
        )

        if loader_text == undefined then
        (
            format "[Script-Manager] Startup loader source could not be built.\n"
            return false
        )

        output_stream = undefined
        write_ok = true

        try
        (
            output_stream = createFile loader_path
            if output_stream == undefined then throw "createFile returned undefined"
            format "%" loader_text to:output_stream
            close output_stream
            output_stream = undefined
        )
        catch
        (
            exception_text = getCurrentException()
            write_ok = false
            format "[Script-Manager] Startup loader write failed: % | %\n" loader_path exception_text

            if output_stream != undefined then
            (
                try (close output_stream) catch ()
            )
        )

        write_ok
        -- return
    ),

    /*
    Removes the dedicated Script-Manager startup loader when no startup preset should run.
    */
    function removeStartupPresetLoader startup_directory:"" =
    (
        loader_path = this.getStartupPresetLoaderPath startup_directory:startup_directory
        if loader_path == "" then return true
        if not(doesFileExist loader_path) then return true

        remove_ok = true

        try
        (
            remove_ok = deleteFile loader_path
        )
        catch
        (
            exception_text = getCurrentException()
            remove_ok = false
            format "[Script-Manager] Startup loader removal failed: % | %\n" loader_path exception_text
        )

        if not remove_ok then format "[Script-Manager] Startup loader still exists: %\n" loader_path
        remove_ok
        -- return
    ),

    /*
    Marks one existing preset as the unique 3ds Max startup preset and installs its startup loader.
    */
    function setStartupPreset preset_name startup_directory:"" =
    (
        normalized_name = this.normalizePresetName preset_name
        if normalized_name == undefined then
        (
            format "[Script-Manager] Invalid startup preset name: %\n" preset_name
            return false
        )
        if not(this.hasPreset normalized_name) then
        (
            format "[Script-Manager] Startup preset does not exist: %\n" normalized_name
            return false
        )

        previous_name = getINISetting ini_path "Presets" "StartupPreset"
        if not(setINISetting ini_path "Presets" "StartupPreset" normalized_name forceUTF16:false) then
        (
            format "[Script-Manager] Could not persist startup preset: %\n" normalized_name
            return false
        )

        if not(this.installStartupPresetLoader startup_directory:startup_directory) then
        (
            rollback_ok = true

            if previous_name == "" then
            (
                delINISetting ini_path "Presets" "StartupPreset"
                rollback_ok = not(hasINISetting ini_path "Presets" "StartupPreset")
            )
            else
            (
                rollback_ok = setINISetting ini_path "Presets" "StartupPreset" previous_name forceUTF16:false
            )

            if rollback_ok then
            (
                format "[Script-Manager] Startup preset assignment rolled back: %\n" normalized_name
            )
            else
            (
                format "[Script-Manager] Startup preset rollback failed: attempted:% previous:%\n" normalized_name previous_name
            )
            return false
        )

        this.refreshPresetStartupControl()
        true
        -- return
    ),

    /*
    Clears the startup-preset setting and removes the dedicated user-startup loader.
    */
    function clearStartupPreset startup_directory:"" =
    (
        previous_name = getINISetting ini_path "Presets" "StartupPreset"

        if hasINISetting ini_path "Presets" "StartupPreset" then
        (
            delINISetting ini_path "Presets" "StartupPreset"
            if hasINISetting ini_path "Presets" "StartupPreset" then
            (
                format "[Script-Manager] Could not clear persisted startup preset: %\n" previous_name
                return false
            )
        )

        if not(this.removeStartupPresetLoader startup_directory:startup_directory) then
        (
            restore_ok = true
            if previous_name != "" then restore_ok = setINISetting ini_path "Presets" "StartupPreset" previous_name forceUTF16:false
            if not restore_ok then format "[Script-Manager] Startup preset restore failed after loader-removal error: %\n" previous_name
            return false
        )

        this.refreshPresetStartupControl()
        true
        -- return
    ),

    /*
    Loads the configured startup preset once when Script-Manager was launched by its user-startup loader.
    */
    function loadStartupPresetOnce =
    (
        if SCRIPT_MANAGER_STARTUP_PRESET_APPLIED == true then return true
        if SCRIPT_MANAGER_STARTUP_LAUNCH != true then return true

        startup_name = this.getStartupPresetName()
        SCRIPT_MANAGER_STARTUP_PRESET_APPLIED = true

        if startup_name == undefined then return true

        if not(this.loadPresetAndScripts startup_name) then
        (
            SCRIPT_MANAGER_STARTUP_PRESET_APPLIED = false
            format "[Script-Manager] Startup preset failed: %\n" startup_name
            return false
        )

        true
        -- return
    ),

    /*
    Returns one stable alphanumeric MacroScript action name derived from the complete preset name.
    */
    function getPresetMacroActionName preset_name =
    (
        normalized_name = this.normalizePresetName preset_name
        if normalized_name == undefined then return undefined

        action_name = "ScriptManagerPreset"

        for character_index = 1 to normalized_name.count do
        (
            action_name += "_" + bit.intAsHex (bit.charAsInt normalized_name[character_index])
        )

        action_name
        -- return
    ),

    /*
    Returns the compact toolbar text used by one generated preset MacroScript action.
    */
    function getPresetMacroButtonText preset_name =
    (
        normalized_name = this.normalizePresetName preset_name
        if normalized_name == undefined then return "Preset"

        if normalized_name.count > 10 then substring normalized_name 1 10 else normalized_name
        -- return
    ),

    /*
    Builds the body used by a persistent MacroScript action that loads one preset by name.
    */
    function buildPresetMacroBody preset_name =
    (
        normalized_name = this.normalizePresetName preset_name
        if normalized_name == undefined then return undefined
        if not(this.hasPreset normalized_name) then return undefined

        manager_path = this.getCanonicalManagerScriptPath()
        if manager_path == undefined or manager_path == "" then return undefined

        manager_literal = this.escapeMaxScriptString manager_path
        preset_literal = this.escapeMaxScriptString normalized_name
        macro_body = "global script_manager\n"
        macro_body += "global script_manager_ui\n"
        macro_body += "global SCRIPT_MANAGER_RUNTIME_MODE\n"
        macro_body += "global EPOLY_TOOLS_RUNTIME_MODE\n"
        macro_body += "local manager_path = \"" + manager_literal + "\"\n"
        macro_body += "local manager_api_ready = false\n"
        macro_body += "if script_manager != undefined then manager_api_ready = isProperty script_manager #loadPresetAndScripts\n"
        macro_body += "if not manager_api_ready then\n"
        macro_body += "(\n"
        macro_body += "    if doesFileExist manager_path then\n"
        macro_body += "    (\n"
        macro_body += "        local previous_script_manager_mode = SCRIPT_MANAGER_RUNTIME_MODE\n"
        macro_body += "        local previous_epoly_mode = EPOLY_TOOLS_RUNTIME_MODE\n"
        macro_body += "        SCRIPT_MANAGER_RUNTIME_MODE = #standalone\n"
        macro_body += "        EPOLY_TOOLS_RUNTIME_MODE = #standalone\n"
        macro_body += "        try\n"
        macro_body += "        (\n"
        macro_body += "            fileIn manager_path quiet:true\n"
        macro_body += "        )\n"
        macro_body += "        catch\n"
        macro_body += "        (\n"
        macro_body += "            local exception_text = getCurrentException()\n"
        macro_body += "            format \"[Script-Manager] Preset macro failed to load manager: %\\n\" exception_text\n"
        macro_body += "        )\n"
        macro_body += "        SCRIPT_MANAGER_RUNTIME_MODE = previous_script_manager_mode\n"
        macro_body += "        EPOLY_TOOLS_RUNTIME_MODE = previous_epoly_mode\n"
        macro_body += "    )\n"
        macro_body += "    else\n"
        macro_body += "    (\n"
        macro_body += "        format \"[Script-Manager] Preset macro missing manager: %\\n\" manager_path\n"
        macro_body += "    )\n"
        macro_body += ")\n"
        macro_body += "manager_api_ready = false\n"
        macro_body += "if script_manager != undefined then manager_api_ready = isProperty script_manager #loadPresetAndScripts\n"
        macro_body += "if manager_api_ready then\n"
        macro_body += "(\n"
        macro_body += "    local manager_open = false\n"
        macro_body += "    if script_manager_ui != undefined then manager_open = script_manager_ui.inDialog\n"
        macro_body += "    if not manager_open then script_manager.showUI()\n"
        macro_body += "    if not(script_manager.loadPresetAndScripts \"" + preset_literal + "\") then\n"
        macro_body += "    (\n"
        macro_body += "        format \"[Script-Manager] Preset macro load failed: %\\n\" \"" + preset_literal + "\"\n"
        macro_body += "    )\n"
        macro_body += ")\n"
        macro_body += "else\n"
        macro_body += "(\n"
        macro_body += "    format \"[Script-Manager] Preset macro API is unavailable.\\n\"\n"
        macro_body += ")\n"

        macro_body
        -- return
    ),

    /*
    Creates or updates one persistent MacroScript action for loading the selected preset from a toolbar.
    */
    function createPresetMacro preset_name =
    (
        normalized_name = this.normalizePresetName preset_name
        if normalized_name == undefined then
        (
            format "[Script-Manager] Invalid preset MacroScript name: %\n" preset_name
            return false
        )
        if not(this.hasPreset normalized_name) then
        (
            format "[Script-Manager] Preset MacroScript source preset does not exist: %\n" normalized_name
            return false
        )

        action_name = this.getPresetMacroActionName normalized_name
        macro_body = this.buildPresetMacroBody normalized_name
        if action_name == undefined or macro_body == undefined then
        (
            format "[Script-Manager] Preset MacroScript source could not be built: %\n" normalized_name
            return false
        )

        macro_id = undefined

        try
        (
            macro_id = macros.new \
                "Script-Manager Presets" \
                action_name \
                ("Load Script-Manager preset: " + normalized_name) \
                (this.getPresetMacroButtonText normalized_name) \
                macro_body
        )
        catch
        (
            exception_text = getCurrentException()
            format "[Script-Manager] Preset MacroScript creation failed for %: %\n" normalized_name exception_text
            return false
        )

        if macro_id == undefined or macro_id <= 0 then
        (
            format "[Script-Manager] Preset MacroScript returned invalid action ID for %: %\n" normalized_name macro_id
            return false
        )

        format "[Script-Manager] Preset MacroScript ready: % | category: Script-Manager Presets\n" normalized_name
        true
        -- return
    ),

    /*
    Deletes one named Script-Manager preset section without changing current loader settings.
    Missing or invalid preset names return false.
    */
    function removePreset preset_name =
    (
        normalized_name = this.normalizePresetName preset_name
        if normalized_name == undefined then return false

        preset_section = this.getPresetSectionName normalized_name
        if not(hasINISetting ini_path preset_section) then return false

        startup_name = this.getStartupPresetName()
        if startup_name == normalized_name then
        (
            if not(this.clearStartupPreset()) then return false
        )

        delINISetting ini_path preset_section
        not(hasINISetting ini_path preset_section)
        -- return
    ),

    /*
    Returns the live preset dropdown from the dynamic PRESETS rollout.
    Undefined is returned while the rollout has not been built.
    */
    function getPresetDropdownControl =
    (
        if script_manager_presets_ui == undefined then return undefined

        script_manager_presets_ui.ddl_presets
        -- return
    ),

    /*
    Returns the STARTUP checkbutton from the dynamic PRESETS rollout.
    */
    function getPresetStartupControl =
    (
        if script_manager_presets_ui == undefined then return undefined

        script_manager_presets_ui.btn_preset_startup
        -- return
    ),

    /*
    Synchronizes the STARTUP checkbutton with the selected preset and persisted startup preset name.
    */
    function refreshPresetStartupControl =
    (
        startup_control = this.getPresetStartupControl()
        if startup_control == undefined then return false

        selected_name = this.getSelectedPresetName()
        startup_name = this.getStartupPresetName()

        preset_dropdown_syncing = true
        startup_control.enabled = selected_name != undefined
        startup_control.checked = selected_name != undefined and startup_name != undefined and selected_name == startup_name
        preset_dropdown_syncing = false

        true
        -- return
    ),

    /*
    Rebuilds the preset dropdown while suppressing load callbacks caused by selection changes.
    The neutral first item prevents refresh/open from applying any preset automatically.
    */
    function refreshPresetDropdown preferred_name:"" =
    (
        dropdown_control = this.getPresetDropdownControl()
        if dropdown_control == undefined then return false

        preset_names = this.getPresetNames()
        display_items = #("<Preset>")
        for preset_name in preset_names do append display_items preset_name

        target_selection = 1
        normalized_preferred_name = this.normalizePresetName preferred_name

        if normalized_preferred_name != undefined then
        (
            preset_index = findItem preset_names normalized_preferred_name
            if preset_index > 0 then target_selection = preset_index + 1
        )

        preset_dropdown_syncing = true
        dropdown_control.items = display_items
        dropdown_control.selection = target_selection
        preset_dropdown_syncing = false

        this.refreshPresetStartupControl()
        true
        -- return
    ),

    /*
    Returns the real preset name selected in the PRESETS dropdown.
    The neutral <Preset> item returns undefined.
    */
    function getSelectedPresetName =
    (
        dropdown_control = this.getPresetDropdownControl()
        if dropdown_control == undefined then return undefined

        preset_index = dropdown_control.selection
        if preset_index <= 1 or preset_index > dropdown_control.items.count then return undefined

        dropdown_control.items[preset_index]
        -- return
    ),

    /*
    Opens the standard 3ds Max rename dialog for a preset name.
    The normalized entered name is returned on OK; Cancel returns undefined.
    */
    function askPresetName default_value:"" =
    (
        preset_dialog = dotNetObject "MaxCustomControls.RenameInstanceDialog" default_value
        preset_dialog.text = "Save Script-Manager Preset"
        modal_result = preset_dialog.ShowModal()

        if modal_result.ToString() != "OK" then return undefined

        normalized_name = this.normalizePresetName preset_dialog.InstanceName

        if normalized_name == undefined then
        (
            messageBox "Enter a non-empty preset name without [ ], |, or line breaks." title:"Script-Manager Preset"
        )

        normalized_name
        -- return
    ),

    /*
    Returns the proposed toolbar name for one Windows account.
    Omitting user_name reads the current Windows user through System.Environment.
    */
    function getDefaultToolbarName user_name:undefined =
    (
        resolved_user_name = user_name

        if resolved_user_name == undefined then
        (
            environment_type = dotNetClass "System.Environment"
            resolved_user_name = environment_type.UserName as string
        )

        if resolved_user_name == undefined then resolved_user_name = "User"
        resolved_user_name = trimLeft (trimRight resolved_user_name)
        if resolved_user_name == "" then resolved_user_name = "User"

        resolved_user_name + " SCRIPT-MANAGER"
        -- return
    ),

    /*
    Opens the standard 3ds Max rename dialog for a toolbar name.
    The entered name is returned on OK; Cancel returns undefined.
    */
    function askToolbarName default_value:"" =
    (
        toolbar_dialog = dotNetObject "MaxCustomControls.RenameInstanceDialog" default_value
        toolbar_dialog.text = "Create Script Toolbar"
        modal_result = toolbar_dialog.ShowModal()

        if modal_result.ToString() != "OK" then return undefined

        toolbar_name = trimLeft (trimRight toolbar_dialog.InstanceName)

        if toolbar_name == "" or (findString toolbar_name "[") != undefined or (findString toolbar_name "]") != undefined or (findString toolbar_name "|") != undefined or (findString toolbar_name "\n") != undefined or (findString toolbar_name "\r") != undefined then
        (
            messageBox "Enter a non-empty toolbar name without [ ], |, or line breaks." title:"Script-Manager Toolbar"
            return undefined
        )

        toolbar_name
        -- return
    ),

    /*
    Returns HOST and DIRECT script paths in the supplied display order.
    OFF scripts are excluded.
    */
    function getToolbarScriptPaths script_paths:undefined =
    (
        source_paths = script_paths

        if source_paths == undefined then
        (
            source_paths = this.getDisplayedScriptPaths()

            if source_paths.count == 0 then
            (
                source_paths = copy available_script_paths
            )
        )

        toolbar_paths = #()

        for script_path in source_paths do
        (
            script_key = this.getScriptKey script_path
            load_mode = this.getScriptLoadMode script_key

            if load_mode != #skip then
            (
                append toolbar_paths script_path
            )
        )

        toolbar_paths
        -- return
    ),

    /*
    Escapes one string for use as an XML attribute value.
    */
    function escapeToolbarXmlValue source_text =
    (
        escaped_text = source_text as string
        escaped_text = substituteString escaped_text "&" "&amp;"
        escaped_text = substituteString escaped_text "\"" "&quot;"
        escaped_text = substituteString escaped_text "<" "&lt;"
        escaped_text = substituteString escaped_text ">" "&gt;"
        escaped_text
        -- return
    ),

    /*
    Escapes one value embedded in generated MaxScript string literals.
    */
    function escapeToolbarMaxScriptValue source_text =
    (
        escaped_text = source_text as string
        escaped_text = substituteString escaped_text "\\" "\\\\"
        escaped_text = substituteString escaped_text "\"" "\\\""
        escaped_text = substituteString escaped_text "\r" ""
        escaped_text = substituteString escaped_text "\n" "\\n"
        escaped_text
        -- return
    ),

    /*
    Returns a compact toolbar-button label derived from one script filename.
    Labels are limited to ten characters.
    */
    function getToolbarButtonLabel script_path =
    (
        button_label = getFilenameFile script_path
        button_label = substituteString button_label "-" " "
        button_label = substituteString button_label "_" " "
        button_label = trimLeft (trimRight button_label)

        if button_label.count > 10 then button_label = substring button_label 1 10
        if button_label == "" then button_label = "Script"

        button_label
        -- return
    ),

    /*
    Returns one deterministic MacroScript action name for a toolbar item index.
    */
    function getToolbarMacroName item_index =
    (
        "ScriptManagerToolbar_Action_" + (formattedPrint item_index format:"03d")
        -- return
    ),

    /*
    Builds the MacroScript source registered by the generated toolbar.
    Script-Manager is always the first action, followed by HOST and DIRECT scripts in tree order.
    */
    function buildToolbarMacroSource toolbar_name script_paths =
    (
        macro_category = "Script-Manager Toolbar"
        escaped_manager_path = this.escapeToolbarMaxScriptValue manager_source_path
        source_text = "macroScript ScriptManagerToolbar_OpenManager category:\"" + macro_category + "\" buttonText:\"Scripts\" tooltip:\"Open Script-Manager\"\n(\n"
        source_text += "    if script_manager != undefined then script_manager.showUI() else fileIn \"" + escaped_manager_path + "\" quiet:true\n"
        source_text += ")\n\n"

        for item_index = 1 to script_paths.count do
        (
            script_path = script_paths[item_index]
            macro_name = this.getToolbarMacroName item_index
            button_label = this.getToolbarButtonLabel script_path
            script_title = getFilenameFile script_path
            escaped_script_path = this.escapeToolbarMaxScriptValue script_path
            escaped_button_label = this.escapeToolbarMaxScriptValue button_label
            escaped_script_title = this.escapeToolbarMaxScriptValue script_title

            source_text += "macroScript " + macro_name + " category:\"" + macro_category + "\" buttonText:\"" + escaped_button_label + "\" tooltip:\"Open " + escaped_script_title + "\"\n(\n"
            source_text += "    if ScriptManagerIntegration != undefined then\n    (\n"
            source_text += "        load_result = ScriptManagerIntegration.loadScript \"" + escaped_script_path + "\" runtime_mode:#standalone quiet:true\n"
            source_text += "        if not load_result[1] then format \"[Script-Manager Toolbar] Failed to load: % | %\\n\" \"" + escaped_script_path + "\" load_result[2]\n"
            source_text += "    )\n    else\n    (\n"
            source_text += "        fileIn \"" + escaped_script_path + "\" quiet:true\n"
            source_text += "    )\n)\n\n"
        )

        source_text
        -- return
    ),

    /*
    Builds one CUIX toolbar window containing Script-Manager first and every configured script action after it.
    */
    function buildToolbarCuixWindow toolbar_name script_paths =
    (
        escaped_toolbar_name = this.escapeToolbarXmlValue toolbar_name
        macro_category = "Script-Manager Toolbar"
        window_text = "        <Window objectName=\"" + escaped_toolbar_name + "\" name=\"" + escaped_toolbar_name + "\" type=\"T\" cType=\"1\" toolbarRows=\"1\">\n"
        window_text += "            <Items>\n"
        window_text += "                <Item typeID=\"2\" type=\"CTB_MACROBUTTON\" width=\"61\" height=\"0\" controlID=\"0\" macroTypeID=\"3\" macroType=\"MB_TYPE_ACTION\" actionTableID=\"647394\" imageID=\"-1\" imageName=\"\" actionID=\"ScriptManagerToolbar_OpenManager`" + macro_category + "\" tip=\"Open Script-Manager\" label=\"Scripts\" />\n"

        for item_index = 1 to script_paths.count do
        (
            script_path = script_paths[item_index]
            macro_name = this.getToolbarMacroName item_index
            button_label = this.getToolbarButtonLabel script_path
            escaped_label = this.escapeToolbarXmlValue button_label
            escaped_tip = this.escapeToolbarXmlValue ("Open " + getFilenameFile script_path)
            button_width = button_label.count * 7 + 12
            if button_width < 40 then button_width = 40

            window_text += "                <Item typeID=\"2\" type=\"CTB_MACROBUTTON\" width=\"" + (button_width as string) + "\" height=\"0\" controlID=\"0\" macroTypeID=\"3\" macroType=\"MB_TYPE_ACTION\" actionTableID=\"647394\" imageID=\"-1\" imageName=\"\" actionID=\"" + macro_name + "`" + macro_category + "\" tip=\"" + escaped_tip + "\" label=\"" + escaped_label + "\" />\n"
        )

        window_text += "            </Items>\n"
        window_text += "        </Window>\n"
        window_text
        -- return
    ),

    /*
    Replaces a same-named toolbar in CUIX text and inserts the new toolbar before CUIWindows closes.
    Returns undefined when the source does not contain the required CUIWindows closing element.
    */
    function patchCuixToolbarText source_text toolbar_name script_paths =
    (
        if source_text == undefined or source_text == "" then return undefined

        escaped_toolbar_name = this.escapeToolbarXmlValue toolbar_name
        start_marker = "        <Window objectName=\"" + escaped_toolbar_name + "\""
        end_marker = "        </Window>"
        patched_text = source_text
        toolbar_start = findString patched_text start_marker

        if toolbar_start != undefined then
        (
            tail_text = substring patched_text toolbar_start (patched_text.count - toolbar_start + 1)
            relative_end = findString tail_text end_marker

            if relative_end == undefined then
            (
                format "[Script-Manager] Existing toolbar has no closing Window element: %\n" toolbar_name
                return undefined
            )

            toolbar_end = toolbar_start + relative_end + end_marker.count - 2
            prefix_text = if toolbar_start > 1 then substring patched_text 1 (toolbar_start - 1) else ""
            suffix_text = if toolbar_end < patched_text.count then substring patched_text (toolbar_end + 1) (patched_text.count - toolbar_end) else ""
            patched_text = prefix_text + suffix_text
        )

        insert_marker = "    </CUIWindows>"
        insert_index = findString patched_text insert_marker

        if insert_index == undefined then
        (
            format "[Script-Manager] CUIX does not contain CUIWindows closing element.\n"
            return undefined
        )

        prefix_text = if insert_index > 1 then substring patched_text 1 (insert_index - 1) else ""
        suffix_text = substring patched_text insert_index (patched_text.count - insert_index + 1)
        prefix_text + (this.buildToolbarCuixWindow toolbar_name script_paths) + suffix_text
        -- return
    ),

    /*
    Writes UTF-8 text with a BOM through the standard .NET file API.
    */
    function writeToolbarTextFile file_path file_text =
    (
        if file_path == undefined or file_path == "" or file_text == undefined then return false

        file_type = dotNetClass "System.IO.File"
        encoding_value = dotNetObject "System.Text.UTF8Encoding" true

        try
        (
            file_type.WriteAllText file_path file_text encoding_value
        )
        catch
        (
            exception_text = getCurrentException()
            format "[Script-Manager] Toolbar file write failed: % | %\n" file_path exception_text
            return false
        )

        doesFileExist file_path
        -- return
    ),

    /*
    Writes and registers the generated MacroScript actions used by toolbar buttons.
    */
    function writeToolbarMacroFile toolbar_name script_paths macro_path:undefined =
    (
        target_path = macro_path
        if target_path == undefined then target_path = (getDir #userMacros) + "\\Script-Manager-Toolbar-Actions.mcr"

        macro_source = this.buildToolbarMacroSource toolbar_name script_paths
        if not(this.writeToolbarTextFile target_path macro_source) then return false

        load_ok = true

        try
        (
            fileIn target_path quiet:true
        )
        catch
        (
            exception_text = getCurrentException()
            load_ok = false
            format "[Script-Manager] Toolbar MacroScript registration failed: % | %\n" target_path exception_text
        )

        load_ok
        -- return
    ),

    /*
    Resolves the complete path of the CUI configuration currently active in 3ds Max.
    */
    function getActiveCuixPath =
    (
        config_file = cui.getConfigFile()
        if config_file == undefined or config_file == "" then return ""
        if doesFileExist config_file then return config_file

        config_directory = cui.getDir()
        if config_directory == undefined or config_directory == "" then return ""

        normalized_directory = ScriptManagerIntegration.normalizeDirectoryPath config_directory
        resolved_path = normalized_directory + config_file
        if not(doesFileExist resolved_path) then return ""

        resolved_path
        -- return
    ),

    /*
    Saves the current UI into a temporary CUIX, patches and loads it live, and optionally saves the result back to the original active CUIX.
    */
    function createToolbar toolbar_name save_ui:true script_paths:undefined =
    (
        normalized_toolbar_name = trimLeft (trimRight toolbar_name)
        if normalized_toolbar_name == "" then return false

        toolbar_paths = this.getToolbarScriptPaths script_paths:script_paths
        active_cuix_path = this.getActiveCuixPath()

        if active_cuix_path == "" then
        (
            format "[Script-Manager] Active CUIX path could not be resolved.\n"
            return false
        )

        if not(this.writeToolbarMacroFile normalized_toolbar_name toolbar_paths) then return false

        temporary_cuix_path = (getDir #temp) + "\\Script-Manager-Toolbar-" + ((timestamp()) as string) + ".cuix"

        if not(cui.saveConfigAs temporary_cuix_path) then
        (
            format "[Script-Manager] Current UI could not be saved to temporary CUIX: %\n" temporary_cuix_path
            return false
        )

        file_type = dotNetClass "System.IO.File"
        source_text = undefined

        try
        (
            source_text = file_type.ReadAllText temporary_cuix_path
        )
        catch
        (
            exception_text = getCurrentException()
            format "[Script-Manager] Temporary CUIX read failed: % | %\n" temporary_cuix_path exception_text
            return false
        )

        patched_text = this.patchCuixToolbarText source_text normalized_toolbar_name toolbar_paths
        if patched_text == undefined then return false
        if not(this.writeToolbarTextFile temporary_cuix_path patched_text) then return false

        if not(cui.loadConfig temporary_cuix_path) then
        (
            format "[Script-Manager] Patched temporary CUIX could not be loaded: %\n" temporary_cuix_path
            return false
        )

        if save_ui then
        (
            if not(cui.saveConfigAs active_cuix_path) then
            (
                format "[Script-Manager] Loaded toolbar could not be saved to active CUIX: %\n" active_cuix_path
                return false
            )

            if not(cui.loadConfig active_cuix_path) then
            (
                format "[Script-Manager] Saved active CUIX could not be reloaded: %\n" active_cuix_path
                return false
            )
        )

        if not(cui.showToolbar normalized_toolbar_name) then
        (
            format "[Script-Manager] Toolbar was loaded but could not be shown: %\n" normalized_toolbar_name
            return false
        )

        true
        -- return
    ),

    /*
    Prompts for the toolbar name and creates it from every HOST and DIRECT script.
    SAVE UI is enabled by default so the generated toolbar is not accidentally left temporary.
    */
    function handleCreateToolbar save_ui:true =
    (
        toolbar_name = this.askToolbarName default_value:(this.getDefaultToolbarName())
        if toolbar_name == undefined then return true

        if this.createToolbar toolbar_name save_ui:save_ui then
        (
            true
        )
        else
        (
            messageBox ("Could not create toolbar \"" + toolbar_name + "\". See the Listener for details.") title:"Script-Manager Toolbar"
            false
        )
        -- return
    ),

    /*
    Handles LMB on SAVE \\ REMOVE by naming and saving the current loader configuration.
    Existing named presets are replaced only after explicit confirmation.
    */
    function handlePresetSave =
    (
        selected_name = this.getSelectedPresetName()
        default_name = if selected_name == undefined then "" else selected_name
        preset_name = this.askPresetName default_value:default_name
        if preset_name == undefined then return true

        save_confirmed = true

        if this.hasPreset preset_name then
        (
            save_confirmed = queryBox ("Preset \"" + preset_name + "\" already exists. Replace it?") title:"Script-Manager Preset"
        )

        if not save_confirmed then return true

        if this.savePreset preset_name then
        (
            this.refreshPresetDropdown preferred_name:preset_name
            true
        )
        else
        (
            messageBox ("Could not save preset \"" + preset_name + "\".") title:"Script-Manager Preset"
            false
        )
        -- return
    ),

    /*
    Handles RMB on SAVE \\ REMOVE by deleting the preset selected in the dropdown.
    Current SOURCES and script load modes are never changed by preset deletion.
    */
    function handlePresetRemove =
    (
        preset_name = this.getSelectedPresetName()

        if preset_name == undefined then
        (
            messageBox "Select a preset in the dropdown before removing it." title:"Script-Manager Preset"
            return false
        )

        remove_confirmed = queryBox ("Remove preset \"" + preset_name + "\"?") title:"Script-Manager Preset"
        if not remove_confirmed then return true

        if this.removePreset preset_name then
        (
            this.refreshPresetDropdown()
            true
        )
        else
        (
            messageBox ("Could not remove preset \"" + preset_name + "\".") title:"Script-Manager Preset"
            false
        )
        -- return
    ),

    /*
    Handles one preset dropdown selection without changing loader configuration.
    Selection only updates PRESETS controls; LOAD performs the actual restore and execution.
    */
    function handlePresetSelected item_index =
    (
        if preset_dropdown_syncing then return true
        if item_index < 1 then return false

        this.refreshPresetStartupControl()
        true
        -- return
    ),

    /*
    Applies and hard reloads the preset currently selected in the PRESETS rollout.
    */
    function handlePresetLoad =
    (
        preset_name = this.getSelectedPresetName()

        if preset_name == undefined then
        (
            messageBox "Select a preset before loading it." title:"Script-Manager Preset"
            return false
        )

        if this.loadPresetAndScripts preset_name then
        (
            true
        )
        else
        (
            messageBox ("Could not load preset \"" + preset_name + "\".") title:"Script-Manager Preset"
            false
        )
        -- return
    ),

    /*
    Creates or updates the persistent toolbar MacroScript action for the selected preset.
    */
    function handlePresetMacro =
    (
        preset_name = this.getSelectedPresetName()

        if preset_name == undefined then
        (
            messageBox "Select a preset before creating its MacroScript action." title:"Script-Manager Preset"
            return false
        )

        if this.createPresetMacro preset_name then
        (
            true
        )
        else
        (
            messageBox ("Could not create the MacroScript action for preset \"" + preset_name + "\".") title:"Script-Manager Preset"
            false
        )
        -- return
    ),

    /*
    Handles the STARTUP checkbutton by assigning or clearing the unique startup preset.
    */
    function handlePresetStartupChanged startup_state =
    (
        if preset_dropdown_syncing then return true

        preset_name = this.getSelectedPresetName()

        if startup_state then
        (
            if preset_name == undefined then
            (
                this.refreshPresetStartupControl()
                messageBox "Select a preset before marking it for startup." title:"Script-Manager Preset"
                return false
            )

            if not(this.setStartupPreset preset_name) then
            (
                this.refreshPresetStartupControl()
                messageBox ("Could not set preset \"" + preset_name + "\" as the startup preset.") title:"Script-Manager Preset"
                return false
            )
        )
        else
        (
            startup_name = this.getStartupPresetName()

            if startup_name != undefined and preset_name == startup_name then
            (
                if not(this.clearStartupPreset()) then
                (
                    this.refreshPresetStartupControl()
                    messageBox "Could not clear the startup preset." title:"Script-Manager Preset"
                    return false
                )
            )
        )

        this.refreshPresetStartupControl()
        true
        -- return
    ),

    /*
    Returns whether one script participates in any persisted load mode.
    This compatibility wrapper treats both hosted and direct-run modes as enabled.
    */
    function getScriptEnabled script_key script_name:"" =
    (
        (this.getScriptLoadMode script_key) != #skip
        -- return
    ),

    /*
    Saves the legacy Boolean script state as hosted or skipped.
    */
    function saveScriptEnabled script_key enabled =
    (
        this.saveScriptLoadMode script_key (if enabled then #host else #skip)
        -- return
    ),

    /*
    Converts one persisted script load mode to its SCRIPTS TreeView state-image index.
    */
    function getScriptLoadModeStateIndex load_mode =
    (
        case load_mode of
        (
            #host: 1
            #direct: 2
            default: 0
        )
        -- return
    ),

    /*
    Returns the legacy combined loader-open state used as the migration fallback.
    */
    function loadLoaderOpenState =
    (
        this.getIniBoolean "Loader" "Open" true
        -- return
    ),

    /*
    Saves the legacy combined loader-open state for backwards compatibility.
    */
    function saveLoaderOpenState open_state =
    (
        setINISetting ini_path "Loader" "Open" (if open_state then "1" else "0") forceUTF16:false
        true
        -- return
    ),

    /*
    Returns the saved expanded state of the PRESETS rollout.
    Existing installs inherit the previous combined Loader/Open state.
    */
    function loadPresetRolloutOpenState =
    (
        saved_text = getINISetting ini_path "Loader" "PresetsOpen"
        if saved_text == "" then return this.loadLoaderOpenState()

        saved_text == "1"
        -- return
    ),

    /*
    Saves the expanded state of the PRESETS rollout.
    */
    function savePresetRolloutOpenState open_state =
    (
        setINISetting ini_path "Loader" "PresetsOpen" (if open_state then "1" else "0") forceUTF16:false
        true
        -- return
    ),

    /*
    Returns the saved expanded state of the OPTIONS rollout.
    Existing installs inherit the previous combined Loader/Open state.
    */
    function loadOptionsRolloutOpenState =
    (
        saved_text = getINISetting ini_path "Loader" "OptionsOpen"
        if saved_text == "" then return this.loadLoaderOpenState()

        saved_text == "1"
        -- return
    ),

    /*
    Saves the expanded state of the OPTIONS rollout.
    */
    function saveOptionsRolloutOpenState open_state =
    (
        setINISetting ini_path "Loader" "OptionsOpen" (if open_state then "1" else "0") forceUTF16:false
        true
        -- return
    ),

    /*
    Returns the saved expanded state of the SOURCES rollout.
    Existing installs inherit the previous combined Loader/Open state.
    */
    function loadSourceRolloutOpenState =
    (
        saved_text = getINISetting ini_path "Loader" "SourcesOpen"
        if saved_text == "" then return this.loadLoaderOpenState()

        saved_text == "1"
        -- return
    ),

    /*
    Saves the expanded state of the SOURCES rollout.
    */
    function saveSourceRolloutOpenState open_state =
    (
        setINISetting ini_path "Loader" "SourcesOpen" (if open_state then "1" else "0") forceUTF16:false
        true
        -- return
    ),

    /*
    Loads the independent SHOW & IGNORE rollout state; existing installations start expanded.
    */
    function loadShowIgnoreRolloutOpenState =
    (
        this.getIniBoolean "Loader" "ShowIgnoreOpen" true
        -- return
    ),

    /*
    Saves the independent SHOW & IGNORE rollout expanded state.
    */
    function saveShowIgnoreRolloutOpenState open_state =
    (
        setINISetting ini_path "Loader" "ShowIgnoreOpen" (if open_state then "1" else "0") forceUTF16:false
        true
        -- return
    ),

    /*
    Loads the SHOW section state, migrating from the former SHOW & IGNORE section.
    */
    function loadShowRolloutOpenState =
    (
        saved_text = getINISetting ini_path "Loader" "ShowOpen"
        if saved_text == "" then return this.loadShowIgnoreRolloutOpenState()

        saved_text == "1"
        -- return
    ),

    /*
    Saves the SHOW section expanded state independently.
    */
    function saveShowRolloutOpenState open_state =
    (
        setINISetting ini_path "Loader" "ShowOpen" (if open_state then "1" else "0") forceUTF16:false
        true
        -- return
    ),

    /*
    Loads the IGNORE section state, migrating from the former SHOW & IGNORE section.
    */
    function loadIgnoreRolloutOpenState =
    (
        saved_text = getINISetting ini_path "Loader" "IgnoreOpen"
        if saved_text == "" then return this.loadShowIgnoreRolloutOpenState()

        saved_text == "1"
        -- return
    ),

    /*
    Saves the IGNORE section expanded state independently.
    */
    function saveIgnoreRolloutOpenState open_state =
    (
        setINISetting ini_path "Loader" "IgnoreOpen" (if open_state then "1" else "0") forceUTF16:false
        true
        -- return
    ),

    /*
    Returns the saved expanded state of the SCRIPTS rollout.
    Existing installs inherit the previous combined Loader/Open state.
    */
    function loadScriptRolloutOpenState =
    (
        saved_text = getINISetting ini_path "Loader" "ScriptsOpen"
        if saved_text == "" then return this.loadLoaderOpenState()

        saved_text == "1"
        -- return
    ),

    /*
    Saves the expanded state of the SCRIPTS rollout.
    */
    function saveScriptRolloutOpenState open_state =
    (
        setINISetting ini_path "Loader" "ScriptsOpen" (if open_state then "1" else "0") forceUTF16:false
        true
        -- return
    ),

    /*
    Returns whether one .ms file is an automatically loaded UI companion for a sibling backend script.
    Paired <Backend>-UI.ms files stay hidden from discovery because selecting the backend loads the companion automatically.
    */
    function isAutoCompanionScriptPath script_path =
    (
        if script_path == undefined or script_path == "" then return false
        if (toLower (getFilenameType script_path)) != ".ms" then return false

        script_stem = getFilenameFile script_path
        if not(matchPattern script_stem pattern:"*-UI" ignoreCase:true) then return false
        if script_stem.count <= 3 then return false

        backend_stem = substring script_stem 1 (script_stem.count - 3)
        backend_path = getFilenamePath script_path + backend_stem + ".ms"

        doesFileExist backend_path
        -- return
    ),

    /*
    Returns whether one script is the clean canonical file for its parent folder.
    The basename must exactly match the parent folder name and must not carry a numeric version suffix.
    */
    function isCleanCanonicalScriptPath script_path directory_path =
    (
        if not(this.isSupportedScriptPath script_path) then return false

        normalized_directory = ScriptManagerIntegration.normalizeDirectoryPath directory_path
        if normalized_directory == "" then return false

        parent_folder_name = ScriptManagerIntegration.getFolderName normalized_directory
        script_stem = getFilenameFile script_path
        version_info = this.getScriptVersionInfo script_path

        not(version_info[1]) and (toLower script_stem) == (toLower parent_folder_name)
        -- return
    ),

    /*
    Returns visible MaxScript files directly inside one directory.
    CLEAN SCRIPTS 1 keeps only a directory-matching unversioned script; state 2 falls back to
    all supported scripts if that directory has no such match. State 0 uses version filtering.
    */
    function getScriptFilesInDirectory directory_path =
    (
        raw_files = this.getRawScriptFilesInDirectory directory_path

        if show_clean_scripts_only then
        (
            clean_files = #()

            for script_path in raw_files do
            (
                if this.isCleanCanonicalScriptPath script_path directory_path then append clean_files script_path
            )

            if clean_files.count > 0 or not show_unclear_scripts then return this.sortScriptPathsNewestFirst clean_files

            -- No canonical folder-name match: expose otherwise hidden scripts in mode 2.
            return raw_files
        )

        if show_versioned_files then return raw_files

        visible_files = #()
        family_keys = #()
        family_canonical_paths = #()
        family_latest_paths = #()
        family_latest_versions = #()

        for script_path in raw_files do
        (
            version_info = this.getScriptVersionInfo script_path
            extension_text = toLower (getFilenameType script_path)
            family_stem = if version_info[1] then version_info[2] else getFilenameFile script_path
            family_key = toLower (family_stem + extension_text)
            family_index = findItem family_keys family_key

            if family_index == 0 then
            (
                append family_keys family_key
                append family_canonical_paths ""
                append family_latest_paths ""
                append family_latest_versions undefined
                family_index = family_keys.count
            )

            if version_info[1] then
            (
                current_latest_version = family_latest_versions[family_index]
                if current_latest_version == undefined or version_info[3] > current_latest_version then
                (
                    family_latest_versions[family_index] = version_info[3]
                    family_latest_paths[family_index] = script_path
                )
            )
            else
            (
                family_canonical_paths[family_index] = script_path
            )
        )

        for family_index = 1 to family_keys.count do
        (
            canonical_path = family_canonical_paths[family_index]
            latest_path = family_latest_paths[family_index]

            if canonical_path != "" then
            (
                append visible_files canonical_path
            )
            else if latest_path != "" then
            (
                append visible_files latest_path
            )
        )

        this.sortScriptPathsNewestFirst visible_files
        -- return
    ),

    /*
    Recursively appends every script path below one directory to the supplied array.
    The manager root directory itself is included by the caller.
    */
    function collectScriptPathsRecursive directory_path script_paths =
    (
        normalized_path = ScriptManagerIntegration.normalizeDirectoryPath directory_path
        if normalized_path == "" then return false
        if this.isManagerPackageDirectory normalized_path then return true
        if this.isDefaultExcludedSourceDirectory normalized_path then return true

        for script_path in (this.getScriptFilesInDirectory normalized_path) do
        (
            append script_paths script_path
        )

        child_directories = getDirectories (normalized_path + "*")
        sort child_directories

        for child_directory in child_directories do
        (
            this.collectScriptPathsRecursive child_directory script_paths
        )

        true
        -- return
    ),

    /*
    Returns every supported MaxScript file below the managed root.
    The result includes root-level scripts plus scripts in every nested directory.
    */
    function getAllScriptPaths =
    (
        script_paths = #()

        if root_directory == "" then return script_paths

        this.collectScriptPathsRecursive root_directory script_paths
        sort script_paths
        script_paths
        -- return
    ),

    /*
    Adds one directory and its complete script hierarchy below an existing TreeView node collection.
    Folder nodes mirror the filesystem; script leaf nodes store their full source path in Tag and ToolTipText.
    */
    function addScriptDirectoryTreeNodes node_collection directory_path =
    (
        normalized_path = ScriptManagerIntegration.normalizeDirectoryPath directory_path
        if normalized_path == "" then return false
        if this.isManagerPackageDirectory normalized_path then return true

        child_directories = getDirectories (normalized_path + "*")
        sort child_directories

        for child_directory in child_directories do
        (
            if not(this.isManagerPackageDirectory child_directory) and this.directoryHasManagedScripts child_directory then
            (
                folder_name = ScriptManagerIntegration.getFolderName child_directory
                folder_node = node_collection.Add folder_name
                folder_node.Tag = child_directory
                folder_node.ToolTipText = child_directory

                this.addScriptDirectoryTreeNodes folder_node.Nodes child_directory
            )
        )

        for script_path in (this.getScriptFilesInDirectory normalized_path) do
        (
            script_name = pathConfig.stripPathToLeaf script_path
            script_node = node_collection.Add script_name
            script_node.Tag = script_path
            script_node.ToolTipText = script_path
            script_tree_file_count += 1
        )

        true
        -- return
    ),

    /*
    Returns the active SCRIPTS TreeView control when the dynamic rollout exists.
    Missing loader UI returns undefined instead of raising a property error.
    */
    /*
    Returns the active SOURCES TreeView control when the dynamic loader rollout exists.
    */
    function getSourceTreeControl =
    (
        if script_manager_sources_ui == undefined then return undefined

        script_manager_sources_ui.tv_sources
        -- return
    ),

    /*
    Returns the source-root edit control from the OPTIONS rollout when available.
    */
    function getSourceRootPathControl =
    (
        if options_rollout == undefined then return undefined

        options_rollout.edt_source_root
        -- return
    ),

    /*
    Returns the IGNORE section edit control inside OPTIONS when available.
    */
    function getScriptIgnoreMaskControl =
    (
        if ignore_rollout == undefined then return undefined

        ignore_rollout.edt_script_ignore
        -- return
    ),

    /*
    Compatibility wrapper for callers using the previous SOURCES ignore-control helper name.
    */
    function getSourceIgnoreMaskControl =
    (
        this.getScriptIgnoreMaskControl()
        -- return
    ),

    /*
    Opens a folder browser and commits an accepted source root after disposing the dialog.
    Cancel leaves the current root and pending edit unchanged.
    */
    function browseSourceRootDirectory =
    (
        root_control = this.getSourceRootPathControl()
        if root_control == undefined then return false

        browse_dialog = dotNetObject "System.Windows.Forms.FolderBrowserDialog"
        browse_dialog.Description = "Select Script-Manager source root."
        browse_dialog.ShowNewFolderButton = false

        current_path = ScriptManagerIntegration.normalizeDirectoryPath root_control.text
        directory_type = dotNetClass "System.IO.Directory"

        if current_path != "" and directory_type.Exists current_path then
        (
            current_path_no_slash = substring current_path 1 (current_path.count - 1)
            browse_dialog.SelectedPath = current_path_no_slash
        )

        dialog_result_type = dotNetClass "System.Windows.Forms.DialogResult"
        dialog_result = browse_dialog.ShowDialog()

        selected_path = ""
        if dialog_result == dialog_result_type.OK then selected_path = browse_dialog.SelectedPath
        browse_dialog.Dispose()

        if dialog_result != dialog_result_type.OK then return false
        this.applyBrowsedSourceRootDirectory selected_path
        -- return
    ),

    /* Commits an accepted BROWSE result through the same verified save and discovery path as REFRESH.
    Typed edits remain pending until REFRESH; browsing explicitly applies the selected directory.
    */
    function applyBrowsedSourceRootDirectory directory_path =
    (
        if is_reloading then return false
        root_control = this.getSourceRootPathControl()
        if root_control == undefined then return false

        root_control.text = ScriptManagerIntegration.normalizeDirectoryPath directory_path
        this.handleManualRefresh()
        -- return
    ),

    /*
    Applies the standard dark TreeView appearance to one manager tree.
    */
    function styleTreeControl tree_control check_boxes:true =
    (
        if tree_control == undefined then return false

        color_type = dotNetClass "System.Drawing.Color"
        border_style_type = dotNetClass "System.Windows.Forms.BorderStyle"
        style_marker = if tree_control.Tag == undefined then "" else tree_control.Tag as string

        tree_control.BackColor = color_type.FromArgb 45 45 48
        tree_control.ForeColor = color_type.FromArgb 225 225 225
        tree_control.BorderStyle = border_style_type.FixedSingle
        tree_control.CheckBoxes = check_boxes

        if style_marker != "SCRIPT_MANAGER_TREE_STYLED" then
        (
            graphics_value = tree_control.CreateGraphics()
            dpi_value = graphics_value.DpiY
            graphics_value.Dispose()
            if dpi_value <= 0 then dpi_value = 96.0

            target_font_points = tree_control.Font.SizeInPoints + ((script_tree_font_pixel_increase as float) * 72.0 / dpi_value)
            tree_control.Font = dotNetObject "System.Drawing.Font" tree_control.Font.FontFamily target_font_points tree_control.Font.Style
            tree_control.ItemHeight = tree_control.Font.Height + 4
            tree_control.Tag = "SCRIPT_MANAGER_TREE_STYLED"
        )

        true
        -- return
    ),

    /*
    Builds explicit dark-UI-safe SOURCES row images.
    Image 0 is transparent for display-only tool rows; images 1/2 are unchecked/checked source glyphs.
    */
    function buildSourceTreeStateImages =
    (
        image_list = dotNetObject "System.Windows.Forms.ImageList"
        image_list.ImageSize = dotNetObject "System.Drawing.Size" 16 16

        color_depth_type = dotNetClass "System.Windows.Forms.ColorDepth"
        image_list.ColorDepth = color_depth_type.Depth32Bit

        color_type = dotNetClass "System.Drawing.Color"
        graphics_type = dotNetClass "System.Drawing.Graphics"
        transparent_color = color_type.Transparent
        border_color = color_type.FromArgb 205 205 205
        active_color = color_type.FromArgb 62 158 255

        blank_bitmap = dotNetObject "System.Drawing.Bitmap" 16 16
        blank_graphics = graphics_type.FromImage blank_bitmap
        blank_graphics.Clear transparent_color
        blank_graphics.Dispose()
        image_list.Images.Add blank_bitmap

        for state_index = 0 to 1 do
        (
            bitmap_value = dotNetObject "System.Drawing.Bitmap" 16 16
            graphics_value = graphics_type.FromImage bitmap_value
            graphics_value.Clear transparent_color

            border_pen_value = dotNetObject "System.Drawing.Pen" border_color 1.0
            graphics_value.DrawRectangle border_pen_value 2 2 11 11
            border_pen_value.Dispose()

            if state_index == 1 then
            (
                active_pen_value = dotNetObject "System.Drawing.Pen" active_color 2.0
                graphics_value.DrawLine active_pen_value 4 8 7 11
                graphics_value.DrawLine active_pen_value 7 11 12 5
                active_pen_value.Dispose()
            )

            graphics_value.Dispose()
            image_list.Images.Add bitmap_value
        )

        source_tree_state_images = image_list
        true
        -- return
    ),

    /*
    Returns whether one SOURCES row represents a selectable recursive source rather than a display-only terminal directory.
    */
    function isSourceTreeNodeSelectable tree_node =
    (
        if tree_node == undefined then return false
        tree_node.Name == "SOURCE_SELECTABLE"
        -- return
    ),

    /*
    Applies the persisted enabled state to one selectable SOURCES row.
    */
    function setSourceTreeNodeVisualState tree_node enabled =
    (
        if tree_node == undefined then return false

        image_index = if enabled then 2 else 1
        tree_node.ImageIndex = image_index
        tree_node.SelectedImageIndex = image_index
        true
        -- return
    ),

    /*
    Applies the dark SOURCES TreeView style with custom per-row checkbox images.
    Native TreeView checkboxes stay disabled; display-only tool rows use the explicit transparent image slot.
    */
    function styleSourceTree =
    (
        tree_control = this.getSourceTreeControl()
        if tree_control == undefined then return false

        if not(this.styleTreeControl tree_control check_boxes:false) then return false
        if source_tree_state_images == undefined then
        (
            if not(this.buildSourceTreeStateImages()) then return false
        )

        tree_control.ImageList = source_tree_state_images
        tree_control.ImageIndex = 0
        tree_control.SelectedImageIndex = 0
        true
        -- return
    ),

    /*
    Renders the already-discovered SOURCES tree; initial construction leaves every branch collapsed.
    */
    function populateSourceTree restore_expansion:true =
    (
        source_tree = this.getSourceTreeControl()
        if source_tree == undefined then return false

        timing_start = timestamp()
        source_tree_syncing_checks = true
        populate_ok = true

        try
        (
            if not(this.styleSourceTree()) then throw "styleSourceTree returned false"
            if source_tree_context_menu == undefined then this.buildSourceTreeContextMenu()
            source_tree.BeginUpdate()
            source_tree.Nodes.Clear()
            source_tree.ShowNodeToolTips = true
            source_tree.HideSelection = false
            source_tree.FullRowSelect = true

            source_node_lookup = dotNetObject "System.Collections.Hashtable"
            source_node_values = #()

            for source_index = 1 to available_source_directories.count do
            (
                source_name = available_source_names[source_index]
                source_directory = available_source_directories[source_index]
                relative_path = this.getRelativeDirectoryPath source_directory
                parent_relative_path = this.getParentRelativePath relative_path
                parent_nodes = source_tree.Nodes

                if parent_relative_path != "" then
                (
                    parent_key = toLower parent_relative_path
                    if source_node_lookup.ContainsKey parent_key then parent_nodes = source_node_lookup.Item[parent_key].Nodes
                )

                source_selectable = false
                if source_index <= available_source_selectable.count then source_selectable = available_source_selectable[source_index]
                source_node = parent_nodes.Add source_name
                source_node.Tag = source_directory
                source_node.Name = if source_selectable then "SOURCE_SELECTABLE" else "SOURCE_TOOL"

                if source_selectable then
                (
                    source_node.ToolTipText = source_directory
                    if not(this.setSourceTreeNodeVisualState source_node (this.getSourceEnabled source_directory)) then throw "setSourceTreeNodeVisualState returned false"
                )
                else
                (
                    source_node.ToolTipText = source_directory
                    source_node.ImageIndex = 0
                    source_node.SelectedImageIndex = 0
                )

                source_node_lookup.Add (toLower relative_path) source_node
                append source_node_values source_node
            )

            tree_expansion_syncing = true

            if restore_expansion then
            (
                for source_node in source_node_values do
                (
                    if this.loadTreeNodeOpenState source_node "SourceTreeOpen" then source_node.Expand() else source_node.Collapse()
                )
            )

            tree_expansion_syncing = false
            source_tree.EndUpdate()
        )
        catch
        (
            exception_text = getCurrentException()
            populate_ok = false

            try
            (
                source_tree.EndUpdate()
            )
            catch
            (
                cleanup_exception_text = getCurrentException()
            )

            format "[Script-Manager] Source tree population failed: %\n" exception_text
        )

        tree_expansion_syncing = false
        source_tree_syncing_checks = false
        timing_elapsed_ms = timestamp() - timing_start
        format "[Script-Manager][TIMING] SOURCES TREE RENDER | % ms | folders:% | success:%\n" timing_elapsed_ms available_source_directories.count populate_ok
        populate_ok
        -- return
    ),

    /*
    Populates SOURCES once after its rollout opens, with a fallback during initial loader construction.
    Both paths share this guard so the first startup never renders the same TreeView twice.
    */
    function populateInitialSourceTree =
    (
        if source_tree_initialized then return true
        if this.getSourceTreeControl() == undefined then return false

        source_tree_initialized = this.populateSourceTree restore_expansion:false
        source_tree_initialized
        -- return
    ),

    /*
    Refreshes script discovery and host categories after source/filter configuration changes without auto-loading scripts.
    */
function refreshConfiguredDiscovery =
(
    if is_reloading then return false
    if script_manager_ui == undefined then return false

    is_reloading = true
    refresh_ok = true

    try
    (
        if not(this.clearLoadedRollouts()) then throw "clearLoadedRollouts returned false"
        if not(this.discoverScripts()) then throw "discoverScripts returned false"
        if not(this.populateScriptTree()) then throw "populateScriptTree returned false"
        if not(this.prepareScriptHost()) then throw "prepareScriptHost returned false"
    )
    catch
    (
        exception_text = getCurrentException()
        refresh_ok = false
        format "[Script-Manager] Source/filter refresh failed: %\n" exception_text
    )

    is_reloading = false
    refresh_ok
    -- return
),

    /*
    Persists a SOURCES checkbox change and refreshes only the selected discovery scope.
    */
    function handleSourceTreeAfterCheck check_args =
    (
        if check_args == undefined or check_args.Node == undefined then return false
        if source_tree_syncing_checks then return true
        if not(this.isSourceTreeNodeSelectable check_args.Node) then return true

        tree_action_type = dotNetClass "System.Windows.Forms.TreeViewAction"
        if check_args.Action == tree_action_type.Unknown then return true

        source_directory = check_args.Node.Tag
        if source_directory == undefined or source_directory == "" then return false
        if not(this.saveSourceEnabled source_directory check_args.Node.Checked) then return false

        this.refreshConfiguredDiscovery()
        -- return
    ),

    /*
    Validates one pending SCRIPTS ignore-mask edit without saving it or rebuilding the tree.
    The edit remains a draft value until the user presses LMB REFRESH.
    */
    function handleScriptIgnoreMaskChanged mask_text =
    (
        this.buildScriptIgnorePatterns mask_text
        true
        -- return
    ),

    /*
    Compatibility wrapper for callers using the previous SOURCES ignore-change helper name.
    */
    function handleSourceIgnoreMaskChanged mask_text =
    (
        this.handleScriptIgnoreMaskChanged mask_text
        -- return
    ),

    /*
    Keeps ENTER in the SCRIPTS IGNORE field non-destructive.
    The field is validated only; LMB REFRESH remains the single save/apply action.
    */
    function handleScriptIgnoreMaskEntered mask_text =
    (
        this.handleScriptIgnoreMaskChanged mask_text
        -- return
    ),

    /*
    Compatibility wrapper for callers using the previous SOURCES ignore-enter helper name.
    */
    function handleSourceIgnoreMaskEntered mask_text =
    (
        this.handleScriptIgnoreMaskEntered mask_text
        -- return
    ),

    /*
    Saves the pending ROOT PATH value from OPTIONS without rebuilding the UI.
    */
    function applyPendingSourceOptions =
    (
        root_control = this.getSourceRootPathControl()
        if root_control == undefined then
        (
            format "[Script-Manager] ROOT PATH save failed | OPTIONS control is not available.\n"
            return false
        )

        pending_root = root_control.text

        normalized_root = ScriptManagerIntegration.normalizeDirectoryPath pending_root
        directory_type = dotNetClass "System.IO.Directory"

        if normalized_root == "" or not(directory_type.Exists normalized_root) then
        (
            format "[Script-Manager] ROOT PATH invalid | path:%\n" pending_root
            return false
        )

        this.saveSourceRootDirectory normalized_root
        -- return
    ),

    /*
    Saves the pending SCRIPTS IGNORE value without rebuilding the UI.
    */
    function applyPendingScriptOptions =
    (
        ignore_control = this.getScriptIgnoreMaskControl()
        if ignore_control == undefined then
        (
            format "[Script-Manager] IGNORE save failed | SCRIPTS control is not available.\n"
            return false
        )

        scriptManagerPersistIgnoreMask this ignore_control.text
        -- return
    ),

    /*
    Saves pending OPTIONS and refreshes the existing SOURCES/SCRIPTS trees in place.
    The loader rollouts are not destroyed or recreated, so .NET REFRESH is safe and preserves the edited OPTIONS controls.
    */
    function handleManualRefresh =
    (
        if is_reloading then
        (
            format "[Script-Manager] REFRESH skipped | another load or refresh is running.\n"
            return false
        )

        if script_manager_ui == undefined then
        (
            format "[Script-Manager] REFRESH failed | manager dialog is unavailable.\n"
            return false
        )

        format "[Script-Manager] REFRESH LMB | saving pending IGNORE and ROOT PATH.\n"

        if not(this.applyPendingScriptOptions()) then
        (
            format "[Script-Manager] REFRESH failed | IGNORE could not be saved.\n"
            return false
        )

        previous_root = ScriptManagerIntegration.normalizeDirectoryPath root_directory
        if not(this.applyPendingSourceOptions()) then
        (
            format "[Script-Manager] REFRESH failed | ROOT PATH invalid or could not be saved; IGNORE was saved.\n"
            return false
        )

        is_reloading = true
        refresh_ok = true

        try
        (
            if not(this.discoverSources()) then throw "discoverSources returned false"
            if not(this.initializeSourceSelection new_root:(previous_root != root_directory)) then throw "initializeSourceSelection returned false"
            if not(this.populateSourceTree()) then throw "populateSourceTree returned false"
            if not(this.discoverScripts()) then throw "discoverScripts returned false"
            if not(this.populateScriptTree()) then throw "populateScriptTree returned false"
            if not(this.prepareScriptHost()) then throw "prepareScriptHost returned false"
            if not(this.layoutManager [script_manager_ui.width, script_manager_ui.height]) then throw "layoutManager returned false"
        )
        catch
        (
            exception_text = getCurrentException()
            refresh_ok = false
            format "[Script-Manager] Manual refresh failed: %\n" exception_text
        )

        is_reloading = false
        if refresh_ok then
        (
            format "[Script-Manager] REFRESH OK | IGNORE:% | SCRIPTS:% | SOURCE FOLDERS:%\n" source_ignore_mask available_script_paths.count available_source_directories.count
        )
        refresh_ok
        -- return
    ),

    /*
    Persists the SHOW VERSIONED FILES filter and refreshes discovery without loading scripts.
    */
    function handleShowVersionedChanged enabled =
    (
        this.saveShowVersionedFiles enabled
        this.refreshConfiguredDiscovery()
        -- return
    ),

    /*
    Cycles CLEAN SCRIPTS through OFF, strict, and strict-with-unclear-fallback.
    Native checkbox changed events report Boolean values, so use the stored mode instead.
    */
    function handleShowCleanScriptsChanged ignored_state =
    (
        next_mode = this.getNextCleanScriptsMode (this.getCleanScriptsMode())
        if not(this.saveCleanScriptsMode next_mode) then return false
        if script_manager_show_ui != undefined then script_manager_show_ui.chk_clean_scripts.triState = next_mode
        this.refreshConfiguredDiscovery()
        -- return
    ),

    /*
    Applies COLLAPSE DIRS immediately without rescanning files or executing scripts.
    Previously saved folder expansion and each script's load state are preserved.
    */
    function handleCollapseScriptDirsChanged enabled =
    (
        this.saveCollapseScriptDirs enabled
        this.populateScriptTree restore_expansion:true
        -- return
    ),

    /*
    Filters the already-discovered SCRIPTS rows as the user types.
    This is display-only and never persists, rescans directories, or runs scripts.
    */
    function handleScriptTreeFilterChanged input_text =
    (
        normalized_text = if input_text == undefined then "" else toLower (trimRight (trimLeft input_text))
        if normalized_text == script_filter_text then return true

        script_filter_text = normalized_text
        this.populateScriptTree restore_expansion:true
        -- return
    ),

    /*
    Returns the active SCRIPTS TreeView control when the dynamic loader rollout exists.
    */
    function getScriptTreeControl =
    (
        if script_manager_scripts_ui == undefined then return undefined

        script_manager_scripts_ui.tv_scripts
        -- return
    ),

    /*
    Recursively collects supported script leaf paths from the currently displayed SCRIPTS tree.
    LOAD SCRIPTS uses this visible tree as its authoritative load set instead of relying only on cached discovery arrays.
    */
    function collectScriptTreePaths tree_node script_paths =
    (
        if tree_node == undefined then return script_paths

        node_path = tree_node.ToolTipText

        if this.isSupportedScriptPath node_path then
        (
            if (findItem script_paths node_path) == 0 then append script_paths node_path
        )
        else
        (
            child_count = tree_node.Nodes.Count

            if child_count > 0 then
            (
                for child_index = 0 to (child_count - 1) do
                (
                    this.collectScriptTreePaths tree_node.Nodes.Item[child_index] script_paths
                )
            )
        )

        script_paths
        -- return
    ),

    /*
    Resolves the clicked folder's host-dialog path and its visible descendant script leaves.
    Script leaves cannot act as groups, and hidden/ignored scripts are never collected.
    */
    function getScriptTreeGroupLoadData tree_node =
    (
        if tree_node == undefined then return #("", #())

        directory_path = tree_node.ToolTipText
        if directory_path == undefined or directory_path == "" then return #("", #())
        if this.isSupportedScriptPath directory_path then return #("", #())

        host_path = this.getRelativeDirectoryPath directory_path
        if host_path == "" then
        (
            normalized_directory = ScriptManagerIntegration.normalizeDirectoryPath directory_path
            normalized_root = ScriptManagerIntegration.normalizeDirectoryPath root_directory
            if normalized_directory != normalized_root then return #("", #())
            host_path = "__ROOT__"
        )

        script_paths = #()
        this.collectScriptTreePaths tree_node script_paths
        #(host_path, script_paths)
        -- return
    ),

    /*
    Returns every supported script leaf currently shown in SCRIPTS.
    */
    function getDisplayedScriptPaths =
    (
        tree_control = this.getScriptTreeControl()
        if tree_control == undefined then return #()

        script_paths = #()
        root_count = tree_control.Nodes.Count

        if root_count > 0 then
        (
            for root_index = 0 to (root_count - 1) do
            (
                this.collectScriptTreePaths tree_control.Nodes.Item[root_index] script_paths
            )
        )

        script_paths
        -- return
    ),

    /*
    Returns whether one exact script path is currently part of the embedded manager load set.
    Comparison is case-insensitive because Windows paths are case-insensitive.
    */
    function isScriptTreePathLoaded script_path =
    (
        if script_path == undefined or script_path == "" then return false

        normalized_script_path = toLower script_path
        path_loaded = false

        for loaded_path in loaded_script_paths while not path_loaded do
        (
            if (toLower loaded_path) == normalized_script_path then path_loaded = true
        )

        path_loaded
        -- return
    ),

    /*
    Returns the explicit checked SOURCES path that overrides the default batch dialog for one script.
    The first checked ancestor is discovery-only; the second checked ancestor is the batch-dialog marker.
    */
    function getBatchOverridePathForScript script_path =
    (
        if not(this.isSupportedScriptPath script_path) then return ""

        script_directory = ScriptManagerIntegration.normalizeDirectoryPath (getFilenamePath script_path)
        matching_checked_count = 0
        override_host_path = ""

        for source_index = 1 to available_source_directories.count while override_host_path == "" do
        (
            source_directory = available_source_directories[source_index]
            source_selectable = false
            if source_index <= available_source_selectable.count then source_selectable = available_source_selectable[source_index]

            if source_selectable and this.getSourceEnabled source_directory then
            (
                normalized_source = ScriptManagerIntegration.normalizeDirectoryPath source_directory
                source_contains_script = script_directory == normalized_source or this.isDirectoryBelowDirectory script_directory normalized_source

                if source_contains_script then
                (
                    matching_checked_count += 1

                    if matching_checked_count == 2 then
                    (
                        source_relative_path = this.getRelativeDirectoryPath normalized_source
                        if source_relative_path != "" then override_host_path = source_relative_path
                    )
                )
            )
        )

        override_host_path
        -- return
    ),

    /*
    Resolves the batch-dialog path for one script.
    An explicit second checked SOURCES ancestor overrides the normal parent-folder dialog.
    */
    function getBatchDialogPathForScript script_path =
    (
        if not(this.isSupportedScriptPath script_path) then return ""

        script_directory = ScriptManagerIntegration.normalizeDirectoryPath (getFilenamePath script_path)
        group_path = this.getRelativeDirectoryPath script_directory
        default_host_path = this.getHostDialogPathForGroup group_path
        override_host_path = this.getBatchOverridePathForScript script_path

        if override_host_path != "" then override_host_path else default_host_path
        -- return
    ),

    /*
    Builds the batch-dialog palette and script-to-host map once per SCRIPTS state synchronization.
    Resolving the full palette per HOST node used to repeat every script/source INI lookup.
    */
    function buildScriptTreeBatchColorCache =
    (
        batch_paths = #()
        host_lookup = Dictionary #string

        for available_script_path in available_script_paths do
        (
            batch_path = this.getBatchDialogPathForScript available_script_path
            if batch_path != "" then
            (
                PutDictValue host_lookup (toLower available_script_path) batch_path
                if (findItem batch_paths batch_path) == 0 then append batch_paths batch_path
            )
        )

        sort batch_paths
        #(batch_paths, host_lookup)
        -- return
    ),

    /*
    Returns a stable palette index for one visible batch-dialog path.
    The render-only palette avoids repeated all-script/source scans; calls outside rendering retain the original resolution.
    */
    function getBatchDialogColorIndex host_path =
    (
        if host_path == undefined or host_path == "" then return 1

        batch_paths = script_tree_batch_palette
        if batch_paths == undefined then
        (
            batch_paths = #()

            for available_script_path in available_script_paths do
            (
                batch_path = this.getBatchDialogPathForScript available_script_path
                if batch_path != "" and (findItem batch_paths batch_path) == 0 then append batch_paths batch_path
            )

            sort batch_paths
        )
        batch_index = findItem batch_paths host_path
        if batch_index == 0 then batch_index = 1

        batch_index
        -- return
    ),

    /*
    Returns the display color for one batch-dialog path.
    The restrained palette repeats when more batch dialogs exist than palette entries.
    */
    function getBatchDialogColor host_path =
    (
        color_type = dotNetClass "System.Drawing.Color"
        color_values = #(
            #(62, 158, 255),
            #(110, 190, 130),
            #(180, 130, 230),
            #(80, 190, 200),
            #(220, 130, 160),
            #(200, 180, 90)
        )
        batch_index = this.getBatchDialogColorIndex host_path
        color_index = mod (batch_index - 1) color_values.count + 1
        rgb_value = color_values[color_index]

        color_type.FromArgb rgb_value[1] rgb_value[2] rgb_value[3]
        -- return
    ),

    /*
    Resets a SCRIPTS item to the standard tree foreground regardless of its checked state.
    The tri-state checkbox is the only load-mode indicator; folder bold fonts are unchanged.
    Kept as a compatibility helper for callers of applyScriptTreeNodeColor.
    */
    function applyScriptTreeNodeColor tree_node =
    (
        if tree_node == undefined then return false

        color_type = dotNetClass "System.Drawing.Color"
        tree_node.ForeColor = color_type.FromArgb 225 225 225
        true
        -- return
    ),

    /*
    Recursively synchronizes one SCRIPTS node and returns whether it or any descendant script is active.
    Script leaves use 0=#skip, 1=#host, 2=#direct. Every folder ancestor shows a checkmark when any descendant is active so collapsed branches expose configured content.
    */
    function syncScriptTreeNodeChecks tree_node =
    (
        if tree_node == undefined then return false

        node_path = tree_node.ToolTipText
        is_script_node = this.isSupportedScriptPath node_path
        node_active = false

        if is_script_node then
        (
            script_key = this.getScriptKey node_path
            load_mode = this.getScriptLoadMode script_key
            this.setScriptTreeNodeVisualState tree_node (this.getScriptLoadModeStateIndex load_mode)
            node_active = load_mode != #skip
        )
        else
        (
            active_count = 0
            child_count = tree_node.Nodes.Count

            if child_count > 0 then
            (
                for child_index = 0 to (child_count - 1) do
                (
                    child_node = tree_node.Nodes.Item[child_index]
                    if this.syncScriptTreeNodeChecks child_node then active_count += 1
                )
            )

            if active_count > 0 then
            (
                this.setScriptTreeNodeVisualState tree_node 1
            )
            else
            (
                this.setScriptTreeNodeVisualState tree_node 0
            )

            node_active = active_count > 0
        )

        this.applyScriptTreeNodeColor tree_node
        node_active
        -- return
    ),

    /*
    Synchronizes every SCRIPTS state image from the persisted load modes.
    The guard prevents UI-state callbacks from changing persistence during a rebuild.
    */
    function syncScriptTreeChecks =
    (
        tree_control = this.getScriptTreeControl()
        if tree_control == undefined then return false

        script_tree_syncing_checks = true
        sync_ok = true
        script_tree_batch_palette = undefined
        script_tree_batch_hosts = undefined

        try
        (
            /* Checked-state formatting is disabled; no HOST palette/INI lookup is needed. */
            for root_index = 0 to (tree_control.Nodes.Count - 1) do
            (
                this.syncScriptTreeNodeChecks tree_control.Nodes.Item[root_index]
            )
        )
        catch
        (
            sync_ok = false
            format "[Script-Manager] Script tree state sync failed: %\n" (getCurrentException())
        )

        script_tree_batch_palette = undefined
        script_tree_batch_hosts = undefined
        script_tree_syncing_checks = false
        sync_ok
        -- return
    ),

    /*
    Returns configured HOST-mode scripts assigned to one resolved batch dialog.
    DIRECT and skipped scripts are intentionally excluded.
    */
    function getConfiguredHostScriptPaths host_path =
    (
        script_paths = #()
        if host_path == undefined or host_path == "" then return script_paths

        for script_path in available_script_paths do
        (
            script_key = this.getScriptKey script_path
            load_mode = this.getScriptLoadMode script_key

            if load_mode == #host and (this.getBatchDialogPathForScript script_path) == host_path then
            (
                if (findItem script_paths script_path) == 0 then append script_paths script_path
            )
        )

        script_paths
        -- return
    ),

    /*
    Returns whether one checked SOURCES directory is the explicit batch-dialog marker for at least one configured HOST script.
    The first checked discovery source is never treated as a dialog marker.
    */
    function isSourceDirectoryBatchDialog source_directory =
    (
        if source_directory == undefined or source_directory == "" then return false
        if not(this.getSourceEnabled source_directory) then return false

        normalized_source = ScriptManagerIntegration.normalizeDirectoryPath source_directory
        source_relative_path = this.getRelativeDirectoryPath normalized_source
        if source_relative_path == "" then return false

        for script_path in available_script_paths do
        (
            script_key = this.getScriptKey script_path
            load_mode = this.getScriptLoadMode script_key

            if load_mode == #host and (this.getBatchOverridePathForScript script_path) == source_relative_path then return true
        )

        false
        -- return
    ),

    /*
    Returns the batch-dialog path represented by the currently selected checked SOURCES item.
    Non-dialog source rows return an empty string.
    */
    function getSelectedSourceDialogPath =
    (
        tree_control = this.getSourceTreeControl()
        if tree_control == undefined or tree_control.SelectedNode == undefined then return ""

        selected_node = tree_control.SelectedNode
        if not(this.isSourceTreeNodeSelectable selected_node) then return ""

        source_directory = selected_node.Tag
        if not(this.isSourceDirectoryBatchDialog source_directory) then return ""

        this.getRelativeDirectoryPath (ScriptManagerIntegration.normalizeDirectoryPath source_directory)
        -- return
    ),

    /*
    Updates whether LOAD \ RELOAD DIALOG is available for the selected SOURCES item.
    The command is shown only on an explicit checked batch-dialog marker.
    */
    function updateSourceTreeContextMenuState =
    (
        if source_tree_load_dialog_item == undefined then return false

        dialog_path = this.getSelectedSourceDialogPath()
        show_dialog_action = dialog_path != ""
        source_tree_load_dialog_item.Visible = show_dialog_action
        source_tree_load_dialog_item.Enabled = show_dialog_action
        if source_tree_open_separator != undefined then source_tree_open_separator.Visible = show_dialog_action
        true
        -- return
    ),

    /*
    Removes .NET handlers and disposes the SOURCES context menu before the loader rollout is rebuilt.
    Cleanup failures are intentionally harmless because the old UI is being destroyed.
    */
    function clearSourceTreeContextMenu =
    (
        cleanup_ok = true

        if source_tree_load_dialog_item != undefined then
        (
            try
            (
                dotNet.removeEventHandler source_tree_load_dialog_item "Click" scriptManagerSourceTreeLoadDialogContextHandler
            )
            catch
            (
                exception_text = getCurrentException()
                cleanup_ok = false
                format "[Script-Manager] Source tree LOAD \\ RELOAD DIALOG handler cleanup failed: %\n" exception_text
            )
        )

        if source_tree_expand_all_item != undefined then
        (
            try
            (
                dotNet.removeEventHandler source_tree_expand_all_item "Click" scriptManagerSourceTreeExpandAllContextHandler
            )
            catch
            (
                exception_text = getCurrentException()
                cleanup_ok = false
                format "[Script-Manager] Source tree EXPAND ALL handler cleanup failed: %\n" exception_text
            )
        )

        if source_tree_collapse_all_item != undefined then
        (
            try
            (
                dotNet.removeEventHandler source_tree_collapse_all_item "Click" scriptManagerSourceTreeCollapseAllContextHandler
            )
            catch
            (
                exception_text = getCurrentException()
                cleanup_ok = false
                format "[Script-Manager] Source tree COLLAPSE ALL handler cleanup failed: %\n" exception_text
            )
        )

        if source_tree_context_menu != undefined then
        (
            try
            (
                source_tree_context_menu.Dispose()
            )
            catch
            (
                exception_text = getCurrentException()
                cleanup_ok = false
                format "[Script-Manager] Source tree context-menu cleanup failed: %\n" exception_text
            )
        )

        source_tree_context_menu = undefined
        source_tree_open_separator = undefined
        source_tree_expand_separator = undefined
        source_tree_load_dialog_item = undefined
        source_tree_expand_all_item = undefined
        source_tree_collapse_all_item = undefined
        cleanup_ok
        -- return
    ),

    /*
    Builds the SOURCES right-click menu with complete-tree expand and collapse commands.
    */
    function buildSourceTreeContextMenu =
    (
        tree_control = this.getSourceTreeControl()
        if tree_control == undefined then return false

        this.clearSourceTreeContextMenu()

        color_type = dotNetClass "System.Drawing.Color"
        source_tree_context_menu = dotNetObject "System.Windows.Forms.ContextMenuStrip"
        source_tree_context_menu.ShowImageMargin = false
        source_tree_context_menu.BackColor = color_type.FromArgb 45 45 48
        source_tree_context_menu.ForeColor = color_type.FromArgb 225 225 225

        source_tree_load_dialog_item = source_tree_context_menu.Items.Add "LOAD \\ RELOAD DIALOG"
        source_tree_open_separator = dotNetObject "System.Windows.Forms.ToolStripSeparator"
        source_tree_context_menu.Items.Add source_tree_open_separator
        source_tree_collapse_all_item = source_tree_context_menu.Items.Add "COLLAPSE ALL"
        source_tree_expand_separator = dotNetObject "System.Windows.Forms.ToolStripSeparator"
        source_tree_context_menu.Items.Add source_tree_expand_separator
        source_tree_expand_all_item = source_tree_context_menu.Items.Add "EXPAND ALL"
        source_tree_load_dialog_item.BackColor = source_tree_context_menu.BackColor
        source_tree_load_dialog_item.ForeColor = source_tree_context_menu.ForeColor
        source_tree_load_dialog_item.ToolTipText = "Load or hard reload only the HOST scripts assigned to this batch dialog."
        source_tree_load_dialog_item.Visible = false
        source_tree_expand_all_item.BackColor = source_tree_context_menu.BackColor
        source_tree_expand_all_item.ForeColor = source_tree_context_menu.ForeColor
        source_tree_collapse_all_item.BackColor = source_tree_context_menu.BackColor
        source_tree_collapse_all_item.ForeColor = source_tree_context_menu.ForeColor

        dotNet.addEventHandler source_tree_load_dialog_item "Click" scriptManagerSourceTreeLoadDialogContextHandler
        dotNet.addEventHandler source_tree_expand_all_item "Click" scriptManagerSourceTreeExpandAllContextHandler
        dotNet.addEventHandler source_tree_collapse_all_item "Click" scriptManagerSourceTreeCollapseAllContextHandler
        true
        -- return
    ),

    /*
    Handles a SOURCES TreeView mouse click and opens its right-click menu.
    */
    function handleSourceTreeNodeClick click_args =
    (
        if click_args == undefined or click_args.Node == undefined then return false

        tree_control = this.getSourceTreeControl()
        if tree_control == undefined then return false

        mouse_buttons = dotNetClass "System.Windows.Forms.MouseButtons"

        if click_args.Button == mouse_buttons.Right then
        (
            tree_control.SelectedNode = click_args.Node
            if source_tree_context_menu != undefined then
            (
                this.updateSourceTreeContextMenuState()
                source_tree_context_menu.Show tree_control click_args.Location
            )
            return true
        )

        if click_args.Button != mouse_buttons.Left then return false

        tree_control.SelectedNode = click_args.Node
        if not(this.isSourceTreeNodeSelectable click_args.Node) then return true

        hit_info = tree_control.HitTest click_args.Location
        if hit_info == undefined then return true

        hit_location_text = hit_info.Location.ToString()
        if (findString hit_location_text "Image") == undefined then return true

        source_directory = click_args.Node.Tag
        if source_directory == undefined or source_directory == "" then return false

        enabled = not(this.getSourceEnabled source_directory)
        if not(this.saveSourceEnabled source_directory enabled) then return false
        if not(this.setSourceTreeNodeVisualState click_args.Node enabled) then return false

        this.refreshConfiguredDiscovery()
        -- return
    ),

    /*
    Expands the complete SOURCES tree and persists the resulting UI state.
    */
    function expandAllSourceTree =
    (
        tree_control = this.getSourceTreeControl()
        if tree_control == undefined then return false

        tree_expansion_syncing = true
        tree_control.ExpandAll()
        tree_expansion_syncing = false
        this.saveTreeExpansionStates tree_control "SourceTreeOpen"
        true
        -- return
    ),

    /*
    Collapses the complete SOURCES tree and persists the resulting UI state.
    */
    function collapseAllSourceTree =
    (
        tree_control = this.getSourceTreeControl()
        if tree_control == undefined then return false

        tree_expansion_syncing = true
        tree_control.CollapseAll()
        tree_expansion_syncing = false
        this.saveTreeExpansionStates tree_control "SourceTreeOpen"
        true
        -- return
    ),

    /*
    Persists one SOURCES folder expand/collapse event.
    */
    function handleSourceTreeExpandedState event_args =
    (
        if event_args == undefined or event_args.Node == undefined then return false
        if tree_expansion_syncing then return true

        this.saveTreeNodeOpenState event_args.Node "SourceTreeOpen"
        -- return
    ),

    /*
    Removes .NET handlers and disposes the SCRIPTS context menu before the loader rollout is rebuilt.
    Cleanup failures are intentionally harmless because the old UI is being destroyed.
    */
    function clearScriptTreeContextMenu =
    (
        cleanup_ok = true

        if script_tree_open_group_item != undefined then
        (
            try
            (
                dotNet.removeEventHandler script_tree_open_group_item "Click" scriptManagerTreeOpenGroupContextHandler
            )
            catch
            (
                exception_text = getCurrentException()
                cleanup_ok = false
                format "[Script-Manager] Tree OPEN GROUP handler cleanup failed: %\n" exception_text
            )
        )

        if script_tree_load_item != undefined then
        (
            try
            (
                dotNet.removeEventHandler script_tree_load_item "Click" scriptManagerTreeLoadContextHandler
            )
            catch
            (
                exception_text = getCurrentException()
                cleanup_ok = false
                format "[Script-Manager] Tree LOAD SCRIPT handler cleanup failed: %\n" exception_text
            )
        )

        if script_tree_startup_item != undefined then
        (
            try
            (
                dotNet.removeEventHandler script_tree_startup_item "Click" scriptManagerTreeStartupContextHandler
            )
            catch
            (
                cleanup_ok = false
                format "[Script-Manager] Tree STARTUP handler cleanup failed: %\n" (getCurrentException())
            )
        )

        if script_tree_open_explorer_item != undefined then
        (
            try
            (
                dotNet.removeEventHandler script_tree_open_explorer_item "Click" scriptManagerTreeOpenExplorerContextHandler
            )
            catch
            (
                exception_text = getCurrentException()
                cleanup_ok = false
                format "[Script-Manager] Tree OPEN IN EXPLORER handler cleanup failed: %\n" exception_text
            )
        )

        if script_tree_expand_item != undefined then
        (
            try
            (
                dotNet.removeEventHandler script_tree_expand_item "Click" scriptManagerTreeExpandContextHandler
            )
            catch
            (
                exception_text = getCurrentException()
                cleanup_ok = false
                format "[Script-Manager] Tree EXPAND handler cleanup failed: %\n" exception_text
            )
        )

        if script_tree_collapse_item != undefined then
        (
            try
            (
                dotNet.removeEventHandler script_tree_collapse_item "Click" scriptManagerTreeCollapseContextHandler
            )
            catch
            (
                exception_text = getCurrentException()
                cleanup_ok = false
                format "[Script-Manager] Tree COLLAPSE handler cleanup failed: %\n" exception_text
            )
        )

        if script_tree_expand_all_item != undefined then
        (
            try
            (
                dotNet.removeEventHandler script_tree_expand_all_item "Click" scriptManagerTreeExpandAllContextHandler
            )
            catch
            (
                exception_text = getCurrentException()
                cleanup_ok = false
                format "[Script-Manager] Tree EXPAND ALL handler cleanup failed: %\n" exception_text
            )
        )

        if script_tree_expand_enabled_item != undefined then
        (
            try
            (
                dotNet.removeEventHandler script_tree_expand_enabled_item "Click" scriptManagerTreeExpandEnabledContextHandler
            )
            catch
            (
                exception_text = getCurrentException()
                cleanup_ok = false
                format "[Script-Manager] Tree EXPAND ENABLED handler cleanup failed: %\n" exception_text
            )
        )

        if script_tree_collapse_all_item != undefined then
        (
            try
            (
                dotNet.removeEventHandler script_tree_collapse_all_item "Click" scriptManagerTreeCollapseAllContextHandler
            )
            catch
            (
                exception_text = getCurrentException()
                cleanup_ok = false
                format "[Script-Manager] Tree COLLAPSE ALL handler cleanup failed: %\n" exception_text
            )
        )

        if script_tree_context_menu != undefined then
        (
            try
            (
                script_tree_context_menu.Dispose()
            )
            catch
            (
                exception_text = getCurrentException()
                cleanup_ok = false
                format "[Script-Manager] Tree context-menu cleanup failed: %\n" exception_text
            )
        )

        script_tree_context_menu = undefined
        script_tree_open_separator = undefined
        script_tree_expand_separator = undefined
        script_tree_open_group_item = undefined
        script_tree_load_item = undefined
        script_tree_startup_item = undefined
        script_tree_open_explorer_item = undefined
        script_tree_expand_item = undefined
        script_tree_collapse_item = undefined
        script_tree_expand_all_item = undefined
        script_tree_expand_enabled_item = undefined
        script_tree_collapse_all_item = undefined
        cleanup_ok
        -- return
    ),

    /*
    Builds the SCRIPTS right-click menu with branch and complete-tree expand/collapse commands.
    */
    function buildScriptTreeContextMenu =
    (
        tree_control = this.getScriptTreeControl()
        if tree_control == undefined then return false

        this.clearScriptTreeContextMenu()

        color_type = dotNetClass "System.Drawing.Color"
        script_tree_context_menu = dotNetObject "System.Windows.Forms.ContextMenuStrip"
        script_tree_context_menu.ShowImageMargin = false
        script_tree_context_menu.BackColor = color_type.FromArgb 45 45 48
        script_tree_context_menu.ForeColor = color_type.FromArgb 225 225 225

        script_tree_open_group_item = script_tree_context_menu.Items.Add "OPEN GROUP"
        script_tree_load_item = script_tree_context_menu.Items.Add "LOAD SCRIPT"
        script_tree_startup_item = script_tree_context_menu.Items.Add "ADD TO STARTUP SCRIPTS"
        script_tree_open_explorer_item = script_tree_context_menu.Items.Add "OPEN IN EXPLORER"
        script_tree_open_separator = dotNetObject "System.Windows.Forms.ToolStripSeparator"
        script_tree_context_menu.Items.Add script_tree_open_separator
        script_tree_collapse_item = script_tree_context_menu.Items.Add "COLLAPSE"
        script_tree_collapse_all_item = script_tree_context_menu.Items.Add "COLLAPSE ALL"
        script_tree_expand_separator = dotNetObject "System.Windows.Forms.ToolStripSeparator"
        script_tree_context_menu.Items.Add script_tree_expand_separator
        script_tree_expand_item = script_tree_context_menu.Items.Add "EXPAND"
        script_tree_expand_all_item = script_tree_context_menu.Items.Add "EXPAND ALL"
        script_tree_expand_enabled_item = script_tree_context_menu.Items.Add "EXPAND ENABLED"

        for menu_item in #(script_tree_open_group_item, script_tree_load_item, script_tree_startup_item, script_tree_open_explorer_item, script_tree_expand_item, script_tree_collapse_item, script_tree_expand_all_item, script_tree_expand_enabled_item, script_tree_collapse_all_item) do
        (
            menu_item.BackColor = script_tree_context_menu.BackColor
            menu_item.ForeColor = script_tree_context_menu.ForeColor
        )

        script_tree_open_group_item.ToolTipText = "Open every script in this folder and its descendants in one shared rollout dialog."
        script_tree_expand_enabled_item.ToolTipText = "Expand only folders containing HOST or DIRECT scripts; collapse other branches."

        dotNet.addEventHandler script_tree_open_group_item "Click" scriptManagerTreeOpenGroupContextHandler
        dotNet.addEventHandler script_tree_load_item "Click" scriptManagerTreeLoadContextHandler
        dotNet.addEventHandler script_tree_startup_item "Click" scriptManagerTreeStartupContextHandler
        dotNet.addEventHandler script_tree_open_explorer_item "Click" scriptManagerTreeOpenExplorerContextHandler
        dotNet.addEventHandler script_tree_expand_item "Click" scriptManagerTreeExpandContextHandler
        dotNet.addEventHandler script_tree_collapse_item "Click" scriptManagerTreeCollapseContextHandler
        dotNet.addEventHandler script_tree_expand_all_item "Click" scriptManagerTreeExpandAllContextHandler
        dotNet.addEventHandler script_tree_expand_enabled_item "Click" scriptManagerTreeExpandEnabledContextHandler
        dotNet.addEventHandler script_tree_collapse_all_item "Click" scriptManagerTreeCollapseAllContextHandler
        true
        -- return
    ),

    /*
    Enables or disables the selected-branch context commands from the current SCRIPTS selection.
    Complete-tree commands remain available whenever the tree exists.
    */
    function updateScriptTreeContextMenuState =
    (
        tree_control = this.getScriptTreeControl()
        if tree_control == undefined then return false
        if script_tree_open_group_item == undefined or script_tree_load_item == undefined or script_tree_startup_item == undefined or script_tree_open_explorer_item == undefined or script_tree_expand_item == undefined or script_tree_collapse_item == undefined or script_tree_expand_enabled_item == undefined then return false

        selected_node = tree_control.SelectedNode
        selected_is_script = selected_node != undefined and this.isSupportedScriptPath selected_node.ToolTipText
        has_selection = selected_node != undefined
        has_children = selected_node != undefined and selected_node.Nodes.Count > 0

        script_tree_open_group_item.Visible = has_selection and not selected_is_script
        script_tree_open_group_item.Enabled = has_children

        script_tree_load_item.Visible = selected_is_script
        script_tree_load_item.Enabled = selected_is_script
        script_tree_startup_item.Visible = selected_is_script
        script_tree_startup_item.Enabled = selected_is_script
        if selected_is_script then
        (
            script_tree_startup_item.Text = if this.isScriptInStartup selected_node.ToolTipText then "REMOVE FROM STARTUP SCRIPTS" else "ADD TO STARTUP SCRIPTS"
        )

        script_tree_open_explorer_item.Visible = has_selection
        script_tree_open_explorer_item.Enabled = has_selection

        script_tree_expand_item.Visible = not selected_is_script
        script_tree_collapse_item.Visible = not selected_is_script
        script_tree_expand_all_item.Visible = not selected_is_script
        script_tree_collapse_all_item.Visible = not selected_is_script

        script_tree_expand_item.Enabled = has_children
        script_tree_collapse_item.Enabled = has_children
        script_tree_expand_all_item.Enabled = not selected_is_script
        script_tree_expand_enabled_item.Visible = true
        script_tree_expand_enabled_item.Enabled = tree_control.Nodes.Count > 0
        script_tree_collapse_all_item.Enabled = not selected_is_script
        if script_tree_open_separator != undefined then script_tree_open_separator.Visible = has_selection
        if script_tree_expand_separator != undefined then script_tree_expand_separator.Visible = not selected_is_script
        true
        -- return
    ),

    /*
    Expands the selected SCRIPTS branch and all descendants, then persists tree UI state.
    */
    function expandSelectedScriptTreeNode =
    (
        tree_control = this.getScriptTreeControl()
        if tree_control == undefined or tree_control.SelectedNode == undefined then return false
        if tree_control.SelectedNode.Nodes.Count == 0 then return false

        tree_expansion_syncing = true
        tree_control.SelectedNode.ExpandAll()
        tree_expansion_syncing = false
        this.saveTreeExpansionStates tree_control "ScriptTreeOpen"
        true
        -- return
    ),

    /*
    Collapses the selected SCRIPTS branch, then persists tree UI state.
    */
    function collapseSelectedScriptTreeNode =
    (
        tree_control = this.getScriptTreeControl()
        if tree_control == undefined or tree_control.SelectedNode == undefined then return false
        if tree_control.SelectedNode.Nodes.Count == 0 then return false

        tree_expansion_syncing = true
        tree_control.SelectedNode.Collapse()
        tree_expansion_syncing = false
        this.saveTreeExpansionStates tree_control "ScriptTreeOpen"
        true
        -- return
    ),

    /*
    Expands the complete SCRIPTS tree and persists the resulting UI state.
    */
    function expandAllScriptTree =
    (
        tree_control = this.getScriptTreeControl()
        if tree_control == undefined then return false

        tree_expansion_syncing = true
        tree_control.ExpandAll()
        tree_expansion_syncing = false
        this.saveTreeExpansionStates tree_control "ScriptTreeOpen"
        true
        -- return
    ),

    /*
Expands a folder branch only when its already-synchronized tri-state image marks active descendants.
The SCRIPTS TreeView stores folder state 1 if it contains HOST or DIRECT scripts.
    */
    function expandEnabledScriptTreeBranch tree_node =
    (
        if tree_node == undefined then return false
        if tree_node.Nodes.Count == 0 then return false
        if tree_node.StateImageIndex != 1 then return false

        tree_node.Expand()

        for child_index = 0 to (tree_node.Nodes.Count - 1) do
        (
            this.expandEnabledScriptTreeBranch tree_node.Nodes.Item[child_index]
        )

        true
        -- return
    ),

    /*
Collapses SCRIPTS, expands only configured HOST/DIRECT branches, and saves the new view state.
This reads existing node-state images without rescanning files or repeatedly reading script INI modes.
    */
    function expandEnabledScriptTree =
    (
        tree_control = this.getScriptTreeControl()
        if tree_control == undefined then return false

        tree_expansion_syncing = true
        expand_ok = true

        try
        (
            tree_control.BeginUpdate()
            tree_control.CollapseAll()

            for root_index = 0 to (tree_control.Nodes.Count - 1) do
            (
                this.expandEnabledScriptTreeBranch tree_control.Nodes.Item[root_index]
            )

            tree_control.EndUpdate()
        )
        catch
        (
            exception_text = getCurrentException()
            expand_ok = false
            format "[Script-Manager] EXPAND ENABLED failed: %\n" exception_text

            try
            (
                tree_control.EndUpdate()
            )
            catch
            (
                cleanup_exception_text = getCurrentException()
                format "[Script-Manager] EXPAND ENABLED UI cleanup failed: %\n" cleanup_exception_text
            )
        )

        tree_expansion_syncing = false
        if expand_ok then expand_ok = this.saveTreeExpansionStates tree_control "ScriptTreeOpen"
        expand_ok
        -- return
    ),

    /*
    Collapses the complete SCRIPTS tree and persists the resulting UI state.
    */
    function collapseAllScriptTree =
    (
        tree_control = this.getScriptTreeControl()
        if tree_control == undefined then return false

        tree_expansion_syncing = true
        tree_control.CollapseAll()
        tree_expansion_syncing = false
        this.saveTreeExpansionStates tree_control "ScriptTreeOpen"
        true
        -- return
    ),

    /*
    Persists one SCRIPTS folder expand/collapse event.
    */
    function handleScriptTreeExpandedState event_args =
    (
        if event_args == undefined or event_args.Node == undefined then return false
        if tree_expansion_syncing then return true
        if script_filter_text != "" then return true
        if this.isSupportedScriptPath event_args.Node.ToolTipText then return true

        this.saveTreeNodeOpenState event_args.Node "ScriptTreeOpen"
        -- return
    ),

    /*
    Builds three explicit dark-UI-safe checkbox glyphs for the SCRIPTS TreeView.
    Index 0 is unchecked, index 1 is checked/hosted, and index 2 is indeterminate/direct-run.
    The glyphs are drawn manually instead of relying on the Windows theme renderer because
    themed checkbox state images can disappear inside 3ds Max dark UI.
    */
    function buildScriptTreeStateImages =
    (
        image_list = dotNetObject "System.Windows.Forms.ImageList"
        image_list.ImageSize = dotNetObject "System.Drawing.Size" 16 16

        color_depth_type = dotNetClass "System.Windows.Forms.ColorDepth"
        image_list.ColorDepth = color_depth_type.Depth32Bit

        color_type = dotNetClass "System.Drawing.Color"
        graphics_type = dotNetClass "System.Drawing.Graphics"

        transparent_color = color_type.Transparent
        border_color = color_type.FromArgb 205 205 205
        active_color = color_type.FromArgb 62 158 255

        for state_index = 0 to 2 do
        (
            bitmap_value = dotNetObject "System.Drawing.Bitmap" 16 16
            graphics_value = graphics_type.FromImage bitmap_value
            graphics_value.Clear transparent_color

            border_pen_value = dotNetObject "System.Drawing.Pen" border_color 1.0
            graphics_value.DrawRectangle border_pen_value 2 2 11 11
            border_pen_value.Dispose()

            if state_index == 1 then
            (
                active_pen_value = dotNetObject "System.Drawing.Pen" active_color 2.0
                graphics_value.DrawLine active_pen_value 4 8 7 11
                graphics_value.DrawLine active_pen_value 7 11 12 5
                active_pen_value.Dispose()
            )
            else if state_index == 2 then
            (
                active_pen_value = dotNetObject "System.Drawing.Pen" active_color 2.0
                graphics_value.DrawLine active_pen_value 4 8 11 8
                active_pen_value.Dispose()
            )

            graphics_value.Dispose()
            image_list.Images.Add bitmap_value
        )

        script_tree_state_images = image_list
        true
        -- return
    ),

    /*
    Applies one visible tri-state glyph index to a SCRIPTS TreeView node.
    StateImageIndex keeps the logical tri-state value while ImageIndex provides the
    always-visible checkbox glyph used by 3ds Max dark UI.
    */
    function setScriptTreeNodeVisualState tree_node state_index =
    (
        if tree_node == undefined then return false

        tree_node.StateImageIndex = state_index
        tree_node.ImageIndex = state_index
        tree_node.SelectedImageIndex = state_index
        true
        -- return
    ),

    /*
    Applies one persisted load mode to a script node without invoking an execution path.
    */
    function applyScriptTreeNodeMode tree_node load_mode =
    (
        if tree_node == undefined then return false

        if not(this.setScriptTreeNodeVisualState tree_node (this.getScriptLoadModeStateIndex load_mode)) then return false
        this.applyScriptTreeNodeColor tree_node
        true
        -- return
    ),

    /*
    Applies the MVP dark TreeView appearance and increases the item font by two rendered pixels.
    The control Tag marks styling as complete so repeated tree population does not grow the font again.
    */
    function styleScriptTree =
    (
        tree_control = this.getScriptTreeControl()
        if tree_control == undefined then return false

        if not(this.styleTreeControl tree_control check_boxes:false) then return false
        if script_tree_state_images == undefined then
        (
            if not(this.buildScriptTreeStateImages()) then return false
        )
        tree_control.ImageList = script_tree_state_images

        if script_tree_folder_font == undefined then
        (
            font_style_type = dotNetClass "System.Drawing.FontStyle"
            script_tree_folder_font = dotNetObject "System.Drawing.Font" tree_control.Font.Name tree_control.Font.Size font_style_type.Bold
        )

        script_tree_font_height = tree_control.Font.Height
        if script_tree_base_font_height <= 0 then script_tree_base_font_height = tree_control.Font.Height
        true
        -- return
    ),

    /*
    Returns the full content height required by the completely expanded SCRIPTS tree.
    The result is based on the actual TreeView row height and is never smaller than the MVP minimum.
    */
    function getScriptTreeRequiredHeight =
    (
        tree_control = this.getScriptTreeControl()
        if tree_control == undefined then return 1032

        tree_node_count = tree_control.GetNodeCount true
        required_height = 12 + (tree_node_count * tree_control.ItemHeight)

        if required_height < 1032 then required_height = 1032

        required_height
        -- return
    ),

    /*
    Opens the category rollout chain containing one clicked script so its embedded rollout is visible.
    Parent categories are expanded from the root down to the target category.
    */
function openGroupHierarchy group_path =
(
    host_path = this.getHostDialogPathForGroup group_path
    if host_path == "" then return true

    host_dialog = this.getHostDialog host_path
    if host_dialog == undefined then return true

    host_open = false

    try
    (
        host_open = host_dialog.inDialog
    )
    catch
    (
        exception_text = getCurrentException()
        format "[Script-Manager] Host dialog-state read failed for %: %\n" host_path exception_text
        return false
    )

    host_open
    -- return
),

    /*
    Returns the tracked live HOST dialog path for one managed script, or an empty string when it is not currently hosted.
    */
    function getLiveHostPathForScript script_path =
    (
        if script_path == undefined or script_path == "" then return ""

        normalized_script_path = toLower script_path
        host_path = ""

        for item_index = 1 to loaded_host_script_paths.count while host_path == "" do
        (
            if (toLower loaded_host_script_paths[item_index]) == normalized_script_path then
            (
                if item_index <= loaded_host_script_dialog_paths.count then
                (
                    candidate_host_path = loaded_host_script_dialog_paths[item_index]
                    host_dialog = this.getHostDialog candidate_host_path

                    if host_dialog != undefined then
                    (
                        host_open = false

                        try
                        (
                            host_open = host_dialog.inDialog
                        )
                        catch
                        (
                            exception_text = getCurrentException()
                            format "[Script-Manager] Hosted script dialog-state read failed for %: %\n" script_path exception_text
                        )

                        if host_open then host_path = candidate_host_path
                    )
                )
            )
        )

        host_path
        -- return
    ),

    /*
    Returns whether one rollout value currently owns its own standalone dialog.
    A failed dialog-state query is reported and treated as not running so UPDATE can recover it.
    */
    function isStandaloneRolloutOpen rollout_value =
    (
        if rollout_value == undefined then return false

        rollout_open = false

        try
        (
            rollout_open = rollout_value.inDialog
        )
        catch
        (
            exception_text = getCurrentException()
            format "[Script-Manager] Standalone rollout-state read failed: %\n" exception_text
            rollout_open = false
        )

        rollout_open
        -- return
    ),

    /*
    Returns whether one configured script is actually running now.
    Standalone dialogs have first priority, manager HOST dialogs have second priority, and scripts without detectable UI are considered running after one successful session load.
    */
    function isManagedScriptRunning script_path =
    (
        if not(this.isSupportedScriptPath script_path) then return false
        if not(doesFileExist script_path) then return false

        source_paths = #(script_path)
        rollout_names = #()
        has_detectable_ui = false

        if (toLower (getFilenameType script_path)) == ".ms" then
        (
            companion_ui_path = getFilenamePath script_path + getFilenameFile script_path + "-UI.ms"
            if doesFileExist companion_ui_path then append source_paths companion_ui_path
        )

        for source_path in source_paths do
        (
            if (toLower (getFilenameType source_path)) != ".mse" then
            (
                source_rollout_names = this.getRolloutNames source_path

                if source_rollout_names != undefined then
                (
                    if source_rollout_names.count > 0 then has_detectable_ui = true

                    for rollout_name in source_rollout_names do
                    (
                        if (findItem rollout_names rollout_name) == 0 then append rollout_names rollout_name
                    )
                )
            )
        )

        for rollout_name in rollout_names do
        (
            rollout_result = this.getRolloutValue rollout_name
            if rollout_result[1] and this.isStandaloneRolloutOpen rollout_result[2] then return true
        )

        registered_pairs = this.getRegisteredRolloutPairsForSources source_paths
        if registered_pairs.count > 0 then has_detectable_ui = true

        for registered_pair in registered_pairs do
        (
            if registered_pair.count >= 1 and this.isStandaloneRolloutOpen registered_pair[1] then return true
        )

        if (this.getLiveHostPathForScript script_path) != "" then return true

        if has_detectable_ui then return false

        this.isScriptTreePathLoaded script_path
        -- return
    ),

    /*
    Loads one selected script without requiring a checkbox mode.
    The action is intentionally soft: already-running scripts are left untouched; unchecked scripts default to standalone preview mode.
    */
    function loadSingleScriptSoft script_path =
    (
        if is_reloading then return false
        if not(this.isSupportedScriptPath script_path) then return false
        if not(doesFileExist script_path) then return false
        if this.isManagerPackageDirectory (getFilenamePath script_path) then return false
        if this.isManagedScriptRunning script_path then return true

        script_name = getFilenameFile script_path
        script_directory = ScriptManagerIntegration.normalizeDirectoryPath (getFilenamePath script_path)
        group_path = this.getRelativeDirectoryPath script_directory
        script_key = this.getScriptKey script_path
        load_mode = this.getScriptLoadMode script_key
        embed_rollouts = load_mode == #host

        if load_mode == #skip then embed_rollouts = false

        is_reloading = true
        load_ok = false

        try
        (
            result_data = this.loadManagedScript \
                script_path \
                script_name:script_name \
                script_key:script_key \
                group_path:group_path \
                embed_rollouts:embed_rollouts

            load_ok = result_data[1]
        )
        catch
        (
            exception_text = getCurrentException()
            format "[Script-Manager] Single-script load failed: % | %\n" script_path exception_text
            load_ok = false
        )

        is_reloading = false
        this.syncScriptTreeChecks()
        load_ok
        -- return
    ),

    /*
    Force-loads one script in standalone/direct mode regardless of its saved load mode or current running state.
    The optional rethrow path restores busy state then propagates the original exception for TreeView debugging.
    */
    function loadSingleScriptForcedDirect script_path rethrow_exception:false =
    (
        last_tree_load_error = ""
        if is_reloading then
        (
            last_tree_load_error = "Manager is currently busy loading scripts."
            format "[Script-Manager][TREE LOAD] ERROR | file:% | reason:manager busy\n" script_path
            return false
        )
        if not(this.isSupportedScriptPath script_path) then
        (
            last_tree_load_error = "Unsupported script file extension."
            format "[Script-Manager][TREE LOAD] ERROR | file:% | reason:unsupported file extension\n" script_path
            return false
        )
        if not(doesFileExist script_path) then
        (
            last_tree_load_error = "Script file does not exist."
            format "[Script-Manager][TREE LOAD] ERROR | file:% | reason:file does not exist\n" script_path
            return false
        )
        if this.isManagerPackageDirectory (getFilenamePath script_path) then
        (
            last_tree_load_error = "Loading files from the manager package is blocked."
            format "[Script-Manager][TREE LOAD] ERROR | file:% | reason:manager package excluded\n" script_path
            return false
        )

        script_name = getFilenameFile script_path
        script_directory = ScriptManagerIntegration.normalizeDirectoryPath (getFilenamePath script_path)
        group_path = this.getRelativeDirectoryPath script_directory
        script_key = this.getScriptKey script_path
        is_reloading = true
        load_ok = false

        try
        (
            result_data = this.loadManagedScript \
                script_path \
                script_name:script_name \
                script_key:script_key \
                group_path:group_path \
                embed_rollouts:false \
                rethrow_exception:rethrow_exception

            load_ok = result_data[1]
            if not load_ok then
            (
                error_detail = if result_data.count >= 3 and result_data[3] != undefined then (result_data[3] as string) else "Loader returned false without error detail."
                last_tree_load_error = error_detail
                format "[Script-Manager][TREE LOAD] ERROR | file:% | detail:%\n" script_path error_detail
            )
        )
        catch
        (
            exception_text = getCurrentException()
            last_tree_load_error = exception_text as string
            format "[Script-Manager][TREE LOAD] EXCEPTION | file:% | detail:%\n" script_path exception_text
            load_ok = false

            if rethrow_exception then
            (
                is_reloading = false
                throw()
            )
        )

        is_reloading = false
        this.syncScriptTreeChecks()
        load_ok
        -- return
    ),

    /*
    Builds Explorer launch settings for the Windows administrator elevation request.
    Both script selection and folder navigation use the same elevated launch configuration.
    */
    function buildElevatedExplorerLaunchInfo target_path select_file:false =
    (
        if target_path == undefined or target_path == "" then return undefined

        launch_info = dotNetObject "System.Diagnostics.ProcessStartInfo"
        launch_info.FileName = "explorer.exe"
        launch_info.UseShellExecute = true
        launch_info.Verb = "runas"

        if select_file then
        (
            launch_info.Arguments = "/select,\"" + target_path + "\""
        )
        else
        (
            launch_info.Arguments = "\"" + target_path + "\""
        )

        launch_info
        -- return
    ),

    /*
    Opens one SCRIPTS tree node in Windows Explorer, requesting administrator elevation.
    Windows can reuse a non-elevated Explorer process, so elevation cannot be guaranteed.
    */
    function openScriptTreeNodeInExplorer tree_node =
    (
        if tree_node == undefined then return false

        target_path = tree_node.ToolTipText
        if target_path == undefined or target_path == "" then return false

        if this.isSupportedScriptPath target_path then
        (
            if not(doesFileExist target_path) then
            (
                format "[Script-Manager] OPEN IN EXPLORER FAILED | file not found: %\n" target_path
                return false
            )

            try
            (
                launch_info = this.buildElevatedExplorerLaunchInfo target_path select_file:true
                (dotNetClass "System.Diagnostics.Process").Start launch_info
                true
            )
            catch
            (
                exception_text = getCurrentException()
                format "[Script-Manager] OPEN IN EXPLORER FAILED | file:% | %\n" target_path exception_text
                false
            )
        )
        else
        (
            normalized_directory = ScriptManagerIntegration.normalizeDirectoryPath target_path
            if normalized_directory == "" then return false
            if normalized_directory.count > 3 and normalized_directory[normalized_directory.count] == "\\" then normalized_directory = substring normalized_directory 1 (normalized_directory.count - 1)

            directory_type = dotNetClass "System.IO.Directory"
            if not(directory_type.Exists normalized_directory) then
            (
                format "[Script-Manager] OPEN IN EXPLORER FAILED | directory not found: %\n" normalized_directory
                return false
            )

            try
            (
                launch_info = this.buildElevatedExplorerLaunchInfo normalized_directory select_file:false
                (dotNetClass "System.Diagnostics.Process").Start launch_info
                true
            )
            catch
            (
                exception_text = getCurrentException()
                format "[Script-Manager] OPEN IN EXPLORER FAILED | directory:% | %\n" normalized_directory exception_text
                false
            )
        )
        -- return
    ),

    /*
    Opens the currently selected SCRIPTS tree row in Windows Explorer.
    */
    function openSelectedScriptTreeItemInExplorer =
    (
        tree_control = this.getScriptTreeControl()
        if tree_control == undefined or tree_control.SelectedNode == undefined then return false

        this.openScriptTreeNodeInExplorer tree_control.SelectedNode
        -- return
    ),

    /*
    Loads a double-clicked MS or MCR script through the existing forced standalone path.
    Unsupported script types and folders are ignored.
    */
    function loadDoubleClickedScriptTreeNode tree_node =
    (
        if tree_node == undefined then return false

        script_path = tree_node.ToolTipText
        if not(this.isSupportedScriptPath script_path) then return false

        extension_text = toLower (getFilenameType script_path)
        if extension_text != ".ms" and extension_text != ".mcr" then return false

        tree_control = this.getScriptTreeControl()
        if tree_control == undefined then return false

        tree_control.SelectedNode = tree_node
        this.loadSelectedScriptTreeItem action_name:"DOUBLE-CLICK"
        -- return
    ),

    /*
    Compatibility wrapper for the shared direct loader used by double-click and RMB actions.
    Folder rows and MSE files are rejected by the loader.
    */
    function loadClickedScriptTreeNode tree_node =
    (
        this.loadDoubleClickedScriptTreeNode tree_node
        -- return
    ),

    /*
    Preserves the former MacroScript-only helper name for external callers.
    MS and MCR rows continue to share the same direct-load behavior.
    */
    function loadDoubleClickedMacroScriptTreeNode tree_node =
    (
        this.loadDoubleClickedScriptTreeNode tree_node
        -- return
    ),

    /*
    Displays a clear failure dialog when a manual TreeView script load fails.
    Listener diagnostics are retained, including any underlying fileIn exception.
    */
    function showTreeLoadFailure action_name script_path reason_text show_dialog:true =
    (
        if not show_dialog then return false
        failure_text = "[TREE LOAD] FAILED\nAction: " + action_name
        if script_path != undefined and script_path != "" then failure_text += "\nFile: " + script_path
        if reason_text != undefined and reason_text != "" then failure_text += "\nError: " + reason_text
        try (messageBox failure_text title:"Script-Manager | TREE LOAD FAILED") catch (format "[Script-Manager][TREE LOAD] Popup failed: %\n" (getCurrentException()))
        true
        -- return
    ),

    /*
    Traces a selected SCRIPTS TreeView load in the Listener, then runs its standalone loader.
    Exceptions show the existing dialog, print the native source/line/stack, and rethrow to the Listener.
    */
    function loadSelectedScriptTreeItem action_name:"RMB LOAD SCRIPT" show_error_dialog:true =
    (
        tree_control = this.getScriptTreeControl()
        if tree_control == undefined then
        (
            format "[Script-Manager][TREE LOAD] FAILED | action:% | reason:SCRIPTS TreeView unavailable\n" action_name
            this.showTreeLoadFailure action_name "" "SCRIPTS TreeView is unavailable." show_dialog:show_error_dialog
            return false
        )
        if tree_control.SelectedNode == undefined then
        (
            format "[Script-Manager][TREE LOAD] FAILED | action:% | reason:no selected script\n" action_name
            this.showTreeLoadFailure action_name "" "No script is selected." show_dialog:show_error_dialog
            return false
        )

        item_name = tree_control.SelectedNode.Text
        script_path = tree_control.SelectedNode.ToolTipText
        path_supported = this.isSupportedScriptPath script_path
        path_exists = if script_path != undefined and script_path != "" then (doesFileExist script_path) else false
        saved_mode = #unknown
        if path_supported then
        (
            script_key = this.getScriptKey script_path
            saved_mode = this.getScriptLoadMode script_key
        )

        format "[Script-Manager][TREE LOAD] START | action:% | item:% | file:% | exists:% | saved_mode:% | run_mode:#standalone\n" \
            action_name item_name script_path path_exists saved_mode

        if not path_supported then
        (
            format "[Script-Manager][TREE LOAD] FAILED | action:% | file:% | reason:unsupported script type\n" action_name script_path
            this.showTreeLoadFailure action_name script_path "Unsupported script type." show_dialog:show_error_dialog
            return false
        )
        if not path_exists then
        (
            format "[Script-Manager][TREE LOAD] FAILED | action:% | file:% | reason:file not found\n" action_name script_path
            this.showTreeLoadFailure action_name script_path "Script file not found." show_dialog:show_error_dialog
            return false
        )

        load_ok = false

        try
        (
            load_ok = this.loadSingleScriptForcedDirect script_path rethrow_exception:true
        )
        catch
        (
            last_tree_load_error = getCurrentException() as string
            format "[Script-Manager][TREE LOAD] FAILED | action:% | item:% | file:% | exception:%\n" \
                action_name item_name script_path last_tree_load_error
            this.showTreeLoadFailure action_name script_path last_tree_load_error show_dialog:show_error_dialog
            throw()
        )

        format "[Script-Manager][TREE LOAD] % | action:% | item:% | file:%\n" \
            (if load_ok then "OK" else "FAILED") action_name item_name script_path
        if not load_ok then
        (
            this.showTreeLoadFailure action_name script_path last_tree_load_error show_dialog:show_error_dialog
            throw ("[TREE LOAD] FAILED | file: " + script_path + " | " + last_tree_load_error)
        )
        load_ok
        -- return
    ),

    /*
    Executes one clicked supported script as the active managed script and embeds declared rollouts when available.
    Existing hosted rollouts are cleared before the selected script runs; scripts without rollouts still execute successfully.
    */
function loadScriptFromTree script_path =
(
    if is_reloading then return false
    if not(this.isSupportedScriptPath script_path) then return false
    if not(doesFileExist script_path) then return false
    if this.isManagerPackageDirectory (getFilenamePath script_path) then return false

    script_name = getFilenameFile script_path
    script_directory = ScriptManagerIntegration.normalizeDirectoryPath (getFilenamePath script_path)
    relative_directory = this.getRelativeDirectoryPath script_directory
    group_path = relative_directory
    script_key = this.getScriptKey script_path
    load_ok = false
    is_reloading = true

    try
    (
        if not(this.clearLoadedRollouts()) then throw "clearLoadedRollouts returned false"

        result_data = this.loadManagedScript script_path script_name:script_name script_key:script_key group_path:group_path
        load_ok = result_data[1]

        if load_ok then this.syncScriptTreeChecks()
    )
    catch
    (
        exception_text = getCurrentException()
        format "[Script-Manager] Tree script load failed: % | %\n" script_path exception_text
        load_ok = false
    )

    is_reloading = false
    load_ok
    -- return
),

    /*
    Executes one checked supported script without clearing already hosted rollouts.
    Scripts already loaded in the current manager session are not executed twice through this path.
    */
function appendScriptFromTree script_path =
(
    if is_reloading then return false
    if not(this.isSupportedScriptPath script_path) then return false
    if not(doesFileExist script_path) then return false
    if this.isManagerPackageDirectory (getFilenamePath script_path) then return false
    if this.isScriptTreePathLoaded script_path then return true

    script_name = getFilenameFile script_path
    script_directory = ScriptManagerIntegration.normalizeDirectoryPath (getFilenamePath script_path)
    relative_directory = this.getRelativeDirectoryPath script_directory
    group_path = relative_directory
    script_key = this.getScriptKey script_path
    load_ok = false
    is_reloading = true

    try
    (
        result_data = this.loadManagedScript script_path script_name:script_name script_key:script_key group_path:group_path
        load_ok = result_data[1]

    )
    catch
    (
        exception_text = getCurrentException()
        format "[Script-Manager] Checked tree script load failed: % | %\n" script_path exception_text
        load_ok = false
    )

    is_reloading = false
    this.syncScriptTreeChecks()
    load_ok
    -- return
),

    /*
    Persists one script-tree node load mode recursively.
    Folder state changes apply the requested mode to every descendant script leaf.
    */
    function setScriptTreeNodeMode tree_node load_mode =
    (
        if tree_node == undefined then return false

        node_path = tree_node.ToolTipText
        if this.isSupportedScriptPath node_path then
        (
            script_key = this.getScriptKey node_path
            if script_key == "" then return false
            if not(this.saveScriptLoadMode script_key load_mode) then return false
        )
        else
        (
            save_ok = true

            child_count = tree_node.Nodes.Count
            if child_count > 0 then
            (
                for child_index = 0 to (child_count - 1) do
                (
                    child_node = tree_node.Nodes.Item[child_index]
                    if not(this.setScriptTreeNodeMode child_node load_mode) then save_ok = false
                )
            )

            return save_ok
        )

        true
        -- return
    ),

    /*
    Persists the legacy Boolean node state as hosted or skipped.
    */
    function setScriptTreeNodeEnabled tree_node enabled =
    (
        this.setScriptTreeNodeMode tree_node (if enabled then #host else #skip)
        -- return
    ),

    /*
    Cycles one SCRIPTS state image without executing the script.
    .ms leaves cycle #skip -> #host -> #direct -> #skip; other script types and folders use #skip/#host.
    */
    function cycleScriptTreeNodeMode tree_node =
    (
        if tree_node == undefined then return false

        node_path = tree_node.ToolTipText
        if this.isSupportedScriptPath node_path then
        (
            script_key = this.getScriptKey node_path
            current_mode = this.getScriptLoadMode script_key
            extension_text = toLower (getFilenameType node_path)

            next_mode = if extension_text == ".ms" then
            (
                case current_mode of
                (
                    #skip: #host
                    #host: #direct
                    default: #skip
                )
            )
            else
            (
                if current_mode == #skip then #host else #skip
            )

            if not(this.saveScriptLoadMode script_key next_mode) then return false
        )
        else
        (
            requested_mode = if tree_node.StateImageIndex == 1 then #skip else #host
            if not(this.setScriptTreeNodeMode tree_node requested_mode) then return false
        )

        this.syncScriptTreeChecks()

        true
        -- return
    ),

    /*
    Retains compatibility with native AfterCheck callbacks if an external caller enables TreeView checkboxes.
    */
    function handleScriptTreeAfterCheck check_args =
    (
        if check_args == undefined or check_args.Node == undefined then return false
        if script_tree_syncing_checks then return true

        tree_action_type = dotNetClass "System.Windows.Forms.TreeViewAction"
        if check_args.Action == tree_action_type.Unknown then return true

        save_ok = this.setScriptTreeNodeEnabled check_args.Node check_args.Node.Checked
        if save_ok then this.syncScriptTreeChecks()
        save_ok
        -- return
    ),

    /*
    Selects a SCRIPTS row on a single click and cycles its checkbox mode when clicked.
    Loading script files is reserved for the separate double-click handler.
    */
    function handleScriptTreeNodeClick click_args =
    (
        if click_args == undefined or click_args.Node == undefined then return false

        tree_control = this.getScriptTreeControl()
        if tree_control == undefined then return false

        mouse_buttons_type = dotNetClass "System.Windows.Forms.MouseButtons"

        if click_args.Button == mouse_buttons_type.Right then
        (
            tree_control.SelectedNode = click_args.Node
            this.updateScriptTreeContextMenuState()

            if script_tree_context_menu != undefined then
            (
                script_tree_context_menu.Show tree_control click_args.Location
            )

            return true
        )

        if click_args.Button != mouse_buttons_type.Left then return false

        tree_control.SelectedNode = click_args.Node
        hit_info = tree_control.HitTest click_args.Location
        if hit_info == undefined then return true

        hit_location_text = hit_info.Location.ToString()
        if (findString hit_location_text "Image") != undefined and click_args.Clicks == 1 then
        (
            return this.cycleScriptTreeNodeMode click_args.Node
        )

        true
        -- return
    ),

    /*
    Loads MS and MCR files only on a left-button double-click of their filename label.
    Checkbox images, folder rows, and MSE files never trigger a direct load.
    */
    function handleScriptTreeNodeDoubleClick click_args =
    (
        if click_args == undefined or click_args.Node == undefined then return false

        tree_control = this.getScriptTreeControl()
        if tree_control == undefined then return false

        mouse_buttons_type = dotNetClass "System.Windows.Forms.MouseButtons"
        if click_args.Button != mouse_buttons_type.Left then return false

        hit_info = tree_control.HitTest click_args.Location
        if hit_info == undefined then return false
        if hit_info.Location.ToString() != "Label" then return false

        this.loadDoubleClickedScriptTreeNode click_args.Node
        -- return
    ),

    /*
    Returns whether one discovered script-bearing directory gets its own SCRIPTS row.
    COLLAPSE DIRS can hide redundant same-name tool rows but not empty-folder pruning.
    */
    function shouldDisplayScriptTreeDirectory group_index =
    (
        if group_index < 1 or group_index > available_group_paths.count then return false
        if group_index > available_group_directories.count then return false

        group_path = available_group_paths[group_index]
        group_directory = available_group_directories[group_index]
        tree_group_path = if group_index <= available_group_tree_paths.count then available_group_tree_paths[group_index] else group_path
        if group_path == "" or tree_group_path == "" or group_directory == "" then return false

        /* Full hierarchy includes tool directories previously omitted as redundant. */
        if not collapse_script_dirs then return true

        if group_index <= available_group_displayable.count then available_group_displayable[group_index] else (this.getSourceToolScriptPath group_directory == "")
        -- return
    ),

    /*
    Ensures one display-relative directory path exists in the SCRIPTS TreeView and returns its child-node collection.
    The supplied real directory keeps OPEN IN EXPLORER and persisted expansion paths correct when unchecked ancestors are hidden.
    */
    function ensureScriptTreeFolderPath root_nodes group_path group_directory node_lookup node_values =
    (
        parent_nodes = root_nodes
        if group_path == "" then return parent_nodes

        path_parts = filterString group_path "\\"
        current_path = ""
        normalized_group_directory = ScriptManagerIntegration.normalizeDirectoryPath group_directory

        for part_index = 1 to path_parts.count do
        (
            part_name = path_parts[part_index]
            current_path = if current_path == "" then part_name else (current_path + "\\" + part_name)
            node_key = toLower current_path

            if not(HasDictValue node_lookup node_key) then
            (
                folder_node = parent_nodes.Add part_name
                folder_directory = normalized_group_directory
                levels_up = path_parts.count - part_index

                for level_index = 1 to levels_up do
                (
                    if folder_directory != "" then
                    (
                        folder_directory_no_slash = substring folder_directory 1 (folder_directory.count - 1)
                        folder_directory = ScriptManagerIntegration.normalizeDirectoryPath (pathConfig.removePathLeaf folder_directory_no_slash)
                    )
                )

                folder_node.Tag = folder_directory
                folder_node.ToolTipText = folder_directory
                if script_tree_folder_font != undefined then folder_node.NodeFont = script_tree_folder_font
                PutDictValue node_lookup node_key folder_node
                append node_values folder_node
                parent_nodes = folder_node.Nodes
            )
            else
            (
                folder_node = GetDictValue node_lookup node_key
                parent_nodes = folder_node.Nodes
            )
        )

        parent_nodes
        -- return
    ),

    /*
    Builds render-local group indexes once instead of rescanning all scripts for each displayed leaf.
    The first native dictionary counts scripts directly in a folder; the second marks folders with descendant scripts.
    */
    function buildScriptTreeGroupCache =
    (
        group_counts = Dictionary #string
        descendant_paths = Dictionary #string

        for group_path in available_script_group_paths do
        (
            group_key = toLower group_path

            if HasDictValue group_counts group_key then
            (
                PutDictValue group_counts group_key ((GetDictValue group_counts group_key) + 1)
            )
            else
            (
                PutDictValue group_counts group_key 1
            )

            parent_path = this.getParentRelativePath group_key

            while parent_path != "" do
            (
                if not(HasDictValue descendant_paths parent_path) then PutDictValue descendant_paths parent_path true
                parent_path = this.getParentRelativePath parent_path
            )
        )

        #(group_counts, descendant_paths)
        -- return
    ),

    /*
    Returns the display-only group path for one discovered script row.
    Optional render-local indexes avoid the quadratic scan used by the compatibility path.
    */
    function getScriptTreeDisplayGroupPath script_index group_counts:undefined descendant_paths:undefined =
    (
        if script_index < 1 or script_index > available_script_paths.count then return ""
        if script_index > available_script_group_paths.count then return ""

        script_path = available_script_paths[script_index]
        group_path = available_script_group_paths[script_index]
        tree_group_path = if script_index <= available_script_tree_group_paths.count then available_script_tree_group_paths[script_index] else group_path
        if group_path == "" or tree_group_path == "" then return tree_group_path
        if not collapse_script_dirs then return tree_group_path

        path_parts = filterString group_path "\\"
        tree_path_parts = filterString tree_group_path "\\"
        if path_parts.count == 0 or tree_path_parts.count == 0 then return tree_group_path

        folder_name = path_parts[path_parts.count]
        script_stem = getFilenameFile script_path
        if (toLower folder_name) != (toLower script_stem) then return tree_group_path

        matching_script_count = 0
        descendant_script_found = false
        group_path_lower = toLower group_path
        descendant_prefix = group_path_lower + "\\"

        if group_counts != undefined and descendant_paths != undefined then
        (
            if HasDictValue group_counts group_path_lower then matching_script_count = GetDictValue group_counts group_path_lower
            descendant_script_found = HasDictValue descendant_paths group_path_lower
        )
        else
        (
            for compare_index = 1 to available_script_group_paths.count do
            (
                compare_group_path_lower = toLower available_script_group_paths[compare_index]

                if compare_group_path_lower == group_path_lower then
                (
                    matching_script_count += 1
                )
                else if (findString compare_group_path_lower descendant_prefix) == 1 then
                (
                    descendant_script_found = true
                )
            )
        )

        if matching_script_count != 1 or descendant_script_found then return tree_group_path
        if tree_path_parts.count == 1 then return ""

        display_group_path = tree_path_parts[1]
        for part_index = 2 to (tree_path_parts.count - 1) do
        (
            display_group_path += "\\" + tree_path_parts[part_index]
        )

        display_group_path
        -- return
    ),

    /*
    Matches the case-insensitive filter against one script filename or its relative folder path.
    A matching folder therefore exposes every discovered script beneath it.
    */
    function scriptTreeFilterMatches script_index =
    (
        if script_filter_text == "" then return true
        if script_index < 1 or script_index > available_script_paths.count then return false
        if script_index > available_script_tree_group_paths.count and script_index > available_script_group_paths.count then return false

        script_leaf = toLower (pathConfig.stripPathToLeaf available_script_paths[script_index])
        if (findString script_leaf script_filter_text) != undefined then return true

        group_path = if script_index <= available_script_tree_group_paths.count then available_script_tree_group_paths[script_index] else available_script_group_paths[script_index]
        if group_path == undefined then return false

        (findString (toLower group_path) script_filter_text) != undefined
        -- return
    ),

    /*
    Renders SCRIPTS using saved per-folder expansion states on initial open and refresh.
    Folders without a saved state start collapsed; script load states are unaffected.
    */
    function populateScriptTree restore_expansion:true =
    (
        if script_manager_scripts_ui == undefined then return false
        if root_directory == "" then return false

        tree_control = this.getScriptTreeControl()
        if tree_control == undefined then return false

        timing_start = timestamp()
        timing_phase_start = timing_start
        timing_folders_ms = 0
        timing_files_ms = 0
        timing_states_ms = 0
        script_tree_file_count = 0
        populate_ok = true
        filter_active = script_filter_text != ""

        /* Suppress expand/collapse persistence throughout Clear, rebuild, and restore. */
        tree_expansion_syncing = true

        try
        (
            this.styleScriptTree()
            if script_tree_context_menu == undefined then this.buildScriptTreeContextMenu()

            tree_control.BeginUpdate()
            tree_control.Nodes.Clear()
            tree_control.ShowNodeToolTips = true
            tree_control.HideSelection = false
            tree_control.FullRowSelect = true

            node_lookup = Dictionary #string
            node_values = #()
            group_cache = this.buildScriptTreeGroupCache()

            if not filter_active then
            (
                for group_index = 1 to available_group_paths.count do
                (
                    if this.shouldDisplayScriptTreeDirectory group_index then
                    (
                        tree_group_path = if group_index <= available_group_tree_paths.count then available_group_tree_paths[group_index] else available_group_paths[group_index]
                        this.ensureScriptTreeFolderPath tree_control.Nodes tree_group_path available_group_directories[group_index] node_lookup node_values
                    )
                )
            )

            timing_folders_ms = timestamp() - timing_phase_start
            timing_phase_start = timestamp()

            /*
            First establish every script folder that will remain visible. A same-name
            script may normally be flattened, but must use its real parent whenever
            another tree row has already made that parent folder visible. This
            prepass also removes dependence on discovery / file insertion order.
            */
            script_display_group_paths = #()
            for script_index = 1 to available_script_paths.count do
            (
                display_group_path = undefined
                if (not filter_active) or (this.scriptTreeFilterMatches script_index) then
                (
                    display_group_path = this.getScriptTreeDisplayGroupPath script_index group_counts:group_cache[1] descendant_paths:group_cache[2]

                    if display_group_path != "" then
                    (
                        raw_tree_group_path = if script_index <= available_script_tree_group_paths.count then available_script_tree_group_paths[script_index] else available_script_group_paths[script_index]
                        group_directory = available_script_directories[script_index]

                        if display_group_path != raw_tree_group_path and group_directory != "" then
                        (
                            group_directory_no_slash = substring group_directory 1 (group_directory.count - 1)
                            group_directory = ScriptManagerIntegration.normalizeDirectoryPath (pathConfig.removePathLeaf group_directory_no_slash)
                        )

                        this.ensureScriptTreeFolderPath tree_control.Nodes display_group_path group_directory node_lookup node_values
                    )
                )
                append script_display_group_paths display_group_path
            )

            for script_index = 1 to available_script_paths.count do
            (
                if script_display_group_paths[script_index] != undefined then
                (
                    script_path = available_script_paths[script_index]
                    group_path = script_display_group_paths[script_index]
                    raw_tree_group_path = if script_index <= available_script_tree_group_paths.count then available_script_tree_group_paths[script_index] else available_script_group_paths[script_index]
                    group_directory = available_script_directories[script_index]

                    /* A visible parent wins over a flattened display shortcut. */
                    if raw_tree_group_path != "" and HasDictValue node_lookup (toLower raw_tree_group_path) then group_path = raw_tree_group_path

                    if group_path != raw_tree_group_path and group_directory != "" then
                    (
                        group_directory_no_slash = substring group_directory 1 (group_directory.count - 1)
                        group_directory = ScriptManagerIntegration.normalizeDirectoryPath (pathConfig.removePathLeaf group_directory_no_slash)
                    )

                    parent_nodes = this.ensureScriptTreeFolderPath tree_control.Nodes group_path group_directory node_lookup node_values

                    script_leaf = pathConfig.stripPathToLeaf script_path
                    script_node = parent_nodes.Add script_leaf
                    script_node.Tag = script_path
                    script_node.ToolTipText = script_path
                    script_tree_file_count += 1
                )
            )

            timing_files_ms = timestamp() - timing_phase_start

            if filter_active then
            (
                for folder_node in node_values do folder_node.Expand()
            )
            else if restore_expansion then
            (
                for folder_node in node_values do
                (
                    if this.loadTreeNodeOpenState folder_node "ScriptTreeOpen" default_expanded:false then folder_node.Expand() else folder_node.Collapse()
                )
            )

            timing_phase_start = timestamp()
            if not(this.syncScriptTreeChecks()) then throw "SCRIPTS state synchronization failed"
            timing_states_ms = timestamp() - timing_phase_start
            tree_control.EndUpdate()

            script_tree_required_height = this.getScriptTreeRequiredHeight()
            loader_content_height = 1942
        )
        catch
        (
            exception_text = getCurrentException()
            populate_ok = false

            try
            (
                tree_control.EndUpdate()
            )
            catch
            (
                cleanup_exception_text = getCurrentException()
            )

            format "[Script-Manager] Script tree population failed: %\n" exception_text
        )

        tree_expansion_syncing = false
        timing_elapsed_ms = timestamp() - timing_start
        format "[Script-Manager][TIMING] SCRIPTS RENDER PHASES | folders:% ms | files:% ms | states:% ms\n" timing_folders_ms timing_files_ms timing_states_ms
        format "[Script-Manager][TIMING] SCRIPTS TREE RENDER | % ms | folders:% | scripts:% | success:%\n" timing_elapsed_ms available_group_paths.count script_tree_file_count populate_ok
        populate_ok
        -- return
    ),

    /*
    Populates SCRIPTS once on startup, restoring saved expanded/collapsed folders.
    Folders without persisted state default to collapsed, including on the first run.
    */
    function populateInitialScriptTree =
    (
        if script_tree_initialized then return true
        if this.getScriptTreeControl() == undefined then return false

        script_tree_initialized = this.populateScriptTree restore_expansion:true
        script_tree_initialized
        -- return
    ),

    /*
    Removes the PRESETS, OPTIONS, SOURCES, and SCRIPTS loader rollouts, including nested SHOW & IGNORE.
    */
    function clearLoaderRollout =
    (
        if script_manager_ui == undefined then return false

        source_menu_cleanup_ok = this.clearSourceTreeContextMenu()
        script_menu_cleanup_ok = this.clearScriptTreeContextMenu()
        cleanup_ok = source_menu_cleanup_ok and script_menu_cleanup_ok

        /* Nested sections must be detached before their OPTIONS parent. */
        if show_rollout != undefined then
        (
            try
            (
                if options_rollout != undefined then removeSubRollout options_rollout.sr_show show_rollout
                show_rollout = undefined
            )
            catch
            (
                cleanup_ok = false
                format "[Script-Manager] SHOW rollout removal failed: %\n" (getCurrentException())
            )
        )

        if ignore_rollout != undefined then
        (
            try
            (
                if options_rollout != undefined then removeSubRollout options_rollout.sr_ignore ignore_rollout
                ignore_rollout = undefined
            )
            catch
            (
                cleanup_ok = false
                format "[Script-Manager] IGNORE rollout removal failed: %\n" (getCurrentException())
            )
        )

        if preset_rollout != undefined then
        (
            try
            (
                removeSubRollout script_manager_ui.sr_loader preset_rollout
                preset_rollout = undefined
            )
            catch
            (
                exception_text = getCurrentException()
                cleanup_ok = false
                format "[Script-Manager] PRESETS rollout removal failed: %\n" exception_text
            )
        )

        if options_rollout != undefined then
        (
            try
            (
                removeSubRollout script_manager_ui.sr_loader options_rollout
                options_rollout = undefined
            )
            catch
            (
                exception_text = getCurrentException()
                cleanup_ok = false
                format "[Script-Manager] OPTIONS rollout removal failed: %\n" exception_text
            )
        )

        if source_rollout != undefined then
        (
            try
            (
                removeSubRollout script_manager_ui.sr_loader source_rollout
                source_rollout = undefined
            )
            catch
            (
                exception_text = getCurrentException()
                cleanup_ok = false
                format "[Script-Manager] SOURCES rollout removal failed: %\n" exception_text
            )
        )

        if script_rollout != undefined then
        (
            try
            (
                removeSubRollout script_manager_ui.sr_loader script_rollout
                script_rollout = undefined
            )
            catch
            (
                exception_text = getCurrentException()
                cleanup_ok = false
                format "[Script-Manager] SCRIPTS rollout removal failed: %\n" exception_text
            )
        )

        loader_rollout = undefined
        cleanup_ok
        -- return
    ),

    /*
    Updates and saves the PRESETS rollout expanded state.
    */
    function setPresetRolloutOpen open_state =
    (
        preset_rollout_open = open_state
        this.savePresetRolloutOpenState open_state

        if script_manager_ui != undefined then
        (
            this.layoutManager [script_manager_ui.width, script_manager_ui.height]
        )

        true
        -- return
    ),

    /*
    Updates and saves the OPTIONS rollout expanded state.
    */
    function setOptionsRolloutOpen open_state =
    (
        options_rollout_open = open_state
        this.saveOptionsRolloutOpenState open_state

        if script_manager_ui != undefined then
        (
            this.layoutManager [script_manager_ui.width, script_manager_ui.height]
        )

        true
        -- return
    ),

    /*
    Updates and saves the SOURCES rollout expanded state.
    */
    function setSourceRolloutOpen open_state =
    (
        source_rollout_open = open_state
        this.saveSourceRolloutOpenState open_state

        if script_manager_ui != undefined then
        (
            this.layoutManager [script_manager_ui.width, script_manager_ui.height]
        )

        true
        -- return
    ),

    /*
    Updates and persists SHOW section expansion inside OPTIONS.
    */
    function setShowRolloutOpen open_state =
    (
        show_rollout_open = open_state
        show_ignore_rollout_open = show_rollout_open or ignore_rollout_open
        this.saveShowRolloutOpenState open_state

        if script_manager_ui != undefined then
        (
            this.layoutManager [script_manager_ui.width, script_manager_ui.height]
        )

        true
        -- return
    ),

    /*
    Updates and persists IGNORE section expansion inside OPTIONS.
    */
    function setIgnoreRolloutOpen open_state =
    (
        ignore_rollout_open = open_state
        show_ignore_rollout_open = show_rollout_open or ignore_rollout_open
        this.saveIgnoreRolloutOpenState open_state

        if script_manager_ui != undefined then
        (
            this.layoutManager [script_manager_ui.width, script_manager_ui.height]
        )

        true
        -- return
    ),

    /*
    Legacy API: expands or collapses both migrated sections together.
    */
    function setShowIgnoreRolloutOpen open_state =
    (
        show_ignore_rollout_open = open_state
        show_rollout_open = open_state
        ignore_rollout_open = open_state
        this.saveShowIgnoreRolloutOpenState open_state
        this.saveShowRolloutOpenState open_state
        this.saveIgnoreRolloutOpenState open_state

        if script_manager_ui != undefined then
        (
            this.layoutManager [script_manager_ui.width, script_manager_ui.height]
        )

        true
        -- return
    ),

    /*
    Updates and saves the SCRIPTS rollout expanded state.
    */
    function setScriptRolloutOpen open_state =
    (
        script_rollout_open = open_state
        this.saveScriptRolloutOpenState open_state

        if script_manager_ui != undefined then
        (
            this.layoutManager [script_manager_ui.width, script_manager_ui.height]
        )

        true
        -- return
    ),

    /*
    Legacy compatibility wrapper for the previous combined loader rollout state.
    */
    function setLoaderRolloutOpen open_state =
    (
        loader_rollout_open = open_state
        preset_rollout_open = open_state
        options_rollout_open = open_state
        source_rollout_open = open_state
        show_ignore_rollout_open = open_state
        show_rollout_open = open_state
        ignore_rollout_open = open_state
        script_rollout_open = open_state

        this.saveLoaderOpenState open_state
        this.savePresetRolloutOpenState open_state
        this.saveOptionsRolloutOpenState open_state
        this.saveSourceRolloutOpenState open_state
        this.saveShowIgnoreRolloutOpenState open_state
        this.saveShowRolloutOpenState open_state
        this.saveIgnoreRolloutOpenState open_state
        this.saveScriptRolloutOpenState open_state

        if script_manager_ui != undefined then
        (
            this.layoutManager [script_manager_ui.width, script_manager_ui.height]
        )

        true
        -- return
    ),

    /*
    Builds PRESETS, OPTIONS (with SHOW and IGNORE), SOURCES, and SCRIPTS.
    ROOT PATH and IGNORE edits remain pending until manual REFRESH.
    */
    function buildLoaderRollout =
    (
        if script_manager_ui == undefined then return false

        if not(this.clearLoaderRollout()) then return false

        source_tree_initialized = false
        script_tree_initialized = false
        script_filter_text = ""

        preset_rollout_open = this.loadPresetRolloutOpenState()
        options_rollout_open = this.loadOptionsRolloutOpenState()
        source_rollout_open = this.loadSourceRolloutOpenState()
        show_rollout_open = this.loadShowRolloutOpenState()
        ignore_rollout_open = this.loadIgnoreRolloutOpenState()
        show_ignore_rollout_open = show_rollout_open or ignore_rollout_open
        script_rollout_open = this.loadScriptRolloutOpenState()
        loader_rollout_open = preset_rollout_open or options_rollout_open or source_rollout_open or script_rollout_open
        this.loadShowVersionedFiles()
        this.loadShowCleanScriptsOnly()
        this.loadCollapseScriptDirs()
        this.loadScriptIgnoreMask()

        preset_text = "rollout script_manager_presets_ui \"PRESETS\" width:288 height:" + (preset_rollout_content_height as string) + "\n(\n"
        preset_text += "    dropdownList ddl_presets \"\" pos:[6,6] width:180 height:24 items:#(\"<Preset>\") tooltip:\"Select a preset.\"\n"
        preset_text += "    button btn_preset_save_remove \"SAVE \\\\ REMOVE\" pos:[192,6] width:90 height:24 tooltip:\"LMB: Save SOURCES and SKIP / HOST / DIRECT states as a named preset.\\n\\nRMB: Remove the preset selected in the dropdown.\"\n"
        preset_text += "    button btn_preset_load \"LOAD\" pos:[6,42] width:86 height:24 tooltip:\"Apply the selected preset and hard reload its configured scripts.\"\n"
        preset_text += "    button btn_preset_macro \"MACRO\" pos:[101,42] width:86 height:24 tooltip:\"Create or update a toolbar MacroScript action for the selected preset.\"\n"
        preset_text += "    checkbutton btn_preset_startup \"STARTUP\" pos:[196,42] width:86 height:24 checked:false tooltip:\"Load the selected preset automatically when 3ds Max starts.\"\n"
        preset_text += "    on btn_preset_save_remove pressed do (if script_manager != undefined then script_manager.handlePresetSave())\n"
        preset_text += "    on btn_preset_save_remove rightclick do (if script_manager != undefined then script_manager.handlePresetRemove())\n"
        preset_text += "    on btn_preset_load pressed do (if script_manager != undefined then script_manager.handlePresetLoad())\n"
        preset_text += "    on btn_preset_macro pressed do (if script_manager != undefined then script_manager.handlePresetMacro())\n"
        preset_text += "    on btn_preset_startup changed startup_state do (if script_manager != undefined then script_manager.handlePresetStartupChanged startup_state)\n"
        preset_text += "    on ddl_presets selected item_index do (if script_manager != undefined then script_manager.handlePresetSelected item_index)\n"
        preset_text += "    on script_manager_presets_ui open do (if script_manager != undefined then script_manager.refreshPresetDropdown())\n"
        preset_text += "    on script_manager_presets_ui rolledUp state do (if script_manager != undefined then script_manager.setPresetRolloutOpen state)\n"
        preset_text += ")"

        show_slot_height = if show_rollout_open then (show_rollout_content_height + rollout_header_height) else loader_collapsed_height
        ignore_slot_height = if ignore_rollout_open then (ignore_rollout_content_height + rollout_header_height) else loader_collapsed_height
        options_inner_offset = show_slot_height + ignore_slot_height + 8

        options_text = "rollout script_manager_options_ui \"OPTIONS\" width:288 height:" + ((options_rollout_content_height + options_inner_offset) as string) + "\n(\n"
        options_text += "    label lbl_source_root \"ROOT PATH:\" pos:[6,6] width:90 height:18\n"
        options_text += "    editText edt_source_root \"\" pos:[6,24] width:210 height:16 text:\"\" tooltip:\"Root directory shown in SOURCES.\\nType a path or use BROWSE.\\n\\nTyped edits are saved and applied with LMB REFRESH. BROWSE applies immediately.\"\n"
        options_text += "    button btn_source_root_browse \"BROWSE\" pos:[222,24] width:60 height:24 tooltip:\"Choose and apply the SOURCES root directory.\\n\\nSelection is saved and both trees are rebuilt immediately.\"\n"
        options_text += "    subRollout sr_show \"\" pos:[0,54] width:288 height:" + (show_slot_height as string) + "\n"
        options_text += "    subRollout sr_ignore \"\" pos:[0," + ((58 + show_slot_height) as string) + "] width:288 height:" + (ignore_slot_height as string) + "\n"
        options_text += "    on btn_source_root_browse pressed do (if script_manager != undefined then script_manager.browseSourceRootDirectory())\n"
        options_text += "    on script_manager_options_ui rolledUp state do (if script_manager != undefined then script_manager.setOptionsRolloutOpen state)\n"
        options_text += ")"

        source_text = "rollout script_manager_sources_ui \"SOURCES\" width:288 height:" + (source_rollout_content_height as string) + "\n(\n"
        source_text += "    dotNetControl tv_sources \"System.Windows.Forms.TreeView\" pos:[6,6] width:276 height:512\n"
        source_text += "    on tv_sources NodeMouseClick click_args do (if script_manager != undefined then script_manager.handleSourceTreeNodeClick click_args)\n"
        source_text += "    on tv_sources AfterCheck check_args do (if script_manager != undefined then script_manager.handleSourceTreeAfterCheck check_args)\n"
        source_text += "    on tv_sources AfterExpand event_args do (if script_manager != undefined then script_manager.handleSourceTreeExpandedState event_args)\n"
        source_text += "    on tv_sources AfterCollapse event_args do (if script_manager != undefined then script_manager.handleSourceTreeExpandedState event_args)\n"
        source_text += "    on script_manager_sources_ui open do (if script_manager != undefined then script_manager.populateInitialSourceTree())\n"
        source_text += "    on script_manager_sources_ui rolledUp state do (if script_manager != undefined then script_manager.setSourceRolloutOpen state)\n"
        source_text += ")"

        show_text = "rollout script_manager_show_ui \"SHOW\" width:288 height:" + (show_rollout_content_height as string) + "\n(\n"
        show_text += "    checkbox chk_show_versions \"VERSIONED FILES\" pos:[6,6] width:110 height:24 checked:" + (show_versioned_files as string) + " tooltip:\"Show every versioned script instead of only the canonical file or newest version.\"\n"
        show_text += "    checkbox chk_clean_scripts \"CLEAN SCRIPTS\" pos:[116,6] width:94 height:24 triState:" + ((this.getCleanScriptsMode()) as string) + " tooltip:\"OFF: Normal script listing.\\nON: Show only the unversioned script matching its parent folder.\\nMIXED: Same as ON, but show all scripts in folders without a name match.\"\n"
        show_text += "    checkbox chk_collapse_dirs \"COLLAPSE DIRS\" pos:[210,6] width:96 height:24 checked:" + (collapse_script_dirs as string) + " tooltip:\"ON: Hide only redundant same-named tool directories containing one script and no other visible branches.\\nOFF: Show the full SCRIPTS directory hierarchy.\"\n"
        show_text += "    on chk_show_versions changed state do (if script_manager != undefined then script_manager.handleShowVersionedChanged state)\n"
        show_text += "    on chk_clean_scripts changed state do (if script_manager != undefined then script_manager.handleShowCleanScriptsChanged state)\n"
        show_text += "    on chk_collapse_dirs changed state do (if script_manager != undefined then script_manager.handleCollapseScriptDirsChanged state)\n"
        show_text += "    on script_manager_show_ui rolledUp state do (if script_manager != undefined then script_manager.setShowRolloutOpen state)\n"
        show_text += ")"

        ignore_text = "rollout script_manager_ignore_ui \"IGNORE\" width:288 height:" + (ignore_rollout_content_height as string) + "\n(\n"
        ignore_text += "    label lbl_script_ignore \"IGNORE:\" pos:[6,6] width:90 height:18\n"
        ignore_text += "    editText edt_script_ignore \"\" pos:[6,24] width:276 height:16 text:\"\" tooltip:\"Filter SCRIPTS tree items by name.\\nSeparate multiple entries with |.\\n\\nPlain names match exactly; * and ? are wildcards.\\nExample: .git|*-OLD|*-DELETED\\n\\nMatching folders hide their complete SCRIPTS subtree.\\nThe value is saved to script_manager.ini and applied only when you press LMB REFRESH.\"\n"
        ignore_text += "    on script_manager_ignore_ui rolledUp state do (if script_manager != undefined then script_manager.setIgnoreRolloutOpen state)\n"
        ignore_text += ")"

        script_text = "rollout script_manager_scripts_ui \"SCRIPTS\" width:288 height:" + (script_rollout_content_height as string) + "\n(\n"
        script_text += "    button btn_load_scripts \"LOAD SCRIPTS\" pos:[6,6] width:88 height:24 tooltip:\"LMB: Load only configured scripts that are not currently running.\\n\\nRMB: Hard reload every configured script.\"\n"
        script_text += "    button btn_create_toolbar \"CREATE TOOLBAR\" pos:[100,6] width:108 height:24 tooltip:\"Prompt for a toolbar name, then create and load a toolbar from every HOST and DIRECT script in tree order.\"\n"
        script_text += "    checkbutton btn_save_toolbar_ui \"SAVE UI\" pos:[214,6] width:68 height:24 checked:true tooltip:\"ON: Save the generated toolbar back to the active CUIX.\\n\\nOFF: Keep it only in the temporary CUIX loaded for this session.\"\n"
        script_text += "    label lbl_scripts_filter \"FILTER:\" pos:[6,37] width:50 height:16\n"
        script_text += "    editText edt_scripts_filter \"\" pos:[58,36] width:224 height:16 text:\"\" tooltip:\"Filter visible scripts and their parent folder names as you type.\\nCase-insensitive; clearing restores the full SCRIPTS tree.\\nNo source rescan, script execution, or INI changes.\"\n"
        script_text += "    dotNetControl tv_scripts \"System.Windows.Forms.TreeView\" pos:[6,60] width:276 height:1032\n"
        script_text += "    on btn_load_scripts pressed do (if script_manager != undefined then script_manager.updateScripts())\n"
        script_text += "    on btn_load_scripts rightclick do (if script_manager != undefined then script_manager.loadScripts())\n"
        script_text += "    on btn_create_toolbar pressed do (if script_manager != undefined then script_manager.handleCreateToolbar save_ui:btn_save_toolbar_ui.checked)\n"
        script_text += "    on edt_scripts_filter changed filter_value do (if script_manager != undefined then script_manager.handleScriptTreeFilterChanged filter_value)\n"
        script_text += "    on tv_scripts NodeMouseClick click_args do (if script_manager != undefined then script_manager.handleScriptTreeNodeClick click_args)\n"
        script_text += "    on tv_scripts NodeMouseDoubleClick click_args do (if script_manager != undefined then script_manager.handleScriptTreeNodeDoubleClick click_args)\n"
        script_text += "    on tv_scripts AfterExpand event_args do (if script_manager != undefined then script_manager.handleScriptTreeExpandedState event_args)\n"
        script_text += "    on tv_scripts AfterCollapse event_args do (if script_manager != undefined then script_manager.handleScriptTreeExpandedState event_args)\n"
        script_text += "    on script_manager_scripts_ui open do (if script_manager != undefined then script_manager.populateInitialScriptTree())\n"
        script_text += "    on script_manager_scripts_ui rolledUp state do (if script_manager != undefined then script_manager.setScriptRolloutOpen state)\n"
        script_text += ")"

        try
        (
            execute preset_text
            execute options_text
            execute source_text
            execute show_text
            execute ignore_text
            execute script_text

            preset_rollout = script_manager_presets_ui
            options_rollout = script_manager_options_ui
            source_rollout = script_manager_sources_ui
            show_rollout = script_manager_show_ui
            ignore_rollout = script_manager_ignore_ui
            script_rollout = script_manager_scripts_ui
            loader_rollout = script_rollout

            addSubRollout script_manager_ui.sr_loader preset_rollout rolledUp:(not preset_rollout_open)
            addSubRollout script_manager_ui.sr_loader options_rollout rolledUp:(not options_rollout_open)

            /* Restore ROOT PATH before tree open handlers can fail during construction. */
            root_control = this.getSourceRootPathControl()
            if root_control == undefined then throw "ROOT PATH control was not created"
            root_control.text = root_directory

            /* Attach SHOW and IGNORE only to the OPTIONS section slots. */
            addSubRollout options_rollout.sr_show show_rollout rolledUp:(not show_rollout_open)
            addSubRollout options_rollout.sr_ignore ignore_rollout rolledUp:(not ignore_rollout_open)
            addSubRollout script_manager_ui.sr_loader source_rollout rolledUp:(not source_rollout_open)
            addSubRollout script_manager_ui.sr_loader script_rollout rolledUp:(not script_rollout_open)
            ignore_control = this.getScriptIgnoreMaskControl()
            if ignore_control == undefined then throw "IGNORE control was not created"
            ignore_control.text = source_ignore_mask

            if not(this.populateInitialSourceTree()) then throw "populateInitialSourceTree returned false"
            if not(this.populateInitialScriptTree()) then throw "populateInitialScriptTree returned false"
            if not(this.refreshPresetDropdown()) then throw "refreshPresetDropdown returned false"
        )
        catch
        (
            format "[Script-Manager] Loader rollout creation failed | attached:% | PRESETS:% | OPTIONS:% | SHOW:% | IGNORE:% | SOURCES:% | SCRIPTS:% | error:%\n" script_manager_ui.sr_loader.rollouts.count (preset_rollout != undefined) (options_rollout != undefined) (show_rollout != undefined) (ignore_rollout != undefined) (source_rollout != undefined) (script_rollout != undefined) (getCurrentException())
            /* Preserve attached controls so REFRESH can retry and edits remain accessible. */
            return false
        )

        true
        -- return
    ),

/*
Returns the organizational host-dialog path for one tool-folder path.
A tool folder normally lives one level below the subdirectory that owns its dialog.
*/
function getHostDialogPathForGroup group_path =
(
    if group_path == undefined or group_path == "" then return "__ROOT__"

    parent_path = this.getParentRelativePath group_path
    if parent_path == "" then group_path else parent_path
    -- return
),

/*
Returns the visible dialog name for one organizational host path.
*/
function getHostDialogTitle host_path =
(
    if host_path == undefined or host_path == "" or host_path == "__ROOT__" then return "Scripts"

    normalized_host_path = substituteString host_path "/" "\\"
    if normalized_host_path[normalized_host_path.count] != "\\" then normalized_host_path += "\\"

    host_name = ScriptManagerIntegration.getFolderName normalized_host_path
    if host_name == "" then host_name = host_path

    host_name
    -- return
),

/*
Returns one live organizational host dialog by its root-relative host path.
*/
function getHostDialog host_path =
(
    host_index = findItem host_dialog_paths host_path
    if host_index == 0 then return undefined
    if host_index > host_dialogs.count then return undefined

    host_dialogs[host_index]
    -- return
),

/*
Tracks one primary HOST-mode script that actually embedded rollout UI into an organizational dialog.
This list drives per-dialog title-button reload without touching other dialogs or DIRECT scripts.
*/
function trackHostScript script_path host_path =
(
    if script_path == undefined or script_path == "" then return false
    if host_path == undefined or host_path == "" then return false

    normalized_script_path = toLower script_path
    existing_index = 0

    for item_index = 1 to loaded_host_script_paths.count while existing_index == 0 do
    (
        if (toLower loaded_host_script_paths[item_index]) == normalized_script_path then existing_index = item_index
    )

    if existing_index > 0 then
    (
        if existing_index <= loaded_host_script_dialog_paths.count then
        (
            loaded_host_script_dialog_paths[existing_index] = host_path
        )
    )
    else
    (
        append loaded_host_script_paths script_path
        append loaded_host_script_dialog_paths host_path
    )

    true
    -- return
),

/*
Returns the primary HOST-mode script paths currently owned by one organizational dialog.
*/
function getHostScriptPaths host_path =
(
    script_paths = #()

    if host_path == undefined or host_path == "" then return script_paths

    for item_index = 1 to loaded_host_script_dialog_paths.count do
    (
        if loaded_host_script_dialog_paths[item_index] == host_path and item_index <= loaded_host_script_paths.count then
        (
            script_path = loaded_host_script_paths[item_index]
            if (findItem script_paths script_path) == 0 then append script_paths script_path
        )
    )

    script_paths
    -- return
),

/*
Clears the tracked primary HOST-mode scripts for one organizational dialog.
*/
function clearHostScriptTracking host_path =
(
    if host_path == undefined or host_path == "" then return false

    for item_index = loaded_host_script_dialog_paths.count to 1 by -1 do
    (
        if loaded_host_script_dialog_paths[item_index] == host_path then
        (
            if item_index <= loaded_host_script_paths.count then deleteItem loaded_host_script_paths item_index
            deleteItem loaded_host_script_dialog_paths item_index
        )
    )

    true
    -- return
),

/*
Returns the INI section used to persist one organizational host dialog.
*/
function getHostDialogIniSection host_path =
(
    normalized_host_path = if host_path == undefined or host_path == "" then "__ROOT__" else substituteString host_path "\\" "/"
    "HostDialog|" + normalized_host_path
    -- return
),

    /*
    Returns the generated category rollout for one relative group path.
    Unknown paths return undefined.
    */
    function getGroupRollout group_path =
    (
        group_index = findItem group_rollout_paths group_path
        if group_index == 0 then return undefined

        group_rollouts[group_index]
        -- return
    ),

    /*
    Returns the saved expanded state for one directory-backed category rollout.
    New categories are expanded by default.
    */
    function loadGroupOpenState group_path =
    (
        this.getIniBoolean "Groups" group_path true
        -- return
    ),

    /*
    Saves the expanded state for one directory-backed category rollout.
    */
    function saveGroupOpenState group_path open_state =
    (
        setINISetting ini_path "Groups" group_path (if open_state then "1" else "0") forceUTF16:false
        true
        -- return
    ),

    /*
    Saves every generated category rollout open state.
    */
    function saveAllGroupStates =
    (
        save_ok = true

        for group_index = 1 to group_rollouts.count do
        (
            group_rollout = group_rollouts[group_index]
            group_open = true
            read_ok = true

            try
            (
                group_open = group_rollout.open
            )
            catch
            (
                exception_text = getCurrentException()
                read_ok = false
                save_ok = false
                format "[Script-Manager] Category open-state read failed: %\n" exception_text
            )

            if read_ok then
            (
                if not(this.saveGroupOpenState group_rollout_paths[group_index] group_open) then save_ok = false
            )
        )

        save_ok
        -- return
    ),

    /*
    Escapes one value for safe insertion into dynamically generated MaxScript string literals.
    */
    function escapeSourceString source_value =
    (
        escaped_value = substituteString source_value "\\" "\\\\"
        escaped_value = substituteString escaped_value "\"" "\\\""
        escaped_value
        -- return
    ),

    /*
    Ensures only the category rollout chain required by one loaded script exists.
    Categories are created lazily so directories without successfully embedded rollouts never appear as empty host rollouts.
    */
    function ensureGroupRolloutPath group_path =
    (
        if group_path == undefined or group_path == "" then return true
        if script_manager_host_ui == undefined then return false
        if (this.getGroupRollout group_path) != undefined then return true

        parent_path = this.getParentRelativePath group_path
        if parent_path != "" then
        (
            if not(this.ensureGroupRolloutPath parent_path) then return false
        )

        group_name = ""
        available_index = findItem available_group_paths group_path

        if available_index > 0 and available_index <= available_group_names.count then
        (
            group_name = available_group_names[available_index]
        )
        else
        (
            normalized_group_path = substituteString group_path "/" "\\"
            if normalized_group_path.count > 0 and normalized_group_path[normalized_group_path.count] != "\\" then normalized_group_path += "\\"
            group_name = ScriptManagerIntegration.getFolderName normalized_group_path
        )

        if group_name == "" then return false

        group_build_id += 1
        symbol_name = "script_manager_group_" + (group_build_id as string) + "_" + ((group_rollouts.count + 1) as string)
        caption_text = this.escapeSourceString group_name
        handler_path = this.escapeSourceString group_path
        source_text = "rollout " + symbol_name + " \"" + caption_text + "\" width:288 height:36\n(\n"
        source_text += "    subRollout sr_children \"\" pos:[6,6] width:276 height:24\n"
        source_text += "    on " + symbol_name + " rolledUp state do (if script_manager != undefined then script_manager.setGroupRolloutOpen \"" + handler_path + "\" state)\n"
        source_text += ")"

        group_rollout = undefined
        add_ok = false

        try
        (
            execute source_text
            group_rollout = execute symbol_name
            group_open = this.loadGroupOpenState group_path

            if parent_path == "" then
            (
                addSubRollout script_manager_host_ui.sr_tools group_rollout rolledUp:(not group_open)
            )
            else
            (
                parent_rollout = this.getGroupRollout parent_path
                if parent_rollout == undefined then throw ("Parent category rollout not found: " + parent_path)
                addSubRollout parent_rollout.sr_children group_rollout rolledUp:(not group_open)
            )

            add_ok = true
        )
        catch
        (
            format "[Script-Manager] Category rollout creation failed for %: %\n" group_path (getCurrentException())
            add_ok = false
        )

        if not add_ok then return false

        append group_rollouts group_rollout
        append group_rollout_paths group_path
        append group_rollout_symbol_names symbol_name

        true
        -- return
    ),

    /*
    Removes generated category rollouts that no longer contain a successfully embedded script rollout.
    Ancestor categories are retained when a loaded descendant still needs them.
    */
    function pruneEmptyGroupRollouts =
    (
        if script_manager_host_ui == undefined then return false

        required_group_paths = #()

        for loaded_group_path in loaded_rollout_group_paths do
        (
            current_group_path = loaded_group_path

            while current_group_path != "" do
            (
                if (findItem required_group_paths current_group_path) == 0 then append required_group_paths current_group_path
                current_group_path = this.getParentRelativePath current_group_path
            )
        )

        prune_ok = true

        if group_rollouts.count > 0 then
        (
            for group_index = group_rollouts.count to 1 by -1 do
            (
                group_path = group_rollout_paths[group_index]

                if (findItem required_group_paths group_path) == 0 then
                (
                    group_rollout = group_rollouts[group_index]
                    parent_path = this.getParentRelativePath group_path
                    remove_ok = true

                    try
                    (
                        if parent_path == "" then
                        (
                            removeSubRollout script_manager_host_ui.sr_tools group_rollout
                        )
                        else
                        (
                            parent_rollout = this.getGroupRollout parent_path
                            if parent_rollout == undefined then throw ("Parent category rollout not found: " + parent_path)
                            removeSubRollout parent_rollout.sr_children group_rollout
                        )
                    )
                    catch
                    (
                        format "[Script-Manager] Empty category removal failed for %: %\n" group_path (getCurrentException())
                        remove_ok = false
                        prune_ok = false
                    )

                    if remove_ok then
                    (
                        deleteItem group_rollouts group_index
                        deleteItem group_rollout_paths group_index
                        if group_index <= group_rollout_symbol_names.count then deleteItem group_rollout_symbol_names group_index
                    )
                )
            )
        )

        if prune_ok then this.refreshHierarchyLayout force:true
        prune_ok
        -- return
    ),

    /*
    Returns the actual visible height occupied by one rollout inside a subrollout slot.
    The rendered rollout HWND height is preferred because it already includes the native header, border, theme, and DPI scaling.
    */
    function getRolloutVisibleHeight rollout_value =
    (
        rendered_height = 0
        rollout_open = true
        rollout_content_height = 0

        try
        (
            if rollout_value.hwnd != 0 then
            (
                rollout_rect = windows.getWindowPos rollout_value.hwnd
                rendered_height = rollout_rect.h
            )
        )
        catch
        (
            exception_text = getCurrentException()
            rendered_height = 0
        )

        if rendered_height > 0 then return rendered_height

        try
        (
            rollout_open = rollout_value.open
        )
        catch
        (
            exception_text = getCurrentException()
            rollout_open = true
        )

        try
        (
            rollout_content_height = rollout_value.height
        )
        catch
        (
            exception_text = getCurrentException()
            rollout_content_height = 0
        )

        if rollout_open then
        (
            rollout_content_height + rollout_header_height
        )
        else
        (
            rollout_header_height
        )
        -- return
    ),

    /*
    Returns the required height for one nested subrollout slot from all child rollouts currently visible inside it.
    Every child contributes its actual rendered window height, so multiple open rollouts always fit; one extra header allowance remains below the content.
    */
    function getSubRolloutRequiredHeight subrollout_control =
    (
        child_rollouts = #()
        content_height = 0

        try
        (
            child_rollouts = subrollout_control.rollouts
        )
        catch
        (
            exception_text = getCurrentException()
            child_rollouts = #()
        )

        for child_rollout in child_rollouts do
        (
            content_height += this.getRolloutVisibleHeight child_rollout
        )

        required_height = content_height + subrollout_extra_height
        if required_height < rollout_header_height then required_height = rollout_header_height

        required_height
        -- return
    ),

    /*
    Builds a compact signature of rollout open states and content heights.
    The layout watcher uses it to avoid resizing when the hierarchy did not change.
    */
    function getHierarchyLayoutSignature =
    (
        signature_text = (group_rollouts.count as string) + ":" + (loaded_rollouts.count as string)

        for group_rollout in group_rollouts do
        (
            rollout_open = true
            rollout_height = 0

            try
            (
                rollout_open = group_rollout.open
                rollout_height = group_rollout.height
            )
            catch
            (
                exception_text = getCurrentException()
                rollout_open = true
                rollout_height = 0
            )

            signature_text += "|G:" + (rollout_open as string) + ":" + (rollout_height as string)
        )

        for rollout_value in loaded_rollouts do
        (
            rollout_open = true
            rollout_height = 0

            try
            (
                rollout_open = rollout_value.open
                rollout_height = rollout_value.height
            )
            catch
            (
                exception_text = getCurrentException()
                rollout_open = true
                rollout_height = 0
            )

            signature_text += "|T:" + (rollout_open as string) + ":" + (rollout_height as string)
        )

        signature_text
        -- return
    ),

    /*
    Resizes every nested category subrollout slot from the currently visible child rollouts.
    Deepest categories are measured first so parent categories inherit the final child heights.
    */
    function layoutGroupRollouts =
    (
        layout_ok = true

        if group_rollouts.count > 0 then
        (
            for group_index = group_rollouts.count to 1 by -1 do
            (
                group_rollout = group_rollouts[group_index]
                required_height = rollout_header_height

                try
                (
                    required_height = this.getSubRolloutRequiredHeight group_rollout.sr_children
                    group_rollout.sr_children.height = required_height
                    group_rollout.height = required_height + 12
                )
                catch
                (
                    exception_text = getCurrentException()
                    layout_ok = false
                    format "[Script-Manager] Category layout failed: %\n" exception_text
                )
            )
        )

        layout_ok
        -- return
    ),

    /*
    Queues one or more forced hierarchy-layout passes for the following timer ticks.
    Deferred passes let native rollout opening finish before nested subrollout heights are measured again.
    */
    function queueHierarchyLayoutPasses pass_count:1 =
    (
        if pass_count < 1 then pass_count = 1
        if pass_count > hierarchy_layout_pending_passes then hierarchy_layout_pending_passes = pass_count
        true
        -- return
    ),

    /*
    Refreshes nested slot sizing only when rollout open states or content heights changed.
    A detected live change queues one settling pass so first-open native layout can finish before final measurement.
    */
    function refreshHierarchyLayout force:false =
    (
        current_signature = this.getHierarchyLayoutSignature()
        layout_changed = force or current_signature != hierarchy_layout_signature

        if layout_changed then
        (
            this.layoutGroupRollouts()
            hierarchy_layout_signature = this.getHierarchyLayoutSignature()

            if not force then this.queueHierarchyLayoutPasses pass_count:1
        )

        layout_changed
        -- return
    ),

    /*
    Runs one hierarchy-layout watcher tick.
    Pending passes are forced so first-open child heights are remeasured after the native rollout event completes.
    */
    function processHierarchyLayoutTick =
    (
        if is_reloading then return false

        if hierarchy_layout_pending_passes > 0 then
        (
            hierarchy_layout_pending_passes -= 1
            this.refreshHierarchyLayout force:true
        )
        else
        (
            this.refreshHierarchyLayout()
        )

        true
        -- return
    ),

    /*
    Persists one category rollout state and refreshes recursive category sizing.
    Opening or closing queues one deferred pass because native child heights finalize after the rolledUp event.
    */
    function setGroupRolloutOpen group_path open_state =
    (
        this.saveGroupOpenState group_path open_state
        this.refreshHierarchyLayout force:true
        this.queueHierarchyLayoutPasses pass_count:1
        true
        -- return
    ),

    /*
    Collects top-level rollout identifiers declared by one readable script source.
    Returns an Array on a successful read, including #() when no rollout is declared, and undefined when the source cannot be read.
    */
    function getRolloutNames script_path =
    (
        if script_path == undefined or not(doesFileExist script_path) then return undefined

        rollout_names = #()
        file_stream = undefined
        read_ok = true

        try
        (
            file_stream = openFile script_path mode:"rt"

            if file_stream == undefined then
            (
                read_ok = false
            )
            else
            (
                while not(eof file_stream) do
                (
                    source_line = readLine file_stream

                    if source_line != undefined then
                    (
                        line_parts = filterString source_line " \t"

                        if line_parts.count >= 2 then
                        (
                            if line_parts[1] == "rollout" then
                            (
                                rollout_name = line_parts[2]
                                if (findItem rollout_names rollout_name) == 0 then append rollout_names rollout_name
                            )
                        )
                    )
                )

                close file_stream
                file_stream = undefined
            )
        )
        catch
        (
            exception_text = getCurrentException()
            read_ok = false
            format "[Script-Manager] Rollout source read failed: % | %\n" script_path exception_text

            if file_stream != undefined then
            (
                try
                (
                    close file_stream
                )
                catch
                (
                    cleanup_exception_text = getCurrentException()
                )
            )
        )

        if not read_ok then return undefined

        rollout_names
        -- return
    ),

    /*
    Returns rollout values registered by scripts whose registry source_path matches one of the supplied loaded source files.
    This runtime lookup complements source-text rollout discovery so tools that register UI dynamically can still be hosted.
    Each result is #(rollout_value, stable_name).
    */
    function getRegisteredRolloutPairsForSources source_paths =
    (
        normalized_sources = #()
        rollout_pairs = #()

        for source_path in source_paths do
        (
            normalized_source = ScriptManagerIntegration.normalizeFilePath source_path

            if normalized_source != "" and (findItem normalized_sources normalized_source) == 0 then
            (
                append normalized_sources normalized_source
            )
        )

        script_ids = ScriptManagerIntegration.getScriptIds()

        for script_id in script_ids do
        (
            script_data = ScriptManagerIntegration.getScript script_id

            if script_data != undefined and script_data.rollout_value != undefined then
            (
                registered_source = ScriptManagerIntegration.normalizeFilePath script_data.source_path

                if registered_source != "" and (findItem normalized_sources registered_source) > 0 then
                (
                    append rollout_pairs #(script_data.rollout_value, script_id)
                )
            )
        )

        rollout_pairs
        -- return
    ),

    /*
    Converts one stored INI integer to a validated integer value.
    Invalid or missing values return the supplied default.
    */
    function getIniInteger section_name key_name default_value =
    (
        stored_text = getINISetting ini_path section_name key_name
        stored_value = undefined

        if stored_text != "" then
        (
            try
            (
                stored_value = stored_text as integer
            )
            catch
            (
                exception_text = getCurrentException()
                stored_value = undefined
            )
        )

        if stored_value == undefined then default_value else stored_value
        -- return
    ),

    /*
    Converts one stored INI rollout-open value to Boolean.
    Missing values return the supplied default.
    */
    function getIniBoolean section_name key_name default_value =
    (
        stored_text = getINISetting ini_path section_name key_name

        if stored_text == "1" then
        (
            true
        )
        else if stored_text == "0" then
        (
            false
        )
        else
        (
            default_value
        )
        -- return
    ),

    /*
    Converts one supported CUI dock state to the compact INI representation.
    Only left and right docking are valid; every other state is treated as floating.
    */
    function dockStateToText dock_state =
    (
        case dock_state of
        (
            #cui_dock_left: "left"
            #cui_dock_right: "right"
            default: "float"
        )
        -- return
    ),

    /*
    Returns the CUI registration styles allowed by the manager.
    The dialog can dock only on the left or right, while floating and dock handles remain enabled.
    */
    function getDialogBarStyles =
    (
        #(#cui_dock_left, #cui_dock_right, #cui_floatable, #cui_handles)
        -- return
    ),

    /*
    Saves one embedded rollout's expanded or collapsed state.
    */
    function saveRolloutOpenState rollout_value =
    (
        if rollout_value == undefined then return false

        rollout_name = ""
        rollout_open = true

        try
        (
            rollout_name = rollout_value.name
            rollout_open = rollout_value.open
        )
        catch
        (
            exception_text = getCurrentException()
            format "[Script-Manager] Hosted rollout state read failed: %\n" exception_text
            return false
        )

        if rollout_name == "" then return false

        setINISetting ini_path "Rollouts" rollout_name (if rollout_open then "1" else "0") forceUTF16:false
        true
        -- return
    ),

    /*
    Saves expanded or collapsed state for every embedded tool rollout.
    */
    function saveAllRolloutStates =
    (
        save_ok = true

        for rollout_value in loaded_rollouts do
        (
            if not(this.saveRolloutOpenState rollout_value) then save_ok = false
        )

        save_ok
        -- return
    ),

    /*
    Returns the saved expanded state for one rollout identifier.
    Hosted script rollouts are expanded by default.
    */
    function loadRolloutOpenState rollout_name =
    (
        getIniBoolean "Rollouts" rollout_name true
        -- return
    ),

    /*
    Saves dialog position, floating height, dock state, and child rollout states.
    Floating geometry is preserved while the dialog is docked.
    */
    function saveDialogState save_rollouts:true =
    (
        if script_manager_ui == undefined then return false

        save_ok = true

        if save_rollouts then
        (
            if not(this.saveAllRolloutStates()) then save_ok = false
            if not(this.saveAllGroupStates()) then save_ok = false
        )

        loader_rollout_open = preset_rollout_open or options_rollout_open or source_rollout_open or script_rollout_open
        if not(this.saveLoaderOpenState loader_rollout_open) then save_ok = false
        if not(this.savePresetRolloutOpenState preset_rollout_open) then save_ok = false
        if not(this.saveOptionsRolloutOpenState options_rollout_open) then save_ok = false
        if not(this.saveSourceRolloutOpenState source_rollout_open) then save_ok = false
        if not(this.saveShowRolloutOpenState show_rollout_open) then save_ok = false
        if not(this.saveIgnoreRolloutOpenState ignore_rollout_open) then save_ok = false
        if not(this.saveScriptRolloutOpenState script_rollout_open) then save_ok = false

        dock_state = #cui_floatable
        is_registered = false

        try
        (
            is_registered = script_manager_ui.dialogBar
        )
        catch
        (
            exception_text = getCurrentException()
            save_ok = false
            format "[Script-Manager] Dialog-bar state read failed: %\n" exception_text
        )

        if is_registered then
        (
            try
            (
                dock_state = cui.getDockState script_manager_ui
            )
            catch
            (
                exception_text = getCurrentException()
                save_ok = false
                format "[Script-Manager] Dock-state read failed: %\n" exception_text
            )
        )

        setINISetting ini_path "Dialog" "Dock" (this.dockStateToText dock_state) forceUTF16:false

        if dock_state == #cui_floatable then
        (
            saved_position = [(this.getIniInteger "Dialog" "X" 120), (this.getIniInteger "Dialog" "Y" 120)]
            scriptManagerTraceDialogPosition "MAIN" "SAVE-BEFORE-WRITE" script_manager_ui saved_position:saved_position dock_text:"float"
            try
            (
                dialog_position = getDialogPos script_manager_ui
                dialog_size = getDialogSize script_manager_ui

                setINISetting ini_path "Dialog" "X" (dialog_position.x as string) forceUTF16:false
                setINISetting ini_path "Dialog" "Y" (dialog_position.y as string) forceUTF16:false
                setINISetting ini_path "Dialog" "Height" (dialog_size.y as string) forceUTF16:false
            )
            catch
            (
                exception_text = getCurrentException()
                save_ok = false
                format "[Script-Manager] Floating dialog-state save failed: %\n" exception_text
            )
        )

        save_ok
        -- return
    ),

    /*
    Returns validated floating position, height, and dock state loaded from INI.
    Invalid values fall back to usable defaults.
    */
    function loadDialogState =
    (
        position_x = this.getIniInteger "Dialog" "X" 120
        position_y = this.getIniInteger "Dialog" "Y" 120
        dialog_height = this.getIniInteger "Dialog" "Height" 1970
        dock_text = getINISetting ini_path "Dialog" "Dock"

        if dialog_height < 1024 then dialog_height = 1024
        if dialog_height > 2000 then dialog_height = 2000
        if dock_text != "left" and dock_text != "right" then dock_text = "float"

        #([position_x, position_y], dialog_height, dock_text)
        -- return
    ),

    /*
    Applies one saved dock state after the manager has been registered as a dialog bar.
    */
    function applyDockState dock_text =
    (
        if script_manager_ui == undefined then return false

        try
        (
            case dock_text of
            (
                "left": cui.DockDialogBar script_manager_ui #cui_dock_left
                "right": cui.DockDialogBar script_manager_ui #cui_dock_right
                default: cui.FloatDialogBar script_manager_ui
            )
        )
        catch
        (
            exception_text = getCurrentException()
            format "[Script-Manager] Dock-state apply failed: %\n" exception_text
            return false
        )

        true
        -- return
    ),

    /*
    Saves one organizational host-dialog position, height, dock state, and hosted rollout states.
    */
function saveHostDialogState host_path save_rollouts:true =
(
    host_dialog = this.getHostDialog host_path
    if host_dialog == undefined then return false

    save_ok = true

    if save_rollouts then
    (
        if not(this.saveAllRolloutStates()) then save_ok = false
    )

    section_name = this.getHostDialogIniSection host_path
    dock_state = #cui_floatable
    is_registered = false

    try
    (
        is_registered = host_dialog.dialogBar
    )
    catch
    (
        exception_text = getCurrentException()
        save_ok = false
        format "[Script-Manager] Host dialog-bar state read failed for %: %\n" host_path exception_text
    )

    if is_registered then
    (
        try
        (
            dock_state = cui.getDockState host_dialog
        )
        catch
        (
            exception_text = getCurrentException()
            save_ok = false
            format "[Script-Manager] Host dock-state read failed for %: %\n" host_path exception_text
        )
    )

    setINISetting ini_path section_name "Dock" (this.dockStateToText dock_state) forceUTF16:false

    if dock_state == #cui_floatable then
    (
        saved_position = [(this.getIniInteger section_name "X" 468), (this.getIniInteger section_name "Y" 120)]
        scriptManagerTraceDialogPosition host_path "SAVE-BEFORE-WRITE" host_dialog saved_position:saved_position dock_text:"float"
        try
        (
            dialog_position = getDialogPos host_dialog
            dialog_size = getDialogSize host_dialog

            setINISetting ini_path section_name "X" (dialog_position.x as string) forceUTF16:false
            setINISetting ini_path section_name "Y" (dialog_position.y as string) forceUTF16:false
            setINISetting ini_path section_name "Height" (dialog_size.y as string) forceUTF16:false
        )
        catch
        (
            exception_text = getCurrentException()
            save_ok = false
            format "[Script-Manager] Host floating dialog-state save failed for %: %\n" host_path exception_text
        )
    )

    save_ok
    -- return
),

    /*
    Returns validated floating position, height, and dock state for one organizational host dialog.
    */
function loadHostDialogState host_path =
(
    section_name = this.getHostDialogIniSection host_path
    dialog_offset = host_dialogs.count * 24
    position_x = this.getIniInteger section_name "X" (468 + dialog_offset)
    position_y = this.getIniInteger section_name "Y" (120 + dialog_offset)
    dialog_height = this.getIniInteger section_name "Height" 720
    dock_text = getINISetting ini_path section_name "Dock"

    if dialog_height < 300 then dialog_height = 300
    if dialog_height > 2000 then dialog_height = 2000
    if dock_text != "left" and dock_text != "right" then dock_text = "float"

    #([position_x, position_y], dialog_height, dock_text)
    -- return
),

    /*
    Applies one saved dock state to one organizational host dialog.
    */
function applyHostDockState host_path dock_text =
(
    host_dialog = this.getHostDialog host_path
    if host_dialog == undefined then return false

    try
    (
        case dock_text of
        (
            "left": cui.DockDialogBar host_dialog #cui_dock_left
            "right": cui.DockDialogBar host_dialog #cui_dock_right
            default: cui.FloatDialogBar host_dialog
        )
    )
    catch
    (
        exception_text = getCurrentException()
        format "[Script-Manager] Host dock-state apply failed for %: %\n" host_path exception_text
        return false
    )

    true
    -- return
),

    /*
    Updates the loader-only Script-Manager dialog layout.
    PRESETS, OPTIONS, SOURCES, and SCRIPTS are independent; SHOW and IGNORE are nested in OPTIONS.
    Hosted rollout content lives exclusively in generated organizational host dialogs.
    */
    function layoutManager dialog_size =
    (
        if script_manager_ui == undefined then return false

        usable_width = dialog_size.x - 24
        if usable_width < 264 then usable_width = 264

        slot_top = 42
        bottom_action_height = 12

        preset_slot_height = if preset_rollout_open then (preset_rollout_content_height + rollout_header_height) else loader_collapsed_height
        show_slot_height = if show_rollout_open then (show_rollout_content_height + rollout_header_height) else loader_collapsed_height
        ignore_slot_height = if ignore_rollout_open then (ignore_rollout_content_height + rollout_header_height) else loader_collapsed_height
        options_inner_offset = show_slot_height + ignore_slot_height + 8
        options_slot_height = if options_rollout_open then (options_rollout_content_height + options_inner_offset + rollout_header_height) else loader_collapsed_height
        source_slot_height = if source_rollout_open then (source_rollout_content_height + rollout_header_height) else loader_collapsed_height
        script_slot_height = if script_rollout_open then (script_rollout_content_height + rollout_header_height) else loader_collapsed_height
        desired_loader_height = preset_slot_height + options_slot_height + source_slot_height + script_slot_height

        maximum_loader_height = dialog_size.y - slot_top - bottom_action_height
        if maximum_loader_height < (loader_collapsed_height * 4) then maximum_loader_height = loader_collapsed_height * 4
        loader_slot_height = amin desired_loader_height maximum_loader_height

        script_manager_ui.btn_refresh_restart.pos = [12,12]
        script_manager_ui.btn_refresh_restart.width = usable_width
        script_manager_ui.btn_refresh_restart.height = 18

        script_manager_ui.sr_loader.pos = [12, slot_top]
        script_manager_ui.sr_loader.width = usable_width
        script_manager_ui.sr_loader.height = loader_slot_height

        if preset_rollout != undefined then
        (
            preset_rollout.width = usable_width
            preset_rollout.height = preset_rollout_content_height
        )

        if options_rollout != undefined then
        (
            options_rollout.width = usable_width
            options_rollout.height = options_rollout_content_height + options_inner_offset

            options_rollout.sr_show.pos = [0,54]
            options_rollout.sr_show.width = usable_width
            options_rollout.sr_show.height = show_slot_height
            options_rollout.sr_ignore.pos = [0,58 + show_slot_height]
            options_rollout.sr_ignore.width = usable_width
            options_rollout.sr_ignore.height = ignore_slot_height

            root_control = this.getSourceRootPathControl()
            if root_control != undefined then root_control.width = amax 20 (usable_width - 78)

            options_rollout.btn_source_root_browse.pos = [usable_width - 66, 24]

        )

        if source_rollout != undefined then
        (
            source_rollout.width = usable_width
            source_rollout.height = source_rollout_content_height

            source_tree = this.getSourceTreeControl()
            if source_tree != undefined then
            (
                source_tree.Width = amax 20 (usable_width - 12)
                source_tree.Height = 512
            )
        )

        if show_rollout != undefined then
        (
            show_rollout.width = usable_width
            show_rollout.height = show_rollout_content_height
        )

        if ignore_rollout != undefined then
        (
            ignore_rollout.width = usable_width
            ignore_rollout.height = ignore_rollout_content_height

            script_ignore_control = this.getScriptIgnoreMaskControl()
            if script_ignore_control != undefined then script_ignore_control.width = amax 20 (usable_width - 12)
        )

        if script_rollout != undefined then
        (
            script_rollout.width = usable_width
            script_rollout.height = script_rollout_content_height

            script_rollout.edt_scripts_filter.width = amax 20 (usable_width - 64)

            tree_control = this.getScriptTreeControl()
            if tree_control != undefined then
            (
                tree_control.Width = amax 20 (usable_width - 12)
                tree_control.Height = 1032
            )
        )

        true
        -- return
    ),

    /*
    Applies the canonical .NET tool title button appearance.
    */
function styleToolTitleButton button_control =
(
    if button_control == undefined then return false

    color_type = dotNetClass "System.Drawing.Color"
    flat_style_type = dotNetClass "System.Windows.Forms.FlatStyle"
    font_style_type = dotNetClass "System.Drawing.FontStyle"
    graphics_unit_type = dotNetClass "System.Drawing.GraphicsUnit"
    dark_color = color_type.FromArgb 45 45 48
    title_color = color_type.FromArgb 62 158 255

    button_control.FlatStyle = flat_style_type.Flat
    button_control.FlatAppearance.BorderSize = 0
    button_control.FlatAppearance.BorderColor = dark_color
    button_control.FlatAppearance.MouseOverBackColor = dark_color
    button_control.FlatAppearance.MouseDownBackColor = dark_color
    button_control.UseVisualStyleBackColor = false
    button_control.BackColor = dark_color
    button_control.ForeColor = title_color
    button_control.TabStop = false
    button_control.Font = dotNetObject "System.Drawing.Font" "Segoe UI" 14.0 font_style_type.Bold graphics_unit_type.Pixel

    true
    -- return
),

    /*
    Applies the canonical tool title button appearance to generated host dialogs.
    */
function styleHostDialogTitleButton button_control =
(
    this.styleToolTitleButton button_control
    -- return
),

    /*
    Sizes one organizational host dialog and its direct tool-rollout slot.
    */
function layoutHostDialog host_path dialog_size =
(
    host_dialog = this.getHostDialog host_path
    if host_dialog == undefined then return false

    usable_width = dialog_size.x - 24
    if usable_width < 312 then usable_width = 312

    title_height = 24
    title_top = 12
    tools_top = 48
    tools_height = dialog_size.y - 60
    if tools_height < rollout_header_height then tools_height = rollout_header_height

    host_dialog.btn_dialog_title.pos = [12,title_top]
    host_dialog.btn_dialog_title.width = usable_width
    host_dialog.btn_dialog_title.height = title_height

    host_dialog.sr_tools.pos = [12,tools_top]
    host_dialog.sr_tools.width = usable_width
    host_dialog.sr_tools.height = tools_height

    true
    -- return
),

/*
Clears only the embedded rollouts owned by one organizational host dialog.
The host dialog itself stays alive so its dock/position state and interactive title button remain intact.
*/
function clearHostDialogRollouts host_path =
(
    host_dialog = this.getHostDialog host_path
    if host_dialog == undefined then return false

    cleanup_ok = this.saveAllRolloutStates()

    for rollout_index = loaded_rollout_group_paths.count to 1 by -1 do
    (
        if loaded_rollout_group_paths[rollout_index] == host_path then
        (
            rollout_removed = true

            try
            (
                removeSubRollout host_dialog.sr_tools loaded_rollouts[rollout_index]
            )
            catch
            (
                exception_text = getCurrentException()
                rollout_removed = false
                cleanup_ok = false
                format "[Script-Manager] Host-only rollout removal failed for %: %\n" host_path exception_text
            )

            if rollout_removed then
            (
                if rollout_index <= loaded_rollouts.count then deleteItem loaded_rollouts rollout_index
                if rollout_index <= loaded_rollout_names.count then deleteItem loaded_rollout_names rollout_index
                deleteItem loaded_rollout_group_paths rollout_index
            )
        )
    )

    if cleanup_ok then this.clearHostScriptTracking host_path

    cleanup_ok
    -- return
),

/*
Loads or hard reloads only the currently configured HOST scripts assigned to one batch dialog.
An existing host dialog is fully destroyed first so docked dialog-bar state cannot interfere with recreation.
Other HOST dialogs and DIRECT scripts are untouched.
*/
function loadConfiguredHostDialogScripts host_path =
(
    if is_reloading then return false
    if host_path == undefined or host_path == "" then return false

    script_paths = this.getConfiguredHostScriptPaths host_path
    if script_paths.count == 0 then
    (
        format "[Script-Manager] No configured HOST scripts found for dialog: %\n" host_path
        return false
    )

    is_reloading = true
    load_ok = true

    try
    (
        host_dialog = this.getHostDialog host_path

        if host_dialog != undefined then
        (
            if not(this.destroyHostDialog host_path clear_rollouts:true) then throw "destroyHostDialog returned false"
        )
        else
        (
            if not(this.clearHostScriptTracking host_path) then throw "clearHostScriptTracking returned false"
        )

        for script_path in script_paths do
        (
            if doesFileExist script_path then
            (
                script_name = getFilenameFile script_path
                script_key = this.getScriptKey script_path
                script_directory = ScriptManagerIntegration.normalizeDirectoryPath (getFilenamePath script_path)
                group_path = this.getRelativeDirectoryPath script_directory

                result_data = this.loadManagedScript \
                    script_path \
                    script_name:script_name \
                    script_key:script_key \
                    group_path:group_path \
                    embed_rollouts:true

                if not result_data[1] then load_ok = false
            )
            else
            (
                load_ok = false
                format "[Script-Manager] Dialog load skipped missing script: %\n" script_path
            )
        )

        if not(this.pruneEmptyHostDialogs()) then load_ok = false
        if not(this.syncScriptTreeChecks()) then load_ok = false

        refreshed_host = this.getHostDialog host_path
        if refreshed_host != undefined then
        (
            if not(this.layoutHostDialog host_path [refreshed_host.width, refreshed_host.height]) then load_ok = false
        )
    )
    catch
    (
        exception_text = getCurrentException()
        load_ok = false
        format "[Script-Manager] Batch dialog load failed for %: %\n" host_path exception_text
    )

    is_reloading = false
    load_ok
    -- return
),

/*
Loads or reloads the batch dialog represented by the selected checked SOURCES item.
*/
function loadSelectedSourceDialog =
(
    host_path = this.getSelectedSourceDialogPath()

    if host_path == "" then
    (
        format "[Script-Manager] Selected SOURCES item does not define a batch dialog.\n"
        return false
    )

    this.loadConfiguredHostDialogScripts host_path
    -- return
),

/*
Opens one clicked SCRIPTS folder as a shared rollout dialog containing all visible nested scripts.
This one-time load forces hosted execution but does not modify saved OFF/HOST/DIRECT modes or other batch settings.
*/
function openScriptTreeGroup tree_node =
(
    if is_reloading then return false

    group_data = this.getScriptTreeGroupLoadData tree_node
    host_path = group_data[1]
    script_paths = group_data[2]

    if host_path == "" or script_paths.count == 0 then
    (
        format "[Script-Manager] OPEN GROUP | no visible scripts in selected folder.\n"
        return false
    )

    is_reloading = true
    load_ok = true

    try
    (
        existing_host = this.getHostDialog host_path
        if existing_host != undefined then
        (
            if not(this.destroyHostDialog host_path clear_rollouts:true) then throw "destroyHostDialog returned false"
        )
        else
        (
            if not(this.clearHostScriptTracking host_path) then throw "clearHostScriptTracking returned false"
        )

        for script_path in script_paths do
        (
            if doesFileExist script_path then
            (
                script_name = getFilenameFile script_path
                script_key = this.getScriptKey script_path
                script_directory = ScriptManagerIntegration.normalizeDirectoryPath (getFilenamePath script_path)
                group_path = this.getRelativeDirectoryPath script_directory

                result_data = this.loadManagedScript \
                    script_path \
                    script_name:script_name \
                    script_key:script_key \
                    group_path:group_path \
                    embed_rollouts:true \
                    host_path_override:host_path

                if not result_data[1] then load_ok = false
            )
            else
            (
                load_ok = false
                format "[Script-Manager] OPEN GROUP | script file missing: %\n" script_path
            )
        )

        if not(this.pruneEmptyHostDialogs()) then load_ok = false
        if not(this.syncScriptTreeChecks()) then load_ok = false

        refreshed_host = this.getHostDialog host_path
        if refreshed_host != undefined then
        (
            if not(this.layoutHostDialog host_path [refreshed_host.width, refreshed_host.height]) then load_ok = false
        )
    )
    catch
    (
        exception_text = getCurrentException()
        load_ok = false
        format "[Script-Manager] OPEN GROUP failed for %: %\n" host_path exception_text
    )

    is_reloading = false
    load_ok
    -- return
),

/*
Opens the currently selected SCRIPTS folder and every visible nested script in one shared dialog.
Script rows do not open groups; their double-click and LOAD SCRIPT behavior is unchanged.
*/
function openSelectedScriptTreeGroup =
(
    tree_control = this.getScriptTreeControl()
    if tree_control == undefined or tree_control.SelectedNode == undefined then return false

    this.openScriptTreeGroup tree_control.SelectedNode
    -- return
),

/*
Reloads only the HOST-mode scripts currently represented by one organizational host dialog.
The old host dialog is fully destroyed before scripts are reloaded so docked dialog-bar state is reset safely.
This is the LMB action of the dialog's .NET title button and never touches other dialogs or DIRECT scripts.
*/
function reloadHostDialogScripts host_path =
(
    if is_reloading then return false
    if host_path == undefined or host_path == "" then return false

    host_dialog = this.getHostDialog host_path
    if host_dialog == undefined then return false

    script_paths = this.getHostScriptPaths host_path
    if script_paths.count == 0 then return true

    is_reloading = true
    reload_ok = true

    try
    (
        if not(this.destroyHostDialog host_path clear_rollouts:true) then throw "destroyHostDialog returned false"

        for script_path in script_paths do
        (
            if doesFileExist script_path then
            (
                script_name = getFilenameFile script_path
                script_key = this.getScriptKey script_path
                script_directory = ScriptManagerIntegration.normalizeDirectoryPath (getFilenamePath script_path)
                group_path = this.getRelativeDirectoryPath script_directory

                result_data = this.loadManagedScript \
                    script_path \
                    script_name:script_name \
                    script_key:script_key \
                    group_path:group_path \
                    embed_rollouts:true \
                    host_path_override:host_path

                if not result_data[1] then reload_ok = false
            )
            else
            (
                reload_ok = false
                format "[Script-Manager] Host reload skipped missing script: %\n" script_path
            )
        )

        if not(this.pruneEmptyHostDialogs()) then reload_ok = false

        refreshed_host = this.getHostDialog host_path
        if refreshed_host != undefined then
        (
            if not(this.layoutHostDialog host_path [refreshed_host.width, refreshed_host.height]) then reload_ok = false
        )
    )
    catch
    (
        exception_text = getCurrentException()
        reload_ok = false
        format "[Script-Manager] Host dialog reload failed for %: %\n" host_path exception_text
    )

    is_reloading = false
    reload_ok
    -- return
),

    /*
    Removes currently embedded tool rollouts from their organizational host dialogs.
    Rollout expanded states are saved before removal, and failed removals remain tracked for a later retry.
    */
function clearLoadedRollouts =
(
    rollout_state_save_ok = this.saveAllRolloutStates()
    cleanup_ok = true

    if loaded_rollouts.count > 0 then
    (
        for rollout_index = loaded_rollouts.count to 1 by -1 do
        (
            rollout_value = loaded_rollouts[rollout_index]
            host_path = if rollout_index <= loaded_rollout_group_paths.count then loaded_rollout_group_paths[rollout_index] else ""
            host_dialog = this.getHostDialog host_path
            rollout_removed = true

            if host_dialog == undefined then
            (
                rollout_removed = false
                format "[Script-Manager] Missing host dialog while removing rollout: %\n" host_path
            )
            else
            (
                try
                (
                    removeSubRollout host_dialog.sr_tools rollout_value
                )
                catch
                (
                    exception_text = getCurrentException()
                    rollout_removed = false
                    format "[Script-Manager] Hosted rollout removal failed: %\n" exception_text
                )
            )

            if rollout_removed then
            (
                deleteItem loaded_rollouts rollout_index
                if rollout_index <= loaded_rollout_names.count then deleteItem loaded_rollout_names rollout_index
                if rollout_index <= loaded_rollout_group_paths.count then deleteItem loaded_rollout_group_paths rollout_index
            )
            else
            (
                cleanup_ok = false
            )
        )
    )

    if cleanup_ok then
    (
        if not(this.destroyAllHostDialogs clear_rollouts:false) then cleanup_ok = false
    )

    if cleanup_ok then
    (
        loaded_script_paths = #()
        loaded_script_names = #()
        loaded_script_keys = #()
        loaded_host_script_paths = #()
        loaded_host_script_dialog_paths = #()
        hierarchy_layout_signature = ""
    )

    cleanup_ok and rollout_state_save_ok
    -- return
),

    /*
    Resolves one rollout identifier and returns #(success, rollout_value, error_text).
    A missing or invalid rollout is an explicit failure instead of a legitimate undefined value.
    */
    function getRolloutValue rollout_name =
    (
        if rollout_name == undefined or rollout_name == "" then return #(false, undefined, "Rollout identifier is empty.")

        rollout_value = undefined
        resolution_error = undefined

        try
        (
            rollout_value = execute rollout_name
        )
        catch
        (
            resolution_error = getCurrentException()
        )

        if resolution_error != undefined then return #(false, undefined, resolution_error)
        if rollout_value == undefined then return #(false, undefined, "Rollout value is undefined: " + rollout_name)

        #(true, rollout_value, undefined)
        -- return
    ),

    /*
    Closes already-existing standalone rollout instances for one script before an embedded reload redefines their globals.
    Both source-declared rollouts and registry-owned rollouts are checked so stale standalone windows cannot survive beside the new hosted rollout.
    */
    function closeExistingStandaloneRolloutsForSources source_paths rollout_names =
    (
        rollout_values = #()
        close_ok = true

        for rollout_name in rollout_names do
        (
            rollout_result = this.getRolloutValue rollout_name

            if rollout_result[1] then
            (
                rollout_value = rollout_result[2]

                if rollout_value != undefined and (findItem rollout_values rollout_value) == 0 then
                (
                    append rollout_values rollout_value
                )
            )
        )

        registered_pairs = this.getRegisteredRolloutPairsForSources source_paths

        for registered_pair in registered_pairs do
        (
            if registered_pair.count >= 1 then
            (
                rollout_value = registered_pair[1]

                if rollout_value != undefined and (findItem rollout_values rollout_value) == 0 then
                (
                    append rollout_values rollout_value
                )
            )
        )

        for rollout_value in rollout_values do
        (
            if this.isStandaloneRolloutOpen rollout_value then
            (
                if not(this.closeStandaloneRollout rollout_value) then close_ok = false
            )
        )

        close_ok
        -- return
    ),

    /*
    Closes a tool rollout's standalone dialog so it can be embedded safely.
    Registered dialog bars are unregistered first, and a failed close is reported as failure.
    */
    function closeStandaloneRollout rollout_value =
    (
        if rollout_value == undefined then return false

        is_in_dialog = false

        try
        (
            is_in_dialog = rollout_value.inDialog
        )
        catch
        (
            exception_text = getCurrentException()
            format "[Script-Manager] Could not query rollout dialog state: %\n" exception_text
            return false
        )

        if not is_in_dialog then return true

        is_dialog_bar = false

        try
        (
            is_dialog_bar = rollout_value.dialogBar
        )
        catch
        (
            exception_text = getCurrentException()
            format "[Script-Manager] Could not query rollout dialog-bar state: %\n" exception_text
            return false
        )

        if is_dialog_bar then
        (
            try
            (
                cui.UnRegisterDialogBar rollout_value
            )
            catch
            (
                exception_text = getCurrentException()
                format "[Script-Manager] Could not unregister standalone rollout: %\n" exception_text
                return false
            )
        )

        try
        (
            destroyDialog rollout_value
        )
        catch
        (
            exception_text = getCurrentException()
            format "[Script-Manager] Could not close standalone rollout: %\n" exception_text
            return false
        )

        true
        -- return
    ),

    /*
    Records one successfully executed manager script after its complete load/embed contract has succeeded.
    Failure paths must never call this helper.
    */
    function recordLoadedScript script_path companion_ui_path:"" script_name:"" script_key:"" =
    (
        if script_path == undefined or script_path == "" then return false

        if (findItem loaded_script_paths script_path) == 0 then append loaded_script_paths script_path
        if companion_ui_path != "" and (findItem loaded_script_paths companion_ui_path) == 0 then append loaded_script_paths companion_ui_path
        if script_name != "" and (findItem loaded_script_names script_name) == 0 then append loaded_script_names script_name
        if script_key != "" and (findItem loaded_script_keys script_key) == 0 then append loaded_script_keys script_key

        true
        -- return
    ),

    /*
    Loads one current backend script and an optional sibling <BackendName>-UI.ms companion.
    Hosted mode embeds declared rollouts, optionally forcing a chosen shared dialog without changing stored script modes.
    Direct mode fileIns only the selected script in #standalone and never adds rollouts to shared dialogs.
    */
function loadManagedScript script_path script_name:"" script_key:"" group_path:"" embed_rollouts:true host_path_override:"" rethrow_exception:false =
(
    if debug_logging then format "[Script-Manager] LOAD PATH: %\n" script_path

    if not(this.isSupportedScriptPath script_path) or not(doesFileExist script_path) then return #(false, 0, "Script not found or unsupported.")

    extension_text = toLower (getFilenameType script_path)
    rollout_names = #()
    companion_ui_path = ""
    companion_ui_exists = false

    if extension_text == ".ms" then
    (
        companion_ui_path = getFilenamePath script_path + getFilenameFile script_path + "-UI.ms"
        companion_ui_exists = doesFileExist companion_ui_path
    )

    if not embed_rollouts then
    (
        integration_result = ScriptManagerIntegration.loadScript script_path runtime_mode:#standalone quiet:true rethrow_exception:rethrow_exception

        if not integration_result[1] then
        (
            error_text = integration_result[2] as string
            format "[Script-Manager] DIRECT FAILED: % | %\n" script_path error_text
            return #(false, 0, error_text)
        )

        loaded_state_ok = this.recordLoadedScript script_path script_name:script_name script_key:script_key
        if not loaded_state_ok then return #(false, 0, "Could not record successful direct-run script state.")

        if debug_logging then format "[Script-Manager] Direct run: %\n" script_path
        return #(true, 0, undefined)
    )

    if extension_text != ".mse" then
    (
        rollout_names = this.getRolloutNames script_path
        if rollout_names == undefined then return #(false, 0, "Could not read rollout declarations: " + script_path)
    )

    if companion_ui_exists then
    (
        companion_rollout_names = this.getRolloutNames companion_ui_path
        if companion_rollout_names == undefined then return #(false, 0, "Could not read rollout declarations: " + companion_ui_path)

        for companion_rollout_name in companion_rollout_names do
        (
            if (findItem rollout_names companion_rollout_name) == 0 then append rollout_names companion_rollout_name
        )
    )

    loaded_source_paths = #(script_path)
    if companion_ui_exists then append loaded_source_paths companion_ui_path

    if not(this.closeExistingStandaloneRolloutsForSources loaded_source_paths rollout_names) then
    (
        error_text = "Could not close an existing standalone rollout before embedded load: " + script_path
        format "[Script-Manager] EMBED FAILED: % | %\n" script_path error_text
        return #(false, 0, error_text)
    )

    integration_result = ScriptManagerIntegration.loadScript script_path runtime_mode:#embedded quiet:true

    if not integration_result[1] then
    (
        error_text = integration_result[2] as string
        format "[Script-Manager] FAILED: % | %\n" script_path error_text
        return #(false, 0, error_text)
    )

    if companion_ui_exists then
    (
        if debug_logging then format "[Script-Manager] UI COMPANION: %\n" companion_ui_path
        companion_result = ScriptManagerIntegration.loadScript companion_ui_path runtime_mode:#embedded quiet:true

        if not companion_result[1] then
        (
            error_text = companion_result[2] as string
            format "[Script-Manager] FAILED: % | %\n" companion_ui_path error_text
            return #(false, 0, error_text)
        )
    )

    resolved_rollouts = #()
    resolved_rollout_names = #()
    resolution_errors = #()

    for rollout_name in rollout_names do
    (
        rollout_result = this.getRolloutValue rollout_name

        if rollout_result[1] then
        (
            rollout_value = rollout_result[2]

            if (findItem resolved_rollouts rollout_value) == 0 then
            (
                append resolved_rollouts rollout_value
                append resolved_rollout_names rollout_name
            )
        )
        else
        (
            append resolution_errors rollout_result[3]
        )
    )

    registered_rollout_pairs = this.getRegisteredRolloutPairsForSources loaded_source_paths

    for registered_pair in registered_rollout_pairs do
    (
        registered_rollout = registered_pair[1]
        registered_name = registered_pair[2]

        if registered_rollout != undefined and (findItem resolved_rollouts registered_rollout) == 0 then
        (
            append resolved_rollouts registered_rollout
            append resolved_rollout_names registered_name
        )
    )

    if resolved_rollouts.count == 0 then
    (
        if rollout_names.count > 0 and resolution_errors.count > 0 then
        (
            error_text = "Declared rollout could not be resolved after load: " + (resolution_errors[1] as string)
            format "[Script-Manager] EMBED FAILED: % | %\n" script_path error_text
            return #(false, 0, error_text)
        )

        loaded_state_ok = this.recordLoadedScript script_path companion_ui_path:(if companion_ui_exists then companion_ui_path else "") script_name:script_name script_key:script_key
        if not loaded_state_ok then return #(false, 0, "Could not record successful script state.")

        if debug_logging then format "[Script-Manager] Executed: % | rollouts:0\n" script_path
        return #(true, 0, undefined)
    )

    if registered_rollout_pairs.count == 0 and resolution_errors.count > 0 then
    (
        error_text = "Not every declared rollout resolved after load: " + (resolution_errors[1] as string)
        format "[Script-Manager] EMBED FAILED: % | %\n" script_path error_text
        return #(false, 0, error_text)
    )

    host_path = if host_path_override != "" then host_path_override else this.getBatchDialogPathForScript script_path

    if not(this.ensureHostDialog host_path) then
    (
        error_text = "Could not create host dialog: " + host_path
        format "[Script-Manager] %\n" error_text
        return #(false, 0, error_text)
    )

    host_dialog = this.getHostDialog host_path
    if host_dialog == undefined then return #(false, 0, "Host dialog is unavailable: " + host_path)

    target_slot = host_dialog.sr_tools
    embedded_rollouts = #()
    embedded_rollout_names = #()
    embed_error = undefined

    for rollout_index = 1 to resolved_rollouts.count while embed_error == undefined do
    (
        rollout_value = resolved_rollouts[rollout_index]
        rollout_name = resolved_rollout_names[rollout_index]

        if not(this.closeStandaloneRollout rollout_value) then
        (
            embed_error = "Could not close standalone rollout before embedding: " + rollout_name
        )
        else
        (
            rollout_open = this.loadRolloutOpenState rollout_name

            try
            (
                addSubRollout target_slot rollout_value rolledUp:(not rollout_open)
                append embedded_rollouts rollout_value
                append embedded_rollout_names rollout_name
            )
            catch
            (
                embed_error = getCurrentException()
            )
        )
    )

    if embed_error != undefined or embedded_rollouts.count != resolved_rollouts.count then
    (
        rollback_ok = true

        if embedded_rollouts.count > 0 then
        (
            for rollout_index = embedded_rollouts.count to 1 by -1 do
            (
                try
                (
                    removeSubRollout target_slot embedded_rollouts[rollout_index]
                )
                catch
                (
                    rollback_exception_text = getCurrentException()
                    rollback_ok = false
                    format "[Script-Manager] Rollback removal failed: %\n" rollback_exception_text
                )
            )
        )

        if embed_error == undefined then embed_error = "Not every resolved rollout was embedded."
        if not rollback_ok then embed_error += " Partial embedding rollback also failed."

        if not(this.pruneEmptyHostDialogs()) then
        (
            format "[Script-Manager] Empty host cleanup failed after embed failure: %\n" script_path
        )

        format "[Script-Manager] EMBED FAILED: % | %\n" script_path embed_error
        return #(false, 0, embed_error)
    )

    for rollout_index = 1 to embedded_rollouts.count do
    (
        append loaded_rollouts embedded_rollouts[rollout_index]
        append loaded_rollout_names embedded_rollout_names[rollout_index]
        append loaded_rollout_group_paths host_path
    )

    loaded_state_ok = this.recordLoadedScript script_path companion_ui_path:(if companion_ui_exists then companion_ui_path else "") script_name:script_name script_key:script_key
    if not loaded_state_ok then return #(false, 0, "Could not record successful script state.")

    if not(this.trackHostScript script_path host_path) then
    (
        format "[Script-Manager] Could not track hosted script for dialog: % | %\n" host_path script_path
    )

    if not(this.layoutHostDialog host_path [host_dialog.width, host_dialog.height]) then
    (
        format "[Script-Manager] Host layout refresh failed for %\n" host_path
    )

    embedded_count = embedded_rollouts.count
    if debug_logging then format "[Script-Manager] Loaded: % | host:% | rollouts:%\n" script_path host_path embedded_count

    #(true, embedded_count, undefined)
    -- return
),

    /*
    Prepares loader state before configured scripts are loaded into hosted or direct-run modes.
    */
function prepareScriptHost =
(
    tree_sync_ok = this.syncScriptTreeChecks()
    tree_sync_ok
    -- return
),

    /*
    Rediscovers supported scripts and rebuilds the script browser/host without auto-executing discovered files.
    Any failed required stage makes the complete reload return false.
    */
    /*
    Loads every non-skipped script from the current discovered source set according to its persisted tri-state mode.
    Returns #(all_succeeded, loaded_script_count, embedded_rollout_count, failed_script_count).
    */
function loadEnabledScripts =
(
    loaded_count = 0
    rollout_count = 0
    failed_count = 0

    script_paths = this.getDisplayedScriptPaths()

    if script_paths.count == 0 then
    (
        for script_path in available_script_paths do append script_paths script_path
    )

    for script_path in script_paths do
    (
        script_key = this.getScriptKey script_path
        load_mode = this.getScriptLoadMode script_key

        if load_mode != #skip then
        (
            script_name = getFilenameFile script_path
            script_directory = ScriptManagerIntegration.normalizeDirectoryPath (getFilenamePath script_path)
            group_path = this.getRelativeDirectoryPath script_directory

            result_data = this.loadManagedScript \
                script_path \
                script_name:script_name \
                script_key:script_key \
                group_path:group_path \
                embed_rollouts:(load_mode == #host)

            if result_data[1] then
            (
                loaded_count += 1
                rollout_count += result_data[2]
            )
            else
            (
                failed_count += 1
            )
        )
    )

    if not(this.pruneEmptyHostDialogs()) then failed_count += 1

    #(failed_count == 0, loaded_count, rollout_count, failed_count)
    -- return
),

    /*
    Soft-updates the configured script set without touching scripts that are already running.
    Closed standalone dialogs and closed HOST batches are loaded again; scripts without detectable UI are loaded only once per manager session.
    */
function updateScripts =
(
    if is_reloading then return false
    if root_directory == "" then return false
    if script_manager_ui == undefined then return false

    is_reloading = true
    update_succeeded = true
    failed_count = 0

    try
    (
        if not(this.prepareScriptHost()) then throw "prepareScriptHost returned false"

        script_paths = this.getDisplayedScriptPaths()
        if script_paths.count == 0 then
        (
            for script_path in available_script_paths do append script_paths script_path
        )

        for script_path in script_paths do
        (
            script_key = this.getScriptKey script_path
            load_mode = this.getScriptLoadMode script_key

            if load_mode != #skip then
            (
                if not(this.isManagedScriptRunning script_path) then
                (
                    script_name = getFilenameFile script_path
                    script_directory = ScriptManagerIntegration.normalizeDirectoryPath (getFilenamePath script_path)
                    group_path = this.getRelativeDirectoryPath script_directory

                    result_data = this.loadManagedScript \
                        script_path \
                        script_name:script_name \
                        script_key:script_key \
                        group_path:group_path \
                        embed_rollouts:(load_mode == #host)

                    if not result_data[1] then failed_count += 1
                )
            )
        )

        if not(this.pruneEmptyHostDialogs()) then failed_count += 1
        if not(this.syncScriptTreeChecks()) then failed_count += 1
        if not(this.updateVersionLabel()) then throw "updateVersionLabel returned false"
        if not(this.layoutManager [script_manager_ui.width, script_manager_ui.height]) then throw "layoutManager returned false"

        update_succeeded = failed_count == 0
    )
    catch
    (
        exception_text = getCurrentException()
        update_succeeded = false
        format "[Script-Manager] UPDATE SCRIPTS FAILED: %\n" exception_text
    )

    is_reloading = false
    update_succeeded
    -- return
),

    /*
    Hard-reloads the persisted tri-state script set.
    Existing manager-hosted rollouts are cleared first, then every configured script is executed again.
    */
function loadScripts =
(
    if is_reloading then return false
    if root_directory == "" then return false
    if script_manager_ui == undefined then return false

    is_reloading = true
    load_succeeded = true
    load_summary = #(true, 0, 0, 0)

    try
    (
        if debug_logging then format "[Script-Manager] LOAD STAGE: clear hosted rollouts\n"
        if not(this.clearLoadedRollouts()) then throw "clearLoadedRollouts returned false"

        if debug_logging then format "[Script-Manager] LOAD STAGE: prepare script state\n"
        if not(this.prepareScriptHost()) then throw "prepareScriptHost returned false"

        if debug_logging then format "[Script-Manager] LOAD STAGE: apply configured scripts\n"
        load_summary = this.loadEnabledScripts()
        if not load_summary[1] then load_succeeded = false

        if not(this.updateVersionLabel()) then throw "updateVersionLabel returned false"
        if not(this.layoutManager [script_manager_ui.width, script_manager_ui.height]) then throw "layoutManager returned false"
    )
    catch
    (
        exception_text = getCurrentException()
        load_succeeded = false
        format "[Script-Manager] LOAD SCRIPTS FAILED: %\n" exception_text
    )

    is_reloading = false
    load_succeeded
    -- return
),

    /*
    Rescans enabled sources and rebuilds the loader trees without executing discovered scripts.
    Configured script modes are applied only by LOAD SCRIPTS.
    */
function reloadScripts =
(
    if is_reloading then return false
    if script_manager_ui == undefined then return false

    this.loadSourceRootDirectory()
    if root_directory == "" then return false

    is_reloading = true
    reload_succeeded = true

    try
    (
        if debug_logging then format "[Script-Manager] RELOAD STAGE: restore options and filters\n"
        this.loadShowVersionedFiles()
        this.loadShowCleanScriptsOnly()
        this.loadCollapseScriptDirs()
        this.loadScriptIgnoreMask()

        if debug_logging then format "[Script-Manager] RELOAD STAGE: discover sources\n"
        if not(this.discoverSources()) then throw "discoverSources returned false"
        if not(this.initializeSourceSelection()) then throw "initializeSourceSelection returned false"

        if debug_logging then format "[Script-Manager] RELOAD STAGE: discover scripts\n"
        if not(this.discoverScripts()) then throw "discoverScripts returned false"

        if debug_logging then format "[Script-Manager] RELOAD STAGE: build loader\n"
        if not(this.buildLoaderRollout()) then throw "buildLoaderRollout returned false"

        if debug_logging then format "[Script-Manager] RELOAD STAGE: synchronize loader state\n"
        if not(this.prepareScriptHost()) then throw "prepareScriptHost returned false"

        if not(this.updateVersionLabel()) then throw "updateVersionLabel returned false"
        if not(this.layoutManager [script_manager_ui.width, script_manager_ui.height]) then throw "layoutManager returned false"

    )
    catch
    (
        exception_text = getCurrentException()
        reload_succeeded = false
        format "[Script-Manager] RELOAD FAILED: %\n" exception_text
    )

    is_reloading = false
    reload_succeeded
    -- return
),

    /*
    Compatibility wrapper for the previous manager API name.
    */
    function reloadTools =
    (
        this.reloadScripts()
        -- return
    ),

    /*
    Keeps the manager project-version registration synchronized.
    The visible version is carried by the main dialog title; the redundant top labels were removed.
    */
function updateVersionLabel =
(
    if script_manager_ui == undefined then return false

    this.registerProjectVersion()
    true
    -- return
),

    /*
    Clears manager-side references to hosted rollouts, groups, and loaded-session script state.
    */
function resetHostedStateTracking =
(
    loaded_rollouts = #()
    loaded_rollout_names = #()
    loaded_rollout_group_paths = #()
    loaded_script_paths = #()
    loaded_script_names = #()
    loaded_script_keys = #()
    group_rollouts = #()
    group_rollout_paths = #()
    group_rollout_symbol_names = #()
    host_dialogs = #()
    host_dialog_paths = #()
    host_dialog_symbol_names = #()
    loaded_host_script_paths = #()
    loaded_host_script_dialog_paths = #()
    hierarchy_layout_signature = ""
    hierarchy_layout_pending_passes = 0
    true
    -- return
),

    /*
    Handles a user-initiated close of one organizational host dialog without retaining stale rollout references.
    */
function handleHostDialogClosed host_path =
(
    if is_destroying_host then return true

    host_dialog = this.getHostDialog host_path
    if host_dialog != undefined then this.saveHostDialogState host_path

    for rollout_index = loaded_rollout_group_paths.count to 1 by -1 do
    (
        if loaded_rollout_group_paths[rollout_index] == host_path then
        (
            if rollout_index <= loaded_rollouts.count then deleteItem loaded_rollouts rollout_index
            if rollout_index <= loaded_rollout_names.count then deleteItem loaded_rollout_names rollout_index
            deleteItem loaded_rollout_group_paths rollout_index
        )
    )

    host_index = findItem host_dialog_paths host_path
    if host_index > 0 then
    (
        if host_index <= host_dialogs.count then deleteItem host_dialogs host_index
        deleteItem host_dialog_paths host_index
        if host_index <= host_dialog_symbol_names.count then deleteItem host_dialog_symbol_names host_index
    )

    this.clearHostScriptTracking host_path

    true
    -- return
),

    /*
    Destroys one organizational host dialog safely and optionally removes its hosted tool rollouts first.
    */
function destroyHostDialog host_path clear_rollouts:true =
(
    host_dialog = this.getHostDialog host_path
    if host_dialog == undefined then return true

    cleanup_ok = true
    if not(this.saveHostDialogState host_path) then cleanup_ok = false
    is_destroying_host = true

    if clear_rollouts then
    (
        for rollout_index = loaded_rollout_group_paths.count to 1 by -1 do
        (
            if loaded_rollout_group_paths[rollout_index] == host_path then
            (
                rollout_removed = true

                try
                (
                    removeSubRollout host_dialog.sr_tools loaded_rollouts[rollout_index]
                )
                catch
                (
                    exception_text = getCurrentException()
                    rollout_removed = false
                    cleanup_ok = false
                    format "[Script-Manager] Hosted rollout removal failed for %: %\n" host_path exception_text
                )

                if rollout_removed then
                (
                    if rollout_index <= loaded_rollouts.count then deleteItem loaded_rollouts rollout_index
                    if rollout_index <= loaded_rollout_names.count then deleteItem loaded_rollout_names rollout_index
                    deleteItem loaded_rollout_group_paths rollout_index
                )
            )
        )
    )

    is_in_dialog = false

    try
    (
        is_in_dialog = host_dialog.inDialog
    )
    catch
    (
        exception_text = getCurrentException()
        cleanup_ok = false
        format "[Script-Manager] Host dialog-state read failed for %: %\n" host_path exception_text
    )

    is_destroying_host = true

    if is_in_dialog then
    (
        is_dialog_bar = false

        try
        (
            is_dialog_bar = host_dialog.dialogBar
        )
        catch
        (
            exception_text = getCurrentException()
            cleanup_ok = false
            format "[Script-Manager] Host dialog-bar state read failed for %: %\n" host_path exception_text
        )

        if is_dialog_bar then
        (
            try
            (
                cui.UnRegisterDialogBar host_dialog
            )
            catch
            (
                exception_text = getCurrentException()
                cleanup_ok = false
                format "[Script-Manager] Host dialog-bar unregister failed for %: %\n" host_path exception_text
            )
        )

        try
        (
            destroyDialog host_dialog
        )
        catch
        (
            exception_text = getCurrentException()
            cleanup_ok = false
            format "[Script-Manager] Host dialog destruction failed for %: %\n" host_path exception_text
        )
    )

    is_destroying_host = false

    host_index = findItem host_dialog_paths host_path
    if host_index > 0 then
    (
        if host_index <= host_dialogs.count then deleteItem host_dialogs host_index
        deleteItem host_dialog_paths host_index
        if host_index <= host_dialog_symbol_names.count then deleteItem host_dialog_symbol_names host_index
    )

    this.clearHostScriptTracking host_path

    cleanup_ok
    -- return
),

/*
Destroys every organizational host dialog.
*/
function destroyAllHostDialogs clear_rollouts:true =
(
    cleanup_ok = true
    paths_to_close = #()

    for host_path in host_dialog_paths do append paths_to_close host_path

    for path_index = paths_to_close.count to 1 by -1 do
    (
        if not(this.destroyHostDialog paths_to_close[path_index] clear_rollouts:clear_rollouts) then cleanup_ok = false
    )

    cleanup_ok
    -- return
),

/*
Removes host dialogs that currently contain no successfully embedded rollout.
*/
function pruneEmptyHostDialogs =
(
    cleanup_ok = true
    required_paths = #()

    for host_path in loaded_rollout_group_paths do
    (
        if (findItem required_paths host_path) == 0 then append required_paths host_path
    )

    paths_to_check = #()
    for host_path in host_dialog_paths do append paths_to_check host_path

    for host_path in paths_to_check do
    (
        if (findItem required_paths host_path) == 0 then
        (
            if not(this.destroyHostDialog host_path clear_rollouts:false) then cleanup_ok = false
        )
    )

    cleanup_ok
    -- return
),

    /*
    Creates one organizational host dialog and restores its persisted position and dock state.
    */
function createHostDialog host_path =
(
    if host_path == undefined or host_path == "" then return false

    existing_host = this.getHostDialog host_path
    if existing_host != undefined then
    (
        existing_open = false

        try
        (
            existing_open = existing_host.inDialog
        )
        catch
        (
            exception_text = getCurrentException()
            format "[Script-Manager] Existing host dialog-state read failed for %: %\n" host_path exception_text
        )

        if existing_open then return true
    )

    host_state = this.loadHostDialogState host_path
    dialog_position = host_state[1]
    dialog_height = host_state[2]
    dock_text = host_state[3]
    registration_position = scriptManagerGetRegistrationPosition dialog_position dock_text
    scriptManagerTraceDialogPosition host_path "INI-RESTORE" undefined saved_position:dialog_position dock_text:dock_text
    host_title = this.getHostDialogTitle host_path
    host_dialog_build_id += 1

    symbol_name = "script_manager_host_" + (host_dialog_build_id as string)
    caption_text = this.escapeSourceString host_title
    handler_path = this.escapeSourceString host_path

    source_text = "rollout " + symbol_name + " \"" + caption_text + "\" width:336 height:720 autoLayoutOnResize:true\n(\n"
    source_text += "    dotNetControl btn_dialog_title \"System.Windows.Forms.Button\" pos:[12,12] width:312 height:24\n"
    source_text += "    subRollout sr_tools \"\" pos:[12,48] width:312 height:660\n"
    source_text += "    on btn_dialog_title Click sender event_args do (if script_manager != undefined then script_manager.reloadHostDialogScripts \"" + handler_path + "\")\n"
    source_text += "    on " + symbol_name + " open do (btn_dialog_title.Text = \"" + caption_text + "\"; if script_manager != undefined then script_manager.layoutHostDialog \"" + handler_path + "\" [" + symbol_name + ".width," + symbol_name + ".height])\n"
    source_text += "    on " + symbol_name + " moved dialog_position do (if script_manager != undefined then (scriptManagerTraceDialogPosition \"" + handler_path + "\" \"MOVED-EVENT\" " + symbol_name + " dock_text:\"event\"; if not script_manager.is_reloading and not script_manager.is_destroying_host and script_manager.dialog_restore_depth == 0 then script_manager.saveHostDialogState \"" + handler_path + "\" save_rollouts:false))\n"
    source_text += "    on " + symbol_name + " resized dialog_size do (if script_manager != undefined then (script_manager.layoutHostDialog \"" + handler_path + "\" dialog_size; if not script_manager.is_reloading and not script_manager.is_destroying_host and script_manager.dialog_restore_depth == 0 then script_manager.saveHostDialogState \"" + handler_path + "\" save_rollouts:false))\n"
    source_text += "    on " + symbol_name + " close do (if script_manager != undefined then script_manager.handleHostDialogClosed \"" + handler_path + "\")\n"
    source_text += "    on " + symbol_name + " help do (if script_manager != undefined then script_manager.reloadLatestManagerScript())\n"
    source_text += ")"

    host_dialog = undefined
    host_index = 0
    dialog_restore_depth += 1

    try
    (
        execute source_text
        host_dialog = execute symbol_name

        append host_dialogs host_dialog
        append host_dialog_paths host_path
        append host_dialog_symbol_names symbol_name
        host_index = host_dialog_paths.count

        createDialog host_dialog \
            width:336 height:dialog_height pos:registration_position \
            style:#(#style_titlebar, #style_sysmenu, #style_toolwindow, #style_resizing) \
            lockWidth:true lockHeight:false autoLayoutOnResize:true

        windows.processPostedMessages()
        -- Use the working CODEBASE correction while the rollout is still unregistered.
        if not(scriptManagerApplyPreRegistrationOffset host_dialog dialog_position dock_text) then throw "Host CUI pre-registration positioning failed"
        scriptManagerTraceDialogPosition host_path "BEFORE-CUI-REGISTER" host_dialog saved_position:dialog_position dock_text:dock_text
        this.styleHostDialogTitleButton host_dialog.btn_dialog_title
    )
    catch
    (
        exception_text = getCurrentException()
        format "[Script-Manager] Host createDialog failed for %: %\n" host_path exception_text
        dialog_restore_depth -= 1

        if host_index > 0 then
        (
            if host_index <= host_dialogs.count then deleteItem host_dialogs host_index
            if host_index <= host_dialog_paths.count then deleteItem host_dialog_paths host_index
            if host_index <= host_dialog_symbol_names.count then deleteItem host_dialog_symbol_names host_index
        )

        return false
    )

    try
    (
        cui.RegisterDialogBar host_dialog \
            minSize:[336,300] \
            style:(this.getDialogBarStyles())
    )
    catch
    (
        exception_text = getCurrentException()
        format "[Script-Manager] Host RegisterDialogBar failed for %: %\n" host_path exception_text
        dialog_restore_depth -= 1

        try
        (
            if host_dialog.inDialog then destroyDialog host_dialog
        )
        catch
        (
            cleanup_exception_text = getCurrentException()
            format "[Script-Manager] Failed to close host after CUI registration failure for %: %\n" host_path cleanup_exception_text
        )

        host_index = findItem host_dialog_paths host_path
        if host_index > 0 then
        (
            if host_index <= host_dialogs.count then deleteItem host_dialogs host_index
            deleteItem host_dialog_paths host_index
            if host_index <= host_dialog_symbol_names.count then deleteItem host_dialog_symbol_names host_index
        )

        return false
    )

    scriptManagerTraceDialogPosition host_path "AFTER-CUI-REGISTER" host_dialog saved_position:dialog_position dock_text:dock_text
    if not(this.applyHostDockState host_path dock_text) then
    (
        format "[Script-Manager] Host dock state restore failed for %.\n" host_path
    )

    scriptManagerTraceDialogPosition host_path "AFTER-DOCK-RESTORE" host_dialog saved_position:dialog_position dock_text:dock_text
    this.layoutHostDialog host_path [host_dialog.width, host_dialog.height]
    dialog_restore_depth -= 1
    scriptManagerTraceDialogPosition host_path "READY" host_dialog saved_position:dialog_position dock_text:dock_text
    true
    -- return
),

    /*
    Ensures one organizational host dialog exists before tool rollouts are embedded.
    */
function ensureHostDialog host_path =
(
    if host_path == undefined or host_path == "" then return false

    host_dialog = this.getHostDialog host_path

    if host_dialog != undefined then
    (
        host_open = false

        try
        (
            host_open = host_dialog.inDialog
        )
        catch
        (
            exception_text = getCurrentException()
            host_open = false
            format "[Script-Manager] Host dialog-state read failed while ensuring %: %\n" host_path exception_text
        )

        if host_open then return true

        host_index = findItem host_dialog_paths host_path
        if host_index > 0 then
        (
            if host_index <= host_dialogs.count then deleteItem host_dialogs host_index
            deleteItem host_dialog_paths host_index
            if host_index <= host_dialog_symbol_names.count then deleteItem host_dialog_symbol_names host_index
        )
    )

    this.createHostDialog host_path
    -- return
),

    /*
    Unregisters and destroys the loader dialog and every organizational host dialog safely.
    */
function destroyManagerDialog =
(
    cleanup_ok = true

    if not(this.cancelInitialLoaderInitialization()) then cleanup_ok = false

    if script_manager_ui != undefined then
    (
        is_in_dialog = false

        try
        (
            is_in_dialog = script_manager_ui.inDialog
        )
        catch
        (
            exception_text = getCurrentException()
            format "[Script-Manager] Manager dialog-state read failed: %\n" exception_text
            return false
        )

        if is_in_dialog then
        (
            if not(this.saveDialogState save_rollouts:false) then cleanup_ok = false
        )
    )

    -- Lock geometry callbacks before child-rollout destruction or CUI unregistration.
    is_destroying_manager = true
    if not(this.destroyAllHostDialogs clear_rollouts:true) then cleanup_ok = false

    if script_manager_ui == undefined then
    (
        is_destroying_manager = false
        return cleanup_ok
    )

    is_in_dialog = false

    try
    (
        is_in_dialog = script_manager_ui.inDialog
    )
    catch
    (
        exception_text = getCurrentException()
        format "[Script-Manager] Manager dialog-state read failed: %\n" exception_text
        is_destroying_manager = false
        return false
    )

    if not is_in_dialog then
    (
        is_destroying_manager = false
        return cleanup_ok
    )

    if not(this.clearLoaderRollout()) then cleanup_ok = false

    is_dialog_bar = false

    try
    (
        is_dialog_bar = script_manager_ui.dialogBar
    )
    catch
    (
        exception_text = getCurrentException()
        cleanup_ok = false
        format "[Script-Manager] Manager dialog-bar state read failed: %\n" exception_text
    )

    if is_dialog_bar then
    (
        try
        (
            cui.UnRegisterDialogBar script_manager_ui
        )
        catch
        (
            exception_text = getCurrentException()
            cleanup_ok = false
            format "[Script-Manager] Manager dialog-bar unregister failed: %\n" exception_text
        )
    )

    try
    (
        destroyDialog script_manager_ui
    )
    catch
    (
        exception_text = getCurrentException()
        cleanup_ok = false
        format "[Script-Manager] Manager dialog destruction failed: %\n" exception_text
    )

    is_destroying_manager = false
    cleanup_ok
    -- return
),

    /*
    Stops the pending one-shot startup timer so a closing or restarting dialog cannot initialize stale controls.
    */
    function cancelInitialLoaderInitialization =
    (
        if loader_init_timer == undefined then return true

        cancel_ok = true

        try
        (
            loader_init_timer.Stop()
            loader_init_timer.Dispose()
        )
        catch
        (
            exception_text = getCurrentException()
            cancel_ok = false
            format "[Script-Manager] Startup loader timer cleanup failed: %\n" exception_text
        )

        if cancel_ok then loader_init_timer = undefined
        cancel_ok
        -- return
    ),

    /*
    Schedules the first source scan and child-rollout construction after the newly docked manager dialog is visible.
    */
    function queueInitialLoaderInitialization =
    (
        if not(this.cancelInitialLoaderInitialization()) then return false

        schedule_ok = true

        try
        (
            loader_init_timer = dotNetObject "System.Windows.Forms.Timer"
            loader_init_timer.Interval = 25
            dotNet.addEventHandler loader_init_timer "Tick" scriptManagerInitialLoaderTickHandler
            loader_init_timer.Start()
        )
        catch
        (
            exception_text = getCurrentException()
            schedule_ok = false
            format "[Script-Manager] Startup loader scheduling failed: %\n" exception_text
            this.cancelInitialLoaderInitialization()
        )

        schedule_ok
        -- return
    ),

    /*
    Initializes PRESETS, OPTIONS, SOURCES, and SCRIPTS on the first UI tick, without requiring a manual RESTART.
    */
    function finishInitialLoaderInitialization timer_sender =
    (
        if loader_init_timer == undefined or timer_sender != loader_init_timer then return false
        if not(this.cancelInitialLoaderInitialization()) then return false

        if script_manager_ui == undefined or not(script_manager_ui.inDialog) then
        (
            format "[Script-Manager] Startup loader aborted: manager dialog is not open.\n"
            return false
        )

        if not(this.reloadScripts()) then
        (
            is_reloading = false
            format "[Script-Manager] Initial script scan reported failure.\n"
            return false
        )

        if SCRIPT_MANAGER_STARTUP_LAUNCH == true then
        (
            if not(this.loadStartupPresetOnce()) then
            (
                format "[Script-Manager] Startup preset load reported failure.\n"
                return false
            )
        )

        true
        -- return
    ),

    /*
    Creates the resizable manager dialog, restores saved state, and enables CUI docking.
    The floating width stays locked while height remains resizable.
    */
    function createManagerDialog =
    (
        dialog_state = this.loadDialogState()
        dialog_position = dialog_state[1]
        dialog_height = dialog_state[2]
        dock_text = dialog_state[3]
        registration_position = scriptManagerGetRegistrationPosition dialog_position dock_text
        scriptManagerTraceDialogPosition "MAIN" "INI-RESTORE" undefined saved_position:dialog_position dock_text:dock_text

        this.registerProjectVersion()
        dialog_restore_depth += 1

        try
        (
            createDialog script_manager_ui \
                width:336 height:dialog_height pos:registration_position \
                style:#(#style_titlebar, #style_sysmenu, #style_toolwindow, #style_resizing) \
                lockWidth:true lockHeight:false autoLayoutOnResize:true

            windows.processPostedMessages()
            -- Apply the CODEBASE correction before the rollout becomes a registered dialog bar.
            if not(scriptManagerApplyPreRegistrationOffset script_manager_ui dialog_position dock_text) then throw "Manager CUI pre-registration positioning failed"
            scriptManagerTraceDialogPosition "MAIN" "BEFORE-CUI-REGISTER" script_manager_ui saved_position:dialog_position dock_text:dock_text
        )
        catch
        (
            exception_text = getCurrentException()
            dialog_restore_depth -= 1
            format "[Script-Manager] createDialog failed: %\n" exception_text
            return false
        )

        try
        (
            cui.RegisterDialogBar script_manager_ui \
                minSize:[336,1024] \
                style:(this.getDialogBarStyles())
        )
        catch
        (
            exception_text = getCurrentException()
            format "[Script-Manager] RegisterDialogBar failed: %\n" exception_text
            dialog_restore_depth -= 1

            try
            (
                if script_manager_ui.inDialog then destroyDialog script_manager_ui
            )
            catch
            (
                cleanup_exception_text = getCurrentException()
                format "[Script-Manager] Failed to close dialog after CUI registration failure: %\n" cleanup_exception_text
            )

            return false
        )

        scriptManagerTraceDialogPosition "MAIN" "AFTER-CUI-REGISTER" script_manager_ui saved_position:dialog_position dock_text:dock_text
        if not(this.applyDockState dock_text) then
        (
            format "[Script-Manager] Dock state restore failed.\n"
        )

        windows.processPostedMessages()
        scriptManagerTraceDialogPosition "MAIN" "AFTER-DOCK-RESTORE" script_manager_ui saved_position:dialog_position dock_text:dock_text
        if not(this.reloadScripts()) then
        (
            dialog_restore_depth -= 1
            format "[Script-Manager] Startup initialization failed | ROOT:% | INI:%\n" root_directory ini_path
            return false
        )
        if SCRIPT_MANAGER_STARTUP_LAUNCH == true then
        (
            if not(this.loadStartupPresetOnce()) then
            (
                dialog_restore_depth -= 1
                return false
            )
        )
        windows.processPostedMessages()
        dialog_restore_depth -= 1
        scriptManagerTraceDialogPosition "MAIN" "READY" script_manager_ui saved_position:dialog_position dock_text:dock_text

        true
        -- return
    ),

    /*
    Returns the newest numeric versioned manager script when it is newer than this running file.
    Otherwise the current source file is returned.
    */
    function getLatestReloadScriptPath =
    (
        if manager_source_path == undefined or manager_source_path == "" then return undefined

        source_directory = ScriptManagerIntegration.normalizeDirectoryPath (getFilenamePath manager_source_path)
        folder_name = ScriptManagerIntegration.getFolderName source_directory

        if source_directory == "" or folder_name == "" then return manager_source_path

        latest_path = manager_source_path
        latest_version = file_version
        versioned_files = getFiles (source_directory + folder_name + "_*.ms")

        for versioned_path in versioned_files do
        (
            version_value = ScriptManagerIntegration.getVersionValue versioned_path folder_name

            if version_value != undefined and version_value > latest_version then
            (
                latest_version = version_value
                latest_path = versioned_path
            )
        )

        latest_path
        -- return
    ),

    /*
    Reloads the newest matching manager version for RESTART/F1, or reloads this running source when no newer version exists.
    */
    function reloadLatestManagerScript =
    (
        reload_path = this.getLatestReloadScriptPath()
        if reload_path == undefined or not(doesFileExist reload_path) then return false

        if not(this.destroyManagerDialog()) then return false

        reload_ok = true

        try
        (
            fileIn reload_path quiet:true
        )
        catch
        (
            exception_text = getCurrentException()
            reload_ok = false
            format "[Script-Manager] RESTART failed: % | %\n" reload_path exception_text
        )

        reload_ok
        -- return
    ),

    /*
    Opens the Script-Manager dialog and restores its persisted state.
    This is the public UI entry point for integration from another script.
    */
    function showUI =
    (
        if not(this.destroyManagerDialog()) then return false

        this.createManagerDialog()
        -- return
    ),

    /*
    Closes the Script-Manager dialog while keeping the manager API instance available.
    */
    function hideUI =
    (
        this.destroyManagerDialog()
        -- return
    ),

    on create do
    (
        ini_path = (getDir #plugcfg) + "\\script_manager.ini"
    )
)

script_manager_version_text = formattedPrint script_manager_project_version format:"1.3f"
script_manager_title = "Script-Manager " + script_manager_version_text

rollout script_manager_ui script_manager_title width:336 height:1970 autoLayoutOnResize:true
(
    local refresh_restart_tooltip

    dotNetControl btn_refresh_restart "System.Windows.Forms.Button" pos:[12,12] width:312 height:18
    subRollout sr_loader "" pos:[12,42] width:312 height:1916

    /*
    Handles both LMB refresh and RMB version reload through one .NET MouseUp handler.
    This path gives the user immediate Listener diagnostics when refresh cannot complete.
    */
    on btn_refresh_restart MouseUp sender event_args do
    (
        scriptManagerRefreshButtonMouseUpHandler sender event_args
    )

    on script_manager_ui open do
    (
        if script_manager != undefined then
        (
            script_manager.styleToolTitleButton btn_refresh_restart
            btn_refresh_restart.Text = "REFRESH \\ RESTART  |  v" + script_manager_version_text
        )

        refresh_restart_tooltip = dotNetObject "System.Windows.Forms.ToolTip"
        refresh_restart_tooltip.SetToolTip btn_refresh_restart "LMB: Save/apply pending OPTIONS, then rescan selected sources and rebuild the loader trees.\n\nRMB: Load the newest Script-Manager version, or restart the current version when no newer file exists."

        script_manager.layoutManager [script_manager_ui.width, script_manager_ui.height]
    )

    on script_manager_ui moved dialog_position do
    (
        if script_manager != undefined then
        (
            saved_position = [(script_manager.getIniInteger "Dialog" "X" 120), (script_manager.getIniInteger "Dialog" "Y" 120)]
            scriptManagerTraceDialogPosition "MAIN" "MOVED-EVENT" script_manager_ui saved_position:saved_position dock_text:"event"
            if not script_manager.is_reloading and not script_manager.is_destroying_manager and script_manager.dialog_restore_depth == 0 then script_manager.saveDialogState save_rollouts:false
        )
    )

    on script_manager_ui resized dialog_size do
    (
        script_manager.layoutManager dialog_size
        if not script_manager.is_reloading and not script_manager.is_destroying_manager and script_manager.dialog_restore_depth == 0 then script_manager.saveDialogState save_rollouts:false
    )

    on script_manager_ui close do
    (
        if script_manager != undefined and not script_manager.is_destroying_manager then script_manager.saveDialogState save_rollouts:false
    )

    on script_manager_ui help do
    (
        if script_manager != undefined then script_manager.reloadLatestManagerScript()
    )

)

script_manager = script_manager_v()
script_manager.manager_source_path = getSourceFileName()
if not(script_manager.initializeSettingsFile()) then throw "Script-Manager settings initialization failed"
script_manager.root_directory = script_manager.getProjectRootDirectory()
if script_manager.debug_logging then format "[Script-Manager] MANAGER SOURCE: %\n" script_manager.manager_source_path
if script_manager.debug_logging then format "[Script-Manager] MANAGED ROOT: %\n" script_manager.root_directory
script_manager.registerProjectVersion()
if SCRIPT_MANAGER_AUTO_OPEN then script_manager.createManagerDialog()

