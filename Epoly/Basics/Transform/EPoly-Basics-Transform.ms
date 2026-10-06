/* EPoly-Basics-Transform.ms
   File version: 0.01
   Project version: 0.34

   Tests Vertex, Edge, and Face sub-object transforms on:
   - Editable_Poly base objects through polyop.
   - Edit_Poly modifiers through MoveSelection / RotateSelection / ScaleSelection.

   The test creates three matched object pairs and checks that both routes
   produce matching geometry after Move, Rotate, and Scale operations.
*/

global epoly_tools_project_version
global epoly_basics_transform_file_version = 0.01
global epoly_basics_transform_project_version = 0.34
global epoly_transform_test_pairs = #()
global epoly_transform_pair_offset = [100.0, 0.0, 0.0]
global epoly_transform_test_tolerance = 0.001

if epoly_tools_project_version == undefined or epoly_tools_project_version < epoly_basics_transform_project_version then
(
    epoly_tools_project_version = epoly_basics_transform_project_version
)

/*
Returns the global sub-object level for the supplied EPoly level.
Supports Vertex, Edge, and Face.
*/
function getTransformSubObjectLevel level_symbol =
(
    level_value = case level_symbol of
    (
        #Vertex: 1
        #Edge: 2
        #Face: 4
        default: 0
    )

    level_value -- return
)

/*
Returns the Edit Poly transform operation for the supplied EPoly level.
Uses the documented level-specific transform operation names.
*/
function getEditPolyTransformOperation level_symbol =
(
    operation_value = case level_symbol of
    (
        #Vertex: #TransformVertex
        #Edge: #TransformEdge
        #Face: #TransformFace
        default: undefined
    )

    operation_value -- return
)

/*
Builds a one-component BitArray from one sub-object index.
The returned BitArray is suitable for polyop and Edit Poly selection APIs.
*/
function makeSingleBitArray component_id =
(
    component_bits = #{}

    if component_id > 0 then
    (
        component_bits[component_id] = true
    )

    component_bits -- return
)

/*
Finds the highest Editable Poly vertex by local Z position.
The first vertex at the maximum Z value is used when several match.
*/
function findTopVertexId poly_object =
(
    best_vertex_id = 0
    best_z = -1.0e30
    vertex_count = polyop.getNumVerts poly_object

    for vertex_id = 1 to vertex_count do
    (
        vertex_position = polyop.getVert poly_object vertex_id

        if vertex_position.z > best_z then
        (
            best_z = vertex_position.z
            best_vertex_id = vertex_id
        )
    )

    best_vertex_id -- return
)

/*
Finds the highest Editable Poly edge by the midpoint Z of its endpoints.
The first edge at the maximum Z value is used when several match.
*/
function findTopEdgeId poly_object =
(
    best_edge_id = 0
    best_z = -1.0e30
    edge_count = polyop.getNumEdges poly_object

    for edge_id = 1 to edge_count do
    (
        edge_vertices = polyop.getEdgeVerts poly_object edge_id
        position_a = polyop.getVert poly_object edge_vertices[1]
        position_b = polyop.getVert poly_object edge_vertices[2]
        midpoint_z = (position_a.z + position_b.z) * 0.5

        if midpoint_z > best_z then
        (
            best_z = midpoint_z
            best_edge_id = edge_id
        )
    )

    best_edge_id -- return
)

/*
Finds the highest Editable Poly face by its local face-center Z position.
The first face at the maximum Z value is used when several match.
*/
function findTopFaceId poly_object =
(
    best_face_id = 0
    best_z = -1.0e30
    face_count = polyop.getNumFaces poly_object

    for face_id = 1 to face_count do
    (
        face_center = polyop.getFaceCenter poly_object face_id

        if face_center.z > best_z then
        (
            best_z = face_center.z
            best_face_id = face_id
        )
    )

    best_face_id -- return
)

/*
Resolves Vertex, Edge, or Face selection to the affected Editable Poly vertices.
Topology is not changed anywhere in this test, so these vertex IDs stay stable.
*/
function getEditablePolyTransformVertices poly_object level_symbol selection_bits =
(
    vertex_bits = case level_symbol of
    (
        #Vertex: copy selection_bits
        #Edge: polyop.getVertsUsingEdge poly_object selection_bits
        #Face: polyop.getVertsUsingFace poly_object selection_bits
        default: #{}
    )

    vertex_bits -- return
)

