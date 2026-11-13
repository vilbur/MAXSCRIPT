/*
Corner-Plane-Test v0.002
Runs numbered, undoable checks for the native-Plane extension.
Execute Corner-Plane.ms before this script.
*/


global corner_plane_test_node = undefined
global corner_plane_test_precision = "0.01mm"


/*
Compares two positions after temporary, explicit millimeter-precision rounding.
Returns true for coordinates that normalize to the same selected precision.
*/
function cornerPlaneTestPositionsMatch actual_point expected_point position_precision:"0.01mm" =
(
    local rounding_step = units.decodeValue position_precision


    local rounded_actual = [
        (round (actual_point.x / rounding_step)),
        (round (actual_point.y / rounding_step)),
        (round (actual_point.z / rounding_step))]


    local rounded_expected = [
        (round (expected_point.x / rounding_step)),
        (round (expected_point.y / rounding_step)),
        (round (expected_point.z / rounding_step))]


    local positions_match = (rounded_actual == rounded_expected)


    if not positions_match then
    (
        format "TEST POSITION FAILED | raw expected:% actual:% | rounded expected:% actual:% | precision:%\n" \
            expected_point actual_point rounded_expected rounded_actual position_precision
    )


    positions_match
    -- return
)


/*
Creates a Corner Plane fixture without deleting or resetting the existing scene.
Returns the new node used by the later test stages.
*/
function partOfTest1 =
(
    undo "Corner Plane Test 1 - Create" on
    (
        corner_plane_test_node = CornerPlane_CP \
            corner_width:100.0 corner_length:60.0 \
            corner_width_segs:3 corner_length_segs:2 \
            pos:[0,0,0] name:"CP_TEST_NATIVE_EXTENSION"
    )


    format "PART 1 | class:% | base:% | native delegate:%\n" \
        (classOf corner_plane_test_node) \
        (classOf corner_plane_test_node.baseObject) \
        (classOf corner_plane_test_node.baseObject.delegate)


    corner_plane_test_node
    -- return
)


/*
Checks corner anchoring and then changes the native delegated dimensions.
Leaves the object enlarged for inspection and emits detailed failures.
*/
function partOfTest2 =
(
    local test_node = corner_plane_test_node
    local first_bounds = nodeGetBoundingBox test_node test_node.transform
    local first_ok = (cornerPlaneTestPositionsMatch first_bounds[1] [0,0,0] position_precision:corner_plane_test_precision) and \
        (cornerPlaneTestPositionsMatch first_bounds[2] [100,60,0] position_precision:corner_plane_test_precision)


    undo "Corner Plane Test 2 - Resize" on
    (
        test_node.corner_width = 200.0
        test_node.corner_length = 120.0
    )


    local second_bounds = nodeGetBoundingBox test_node test_node.transform
    local second_ok = (cornerPlaneTestPositionsMatch second_bounds[1] [0,0,0] position_precision:corner_plane_test_precision) and \
        (cornerPlaneTestPositionsMatch second_bounds[2] [200,120,0] position_precision:corner_plane_test_precision)


    format "PART 2 | before:% | after:% | corner and bounds PASS:%\n" \
        first_bounds second_bounds (first_ok and second_ok)


    (first_ok and second_ok)
    -- return
)


/*
Rotates the plane and verifies its corner remains at the object's transform origin.
Reports the local bounding box after rotation and leaves the object in the scene.
*/
function partOfTest3 =
(
    local test_node = corner_plane_test_node


    undo "Corner Plane Test 3 - Rotate" on
    (
        test_node.rotation = (eulerAngles 0 0 45)
    )


    local transformed_bounds = nodeGetBoundingBox test_node test_node.transform
    local rotation_ok = (cornerPlaneTestPositionsMatch transformed_bounds[1] [0,0,0] position_precision:corner_plane_test_precision) and \
        (cornerPlaneTestPositionsMatch transformed_bounds[2] [200,120,0] position_precision:corner_plane_test_precision)


    format "PART 3 | rotated local bounds:% | PASS:%\n" transformed_bounds rotation_ok
    format "UNDO ORDER: Rotate, Resize, Create\n"


    rotation_ok
    -- return
)


