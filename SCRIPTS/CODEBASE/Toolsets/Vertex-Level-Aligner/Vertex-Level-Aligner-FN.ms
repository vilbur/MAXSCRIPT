/*
Vertex Level Aligner FN 0.143
Backend-only functional module. Scans Editable Poly / Edit Poly vertex levels on a selected world X/Y/Z axis, groups nearby exact levels by threshold, and exposes selection data to the frontend.
*/

global vertex_level_aligner
global EPOLY_TOOLS_RUNTIME_MODE
global vertex_level_aligner_log_path
global vertexLevelAlignerWriteLog
global vertexLevelAlignerStartLog
global vertex_level_aligner_default_threshold
global VertexColorPainter_v

vertex_level_aligner_default_threshold = 0.0

/*
Writes one crash-trace marker and closes the file immediately so the last completed stage survives a hard 3ds Max crash.
*/
function vertexLevelAlignerWriteLog message_text =
(
    if vertex_level_aligner_log_path == undefined or vertex_level_aligner_log_path == "" then return false

    log_ok = true
    log_stream = undefined

    try
    (
        log_stream = openFile vertex_level_aligner_log_path mode:"a"
        if log_stream == undefined then throw "Could not open Vertex Level Aligner log."

        format "%\n" message_text to:log_stream
        close log_stream
        log_stream = undefined
    )
    catch
    (
        log_exception = getCurrentException()
        log_ok = false

        if log_stream != undefined then
        (
            try
            (
                close log_stream
            )
            catch
            (
                close_exception = getCurrentException()
            )
        )
    )

    log_ok
    -- return
)

/*
Creates a fresh crash log next to the canonical script for each direct backend execution.
*/
function vertexLevelAlignerStartLog source_file =
(
    if source_file == undefined or source_file == "" then return false

    log_stream = undefined
    start_ok = true

    try
    (
        vertex_level_aligner_log_path = getFilenamePath source_file + "Vertex-Level-Aligner-crash.log"
        log_stream = createFile vertex_level_aligner_log_path
        if log_stream == undefined then throw "Could not create Vertex Level Aligner log."

        format "000 START Vertex Level Aligner project 1.123\n" to:log_stream
        close log_stream
        log_stream = undefined
    )
    catch
    (
        start_log_exception = getCurrentException()
        start_ok = false

        if log_stream != undefined then
        (
            try
            (
                close log_stream
            )
            catch
            (
                start_log_close_exception = getCurrentException()
            )
        )

        vertex_level_aligner_log_path = undefined
    )

    start_ok
    -- return
)

