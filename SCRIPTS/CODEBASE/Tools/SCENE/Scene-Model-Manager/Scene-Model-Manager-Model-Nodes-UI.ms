/*
Scene Model Manager MODEL NODES rollout module.
File version: 0.001
Project version: 0.033

Loaded by Scene-Model-Manager.ms after the common UI file.
The rollout owns MODEL NODE UI only; scene/member operations remain in SceneModelManager.
*/

global scene_model_manager_nodes_rollout
global scene_model_manager_export_rollout
global scene_model_manager_ui_ini_file
global scene_model_manager_project_version
global smmModelNodesDump
global smmModelNodesSetIniValue
global smmModelNodesGetIniInteger

if (scene_model_manager_project_version == undefined or scene_model_manager_project_version < 0.033) then
(
    scene_model_manager_project_version = 0.033
)

/*
Writes one MODEL NODES UI trace through the project DUMP logger.
*/
function smmModelNodesDump log_value =
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

/*
Writes one MODEL NODES UI setting to the existing Scene Model Manager INI file.
*/
function smmModelNodesSetIniValue key_name setting_value =
(
    setINISetting scene_model_manager_ui_ini_file "UI" key_name (setting_value as string)
    true
    -- return
)

/*
Reads one persisted MODEL NODES integer setting or returns the supplied default.
*/
function smmModelNodesGetIniInteger key_name default_value =
(
    setting_text = getINISetting scene_model_manager_ui_ini_file "UI" key_name

    if setting_text == "" then
    (
        default_value
    )
    else
    (
        try
        (
            setting_text as integer
        )
        catch
        (
            default_value
        )
    )
    -- return
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

    checkbutton chk_bind_layer_members "BIND MATCHING LAYER" pos:[24,276] width:240 height:24 checked:false \
        toolTip:"ON: The exact same-named scene layer becomes authoritative for MODEL MEMBERS. Before member-dependent node operations, missing top hierarchy roots are linked and stale roots are unlinked automatically. ADD SELECTED / REMOVE SELECTED are disabled.\n\nOFF: Membership is edited manually with ADD SELECTED / REMOVE SELECTED."

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
    local bind_matching_state_syncing = false

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
    Synchronizes BIND MATCHING LAYER and manual MODEL MEMBER controls from the selected MODEL NODE.
    Manual ADD / REMOVE actions are frozen while the layer-authoritative mode is enabled.
    */
    function refreshModelMemberControls =
    (
        model_node = getSelectedModelNode()
        has_model_node = SceneModelManager.isModelNode model_node
        bind_matching_enabled = false

        if has_model_node then
        (
            bind_matching_enabled = SceneModelManager.isModelNodeBindMatchingLayer model_node
        )

        bind_matching_state_syncing = true
        chk_bind_layer_members.enabled = has_model_node
        chk_bind_layer_members.checked = bind_matching_enabled
        btn_add_members.enabled = (has_model_node and not bind_matching_enabled)
        btn_remove_members.enabled = (has_model_node and not bind_matching_enabled)
        btn_select_members.enabled = has_model_node
        bind_matching_state_syncing = false
        true
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

        smmModelNodesDump ("MODEL NODE | NAME PROMPT | modal=" + (modal_result as string) + " | result=" + (entered_name as string))

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
        refreshModelMemberControls()
        refreshOrthoRadio()
    )

    /*
    Synchronizes layer-authoritative MODEL MEMBERS before one member-dependent node operation.
    BIND MATCHING LAYER OFF is a successful no-op; BIND MATCHING LAYER failures abort the requested operation.
    */
    function prepareBoundMatchingLayerMembers model_node operation_name =
    (
        sync_result = SceneModelManager.syncBoundMatchingLayerMembers model_node
        smmModelNodesDump ("MODEL MEMBERS | BIND MATCHING LAYER BEFORE " + operation_name + " | " + (sync_result as string))

        if (sync_result[1] and SceneModelManager.isModelNodeBindMatchingLayer model_node) then
        (
            refreshModelNodes keep_node:model_node
        )

        sync_result
        -- return
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
                smmModelNodesDump ("MODEL NODE | LIVE SETTINGS | ratio=" + (spn_ratio.value as string) + " | sizeCm=" + (spn_text_size.value as string) + " | ok=" + (update_ok as string))

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
            refreshModelMemberControls()
            refreshOrthoRadio()
        )
    )

    on scene_model_manager_nodes_rollout open do
    (
        saved_ratio = smmModelNodesGetIniInteger "DefaultRatio" 150
        saved_text_size = smmModelNodesGetIniInteger "DefaultTextSizeCm" 100

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
        smmModelNodesSetIniValue "DefaultRatio" spinner_value

        if not node_controls_syncing then
        (
            applyLiveNodeSettings refresh_list:true
        )
    )

    on spn_text_size changed spinner_value do
    (
        smmModelNodesSetIniValue "DefaultTextSizeCm" spinner_value

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
        smmModelNodesDump ("MODEL NODE | CREATE | NAME PROMPT | defaultName=" + default_name)
        model_name = promptModelNodeName default_name

        if model_name == undefined then
        (
            lbl_node_status.text = "MODEL NODE creation cancelled."
            smmModelNodesDump "MODEL NODE | CREATE | CANCELLED AT NAME"
        )
        else
        (
            member_nodes = getCreationMemberNodes()
            smmModelNodesDump ("MODEL NODE | CREATE | SELECTION | count=" + (member_nodes.count as string))

            if member_nodes.count == 0 then
            (
                lbl_node_status.text = "Select objects before creating a MODEL NODE."
                smmModelNodesDump "MODEL NODE | CREATE | STOP | no selection"
            )
            else
            (
                member_roots = SceneModelManager.getTopModelMemberRoots member_nodes

                if member_roots.count == 0 then
                (
                    lbl_node_status.text = "No top hierarchy roots are selected."
                    smmModelNodesDump "MODEL NODE | CREATE | STOP | no top hierarchy roots"
                )
                else
                (
                    model_node = SceneModelManager.createModelNode model_name member_nodes undefined spn_ratio.value (getTextSizeSystemValue())
                    smmModelNodesDump ("MODEL NODE | CREATE | RESULT | node=" + (model_node as string) + " | name=" + model_name + " | source=" + (member_nodes.count as string) + " | roots=" + (member_roots.count as string))

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
        else if SceneModelManager.isModelNodeBindMatchingLayer model_node then
        (
            lbl_node_status.text = "BIND MATCHING LAYER is ON. Membership follows the matching layer."
        )
        else
        (
            smmModelNodesDump ("MODEL MEMBERS | ADD SELECTED | START | selection=" + (selection.count as string))
            added_count = SceneModelManager.addSelectionToModelNode model_node
            smmModelNodesDump ("MODEL MEMBERS | ADD SELECTED | RESULT | added=" + (added_count as string))
            refreshModelNodes keep_node:model_node
            lbl_node_status.text = "Added top member roots: " + (added_count as string)
        )
    )

    on chk_bind_layer_members changed checked_state do
    (
        if not bind_matching_state_syncing then
        (
            model_node = getSelectedModelNode()

            if model_node == undefined then
            (
                bind_matching_state_syncing = true
                chk_bind_layer_members.checked = false
                bind_matching_state_syncing = false
                lbl_node_status.text = "Select a MODEL NODE in the list first."
            )
            else
            (
                mode_ok = SceneModelManager.setModelNodeBindMatchingLayer model_node checked_state
                smmModelNodesDump ("MODEL MEMBERS | BIND MATCHING LAYER MODE | enabled=" + (checked_state as string) + " | ok=" + (mode_ok as string))
                refreshModelMemberControls()

                if not mode_ok then
                (
                    lbl_node_status.text = "Could not change BIND MATCHING LAYER mode."
                )
                else if checked_state then
                (
                    sync_result = SceneModelManager.syncBoundMatchingLayerMembers model_node
                    smmModelNodesDump ("MODEL MEMBERS | BIND MATCHING LAYER ENABLE SYNC | " + (sync_result as string))

                    if sync_result[1] then refreshModelNodes keep_node:model_node
                    lbl_node_status.text = sync_result[5]
                )
                else
                (
                    lbl_node_status.text = "BIND MATCHING LAYER OFF. Manual membership editing enabled."
                )
            )
        )
    )

    on btn_remove_members pressed do
    (
        model_node = getSelectedModelNode()

        if model_node == undefined then
        (
            lbl_node_status.text = "Select a MODEL NODE in the list first."
        )
        else if SceneModelManager.isModelNodeBindMatchingLayer model_node then
        (
            lbl_node_status.text = "BIND MATCHING LAYER is ON. Membership follows the matching layer."
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
            sync_result = prepareBoundMatchingLayerMembers model_node "SELECT MEMBERS"

            if sync_result[1] then
            (
                member_count = SceneModelManager.selectModelNodeMembers model_node
                lbl_node_status.text = "Selected member roots: " + (member_count as string)
            )
            else
            (
                lbl_node_status.text = sync_result[5]
            )
        )
    )

    on btn_set_ortho pressed do
    (
        smmModelNodesDump "MODEL NODE | SET ORTHO VECTOR | START"
        model_node = getSelectedModelNode()

        if model_node == undefined then
        (
            lbl_node_status.text = "Select a MODEL NODE in the list first."
            smmModelNodesDump "MODEL NODE | SET ORTHO VECTOR | STOP | no MODEL NODE selected"
        )
        else
        (
            sync_result = prepareBoundMatchingLayerMembers model_node "SET ORTHO DIRECTION"

            if not sync_result[1] then
            (
                lbl_node_status.text = sync_result[5]
                smmModelNodesDump ("MODEL NODE | SET ORTHO VECTOR | STOP | BIND MATCHING LAYER | " + sync_result[5])
            )
            else if SceneModelManager.isModelNodeOrthoActive model_node then
            (
                lbl_node_status.text = "Return this MODEL NODE to ORIGINAL before redefining its direction."
                smmModelNodesDump "MODEL NODE | SET ORTHO VECTOR | STOP | selected MODEL NODE ORTHO active"
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
                    smmModelNodesDump "MODEL NODE | SET ORTHO VECTOR | CANCEL | start"
                )
                else
                (
                    smmModelNodesDump ("MODEL NODE | SET ORTHO VECTOR | START POINT | " + (vector_start as string))
                    lbl_node_status.text = "Pick ORTHO vector END..."
                    windows.processPostedMessages()

                    vector_end = pickPoint \
                        prompt:"Pick MODEL NODE ORTHO vector END" \
                        rubberBand:vector_start \
                        snap:#3D

                    if (vector_end == #escape or vector_end == #rightClick) then
                    (
                        lbl_node_status.text = "ORTHO vector pick cancelled at END."
                        smmModelNodesDump "MODEL NODE | SET ORTHO VECTOR | CANCEL | end"
                    )
                    else
                    (
                        picked_vector = vector_end - vector_start
                        vector_xy = [picked_vector.x, picked_vector.y, 0.0]
                        smmModelNodesDump ("MODEL NODE | SET ORTHO VECTOR | VECTOR | start=" + (vector_start as string) + " | end=" + (vector_end as string) + " | vector=" + (picked_vector as string))

                        if length vector_xy == 0.0 then
                        (
                            lbl_node_status.text = "Picked ORTHO XY vector has zero length."
                            smmModelNodesDump "MODEL NODE | SET ORTHO VECTOR | STOP | zero XY vector"
                        )
                        else
                        (
                            smmModelNodesDump ("MODEL NODE | SET ORTHO VECTOR | ALIGN PIVOT | target=" + (vector_start as string))
                            move_result = SceneModelManager.moveModelNodePivot model_node vector_start
                            smmModelNodesDump ("MODEL NODE | SET ORTHO VECTOR | MOVE RESULT | " + (move_result as string))

                            if move_result[1] then
                            (
                                direction_point = model_node.pos + picked_vector
                                result_value = SceneModelManager.setModelNodeOrthoFromDirection model_node direction_point
                                smmModelNodesDump ("MODEL NODE | SET ORTHO VECTOR | RESULT | " + (result_value as string))

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
            else
            (
                sync_result = prepareBoundMatchingLayerMembers model_node "ORTHO / ORIGINAL"

                if not sync_result[1] then
                (
                    result_value = #(false, sync_result[5])
                )
                else if state_index == 1 then
                (
                    smmModelNodesDump ("MODEL NODE | ORTHO RADIO | ORTHO | node=" + model_node.name)
                    result_value = SceneModelManager.activateModelNodeOrtho model_node
                )
                else
                (
                    smmModelNodesDump ("MODEL NODE | ORTHO RADIO | ORIGINAL | node=" + model_node.name)
                    result_value = SceneModelManager.restoreOrthoView model_node:model_node
                )
            )

            smmModelNodesDump ("MODEL NODE | ORTHO RADIO | RESULT | " + (result_value as string))
            refreshOrthoRadio()
            lbl_node_status.text = result_value[2]
        )
    )

    on scene_model_manager_nodes_rollout rolledUp rollout_is_open do
    (
        smmModelNodesSetIniValue "ModelNodesOpen" (if rollout_is_open then 1 else 0)
    )
)
