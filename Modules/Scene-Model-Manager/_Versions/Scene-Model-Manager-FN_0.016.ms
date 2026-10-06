/*
Scene Model Manager backend.
File version: 0.016
Project version: 0.016

Built from the tested uploaded source tools:
- Scene-Rescaler.ms
- Scene-Offset-Tool_0.13.ms
- Rotate-To-Ortho_0.01.ms
- convertSystemUnitsMmToMetersByMerge.ms
*/

global SceneModelManager
global scene_model_manager_project_version

if (scene_model_manager_project_version == undefined or scene_model_manager_project_version < 0.016) then
(
    scene_model_manager_project_version = 0.016
)

struct SceneModelManager_v
(
    file_version = 0.016,
    project_version = 0.016,
    offset_helper_name = "SCENE_OFFSET_DATA",
    ortho_driver_name = "SCENE_MODEL_ORTHO_DRIVER",
    model_node_layer_name = "_MODEL_NODES",
    helper_layer_name = "_HELPERS>Scene-Model-Manager",
    outlier_handles = #(),
    target_unit_names = #(#Millimeters, #Centimeters, #Meters, #Kilometers, #Inches, #Feet, #Miles),
    display_unit_names = #(#CustomMillimeter, #Generic, #Millimeters, #Centimeters, #Meters, #Kilometers),

    /*
    Returns one named physical unit expressed in millimeters.
    This preserves the tested Scene Rescaler unit conversion model.
    */
    function getUnitMillimeters unit_name =
    (
        unit_mm = 1.0

        case unit_name of
        (
            #Millimeters: unit_mm = 1.0
            #Centimeters: unit_mm = 10.0
            #Meters: unit_mm = 1000.0
            #Kilometers: unit_mm = 1000000.0
            #Inches: unit_mm = 25.4
            #Feet: unit_mm = 304.8
            #Miles: unit_mm = 1609344.0
            default: unit_mm = 1.0
        )

        unit_mm
        -- return
    ),

    /*
    Calculates the world rescale factor for the selected physical model ratio.
    Source SystemScale and SystemType are both included in the calculation.
    */
    function calculateScaleFactor source_scale source_type target_type ratio_value =
    (
        source_mm = source_scale * getUnitMillimeters source_type
        target_mm = getUnitMillimeters target_type
        scale_factor = 0.0

        if (ratio_value > 0 and target_mm > 0.0) then
        (
            scale_factor = source_mm / target_mm / ratio_value
        )

        scale_factor
        -- return
    ),

    /*
    Sets the requested display-unit preset without changing scene geometry.
    Custom millimeter mode means one displayed unit is one physical millimeter.
    */
    function setTargetDisplayUnits display_type =
    (
        case display_type of
        (
            #CustomMillimeter:
            (
                units.DisplayType = #custom
                units.CustomName = "mm"
                units.CustomValue = 0.001
                units.CustomUnit = #meters
            )
            #Generic:
            (
                units.DisplayType = #generic
            )
            #Millimeters:
            (
                units.DisplayType = #metric
                units.MetricType = #millimeters
            )
            #Centimeters:
            (
                units.DisplayType = #metric
                units.MetricType = #centimeters
            )
            #Meters:
            (
                units.DisplayType = #metric
                units.MetricType = #meters
            )
            #Kilometers:
            (
                units.DisplayType = #metric
                units.MetricType = #kilometers
            )
            default:
            (
                units.DisplayType = #generic
            )
        )

        true
        -- return
    ),

    /*
    Sets target System Units and Display Units for a temporary model conversion.
    SystemScale is intentionally fixed at exactly 1.0.
    */
    function setTargetUnits target_type display_type =
    (
        units.SystemType = target_type
        units.SystemScale = 1.0
        setTargetDisplayUnits display_type
        true
        -- return
    ),

    /*
    Returns the target System Unit name for one UI dropdown selection.
    Invalid selections fall back to millimeters.
    */
    function getTargetTypeBySelection selection_index =
    (
        target_type = #Millimeters

        if (selection_index >= 1 and selection_index <= target_unit_names.count) then
        (
            target_type = target_unit_names[selection_index]
        )

        target_type
        -- return
    ),

    /*
    Returns the target Display Unit mode for one UI dropdown selection.
    Invalid selections fall back to custom millimeters.
    */
    function getDisplayTypeBySelection selection_index =
    (
        display_type = #CustomMillimeter

        if (selection_index >= 1 and selection_index <= display_unit_names.count) then
        (
            display_type = display_unit_names[selection_index]
        )

        display_type
        -- return
    ),

    /*
    Converts the editing scene to centimeter display while retaining meter System Units.
    This matches the tested mm-to-meter Merge source tool.
    */
    function setEditingDisplayCentimeters =
    (
        units.DisplayType = #custom
        units.CustomName = "cm"
        units.CustomValue = 0.01
        units.CustomUnit = #meters
        true
        -- return
    ),

    /*
    Reports whether the scene uses the required editing System Units.
    Editing System Units are exactly 1 Unit = 1 Meter.
    */
    function isEditingSystemReady =
    (
        (units.SystemType == #meters) and (units.SystemScale == 1.0)
        -- return
    ),


    /*
    Returns true when a node carries the persistent MODEL NODE marker.
    This early helper is used by preparation code before MODEL NODE management functions.
    */
    function isModelNodeMarker node_value =
    (
        if (node_value == undefined or not isValidNode node_value) then
        (
            false
        )
        else
        (
            getUserPropVal node_value "SMM_MODEL_NODE" == true
        )
        -- return
    ),

    /*
    Returns true when the temporary scene-wide ORTHO driver currently exists.
    Preparation and offset operations use this guard before ORTHO methods are reached.
    */
    function hasOrthoDriver =
    (
        driver_node = getNodeByName ortho_driver_name
        (driver_node != undefined and isValidNode driver_node)
        -- return
    ),

    /*
    Converts a saved 1 mm System Units scene to 1 meter System Units through native Merge.
    This is the tested uploaded conversion workflow and keeps physical size unchanged.
    */
    function convertSystemUnitsMmToMetersByMerge =
    (
        source_ready = true
        source_file = ""
        source_size_mm = undefined
        source_object_count = 0

        if maxFileName == "" then
        (
            messageBox "Save the source scene first." title:"Scene Model Manager - Units"
            source_ready = false
        )

        if (source_ready and getSaveRequired()) then
        (
            messageBox "Scene contains unsaved changes.\nSave it first, then run the conversion again." title:"Scene Model Manager - Units"
            source_ready = false
        )

        if (source_ready and ((units.SystemType != #millimeters) or (units.SystemScale != 1.0))) then
        (
            messageBox (
                "Expected source System Units:\n\n" +
                "1 Unit = 1 Millimeter\n\n" +
                "Current:\n" +
                (units.SystemScale as string) + " " +
                (units.SystemType as string)
            ) title:"Scene Model Manager - Units"

            source_ready = false
        )

        if source_ready then
        (
            source_file = maxFilePath + maxFileName
            source_object_count = objects.count

            if objects.count > 0 then
            (
                source_bounds = objects.boundingBox
                source_size_mm = source_bounds.max - source_bounds.min
            )

            continue_conversion = queryBox (
                "The current saved scene will be used as SOURCE.\n\n" +
                "3ds Max will reset to an empty scene and set:\n" +
                "System Units = 1 Meter\n" +
                "Display Units = centimeters\n\n" +
                "Then the source MAX file will be opened through Merge.\n\n" +
                "Continue?"
            ) title:"Scene Model Manager - Units"

            if continue_conversion then
            (
                resetMaxFile #noPrompt

                units.SystemScale = 1.0
                units.SystemType = #meters
                setEditingDisplayCentimeters()

                format "\n========================================\n"
                format "SCENE MODEL MANAGER | MM -> METERS\n"
                format "========================================\n"
                format "Source: %\n" source_file
                format "Target System Units: 1 meter\n"
                format "Target Display Units: 1 cm\n"
                format "\n"
                format "IN THE MERGE DIALOG:\n"
                format "1. Select ALL objects.\n"
                format "2. KEEP 'Rescale Objects to System Unit Scale' ENABLED.\n"
                format "3. Merge.\n"
                format "========================================\n\n"

                merge_ok = mergeMAXFile source_file #prompt quiet:false

                if merge_ok then
                (
                    redrawViews()

                    format "\n========================================\n"
                    format "MERGE FINISHED\n"
                    format "========================================\n"
                    format "System Scale:       %\n" units.SystemScale
                    format "System Type:        %\n" units.SystemType
                    format "Display Type:       %\n" units.DisplayType
                    format "Merged objects:     %\n" objects.count
                    format "Source objects:     %\n" source_object_count

                    if ((objects.count > 0) and (source_size_mm != undefined)) then
                    (
                        target_bounds = objects.boundingBox
                        target_size_m = target_bounds.max - target_bounds.min
                        expected_size_m = source_size_mm / 1000.0

                        format "\nSource size [mm]:   %\n" source_size_mm
                        format "Expected size [m]:  %\n" expected_size_m
                        format "Actual size [m]:    %\n" target_size_m
                    )

                    format "\nSAVE THIS RESULT UNDER A NEW FILE NAME.\n"
                    format "========================================\n\n"
                )
                else
                (
                    format "\nMerge cancelled or failed.\n"
                )

                merge_ok
            )
            else
            (
                false
            )
        )
        else
        (
            false
        )
        -- return
    ),

    /*
    Returns the combined world bounding box of all geometry in the scene.
    Geometry is the authority for exact outlier classification.
    */
    function getGeometryBounds =
    (
        bounds_value = Box3()
        geometry_count = 0

        for node_value in geometry do
        (
            if (isValidNode node_value and classOf node_value != TargetObject) then
            (
                bounds_value += node_value.min
                bounds_value += node_value.max
                geometry_count += 1
            )
        )

        if geometry_count == 0 then
        (
            undefined
        )
        else
        (
            bounds_value
        )
        -- return
    ),

    /*
    Returns true when one world point is inside or exactly on the supplied Box3.
    No hidden distance tolerance is used.
    */
    function isPointInsideBounds point_value bounds_value =
    (
        if bounds_value == undefined then
        (
            false
        )
        else
        (
            (point_value.x >= bounds_value.min.x) and (point_value.x <= bounds_value.max.x) and \
            (point_value.y >= bounds_value.min.y) and (point_value.y <= bounds_value.max.y) and \
            (point_value.z >= bounds_value.min.z) and (point_value.z <= bounds_value.max.z)
        )
        -- return
    ),

    /*
    Detects top-level non-geometry leaf nodes whose pivot lies outside geometry bounds.
    The result is only selected for review; this function never deletes anything.
    */
    function findOutlierCandidates =
    (
        bounds_value = getGeometryBounds()
        candidate_nodes = #()
        outlier_handles = #()

        if bounds_value == undefined then
        (
            #()
        )
        else
        (
            for node_value in rootNode.children do
            (
                is_candidate = \
                    isValidNode node_value and \
                    (superClassOf node_value != GeometryClass) and \
                    (node_value.children.count == 0) and \
                    (not isModelNodeMarker node_value) and \
                    (node_value.name != offset_helper_name) and \
                    (node_value.name != ortho_driver_name)

                if (is_candidate and (not isPointInsideBounds node_value.pos bounds_value)) then
                (
                    append candidate_nodes node_value
                    append outlier_handles node_value.inode.handle
                )
            )

            if candidate_nodes.count > 0 then
            (
                select candidate_nodes
            )

            candidate_nodes
        )
        -- return
    ),

    /*
    Deletes only the candidates found by the most recent outlier scan.
    The UI owns confirmation so this backend function stays deterministic.
    */
    function deleteFoundOutliers =
    (
        deleted_count = 0
        missing_count = 0

        undo "Delete Scene Outlier Candidates" on
        (
            for node_handle in outlier_handles do
            (
                node_value = maxOps.getNodeByHandle node_handle

                if (node_value != undefined and isValidNode node_value) then
                (
                    delete node_value
                    deleted_count += 1
                )
                else
                (
                    missing_count += 1
                )
            )
        )

        outlier_handles = #()
        #(deleted_count, missing_count)
        -- return
    ),

    /*
    Centers pivots on selected geometry, or all geometry when nothing is selected.
    This preserves the tested Scene Offset Tool behavior and does not collapse stacks.
    */
    function centerObjectPivots =
    (
        selection_nodes = selection as array
        target_nodes = #()

        for node_value in geometry do
        (
            if (selection_nodes.count == 0 or (findItem selection_nodes node_value) > 0) then
            (
                append target_nodes node_value
            )
        )

        if target_nodes.count == 0 then
        (
            #(false, "No geometry found for pivot centering.")
        )
        else
        (
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
                        format "Scene Model Manager pivot error | % | %\n" node_value.name (getCurrentException())
                    )
                )
            )

            message_text = "Centered pivots: " + centered_count as string
            if failed_count > 0 then
            (
                message_text += " | Failed: " + failed_count as string
            )

            #(failed_count == 0, message_text)
        )
        -- return
    ),

    /*
    Returns the persistent scene-offset helper when present.
    Position stays at work origin; Z rotation mirrors the stored main scene rotation.
    */
    function getOffsetHelper =
    (
        helper_node = getNodeByName offset_helper_name

        if (helper_node != undefined and isValidNode helper_node) then
        (
            helper_node
        )
        else
        (
            undefined
        )
        -- return
    ),

    /*
    Creates the persistent scene-offset Point helper on Layer 0.
    Stored physical offsets use millimeters exactly as in the tested source tool.
    */
    function createOffsetHelper =
    (
        helper_node = getOffsetHelper()

        if helper_node == undefined then
        (
            helper_node = Point \
                name:offset_helper_name \
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
            setUserPropVal helper_node "SO_MAIN_ROTATION_Z" 0.0
            setUserPropVal helper_node "SO_MAIN_ROTATION_DEFINED_Z" 0.0
            setUserPropVal helper_node "SO_MAIN_ROTATION_DEFINED" false
            setUserPropVal helper_node "SO_MAIN_ROTATION_ACTIVE" false
            helper_node.rotation = ((eulerAngles 0.0 0.0 0.0) as quat)
        )

        helper_node
        -- return
    ),

    /*
    Returns whether a persistent scene offset is currently active.
    The active flag is read from authoritative helper metadata.
    */
    function isOffsetActive =
    (
        helper_node = getOffsetHelper()

        if helper_node == undefined then
        (
            false
        )
        else
        (
            active_value = getUserPropVal helper_node "SO_ACTIVE"
            active_value == true
        )
        -- return
    ),

    /*
    Converts one system-unit Point3 into three physical millimeter Doubles.
    This preserves the tested offset-storage representation.
    */
    function point3ToMillimeterDoubles point_value =
    (
        millimeter_scale = (units.decodeValue "1mm") as Double

        if millimeter_scale <= 0.0d0 then
        (
            undefined
        )
        else
        (
            #(
                (point_value.x as Double) / millimeter_scale,
                (point_value.y as Double) / millimeter_scale,
                (point_value.z as Double) / millimeter_scale
            )
        )
        -- return
    ),

    /*
    Reads the stored physical scene offset into current 3ds Max system units.
    The helper transform is intentionally ignored.
    */
    function getStoredOffsetSystemUnits =
    (
        helper_node = getOffsetHelper()

        if helper_node == undefined then
        (
            undefined
        )
        else
        (
            offset_x_mm = getUserPropVal helper_node "SO_OFFSET_X_MM"
            offset_y_mm = getUserPropVal helper_node "SO_OFFSET_Y_MM"
            offset_z_mm = getUserPropVal helper_node "SO_OFFSET_Z_MM"

            if (offset_x_mm == undefined or offset_y_mm == undefined or offset_z_mm == undefined) then
            (
                undefined
            )
            else
            (
                millimeter_scale = (units.decodeValue "1mm") as Double

                if millimeter_scale <= 0.0d0 then
                (
                    undefined
                )
                else
                (
                    [
                        (((offset_x_mm as Double) * millimeter_scale) as Float),
                        (((offset_y_mm as Double) * millimeter_scale) as Float),
                        (((offset_z_mm as Double) * millimeter_scale) as Float)]
                )
            )
        )
        -- return
    ),

    /*
    Returns geometry used to calculate the work-origin anchor.
    Selected geometry is preferred; otherwise all scene geometry is used.
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

        if selected_geometry.count > 0 then
        (
            selected_geometry
        )
        else
        (
            all_geometry = #()

            for node_value in geometry do
            (
                append all_geometry node_value
            )

            all_geometry
        )
        -- return
    ),

    /*
    Returns the exact combined world bounding-box center of supplied nodes.
    This point becomes the temporary editing origin.
    */
    function getNodesWorldBoundingBoxCenter node_array =
    (
        if (node_array == undefined or node_array.count == 0) then
        (
            undefined
        )
        else
        (
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
        )
        -- return
    ),

    /*
    Returns current top-level scene roots except manager metadata helpers.
    These are the nodes moved together by the global work-origin offset.
    */
    function getOffsetSceneRoots =
    (
        offset_helper = getOffsetHelper()
        ortho_driver = getNodeByName ortho_driver_name
        if (ortho_driver != undefined and not isValidNode ortho_driver) then ortho_driver = undefined
        result_nodes = #()

        for node_value in rootNode.children do
        (
            if (isValidNode node_value and node_value != offset_helper and node_value != ortho_driver) then
            (
                append result_nodes node_value
            )
        )

        result_nodes
        -- return
    ),

    /*
    Returns the exact world-Z angle of one XY direction vector in degrees.
    Uses explicit quadrant handling so scene and MODEL NODE rotation share one reusable operation.
    */
    function getDirectionAngleFromVectorXY direction_vector =
    (
        if direction_vector == undefined then
        (
            undefined
        )
        else
        (
            vector_x = direction_vector.x
            vector_y = direction_vector.y

            if (vector_x == 0.0 and vector_y == 0.0) then
            (
                undefined
            )
            else if vector_x == 0.0 then
            (
                if vector_y > 0.0 then
                (
                    90.0
                )
                else
                (
                    -90.0
                )
            )
            else
            (
                direction_angle = atan (vector_y / vector_x)

                if vector_x < 0.0 then
                (
                    if vector_y >= 0.0 then
                    (
                        direction_angle += 180.0
                    )
                    else
                    (
                        direction_angle -= 180.0
                    )
                )

                direction_angle
            )
        )
        -- return
    ),

    /*
    Returns the correction that aligns one source angle to the nearest world X/Y axis.
    The 90-degree snapping is the explicit ORTHO feature behavior, not a hidden precision tolerance.
    */
    function getNearestAxisRotationDelta direction_angle =
    (
        if direction_angle == undefined then
        (
            undefined
        )
        else
        (
            snapped_angle = if direction_angle >= 135.0 then
            (
                180.0
            )
            else if direction_angle >= 45.0 then
            (
                90.0
            )
            else if direction_angle > -45.0 then
            (
                0.0
            )
            else if direction_angle > -135.0 then
            (
                -90.0
            )
            else
            (
                -180.0
            )

            snapped_angle - direction_angle
        )
        -- return
    ),

    /*
    Returns current applied main scene Z rotation in degrees.
    Older offset helpers without this metadata are treated as zero rotation.
    */
    function getStoredMainRotationZ =
    (
        helper_node = getOffsetHelper()

        if helper_node == undefined then
        (
            0.0
        )
        else
        (
            rotation_z = getUserPropVal helper_node "SO_MAIN_ROTATION_Z"
            if rotation_z == undefined then rotation_z = 0.0
            rotation_z
        )
        -- return
    ),

    /*
    Returns the stored main-rotation definition independently of whether it is currently applied.
    Older helpers fall back to their current rotation or last stored correction.
    */
    function getStoredMainRotationDefinedZ =
    (
        helper_node = getOffsetHelper()

        if helper_node == undefined then
        (
            0.0
        )
        else
        (
            defined_z = getUserPropVal helper_node "SO_MAIN_ROTATION_DEFINED_Z"

            if defined_z == undefined then
            (
                current_z = getStoredMainRotationZ()
                last_delta = getUserPropVal helper_node "SO_MAIN_ROTATION_LAST_DELTA_Z"

                if current_z != 0.0 then
                (
                    defined_z = current_z
                )
                else if last_delta != undefined then
                (
                    defined_z = last_delta
                )
                else
                (
                    defined_z = 0.0
                )
            )

            defined_z
        )
        -- return
    ),

    /*
    Returns true when a main rotation vector has been defined for the active offset helper.
    This state is separate from whether that rotation is currently applied.
    */
    function hasMainRotationDefinition =
    (
        helper_node = getOffsetHelper()

        if helper_node == undefined then
        (
            false
        )
        else
        (
            defined_value = getUserPropVal helper_node "SO_MAIN_ROTATION_DEFINED"

            if defined_value == undefined then
            (
                stored_vector = getUserPropVal helper_node "SO_MAIN_ROTATION_VECTOR_XY"
                stored_vector != undefined
            )
            else
            (
                defined_value == true
            )
        )
        -- return
    ),

    /*
    Returns whether the stored main rotation definition is currently applied to the editing scene.
    Older helpers infer this state from their current applied rotation.
    */
    function isMainRotationActive =
    (
        helper_node = getOffsetHelper()

        if helper_node == undefined then
        (
            false
        )
        else
        (
            active_value = getUserPropVal helper_node "SO_MAIN_ROTATION_ACTIVE"

            if active_value == undefined then
            (
                getStoredMainRotationZ() != 0.0
            )
            else
            (
                active_value == true
            )
        )
        -- return
    ),

    /*
    Applies one absolute main Z rotation through the persistent offset helper.
    Scene roots are linked only for the transform operation and then unlinked with world transforms preserved.
    */
    function applyMainRotationAngleRaw target_angle =
    (
        helper_node = getOffsetHelper()

        if helper_node == undefined then
        (
            false
        )
        else
        (
            root_nodes = getOffsetSceneRoots()

            if root_nodes.count == 0 then
            (
                false
            )
            else
            (
                for node_value in root_nodes do
                (
                    original_tm = node_value.transform
                    node_value.parent = helper_node
                    node_value.transform = original_tm
                )

                helper_node.rotation = quat target_angle [0,0,1]

                for node_value in root_nodes do
                (
                    rotated_tm = node_value.transform
                    node_value.parent = undefined
                    node_value.transform = rotated_tm
                )

                setUserPropVal helper_node "SO_MAIN_ROTATION_Z" target_angle
                true
            )
        )
        -- return
    ),

    /*
    Sets the absolute applied main scene Z rotation while the scene offset is active.
    The stored rotation definition and toggle state are managed separately.
    */
    function setMainRotationAngle target_angle =
    (
        if not isOffsetActive() then
        (
            #(false, "OFFSET TO ORIGIN must be active before main rotation.")
        )
        else if hasOrthoDriver() then
        (
            #(false, "Return MODEL NODE ORTHO view to ORIGINAL before changing main rotation.")
        )
        else
        (
            current_angle = getStoredMainRotationZ()

            if current_angle == target_angle then
            (
                #(true, "Main rotation unchanged: " + (formattedPrint target_angle format:"0.6f") + " deg")
            )
            else
            (
                rotation_ok = false

                undo "Set Main Scene Rotation" on
                (
                    rotation_ok = applyMainRotationAngleRaw target_angle
                )

                if rotation_ok then
                (
                    #(true, "Main rotation Z: " + (formattedPrint target_angle format:"0.6f") + " deg")
                )
                else
                (
                    #(false, "Main rotation failed: no rotatable scene roots were found.")
                )
            )
        )
        -- return
    ),

    /*
    Defines the reusable main-rotation angle from one picked XY vector.
    Definition is independent from OFFSET; applying the stored angle remains controlled by the rotation toggle.
    */
    function defineMainRotationFromVector direction_vector =
    (
        if direction_vector == undefined then
        (
            #(false, "No main rotation vector was supplied.")
        )
        else
        (
            vector_xy = [direction_vector.x, direction_vector.y, 0.0]
            direction_angle = getDirectionAngleFromVectorXY vector_xy

            if direction_angle == undefined then
            (
                #(false, "Main rotation vector has zero XY length.")
            )
            else
            (
                helper_node = createOffsetHelper()

                if helper_node == undefined then
                (
                    #(false, "Could not create SCENE_OFFSET_DATA for the rotation definition.")
                )
                else
                (
                    rotation_delta = getNearestAxisRotationDelta direction_angle
                    defined_angle = getStoredMainRotationZ() + rotation_delta
                    rotation_active = isMainRotationActive()
                    apply_result = #(true, "")

                    if rotation_active then
                    (
                        if hasOrthoDriver() then
                        (
                            apply_result = #(false, "Return MODEL NODE ORTHO view to ORIGINAL before redefining active main rotation.")
                        )
                        else
                        (
                            apply_result = setMainRotationAngle defined_angle
                        )
                    )

                    if apply_result[1] then
                    (
                        setUserPropVal helper_node "SO_MAIN_ROTATION_VECTOR_XY" vector_xy
                        setUserPropVal helper_node "SO_MAIN_ROTATION_LAST_DELTA_Z" rotation_delta
                        setUserPropVal helper_node "SO_MAIN_ROTATION_DEFINED_Z" defined_angle
                        setUserPropVal helper_node "SO_MAIN_ROTATION_DEFINED" true

                        if rotation_active then
                        (
                            #(true, "Main rotation redefined and ON | Z: " + (formattedPrint defined_angle format:"0.6f") + " deg")
                        )
                        else if isOffsetActive() then
                        (
                            #(true, "Main rotation defined | Z: " + (formattedPrint defined_angle format:"0.6f") + " deg | toggle is OFF")
                        )
                        else
                        (
                            #(true, "Main rotation defined | Z: " + (formattedPrint defined_angle format:"0.6f") + " deg | activate OFFSET to apply")
                        )
                    )
                    else
                    (
                        apply_result
                    )
                )
            )
        )
        -- return
    ),

    /*
    Compatibility wrapper for earlier UI versions.
    The supplied value is treated as an XY direction vector, not as a world-space point.
    */
    function setMainRotationFromDirection direction_vector =
    (
        defineMainRotationFromVector direction_vector
        -- return
    ),

    /*
    Applies or removes the stored main rotation definition without changing that definition.
    This toggle operation stays independent so the same vector-angle definition can also be reused per MODEL NODE.
    */
    function setMainRotationActive rotation_active =
    (
        if not isOffsetActive() then
        (
            #(false, "OFFSET TO ORIGIN must be active before toggling main rotation.")
        )
        else if hasOrthoDriver() then
        (
            #(false, "Return MODEL NODE ORTHO view to ORIGINAL before toggling main rotation.")
        )
        else if (rotation_active and not hasMainRotationDefinition()) then
        (
            #(false, "Define the main rotation vector first.")
        )
        else
        (
            target_angle = if rotation_active then getStoredMainRotationDefinedZ() else 0.0
            result_value = setMainRotationAngle target_angle

            if result_value[1] then
            (
                helper_node = getOffsetHelper()
                setUserPropVal helper_node "SO_MAIN_ROTATION_ACTIVE" rotation_active

                if rotation_active then
                (
                    #(true, "Main rotation ON | Z: " + (formattedPrint target_angle format:"0.6f") + " deg")
                )
                else
                (
                    #(true, "Main rotation OFF | Defined Z: " + (formattedPrint (getStoredMainRotationDefinedZ()) format:"0.6f") + " deg")
                )
            )
            else
            (
                result_value
            )
        )
        -- return
    ),

    /*
    Restores the main scene rotation to zero while preserving its stored definition.
    */
    function resetMainRotation =
    (
        setMainRotationActive false
        -- return
    ),

    /*
    Stores authoritative scene offset metadata on the persistent helper.
    The helper Point stays at work origin so it never recreates far-away scene extents.
    */
    function storeOffsetData helper_node offset_value moved_handles =
    (
        offset_mm = point3ToMillimeterDoubles offset_value

        if offset_mm == undefined then
        (
            false
        )
        else
        (
            setUserPropVal helper_node "SO_OFFSET_X_MM" offset_mm[1]
            setUserPropVal helper_node "SO_OFFSET_Y_MM" offset_mm[2]
            setUserPropVal helper_node "SO_OFFSET_Z_MM" offset_mm[3]
            setUserPropVal helper_node "SO_NODE_HANDLES" moved_handles
            setUserPropVal helper_node "SO_ACTIVE" true
            setUserPropVal helper_node "SO_MAIN_ROTATION_Z" 0.0
            setUserPropVal helper_node "SO_MAIN_ROTATION_ACTIVE" false
            helper_node.pos = [0.0,0.0,0.0]
            helper_node.rotation = ((eulerAngles 0.0 0.0 0.0) as quat)
            true
        )
        -- return
    ),

    /*
    Moves the complete working scene to the selected or automatic geometry center.
    The physical offset is stored so real-world coordinates can be restored later.
    */
    function offsetSceneToWorkOrigin offset_value:undefined =
    (
        if isOffsetActive() then
        (
            #(false, "Offset is already active. Restore it first.")
        )
        else if hasOrthoDriver() then
        (
            #(false, "Return ORTHO view to ORIGINAL before changing scene offset.")
        )
        else
        (
            anchor_value = offset_value

            if anchor_value == undefined then
            (
                anchor_nodes = getAnchorGeometry()
                anchor_value = getNodesWorldBoundingBoxCenter anchor_nodes
            )

            if anchor_value == undefined then
            (
                #(false, "No offset value is available.")
            )
            else
            (
                helper_node = createOffsetHelper()
                top_nodes = getOffsetSceneRoots()

                if helper_node == undefined then
                (
                    #(false, "Could not create SCENE_OFFSET_DATA.")
                )
                else if top_nodes.count == 0 then
                (
                    #(false, "No top-level scene nodes found.")
                )
                else
                (
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
                                format "Scene Model Manager offset error | % | %\n" node_value.name (getCurrentException())
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

                        if failed_count == 0 then
                        (
                            storeOffsetData helper_node anchor_value moved_handles
                        )
                    )

                    message_text = "Scene offset active | Moved roots: " + moved_handles.count as string

                    if failed_count > 0 then
                    (
                        message_text += " | Failed: " + failed_count as string
                    )

                    #(failed_count == 0, message_text)
                )
            )
        )
        -- return
    ),

    /*
    Adds all current working roots to the persistent offset restore set.
    This includes MODEL NODEs or new scene roots created after the original offset.
    */
    function registerCurrentRootsWithOffset =
    (
        helper_node = getOffsetHelper()

        if (helper_node == undefined or not isOffsetActive()) then
        (
            0
        )
        else
        (
            stored_handles = getUserPropVal helper_node "SO_NODE_HANDLES"
            if stored_handles == undefined then stored_handles = #()

            added_count = 0
            current_roots = getOffsetSceneRoots()

            for node_value in current_roots do
            (
                node_handle = node_value.inode.handle

                if (findItem stored_handles node_handle) == 0 then
                (
                    append stored_handles node_handle
                    added_count += 1
                )
            )

            setUserPropVal helper_node "SO_NODE_HANDLES" stored_handles
            added_count
        )
        -- return
    ),

    /*
    Restores the active work-origin offset using the tested stored-handle workflow.
    New roots are registered first so MODEL NODEs move back with the scene.
    */
    function restoreSceneOffset =
    (
        if hasOrthoDriver() then
        (
            #(false, "Return ORTHO view to ORIGINAL before restoring scene offset.")
        )
        else
        (
            helper_node = getOffsetHelper()

            if helper_node == undefined then
            (
                #(false, "SCENE_OFFSET_DATA was not found.")
            )
            else if not isOffsetActive() then
            (
                #(false, "No active scene offset is stored.")
            )
            else
            (
                registerCurrentRootsWithOffset()
                offset_value = getStoredOffsetSystemUnits()
                stored_handles = getUserPropVal helper_node "SO_NODE_HANDLES"
                if stored_handles == undefined then stored_handles = #()

                if offset_value == undefined then
                (
                    #(false, "Stored offset data is incomplete.")
                )
                else
                (
                    restored_count = 0
                    failed_count = 0
                    skipped_parented_count = 0
                    rotation_reset_ok = true

                    undo "Restore Scene Offset" on
                    (
                        if getStoredMainRotationZ() != 0.0 then
                        (
                            rotation_reset_ok = applyMainRotationAngleRaw 0.0
                        )

                        if rotation_reset_ok then
                        (
                            for node_handle in stored_handles do
                            (
                                node_value = maxOps.getNodeByHandle node_handle

                                if (node_value == undefined or not isValidNode node_value) then
                                (
                                    failed_count += 1
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
                                        format "Scene Model Manager restore offset error | % | %\n" node_value.name (getCurrentException())
                                    )

                                    if restore_ok then
                                    (
                                        restored_count += 1
                                    )
                                    else
                                    (
                                        failed_count += 1
                                    )
                                )
                            )
                        )

                        if (rotation_reset_ok and failed_count == 0 and skipped_parented_count == 0) then
                        (
                            setUserPropVal helper_node "SO_MAIN_ROTATION_ACTIVE" false
                            setUserPropVal helper_node "SO_ACTIVE" false
                        )
                    )

                    if not rotation_reset_ok then
                    (
                        #(false, "Scene restore stopped because main rotation could not be reset.")
                    )
                    else
                    (
                        message_text = "Scene restored | Roots: " + restored_count as string

                        if failed_count > 0 then
                        (
                            message_text += " | Missing/failed: " + failed_count as string
                        )

                        if skipped_parented_count > 0 then
                        (
                            message_text += " | Parented skipped: " + skipped_parented_count as string
                        )

                        #((failed_count == 0 and skipped_parented_count == 0), message_text)
                    )
                )
            )
        )
        -- return
    ),

    /*
    Returns or creates the dedicated MODEL NODE layer.
    MODEL NODE Text shapes stay visually separate from imported scene content.
    */
    function getModelNodeLayer =
    (
        layer_ref = LayerManager.getLayerFromName model_node_layer_name

        if layer_ref == undefined then
        (
            layer_ref = LayerManager.newLayerFromName model_node_layer_name
        )

        layer_ref
        -- return
    ),

    /*
    Returns or creates the manager helper layer used by temporary ORTHO drivers.
    This layer never owns MODEL NODE Text shapes.
    */
    function getHelperLayer =
    (
        layer_ref = LayerManager.getLayerFromName helper_layer_name

        if layer_ref == undefined then
        (
            layer_ref = LayerManager.newLayerFromName helper_layer_name
        )

        layer_ref
        -- return
    ),

    /*
    Returns true when a scene node is a Scene Model Manager MODEL NODE.
    Identification uses persistent User Defined Properties instead of the node name.
    */
    function isModelNode node_value =
    (
        if (node_value == undefined or not isValidNode node_value) then
        (
            false
        )
        else
        (
            isModelNodeMarker node_value
        )
        -- return
    ),

    /*
    Returns all top-level MODEL NODE Text shapes currently stored in the scene.
    The array follows current root-node order for stable scene-local presentation.
    */
    function getModelNodes =
    (
        model_nodes = #()

        for node_value in rootNode.children do
        (
            if isModelNode node_value then
            (
                append model_nodes node_value
            )
        )

        model_nodes
        -- return
    ),

    /*
    Returns the exact world bounding-box center of a node array.
    This supplies the default MODEL NODE pivot when members are already selected.
    */
    function getNodesBoundsCenter node_array =
    (
        if (node_array == undefined or node_array.count == 0) then
        (
            undefined
        )
        else
        (
            bounds_value = Box3()
            valid_count = 0

            for node_value in node_array do
            (
                if (node_value != undefined and isValidNode node_value) then
                (
                    bounds_value += node_value.min
                    bounds_value += node_value.max
                    valid_count += 1
                )
            )

            if valid_count == 0 then undefined else bounds_value.center
        )
        -- return
    ),

    /*
    Updates the visible Text content of one MODEL NODE.
    The scene label always shows its logical model name and current ratio.
    */
    function updateModelNodeText model_node =
    (
        if not isModelNode model_node then
        (
            false
        )
        else
        (
            model_name = getUserPropVal model_node "SMM_MODEL_NAME"
            ratio_value = getUserPropVal model_node "SMM_RATIO"

            if model_name == undefined then model_name = model_node.name
            if ratio_value == undefined then ratio_value = 150

            if isProperty model_node #text then
            (
                model_node.text = model_name + "\n1:" + (ratio_value as string)
            )

            true
        )
        -- return
    ),

    /*
    Creates one visible Text MODEL NODE at the supplied world pivot.
    Membership is stored as node handles and does not alter scene parenting.
    */
    function createModelNode node_name member_nodes pivot_point ratio_value text_size =
    (
        if pivot_point == undefined then
        (
            undefined
        )
        else
        (
            safe_name = node_name
            if safe_name == "" then safe_name = uniqueName "MODEL_NODE_"

            model_node = Text \
                name:(uniqueName (safe_name + "_NODE")) \
                text:safe_name \
                size:text_size \
                pos:pivot_point

            model_node.wirecolor = color 255 180 0
            model_node.render_renderable = false
            model_node.render_displayRenderMesh = false

            model_layer = getModelNodeLayer()
            if model_layer != undefined then model_layer.addNode model_node

            member_handles = #()

            if member_nodes != undefined then
            (
                for member_node in member_nodes do
                (
                    if (member_node != undefined and isValidNode member_node and member_node != model_node) then
                    (
                        appendIfUnique member_handles member_node.inode.handle
                    )
                )
            )

            setUserPropVal model_node "SMM_MODEL_NODE" true
            setUserPropVal model_node "SMM_FILE_VERSION" file_version
            setUserPropVal model_node "SMM_PROJECT_VERSION" project_version
            setUserPropVal model_node "SMM_MODEL_NAME" safe_name
            setUserPropVal model_node "SMM_RATIO" ratio_value
            setUserPropVal model_node "SMM_MEMBER_HANDLES" member_handles
            setUserPropVal model_node "SMM_ORTHO_DELTA_Z" 0.0
            setUserPropVal model_node "SMM_SOURCE_ANGLE_Z" 0.0
            setUserPropVal model_node "SMM_PICKED_VECTOR_XY" [1.0,0.0,0.0]
            setUserPropVal model_node "SMM_TARGET_SYSTEM_TYPE" #Millimeters
            setUserPropVal model_node "SMM_TARGET_DISPLAY_TYPE" #CustomMillimeter

            updateModelNodeText model_node
            registerCurrentRootsWithOffset()
            model_node
        )
        -- return
    ),

    /*
    Applies name, ratio, and visible text size changes to an existing MODEL NODE.
    The node's unique scene identity and membership remain unchanged.
    */
    function updateModelNodeSettings model_node node_name ratio_value text_size =
    (
        if not isModelNode model_node then
        (
            false
        )
        else
        (
            model_name = node_name
            if model_name == "" then model_name = model_node.name

            setUserPropVal model_node "SMM_MODEL_NAME" model_name
            setUserPropVal model_node "SMM_RATIO" ratio_value
            model_node.size = text_size
            updateModelNodeText model_node
            true
        )
        -- return
    ),

    /*
    Returns persistent member handles for one MODEL NODE.
    Missing metadata is represented by an empty array.
    */
    function getModelNodeMemberHandles model_node =
    (
        member_handles = #()

        if isModelNode model_node then
        (
            stored_handles = getUserPropVal model_node "SMM_MEMBER_HANDLES"
            if stored_handles != undefined then member_handles = stored_handles
        )

        member_handles
        -- return
    ),

    /*
    Resolves valid scene nodes currently assigned to one MODEL NODE.
    Missing or deleted handles are skipped without fabricating replacement nodes.
    */
    function getModelNodeMembers model_node =
    (
        member_nodes = #()
        member_handles = getModelNodeMemberHandles model_node

        for node_handle in member_handles do
        (
            member_node = maxOps.getNodeByHandle node_handle

            if (member_node != undefined and isValidNode member_node) then
            (
                append member_nodes member_node
            )
        )

        member_nodes
        -- return
    ),

    /*
    Adds the current viewport selection to one MODEL NODE membership set.
    The MODEL NODE itself is ignored if it is also selected.
    */
    function addSelectionToModelNode model_node =
    (
        if not isModelNode model_node then
        (
            0
        )
        else
        (
            member_handles = getModelNodeMemberHandles model_node
            added_count = 0

            for member_node in selection do
            (
                if (member_node != model_node and not isModelNode member_node) then
                (
                    node_handle = member_node.inode.handle

                    if (findItem member_handles node_handle) == 0 then
                    (
                        append member_handles node_handle
                        added_count += 1
                    )
                )
            )

            setUserPropVal model_node "SMM_MEMBER_HANDLES" member_handles
            added_count
        )
        -- return
    ),

    /*
    Removes the current viewport selection from one MODEL NODE membership set.
    Deleted or already missing members are also removed from persistent metadata.
    */
    function removeSelectionFromModelNode model_node =
    (
        if not isModelNode model_node then
        (
            0
        )
        else
        (
            member_handles = getModelNodeMemberHandles model_node
            selected_handles = #()

            for selected_node in selection do
            (
                appendIfUnique selected_handles selected_node.inode.handle
            )

            new_handles = #()
            removed_count = 0

            for node_handle in member_handles do
            (
                member_node = maxOps.getNodeByHandle node_handle
                remove_handle = (findItem selected_handles node_handle) > 0

                if member_node == undefined then remove_handle = true

                if remove_handle then
                (
                    removed_count += 1
                )
                else
                (
                    append new_handles node_handle
                )
            )

            setUserPropVal model_node "SMM_MEMBER_HANDLES" new_handles
            removed_count
        )
        -- return
    ),

    /*
    Selects all currently valid members assigned to one MODEL NODE.
    This is a non-destructive membership inspection action.
    */
    function selectModelNodeMembers model_node =
    (
        member_nodes = getModelNodeMembers model_node

        if member_nodes.count > 0 then
        (
            select member_nodes
        )
        else
        (
            clearSelection()
        )

        member_nodes.count
        -- return
    ),

    /*
    Calculates and stores ORTHO correction from the MODEL NODE pivot to a picked XY point.
    The visible Text rotation follows the picked source direction; no epsilon is introduced.
    */
    function setModelNodeOrthoFromDirection model_node direction_point =
    (
        if not isModelNode model_node then
        (
            #(false, "Select a valid MODEL NODE first.")
        )
        else if direction_point == undefined then
        (
            #(false, "No direction point was supplied.")
        )
        else
        (
            picked_vector = direction_point - model_node.pos
            vector_xy = [picked_vector.x, picked_vector.y, 0.0]

            if length vector_xy == 0.0 then
            (
                #(false, "Picked XY vector has zero length.")
            )
            else
            (
                direction_angle = getDirectionAngleFromVectorXY vector_xy
                rotation_delta = getNearestAxisRotationDelta direction_angle

                setUserPropVal model_node "SMM_PICKED_VECTOR_XY" vector_xy
                setUserPropVal model_node "SMM_SOURCE_ANGLE_Z" direction_angle
                setUserPropVal model_node "SMM_ORTHO_DELTA_Z" rotation_delta
                model_node.rotation = quat direction_angle [0,0,1]

                #(true, "ORTHO correction Z: " + (formattedPrint rotation_delta format:"0.6f") + " deg")
            )
        )
        -- return
    ),

    /*
    Returns the active temporary scene ORTHO driver when it exists.
    The driver is not a MODEL NODE and is never an export member.
    */
    function getOrthoDriver =
    (
        driver_node = getNodeByName ortho_driver_name

        if (driver_node != undefined and isValidNode driver_node) then
        (
            driver_node
        )
        else
        (
            undefined
        )
        -- return
    ),

    /*
    Returns whether the editing scene is currently displayed through an ORTHO driver.
    Only one scene-wide ORTHO view may be active at a time.
    */
    function isOrthoActive =
    (
        hasOrthoDriver()
        -- return
    ),

    /*
    Returns top-level scene content eligible for temporary scene-wide ORTHO parenting.
    MODEL NODE Text shapes and persistent manager helpers stay outside the driver.
    */
    function getOrthoSceneRoots =
    (
        result_nodes = #()
        offset_helper = getOffsetHelper()
        driver_node = getOrthoDriver()

        for node_value in rootNode.children do
        (
            if (isValidNode node_value and node_value != offset_helper and node_value != driver_node and not isModelNode node_value) then
            (
                append result_nodes node_value
            )
        )

        result_nodes
        -- return
    ),

    /*
    Creates the temporary scene-wide ORTHO driver at one MODEL NODE pivot.
    The parenting strategy is adapted from the tested Rotate-To-Ortho source tool.
    */
    function createOrthoDriver model_node =
    (
        if not isModelNode model_node then
        (
            undefined
        )
        else
        (
            existing_driver = getOrthoDriver()
            if existing_driver != undefined then delete existing_driver

            driver_node = Point \
                name:ortho_driver_name \
                pos:model_node.pos \
                size:(units.decodeValue "1m") \
                box:true \
                cross:false \
                centermarker:false \
                axistripod:true \
                constantscreensize:true \
                drawontop:true

            driver_node.wirecolor = color 0 200 255
            driver_node.rotation = ((eulerAngles 0.0 0.0 0.0) as quat)
            setUserPropVal driver_node "SMM_ACTIVE_MODEL_HANDLE" model_node.inode.handle

            helper_layer = getHelperLayer()
            if helper_layer != undefined then helper_layer.addNode driver_node

            driver_node
        )
        -- return
    ),

    /*
    Parents supplied scene roots to the ORTHO driver while preserving world transforms.
    This is the same reversible transform principle as the tested ORTHO source tool.
    */
    function bindRootsToOrthoDriver root_nodes driver_node =
    (
        bound_count = 0

        for node_value in root_nodes do
        (
            if (node_value != undefined and isValidNode node_value and node_value.parent != driver_node) then
            (
                original_tm = node_value.transform
                node_value.parent = driver_node
                node_value.transform = original_tm
                bound_count += 1
            )
        )

        bound_count
        -- return
    ),

    /*
    Activates one MODEL NODE ORTHO view for scene editing.
    Scene content is parented to a temporary driver; MODEL NODE membership is unchanged.
    */
    function activateModelNodeOrtho model_node =
    (
        if not isModelNode model_node then
        (
            #(false, "Select a valid MODEL NODE first.")
        )
        else
        (
            if hasOrthoDriver() then
            (
                return_value = #(false, "Return the current ORTHO view to ORIGINAL before activating another MODEL NODE.")
            )
            else
            (
                return_value = undefined
            )

            if return_value != undefined then
            (
                return_value
            )
            else
            (
            rotation_delta = getUserPropVal model_node "SMM_ORTHO_DELTA_Z"
            if rotation_delta == undefined then rotation_delta = 0.0

            driver_node = createOrthoDriver model_node

            if driver_node == undefined then
            (
                #(false, "Could not create the scene ORTHO driver.")
            )
            else
            (
                scene_roots = getOrthoSceneRoots()

                undo "Scene Model ORTHO View" on
                (
                    bindRootsToOrthoDriver scene_roots driver_node
                    driver_node.rotation = quat rotation_delta [0,0,1]
                )

                #(true, "ORTHO view active: " + model_node.name)
            )
            )
        )
        -- return
    ),

    /*
    Restores the scene from the temporary ORTHO editing frame to original orientation.
    New roots created during ORTHO editing are bound before the inverse rotation is applied.
    */
    function restoreOrthoView =
    (
        driver_node = getOrthoDriver()

        if driver_node == undefined then
        (
            #(true, "ORTHO view is already ORIGINAL.")
        )
        else
        (
            undo "Restore Scene Model ORTHO" on
            (
                new_roots = getOrthoSceneRoots()
                bindRootsToOrthoDriver new_roots driver_node
                driver_node.rotation = ((eulerAngles 0.0 0.0 0.0) as quat)

                child_nodes = driver_node.children as array

                for child_node in child_nodes do
                (
                    child_tm = child_node.transform
                    child_node.parent = undefined
                    child_node.transform = child_tm
                )

                delete driver_node
            )

            #(true, "Scene returned to ORIGINAL orientation.")
        )
        -- return
    ),

    /*
    Bakes the currently active ORTHO driver into child world transforms.
    This is used only inside held export/copy transactions and is restored by Fetch.
    */
    function bakeOrthoView =
    (
        driver_node = getOrthoDriver()

        if driver_node == undefined then
        (
            true
        )
        else
        (
            new_roots = getOrthoSceneRoots()
            bindRootsToOrthoDriver new_roots driver_node
            child_nodes = driver_node.children as array

            for child_node in child_nodes do
            (
                child_tm = child_node.transform
                child_node.parent = undefined
                child_node.transform = child_tm
            )

            delete driver_node
            true
        )
        -- return
    ),

    /*
    Prepares the held temporary scene for one MODEL NODE export orientation.
    Any current editing ORTHO frame is first normalized only inside the held transaction.
    */
    function prepareModelNodeTransaction model_node =
    (
        if isOrthoActive() then restoreOrthoView()

        result_value = activateModelNodeOrtho model_node

        if result_value[1] then
        (
            bakeOrthoView()
            true
        )
        else
        (
            false
        )
        -- return
    ),

    /*
    Sanitizes one MODEL NODE name for Windows output filenames.
    Invalid filename characters are replaced with underscores.
    */
    function getSafeFileName file_name =
    (
        safe_name = file_name
        invalid_chars = #("\\", "/", ":", "*", "?", "\"", "<", ">", "|")

        for invalid_char in invalid_chars do
        (
            safe_name = substituteString safe_name invalid_char "_"
        )

        if safe_name == "" then safe_name = "model"
        safe_name
        -- return
    ),

    /*
    Recursively collects geometry below one scene node for export.
    The supplied node itself is included when it is geometry.
    */
    function collectGeometryFromNode source_node =
    (
        geometry_nodes = #()

        if (source_node != undefined and isValidNode source_node) then
        (
            if superClassOf source_node == GeometryClass then
            (
                append geometry_nodes source_node
            )

            for child_node in source_node.children do
            (
                child_geometry = collectGeometryFromNode child_node

                for geometry_node in child_geometry do
                (
                    appendIfUnique geometry_nodes geometry_node
                )
            )
        )

        geometry_nodes
        -- return
    ),

    /*
    Resolves all unique geometry represented by one MODEL NODE membership set.
    Group heads and parent dummies contribute their geometry descendants automatically.
    */
    function getModelNodeExportGeometry model_node =
    (
        export_geometry = #()
        member_nodes = getModelNodeMembers model_node

        for member_node in member_nodes do
        (
            member_geometry = collectGeometryFromNode member_node

            for geometry_node in member_geometry do
            (
                appendIfUnique export_geometry geometry_node
            )
        )

        export_geometry
        -- return
    ),

    /*
    Builds one temporary Editable Poly by copying and attaching export geometry.
    Original scene nodes and modifier stacks are never collapsed or attached.
    */
    function createMergedExportNode source_nodes export_name =
    (
        merged_node = undefined
        temp_nodes = #()

        for source_node in source_nodes do
        (
            temp_node = undefined

            try
            (
                temp_node = copy source_node

                if isGroupMember temp_node then setGroupMember temp_node false
                temp_node.parent = undefined

                if canConvertTo temp_node Editable_Poly then
                (
                    convertTo temp_node Editable_Poly
                    append temp_nodes temp_node
                )
                else
                (
                    delete temp_node
                )
            )
            catch
            (
                exception_text = getCurrentException()

                if (temp_node != undefined and isValidNode temp_node) then delete temp_node
                format "Scene Model Manager export copy failed | % | %\n" source_node.name exception_text
            )
        )

        if temp_nodes.count > 0 then
        (
            merged_node = temp_nodes[1]
            merged_node.name = export_name

            if temp_nodes.count > 1 then
            (
                for node_index = temp_nodes.count to 2 by -1 do
                (
                    attach_node = temp_nodes[node_index]
                    attach_name = attach_node.name

                    try
                    (
                        polyop.attach merged_node attach_node
                    )
                    catch
                    (
                        exception_text = getCurrentException()

                        if isValidNode attach_node then delete attach_node
                        format "Scene Model Manager OBJ attach failed | % | %\n" attach_name exception_text
                    )
                )
            )
        )

        merged_node
        -- return
    ),

    /*
    Creates one ORTHO and ratio-scaled MAX copy for the selected MODEL NODE.
    Hold/Fetch restores the working real-world editing scene after the copy is written.
    */
    function createModelMaxCopy model_node target_path target_type display_type =
    (
        operation_ok = false
        hold_created = false
        fetch_ok = false
        error_text = ""

        if not isModelNode model_node then
        (
            #(false, "Select a valid MODEL NODE first.")
        )
        else if target_path == "" then
        (
            #(false, "Choose an output MAX file first.")
        )
        else
        (
            ratio_value = getUserPropVal model_node "SMM_RATIO"
            if ratio_value == undefined then ratio_value = 150

            if getFilenameType target_path == "" then target_path += ".max"

            source_path = maxFilePath + maxFileName
            same_as_source = false

            if source_path != "" then
            (
                same_as_source = toLower (substituteString source_path "/" "\\") == toLower (substituteString target_path "/" "\\")
            )

            if same_as_source then
            (
                #(false, "Target MAX file cannot be the currently loaded source scene.")
            )
            else
            (
                allow_save = true
                if doesFileExist target_path then allow_save = queryBox ("Target exists:\n\n" + target_path + "\n\nOverwrite it?") title:"Scene Model Manager"

                if not allow_save then
                (
                    #(false, "Model copy cancelled.")
                )
                else
                (
                    scale_factor = calculateScaleFactor units.SystemScale units.SystemType target_type ratio_value

                    try
                    (
                        holdMaxFile()
                        hold_created = true

                        if prepareModelNodeTransaction model_node then
                        (
                            rescaleWorldUnits scale_factor
                            setTargetUnits target_type display_type
                            operation_ok = saveMaxFile target_path useNewFile:false clearNeedSaveFlag:false quiet:true
                        )
                    )
                    catch
                    (
                        error_text = getCurrentException()
                        format "Scene Model Manager MAX copy error: %\n" error_text
                        operation_ok = false
                    )

                    if hold_created then
                    (
                        try
                        (
                            fetchMaxFile quiet:true
                            fetch_ok = true
                        )
                        catch
                        (
                            fetch_ok = false
                            format "Scene Model Manager Fetch error: %\n" (getCurrentException())
                        )
                    )

                    if (operation_ok and fetch_ok) then
                    (
                        #(true, "Model MAX copy created: " + target_path)
                    )
                    else if (operation_ok and not fetch_ok) then
                    (
                        #(false, "MAX copy was saved, but Fetch failed. Use Edit > Fetch before continuing.")
                    )
                    else if fetch_ok then
                    (
                        #(false, "MAX copy failed. Working scene was restored. " + error_text)
                    )
                    else
                    (
                        #(false, "MAX copy and automatic Fetch both failed. Use Edit > Fetch. " + error_text)
                    )
                )
            )
        )
        -- return
    ),

    /*
    Exports one MODEL NODE membership set as one ORTHO and ratio-scaled OBJ file.
    Hold/Fetch guarantees the working editing scene returns to its previous state.
    */
    function exportModelNodeObj model_node obj_path target_type display_type =
    (
        operation_ok = false
        hold_created = false
        fetch_ok = false
        error_text = ""

        if not isModelNode model_node then
        (
            #(false, "Select a valid MODEL NODE first.")
        )
        else if obj_path == "" then
        (
            #(false, "OBJ output path is empty.")
        )
        else
        (
            ratio_value = getUserPropVal model_node "SMM_RATIO"
            if ratio_value == undefined then ratio_value = 150
            if getFilenameType obj_path == "" then obj_path += ".obj"

            export_dir = getFilenamePath obj_path
            if export_dir != "" then makeDir export_dir all:true

            scale_factor = calculateScaleFactor units.SystemScale units.SystemType target_type ratio_value

            try
            (
                holdMaxFile()
                hold_created = true

                if prepareModelNodeTransaction model_node then
                (
                    rescaleWorldUnits scale_factor
                    setTargetUnits target_type display_type
                    export_geometry = getModelNodeExportGeometry model_node

                    if export_geometry.count > 0 then
                    (
                        model_name = getUserPropVal model_node "SMM_MODEL_NAME"
                        if model_name == undefined then model_name = model_node.name

                        temp_export_node = createMergedExportNode export_geometry model_name

                        if temp_export_node != undefined then
                        (
                            select temp_export_node
                            exportFile obj_path #noPrompt selectedOnly:true using:ObjExp
                            operation_ok = true
                        )
                    )
                )
            )
            catch
            (
                error_text = getCurrentException()
                format "Scene Model Manager OBJ export error: %\n" error_text
                operation_ok = false
            )

            if hold_created then
            (
                try
                (
                    fetchMaxFile quiet:true
                    fetch_ok = true
                )
                catch
                (
                    fetch_ok = false
                    format "Scene Model Manager OBJ Fetch error: %\n" (getCurrentException())
                )
            )

            if (operation_ok and fetch_ok) then
            (
                #(true, "OBJ exported: " + obj_path)
            )
            else if (operation_ok and not fetch_ok) then
            (
                #(false, "OBJ exported, but Fetch failed. Use Edit > Fetch before continuing.")
            )
            else if fetch_ok then
            (
                #(false, "OBJ export failed. Working scene was restored. " + error_text)
            )
            else
            (
                #(false, "OBJ export and automatic Fetch both failed. Use Edit > Fetch. " + error_text)
            )
        )
        -- return
    ),

    /*
    Exports every MODEL NODE to the supplied folder using each node's own ratio and ORTHO.
    Each node is an independent held transaction so one failure cannot corrupt the source scene.
    */
    function exportAllModelNodesObj export_folder target_type display_type =
    (
        model_nodes = getModelNodes()
        exported_count = 0
        failed_count = 0

        if export_folder == "" then
        (
            #(0, model_nodes.count)
        )
        else
        (
            makeDir export_folder all:true

            for model_node in model_nodes do
            (
                model_name = getUserPropVal model_node "SMM_MODEL_NAME"
                if model_name == undefined then model_name = model_node.name

                obj_path = export_folder + getSafeFileName model_name + ".obj"
                result_value = exportModelNodeObj model_node obj_path target_type display_type

                if result_value[1] then
                (
                    exported_count += 1
                )
                else
                (
                    failed_count += 1
                    format "Scene Model Manager batch export failed | % | %\n" model_name result_value[2]
                )
            )

            #(exported_count, failed_count)
        )
        -- return
    ),

    /*
    Builds a default output path beside the current MAX scene for one MODEL NODE.
    The extension must include its leading dot, for example ".obj" or ".max".
    */
    function getDefaultModelPath model_node extension_value =
    (
        if (maxFilePath == "" or not isModelNode model_node) then
        (
            ""
        )
        else
        (
            model_name = getUserPropVal model_node "SMM_MODEL_NAME"
            if model_name == undefined then model_name = model_node.name

            output_dir = maxFilePath + "export\\"
            makeDir output_dir all:true
            output_dir + getSafeFileName model_name + extension_value
        )
        -- return
    ),

    on create do
    (
    )
)

SceneModelManager = SceneModelManager_v()
