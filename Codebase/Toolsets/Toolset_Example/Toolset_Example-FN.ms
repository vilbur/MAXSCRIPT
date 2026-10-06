/*
Toolset Example backend.
Contains Toolset-specific non-UI coordination state.
*/


global toolset_example_fn_version = "0.01"


struct ToolsetExample_v
(
    tool_names = #("Tool_Example"),


    /*
    Returns the names of Tools owned by this Toolset.
    A copy is returned so callers do not modify internal state directly.
    */
    function getToolNames =
    (
        copy tool_names -- return
    ),


    /*
    Reports whether the required Tool backend is loaded.
    This checks backend availability only and does not inspect UI state.
    */
    function isReady =
    (
        (::runToolExample != undefined) -- return
    ),


    on create do
    (
    )
)


global ToolsetExample
ToolsetExample = ToolsetExample_v()