/* Rebuild-Mesh_0.01.ms
   Rebuild evaluated mesh topology from visible edges.
*/

global rebuildMesh
global rebuildMeshRollout

struct rebuildMesh_v
(
    version = "0.04",

    /* Build an undirected edge key.
       The smaller vertex index is always stored first. */
    function edgeKey vertex_a vertex_b =
    (
        if vertex_a < vertex_b then
        (
            ((vertex_a as string) + "|" + (vertex_b as string))
        )
        else
        (
            ((vertex_b as string) + "|" + (vertex_a as string))
        )
        -- return
    ),

    /* Build a spatial hash key for one weld cell.
       Cell coordinates are derived from local object-space positions. */
    function cellKey position weld_tolerance offset_x:0 offset_y:0 offset_z:0 =
    (
        cell_x = (floor (position.x / weld_tolerance)) + offset_x
        cell_y = (floor (position.y / weld_tolerance)) + offset_y
        cell_z = (floor (position.z / weld_tolerance)) + offset_z

        ((cell_x as string) + "|" + (cell_y as string) + "|" + (cell_z as string))
        -- return
    ),

    /* Return the two canonical vertex indices used by one triangle edge.
       Triangle edge order follows getEdgeVis(): 1=(x,y), 2=(y,z), 3=(z,x). */
    function faceEdgeVerts mapped_face edge_id =
    (
        edge_vertices = case edge_id of
        (
            1: #(mapped_face[1], mapped_face[2])
            2: #(mapped_face[2], mapped_face[3])
            3: #(mapped_face[3], mapped_face[1])
        )

        edge_vertices
        -- return
    ),

    /* Find the root face in the disjoint-set forest.
       Path compression keeps repeated group queries inexpensive. */
    function findRoot face_parent face_id =
    (
        root_id = face_id

        while face_parent[root_id] != root_id do
        (
            root_id = face_parent[root_id]
        )

        current_id = face_id
        while face_parent[current_id] != current_id do
        (
            next_id = face_parent[current_id]
            face_parent[current_id] = root_id
            current_id = next_id
        )

        root_id
        -- return
    ),

    /* Join two face groups in the disjoint-set forest.
       Rank is used so deep parent chains are avoided. */
    function unionFaces face_parent rank_values face_a face_b =
    (
        root_a = findRoot face_parent face_a
        root_b = findRoot face_parent face_b

        if root_a != root_b then
        (
            if rank_values[root_a] < rank_values[root_b] then
            (
                face_parent[root_a] = root_b
            )
            else if rank_values[root_a] > rank_values[root_b] then
            (
                face_parent[root_b] = root_a
            )
            else
            (
                face_parent[root_b] = root_a
                rank_values[root_a] += 1
            )
        )

        true
        -- return
    ),

    /* Create canonical vertices by welding coincident source positions.
       Neighboring spatial-hash cells are checked so cell borders cannot miss a weld. */
    function buildCanonicalVertices source_mesh weld_tolerance =
    (
        effective_tolerance = weld_tolerance
        if effective_tolerance <= 0.0 then
        (
            effective_tolerance = 0.000000001
        )

        old_to_canonical = for vertex_id = 1 to source_mesh.numverts collect 0
        canonical_positions = #()

        cell_table = dotNetObject "System.Collections.Hashtable"
        cell_buckets = #()

        for old_vertex_id = 1 to source_mesh.numverts do
        (
            position = getVert source_mesh old_vertex_id
            canonical_id = 0

            for offset_x = -1 to 1 while canonical_id == 0 do
            (
                for offset_y = -1 to 1 while canonical_id == 0 do
                (
                    for offset_z = -1 to 1 while canonical_id == 0 do
                    (
                        cell_key = cellKey position effective_tolerance offset_x:offset_x offset_y:offset_y offset_z:offset_z

                        if cell_table.ContainsKey cell_key then
                        (
                            bucket_index = cell_table.Item[cell_key]
                            bucket_values = cell_buckets[bucket_index]

                            for candidate_id in bucket_values while canonical_id == 0 do
                            (
                                if (distance position canonical_positions[candidate_id]) <= effective_tolerance then
                                (
                                    canonical_id = candidate_id
                                )
                            )
                        )
                    )
                )
            )

            if canonical_id == 0 then
            (
                append canonical_positions position
                canonical_id = canonical_positions.count

                own_key = cellKey position effective_tolerance

                if cell_table.ContainsKey own_key then
                (
                    bucket_index = cell_table.Item[own_key]
                    bucket_values = cell_buckets[bucket_index]
                    append bucket_values canonical_id
                    cell_buckets[bucket_index] = bucket_values
                )
                else
                (
                    append cell_buckets #(canonical_id)
                    bucket_index = cell_buckets.count
                    cell_table.Add own_key bucket_index
                )
            )

            old_to_canonical[old_vertex_id] = canonical_id
        )

        #(canonical_positions, old_to_canonical)
        -- return
    ),

    /* Validate triangles after positional welding and remove duplicate faces.
       Repeated vertices and effectively zero-area triangles are treated as degenerate. */
    function buildValidFaces source_mesh canonical_positions old_to_canonical weld_tolerance =
    (
        face_verts = for face_id = 1 to source_mesh.numfaces collect undefined
        face_mat_ids = for face_id = 1 to source_mesh.numfaces collect 1
        face_smoothing = for face_id = 1 to source_mesh.numfaces collect 0
        valid_face_ids = #()

        degenerate_count = 0
        duplicate_count = 0
        duplicate_table = dotNetObject "System.Collections.Hashtable"

        area_epsilon = amax 0.000000000001 (weld_tolerance * weld_tolerance * 0.001)

        for face_id = 1 to source_mesh.numfaces do
        (
            source_face = getFace source_mesh face_id

            mapped_face = #(
                old_to_canonical[source_face.x as integer],
                old_to_canonical[source_face.y as integer],
                old_to_canonical[source_face.z as integer]
            )

            face_verts[face_id] = mapped_face
            face_mat_ids[face_id] = getFaceMatID source_mesh face_id
            face_smoothing[face_id] = getFaceSmoothGroup source_mesh face_id

            is_degenerate = false

            if mapped_face[1] == mapped_face[2] or mapped_face[2] == mapped_face[3] or mapped_face[3] == mapped_face[1] then
            (
                is_degenerate = true
            )
            else
            (
                position_a = canonical_positions[mapped_face[1]]
                position_b = canonical_positions[mapped_face[2]]
                position_c = canonical_positions[mapped_face[3]]

                area_vector = cross (position_b - position_a) (position_c - position_a)

                if (length area_vector) <= area_epsilon then
                (
                    is_degenerate = true
                )
            )

            if is_degenerate then
            (
                degenerate_count += 1
            )
            else
            (
                sorted_ids = #(mapped_face[1], mapped_face[2], mapped_face[3])
                sort sorted_ids

                face_key = (sorted_ids[1] as string) + "|" + (sorted_ids[2] as string) + "|" + (sorted_ids[3] as string)

                if duplicate_table.ContainsKey face_key then
                (
                    duplicate_count += 1
                )
                else
                (
                    duplicate_table.Add face_key true
                    append valid_face_ids face_id
                )
            )
        )

        #(face_verts, face_mat_ids, face_smoothing, valid_face_ids, degenerate_count, duplicate_count)
        -- return
    ),

    /* Group triangles across shared invisible edges.
       Material-ID or smoothing-group boundaries are preserved as explicit polygon edges. */
    function buildFaceGroups source_mesh face_verts face_mat_ids face_smoothing valid_face_ids =
    (
        face_parent = for face_id = 1 to source_mesh.numfaces collect face_id
        rank_values = for face_id = 1 to source_mesh.numfaces collect 0

        edge_table = dotNetObject "System.Collections.Hashtable"
        edge_records = #()

        for face_id in valid_face_ids do
        (
            mapped_face = face_verts[face_id]

            for edge_id = 1 to 3 do
            (
                edge_vertices = faceEdgeVerts mapped_face edge_id
                edge_key = edgeKey edge_vertices[1] edge_vertices[2]
                edge_visible = getEdgeVis source_mesh face_id edge_id

                if edge_table.ContainsKey edge_key then
                (
                    edge_record_index = edge_table.Item[edge_key]
                )
                else
                (
                    append edge_records #(edge_key, #())
                    edge_record_index = edge_records.count
                    edge_table.Add edge_key edge_record_index
                )

                edge_record = edge_records[edge_record_index]
                edge_uses = edge_record[2]
                append edge_uses #(face_id, edge_id, edge_visible)
                edge_record[2] = edge_uses
                edge_records[edge_record_index] = edge_record
            )
        )

        attribute_conflict_count = 0
        nonmanifold_edge_count = 0

        for edge_record in edge_records do
        (
            edge_uses = edge_record[2]

            if edge_uses.count == 2 then
            (
                use_a = edge_uses[1]
                use_b = edge_uses[2]

                if use_a[3] == false and use_b[3] == false then
                (
                    face_a = use_a[1]
                    face_b = use_b[1]

                    same_material = face_mat_ids[face_a] == face_mat_ids[face_b]
                    same_smoothing = face_smoothing[face_a] == face_smoothing[face_b]

                    if same_material and same_smoothing then
                    (
                        unionFaces face_parent rank_values face_a face_b
                    )
                    else
                    (
                        attribute_conflict_count += 1
                    )
                )
            )
            else if edge_uses.count > 2 then
            (
                nonmanifold_edge_count += 1
            )
        )

        group_table = dotNetObject "System.Collections.Hashtable"
        groups = #()

        for face_id in valid_face_ids do
        (
            root_id = findRoot face_parent face_id
            root_key = root_id as string

            if group_table.ContainsKey root_key then
            (
                group_index = group_table.Item[root_key]
                group_faces = groups[group_index]
                append group_faces face_id
                groups[group_index] = group_faces
            )
            else
            (
                append groups #(face_id)
                group_index = groups.count
                group_table.Add root_key group_index
            )
        )

        #(groups, attribute_conflict_count, nonmanifold_edge_count)
        -- return
    ),

    /* Trace one polygon boundary from a triangle group.
       Groups with holes, branches, open chains, or non-manifold boundary counts are rejected. */
    function buildBoundaryLoop group_faces face_verts =
    (
        edge_table = dotNetObject "System.Collections.Hashtable"
        edge_records = #()
        bad_edge_count = false

        for face_id in group_faces do
        (
            mapped_face = face_verts[face_id]

            for edge_id = 1 to 3 do
            (
                edge_vertices = faceEdgeVerts mapped_face edge_id
                edge_key = edgeKey edge_vertices[1] edge_vertices[2]

                if edge_table.ContainsKey edge_key then
                (
                    edge_record_index = edge_table.Item[edge_key]
                    edge_record = edge_records[edge_record_index]
                    edge_record[3] += 1
                    edge_records[edge_record_index] = edge_record
                )
                else
                (
                    append edge_records #(edge_vertices[1], edge_vertices[2], 1)
                    edge_record_index = edge_records.count
                    edge_table.Add edge_key edge_record_index
                )
            )
        )

        boundary_edges = #()

        for edge_record in edge_records do
        (
            if edge_record[3] == 1 then
            (
                append boundary_edges #(edge_record[1], edge_record[2])
            )
            else if edge_record[3] > 2 then
            (
                bad_edge_count = true
            )
        )

        boundary_valid = not bad_edge_count
        loops = #()

        if boundary_edges.count < 3 then
        (
            boundary_valid = false
        )

        if boundary_valid then
        (
            used_edges = #{}
            used_count = 0

            while boundary_valid and used_count < boundary_edges.count do
            (
                start_edge_index = 0

                for edge_index = 1 to boundary_edges.count while start_edge_index == 0 do
                (
                    if used_edges[edge_index] == false then
                    (
                        start_edge_index = edge_index
                    )
                )

                if start_edge_index == 0 then
                (
                    boundary_valid = false
                )
                else
                (
                    start_edge = boundary_edges[start_edge_index]
                    start_vertex = start_edge[1]
                    current_vertex = start_edge[2]

                    current_loop = #(start_vertex, current_vertex)
                    used_edges[start_edge_index] = true
                    used_count += 1
                    step_count = 0
                    closed_loop = false

                    while boundary_valid and not closed_loop and step_count <= boundary_edges.count do
                    (
                        if current_vertex == start_vertex then
                        (
                            closed_loop = true
                        )
                        else
                        (
                            candidate_count = 0
                            next_edge_index = 0
                            next_vertex = 0

                            for edge_index = 1 to boundary_edges.count do
                            (
                                if used_edges[edge_index] == false then
                                (
                                    test_edge = boundary_edges[edge_index]

                                    if test_edge[1] == current_vertex then
                                    (
                                        candidate_count += 1
                                        next_edge_index = edge_index
                                        next_vertex = test_edge[2]
                                    )
                                    else if test_edge[2] == current_vertex then
                                    (
                                        candidate_count += 1
                                        next_edge_index = edge_index
                                        next_vertex = test_edge[1]
                                    )
                                )
                            )

                            if candidate_count != 1 then
                            (
                                boundary_valid = false
                            )
                            else
                            (
                                used_edges[next_edge_index] = true
                                used_count += 1

                                if next_vertex != start_vertex then
                                (
                                    append current_loop next_vertex
                                )

                                current_vertex = next_vertex
                            )
                        )

                        step_count += 1
                    )

                    if closed_loop and current_loop.count >= 3 then
                    (
                        append loops current_loop
                    )
                    else
                    (
                        boundary_valid = false
                    )
                )
            )
        )

        if boundary_valid and loops.count == 1 then
        (
            loops[1]
        )
        else
        (
            undefined
        )
        -- return
    ),

    /* Build raw polygon records from triangle groups.
       Invalid complex groups fall back to their original valid triangles instead of losing geometry. */
    function buildPolygonRecords groups face_verts face_mat_ids face_smoothing =
    (
        polygon_records = #()
        fallback_group_count = 0

        for group_faces in groups do
        (
            boundary_loop = buildBoundaryLoop group_faces face_verts

            if boundary_loop != undefined then
            (
                source_face_id = group_faces[1]
                append polygon_records #(
                    boundary_loop,
                    group_faces,
                    face_mat_ids[source_face_id],
                    face_smoothing[source_face_id],
                    false
                )
            )
            else
            (
                fallback_group_count += 1

                for face_id in group_faces do
                (
                    append polygon_records #(
                        copy face_verts[face_id],
                        #(face_id),
                        face_mat_ids[face_id],
                        face_smoothing[face_id],
                        true
                    )
                )
            )
        )

        #(polygon_records, fallback_group_count)
        -- return
    ),

    /* Add one neighbor to a canonical vertex without duplicates.
       The neighbor lists represent all explicit output polygon edges. */
    function appendNeighbor neighbor_lists vertex_id neighbor_id =
    (
        neighbors = neighbor_lists[vertex_id]

        if (findItem neighbors neighbor_id) == 0 then
        (
            append neighbors neighbor_id
            neighbor_lists[vertex_id] = neighbors
        )

        true
        -- return
    ),

    /* Test whether a degree-two vertex lies on a straight line.
       Both incident vectors must point in opposite directions within the angle tolerance. */
    function isStraightVertex position_a position_mid position_b angle_tolerance =
    (
        vector_a = position_a - position_mid
        vector_b = position_b - position_mid

        vector_a_length = length vector_a
        vector_b_length = length vector_b

        is_straight = false

        if vector_a_length > 0.000000000001 and vector_b_length > 0.000000000001 then
        (
            direction_a = vector_a / vector_a_length
            direction_b = vector_b / vector_b_length

            dot_value = dot direction_a direction_b

            if dot_value > 1.0 then
            (
                dot_value = 1.0
            )
            else if dot_value < -1.0 then
            (
                dot_value = -1.0
            )

            angle_value = acos dot_value
            is_straight = (abs (180.0 - angle_value)) <= angle_tolerance
        )

        is_straight
        -- return
    ),

    /* Remove globally degree-two collinear visible-edge vertices from polygon loops.
       Each removed A-V-B chain becomes one explicit A-B polygon edge. */
    function simplifyPolygonRecords polygon_records canonical_positions angle_tolerance =
    (
        neighbor_lists = for vertex_id = 1 to canonical_positions.count collect #()

        for polygon_record in polygon_records do
        (
            polygon_loop = polygon_record[1]

            for corner_id = 1 to polygon_loop.count do
            (
                next_corner_id = if corner_id == polygon_loop.count then 1 else corner_id + 1

                vertex_a = polygon_loop[corner_id]
                vertex_b = polygon_loop[next_corner_id]

                appendNeighbor neighbor_lists vertex_a vertex_b
                appendNeighbor neighbor_lists vertex_b vertex_a
            )
        )

        removable_vertices = #{}

        for vertex_id = 1 to neighbor_lists.count do
        (
            neighbors = neighbor_lists[vertex_id]

            if neighbors.count == 2 then
            (
                if isStraightVertex canonical_positions[neighbors[1]] canonical_positions[vertex_id] canonical_positions[neighbors[2]] angle_tolerance then
                (
                    removable_vertices[vertex_id] = true
                )
            )
        )

        clean_records = #()
        degenerate_after_simplify_count = 0

        for polygon_record in polygon_records do
        (
            polygon_loop = polygon_record[1]
            clean_loop = #()

            for vertex_id in polygon_loop do
            (
                if removable_vertices[vertex_id] == false then
                (
                    append clean_loop vertex_id
                )
            )

            if clean_loop.count >= 3 then
            (
                append clean_records #(
                    clean_loop,
                    polygon_record[2],
                    polygon_record[3],
                    polygon_record[4],
                    polygon_record[5]
                )
            )
            else
            (
                degenerate_after_simplify_count += 1
            )
        )

        #(clean_records, removable_vertices.numberSet, degenerate_after_simplify_count)
        -- return
    ),

    /* Convert snapshot world positions into coordinates relative to the source pivot.
       The rebuilt node can then use the exact source node transform without moving geometry. */
    function buildPivotLocalPositions canonical_positions source_obj =
    (
        inverse_pivot_tm = inverse source_obj.transform
        pivot_local_positions = #()

        for world_position in canonical_positions do
        (
            append pivot_local_positions (world_position * inverse_pivot_tm)
        )

        pivot_local_positions
        -- return
    ),

    /* Create or reuse one output Editable Poly vertex.
       Canonical source IDs are mapped to output vertex IDs lazily. */
    function getOrCreateOutputVert out_poly canonical_positions output_vert_ids canonical_id =
    (
        output_vertex_id = output_vert_ids[canonical_id]

        if output_vertex_id == 0 then
        (
            output_vertex_id = polyop.createVert out_poly canonical_positions[canonical_id]
            output_vert_ids[canonical_id] = output_vertex_id
        )

        output_vertex_id
        -- return
    ),

    /* Find one source mapping coordinate for a canonical polygon corner.
       The coordinate is taken from a source triangle that belongs to the rebuilt polygon. */
    function getSourceMapCoord source_mesh map_channel source_faces old_to_canonical canonical_id =
    (
        map_position = [0,0,0]
        map_position_found = false
        map_face_count = meshop.getNumMapFaces source_mesh map_channel
        map_vert_count = meshop.getNumMapVerts source_mesh map_channel

        for source_face_id in source_faces while map_position_found == false do
        (
            if source_face_id <= map_face_count then
            (
                source_face = getFace source_mesh source_face_id
                map_face = meshop.getMapFace source_mesh map_channel source_face_id

                source_vertex_ids = #(source_face.x as integer, source_face.y as integer, source_face.z as integer)
                map_vertex_ids = #(map_face.x as integer, map_face.y as integer, map_face.z as integer)

                for corner_id = 1 to 3 while map_position_found == false do
                (
                    source_vertex_id = source_vertex_ids[corner_id]

                    if old_to_canonical[source_vertex_id] == canonical_id then
                    (
                        map_vertex_id = map_vertex_ids[corner_id]

                        if map_vertex_id >= 1 and map_vertex_id <= map_vert_count then
                        (
                            map_position = meshop.getMapVert source_mesh map_channel map_vertex_id
                            map_position_found = true
                        )
                    )
                )
            )
        )

        map_position
        -- return
    ),

    /* Rebuild supported map channels for all successfully created polygons.
       A separate map vertex is created for every output polygon corner for seam safety. */
    function rebuildMapChannels out_poly source_mesh created_face_records old_to_canonical =
    (
        source_num_maps = meshop.getNumMaps source_mesh
        rebuilt_channel_count = 0

        if source_num_maps > 0 then
        (
            polyop.setNumMaps out_poly source_num_maps keep:false

            for map_channel = 0 to (source_num_maps - 1) do
            (
                if meshop.getMapSupport source_mesh map_channel then
                (
                    source_map_vert_count = meshop.getNumMapVerts source_mesh map_channel

                    if source_map_vert_count > 0 then
                    (
                        total_corner_count = 0

                        for face_record in created_face_records do
                        (
                            total_corner_count += face_record[2].count
                        )

                        if total_corner_count > 0 then
                        (
                            polyop.setMapSupport out_poly map_channel true
                            polyop.setNumMapVerts out_poly map_channel total_corner_count keep:false

                            next_map_vertex_id = 1

                            for face_record in created_face_records do
                            (
                                output_face_id = face_record[1]
                                canonical_loop = face_record[2]
                                source_faces = face_record[3]
                                output_map_face = #()

                                for canonical_id in canonical_loop do
                                (
                                    map_position = getSourceMapCoord source_mesh map_channel source_faces old_to_canonical canonical_id

                                    polyop.setMapVert out_poly map_channel next_map_vertex_id map_position
                                    append output_map_face next_map_vertex_id
                                    next_map_vertex_id += 1
                                )

                                polyop.setMapFace out_poly map_channel output_face_id output_map_face
                            )

                            rebuilt_channel_count += 1
                        )
                    )
                )
            )
        )

        rebuilt_channel_count
        -- return
    ),

    /* Create the new Editable Poly from clean polygon records.
       Source geometry remains untouched and only a new _REBUILT node is produced. */
    function createOutputObject source_obj source_mesh canonical_positions old_to_canonical polygon_records rebuild_maps:true =
    (
        output_name = uniqueName (source_obj.name + "_REBUILT")
        out_node = editable_mesh name:output_name
        convertTo out_node Editable_Poly

        out_poly = out_node.baseObject
        out_poly.showCage = off
        pivot_local_positions = buildPivotLocalPositions canonical_positions source_obj
        output_vert_ids = for vertex_id = 1 to canonical_positions.count collect 0
        created_face_records = #()
        failed_face_count = 0

        for polygon_record in polygon_records do
        (
            canonical_loop = polygon_record[1]
            output_vertex_loop = #()

            for canonical_id in canonical_loop do
            (
                output_vertex_id = getOrCreateOutputVert out_poly pivot_local_positions output_vert_ids canonical_id
                append output_vertex_loop output_vertex_id
            )

            output_face_id = polyop.createPolygon out_poly output_vertex_loop
            used_canonical_loop = canonical_loop

            if output_face_id == undefined then
            (
                reversed_output_loop = for loop_id = output_vertex_loop.count to 1 by -1 collect output_vertex_loop[loop_id]
                reversed_canonical_loop = for loop_id = canonical_loop.count to 1 by -1 collect canonical_loop[loop_id]

                output_face_id = polyop.createPolygon out_poly reversed_output_loop
                used_canonical_loop = reversed_canonical_loop
            )

            if output_face_id != undefined then
            (
                polyop.setFaceMatID out_poly output_face_id polygon_record[3]
                polyop.setFaceSmoothGroup out_poly output_face_id polygon_record[4]

                append created_face_records #(
                    output_face_id,
                    used_canonical_loop,
                    polygon_record[2]
                )
            )
            else
            (
                failed_face_count += 1
            )
        )

        polyop.deleteIsoVerts out_poly
        update out_node

        rebuilt_channel_count = 0

        if rebuild_maps and created_face_records.count > 0 then
        (
            rebuilt_channel_count = rebuildMapChannels out_poly source_mesh created_face_records old_to_canonical
            update out_node
        )

        /* Preserve the source pivot transform exactly.
           Snapshot geometry was converted back from world space into this pivot-local space. */
        out_node.transform = source_obj.transform
        out_node.material = source_obj.material
        out_node.wirecolor = source_obj.wirecolor

        #(out_node, failed_face_count, rebuilt_channel_count, created_face_records.count)
        -- return
    ),

    /* Rebuild the currently selected geometry object into a clean Editable Poly.
       The evaluated result supports Editable Poly objects and stacks containing Edit Poly. */
    function rebuildSelected weld_tolerance:0.0001 straight_angle_tolerance:0.01 rebuild_maps:true =
    (
        result_node = undefined

        if selection.count != 1 then
        (
            messageBox "Select exactly one geometry object." title:("Rebuild Mesh " + version)
        )
        else
        (
            source_obj = selection[1]
            source_mesh = undefined

            try
            (
                source_mesh = snapshotAsMesh source_obj
            )
            catch
            (
                source_mesh = undefined
            )

            if source_mesh == undefined then
            (
                messageBox "Could not evaluate the selected object as a mesh." title:("Rebuild Mesh " + version)
            )
            else if source_mesh.numfaces == 0 then
            (
                messageBox "The evaluated mesh has no faces." title:("Rebuild Mesh " + version)
            )
            else
            (
                canonical_data = buildCanonicalVertices source_mesh weld_tolerance
                canonical_positions = canonical_data[1]
                old_to_canonical = canonical_data[2]

                valid_data = buildValidFaces source_mesh canonical_positions old_to_canonical weld_tolerance
                face_verts = valid_data[1]
                face_mat_ids = valid_data[2]
                face_smoothing = valid_data[3]
                valid_face_ids = valid_data[4]
                degenerate_count = valid_data[5]
                duplicate_face_count = valid_data[6]

                if valid_face_ids.count == 0 then
                (
                    messageBox "No valid faces remain after cleanup." title:("Rebuild Mesh " + version)
                )
                else
                (
                    group_data = buildFaceGroups source_mesh face_verts face_mat_ids face_smoothing valid_face_ids
                    groups = group_data[1]
                    attribute_conflict_count = group_data[2]
                    nonmanifold_edge_count = group_data[3]

                    polygon_data = buildPolygonRecords groups face_verts face_mat_ids face_smoothing
                    polygon_records = polygon_data[1]
                    fallback_group_count = polygon_data[2]

                    simplify_data = simplifyPolygonRecords polygon_records canonical_positions straight_angle_tolerance
                    clean_records = simplify_data[1]
                    straight_vertex_count = simplify_data[2]
                    collapsed_face_count = simplify_data[3]

                    output_data = undefined

                    undo label:("Rebuild Mesh " + version) on
                    (
                        output_data = createOutputObject source_obj source_mesh canonical_positions old_to_canonical clean_records rebuild_maps:rebuild_maps
                    )

                    if output_data != undefined then
                    (
                        result_node = output_data[1]
                        failed_face_count = output_data[2]
                        rebuilt_channel_count = output_data[3]
                        created_face_count = output_data[4]

                        if created_face_count == 0 then
                        (
                            delete result_node
                            result_node = undefined
                            messageBox "No polygons could be created." title:("Rebuild Mesh " + version)
                        )
                        else
                        (
                            select result_node
                            max modify mode

                            format "\n--- Rebuild Mesh % ---\n" version
                            format "Source: %\n" source_obj.name
                            format "Source verts: %, source triangles: %\n" source_mesh.numverts source_mesh.numfaces
                            format "Merged coincident verts: %\n" (source_mesh.numverts - canonical_positions.count)
                            format "Degenerate faces skipped: %\n" degenerate_count
                            format "Duplicate faces skipped: %\n" duplicate_face_count
                            format "Triangle groups: %\n" groups.count
                            format "Complex groups using triangle fallback: %\n" fallback_group_count
                            format "Hidden edges kept because material/smoothing differed: %\n" attribute_conflict_count
                            format "Non-manifold geometric edges detected: %\n" nonmanifold_edge_count
                            format "Straight degree-two verts removed: %\n" straight_vertex_count
                            format "Faces lost after straight-vertex cleanup: %\n" collapsed_face_count
                            format "Polygon creation failures: %\n" failed_face_count
                            format "Map channels rebuilt: %\n" rebuilt_channel_count
                            format "Output verts: %, output polygons: %\n" (polyop.getNumVerts result_node) (polyop.getNumFaces result_node)
                            format "Output: %\n" result_node.name
                            format "--------------------------\n\n"
                        )
                    )
                )
            )
        )

        result_node
        -- return
    ),

    /* Create a deliberately damaged SketchUp-like test mesh.
       Expected rebuild result is one four-sided polygon with four vertices. */
    function createTestMesh =
    (
        test_name = uniqueName "REBUILD_TEST"

        test_obj = mesh name:test_name \
            vertices:#(
                [0,0,0],
                [50,0,0],
                [100,0,0],
                [100,100,0],
                [0,100,0],
                [50,0,0]
            ) \
            faces:#(
                [1,2,5],
                [6,4,5],
                [2,3,4],
                [1,1,5],
                [1,2,5]
            )

        setEdgeVis test_obj 1 1 true
        setEdgeVis test_obj 1 2 false
        setEdgeVis test_obj 1 3 false

        setEdgeVis test_obj 2 1 false
        setEdgeVis test_obj 2 2 true
        setEdgeVis test_obj 2 3 false

        setEdgeVis test_obj 3 1 true
        setEdgeVis test_obj 3 2 true
        setEdgeVis test_obj 3 3 false

        setEdgeVis test_obj 4 1 true
        setEdgeVis test_obj 4 2 true
        setEdgeVis test_obj 4 3 true

        setEdgeVis test_obj 5 1 true
        setEdgeVis test_obj 5 2 false
        setEdgeVis test_obj 5 3 false

        update test_obj
        convertTo test_obj Editable_Poly
        test_obj.baseObject.showCage = off

        test_obj.pos = [250.0,125.0,40.0]
        test_obj.rotation = quat 27.0 [0.0,0.0,1.0]
        test_obj.pivot = [235.0,110.0,32.0]

        select test_obj
        max modify mode

        format "\nRebuild Mesh TEST created: %\n" test_obj.name
        format "Contains: duplicate-position vertex, degenerate face, duplicate face,\n"
        format "hidden internal triangulation edges, hidden border edge, and a straight mid-edge vertex.\n"
        format "Expected rebuild: 4 verts / 1 polygon, identical world placement, identical pivot.\n\n"

        test_obj
        -- return
    ),

    on create do
    (
    )
)

rebuildMesh = rebuildMesh_v()

try
(
    destroyDialog rebuildMeshRollout
)
catch
(
)

rollout rebuildMeshRollout "Rebuild Mesh 0.04" width:330
(
    spinner spn_weld_tolerance "Weld tolerance:" range:[0.000000001,1000000.0,0.0001] type:#worldunits fieldwidth:90
    spinner spn_straight_angle "Straight tolerance:" range:[0.0,5.0,0.01] type:#float scale:0.01 fieldwidth:90
    checkbox chk_rebuild_maps "Rebuild map channels" checked:true

    button btn_rebuild "REBUILD SELECTED" width:300 height:36
    button btn_test "CREATE TEST MESH" width:300 height:28

    label lbl_info_1 "Source object is never modified."
    label lbl_info_2 "Output is a new *_REBUILT Editable Poly."

    on btn_rebuild pressed do
    (
        rebuildMesh.rebuildSelected \
            weld_tolerance:spn_weld_tolerance.value \
            straight_angle_tolerance:spn_straight_angle.value \
            rebuild_maps:chk_rebuild_maps.checked
    )

    on btn_test pressed do
    (
        rebuildMesh.createTestMesh()
    )
)

createDialog rebuildMeshRollout
