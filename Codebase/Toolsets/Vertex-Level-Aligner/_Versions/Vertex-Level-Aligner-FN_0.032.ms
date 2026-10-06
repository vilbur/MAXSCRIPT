/*
Vertex Level Aligner FN 0.032
Backend-only functional module. Scans Editable Poly / Edit Poly vertex world-Z levels, groups nearby exact levels by threshold, and exposes selection data to the frontend.
*/

global vertex_level_aligner
global EPOLY_TOOLS_RUNTIME_MODE
global vertex_level_aligner_log_path
global vertexLevelAlignerWriteLog
global vertexLevelAlignerStartLog
global vertex_level_aligner_default_threshold

if vertex_level_aligner_default_threshold == undefined then
(
    vertex_level_aligner_default_threshold = try(units.decodeValue "1mm")catch(1.0)
)

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

    format "000 START Vertex Level Aligner project 0.782\n" to:log_stream
    close log_stream
    true
    -- return
)

struct vertex_level_aligner_v
(
    file_version = 0.032,
    project_version = 0.782,
    scan_node = undefined,
    scan_modifier = undefined,
    scan_kind = #none,
    scan_vertex_count = 0,
    threshold_value = vertex_level_aligner_default_threshold,
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

        vertex_position * node_value.transform
        -- return
    ),

    /*
    Compares two #(z, vertex_id) samples for qsort.
    Z is primary and vertex ID is a deterministic tie-breaker.
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
    Collects and sorts live world-Z samples for every vertex in one context.
    Each sample stores #(world_z, vertex_id).
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
                append sample_values #(world_position.z, vertex_id)
            )
        )

        qsort sample_values this.compareVertexSamples
        sample_values
        -- return
    ),

    /*
    Collapses numerically identical Z samples into exact level entries.
    Each level entry is #(z_value, vertex_bits).
    */
    function buildExactLevels sample_values =
    (
        exact_levels = #()
        current_level = undefined

        for sample_value in sample_values do
        (
            sample_z = sample_value[1]
            vertex_id = sample_value[2]

            if current_level == undefined then
            (
                current_bits = #{}
                current_bits[vertex_id] = true
                current_level = #(sample_z, current_bits)
                append exact_levels current_level
            )
            else
            (
                if abs(sample_z - current_level[1]) <= exact_epsilon then
                (
                    current_level[2][vertex_id] = true
                )
                else
                (
                    current_bits = #{}
                    current_bits[vertex_id] = true
                    current_level = #(sample_z, current_bits)
                    append exact_levels current_level
                )
            )
        )

        exact_levels
        -- return
    ),

    /*
    Builds one threshold group from an ordered array of exact level entries.
    Group data is #(center_z, min_z, max_z, vertex_bits, exact_levels, is_broken).
    */
    function buildGroupData exact_levels =
    (
        if exact_levels == undefined or exact_levels.count == 0 then return undefined

        group_bits = #{}
        min_z = exact_levels[1][1]
        max_z = exact_levels[exact_levels.count][1]

        for level_entry in exact_levels do
        (
            level_bits = level_entry[2]

            for vertex_id in level_bits do
            (
                group_bits[vertex_id] = true
            )
        )

        center_z = (min_z + max_z) * 0.5
        is_broken = exact_levels.count > 1

        #(center_z, min_z, max_z, group_bits, exact_levels, is_broken)
        -- return
    ),

    /*
    Groups exact Z levels inside a symmetric threshold window.
    One cluster may span at most 2 * threshold so values at center +/- threshold remain together.
    */
    function buildThresholdGroups exact_levels threshold:1.0 =
    (
        group_values = #()
        if exact_levels == undefined or exact_levels.count == 0 then return group_values

        threshold_limit = threshold
        if threshold_limit < 0.0 then threshold_limit = 0.0
        maximum_span = threshold_limit * 2.0
        current_levels = #()
        current_min_z = undefined

        for level_entry in exact_levels do
        (
            level_z = level_entry[1]

            if current_levels.count == 0 then
            (
                current_levels = #(level_entry)
                current_min_z = level_z
            )
            else
            (
                if (level_z - current_min_z) <= (maximum_span + exact_epsilon) then
                (
                    append current_levels level_entry
                )
                else
                (
                    group_data = this.buildGroupData current_levels
                    if group_data != undefined then append group_values group_data
                    current_levels = #(level_entry)
                    current_min_z = level_z
                )
            )
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
    function scanNode node_value modifier_value:undefined threshold:1.0 =
    (
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
        exact_levels = this.buildExactLevels sample_values
        level_groups = this.buildThresholdGroups exact_levels threshold:threshold_value

        scan_node = context_data[2]
        scan_kind = context_kind
        scan_modifier = if context_kind == #edit_poly then context_data[3] else undefined
        scan_vertex_count = this.getContextVertexCount context_data

        broken_count = this.getBrokenGroupCount()
        last_message = (level_groups.count as string) + " groups | " + (broken_count as string) + " broken | " + (sample_values.count as string) + " verts"

        true
        -- return
    ),

    /*
    Scans exactly one currently selected scene node.
    The stored threshold value is used when no explicit threshold is supplied by the UI.
    */
    function scanSelection threshold:undefined =
    (
        vertexLevelAlignerWriteLog "400 SCAN selection entered"
        selected_nodes = selection as array
        vertexLevelAlignerWriteLog ("401 SCAN selected node count = " + (selected_nodes.count as string))

        if selected_nodes.count != 1 then
        (
            last_message = "Select exactly one Editable Poly or Edit Poly object."
            return false
        )

        threshold_to_use = threshold_value
        if threshold != undefined then threshold_to_use = threshold

        scan_ok = this.scanNode selected_nodes[1] threshold:threshold_to_use
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
    Returns the world-Z target for one group alignment mode.
    TOP uses max Z, MIDDLE uses the group center, and BOTTOM uses min Z.
    */
    function getAlignmentTargetZ group_data alignment_mode =
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
    Returns a readable alignment mode label for status text.
    */
    function getAlignmentModeText alignment_mode =
    (
        case alignment_mode of
        (
            #top: "TOP"
            #middle: "MIDDLE"
            #bottom: "BOTTOM"
            default: "UNKNOWN"
        )
        -- return
    ),

    /*
    Moves Editable Poly vertices by one world-Z delta while preserving arbitrary node transforms.
    */
    function moveEditablePolyVertexBitsByWorldZDelta vertex_bits delta_world_z =
    (
        if scan_node == undefined or not(isValidNode scan_node) then return false
        if classOf scan_node.baseObject != Editable_Poly then return false

        topology_value = scan_node.baseObject
        try(topology_value.showCage = off)catch()

        inverse_transform = inverse scan_node.transform
        local_origin = [0,0,0] * inverse_transform
        local_target = [0,0,delta_world_z] * inverse_transform
        local_delta = local_target - local_origin

        polyop.moveVert topology_value vertex_bits local_delta
        update scan_node
        true
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
    Moves one Edit Poly vertex set by a world-Z delta using the EditPolyMod transform API.
    */
    function moveEditPolyVertexBitsByWorldZDelta vertex_bits delta_world_z =
    (
        if not(this.prepareEditPolyVertexSelection vertex_bits) then return false

        modifier_value = scan_modifier
        move_amount = [0,0,delta_world_z]

        if abs(delta_world_z) > exact_epsilon then
        (
            modifier_value.MoveSelection move_amount
            modifier_value.Commit()
        )

        modifier_value.RefreshScreen()
        true
        -- return
    ),

    /*
    Moves a stored vertex set by one world-Z delta on the scanned topology.
    */
    function moveVertexBitsByWorldZDelta vertex_bits delta_world_z =
    (
        if vertex_bits == undefined or vertex_bits.numberSet == 0 then return false
        if not(this.isStoredContextCurrent()) then return false

        if scan_kind == #editable_poly then
        (
            return this.moveEditablePolyVertexBitsByWorldZDelta vertex_bits delta_world_z
        )

        if scan_kind == #edit_poly then
        (
            return this.moveEditPolyVertexBitsByWorldZDelta vertex_bits delta_world_z
        )

        false
        -- return
    ),

    /*
    Aligns one or more stored exact levels to one world-Z target and refreshes the stored scan.
    */
    function alignExactLevels exact_levels target_z alignment_mode =
    (
        if exact_levels == undefined or exact_levels.count == 0 then return false
        if target_z == undefined then return false
        if not(this.isStoredContextCurrent()) then
        (
            last_message = "Topology changed. Scan the object again."
            return false
        )

        aligned_bits = #{}
        target_node = scan_node
        target_modifier = scan_modifier
        target_threshold = threshold_value

        for level_data in exact_levels do
        (
            level_z = level_data[1]
            level_bits = level_data[2]
            delta_world_z = target_z - level_z

            if not(this.moveVertexBitsByWorldZDelta level_bits delta_world_z) then
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

        if not(this.scanNode target_node modifier_value:target_modifier threshold:target_threshold) then
        (
            return false
        )

        scan_message = last_message
        this.selectVertexBits aligned_bits
        last_message = (aligned_bits.numberSet as string) + " vertices aligned " + (this.getAlignmentModeText alignment_mode) + " | " + scan_message
        true
        -- return
    ),

    /*
    Aligns every exact level in one threshold group to TOP, MIDDLE, or BOTTOM.
    */
    function alignGroup group_index alignment_mode =
    (
        group_data = this.getGroupData group_index
        if group_data == undefined then return false

        target_z = this.getAlignmentTargetZ group_data alignment_mode
        this.alignExactLevels group_data[5] target_z alignment_mode
        -- return
    ),

    /*
    Aligns one exact child level to the parent group's TOP, MIDDLE, or BOTTOM target.
    */
    function alignLevel group_index level_index alignment_mode =
    (
        group_data = this.getGroupData group_index
        if group_data == undefined then return false

        level_data = this.getLevelData group_index level_index
        if level_data == undefined then return false

        target_z = this.getAlignmentTargetZ group_data alignment_mode
        this.alignExactLevels #(level_data) target_z alignment_mode
        -- return
    ),

    /*
    Selects every vertex stored in one threshold group.
    This is used when a parent TreeView node is selected.
    */
    function selectGroup group_index =
    (
        group_data = this.getGroupData group_index
        if group_data == undefined then return false

        this.selectVertexBits group_data[4]
        -- return
    ),

    /*
    Selects vertices at one exact Z value inside one threshold group.
    This is used when a child TreeView node is selected.
    */
    function selectLevel group_index level_index =
    (
        level_data = this.getLevelData group_index level_index
        if level_data == undefined then return false

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
