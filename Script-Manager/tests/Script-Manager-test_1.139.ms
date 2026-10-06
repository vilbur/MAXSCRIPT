/*
    Script-Manager regression test 1.139.
    Tests production version identity, source selection, filters, persistent tri-state load modes, marked-item color, tree menus, and dedicated script-load behavior.
*/

global script_manager_test_file_version = 1.139
global script_manager_test_project_version = 1.140
global script_manager_test_root = getFilenamePath (getSourceFileName())
global script_manager_test_passed = true
global script_manager_test_original_root
global script_manager_test_original_ini
global script_manager_test_temp_root
global script_manager_test_marker_a
global script_manager_test_marker_b
global script_manager_test_marker_c
global script_manager_test_marker_d
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

    version_ok = script_manager.file_version == 1.140 and script_manager.project_version == 1.140 and ScriptManagerIntegration.file_version == 1.140 and ScriptManagerIntegration.project_version == 1.140
    global_version_ok = script_manager_project_version == 1.140
    title_ok = script_manager_ui.title == "Script-Manager 1.140"
    main_action_ok = isProperty script_manager_ui #btn_refresh_restart
    source_rollout_ok = script_manager_sources_ui != undefined and script_manager_sources_ui.title == "SOURCES" and isProperty script_manager_sources_ui #tv_sources and not(isProperty script_manager_sources_ui #btn_reload)
    script_rollout_ok = script_manager_scripts_ui != undefined and script_manager_scripts_ui.title == "SCRIPTS" and isProperty script_manager_scripts_ui #btn_load_scripts
    soft_hard_api_ok = isProperty script_manager #updateScripts and isProperty script_manager #loadScripts and isProperty script_manager #isManagedScriptRunning and isProperty script_manager #loadSingleScriptForcedDirect
    source_tree_ok = script_manager.getSourceTreeControl() != undefined
    script_tree_ok = script_manager.getScriptTreeControl() != undefined
    source_height_ok = source_tree_ok and script_manager_sources_ui.tv_sources.height >= 512
    source_mixed_ui_ok = source_tree_ok and not(script_manager_sources_ui.tv_sources.CheckBoxes) and script_manager_sources_ui.tv_sources.ImageList != undefined and script_manager_sources_ui.tv_sources.ImageList.Images.Count >= 2
    tristate_ui_ok = script_tree_ok and not(script_manager_scripts_ui.tv_scripts.CheckBoxes) and script_manager_scripts_ui.tv_scripts.ImageList != undefined and script_manager_scripts_ui.tv_scripts.ImageList.Images.Count >= 3
    loader_only_ok = not(isProperty script_manager_ui #sr_tools)
    host_model_ok = isProperty script_manager #host_dialogs and isProperty script_manager #host_dialog_paths and isProperty script_manager #loaded_host_script_paths and isProperty script_manager #loaded_host_script_dialog_paths
    clean_filter_ok = script_manager_scripts_ui != undefined and isProperty script_manager_scripts_ui #chk_clean_scripts
    preset_ui_ok = script_manager_scripts_ui != undefined and isProperty script_manager_scripts_ui #ddl_presets and isProperty script_manager_scripts_ui #btn_preset_save_remove
    preset_neutral_ok = preset_ui_ok and script_manager_scripts_ui.ddl_presets.items.count >= 1 and script_manager_scripts_ui.ddl_presets.items[1] == "<Preset>" and script_manager_scripts_ui.ddl_presets.selection == 1
    preset_api_ok = isProperty script_manager #savePreset and isProperty script_manager #loadPreset and isProperty script_manager #removePreset and isProperty script_manager #getPresetNames and isProperty script_manager #refreshPresetDropdown
    rollout_state_ok = isProperty script_manager #source_rollout_open and isProperty script_manager #script_rollout_open
    context_menu_ok = script_manager.source_tree_context_menu != undefined and script_manager.script_tree_load_item != undefined and script_manager.script_tree_expand_all_item != undefined and script_manager.script_tree_collapse_all_item != undefined

    test_ok = version_ok and global_version_ok and title_ok and main_action_ok and source_rollout_ok and script_rollout_ok and soft_hard_api_ok and source_tree_ok and script_tree_ok and source_height_ok and source_mixed_ui_ok and tristate_ui_ok and loader_only_ok and host_model_ok and clean_filter_ok and preset_ui_ok and preset_neutral_ok and preset_api_ok and rollout_state_ok and context_menu_ok
    if not test_ok then script_manager_test_passed = false

    format "PART 1 | version:% | global:% | title:% | main-action:% | source-rollout:% | script-rollout:% | soft-hard:% | sources:% | scripts:% | source-512:% | source-mixed-ui:% | tristate-ui:% | loader-only:% | host-model:% | clean-filter:% | preset-ui:% | preset-neutral:% | preset-api:% | rollout-state:% | tree-menu:% | PASS:%\n" version_ok global_version_ok title_ok main_action_ok source_rollout_ok script_rollout_ok soft_hard_api_ok source_tree_ok script_tree_ok source_height_ok source_mixed_ui_ok tristate_ui_ok loader_only_ok host_model_ok clean_filter_ok preset_ui_ok preset_neutral_ok preset_api_ok rollout_state_ok context_menu_ok test_ok
    test_ok
    -- return
)

