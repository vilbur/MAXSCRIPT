/*
Scene Offset Tool 0.13
Standalone diagnostic utility for temporarily moving a large-coordinate 3ds Max scene near world origin.

Rules:
- SCENE_OFFSET_DATA is a visual Point helper only.
- Authoritative offset data is stored in the helper's User Defined Properties.
- Only top-level scene nodes are translated so child hierarchies are not moved twice.
- Restore uses the stored node handles and stored millimeter offset.
- Pivot centering does not collapse the modifier stack.
*/

global SceneOffsetTool
global scene_offset_tool_rollout
global scene_offset_tool_title

try
(
    destroyDialog scene_offset_tool_rollout
)
catch
(
)

struct SceneOffsetTool_v
(
    file_version = 0.13,
    project_version = 0.13,
    helper_name = "SCENE_OFFSET_DATA",

    /*
    Returns the persistent scene-offset helper when it exists.
    The helper transform is never used as authoritative offset data.
    */
    function getOffsetHelper =
    (
        helper_node = getNodeByName helper_name

        if helper_node != undefined and isValidNode helper_node then
        (
            return helper_node
        )

        undefined
        -- return
    ),

    /*
    Creates the persistent Point helper on the default Layer 0.
    Its position is visual only; restoration uses User Defined Properties.
    */
    function createOffsetHelper =
    (
        helper_node = getOffsetHelper()
        if helper_node != undefined then return helper_node

        helper_node = Point \
            name:helper_name \
            size:20.0 \
            centermarker:true \
            axistripod:true \
            cross:true \
            box:true \
            constantscreensize:true \
            drawontop:true

        helper_node.wirecolor = color 255 140 0

        default_layer = LayerManager.getLayer 0
        if default_layer != undefined then
        (
            default_layer.addNode helper_node
        )

        setUserPropVal helper_node "SO_TOOL_VERSION" file_version
        setUserPropVal helper_node "SO_ACTIVE" false
        setUserPropVal helper_node "SO_OFFSET_X_MM" 0.0d0
        setUserPropVal helper_node "SO_OFFSET_Y_MM" 0.0d0
        setUserPropVal helper_node "SO_OFFSET_Z_MM" 0.0d0
        setUserPropVal helper_node "SO_NODE_HANDLES" #()

        helper_node
        -- return
    ),

    /*
    Returns true only when the helper says a temporary scene offset is active.
    The helper position is intentionally ignored.
    */
    function isOffsetActive =
    (
        helper_node = getOffsetHelper()
        if helper_node == undefined then return false

        active_value = getUserPropVal helper_node "SO_ACTIVE"
        active_value == true
        -- return
    ),

    /*
    Converts a system-unit Point3 to physical millimeters using Double arithmetic.
    The resulting three Doubles are suitable for persistent user-property storage.
    */
    function point3ToMillimeterDoubles point_value =
    (
        millimeter_scale = (units.decodeValue "1mm") as Double
        if millimeter_scale <= 0.0d0 then return undefined

        #(
            (point_value.x as Double) / millimeter_scale,
            (point_value.y as Double) / millimeter_scale,
            (point_value.z as Double) / millimeter_scale
        )
        -- return
    ),

    /*
    Returns how many physical millimeters are represented by one selected UI unit.
    This conversion is internal to the tool and never changes 3ds Max unit settings.
    */
    function getDisplayUnitMillimeterScale unit_name =
    (
        case unit_name of
        (
            "mm": 1.0d0
            "cm": 10.0d0
            "m": 1000.0d0
            default: 1.0d0
        )
        -- return
    ),

    /*
    Converts one physical millimeter value to the currently selected UI unit.
    The result is display-only and does not modify 3ds Max unit settings.
    */
    function millimetersToDisplayValue millimeter_value unit_name =
    (
        unit_scale_mm = getDisplayUnitMillimeterScale unit_name
        if unit_scale_mm <= 0.0d0 then return undefined

        (millimeter_value as Double) / unit_scale_mm
        -- return
    ),

    /*
    Converts one value from the currently selected UI unit to physical millimeters.
    Stored helper metadata remains millimeter based regardless of the displayed unit.
    */
    function displayValueToMillimeters display_value unit_name =
    (
        unit_scale_mm = getDisplayUnitMillimeterScale unit_name
        (display_value as Double) * unit_scale_mm
        -- return
    ),

    /*
    Converts explicit UI offset values to one system-unit Point3 using the selected display unit.
    This conversion is internal to the tool and does not modify 3ds Max unit settings.
    */
    function displayValuesToPoint3 offset_x_value offset_y_value offset_z_value unit_name =
    (
        offset_x_mm = displayValueToMillimeters offset_x_value unit_name
        offset_y_mm = displayValueToMillimeters offset_y_value unit_name
        offset_z_mm = displayValueToMillimeters offset_z_value unit_name

        millimeter_scale = (units.decodeValue "1mm") as Double
        if millimeter_scale <= 0.0d0 then return undefined

        offset_x_system = (((offset_x_mm as Double) * millimeter_scale) as Float)
        offset_y_system = (((offset_y_mm as Double) * millimeter_scale) as Float)
        offset_z_system = (((offset_z_mm as Double) * millimeter_scale) as Float)

        [offset_x_system, offset_y_system, offset_z_system]
        -- return
    ),

    /*
    Returns the combined world bounding-box center of the current selection.
    The persistent scene-offset helper is ignored if it happens to be selected.
    */
    function getSelectionWorldBoundingBoxCenter =
    (
        selection_nodes = selection as array
        helper_node = getOffsetHelper()
        bbox_value = Box3()
        valid_count = 0

        for node_value in selection_nodes do
        (
            if isValidNode node_value and node_value != helper_node then
            (
                bbox_value += node_value.min
                bbox_value += node_value.max
                valid_count += 1
            )
        )

        if valid_count == 0 then return undefined

        bbox_value.center
        -- return
    ),

    /*
    Reads the authoritative stored offset from helper user properties.
    The returned Point3 is in current 3ds Max system units.
    */
    function getStoredOffsetSystemUnits =
    (
        helper_node = getOffsetHelper()
        if helper_node == undefined then return undefined

        offset_x_mm = getUserPropVal helper_node "SO_OFFSET_X_MM"
        offset_y_mm = getUserPropVal helper_node "SO_OFFSET_Y_MM"
        offset_z_mm = getUserPropVal helper_node "SO_OFFSET_Z_MM"

        if offset_x_mm == undefined or offset_y_mm == undefined or offset_z_mm == undefined then
        (
            return undefined
        )

        millimeter_scale = (units.decodeValue "1mm") as Double
        if millimeter_scale <= 0.0d0 then return undefined

        offset_x_value = (((offset_x_mm as Double) * millimeter_scale) as Float)
        offset_y_value = (((offset_y_mm as Double) * millimeter_scale) as Float)
        offset_z_value = (((offset_z_mm as Double) * millimeter_scale) as Float)

        [offset_x_value, offset_y_value, offset_z_value]
        -- return
    ),

    /*
    Returns geometry used to choose the temporary work-origin point.
    Selected geometry is preferred; otherwise all geometry is used.
    */
    function getAnchorGeometry =
    (
        selection_nodes = selection as array
        selected_geometry = #()

        for node_value in geometry do
        (
            if (findItem selection_nodes node_value) > 0 then
            (
                append selected_geometry node_value
            )
        )

        if selected_geometry.count > 0 then return selected_geometry

        all_geometry = #()
        for node_value in geometry do
        (
            append all_geometry node_value
        )

        all_geometry
        -- return
    ),

    /*
    Returns the combined world bounding-box center of the supplied nodes.
    This point becomes the temporary work origin.
    */
    function getNodesWorldBoundingBoxCenter node_array =
    (
        if node_array == undefined or node_array.count == 0 then return undefined

        bbox_value = Box3()

        for node_value in node_array do
        (
            if isValidNode node_value then
            (
                bbox_value += node_value.min
                bbox_value += node_value.max
            )
        )

        bbox_value.center
        -- return
    ),

    /*
    Returns the top-level scene nodes that must move as one scene.
    The persistent offset helper is excluded so it remains only a visual marker.
    */
    function getTopLevelSceneNodes =
    (
        helper_node = getOffsetHelper()
        result_nodes = #()

        for node_value in rootNode.children do
        (
            if isValidNode node_value and node_value != helper_node then
            (
                append result_nodes node_value
            )
        )

        result_nodes
        -- return
    ),

    /*
    Centers pivots on selected geometry, or on all geometry when nothing is selected.
    Geometry stays visually in place and modifier stacks are not collapsed.
    */
    function centerObjectPivots =
    (
        selection_nodes = selection as array
        target_nodes = #()

        for node_value in geometry do
        (
            if selection_nodes.count == 0 or (findItem selection_nodes node_value) > 0 then
            (
                append target_nodes node_value
            )
        )

        if target_nodes.count == 0 then
        (
            return #(false, "No geometry found for pivot centering.")
        )

        centered_count = 0
        failed_count = 0

        undo "Center Object Pivots" on
        (
            for node_value in target_nodes do
            (
                try
                (
                    node_value.pivot = node_value.center
                    centered_count += 1
                )
                catch
                (
                    failed_count += 1
                )
            )
        )

        message_text = "Centered pivots: " + centered_count as string
        if failed_count > 0 then
        (
            message_text += " | Failed: " + failed_count as string
        )

        #(true, message_text)
        -- return
    ),

    /*
    Stores authoritative offset metadata on the helper.
    The Point helper is placed at the original anchor only as a visual reference.
    */
    function storeOffsetData helper_node offset_value moved_handles =
    (
        offset_mm = point3ToMillimeterDoubles offset_value
        if offset_mm == undefined then return false

        setUserPropVal helper_node "SO_OFFSET_X_MM" offset_mm[1]
        setUserPropVal helper_node "SO_OFFSET_Y_MM" offset_mm[2]
        setUserPropVal helper_node "SO_OFFSET_Z_MM" offset_mm[3]
        setUserPropVal helper_node "SO_NODE_HANDLES" moved_handles
        setUserPropVal helper_node "SO_ACTIVE" true

        helper_node.pos = offset_value
        true
        -- return
    ),

    /*
    Moves all current top-level scene nodes so the selected/all geometry center becomes world zero.
    Only nodes that were successfully moved are recorded for restoration.
    */
    function offsetSceneToWorkOrigin offset_value:undefined =
    (
        if isOffsetActive() then
        (
            return #(false, "Offset is already active. Restore it first.")
        )

        anchor_value = offset_value

        if anchor_value == undefined then
        (
            anchor_nodes = getAnchorGeometry()
            anchor_value = getNodesWorldBoundingBoxCenter anchor_nodes
        )

        if anchor_value == undefined then
        (
            return #(false, "No offset value is available.")
        )

        helper_node = createOffsetHelper()
        if helper_node == undefined then
        (
            return #(false, "Could not create SCENE_OFFSET_DATA.")
        )

        top_nodes = getTopLevelSceneNodes()
        if top_nodes.count == 0 then
        (
            return #(false, "No top-level scene nodes found.")
        )

        move_delta = -anchor_value
        moved_handles = #()
        failed_count = 0

        undo "Offset Scene To Work Origin" on
        (
            for node_value in top_nodes do
            (
                move_ok = true

                try
                (
                    in coordsys world
                    (
                        move node_value move_delta
                    )
                )
                catch
                (
                    move_ok = false
                )

                if move_ok then
                (
                    append moved_handles node_value.inode.handle
                )
                else
                (
                    failed_count += 1
                )
            )

            storeOffsetData helper_node anchor_value moved_handles
        )

        message_text = "Scene offset active | Moved roots: " + moved_handles.count as string
        if failed_count > 0 then
        (
            message_text += " | Failed: " + failed_count as string
        )

        #(true, message_text)
        -- return
    ),

    /*
    Restores only nodes recorded by the active helper.
    The stored millimeter offset is authoritative; the helper transform is ignored.
    */
    function restoreSceneOffset =
    (
        helper_node = getOffsetHelper()
        if helper_node == undefined then
        (
            return #(false, "SCENE_OFFSET_DATA was not found.")
        )

        if not(isOffsetActive()) then
        (
            return #(false, "No active scene offset is stored.")
        )

        offset_value = getStoredOffsetSystemUnits()
        if offset_value == undefined then
        (
            return #(false, "Stored offset data is incomplete.")
        )

        stored_handles = getUserPropVal helper_node "SO_NODE_HANDLES"
        if stored_handles == undefined then stored_handles = #()

        restored_count = 0
        missing_count = 0
        skipped_parented_count = 0

        undo "Restore Scene Offset" on
        (
            for node_handle in stored_handles do
            (
                node_value = maxOps.getNodeByHandle node_handle

                if node_value == undefined or not(isValidNode node_value) then
                (
                    missing_count += 1
                )
                else if node_value.parent != undefined then
                (
                    skipped_parented_count += 1
                )
                else
                (
                    restore_ok = true

                    try
                    (
                        in coordsys world
                        (
                            move node_value offset_value
                        )
                    )
                    catch
                    (
                        restore_ok = false
                    )

                    if restore_ok then
                    (
                        restored_count += 1
                    )
                    else
                    (
                        missing_count += 1
                    )
                )
            )

            setUserPropVal helper_node "SO_ACTIVE" false
        )

        message_text = "Scene restored | Roots: " + restored_count as string

        if missing_count > 0 then
        (
            message_text += " | Missing/failed: " + missing_count as string
        )

        if skipped_parented_count > 0 then
        (
            message_text += " | Reparented skipped: " + skipped_parented_count as string
        )

        #(true, message_text)
        -- return
    ),

    /*
    Returns compact state text for the rollout in the requested UI display unit.
    Stored helper metadata remains millimeter based and the helper position is not consulted.
    */
    function getStateText display_unit_name:"mm" =
    (
        helper_node = getOffsetHelper()

        if helper_node == undefined then
        (
            return "State: no offset helper"
        )

        if not(isOffsetActive()) then
        (
            return "State: offset inactive"
        )

        offset_x_mm = getUserPropVal helper_node "SO_OFFSET_X_MM"
        offset_y_mm = getUserPropVal helper_node "SO_OFFSET_Y_MM"
        offset_z_mm = getUserPropVal helper_node "SO_OFFSET_Z_MM"

        if offset_x_mm == undefined or offset_y_mm == undefined or offset_z_mm == undefined then
        (
            return "State: active, stored data incomplete"
        )

        offset_x_display = millimetersToDisplayValue offset_x_mm display_unit_name
        offset_y_display = millimetersToDisplayValue offset_y_mm display_unit_name
        offset_z_display = millimetersToDisplayValue offset_z_mm display_unit_name

        "State: ACTIVE | X " + formattedPrint offset_x_display format:"0.3f" + \
        " | Y " + formattedPrint offset_y_display format:"0.3f" + \
        " | Z " + formattedPrint offset_z_display format:"0.3f" + " " + display_unit_name
        -- return
    ),

    on create do
    (
    )
)

