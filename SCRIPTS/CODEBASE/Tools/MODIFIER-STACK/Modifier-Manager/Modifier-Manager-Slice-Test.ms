/*
Modifier Manager Slice runtime tests (3ds Max 2023/2026).
File version: 0.022 | Project version: 0.022.
Run in a disposable scene; leaves its test node for inspection.
*/
global mm_slice_test_node

/* Assert one native Slice result and identify the failed behavior. */
function testSliceAssert result_value result_text =
(
    if not result_value then throw ("MM SLICE TEST | FAILED | " + result_text)
    format "MM SLICE TEST | PASS | %\n" result_text
    true -- return
)

/* Confirm negative, center and positive positions span half-bounds. */
function testSlicePercentMath =
(
    testSliceAssert (abs ((modifierSliceManager.percentToValue (-50.0) 50.0 (-100.0)) + 50.0) < 0.0001) "Minimum endpoint"
    testSliceAssert (abs (modifierSliceManager.percentToValue (-50.0) 50.0 0.0) < 0.0001) "Center endpoint"
    testSliceAssert (abs ((modifierSliceManager.percentToValue (-50.0) 50.0 100.0) - 50.0) < 0.0001) "Maximum endpoint"
    testSliceAssert (abs ((modifierSliceManager.valueToPercent (-50.0) 50.0 25.0) - 50.0) < 0.0001) "Readback percentage"
)

/* Exercise the actual Slice gizmo in Local, World and Gizmo coordinates. */
function testSliceGizmoTranslation =
(
    mm_slice_test_node = box name:(uniqueName "MM_SLICE_TEST_") width:100 length:80 height:60 pos:[120,60,10]
    target_mod = SliceModifier()
    addModifier mm_slice_test_node target_mod
    original_rotation = target_mod.slice_plane.rotation
    for axis_mode in #(#local, #world, #gizmo) do
    (
        modifierSliceManager.clearCache()
        testSliceAssert (modifierSliceManager.setAxisPercent mm_slice_test_node target_mod axis_mode 1 100.0) ((axis_mode as string) + " X move")
        percent_value = modifierSliceManager.getAxisPercent mm_slice_test_node target_mod axis_mode 1
        testSliceAssert (abs (percent_value - 100.0) < 0.01) ((axis_mode as string) + " X readback")
        testSliceAssert (modifierSliceManager.setAxisPercent mm_slice_test_node target_mod axis_mode 1 (-100.0)) ((axis_mode as string) + " reverse X move")
        testSliceAssert (abs ((modifierSliceManager.getAxisPercent mm_slice_test_node target_mod axis_mode 1) + 100.0) < 0.01) ((axis_mode as string) + " reverse X readback")
    )
    testSliceAssert (target_mod.slice_plane.rotation == original_rotation) "Slider movement preserves rotation"
    target_mod.slice_plane.rotation = ((angleaxis 35 [0,1,0]) as quat)
    rotated_gizmo = target_mod.slice_plane.rotation
    modifierSliceManager.clearCache()
    testSliceAssert (modifierSliceManager.setAxisPercent mm_slice_test_node target_mod #gizmo 2 100.0) "Rotated Gizmo Y move"
    testSliceAssert (abs ((modifierSliceManager.getAxisPercent mm_slice_test_node target_mod #gizmo 2) - 100.0) < 0.01) "Rotated Gizmo Y readback"
    testSliceAssert (target_mod.slice_plane.rotation == rotated_gizmo) "Rotated Gizmo orientation preserved"
    testSliceAssert ((classOf target_mod) == SliceModifier) "Modifier is native Slice"
)

/* Check the four exact native Slice type IDs and the Polygon/Face mapping. */
function testSliceModeMapping =
(
    target_mod = mm_slice_test_node.modifiers[1]
    for slice_id = 0 to 3 do
    (
        modifierSliceManager.setSliceType target_mod slice_id
        testSliceAssert (target_mod.Slice_Type == slice_id) ("Slice type " + (slice_id as string))
    )
    modifierSliceManager.setOperateMode mm_slice_test_node target_mod 2
    testSliceAssert (target_mod.Faces___Polygons_Toggle == 1) "Poly mode"
    modifierSliceManager.setOperateMode mm_slice_test_node target_mod 3
    testSliceAssert (target_mod.Faces___Polygons_Toggle == 0) "Mesh mode"
    modifierSliceManager.setOperateMode mm_slice_test_node target_mod 1
    testSliceAssert (target_mod.Faces___Polygons_Toggle == 0) "Automatic mode resolves base Box to Face"
    true -- return
)

/* Run independently of the UI and avoid deleting or resetting scene objects. */
(
    source_folder = getFilenamePath (getSourceFileName())
    fileIn (source_folder + "Modifier-Manager-FN.ms")
    fileIn (source_folder + "Modifier-Manager-Slice.ms")
    testSlicePercentMath()
    testSliceGizmoTranslation()
    testSliceModeMapping()
    format "MM SLICE TEST | FINISHED\n"
)
