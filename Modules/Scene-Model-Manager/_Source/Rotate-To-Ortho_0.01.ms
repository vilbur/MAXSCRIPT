/*
Rotate-To-Ortho
File version: 0.05
Project version: 0.05
Creates a reversible ORTHO rotation helper for the current selection.
*/

global rotate_to_ortho_file_version = 0.05
global rotate_to_ortho_file_project_version = 0.05
global rotate_to_ortho_global_project_version
global rotate_to_ortho_source_file = getSourceFileName()
global rotate_to_ortho_ini_file = (getDir #plugcfg) + "\\Rotate-To-Ortho.ini"

if rotate_to_ortho_global_project_version == undefined then
(
    rotate_to_ortho_global_project_version = rotate_to_ortho_file_project_version
)
else if rotate_to_ortho_file_project_version > rotate_to_ortho_global_project_version then
(
    rotate_to_ortho_global_project_version = rotate_to_ortho_file_project_version
)

global rotate_to_ortho_title = "ROTATE TO ORTHO " + (rotate_to_ortho_global_project_version as string)

try
(
    destroyDialog rotateSelectionToOrtho_rollout
)
catch
(
)


/*
Returns true when pickPoint was cancelled.
Handles ESC and RMB cancellation.
*/
function isPickCancelled picked_value
(
    if (picked_value == #escape) or (picked_value == #rightClick) then
    (
        true
    )
    else
    (
        false
    )
    -- return
)


/*
Gets or creates the rotation-helper layer.
The helper is always placed on _HELPERS>Rotation.
*/
function getRotationHelperLayer layer_name
(
    layer_ref = LayerManager.getLayerFromName layer_name

    if layer_ref == undefined then
    (
        layer_ref = LayerManager.newLayerFromName layer_name
    )

    layer_ref
    -- return
)


/*
Returns only top-level nodes inside the current selection.
Selected child hierarchies remain intact when linked to the helper.
*/
function getSelectedRootNodes selected_nodes
(
    root_nodes = #()

    for node_item in selected_nodes do
    (
        parent_node = node_item.parent

        if (parent_node == undefined) or ((findItem selected_nodes parent_node) == 0) then
        (
            append root_nodes node_item
        )
    )

    root_nodes
    -- return
)


/*
Returns the largest world-space dimension of the complete selection.
All selected objects are evaluated together as one bounding box.
*/
function getSelectionMaxDimension selected_nodes
(
    if selected_nodes.count == 0 then
    (
        0.0
    )
    else
    (
        world_tm = matrix3 1
        first_bounds = nodeGetBoundingBox selected_nodes[1] world_tm
        bounds_min = copy first_bounds[1]
        bounds_max = copy first_bounds[2]

        for node_index = 2 to selected_nodes.count do
        (
            node_bounds = nodeGetBoundingBox selected_nodes[node_index] world_tm

            if node_bounds[1].x < bounds_min.x then
            (
                bounds_min.x = node_bounds[1].x
            )
            if node_bounds[1].y < bounds_min.y then
            (
                bounds_min.y = node_bounds[1].y
            )
            if node_bounds[1].z < bounds_min.z then
            (
                bounds_min.z = node_bounds[1].z
            )

            if node_bounds[2].x > bounds_max.x then
            (
                bounds_max.x = node_bounds[2].x
            )
            if node_bounds[2].y > bounds_max.y then
            (
                bounds_max.y = node_bounds[2].y
            )
            if node_bounds[2].z > bounds_max.z then
            (
                bounds_max.z = node_bounds[2].z
            )
        )

        bounds_size = bounds_max - bounds_min
        max_dimension = bounds_size.x

        if bounds_size.y > max_dimension then
        (
            max_dimension = bounds_size.y
        )
        if bounds_size.z > max_dimension then
        (
            max_dimension = bounds_size.z
        )

        max_dimension
    )
    -- return
)


/*
Returns helper size using decade-based world scaling.
Up to 1 m -> 0.1 m, up to 10 m -> 1 m, up to 100 m -> 10 m, and so on.
*/
function getRotationHelperSize max_dimension
(
    helper_size = units.decodeValue "0.1m"
    dimension_threshold = units.decodeValue "1m"

    while max_dimension > dimension_threshold do
    (
        helper_size *= 10.0
        dimension_threshold *= 10.0
    )

    helper_size
    -- return
)


/*
Calculates world-Z correction for the picked XY direction.
The direction is aligned to the nearest positive or negative world X/Y axis.
*/
function getOrthoRotationDelta picked_vector
(
    vector_xy = [picked_vector.x, picked_vector.y, 0.0]

    if (length vector_xy) < 0.000001 then
    (
        undefined
    )
    else
    (
        direction_angle = atan2 vector_xy.y vector_xy.x
        snapped_angle = (round (direction_angle / 90.0)) * 90.0
        rotation_delta = snapped_angle - direction_angle

        rotation_delta
    )
    -- return
)


/*
Creates a neutral Point helper at the picked pivot.
Zero helper rotation represents the original state of linked objects.
*/
function createRotationHelper picked_point helper_size
(
    helper_node = point \
        name:(uniqueName "ORTHO_ROTATION_") \
        pos:picked_point \
        size:helper_size \
        box:on \
        cross:off \
        centermarker:off \
        axistripod:on \
        constantscreensize:off \
        drawontop:off

    helper_node.axisLength = helper_size
    helper_node.wirecolor = color 255 128 0
    helper_node.rotation = ((eulerAngles 0.0 0.0 0.0) as quat)

    helper_layer = getRotationHelperLayer "_HELPERS>Rotation"
    helper_layer.addNode helper_node

    helper_node
    -- return
)


/*
Parents selected hierarchy roots to the helper.
Every linked root keeps exactly the same world transform after linking.
*/
function bindNodesToRotationHelper root_nodes helper_node
(
    for node_item in root_nodes do
    (
        original_tm = node_item.transform
        node_item.parent = helper_node
        node_item.transform = original_tm
    )

    true
    -- return
)


/*
Returns true when a node is a Rotate-To-Ortho helper.
The helper is identified by the user properties stored by this tool.
*/
function isRotationHelperNode node_item
(
    if node_item == undefined then
    (
        false
    )
    else
    (
        helper_file_version = getUserPropVal node_item "RotationHelperFileVersion"
        rotation_delta = getUserPropVal node_item "OrthoRotationDeltaZ"

        (helper_file_version != undefined) and (rotation_delta != undefined)
    )
    -- return
)


/*
Returns all Rotate-To-Ortho helpers in the supplied node array.
RELINK requires exactly one helper in the current selection.
*/
function getSelectedRotationHelpers selected_nodes
(
    helper_nodes = #()

    for node_item in selected_nodes do
    (
        if isRotationHelperNode node_item then
        (
            append helper_nodes node_item
        )
    )

    helper_nodes
    -- return
)


/*
Returns true when a node is already linked anywhere below the helper.
This prevents RELINK from creating an unnecessary new parent relationship.
*/
function isNodeLinkedUnderHelper node_item helper_node
(
    parent_node = node_item.parent
    is_linked = false

    while (parent_node != undefined) and (not is_linked) do
    (
        if parent_node == helper_node then
        (
            is_linked = true
        )
        else
        (
            parent_node = parent_node.parent
        )
    )

    is_linked
    -- return
)


/*
Returns selected hierarchy roots that are not already linked to the helper.
The helper itself is excluded from the returned node array.
*/
function getRelinkableRootNodes selected_nodes helper_node
(
    object_nodes = #()

    for node_item in selected_nodes do
    (
        if node_item != helper_node then
        (
            append object_nodes node_item
        )
    )

    root_nodes = getSelectedRootNodes object_nodes
    relink_nodes = #()

    for node_item in root_nodes do
    (
        if not isNodeLinkedUnderHelper node_item helper_node then
        (
            append relink_nodes node_item
        )
    )

    relink_nodes
    -- return
)


/*
Relinks selected unbound objects to one selected Rotate-To-Ortho helper.
The helper is evaluated at its original frame for binding, then the starting time is restored.
*/
function relinkSelectionToRotationHelper
(
    selected_nodes = selection as array
    helper_nodes = getSelectedRotationHelpers selected_nodes

    if helper_nodes.count != 1 then
    (
        messageBox \
            "Select exactly one Rotate-To-Ortho helper together with one or more unlinked objects." \
            title:"Rotate To Ortho - Relink"

        false
    )
    else
    (
        helper_node = helper_nodes[1]
        relink_nodes = getRelinkableRootNodes selected_nodes helper_node

        if relink_nodes.count == 0 then
        (
            messageBox \
                "No unlinked selected objects were found." \
                title:"Rotate To Ortho - Relink"

            false
        )
        else
        (
            start_time = sliderTime
            original_frame = getUserPropVal helper_node "OrthoOriginalFrame"

            if original_frame == undefined then
            (
                original_frame = 1
            )

            original_time = original_frame * 1f

            undo "Relink To Ortho Helper" on
            (
                sliderTime = original_time
                bindNodesToRotationHelper relink_nodes helper_node
                sliderTime = start_time
            )

            select selected_nodes

            format "\nROTATE TO ORTHO - RELINK\n"
            format "Helper: %\n" helper_node.name
            format "Relinked root object(s): %\n" relink_nodes.count
            format "Bound at original frame: %\n" original_frame
            format "Restored start time: %\n\n" start_time

            true
        )
    )
    -- return
)


/*
Stores alignment data on the Point helper.
The values remain saved with the scene in User Defined Properties.
*/
function saveRotationHelperData helper_node picked_point picked_vector rotation_delta helper_size max_dimension
(
    setUserPropVal helper_node "RotationHelperFileVersion" rotate_to_ortho_file_version
    setUserPropVal helper_node "RotationHelperProjectVersion" rotate_to_ortho_global_project_version
    setUserPropVal helper_node "OrthoPivot" picked_point
    setUserPropVal helper_node "OrthoPickedVectorXY" picked_vector
    setUserPropVal helper_node "OrthoRotationAxis" [0,0,1]
    setUserPropVal helper_node "OrthoRotationDeltaZ" rotation_delta
    setUserPropVal helper_node "OrthoNeutralRotation" ((eulerAngles 0.0 0.0 0.0) as quat)
    setUserPropVal helper_node "OrthoAlignedRotation" (quat rotation_delta [0,0,1])
    setUserPropVal helper_node "OrthoOriginalFrame" 1
    setUserPropVal helper_node "OrthoAlignedFrame" 0
    setUserPropVal helper_node "OrthoHelperSize" helper_size
    setUserPropVal helper_node "OrthoSelectionMaxDimension" max_dimension

    true
    -- return
)


/*
Creates keys for ORIGINAL and ORTHO states.
Frame 1 is neutral/original and frame 0 is the aligned state.
*/
function animateRotationHelper helper_node rotation_delta
(
    neutral_rotation = ((eulerAngles 0.0 0.0 0.0) as quat)
    aligned_rotation = quat rotation_delta [0,0,1]

    animate on
    (
        at time 1f
        (
            helper_node.rotation = neutral_rotation
        )

        at time 0f
        (
            helper_node.rotation = aligned_rotation
        )
    )

    true
    -- return
)


/*
Returns a saved dialog position when available.
Falls back to the default 3ds Max dialog position when no valid position exists.
*/
function getRotateToOrthoDialogPosition
(
    saved_x = getIniSetting rotate_to_ortho_ini_file "UI" "X"
    saved_y = getIniSetting rotate_to_ortho_ini_file "UI" "Y"

    if (saved_x != "") and (saved_y != "") then
    (
        [(saved_x as integer), (saved_y as integer)]
    )
    else
    (
        undefined
    )
    -- return
)


/*
Saves the current dialog position.
The position is restored the next time the tool is opened.
*/
function saveRotateToOrthoDialogPosition dialog_pos
(
    if dialog_pos != undefined then
    (
        setIniSetting rotate_to_ortho_ini_file "UI" "X" (dialog_pos.x as string)
        setIniSetting rotate_to_ortho_ini_file "UI" "Y" (dialog_pos.y as string)
    )

    true
    -- return
)


/*
Extracts the numeric version suffix from a versioned MaxScript filename.
Expected form is Tool-Name_0.01.ms.
*/
function getScriptFileVersion script_file
(
    file_base = getFilenameFile script_file
    name_parts = filterString file_base "_"

    if name_parts.count >= 2 then
    (
        name_parts[name_parts.count] as float
    )
    else
    (
        undefined
    )
    -- return
)


/*
Reloads the newest versioned script from the current script directory.
If no newer file exists, the current source file is reloaded.
*/
function reloadNewestScriptVersion source_file
(
    if (source_file == undefined) or (source_file == "") then
    (
        false
    )
    else
    (
        source_path = getFilenamePath source_file
        source_base = getFilenameFile source_file
        source_parts = filterString source_base "_"

        if source_parts.count < 2 then
        (
            fileIn source_file
            true
        )
        else
        (
            version_token = source_parts[source_parts.count]
            prefix_length = source_base.count - version_token.count
            source_prefix = substring source_base 1 prefix_length
            matching_files = getFiles (source_path + source_prefix + "*.ms")

            newest_file = source_file
            newest_version = getScriptFileVersion source_file

            if newest_version == undefined then
            (
                newest_version = 0.0
            )

            for candidate_file in matching_files do
            (
                candidate_version = getScriptFileVersion candidate_file

                if (candidate_version != undefined) and (candidate_version > newest_version) then
                (
                    newest_version = candidate_version
                    newest_file = candidate_file
                )
            )

            fileIn newest_file
            true
        )
    )
    -- return
)


/*
Runs the complete interactive ORTHO alignment operation.
Pick the pivot first and then pick an XY direction.
*/
function rotateSelectionToOrtho
(
    selected_nodes = selection as array

    if selected_nodes.count == 0 then
    (
        messageBox "Select one or more objects first." title:"Rotate Selection To Ortho"
        false
    )
    else
    (
        picked_point = pickPoint prompt:"Pick rotation pivot" snap:#3D

        if isPickCancelled picked_point then
        (
            false
        )
        else
        (
            direction_point = pickPoint \
                prompt:"Pick XY direction" \
                rubberBand:picked_point \
                snap:#3D

            if isPickCancelled direction_point then
            (
                false
            )
            else
            (
                picked_vector = direction_point - picked_point
                picked_vector_xy = [picked_vector.x, picked_vector.y, 0.0]
                rotation_delta = getOrthoRotationDelta picked_vector_xy

                if rotation_delta == undefined then
                (
                    messageBox "The picked XY vector is too short." title:"Rotate Selection To Ortho"
                    false
                )
                else
                (
                    max_dimension = getSelectionMaxDimension selected_nodes
                    helper_size = getRotationHelperSize max_dimension

                    undo "Rotate Selection To Ortho" on
                    (
                        helper_node = createRotationHelper picked_point helper_size
                        root_nodes = getSelectedRootNodes selected_nodes

                        bindNodesToRotationHelper root_nodes helper_node
                        animateRotationHelper helper_node rotation_delta
                        saveRotationHelperData helper_node picked_point picked_vector_xy rotation_delta helper_size max_dimension

                        sliderTime = 0f
                        select selected_nodes

                        format "\nROTATE TO ORTHO\n"
                        format "Helper: %\n" helper_node.name
                        format "Layer: _HELPERS>Rotation\n"
                        format "Correction Z: % deg\n" rotation_delta
                        format "Frame 0: ORTHO\n"
                        format "Frame 1: ORIGINAL / helper rotation 0,0,0\n"
                        format "Helper size: %\n" helper_size
                        format "Selection max dimension: %\n\n" max_dimension
                    )

                    true
                )
            )
        )
    )
    -- return
)


rollout rotateSelectionToOrtho_rollout rotate_to_ortho_title width:240
(
    button btn_create \
        "PICK PIVOT + VECTOR" \
        width:220 \
        height:38 \
        align:#center \
        tooltip:"LMB: Pick the rotation pivot, then pick an XY direction to align to the nearest world X/Y axis."

    button btn_relink \
        "RELINK" \
        width:220 \
        height:30 \
        align:#center \
        tooltip:"LMB: Return the helper to its original state, link selected unbound objects, then restore the starting state."

    button btn_restart \
        "RESTART" \
        width:220 \
        height:24 \
        align:#center \
        tooltip:"LMB: Reload the newest available version of this tool."

    on btn_create pressed do
    (
        rotateSelectionToOrtho()
    )

    on btn_relink pressed do
    (
        relinkSelectionToRotationHelper()
    )

    on btn_restart pressed do
    (
        reloadNewestScriptVersion rotate_to_ortho_source_file
    )

    on rotateSelectionToOrtho_rollout moved dialog_pos do
    (
        saveRotateToOrthoDialogPosition dialog_pos
    )

    on rotateSelectionToOrtho_rollout help do
    (
        reloadNewestScriptVersion rotate_to_ortho_source_file
    )
)


dialog_pos = getRotateToOrthoDialogPosition()

if dialog_pos == undefined then
(
    createDialog rotateSelectionToOrtho_rollout
)
else
(
    createDialog rotateSelectionToOrtho_rollout pos:dialog_pos
)
