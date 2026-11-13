/*
Tank Panel Generator feature logic, version 0.087.
The logical panel mask is independent of preview geometry and user interface.
*/








/* Procedural extrusion uses native MeshOp; shared Edit Poly helpers are not loaded. */


/* Derives signed, equal-distance offset vectors for the face-region border.
   Face incidence (not positions or hidden triangulation edges) defines loops.
   Two facet-local inward edge directions form each corner miter; interior
   vertices receive no offset. Signed values move the border in or out.
   The returned array is indexed by SOURCE vertex ID; undefined means interior.
*/
global tpgGetRegionBoundaryOffsets
function tpgGetRegionBoundaryOffsets source_mesh region_faces offset_amount ring_chains:undefined =
(
    local edge_neighbors = #()
    local edge_records = #()
    local boundary_out = #()
    local boundary_in = #()
    local boundary_offsets = #()
    edge_neighbors.count = source_mesh.numverts
    boundary_out.count = source_mesh.numverts
    boundary_in.count = source_mesh.numverts
    boundary_offsets.count = source_mesh.numverts
    for face_id in region_faces do
    (
        local vertex_ids = getFace source_mesh face_id
        for corner_id = 1 to 3 do
        (
            local next_corner_id = if corner_id == 3 then 1 else corner_id + 1
            local first_id = vertex_ids[corner_id] as integer
            local second_id = vertex_ids[next_corner_id] as integer
            local lower_id = amin first_id second_id
            local upper_id = amax first_id second_id
            if edge_neighbors[lower_id] == undefined then edge_neighbors[lower_id] = #()
            local record_id = 0
            for candidate_id in edge_neighbors[lower_id] while record_id == 0 do
            (
                if edge_records[candidate_id][2] == upper_id then record_id = candidate_id
            )
            if record_id == 0 then
            (
                append edge_records #(lower_id,upper_id,1,first_id,second_id,face_id)
                append edge_neighbors[lower_id] edge_records.count
            )
            else
            (
                edge_records[record_id][3] += 1
                if edge_records[record_id][3] > 2 then
                    throw ("TPG | Non-manifold border edge: " + lower_id as string + "," + upper_id as string + " uses:" + edge_records[record_id][3] as string)
            )
        )
    )
    /* TPG source rings run across local XZ; local Y is the generator length axis.
       Build adjacency from original triangle edges, including interior ring rows.
       This uses exact source row coordinates, never world transforms or proximity matching.
    */
    if ring_chains != undefined then
    (
        local ring_neighbors = #()
        ring_neighbors.count = source_mesh.numverts
        for edge_record in edge_records do
        (
            local first_id = edge_record[1]
            local second_id = edge_record[2]
            if (getVert source_mesh first_id).y == (getVert source_mesh second_id).y then
            (
                if ring_neighbors[first_id] == undefined then ring_neighbors[first_id] = #()
                if ring_neighbors[second_id] == undefined then ring_neighbors[second_id] = #()
                append ring_neighbors[first_id] second_id
                append ring_neighbors[second_id] first_id
            )
        )
        local visited_rings = #{}
        visited_rings.count = source_mesh.numverts
        for vertex_id = 1 to ring_neighbors.count where ring_neighbors[vertex_id] != undefined do
        (
            if ring_neighbors[vertex_id].count > 2 then
                throw ("TPG | Branching taper ring at source vertex:" + vertex_id as string)
            if ring_neighbors[vertex_id].count == 1 and not visited_rings[vertex_id] then
            (
                local ring_ids = #(vertex_id)
                local previous_id = 0
                local current_id = vertex_id
                local next_id = ring_neighbors[current_id][1]
                visited_rings[current_id] = true
                while next_id != 0 do
                (
                    append ring_ids next_id
                    previous_id = current_id
                    current_id = next_id
                    visited_rings[current_id] = true
                    next_id = 0
                    for neighbor_id in ring_neighbors[current_id] where neighbor_id != previous_id do next_id = neighbor_id
                )
                if ring_ids.count > 2 then append ring_chains ring_ids
            )
        )
    )
    local boundary_vertices = #{}
    boundary_vertices.count = source_mesh.numverts
    for edge_record in edge_records where edge_record[3] == 1 do
    (
        local first_id = edge_record[4]
        local second_id = edge_record[5]
        if boundary_out[first_id] != undefined or boundary_in[second_id] != undefined then
            throw ("TPG | Branching/inconsistent border edge: " + first_id as string + "," + second_id as string)
        local edge_direction = (getVert source_mesh second_id) - (getVert source_mesh first_id)
        local face_normal = getFaceNormal source_mesh edge_record[6]
        local inward_direction = normalize (cross face_normal edge_direction)
        boundary_out[first_id] = #(second_id,inward_direction)
        boundary_in[second_id] = #(first_id,inward_direction)
        boundary_vertices[first_id] = true
        boundary_vertices[second_id] = true
    )
    for vertex_id in boundary_vertices do
    (
        if boundary_in[vertex_id] == undefined or boundary_out[vertex_id] == undefined then
            throw ("TPG | Open border loop at vertex: " + vertex_id as string)
        local first_inward = boundary_in[vertex_id][2]
        local second_inward = boundary_out[vertex_id][2]
        local denominator = 1.0 + dot first_inward second_inward
        if denominator <= 0.0 then
            throw ("TPG | Collapsed offset corner at vertex: " + vertex_id as string + " denominator:" + denominator as string)
        boundary_offsets[vertex_id] = (first_inward + second_inward) * (offset_amount / denominator)
    )
    boundary_offsets
    -- return
)

/* Redistribute one TPG upper ring with equal chord distances and fixed endpoints.
   New positions follow the pre-redistribution bent polyline; source IDs stay valid.
   The explicit project position precision bounds the spacing residual, not geometry snapping.
*/
global tpgRespaceTaperRing
function tpgRespaceTaperRing source_mesh ring_ids position_precision =
(
    local ring_points = for vertex_id in ring_ids collect (getVert source_mesh vertex_id)
    local edge_count = ring_points.count - 1
    local lower_spacing = 0.0
    local upper_spacing = 0.0
    for point_id = 1 to edge_count do upper_spacing += distance ring_points[point_id] ring_points[point_id + 1]
    upper_spacing /= edge_count
    local solved_points = undefined
    local spacing_residual = undefined
    for attempt_id = 1 to 64 while solved_points == undefined do
    (
        local trial_spacing = (lower_spacing + upper_spacing) * 0.5
        local trial_points = #(ring_points[1])
        local segment_id = 1
        local segment_fraction = 0.0
        local trial_valid = true
        for point_id = 2 to edge_count while trial_valid do
        (
            local found_point = false
            while segment_id <= edge_count and not found_point do
            (
                local segment_vector = ring_points[segment_id + 1] - ring_points[segment_id]
                local squared_length = dot segment_vector segment_vector
                if squared_length > 0.0 then
                (
                    local relative_point = ring_points[segment_id] - trial_points[trial_points.count]
                    local projection_value = dot relative_point segment_vector
                    local discriminant_value = projection_value * projection_value - squared_length * ((dot relative_point relative_point) - trial_spacing * trial_spacing)
                    if discriminant_value >= 0.0 then
                    (
                        local candidate_fraction = (-projection_value + sqrt discriminant_value) / squared_length
                        if candidate_fraction >= segment_fraction and candidate_fraction <= 1.0 then
                        (
                            append trial_points (ring_points[segment_id] + segment_vector * candidate_fraction)
                            segment_fraction = candidate_fraction
                            found_point = true
                        )
                    )
                )
                if not found_point then
                (
                    segment_id += 1
                    segment_fraction = 0.0
                )
            )
            if not found_point then trial_valid = false
        )
        if trial_valid then
        (
            spacing_residual = (distance ring_points[ring_points.count] trial_points[trial_points.count]) - trial_spacing
            if abs spacing_residual <= (position_precision * 0.5) then
            (
                append trial_points ring_points[ring_points.count]
                solved_points = trial_points
            )
            else if spacing_residual > 0.0 then lower_spacing = trial_spacing else upper_spacing = trial_spacing
        )
        else upper_spacing = trial_spacing
    )
    if solved_points == undefined then
        throw ("TPG | Taper ring spacing did not converge. Vertices:" + ring_ids as string + " residual:" + spacing_residual as string + " precision:" + position_precision as string)
    local minimum_spacing = distance solved_points[1] solved_points[2]
    local maximum_spacing = minimum_spacing
    for point_id = 2 to edge_count do
    (
        local actual_spacing = distance solved_points[point_id] solved_points[point_id + 1]
        minimum_spacing = amin minimum_spacing actual_spacing
        maximum_spacing = amax maximum_spacing actual_spacing
    )
    if (maximum_spacing - minimum_spacing) > position_precision then
        throw ("TPG | Taper ring spacing exceeds precision. Vertices:" + ring_ids as string + " minimum:" + minimum_spacing as string + " maximum:" + maximum_spacing as string + " precision:" + position_precision as string)
    /* Commit only after the complete ring has a valid spacing solution. */
    for point_id = 2 to edge_count do setVert source_mesh ring_ids[point_id] solved_points[point_id]
    source_mesh
    -- return
)

/* Extrude with no native outline and offset the NEW TOP perimeter separately.
   Lower vertices stay fixed. Nonzero Taper also redistributes all upper ring
   rows between their fixed tapered endpoints with equal chord spacing.
   Capture original face/corner IDs before meshop changes topology; consume
   and discard that correspondence immediately after the operation.
*/
global tpgExtrudeFaceRegion
function tpgExtrudeFaceRegion source_mesh region_faces height_amount border_offset extrusion_direction redistribute_rings:true position_precision:undefined =
(
    if border_offset == 0.0 then
    (
        meshop.extrudeFaces source_mesh region_faces height_amount 0.0 dir:extrusion_direction
    )
    else
    (
        local original_faces = for face_id in region_faces collect #(face_id,(getFace source_mesh face_id))
        local ring_chains = #()
        local boundary_offsets = tpgGetRegionBoundaryOffsets source_mesh region_faces border_offset ring_chains:(if redistribute_rings then ring_chains else undefined)
        local top_vertex_ids = #()
        top_vertex_ids.count = source_mesh.numverts
        meshop.extrudeFaces source_mesh region_faces height_amount 0.0 dir:extrusion_direction
        local visited_vertices = #{}
        visited_vertices.count = source_mesh.numverts
        for original_face in original_faces do
        (
            local current_vertices = getFace source_mesh original_face[1]
            for corner_id = 1 to 3 do
            (
                local top_vertex_id = current_vertices[corner_id] as integer
                local source_vertex_id = original_face[2][corner_id] as integer
                top_vertex_ids[source_vertex_id] = top_vertex_id
                if not visited_vertices[top_vertex_id] and boundary_offsets[source_vertex_id] != undefined then
                (
                    setVert source_mesh top_vertex_id ((getVert source_mesh top_vertex_id) + boundary_offsets[source_vertex_id])
                    visited_vertices[top_vertex_id] = true
                )
            )
        )
        if redistribute_rings then
        (
            if position_precision == undefined then position_precision = units.decodeValue "0.01mm"
            if position_precision <= 0.0 then throw ("TPG | Taper spacing precision must be positive, actual:" + position_precision as string)
            for ring_ids in ring_chains do
            (
                local top_ring_ids = for vertex_id in ring_ids collect top_vertex_ids[vertex_id]
                tpgRespaceTaperRing source_mesh top_ring_ids position_precision
            )
        )
    )
    source_mesh
    -- return
)

