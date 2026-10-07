/*
Geometry Diagnostics backend test.
Runs direct channel-0 tests plus evaluated-stack VertexPaint tests on tessellation-created vertices.
*/

global geometry_diagnostics_test_file_version = "0.08"
global geometry_diagnostics_test_project_version = "0.09"
global geometry_diagnostics_project_version
global geometry_diagnostics_test_source_file = getSourceFileName()
global geometry_diagnostics_test_directory
global geometry_diagnostics_test_vertex_color_painter_path
global geometry_diagnostics_test_backend_path
global geometry_diagnostics_test_scene_node
global geometry_diagnostics_test_passed = true
global geometry_diagnostics_test_vertex_one_map_ids = #()
global geometry_diagnostics_test_colors_before_vertex_paint = #()
global geometry_diagnostics_test_map_faces_before_vertex_paint = #()
global geometry_diagnostics_test_vertex_color = color 255 128 0
global geometry_diagnostics_modifier_test_node
global geometry_diagnostics_modifier_test_tessellate_mod
global geometry_diagnostics_modifier_test_base_vertex_count = 0
global geometry_diagnostics_modifier_test_evaluated_vertex_count = 0
global geometry_diagnostics_modifier_test_new_vertex_ids = #{}

if geometry_diagnostics_project_version == undefined then
(
    geometry_diagnostics_project_version = geometry_diagnostics_test_project_version
)
else if (geometry_diagnostics_project_version as float) < (geometry_diagnostics_test_project_version as float) then
(
    geometry_diagnostics_project_version = geometry_diagnostics_test_project_version
)

if geometry_diagnostics_test_source_file == undefined or geometry_diagnostics_test_source_file == "" then
(
    throw "Geometry-Diagnostics-Test.ms must be executed from a saved .ms file."
)

geometry_diagnostics_test_directory = getFilenamePath geometry_diagnostics_test_source_file
geometry_diagnostics_test_vertex_color_painter_path = geometry_diagnostics_test_directory + "..\\..\\..\\..\\Operations\\Vertex-Color-Painter\\Vertex-Color-Painter.ms"

if not doesFileExist geometry_diagnostics_test_vertex_color_painter_path then
(
    geometry_diagnostics_test_vertex_color_painter_path = geometry_diagnostics_test_directory + "..\\..\\..\\Operations\\Vertex-Color-Painter\\Vertex-Color-Painter.ms"
)

geometry_diagnostics_test_backend_path = geometry_diagnostics_test_directory + "..\\Geometry-Diagnostics-FN.ms"

if not doesFileExist geometry_diagnostics_test_vertex_color_painter_path then
(
    throw ("Missing Vertex Color Painter operation: " + geometry_diagnostics_test_vertex_color_painter_path)
)

if not doesFileExist geometry_diagnostics_test_backend_path then
(
    throw ("Missing Geometry Diagnostics backend: " + geometry_diagnostics_test_backend_path)
)

fileIn geometry_diagnostics_test_vertex_color_painter_path
fileIn geometry_diagnostics_test_backend_path


/*
Records one boolean test result and keeps the complete test status.
Returns the supplied boolean condition.
*/
function geometryDiagnosticsTestCheck condition_value label_text =
(
    if condition_value then
    (
        format "PASS: %\n" label_text
    )
    else
    (
        format "FAIL: %\n" label_text
        geometry_diagnostics_test_passed = false
    )

    condition_value
    -- return
)


/*
Compares two Point3 values exactly for this no-tolerance color-map test.
Returns true only when all stored channel values are exactly equal.
*/
function geometryDiagnosticsTestPoint3Match value_a value_b =
(
    if value_a == undefined or value_b == undefined then return false

    value_a == value_b
    -- return
)