/*
Builds an isolated temporary source tree and switches the manager to a temporary INI so user settings are untouched.
*/
function partOfTest2 =
(
    script_manager_test_temp_root = ScriptManagerIntegration.normalizeDirectoryPath ((getDir #temp) + "\\Script-Manager-Test-Root")
    source_a = script_manager_test_temp_root + "SourceA\\"
    source_a_category = source_a + "Category\\"
    source_a_leaf = source_a + "ToolLeaf\\"
    source_a_nested_leaf = source_a_category + "ToolNested\\"
    source_b = script_manager_test_temp_root + "SourceB\\"

    makeDir script_manager_test_temp_root
    makeDir source_a
    makeDir source_a_category
    makeDir source_a_leaf
    makeDir source_a_nested_leaf
    makeDir source_b

    writeScriptManagerTestScript (source_a_leaf + "ToolLeaf.ms") "global script_manager_test_source_leaf; script_manager_test_source_leaf = true"
    writeScriptManagerTestScript (source_a_nested_leaf + "ToolNested.ms") "global script_manager_test_source_nested_leaf; script_manager_test_source_nested_leaf = true"
    writeScriptManagerTestScript (source_b + "SourceB.ms") "global script_manager_test_source_b; script_manager_test_source_b = true"

    test_ini = (getDir #temp) + "\\Script-Manager-Test.ini"
    if doesFileExist test_ini then deleteFile test_ini

    script_manager.root_directory = script_manager_test_temp_root
    script_manager.ini_path = test_ini
    script_manager.show_versioned_files = false

    migration_seed_ok = script_manager.saveSourceEnabled source_a_nested_leaf true
    source_ok = script_manager.discoverSources()
    source_a_index = findItem script_manager.available_source_directories source_a
    category_index = findItem script_manager.available_source_directories source_a_category
    root_leaf_index = findItem script_manager.available_source_directories source_b
    tool_leaf_index = findItem script_manager.available_source_directories source_a_leaf
    nested_tool_leaf_index = findItem script_manager.available_source_directories source_a_nested_leaf

    source_a_visible = source_a_index > 0 and script_manager.available_source_selectable[source_a_index]
    category_visible = category_index > 0 and script_manager.available_source_selectable[category_index]
    root_leaf_visible = root_leaf_index > 0 and script_manager.available_source_selectable[root_leaf_index]
    tool_leaf_display_ok = tool_leaf_index > 0 and not(script_manager.available_source_selectable[tool_leaf_index]) and script_manager.available_source_names[tool_leaf_index] == "ToolLeaf"
    nested_tool_leaf_display_ok = nested_tool_leaf_index > 0 and not(script_manager.available_source_selectable[nested_tool_leaf_index]) and script_manager.available_source_names[nested_tool_leaf_index] == "ToolNested"
    migration_ok = migration_seed_ok and script_manager.getSourceEnabled source_a_category and not(script_manager.getSourceEnabled source_a_nested_leaf)

    populate_ok = script_manager.populateSourceTree()
    source_tree = script_manager.getSourceTreeControl()
    source_a_node = undefined
    category_node = undefined
    tool_leaf_node = undefined
    nested_tool_leaf_node = undefined

    if source_tree != undefined then
    (
        for root_index = 0 to (source_tree.Nodes.Count - 1) while source_a_node == undefined do
        (
            candidate_node = source_tree.Nodes.Item[root_index]
            if candidate_node.Text == "SourceA" then source_a_node = candidate_node
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
        for child_index = 0 to (category_node.Nodes.Count - 1) while nested_tool_leaf_node == undefined do
        (
            candidate_node = category_node.Nodes.Item[child_index]
            if candidate_node.Text == "ToolNested" then nested_tool_leaf_node = candidate_node
        )
    )

    source_row_visual_ok =         source_a_node != undefined and source_a_node.Name == "SOURCE_SELECTABLE" and source_a_node.ImageIndex >= 0 and         category_node != undefined and category_node.Name == "SOURCE_SELECTABLE" and category_node.ImageIndex >= 0 and         tool_leaf_node != undefined and tool_leaf_node.Name == "SOURCE_TOOL" and tool_leaf_node.ImageIndex == -1 and         nested_tool_leaf_node != undefined and nested_tool_leaf_node.Name == "SOURCE_TOOL" and nested_tool_leaf_node.ImageIndex == -1

    test_ok = source_ok and source_a_visible and category_visible and root_leaf_visible and tool_leaf_display_ok and nested_tool_leaf_display_ok and migration_ok and populate_ok and source_row_visual_ok
    if not test_ok then script_manager_test_passed = false

    format "PART 2 | source-A:% | category:% | root-leaf:% | tool-leaf:% | nested-tool-leaf:% | migrate:% | row-visual:% | PASS:%\n" source_a_visible category_visible root_leaf_visible tool_leaf_display_ok nested_tool_leaf_display_ok migration_ok source_row_visual_ok test_ok
    test_ok
    -- return
)

/*
Verifies source selections are persisted and only checked sources participate in discovery.
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

    test_ok = save_a_ok and save_b_ok and persisted_ok and write_a_ok and write_b_ok and discover_ok and source_a_found and source_b_hidden and root_group_kept_ok and leaf_flatten_ok and nested_flatten_ok
    if not test_ok then script_manager_test_passed = false

    format "PART 3 | persisted:% | A:% | B-hidden:% | root-kept:% | leaf-flat:% | nested-flat:% | PASS:%\n" persisted_ok source_a_found source_b_hidden root_group_kept_ok leaf_flatten_ok nested_flatten_ok test_ok
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

    script_manager.show_versioned_files = false
    visible_files = script_manager.getScriptFilesInDirectory source_a

    canonical_ok = (findItem visible_files (source_a + "Tool.ms")) > 0
    old_tool_hidden = (findItem visible_files (source_a + "Tool_0.01.ms")) == 0 and (findItem visible_files (source_a + "Tool_0.02.ms")) == 0
    newest_only_ok = (findItem visible_files (source_a + "Only_0.03.ms")) > 0 and (findItem visible_files (source_a + "Only_0.01.ms")) == 0

    test_ok = canonical_ok and old_tool_hidden and newest_only_ok
    if not test_ok then script_manager_test_passed = false

    format "PART 4 | canonical:% | old-hidden:% | newest:% | PASS:%\n" canonical_ok old_tool_hidden newest_only_ok test_ok
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
        (findItem visible_files (source_a + "Only_0.03.ms")) > 0

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
Verifies tri-state script modes persist and active script states keep the marked-item color.
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
    marked_color_ok = color_apply_ok and color_node.ForeColor.R == 62 and color_node.ForeColor.G == 158 and color_node.ForeColor.B == 255

    visual_node = dotNetObject "System.Windows.Forms.TreeNode" "Visual.ms"
    visual_host_ok = script_manager.applyScriptTreeNodeMode visual_node #host and visual_node.StateImageIndex == 1 and visual_node.ImageIndex == 1
    visual_direct_ok = script_manager.applyScriptTreeNodeMode visual_node #direct and visual_node.StateImageIndex == 2 and visual_node.ImageIndex == 2
    visual_skip_ok = script_manager.applyScriptTreeNodeMode visual_node #skip and visual_node.StateImageIndex == 0 and visual_node.ImageIndex == 0
    visible_tristate_ok = visual_host_ok and visual_direct_ok and visual_skip_ok

    test_ok = save_a_ok and save_b_ok and save_c_ok and save_d_ok and persisted_ok and marked_color_ok and visible_tristate_ok
    if not test_ok then script_manager_test_passed = false

    format "PART 6 | host:% | skip:% | direct:% | runtime-host:% | marked-color:% | visible-tristate:% | PASS:%\n" (script_manager.getScriptLoadMode key_a) (script_manager.getScriptLoadMode key_b) (script_manager.getScriptLoadMode key_c) (script_manager.getScriptLoadMode key_d) marked_color_ok visible_tristate_ok test_ok
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

    test_ok = mapping_ok and title_ok and create_ok and slot_ok and host_caption_ok and title_button_ok and title_button_style_ok and save_ok and persisted_ok and destroy_ok and removed_ok
    if not test_ok then script_manager_test_passed = false

    format "PART 9 | mapping:% | title:% | create:% | slot:% | host-caption:% | title-button:% | title-style:% | persisted:% | destroy:% | removed:% | PASS:%\n" mapping_ok title_ok create_ok slot_ok host_caption_ok title_button_ok title_button_style_ok persisted_ok destroy_ok removed_ok test_ok
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

    folder_node = dotNetObject "System.Windows.Forms.TreeNode" "Folder"
    folder_node.ToolTipText = source_a
    folder_node.Nodes.Add "Child"
    script_manager_scripts_ui.tv_scripts.SelectedNode = folder_node
    folder_menu_ok = script_manager.updateScriptTreeContextMenuState() and not(script_manager.script_tree_load_item.Visible) and script_manager.script_tree_expand_item.Visible

    test_ok = write_ok and mode_ok and tracked_before and script_menu_ok and first_load_ok and first_direct_ok and first_not_hosted and second_load_ok and forced_twice_ok and second_not_hosted and mode_unchanged_ok and folder_menu_ok
    if not test_ok then script_manager_test_passed = false

    format "PART 10 | write:% | host-mode:% | menu:% | first-direct:% | first-no-host:% | second-forced:% | second-no-host:% | mode-unchanged:% | folder-menu:% | PASS:%\n" write_ok mode_ok script_menu_ok first_direct_ok first_not_hosted forced_twice_ok second_not_hosted mode_unchanged_ok folder_menu_ok test_ok
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
Restores production manager paths/settings and removes isolated test files.
*/
function partOfTest12 =
(
    cleanup_ok = script_manager.clearLoadedRollouts()
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
        for test_file in (getFiles (script_manager_test_temp_root + "SourceB\\*.ms")) do deleteFile test_file
        for test_file in (getFiles (script_manager_test_temp_root + "SourceA\\ToolLeaf\\*.ms")) do deleteFile test_file
        for test_file in (getFiles (script_manager_test_temp_root + "SourceA\\Category\\ToolNested\\*.ms")) do deleteFile test_file
    )

    test_ini = (getDir #temp) + "\\Script-Manager-Test.ini"
    if doesFileExist test_ini then deleteFile test_ini

    test_ok = restore_ok
    if not test_ok then script_manager_test_passed = false

    format "PART 12 | restore:% | PASS:%\n" restore_ok test_ok
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

format "============================================================\n"
format "SCRIPT-MANAGER TEST RESULT | PASS:%\n" script_manager_test_passed
format "============================================================\n"
