/*
Redundant Vertex Cleaner project 0.830 audit test.
The audit loads the sibling canonical Two-Edge-Verts.ms itself and verifies the expected release before geometry tests.
*/

global TwoEdgeVerts
global EPOLY_TOOLS_RUNTIME_MODE
global tev_audit_editable_node
global tev_audit_edit_poly_node
global tev_audit_edit_poly_mod
global tev_audit_pass_count
global tev_audit_fail_count
global tev_audit_exception_count
global tev_audit_ready

/*
Resets audit result counters before the canonical Tool is loaded.
*/
function resetAuditCounters =
(
    tev_audit_pass_count = 0
    tev_audit_fail_count = 0
    tev_audit_exception_count = 0
    true
    -- return
)

/*
Prints one Boolean audit result, updates the audit counters, and returns the same Boolean value.
Use the Listener PASS / FAIL lines to verify each contract independently.
*/
function auditCheck condition_value label_text =
(
    if condition_value then
    (
        tev_audit_pass_count += 1
        format "PASS | %\n" label_text
    )
    else
    (
        tev_audit_fail_count += 1
        format "FAIL | %\n" label_text
    )

    condition_value
    -- return
)

/*
Records one unexpected phase exception without hiding the original MAXScript exception text.
*/
function auditRecordException phase_text exception_text =
(
    tev_audit_fail_count += 1
    tev_audit_exception_count += 1
    format "FAIL | % | EXCEPTION: %\n" phase_text exception_text
    false
    -- return
)

/*
Prints the final aggregate audit status and returns true only when no check or phase failed.
*/
function printAuditSummary =
(
    overall_ok = tev_audit_fail_count == 0

    format "\n=== AUDIT SUMMARY ===\n"
    format "PASS: %\n" tev_audit_pass_count
    format "FAIL: %\n" tev_audit_fail_count
    format "EXCEPTIONS: %\n" tev_audit_exception_count

    if overall_ok then
    (
        format "RESULT: PASS\n"
    )
    else
    (
        format "RESULT: FAIL\n"
    )

    overall_ok
    -- return
)

/*
Compares two Arrays by count and ordered element values.
MAXScript Array equality is not used because separate Arrays with identical contents can compare as unequal.
*/
function arraysMatchByValue array_a array_b =
(
    if classOf array_a != Array or classOf array_b != Array then return false
    if array_a.count != array_b.count then return false

    for item_index = 1 to array_a.count do
    (
        if array_a[item_index] != array_b[item_index] then return false
    )

    true
    -- return
)

/*
Returns true when two live Editable Poly vertices share a topology edge.
This independently verifies that removing a degree-two source preserves the edge path between its surviving neighbors.
*/
function editablePolyVerticesShareEdge poly_value vertex_a vertex_b =
(
    if poly_value == undefined then return false
    if vertex_a < 1 or vertex_b < 1 then return false

    vertex_count = polyop.getNumVerts poly_value
    if vertex_a > vertex_count or vertex_b > vertex_count then return false

    incident_edges = polyop.getEdgesUsingVert poly_value #{vertex_a}

    for edge_index in incident_edges do
    (
        edge_vertices = polyop.getEdgeVerts poly_value edge_index

        if edge_vertices != undefined and edge_vertices.count == 2 then
        (
            if (edge_vertices[1] == vertex_a and edge_vertices[2] == vertex_b) or \
               (edge_vertices[1] == vertex_b and edge_vertices[2] == vertex_a) then return true
        )
    )

    false
    -- return
)

/*
Returns true when two live Edit Poly vertices share a topology edge in the tested modifier.
This independently verifies neighbor connectivity after the source vertex is welded away.
*/
function editPolyVerticesShareEdge node edit_poly_mod vertex_a vertex_b =
(
    if node == undefined or not(isValidNode node) then return false
    if edit_poly_mod == undefined or classOf edit_poly_mod != Edit_Poly then return false
    if vertex_a < 1 or vertex_b < 1 then return false

    vertex_count = EditPolyMod.GetNumVertices edit_poly_mod node:node
    if vertex_a > vertex_count or vertex_b > vertex_count then return false

    incident_count = EditPolyMod.GetVertexEdgeCount edit_poly_mod vertex_a node:node

    for incident_index = 1 to incident_count do
    (
        edge_index = EditPolyMod.GetVertexEdge edit_poly_mod vertex_a incident_index node:node
        edge_vertex_a = EditPolyMod.GetEdgeVertex edit_poly_mod edge_index 1 node:node
        edge_vertex_b = EditPolyMod.GetEdgeVertex edit_poly_mod edge_index 2 node:node

        if (edge_vertex_a == vertex_a and edge_vertex_b == vertex_b) or \
           (edge_vertex_a == vertex_b and edge_vertex_b == vertex_a) then return true
    )

    false
    -- return
)


/*
Returns the single internal edge on the two-quad audit plane.
The fixture intentionally has one internal divider and six border edges.
*/
function getAuditSingleInternalEdge poly_value =
(
    if poly_value == undefined then return 0

    edge_count = polyop.getNumEdges poly_value
    open_edges = polyop.getOpenEdges poly_value
    internal_edge = 0
    internal_count = 0

    for edge_index = 1 to edge_count do
    (
        if not(open_edges[edge_index]) then
        (
            internal_edge = edge_index
            internal_count += 1
        )
    )

    if internal_count != 1 then return 0
    internal_edge
    -- return
)

/*
Removes the single internal divider while preserving its endpoint vertices.
The resulting six-sided polygon has two straight border vertices and four border corners.
*/
function prepareAuditTrueTwoEdgeFixture node =
(
    if node == undefined or not(isValidNode node) then return false
    if classOf node.baseObject != Editable_Poly then return false

    poly_value = node.baseObject
    internal_edge = getAuditSingleInternalEdge poly_value
    if internal_edge < 1 then return false

    before_vertex_count = polyop.getNumVerts poly_value
    remove_flag = bit.set 0 30 true
    polyop.setEdgeFlags poly_value #{internal_edge} remove_flag
    node.EditablePoly.remove selLevel:#Edge flag:remove_flag
    update node

    if polyop.getNumVerts poly_value != before_vertex_count then return false
    if polyop.getNumFaces poly_value != 1 then return false
    if getAuditSingleInternalEdge poly_value != 0 then return false

    true
    -- return
)

/*
Hides the single internal divider without removing its topology edge.
The two divider endpoints remain topology T-junctions but expose only their two straight border edges.
*/
function prepareAuditHiddenTJunctionFixture node =
(
    if node == undefined or not(isValidNode node) then return false
    if classOf node.baseObject != Editable_Poly then return false

    poly_value = node.baseObject
    internal_edge = getAuditSingleInternalEdge poly_value
    if internal_edge < 1 then return false

    polyop.setEdgeVis poly_value #{internal_edge} false
    update node

    not(polyop.getEdgeVis poly_value internal_edge)
    -- return
)

