/*
Spline Editor - compact 144-pixel frontend with native controls.
File version: 0.003 | Project version: 0.004
*/

global spline_editor_ui_file_version = "0.003"
global spline_editor_project_version
if spline_editor_project_version == undefined then
(
    spline_editor_project_version = "0.004"
)

rollout splineEditorRollout ("Spline Editor - v" + spline_editor_project_version) width:144 height:432
(
    dotNetControl btn_tool_title "System.Windows.Forms.Button" width:120 height:18 pos:[12,12]
    dropdownList ddl_section "" items:#("Visibility", "Knots", "Segments", "Splines", "Material IDs") width:120 height:24 pos:[12,48] tooltip:"Select a group of spline editing controls. All operations remain available."

    -- Visibility section
    button btn_hide_selected "Hide Selected" width:120 height:24 pos:[12,96] tooltip:"Hide selected spline sub-objects."
    button btn_hide_unselected "Hide Unselected" width:120 height:24 pos:[12,132] tooltip:"Hide the inverse of the current selection, then restore its IDs."
    button btn_unhide_all "Unhide All" width:120 height:24 pos:[12,168] tooltip:"Reveal hidden spline segments."

    -- Knots section
    button btn_fuse "Fuse" width:120 height:24 pos:[12,96] tooltip:"Move selected knots to their average position without joining them."
    button btn_weld "Weld" width:120 height:24 pos:[12,132] tooltip:"Weld selected knots using the distance below."
    spinner spn_weld_threshold "Dist" range:[0.0,1000000.0,0.0] type:#float fieldWidth:72 width:120 height:24 pos:[12,168] tooltip:"Weld distance, in 3ds Max system units. Zero is exact."
    button btn_cross_insert "Cross Insert" width:120 height:24 pos:[12,204] tooltip:"Start native viewport Cross Insert. Use the Modify panel for its threshold."
    spinner spn_cross_threshold "Threshold" range:[0.0,1000000.0,0.0] type:#float fieldWidth:48 width:120 height:24 pos:[12,240] enabled:false tooltip:"Not exposed by native MAXScript; adjust this threshold in the Modify panel."
    label lbl_cross_hint "Cross threshold:\nModify panel only" width:120 height:36 pos:[12,276]

    -- Segments section
    label lbl_divide_presets "Divide presets" width:120 height:24 pos:[12,96]
    radioButtons rb_divide_preset "" labels:#("1", "2", "3", "4", "6", "8") default:1 columns:3 pos:[12,120] width:120 height:52
    spinner spn_divide_count "Count" range:[1,100,1] type:#integer fieldWidth:48 width:120 height:24 pos:[12,192] tooltip:"Number of evenly spaced knots to add per selected segment."
    button btn_divide "Divide" width:120 height:24 pos:[12,228] tooltip:"Divide selected segments, preserving other segments."

    -- Splines section
    button btn_attach_pick "Attach Pick" width:120 height:24 pos:[12,96] tooltip:"Start native viewport Attach mode."
    button btn_attach_multiple "Attach Multiple" width:120 height:24 pos:[12,132] tooltip:"Open native Attach Multiple dialog."
    button btn_attach_selected "Attach Selected" width:120 height:24 pos:[12,168] tooltip:"Attach selected Editable Spline objects into selection[1]."
    button btn_detach_dialog "Detach Dialog" width:120 height:24 pos:[12,204] tooltip:"Open native Detach dialog for selected spline sub-objects."
    button btn_explode "Explode" width:120 height:24 pos:[12,240] tooltip:"Explode selected splines using native options."
    button btn_detach_object "Detach to Object" width:120 height:24 pos:[12,276] tooltip:"Move selected whole splines to a new object."
    button btn_detach_object_copy "Object Clone" width:120 height:24 pos:[12,312] tooltip:"Copy selected whole splines into a new object without removing originals."
    button btn_detach_spline_copy "Spline Copy Inside" width:120 height:24 pos:[12,348] tooltip:"Copy selected whole splines as new sub-splines inside the current object."

    -- Material IDs section
    label lbl_ids "Sequential from 1" width:120 height:24 pos:[12,96]
    radioButtons rb_id_scope "" labels:#("Selected splines", "All splines") default:1 columns:1 pos:[12,132] width:120 height:48
    button btn_assign_ids "Assign Material IDs" width:120 height:24 pos:[12,204] tooltip:"Assign one ID per spline, starting at 1, applied to each segment."

    label lbl_status "Ready." width:120 height:36 pos:[12,384]

    /*
    Displays only the chosen section so every control fits a 144-pixel dialog.
    */
    function showSection section_index =
    (
        local visibility_section = section_index == 1
        local knots_section = section_index == 2
        local segments_section = section_index == 3
        local splines_section = section_index == 4
        local ids_section = section_index == 5

        btn_hide_selected.visible = visibility_section
        btn_hide_unselected.visible = visibility_section
        btn_unhide_all.visible = visibility_section

        btn_fuse.visible = knots_section
        btn_weld.visible = knots_section
        spn_weld_threshold.visible = knots_section
        btn_cross_insert.visible = knots_section
        spn_cross_threshold.visible = knots_section
        lbl_cross_hint.visible = knots_section

        lbl_divide_presets.visible = segments_section
        rb_divide_preset.visible = segments_section
        spn_divide_count.visible = segments_section
        btn_divide.visible = segments_section

        btn_attach_pick.visible = splines_section
        btn_attach_multiple.visible = splines_section
        btn_attach_selected.visible = splines_section
        btn_detach_dialog.visible = splines_section
        btn_explode.visible = splines_section
        btn_detach_object.visible = splines_section
        btn_detach_object_copy.visible = splines_section
        btn_detach_spline_copy.visible = splines_section

        lbl_ids.visible = ids_section
        rb_id_scope.visible = ids_section
        btn_assign_ids.visible = ids_section
        true
    )

    /*
    Loads tool-specific control settings from the stable script-local INI.
    */
    function loadUiState =
    (
        RolloutState.loadSpinner spn_weld_threshold spline_editor_ini_path "Actions" "WeldDistance" default_value:0.0
        RolloutState.loadSpinner spn_divide_count spline_editor_ini_path "Actions" "DivideCount" default_value:1.0
        local divide_preset = IniSettings.getInteger spline_editor_ini_path "Actions" "DividePreset" default_value:1
        if divide_preset >= 1 and divide_preset <= 6 then
        (
            rb_divide_preset.state = divide_preset
        )
        local id_scope = IniSettings.getInteger spline_editor_ini_path "Actions" "MaterialIDScope" default_value:1
        if id_scope >= 1 and id_scope <= 2 then
        (
            rb_id_scope.state = id_scope
        )
        RolloutState.loadDropdown ddl_section spline_editor_ini_path "MainUI" "SelectedSection" default_value:1
    )

    /*
    Saves the editable controls with the shared persistent settings helpers.
    */
    function saveUiState =
    (
        RolloutState.saveDropdown ddl_section spline_editor_ini_path "MainUI" "SelectedSection"
        RolloutState.saveSpinner spn_weld_threshold spline_editor_ini_path "Actions" "WeldDistance"
        RolloutState.saveSpinner spn_divide_count spline_editor_ini_path "Actions" "DivideCount"
        IniSettings.setInteger spline_editor_ini_path "Actions" "DividePreset" rb_divide_preset.state
        IniSettings.setInteger spline_editor_ini_path "Actions" "MaterialIDScope" rb_id_scope.state
        true
        -- return
    )

    /*
    Executes one validated backend operation and displays its real completion status.
    Native interactive modes report that they were entered, not that editing finished.
    */
    function runAction action_key =
    (
        local operation_ok = false
        local native_action = findItem #(#crossInsert, #attachPick, #attachMultiple, #detachDialog) action_key > 0
        if native_action then
        (
            operation_ok = case action_key of
            (
                #crossInsert: (SplineEditor.startCrossInsert())
                #attachPick: (SplineEditor.startNativeAction #attach)
                #attachMultiple: (SplineEditor.startNativeAction #attachMultiple)
                #detachDialog: (SplineEditor.startNativeAction #detachDialog)
                default: false
            )
        )
        else
        (
            undo "Spline Editor - Geometry Action" on
            (
                operation_ok = case action_key of
                (
                    #hideSelected: (SplineEditor.hideSelected())
                    #hideUnselected: (SplineEditor.hideUnselected())
                    #unhideAll: (SplineEditor.unhideAll())
                    #fuse: (SplineEditor.editKnots #fuse)
                    #weld: (SplineEditor.editKnots #weld weld_threshold:spn_weld_threshold.value)
                    #divide: (SplineEditor.divideSelected spn_divide_count.value)
                    #attachSelected: (SplineEditor.attachSelectedObjects())
                    #explode: (SplineEditor.explodeSelected())
                    #detachObject: (SplineEditor.detachToObject false)
                    #detachObjectCopy: (SplineEditor.detachToObject true)
                    #detachSplineCopy: (SplineEditor.duplicateSplinesInside())
                    #materialIDs: (SplineEditor.assignSplineMaterialIDs all_splines:(rb_id_scope.state == 2))
                    default: false
                )
            )
        )
        lbl_status.text = if operation_ok then (if native_action then "Native mode started." else "Done: " + (action_key as string)) else "No edit. See Listener."
        operation_ok
        -- return
    )

    on splineEditorRollout open do
    (
        ToolTitleButton.setupToolTitleButton btn_tool_title "Spline Editor"
        ToolTitleButton.resizeToolTitleButton btn_tool_title (splineEditorRollout.width - 24)
        loadUiState()
        showSection ddl_section.selection
    )
    on splineEditorRollout moved dialog_pos do
    (
        DialogHost.saveDialogPosition splineEditorRollout spline_editor_ini_path "MainUI"
    )
    on splineEditorRollout resized dialog_size do
    (
        ToolTitleButton.resizeToolTitleButton btn_tool_title (dialog_size.x - 24)
        DialogHost.saveDialogHeight splineEditorRollout spline_editor_ini_path "MainUI" min_height:432
    )
    on splineEditorRollout close do
    (
        saveUiState()
        DialogHost.saveDialogState splineEditorRollout spline_editor_ini_path "MainUI" min_height:432
    )
    on btn_tool_title Click sender event_args do
    (
        restartTool spline_editor_entry_path "Spline-Editor"
    )
    on ddl_section selected section_index do
    (
        showSection section_index
        saveUiState()
    )
    on rb_divide_preset changed state do
    (
        local preset_counts = #(1,2,3,4,6,8)
        spn_divide_count.value = preset_counts[state]
        saveUiState()
    )
    on spn_divide_count changed new_value do
    (
        local preset_counts = #(1,2,3,4,6,8)
        local matched_index = findItem preset_counts new_value
        if matched_index > 0 then
        (
            rb_divide_preset.state = matched_index
        )
        saveUiState()
    )
    on spn_weld_threshold changed new_value do
    (
        saveUiState()
    )
    on rb_id_scope changed state do
    (
        saveUiState()
    )
    on btn_hide_selected pressed do
    (
        runAction #hideSelected
    )
    on btn_hide_unselected pressed do
    (
        runAction #hideUnselected
    )
    on btn_unhide_all pressed do
    (
        runAction #unhideAll
    )
    on btn_fuse pressed do
    (
        runAction #fuse
    )
    on btn_weld pressed do
    (
        runAction #weld
    )
    on btn_cross_insert pressed do
    (
        runAction #crossInsert
    )
    on btn_divide pressed do
    (
        runAction #divide
    )
    on btn_attach_pick pressed do
    (
        runAction #attachPick
    )
    on btn_attach_multiple pressed do
    (
        runAction #attachMultiple
    )
    on btn_attach_selected pressed do
    (
        runAction #attachSelected
    )
    on btn_detach_dialog pressed do
    (
        runAction #detachDialog
    )
    on btn_explode pressed do
    (
        runAction #explode
    )
    on btn_detach_object pressed do
    (
        runAction #detachObject
    )
    on btn_detach_object_copy pressed do
    (
        runAction #detachObjectCopy
    )
    on btn_detach_spline_copy pressed do
    (
        runAction #detachSplineCopy
    )
    on btn_assign_ids pressed do
    (
        runAction #materialIDs
    )
)

/*
Opens the native shared-host dialog with left/right docking and INI persistence.
*/
function splineEditorShowDialog =
(
    DialogHost.createManagedDialog splineEditorRollout spline_editor_ini_path "MainUI" tool_key:"Spline-Editor" default_width:144 default_height:432 min_height:432
    windows.processPostedMessages()
    true
    -- return
)
