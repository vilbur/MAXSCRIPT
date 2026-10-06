/*
Generic rollout-control persistence helpers.
This file belongs to the UI layer and must not contain feature processing logic.
*/

struct RolloutState_v
(
    /*
    Loads one checkbox state from INI.
    */
    function loadCheckbox control ini_path section_name key_name default_value:false =
    (
        if control != undefined then
        (
            control.checked = IniSettings.getBoolean ini_path section_name key_name default_value:default_value
        )
    ),

    /*
    Saves one checkbox state to INI.
    */
    function saveCheckbox control ini_path section_name key_name =
    (
        if control != undefined then
        (
            IniSettings.setBoolean ini_path section_name key_name control.checked
        )
    ),

    /*
    Loads one spinner value from INI.
    */
    function loadSpinner control ini_path section_name key_name default_value:0.0 =
    (
        if control != undefined then
        (
            control.value = IniSettings.getFloat ini_path section_name key_name default_value:default_value
        )
    ),

    /*
    Saves one spinner value to INI.
    */
    function saveSpinner control ini_path section_name key_name =
    (
        if control != undefined then
        (
            IniSettings.setFloat ini_path section_name key_name control.value
        )
    ),

    /*
    Loads one dropdown selection index from INI.
    */
    function loadDropdown control ini_path section_name key_name default_value:1 =
    (
        if control != undefined then
        (
            local selection_value = IniSettings.getInteger ini_path section_name key_name default_value:default_value

            if selection_value < 1 then selection_value = 1
            if selection_value > control.items.count then selection_value = control.items.count

            if control.items.count > 0 then control.selection = selection_value
        )
    ),

    /*
    Saves one dropdown selection index to INI.
    */
    function saveDropdown control ini_path section_name key_name =
    (
        if control != undefined then
        (
            IniSettings.setInteger ini_path section_name key_name control.selection
        )
    ),

    /*
    Loads one edit-text value from INI.
    */
    function loadEditText control ini_path section_name key_name default_value:"" =
    (
        if control != undefined then
        (
            control.text = IniSettings.getString ini_path section_name key_name default_value:default_value
        )
    ),

    /*
    Saves one edit-text value to INI.
    */
    function saveEditText control ini_path section_name key_name =
    (
        if control != undefined then
        (
            IniSettings.setString ini_path section_name key_name control.text
        )
    ),

    on create do
    (
    )
)

global RolloutState
RolloutState = RolloutState_v()