/*
Test part 1 creates the generated Editable Poly test box.
The scene-changing stage has its own named undo entry inside the backend operation.
*/
function partOfTest1 =
(
    format "\n--- TEST PART 1 : CREATE BOX ---\n"

    geometry_diagnostics_test_scene_node = createGeometryDiagnosticsTestBox()

    geometryDiagnosticsTestCheck (isGeometryDiagnosticsEditablePolyNode geometry_diagnostics_test_scene_node) "Generated node is Editable Poly."

    if isGeometryDiagnosticsEditablePolyNode geometry_diagnostics_test_scene_node then
    (
        select geometry_diagnostics_test_scene_node
        max modify mode
        modPanel.setCurrentObject geometry_diagnostics_test_scene_node.baseObject node:geometry_diagnostics_test_scene_node ui:true

        geometryDiagnosticsTestCheck (modPanel.getCurrentObject() == geometry_diagnostics_test_scene_node.baseObject) "Editable Poly base is selected in the Modify panel."
    )

    geometry_diagnostics_test_scene_node
    -- return
)


/*
Test part 2 validates the expected geometry and split channel-0 topology.
This stage is read-only.
*/
function partOfTest2 =
(
    format "\n--- TEST PART 2 : VALIDATE TOPOLOGY ---\n"

    if not isGeometryDiagnosticsEditablePolyNode geometry_diagnostics_test_scene_node then
    (
        geometryDiagnosticsTestCheck false "Part 2 has a valid Editable Poly test node."
        return false
    )

    local poly_value = geometry_diagnostics_test_scene_node.baseObject
    local vertex_count = polyop.getNumVerts poly_value
    local face_count = polyop.getNumFaces poly_value
    local map_vert_count = polyop.getNumMapVerts poly_value 0
    local all_faces_are_quads = true

    for face_id = 1 to face_count do
    (
        if polyop.getFaceDeg poly_value face_id != 4 then
        (
            all_faces_are_quads = false
        )
    )

    geometryDiagnosticsTestCheck (vertex_count == 8) "Box has 8 geometry vertices."
    geometryDiagnosticsTestCheck (face_count == 6) "Box has 6 Editable Poly polygon faces."
    geometryDiagnosticsTestCheck (map_vert_count == 24) "Channel 0 has 24 fully split map vertices."
    geometryDiagnosticsTestCheck all_faces_are_quads "Every test polygon has four corners."

    geometry_diagnostics_test_passed
    -- return
)


