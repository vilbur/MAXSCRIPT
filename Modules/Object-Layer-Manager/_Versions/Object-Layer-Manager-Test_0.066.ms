/*
Object Layer Manager Test 0.066
Performs source-level crash-safety checks, then loads the canonical tool once for a safe smoke test.
*/

global object_layer_manager_test_source = getSourceFileName()
global object_layer_manager_test_file_version = 0.066
global object_layer_manager_test_project_version = 0.076

/*
Returns the directory containing this test.
The test must be executed from a saved .ms file.
*/
function getObjectLayerManagerTestDirectory =
(
    if object_layer_manager_test_source == undefined or object_layer_manager_test_source == "" then
    (
        throw "Object-Layer-Manager-Test.ms must be executed from a saved .ms file."
    )

    getFilenamePath object_layer_manager_test_source
    -- return
)

/*
Returns the complete canonical Object Layer Manager source as one string.
The file is read without executing it so teardown ordering can be checked safely.
*/
function getObjectLayerManagerTestSourceText =
(
    local tool_path = getObjectLayerManagerTestDirectory() + "Object-Layer-Manager.ms"
    local file_stream = openFile tool_path mode:"rt"
    local source_text = ""

    if file_stream == undefined then
    (
        throw ("Object Layer Manager test: cannot open source: " + tool_path)
    )

    while not eof file_stream do
    (
        source_text += readLine file_stream
        source_text += "\n"
    )

    close file_stream

    source_text
    -- return
)

/*
Loads the canonical Object Layer Manager source exactly once.
This test intentionally avoids a second immediate CUI teardown/recreation cycle.
*/
function loadObjectLayerManagerTestTool =
(
    local tool_path = getObjectLayerManagerTestDirectory() + "Object-Layer-Manager.ms"

    if not doesFileExist tool_path then
    (
        throw ("Object Layer Manager test: missing canonical tool: " + tool_path)
    )

    fileIn tool_path quiet:true
    true
    -- return
)

/*
Requires one condition to be true.
*/
function requireObjectLayerManagerTest condition message =
(
    if not condition then
    (
        throw ("Object Layer Manager test failed: " + message)
    )

    true
    -- return
)

