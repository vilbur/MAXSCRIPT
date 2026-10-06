/*
Reusable Operations-layer template.
Version 0.01.
*/


global operations_template_version = "0.01"


/*
Runs one complete procedure through the Function layer.
Result format is #(success, value, message).
*/
function prepareTemplateValue value min_value max_value =
(
    if ::clampTemplateValue == undefined then
    (
        #(false, undefined, "Function clampTemplateValue is not loaded.") -- return
    )
    else
    (
        local clamped_value = clampTemplateValue value min_value max_value
        #(true, clamped_value, "OK") -- return
    )
)