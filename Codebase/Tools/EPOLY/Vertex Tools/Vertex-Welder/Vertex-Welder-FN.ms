/*
    Vertex Welder FN 0.015
    Backend-only geometry and Tool coordination for Editable Poly and Edit Poly welding.
*/

global VertexWelder
global vertex_welder_project_version
global vertex_welder_fn_file_version = 0.015
global vertex_welder_fn_stored_project_version = 0.017

if vertex_welder_project_version == undefined or vertex_welder_project_version < vertex_welder_fn_stored_project_version then
(
    vertex_welder_project_version = vertex_welder_fn_stored_project_version
)

struct VertexWelder_v
(
    file_version = 0.015,
    project_version = 0.017,
    last_message = "Ready.",
    test_node = undefined,
    test_mode = #weld,

    /*
    Stores one status message and optionally prints the same text to the Listener.
    Returns the supplied text.
    */
    function setMessage message_text print_message:false =
    (
        last_message = message_text

        if print_message then
        (
            format "Vertex Welder | %\n" message_text
        )

        message_text
        -- return
    ),

    /*
    Converts the user threshold from millimeters to current 3ds Max system units.
    No rounding or additional tolerance is applied.
    */
    function thresholdMmToSystemUnits threshold_mm =
    (
        threshold_mm * (units.decodeValue "1mm")
        -- return
    ),

    /*
    Returns true when the supplied Edit Poly modifier belongs to the supplied node.
    */
    function modifierBelongsToNode node_v edit_poly_mod =
    (
        if not isValidNode node_v then return false
        if edit_poly_mod == undefined or classOf edit_poly_mod != Edit_Poly then return false

        for stack_mod in node_v.modifiers do
        (
            if stack_mod == edit_poly_mod then return true
        )

        false
        -- return
    ),

    /*
    Returns the highest Edit Poly modifier on one node, or undefined when none exists.
    */
    function getHighestEditPolyModifier node_v =
    (
        if not isValidNode node_v then return undefined

        for modifier_index = node_v.modifiers.count to 1 by -1 do
        (
            stack_mod = node_v.modifiers[modifier_index]

            if classOf stack_mod == Edit_Poly then return stack_mod
        )

        undefined
        -- return
    ),

    /*
    Resolves one supported topology target as #(kind, node, topology_value).
    Active Edit Poly wins, then highest Edit Poly, then an Editable Poly base object.
    */
    function getTargetFromNode node_v prefer_active:true =
    (
        if not isValidNode node_v then return undefined

        edit_poly_mod = undefined

        if prefer_active then
        (
            active_stack_value = modPanel.getCurrentObject()

            if classOf active_stack_value == Edit_Poly and this.modifierBelongsToNode node_v active_stack_value then
            (
                edit_poly_mod = active_stack_value
            )
        )

        if edit_poly_mod == undefined then
        (
            edit_poly_mod = this.getHighestEditPolyModifier node_v
        )

        if edit_poly_mod != undefined then
        (
            edit_poly_mod.showCage = off
            return #(#edit_poly, node_v, edit_poly_mod)
        )

        if classOf node_v.baseObject == Editable_Poly then
        (
            node_v.baseObject.showCage = off
            return #(#editable_poly, node_v, node_v.baseObject)
        )

        undefined
        -- return
    ),

    /*
    Resolves exactly one selected Editable Poly or Edit Poly target.
    */
    function getSelectedTarget =
    (
        if selection.count != 1 then
        (
            this.setMessage "Select exactly one Editable Poly / Edit Poly object."
            return undefined
        )

        target_data = this.getTargetFromNode selection[1]

        if target_data == undefined then
        (
            this.setMessage "The selected object has no supported Editable Poly or Edit Poly target."
        )

        target_data
        -- return
    ),

    /*
    Synchronizes one Editable Poly topology before an ID-sensitive analysis phase.
    Returns false for unsupported targets and true after topology is safe to read.
    */
    function ensureCleanEditablePolyTopology target_data =
    (
        if target_data == undefined or target_data[1] != #editable_poly then return false

        poly_value = target_data[3]

        if polyop.getHasDeadStructs poly_value != 0 then
        (
            polyop.collapseDeadStructs poly_value
        )

        polyop.getHasDeadStructs poly_value == 0
        -- return
    ),

    /*
    Prepares an Editable Poly target for a new topology-ID analysis phase.
    Edit Poly does not use base-object dead-topology compaction.
    */
    function prepareTopologyPhase target_data =
    (
        if target_data == undefined then return false

        if target_data[1] == #editable_poly then
        (
            return this.ensureCleanEditablePolyTopology target_data
        )

        if target_data[1] == #edit_poly then return true

        false
        -- return
    ),

    /*
    Returns the current live vertex count for one supported target.
    */
    function getVertexCount target_data =
    (
        if target_data == undefined then return -1

        target_kind = target_data[1]
        node_v = target_data[2]
        topology_value = target_data[3]

        if target_kind == #editable_poly then return polyop.getNumVerts topology_value
        if target_kind == #edit_poly then return topology_value.GetNumVertices node:node_v

        -1
        -- return
    ),

    /*
    Returns the current live edge count for one supported target.
    */
    function getEdgeCount target_data =
    (
        if target_data == undefined then return -1

        target_kind = target_data[1]
        node_v = target_data[2]
        topology_value = target_data[3]

        if target_kind == #editable_poly then return polyop.getNumEdges topology_value
        if target_kind == #edit_poly then return topology_value.GetNumEdges node:node_v

        -1
        -- return
    ),

    /*
    Returns one vertex position in world space for one supported target.
    Editable Poly local points are transformed once; node-scoped Edit Poly GetVertex values are already world-space in the verified translated-node path.
    */
    function getVertexWorldPosition target_data vertex_id =
    (
        if target_data == undefined or vertex_id <= 0 then return undefined

        target_kind = target_data[1]
        node_v = target_data[2]
        topology_value = target_data[3]

        if target_kind == #editable_poly then
        (
            local_position = polyop.getVert topology_value vertex_id
            if local_position == undefined then return undefined
            return local_position * node_v.objectTransform
        )

        if target_kind == #edit_poly then
        (
            return topology_value.GetVertex vertex_id node:node_v
        )

        undefined
        -- return
    ),

    /*
    Returns the two endpoint vertex IDs of one current topology edge.
    The result is always an Array or undefined on invalid input.
    */
    function getEdgeVertexIds target_data edge_id =
    (
        if target_data == undefined or edge_id <= 0 then return undefined

        target_kind = target_data[1]
        node_v = target_data[2]
        topology_value = target_data[3]

        if target_kind == #editable_poly then
        (
            endpoint_value = polyop.getEdgeVerts topology_value edge_id
            if endpoint_value == undefined then return undefined
            return #(endpoint_value[1], endpoint_value[2])
        )

        if target_kind == #edit_poly then
        (
            vertex_a = topology_value.GetEdgeVertex edge_id 1 node:node_v
            vertex_b = topology_value.GetEdgeVertex edge_id 2 node:node_v

            if vertex_a == undefined or vertex_b == undefined then return undefined
            if vertex_a <= 0 or vertex_b <= 0 then return undefined
            return #(vertex_a, vertex_b)
        )

        undefined
        -- return
    ),

    /*
    Returns current positive face IDs using one edge.
    The result is always an Array.
    */
    function getEdgeFaceIds target_data edge_id =
    (
        face_ids = #()
        if target_data == undefined or edge_id <= 0 then return face_ids

        target_kind = target_data[1]
        node_v = target_data[2]
        topology_value = target_data[3]

        if target_kind == #editable_poly then
        (
            face_bits = polyop.getFacesUsingEdge topology_value edge_id

            for face_id in face_bits do append face_ids face_id
        )
        else if target_kind == #edit_poly then
        (
            face_a = topology_value.GetEdgeFace edge_id 1 node:node_v
            face_b = topology_value.GetEdgeFace edge_id 2 node:node_v

            if face_a != undefined and face_a > 0 then append face_ids face_a
            if face_b != undefined and face_b > 0 and face_b != face_a then append face_ids face_b
        )

        face_ids
        -- return
    ),

    /*
    Returns the current live face count for one supported target.
    Face IDs are preserved across normal border-vertex stitches and anchor the original source-side map.
    */
    function getFaceCount target_data =
    (
        if target_data == undefined then return -1

        target_kind = target_data[1]
        node_v = target_data[2]
        topology_value = target_data[3]

        if target_kind == #editable_poly then return polyop.getNumFaces topology_value
        if target_kind == #edit_poly then return topology_value.GetNumFaces node:node_v

        -1
        -- return
    ),

    /*
    Returns ordered vertex IDs used by one polygon face.
    The result is always an Array.
    */
    function getFaceVertexIds target_data face_id =
    (
        vertex_ids = #()
        if target_data == undefined or face_id <= 0 then return vertex_ids

        target_kind = target_data[1]
        node_v = target_data[2]
        topology_value = target_data[3]

        if target_kind == #editable_poly then
        (
            face_vertices = polyop.getFaceVerts topology_value face_id

            if face_vertices != undefined then
            (
                for vertex_id in face_vertices do append vertex_ids vertex_id
            )
        )
        else if target_kind == #edit_poly then
        (
            face_degree = topology_value.GetFaceDegree face_id node:node_v

            if face_degree != undefined and face_degree > 0 then
            (
                for corner_index = 1 to face_degree do
                (
                    append vertex_ids (topology_value.GetFaceVertex face_id corner_index node:node_v)
                )
            )
        )

        vertex_ids
        -- return
    ),

    /*
    Builds current open-edge records as #(edge_id, vertex_a, vertex_b, adjacent_face_id).
    The result is always an Array.
    */
    function getOpenEdgeRecords target_data =
    (
        open_records = #()
        if target_data == undefined then return open_records

        edge_count = this.getEdgeCount target_data

        if edge_count <= 0 then return open_records

        for edge_id = 1 to edge_count do
        (
            face_ids = this.getEdgeFaceIds target_data edge_id

            if face_ids.count == 1 then
            (
                endpoint_ids = this.getEdgeVertexIds target_data edge_id

                if endpoint_ids != undefined then
                (
                    append open_records #(edge_id, endpoint_ids[1], endpoint_ids[2], face_ids[1])
                )
            )
        )

        open_records
        -- return
    ),

    /*
    Builds a polygon-element ID for every current face using shared-edge connectivity.
    Faces that touch only at one vertex remain separate elements, matching Editable Poly element semantics.
    */
    function buildElementMap target_data =
    (
        element_ids = #()
        if target_data == undefined then return element_ids

        face_count = this.getFaceCount target_data
        edge_count = this.getEdgeCount target_data

        if face_count <= 0 then return element_ids

        element_ids.count = face_count
        face_adjacency = for face_id = 1 to face_count collect #()

        if edge_count > 0 then
        (
            for edge_id = 1 to edge_count do
            (
                face_ids = this.getEdgeFaceIds target_data edge_id

                if face_ids.count > 1 then
                (
                    for first_face_index = 1 to (face_ids.count - 1) do
                    (
                        face_a = face_ids[first_face_index]

                        if face_a > 0 and face_a <= face_count then
                        (
                            for second_face_index = (first_face_index + 1) to face_ids.count do
                            (
                                face_b = face_ids[second_face_index]

                                if face_b > 0 and face_b <= face_count and face_a != face_b then
                                (
                                    if findItem face_adjacency[face_a] face_b == 0 then append face_adjacency[face_a] face_b
                                    if findItem face_adjacency[face_b] face_a == 0 then append face_adjacency[face_b] face_a
                                )
                            )
                        )
                    )
                )
            )
        )

        element_id = 0

        for start_face = 1 to face_count do
        (
            if element_ids[start_face] == undefined then
            (
                element_id += 1
                queue_faces = #(start_face)
                element_ids[start_face] = element_id
                queue_index = 1

                while queue_index <= queue_faces.count do
                (
                    active_face = queue_faces[queue_index]
                    queue_index += 1

                    for neighbor_face in face_adjacency[active_face] do
                    (
                        if element_ids[neighbor_face] == undefined then
                        (
                            element_ids[neighbor_face] = element_id
                            append queue_faces neighbor_face
                        )
                    )
                )
            )
        )

        element_ids
        -- return
    ),

    /*
    Builds the set of face-connected element IDs touching every current vertex.
    A point-only junction can therefore belong to more than one polygon element without merging those elements.
    */
    function buildVertexElementMembership target_data element_ids =
    (
        vertex_memberships = #()
        if target_data == undefined or element_ids == undefined or element_ids.count == 0 then return vertex_memberships

        vertex_count = this.getVertexCount target_data
        face_count = this.getFaceCount target_data

        if vertex_count <= 0 or face_count <= 0 or element_ids.count != face_count then return vertex_memberships

        vertex_memberships = for vertex_id = 1 to vertex_count collect #()

        for face_id = 1 to face_count do
        (
            element_id = element_ids[face_id]
            face_vertex_ids = this.getFaceVertexIds target_data face_id

            if element_id != undefined and element_id > 0 then
            (
                for vertex_id in face_vertex_ids do
                (
                    if vertex_id > 0 and vertex_id <= vertex_count then
                    (
                        if findItem vertex_memberships[vertex_id] element_id == 0 then
                        (
                            append vertex_memberships[vertex_id] element_id
                        )
                    )
                )
            )
        )

        vertex_memberships
        -- return
    ),

    /*
    Returns true when two current vertices touch at least one common face-connected polygon element.
    Shared point junctions can carry multiple memberships without changing the element count.
    */
    function verticesShareElement vertex_memberships vertex_a vertex_b =
    (
        if vertex_memberships == undefined or vertex_memberships.count == 0 then return false
        if vertex_a <= 0 or vertex_b <= 0 then return false
        if vertex_a > vertex_memberships.count or vertex_b > vertex_memberships.count then return false

        memberships_a = vertex_memberships[vertex_a]
        memberships_b = vertex_memberships[vertex_b]

        if memberships_a == undefined or memberships_b == undefined then return false

        for element_id in memberships_a do
        (
            if findItem memberships_b element_id > 0 then return true
        )

        false
        -- return
    ),

    /*
    Returns the number of connected elements represented by one element-ID map.
    */
    function getElementCountFromMap element_ids =
    (
        if element_ids == undefined or element_ids.count == 0 then return 0

        element_count = 0

        for element_id in element_ids do
        (
            if element_id != undefined and element_id > element_count then element_count = element_id
        )

        element_count
        -- return
    ),

    /*
    Returns the current connected-element count for one target.
    */
    function getElementCount target_data =
    (
        if not(this.prepareTopologyPhase target_data) then return 0

        element_ids = this.buildElementMap target_data
        this.getElementCountFromMap element_ids
        -- return
    ),

    /*
    Captures the original face-connected polygon-element identity of every current face.
    BORDERS keeps this map unchanged so later seam runs remain eligible after an earlier run joins the live elements.
    */
    function buildFaceGroupMap target_data =
    (
        face_group_ids = #()
        if target_data == undefined then return face_group_ids

        element_ids = this.buildElementMap target_data
        face_count = this.getFaceCount target_data

        if face_count <= 0 or element_ids.count != face_count then return face_group_ids

        face_group_ids = for face_id = 1 to face_count collect element_ids[face_id]

        face_group_ids
        -- return
    ),

    /*
    Converts current open-edge records into a unique ascending array of border vertex IDs.
    */
    function getBorderVertexIds open_records =
    (
        border_bits = #{}

        for edge_record in open_records do
        (
            border_bits[edge_record[2]] = true
            border_bits[edge_record[3]] = true
        )

        border_vertices = #()
        for vertex_id in border_bits do append border_vertices vertex_id

        border_vertices
        -- return
    ),

    /*
    Returns a deterministic key string for one unordered vertex pair.
    */
    function getVertexPairKey vertex_a vertex_b =
    (
        lower_id = vertex_a
        higher_id = vertex_b

        if lower_id > higher_id then
        (
            swap_id = lower_id
            lower_id = higher_id
            higher_id = swap_id
        )

        (lower_id as string) + ":" + (higher_id as string)
        -- return
    ),

    /*
    Finds the closest current border-vertex pair inside the explicit threshold.
    PER ELEMENT additionally requires the two vertices to share at least one face-connected element membership.
    */
    function findClosestPair target_data threshold_value per_element:false blocked_keys:#() =
    (
        open_records = this.getOpenEdgeRecords target_data
        border_vertices = this.getBorderVertexIds open_records

        if border_vertices.count < 2 then return undefined

        element_ids = #()
        vertex_memberships = #()

        if per_element then
        (
            element_ids = this.buildElementMap target_data
            if element_ids.count == 0 then return undefined

            vertex_memberships = this.buildVertexElementMembership target_data element_ids
            if vertex_memberships.count == 0 then return undefined
        )

        best_pair = undefined
        best_distance = undefined

        for first_index = 1 to (border_vertices.count - 1) do
        (
            vertex_a = border_vertices[first_index]
            position_a = this.getVertexWorldPosition target_data vertex_a

            if position_a != undefined then
            (
                for second_index = (first_index + 1) to border_vertices.count do
                (
                    vertex_b = border_vertices[second_index]
                    pair_key = this.getVertexPairKey vertex_a vertex_b

                    if findItem blocked_keys pair_key == 0 then
                    (
                        element_ok = true

                        if per_element then
                        (
                            element_ok = this.verticesShareElement vertex_memberships vertex_a vertex_b
                        )

                        if element_ok then
                        (
                            position_b = this.getVertexWorldPosition target_data vertex_b

                            if position_b != undefined then
                            (
                                pair_distance = distance position_a position_b

                                if pair_distance <= threshold_value then
                                (
                                    if best_distance == undefined or pair_distance < best_distance then
                                    (
                                        best_distance = pair_distance
                                        best_pair = #(vertex_a, vertex_b, pair_distance, (position_a + position_b) / 2.0)
                                    )
                                )
                            )
                        )
                    )
                )
            )
        )

        best_pair
        -- return
    ),

    /*
    Prepares one Edit Poly modifier for deterministic local vertex selection.
    */
    function prepareEditPolyVertexContext target_data =
    (
        if target_data == undefined or target_data[1] != #edit_poly then return false

        node_v = target_data[2]
        edit_poly_mod = target_data[3]

        if not(this.modifierBelongsToNode node_v edit_poly_mod) then return false

        select node_v
        max modify mode
        edit_poly_mod.SetPrimaryNode node_v
        edit_poly_mod.useStackSelection = false
        edit_poly_mod.selectMode = 0
        edit_poly_mod.showCage = off
        modPanel.setCurrentObject edit_poly_mod node:node_v
        edit_poly_mod.SetEPolySelLevel #Vertex
        subObjectLevel = 1

        true
        -- return
    ),

    /*
    Replaces the current Edit Poly vertex selection with one supplied BitArray.
    A failed selection read/write is reported as false rather than an empty success.
    */
    function setEditPolyVertexSelection target_data vertex_bits =
    (
        if not(this.prepareEditPolyVertexContext target_data) then return false

        node_v = target_data[2]
        edit_poly_mod = target_data[3]
        old_vertices = edit_poly_mod.GetSelection #Vertex node:node_v

        if old_vertices == undefined then return false

        if old_vertices.numberSet > 0 then
        (
            edit_poly_mod.Select #Vertex old_vertices select:false node:node_v
        )

        if vertex_bits.numberSet > 0 then
        (
            edit_poly_mod.Select #Vertex vertex_bits select:true node:node_v
        )

        stored_vertices = edit_poly_mod.GetSelection #Vertex node:node_v
        if stored_vertices == undefined then return false

        stored_vertices == vertex_bits
        -- return
    ),

    /*
    Moves one Edit Poly vertex from its current world position to an exact world target.
    */
    function moveEditPolyVertexToWorldPosition target_data vertex_id target_world =
    (
        if target_data == undefined or target_data[1] != #edit_poly then return false

        node_v = target_data[2]
        edit_poly_mod = target_data[3]
        current_world = this.getVertexWorldPosition target_data vertex_id

        if current_world == undefined then return false
        if not(this.setEditPolyVertexSelection target_data #{vertex_id}) then return false

        move_delta = target_world - current_world

        if move_delta != [0,0,0] then
        (
            edit_poly_mod.MoveSelection move_delta
            edit_poly_mod.Commit()
            edit_poly_mod.RefreshScreen()
            update node_v
        )

        moved_world = this.getVertexWorldPosition target_data vertex_id
        if moved_world == undefined then return false

        if moved_world != target_world then
        (
            if this.setEditPolyVertexSelection target_data #{vertex_id} then
            (
                restore_delta = current_world - moved_world

                if restore_delta != [0,0,0] then
                (
                    edit_poly_mod.MoveSelection restore_delta
                    edit_poly_mod.Commit()
                    edit_poly_mod.RefreshScreen()
                    update node_v
                )
            )

            return false
        )

        true
        -- return
    ),

    /*
    Welds one current vertex pair to an explicit world-space target and verifies one removed vertex.
    The higher ID is always used as the source and the lower ID as destination.
    */
    function weldPairAtWorldPosition target_data vertex_a vertex_b target_world =
    (
        if target_data == undefined or target_world == undefined then return false
        if vertex_a <= 0 or vertex_b <= 0 or vertex_a == vertex_b then return false

        source_id = vertex_a
        target_id = vertex_b

        if source_id < target_id then
        (
            swap_id = source_id
            source_id = target_id
            target_id = swap_id
        )

        before_count = this.getVertexCount target_data
        if before_count <= 0 or source_id > before_count or target_id > before_count then return false

        target_kind = target_data[1]
        node_v = target_data[2]
        topology_value = target_data[3]

        if target_kind == #editable_poly then
        (
            polyop.weldVerts topology_value target_id source_id target_world node:node_v
            update node_v

            if not(this.ensureCleanEditablePolyTopology target_data) then return false

            after_count = this.getVertexCount target_data
            return after_count == (before_count - 1)
        )

        if target_kind == #edit_poly then
        (
            source_world = this.getVertexWorldPosition target_data source_id
            destination_world = this.getVertexWorldPosition target_data target_id

            if source_world == undefined or destination_world == undefined then return false
            if not(this.prepareEditPolyVertexContext target_data) then return false

            /*
            Follow the verified Edit Poly target-weld sequence: move only the disposable source onto
            the surviving target, weld target/source, then move the surviving target to the requested point.
            */
            if not(this.moveEditPolyVertexToWorldPosition target_data source_id destination_world) then return false

            pre_weld_count = this.getVertexCount target_data

            if pre_weld_count != before_count then
            (
                this.moveEditPolyVertexToWorldPosition target_data source_id source_world
                this.setMessage ("Edit Poly source move changed the live vertex count unexpectedly: " + (before_count as string) + " -> " + (pre_weld_count as string) + ".")
                return false
            )

            EditPolyMod.WeldVertices topology_value target_id source_id node:node_v
            EditPolyMod.Commit topology_value
            topology_value.RefreshScreen()
            update node_v

            if not(this.prepareEditPolyVertexContext target_data) then
            (
                this.setMessage "Edit Poly weld completed but the modifier context could not be rebound for verification."
                return false
            )

            after_count = this.getVertexCount target_data

            if after_count == (before_count - 1) then
            (
                if not(this.moveEditPolyVertexToWorldPosition target_data target_id target_world) then
                (
                    this.setMessage "Edit Poly weld succeeded but the surviving vertex could not be moved to the requested weld target."
                    return false
                )

                final_count = this.getVertexCount target_data

                if final_count != after_count then
                (
                    this.setMessage ("Edit Poly post-weld target move changed the live vertex count unexpectedly: " + (after_count as string) + " -> " + (final_count as string) + ".")
                    return false
                )

                return true
            )

            if after_count == before_count then
            (
                restore_source_ok = this.moveEditPolyVertexToWorldPosition target_data source_id source_world

                if not restore_source_ok then
                (
                    this.setMessage "Edit Poly weld failed and the disposable source vertex could not be restored."
                )

                return false
            )

            this.setMessage ("Edit Poly weld left an unexpected vertex count: " + (before_count as string) + " -> " + (after_count as string) + " | survivor:" + (target_id as string) + " | disposable:" + (source_id as string) + ".")
            return false
        )

        false
        -- return
    ),

    /*
    Runs normal or per-element closest-pair welding until no eligible pair remains.
    Returns the verified weld count, or -1 on an incomplete destructive failure.
    */
    function weldClosestPairs target_data threshold_value per_element:false debug:false =
    (
        if target_data == undefined then
        (
            this.setMessage "No valid target."
            return -1
        )

        if threshold_value < 0.0 then
        (
            this.setMessage "Threshold cannot be negative."
            return -1
        )

        welded_count = 0
        blocked_keys = #()
        keep_searching = true

        while keep_searching do
        (
            if not(this.prepareTopologyPhase target_data) then
            (
                this.setMessage "Topology synchronization failed."
                return -1
            )

            pair_data = this.findClosestPair target_data threshold_value per_element:per_element blocked_keys:blocked_keys

            if pair_data == undefined then
            (
                keep_searching = false
            )
            else
            (
                vertex_a = pair_data[1]
                vertex_b = pair_data[2]
                pair_distance = pair_data[3]
                target_world = pair_data[4]

                if debug then
                (
                    format "Vertex Welder DEBUG | candidate:% <-> % | distance:% | target:%\n" vertex_a vertex_b pair_distance target_world
                )

                pair_before_count = this.getVertexCount target_data

                if this.weldPairAtWorldPosition target_data vertex_a vertex_b target_world then
                (
                    welded_count += 1
                    blocked_keys = #()

                    if debug then format "Vertex Welder DEBUG | welded pair:% <-> %\n" vertex_a vertex_b
                )
                else
                (
                    pair_after_count = this.getVertexCount target_data

                    if pair_after_count != pair_before_count then
                    (
                        this.setMessage ("Weld failed after the live vertex count changed unexpectedly: " + (pair_before_count as string) + " -> " + (pair_after_count as string) + ".")
                        return -1
                    )

                    pair_key = this.getVertexPairKey vertex_a vertex_b
                    append blocked_keys pair_key

                    if debug then format "Vertex Welder DEBUG | native weld rejected pair:% <-> %\n" vertex_a vertex_b
                )
            )
        )

        mode_text = if per_element then "PER ELEMENT" else "WELD"
        this.setMessage (mode_text + " complete. Welded pairs: " + (welded_count as string) + ".")
        welded_count
        -- return
    ),

    /*
    Calculates one world-space face plane as #(unit_normal, dot_offset).
    Newell's polygon normal is used so n-gons do not depend on one arbitrary triangle.
    */
    function getFaceWorldPlane target_data face_id =
    (
        vertex_ids = this.getFaceVertexIds target_data face_id
        if vertex_ids.count < 3 then return undefined

        positions = #()

        for vertex_id in vertex_ids do
        (
            world_position = this.getVertexWorldPosition target_data vertex_id
            if world_position == undefined then return undefined
            append positions world_position
        )

        normal_sum = [0,0,0]

        for point_index = 1 to positions.count do
        (
            next_index = point_index + 1
            if next_index > positions.count then next_index = 1

            point_a = positions[point_index]
            point_b = positions[next_index]

            normal_sum.x += (point_a.y - point_b.y) * (point_a.z + point_b.z)
            normal_sum.y += (point_a.z - point_b.z) * (point_a.x + point_b.x)
            normal_sum.z += (point_a.x - point_b.x) * (point_a.y + point_b.y)
        )

        if (length normal_sum) == 0.0 then return undefined

        face_normal = normalize normal_sum
        plane_offset = dot face_normal positions[1]

        #(face_normal, plane_offset)
        -- return
    ),

    /*
    Projects a reference point onto the unique intersection line of two planes.
    Exactly parallel planes use the reference point as the explicit midpoint fallback.
    */
    function getPlaneIntersectionTarget plane_a plane_b reference_point =
    (
        if plane_a == undefined or plane_b == undefined or reference_point == undefined then return undefined

        normal_a = plane_a[1]
        offset_a = plane_a[2]
        normal_b = plane_b[1]
        offset_b = plane_b[2]
        line_direction = cross normal_a normal_b
        line_length_squared = dot line_direction line_direction

        if line_length_squared == 0.0 then return reference_point

        line_point = (((cross normal_b line_direction) * offset_a) + ((cross line_direction normal_a) * offset_b)) / line_length_squared
        line_parameter = (dot (reference_point - line_point) line_direction) / line_length_squared

        line_point + (line_direction * line_parameter)
        -- return
    ),

    /*
    Returns the single adjacent face ID of one open edge, or zero when it is not open.
    */
    function getOpenEdgeFaceId target_data edge_id =
    (
        face_ids = this.getEdgeFaceIds target_data edge_id
        if face_ids.count == 1 then face_ids[1] else 0
        -- return
    ),

    /*
    Computes one BORDERS weld target from the two adjacent face planes.
    The result must remain inside the explicit user threshold from both vertices.
    */
    function getBorderPairTarget target_data vertex_a vertex_b edge_a edge_b threshold_value =
    (
        position_a = this.getVertexWorldPosition target_data vertex_a
        position_b = this.getVertexWorldPosition target_data vertex_b

        if position_a == undefined or position_b == undefined then return undefined
        if distance position_a position_b > threshold_value then return undefined

        face_a = this.getOpenEdgeFaceId target_data edge_a
        face_b = this.getOpenEdgeFaceId target_data edge_b

        if face_a <= 0 or face_b <= 0 then return undefined

        plane_a = this.getFaceWorldPlane target_data face_a
        plane_b = this.getFaceWorldPlane target_data face_b

        if plane_a == undefined or plane_b == undefined then return undefined

        midpoint = (position_a + position_b) / 2.0
        target_world = this.getPlaneIntersectionTarget plane_a plane_b midpoint

        if target_world == undefined then return undefined
        if distance position_a target_world > threshold_value then return undefined
        if distance position_b target_world > threshold_value then return undefined

        target_world
        -- return
    ),

    /*
    Returns one deterministic key string for an unordered border-edge pair.
    */
    function getEdgePairKey edge_a edge_b =
    (
        lower_id = edge_a
        higher_id = edge_b

        if lower_id > higher_id then
        (
            swap_id = lower_id
            lower_id = higher_id
            higher_id = swap_id
        )

        (lower_id as string) + ":" + (higher_id as string)
        -- return
    ),

    /*
    Finds the best compatible pair of open border edges using an explicit face-group relation.
    same_group:false requires different groups for BORDERS; same_group:true requires one current group for PER ELEMENT BORDER.
    */
    function findBestBorderSeed target_data threshold_value blocked_edge_keys:#() face_group_ids:#() same_group:false =
    (
        open_records = this.getOpenEdgeRecords target_data
        if open_records.count < 2 then return undefined

        active_face_groups = face_group_ids

        if active_face_groups == undefined or active_face_groups.count == 0 then
        (
            active_face_groups = this.buildFaceGroupMap target_data
        )

        if active_face_groups.count == 0 then return undefined

        best_seed = undefined
        best_score = undefined

        for first_index = 1 to (open_records.count - 1) do
        (
            record_a = open_records[first_index]
            edge_a = record_a[1]
            a1 = record_a[2]
            a2 = record_a[3]
            face_a = record_a[4]
            group_a = if face_a > 0 and face_a <= active_face_groups.count then active_face_groups[face_a] else undefined

            if group_a != undefined then
            (
                for second_index = (first_index + 1) to open_records.count do
                (
                    record_b = open_records[second_index]
                    edge_b = record_b[1]
                    pair_key = this.getEdgePairKey edge_a edge_b

                    if findItem blocked_edge_keys pair_key == 0 then
                    (
                        b1 = record_b[2]
                        b2 = record_b[3]
                        face_b = record_b[4]
                        group_b = if face_b > 0 and face_b <= active_face_groups.count then active_face_groups[face_b] else undefined

                        group_relation_ok = false

                        if group_b != undefined then
                        (
                            if same_group then
                            (
                                group_relation_ok = group_a == group_b
                            )
                            else
                            (
                                group_relation_ok = group_a != group_b
                            )
                        )

                        if group_relation_ok then
                        (
                            position_a1 = this.getVertexWorldPosition target_data a1
                            position_a2 = this.getVertexWorldPosition target_data a2
                            position_b1 = this.getVertexWorldPosition target_data b1
                            position_b2 = this.getVertexWorldPosition target_data b2

                            if position_a1 != undefined and position_a2 != undefined and position_b1 != undefined and position_b2 != undefined then
                            (
                                direct_1 = distance position_a1 position_b1
                                direct_2 = distance position_a2 position_b2
                                crossed_1 = distance position_a1 position_b2
                                crossed_2 = distance position_a2 position_b1

                                direct_score = if direct_1 > direct_2 then direct_1 else direct_2
                                crossed_score = if crossed_1 > crossed_2 then crossed_1 else crossed_2

                                seed_score = direct_score
                                oriented_b1 = b1
                                oriented_b2 = b2
                                oriented_position_b1 = position_b1
                                oriented_position_b2 = position_b2

                                if crossed_score < direct_score then
                                (
                                    seed_score = crossed_score
                                    oriented_b1 = b2
                                    oriented_b2 = b1
                                    oriented_position_b1 = position_b2
                                    oriented_position_b2 = position_b1
                                )

                                seed_direction_ok = true

                                if same_group then
                                (
                                    seed_step_a = position_a2 - position_a1
                                    seed_step_b = oriented_position_b2 - oriented_position_b1
                                    seed_direction_ok = seed_step_a != [0,0,0] and seed_step_b != [0,0,0] and (dot seed_step_a seed_step_b) > 0.0
                                )

                                if seed_score <= threshold_value and seed_direction_ok then
                                (
                                    if best_score == undefined or seed_score < best_score then
                                    (
                                        best_score = seed_score
                                        best_seed = #(edge_a, edge_b, a1, a2, oriented_b1, oriented_b2, seed_score, group_a, group_b)
                                    )
                                )
                            )
                        )
                    )
                )
            )
        )

        best_seed
        -- return
    ),

    /*
    Finds one unambiguous next open-border step that stays on one original source face group.
    More than one eligible continuation is considered ambiguous and returns undefined.
    */
    function findNextBorderStep open_records current_vertex previous_edge used_edge_bits expected_group face_group_ids =
    (
        candidate_step = undefined
        candidate_count = 0

        for edge_record in open_records do
        (
            edge_id = edge_record[1]

            if edge_id != previous_edge and not used_edge_bits[edge_id] then
            (
                vertex_a = edge_record[2]
                vertex_b = edge_record[3]
                face_id = edge_record[4]
                next_vertex = 0

                if vertex_a == current_vertex then next_vertex = vertex_b
                if vertex_b == current_vertex then next_vertex = vertex_a

                if next_vertex > 0 and face_id > 0 and face_id <= face_group_ids.count then
                (
                    if face_group_ids[face_id] == expected_group then
                    (
                        candidate_count += 1
                        candidate_step = #(edge_id, next_vertex)
                    )
                )
            )
        )

        if candidate_count == 1 then candidate_step else undefined
        -- return
    ),

    /*
    Returns true when two synchronous border steps travel in the same spatial direction.
    Exact dot-product sign is used as an orientation gate; no private angle tolerance is introduced.
    */
    function areBorderStepsCoDirected target_data current_a current_b next_a next_b =
    (
        current_world_a = this.getVertexWorldPosition target_data current_a
        current_world_b = this.getVertexWorldPosition target_data current_b
        next_world_a = this.getVertexWorldPosition target_data next_a
        next_world_b = this.getVertexWorldPosition target_data next_b

        if current_world_a == undefined or current_world_b == undefined or next_world_a == undefined or next_world_b == undefined then return false

        step_vector_a = next_world_a - current_world_a
        step_vector_b = next_world_b - current_world_b

        if step_vector_a == [0,0,0] or step_vector_b == [0,0,0] then return false

        (dot step_vector_a step_vector_b) > 0.0
        -- return
    ),

    /*
    Extends one side of an already oriented border seed and appends compatible vertex pairs.
    Returns true after a normal stop and false only for invalid input.
    */
    function extendBorderPairs target_data open_records face_group_ids group_a group_b current_a current_b previous_edge_a previous_edge_b used_edges_a used_edges_b used_vertices_a used_vertices_b threshold_value pair_records debug:false =
    (
        if target_data == undefined then return false

        keep_walking = true
        active_a = current_a
        active_b = current_b
        prior_edge_a = previous_edge_a
        prior_edge_b = previous_edge_b

        while keep_walking do
        (
            step_a = this.findNextBorderStep open_records active_a prior_edge_a used_edges_a group_a face_group_ids
            step_b = this.findNextBorderStep open_records active_b prior_edge_b used_edges_b group_b face_group_ids

            if step_a == undefined or step_b == undefined then
            (
                keep_walking = false
            )
            else
            (
                next_edge_a = step_a[1]
                next_vertex_a = step_a[2]
                next_edge_b = step_b[1]
                next_vertex_b = step_b[2]

                if next_vertex_a == next_vertex_b then
                (
                    if debug then
                    (
                        format "Vertex Welder DEBUG | border walk stop: both source groups meet at existing shared vertex %.\n" next_vertex_a
                    )

                    keep_walking = false
                )
                else if not(this.areBorderStepsCoDirected target_data active_a active_b next_vertex_a next_vertex_b) then
                (
                    if debug then
                    (
                        format "Vertex Welder DEBUG | border walk stop: continuation directions diverge at % <-> % toward % <-> %.\n" active_a active_b next_vertex_a next_vertex_b
                    )

                    keep_walking = false
                )
                else if used_vertices_a[next_vertex_a] or used_vertices_b[next_vertex_b] then
                (
                    keep_walking = false
                )
                else
                (
                    target_world = this.getBorderPairTarget target_data next_vertex_a next_vertex_b next_edge_a next_edge_b threshold_value

                    if target_world == undefined then
                    (
                        keep_walking = false
                    )
                    else
                    (
                        append pair_records #(next_vertex_a, next_vertex_b, next_edge_a, next_edge_b, target_world)
                        used_edges_a[next_edge_a] = true
                        used_edges_b[next_edge_b] = true
                        used_vertices_a[next_vertex_a] = true
                        used_vertices_b[next_vertex_b] = true

                        if debug then
                        (
                            format "Vertex Welder DEBUG | border walk:% <-> % | edges:% <-> % | target:%\n" next_vertex_a next_vertex_b next_edge_a next_edge_b target_world
                        )

                        active_a = next_vertex_a
                        active_b = next_vertex_b
                        prior_edge_a = next_edge_a
                        prior_edge_b = next_edge_b
                    )
                )
            )
        )

        true
        -- return
    ),

    /*
    Builds one complete locally compatible border-pair run from a seed edge pair.
    Shared endpoint vertices are treated as already stitched and original face-group identity keeps the two source sides distinct.
    */
    function buildBorderPairRun target_data seed_data threshold_value face_group_ids:#() debug:false =
    (
        pair_records = #()
        if seed_data == undefined then return pair_records

        open_records = this.getOpenEdgeRecords target_data
        active_face_groups = face_group_ids

        if active_face_groups == undefined or active_face_groups.count == 0 then
        (
            active_face_groups = this.buildFaceGroupMap target_data
        )

        if open_records.count == 0 or active_face_groups.count == 0 then return pair_records

        edge_a = seed_data[1]
        edge_b = seed_data[2]
        a1 = seed_data[3]
        a2 = seed_data[4]
        b1 = seed_data[5]
        b2 = seed_data[6]
        group_a = seed_data[8]
        group_b = seed_data[9]

        if a1 != b1 then
        (
            target_1 = this.getBorderPairTarget target_data a1 b1 edge_a edge_b threshold_value
            if target_1 == undefined then return #()
            append pair_records #(a1, b1, edge_a, edge_b, target_1)
        )
        else if debug then
        (
            format "Vertex Welder DEBUG | border seed endpoint % is already shared; no weld pair is added.\n" a1
        )

        if a2 != b2 then
        (
            target_2 = this.getBorderPairTarget target_data a2 b2 edge_a edge_b threshold_value
            if target_2 == undefined then return #()
            append pair_records #(a2, b2, edge_a, edge_b, target_2)
        )
        else if debug then
        (
            format "Vertex Welder DEBUG | border seed endpoint % is already shared; no weld pair is added.\n" a2
        )

        edge_count = this.getEdgeCount target_data
        vertex_count = this.getVertexCount target_data
        used_edges_a = #{}
        used_edges_b = #{}
        used_vertices_a = #{}
        used_vertices_b = #{}
        used_edges_a.count = edge_count
        used_edges_b.count = edge_count
        used_vertices_a.count = vertex_count
        used_vertices_b.count = vertex_count
        used_edges_a[edge_a] = true
        used_edges_b[edge_b] = true
        used_vertices_a[a1] = true
        used_vertices_a[a2] = true
        used_vertices_b[b1] = true
        used_vertices_b[b2] = true

        this.extendBorderPairs target_data open_records active_face_groups group_a group_b a1 b1 edge_a edge_b used_edges_a used_edges_b used_vertices_a used_vertices_b threshold_value pair_records debug:debug
        this.extendBorderPairs target_data open_records active_face_groups group_a group_b a2 b2 edge_a edge_b used_edges_a used_edges_b used_vertices_a used_vertices_b threshold_value pair_records debug:debug

        pair_records
        -- return
    ),

    /*
    Sorts planned weld pairs by the higher endpoint ID for deterministic compound execution.
    Deleting higher endpoint IDs first keeps every lower endpoint used by later pairs numerically stable when native weld compaction occurs.
    */
    function sortPairsDescendingByHighVertex pair_records =
    (
        sorted_pairs = for pair_record in pair_records collect pair_record

        for first_index = 1 to (sorted_pairs.count - 1) do
        (
            best_index = first_index
            first_high = if sorted_pairs[best_index][1] > sorted_pairs[best_index][2] then sorted_pairs[best_index][1] else sorted_pairs[best_index][2]

            for second_index = (first_index + 1) to sorted_pairs.count do
            (
                second_high = if sorted_pairs[second_index][1] > sorted_pairs[second_index][2] then sorted_pairs[second_index][1] else sorted_pairs[second_index][2]

                if second_high > first_high then
                (
                    best_index = second_index
                    first_high = second_high
                )
            )

            if best_index != first_index then
            (
                swap_pair = sorted_pairs[first_index]
                sorted_pairs[first_index] = sorted_pairs[best_index]
                sorted_pairs[best_index] = swap_pair
            )
        )

        sorted_pairs
        -- return
    ),


    /*
    Welds one planned sequential border run while avoiding explicit dead-topology collapse between pairs.
    Editable Poly welds may compact their vertex list immediately, so the lower endpoint is kept as survivor and higher disposable endpoints execute in descending order.
    */
    function weldBorderPairRun target_data pair_records debug:false =
    (
        if pair_records == undefined or pair_records.count == 0 then return 0

        sorted_pairs = this.sortPairsDescendingByHighVertex pair_records
        target_kind = target_data[1]

        if target_kind == #editable_poly then
        (
            if not(this.prepareTopologyPhase target_data) then
            (
                this.setMessage "Editable Poly border run could not establish one clean topology domain."
                return -1
            )

            node_v = target_data[2]
            poly_value = target_data[3]
            before_count = polyop.getNumVerts poly_value
            planned_vertices = #{}
            previous_source_id = before_count + 1

            for pair_record in sorted_pairs do
            (
                if pair_record.count < 5 then
                (
                    this.setMessage "Editable Poly border weld plan is incomplete."
                    return -1
                )

                vertex_a = pair_record[1]
                vertex_b = pair_record[2]

                if vertex_a <= 0 or vertex_b <= 0 or vertex_a > before_count or vertex_b > before_count or vertex_a == vertex_b then
                (
                    this.setMessage "Editable Poly border weld plan contains invalid vertex IDs."
                    return -1
                )

                source_id = if vertex_a > vertex_b then vertex_a else vertex_b
                target_id = if vertex_a < vertex_b then vertex_a else vertex_b

                if source_id >= previous_source_id then
                (
                    this.setMessage "Editable Poly border weld plan is not ordered by descending disposable vertex ID."
                    return -1
                )

                if planned_vertices[source_id] or planned_vertices[target_id] then
                (
                    this.setMessage "Editable Poly border weld plan reuses a vertex in more than one planned pair."
                    return -1
                )

                planned_vertices[source_id] = true
                planned_vertices[target_id] = true
                previous_source_id = source_id
            )

            welded_count = 0

            for pair_record in sorted_pairs do
            (
                vertex_a = pair_record[1]
                vertex_b = pair_record[2]
                target_world = pair_record[5]
                source_id = if vertex_a > vertex_b then vertex_a else vertex_b
                target_id = if vertex_a < vertex_b then vertex_a else vertex_b
                pair_before_count = polyop.getNumVerts poly_value

                if source_id > pair_before_count or target_id > pair_before_count then
                (
                    this.setMessage ("Editable Poly border weld lost the planned ID domain before pair " + (vertex_a as string) + " <-> " + (vertex_b as string) + ".")
                    return -1
                )

                if debug then
                (
                    format "Vertex Welder DEBUG | border compound weld:% <- % | planned:% <-> % | verts-before:% | target:%\n" target_id source_id vertex_a vertex_b pair_before_count target_world
                )

                -- polyop.weldVerts keeps the first endpoint as the survivor in this verified path.
                -- Supplying the lower ID first removes the higher disposable ID, so descending execution preserves every later planned lower ID.
                polyop.weldVerts poly_value target_id source_id target_world node:node_v
                update node_v

                pair_after_count = polyop.getNumVerts poly_value

                if pair_after_count != (pair_before_count - 1) then
                (
                    this.setMessage ("Editable Poly border weld changed the vertex count unexpectedly for pair " + (vertex_a as string) + " <-> " + (vertex_b as string) + ": " + (pair_before_count as string) + " -> " + (pair_after_count as string) + ".")
                    return -1
                )

                survivor_world = this.getVertexWorldPosition target_data target_id

                if survivor_world == undefined or survivor_world != target_world then
                (
                    this.setMessage ("Editable Poly border weld did not keep the lower-ID survivor at the requested target for pair " + (vertex_a as string) + " <-> " + (vertex_b as string) + ".")
                    return -1
                )

                welded_count += 1
            )

            if not(this.ensureCleanEditablePolyTopology target_data) then
            (
                this.setMessage "Editable Poly border run finished, but final dead-topology synchronization failed."
                return -1
            )

            after_count = this.getVertexCount target_data

            if welded_count != sorted_pairs.count or after_count != (before_count - sorted_pairs.count) then
            (
                this.setMessage ("Editable Poly border run changed the final vertex count unexpectedly: " + (before_count as string) + " -> " + (after_count as string) + ".")
                return -1
            )

            return welded_count
        )

        if target_kind == #edit_poly then
        (
            welded_count = 0

            for pair_record in sorted_pairs do
            (
                vertex_a = pair_record[1]
                vertex_b = pair_record[2]
                target_world = pair_record[5]

                if debug then
                (
                    format "Vertex Welder DEBUG | border weld:% <-> % | target:%\n" vertex_a vertex_b target_world
                )

                if this.weldPairAtWorldPosition target_data vertex_a vertex_b target_world then
                (
                    welded_count += 1
                )
                else
                (
                    this.setMessage ("Edit Poly border weld stopped after planned pair " + (vertex_a as string) + " <-> " + (vertex_b as string) + " failed.")
                    return -1
                )
            )

            return welded_count
        )

        this.setMessage "Unsupported target in border weld run."
        -1
        -- return
    ),

    /*
    Runs sequential different-element border stitching until no compatible border seed remains.
    */
    function weldBorders target_data threshold_value debug:false =
    (
        if target_data == undefined then
        (
            this.setMessage "No valid target."
            return -1
        )

        if threshold_value < 0.0 then
        (
            this.setMessage "Threshold cannot be negative."
            return -1
        )

        if not(this.prepareTopologyPhase target_data) then
        (
            this.setMessage "Topology synchronization failed."
            return -1
        )

        source_face_count = this.getFaceCount target_data
        source_face_groups = this.buildFaceGroupMap target_data

        if source_face_count <= 0 or source_face_groups.count != source_face_count then
        (
            this.setMessage "BORDERS could not capture the original face-element identity."
            return -1
        )

        total_welded = 0
        blocked_edge_keys = #()
        keep_searching = true

        while keep_searching do
        (
            if not(this.prepareTopologyPhase target_data) then
            (
                this.setMessage "Topology synchronization failed."
                return -1
            )

            current_face_count = this.getFaceCount target_data

            if current_face_count != source_face_count then
            (
                this.setMessage ("BORDERS changed the face count unexpectedly: " + (source_face_count as string) + " -> " + (current_face_count as string) + ".")
                return -1
            )

            seed_data = this.findBestBorderSeed target_data threshold_value blocked_edge_keys:blocked_edge_keys face_group_ids:source_face_groups

            if seed_data == undefined then
            (
                keep_searching = false
            )
            else
            (
                if debug then
                (
                    format "Vertex Welder DEBUG | border seed edges:% <-> % | verts:(%,%) <-> (%,%) | score:% | source-groups:% <-> %\n" seed_data[1] seed_data[2] seed_data[3] seed_data[4] seed_data[5] seed_data[6] seed_data[7] seed_data[8] seed_data[9]
                )

                pair_records = this.buildBorderPairRun target_data seed_data threshold_value face_group_ids:source_face_groups debug:debug

                if pair_records.count == 0 then
                (
                    append blocked_edge_keys (this.getEdgePairKey seed_data[1] seed_data[2])

                    if debug then format "Vertex Welder DEBUG | rejected border seed:% <-> %\n" seed_data[1] seed_data[2]
                )
                else
                (
                    run_count = this.weldBorderPairRun target_data pair_records debug:debug

                    if run_count < 0 then return -1

                    total_welded += run_count
                    blocked_edge_keys = #()

                    if debug then
                    (
                        format "Vertex Welder DEBUG | border run complete:% pair(s) | total:% | preserving original source groups for remaining seams.\n" run_count total_welded
                    )
                )
            )
        )

        this.setMessage ("BORDERS complete. Welded pairs: " + (total_welded as string) + ".")
        total_welded
        -- return
    ),

    /*
    Stitches close matching open-border chains that already belong to the same current face-connected element.
    This is a post-fix mode for partially stitched seams where normal BORDERS can no longer use a different-element seed.
    */
    function weldPerElementBorders target_data threshold_value debug:false =
    (
        if target_data == undefined then
        (
            this.setMessage "No valid target."
            return -1
        )

        if threshold_value < 0.0 then
        (
            this.setMessage "Threshold cannot be negative."
            return -1
        )

        total_welded = 0
        blocked_edge_keys = #()
        keep_searching = true

        while keep_searching do
        (
            if not(this.prepareTopologyPhase target_data) then
            (
                this.setMessage "Topology synchronization failed."
                return -1
            )

            source_face_count = this.getFaceCount target_data
            current_face_groups = this.buildFaceGroupMap target_data

            if source_face_count <= 0 or current_face_groups.count != source_face_count then
            (
                this.setMessage "PER ELEMENT BORDER could not resolve the current face-element identity."
                return -1
            )

            seed_data = this.findBestBorderSeed target_data threshold_value blocked_edge_keys:blocked_edge_keys face_group_ids:current_face_groups same_group:true

            if seed_data == undefined then
            (
                keep_searching = false
            )
            else
            (
                if debug then
                (
                    format "Vertex Welder DEBUG | per-element border seed edges:% <-> % | verts:(%,%) <-> (%,%) | score:% | group:%\n" seed_data[1] seed_data[2] seed_data[3] seed_data[4] seed_data[5] seed_data[6] seed_data[7] seed_data[8]
                )

                pair_records = this.buildBorderPairRun target_data seed_data threshold_value face_group_ids:current_face_groups debug:debug

                if pair_records.count == 0 then
                (
                    append blocked_edge_keys (this.getEdgePairKey seed_data[1] seed_data[2])

                    if debug then format "Vertex Welder DEBUG | rejected per-element border seed:% <-> %\n" seed_data[1] seed_data[2]
                )
                else
                (
                    run_count = this.weldBorderPairRun target_data pair_records debug:debug

                    if run_count < 0 then return -1

                    if this.getFaceCount target_data != source_face_count then
                    (
                        this.setMessage "PER ELEMENT BORDER changed the face count unexpectedly."
                        return -1
                    )

                    total_welded += run_count
                    blocked_edge_keys = #()

                    if debug then
                    (
                        format "Vertex Welder DEBUG | per-element border run complete:% pair(s) | total:%\n" run_count total_welded
                    )
                )
            )
        )

        this.setMessage ("PER ELEMENT BORDER complete. Welded pairs: " + (total_welded as string) + ".")
        total_welded
        -- return
    ),

    /*
    Dispatches one mode against one resolved target using an explicit millimeter threshold.
    Returns the verified weld count or -1 on failure.
    */
    function runModeOnTarget target_data mode_value threshold_mm debug:false =
    (
        if target_data == undefined then
        (
            this.setMessage "No valid target."
            return -1
        )

        if not isKindOf threshold_mm Number or threshold_mm < 0.0 then
        (
            this.setMessage "Threshold must be a non-negative numeric millimeter value."
            return -1
        )

        threshold_value = this.thresholdMmToSystemUnits threshold_mm

        if mode_value == #weld then return this.weldClosestPairs target_data threshold_value debug:debug
        if mode_value == #per_element then return this.weldClosestPairs target_data threshold_value per_element:true debug:debug
        if mode_value == #borders then return this.weldBorders target_data threshold_value debug:debug
        if mode_value == #per_element_border then return this.weldPerElementBorders target_data threshold_value debug:debug

        this.setMessage "Unknown weld mode."
        -1
        -- return
    ),

    /*
    Runs one UI weld action on the currently selected supported target inside one undo entry.
    */
    function runSelected mode_value threshold_mm debug:false =
    (
        target_data = this.getSelectedTarget()
        if target_data == undefined then return -1

        before_count = this.getVertexCount target_data
        welded_count = -1

        undo "Vertex Welder" on
        (
            with redraw off
            (
                welded_count = this.runModeOnTarget target_data mode_value threshold_mm debug:debug
            )
        )

        after_count = this.getVertexCount target_data
        completeRedraw()

        format "Vertex Welder | mode:% | threshold:% mm | verts:% -> % | welded:% | status:%\n" mode_value threshold_mm before_count after_count welded_count last_message

        welded_count
        -- return
    ),

    /*
    Deletes a previous named test fixture when it still exists.
    */
    function deleteNamedTestObject object_name =
    (
        existing_node = getNodeByName object_name exact:true

        if isValidNode existing_node then delete existing_node

        true
        -- return
    ),

    /*
    Creates the WELD test fixture with two coplanar disconnected quads and a close seam.
    */
    function createWeldFixture object_name threshold_mm =
    (
        gap_value = this.thresholdMmToSystemUnits (threshold_mm * 0.5)
        size_value = units.decodeValue "20mm"

        fixture_node = mesh name:object_name \
            vertices:#( \
                [-size_value,0,0], [0,0,0], [0,size_value,0], [-size_value,size_value,0], \
                [gap_value,0,0], [size_value,0,0], [size_value,size_value,0], [gap_value,size_value,0]) \
            faces:#([1,2,3], [1,3,4], [5,6,7], [5,7,8])

        convertToPoly fixture_node
        fixture_node.baseObject.showCage = off
        fixture_node
        -- return
    ),

    /*
    Creates the PER ELEMENT fixture with one close same-element mouth and one tempting nearby separate element.
    */
    function createPerElementFixture object_name threshold_mm =
    (
        gap_value = this.thresholdMmToSystemUnits (threshold_mm * 0.25)
        cross_gap = this.thresholdMmToSystemUnits (threshold_mm * 0.4)
        x_inner = units.decodeValue "15mm"
        x_far = units.decodeValue "20mm"
        strip_height = units.decodeValue "5mm"
        far_gap = units.decodeValue "1mm"

        fixture_node = mesh name:object_name \
            vertices:#( \
                [0,0,0], [x_inner,0,0], [x_inner,strip_height,0], [0,strip_height,0], \
                [x_far,0,0], [x_far,strip_height,0], [x_far,strip_height + far_gap,0], [x_inner,strip_height + far_gap,0], \
                [x_far,(strip_height * 2.0) + far_gap,0], [x_inner,(strip_height * 2.0) + far_gap,0], \
                [0,strip_height + gap_value,0], [0,(strip_height * 2.0) + gap_value,0], \
                [-cross_gap,strip_height,0], [-x_far,0,0], [-x_far,strip_height * 2.0,0]) \
            faces:#( \
                [1,2,3], [1,3,4], \
                [2,5,6], [2,6,3], \
                [3,6,7], [3,7,8], \
                [8,7,9], [8,9,10], \
                [11,8,10], [11,10,12], \
                [13,14,15])

        convertToPoly fixture_node
        fixture_node.baseObject.showCage = off
        fixture_node
        -- return
    ),

    /*
    Creates the BORDERS fixture with two rectangular faces whose planes intersect between close seam edges.
    */
    function createBordersFixture object_name threshold_mm =
    (
        gap_value = this.thresholdMmToSystemUnits (threshold_mm * 0.5)
        rise_value = this.thresholdMmToSystemUnits (threshold_mm * 0.05)
        size_value = units.decodeValue "20mm"
        intersection_x = gap_value / 2.0
        plane_slope = (rise_value * 2.0) / gap_value
        far_z = plane_slope * (size_value - intersection_x)

        fixture_node = mesh name:object_name \
            vertices:#( \
                [-size_value,0,0], [0,0,0], [0,size_value,0], [-size_value,size_value,0], \
                [gap_value,0,rise_value], [size_value,0,far_z], [size_value,size_value,far_z], [gap_value,size_value,rise_value]) \
            faces:#([1,2,3], [1,3,4], [5,6,7], [5,7,8])

        convertToPoly fixture_node
        fixture_node.baseObject.showCage = off
        fixture_node
        -- return
    ),

    /*
    Creates a fresh test fixture for one selected mode and stores it for TEST RMB execution.
    */
    function createTestFixture mode_value threshold_mm =
    (
        if not isKindOf threshold_mm Number or threshold_mm <= 0.0 then
        (
            this.setMessage "TEST requires a threshold greater than zero."
            return false
        )

        object_name = "VERTEX_WELDER_TEST"
        created_node = undefined

        undo "Vertex Welder Test - Create Source" on
        (
            this.deleteNamedTestObject object_name

            if mode_value == #weld then created_node = this.createWeldFixture object_name threshold_mm
            if mode_value == #per_element then created_node = this.createPerElementFixture object_name threshold_mm
            if mode_value == #borders then created_node = this.createBordersFixture object_name threshold_mm
        )

        if not isValidNode created_node then
        (
            this.setMessage "Could not create the test fixture."
            return false
        )

        test_node = created_node
        test_mode = mode_value
        select test_node
        completeRedraw()

        target_data = this.getTargetFromNode test_node prefer_active:false
        vertex_count = this.getVertexCount target_data
        element_count = this.getElementCount target_data

        this.setMessage ("Test source created for " + (mode_value as string) + ".")
        format "Vertex Welder TEST CREATE | mode:% | threshold:% mm | node:% | verts:% | elements:%\n" mode_value threshold_mm test_node.name vertex_count element_count
        true
        -- return
    ),

    /*
    Runs the selected mode on the stored TEST source and prints detailed Listener diagnostics.
    */
    function runStoredTest mode_value threshold_mm =
    (
        if not isValidNode test_node then
        (
            this.setMessage "Create a TEST source with LMB first."
            return -1
        )

        target_data = this.getTargetFromNode test_node prefer_active:false
        if target_data == undefined then
        (
            this.setMessage "Stored TEST node no longer has supported topology."
            return -1
        )

        before_count = this.getVertexCount target_data
        before_elements = this.getElementCount target_data
        welded_count = -1

        select test_node

        undo "Vertex Welder Test - Run Weld" on
        (
            with redraw off
            (
                welded_count = this.runModeOnTarget target_data mode_value threshold_mm debug:true
            )
        )

        after_count = this.getVertexCount target_data
        after_elements = this.getElementCount target_data
        completeRedraw()

        format "Vertex Welder TEST RESULT | mode:% | threshold:% mm | verts:% -> % | elements:% -> % | welded:% | status:%\n" mode_value threshold_mm before_count after_count before_elements after_elements welded_count last_message
        welded_count
        -- return
    ),

    on create do
    (
        last_message = "Ready."
    )
)

VertexWelder = VertexWelder_v()