/*
Deletes the central quad from a 3x3 Editable Poly plane to create one outer square border and one inner square hole.
The remaining ring supplies four outer corners plus four inner-hole corners without introducing a tolerance.
*/
function prepareAuditBorderRingFixture node =
(
    if node == undefined or not(isValidNode node) then return false
    if classOf node.baseObject != Editable_Poly then return false

    poly_value = node.baseObject
    face_count = polyop.getNumFaces poly_value
    if face_count != 9 then return false

    center_face = 0
    center_distance = 0.0

    for face_index = 1 to face_count do
    (
        face_center = polyop.getFaceCenter poly_value face_index
        face_distance = length face_center

        if center_face == 0 or face_distance < center_distance then
        (
            center_face = face_index
            center_distance = face_distance
        )
    )

    if center_face < 1 then return false

    before_face_count = face_count
    polyop.deleteFaces poly_value #{center_face} delIsoVerts:false
    update node

    after_face_count = polyop.getNumFaces poly_value
    open_edges = polyop.getOpenEdges poly_value

    after_face_count == (before_face_count - 1) and open_edges.numberSet == 16
    -- return
)


/*
Finds an Editable Poly vertex at one exact object-space position.
Exact lookup avoids relying on vertex IDs after a successful weld renumbers topology.
*/
function findEditablePolyVertexAtExactPosition poly_value target_position =
(
    if poly_value == undefined then return 0

    vertex_count = polyop.getNumVerts poly_value

    for vertex_index = 1 to vertex_count do
    (
        if polyop.getVert poly_value vertex_index == target_position then return vertex_index
    )

    0
    -- return
)

/*
Finds an Edit Poly vertex at one exact live modifier position.
Exact lookup avoids relying on modifier vertex IDs after a successful weld renumbers topology.
*/
function findEditPolyVertexAtExactPosition node edit_poly_mod target_position =
(
    if node == undefined or not(isValidNode node) then return 0
    if edit_poly_mod == undefined or classOf edit_poly_mod != Edit_Poly then return 0

    vertex_count = EditPolyMod.GetNumVertices edit_poly_mod node:node

    for vertex_index = 1 to vertex_count do
    (
        if EditPolyMod.GetVertex edit_poly_mod vertex_index node:node == target_position then return vertex_index
    )

    0
    -- return
)

/*
Loads the sibling canonical Tool in library mode and verifies the audit is running against project 0.830 backend 0.75 or newer.
This prevents stale already-loaded globals from producing misleading geometry failures.
*/
function loadAuditTool =
(
    audit_source_path = getSourceFileName()
    if audit_source_path == undefined or audit_source_path == "" then
    (
        auditCheck false "Audit source path is available"
        return false
    )

    package_directory = getFilenamePath audit_source_path
    main_path = package_directory + "Two-Edge-Verts.ms"

    if not(doesFileExist main_path) then
    (
        auditCheck false "Canonical Tool sibling file exists"
        format "DETAIL | Missing canonical Tool: %\n" main_path
        return false
    )

    previous_runtime_mode = EPOLY_TOOLS_RUNTIME_MODE
    EPOLY_TOOLS_RUNTIME_MODE = #library
    load_ok = false
    load_error = undefined

    try
    (
        fileIn main_path quiet:true
        load_ok = true
    )
    catch
    (
        load_error = getCurrentException()
    )

    EPOLY_TOOLS_RUNTIME_MODE = previous_runtime_mode

    if not(load_ok) then
    (
        auditCheck false "Canonical Tool loads without exception"
        format "DETAIL | Canonical Tool load exception: %\n" load_error
        return false
    )

    if TwoEdgeVerts == undefined then
    (
        auditCheck false "TwoEdgeVerts backend exists after canonical Tool load"
        return false
    )

    version_ok = TwoEdgeVerts.file_version >= 0.75 and TwoEdgeVerts.project_version >= 0.830

    auditCheck \
        version_ok \
        ("Loaded current backend | file:" + (TwoEdgeVerts.file_version as string) + " | project:" + (TwoEdgeVerts.project_version as string))

    if not(version_ok) then
    (
        format "AUDIT STOPPED | Expected backend >= 0.75 and project >= 0.830. The local Google Drive copy is stale.\n"
        return false
    )

    true
    -- return
)

/*
Creates independent Editable Poly and Edit Poly audit objects.
Each two-quad plane has its internal divider removed without deleting the divider endpoints, leaving two straight true 2-edge vertices and four border corners.
*/
function partOfTest1 =
(
    undo "TEV AUDIT 1 - Setup" on
    (
        tev_audit_editable_node = Plane \
            name:(uniqueName "TEV_Audit_Editable_") \
            width:80.0 \
            length:40.0 \
            widthsegs:2 \
            lengthsegs:1

        convertTo tev_audit_editable_node Editable_Poly
        tev_audit_editable_node.position = [-60.0, 0.0, 0.0]
        tev_audit_editable_node.showCage = off
        if not(prepareAuditTrueTwoEdgeFixture tev_audit_editable_node) then throw "TEV Audit setup failed to create Editable Poly true 2-edge fixture."

        tev_audit_edit_poly_node = Plane \
            name:(uniqueName "TEV_Audit_EditPoly_") \
            width:80.0 \
            length:40.0 \
            widthsegs:2 \
            lengthsegs:1

        convertTo tev_audit_edit_poly_node Editable_Poly
        tev_audit_edit_poly_node.position = [60.0, 0.0, 0.0]
        tev_audit_edit_poly_node.showCage = off
        if not(prepareAuditTrueTwoEdgeFixture tev_audit_edit_poly_node) then throw "TEV Audit setup failed to create Edit Poly true 2-edge fixture."

        tev_audit_edit_poly_mod = Edit_Poly()
        tev_audit_edit_poly_mod.name = "TEV AUDIT EDIT POLY"
        tev_audit_edit_poly_mod.showCage = off
        addModifier tev_audit_edit_poly_node tev_audit_edit_poly_mod

        select tev_audit_editable_node
    )

    auditCheck \
        (classOf tev_audit_editable_node.baseObject == Editable_Poly) \
        "Editable Poly test object created"

    auditCheck \
        (classOf tev_audit_edit_poly_mod == Edit_Poly) \
        "Edit Poly test modifier created"

    -- return
)

