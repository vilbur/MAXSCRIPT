/*
Scene Model Manager UI.
File version: 0.032
Project version: 0.032
*/

global scene_model_manager_rollout
global scene_model_manager_prepare_rollout
global scene_model_manager_nodes_rollout
global scene_model_manager_export_rollout
global scene_model_manager_title
global scene_model_manager_restart_file
global scene_model_manager_ui_ini_file
global openSceneModelManager

/*
Closes the previous Scene Model Manager dialog before this UI version is defined.
The stable global rollout reference makes script reloads single-instance across versions.
*/
if scene_model_manager_rollout != undefined then
(
    try (destroyDialog scene_model_manager_rollout) catch ()
)

if (scene_model_manager_project_version == undefined or scene_model_manager_project_version < 0.032) then
(
    scene_model_manager_project_version = 0.032
)

scene_model_manager_title = "SCENE MODEL MANAGER " + (scene_model_manager_project_version as string)
scene_model_manager_restart_file = getFilenamePath (getSourceFileName()) + "Scene-Model-Manager.ms"
scene_model_manager_ui_ini_file = getDir #plugcfg + "\\Scene-Model-Manager.ini"

/*
Reads one persisted integer UI setting or returns the supplied default.
Invalid INI text is ignored without altering scene data.
*/
function getSceneModelManagerIniInteger key_name default_value =
(
    setting_text = getINISetting scene_model_manager_ui_ini_file "UI" key_name

    if setting_text == "" then
    (
        default_value
    )
    else
    (
        try(setting_text as integer)catch(default_value)
    )
    -- return
)

/*
Reads one persisted Float UI setting or returns the supplied default.
Invalid INI text is ignored without altering scene data.
*/
function getSceneModelManagerIniFloat key_name default_value =
(
    setting_text = getINISetting scene_model_manager_ui_ini_file "UI" key_name

    if setting_text == "" then
    (
        default_value
    )
    else
    (
        try(setting_text as float)catch(default_value)
    )
    -- return
)

/*
Writes one user-interface setting to the Scene Model Manager INI file.
Scene-specific transform and MODEL NODE data are never stored here.
*/
function setSceneModelManagerIniValue key_name setting_value =
(
    setINISetting scene_model_manager_ui_ini_file "UI" key_name (setting_value as string)
    true
    -- return
)

/*
Reads one persisted Boolean rollout state from integer INI storage.
Zero means closed and any non-zero value means open.
*/
function getSceneModelManagerIniBoolean key_name default_value =
(
    default_integer = if default_value then 1 else 0
    stored_integer = getSceneModelManagerIniInteger key_name default_integer
    stored_integer != 0
    -- return
)

/*
Persists dialog position, resizable height, and the three subrollout open states.
The fixed 288 px dialog width is intentionally not persisted.
*/
function saveSceneModelManagerDialogState dialog_pos:undefined dialog_size:undefined =
(
    if dialog_pos != undefined then
    (
        setSceneModelManagerIniValue "DialogX" dialog_pos.x
        setSceneModelManagerIniValue "DialogY" dialog_pos.y
    )

    if (dialog_size != undefined and dialog_size.y >= 408) then
    (
        setSceneModelManagerIniValue "DialogHeight" dialog_size.y
    )

    setSceneModelManagerIniValue "PrepareOpen" (if scene_model_manager_prepare_rollout.open then 1 else 0)
    setSceneModelManagerIniValue "ModelNodesOpen" (if scene_model_manager_nodes_rollout.open then 1 else 0)
    setSceneModelManagerIniValue "ExportOpen" (if scene_model_manager_export_rollout.open then 1 else 0)
    true
    -- return
)

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

/*
Writes one UI process marker through the backend DUMP interface.
The UI remains functional when development logging is unavailable.
*/
function dumpSceneModelManagerUi log_value =
(
    if SceneModelManager == undefined then
    (
        false
    )
    else
    (
        SceneModelManager.dumpLog ("UI | " + (log_value as string))
    )
    -- return
)

