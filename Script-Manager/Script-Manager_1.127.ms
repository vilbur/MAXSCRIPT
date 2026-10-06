/*
    Script-Manager 1.127
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
    file_version = 1.127,
    project_version = 1.127,
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
    Returns #(success, error, script_path).
    */
    function loadScript script_path runtime_mode:#library quiet:true =
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
global script_manager_title
global script_manager_host_title
global script_manager_version_text
global SCRIPT_MANAGER_AUTO_OPEN
global scriptManagerTreeExpandContextHandler
global scriptManagerTreeCollapseContextHandler
global scriptManagerTreeExpandAllContextHandler
global scriptManagerTreeCollapseAllContextHandler
global scriptManagerSourceTreeExpandAllContextHandler
global scriptManagerSourceTreeCollapseAllContextHandler

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
Collapses the complete SCRIPTS tree from the .NET context-menu callback.
*/
function scriptManagerTreeCollapseAllContextHandler sender_value event_args =
(
    if script_manager != undefined then script_manager.collapseAllScriptTree()
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

struct script_manager_v
(
    file_version = 1.127,
    project_version = 1.127,
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
    available_script_directories = #(),
    available_script_paths = #(),
    available_source_names = #(),
    available_source_directories = #(),
    show_versioned_files = false,
    show_clean_scripts_only = false,
    available_group_paths = #(),
    available_group_names = #(),
    available_group_directories = #(),
    group_rollouts = #(),
    group_rollout_paths = #(),
    group_rollout_symbol_names = #(),
    group_build_id = 0,
    host_dialogs = #(),
    host_dialog_paths = #(),
    host_dialog_symbol_names = #(),
    host_dialog_build_id = 0,
    loader_rollout = undefined,
    loader_rollout_open = true,
    loader_content_height = 1664,
    script_tree_file_count = 0,
    script_tree_required_height = 1032,
    script_tree_base_font_height = 0,
    script_tree_font_height = 0,
    script_tree_font_pixel_increase = 2,
    script_tree_state_images = undefined,
    script_tree_context_menu = undefined,
    script_tree_expand_item = undefined,
    script_tree_collapse_item = undefined,
    script_tree_expand_all_item = undefined,
    script_tree_collapse_all_item = undefined,
    source_tree_context_menu = undefined,
    source_tree_expand_all_item = undefined,
    source_tree_collapse_all_item = undefined,
    script_tree_syncing_checks = false,
    source_tree_syncing_checks = false,
    tree_expansion_syncing = false,
    debug_logging = false,
    manager_source_path = "",
    loader_collapsed_height = 24,
    rollout_header_height = 24,
    subrollout_extra_height = 24,
    hierarchy_layout_signature = "",
    hierarchy_layout_pending_passes = 0,
    is_reloading = false,
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

        setINISetting ini_path "Sources" source_key (if enabled then "1" else "0") forceUTF16:false
        true
        -- return
    ),

    /*
    Appends every selectable source subfolder below one directory in parent-before-child order.
    The Script-Manager package directory is excluded from source discovery.
    */
    function collectSourceDirectoriesRecursive directory_path =
    (
        normalized_path = ScriptManagerIntegration.normalizeDirectoryPath directory_path
        if normalized_path == "" then return false

        child_directories = getDirectories (normalized_path + "*")
        sort child_directories

        for child_directory in child_directories do
        (
            if not(this.isManagerPackageDirectory child_directory) then
            (
                normalized_child = ScriptManagerIntegration.normalizeDirectoryPath child_directory
                append available_source_names (ScriptManagerIntegration.getFolderName normalized_child)
                append available_source_directories normalized_child
                this.collectSourceDirectoriesRecursive normalized_child
            )
        )

        true
        -- return
    ),

    /*
    Discovers the selectable source-folder hierarchy below the managed root.
    The managed root itself is intentionally not exposed as a SOURCES item.
    */
    function discoverSources =
    (
        available_source_names = #()
        available_source_directories = #()

        if root_directory == "" then return false

        this.collectSourceDirectoriesRecursive root_directory
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

            if this.getSourceEnabled source_directory then
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
    Returns raw supported script files directly inside one directory before version filtering.
    Auto-loaded UI companions remain hidden as separate load targets.
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
                if not(this.isAutoCompanionScriptPath script_path) then append script_files script_path
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
        show_versioned_files = (getINISetting ini_path "Filter" "ShowVersionedFiles") == "1"
        show_versioned_files
        -- return
    ),

    /*
    Saves the CLEAN SCRIPTS ONLY filter state.
    */
    function saveShowCleanScriptsOnly enabled =
    (
        show_clean_scripts_only = enabled
        setINISetting ini_path "Filter" "CleanScriptsOnly" (if enabled then "1" else "0") forceUTF16:false
        true
        -- return
    ),

    /*
    Loads the CLEAN SCRIPTS ONLY filter state.
    */
    function loadShowCleanScriptsOnly =
    (
        show_clean_scripts_only = (getINISetting ini_path "Filter" "CleanScriptsOnly") == "1"
        show_clean_scripts_only
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
    Loads one folder-node expanded state from INI, defaulting to expanded.
    */
    function loadTreeNodeOpenState tree_node section_name =
    (
        state_key = this.getTreeExpansionKey tree_node
        if state_key == "" then return true

        this.getIniBoolean section_name state_key true
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

        if (this.getScriptFilesInDirectory normalized_path).count > 0 then return true

        child_directories = getDirectories (normalized_path + "*")
        sort child_directories

        for child_directory in child_directories do
        (
            if this.directoryHasManagedScripts child_directory then return true
        )

        false
        -- return
    ),

    /*
    Recursively discovers one script-bearing directory and its supported script files.
    */
    function discoverDirectory directory_path =
    (
        normalized_path = ScriptManagerIntegration.normalizeDirectoryPath directory_path
        if normalized_path == "" then return false
        if this.isManagerPackageDirectory normalized_path then return true
        if not(this.directoryHasManagedScripts normalized_path) then return true

        relative_path = this.getRelativeDirectoryPath normalized_path
        if relative_path == "" then return false

        append available_group_paths relative_path
        append available_group_names (ScriptManagerIntegration.getFolderName normalized_path)
        append available_group_directories normalized_path

        if debug_logging then format "[Script-Manager] GROUP: %\n" relative_path

        for script_path in (this.getScriptFilesInDirectory normalized_path) do
        (
            script_name = getFilenameFile script_path
            script_key = this.getScriptKey script_path

            append available_script_names script_name
            append available_script_keys script_key
            append available_script_group_paths relative_path
            append available_script_directories normalized_path
            append available_script_paths script_path

            if debug_logging then format "[Script-Manager] SCRIPT: % | GROUP: % | LOAD PATH: %\n" script_key relative_path script_path
        )

        child_directories = getDirectories (normalized_path + "*")
        sort child_directories

        for child_directory in child_directories do
        (
            this.discoverDirectory child_directory
        )

        true
        -- return
    ),

    /*
    Discovers all supported scripts and script-bearing directories below the manager root.
    Folder order drives category rollout order and tool order recursively.
    */
    function discoverScripts =
    (
        available_script_names = #()
        available_script_keys = #()
        available_script_group_paths = #()
        available_script_directories = #()
        available_script_paths = #()
        available_group_paths = #()
        available_group_names = #()
        available_group_directories = #()

        if root_directory == "" then return false
        if available_source_directories.count == 0 then this.discoverSources()

        root_directory = ScriptManagerIntegration.normalizeDirectoryPath root_directory
        if debug_logging then format "[Script-Manager] ROOT PATH: %\n" root_directory

        enabled_sources = this.getEnabledSourceDirectories()

        for source_directory in enabled_sources do
        (
            normalized_source = ScriptManagerIntegration.normalizeDirectoryPath source_directory

            if normalized_source == root_directory then
            (
                for script_path in (this.getScriptFilesInDirectory root_directory) do
                (
                    script_name = getFilenameFile script_path
                    script_key = this.getScriptKey script_path

                    append available_script_names script_name
                    append available_script_keys script_key
                    append available_script_group_paths ""
                    append available_script_directories root_directory
                    append available_script_paths script_path

                    if debug_logging then format "[Script-Manager] SCRIPT: % | GROUP: <root> | LOAD PATH: %\n" script_key script_path
                )
            )
            else
            (
                this.discoverDirectory normalized_source
            )
        )

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
    Returns the saved expanded state of the tool-loader rollout.
    */
    function loadLoaderOpenState =
    (
        this.getIniBoolean "Loader" "Open" true
        -- return
    ),

    /*
    Saves the expanded state of the tool-loader rollout.
    */
    function saveLoaderOpenState open_state =
    (
        setINISetting ini_path "Loader" "Open" (if open_state then "1" else "0") forceUTF16:false
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
    CLEAN SCRIPTS ONLY has priority and keeps only the unversioned file named exactly like its parent folder.
    Otherwise SHOW VERSIONED FILES exposes every version; the default view keeps canonical files or the newest version.
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

            return this.sortScriptPathsNewestFirst clean_files
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
        if script_manager_loader_ui == undefined then return undefined
        if not(isProperty script_manager_loader_ui #tv_sources) then return undefined

        script_manager_loader_ui.tv_sources
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
    Rebuilds the SOURCES tree as the selectable subfolder hierarchy below the managed root.
    */
    function populateSourceTree =
    (
        source_tree = this.getSourceTreeControl()
        if source_tree == undefined then return false
        if not(this.discoverSources()) then return false

        source_tree_syncing_checks = true
        populate_ok = true

        try
        (
            this.styleTreeControl source_tree
            if source_tree_context_menu == undefined then this.buildSourceTreeContextMenu()
            source_tree.BeginUpdate()
            source_tree.Nodes.Clear()
            source_tree.ShowNodeToolTips = true
            source_tree.HideSelection = false
            source_tree.FullRowSelect = true

            source_node_paths = #()
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
                    parent_index = findItem source_node_paths parent_relative_path
                    if parent_index > 0 then parent_nodes = source_node_values[parent_index].Nodes
                )

                source_node = parent_nodes.Add source_name
                source_node.Tag = source_directory
                source_node.ToolTipText = source_directory
                source_node.Checked = this.getSourceEnabled source_directory
                append source_node_paths relative_path
                append source_node_values source_node
            )

            tree_expansion_syncing = true

            for source_node in source_node_values do
            (
                if this.loadTreeNodeOpenState source_node "SourceTreeOpen" then source_node.Expand() else source_node.Collapse()
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
        populate_ok
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

        tree_action_type = dotNetClass "System.Windows.Forms.TreeViewAction"
        if check_args.Action == tree_action_type.Unknown then return true

        source_directory = check_args.Node.ToolTipText
        if source_directory == undefined or source_directory == "" then return false
        if not(this.saveSourceEnabled source_directory check_args.Node.Checked) then return false

        this.refreshConfiguredDiscovery()
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
    Persists the CLEAN SCRIPTS ONLY filter and refreshes discovery without loading scripts.
    */
    function handleShowCleanScriptsChanged enabled =
    (
        this.saveShowCleanScriptsOnly enabled
        this.refreshConfiguredDiscovery()
        -- return
    ),

    /*
    Returns the active SCRIPTS TreeView control when the dynamic loader rollout exists.
    */
    function getScriptTreeControl =
    (
        if script_manager_loader_ui == undefined then return undefined
        if not(isProperty script_manager_loader_ui #tv_scripts) then return undefined

        script_manager_loader_ui.tv_scripts
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
    Applies the script-item font color for one TreeView node.
    Hosted and direct-run script leaves use RGB 62,158,255; skipped files and folders use the standard tree foreground.
    */
    function applyScriptTreeNodeColor tree_node =
    (
        if tree_node == undefined then return false

        color_type = dotNetClass "System.Drawing.Color"
        node_path = tree_node.ToolTipText
        node_active = false

        if this.isSupportedScriptPath node_path then
        (
            script_key = this.getScriptKey node_path
            node_active = (this.getScriptLoadMode script_key) != #skip
        )

        if node_active then
        (
            tree_node.ForeColor = color_type.FromArgb 62 158 255
        )
        else
        (
            tree_node.ForeColor = color_type.FromArgb 225 225 225
        )

        true
        -- return
    ),

    /*
    Recursively synchronizes one SCRIPTS node and returns whether it or any descendant script is active.
    Script leaves use 0=#skip, 1=#host, 2=#direct. Folder nodes show indeterminate when descendant modes are mixed.
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
            tree_node.StateImageIndex = this.getScriptLoadModeStateIndex load_mode
            node_active = load_mode != #skip
        )
        else
        (
            active_count = 0
            host_count = 0
            child_count = tree_node.Nodes.Count

            if child_count > 0 then
            (
                for child_index = 0 to (child_count - 1) do
                (
                    child_node = tree_node.Nodes.Item[child_index]
                    if this.syncScriptTreeNodeChecks child_node then active_count += 1
                    if child_node.StateImageIndex == 1 then host_count += 1
                )
            )

            if child_count == 0 or active_count == 0 then
            (
                tree_node.StateImageIndex = 0
            )
            else if active_count == child_count and host_count == child_count then
            (
                tree_node.StateImageIndex = 1
            )
            else
            (
                tree_node.StateImageIndex = 2
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

        try
        (
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

        script_tree_syncing_checks = false
        sync_ok
        -- return
    ),

    /*
    Removes .NET handlers and disposes the SOURCES context menu before the loader rollout is rebuilt.
    Cleanup failures are intentionally harmless because the old UI is being destroyed.
    */
    function clearSourceTreeContextMenu =
    (
        cleanup_ok = true

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

        source_tree_expand_all_item = source_tree_context_menu.Items.Add "EXPAND ALL"
        source_tree_collapse_all_item = source_tree_context_menu.Items.Add "COLLAPSE ALL"
        source_tree_expand_all_item.BackColor = source_tree_context_menu.BackColor
        source_tree_expand_all_item.ForeColor = source_tree_context_menu.ForeColor
        source_tree_collapse_all_item.BackColor = source_tree_context_menu.BackColor
        source_tree_collapse_all_item.ForeColor = source_tree_context_menu.ForeColor

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
        if click_args.Button != mouse_buttons.Right then return true

        tree_control.SelectedNode = click_args.Node
        if source_tree_context_menu != undefined then source_tree_context_menu.Show tree_control click_args.Location
        true
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
        script_tree_expand_item = undefined
        script_tree_collapse_item = undefined
        script_tree_expand_all_item = undefined
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

        script_tree_expand_item = script_tree_context_menu.Items.Add "EXPAND"
        script_tree_collapse_item = script_tree_context_menu.Items.Add "COLLAPSE"
        script_tree_expand_all_item = script_tree_context_menu.Items.Add "EXPAND ALL"
        script_tree_collapse_all_item = script_tree_context_menu.Items.Add "COLLAPSE ALL"

        for menu_item in #(script_tree_expand_item, script_tree_collapse_item, script_tree_expand_all_item, script_tree_collapse_all_item) do
        (
            menu_item.BackColor = script_tree_context_menu.BackColor
            menu_item.ForeColor = script_tree_context_menu.ForeColor
        )

        dotNet.addEventHandler script_tree_expand_item "Click" scriptManagerTreeExpandContextHandler
        dotNet.addEventHandler script_tree_collapse_item "Click" scriptManagerTreeCollapseContextHandler
        dotNet.addEventHandler script_tree_expand_all_item "Click" scriptManagerTreeExpandAllContextHandler
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
        if script_tree_expand_item == undefined or script_tree_collapse_item == undefined then return false

        selected_node = tree_control.SelectedNode
        has_children = selected_node != undefined and selected_node.Nodes.Count > 0
        script_tree_expand_item.Enabled = has_children
        script_tree_collapse_item.Enabled = has_children
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
        if this.isSupportedScriptPath event_args.Node.ToolTipText then return true

        this.saveTreeNodeOpenState event_args.Node "ScriptTreeOpen"
        -- return
    ),

    /*
    Builds the three checkbox-state images used by the SCRIPTS TreeView.
    Index 0 is unchecked, index 1 is checked/hosted, and index 2 is indeterminate/direct-run.
    */
    function buildScriptTreeStateImages =
    (
        image_list = dotNetObject "System.Windows.Forms.ImageList"
        image_list.ImageSize = dotNetObject "System.Drawing.Size" 16 16
        checkbox_renderer = dotNetClass "System.Windows.Forms.CheckBoxRenderer"
        checkbox_state_type = dotNetClass "System.Windows.Forms.VisualStyles.CheckBoxState"
        point_value = dotNetObject "System.Drawing.Point" 0 0
        color_type = dotNetClass "System.Drawing.Color"
        transparent_color = color_type.Transparent
        state_values = #(checkbox_state_type.UncheckedNormal, checkbox_state_type.CheckedNormal, checkbox_state_type.MixedNormal)

        for state_value in state_values do
        (
            bitmap_value = dotNetObject "System.Drawing.Bitmap" 16 16
            graphics_value = (dotNetClass "System.Drawing.Graphics").FromImage bitmap_value
            graphics_value.Clear transparent_color
            checkbox_renderer.DrawCheckBox graphics_value point_value state_value
            graphics_value.Dispose()
            image_list.Images.Add bitmap_value
            bitmap_value.Dispose()
        )

        script_tree_state_images = image_list
        true
        -- return
    ),

    /*
    Applies one persisted load mode to a script node without invoking an execution path.
    */
    function applyScriptTreeNodeMode tree_node load_mode =
    (
        if tree_node == undefined then return false

        tree_node.StateImageIndex = this.getScriptLoadModeStateIndex load_mode
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
        tree_control.StateImageList = script_tree_state_images
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

        if load_ok then
        (
            this.syncScriptTreeChecks()

            if result_data[2] > 0 then
            (
                script_manager_ui.lbl_status.text = "Loaded: " + (pathConfig.stripPathToLeaf script_path) + " | " + (result_data[2] as string) + " rollout(s)"
            )
            else
            (
                script_manager_ui.lbl_status.text = "Executed: " + (pathConfig.stripPathToLeaf script_path)
            )
        )
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

        if load_ok then
        (
            if result_data[2] > 0 then
            (
                script_manager_ui.lbl_status.text = "Appended: " + (pathConfig.stripPathToLeaf script_path) + " | " + (result_data[2] as string) + " rollout(s)"
            )
            else
            (
                script_manager_ui.lbl_status.text = "Executed: " + (pathConfig.stripPathToLeaf script_path)
            )
        )
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
        if script_manager_ui != undefined then script_manager_ui.lbl_status.text = "Load mode updated. Press LOAD SCRIPTS to apply."
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
    Handles script-tree item clicks.
    LMB on a state image cycles the persisted mode; LMB on the item runs the manual hosted path; RMB opens tree commands.
    */
    function handleScriptTreeNodeClick click_args =
    (
        if click_args == undefined then return false
        if click_args.Node == undefined then return false

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

        hit_info = tree_control.HitTest click_args.Location
        if hit_info != undefined then
        (
            hit_location_text = hit_info.Location.ToString()
            if (findString hit_location_text "StateImage") != undefined then
            (
                return this.cycleScriptTreeNodeMode click_args.Node
            )
        )

        clicked_path = click_args.Node.ToolTipText
        if not(this.isSupportedScriptPath clicked_path) then return false

        this.loadScriptFromTree clicked_path
        -- return
    ),

    /*
    Rebuilds the SCRIPTS TreeView from the complete managed directory tree.
    All folder nodes and all .ms/.mcr/.mse script files are shown; the tree is expanded after population.
    */
    function populateScriptTree =
    (
        if script_manager_loader_ui == undefined then return false
        if root_directory == "" then return false

        tree_control = this.getScriptTreeControl()
        if tree_control == undefined then return false

        script_tree_file_count = 0
        populate_ok = true

        try
        (
            this.styleScriptTree()
            if script_tree_context_menu == undefined then this.buildScriptTreeContextMenu()

            tree_control.BeginUpdate()
            tree_control.Nodes.Clear()
            tree_control.ShowNodeToolTips = true
            tree_control.HideSelection = false
            tree_control.FullRowSelect = true

            node_paths = #()
            node_values = #()

            for script_index = 1 to available_script_paths.count do
            (
                script_path = available_script_paths[script_index]
                group_path = available_script_group_paths[script_index]
                parent_nodes = tree_control.Nodes

                if group_path != "" then
                (
                    path_parts = filterString group_path "\\"
                    current_path = ""

                    for part_index = 1 to path_parts.count do
                    (
                        part_name = path_parts[part_index]
                        current_path = if current_path == "" then part_name else (current_path + "\\" + part_name)
                        node_index = findItem node_paths current_path

                        if node_index == 0 then
                        (
                            folder_node = parent_nodes.Add part_name
                            folder_directory = root_directory + current_path + "\\"
                            folder_node.Tag = folder_directory
                            folder_node.ToolTipText = folder_directory
                            append node_paths current_path
                            append node_values folder_node
                            parent_nodes = folder_node.Nodes
                        )
                        else
                        (
                            folder_node = node_values[node_index]
                            parent_nodes = folder_node.Nodes
                        )
                    )
                )

                script_leaf = pathConfig.stripPathToLeaf script_path
                script_node = parent_nodes.Add script_leaf
                script_node.Tag = script_path
                script_node.ToolTipText = script_path
                script_tree_file_count += 1
            )

            tree_expansion_syncing = true

            for folder_node in node_values do
            (
                if this.loadTreeNodeOpenState folder_node "ScriptTreeOpen" then folder_node.Expand() else folder_node.Collapse()
            )

            tree_expansion_syncing = false
            tree_control.EndUpdate()
            this.syncScriptTreeChecks()

            script_tree_required_height = this.getScriptTreeRequiredHeight()
            loader_content_height = 1664
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
        populate_ok
        -- return
    ),

    /*
    Removes the loader rollout from the first subrollout slot.
    */
    function clearLoaderRollout =
    (
        if script_manager_ui == undefined then return false

        source_menu_cleanup_ok = this.clearSourceTreeContextMenu()
        script_menu_cleanup_ok = this.clearScriptTreeContextMenu()
        cleanup_ok = source_menu_cleanup_ok and script_menu_cleanup_ok

        if loader_rollout != undefined then
        (
            try
            (
                removeSubRollout script_manager_ui.sr_loader loader_rollout
                loader_rollout = undefined
            )
            catch
            (
                exception_text = getCurrentException()
                cleanup_ok = false
                format "[Script-Manager] Loader rollout removal failed: %\n" exception_text
            )
        )

        cleanup_ok
        -- return
    ),

    /*
    Updates the saved loader-open state and immediately collapses or expands its first slot.
    */
    function setLoaderRolloutOpen open_state =
    (
        loader_rollout_open = open_state
        this.saveLoaderOpenState open_state

        if script_manager_ui != undefined then
        (
            this.layoutManager [script_manager_ui.width, script_manager_ui.height]
        )

        true
        -- return
    ),

    /*
    Builds the first-slot SCRIPTS rollout as a recursive filesystem TreeView.
    The tree lists every .ms/.mcr/.mse script below the managed root; scripts execute only when explicitly selected.
    */
    function buildLoaderRollout =
    (
        if script_manager_ui == undefined then return false

        if not(this.clearLoaderRollout()) then return false
        loader_rollout_open = this.loadLoaderOpenState()
        this.loadShowVersionedFiles()
        this.loadShowCleanScriptsOnly()
        loader_content_height = 1664

        source_text = "rollout script_manager_loader_ui \"SCRIPT LOADER\" width:288 height:" + (loader_content_height as string) + "\n(\n"
        source_text += "    label lbl_sources \"SOURCES\" pos:[6,6] width:132 height:12 align:#left\n"
        source_text += "    dotNetControl tv_sources \"System.Windows.Forms.TreeView\" pos:[6,24] width:276 height:512\n"
        source_text += "    checkbox chk_show_versions \"SHOW VERSIONED FILES\" pos:[6,548] width:180 height:24 checked:" + (show_versioned_files as string) + " tooltip:\"Show every versioned script instead of only the canonical file or newest version.\"\n"
        source_text += "    checkbox chk_clean_scripts \"CLEAN SCRIPTS ONLY\" pos:[6,572] width:180 height:24 checked:" + (show_clean_scripts_only as string) + " tooltip:\"Show only an unversioned script whose name matches its parent folder.\"\n"
        source_text += "    label lbl_scripts \"SCRIPTS\" pos:[6,608] width:132 height:12 align:#left\n"
        source_text += "    dotNetControl tv_scripts \"System.Windows.Forms.TreeView\" pos:[6,626] width:276 height:1032\n"
        source_text += "    on tv_sources NodeMouseClick click_args do (if script_manager != undefined then script_manager.handleSourceTreeNodeClick click_args)\n"
        source_text += "    on tv_sources AfterCheck check_args do (if script_manager != undefined then script_manager.handleSourceTreeAfterCheck check_args)\n"
        source_text += "    on tv_sources AfterExpand event_args do (if script_manager != undefined then script_manager.handleSourceTreeExpandedState event_args)\n"
        source_text += "    on tv_sources AfterCollapse event_args do (if script_manager != undefined then script_manager.handleSourceTreeExpandedState event_args)\n"
        source_text += "    on tv_scripts NodeMouseClick click_args do (if script_manager != undefined then script_manager.handleScriptTreeNodeClick click_args)\n"
        source_text += "    on tv_scripts AfterExpand event_args do (if script_manager != undefined then script_manager.handleScriptTreeExpandedState event_args)\n"
        source_text += "    on tv_scripts AfterCollapse event_args do (if script_manager != undefined then script_manager.handleScriptTreeExpandedState event_args)\n"
        source_text += "    on chk_show_versions changed state do (if script_manager != undefined then script_manager.handleShowVersionedChanged state)\n"
        source_text += "    on chk_clean_scripts changed state do (if script_manager != undefined then script_manager.handleShowCleanScriptsChanged state)\n"
        source_text += "    on script_manager_loader_ui open do (if script_manager != undefined then (script_manager.populateSourceTree(); script_manager.populateScriptTree()))\n"
        source_text += "    on script_manager_loader_ui rolledUp state do (if script_manager != undefined then script_manager.setLoaderRolloutOpen state)\n"
        source_text += ")"

        try
        (
            execute source_text
            loader_rollout = script_manager_loader_ui
            addSubRollout script_manager_ui.sr_loader loader_rollout rolledUp:(not loader_rollout_open)

            if not(this.populateSourceTree()) then throw "populateSourceTree returned false"
            if not(this.populateScriptTree()) then throw "populateScriptTree returned false"
        )
        catch
        (
            format "[Script-Manager] Loader rollout creation failed: %\n" (getCurrentException())
            loader_rollout = undefined
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

        if not(this.saveLoaderOpenState loader_rollout_open) then save_ok = false

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
        dialog_height = this.getIniInteger "Dialog" "Height" 1784
        dock_text = getINISetting ini_path "Dialog" "Dock"

        if dialog_height < 1784 then dialog_height = 1784
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
    Hosted rollout content lives exclusively in generated organizational host dialogs.
    */
    function layoutManager dialog_size =
    (
        if script_manager_ui == undefined then return false

        usable_width = dialog_size.x - 24
        if usable_width < 264 then usable_width = 264

        slot_top = 60
        bottom_action_height = 12

        desired_loader_height = if loader_rollout_open then (loader_content_height + rollout_header_height) else loader_collapsed_height
        maximum_loader_height = dialog_size.y - slot_top - bottom_action_height
        if maximum_loader_height < loader_collapsed_height then maximum_loader_height = loader_collapsed_height
        loader_slot_height = amin desired_loader_height maximum_loader_height

        script_manager_ui.lbl_version.width = 96
        script_manager_ui.lbl_status.width = amax 96 (usable_width - 108)

        script_manager_ui.sr_loader.pos = [12, slot_top]
        script_manager_ui.sr_loader.width = usable_width
        script_manager_ui.sr_loader.height = loader_slot_height

        if loader_rollout != undefined then
        (
            visible_loader_content_height = amax 32 (loader_slot_height - rollout_header_height)
            loader_rollout.width = usable_width
            loader_rollout.height = visible_loader_content_height

            source_tree = this.getSourceTreeControl()
            if source_tree != undefined then source_tree.Width = amax 20 (usable_width - 12)

            tree_control = this.getScriptTreeControl()
            if tree_control != undefined then
            (
                tree_control.Width = amax 20 (usable_width - 12)
                tree_control.Height = amax 1032 (visible_loader_content_height - 632)
            )
        )


        true
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

    tools_height = dialog_size.y - 24
    if tools_height < rollout_header_height then tools_height = rollout_header_height

    host_dialog.sr_tools.pos = [12,12]
    host_dialog.sr_tools.width = usable_width
    host_dialog.sr_tools.height = tools_height

    true
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
    Hosted mode embeds declared rollouts; direct mode fileIns only the selected script in #standalone and never adds rollouts to shared dialogs.
    */
function loadManagedScript script_path script_name:"" script_key:"" group_path:"" embed_rollouts:true =
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
        integration_result = ScriptManagerIntegration.loadScript script_path runtime_mode:#standalone quiet:true

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

    if rollout_names.count == 0 then
    (
        loaded_state_ok = this.recordLoadedScript script_path companion_ui_path:(if companion_ui_exists then companion_ui_path else "") script_name:script_name script_key:script_key
        if not loaded_state_ok then return #(false, 0, "Could not record successful script state.")

        if debug_logging then format "[Script-Manager] Executed: % | rollouts:0\n" script_path
        return #(true, 0, undefined)
    )

    host_path = this.getHostDialogPathForGroup group_path

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

    for rollout_name in rollout_names while embed_error == undefined do
    (
        rollout_result = this.getRolloutValue rollout_name

        if not rollout_result[1] then
        (
            embed_error = rollout_result[3]
        )
        else
        (
            rollout_value = rollout_result[2]

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
    )

    if embed_error != undefined or embedded_rollouts.count != rollout_names.count then
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

        if embed_error == undefined then embed_error = "Not every declared rollout was embedded."
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
    script_manager_ui.lbl_status.text = (available_script_paths.count as string) + " scripts / " + (available_group_paths.count as string) + " groups"
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

    for script_index = 1 to available_script_paths.count do
    (
        script_path = available_script_paths[script_index]
        script_key = available_script_keys[script_index]

        load_mode = this.getScriptLoadMode script_key

        if load_mode != #skip then
        (
            result_data = this.loadManagedScript \
                script_path \
                script_name:available_script_names[script_index] \
                script_key:script_key \
                group_path:available_script_group_paths[script_index] \
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
    Applies the persisted tri-state load modes to the scripts already discovered in the SCRIPTS tree.
    Hosted rollouts are rebuilt from the current configured load set; source discovery is not repeated here.
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

        if load_summary[4] > 0 then
        (
            script_manager_ui.lbl_status.text = (load_summary[2] as string) + " loaded / " + (load_summary[4] as string) + " failed"
        )
        else
        (
            script_manager_ui.lbl_status.text = (load_summary[2] as string) + " loaded / " + (available_script_paths.count as string) + " available"
        )
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
    if root_directory == "" then return false
    if script_manager_ui == undefined then return false

    is_reloading = true
    reload_succeeded = true

    try
    (
        if debug_logging then format "[Script-Manager] RELOAD STAGE: discover sources\n"
        if not(this.discoverSources()) then throw "discoverSources returned false"

        if debug_logging then format "[Script-Manager] RELOAD STAGE: discover scripts\n"
        if not(this.discoverScripts()) then throw "discoverScripts returned false"

        if debug_logging then format "[Script-Manager] RELOAD STAGE: build loader\n"
        if not(this.buildLoaderRollout()) then throw "buildLoaderRollout returned false"

        if debug_logging then format "[Script-Manager] RELOAD STAGE: synchronize loader state\n"
        if not(this.prepareScriptHost()) then throw "prepareScriptHost returned false"

        if not(this.updateVersionLabel()) then throw "updateVersionLabel returned false"
        if not(this.layoutManager [script_manager_ui.width, script_manager_ui.height]) then throw "layoutManager returned false"

        script_manager_ui.lbl_status.text = (available_script_paths.count as string) + " scripts available. Press LOAD SCRIPTS."
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
    Updates the visible project-version label without touching a registered dialog-bar title.
    Dialog-bar titles are assigned before CUI registration in createManagerDialog().
    */
function updateVersionLabel =
(
    if script_manager_ui == undefined then return false

    this.registerProjectVersion()
    script_manager_ui.lbl_version.text = "Script Manager  " + script_manager_version_text
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
    host_title = this.getHostDialogTitle host_path
    host_dialog_build_id += 1

    symbol_name = "script_manager_host_" + (host_dialog_build_id as string)
    caption_text = this.escapeSourceString (host_title + " " + script_manager_version_text)
    handler_path = this.escapeSourceString host_path

    source_text = "rollout " + symbol_name + " \"" + caption_text + "\" width:336 height:720 autoLayoutOnResize:true\n(\n"
    source_text += "    subRollout sr_tools \"\" pos:[12,12] width:312 height:696\n"
    source_text += "    on " + symbol_name + " open do (if script_manager != undefined then script_manager.layoutHostDialog \"" + handler_path + "\" [" + symbol_name + ".width," + symbol_name + ".height])\n"
    source_text += "    on " + symbol_name + " moved dialog_position do (if script_manager != undefined and not script_manager.is_reloading then script_manager.saveHostDialogState \"" + handler_path + "\" save_rollouts:false)\n"
    source_text += "    on " + symbol_name + " resized dialog_size do (if script_manager != undefined then (script_manager.layoutHostDialog \"" + handler_path + "\" dialog_size; if not script_manager.is_reloading then script_manager.saveHostDialogState \"" + handler_path + "\" save_rollouts:false))\n"
    source_text += "    on " + symbol_name + " close do (if script_manager != undefined then script_manager.handleHostDialogClosed \"" + handler_path + "\")\n"
    source_text += "    on " + symbol_name + " help do (if script_manager != undefined then script_manager.reloadLatestManagerScript())\n"
    source_text += ")"

    host_dialog = undefined
    host_index = 0

    try
    (
        execute source_text
        host_dialog = execute symbol_name

        append host_dialogs host_dialog
        append host_dialog_paths host_path
        append host_dialog_symbol_names symbol_name
        host_index = host_dialog_paths.count

        createDialog host_dialog \
            width:336 height:dialog_height pos:dialog_position \
            style:#(#style_titlebar, #style_sysmenu, #style_toolwindow, #style_resizing) \
            lockWidth:true lockHeight:false autoLayoutOnResize:true

        windows.processPostedMessages()
    )
    catch
    (
        exception_text = getCurrentException()
        format "[Script-Manager] Host createDialog failed for %: %\n" host_path exception_text

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

    if not(this.applyHostDockState host_path dock_text) then
    (
        format "[Script-Manager] Host dock state restore failed for %.\n" host_path
    )

    this.layoutHostDialog host_path [host_dialog.width, host_dialog.height]
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

    if not(this.destroyAllHostDialogs clear_rollouts:true) then cleanup_ok = false

    if script_manager_ui == undefined then return cleanup_ok

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

    if not is_in_dialog then return cleanup_ok

    if not(this.clearLoaderRollout()) then cleanup_ok = false
    is_destroying_manager = true

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
    Creates the resizable manager dialog, restores saved state, and enables CUI docking.
    The floating width stays locked while height remains resizable.
    */
    function createManagerDialog =
    (
        dialog_state = this.loadDialogState()
        dialog_position = dialog_state[1]
        dialog_height = dialog_state[2]
        dock_text = dialog_state[3]

        this.registerProjectVersion()

        try
        (
            createDialog script_manager_ui \
                width:336 height:dialog_height pos:dialog_position \
                style:#(#style_titlebar, #style_sysmenu, #style_toolwindow, #style_resizing) \
                lockWidth:true lockHeight:false autoLayoutOnResize:true

            windows.processPostedMessages()
        )
        catch
        (
            exception_text = getCurrentException()
            format "[Script-Manager] createDialog failed: %\n" exception_text
            return false
        )

        try
        (
            cui.RegisterDialogBar script_manager_ui \
                minSize:[336,1796] \
                style:(this.getDialogBarStyles())
        )
        catch
        (
            exception_text = getCurrentException()
            format "[Script-Manager] RegisterDialogBar failed: %\n" exception_text

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

        if not(this.applyDockState dock_text) then
        (
            format "[Script-Manager] Dock state restore failed.\n"
        )

        if not(this.reloadScripts()) then
        (
            is_reloading = false
            format "[Script-Manager] Initial script scan reported failure.\n"
            return false
        )

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

script_manager_version_text = "1.127"
script_manager_title = "Script-Manager " + script_manager_version_text

rollout script_manager_ui script_manager_title width:336 height:1796 autoLayoutOnResize:true
(
    button btn_reload "RELOAD" pos:[12,12] width:96 height:24 tooltip:"LMB: Rescan selected sources and rebuild the loader trees.\n\nRMB: Load the newest Script-Manager version, or restart the current version when no newer file exists."
    button btn_load_scripts "LOAD SCRIPTS" pos:[120,12] width:96 height:24 tooltip:"LMB: Apply the saved SCRIPTS load modes to the currently discovered scripts."
    label lbl_version "Script Manager" pos:[12,42] width:96 height:12 align:#left
    label lbl_status "Not loaded" pos:[120,42] width:204 height:12 align:#left
    subRollout sr_loader "" pos:[12,60] width:312 height:1664

    on script_manager_ui open do
    (
        script_manager.layoutManager [script_manager_ui.width, script_manager_ui.height]
    )

    on script_manager_ui moved dialog_position do
    (
        if not script_manager.is_reloading then script_manager.saveDialogState save_rollouts:false
    )

    on script_manager_ui resized dialog_size do
    (
        script_manager.layoutManager dialog_size
        if not script_manager.is_reloading then script_manager.saveDialogState save_rollouts:false
    )

    on script_manager_ui close do
    (
        if script_manager != undefined and not script_manager.is_destroying_manager then script_manager.saveDialogState save_rollouts:false
    )

    on script_manager_ui help do
    (
        if script_manager != undefined then script_manager.reloadLatestManagerScript()
    )

    on btn_reload pressed do
    (
        script_manager.reloadScripts()
    )

    on btn_load_scripts pressed do
    (
        script_manager.loadScripts()
    )

    on btn_reload rightclick do
    (
        script_manager.reloadLatestManagerScript()
    )
)

script_manager = script_manager_v()
script_manager.manager_source_path = getSourceFileName()
script_manager.root_directory = script_manager.getProjectRootDirectory()
if script_manager.debug_logging then format "[Script-Manager] MANAGER SOURCE: %\n" script_manager.manager_source_path
if script_manager.debug_logging then format "[Script-Manager] MANAGED ROOT: %\n" script_manager.root_directory
script_manager.registerProjectVersion()
if SCRIPT_MANAGER_AUTO_OPEN then script_manager.createManagerDialog()
