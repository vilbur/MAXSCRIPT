/* Missing Loop Rebuilder
   Version 0.002 | Project 1.126 */

global missingLoopRebuilderVersion = 0.002
global missingLoopRebuilderProjectVersion = 1.126

struct MissingLoopRebuilder_v
(
    /* Returns true when the node can be processed as Editable Poly.
       Edit Poly stack support is prepared for later repair stages. */
    function isSupportedNode node_v =
    (
        if isValidNode node_v then
        (
            if (classOf node_v.baseObject == Editable_Poly) then true else false
        )
        else false
        -- return
    ),

    /* Returns all open-border vertices on an Editable Poly node.
       These vertices are excluded from internal missing-loop candidates. */
    function getBorderVerts node_v =
    (
        border_verts = #{}
        if isSupportedNode node_v then
        (
            edge_count = polyop.getNumEdges node_v
            for edge_index = 1 to edge_count do
            (
                edge_faces = polyop.getFacesUsingEdge node_v edge_index
                if edge_faces.numberSet == 1 then
                (
                    edge_verts = polyop.getVertsUsingEdge node_v edge_index
                    border_verts += edge_verts
                )
            )
        )
        border_verts
        -- return
    ),

    /* Creates a quad grid used to test missing loop reconstruction.
       The result is converted to Editable Poly and its cage is disabled. */
    function createTestGrid x_segments:6 y_segments:6 =
    (
        test_node = plane length:120 width:120 lengthsegs:y_segments widthsegs:x_segments
        test_node.name = "MLR_TEST"
        convertToPoly test_node
        test_node.showCage = off
        test_node
        -- return
    ),

    /* Removes internal grid edges to create controlled missing-loop cases.
       Loop count removes consecutive vertical separators; ring count removes consecutive horizontal separators. */
    function makeMissingPattern node_v missing_loop_count:1 missing_ring_count:0 =
    (
        if isSupportedNode node_v then
        (
            x_segments = 6
            y_segments = 6
            center_x = 3
            center_y = 3
            remove_edges = #{}

            edge_count = polyop.getNumEdges node_v
            for edge_index = 1 to edge_count do
            (
                edge_verts = polyop.getEdgeVerts node_v edge_index
                p1 = polyop.getVert node_v edge_verts[1]
                p2 = polyop.getVert node_v edge_verts[2]
                mid_p = (p1 + p2) * 0.5
                edge_vec = p2 - p1

                if (abs edge_vec.y > abs edge_vec.x) and missing_loop_count > 0 then
                (
                    if (abs mid_p.x < 1.0) and (abs mid_p.y <= (missing_loop_count * 10.0)) then remove_edges[edge_index] = true
                )

                if (abs edge_vec.x > abs edge_vec.y) and missing_ring_count > 0 then
                (
                    if (abs mid_p.y < 1.0) and (abs mid_p.x <= (missing_ring_count * 10.0)) then remove_edges[edge_index] = true
                )
            )

            if remove_edges.numberSet > 0 then polyop.deleteEdges node_v remove_edges delIsoVerts:false
            update node_v
        )
        node_v
        -- return
    ),

    /* Builds the current controlled test object from loop/ring counts.
       Counts affect only test generation and are not repair hints. */
    function buildTest missing_loop_count:1 missing_ring_count:0 =
    (
        undo "MLR Create Test" on
        (
            test_node = createTestGrid()
            makeMissingPattern test_node missing_loop_count:missing_loop_count missing_ring_count:missing_ring_count
            select test_node
            test_node
        )
        -- return
    ),

    /* Finds internal n-gon faces that can contain a missing loop segment.
       Border-connected vertices are ignored by candidate detection. */
    function findCandidateFaces node_v =
    (
        candidate_faces = #{}
        if isSupportedNode node_v then
        (
            border_verts = getBorderVerts node_v
            face_count = polyop.getNumFaces node_v
            for face_index = 1 to face_count do
            (
                face_verts = polyop.getFaceVerts node_v face_index
                if face_verts.count >= 5 then
                (
                    has_border = false
                    for vert_index in face_verts while not has_border do
                    (
                        if border_verts[vert_index] then has_border = true
                    )
                    if not has_border then candidate_faces[face_index] = true
                )
            )
        )
        candidate_faces
        -- return
    ),

    /* Selects candidate n-gons for the first reconstruction prototype.
       Actual ring tracing and edge recreation is the next implementation stage. */
    function selectCandidates node_v =
    (
        candidate_faces = findCandidateFaces node_v
        if isSupportedNode node_v then
        (
            polyop.setFaceSelection node_v candidate_faces
            subObjectLevel = 4
            update node_v
        )
        candidate_faces
        -- return
    ),

    on create do
    (
    )
)

global MissingLoopRebuilder = MissingLoopRebuilder_v()

try(destroyDialog missingLoopRebuilderRollout)catch()

rollout missingLoopRebuilderRollout ("Missing Loop Rebuilder | v" + (missingLoopRebuilderProjectVersion as string)) width:250
(
    spinner spn_missing_loop "Missing Count Loop:" range:[0,4,1] type:#integer fieldwidth:55
    spinner spn_missing_ring "Missing Count Ring:" range:[0,4,0] type:#integer fieldwidth:55
    button btn_create_test "Create Test" width:220 height:28 tooltip:"LMB: Create an Editable Poly grid with controlled missing edges."
    button btn_find "Find Missing" width:220 height:28 tooltip:"LMB: Select internal n-gons that can contain missing loop segments."

    on btn_create_test pressed do
    (
        MissingLoopRebuilder.buildTest missing_loop_count:spn_missing_loop.value missing_ring_count:spn_missing_ring.value
    )

    on btn_find pressed do
    (
        if selection.count == 1 and MissingLoopRebuilder.isSupportedNode selection[1] then
        (
            MissingLoopRebuilder.selectCandidates selection[1]
        )
        else
        (
            format "Missing Loop Rebuilder: select one Editable Poly object.\n"
        )
    )

    on missingLoopRebuilderRollout open do
    (
        if selection.count == 1 and MissingLoopRebuilder.isSupportedNode selection[1] then selection[1].showCage = off
    )
)

createDialog missingLoopRebuilderRollout

/* Test 1 creates a single missing edge case.
   Inspect the resulting internal n-gon visually. */
function partOfTest1() =
(
    MissingLoopRebuilder.buildTest missing_loop_count:1 missing_ring_count:0
    -- return
)

/* Test 2 creates two connected missing edges in loop direction.
   The test leaves the scene in the generated state. */
function partOfTest2() =
(
    MissingLoopRebuilder.buildTest missing_loop_count:2 missing_ring_count:0
    -- return
)

/* Test 3 creates combined loop and ring missing-edge patterns.
   Candidate faces are selected for visual inspection. */
function partOfTest3() =
(
    test_node = MissingLoopRebuilder.buildTest missing_loop_count:2 missing_ring_count:2
    MissingLoopRebuilder.selectCandidates test_node
    format "MLR test complete. Undo order: candidate selection, combined test creation, loop test creation, single-edge test creation.\n"
    -- return
)

-- Test execution queue is intentionally disabled for production loading.
-- partOfTest1()
-- partOfTest2()
-- partOfTest3()