/*
Verifies that reload cleanup executes before the main rollout is redefined.
The old hierarchy must be detached while the old parent is still alive.
*/
function partOfTest1 =
(
    local source_text = getObjectLayerManagerTestSourceText()
    local cleanup_call_index = findString source_text "ascClosePreviousObjectLayerManagerDialog()"
    local rollout_index = findString source_text "rollout asc_main_rollout"

    requireObjectLayerManagerTest (cleanup_call_index != undefined) "Early dialog cleanup call is missing."
    requireObjectLayerManagerTest (rollout_index != undefined) "Main rollout definition is missing."
    requireObjectLayerManagerTest (cleanup_call_index < rollout_index) "Dialog cleanup must run before the rollout is redefined."
    requireObjectLayerManagerTest ((findString source_text "existing_dialog.clearLayerHierarchy()") != undefined) "Old dynamic hierarchy is not detached before dialog teardown."
    requireObjectLayerManagerTest ((findString source_text "cui.UnRegisterDialogBar existing_dialog") != undefined) "CUI dialog bar is not unregistered before destruction."
    requireObjectLayerManagerTest ((findString source_text "existing_dialog.hwnd") == undefined) "Reload cleanup still probes HWND state."
    requireObjectLayerManagerTest ((findString source_text "rollout asc_main_rollout \"Object-Layer-Manager | v0.076\"") != undefined) "Main rollout does not use the literal crash-safe title."
    requireObjectLayerManagerTest ((findString source_text "object_layer_manager_rollout_title") == undefined) "Pre-rollout dynamic title resolution is still present."
    requireObjectLayerManagerTest ((findString source_text "asc_main_rollout.title =") == undefined) "Unsafe rollout title mutation is present."
    requireObjectLayerManagerTest ((findString source_text "dotNetControl btn_add_default \"System.Windows.Forms.Button\"") != undefined) "Default .NET layer button is missing."
    requireObjectLayerManagerTest ((findString source_text "rollout_creator.addControl #dotNetControl #btn_add_selection \"System.Windows.Forms.Button\"") != undefined) "Generated branch .NET layer button is missing."
    requireObjectLayerManagerTest ((findString source_text "function ascApplyLayerButtonFont") != undefined) "Per-control layer-button font helper is missing."
    requireObjectLayerManagerTest ((findString source_text "global asc_layer_button_font") == undefined) "Unsafe shared disposable layer-button Font global is still present."
    requireObjectLayerManagerTest ((findString source_text "function ascApplyLayerButtonStyle") != undefined) "Dark .NET layer-button style helper is missing."
    requireObjectLayerManagerTest ((findString source_text "UseVisualStyleBackColor = false") != undefined) "Dark .NET layer buttons still use the Windows visual-style background."
    requireObjectLayerManagerTest ((findString source_text "BackColor = color_class.FromArgb 52 52 52") != undefined) "Dark .NET layer-button background is missing."
    requireObjectLayerManagerTest ((findString source_text "button_control.FlatStyle = flat_style_class.Flat") != undefined) "Borderless .NET layer-button flat style is missing."
    requireObjectLayerManagerTest ((findString source_text "button_control.FlatAppearance.BorderSize = 0") != undefined) "Borderless .NET layer-button border size is not zero."
    requireObjectLayerManagerTest ((findString source_text "button_control.Font.FontFamily 9.0") != undefined) "Layer-button font is not the requested 9 pt size."
    requireObjectLayerManagerTest ((findString source_text "lockWidth:true lockHeight:false") != undefined) "Dialog width is not locked at 256 px."
    requireObjectLayerManagerTest ((findString source_text "minSize:[256,240] maxSize:[256,-1]") != undefined) "CUI width is not fixed at 256 px."
    requireObjectLayerManagerTest ((findString source_text "rcmenu asc_layer_context_menu") != undefined) "Layer-action context menu definition is missing."
    requireObjectLayerManagerTest ((findString source_text "keyboard.shiftPressed") != undefined) "SHIFT + RMB temporary-isolation modifier is missing."
    requireObjectLayerManagerTest ((findString source_text "popupMenu asc_layer_context_menu") != undefined) "CTRL + RMB layer-action popup menu is missing."
    requireObjectLayerManagerTest ((findString source_text "SHIFT + RMB: Temporarily isolate this layer.") != undefined) "Generated layer-button SHIFT + RMB tooltip is missing."
    requireObjectLayerManagerTest ((findString source_text "CTRL + RMB: Open the layer actions menu.") != undefined) "Generated layer-button CTRL + RMB tooltip is missing."
    requireObjectLayerManagerTest ((findString source_text "CTRL + RMB: Temporarily isolate this layer.") == undefined) "Old CTRL + RMB isolation tooltip is still present."
    requireObjectLayerManagerTest ((findString source_text "button btn_create_layer \"Create\"") != undefined) "Create layer button is missing."
    requireObjectLayerManagerTest ((findString source_text "button btn_refresh_layers \"Refresh Layers\" width:116 height:32 across:2") != undefined) "Refresh/Create top row does not use across:2."
    requireObjectLayerManagerTest ((findString source_text "btn_refresh_layers.width = content_width") == undefined) "Vertical resize still expands Refresh over the Create button."
    requireObjectLayerManagerTest ((findString source_text "function ascGetMajoritySelectedLayer") != undefined) "Majority selected-layer helper is missing."
    requireObjectLayerManagerTest ((findString source_text "function ascCreateLayerForSelection") != undefined) "Create-layer operation is missing."
    requireObjectLayerManagerTest ((findString source_text "scene_node.layer") != undefined) "Create-layer operation does not read selected-node layers."
    requireObjectLayerManagerTest ((findString source_text "new_layer.setParent parent_layer") != undefined) "Created layer is not nested under the majority parent layer."
    requireObjectLayerManagerTest ((findString source_text "default_name = parent_name + \"-NEW\"") != undefined) "Create-layer default name is not based on the majority parent layer."
    requireObjectLayerManagerTest ((findString source_text "getString \"New layer name:\" default:default_name") != undefined) "Create-layer name prompt is missing or not prefilled."
    requireObjectLayerManagerTest ((findString source_text "on btn_create_layer pressed do") != undefined) "Create-layer button handler is missing."
    requireObjectLayerManagerTest ((findString source_text "button btn_restart \"Restart\"") != undefined) "Bottom Restart button is missing."
    requireObjectLayerManagerTest ((findString source_text "fileIn restart_path quiet:true") != undefined) "Restart button does not reload the canonical script."

    true
    -- return
)

