/*
Reusable Operations-layer example.
Version 0.02.
*/


global operations_example_version = "0.02"


/*
Runs one complete procedure through the Function layer.
Result format is #(success, value, message).
*/
function prepareExampleValue value min_value max_value =
(
    if ::clampExampleValue == undefined then
    (
        #(false, undefined, "Function clampExampleValue is not loaded.") -- return
    )
    else
    (
        local clamped_value = clampExampleValue value min_value max_value
        #(true, clamped_value, "OK") -- return
    )
)