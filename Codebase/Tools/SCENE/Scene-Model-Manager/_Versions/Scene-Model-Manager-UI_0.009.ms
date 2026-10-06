/*
Scene Model Manager UI.
File version: 0.009
Project version: 0.009
*/

global scene_model_manager_rollout
global scene_model_manager_prepare_rollout
global scene_model_manager_nodes_rollout
global scene_model_manager_export_rollout
global scene_model_manager_title
global scene_model_manager_restart_file

if (scene_model_manager_project_version == undefined or scene_model_manager_project_version < 0.009) then
(
    scene_model_manager_project_version = 0.009
)

scene_model_manager_title = "SCENE MODEL MANAGER " + (scene_model_manager_project_version as string)
scene_model_manager_restart_file = getFilenamePath (getSourceFileName()) + "Scene-Model-Manager.ms"

/*
Reloads the canonical Toolset entry file from the current package directory.
This is shared by the RESTART button and F1 help callback.
*/
function restartSceneModelManager =
(
    if doesFileExist scene_model_manager_restart_file then
    (
        fileIn scene_model_manager_restart_file
        true
    )
    else
    (
        messageBox ("Scene Model Manager entry file not found:\n\n" + scene_model_manager_restart_file) title:"Scene Model Manager"
        false
    )
    -- return
)

rollout scene_model_manager_prepare_rollout "1. PREPARE SCENE" width:192 height:372
(
    label lbl_units "System:" pos:[12,12] width:72 height:24
    label lbl_units_value "-" pos:[84,12] width:96 height:24
    label lbl_display "Display:" pos:[12,36] width:72 height:24
    label lbl_display_value "-" pos:[84,36] width:96 height:24

    button btn_convert_units "1. CONVERT 1mm -> 1m" pos:[12,72] width:168 height:24 \
        toolTip:"LMB: Reset to a clean 1 meter scene and Merge the saved 1 mm source with native unit rescaling."

    button btn_display_cm "2. SET DISPLAY = cm" pos:[12,108] width:168 height:24
    button btn_outliers "3. OUTLIERS  SELECT / DELETE" pos:[12,144] width:168 height:24 \
        toolTip:"LMB: Select outlier candidates for visual review.\n\nRMB: Delete the candidates found by the last LMB scan after confirmation."

    button btn_center_pivots "4. CENTER PIVOTS" pos:[12,180] width:168 height:24 \
        toolTip:"LMB: Center pivots on selected geometry, or all geometry when nothing is selected.\n\nModifier stacks are not collapsed."

    label lbl_scene_position "5. SCENE POSITION" pos:[12,216] width:168 height:24
    radioButtons rdo_scene_position "" labels:#("REAL-WORLD", "OFFSET TO ORIGIN") default:1 columns:1 pos:[12,240]

    label lbl_prepare_status "Ready." pos:[12,300] width:168 height:60

    local offset_state_syncing = false

    /*
    Refreshes source-unit labels from the currently loaded scene.
    UI formatting never changes the underlying scene values.
    */
    function refreshPrepareState =
    (
        lbl_units_value.text = (units.SystemScale as string) + " " + (units.SystemType as string)
        lbl_display_value.text = units.DisplayType as string

        offset_state_syncing = true

        if SceneModelManager.isOffsetActive() then
        (
            rdo_scene_position.state = 2
            lbl_prepare_status.text = "Editing offset is ACTIVE. Scene is working near origin."
        )
        else
        (
            rdo_scene_position.state = 1
            lbl_prepare_status.text = "Editing offset is inactive."
        )

        offset_state_syncing = false
    )

    on scene_model_manager_prepare_rollout open do
    (
        refreshPrepareState()
    )

    on btn_convert_units pressed do
    (
        lbl_prepare_status.text = "Opening native Merge unit conversion..."
        windows.processPostedMessages()
        conversion_ok = SceneModelManager.convertSystemUnitsMmToMetersByMerge()
        refreshPrepareState()

        if conversion_ok then lbl_prepare_status.text = "Merge finished. Save this meter-based working scene under a new name."
    )

    on btn_display_cm pressed do
    (
        SceneModelManager.setEditingDisplayCentimeters()
        refreshPrepareState()
        lbl_prepare_status.text = "Display Units set to centimeters. System Units were not changed."
    )

    on btn_outliers pressed do
    (
        candidate_nodes = SceneModelManager.findOutlierCandidates()
        lbl_prepare_status.text = (candidate_nodes.count as string) + " outlier candidate(s) selected for visual review."
    )

    on btn_outliers rightclick do
    (
        if SceneModelManager.outlier_handles.count == 0 then
        (
            lbl_prepare_status.text = "LMB first to find and select outlier candidates."
        )
        else
        (
            delete_ok = queryBox \
                ("Delete the " + (SceneModelManager.outlier_handles.count as string) + " previously found outlier candidate(s)?") \
                title:"Scene Model Manager"

            if delete_ok then
            (
                delete_result = SceneModelManager.deleteFoundOutliers()
                lbl_prepare_status.text = "Deleted: " + (delete_result[1] as string) + " | Missing: " + (delete_result[2] as string)
            )
        )
    )

    on btn_center_pivots pressed do
    (
        result_value = SceneModelManager.centerObjectPivots()
        lbl_prepare_status.text = result_value[2]
    )

    on rdo_scene_position changed state_index do
    (
        if not offset_state_syncing then
        (
            if state_index == 2 then
            (
                result_value = SceneModelManager.offsetSceneToWorkOrigin()
            )
            else
            (
                result_value = SceneModelManager.restoreSceneOffset()
            )

            refreshPrepareState()
            lbl_prepare_status.text = result_value[2]
        )
    )
)

