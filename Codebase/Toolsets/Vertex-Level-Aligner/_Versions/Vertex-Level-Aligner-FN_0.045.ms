/*
Vertex Level Aligner FN 0.045
Backend-only functional module. Scans Editable Poly / Edit Poly vertex levels on a selected world X/Y/Z axis, groups nearby exact levels by threshold, and exposes selection data to the frontend.
*/

global vertex_level_aligner
global EPOLY_TOOLS_RUNTIME_MODE
global vertex_level_aligner_log_path
global vertexLevelAlignerWriteLog
global vertexLevelAlignerStartLog
global vertex_level_aligner_default_threshold

vertex_level_aligner_default_threshold = 0.0

/*
Writes one crash-trace marker and closes the file immediately so the last completed stage survives a hard 3ds Max crash.
*/
function vertexLevelAlignerWriteLog message_text =
(
    try
    (
        if vertex_level_aligner_log_path != undefined and vertex_level_aligner_log_path != "" then
        (
            log_stream = openFile vertex_level_aligner_log_path mode:"a"

            if log_stream != undefined then
            (
                format "%\n" message_text to:log_stream
                close log_stream
            )
        )
    )
    catch
    (
    )

    true
    -- return
)

/*
Creates a fresh crash log next to the canonical script for each direct backend execution.
*/
function vertexLevelAlignerStartLog source_file =
(
    if source_file == undefined or source_file == "" then return false

    vertex_level_aligner_log_path = getFilenamePath source_file + "Vertex-Level-Aligner-crash.log"
    log_stream = createFile vertex_level_aligner_log_path

    if log_stream == undefined then return false

    format "000 START Vertex Level Aligner project 0.812\n" to:log_stream
    close log_stream
    true
    -- return
)

