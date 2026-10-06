/*
Vertex Color Painter operation regression test.
Tests direct Editable Poly painting and Edit Poly + PaintLayerMod painting through the reusable VertexColorPainter_v API.
*/

global vertex_color_painter_test_file_version = "0.05"
global vertex_color_painter_test_passed = true
global vertex_color_painter_test_source_file = getSourceFileName()
global vertex_color_painter_test_directory
global vertex_color_painter_test_module_path
global vertex_color_painter_test_base_node
global vertex_color_painter_test_stack_node
global vertex_color_painter_test_edit_poly
global vertex_color_painter_test_stack_vertex_ids = #{1,2}
global vertex_color_painter_test_orange = color 255 128 0
global vertex_color_painter_test_red = color 255 0 0
global vertex_color_painter_test_green = color 0 255 0
global vertex_color_painter_test_blue = color 0 0 255

if vertex_color_painter_test_source_file == undefined or vertex_color_painter_test_source_file == "" then
(
    throw "Vertex-Color-Painter-Test.ms must be executed from a saved .ms file."
)

vertex_color_painter_test_directory = getFilenamePath vertex_color_painter_test_source_file
vertex_color_painter_test_module_path = vertex_color_painter_test_directory + "Vertex-Color-Painter.ms"

if not doesFileExist vertex_color_painter_test_module_path then
(
    throw ("Missing Vertex Color Painter module: " + vertex_color_painter_test_module_path)
)

fileIn vertex_color_painter_test_module_path


/*
Records one boolean test result and preserves the complete regression status.
Returns the supplied boolean condition.
*/
function vertexColorPainterTestCheck condition_value label_text =
(
    if condition_value then
    (
        format "PASS: %\n" label_text
    )
    else
    (
        format "FAIL: %\n" label_text
        vertex_color_painter_test_passed = false
    )

    condition_value
    -- return
)


/*
Creates a fully face-split white channel-0 map on one clean Editable Poly test node.
Returns false when the supplied node cannot safely host the deterministic test topology.
*/
function vertexColorPainterTestBuildSplitMap source_node =
(
    if not isValidNode source_node then return false
    if classOf source_node.baseObject != Editable_Poly then return false
    if source_node.modifiers.count != 0 then return false

    local poly_value = source_node.baseObject

    if polyop.getHasDeadStructs poly_value != 0 then
    (
        polyop.collapseDeadStructs poly_value
    )

    local face_count = polyop.getNumFaces poly_value
    local total_corner_count = 0
    local next_map_vert_id = 1
    local white_point = [1.0, 1.0, 1.0]

    if polyop.getMapSupport poly_value 0 then
    (
        polyop.setMapSupport poly_value 0 false
    )

    polyop.setMapSupport poly_value 0 true

    for face_id = 1 to face_count do
    (
        total_corner_count += polyop.getFaceDeg poly_value face_id
    )

    polyop.setNumMapVerts poly_value 0 total_corner_count keep:false

    for face_id = 1 to face_count do
    (
        local face_degree = polyop.getFaceDeg poly_value face_id
        local map_face_ids = #()

        for corner_id = 1 to face_degree do
        (
            append map_face_ids next_map_vert_id
            polyop.setMapVert poly_value 0 next_map_vert_id white_point
            next_map_vert_id += 1
        )

        polyop.setMapFace poly_value 0 face_id map_face_ids
    )

    true
    -- return
)


/*
Creates one deterministic Editable Poly box for Vertex Color Painter tests.
The generated node has 8 geometry vertices, 6 polygon faces, and 24 split channel-0 map vertices.
*/
function vertexColorPainterTestCreateBox node_prefix position_value =
(
    local created_node = undefined

    undo "Vertex Color Painter Test - Create Box" on
    (
        created_node = box \
            name:(uniqueName node_prefix) \
            length:100.0 \
            width:100.0 \
            height:100.0 \
            lengthsegs:1 \
            widthsegs:1 \
            heightsegs:1

        created_node.position = position_value
        convertTo created_node Editable_Poly
        created_node.baseObject.showCage = off

        if not vertexColorPainterTestBuildSplitMap created_node then
        (
            delete created_node
            created_node = undefined
        )
    )

    created_node
    -- return
)


