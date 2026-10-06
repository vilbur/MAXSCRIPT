/*
Object Layer Manager Test 0.072
Performs source-level crash-safety checks, then loads the canonical tool once for a safe smoke test.
*/

global object_layer_manager_test_source = getSourceFileName()
global object_layer_manager_test_file_version = 0.072
global object_layer_manager_test_project_version = 0.082

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
    local visibility_chain_start = findString source_text "function ascGetLayerVisibilityChain layer_name"
    local visibility_toggle_start = findString source_text "function ascToggleLayerVisibility layer_name"
    local visibility_chain_text = ""
    local primary_handler_start = findString source_text "function ascHandleLayerButtonPressed layer_name"
    local context_menu_start = findString source_text "global asc_layer_context_menu_target"
    local primary_handler_text = ""

    if (visibility_chain_start != undefined) and (visibility_toggle_start != undefined) and (visibility_toggle_start > visibility_chain_start) then
    (
        visibility_chain_text = substring source_text visibility_chain_start (visibility_toggle_start - visibility_chain_start)
    )

    if (primary_handler_start != undefined) and (context_menu_start != undefined) and (context_menu_start > primary_handler_start) then
    (
        primary_handler_text = substring source_text primary_handler_start (context_menu_start - primary_handler_start)
    )

    requireObjectLayerManagerTest (cleanup_call_index != undefined) "Early dialog cleanup call is missing."
    requireObjectLayerManagerTest (rollout_index != undefined) "Main rollout definition is missing."
    requireObjectLayerManagerTest (cleanup_call_index < rollout_index) "Dialog cleanup must run before the rollout is redefined."
    requireObjectLayerManagerTest ((findString source_text "existing_dialog.clearLayerHierarchy()") != undefined) "Old dynamic hierarchy is not detached before dialog teardown."
    requireObjectLayerManagerTest ((findString source_text "cui.UnRegisterDialogBar existing_dialog") != undefined) "CUI dialog bar is not unregistered before destruction."
    requireObjectLayerManagerTest ((findString source_text "existing_dialog.hwnd") == undefined) "Reload cleanup still probes HWND state."
    requireObjectLayerManagerTest ((findString source_text "rollout asc_main_rollout \"Object-Layer-Manager | v0.082\"") != undefined) "Main rollout does not use the literal crash-safe title."
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
    requireObjectLayerManagerTest ((findString source_text "function ascApplyLayerButtonFont button_control highlighted:false") != undefined) "Layer-button font helper does not support highlighted state."
    requireObjectLayerManagerTest ((findString source_text "font_style_class.Bold") != undefined) "Last-used layer highlight does not use a bold font."
    requireObjectLayerManagerTest ((findString source_text "font_style_class.Regular") != undefined) "Non-highlighted layer buttons do not restore the regular font."
    requireObjectLayerManagerTest ((findString source_text "function ascRegisterLayerButton") != undefined) "Visible layer-button registry helper is missing."
    requireObjectLayerManagerTest ((findString source_text "ascApplyLayerButtonFont button_control highlighted:(layer_name == asc_last_used_layer_name)") != undefined) "Registered layer buttons do not restore last-used font emphasis."
    requireObjectLayerManagerTest ((findString source_text "function ascSetLastUsedLayerName") != undefined) "Last-used layer setter is missing."
    requireObjectLayerManagerTest ((findString source_text "ascWriteSetting \"LastUsedLayer\" layer_name") != undefined) "Last-used layer is not persisted per scene."
    requireObjectLayerManagerTest (primary_handler_text != "") "Could not isolate the layer-button LMB handler for highlight validation."
    requireObjectLayerManagerTest ((findString primary_handler_text "if operation_ok then") != undefined) "Layer-button LMB highlight is not gated by a successful move."
    requireObjectLayerManagerTest ((findString primary_handler_text "ascSetLastUsedLayerName layer_name") != undefined) "Successful layer-button LMB does not update the last-used layer."
    requireObjectLayerManagerTest ((findString source_text "ascRegisterLayerButton btn_add_selection asc_dynamic_layer_names[layer_name_index]") != undefined) "Generated branch buttons are not registered for highlight restoration."
    requireObjectLayerManagerTest ((findString source_text "ascRegisterLayerButton btn_add_default \"0\"") != undefined) "Default button is not registered for highlight restoration."
    requireObjectLayerManagerTest ((findString source_text "lockWidth:true lockHeight:false") != undefined) "Dialog width is not locked at 256 px."
    requireObjectLayerManagerTest ((findString source_text "minSize:[256,240] maxSize:[256,-1]") != undefined) "CUI width is not fixed at 256 px."
    requireObjectLayerManagerTest ((findString source_text "rcmenu asc_layer_context_menu") != undefined) "Layer-action context menu definition is missing."
    requireObjectLayerManagerTest ((findString source_text "keyboard.shiftPressed") != undefined) "SHIFT + RMB temporary-isolation modifier is missing."
    requireObjectLayerManagerTest ((findString source_text "popupMenu asc_layer_context_menu") != undefined) "CTRL + RMB layer-action popup menu is missing."
    requireObjectLayerManagerTest ((findString source_text "function ascGetLayerVisibilityChain") != undefined) "Layer parent-chain visibility helper is missing."
    requireObjectLayerManagerTest ((findString source_text "while (parent_layer != undefined) and (parent_layer.name != \"0\") do") != undefined) "Layer visibility chain does not stop before Default."
    requireObjectLayerManagerTest ((findString source_text "visibility_chain = ascGetLayerVisibilityChain layer_name") != undefined) "RMB visibility action does not collect the parent chain."
    requireObjectLayerManagerTest ((findString source_text "chain_layer.isHidden = hide_chain") != undefined) "RMB visibility action does not apply one state to the whole parent chain."
    requireObjectLayerManagerTest (visibility_chain_text != "") "Could not isolate the visibility-chain helper for scope validation."
    requireObjectLayerManagerTest ((findString visibility_chain_text "parent_layer = target_layer.getParent()") != undefined) "RMB visibility chain does not start by walking to the clicked layer's parent."
    requireObjectLayerManagerTest ((findString visibility_chain_text "parent_layer = parent_layer.getParent()") != undefined) "RMB visibility chain does not continue upward through parents."
    requireObjectLayerManagerTest ((findString visibility_chain_text "getChild") == undefined) "RMB visibility chain must not traverse child layers."
    requireObjectLayerManagerTest ((findString visibility_chain_text "getNumChildren") == undefined) "RMB visibility chain must not traverse sibling/child hierarchy branches."
    requireObjectLayerManagerTest ((findString source_text "function ascLoadLayerRolloutStates") != undefined) "Saved rollout-state loader is missing."
    requireObjectLayerManagerTest ((findString source_text "function ascSetLayerRolloutOpenState") != undefined) "Rollout-state setter is missing."
    requireObjectLayerManagerTest ((findString source_text "rolledUp rollout_is_open do") != undefined) "Dynamic rollouts do not persist their rolled-up state."
    requireObjectLayerManagerTest ((findString source_text "ascSetLayerRolloutOpenState asc_dynamic_layer_names[layer_name_index] rollout_is_open") != undefined) "Dynamic rollout callback does not save state by native layer name."
    requireObjectLayerManagerTest ((findString source_text "rollout_is_open = ascGetLayerRolloutOpenState layer_name") != undefined) "Dynamic rollout install does not read the saved open state."
    requireObjectLayerManagerTest ((findString source_text "rolledUp:(not rollout_is_open)") != undefined) "Dynamic rollout install does not restore the saved rolled-up state."
    requireObjectLayerManagerTest ((findString source_text "Show/Hide Layer + Parent Chain") != undefined) "Layer context-menu visibility label does not describe the parent-chain action."
    requireObjectLayerManagerTest ((findString source_text "RMB: Show/hide this layer and all parent layers.") != undefined) "Generated layer-button RMB parent-chain tooltip is missing."
    requireObjectLayerManagerTest ((findString source_text "RMB: Show/hide Default.") != undefined) "Default-layer RMB tooltip is missing."
    requireObjectLayerManagerTest ((findString source_text "SHIFT + RMB: Temporarily isolate this layer.") != undefined) "Generated layer-button SHIFT + RMB tooltip is missing."
    requireObjectLayerManagerTest ((findString source_text "CTRL + RMB: Open the layer actions menu.") != undefined) "Generated layer-button CTRL + RMB tooltip is missing."
    requireObjectLayerManagerTest ((findString source_text "CTRL + RMB: Temporarily isolate this layer.") == undefined) "Old CTRL + RMB isolation tooltip is still present."
    requireObjectLayerManagerTest ((findString source_text "RMB: Toggle layer visibility.") == undefined) "Old single-layer RMB visibility tooltip is still present."
    requireObjectLayerManagerTest ((findString source_text "button btn_create_layer \"New Layer\"") != undefined) "New Layer button is missing."
    requireObjectLayerManagerTest ((findString source_text "button btn_refresh_layers \"Refresh Layers\" width:116 height:32 across:2") != undefined) "Refresh/New Layer top row does not use across:2."
    requireObjectLayerManagerTest ((findString source_text "btn_refresh_layers.width = content_width") == undefined) "Vertical resize still expands Refresh over the New Layer button."
    requireObjectLayerManagerTest ((findString source_text "function resizeLayerRolloutTree") == undefined) "Obsolete recursive width-relayout helper is still present."
    requireObjectLayerManagerTest ((findString source_text "dialog_size.x") == undefined) "Resize callback still performs width-driven relayout."
    requireObjectLayerManagerTest ((findString source_text "function ascGetMajoritySelectedLayer") != undefined) "Majority selected-layer helper is missing."
    requireObjectLayerManagerTest ((findString source_text "function ascCreateLayerForSelection") != undefined) "Create-layer operation is missing."
    requireObjectLayerManagerTest ((findString source_text "function ascCreateLayerForSelection nested:true") != undefined) "Create-layer nested/sibling mode parameter is missing."
    requireObjectLayerManagerTest ((findString source_text "scene_node.layer") != undefined) "Create-layer operation does not read selected-node layers."
    requireObjectLayerManagerTest ((findString source_text "target_parent_layer = current_layer") != undefined) "LMB nested mode does not use the current majority layer as parent."
    requireObjectLayerManagerTest ((findString source_text "target_parent_layer = try(current_layer.getParent())catch(undefined)") != undefined) "RMB sibling mode does not resolve the current layer parent."
    requireObjectLayerManagerTest ((findString source_text "new_layer.setParent target_parent_layer") != undefined) "New layer does not use the resolved nested/sibling parent."
    requireObjectLayerManagerTest ((findString source_text "default_name = current_name + \"-NEW\"") != undefined) "Create-layer default name is not based on the current majority layer."
    requireObjectLayerManagerTest ((findString source_text "function ascPromptLayerName default_name") != undefined) "Native layer-name prompt helper is missing."
    requireObjectLayerManagerTest ((findString source_text "editText edt_layer_name_prompt") != undefined) "Native layer-name editText control is missing."
    requireObjectLayerManagerTest ((findString source_text "createDialog asc_layer_name_prompt_rollout width:320 height:84 modal:true") != undefined) "Layer-name prompt is not modal."
    requireObjectLayerManagerTest ((findString source_text "new_name = ascPromptLayerName default_name") != undefined) "Create-layer operation does not use the native layer-name prompt."
    requireObjectLayerManagerTest ((findString source_text "getString \"New layer name:\"") == undefined) "Unsupported getString layer-name prompt is still present."
    requireObjectLayerManagerTest ((findString source_text "on btn_create_layer pressed do") != undefined) "New Layer LMB handler is missing."
    requireObjectLayerManagerTest ((findString source_text "ascCreateLayerForSelection nested:true") != undefined) "New Layer LMB does not request nested creation."
    requireObjectLayerManagerTest ((findString source_text "on btn_create_layer rightclick do") != undefined) "New Layer RMB handler is missing."
    requireObjectLayerManagerTest ((findString source_text "ascCreateLayerForSelection nested:false") != undefined) "New Layer RMB does not request sibling creation."
    requireObjectLayerManagerTest ((findString source_text "RMB: Create a layer next to that current layer.") != undefined) "New Layer RMB tooltip is missing."
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
    requireObjectLayerManagerTest (object_layer_manager_file_version >= 0.082) "Expected file version 0.082 or newer."
    requireObjectLayerManagerTest (try(asc_main_rollout.btn_add_default.GetType().FullName == "System.Windows.Forms.Button")catch(false)) "Default control is not a Windows Forms Button."
    requireObjectLayerManagerTest (try(asc_main_rollout.btn_add_default.BackColor.R < 100)catch(false)) "Default .NET layer button background is not dark."
    requireObjectLayerManagerTest (try(asc_main_rollout.btn_add_default.FlatAppearance.BorderSize == 0)catch(false)) "Default .NET layer button still has a visible border."
    requireObjectLayerManagerTest (try(asc_main_rollout.btn_refresh_layers.pos.y == asc_main_rollout.btn_create_layer.pos.y)catch(false)) "Refresh and New Layer are not on the same top row."
    requireObjectLayerManagerTest (try(asc_main_rollout.btn_refresh_layers.width == asc_main_rollout.btn_create_layer.width)catch(false)) "Refresh and New Layer do not use equal widths."
    requireObjectLayerManagerTest (try(asc_main_rollout.btn_restart != undefined)catch(false)) "Restart control is missing at runtime."
    requireObjectLayerManagerTest (try(asc_main_rollout.btn_restart.pos.y > asc_main_rollout.hierarchy_slot.pos.y)catch(false)) "Restart control is not positioned below the hierarchy."
    requireObjectLayerManagerTest (asc_main_rollout.title == "Object-Layer-Manager | v0.082") "Rollout title does not match the literal declaration."

    true
    -- return
)

partOfTest1()
partOfTest2()
partOfTest3()

format "\nOBJECT LAYER MANAGER TEST PASSED\n"
format "The test performs one UI load only. Run Object-Layer-Manager.ms again manually after this test to verify normal reload replacement.\n"
format "Undo order: none. This test does not modify scene geometry.\n"
