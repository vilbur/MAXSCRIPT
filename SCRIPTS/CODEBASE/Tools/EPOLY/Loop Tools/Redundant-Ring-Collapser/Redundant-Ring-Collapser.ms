/*
    Redundant Ring Collapser 0.07
    Standalone conservative tool for detecting and collapsing edge rings between pairs of adjacent redundant loops.
*/

global RedundantRingCollapser
global RedundantRingCollapser_Test_UI
global RedundantRingCollapser_Title
global RedundantRingCollapser_Source_File
global RedundantRingCollapser_Script_Reload_Path
global RedundantRingCollapser_Tool_Title_Button_Path
global epoly_tools_project_version
global EPolyToolsIntegration
global EPOLY_TOOLS_RUNTIME_MODE
global EPOLY_TOOLS_MANAGER_PATH
global EPOLY_TOOLS_MANAGER_PREVIOUS_RUNTIME_MODE
global EPOLY_TOOLS_MANAGER_LOAD_ERROR
global EPOLY_TOOLS_MANAGER_SEARCH_DIRECTORY
global EPOLY_TOOLS_MANAGER_PARENT_DIRECTORY
global EPOLY_TOOLS_MANAGER_CANDIDATE_PATH
global EPOLY_TOOLS_MANAGER_SEARCH_DEPTH
global EPOLY_TOOLS_MANAGER_SEARCH_PATH_WITHOUT_SEPARATOR

RedundantRingCollapser_Source_File = getSourceFileName()

if RedundantRingCollapser_Source_File == undefined or RedundantRingCollapser_Source_File == "" then
(
    throw "Redundant-Ring-Collapser must be executed from a saved .ms file."
)

RedundantRingCollapser_Script_Reload_Path = (getFilenamePath RedundantRingCollapser_Source_File) + "..\\..\\..\\..\\..\\UI\\Default\\ScriptReload.ms"
RedundantRingCollapser_Tool_Title_Button_Path = (getFilenamePath RedundantRingCollapser_Source_File) + "..\\..\\..\\..\\..\\UI\\Default\\ToolTitleButton.ms"

if not doesFileExist RedundantRingCollapser_Script_Reload_Path then
(
    throw ("Missing shared UI dependency: " + RedundantRingCollapser_Script_Reload_Path)
)

if not doesFileExist RedundantRingCollapser_Tool_Title_Button_Path then
(
    throw ("Missing shared UI dependency: " + RedundantRingCollapser_Tool_Title_Button_Path)
)

fileIn RedundantRingCollapser_Script_Reload_Path
fileIn RedundantRingCollapser_Tool_Title_Button_Path

try(destroyDialog RedundantRingCollapser_Test_UI)catch()

if EPolyToolsIntegration == undefined then
(
    EPOLY_TOOLS_MANAGER_PATH = undefined
    EPOLY_TOOLS_MANAGER_SEARCH_DIRECTORY = getFilenamePath (getSourceFileName())
    EPOLY_TOOLS_MANAGER_PARENT_DIRECTORY = undefined
    EPOLY_TOOLS_MANAGER_CANDIDATE_PATH = undefined
    EPOLY_TOOLS_MANAGER_SEARCH_DEPTH = 0

    while EPOLY_TOOLS_MANAGER_PATH == undefined and EPOLY_TOOLS_MANAGER_SEARCH_DIRECTORY != "" and EPOLY_TOOLS_MANAGER_SEARCH_DEPTH < 16 do
    (
        EPOLY_TOOLS_MANAGER_CANDIDATE_PATH = EPOLY_TOOLS_MANAGER_SEARCH_DIRECTORY + "PolyToosManager.ms"

        if doesFileExist EPOLY_TOOLS_MANAGER_CANDIDATE_PATH then
        (
            EPOLY_TOOLS_MANAGER_PATH = EPOLY_TOOLS_MANAGER_CANDIDATE_PATH
        )
        else
        (
            EPOLY_TOOLS_MANAGER_SEARCH_PATH_WITHOUT_SEPARATOR = EPOLY_TOOLS_MANAGER_SEARCH_DIRECTORY

            if EPOLY_TOOLS_MANAGER_SEARCH_PATH_WITHOUT_SEPARATOR.count > 0 and EPOLY_TOOLS_MANAGER_SEARCH_PATH_WITHOUT_SEPARATOR[EPOLY_TOOLS_MANAGER_SEARCH_PATH_WITHOUT_SEPARATOR.count] == "\\" then
            (
                EPOLY_TOOLS_MANAGER_SEARCH_PATH_WITHOUT_SEPARATOR = substring EPOLY_TOOLS_MANAGER_SEARCH_PATH_WITHOUT_SEPARATOR 1 (EPOLY_TOOLS_MANAGER_SEARCH_PATH_WITHOUT_SEPARATOR.count - 1)
            )

            EPOLY_TOOLS_MANAGER_PARENT_DIRECTORY = getFilenamePath EPOLY_TOOLS_MANAGER_SEARCH_PATH_WITHOUT_SEPARATOR

            if EPOLY_TOOLS_MANAGER_PARENT_DIRECTORY == EPOLY_TOOLS_MANAGER_SEARCH_DIRECTORY then
            (
                EPOLY_TOOLS_MANAGER_SEARCH_DIRECTORY = ""
            )
            else
            (
                EPOLY_TOOLS_MANAGER_SEARCH_DIRECTORY = EPOLY_TOOLS_MANAGER_PARENT_DIRECTORY
            )
        )

        EPOLY_TOOLS_MANAGER_SEARCH_DEPTH += 1
    )

    EPOLY_TOOLS_MANAGER_PREVIOUS_RUNTIME_MODE = EPOLY_TOOLS_RUNTIME_MODE
    EPOLY_TOOLS_MANAGER_LOAD_ERROR = undefined
    EPOLY_TOOLS_RUNTIME_MODE = #library

    if EPOLY_TOOLS_MANAGER_PATH != undefined then
    (
        try
        (
            fileIn EPOLY_TOOLS_MANAGER_PATH quiet:true -- resolved parent PolyToosManager.ms
        )
        catch
        (
            EPOLY_TOOLS_MANAGER_LOAD_ERROR = getCurrentException()
        )
    )
    else
    (
        EPOLY_TOOLS_MANAGER_LOAD_ERROR = "PolyToosManager.ms was not found in any parent EPolyTools directory."
    )

    EPOLY_TOOLS_RUNTIME_MODE = EPOLY_TOOLS_MANAGER_PREVIOUS_RUNTIME_MODE
    EPOLY_TOOLS_MANAGER_PREVIOUS_RUNTIME_MODE = undefined
    EPOLY_TOOLS_MANAGER_PATH = undefined
    EPOLY_TOOLS_MANAGER_SEARCH_DIRECTORY = undefined
    EPOLY_TOOLS_MANAGER_PARENT_DIRECTORY = undefined
    EPOLY_TOOLS_MANAGER_CANDIDATE_PATH = undefined
    EPOLY_TOOLS_MANAGER_SEARCH_DEPTH = undefined
    EPOLY_TOOLS_MANAGER_SEARCH_PATH_WITHOUT_SEPARATOR = undefined

    if EPOLY_TOOLS_MANAGER_LOAD_ERROR != undefined then
    (
        throw EPOLY_TOOLS_MANAGER_LOAD_ERROR
    )
)