SceneOffsetTool = SceneOffsetTool_v()
scene_offset_tool_title = "Scene Offset Tool " + (formattedPrint SceneOffsetTool.project_version format:"0.2f")

rollout scene_offset_tool_rollout scene_offset_tool_title width:350 height:232
(
    local current_unit_name = "mm"
    local radio_syncing = false

    label lbl_pivots "Object pivots" pos:[10,10] width:330 height:18

    button btn_center_pivots "CENTER PIVOTS TO OBJECTS" pos:[10,29] width:160 height:26 \
        tooltip:"Centers pivots on selected geometry; if nothing is selected, processes all geometry."

    button btn_helper "SELECT HELPER" pos:[175,29] width:165 height:26 \
        tooltip:"Selects the persistent helper that stores the authoritative offset metadata."

    label lbl_scene "Temporary scene offset" pos:[10,63] width:330 height:18

    spinner spn_offset_x "X" pos:[10,82] width:84 height:20 fieldWidth:58 range:[-1000000000.0,1000000000.0,0.0] type:#float scale:0.001
    spinner spn_offset_y "Y" pos:[98,82] width:84 height:20 fieldWidth:58 range:[-1000000000.0,1000000000.0,0.0] type:#float scale:0.001
    spinner spn_offset_z "Z" pos:[186,82] width:84 height:20 fieldWidth:58 range:[-1000000000.0,1000000000.0,0.0] type:#float scale:0.001
    dropdownlist ddl_offset_unit "" pos:[278,78] width:62 height:5 items:#("mm", "cm", "m") selection:1 \
        tooltip:"Changes only how offset values are shown and entered in this tool."

    button btn_from_selection "FROM SELECTION" pos:[10,110] width:160 height:24 \
        tooltip:"Fill X, Y, and Z from the current selection's combined world bounding-box center."

    button btn_round "ROUND" pos:[175,110] width:165 height:24 \
        tooltip:"Round X, Y, and Z to a practical grid based on the selected display unit."

    radiobuttons rdo_scene_state labels:#("OFFSET", "RESTORE") default:2 columns:2 pos:[85,140] width:180 height:27 align:#center \
        tooltip:#("Apply the current XYZ offset to the scene.", "Restore the scene from SCENE_OFFSET_DATA.")

    label lbl_state "State:" pos:[10,174] width:330 height:18
    label lbl_status "" pos:[10,194] width:330 height:30

    /*
    Returns the practical rounding step for the selected UI display unit.
    Each display unit uses its own practical rounding step.
    */
    function getNiceRoundStep unit_name =
    (
        case unit_name of
        (
            "mm": 100.0d0
            "cm": 10.0d0
            "m": 100.0d0
            default: 100.0d0
        )
        -- return
    )

    /*
    Rounds one signed value to the nearest supplied step.
    Half-step values round away from zero for predictable symmetric behavior.
    */
    function roundValueToStep input_value step_value =
    (
        value_double = input_value as Double
        step_double = step_value as Double
        if step_double <= 0.0d0 then return value_double

        sign_value = if value_double < 0.0d0 then -1.0d0 else 1.0d0
        rounded_value = (floor (((abs value_double) / step_double) + 0.5d0)) * step_double
        rounded_value * sign_value
        -- return
    )

    /*
    Returns the currently selected UI display unit name.
    This unit affects only the three visible offset spinners.
    */
    function getCurrentDisplayUnit =
    (
        if ddl_offset_unit.selection < 1 then return "mm"
        ddl_offset_unit.items[ddl_offset_unit.selection]
        -- return
    )

    /*
    Converts all three visible spinner values between UI display units.
    Physical offset values remain unchanged while the displayed numbers are rescaled.
    */
    function convertVisibleOffsetUnits old_unit_name new_unit_name =
    (
        if old_unit_name == new_unit_name then return true

        offset_x_mm = SceneOffsetTool.displayValueToMillimeters spn_offset_x.value old_unit_name
        offset_y_mm = SceneOffsetTool.displayValueToMillimeters spn_offset_y.value old_unit_name
        offset_z_mm = SceneOffsetTool.displayValueToMillimeters spn_offset_z.value old_unit_name

        spn_offset_x.value = (SceneOffsetTool.millimetersToDisplayValue offset_x_mm new_unit_name) as Float
        spn_offset_y.value = (SceneOffsetTool.millimetersToDisplayValue offset_y_mm new_unit_name) as Float
        spn_offset_z.value = (SceneOffsetTool.millimetersToDisplayValue offset_z_mm new_unit_name) as Float
        true
        -- return
    )

    /*
    Fills the visible offset fields from the current selection center when selection exists.
    Values are converted to the currently selected UI unit and remain editable before scene movement.
    */
    function prefillOffsetFromSelection =
    (
        selection_center = SceneOffsetTool.getSelectionWorldBoundingBoxCenter()
        if selection_center == undefined then return false

        offset_mm = SceneOffsetTool.point3ToMillimeterDoubles selection_center
        if offset_mm == undefined then return false

        unit_name = getCurrentDisplayUnit()
        spn_offset_x.value = (SceneOffsetTool.millimetersToDisplayValue offset_mm[1] unit_name) as Float
        spn_offset_y.value = (SceneOffsetTool.millimetersToDisplayValue offset_mm[2] unit_name) as Float
        spn_offset_z.value = (SceneOffsetTool.millimetersToDisplayValue offset_mm[3] unit_name) as Float
        true
        -- return
    )

    /*
    Synchronizes the OFFSET / RESTORE radio selection with the real helper state.
    Programmatic synchronization is guarded so it cannot execute scene actions recursively.
    */
    function syncSceneStateRadio =
    (
        radio_syncing = true
        rdo_scene_state.state = if SceneOffsetTool.isOffsetActive() then 1 else 2
        radio_syncing = false
        true
        -- return
    )

    function refreshState =
    (
        lbl_state.text = SceneOffsetTool.getStateText display_unit_name:(getCurrentDisplayUnit())
        true
        -- return
    )

    on btn_center_pivots pressed do
    (
        result_value = SceneOffsetTool.centerObjectPivots()
        lbl_status.text = result_value[2]
        refreshState()
    )

    on ddl_offset_unit selected unit_index do
    (
        new_unit_name = ddl_offset_unit.items[unit_index]
        convertVisibleOffsetUnits current_unit_name new_unit_name
        current_unit_name = new_unit_name
        refreshState()
    )

    on btn_from_selection pressed do
    (
        if prefillOffsetFromSelection() then
        (
            lbl_status.text = "Offset filled from current selection center."
        )
        else
        (
            lbl_status.text = "No valid current selection."
        )
    )

    on btn_round pressed do
    (
        unit_name = getCurrentDisplayUnit()
        round_step = getNiceRoundStep unit_name

        spn_offset_x.value = (roundValueToStep spn_offset_x.value round_step) as Float
        spn_offset_y.value = (roundValueToStep spn_offset_y.value round_step) as Float
        spn_offset_z.value = (roundValueToStep spn_offset_z.value round_step) as Float

        step_label = case unit_name of
        (
            "mm": "100 mm"
            "cm": "10 cm"
            "m": "100 m"
            default: "100 mm"
        )

        lbl_status.text = "Rounded XYZ to " + step_label + " grid."
    )

    on rdo_scene_state changed state_index do
    (
        if not(radio_syncing) then
        (
            if state_index == 1 then
            (
                unit_name = getCurrentDisplayUnit()
                offset_value = SceneOffsetTool.displayValuesToPoint3 spn_offset_x.value spn_offset_y.value spn_offset_z.value unit_name

                if offset_value == undefined then
                (
                    lbl_status.text = "Could not convert the offset values."
                )
                else
                (
                    result_value = SceneOffsetTool.offsetSceneToWorkOrigin offset_value:offset_value
                    lbl_status.text = result_value[2]
                )
            )
            else if state_index == 2 then
            (
                result_value = SceneOffsetTool.restoreSceneOffset()
                lbl_status.text = result_value[2]
            )

            syncSceneStateRadio()
            refreshState()
        )
    )

    on btn_helper pressed do
    (
        helper_node = SceneOffsetTool.getOffsetHelper()

        if helper_node == undefined then
        (
            lbl_status.text = "SCENE_OFFSET_DATA was not found."
        )
        else
        (
            select helper_node
            lbl_status.text = "Selected SCENE_OFFSET_DATA."
        )

        refreshState()
    )

    on scene_offset_tool_rollout open do
    (
        current_unit_name = getCurrentDisplayUnit()
        prefillOffsetFromSelection()
        syncSceneStateRadio()
        refreshState()
    )
)

createDialog scene_offset_tool_rollout style:#(#style_titlebar, #style_sysmenu, #style_toolwindow)