/*
Test part 3 paints the six polygon faces with six independent colors.
The scene-changing stage is stored as its own named undo entry by the backend operation.
*/
function partOfTest3 =
(
    format "\n--- TEST PART 3 : PAINT SIX FACES ---\n"

    if not isGeometryDiagnosticsEditablePolyNode geometry_diagnostics_test_scene_node then
    (
        geometryDiagnosticsTestCheck false "Part 3 has a valid Editable Poly test node."
        return false
    )

    local paint_result = paintGeometryDiagnosticsTestBox geometry_diagnostics_test_scene_node

    geometryDiagnosticsTestCheck paint_result "Six-color paint operation completed."
    geometryDiagnosticsTestCheck (VertexColorPainter.stack_index == 0) "Selected Editable Poly routes face colors directly to channel 0."
    geometryDiagnosticsTestCheck (VertexColorPainter.backend_type == #baseObject) "Selected Editable Poly uses the direct painter backend."
    geometryDiagnosticsTestCheck (getGeometryDiagnosticsPaintLayerMod geometry_diagnostics_test_scene_node == undefined) "Direct Editable Poly face paint does not add PaintLayerMod."

    paint_result
    -- return
)


/*
Test part 4 validates that each polygon references four unique face-local map vertices.
The six-color result remains in the scene for the next geometry-vertex test stage.
*/
function partOfTest4 =
(
    format "\n--- TEST PART 4 : VALIDATE FACE-CORNER PAINT MAP ---\n"

    if not isGeometryDiagnosticsEditablePolyNode geometry_diagnostics_test_scene_node then
    (
        geometryDiagnosticsTestCheck false "Part 4 has a valid Editable Poly test node."
        return false
    )

    local poly_value = geometry_diagnostics_test_scene_node.baseObject
    local face_count = polyop.getNumFaces poly_value
    local seen_map_ids = #()
    local face_map_counts_valid = true
    local all_map_ids_unique = true

    for face_id = 1 to face_count do
    (
        local map_face_ids = polyop.getMapFace poly_value 0 face_id

        if map_face_ids.count != 4 then
        (
            face_map_counts_valid = false
        )

        for map_vert_id in map_face_ids do
        (
            if findItem seen_map_ids map_vert_id > 0 then
            (
                all_map_ids_unique = false
            )
            else
            (
                append seen_map_ids map_vert_id
            )
        )
    )

    geometryDiagnosticsTestCheck face_map_counts_valid "Every polygon references four map vertices."
    geometryDiagnosticsTestCheck all_map_ids_unique "No channel-0 map vertex is shared between test polygons."
    geometryDiagnosticsTestCheck (seen_map_ids.count == 24) "Exactly 24 unique map vertices are referenced."

    geometry_diagnostics_test_passed
    -- return
)


/*
Test part 5 resolves geometry vertex 1 to all of its face-corner map vertices.
It snapshots colors and map faces so the next stage can prove that only those corners change.
*/
function partOfTest5 =
(
    format "\n--- TEST PART 5 : RESOLVE GEOMETRY VERTEX 1 ---\n"

    if not isGeometryDiagnosticsEditablePolyNode geometry_diagnostics_test_scene_node then
    (
        geometryDiagnosticsTestCheck false "Part 5 has a valid Editable Poly test node."
        return false
    )

    local poly_value = geometry_diagnostics_test_scene_node.baseObject
    local face_count = polyop.getNumFaces poly_value
    local map_vert_count = polyop.getNumMapVerts poly_value 0
    local touching_face_ids = #()

    geometry_diagnostics_test_vertex_one_map_ids = getGeometryDiagnosticsMapVerticesForGeometryVertices geometry_diagnostics_test_scene_node 1

    if geometry_diagnostics_test_vertex_one_map_ids == undefined then
    (
        geometryDiagnosticsTestCheck false "Geometry vertex 1 map-vertex resolution succeeded."
        return false
    )

    geometry_diagnostics_test_colors_before_vertex_paint = #()
    geometry_diagnostics_test_map_faces_before_vertex_paint = #()

    for map_vert_id = 1 to map_vert_count do
    (
        append geometry_diagnostics_test_colors_before_vertex_paint (polyop.getMapVert poly_value 0 map_vert_id)
    )

    for face_id = 1 to face_count do
    (
        local geometry_face_ids = polyop.getFaceVerts poly_value face_id
        append geometry_diagnostics_test_map_faces_before_vertex_paint (polyop.getMapFace poly_value 0 face_id)

        if findItem geometry_face_ids 1 > 0 then
        (
            append touching_face_ids face_id
        )
    )

    format "GEOMETRY VERTEX 1 TOUCHES POLYGON FACES: %\n" touching_face_ids
    format "GEOMETRY VERTEX 1 MAP VERTICES: %\n" geometry_diagnostics_test_vertex_one_map_ids

    geometryDiagnosticsTestCheck (geometryDiagnosticsIntegerArraysMatch touching_face_ids #(1, 3, 6)) "Geometry vertex 1 belongs to polygon faces 1, 3, and 6."
    geometryDiagnosticsTestCheck (geometry_diagnostics_test_vertex_one_map_ids.count == 3) "Geometry vertex 1 resolves to exactly three channel-0 map vertices."
    geometryDiagnosticsTestCheck (geometryDiagnosticsIntegerArraysMatch geometry_diagnostics_test_vertex_one_map_ids #(1, 9, 22)) "Geometry vertex 1 resolves to map vertices 1, 9, and 22 on this test topology."

    geometry_diagnostics_test_passed
    -- return
)


/*
Test part 6 paints geometry vertex 1 through the public geometry-vertex interface.
The backend must fan the color out to every channel-0 face-corner representation.
*/
function partOfTest6 =
(
    format "\n--- TEST PART 6 : PAINT GEOMETRY VERTEX 1 ---\n"

    if not isGeometryDiagnosticsEditablePolyNode geometry_diagnostics_test_scene_node then
    (
        geometryDiagnosticsTestCheck false "Part 6 has a valid Editable Poly test node."
        return false
    )

    local paint_result = paintGeometryDiagnosticsVertices geometry_diagnostics_test_scene_node 1 geometry_diagnostics_test_vertex_color

    geometryDiagnosticsTestCheck paint_result "Geometry vertex 1 paint operation completed."

    paint_result
    -- return
)


/*
Test part 7 proves that exactly the three mapped corners changed and map topology stayed intact.
Every non-target map vertex must retain its previous face color exactly.
*/
function partOfTest7 =
(
    format "\n--- TEST PART 7 : VALIDATE GEOMETRY-VERTEX FAN-OUT ---\n"

    if not isGeometryDiagnosticsEditablePolyNode geometry_diagnostics_test_scene_node then
    (
        geometryDiagnosticsTestCheck false "Part 7 has a valid Editable Poly test node."
        return false
    )

    local poly_value = geometry_diagnostics_test_scene_node.baseObject
    local face_count = polyop.getNumFaces poly_value
    local map_vert_count = polyop.getNumMapVerts poly_value 0
    local expected_map_point = geometryDiagnosticsColorToMapPoint geometry_diagnostics_test_vertex_color
    local changed_target_count = 0
    local non_target_colors_preserved = true
    local map_topology_preserved = true

    for map_vert_id = 1 to map_vert_count do
    (
        local current_map_point = polyop.getMapVert poly_value 0 map_vert_id

        if findItem geometry_diagnostics_test_vertex_one_map_ids map_vert_id > 0 then
        (
            if geometryDiagnosticsTestPoint3Match current_map_point expected_map_point then
            (
                changed_target_count += 1
            )
        )
        else
        (
            if not geometryDiagnosticsTestPoint3Match current_map_point geometry_diagnostics_test_colors_before_vertex_paint[map_vert_id] then
            (
                non_target_colors_preserved = false
            )
        )
    )

    for face_id = 1 to face_count do
    (
        local current_map_face = polyop.getMapFace poly_value 0 face_id

        if not geometryDiagnosticsIntegerArraysMatch current_map_face geometry_diagnostics_test_map_faces_before_vertex_paint[face_id] then
        (
            map_topology_preserved = false
        )
    )

    geometryDiagnosticsTestCheck (changed_target_count == 3) "Exactly three map vertices received the geometry-vertex color."
    geometryDiagnosticsTestCheck non_target_colors_preserved "All non-target map vertices kept their original face colors."
    geometryDiagnosticsTestCheck map_topology_preserved "Geometry-vertex painting did not change channel-0 map topology."

    geometry_diagnostics_test_passed
    -- return
)


/*
Test part 8 restores the original white split map captured before the first paint session.
It validates all 24 map colors and keeps the original split topology intact.
*/
function partOfTest8 =
(
    format "\n--- TEST PART 8 : RESTORE ORIGINAL COLORS ---\n"

    if not isGeometryDiagnosticsEditablePolyNode geometry_diagnostics_test_scene_node then
    (
        geometryDiagnosticsTestCheck false "Part 8 has a valid Editable Poly test node."
        return false
    )

    local restore_result = restoreGeometryDiagnosticsColors geometry_diagnostics_test_scene_node

    geometryDiagnosticsTestCheck restore_result "Paint-session restore completed."

    if not restore_result then return false

    local poly_value = geometry_diagnostics_test_scene_node.baseObject
    local map_vert_count = polyop.getNumMapVerts poly_value 0
    local all_colors_white = true
    local white_point = [1.0, 1.0, 1.0]

    for map_vert_id = 1 to map_vert_count do
    (
        if not geometryDiagnosticsTestPoint3Match (polyop.getMapVert poly_value 0 map_vert_id) white_point then
        (
            all_colors_white = false
        )
    )

    geometryDiagnosticsTestCheck (map_vert_count == 24) "Restore preserved all 24 split map vertices."
    geometryDiagnosticsTestCheck all_colors_white "Restore returned all 24 map vertices to white."
    geometryDiagnosticsTestCheck (getGeometryDiagnosticsBackupIndex geometry_diagnostics_test_scene_node == 0) "Restore closed the original paint-session backup."

    geometry_diagnostics_test_passed
    -- return
)


/*
Test part 9 rebuilds the useful visual end state after restore verification.
The scene is left with six face colors plus the orange fan-out at geometry vertex 1.
*/
function partOfTest9 =
(
    format "\n--- TEST PART 9 : FINAL VISUAL STATE ---\n"

    if not isGeometryDiagnosticsEditablePolyNode geometry_diagnostics_test_scene_node then
    (
        geometryDiagnosticsTestCheck false "Part 9 has a valid Editable Poly test node."
        return false
    )

    local face_paint_result = paintGeometryDiagnosticsTestBox geometry_diagnostics_test_scene_node
    local vertex_paint_result = false

    if face_paint_result then
    (
        vertex_paint_result = paintGeometryDiagnosticsVertices geometry_diagnostics_test_scene_node 1 geometry_diagnostics_test_vertex_color
    )

    geometryDiagnosticsTestCheck face_paint_result "Final six-face paint completed."
    geometryDiagnosticsTestCheck vertex_paint_result "Final geometry-vertex fan-out paint completed."

    dumpGeometryDiagnosticsChannelZero geometry_diagnostics_test_scene_node

    format "\nFINAL VISUAL STATE:\n"
    format "- six independently colored polygon faces\n"
    format "- geometry vertex 1 painted orange across map vertices %\n" geometry_diagnostics_test_vertex_one_map_ids
    format "\nLATEST UNDO ORDER:\n"
    format "1. Geometry Diagnostics - Paint Geometry Vertices -> returns to six solid face colors.\n"
    format "2. Geometry Diagnostics - Paint Face Colors -> returns to the restored white split map.\n"
    format "Earlier validation paint entries remain below those two undo records.\n"
    format "\nFINAL TEST STATUS: %\n" (if geometry_diagnostics_test_passed then "PASS" else "FAIL")
    format "The final painted test box is intentionally left in the scene.\n"

    geometry_diagnostics_test_passed
    -- return
)




/*
Test part 10 creates the selected-modifier regression fixture.
The exact Tessellate setup is added through the Modify panel and remains the selected stack level.
*/
function partOfTest10 =
(
    format "\n--- TEST PART 10 : SELECTED TESSELLATE TARGET ---\n"

    geometry_diagnostics_modifier_test_node = createGeometryDiagnosticsTestBox()

    if not isGeometryDiagnosticsEditablePolyNode geometry_diagnostics_modifier_test_node then
    (
        geometryDiagnosticsTestCheck false "Modifier-path test created an Editable Poly box."
        return false
    )

    local base_poly = geometry_diagnostics_modifier_test_node.baseObject

    geometry_diagnostics_modifier_test_base_vertex_count = polyop.getNumVerts base_poly
    geometry_diagnostics_modifier_test_tessellate_mod = addGeometryDiagnosticsTestTessellation geometry_diagnostics_modifier_test_node

    geometryDiagnosticsTestCheck (geometry_diagnostics_modifier_test_tessellate_mod != undefined) "Tessellate paint target was added through modPanel.addModToSelection."

    if geometry_diagnostics_modifier_test_tessellate_mod == undefined then return false

    geometryDiagnosticsTestCheck (modPanel.getCurrentObject() == geometry_diagnostics_modifier_test_tessellate_mod) "Tessellate remains selected in the Modify panel."
    geometryDiagnosticsTestCheck (geometry_diagnostics_modifier_test_tessellate_mod.faceType == 1) "Tessellate faceType is 1."
    geometryDiagnosticsTestCheck (geometry_diagnostics_modifier_test_tessellate_mod.type == 0) "Tessellate type is 0."
    geometryDiagnosticsTestCheck (geometry_diagnostics_modifier_test_tessellate_mod.tension == 0) "Tessellate tension is 0."
    geometryDiagnosticsTestCheck (geometry_diagnostics_modifier_test_tessellate_mod.iterations == 0) "Tessellate iterations is 0."

    local target_result = ensureGeometryDiagnosticsPainterTarget geometry_diagnostics_modifier_test_node

    geometryDiagnosticsTestCheck target_result "Geometry Diagnostics bound VertexColorPainter to the selected Tessellate modifier."
    geometryDiagnosticsTestCheck (target_result and VertexColorPainter.backend_type == #vertexPaint) "Selected Tessellate uses the PaintLayerMod backend."
    geometryDiagnosticsTestCheck (target_result and VertexColorPainter.target_stack_mod == geometry_diagnostics_modifier_test_tessellate_mod) "Painter target is the exact selected Tessellate instance."

    if not target_result then return false

    geometry_diagnostics_modifier_test_evaluated_vertex_count = getGeometryDiagnosticsEvaluatedVertexCount geometry_diagnostics_modifier_test_node
    geometry_diagnostics_modifier_test_new_vertex_ids = #{21..26}

    format "BASE EDITABLE POLY VERTICES: %\n" geometry_diagnostics_modifier_test_base_vertex_count
    format "TESSELLATE TARGET VERTICES: %\n" VertexColorPainter.vertex_count
    format "FULL EVALUATED STACK VERTICES: %\n" geometry_diagnostics_modifier_test_evaluated_vertex_count
    format "TESSELLATE PAINT TEST VERTICES: %\n" geometry_diagnostics_modifier_test_new_vertex_ids

    geometryDiagnosticsTestCheck (geometry_diagnostics_modifier_test_base_vertex_count == 8) "Base Editable Poly still has 8 geometry vertices."
    geometryDiagnosticsTestCheck (VertexColorPainter.vertex_count >= 26) "Selected Tessellate target contains generated vertices 21 through 26."
    geometryDiagnosticsTestCheck (geometry_diagnostics_modifier_test_new_vertex_ids.numberSet == 6) "Generated-vertex test targets exactly vertices 21 through 26."
    geometryDiagnosticsTestCheck (geometry_diagnostics_modifier_test_evaluated_vertex_count == VertexColorPainter.vertex_count) "Full evaluated stack matches the selected Tessellate topology before paint-layer insertion."
    geometryDiagnosticsTestCheck (getGeometryDiagnosticsPaintLayerMod geometry_diagnostics_modifier_test_node == undefined) "PaintLayerMod does not exist before selected-modifier paint."

    geometry_diagnostics_test_passed
    -- return
)


/*
Test part 11 paints face colors while Tessellate is selected in the Modify panel.
VertexColorPainter must create its owned PaintLayerMod immediately above that exact selected modifier.
*/
function partOfTest11 =
(
    format "\n--- TEST PART 11 : PAINT FACE COLORS ON SELECTED MODIFIER ---\n"

    if not isValidNode geometry_diagnostics_modifier_test_node then
    (
        geometryDiagnosticsTestCheck false "Part 11 has a valid modifier-path test node."
        return false
    )

    local paint_result = paintGeometryDiagnosticsTestBox geometry_diagnostics_modifier_test_node
    local paint_layer_mod = getGeometryDiagnosticsPaintLayerMod geometry_diagnostics_modifier_test_node

    geometryDiagnosticsTestCheck paint_result "Face colors painted through VertexColorPainter on the selected Tessellate topology."
    geometryDiagnosticsTestCheck (paint_layer_mod != undefined) "Selected modifier face paint created the painter-owned PaintLayerMod."
    geometryDiagnosticsTestCheck (VertexColorPainter.target_stack_mod == geometry_diagnostics_modifier_test_tessellate_mod) "Face painting kept the exact selected Tessellate as the topology target."

    if paint_layer_mod != undefined then
    (
        local paint_layer_index = VertexColorPainter.getPaintLayerStackIndex()
        local tessellate_index = VertexColorPainter.getCurrentTargetStackIndex()

        geometryDiagnosticsTestCheck (tessellate_index == (paint_layer_index + 1)) "PaintLayerMod sits immediately above the selected Tessellate modifier."
    )

    paint_result
    -- return
)


/*
Test part 12 paints only vertices generated by the selected Tessellate modifier.
The same painter-owned PaintLayerMod must accept evaluated-only vertex IDs 21 through 26.
*/
function partOfTest12 =
(
    format "\n--- TEST PART 12 : PAINT TESSELLATE-GENERATED VERTICES ---\n"

    if not isValidNode geometry_diagnostics_modifier_test_node then
    (
        geometryDiagnosticsTestCheck false "Part 12 has a valid modifier-path test node."
        return false
    )

    local paint_result = paintGeometryDiagnosticsVertices \
        geometry_diagnostics_modifier_test_node \
        geometry_diagnostics_modifier_test_new_vertex_ids \
        geometry_diagnostics_test_vertex_color

    geometryDiagnosticsTestCheck paint_result "Generated Tessellate vertices were painted through VertexColorPainter."

    if not paint_result then return false

    local base_poly = geometry_diagnostics_modifier_test_node.baseObject
    local paint_layer_mod = getGeometryDiagnosticsPaintLayerMod geometry_diagnostics_modifier_test_node

    geometryDiagnosticsTestCheck (paint_layer_mod != undefined) "Painter-owned PaintLayerMod remains available for validation."

    if paint_layer_mod == undefined then return false

    local paint_state = acquireGeometryDiagnosticsPaintState geometry_diagnostics_modifier_test_node paint_layer_mod

    geometryDiagnosticsTestCheck (paint_state != undefined) "VertexPaint state can be acquired from the selected-modifier stack."

    if paint_state == undefined then return false

    local expected_paint_point = geometryDiagnosticsColorToPaintPoint4 geometry_diagnostics_test_vertex_color
    local raw_color_count = paint_state.GetNumRawColors()
    local base_map_vert_count = polyop.getNumMapVerts base_poly 0
    local base_colors_unchanged = true
    local painted_new_vertex_count = 0

    for vertex_id in geometry_diagnostics_modifier_test_new_vertex_ids do
    (
        if paint_state.GetVertAverageColor vertex_id == expected_paint_point then
        (
            painted_new_vertex_count += 1
        )
    )

    for map_vert_id = 1 to base_map_vert_count do
    (
        if polyop.getMapVert base_poly 0 map_vert_id != [1.0, 1.0, 1.0] then
        (
            base_colors_unchanged = false
        )
    )

    format "VERTEXPAINT RAW COLOR ENTRIES: %\n" raw_color_count
    format "BASE CHANNEL-0 MAP VERTICES: %\n" base_map_vert_count
    format "TESSELLATE VERTICES REQUESTED: %\n" geometry_diagnostics_modifier_test_new_vertex_ids.numberSet
    format "TESSELLATE VERTICES VERIFIED ORANGE: %\n" painted_new_vertex_count

    geometryDiagnosticsTestCheck (paint_layer_mod.mapChannel == 0) "PaintLayerMod targets channel 0."
    geometryDiagnosticsTestCheck paint_layer_mod.layerIsolated "PaintLayerMod ignores underlying baked colors."
    geometryDiagnosticsTestCheck (raw_color_count > 24) "VertexPaint state sees the Tessellate-generated topology."
    geometryDiagnosticsTestCheck (painted_new_vertex_count == geometry_diagnostics_modifier_test_new_vertex_ids.numberSet) "Every requested Tessellate-generated vertex stores the orange diagnostic color."
    geometryDiagnosticsTestCheck (base_map_vert_count == 24) "Base channel-0 topology still has 24 split map vertices."
    geometryDiagnosticsTestCheck base_colors_unchanged "Base channel-0 color values stayed untouched."

    paint_layer_mod.ReleasePaintState geometry_diagnostics_modifier_test_node paint_state

    geometry_diagnostics_test_passed
    -- return
)


/*
Test part 13 removes only the painter-owned PaintLayerMod.
The selected Tessellate topology target and its evaluated vertex count must remain intact.
*/
function partOfTest13 =
(
    format "\n--- TEST PART 13 : RESTORE SELECTED-MODIFIER PAINT ---\n"

    if not isValidNode geometry_diagnostics_modifier_test_node then
    (
        geometryDiagnosticsTestCheck false "Part 13 has a valid modifier-path test node."
        return false
    )

    local restore_result = restoreGeometryDiagnosticsColors geometry_diagnostics_modifier_test_node
    local tessellate_preserved = false

    for stack_mod in geometry_diagnostics_modifier_test_node.modifiers do
    (
        if stack_mod == geometry_diagnostics_modifier_test_tessellate_mod then
        (
            tessellate_preserved = true
        )
    )

    geometryDiagnosticsTestCheck restore_result "Selected-modifier paint restore removed the painter-owned PaintLayerMod."
    geometryDiagnosticsTestCheck (getGeometryDiagnosticsPaintLayerMod geometry_diagnostics_modifier_test_node == undefined) "No painter-owned PaintLayerMod remains."
    geometryDiagnosticsTestCheck tessellate_preserved "Exact selected Tessellate modifier was preserved."
    geometryDiagnosticsTestCheck (VertexColorPainter.getCurrentTargetStackIndex() == 1) "Tessellate target returned to stack index 1 after paint-layer removal."
    geometryDiagnosticsTestCheck (getGeometryDiagnosticsEvaluatedVertexCount geometry_diagnostics_modifier_test_node == geometry_diagnostics_modifier_test_evaluated_vertex_count) "Evaluated Tessellate vertex count was preserved."

    geometry_diagnostics_test_passed
    -- return
)


/*
Test part 14 rebuilds the final selected-modifier visual state.
Face colors and generated-vertex orange are both written through VertexColorPainter above the selected Tessellate target.
*/
function partOfTest14 =
(
    format "\n--- TEST PART 14 : FINAL SELECTED-MODIFIER VISUAL STATE ---\n"

    if not isValidNode geometry_diagnostics_modifier_test_node then
    (
        geometryDiagnosticsTestCheck false "Part 14 has a valid modifier-path test node."
        return false
    )

    select geometry_diagnostics_modifier_test_node
    max modify mode
    modPanel.setCurrentObject geometry_diagnostics_modifier_test_tessellate_mod node:geometry_diagnostics_modifier_test_node ui:true

    local face_paint_result = paintGeometryDiagnosticsTestBox geometry_diagnostics_modifier_test_node
    local vertex_paint_result = false

    if face_paint_result then
    (
        vertex_paint_result = paintGeometryDiagnosticsVertices \
            geometry_diagnostics_modifier_test_node \
            geometry_diagnostics_modifier_test_new_vertex_ids \
            geometry_diagnostics_test_vertex_color
    )

    local paint_layer_mod = getGeometryDiagnosticsPaintLayerMod geometry_diagnostics_modifier_test_node

    geometryDiagnosticsTestCheck face_paint_result "Final face colors were painted on the selected Tessellate topology."
    geometryDiagnosticsTestCheck vertex_paint_result "Final generated Tessellate vertices were painted orange."
    geometryDiagnosticsTestCheck (paint_layer_mod != undefined) "Final stack contains the painter-owned PaintLayerMod."

    if paint_layer_mod != undefined then
    (
        geometryDiagnosticsTestCheck (VertexColorPainter.getCurrentTargetStackIndex() == (VertexColorPainter.getPaintLayerStackIndex() + 1)) "Final PaintLayerMod sits immediately above Tessellate."
    )

    completeRedraw()

    format "\nFINAL MODIFIER TEST STATE:\n"
    format "- Editable Poly base remains unchanged\n"
    format "- Tessellate is the selected evaluated topology target\n"
    format "- Vertex Color Painter PaintLayerMod sits immediately above Tessellate\n"
    format "- all selected-target faces use the repeating diagnostic palette\n"
    format "- generated vertices % are orange in the diagnostic paint layer\n" geometry_diagnostics_modifier_test_new_vertex_ids
    format "\nFINAL TEST STATUS: %\n" (if geometry_diagnostics_test_passed then "PASS" else "FAIL")
    format "The selected-modifier regression object is intentionally left in the scene.\n"

    geometry_diagnostics_test_passed
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
partOfTest10()
partOfTest11()
partOfTest12()
partOfTest13()
partOfTest14()