/*
Adds one neutral Edit Poly target without changing topology.
The modifier exists only to prove PaintLayerMod painting above a stable Edit Poly stack level.
*/
function vertexColorPainterTestAddEditPolyTarget source_node =
(
    if not isValidNode source_node then return undefined
    if classOf source_node.baseObject != Editable_Poly then return undefined
    if source_node.modifiers.count != 0 then return undefined

    local edit_poly_mod = Edit_Poly()
    edit_poly_mod.name = "VERTEX COLOR PAINTER TEST - TARGET"
    edit_poly_mod.useStackSelection = false
    edit_poly_mod.selectMode = 0

    if isProperty edit_poly_mod #showCage then
    (
        edit_poly_mod.showCage = off
    )

    undo "Vertex Color Painter Test - Add Edit Poly Target" on
    (
        addModifier source_node edit_poly_mod
    )

    completeRedraw()

    edit_poly_mod
    -- return
)


/*
Returns true when every direct channel-0 map vertex on the test node is exactly white.
This deterministic test intentionally uses exact values and no tolerance.
*/
function vertexColorPainterTestMapIsWhite source_node =
(
    if not isValidNode source_node then return false
    if classOf source_node.baseObject != Editable_Poly then return false

    local poly_value = source_node.baseObject

    if not polyop.getMapSupport poly_value 0 then return false

    local map_vert_count = polyop.getNumMapVerts poly_value 0
    local white_point = [1.0, 1.0, 1.0]

    for map_vert_id = 1 to map_vert_count do
    (
        if polyop.getMapVert poly_value 0 map_vert_id != white_point then return false
    )

    true
    -- return
)