/*
Calculates the arithmetic center of supplied Editable Poly vertices.
Positions are read in the Editable Poly object's local coordinate system.
*/
function getEditablePolyVertexCenter poly_object vertex_bits =
(
    center_value = [0.0, 0.0, 0.0]
    vertex_count = vertex_bits.numberSet

    if vertex_count > 0 then
    (
        for vertex_id in vertex_bits do
        (
            center_value += polyop.getVert poly_object vertex_id
        )

        center_value = center_value / vertex_count
    )

    center_value -- return
)

/*
Calculates the arithmetic center of supplied vertices through an Edit Poly modifier.
The node parameter keeps modifier-instance geometry reads unambiguous.
*/
function getEditPolyVertexCenter node_value modifier_value vertex_bits =
(
    center_value = [0.0, 0.0, 0.0]
    vertex_count = vertex_bits.numberSet

    if vertex_count > 0 then
    (
        for vertex_id in vertex_bits do
        (
            center_value += modifier_value.GetVertex vertex_id node:node_value
        )

        center_value = center_value / vertex_count
    )

    center_value -- return
)

/*
Writes a Vertex, Edge, or Face selection to an Editable Poly base object.
Only polyop selection methods are used for the base Editable Poly path.
*/
function setEditablePolyTransformSelection poly_object level_symbol selection_bits =
(
    result_value = true

    case level_symbol of
    (
        #Vertex: polyop.setVertSelection poly_object selection_bits
        #Edge: polyop.setEdgeSelection poly_object selection_bits
        #Face: polyop.setFaceSelection poly_object selection_bits
        default: result_value = false
    )

    result_value -- return
)

/*
Activates one Edit Poly modifier at the requested sub-object level.
The modifier uses its own selection and keeps cage display disabled.
*/
function prepareEditPolyTransformModifier node_value modifier_value level_symbol =
(
    result_value = false
    sub_object_level = getTransformSubObjectLevel level_symbol

    if isValidNode node_value and modifier_value != undefined and sub_object_level > 0 then
    (
        select node_value
        max modify mode

        modifier_value.SetPrimaryNode node_value
        modifier_value.useStackSelection = false
        modifier_value.selectMode = 0
        modifier_value.showCage = off

        modPanel.setCurrentObject modifier_value node:node_value
        modifier_value.SetEPolySelLevel level_symbol
        subObjectLevel = sub_object_level

        result_value = true
    )

    result_value -- return
)

/*
Writes a visible Vertex, Edge, or Face selection to an Edit Poly modifier.
The modifier selection API is kept separate from the base polyop path.
*/
function setEditPolyTransformSelection node_value modifier_value level_symbol selection_bits =
(
    result_value = prepareEditPolyTransformModifier node_value modifier_value level_symbol

    if result_value then
    (
        modifier_value.Select level_symbol selection_bits node:node_value
        modifier_value.RefreshScreen()
        completeRedraw()
    )

    result_value -- return
)

/*
Moves selected sub-objects on an Editable Poly by moving their affected vertices.
The operation stays entirely on the Editable Poly base-object topology.
*/
function moveEditablePolySubObjects poly_object level_symbol selection_bits move_amount =
(
    vertex_bits = getEditablePolyTransformVertices poly_object level_symbol selection_bits
    result_value = vertex_bits.numberSet > 0

    if result_value then
    (
        polyop.moveVert poly_object vertex_bits move_amount useSoftSel:false
    )

    result_value -- return
)

/*
Rotates selected sub-objects on an Editable Poly around their vertex center.
Point3 multiplied by Quat is used for the rotation; no rotate helper is used.
*/
function rotateEditablePolySubObjects poly_object level_symbol selection_bits rotation_value =
(
    vertex_bits = getEditablePolyTransformVertices poly_object level_symbol selection_bits
    result_value = vertex_bits.numberSet > 0

    if result_value then
    (
        center_value = getEditablePolyVertexCenter poly_object vertex_bits

        for vertex_id in vertex_bits do
        (
            old_position = polyop.getVert poly_object vertex_id
            new_position = center_value + ((old_position - center_value) * rotation_value)
            polyop.setVert poly_object vertex_id new_position
        )
    )

    result_value -- return
)

