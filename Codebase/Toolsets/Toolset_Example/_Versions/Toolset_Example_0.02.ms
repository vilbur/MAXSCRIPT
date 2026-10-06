/*
Reusable Toolset-layer dialog example.
Version 0.02.
*/


global toolset_example_version = "0.02"


struct ToolsetExample_v
(
    floater_ref = undefined,


    /*
    Closes the current Toolset dialog.
    Safe to call when the dialog is not open.
    */
    function closeToolset =
    (
        if floater_ref != undefined then
        (
            try
            (
                closeRolloutFloater floater_ref
            )
            catch
            (
            )


            floater_ref = undefined
        )


        true -- return
    ),


    /*
    Opens the Toolset and adds its Tool rollouts.
    The Toolset coordinates UI composition only.
    */
    function openToolset width:320 height:220 =
    (
        if ::toolExampleRollout == undefined then
        (
            false -- return
        )
        else
        (
            closeToolset()


            floater_ref = newRolloutFloater ("Toolset Example - v" + toolset_example_version) width height
            addRollout toolExampleRollout floater_ref


            true -- return
        )
    ),


    on create do
    (
    )
)


global ToolsetExample
ToolsetExample = ToolsetExample_v()