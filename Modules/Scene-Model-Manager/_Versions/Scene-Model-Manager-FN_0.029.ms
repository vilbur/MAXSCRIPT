/*
Scene Model Manager backend.
File version: 0.029
Project version: 0.034

Built from the tested uploaded source tools:
- Scene-Rescaler.ms
- Scene-Offset-Tool_0.13.ms
- Rotate-To-Ortho_0.01.ms
- convertSystemUnitsMmToMetersByMerge.ms
*/

global SceneModelManager
global scene_model_manager_project_version
global scene_model_manager_dump

if (scene_model_manager_project_version == undefined or scene_model_manager_project_version < 0.034) then
(
    scene_model_manager_project_version = 0.034
)

struct SceneModelManager_v
(
    file_version = 0.029,
    project_version = 0.034,
    offset_helper_name = "SCENE_OFFSET_DATA",
    model_node_layer_name = "_MODEL_NODES",
    outlier_handles = #(),
    target_unit_names = #(#Millimeters, #Centimeters, #Meters, #Kilometers, #Inches, #Feet, #Miles),
    display_unit_names = #(#CustomMillimeter, #Generic, #Millimeters, #Centimeters, #Meters, #Kilometers),

    /*
    Writes one development trace line through the optional project DUMP logger.
    Backend behavior remains independent when DUMP is unavailable or disabled.
    */
    function dumpLog log_value =
    (
        if scene_model_manager_dump == undefined then
        (
            false
        )
        else
        (
            scene_model_manager_dump.log log_value
        )
        -- return
    ),

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
    Returns whether one MODEL NODE currently has its own ORTHO display rotation active.
    This state belongs only to that MODEL NODE and never represents a scene-wide ORTHO transform.
    */
    function isModelNodeOrthoActive model_node =
    (
        if not isModelNodeMarker model_node then
        (
            false
        )
        else
        (
            getUserPropVal model_node "SMM_ORTHO_VIEW_ACTIVE" == true
        )
        -- return
    ),

    /*
    Returns true when any MODEL NODE currently has its own ORTHO display rotation active.
    Global scene transforms may use this guard to avoid overwriting a node-specific temporary orientation.
    */
    function hasActiveModelOrtho =
    (
        active_found = false

        for node_value in shapes do
        (
            if (isModelNodeMarker node_value and isModelNodeOrthoActive node_value) then
            (
                active_found = true
            )
        )

        active_found
        -- return
    ),

    /*
    Converts a saved 1 mm System Units scene to 1 meter System Units through native Merge.
    This is the tested uploaded conversion workflow and keeps physical size unchanged.
    */
    function convertSystemUnitsMmToMetersByMerge =
    (
        dumpLog "FN | convertSystemUnitsMmToMetersByMerge | START"
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

                dumpLog ("FN | convertSystemUnitsMmToMetersByMerge | MERGE | source=" + source_file)
                merge_ok = mergeMAXFile source_file #prompt quiet:false
                dumpLog ("FN | convertSystemUnitsMmToMetersByMerge | MERGE RESULT | ok=" + (merge_ok as string) + " | objects=" + (objects.count as string))

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
        dumpLog "FN | findOutlierCandidates | START"
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
                    (node_value.name != offset_helper_name)

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

            dumpLog ("FN | findOutlierCandidates | RESULT | count=" + (candidate_nodes.count as string))
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
        dumpLog ("FN | deleteFoundOutliers | START | handles=" + (outlier_handles.count as string))
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
        dumpLog ("FN | deleteFoundOutliers | RESULT | deleted=" + (deleted_count as string) + " | missing=" + (missing_count as string))
        #(deleted_count, missing_count)
        -- return
    ),

    /*
    Centers pivots on selected geometry, or all geometry when nothing is selected.
    This preserves the tested Scene Offset Tool behavior and does not collapse stacks.
    */
    function centerObjectPivots =
    (
        dumpLog ("FN | centerObjectPivots | START | selection=" + (selection.count as string))
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

            dumpLog ("FN | centerObjectPivots | RESULT | centered=" + (centered_count as string) + " | failed=" + (failed_count as string))
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
        result_nodes = #()

        for node_value in rootNode.children do
        (
            if (isValidNode node_value and node_value != offset_helper) then
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
        else if hasActiveModelOrtho() then
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
        dumpLog ("FN | defineMainRotationFromVector | START | vector=" + (direction_vector as string))
        if direction_vector == undefined then
        (
            #(false, "No main rotation vector was supplied.")
        )
        else
        (
            vector_xy = [direction_vector.x, direction_vector.y, 0.0]
            direction_angle = getDirectionAngleFromVectorXY vector_xy
            dumpLog ("FN | defineMainRotationFromVector | ANGLE | vector=" + (vector_xy as string) + " | angle=" + (direction_angle as string))

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
                    dumpLog ("FN | defineMainRotationFromVector | DEFINITION | delta=" + (rotation_delta as string) + " | defined=" + (defined_angle as string) + " | active=" + (rotation_active as string))
                    apply_result = #(true, "")

                    if rotation_active then
                    (
                        if hasActiveModelOrtho() then
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
    Adds one explicit angle step to the stored main-rotation definition.
    When the main rotation toggle is ON, the scene is updated immediately around world origin.
    */
    function addMainRotationAngle angle_delta =
    (
        dumpLog ("FN | addMainRotationAngle | START | delta=" + (angle_delta as string))
        helper_node = createOffsetHelper()

        if helper_node == undefined then
        (
            #(false, "Could not create SCENE_OFFSET_DATA for main rotation.")
        )
        else
        (
            current_defined = if hasMainRotationDefinition() then getStoredMainRotationDefinedZ() else getStoredMainRotationZ()
            target_defined = current_defined + angle_delta
            rotation_active = isMainRotationActive()
            dumpLog ("FN | addMainRotationAngle | TARGET | current=" + (current_defined as string) + " | target=" + (target_defined as string) + " | active=" + (rotation_active as string))
            apply_result = #(true, "")

            if rotation_active then
            (
                apply_result = setMainRotationAngle target_defined
            )

            if apply_result[1] then
            (
                setUserPropVal helper_node "SO_MAIN_ROTATION_DEFINED_Z" target_defined
                setUserPropVal helper_node "SO_MAIN_ROTATION_DEFINED" true
                dumpLog ("FN | addMainRotationAngle | STORED | target=" + (target_defined as string))

                if rotation_active then
                (
                    #(true, "Main rotation +" + (formattedPrint angle_delta format:"0.6f") + " deg | ON | Z: " + (formattedPrint target_defined format:"0.6f") + " deg")
                )
                else if isOffsetActive() then
                (
                    #(true, "Main rotation +" + (formattedPrint angle_delta format:"0.6f") + " deg | Defined Z: " + (formattedPrint target_defined format:"0.6f") + " deg | toggle is OFF")
                )
                else
                (
                    #(true, "Main rotation +" + (formattedPrint angle_delta format:"0.6f") + " deg | Defined Z: " + (formattedPrint target_defined format:"0.6f") + " deg | activate OFFSET to apply")
                )
            )
            else
            (
                apply_result
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
        dumpLog ("FN | setMainRotationActive | START | active=" + (rotation_active as string))
        if not isOffsetActive() then
        (
            #(false, "OFFSET TO ORIGIN must be active before toggling main rotation.")
        )
        else if hasActiveModelOrtho() then
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
            dumpLog ("FN | setMainRotationActive | TARGET | angle=" + (target_angle as string))
            result_value = setMainRotationAngle target_angle
            dumpLog ("FN | setMainRotationActive | SET RESULT | " + (result_value as string))

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
        dumpLog ("FN | offsetSceneToWorkOrigin | START | suppliedOffset=" + (offset_value as string))
        if isOffsetActive() then
        (
            #(false, "Offset is already active. Restore it first.")
        )
        else if hasActiveModelOrtho() then
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
                dumpLog ("FN | offsetSceneToWorkOrigin | ANCHOR | " + (anchor_value as string))
                helper_node = createOffsetHelper()
                top_nodes = getOffsetSceneRoots()
                dumpLog ("FN | offsetSceneToWorkOrigin | ROOTS | count=" + (top_nodes.count as string))

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

                    dumpLog ("FN | offsetSceneToWorkOrigin | RESULT | moved=" + (moved_handles.count as string) + " | failed=" + (failed_count as string))
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
        dumpLog "FN | restoreSceneOffset | START"
        if hasActiveModelOrtho() then
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
                dumpLog ("FN | restoreSceneOffset | DATA | offset=" + (offset_value as string) + " | handles=" + (stored_handles.count as string))

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

                        dumpLog ("FN | restoreSceneOffset | RESULT | restored=" + (restored_count as string) + " | failed=" + (failed_count as string) + " | parentedSkipped=" + (skipped_parented_count as string))
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
    Returns all MODEL NODE Text shapes currently stored in the scene.
    Shape collection lookup remains valid while a MODEL NODE is temporarily parented during ORTHO view.
    */
    function getModelNodes =
    (
        model_nodes = #()

        for node_value in shapes do
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
    The viewport Text displays only the logical MODEL NODE name.
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
            if model_name == undefined then model_name = model_node.name

            if isProperty model_node #text then
            (
                model_node.text = model_name
                model_node.name = model_name
            )

            (model_node.text == model_name and model_node.name == model_name)
        )
        -- return
    ),

    /*
    Replaces linked member handles with the MODEL NODE root in active offset metadata.
    This keeps REAL-WORLD restore valid after selected objects become children of the Text node.
    */
    function syncOffsetHandlesForLinkedModelNode model_node member_nodes =
    (
        if (not isOffsetActive() or not isModelNode model_node) then
        (
            0
        )
        else
        (
            helper_node = getOffsetHelper()

            if helper_node == undefined then
            (
                0
            )
            else
            (
                stored_handles = getUserPropVal helper_node "SO_NODE_HANDLES"
                if stored_handles == undefined then stored_handles = #()

                linked_handles = #()
                for member_node in member_nodes do
                (
                    if (member_node != undefined and isValidNode member_node) then
                    (
                        appendIfUnique linked_handles member_node.inode.handle
                    )
                )

                new_handles = #()
                for stored_handle in stored_handles do
                (
                    if (findItem linked_handles stored_handle) == 0 then
                    (
                        appendIfUnique new_handles stored_handle
                    )
                )

                appendIfUnique new_handles model_node.inode.handle
                setUserPropVal helper_node "SO_NODE_HANDLES" new_handles
                new_handles.count
            )
        )
        -- return
    ),

    /*
    Returns only top hierarchy roots from one candidate node array.
    A candidate is eligible only when its full non-MODEL-NODE ancestor chain is also represented by that candidate root.
    Children remain under their existing parents, group heads remain intact, and nodes already owned by another MODEL NODE are excluded.
    */
    function getTopModelMemberRoots source_nodes owner_model_node:undefined =
    (
        candidate_nodes = #()
        candidate_handles = #()
        root_nodes = #()

        if source_nodes != undefined then
        (
            for source_node in source_nodes do
            (
                if (source_node != undefined and isValidNode source_node and not isModelNode source_node) then
                (
                    source_handle = source_node.inode.handle

                    if (findItem candidate_handles source_handle) == 0 then
                    (
                        append candidate_nodes source_node
                        append candidate_handles source_handle
                    )
                )
            )
        )

        for candidate_node in candidate_nodes do
        (
            hierarchy_root = candidate_node
            ancestor_node = hierarchy_root.parent

            while (ancestor_node != undefined and not isModelNode ancestor_node) do
            (
                hierarchy_root = ancestor_node
                ancestor_node = hierarchy_root.parent
            )

            blocked_by_other_model = false

            if (ancestor_node != undefined and isModelNode ancestor_node) then
            (
                blocked_by_other_model = (owner_model_node == undefined or ancestor_node != owner_model_node)
            )

            if not blocked_by_other_model then
            (
                hierarchy_handle = hierarchy_root.inode.handle

                if (findItem candidate_handles hierarchy_handle) > 0 then
                (
                    appendIfUnique root_nodes hierarchy_root
                )
            )
        )

        dumpLog ("FN | getTopModelMemberRoots | candidates=" + (candidate_nodes.count as string) + " | roots=" + (root_nodes.count as string))
        root_nodes
        -- return
    ),

    /*
    Returns all valid nodes from the scene layer whose name exactly matches the supplied string.
    Case or spelling differences are rejected even if LayerManager resolves a similarly named layer.
    */
    function getExactLayerNodes layer_name =
    (
        layer_nodes = #()

        if (layer_name != undefined and layer_name != "") then
        (
            source_layer = LayerManager.getLayerFromName layer_name

            if (source_layer != undefined and source_layer.name == layer_name) then
            (
                read_ok = source_layer.nodes &layer_nodes

                if not read_ok then
                (
                    dumpLog ("FN | getExactLayerNodes | READ FAILED | layer=" + layer_name)
                    layer_nodes = #()
                )
            )
        )

        layer_nodes
        -- return
    ),

    /*
    Creates one visible Text MODEL NODE at the XY center of the supplied members with Z forced to zero.
    Selected member objects are linked to the Text node while preserving their world transforms.
    */
    function createModelNode node_name member_nodes pivot_point ratio_value text_size =
    (
        member_count = if member_nodes == undefined then 0 else member_nodes.count
        dumpLog ("FN | createModelNode | START | name=" + (node_name as string) + " | members=" + (member_count as string))

        if (member_nodes == undefined or member_nodes.count == 0) then
        (
            dumpLog "FN | createModelNode | STOP | no member selection"
            undefined
        )
        else
        (
            selection_center = getNodesBoundsCenter member_nodes

            if selection_center == undefined then
            (
                dumpLog "FN | createModelNode | STOP | selection center unavailable"
                undefined
            )
            else
            (
                safe_name = node_name
                if safe_name == "" then safe_name = uniqueName "MODEL_NODE_"

                model_node = Text \
                    name:safe_name \
                    text:safe_name \
                    size:text_size \
                    pos:selection_center

                model_position = model_node.pos
                model_position.z = 0.0
                model_node.pos = model_position
                dumpLog ("FN | createModelNode | CENTER | source=" + (selection_center as string) + " | textPos=" + (model_node.pos as string))

                model_node.wirecolor = color 255 180 0
                model_node.render_renderable = false
                model_node.render_displayRenderMesh = false

                model_layer = getModelNodeLayer()
                if model_layer != undefined then model_layer.addNode model_node

                member_handles = #()
                original_parents = #()
                original_transforms = #()
                valid_members = getTopModelMemberRoots member_nodes

                for member_node in valid_members do
                (
                    append original_parents member_node.parent
                    append original_transforms member_node.transform
                )

                dumpLog ("FN | createModelNode | HIERARCHY ROOTS | source=" + (member_nodes.count as string) + " | roots=" + (valid_members.count as string))

                if valid_members.count == 0 then
                (
                    delete model_node
                    dumpLog "FN | createModelNode | STOP | no valid members"
                    undefined
                )
                else
                (
                    link_ok = true
                    linked_count = 0

                    for member_index = 1 to valid_members.count while link_ok do
                    (
                        member_node = valid_members[member_index]

                        try
                        (
                            member_tm = member_node.transform
                            member_node.parent = model_node
                            member_node.transform = member_tm
                            appendIfUnique member_handles member_node.inode.handle
                            linked_count += 1
                        )
                        catch
                        (
                            link_ok = false
                            link_error_text = getCurrentException()
                            dumpLog ("FN | createModelNode | LINK ERROR | node=" + member_node.name + " | " + link_error_text)
                        )
                    )

                    if not link_ok then
                    (
                        for rollback_index = 1 to linked_count do
                        (
                            rollback_node = valid_members[rollback_index]

                            try
                            (
                                rollback_node.parent = original_parents[rollback_index]
                                rollback_node.transform = original_transforms[rollback_index]
                            )
                            catch
                            (
                                rollback_error_text = getCurrentException()
                                dumpLog ("FN | createModelNode | ROLLBACK ERROR | node=" + rollback_node.name + " | " + rollback_error_text)
                            )
                        )

                        delete model_node
                        undefined
                    )
                    else
                    (
                        setUserPropVal model_node "SMM_MODEL_NODE" true
                        setUserPropVal model_node "SMM_FILE_VERSION" file_version
                        setUserPropVal model_node "SMM_PROJECT_VERSION" project_version
                        setUserPropVal model_node "SMM_MODEL_NAME" safe_name
                        setUserPropVal model_node "SMM_RATIO" ratio_value
                        setUserPropVal model_node "SMM_MEMBER_HANDLES" member_handles
                        setUserPropVal model_node "SMM_BIND_MATCHING_LAYER" false
                        setUserPropVal model_node "SMM_ORTHO_DELTA_Z" 0.0
                        setUserPropVal model_node "SMM_SOURCE_ANGLE_Z" 0.0
                        setUserPropVal model_node "SMM_PICKED_VECTOR_XY" [1.0,0.0,0.0]
                        setUserPropVal model_node "SMM_ORTHO_VIEW_ACTIVE" false
                        setUserPropVal model_node "SMM_ORTHO_BOUND_HANDLES" #()
                        setUserPropVal model_node "SMM_TARGET_SYSTEM_TYPE" #Millimeters
                        setUserPropVal model_node "SMM_TARGET_DISPLAY_TYPE" #CustomMillimeter

                        identity_ok = updateModelNodeText model_node

                        if not identity_ok then
                        (
                            dumpLog ("FN | createModelNode | IDENTITY MISMATCH | name=" + model_node.name + " | text=" + model_node.text + " | expected=" + safe_name)
                        )

                        syncOffsetHandlesForLinkedModelNode model_node valid_members
                        registerCurrentRootsWithOffset()
                        dumpLog ("FN | createModelNode | CREATED | node=" + model_node.name + " | linked=" + (linked_count as string) + " | pos=" + (model_node.pos as string))
                        model_node
                    )
                )
            )
        )
        -- return
    ),

    /*
    Applies name, ratio, and visible text size changes to an existing MODEL NODE.
    The node's unique scene identity and membership remain unchanged.
    */
    function updateModelNodeSettings model_node node_name ratio_value text_size =
    (
        dumpLog ("FN | updateModelNodeSettings | START | node=" + (model_node as string))
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
            identity_ok = updateModelNodeText model_node

            if not identity_ok then
            (
                dumpLog ("FN | updateModelNodeSettings | IDENTITY MISMATCH | name=" + model_node.name + " | text=" + model_node.text + " | expected=" + model_name)
            )

            identity_ok
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
    Adds supplied hierarchy roots to one MODEL NODE while preserving every root world transform.
    Only top hierarchy roots returned by getTopModelMemberRoots are linked; descendants are never reparented.
    */
    function addNodesToModelNode model_node source_nodes =
    (
        if not isModelNode model_node then
        (
            0
        )
        else
        (
            member_handles = getModelNodeMemberHandles model_node
            root_nodes = getTopModelMemberRoots source_nodes owner_model_node:model_node
            added_nodes = #()
            added_count = 0
            source_count = if source_nodes == undefined then 0 else source_nodes.count

            dumpLog ("FN | addNodesToModelNode | START | source=" + (source_count as string) + " | roots=" + (root_nodes.count as string))

            for root_node in root_nodes do
            (
                root_handle = root_node.inode.handle

                if (findItem member_handles root_handle) == 0 then
                (
                    try
                    (
                        root_tm = root_node.transform

                        if root_node.parent != model_node then
                        (
                            root_node.parent = model_node
                            root_node.transform = root_tm
                        )

                        append member_handles root_handle
                        append added_nodes root_node
                        added_count += 1
                    )
                    catch
                    (
                        add_error_text = getCurrentException()
                        dumpLog ("FN | addNodesToModelNode | LINK ERROR | node=" + root_node.name + " | " + add_error_text)
                    )
                )
            )

            setUserPropVal model_node "SMM_MEMBER_HANDLES" member_handles
            syncOffsetHandlesForLinkedModelNode model_node added_nodes
            registerCurrentRootsWithOffset()
            dumpLog ("FN | addNodesToModelNode | RESULT | added=" + (added_count as string))
            added_count
        )
        -- return
    ),

    /*
    Returns whether one MODEL NODE automatically synchronizes members from its exactly matching layer.
    Missing metadata defaults to false so existing scenes retain manual membership until explicitly enabled.
    */
    function isModelNodeBindMatchingLayer model_node =
    (
        if not isModelNode model_node then
        (
            false
        )
        else
        (
            bind_matching_value = getUserPropVal model_node "SMM_BIND_MATCHING_LAYER"
            bind_matching_value == true
        )
        -- return
    ),

    /*
    Enables or disables exact matching-layer membership synchronization for one MODEL NODE.
    This only changes the persistent mode flag; callers decide when synchronization should run.
    */
    function setModelNodeBindMatchingLayer model_node bind_matching_enabled =
    (
        if not isModelNode model_node then
        (
            false
        )
        else
        (
            setUserPropVal model_node "SMM_BIND_MATCHING_LAYER" bind_matching_enabled
            stored_value = getUserPropVal model_node "SMM_BIND_MATCHING_LAYER"
            write_ok = stored_value == bind_matching_enabled
            dumpLog ("FN | setModelNodeBindMatchingLayer | node=" + model_node.name + " | requested=" + (bind_matching_enabled as string) + " | stored=" + (stored_value as string) + " | ok=" + (write_ok as string))
            write_ok
        )
        -- return
    ),

    /*
    Synchronizes MODEL MEMBERS to the exact same-named scene layer.
    The matching layer becomes authoritative: desired top hierarchy roots are linked, stale stored roots are unlinked,
    and every touched node keeps its exact world transform and child/group hierarchy.
    Return contract: #(success, addedCount, removedCount, desiredRootCount, message).
    */
    function syncMatchingLayerModelMembers model_node =
    (
        if not isModelNode model_node then
        (
            #(false, 0, 0, 0, "Select a valid MODEL NODE first.")
        )
        else
        (
            model_name = getUserPropVal model_node "SMM_MODEL_NAME"
            if model_name == undefined then model_name = model_node.name

            source_layer = LayerManager.getLayerFromName model_name

            if (source_layer == undefined or source_layer.name != model_name) then
            (
                message_text = "BIND MATCHING LAYER exact layer not found: " + model_name
                dumpLog ("FN | syncMatchingLayerModelMembers | STOP | " + message_text)
                #(false, 0, 0, 0, message_text)
            )
            else
            (
                layer_nodes = #()
                layer_read_ok = source_layer.nodes &layer_nodes

                if not layer_read_ok then
                (
                    message_text = "BIND MATCHING LAYER could not read layer nodes: " + model_name
                    dumpLog ("FN | syncMatchingLayerModelMembers | STOP | " + message_text)
                    #(false, 0, 0, 0, message_text)
                )
                else
                (
                    desired_roots = getTopModelMemberRoots layer_nodes owner_model_node:model_node
                    desired_handles = #()

                    for desired_root in desired_roots do
                    (
                        appendIfUnique desired_handles desired_root.inode.handle
                    )

                    original_handles = getModelNodeMemberHandles model_node
                    current_members = getModelNodeMembers model_node
                    touched_nodes = #()

                    for current_member in current_members do
                    (
                        appendIfUnique touched_nodes current_member
                    )

                    for desired_root in desired_roots do
                    (
                        appendIfUnique touched_nodes desired_root
                    )

                    original_parents = #()
                    original_transforms = #()

                    for touched_node in touched_nodes do
                    (
                        append original_parents touched_node.parent
                        append original_transforms touched_node.transform
                    )

                    sync_ok = true
                    rollback_ok = true
                    sync_error_text = ""
                    added_count = 0
                    removed_count = 0

                    dumpLog ("FN | syncMatchingLayerModelMembers | START | node=" + model_node.name + " | layerNodes=" + (layer_nodes.count as string) + " | desiredRoots=" + (desired_roots.count as string) + " | currentHandles=" + (original_handles.count as string))

                    try
                    (
                        for current_handle in original_handles do
                        (
                            if (findItem desired_handles current_handle) == 0 then
                            (
                                current_node = maxOps.getNodeByHandle current_handle

                                if (current_node != undefined and isValidNode current_node and current_node.parent == model_node) then
                                (
                                    current_tm = current_node.transform
                                    current_node.parent = undefined
                                    current_node.transform = current_tm
                                )

                                removed_count += 1
                            )
                        )

                        for desired_root in desired_roots do
                        (
                            desired_handle = desired_root.inode.handle

                            if desired_root.parent != model_node then
                            (
                                desired_tm = desired_root.transform
                                desired_root.parent = model_node
                                desired_root.transform = desired_tm
                            )

                            if (findItem original_handles desired_handle) == 0 then
                            (
                                added_count += 1
                            )
                        )

                        setUserPropVal model_node "SMM_MEMBER_HANDLES" desired_handles
                    )
                    catch
                    (
                        sync_ok = false
                        sync_error_text = getCurrentException()
                        dumpLog ("FN | syncMatchingLayerModelMembers | ERROR | " + sync_error_text)
                    )

                    if not sync_ok then
                    (
                        for touched_index = 1 to touched_nodes.count do
                        (
                            touched_node = touched_nodes[touched_index]

                            try
                            (
                                touched_node.parent = original_parents[touched_index]
                                touched_node.transform = original_transforms[touched_index]
                            )
                            catch
                            (
                                rollback_ok = false
                                rollback_error_text = getCurrentException()
                                dumpLog ("FN | syncMatchingLayerModelMembers | ROLLBACK ERROR | node=" + touched_node.name + " | " + rollback_error_text)
                            )
                        )

                        setUserPropVal model_node "SMM_MEMBER_HANDLES" original_handles

                        if rollback_ok then
                        (
                            #(false, 0, 0, desired_roots.count, "BIND MATCHING LAYER failed and was rolled back: " + sync_error_text)
                        )
                        else
                        (
                            #(false, 0, 0, desired_roots.count, "BIND MATCHING LAYER failed and rollback also failed. Check DUMP / Listener.")
                        )
                    )
                    else
                    (
                        syncOffsetHandlesForLinkedModelNode model_node desired_roots
                        registerCurrentRootsWithOffset()

                        message_text = "BIND MATCHING LAYER " + model_name + " | Roots: " + (desired_roots.count as string) + " | Added: " + (added_count as string) + " | Removed: " + (removed_count as string)
                        dumpLog ("FN | syncMatchingLayerModelMembers | RESULT | added=" + (added_count as string) + " | removed=" + (removed_count as string) + " | roots=" + (desired_roots.count as string))
                        #(true, added_count, removed_count, desired_roots.count, message_text)
                    )
                )
            )
        )
        -- return
    ),

    /*
    Runs matching-layer synchronization only when BIND MATCHING LAYER is enabled for the MODEL NODE.
    Return contract always matches syncMatchingLayerModelMembers.
    */
    function syncBoundMatchingLayerMembers model_node =
    (
        if not isModelNode model_node then
        (
            #(false, 0, 0, 0, "Select a valid MODEL NODE first.")
        )
        else if isModelNodeBindMatchingLayer model_node then
        (
            syncMatchingLayerModelMembers model_node
        )
        else
        (
            current_members = getModelNodeMembers model_node
            #(true, 0, 0, current_members.count, "BIND MATCHING LAYER is off.")
        )
        -- return
    ),

    /*
    Adds top hierarchy roots from the exact layer whose name matches the MODEL NODE logical name.
    The return array is always #(success, addedCount, eligibleRootCount, message).
    */
    function bindMatchingLayerToModelNode model_node =
    (
        if not isModelNode model_node then
        (
            #(false, 0, 0, "Select a valid MODEL NODE first.")
        )
        else
        (
            model_name = getUserPropVal model_node "SMM_MODEL_NAME"
            if model_name == undefined then model_name = model_node.name

            source_layer = LayerManager.getLayerFromName model_name

            if (source_layer == undefined or source_layer.name != model_name) then
            (
                message_text = "Exact layer not found: " + model_name
                dumpLog ("FN | bindMatchingLayerToModelNode | STOP | " + message_text)
                #(false, 0, 0, message_text)
            )
            else
            (
                layer_nodes = getExactLayerNodes model_name
                root_nodes = getTopModelMemberRoots layer_nodes owner_model_node:model_node
                added_count = addNodesToModelNode model_node layer_nodes
                message_text = "Layer " + model_name + " | Top roots: " + (root_nodes.count as string) + " | Added: " + (added_count as string)

                dumpLog ("FN | bindMatchingLayerToModelNode | RESULT | layerNodes=" + (layer_nodes.count as string) + " | roots=" + (root_nodes.count as string) + " | added=" + (added_count as string))
                #(true, added_count, root_nodes.count, message_text)
            )
        )
        -- return
    ),

    /*
    Adds only top hierarchy roots from the current viewport selection to one MODEL NODE.
    Existing child/group hierarchy remains untouched because descendants are never reparented individually.
    */
    function addSelectionToModelNode model_node =
    (
        dumpLog ("FN | addSelectionToModelNode | START | node=" + (model_node as string) + " | selection=" + (selection.count as string))
        added_count = addNodesToModelNode model_node (selection as array)
        dumpLog ("FN | addSelectionToModelNode | RESULT | added=" + (added_count as string))
        added_count
        -- return
    ),


    /*
    Removes current viewport selection from one MODEL NODE membership set.
    Members parented directly to the Text node are unlinked to world root with world transforms preserved.
    */
    function removeSelectionFromModelNode model_node =
    (
        dumpLog ("FN | removeSelectionFromModelNode | START | node=" + (model_node as string) + " | selection=" + (selection.count as string))
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
                    if (member_node != undefined and isValidNode member_node and member_node.parent == model_node) then
                    (
                        try
                        (
                            member_tm = member_node.transform
                            member_node.parent = undefined
                            member_node.transform = member_tm
                        )
                        catch
                        (
                            remove_error_text = getCurrentException()
                            dumpLog ("FN | removeSelectionFromModelNode | UNLINK ERROR | node=" + member_node.name + " | " + remove_error_text)
                            remove_handle = false
                        )
                    )

                    if remove_handle then
                    (
                        removed_count += 1
                    )
                    else
                    (
                        append new_handles node_handle
                    )
                )
                else
                (
                    append new_handles node_handle
                )
            )

            setUserPropVal model_node "SMM_MEMBER_HANDLES" new_handles
            registerCurrentRootsWithOffset()
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
    Moves one MODEL NODE to an exact world-space pivot point while preserving member world transforms.
    Linked member geometry stays visually stationary; subsequent ORTHO activation uses the new MODEL NODE position as its rotation pivot.
    */
    function moveModelNodePivot model_node target_point =
    (
        dumpLog ("FN | moveModelNodePivot | START | node=" + (model_node as string) + " | target=" + (target_point as string))

        if not isModelNode model_node then
        (
            #(false, "Select a valid MODEL NODE first.")
        )
        else if isModelNodeOrthoActive model_node then
        (
            #(false, "Return this MODEL NODE from ORTHO to ORIGINAL before moving its pivot.")
        )
        else if target_point == undefined then
        (
            #(false, "No MODEL NODE pivot point was supplied.")
        )
        else
        (
            member_nodes = getModelNodeMembers model_node
            member_transforms = #()

            for member_node in member_nodes do
            (
                append member_transforms member_node.transform
            )

            original_model_transform = model_node.transform
            move_ok = true
            move_error_text = ""

            try
            (
                model_node.pos = target_point

                for member_index = 1 to member_nodes.count do
                (
                    member_nodes[member_index].transform = member_transforms[member_index]
                )
            )
            catch
            (
                move_ok = false
                move_error_text = getCurrentException()
                dumpLog ("FN | moveModelNodePivot | ERROR | " + move_error_text)
            )

            if move_ok then
            (
                dumpLog ("FN | moveModelNodePivot | RESULT | pos=" + (model_node.pos as string) + " | membersPreserved=" + (member_nodes.count as string))
                #(true, "MODEL NODE pivot moved to vector START.")
            )
            else
            (
                rollback_ok = true

                try
                (
                    model_node.transform = original_model_transform

                    for member_index = 1 to member_nodes.count do
                    (
                        member_nodes[member_index].transform = member_transforms[member_index]
                    )
                )
                catch
                (
                    rollback_ok = false
                    rollback_error_text = getCurrentException()
                    dumpLog ("FN | moveModelNodePivot | ROLLBACK ERROR | " + rollback_error_text)
                )

                if rollback_ok then
                (
                    #(false, "Could not move MODEL NODE pivot: " + move_error_text)
                )
                else
                (
                    #(false, "Could not move MODEL NODE pivot and rollback also failed. Check DUMP / Listener.")
                )
            )
        )
        -- return
    ),

    /*
    Calculates and stores ORTHO correction from the MODEL NODE pivot to a picked XY point.
    ROTATION ON snaps the visible MODEL NODE to the nearest world X/Y axis; ROTATION OFF leaves its orientation unchanged.
    Linked member world transforms remain unchanged.
    */
    function setModelNodeOrthoFromDirection model_node direction_point =
    (
        dumpLog ("FN | setModelNodeOrthoFromDirection | START | node=" + (model_node as string) + " | point=" + (direction_point as string))
        if not isModelNode model_node then
        (
            #(false, "Select a valid MODEL NODE first.")
        )
        else if isModelNodeOrthoActive model_node then
        (
            #(false, "Return this MODEL NODE from ORTHO to ORIGINAL before redefining its ORTHO direction.")
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
                snapped_angle = direction_angle + rotation_delta
                rotation_active = isMainRotationActive()
                dumpLog ("FN | setModelNodeOrthoFromDirection | ANGLE | vector=" + (vector_xy as string) + " | angle=" + (direction_angle as string) + " | delta=" + (rotation_delta as string) + " | snapped=" + (snapped_angle as string) + " | rotationActive=" + (rotation_active as string))

                member_nodes = getModelNodeMembers model_node
                member_transforms = #()

                for member_node in member_nodes do
                (
                    append member_transforms member_node.transform
                )

                original_model_transform = model_node.transform
                rotation_ok = true
                rotation_error_text = ""

                if rotation_active then
                (
                    try
                    (
                        model_node.rotation = quat snapped_angle [0,0,1]

                        for member_index = 1 to member_nodes.count do
                        (
                            member_nodes[member_index].transform = member_transforms[member_index]
                        )
                    )
                    catch
                    (
                        rotation_ok = false
                        rotation_error_text = getCurrentException()
                        dumpLog ("FN | setModelNodeOrthoFromDirection | ROTATION ERROR | " + rotation_error_text)
                    )
                )

                if rotation_ok then
                (
                    setUserPropVal model_node "SMM_PICKED_VECTOR_XY" vector_xy
                    setUserPropVal model_node "SMM_SOURCE_ANGLE_Z" direction_angle
                    setUserPropVal model_node "SMM_ORTHO_DELTA_Z" rotation_delta

                    if rotation_active then
                    (
                        #(true, "ORTHO correction Z: " + (formattedPrint rotation_delta format:"0.6f") + " deg | MODEL NODE snapped to " + (formattedPrint snapped_angle format:"0.6f") + " deg")
                    )
                    else
                    (
                        #(true, "ORTHO correction Z: " + (formattedPrint rotation_delta format:"0.6f") + " deg | ROTATION OFF")
                    )
                )
                else
                (
                    rollback_ok = true

                    try
                    (
                        model_node.transform = original_model_transform

                        for member_index = 1 to member_nodes.count do
                        (
                            member_nodes[member_index].transform = member_transforms[member_index]
                        )
                    )
                    catch
                    (
                        rollback_ok = false
                        rollback_error_text = getCurrentException()
                        dumpLog ("FN | setModelNodeOrthoFromDirection | ROLLBACK ERROR | " + rollback_error_text)
                    )

                    if rollback_ok then
                    (
                        #(false, "Could not set MODEL NODE ORTHO direction: " + rotation_error_text)
                    )
                    else
                    (
                        #(false, "Could not set MODEL NODE ORTHO direction and rollback also failed. Check DUMP / Listener.")
                    )
                )
            )
        )
        -- return
    ),

    /*
    Returns the first MODEL NODE that currently has its own ORTHO display rotation active.
    This compatibility helper never implies that the rest of the scene is rotated.
    */
    function getActiveOrthoModelNode =
    (
        active_node = undefined

        for node_value in shapes do
        (
            if (active_node == undefined and isModelNodeOrthoActive node_value) then
            (
                active_node = node_value
            )
        )

        active_node
        -- return
    ),

    /*
    Returns whether any MODEL NODE currently has its own ORTHO display rotation active.
    This remains a compatibility query for global scene operations that require a neutral node state.
    */
    function isOrthoActive =
    (
        hasActiveModelOrtho()
        -- return
    ),

    /*
    Activates ORTHO only on the selected MODEL NODE Text object.
    Linked MODEL members keep their exact world transforms and no other scene root is parented or rotated.
    */
    function activateModelNodeOrtho model_node =
    (
        dumpLog ("FN | activateModelNodeOrtho | START | node=" + (model_node as string))

        if not isModelNode model_node then
        (
            #(false, "Select a valid MODEL NODE first.")
        )
        else if isModelNodeOrthoActive model_node then
        (
            #(true, "MODEL NODE is already ORTHO: " + model_node.name)
        )
        else
        (
            rotation_delta = getUserPropVal model_node "SMM_ORTHO_DELTA_Z"
            if rotation_delta == undefined then rotation_delta = 0.0

            member_nodes = getModelNodeMembers model_node
            member_transforms = #()

            for member_node in member_nodes do
            (
                append member_transforms member_node.transform
            )

            original_rotation = model_node.rotation
            operation_ok = true
            error_text = ""
            dumpLog ("FN | activateModelNodeOrtho | NODE ONLY | delta=" + (rotation_delta as string) + " | membersPreserved=" + (member_nodes.count as string))

            try
            (
                setUserPropVal model_node "SMM_ORTHO_ORIGINAL_ROTATION" original_rotation
                setUserPropVal model_node "SMM_ORTHO_BOUND_HANDLES" #()
                model_node.rotation = quat rotation_delta [0,0,1]

                for member_index = 1 to member_nodes.count do
                (
                    member_nodes[member_index].transform = member_transforms[member_index]
                )

                setUserPropVal model_node "SMM_ORTHO_VIEW_ACTIVE" true
            )
            catch
            (
                operation_ok = false
                error_text = getCurrentException()
                dumpLog ("FN | activateModelNodeOrtho | ERROR | " + error_text)
            )

            if operation_ok then
            (
                #(true, "MODEL NODE ORTHO: " + model_node.name + " | Scene unchanged")
            )
            else
            (
                rollback_ok = true

                try
                (
                    model_node.rotation = original_rotation

                    for member_index = 1 to member_nodes.count do
                    (
                        member_nodes[member_index].transform = member_transforms[member_index]
                    )

                    setUserPropVal model_node "SMM_ORTHO_VIEW_ACTIVE" false
                    setUserPropVal model_node "SMM_ORTHO_BOUND_HANDLES" #()
                )
                catch
                (
                    rollback_ok = false
                    rollback_error_text = getCurrentException()
                    dumpLog ("FN | activateModelNodeOrtho | ROLLBACK ERROR | " + rollback_error_text)
                )

                if rollback_ok then
                (
                    #(false, "Could not rotate MODEL NODE to ORTHO: " + error_text)
                )
                else
                (
                    #(false, "Could not rotate MODEL NODE to ORTHO and rollback also failed. Check DUMP / Listener.")
                )
            )
        )
        -- return
    ),

    /*
    Restores only one MODEL NODE from its temporary ORTHO display rotation.
    When no node is supplied, the first active MODEL NODE is used for backward compatibility.
    */
    function restoreOrthoView model_node:undefined =
    (
        dumpLog ("FN | restoreOrthoView | START | node=" + (model_node as string))
        target_node = model_node
        if target_node == undefined then target_node = getActiveOrthoModelNode()

        if target_node == undefined then
        (
            #(true, "MODEL NODE ORTHO is already ORIGINAL.")
        )
        else if not isModelNode target_node then
        (
            #(false, "Select a valid MODEL NODE first.")
        )
        else if not isModelNodeOrthoActive target_node then
        (
            #(true, "MODEL NODE is already ORIGINAL: " + target_node.name)
        )
        else
        (
            original_rotation = getUserPropVal target_node "SMM_ORTHO_ORIGINAL_ROTATION"

            if original_rotation == undefined then
            (
                #(false, "MODEL NODE ORTHO state is missing its original rotation.")
            )
            else
            (
                active_rotation = target_node.rotation
                member_nodes = getModelNodeMembers target_node
                member_transforms = #()

                for member_node in member_nodes do
                (
                    append member_transforms member_node.transform
                )

                operation_ok = true
                error_text = ""

                try
                (
                    target_node.rotation = original_rotation

                    for member_index = 1 to member_nodes.count do
                    (
                        member_nodes[member_index].transform = member_transforms[member_index]
                    )

                    setUserPropVal target_node "SMM_ORTHO_VIEW_ACTIVE" false
                    setUserPropVal target_node "SMM_ORTHO_BOUND_HANDLES" #()
                )
                catch
                (
                    operation_ok = false
                    error_text = getCurrentException()
                    dumpLog ("FN | restoreOrthoView | ERROR | " + error_text)
                )

                if operation_ok then
                (
                    #(true, "MODEL NODE ORIGINAL: " + target_node.name + " | Scene unchanged")
                )
                else
                (
                    rollback_ok = true

                    try
                    (
                        target_node.rotation = active_rotation

                        for member_index = 1 to member_nodes.count do
                        (
                            member_nodes[member_index].transform = member_transforms[member_index]
                        )

                        setUserPropVal target_node "SMM_ORTHO_VIEW_ACTIVE" true
                    )
                    catch
                    (
                        rollback_ok = false
                        rollback_error_text = getCurrentException()
                        dumpLog ("FN | restoreOrthoView | ROLLBACK ERROR | " + rollback_error_text)
                    )

                    if rollback_ok then
                    (
                        #(false, "Could not restore MODEL NODE ORIGINAL rotation: " + error_text)
                    )
                    else
                    (
                        #(false, "Could not restore MODEL NODE ORIGINAL rotation and rollback also failed. Check DUMP / Listener.")
                    )
                )
            )
        )
        -- return
    ),

    /*
    Clears one active MODEL NODE ORTHO display state while preserving all member world transforms.
    Node-only ORTHO has no scene transform to bake, so this is equivalent to restoring that node to ORIGINAL.
    */
    function bakeOrthoView model_node:undefined =
    (
        result_value = restoreOrthoView model_node:model_node
        result_value[1]
        -- return
    ),

    /*
    Applies the stored MODEL NODE ORTHO correction to its linked members only inside an export transaction.
    Other scene roots remain untouched; Hold/Fetch restores the source scene after export.
    */
    function applyModelNodeExportOrtho model_node =
    (
        dumpLog ("FN | applyModelNodeExportOrtho | START | node=" + (model_node as string))

        if not isModelNode model_node then
        (
            false
        )
        else
        (
            rotation_delta = getUserPropVal model_node "SMM_ORTHO_DELTA_Z"
            if rotation_delta == undefined then rotation_delta = 0.0

            member_nodes = getModelNodeMembers model_node
            member_transforms = #()

            for member_node in member_nodes do
            (
                append member_transforms member_node.transform
            )

            operation_ok = true

            try
            (
                model_node.rotation = ((eulerAngles 0.0 0.0 0.0) as quat)

                for member_index = 1 to member_nodes.count do
                (
                    member_nodes[member_index].transform = member_transforms[member_index]
                )

                model_node.rotation = quat rotation_delta [0,0,1]
                dumpLog ("FN | applyModelNodeExportOrtho | APPLY | delta=" + (rotation_delta as string) + " | members=" + (member_nodes.count as string))
            )
            catch
            (
                operation_ok = false
                dumpLog ("FN | applyModelNodeExportOrtho | ERROR | " + (getCurrentException()))
            )

            operation_ok
        )
        -- return
    ),

    /*
    Prepares the held temporary scene for one MODEL NODE export orientation.
    Interactive ORTHO state on that node is normalized first; only its linked members receive the export correction.
    */
    function prepareModelNodeTransaction model_node =
    (
        prepare_ok = true

        if isModelNodeOrthoActive model_node then
        (
            restore_result = restoreOrthoView model_node:model_node
            prepare_ok = restore_result[1]
        )

        if prepare_ok then
        (
            applyModelNodeExportOrtho model_node
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
        dumpLog ("FN | createModelMaxCopy | START | node=" + (model_node as string) + " | path=" + (target_path as string))
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
                    dumpLog ("FN | createModelMaxCopy | SCALE | ratio=" + (ratio_value as string) + " | factor=" + (scale_factor as string))

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
        dumpLog ("FN | exportModelNodeObj | START | node=" + (model_node as string) + " | path=" + (obj_path as string))
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
            dumpLog ("FN | exportModelNodeObj | SCALE | ratio=" + (ratio_value as string) + " | factor=" + (scale_factor as string))

            try
            (
                holdMaxFile()
                hold_created = true

                if prepareModelNodeTransaction model_node then
                (
                    rescaleWorldUnits scale_factor
                    setTargetUnits target_type display_type
                    export_geometry = getModelNodeExportGeometry model_node

                    dumpLog ("FN | exportModelNodeObj | GEOMETRY | count=" + (export_geometry.count as string))
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
        dumpLog ("FN | exportAllModelNodesObj | START | folder=" + export_folder)
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
                sync_result = syncBoundMatchingLayerMembers model_node

                if not sync_result[1] then
                (
                    failed_count += 1
                    dumpLog ("FN | exportAllModelNodesObj | BIND MATCHING LAYER FAILED | node=" + model_name + " | " + sync_result[5])
                    format "Scene Model Manager batch export auto-bind failed | % | %\n" model_name sync_result[5]
                )
                else
                (
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
