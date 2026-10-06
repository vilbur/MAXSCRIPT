/*
Scene Model Manager UI.
File version: 0.005
Project version: 0.005
*/

global scene_model_manager_rollout
global scene_model_manager_prepare_rollout
global scene_model_manager_nodes_rollout
global scene_model_manager_export_rollout
global scene_model_manager_title

if (scene_model_manager_project_version == undefined or scene_model_manager_project_version < 0.005) then
(
    scene_model_manager_project_version = 0.005
)

scene_model_manager_title = "SCENE MODEL MANAGER " + (scene_model_manager_project_version as string)

rollout scene_model_manager_prepare_rollout "1. PREPARE SCENE"
(
    label lbl_units "System Units:" pos:[12,12] width:88 height:18
    label lbl_units_value "-" pos:[104,12] width:360 height:18
    label lbl_display "Display Units:" pos:[12,34] width:88 height:18
    label lbl_display_value "-" pos:[104,34] width:360 height:18

    button btn_convert_units "1. CONVERT 1mm -> 1m BY MERGE" pos:[12,60] width:452 height:28 \
        toolTip:"LMB: Reset to a clean 1 meter scene and Merge the saved 1 mm source with native unit rescaling."

    button btn_display_cm "2. SET DISPLAY = cm" pos:[12,94] width:220 height:26
    button btn_find_outliers "3. FIND OUTLIERS" pos:[244,94] width:220 height:26 \
        toolTip:"LMB: Select top-level non-geometry leaf nodes whose pivot lies outside the exact geometry bounding box.\n\nNothing is deleted."

    button btn_delete_outliers "4. DELETE FOUND" pos:[12,126] width:220 height:26 \
        toolTip:"LMB: Delete only nodes found by the previous FIND OUTLIERS scan after confirmation."
    button btn_center_pivots "5. CENTER PIVOTS" pos:[244,126] width:220 height:26 \
        toolTip:"LMB: Center pivots on selected geometry, or all geometry when nothing is selected.\n\nModifier stacks are not collapsed."

    button btn_offset_origin "6. OFFSET TO ORIGIN" pos:[12,158] width:220 height:28 \
        toolTip:"LMB: Move the complete working scene so selected geometry, or all geometry, is centered at world origin.\n\nThe real-world offset is stored for later restoration."
    button btn_restore_offset "RESTORE REAL-WORLD" pos:[244,158] width:220 height:28 \
        toolTip:"LMB: Restore the persistent real-world scene offset.\n\nORTHO view must be ORIGINAL first."

    label lbl_prepare_status "Ready." pos:[12,194] width:452 height:36

    /*
    Refreshes source-unit labels from the currently loaded scene.
    UI formatting never changes the underlying scene values.
    */
    function refreshPrepareState =
    (
        lbl_units_value.text = (units.SystemScale as string) + " " + (units.SystemType as string)
        lbl_display_value.text = units.DisplayType as string

        if SceneModelManager.isOffsetActive() then
        (
            lbl_prepare_status.text = "Editing offset is ACTIVE. Scene is working near origin."
        )
        else
        (
            lbl_prepare_status.text = "Editing offset is inactive."
        )
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

    on btn_find_outliers pressed do
    (
        candidate_nodes = SceneModelManager.findOutlierCandidates()
        lbl_prepare_status.text = (candidate_nodes.count as string) + " outlier candidate(s) selected for visual review."
    )

    on btn_delete_outliers pressed do
    (
        if SceneModelManager.outlier_handles.count == 0 then
        (
            lbl_prepare_status.text = "Run FIND OUTLIERS first."
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

    on btn_offset_origin pressed do
    (
        result_value = SceneModelManager.offsetSceneToWorkOrigin()
        lbl_prepare_status.text = result_value[2]
        refreshPrepareState()
    )

    on btn_restore_offset pressed do
    (
        result_value = SceneModelManager.restoreSceneOffset()
        lbl_prepare_status.text = result_value[2]
        refreshPrepareState()
    )
)

rollout scene_model_manager_nodes_rollout "2. MODEL NODES"
(
    listBox lb_model_nodes "MODEL NODES" pos:[12,10] width:452 height:7

    editText edt_name "Name:" pos:[12,140] width:292 height:20
    spinner spn_ratio "Ratio 1:" pos:[316,140] width:148 height:20 type:#integer range:[1,1000000,150] scale:1

    spinner spn_text_size "Text cm:" pos:[12,168] width:220 height:20 type:#float range:[1.0,100000.0,100.0] scale:1.0
    button btn_refresh_nodes "REFRESH LIST" pos:[244,166] width:220 height:24

    button btn_create_node "CREATE FROM SELECTION" pos:[12,198] width:220 height:26 \
        toolTip:"LMB: Create a visible MODEL NODE Text object at the selected objects' bounding-box center.\n\nCurrent selection becomes the initial membership."
    button btn_update_node "UPDATE NODE" pos:[244,198] width:220 height:26

    button btn_add_members "ADD SELECTED" pos:[12,230] width:220 height:24
    button btn_remove_members "REMOVE SELECTED" pos:[244,230] width:220 height:24

    button btn_select_members "SELECT MEMBERS" pos:[12,260] width:452 height:24

    button btn_set_ortho "SET ORTHO DIRECTION" pos:[12,290] width:452 height:26 \
        toolTip:"LMB: Pick an XY direction from the MODEL NODE position.\n\nThe Text orientation shows the stored source direction."

    button btn_ortho_view "ORTHO VIEW" pos:[12,322] width:220 height:28 \
        toolTip:"LMB: Rotate the complete editing scene through the selected MODEL NODE pivot.\n\nMODEL NODE membership only controls export, not what rotates."
    button btn_original_view "ORIGINAL VIEW" pos:[244,322] width:220 height:28 \
        toolTip:"LMB: Return the editing scene from the active ORTHO frame to original orientation."

    label lbl_node_status "Ready." pos:[12,358] width:452 height:38

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

rollout scene_model_manager_export_rollout "3. MODEL / EXPORT"
(
    label lbl_export_node "Active MODEL NODE:" pos:[12,12] width:112 height:18
    label lbl_export_node_value "Select one in MODEL NODES." pos:[128,12] width:336 height:18

    dropdownList ddl_target_units "System Units:" pos:[12,38] width:220 items:#("Millimeters", "Centimeters", "Meters", "Kilometers", "Inches", "Feet", "Miles") selection:1
    dropdownList ddl_display_units "Display Units:" pos:[244,38] width:220 items:#("Custom mm", "Generic", "Millimeters", "Centimeters", "Meters", "Kilometers") selection:1

    editText edt_max_path "MAX:" pos:[12,78] width:352 height:20
    button btn_browse_max "BROWSE" pos:[376,76] width:88 height:24

    button btn_create_max "CREATE MODEL MAX COPY" pos:[12,106] width:452 height:28

    editText edt_obj_path "OBJ:" pos:[12,144] width:452 height:20

    button btn_export_obj "EXPORT SELECTED MODEL NODE OBJ" pos:[12,172] width:452 height:28
    button btn_export_all "EXPORT ALL MODEL NODES TO scene\\export" pos:[12,206] width:452 height:28

    label lbl_export_status "Ready." pos:[12,244] width:452 height:40

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

rollout scene_model_manager_rollout scene_model_manager_title width:500 height:720
(
    subRollout sr_sections "" pos:[6,6] width:488 height:686
    label lbl_footer "Source scene stays authoritative. MODEL exports use Hold/Fetch." pos:[10,696] width:480 height:18

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
        new_height = amax 300 (dialog_size.y - 34)
        sr_sections.height = new_height
        lbl_footer.pos.y = dialog_size.y - 22
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

    createDialog scene_model_manager_rollout 500 720 style:#(#style_titlebar, #style_sysmenu, #style_resizing)
    windows.processPostedMessages()
    true
    -- return
)