/*
Test part 1 creates and binds the direct Editable Poly target.
The cached topology must use the base object's polygon, edge, and vertex IDs.
*/
function partOfTest1 =
(
    format "\n--- VERTEX COLOR PAINTER TEST PART 1 : BASE TARGET ---\n"

    vertex_color_painter_test_base_node = vertexColorPainterTestCreateBox "VertexColorPainter_Base" [-80,0,0]

    vertexColorPainterTestCheck (vertex_color_painter_test_base_node != undefined) "Created direct Editable Poly test box."

    if vertex_color_painter_test_base_node == undefined then return false

    local target_result = VertexColorPainter.setTarget vertex_color_painter_test_base_node 0

    vertexColorPainterTestCheck target_result "VertexColorPainter bound to stack index 0."
    vertexColorPainterTestCheck (VertexColorPainter.source_node == vertex_color_painter_test_base_node) "source_node property identifies the bound object."
    vertexColorPainterTestCheck (VertexColorPainter.stack_index == 0) "stack_index property identifies the base object."
    vertexColorPainterTestCheck (VertexColorPainter.backend_type == #baseObject) "Base target selected direct channel-0 backend."
    vertexColorPainterTestCheck (VertexColorPainter.vertex_count == 8) "Cached base topology has 8 vertices."
    vertexColorPainterTestCheck (VertexColorPainter.face_count == 6) "Cached base topology has 6 polygon faces."
    vertexColorPainterTestCheck (VertexColorPainter.edge_count == 12) "Cached base topology has 12 edges."
    vertexColorPainterTestCheck (VertexColorPainter.geo_to_map_vertices[1].count == 3) "Geometry vertex 1 caches three split map-vertex representations."

    vertex_color_painter_test_passed
    -- return
)


/*
Test part 2 paints one exact face corner using the geo-vertex plus polygon-face API.
Only the map vertex representing that exact corner may change.
*/
function partOfTest2 =
(
    format "\n--- VERTEX COLOR PAINTER TEST PART 2 : PAINT EXACT BASE CORNER ---\n"

    if not VertexColorPainter.isTargetValid() then
    (
        vertexColorPainterTestCheck false "Direct target is valid before exact-corner paint."
        return false
    )

    local target_map_vert_id = VertexColorPainter.getMapVertexForCorner 1 1
    local paint_result = VertexColorPainter.paintCorner 1 1 vertex_color_painter_test_orange
    local orange_point = VertexColorPainter.colorToMapPoint vertex_color_painter_test_orange
    local poly_value = vertex_color_painter_test_base_node.baseObject
    local changed_count = 0

    for map_vert_id = 1 to polyop.getNumMapVerts poly_value 0 do
    (
        if polyop.getMapVert poly_value 0 map_vert_id == orange_point then
        (
            changed_count += 1
        )
    )

    format "EXACT CORNER: GEO VERT 1 + FACE 1 -> MAP VERT %\n" target_map_vert_id

    vertexColorPainterTestCheck paint_result "paintCorner completed on the direct backend."
    vertexColorPainterTestCheck (target_map_vert_id == 1) "Exact corner resolves to map vertex 1 on the deterministic split map."
    vertexColorPainterTestCheck (changed_count == 1) "Exactly one direct map vertex changed color."

    vertex_color_painter_test_passed
    -- return
)


/*
Test part 3 validates the reusable vertex, edge, and face methods on cached direct topology.
Each public method must complete without changing geometry or map topology.
*/
function partOfTest3 =
(
    format "\n--- VERTEX COLOR PAINTER TEST PART 3 : BASE VERTEX EDGE FACE API ---\n"

    local poly_value = vertex_color_painter_test_base_node.baseObject
    local map_vert_count_before = polyop.getNumMapVerts poly_value 0
    local map_face_count_before = polyop.getNumMapFaces poly_value 0
    local vertex_result = VertexColorPainter.paintVertex 1 vertex_color_painter_test_red
    local edge_result = VertexColorPainter.paintEdge 1 vertex_color_painter_test_green
    local face_result = VertexColorPainter.paintFace 2 vertex_color_painter_test_blue

    vertexColorPainterTestCheck vertex_result "paintVertex completed on cached direct topology."
    vertexColorPainterTestCheck edge_result "paintEdge completed on cached direct topology."
    vertexColorPainterTestCheck face_result "paintFace completed on cached direct topology."
    vertexColorPainterTestCheck (polyop.getNumMapVerts poly_value 0 == map_vert_count_before) "Direct API preserved map-vertex count."
    vertexColorPainterTestCheck (polyop.getNumMapFaces poly_value 0 == map_face_count_before) "Direct API preserved map-face count."

    vertex_color_painter_test_passed
    -- return
)


/*
Test part 4 restores the original direct channel-0 state through the shared painter session.
All 24 deterministic map vertices must return to white.
*/
function partOfTest4 =
(
    format "\n--- VERTEX COLOR PAINTER TEST PART 4 : CLEAR BASE PAINT ---\n"

    local clear_result = VertexColorPainter.clearPaint()

    vertexColorPainterTestCheck clear_result "clearPaint restored direct base paint."
    vertexColorPainterTestCheck (vertexColorPainterTestMapIsWhite vertex_color_painter_test_base_node) "All 24 direct map vertices returned to white."
    vertexColorPainterTestCheck (not VertexColorPainter.base_backup_valid) "Direct restore backup closed successfully."

    vertex_color_painter_test_passed
    -- return
)


/*
Test part 5 creates a second box with a neutral Edit Poly target.
The painter test deliberately avoids topology-generation behavior and isolates the PaintLayerMod backend.
*/
function partOfTest5 =
(
    format "\n--- VERTEX COLOR PAINTER TEST PART 5 : EDIT POLY PAINT TARGET ---\n"

    vertex_color_painter_test_stack_node = vertexColorPainterTestCreateBox "VertexColorPainter_Stack" [80,0,0]

    vertexColorPainterTestCheck (vertex_color_painter_test_stack_node != undefined) "Created modifier-stack test box."

    if vertex_color_painter_test_stack_node == undefined then return false

    vertex_color_painter_test_edit_poly = vertexColorPainterTestAddEditPolyTarget vertex_color_painter_test_stack_node

    vertexColorPainterTestCheck (vertex_color_painter_test_edit_poly != undefined) "Added neutral Edit Poly paint target."

    if vertex_color_painter_test_edit_poly == undefined then return false

    local target_result = VertexColorPainter.setTarget vertex_color_painter_test_stack_node 1

    vertexColorPainterTestCheck target_result "VertexColorPainter bound to the Edit Poly target."
    vertexColorPainterTestCheck (VertexColorPainter.backend_type == #vertexPaint) "Edit Poly target selected PaintLayerMod backend."

    if not target_result then return false

    vertexColorPainterTestCheck (VertexColorPainter.evaluated_mesh != undefined) "Cached evaluated mesh exists for the Edit Poly target."
    vertexColorPainterTestCheck (VertexColorPainter.vertex_count == 8) "Cached Edit Poly target has 8 vertices."
    vertexColorPainterTestCheck (VertexColorPainter.face_count == 6) "Cached Edit Poly target has 6 polygon faces."
    vertexColorPainterTestCheck (VertexColorPainter.edge_count == 12) "Cached Edit Poly target has 12 edges."
    vertexColorPainterTestCheck (VertexColorPainter.vertex_faces[1].count == 3) "Cached modifier topology preserves vertex 1 polygon adjacency."

    vertex_color_painter_test_passed
    -- return
)


/*
Test part 6 paints two stable geometry vertices through one PaintLayerMod transaction.
The Editable Poly base channel must remain unchanged because modifier paint lives above the Edit Poly target.
*/
function partOfTest6 =
(
    format "\n--- VERTEX COLOR PAINTER TEST PART 6 : PAINT MODIFIER VERTICES ---\n"

    local paint_result = VertexColorPainter.paintVertices vertex_color_painter_test_stack_vertex_ids vertex_color_painter_test_orange
    local paint_layer_mod = VertexColorPainter.getPaintLayerMod()
    local paint_layer_ready = paint_layer_mod != undefined
    local paint_index = if paint_layer_ready then VertexColorPainter.getPaintLayerStackIndex() else 0
    local target_index = VertexColorPainter.getCurrentTargetStackIndex()

    format "PAINT LAYER INDEX: % | TARGET EDIT POLY INDEX: %\n" paint_index target_index

    vertexColorPainterTestCheck paint_result "paintVertices colored the requested Edit Poly target vertices."
    vertexColorPainterTestCheck paint_layer_ready "Tool-owned PaintLayerMod exists."
    vertexColorPainterTestCheck (paint_layer_ready and paint_index > 0 and target_index == (paint_index + 1)) "PaintLayerMod remains immediately above the bound Edit Poly."
    vertexColorPainterTestCheck (paint_layer_ready and VertexColorPainter.stack_index == target_index) "stack_index property tracks the target after PaintLayerMod insertion."
    vertexColorPainterTestCheck (vertexColorPainterTestMapIsWhite vertex_color_painter_test_stack_node) "Base Editable Poly channel remains untouched."

    if not paint_layer_ready then return false

    local paint_state = paint_layer_mod.AcquirePaintState vertex_color_painter_test_stack_node

    vertexColorPainterTestCheck (paint_state != undefined) "Acquired PaintLayerMod state for verification."

    if paint_state == undefined then return false

    local expected_point = VertexColorPainter.colorToPaintPoint4 vertex_color_painter_test_orange
    local verified_count = 0

    for vertex_id in vertex_color_painter_test_stack_vertex_ids do
    (
        if paint_state.GetVertAverageColor vertex_id == expected_point then
        (
            verified_count += 1
        )
    )

    paint_layer_mod.ReleasePaintState vertex_color_painter_test_stack_node paint_state

    format "MODIFIER VERTICES REQUESTED: %\n" vertex_color_painter_test_stack_vertex_ids.numberSet
    format "MODIFIER VERTICES VERIFIED ORANGE: %\n" verified_count

    vertexColorPainterTestCheck (verified_count == vertex_color_painter_test_stack_vertex_ids.numberSet) "Every requested modifier vertex stores the orange color."

    vertex_color_painter_test_passed
    -- return
)


/*
Test part 7 paints one exact face corner red while another corner of the same geometry vertex stays orange.
This proves independent face-corner storage through VertexPaintState on the modifier backend.
*/
function partOfTest7 =
(
    format "\n--- VERTEX COLOR PAINTER TEST PART 7 : EXACT MODIFIER FACE CORNER ---\n"

    local target_vertex_id = 1

    if VertexColorPainter.vertex_faces[target_vertex_id].count < 2 then
    (
        vertexColorPainterTestCheck false "Target vertex has at least two adjacent polygon faces."
        return false
    )

    local target_face_id = VertexColorPainter.vertex_faces[target_vertex_id][1]
    local neighbor_face_id = VertexColorPainter.vertex_faces[target_vertex_id][2]
    local paint_result = VertexColorPainter.paintCorner target_vertex_id target_face_id vertex_color_painter_test_red
    local paint_layer_mod = VertexColorPainter.getPaintLayerMod()

    vertexColorPainterTestCheck paint_result "paintCorner completed on the PaintLayerMod backend."

    if paint_layer_mod == undefined then return false

    local paint_state = paint_layer_mod.AcquirePaintState vertex_color_painter_test_stack_node

    if paint_state == undefined then
    (
        vertexColorPainterTestCheck false "Acquired PaintLayerMod state after exact modifier-corner paint."
        return false
    )

    local red_point = VertexColorPainter.colorToPaintPoint4 vertex_color_painter_test_red
    local orange_point = VertexColorPainter.colorToPaintPoint4 vertex_color_painter_test_orange
    local target_raw_index = paint_state.GetRawIndex target_face_id target_vertex_id
    local neighbor_raw_index = paint_state.GetRawIndex neighbor_face_id target_vertex_id
    local target_stored_point = if target_raw_index > 0 then paint_state.GetRawColor target_raw_index else undefined
    local neighbor_stored_point = if neighbor_raw_index > 0 then paint_state.GetRawColor neighbor_raw_index else undefined

    paint_layer_mod.ReleasePaintState vertex_color_painter_test_stack_node paint_state

    format "EXACT MODIFIER CORNER: GEO VERT % + FACE % -> RAW %\n" target_vertex_id target_face_id target_raw_index
    format "NEIGHBOR MODIFIER CORNER: GEO VERT % + FACE % -> RAW %\n" target_vertex_id neighbor_face_id neighbor_raw_index

    vertexColorPainterTestCheck (target_raw_index > 0) "Target face/vertex pair resolves to one raw VertexPaint color entry."
    vertexColorPainterTestCheck (neighbor_raw_index > 0) "Adjacent face/vertex pair resolves to a separate raw VertexPaint color entry."
    vertexColorPainterTestCheck (target_raw_index != neighbor_raw_index) "Adjacent polygon corners of one geometry vertex use different raw paint entries."
    vertexColorPainterTestCheck (target_stored_point == red_point) "Target face corner stores the requested red color."
    vertexColorPainterTestCheck (neighbor_stored_point == orange_point) "Adjacent face corner preserves the previous orange vertex color."
    vertexColorPainterTestCheck (vertexColorPainterTestMapIsWhite vertex_color_painter_test_stack_node) "Exact modifier-corner paint leaves the base channel untouched."

    vertex_color_painter_test_passed
    -- return
)


/*
Test part 8 removes only the tool-owned PaintLayerMod.
The neutral Edit Poly target and the Editable Poly base must remain unchanged.
*/
function partOfTest8 =
(
    format "\n--- VERTEX COLOR PAINTER TEST PART 8 : CLEAR MODIFIER PAINT ---\n"

    local cached_vertex_count_before = VertexColorPainter.vertex_count
    local cached_face_count_before = VertexColorPainter.face_count
    local clear_result = VertexColorPainter.clearPaint()
    local edit_poly_preserved = false

    for stack_mod in vertex_color_painter_test_stack_node.modifiers do
    (
        if stack_mod == vertex_color_painter_test_edit_poly then
        (
            edit_poly_preserved = true
        )
    )

    vertexColorPainterTestCheck clear_result "clearPaint removed the tool-owned PaintLayerMod."
    vertexColorPainterTestCheck (VertexColorPainter.getPaintLayerMod() == undefined) "No tool-owned PaintLayerMod remains."
    vertexColorPainterTestCheck edit_poly_preserved "Target Edit Poly modifier remains in the stack."
    vertexColorPainterTestCheck (VertexColorPainter.getCurrentTargetStackIndex() == 1) "Target Edit Poly returned to stack index 1 after paint-layer removal."
    vertexColorPainterTestCheck (VertexColorPainter.vertex_count == cached_vertex_count_before) "Cached modifier vertex count remains unchanged."
    vertexColorPainterTestCheck (VertexColorPainter.face_count == cached_face_count_before) "Cached modifier face count remains unchanged."
    vertexColorPainterTestCheck (vertexColorPainterTestMapIsWhite vertex_color_painter_test_stack_node) "Base channel remains white after modifier-paint clear."

    vertex_color_painter_test_passed
    -- return
)


/*
Test part 9 rebuilds a final modifier-paint state for visual inspection.
Vertex 1 is orange on all corners except one exact face corner, which is red.
*/
function partOfTest9 =
(
    format "\n--- VERTEX COLOR PAINTER TEST PART 9 : FINAL VISUAL STATE ---\n"

    local vertex_result = VertexColorPainter.paintVertex 1 vertex_color_painter_test_orange
    local target_face_id = VertexColorPainter.vertex_faces[1][1]
    local corner_result = if vertex_result then VertexColorPainter.paintCorner 1 target_face_id vertex_color_painter_test_red else false

    vertexColorPainterTestCheck vertex_result "Final modifier vertex color was rebuilt."
    vertexColorPainterTestCheck corner_result "Final exact face-corner override was rebuilt."
    vertexColorPainterTestCheck (VertexColorPainter.getPaintLayerMod() != undefined) "Final stack contains the Vertex Color Painter layer."

    select vertex_color_painter_test_stack_node
    completeRedraw()

    format "\nFINAL VERTEX COLOR PAINTER TEST STATE:\n"
    format "- base test object remains in the scene with restored white channel 0\n"
    format "- stack test object keeps one neutral Edit Poly target\n"
    format "- Vertex Color Painter PaintLayerMod sits immediately above the Edit Poly\n"
    format "- geometry vertex 1 is orange, with one polygon face corner overridden to red\n"
    format "\nFINAL TEST STATUS: %\n" (if vertex_color_painter_test_passed then "PASS" else "FAIL")

    vertex_color_painter_test_passed
    -- return
)


clearListener()
partOfTest1()
partOfTest2()
partOfTest3()
partOfTest4()
partOfTest5()
partOfTest6()
partOfTest7()
partOfTest8()
partOfTest9()