struct vertex_level_aligner_v
(
    file_version = 0.143,
    project_version = 1.123,
    scan_node = undefined,
    scan_modifier = undefined,
    scan_kind = #none,
    scan_vertex_count = 0,
    scan_topology_signature = #(),
    topology_compaction_serial = 0,
    threshold_value = vertex_level_aligner_default_threshold,
    world_axis = #z,
    exact_epsilon = 0.000001,
    level_groups = #(),
    diagnostic_painter = undefined,
    diagnostic_broken_color = (color 255 0 0),
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
    Resolves the exact stack index consumed by Vertex Color Painter for the stored scan topology.
    Editable Poly base returns 0; the exact stored Edit Poly modifier returns its current positive stack index.
    */
    function getDiagnosticPainterStackIndex =
    (
        if scan_node == undefined or not(isValidNode scan_node) then
        (
            vertexLevelAlignerWriteLog "DIAGNOSTIC PAINT STACK ERROR: scanned node is invalid."
            return -1
        )

        if scan_kind == #editable_poly then return 0

        if scan_kind == #edit_poly then
        (
            if scan_modifier == undefined or not(this.modifierBelongsToNode scan_node scan_modifier) then
            (
                vertexLevelAlignerWriteLog "DIAGNOSTIC PAINT STACK ERROR: stored Edit Poly modifier is missing from the scanned node."
                return -1
            )

            for stack_index = 1 to scan_node.modifiers.count do
            (
                if scan_node.modifiers[stack_index] == scan_modifier then return stack_index
            )

            vertexLevelAlignerWriteLog "DIAGNOSTIC PAINT STACK ERROR: could not resolve stored Edit Poly stack index."
            return -1
        )

        vertexLevelAlignerWriteLog ("DIAGNOSTIC PAINT STACK ERROR: unsupported scan kind " + (scan_kind as string))
        -1
        -- return
    ),

    /*
    Disables one cage state as best-effort UI cleanup.
    Cage-state failure is non-critical and never changes geometry success.
    */
    function disableCageBestEffort topology_value =
    (
        if topology_value == undefined then return false

        cage_ok = true

        try
        (
            topology_value.showCage = off
        )
        catch
        (
            cage_exception = getCurrentException()
            cage_ok = false
        )

        cage_ok
        -- return
    ),

    /*
    Returns true when two BitArrays contain exactly the same set bits.
    The comparison avoids relying on reference identity or selection-writer return values.
    */
    function bitArraysEqual bit_array_a bit_array_b =
    (
        if bit_array_a == undefined or bit_array_b == undefined then return false
        if bit_array_a.numberSet != bit_array_b.numberSet then return false

        for bit_index in bit_array_a do
        (
            if not(bit_array_b[bit_index]) then return false
        )

        true
        -- return
    ),

    /*
    Invalidates every stored topology-derived cache after Editable Poly index compaction.
    Node/modifier identity is cleared so no stale vertex, edge, face, BitArray, or signature data can be reused.
    */
    function invalidateStoredTopologyCache =
    (
        scan_node = undefined
        scan_modifier = undefined
        scan_kind = #none
        scan_vertex_count = 0
        scan_topology_signature = #()
        level_groups = #()

        true
        -- return
    ),

    /*
    Synchronizes one Editable Poly topology before an index-sensitive phase.
    Edit Poly contexts are never collapsed; #collapsed means every pre-existing component ID must be discarded.
    */
    function synchronizeEditablePolyTopology context_data =
    (
        if context_data == undefined or context_data.count < 3 then return #failed

        context_kind = context_data[1]
        node_value = context_data[2]
        topology_value = context_data[3]

        if context_kind != #editable_poly then return #not_applicable
        if node_value == undefined or not(isValidNode node_value) then return #failed
        if topology_value == undefined or classOf topology_value != Editable_Poly then return #failed

        has_edit_poly_mod = false

        for stack_index = 1 to node_value.modifiers.count do
        (
            if classOf node_value.modifiers[stack_index] == Edit_Poly then
            (
                has_edit_poly_mod = true
            )
        )

        if has_edit_poly_mod then
        (
            vertexLevelAlignerWriteLog "DEAD TOPOLOGY SYNC blocked: Edit Poly modifier exists above the base Editable Poly."
            return #failed
        )

        dead_struct_flags = -1
        collapse_attempted = false
        collapse_completed = false
        sync_ok = true

        try
        (
            dead_struct_flags = polyop.getHasDeadStructs topology_value

            if dead_struct_flags != 0 then
            (
                collapse_attempted = true
                polyop.collapseDeadStructs topology_value

                if polyop.getHasDeadStructs topology_value != 0 then
                (
                    throw "Editable Poly dead topology remained after collapseDeadStructs."
                )

                collapse_completed = true
            )
        )
        catch
        (
            dead_topology_exception = getCurrentException()
            vertexLevelAlignerWriteLog ("DEAD TOPOLOGY SYNC ERROR: " + (dead_topology_exception as string))
            sync_ok = false
        )

        if collapse_attempted then
        (
            topology_compaction_serial += 1
            this.invalidateStoredTopologyCache()
        )

        if not(sync_ok) then return #failed
        if collapse_attempted and not(collapse_completed) then return #failed

        if collapse_completed then
        (
            update_ok = true

            try
            (
                update node_value
            )
            catch
            (
                dead_topology_update_exception = getCurrentException()
                vertexLevelAlignerWriteLog ("DEAD TOPOLOGY UPDATE ERROR: " + (dead_topology_update_exception as string))
                update_ok = false
            )

            if not(update_ok) then return #failed
            return #collapsed
        )

        #clean
        -- return
    ),

    /*
    Reads the current sub-object level without converting an API exception into Vertex mode.
    A legitimate undefined level still normalizes to Vertex mode for the existing UI contract.
    */
    function getCurrentSubObjectLevelSafe =
    (
        current_level = undefined
        read_ok = true

        try
        (
            current_level = subObjectLevel
        )
        catch
        (
            level_exception = getCurrentException()
            read_ok = false
        )

        if not(read_ok) then return undefined
        if current_level == undefined then return 1

        current_level
        -- return
    ),


    /*
    Returns the currently active Edit Poly modifier when it belongs to the node.
    Otherwise the first Edit Poly modifier in the stack is returned.
    */
    function getEditPolyModifier node_value =
    (
        if node_value == undefined or not(isValidNode node_value) then return undefined

        current_object = undefined

        try
        (
            current_object = modPanel.getCurrentObject()
        )
        catch
        (
            current_object_exception = getCurrentException()
        )

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
            this.disableCageBestEffort edit_modifier
            return #(#edit_poly, node_value, edit_modifier)
        )

        if classOf node_value.baseObject == Editable_Poly then
        (
            this.disableCageBestEffort node_value.baseObject
            return #(#editable_poly, node_value, node_value.baseObject)
        )

        #(#none, node_value, undefined)
        -- return
    ),

    /*
    Returns the live vertex count for one resolved Editable Poly or Edit Poly context.
    Unsupported contexts and failed native reads return the Integer failure sentinel -1.
    */
    function getContextVertexCount context_data topology_validated:false =
    (
        if context_data == undefined or context_data.count < 3 then return -1

        context_kind = context_data[1]
        node_value = context_data[2]
        topology_value = context_data[3]
        vertex_count = -1

        if context_kind == #editable_poly and not(topology_validated) then
        (
            topology_sync_state = this.synchronizeEditablePolyTopology context_data
            if topology_sync_state == #failed then return -1
        )

        try
        (
            if context_kind == #editable_poly then
            (
                vertex_count = polyop.getNumVerts topology_value
            )
            else if context_kind == #edit_poly then
            (
                vertex_count = EditPolyMod.GetNumVertices topology_value node:node_value
            )
        )
        catch
        (
            vertex_count_exception = getCurrentException()
            vertexLevelAlignerWriteLog ("VERTEX COUNT ERROR: " + (vertex_count_exception as string))
            vertex_count = -1
        )

        vertex_count
        -- return
    ),

    /*
    Reads one live vertex position from the resolved target in world space.
    Editable Poly uses PolyOp's native world-coordinate node context so X/Y/Z share the same coordinate path.
    */
    function getWorldVertexPosition context_data vertex_id topology_validated:false =
    (
        if context_data == undefined or context_data.count < 3 then return undefined
        if vertex_id == undefined or vertex_id < 1 then return undefined

        context_kind = context_data[1]
        node_value = context_data[2]
        topology_value = context_data[3]

        if context_kind == #editable_poly then
        (
            if not(topology_validated) then
            (
                topology_sync_state = this.synchronizeEditablePolyTopology context_data

                if topology_sync_state == #failed then return undefined
                if topology_sync_state == #collapsed then return undefined
            )

            is_dead = polyop.isVertDead topology_value vertex_id
            if is_dead then return undefined

            world_position = undefined

            in coordsys world
            (
                world_position = polyop.getVert topology_value vertex_id node:node_value
            )

            return world_position
        )

        if context_kind == #edit_poly then
        (
            vertex_position = EditPolyMod.GetVertex topology_value vertex_id node:node_value
            if vertex_position == undefined then return undefined
            return (vertex_position * node_value.objectTransform)
        )

        undefined
        -- return
    ),

    /*
    Builds a topology-only face/vertex signature for the resolved context.
    Native read failure returns undefined so same-count topology changes cannot masquerade as current data.
    */
    function getContextTopologySignature context_data topology_validated:false =
    (
        if context_data == undefined or context_data.count < 3 then return undefined

        context_kind = context_data[1]
        node_value = context_data[2]
        topology_value = context_data[3]
        signature_values = #()
        signature_ok = true

        if context_kind == #editable_poly and not(topology_validated) then
        (
            topology_sync_state = this.synchronizeEditablePolyTopology context_data
            if topology_sync_state == #failed then return undefined
        )

        try
        (
            if context_kind == #editable_poly then
            (
                face_count = polyop.getNumFaces topology_value

                for face_id = 1 to face_count do
                (
                    face_vertices = polyop.getFaceVerts topology_value face_id
                    face_signature = #()

                    for vertex_id in face_vertices do
                    (
                        append face_signature vertex_id
                    )

                    append signature_values face_signature
                )
            )
            else if context_kind == #edit_poly then
            (
                face_count = topology_value.GetNumFaces node:node_value

                for face_id = 1 to face_count do
                (
                    face_degree = topology_value.GetFaceDegree face_id node:node_value
                    if face_degree < 0 then throw "Invalid Edit Poly face degree."

                    face_signature = #()

                    for corner_id = 1 to face_degree do
                    (
                        vertex_id = topology_value.GetFaceVertex face_id corner_id node:node_value
                        if vertex_id <= 0 then throw "Invalid Edit Poly face vertex."
                        append face_signature vertex_id
                    )

                    append signature_values face_signature
                )
            )
            else
            (
                signature_ok = false
            )
        )
        catch
        (
            topology_signature_exception = getCurrentException()
            vertexLevelAlignerWriteLog ("TOPOLOGY SIGNATURE ERROR: " + (topology_signature_exception as string))
            signature_ok = false
        )

        if not(signature_ok) then return undefined

        signature_values
        -- return
    ),

    /*
    Compares two face/vertex topology signatures exactly.
    Vertex movement does not affect this signature, while same-count topology mutation does.
    */
    function topologySignaturesEqual signature_a signature_b =
    (
        if signature_a == undefined or signature_b == undefined then return false
        if signature_a.count != signature_b.count then return false

        for face_index = 1 to signature_a.count do
        (
            face_a = signature_a[face_index]
            face_b = signature_b[face_index]

            if face_a == undefined or face_b == undefined then return false
            if face_a.count != face_b.count then return false

            for corner_index = 1 to face_a.count do
            (
                if face_a[corner_index] != face_b[corner_index] then return false
            )
        )

        true
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
    Returns a few single-precision ULPs for two world-axis values.
    This tolerance is reserved for post-write/movement verification and must not merge distinct scanned exact levels.
    */
    function getAxisPrecisionTolerance axis_value_a axis_value_b =
    (
        maximum_magnitude = abs axis_value_a
        second_magnitude = abs axis_value_b

        if second_magnitude > maximum_magnitude then maximum_magnitude = second_magnitude
        if maximum_magnitude < 1.0 then maximum_magnitude = 1.0

        exponent_value = floor ((log maximum_magnitude) / (log 2.0))
        float_ulp = 2.0 ^ (exponent_value - 23.0)
        float_ulp * 4.0
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
    function collectVertexSamples context_data topology_validated:false =
    (
        sample_values = #()

        if context_data == undefined or context_data.count < 3 then
        (
            throw "Could not resolve topology context."
        )

        context_kind = context_data[1]

        if context_kind == #editable_poly and not(topology_validated) then
        (
            topology_sync_state = this.synchronizeEditablePolyTopology context_data
            if topology_sync_state == #failed then throw "Could not synchronize Editable Poly topology."
        )

        vertex_count = this.getContextVertexCount context_data topology_validated:true

        if vertex_count < 0 then
        (
            throw "Could not read live vertex count."
        )

        for vertex_id = 1 to vertex_count do
        (
            world_position = this.getWorldVertexPosition context_data vertex_id topology_validated:true

            if world_position == undefined then
            (
                throw ("Could not read live vertex " + (vertex_id as string) + " after topology synchronization.")
            )

            axis_position = this.getWorldAxisValue world_position
            append sample_values #(axis_position, vertex_id)
        )

        qsort sample_values this.compareVertexSamples
        sample_values
        -- return
    ),

    /*
    Returns one selected-axis coordinate rounded to the decimal precision used by 3ds Max value spinners.
    The precision source is preferences.spinnerPrecision only; Spinner Snap is intentionally ignored.
    */
    function getAxisValueAtSpinnerPrecision axis_value spinner_precision =
    (
        precision_scale = 10.0d0 ^ spinner_precision
        scaled_axis_value = (axis_value as Double) * precision_scale

        rounded_scaled_axis_value = if scaled_axis_value >= 0.0d0 then
        (
            floor (scaled_axis_value + 0.5d0)
        )
        else
        (
            ceil (scaled_axis_value - 0.5d0)
        )

        rounded_scaled_axis_value / precision_scale
        -- return
    ),

    /*
    Collapses selected-axis samples by the active 3ds Max spinner decimal precision.
    Samples that round to the same coordinate become one level and that rounded coordinate is stored as the level's common axis value.
    */
    function buildSpinnerPrecisionLevels sample_values spinner_precision =
    (
        exact_levels = #()
        current_level = undefined

        for sample_value in sample_values do
        (
            sample_axis_value = this.getAxisValueAtSpinnerPrecision sample_value[1] spinner_precision
            vertex_id = sample_value[2]

            if current_level == undefined then
            (
                current_bits = #{}
                current_bits[vertex_id] = true
                current_level = #(sample_axis_value, current_bits)
                append exact_levels current_level
            )
            else if sample_axis_value == current_level[1] then
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

        exact_levels
        -- return
    ),

    /*
    Compatibility helper retained for direct callers that explicitly supply an exact-level tolerance.
    Production scanning uses buildSpinnerPrecisionLevels() instead.
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

        if diagnostic_painter != undefined then
        (
            if not(this.clearDiagnosticPaint update_message:false) then
            (
                last_message = "Could not clear existing diagnostic paint before scan."
                return false
            )
        )

        context_data = this.resolveContext node_value modifier_value:modifier_value
        context_kind = context_data[1]

        if context_kind == #none then
        (
            scan_node = undefined
            scan_modifier = undefined
            scan_kind = #none
            scan_vertex_count = 0
            scan_topology_signature = #()
            level_groups = #()
            last_message = "Select one Editable Poly or Edit Poly object."
            return false
        )

        if context_kind == #editable_poly then
        (
            topology_sync_state = this.synchronizeEditablePolyTopology context_data

            if topology_sync_state == #failed then
            (
                this.invalidateStoredTopologyCache()
                last_message = "Could not synchronize Editable Poly topology. Scan aborted."
                return false
            )
        )

        threshold_to_store = threshold
        if threshold_to_store < 0.0 then threshold_to_store = 0.0

        read_ok = true
        sample_values = #()
        new_vertex_count = -1
        new_topology_signature = undefined

        try
        (
            new_vertex_count = this.getContextVertexCount context_data topology_validated:true
            if new_vertex_count < 0 then throw "Could not read live vertex count."

            new_topology_signature = this.getContextTopologySignature context_data topology_validated:true
            if new_topology_signature == undefined then throw "Could not read live topology signature."

            sample_values = this.collectVertexSamples context_data topology_validated:true
        )
        catch
        (
            scan_exception = getCurrentException()
            read_ok = false
        )

        if not(read_ok) then
        (
            scan_node = undefined
            scan_modifier = undefined
            scan_kind = #none
            scan_vertex_count = 0
            scan_topology_signature = #()
            level_groups = #()
            last_message = "Could not read live topology. Scan aborted."
            return false
        )

        working_spinner_precision = preferences.spinnerPrecision
        exact_levels = this.buildSpinnerPrecisionLevels sample_values working_spinner_precision
        new_level_groups = this.buildThresholdGroups exact_levels threshold:threshold_to_store

        threshold_value = threshold_to_store
        level_groups = new_level_groups
        scan_node = context_data[2]
        scan_kind = context_kind
        scan_modifier = if context_kind == #edit_poly then context_data[3] else undefined
        scan_vertex_count = new_vertex_count
        scan_topology_signature = new_topology_signature

        broken_count = this.getBrokenGroupCount context_validated:true
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
    Returns the number of stored threshold groups after validating cached component IDs.
    Pass context_validated:true only inside a phase that already called isStoredContextCurrent().
    */
    function getGroupCount context_validated:false =
    (
        if not(context_validated) then
        (
            if scan_node == undefined or scan_kind == #none then return 0
            if not(this.isStoredContextCurrent()) then
            (
                last_message = "Topology changed. Scan the object again."
                return 0
            )
        )

        level_groups.count
        -- return
    ),

    /*
    Returns the number of stored broken groups after validating cached component IDs.
    Pass context_validated:true only inside a phase that already called isStoredContextCurrent().
    */
    function getBrokenGroupCount context_validated:false =
    (
        if not(context_validated) then
        (
            if scan_node == undefined or scan_kind == #none then return 0
            if not(this.isStoredContextCurrent()) then
            (
                last_message = "Topology changed. Scan the object again."
                return 0
            )
        )

        broken_count = 0

        for group_data in level_groups do
        (
            if group_data[6] then broken_count += 1
        )

        broken_count
        -- return
    ),

    /*
    Returns one stored group only after validating that its cached topology IDs are current.
    Invalid or stale indexes return undefined.
    */
    function getGroupData group_index context_validated:false =
    (
        if not(context_validated) then
        (
            if scan_node == undefined or scan_kind == #none then return undefined
            if not(this.isStoredContextCurrent()) then
            (
                last_message = "Topology changed. Scan the object again."
                return undefined
            )
        )

        if group_index < 1 or group_index > level_groups.count then return undefined

        level_groups[group_index]
        -- return
    ),

    /*
    Returns one stored exact level only after validating that its cached topology IDs are current.
    Invalid or stale group/level indexes return undefined.
    */
    function getLevelData group_index level_index context_validated:false =
    (
        if not(context_validated) then
        (
            if scan_node == undefined or scan_kind == #none then return undefined
            if not(this.isStoredContextCurrent()) then
            (
                last_message = "Topology changed. Scan the object again."
                return undefined
            )
        )

        group_data = this.getGroupData group_index context_validated:true
        if group_data == undefined then return undefined

        exact_levels = group_data[5]
        if level_index < 1 or level_index > exact_levels.count then return undefined

        exact_levels[level_index]
        -- return
    ),

    /*
    Collects the scanned vertex IDs represented by one or more TreeView group/level targets.
    Invalid target entries are ignored; native/stored-context failure returns undefined.
    */
    function getTargetVertexBits target_data_array =
    (
        if target_data_array == undefined then return undefined
        if not(isKindOf target_data_array Array) then return undefined
        if not(this.isStoredContextCurrent()) then
        (
            last_message = "Topology changed. Scan the object again."
            return undefined
        )

        combined_vertex_bits = #{}

        for target_data in target_data_array do
        (
            if isKindOf target_data Array and target_data.count >= 2 then
            (
                if target_data[1] == #group then
                (
                    group_data = this.getGroupData target_data[2] context_validated:true

                    if group_data != undefined then
                    (
                        for vertex_id in group_data[4] do
                        (
                            combined_vertex_bits[vertex_id] = true
                        )
                    )
                )
                else if target_data[1] == #level and target_data.count >= 3 then
                (
                    level_data = this.getLevelData target_data[2] target_data[3] context_validated:true

                    if level_data != undefined then
                    (
                        for vertex_id in level_data[2] do
                        (
                            combined_vertex_bits[vertex_id] = true
                        )
                    )
                )
            )
        )

        combined_vertex_bits
        -- return
    ),

    /*
    Returns only faces whose every vertex belongs to the supplied selected-vertex BitArray.
    Legitimate no-result returns an empty BitArray; native topology-read failure returns undefined.
    */
    function getFullySelectedFacesFromVertexBits vertex_bits =
    (
        if vertex_bits == undefined then return undefined
        if vertex_bits.numberSet == 0 then return #{}
        if not(this.isStoredContextCurrent()) then
        (
            last_message = "Topology changed. Scan the object again."
            return undefined
        )

        context_data = this.resolveContext scan_node modifier_value:scan_modifier
        context_kind = context_data[1]
        topology_value = context_data[3]
        candidate_faces = #{}
        selected_faces = #{}
        topology_ok = true
        topology_exception_text = ""

        try
        (
            if context_kind == #editable_poly then
            (
                candidate_faces = polyop.getFacesUsingVert topology_value vertex_bits

                for face_id in candidate_faces do
                (
                    face_vertices = polyop.getFaceVerts topology_value face_id
                    face_is_fully_selected = true

                    for face_vertex_id in face_vertices do
                    (
                        if not(vertex_bits[face_vertex_id]) then
                        (
                            face_is_fully_selected = false
                        )
                    )

                    if face_is_fully_selected then
                    (
                        selected_faces[face_id] = true
                    )
                )
            )
            else if context_kind == #edit_poly then
            (
                if not(this.modifierBelongsToNode scan_node topology_value) then
                (
                    throw "Stored Edit Poly modifier no longer belongs to the scanned node."
                )

                for vertex_id in vertex_bits do
                (
                    vertex_face_count = EditPolyMod.GetVertexFaceCount topology_value vertex_id node:scan_node

                    if vertex_face_count == undefined or vertex_face_count < 0 then
                    (
                        throw "Could not read Edit Poly vertex-face adjacency."
                    )

                    for vertex_face_offset = 1 to vertex_face_count do
                    (
                        face_id = EditPolyMod.GetVertexFace topology_value vertex_id vertex_face_offset node:scan_node

                        if face_id == undefined or face_id < 1 then
                        (
                            throw "Could not read one Edit Poly face index."
                        )

                        candidate_faces[face_id] = true
                    )
                )

                for face_id in candidate_faces do
                (
                    face_degree = EditPolyMod.GetFaceDegree topology_value face_id node:scan_node

                    if face_degree == undefined or face_degree < 3 then
                    (
                        throw "Could not read one Edit Poly face degree."
                    )

                    face_is_fully_selected = true

                    for corner_index = 1 to face_degree do
                    (
                        face_vertex_id = EditPolyMod.GetFaceVertex topology_value face_id corner_index node:scan_node

                        if face_vertex_id == undefined or face_vertex_id < 1 then
                        (
                            throw "Could not read one Edit Poly face vertex."
                        )

                        if not(vertex_bits[face_vertex_id]) then
                        (
                            face_is_fully_selected = false
                        )
                    )

                    if face_is_fully_selected then
                    (
                        selected_faces[face_id] = true
                    )
                )
            )
            else
            (
                topology_ok = false
            )
        )
        catch
        (
            topology_exception_text = getCurrentException()
            vertexLevelAlignerWriteLog ("FACE FILTER ERROR: " + (topology_exception_text as string))
            topology_ok = false
        )

        if not(topology_ok) then
        (
            last_message = "Could not resolve polygons from the selected level vertices."
            return undefined
        )

        selected_faces
        -- return
    ),

    /*
    Resolves TreeView targets to vertices and returns only polygons fully contained by those vertices.
    */
    function getFullySelectedFacesFromTargets target_data_array =
    (
        target_vertex_bits = this.getTargetVertexBits target_data_array
        if target_vertex_bits == undefined then return undefined

        this.getFullySelectedFacesFromVertexBits target_vertex_bits
        -- return
    ),

    /*
    Collects the union of exclusive polygon faces belonging to every currently broken threshold group.
    A face is included only when all of its vertices belong to the same broken group; valid groups remain untouched.
    */
    function getBrokenDiagnosticFaceBits =
    (
        if not(this.isStoredContextCurrent()) then
        (
            last_message = "Topology changed. Scan the object again."
            return undefined
        )

        broken_face_bits = #{}

        for group_index = 1 to level_groups.count do
        (
            group_data = this.getGroupData group_index context_validated:true

            if group_data == undefined then
            (
                vertexLevelAlignerWriteLog ("DIAGNOSTIC PAINT FACE ERROR: group data missing at index " + (group_index as string))
                return undefined
            )

            if group_data[6] then
            (
                group_face_bits = this.getFullySelectedFacesFromVertexBits group_data[4]

                if group_face_bits == undefined then
                (
                    vertexLevelAlignerWriteLog ("DIAGNOSTIC PAINT FACE ERROR: exclusive face resolution failed for broken group " + (group_index as string))
                    return undefined
                )

                for face_id in group_face_bits do
                (
                    broken_face_bits[face_id] = true
                )
            )
        )

        broken_face_bits
        -- return
    ),

    /*
    Clears only the independent Vertex Color Painter session owned by this Vertex Level Aligner instance.
    Original base channel/display state or the exact owned PaintLayerMod is restored by the Operation itself.
    */
    function clearDiagnosticPaint update_message:true =
    (
        if diagnostic_painter == undefined then
        (
            if update_message then last_message = "Diagnostic paint is already clear."
            return true
        )

        clear_ok = diagnostic_painter.clearPaint()

        if not(clear_ok) then
        (
            vertexLevelAlignerWriteLog "DIAGNOSTIC PAINT CLEAR ERROR: Vertex Color Painter refused cleanup."
            if update_message then last_message = "Could not clear diagnostic paint safely."
            return false
        )

        diagnostic_painter = undefined
        if update_message then last_message = "Diagnostic paint cleared."

        true
        -- return
    ),

    /*
    Paints exclusive polygons from all broken groups with one diagnostic color through Vertex Color Painter.
    The painter is bound to the exact same Editable Poly base or Edit Poly stack level used by the current scan.
    */
    function paintBrokenDiagnosticFaces color_value:(color 255 0 0) =
    (
        if classOf color_value != Color then
        (
            vertexLevelAlignerWriteLog ("DIAGNOSTIC PAINT ERROR: invalid color value " + (color_value as string))
            last_message = "Diagnostic paint requires a Color value."
            return false
        )

        if VertexColorPainter_v == undefined then
        (
            vertexLevelAlignerWriteLog "DIAGNOSTIC PAINT ERROR: Vertex Color Painter Operation is unavailable."
            last_message = "Vertex Color Painter Operation is unavailable."
            return false
        )

        if not(this.isStoredContextCurrent()) then
        (
            last_message = "Topology changed. Scan the object again."
            return false
        )

        broken_count = this.getBrokenGroupCount context_validated:true
        broken_face_bits = this.getBrokenDiagnosticFaceBits()

        if broken_face_bits == undefined then
        (
            last_message = "Could not resolve exclusive polygons for broken groups."
            return false
        )

        if not(this.clearDiagnosticPaint update_message:false) then return false

        if broken_count == 0 then
        (
            last_message = "No broken groups to paint."
            return true
        )

        if broken_face_bits.numberSet == 0 then
        (
            last_message = (broken_count as string) + " broken groups | no exclusive polygons to paint."
            return true
        )

        painter_stack_index = this.getDiagnosticPainterStackIndex()
        if painter_stack_index < 0 then
        (
            last_message = "Could not resolve the diagnostic paint topology level."
            return false
        )

        diagnostic_painter = VertexColorPainter_v()
        if diagnostic_painter == undefined then
        (
            vertexLevelAlignerWriteLog "DIAGNOSTIC PAINT ERROR: could not create independent Vertex Color Painter session."
            last_message = "Could not create diagnostic painter session."
            return false
        )

        if not(diagnostic_painter.setTarget scan_node painter_stack_index) then
        (
            vertexLevelAlignerWriteLog ("DIAGNOSTIC PAINT ERROR: setTarget failed | node:" + (scan_node as string) + " | stack:" + (painter_stack_index as string))
            diagnostic_painter = undefined
            last_message = "Vertex Color Painter rejected the scanned topology level."
            return false
        )

        if not(diagnostic_painter.beginPaint()) then
        (
            vertexLevelAlignerWriteLog "DIAGNOSTIC PAINT ERROR: beginPaint failed."
            cleanup_ok = diagnostic_painter.clearPaint()

            if cleanup_ok then
            (
                diagnostic_painter = undefined
                last_message = "Could not begin diagnostic paint; temporary paint state was cleared."
            )
            else
            (
                vertexLevelAlignerWriteLog "DIAGNOSTIC PAINT CLEANUP ERROR: beginPaint failure cleanup also failed."
                last_message = "Could not begin diagnostic paint; cleanup also failed."
            )

            return false
        )

        paint_ok = true
        failed_face_id = 0

        for face_id in broken_face_bits while paint_ok do
        (
            if not(diagnostic_painter.paintFace face_id color_value) then
            (
                paint_ok = false
                failed_face_id = face_id
            )
        )

        end_ok = diagnostic_painter.endPaint()

        if not(paint_ok) or not(end_ok) then
        (
            vertexLevelAlignerWriteLog ("DIAGNOSTIC PAINT ERROR: paint transaction failed | face:" + (failed_face_id as string) + " | endPaint:" + (end_ok as string))
            cleanup_ok = diagnostic_painter.clearPaint()

            if cleanup_ok then
            (
                diagnostic_painter = undefined
                last_message = "Diagnostic paint failed and was rolled back."
            )
            else
            (
                vertexLevelAlignerWriteLog "DIAGNOSTIC PAINT CLEANUP ERROR: failed paint transaction could not be rolled back safely."
                last_message = "Diagnostic paint failed; cleanup also failed."
            )

            return false
        )

        diagnostic_broken_color = color_value
        last_message = (broken_count as string) + " broken groups | " + (broken_face_bits.numberSet as string) + " exclusive polygons painted red."

        true
        -- return
    ),

    /*
    Applies one 1-based Material ID directly to Editable Poly faces and verifies every written face.
    */
    function setEditablePolyFaceMaterialId face_bits material_id =
    (
        if face_bits == undefined then return false
        if face_bits.numberSet == 0 then
        (
            last_message = "No fully selected polygons were found."
            return false
        )
        if material_id < 1 or material_id > 65536 then
        (
            last_message = "Material ID must be between 1 and 65536."
            return false
        )
        if scan_kind != #editable_poly then return false
        if not(this.isStoredContextCurrent()) then
        (
            last_message = "Topology changed. Scan the object again."
            return false
        )

        topology_value = scan_node.baseObject
        operation_ok = true
        operation_exception_text = ""

        try
        (
            polyop.setFaceMatID topology_value face_bits material_id

            for face_id in face_bits do
            (
                actual_material_id = polyop.getFaceMatID topology_value face_id

                if actual_material_id != material_id then
                (
                    throw ("Material ID verification failed on face " + (face_id as string) + ".")
                )
            )

            update scan_node
        )
        catch
        (
            operation_exception_text = getCurrentException()
            vertexLevelAlignerWriteLog ("EDITABLE POLY MATERIAL ERROR: " + (operation_exception_text as string))
            operation_ok = false
        )

        if not(operation_ok) then
        (
            last_message = "Could not apply Material ID to the selected polygons."
            return false
        )

        redrawViews()
        last_message = (face_bits.numberSet as string) + " polygons set to Material ID " + (material_id as string) + "."
        true
        -- return
    ),

    /*
    Applies one 1-based Material ID through the active Edit Poly modifier and restores its face selection and sub-object level.
    Edit Poly's materialIDToSet value is zero-based, so the UI Material ID is converted by subtracting one.
    */
    function setEditPolyFaceMaterialId face_bits material_id =
    (
        if face_bits == undefined then return false
        if face_bits.numberSet == 0 then
        (
            last_message = "No fully selected polygons were found."
            return false
        )
        if material_id < 1 or material_id > 65536 then
        (
            last_message = "Material ID must be between 1 and 65536."
            return false
        )
        if scan_kind != #edit_poly then return false
        if not(this.isStoredContextCurrent()) then
        (
            last_message = "Topology changed. Scan the object again."
            return false
        )

        edit_poly_mod = scan_modifier
        if not(this.modifierBelongsToNode scan_node edit_poly_mod) then
        (
            last_message = "The scanned Edit Poly modifier is no longer valid."
            return false
        )

        if getCommandPanelTaskMode() != #modify then
        (
            last_message = "Select a TreeView level before applying Material ID."
            return false
        )

        current_object = undefined
        context_read_ok = true
        context_exception_text = ""

        try
        (
            current_object = modPanel.getCurrentObject()
        )
        catch
        (
            context_exception_text = getCurrentException()
            vertexLevelAlignerWriteLog ("EDIT POLY MATERIAL CONTEXT ERROR: " + (context_exception_text as string))
            context_read_ok = false
        )

        if not(context_read_ok) or current_object != edit_poly_mod then
        (
            last_message = "Keep the scanned Edit Poly modifier active before applying Material ID."
            return false
        )

        previous_subobject_level = this.getCurrentSubObjectLevelSafe()
        if previous_subobject_level == undefined then
        (
            last_message = "Could not read the current sub-object level."
            return false
        )

        previous_epoly_level = undefined
        previous_face_selection = undefined
        previous_material_id_to_set = undefined
        state_read_ok = true
        state_exception_text = ""

        try
        (
            previous_epoly_level = edit_poly_mod.GetEPolySelLevel()
            previous_face_selection = edit_poly_mod.GetSelection #Face node:scan_node
            previous_material_id_to_set = edit_poly_mod.materialIDToSet
        )
        catch
        (
            state_exception_text = getCurrentException()
            vertexLevelAlignerWriteLog ("EDIT POLY MATERIAL STATE READ ERROR: " + (state_exception_text as string))
            state_read_ok = false
        )

        if not(state_read_ok) or previous_epoly_level == undefined or previous_face_selection == undefined then
        (
            last_message = "Could not preserve the Edit Poly selection state."
            return false
        )

        operation_ok = true
        operation_started = false
        operation_exception_text = ""
        expected_edit_poly_material_id = material_id - 1

        try
        (
            edit_poly_mod.SetPrimaryNode scan_node
            edit_poly_mod.useStackSelection = false
            edit_poly_mod.selectMode = 0
            edit_poly_mod.SetEPolySelLevel #Face
            subObjectLevel = 4

            current_face_selection = edit_poly_mod.GetSelection #Face node:scan_node

            if current_face_selection.numberSet > 0 then
            (
                edit_poly_mod.Select #Face current_face_selection select:false node:scan_node
            )

            edit_poly_mod.Select #Face face_bits select:true node:scan_node
            actual_face_selection = edit_poly_mod.GetSelection #Face node:scan_node

            if not(this.bitArraysEqual actual_face_selection face_bits) then
            (
                throw "Could not apply the temporary Edit Poly face selection."
            )

            edit_poly_mod.SetOperation #SetMaterial
            operation_started = true
            edit_poly_mod.materialIDToSet = expected_edit_poly_material_id
            edit_poly_mod.Commit()
            operation_started = false

            for face_id in face_bits do
            (
                actual_material_id = EditPolyMod.GetFaceMaterial edit_poly_mod face_id node:scan_node

                if actual_material_id != expected_edit_poly_material_id then
                (
                    throw ("Material ID verification failed on Edit Poly face " + (face_id as string) + ".")
                )
            )
        )
        catch
        (
            operation_exception_text = getCurrentException()
            vertexLevelAlignerWriteLog ("EDIT POLY MATERIAL ERROR: " + (operation_exception_text as string))
            operation_ok = false
        )

        cancel_ok = true
        cancel_exception_text = ""

        if operation_started then
        (
            try
            (
                edit_poly_mod.Cancel()
                operation_started = false
            )
            catch
            (
                cancel_exception_text = getCurrentException()
                vertexLevelAlignerWriteLog ("EDIT POLY MATERIAL CANCEL ERROR: " + (cancel_exception_text as string))
                cancel_ok = false
            )
        )

        restore_ok = true
        restore_exception_text = ""

        try
        (
            current_face_selection = edit_poly_mod.GetSelection #Face node:scan_node

            if current_face_selection.numberSet > 0 then
            (
                edit_poly_mod.Select #Face current_face_selection select:false node:scan_node
            )

            if previous_face_selection.numberSet > 0 then
            (
                edit_poly_mod.Select #Face previous_face_selection select:true node:scan_node
            )

            restored_face_selection = edit_poly_mod.GetSelection #Face node:scan_node

            if not(this.bitArraysEqual restored_face_selection previous_face_selection) then
            (
                throw "Could not restore the previous Edit Poly face selection."
            )

            edit_poly_mod.materialIDToSet = previous_material_id_to_set
            edit_poly_mod.SetEPolySelLevel previous_epoly_level
            subObjectLevel = previous_subobject_level
            edit_poly_mod.RefreshScreen()
        )
        catch
        (
            restore_exception_text = getCurrentException()
            vertexLevelAlignerWriteLog ("EDIT POLY MATERIAL RESTORE ERROR: " + (restore_exception_text as string))
            restore_ok = false
        )

        completeRedraw()

        if not(operation_ok) then
        (
            last_message = "Could not apply Material ID to the selected polygons."
            return false
        )

        if not(cancel_ok) or not(restore_ok) then
        (
            last_message = "Material ID was applied, but Edit Poly state could not be fully restored."
            return false
        )

        last_message = (face_bits.numberSet as string) + " polygons set to Material ID " + (material_id as string) + "."
        true
        -- return
    ),

    /*
    Applies the requested Material ID only to polygons whose every vertex belongs to the selected TreeView targets.
    */
    function applyMaterialIdToTargets target_data_array material_id =
    (
        if target_data_array == undefined or not(isKindOf target_data_array Array) or target_data_array.count == 0 then
        (
            last_message = "Select one or more TreeView levels first."
            return false
        )
        if material_id < 1 or material_id > 65536 then
        (
            last_message = "Material ID must be between 1 and 65536."
            return false
        )

        selected_faces = this.getFullySelectedFacesFromTargets target_data_array
        if selected_faces == undefined then return false

        if selected_faces.numberSet == 0 then
        (
            last_message = "No polygons have all vertices inside the selected level vertices."
            return false
        )

        if scan_kind == #editable_poly then
        (
            return this.setEditablePolyFaceMaterialId selected_faces material_id
        )

        if scan_kind == #edit_poly then
        (
            return this.setEditPolyFaceMaterialId selected_faces material_id
        )

        last_message = "The scanned target does not support polygon Material IDs."
        false
        -- return
    ),

    /*
    Returns the live selected-axis position represented by one scanned vertex set.
    TreeView text is ignored; positions are read directly from the current Editable Poly / Edit Poly topology.
    */
    function getLiveVertexBitsAxisValue vertex_bits =
    (
        if vertex_bits == undefined or vertex_bits.numberSet == 0 then return undefined
        if not(this.isStoredContextCurrent()) then
        (
            last_message = "Topology changed. Scan the object again."
            return undefined
        )

        context_data = this.resolveContext scan_node modifier_value:scan_modifier
        axis_reference = undefined
        axis_delta_total = 0.0
        axis_count = 0
        read_ok = true

        try
        (
            for vertex_id in vertex_bits do
            (
                world_position = this.getWorldVertexPosition context_data vertex_id topology_validated:true
                if world_position == undefined then throw "Could not read one live target vertex."

                axis_value = this.getWorldAxisValue world_position

                if axis_reference == undefined then
                (
                    axis_reference = axis_value
                )
                else
                (
                    axis_delta_total += axis_value - axis_reference
                )

                axis_count += 1
            )
        )
        catch
        (
            live_axis_exception = getCurrentException()
            read_ok = false
        )

        if not(read_ok) or axis_count != vertex_bits.numberSet or axis_reference == undefined then
        (
            last_message = "Could not read every target vertex from live geometry."
            return undefined
        )

        axis_reference + (axis_delta_total / axis_count)
        -- return
    ),

    /*
    Returns the selected-axis coordinate reported by 3ds Max's native sub-object Selection Center.
    The supplied BitArray must already be the active Vertex selection; otherwise undefined is returned without changing selection.
    The user's Coordinate System Center mode is restored after the native transform-axis read.
    */
    function getCurrentVertexSelectionCenterAxisValue vertex_bits =
    (
        if vertex_bits == undefined or vertex_bits.numberSet == 0 then return undefined
        if not(this.isStoredContextCurrent()) then return undefined

        current_subobject_level = this.getCurrentSubObjectLevelSafe()
        if current_subobject_level != 1 then return undefined

        selected_vertex_bits = undefined
        selection_read_ok = true

        try
        (
            if scan_kind == #editable_poly then
            (
                selected_vertex_bits = polyop.getVertSelection scan_node.baseObject
            )
            else if scan_kind == #edit_poly then
            (
                if not(this.modifierBelongsToNode scan_node scan_modifier) then return undefined
                selected_vertex_bits = scan_modifier.GetSelection #Vertex node:scan_node
            )
            else
            (
                selection_read_ok = false
            )
        )
        catch
        (
            selection_center_selection_exception = getCurrentException()
            vertexLevelAlignerWriteLog ("SELECTION CENTER selection read failed: " + selection_center_selection_exception)
            selection_read_ok = false
        )

        if not(selection_read_ok) or selected_vertex_bits == undefined then return undefined
        if not(this.bitArraysEqual selected_vertex_bits vertex_bits) then return undefined

        previous_center_mode = undefined
        center_mode_changed = false
        axis_matrix = undefined
        axis_read_ok = true

        try
        (
            previous_center_mode = getCoordCenter()
            if previous_center_mode != #selection then
            (
                setCoordCenter #selection
                center_mode_changed = true
            )

            axis_matrix = getTransformAxis scan_node 0
        )
        catch
        (
            selection_center_axis_exception = getCurrentException()
            vertexLevelAlignerWriteLog ("SELECTION CENTER transform-axis read failed: " + selection_center_axis_exception)
            axis_read_ok = false
        )

        if center_mode_changed and previous_center_mode != undefined then
        (
            restore_ok = true

            try
            (
                setCoordCenter previous_center_mode
            )
            catch
            (
                selection_center_restore_exception = getCurrentException()
                vertexLevelAlignerWriteLog ("SELECTION CENTER mode restore failed: " + selection_center_restore_exception)
                restore_ok = false
            )

            if not(restore_ok) then return undefined
        )

        if not(axis_read_ok) or axis_matrix == undefined then return undefined

        selection_center_world = axis_matrix.row4
        this.getWorldAxisValue selection_center_world
        -- return
    ),

    /*
    Returns true when stored topology still matches the vertex count used during the scan.
    Geometry topology changes require a new scan before IDs can be selected safely.
    */
    function isStoredContextCurrent =
    (
        if scan_node == undefined or not(isValidNode scan_node) then return false

        stored_node = scan_node
        stored_modifier = scan_modifier
        stored_kind = scan_kind
        stored_vertex_count = scan_vertex_count
        stored_topology_signature = scan_topology_signature

        context_data = this.resolveContext stored_node modifier_value:stored_modifier
        if context_data[1] != stored_kind then return false

        if stored_kind == #editable_poly then
        (
            topology_sync_state = this.synchronizeEditablePolyTopology context_data

            if topology_sync_state == #failed then return false
            if topology_sync_state == #collapsed then
            (
                stored_vertex_count = 0
                stored_topology_signature = undefined
                return false
            )
        )

        current_vertex_count = this.getContextVertexCount context_data topology_validated:true
        if current_vertex_count < 0 or current_vertex_count != stored_vertex_count then return false

        current_topology_signature = this.getContextTopologySignature context_data topology_validated:true
        if current_topology_signature == undefined then return false

        this.topologySignaturesEqual stored_topology_signature current_topology_signature
        -- return
    ),

    /*
    Unhides the supplied scanned vertices before TreeView selection.
    Editable Poly preserves hidden vertices outside the target set; Edit Poly exposes only Unhide All Vertices, so it unhides vertex components on that modifier before the target selection is applied.
    */
    function unhideVertexBits vertex_bits =
    (
        if vertex_bits == undefined then
        (
            last_message = "No vertex set was supplied for unhide."
            return false
        )
        if vertex_bits.numberSet == 0 then return true
        if not(this.isStoredContextCurrent()) then
        (
            last_message = "Topology changed. Scan the object again."
            return false
        )

        operation_ok = true

        try
        (
            if scan_kind == #editable_poly then
            (
                topology_value = scan_node.baseObject
                hidden_vertices = polyop.getHiddenVerts topology_value
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
            )
            else if scan_kind == #edit_poly then
            (
                modifier_value = scan_modifier
                if not(this.modifierBelongsToNode scan_node modifier_value) then return false

                select scan_node
                max modify mode

                this.disableCageBestEffort modifier_value
                modifier_value.SetPrimaryNode scan_node
                modifier_value.useStackSelection = false
                modifier_value.selectMode = 0
                modPanel.setCurrentObject modifier_value node:scan_node
                modifier_value.SetEPolySelLevel #Vertex
                subObjectLevel = 1
                modifier_value.ButtonOp #UnhideAllVertex
                modifier_value.RefreshScreen()
            )
            else
            (
                operation_ok = false
            )
        )
        catch
        (
            unhide_exception = getCurrentException()
            operation_ok = false
        )

        if not(operation_ok) then
        (
            last_message = "Could not unhide the requested vertices."
            return false
        )

        true
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

        selection_ok = true

        try
        (
            select scan_node
            max modify mode

            if scan_kind == #editable_poly then
            (
                topology_value = scan_node.baseObject
                subObjectLevel = 1
                polyop.setVertSelection topology_value vertex_bits
                actual_vertices = polyop.getVertSelection topology_value
                selection_ok = this.bitArraysEqual actual_vertices vertex_bits
            )
            else if scan_kind == #edit_poly then
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
                actual_vertices = modifier_value.GetSelection #Vertex
                selection_ok = this.bitArraysEqual actual_vertices vertex_bits
                modifier_value.RefreshScreen()
            )
            else
            (
                selection_ok = false
            )
        )
        catch
        (
            vertex_selection_exception = getCurrentException()
            selection_ok = false
        )

        completeRedraw()

        if not(selection_ok) then
        (
            last_message = "Could not apply and verify the vertex selection."
            return false
        )

        last_message = (vertex_bits.numberSet as string) + " vertices selected."
        true
        -- return
    ),

    /*
    Returns Editable Poly edges whose two endpoint vertices are both inside the supplied level vertex set.
    Candidate edges come from the same live topology that receives the final selection.
    */
    function getEditablePolyEdgesBetweenVertexBits vertex_bits context_validated:false =
    (
        result_edges = #{}
        if vertex_bits == undefined or vertex_bits.numberSet < 2 then return result_edges
        if not(context_validated) and not(this.isStoredContextCurrent()) then return undefined
        if scan_node == undefined or not(isValidNode scan_node) then return undefined
        if classOf scan_node.baseObject != Editable_Poly then return undefined

        topology_value = scan_node.baseObject
        read_ok = true

        try
        (
            candidate_edges = polyop.getEdgesUsingVert topology_value vertex_bits

            for edge_id in candidate_edges do
            (
                edge_vertices = polyop.getVertsUsingEdge topology_value #{edge_id}

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
        )
        catch
        (
            editable_edge_exception = getCurrentException()
            vertexLevelAlignerWriteLog ("EDITABLE POLY EDGE READ ERROR: " + (editable_edge_exception as string))
            read_ok = false
        )

        if not(read_ok) then return undefined

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
        if scan_node == undefined or not(isValidNode scan_node) then return undefined

        modifier_value = scan_modifier
        if not(this.modifierBelongsToNode scan_node modifier_value) then return undefined

        this.disableCageBestEffort modifier_value
        modifier_value.SetPrimaryNode scan_node
        modifier_value.useStackSelection = false
        modifier_value.selectMode = 0
        read_ok = true

        try
        (
            face_count = modifier_value.GetNumFaces node:scan_node

            for face_id = 1 to face_count do
            (
                face_degree = modifier_value.GetFaceDegree face_id node:scan_node
                if face_degree < 0 then throw "Invalid Edit Poly face degree."

                if face_degree >= 2 then
                (
                    for corner_id = 1 to face_degree do
                    (
                        next_corner_id = if corner_id == face_degree then 1 else corner_id + 1
                        vertex_a = modifier_value.GetFaceVertex face_id corner_id node:scan_node
                        vertex_b = modifier_value.GetFaceVertex face_id next_corner_id node:scan_node

                        if vertex_a <= 0 or vertex_b <= 0 then throw "Invalid Edit Poly face vertex."

                        if vertex_bits[vertex_a] and vertex_bits[vertex_b] then
                        (
                            edge_id = modifier_value.GetFaceEdge face_id corner_id node:scan_node
                            if edge_id <= 0 then throw "Invalid Edit Poly face edge."
                            result_edges[edge_id] = true
                        )
                    )
                )
            )
        )
        catch
        (
            edit_poly_edge_exception = getCurrentException()
            read_ok = false
        )

        if not(read_ok) then return undefined

        result_edges
        -- return
    ),

    /*
    Resolves edges between vertices on one exact level for the currently scanned topology.
    */
    function getEdgesBetweenVertexBits vertex_bits context_validated:false =
    (
        if not(context_validated) and not(this.isStoredContextCurrent()) then return undefined

        if scan_kind == #editable_poly then
        (
            return this.getEditablePolyEdgesBetweenVertexBits vertex_bits context_validated:true
        )

        if scan_kind == #edit_poly then
        (
            return this.getEditPolyEdgesBetweenVertexBits vertex_bits
        )

        undefined
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

        selection_ok = true

        try
        (
            select scan_node
            max modify mode

            if scan_kind == #editable_poly then
            (
                topology_value = scan_node.baseObject
                subObjectLevel = 2
                polyop.setEdgeSelection topology_value edge_bits
                actual_edges = polyop.getEdgeSelection topology_value
                selection_ok = this.bitArraysEqual actual_edges edge_bits
            )
            else if scan_kind == #edit_poly then
            (
                modifier_value = scan_modifier
                if not(this.modifierBelongsToNode scan_node modifier_value) then return false

                this.disableCageBestEffort modifier_value
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
                actual_edges = modifier_value.GetSelection #Edge
                selection_ok = this.bitArraysEqual actual_edges edge_bits
                modifier_value.RefreshScreen()
            )
            else
            (
                selection_ok = false
            )
        )
        catch
        (
            edge_selection_exception = getCurrentException()
            selection_ok = false
        )

        completeRedraw()

        if not(selection_ok) then
        (
            last_message = "Could not apply and verify the edge selection."
            return false
        )

        last_message = (edge_bits.numberSet as string) + " edges selected."
        true
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
    function moveEditablePolyVertexBitsByWorldAxisDelta vertex_bits delta_world_value world_axis_value:undefined context_validated:false =
    (
        if vertex_bits == undefined or vertex_bits.numberSet == 0 then return false
        if not(context_validated) and not(this.isStoredContextCurrent()) then return false
        if scan_node == undefined or not(isValidNode scan_node) then return false
        if classOf scan_node.baseObject != Editable_Poly then return false

        topology_value = scan_node.baseObject
        this.disableCageBestEffort topology_value
        move_ok = true

        try
        (
            world_delta = this.getWorldAxisDeltaVector delta_world_value world_axis_value:world_axis_value
            inverse_transform = inverse scan_node.objectTransform
            local_origin = [0,0,0] * inverse_transform
            local_target = world_delta * inverse_transform
            local_delta = local_target - local_origin

            polyop.moveVert topology_value vertex_bits local_delta
            update scan_node
        )
        catch
        (
            editable_move_exception = getCurrentException()
            vertexLevelAlignerWriteLog ("EDITABLE POLY MOVE ERROR: " + (editable_move_exception as string))
            move_ok = false
        )

        move_ok
        -- return
    ),

    /*
    Moves Editable Poly vertices by one world-axis delta through PolyOp's native world-coordinate node context.
    This round-only path avoids converting a tiny world delta through objectTransform before the geometry write.
    */
    function moveEditablePolyVertexBitsByWorldAxisDeltaDirect vertex_bits delta_world_value world_axis_value:undefined context_validated:false =
    (
        if vertex_bits == undefined or vertex_bits.numberSet == 0 then return false
        if not(context_validated) and not(this.isStoredContextCurrent()) then return false
        if scan_node == undefined or not(isValidNode scan_node) then return false
        if classOf scan_node.baseObject != Editable_Poly then return false

        topology_value = scan_node.baseObject
        axis_to_use = if world_axis_value == undefined then world_axis else this.normalizeWorldAxis world_axis_value
        world_positions = #()
        write_ok = true

        try
        (
            in coordsys world
            (
                for vertex_id in vertex_bits do
                (
                    world_position = polyop.getVert topology_value vertex_id node:scan_node
                    if world_position == undefined then throw "Could not read one Editable Poly vertex for direct world movement."

                    case axis_to_use of
                    (
                        #x: world_position.x = (world_position.x as Double) + (delta_world_value as Double)
                        #y: world_position.y = (world_position.y as Double) + (delta_world_value as Double)
                        default: world_position.z = (world_position.z as Double) + (delta_world_value as Double)
                    )

                    append world_positions world_position
                )

                if world_positions.count != vertex_bits.numberSet then throw "Incomplete Editable Poly direct world movement read."
                polyop.setVert topology_value vertex_bits world_positions node:scan_node
            )

            update scan_node
        )
        catch
        (
            editable_direct_move_exception = getCurrentException()
            vertexLevelAlignerWriteLog ("EDITABLE POLY DIRECT MOVE ERROR: " + (editable_direct_move_exception as string))
            write_ok = false
        )

        write_ok
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

        this.disableCageBestEffort modifier_value
        selection_ok = true

        try
        (
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
            actual_vertices = modifier_value.GetSelection #Vertex
            selection_ok = this.bitArraysEqual actual_vertices vertex_bits
        )
        catch
        (
            edit_poly_prepare_exception = getCurrentException()
            selection_ok = false
        )

        selection_ok
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
        move_ok = true

        try
        (
            if abs(delta_world_value) > exact_epsilon then
            (
                modifier_value.MoveSelection move_amount
                modifier_value.Commit()
            )

            modifier_value.RefreshScreen()
        )
        catch
        (
            edit_poly_move_exception = getCurrentException()
            move_ok = false
        )

        move_ok
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
    /*
    Reads every requested live vertex into #(vertexID, axisValue) samples.
    Any missing live vertex makes the read fail instead of returning partial data.
    */
    function getVertexBitsWorldAxisSamples vertex_bits =
    (
        if vertex_bits == undefined or vertex_bits.numberSet == 0 then return undefined
        if not(this.isStoredContextCurrent()) then return undefined

        context_data = this.resolveContext scan_node modifier_value:scan_modifier
        sample_values = #()
        read_ok = true

        try
        (
            for vertex_id in vertex_bits do
            (
                world_position = this.getWorldVertexPosition context_data vertex_id topology_validated:true
                if world_position == undefined then throw "Could not read one live vertex."
                append sample_values #(vertex_id, this.getWorldAxisValue world_position)
            )
        )
        catch
        (
            axis_sample_exception = getCurrentException()
            read_ok = false
        )

        if not(read_ok) or sample_values.count != vertex_bits.numberSet then return undefined

        sample_values
        -- return
    ),

    /*
    Verifies that every sampled vertex moved by the requested world-axis delta.
    This catches native no-op or partial movement without changing the movement algorithm itself.
    */
    function verifyVertexBitsWorldAxisDelta before_samples delta_world_value context_validated:false =
    (
        if before_samples == undefined or before_samples.count == 0 then return false
        if not(context_validated) and not(this.isStoredContextCurrent()) then return false

        context_data = this.resolveContext scan_node modifier_value:scan_modifier
        verify_ok = true

        try
        (
            for sample_value in before_samples do
            (
                vertex_id = sample_value[1]
                source_axis_value = sample_value[2]
                expected_axis_value = source_axis_value + delta_world_value
                world_position = this.getWorldVertexPosition context_data vertex_id topology_validated:true
                if world_position == undefined then throw "Could not verify one moved vertex."

                current_axis_value = this.getWorldAxisValue world_position
                comparison_tolerance = exact_epsilon * 10.0
                precision_tolerance = this.getAxisPrecisionTolerance current_axis_value expected_axis_value
                if precision_tolerance > comparison_tolerance then comparison_tolerance = precision_tolerance

                if abs(current_axis_value - expected_axis_value) > comparison_tolerance then
                (
                    verify_ok = false
                )
            )
        )
        catch
        (
            delta_verify_exception = getCurrentException()
            vertexLevelAlignerWriteLog ("VERTEX DELTA VERIFY ERROR: " + (delta_verify_exception as string))
            verify_ok = false
        )

        verify_ok
        -- return
    ),
    function moveVertexBitsByWorldAxisDelta vertex_bits delta_world_value =
    (
        if vertex_bits == undefined or vertex_bits.numberSet == 0 then return false
        if not(this.isStoredContextCurrent()) then return false

        before_samples = this.getVertexBitsWorldAxisSamples vertex_bits
        if before_samples == undefined then
        (
            last_message = "Could not read every vertex before movement."
            return false
        )

        move_ok = false

        if scan_kind == #editable_poly then
        (
            move_ok = this.moveEditablePolyVertexBitsByWorldAxisDelta vertex_bits delta_world_value context_validated:true
        )
        else if scan_kind == #edit_poly then
        (
            move_ok = this.moveEditPolyVertexBitsByWorldAxisDelta vertex_bits delta_world_value
        )

        if not(move_ok) then return false

        if not(this.verifyVertexBitsWorldAxisDelta before_samples delta_world_value context_validated:true) then
        (
            last_message = "Vertex movement could not be verified on live geometry."
            return false
        )

        true
        -- return
    ),

    /*
    Compatibility wrapper for explicit world-Z dispatch.
    */
    function moveVertexBitsByWorldZDelta vertex_bits delta_world_z =
    (
        if vertex_bits == undefined or vertex_bits.numberSet == 0 then return false
        if not(this.isStoredContextCurrent()) then return false

        previous_world_axis = world_axis
        world_axis = #z
        move_ok = false

        try
        (
            move_ok = this.moveVertexBitsByWorldAxisDelta vertex_bits delta_world_z
        )
        catch
        (
            world_z_move_exception = getCurrentException()
            move_ok = false
        )

        world_axis = previous_world_axis
        move_ok
        -- return
    ),

    /*
    Moves one stored vertex set rigidly so its reference value reaches one target on the selected world axis.
    The vertex IDs are preserved; only the supplied selected-item vertices move.
    */
    function moveVertexBitsToAxisValue vertex_bits source_axis_value target_axis_value operation_text use_supplied_source:false use_direct_editable_poly_world_write:false =
    (
        if vertex_bits == undefined or vertex_bits.numberSet == 0 then return false
        if source_axis_value == undefined or target_axis_value == undefined then return false
        if not(this.isStoredContextCurrent()) then
        (
            last_message = "Topology changed. Scan the object again."
            return false
        )

        movement_source_axis_value = source_axis_value

        if not(use_supplied_source) then
        (
            movement_source_axis_value = this.getLiveVertexBitsAxisValue vertex_bits
            if movement_source_axis_value == undefined then
            (
                last_message = "Could not read the live source position for movement."
                return false
            )
        )

        target_node = scan_node
        target_modifier = scan_modifier
        target_threshold = threshold_value
        target_world_axis = world_axis
        target_vertex_count = vertex_bits.numberSet
        delta_world_value = target_axis_value - movement_source_axis_value

        movement_ok = false

        if use_direct_editable_poly_world_write and scan_kind == #editable_poly then
        (
            movement_ok = this.moveEditablePolyVertexBitsByWorldAxisDeltaDirect vertex_bits delta_world_value context_validated:true
        )
        else
        (
            movement_ok = this.moveVertexBitsByWorldAxisDelta vertex_bits delta_world_value
        )

        if not(movement_ok) then
        (
            last_message = "Could not move the selected item."
            return false
        )

        completeRedraw()

        compaction_serial_before_rescan = topology_compaction_serial

        if not(this.scanNode target_node modifier_value:target_modifier threshold:target_threshold world_axis_value:target_world_axis) then
        (
            return false
        )

        if topology_compaction_serial != compaction_serial_before_rescan then
        (
            vertex_bits = undefined
            last_message = "Editable Poly topology compacted during rescan. Previous component IDs were invalidated."
            return false
        )

        scan_message = last_message
        last_message = (target_vertex_count as string) + " vertices " + operation_text + " on world " + (this.getWorldAxisText()) + " | " + scan_message
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
    Snaps one selected-axis world value to a physical millimeter grid around an optional display-origin offset.
    UP uses the next/equal grid value; DOWN uses the previous/equal grid value.
    */
    function roundAxisValueToStepMillimeters source_axis_value round_direction step_millimeters offset_axis_value:0.0 =
    (
        if source_axis_value == undefined then return undefined
        if step_millimeters == undefined or step_millimeters <= 0.0 then return undefined

        millimeter_scale_double = (units.decodeValue "1mm") as Double
        if millimeter_scale_double <= 0.0d0 then return undefined

        source_axis_double = source_axis_value as Double
        offset_axis_double = offset_axis_value as Double
        step_millimeters_double = step_millimeters as Double
        tolerance_millimeters_double = 0.000001d0
        display_millimeters_double = (source_axis_double - offset_axis_double) / millimeter_scale_double

        rounded_millimeters_double = case round_direction of
        (
            #up: (ceil ((display_millimeters_double - tolerance_millimeters_double) / step_millimeters_double)) * step_millimeters_double
            #down: (floor ((display_millimeters_double + tolerance_millimeters_double) / step_millimeters_double)) * step_millimeters_double
            default: undefined
        )

        if rounded_millimeters_double == undefined then return undefined

        (rounded_millimeters_double * millimeter_scale_double) + offset_axis_double
        -- return
    ),

    /*
    Rounds one group row on the requested physical millimeter step by moving only that group's vertices rigidly.
    Internal exact-level spacing is preserved.
    */
    function roundGroupToStepMillimeters group_index round_direction step_millimeters offset_axis_value:0.0 source_axis_value:undefined =
    (
        group_data = this.getGroupData group_index
        if group_data == undefined then return false

        round_source_axis_value = source_axis_value
        if round_source_axis_value == undefined then
        (
            round_source_axis_value = this.getLiveVertexBitsAxisValue group_data[4]
        )
        if round_source_axis_value == undefined then return false

        target_axis_value = this.roundAxisValueToStepMillimeters round_source_axis_value round_direction step_millimeters offset_axis_value:offset_axis_value
        if target_axis_value == undefined then return false

        operation_text = if round_direction == #up then "rounded UP" else "rounded DOWN"
        this.moveVertexBitsToAxisValue group_data[4] round_source_axis_value target_axis_value operation_text use_supplied_source:true use_direct_editable_poly_world_write:true
        -- return
    ),

    /*
    Rounds one exact child level on the requested physical millimeter step.
    Sibling levels in the same group are not changed.
    */
    function roundLevelToStepMillimeters group_index level_index round_direction step_millimeters offset_axis_value:0.0 source_axis_value:undefined =
    (
        level_data = this.getLevelData group_index level_index
        if level_data == undefined then return false

        round_source_axis_value = source_axis_value
        if round_source_axis_value == undefined then
        (
            round_source_axis_value = this.getLiveVertexBitsAxisValue level_data[2]
        )
        if round_source_axis_value == undefined then return false

        target_axis_value = this.roundAxisValueToStepMillimeters round_source_axis_value round_direction step_millimeters offset_axis_value:offset_axis_value
        if target_axis_value == undefined then return false

        operation_text = if round_direction == #up then "rounded UP" else "rounded DOWN"
        this.moveVertexBitsToAxisValue level_data[2] round_source_axis_value target_axis_value operation_text use_supplied_source:true use_direct_editable_poly_world_write:true
        -- return
    ),

    /*
    Compatibility wrapper for callers that still request the historical fixed 5 mm rounding grid.
    */
    function roundAxisValueToFiveMillimeters source_axis_value round_direction offset_axis_value:0.0 =
    (
        this.roundAxisValueToStepMillimeters source_axis_value round_direction 5.0 offset_axis_value:offset_axis_value
        -- return
    ),

    /*
    Compatibility wrapper for historical fixed 5 mm group rounding.
    */
    function roundGroupToFiveMillimeters group_index round_direction offset_axis_value:0.0 =
    (
        this.roundGroupToStepMillimeters group_index round_direction 5.0 offset_axis_value:offset_axis_value
        -- return
    ),

    /*
    Compatibility wrapper for historical fixed 5 mm exact-level rounding.
    */
    function roundLevelToFiveMillimeters group_index level_index round_direction offset_axis_value:0.0 =
    (
        this.roundLevelToStepMillimeters group_index level_index round_direction 5.0 offset_axis_value:offset_axis_value
        -- return
    ),

    /*
    Sets every supplied Editable Poly vertex to one exact coordinate on the active world axis.
    PolyOp reads and writes the whole vertex set in native world coordinates so X, Y, and Z use the identical path.
    */
    function setEditablePolyVertexBitsToWorldAxisValue vertex_bits target_axis_value context_validated:false =
    (
        if vertex_bits == undefined or vertex_bits.numberSet == 0 then return false
        if not(context_validated) and not(this.isStoredContextCurrent()) then return false
        if scan_node == undefined or not(isValidNode scan_node) then return false
        if classOf scan_node.baseObject != Editable_Poly then return false

        topology_value = scan_node.baseObject
        axis_to_use = this.normalizeWorldAxis world_axis
        world_positions = #()
        write_ok = true

        try
        (
            in coordsys world
            (
                for vertex_id in vertex_bits do
                (
                    world_position = polyop.getVert topology_value vertex_id node:scan_node
                    if world_position == undefined then throw "Could not read one Editable Poly vertex for exact-axis write."

                    case axis_to_use of
                    (
                        #x: world_position.x = target_axis_value
                        #y: world_position.y = target_axis_value
                        default: world_position.z = target_axis_value
                    )

                    append world_positions world_position
                )

                if world_positions.count != vertex_bits.numberSet then throw "Incomplete Editable Poly vertex read."

                polyop.setVert topology_value vertex_bits world_positions node:scan_node
            )

            update scan_node
        )
        catch
        (
            editable_set_exception = getCurrentException()
            vertexLevelAlignerWriteLog ("EDITABLE POLY EXACT WRITE ERROR: " + (editable_set_exception as string))
            write_ok = false
        )

        write_ok
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
                if not(this.moveVertexBitsByWorldAxisDelta level_bits delta_world_value) then return false
            )
        )

        context_data = this.resolveContext scan_node modifier_value:scan_modifier

        for vertex_id in vertex_bits do
        (
            world_position = undefined
            read_ok = true

            try
            (
                world_position = this.getWorldVertexPosition context_data vertex_id topology_validated:true
            )
            catch
            (
                edit_poly_correction_read_exception = getCurrentException()
                read_ok = false
            )

            if not(read_ok) or world_position == undefined then return false

            current_axis_value = this.getWorldAxisValue world_position
            correction_delta = target_axis_value - current_axis_value

            if abs(correction_delta) > exact_epsilon then
            (
                correction_bits = #{}
                correction_bits[vertex_id] = true
                if not(this.moveVertexBitsByWorldAxisDelta correction_bits correction_delta) then return false
            )
        )

        true
        -- return
    ),

    /*
    Returns true only when every supplied vertex is at the requested world-axis coordinate.
    This verifies the real live geometry rather than trusting stored TreeView data.
    */
    function verifyVertexBitsAtWorldAxisValue vertex_bits target_axis_value context_validated:false =
    (
        if vertex_bits == undefined or vertex_bits.numberSet == 0 then return false
        if not(context_validated) and not(this.isStoredContextCurrent()) then return false
        if scan_node == undefined or not(isValidNode scan_node) then return false

        context_data = this.resolveContext scan_node modifier_value:scan_modifier
        verification_tolerance = exact_epsilon * 10.0
        verify_ok = true

        try
        (
            for vertex_id in vertex_bits do
            (
                world_position = this.getWorldVertexPosition context_data vertex_id topology_validated:true
                if world_position == undefined then throw "Could not read one verification vertex."

                current_axis_value = this.getWorldAxisValue world_position
                precision_tolerance = this.getAxisPrecisionTolerance current_axis_value target_axis_value
                comparison_tolerance = verification_tolerance
                if precision_tolerance > comparison_tolerance then comparison_tolerance = precision_tolerance

                if abs(current_axis_value - target_axis_value) > comparison_tolerance then
                (
                    verify_ok = false
                )
            )
        )
        catch
        (
            exact_verify_exception = getCurrentException()
            vertexLevelAlignerWriteLog ("EXACT AXIS VERIFY ERROR: " + (exact_verify_exception as string))
            verify_ok = false
        )

        verify_ok
        -- return
    ),

    /*
    Returns true when every requested vertex belongs to one exact rescanned level at the target value.
    Extra vertices may share that exact level; the requested set itself must not remain split.
    */
    function areVertexBitsInSingleExactLevel vertex_bits target_axis_value context_validated:false =
    (
        if vertex_bits == undefined or vertex_bits.numberSet == 0 then return false
        if not(context_validated) and not(this.isStoredContextCurrent()) then return false

        for group_data in level_groups do
        (
            exact_levels = group_data[5]

            for level_data in exact_levels do
            (
                level_axis_value = level_data[1]
                comparison_tolerance = exact_epsilon * 10.0
                precision_tolerance = this.getAxisPrecisionTolerance level_axis_value target_axis_value
                if precision_tolerance > comparison_tolerance then comparison_tolerance = precision_tolerance

                if abs(level_axis_value - target_axis_value) <= comparison_tolerance then
                (
                    matching_bits = level_data[2] * vertex_bits
                    if matching_bits.numberSet == vertex_bits.numberSet then return true
                )
            )
        )

        false
        -- return
    ),


    /*
    Sets every vertex in one threshold group to the current item's selected-axis position, then rescans.
    The operation writes the full group directly instead of moving stored levels one at a time.
    */
    function flattenGroupToAxisValue group_index target_axis_value alignment_mode:#here =
    (
        if target_axis_value == undefined then return false
        if not(this.isStoredContextCurrent()) then
        (
            last_message = "Topology changed. Scan the object again."
            return false
        )

        group_data = this.getGroupData group_index context_validated:true
        if group_data == undefined then return false

        group_bits = group_data[4]
        if group_bits == undefined or group_bits.numberSet == 0 then return false

        group_vertex_count = group_bits.numberSet
        target_node = scan_node
        target_modifier = scan_modifier
        target_threshold = threshold_value
        target_world_axis = world_axis
        write_ok = false

        if scan_kind == #editable_poly then
        (
            write_ok = this.setEditablePolyVertexBitsToWorldAxisValue group_bits target_axis_value context_validated:true
        )
        else if scan_kind == #edit_poly then
        (
            write_ok = this.setEditPolyVertexBitsToWorldAxisValue group_bits group_data[5] target_axis_value
        )

        if not(write_ok) then
        (
            last_message = "Could not set the group vertex positions."
            return false
        )

        if not(this.verifyVertexBitsAtWorldAxisValue group_bits target_axis_value context_validated:true) then
        (
            last_message = "Group alignment did not reach the requested live world-axis position."
            return false
        )

        completeRedraw()

        compaction_serial_before_rescan = topology_compaction_serial

        if not(this.scanNode target_node modifier_value:target_modifier threshold:target_threshold world_axis_value:target_world_axis) then
        (
            return false
        )

        if topology_compaction_serial != compaction_serial_before_rescan then
        (
            group_bits = undefined
            group_data = undefined
            last_message = "Editable Poly topology compacted during rescan. Previous component IDs were invalidated."
            return false
        )

        if not(this.areVertexBitsInSingleExactLevel group_bits target_axis_value context_validated:true) then
        (
            last_message = "Aligned group did not rescan as one exact level."
            return false
        )

        scan_message = last_message
        last_message = (group_vertex_count as string) + " vertices aligned " + (this.getAlignmentModeText alignment_mode) + " on world " + (this.getWorldAxisText()) + " | " + scan_message
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

        if not(this.verifyVertexBitsAtWorldAxisValue aligned_bits target_axis_value context_validated:true) then
        (
            last_message = "Level alignment did not reach the requested live world-axis position."
            return false
        )

        aligned_vertex_count = aligned_bits.numberSet
        completeRedraw()

        compaction_serial_before_rescan = topology_compaction_serial

        if not(this.scanNode target_node modifier_value:target_modifier threshold:target_threshold world_axis_value:target_world_axis) then
        (
            return false
        )

        if topology_compaction_serial != compaction_serial_before_rescan then
        (
            aligned_bits = undefined
            exact_levels = undefined
            last_message = "Editable Poly topology compacted during rescan. Previous component IDs were invalidated."
            return false
        )

        if not(this.areVertexBitsInSingleExactLevel aligned_bits target_axis_value context_validated:true) then
        (
            last_message = "Aligned vertices did not rescan as one exact level."
            return false
        )

        scan_message = last_message

        if not(this.selectVertexBits aligned_bits) then
        (
            return false
        )

        last_message = (aligned_vertex_count as string) + " vertices aligned " + (this.getAlignmentModeText alignment_mode) + " on world " + (this.getWorldAxisText()) + " | " + scan_message
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
                group_data = this.getGroupData group_index context_validated:true

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

        compaction_serial_before_rescan = topology_compaction_serial

        if not(this.scanNode target_node modifier_value:target_modifier threshold:target_threshold world_axis_value:target_world_axis) then
        (
            return false
        )

        if topology_compaction_serial != compaction_serial_before_rescan then
        (
            alignment_jobs = #()
            aligned_bits = undefined
            last_message = "Editable Poly topology compacted during rescan. Previous component IDs were invalidated."
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
    Returns true when the stored scan target is already the active Modify-panel object.
    CTRL multi-selection uses this to avoid needless modifier-stack activation and sub-object switching.
    */
    function isStoredModifyContextActive =
    (
        if scan_node == undefined or not(isValidNode scan_node) then return false
        if getCommandPanelTaskMode() != #modify then return false

        current_object = undefined
        read_ok = true

        try
        (
            current_object = modPanel.getCurrentObject()
        )
        catch
        (
            current_object_exception = getCurrentException()
            read_ok = false
        )

        if not(read_ok) or current_object == undefined then return false

        if scan_kind == #edit_poly then
        (
            return current_object == scan_modifier
        )

        if scan_kind == #editable_poly then
        (
            return current_object == scan_node.baseObject
        )

        false
        -- return
    ),

    /*
    Replaces the current Vertex selection without reactivating Modify mode or resetting subObjectLevel.
    If the stored target or Vertex level is not already active, the audited full selector is used as fallback.
    */
    function selectVertexBitsFast vertex_bits context_validated:false =
    (
        if vertex_bits == undefined then return false
        if not(context_validated) and not(this.isStoredContextCurrent()) then
        (
            last_message = "Topology changed. Scan the object again."
            return false
        )

        current_subobject_level = this.getCurrentSubObjectLevelSafe()
        if current_subobject_level == undefined then
        (
            last_message = "Could not read the current sub-object level."
            return false
        )

        if current_subobject_level != 1 then return this.selectVertexBits vertex_bits
        if not(this.isStoredModifyContextActive()) then return this.selectVertexBits vertex_bits

        selection_ok = true

        try
        (
            if scan_kind == #editable_poly then
            (
                topology_value = scan_node.baseObject
                polyop.setVertSelection topology_value vertex_bits
                actual_vertices = polyop.getVertSelection topology_value
                selection_ok = this.bitArraysEqual actual_vertices vertex_bits
            )
            else if scan_kind == #edit_poly then
            (
                modifier_value = scan_modifier
                if not(this.modifierBelongsToNode scan_node modifier_value) then return false

                old_vertices = modifier_value.GetSelection #Vertex node:scan_node
                if old_vertices.numberSet > 0 then
                (
                    modifier_value.Select #Vertex old_vertices select:false
                )

                if vertex_bits.numberSet > 0 then
                (
                    modifier_value.Select #Vertex vertex_bits select:true
                )

                actual_vertices = modifier_value.GetSelection #Vertex node:scan_node
                selection_ok = this.bitArraysEqual actual_vertices vertex_bits
                modifier_value.RefreshScreen()
            )
            else
            (
                selection_ok = false
            )
        )
        catch
        (
            fast_vertex_selection_exception = getCurrentException()
            selection_ok = false
        )

        if not(selection_ok) then
        (
            last_message = "Could not apply and verify the vertex selection."
            return false
        )

        redrawViews()
        last_message = (vertex_bits.numberSet as string) + " vertices selected."
        true
        -- return
    ),

    /*
    Replaces the current Edge selection without reactivating Modify mode or resetting subObjectLevel.
    If the stored target or Edge level is not already active, the audited full selector is used as fallback.
    */
    function selectEdgeBitsFast edge_bits context_validated:false =
    (
        if edge_bits == undefined then return false
        if not(context_validated) and not(this.isStoredContextCurrent()) then
        (
            last_message = "Topology changed. Scan the object again."
            return false
        )

        current_subobject_level = this.getCurrentSubObjectLevelSafe()
        if current_subobject_level == undefined then
        (
            last_message = "Could not read the current sub-object level."
            return false
        )

        if current_subobject_level != 2 then return this.selectEdgeBits edge_bits
        if not(this.isStoredModifyContextActive()) then return this.selectEdgeBits edge_bits

        selection_ok = true

        try
        (
            if scan_kind == #editable_poly then
            (
                topology_value = scan_node.baseObject
                polyop.setEdgeSelection topology_value edge_bits
                actual_edges = polyop.getEdgeSelection topology_value
                selection_ok = this.bitArraysEqual actual_edges edge_bits
            )
            else if scan_kind == #edit_poly then
            (
                modifier_value = scan_modifier
                if not(this.modifierBelongsToNode scan_node modifier_value) then return false

                old_edges = modifier_value.GetSelection #Edge node:scan_node
                if old_edges.numberSet > 0 then
                (
                    modifier_value.Select #Edge old_edges select:false
                )

                if edge_bits.numberSet > 0 then
                (
                    modifier_value.Select #Edge edge_bits select:true
                )

                actual_edges = modifier_value.GetSelection #Edge node:scan_node
                selection_ok = this.bitArraysEqual actual_edges edge_bits
                modifier_value.RefreshScreen()
            )
            else
            (
                selection_ok = false
            )
        )
        catch
        (
            fast_edge_selection_exception = getCurrentException()
            selection_ok = false
        )

        if not(selection_ok) then
        (
            last_message = "Could not apply and verify the edge selection."
            return false
        )

        redrawViews()
        last_message = (edge_bits.numberSet as string) + " edges selected."
        true
        -- return
    ),

    /*
    Selects the union of multiple TreeView group/level targets in the user's current component mode.
    Group targets contribute every exact level in that group; level targets contribute only that exact level.
    */
    function selectTargets target_data_array =
    (
        if target_data_array == undefined then
        (
            last_message = "No selection targets were supplied."
            return false
        )
        if not(isKindOf target_data_array Array) then
        (
            last_message = "Selection targets must be supplied as an Array."
            return false
        )
        if target_data_array.count == 0 then
        (
            last_message = "No selection targets were supplied."
            return false
        )
        if not(this.isStoredContextCurrent()) then
        (
            last_message = "Topology changed. Scan the object again."
            return false
        )

        current_subobject_level = this.getCurrentSubObjectLevelSafe()
        if current_subobject_level == undefined then
        (
            last_message = "Could not read the current sub-object level."
            return false
        )
        if current_subobject_level != 2 then current_subobject_level = 1

        combined_vertex_bits = #{}
        combined_edge_bits = #{}

        for target_data in target_data_array do
        (
            if isKindOf target_data Array and target_data.count >= 2 then
            (
                if target_data[1] == #group then
                (
                    group_data = this.getGroupData target_data[2] context_validated:true

                    if group_data != undefined then
                    (
                        for vertex_id in group_data[4] do combined_vertex_bits[vertex_id] = true

                        if current_subobject_level == 2 then
                        (
                            exact_levels = group_data[5]

                            for level_data in exact_levels do
                            (
                                level_edges = this.getEdgesBetweenVertexBits level_data[2] context_validated:true
                                if level_edges == undefined then
                                (
                                    last_message = "Could not read live edge topology."
                                    return false
                                )
                                for edge_id in level_edges do combined_edge_bits[edge_id] = true
                            )
                        )
                    )
                )
                else if target_data[1] == #level and target_data.count >= 3 then
                (
                    level_data = this.getLevelData target_data[2] target_data[3] context_validated:true

                    if level_data != undefined then
                    (
                        for vertex_id in level_data[2] do combined_vertex_bits[vertex_id] = true

                        if current_subobject_level == 2 then
                        (
                            level_edges = this.getEdgesBetweenVertexBits level_data[2] context_validated:true
                            if level_edges == undefined then
                            (
                                last_message = "Could not read live edge topology."
                                return false
                            )
                            for edge_id in level_edges do combined_edge_bits[edge_id] = true
                        )
                    )
                )
            )
        )

        if combined_vertex_bits.numberSet == 0 then
        (
            last_message = "No valid selection targets were resolved."
            return false
        )

        if not(this.unhideVertexBits combined_vertex_bits) then return false

        if current_subobject_level == 2 then
        (
            return this.selectEdgeBits combined_edge_bits
        )

        this.selectVertexBits combined_vertex_bits
        -- return
    ),

    /*
    Selects a multi-target union while preserving an already-active Vertex or Edge editing context.
    This fast CTRL path never unhides geometry and never changes Modify-panel or sub-object state unless fallback is required.
    */
    function selectTargetsFast target_data_array =
    (
        if target_data_array == undefined then
        (
            last_message = "No selection targets were supplied."
            return false
        )
        if not(isKindOf target_data_array Array) then
        (
            last_message = "Selection targets must be supplied as an Array."
            return false
        )
        if target_data_array.count == 0 then
        (
            last_message = "No selection targets were supplied."
            return false
        )
        if not(this.isStoredContextCurrent()) then
        (
            last_message = "Topology changed. Scan the object again."
            return false
        )

        current_subobject_level = this.getCurrentSubObjectLevelSafe()
        if current_subobject_level == undefined then
        (
            last_message = "Could not read the current sub-object level."
            return false
        )

        if current_subobject_level != 1 and current_subobject_level != 2 then
        (
            return this.selectTargets target_data_array
        )

        combined_vertex_bits = #{}
        combined_edge_bits = #{}

        for target_data in target_data_array do
        (
            if isKindOf target_data Array and target_data.count >= 2 then
            (
                if target_data[1] == #group then
                (
                    group_data = this.getGroupData target_data[2] context_validated:true

                    if group_data != undefined then
                    (
                        for vertex_id in group_data[4] do combined_vertex_bits[vertex_id] = true

                        if current_subobject_level == 2 then
                        (
                            exact_levels = group_data[5]

                            for level_data in exact_levels do
                            (
                                level_edges = this.getEdgesBetweenVertexBits level_data[2] context_validated:true
                                if level_edges == undefined then
                                (
                                    last_message = "Could not read live edge topology."
                                    return false
                                )
                                for edge_id in level_edges do combined_edge_bits[edge_id] = true
                            )
                        )
                    )
                )
                else if target_data[1] == #level and target_data.count >= 3 then
                (
                    level_data = this.getLevelData target_data[2] target_data[3] context_validated:true

                    if level_data != undefined then
                    (
                        for vertex_id in level_data[2] do combined_vertex_bits[vertex_id] = true

                        if current_subobject_level == 2 then
                        (
                            level_edges = this.getEdgesBetweenVertexBits level_data[2] context_validated:true
                            if level_edges == undefined then
                            (
                                last_message = "Could not read live edge topology."
                                return false
                            )
                            for edge_id in level_edges do combined_edge_bits[edge_id] = true
                        )
                    )
                )
            )
        )

        if combined_vertex_bits.numberSet == 0 then
        (
            last_message = "No valid selection targets were resolved."
            return false
        )

        if current_subobject_level == 2 then
        (
            return this.selectEdgeBitsFast combined_edge_bits context_validated:true
        )

        this.selectVertexBitsFast combined_vertex_bits context_validated:true
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

        current_subobject_level = this.getCurrentSubObjectLevelSafe()
        if current_subobject_level == undefined then
        (
            last_message = "Could not read the current sub-object level."
            return false
        )

        if not(this.unhideVertexBits group_data[4]) then return false

        if current_subobject_level == 2 then
        (
            group_edges = #{}
            exact_levels = group_data[5]

            for level_data in exact_levels do
            (
                level_edges = this.getEdgesBetweenVertexBits level_data[2] context_validated:true
                if level_edges == undefined then
                (
                    last_message = "Could not read live edge topology."
                    return false
                )

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

        current_subobject_level = this.getCurrentSubObjectLevelSafe()
        if current_subobject_level == undefined then
        (
            last_message = "Could not read the current sub-object level."
            return false
        )

        if not(this.unhideVertexBits level_data[2]) then return false

        if current_subobject_level == 2 then
        (
            level_edges = this.getEdgesBetweenVertexBits level_data[2] context_validated:true
            if level_edges == undefined then
            (
                last_message = "Could not read live edge topology."
                return false
            )
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
