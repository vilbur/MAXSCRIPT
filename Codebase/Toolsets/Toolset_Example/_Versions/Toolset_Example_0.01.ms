/*
Reusable Toolset-layer dialog template.
Version 0.01.
*/


global toolset_template_version = "0.01"


struct ToolsetTemplate_v
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
        if ::toolTemplateRollout == undefined then
        (
            false -- return
        )
        else
        (
            closeToolset()


            floater_ref = newRolloutFloater ("Toolset Template - v" + toolset_template_version) width height
            addRollout toolTemplateRollout floater_ref


            true -- return
        )
    ),


    on create do
    (
    )
)


global ToolsetTemplate
ToolsetTemplate = ToolsetTemplate_v()