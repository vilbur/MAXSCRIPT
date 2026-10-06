/*
Reusable Functions-layer template.
Version 0.01.
*/


global functions_template_version = "0.01"


/*
Clamps one value to a numeric range.
This is an atomic Function example with explicit input and output.
*/
function clampTemplateValue value min_value max_value =
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