/* Inset uses the same boundary-offset geometry as Taper, but starts from
   the original lower border and creates its separate zero-height rim first.
*/
global tpgInsetFaceRegion
function tpgInsetFaceRegion source_mesh region_faces inset_amount =
(
    tpgExtrudeFaceRegion source_mesh region_faces 0.0 inset_amount #common redistribute_rings:false
    -- return
)


/* Decode the stored direction; pre-mode scenes and presets retain Group behavior.
*/
global tpgDecodeExtrusionMode
function tpgDecodeExtrusionMode stored_value =
(
    case stored_value of
    (
        undefined: #group
        "": #group
        "Group": #group
        "Local": #local
        default: throw ("TPG | Invalid ExtrusionMode: " + (stored_value as string) + " expected Group or Local.")
    )
    -- return
)


/* Validate and serialize the public extrusion mode without numeric enum coercion.
*/
global tpgEncodeExtrusionMode
function tpgEncodeExtrusionMode mode_value =
(
    case mode_value of
    (
        #group: "Group"
        #local: "Local"
        default: throw ("TPG | Invalid extrusion mode: " + (mode_value as string) + " expected #group or #local.")
    )
    -- return
)


/*
Rebuilds the extrusion from the incoming, already bent TriMesh.
Map channel 99 carries immutable expanded-cell IDs and the enabled mask.
*/
global tpgBuildExtrusionMesh
function tpgBuildExtrusionMesh source_mesh source_node =
(
    local extrusion_mode = tpgDecodeExtrusionMode (getUserPropVal source_node "SPG_ExtrusionMode" asString:true)
    local extrusion_direction = if extrusion_mode == #local then #independent else #common
    local encoded_depths = getUserPropVal source_node "SPG_RuleDepths" asString:true
    local encoded_insets = getUserPropVal source_node "SPG_RuleInsets" asString:true
    local encoded_tapers = getUserPropVal source_node "SPG_RuleTapers" asString:true
    local encoded_rule_count = getUserPropVal source_node "SPG_RuleCount" asString:true
    local encoded_cells = getUserPropVal source_node "SPG_TotalRows" asString:true
    local encoded_columns = getUserPropVal source_node "SPG_TotalColumns" asString:true
    local seams_active = (getUserPropVal source_node "SPG_SeamsEnabled" asString:true) == "1"
    if encoded_depths == undefined or encoded_insets == undefined or encoded_tapers == undefined or encoded_rule_count == undefined or encoded_cells == undefined or encoded_columns == undefined then
        throw "TPG | Procedural extrusion requires saved per-rule parameters."
    if not (meshop.getMapSupport source_mesh 99) then
        throw "TPG | Procedural extrusion requires the original cell-ID map channel 99."
    local rule_count = encoded_rule_count as integer
    local cell_count = (encoded_cells as integer) * (encoded_columns as integer)
    local depth_tokens = filterString encoded_depths ";"
    local inset_tokens = filterString encoded_insets ";"
    local taper_tokens = filterString encoded_tapers ";"
    if rule_count < 1 or cell_count < 1 or depth_tokens.count != rule_count or inset_tokens.count != rule_count or taper_tokens.count != rule_count then
        throw "TPG | Procedural extrusion rule counts do not match stored data."
    local heights_value = #()
    local insets_value = #()
    local tapers_value = #()
    local rule_face_regions = #()
    heights_value.count = rule_count
    insets_value.count = rule_count
    tapers_value.count = rule_count
    rule_face_regions.count = rule_count
    for rule_id = 1 to rule_count do
    (
        heights_value[rule_id] = depth_tokens[rule_id] as float
        insets_value[rule_id] = inset_tokens[rule_id] as float
        tapers_value[rule_id] = taper_tokens[rule_id] as float
        if insets_value[rule_id] < 0.0 then throw "TPG | Negative Inset is invalid."
        rule_face_regions[rule_id] = #()
        rule_face_regions[rule_id].count = if insets_value[rule_id] > 0.0 then cell_count else 1
        for region_id = 1 to rule_face_regions[rule_id].count do rule_face_regions[rule_id][region_id] = #{}
    )


    /*
    Divide only incoming faces into original logical panel regions.
    All subsequent operations act on the local TriMesh, not the scene stack.
    */
    /* Weld the incoming bent TriMesh before caching any face/vertex IDs.
       The saved millimeter precision is the weld distance, converted to scene units.
       Only this modifier's mesh copy changes; the flat base and Bend stay intact.
    */
    local precision_mm_text = getUserPropVal source_node "SPG_PositionPrecisionMM" asString:true
    local precision_mm_value = if precision_mm_text != undefined then (precision_mm_text as float) else 0.01
    if precision_mm_value == undefined or precision_mm_value <= 0.0 then
        throw ("TPG | Invalid pre-extrusion weld precision in mm:" + precision_mm_text as string)
    local weld_threshold = units.decodeValue ((precision_mm_value as string) + "mm")
    local weld_vertices = #{1..source_mesh.numverts}
    meshop.weldVertsByThreshold source_mesh weld_vertices weld_threshold
    /* The weld invalidates old indices; all region/topology IDs are read below. */
    local original_face_count = source_mesh.numfaces
    for face_id = 1 to original_face_count do
    (
        local face_uv = meshop.getMapFace source_mesh 99 face_id
        local tag_value = meshop.getMapVert source_mesh 99 (face_uv.x as integer)
        local mixed_seam_face = false
        if seams_active then
        (
            local second_tag = meshop.getMapVert source_mesh 99 (face_uv.y as integer)
            local third_tag = meshop.getMapVert source_mesh 99 (face_uv.z as integer)
            if (distance tag_value second_tag) > 0.001 or (distance tag_value third_tag) > 0.001 then
                mixed_seam_face = true
        )
        local cell_id = (floor (tag_value.x + 0.5)) as integer
        local material_id = getFaceMatID source_mesh face_id
        -- The baked Shell back/edge faces use the reserved neutral map tag 0.
        if cell_id == 0 and tag_value.y == 0.0 then mixed_seam_face = true
        if not seams_active and not mixed_seam_face and (cell_id < 1 or cell_id > cell_count) then
            throw "TPG | The saved cell-ID map is outside the panel grid."
        if seams_active and (cell_id < 1 or cell_id > cell_count) then mixed_seam_face = true
        if not mixed_seam_face then
        (
            if tag_value.y > 0.5 then
            (
                if material_id < 1 or material_id > rule_count then throw "TPG | The source face Material ID exceeds its rule table."
                local region_id = if insets_value[material_id] > 0.0 then cell_id else 1
                rule_face_regions[material_id][region_id][face_id] = true
            )
        )
    )


    /*
    Build rim and wall topology on the incoming mesh, leaving its lower stack intact.
    The native MeshOp ExtrudeFaces operation preserves original input face IDs.
    */
    for rule_id = 1 to rule_count do
    (
        for face_region in rule_face_regions[rule_id] do
        (
            if face_region.numberSet > 0 then
            (
                face_region.count = source_mesh.numfaces
                local before_faces = source_mesh.numfaces
                if insets_value[rule_id] > 0.0 then
                    tpgInsetFaceRegion source_mesh face_region insets_value[rule_id]
                if heights_value[rule_id] != 0.0 or tapers_value[rule_id] != 0.0 then
                (
                    face_region.count = source_mesh.numfaces
                    tpgExtrudeFaceRegion source_mesh face_region heights_value[rule_id] tapers_value[rule_id] extrusion_direction
                )
                for side_face_id = before_faces + 1 to source_mesh.numfaces do
                    setFaceMatID source_mesh side_face_id rule_id
            )
        )
    )
    source_mesh
    -- return
)


/*
Persistent parametric extrusion above Bend. Its identity never changes on edits.
The last-good incoming mesh is kept if a malformed node record is encountered.
*/
plugin simpleMeshMod TPGExtrusion_v name:"TPG Extrusion" classID:#(0x54504706,0x20261025) category:"Tank Panel Generator"
(
    parameters main
    (
        refresh_counter type:#integer default:0 animatable:false
    )
    on modifyMesh do
    (
        if isValidNode owningNode then
        (
            try
            (
                local result_mesh = tpgBuildExtrusionMesh (copy mesh) owningNode
                mesh = result_mesh
            )
            catch
            (
                format "TPG PROCEDURAL ERROR | %\n" (getCurrentException())
            )
        )
    )
)


/* A validated, detached snapshot of a generated module's editable settings.
*/
struct TankPanelObjectData_v
(
    source_node = undefined,
    bend_mod = undefined,
    seams_mod = undefined,
    chamfer_mod = undefined,
    rows = 1,
    columns = 1,
    repeat_x = 1,
    repeat_y = 1,
    radius_value = 0.0,
    length_value = 0.0,
    arc_segments = 1,
    length_segments = 1,
    length_segments_auto = false,
    mask = #(),
    cell_ids = #(),
    rule_depths = #(),
    rule_thicknesses = #(),
    rule_offsets = #(),
    rule_insets = #(),
    rule_tapers = #(),
    material_mode = #multi,
    extrusion_mode = #group,
    seams_enabled = false,
    seams_amount = 10.0,
    seams_offset = 20.0,
    chamfer_enabled = false,
    chamfer_amount = 1.0,
    chamfer_segments = 1,
    base_thickness = 0.0,
    unit_index = 1,
    on create do ()
)