/*
Scales selected sub-objects on an Editable Poly around their vertex center.
Scale is applied component-wise to each vertex offset from the center.
*/
function scaleEditablePolySubObjects poly_object level_symbol selection_bits scale_value =
(
    vertex_bits = getEditablePolyTransformVertices poly_object level_symbol selection_bits
    result_value = vertex_bits.numberSet > 0

    if result_value then
    (
        center_value = getEditablePolyVertexCenter poly_object vertex_bits

        for vertex_id in vertex_bits do
        (
            old_position = polyop.getVert poly_object vertex_id
            offset_value = old_position - center_value
            scaled_offset = [offset_value.x * scale_value.x, offset_value.y * scale_value.y, offset_value.z * scale_value.z]
            new_position = center_value + scaled_offset
            polyop.setVert poly_object vertex_id new_position
        )
    )

    result_value -- return
)

/*
Begins the correct level-specific Edit Poly transform operation.
The current modifier selection is preserved and used by the transform methods.
*/
function beginEditPolyTransform node_value modifier_value level_symbol =
(
    operation_value = getEditPolyTransformOperation level_symbol
    result_value = prepareEditPolyTransformModifier node_value modifier_value level_symbol

    if result_value and operation_value != undefined then
    (
        modifier_value.SetOperation operation_value
    )
    else
    (
        result_value = false
    )

    result_value -- return
)

/*
Moves the current Edit Poly sub-object selection and commits the operation.
The native Edit Poly MoveSelection method is used directly.
*/
function moveEditPolySubObjects node_value modifier_value level_symbol move_amount =
(
    result_value = beginEditPolyTransform node_value modifier_value level_symbol

    if result_value then
    (
        parent_tm = matrix3 1
        axis_tm = matrix3 1

        modifier_value.MoveSelection move_amount parent:parent_tm axis:axis_tm localOrigin:false
        modifier_value.Commit()
        modifier_value.RefreshScreen()
    )

    result_value -- return
)

/*
Rotates the current Edit Poly selection around the same explicit center as the base test.
A translated custom axis supplies the pivot and the operation is committed afterward.
*/
function rotateEditPolySubObjects node_value modifier_value level_symbol selection_bits rotation_value =
(
    result_value = beginEditPolyTransform node_value modifier_value level_symbol

    if result_value then
    (
        vertex_bits = getEditablePolyTransformVertices node_value.baseObject level_symbol selection_bits
        center_value = getEditPolyVertexCenter node_value modifier_value vertex_bits
        parent_tm = matrix3 1
        axis_tm = transMatrix center_value

        modifier_value.RotateSelection rotation_value parent:parent_tm axis:axis_tm localOrigin:false
        modifier_value.Commit()
        modifier_value.RefreshScreen()
    )

    result_value -- return
)

/*
Scales the current Edit Poly selection around the same explicit center as the base test.
A translated custom axis supplies the pivot and the operation is committed afterward.
*/
function scaleEditPolySubObjects node_value modifier_value level_symbol selection_bits scale_value =
(
    result_value = beginEditPolyTransform node_value modifier_value level_symbol

    if result_value then
    (
        vertex_bits = getEditablePolyTransformVertices node_value.baseObject level_symbol selection_bits
        center_value = getEditPolyVertexCenter node_value modifier_value vertex_bits
        parent_tm = matrix3 1
        axis_tm = transMatrix center_value

        modifier_value.ScaleSelection scale_value parent:parent_tm axis:axis_tm localOrigin:false
        modifier_value.Commit()
        modifier_value.RefreshScreen()
    )

    result_value -- return
)

/*
Deletes nodes left by an earlier run of this transform test.
Only nodes using the dedicated EPolyTransformTest_ name prefix are removed.
*/
function deleteOldTransformTestNodes =
(
    nodes_to_delete = #()

    for scene_node in objects do
    (
        if matchPattern scene_node.name pattern:"EPolyTransformTest_*" then
        (
            append nodes_to_delete scene_node
        )
    )

    if nodes_to_delete.count > 0 then
    (
        delete nodes_to_delete
    )

    nodes_to_delete.count -- return
)