struct vertex_level_aligner_v
(
    file_version = 0.045,
    project_version = 0.812,
    scan_node = undefined,
    scan_modifier = undefined,
    scan_kind = #none,
    scan_vertex_count = 0,
    threshold_value = vertex_level_aligner_default_threshold,
    world_axis = #z,
    exact_epsilon = 0.000001,
    level_groups = #(),
    last_message = "Select one Editable Poly or Edit Poly object.",

    /*
    Returns true when one Edit Poly modifier belongs to the supplied node.
    Modifier identity is checked directly against the node modifier stack.
    */
    function modifierBelongsToNode node_value modifier_value =
    (
        if node_value == undefined or modifier_value == undefined then return false
        if not(isValidNode node_value) then return false
        if classOf modifier_value != Edit_Poly then return false

        for modifier_index = 1 to node_value.modifiers.count do
        (
            if node_value.modifiers[modifier_index] == modifier_value then return true
        )

        false
        -- return
    ),

    /*
    Returns the currently active Edit Poly modifier when it belongs to the node.
    Otherwise the first Edit Poly modifier in the stack is returned.
    */
    function getEditPolyModifier node_value =
    (
        if node_value == undefined or not(isValidNode node_value) then return undefined

        current_object = try(modPanel.getCurrentObject())catch(undefined)

        if current_object != undefined then
        (
            if classOf current_object == Edit_Poly and this.modifierBelongsToNode node_value current_object then return current_object
        )

        for modifier_index = 1 to node_value.modifiers.count do
        (
            modifier_value = node_value.modifiers[modifier_index]
            if classOf modifier_value == Edit_Poly then return modifier_value
        )

        undefined
        -- return
    ),

    /*
    Resolves one scan target as #(kind, node, topology object).
    An explicit Edit Poly modifier takes priority over automatic resolution.
    */
    function resolveContext node_value modifier_value:undefined =
    (
        if node_value == undefined or not(isValidNode node_value) then return #(#none, undefined, undefined)

        if modifier_value != undefined then
        (
            if this.modifierBelongsToNode node_value modifier_value then return #(#edit_poly, node_value, modifier_value)
        )

        edit_modifier = this.getEditPolyModifier node_value
        if edit_modifier != undefined then
        (
            try(edit_modifier.showCage = off)catch()
            return #(#edit_poly, node_value, edit_modifier)
        )

        if classOf node_value.baseObject == Editable_Poly then
        (
            try(node_value.baseObject.showCage = off)catch()
            return #(#editable_poly, node_value, node_value.baseObject)
        )

        #(#none, node_value, undefined)
        -- return
    ),

    /*
    Returns the live vertex count for one resolved Editable Poly or Edit Poly context.
    Unsupported contexts return zero.
    */
    function getContextVertexCount context_data =
    (
        context_kind = context_data[1]
        node_value = context_data[2]
        topology_value = context_data[3]

        if context_kind == #editable_poly then
        (
            return polyop.getNumVerts topology_value
        )

        if context_kind == #edit_poly then
        (
            return try(EditPolyMod.GetNumVertices topology_value node:node_value)catch(0)
        )

        0
        -- return
    ),

    /*
    Reads one live vertex position from the resolved target and converts it to world space.
    Invalid/dead vertices return undefined and are skipped by the scanner.
    */
    function getWorldVertexPosition context_data vertex_id =
    (
        context_kind = context_data[1]
        node_value = context_data[2]
        topology_value = context_data[3]
        vertex_position = undefined

        if context_kind == #editable_poly then
        (
            is_dead = try(polyop.isVertDead topology_value vertex_id)catch(false)
            if is_dead then return undefined
            vertex_position = try(polyop.getVert topology_value vertex_id)catch(undefined)
        )
        else if context_kind == #edit_poly then
        (
            vertex_position = try(EditPolyMod.GetVertex topology_value vertex_id node:node_value)catch(undefined)
        )

        if vertex_position == undefined then return undefined

        vertex_position * node_value.objectTransform
        -- return
    ),

    /*
    Normalizes one requested world-axis symbol to #x, #y, or #z.
    Invalid values fall back to #z.
    */
    function normalizeWorldAxis world_axis_value =
    (
        case world_axis_value of
        (
            #x: #x
            #y: #y
            #z: #z
            default: #z
        )
        -- return
    ),

    /*
    Returns one point component on the requested world axis.
    When no axis is supplied, the backend's currently selected world axis is used.
    */
    function getWorldAxisValue world_position world_axis_value:undefined =
    (
        if world_position == undefined then return undefined

        axis_to_use = if world_axis_value == undefined then world_axis else this.normalizeWorldAxis world_axis_value

        case axis_to_use of
        (
            #x: world_position.x
            #y: world_position.y
            default: world_position.z
        )
        -- return
    ),

    /*
    Returns a world-space delta vector constrained to one selected world axis.
    */
    function getWorldAxisDeltaVector delta_world_value world_axis_value:undefined =
    (
        axis_to_use = if world_axis_value == undefined then world_axis else this.normalizeWorldAxis world_axis_value

        case axis_to_use of
        (
            #x: [delta_world_value,0,0]
            #y: [0,delta_world_value,0]
            default: [0,0,delta_world_value]
        )
        -- return
    ),

    /*
    Returns the selected world-axis name for UI/status text.
    */
    function getWorldAxisText world_axis_value:undefined =
    (
        axis_to_use = if world_axis_value == undefined then world_axis else this.normalizeWorldAxis world_axis_value

        case axis_to_use of
        (
            #x: "X"
            #y: "Y"
            default: "Z"
        )
        -- return
    ),

    /*
    Compares two #(axis_position, vertex_id) samples for qsort.
    Axis position is primary and vertex ID is a deterministic tie-breaker.
    */
    function compareVertexSamples sample_a sample_b =
    (
        if sample_a[1] < sample_b[1] then return -1
        if sample_a[1] > sample_b[1] then return 1
        if sample_a[2] < sample_b[2] then return -1
        if sample_a[2] > sample_b[2] then return 1

        0
        -- return
    ),

    /*
    Collects and sorts live samples for every vertex on the selected world axis.
    Each sample stores #(world_axis_position, vertex_id).
    */
    function collectVertexSamples context_data =
    (
        sample_values = #()
        vertex_count = this.getContextVertexCount context_data

        for vertex_id = 1 to vertex_count do
        (
            world_position = this.getWorldVertexPosition context_data vertex_id

            if world_position != undefined then
            (
                axis_position = this.getWorldAxisValue world_position
                append sample_values #(axis_position, vertex_id)
            )
        )

        qsort sample_values this.compareVertexSamples
        sample_values
        -- return
    ),

    /*
    Collapses selected-axis samples into exact level entries using the supplied numeric tolerance.
    A zero tolerance preserves every distinct stored axis value without epsilon rounding.
    */
    function buildExactLevels sample_values tolerance:undefined =
    (
        exact_levels = #()
        current_level = undefined
        level_tolerance = if tolerance == undefined then exact_epsilon else tolerance

        if level_tolerance < 0.0 then level_tolerance = 0.0

        for sample_value in sample_values do
        (
            sample_axis_value = sample_value[1]
            vertex_id = sample_value[2]

            if current_level == undefined then
            (
                current_bits = #{}
                current_bits[vertex_id] = true
                current_level = #(sample_axis_value, current_bits)
                append exact_levels current_level
            )
            else
            (
                if abs(sample_axis_value - current_level[1]) <= level_tolerance then
                (
                    current_level[2][vertex_id] = true
                )
                else
                (
                    current_bits = #{}
                    current_bits[vertex_id] = true
                    current_level = #(sample_axis_value, current_bits)
                    append exact_levels current_level
                )
            )
        )

        exact_levels
        -- return
    ),

    /*
    Compatibility helper retained for older callers.
    Vertex Level Aligner no longer removes single-vertex exact levels: every valid exact level is returned.
    */
    function filterSingleVertexLevels exact_levels =
    (
        retained_levels = #()
        if exact_levels == undefined then return retained_levels

        for level_entry in exact_levels do
        (
            if level_entry != undefined and level_entry.count >= 2 and level_entry[2] != undefined then
            (
                append retained_levels level_entry
            )
        )

        retained_levels
        -- return
    ),

    /*
    Builds one threshold group from an ordered array of exact level entries.
    Group data is #(center_axis, min_axis, max_axis, vertex_bits, exact_levels, is_broken).
    */
    function buildGroupData exact_levels =
    (
        if exact_levels == undefined or exact_levels.count == 0 then return undefined

        group_bits = #{}
        min_axis = exact_levels[1][1]
        max_axis = exact_levels[exact_levels.count][1]

        for level_entry in exact_levels do
        (
            level_bits = level_entry[2]

            for vertex_id in level_bits do
            (
                group_bits[vertex_id] = true
            )
        )

        center_axis = (min_axis + max_axis) * 0.5
        is_broken = exact_levels.count > 1

        #(center_axis, min_axis, max_axis, group_bits, exact_levels, is_broken)
        -- return
    ),

    /*
    Groups ordered exact levels by neighboring distance on the selected world axis.
    Consecutive levels stay in one group while every adjacent gap is within threshold, so a chained group may span more than the threshold overall.
    Threshold 0.0 creates one group per exact axis level with no threshold merging.
    */
    function buildThresholdGroups exact_levels threshold:1.0 =
    (
        group_values = #()
        if exact_levels == undefined or exact_levels.count == 0 then return group_values

        threshold_limit = threshold
        if threshold_limit < 0.0 then threshold_limit = 0.0

        if threshold_limit == 0.0 then
        (
            for level_entry in exact_levels do
            (
                group_data = this.buildGroupData #(level_entry)
                if group_data != undefined then append group_values group_data
            )

            return group_values
        )

        current_levels = #()
        previous_axis = undefined

        for level_entry in exact_levels do
        (
            level_axis = level_entry[1]

            if current_levels.count == 0 then
            (
                current_levels = #(level_entry)
            )
            else
            (
                if (level_axis - previous_axis) <= (threshold_limit + exact_epsilon) then
                (
                    append current_levels level_entry
                )
                else
                (
                    group_data = this.buildGroupData current_levels
                    if group_data != undefined then append group_values group_data
                    current_levels = #(level_entry)
                )
            )

            previous_axis = level_axis
        )

        if current_levels.count > 0 then
        (
            group_data = this.buildGroupData current_levels
            if group_data != undefined then append group_values group_data
        )

        group_values
        -- return
    ),

    /*
    Scans one node and stores all threshold groups for later TreeView display and selection.
    Optional modifier selects one explicit Edit Poly topology.
    */
    function scanNode node_value modifier_value:undefined threshold:1.0 world_axis_value:undefined =
    (
        if world_axis_value != undefined then
        (
            world_axis = this.normalizeWorldAxis world_axis_value
        )

        context_data = this.resolveContext node_value modifier_value:modifier_value
        context_kind = context_data[1]

        if context_kind == #none then
        (
            scan_node = undefined
            scan_modifier = undefined
            scan_kind = #none
            scan_vertex_count = 0
            level_groups = #()
            last_message = "Select one Editable Poly or Edit Poly object."
            return false
        )

        threshold_value = threshold
        if threshold_value < 0.0 then threshold_value = 0.0

        sample_values = this.collectVertexSamples context_data
        exact_level_tolerance = if threshold_value == 0.0 then 0.0 else exact_epsilon
        exact_levels = this.buildExactLevels sample_values tolerance:exact_level_tolerance
        level_groups = this.buildThresholdGroups exact_levels threshold:threshold_value

        scan_node = context_data[2]
        scan_kind = context_kind
        scan_modifier = if context_kind == #edit_poly then context_data[3] else undefined
        scan_vertex_count = this.getContextVertexCount context_data

        broken_count = this.getBrokenGroupCount()
        last_message = "Axis " + (this.getWorldAxisText()) + " | " + (level_groups.count as string) + " groups | " + (broken_count as string) + " broken | " + (sample_values.count as string) + " grouped verts | all exact levels retained"

        true
        -- return
    ),

    /*
    Scans the first currently selected scene node.
    Additional selected objects are ignored; the stored threshold is used when none is supplied by the UI.
    */
    function scanSelection threshold:undefined world_axis_value:undefined =
    (
        vertexLevelAlignerWriteLog "400 SCAN selection entered"
        selected_nodes = selection as array
        vertexLevelAlignerWriteLog ("401 SCAN selected node count = " + (selected_nodes.count as string))

        if selected_nodes.count == 0 then
        (
            last_message = "Select one Editable Poly or Edit Poly object."
            return false
        )

        threshold_to_use = threshold_value
        if threshold != undefined then threshold_to_use = threshold

        scan_ok = this.scanNode selected_nodes[1] threshold:threshold_to_use world_axis_value:world_axis_value
        vertexLevelAlignerWriteLog ("409 SCAN complete = " + (scan_ok as string) + " | " + last_message)
        scan_ok
        -- return
    ),

    /*
    Returns the number of stored threshold groups.
    The result is zero before a successful scan.
    */
    function getGroupCount =
    (
        level_groups.count
        -- return
    ),

    /*
    Returns the number of stored groups containing more than one exact Z level.
    These groups are treated as broken layers by the UI filter.
    */
    function getBrokenGroupCount =
    (
        broken_count = 0

        for group_data in level_groups do
        (
            if group_data[6] then broken_count += 1
        )

        broken_count
        -- return
    ),

    /*
    Returns one stored group entry by 1-based index.
    Invalid indexes return undefined.
    */
    function getGroupData group_index =
    (
        if group_index < 1 or group_index > level_groups.count then return undefined

        level_groups[group_index]
        -- return
    ),

    /*
    Returns one exact level entry from one stored group.
    Invalid group or level indexes return undefined.
    */
    function getLevelData group_index level_index =
    (
        group_data = this.getGroupData group_index
        if group_data == undefined then return undefined

        exact_levels = group_data[5]
        if level_index < 1 or level_index > exact_levels.count then return undefined

        exact_levels[level_index]
        -- return
    ),

    /*
    Returns true when stored topology still matches the vertex count used during the scan.
    Geometry topology changes require a new scan before IDs can be selected safely.
    */
    function isStoredContextCurrent =
    (
        if scan_node == undefined or not(isValidNode scan_node) then return false

        context_data = this.resolveContext scan_node modifier_value:scan_modifier
        if context_data[1] != scan_kind then return false

        current_vertex_count = this.getContextVertexCount context_data
        current_vertex_count == scan_vertex_count
        -- return
    ),

    /*
    Unhides the supplied scanned vertices before TreeView selection.
    Editable Poly preserves hidden vertices outside the target set; Edit Poly exposes only Unhide All Vertices, so it unhides vertex components on that modifier before the target selection is applied.
    */
    function unhideVertexBits vertex_bits =
    (
        if vertex_bits == undefined or vertex_bits.numberSet == 0 then return true
        if not(this.isStoredContextCurrent()) then
        (
            last_message = "Topology changed. Scan the object again."
            return false
        )

        if scan_kind == #editable_poly then
        (
            topology_value = scan_node.baseObject
            hidden_vertices = try(polyop.getHiddenVerts topology_value)catch(#{})
            target_hidden_vertices = hidden_vertices * vertex_bits

            if target_hidden_vertices.numberSet > 0 then
            (
                remaining_hidden_vertices = hidden_vertices - vertex_bits
                polyop.unHideAllVerts topology_value

                if remaining_hidden_vertices.numberSet > 0 then
                (
                    polyop.setHiddenVerts topology_value remaining_hidden_vertices
                )

                update scan_node
            )

            return true
        )

        if scan_kind == #edit_poly then
        (
            modifier_value = scan_modifier
            if not(this.modifierBelongsToNode scan_node modifier_value) then return false

            select scan_node
            max modify mode

            try(modifier_value.showCage = off)catch()
            modifier_value.SetPrimaryNode scan_node
            modifier_value.useStackSelection = false
            modifier_value.selectMode = 0
            modPanel.setCurrentObject modifier_value node:scan_node
            modifier_value.SetEPolySelLevel #Vertex
            subObjectLevel = 1
            modifier_value.ButtonOp #UnhideAllVertex
            modifier_value.RefreshScreen()
            return true
        )

        false
        -- return
    ),

    /*
    Visibly selects supplied vertex IDs on the same Editable Poly or Edit Poly topology that was scanned.
    Existing vertex selection is replaced and the Modify panel remains at Vertex level.
    */
    function selectVertexBits vertex_bits =
    (
        if vertex_bits == undefined then return false
        if not(this.isStoredContextCurrent()) then
        (
            last_message = "Topology changed. Scan the object again."
            return false
        )

        select scan_node
        max modify mode

        if scan_kind == #editable_poly then
        (
            topology_value = scan_node.baseObject
            subObjectLevel = 1
            polyop.setVertSelection topology_value vertex_bits
            completeRedraw()
            last_message = (vertex_bits.numberSet as string) + " vertices selected."
            return true
        )

        if scan_kind == #edit_poly then
        (
            modifier_value = scan_modifier
            if not(this.modifierBelongsToNode scan_node modifier_value) then return false

            modifier_value.SetPrimaryNode scan_node
            modifier_value.useStackSelection = false
            modifier_value.selectMode = 0
            modPanel.setCurrentObject modifier_value node:scan_node
            modifier_value.SetEPolySelLevel #Vertex
            subObjectLevel = 1

            old_vertices = modifier_value.GetSelection #Vertex
            if old_vertices.numberSet > 0 then
            (
                modifier_value.Select #Vertex old_vertices select:false
            )

            modifier_value.Select #Vertex vertex_bits select:true
            modifier_value.RefreshScreen()
            completeRedraw()
            last_message = (vertex_bits.numberSet as string) + " vertices selected."
            return true
        )

        false
        -- return
    ),

    /*
    Returns Editable Poly edges whose two endpoint vertices are both inside the supplied level vertex set.
    Candidate edges come from the same live topology that receives the final selection.
    */
    function getEditablePolyEdgesBetweenVertexBits vertex_bits =
    (
        result_edges = #{}
        if vertex_bits == undefined or vertex_bits.numberSet < 2 then return result_edges
        if scan_node == undefined or not(isValidNode scan_node) then return result_edges
        if classOf scan_node.baseObject != Editable_Poly then return result_edges

        topology_value = scan_node.baseObject
        candidate_edges = try(polyop.getEdgesUsingVert topology_value vertex_bits)catch(#{})

        for edge_id in candidate_edges do
        (
            edge_vertices = try(polyop.getVertsUsingEdge topology_value #{edge_id})catch(#{})

            if edge_vertices.numberSet == 2 then
            (
                matching_vertex_count = 0

                for vertex_id in edge_vertices do
                (
                    if vertex_bits[vertex_id] then matching_vertex_count += 1
                )

                if matching_vertex_count == 2 then
                (
                    result_edges[edge_id] = true
                )
            )
        )

        result_edges
        -- return
    ),

    /*
    Returns Edit Poly polygon-boundary edges whose two endpoint vertices are both inside the supplied level vertex set.
    Face vertex/edge IDs are read from the same live Edit Poly topology, so no TriMesh edge IDs are transferred.
    */
    function getEditPolyEdgesBetweenVertexBits vertex_bits =
    (
        result_edges = #{}
        if vertex_bits == undefined or vertex_bits.numberSet < 2 then return result_edges
        if scan_node == undefined or not(isValidNode scan_node) then return result_edges

        modifier_value = scan_modifier
        if not(this.modifierBelongsToNode scan_node modifier_value) then return result_edges

        try(modifier_value.showCage = off)catch()
        modifier_value.SetPrimaryNode scan_node
        modifier_value.useStackSelection = false
        modifier_value.selectMode = 0

        face_count = try(modifier_value.GetNumFaces node:scan_node)catch(0)

        for face_id = 1 to face_count do
        (
            face_degree = try(modifier_value.GetFaceDegree face_id node:scan_node)catch(0)

            if face_degree >= 2 then
            (
                for corner_id = 1 to face_degree do
                (
                    next_corner_id = if corner_id == face_degree then 1 else corner_id + 1
                    vertex_a = try(modifier_value.GetFaceVertex face_id corner_id node:scan_node)catch(0)
                    vertex_b = try(modifier_value.GetFaceVertex face_id next_corner_id node:scan_node)catch(0)

                    if vertex_a > 0 and vertex_b > 0 and vertex_bits[vertex_a] and vertex_bits[vertex_b] then
                    (
                        edge_id = try(modifier_value.GetFaceEdge face_id corner_id node:scan_node)catch(0)
                        if edge_id > 0 then result_edges[edge_id] = true
                    )
                )
            )
        )

        result_edges
        -- return
    ),

    /*
    Resolves edges between vertices on one exact level for the currently scanned topology.
    */
    function getEdgesBetweenVertexBits vertex_bits =
    (
        if scan_kind == #editable_poly then
        (
            return this.getEditablePolyEdgesBetweenVertexBits vertex_bits
        )

        if scan_kind == #edit_poly then
        (
            return this.getEditPolyEdgesBetweenVertexBits vertex_bits
        )

        #{}
        -- return
    ),

    /*
    Visibly selects supplied edges on the same Editable Poly or Edit Poly topology that was scanned.
    Existing edge selection is replaced and the Modify panel remains at Edge level.
    */
    function selectEdgeBits edge_bits =
    (
        if edge_bits == undefined then return false
        if not(this.isStoredContextCurrent()) then
        (
            last_message = "Topology changed. Scan the object again."
            return false
        )

        select scan_node
        max modify mode

        if scan_kind == #editable_poly then
        (
            topology_value = scan_node.baseObject
            subObjectLevel = 2
            polyop.setEdgeSelection topology_value edge_bits
            completeRedraw()
            last_message = (edge_bits.numberSet as string) + " edges selected."
            return true
        )

        if scan_kind == #edit_poly then
        (
            modifier_value = scan_modifier
            if not(this.modifierBelongsToNode scan_node modifier_value) then return false

            try(modifier_value.showCage = off)catch()
            modifier_value.SetPrimaryNode scan_node
            modifier_value.useStackSelection = false
            modifier_value.selectMode = 0
            modPanel.setCurrentObject modifier_value node:scan_node
            modifier_value.SetEPolySelLevel #Edge
            subObjectLevel = 2

            old_edges = modifier_value.GetSelection #Edge
            if old_edges.numberSet > 0 then
            (
                modifier_value.Select #Edge old_edges select:false
            )

            modifier_value.Select #Edge edge_bits select:true
            modifier_value.RefreshScreen()
            completeRedraw()
            last_message = (edge_bits.numberSet as string) + " edges selected."
            return true
        )

        false
        -- return
    ),

    /*
    Returns the selected world-axis target for one group alignment mode.
    UP uses the maximum axis value, MIDDLE uses the group center, and DOWN uses the minimum axis value.
    */
    function getAlignmentTargetAxisValue group_data alignment_mode =
    (
        if group_data == undefined then return undefined

        case alignment_mode of
        (
            #top: group_data[3]
            #middle: group_data[1]
            #bottom: group_data[2]
            default: undefined
        )
        -- return
    ),

    /*
    Compatibility alias for older callers; group scalar data follows the currently selected world axis.
    */
    function getAlignmentTargetZ group_data alignment_mode =
    (
        this.getAlignmentTargetAxisValue group_data alignment_mode
        -- return
    ),

    /*
    Returns a readable alignment mode label for status text.
    */
    function getAlignmentModeText alignment_mode =
    (
        case alignment_mode of
        (
            #here: "HERE"
            #top: "UP"
            #middle: "MIDDLE"
            #bottom: "DOWN"
            default: "UNKNOWN"
        )
        -- return
    ),

    /*
    Moves Editable Poly vertices by one selected world-axis delta while preserving arbitrary node transforms.
    */
    function moveEditablePolyVertexBitsByWorldAxisDelta vertex_bits delta_world_value world_axis_value:undefined =
    (
        if scan_node == undefined or not(isValidNode scan_node) then return false
        if classOf scan_node.baseObject != Editable_Poly then return false

        topology_value = scan_node.baseObject
        try(topology_value.showCage = off)catch()

        world_delta = this.getWorldAxisDeltaVector delta_world_value world_axis_value:world_axis_value
        inverse_transform = inverse scan_node.objectTransform
        local_origin = [0,0,0] * inverse_transform
        local_target = world_delta * inverse_transform
        local_delta = local_target - local_origin

        polyop.moveVert topology_value vertex_bits local_delta
        update scan_node
        true
        -- return
    ),

    /*
    Compatibility wrapper for explicit world-Z movement.
    */
    function moveEditablePolyVertexBitsByWorldZDelta vertex_bits delta_world_z =
    (
        this.moveEditablePolyVertexBitsByWorldAxisDelta vertex_bits delta_world_z world_axis_value:#z
        -- return
    ),

    /*
    Selects one Edit Poly vertex set without changing the backend scan identity.
    */
    function prepareEditPolyVertexSelection vertex_bits =
    (
        if scan_node == undefined or not(isValidNode scan_node) then return false

        modifier_value = scan_modifier
        if not(this.modifierBelongsToNode scan_node modifier_value) then return false

        try(modifier_value.showCage = off)catch()

        select scan_node
        max modify mode

        modifier_value.SetPrimaryNode scan_node
        modifier_value.useStackSelection = false
        modifier_value.selectMode = 0

        modPanel.setCurrentObject modifier_value node:scan_node
        modifier_value.SetEPolySelLevel #Vertex
        subObjectLevel = 1

        old_vertices = modifier_value.GetSelection #Vertex

        if old_vertices.numberSet > 0 then
        (
            modifier_value.Select #Vertex old_vertices select:false
        )

        modifier_value.Select #Vertex vertex_bits select:true
        true
        -- return
    ),

    /*
    Moves one Edit Poly vertex set by a selected world-axis delta using the EditPolyMod transform API.
    */
    function moveEditPolyVertexBitsByWorldAxisDelta vertex_bits delta_world_value world_axis_value:undefined =
    (
        if not(this.prepareEditPolyVertexSelection vertex_bits) then return false

        modifier_value = scan_modifier
        move_amount = this.getWorldAxisDeltaVector delta_world_value world_axis_value:world_axis_value

        if abs(delta_world_value) > exact_epsilon then
        (
            modifier_value.MoveSelection move_amount
            modifier_value.Commit()
        )

        modifier_value.RefreshScreen()
        true
        -- return
    ),

    /*
    Compatibility wrapper for explicit world-Z Edit Poly movement.
    */
    function moveEditPolyVertexBitsByWorldZDelta vertex_bits delta_world_z =
    (
        this.moveEditPolyVertexBitsByWorldAxisDelta vertex_bits delta_world_z world_axis_value:#z
        -- return
    ),

    /*
    Moves a stored vertex set by one delta on the backend's selected world axis.
    */
    function moveVertexBitsByWorldAxisDelta vertex_bits delta_world_value =
    (
        if vertex_bits == undefined or vertex_bits.numberSet == 0 then return false
        if not(this.isStoredContextCurrent()) then return false

        if scan_kind == #editable_poly then
        (
            return this.moveEditablePolyVertexBitsByWorldAxisDelta vertex_bits delta_world_value
        )

        if scan_kind == #edit_poly then
        (
            return this.moveEditPolyVertexBitsByWorldAxisDelta vertex_bits delta_world_value
        )

        false
        -- return
    ),

    /*
    Compatibility wrapper for explicit world-Z dispatch.
    */
    function moveVertexBitsByWorldZDelta vertex_bits delta_world_z =
    (
        if vertex_bits == undefined or vertex_bits.numberSet == 0 then return false
        if not(this.isStoredContextCurrent()) then return false

        if scan_kind == #editable_poly then
        (
            return this.moveEditablePolyVertexBitsByWorldAxisDelta vertex_bits delta_world_z world_axis_value:#z
        )

        if scan_kind == #edit_poly then
        (
            return this.moveEditPolyVertexBitsByWorldAxisDelta vertex_bits delta_world_z world_axis_value:#z
        )

        false
        -- return
    ),

    /*
    Moves one stored vertex set rigidly so its reference value reaches one target on the selected world axis.
    The vertex IDs are preserved; only the supplied selected-item vertices move.
    */
    function moveVertexBitsToAxisValue vertex_bits source_axis_value target_axis_value operation_text =
    (
        if vertex_bits == undefined or vertex_bits.numberSet == 0 then return false
        if source_axis_value == undefined or target_axis_value == undefined then return false
        if not(this.isStoredContextCurrent()) then
        (
            last_message = "Topology changed. Scan the object again."
            return false
        )

        target_node = scan_node
        target_modifier = scan_modifier
        target_threshold = threshold_value
        target_world_axis = world_axis
        delta_world_value = target_axis_value - source_axis_value

        if not(this.moveVertexBitsByWorldAxisDelta vertex_bits delta_world_value) then
        (
            last_message = "Could not move the selected item."
            return false
        )

        completeRedraw()

        if not(this.scanNode target_node modifier_value:target_modifier threshold:target_threshold world_axis_value:target_world_axis) then
        (
            return false
        )

        scan_message = last_message
        last_message = (vertex_bits.numberSet as string) + " vertices " + operation_text + " on world " + (this.getWorldAxisText()) + " | " + scan_message
        true
        -- return
    ),

    /*
    Moves every vertex represented by one group row rigidly to a target reference value on the selected world axis.
    Internal level spacing is preserved because the whole group receives one common delta.
    */
    function moveGroupToAxisValue group_index target_axis_value operation_text =
    (
        group_data = this.getGroupData group_index
        if group_data == undefined then return false

        this.moveVertexBitsToAxisValue group_data[4] group_data[1] target_axis_value operation_text
        -- return
    ),

    /*
    Moves only the vertices represented by one exact child level to a target value on the selected world axis.
    No other level in the parent group is changed.
    */
    function moveLevelToAxisValue group_index level_index target_axis_value operation_text =
    (
        level_data = this.getLevelData group_index level_index
        if level_data == undefined then return false

        this.moveVertexBitsToAxisValue level_data[2] level_data[1] target_axis_value operation_text
        -- return
    ),

    /*
    Snaps one selected-axis world value to the 5 mm grid around an optional display-origin offset.
    UP uses the next/equal grid value; DOWN uses the previous/equal grid value.
    */
    function roundAxisValueToFiveMillimeters source_axis_value round_direction offset_axis_value:0.0 =
    (
        if source_axis_value == undefined then return undefined

        millimeter_scale = units.decodeValue "1mm"
        round_step_value = millimeter_scale * 5.0
        tolerance_value = millimeter_scale * 0.000001
        display_axis_value = source_axis_value - offset_axis_value

        rounded_display_value = case round_direction of
        (
            #up: (ceil ((display_axis_value - tolerance_value) / round_step_value)) * round_step_value
            #down: (floor ((display_axis_value + tolerance_value) / round_step_value)) * round_step_value
            default: display_axis_value
        )

        rounded_display_value + offset_axis_value
        -- return
    ),

    /*
    Rounds one group row to the 5 mm grid by moving only that group's vertices rigidly.
    Internal exact-level spacing is preserved.
    */
    function roundGroupToFiveMillimeters group_index round_direction offset_axis_value:0.0 =
    (
        group_data = this.getGroupData group_index
        if group_data == undefined then return false

        target_axis_value = this.roundAxisValueToFiveMillimeters group_data[1] round_direction offset_axis_value:offset_axis_value
        operation_text = if round_direction == #up then "rounded UP" else "rounded DOWN"

        this.moveGroupToAxisValue group_index target_axis_value operation_text
        -- return
    ),

    /*
    Rounds one exact child level to the 5 mm grid by moving only that level's vertices.
    Sibling levels in the same group are not changed.
    */
    function roundLevelToFiveMillimeters group_index level_index round_direction offset_axis_value:0.0 =
    (
        level_data = this.getLevelData group_index level_index
        if level_data == undefined then return false

        target_axis_value = this.roundAxisValueToFiveMillimeters level_data[1] round_direction offset_axis_value:offset_axis_value
        operation_text = if round_direction == #up then "rounded UP" else "rounded DOWN"

        this.moveLevelToAxisValue group_index level_index target_axis_value operation_text
        -- return
    ),

    /*
    Sets every supplied Editable Poly vertex to one exact world-axis coordinate.
    The other two world coordinates are preserved and converted back through the node transform.
    */
    function setEditablePolyVertexBitsToWorldAxisValue vertex_bits target_axis_value =
    (
        if vertex_bits == undefined or vertex_bits.numberSet == 0 then return false
        if scan_node == undefined or not(isValidNode scan_node) then return false
        if classOf scan_node.baseObject != Editable_Poly then return false

        topology_value = scan_node.baseObject
        inverse_transform = inverse scan_node.objectTransform
        axis_to_use = this.normalizeWorldAxis world_axis
        target_positions = #()

        for vertex_id in vertex_bits do
        (
            local_position = polyop.getVert topology_value vertex_id
            world_position = local_position * scan_node.objectTransform

            case axis_to_use of
            (
                #x: world_position.x = target_axis_value
                #y: world_position.y = target_axis_value
                default: world_position.z = target_axis_value
            )

            append target_positions (world_position * inverse_transform)
        )

        polyop.setVert topology_value vertex_bits target_positions
        update scan_node
        true
        -- return
    ),

    /*
    Forces Edit Poly vertices to one exact world-axis coordinate using the stable MoveSelection path.
    Each stored exact level moves as one selection; a per-vertex correction pass removes any residual mismatch.
    */
    function setEditPolyVertexBitsToWorldAxisValue vertex_bits exact_levels target_axis_value =
    (
        if vertex_bits == undefined or vertex_bits.numberSet == 0 then return false
        if exact_levels == undefined or exact_levels.count == 0 then return false
        if scan_node == undefined or not(isValidNode scan_node) then return false
        if not(this.modifierBelongsToNode scan_node scan_modifier) then return false

        for level_data in exact_levels do
        (
            level_axis_value = level_data[1]
            level_bits = level_data[2]
            delta_world_value = target_axis_value - level_axis_value

            if abs(delta_world_value) > exact_epsilon then
            (
                if not(this.moveEditPolyVertexBitsByWorldAxisDelta level_bits delta_world_value) then return false
            )
        )

        context_data = this.resolveContext scan_node modifier_value:scan_modifier

        for vertex_id in vertex_bits do
        (
            world_position = this.getWorldVertexPosition context_data vertex_id
            if world_position == undefined then return false

            current_axis_value = this.getWorldAxisValue world_position
            correction_delta = target_axis_value - current_axis_value

            if abs(correction_delta) > exact_epsilon then
            (
                correction_bits = #{}
                correction_bits[vertex_id] = true
                if not(this.moveEditPolyVertexBitsByWorldAxisDelta correction_bits correction_delta) then return false
            )
        )

        true
        -- return
    ),

    /*
    Returns true only when every supplied vertex is at the requested world-axis coordinate.
    This verifies the real live geometry rather than trusting stored TreeView data.
    */
    function verifyVertexBitsAtWorldAxisValue vertex_bits target_axis_value =
    (
        if vertex_bits == undefined or vertex_bits.numberSet == 0 then return false
        if scan_node == undefined or not(isValidNode scan_node) then return false

        context_data = this.resolveContext scan_node modifier_value:scan_modifier
        verification_tolerance = exact_epsilon * 10.0

        for vertex_id in vertex_bits do
        (
            world_position = this.getWorldVertexPosition context_data vertex_id
            if world_position == undefined then return false

            current_axis_value = this.getWorldAxisValue world_position
            if abs(current_axis_value - target_axis_value) > verification_tolerance then return false
        )

        true
        -- return
    ),

    /*
    Flattens one complete threshold group to a single exact world-axis coordinate.
    The operation writes real vertex positions, rescans the live mesh, and requires the resulting group to be unbroken.
    */
    function flattenGroupToAxisValue group_index target_axis_value alignment_mode:#here =
    (
        group_data = this.getGroupData group_index
        if group_data == undefined or target_axis_value == undefined then return false
        if not(this.isStoredContextCurrent()) then
        (
            last_message = "Topology changed. Scan the object again."
            return false
        )

        group_bits = group_data[4]
        exact_levels = group_data[5]
        target_node = scan_node
        target_modifier = scan_modifier
        target_threshold = threshold_value
        target_world_axis = world_axis
        flatten_ok = false

        if scan_kind == #editable_poly then
        (
            flatten_ok = this.setEditablePolyVertexBitsToWorldAxisValue group_bits target_axis_value
        )
        else if scan_kind == #edit_poly then
        (
            flatten_ok = this.setEditPolyVertexBitsToWorldAxisValue group_bits exact_levels target_axis_value
        )

        if not(flatten_ok) then
        (
            last_message = "Could not set the group vertices to one axis position."
            return false
        )

        completeRedraw()

        if not(this.verifyVertexBitsAtWorldAxisValue group_bits target_axis_value) then
        (
            last_message = "Alignment failed verification: group vertices are not at one axis position."
            return false
        )

        if not(this.scanNode target_node modifier_value:target_modifier threshold:target_threshold world_axis_value:target_world_axis) then return false

        aligned_group_index = 0

        for current_group_index = 1 to level_groups.count do
        (
            current_group_data = level_groups[current_group_index]
            matching_bits = current_group_data[4] * group_bits

            if matching_bits.numberSet == group_bits.numberSet then
            (
                aligned_group_index = current_group_index
            )
        )

        if aligned_group_index == 0 then
        (
            last_message = "Aligned vertices could not be resolved after rescan."
            return false
        )

        aligned_group_data = level_groups[aligned_group_index]
        if aligned_group_data[6] or aligned_group_data[5].count != 1 then
        (
            last_message = "Alignment did not merge the group into one exact level."
            return false
        )

        scan_message = last_message
        this.selectVertexBits group_bits
        last_message = (group_bits.numberSet as string) + " vertices aligned " + (this.getAlignmentModeText alignment_mode) + " to one world " + (this.getWorldAxisText()) + " position | group unbroken | " + scan_message
        true
        -- return
    ),

    /*
    Aligns one or more stored exact levels to one target on the selected world axis and refreshes the stored scan.
    */
    function alignExactLevels exact_levels target_axis_value alignment_mode =
    (
        if exact_levels == undefined or exact_levels.count == 0 then return false
        if target_axis_value == undefined then return false
        if not(this.isStoredContextCurrent()) then
        (
            last_message = "Topology changed. Scan the object again."
            return false
        )

        aligned_bits = #{}
        target_node = scan_node
        target_modifier = scan_modifier
        target_threshold = threshold_value
        target_world_axis = world_axis

        for level_data in exact_levels do
        (
            level_axis_value = level_data[1]
            level_bits = level_data[2]
            delta_world_value = target_axis_value - level_axis_value

            if not(this.moveVertexBitsByWorldAxisDelta level_bits delta_world_value) then
            (
                last_message = "Could not align the selected level."
                return false
            )

            for vertex_id in level_bits do
            (
                aligned_bits[vertex_id] = true
            )
        )

        completeRedraw()

        if not(this.scanNode target_node modifier_value:target_modifier threshold:target_threshold world_axis_value:target_world_axis) then
        (
            return false
        )

        scan_message = last_message
        this.selectVertexBits aligned_bits
        last_message = (aligned_bits.numberSet as string) + " vertices aligned " + (this.getAlignmentModeText alignment_mode) + " on world " + (this.getWorldAxisText()) + " | " + scan_message
        true
        -- return
    ),

    /*
    Aligns each requested group to its own unique exact level containing the most vertices.
    Groups whose maximum vertex count is tied across multiple exact levels are skipped unchanged.
    All jobs are snapshotted before movement and the object is rescanned only once at the end.
    */
    function alignGroupsToMost group_indices =
    (
        if group_indices == undefined or group_indices.count == 0 then
        (
            last_message = "No groups selected for Align MOST."
            return false
        )

        if not(this.isStoredContextCurrent()) then
        (
            last_message = "Topology changed. Scan the object again."
            return false
        )

        unique_group_indices = #()
        alignment_jobs = #()
        skipped_tie_count = 0

        for group_index in group_indices do
        (
            if group_index > 0 and (findItem unique_group_indices group_index) == 0 then
            (
                append unique_group_indices group_index
                group_data = this.getGroupData group_index

                if group_data != undefined then
                (
                    exact_levels = group_data[5]

                    if isKindOf exact_levels Array and exact_levels.count > 0 then
                    (
                        largest_vertex_count = -1
                        largest_match_count = 0
                        target_axis_value = undefined

                        for level_data in exact_levels do
                        (
                            level_vertex_count = level_data[2].numberSet

                            if level_vertex_count > largest_vertex_count then
                            (
                                largest_vertex_count = level_vertex_count
                                largest_match_count = 1
                                target_axis_value = level_data[1]
                            )
                            else if level_vertex_count == largest_vertex_count then
                            (
                                largest_match_count += 1
                            )
                        )

                        if largest_match_count == 1 then
                        (
                            append alignment_jobs #(exact_levels, target_axis_value)
                        )
                        else
                        (
                            skipped_tie_count += 1
                        )
                    )
                )
            )
        )

        if alignment_jobs.count == 0 then
        (
            last_message = if skipped_tie_count > 0 then
            (
                (skipped_tie_count as string) + " selected group(s) skipped because MOST is tied."
            )
            else
            (
                "No valid groups selected for Align MOST."
            )

            return false
        )

        target_node = scan_node
        target_modifier = scan_modifier
        target_threshold = threshold_value
        target_world_axis = world_axis
        aligned_bits = #{}

        for alignment_job in alignment_jobs do
        (
            job_levels = alignment_job[1]
            job_target_axis_value = alignment_job[2]

            for level_data in job_levels do
            (
                level_axis_value = level_data[1]
                level_bits = level_data[2]
                delta_world_value = job_target_axis_value - level_axis_value

                if not(this.moveVertexBitsByWorldAxisDelta level_bits delta_world_value) then
                (
                    last_message = "Could not align one selected group to MOST."
                    return false
                )

                for vertex_id in level_bits do aligned_bits[vertex_id] = true
            )
        )

        completeRedraw()

        if not(this.scanNode target_node modifier_value:target_modifier threshold:target_threshold world_axis_value:target_world_axis) then
        (
            return false
        )

        scan_message = last_message

        last_message = (alignment_jobs.count as string) + " group(s) aligned MOST"
        if skipped_tie_count > 0 then
        (
            last_message += " | " + (skipped_tie_count as string) + " skipped because MOST is tied"
        )
        last_message += " | " + scan_message

        true
        -- return
    ),

    /*
    Aligns every exact level in one threshold group to one explicit target on the selected world axis.
    This is used by the contextual Align-to-position action so the clicked row supplies the target while the whole group moves.
    */
    function alignGroupToAxisValue group_index target_axis_value alignment_mode:#here =
    (
        this.flattenGroupToAxisValue group_index target_axis_value alignment_mode:alignment_mode
        -- return
    ),

    /*
    Compatibility alias for older callers; the scalar target follows the currently selected world axis.
    */
    function alignGroupToZ group_index target_z alignment_mode:#here =
    (
        this.alignGroupToAxisValue group_index target_z alignment_mode:alignment_mode
        -- return
    ),

    /*
    Aligns every exact level in one threshold group to UP, MIDDLE, or DOWN.
    */
    function alignGroup group_index alignment_mode =
    (
        group_data = this.getGroupData group_index
        if group_data == undefined then return false

        target_axis_value = this.getAlignmentTargetAxisValue group_data alignment_mode
        this.flattenGroupToAxisValue group_index target_axis_value alignment_mode:alignment_mode
        -- return
    ),

    /*
    Aligns one exact child level to the parent group's UP, MIDDLE, or DOWN target.
    */
    function alignLevel group_index level_index alignment_mode =
    (
        group_data = this.getGroupData group_index
        if group_data == undefined then return false

        level_data = this.getLevelData group_index level_index
        if level_data == undefined then return false

        target_axis_value = this.getAlignmentTargetAxisValue group_data alignment_mode
        this.alignExactLevels #(level_data) target_axis_value alignment_mode
        -- return
    ),

    /*
    Selects the union of multiple TreeView group/level targets in the user's current component mode.
    Group targets contribute every exact level in that group; level targets contribute only that exact level.
    */
    function selectTargets target_data_array =
    (
        if target_data_array == undefined then return false
        if not(this.isStoredContextCurrent()) then
        (
            last_message = "Topology changed. Scan the object again."
            return false
        )

        current_subobject_level = try(subObjectLevel)catch(1)
        if current_subobject_level != 2 then current_subobject_level = 1
        combined_vertex_bits = #{}
        combined_edge_bits = #{}

        for target_data in target_data_array do
        (
            if isKindOf target_data Array and target_data.count >= 2 then
            (
                if target_data[1] == #group then
                (
                    group_data = this.getGroupData target_data[2]

                    if group_data != undefined then
                    (
                        for vertex_id in group_data[4] do combined_vertex_bits[vertex_id] = true

                        if current_subobject_level == 2 then
                        (
                            exact_levels = group_data[5]

                            for level_data in exact_levels do
                            (
                                level_edges = this.getEdgesBetweenVertexBits level_data[2]
                                for edge_id in level_edges do combined_edge_bits[edge_id] = true
                            )
                        )
                    )
                )
                else if target_data[1] == #level and target_data.count >= 3 then
                (
                    level_data = this.getLevelData target_data[2] target_data[3]

                    if level_data != undefined then
                    (
                        for vertex_id in level_data[2] do combined_vertex_bits[vertex_id] = true

                        if current_subobject_level == 2 then
                        (
                            level_edges = this.getEdgesBetweenVertexBits level_data[2]
                            for edge_id in level_edges do combined_edge_bits[edge_id] = true
                        )
                    )
                )
            )
        )

        if combined_vertex_bits.numberSet > 0 then
        (
            if not(this.unhideVertexBits combined_vertex_bits) then return false
        )

        if current_subobject_level == 2 then
        (
            return this.selectEdgeBits combined_edge_bits
        )

        this.selectVertexBits combined_vertex_bits
        -- return
    ),

    /*
    Selects one threshold group in the user's current component mode.
    At Edge level, only edges whose two endpoints belong to the same exact selected-axis level are selected,
    so cross-level vertical edges inside a broken group are excluded.
    */
    function selectGroup group_index =
    (
        group_data = this.getGroupData group_index
        if group_data == undefined then return false

        current_subobject_level = try(subObjectLevel)catch(1)

        if not(this.unhideVertexBits group_data[4]) then return false

        if current_subobject_level == 2 then
        (
            group_edges = #{}
            exact_levels = group_data[5]

            for level_data in exact_levels do
            (
                level_edges = this.getEdgesBetweenVertexBits level_data[2]

                for edge_id in level_edges do
                (
                    group_edges[edge_id] = true
                )
            )

            return this.selectEdgeBits group_edges
        )

        this.selectVertexBits group_data[4]
        -- return
    ),

    /*
    Selects one exact selected-axis level in the user's current component mode.
    At Edge level, only edges connecting two vertices of this exact level are selected.
    */
    function selectLevel group_index level_index =
    (
        level_data = this.getLevelData group_index level_index
        if level_data == undefined then return false

        current_subobject_level = try(subObjectLevel)catch(1)

        if not(this.unhideVertexBits level_data[2]) then return false

        if current_subobject_level == 2 then
        (
            level_edges = this.getEdgesBetweenVertexBits level_data[2]
            return this.selectEdgeBits level_edges
        )

        this.selectVertexBits level_data[2]
        -- return
    ),

    on create do
    (
    )
)

vertex_level_aligner = vertex_level_aligner_v()
vertexLevelAlignerWriteLog "010 BACKEND API struct instance created"

vertexLevelAlignerWriteLog "010 FN API struct instance created"
