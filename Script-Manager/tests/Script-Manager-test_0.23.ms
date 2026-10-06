/*
    Script-Manager regression test 0.23.
    Tests generic discovery, explicit execution, rollout hosting, runtime restoration, compatibility aliases, and reload safety.
*/

global script_manager_test_file_version = 0.23
global script_manager_test_project_version = 1.119
global script_manager_test_root = getFilenamePath (getSourceFileName())
global script_manager_test_passed = true
global script_manager_test_marker
global script_manager_test_runtime_marker
global script_manager_test_rollout

/*
Loads Script-Manager standalone and verifies the generic managed-root contract without auto-loading scripts.
*/
function partOfTest1 =
(
    manager_path = script_manager_test_root + "Script-Manager.ms"
    SCRIPT_MANAGER_RUNTIME_MODE = #standalone
    fileIn manager_path quiet:true

    source_directory = ScriptManagerIntegration.normalizeDirectoryPath script_manager_test_root
    source_directory_no_slash = substring source_directory 1 (source_directory.count - 1)
    expected_root = ScriptManagerIntegration.normalizeDirectoryPath (pathConfig.removePathLeaf source_directory_no_slash)

    dialog_ok = false
    loader_count = 0

    try
    (
        dialog_ok = script_manager_ui.dialogBar
        loader_count = script_manager_ui.sr_loader.rollouts.count
    )
    catch
    (
        exception_text = getCurrentException()
        dialog_ok = false
        loader_count = 0
    )

    root_ok = script_manager.root_directory == expected_root
    expected_title = "Script-Manager " + (script_manager_project_version as string)
    expected_version_label = "Script Manager  " + (script_manager_project_version as string)
    title_ok = script_manager_ui.title == expected_title
    version_label_ok = script_manager_ui.lbl_version.text == expected_version_label
    empty_load_ok = script_manager.loaded_script_paths.count == 0 and script_manager.loaded_rollouts.count == 0
    integration_ok = ScriptManagerIntegration != undefined and EPolyToolsIntegration != undefined
    test_ok = dialog_ok and loader_count == 1 and root_ok and title_ok and version_label_ok and empty_load_ok and integration_ok

    if not test_ok then script_manager_test_passed = false
    format "PART 1 | root:% | title:% | version-label:% | empty-load:% | integration:% | PASS:%\n" root_ok title_ok version_label_ok empty_load_ok integration_ok test_ok

    test_ok
    -- return
)

/*
Verifies generic discovery accepts all supported script extensions and excludes the Script-Manager package itself.
*/
function partOfTest2 =
(
    discovery_ok = script_manager.discoverScripts()
    extensions_ok = true
    manager_excluded = true
    manager_directory = ScriptManagerIntegration.normalizeDirectoryPath script_manager_test_root

    for script_path in script_manager.available_script_paths do
    (
        if not(script_manager.isSupportedScriptPath script_path) then extensions_ok = false
        if ScriptManagerIntegration.isFilePathUnderDirectory script_path manager_directory then manager_excluded = false
    )

    test_ok = discovery_ok and script_manager.available_script_paths.count > 0 and extensions_ok and manager_excluded
    if not test_ok then script_manager_test_passed = false

    format "PART 2 | scripts:% | supported:% | manager-excluded:% | PASS:%\n" script_manager.available_script_paths.count extensions_ok manager_excluded test_ok
    test_ok
    -- return
)

