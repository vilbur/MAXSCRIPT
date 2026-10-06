/*
Reusable Functions-layer example.
Version 0.02.
*/


global functions_example_version = "0.02"


/*
Clamps one value to a numeric range.
This is an atomic Function example with explicit input and output.
*/
function clampExampleValue value min_value max_value =
(
    local result_value = value


    if result_value < min_value then
    (
        result_value = min_value
    )


    if result_value > max_value then
    (
        result_value = max_value
    )


    result_value -- return
)