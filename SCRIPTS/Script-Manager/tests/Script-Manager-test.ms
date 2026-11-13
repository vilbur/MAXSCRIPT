/*
    Script-Manager regression test 1.205.
    Tests production version identity, source selection, filters, persistent tri-state load modes, toolbar generation, tree menus, and dedicated script-load behavior.
*/

global script_manager_test_file_version = 1.205
global script_manager_test_project_version = 1.211
global script_manager_test_root = getFilenamePath (getSourceFileName())
global script_manager_test_passed = true
global script_manager_test_original_root
global script_manager_test_original_ini
global script_manager_test_temp_root
global script_manager_test_marker_a
global script_manager_test_marker_b
global script_manager_test_marker_c
global script_manager_test_marker_d
global script_manager_test_marker_e
global script_manager_test_marker_f
global script_manager_test_marker_g
global script_manager_test_host_reload_rollout
global script_manager_test_forced_rollout
global script_manager_test_forced_mode

/*
Creates one plain MaxScript file used by the isolated loader tests.
*/
function writeScriptManagerTestScript script_path script_body =
(
    file_stream = createFile script_path
    if file_stream == undefined then return false

    format "%\n" script_body to:file_stream
    close file_stream
    true
    -- return
)

/*
Reads one plain text file used by generated preset-loader regression checks.
*/
function readScriptManagerTestFileText file_path =
(
    if not(doesFileExist file_path) then return undefined

    file_stream = openFile file_path
    if file_stream == undefined then return undefined

    file_text = ""

    while not(eof file_stream) do
    (
        file_text += (readLine file_stream) + "\n"
    )

    close file_stream
    file_text
    -- return
)

/*
Returns whether one TreeNode collection contains the requested visible text anywhere below it.
*/
function scriptManagerTestTreeContainsText node_collection target_text =
(
    if node_collection == undefined or target_text == undefined then return false

    target_lower = toLower target_text
    item_found = false

    for node_index = 0 to (node_collection.Count - 1) while not item_found do
    (
        tree_node = node_collection.Item[node_index]
        if (toLower tree_node.Text) == target_lower then
        (
            item_found = true
        )
        else if tree_node.Nodes.Count > 0 then
        (
            item_found = scriptManagerTestTreeContainsText tree_node.Nodes target_text
        )
    )

    item_found
    -- return
)