/*
Verifies loadScript executes a normal no-rollout script and restores both runtime-mode globals afterward.
*/
function partOfTest3 =
(
    temp_path = (getDir #temp) + "\\Script-Manager-No-Rollout-Test.ms"
    file_stream = createFile temp_path
    format "global script_manager_test_marker\nscript_manager_test_marker = 12345\n" to:file_stream
    close file_stream

    script_manager_test_marker = 0
    SCRIPT_MANAGER_RUNTIME_MODE = #standalone
    EPOLY_TOOLS_RUNTIME_MODE = #standalone

    result_data = ScriptManagerIntegration.loadScript temp_path runtime_mode:#embedded quiet:true
    restored_ok = SCRIPT_MANAGER_RUNTIME_MODE == #standalone and EPOLY_TOOLS_RUNTIME_MODE == #standalone
    executed_ok = result_data[1] and script_manager_test_marker == 12345

    if doesFileExist temp_path then deleteFile temp_path

    test_ok = executed_ok and restored_ok
    if not test_ok then script_manager_test_passed = false

    format "PART 3 | executed:% | restored:% | PASS:%\n" executed_ok restored_ok test_ok
    test_ok
    -- return
)

/*
Verifies the manager treats a successful no-rollout script as executed instead of a failed embed.
*/
function partOfTest4 =
(
    temp_path = (getDir #temp) + "\\Script-Manager-Managed-No-Rollout.ms"
    file_stream = createFile temp_path
    format "global script_manager_test_marker\nscript_manager_test_marker = 24680\n" to:file_stream
    close file_stream

    script_manager_test_marker = 0
    result_data = script_manager.loadManagedScript temp_path script_name:"NO ROLLOUT" script_key:"NO ROLLOUT" group_path:""
    loaded_path_ok = script_manager.isScriptTreePathLoaded temp_path
    result_ok = result_data[1] and result_data[2] == 0 and script_manager_test_marker == 24680 and loaded_path_ok

    cleanup_ok = script_manager.clearLoadedRollouts()
    if doesFileExist temp_path then deleteFile temp_path

    test_ok = result_ok and cleanup_ok
    if not test_ok then script_manager_test_passed = false

    format "PART 4 | result:% | loaded-path:% | cleanup:% | PASS:%\n" result_ok loaded_path_ok cleanup_ok test_ok
    test_ok
    -- return
)

/*
Verifies a script-declared rollout is embedded and then removed cleanly by the generic host.
*/
function partOfTest5 =
(
    temp_path = (getDir #temp) + "\\Script-Manager-Rollout-Test.ms"
    file_stream = createFile temp_path
    format "global script_manager_test_rollout\nrollout script_manager_test_rollout \"SCRIPT MANAGER TEST\" (label lbl_test \"OK\")\n" to:file_stream
    close file_stream

    result_data = script_manager.loadManagedScript temp_path script_name:"ROLLOUT TEST" script_key:"ROLLOUT TEST" group_path:""
    embed_ok = result_data[1] and result_data[2] == 1 and script_manager.loaded_rollouts.count == 1
    cleanup_ok = script_manager.clearLoadedRollouts()

    if doesFileExist temp_path then deleteFile temp_path

    test_ok = embed_ok and cleanup_ok and script_manager.loaded_rollouts.count == 0
    if not test_ok then script_manager_test_passed = false

    format "PART 5 | embed:% | cleanup:% | PASS:%\n" embed_ok cleanup_ok test_ok
    test_ok
    -- return
)

/*
Verifies the EPoly compatibility alias receives embedded runtime mode while old callers remain supported.
*/
function partOfTest6 =
(
    temp_path = (getDir #temp) + "\\Script-Manager-EPoly-Compatibility.ms"
    file_stream = createFile temp_path
    format "global script_manager_test_runtime_marker\nscript_manager_test_runtime_marker = #(EPOLY_TOOLS_RUNTIME_MODE, EPolyToolsIntegration != undefined)\n" to:file_stream
    close file_stream

    script_manager_test_runtime_marker = undefined
    result_data = ScriptManagerIntegration.loadScript temp_path runtime_mode:#embedded quiet:true
    compatibility_ok = result_data[1] and script_manager_test_runtime_marker != undefined and script_manager_test_runtime_marker[1] == #embedded and script_manager_test_runtime_marker[2]

    if doesFileExist temp_path then deleteFile temp_path

    test_ok = compatibility_ok
    if not test_ok then script_manager_test_passed = false

    format "PART 6 | compatibility:% | PASS:%\n" compatibility_ok test_ok
    test_ok
    -- return
)

/*
Verifies manager reload rescans files without executing a newly discovered root script.
*/
function partOfTest7 =
(
    probe_path = script_manager.root_directory + "Script-Manager-AutoLoad-Probe.ms"
    file_stream = createFile probe_path
    format "global script_manager_test_marker\nscript_manager_test_marker = 99999\n" to:file_stream
    close file_stream

    script_manager_test_marker = 0
    reload_ok = script_manager.reloadScripts()
    discovered_ok = (findItem script_manager.available_script_paths probe_path) > 0
    no_auto_execute_ok = script_manager_test_marker == 0

    if doesFileExist probe_path then deleteFile probe_path
    cleanup_reload_ok = script_manager.reloadScripts()

    test_ok = reload_ok and discovered_ok and no_auto_execute_ok and cleanup_reload_ok
    if not test_ok then script_manager_test_passed = false

    format "PART 7 | discovered:% | no-auto-execute:% | cleanup:% | PASS:%\n" discovered_ok no_auto_execute_ok cleanup_reload_ok test_ok
    test_ok
    -- return
)

/*
Verifies F1 reload resolution targets Script-Manager versioned files and never the retired EPoly manager name.
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
Verifies Script-Manager reload does not delete registry entries belonging to scripts loaded outside the manager session.
The generic manager must not claim ownership of the shared registry by project-root location alone.
*/
function partOfTest9 =
(
    registry_id = "__script_manager_registry_preserve_test__"
    registry_source = script_manager.root_directory + "External-Registry-Test.ms"

    if ScriptManagerIntegration.hasScript registry_id then RemoveDictValue ScriptManagerIntegration.registry registry_id

    registry_data = ScriptManagerIntegration.registerScript registry_id "REGISTRY PRESERVE TEST" undefined undefined 0.01 script_manager_test_project_version registry_source capabilities:#()
    registered_ok = registry_data != undefined and ScriptManagerIntegration.hasScript registry_id
    reload_ok = script_manager.reloadScripts()
    preserved_ok = ScriptManagerIntegration.hasScript registry_id

    if ScriptManagerIntegration.hasScript registry_id then RemoveDictValue ScriptManagerIntegration.registry registry_id

    test_ok = registered_ok and reload_ok and preserved_ok
    if not test_ok then script_manager_test_passed = false

    format "PART 9 | registered:% | reload:% | registry-preserved:% | PASS:%\n" registered_ok reload_ok preserved_ok test_ok
    test_ok
    -- return
)

/*
Verifies a failed rollout-host request never marks its script as loaded.
An intentionally missing target group forces failure after fileIn but before successful embedding.
*/
function partOfTest10 =
(
    temp_path = (getDir #temp) + "\\Script-Manager-Failed-Embed-Test.ms"
    file_stream = createFile temp_path
    format "global script_manager_test_rollout\nrollout script_manager_test_rollout \"FAILED EMBED TEST\" (label lbl_test \"OK\")\n" to:file_stream
    close file_stream

    result_data = script_manager.loadManagedScript temp_path script_name:"FAILED EMBED" script_key:"FAILED EMBED" group_path:"__MISSING_GROUP__"
    failure_ok = not(result_data[1]) and result_data[2] == 0
    not_marked_ok = not(script_manager.isScriptTreePathLoaded temp_path) and (findItem script_manager.loaded_script_names "FAILED EMBED") == 0

    if doesFileExist temp_path then deleteFile temp_path
    script_manager_test_rollout = undefined

    test_ok = failure_ok and not_marked_ok
    if not test_ok then script_manager_test_passed = false

    format "PART 10 | failure:% | not-marked-loaded:% | PASS:%\n" failure_ok not_marked_ok test_ok
    test_ok
    -- return
)

/*
Verifies a paired <Backend>-UI.ms companion is hidden from discovery while its backend remains selectable.
The companion is still loaded automatically when the backend is executed.
*/
function partOfTest11 =
(
    backend_path = script_manager.root_directory + "Script-Manager-Companion-Filter-Test.ms"
    companion_path = script_manager.root_directory + "Script-Manager-Companion-Filter-Test-UI.ms"

    backend_stream = createFile backend_path
    companion_stream = createFile companion_path
    setup_ok = backend_stream != undefined and companion_stream != undefined

    if backend_stream != undefined then
    (
        format "-- backend companion-filter test\n" to:backend_stream
        close backend_stream
    )

    if companion_stream != undefined then
    (
        format "-- automatic UI companion-filter test\n" to:companion_stream
        close companion_stream
    )

    discovery_ok = if setup_ok then script_manager.discoverScripts() else false
    backend_visible_ok = discovery_ok and (findItem script_manager.available_script_paths backend_path) > 0
    companion_hidden_ok = discovery_ok and (findItem script_manager.available_script_paths companion_path) == 0 and script_manager.isAutoCompanionScriptPath companion_path

    if doesFileExist backend_path then deleteFile backend_path
    if doesFileExist companion_path then deleteFile companion_path
    restore_ok = script_manager.reloadScripts()

    test_ok = setup_ok and backend_visible_ok and companion_hidden_ok and restore_ok
    if not test_ok then script_manager_test_passed = false

    format "PART 11 | setup:% | backend-visible:% | companion-hidden:% | restore:% | PASS:%\n" setup_ok backend_visible_ok companion_hidden_ok restore_ok test_ok
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

format "============================================================\n"
format "SCRIPT-MANAGER TEST RESULT | PASS:%\n" script_manager_test_passed
format "No scene geometry is created or modified by this test.\n"
format "============================================================\n"