/*
Creates one matched Editable Poly / Edit Poly test pair for one sub-object level.
Both objects keep identity node transforms; their visible spacing is baked into vertices.
*/
function createTransformTestPair level_symbol row_y =
(
    label_value = level_symbol as string
    base_name = "EPolyTransformTest_" + label_value + "_EditablePoly"
    modifier_name = "EPolyTransformTest_" + label_value + "_EditPoly"

    base_node = box name:base_name length:30.0 width:30.0 height:30.0 lengthsegs:1 widthsegs:1 heightsegs:1
    base_node = convertToPoly base_node
    base_node.baseObject.showCage = off

    base_geometry_offset = [-50.0, row_y, 0.0]
    polyop.moveVert base_node.baseObject #all base_geometry_offset useSoftSel:false

    modifier_node = copy base_node
    modifier_node.name = modifier_name
    modifier_node.baseObject.showCage = off
    polyop.moveVert modifier_node.baseObject #all epoly_transform_pair_offset useSoftSel:false

    modifier_value = Edit_Poly()
    modifier_value.name = "TEST TRANSFORM " + label_value
    modifier_value.showCage = off
    modifier_value.useStackSelection = false
    modifier_value.selectMode = 0
    addModifier modifier_node modifier_value

    component_id = case level_symbol of
    (
        #Vertex: findTopVertexId base_node.baseObject
        #Edge: findTopEdgeId base_node.baseObject
        #Face: findTopFaceId base_node.baseObject
        default: 0
    )

    selection_bits = makeSingleBitArray component_id
    pair_data = #(level_symbol, base_node, modifier_node, modifier_value, selection_bits)

    pair_data -- return
)

/*
Compares all vertices in one matched pair after a transform stage.
The Edit Poly object is expected to remain exactly pair_offset away from the base object.
*/
function compareTransformTestPair pair_data stage_label =
(
    level_symbol = pair_data[1]
    base_node = pair_data[2]
    modifier_node = pair_data[3]
    modifier_value = pair_data[4]

    base_vertex_count = polyop.getNumVerts base_node.baseObject
    modifier_vertex_count = modifier_value.GetNumVertices node:modifier_node
    max_error = 0.0
    result_value = base_vertex_count == modifier_vertex_count

    if result_value then
    (
        for vertex_id = 1 to base_vertex_count do
        (
            base_position = polyop.getVert base_node.baseObject vertex_id
            modifier_position = modifier_value.GetVertex vertex_id node:modifier_node
            expected_modifier_position = base_position + epoly_transform_pair_offset
            error_value = distance modifier_position expected_modifier_position

            if error_value > max_error then
            (
                max_error = error_value
            )
        )

        result_value = max_error <= epoly_transform_test_tolerance
    )

    format "[%] % parity | max error:% | pass:%\n" stage_label level_symbol max_error result_value

    result_value -- return
)

/*
Runs parity checks for all Vertex, Edge, and Face test pairs.
Returns true only when all pair comparisons pass.
*/
function compareAllTransformTestPairs stage_label =
(
    result_value = true

    for pair_data in epoly_transform_test_pairs do
    (
        if not (compareTransformTestPair pair_data stage_label) then
        (
            result_value = false
        )
    )

    format "[%] ALL LEVELS PASS: %\n\n" stage_label result_value

    result_value -- return
)