/*
Loads production and verifies one synchronized version number plus required UI controls.
*/
function partOfTest1 =
(
    production_path = script_manager_test_root + "Script-Manager.ms"

    if not(doesFileExist production_path) then
    (
        test_directory = ScriptManagerIntegration.normalizeDirectoryPath script_manager_test_root
        test_directory_no_slash = substring test_directory 1 (test_directory.count - 1)
        production_path = ScriptManagerIntegration.normalizeDirectoryPath (pathConfig.removePathLeaf test_directory_no_slash) + "Script-Manager.ms"
    )

    SCRIPT_MANAGER_RUNTIME_MODE = #standalone
    fileIn production_path quiet:true

    script_manager_test_original_root = script_manager.root_directory
    script_manager_test_original_ini = script_manager.ini_path
    expected_ini_path = ScriptManagerIntegration.normalizeDirectoryPath (getFilenamePath script_manager.manager_source_path) + "script_manager.ini"
    settings_path_ok = script_manager.ini_path == expected_ini_path

    version_ok = script_manager.file_version == 1.211 and script_manager.project_version == 1.211 and ScriptManagerIntegration.file_version == 1.211 and ScriptManagerIntegration.project_version == 1.211
    global_version_ok = script_manager_project_version == 1.211
    title_ok = script_manager_ui.title == "Script-Manager 1.211"
    main_action_ok = isProperty script_manager_ui #btn_refresh_restart and (script_manager_ui.btn_refresh_restart.GetType()).FullName == "System.Windows.Forms.Button"
    main_action_style_ok = main_action_ok and script_manager_ui.btn_refresh_restart.Text == "REFRESH \\ RESTART  |  v1.211" and script_manager_ui.btn_refresh_restart.height == 18 and script_manager_ui.btn_refresh_restart.FlatAppearance.BorderSize == 0 and script_manager_ui.btn_refresh_restart.BackColor.R == 45 and script_manager_ui.btn_refresh_restart.BackColor.G == 45 and script_manager_ui.btn_refresh_restart.BackColor.B == 48 and script_manager_ui.btn_refresh_restart.ForeColor.R == 62 and script_manager_ui.btn_refresh_restart.ForeColor.G == 158 and script_manager_ui.btn_refresh_restart.ForeColor.B == 255 and not script_manager_ui.btn_refresh_restart.TabStop and script_manager_ui.btn_refresh_restart.Font.Name == "Segoe UI" and script_manager_ui.btn_refresh_restart.Font.Size == 14.0 and script_manager_ui.btn_refresh_restart.Font.Bold
    production_text = readScriptManagerTestFileText production_path
    main_action_direct_ok = production_text != undefined and (findString production_text "on btn_refresh_restart MouseUp") != undefined and (findString production_text "scriptManagerRefreshButtonMouseUpHandler sender event_args") != undefined and (findString production_text "on btn_refresh_restart Click") == undefined and (findString production_text "tmr_refresh_restart") == undefined
    single_tree_init_ok = production_text != undefined and (findString production_text "on script_manager_sources_ui open do") != undefined and (findString production_text "on script_manager_scripts_ui open do") != undefined and isProperty script_manager #populateInitialSourceTree and isProperty script_manager #populateInitialScriptTree
    preset_rollout_ok = script_manager_presets_ui != undefined and script_manager_presets_ui.title == "PRESETS" and isProperty script_manager_presets_ui #ddl_presets and isProperty script_manager_presets_ui #btn_preset_save_remove and isProperty script_manager_presets_ui #btn_preset_load and isProperty script_manager_presets_ui #btn_preset_macro and isProperty script_manager_presets_ui #btn_preset_startup
    options_rollout_ok = script_manager_options_ui != undefined and script_manager_options_ui.title == "OPTIONS" and script_manager.getSourceRootPathControl() != undefined and script_manager_options_ui.btn_source_root_browse != undefined
    source_rollout_ok = script_manager_sources_ui != undefined and script_manager_sources_ui.title == "SOURCES" and isProperty script_manager_sources_ui #tv_sources and not(isProperty script_manager_sources_ui #edt_source_ignore) and not(isProperty script_manager_sources_ui #btn_reload)
    show_ignore_rollout_ok = script_manager_show_ui != undefined and script_manager_show_ui.title == "SHOW" and isProperty script_manager_show_ui #chk_show_versions and isProperty script_manager_show_ui #chk_clean_scripts and isProperty script_manager_show_ui #chk_collapse_dirs and script_manager_ignore_ui != undefined and script_manager_ignore_ui.title == "IGNORE" and isProperty script_manager_ignore_ui #edt_script_ignore and isProperty script_manager_options_ui #sr_show and isProperty script_manager_options_ui #sr_ignore
    script_rollout_ok = script_manager_scripts_ui != undefined and script_manager_scripts_ui.title == "SCRIPTS" and isProperty script_manager_scripts_ui #btn_load_scripts and isProperty script_manager_scripts_ui #btn_create_toolbar and isProperty script_manager_scripts_ui #btn_save_toolbar_ui and isProperty script_manager_scripts_ui #edt_scripts_filter and not(isProperty script_manager_scripts_ui #sr_show_ignore) and not(isProperty script_manager_scripts_ui #edt_script_ignore) and script_manager_scripts_ui.btn_save_toolbar_ui.checked and not(isProperty script_manager_scripts_ui #ddl_presets)
    ignore_tooltip_ok = show_ignore_rollout_ok and (findString script_manager_ignore_ui.edt_script_ignore.tooltip "saved to script_manager.ini") != undefined and (findString script_manager_ignore_ui.edt_script_ignore.tooltip "LMB REFRESH") != undefined
    root_tooltip_ok = options_rollout_ok and (findString script_manager_options_ui.edt_source_root.tooltip "only when you press LMB REFRESH") != undefined
    root_single_line_ok = options_rollout_ok and script_manager_options_ui.edt_source_root.height < 17
    ignore_width_ok = show_ignore_rollout_ok and script_manager_ignore_ui.edt_script_ignore.width >= 276
    ignore_single_line_ok = show_ignore_rollout_ok and script_manager_ignore_ui.edt_script_ignore.height < 17
    soft_hard_api_ok = isProperty script_manager #updateScripts and isProperty script_manager #loadScripts and isProperty script_manager #isManagedScriptRunning and isProperty script_manager #loadSingleScriptForcedDirect and isProperty script_manager #closeExistingStandaloneRolloutsForSources
    source_tree_ok = script_manager.getSourceTreeControl() != undefined and script_manager.getSourceRootPathControl() != undefined and isProperty script_manager #saveSourceRootDirectory and isProperty script_manager #loadSourceRootDirectory and isProperty script_manager #applyPendingSourceOptions and isProperty script_manager #handleManualRefresh
    script_tree_ok = script_manager.getScriptTreeControl() != undefined and script_manager.getScriptIgnoreMaskControl() != undefined and isProperty script_manager #applyPendingScriptOptions and isProperty script_manager #saveScriptIgnoreMask and isProperty script_manager #loadScriptIgnoreMask and isProperty script_manager #buildScriptIgnorePatterns and isProperty script_manager #doesScriptTreeNameMatchIgnore and isProperty script_manager #isScriptTreeDirectoryIgnored and isProperty script_manager #isScriptTreeScriptIgnored and isProperty script_manager #shouldDisplayScriptTreeDirectory and isProperty script_manager #ensureScriptTreeFolderPath and isProperty script_manager #getScriptTreeSourceDisplayPath and isProperty script_manager #available_group_tree_paths and isProperty script_manager #available_script_tree_group_paths
    source_height_ok = source_tree_ok and script_manager_sources_ui.tv_sources.height >= 512
    script_height_ok = script_tree_ok and script_manager_scripts_ui.tv_scripts.height >= 1032
    source_mixed_ui_ok = source_tree_ok and not(script_manager_sources_ui.tv_sources.CheckBoxes) and script_manager_sources_ui.tv_sources.ImageList != undefined and script_manager_sources_ui.tv_sources.ImageList.Images.Count >= 3
    tristate_ui_ok = script_tree_ok and not(script_manager_scripts_ui.tv_scripts.CheckBoxes) and script_manager_scripts_ui.tv_scripts.ImageList != undefined and script_manager_scripts_ui.tv_scripts.ImageList.Images.Count >= 3
    loader_only_ok = not(isProperty script_manager_ui #sr_tools)
    host_model_ok = isProperty script_manager #host_dialogs and isProperty script_manager #host_dialog_paths and isProperty script_manager #loaded_host_script_paths and isProperty script_manager #loaded_host_script_dialog_paths
    clean_filter_ok = show_ignore_rollout_ok
    preset_ui_ok = preset_rollout_ok
    preset_neutral_ok = preset_ui_ok and script_manager_presets_ui.ddl_presets.items.count >= 1 and script_manager_presets_ui.ddl_presets.items[1] == "<Preset>" and script_manager_presets_ui.ddl_presets.selection == 1 and not(script_manager_presets_ui.btn_preset_startup.checked)
    preset_api_ok = isProperty script_manager #savePreset and isProperty script_manager #loadPreset and isProperty script_manager #loadPresetAndScripts and isProperty script_manager #removePreset and isProperty script_manager #getPresetNames and isProperty script_manager #refreshPresetDropdown and isProperty script_manager #getStartupPresetName and isProperty script_manager #setStartupPreset and isProperty script_manager #clearStartupPreset and isProperty script_manager #loadStartupPresetOnce and isProperty script_manager #createPresetMacro and isProperty script_manager #buildPresetMacroBody
    rollout_state_ok = isProperty script_manager #preset_rollout_open and isProperty script_manager #options_rollout_open and isProperty script_manager #source_rollout_open and isProperty script_manager #show_rollout_open and isProperty script_manager #ignore_rollout_open and isProperty script_manager #script_rollout_open
    context_menu_ok = script_manager.source_tree_context_menu != undefined and script_manager.source_tree_load_dialog_item != undefined and script_manager.script_tree_open_group_item != undefined and script_manager.script_tree_load_item != undefined and script_manager.script_tree_open_explorer_item != undefined and script_manager.script_tree_expand_all_item != undefined and script_manager.script_tree_expand_enabled_item != undefined and script_manager.script_tree_collapse_all_item != undefined
    source_dialog_api_ok = isProperty script_manager #getBatchOverridePathForScript and isProperty script_manager #getConfiguredHostScriptPaths and isProperty script_manager #isSourceDirectoryBatchDialog and isProperty script_manager #getSelectedSourceDialogPath and isProperty script_manager #loadConfiguredHostDialogScripts and isProperty script_manager #loadSelectedSourceDialog

    test_ok = settings_path_ok and version_ok and global_version_ok and title_ok and main_action_ok and main_action_style_ok and main_action_direct_ok and single_tree_init_ok and preset_rollout_ok and options_rollout_ok and source_rollout_ok and show_ignore_rollout_ok and ignore_tooltip_ok and root_tooltip_ok and root_single_line_ok and ignore_width_ok and ignore_single_line_ok and script_rollout_ok and soft_hard_api_ok and source_tree_ok and script_tree_ok and source_height_ok and script_height_ok and source_mixed_ui_ok and tristate_ui_ok and loader_only_ok and host_model_ok and clean_filter_ok and preset_ui_ok and preset_neutral_ok and preset_api_ok and rollout_state_ok and context_menu_ok and source_dialog_api_ok
    if not test_ok then script_manager_test_passed = false

    format "PART 1 | settings-path:% | version:% | global:% | title:% | main-action:% | main-action-style:% | main-action-direct:% | single-init:% | presets-rollout:% | options-rollout:% | source-rollout:% | show-ignore-rollout:% | ignore-tooltip:% | root-tooltip:% | root-single-line:% | ignore-width:% | ignore-single-line:% | script-rollout:% | soft-hard:% | sources:% | scripts:% | source-512:% | script-1032:% | source-mixed-ui:% | tristate-ui:% | loader-only:% | host-model:% | clean-filter:% | preset-ui:% | preset-neutral:% | preset-api:% | rollout-state:% | tree-menu:% | source-dialog-api:% | PASS:%\n" settings_path_ok version_ok global_version_ok title_ok main_action_ok main_action_style_ok main_action_direct_ok single_tree_init_ok preset_rollout_ok options_rollout_ok source_rollout_ok show_ignore_rollout_ok ignore_tooltip_ok root_tooltip_ok root_single_line_ok ignore_width_ok ignore_single_line_ok script_rollout_ok soft_hard_api_ok source_tree_ok script_tree_ok source_height_ok script_height_ok source_mixed_ui_ok tristate_ui_ok loader_only_ok host_model_ok clean_filter_ok preset_ui_ok preset_neutral_ok preset_api_ok rollout_state_ok context_menu_ok source_dialog_api_ok test_ok
    test_ok
    -- return
)

/*
Builds an isolated temporary source tree and verifies that IGNORE is a persisted SCRIPTS-only filter.
*/
function partOfTest2 =
(
    script_manager_test_temp_root = ScriptManagerIntegration.normalizeDirectoryPath ((getDir #temp) + "\\Script-Manager-Test-Root")
    source_a = script_manager_test_temp_root + "SourceA\\"
    source_a_category = source_a + "Category\\"
    source_a_leaf = source_a + "ToolLeaf\\"
    source_a_nested_leaf = source_a_category + "ToolNested\\"
    source_a_nested_hidden_child = source_a_nested_leaf + "Internal\\"
    source_a_generic_leaf = source_a_category + "LooseTool\\"
    source_a_empty_leaf = source_a_category + "EmptyTool\\"
    source_a_pending = source_a_category + "PendingTools\\"
    source_a_git = source_a_category + ".git\\"
    source_a_deleted = source_a_category + "Archive-DELETED\\"
    source_a_old = source_a_category + "Backup-OLD\\"
    source_b = script_manager_test_temp_root + "SourceB\\"
    source_a_ignored_script = source_a + "Scratch-OLD.ms"

    makeDir script_manager_test_temp_root
    makeDir source_a
    makeDir source_a_category
    makeDir source_a_leaf
    makeDir source_a_nested_leaf
    makeDir source_a_nested_hidden_child
    makeDir source_a_generic_leaf
    makeDir source_a_empty_leaf
    makeDir source_a_pending
    makeDir source_a_git
    makeDir source_a_deleted
    makeDir source_a_old
    makeDir source_b

    writeScriptManagerTestScript (source_a_leaf + "ToolLeaf.ms") "global script_manager_test_source_leaf; script_manager_test_source_leaf = true"
    writeScriptManagerTestScript (source_a_nested_leaf + "ToolNested.ms") "global script_manager_test_source_nested_leaf; script_manager_test_source_nested_leaf = true"
    writeScriptManagerTestScript (source_a_nested_hidden_child + "Helper.ms") "global script_manager_test_source_hidden_helper; script_manager_test_source_hidden_helper = true"
    writeScriptManagerTestScript (source_a_generic_leaf + "DifferentName.ms") "global script_manager_test_source_generic_leaf; script_manager_test_source_generic_leaf = true"
    writeScriptManagerTestScript (source_a_pending + "notes.txt") "Pending organizational directory without a same-name MaxScript file."
    writeScriptManagerTestScript (source_a_git + "HiddenGit.ms") "global script_manager_test_source_git; script_manager_test_source_git = true"
    writeScriptManagerTestScript (source_a_deleted + "HiddenDeleted.ms") "global script_manager_test_source_deleted; script_manager_test_source_deleted = true"
    writeScriptManagerTestScript (source_a_old + "HiddenOld.ms") "global script_manager_test_source_old; script_manager_test_source_old = true"
    writeScriptManagerTestScript source_a_ignored_script "global script_manager_test_ignored_file; script_manager_test_ignored_file = true"
    writeScriptManagerTestScript (source_b + "SourceB.ms") "global script_manager_test_source_b; script_manager_test_source_b = true"

    test_ini = (getDir #temp) + "\\Script-Manager-Test.ini"
    if doesFileExist test_ini then deleteFile test_ini

    script_manager.root_directory = script_manager_test_temp_root
    script_manager.ini_path = test_ini
    script_manager.show_versioned_files = false

    default_ignore_mask = script_manager.loadScriptIgnoreMask()
    default_ignore_load_ok = default_ignore_mask == ".git" and script_manager.source_ignore_mask == ".git"
    default_source_discovery_ok = script_manager.discoverSources()
    default_git_visible_ok = (findItem script_manager.available_source_directories source_a_git) == 0
    default_deleted_visible_ok = (findItem script_manager.available_source_directories source_a_deleted) > 0
    default_old_visible_ok = (findItem script_manager.available_source_directories source_a_old) > 0

    remembered_ignore_mask = ".git|.*-DELETED|*-OLD|"
    ignore_change_deferred_ok = script_manager.handleScriptIgnoreMaskChanged remembered_ignore_mask and not(hasINISetting test_ini "Filter" "ScriptIgnoreMask") and script_manager.source_ignore_mask == ".git"
    source_tree_unchanged_ok = (findItem script_manager.available_source_directories source_a_git) == 0 and (findItem script_manager.available_source_directories source_a_deleted) > 0 and (findItem script_manager.available_source_directories source_a_old) > 0

    options_draft_ok = false
    source_options_apply_ok = false
    script_options_apply_ok = false
    root_persist_ok = false
    ignore_persist_ok = false

    if script_manager_options_ui != undefined and script_manager_ignore_ui != undefined and isProperty script_manager_options_ui #edt_source_root and isProperty script_manager_ignore_ui #edt_script_ignore then
    (
        script_manager_options_ui.edt_source_root.text = script_manager_test_temp_root
        script_manager_ignore_ui.edt_script_ignore.text = remembered_ignore_mask
        options_draft_ok = not(hasINISetting test_ini "Options" "SourceRootDirectory") and not(hasINISetting test_ini "Filter" "ScriptIgnoreMask")

        source_options_apply_ok = script_manager.applyPendingSourceOptions()
        script_options_apply_ok = script_manager.applyPendingScriptOptions()
        root_persist_ok = ScriptManagerIntegration.normalizeDirectoryPath (getINISetting test_ini "Options" "SourceRootDirectory") == script_manager_test_temp_root and script_manager.root_directory == script_manager_test_temp_root
        ignore_persist_ok = (getINISetting test_ini "Filter" "ScriptIgnoreMask") == remembered_ignore_mask and script_manager.source_ignore_mask == remembered_ignore_mask
    )

    script_manager.root_directory = ""
    root_restore_ok = script_manager.loadSourceRootDirectory() == script_manager_test_temp_root and script_manager.root_directory == script_manager_test_temp_root
    script_manager.source_ignore_mask = ".git"
    script_manager.source_ignore_patterns = script_manager.buildScriptIgnorePatterns ".git"
    script_manager.source_ignore_regexes = script_manager.source_ignore_patterns
    ignore_restore_ok = script_manager.loadScriptIgnoreMask() == remembered_ignore_mask and script_manager.source_ignore_mask == remembered_ignore_mask
    ignore_matcher_ok = script_manager.isScriptTreeDirectoryIgnored source_a_git and script_manager.isScriptTreeDirectoryIgnored source_a_deleted and script_manager.isScriptTreeDirectoryIgnored source_a_old and script_manager.isScriptTreeScriptIgnored source_a_ignored_script and not(script_manager.isScriptTreeDirectoryIgnored source_a_generic_leaf)

    custom_source_discovery_ok = script_manager.discoverSources()
    ignored_sources_still_visible_ok = (findItem script_manager.available_source_directories source_a_git) == 0 and (findItem script_manager.available_source_directories source_a_deleted) > 0 and (findItem script_manager.available_source_directories source_a_old) > 0

    ignore_source_enable_ok = script_manager.saveSourceEnabled source_a true
    ignore_script_discovery_ok = script_manager.discoverScripts() and \
        (findItem script_manager.available_script_paths (source_a_git + "HiddenGit.ms")) == 0 and \
        (findItem script_manager.available_script_paths (source_a_deleted + "HiddenDeleted.ms")) == 0 and \
        (findItem script_manager.available_script_paths (source_a_old + "HiddenOld.ms")) == 0 and \
        (findItem script_manager.available_script_paths source_a_ignored_script) == 0 and \
        (findItem script_manager.available_group_directories source_a_git) == 0 and \
        (findItem script_manager.available_group_directories source_a_deleted) == 0 and \
        (findItem script_manager.available_group_directories source_a_old) == 0
    script_tree_populate_ok = script_manager.populateScriptTree()
    script_tree = script_manager.getScriptTreeControl()
    ignored_tree_items_hidden_ok = script_tree_populate_ok and script_tree != undefined and \
        not(scriptManagerTestTreeContainsText script_tree.Nodes ".git") and \
        not(scriptManagerTestTreeContainsText script_tree.Nodes "Archive-DELETED") and \
        not(scriptManagerTestTreeContainsText script_tree.Nodes "Backup-OLD") and \
        not(scriptManagerTestTreeContainsText script_tree.Nodes "Scratch-OLD.ms")
    script_manager.saveSourceEnabled source_a false

    migration_seed_nested_ok = script_manager.saveSourceEnabled source_a_nested_leaf true
    migration_seed_generic_ok = script_manager.saveSourceEnabled source_a_generic_leaf true
    migration_seed_ok = migration_seed_nested_ok and migration_seed_generic_ok
    source_ok = script_manager.discoverSources()
    source_a_index = findItem script_manager.available_source_directories source_a
    category_index = findItem script_manager.available_source_directories source_a_category
    root_leaf_index = findItem script_manager.available_source_directories source_b
    tool_leaf_index = findItem script_manager.available_source_directories source_a_leaf
    nested_tool_leaf_index = findItem script_manager.available_source_directories source_a_nested_leaf
    hidden_child_index = findItem script_manager.available_source_directories source_a_nested_hidden_child
    generic_leaf_index = findItem script_manager.available_source_directories source_a_generic_leaf
    empty_leaf_index = findItem script_manager.available_source_directories source_a_empty_leaf
    pending_index = findItem script_manager.available_source_directories source_a_pending

    source_a_visible = source_a_index > 0 and script_manager.available_source_selectable[source_a_index]
    category_visible = category_index > 0 and script_manager.available_source_selectable[category_index]
    root_stopper_display_ok = root_leaf_index > 0 and not(script_manager.available_source_selectable[root_leaf_index]) and script_manager.available_source_names[root_leaf_index] == "SourceB"
    tool_leaf_display_ok = tool_leaf_index > 0 and not(script_manager.available_source_selectable[tool_leaf_index]) and script_manager.available_source_names[tool_leaf_index] == "ToolLeaf"
    nested_tool_leaf_display_ok = nested_tool_leaf_index > 0 and not(script_manager.available_source_selectable[nested_tool_leaf_index]) and script_manager.available_source_names[nested_tool_leaf_index] == "ToolNested"
    hierarchy_stopper_ok = hidden_child_index == 0
    generic_leaf_display_ok = generic_leaf_index > 0 and script_manager.available_source_selectable[generic_leaf_index] and script_manager.available_source_names[generic_leaf_index] == "LooseTool"
    empty_leaf_display_ok = empty_leaf_index == 0
    pending_source_ok = pending_index == 0
    migration_ok = migration_seed_ok and script_manager.getSourceEnabled source_a_category and not(script_manager.getSourceEnabled source_a_nested_leaf) and script_manager.getSourceEnabled source_a_generic_leaf

    populate_ok = script_manager.populateSourceTree()
    source_tree = script_manager.getSourceTreeControl()
    source_a_node = undefined
    source_b_node = undefined
    category_node = undefined
    tool_leaf_node = undefined
    nested_tool_leaf_node = undefined
    generic_leaf_node = undefined
    empty_leaf_node = undefined
    pending_node = undefined

    if source_tree != undefined then
    (
        for root_index = 0 to (source_tree.Nodes.Count - 1) do
        (
            candidate_node = source_tree.Nodes.Item[root_index]
            if candidate_node.Text == "SourceA" then source_a_node = candidate_node
            if candidate_node.Text == "SourceB" then source_b_node = candidate_node
        )
    )

    if source_a_node != undefined then
    (
        for child_index = 0 to (source_a_node.Nodes.Count - 1) do
        (
            candidate_node = source_a_node.Nodes.Item[child_index]
            if candidate_node.Text == "Category" then category_node = candidate_node
            if candidate_node.Text == "ToolLeaf" then tool_leaf_node = candidate_node
        )
    )

    if category_node != undefined then
    (
        for child_index = 0 to (category_node.Nodes.Count - 1) do
        (
            candidate_node = category_node.Nodes.Item[child_index]
            if candidate_node.Text == "ToolNested" then nested_tool_leaf_node = candidate_node
            if candidate_node.Text == "LooseTool" then generic_leaf_node = candidate_node
            if candidate_node.Text == "EmptyTool" then empty_leaf_node = candidate_node
            if candidate_node.Text == "PendingTools" then pending_node = candidate_node
        )
    )

    source_row_visual_ok = \
        source_a_node != undefined and source_a_node.Name == "SOURCE_SELECTABLE" and source_a_node.ImageIndex >= 1 and \
        source_b_node != undefined and source_b_node.Name == "SOURCE_TOOL" and source_b_node.ImageIndex == 0 and \
        category_node != undefined and category_node.Name == "SOURCE_SELECTABLE" and category_node.ImageIndex >= 1 and \
        tool_leaf_node != undefined and tool_leaf_node.Name == "SOURCE_TOOL" and tool_leaf_node.ImageIndex == 0 and \
        nested_tool_leaf_node != undefined and nested_tool_leaf_node.Name == "SOURCE_TOOL" and nested_tool_leaf_node.ImageIndex == 0 and \
        generic_leaf_node != undefined and generic_leaf_node.Name == "SOURCE_SELECTABLE" and generic_leaf_node.ImageIndex >= 1 and \
        empty_leaf_node == undefined and pending_node == undefined

    test_ok = default_ignore_load_ok and default_source_discovery_ok and default_git_visible_ok and default_deleted_visible_ok and default_old_visible_ok and ignore_change_deferred_ok and source_tree_unchanged_ok and options_draft_ok and source_options_apply_ok and script_options_apply_ok and root_persist_ok and ignore_persist_ok and root_restore_ok and ignore_restore_ok and ignore_matcher_ok and custom_source_discovery_ok and ignored_sources_still_visible_ok and ignore_source_enable_ok and ignore_script_discovery_ok and ignored_tree_items_hidden_ok and source_ok and source_a_visible and category_visible and root_stopper_display_ok and tool_leaf_display_ok and nested_tool_leaf_display_ok and hierarchy_stopper_ok and generic_leaf_display_ok and empty_leaf_display_ok and pending_source_ok and migration_ok and populate_ok and source_row_visual_ok
    if not test_ok then script_manager_test_passed = false

    format "PART 2 | ignore-default:% | .git-source-hidden:% | deleted-source-visible:% | old-source-visible:% | ignore-deferred:% | source-tree-unchanged:% | options-draft:% | source-options:% | script-options:% | root-persist:% | ignore-persist:% | root-restore:% | ignore-restore:% | matcher:% | sources-unfiltered:% | scripts-filtered:% | tree-filtered:% | source-A:% | category:% | root-same-name-stopper:% | same-name-tool:% | nested-same-name-tool:% | stopper-hides-children:% | different-name-terminal-selectable:% | empty-hidden:% | pending-hidden:% | migrate:% | row-visual:% | PASS:%\n" default_ignore_load_ok default_git_visible_ok default_deleted_visible_ok default_old_visible_ok ignore_change_deferred_ok source_tree_unchanged_ok options_draft_ok source_options_apply_ok script_options_apply_ok root_persist_ok ignore_persist_ok root_restore_ok ignore_restore_ok ignore_matcher_ok (custom_source_discovery_ok and ignored_sources_still_visible_ok) (ignore_source_enable_ok and ignore_script_discovery_ok) ignored_tree_items_hidden_ok source_a_visible category_visible root_stopper_display_ok tool_leaf_display_ok nested_tool_leaf_display_ok hierarchy_stopper_ok generic_leaf_display_ok empty_leaf_display_ok pending_source_ok migration_ok source_row_visual_ok test_ok
    test_ok
    -- return
)

/*
Verifies source selections, script-bearing directory pruning, and selected-source roots.
*/
function partOfTest3 =
(
    source_a = script_manager_test_temp_root + "SourceA\\"
    source_b = script_manager_test_temp_root + "SourceB\\"

    save_a_ok = script_manager.saveSourceEnabled source_a true
    save_b_ok = script_manager.saveSourceEnabled source_b false
    persisted_ok = script_manager.getSourceEnabled source_a and not(script_manager.getSourceEnabled source_b)

    write_a_ok = writeScriptManagerTestScript (source_a + "SourceA.ms") "global script_manager_test_marker_a; script_manager_test_marker_a = 10"
    write_b_ok = writeScriptManagerTestScript (source_b + "SourceB.ms") "global script_manager_test_marker_b; script_manager_test_marker_b = 20"

    discover_ok = script_manager.discoverScripts()
    source_a_found = (findItem script_manager.available_script_paths (source_a + "SourceA.ms")) > 0
    source_b_hidden = (findItem script_manager.available_script_paths (source_b + "SourceB.ms")) == 0

    leaf_path = source_a + "ToolLeaf\\ToolLeaf.ms"
    nested_path = source_a + "Category\\ToolNested\\ToolNested.ms"
    root_script_index = findItem script_manager.available_script_paths (source_a + "SourceA.ms")
    leaf_script_index = findItem script_manager.available_script_paths leaf_path
    nested_script_index = findItem script_manager.available_script_paths nested_path

    root_group_kept_ok = root_script_index > 0 and script_manager.getScriptTreeDisplayGroupPath root_script_index == "SourceA"
    leaf_flatten_ok = leaf_script_index > 0 and script_manager.getScriptTreeDisplayGroupPath leaf_script_index == "SourceA"
    nested_flatten_ok = nested_script_index > 0 and script_manager.getScriptTreeDisplayGroupPath nested_script_index == "SourceA\\Category"

    pending_group_path = "SourceA\\Category\\PendingTools"
    pending_group_discovered_ok = (findItem script_manager.available_group_paths pending_group_path) == 0
    populate_tree_ok = script_manager.populateScriptTree()
    script_tree = script_manager.getScriptTreeControl()
    pending_tree_node = undefined

    if script_tree != undefined then
    (
        for root_index = 0 to (script_tree.Nodes.Count - 1) do
        (
            source_node = script_tree.Nodes.Item[root_index]
            if source_node.Text == "SourceA" then
            (
                for category_index = 0 to (source_node.Nodes.Count - 1) do
                (
                    category_node = source_node.Nodes.Item[category_index]
                    if category_node.Text == "Category" then
                    (
                        folder_font_ok = category_node.NodeFont != undefined and category_node.NodeFont.Bold
                        for pending_index = 0 to (category_node.Nodes.Count - 1) do
                        (
                            candidate_node = category_node.Nodes.Item[pending_index]
                            if candidate_node.Text == "PendingTools" then pending_tree_node = candidate_node
                        )
                    )
                )
            )
        )
    )

    pending_tree_visible_ok = populate_tree_ok and pending_tree_node == undefined

    category_source = source_a + "Category\\"
    child_source_seed_ok = script_manager.saveSourceEnabled source_a false and script_manager.saveSourceEnabled category_source true
    child_source_discover_ok = child_source_seed_ok and script_manager.discoverScripts()
    child_nested_index = findItem script_manager.available_script_paths nested_path
    child_source_path_ok = child_nested_index > 0 and script_manager.getScriptTreeDisplayGroupPath child_nested_index == "Category"
    child_source_populate_ok = child_source_discover_ok and script_manager.populateScriptTree()
    child_source_tree = script_manager.getScriptTreeControl()
    unselected_parent_hidden_ok = true
    selected_child_root_visible_ok = false

    if child_source_tree != undefined then
    (
        for root_index = 0 to (child_source_tree.Nodes.Count - 1) do
        (
            candidate_root = child_source_tree.Nodes.Item[root_index]
            if candidate_root.Text == "SourceA" then unselected_parent_hidden_ok = false
            if candidate_root.Text == "Category" then selected_child_root_visible_ok = true
        )
    )

    child_source_wrapper_ok = child_source_populate_ok and child_source_path_ok and unselected_parent_hidden_ok and selected_child_root_visible_ok
    source_restore_ok = script_manager.saveSourceEnabled category_source false and script_manager.saveSourceEnabled source_a true and script_manager.discoverScripts() and script_manager.populateScriptTree()

    test_ok = save_a_ok and save_b_ok and persisted_ok and write_a_ok and write_b_ok and discover_ok and source_a_found and source_b_hidden and root_group_kept_ok and leaf_flatten_ok and nested_flatten_ok and pending_group_discovered_ok and pending_tree_visible_ok and folder_font_ok and child_source_wrapper_ok and source_restore_ok
    if not test_ok then script_manager_test_passed = false

    format "PART 3 | persisted:% | A:% | B-hidden:% | root-kept:% | leaf-flat:% | nested-flat:% | no-script-group-pruned:% | group-hidden:% | folder-bold:% | checked-child-is-root:% | PASS:%\n" persisted_ok source_a_found source_b_hidden root_group_kept_ok leaf_flatten_ok nested_flatten_ok pending_group_discovered_ok pending_tree_visible_ok folder_font_ok child_source_wrapper_ok test_ok
    test_ok
    -- return
)

/*
Verifies default filtering prefers an unversioned canonical script, otherwise only the newest numeric version.
*/
function partOfTest4 =
(
    source_a = script_manager_test_temp_root + "SourceA\\"

    writeScriptManagerTestScript (source_a + "Tool.ms") "global script_manager_test_marker_c; script_manager_test_marker_c = 1"
    writeScriptManagerTestScript (source_a + "Tool_0.01.ms") "global script_manager_test_marker_c; script_manager_test_marker_c = 2"
    writeScriptManagerTestScript (source_a + "Tool_0.02.ms") "global script_manager_test_marker_c; script_manager_test_marker_c = 3"
    writeScriptManagerTestScript (source_a + "Only_0.01.ms") "global script_manager_test_marker_c; script_manager_test_marker_c = 4"
    writeScriptManagerTestScript (source_a + "Only_0.03.ms") "global script_manager_test_marker_c; script_manager_test_marker_c = 5"
    writeScriptManagerTestScript (source_a + "Dual.ms") "global script_manager_test_marker_c; script_manager_test_marker_c = 6"
    writeScriptManagerTestScript (source_a + "Dual.mcr") "global script_manager_test_marker_c; script_manager_test_marker_c = 7"

    script_manager.show_versioned_files = false
    visible_files = script_manager.getScriptFilesInDirectory source_a

    canonical_ok = (findItem visible_files (source_a + "Tool.ms")) > 0
    old_tool_hidden = (findItem visible_files (source_a + "Tool_0.01.ms")) == 0 and (findItem visible_files (source_a + "Tool_0.02.ms")) == 0
    newest_only_ok = (findItem visible_files (source_a + "Only_0.03.ms")) > 0 and (findItem visible_files (source_a + "Only_0.01.ms")) == 0
    same_name_ms_preferred_ok = (findItem visible_files (source_a + "Dual.ms")) > 0 and (findItem visible_files (source_a + "Dual.mcr")) == 0

    test_ok = canonical_ok and old_tool_hidden and newest_only_ok and same_name_ms_preferred_ok
    if not test_ok then script_manager_test_passed = false

    format "PART 4 | canonical:% | old-hidden:% | newest:% | ms-over-mcr:% | PASS:%\n" canonical_ok old_tool_hidden newest_only_ok same_name_ms_preferred_ok test_ok
    test_ok
    -- return
)

/*
Verifies SHOW VERSIONED FILES exposes every versioned source file.
*/
function partOfTest5 =
(
    source_a = script_manager_test_temp_root + "SourceA\\"
    script_manager.show_versioned_files = true
    script_manager.show_clean_scripts_only = false
    visible_files = script_manager.getScriptFilesInDirectory source_a

    all_versions_ok = \
        (findItem visible_files (source_a + "Tool.ms")) > 0 and \
        (findItem visible_files (source_a + "Tool_0.01.ms")) > 0 and \
        (findItem visible_files (source_a + "Tool_0.02.ms")) > 0 and \
        (findItem visible_files (source_a + "Only_0.01.ms")) > 0 and \
        (findItem visible_files (source_a + "Only_0.03.ms")) > 0 and \
        (findItem visible_files (source_a + "Dual.ms")) > 0 and \
        (findItem visible_files (source_a + "Dual.mcr")) == 0

    save_clean_ok = script_manager.saveShowCleanScriptsOnly true
    load_clean_ok = script_manager.loadShowCleanScriptsOnly()
    clean_files = script_manager.getScriptFilesInDirectory source_a
    clean_only_ok = clean_files.count == 1 and clean_files[1] == (source_a + "SourceA.ms")
    clean_persisted_ok = save_clean_ok and load_clean_ok and script_manager.show_clean_scripts_only

    script_manager.show_clean_scripts_only = false
    init_reload_ok = script_manager.reloadScripts()
    init_clean_loaded_ok = script_manager.show_clean_scripts_only and script_manager.available_script_paths.count == 1 and script_manager.available_script_paths[1] == (source_a + "SourceA.ms")

    script_manager.saveShowCleanScriptsOnly false
    script_manager.saveShowVersionedFiles false
    script_manager.show_versioned_files = false

    test_ok = all_versions_ok and clean_only_ok and clean_persisted_ok and init_reload_ok and init_clean_loaded_ok
    if not test_ok then script_manager_test_passed = false

    format "PART 5 | all-versions:% | clean-only:% | clean-persisted:% | init-filter:% | PASS:%\n" all_versions_ok clean_only_ok clean_persisted_ok init_clean_loaded_ok test_ok
    test_ok
    -- return
)

/*
Verifies persisted tri-state load modes and neutral text formatting regardless of checked state.
*/
function partOfTest6 =
(
    source_a = script_manager_test_temp_root + "SourceA\\"
    run_a_path = source_a + "RunA.ms"
    run_b_path = source_a + "RunB.ms"
    run_c_path = source_a + "RunC.ms"
    run_d_path = source_a + "RunD.ms"

    writeScriptManagerTestScript run_a_path "global script_manager_test_marker_a; if script_manager_test_marker_a == undefined then script_manager_test_marker_a = 0; script_manager_test_marker_a += 1"
    writeScriptManagerTestScript run_b_path "global script_manager_test_marker_b; if script_manager_test_marker_b == undefined then script_manager_test_marker_b = 0; script_manager_test_marker_b += 1"
    writeScriptManagerTestScript run_c_path "global script_manager_test_marker_c; global script_manager_test_direct_rollout; if script_manager_test_marker_c == undefined then script_manager_test_marker_c = 0; script_manager_test_marker_c += 1; try(if script_manager_test_direct_rollout != undefined and script_manager_test_direct_rollout.inDialog then destroyDialog script_manager_test_direct_rollout)catch(getCurrentException()); rollout script_manager_test_direct_rollout \"Direct Test\" (); if ScriptManagerIntegration.shouldAutoOpenUI() then createDialog script_manager_test_direct_rollout"
    writeScriptManagerTestScript run_d_path "global script_manager_test_marker_d; global script_manager_test_runtime_rollout; if script_manager_test_marker_d == undefined then script_manager_test_marker_d = 0; script_manager_test_marker_d += 1; execute \"rollout script_manager_test_runtime_rollout \\\"Runtime Registry Test\\\" ()\"; ScriptManagerIntegration.registerScript \"script_manager_test_runtime\" \"Runtime Registry Test\" undefined script_manager_test_runtime_rollout 1.0 1.0 (getSourceFileName()) capabilities:#(#ui)"

    key_a = script_manager.getScriptKey run_a_path
    key_b = script_manager.getScriptKey run_b_path
    key_c = script_manager.getScriptKey run_c_path
    key_d = script_manager.getScriptKey run_d_path
    save_a_ok = script_manager.saveScriptLoadMode key_a #host
    save_b_ok = script_manager.saveScriptLoadMode key_b #skip
    save_c_ok = script_manager.saveScriptLoadMode key_c #direct
    save_d_ok = script_manager.saveScriptLoadMode key_d #host
    persisted_ok = script_manager.getScriptLoadMode key_a == #host and script_manager.getScriptLoadMode key_b == #skip and script_manager.getScriptLoadMode key_c == #direct and script_manager.getScriptLoadMode key_d == #host

    color_node = dotNetObject "System.Windows.Forms.TreeNode" "RunC.ms"
    color_node.ToolTipText = run_c_path
    color_apply_ok = script_manager.applyScriptTreeNodeColor color_node
    marked_color_ok = color_apply_ok and color_node.ForeColor.R == 225 and color_node.ForeColor.G == 225 and color_node.ForeColor.B == 225

    host_color_node = dotNetObject "System.Windows.Forms.TreeNode" "RunA.ms"
    host_color_node.ToolTipText = run_a_path
    host_color_apply_ok = script_manager.applyScriptTreeNodeColor host_color_node
    host_color_ok = host_color_apply_ok and host_color_node.ForeColor.ToArgb() == color_node.ForeColor.ToArgb()

    visual_node = dotNetObject "System.Windows.Forms.TreeNode" "Visual.ms"
    visual_host_ok = script_manager.applyScriptTreeNodeMode visual_node #host and visual_node.StateImageIndex == 1 and visual_node.ImageIndex == 1
    visual_direct_ok = script_manager.applyScriptTreeNodeMode visual_node #direct and visual_node.StateImageIndex == 2 and visual_node.ImageIndex == 2
    visual_skip_ok = script_manager.applyScriptTreeNodeMode visual_node #skip and visual_node.StateImageIndex == 0 and visual_node.ImageIndex == 0
    visible_tristate_ok = visual_host_ok and visual_direct_ok and visual_skip_ok

    root_parent_node = dotNetObject "System.Windows.Forms.TreeNode" "SourceA"
    nested_parent_node = root_parent_node.Nodes.Add "Nested"
    host_child_node = nested_parent_node.Nodes.Add "RunA.ms"
    skip_child_node = nested_parent_node.Nodes.Add "RunB.ms"
    direct_child_node = nested_parent_node.Nodes.Add "RunC.ms"
    host_child_node.ToolTipText = run_a_path
    skip_child_node.ToolTipText = run_b_path
    direct_child_node.ToolTipText = run_c_path
    parent_sync_ok = script_manager.syncScriptTreeNodeChecks root_parent_node
    parent_indicator_ok = parent_sync_ok and nested_parent_node.StateImageIndex == 1 and root_parent_node.StateImageIndex == 1 and nested_parent_node.ImageIndex == 1 and root_parent_node.ImageIndex == 1

    test_ok = save_a_ok and save_b_ok and save_c_ok and save_d_ok and persisted_ok and marked_color_ok and host_color_ok and visible_tristate_ok and parent_indicator_ok
    if not test_ok then script_manager_test_passed = false

    format "PART 6 | host:% | skip:% | direct:% | runtime-host:% | direct-neutral:% | host-neutral:% | visible-tristate:% | parent-active-check:% | PASS:%\n" (script_manager.getScriptLoadMode key_a) (script_manager.getScriptLoadMode key_b) (script_manager.getScriptLoadMode key_c) (script_manager.getScriptLoadMode key_d) marked_color_ok host_color_ok visible_tristate_ok parent_indicator_ok test_ok
    test_ok
    -- return
)

/*
Verifies RELOAD only rebuilds discovery and LOAD SCRIPTS applies OFF, HOST, and DIRECT modes.
*/
function partOfTest7 =
(
    source_a = script_manager_test_temp_root + "SourceA\\"

    script_manager_test_marker_a = 0
    script_manager_test_marker_b = 0
    script_manager_test_marker_c = 0
    script_manager_test_marker_d = 0

    reload_ok = script_manager.reloadScripts()
    reload_is_scan_only = script_manager_test_marker_a == 0 and script_manager_test_marker_b == 0 and script_manager_test_marker_c == 0 and script_manager_test_marker_d == 0

    hard_load_ok = script_manager.loadScripts()
    hosted_loaded = script_manager_test_marker_a == 1
    skipped_not_loaded = script_manager_test_marker_b == 0
    direct_loaded = script_manager_test_marker_c == 1
    runtime_hosted_loaded = script_manager_test_marker_d == 1
    direct_dialog_open = script_manager_test_direct_rollout != undefined and script_manager_test_direct_rollout.inDialog

    soft_update_ok = script_manager.updateScripts()
    running_untouched = script_manager_test_marker_a == 1 and script_manager_test_marker_c == 1 and script_manager_test_marker_d == 1

    destroy_direct_ok = true
    try
    (
        if script_manager_test_direct_rollout.inDialog then destroyDialog script_manager_test_direct_rollout
    )
    catch
    (
        exception_text = getCurrentException()
        destroy_direct_ok = false
    )

    reopen_direct_ok = script_manager.updateScripts()
    closed_direct_reloaded = script_manager_test_marker_c == 2 and script_manager_test_direct_rollout.inDialog
    no_ui_still_once = script_manager_test_marker_a == 1

    runtime_host_path = script_manager.getHostDialogPathForGroup "SourceA"
    host_script_tracked = (findItem (script_manager.getHostScriptPaths runtime_host_path) (source_a + "RunD.ms")) > 0
    close_batch_ok = script_manager.destroyHostDialog runtime_host_path clear_rollouts:true
    reopen_batch_ok = script_manager.updateScripts()
    closed_batch_reloaded = script_manager_test_marker_d == 2
    direct_after_batch_untouched = script_manager_test_marker_c == 2

    second_hard_ok = script_manager.loadScripts()
    hard_reexecuted = script_manager_test_marker_a == 2 and script_manager_test_marker_b == 0 and script_manager_test_marker_c == 3 and script_manager_test_marker_d == 3

    test_ok = reload_ok and reload_is_scan_only and hard_load_ok and hosted_loaded and skipped_not_loaded and direct_loaded and runtime_hosted_loaded and direct_dialog_open and soft_update_ok and running_untouched and destroy_direct_ok and reopen_direct_ok and closed_direct_reloaded and no_ui_still_once and host_script_tracked and close_batch_ok and reopen_batch_ok and closed_batch_reloaded and direct_after_batch_untouched and second_hard_ok and hard_reexecuted
    if not test_ok then script_manager_test_passed = false

    format "PART 7 | scan:% | hard:% | host:% | skip:% | direct:% | runtime-host:% | direct-open:% | soft:% | untouched:% | direct-reopen:% | no-ui-once:% | host-tracked:% | batch-close:% | batch-reopen:% | hard-again:% | hard-reexecuted:% | PASS:%\n" reload_is_scan_only hard_load_ok hosted_loaded skipped_not_loaded direct_loaded runtime_hosted_loaded direct_dialog_open soft_update_ok running_untouched closed_direct_reloaded no_ui_still_once host_script_tracked close_batch_ok closed_batch_reloaded second_hard_ok hard_reexecuted test_ok
    test_ok
    -- return
)

/*
Verifies RESTART resolution belongs to Script-Manager and points to an existing source.
*/
function partOfTest8 =
(
    reload_path = script_manager.getLatestReloadScriptPath()
    reload_name = if reload_path == undefined then "" else getFilenameFile reload_path
    name_ok = matchPattern reload_name pattern:"Script-Manager*" ignoreCase:true
    exists_ok = reload_path != undefined and doesFileExist reload_path

    test_ok = name_ok and exists_ok
    if not test_ok then script_manager_test_passed = false

    format "PART 8 | reload:% | name:% | exists:% | PASS:%\n" reload_path name_ok exists_ok test_ok
    test_ok
    -- return
)

/*
Verifies tool folders sharing one parent resolve to one persistent organizational host dialog.
*/
function partOfTest9 =
(
    host_path_a = script_manager.getHostDialogPathForGroup "SourceA\\Bundle\\ToolA"
    host_path_b = script_manager.getHostDialogPathForGroup "SourceA\\Bundle\\ToolB"
    mapping_ok = host_path_a == "SourceA\\Bundle" and host_path_b == host_path_a
    title_ok = script_manager.getHostDialogTitle host_path_a == "Bundle"

    create_ok = script_manager.ensureHostDialog host_path_a
    host_dialog = script_manager.getHostDialog host_path_a
    slot_ok = host_dialog != undefined and isProperty host_dialog #sr_tools and host_dialog.sr_tools.width >= 312
    host_caption_ok = host_dialog != undefined and host_dialog.title == "Bundle"
    title_button_ok = host_dialog != undefined and isProperty host_dialog #btn_dialog_title and host_dialog.btn_dialog_title.Text == "Bundle"
    title_button_style_ok = false

    if title_button_ok then
    (
        flat_style_type = dotNetClass "System.Windows.Forms.FlatStyle"
        title_button_style_ok = host_dialog.btn_dialog_title.FlatStyle == flat_style_type.Flat and \
            host_dialog.btn_dialog_title.FlatAppearance.BorderSize == 0 and \
            host_dialog.btn_dialog_title.BackColor.R == 45 and host_dialog.btn_dialog_title.BackColor.G == 45 and host_dialog.btn_dialog_title.BackColor.B == 48 and \
            host_dialog.btn_dialog_title.ForeColor.R == 62 and host_dialog.btn_dialog_title.ForeColor.G == 158 and host_dialog.btn_dialog_title.ForeColor.B == 255
    )

    save_ok = false
    persisted_ok = false

    if host_dialog != undefined then
    (
        save_ok = script_manager.saveHostDialogState host_path_a save_rollouts:false
        section_name = script_manager.getHostDialogIniSection host_path_a
        persisted_ok = (getINISetting script_manager.ini_path section_name "Dock") != ""
    )

    destroy_ok = script_manager.destroyHostDialog host_path_a clear_rollouts:false
    removed_ok = script_manager.getHostDialog host_path_a == undefined

    reload_tool_directory = script_manager_test_temp_root + "SourceA\\Bundle\\ReloadTool\\"
    reload_script_path = reload_tool_directory + "ReloadTool.ms"
    makeDir (script_manager_test_temp_root + "SourceA\\Bundle")
    makeDir reload_tool_directory
    script_manager_test_marker_e = 0
    reload_script_body = "global script_manager_test_marker_e; global script_manager_test_host_reload_rollout; if script_manager_test_marker_e == undefined then script_manager_test_marker_e = 0; script_manager_test_marker_e += 1; rollout script_manager_test_host_reload_rollout \"Host Reload Test\" (); if ScriptManagerIntegration.shouldAutoOpenUI() then createDialog script_manager_test_host_reload_rollout"
    reload_write_ok = writeScriptManagerTestScript reload_script_path reload_script_body

    direct_load_result = script_manager.loadManagedScript reload_script_path script_name:"ReloadTool" script_key:(script_manager.getScriptKey reload_script_path) group_path:"SourceA\\Bundle\\ReloadTool" embed_rollouts:false
    stale_standalone_rollout = script_manager_test_host_reload_rollout
    stale_standalone_open_ok = direct_load_result[1] and stale_standalone_rollout != undefined and stale_standalone_rollout.inDialog and script_manager_test_marker_e == 1

    reload_load_result = script_manager.loadManagedScript reload_script_path script_name:"ReloadTool" script_key:(script_manager.getScriptKey reload_script_path) group_path:"SourceA\\Bundle\\ReloadTool" embed_rollouts:true
    stale_standalone_closed_ok = stale_standalone_rollout != undefined and not(stale_standalone_rollout.inDialog)
    first_reload_host = script_manager.getHostDialog host_path_a
    first_reload_host_ok = reload_load_result[1] and stale_standalone_closed_ok and first_reload_host != undefined and first_reload_host.inDialog and script_manager_test_marker_e == 2
    dialog_reload_ok = script_manager.reloadHostDialogScripts host_path_a
    second_reload_host = script_manager.getHostDialog host_path_a
    recreated_host_ok = dialog_reload_ok and second_reload_host != undefined and second_reload_host.inDialog and first_reload_host != second_reload_host and script_manager_test_marker_e == 3
    reload_cleanup_ok = script_manager.destroyHostDialog host_path_a clear_rollouts:true
    if doesFileExist reload_script_path then deleteFile reload_script_path

    test_ok = mapping_ok and title_ok and create_ok and slot_ok and host_caption_ok and title_button_ok and title_button_style_ok and save_ok and persisted_ok and destroy_ok and removed_ok and reload_write_ok and stale_standalone_open_ok and stale_standalone_closed_ok and first_reload_host_ok and recreated_host_ok and reload_cleanup_ok
    if not test_ok then script_manager_test_passed = false

    format "PART 9 | mapping:% | title:% | create:% | slot:% | host-caption:% | title-button:% | title-style:% | persisted:% | destroy:% | removed:% | stale-open:% | stale-closed:% | reload-recreates:% | PASS:%\n" mapping_ok title_ok create_ok slot_ok host_caption_ok title_button_ok title_button_style_ok persisted_ok destroy_ok removed_ok stale_standalone_open_ok stale_standalone_closed_ok recreated_host_ok test_ok
    test_ok
    -- return
)

/*
Verifies script-item RMB LOAD SCRIPT force-runs the selected script directly, ignores its HOST mode, and never adds it to a batch dialog.
*/
function partOfTest10 =
(
    source_a = script_manager_test_temp_root + "SourceA\\"
    preview_path = source_a + "Preview.ms"
    script_manager_test_marker_b = 0
    script_manager_test_forced_mode = undefined

    preview_body = "global script_manager_test_marker_b; global script_manager_test_forced_rollout; global script_manager_test_forced_mode; if script_manager_test_marker_b == undefined then script_manager_test_marker_b = 0; script_manager_test_marker_b += 1; script_manager_test_forced_mode = SCRIPT_MANAGER_RUNTIME_MODE; try(if script_manager_test_forced_rollout != undefined and script_manager_test_forced_rollout.inDialog then destroyDialog script_manager_test_forced_rollout)catch(getCurrentException()); rollout script_manager_test_forced_rollout \"Forced Direct Preview\" (); if ScriptManagerIntegration.shouldAutoOpenUI() then createDialog script_manager_test_forced_rollout"
    write_ok = writeScriptManagerTestScript preview_path preview_body

    preview_key = script_manager.getScriptKey preview_path
    mode_ok = script_manager.saveScriptLoadMode preview_key #host
    host_path = script_manager.getHostDialogPathForGroup "SourceA"
    tracked_before = (findItem (script_manager.getHostScriptPaths host_path) preview_path) == 0

    script_node = dotNetObject "System.Windows.Forms.TreeNode" "Preview.ms"
    script_node.ToolTipText = preview_path
    script_manager_scripts_ui.tv_scripts.SelectedNode = script_node
    script_menu_ok = script_manager.updateScriptTreeContextMenuState() and script_manager.script_tree_load_item.Visible and not(script_manager.script_tree_expand_item.Visible)

    first_load_ok = script_manager.loadSelectedScriptTreeItem()
    first_direct_ok = script_manager_test_marker_b == 1 and script_manager_test_forced_mode == #standalone and script_manager_test_forced_rollout != undefined and script_manager_test_forced_rollout.inDialog
    first_not_hosted = (findItem (script_manager.getHostScriptPaths host_path) preview_path) == 0 and script_manager.getLiveHostPathForScript preview_path == ""

    second_load_ok = script_manager.loadSelectedScriptTreeItem()
    forced_twice_ok = script_manager_test_marker_b == 2 and script_manager_test_forced_mode == #standalone and script_manager_test_forced_rollout.inDialog
    second_not_hosted = (findItem (script_manager.getHostScriptPaths host_path) preview_path) == 0 and script_manager.getLiveHostPathForScript preview_path == ""
    mode_unchanged_ok = script_manager.getScriptLoadMode preview_key == #host

    macro_preview_path = source_a + "PreviewMacro.mcr"
    script_manager_test_marker_g = 0
    macro_write_ok = writeScriptManagerTestScript macro_preview_path "global script_manager_test_marker_g; if script_manager_test_marker_g == undefined then script_manager_test_marker_g = 0; script_manager_test_marker_g += 1; macroScript ScriptManagerPreviewMacroTest category:\"Script-Manager Test\" (on execute do ())"
    macro_node = dotNetObject "System.Windows.Forms.TreeNode" "PreviewMacro.mcr"
    macro_node.ToolTipText = macro_preview_path
    macro_double_load_ok = macro_write_ok and script_manager.loadDoubleClickedScriptTreeNode macro_node and script_manager_test_marker_g == 1
    ms_double_load_ok = script_manager.loadDoubleClickedScriptTreeNode script_node and script_manager_test_marker_b == 3 and script_manager_test_forced_mode == #standalone

    mse_preview_path = source_a + "PreviewEncrypted.mse"
    mse_node = dotNetObject "System.Windows.Forms.TreeNode" "PreviewEncrypted.mse"
    mse_node.ToolTipText = mse_preview_path
    mse_double_ignored_ok = not(script_manager.loadDoubleClickedScriptTreeNode mse_node)

    script_manager_scripts_ui.tv_scripts.SelectedNode = script_node
    script_explorer_menu_ok = script_manager.updateScriptTreeContextMenuState() and script_manager.script_tree_open_explorer_item.Visible and script_manager.script_tree_open_explorer_item.Enabled

    folder_node = dotNetObject "System.Windows.Forms.TreeNode" "Folder"
    folder_node.ToolTipText = source_a
    folder_node.Nodes.Add "Child"
    script_manager_scripts_ui.tv_scripts.SelectedNode = folder_node
    folder_menu_ok = script_manager.updateScriptTreeContextMenuState() and not(script_manager.script_tree_load_item.Visible) and script_manager.script_tree_open_explorer_item.Visible and script_manager.script_tree_expand_item.Visible

    test_ok = write_ok and mode_ok and tracked_before and script_menu_ok and first_load_ok and first_direct_ok and first_not_hosted and second_load_ok and forced_twice_ok and second_not_hosted and mode_unchanged_ok and macro_double_load_ok and ms_double_load_ok and mse_double_ignored_ok and script_explorer_menu_ok and folder_menu_ok
    if not test_ok then script_manager_test_passed = false

    format "PART 10 | write:% | host-mode:% | menu:% | first-direct:% | first-no-host:% | second-forced:% | second-no-host:% | mode-unchanged:% | mcr-double:% | ms-double:% | mse-double-ignore:% | explorer-menu:% | folder-menu:% | PASS:%\n" write_ok mode_ok script_menu_ok first_direct_ok first_not_hosted forced_twice_ok second_not_hosted mode_unchanged_ok macro_double_load_ok ms_double_load_ok mse_double_ignored_ok script_explorer_menu_ok folder_menu_ok test_ok
    test_ok
    -- return
)

/*
Verifies named presets save, list, restore, and remove SOURCES plus SKIP / HOST / DIRECT configuration without executing scripts.
*/
function partOfTest11 =
(
    preset_name = "Script Manager Preset Test"
    source_a = script_manager_test_temp_root + "SourceA\\"
    source_b = script_manager_test_temp_root + "SourceB\\"
    run_a_key = script_manager.getScriptKey (source_a + "RunA.ms")
    run_b_key = script_manager.getScriptKey (source_a + "RunB.ms")
    run_c_key = script_manager.getScriptKey (source_a + "RunC.ms")
    run_d_key = script_manager.getScriptKey (source_a + "RunD.ms")
    preview_key = script_manager.getScriptKey (source_a + "Preview.ms")

    if script_manager.hasPreset preset_name then script_manager.removePreset preset_name

    source_a_before = script_manager.getSourceEnabled source_a
    source_b_before = script_manager.getSourceEnabled source_b
    run_a_mode_before = script_manager.getScriptLoadMode run_a_key
    run_b_mode_before = script_manager.getScriptLoadMode run_b_key
    run_c_mode_before = script_manager.getScriptLoadMode run_c_key
    run_d_mode_before = script_manager.getScriptLoadMode run_d_key
    preview_mode_before = script_manager.getScriptLoadMode preview_key
    marker_a_before = script_manager_test_marker_a
    marker_b_before = script_manager_test_marker_b
    marker_c_before = script_manager_test_marker_c
    marker_d_before = script_manager_test_marker_d

    save_ok = script_manager.savePreset preset_name
    has_ok = script_manager.hasPreset preset_name
    listed_ok = (findItem (script_manager.getPresetNames()) preset_name) > 0
    data_ok = script_manager.readPresetData preset_name != undefined

    mutate_sources_ok = script_manager.saveSourceEnabled source_a false and script_manager.saveSourceEnabled source_b true
    mutate_scripts_ok = script_manager.saveScriptLoadMode run_a_key #skip and script_manager.saveScriptLoadMode run_b_key #direct
    mutated_ok = mutate_sources_ok and mutate_scripts_ok and not(script_manager.getSourceEnabled source_a) and script_manager.getSourceEnabled source_b and script_manager.getScriptLoadMode run_a_key == #skip and script_manager.getScriptLoadMode run_b_key == #direct

    load_ok = script_manager.loadPreset preset_name
    sources_restored_ok = script_manager.getSourceEnabled source_a == source_a_before and script_manager.getSourceEnabled source_b == source_b_before
    scripts_restored_ok = \
        script_manager.getScriptLoadMode run_a_key == run_a_mode_before and \
        script_manager.getScriptLoadMode run_b_key == run_b_mode_before and \
        script_manager.getScriptLoadMode run_c_key == run_c_mode_before and \
        script_manager.getScriptLoadMode run_d_key == run_d_mode_before and \
        script_manager.getScriptLoadMode preview_key == preview_mode_before
    no_execution_ok = script_manager_test_marker_a == marker_a_before and script_manager_test_marker_b == marker_b_before and script_manager_test_marker_c == marker_c_before and script_manager_test_marker_d == marker_d_before
    dropdown_ok = script_manager.getSelectedPresetName() == preset_name

    remove_ok = script_manager.removePreset preset_name
    removed_ok = not(script_manager.hasPreset preset_name) and (findItem (script_manager.getPresetNames()) preset_name) == 0
    script_manager.refreshPresetDropdown()

    test_ok = save_ok and has_ok and listed_ok and data_ok and mutated_ok and load_ok and sources_restored_ok and scripts_restored_ok and no_execution_ok and dropdown_ok and remove_ok and removed_ok
    if not test_ok then script_manager_test_passed = false

    format "PART 11 | save:% | has:% | listed:% | data:% | mutated:% | load:% | sources:% | scripts:% | no-execution:% | dropdown:% | remove:% | removed:% | PASS:%\n" save_ok has_ok listed_ok data_ok mutated_ok load_ok sources_restored_ok scripts_restored_ok no_execution_ok dropdown_ok remove_ok removed_ok test_ok
    test_ok
    -- return
)

/*
Verifies one checked batch ancestor groups scripts from different parent folders into one dialog.
The first checked discovery root is ignored, and deeper checked descendants do not split the selected batch subtree.
*/
function partOfTest12 =
(
    source_root = script_manager_test_temp_root + "SourceA\\"
    batch_root = source_root + "Edit Poly Tools\\"
    parent_a = batch_root + "ParentA\\"
    parent_b = batch_root + "ParentB\\"
    tool_a = parent_a + "ToolA\\"
    tool_b = parent_b + "ToolB\\"
    script_a = tool_a + "ToolA.ms"
    script_b = tool_b + "ToolB.ms"

    original_source_names = script_manager.available_source_names
    original_source_directories = script_manager.available_source_directories
    original_source_selectable = script_manager.available_source_selectable

    script_manager.available_source_names = #("SourceA", "Edit Poly Tools", "ParentA", "ParentB")
    script_manager.available_source_directories = #(source_root, batch_root, parent_a, parent_b)
    script_manager.available_source_selectable = #(true, true, true, true)

    source_ok = script_manager.saveSourceEnabled source_root true
    batch_ok = script_manager.saveSourceEnabled batch_root true
    parent_a_ok = script_manager.saveSourceEnabled parent_a true
    parent_b_ok = script_manager.saveSourceEnabled parent_b true

    host_a = script_manager.getBatchDialogPathForScript script_a
    host_b = script_manager.getBatchDialogPathForScript script_b
    shared_batch_ok = host_a == "SourceA\\Edit Poly Tools" and host_b == host_a

    clear_batch_ok = script_manager.saveSourceEnabled batch_root false
    clear_parent_a_ok = script_manager.saveSourceEnabled parent_a false
    clear_parent_b_ok = script_manager.saveSourceEnabled parent_b false
    default_a = script_manager.getBatchDialogPathForScript script_a
    default_b = script_manager.getBatchDialogPathForScript script_b
    first_checked_ignored_ok = default_a == "SourceA\\Edit Poly Tools\\ParentA" and default_b == "SourceA\\Edit Poly Tools\\ParentB"

    script_manager.saveSourceEnabled batch_root false
    script_manager.saveSourceEnabled parent_a false
    script_manager.saveSourceEnabled parent_b false

    script_manager.available_source_names = original_source_names
    script_manager.available_source_directories = original_source_directories
    script_manager.available_source_selectable = original_source_selectable

    test_ok = source_ok and batch_ok and parent_a_ok and parent_b_ok and shared_batch_ok and clear_batch_ok and clear_parent_a_ok and clear_parent_b_ok and first_checked_ignored_ok
    if not test_ok then script_manager_test_passed = false

    format "PART 12 | shared-cross-parent-batch:% | first-checked-ignored:% | PASS:%\n" shared_batch_ok first_checked_ignored_ok test_ok
    test_ok
    -- return
)

/*
Verifies the SOURCES batch-dialog context command targets only an explicit checked dialog marker.
Configured HOST scripts from different parent folders share the action; DIRECT and other-dialog scripts are excluded.
*/
function partOfTest13 =
(
    source_root = script_manager_test_temp_root + "SourceA\\"
    batch_root = source_root + "Edit Poly Tools\\"
    parent_a = batch_root + "ParentA\\"
    parent_b = batch_root + "ParentB\\"
    direct_parent = batch_root + "ParentDirect\\"
    other_parent = source_root + "Other Batch\\ParentC\\"
    script_a = parent_a + "ToolA\\ToolA.ms"
    script_b = parent_b + "ToolB\\ToolB.ms"
    script_direct = direct_parent + "ToolDirect\\ToolDirect.ms"
    script_other = other_parent + "ToolC\\ToolC.ms"

    original_source_names = script_manager.available_source_names
    original_source_directories = script_manager.available_source_directories
    original_source_selectable = script_manager.available_source_selectable
    original_script_paths = script_manager.available_script_paths

    script_manager.available_source_names = #("SourceA", "Edit Poly Tools", "ParentA", "ParentB", "ParentDirect", "Other Batch")
    script_manager.available_source_directories = #(source_root, batch_root, parent_a, parent_b, direct_parent, source_root + "Other Batch\\")
    script_manager.available_source_selectable = #(true, true, true, true, true, true)
    script_manager.available_script_paths = #(script_a, script_b, script_direct, script_other)

    source_ok = script_manager.saveSourceEnabled source_root true
    batch_ok = script_manager.saveSourceEnabled batch_root true
    script_manager.saveSourceEnabled parent_a false
    script_manager.saveSourceEnabled parent_b false
    script_manager.saveSourceEnabled direct_parent false
    script_manager.saveSourceEnabled (source_root + "Other Batch\\") false

    key_a = script_manager.getScriptKey script_a
    key_b = script_manager.getScriptKey script_b
    key_direct = script_manager.getScriptKey script_direct
    key_other = script_manager.getScriptKey script_other
    script_manager.saveScriptLoadMode key_a #host
    script_manager.saveScriptLoadMode key_b #host
    script_manager.saveScriptLoadMode key_direct #direct
    script_manager.saveScriptLoadMode key_other #host

    batch_path = script_manager.getRelativeDirectoryPath batch_root
    override_a_ok = script_manager.getBatchOverridePathForScript script_a == batch_path
    override_b_ok = script_manager.getBatchOverridePathForScript script_b == batch_path
    batch_marker_ok = script_manager.isSourceDirectoryBatchDialog batch_root and not(script_manager.isSourceDirectoryBatchDialog source_root)

    configured_paths = script_manager.getConfiguredHostScriptPaths batch_path
    configured_set_ok = configured_paths.count == 2 and (findItem configured_paths script_a) > 0 and (findItem configured_paths script_b) > 0 and (findItem configured_paths script_direct) == 0 and (findItem configured_paths script_other) == 0

    tree_control = script_manager.getSourceTreeControl()
    tree_control.Nodes.Clear()
    source_node = tree_control.Nodes.Add "SourceA"
    source_node.Name = "SOURCE_SELECTABLE"
    source_node.Tag = source_root
    batch_node = source_node.Nodes.Add "Edit Poly Tools"
    batch_node.Name = "SOURCE_SELECTABLE"
    batch_node.Tag = batch_root

    tree_control.SelectedNode = batch_node
    selected_batch_ok = script_manager.getSelectedSourceDialogPath() == batch_path
    menu_batch_ok = script_manager.updateSourceTreeContextMenuState() and script_manager.source_tree_load_dialog_item.Visible and script_manager.source_tree_load_dialog_item.Enabled and script_manager.source_tree_load_dialog_item.Text == "LOAD \\ RELOAD DIALOG"

    tree_control.SelectedNode = source_node
    selected_root_ok = script_manager.getSelectedSourceDialogPath() == ""
    menu_root_ok = script_manager.updateSourceTreeContextMenuState() and not(script_manager.source_tree_load_dialog_item.Visible)

    script_manager.saveScriptLoadMode key_a #skip
    script_manager.saveScriptLoadMode key_b #skip
    script_manager.saveScriptLoadMode key_direct #skip
    script_manager.saveScriptLoadMode key_other #skip
    script_manager.saveSourceEnabled batch_root false

    script_manager.available_source_names = original_source_names
    script_manager.available_source_directories = original_source_directories
    script_manager.available_source_selectable = original_source_selectable
    script_manager.available_script_paths = original_script_paths
    restore_tree_ok = script_manager.populateSourceTree() and script_manager.populateScriptTree()

    test_ok = source_ok and batch_ok and override_a_ok and override_b_ok and batch_marker_ok and configured_set_ok and selected_batch_ok and menu_batch_ok and selected_root_ok and menu_root_ok and restore_tree_ok
    if not test_ok then script_manager_test_passed = false

    format "PART 13 | batch-marker:% | configured-set:% | selected-batch:% | menu-batch:% | root-hidden:% | restore:% | PASS:%\n" batch_marker_ok configured_set_ok selected_batch_ok menu_batch_ok (selected_root_ok and menu_root_ok) restore_tree_ok test_ok
    test_ok
    -- return
)

/*
Verifies PRESETS load execution, MacroScript body generation, and one startup preset with an isolated startup-loader path.
*/
function partOfTest14 =
(
    preset_name = "Startup Macro Preset"
    source_a = script_manager_test_temp_root + "SourceA\\"
    preset_exec_path = source_a + "PresetExec.ms"
    preset_exec_key = script_manager.getScriptKey preset_exec_path
    startup_loader_path = script_manager.getStartupPresetLoaderPath startup_directory:script_manager_test_temp_root

    previous_source_entries = script_manager.getIniSectionEntries "Sources"
    previous_script_entries = script_manager.getIniSectionEntries "Scripts"
    previous_startup_name = getINISetting script_manager.ini_path "Presets" "StartupPreset"

    if script_manager.hasPreset preset_name then script_manager.removePreset preset_name
    if doesFileExist startup_loader_path then deleteFile startup_loader_path

    write_ok = writeScriptManagerTestScript preset_exec_path "global script_manager_test_marker_f; if script_manager_test_marker_f == undefined then script_manager_test_marker_f = 0; script_manager_test_marker_f += 1"
    source_state_ok = script_manager.replaceIniSection "Sources" #(#(script_manager.getSourceKey source_a, "1"))
    script_state_ok = script_manager.replaceIniSection "Scripts" #(#(preset_exec_key, "2"))
    save_ok = write_ok and source_state_ok and script_state_ok and script_manager.savePreset preset_name

    macro_action_name = script_manager.getPresetMacroActionName preset_name
    macro_body = script_manager.buildPresetMacroBody preset_name
    macro_body_ok = macro_action_name != undefined and macro_body != undefined and findString macro_body "loadPresetAndScripts" != undefined and findString macro_body preset_name != undefined and findString macro_body (script_manager.escapeMaxScriptString (script_manager.getCanonicalManagerScriptPath())) != undefined
    macro_button_ok = script_manager.getPresetMacroButtonText preset_name == "Startup Ma"

    startup_set_ok = script_manager.setStartupPreset preset_name startup_directory:script_manager_test_temp_root
    startup_name_ok = script_manager.getStartupPresetName() == preset_name
    startup_file_ok = doesFileExist startup_loader_path
    startup_text = readScriptManagerTestFileText startup_loader_path
    startup_text_ok = startup_text != undefined and findString startup_text "SCRIPT_MANAGER_STARTUP_LAUNCH = true" != undefined and findString startup_text (script_manager.escapeMaxScriptString (script_manager.getCanonicalManagerScriptPath())) != undefined

    script_manager_test_marker_f = 0
    mutate_ok = script_manager.replaceIniSection "Sources" #() and script_manager.replaceIniSection "Scripts" #()
    SCRIPT_MANAGER_STARTUP_LAUNCH = true
    SCRIPT_MANAGER_STARTUP_PRESET_APPLIED = false
    first_startup_ok = mutate_ok and script_manager.loadStartupPresetOnce() and script_manager_test_marker_f == 1 and script_manager.getScriptLoadMode preset_exec_key == #direct
    second_startup_ok = script_manager.loadStartupPresetOnce() and script_manager_test_marker_f == 1
    SCRIPT_MANAGER_STARTUP_LAUNCH = false
    SCRIPT_MANAGER_STARTUP_PRESET_APPLIED = false

    startup_clear_ok = script_manager.clearStartupPreset startup_directory:script_manager_test_temp_root
    startup_cleared_ok = script_manager.getStartupPresetName() == undefined and not(doesFileExist startup_loader_path)
    remove_ok = script_manager.removePreset preset_name

    startup_restore_ok = true
    if previous_startup_name != "" then
    (
        startup_restore_ok = setINISetting script_manager.ini_path "Presets" "StartupPreset" previous_startup_name forceUTF16:false
        if not startup_restore_ok then format "TEST RESTORE FAILED | startup preset:%\n" previous_startup_name
    )

    restore_sources_ok = script_manager.replaceIniSection "Sources" previous_source_entries
    restore_scripts_ok = script_manager.replaceIniSection "Scripts" previous_script_entries
    restore_ui_ok = restore_sources_ok and restore_scripts_ok and script_manager.refreshPresetConfiguration() and script_manager.refreshPresetDropdown()

    test_ok = save_ok and macro_body_ok and macro_button_ok and startup_set_ok and startup_name_ok and startup_file_ok and startup_text_ok and first_startup_ok and second_startup_ok and startup_clear_ok and startup_cleared_ok and remove_ok and startup_restore_ok and restore_ui_ok
    if not test_ok then script_manager_test_passed = false

    format "PART 14 | save:% | macro-body:% | macro-button:% | startup-set:% | startup-file:% | startup-text:% | startup-first:% | startup-once:% | startup-clear:% | remove:% | startup-restore:% | restore:% | PASS:%\n" save_ok macro_body_ok macro_button_ok startup_set_ok startup_file_ok startup_text_ok first_startup_ok second_startup_ok (startup_clear_ok and startup_cleared_ok) remove_ok startup_restore_ok restore_ui_ok test_ok
    test_ok
    -- return
)

/*
Verifies toolbar naming, checked-script selection, generated actions, and non-destructive CUIX text replacement without loading a live UI configuration.
*/
function partOfTest15 =
(
    previous_paths = script_manager.available_script_paths
    previous_groups = script_manager.available_script_group_paths

    toolbar_host_path = script_manager_test_temp_root + "SourceA\\ToolbarHost.ms"
    toolbar_skip_path = script_manager_test_temp_root + "SourceA\\ToolbarSkip.ms"
    toolbar_direct_path = script_manager_test_temp_root + "SourceA\\ToolbarDirect.ms"

    script_manager.available_script_paths = #(toolbar_host_path, toolbar_skip_path, toolbar_direct_path)
    script_manager.available_script_group_paths = #("SourceA", "SourceA", "SourceA")

    host_key = script_manager.getScriptKey toolbar_host_path
    skip_key = script_manager.getScriptKey toolbar_skip_path
    direct_key = script_manager.getScriptKey toolbar_direct_path

    script_manager.saveScriptLoadMode host_key #host
    script_manager.saveScriptLoadMode skip_key #skip
    script_manager.saveScriptLoadMode direct_key #direct

    default_name_ok = script_manager.getDefaultToolbarName user_name:"TestUser" == "TestUser SCRIPT-MANAGER"
    configured_paths = script_manager.getToolbarScriptPaths script_paths:script_manager.available_script_paths
    checked_paths_ok = configured_paths.count == 2 and configured_paths[1] == toolbar_host_path and configured_paths[2] == toolbar_direct_path and (findItem configured_paths toolbar_skip_path) == 0

    macro_source = script_manager.buildToolbarMacroSource "Test Toolbar" configured_paths
    macro_source_ok = (findString macro_source toolbar_host_path) != undefined and (findString macro_source toolbar_direct_path) != undefined and (findString macro_source toolbar_skip_path) == undefined and (findString macro_source "ScriptManagerToolbar_OpenManager") != undefined

    source_cuix = "<?xml version=\"1.0\" encoding=\"utf-8\" ?>\n<ADSK_CUI>\n    <CUIWindows>\n        <Window objectName=\"Keep Toolbar\" name=\"Keep Toolbar\" type=\"T\" cType=\"1\" toolbarRows=\"1\"><Items /></Window>\n        <Window objectName=\"Test Toolbar\" name=\"Test Toolbar\" type=\"T\" cType=\"1\" toolbarRows=\"1\"><Items /></Window>\n    </CUIWindows>\n</ADSK_CUI>"
    patched_cuix = script_manager.patchCuixToolbarText source_cuix "Test Toolbar" configured_paths
    cuix_ok = patched_cuix != undefined and (findString patched_cuix "Keep Toolbar") != undefined and (findString patched_cuix "ScriptManagerToolbar_OpenManager`Script-Manager Toolbar") != undefined and (findString patched_cuix "ToolbarHost") != undefined and (findString patched_cuix "ToolbarDirect") != undefined and (findString patched_cuix "ToolbarSkip") == undefined

    live_api_ok = isProperty script_manager #createToolbar and isProperty script_manager #handleCreateToolbar and isProperty script_manager #getActiveCuixPath and isProperty script_manager #writeToolbarMacroFile

    script_manager.available_script_paths = previous_paths
    script_manager.available_script_group_paths = previous_groups

    test_ok = default_name_ok and checked_paths_ok and macro_source_ok and cuix_ok and live_api_ok
    if not test_ok then script_manager_test_passed = false

    format "PART 15 | default-name:% | checked:% | macros:% | cuix:% | live-api:% | PASS:%\n" default_name_ok checked_paths_ok macro_source_ok cuix_ok live_api_ok test_ok
    test_ok
    -- return
)

/*
Verifies collapsed initial trees and indexed folder/script lookups without changing configured load modes.
*/
function partOfTest16 =
(
    source_ok = script_manager.populateSourceTree restore_expansion:false
    script_ok = script_manager.populateScriptTree restore_expansion:false
    source_tree = script_manager.getSourceTreeControl()
    script_tree = script_manager.getScriptTreeControl()
    collapsed_ok = source_ok and script_ok and source_tree != undefined and script_tree != undefined and source_tree.Nodes.Count > 0 and script_tree.Nodes.Count > 0

    if collapsed_ok then
    (
        for root_index = 0 to (source_tree.Nodes.Count - 1) do
        (
            if source_tree.Nodes.Item[root_index].IsExpanded then collapsed_ok = false
        )

        for root_index = 0 to (script_tree.Nodes.Count - 1) do
        (
            if script_tree.Nodes.Item[root_index].IsExpanded then collapsed_ok = false
        )
    )

    cache_ok = false
    if isProperty script_manager #buildScriptTreeGroupCache then
    (
        group_cache = script_manager.buildScriptTreeGroupCache()
        cache_ok = group_cache.count == 2

        if cache_ok then
        (
            for script_index = 1 to script_manager.available_script_paths.count do
            (
                expected_path = script_manager.getScriptTreeDisplayGroupPath script_index
                indexed_path = script_manager.getScriptTreeDisplayGroupPath script_index group_counts:group_cache[1] descendant_paths:group_cache[2]
                if expected_path != indexed_path then cache_ok = false
            )
        )
    )

    folder_tree = dotNetObject "System.Windows.Forms.TreeView"
    folder_lookup = Dictionary #string
    folder_values = #()
    folder_directory = script_manager_test_temp_root + "SourceA\\Category\\"
    script_manager.ensureScriptTreeFolderPath folder_tree.Nodes "SourceA\\Category" folder_directory folder_lookup folder_values
    script_manager.ensureScriptTreeFolderPath folder_tree.Nodes "SourceA\\Category" folder_directory folder_lookup folder_values
    folder_cache_ok = folder_tree.Nodes.Count == 1 and folder_tree.Nodes.Item[0].Nodes.Count == 1 and folder_values.count == 2 and folder_lookup.Count == 2

    first_load_ok = false
    no_duplicate_init_ok = false

    if collapsed_ok and isProperty script_manager #populateInitialSourceTree and isProperty script_manager #populateInitialScriptTree then
    (
        /* Simulate newly created, empty TreeViews after discovery but before their first open event. */
        source_tree.Nodes.Clear()
        script_tree.Nodes.Clear()
        script_manager.source_tree_initialized = false
        script_manager.script_tree_initialized = false

        first_source_ok = script_manager.populateInitialSourceTree()
        first_script_ok = script_manager.populateInitialScriptTree()
        first_load_ok = first_source_ok and first_script_ok and source_tree.Nodes.Count > 0 and script_tree.Nodes.Count > 0

        if first_load_ok then
        (
            source_node_count = source_tree.GetNodeCount true
            script_node_count = script_tree.GetNodeCount true
            source_tree.Nodes.Item[0].ToolTipText = "SM_INIT_SOURCE_SENTINEL"
            script_tree.Nodes.Item[0].ToolTipText = "SM_INIT_SCRIPT_SENTINEL"

            second_source_ok = script_manager.populateInitialSourceTree()
            second_script_ok = script_manager.populateInitialScriptTree()
            no_duplicate_init_ok = second_source_ok and second_script_ok and \
                source_tree.GetNodeCount true == source_node_count and script_tree.GetNodeCount true == script_node_count and \
                source_tree.Nodes.Item[0].ToolTipText == "SM_INIT_SOURCE_SENTINEL" and script_tree.Nodes.Item[0].ToolTipText == "SM_INIT_SCRIPT_SENTINEL"
        )

        /* Restore the real tree nodes after the sentinel check. */
        script_manager.populateSourceTree restore_expansion:false
        script_manager.populateScriptTree restore_expansion:false
    )

    test_ok = collapsed_ok and cache_ok and folder_cache_ok and first_load_ok and no_duplicate_init_ok
    if not test_ok then script_manager_test_passed = false

    format "PART 16 | collapsed:% | group-index:% | folder-cache:% | first-load:% | once-only:% | PASS:%\n" collapsed_ok cache_ok folder_cache_ok first_load_ok no_duplicate_init_ok test_ok
    test_ok
    -- return
)

/*
Verifies EXPAND ENABLED reveals HOST/DIRECT script paths while collapsing skipped branches.
The synthetic rows use the real SCRIPTS TreeView and are restored after the test.
*/
function partOfTest17 =
(
    tree_control = script_manager.getScriptTreeControl()
    menu_ok = isProperty script_manager #script_tree_expand_enabled_item and script_manager.script_tree_expand_enabled_item != undefined
    if menu_ok then menu_ok = script_manager.script_tree_expand_enabled_item.Text == "EXPAND ENABLED"

    direct_path_ok = false
    host_path_ok = false
    skipped_path_ok = false
    empty_selection_ok = false

    if tree_control != undefined and isProperty script_manager #expandEnabledScriptTree and menu_ok then
    (
        tree_control.Nodes.Clear()

        active_root = tree_control.Nodes.Add "ACTIVE ROOT"
        active_root.ToolTipText = script_manager_test_temp_root + "ActiveRoot\\"
        active_branch = active_root.Nodes.Add "ACTIVE BRANCH"
        active_branch.ToolTipText = script_manager_test_temp_root + "ActiveRoot\\ActiveBranch\\"
        direct_leaf = active_branch.Nodes.Add "Direct.ms"
        direct_leaf.ToolTipText = script_manager_test_temp_root + "ActiveRoot\\ActiveBranch\\Direct.ms"
        skipped_branch = active_root.Nodes.Add "SKIPPED BRANCH"
        skipped_branch.ToolTipText = script_manager_test_temp_root + "ActiveRoot\\SkippedBranch\\"
        skipped_leaf = skipped_branch.Nodes.Add "Skipped.ms"
        skipped_leaf.ToolTipText = script_manager_test_temp_root + "ActiveRoot\\SkippedBranch\\Skipped.ms"

        host_root = tree_control.Nodes.Add "HOST ROOT"
        host_root.ToolTipText = script_manager_test_temp_root + "HostRoot\\"
        host_leaf = host_root.Nodes.Add "Hosted.ms"
        host_leaf.ToolTipText = script_manager_test_temp_root + "HostRoot\\Hosted.ms"

        inactive_root = tree_control.Nodes.Add "INACTIVE ROOT"
        inactive_root.ToolTipText = script_manager_test_temp_root + "InactiveRoot\\"
        inactive_branch = inactive_root.Nodes.Add "INACTIVE BRANCH"
        inactive_branch.ToolTipText = script_manager_test_temp_root + "InactiveRoot\\InactiveBranch\\"
        inactive_leaf = inactive_branch.Nodes.Add "Inactive.ms"
        inactive_leaf.ToolTipText = script_manager_test_temp_root + "InactiveRoot\\InactiveBranch\\Inactive.ms"

        for tree_node in #(active_root, active_branch, host_root, host_leaf) do script_manager.setScriptTreeNodeVisualState tree_node 1
        for tree_node in #(direct_leaf) do script_manager.setScriptTreeNodeVisualState tree_node 2
        for tree_node in #(skipped_branch, skipped_leaf, inactive_root, inactive_branch, inactive_leaf) do script_manager.setScriptTreeNodeVisualState tree_node 0

        tree_control.ExpandAll()
        expand_ok = script_manager.expandEnabledScriptTree()

        direct_path_ok = expand_ok and active_root.IsExpanded and active_branch.IsExpanded
        host_path_ok = expand_ok and host_root.IsExpanded
        skipped_path_ok = expand_ok and not(skipped_branch.IsExpanded) and not(inactive_root.IsExpanded)

        for tree_node in #(active_root, active_branch, host_root, direct_leaf, host_leaf) do script_manager.setScriptTreeNodeVisualState tree_node 0

        empty_expand_ok = script_manager.expandEnabledScriptTree()
        empty_selection_ok = empty_expand_ok and not(active_root.IsExpanded) and not(active_branch.IsExpanded) and not(host_root.IsExpanded)

        script_manager.populateScriptTree restore_expansion:false
    )

    test_ok = menu_ok and direct_path_ok and host_path_ok and skipped_path_ok and empty_selection_ok
    if not test_ok then script_manager_test_passed = false

    format "PART 17 | menu:% | direct:% | host:% | skipped:% | none:% | PASS:%\n" menu_ok direct_path_ok host_path_ok skipped_path_ok empty_selection_ok test_ok
    test_ok
    -- return
)

/*
Verifies file selection and folder navigation request elevation through the same Explorer launcher.
The test inspects launch configuration without opening Windows Explorer or triggering a UAC prompt.
*/
function partOfTest18 =
(
    file_path = "C:\\Test Folder\\example.ms"
    folder_path = "C:\\Test Folder\\"
    file_info = script_manager.buildElevatedExplorerLaunchInfo file_path select_file:true
    folder_info = script_manager.buildElevatedExplorerLaunchInfo folder_path select_file:false

    file_ok = file_info != undefined and file_info.FileName == "explorer.exe" and file_info.Arguments == ("/select,\"" + file_path + "\"") and file_info.Verb == "runas" and file_info.UseShellExecute
    folder_ok = folder_info != undefined and folder_info.FileName == "explorer.exe" and folder_info.Arguments == ("\"" + folder_path + "\"") and folder_info.Verb == "runas" and folder_info.UseShellExecute
    test_ok = file_ok and folder_ok

    if not test_ok then script_manager_test_passed = false
    format "PART 18 | file:% | folder:% | PASS:%\n" file_ok folder_ok test_ok
    test_ok
    -- return
)

/*
Verifies OPEN GROUP is first and folder-only, and forces nested OFF/DIRECT scripts into one host.
The saved script modes are unchanged, and the shared dialog's title-button reload keeps its grouping.
*/
function partOfTest19 =
(
    group_directory = script_manager_test_temp_root + "SourceA\\GroupOpenTest\\"
    nested_directory = group_directory + "Nested\\"
    script_a = group_directory + "GroupAlpha.ms"
    script_b = nested_directory + "GroupBeta.ms"
    makeDir group_directory
    makeDir nested_directory

    body_a = "global script_manager_test_group_rollout_a; rollout script_manager_test_group_rollout_a \"Group A\" ()"
    body_b = "global script_manager_test_group_rollout_b; rollout script_manager_test_group_rollout_b \"Group B\" ()"
    write_ok = (writeScriptManagerTestScript script_a body_a) and (writeScriptManagerTestScript script_b body_b)

    key_a = script_manager.getScriptKey script_a
    key_b = script_manager.getScriptKey script_b
    mode_set_ok = script_manager.saveScriptLoadMode key_a #skip and script_manager.saveScriptLoadMode key_b #direct

    group_node = dotNetObject "System.Windows.Forms.TreeNode" "GroupOpenTest"
    group_node.ToolTipText = group_directory
    leaf_a = dotNetObject "System.Windows.Forms.TreeNode" "GroupAlpha.ms"
    leaf_a.ToolTipText = script_a
    nested_node = dotNetObject "System.Windows.Forms.TreeNode" "Nested"
    nested_node.ToolTipText = nested_directory
    leaf_b = dotNetObject "System.Windows.Forms.TreeNode" "GroupBeta.ms"
    leaf_b.ToolTipText = script_b
    group_node.Nodes.Add leaf_a
    nested_node.Nodes.Add leaf_b
    group_node.Nodes.Add nested_node

    group_data = script_manager.getScriptTreeGroupLoadData group_node
    plan_ok = group_data[1] == "SourceA\\GroupOpenTest" and group_data[2].count == 2 and (findItem group_data[2] script_a) > 0 and (findItem group_data[2] script_b) > 0
    leaf_data = script_manager.getScriptTreeGroupLoadData leaf_a
    leaf_plan_ok = leaf_data[1] == "" and leaf_data[2].count == 0

    tree_control = script_manager.getScriptTreeControl()
    previous_selection = tree_control.SelectedNode
    tree_control.Nodes.Add group_node
    tree_control.SelectedNode = group_node
    script_manager.updateScriptTreeContextMenuState()
    first_item_ok = script_manager.script_tree_context_menu.Items.Item[0].Text == "OPEN GROUP"
    folder_menu_ok = script_manager.script_tree_open_group_item.Visible and script_manager.script_tree_open_group_item.Enabled
    tree_control.SelectedNode = leaf_a
    script_manager.updateScriptTreeContextMenuState()
    leaf_menu_ok = not script_manager.script_tree_open_group_item.Visible
    tree_control.SelectedNode = group_node

    load_ok = write_ok and mode_set_ok and script_manager.openScriptTreeGroup group_node
    host_path = "SourceA\\GroupOpenTest"
    host_dialog = script_manager.getHostDialog host_path
    host_ok = load_ok and host_dialog != undefined and host_dialog.inDialog and (script_manager.getHostScriptPaths host_path).count == 2
    state_ok = script_manager.getScriptLoadMode key_a == #skip and script_manager.getScriptLoadMode key_b == #direct
    reload_ok = host_ok and script_manager.reloadHostDialogScripts host_path
    reloaded_host = script_manager.getHostDialog host_path
    reload_group_ok = reload_ok and reloaded_host != undefined and reloaded_host.inDialog and (script_manager.getHostScriptPaths host_path).count == 2
    cleanup_ok = script_manager.destroyHostDialog host_path clear_rollouts:true

    tree_control.Nodes.Remove group_node
    if previous_selection != undefined then tree_control.SelectedNode = previous_selection
    if doesFileExist script_a then deleteFile script_a
    if doesFileExist script_b then deleteFile script_b

    test_ok = write_ok and mode_set_ok and plan_ok and leaf_plan_ok and first_item_ok and folder_menu_ok and leaf_menu_ok and host_ok and state_ok and reload_group_ok and cleanup_ok
    if not test_ok then script_manager_test_passed = false
    format "PART 19 | first:% | folder:% | leaf-hidden:% | subtree:% | forced-host:% | modes-unchanged:% | reload:% | cleanup:% | PASS:%\n" first_item_ok folder_menu_ok leaf_menu_ok plan_ok host_ok state_ok reload_group_ok cleanup_ok test_ok
    test_ok
    -- return
)

/*
Verifies REFRESH LMB saves IGNORE even if ROOT PATH is invalid and then filters the SCRIPTS tree.
The valid-root step invokes the exact .NET MouseUp dispatcher used by the actual title button.
*/
function partOfTest20 =
(
    root_control = script_manager.getSourceRootPathControl()
    ignore_control = script_manager.getScriptIgnoreMaskControl()
    source_a = script_manager_test_temp_root + "SourceA\\"
    filtered_script_path = source_a + "ToolLeaf\\ToolLeaf.ms"
    missing_root = script_manager_test_temp_root + "__MissingRefreshRoot__\\"
    mask_text = "ToolLeaf|*.temp"

    control_ok = root_control != undefined and ignore_control != undefined
    blocked_save_ok = false
    refresh_ok = false
    ini_ok = false
    scripts_filtered_ok = false
    sources_unfiltered_ok = false
    text_unchanged_ok = false

    if control_ok then
    (
        script_manager.saveSourceEnabled source_a true
        root_control.text = missing_root
        ignore_control.text = mask_text

        blocked_refresh_result = script_manager.handleManualRefresh()
        blocked_save_ok = not blocked_refresh_result and (getINISetting script_manager.ini_path "Filter" "ScriptIgnoreMask") == mask_text

        root_control.text = script_manager_test_temp_root
        mouse_buttons_type = dotNetClass "System.Windows.Forms.MouseButtons"
        mouse_args = dotNetObject "System.Windows.Forms.MouseEventArgs" mouse_buttons_type.Left 1 0 0 0
        refresh_ok = scriptManagerRefreshButtonMouseUpHandler script_manager_ui.btn_refresh_restart mouse_args

        ini_ok = (getINISetting script_manager.ini_path "Filter" "ScriptIgnoreMask") == mask_text and script_manager.source_ignore_mask == mask_text
        scripts_filtered_ok = (findItem script_manager.available_script_paths filtered_script_path) == 0
        sources_unfiltered_ok = (findItem script_manager.available_source_directories (source_a + "ToolLeaf\\")) > 0
        text_unchanged_ok = ignore_control.text == mask_text
    )

    test_ok = control_ok and blocked_save_ok and refresh_ok and ini_ok and scripts_filtered_ok and sources_unfiltered_ok and text_unchanged_ok
    if not test_ok then script_manager_test_passed = false
    format "PART 20 | controls:% | saved-with-bad-root:% | LMB-refresh:% | INI:% | SCRIPTS-filter:% | SOURCES-kept:% | text:% | PASS:%\n" control_ok blocked_save_ok refresh_ok ini_ok scripts_filtered_ok sources_unfiltered_ok text_unchanged_ok test_ok
    test_ok
    -- return
)

/*
Verifies a new ROOT PATH is applied by LMB REFRESH and remains displayed after a full rollout rebuild.
Restores the test root afterwards so cleanup still targets the same files.
*/
function partOfTest23 =
(
    original_root = script_manager_test_temp_root
    alternate_root = original_root + "SourceA\\"
    root_control = script_manager.getSourceRootPathControl()
    field_ready_ok = root_control != undefined and (ScriptManagerIntegration.normalizeDirectoryPath root_control.text) == original_root
    apply_ok = false
    save_ok = false
    discovery_ok = false
    visible_script_ok = false
    reload_ok = false
    restored_field_ok = false
    restore_ok = false

    if root_control != undefined then
    (
        root_control.text = alternate_root
        apply_ok = script_manager.handleManualRefresh()
        save_ok = apply_ok and script_manager.root_directory == alternate_root and (ScriptManagerIntegration.normalizeDirectoryPath (getINISetting script_manager.ini_path "Options" "SourceRootDirectory")) == alternate_root
        discovery_ok = apply_ok and (findItem script_manager.available_source_directories (alternate_root + "ToolLeaf\\")) > 0 and (findItem script_manager.available_source_directories alternate_root) == 0
        visible_script_ok = apply_ok and script_manager.available_script_paths.count > 0 and (script_manager.getScriptTreeControl()).Nodes.Count > 0

        reload_ok = script_manager.reloadScripts()
        refreshed_control = script_manager.getSourceRootPathControl()
        restored_field_ok = reload_ok and refreshed_control != undefined and (ScriptManagerIntegration.normalizeDirectoryPath refreshed_control.text) == alternate_root

        if refreshed_control != undefined then
        (
            refreshed_control.text = original_root
            restore_ok = script_manager.handleManualRefresh()
            restore_ok = restore_ok and script_manager.root_directory == original_root and (ScriptManagerIntegration.normalizeDirectoryPath (getINISetting script_manager.ini_path "Options" "SourceRootDirectory")) == original_root
        )
    )

    test_ok = field_ready_ok and apply_ok and save_ok and discovery_ok and visible_script_ok and reload_ok and restored_field_ok and restore_ok
    if not test_ok then script_manager_test_passed = false
    format "PART 23 | initial-field:% | apply:% | saved:% | discovery:% | scripts-visible:% | reload:% | restored-field:% | restored-root:% | PASS:%\n" field_ready_ok apply_ok save_ok discovery_ok visible_script_ok reload_ok restored_field_ok restore_ok test_ok
    test_ok
    -- return
)

/*
Restores production manager paths/settings and removes isolated test files.
*/
function partOfTest21 =
(
    cleanup_ok = script_manager.clearLoadedRollouts()
    startup_loader_path = script_manager.getStartupPresetLoaderPath startup_directory:script_manager_test_temp_root
    if doesFileExist startup_loader_path then
    (
        if not(deleteFile startup_loader_path) then
        (
            format "TEST CLEANUP FAILED | startup loader still exists: %\n" startup_loader_path
            cleanup_ok = false
        )
    )
    if HasDictValue SCRIPT_MANAGER_REGISTRY "script_manager_test_runtime" then RemoveDictValue SCRIPT_MANAGER_REGISTRY "script_manager_test_runtime"

    try
    (
        if script_manager_test_direct_rollout != undefined and script_manager_test_direct_rollout.inDialog then destroyDialog script_manager_test_direct_rollout
    )
    catch
    (
        exception_text = getCurrentException()
        cleanup_ok = false
    )

    try
    (
        if script_manager_test_forced_rollout != undefined and script_manager_test_forced_rollout.inDialog then destroyDialog script_manager_test_forced_rollout
    )
    catch
    (
        exception_text = getCurrentException()
        cleanup_ok = false
    )

    script_manager.root_directory = script_manager_test_original_root
    script_manager.ini_path = script_manager_test_original_ini
    restore_ok = cleanup_ok and script_manager.reloadScripts()

    if script_manager_test_temp_root != undefined and script_manager_test_temp_root != "" then
    (
        for test_file in (getFiles (script_manager_test_temp_root + "SourceA\\*.ms")) do deleteFile test_file
        for test_file in (getFiles (script_manager_test_temp_root + "SourceA\\*.mcr")) do deleteFile test_file
        for test_file in (getFiles (script_manager_test_temp_root + "SourceB\\*.ms")) do deleteFile test_file
        for test_file in (getFiles (script_manager_test_temp_root + "SourceA\\ToolLeaf\\*.ms")) do deleteFile test_file
        for test_file in (getFiles (script_manager_test_temp_root + "SourceA\\Category\\ToolNested\\*.ms")) do deleteFile test_file
        for test_file in (getFiles (script_manager_test_temp_root + "SourceA\\Category\\ToolNested\\Internal\\*.ms")) do deleteFile test_file
        for test_file in (getFiles (script_manager_test_temp_root + "SourceA\\Category\\LooseTool\\*.ms")) do deleteFile test_file
        for test_file in (getFiles (script_manager_test_temp_root + "SourceA\\Category\\PendingTools\\*")) do deleteFile test_file
        for test_file in (getFiles (script_manager_test_temp_root + "SourceA\\Category\\.git\\*.ms")) do deleteFile test_file
        for test_file in (getFiles (script_manager_test_temp_root + "SourceA\\Category\\Archive-DELETED\\*.ms")) do deleteFile test_file
        for test_file in (getFiles (script_manager_test_temp_root + "SourceA\\Category\\Backup-OLD\\*.ms")) do deleteFile test_file
    )

    test_ini = (getDir #temp) + "\\Script-Manager-Test.ini"
    if doesFileExist test_ini then deleteFile test_ini

    test_ok = restore_ok
    if not test_ok then script_manager_test_passed = false

    format "PART 18 | restore:% | PASS:%\n" restore_ok test_ok
    test_ok
    -- return
)

/*
Verifies that opening from a cold dialog initializes both trees synchronously without RESTART.
The manager should not depend on an unreliable WinForms Timer tick to populate its rollouts.
*/
function partOfTest22 =
(
    startup_launch_before = SCRIPT_MANAGER_STARTUP_LAUNCH
    SCRIPT_MANAGER_STARTUP_LAUNCH = false

    close_ok = script_manager.destroyManagerDialog()
    open_ok = close_ok and script_manager.createManagerDialog()
    first_content_ok = open_ok and script_manager_ui.sr_loader.rollouts.count == 4 and script_manager.source_tree_initialized and script_manager.script_tree_initialized and script_manager.getSourceTreeControl() != undefined and script_manager.getScriptTreeControl() != undefined and script_manager.getScriptIgnoreMaskControl() != undefined and script_manager.getSourceRootPathControl() != undefined and (ScriptManagerIntegration.normalizeDirectoryPath (script_manager.getSourceRootPathControl()).text) == script_manager.root_directory
    no_timer_ok = script_manager.loader_init_timer == undefined

    second_close_ok = open_ok and script_manager.destroyManagerDialog()
    second_open_ok = second_close_ok and script_manager.createManagerDialog()
    second_content_ok = second_open_ok and script_manager_ui.sr_loader.rollouts.count == 4 and script_manager.source_tree_initialized and script_manager.script_tree_initialized and script_manager.getSourceTreeControl() != undefined and script_manager.getScriptTreeControl() != undefined

    SCRIPT_MANAGER_STARTUP_LAUNCH = startup_launch_before

    test_ok = close_ok and open_ok and first_content_ok and no_timer_ok and second_close_ok and second_open_ok and second_content_ok
    if not test_ok then script_manager_test_passed = false
    format "PART 22 | close:% | cold-open:% | first-content:% | no-timer:% | reopen:% | second-content:% | PASS:%\n" close_ok open_ok first_content_ok no_timer_ok second_open_ok second_content_ok test_ok
    test_ok
    -- return
)

/* Verifies the accepted BROWSE path commits the root, both trees, and an empty IGNORE value.
Restores the isolated test root and mask before the existing cleanup runs.
*/
function partOfTest24 =
(
    original_root = script_manager.root_directory
    original_mask = script_manager.source_ignore_mask
    alternate_root = script_manager_test_temp_root + "SourceA\\"
    ignore_control = script_manager.getScriptIgnoreMaskControl()
    test_ok = false
    try
    (
        if ignore_control == undefined then throw "IGNORE control unavailable"
        ignore_control.text = ""
        if not(script_manager.applyBrowsedSourceRootDirectory alternate_root) then throw "Browse commit failed"
        if script_manager.root_directory != alternate_root then throw "Browse root not active"
        if (getINISetting script_manager.ini_path "Options" "SourceRootDirectory") != alternate_root then throw "Browse root not persisted"
        if not(hasINISetting script_manager.ini_path "Filter" "ScriptIgnoreMask") then throw "Empty IGNORE key missing"
        if (getINISetting script_manager.ini_path "Filter" "ScriptIgnoreMask") != "" then throw "Empty IGNORE not persisted"
        if (script_manager.getSourceTreeControl()).Nodes.Count == 0 then throw "Browse SOURCES empty"
        if (script_manager.getScriptTreeControl()).Nodes.Count == 0 then throw "Browse SCRIPTS empty"
        if not(script_manager.reloadScripts()) then throw "Reload failed"
        if (script_manager.getSourceRootPathControl()).text != alternate_root then throw "Root control not restored"
        if (script_manager.getScriptIgnoreMaskControl()).text != "" then throw "Empty IGNORE not restored"
        (script_manager.getScriptIgnoreMaskControl()).text = ".git|*-OLD|"
        if not(script_manager.handleManualRefresh()) then throw "Nonempty IGNORE save failed"
        if not(script_manager.reloadScripts()) then throw "Nonempty IGNORE reload failed"
        if (script_manager.getScriptIgnoreMaskControl()).text != ".git|*-OLD|" then throw "Nonempty IGNORE not restored"
        test_ok = true
    )
    catch
    (
        format "PART 24 ERROR | %\n" (getCurrentException())
    )
    (script_manager.getSourceRootPathControl()).text = original_root
    (script_manager.getScriptIgnoreMaskControl()).text = original_mask
    restore_ok = script_manager.handleManualRefresh()
    test_ok = test_ok and restore_ok
    if not test_ok then script_manager_test_passed = false
    format "PART 24 | browse/save/reload:% | restored:%\n" test_ok restore_ok
    test_ok
    -- return
)

/*
Tests that the WinForms IGNORE save path persists without using the oversized
manager struct's local-variable thunk, including empty and nonempty masks.
*/
function partOfTest25 =
(
    local previous_ini = script_manager.ini_path
    local previous_mask = script_manager.source_ignore_mask
    local previous_patterns = script_manager.source_ignore_patterns
    local previous_regexes = script_manager.source_ignore_regexes
    local ignore_control = script_manager.getScriptIgnoreMaskControl()
    local previous_ui_text = if ignore_control != undefined then ignore_control.text else undefined
    local temporary_ini = (getDir #temp) + "\\Script-Manager-Ignore-Thunks-Test.ini"
    local test_ok = false
    local first_ok = false
    local empty_ok = false
    local wrapper_ok = false

    if doesFileExist temporary_ini then deleteFile temporary_ini
    try
    (
        if ignore_control == undefined then throw "IGNORE UI control missing"
        script_manager.ini_path = temporary_ini
        ignore_control.text = ".git|*-OLD|"
        first_ok = script_manager.applyPendingScriptOptions()
        if not first_ok then throw "Apply pending IGNORE failed"
        if (getINISetting temporary_ini "Filter" "ScriptIgnoreMask") != ".git|*-OLD|" then throw "Nonempty IGNORE readback failed"
        if script_manager.source_ignore_patterns.count != 2 then throw "Normalized IGNORE pattern count mismatch"

        ignore_control.text = ""
        empty_ok = script_manager.applyPendingScriptOptions()
        if not empty_ok then throw "Empty IGNORE save failed"
        if not(hasINISetting temporary_ini "Filter" "ScriptIgnoreMask") then throw "Empty IGNORE key missing"
        if (getINISetting temporary_ini "Filter" "ScriptIgnoreMask") != "" then throw "Empty IGNORE readback failed"
        if script_manager.source_ignore_patterns.count != 0 then throw "Empty IGNORE patterns not cleared"

        wrapper_ok = script_manager.saveScriptIgnoreMask ".git"
        if not wrapper_ok then throw "Compatibility saveScriptIgnoreMask failed"
        if (getINISetting temporary_ini "Filter" "ScriptIgnoreMask") != ".git" then throw "Compatibility IGNORE readback failed"
        test_ok = true
    )
    catch
    (
        format "PART 25 ERROR | %\n" (getCurrentException())
    )

    script_manager.ini_path = previous_ini
    script_manager.source_ignore_mask = previous_mask
    script_manager.source_ignore_patterns = previous_patterns
    script_manager.source_ignore_regexes = previous_regexes
    if ignore_control != undefined and previous_ui_text != undefined then ignore_control.text = previous_ui_text
    if doesFileExist temporary_ini then deleteFile temporary_ini

    if not test_ok then script_manager_test_passed = false
    format "PART 25 | pending:% | empty:% | compatibility:% | PASS:%\n" first_ok empty_ok wrapper_ok test_ok
    test_ok
    -- return
)

/*
Verifies that one render-local color palette preserves the previous sorted HOST
colors and never leaks a stale host cache into later UI events.
*/
function partOfTest26 =
(
    local previous_palette = script_manager.script_tree_batch_palette
    local previous_hosts = script_manager.script_tree_batch_hosts
    local test_ok = false
    local cache_ok = false
    local index_ok = false
    local host_ok = false
    local cleanup_ok = false
    local sync_ok = false

    try
    (
        render_cache = script_manager.buildScriptTreeBatchColorCache()
        cached_paths = render_cache[1]
        cached_hosts = render_cache[2]
        expected_paths = #()
        cache_ok = render_cache.count == 2
        host_ok = cache_ok

        for script_path in script_manager.available_script_paths do
        (
            host_path = script_manager.getBatchDialogPathForScript script_path
            if host_path != "" then
            (
                if (findItem expected_paths host_path) == 0 then append expected_paths host_path
                if not(HasDictValue cached_hosts (toLower script_path)) then host_ok = false
                if host_ok and (GetDictValue cached_hosts (toLower script_path)) != host_path then host_ok = false
            )
        )
        sort expected_paths
        cache_ok = cache_ok and cached_paths.count == expected_paths.count
        if cache_ok then
        (
            for path_index = 1 to expected_paths.count do
            (
                if cached_paths[path_index] != expected_paths[path_index] then cache_ok = false
            )
        )
        script_manager.script_tree_batch_palette = cached_paths
        script_manager.script_tree_batch_hosts = cached_hosts
        index_ok = true
        for host_index = 1 to expected_paths.count do
        (
            if script_manager.getBatchDialogColorIndex expected_paths[host_index] != host_index then index_ok = false
        )
        script_manager.script_tree_batch_palette = undefined
        script_manager.script_tree_batch_hosts = undefined
        if expected_paths.count > 0 then index_ok = index_ok and (script_manager.getBatchDialogColorIndex expected_paths[1]) == 1
        sync_ok = script_manager.syncScriptTreeChecks()
        cleanup_ok = script_manager.script_tree_batch_palette == undefined and script_manager.script_tree_batch_hosts == undefined
        test_ok = cache_ok and host_ok and index_ok and sync_ok and cleanup_ok
    )
    catch
    (
        format "PART 26 ERROR | %\n" (getCurrentException())
    )

    script_manager.script_tree_batch_palette = previous_palette
    script_manager.script_tree_batch_hosts = previous_hosts
    if not test_ok then script_manager_test_passed = false
    format "PART 26 | cached:% | hosts:% | sorted-colors:% | sync:% | cleaned:% | PASS:%\n" cache_ok host_ok index_ok sync_ok cleanup_ok test_ok
    test_ok
    -- return
)

/*
Checks every dynamically executed rollout and .NET callback has a persistent
MAXScript global slot. Missing declarations previously let a fileIn-local thunk
outlive its source frame, causing the first OPTIONS attachment or REFRESH save
handler to fail after the initial script evaluation.
*/
function partOfTest27 =
(
    local global_names = #(
        #script_manager_options_ui,
        #script_manager_ignore_ui,
        #scriptManagerRefreshButtonMouseUpHandler,
        #scriptManagerInitialLoaderTickHandler,
        #scriptManagerTreeOpenGroupContextHandler,
        #scriptManagerPersistIgnoreMask
    )
    local globals_ok = true
    local controls_ok = false
    local test_ok = false

    for global_name in global_names do
    (
        if not(globalVars.isglobal global_name) then
        (
            format "PART 27 | missing persistent global: %\n" global_name
            globals_ok = false
        )
    )

    controls_ok = script_manager_ui != undefined and script_manager_ui.sr_loader.rollouts.count == 4 and \
        script_manager.getSourceRootPathControl() != undefined and \
        script_manager.getSourceTreeControl() != undefined and \
        script_manager.getScriptTreeControl() != undefined and \
        script_manager.getScriptIgnoreMaskControl() != undefined

    test_ok = globals_ok and controls_ok
    if not test_ok then script_manager_test_passed = false
    format "PART 27 | persistent-globals:% | five-rollouts:% | PASS:%\n" globals_ok controls_ok test_ok
    test_ok
    -- return
)


/*
SHOW VERSIONED FILES defaults to ON for a missing INI key, but explicitly saved
OFF and ON settings remain authoritative.
*/
function partOfTest28 =
(
    local old_ini_path = script_manager.ini_path
    local old_filter_state = script_manager.show_versioned_files
    local test_ini_path = (getDir #temp) + "\\Script-Manager-Default-Versions-Test.ini"
    local default_on = false
    local saved_off = false
    local saved_on = false
    local test_ok = false

    try
    (
        if doesFileExist test_ini_path then deleteFile test_ini_path
        script_manager.ini_path = test_ini_path
        default_on = script_manager.loadShowVersionedFiles() == true
        script_manager.saveShowVersionedFiles false
        saved_off = script_manager.loadShowVersionedFiles() == false
        script_manager.saveShowVersionedFiles true
        saved_on = script_manager.loadShowVersionedFiles() == true
        test_ok = default_on and saved_off and saved_on
    )
    catch
    (
        format "PART 28 ERROR | %\n" (getCurrentException())
    )

    script_manager.ini_path = old_ini_path
    script_manager.show_versioned_files = old_filter_state
    if doesFileExist test_ini_path then deleteFile test_ini_path
    if not test_ok then script_manager_test_passed = false
    format "PART 28 | default-on:% | saved-off:% | saved-on:% | PASS:%\n" default_on saved_off saved_on test_ok
    test_ok
    -- return
)

/*
Dialog open/registration must not persist transient 1px floating position changes.
The correction itself must occur before CUI registers a dialog bar.
*/
function partOfTest29 =
(
    local production_path = script_manager.manager_source_path
    local source_text = readScriptManagerTestFileText production_path
    local guard_ok = false
    local correction_ok = false
    local idle_ok = script_manager.dialog_restore_depth == 0
    local test_ok = false

    if source_text != undefined then
    (
        guard_ok = (findString source_text "script_manager.dialog_restore_depth == 0 then script_manager.saveDialogState") != undefined and \
            (findString source_text "script_manager.dialog_restore_depth == 0 then script_manager.saveHostDialogState") != undefined
        correction_ok = (findString source_text "setDialogPos host_dialog dialog_position") != undefined and \
            (findString source_text "setDialogPos script_manager_ui dialog_position") != undefined
    )
    test_ok = guard_ok and correction_ok and idle_ok
    if not test_ok then script_manager_test_passed = false
    format "PART 29 | move-guards:% | pre-CUI-correction:% | idle:% | PASS:%\n" guard_ok correction_ok idle_ok test_ok
    test_ok
    -- return
)

/*
A script is always nested under its parent folder when that folder is visibly
present in SCRIPTS. Without the folder, the legacy single-script flattening
remains available. This exercises both cases against the real TreeView.
*/
function partOfTest30 =
(
    local source_a = script_manager_test_temp_root + "SourceA\\"
    local tool_dir = source_a + "ToolLeaf\\"
    local script_path = tool_dir + "ToolLeaf.ms"
    local group_path = "SourceA\\ToolLeaf"
    local group_index = findItem script_manager.available_group_paths group_path
    local script_index = findItem script_manager.available_script_paths script_path
    local original_displayable = undefined
    local visible_folder_ok = false
    local hidden_folder_ok = false
    local no_duplicate_ok = false
    local restore_ok = false
    local test_ok = false

    if group_index > 0 and script_index > 0 then
    (
        original_displayable = script_manager.available_group_displayable[group_index]
        try
        (
            /* Simulate an organizational folder that shares a name with its only script. */
            script_manager.available_group_displayable[group_index] = true
            if script_manager.populateScriptTree restore_expansion:false then
            (
                tree_control = script_manager.getScriptTreeControl()
                parent_node = undefined
                if tree_control != undefined then
                (
                    for root_index = 0 to (tree_control.Nodes.Count - 1) do
                    (
                        root_node = tree_control.Nodes.Item[root_index]
                        if root_node.Text == "SourceA" then
                        (
                            for child_index = 0 to (root_node.Nodes.Count - 1) do
                            (
                                child_node = root_node.Nodes.Item[child_index]
                                if child_node.Text == "ToolLeaf" then parent_node = child_node
                            )
                            if parent_node != undefined then
                            (
                                visible_folder_ok = parent_node.Nodes.Count == 1 and parent_node.Nodes.Item[0].Text == "ToolLeaf.ms"
                                no_duplicate_ok = true
                                for child_index = 0 to (root_node.Nodes.Count - 1) do
                                (
                                    child_node = root_node.Nodes.Item[child_index]
                                    if child_node.Text == "ToolLeaf.ms" then no_duplicate_ok = false
                                )
                            )
                        )
                    )
                )
            )

            script_manager.available_group_displayable[group_index] = false
            if script_manager.populateScriptTree restore_expansion:false then
            (
                tree_control = script_manager.getScriptTreeControl()
                if tree_control != undefined then
                (
                    for root_index = 0 to (tree_control.Nodes.Count - 1) do
                    (
                        root_node = tree_control.Nodes.Item[root_index]
                        if root_node.Text == "SourceA" then
                        (
                            flat_script_found = false
                            tool_folder_found = false
                            for child_index = 0 to (root_node.Nodes.Count - 1) do
                            (
                                child_node = root_node.Nodes.Item[child_index]
                                if child_node.Text == "ToolLeaf.ms" then flat_script_found = true
                                if child_node.Text == "ToolLeaf" then tool_folder_found = true
                            )
                            hidden_folder_ok = flat_script_found and not tool_folder_found
                        )
                    )
                )
            )
        )
        catch
        (
            format "PART 30 ERROR | %\n" (getCurrentException())
        )
        script_manager.available_group_displayable[group_index] = original_displayable
        restore_ok = script_manager.populateScriptTree restore_expansion:false
    )

    test_ok = visible_folder_ok and no_duplicate_ok and hidden_folder_ok and restore_ok
    if not test_ok then script_manager_test_passed = false
    format "PART 30 | existing-parent:% | no-duplicate:% | flatten-without-parent:% | restored:% | PASS:%\n" visible_folder_ok no_duplicate_ok hidden_folder_ok restore_ok test_ok
    test_ok
    -- return
)

/*
Regression: script checkmarks change only their glyph, never their text formatting.
HOST/DIRECT/SKIP nodes all recover the default text color even after older custom colors.
*/
function partOfTest31 =
(
    local color_type = dotNetClass "System.Drawing.Color"
    local neutral_color = color_type.FromArgb 225 225 225
    local legacy_color = color_type.FromArgb 255 165 60
    local script_node = dotNetObject "System.Windows.Forms.TreeNode" "Format-Test.ms"
    local host_ok = false
    local direct_ok = false
    local skip_ok = false
    local test_ok = false

    script_node.ForeColor = legacy_color
    host_ok = script_manager.applyScriptTreeNodeMode script_node #host and script_node.StateImageIndex == 1 and script_node.ForeColor.ToArgb() == neutral_color.ToArgb()

    script_node.ForeColor = legacy_color
    direct_ok = script_manager.applyScriptTreeNodeMode script_node #direct and script_node.StateImageIndex == 2 and script_node.ForeColor.ToArgb() == neutral_color.ToArgb()

    script_node.ForeColor = legacy_color
    skip_ok = script_manager.applyScriptTreeNodeMode script_node #skip and script_node.StateImageIndex == 0 and script_node.ForeColor.ToArgb() == neutral_color.ToArgb()

    test_ok = host_ok and direct_ok and skip_ok
    if not test_ok then script_manager_test_passed = false
    format "PART 31 | host-neutral:% | direct-neutral:% | skip-neutral:% | PASS:%\n" host_ok direct_ok skip_ok test_ok
    test_ok
    -- return
)

/*
Checks ordered right-click menu sections and SOURCES subtree eligibility for all MaxScript types.
Filters on SCRIPTS must not influence SOURCES eligibility; .git is always skipped.
*/
function partOfTest32 =
(
    local source_menu = script_manager.source_tree_context_menu
    local script_menu = script_manager.script_tree_context_menu
    local source_order_ok = false
    local script_order_ok = false
    local separators_ok = false
    local presence_ok = false
    local non_script_ok = false
    local git_ok = false
    local masked_ok = false
    local test_ok = false
    local temporary_root = ScriptManagerIntegration.normalizeDirectoryPath ((getDir #temp) + "\\Script-Manager-Source-Menu-Test")
    local nested_directory = temporary_root + "Category\\McrOnly\\"
    local mse_directory = temporary_root + "Category\\MseOnly\\"
    local plain_directory = temporary_root + "NotesOnly\\"
    local git_directory = temporary_root + ".git\\"
    local lookup_cache = Dictionary #string
    local mcr_path = nested_directory + "Custom.mcr"
    local mse_path = mse_directory + "Custom.mse"
    local git_path = git_directory + "Hidden.ms"

    try
    (
        script_order_ok = script_menu != undefined and script_menu.Items.Count == 10 and \
            script_menu.Items.Item[0].Text == "OPEN GROUP" and \
            script_menu.Items.Item[1].Text == "LOAD SCRIPT" and \
            script_menu.Items.Item[2].Text == "OPEN IN EXPLORER" and \
            script_menu.Items.Item[4].Text == "COLLAPSE" and \
            script_menu.Items.Item[5].Text == "COLLAPSE ALL" and \
            script_menu.Items.Item[7].Text == "EXPAND" and \
            script_menu.Items.Item[8].Text == "EXPAND ALL" and \
            script_menu.Items.Item[9].Text == "EXPAND ENABLED"
        source_order_ok = source_menu != undefined and source_menu.Items.Count == 5 and \
            source_menu.Items.Item[0].Text == "LOAD \\ RELOAD DIALOG" and \
            source_menu.Items.Item[2].Text == "COLLAPSE ALL" and \
            source_menu.Items.Item[4].Text == "EXPAND ALL"
        separators_ok = source_order_ok and script_order_ok and \
            (script_menu.Items.Item[3].GetType()).Name == "ToolStripSeparator" and \
            (script_menu.Items.Item[6].GetType()).Name == "ToolStripSeparator" and \
            (source_menu.Items.Item[1].GetType()).Name == "ToolStripSeparator" and \
            (source_menu.Items.Item[3].GetType()).Name == "ToolStripSeparator"

        makeDir temporary_root
        makeDir (temporary_root + "Category\\")
        makeDir nested_directory
        makeDir mse_directory
        makeDir plain_directory
        makeDir git_directory
        writeScriptManagerTestScript mcr_path "-- macro test"
        writeScriptManagerTestScript mse_path "-- encrypted extension test placeholder"
        writeScriptManagerTestScript (plain_directory + "notes.txt") "not MaxScript"
        writeScriptManagerTestScript git_path "-- excluded repository"

        presence_ok = script_manager.sourceDirectoryHasMaxScripts (temporary_root + "Category\\") lookup_cache and \
            script_manager.sourceDirectoryHasMaxScripts nested_directory lookup_cache and \
            script_manager.sourceDirectoryHasMaxScripts mse_directory lookup_cache
        non_script_ok = not(script_manager.sourceDirectoryHasMaxScripts plain_directory lookup_cache)
        git_ok = not(script_manager.sourceDirectoryHasMaxScripts git_directory lookup_cache)
        masked_ok = not(script_manager.isDefaultExcludedSourceDirectory nested_directory) and script_manager.isDefaultExcludedSourceDirectory git_directory
    )
    catch
    (
        format "PART 32 ERROR | %\n" (getCurrentException())
    )

    for file_path in #(mcr_path, mse_path, git_path, plain_directory + "notes.txt") do
    (
        if doesFileExist file_path then deleteFile file_path
    )
    test_ok = script_order_ok and source_order_ok and separators_ok and presence_ok and non_script_ok and git_ok and masked_ok
    if not test_ok then script_manager_test_passed = false
    format "PART 32 | context-order:% | source-order:% | separators:% | script-recursive:% | no-script:% | git:% | source-independent:% | PASS:%\n" script_order_ok source_order_ok separators_ok presence_ok non_script_ok git_ok masked_ok test_ok
    test_ok
    -- return
)

/*
Regression: ToolStripCollection.Add(separator) returns an integer index, not the
ToolStripSeparator object. All four stored separator slots must be live .NET
objects supporting Visible, including the context update from the crash report.
*/
function partOfTest33 =
(
    local source_ok = false
    local script_ok = false
    local update_ok = false
    local test_ok = false

    try
    (
        source_ok = script_manager.source_tree_open_separator != undefined and \
            (script_manager.source_tree_open_separator.GetType()).Name == "ToolStripSeparator" and \
            (script_manager.source_tree_expand_separator.GetType()).Name == "ToolStripSeparator"
        script_ok = script_manager.script_tree_open_separator != undefined and \
            (script_manager.script_tree_open_separator.GetType()).Name == "ToolStripSeparator" and \
            (script_manager.script_tree_expand_separator.GetType()).Name == "ToolStripSeparator"

        if source_ok and script_ok then
        (
            update_ok = script_manager.updateSourceTreeContextMenuState() and \
                script_manager.updateScriptTreeContextMenuState()
        )
    )
    catch
    (
        format "PART 33 ERROR | %\n" (getCurrentException())
    )

    test_ok = source_ok and script_ok and update_ok
    if not test_ok then script_manager_test_passed = false
    format "PART 33 | source-separators:% | script-separators:% | visibility-update:% | PASS:%\n" source_ok script_ok update_ok test_ok
    test_ok
    -- return
)

/*
Verifies the working CODEBASE pre-registration and native CUI offset calculations.
Docked positioning must remain unchanged; the registered raw target is preserved.
*/
function partOfTest34 =
(
    local original_position = [253,451]
    local creation_position = undefined
    local before_registration = undefined
    local after_registration = undefined
    local left_position = undefined
    local right_position = undefined
    local cycles_ok = true
    local test_ok = false

    try
    (
        creation_position = scriptManagerGetRegistrationPosition original_position "float"
        before_registration = creation_position + [6,-2]
        after_registration = before_registration + [6,29]
        left_position = scriptManagerGetRegistrationPosition original_position "left"
        right_position = scriptManagerGetRegistrationPosition original_position "right"

        for cycle_index = 1 to 5 do
        (
            if ((scriptManagerGetRegistrationPosition after_registration "float") + [6,-2] + [6,29]) != original_position then cycles_ok = false
        )

        test_ok = creation_position == [241,424] and \
            before_registration == [247,422] and \
            after_registration == original_position and \
            left_position == original_position and \
            right_position == original_position and cycles_ok
    )
    catch
    (
        format "PART 34 ERROR | %\n" (getCurrentException())
    )

    if not test_ok then script_manager_test_passed = false
    format "PART 34 | raw-create:% | raw-pre:% | raw-registered:% | left:% | right:% | cycles:% | PASS:%\n" \
        creation_position before_registration after_registration left_position right_position cycles_ok test_ok
    test_ok
    -- return
)

/*
Verifies that single-click only selects/cycles state and double-click loads MS/MCR scripts.
Checks the double-click event binding and label-only hit testing, plus unsupported types.
*/
function partOfTest35 =
(
    local production_path = script_manager_test_root + "..\\Script-Manager.ms"
    local source_text = readScriptManagerTestFileText production_path
    local click_binding_ok = false
    local double_binding_ok = false
    local label_gate_ok = false
    local single_click_safe_ok = false
    local ms_load_ok = false
    local mcr_load_ok = false
    local mse_skip_ok = false
    local folder_skip_ok = false
    local test_ok = false

    if source_text != undefined then
    (
        click_binding_ok = (findString source_text "on tv_scripts NodeMouseClick click_args") != undefined
        double_binding_ok = (findString source_text "on tv_scripts NodeMouseDoubleClick click_args") != undefined and \
            (findString source_text "script_manager.handleScriptTreeNodeDoubleClick click_args") != undefined
        label_gate_ok = (findString source_text "if hit_info.Location.ToString() != \"Label\" then return false") != undefined and \
            (findString source_text "this.loadDoubleClickedScriptTreeNode click_args.Node") != undefined
        local click_handler_start = findString source_text "function handleScriptTreeNodeClick click_args ="
        local double_handler_start = findString source_text "function handleScriptTreeNodeDoubleClick click_args ="
        if click_handler_start != undefined and double_handler_start != undefined and double_handler_start > click_handler_start then
        (
            local click_handler_text = subString source_text click_handler_start (double_handler_start - click_handler_start)
            single_click_safe_ok = (findString click_handler_text "return this.cycleScriptTreeNodeMode click_args.Node") != undefined and \
                (findString click_handler_text "loadClickedScriptTreeNode") == undefined and \
                (findString click_handler_text "loadDoubleClickedScriptTreeNode") == undefined
        )
    )

    try
    (
        local source_a = script_manager_test_temp_root + "SourceA\\"
        local ms_path = source_a + "ClickLoad.ms"
        local mcr_path = source_a + "ClickMacro.mcr"
        local mse_path = source_a + "ClickEncrypted.mse"
        local ms_node = dotNetObject "System.Windows.Forms.TreeNode" "ClickLoad.ms"
        local mcr_node = dotNetObject "System.Windows.Forms.TreeNode" "ClickMacro.mcr"
        local mse_node = dotNetObject "System.Windows.Forms.TreeNode" "ClickEncrypted.mse"
        local folder_node = dotNetObject "System.Windows.Forms.TreeNode" "Category"

        ms_node.ToolTipText = ms_path
        mcr_node.ToolTipText = mcr_path
        mse_node.ToolTipText = mse_path
        folder_node.ToolTipText = source_a

        script_manager_test_marker_g = 0
        local ms_written = writeScriptManagerTestScript ms_path "global script_manager_test_marker_g; script_manager_test_marker_g += 1"
        local mcr_written = writeScriptManagerTestScript mcr_path "global script_manager_test_marker_g; script_manager_test_marker_g += 1; macroScript ClickLoadMacroTest category:\"Script-Manager Test\" (on execute do ())"
        if ms_written then ms_load_ok = script_manager.loadDoubleClickedScriptTreeNode ms_node and script_manager_test_marker_g == 1
        if mcr_written then mcr_load_ok = script_manager.loadDoubleClickedScriptTreeNode mcr_node and script_manager_test_marker_g == 2
        mse_skip_ok = not(script_manager.loadDoubleClickedScriptTreeNode mse_node) and script_manager_test_marker_g == 2
        folder_skip_ok = not(script_manager.loadDoubleClickedScriptTreeNode folder_node) and script_manager_test_marker_g == 2

        if doesFileExist ms_path then deleteFile ms_path
        if doesFileExist mcr_path then deleteFile mcr_path
    )
    catch
    (
        format "PART 35 ERROR | %\n" (getCurrentException())
    )

    test_ok = click_binding_ok and double_binding_ok and label_gate_ok and single_click_safe_ok and ms_load_ok and mcr_load_ok and mse_skip_ok and folder_skip_ok
    if not test_ok then script_manager_test_passed = false
    format "PART 35 | click-binding:% | double-click-binding:% | label-gate:% | single-click-safe:% | ms:% | mcr:% | mse-ignored:% | folder-ignored:% | PASS:%\n" click_binding_ok double_binding_ok label_gate_ok single_click_safe_ok ms_load_ok mcr_load_ok mse_skip_ok folder_skip_ok test_ok
    test_ok
    -- return
)

/*
Tests position-trace instrumentation and verifies it does not mutate geometry.
Both the manager and host lifecycles must report saved, actual, and delta coordinates.
*/
function partOfTest36 =
(
    local production_path = script_manager_test_root + "..\\Script-Manager.ms"
    local source_text = readScriptManagerTestFileText production_path
    local helper_ok = false
    local main_ok = false
    local host_ok = false
    local trace_ok = false
    local original_position = [253,451]
    local test_ok = false

    if source_text != undefined then
    (
        helper_ok = (findString source_text "function scriptManagerTraceDialogPosition") != undefined and \
            (findString source_text "[Script-Manager][XY]") != undefined and \
            (findString source_text "saved:% | actual:% | delta:%") != undefined
        main_ok = (findString source_text "\"MAIN\" \"INI-RESTORE\"") != undefined and \
            (findString source_text "\"MAIN\" \"BEFORE-CUI-REGISTER\"") != undefined and \
            (findString source_text "\"MAIN\" \"AFTER-CUI-REGISTER\"") != undefined and \
            (findString source_text "\"MAIN\" \"AFTER-DOCK-RESTORE\"") != undefined and \
            (findString source_text "\"MAIN\" \"SAVE-BEFORE-WRITE\"") != undefined
        host_ok = (findString source_text "host_path \"INI-RESTORE\"") != undefined and \
            (findString source_text "host_path \"BEFORE-CUI-REGISTER\"") != undefined and \
            (findString source_text "host_path \"AFTER-CUI-REGISTER\"") != undefined and \
            (findString source_text "host_path \"AFTER-DOCK-RESTORE\"") != undefined and \
            (findString source_text "host_path \"SAVE-BEFORE-WRITE\"") != undefined and \
            (findString source_text "\"MOVED-EVENT\"") != undefined
    )

    try
    (
        trace_ok = scriptManagerTraceDialogPosition "TEST" "INI-RESTORE" undefined saved_position:original_position dock_text:"float"
    )
    catch
    (
        format "PART 36 ERROR | %\n" (getCurrentException())
    )

    test_ok = helper_ok and main_ok and host_ok and trace_ok and original_position == [253,451]
    if not test_ok then script_manager_test_passed = false
    format "PART 36 | helper:% | main:% | host:% | no-mutation:% | PASS:%\n" helper_ok main_ok host_ok trace_ok test_ok
    test_ok
    -- return
)

/*
Verifies SCRIPTS expansion states are restored at startup and across refresh/restart.
Unsaved folders must be collapsed, saved ON/OFF must round-trip, and rebuilds
must not overwrite saved expansion values while clearing and restoring nodes.
*/
function partOfTest37 =
(
    local production_path = script_manager_test_root + "..\\Script-Manager.ms"
    local source_text = readScriptManagerTestFileText production_path
    local startup_ok = false
    local restoring_ok = false
    local guard_ok = false
    local default_ok = false
    local expanded_ok = false
    local collapsed_ok = false
    local test_ok = false
    local original_ini = script_manager.ini_path
    local original_root = script_manager.root_directory
    local test_ini = script_manager_test_temp_root + "ScriptTreeExpansion_1.196.ini"

    if source_text != undefined then
    (
        startup_ok = (findString source_text "script_tree_initialized = this.populateScriptTree restore_expansion:true") != undefined
        restoring_ok = (findString source_text "this.loadTreeNodeOpenState folder_node \"ScriptTreeOpen\" default_expanded:false") != undefined
        guard_ok = (findString source_text "/* Suppress expand/collapse persistence throughout Clear, rebuild, and restore. */") != undefined
    )

    try
    (
        if doesFileExist test_ini then deleteFile test_ini
        script_manager.ini_path = test_ini
        script_manager.root_directory = script_manager_test_temp_root

        local tree_node = dotNetObject "System.Windows.Forms.TreeNode" "StateTest"
        tree_node.ToolTipText = script_manager_test_temp_root + "StateTest\\"
        local state_key = script_manager.getTreeExpansionKey tree_node

        if state_key != "" then
        (
            default_ok = not(script_manager.loadTreeNodeOpenState tree_node "ScriptTreeOpen" default_expanded:false)
            setINISetting test_ini "ScriptTreeOpen" state_key "1" forceUTF16:false
            expanded_ok = script_manager.loadTreeNodeOpenState tree_node "ScriptTreeOpen" default_expanded:false
            setINISetting test_ini "ScriptTreeOpen" state_key "0" forceUTF16:false
            collapsed_ok = not(script_manager.loadTreeNodeOpenState tree_node "ScriptTreeOpen" default_expanded:false)
        )
    )
    catch
    (
        format "PART 37 ERROR | %\n" (getCurrentException())
    )

    script_manager.ini_path = original_ini
    script_manager.root_directory = original_root
    if doesFileExist test_ini then deleteFile test_ini

    test_ok = startup_ok and restoring_ok and guard_ok and default_ok and expanded_ok and collapsed_ok
    if not test_ok then script_manager_test_passed = false
    format "PART 37 | startup:% | restore:% | no-clobber:% | default-collapsed:% | saved-open:% | saved-closed:% | PASS:%\n" startup_ok restoring_ok guard_ok default_ok expanded_ok collapsed_ok test_ok
    test_ok
    -- return
)

/*
Verifies main manager height minimum is 1024 px without changing default
height, saved larger sizes, maximum clamp, or hosted dialog minimum.
*/
function partOfTest38 =
(
    original_ini = script_manager.ini_path
    test_ini = script_manager_test_temp_root + "ScriptManager_MinHeight_1.197.ini"
    production_path = script_manager_test_root + "..\\Script-Manager.ms"
    source_text = readScriptManagerTestFileText production_path
    source_ok = false
    minimum_ok = false
    preserved_ok = false
    maximum_ok = false
    default_ok = false
    test_ok = false

    if source_text != undefined then
    (
        source_ok = (findString source_text "minSize:[336,1024]") != undefined and \
                    (findString source_text "if dialog_height < 1024 then dialog_height = 1024") != undefined and \
                    (findString source_text "minSize:[336,300]") != undefined
    )

    try
    (
        if doesFileExist test_ini then deleteFile test_ini
        script_manager.ini_path = test_ini

        dialog_state = script_manager.loadDialogState()
        default_ok = (dialog_state[2] == 1970)
        setINISetting test_ini "Dialog" "Height" "800" forceUTF16:false
        dialog_state = script_manager.loadDialogState()
        minimum_ok = (dialog_state[2] == 1024)
        setINISetting test_ini "Dialog" "Height" "1200" forceUTF16:false
        dialog_state = script_manager.loadDialogState()
        preserved_ok = (dialog_state[2] == 1200)
        setINISetting test_ini "Dialog" "Height" "2400" forceUTF16:false
        dialog_state = script_manager.loadDialogState()
        maximum_ok = (dialog_state[2] == 2000)
    )
    catch
    (
        format "PART 38 ERROR | %\n" (getCurrentException())
    )

    script_manager.ini_path = original_ini
    if doesFileExist test_ini then deleteFile test_ini

    test_ok = source_ok and default_ok and minimum_ok and preserved_ok and maximum_ok
    if not test_ok then script_manager_test_passed = false
    format "PART 38 | min-size:% | default:% | clamp:% | saved:% | max:% | PASS:%\n" source_ok default_ok minimum_ok preserved_ok maximum_ok test_ok
    test_ok
    -- return
)

/*
Verifies COLLAPSE DIRS defaults to compact mode, persists ON/OFF in the
repository INI, and toggles full versus compact SCRIPTS hierarchy without
changing file leaf paths or losing branches with multiple visible scripts.
*/
function partOfTest39 =
(
    local original_ini = script_manager.ini_path
    local original_root = script_manager.root_directory
    local original_collapse = script_manager.collapse_script_dirs
    local original_group_paths = script_manager.available_group_paths
    local original_group_tree_paths = script_manager.available_group_tree_paths
    local original_group_directories = script_manager.available_group_directories
    local original_group_displayable = script_manager.available_group_displayable
    local original_script_paths = script_manager.available_script_paths
    local original_script_group_paths = script_manager.available_script_group_paths
    local original_script_tree_group_paths = script_manager.available_script_tree_group_paths
    local original_script_directories = script_manager.available_script_directories
    local test_ini = script_manager_test_temp_root + "CollapseDirs_1.199.ini"
    local test_root = script_manager_test_temp_root
    local sample_directory = test_root + "Sample\\"
    local chamfer_directory = sample_directory + "Chamfer\\"
    local align_directory = sample_directory + "Align\\"
    local ui_ok = script_manager_show_ui != undefined and isProperty script_manager_show_ui #chk_collapse_dirs
    local default_ok = false
    local persisted_ok = false
    local full_ok = false
    local compact_ok = false
    local multi_script_ok = false
    local paths_ok = false
    local restore_ok = false
    local test_ok = false

    try
    (
        if doesFileExist test_ini then deleteFile test_ini
        script_manager.ini_path = test_ini
        script_manager.root_directory = test_root
        default_ok = script_manager.loadCollapseScriptDirs()

        script_manager.available_group_paths = #("Sample", "Sample\\Chamfer", "Sample\\Align")
        script_manager.available_group_tree_paths = #("Sample", "Sample\\Chamfer", "Sample\\Align")
        script_manager.available_group_directories = #(sample_directory, chamfer_directory, align_directory)
        script_manager.available_group_displayable = #(true, false, false)
        script_manager.available_script_paths = #(chamfer_directory + "Chamfer.ms", align_directory + "Align.ms", align_directory + "Align-Extra.ms")
        script_manager.available_script_group_paths = #("Sample\\Chamfer", "Sample\\Align", "Sample\\Align")
        script_manager.available_script_tree_group_paths = #("Sample\\Chamfer", "Sample\\Align", "Sample\\Align")
        script_manager.available_script_directories = #(chamfer_directory, align_directory, align_directory)

        script_manager.saveCollapseScriptDirs false
        persisted_ok = (getINISetting test_ini "Filter" "CollapseDirs") == "0" and not(script_manager.loadCollapseScriptDirs())
        full_path_ok = script_manager.getScriptTreeDisplayGroupPath 1 == "Sample\\Chamfer"
        if script_manager.populateScriptTree restore_expansion:false then
        (
            tree_control = script_manager.getScriptTreeControl()
            if tree_control.Nodes.Count == 1 then
            (
                sample_node = tree_control.Nodes.Item[0]
                full_ok = sample_node.Text == "Sample" and sample_node.Nodes.Count == 2 and (scriptManagerTestTreeContainsText sample_node.Nodes "Chamfer") and (scriptManagerTestTreeContainsText sample_node.Nodes "Chamfer.ms")
            )
        )

        script_manager.saveCollapseScriptDirs true
        persisted_ok = persisted_ok and (getINISetting test_ini "Filter" "CollapseDirs") == "1" and script_manager.loadCollapseScriptDirs()
        compact_path_ok = script_manager.getScriptTreeDisplayGroupPath 1 == "Sample"
        if script_manager.populateScriptTree restore_expansion:false then
        (
            tree_control = script_manager.getScriptTreeControl()
            if tree_control.Nodes.Count == 1 then
            (
                sample_node = tree_control.Nodes.Item[0]
                compact_ok = sample_node.Text == "Sample" and sample_node.Nodes.Count == 2 and scriptManagerTestTreeContainsText sample_node.Nodes "Chamfer.ms" and not(scriptManagerTestTreeContainsText sample_node.Nodes "Chamfer")
                multi_script_ok = scriptManagerTestTreeContainsText sample_node.Nodes "Align" and scriptManagerTestTreeContainsText sample_node.Nodes "Align.ms" and scriptManagerTestTreeContainsText sample_node.Nodes "Align-Extra.ms"
                for child_index = 0 to (sample_node.Nodes.Count - 1) do
                (
                    child_node = sample_node.Nodes.Item[child_index]
                    if child_node.Text == "Chamfer.ms" then paths_ok = child_node.ToolTipText == (chamfer_directory + "Chamfer.ms")
                )
            )
        )
        full_ok = full_ok and full_path_ok
        compact_ok = compact_ok and compact_path_ok
        persisted_ok = persisted_ok and ui_ok
    )
    catch
    (
        format "PART 39 ERROR | %\n" (getCurrentException())
    )

    script_manager.ini_path = original_ini
    script_manager.root_directory = original_root
    script_manager.collapse_script_dirs = original_collapse
    script_manager.available_group_paths = original_group_paths
    script_manager.available_group_tree_paths = original_group_tree_paths
    script_manager.available_group_directories = original_group_directories
    script_manager.available_group_displayable = original_group_displayable
    script_manager.available_script_paths = original_script_paths
    script_manager.available_script_group_paths = original_script_group_paths
    script_manager.available_script_tree_group_paths = original_script_tree_group_paths
    script_manager.available_script_directories = original_script_directories
    if doesFileExist test_ini then deleteFile test_ini
    restore_ok = script_manager.populateScriptTree restore_expansion:true
    test_ok = default_ok and persisted_ok and full_ok and compact_ok and multi_script_ok and paths_ok and restore_ok
    if not test_ok then script_manager_test_passed = false
    format "PART 39 | ui:% | default:% | persistence:% | full:% | compact:% | multi-script:% | leaf-path:% | restored:% | PASS:%\n" ui_ok default_ok persisted_ok full_ok compact_ok multi_script_ok paths_ok restore_ok test_ok
    test_ok
    -- return
)


/*
Verifies that the SHOW section owns all three filter checkboxes on one row
while preserving their existing handlers and labels.
*/
function partOfTest40 =
(
    local production_path = script_manager_test_root + "..\\Script-Manager.ms"
    local production_text = readScriptManagerTestFileText production_path
    local labels_ok = false
    local ui_ok = false
    local row_ok = false
    local handlers_ok = false
    local test_ok = false

    if production_text != undefined then
    (
        labels_ok = (findString production_text "checkbox chk_show_versions \\\"VERSIONED FILES\\\" pos:[6,6] width:110") != undefined
        labels_ok = labels_ok and (findString production_text "checkbox chk_clean_scripts \\\"CLEAN SCRIPTS\\\" pos:[116,6] width:94") != undefined
        labels_ok = labels_ok and (findString production_text "checkbox chk_collapse_dirs \\\"COLLAPSE DIRS\\\" pos:[210,6] width:96") != undefined
        handlers_ok = (findString production_text "on chk_show_versions changed state do") != undefined and (findString production_text "on chk_clean_scripts changed state do") != undefined and (findString production_text "on chk_collapse_dirs changed state do") != undefined
    )

    try
    (
        ui_ok = script_manager_show_ui != undefined and script_manager_show_ui.chk_show_versions != undefined and script_manager_show_ui.chk_clean_scripts != undefined and script_manager_show_ui.chk_collapse_dirs != undefined
        if ui_ok then
        (
            row_ok = script_manager_show_ui.chk_show_versions.pos == [6,6] and script_manager_show_ui.chk_clean_scripts.pos == [116,6] and script_manager_show_ui.chk_collapse_dirs.pos == [210,6]
            row_ok = row_ok and script_manager_show_ui.chk_show_versions.width == 110 and script_manager_show_ui.chk_clean_scripts.width == 94 and script_manager_show_ui.chk_collapse_dirs.width == 96
            row_ok = row_ok and (script_manager_show_ui.chk_collapse_dirs.pos.x + script_manager_show_ui.chk_collapse_dirs.width) <= script_manager_show_ui.width
        )
    )
    catch
    (
        format "PART 40 ERROR | %\n" (getCurrentException())
    )

    test_ok = labels_ok and ui_ok and row_ok and handlers_ok
    if not test_ok then script_manager_test_passed = false
    format "PART 40 | labels:% | ui:% | single-row:% | handlers:% | PASS:%\n" labels_ok ui_ok row_ok handlers_ok test_ok
    test_ok
    -- return
)

/*
Verifies that CUI unregister and destruction cannot overwrite the saved floating
geometry, and that main/host creation use the pre-registration helper only.
*/
function partOfTest41 =
(
    local production_path = script_manager_test_root + "..\\Script-Manager.ms"
    local production_text = readScriptManagerTestFileText production_path
    local main_guard_ok = false
    local host_guard_ok = false
    local registered_guard_ok = false
    local main_restore_ok = false
    local host_restore_ok = false
    local test_ok = false

    if production_text != undefined then
    (
        main_guard_ok = (findString production_text "not script_manager.is_destroying_manager and script_manager.dialog_restore_depth == 0 then script_manager.saveDialogState") != undefined
        host_guard_ok = (findString production_text "not script_manager.is_destroying_host and script_manager.dialog_restore_depth == 0 then script_manager.saveHostDialogState") != undefined
        registered_guard_ok = (findString production_text "if dialog_value.dialogBar then return false") != undefined
        main_restore_ok = (findString production_text "scriptManagerApplyPreRegistrationOffset script_manager_ui dialog_position dock_text") != undefined
        host_restore_ok = (findString production_text "scriptManagerApplyPreRegistrationOffset host_dialog dialog_position dock_text") != undefined
    )

    test_ok = main_guard_ok and host_guard_ok and registered_guard_ok and main_restore_ok and host_restore_ok
    if not test_ok then script_manager_test_passed = false
    format "PART 41 | main-save-guard:% | host-save-guard:% | registered-move-guard:% | main-restore:% | host-restore:% | PASS:%\n" \
        main_guard_ok host_guard_ok registered_guard_ok main_restore_ok host_restore_ok test_ok
    test_ok
    -- return
)

/*
Verifies that TreeView LOAD SCRIPT logs item/path/mode and the outcome of fileIn.
Also checks failure propagation without marking an exception-throwing file as loaded.
*/
function partOfTest42 =
(
    local production_path = script_manager_test_root + "..\\Script-Manager.ms"
    local source_text = readScriptManagerTestFileText production_path
    local start_log_ok = false
    local result_log_ok = false
    local detail_log_ok = false
    local actions_ok = false
    local missing_file_ok = false
    local failing_file_ok = false
    local test_ok = false

    if source_text != undefined then
    (
        start_log_ok = (findString source_text "[Script-Manager][TREE LOAD] START | action:% | item:% | file:% | exists:% | saved_mode:% | run_mode:#standalone") != undefined
        result_log_ok = (findString source_text "[Script-Manager][TREE LOAD] % | action:% | item:% | file:%") != undefined
        detail_log_ok = (findString source_text "[Script-Manager][TREE LOAD] ERROR | file:% | detail:%") != undefined and \
            (findString source_text "[Script-Manager][TREE LOAD] EXCEPTION | file:% | detail:%") != undefined
        actions_ok = (findString source_text "this.loadSelectedScriptTreeItem action_name:\"DOUBLE-CLICK\"") != undefined and \
            (findString source_text "function loadSelectedScriptTreeItem action_name:\"RMB LOAD SCRIPT\"") != undefined
    )

    try
    (
        local source_a = script_manager_test_temp_root + "SourceA\\"
        local missing_path = source_a + "ScriptManager-Missing-Diagnostic.ms"
        local failing_path = source_a + "ScriptManager-Failing-Diagnostic.ms"
        missing_file_ok = not(script_manager.loadSingleScriptForcedDirect missing_path)
        if writeScriptManagerTestScript failing_path "throw \"SCRIPT_MANAGER_TEST_FILEIN_FAILURE\"" then
        (
            failing_file_ok = not(script_manager.loadSingleScriptForcedDirect failing_path)
            if doesFileExist failing_path then deleteFile failing_path
        )
    )
    catch
    (
        format "PART 42 ERROR | %\n" (getCurrentException())
    )

    test_ok = start_log_ok and result_log_ok and detail_log_ok and actions_ok and missing_file_ok and failing_file_ok
    if not test_ok then script_manager_test_passed = false
    format "PART 42 | start:% | result:% | failure-detail:% | actions:% | missing:% | failing-file:% | PASS:%\n" \
        start_log_ok result_log_ok detail_log_ok actions_ok missing_file_ok failing_file_ok test_ok
    test_ok
    -- return
)


/*
Regression: directories without .ms/.mcr/.mzp/.mse files at any depth are
absent from discovered SCRIPTS groups, while parent folders and each file type survive.
MZP is used for directory eligibility only; script loading remains unchanged.
*/
function partOfTest43 =
(
    local original_root = script_manager.root_directory
    local original_patterns = script_manager.source_ignore_patterns
    local original_versioned = script_manager.show_versioned_files
    local original_clean = script_manager.show_clean_scripts_only
    local original_groups = script_manager.available_group_paths
    local original_tree_groups = script_manager.available_group_tree_paths
    local original_names = script_manager.available_group_names
    local original_directories = script_manager.available_group_directories
    local original_displayable = script_manager.available_group_displayable
    local original_script_names = script_manager.available_script_names
    local original_script_keys = script_manager.available_script_keys
    local original_script_groups = script_manager.available_script_group_paths
    local original_script_tree_groups = script_manager.available_script_tree_group_paths
    local original_script_directories = script_manager.available_script_directories
    local original_script_paths = script_manager.available_script_paths
    local temp_root = ScriptManagerIntegration.normalizeDirectoryPath ((getDir #temp) + "\\Script-Manager-PruneDirs-1.203")
    local source_path = temp_root + "Source\\"
    local nested_parent = source_path + "KeepParent\\"
    local nested_scripts = nested_parent + "Nested\\"
    local mcr_directory = source_path + "McrOnly\\"
    local mse_directory = source_path + "MseOnly\\"
    local mzp_directory = source_path + "MzpOnly\\"
    local empty_directory = source_path + "Empty\\"
    local notes_directory = source_path + "NotesOnly\\"
    local git_directory = source_path + ".git\\"
    local cache = Dictionary #string
    local found_ok = false
    local empty_ok = false
    local mzp_ok = false
    local excluded_ok = false
    local tree_ok = false
    local restored_ok = false
    local test_ok = false

    try
    (
        makeDir temp_root
        for directory_path in #(source_path, nested_parent, nested_scripts, mcr_directory, mse_directory, mzp_directory, empty_directory, notes_directory, git_directory) do makeDir directory_path
        writeScriptManagerTestScript (nested_scripts + "Nested.ms") "-- source fixture"
        writeScriptManagerTestScript (mcr_directory + "Entry.mcr") "-- macro fixture"
        writeScriptManagerTestScript (mse_directory + "Entry.mse") "-- encrypted fixture"
        writeScriptManagerTestScript (mzp_directory + "Package.mzp") "-- package fixture"
        writeScriptManagerTestScript (notes_directory + "notes.txt") "-- not a script"
        writeScriptManagerTestScript (git_directory + "Ignored.ms") "-- ignored by default"

        script_manager.root_directory = temp_root
        script_manager.source_ignore_patterns = #(".git")
        script_manager.show_versioned_files = true
        script_manager.show_clean_scripts_only = false
        script_manager.available_group_paths = #()
        script_manager.available_group_tree_paths = #()
        script_manager.available_group_names = #()
        script_manager.available_group_directories = #()
        script_manager.available_group_displayable = #()
        script_manager.available_script_names = #()
        script_manager.available_script_keys = #()
        script_manager.available_script_group_paths = #()
        script_manager.available_script_tree_group_paths = #()
        script_manager.available_script_directories = #()
        script_manager.available_script_paths = #()

        script_manager.discoverDirectory source_path source_path cache
        found_ok = (findItem script_manager.available_group_directories source_path) > 0 and \
            (findItem script_manager.available_group_directories nested_parent) > 0 and \
            (findItem script_manager.available_group_directories nested_scripts) > 0 and \
            (findItem script_manager.available_group_directories mcr_directory) > 0 and \
            (findItem script_manager.available_group_directories mse_directory) > 0
        mzp_ok = (findItem script_manager.available_group_directories mzp_directory) > 0 and \
            script_manager.scriptDirectoryHasSourceFiles mzp_directory cache
        empty_ok = (findItem script_manager.available_group_directories empty_directory) == 0 and \
            (findItem script_manager.available_group_directories notes_directory) == 0 and \
            not(script_manager.scriptDirectoryHasSourceFiles notes_directory cache)
        excluded_ok = (findItem script_manager.available_group_directories git_directory) == 0

        if script_manager.populateScriptTree restore_expansion:false then
        (
            script_tree = script_manager.getScriptTreeControl()
            tree_ok = script_tree != undefined and \
                scriptManagerTestTreeContainsText script_tree.Nodes "KeepParent" and \
                scriptManagerTestTreeContainsText script_tree.Nodes "MzpOnly" and \
                not(scriptManagerTestTreeContainsText script_tree.Nodes "Empty") and \
                not(scriptManagerTestTreeContainsText script_tree.Nodes "NotesOnly")
        )
    )
    catch
    (
        format "PART 43 ERROR | %\n" (getCurrentException())
    )

    script_manager.root_directory = original_root
    script_manager.source_ignore_patterns = original_patterns
    script_manager.show_versioned_files = original_versioned
    script_manager.show_clean_scripts_only = original_clean
    script_manager.available_group_paths = original_groups
    script_manager.available_group_tree_paths = original_tree_groups
    script_manager.available_group_names = original_names
    script_manager.available_group_directories = original_directories
    script_manager.available_group_displayable = original_displayable
    script_manager.available_script_names = original_script_names
    script_manager.available_script_keys = original_script_keys
    script_manager.available_script_group_paths = original_script_groups
    script_manager.available_script_tree_group_paths = original_script_tree_groups
    script_manager.available_script_directories = original_script_directories
    script_manager.available_script_paths = original_script_paths
    restored_ok = script_manager.populateScriptTree restore_expansion:true

    test_ok = found_ok and empty_ok and mzp_ok and excluded_ok and tree_ok and restored_ok
    if not test_ok then script_manager_test_passed = false
    format "PART 43 | nested:% | pruned:% | mzp:% | excluded:% | tree:% | restored:% | PASS:%\n" found_ok empty_ok mzp_ok excluded_ok tree_ok restored_ok test_ok
    test_ok
    -- return
)

/*
Verifies independent SHOW and IGNORE subrollouts reside inside OPTIONS.
Both sections preserve the legacy combined open state and existing filter controls.
*/
function partOfTest44 =
(
    local production_path = script_manager_test_root + "..\\Script-Manager.ms"
    local production_text = readScriptManagerTestFileText production_path
    local previous_ini = script_manager.ini_path
    local test_ini_path = (getDir #temp) + "\\Script-Manager-ShowIgnore-Test.ini"
    local controls_ok = false
    local ownership_ok = false
    local tree_ok = false
    local handlers_ok = false
    local state_ok = false
    local migration_ok = false
    local test_ok = false

    controls_ok = script_manager_show_ui != undefined and \
        script_manager_ignore_ui != undefined and \
        script_manager.getScriptIgnoreMaskControl() == script_manager_ignore_ui.edt_script_ignore and \
        isProperty script_manager_show_ui #chk_show_versions and \
        isProperty script_manager_show_ui #chk_clean_scripts and \
        isProperty script_manager_show_ui #chk_collapse_dirs and \
        not(isProperty script_manager_scripts_ui #sr_show_ignore)

    ownership_ok = script_manager_ui.sr_loader.rollouts.count == 4 and \
        script_manager_options_ui.sr_show.rollouts.count == 1 and \
        script_manager_options_ui.sr_ignore.rollouts.count == 1 and \
        script_manager_options_ui.sr_show.rollouts[1] == script_manager_show_ui and \
        script_manager_options_ui.sr_ignore.rollouts[1] == script_manager_ignore_ui

    tree_ok = script_manager_scripts_ui.tv_scripts.pos == [6,60] and \
        script_manager_scripts_ui.tv_scripts.height == 1032 and \
        script_manager_scripts_ui.btn_load_scripts.pos == [6,6]

    if production_text != undefined then
    (
        ownership_ok = ownership_ok and \
            (findString production_text "addSubRollout options_rollout.sr_show show_rollout") != undefined and \
            (findString production_text "addSubRollout options_rollout.sr_ignore ignore_rollout") != undefined and \
            (findString production_text "addSubRollout script_rollout.sr_show_ignore") == undefined
        handlers_ok = (findString production_text "on chk_show_versions changed state do") != undefined and \
            (findString production_text "on chk_clean_scripts changed state do") != undefined and \
            (findString production_text "on chk_collapse_dirs changed state do") != undefined and \
            (findString production_text "script_manager.setShowRolloutOpen state") != undefined and \
            (findString production_text "script_manager.setIgnoreRolloutOpen state") != undefined
    )

    if doesFileExist test_ini_path then deleteFile test_ini_path
    script_manager.ini_path = test_ini_path
    migration_ok = script_manager.saveShowIgnoreRolloutOpenState false and \
        not(script_manager.loadShowRolloutOpenState()) and \
        not(script_manager.loadIgnoreRolloutOpenState())
    state_ok = script_manager.saveShowRolloutOpenState true and \
        script_manager.saveIgnoreRolloutOpenState false and \
        script_manager.loadShowRolloutOpenState() and \
        not(script_manager.loadIgnoreRolloutOpenState()) and \
        script_manager.saveIgnoreRolloutOpenState true and \
        script_manager.loadIgnoreRolloutOpenState()
    script_manager.ini_path = previous_ini
    if doesFileExist test_ini_path then deleteFile test_ini_path

    test_ok = controls_ok and ownership_ok and tree_ok and handlers_ok and state_ok and migration_ok
    if not test_ok then script_manager_test_passed = false
    format "PART 44 | controls:% | options-slots:% | script-layout:% | handlers:% | independent-state:% | migration:% | PASS:%\n" controls_ok ownership_ok tree_ok handlers_ok state_ok migration_ok test_ok
    test_ok
    -- return
)

/*
Verifies live SCRIPTS filtering by filename and parent folder without discovery or INI changes.
Clearing the filter restores all leaves and the previously saved folder expansion state.
*/
function partOfTest45 =
(
    local original_ini = script_manager.ini_path
    local original_root = script_manager.root_directory
    local original_collapse = script_manager.collapse_script_dirs
    local original_filter = script_manager.script_filter_text
    local original_group_paths = script_manager.available_group_paths
    local original_group_tree_paths = script_manager.available_group_tree_paths
    local original_group_directories = script_manager.available_group_directories
    local original_group_displayable = script_manager.available_group_displayable
    local original_script_paths = script_manager.available_script_paths
    local original_script_group_paths = script_manager.available_script_group_paths
    local original_script_tree_group_paths = script_manager.available_script_tree_group_paths
    local original_script_directories = script_manager.available_script_directories
    local test_ini_path = script_manager_test_temp_root + "FilterTree_1.205.ini"
    local test_root = script_manager_test_temp_root
    local sample_directory = ScriptManagerIntegration.normalizeDirectoryPath (test_root + "Sample")
    local alpha_directory = ScriptManagerIntegration.normalizeDirectoryPath (sample_directory + "Alpha")
    local beta_directory = ScriptManagerIntegration.normalizeDirectoryPath (sample_directory + "Beta")
    local alpha_path = alpha_directory + "Alpha.ms"
    local beta_path = beta_directory + "Beta.ms"
    local other_path = beta_directory + "Other.ms"
    local control_ok = false
    local unfiltered_ok = false
    local filename_ok = false
    local folder_ok = false
    local no_match_ok = false
    local restore_ok = false
    local persisted_ok = false
    local test_ok = false

    try
    (
        if doesFileExist test_ini_path then deleteFile test_ini_path
        script_manager.ini_path = test_ini_path
        script_manager.root_directory = test_root
        script_manager.collapse_script_dirs = false
        script_manager.script_filter_text = ""

        script_manager.available_group_paths = #("Sample", "Sample\\Alpha", "Sample\\Beta")
        script_manager.available_group_tree_paths = #("Sample", "Sample\\Alpha", "Sample\\Beta")
        script_manager.available_group_directories = #(sample_directory, alpha_directory, beta_directory)
        script_manager.available_group_displayable = #(true, true, true)
        script_manager.available_script_paths = #(alpha_path, beta_path, other_path)
        script_manager.available_script_group_paths = #("Sample\\Alpha", "Sample\\Beta", "Sample\\Beta")
        script_manager.available_script_tree_group_paths = #("Sample\\Alpha", "Sample\\Beta", "Sample\\Beta")
        script_manager.available_script_directories = #(alpha_directory, beta_directory, beta_directory)

        script_manager.saveScriptLoadMode (script_manager.getScriptKey alpha_path) #host
        setINISetting test_ini_path "ScriptTreeOpen" "Sample" "0" forceUTF16:false
        control_ok = script_manager_scripts_ui != undefined and isProperty script_manager_scripts_ui #edt_scripts_filter

        unfiltered_ok = script_manager.populateScriptTree restore_expansion:true and script_manager.script_tree_file_count == 3
        filename_ok = script_manager.handleScriptTreeFilterChanged "aLpHa" and \
            script_manager.script_tree_file_count == 1 and \
            scriptManagerTestTreeContainsText script_manager_scripts_ui.tv_scripts.Nodes "Alpha.ms" and \
            not(scriptManagerTestTreeContainsText script_manager_scripts_ui.tv_scripts.Nodes "Beta.ms") and \
            script_manager_scripts_ui.tv_scripts.Nodes.Item[0].IsExpanded

        folder_ok = script_manager.handleScriptTreeFilterChanged "beta" and \
            script_manager.script_tree_file_count == 2 and \
            scriptManagerTestTreeContainsText script_manager_scripts_ui.tv_scripts.Nodes "Beta.ms" and \
            scriptManagerTestTreeContainsText script_manager_scripts_ui.tv_scripts.Nodes "Other.ms" and \
            not(scriptManagerTestTreeContainsText script_manager_scripts_ui.tv_scripts.Nodes "Alpha.ms")

        no_match_ok = script_manager.handleScriptTreeFilterChanged "no-matching-script" and \
            script_manager.script_tree_file_count == 0 and script_manager_scripts_ui.tv_scripts.Nodes.Count == 0

        restore_ok = script_manager.handleScriptTreeFilterChanged "" and \
            script_manager.script_tree_file_count == 3 and \
            scriptManagerTestTreeContainsText script_manager_scripts_ui.tv_scripts.Nodes "Alpha.ms" and \
            scriptManagerTestTreeContainsText script_manager_scripts_ui.tv_scripts.Nodes "Beta.ms" and \
            scriptManagerTestTreeContainsText script_manager_scripts_ui.tv_scripts.Nodes "Other.ms" and \
            not(script_manager_scripts_ui.tv_scripts.Nodes.Item[0].IsExpanded)

        persisted_ok = (getINISetting test_ini_path "ScriptTreeOpen" "Sample") == "0" and \
            script_manager.getScriptLoadMode (script_manager.getScriptKey alpha_path) == #host and \
            script_manager.available_script_paths.count == 3 and \
            not(hasINISetting test_ini_path "Filter" "ScriptTreeFilter")
    )
    catch
    (
        format "PART 45 ERROR | %\n" (getCurrentException())
    )

    script_manager.ini_path = original_ini
    script_manager.root_directory = original_root
    script_manager.collapse_script_dirs = original_collapse
    script_manager.available_group_paths = original_group_paths
    script_manager.available_group_tree_paths = original_group_tree_paths
    script_manager.available_group_directories = original_group_directories
    script_manager.available_group_displayable = original_group_displayable
    script_manager.available_script_paths = original_script_paths
    script_manager.available_script_group_paths = original_script_group_paths
    script_manager.available_script_tree_group_paths = original_script_tree_group_paths
    script_manager.available_script_directories = original_script_directories
    script_manager.script_filter_text = original_filter
    if doesFileExist test_ini_path then deleteFile test_ini_path
    script_manager.populateScriptTree restore_expansion:true

    test_ok = control_ok and unfiltered_ok and filename_ok and folder_ok and no_match_ok and restore_ok and persisted_ok
    if not test_ok then script_manager_test_passed = false
    format "PART 45 | control:% | unfiltered:% | filename:% | folder:% | no-match:% | cleared:% | persisted:% | PASS:%\n" control_ok unfiltered_ok filename_ok folder_ok no_match_ok restore_ok persisted_ok test_ok
    test_ok
    -- return
)

/*
Verifies isolated per-script startup launchers, collision protection and safe removal.
Also checks the visible right-click toggle and manual-load failure-message wiring.
*/
function partOfTest46 =
(
    test_directory = ScriptManagerIntegration.normalizeDirectoryPath ((getDir #temp) + "\\Script-Manager-Startup-Test-1.211")
    script_a = test_directory + "A\\Startup-Sample.ms"
    script_b = test_directory + "B\\Startup-Sample.ms"
    launcher_a = ""
    launcher_b = ""
    original_text = "-- SCRIPT_MANAGER_TEST_SOURCE_CONTENT"
    startup_ok = false
    collision_ok = false
    foreign_ok = false
    removal_ok = false
    source_intact_ok = false
    menu_ok = false
    error_dialog_ok = false
    test_ok = false

    try
    (
        makeDir (test_directory + "A\\")
        makeDir (test_directory + "B\\")
        writeScriptManagerTestScript script_a original_text
        writeScriptManagerTestScript script_b original_text

        launcher_a = script_manager.getScriptStartupLauncherPath script_a startup_directory:test_directory
        launcher_b = script_manager.getScriptStartupLauncherPath script_b startup_directory:test_directory
        collision_ok = launcher_a != "" and launcher_b != "" and launcher_a != launcher_b

        startup_ok = collision_ok and \
            script_manager.addScriptToStartup script_a startup_directory:test_directory and \
            script_manager.isScriptInStartup script_a startup_directory:test_directory and \
            not(script_manager.isScriptInStartup script_b startup_directory:test_directory)

        if startup_ok then
        (
            startup_text = readScriptManagerTestFileText launcher_a
            startup_ok = startup_text != undefined and \
                (findString startup_text "fileIn script_path quiet:true") != undefined and \
                (findString startup_text script_a) != undefined
        )

        source_intact_ok = (readScriptManagerTestFileText script_a) == (original_text + "\n")
        removal_ok = script_manager.removeScriptFromStartup script_a startup_directory:test_directory and \
            not(doesFileExist launcher_a) and \
            not(script_manager.isScriptInStartup script_a startup_directory:test_directory)

        if collision_ok then
        (
            writeScriptManagerTestScript launcher_b "-- foreign startup file: do not change"
            foreign_ok = not(script_manager.isScriptInStartup script_b startup_directory:test_directory) and \
                not(script_manager.addScriptToStartup script_b startup_directory:test_directory) and \
                not(script_manager.removeScriptFromStartup script_b startup_directory:test_directory) and \
                (readScriptManagerTestFileText launcher_b) == "-- foreign startup file: do not change\n"
        )

        source_path = script_manager_test_root + "..\\Script-Manager.ms"
        production_text = readScriptManagerTestFileText source_path
        if production_text != undefined then
        (
            menu_ok = (findString production_text "ADD TO STARTUP SCRIPTS") != undefined and \
                (findString production_text "REMOVE FROM STARTUP SCRIPTS") != undefined and \
                (findString production_text "scriptManagerTreeStartupContextHandler") != undefined
            error_dialog_ok = (findString production_text "function showTreeLoadFailure") != undefined and \
                (findString production_text "[TREE LOAD] FAILED") != undefined and \
                (findString production_text "this.showTreeLoadFailure action_name script_path last_tree_load_error") != undefined
        )
    )
    catch
    (
        format "PART 46 ERROR | %\n" (getCurrentException())
    )

    for temp_path in #(launcher_a, launcher_b, script_a, script_b) do
    (
        if temp_path != "" and doesFileExist temp_path then deleteFile temp_path
    )

    test_ok = startup_ok and collision_ok and foreign_ok and removal_ok and source_intact_ok and menu_ok and error_dialog_ok
    if not test_ok then script_manager_test_passed = false
    format "PART 46 | add:% | unique:% | foreign-safe:% | remove:% | source-unchanged:% | menu:% | failure-dialog:% | PASS:%\n" \
        startup_ok collision_ok foreign_ok removal_ok source_intact_ok menu_ok error_dialog_ok test_ok
    test_ok
    -- return
)

/*
Verifies that manual TreeView loads rethrow the original exception after printing its source and stack.
Also checks mode restoration and busy-state cleanup without showing a modal error in this isolated test.
*/
function partOfTest47 =
(
    test_path = script_manager_test_temp_root + "SourceA\\ScriptManager-Native-Exception-Test.ms"
    marker_text = "SCRIPT_MANAGER_NATIVE_EXCEPTION_TEST_47"
    source_path = script_manager_test_root + "..\\Script-Manager.ms"
    source_text = readScriptManagerTestFileText source_path
    propagation_wired = false
    integration_threw = false
    manager_threw = false
    ui_threw = false
    modes_restored = false
    reset_ok = false
    test_ok = false

    if source_text != undefined then
    (
        propagation_wired = (findString source_text "function loadScript script_path runtime_mode:#library quiet:true rethrow_exception:false") != undefined and \
            (findString source_text "getCurrentExceptionStackTrace()") != undefined and \
            (findString source_text "getErrorSourceFileName()") != undefined and \
            (findString source_text "getErrorSourceFileLine()") != undefined and \
            (findString source_text "this.loadSingleScriptForcedDirect script_path rethrow_exception:true") != undefined and \
            (findString source_text "[Script-Manager][TREE LOAD] NATIVE EXCEPTION") != undefined
    )

    try
    (
        write_ok = writeScriptManagerTestScript test_path ("throw \"" + marker_text + "\"")
        old_script_mode = SCRIPT_MANAGER_RUNTIME_MODE
        old_epoly_mode = EPOLY_TOOLS_RUNTIME_MODE

        if write_ok then
        (
            try
            (
                ScriptManagerIntegration.loadScript test_path runtime_mode:#standalone quiet:true rethrow_exception:true
            )
            catch
            (
                exception_text = getCurrentException() as string
                integration_threw = (findString exception_text marker_text) != undefined
            )

            modes_restored = SCRIPT_MANAGER_RUNTIME_MODE == old_script_mode and EPOLY_TOOLS_RUNTIME_MODE == old_epoly_mode

            try
            (
                script_manager.loadSingleScriptForcedDirect test_path rethrow_exception:true
            )
            catch
            (
                exception_text = getCurrentException() as string
                manager_threw = (findString exception_text marker_text) != undefined
            )

            tree_control = script_manager.getScriptTreeControl()
            if tree_control != undefined then
            (
                previous_node = tree_control.SelectedNode
                failure_node = dotNetObject "System.Windows.Forms.TreeNode" "ScriptManager-Native-Exception-Test.ms"
                failure_node.ToolTipText = test_path
                tree_control.SelectedNode = failure_node

                try
                (
                    script_manager.loadSelectedScriptTreeItem action_name:"TEST EXCEPTION" show_error_dialog:false
                )
                catch
                (
                    exception_text = getCurrentException() as string
                    ui_threw = (findString exception_text marker_text) != undefined
                )
                tree_control.SelectedNode = previous_node
            )

            reset_ok = not(script_manager.is_reloading) and (findString script_manager.last_tree_load_error marker_text) != undefined
        )
    )
    catch
    (
        format "PART 47 ERROR | %\n" (getCurrentException())
    )

    if doesFileExist test_path then deleteFile test_path
    test_ok = propagation_wired and integration_threw and manager_threw and ui_threw and modes_restored and reset_ok
    if not test_ok then script_manager_test_passed = false
    format "PART 47 | wired:% | integration-throws:% | manager-throws:% | ui-throws:% | modes-restored:% | busy-reset:% | PASS:%\n" \
        propagation_wired integration_threw manager_threw ui_threw modes_restored reset_ok test_ok
    test_ok
    -- return
)

/*
Verifies CLEAN SCRIPTS tri-state persistence, strict matching, unclear-folder fallback,
and the 0 -> 1 -> 2 -> 0 checkbox cycle without executing any discovered script.
*/
function partOfTest48 =
(
    previous_ini = script_manager.ini_path
    previous_clean = script_manager.show_clean_scripts_only
    previous_unclear = script_manager.show_unclear_scripts
    previous_versioned = script_manager.show_versioned_files
    previous_ui_state = if script_manager_show_ui != undefined then script_manager_show_ui.chk_clean_scripts.triState else 0
    test_ini = (getDir #temp) + "\\Script-Manager-Clean-Tristate-Test.ini"
    test_root = script_manager_test_temp_root + "Clean-Tristate-Test\\"
    matched_dir = test_root + "MatchingTool\\"
    unmatched_dir = test_root + "UnclearTool\\"
    versioned_dir = test_root + "VersionOnly\\"
    source_text = readScriptManagerTestFileText (script_manager_test_root + "..\\Script-Manager.ms")
    setup_ok = false
    strict_ok = false
    mixed_ok = false
    off_ok = false
    old_ini_ok = false
    third_ini_ok = false
    cycle_ok = false
    ui_ok = false
    test_ok = false

    try
    (
        makeDir matched_dir
        makeDir unmatched_dir
        makeDir versioned_dir
        setup_ok = \
            (writeScriptManagerTestScript (matched_dir + "matchingtool.ms") "true") and \
            (writeScriptManagerTestScript (matched_dir + "Helper.ms") "true") and \
            (writeScriptManagerTestScript (unmatched_dir + "Utility.ms") "true") and \
            (writeScriptManagerTestScript (unmatched_dir + "Another.ms") "true") and \
            (writeScriptManagerTestScript (versioned_dir + "Only_0.01.ms") "true") and \
            (writeScriptManagerTestScript (versioned_dir + "Only_0.03.ms") "true")

        if doesFileExist test_ini then deleteFile test_ini
        script_manager.ini_path = test_ini
        script_manager.show_versioned_files = true

        if setup_ok then
        (
            script_manager.saveCleanScriptsMode 0
            all_matched = script_manager.getScriptFilesInDirectory matched_dir
            all_unclear = script_manager.getScriptFilesInDirectory unmatched_dir
            off_ok = (all_matched.count == 2 and all_unclear.count == 2 and script_manager.getCleanScriptsMode() == 0)

            script_manager.saveCleanScriptsMode 1
            strict_matched = script_manager.getScriptFilesInDirectory matched_dir
            strict_unclear = script_manager.getScriptFilesInDirectory unmatched_dir
            strict_versioned = script_manager.getScriptFilesInDirectory versioned_dir
            strict_ok = strict_matched.count == 1 and strict_matched[1] == (matched_dir + "matchingtool.ms") and strict_unclear.count == 0 and strict_versioned.count == 0

            script_manager.show_versioned_files = false
            script_manager.saveCleanScriptsMode 2
            mixed_matched = script_manager.getScriptFilesInDirectory matched_dir
            mixed_unclear = script_manager.getScriptFilesInDirectory unmatched_dir
            mixed_versioned = script_manager.getScriptFilesInDirectory versioned_dir
            mixed_ok = mixed_matched.count == 1 and mixed_matched[1] == (matched_dir + "matchingtool.ms") and \
                (findItem mixed_unclear (unmatched_dir + "Utility.ms")) > 0 and \
                (findItem mixed_unclear (unmatched_dir + "Another.ms")) > 0 and mixed_unclear.count == 2 and \
                mixed_versioned.count == 2
            third_ini_ok = (getINISetting test_ini "Filter" "CleanScriptsOnly") == "2" and \
                script_manager.loadShowCleanScriptsOnly() and script_manager.getCleanScriptsMode() == 2

            setINISetting test_ini "Filter" "CleanScriptsOnly" "1" forceUTF16:false
            old_one_ok = script_manager.loadShowCleanScriptsOnly() and script_manager.getCleanScriptsMode() == 1
            setINISetting test_ini "Filter" "CleanScriptsOnly" "0" forceUTF16:false
            old_zero_ok = not(script_manager.loadShowCleanScriptsOnly()) and script_manager.getCleanScriptsMode() == 0
            old_ini_ok = old_one_ok and old_zero_ok
            cycle_ok = ((script_manager.getNextCleanScriptsMode 0) == 1) and \
                ((script_manager.getNextCleanScriptsMode 1) == 2) and \
                ((script_manager.getNextCleanScriptsMode 2) == 0)
        )

        ui_ok = source_text != undefined and \
            (findString source_text "checkbox chk_clean_scripts \\\"CLEAN SCRIPTS\\\"") != undefined and \
            (findString source_text "triState:") != undefined and \
            (findString source_text "handleShowCleanScriptsChanged state") != undefined and \
            (findString source_text "script_manager_show_ui.chk_clean_scripts.triState = next_mode") != undefined and \
            script_manager_show_ui != undefined and previous_ui_state >= 0 and previous_ui_state <= 2
    )
    catch
    (
        format "PART 48 ERROR | %\n" (getCurrentException())
    )

    script_manager.ini_path = previous_ini
    script_manager.show_clean_scripts_only = previous_clean
    script_manager.show_unclear_scripts = previous_unclear
    script_manager.show_versioned_files = previous_versioned
    if script_manager_show_ui != undefined then script_manager_show_ui.chk_clean_scripts.triState = previous_ui_state
    if doesFileExist test_ini then deleteFile test_ini

    test_ok = setup_ok and off_ok and strict_ok and mixed_ok and third_ini_ok and old_ini_ok and cycle_ok and ui_ok
    if not test_ok then script_manager_test_passed = false
    format "PART 48 | setup:% | off:% | strict:% | mixed:% | ini-2:% | legacy-0/1:% | cycle:% | ui:% | PASS:%\n" setup_ok off_ok strict_ok mixed_ok third_ini_ok old_ini_ok cycle_ok ui_ok test_ok
    test_ok
    -- return
)

partOfTest1()
partOfTest2()
partOfTest3()
partOfTest4()
partOfTest5()
partOfTest6()
partOfTest7()
partOfTest8()
partOfTest9()
partOfTest10()
partOfTest11()
partOfTest12()
partOfTest13()
partOfTest14()
partOfTest15()
partOfTest16()
partOfTest17()
partOfTest18()
partOfTest19()
partOfTest20()
partOfTest23()
partOfTest24()
partOfTest25()
partOfTest26()
partOfTest27()
partOfTest28()
partOfTest29()
partOfTest30()
partOfTest31()
partOfTest32()
partOfTest33()
partOfTest34()
partOfTest35()
partOfTest36()
partOfTest37()
partOfTest38()
partOfTest39()
partOfTest40()
partOfTest41()
partOfTest42()
partOfTest43()
partOfTest44()
partOfTest45()
partOfTest46()
partOfTest47()
partOfTest48()
partOfTest21()
partOfTest22()

format "============================================================\n"
format "SCRIPT-MANAGER TEST RESULT | PASS:%\n" script_manager_test_passed
format "============================================================\n"