/*
Tests Editable Poly detection, visible-neighbor resolution, manual stepping, and one-vertex removal.
The highest stored candidate must be armed first and consumed only after a successful fix.
*/
function partOfTest2 =
(
    select tev_audit_editable_node
    max modify mode

    candidate_bits = TwoEdgeVerts.getTwoEdgeVerts tev_audit_editable_node

    candidates_ok = false

    if classOf candidate_bits == BitArray then
    (
        candidates_ok = candidate_bits.numberSet == 2
    )

    auditCheck \
        candidates_ok \
        "Editable Poly detects only the two straight true 2-edge vertices"

    if not(candidates_ok) then
    (
        format "FAIL | Editable Poly candidate set is %, expected two true 2-edge vertices.\n" candidate_bits
        return false
    )

    border_corner_bits = TwoEdgeVerts.getBorderCornerVerts tev_audit_editable_node
    t_junction_bits = TwoEdgeVerts.getTJunctionVerts tev_audit_editable_node

    auditCheck \
        (classOf border_corner_bits == BitArray and border_corner_bits.numberSet == 4) \
        "Editable Poly border-corner classifier owns the four polygon corners"

    auditCheck \
        (classOf t_junction_bits == BitArray and t_junction_bits.numberSet == 0) \
        "Editable Poly true 2-edge fixture contains no T-junctions"

    auditCheck \
        ((candidate_bits * border_corner_bits).numberSet == 0 and (candidate_bits * t_junction_bits).numberSet == 0) \
        "Editable Poly true 2-edge candidates do not overlap border-corner or T-junction classes"

    stored_ids = TwoEdgeVerts.storeCandidateIds tev_audit_editable_node candidate_bits
    stored_ok = false

    if classOf stored_ids == Array then
    (
        stored_ok = stored_ids.count == 2
    )

    auditCheck \
        stored_ok \
        "Editable Poly storeCandidateIds returns only the two true 2-edge IDs"

    if not(stored_ok) then
    (
        format "FAIL | Editable Poly storeCandidateIds returned %, expected a two-ID Array.\n" stored_ids
        return false
    )

    stored_readback = TwoEdgeVerts.getStoredCandidateIds()
    readback_ok = false

    if classOf stored_readback == Array then
    (
        readback_ok = arraysMatchByValue stored_readback stored_ids
    )

    auditCheck \
        readback_ok \
        "Editable Poly getStoredCandidateIds returns the stored candidate Array"

    if not(readback_ok) then
    (
        format "FAIL | Editable Poly stored readback is %, expected %.\n" stored_readback stored_ids
        return false
    )

    source_vertex_id = TwoEdgeVerts.getNextStoredCandidateId()
    source_ok = false

    if classOf source_vertex_id == Integer then
    (
        source_ok = source_vertex_id > 0 and source_vertex_id == stored_ids[stored_ids.count]
    )

    auditCheck \
        source_ok \
        "Editable Poly manual queue resolves the highest stored ID first"

    if not(source_ok) then
    (
        format "FAIL | Editable Poly next candidate is %, stored IDs:%\n" source_vertex_id stored_ids
        return false
    )

    visible_neighbors = TwoEdgeVerts.getVisibleNeighborVertexIds tev_audit_editable_node source_vertex_id
    closest_neighbor_id = TwoEdgeVerts.getClosestVisibleNeighborVertexId tev_audit_editable_node source_vertex_id

    neighbors_ok = false

    if classOf visible_neighbors == Array then
    (
        neighbors_ok = visible_neighbors.count == 2
    )

    auditCheck \
        neighbors_ok \
        "Editable Poly source has exactly two actually visible neighbors"

    if not(neighbors_ok) then
    (
        format "FAIL | Editable Poly visible neighbors are %, expected a two-ID Array.\n" visible_neighbors
        return false
    )

    closest_ok = false

    if classOf closest_neighbor_id == Integer then
    (
        closest_ok = (findItem visible_neighbors closest_neighbor_id) > 0
    )

    auditCheck \
        closest_ok \
        "Editable Poly closest weld target belongs to the visible-neighbor set"

    if not(closest_ok) then return false

    other_neighbor_id = if visible_neighbors[1] == closest_neighbor_id then visible_neighbors[2] else visible_neighbors[1]
    target_position_before = polyop.getVert tev_audit_editable_node.baseObject closest_neighbor_id
    other_position_before = polyop.getVert tev_audit_editable_node.baseObject other_neighbor_id

    selected_ok = TwoEdgeVerts.selectNextManualRemoveCandidate()
    selected_bits = polyop.getVertSelection tev_audit_editable_node.baseObject

    auditCheck \
        (selected_ok == true) \
        "Editable Poly manual LMB arms one candidate without changing topology"

    auditCheck \
        (selected_bits == #{source_vertex_id}) \
        "Editable Poly manual LMB selects only the armed source vertex"

    polyop.setVertSelection tev_audit_editable_node.baseObject #{}
    changed_selection_bits = polyop.getVertSelection tev_audit_editable_node.baseObject

    auditCheck \
        (changed_selection_bits.numberSet == 0) \
        "Editable Poly manual RMB does not depend on the armed source remaining selected"

    before_vertex_count = polyop.getNumVerts tev_audit_editable_node.baseObject
    fixed_ok = TwoEdgeVerts.fixManualRemoveCandidate()
    after_vertex_count = polyop.getNumVerts tev_audit_editable_node.baseObject
    remaining_ids = TwoEdgeVerts.getStoredCandidateIds()
    final_selection = polyop.getVertSelection tev_audit_editable_node.baseObject

    resolved_target_id = findEditablePolyVertexAtExactPosition tev_audit_editable_node.baseObject target_position_before
    resolved_other_id = findEditablePolyVertexAtExactPosition tev_audit_editable_node.baseObject other_position_before
    target_position_after = if resolved_target_id > 0 then polyop.getVert tev_audit_editable_node.baseObject resolved_target_id else undefined

    auditCheck \
        (fixed_ok == true) \
        "Editable Poly manual RMB reports a successful fix"

    auditCheck \
        (after_vertex_count == (before_vertex_count - 1)) \
        "Editable Poly manual RMB removes exactly one source vertex"

    auditCheck \
        (editablePolyVerticesShareEdge tev_audit_editable_node.baseObject resolved_target_id resolved_other_id) \
        "Editable Poly removal preserves an edge between the two surviving source neighbors"

    auditCheck \
        (target_position_after != undefined and target_position_after == target_position_before) \
        "Editable Poly surviving neighbor stays at its original position"

    remaining_ok = false

    if classOf remaining_ids == Array then
    (
        remaining_ok = (findItem remaining_ids source_vertex_id) == 0
    )

    auditCheck \
        remaining_ok \
        "Editable Poly successful fix consumes only the processed stored ID"

    final_selection_ok = false

    if classOf final_selection == BitArray then
    (
        final_selection_ok = final_selection.numberSet == 0
    )

    auditCheck \
        final_selection_ok \
        "Editable Poly successful fix clears component selection"

    -- return
)

/*
Tests the same manual workflow on live Edit Poly topology.
Candidate identity must remain the live modifier vertex ID while snapshot data is used only for visibility.
*/
function partOfTest3 =
(
    select tev_audit_edit_poly_node
    max modify mode

    tev_audit_edit_poly_mod.SetPrimaryNode tev_audit_edit_poly_node
    tev_audit_edit_poly_mod.useStackSelection = false
    tev_audit_edit_poly_mod.selectMode = 0
    tev_audit_edit_poly_mod.showCage = off

    modPanel.setCurrentObject tev_audit_edit_poly_mod node:tev_audit_edit_poly_node

    tev_audit_edit_poly_mod.SetEPolySelLevel #Vertex
    subObjectLevel = 1

    candidate_bits = TwoEdgeVerts.getTwoEdgeVerts \
        tev_audit_edit_poly_node \
        edit_poly_mod:tev_audit_edit_poly_mod

    candidates_ok = false

    if classOf candidate_bits == BitArray then
    (
        candidates_ok = candidate_bits.numberSet == 2
    )

    auditCheck \
        candidates_ok \
        "Edit Poly detects only the two live straight true 2-edge IDs"

    if not(candidates_ok) then
    (
        format "FAIL | Edit Poly candidate set is %, expected two true 2-edge vertices.\n" candidate_bits
        return false
    )

    border_corner_bits = TwoEdgeVerts.getBorderCornerVerts \
        tev_audit_edit_poly_node \
        edit_poly_mod:tev_audit_edit_poly_mod

    t_junction_bits = TwoEdgeVerts.getTJunctionVerts \
        tev_audit_edit_poly_node \
        edit_poly_mod:tev_audit_edit_poly_mod

    auditCheck \
        (classOf border_corner_bits == BitArray and border_corner_bits.numberSet == 4) \
        "Edit Poly border-corner classifier owns the four polygon corners"

    auditCheck \
        (classOf t_junction_bits == BitArray and t_junction_bits.numberSet == 0) \
        "Edit Poly true 2-edge fixture contains no T-junctions"

    auditCheck \
        ((candidate_bits * border_corner_bits).numberSet == 0 and (candidate_bits * t_junction_bits).numberSet == 0) \
        "Edit Poly true 2-edge candidates do not overlap border-corner or T-junction classes"

    stored_ids = TwoEdgeVerts.storeCandidateIds \
        tev_audit_edit_poly_node \
        candidate_bits \
        edit_poly_mod:tev_audit_edit_poly_mod

    stored_ok = false

    if classOf stored_ids == Array then
    (
        stored_ok = stored_ids.count == 2
    )

    auditCheck \
        stored_ok \
        "Edit Poly storeCandidateIds returns only the two live true 2-edge IDs"

    if not(stored_ok) then
    (
        format "FAIL | Edit Poly storeCandidateIds returned %, expected a two-ID Array.\n" stored_ids
        return false
    )

    stored_readback = TwoEdgeVerts.getStoredCandidateIds()
    readback_ok = false

    if classOf stored_readback == Array then
    (
        readback_ok = arraysMatchByValue stored_readback stored_ids
    )

    auditCheck \
        readback_ok \
        "Edit Poly getStoredCandidateIds returns the stored candidate Array"

    if not(readback_ok) then
    (
        format "FAIL | Edit Poly stored readback is %, expected %.\n" stored_readback stored_ids
        return false
    )

    source_vertex_id = TwoEdgeVerts.getNextStoredCandidateId()
    source_ok = false

    if classOf source_vertex_id == Integer then
    (
        source_ok = source_vertex_id > 0 and source_vertex_id == stored_ids[stored_ids.count]
    )

    auditCheck \
        source_ok \
        "Edit Poly manual queue resolves the highest stored ID first"

    if not(source_ok) then
    (
        format "FAIL | Edit Poly next candidate is %, stored IDs:%\n" source_vertex_id stored_ids
        return false
    )

    visible_neighbors = TwoEdgeVerts.getVisibleNeighborVertexIds \
        tev_audit_edit_poly_node \
        source_vertex_id \
        edit_poly_mod:tev_audit_edit_poly_mod

    closest_neighbor_id = TwoEdgeVerts.getClosestVisibleNeighborVertexId \
        tev_audit_edit_poly_node \
        source_vertex_id \
        edit_poly_mod:tev_audit_edit_poly_mod

    neighbors_ok = false

    if classOf visible_neighbors == Array then
    (
        neighbors_ok = visible_neighbors.count == 2
    )

    auditCheck \
        neighbors_ok \
        "Edit Poly source has exactly two actually visible neighbors"

    if not(neighbors_ok) then
    (
        format "FAIL | Edit Poly visible neighbors are %, expected a two-ID Array.\n" visible_neighbors
        return false
    )

    closest_ok = false

    if classOf closest_neighbor_id == Integer then
    (
        closest_ok = (findItem visible_neighbors closest_neighbor_id) > 0
    )

    auditCheck \
        closest_ok \
        "Edit Poly closest weld target belongs to the visible-neighbor set"

    if not(closest_ok) then return false

    other_neighbor_id = if visible_neighbors[1] == closest_neighbor_id then visible_neighbors[2] else visible_neighbors[1]
    target_position_before = EditPolyMod.GetVertex tev_audit_edit_poly_mod closest_neighbor_id node:tev_audit_edit_poly_node
    other_position_before = EditPolyMod.GetVertex tev_audit_edit_poly_mod other_neighbor_id node:tev_audit_edit_poly_node

    selected_ok = TwoEdgeVerts.selectNextManualRemoveCandidate()
    selected_bits = tev_audit_edit_poly_mod.GetSelection #Vertex node:tev_audit_edit_poly_node

    auditCheck \
        (selected_ok == true) \
        "Edit Poly manual LMB arms one live modifier candidate"

    auditCheck \
        (selected_bits == #{source_vertex_id}) \
        "Edit Poly manual LMB selects only the armed live modifier vertex"

    if selected_bits.numberSet > 0 then
    (
        tev_audit_edit_poly_mod.Select #Vertex selected_bits select:false node:tev_audit_edit_poly_node
    )

    changed_selection_bits = tev_audit_edit_poly_mod.GetSelection #Vertex node:tev_audit_edit_poly_node
    if changed_selection_bits == undefined then changed_selection_bits = #{}

    auditCheck \
        (changed_selection_bits.numberSet == 0) \
        "Edit Poly manual RMB does not depend on the armed source remaining selected"

    before_vertex_count = EditPolyMod.GetNumVertices \
        tev_audit_edit_poly_mod \
        node:tev_audit_edit_poly_node

    fixed_ok = TwoEdgeVerts.fixManualRemoveCandidate()

    after_vertex_count = EditPolyMod.GetNumVertices \
        tev_audit_edit_poly_mod \
        node:tev_audit_edit_poly_node

    remaining_ids = TwoEdgeVerts.getStoredCandidateIds()
    final_selection = tev_audit_edit_poly_mod.GetSelection #Vertex node:tev_audit_edit_poly_node

    resolved_target_id = findEditPolyVertexAtExactPosition tev_audit_edit_poly_node tev_audit_edit_poly_mod target_position_before
    resolved_other_id = findEditPolyVertexAtExactPosition tev_audit_edit_poly_node tev_audit_edit_poly_mod other_position_before
    target_position_after = if resolved_target_id > 0 then EditPolyMod.GetVertex tev_audit_edit_poly_mod resolved_target_id node:tev_audit_edit_poly_node else undefined

    auditCheck \
        (fixed_ok == true) \
        "Edit Poly manual RMB reports a successful fix"

    auditCheck \
        (after_vertex_count == (before_vertex_count - 1)) \
        "Edit Poly manual RMB removes exactly one source vertex"

    auditCheck \
        (editPolyVerticesShareEdge tev_audit_edit_poly_node tev_audit_edit_poly_mod resolved_target_id resolved_other_id) \
        "Edit Poly removal preserves an edge between the two surviving source neighbors"

    auditCheck \
        (target_position_after != undefined and target_position_after == target_position_before) \
        "Edit Poly surviving neighbor stays at its original position"

    remaining_ok = false

    if classOf remaining_ids == Array then
    (
        remaining_ok = (findItem remaining_ids source_vertex_id) == 0
    )

    auditCheck \
        remaining_ok \
        "Edit Poly successful fix consumes only the processed stored ID"

    final_selection_ok = false

    if classOf final_selection == BitArray then
    (
        final_selection_ok = final_selection.numberSet == 0
    )

    auditCheck \
        final_selection_ok \
        "Edit Poly successful fix clears modifier vertex selection"

    -- return
)

/*
Verifies that SEARCH rejects multi-object input and remains non-destructive.
This protects the one-object candidate-state contract introduced in project 0.818.
*/
function partOfTest4 =
(
    editable_before = polyop.getNumVerts tev_audit_editable_node.baseObject
    edit_poly_before = EditPolyMod.GetNumVertices \
        tev_audit_edit_poly_mod \
        node:tev_audit_edit_poly_node

    select #(tev_audit_editable_node, tev_audit_edit_poly_node)
    search_ok = TwoEdgeVerts.selectTwoEdgeVerts()

    editable_after = polyop.getNumVerts tev_audit_editable_node.baseObject
    edit_poly_after = EditPolyMod.GetNumVertices \
        tev_audit_edit_poly_mod \
        node:tev_audit_edit_poly_node

    auditCheck \
        (search_ok == false) \
        "SEARCH rejects multi-object input"

    auditCheck \
        (editable_after == editable_before and edit_poly_after == edit_poly_before) \
        "Rejected multi-object SEARCH does not alter topology"

    -- return
)

/*
Verifies that a hidden branch cannot make a topology T-junction leak into true 2-edge detection.
The same two-quad fixture also proves border corners are owned only by their dedicated classifier.
*/
function partOfTest5 =
(
    overlap_editable = undefined
    overlap_edit_poly_node = undefined
    overlap_edit_poly_mod = undefined

    undo "TEV AUDIT 5 - Classification Separation" on
    (
        overlap_editable = Plane \
            name:(uniqueName "TEV_Audit_Overlap_Editable_") \
            width:80.0 \
            length:40.0 \
            widthsegs:2 \
            lengthsegs:1

        convertTo overlap_editable Editable_Poly
        overlap_editable.position = [-60.0, 80.0, 0.0]
        overlap_editable.showCage = off
        if not(prepareAuditHiddenTJunctionFixture overlap_editable) then throw "TEV Audit overlap Editable Poly setup failed."

        overlap_edit_poly_node = Plane \
            name:(uniqueName "TEV_Audit_Overlap_EditPoly_") \
            width:80.0 \
            length:40.0 \
            widthsegs:2 \
            lengthsegs:1

        convertTo overlap_edit_poly_node Editable_Poly
        overlap_edit_poly_node.position = [60.0, 80.0, 0.0]
        overlap_edit_poly_node.showCage = off
        if not(prepareAuditHiddenTJunctionFixture overlap_edit_poly_node) then throw "TEV Audit overlap Edit Poly setup failed."

        overlap_edit_poly_mod = Edit_Poly()
        overlap_edit_poly_mod.name = "TEV AUDIT OVERLAP EDIT POLY"
        overlap_edit_poly_mod.showCage = off
        addModifier overlap_edit_poly_node overlap_edit_poly_mod
    )

    editable_two_bits = TwoEdgeVerts.getTwoEdgeVerts overlap_editable
    editable_t_bits = TwoEdgeVerts.getTJunctionVerts overlap_editable
    editable_border_t_bits = TwoEdgeVerts.getBorderTJunctionVerts overlap_editable
    editable_border_bits = TwoEdgeVerts.getBorderCornerVerts overlap_editable
    editable_types_ok = classOf editable_two_bits == BitArray and classOf editable_t_bits == BitArray and classOf editable_border_t_bits == BitArray and classOf editable_border_bits == BitArray

    auditCheck \
        editable_types_ok \
        "Editable Poly classification APIs return BitArrays"

    if editable_types_ok then
    (
        auditCheck \
            (editable_two_bits.numberSet == 0) \
            "Editable Poly hidden-branch fixture has no true 2-edge candidates"

        auditCheck \
            (editable_t_bits.numberSet == 2) \
            "Editable Poly hidden branch remains owned by the two T-junction vertices"

        auditCheck \
            (editable_border_t_bits.numberSet == 2 and editable_border_t_bits == editable_t_bits) \
            "Editable Poly hidden-branch fixture identifies both T-junctions as border T-junctions"

        auditCheck \
            (editable_border_bits.numberSet == 4) \
            "Editable Poly four 90-degree border corners stay in the border-corner class"

        auditCheck \
            ((editable_two_bits * editable_t_bits).numberSet == 0 and (editable_two_bits * editable_border_bits).numberSet == 0 and (editable_t_bits * editable_border_bits).numberSet == 0) \
            "Editable Poly classification sets are mutually exclusive"
    )

    if not(editable_types_ok) then return false

    select overlap_editable
    t_select_ok = TwoEdgeVerts.selectTJunctionVerts()
    selected_t_bits = polyop.getVertSelection overlap_editable.baseObject

    auditCheck \
        (t_select_ok and selected_t_bits == editable_t_bits) \
        "Editable Poly T-junction selector selects only the T-junction class"

    select overlap_editable
    border_t_select_ok = TwoEdgeVerts.selectBorderTJunctionVerts()
    selected_border_t_bits = polyop.getVertSelection overlap_editable.baseObject

    auditCheck \
        (border_t_select_ok and selected_border_t_bits == editable_border_t_bits) \
        "Editable Poly border T-junction selector selects only the border T-junction subset"

    select overlap_editable
    border_select_ok = TwoEdgeVerts.selectBorderCornerVerts()
    selected_border_bits = polyop.getVertSelection overlap_editable.baseObject

    auditCheck \
        (border_select_ok and selected_border_bits == editable_border_bits) \
        "Editable Poly border-corner selector selects only the border-corner class"

    select overlap_edit_poly_node
    max modify mode
    overlap_edit_poly_mod.SetPrimaryNode overlap_edit_poly_node
    overlap_edit_poly_mod.useStackSelection = false
    overlap_edit_poly_mod.selectMode = 0
    overlap_edit_poly_mod.showCage = off
    modPanel.setCurrentObject overlap_edit_poly_mod node:overlap_edit_poly_node
    overlap_edit_poly_mod.SetEPolySelLevel #Vertex
    subObjectLevel = 1

    edit_two_bits = TwoEdgeVerts.getTwoEdgeVerts overlap_edit_poly_node edit_poly_mod:overlap_edit_poly_mod
    edit_t_bits = TwoEdgeVerts.getTJunctionVerts overlap_edit_poly_node edit_poly_mod:overlap_edit_poly_mod
    edit_border_t_bits = TwoEdgeVerts.getBorderTJunctionVerts overlap_edit_poly_node edit_poly_mod:overlap_edit_poly_mod
    edit_border_bits = TwoEdgeVerts.getBorderCornerVerts overlap_edit_poly_node edit_poly_mod:overlap_edit_poly_mod
    edit_types_ok = classOf edit_two_bits == BitArray and classOf edit_t_bits == BitArray and classOf edit_border_t_bits == BitArray and classOf edit_border_bits == BitArray

    auditCheck \
        edit_types_ok \
        "Edit Poly classification APIs return BitArrays"

    if edit_types_ok then
    (
        auditCheck \
            (edit_two_bits.numberSet == 0) \
            "Edit Poly hidden-branch fixture has no true 2-edge candidates"

        auditCheck \
            (edit_t_bits.numberSet == 2) \
            "Edit Poly hidden branch remains owned by the two live T-junction vertices"

        auditCheck \
            (edit_border_t_bits.numberSet == 2 and edit_border_t_bits == edit_t_bits) \
            "Edit Poly hidden-branch fixture identifies both live T-junctions as border T-junctions"

        auditCheck \
            (edit_border_bits.numberSet == 4) \
            "Edit Poly four 90-degree border corners stay in the live border-corner class"

        auditCheck \
            ((edit_two_bits * edit_t_bits).numberSet == 0 and (edit_two_bits * edit_border_bits).numberSet == 0 and (edit_t_bits * edit_border_bits).numberSet == 0) \
            "Edit Poly classification sets are mutually exclusive"
    )

    if not(edit_types_ok) then return false

    -- return
)

/*
Creates exact-position duplicate fixtures for Editable Poly and Edit Poly, then verifies detection and collapse.
The duplicate pair shares one literal Point3 position, so no tolerance participates in the test.
*/
function partOfTest6 =
(
    duplicate_editable = undefined
    duplicate_edit_poly_node = undefined
    duplicate_edit_poly_mod = undefined

    undo "RVC AUDIT 6 - Exact Duplicate Vertices" on
    (
        duplicate_editable = mesh \
            name:(uniqueName "RVC_Audit_Duplicate_Editable_") \
            vertices:#([0,0,0], [20,0,0], [0,20,0], [0,0,0], [-20,0,0], [0,-20,0]) \
            faces:#([1,2,3], [4,5,6])
        convertTo duplicate_editable Editable_Poly
        duplicate_editable.position = [-60.0, 160.0, 0.0]
        duplicate_editable.showCage = off

        duplicate_edit_poly_node = mesh \
            name:(uniqueName "RVC_Audit_Duplicate_EditPoly_") \
            vertices:#([0,0,0], [20,0,0], [0,20,0], [0,0,0], [-20,0,0], [0,-20,0]) \
            faces:#([1,2,3], [4,5,6])
        convertTo duplicate_edit_poly_node Editable_Poly
        duplicate_edit_poly_node.position = [60.0, 160.0, 0.0]
        duplicate_edit_poly_node.showCage = off

        duplicate_edit_poly_mod = Edit_Poly()
        duplicate_edit_poly_mod.name = "RVC AUDIT DUPLICATE EDIT POLY"
        duplicate_edit_poly_mod.showCage = off
        addModifier duplicate_edit_poly_node duplicate_edit_poly_mod
    )

    editable_before = polyop.getNumVerts duplicate_editable.baseObject
    editable_duplicate_bits = TwoEdgeVerts.getDuplicatePositionVerts duplicate_editable

    auditCheck \
        (classOf editable_duplicate_bits == BitArray and editable_duplicate_bits.numberSet == 2) \
        "Editable Poly detects exactly the two exact-position duplicate vertices"

    editable_removed = TwoEdgeVerts.collapseDuplicatePositionVerts duplicate_editable
    editable_after = polyop.getNumVerts duplicate_editable.baseObject
    editable_remaining_bits = TwoEdgeVerts.getDuplicatePositionVerts duplicate_editable

    auditCheck \
        (editable_removed == 1 and editable_after == (editable_before - 1)) \
        "Editable Poly exact duplicate collapse removes exactly one vertex"

    auditCheck \
        (classOf editable_remaining_bits == BitArray and editable_remaining_bits.numberSet == 0) \
        "Editable Poly has no exact-position duplicate group after collapse"

    select duplicate_edit_poly_node
    max modify mode
    duplicate_edit_poly_mod.SetPrimaryNode duplicate_edit_poly_node
    duplicate_edit_poly_mod.useStackSelection = false
    duplicate_edit_poly_mod.selectMode = 0
    duplicate_edit_poly_mod.showCage = off
    modPanel.setCurrentObject duplicate_edit_poly_mod node:duplicate_edit_poly_node
    duplicate_edit_poly_mod.SetEPolySelLevel #Vertex
    subObjectLevel = 1

    edit_before = EditPolyMod.GetNumVertices duplicate_edit_poly_mod node:duplicate_edit_poly_node
    edit_duplicate_bits = TwoEdgeVerts.getDuplicatePositionVerts duplicate_edit_poly_node edit_poly_mod:duplicate_edit_poly_mod

    auditCheck \
        (classOf edit_duplicate_bits == BitArray and edit_duplicate_bits.numberSet == 2) \
        "Edit Poly detects exactly the two live exact-position duplicate vertices"

    edit_removed = TwoEdgeVerts.collapseDuplicatePositionVerts duplicate_edit_poly_node edit_poly_mod:duplicate_edit_poly_mod
    edit_after = EditPolyMod.GetNumVertices duplicate_edit_poly_mod node:duplicate_edit_poly_node
    edit_remaining_bits = TwoEdgeVerts.getDuplicatePositionVerts duplicate_edit_poly_node edit_poly_mod:duplicate_edit_poly_mod

    auditCheck \
        (edit_removed == 1 and edit_after == (edit_before - 1)) \
        "Edit Poly exact duplicate collapse removes exactly one live vertex"

    auditCheck \
        (classOf edit_remaining_bits == BitArray and edit_remaining_bits.numberSet == 0) \
        "Edit Poly has no exact-position duplicate group after collapse"

    -- return
)


/*
Creates fresh Editable Poly and Edit Poly fixtures and verifies SEARCH RMB reaches a fixed point.
The operation must repeatedly re-detect live topology until no true two-edge candidates remain.
*/
function partOfTest7 =
(
    stable_editable = undefined
    stable_edit_poly_node = undefined
    stable_edit_poly_mod = undefined

    undo "RVC AUDIT 7 - Stable Cleanup Setup" on
    (
        stable_editable = Plane \
            name:(uniqueName "RVC_Audit_Stable_Editable_") \
            width:80.0 \
            length:40.0 \
            widthsegs:2 \
            lengthsegs:1

        convertTo stable_editable Editable_Poly
        stable_editable.position = [-60.0, 240.0, 0.0]
        stable_editable.showCage = off
        if not(prepareAuditTrueTwoEdgeFixture stable_editable) then throw "RVC Audit stable setup failed for Editable Poly."

        stable_edit_poly_node = Plane \
            name:(uniqueName "RVC_Audit_Stable_EditPoly_") \
            width:80.0 \
            length:40.0 \
            widthsegs:2 \
            lengthsegs:1

        convertTo stable_edit_poly_node Editable_Poly
        stable_edit_poly_node.position = [60.0, 240.0, 0.0]
        stable_edit_poly_node.showCage = off
        if not(prepareAuditTrueTwoEdgeFixture stable_edit_poly_node) then throw "RVC Audit stable setup failed for Edit Poly."

        stable_edit_poly_mod = Edit_Poly()
        stable_edit_poly_mod.name = "RVC AUDIT STABLE EDIT POLY"
        stable_edit_poly_mod.showCage = off
        addModifier stable_edit_poly_node stable_edit_poly_mod
    )

    select stable_editable
    editable_initial = TwoEdgeVerts.getTwoEdgeVerts stable_editable
    editable_before = polyop.getNumVerts stable_editable.baseObject
    editable_removed = TwoEdgeVerts.removeTwoEdgeVertsUntilStable()
    editable_after = polyop.getNumVerts stable_editable.baseObject
    editable_remaining = TwoEdgeVerts.getTwoEdgeVerts stable_editable

    auditCheck \
        (classOf editable_initial == BitArray and editable_initial.numberSet == 2) \
        "Editable Poly stable fixture begins with two true 2-edge candidates"

    auditCheck \
        (editable_removed == 2 and editable_after == (editable_before - 2)) \
        "Editable Poly fixed-point cleanup removes both live candidates"

    auditCheck \
        (classOf editable_remaining == BitArray and editable_remaining.numberSet == 0) \
        "Editable Poly fixed-point cleanup finishes with zero true 2-edge candidates"

    select stable_edit_poly_node
    max modify mode
    stable_edit_poly_mod.SetPrimaryNode stable_edit_poly_node
    stable_edit_poly_mod.useStackSelection = false
    stable_edit_poly_mod.selectMode = 0
    stable_edit_poly_mod.showCage = off
    modPanel.setCurrentObject stable_edit_poly_mod node:stable_edit_poly_node
    stable_edit_poly_mod.SetEPolySelLevel #Vertex
    subObjectLevel = 1

    edit_initial = TwoEdgeVerts.getTwoEdgeVerts stable_edit_poly_node edit_poly_mod:stable_edit_poly_mod
    edit_before = EditPolyMod.GetNumVertices stable_edit_poly_mod node:stable_edit_poly_node
    edit_removed = TwoEdgeVerts.removeTwoEdgeVertsUntilStable()
    edit_after = EditPolyMod.GetNumVertices stable_edit_poly_mod node:stable_edit_poly_node
    edit_remaining = TwoEdgeVerts.getTwoEdgeVerts stable_edit_poly_node edit_poly_mod:stable_edit_poly_mod

    auditCheck \
        (classOf edit_initial == BitArray and edit_initial.numberSet == 2) \
        "Edit Poly stable fixture begins with two live true 2-edge candidates"

    auditCheck \
        (edit_removed == 2 and edit_after == (edit_before - 2)) \
        "Edit Poly fixed-point cleanup removes both live candidates"

    auditCheck \
        (classOf edit_remaining == BitArray and edit_remaining.numberSet == 0) \
        "Edit Poly fixed-point cleanup finishes with zero live true 2-edge candidates"

    -- return
)


/*
Creates square-ring fixtures and verifies that border corners split into inner-hole and exterior-perimeter classes.
The compatibility border-corner API must remain the exact union of the two new selectors on both supported topology types.
*/
function partOfTest8 =
(
    ring_editable = undefined
    ring_edit_poly_node = undefined
    ring_edit_poly_mod = undefined

    undo "RVC AUDIT 8 - Inner Outer Border Corners" on
    (
        ring_editable = Plane \
            name:(uniqueName "RVC_Audit_BorderRing_Editable_") \
            width:90.0 \
            length:90.0 \
            widthsegs:3 \
            lengthsegs:3

        convertTo ring_editable Editable_Poly
        ring_editable.position = [-60.0, 340.0, 0.0]
        ring_editable.showCage = off
        if not(prepareAuditBorderRingFixture ring_editable) then throw "RVC Audit border-ring setup failed for Editable Poly."

        ring_edit_poly_node = Plane \
            name:(uniqueName "RVC_Audit_BorderRing_EditPoly_") \
            width:90.0 \
            length:90.0 \
            widthsegs:3 \
            lengthsegs:3

        convertTo ring_edit_poly_node Editable_Poly
        ring_edit_poly_node.position = [60.0, 340.0, 0.0]
        ring_edit_poly_node.showCage = off
        if not(prepareAuditBorderRingFixture ring_edit_poly_node) then throw "RVC Audit border-ring setup failed for Edit Poly."

        ring_edit_poly_mod = Edit_Poly()
        ring_edit_poly_mod.name = "RVC AUDIT BORDER RING EDIT POLY"
        ring_edit_poly_mod.showCage = off
        addModifier ring_edit_poly_node ring_edit_poly_mod
    )

    editable_all = TwoEdgeVerts.getBorderCornerVerts ring_editable
    editable_inner = TwoEdgeVerts.getInnerBorderCornerVerts ring_editable
    editable_outer = TwoEdgeVerts.getOuterBorderCornerVerts ring_editable

    auditCheck \
        (classOf editable_all == BitArray and editable_all.numberSet == 8) \
        "Editable Poly square ring has eight total border corners"

    auditCheck \
        (classOf editable_inner == BitArray and editable_inner.numberSet == 4) \
        "Editable Poly square ring identifies four inner-hole border corners"

    auditCheck \
        (classOf editable_outer == BitArray and editable_outer.numberSet == 4) \
        "Editable Poly square ring identifies four exterior border corners"

    auditCheck \
        ((editable_inner * editable_outer).numberSet == 0 and (editable_inner + editable_outer) == editable_all) \
        "Editable Poly inner and outer border-corner sets are disjoint and exactly rebuild the compatibility union"

    select ring_editable
    inner_select_ok = TwoEdgeVerts.selectInnerBorderCornerVerts()
    inner_selected = polyop.getVertSelection ring_editable.baseObject

    auditCheck \
        (inner_select_ok and inner_selected == editable_inner) \
        "Editable Poly INNER BORDER CORNERS selector selects only the hole corners"

    select ring_editable
    outer_select_ok = TwoEdgeVerts.selectOuterBorderCornerVerts()
    outer_selected = polyop.getVertSelection ring_editable.baseObject

    auditCheck \
        (outer_select_ok and outer_selected == editable_outer) \
        "Editable Poly OUTTER BORDER CORNERS selector selects only the exterior corners"

    select ring_edit_poly_node
    max modify mode
    ring_edit_poly_mod.SetPrimaryNode ring_edit_poly_node
    ring_edit_poly_mod.useStackSelection = false
    ring_edit_poly_mod.selectMode = 0
    ring_edit_poly_mod.showCage = off
    modPanel.setCurrentObject ring_edit_poly_mod node:ring_edit_poly_node
    ring_edit_poly_mod.SetEPolySelLevel #Vertex
    subObjectLevel = 1

    edit_all = TwoEdgeVerts.getBorderCornerVerts ring_edit_poly_node edit_poly_mod:ring_edit_poly_mod
    edit_inner = TwoEdgeVerts.getInnerBorderCornerVerts ring_edit_poly_node edit_poly_mod:ring_edit_poly_mod
    edit_outer = TwoEdgeVerts.getOuterBorderCornerVerts ring_edit_poly_node edit_poly_mod:ring_edit_poly_mod

    auditCheck \
        (classOf edit_all == BitArray and edit_all.numberSet == 8) \
        "Edit Poly square ring has eight live total border corners"

    auditCheck \
        (classOf edit_inner == BitArray and edit_inner.numberSet == 4) \
        "Edit Poly square ring identifies four live inner-hole border corners"

    auditCheck \
        (classOf edit_outer == BitArray and edit_outer.numberSet == 4) \
        "Edit Poly square ring identifies four live exterior border corners"

    auditCheck \
        ((edit_inner * edit_outer).numberSet == 0 and (edit_inner + edit_outer) == edit_all) \
        "Edit Poly inner and outer border-corner sets are disjoint and exactly rebuild the compatibility union"

    select ring_edit_poly_node
    edit_inner_select_ok = TwoEdgeVerts.selectInnerBorderCornerVerts()
    edit_inner_selected = ring_edit_poly_mod.GetSelection #Vertex node:ring_edit_poly_node

    auditCheck \
        (edit_inner_select_ok and edit_inner_selected == edit_inner) \
        "Edit Poly INNER BORDER CORNERS selector selects only the live hole corners"

    select ring_edit_poly_node
    edit_outer_select_ok = TwoEdgeVerts.selectOuterBorderCornerVerts()
    edit_outer_selected = ring_edit_poly_mod.GetSelection #Vertex node:ring_edit_poly_node

    auditCheck \
        (edit_outer_select_ok and edit_outer_selected == edit_outer) \
        "Edit Poly OUTTER BORDER CORNERS selector selects only the live exterior corners"

    -- return
)


/*
Creates fresh Editable Poly and Edit Poly fixtures and verifies FIX SELECTED VERT works without SEARCH/manual queue state.
Exactly one selected true two-edge vertex must be removed and any stale manual candidate state must be cleared after success.
*/
function partOfTest9 =
(
    direct_editable = undefined
    direct_edit_poly_node = undefined
    direct_edit_poly_mod = undefined

    undo "RVC AUDIT 9 - Direct Selected Fix Setup" on
    (
        direct_editable = Plane \
            name:(uniqueName "RVC_Audit_DirectFix_Editable_") \
            width:80.0 \
            length:40.0 \
            widthsegs:2 \
            lengthsegs:1

        convertTo direct_editable Editable_Poly
        direct_editable.position = [-60.0, 440.0, 0.0]
        direct_editable.showCage = off
        if not(prepareAuditTrueTwoEdgeFixture direct_editable) then throw "RVC Audit direct-fix setup failed for Editable Poly."

        direct_edit_poly_node = Plane \
            name:(uniqueName "RVC_Audit_DirectFix_EditPoly_") \
            width:80.0 \
            length:40.0 \
            widthsegs:2 \
            lengthsegs:1

        convertTo direct_edit_poly_node Editable_Poly
        direct_edit_poly_node.position = [60.0, 440.0, 0.0]
        direct_edit_poly_node.showCage = off
        if not(prepareAuditTrueTwoEdgeFixture direct_edit_poly_node) then throw "RVC Audit direct-fix setup failed for Edit Poly."

        direct_edit_poly_mod = Edit_Poly()
        direct_edit_poly_mod.name = "RVC AUDIT DIRECT FIX EDIT POLY"
        direct_edit_poly_mod.showCage = off
        addModifier direct_edit_poly_node direct_edit_poly_mod
    )

    select direct_editable
    editable_candidates = TwoEdgeVerts.getTwoEdgeVerts direct_editable
    editable_ids = editable_candidates as array
    editable_source = editable_ids[editable_ids.count]
    editable_single = #{}
    editable_single[editable_source] = true
    polyop.setVertSelection direct_editable.baseObject editable_single
    editable_before = polyop.getNumVerts direct_editable.baseObject
    editable_fixed = TwoEdgeVerts.fixSelectedVertex()
    editable_after = polyop.getNumVerts direct_editable.baseObject

    auditCheck \
        (editable_fixed == true and editable_after == (editable_before - 1)) \
        "Editable Poly FIX SELECTED VERT removes exactly one selected true 2-edge vertex"

    editable_stored_ids = TwoEdgeVerts.getStoredCandidateIds()
    auditCheck \
        (classOf editable_stored_ids == Array and editable_stored_ids.count == 0) \
        "Editable Poly direct fix clears stale manual candidate state"

    select direct_edit_poly_node
    max modify mode
    direct_edit_poly_mod.SetPrimaryNode direct_edit_poly_node
    direct_edit_poly_mod.useStackSelection = false
    direct_edit_poly_mod.selectMode = 0
    direct_edit_poly_mod.showCage = off
    modPanel.setCurrentObject direct_edit_poly_mod node:direct_edit_poly_node
    direct_edit_poly_mod.SetEPolySelLevel #Vertex
    subObjectLevel = 1

    edit_candidates = TwoEdgeVerts.getTwoEdgeVerts direct_edit_poly_node edit_poly_mod:direct_edit_poly_mod
    edit_ids = edit_candidates as array
    edit_source = edit_ids[edit_ids.count]
    current_bits = direct_edit_poly_mod.GetSelection #Vertex node:direct_edit_poly_node
    if current_bits == undefined then current_bits = #{}
    if current_bits.numberSet > 0 then direct_edit_poly_mod.Select #Vertex current_bits select:false node:direct_edit_poly_node
    edit_single = #{}
    edit_single[edit_source] = true
    direct_edit_poly_mod.Select #Vertex edit_single select:true node:direct_edit_poly_node
    edit_before = EditPolyMod.GetNumVertices direct_edit_poly_mod node:direct_edit_poly_node
    edit_fixed = TwoEdgeVerts.fixSelectedVertex()
    edit_after = EditPolyMod.GetNumVertices direct_edit_poly_mod node:direct_edit_poly_node

    auditCheck \
        (edit_fixed == true and edit_after == (edit_before - 1)) \
        "Edit Poly FIX SELECTED VERT removes exactly one selected live true 2-edge vertex"

    edit_stored_ids = TwoEdgeVerts.getStoredCandidateIds()
    auditCheck \
        (classOf edit_stored_ids == Array and edit_stored_ids.count == 0) \
        "Edit Poly direct fix clears stale manual candidate state"

    -- return
)


/*
Prints the expected undo order after all numbered audit stages have been attempted.
The scene is intentionally left in its final tested state for visual inspection.
*/
function printAuditUndoOrder =
(
    format "\nUNDO ORDER:\n"
    format "1. Remove One 2-Edge Vert - Edit Poly direct selected fix\n"
    format "2. Remove One 2-Edge Vert - Editable Poly direct selected fix\n"
    format "3. RVC AUDIT 9 - Direct Selected Fix Setup\n"
    format "4. RVC AUDIT 8 - Inner Outer Border Corners\n"
    format "5. Remove 2-Edge Verts Until Stable - Edit Poly\n"
    format "6. Remove 2-Edge Verts Until Stable - Editable Poly\n"
    format "7. RVC AUDIT 7 - Stable Cleanup Setup\n"
    format "8. RVC AUDIT 6 - Exact Duplicate Vertices\n"
    format "9. TEV AUDIT 5 - Classification Separation\n"
    format "10. Remove One 2-Edge Vert - Edit Poly manual fix\n"
    format "11. Remove One 2-Edge Vert - Editable Poly manual fix\n"
    format "12. TEV AUDIT 1 - Setup\n"
    format "\nScene is intentionally left in the final tested state for inspection.\n"
    true
    -- return
)


resetAuditCounters()
tev_audit_ready = loadAuditTool()

if tev_audit_ready then
(
    format "\n=== REDUNDANT VERTEX CLEANER AUDIT | project 0.830 ===\n"

    try
    (
        partOfTest1()
    )
    catch
    (
        auditRecordException "PART 1 - Setup" (getCurrentException())
    )

    try
    (
        partOfTest2()
    )
    catch
    (
        auditRecordException "PART 2 - Editable Poly workflow" (getCurrentException())
    )

    try
    (
        partOfTest3()
    )
    catch
    (
        auditRecordException "PART 3 - Edit Poly workflow" (getCurrentException())
    )

    try
    (
        partOfTest4()
    )
    catch
    (
        auditRecordException "PART 4 - Multi-object SEARCH rejection" (getCurrentException())
    )


    try
    (
        partOfTest5()
    )
    catch
    (
        auditRecordException "PART 5 - Classification separation" (getCurrentException())
    )

    try
    (
        partOfTest6()
    )
    catch
    (
        auditRecordException "PART 6 - Exact duplicate collapse" (getCurrentException())
    )

    try
    (
        partOfTest7()
    )
    catch
    (
        auditRecordException "PART 7 - Fixed-point two-edge cleanup" (getCurrentException())
    )

    try
    (
        partOfTest8()
    )
    catch
    (
        auditRecordException "PART 8 - Inner/outer border-corner split" (getCurrentException())
    )

    try
    (
        partOfTest9()
    )
    catch
    (
        auditRecordException "PART 9 - Direct selected vertex fix" (getCurrentException())
    )

    printAuditUndoOrder()
)

printAuditSummary()
