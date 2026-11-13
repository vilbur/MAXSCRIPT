/*
Toolbar-Creator integration test 0.13 | shared project 0.25.
Run in 3ds Max while no other CUI customization is in progress.
*/

global toolbarCreatorTestFileVersion = 0.13
global toolbarCreatorTestProjectVersion = 0.25
global toolbarCreatorProjectVersion

if toolbarCreatorProjectVersion == undefined or toolbarCreatorProjectVersion < toolbarCreatorTestProjectVersion then
(
    toolbarCreatorProjectVersion = toolbarCreatorTestProjectVersion
)

global toolbar_creator_test_name = "Toolbar-Creator TEST"
global toolbar_creator_test_renamed_name = "Toolbar-Creator TEST RENAMED"
global toolbar_creator_test_script_a = ""
global toolbar_creator_test_script_b = ""
global toolbar_creator_test_macro_path = ""
global toolbar_creator_test_renamed_macro_path = ""
global toolbar_creator_test_success = true

/*
Prints one test assertion and preserves the shared Boolean result.
Returns the tested Boolean value.
*/
function assertToolbarCreatorTest condition_value test_name =
(
    if condition_value then
    (
        format "TOOLBAR-CREATOR TEST | PASS | %\n" test_name
    )
    else
    (
        format "TOOLBAR-CREATOR TEST | FAIL | %\n" test_name
        toolbar_creator_test_success = false
    )

    condition_value
    -- return
)

/*
Resolves the complete path of the CUIX currently active in 3ds Max.
Returns an empty string when the active file cannot be resolved.
*/
function getToolbarCreatorTestCuixPath =
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
Returns the number of toolbar buttons saved for one toolbar name.
Returns -1 when the toolbar is absent or the CUIX cannot be read.
*/
function getToolbarCreatorTestButtonCount toolbar_name =
(
    button_count = -1
    active_cuix_path = getToolbarCreatorTestCuixPath()

    if active_cuix_path != "" then
    (
        xml_document = dotNetObject "System.Xml.XmlDocument"
        xml_document.PreserveWhitespace = true

        try
        (
            xml_document.Load active_cuix_path
            windows_node = xml_document.SelectSingleNode "/ADSK_CUI/CUIWindows"

            if windows_node != undefined then
            (
                child_nodes = windows_node.ChildNodes
                for child_index = 0 to (child_nodes.Count - 1) while button_count == -1 do
                (
                    candidate_node = child_nodes.ItemOf[child_index]
                    if candidate_node.Name == "Window" and (candidate_node.GetAttribute "objectName") == toolbar_name then
                    (
                        items_node = candidate_node.SelectSingleNode "Items"
                        button_count = if items_node == undefined then 0 else items_node.ChildNodes.Count
                    )
                )
            )
        )
        catch
        (
            exception_text = getCurrentException()
            format "TOOLBAR-CREATOR TEST | CUIX read failed | % | %\n" active_cuix_path exception_text
        )
    )

    button_count
    -- return
)

