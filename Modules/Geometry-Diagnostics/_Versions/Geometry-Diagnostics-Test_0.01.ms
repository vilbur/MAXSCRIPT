/*
Geometry Diagnostics backend test.
Runs one inspectable six-color box workflow in numbered stages.
*/

global geometry_diagnostics_test_file_version = "0.01"
global geometry_diagnostics_test_project_version = "0.01"
global geometry_diagnostics_project_version
global geometry_diagnostics_test_source_file = getSourceFileName()
global geometry_diagnostics_test_directory
global geometry_diagnostics_test_backend_path
global geometry_diagnostics_test_scene_node
global geometry_diagnostics_test_passed = true

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
geometry_diagnostics_test_backend_path = geometry_diagnostics_test_directory + "..\\Geometry-Diagnostics-FN.ms"

if not doesFileExist geometry_diagnostics_test_backend_path then
(
    throw ("Missing Geometry Diagnostics backend: " + geometry_diagnostics_test_backend_path)
)

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
Test part 1 creates the generated Editable Poly test box.
The scene-changing stage has its own named undo entry inside the backend operation.
*/
function partOfTest1 =
(
    format "\n--- TEST PART 1 : CREATE BOX ---\n"

    geometry_diagnostics_test_scene_node = createGeometryDiagnosticsTestBox()

    geometryDiagnosticsTestCheck (isGeometryDiagnosticsEditablePolyNode geometry_diagnostics_test_scene_node) "Generated node is Editable Poly."

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

    paint_result
    -- return
)


/*
Test part 4 validates that each polygon references four unique face-local map vertices.
It leaves the painted scene intact for visual inspection.
*/
function partOfTest4 =
(
    format "\n--- TEST PART 4 : VALIDATE PAINT MAP ---\n"

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

    dumpGeometryDiagnosticsChannelZero geometry_diagnostics_test_scene_node

    format "\nUNDO ORDER:\n"
    format "1. Geometry Diagnostics - Paint Face Colors -> restores the white split-color map.\n"
    format "2. Geometry Diagnostics - Create Test Box -> removes the generated box.\n"
    format "\nFINAL TEST STATUS: %\n" (if geometry_diagnostics_test_passed then "PASS" else "FAIL")
    format "The final painted test box is intentionally left in the scene.\n"

    geometry_diagnostics_test_passed
    -- return
)


partOfTest1()
partOfTest2()
partOfTest3()
partOfTest4()
