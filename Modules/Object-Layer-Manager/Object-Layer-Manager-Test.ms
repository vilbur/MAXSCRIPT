/*
Object Layer Manager Test 0.074
Performs source-level crash-safety checks, then loads the canonical tool once for a safe smoke test.
*/

global object_layer_manager_test_source = getSourceFileName()
global object_layer_manager_test_file_version = 0.074
global object_layer_manager_test_project_version = 0.084

struct objectLayerManagerTestRolloutState_v
(
    open = true
)

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
    requireObjectLayerManagerTest ((findString source_text "rollout asc_main_rollout \"Object-Layer-Manager | v0.084\"") != undefined) "Main rollout does not use the literal crash-safe title."
    requireObjectLayerManagerTest ((findString source_text "object_layer_manager_rollout_title") == undefined) "Pre-rollout dynamic title resolution is still present."
    requireObjectLayerManagerTest ((findString source_text "asc_main_rollout.title =") == undefined) "Unsafe rollout title mutation is present."
    requireObjectLayerManagerTest ((findString source_text "dotNetControl btn_add_default \"System.Windows.Forms.Button\"") != undefined) "Default .NET layer button is missing."
    requireObjectLayerManagerTest ((findString source_text "rollout_creator.addControl #dotNetControl #btn_add_selection \"System.Windows.Forms.Button\"") != undefined) "Generated branch .NET layer button is missing."
    requireObjectLayerManagerTest ((findString source_text "function ascApplyLayerButtonFont") != undefined) "Per-control layer-button font helper is missing."
    requireObjectLayerManagerTest ((findString source_text "global asc_layer_button_font") == undefined) "Unsafe shared disposable layer-button Font global is still present."
    requireObjectLayerManagerTest ((findString source_text "function ascApplyLayerButtonStyle") != undefined) "Dark .NET layer-button style helper is missing."
    requireObjectLayerManagerTest ((findString source_text "UseVisualStyleBackColor = false") != undefined) "Dark .NET layer buttons still use the Windows visual-style background."
    requireObjectLayerManagerTest ((findString source_text "BackColor = color_class.FromArgb 52 52 52") != undefined) "Dark .NET layer-button background is missing."
    requireObjectLayerManagerTest ((findString source_text "function ascApplyLayerButtonStyle button_control grayed:false") != undefined) "Layer-button style helper does not support grayed scene state."
    requireObjectLayerManagerTest ((findString source_text "BackColor = color_class.FromArgb 68 68 68") != undefined) "Hidden/off layer-button gray background is missing."
    requireObjectLayerManagerTest ((findString source_text "ForeColor = color_class.FromArgb 145 145 145") != undefined) "Hidden/off layer-button gray text is missing."
    requireObjectLayerManagerTest ((findString source_text "function ascIsLayerButtonGrayed") != undefined) "Layer-button scene-state resolver is missing."
    requireObjectLayerManagerTest ((findString source_text "button_is_grayed = (not scene_layer.on) or scene_layer.isHidden") != undefined) "Layer-button grayed state does not reflect layer ON/hidden state."
    requireObjectLayerManagerTest ((findString source_text "function ascRefreshLayerButtonSceneStates") != undefined) "Layer-button scene-state refresh helper is missing."
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
    requireObjectLayerManagerTest ((findString source_text "visibility_chain = ascGetLayerVisibilityChain layer_name") != undefined) "RMB visibility action does not collect the clicked layer and ancestor chain."
    requireObjectLayerManagerTest ((findString source_text "target_layer.isHidden = true") != undefined) "RMB hide path does not hide only the clicked layer."
    requireObjectLayerManagerTest ((findString source_text "chain_layer.isHidden = false") != undefined) "RMB show path does not unhide the clicked layer and required ancestors."
    requireObjectLayerManagerTest ((findString source_text "chain_layer.isHidden = hide_chain") == undefined) "RMB still writes one hide state across the whole ancestor chain."
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
    requireObjectLayerManagerTest ((findString source_text "function ascSyncManagerRolloutTreeToScene") != undefined) "Manager-to-scene rollout sync helper is missing."
    requireObjectLayerManagerTest ((findString source_text "scene_layer.on = rollout_definition.open") != undefined) "Manager-to-scene sync does not map open rollout to layer ON."
    requireObjectLayerManagerTest ((findString source_text "function ascSyncAllSceneBranchStatesToMemory") != undefined) "Scene-to-manager all-branch memory sync helper is missing."
    requireObjectLayerManagerTest ((findString source_text "scene_layer.getNumChildren() > 0") != undefined) "Scene-to-manager memory sync does not limit stored rollout state to branch layers."
    requireObjectLayerManagerTest ((findString source_text "function ascSyncSceneLayerTreeToManager") != undefined) "Scene-to-manager rollout sync helper is missing."
    requireObjectLayerManagerTest ((findString source_text "desired_open = scene_layer.on") != undefined) "Scene-to-manager sync does not map layer ON to rollout openness."
    requireObjectLayerManagerTest ((findString source_text "rollout_definition.open = desired_open") != undefined) "Scene-to-manager sync does not update rollout open state."
    requireObjectLayerManagerTest ((findString source_text "ascSetLayerRolloutOpenState layer_name scene_layer.on save_state:false") != undefined) "Scene-to-manager sync does not update remembered rollout state in batch mode."
    requireObjectLayerManagerTest ((findString source_text "button btn_sync_layers \"Sync\"") != undefined) "Sync button is missing."
    requireObjectLayerManagerTest ((findString source_text "on btn_sync_layers pressed do") != undefined) "Sync LMB handler is missing."
    requireObjectLayerManagerTest ((findString source_text "syncManagerToScene()") != undefined) "Sync LMB does not drive manager state into scene layers."
    requireObjectLayerManagerTest ((findString source_text "on btn_sync_layers rightclick do") != undefined) "Sync RMB handler is missing."
    requireObjectLayerManagerTest ((findString source_text "syncSceneToManager()") != undefined) "Sync RMB does not drive scene-layer state into the manager."
    requireObjectLayerManagerTest ((findString source_text "Show/Hide Layer (Parents on Show)") != undefined) "Layer context-menu visibility label does not describe the parent-chain action."
    requireObjectLayerManagerTest ((findString source_text "RMB: Hide this layer only; show it with its parent chain.") != undefined) "Generated layer-button RMB parent-chain tooltip is missing."
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
    requireObjectLayerManagerTest (object_layer_manager_file_version >= 0.084) "Expected file version 0.084 or newer."
    requireObjectLayerManagerTest (try(asc_main_rollout.btn_add_default.GetType().FullName == "System.Windows.Forms.Button")catch(false)) "Default control is not a Windows Forms Button."
    requireObjectLayerManagerTest (try(asc_main_rollout.btn_add_default.BackColor.R < 100)catch(false)) "Default .NET layer button background is not dark."
    requireObjectLayerManagerTest (try(asc_main_rollout.btn_add_default.FlatAppearance.BorderSize == 0)catch(false)) "Default .NET layer button still has a visible border."
    requireObjectLayerManagerTest (try(asc_main_rollout.btn_refresh_layers.pos.y == asc_main_rollout.btn_create_layer.pos.y)catch(false)) "Refresh and New Layer are not on the same top row."
    requireObjectLayerManagerTest (try(asc_main_rollout.btn_refresh_layers.width == asc_main_rollout.btn_create_layer.width)catch(false)) "Refresh and New Layer do not use equal widths."
    requireObjectLayerManagerTest (try(asc_main_rollout.btn_sync_layers != undefined)catch(false)) "Sync control is missing at runtime."
    requireObjectLayerManagerTest (try(asc_main_rollout.btn_sync_layers.width == 240)catch(false)) "Sync control is not full width."
    requireObjectLayerManagerTest (try(asc_main_rollout.btn_sync_layers.pos.y > asc_main_rollout.btn_refresh_layers.pos.y)catch(false)) "Sync control is not below the top action row."
    requireObjectLayerManagerTest (try(asc_main_rollout.btn_restart != undefined)catch(false)) "Restart control is missing at runtime."
    requireObjectLayerManagerTest (try(asc_main_rollout.btn_restart.pos.y > asc_main_rollout.hierarchy_slot.pos.y)catch(false)) "Restart control is not positioned below the hierarchy."
    requireObjectLayerManagerTest (asc_main_rollout.title == "Object-Layer-Manager | v0.084") "Rollout title does not match the literal declaration."

    true
    -- return
)