/*
Loads Toolbar-Creator and creates two harmless temporary source scripts.
Removes a stale test toolbar left by an interrupted earlier test.
*/
function partOfTest1 =
(
    test_file_path = getSourceFileName()
    test_directory = getFilenamePath test_file_path
    creator_file_path = test_directory + "Toolbar-Creator-FN.ms"
    setup_ok = assertToolbarCreatorTest (doesFileExist creator_file_path) "canonical creator file exists"

    if setup_ok then
    (
        backend_loaded = true

        try
        (
            fileIn creator_file_path quiet:true
        )
        catch
        (
            backend_loaded = false
            format "TOOLBAR-CREATOR TEST | Backend load/compile error | %\n" (getCurrentException())
        )

        setup_ok = assertToolbarCreatorTest backend_loaded "backend compiles and loads without UI changes"

        if setup_ok then
        (
            setup_ok = assertToolbarCreatorTest (manageScriptToolbar != undefined) "public function loaded"
            assertToolbarCreatorTest (renameManagedScriptToolbar != undefined) "managed-toolbar rename function loaded"
            xml_probe = dotNetObject "System.Xml.XmlDocument"
            xml_probe.LoadXml "<Root><Window objectName='First'/><Window objectName='Target'/></Root>"
            matched_node = toolbarCreatorFindXmlNode xml_probe.DocumentElement "Target"
            assertToolbarCreatorTest (matched_node != undefined and (matched_node.GetAttribute "objectName") == "Target") "XML toolbar search uses indexed .NET child access"
            assertToolbarCreatorTest ((toolbarCreatorFindXmlNode xml_probe.DocumentElement "Missing") == undefined) "XML toolbar search returns undefined for absent name"

            managed_xml_probe = dotNetObject "System.Xml.XmlDocument"
            managed_xml_probe.LoadXml "<ADSK_CUI><CUIWindows><Window type='T' objectName='My Tools'><Items><Item actionID='ToolbarCreator_Test`Toolbar-Creator'/><Item actionID='ToolbarCreator_Another`Toolbar-Creator'/></Items></Window><Window type='T' objectName='Standard'><Items><Item actionID='BuiltIn`Main UI'/></Items></Window><Window type='T' objectName='Empty'/><Window type='D' objectName='Other'><Items><Item actionID='ToolbarCreator_NotToolbar`Toolbar-Creator'/></Items></Window></CUIWindows></ADSK_CUI>"
            managed_windows = managed_xml_probe.SelectSingleNode "/ADSK_CUI/CUIWindows"
            managed_names = toolbarCreatorCollectManagedNames managed_windows
            assertToolbarCreatorTest (classOf managed_names == Array and managed_names.count == 1 and managed_names[1] == "My Tools") "managed-toolbar discovery excludes unrelated CUIX windows"

            user_scripts_root = toolbarCreatorGetUserScriptsRoot()
            source_under_root = user_scripts_root + "\\CODEBASE\\Portable-Example.ms"
            portable_example_path = "$userScripts\\CODEBASE\\Portable-Example.ms"
            assertToolbarCreatorTest ((toolbarCreatorToPortablePath source_under_root) == portable_example_path) "userScripts paths shorten to a portable symbolic prefix"
            assertToolbarCreatorTest ((toolbarCreatorToPortablePath user_scripts_root) == "$userScripts") "exact userScripts root shortens without a trailing separator"
            assertToolbarCreatorTest ((toolbarCreatorResolveScriptPath portable_example_path) == source_under_root) "symbolic userScripts paths resolve to the current configured directory"
            assertToolbarCreatorTest ((toolbarCreatorToPortablePath (user_scripts_root + "_Other\\Tool.ms")) == (user_scripts_root + "_Other\\Tool.ms")) "similarly named sibling directories are not shortened"
            assertToolbarCreatorTest ((toLower (toolbarCreatorToPortablePath ((toUpper user_scripts_root) + "\\CODEBASE\\Portable-Example.ms"))) == (toLower portable_example_path)) "userScripts directory matching ignores Windows path case"
            symbolic_macro_probe = toolbarCreatorBuildMacroSource #(#(source_under_root, "PATH", "Run path")) "Toolbar-Creator" #("ToolbarCreator_PathProbe")
            assertToolbarCreatorTest ((findString symbolic_macro_probe "$userScripts") != undefined and (findString symbolic_macro_probe user_scripts_root) == undefined) "generated toolbar actions store native portable userScripts paths"

            assertToolbarCreatorTest (not(manageScriptToolbar #unsupported "Toolbar-Creator INVALID")) "invalid operation returns false"
            assertToolbarCreatorTest (not(manageScriptToolbar #create undefined)) "invalid toolbar name returns false"
            assertToolbarCreatorTest (not(manageScriptToolbar #create "Toolbar-Creator INVALID" button_data:#(#(1, 2)))) "invalid button record returns false"
            assertToolbarCreatorTest (not(manageScriptToolbar #create "Toolbar-Creator INVALID" button_data:#(1))) "non-array button record returns false"
            assertToolbarCreatorTest (not(manageScriptToolbar #delete "Toolbar-Creator INVALID" macro_file_path:1)) "invalid macro path returns false"
        )
    )

    if setup_ok then
    (
        temp_directory = getDir #temp
        toolbar_creator_test_script_a = temp_directory + "\\Toolbar-Creator-Test-A.ms"
        toolbar_creator_test_script_b = temp_directory + "\\Toolbar-Creator-Test-B.ms"
        toolbar_creator_test_macro_path = temp_directory + "\\Toolbar-Creator-Test-Actions.mcr"
        toolbar_creator_test_renamed_macro_path = temp_directory + "\\Toolbar-Creator-Test-Renamed-Actions.mcr"
        file_type = dotNetClass "System.IO.File"
        encoding_value = dotNetObject "System.Text.UTF8Encoding" true
        file_type.WriteAllText toolbar_creator_test_script_a "format \"TOOLBAR-CREATOR TEST SCRIPT A\\n\"\n" encoding_value
        file_type.WriteAllText toolbar_creator_test_script_b "format \"TOOLBAR-CREATOR TEST SCRIPT B\\n\"\n" encoding_value

        if getToolbarCreatorTestButtonCount toolbar_creator_test_name >= 0 then
        (
            manageScriptToolbar #delete toolbar_creator_test_name \
                macro_file_path:toolbar_creator_test_macro_path \
                register_macros:false \
                save_ui:true
        )

        if getToolbarCreatorTestButtonCount toolbar_creator_test_renamed_name >= 0 then
        (
            manageScriptToolbar #delete toolbar_creator_test_renamed_name \
                macro_file_path:toolbar_creator_test_renamed_macro_path \
                register_macros:false \
                save_ui:true
        )
    )

    setup_ok
    -- return
)

/*
Verifies recursive discovery, individual scripts, deduplication, and failure contracts.
This stage uses its own temporary tree and does not modify the 3ds Max UI.
*/
function partOfTest2 =
(
    scan_available = assertToolbarCreatorTest (collectToolbarScripts != undefined) "recursive collector loaded"
    scan_ok = scan_available

    if scan_available then
    (
        scan_root = (getDir #temp) + "\\Toolbar-Creator-Scan-" + ((timestamp()) as string)
        nested_root = scan_root + "\\Nested"
        deepest_root = nested_root + "\\Deep"
        makeDir deepest_root all:true

        root_script = scan_root + "\\Root.ms"
        nested_script = nested_root + "\\Nested__Script--Test.ms"
        deep_script = deepest_root + "\\Deep.ms"
        ignored_file = deepest_root + "\\Ignore.txt"
        file_type = dotNetClass "System.IO.File"
        directory_type = dotNetClass "System.IO.Directory"
        encoding_value = dotNetObject "System.Text.UTF8Encoding" true

        file_type.WriteAllText root_script "print \"root\"\n" encoding_value
        file_type.WriteAllText nested_script "print \"nested\"\n" encoding_value
        file_type.WriteAllText deep_script "print \"deep\"\n" encoding_value
        file_type.WriteAllText ignored_file "ignore" encoding_value

        scan_data = collectToolbarScripts #(scan_root, nested_script, scan_root)
        scan_ok = assertToolbarCreatorTest (classOf scan_data == Array) "collector returns Array for valid sources"

        if scan_ok then
        (
            assertToolbarCreatorTest (scan_data.count == 3) "recursive scan finds exactly three unique .ms files"
            found_paths = for button_record in scan_data collect (toLower button_record[1])
            assertToolbarCreatorTest ((findItem found_paths (toLower root_script)) != 0) "root .ms included"
            assertToolbarCreatorTest ((findItem found_paths (toLower nested_script)) != 0) "nested .ms included"
            assertToolbarCreatorTest ((findItem found_paths (toLower deep_script)) != 0) "deep .ms included"
            assertToolbarCreatorTest (scan_data[1].count == 3) "result records match toolbar button contract"
            named_buttons = for button_record in scan_data where (toLower button_record[1]) == (toLower nested_script) collect button_record
            name_ok = named_buttons.count == 1
            if name_ok then name_ok = named_buttons[1][2] == "Nested Script Test" and named_buttons[1][3] == "Run Nested Script Test"
            assertToolbarCreatorTest name_ok "script name separators become single spaces in button text and tooltip"
        )

        top_only_data = collectToolbarScripts #(scan_root) recursive:false
        assertToolbarCreatorTest (classOf top_only_data == Array and top_only_data.count == 1) "nonrecursive scan includes root files only"

        invalid_data = collectToolbarScripts #((scan_root + "\\Missing.ms"))
        assertToolbarCreatorTest (invalid_data == undefined) "missing source reports failure"

        invalid_type_data = collectToolbarScripts #(123)
        assertToolbarCreatorTest (invalid_type_data == undefined) "unsupported source type reports failure"

        empty_root = scan_root + "\\Empty"
        makeDir empty_root
        empty_data = collectToolbarScripts #(empty_root)
        assertToolbarCreatorTest (classOf empty_data == Array and empty_data.count == 0) "empty folder returns empty Array"

        macro_test_path = @"$userScripts\new\Nested.ms"
        macro_test_source = toolbarCreatorBuildMacroSource #(#(macro_test_path, "TEST", "Test tooltip")) "Toolbar-Creator Test" #("ToolbarCreator_Test")
        parsed_macro_paths = toolbarCreatorParseGeneratedMacroPaths macro_test_source
        macro_parse_ok = classOf parsed_macro_paths == Array
        if macro_parse_ok then macro_parse_ok = parsed_macro_paths.count == 1
        if macro_parse_ok then macro_parse_ok = parsed_macro_paths[1][1] == "ToolbarCreator_Test" and parsed_macro_paths[1][2] == macro_test_path
        assertToolbarCreatorTest macro_parse_ok "generated MacroScript path parser restores symbolic paths with backslashes"

        directory_type.Delete scan_root true
    )

    scan_ok
    -- return
)

/*
Creates a one-button toolbar and verifies the saved CUIX result.
The test disables MacroScript registration to avoid persistent test actions.
*/
function partOfTest3 =
(
    create_data = #(
        #(toolbar_creator_test_script_a, "TEST A", "Run test script A")
    )

    create_ok = manageScriptToolbar #create toolbar_creator_test_name button_data:create_data \
        macro_category:"Toolbar-Creator Test" \
        macro_file_path:toolbar_creator_test_macro_path \
        register_macros:false \
        show_toolbar:false \
        save_ui:true

    assertToolbarCreatorTest create_ok "create returns true"
    assertToolbarCreatorTest (getToolbarCreatorTestButtonCount toolbar_creator_test_name == 1) "create saves one button"
    loaded_buttons = getManagedScriptToolbarButtons toolbar_creator_test_name macro_file_path:toolbar_creator_test_macro_path
    loaded_ok = classOf loaded_buttons == Array
    if loaded_ok then loaded_ok = loaded_buttons.count == 1
    if loaded_ok then loaded_ok = loaded_buttons[1][1] == toolbarCreatorToPortablePath toolbar_creator_test_script_a
    if loaded_ok then loaded_ok = loaded_buttons[1][2] == "TEST A" and loaded_buttons[1][3] == "Run test script A"
    assertToolbarCreatorTest loaded_ok "managed toolbar selection can restore one script from saved CUIX and MacroScript"
    create_ok
    -- return
)

/*
Updates the test toolbar to two buttons and verifies replacement in CUIX.
No duplicate same-named toolbar is allowed to remain.
*/
function partOfTest4 =
(
    update_data = #(
        #(toolbar_creator_test_script_a, "TEST A", "Run test script A"),
        #(toolbar_creator_test_script_b, "TEST B", "Run test script B")
    )

    update_ok = manageScriptToolbar #update toolbar_creator_test_name button_data:update_data \
        macro_category:"Toolbar-Creator Test" \
        macro_file_path:toolbar_creator_test_macro_path \
        register_macros:false \
        show_toolbar:false \
        save_ui:true

    assertToolbarCreatorTest update_ok "update returns true"
    assertToolbarCreatorTest (getToolbarCreatorTestButtonCount toolbar_creator_test_name == 2) "update saves two buttons"
    loaded_buttons = getManagedScriptToolbarButtons toolbar_creator_test_name macro_file_path:toolbar_creator_test_macro_path
    loaded_ok = classOf loaded_buttons == Array
    if loaded_ok then loaded_ok = loaded_buttons.count == 2
    if loaded_ok then loaded_ok = loaded_buttons[1][1] == toolbarCreatorToPortablePath toolbar_creator_test_script_a
    if loaded_ok then loaded_ok = loaded_buttons[2][1] == toolbarCreatorToPortablePath toolbar_creator_test_script_b
    if loaded_ok then loaded_ok = loaded_buttons[2][2] == "TEST B" and loaded_buttons[2][3] == "Run test script B"
    assertToolbarCreatorTest loaded_ok "managed toolbar selection restores script order, text and tooltip after update"
    update_ok
    -- return
)

/*
Renames the test toolbar and checks that its ordered buttons survive.
The original generated MacroScript and toolbar must no longer exist.
*/
function partOfTest5 =
(
    rename_ok = renameManagedScriptToolbar toolbar_creator_test_name toolbar_creator_test_renamed_name \
        old_macro_file_path:toolbar_creator_test_macro_path \
        new_macro_file_path:toolbar_creator_test_renamed_macro_path \
        macro_category:"Toolbar-Creator Test" \
        register_macros:false \
        show_toolbar:false \
        save_ui:true

    assertToolbarCreatorTest rename_ok "rename returns true"
    renamed_buttons = getManagedScriptToolbarButtons toolbar_creator_test_renamed_name macro_file_path:toolbar_creator_test_renamed_macro_path
    buttons_ok = (classOf renamed_buttons == Array)
    if buttons_ok then buttons_ok = renamed_buttons.count == 2
    if buttons_ok then buttons_ok = renamed_buttons[1][1] == toolbarCreatorToPortablePath toolbar_creator_test_script_a
    if buttons_ok then buttons_ok = renamed_buttons[2][1] == toolbarCreatorToPortablePath toolbar_creator_test_script_b
    if buttons_ok then buttons_ok = renamed_buttons[1][2] == "TEST A" and renamed_buttons[2][2] == "TEST B"
    if buttons_ok then buttons_ok = renamed_buttons[1][3] == "Run test script A" and renamed_buttons[2][3] == "Run test script B"
    assertToolbarCreatorTest buttons_ok "rename preserves scripts, labels, tooltip and order"
    assertToolbarCreatorTest ((getToolbarCreatorTestButtonCount toolbar_creator_test_name == -1) and (getToolbarCreatorTestButtonCount toolbar_creator_test_renamed_name == 2) and not doesFileExist toolbar_creator_test_macro_path) "rename removes the original toolbar and generated macro"

    rename_ok
    -- return
)

/*
Deletes the renamed test toolbar, verifies absence, and removes temporary files.
Leaves the active user CUIX without the temporary test toolbar.
*/
function partOfTest6 =
(
    /* Simulate a previously saved toolbar whose generated macro was lost. */
    if doesFileExist toolbar_creator_test_renamed_macro_path then deleteFile toolbar_creator_test_renamed_macro_path
    assertToolbarCreatorTest (not doesFileExist toolbar_creator_test_renamed_macro_path) "test toolbar macro file is unavailable"

    delete_ok = manageScriptToolbar #delete toolbar_creator_test_renamed_name \
        macro_file_path:toolbar_creator_test_renamed_macro_path \
        register_macros:false \
        save_ui:true

    assertToolbarCreatorTest delete_ok "delete works even if existing toolbar macro file is missing"
    assertToolbarCreatorTest (getToolbarCreatorTestButtonCount toolbar_creator_test_renamed_name == -1) "delete removes toolbar from the active saved CUIX"
    managed_names = listManagedScriptToolbars()
    managed_list_ok = classOf managed_names == Array
    if managed_list_ok then managed_list_ok = (findItem managed_names toolbar_creator_test_renamed_name) == 0
    assertToolbarCreatorTest managed_list_ok "delete removes toolbar from managed toolbar list"
    assertToolbarCreatorTest (not doesFileExist toolbar_creator_test_renamed_macro_path) "delete removes generated macro file"

    if doesFileExist toolbar_creator_test_script_a then deleteFile toolbar_creator_test_script_a
    if doesFileExist toolbar_creator_test_script_b then deleteFile toolbar_creator_test_script_b

    format "TOOLBAR-CREATOR TEST | RESULT | %\n" toolbar_creator_test_success
    format "TOOLBAR-CREATOR TEST | ORDER | CREATE -> UPDATE -> RENAME -> DELETE\n"
    toolbar_creator_test_success
    -- return
)

if partOfTest1() then
(
    partOfTest2()
    partOfTest3()
    partOfTest4()
    partOfTest5()
    partOfTest6()
)
else
(
    format "TOOLBAR-CREATOR TEST | ABORT | Backend failed to load; UI integration was not attempted.\n"
)

