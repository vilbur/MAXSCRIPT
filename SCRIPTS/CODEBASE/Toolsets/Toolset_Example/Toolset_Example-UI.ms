/*
Toolset Example frontend.
Owns the Toolset dialog and composes Tool rollouts.
*/


global toolset_example_ui_version = "0.01"
global toolset_example_floater = undefined


/*
Closes the Toolset Example dialog.
Safe to call when the dialog is not open.
*/
function closeToolsetExampleUi =
(
    if toolset_example_floater != undefined then
    (
        try
        (
            closeRolloutFloater toolset_example_floater
        )
        catch
        (
        )


        toolset_example_floater = undefined
    )


    true -- return
)


/*
Opens the Toolset Example dialog.
The frontend composes the Tool rollout but does not own Tool backend logic.
*/
function openToolsetExampleUi width:320 height:220 =
(
    if ::ToolsetExample == undefined then
    (
        false -- return
    )
    else if not ToolsetExample.isReady() then
    (
        false -- return
    )
    else if ::toolExampleRollout == undefined then
    (
        false -- return
    )
    else
    (
        closeToolsetExampleUi()


        toolset_example_floater = newRolloutFloater ("Toolset Example - v" + toolset_example_ui_version) width height
        addRollout toolExampleRollout toolset_example_floater


        true -- return
    )
)


/*
Tests Toolset dialog creation.
Opens the Toolset twice to verify safe replacement.
*/
function testToolsetExampleUi =
(
    local first_open = openToolsetExampleUi()
    local second_open = openToolsetExampleUi()
    local test_passed = first_open and second_open


    format "Toolset_Example-UI test: %\n" (if test_passed then "PASS" else "FAIL")


    test_passed -- return
)