/*
Verifies that the rollout close handler stays lightweight during native window destruction.
It must not recursively remove child subrollouts while the parent dialog is closing.
*/
function partOfTest2 =
(
    local source_text = getObjectLayerManagerTestSourceText()
    local close_start = findString source_text "on asc_main_rollout close do"
    local close_end = undefined
    local close_length = 0
    local close_text = ""

    requireObjectLayerManagerTest (close_start != undefined) "Main rollout close handler is missing."

    close_end = findString (substring source_text close_start (source_text.count - close_start + 1)) "on btn_refresh_layers pressed do"
    requireObjectLayerManagerTest (close_end != undefined) "Could not resolve the end of the close handler."

    close_length = close_end - 1
    close_text = substring source_text close_start close_length

    requireObjectLayerManagerTest ((findString close_text "clearLayerHierarchy()") == undefined) "Close handler still removes dynamic subrollouts during native destruction."

    true
    -- return
)

/*
Loads the canonical tool once and verifies that its current dialog starts successfully.
Repeated reload is intentionally a manual follow-up after 3ds Max has returned to its message loop.
*/
function partOfTest3 =
(
    loadObjectLayerManagerTestTool()

    requireObjectLayerManagerTest (::asc_main_rollout != undefined) "Main rollout was not defined."
    requireObjectLayerManagerTest (try(asc_main_rollout.inDialog)catch(false)) "Main rollout is not in a CreateDialog window."
    requireObjectLayerManagerTest (object_layer_manager_file_version >= 0.076) "Expected file version 0.076 or newer."
    requireObjectLayerManagerTest (try(asc_main_rollout.btn_add_default.GetType().FullName == "System.Windows.Forms.Button")catch(false)) "Default control is not a Windows Forms Button."
    requireObjectLayerManagerTest (try(asc_main_rollout.btn_add_default.BackColor.R < 100)catch(false)) "Default .NET layer button background is not dark."
    requireObjectLayerManagerTest (try(asc_main_rollout.btn_add_default.FlatAppearance.BorderSize == 0)catch(false)) "Default .NET layer button still has a visible border."
    requireObjectLayerManagerTest (try(asc_main_rollout.btn_refresh_layers.pos.y == asc_main_rollout.btn_create_layer.pos.y)catch(false)) "Refresh and Create are not on the same top row."
    requireObjectLayerManagerTest (try(asc_main_rollout.btn_refresh_layers.width == asc_main_rollout.btn_create_layer.width)catch(false)) "Refresh and Create do not use equal widths."
    requireObjectLayerManagerTest (try(asc_main_rollout.btn_restart != undefined)catch(false)) "Restart control is missing at runtime."
    requireObjectLayerManagerTest (try(asc_main_rollout.btn_restart.pos.y > asc_main_rollout.hierarchy_slot.pos.y)catch(false)) "Restart control is not positioned below the hierarchy."
    requireObjectLayerManagerTest (asc_main_rollout.title == "Object-Layer-Manager | v0.076") "Rollout title does not match the literal declaration."

    true
    -- return
)

partOfTest1()
partOfTest2()
partOfTest3()

format "\nOBJECT LAYER MANAGER TEST PASSED\n"
format "The test performs one UI load only. Run Object-Layer-Manager.ms again manually after this test to verify normal reload replacement.\n"
format "Undo order: none. This test does not modify scene geometry.\n"