rollout scene_model_manager_prepare_rollout "1. PREPARE SCENE" width:288 height:420
(
    label lbl_units "System:" pos:[12,12] width:72 height:24
    label lbl_units_value "-" pos:[84,12] width:192 height:24
    label lbl_display "Display:" pos:[12,36] width:72 height:24
    label lbl_display_value "-" pos:[84,36] width:192 height:24

    button btn_convert_units "1. CONVERT 1mm -> 1m" pos:[12,72] width:264 height:24 \
        toolTip:"LMB: Reset to a clean 1 meter scene and Merge the saved 1 mm source with native unit rescaling."

    button btn_display_cm "2. SET DISPLAY = cm" pos:[12,108] width:264 height:24
    button btn_outliers "3. OUTLIERS  SELECT / DELETE" pos:[12,144] width:264 height:24 \
        toolTip:"LMB: Select outlier candidates for visual review.\n\nRMB: Delete the candidates found by the last LMB scan after confirmation."

    button btn_center_pivots "4. CENTER PIVOTS" pos:[12,180] width:264 height:24 \
        toolTip:"LMB: Center pivots on selected geometry, or all geometry when nothing is selected.\n\nModifier stacks are not collapsed."

    label lbl_scene_position "5. SCENE POSITION" pos:[12,216] width:264 height:24
    radioButtons rdo_scene_position "" labels:#("REAL-WORLD", "OFFSET TO ORIGIN") default:1 columns:2 pos:[42,240] width:204 align:#center

    button btn_main_rotation "6. DEFINE ROTATION VECTOR" pos:[12,276] width:264 height:24 \
        toolTip:"LMB: Immediately pick vector START, then vector END in the viewport. The XY vector defines the stored correction angle.\n\nRMB: Add +90 deg to the stored rotation. If ROTATION ON is active, rotate the scene immediately around world origin."
    radioButtons rdo_scene_rotation "" labels:#("ROTATION OFF", "ROTATION ON") default:1 columns:2 pos:[42,312] width:204 align:#center

    label lbl_prepare_status "Ready." pos:[12,348] width:264 height:60

    local offset_state_syncing = false
    local rotation_state_syncing = false

    /*
    Refreshes source-unit labels from the currently loaded scene.
    UI formatting never changes the underlying scene values.
    */
    function refreshPrepareState =
    (
        lbl_units_value.text = (units.SystemScale as string) + " " + (units.SystemType as string)
        lbl_display_value.text = units.DisplayType as string

        offset_state_syncing = true
        rotation_state_syncing = true
        offset_active = SceneModelManager.isOffsetActive()
        btn_main_rotation.enabled = true
        rdo_scene_rotation.enabled = offset_active

        if offset_active then
        (
            rdo_scene_position.state = 2
            rotation_active = SceneModelManager.isMainRotationActive()
            rotation_defined = SceneModelManager.hasMainRotationDefinition()
            defined_rotation_z = SceneModelManager.getStoredMainRotationDefinedZ()
            applied_rotation_z = SceneModelManager.getStoredMainRotationZ()
            rdo_scene_rotation.state = if rotation_active then 2 else 1

            if rotation_active then
            (
                lbl_prepare_status.text = "OFFSET | ROTATION ON: " + (formattedPrint applied_rotation_z format:"0.6f") + " deg"
            )
            else if rotation_defined then
            (
                lbl_prepare_status.text = "OFFSET | ROTATION OFF | Defined: " + (formattedPrint defined_rotation_z format:"0.6f") + " deg"
            )
            else
            (
                lbl_prepare_status.text = "OFFSET | Rotation vector not defined."
            )
        )
        else
        (
            rdo_scene_position.state = 1
            rdo_scene_rotation.state = 1
            rotation_defined = SceneModelManager.hasMainRotationDefinition()
            defined_rotation_z = SceneModelManager.getStoredMainRotationDefinedZ()

            if rotation_defined then
            (
                lbl_prepare_status.text = "ROTATION DEFINED: " + (formattedPrint defined_rotation_z format:"0.6f") + " deg | activate OFFSET to apply."
            )
            else
            (
                lbl_prepare_status.text = "Editing offset is inactive."
            )
        )

        rotation_state_syncing = false
        offset_state_syncing = false
    )

    on scene_model_manager_prepare_rollout open do
    (
        refreshPrepareState()
    )

    on btn_convert_units pressed do
    (
        dumpSceneModelManagerUi "PREPARE | CONVERT | START"
        lbl_prepare_status.text = "Opening native Merge unit conversion..."
        windows.processPostedMessages()
        conversion_ok = SceneModelManager.convertSystemUnitsMmToMetersByMerge()
        dumpSceneModelManagerUi ("PREPARE | CONVERT | RESULT | " + (conversion_ok as string))
        refreshPrepareState()

        if conversion_ok then lbl_prepare_status.text = "Merge finished. Save this meter-based working scene under a new name."
    )

    on btn_display_cm pressed do
    (
        dumpSceneModelManagerUi "PREPARE | DISPLAY CM | START"
        display_ok = SceneModelManager.setEditingDisplayCentimeters()
        dumpSceneModelManagerUi ("PREPARE | DISPLAY CM | RESULT | " + (display_ok as string))
        refreshPrepareState()
        lbl_prepare_status.text = "Display Units set to centimeters. System Units were not changed."
    )

    on btn_outliers pressed do
    (
        dumpSceneModelManagerUi "PREPARE | OUTLIERS SELECT | START"
        candidate_nodes = SceneModelManager.findOutlierCandidates()
        dumpSceneModelManagerUi ("PREPARE | OUTLIERS SELECT | RESULT | count=" + (candidate_nodes.count as string))
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
                dumpSceneModelManagerUi "PREPARE | OUTLIERS DELETE | START"
                delete_result = SceneModelManager.deleteFoundOutliers()
                dumpSceneModelManagerUi ("PREPARE | OUTLIERS DELETE | RESULT | " + (delete_result as string))
                lbl_prepare_status.text = "Deleted: " + (delete_result[1] as string) + " | Missing: " + (delete_result[2] as string)
            )
        )
    )

    on btn_center_pivots pressed do
    (
        dumpSceneModelManagerUi "PREPARE | CENTER PIVOTS | START"
        result_value = SceneModelManager.centerObjectPivots()
        dumpSceneModelManagerUi ("PREPARE | CENTER PIVOTS | RESULT | " + (result_value as string))
        lbl_prepare_status.text = result_value[2]
    )

    on rdo_scene_position changed state_index do
    (
        if not offset_state_syncing then
        (
            dumpSceneModelManagerUi ("PREPARE | SCENE POSITION | state=" + (state_index as string))
            if state_index == 2 then
            (
                result_value = SceneModelManager.offsetSceneToWorkOrigin()
            )
            else
            (
                result_value = SceneModelManager.restoreSceneOffset()
            )

            dumpSceneModelManagerUi ("PREPARE | SCENE POSITION | RESULT | " + (result_value as string))
            refreshPrepareState()
            lbl_prepare_status.text = result_value[2]
        )
    )

    on btn_main_rotation pressed do
    (
        dumpSceneModelManagerUi "PREPARE | DEFINE ROTATION VECTOR | PICK START"
        lbl_prepare_status.text = "Pick rotation vector START..."
        windows.processPostedMessages()

        vector_start = pickPoint \
            prompt:"Pick main rotation vector START" \
            snap:#3D

        if (vector_start == #escape or vector_start == #rightClick) then
        (
            lbl_prepare_status.text = "Main rotation vector pick cancelled."
        )
        else
        (
            dumpSceneModelManagerUi ("PREPARE | DEFINE ROTATION VECTOR | START POINT | " + (vector_start as string))
            lbl_prepare_status.text = "Pick rotation vector END..."
            windows.processPostedMessages()

            vector_end = pickPoint \
                prompt:"Pick main rotation vector END" \
                rubberBand:vector_start \
                snap:#3D

            if (vector_end == #escape or vector_end == #rightClick) then
            (
                lbl_prepare_status.text = "Main rotation vector pick cancelled."
            )
            else
            (
                picked_vector = vector_end - vector_start
                dumpSceneModelManagerUi ("PREPARE | DEFINE ROTATION VECTOR | VECTOR | start=" + (vector_start as string) + " | end=" + (vector_end as string) + " | vector=" + (picked_vector as string))
                result_value = SceneModelManager.defineMainRotationFromVector picked_vector
                dumpSceneModelManagerUi ("PREPARE | DEFINE ROTATION VECTOR | RESULT | " + (result_value as string))
                refreshPrepareState()
                lbl_prepare_status.text = result_value[2]
            )
        )
    )

    on btn_main_rotation rightclick do
    (
        dumpSceneModelManagerUi "PREPARE | ROTATION +90 | START"
        result_value = SceneModelManager.addMainRotationAngle 90.0
        dumpSceneModelManagerUi ("PREPARE | ROTATION +90 | RESULT | " + (result_value as string))
        refreshPrepareState()
        lbl_prepare_status.text = result_value[2]
    )

    on rdo_scene_rotation changed state_index do
    (
        if not rotation_state_syncing then
        (
            dumpSceneModelManagerUi ("PREPARE | ROTATION TOGGLE | state=" + (state_index as string))
            result_value = SceneModelManager.setMainRotationActive (state_index == 2)
            dumpSceneModelManagerUi ("PREPARE | ROTATION TOGGLE | RESULT | " + (result_value as string))
            refreshPrepareState()
            lbl_prepare_status.text = result_value[2]
        )
    )

    on scene_model_manager_prepare_rollout rolledUp rollout_is_open do
    (
        setSceneModelManagerIniValue "PrepareOpen" (if rollout_is_open then 1 else 0)
    )
)

rollout scene_model_manager_nodes_rollout "2. MODEL NODES" width:288 height:504
(
    spinner spn_ratio "Ratio 1:" pos:[42,12] width:96 height:24 type:#integer range:[1,1000000,150] scale:1 \
        toolTip:"MODEL ratio. For a selected MODEL NODE, changing this spinner updates the stored ratio immediately. Without a selected node it remains the creation default."
    spinner spn_text_size "Size:" pos:[150,12] width:96 height:24 type:#integer range:[1,100000,100] scale:1 \
        toolTip:"Visible MODEL NODE Text size in centimeters. For a selected MODEL NODE, changing this spinner updates the Text size immediately in the viewport."

    button btn_create_node "CREATE MODEL NODE" pos:[12,48] width:180 height:24 \
        toolTip:"Ask for the MODEL name, prefilled from the selected objects' layer. Create the Text at the selection XY center with Z = 0, then link only top hierarchy roots so groups and object hierarchies stay intact."
    button btn_refresh_nodes "REFRESH" pos:[204,48] width:72 height:24 \
        toolTip:"Refresh MODEL NODEs from the current scene while preserving the selected MODEL NODE when possible."

    listBox lb_model_nodes "MODEL NODES" pos:[12,84] width:264 height:7 \
        toolTip:"Select a MODEL NODE to edit its live ratio/size, top-root MODEL MEMBERS, and ORTHO view."

    groupBox grp_model_members "MODEL MEMBERS" pos:[12,216] width:264 height:132

    button btn_add_members "ADD SELECTED" pos:[24,240] width:108 height:24 \
        toolTip:"Add only top hierarchy roots from the current viewport selection. Children and group members remain parented to their existing hierarchy."
    button btn_remove_members "REMOVE SELECTED" pos:[144,240] width:120 height:24 \
        toolTip:"Remove selected stored member roots from this MODEL NODE. Only roots directly owned by the MODEL NODE are unlinked; their child hierarchies remain untouched."

    button btn_bind_layer_members "BIND MATCHING LAYER" pos:[24,276] width:240 height:24 \
        toolTip:"Find the scene layer whose name exactly matches the selected MODEL NODE name and bind only its top hierarchy roots. Descendants, group members, and roots already owned by another MODEL NODE are not reparented."

    button btn_select_members "SELECT MEMBERS" pos:[24,312] width:240 height:24 \
        toolTip:"Select all currently valid top member roots stored by the selected MODEL NODE."

    button btn_set_ortho "SET ORTHO DIRECTION" pos:[12,360] width:264 height:24 \
        toolTip:"LMB: Pick vector START, then END. The MODEL NODE pivot is aligned to START and the XY vector defines its stored ORTHO correction.\n\nIf ROTATION ON is active, the MODEL NODE rotates to the nearest world X/Y axis."

    radioButtons rdo_ortho_view "" labels:#("ORTHO", "ORIGINAL") default:2 columns:2 pos:[42,396] width:204 align:#center \
        toolTip:#("Rotate only the selected MODEL NODE Text to its stored ORTHO correction. Linked members and the rest of the scene stay unchanged.", "Restore only the selected MODEL NODE Text to its pre-ORTHO rotation. Linked members and the rest of the scene stay unchanged.")

    label lbl_node_status "Ready." pos:[12,432] width:264 height:60

    local model_node_refs = #()
    local ortho_state_syncing = false
    local node_controls_syncing = false

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
    Converts the integer Size spinner value in centimeters to current system units.
    Integer centimeters are an explicit MODEL NODE UI requirement.
    */
    function getTextSizeSystemValue =
    (
        centimeter_scale = units.decodeValue "1cm"
        spn_text_size.value * centimeter_scale
        -- return
    )

    /*
    Synchronizes the ORTHO / ORIGINAL radio row from the MODEL NODE-owned ORTHO state.
    Programmatic radio changes are guarded so they never retrigger the view operation.
    */
    function refreshOrthoRadio =
    (
        ortho_state_syncing = true
        model_node = getSelectedModelNode()

        if (model_node != undefined and SceneModelManager.isModelNodeOrthoActive model_node) then
        (
            rdo_ortho_view.state = 1
        )
        else
        (
            rdo_ortho_view.state = 2
        )

        ortho_state_syncing = false
        true
        -- return
    )

    /*
    Returns the current viewport selection eligible for new MODEL NODE membership.
    Existing MODEL NODE Text objects are excluded from the new membership set.
    */
    function getCreationMemberNodes =
    (
        member_nodes = #()

        for selected_node in selection do
        (
            if (selected_node != undefined and isValidNode selected_node and not SceneModelManager.isModelNode selected_node) then
            (
                append member_nodes selected_node
            )
        )

        member_nodes
        -- return
    )

    /*
    Builds the creation-name prompt default from the selected member objects' layer.
    The first valid member layer is used; without members or a valid layer, a unique MODEL_ name is proposed.
    */
    function getCreationDefaultName member_nodes =
    (
        default_name = ""

        if (member_nodes != undefined and member_nodes.count > 0) then
        (
            source_layer = member_nodes[1].layer
            if source_layer != undefined then default_name = source_layer.name
        )

        if default_name == "" then default_name = uniqueName "MODEL_"
        default_name
        -- return
    )

    /*
    Prompts for a MODEL NODE name with the 3ds Max Rename Instance dialog.
    The supplied default name is prefilled; an empty result stops creation.
    */
    function promptModelNodeName default_name =
    (
        name_dialog = dotNetObject "MaxCustomControls.RenameInstanceDialog" default_name
        name_dialog.text = "MODEL NODE Name"
        modal_result = name_dialog.ShowModal()
        entered_name = name_dialog.InstanceName

        dumpSceneModelManagerUi ("MODEL NODE | NAME PROMPT | modal=" + (modal_result as string) + " | result=" + (entered_name as string))

        if entered_name == "" then entered_name = undefined
        entered_name
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
            resolved_members = SceneModelManager.getModelNodeMembers model_node
            member_count = resolved_members.count

            if model_name == undefined then model_name = model_node.name
            if ratio_value == undefined then ratio_value = 150

            append item_texts (model_name + " | 1:" + (ratio_value as string) + " | " + (member_count as string) + " member root(s)")
            if model_node == previous_node then selected_index = node_index
        )

        lb_model_nodes.items = item_texts
        if selected_index > 0 then lb_model_nodes.selection = selected_index
        refreshOrthoRadio()
    )

    /*
    Applies the live Ratio and Size spinner values to the selected MODEL NODE.
    Programmatic spinner synchronization is ignored so list selection never writes settings back accidentally.
    */
    function applyLiveNodeSettings refresh_list:false =
    (
        if node_controls_syncing then
        (
            false
        )
        else
        (
            model_node = getSelectedModelNode()

            if model_node == undefined then
            (
                false
            )
            else
            (
                model_name = getUserPropVal model_node "SMM_MODEL_NAME"
                if model_name == undefined then model_name = model_node.name

                update_ok = SceneModelManager.updateModelNodeSettings model_node model_name spn_ratio.value (getTextSizeSystemValue())
                dumpSceneModelManagerUi ("MODEL NODE | LIVE SETTINGS | ratio=" + (spn_ratio.value as string) + " | sizeCm=" + (spn_text_size.value as string) + " | ok=" + (update_ok as string))

                if update_ok then
                (
                    if refresh_list then refreshModelNodes keep_node:model_node
                    scene_model_manager_export_rollout.refreshExportState()
                )

                update_ok
            )
        )
        -- return
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

            node_controls_syncing = true
            spn_ratio.value = ratio_value

            centimeter_scale = units.decodeValue "1cm"
            if centimeter_scale != 0.0 then spn_text_size.value = (model_node.size / centimeter_scale) as integer
            node_controls_syncing = false

            resolved_members = SceneModelManager.getModelNodeMembers model_node
            lbl_node_status.text = "Selected: " + model_name + " | Members: " + (resolved_members.count as string)
            refreshOrthoRadio()
        )
    )

    on scene_model_manager_nodes_rollout open do
    (
        saved_ratio = getSceneModelManagerIniInteger "DefaultRatio" 150
        saved_text_size = getSceneModelManagerIniInteger "DefaultTextSizeCm" 100

        if saved_ratio < 1 then saved_ratio = 150
        if saved_text_size < 1 then saved_text_size = 100

        node_controls_syncing = true
        spn_ratio.value = saved_ratio
        spn_text_size.value = saved_text_size
        node_controls_syncing = false
        refreshModelNodes()
        refreshOrthoRadio()
    )

    on spn_ratio changed spinner_value do
    (
        setSceneModelManagerIniValue "DefaultRatio" spinner_value

        if not node_controls_syncing then
        (
            applyLiveNodeSettings refresh_list:true
        )
    )

    on spn_text_size changed spinner_value do
    (
        setSceneModelManagerIniValue "DefaultTextSizeCm" spinner_value

        if not node_controls_syncing then
        (
            applyLiveNodeSettings()
        )
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
        default_members = getCreationMemberNodes()
        default_name = getCreationDefaultName default_members
        dumpSceneModelManagerUi ("MODEL NODE | CREATE | NAME PROMPT | defaultName=" + default_name)
        model_name = promptModelNodeName default_name

        if model_name == undefined then
        (
            lbl_node_status.text = "MODEL NODE creation cancelled."
            dumpSceneModelManagerUi "MODEL NODE | CREATE | CANCELLED AT NAME"
        )
        else
        (
            member_nodes = getCreationMemberNodes()
            dumpSceneModelManagerUi ("MODEL NODE | CREATE | SELECTION | count=" + (member_nodes.count as string))

            if member_nodes.count == 0 then
            (
                lbl_node_status.text = "Select objects before creating a MODEL NODE."
                dumpSceneModelManagerUi "MODEL NODE | CREATE | STOP | no selection"
            )
            else
            (
                member_roots = SceneModelManager.getTopModelMemberRoots member_nodes

                if member_roots.count == 0 then
                (
                    lbl_node_status.text = "No top hierarchy roots are selected."
                    dumpSceneModelManagerUi "MODEL NODE | CREATE | STOP | no top hierarchy roots"
                )
                else
                (
                    model_node = SceneModelManager.createModelNode model_name member_nodes undefined spn_ratio.value (getTextSizeSystemValue())
                    dumpSceneModelManagerUi ("MODEL NODE | CREATE | RESULT | node=" + (model_node as string) + " | name=" + model_name + " | source=" + (member_nodes.count as string) + " | roots=" + (member_roots.count as string))

                    if model_node != undefined then
                    (
                        refreshModelNodes keep_node:model_node
                        syncNodeControls model_node
                        select model_node
                        linked_roots = SceneModelManager.getModelNodeMembers model_node
                        lbl_node_status.text = "MODEL NODE created: " + model_name + " | Root members: " + (linked_roots.count as string)
                        scene_model_manager_export_rollout.refreshExportState()
                    )
                    else
                    (
                        lbl_node_status.text = "MODEL NODE creation failed. Check DUMP / Listener."
                    )
                )
            )
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
            dumpSceneModelManagerUi ("MODEL MEMBERS | ADD SELECTED | START | selection=" + (selection.count as string))
            added_count = SceneModelManager.addSelectionToModelNode model_node
            dumpSceneModelManagerUi ("MODEL MEMBERS | ADD SELECTED | RESULT | added=" + (added_count as string))
            refreshModelNodes keep_node:model_node
            lbl_node_status.text = "Added top member roots: " + (added_count as string)
        )
    )

    on btn_bind_layer_members pressed do
    (
        model_node = getSelectedModelNode()

        if model_node == undefined then
        (
            lbl_node_status.text = "Select a MODEL NODE in the list first."
        )
        else
        (
            model_name = getUserPropVal model_node "SMM_MODEL_NAME"
            if model_name == undefined then model_name = model_node.name

            dumpSceneModelManagerUi ("MODEL MEMBERS | BIND MATCHING LAYER | START | name=" + model_name)
            bind_result = SceneModelManager.bindMatchingLayerToModelNode model_node
            dumpSceneModelManagerUi ("MODEL MEMBERS | BIND MATCHING LAYER | RESULT | " + (bind_result as string))
            refreshModelNodes keep_node:model_node
            lbl_node_status.text = bind_result[4]
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
            lbl_node_status.text = "Removed member roots: " + (removed_count as string)
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
            lbl_node_status.text = "Selected member roots: " + (member_count as string)
        )
    )

    on btn_set_ortho pressed do
    (
        dumpSceneModelManagerUi "MODEL NODE | SET ORTHO VECTOR | START"
        model_node = getSelectedModelNode()

        if model_node == undefined then
        (
            lbl_node_status.text = "Select a MODEL NODE in the list first."
            dumpSceneModelManagerUi "MODEL NODE | SET ORTHO VECTOR | STOP | no MODEL NODE selected"
        )
        else if SceneModelManager.isModelNodeOrthoActive model_node then
        (
            lbl_node_status.text = "Return this MODEL NODE to ORIGINAL before redefining its direction."
            dumpSceneModelManagerUi "MODEL NODE | SET ORTHO VECTOR | STOP | selected MODEL NODE ORTHO active"
        )
        else
        (
            lbl_node_status.text = "Pick ORTHO vector START..."
            windows.processPostedMessages()

            vector_start = pickPoint \
                prompt:"Pick MODEL NODE ORTHO vector START" \
                snap:#3D

            if (vector_start == #escape or vector_start == #rightClick) then
            (
                lbl_node_status.text = "ORTHO vector pick cancelled at START."
                dumpSceneModelManagerUi "MODEL NODE | SET ORTHO VECTOR | CANCEL | start"
            )
            else
            (
                dumpSceneModelManagerUi ("MODEL NODE | SET ORTHO VECTOR | START POINT | " + (vector_start as string))
                lbl_node_status.text = "Pick ORTHO vector END..."
                windows.processPostedMessages()

                vector_end = pickPoint \
                    prompt:"Pick MODEL NODE ORTHO vector END" \
                    rubberBand:vector_start \
                    snap:#3D

                if (vector_end == #escape or vector_end == #rightClick) then
                (
                    lbl_node_status.text = "ORTHO vector pick cancelled at END."
                    dumpSceneModelManagerUi "MODEL NODE | SET ORTHO VECTOR | CANCEL | end"
                )
                else
                (
                    picked_vector = vector_end - vector_start
                    vector_xy = [picked_vector.x, picked_vector.y, 0.0]
                    dumpSceneModelManagerUi ("MODEL NODE | SET ORTHO VECTOR | VECTOR | start=" + (vector_start as string) + " | end=" + (vector_end as string) + " | vector=" + (picked_vector as string))

                    if length vector_xy == 0.0 then
                    (
                        lbl_node_status.text = "Picked ORTHO XY vector has zero length."
                        dumpSceneModelManagerUi "MODEL NODE | SET ORTHO VECTOR | STOP | zero XY vector"
                    )
                    else
                    (
                        dumpSceneModelManagerUi ("MODEL NODE | SET ORTHO VECTOR | ALIGN PIVOT | target=" + (vector_start as string))
                        move_result = SceneModelManager.moveModelNodePivot model_node vector_start
                        dumpSceneModelManagerUi ("MODEL NODE | SET ORTHO VECTOR | MOVE RESULT | " + (move_result as string))

                        if move_result[1] then
                        (
                            direction_point = model_node.pos + picked_vector
                            result_value = SceneModelManager.setModelNodeOrthoFromDirection model_node direction_point
                            dumpSceneModelManagerUi ("MODEL NODE | SET ORTHO VECTOR | RESULT | " + (result_value as string))

                            if result_value[1] then
                            (
                                lbl_node_status.text = "Pivot aligned to vector START. " + result_value[2]
                            )
                            else
                            (
                                lbl_node_status.text = result_value[2]
                            )
                        )
                        else
                        (
                            lbl_node_status.text = move_result[2]
                        )
                    )
                )
            )
        )
    )

    on btn_refresh_nodes pressed do
    (
        refreshModelNodes()
        lbl_node_status.text = "MODEL NODE list refreshed."
    )

    on rdo_ortho_view changed state_index do
    (
        if not ortho_state_syncing then
        (
            model_node = getSelectedModelNode()

            if model_node == undefined then
            (
                result_value = #(false, "Select a MODEL NODE in the list first.")
            )
            else if state_index == 1 then
            (
                dumpSceneModelManagerUi ("MODEL NODE | ORTHO RADIO | ORTHO | node=" + model_node.name)
                result_value = SceneModelManager.activateModelNodeOrtho model_node
            )
            else
            (
                dumpSceneModelManagerUi ("MODEL NODE | ORTHO RADIO | ORIGINAL | node=" + model_node.name)
                result_value = SceneModelManager.restoreOrthoView model_node:model_node
            )

            dumpSceneModelManagerUi ("MODEL NODE | ORTHO RADIO | RESULT | " + (result_value as string))
            refreshOrthoRadio()
            lbl_node_status.text = result_value[2]
        )
    )

    on scene_model_manager_nodes_rollout rolledUp rollout_is_open do
    (
        setSceneModelManagerIniValue "ModelNodesOpen" (if rollout_is_open then 1 else 0)
    )
)

rollout scene_model_manager_export_rollout "3. MODEL / EXPORT" width:288 height:444
(
    label lbl_export_node "ACTIVE MODEL NODE" pos:[12,12] width:264 height:24
    label lbl_export_node_value "Select one in MODEL NODES." pos:[12,36] width:264 height:36

    dropdownList ddl_target_units "System Units:" pos:[12,84] width:264 items:#("Millimeters", "Centimeters", "Meters", "Kilometers", "Inches", "Feet", "Miles") selection:1
    dropdownList ddl_display_units "Display Units:" pos:[12,120] width:264 items:#("Custom mm", "Generic", "Millimeters", "Centimeters", "Meters", "Kilometers") selection:1

    editText edt_max_path "MAX:" pos:[12,156] width:264 height:24
    button btn_browse_max "BROWSE MAX" pos:[12,192] width:264 height:24
    button btn_create_max "CREATE MODEL MAX COPY" pos:[12,228] width:264 height:24

    editText edt_obj_path "OBJ:" pos:[12,264] width:264 height:24
    button btn_export_obj "EXPORT SELECTED OBJ" pos:[12,300] width:264 height:24
    button btn_export_all "EXPORT ALL TO scene\\export" pos:[12,336] width:264 height:24

    label lbl_export_status "Ready." pos:[12,372] width:264 height:60

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
        saved_target_units = getSceneModelManagerIniInteger "TargetUnitsSelection" 1
        saved_display_units = getSceneModelManagerIniInteger "DisplayUnitsSelection" 1

        if (saved_target_units < 1 or saved_target_units > ddl_target_units.items.count) then saved_target_units = 1
        if (saved_display_units < 1 or saved_display_units > ddl_display_units.items.count) then saved_display_units = 1

        ddl_target_units.selection = saved_target_units
        ddl_display_units.selection = saved_display_units
        refreshExportState()
    )

    on ddl_target_units selected selection_index do
    (
        setSceneModelManagerIniValue "TargetUnitsSelection" selection_index
    )

    on ddl_display_units selected selection_index do
    (
        setSceneModelManagerIniValue "DisplayUnitsSelection" selection_index
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
            dumpSceneModelManagerUi ("EXPORT | MAX COPY | START | path=" + edt_max_path.text)
            result_value = SceneModelManager.createModelMaxCopy model_node edt_max_path.text target_type display_type
            dumpSceneModelManagerUi ("EXPORT | MAX COPY | RESULT | " + (result_value as string))
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
            dumpSceneModelManagerUi ("EXPORT | OBJ | START | path=" + edt_obj_path.text)
            result_value = SceneModelManager.exportModelNodeObj model_node edt_obj_path.text target_type display_type
            dumpSceneModelManagerUi ("EXPORT | OBJ | RESULT | " + (result_value as string))
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
            dumpSceneModelManagerUi ("EXPORT | ALL OBJ | START | folder=" + export_folder)
            result_value = SceneModelManager.exportAllModelNodesObj export_folder target_type display_type
            dumpSceneModelManagerUi ("EXPORT | ALL OBJ | RESULT | " + (result_value as string))
            lbl_export_status.text = "Exported: " + (result_value[1] as string) + " | Failed: " + (result_value[2] as string)
        )
    )

    on scene_model_manager_export_rollout rolledUp rollout_is_open do
    (
        setSceneModelManagerIniValue "ExportOpen" (if rollout_is_open then 1 else 0)
    )
)

