/* Rebuild-Mesh.ms
   File version: 0.10
   Rebuild evaluated Editable Poly polygons as isolated face islands, merge exact coincident topology, remove straight degree-two verts, and repair degenerate triangulation.
*/

global rebuildMesh
global rebuildMeshRollout
global rebuild_mesh_version = "0.10"
global rebuild_mesh_title = "Rebuild Mesh " + rebuild_mesh_version
global rebuild_mesh_ini = (getDir #plugcfg + "\\Rebuild-Mesh.ini")

struct rebuildMesh_v
(
    version = rebuild_mesh_version,
    degenerate_sliver_ratio = 0.001,
    degenerate_area_epsilon = 0.00000001,
    degenerate_length_epsilon = 0.00000001,

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

    /* Calculate an area-weighted source normal for one triangle group.
       Source face winding is treated as authoritative because the original faces are correctly placed. */
    function getGroupSourceNormal group_faces face_verts canonical_positions =
    (
        normal_value = [0.0,0.0,0.0]

        for face_id in group_faces do
        (
            mapped_face = face_verts[face_id]
            position_a = canonical_positions[mapped_face[1]]
            position_b = canonical_positions[mapped_face[2]]
            position_c = canonical_positions[mapped_face[3]]

            normal_value += cross (position_b - position_a) (position_c - position_a)
        )

        normal_value
        -- return
    ),

    /* Calculate the oriented normal of one polygon loop with Newell's method.
       Only the sign/direction is needed for matching the source face orientation. */
    function getPolygonLoopNormal polygon_loop canonical_positions =
    (
        normal_value = [0.0,0.0,0.0]

        for corner_id = 1 to polygon_loop.count do
        (
            next_corner_id = if corner_id == polygon_loop.count then 1 else corner_id + 1
            current_position = canonical_positions[polygon_loop[corner_id]]
            next_position = canonical_positions[polygon_loop[next_corner_id]]

            normal_value.x += (current_position.y - next_position.y) * (current_position.z + next_position.z)
            normal_value.y += (current_position.z - next_position.z) * (current_position.x + next_position.x)
            normal_value.z += (current_position.x - next_position.x) * (current_position.y + next_position.y)
        )

        normal_value
        -- return
    ),

    /* Reverse one polygon loop while preserving the same vertex membership.
       Used only when the traced boundary normal opposes the source-face normal. */
    function reversePolygonLoop polygon_loop =
    (
        reversed_loop = #()

        for corner_id = polygon_loop.count to 1 by -1 do
        (
            append reversed_loop polygon_loop[corner_id]
        )

        reversed_loop
        -- return
    ),

    /* Match a rebuilt polygon boundary to the normal direction of its source faces.
       Neighboring/source face winding wins over arbitrary boundary-trace direction. */
    function orientBoundaryToSourceNormal boundary_loop group_faces face_verts canonical_positions =
    (
        oriented_loop = boundary_loop
        source_normal = getGroupSourceNormal group_faces face_verts canonical_positions
        boundary_normal = getPolygonLoopNormal boundary_loop canonical_positions
        was_reversed = false

        if (length source_normal) > 0.000000000001 and (length boundary_normal) > 0.000000000001 then
        (
            if (dot source_normal boundary_normal) < 0.0 then
            (
                oriented_loop = reversePolygonLoop boundary_loop
                was_reversed = true
            )
        )

        #(oriented_loop, was_reversed)
        -- return
    ),

    /* Build raw polygon records from triangle groups.
       Source face orientation is preserved; invalid complex groups fall back to original triangles. */
    function buildPolygonRecords groups face_verts face_mat_ids face_smoothing canonical_positions =
    (
        polygon_records = #()
        fallback_group_count = 0
        reoriented_group_count = 0

        for group_faces in groups do
        (
            boundary_loop = buildBoundaryLoop group_faces face_verts

            if boundary_loop != undefined then
            (
                orientation_data = orientBoundaryToSourceNormal boundary_loop group_faces face_verts canonical_positions
                boundary_loop = orientation_data[1]

                if orientation_data[2] then
                (
                    reoriented_group_count += 1
                )

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

        #(polygon_records, fallback_group_count, reoriented_group_count)
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

    /* Copy source node behavior to the rebuilt node.
       Layer membership, display/render flags, visibility state, material and user properties are preserved. */
    function copySourceNodeBehavior source_obj out_node =
    (
        source_layer = source_obj.layer

        if source_layer != undefined then
        (
            source_layer.addNode out_node
        )

        out_node.material = source_obj.material
        out_node.wirecolor = source_obj.wirecolor

        out_node.displayByLayer = source_obj.displayByLayer
        out_node.renderByLayer = source_obj.renderByLayer
        out_node.motionByLayer = source_obj.motionByLayer
        out_node.colorByLayer = source_obj.colorByLayer
        out_node.globalIlluminationByLayer = source_obj.globalIlluminationByLayer

        out_node.renderable = source_obj.renderable
        out_node.inheritVisibility = source_obj.inheritVisibility
        out_node.primaryVisibility = source_obj.primaryVisibility
        out_node.secondaryVisibility = source_obj.secondaryVisibility
        out_node.receiveShadows = source_obj.receiveShadows
        out_node.castShadows = source_obj.castShadows
        out_node.applyAtmospherics = source_obj.applyAtmospherics
        out_node.renderOccluded = source_obj.renderOccluded
        out_node.gbufferChannel = source_obj.gbufferChannel

        out_node.motionBlurOn = source_obj.motionBlurOn
        out_node.motionBlur = source_obj.motionBlur
        out_node.imageMotionBlurMultiplier = source_obj.imageMotionBlurMultiplier

        out_node.xray = source_obj.xray
        out_node.boxMode = source_obj.boxMode
        out_node.allEdges = source_obj.allEdges
        out_node.vertexTicks = source_obj.vertexTicks
        out_node.backFaceCull = source_obj.backFaceCull
        out_node.showTrajectory = source_obj.showTrajectory

        out_node.visibility = source_obj.visibility
        out_node.isNodeHidden = source_obj.isNodeHidden
        out_node.isNodeFrozen = source_obj.isNodeFrozen

        user_property_buffer = getUserPropBuffer source_obj
        setUserPropBuffer out_node user_property_buffer

        true
        -- return
    ),

    /* Convert one float into a bit-exact key component.
       Zero is normalized so +0.0 and -0.0 weld as the same exact position. */
    function exactFloatKey value =
    (
        if value == 0.0 then
        (
            "0"
        )
        else
        (
            (bit.floatAsInt value) as string
        )
        -- return
    ),

    /* Build a bit-exact position key.
       This is the logical equivalent of a 0.0 weld threshold without tolerance drift. */
    function exactPointKey position =
    (
        (exactFloatKey position.x) + "|" + (exactFloatKey position.y) + "|" + (exactFloatKey position.z)
        -- return
    ),

    /* Return one canonical vertex ID for an exact source position.
       No tolerance is used and no source face point is moved. */
    function getOrCreateExactVertexId key_position stored_position position_table canonical_positions =
    (
        position_key = exactPointKey key_position

        if position_table.ContainsKey position_key then
        (
            position_table.Item[position_key]
        )
        else
        (
            append canonical_positions stored_position
            canonical_id = canonical_positions.count
            position_table.Add position_key canonical_id
            canonical_id
        )
        -- return
    ),

    /* Remove only repeated consecutive vertex IDs from one face loop while preserving source-corner mapping.
       Non-consecutive repeats remain detectable as a degenerate polygon. */
    function cleanExactLoopData source_loop source_corner_ids =
    (
        clean_loop = #()
        clean_corner_ids = #()

        for loop_index = 1 to source_loop.count do
        (
            vertex_id = source_loop[loop_index]

            if clean_loop.count == 0 or clean_loop[clean_loop.count] != vertex_id then
            (
                append clean_loop vertex_id
                append clean_corner_ids source_corner_ids[loop_index]
            )
        )

        if clean_loop.count > 1 and clean_loop[1] == clean_loop[clean_loop.count] then
        (
            deleteItem clean_loop clean_loop.count
            deleteItem clean_corner_ids clean_corner_ids.count
        )

        #(clean_loop, clean_corner_ids)
        -- return
    ),

    /* Count unique vertex IDs in one polygon loop.
       Used to reject self-collapsed source faces after exact-position welding. */
    function countUniqueLoopVerts vertex_loop =
    (
        unique_ids = #()

        for vertex_id in vertex_loop do
        (
            if (findItem unique_ids vertex_id) == 0 then
            (
                append unique_ids vertex_id
            )
        )

        unique_ids.count
        -- return
    ),

    /* Calculate an ordered polygon normal with Newell's method.
       The vector direction follows the source face winding. */
    function getLoopNormal vertex_loop canonical_positions =
    (
        normal_value = [0.0,0.0,0.0]

        if vertex_loop.count >= 3 then
        (
            for loop_id = 1 to vertex_loop.count do
            (
                next_id = loop_id + 1

                if next_id > vertex_loop.count then
                (
                    next_id = 1
                )

                point_a = canonical_positions[vertex_loop[loop_id]]
                point_b = canonical_positions[vertex_loop[next_id]]

                normal_value.x += (point_a.y - point_b.y) * (point_a.z + point_b.z)
                normal_value.y += (point_a.z - point_b.z) * (point_a.x + point_b.x)
                normal_value.z += (point_a.x - point_b.x) * (point_a.y + point_b.y)
            )
        )

        normal_value
        -- return
    ),

    /* Compute polygon area from an ordered point loop.
       Zero area means the whole polygon is degenerate and should be discarded. */
    function getPointLoopArea face_points =
    (
        if face_points == undefined or face_points.count < 3 then
        (
            0.0
        )
        else
        (
            area_vector = [0.0,0.0,0.0]
            origin_point = face_points[1]

            for point_index = 1 to face_points.count do
            (
                next_index = if point_index == face_points.count then 1 else point_index + 1
                point_a = face_points[point_index] - origin_point
                point_b = face_points[next_index] - origin_point
                area_vector += cross point_a point_b
            )

            0.5 * (length area_vector)
        )
        -- return
    ),

    /* Return true when any three polygon vertices are effectively collinear.
       This follows the shared Degenerate Face Selector test and is used only to repair internal triangulation. */
    function hasCollinearLoopTriple vertex_loop canonical_positions ratio_tolerance:0.000001 =
    (
        if vertex_loop == undefined or vertex_loop.count < 4 then
        (
            false
        )
        else
        (
            found_collinear = false

            for index_a = 1 to vertex_loop.count - 2 while not found_collinear do
            (
                for index_b = index_a + 1 to vertex_loop.count - 1 while not found_collinear do
                (
                    for index_c = index_b + 1 to vertex_loop.count while not found_collinear do
                    (
                        point_a = canonical_positions[vertex_loop[index_a]]
                        point_b = canonical_positions[vertex_loop[index_b]]
                        point_c = canonical_positions[vertex_loop[index_c]]
                        vector_ab = point_b - point_a
                        vector_ac = point_c - point_a
                        length_ab = length vector_ab
                        length_ac = length vector_ac
                        scale_value = if length_ab > length_ac then length_ab else length_ac

                        if scale_value > 0.000000000001 then
                        (
                            collinear_ratio = (length (cross vector_ab vector_ac)) / (scale_value * scale_value)

                            if collinear_ratio <= ratio_tolerance then
                            (
                                found_collinear = true
                            )
                        )
                    )
                )
            )

            found_collinear
        )
        -- return
    ),

    /* Build one rotation-dependent key for a loop.
       start_index and reverse_order define which cyclic representation is emitted. */
    function loopRotationKey vertex_loop start_index reverse_order:false =
    (
        key_value = ""
        loop_count = vertex_loop.count

        for offset_id = 0 to (loop_count - 1) do
        (
            if reverse_order then
            (
                source_index = start_index - offset_id

                while source_index < 1 do
                (
                    source_index += loop_count
                )
            )
            else
            (
                source_index = start_index + offset_id

                while source_index > loop_count do
                (
                    source_index -= loop_count
                )
            )

            key_value += (vertex_loop[source_index] as string) + "|"
        )

        key_value
        -- return
    ),

    /* Build an orientation-independent exact face key.
       Cyclic rotations and reversed winding of the same geometric polygon compare equal. */
    function exactFaceKey vertex_loop =
    (
        best_key = undefined

        for start_index = 1 to vertex_loop.count do
        (
            forward_key = loopRotationKey vertex_loop start_index reverse_order:false
            reverse_key = loopRotationKey vertex_loop start_index reverse_order:true

            if best_key == undefined or forward_key < best_key then
            (
                best_key = forward_key
            )

            if reverse_key < best_key then
            (
                best_key = reverse_key
            )
        )

        best_key
        -- return
    ),

    /* Return ordered world-space points for one polygon on the temporary Editable Poly source.
       This is adapted from the uploaded Degenerate Face Selector working method. */
    function getDegenerateFaceWorldPoints source_node source_poly face_id =
    (
        face_vertices = polyop.getFaceVerts source_poly face_id

        if face_vertices == undefined or face_vertices.count < 3 then
        (
            undefined
        )
        else
        (
            face_points = #()
            valid_points = true

            for vertex_id in face_vertices while valid_points do
            (
                vertex_point = undefined

                in coordsys world
                (
                    vertex_point = polyop.getVert source_node vertex_id
                )

                if vertex_point == undefined then
                (
                    valid_points = false
                )
                else
                (
                    append face_points vertex_point
                )
            )

            if valid_points then face_points else undefined
        )
        -- return
    ),

    /* Return the longest polygon-boundary segment in one ordered point loop.
       Hidden triangulation diagonals are intentionally ignored. */
    function getDegenerateFaceLongestBoundary face_points =
    (
        if face_points == undefined or face_points.count < 2 then
        (
            0.0
        )
        else
        (
            longest_edge = 0.0

            for point_id = 1 to face_points.count do
            (
                next_id = if point_id == face_points.count then 1 else point_id + 1
                edge_length = distance face_points[point_id] face_points[next_id]

                if edge_length > longest_edge then
                (
                    longest_edge = edge_length
                )
            )

            longest_edge
        )
        -- return
    ),

    /* Detect degenerate/sliver polygons before any weld or rebuild operation.
       The thresholds and area/longest-edge quality test follow the uploaded working selector. */
    function findDegenerateFacesFirst source_node source_poly sliver_ratio:0.001 =
    (
        degenerate_faces = #{}
        face_count = polyop.getNumFaces source_poly

        for face_id = 1 to face_count do
        (
            face_points = getDegenerateFaceWorldPoints source_node source_poly face_id

            if face_points == undefined then
            (
                degenerate_faces[face_id] = true
            )
            else
            (
                face_area = getPointLoopArea face_points
                longest_edge = getDegenerateFaceLongestBoundary face_points
                quality_value = 0.0

                if longest_edge > degenerate_length_epsilon then
                (
                    quality_value = face_area / (longest_edge * longest_edge)
                )

                if face_area <= degenerate_area_epsilon or longest_edge <= degenerate_length_epsilon or quality_value <= sliver_ratio then
                (
                    degenerate_faces[face_id] = true
                )
            )
        )

        degenerate_faces
        -- return
    ),

    /* Delete all detected degenerate faces on the disposable evaluated copy before any other topology cleanup.
       Selection and DeleteFace use the same Edit Poly workflow as the uploaded proven method; the source object is never touched. */
    function deleteDegenerateFacesFirst source_poly_obj =
    (
        deleted_count = 0

        if source_poly_obj != undefined and isValidNode source_poly_obj and classOf source_poly_obj.baseObject == Editable_Poly then
        (
            source_poly = source_poly_obj.baseObject
            source_poly.showCage = off
            degenerate_faces = findDegenerateFacesFirst source_poly_obj source_poly sliver_ratio:degenerate_sliver_ratio
            deleted_count = degenerate_faces.numberSet

            if deleted_count > 0 then
            (
                delete_modifier = Edit_Poly name:"DELETE DEGENERATE FACES"
                addModifier source_poly_obj delete_modifier
                delete_modifier.selectMode = 0
                delete_modifier.showCage = false
                delete_modifier.useStackSelection = false
                delete_modifier.SetPrimaryNode source_poly_obj

                select source_poly_obj
                max modify mode
                modPanel.setCurrentObject delete_modifier node:source_poly_obj
                delete_modifier.SetEPolySelLevel #Face
                subObjectLevel = 4
                delete_modifier.Select #Face degenerate_faces
                update source_poly_obj

                delete_modifier.ButtonOp #DeleteFace
                update source_poly_obj
                subObjectLevel = 0

                collapseStack source_poly_obj
                convertTo source_poly_obj Editable_Poly
                source_poly_obj.baseObject.showCage = off
                update source_poly_obj
            )
        )

        deleted_count
        -- return
    ),

    /* Collapse a temporary evaluated copy to Editable Poly.
       The source object and its modifier stack remain untouched. */
    function createEvaluatedPolyCopy source_obj =
    (
        temp_obj = undefined

        try
        (
            temp_obj = copy source_obj
            temp_obj.name = uniqueName "__REBUILD_FACE_SOURCE"
            convertTo temp_obj Editable_Poly
        )
        catch
        (
            if temp_obj != undefined then
            (
                delete temp_obj
            )

            temp_obj = undefined
        )

        temp_obj
        -- return
    ),

    /* Read the evaluated Editable Poly face loops exactly as they exist.
       Whole zero-area polygons are discarded; non-zero-area polygons remain authoritative. */
    function buildFaceSafeRecords source_poly source_node source_obj =
    (
        source_vert_count = polyop.getNumVerts source_poly
        source_face_count = polyop.getNumFaces source_poly
        inverse_source_tm = inverse source_obj.transform

        position_table = dotNetObject "System.Collections.Hashtable"
        face_table = dotNetObject "System.Collections.Hashtable"

        canonical_positions = #()
        face_records = #()

        degenerate_count = 0
        duplicate_face_count = 0

        for face_id = 1 to source_face_count do
        (
            source_vertex_loop = polyop.getFaceVerts source_poly face_id
            canonical_loop = #()
            source_corner_ids = #()

            for source_corner_id = 1 to source_vertex_loop.count do
            (
                source_vertex_id = source_vertex_loop[source_corner_id]
                source_world_position = [0.0,0.0,0.0]

                in coordsys world
                (
                    source_world_position = polyop.getVert source_node source_vertex_id
                )

                source_local_position = source_world_position * inverse_source_tm
                canonical_id = getOrCreateExactVertexId source_world_position source_local_position position_table canonical_positions
                append canonical_loop canonical_id
                append source_corner_ids source_corner_id
            )

            clean_data = cleanExactLoopData canonical_loop source_corner_ids
            canonical_loop = clean_data[1]
            source_corner_ids = clean_data[2]

            unique_count = countUniqueLoopVerts canonical_loop
            is_degenerate = canonical_loop.count < 3 or unique_count != canonical_loop.count

            if not is_degenerate then
            (
                loop_points = for canonical_id in canonical_loop collect canonical_positions[canonical_id]

                if (getPointLoopArea loop_points) <= 0.000000000001 then
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
                face_key = exactFaceKey canonical_loop

                if face_table.ContainsKey face_key then
                (
                    duplicate_face_count += 1
                )
                else
                (
                    face_table.Add face_key true

                    append face_records #(
                        canonical_loop,
                        face_id,
                        polyop.getFaceMatID source_poly face_id,
                        polyop.getFaceSmoothGroup source_poly face_id,
                        false,
                        source_corner_ids,
                        false
                    )
                )
            )
        )

        removed_vertex_count = source_vert_count - canonical_positions.count

        #(canonical_positions, face_records, removed_vertex_count, degenerate_count, duplicate_face_count)
        -- return
    ),

    /* Remove straight vertices that have exactly two polygon-boundary neighbors after the exact weld.
       A-V-B becomes A-B without moving either neighbor; faces that collapse below valid polygon area are deleted. */
    function removeTwoEdgeVertsAfterExactWeld face_records canonical_positions angle_tolerance:0.01 =
    (
        working_records = face_records
        total_removed_vertex_count = 0
        total_degenerate_face_count = 0
        total_duplicate_face_count = 0
        cleanup_pass = 0
        continue_cleanup = true

        while continue_cleanup and cleanup_pass < 64 do
        (
            cleanup_pass += 1
            neighbor_lists = for vertex_id = 1 to canonical_positions.count collect #()

            for face_record in working_records do
            (
                vertex_loop = face_record[1]

                for loop_id = 1 to vertex_loop.count do
                (
                    next_id = if loop_id == vertex_loop.count then 1 else loop_id + 1
                    vertex_a = vertex_loop[loop_id]
                    vertex_b = vertex_loop[next_id]

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

            if removable_vertices.numberSet == 0 then
            (
                continue_cleanup = false
            )
            else
            (
                clean_records = #()
                face_table = dotNetObject "System.Collections.Hashtable"

                for face_record in working_records do
                (
                    source_loop = face_record[1]
                    source_corner_ids = face_record[6]
                    clean_loop = #()
                    clean_corner_ids = #()

                    for loop_id = 1 to source_loop.count do
                    (
                        vertex_id = source_loop[loop_id]

                        if not removable_vertices[vertex_id] then
                        (
                            append clean_loop vertex_id
                            append clean_corner_ids source_corner_ids[loop_id]
                        )
                    )

                    unique_count = countUniqueLoopVerts clean_loop
                    valid_face = clean_loop.count >= 3 and unique_count == clean_loop.count

                    if valid_face then
                    (
                        clean_points = for canonical_id in clean_loop collect canonical_positions[canonical_id]
                        valid_face = (getPointLoopArea clean_points) > 0.000000000001
                    )

                    if valid_face then
                    (
                        face_key = exactFaceKey clean_loop

                        if face_table.ContainsKey face_key then
                        (
                            total_duplicate_face_count += 1
                        )
                        else
                        (
                            face_table.Add face_key true
                            clean_record = copy face_record
                            clean_record[1] = clean_loop
                            clean_record[6] = clean_corner_ids
                            clean_record[7] = false
                            append clean_records clean_record
                        )
                    )
                    else
                    (
                        total_degenerate_face_count += 1
                    )
                )

                total_removed_vertex_count += removable_vertices.numberSet
                working_records = clean_records

                if working_records.count == 0 then
                (
                    continue_cleanup = false
                )
            )
        )

        for face_id = 1 to working_records.count do
        (
            face_record = working_records[face_id]
            face_record[7] = face_record[1].count > 3 and hasCollinearLoopTriple face_record[1] canonical_positions
            working_records[face_id] = face_record
        )

        #(working_records, total_removed_vertex_count, total_degenerate_face_count, total_duplicate_face_count)
        -- return
    ),

    /* Build edge adjacency and make connected neighboring polygons use consistent winding.
       The first face in each connected component keeps its source winding; neighbors follow it. */
    function orientFaceSafeRecords face_records =
    (
        edge_table = dotNetObject "System.Collections.Hashtable"
        edge_records = #()
        adjacency = for face_id = 1 to face_records.count collect #()

        for face_id = 1 to face_records.count do
        (
            vertex_loop = face_records[face_id][1]

            for loop_id = 1 to vertex_loop.count do
            (
                next_id = loop_id + 1

                if next_id > vertex_loop.count then
                (
                    next_id = 1
                )

                vertex_a = vertex_loop[loop_id]
                vertex_b = vertex_loop[next_id]
                edge_key = edgeKey vertex_a vertex_b
                edge_direction = if vertex_a < vertex_b then 1 else -1

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
                append edge_uses #(face_id, edge_direction)
                edge_record[2] = edge_uses
                edge_records[edge_record_index] = edge_record
            )
        )

        shared_edge_count = 0
        nonmanifold_edge_count = 0

        for edge_record in edge_records do
        (
            edge_uses = edge_record[2]

            if edge_uses.count == 2 then
            (
                shared_edge_count += 1

                use_a = edge_uses[1]
                use_b = edge_uses[2]
                needs_different_flip = use_a[2] == use_b[2]

                adjacency_a = adjacency[use_a[1]]
                append adjacency_a #(use_b[1], needs_different_flip)
                adjacency[use_a[1]] = adjacency_a

                adjacency_b = adjacency[use_b[1]]
                append adjacency_b #(use_a[1], needs_different_flip)
                adjacency[use_b[1]] = adjacency_b
            )
            else if edge_uses.count > 2 then
            (
                nonmanifold_edge_count += 1
            )
        )

        flip_states = for face_id = 1 to face_records.count collect undefined
        reoriented_count = 0
        orientation_conflict_count = 0

        for seed_face_id = 1 to face_records.count do
        (
            if flip_states[seed_face_id] == undefined then
            (
                flip_states[seed_face_id] = false
                queue_values = #(seed_face_id)

                while queue_values.count > 0 do
                (
                    current_face_id = queue_values[1]
                    deleteItem queue_values 1
                    current_flip = flip_states[current_face_id]

                    for neighbor_record in adjacency[current_face_id] do
                    (
                        neighbor_face_id = neighbor_record[1]
                        needs_different_flip = neighbor_record[2]
                        expected_flip = if needs_different_flip then (not current_flip) else current_flip

                        if flip_states[neighbor_face_id] == undefined then
                        (
                            flip_states[neighbor_face_id] = expected_flip
                            append queue_values neighbor_face_id
                        )
                        else if flip_states[neighbor_face_id] != expected_flip then
                        (
                            orientation_conflict_count += 1
                        )
                    )
                )
            )
        )

        for face_id = 1 to face_records.count do
        (
            if flip_states[face_id] == true then
            (
                face_record = face_records[face_id]
                source_loop = face_record[1]
                source_corner_ids = face_record[6]
                reversed_loop = for loop_id = source_loop.count to 1 by -1 collect source_loop[loop_id]
                reversed_corner_ids = for loop_id = source_corner_ids.count to 1 by -1 collect source_corner_ids[loop_id]

                face_record[1] = reversed_loop
                face_record[5] = true
                face_record[6] = reversed_corner_ids
                face_records[face_id] = face_record
                reoriented_count += 1
            )
        )

        #(face_records, reoriented_count, shared_edge_count, nonmanifold_edge_count, orientation_conflict_count)
        -- return
    ),

    /* Copy source map channels face-by-face using the surviving source-corner IDs.
       This keeps UV corners aligned when straight degree-two geometry corners are removed. */
    function rebuildFaceSafeMaps out_poly source_poly created_face_records =
    (
        source_num_maps = polyop.getNumMaps source_poly
        rebuilt_channel_count = 0

        if source_num_maps > 0 and created_face_records.count > 0 then
        (
            polyop.setNumMaps out_poly source_num_maps keep:false

            for map_channel = 0 to (source_num_maps - 1) do
            (
                if polyop.getMapSupport source_poly map_channel then
                (
                    source_map_vert_count = polyop.getNumMapVerts source_poly map_channel

                    if source_map_vert_count > 0 then
                    (
                        total_corner_count = 0
                        channel_valid = true

                        for face_record in created_face_records while channel_valid do
                        (
                            source_face_id = face_record[2]
                            source_corner_ids = face_record[3]
                            source_map_face = polyop.getMapFace source_poly map_channel source_face_id

                            for source_corner_id in source_corner_ids while channel_valid do
                            (
                                if source_corner_id < 1 or source_corner_id > source_map_face.count then
                                (
                                    channel_valid = false
                                )
                            )

                            if channel_valid then
                            (
                                total_corner_count += source_corner_ids.count
                            )
                        )

                        if channel_valid and total_corner_count > 0 then
                        (
                            polyop.setMapSupport out_poly map_channel true
                            polyop.setNumMapVerts out_poly map_channel total_corner_count keep:false
                            next_map_vertex_id = 1

                            for face_record in created_face_records do
                            (
                                output_face_id = face_record[1]
                                source_face_id = face_record[2]
                                source_corner_ids = face_record[3]
                                source_map_face = polyop.getMapFace source_poly map_channel source_face_id
                                output_map_face = #()

                                for source_corner_id in source_corner_ids do
                                (
                                    source_map_vertex_id = source_map_face[source_corner_id]
                                    map_position = polyop.getMapVert source_poly map_channel source_map_vertex_id
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

    /* Return one wrapped point chain between two polygon corners.
       Used to score candidate internal diagonals without changing the polygon boundary. */
    function getWrappedPointChain face_points start_index end_index =
    (
        result_points = #()

        if face_points == undefined or face_points.count < 3 or start_index < 1 or end_index < 1 then
        (
            result_points
        )
        else
        (
            current_index = start_index
            append result_points face_points[current_index]
            safety_count = 0

            while current_index != end_index and safety_count <= face_points.count do
            (
                current_index += 1

                if current_index > face_points.count then
                (
                    current_index = 1
                )

                append result_points face_points[current_index]
                safety_count += 1
            )

            result_points
        )
        -- return
    ),

    /* Find the healthiest non-adjacent diagonal for one rebuilt polygon.
       The chosen diagonal maximizes the smaller area of the two polygon halves. */
    function findBestPolyFaceDiagonal out_poly face_id =
    (
        vertex_ids = polyop.getFaceVerts out_poly face_id

        if vertex_ids == undefined or vertex_ids.count < 4 then
        (
            undefined
        )
        else
        (
            face_points = for vertex_id in vertex_ids collect polyop.getVert out_poly vertex_id
            best_pair = undefined
            best_score = -1.0
            point_count = face_points.count

            for index_a = 1 to point_count - 1 do
            (
                for index_b = index_a + 1 to point_count do
                (
                    adjacent_pair = index_b == (index_a + 1) or (index_a == 1 and index_b == point_count)

                    if not adjacent_pair then
                    (
                        chain_a = getWrappedPointChain face_points index_a index_b
                        chain_b = getWrappedPointChain face_points index_b index_a

                        if chain_a.count >= 3 and chain_b.count >= 3 then
                        (
                            area_a = getPointLoopArea chain_a
                            area_b = getPointLoopArea chain_b
                            split_score = if area_a < area_b then area_a else area_b

                            if split_score > best_score then
                            (
                                best_score = split_score
                                best_pair = #(vertex_ids[index_a], vertex_ids[index_b], split_score)
                            )
                        )
                    )
                )
            )

            best_pair
        )
        -- return
    ),

    /* Repair internal triangulation of one non-zero-area polygon that still contains a collinear triangle candidate.
       Retriangulate is followed by SetDiagonal using the healthiest available non-adjacent vertex pair. */
    function fixPolyFaceTriangulation out_poly face_id =
    (
        retriangulated = false
        diagonal_set = false

        if face_id >= 1 and face_id <= (polyop.getNumFaces out_poly) and (polyop.getFaceDeg out_poly face_id) > 3 then
        (
            face_bits = #{}
            face_bits[face_id] = true

            try
            (
                polyop.retriangulate out_poly face_bits
                retriangulated = true
            )
            catch
            (
                retriangulated = false
            )

            diagonal_data = findBestPolyFaceDiagonal out_poly face_id

            if diagonal_data != undefined and diagonal_data[3] > 0.000000000001 then
            (
                try
                (
                    polyop.setDiagonal out_poly face_id diagonal_data[1] diagonal_data[2]
                    diagonal_set = true
                )
                catch
                (
                    diagonal_set = false
                )
            )
        )

        #(retriangulated, diagonal_set)
        -- return
    ),

    /* Create a clean Editable Poly directly from source polygon loops.
       Shared topology is created only when source face corners have bit-exactly equal positions. */
    function createFaceSafeOutput source_obj source_poly canonical_positions face_records rebuild_maps:true =
    (
        output_name = uniqueName (source_obj.name + "_REBUILT")
        out_node = editable_mesh name:output_name
        convertTo out_node Editable_Poly

        out_poly = out_node.baseObject
        out_poly.showCage = off

        for position in canonical_positions do
        (
            polyop.createVert out_poly position
        )

        created_face_records = #()
        failed_face_count = 0
        retriangulated_face_count = 0
        diagonal_fixed_face_count = 0

        for face_record in face_records do
        (
            canonical_loop = face_record[1]
            output_face_id = polyop.createPolygon out_poly canonical_loop

            if output_face_id != undefined then
            (
                polyop.setFaceMatID out_poly output_face_id face_record[3]
                polyop.setFaceSmoothGroup out_poly output_face_id face_record[4]

                if face_record[7] then
                (
                    triangulation_result = fixPolyFaceTriangulation out_poly output_face_id

                    if triangulation_result[1] then
                    (
                        retriangulated_face_count += 1
                    )

                    if triangulation_result[2] then
                    (
                        diagonal_fixed_face_count += 1
                    )
                )

                append created_face_records #(
                    output_face_id,
                    face_record[2],
                    face_record[6]
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
            rebuilt_channel_count = rebuildFaceSafeMaps out_poly source_poly created_face_records
            update out_node
        )

        out_node.transform = source_obj.transform
        copySourceNodeBehavior source_obj out_node

        #(out_node, failed_face_count, rebuilt_channel_count, created_face_records.count, retriangulated_face_count, diagonal_fixed_face_count)
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
        copySourceNodeBehavior source_obj out_node

        #(out_node, failed_face_count, rebuilt_channel_count, created_face_records.count)
        -- return
    ),

    /* Rebuild the selected evaluated polygons without inferring new polygon boundaries.
       Source faces are treated as isolated islands, exact-position vertices are merged, and neighbor winding is preserved. */
    function rebuildSelected rebuild_maps:true =
    (
        result_node = undefined
        source_poly_obj = undefined

        if selection.count != 1 then
        (
            messageBox "Select exactly one geometry object." title:("Rebuild Mesh " + version)
        )
        else
        (
            source_obj = selection[1]
            source_poly_obj = createEvaluatedPolyCopy source_obj

            if source_poly_obj == undefined then
            (
                messageBox "Could not evaluate the selected object as Editable Poly." title:("Rebuild Mesh " + version)
            )
            else
            (
                source_poly = source_poly_obj.baseObject
                source_face_count = polyop.getNumFaces source_poly

                if source_face_count == 0 then
                (
                    delete source_poly_obj
                    source_poly_obj = undefined

                    messageBox "The evaluated Editable Poly has no faces." title:("Rebuild Mesh " + version)
                )
                else
                (
                    /* FIRST TOPOLOGY ACTION: delete degenerate faces before exact weld, duplicate cleanup or 2-edge cleanup. */
                    first_pass_degenerate_count = deleteDegenerateFacesFirst source_poly_obj
                    source_poly = source_poly_obj.baseObject
                    clean_source_face_count = polyop.getNumFaces source_poly

                    if clean_source_face_count == 0 then
                    (
                        delete source_poly_obj
                        source_poly_obj = undefined

                        messageBox "No faces remain after the first degenerate-face deletion pass." title:("Rebuild Mesh " + version)
                    )
                    else
                    (
                    face_safe_data = buildFaceSafeRecords source_poly source_poly_obj source_obj
                    canonical_positions = face_safe_data[1]
                    face_records = face_safe_data[2]
                    exact_removed_vertex_count = face_safe_data[3]
                    degenerate_count = face_safe_data[4]
                    duplicate_face_count = face_safe_data[5]

                    two_edge_cleanup_data = removeTwoEdgeVertsAfterExactWeld face_records canonical_positions
                    face_records = two_edge_cleanup_data[1]
                    two_edge_removed_count = two_edge_cleanup_data[2]
                    degenerate_count += two_edge_cleanup_data[3]
                    duplicate_face_count += two_edge_cleanup_data[4]

                    orientation_data = orientFaceSafeRecords face_records
                    face_records = orientation_data[1]
                    reoriented_count = orientation_data[2]
                    shared_edge_count = orientation_data[3]
                    nonmanifold_edge_count = orientation_data[4]
                    orientation_conflict_count = orientation_data[5]

                    if face_records.count == 0 then
                    (
                        delete source_poly_obj
                        source_poly_obj = undefined

                        messageBox "No valid polygons remain after exact cleanup." title:("Rebuild Mesh " + version)
                    )
                    else
                    (
                        output_data = undefined

                        undo label:("Rebuild Mesh " + version) on
                        (
                            output_data = createFaceSafeOutput source_obj source_poly canonical_positions face_records rebuild_maps:rebuild_maps
                        )

                        if output_data != undefined then
                        (
                            result_node = output_data[1]
                            failed_face_count = output_data[2]
                            rebuilt_channel_count = output_data[3]
                            created_face_count = output_data[4]
                            retriangulated_face_count = output_data[5]
                            diagonal_fixed_face_count = output_data[6]
                        )

                        delete source_poly_obj
                        source_poly_obj = undefined

                        if result_node != undefined then
                        (
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

                                format "\n--- Rebuild Mesh % | FACE SAFE ---\n" version
                                format "Source: %\n" source_obj.name
                                format "Source polygons before degenerate pass: %\n" source_face_count
                                format "FIRST PASS degenerate polygons deleted: %\n" first_pass_degenerate_count
                                format "Polygons after degenerate pass: %\n" clean_source_face_count
                                format "Exact duplicate / unused verts removed: %\n" exact_removed_vertex_count
                                format "Additional degenerate polygons skipped after weld/cleanup: %\n" degenerate_count
                                format "Duplicate polygons skipped: %\n" duplicate_face_count
                                format "Straight 2-edge verts removed after exact weld: %\n" two_edge_removed_count
                                format "Shared exact edges: %\n" shared_edge_count
                                format "Collinear polygons retriangulated: %\n" retriangulated_face_count
                                format "Healthy diagonals explicitly set: %\n" diagonal_fixed_face_count
                                format "Faces reoriented to neighbor winding: %\n" reoriented_count
                                format "Non-manifold exact edges: %\n" nonmanifold_edge_count
                                format "Orientation conflicts: %\n" orientation_conflict_count
                                format "Polygon creation failures: %\n" failed_face_count
                                format "Map channels rebuilt: %\n" rebuilt_channel_count
                                format "Output verts: %, output polygons: %\n" (polyop.getNumVerts result_node) (polyop.getNumFaces result_node)
                                format "Output: %\n" result_node.name
                                format "------------------------------------\n\n"
                            )
                        )
                    )
                    )
                )
            )
        )

        if source_poly_obj != undefined then
        (
            delete source_poly_obj
        )

        result_node
        -- return
    ),

    /* Create a face-safe regression object for exact weld, degenerate deletion, 2-edge cleanup and triangulation repair.
       The source contains duplicate seam verts, one straight degree-two boundary vertex, one zero-area triangle and one collinear n-gon corner. */
    function createTestMesh =
    (
        test_name = uniqueName "REBUILD_TEST"
        test_obj = editable_mesh name:test_name
        convertTo test_obj Editable_Poly
        test_poly = test_obj.baseObject
        test_poly.showCage = off

        vertex_positions = #(
            [0,0,0],
            [25,0,0],
            [50,0,0],
            [50,100,0],
            [0,100,0],
            [50,0,0],
            [100,0,0],
            [100,100,0],
            [50,100,0],
            [0,150,0],
            [25,150,0],
            [50,150,0],
            [0,200,0],
            [25,200,0],
            [50,200,0],
            [50,250,0],
            [0,250,0],
            [25,180,0],
            [35,180,0]
        )

        for position in vertex_positions do
        (
            polyop.createVert test_poly position
        )

        face_a = polyop.createPolygon test_poly #(1,2,3,4,5)
        face_b = polyop.createPolygon test_poly #(6,7,8,9)
        face_zero = polyop.createPolygon test_poly #(10,11,12)
        face_collinear = polyop.createPolygon test_poly #(13,14,15,16,17)
        face_support = polyop.createPolygon test_poly #(14,18,19)

        for face_id in #(face_a,face_b,face_zero,face_collinear,face_support) do
        (
            if face_id != undefined then
            (
                polyop.setFaceMatID test_poly face_id 1
                polyop.setFaceSmoothGroup test_poly face_id 0
            )
        )

        update test_obj

        test_layer = LayerManager.getLayerFromName "REBUILD_TEST_LAYER"

        if test_layer == undefined then
        (
            test_layer = LayerManager.newLayerFromName "REBUILD_TEST_LAYER"
        )

        test_layer.addNode test_obj

        test_obj.pos = [250.0,125.0,40.0]
        test_obj.rotation = quat 27.0 [0.0,0.0,1.0]
        test_obj.pivot = [235.0,110.0,32.0]
        test_obj.backFaceCull = true
        test_obj.allEdges = true
        test_obj.gbufferChannel = 17
        setUserProp test_obj "REBUILD_TEST_PROP" "SOURCE_BEHAVIOR"

        select test_obj
        max modify mode

        format "\nRebuild Mesh 0.10 TEST created: %\n" test_obj.name
        format "Expected cleanup: FIRST PASS deletes the zero-area face, then exact seam weld, straight 2-edge midpoint removal and collinear n-gon retriangulation.\n"
        format "Source placement, pivot, layer and node behavior must remain unchanged on *_REBUILT.\n\n"

        test_obj
        -- return
    ),

    /* Load the saved Rebuild Maps checkbox value.
       Missing or invalid INI state falls back to enabled. */
    function loadRebuildMapsSetting =
    (
        saved_value = getINISetting rebuild_mesh_ini "Settings" "RebuildMaps"

        if saved_value == "0" or saved_value == "false" then
        (
            false
        )
        else
        (
            true
        )
        -- return
    ),

    /* Load the last saved dialog position.
       Missing coordinates return undefined so 3ds Max can choose a safe default. */
    function loadDialogPos =
    (
        x_text = getINISetting rebuild_mesh_ini "UI" "X"
        y_text = getINISetting rebuild_mesh_ini "UI" "Y"

        if x_text == "" or y_text == "" then
        (
            undefined
        )
        else
        (
            [x_text as integer, y_text as integer]
        )
        -- return
    ),

    /* Save user-facing dialog state to the 3ds Max plugcfg folder.
       The checkbox and dialog position survive RESTART and later tool sessions. */
    function saveDialogState rebuild_maps_value:undefined =
    (
        if rebuild_maps_value != undefined then
        (
            setINISetting rebuild_mesh_ini "Settings" "RebuildMaps" (if rebuild_maps_value then "1" else "0")
        )

        try
        (
            dialog_pos = getDialogPos rebuildMeshRollout
            setINISetting rebuild_mesh_ini "UI" "X" (dialog_pos.x as string)
            setINISetting rebuild_mesh_ini "UI" "Y" (dialog_pos.y as string)
        )
        catch
        (
        )

        true
        -- return
    ),

    /* Return true only for a simple numeric version suffix such as 0.09 or 0.9991. */
    function isVersionText version_text =
    (
        valid_value = version_text != undefined and version_text != ""
        digit_count = 0
        dot_count = 0

        if valid_value then
        (
            for char_index = 1 to version_text.count while valid_value do
            (
                char_value = version_text[char_index]

                if char_value == "." then
                (
                    dot_count += 1

                    if dot_count > 1 then
                    (
                        valid_value = false
                    )
                )
                else if findString "0123456789" char_value != undefined then
                (
                    digit_count += 1
                )
                else
                (
                    valid_value = false
                )
            )
        )

        valid_value and digit_count > 0
        -- return
    ),

    /* Strip a trailing numeric _version suffix from one script stem.
       Tool names containing other underscores remain intact. */
    function getVersionBaseName file_stem =
    (
        last_underscore = 0

        for char_index = 1 to file_stem.count do
        (
            if file_stem[char_index] == "_" then
            (
                last_underscore = char_index
            )
        )

        base_name = file_stem

        if last_underscore > 1 and last_underscore < file_stem.count then
        (
            suffix_text = substring file_stem (last_underscore + 1) (file_stem.count - last_underscore)

            if isVersionText suffix_text then
            (
                base_name = substring file_stem 1 (last_underscore - 1)
            )
        )

        base_name
        -- return
    ),

    /* Find the newest matching versioned script beside the currently running script.
       A newer versioned file wins; otherwise the currently running file is reloaded. */
    function getLatestRestartScriptPath =
    (
        source_file = getSourceFileName()

        if source_file == undefined or source_file == "" or not doesFileExist source_file then
        (
            undefined
        )
        else
        (
            source_folder = getFilenamePath source_file
            source_stem = getFilenameFile source_file
            base_name = getVersionBaseName source_stem
            version_prefix = base_name + "_"
            candidate_files = getFiles (source_folder + base_name + "_*.ms")
            current_version_value = version as float
            newest_version_value = current_version_value
            newest_file = undefined

            for candidate_file in candidate_files do
            (
                candidate_stem = getFilenameFile candidate_file

                if findString candidate_stem version_prefix == 1 then
                (
                    candidate_version_text = substring candidate_stem (version_prefix.count + 1) (candidate_stem.count - version_prefix.count)

                    if isVersionText candidate_version_text then
                    (
                        candidate_version_value = candidate_version_text as float

                        if candidate_version_value > newest_version_value then
                        (
                            newest_version_value = candidate_version_value
                            newest_file = candidate_file
                        )
                    )
                )
            )

            if newest_file != undefined then newest_file else source_file
        )
        -- return
    ),

    /* Save dialog state, then load the newest matching version from the current script folder.
       When no newer version exists, reload the currently running file. */
    function restartTool rebuild_maps_value:undefined =
    (
        saveDialogState rebuild_maps_value:rebuild_maps_value
        latest_script = getLatestRestartScriptPath()
        result_value = false

        if latest_script != undefined and doesFileExist latest_script then
        (
            fileIn latest_script
            result_value = true
        )
        else
        (
            messageBox "Cannot find the current or a newer Rebuild Mesh script file." title:("Rebuild Mesh " + version)
        )

        result_value
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

rollout rebuildMeshRollout rebuild_mesh_title width:330
(
    label lbl_mode_1 "FACE SAFE REBUILD"
    label lbl_mode_2 "Source polygons -> exact position weld (0.0)"
    checkbox chk_rebuild_maps "Rebuild map channels" checked:(rebuildMesh.loadRebuildMapsSetting())

    button btn_rebuild "REBUILD SELECTED" width:300 height:36
    button btn_test "CREATE TEST MESH" width:300 height:28

    label lbl_info_1 "Source object and modifier stack are never modified."
    label lbl_info_2 "Output is a clean *_REBUILT Editable Poly."
    label lbl_info_3 "FIRST: delete degenerate faces. Then exact weld and topology rebuild."

    button btn_restart "RESTART" width:300 height:28 tooltip:"LMB: Save dialog state and load the newest matching version from this folder."

    on btn_rebuild pressed do
    (
        rebuildMesh.rebuildSelected rebuild_maps:chk_rebuild_maps.checked
    )

    on btn_test pressed do
    (
        rebuildMesh.createTestMesh()
    )

    on chk_rebuild_maps changed state do
    (
        rebuildMesh.saveDialogState rebuild_maps_value:state
    )

    on btn_restart pressed do
    (
        rebuildMesh.restartTool rebuild_maps_value:chk_rebuild_maps.checked
    )

    on rebuildMeshRollout close do
    (
        rebuildMesh.saveDialogState rebuild_maps_value:chk_rebuild_maps.checked
    )
)

saved_dialog_pos = rebuildMesh.loadDialogPos()

if saved_dialog_pos == undefined then
(
    createDialog rebuildMeshRollout
)
else
(
    createDialog rebuildMeshRollout pos:saved_dialog_pos
)
