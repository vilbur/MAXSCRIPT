/*
Generic INI persistence helpers for MaxScript UI code.
Keep feature logic independent from this file.
*/

struct IniSettings_v
(
    /*
    Returns a string setting or the supplied default value.
    */
    function getString file_path section_name key_name default_value:"" =
    (
        local value = getINISetting file_path section_name key_name

        if value == "" then
        (
            default_value
        )
        else
        (
            value
        )
    ),

    /*
    Writes one string setting.
    */
    function setString file_path section_name key_name value =
    (
        setINISetting file_path section_name key_name (value as string)
        true
    ),

    /*
    Returns an integer setting or the supplied default value.
    */
    function getInteger file_path section_name key_name default_value:0 =
    (
        local value = getINISetting file_path section_name key_name

        if value == "" then
        (
            default_value
        )
        else
        (
            try (value as integer) catch (default_value)
        )
    ),

    /*
    Writes one integer setting.
    */
    function setInteger file_path section_name key_name value =
    (
        setINISetting file_path section_name key_name ((value as integer) as string)
        true
    ),

    /*
    Returns a float setting or the supplied default value.
    */
    function getFloat file_path section_name key_name default_value:0.0 =
    (
        local value = getINISetting file_path section_name key_name

        if value == "" then
        (
            default_value
        )
        else
        (
            try (value as float) catch (default_value)
        )
    ),

    /*
    Writes one float setting.
    */
    function setFloat file_path section_name key_name value =
    (
        setINISetting file_path section_name key_name ((value as float) as string)
        true
    ),

    /*
    Returns a boolean setting or the supplied default value.
    */
    function getBoolean file_path section_name key_name default_value:false =
    (
        local value = toLower (getINISetting file_path section_name key_name)

        case value of
        (
            "true": true
            "1": true
            "yes": true
            "false": false
            "0": false
            "no": false
            default: default_value
        )
    ),

    /*
    Writes one boolean setting.
    */
    function setBoolean file_path section_name key_name value =
    (
        setINISetting file_path section_name key_name (if value then "true" else "false")
        true
    ),

    /*
    Returns a Point2 setting stored as two integer keys.
    */
    function getPoint2 file_path section_name key_x key_y default_value:[0, 0] =
    (
        local x_value = getInteger file_path section_name key_x default_value:default_value.x
        local y_value = getInteger file_path section_name key_y default_value:default_value.y

        [x_value, y_value]
    ),

    /*
    Writes a Point2 setting as two integer keys.
    */
    function setPoint2 file_path section_name key_x key_y value =
    (
        setInteger file_path section_name key_x value.x
        setInteger file_path section_name key_y value.y
        true
    ),

    on create do
    (
    )
)

global IniSettings
IniSettings = IniSettings_v()