/*
Part 1 creates fresh Vertex, Edge, and Face transform test pairs.
The scene is left populated so each later undo step can be inspected visually.
*/
function partOfTest1 =
(
    undo "EPoly Transform Test - Setup" on
    (
        deleteOldTransformTestNodes()
        epoly_transform_test_pairs = #()

        append epoly_transform_test_pairs (createTransformTestPair #Vertex 60.0)
        append epoly_transform_test_pairs (createTransformTestPair #Edge 0.0)
        append epoly_transform_test_pairs (createTransformTestPair #Face -60.0)
    )

    format "PART 1 | Created 3 matched Editable Poly / Edit Poly pairs.\n"
    true -- return
)

/*
Part 2 stores equivalent selections through each object's correct selection API.
It also verifies that the untouched pair geometry starts in exact parity.
*/
function partOfTest2 =
(
    undo "EPoly Transform Test - Selections" on
    (
        for pair_data in epoly_transform_test_pairs do
        (
            level_symbol = pair_data[1]
            base_node = pair_data[2]
            modifier_node = pair_data[3]
            modifier_value = pair_data[4]
            selection_bits = pair_data[5]

            setEditablePolyTransformSelection base_node.baseObject level_symbol selection_bits
            setEditPolyTransformSelection modifier_node modifier_value level_symbol selection_bits

            stored_selection = modifier_value.GetSelection level_symbol node:modifier_node
            format "SELECTION | % | requested:% | stored:%\n" level_symbol selection_bits stored_selection
        )
    )

    compareAllTransformTestPairs "INITIAL"
    true -- return
)

/*
Part 3 moves Vertex, Edge, and Face selections through both transform paths.
Every pair is compared immediately after the committed move operation.
*/
function partOfTest3 =
(
    move_amount = [8.0, 4.0, 12.0]

    undo "EPoly Transform Test - Move" on
    (
        for pair_data in epoly_transform_test_pairs do
        (
            level_symbol = pair_data[1]
            base_node = pair_data[2]
            modifier_node = pair_data[3]
            modifier_value = pair_data[4]
            selection_bits = pair_data[5]

            moveEditablePolySubObjects base_node.baseObject level_symbol selection_bits move_amount
            moveEditPolySubObjects modifier_node modifier_value level_symbol move_amount
        )
    )

    compareAllTransformTestPairs "MOVE"
    completeRedraw()
    true -- return
)

/*
Part 4 rotates Vertex, Edge, and Face selections 25 degrees around local Z.
Both implementations rotate around the current affected-vertex selection center.
*/
function partOfTest4 =
(
    rotation_value = quat 25.0 [0.0, 0.0, 1.0]

    undo "EPoly Transform Test - Rotate" on
    (
        for pair_data in epoly_transform_test_pairs do
        (
            level_symbol = pair_data[1]
            base_node = pair_data[2]
            modifier_node = pair_data[3]
            modifier_value = pair_data[4]
            selection_bits = pair_data[5]

            rotateEditablePolySubObjects base_node.baseObject level_symbol selection_bits rotation_value
            rotateEditPolySubObjects modifier_node modifier_value level_symbol selection_bits rotation_value
        )
    )

    compareAllTransformTestPairs "ROTATE"
    completeRedraw()
    true -- return
)

/*
Part 5 applies a non-uniform scale to Vertex, Edge, and Face selections.
Both implementations scale around the current affected-vertex selection center.
*/
function partOfTest5 =
(
    scale_value = [1.25, 0.75, 1.10]

    undo "EPoly Transform Test - Scale" on
    (
        for pair_data in epoly_transform_test_pairs do
        (
            level_symbol = pair_data[1]
            base_node = pair_data[2]
            modifier_node = pair_data[3]
            modifier_value = pair_data[4]
            selection_bits = pair_data[5]

            scaleEditablePolySubObjects base_node.baseObject level_symbol selection_bits scale_value
            scaleEditPolySubObjects modifier_node modifier_value level_symbol selection_bits scale_value
        )
    )

    compareAllTransformTestPairs "SCALE"
    completeRedraw()
    true -- return
)

/*
Part 6 leaves the Face Edit Poly pair active for visual inspection.
It prints the intended undo sequence from final state back to initial scene state.
*/
function partOfTest6 =
(
    if epoly_transform_test_pairs.count >= 3 then
    (
        pair_data = epoly_transform_test_pairs[3]
        level_symbol = pair_data[1]
        modifier_node = pair_data[3]
        modifier_value = pair_data[4]

        prepareEditPolyTransformModifier modifier_node modifier_value level_symbol
        modifier_value.RefreshScreen()
        completeRedraw()
    )

    format "============================================================\n"
    format "EPoly sub-object transform test finished.\n"
    format "Undo order from the final state:\n"
    format "  1. EPoly Transform Test - Scale\n"
    format "  2. EPoly Transform Test - Rotate\n"
    format "  3. EPoly Transform Test - Move\n"
    format "  4. EPoly Transform Test - Selections\n"
    format "  5. EPoly Transform Test - Setup\n"
    format "Tolerance: %\n" epoly_transform_test_tolerance
    format "============================================================\n"

    true -- return
)

/* Explicit test execution queue. */
partOfTest1()
partOfTest2()
partOfTest3()
partOfTest4()
partOfTest5()
partOfTest6()
