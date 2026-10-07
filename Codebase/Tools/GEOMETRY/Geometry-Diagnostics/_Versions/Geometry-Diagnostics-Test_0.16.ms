/*
Geometry Diagnostics backend test.
Runs direct channel-0 tests plus evaluated-stack VertexPaint tests on tessellation-created vertices.
*/

global geometry_diagnostics_test_file_version = "0.16"
global geometry_diagnostics_test_project_version = "0.18"
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
global geometry_diagnostics_test_base_ortho_result
global geometry_diagnostics_test_modifier_ortho_result

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
        local tessellate_mod = geometry_diagnostics_test_scene_node.modifiers[#Tessellate]

        geometryDiagnosticsTestCheck (tessellate_mod != undefined) "Generated test box includes the Tessellate modifier."

        if tessellate_mod != undefined then
        (
            geometryDiagnosticsTestCheck (tessellate_mod.faceType == 1) "Test-box Tessellate faceType is 1."
            geometryDiagnosticsTestCheck (tessellate_mod.type == 0) "Test-box Tessellate type is 0."
            geometryDiagnosticsTestCheck (tessellate_mod.tension == 0) "Test-box Tessellate tension is 0."
            geometryDiagnosticsTestCheck (tessellate_mod.iterations == 0) "Test-box Tessellate iterations is 0."
        )

        select geometry_diagnostics_test_scene_node
        max modify mode
        modPanel.setCurrentObject geometry_diagnostics_test_scene_node.baseObject node:geometry_diagnostics_test_scene_node ui:true

        geometryDiagnosticsTestCheck (modPanel.getCurrentObject() == geometry_diagnostics_test_scene_node.baseObject) "Editable Poly base is selected for direct channel-0 tests."
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
The test-box creator already adds the canonical Tessellate target and leaves it selected.
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
    geometry_diagnostics_modifier_test_tessellate_mod = geometry_diagnostics_modifier_test_node.modifiers[#Tessellate]

    geometryDiagnosticsTestCheck (geometry_diagnostics_modifier_test_tessellate_mod != undefined) "Created test box already contains the Tessellate paint target."

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


/*
Test part 15 validates base-box horizontal/vertical classification at explicit 0.01mm precision.
The 12 visible box edges must resolve to eight horizontal edges, four vertical edges, and zero tolerated or invalid edges.
*/
function partOfTest15 =
(
    format "\n--- TEST PART 15 : BASE ORTHO EDGE CLASSIFICATION ---\n"

    if not isValidNode geometry_diagnostics_test_scene_node then
    (
        geometryDiagnosticsTestCheck false "Part 15 has a valid direct-base test node."
        return false
    )

    select geometry_diagnostics_test_scene_node
    max modify mode
    modPanel.setCurrentObject geometry_diagnostics_test_scene_node.baseObject node:geometry_diagnostics_test_scene_node ui:true

    geometry_diagnostics_test_base_ortho_result = analyzeGeometryDiagnosticsOrthoEdges geometry_diagnostics_test_scene_node "0.01mm" "1.00mm"

    geometryDiagnosticsTestCheck (resolveGeometryDiagnosticsPositionPrecision "1mm" == units.decodeValue "1mm") "1mm position precision resolves through explicit unit conversion."
    geometryDiagnosticsTestCheck (resolveGeometryDiagnosticsPositionPrecision "0.1mm" == units.decodeValue "0.1mm") "0.1mm position precision resolves through explicit unit conversion."
    geometryDiagnosticsTestCheck (resolveGeometryDiagnosticsPositionPrecision "0.01mm" == units.decodeValue "0.01mm") "0.01mm position precision resolves through explicit unit conversion."
    geometryDiagnosticsTestCheck (resolveGeometryDiagnosticsPositionPrecision "invalid" == undefined) "Unsupported position precision is refused."
    geometryDiagnosticsTestCheck (resolveGeometryDiagnosticsOrthoTolerance "1.00mm" == units.decodeValue "1.00mm") "1.00mm ortho tolerance resolves through explicit unit conversion."
    geometryDiagnosticsTestCheck (resolveGeometryDiagnosticsOrthoTolerance "10.00mm" == units.decodeValue "10.00mm") "10.00mm ortho tolerance resolves through explicit unit conversion."
    geometryDiagnosticsTestCheck (resolveGeometryDiagnosticsOrthoTolerance "invalid" == undefined) "Unsupported ortho tolerance is refused."

    geometryDiagnosticsTestCheck (geometry_diagnostics_test_base_ortho_result != undefined) "Base ortho-edge analysis returned a result."

    if geometry_diagnostics_test_base_ortho_result == undefined then return false

    geometryDiagnosticsTestCheck (geometry_diagnostics_test_base_ortho_result.visible_edges.numberSet == 12) "Base box has 12 visible/selectable edges."
    geometryDiagnosticsTestCheck (geometry_diagnostics_test_base_ortho_result.horizontal_edges.numberSet == 8) "Base box has eight horizontal edges."
    geometryDiagnosticsTestCheck (geometry_diagnostics_test_base_ortho_result.vertical_edges.numberSet == 4) "Base box has four vertical edges."
    geometryDiagnosticsTestCheck (geometry_diagnostics_test_base_ortho_result.orthogonal_edges.numberSet == 12) "All 12 base-box edges are horizontal or vertical."
    geometryDiagnosticsTestCheck (geometry_diagnostics_test_base_ortho_result.valid_skewed_edges.numberSet == 0) "Base box has no tolerated skewed/sloped edges."
    geometryDiagnosticsTestCheck (geometry_diagnostics_test_base_ortho_result.invalid_edges.numberSet == 0) "Base box has no invalid skewed/sloped edges."
    geometryDiagnosticsTestCheck (geometry_diagnostics_test_base_ortho_result.suspicious_edges == geometry_diagnostics_test_base_ortho_result.invalid_edges) "Suspicious compatibility set aliases invalid edges."
    geometryDiagnosticsTestCheck (geometry_diagnostics_test_base_ortho_result.vertex_data.count == 0) "Zero invalid base edges produce zero invalid face-corner rows."

    local all_base_deviations_zero = true

    for edge_id in geometry_diagnostics_test_base_ortho_result.visible_edges do
    (
        if geometry_diagnostics_test_base_ortho_result.edge_deviation_distances[edge_id] != 0.0 then
        (
            all_base_deviations_zero = false
        )
    )

    geometryDiagnosticsTestCheck all_base_deviations_zero "Every exact base-box edge stores zero off-axis distance."

    geometry_diagnostics_test_passed
    -- return
)


/*
Test part 16 proves one edge can be colored on only one polygon face through exact face-corner data.
The two corners on the chosen face turn red while the same geometry edge remains white on its neighboring face.
*/
function partOfTest16 =
(
    format "\n--- TEST PART 16 : FACE-LOCAL EDGE COLOR ---\n"

    if not isValidNode geometry_diagnostics_test_scene_node then
    (
        geometryDiagnosticsTestCheck false "Part 16 has a valid direct-base test node."
        return false
    )

    if VertexColorPainter.source_node == geometry_diagnostics_test_scene_node then
    (
        restoreGeometryDiagnosticsColors geometry_diagnostics_test_scene_node
    )

    select geometry_diagnostics_test_scene_node
    max modify mode
    modPanel.setCurrentObject geometry_diagnostics_test_scene_node.baseObject node:geometry_diagnostics_test_scene_node ui:true

    local target_result = ensureGeometryDiagnosticsPainterTarget geometry_diagnostics_test_scene_node

    geometryDiagnosticsTestCheck target_result "Direct-base painter target is ready for face-local edge paint."

    if not target_result then return false

    local target_edge_id = 1
    local edge_vertices = VertexColorPainter.edge_vertices[target_edge_id]
    local edge_faces = VertexColorPainter.edge_faces[target_edge_id]

    geometryDiagnosticsTestCheck (edge_vertices != undefined and edge_vertices.count == 2) "Test edge has two geometry endpoints."
    geometryDiagnosticsTestCheck (edge_faces != undefined and edge_faces.count == 2) "Test edge has two adjacent polygon faces."

    if edge_vertices == undefined or edge_vertices.count != 2 or edge_faces == undefined or edge_faces.count != 2 then return false

    local target_face_id = edge_faces[1]
    local neighbor_face_id = edge_faces[2]
    local red_color = color 255 0 0
    local red_point = geometryDiagnosticsColorToMapPoint red_color
    local white_point = [1.0, 1.0, 1.0]
    local paint_result = paintGeometryDiagnosticsEdgeOnFace geometry_diagnostics_test_scene_node target_edge_id target_face_id red_color

    geometryDiagnosticsTestCheck paint_result "One edge painted on one polygon face."

    if not paint_result then return false

    local target_map_a = VertexColorPainter.getMapVertexForCorner edge_vertices[1] target_face_id
    local target_map_b = VertexColorPainter.getMapVertexForCorner edge_vertices[2] target_face_id
    local neighbor_map_a = VertexColorPainter.getMapVertexForCorner edge_vertices[1] neighbor_face_id
    local neighbor_map_b = VertexColorPainter.getMapVertexForCorner edge_vertices[2] neighbor_face_id
    local base_poly = geometry_diagnostics_test_scene_node.baseObject

    geometryDiagnosticsTestCheck (polyop.getMapVert base_poly 0 target_map_a == red_point) "First target-face edge corner is red."
    geometryDiagnosticsTestCheck (polyop.getMapVert base_poly 0 target_map_b == red_point) "Second target-face edge corner is red."
    geometryDiagnosticsTestCheck (polyop.getMapVert base_poly 0 neighbor_map_a == white_point) "First neighboring-face edge corner remains white."
    geometryDiagnosticsTestCheck (polyop.getMapVert base_poly 0 neighbor_map_b == white_point) "Second neighboring-face edge corner remains white."

    local restore_result = restoreGeometryDiagnosticsColors geometry_diagnostics_test_scene_node
    geometryDiagnosticsTestCheck restore_result "Face-local edge paint restored to the original base map."

    geometry_diagnostics_test_passed
    -- return
)


/*
Test part 17 runs the complete CHECK ORTHO EDGES diagnostic on the selected Tessellate target.
The generated topology must contain horizontal, vertical, and invalid edges while the full visible domain receives the white / green-blue / yellow-red severity overlay.
*/
function partOfTest17 =
(
    format "\n--- TEST PART 17 : CHECK ORTHO EDGES ON TESSELLATE ---\n"

    if not isValidNode geometry_diagnostics_modifier_test_node then
    (
        geometryDiagnosticsTestCheck false "Part 17 has a valid modifier-path test node."
        return false
    )

    if VertexColorPainter.source_node == geometry_diagnostics_modifier_test_node then
    (
        restoreGeometryDiagnosticsColors geometry_diagnostics_modifier_test_node
    )

    select geometry_diagnostics_modifier_test_node
    max modify mode
    modPanel.setCurrentObject geometry_diagnostics_modifier_test_tessellate_mod node:geometry_diagnostics_modifier_test_node ui:true

    geometry_diagnostics_test_modifier_ortho_result = checkGeometryDiagnosticsOrthoEdges geometry_diagnostics_modifier_test_node "0.01mm" "1.00mm"

    geometryDiagnosticsTestCheck (geometry_diagnostics_test_modifier_ortho_result != undefined) "Tessellate ortho-edge diagnostic completed."

    if geometry_diagnostics_test_modifier_ortho_result == undefined then return false

    local ortho_result = geometry_diagnostics_test_modifier_ortho_result
    local reconstructed_visible = copy ortho_result.orthogonal_edges
    reconstructed_visible += ortho_result.valid_skewed_edges
    reconstructed_visible += ortho_result.invalid_edges

    geometryDiagnosticsTestCheck (ortho_result.visible_edges.numberSet > 0) "Tessellate diagnostic has visible edges."
    geometryDiagnosticsTestCheck (ortho_result.horizontal_edges.numberSet > 0) "Tessellate diagnostic finds horizontal edges."
    geometryDiagnosticsTestCheck (ortho_result.vertical_edges.numberSet > 0) "Tessellate diagnostic finds vertical edges."
    geometryDiagnosticsTestCheck (ortho_result.invalid_edges.numberSet > 0) "Tessellate diagnostic finds invalid edges above ortho tolerance."
    geometryDiagnosticsTestCheck (ortho_result.suspicious_edges == ortho_result.invalid_edges) "Suspicious compatibility set matches invalid edges."
    geometryDiagnosticsTestCheck (reconstructed_visible == ortho_result.visible_edges) "Valid ortho plus tolerated plus invalid edges reconstruct the complete visible-edge domain."
    geometryDiagnosticsTestCheck (ortho_result.vertex_data.count > 0) "Invalid edges are converted to face-corner vertex data."
    geometryDiagnosticsTestCheck (ortho_result.edge_deviation_distances.count == VertexColorPainter.edge_count) "Ortho result stores one indexed distance-severity slot per target edge."
    geometryDiagnosticsTestCheck (getGeometryDiagnosticsPaintLayerMod geometry_diagnostics_modifier_test_node != undefined) "CHECK ORTHO EDGES creates the painter-owned PaintLayerMod on the Tessellate target."

    local base_poly = geometry_diagnostics_modifier_test_node.baseObject
    local base_map_vert_count = polyop.getNumMapVerts base_poly 0
    local base_colors_unchanged = true

    for map_vert_id = 1 to base_map_vert_count do
    (
        if polyop.getMapVert base_poly 0 map_vert_id != [1.0, 1.0, 1.0] then
        (
            base_colors_unchanged = false
        )
    )

    geometryDiagnosticsTestCheck base_colors_unchanged "Tessellate ortho-edge paint leaves the Editable Poly base channel untouched."

    completeRedraw()

    format "\nFINAL ORTHO DIAGNOSTIC STATE:\n"
    format "- Tessellate remains the selected topology target\n"
    format "- horizontal edges: %\n" ortho_result.horizontal_edges
    format "- vertical edges: %\n" ortho_result.vertical_edges
    format "- tolerated skewed/sloped edges: %\n" ortho_result.valid_skewed_edges
    format "- invalid skewed/sloped edges: %\n" ortho_result.invalid_edges
    format "- visible edges use severity colors: white valid ortho | green->blue tolerated | yellow->red invalid\n"
    format "\nFINAL TEST STATUS: %\n" (if geometry_diagnostics_test_passed then "PASS" else "FAIL")

    geometry_diagnostics_test_passed
    -- return
)


/*
Test part 18 verifies the principal-axis off-axis distance helper used by direction selection.
Z measures XY drift, X measures YZ drift, and Y measures XZ drift.
*/
function partOfTest18 =
(
    format "\n--- TEST PART 18 : PRINCIPAL AXIS OFF-AXIS DISTANCE ---\n"

    local z_data = getGeometryDiagnosticsPrincipalAxisData [0,0,0] [3,4,100]
    local x_data = getGeometryDiagnosticsPrincipalAxisData [0,0,0] [100,3,4]
    local y_data = getGeometryDiagnosticsPrincipalAxisData [0,0,0] [3,100,4]

    geometryDiagnosticsTestCheck (z_data.count == 2 and z_data[1] == #z and z_data[2] == 5.0) "Z-dominant edge uses XY drift distance."
    geometryDiagnosticsTestCheck (x_data.count == 2 and x_data[1] == #x and x_data[2] == 5.0) "X-dominant edge uses YZ drift distance."
    geometryDiagnosticsTestCheck (y_data.count == 2 and y_data[1] == #y and y_data[2] == 5.0) "Y-dominant edge uses XZ drift distance."

    geometry_diagnostics_test_passed
    -- return
)



/*
Test part 19 verifies position-difference direction classification without scene mutation.
Dominant axis chooses Z, X, or Y; off-axis drift then decides LMB within-precision versus RMB beyond-precision.
*/
function partOfTest19 =
(
    format "\n--- TEST PART 19 : DIRECTION BUTTON POSITION DIFFERENCE ---\n"

    local position_difference = 0.1
    local origin = [0.0, 0.0, 0.0]
    local vertical_exact = [0.05, 0.05, 10.0]
    local vertical_skewed = [0.2, 0.0, 10.0]
    local horizontal_x_exact = [10.0, 0.05, 0.05]
    local horizontal_x_sloped = [10.0, 0.0, 0.2]
    local horizontal_y_exact = [0.05, 10.0, 0.05]
    local horizontal_y_sloped = [0.2, 10.0, 0.0]

    geometryDiagnosticsTestCheck \
        (geometryDiagnosticsDirectionMatches origin vertical_exact #vertical #exact position_difference) \
        "LMB vertical accepts Z-dominant XY drift within position difference."

    geometryDiagnosticsTestCheck \
        (not (geometryDiagnosticsDirectionMatches origin vertical_skewed #vertical #exact position_difference)) \
        "LMB vertical rejects Z-dominant XY drift above position difference."

    geometryDiagnosticsTestCheck \
        (geometryDiagnosticsDirectionMatches origin vertical_skewed #vertical #skewed position_difference) \
        "RMB vertical accepts Z-dominant XY drift above position difference."

    geometryDiagnosticsTestCheck \
        (not (geometryDiagnosticsDirectionMatches origin horizontal_x_sloped #vertical #skewed position_difference)) \
        "Vertical RMB does not absorb an X-dominant horizontal edge."

    geometryDiagnosticsTestCheck \
        (geometryDiagnosticsDirectionMatches origin horizontal_x_exact #horizontal #exact position_difference) \
        "LMB horizontal X-direction uses YZ drift within position difference."

    geometryDiagnosticsTestCheck \
        (geometryDiagnosticsDirectionMatches origin horizontal_x_sloped #horizontal #skewed position_difference) \
        "RMB horizontal X-direction uses YZ drift above position difference."

    geometryDiagnosticsTestCheck \
        (geometryDiagnosticsDirectionMatches origin horizontal_y_exact #horizontal #exact position_difference) \
        "LMB horizontal Y-direction uses XZ drift within position difference."

    geometryDiagnosticsTestCheck \
        (geometryDiagnosticsDirectionMatches origin horizontal_y_sloped #horizontal #skewed position_difference) \
        "RMB horizontal Y-direction uses XZ drift above position difference."

    geometry_diagnostics_test_passed
    -- return
)



/*
Test part 20 verifies the three-level distance-based orthogonal color ramp independently of scene geometry.
Valid ortho is white, tolerated skew/sloping blends green to blue, and invalid skew/sloping blends yellow to red.
*/
function partOfTest20 =
(
    format "\n--- TEST PART 20 : ORTHO DISTANCE SEVERITY COLOR RAMP ---\n"

    local position_precision = 0.01
    local ortho_tolerance = 1.0
    local white_color = getGeometryDiagnosticsOrthoSeverityColor 0.005 position_precision ortho_tolerance
    local white_boundary_color = getGeometryDiagnosticsOrthoSeverityColor position_precision position_precision ortho_tolerance
    local valid_start_color = getGeometryDiagnosticsOrthoSeverityColor 0.02 position_precision ortho_tolerance
    local valid_mid_color = getGeometryDiagnosticsOrthoSeverityColor 0.505 position_precision ortho_tolerance
    local blue_color = getGeometryDiagnosticsOrthoSeverityColor ortho_tolerance position_precision ortho_tolerance
    local invalid_start_color = getGeometryDiagnosticsOrthoSeverityColor 1.001 position_precision ortho_tolerance
    local invalid_mid_color = getGeometryDiagnosticsOrthoSeverityColor 1.5 position_precision ortho_tolerance
    local red_color = getGeometryDiagnosticsOrthoSeverityColor 2.0 position_precision ortho_tolerance
    local beyond_red_color = getGeometryDiagnosticsOrthoSeverityColor 4.0 position_precision ortho_tolerance
    local expected_white = color 255 255 255
    local expected_blue = color 0 0 255
    local expected_red = color 255 0 0

    geometryDiagnosticsTestCheck (white_color == expected_white) "Deviation inside postion preccision is white."
    geometryDiagnosticsTestCheck (white_boundary_color == expected_white) "Postion preccision boundary remains valid-ortho white."
    geometryDiagnosticsTestCheck (valid_start_color.r == 0.0 and valid_start_color.g > valid_start_color.b) "Tolerated skew/sloping starts predominantly green."
    geometryDiagnosticsTestCheck (valid_mid_color.r == 0.0 and valid_mid_color.g > 0.0 and valid_mid_color.b > 0.0) "Tolerated skew/sloping blends green toward blue."
    geometryDiagnosticsTestCheck (blue_color == expected_blue) "Ortho tolerance boundary is blue and still valid."
    geometryDiagnosticsTestCheck (invalid_start_color.r > 0.0 and invalid_start_color.g > 0.0 and invalid_start_color.b == 0.0) "Invalid range starts in yellow."
    geometryDiagnosticsTestCheck (invalid_mid_color.r == 255.0 and invalid_mid_color.g > 0.0 and invalid_mid_color.g < 255.0) "Invalid range blends yellow toward red."
    geometryDiagnosticsTestCheck (red_color == expected_red) "Twice ortho tolerance reaches red."
    geometryDiagnosticsTestCheck (beyond_red_color == expected_red) "Deviation above twice ortho tolerance stays clamped red."

    geometry_diagnostics_test_passed
    -- return
)

/*
Test part 21 verifies that a direction button stores its result as a real Edit Poly edge selection.
The owned modifier is activated in Modify mode at Edge level and the selection is verified by read-back.
*/
function partOfTest21 =
(
    format "\n--- TEST PART 21 : DIRECTION BUTTON EDGE SELECTION ---\n"

    local test_node = undefined
    local test_passed = false

    try
    (
        test_node = box name:(uniqueName "GeometryDiagnostics_DirectionSelectionTest") length:100.0 width:100.0 height:100.0
        convertTo test_node Editable_Poly
        test_node.baseObject.showCage = off
        select test_node

        local direction_result = checkGeometryDiagnosticsDirectionEdges test_node #vertical #exact "0.01mm"
        local selection_edit_poly_mod = if direction_result != undefined then direction_result.selection_edit_poly_mod else undefined
        local actual_selection = if selection_edit_poly_mod != undefined then \
            EditPolyMod.GetSelection selection_edit_poly_mod #Edge node:test_node else #{}
        local expected_selection = if direction_result != undefined then direction_result.edge_ids else #{}

        geometryDiagnosticsTestCheck (direction_result != undefined) "Direction button selection returned a result."
        geometryDiagnosticsTestCheck (direction_result != undefined and expected_selection.numberSet == 4) "Box LMB vertical selects four vertical edges."
        geometryDiagnosticsTestCheck (direction_result != undefined and actual_selection == expected_selection) "Owned Edit Poly stores the exact requested edge BitArray."
        geometryDiagnosticsTestCheck (modPanel.getCurrentObject() == selection_edit_poly_mod) "Owned Geometry Diagnostics Edit Poly is active in Modify panel."
        geometryDiagnosticsTestCheck (subObjectLevel == 2) "Direction button leaves the tool at Edge sub-object level."
        geometryDiagnosticsTestCheck (selection_edit_poly_mod != undefined and selection_edit_poly_mod.useStackSelection == false) "Owned Edit Poly disables stack selection."
        geometryDiagnosticsTestCheck (selection_edit_poly_mod != undefined and selection_edit_poly_mod.showCage == off) "Owned Edit Poly cage stays off."

        test_passed = direction_result != undefined and actual_selection == expected_selection
    )
    catch
    (
        local exception_text = getCurrentException()
        format "Geometry Diagnostics TEST PART 21 ERROR | exception:%\n" exception_text
        geometryDiagnosticsTestCheck false "Direction button edge-selection workflow completed without exception."
        test_passed = false
    )

    if isValidNode test_node then
    (
        delete test_node
    )

    test_passed
    -- return
)


/*
Test part 22 verifies both LMB and RMB direction-button selection on one live Edit Poly adapter.
LMB selects the within-precision vertical edge; RMB replaces it with the beyond-precision vertical edges.
*/
function partOfTest22 =
(
    format "\n--- TEST PART 22 : DIRECTION BUTTON LMB/RMB SELECTION ---\n"

    local test_node = undefined
    local test_passed = false
    local position_precision = units.decodeValue "0.01mm"

    try
    (
        local point_a = [0.0, 0.0, 0.0]
        local point_b = [0.0, 0.0, position_precision * 100.0]
        local point_c = [position_precision * 2.0, 0.0, position_precision * 200.0]

        test_node = mesh \
            name:(uniqueName "GeometryDiagnostics_DirectionMouseTest") \
            vertices:#(point_a, point_b, point_c) \
            faces:#([1,2,3])

        convertTo test_node Editable_Poly
        test_node.baseObject.showCage = off
        select test_node

        local exact_result = checkGeometryDiagnosticsDirectionEdges test_node #vertical #exact "0.01mm"
        local selection_edit_poly_mod = if exact_result != undefined then exact_result.selection_edit_poly_mod else undefined
        local exact_actual_selection = if selection_edit_poly_mod != undefined then \
            EditPolyMod.GetSelection selection_edit_poly_mod #Edge node:test_node else #{}

        geometryDiagnosticsTestCheck (exact_result != undefined) "LMB vertical selection returned a result."
        geometryDiagnosticsTestCheck (exact_result != undefined and exact_result.edge_ids.numberSet == 1) "LMB vertical selects only the within-precision edge."
        geometryDiagnosticsTestCheck (exact_result != undefined and exact_actual_selection == exact_result.edge_ids) "LMB selection survives update and final read-back."

        local skewed_result = checkGeometryDiagnosticsDirectionEdges test_node #vertical #skewed "0.01mm"
        local skewed_edit_poly_mod = if skewed_result != undefined then skewed_result.selection_edit_poly_mod else undefined
        local skewed_actual_selection = if skewed_edit_poly_mod != undefined then \
            EditPolyMod.GetSelection skewed_edit_poly_mod #Edge node:test_node else #{}

        geometryDiagnosticsTestCheck (skewed_result != undefined) "RMB vertical selection returned a result."
        geometryDiagnosticsTestCheck (skewed_result != undefined and skewed_result.edge_ids.numberSet == 2) "RMB vertical selects the two beyond-precision edges."
        geometryDiagnosticsTestCheck (skewed_result != undefined and skewed_actual_selection == skewed_result.edge_ids) "RMB selection survives update and final read-back."
        geometryDiagnosticsTestCheck (selection_edit_poly_mod != undefined and skewed_edit_poly_mod == selection_edit_poly_mod) "LMB and RMB reuse the same exact session-owned Edit Poly."
        geometryDiagnosticsTestCheck (modPanel.getCurrentObject() == skewed_edit_poly_mod) "RMB leaves the owned Edit Poly active in Modify panel."
        geometryDiagnosticsTestCheck (subObjectLevel == 2) "RMB leaves Edge sub-object level active."

        test_passed = \
            exact_result != undefined and \
            skewed_result != undefined and \
            exact_actual_selection == exact_result.edge_ids and \
            skewed_actual_selection == skewed_result.edge_ids and \
            selection_edit_poly_mod == skewed_edit_poly_mod
    )
    catch
    (
        local exception_text = getCurrentException()
        format "Geometry Diagnostics TEST PART 22 ERROR | exception:%\n" exception_text
        geometryDiagnosticsTestCheck false "LMB/RMB direction-button selection workflow completed without exception."
        test_passed = false
    )

    if isValidNode test_node then
    (
        delete test_node
    )

    test_passed
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
partOfTest15()
partOfTest16()
partOfTest17()
partOfTest18()
partOfTest19()
partOfTest20()
partOfTest21()
partOfTest22()