struct RedundantRingCollapser_v
(
    file_version = 0.07,
    project_version = 1.188,
    face_angle_threshold = 0.1,
    straight_angle_threshold = 2.0,
    coincidence_tolerance = 0.001,
    crease_epsilon = 0.000001,

    /*
    Registers this file's shared EPolyTools project version.
    The highest loaded project version always wins.
    */
    function registerProjectVersion =
    (
        if EPolyToolsIntegration != undefined then
        (
            epoly_tools_project_version = EPolyToolsIntegration.registerProjectVersion project_version
        )
        else
        (
            if epoly_tools_project_version == undefined then
            (
                epoly_tools_project_version = project_version
            )
            else if project_version > epoly_tools_project_version then
            (
                epoly_tools_project_version = project_version
            )
        )

        epoly_tools_project_version
        -- return
    ),

    /*
    Forces Editable Poly and Edit Poly selection mode to normal component selection.
    Every selection read/write path in this tool uses selectMode 0.
    */
    function forceSelectModeZero editable_poly =
    (
        if editable_poly == undefined then return false

        try(editable_poly.selectMode = 0)catch()
        try(editable_poly.showCage = false)catch()
        true
        -- return
    ),

    /*
    Returns the opposite vertex of an incident edge.
    Invalid topology returns undefined.
    */
    function getOtherVertex vertex_index edge_index edge_vertices =
    (
        if edge_index < 1 or edge_index > edge_vertices.count then return undefined

        edge_pair = edge_vertices[edge_index]
        if edge_pair == undefined or edge_pair.count != 2 then return undefined

        if edge_pair[1] == vertex_index then
        (
            edge_pair[2]
        )
        else if edge_pair[2] == vertex_index then
        (
            edge_pair[1]
        )
        else
        (
            undefined
        )
        -- return
    ),

    /*
    Returns the geometric length of one analyzed topology edge.
    Invalid topology returns zero.
    */
    function getEdgeLength edge_index edge_vertices vertex_points =
    (
        if edge_index < 1 or edge_index > edge_vertices.count then return 0.0

        edge_pair = edge_vertices[edge_index]
        if edge_pair == undefined or edge_pair.count != 2 then return 0.0

        point_a = vertex_points[edge_pair[1]]
        point_b = vertex_points[edge_pair[2]]
        if point_a == undefined or point_b == undefined then return 0.0

        distance point_a point_b
        -- return
    ),

    /*
    Returns a normalized direction from one vertex along one incident edge.
    Zero-length edges return undefined.
    */
    function getEdgeDirection vertex_index edge_index edge_vertices vertex_points =
    (
        other_vertex = getOtherVertex vertex_index edge_index edge_vertices
        if other_vertex == undefined then return undefined

        direction_value = vertex_points[other_vertex] - vertex_points[vertex_index]
        if length direction_value <= 0.0000001 then return undefined

        normalize direction_value
        -- return
    ),

    /*
    Recursively pairs every edge with one opposite straight continuation.
    Backtracking avoids order-dependent rejection at crossings.
    */
    function canPairEdges vertex_index edge_array edge_vertices vertex_points straight_limit =
    (
        if edge_array.count == 0 then return true
        if (mod edge_array.count 2) != 0 then return false

        first_edge = edge_array[1]
        first_direction = getEdgeDirection vertex_index first_edge edge_vertices vertex_points
        if first_direction == undefined then return false

        for pair_index = 2 to edge_array.count do
        (
            pair_edge = edge_array[pair_index]
            pair_direction = getEdgeDirection vertex_index pair_edge edge_vertices vertex_points

            if pair_direction != undefined then
            (
                if (dot first_direction pair_direction) <= -straight_limit then
                (
                    remaining_edges = #()

                    for index = 2 to edge_array.count do
                    (
                        if index != pair_index then append remaining_edges edge_array[index]
                    )

                    if canPairEdges vertex_index remaining_edges edge_vertices vertex_points straight_limit then return true
                )
            )
        )

        false
        -- return
    ),

    /*
    Tests whether all supplied incident edges form straight-through opposite pairs.
    Empty input is accepted; odd or unmatched sets are rejected.
    */
    function areEdgesStraightPairs vertex_index edge_set edge_vertices vertex_points angle_threshold:2.0 =
    (
        if edge_set.numberSet == 0 then return true
        if (mod edge_set.numberSet 2) != 0 then return false

        canPairEdges vertex_index (edge_set as array) edge_vertices vertex_points (cos angle_threshold)
        -- return
    ),

    /*
    Reads native Editable Poly topology without changing geometry.
    Vertex positions and face normals are captured in world space while native edge IDs are preserved.
    */
    function buildPolyTopology node poly_value =
    (
        if node == undefined or not(isValidNode node) then return undefined
        if poly_value == undefined or classOf poly_value != Editable_Poly then return undefined

        vertex_count = polyop.getNumVerts poly_value
        edge_count = polyop.getNumEdges poly_value
        face_count = polyop.getNumFaces poly_value

        if vertex_count < 2 or edge_count < 1 or face_count < 1 then return undefined

        vertex_points = #()
        vertex_edges = #()
        vertex_faces = #()

        for vertex_index = 1 to vertex_count do
        (
            vertex_point = undefined

            in coordsys world
            (
                vertex_point = polyop.getVert poly_value vertex_index node:node
            )

            append vertex_points vertex_point
            append vertex_edges #{}
            append vertex_faces #{}
        )

        edge_vertices = #()
        edge_faces = #()
        border_edges = #{}
        border_vertices = #{}

        for edge_index = 1 to edge_count do
        (
            edge_pair = polyop.getEdgeVerts poly_value edge_index
            edge_face_array = polyop.getEdgeFaces poly_value edge_index

            edge_valid = edge_pair != undefined and edge_pair.count == 2
            if edge_valid then edge_valid = edge_pair[1] >= 1 and edge_pair[1] <= vertex_count and edge_pair[2] >= 1 and edge_pair[2] <= vertex_count

            if edge_valid then
            (
                append edge_vertices #(edge_pair[1], edge_pair[2])
                vertex_edges[edge_pair[1]][edge_index] = true
                vertex_edges[edge_pair[2]][edge_index] = true

                face_a = 0
                face_b = 0

                if edge_face_array != undefined then
                (
                    if edge_face_array.count >= 1 then face_a = edge_face_array[1]
                    if edge_face_array.count >= 2 then face_b = edge_face_array[2]
                )

                append edge_faces #(face_a, face_b)

                if face_a > 0 and face_b == 0 then
                (
                    border_edges[edge_index] = true
                    border_vertices[edge_pair[1]] = true
                    border_vertices[edge_pair[2]] = true
                )
            )
            else
            (
                append edge_vertices undefined
                append edge_faces undefined
            )
        )

        face_normals = #()
        face_valid = #{}

        for face_index = 1 to face_count do
        (
            face_vertices = polyop.getFaceVerts poly_value face_index
            face_normal = undefined

            if face_vertices != undefined and face_vertices.count >= 3 then
            (
                for vertex_index in face_vertices do
                (
                    if vertex_index >= 1 and vertex_index <= vertex_count then vertex_faces[vertex_index][face_index] = true
                )

                in coordsys world
                (
                    face_normal = polyop.getFaceNormal poly_value face_index node:node
                )

                if face_normal != undefined then
                (
                    if length face_normal > 0.0000001 then
                    (
                        face_normal = normalize face_normal
                        face_valid[face_index] = true
                    )
                    else
                    (
                        face_normal = undefined
                    )
                )
            )

            append face_normals face_normal
            append face_vertices_list (if face_vertices != undefined then face_vertices else #())
        )

        #(
            vertex_count,
            edge_count,
            face_count,
            vertex_points,
            vertex_edges,
            vertex_faces,
            edge_vertices,
            edge_faces,
            border_edges,
            border_vertices,
            face_normals,
            face_valid,
            face_vertices_list
        )
        -- return
    ),

    /*
    Returns explicit edge creases from Editable Poly edge-data channel 2.
    Unsupported crease data means that no explicit crease is present.
    */
    function getCreaseEdges poly_value edge_count =
    (
        crease_edges = #{}

        if polyop.getEDataChannelSupport poly_value 2 then
        (
            for edge_index = 1 to edge_count do
            (
                crease_value = polyop.getEDataValue poly_value 2 edge_index
                if crease_value != undefined and abs crease_value > crease_epsilon then crease_edges[edge_index] = true
            )
        )

        crease_edges
        -- return
    ),

    /*
    Acquires the evaluated top-of-stack geometry for read-only analysis.
    A modifier-free Editable Poly is read directly; any other stack is evaluated on a disposable collapsed copy.
    */
    function acquireAnalysisSource node =
    (
        if node == undefined or not(isValidNode node) then return undefined

        if classOf node.baseObject == Editable_Poly and node.modifiers.count == 0 then
        (
            forceSelectModeZero node.baseObject
            #(node, node.baseObject, false)
        )
        else
        (
            temp_node = undefined
            result_data = undefined

            try
            (
                with undo off
                (
                    temp_node = copy node
                    temp_node.name = uniqueName "__REDUNDANT_LOOP_ANALYSIS__"
                    convertToPoly temp_node

                    if classOf temp_node.baseObject != Editable_Poly then throw "evaluated copy is not Editable Poly"
                    forceSelectModeZero temp_node.baseObject
                    result_data = #(temp_node, temp_node.baseObject, true)
                )
            )
            catch
            (
                if temp_node != undefined then try(delete temp_node)catch()
                result_data = undefined
            )

            result_data
        )
        -- return
    ),

    /*
    Releases only disposable analysis geometry.
    The user's original object is never deleted or collapsed.
    */
    function releaseAnalysisSource analysis_source =
    (
        if analysis_source == undefined then return false

        if analysis_source[3] then
        (
            analysis_node = analysis_source[1]

            if analysis_node != undefined and isValidNode analysis_node then
            (
                with undo off
                (
                    try(delete analysis_node)catch()
                )
            )
        )

        true
        -- return
    ),

    /*
    Removes only near-zero and exact duplicate support edges from terminal topology tests.
    Real angled branches, border corners, and distinct continuations remain in the effective incidence set.
    */
    function getEffectiveIncidentEdges vertex_index chain_edges vertex_edges edge_vertices vertex_points =
    (
        if vertex_index < 1 or vertex_index > vertex_edges.count then return #{}

        incident_edges = vertex_edges[vertex_index]
        effective_edges = #{}
        chain_other_points = #()

        for chain_edge in (incident_edges * chain_edges) do
        (
            chain_other_vertex = getOtherVertex vertex_index chain_edge edge_vertices

            if chain_other_vertex != undefined then
            (
                chain_other_point = vertex_points[chain_other_vertex]
                if chain_other_point != undefined then append chain_other_points chain_other_point
            )
        )

        for edge_index in incident_edges do
        (
            keep_edge = true

            if not chain_edges[edge_index] then
            (
                if getEdgeLength edge_index edge_vertices vertex_points <= coincidence_tolerance then
                (
                    keep_edge = false
                )
                else
                (
                    other_vertex = getOtherVertex vertex_index edge_index edge_vertices

                    if other_vertex == undefined then
                    (
                        keep_edge = false
                    )
                    else
                    (
                        other_point = vertex_points[other_vertex]

                        if other_point == undefined then
                        (
                            keep_edge = false
                        )
                        else
                        (
                            for chain_other_point in chain_other_points while keep_edge do
                            (
                                if distance other_point chain_other_point <= coincidence_tolerance then keep_edge = false
                            )
                        )
                    )
                )
            )

            if keep_edge then effective_edges[edge_index] = true
        )

        effective_edges
        -- return
    ),

    /*
    Tests one strict straight open-border terminal.
    A real border corner is rejected because its two border continuations are not opposite within the straightness tolerance.
    */
    function isValidOpenBorderTerminal vertex_index chain_incident_edges border_edges vertex_edges edge_vertices vertex_points angle_threshold:2.0 =
    (
        if chain_incident_edges.numberSet != 1 then return false

        effective_edges = getEffectiveIncidentEdges vertex_index chain_incident_edges vertex_edges edge_vertices vertex_points
        effective_chain = effective_edges * chain_incident_edges
        effective_border = effective_edges * border_edges

        if effective_chain.numberSet != 1 then return false
        if effective_border.numberSet != 2 then return false
        if effective_edges.numberSet != 3 then return false
        if not(areEdgesStraightPairs vertex_index effective_border edge_vertices vertex_points angle_threshold:angle_threshold) then return false

        true
        -- return
    ),

    /*
    Tests one internal straight T-junction or crossing terminal.
    Every effective non-chain edge must be consumed by an opposite straight-through pair.
    */
    function isValidInternalTerminal vertex_index chain_incident_edges border_edges vertex_edges edge_vertices vertex_points angle_threshold:2.0 =
    (
        if chain_incident_edges.numberSet != 1 then return false

        effective_edges = getEffectiveIncidentEdges vertex_index chain_incident_edges vertex_edges edge_vertices vertex_points
        effective_chain = effective_edges * chain_incident_edges

        if effective_chain.numberSet != 1 then return false
        if (vertex_edges[vertex_index] * border_edges).numberSet > 0 then return false

        remaining_edges = effective_edges - effective_chain
        if remaining_edges.numberSet < 2 then return false

        areEdgesStraightPairs vertex_index remaining_edges edge_vertices vertex_points angle_threshold:angle_threshold
        -- return
    ),

    /*
    Tests one legal chain terminal and never lets a border vertex fall through to the internal T-junction rule.
    Any raw border incidence forces strict open-border validation.
    */
    function isValidTerminal vertex_index chain_incident_edges border_edges vertex_edges edge_vertices vertex_points angle_threshold:2.0 =
    (
        if vertex_index < 1 or vertex_index > vertex_edges.count then return false
        if chain_incident_edges.numberSet != 1 then return false

        raw_border_edges = vertex_edges[vertex_index] * border_edges

        if raw_border_edges.numberSet > 0 then
        (
            isValidOpenBorderTerminal vertex_index chain_incident_edges border_edges vertex_edges edge_vertices vertex_points angle_threshold:angle_threshold
        )
        else
        (
            isValidInternalTerminal vertex_index chain_incident_edges border_edges vertex_edges edge_vertices vertex_points angle_threshold:angle_threshold
        )
        -- return
    ),

    /*
    Tests one internal chain vertex before traversal continues through it.
    The incoming/outgoing pair must be straight and all unrelated effective edges must pair straight through.
    */
    function isValidInternalVertex vertex_index incoming_edge outgoing_edge border_edges vertex_edges edge_vertices vertex_points angle_threshold:2.0 =
    (
        if (vertex_edges[vertex_index] * border_edges).numberSet > 0 then return false

        chain_pair = #{}
        chain_pair[incoming_edge] = true
        chain_pair[outgoing_edge] = true

        effective_edges = getEffectiveIncidentEdges vertex_index chain_pair vertex_edges edge_vertices vertex_points
        effective_chain = effective_edges * chain_pair

        if effective_chain.numberSet != 2 then return false
        if not(areEdgesStraightPairs vertex_index effective_chain edge_vertices vertex_points angle_threshold:angle_threshold) then return false

        transverse_edges = effective_edges - effective_chain

        if transverse_edges.numberSet > 0 then
        (
            if not(areEdgesStraightPairs vertex_index transverse_edges edge_vertices vertex_points angle_threshold:angle_threshold) then return false
        )

        true
        -- return
    ),

    /*
    Verifies every live face incident to one chain vertex against the chain reference plane orientation.
    Opposite normal direction is accepted by comparing the absolute dot product.
    */
    function isVertexPlanar vertex_index vertex_faces face_normals face_valid reference_normal angle_threshold:0.1 =
    (
        if vertex_index < 1 or vertex_index > vertex_faces.count then return false
        if reference_normal == undefined then return false

        normal_limit = cos angle_threshold
        incident_face_count = 0

        for face_index in vertex_faces[vertex_index] do
        (
            if face_index < 1 or face_index > face_normals.count then return false
            if face_index > face_valid.count or not face_valid[face_index] then return false

            face_normal = face_normals[face_index]
            if face_normal == undefined then return false

            incident_face_count += 1
            if abs(dot reference_normal face_normal) < normal_limit then return false
        )

        incident_face_count > 0
        -- return
    ),

    /*
    Builds the conservative internal edge candidate set.
    Border, explicit crease, zero-length, invalid-adjacency, and non-coplanar edges are rejected before traversal.
    */
    function buildCandidateEdges topology_data crease_edges angle_threshold:0.1 =
    (
        edge_count = topology_data[2]
        face_count = topology_data[3]
        vertex_points = topology_data[4]
        edge_vertices = topology_data[7]
        edge_faces = topology_data[8]
        border_edges = topology_data[9]
        face_normals = topology_data[11]
        face_valid = topology_data[12]

        candidate_edges = #{}
        normal_limit = cos angle_threshold

        for edge_index = 1 to edge_count do
        (
            edge_pair = edge_vertices[edge_index]
            face_pair = edge_faces[edge_index]
            is_border = border_edges[edge_index]
            is_crease = crease_edges[edge_index]

            if edge_pair != undefined and face_pair != undefined and not is_border and not is_crease then
            (
                if getEdgeLength edge_index edge_vertices vertex_points > coincidence_tolerance then
                (
                    face_a = face_pair[1]
                    face_b = face_pair[2]

                    if face_a > 0 and face_b > 0 and face_a <= face_count and face_b <= face_count then
                    (
                        if face_valid[face_a] and face_valid[face_b] then
                        (
                            if abs(dot face_normals[face_a] face_normals[face_b]) >= normal_limit then candidate_edges[edge_index] = true
                        )
                    )
                )
            )
        )

        candidate_edges
        -- return
    ),

    /*
    Tests one isolated internal divider edge separately from open-chain terminal logic.
    It must be an internal coplanar candidate with no other candidate edge incident at either endpoint.
    */
    function isValidIsolatedDivider edge_index candidate_edges topology_data face_threshold:0.1 =
    (
        if edge_index < 1 or edge_index > topology_data[2] then return false
        if not candidate_edges[edge_index] then return false

        vertex_edges = topology_data[5]
        vertex_faces = topology_data[6]
        edge_vertices = topology_data[7]
        edge_faces = topology_data[8]
        face_normals = topology_data[11]
        face_valid = topology_data[12]

        edge_pair = edge_vertices[edge_index]
        face_pair = edge_faces[edge_index]
        if edge_pair == undefined or edge_pair.count != 2 then return false
        if face_pair == undefined or face_pair.count != 2 then return false

        face_a = face_pair[1]
        face_b = face_pair[2]
        if face_a < 1 or face_b < 1 then return false
        if face_a > face_normals.count or face_b > face_normals.count then return false
        if not face_valid[face_a] or not face_valid[face_b] then return false

        reference_normal = face_normals[face_a]
        if reference_normal == undefined then return false

        divider_edge = #{}
        divider_edge[edge_index] = true

        for vertex_index in edge_pair do
        (
            other_candidates = (vertex_edges[vertex_index] * candidate_edges) - divider_edge
            if other_candidates.numberSet > 0 then return false

            if not(isVertexPlanar vertex_index vertex_faces face_normals face_valid reference_normal angle_threshold:face_threshold) then return false
        )

        true
        -- return
    ),

    /*
    Validates a completed chain as one planar, straight, terminal-to-terminal topology feature.
    Any invalid endpoint, branch, border incidence, or non-planar incident face rejects the whole chain.
    */
    function validateChain chain_edges chain_vertices start_vertex end_vertex candidate_edges topology_data reference_normal face_threshold:0.1 straight_threshold:2.0 =
    (
        if chain_edges.numberSet == 0 then return #(false, "empty chain")
        if chain_vertices.count < 2 then return #(false, "chain has fewer than two vertices")
        if start_vertex == end_vertex then return #(false, "chain returns to its start")
        if (chain_edges - candidate_edges).numberSet > 0 then return #(false, "chain contains a non-candidate edge")

        vertex_points = topology_data[4]
        vertex_edges = topology_data[5]
        vertex_faces = topology_data[6]
        edge_vertices = topology_data[7]
        border_edges = topology_data[9]
        face_normals = topology_data[11]
        face_valid = topology_data[12]

        for vertex_index in chain_vertices do
        (
            if not(isVertexPlanar vertex_index vertex_faces face_normals face_valid reference_normal angle_threshold:face_threshold) then
            (
                return #(false, "non-planar incident faces at vertex " + (vertex_index as string))
            )

            chain_incident_edges = vertex_edges[vertex_index] * chain_edges
            is_endpoint = vertex_index == start_vertex or vertex_index == end_vertex

            if is_endpoint then
            (
                if not(isValidTerminal vertex_index chain_incident_edges border_edges vertex_edges edge_vertices vertex_points angle_threshold:straight_threshold) then
                (
                    return #(false, "invalid terminal topology at vertex " + (vertex_index as string))
                )
            )
            else
            (
                if chain_incident_edges.numberSet != 2 then return #(false, "internal vertex does not have exactly two chain edges at vertex " + (vertex_index as string))

                chain_pair = chain_incident_edges as array

                if not(isValidInternalVertex vertex_index chain_pair[1] chain_pair[2] border_edges vertex_edges edge_vertices vertex_points angle_threshold:straight_threshold) then
                (
                    return #(false, "invalid internal branch topology at vertex " + (vertex_index as string))
                )
            )
        )

        #(true, "")
        -- return
    ),

    /*
    Creates a stable key for duplicate suppression when the same chain is traversed from both terminals.
    BitArray iteration keeps edge IDs sorted automatically.
    */
    function makeChainKey chain_edges =
    (
        key_text = ""
        for edge_index in chain_edges do key_text += (edge_index as string) + ","
        key_text
        -- return
    ),

    /*
    Detects redundant straight internal chains on one selected node without changing its geometry or stack.
    Returns success, chain records, the union edge BitArray, an error message, and immutable analyzed topology.
    */
    function detectRedundantLoops node face_threshold:0.1 straight_threshold:2.0 debug_output:false =
    (
        loop_records = #()
        redundant_edges = #{}
        analysis_source = acquireAnalysisSource node

        if analysis_source == undefined then return #(false, loop_records, redundant_edges, "could not acquire evaluated Editable Poly topology", undefined)

        analysis_node = analysis_source[1]
        analysis_poly = analysis_source[2]
        topology_data = buildPolyTopology analysis_node analysis_poly

        if topology_data == undefined then
        (
            releaseAnalysisSource analysis_source
            return #(false, loop_records, redundant_edges, "could not read evaluated Editable Poly topology", undefined)
        )

        crease_edges = getCreaseEdges analysis_poly topology_data[2]
        candidate_edges = buildCandidateEdges topology_data crease_edges angle_threshold:face_threshold

        edge_count = topology_data[2]
        vertex_points = topology_data[4]
        vertex_edges = topology_data[5]
        vertex_faces = topology_data[6]
        edge_vertices = topology_data[7]
        edge_faces = topology_data[8]
        border_edges = topology_data[9]
        face_normals = topology_data[11]
        face_valid = topology_data[12]

        straight_limit = cos straight_threshold
        accepted_keys = #()
        attempted_keys = #()
        isolated_edges = #{}

        for divider_edge in candidate_edges do
        (
            if isValidIsolatedDivider divider_edge candidate_edges topology_data face_threshold:face_threshold then
            (
                divider_pair = edge_vertices[divider_edge]
                divider_bits = #{}
                divider_bits[divider_edge] = true
                divider_vertices = #(divider_pair[1], divider_pair[2])
                divider_key = makeChainKey divider_bits

                if findItem accepted_keys divider_key == 0 then
                (
                    append accepted_keys divider_key
                    append loop_records #(divider_bits, divider_vertices, divider_pair[1], divider_pair[2])
                    redundant_edges = redundant_edges + divider_bits
                    isolated_edges[divider_edge] = true

                    if debug_output then
                    (
                        vertex_bits = #{}
                        vertex_bits[divider_pair[1]] = true
                        vertex_bits[divider_pair[2]] = true
                        format "REDUNDANT DIVIDER | node:% | verts:% | edges:%\n" node.name vertex_bits divider_bits
                    )
                )
            )
        )

        traversal_candidates = candidate_edges - isolated_edges

        for start_edge in traversal_candidates do
        (
            start_pair = edge_vertices[start_edge]

            if start_pair != undefined then
            (
                single_chain = #{}
                single_chain[start_edge] = true
                possible_starts = #()

                if isValidTerminal start_pair[1] single_chain border_edges vertex_edges edge_vertices vertex_points angle_threshold:straight_threshold then append possible_starts start_pair[1]
                if isValidTerminal start_pair[2] single_chain border_edges vertex_edges edge_vertices vertex_points angle_threshold:straight_threshold then append possible_starts start_pair[2]

                for start_vertex in possible_starts do
                (
                    attempt_key = (start_edge as string) + ":" + (start_vertex as string)

                    if findItem attempted_keys attempt_key == 0 then
                    (
                        append attempted_keys attempt_key

                        chain_edges = #{}
                        chain_edges[start_edge] = true
                        chain_vertices = #(start_vertex)

                        previous_vertex = start_vertex
                        current_edge = start_edge
                        current_vertex = if start_pair[1] == start_vertex then start_pair[2] else start_pair[1]
                        append chain_vertices current_vertex

                        reference_normal = undefined
                        start_faces = edge_faces[start_edge]

                        if start_faces != undefined then
                        (
                            reference_face = if start_faces[1] > 0 then start_faces[1] else start_faces[2]

                            if reference_face >= 1 and reference_face <= face_normals.count then
                            (
                                if face_valid[reference_face] then reference_normal = face_normals[reference_face]
                            )
                        )

                        rejected_reason = ""
                        completed_chain = false
                        step_count = 0

                        if reference_normal == undefined then rejected_reason = "missing reference face normal"

                        while rejected_reason == "" and not completed_chain and step_count <= edge_count do
                        (
                            step_count += 1

                            if not(isVertexPlanar current_vertex vertex_faces face_normals face_valid reference_normal angle_threshold:face_threshold) then
                            (
                                rejected_reason = "non-planar incident faces at vertex " + (current_vertex as string)
                            )
                            else
                            (
                                incoming_direction = vertex_points[current_vertex] - vertex_points[previous_vertex]

                                if length incoming_direction <= 0.0000001 then
                                (
                                    rejected_reason = "zero-length chain segment"
                                )
                                else
                                (
                                    incoming_direction = normalize incoming_direction
                                    forward_edges = #()
                                    incident_candidates = vertex_edges[current_vertex] * traversal_candidates

                                    for candidate_edge in incident_candidates do
                                    (
                                        if candidate_edge != current_edge then
                                        (
                                            next_vertex = getOtherVertex current_vertex candidate_edge edge_vertices

                                            if next_vertex != undefined then
                                            (
                                                outgoing_direction = vertex_points[next_vertex] - vertex_points[current_vertex]

                                                if length outgoing_direction > 0.0000001 then
                                                (
                                                    outgoing_direction = normalize outgoing_direction
                                                    if dot incoming_direction outgoing_direction >= straight_limit then append forward_edges candidate_edge
                                                )
                                            )
                                        )
                                    )

                                    if forward_edges.count == 0 then
                                    (
                                        terminal_chain = #{}
                                        terminal_chain[current_edge] = true

                                        if isValidTerminal current_vertex terminal_chain border_edges vertex_edges edge_vertices vertex_points angle_threshold:straight_threshold then
                                        (
                                            completed_chain = true
                                        )
                                        else
                                        (
                                            rejected_reason = "chain stopped at invalid terminal vertex " + (current_vertex as string)
                                        )
                                    )
                                    else if forward_edges.count > 1 then
                                    (
                                        rejected_reason = "ambiguous forward branching at vertex " + (current_vertex as string)
                                    )
                                    else
                                    (
                                        next_edge = forward_edges[1]

                                        if chain_edges[next_edge] then
                                        (
                                            rejected_reason = "closed edge cycle"
                                        )
                                        else if not(isValidInternalVertex current_vertex current_edge next_edge border_edges vertex_edges edge_vertices vertex_points angle_threshold:straight_threshold) then
                                        (
                                            rejected_reason = "invalid internal branch topology at vertex " + (current_vertex as string)
                                        )
                                        else
                                        (
                                            next_vertex = getOtherVertex current_vertex next_edge edge_vertices

                                            if next_vertex == undefined then
                                            (
                                                rejected_reason = "invalid continuation edge"
                                            )
                                            else if findItem chain_vertices next_vertex != 0 then
                                            (
                                                rejected_reason = "closed or revisited vertex cycle"
                                            )
                                            else
                                            (
                                                chain_edges[next_edge] = true
                                                previous_vertex = current_vertex
                                                current_vertex = next_vertex
                                                current_edge = next_edge
                                                append chain_vertices current_vertex
                                            )
                                        )
                                    )
                                )
                            )
                        )

                        if step_count > edge_count then rejected_reason = "traversal exceeded edge count"

                        if rejected_reason == "" and completed_chain then
                        (
                            validation = validateChain chain_edges chain_vertices start_vertex current_vertex traversal_candidates topology_data reference_normal face_threshold:face_threshold straight_threshold:straight_threshold

                            if validation[1] then
                            (
                                chain_key = makeChainKey chain_edges

                                if findItem accepted_keys chain_key == 0 then
                                (
                                    append accepted_keys chain_key
                                    append loop_records #(chain_edges, chain_vertices, start_vertex, current_vertex)
                                    redundant_edges = redundant_edges + chain_edges

                                    if debug_output then
                                    (
                                        vertex_bits = #{}
                                        for vertex_index in chain_vertices do vertex_bits[vertex_index] = true
                                        format "REDUNDANT CHAIN | node:% | verts:% | edges:% | terminal:% -> %\n" node.name vertex_bits chain_edges start_vertex current_vertex
                                    )
                                )
                            )
                            else
                            (
                                rejected_reason = validation[2]
                            )
                        )

                        if debug_output and rejected_reason != "" then
                        (
                            format "Rejected candidate | node:% | startEdge:% | startVert:% | reason:%\n" node.name start_edge start_vertex rejected_reason
                        )
                    )
                )
            )
        )

        releaseAnalysisSource analysis_source
        #(true, loop_records, redundant_edges, "", topology_data)
        -- return
    ),

    /*
    Returns the unique polygon edge directly connecting two topology vertices.
    Ambiguous or missing connections return zero.
    */
    function findDirectTopologyEdge vertex_a vertex_b vertex_edges =
    (
        if vertex_a < 1 or vertex_b < 1 then return 0
        if vertex_a > vertex_edges.count or vertex_b > vertex_edges.count then return 0

        common_edges = vertex_edges[vertex_a] * vertex_edges[vertex_b]
        if common_edges.numberSet != 1 then return 0

        (common_edges as array)[1]
        -- return
    ),

    /*
    Tests whether four vertices define exactly one quad face in the analyzed polygon topology.
    This keeps ring detection on real polygon faces rather than hidden triangulation edges.
    */
    function findQuadFaceByVertices vertex_a vertex_b vertex_c vertex_d vertex_faces face_vertices_list =
    (
        common_faces = copy vertex_faces[vertex_a]
        common_faces = common_faces * vertex_faces[vertex_b]
        common_faces = common_faces * vertex_faces[vertex_c]
        common_faces = common_faces * vertex_faces[vertex_d]

        matched_faces = #()

        for face_index in common_faces do
        (
            face_vertices = face_vertices_list[face_index]

            if face_vertices != undefined and face_vertices.count == 4 then
            (
                has_all = findItem face_vertices vertex_a != 0 and findItem face_vertices vertex_b != 0 and findItem face_vertices vertex_c != 0 and findItem face_vertices vertex_d != 0
                if has_all then append matched_faces face_index
            )
        )

        if matched_faces.count == 1 then matched_faces[1] else 0
        -- return
    ),

    /*
    Validates one correspondence direction between two redundant loops.
    A valid pair is connected by one clean parallel edge at every loop vertex and every strip cell is a quad.
    */
    function testLoopPairMapping loop_a loop_b topology_data reverse_b:false straight_threshold:2.0 =
    (
        loop_edges_a = loop_a[1]
        loop_vertices_a = loop_a[2]
        loop_edges_b = loop_b[1]
        loop_vertices_b = loop_b[2]

        if loop_vertices_a.count < 2 or loop_vertices_b.count < 2 then return #(false, #{}, #{}, #{}, "loop has fewer than two vertices")
        if loop_vertices_a.count != loop_vertices_b.count then return #(false, #{}, #{}, #{}, "loop vertex counts differ")
        if (loop_edges_a * loop_edges_b).numberSet > 0 then return #(false, #{}, #{}, #{}, "loops share edges")

        for vertex_index in loop_vertices_a do
        (
            if findItem loop_vertices_b vertex_index != 0 then return #(false, #{}, #{}, #{}, "loops share vertices")
        )

        vertex_points = topology_data[4]
        vertex_edges = topology_data[5]
        vertex_faces = topology_data[6]
        edge_vertices = topology_data[7]
        face_vertices_list = topology_data[13]
        straight_limit = cos straight_threshold
        vertex_count = loop_vertices_a.count

        direction_a = vertex_points[loop_vertices_a[vertex_count]] - vertex_points[loop_vertices_a[1]]
        direction_b = vertex_points[loop_vertices_b[vertex_count]] - vertex_points[loop_vertices_b[1]]

        if length direction_a <= 0.0000001 or length direction_b <= 0.0000001 then return #(false, #{}, #{}, #{}, "zero-length loop direction")

        direction_a = normalize direction_a
        direction_b = normalize direction_b
        if abs(dot direction_a direction_b) < straight_limit then return #(false, #{}, #{}, #{}, "loops are not parallel")

        ring_edges = #{}
        ring_vertices = #{}
        strip_faces = #{}
        first_connector_direction = undefined

        for vertex_position = 1 to vertex_count do
        (
            vertex_a = loop_vertices_a[vertex_position]
            mapped_position = if reverse_b then (vertex_count - vertex_position + 1) else vertex_position
            vertex_b = loop_vertices_b[mapped_position]
            connector_edge = findDirectTopologyEdge vertex_a vertex_b vertex_edges

            if connector_edge == 0 then return #(false, #{}, #{}, #{}, "missing or ambiguous connector edge")
            if loop_edges_a[connector_edge] or loop_edges_b[connector_edge] then return #(false, #{}, #{}, #{}, "connector belongs to a redundant loop")

            connector_direction = vertex_points[vertex_b] - vertex_points[vertex_a]
            if length connector_direction <= coincidence_tolerance then return #(false, #{}, #{}, #{}, "zero-length connector edge")
            connector_direction = normalize connector_direction

            if first_connector_direction == undefined then
            (
                first_connector_direction = connector_direction
            )
            else if dot first_connector_direction connector_direction < straight_limit then
            (
                return #(false, #{}, #{}, #{}, "connector edges are not parallel")
            )

            ring_edges[connector_edge] = true
            ring_vertices[vertex_a] = true
            ring_vertices[vertex_b] = true
        )

        if ring_edges.numberSet != vertex_count then return #(false, #{}, #{}, #{}, "connector edges are not unique")

        for segment_index = 1 to (vertex_count - 1) do
        (
            a_1 = loop_vertices_a[segment_index]
            a_2 = loop_vertices_a[segment_index + 1]
            b_position_1 = if reverse_b then (vertex_count - segment_index + 1) else segment_index
            b_position_2 = if reverse_b then (vertex_count - segment_index) else (segment_index + 1)
            b_1 = loop_vertices_b[b_position_1]
            b_2 = loop_vertices_b[b_position_2]

            edge_a = findDirectTopologyEdge a_1 a_2 vertex_edges
            edge_b = findDirectTopologyEdge b_1 b_2 vertex_edges

            if edge_a == 0 or not loop_edges_a[edge_a] then return #(false, #{}, #{}, #{}, "first loop order does not match topology")
            if edge_b == 0 or not loop_edges_b[edge_b] then return #(false, #{}, #{}, #{}, "second loop order does not match topology")

            strip_face = findQuadFaceByVertices a_1 a_2 b_1 b_2 vertex_faces face_vertices_list
            if strip_face == 0 then return #(false, #{}, #{}, #{}, "strip between loops is not a continuous quad strip")
            strip_faces[strip_face] = true
        )

        #(true, ring_edges, ring_vertices, strip_faces, if reverse_b then #reverse else #forward)
        -- return
    ),

    /*
    Finds a collapsible edge ring between one pair of redundant loops.
    Both correspondence directions are tested; exactly one valid mapping is required.
    */
    function buildRingBetweenLoops loop_a loop_b topology_data straight_threshold:2.0 =
    (
        forward_result = testLoopPairMapping loop_a loop_b topology_data reverse_b:false straight_threshold:straight_threshold
        reverse_result = testLoopPairMapping loop_a loop_b topology_data reverse_b:true straight_threshold:straight_threshold
        valid_count = 0
        accepted_result = undefined

        if forward_result[1] then
        (
            valid_count += 1
            accepted_result = forward_result
        )

        if reverse_result[1] then
        (
            valid_count += 1
            accepted_result = reverse_result
        )

        if valid_count != 1 then return #(false, #{}, #{}, #{}, if valid_count == 0 then "no valid quad-strip mapping" else "ambiguous loop correspondence")

        accepted_result
        -- return
    ),

    /*
    Detects edge rings bounded by exactly paired redundant loops without modifying the scene.
    A redundant loop that can pair with more than one neighbor is rejected as ambiguous.
    */
    function detectRedundantRings node face_threshold:0.1 straight_threshold:2.0 debug_output:false =
    (
        loop_detection = detectRedundantLoops node face_threshold:face_threshold straight_threshold:straight_threshold debug_output:false
        ring_records = #()
        ring_edges = #{}

        if not loop_detection[1] then return #(false, ring_records, ring_edges, loop_detection[4], loop_detection[5])

        loop_records = loop_detection[2]
        topology_data = loop_detection[5]
        if loop_records.count < 2 then return #(true, ring_records, ring_edges, "", topology_data)

        candidate_pairs = #()
        loop_pair_counts = for loop_index = 1 to loop_records.count collect 0

        for loop_a_index = 1 to (loop_records.count - 1) do
        (
            for loop_b_index = (loop_a_index + 1) to loop_records.count do
            (
                pair_result = buildRingBetweenLoops loop_records[loop_a_index] loop_records[loop_b_index] topology_data straight_threshold:straight_threshold

                if pair_result[1] then
                (
                    append candidate_pairs #(loop_a_index, loop_b_index, pair_result[2], pair_result[3], pair_result[4], pair_result[5])
                    loop_pair_counts[loop_a_index] += 1
                    loop_pair_counts[loop_b_index] += 1
                )
            )
        )

        for pair_record in candidate_pairs do
        (
            loop_a_index = pair_record[1]
            loop_b_index = pair_record[2]

            if loop_pair_counts[loop_a_index] == 1 and loop_pair_counts[loop_b_index] == 1 then
            (
                append ring_records pair_record
                ring_edges = ring_edges + pair_record[3]

                if debug_output then
                (
                    format "REDUNDANT RING | node:% | loops:%-% | edges:% | stripFaces:% | mapping:%\n" node.name loop_a_index loop_b_index pair_record[3] pair_record[5] pair_record[6]
                )
            )
            else if debug_output then
            (
                format "Rejected ring pair | node:% | loops:%-% | reason:ambiguous redundant-loop neighbor\n" node.name loop_a_index loop_b_index
            )
        )

        #(true, ring_records, ring_edges, "", topology_data)
        -- return
    ),

    /*
    Returns the currently selected edge IDs from the active Editable Poly or Edit Poly object.
    The selection source is never inferred from a debug spinner.
    */
    function getCurrentSelectedEdges node =
    (
        selected_edges = #{}
        if node == undefined or not(isValidNode node) then return selected_edges

        current_object = undefined
        try(current_object = modPanel.getCurrentObject())catch()

        if current_object != undefined and classOf current_object == Edit_Poly then
        (
            current_on_node = false

            for modifier_index = 1 to node.modifiers.count while not current_on_node do
            (
                if node.modifiers[modifier_index] == current_object then current_on_node = true
            )

            if current_on_node then
            (
                forceSelectModeZero current_object
                try(selected_edges = current_object.GetSelection #Edge node:node)catch()
            )
        )

        if selected_edges.numberSet == 0 and node.modifiers.count > 0 then
        (
            top_modifier = node.modifiers[1]

            if classOf top_modifier == Edit_Poly then
            (
                forceSelectModeZero top_modifier
                try(selected_edges = top_modifier.GetSelection #Edge node:node)catch()
            )
        )

        if selected_edges.numberSet == 0 and classOf node.baseObject == Editable_Poly then
        (
            forceSelectModeZero node.baseObject
            try(selected_edges = polyop.getEdgeSelection node.baseObject)catch()
        )

        selected_edges
        -- return
    ),

    /*
    Prints detailed classification for one analyzed edge ID without changing the object.
    The UI calls this for every currently selected edge on the active object.
    */
    function debugEdge node edge_index face_threshold:0.1 straight_threshold:2.0 =
    (
        analysis_source = acquireAnalysisSource node
        if analysis_source == undefined then return false

        analysis_node = analysis_source[1]
        analysis_poly = analysis_source[2]
        topology_data = buildPolyTopology analysis_node analysis_poly

        if topology_data == undefined then
        (
            releaseAnalysisSource analysis_source
            return false
        )

        crease_edges = getCreaseEdges analysis_poly topology_data[2]
        candidate_edges = buildCandidateEdges topology_data crease_edges angle_threshold:face_threshold

        if edge_index < 1 or edge_index > topology_data[2] then
        (
            format "DEBUG EDGE % | invalid edge ID, edgeCount:%\n" edge_index topology_data[2]
            releaseAnalysisSource analysis_source
            return false
        )

        edge_pair = topology_data[7][edge_index]
        face_pair = topology_data[8][edge_index]
        border_edges = topology_data[9]
        vertex_edges = topology_data[5]
        vertex_points = topology_data[4]

        isolated_ok = isValidIsolatedDivider edge_index candidate_edges topology_data face_threshold:face_threshold
        format "DEBUG EDGE % | verts:% | faces:% | candidate:% | isolatedDivider:% | border:% | crease:%\n" edge_index edge_pair face_pair candidate_edges[edge_index] isolated_ok border_edges[edge_index] crease_edges[edge_index]

        if edge_pair != undefined then
        (
            chain_set = #{}
            chain_set[edge_index] = true

            for vertex_index in edge_pair do
            (
                effective_edges = getEffectiveIncidentEdges vertex_index chain_set vertex_edges topology_data[7] vertex_points
                raw_border = vertex_edges[vertex_index] * border_edges
                effective_border = effective_edges * border_edges
                terminal_ok = isValidTerminal vertex_index chain_set border_edges vertex_edges topology_data[7] vertex_points angle_threshold:straight_threshold

                format "  V% | rawEdges:% | effective:% | rawBorder:% | effectiveBorder:% | terminal:%\n" vertex_index vertex_edges[vertex_index] effective_edges raw_border effective_border terminal_ok
            )
        )

        releaseAnalysisSource analysis_source
        true
        -- return
    ),

    /*
    Debugs every currently selected edge on one object.
    No explicit edge ID input is required.
    */
    function debugSelectedEdges node face_threshold:0.1 straight_threshold:2.0 =
    (
        selected_edges = getCurrentSelectedEdges node

        if selected_edges.numberSet == 0 then
        (
            messageBox "Select one or more edges first." title:"Redundant Ring Collapser"
            return false
        )

        debug_ok = true

        for edge_index in selected_edges do
        (
            if not(debugEdge node edge_index face_threshold:face_threshold straight_threshold:straight_threshold) then debug_ok = false
        )

        debug_ok
        -- return
    ),

    /*
    Returns the existing exact top selection modifier or creates one.
    Unrelated Edit Poly modifiers are never used for selection storage.
    */
    function acquireSelectionModifier node =
    (
        if node.modifiers.count > 0 then
        (
            top_modifier = node.modifiers[1]

            if classOf top_modifier == Edit_Poly and top_modifier.name == "SELECT REDUNDANT RINGS" then
            (
                return #(top_modifier, false)
            )
        )

        selection_modifier = Edit_Poly name:"SELECT REDUNDANT RINGS"
        addModifier node selection_modifier
        #(selection_modifier, true)
        -- return
    ),

    /*
    Returns the dedicated redundant-loop selection modifier from one node.
    Unrelated Edit Poly modifiers are ignored.
    */
    function findLoopSelectionModifier node =
    (
        if node == undefined or not(isValidNode node) then return undefined

        selection_modifier = undefined

        for modifier_index = 1 to node.modifiers.count while selection_modifier == undefined do
        (
            current_modifier = node.modifiers[modifier_index]

            if classOf current_modifier == Edit_Poly and current_modifier.name == "SELECT REDUNDANT LOOPS" then
            (
                selection_modifier = current_modifier
            )
        )

        selection_modifier
        -- return
    ),

    /*
    Returns the existing redundant-loop selector or creates one at the top of the stack.
    The caller receives the modifier and whether it was created by this call.
    */
    function acquireLoopSelectionModifier node =
    (
        selection_modifier = findLoopSelectionModifier node

        if selection_modifier != undefined then
        (
            return #(selection_modifier, false)
        )

        selection_modifier = Edit_Poly name:"SELECT REDUNDANT LOOPS"
        addModifier node selection_modifier
        #(selection_modifier, true)
        -- return
    ),

    /*
    Activates the dedicated selection modifier in Edge mode with Show Cage disabled.
    Geometry detection has already finished before this function runs.
    */
    function activateSelectionModifier node selection_modifier =
    (
        if node == undefined or not(isValidNode node) then return false
        if selection_modifier == undefined or classOf selection_modifier != Edit_Poly then return false

        activated = true

        try
        (
            select node
            max modify mode
            if classOf node.baseObject == Editable_Poly then forceSelectModeZero node.baseObject
            forceSelectModeZero selection_modifier
            selection_modifier.SetPrimaryNode node
            selection_modifier.useStackSelection = false
            selection_modifier.showCage = false
            selection_modifier.selectMode = 0
            modPanel.setCurrentObject selection_modifier
            selection_modifier.SetEPolySelLevel #Edge
            subObjectLevel = 2
            update node
        )
        catch
        (
            activated = false
        )

        activated
        -- return
    ),

    /*
    Verifies that evaluated edge IDs still describe the same geometry after the selection modifier is added.
    Verification uses a disposable collapsed copy and compares every edge endpoint pair in world space.
    */
    function verifyEdgeIdMapping node source_topology =
    (
        verification_source = acquireAnalysisSource node
        if verification_source == undefined then return false

        verification_topology = buildPolyTopology verification_source[1] verification_source[2]
        mapping_ok = verification_topology != undefined

        if mapping_ok then mapping_ok = verification_topology[1] == source_topology[1] and verification_topology[2] == source_topology[2] and verification_topology[3] == source_topology[3]

        if mapping_ok then
        (
            source_points = source_topology[4]
            source_edges = source_topology[7]
            current_points = verification_topology[4]
            current_edges = verification_topology[7]

            for edge_index = 1 to source_topology[2] while mapping_ok do
            (
                source_pair = source_edges[edge_index]
                current_pair = current_edges[edge_index]

                if source_pair == undefined or current_pair == undefined then
                (
                    mapping_ok = source_pair == undefined and current_pair == undefined
                )
                else
                (
                    source_a = source_points[source_pair[1]]
                    source_b = source_points[source_pair[2]]
                    current_a = current_points[current_pair[1]]
                    current_b = current_points[current_pair[2]]

                    same_forward = distance source_a current_a <= coincidence_tolerance and distance source_b current_b <= coincidence_tolerance
                    same_reverse = distance source_a current_b <= coincidence_tolerance and distance source_b current_a <= coincidence_tolerance

                    if not same_forward and not same_reverse then mapping_ok = false
                )
            )
        )

        releaseAnalysisSource verification_source
        mapping_ok
        -- return
    ),

    /*
    Detects one object and stores collapsible ring edges in the dedicated Edit Poly modifier.
    Zero matches leave no SELECT REDUNDANT RINGS modifier behind.
    */
    function selectRedundantRingsOnNode node face_threshold:0.1 straight_threshold:2.0 debug_output:true =
    (
        if node == undefined or not(isValidNode node) then return #(false, 0, 0, "invalid node", undefined)

        detection = detectRedundantRings node face_threshold:face_threshold straight_threshold:straight_threshold debug_output:debug_output
        if not detection[1] then return #(false, 0, 0, detection[4], undefined)

        ring_count = detection[2].count
        selected_edges = detection[3]
        topology_data = detection[5]
        selected_edge_count = selected_edges.numberSet
        selection_modifier = undefined
        created_now = false
        operation_error = undefined

        try
        (
            if selected_edge_count > 0 then
            (
                modifier_data = acquireSelectionModifier node
                selection_modifier = modifier_data[1]
                created_now = modifier_data[2]

                if not(activateSelectionModifier node selection_modifier) then throw "could not activate SELECT REDUNDANT RINGS"
                forceSelectModeZero selection_modifier
                if classOf node.baseObject == Editable_Poly then forceSelectModeZero node.baseObject
                if not(verifyEdgeIdMapping node topology_data) then throw "evaluated edge IDs changed before ring selection storage"

                selection_bits = copy selected_edges
                selection_bits.count = topology_data[2]
                empty_selection = #{}
                empty_selection.count = topology_data[2]

                clear_ok = selection_modifier.SetSelection #Edge empty_selection node:node
                store_ok = selection_modifier.SetSelection #Edge selection_bits node:node
                update node
                selection_modifier.RefreshScreen()
                stored_selection = selection_modifier.GetSelection #Edge node:node

                if not clear_ok then throw "could not clear Edit Poly edge selection before ring storage"
                if not store_ok then throw "Edit Poly SetSelection returned false while storing redundant ring edges"

                stored_bits = copy stored_selection
                stored_bits.count = topology_data[2]
                if stored_bits != selection_bits then throw ("ring selection storage mismatch. requested:" + (selected_edges as string) + " actual:" + (stored_selection as string))

                selection_modifier.showCage = false
                if not(activateSelectionModifier node selection_modifier) then throw "could not enter Edge sub-object level after ring selection storage"
            )
            else
            (
                if node.modifiers.count > 0 then
                (
                    top_modifier = node.modifiers[1]
                    if classOf top_modifier == Edit_Poly and top_modifier.name == "SELECT REDUNDANT RINGS" then deleteModifier node top_modifier
                )
                update node
            )
        )
        catch
        (
            operation_error = getCurrentException()

            if selection_modifier != undefined then
            (
                if created_now or selection_modifier.name == "SELECT REDUNDANT RINGS" then try(deleteModifier node selection_modifier)catch()
                selection_modifier = undefined
            )
            update node
        )

        if operation_error == undefined then #(true, ring_count, selected_edge_count, "", selection_modifier) else #(false, 0, 0, operation_error as string, undefined)
        -- return
    ),

    /*
    Processes selected objects independently and finishes with only objects containing redundant rings selected.
    */
    function selectRedundantRings face_threshold:0.1 straight_threshold:2.0 debug_output:true =
    (
        selected_nodes = selection as array

        if selected_nodes.count == 0 then
        (
            messageBox "Select at least one geometry object." title:"Redundant Ring Collapser"
            return #(false, 0, 0)
        )

        total_rings = 0
        total_edges = 0
        failed_count = 0
        matching_nodes = #()
        first_match_node = undefined
        first_match_modifier = undefined

        for node in selected_nodes do
        (
            result_data = selectRedundantRingsOnNode node face_threshold:face_threshold straight_threshold:straight_threshold debug_output:debug_output

            if result_data[1] then
            (
                total_rings += result_data[2]
                total_edges += result_data[3]

                if result_data[3] > 0 then
                (
                    append matching_nodes node
                    if first_match_modifier == undefined then
                    (
                        first_match_node = node
                        first_match_modifier = result_data[5]
                    )
                )
            )
            else
            (
                failed_count += 1
                format "Redundant Ring Collapser FAILED | node:% | %\n" node.name result_data[4]
            )
        )

        if matching_nodes.count > 0 then
        (
            select matching_nodes

            if matching_nodes.count == 1 and first_match_modifier != undefined then
            (
                activateSelectionModifier first_match_node first_match_modifier
                first_match_modifier.RefreshScreen()
            )
        )
        else
        (
            select selected_nodes
        )

        completeRedraw()
        format "Redundant Ring Collapser COMPLETE | objects:% | rings:% | edges:% | failures:%\n" selected_nodes.count total_rings total_edges failed_count
        #(failed_count == 0, total_rings, total_edges)
        -- return
    ),

    /*
    Stores the currently detected redundant loops in SELECT REDUNDANT LOOPS.
    Existing selector data is preserved when storage fails or no new loops are found.
    */
    function storeRedundantLoopsForRemovalOnNode node face_threshold:0.1 straight_threshold:2.0 =
    (
        if node == undefined or not(isValidNode node) then return #(false, 0, undefined, "invalid node")

        detection = detectRedundantLoops node face_threshold:face_threshold straight_threshold:straight_threshold debug_output:false
        if not detection[1] then return #(false, 0, undefined, detection[4])

        selected_edges = detection[3]
        topology_data = detection[5]
        selected_edge_count = selected_edges.numberSet

        if selected_edge_count == 0 then return #(true, 0, findLoopSelectionModifier node, "")

        modifier_data = acquireLoopSelectionModifier node
        selection_modifier = modifier_data[1]
        created_now = modifier_data[2]
        previous_selection = #{}
        operation_error = undefined

        if not created_now then
        (
            try(previous_selection = copy (selection_modifier.GetSelection #Edge node:node))catch()
        )

        try
        (
            if not(activateSelectionModifier node selection_modifier) then throw "could not activate SELECT REDUNDANT LOOPS"
            if not(verifyEdgeIdMapping node topology_data) then throw "evaluated edge IDs changed before redundant-loop selection storage"

            selection_bits = copy selected_edges
            selection_bits.count = topology_data[2]
            empty_selection = #{}
            empty_selection.count = topology_data[2]

            clear_ok = selection_modifier.SetSelection #Edge empty_selection node:node
            store_ok = selection_modifier.SetSelection #Edge selection_bits node:node
            update node
            selection_modifier.RefreshScreen()

            if not clear_ok then throw "could not clear Edit Poly edge selection before redundant-loop storage"
            if not store_ok then throw "Edit Poly SetSelection returned false while storing redundant-loop edges"

            stored_selection = copy (selection_modifier.GetSelection #Edge node:node)
            stored_selection.count = topology_data[2]

            if stored_selection != selection_bits then
            (
                throw ("redundant-loop selection storage mismatch. requested:" + (selected_edges as string) + " actual:" + (stored_selection as string))
            )

            selection_modifier.showCage = false
        )
        catch
        (
            operation_error = getCurrentException()

            if created_now then
            (
                try(deleteModifier node selection_modifier)catch()
                selection_modifier = undefined
            )
            else if selection_modifier != undefined then
            (
                try(selection_modifier.SetSelection #Edge previous_selection node:node)catch()
                try(selection_modifier.showCage = false)catch()
            )

            update node
        )

        if operation_error == undefined then
        (
            #(true, selected_edge_count, selection_modifier, "")
        )
        else
        (
            #(false, 0, undefined, operation_error as string)
        )
        -- return
    ),

    /*
    Removes redundant-loop edges and their vertices through SELECT REDUNDANT LOOPS.
    RMB uses the native Edit Poly Remove Edge And Vertices operation exactly.
    */
    function removeSelectedLoops face_threshold:0.1 straight_threshold:2.0 =
    (
        selected_nodes = selection as array

        if selected_nodes.count == 0 then
        (
            messageBox "Select at least one geometry object." title:"Redundant Ring Collapser"
            return false
        )

        removed_nodes = #()
        total_edges = 0
        failed_count = 0

        for node in selected_nodes do
        (
            selection_modifier = findLoopSelectionModifier node

            if selection_modifier == undefined then
            (
                detection_result = storeRedundantLoopsForRemovalOnNode node face_threshold:face_threshold straight_threshold:straight_threshold

                if detection_result[1] and detection_result[2] > 0 then
                (
                    selection_modifier = detection_result[3]
                )
                else if not detection_result[1] then
                (
                    failed_count += 1
                    format "Redundant Ring Collapser REMOVE DETECTION FAILED | node:% | %\n" node.name detection_result[4]
                )
            )

            if selection_modifier != undefined then
            (
                operation_error = undefined

                try
                (
                    if not(activateSelectionModifier node selection_modifier) then throw "could not activate SELECT REDUNDANT LOOPS"

                    selected_loop_edges = copy (selection_modifier.GetSelection #Edge node:node)
                    if selected_loop_edges.numberSet == 0 then throw "SELECT REDUNDANT LOOPS contains no selected edges"
                    edge_count_before = selected_loop_edges.numberSet

                    undo "Remove Redundant Loops" on
                    (
                        selection_modifier.SetEPolySelLevel #Edge
                        subObjectLevel = 2
                        modPanel.setCurrentObject selection_modifier node:node

                        selection_modifier.ButtonOp #RemoveEdgeRemoveVertices
                        update node

                        selection_modifier.showCage = false
                        selection_modifier.name = "DELETED REDUNDANT LOOPS"
                        selection_modifier.RefreshScreen()
                    )

                    total_edges += edge_count_before
                    append removed_nodes node
                )
                catch
                (
                    operation_error = getCurrentException()
                )

                if operation_error != undefined then
                (
                    failed_count += 1
                    format "Redundant Ring Collapser REMOVE FAILED | node:% | %\n" node.name operation_error
                )
            )
        )

        if removed_nodes.count > 0 then select removed_nodes else select selected_nodes
        completeRedraw()

        format "Redundant Ring Collapser REMOVE | objects:% | removedEdges:% | failures:%\n" removed_nodes.count total_edges failed_count
        removed_nodes.count > 0 and failed_count == 0
        -- return
    ),

    /*
    Collapses the ring edges stored by SELECT REDUNDANT RINGS on every selected matching object.
    If the selection modifier is missing, detection runs first for that object.
    */
    function collapseSelectedRings face_threshold:0.1 straight_threshold:2.0 =
    (
        selected_nodes = selection as array

        if selected_nodes.count == 0 then
        (
            messageBox "Select at least one geometry object." title:"Redundant Ring Collapser"
            return false
        )

        collapsed_nodes = #()
        total_edges = 0
        failed_count = 0

        for node in selected_nodes do
        (
            selection_modifier = undefined

            if node.modifiers.count > 0 then
            (
                top_modifier = node.modifiers[1]
                if classOf top_modifier == Edit_Poly and top_modifier.name == "SELECT REDUNDANT RINGS" then selection_modifier = top_modifier
            )

            if selection_modifier == undefined then
            (
                detection_result = selectRedundantRingsOnNode node face_threshold:face_threshold straight_threshold:straight_threshold debug_output:false
                if detection_result[1] and detection_result[3] > 0 then selection_modifier = detection_result[5]
            )

            if selection_modifier != undefined then
            (
                operation_error = undefined

                try
                (
                    if not(activateSelectionModifier node selection_modifier) then throw "could not activate SELECT REDUNDANT RINGS"
                    forceSelectModeZero selection_modifier
                    if classOf node.baseObject == Editable_Poly then forceSelectModeZero node.baseObject

                    selected_ring_edges = selection_modifier.GetSelection #Edge node:node
                    if selected_ring_edges.numberSet == 0 then throw "SELECT REDUNDANT RINGS contains no selected edges"
                    edge_count_before = selected_ring_edges.numberSet

                    undo "Collapse Redundant Rings" on
                    (
                        selection_modifier.SetEPolySelLevel #Edge
                        subObjectLevel = 2
                        selection_modifier.ButtonOp #CollapseEdge
                        update node
                        selection_modifier.showCage = false
                        selection_modifier.name = "DELETED REDUNDANT RINGS"
                        selection_modifier.RefreshScreen()
                    )

                    total_edges += edge_count_before
                    append collapsed_nodes node
                )
                catch
                (
                    operation_error = getCurrentException()
                )

                if operation_error != undefined then
                (
                    failed_count += 1
                    format "Redundant Ring Collapser COLLAPSE FAILED | node:% | %\n" node.name operation_error
                )
            )
        )

        if collapsed_nodes.count > 0 then select collapsed_nodes else select selected_nodes
        completeRedraw()
        format "Redundant Ring Collapser COLLAPSE | objects:% | collapsedEdges:% | failures:%\n" collapsed_nodes.count total_edges failed_count
        collapsed_nodes.count > 0 and failed_count == 0
        -- return
    ),

    /*
    Creates a planar quad grid with exactly two adjacent internal redundant loops.
    The expected collapsible ring contains one connector edge for each grid row vertex.
    */
    function createRingTestObject x_offset:0.0 =
    (
        test_node = plane name:(uniqueName "REDUNDANT_RING_TEST_") width:30.0 length:20.0 widthsegs:3 lengthsegs:2
        test_node.position = [x_offset, 0.0, 0.0]
        convertTo test_node Editable_Poly
        forceSelectModeZero test_node.baseObject
        update test_node
        test_node
        -- return
    ),

    /*
    Runs standalone regression tests for one valid redundant ring and one no-pair topology.
    */
    function runRingTests =
    (
        test_passed = true
        valid_test = undefined
        no_pair_test = undefined

        try
        (
            valid_test = createRingTestObject x_offset:0.0
            valid_result = selectRedundantRingsOnNode valid_test face_threshold:0.1 straight_threshold:2.0 debug_output:true
            valid_ok = valid_result[1] and valid_result[2] == 1 and valid_result[3] == 3
            format "TEST redundant ring selected: % | rings:% | edges:% | error:%\n" valid_ok valid_result[2] valid_result[3] valid_result[4]
            if not valid_ok then test_passed = false

            no_pair_test = plane name:(uniqueName "REDUNDANT_RING_NO_PAIR_") width:20.0 length:20.0 widthsegs:2 lengthsegs:2
            no_pair_test.position = [50.0, 0.0, 0.0]
            convertTo no_pair_test Editable_Poly
            forceSelectModeZero no_pair_test.baseObject
            update no_pair_test

            no_pair_result = selectRedundantRingsOnNode no_pair_test face_threshold:0.1 straight_threshold:2.0 debug_output:true
            no_pair_ok = no_pair_result[1] and no_pair_result[2] == 0 and no_pair_result[3] == 0
            format "TEST unmatched redundant loops rejected: % | rings:% | edges:% | error:%\n" no_pair_ok no_pair_result[2] no_pair_result[3] no_pair_result[4]
            if not no_pair_ok then test_passed = false
        )
        catch
        (
            format "RING TEST ERROR: %\n" (getCurrentException())
            test_passed = false
        )

        if valid_test != undefined then try(delete valid_test)catch()
        if no_pair_test != undefined then try(delete no_pair_test)catch()

        format "REDUNDANT LOOP COLLAPSER TESTS PASSED: %\n" test_passed
        test_passed
        -- return
    ),

    /*
    Creates the valid redundant-ring test grid for manual viewport inspection.
    */
    function createManualRingTestObject =
    (
        test_node = createRingTestObject x_offset:0.0
        select test_node
        completeRedraw()
        test_node
        -- return
    ),

    /*
    Opens the standalone tool dialog.
    Embedded and library loads can call this explicitly when UI is desired.
    */
    function showUI =
    (
        this.hideUI()
        createDialog RedundantRingCollapser_Test_UI
        windows.processPostedMessages()
        true
        -- return
    ),

    /*
    Closes the standalone tool dialog without changing the public API instance.
    */
    function hideUI =
    (
        try(destroyDialog RedundantRingCollapser_Test_UI)catch()
        true
        -- return
    ),

    on create do
    (
    )
)

RedundantRingCollapser = RedundantRingCollapser_v()
RedundantRingCollapser.registerProjectVersion()
RedundantRingCollapser_Title = "Redundant Ring Collapser | v" + (epoly_tools_project_version as string)

rollout RedundantRingCollapser_Test_UI RedundantRingCollapser_Title width:286 height:144
(
    dotNetControl btn_tool_title "System.Windows.Forms.Button" pos:[12,12] width:262 height:18
    label lbl_info "Face plane: 0.1 deg    Straight: 2.0 deg" pos:[12,42] width:260 height:18 align:#left
    button btn_detect "DETECT RINGS \\ REMOVE LOOPS" pos:[12,66] width:262 height:30 tooltip:"LMB: Detect edge rings between uniquely paired redundant loops and select them.\n\nRMB: Remove redundant-loop edges and their vertices through SELECT REDUNDANT LOOPS."
    button btn_create "CREATE TEST MESH" pos:[12,108] width:126 height:24 tooltip:"Create a planar quad grid containing one valid redundant ring."
    button btn_tests "RUN TESTS" pos:[148,108] width:126 height:24 tooltip:"Run valid-ring and ambiguous/no-pair regression tests."

    on RedundantRingCollapser_Test_UI open do
    (
        ToolTitleButton.setupToolTitleButton btn_tool_title "Redundant Ring Collapser"
        ToolTitleButton.resizeToolTitleButton btn_tool_title (RedundantRingCollapser_Test_UI.width - 24)
        btn_tool_title.height = 18
    )

    on RedundantRingCollapser_Test_UI resized dialog_size do
    (
        ToolTitleButton.resizeToolTitleButton btn_tool_title (dialog_size.x - 24)
        btn_tool_title.height = 18
    )

    on btn_tool_title Click sender event_args do
    (
        restartTool RedundantRingCollapser_Source_File "Redundant-Ring-Collapser"
    )

    on btn_detect pressed do
    (
        RedundantRingCollapser.selectRedundantRings face_threshold:0.1 straight_threshold:2.0 debug_output:true
    )

    on btn_detect rightclick do
    (
        RedundantRingCollapser.removeSelectedLoops face_threshold:0.1 straight_threshold:2.0
    )

    on btn_create pressed do
    (
        RedundantRingCollapser.createManualRingTestObject()
    )

    on btn_tests pressed do
    (
        RedundantRingCollapser.runRingTests()
    )
)

if EPolyToolsIntegration != undefined then
(
    EPolyToolsIntegration.registerTool "redundant-ring-collapser" "Redundant Ring Collapser" RedundantRingCollapser RedundantRingCollapser_Test_UI RedundantRingCollapser.file_version RedundantRingCollapser.project_version (getSourceFileName()) capabilities:#(#detect, #selection, #collapse, #remove, #edge, #editable_poly, #edit_poly, #ui)

    if EPolyToolsIntegration.shouldAutoOpenUI() then RedundantRingCollapser.showUI()
)
else
(
    RedundantRingCollapser.showUI()
)
