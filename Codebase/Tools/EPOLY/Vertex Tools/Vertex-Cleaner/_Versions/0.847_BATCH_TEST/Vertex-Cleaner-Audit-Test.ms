/*
Vertex Cleaner Audit 0.847 / project 0.847 audit test.
The audit loads the sibling canonical Vertex-Cleaner.ms itself and verifies the expected release before geometry tests.
*/

global TwoEdgeVerts
global TwoEdgeVertsMain
global EPOLY_TOOLS_RUNTIME_MODE
global tev_audit_editable_node
global tev_audit_edit_poly_node
global tev_audit_edit_poly_mod
global tev_audit_pass_count
global tev_audit_fail_count
global tev_audit_exception_count
global tev_audit_ready
global tev_audit_file_version
global tev_audit_project_version
global two_edge_verts_ui_title

tev_audit_file_version = 0.847
tev_audit_project_version = 0.847

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
function editablePolyVerticesShareEdge node vertex_a vertex_b =
(
    if node == undefined or not(isValidNode node) then return false
    if classOf node.baseObject != Editable_Poly then return false
    if vertex_a < 1 or vertex_b < 1 then return false
    if polyop.getHasDeadStructs node.baseObject != 0 then return false

    poly_value = node.baseObject
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
function getAuditSingleInternalEdge node =
(
    if node == undefined or not(isValidNode node) then return 0
    if classOf node.baseObject != Editable_Poly then return 0

    topology_state = TwoEdgeVerts.ensureCleanEditablePolyTopology node
    if topology_state == #failed or topology_state == #blocked then return 0

    poly_value = node.baseObject
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
    internal_edge = getAuditSingleInternalEdge node
    if internal_edge < 1 then return false

    before_vertex_count = polyop.getNumVerts poly_value
    remove_flag = bit.set 0 30 true
    polyop.setEdgeFlags poly_value #{internal_edge} remove_flag
    node.EditablePoly.remove selLevel:#Edge flag:remove_flag
    update node

    topology_state = TwoEdgeVerts.ensureCleanEditablePolyTopology node
    if topology_state == #failed or topology_state == #blocked then return false

    if polyop.getNumVerts poly_value != before_vertex_count then return false
    if polyop.getNumFaces poly_value != 1 then return false
    if getAuditSingleInternalEdge node != 0 then return false

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
    internal_edge = getAuditSingleInternalEdge node
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

    topology_state = TwoEdgeVerts.ensureCleanEditablePolyTopology node
    if topology_state == #failed or topology_state == #blocked then return false

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

    topology_state = TwoEdgeVerts.ensureCleanEditablePolyTopology node
    if topology_state == #failed or topology_state == #blocked then return false

    after_face_count = polyop.getNumFaces poly_value
    open_edges = polyop.getOpenEdges poly_value

    after_face_count == (before_face_count - 1) and open_edges.numberSet == 16
    -- return
)


/*
Finds an Editable Poly vertex at one exact object-space position.
Exact lookup avoids relying on vertex IDs after a successful weld renumbers topology.
*/
function findEditablePolyVertexAtExactPosition node target_position =
(
    if node == undefined or not(isValidNode node) then return 0
    if classOf node.baseObject != Editable_Poly then return 0
    if polyop.getHasDeadStructs node.baseObject != 0 then return 0

    poly_value = node.baseObject
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
Loads the sibling canonical Tool in library mode and verifies one exact unified 0.847 version across main/backend/frontend.
This prevents stale already-loaded globals or split file/project versions from producing misleading geometry failures.
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
    main_path = package_directory + "Vertex-Cleaner.ms"

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

    if TwoEdgeVertsMain == undefined then
    (
        auditCheck false "TwoEdgeVertsMain exists after canonical Tool load"
        return false
    )

    if TwoEdgeVerts == undefined then
    (
        auditCheck false "TwoEdgeVerts backend exists after canonical Tool load"
        return false
    )

    expected_version = 0.847
    audit_version_ok = tev_audit_file_version == expected_version and tev_audit_project_version == expected_version
    main_version_ok = TwoEdgeVertsMain.file_version == expected_version and TwoEdgeVertsMain.project_version == expected_version
    main_name_ok = getFilenameFile TwoEdgeVertsMain.source_path == "Vertex-Cleaner"
    backend_version_ok = TwoEdgeVerts.file_version == expected_version and TwoEdgeVerts.project_version == expected_version
    frontend_version_ok = TwoEdgeVertsUI != undefined and TwoEdgeVertsUI.file_version == expected_version and TwoEdgeVertsUI.project_version == expected_version
    unified_version_ok = audit_version_ok and main_version_ok and backend_version_ok and frontend_version_ok
    main_backend_name_ok = TwoEdgeVertsMain.backend_file_name == "Vertex-Cleaner-FN.ms"
    main_frontend_name_ok = TwoEdgeVertsMain.frontend_file_name == "Vertex-Cleaner-UI.ms"

    auditCheck \
        main_version_ok \
        ("Loaded current main | file:" + (TwoEdgeVertsMain.file_version as string) + " | project:" + (TwoEdgeVertsMain.project_version as string))

    auditCheck audit_version_ok "Audit file version equals audit project version 0.847"
    auditCheck unified_version_ok "Audit/main/backend/frontend file version equals project version 0.847"
    auditCheck main_name_ok "Canonical main filename is Vertex-Cleaner.ms"
    auditCheck main_backend_name_ok "Main expects canonical backend Vertex-Cleaner-FN.ms"
    auditCheck main_frontend_name_ok "Main expects canonical frontend Vertex-Cleaner-UI.ms"

    auditCheck \
        backend_version_ok \
        ("Loaded current backend | file:" + (TwoEdgeVerts.file_version as string) + " | project:" + (TwoEdgeVerts.project_version as string))

    auditCheck \
        frontend_version_ok \
        ("Loaded current frontend | file:" + (TwoEdgeVertsUI.file_version as string) + " | project:" + (TwoEdgeVertsUI.project_version as string))

    if not(unified_version_ok and main_name_ok and main_backend_name_ok and main_frontend_name_ok) then
    (
        format "AUDIT STOPPED | Expected unified Vertex Cleaner version 0.847: audit/main/backend/frontend file_version == project_version == 0.847. The local Google Drive copy is stale or mis-versioned.\n"
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
    editable_compact_after_fix = polyop.getHasDeadStructs tev_audit_editable_node.baseObject == 0

    auditCheck \
        editable_compact_after_fix \
        "Editable Poly manual fix returns with compact live topology before post-fix ID reads"

    if not(editable_compact_after_fix) then return false

    after_vertex_count = polyop.getNumVerts tev_audit_editable_node.baseObject
    remaining_ids = TwoEdgeVerts.getStoredCandidateIds()
    final_selection = polyop.getVertSelection tev_audit_editable_node.baseObject

    resolved_target_id = findEditablePolyVertexAtExactPosition tev_audit_editable_node target_position_before
    resolved_other_id = findEditablePolyVertexAtExactPosition tev_audit_editable_node other_position_before
    target_position_after = if resolved_target_id > 0 then polyop.getVert tev_audit_editable_node.baseObject resolved_target_id else undefined

    auditCheck \
        (fixed_ok == true) \
        "Editable Poly manual RMB reports a successful fix"

    auditCheck \
        (after_vertex_count == (before_vertex_count - 1)) \
        "Editable Poly manual RMB removes exactly one source vertex"

    auditCheck \
        (editablePolyVerticesShareEdge tev_audit_editable_node resolved_target_id resolved_other_id) \
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
    if changed_selection_bits == undefined then
    (
        auditCheck false "Edit Poly selection read succeeds before manual RMB selection-change regression check"
        return false
    )

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
    force_search_ok = TwoEdgeVerts.selectTwoEdgeVerts force_mode:true
    force_selected_bits = polyop.getVertSelection overlap_editable.baseObject

    auditCheck \
        (force_search_ok and force_selected_bits.numberSet == 2) \
        "Editable Poly FORCE SEARCH keeps only the two near-straight visible-edge vertices"

    filtered_search_ok = TwoEdgeVerts.selectTwoEdgeVerts force_mode:false
    filtered_selected_bits = polyop.getVertSelection overlap_editable.baseObject

    auditCheck \
        (filtered_search_ok and filtered_selected_bits == editable_two_bits) \
        "Editable Poly filtered SEARCH preserves the existing classification result"

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

    select overlap_edit_poly_node
    force_edit_search_ok = TwoEdgeVerts.selectTwoEdgeVerts force_mode:true
    force_edit_selected_bits = overlap_edit_poly_mod.GetSelection #Vertex node:overlap_edit_poly_node

    auditCheck \
        (force_edit_search_ok and force_edit_selected_bits != undefined and force_edit_selected_bits.numberSet == 2) \
        "Edit Poly FORCE SEARCH keeps only the two near-straight visible-edge vertices"

    filtered_edit_search_ok = TwoEdgeVerts.selectTwoEdgeVerts force_mode:false
    filtered_edit_selected_bits = overlap_edit_poly_mod.GetSelection #Vertex node:overlap_edit_poly_node

    auditCheck \
        (filtered_edit_search_ok and filtered_edit_selected_bits != undefined and filtered_edit_selected_bits == edit_two_bits) \
        "Edit Poly filtered SEARCH preserves the existing classification result"

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
    editable_compact_after_collapse = polyop.getHasDeadStructs duplicate_editable.baseObject == 0

    auditCheck \
        editable_compact_after_collapse \
        "Editable Poly duplicate collapse returns with compact topology before fresh ID reads"

    if not(editable_compact_after_collapse) then return false

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
Creates fresh Editable Poly and Edit Poly fixtures and verifies SEARCH RMB processes one captured FORCE set in reverse vertex-ID order.
The operation reuses the same native Remove / fallback mechanism as SELECT \\ REMOVE and must not stop merely because filtered classification differs.
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
    editable_force_selected_ok = TwoEdgeVerts.selectTwoEdgeVerts force_mode:true
    editable_initial = polyop.getVertSelection stable_editable.baseObject
    editable_before = polyop.getNumVerts stable_editable.baseObject
    editable_removed = TwoEdgeVerts.removeTwoEdgeVertsUsingManualWorkflow()
    editable_compact_after_cleanup = polyop.getHasDeadStructs stable_editable.baseObject == 0

    auditCheck \
        editable_compact_after_cleanup \
        "Editable Poly SEARCH RMB FORCE reverse cleanup returns with compact topology before fresh ID reads"

    if not(editable_compact_after_cleanup) then return false

    editable_after = polyop.getNumVerts stable_editable.baseObject
    editable_remaining = TwoEdgeVerts.getTwoEdgeVerts stable_editable

    auditCheck \
        (editable_force_selected_ok and classOf editable_initial == BitArray and editable_initial.numberSet == 2) \
        "Editable Poly stable fixture begins with two FORCE 2-edge candidates"

    auditCheck \
        (editable_removed == 2 and editable_after == (editable_before - 2)) \
        "Editable Poly SEARCH RMB FORCE reverse cleanup removes both live candidates"

    auditCheck \
        (classOf editable_remaining == BitArray and editable_remaining.numberSet == 0) \
        "Editable Poly SEARCH RMB FORCE reverse cleanup finishes with zero true 2-edge candidates"

    select stable_edit_poly_node
    max modify mode
    stable_edit_poly_mod.SetPrimaryNode stable_edit_poly_node
    stable_edit_poly_mod.useStackSelection = false
    stable_edit_poly_mod.selectMode = 0
    stable_edit_poly_mod.showCage = off
    modPanel.setCurrentObject stable_edit_poly_mod node:stable_edit_poly_node
    stable_edit_poly_mod.SetEPolySelLevel #Vertex
    subObjectLevel = 1

    edit_force_selected_ok = TwoEdgeVerts.selectTwoEdgeVerts force_mode:true
    edit_initial = stable_edit_poly_mod.GetSelection #Vertex node:stable_edit_poly_node
    edit_before = EditPolyMod.GetNumVertices stable_edit_poly_mod node:stable_edit_poly_node
    edit_removed = TwoEdgeVerts.removeTwoEdgeVertsUsingManualWorkflow()
    edit_after = EditPolyMod.GetNumVertices stable_edit_poly_mod node:stable_edit_poly_node
    edit_remaining = TwoEdgeVerts.getTwoEdgeVerts stable_edit_poly_node edit_poly_mod:stable_edit_poly_mod

    auditCheck \
        (edit_force_selected_ok and classOf edit_initial == BitArray and edit_initial.numberSet == 2) \
        "Edit Poly stable fixture begins with two FORCE 2-edge candidates"

    auditCheck \
        (edit_removed == 2 and edit_after == (edit_before - 2)) \
        "Edit Poly SEARCH RMB FORCE reverse cleanup removes both live candidates"

    auditCheck \
        (classOf edit_remaining == BitArray and edit_remaining.numberSet == 0) \
        "Edit Poly SEARCH RMB FORCE reverse cleanup finishes with zero live true 2-edge candidates"

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
Exactly one selected true two-edge vertex must disappear while its two surviving visible neighbors remain connected by one edge.
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
    editable_neighbors = TwoEdgeVerts.getVisibleNeighborVertexIds direct_editable editable_source
    editable_target = TwoEdgeVerts.getClosestVisibleNeighborVertexId direct_editable editable_source
    editable_neighbors_ok = classOf editable_neighbors == Array and editable_neighbors.count == 2 and (findItem editable_neighbors editable_target) > 0

    auditCheck \
        editable_neighbors_ok \
        "Editable Poly FIX SELECTED VERT source has exactly two visible neighbors and a valid weld target"

    if not(editable_neighbors_ok) then return false

    editable_other = if editable_neighbors[1] == editable_target then editable_neighbors[2] else editable_neighbors[1]
    editable_target_position_before = polyop.getVert direct_editable.baseObject editable_target
    editable_other_position_before = polyop.getVert direct_editable.baseObject editable_other
    editable_before = polyop.getNumVerts direct_editable.baseObject
    editable_fixed = TwoEdgeVerts.fixSelectedVertex()
    editable_compact_after_direct_fix = polyop.getHasDeadStructs direct_editable.baseObject == 0

    auditCheck \
        editable_compact_after_direct_fix \
        "Editable Poly FIX SELECTED VERT returns with compact topology before fresh ID reads"

    if not(editable_compact_after_direct_fix) then return false

    editable_after = polyop.getNumVerts direct_editable.baseObject

    editable_target_after = findEditablePolyVertexAtExactPosition direct_editable editable_target_position_before
    editable_other_after = findEditablePolyVertexAtExactPosition direct_editable editable_other_position_before
    editable_target_position_after = if editable_target_after > 0 then polyop.getVert direct_editable.baseObject editable_target_after else undefined

    auditCheck \
        (editable_fixed == true and editable_after == (editable_before - 1)) \
        "Editable Poly FIX SELECTED VERT removes exactly one selected true 2-edge vertex"

    auditCheck \
        (editablePolyVerticesShareEdge direct_editable editable_target_after editable_other_after) \
        "Editable Poly FIX SELECTED VERT keeps one edge between the two surviving source neighbors"

    auditCheck \
        (editable_target_position_after != undefined and editable_target_position_after == editable_target_position_before) \
        "Editable Poly FIX SELECTED VERT keeps the target neighbor at its exact original position"

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
    if current_bits == undefined then
    (
        auditCheck false "Edit Poly direct-fix setup can read the current vertex selection"
        return false
    )
    if current_bits.numberSet > 0 then direct_edit_poly_mod.Select #Vertex current_bits select:false node:direct_edit_poly_node
    edit_single = #{}
    edit_single[edit_source] = true
    direct_edit_poly_mod.Select #Vertex edit_single select:true node:direct_edit_poly_node
    edit_neighbors = TwoEdgeVerts.getVisibleNeighborVertexIds direct_edit_poly_node edit_source edit_poly_mod:direct_edit_poly_mod
    edit_target = TwoEdgeVerts.getClosestVisibleNeighborVertexId direct_edit_poly_node edit_source edit_poly_mod:direct_edit_poly_mod
    edit_neighbors_ok = classOf edit_neighbors == Array and edit_neighbors.count == 2 and (findItem edit_neighbors edit_target) > 0

    auditCheck \
        edit_neighbors_ok \
        "Edit Poly FIX SELECTED VERT source has exactly two visible neighbors and a valid weld target"

    if not(edit_neighbors_ok) then return false

    edit_other = if edit_neighbors[1] == edit_target then edit_neighbors[2] else edit_neighbors[1]
    edit_target_position_before = EditPolyMod.GetVertex direct_edit_poly_mod edit_target node:direct_edit_poly_node
    edit_other_position_before = EditPolyMod.GetVertex direct_edit_poly_mod edit_other node:direct_edit_poly_node
    edit_before = EditPolyMod.GetNumVertices direct_edit_poly_mod node:direct_edit_poly_node
    edit_fixed = TwoEdgeVerts.fixSelectedVertex()
    edit_after = EditPolyMod.GetNumVertices direct_edit_poly_mod node:direct_edit_poly_node

    edit_target_after = findEditPolyVertexAtExactPosition direct_edit_poly_node direct_edit_poly_mod edit_target_position_before
    edit_other_after = findEditPolyVertexAtExactPosition direct_edit_poly_node direct_edit_poly_mod edit_other_position_before
    edit_target_position_after = if edit_target_after > 0 then EditPolyMod.GetVertex direct_edit_poly_mod edit_target_after node:direct_edit_poly_node else undefined

    auditCheck \
        (edit_fixed == true and edit_after == (edit_before - 1)) \
        "Edit Poly FIX SELECTED VERT removes exactly one selected live true 2-edge vertex"

    auditCheck \
        (editPolyVerticesShareEdge direct_edit_poly_node direct_edit_poly_mod edit_target_after edit_other_after) \
        "Edit Poly FIX SELECTED VERT keeps one edge between the two surviving source neighbors"

    auditCheck \
        (edit_target_position_after != undefined and edit_target_position_after == edit_target_position_before) \
        "Edit Poly FIX SELECTED VERT keeps the target neighbor at its exact original position"

    edit_stored_ids = TwoEdgeVerts.getStoredCandidateIds()
    auditCheck \
        (classOf edit_stored_ids == Array and edit_stored_ids.count == 0) \
        "Edit Poly direct fix clears stale manual candidate state"

    -- return
)


/*
Verifies true two-edge detector status keeps a valid empty result distinct from detector failure.
A clean Edit Poly box must report zero candidates with success, while an invalid detector target must report failure with the same empty BitArray shape.
*/
function partOfTest10 =
(
    detector_node = undefined
    detector_mod = undefined

    undo "RVC AUDIT 10 - Detector Status Setup" on
    (
        detector_node = Box \
            name:(uniqueName "RVC_Audit_DetectorStatus_") \
            width:40.0 \
            length:40.0 \
            height:40.0

        convertTo detector_node Editable_Poly
        detector_node.position = [0.0, 540.0, 20.0]
        detector_node.showCage = off

        detector_mod = Edit_Poly()
        detector_mod.name = "RVC AUDIT DETECTOR STATUS"
        detector_mod.showCage = off
        addModifier detector_node detector_mod
    )

    select detector_node
    max modify mode
    detector_mod.SetPrimaryNode detector_node
    detector_mod.useStackSelection = false
    detector_mod.selectMode = 0
    detector_mod.showCage = off
    modPanel.setCurrentObject detector_mod node:detector_node
    detector_mod.SetEPolySelLevel #Vertex
    subObjectLevel = 1

    valid_empty_bits = TwoEdgeVerts.getTwoEdgeVerts detector_node edit_poly_mod:detector_mod
    valid_empty_ok = TwoEdgeVerts.wasLastTwoEdgeDetectionSuccessful()

    auditCheck \
        (classOf valid_empty_bits == BitArray and valid_empty_bits.numberSet == 0 and valid_empty_ok) \
        "Edit Poly valid zero-candidate detection reports an empty BitArray with successful detector state"

    failed_bits = TwoEdgeVerts.findTwoEdgeVertsOnEditPoly detector_node undefined quiet_mode:true
    failed_state = TwoEdgeVerts.wasLastTwoEdgeDetectionSuccessful()

    auditCheck \
        (classOf failed_bits == BitArray and failed_bits.numberSet == 0 and not(failed_state)) \
        "Edit Poly failed detector attempt reports an empty BitArray with failed detector state"

    recovered_bits = TwoEdgeVerts.getTwoEdgeVerts detector_node edit_poly_mod:detector_mod
    recovered_state = TwoEdgeVerts.wasLastTwoEdgeDetectionSuccessful()

    auditCheck \
        (classOf recovered_bits == BitArray and recovered_bits.numberSet == 0 and recovered_state) \
        "Edit Poly detector success state recovers after a later valid detection"

    true
    -- return
)


/*
Verifies the canonical main entry can execute in standalone mode and leaves a real open dialog.
This is the regression test for direct Run Script startup after the package rename.
*/
function partOfTest11 =
(
    previous_runtime_mode = EPOLY_TOOLS_RUNTIME_MODE
    EPOLY_TOOLS_RUNTIME_MODE = #standalone
    run_ok = false
    run_error = undefined

    try
    (
        run_ok = TwoEdgeVertsMain.run()
    )
    catch
    (
        run_error = getCurrentException()
    )

    dialog_open = TwoEdgeVerts_UI != undefined and TwoEdgeVerts_UI.inDialog
    tool_title_ok = false
    title_version_ok = false
    docking_registered = false
    dock_state_ok = false

    if dialog_open then
    (
        tool_title_ok = TwoEdgeVerts_UI.btn_tool_title != undefined and TwoEdgeVerts_UI.btn_tool_title.Text == "Vertex Cleaner"
        title_version_ok = TwoEdgeVertsUI != undefined and two_edge_verts_ui_title == ("Vertex Cleaner | v" + (TwoEdgeVertsUI.project_version as string)) and TwoEdgeVertsUI.file_version == TwoEdgeVertsUI.project_version
        docking_registered = TwoEdgeVerts_UI.dialogBar

        if docking_registered then
        (
            dock_state = undefined

            try
            (
                dock_state = cui.getDockState TwoEdgeVerts_UI
            )
            catch
            (
                exception_text = getCurrentException()
                format "AUDIT DETAIL | Dock state read failed: %\n" exception_text
                dock_state = undefined
            )

            dock_state_ok = dock_state == #cui_floatable or dock_state == #cui_dock_left or dock_state == #cui_dock_right
        )
    )

    if dialog_open and TwoEdgeVertsUI != undefined then
    (
        TwoEdgeVertsUI.hideUI()
    )

    EPOLY_TOOLS_RUNTIME_MODE = previous_runtime_mode

    auditCheck (run_error == undefined) "Standalone canonical main executes without exception"
    auditCheck run_ok "Standalone canonical main reports startup success"
    auditCheck dialog_open "Standalone canonical main opens Vertex Cleaner dialog"
    auditCheck tool_title_ok "Standalone UI exposes the .NET Vertex Cleaner tool title restart button"
    auditCheck title_version_ok "Standalone rollout title version equals frontend file/project version"
    auditCheck docking_registered "Standalone UI is registered as a CUI dialog bar"
    auditCheck dock_state_ok "Standalone UI dock state is floating, left, or right only"

    run_error == undefined and run_ok and dialog_open and tool_title_ok and title_version_ok and docking_registered and dock_state_ok
    -- return
)


/*
Verifies the controlled Editable Poly dead-topology synchronization boundary and cache invalidation contract.
The fixture uses one isolated vertex so deletion can expose a dead slot without requiring any hardcoded production component ID.
*/
function partOfTest12 =
(
    dirty_node = undefined
    blocked_node = undefined
    blocked_mod = undefined

    undo "RVC AUDIT 12 - Dead Topology Sync" on
    (
        dirty_node = mesh \
            name:(uniqueName "RVC_Audit_DeadTopology_") \
            vertices:#([0,0,0], [20,0,0], [0,20,0], [40,40,0]) \
            faces:#([1,2,3])

        convertTo dirty_node Editable_Poly
        dirty_node.position = [-60.0, 620.0, 0.0]
        dirty_node.showCage = off

        dirty_base = dirty_node.baseObject
        delete_vertex = polyop.getNumVerts dirty_base
        polyop.deleteVerts dirty_base #{delete_vertex}
        update dirty_node

        dead_before_sync = polyop.getHasDeadStructs dirty_base

        TwoEdgeVerts.manual_remove_node = dirty_node
        TwoEdgeVerts.manual_remove_target_type = #EditablePoly
        TwoEdgeVerts.manual_remove_modifier = undefined
        TwoEdgeVerts.manual_remove_vertex_ids = #(1)
        TwoEdgeVerts.manual_remove_candidate_id = 1

        sync_state = TwoEdgeVerts.ensureCleanEditablePolyTopology dirty_node
        dead_after_sync = polyop.getHasDeadStructs dirty_base
        cached_ids_after_sync = TwoEdgeVerts.getStoredCandidateIds()

        if dead_before_sync != 0 then
        (
            auditCheck \
                (sync_state == #collapsed) \
                "Editable Poly dead topology synchronizes through one controlled collapse boundary"

            auditCheck \
                (dead_after_sync == 0) \
                "Editable Poly collapse boundary leaves no dead vertex/edge/face structures"

            auditCheck \
                (classOf cached_ids_after_sync == Array and cached_ids_after_sync.count == 0) \
                "Editable Poly collapse boundary invalidates cached manual vertex IDs"
        )
        else
        (
            auditCheck \
                (sync_state == #clean and dead_after_sync == 0) \
                "Editable Poly runtime compacted the isolated deletion immediately; clean synchronization remains non-destructive"
        )

        blocked_node = mesh \
            name:(uniqueName "RVC_Audit_DeadTopology_Blocked_") \
            vertices:#([0,0,0], [20,0,0], [0,20,0], [40,40,0]) \
            faces:#([1,2,3])

        convertTo blocked_node Editable_Poly
        blocked_node.position = [60.0, 620.0, 0.0]
        blocked_node.showCage = off

        blocked_base = blocked_node.baseObject
        blocked_delete_vertex = polyop.getNumVerts blocked_base
        polyop.deleteVerts blocked_base #{blocked_delete_vertex}
        update blocked_node

        blocked_mod = Edit_Poly()
        blocked_mod.name = "RVC AUDIT DEAD TOPOLOGY EDIT POLY GUARD"
        blocked_mod.showCage = off
        addModifier blocked_node blocked_mod

        blocked_dead_before = polyop.getHasDeadStructs blocked_base
        blocked_state = TwoEdgeVerts.ensureCleanEditablePolyTopology blocked_node
        blocked_dead_after = polyop.getHasDeadStructs blocked_base

        if blocked_dead_before != 0 then
        (
            auditCheck \
                (blocked_state == #blocked) \
                "Editable Poly dead-topology collapse is blocked when an Edit Poly modifier exists above the base"

            auditCheck \
                (blocked_dead_after == blocked_dead_before) \
                "Blocked Editable Poly synchronization does not reindex the base underneath Edit Poly"
        )
        else
        (
            auditCheck \
                (blocked_state == #clean and blocked_dead_after == 0) \
                "Edit Poly guard fixture was already compact, so synchronization performs no base collapse"
        )
    )

    true
    -- return
)


/*
Verifies that FORCE SEARCH uses the explicit 15-degree maximum deviation from a straight continuation.
A 10-degree bend must pass while a 20-degree bend must fail on both Editable Poly and Edit Poly.
*/
function partOfTest13 =
(
    force_angle_editable = undefined
    force_angle_edit_poly_node = undefined
    force_angle_edit_poly_mod = undefined

    undo "RVC AUDIT 13 - FORCE 15 Degree Limit" on
    (
        force_angle_editable = mesh \
            name:(uniqueName "RVC_Audit_ForceAngle_Editable_") \
            vertices:#( \
                [0.0,0.0,0.0], [-10.0,0.0,0.0], [10.0,1.7632698,0.0], \
                [40.0,0.0,0.0], [30.0,0.0,0.0], [50.0,3.6397023,0.0]) \
            faces:#([1,2,3], [4,5,6])

        convertTo force_angle_editable Editable_Poly
        force_angle_editable.position = [-60.0, 360.0, 0.0]
        force_angle_editable.showCage = off

        force_angle_edit_poly_node = mesh \
            name:(uniqueName "RVC_Audit_ForceAngle_EditPoly_") \
            vertices:#( \
                [0.0,0.0,0.0], [-10.0,0.0,0.0], [10.0,1.7632698,0.0], \
                [40.0,0.0,0.0], [30.0,0.0,0.0], [50.0,3.6397023,0.0]) \
            faces:#([1,2,3], [4,5,6])

        convertTo force_angle_edit_poly_node Editable_Poly
        force_angle_edit_poly_node.position = [60.0, 360.0, 0.0]
        force_angle_edit_poly_node.showCage = off

        force_angle_edit_poly_mod = Edit_Poly()
        force_angle_edit_poly_mod.name = "RVC AUDIT FORCE ANGLE EDIT POLY"
        force_angle_edit_poly_mod.showCage = off
        addModifier force_angle_edit_poly_node force_angle_edit_poly_mod
    )

    select force_angle_editable
    editable_force_ok = TwoEdgeVerts.selectTwoEdgeVerts force_mode:true
    editable_force_bits = polyop.getVertSelection force_angle_editable.baseObject

    auditCheck \
        (editable_force_ok and editable_force_bits == #{1}) \
        "Editable Poly FORCE SEARCH accepts 10-degree deviation and rejects 20-degree deviation"

    select force_angle_edit_poly_node
    max modify mode
    force_angle_edit_poly_mod.SetPrimaryNode force_angle_edit_poly_node
    force_angle_edit_poly_mod.useStackSelection = false
    force_angle_edit_poly_mod.selectMode = 0
    force_angle_edit_poly_mod.showCage = off
    modPanel.setCurrentObject force_angle_edit_poly_mod node:force_angle_edit_poly_node
    force_angle_edit_poly_mod.SetEPolySelLevel #Vertex
    subObjectLevel = 1

    edit_force_ok = TwoEdgeVerts.selectTwoEdgeVerts force_mode:true
    edit_force_bits = force_angle_edit_poly_mod.GetSelection #Vertex node:force_angle_edit_poly_node

    auditCheck \
        (edit_force_ok and edit_force_bits != undefined and edit_force_bits == #{1}) \
        "Edit Poly FORCE SEARCH accepts 10-degree deviation and rejects 20-degree deviation"

    true
    -- return
)


/*
Verifies timer-equivalent vertex-info reads are non-destructive and SELECT \ REMOVE LMB/RMB rebuild their own fresh manual state without SEARCH RMB.
The dirty fixture keeps its dead-structure state and stored IDs unchanged; the clean fixture resets manual state, then runs LMB arm and RMB remove directly.
*/
function partOfTest14 =
(
    info_dirty_node = undefined
    manual_node = undefined

    undo "RVC AUDIT 14 - UI Manual Workflow Regression" on
    (
        info_dirty_node = mesh \
            name:(uniqueName "RVC_Audit_InfoReadOnly_") \
            vertices:#([0,0,0], [20,0,0], [0,20,0], [40,40,0]) \
            faces:#([1,2,3])

        convertTo info_dirty_node Editable_Poly
        info_dirty_node.position = [-60.0, 700.0, 0.0]
        info_dirty_node.showCage = off

        info_dirty_base = info_dirty_node.baseObject
        info_delete_vertex = polyop.getNumVerts info_dirty_base
        polyop.deleteVerts info_dirty_base #{info_delete_vertex}
        update info_dirty_node

        select info_dirty_node
        info_dead_before = polyop.getHasDeadStructs info_dirty_base

        TwoEdgeVerts.manual_remove_node = info_dirty_node
        TwoEdgeVerts.manual_remove_target_type = #EditablePoly
        TwoEdgeVerts.manual_remove_modifier = undefined
        TwoEdgeVerts.manual_remove_vertex_ids = #(1)
        TwoEdgeVerts.manual_remove_candidate_id = 1

        info_counts = TwoEdgeVerts.getSelectedVertexCounts()
        info_dead_after = polyop.getHasDeadStructs info_dirty_base
        info_stored_after = TwoEdgeVerts.getStoredCandidateIds()

        auditCheck \
            (info_dead_after == info_dead_before) \
            "Vertex-info refresh never collapses or otherwise mutates Editable Poly dead topology"

        auditCheck \
            (arraysMatchByValue info_stored_after #(1)) \
            "Vertex-info refresh never invalidates stored SELECT \\ REMOVE candidate IDs"

        if info_dead_before != 0 then
        (
            auditCheck \
                (classOf info_counts == Array and info_counts.count == 0) \
                "Vertex-info refresh refuses unsafe Editable Poly component counts while dead topology exists"
        )
        else
        (
            auditCheck \
                (classOf info_counts == Array and info_counts.count == 3) \
                "Vertex-info refresh returns normal counts when the runtime already compacted the fixture"
        )

        TwoEdgeVerts.resetManualRemoveState()

        manual_node = Plane \
            name:(uniqueName "RVC_Audit_UIManual_") \
            width:80.0 \
            length:40.0 \
            widthsegs:2 \
            lengthsegs:1

        convertTo manual_node Editable_Poly
        manual_node.position = [60.0, 700.0, 0.0]
        manual_node.showCage = off

        if not(prepareAuditTrueTwoEdgeFixture manual_node) then throw "RVC Audit UI manual workflow setup failed."

        select manual_node
        manual_before_count = polyop.getNumVerts manual_node.baseObject
        TwoEdgeVerts.resetManualRemoveState()

        info_counts = TwoEdgeVerts.getSelectedVertexCounts()
        auditCheck \
            (classOf info_counts == Array and info_counts.count == 3) \
            "Timer-equivalent vertex-info refresh remains readable before manual LMB"

        manual_selected_ok = TwoEdgeVerts.selectNextManualRemoveCandidate()
        manual_armed_id = TwoEdgeVerts.manual_remove_candidate_id
        manual_stored_ids = TwoEdgeVerts.getStoredCandidateIds()

        auditCheck \
            (manual_selected_ok and manual_armed_id > 0 and classOf manual_stored_ids == Array and manual_stored_ids.count > 0) \
            "SELECT \\ REMOVE LMB performs a fresh filtered search, stores current candidates, and arms one candidate"

        manual_fixed_ok = TwoEdgeVerts.fixManualRemoveCandidate()
        manual_after_count = polyop.getNumVerts manual_node.baseObject

        auditCheck \
            (manual_fixed_ok and manual_after_count == (manual_before_count - 1)) \
            "SELECT \\ REMOVE RMB removes the candidate armed by LMB without SEARCH RMB"
    )

    true
    -- return
)


/*
Prints the expected undo order after all numbered audit stages have been attempted.
The scene is intentionally left in its final tested state for visual inspection.
*/
function printAuditUndoOrder =
(
    format "\nUNDO ORDER:\n"
    format "1. Remove One 2-Edge Vert - Editable Poly UI manual regression\n"
    format "2. RVC AUDIT 14 - UI Manual Workflow Regression\n"
    format "3. RVC AUDIT 13 - FORCE 15 Degree Limit\n"
    format "4. RVC AUDIT 12 - Dead Topology Sync\n"
    format "5. RVC AUDIT 10 - Detector Status Setup\n"
    format "6. Remove One 2-Edge Vert - Edit Poly direct selected fix\n"
    format "7. Remove One 2-Edge Vert - Editable Poly direct selected fix\n"
    format "8. RVC AUDIT 9 - Direct Selected Fix Setup\n"
    format "9. RVC AUDIT 8 - Inner Outer Border Corners\n"
    format "10. SEARCH RMB FORCE batch - Edit Poly (one batch undo record)\n"
    format "11. SEARCH RMB FORCE batch - Editable Poly (one batch undo record)\n"
    format "12. RVC AUDIT 7 - Stable Cleanup Setup\n"
    format "13. RVC AUDIT 6 - Exact Duplicate Vertices\n"
    format "14. TEV AUDIT 5 - Classification Separation\n"
    format "15. Remove One 2-Edge Vert - Edit Poly manual fix\n"
    format "16. Remove One 2-Edge Vert - Editable Poly manual fix\n"
    format "17. TEV AUDIT 1 - Setup\n"
    format "\nScene is intentionally left in the final tested state for inspection.\n"
    true
    -- return
)


resetAuditCounters()
tev_audit_ready = loadAuditTool()

if tev_audit_ready then
(
    format "\n=== VERTEX CLEANER AUDIT | project 0.847 ===\n"

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

    try
    (
        partOfTest10()
    )
    catch
    (
        auditRecordException "PART 10 - Detector success/failure state" (getCurrentException())
    )

    try
    (
        partOfTest11()
    )
    catch
    (
        auditRecordException "PART 11 - Standalone dialog startup" (getCurrentException())
    )

    try
    (
        partOfTest12()
    )
    catch
    (
        auditRecordException "PART 12 - Editable Poly dead topology synchronization" (getCurrentException())
    )

    try
    (
        partOfTest13()
    )
    catch
    (
        auditRecordException "PART 13 - FORCE 15-degree angle limit" (getCurrentException())
    )

    try
    (
        partOfTest14()
    )
    catch
    (
        auditRecordException "PART 14 - UI manual workflow regression" (getCurrentException())
    )

    printAuditUndoOrder()
)

printAuditSummary()