/*
Moves the pivot horizontally while checking world geometry and signed direction.
Runs with the fixture already rotated by the previous stage.
*/
function partOfTest4 =
(
    local test_node = corner_plane_test_node
    local pivot_before = test_node.pivot
    local world_bounds_before = nodeGetBoundingBox test_node (matrix3 1)
    local pivot_expected = ([test_node.corner_width * test_node.corner_x_sign, 0, 0] * test_node.transform)
    local original_sign = test_node.corner_x_sign
    local action_ok = false


    undo "Corner Plane Test 4 - Flip Pivot" on
    (
        action_ok = test_node.baseObject.flipPivotHorizontally()
    )


    local world_bounds_after = nodeGetBoundingBox test_node (matrix3 1)
    local bounds_ok = (cornerPlaneTestPositionsMatch world_bounds_after[1] world_bounds_before[1] position_precision:corner_plane_test_precision) and \
        (cornerPlaneTestPositionsMatch world_bounds_after[2] world_bounds_before[2] position_precision:corner_plane_test_precision)
    local pivot_ok = cornerPlaneTestPositionsMatch test_node.pivot pivot_expected position_precision:corner_plane_test_precision
    local direction_ok = (test_node.corner_x_sign == -original_sign)


    format "PART 4 | pivot before:% after:% expected:% | geometry unchanged:% | direction flipped:% | PASS:%\\n" \
        pivot_before test_node.pivot pivot_expected bounds_ok direction_ok (action_ok and bounds_ok and pivot_ok and direction_ok)


    (action_ok and bounds_ok and pivot_ok and direction_ok)
    -- return
)


/*
Flips the pivot back and checks that the world-space geometry is unchanged.
*/
function partOfTest5 =
(
    local test_node = corner_plane_test_node
    local world_bounds_before = nodeGetBoundingBox test_node (matrix3 1)
    local action_ok = false


    undo "Corner Plane Test 5 - Flip Back" on
    (
        action_ok = test_node.baseObject.flipPivotHorizontally()
    )


    local world_bounds_after = nodeGetBoundingBox test_node (matrix3 1)
    local bounds_ok = (cornerPlaneTestPositionsMatch world_bounds_after[1] world_bounds_before[1] position_precision:corner_plane_test_precision) and \
        (cornerPlaneTestPositionsMatch world_bounds_after[2] world_bounds_before[2] position_precision:corner_plane_test_precision)
    local pivot_ok = cornerPlaneTestPositionsMatch test_node.pivot [0,0,0] position_precision:corner_plane_test_precision
    local direction_ok = (test_node.corner_x_sign == 1)


    format "PART 5 | pivot:% | geometry unchanged:% | direction restored:% | PASS:%\\n" \
        test_node.pivot bounds_ok direction_ok (action_ok and bounds_ok and pivot_ok and direction_ok)


    (action_ok and bounds_ok and pivot_ok and direction_ok)
    -- return
)


/*
Tests that Width growth after flipping preserves the new pivot corner.
Leaves the resized, flipped plane in the scene for visual inspection.
*/
function partOfTest6 =
(
    local test_node = corner_plane_test_node
    local flip_ok = false


    undo "Corner Plane Test 6 - Flip Again" on
    (
        flip_ok = test_node.baseObject.flipPivotHorizontally()
    )


    local pivot_before = test_node.pivot


    undo "Corner Plane Test 7 - Resize From Flipped Pivot" on
    (
        test_node.corner_width = 220.0
    )


    local local_bounds = nodeGetBoundingBox test_node test_node.transform
    local pivot_ok = cornerPlaneTestPositionsMatch test_node.pivot pivot_before position_precision:corner_plane_test_precision
    local bounds_ok = (cornerPlaneTestPositionsMatch local_bounds[1] [-220,0,0] position_precision:corner_plane_test_precision) and \
        (cornerPlaneTestPositionsMatch local_bounds[2] [0,120,0] position_precision:corner_plane_test_precision)
    local direction_ok = (test_node.corner_x_sign == -1)


    format "PART 6 | pivot retained:% | local bounds:% | direction:% | PASS:%\\n" \
        pivot_ok local_bounds test_node.corner_x_sign (flip_ok and pivot_ok and bounds_ok and direction_ok)
    format "UNDO ORDER: Resize From Flipped Pivot, Flip Again, Flip Back, Flip Pivot, Rotate, Resize, Create\\n"


    (flip_ok and pivot_ok and bounds_ok and direction_ok)
    -- return
)


partOfTest1()
partOfTest2()
partOfTest3()
partOfTest4()
partOfTest5()
partOfTest6()