/*
Creates a real four-layer hierarchy and verifies sibling visibility isolation for RMB.
The uniquely named test tree remains in the scene for visual inspection and can be removed by undoing the test stages.
*/
function partOfTest4 =
(
    local suffix_index = 1
    local name_prefix = ""
    local top_name = ""
    local parent_name = ""
    local layer_a_name = ""
    local layer_b_name = ""
    local top_layer = undefined
    local parent_layer = undefined
    local layer_a = undefined
    local layer_b = undefined
    local parent_set = false
    local visibility_chain = #()

    while top_name == "" do
    (
        name_prefix = "__OLM_VIS_TEST_" + (suffix_index as string) + "_"
        top_name = name_prefix + "TOP-LAYER"
        parent_name = name_prefix + "PARENT-LAYER"
        layer_a_name = name_prefix + "LAYER-A"
        layer_b_name = name_prefix + "LAYER-B"

        if (layerManager.getLayerFromName top_name != undefined) or \
           (layerManager.getLayerFromName parent_name != undefined) or \
           (layerManager.getLayerFromName layer_a_name != undefined) or \
           (layerManager.getLayerFromName layer_b_name != undefined) then
        (
            top_name = ""
            suffix_index += 1
        )
    )

    undo "OLM Test: Create Visibility Tree" on
    (
        top_layer = layerManager.newLayerFromName top_name
        parent_layer = layerManager.newLayerFromName parent_name
        layer_a = layerManager.newLayerFromName layer_a_name
        layer_b = layerManager.newLayerFromName layer_b_name

        requireObjectLayerManagerTest (top_layer != undefined) "Could not create TOP-LAYER test layer."
        requireObjectLayerManagerTest (parent_layer != undefined) "Could not create PARENT-LAYER test layer."
        requireObjectLayerManagerTest (layer_a != undefined) "Could not create LAYER-A test layer."
        requireObjectLayerManagerTest (layer_b != undefined) "Could not create LAYER-B test layer."

        parent_set = try(parent_layer.setParent top_layer)catch(false)
        requireObjectLayerManagerTest parent_set "Could not parent PARENT-LAYER under TOP-LAYER."

        parent_set = try(layer_a.setParent parent_layer)catch(false)
        requireObjectLayerManagerTest parent_set "Could not parent LAYER-A under PARENT-LAYER."

        parent_set = try(layer_b.setParent parent_layer)catch(false)
        requireObjectLayerManagerTest parent_set "Could not parent LAYER-B under PARENT-LAYER."

        top_layer.isHidden = false
        parent_layer.isHidden = false
        layer_a.isHidden = false
        layer_b.isHidden = false
    )

    requireObjectLayerManagerTest (try((parent_layer.getParent()).name == top_name)catch(false)) "PARENT-LAYER is not under TOP-LAYER."
    requireObjectLayerManagerTest (try((layer_a.getParent()).name == parent_name)catch(false)) "LAYER-A is not under PARENT-LAYER."
    requireObjectLayerManagerTest (try((layer_b.getParent()).name == parent_name)catch(false)) "LAYER-B is not under PARENT-LAYER."

    visibility_chain = ascGetLayerVisibilityChain layer_b_name
    requireObjectLayerManagerTest (visibility_chain.count == 3) "LAYER-B visibility chain must contain exactly LAYER-B, PARENT-LAYER, and TOP-LAYER."
    requireObjectLayerManagerTest (visibility_chain[1].name == layer_b_name) "Visibility chain does not start at LAYER-B."
    requireObjectLayerManagerTest (visibility_chain[2].name == parent_name) "Visibility chain second item is not PARENT-LAYER."
    requireObjectLayerManagerTest (visibility_chain[3].name == top_name) "Visibility chain third item is not TOP-LAYER."
    requireObjectLayerManagerTest ((findItem (for chain_layer in visibility_chain collect chain_layer.name) layer_a_name) == 0) "Sibling LAYER-A leaked into LAYER-B visibility chain."

    requireObjectLayerManagerTest (ascToggleLayerVisibility layer_b_name) "RMB helper failed while hiding LAYER-B."
    requireObjectLayerManagerTest layer_b.isHidden "LAYER-B was not hidden."
    requireObjectLayerManagerTest (not layer_a.isHidden) "Hiding LAYER-B changed sibling LAYER-A visibility."
    requireObjectLayerManagerTest (not parent_layer.isHidden) "Hiding LAYER-B must not hide PARENT-LAYER."
    requireObjectLayerManagerTest (not top_layer.isHidden) "Hiding LAYER-B must not hide TOP-LAYER."

    requireObjectLayerManagerTest (ascToggleLayerVisibility layer_b_name) "RMB helper failed while showing LAYER-B."
    requireObjectLayerManagerTest (not layer_b.isHidden) "LAYER-B was not shown."
    requireObjectLayerManagerTest (not layer_a.isHidden) "Showing LAYER-B changed visible sibling LAYER-A."
    requireObjectLayerManagerTest (not parent_layer.isHidden) "Showing LAYER-B did not leave PARENT-LAYER visible."
    requireObjectLayerManagerTest (not top_layer.isHidden) "Showing LAYER-B did not leave TOP-LAYER visible."

    undo "OLM Test: Seed Hidden Parent" on
    (
        layer_a.isHidden = true
        parent_layer.isHidden = true
        layer_b.isHidden = false
    )

    requireObjectLayerManagerTest (ascToggleLayerVisibility layer_b_name) "RMB helper failed while restoring a blocked LAYER-B."
    requireObjectLayerManagerTest (not layer_b.isHidden) "Blocked LAYER-B was not shown."
    requireObjectLayerManagerTest (not parent_layer.isHidden) "Showing blocked LAYER-B did not unhide PARENT-LAYER."
    requireObjectLayerManagerTest (not top_layer.isHidden) "Showing blocked LAYER-B did not keep TOP-LAYER visible."
    requireObjectLayerManagerTest layer_a.isHidden "Showing LAYER-B changed hidden sibling LAYER-A."

    requireObjectLayerManagerTest (ascToggleLayerVisibility layer_b_name) "RMB helper failed on the second LAYER-B hide."
    requireObjectLayerManagerTest layer_b.isHidden "Second LAYER-B hide did not hide LAYER-B."
    requireObjectLayerManagerTest layer_a.isHidden "Second LAYER-B hide changed hidden sibling LAYER-A."
    requireObjectLayerManagerTest (not parent_layer.isHidden) "Second LAYER-B hide changed PARENT-LAYER."
    requireObjectLayerManagerTest (not top_layer.isHidden) "Second LAYER-B hide changed TOP-LAYER."

    undo "OLM Test: Restore Visibility Tree" on
    (
        top_layer.isHidden = false
        parent_layer.isHidden = false
        layer_a.isHidden = false
        layer_b.isHidden = false
    )

    format "Visibility test tree left for inspection: % > % > (% / %)\\n" top_name parent_name layer_a_name layer_b_name

    true
    -- return
)