rollout scene_model_manager_rollout scene_model_manager_title width:288 height:720
(
    button btn_restart "RESTART" pos:[12,12] width:264 height:24 \
        toolTip:"LMB: Reload the canonical Scene Model Manager entry file."

    subRollout sr_sections "" pos:[0,48] width:288 height:612
    label lbl_footer "Source scene authoritative.\nExports use Hold/Fetch." pos:[12,672] width:264 height:36

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
        dumpSceneModelManagerUi "DIALOG | OPEN"
        try (removeSubRollout sr_sections scene_model_manager_prepare_rollout) catch ()
        try (removeSubRollout sr_sections scene_model_manager_nodes_rollout) catch ()
        try (removeSubRollout sr_sections scene_model_manager_export_rollout) catch ()

        prepare_open = getSceneModelManagerIniBoolean "PrepareOpen" true
        model_nodes_open = getSceneModelManagerIniBoolean "ModelNodesOpen" true
        export_open = getSceneModelManagerIniBoolean "ExportOpen" true

        addSubRollout sr_sections scene_model_manager_prepare_rollout rolledUp:(not prepare_open)
        addSubRollout sr_sections scene_model_manager_nodes_rollout rolledUp:(not model_nodes_open)
        addSubRollout sr_sections scene_model_manager_export_rollout rolledUp:(not export_open)

        current_dialog_height = scene_model_manager_rollout.height
        sr_sections.height = amax 300 (current_dialog_height - 108)
        lbl_footer.pos.y = current_dialog_height - 48
        windows.processPostedMessages()
    )

    on scene_model_manager_rollout moved dialog_pos do
    (
        saveSceneModelManagerDialogState dialog_pos:dialog_pos
    )

    on scene_model_manager_rollout resized dialog_size do
    (
        new_height = amax 300 (dialog_size.y - 108)
        sr_sections.height = new_height
        lbl_footer.pos.y = dialog_size.y - 48
        saveSceneModelManagerDialogState dialog_size:dialog_size
    )

    on scene_model_manager_rollout close do
    (
        dumpSceneModelManagerUi "DIALOG | CLOSE"
        saveSceneModelManagerDialogState()
        try (removeSubRollout sr_sections scene_model_manager_prepare_rollout) catch ()
        try (removeSubRollout sr_sections scene_model_manager_nodes_rollout) catch ()
        try (removeSubRollout sr_sections scene_model_manager_export_rollout) catch ()
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

    dialog_x = getSceneModelManagerIniInteger "DialogX" 120
    dialog_y = getSceneModelManagerIniInteger "DialogY" 120
    dialog_height = getSceneModelManagerIniInteger "DialogHeight" 720

    if dialog_height < 408 then dialog_height = 408

    createDialog scene_model_manager_rollout \
        width:288 \
        height:dialog_height \
        pos:[dialog_x, dialog_y] \
        lockWidth:true \
        lockHeight:false \
        autoLayoutOnResize:false \
        style:#(#style_titlebar, #style_sysmenu, #style_resizing)
    windows.processPostedMessages()
    true
    -- return
)
