-- FILE_VERSION: 0.001
-- PROJECT_VERSION: 0.001
-- Source: Codebase/Globals/COLOR_NAMES.ms
global COLOR_NAMES


/*
Returns a palette Color by Name key or undefined for a missing entry.
Requires the canonical COLOR_NAMES dictionary to be loaded first.
*/
function getNamedColor color_key =
(
    if COLOR_NAMES == undefined then
    (
        format "COLOR ERROR | COLOR_NAMES is undefined; load Globals/COLOR_NAMES.ms first.\n"
        undefined
    )
    else if not (HasDictValue COLOR_NAMES color_key) then
    (
        format "COLOR ERROR | Missing palette key: %\n" color_key
        undefined
    )
    else
    (
        GetDictValue COLOR_NAMES color_key
    )
    -- return
)