/*
Verifies bidirectional layer ON/rollout-state mapping and gray button scene-state feedback.
The test uses a lightweight rollout-state struct with the verified .open property so mapping logic can be exercised without opening an extra dialog.
*/
function partOfTest5 =
(
    local suffix_index = 1
    local sync_layer_name = ""
    local sync_layer = undefined
    local mock_rollout = objectLayerManagerTestRolloutState_v()
    local mock_tree = undefined
    local test_button = dotNetObject "System.Windows.Forms.Button"

    while sync_layer_name == "" do
    (
        sync_layer_name = "__OLM_SYNC_TEST_" + (suffix_index as string)

        if layerManager.getLayerFromName sync_layer_name != undefined then
        (
            sync_layer_name = ""
            suffix_index += 1
        )
    )

    undo "OLM Test: Create Sync Layer" on
    (
        sync_layer = layerManager.newLayerFromName sync_layer_name
        requireObjectLayerManagerTest (sync_layer != undefined) "Could not create sync test layer."
        sync_layer.on = true
        sync_layer.isHidden = false
    )

    mock_tree = #(mock_rollout, #(), sync_layer_name)

    mock_rollout.open = false
    undo "OLM Test: Manager To Scene OFF" on
    (
        requireObjectLayerManagerTest ((ascSyncManagerRolloutTreeToScene mock_tree) == 1) "Manager-to-scene sync did not process the test layer."
    )
    requireObjectLayerManagerTest (not sync_layer.on) "Rolled-up manager state did not switch the scene layer OFF."

    mock_rollout.open = true
    undo "OLM Test: Manager To Scene ON" on
    (
        requireObjectLayerManagerTest ((ascSyncManagerRolloutTreeToScene mock_tree) == 1) "Manager-to-scene sync did not process the open test rollout."
    )
    requireObjectLayerManagerTest sync_layer.on "Open manager rollout did not switch the scene layer ON."

    undo "OLM Test: Seed Scene OFF" on
    (
        sync_layer.on = false
    )
    requireObjectLayerManagerTest ((ascSyncSceneLayerTreeToManager mock_tree) == 1) "Scene-to-manager sync did not process the OFF test layer."
    requireObjectLayerManagerTest (not mock_rollout.open) "Scene layer OFF did not roll up the manager state."
    requireObjectLayerManagerTest (not (ascGetLayerRolloutOpenState sync_layer_name)) "Scene layer OFF was not stored as a closed rollout state."

    undo "OLM Test: Seed Scene ON" on
    (
        sync_layer.on = true
    )
    requireObjectLayerManagerTest ((ascSyncSceneLayerTreeToManager mock_tree) == 1) "Scene-to-manager sync did not process the ON test layer."
    requireObjectLayerManagerTest mock_rollout.open "Scene layer ON did not open the manager state."
    requireObjectLayerManagerTest (ascGetLayerRolloutOpenState sync_layer_name) "Scene layer ON was not stored as an open rollout state."

    requireObjectLayerManagerTest (not (ascIsLayerButtonGrayed sync_layer_name)) "Visible ON layer is incorrectly marked gray."
    ascApplyLayerButtonStyle test_button grayed:(ascIsLayerButtonGrayed sync_layer_name)
    requireObjectLayerManagerTest (test_button.ForeColor.R == 235) "Visible ON layer button does not use normal text color."

    undo "OLM Test: Seed Hidden Sync Layer" on
    (
        sync_layer.isHidden = true
    )
    requireObjectLayerManagerTest (ascIsLayerButtonGrayed sync_layer_name) "Hidden layer is not marked gray."
    ascApplyLayerButtonStyle test_button grayed:(ascIsLayerButtonGrayed sync_layer_name)
    requireObjectLayerManagerTest (test_button.ForeColor.R == 145) "Hidden layer button does not use gray text color."

    undo "OLM Test: Restore Sync Layer" on
    (
        sync_layer.on = true
        sync_layer.isHidden = false
    )

    format "Sync test layer left for inspection: %\n" sync_layer_name

    true
    -- return
)

partOfTest1()
partOfTest2()
partOfTest3()
partOfTest4()
partOfTest5()

format "\nOBJECT LAYER MANAGER TEST PASSED\n"
format "The test performs one UI load, the real sibling-visibility tree regression, and bidirectional layer ON/rollout sync checks.\n"
format "Undo order includes Restore Sync Layer, hidden/ON sync seeds, manager-to-scene ON/OFF, Create Sync Layer, then the visibility-tree stages.\n"
