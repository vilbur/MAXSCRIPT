/*
Main-Toolbar-Extended-Test 0.001
Read/write native MAXScript API test; restores edited system UI settings.
*/

/*
Verifies one representative native setting per toolbar group.
Returns a Boolean and restores the original settings before returning.
*/
function testMainToolbarExtendedNativeStates =
(
    original_center = getCoordCenter()
    original_system = getRefCoordSys()
    original_ref_node = toolMode.coordSysNode
    original_axis = toolMode.axisConstraints
    original_grid = snapMode.getOSnapItemActive 4 1
    original_snap = snapMode.active
    original_angle = snapMode.angleSnapActive
    original_constant = preferences.constantReferenceSystem

    test_ok = true
    try
    (
        setCoordCenter #selection
        if (getCoordCenter() != #selection) then
        (
            format "[MTE TEST] FAILED | center expected:#selection actual:%\n" (getCoordCenter())
            test_ok = false
        )

        if original_system == #object and not (isValidNode original_ref_node) then
        (
            format "[MTE TEST] SKIPPED | cannot safely restore original grid/object reference without a node.\n"
        )
        else
        (
            toolMode.coordsys #world
            if (getRefCoordSys() != #world) then
            (
                format "[MTE TEST] FAILED | coords expected:#world actual:%\n" (getRefCoordSys())
                test_ok = false
            )
        )

        toolMode.axisConstraints = #YZ
        if (toolMode.axisConstraints != #YZ) then
        (
            format "[MTE TEST] FAILED | axis expected:#YZ actual:%\n" toolMode.axisConstraints
            test_ok = false
        )

        snapMode.setOSnapItemActive 4 1 (not original_grid)
        if (snapMode.getOSnapItemActive 4 1) != (not original_grid) then
        (
            format "[MTE TEST] FAILED | Grid Points expected:% actual:%\n" (not original_grid) (snapMode.getOSnapItemActive 4 1)
            test_ok = false
        )

        snapMode.active = not original_snap
        if snapMode.active != (not original_snap) then
        (
            format "[MTE TEST] FAILED | snap master expected:% actual:%\n" (not original_snap) snapMode.active
            test_ok = false
        )

        snapMode.angleSnapActive = not original_angle
        if snapMode.angleSnapActive != (not original_angle) then
        (
            format "[MTE TEST] FAILED | angle expected:% actual:%\n" (not original_angle) snapMode.angleSnapActive
            test_ok = false
        )

        preferences.constantReferenceSystem = not original_constant
        if preferences.constantReferenceSystem != (not original_constant) then
        (
            format "[MTE TEST] FAILED | constant reference expected:% actual:%\n" (not original_constant) preferences.constantReferenceSystem
            test_ok = false
        )
    )
    catch
    (
        exception_text = getCurrentException()
        format "[MTE TEST] FAILED | unexpected exception:%\n" exception_text
        test_ok = false
    )

    /* Restore settings even when the test encountered an exception. */
    try
    (
        setCoordCenter original_center
        if original_system == #hybrid then
        (
            toolMode.coordsys #view
        )
        else if original_system == #object then
        (
            if isValidNode original_ref_node then
            (
                toolMode.coordsys original_ref_node
            )
            else
            (
                format "[MTE TEST] FAILED | cannot restore original object/grid reference with undefined node.\n"
                test_ok = false
            )
        )
        else
        (
            toolMode.coordsys original_system
        )
        toolMode.axisConstraints = original_axis
        snapMode.setOSnapItemActive 4 1 original_grid
        snapMode.active = original_snap
        snapMode.angleSnapActive = original_angle
        preferences.constantReferenceSystem = original_constant
        updateToolbarButtons()
    )
    catch
    (
        exception_text = getCurrentException()
        format "[MTE TEST] FAILED | restoring native state:%\n" exception_text
        test_ok = false
    )

    format "[MTE TEST] RESULT | pass:%\n" test_ok
    test_ok
    -- return
)

testMainToolbarExtendedNativeStates()