struct SurfacePanelGenerator_v
(
    file_version = "0.087",
    project_version = "0.089",
    rows = 4,
    columns = 3,
    mask = #(),
    cell_ids = #(),
    rule_depths = #(),
    rule_thicknesses = #(),
    rule_offsets = #(),
    rule_insets = #(),
    rule_tapers = #(),
    last_node = undefined,
    last_bend_mod = undefined,
    material_mode = #multi,
    extrusion_mode = #group,
    seams_enabled = false,
    seams_amount = 10.0,
    seams_offset = 20.0,
    chamfer_enabled = false,
    chamfer_amount = 1.0,
    chamfer_segments = 1,
    base_thickness = 0.0,
    extrusion_cache_node = undefined,
    extrusion_cache_base = undefined,
    extrusion_cache_layout = #(),
    extrusion_cache_cells = #(),








    /*
    Creates a fixed-size Boolean grid mask.
    */
    function makeMask rows_value columns_value enabled:true =
    (
        local mask_value = #()
        mask_value.count = rows_value * columns_value








        for item_id = 1 to mask_value.count do
        (
            mask_value[item_id] = enabled
        )








        mask_value
        -- return
    ),








    /*
    Resizes a row-major mask while preserving overlapping cells.
    */
    function resizeMask old_mask old_rows old_columns new_rows new_columns =
    (
        local new_mask = makeMask new_rows new_columns enabled:false
        local copy_rows = amin old_rows new_rows
        local copy_columns = amin old_columns new_columns








        for row_id = 1 to copy_rows do
        (
            for column_id = 1 to copy_columns do
            (
                new_mask[((row_id - 1) * new_columns) + column_id] = old_mask[((row_id - 1) * old_columns) + column_id]
            )
        )








        new_mask
        -- return
    ),








    /*
    Converts the current grid mask into compact INI-safe text.
    */
    function encodeMask mask_value =
    (
        local output_value = ""








        for cell_value in mask_value do
        (
            output_value += (if cell_value then "1" else "0")
        )








        output_value
        -- return
    ),








    /*
    Reads a grid mask with an explicit expected size and default state.
    */
    function decodeMask encoded_value cell_count default_enabled:true =
    (
        local mask_value = makeMask 1 cell_count enabled:default_enabled








        if encoded_value.count == cell_count then
        (
            for item_id = 1 to cell_count do
            (
                mask_value[item_id] = (substring encoded_value item_id 1) == "1"
            )
        )








        mask_value
        -- return
    ),








    /*
    Counts the enabled logical panels.
    */
    function countEnabled mask_value =
    (
        local enabled_count = 0








        for cell_value in mask_value do
        (
            if cell_value then enabled_count += 1
        )








        enabled_count
        -- return
    ),








    /*
    Tiles a row-major logical mask across X (circumference) and Y (module length).
    The original mask is unchanged; every repeat is a copy of its complete pattern.
    */
    function tileMask mask_value rows_value columns_value x_multiplier y_multiplier =
    (
        local tiled_rows = rows_value * y_multiplier
        local tiled_columns = columns_value * x_multiplier
        local tiled_mask = makeMask tiled_rows tiled_columns enabled:false








        for repeat_y = 0 to y_multiplier - 1 do
        (
            for repeat_x = 0 to x_multiplier - 1 do
            (
                for row_id = 1 to rows_value do
                (
                    for column_id = 1 to columns_value do
                    (
                        local source_id = ((row_id - 1) * columns_value) + column_id
                        local target_row = repeat_y * rows_value + row_id
                        local target_column = repeat_x * columns_value + column_id
                        local target_id = ((target_row - 1) * tiled_columns) + target_column
                        tiled_mask[target_id] = mask_value[source_id]
                    )
                )
            )
        )








        tiled_mask
        -- return
    ),








    /*
    Returns the unbent, un-repeated source-panel dimensions in current scene
    units. A source panel spans all of its arc subdivisions, so subdivisions
    and repetitions around X divide the fixed circumference into smaller
    repeated pattern sectors; Y repeats preserve each source panel height.
    This matches the Plane created by generateModule before its Bend.
    */
    function getUnbentPanelDimensions rows_value columns_value radius_value length_value x_multiplier:1 =
    (
        if rows_value < 1 or columns_value < 1 or radius_value <= 0 or length_value <= 0 or x_multiplier < 1 then
        (
            format "TPG ERROR | Invalid unbent panel dimensions | rows:% columns:% radius:% length:% repeats around:%\n" rows_value columns_value radius_value length_value x_multiplier
            undefined
        )
        else
        (
            [(2.0 * pi * radius_value) / (columns_value * x_multiplier), length_value / rows_value]
        )
        -- return
    ),








    /*
    Assigns Material ID 1 to every new source-grid cell.
    Existing cell IDs and historical rule values are preserved when loading.
    */
    function makeCellIds rows_value columns_value =
    (
        for cell_id = 1 to (rows_value * columns_value) collect 1
        -- return
    ),








    /*
    Preserves IDs in overlapping cells on a segment-grid resize.
    New cells receive Material ID 1.
    */
    function resizeCellIds previous_ids old_rows old_columns new_rows new_columns =
    (
        local new_ids = makeCellIds new_rows new_columns
        local copy_rows = amin old_rows new_rows
        local copy_columns = amin old_columns new_columns
        for row_id = 1 to copy_rows do
        (
            for column_id = 1 to copy_columns do
            (
                new_ids[((row_id - 1) * new_columns) + column_id] = previous_ids[((row_id - 1) * old_columns) + column_id]
            )
        )
        new_ids
        -- return
    ),








    /*
    Creates an ID-indexed extrusion depth array with a single default.
    */
    function makeRuleDepths rule_count default_depth =
    (
        local result_depths = #()
        result_depths.count = rule_count
        for rule_id = 1 to rule_count do result_depths[rule_id] = default_depth
        result_depths
        -- return
    ),








    /*
    Expands rule storage without changing configured rule depths.
    */
    function resizeRuleDepths previous_depths new_rule_count default_depth =
    (
        local result_depths = makeRuleDepths new_rule_count default_depth
        for rule_id = 1 to (amin previous_depths.count new_rule_count) do
        (
            result_depths[rule_id] = previous_depths[rule_id]
        )
        result_depths
        -- return
    ),








    /*
    Encodes positive rule IDs for INI and node user properties.
    */
    function encodeCellIds ids_value =
    (
        local encoded_value = ""
        for cell_id = 1 to ids_value.count do
        (
            if cell_id > 1 then encoded_value += ";"
            encoded_value += (ids_value[cell_id] as string)
        )
        encoded_value
        -- return
    ),








    /*
    Restores per-segment rule IDs; a malformed saved array is rejected.
    */
    function decodeCellIds encoded_value rows_value columns_value =
    (
        local default_ids = makeCellIds rows_value columns_value
        local tokens = filterString encoded_value ";"
        local valid = (tokens.count == default_ids.count)
        if valid then
        (
            for cell_id = 1 to tokens.count do
            (
                local parsed_id = undefined
                try (parsed_id = tokens[cell_id] as integer) catch
                (
                    format "TPG WARNING | Invalid saved ID token | cell:% value:%\n" cell_id tokens[cell_id]
                    valid = false
                )
                if valid and parsed_id != undefined and parsed_id > 0 then
                (
                    default_ids[cell_id] = parsed_id
                )
                else
                (
                    valid = false
                )
            )
        )
        if not valid then
        (
            if encoded_value != "" then format "TPG WARNING | Invalid CellIDs ignored; Material ID 1 restored to all cells.\n"
            default_ids = makeCellIds rows_value columns_value
        )
        default_ids
        -- return
    ),








    /*
    Serializes ID-specific extrusion depths independently of segment count.
    */
    function encodeRuleDepths depths_value =
    (
        local encoded_value = ""
        for rule_id = 1 to depths_value.count do
        (
            if rule_id > 1 then encoded_value += ";"
            encoded_value += (formattedPrint depths_value[rule_id] format:".9g")
        )
        encoded_value
        -- return
    ),








    /*
    Reads persisted rule depths or uses the explicit default depth.
    */
    function decodeRuleDepths encoded_value rule_count default_depth =
    (
        local depths_value = makeRuleDepths rule_count default_depth
        local tokens = filterString encoded_value ";"
        -- Accept an older, shorter rule table and preserve those IDs when
        -- the UI exposes more palette slots in the current release.
        if encoded_value != "" and tokens.count <= rule_count then
        (
            for rule_id = 1 to tokens.count do
            (
                local parsed_depth = undefined
                try (parsed_depth = tokens[rule_id] as float) catch
                (
                    format "TPG WARNING | Invalid saved rule depth | rule:% value:%\n" rule_id tokens[rule_id]
                )
                if parsed_depth != undefined then depths_value[rule_id] = parsed_depth
            )
        )
        else if encoded_value != "" then
        (
            format "TPG WARNING | RuleDepths cardinality mismatch; expected:% got:%\n" rule_count tokens.count
        )
        depths_value
        -- return
    ),








    /*
    Maps an expanded grid cell back to its single source pattern cell.
    Repeated tiles reuse the source cell's material ID.
    */
    function sourceCellId expanded_row expanded_column rows_value columns_value =
    (
        local source_row = (mod (expanded_row - 1) rows_value) + 1
        local source_column = (mod (expanded_column - 1) columns_value) + 1








        ((source_row - 1) * columns_value) + source_column
        -- return
    ),








    /*
    Returns deterministic soft diffuse colors, shared by the grid and materials.
    ID 1 is neutral grey; the following six are red, green, blue, yellow,
    magenta and cyan. Later cycles vary hue and saturation slightly.
    */
    function getPanelColor panel_id =
    (
        local palette = #(
            (color 146 146 146),
            (color 185 116 114),
            (color 117 168 123),
            (color 116 147 190),
            (color 196 183 116),
            (color 182 128 176),
            (color 117 182 184)
        )
        local index_value = amax 1 panel_id
        local palette_slot = (mod (index_value - 1) 7) + 1
        local cycle_index = (floor ((index_value - 1) / 7.0)) as integer
        local base_color = palette[palette_slot]
        if cycle_index == 0 then
        (
            base_color
        )
        else
        (
            local red_value = base_color.r as float
            local green_value = base_color.g as float
            local blue_value = base_color.b as float
            if palette_slot == 1 then
            (
                local grey_shift = (mod cycle_index 5) * 5 - 10
                color (red_value + grey_shift) (green_value + grey_shift) (blue_value + grey_shift)
            )
            else
            (
                local average = (red_value + green_value + blue_value) / 3.0
                local saturation_factor = 0.84 + ((mod cycle_index 5) * 0.03)
                local hue_shift = ((mod cycle_index 5) - 2) * 3.0
                local new_red = average + ((red_value - average) * saturation_factor) + hue_shift
                local new_green = average + ((green_value - average) * saturation_factor) - (hue_shift * 0.5)
                local new_blue = average + ((blue_value - average) * saturation_factor) + (hue_shift * 0.25)
                color (amax 0 (amin 255 new_red)) (amax 0 (amin 255 new_green)) (amax 0 (amin 255 new_blue))
            )
        )
        -- return
    ),








    /*
    Creates one Standard sub-material per panel/rule ID with matching diffuse.
    */
    function makePaletteMaterial rows_value columns_value rule_count:0 =
    (
        local source_count = amax (rows_value * columns_value) rule_count
        local palette_material = multiMaterial numsubs:source_count
        palette_material.name = "TPG_Panel_IDs"








        for cell_id = 1 to source_count do
        (
            local color_value = getPanelColor cell_id








            local cell_label = "Rule ID " + (cell_id as string)
            local cell_material = standardMaterial name:cell_label diffuse:color_value
            palette_material.materialList[cell_id] = cell_material
            palette_material.materialIDList[cell_id] = cell_id
            palette_material.names[cell_id] = cell_label
        )








        palette_material
        -- return
    ),








    /*
    Assigns palette or plain grey to the bound node without changing face IDs.
    Material mode is retained for subsequent regenerations.
    */
    function applyMaterial target_node rows_value columns_value mode_value rule_count:0 =
    (
        if not isValidNode target_node then
        (
            format "TPG ERROR | Apply material requires a valid bound node.\n"
            false
        )
        else
        (
            if mode_value == #multi then
            (
                target_node.material = makePaletteMaterial rows_value columns_value rule_count:rule_count
                setUserProp target_node "SPG_MaterialMode" "Multi"
                material_mode = #multi
            )
            else if mode_value == #gray then
            (
                target_node.material = standardMaterial name:"TPG_Gray" diffuse:(color 135 135 135)
                setUserProp target_node "SPG_MaterialMode" "Gray"
                material_mode = #gray
            )
            else
            (
                format "TPG ERROR | Invalid material mode:%\n" mode_value
                return false
            )
            true
        )
        -- return
    ),








    /*
    Returns exact tool-owned modifiers in visual order: top Chamfer, extrusion,
    Bend, lower Seams Chamfer; missing optional Chamfers remain undefined.
    No user modifier is identified by its display name.
    */
    function getOwnedStackParts source_node =
    (
        local result_parts = undefined
        if isValidNode source_node and classOf source_node.baseObject == Editable_Poly then
        (
            local stack_count = source_node.modifiers.count
            local stack_index = 1
            local top_chamfer_mod = undefined
            local extrusion_mod = undefined
            local bend_mod = undefined
            local seams_mod = undefined
            if stack_count > 0 then
            (
                if (getAppData source_node.modifiers[stack_index] 1847365210) == "TPG:Chamfer" and classOf source_node.modifiers[stack_index] == Chamfer then
                (
                    top_chamfer_mod = source_node.modifiers[stack_index]
                    stack_index += 1
                )
                if stack_index <= stack_count and (getAppData source_node.modifiers[stack_index] 1847365210) == "TPG:Extrusion" then
                (
                    if classOf source_node.modifiers[stack_index] == TPGExtrusion_v or classOf source_node.modifiers[stack_index] == Edit_Poly then
                    (
                        extrusion_mod = source_node.modifiers[stack_index]
                        stack_index += 1
                    )
                )
                if stack_index <= stack_count then
                (
                    if classOf source_node.modifiers[stack_index] == Bend and (getAppData source_node.modifiers[stack_index] 1847365210) == "TPG:Bend" then
                    (
                        bend_mod = source_node.modifiers[stack_index]
                        stack_index += 1
                    )
                )
                if stack_index <= stack_count then
                (
                    if classOf source_node.modifiers[stack_index] == Chamfer and (getAppData source_node.modifiers[stack_index] 1847365210) == "TPG:Seams" then
                    (
                        seams_mod = source_node.modifiers[stack_index]
                        stack_index += 1
                    )
                )
                if bend_mod != undefined and stack_index == (stack_count + 1) then
                    result_parts = #(top_chamfer_mod,extrusion_mod,bend_mod,seams_mod)
            )
        )
        result_parts
        -- return
    ),


    /*
    Regeneration can replace only the tool-owned geometry and Bend stack.
    User-added modifiers must never be destroyed by instanceReplace.
    */
    function canReplaceBoundNode target_node owned_bend =
    (
        local can_replace = false
        if isValidNode target_node and owned_bend != undefined then
        (
            local owner_marker = getUserProp target_node "SPG_Owner"
            local is_owned = (owner_marker == "Tank-Panel-Generator" or owner_marker == "Surface-Panel-Generator")
            if not is_owned then
            (
                -- v0.005 generated modules have no SPG_Owner, but retain both grid metadata fields.
                is_owned = ((getUserProp target_node "SPG_Mask") != undefined and (getUserProp target_node "SPG_ArcSegments") != undefined)
            )
            if is_owned then
            (
                if target_node.modifiers.count == 1 then
                (
                    can_replace = (target_node.modifiers[1] == owned_bend and (getUserPropVal target_node "SPG_DataSchema" asString:true) != "2")
                )
                else if target_node.modifiers.count >= 2 and target_node.modifiers.count <= 4 then
                (
                    local owned_parts = getOwnedStackParts target_node
                    can_replace = (owned_parts != undefined and owned_parts[2] != undefined and owned_parts[3] == owned_bend and (getUserPropVal target_node "SPG_DataSchema" asString:true) == "2")
                )
            )
        )
        if not can_replace then
        (
            format "TPG ERROR | Existing bound object cannot be regenerated: owned Bend changed, foreign modifiers present, or ownership invalid. node:%\n" target_node
        )
        can_replace
        -- return
    ),


    /*
    Add or edit owned native Chamfer modifiers without rebuilding the base sheet.
    The seam modifier always sits BELOW Bend; regular Chamfer sits above extrusion.
    */
    function syncChamferStack target_node owned_bend seams_enabled_value:false seams_amount_value:10.0 seams_offset_value:20.0 chamfer_enabled_value:false chamfer_amount_value:1.0 chamfer_segments_value:1 =
    (
        if seams_amount_value < 0.0 or seams_offset_value < 0.0 or chamfer_amount_value < 0.0 then
            throw "TPG | Chamfer and Seams amounts must not be negative."
        if chamfer_segments_value < 0 or chamfer_segments_value > 100 or chamfer_segments_value != (chamfer_segments_value as integer) then
            throw "TPG | Chamfer segments must be an integer from 0 to 100."
        if not (canReplaceBoundNode target_node owned_bend) then
            throw "TPG | Refusing to edit a foreign or changed modifier stack."


        local stack_parts = getOwnedStackParts target_node
        local top_chamfer_mod = stack_parts[1]
        local original_extrusion_mod = stack_parts[2]
        local seams_mod = stack_parts[4]
        /*
        The procedural modifier can evaluate while the lower Chamfer is inserted.
        Publish the intended seam-tag mode before that first stack evaluation.
        */
        setUserProp target_node "SPG_SeamsEnabled" (if seams_enabled_value then 1 else 0)
        setUserProp target_node "SPG_SeamsAmount" seams_amount_value
        setUserProp target_node "SPG_SeamsOffset" seams_offset_value
        setUserProp target_node "SPG_ChamferEnabled" (if chamfer_enabled_value then 1 else 0)
        setUserProp target_node "SPG_ChamferAmount" chamfer_amount_value
        setUserProp target_node "SPG_ChamferSegments" chamfer_segments_value
        if seams_enabled_value and seams_mod == undefined then
        (
            seams_mod = Chamfer name:"TPG Seams"
            seams_mod.enabled = false
            seams_mod.materialoption = 1
            seams_mod.amount = seams_amount_value
            seams_mod.selectionoption = 5
            seams_mod.useminangle = false
            seams_mod.addinset = true
            seams_mod.insetoffset = seams_offset_value
            seams_mod.insetamount = 0.0
            seams_mod.segments = 0
            addModifier target_node seams_mod before:target_node.modifiers.count
            setAppData seams_mod 1847365210 "TPG:Seams"
        )
        if chamfer_enabled_value and top_chamfer_mod == undefined then
        (
            top_chamfer_mod = Chamfer name:"TPG_Chamfer"
            top_chamfer_mod.enabled = false
            top_chamfer_mod.amount = chamfer_amount_value
            top_chamfer_mod.materialoption = 2
            top_chamfer_mod.segments = chamfer_segments_value
            top_chamfer_mod.selectionoption = 5
            addModifier target_node top_chamfer_mod
            setAppData top_chamfer_mod 1847365210 "TPG:Chamfer"
        )
        if seams_mod != undefined then
        (
            seams_mod.enabled = false
            seams_mod.materialoption = 1
            seams_mod.amount = seams_amount_value
            seams_mod.selectionoption = 5
            seams_mod.useminangle = false
            seams_mod.addinset = true
            seams_mod.insetoffset = seams_offset_value
            seams_mod.insetamount = 0.0
            seams_mod.segments = 0
            seams_mod.enabled = seams_enabled_value
        )
        if top_chamfer_mod != undefined then
        (
            top_chamfer_mod.enabled = false
            top_chamfer_mod.name = "TPG_Chamfer"
            top_chamfer_mod.amount = chamfer_amount_value
            top_chamfer_mod.materialoption = 2
            top_chamfer_mod.segments = chamfer_segments_value
            top_chamfer_mod.selectionoption = 5
            top_chamfer_mod.enabled = chamfer_enabled_value
        )
        local verified_parts = getOwnedStackParts target_node
        if verified_parts == undefined or verified_parts[2] != original_extrusion_mod or verified_parts[3] != owned_bend or verified_parts[1] != top_chamfer_mod or verified_parts[4] != seams_mod then
            throw "TPG | Native Chamfer insertion changed the expected modifier order."
        verified_parts
        -- return
    ),


    /* Read and validate an object's complete generation record without binding it.
    */
    function readModuleData source_node =
    (
        if not isValidNode source_node then throw "TPG LOAD | Select one generated module."
        local owner_text = getUserPropVal source_node "SPG_Owner" asString:true
        if owner_text != "Tank-Panel-Generator" and owner_text != "Surface-Panel-Generator" then
            throw "TPG LOAD | Selected object has no generator ownership record."
        local schema_text = getUserPropVal source_node "SPG_DataSchema" asString:true
        if schema_text != undefined and schema_text != "1" and schema_text != "2" then throw "TPG LOAD | Unsupported generator data schema."
        local data_value = TankPanelObjectData_v()
        data_value.source_node = source_node
        local thickness_text = getUserPropVal source_node "SPG_BaseThickness" asString:true
        if thickness_text != undefined then
        (
            data_value.base_thickness = thickness_text as float
            if data_value.base_thickness == undefined or data_value.base_thickness < 0.0 or data_value.base_thickness > 1000000.0 then
                throw "TPG LOAD | Invalid base thickness."
        )
        local auto_text = getUserPropVal source_node "SPG_LengthSegmentsAuto" asString:true
        if auto_text != undefined and auto_text != "0" and auto_text != "1" then
            throw ("TPG LOAD | Invalid SPG_LengthSegmentsAuto:" + auto_text)
        data_value.length_segments_auto = (auto_text == "1")
        data_value.extrusion_mode = tpgDecodeExtrusionMode (getUserPropVal source_node "SPG_ExtrusionMode" asString:true)
        local numeric_fields = #(#("SPG_Rows",#rows),#("SPG_Columns",#columns),#("SPG_XMultiplier",#repeat_x),#("SPG_YMultiplier",#repeat_y),#("SPG_Radius",#radius_value),#("SPG_Length",#length_value),#("SPG_ArcSegments",#arc_segments),#("SPG_LengthSegments",#length_segments))
        for field_pair in numeric_fields do
        (
            local raw_value = getUserPropVal source_node field_pair[1] asString:true
            if raw_value == undefined then throw ("TPG LOAD | Missing property: " + field_pair[1])
            local parsed_value = raw_value as float
            if parsed_value == undefined or parsed_value <= 0.0 then throw ("TPG LOAD | Invalid property: " + field_pair[1] + " = " + raw_value)
            if field_pair[2] != #radius_value and field_pair[2] != #length_value then
            (
                if parsed_value != (parsed_value as integer) then throw ("TPG LOAD | Expected integer: " + field_pair[1])
                parsed_value = parsed_value as integer
            )
            setProperty data_value field_pair[2] parsed_value
        )
        local cell_count = data_value.rows * data_value.columns
        local mask_text = getUserPropVal source_node "SPG_Mask" asString:true
        if mask_text == undefined or mask_text.count != cell_count then throw "TPG LOAD | Invalid panel mask length."
        for character_id = 1 to mask_text.count do
        (
            local mask_character = substring mask_text character_id 1
            if mask_character != "0" and mask_character != "1" then throw "TPG LOAD | Panel mask contains a non-binary value."
        )
        data_value.mask = decodeMask mask_text cell_count
        local id_text = getUserPropVal source_node "SPG_CellIDs" asString:true
        if id_text == undefined then throw "TPG LOAD | Missing CellIDs."
        local id_tokens = filterString id_text ";"
        if id_tokens.count != cell_count then throw "TPG LOAD | CellIDs count does not match the grid."
        local depth_text = getUserPropVal source_node "SPG_RuleDepths" asString:true
        if depth_text == undefined then throw "TPG LOAD | Missing per-ID heights."
        local depth_tokens = filterString depth_text ";"
        local rule_count = depth_tokens.count
        if rule_count < 1 then throw "TPG LOAD | Empty per-ID rule table."
        local stored_count_text = getUserPropVal source_node "SPG_RuleCount" asString:true
        if stored_count_text != undefined and (stored_count_text as integer) != rule_count then throw "TPG LOAD | RuleCount does not match saved heights."
        data_value.cell_ids = #()
        for id_token in id_tokens do
        (
            local id_value = id_token as integer
            if id_value == undefined or (id_token as float) != id_value or id_value < 1 or id_value > rule_count then
                throw ("TPG LOAD | Invalid cell ID: " + id_token)
            append data_value.cell_ids id_value
        )
        local rule_fields = #(#("SPG_RuleDepths",#rule_depths),#("SPG_RuleThicknesses",#rule_thicknesses),#("SPG_RuleOffsets",#rule_offsets),#("SPG_RuleInsets",#rule_insets),#("SPG_RuleTapers",#rule_tapers))
        for field_pair in rule_fields do
        (
            local raw_text = getUserPropVal source_node field_pair[1] asString:true
            local field_values = #()
            if raw_text == undefined then
            (
                if schema_text != undefined then throw ("TPG LOAD | Missing rule table: " + field_pair[1])
                /* Missing optional legacy rules have documented zero defaults.
                */
                field_values = makeRuleDepths rule_count 0.0
            )
            else
            (
                local tokens = filterString raw_text ";"
                if tokens.count != rule_count then throw ("TPG LOAD | Rule length mismatch: " + field_pair[1])
                for token_text in tokens do
                (
                    local number_value = token_text as float
                    if number_value == undefined then throw ("TPG LOAD | Invalid number in " + field_pair[1])
                    if field_pair[2] == #rule_insets and number_value < 0.0 then throw "TPG LOAD | Negative Inset is invalid."
                    append field_values number_value
                )
            )
            setProperty data_value field_pair[2] field_values
        )
        local mode_text = getUserPropVal source_node "SPG_MaterialMode" asString:true
        if mode_text != "Multi" and mode_text != "Gray" then throw "TPG LOAD | Invalid material mode."
        data_value.material_mode = if mode_text == "Gray" then #gray else #multi
        local unit_text = getUserPropVal source_node "SPG_DimensionUnit" asString:true
        if unit_text != undefined then
        (
            data_value.unit_index = unit_text as integer
            if data_value.unit_index == undefined or (unit_text as float) != data_value.unit_index or data_value.unit_index < 0 or data_value.unit_index > 2 then throw "TPG LOAD | Invalid SIZE unit."
        )
        local stack_parts = getOwnedStackParts source_node
        local candidate_bend = undefined
        if schema_text == "2" then
        (
            if stack_parts == undefined or stack_parts[2] == undefined then
                throw "TPG LOAD | Unexpected module stack; foreign modifiers block editing."
            candidate_bend = stack_parts[3]
            data_value.chamfer_mod = stack_parts[1]
            data_value.seams_mod = stack_parts[4]
        )
        else
        (
            if classOf source_node.baseObject != Editable_Poly or source_node.modifiers.count != 1 then
                throw "TPG LOAD | Unexpected legacy module stack."
            candidate_bend = source_node.modifiers[1]
        )
        if classOf candidate_bend != Bend then throw "TPG LOAD | Generated Bend is missing."
        local bend_marker = getAppData candidate_bend 1847365210
        if bend_marker != "TPG:Bend" then
        (
            if schema_text != undefined or candidate_bend.angle != 360.0 or candidate_bend.direction != 0.0 or candidate_bend.axis != 0 then
                throw "TPG LOAD | Cannot establish ownership of this Bend."
        )
        data_value.bend_mod = candidate_bend
        local seams_enabled_text = getUserPropVal source_node "SPG_SeamsEnabled" asString:true
        local seams_amount_text = getUserPropVal source_node "SPG_SeamsAmount" asString:true
        local seams_offset_text = getUserPropVal source_node "SPG_SeamsOffset" asString:true
        local chamfer_enabled_text = getUserPropVal source_node "SPG_ChamferEnabled" asString:true
        local chamfer_amount_text = getUserPropVal source_node "SPG_ChamferAmount" asString:true
        local chamfer_segments_text = getUserPropVal source_node "SPG_ChamferSegments" asString:true
        data_value.seams_enabled = seams_enabled_text == "1"
        data_value.chamfer_enabled = chamfer_enabled_text == "1"
        if seams_amount_text != undefined then data_value.seams_amount = seams_amount_text as float
        if seams_offset_text != undefined then data_value.seams_offset = seams_offset_text as float
        if chamfer_amount_text != undefined then data_value.chamfer_amount = chamfer_amount_text as float
        if chamfer_segments_text != undefined then
        (
            local parsed_chamfer_segments = chamfer_segments_text as float
            if parsed_chamfer_segments == undefined or parsed_chamfer_segments != (parsed_chamfer_segments as integer) then throw "TPG LOAD | Invalid Chamfer Segments value."
            data_value.chamfer_segments = parsed_chamfer_segments as integer
        )
        else if data_value.chamfer_mod != undefined then data_value.chamfer_segments = data_value.chamfer_mod.segments
        if data_value.seams_amount == undefined or data_value.seams_amount < 0 or data_value.seams_offset == undefined or data_value.seams_offset < 0 or data_value.chamfer_amount == undefined or data_value.chamfer_amount < 0 or data_value.chamfer_segments < 0 or data_value.chamfer_segments > 100 then
            throw "TPG LOAD | Invalid native Chamfer parameters."
        if data_value.seams_enabled and data_value.seams_mod == undefined then
            throw "TPG LOAD | Enabled Seams modifier is missing."
        if data_value.chamfer_enabled and data_value.chamfer_mod == undefined then
            throw "TPG LOAD | Enabled Chamfer modifier is missing."
        data_value
        -- return
    ),


    /*
    Updates parameters on the existing extrusion; migrates legacy Edit Poly only once.
    The base mesh and Bend remain untouched for normal v0.062 edits.
    */
    function updateExtrusionOnly target_node owned_bend rule_depths_value:undefined rule_insets_value:undefined rule_tapers_value:undefined extrusion_mode_value:undefined =
    (
        local saved_data = readModuleData target_node
        if extrusion_mode_value == undefined then extrusion_mode_value = saved_data.extrusion_mode
        local encoded_extrusion_mode = tpgEncodeExtrusionMode extrusion_mode_value
        if not (canReplaceBoundNode target_node owned_bend) or saved_data.bend_mod != owned_bend then
            throw "TPG | Extrusion-only update requires an intact owned stack."
        if rule_depths_value == undefined then rule_depths_value = saved_data.rule_depths
        if rule_insets_value == undefined then rule_insets_value = saved_data.rule_insets
        if rule_tapers_value == undefined then rule_tapers_value = saved_data.rule_tapers
        local rule_count = saved_data.rule_depths.count
        if rule_depths_value.count != rule_count or rule_insets_value.count != rule_count or rule_tapers_value.count != rule_count then
            throw "TPG | Extrusion-only update has mismatched rule arrays."
        for rule_id = 1 to rule_count do
        (
            if rule_insets_value[rule_id] < 0.0 then throw "TPG | Negative Inset is invalid."
        )


        local original_base = target_node.baseObject
        local original_stack = getOwnedStackParts target_node
        local original_extrusion_mod = original_stack[2]
        local current_extrusion_mod = original_extrusion_mod
        local original_bend_mod = original_stack[3]
        local original_top_chamfer_mod = original_stack[1]
        local original_seams_mod = original_stack[4]


        /* One-time migration from the v0.061 committed Edit Poly to the persistent modifier.
        Subsequent edits never touch the base mesh, Bend, or stack structure.
        */
        if classOf current_extrusion_mod == Edit_Poly then
        (
            if original_top_chamfer_mod != undefined or original_seams_mod != undefined then
                throw "TPG | Legacy Edit Poly migration requires a two-modifier stack."
            local tiled_rows = saved_data.rows * saved_data.repeat_y
            local tiled_columns = saved_data.columns * saved_data.repeat_x
            local tiled_mask = tileMask saved_data.mask saved_data.rows saved_data.columns saved_data.repeat_x saved_data.repeat_y
            local face_count = polyop.getNumFaces original_base
            if face_count != tiled_rows * tiled_columns * saved_data.arc_segments * saved_data.length_segments then
                throw "TPG | Legacy base topology does not match its saved panel grid."
            local sheet_width = 2.0 * pi * saved_data.radius_value
            local sheet_length = saved_data.length_value * saved_data.repeat_y
            local cell_width = sheet_width / tiled_columns
            local cell_length = sheet_length / tiled_rows
            local precision_mm_text = getUserPropVal target_node "SPG_PositionPrecisionMM" asString:true
            local precision_mm_value = if precision_mm_text != undefined then (precision_mm_text as float) else 0.01
            if precision_mm_value == undefined or precision_mm_value <= 0.0 then
                throw "TPG | Invalid original panel mapping precision."
            local precision_value = units.decodeValue ((precision_mm_value as string) + "mm")


            polyop.setMapSupport original_base 99 true
            polyop.setNumMapVerts original_base 99 tiled_mask.count
            for expanded_cell_id = 1 to tiled_mask.count do
            (
                local enabled_value = if tiled_mask[expanded_cell_id] then 1.0 else 0.0
                polyop.setMapVert original_base 99 expanded_cell_id [expanded_cell_id,enabled_value,0.0]
            )
            for face_id = 1 to face_count do
            (
                local face_vertex_ids = polyop.getFaceVerts original_base face_id
                if face_vertex_ids.count == 0 then throw "TPG | Legacy base contains an empty face."
                local face_center = [0.0,0.0,0.0]
                for vertex_id in face_vertex_ids do
                    face_center += polyop.getVert original_base vertex_id
                face_center /= face_vertex_ids.count
                local scaled_x = face_center.x / precision_value
                local scaled_y = face_center.y / precision_value
                local center_x = (if scaled_x >= 0.0 then (floor (scaled_x + 0.5)) else (ceil (scaled_x - 0.5))) * precision_value
                local center_y = (if scaled_y >= 0.0 then (floor (scaled_y + 0.5)) else (ceil (scaled_y - 0.5))) * precision_value
                local column_id = ((floor ((center_x + sheet_width / 2.0) / cell_width)) as integer) + 1
                local row_id = ((floor ((center_y + sheet_length / 2.0) / cell_length)) as integer) + 1
                if column_id < 1 or column_id > tiled_columns or row_id < 1 or row_id > tiled_rows then
                    throw "TPG | Cannot migrate base-face cell mapping."
                local expanded_cell_id = ((row_id - 1) * tiled_columns) + column_id
                local map_face_vertices = for corner_id = 1 to face_vertex_ids.count collect expanded_cell_id
                polyop.setMapFace original_base 99 face_id map_face_vertices
            )


            local migrated_extrusion_mod = TPGExtrusion_v name:"TPG Extrusion"
            local migration_exception = undefined
            local previous_enabled = current_extrusion_mod.enabled
            try
            (
                current_extrusion_mod.enabled = false
                addModifier target_node migrated_extrusion_mod
                if target_node.modifiers.count != 3 or target_node.modifiers[1] != migrated_extrusion_mod or target_node.modifiers[2] != current_extrusion_mod or target_node.modifiers[3] != original_bend_mod then
                    throw "TPG | Legacy migration changed the modifier order."
                setAppData migrated_extrusion_mod 1847365210 "TPG:Extrusion"
                deleteModifier target_node current_extrusion_mod
                if target_node.modifiers.count != 2 or target_node.modifiers[1] != migrated_extrusion_mod then
                    throw "TPG | Legacy extrusion migration could not be committed."
                current_extrusion_mod = migrated_extrusion_mod
            )
            catch
            (
                migration_exception = getCurrentException()
                if target_node.modifiers.count == 3 and target_node.modifiers[1] == migrated_extrusion_mod then
                    deleteModifier target_node migrated_extrusion_mod
                if target_node.modifiers.count >= 1 and target_node.modifiers[1] == current_extrusion_mod then
                    current_extrusion_mod.enabled = previous_enabled
            )
            if migration_exception != undefined then throw migration_exception
            format "TPG | Migrated legacy extrusion to persistent modifier | node:%\n" target_node.name
        )
        else if classOf current_extrusion_mod != TPGExtrusion_v then
            throw "TPG | Unexpected extrusion modifier class."


        /* Parameter update: no new modifier, no Edit Poly operations or geometry rebake.
        */
        setUserProp target_node "SPG_ExtrusionMode" encoded_extrusion_mode
        setUserProp target_node "SPG_RuleDepths" (encodeRuleDepths rule_depths_value)
        setUserProp target_node "SPG_RuleInsets" (encodeRuleDepths rule_insets_value)
        setUserProp target_node "SPG_RuleTapers" (encodeRuleDepths rule_tapers_value)
        setUserProp target_node "SPG_GeneratorVersion" "0.089"
        current_extrusion_mod.refresh_counter += 1
        local result_stack = getOwnedStackParts target_node
        if target_node.baseObject != original_base or result_stack == undefined or result_stack[1] != original_top_chamfer_mod or result_stack[2] != current_extrusion_mod or result_stack[3] != original_bend_mod or result_stack[4] != original_seams_mod then
            throw "TPG | Parameter update unexpectedly changed the owned modifier stack."
        last_node = target_node
        last_bend_mod = original_bend_mod
        format "TPG FAST | Updated existing extrusion parameters | node:% refresh:%\n" target_node.name current_extrusion_mod.refresh_counter
        target_node
        -- return
    ),


    /*
    Builds a tagged polygon sheet and persistent procedural extrusion above Bend.
    Each logical cell retains its own private map tag through deformation.
    */
    function generateModule rows_value columns_value mask_value radius_value length_value depth_value arc_segments position_precision_mm x_multiplier:1 y_multiplier:1 length_segments:1 target_node:undefined owned_bend:undefined material_mode_value:#multi cell_ids_value:undefined rule_depths_value:undefined rule_thicknesses_value:undefined rule_offsets_value:undefined rule_insets_value:undefined rule_tapers_value:undefined extrusion_mode_value:#group seams_enabled_value:false seams_amount_value:10.0 seams_offset_value:20.0 chamfer_enabled_value:false chamfer_amount_value:1.0 chamfer_segments_value:1 base_thickness_value:0.0 =
    (
        local encoded_extrusion_mode = tpgEncodeExtrusionMode extrusion_mode_value
        /* Zero is the serialized Auto setting; positive values remain manual.
           Round only the dimensionless count, never positions or scene dimensions.
           Repeat Length expands both sheet length and row count, so cancels here.
        */
        local length_segments_auto = (length_segments == 0)
        if length_segments_auto and rows_value > 0 and columns_value > 0 and radius_value > 0.0 and length_value > 0.0 and arc_segments > 0 and x_multiplier > 0 then
        (
            local base_polygon_width = (2.0 * pi * radius_value) / (columns_value * x_multiplier * arc_segments)
            local desired_count = (length_value / rows_value) / base_polygon_width
            length_segments = amax 1 ((floor (desired_count + 0.5)) as integer)
        )
        local generated_node = undefined
        if cell_ids_value == undefined then cell_ids_value = makeCellIds rows_value columns_value
        if rule_depths_value == undefined then rule_depths_value = makeRuleDepths (amax 16 (rows_value * columns_value)) depth_value
        local rule_count = rule_depths_value.count
        if rule_thicknesses_value == undefined then rule_thicknesses_value = makeRuleDepths rule_count 0.0
        if rule_offsets_value == undefined then rule_offsets_value = makeRuleDepths rule_count 0.0
        if rule_insets_value == undefined then rule_insets_value = makeRuleDepths rule_count 0.0
        if rule_tapers_value == undefined then rule_tapers_value = makeRuleDepths rule_count 0.0
        local rule_data_valid = (cell_ids_value.count == (rows_value * columns_value) and rule_count > 0 and rule_thicknesses_value.count == rule_count and rule_offsets_value.count == rule_count and rule_insets_value.count == rule_count and rule_tapers_value.count == rule_count)
        if rule_data_valid then
        (
            for rule_id = 1 to rule_count while rule_data_valid do
            (
                if rule_insets_value[rule_id] < 0.0 then rule_data_valid = false
            )
        )
        if rule_data_valid then
        (
            for cell_id = 1 to cell_ids_value.count while rule_data_valid do
            (
                local rule_id = cell_ids_value[cell_id]
                if rule_id < 1 or rule_id > rule_count then rule_data_valid = false
            )
        )
        local valid_inputs = (base_thickness_value >= 0.0 and base_thickness_value <= 1000000.0 and rows_value > 0 and columns_value > 0 and x_multiplier > 0 and y_multiplier > 0 and arc_segments > 0 and length_segments > 0 and radius_value > 0 and length_value > 0 and position_precision_mm > 0 and mask_value.count == (rows_value * columns_value) and rule_data_valid and (material_mode_value == #multi or material_mode_value == #gray))








        if not valid_inputs then
        (
            format "TPG ERROR | Generate parameters invalid | rows:% columns:% mask:% X:% Y:% radius:% length:% depth:% subdivisions:% precision_mm:%\n" rows_value columns_value mask_value.count x_multiplier y_multiplier radius_value length_value depth_value arc_segments position_precision_mm
        )
        else if target_node != undefined and isValidNode target_node and not (canReplaceBoundNode target_node owned_bend) then
        (
            generated_node = undefined
        )
        else
        (
            local tiled_rows = rows_value * y_multiplier
            local tiled_columns = columns_value * x_multiplier
            local tiled_mask = tileMask mask_value rows_value columns_value x_multiplier y_multiplier
            -- The flat sheet always spans one circumference at the requested
            -- final radius. Repeat Around redistributes source tiles within it.
            local sheet_width = 2.0 * pi * radius_value
            local sheet_length = length_value * y_multiplier
            local cell_width = sheet_width / tiled_columns
            local cell_length = sheet_length / tiled_rows
            local precision_value = units.decodeValue ((position_precision_mm as string) + "mm")








            generated_node = plane width:sheet_width length:sheet_length widthsegs:(tiled_columns * arc_segments) lengthsegs:(tiled_rows * length_segments) name:"TPG_Module" mapcoords:true
            convertToPoly generated_node
            local expected_outer_faces = tiled_rows * tiled_columns * arc_segments * length_segments
            if base_thickness_value > 0.0 then
            (
                local base_shell_mod = Shell innerAmount:base_thickness_value outerAmount:0.0
                base_shell_mod.segments = 1
                addModifier generated_node base_shell_mod
                convertToPoly generated_node
                if generated_node.modifiers.count != 0 or classOf generated_node.baseObject != Editable_Poly then
                    throw "TPG | Failed to bake thickness into the flat Editable Poly base."
            )








            if (polyop.getHasDeadStructs generated_node) != 0 then
            (
                polyop.collapseDeadStructs generated_node
            )
            /* The flat Shell's X-facing end walls overlap at the cylinder closure.
               Delete them in one batch before Bend. Z-facing skins and Y-facing
               axial rims stay intact. No panel/face IDs have been cached yet.
            */
            if base_thickness_value > 0.0 then
            (
                local seam_thickness_faces = #{}
                local shell_face_count = polyop.getNumFaces generated_node.baseObject
                seam_thickness_faces.count = shell_face_count
                for face_id = 1 to shell_face_count do
                (
                    local shell_normal = polyop.getFaceNormal generated_node.baseObject face_id
                    if abs shell_normal.x == 1.0 then seam_thickness_faces[face_id] = true
                )
                local expected_seam_faces = 2 * tiled_rows * length_segments
                if seam_thickness_faces.numberSet != expected_seam_faces then
                    throw ("TPG | Thickness seam walls mismatch. Actual:" + seam_thickness_faces.numberSet as string + " expected:" + expected_seam_faces as string)
                polyop.deleteFaces generated_node.baseObject seam_thickness_faces delIsoVerts:false
                /* Deletion is complete; discard its indices before fresh cell maps. */
                seam_thickness_faces = undefined
                if (polyop.getHasDeadStructs generated_node.baseObject) != 0 then
                (
                    polyop.collapseDeadStructs generated_node.baseObject
                )
            )








            local cell_face_sets = #()
            cell_face_sets.count = tiled_mask.count








            for item_id = 1 to tiled_mask.count do
            (
                cell_face_sets[item_id] = #{}
            )








            local face_count = polyop.getNumFaces generated_node
            local mapping_valid = true
            local mapped_faces = 0
            local face_material_ids = #()
            face_material_ids.count = face_count








            /*
            Read local face vertex coordinates explicitly. This also avoids the
            face-center lookup that failed on the user's MAXScript runtime.
            */
            local poly_value = generated_node.baseObject








            for face_id = 1 to face_count do
            (
                -- Outer original sheet faces point in +Z. Shell back/side faces are not panel regions.
                local is_panel_face = base_thickness_value == 0.0 or (polyop.getFaceNormal poly_value face_id).z > 0.5
                if is_panel_face then
                (
                local face_vertex_ids = polyop.getFaceVerts poly_value face_id
                local face_center = [0.0, 0.0, 0.0]








                if face_vertex_ids.count == 0 then
                (
                    format "TPG ERROR | Empty face vertices | node:% face:%\n" generated_node.name face_id
                    mapping_valid = false
                )
                else
                (
                    for vertex_id in face_vertex_ids do
                    (
                        face_center += (polyop.getVert poly_value vertex_id)
                    )
                    face_center /= face_vertex_ids.count








                    /*
                    Quantize temporary face centers using documented floor/ceil primitives.
                    Round nearest, with half steps away from zero, without modifying geometry.
                    */
                    local scaled_x = face_center.x / precision_value
                    local scaled_y = face_center.y / precision_value
                    local rounded_x = if scaled_x >= 0.0 then (floor (scaled_x + 0.5)) else (ceil (scaled_x - 0.5))
                    local rounded_y = if scaled_y >= 0.0 then (floor (scaled_y + 0.5)) else (ceil (scaled_y - 0.5))
                    local center_x = rounded_x * precision_value
                    local center_y = rounded_y * precision_value
                    local column_id = ((floor ((center_x + sheet_width / 2.0) / cell_width)) as integer) + 1
                    /* Reverse longitudinal row mapping for IDs, mask and extrusion together.
                    */
                    local row_id = ((floor ((center_y + sheet_length / 2.0) / cell_length)) as integer) + 1








                    if column_id < 1 or column_id > tiled_columns or row_id < 1 or row_id > tiled_rows then
                    (
                        format "TPG ERROR | Face mapping outside grid | face:% center:% rounded:[%,%] row:% column:% precision_mm:%\n" face_id face_center center_x center_y row_id column_id position_precision_mm
                        mapping_valid = false
                    )
                    else
                    (
                        local expanded_cell_id = ((row_id - 1) * tiled_columns) + column_id
                        cell_face_sets[expanded_cell_id][face_id] = true
                        local source_cell_id = sourceCellId row_id column_id rows_value columns_value
                        face_material_ids[face_id] = cell_ids_value[source_cell_id]
                        mapped_faces += 1
                    )
                )
                )
            )








            if mapping_valid and mapped_faces == expected_outer_faces then
            (
                for face_id = 1 to face_count do
                (
                    if face_material_ids[face_id] != undefined then
                        polyop.setFaceMatID poly_value face_id face_material_ids[face_id]
                )


                /*
                Store the logical expanded cell for every base face in private UV 99.
                The triangulated input after Bend retains this immutable per-face tag.
                */
                polyop.setMapSupport poly_value 99 true
                -- Map vertex 1 denotes side and back faces. Only original top panel faces are active.
                polyop.setNumMapVerts poly_value 99 (tiled_mask.count + 1)
                polyop.setMapVert poly_value 99 1 [0.0,0.0,0.0]
                for face_id = 1 to face_count do
                (
                    local neutral_tags = for corner_id = 1 to (polyop.getFaceDeg poly_value face_id) collect 1
                    polyop.setMapFace poly_value 99 face_id neutral_tags
                )
                for expanded_cell_id = 1 to tiled_mask.count do
                (
                    local enabled_value = if tiled_mask[expanded_cell_id] then 1.0 else 0.0
                    local outer_tag_index = expanded_cell_id + 1
                    polyop.setMapVert poly_value 99 outer_tag_index [expanded_cell_id,enabled_value,0.0]
                    for face_id in cell_face_sets[expanded_cell_id] do
                    (
                        local map_face_vertices = for corner_id = 1 to (polyop.getFaceDeg poly_value face_id) collect outer_tag_index
                        polyop.setMapFace poly_value 99 face_id map_face_vertices
                    )
                )








                /*
                Permanent generator-owned stack: Editable Poly base, Bend, procedural extrusion.
                Parameters are saved before first modifier evaluation; no Modify-panel operations.
                */
                local bend_mod = Bend angle:360.0 direction:0.0 axis:0
                local extrusion_mod = TPGExtrusion_v name:"TPG Extrusion"
                local generation_exception = undefined
                try
                (
                    setUserProp generated_node "SPG_ExtrusionMode" encoded_extrusion_mode
                    setUserProp generated_node "SPG_RuleDepths" (encodeRuleDepths rule_depths_value)
                    setUserProp generated_node "SPG_RuleInsets" (encodeRuleDepths rule_insets_value)
                    setUserProp generated_node "SPG_RuleTapers" (encodeRuleDepths rule_tapers_value)
                    setUserProp generated_node "SPG_RuleCount" rule_count
                    setUserProp generated_node "SPG_TotalRows" tiled_rows
                    setUserProp generated_node "SPG_TotalColumns" tiled_columns
                    addModifier generated_node bend_mod
                    addModifier generated_node extrusion_mod
                    if generated_node.modifiers.count != 2 or generated_node.modifiers[1] != extrusion_mod or generated_node.modifiers[2] != bend_mod then
                        throw "TPG | Failed to build the procedural extrusion above Bend."
                    setAppData bend_mod 1847365210 "TPG:Bend"
                    setAppData extrusion_mod 1847365210 "TPG:Extrusion"
    
    
    
    
                    if isValidNode target_node then
                    (
                        instanceReplace target_node generated_node
                        delete generated_node
                        generated_node = target_node
                        if not isValidNode generated_node or generated_node.modifiers.count != 2 then
                        (
                            format "TPG ERROR | Instance replacement failed to preserve the bound node.\n"
                            throw "TPG regeneration failed."
                        )
                        format "TPG | Updated bound scene node:%\n" generated_node.name
                    )


                    -- Orient the evaluated module mesh independently of the scene node.
                    -- Keep the Editable Poly -> Bend -> TPG Extrusion stack untouched.
                    generated_node.objectOffsetRot = (quat 0 0 -1 0)
                    generated_node.rotation = (quat 0 0 0 1)
    
    
    
    
                    setAppData generated_node.modifiers[2] 1847365210 "TPG:Bend"
                    setAppData generated_node.modifiers[1] 1847365210 "TPG:Extrusion"
                    setUserProp generated_node "SPG_DataSchema" 2
                    setUserProp generated_node "SPG_GeneratorVersion" "0.089"
                    setUserProp generated_node "SPG_Owner" "Tank-Panel-Generator"
                    setUserProp generated_node "SPG_Rows" rows_value
                    setUserProp generated_node "SPG_Columns" columns_value
                    setUserProp generated_node "SPG_XMultiplier" x_multiplier
                    setUserProp generated_node "SPG_YMultiplier" y_multiplier
                    setUserProp generated_node "SPG_TotalRows" tiled_rows
                    setUserProp generated_node "SPG_TotalColumns" tiled_columns
                    setUserProp generated_node "SPG_ExpandedRadius" radius_value
                    setUserProp generated_node "SPG_ExpandedLength" sheet_length
                    setUserProp generated_node "SPG_Mask" (encodeMask mask_value)
                    setUserProp generated_node "SPG_CellIDs" (encodeCellIds cell_ids_value)
                    setUserProp generated_node "SPG_ExtrusionMode" encoded_extrusion_mode
                    setUserProp generated_node "SPG_RuleDepths" (encodeRuleDepths rule_depths_value)
                    setUserProp generated_node "SPG_RuleThicknesses" (encodeRuleDepths rule_thicknesses_value)
                    setUserProp generated_node "SPG_RuleOffsets" (encodeRuleDepths rule_offsets_value)
                    setUserProp generated_node "SPG_RuleInsets" (encodeRuleDepths rule_insets_value)
                    setUserProp generated_node "SPG_RuleTapers" (encodeRuleDepths rule_tapers_value)
                    setUserProp generated_node "SPG_RuleCount" rule_count
                    setUserProp generated_node "SPG_Radius" (formattedPrint radius_value format:".9g")
                    setUserProp generated_node "SPG_Length" (formattedPrint length_value format:".9g")
                    setUserProp generated_node "SPG_PanelDepth" depth_value
                    setUserProp generated_node "SPG_BaseThickness" (formattedPrint base_thickness_value format:".9g")
                    setUserProp generated_node "SPG_ArcSegments" arc_segments
                    setUserProp generated_node "SPG_LengthSegments" length_segments
                    setUserProp generated_node "SPG_LengthSegmentsAuto" (if length_segments_auto then 1 else 0)
                    setUserProp generated_node "SPG_PositionPrecisionMM" position_precision_mm
    
    
    
    
                    if not (applyMaterial generated_node rows_value columns_value material_mode_value rule_count:rule_count) then
                    (
                        throw "TPG material creation failed."
                    )
                    local configured_stack = syncChamferStack generated_node generated_node.modifiers[2] seams_enabled_value:seams_enabled_value seams_amount_value:seams_amount_value seams_offset_value:seams_offset_value chamfer_enabled_value:chamfer_enabled_value chamfer_amount_value:chamfer_amount_value chamfer_segments_value:chamfer_segments_value
                    configured_stack[2].refresh_counter += 1
                )
                catch
                (
                    generation_exception = getCurrentException()
                    format "TPG ERROR | Generation aborted | node:% error:%\n" generated_node generation_exception
                    if isValidNode generated_node and generated_node != target_node then
                    (
                        delete generated_node
                        generated_node = undefined
                    )
                )
                if generation_exception != undefined then throw generation_exception
                last_node = generated_node
                base_thickness = base_thickness_value
                last_bend_mod = (getOwnedStackParts generated_node)[3]
                format "TPG | Generated % | pattern:%x% repeats:%x% total cells:% active:% base faces:%\n" generated_node.name columns_value rows_value x_multiplier y_multiplier tiled_mask.count (countEnabled tiled_mask) face_count
            )
            else
            (
                format "TPG ERROR | Initial polygon-to-cell mapping invalid | mapped:% expected:%\n" mapped_faces face_count
                delete generated_node
                generated_node = undefined
            )
        )








        generated_node
        -- return
    ),








    on create do
    (
        mask = makeMask rows columns enabled:true
        cell_ids = makeCellIds rows columns
        rule_depths = makeRuleDepths (amax 99 (rows * columns)) (units.decodeValue "1cm")
        rule_thicknesses = makeRuleDepths rule_depths.count 0.0
        rule_offsets = makeRuleDepths rule_depths.count 0.0
        rule_insets = makeRuleDepths rule_depths.count 0.0
        rule_tapers = makeRuleDepths rule_depths.count 0.0
    )
)








global SurfacePanelGenerator
SurfacePanelGenerator = SurfacePanelGenerator_v()




/*
Manages named generator snapshots in the existing INI without storing dialog geometry.
Preset sections use stable numeric IDs so arbitrary user names never become INI keys.
*/
struct TPGPresetManager_v
(
    ini_path = "",
    main_section = "MainUI",
    registry_section = "TPG_Presets",
    setting_keys = #("Rows","Columns","XMultiplier","YMultiplier","Mask","CellIDs","MaterialMode","RuleCount","RuleDepths","RuleThicknesses","RuleOffsets","RuleInsets","RuleTapers","ExtrusionMode","ActiveRuleID","Radius","Length","BaseThickness","ArcSegments","LengthSegments","DimensionUnit","DimensionUnitSchema","SeamsEnabled","SeamsAmount","SeamsOffset","ChamferEnabled","ChamferAmount","ChamferSegments","CapEndRadius","CapThickness","CapDepth","CapSeams","CapFirstSeam","CapSeamSpacing","CapChamferAmount","CapChamferDepth","CapInset","CapSeamDepth","CapSeamSegments","CapTopSegments","CapSeamMaterial","CapEnter","CapExit"),
    panels_setting_keys = #("Rows","Columns","XMultiplier","YMultiplier","Mask","CellIDs","MaterialMode","ActiveRuleID","Radius","Length","BaseThickness","ArcSegments","LengthSegments","DimensionUnit","DimensionUnitSchema"),
    extrude_setting_keys = #("RuleCount","RuleDepths","RuleThicknesses","RuleOffsets","RuleInsets","RuleTapers","ExtrusionMode"),
    seams_setting_keys = #("SeamsEnabled","SeamsAmount","SeamsOffset"),
    chamfer_setting_keys = #("ChamferEnabled","ChamferAmount","ChamferSegments"),
    hatch_setting_keys = #("CapEndRadius","CapThickness","CapDepth","CapSeams","CapFirstSeam","CapSeamSpacing","CapChamferAmount","CapChamferDepth","CapInset","CapSeamDepth","CapSeamSegments","CapTopSegments","CapSeamMaterial","CapEnter","CapExit"),


    /*
    Finds the stable INI section for a numeric preset identifier.
    */
    function presetSection preset_id =
    (
        "TPG_Preset_" + (preset_id as string)
        -- return
    ),


    /*
    Reads numeric preset IDs in their original saved order.
    */
    function getPresetIds =
    (
        local id_tokens = filterString (getINISetting ini_path registry_section "IDs") ";"
        local id_values = #()
        for id_token in id_tokens do
        (
            local preset_id = undefined
            try
            (
                preset_id = id_token as integer
            )
            catch
            (
                format "TPG PRESETS | Invalid preset registry ID:% error:%\n" id_token (getCurrentException())
                throw()
            )
            if preset_id == undefined or preset_id < 1 then
            (
                format "TPG PRESETS | Invalid preset registry ID:% expected positive integer.\n" id_token
                throw "TPG PRESETS | Invalid stored preset registry."
            )
            append id_values preset_id
        )
        id_values
        -- return
    ),


    /*
    Saves a list of preset IDs without changing their stored sections.
    */
    function setPresetIds id_values =
    (
        local encoded_ids = ""
        for preset_id in id_values do
        (
            if encoded_ids != "" then encoded_ids += ";"
            encoded_ids += preset_id as string
        )
        setINISetting ini_path registry_section "IDs" encoded_ids
        true
        -- return
    ),


    /*
    Resolves a name case-insensitively while leaving its display spelling intact.
    */
    function findPresetId preset_name =
    (
        local matching_id = 0
        local match_text = toLower (trimRight (trimLeft preset_name))
        if match_text == "" then return 0
        for preset_id in (getPresetIds()) while matching_id == 0 do
        (
            local current_name = getINISetting ini_path (presetSection preset_id) "Name"
            if toLower current_name == match_text then matching_id = preset_id
        )
        matching_id
        -- return
    ),


    /*
    Lists named presets, preserving their saved order and original capitalization.
    */
    function getPresetNames =
    (
        local preset_names = #()
        for preset_id in (getPresetIds()) do
        (
            local preset_name = getINISetting ini_path (presetSection preset_id) "Name"
            if preset_name != "" then append preset_names preset_name
        )
        preset_names
        -- return
    ),


    /*
    Creates or overwrites one named snapshot of generator settings.
    */
    function savePreset preset_name =
    (
        local clean_name = trimRight (trimLeft preset_name)
        if clean_name == "" then return false
        local preset_id = findPresetId clean_name
        if preset_id == 0 then
        (
            local saved_next_id = getINISetting ini_path registry_section "NextID"
            preset_id = if saved_next_id == "" then 1 else undefined
            if saved_next_id != "" then
            (
                try
                (
                    preset_id = saved_next_id as integer
                )
                catch
                (
                    format "TPG PRESETS | Invalid next preset ID:% error:%\n" saved_next_id (getCurrentException())
                    throw()
                )
                if preset_id == undefined or preset_id < 1 then
                (
                    format "TPG PRESETS | Invalid next preset ID:% expected positive integer.\n" saved_next_id
                    throw "TPG PRESETS | Invalid stored next preset ID."
                )
            )
            local existing_ids = getPresetIds()
            while (findItem existing_ids preset_id) > 0 do preset_id += 1
            append existing_ids preset_id
            setPresetIds existing_ids
            setINISetting ini_path registry_section "NextID" ((preset_id + 1) as string)
        )
        local preset_section = presetSection preset_id
        setINISetting ini_path preset_section "Name" clean_name
        for setting_key in setting_keys do
        (
            setINISetting ini_path preset_section setting_key (getINISetting ini_path main_section setting_key)
        )
        true
        -- return
    ),


    /*
    Restores all settings or only the selected section, never dialog state.
    */
    function loadPreset preset_name mode:#all =
    (
        local preset_id = findPresetId preset_name
        if preset_id == 0 then return false
        local selected_keys = case mode of
        (
            #all: setting_keys
            #panels: panels_setting_keys
            #extrude: extrude_setting_keys
            #seams: seams_setting_keys
            #chamfer: chamfer_setting_keys
            #hatch: hatch_setting_keys
            default: undefined
        )
        if selected_keys == undefined then
        (
            format "TPG PRESETS | Invalid load mode:% expected #all, #panels, #extrude, or #hatch.\n" mode
            return false
        )
        local preset_section = presetSection preset_id
        local saved_extrusion_mode = getINISetting ini_path preset_section "ExtrusionMode"
        if mode == #all or mode == #extrude then
            saved_extrusion_mode = tpgEncodeExtrusionMode (tpgDecodeExtrusionMode saved_extrusion_mode)
        for setting_key in selected_keys do
        (
            local stored_value = getINISetting ini_path preset_section setting_key
            if setting_key == "ExtrusionMode" then stored_value = saved_extrusion_mode
            if setting_key == "ChamferSegments" and stored_value == "" then stored_value = "1"
            if setting_key == "BaseThickness" and stored_value == "" then stored_value = "0"
            if stored_value == "" and (findItem #("CapSeamSegments","CapTopSegments","CapEnter") setting_key) > 0 then stored_value = "0"
            if stored_value == "" and setting_key == "CapSeamMaterial" then stored_value = "99"
            if stored_value == "" and setting_key == "CapExit" then stored_value = "1"
            /* An empty legacy depth key restores the UI's five selected-unit default. */
            if setting_key == "CapSeamDepth" and stored_value == "" then
                setINISetting ini_path main_section setting_key ""
            else if stored_value != "" then setINISetting ini_path main_section setting_key stored_value
        )
        true
        -- return
    ),


    /*
    Renames an existing snapshot without copying or altering its setting values.
    */
    function renamePreset old_name new_name =
    (
        local preset_id = findPresetId old_name
        local clean_name = trimRight (trimLeft new_name)
        local duplicate_id = findPresetId clean_name
        if preset_id == 0 or clean_name == "" or (duplicate_id != 0 and duplicate_id != preset_id) then return false
        setINISetting ini_path (presetSection preset_id) "Name" clean_name
        true
        -- return
    ),


    /*
    Removes one named snapshot and its associated INI section.
    */
    function deletePreset preset_name =
    (
        local preset_id = findPresetId preset_name
        if preset_id == 0 then return false
        local existing_ids = getPresetIds()
        deleteItem existing_ids (findItem existing_ids preset_id)
        delINISetting ini_path (presetSection preset_id)
        setPresetIds existing_ids
        true
        -- return
    ),


    on create do
    (
    )
)




/*
Export the preset constructor from this dependency's fileIn scope.
The main rollout is compiled in a different scope and needs its global binding.
*/
::TPGPresetManager_v = TPGPresetManager_v