rollout scene_model_manager_nodes_rollout "2. MODEL NODES" width:192 height:576
(
    listBox lb_model_nodes "MODEL NODES" pos:[12,12] width:168 height:7

    editText edt_name "Name:" pos:[12,144] width:168 height:24
    spinner spn_ratio "Ratio 1:" pos:[12,180] width:168 height:24 type:#integer range:[1,1000000,150] scale:1
    spinner spn_text_size "Text cm:" pos:[12,216] width:168 height:24 type:#float range:[1.0,100000.0,100.0] scale:1.0
    button btn_refresh_nodes "REFRESH LIST" pos:[12,252] width:168 height:24

    button btn_create_node "CREATE FROM SELECTION" pos:[12,288] width:168 height:24 \
        toolTip:"LMB: Create a visible MODEL NODE Text object at the selected objects' bounding-box center.\n\nCurrent selection becomes the initial membership."
    button btn_update_node "UPDATE NODE" pos:[12,324] width:168 height:24

    button btn_add_members "ADD" pos:[12,360] width:72 height:24
    button btn_remove_members "REMOVE" pos:[96,360] width:72 height:24

    button btn_select_members "SELECT MEMBERS" pos:[12,396] width:168 height:24

    button btn_set_ortho "SET ORTHO DIRECTION" pos:[12,432] width:168 height:24 \
        toolTip:"LMB: Pick an XY direction from the MODEL NODE position.\n\nThe Text orientation shows the stored source direction."

    button btn_ortho_view "ORTHO" pos:[12,468] width:72 height:24 \
        toolTip:"LMB: Rotate the complete editing scene through the selected MODEL NODE pivot.\n\nMODEL NODE membership only controls export, not what rotates."
    button btn_original_view "ORIGINAL" pos:[96,468] width:72 height:24 \
        toolTip:"LMB: Return the editing scene from the active ORTHO frame to original orientation."

    label lbl_node_status "Ready." pos:[12,504] width:168 height:60

    local model_node_refs = #()

    /*
    Returns the MODEL NODE currently selected in the listbox.
    The list index maps only to the last refreshed node-reference array.
    */
    function getSelectedModelNode =
    (
        selected_node = undefined
        selected_index = lb_model_nodes.selection

        if (selected_index >= 1 and selected_index <= model_node_refs.count) then
        (
            candidate_node = model_node_refs[selected_index]
            if SceneModelManager.isModelNode candidate_node then selected_node = candidate_node
        )

        selected_node
        -- return
    )

    /*
    Converts the Text-size spinner value in centimeters to current system units.
    Backend precision is not rounded or quantized by the displayed decimal format.
    */
    function getTextSizeSystemValue =
    (
        centimeter_scale = units.decodeValue "1cm"
        spn_text_size.value * centimeter_scale
        -- return
    )

    /*
    Refreshes listbox labels and preserves the previous MODEL NODE selection when possible.
    Each label includes model name, ratio, and current membership count.
    */
    function refreshModelNodes keep_node:undefined =
    (
        previous_node = keep_node
        if previous_node == undefined then previous_node = getSelectedModelNode()

        model_node_refs = SceneModelManager.getModelNodes()
        item_texts = #()
        selected_index = 0

        for node_index = 1 to model_node_refs.count do
        (
            model_node = model_node_refs[node_index]
            model_name = getUserPropVal model_node "SMM_MODEL_NAME"
            ratio_value = getUserPropVal model_node "SMM_RATIO"
            member_count = SceneModelManager.getModelNodeMembers(model_node).count

            if model_name == undefined then model_name = model_node.name
            if ratio_value == undefined then ratio_value = 150

            append item_texts (model_name + " | 1:" + (ratio_value as string) + " | " + (member_count as string) + " object(s)")
            if model_node == previous_node then selected_index = node_index
        )

        lb_model_nodes.items = item_texts
        if selected_index > 0 then lb_model_nodes.selection = selected_index
    )

    /*
    Copies persistent settings from one selected MODEL NODE into editable UI controls.
    This is presentation state only and does not alter the node.
    */
    function syncNodeControls model_node =
    (
        if SceneModelManager.isModelNode model_node then
        (
            model_name = getUserPropVal model_node "SMM_MODEL_NAME"
            ratio_value = getUserPropVal model_node "SMM_RATIO"

            if model_name == undefined then model_name = model_node.name
            if ratio_value == undefined then ratio_value = 150

            edt_name.text = model_name
            spn_ratio.value = ratio_value

            centimeter_scale = units.decodeValue "1cm"
            if centimeter_scale != 0.0 then spn_text_size.value = model_node.size / centimeter_scale

            lbl_node_status.text = "Selected: " + model_name + " | Members: " + (SceneModelManager.getModelNodeMembers(model_node).count as string)
        )
    )

    on scene_model_manager_nodes_rollout open do
    (
        refreshModelNodes()
    )

    on lb_model_nodes selected selected_index do
    (
        model_node = getSelectedModelNode()

        if model_node != undefined then
        (
            syncNodeControls model_node
            select model_node
            scene_model_manager_export_rollout.refreshExportState()
        )
    )

    on btn_create_node pressed do
    (
        member_nodes = selection as array
        pivot_point = SceneModelManager.getNodesBoundsCenter member_nodes

        if pivot_point == undefined then
        (
            picked_point = pickPoint prompt:"Pick MODEL NODE pivot" snap:#3D

            if (picked_point != #escape and picked_point != #rightClick) then pivot_point = picked_point
        )

        if pivot_point == undefined or pivot_point == #escape or pivot_point == #rightClick then
        (
            lbl_node_status.text = "MODEL NODE creation cancelled."
        )
        else
        (
            model_node = SceneModelManager.createModelNode edt_name.text member_nodes pivot_point spn_ratio.value (getTextSizeSystemValue())

            if model_node != undefined then
            (
                refreshModelNodes keep_node:model_node
                syncNodeControls model_node
                select model_node
                lbl_node_status.text = "MODEL NODE created. Set its ORTHO direction next."
                scene_model_manager_export_rollout.refreshExportState()
            )
        )
    )

    on btn_update_node pressed do
    (
        model_node = getSelectedModelNode()

        if model_node == undefined then
        (
            lbl_node_status.text = "Select a MODEL NODE in the list first."
        )
        else
        (
            SceneModelManager.updateModelNodeSettings model_node edt_name.text spn_ratio.value (getTextSizeSystemValue())
            refreshModelNodes keep_node:model_node
            lbl_node_status.text = "MODEL NODE settings updated."
            scene_model_manager_export_rollout.refreshExportState()
        )
    )

    on btn_add_members pressed do
    (
        model_node = getSelectedModelNode()

        if model_node == undefined then
        (
            lbl_node_status.text = "Select a MODEL NODE in the list first."
        )
        else
        (
            added_count = SceneModelManager.addSelectionToModelNode model_node
            refreshModelNodes keep_node:model_node
            lbl_node_status.text = "Added members: " + (added_count as string)
        )
    )

    on btn_remove_members pressed do
    (
        model_node = getSelectedModelNode()

        if model_node == undefined then
        (
            lbl_node_status.text = "Select a MODEL NODE in the list first."
        )
        else
        (
            removed_count = SceneModelManager.removeSelectionFromModelNode model_node
            refreshModelNodes keep_node:model_node
            lbl_node_status.text = "Removed members: " + (removed_count as string)
        )
    )

    on btn_select_members pressed do
    (
        model_node = getSelectedModelNode()

        if model_node == undefined then
        (
            lbl_node_status.text = "Select a MODEL NODE in the list first."
        )
        else
        (
            member_count = SceneModelManager.selectModelNodeMembers model_node
            lbl_node_status.text = "Selected members: " + (member_count as string)
        )
    )

    on btn_set_ortho pressed do
    (
        model_node = getSelectedModelNode()

        if model_node == undefined then
        (
            lbl_node_status.text = "Select a MODEL NODE in the list first."
        )
        else
        (
            direction_point = pickPoint \
                prompt:"Pick MODEL NODE XY direction" \
                rubberBand:model_node.pos \
                snap:#3D

            if (direction_point == #escape or direction_point == #rightClick) then
            (
                lbl_node_status.text = "ORTHO direction pick cancelled."
            )
            else
            (
                result_value = SceneModelManager.setModelNodeOrthoFromDirection model_node direction_point
                lbl_node_status.text = result_value[2]
            )
        )
    )

    on btn_refresh_nodes pressed do
    (
        refreshModelNodes()
        lbl_node_status.text = "MODEL NODE list refreshed."
    )

    on btn_ortho_view pressed do
    (
        model_node = getSelectedModelNode()
        result_value = SceneModelManager.activateModelNodeOrtho model_node
        lbl_node_status.text = result_value[2]
    )

    on btn_original_view pressed do
    (
        result_value = SceneModelManager.restoreOrthoView()
        lbl_node_status.text = result_value[2]
    )
)

rollout scene_model_manager_export_rollout "3. MODEL / EXPORT" width:192 height:444
(
    label lbl_export_node "ACTIVE MODEL NODE" pos:[12,12] width:168 height:24
    label lbl_export_node_value "Select one in MODEL NODES." pos:[12,36] width:168 height:36

    dropdownList ddl_target_units "System Units:" pos:[12,84] width:168 items:#("Millimeters", "Centimeters", "Meters", "Kilometers", "Inches", "Feet", "Miles") selection:1
    dropdownList ddl_display_units "Display Units:" pos:[12,120] width:168 items:#("Custom mm", "Generic", "Millimeters", "Centimeters", "Meters", "Kilometers") selection:1

    editText edt_max_path "MAX:" pos:[12,156] width:168 height:24
    button btn_browse_max "BROWSE MAX" pos:[12,192] width:168 height:24
    button btn_create_max "CREATE MODEL MAX COPY" pos:[12,228] width:168 height:24

    editText edt_obj_path "OBJ:" pos:[12,264] width:168 height:24
    button btn_export_obj "EXPORT SELECTED OBJ" pos:[12,300] width:168 height:24
    button btn_export_all "EXPORT ALL TO scene\\export" pos:[12,336] width:168 height:24

    label lbl_export_status "Ready." pos:[12,372] width:168 height:60

    /*
    Retrieves the MODEL NODE selected in the middle rollout without changing viewport selection.
    The middle rollout owns the authoritative listbox-to-node mapping.
    */
    function getActiveModelNode =
    (
        scene_model_manager_nodes_rollout.getSelectedModelNode()
        -- return
    )

    /*
    Refreshes output paths from the currently selected MODEL NODE.
    Paths are generated beside the saved working MAX scene.
    */
    function refreshExportState =
    (
        model_node = getActiveModelNode()

        if model_node == undefined then
        (
            lbl_export_node_value.text = "Select one in MODEL NODES."
        )
        else
        (
            model_name = getUserPropVal model_node "SMM_MODEL_NAME"
            if model_name == undefined then model_name = model_node.name

            lbl_export_node_value.text = model_name + " | 1:" + ((getUserPropVal model_node "SMM_RATIO") as string)
            edt_max_path.text = SceneModelManager.getDefaultModelPath model_node ".max"
            edt_obj_path.text = SceneModelManager.getDefaultModelPath model_node ".obj"
        )
    )

    on scene_model_manager_export_rollout open do
    (
        refreshExportState()
    )

    on btn_browse_max pressed do
    (
        model_node = getActiveModelNode()

        if model_node == undefined then
        (
            lbl_export_status.text = "Select a MODEL NODE first."
        )
        else
        (
            seed_path = edt_max_path.text
            selected_path = getMAXSaveFileName filename:seed_path
            if selected_path != undefined then edt_max_path.text = selected_path
        )
    )

    on btn_create_max pressed do
    (
        model_node = getActiveModelNode()

        if model_node == undefined then
        (
            lbl_export_status.text = "Select a MODEL NODE first."
        )
        else
        (
            target_type = SceneModelManager.getTargetTypeBySelection ddl_target_units.selection
            display_type = SceneModelManager.getDisplayTypeBySelection ddl_display_units.selection
            lbl_export_status.text = "Creating model MAX copy..."
            windows.processPostedMessages()
            result_value = SceneModelManager.createModelMaxCopy model_node edt_max_path.text target_type display_type
            lbl_export_status.text = result_value[2]
        )
    )

    on btn_export_obj pressed do
    (
        model_node = getActiveModelNode()

        if model_node == undefined then
        (
            lbl_export_status.text = "Select a MODEL NODE first."
        )
        else
        (
            target_type = SceneModelManager.getTargetTypeBySelection ddl_target_units.selection
            display_type = SceneModelManager.getDisplayTypeBySelection ddl_display_units.selection
            lbl_export_status.text = "Exporting MODEL NODE OBJ..."
            windows.processPostedMessages()
            result_value = SceneModelManager.exportModelNodeObj model_node edt_obj_path.text target_type display_type
            lbl_export_status.text = result_value[2]
        )
    )

    on btn_export_all pressed do
    (
        if maxFilePath == "" then
        (
            lbl_export_status.text = "Save the working MAX scene before batch export."
        )
        else
        (
            target_type = SceneModelManager.getTargetTypeBySelection ddl_target_units.selection
            display_type = SceneModelManager.getDisplayTypeBySelection ddl_display_units.selection
            export_folder = maxFilePath + "export\\"
            lbl_export_status.text = "Batch exporting MODEL NODEs..."
            windows.processPostedMessages()
            result_value = SceneModelManager.exportAllModelNodesObj export_folder target_type display_type
            lbl_export_status.text = "Exported: " + (result_value[1] as string) + " | Failed: " + (result_value[2] as string)
        )
    )
)

rollout scene_model_manager_rollout scene_model_manager_title width:192 height:720
(
    button btn_restart "RESTART" pos:[12,12] width:168 height:24 \
        toolTip:"LMB: Reload the canonical Scene Model Manager entry file."

    subRollout sr_sections "" pos:[0,48] width:192 height:612
    label lbl_footer "Source scene authoritative.\nExports use Hold/Fetch." pos:[12,672] width:168 height:36

    on btn_restart pressed do
    (
        restartSceneModelManager()
    )

    on scene_model_manager_rollout help do
    (
        restartSceneModelManager()
    )

    on scene_model_manager_rollout open do
    (
        try (removeSubRollout sr_sections scene_model_manager_prepare_rollout) catch ()
        try (removeSubRollout sr_sections scene_model_manager_nodes_rollout) catch ()
        try (removeSubRollout sr_sections scene_model_manager_export_rollout) catch ()

        addSubRollout sr_sections scene_model_manager_prepare_rollout rolledUp:false
        addSubRollout sr_sections scene_model_manager_nodes_rollout rolledUp:false
        addSubRollout sr_sections scene_model_manager_export_rollout rolledUp:false
        windows.processPostedMessages()
    )

    on scene_model_manager_rollout resized dialog_size do
    (
        new_height = amax 300 (dialog_size.y - 108)
        sr_sections.height = new_height
        lbl_footer.pos.y = dialog_size.y - 48
    )
)

/*
Opens the Scene Model Manager top-level Toolset dialog.
Only the main entry file calls this function automatically.
*/
function openSceneModelManager =
(
    try
    (
        destroyDialog scene_model_manager_rollout
    )
    catch
    (
    )

    createDialog scene_model_manager_rollout 192 720 style:#(#style_titlebar, #style_sysmenu, #style_resizing)
    windows.processPostedMessages()
    true
    -- return
)
