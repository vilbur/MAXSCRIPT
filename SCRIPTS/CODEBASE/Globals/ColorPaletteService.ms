/*
Shared numeric color-ID palette service. No UI or scene dependencies.
FILE_VERSION: 0.005 | PROJECT_VERSION: 0.006
Canonical source of truth: Globals/ColorPalette.ini; changes are written only on save.
Material ID range: 1..60000 (Multi/Sub-Object MAXScript limit).
*/








global ColorPaletteService








struct ColorPaletteEntry_v
(
    palette_id = 0,
    name_text = "",
    color_value = (color 128 128 128),
    description_text = "",
    is_transparent = false,
    on create do
    (
    )
)








/*
Compares two palette entries by numeric ID for qsort.
Returns -1, 0, or 1.
*/
function colorPaletteCompareIds entry_a entry_b =
(
    if entry_a.palette_id < entry_b.palette_id then -1
    else if entry_a.palette_id > entry_b.palette_id then 1
    else 0
    -- return
)








struct ColorPaletteService_v
(
    entries = #(),
    ini_path = "",
    max_material_id = 60000,
    file_version = "0.005",








    /*
    Makes an independent color entry with the supplied ID and metadata.
    Returns a ColorPaletteEntry_v record.
    */
    function makeEntry palette_id name_text color_value description_text is_transparent:false =
    (
        ColorPaletteEntry_v palette_id:palette_id name_text:name_text color_value:(color color_value.r color_value.g color_value.b) description_text:description_text is_transparent:is_transparent
        -- return
    ),








    /*
    Parses unsigned decimal integers without evaluating input or rounding decimals.
    Returns undefined on empty, non-digit, unsupported, or out-of-range input.
    */
    function parseUnsignedInt entered_text maximum_value =
    (
        local input_text = if classOf entered_text == String then entered_text else if classOf entered_text == Integer then (entered_text as string) else ""
        local parsed_value = 0
        local valid_text = input_text.count > 0 and classOf maximum_value == Integer and maximum_value >= 0








        if valid_text then
        (
            for digit_index = 1 to input_text.count while valid_text do
            (
                local digit_position = findString "0123456789" input_text[digit_index]
                if digit_position == undefined then
                (
                    valid_text = false
                )
                else
                (
                    parsed_value = (parsed_value * 10) + digit_position - 1
                    if parsed_value > maximum_value then valid_text = false
                )
            )
        )








        if valid_text then parsed_value else undefined
        -- return
    ),








    /*
    Parses an exact positive integer material ID within supported range.
    Returns undefined for invalid strings and values.
    */
    function parseId entered_text =
    (
        local parsed_id = parseUnsignedInt entered_text max_material_id
        if parsed_id != undefined and parsed_id >= 1 then parsed_id else undefined
        -- return
    ),








    /*
    Creates a safe copy of an entry to prevent external mutation of service data.
    Returns a new entry or undefined.
    */
    function copyEntry entry_value =
    (
        if entry_value == undefined then undefined
        else makeEntry entry_value.palette_id entry_value.name_text entry_value.color_value entry_value.description_text is_transparent:entry_value.is_transparent
        -- return
    ),








    /*
    Validates IDs, names, RGB range and uniqueness before service mutation.
    Returns true only for a fully valid array of entries.
    */
    function validateEntries candidate_entries =
    (
        local valid_entries = classOf candidate_entries == Array
        local seen_ids = #()
        if not valid_entries then format "PALETTE ERROR | entries must be an Array, got:%\n" (classOf candidate_entries)
        if valid_entries then
        (
            for entry_value in candidate_entries while valid_entries do
            (
                local palette_id = entry_value.palette_id
                local palette_rgb = entry_value.color_value
                valid_entries = classOf palette_id == Integer and palette_id >= 1 and palette_id <= max_material_id and classOf entry_value.name_text == String and entry_value.name_text != "" and classOf palette_rgb == Color and classOf entry_value.description_text == String and classOf entry_value.is_transparent == BooleanClass
                if valid_entries then
                (
                    valid_entries = palette_rgb.r >= 0 and palette_rgb.r <= 255 and palette_rgb.g >= 0 and palette_rgb.g <= 255 and palette_rgb.b >= 0 and palette_rgb.b <= 255
                )
                if valid_entries then
                (
                    if (findItem seen_ids palette_id) != 0 then valid_entries = false
                    else append seen_ids palette_id
                )
                if not valid_entries then
                (
                    format "PALETTE VALIDATION FAILED | ID:% name:% transparencyClass:%\n" palette_id entry_value.name_text (classOf entry_value.is_transparent)
                )
            )
        )
        valid_entries
        -- return
    ),








    /*
    Returns copies of all palette records in ascending ID order.
    Editing returned values does not alter the live service until setEntries.
    */
    function getEntries =
    (
        for entry_value in entries collect (copyEntry entry_value)
        -- return
    ),








    /*
    Finds an entry by material ID without changing service state.
    Returns an independent record or undefined for an unknown ID.
    */
    function getEntryById material_id =
    (
        local found_entry = undefined
        for entry_value in entries while found_entry == undefined do
        (
            if entry_value.palette_id == material_id then found_entry = copyEntry entry_value
        )
        found_entry
        -- return
    ),








    /*
    Gets a palette RGB color by material ID.
    Returns Color or undefined; zero and missing IDs are not valid colors.
    */
    function getColorById material_id =
    (
        local entry_value = getEntryById material_id
        if entry_value == undefined then undefined else entry_value.color_value
        -- return
    ),








    /*
    Gets the palette label by material ID.
    Returns String or undefined.
    */
    function getNameById material_id =
    (
        local entry_value = getEntryById material_id
        if entry_value == undefined then undefined else entry_value.name_text
        -- return
    ),








    /*
    Finds a material ID from a case-sensitive palette name.
    Returns Integer or undefined.
    */
    function findIdByName name_text =
    (
        local found_id = undefined
        for entry_value in entries while found_id == undefined do
        (
            if entry_value.name_text == name_text then found_id = entry_value.palette_id
        )
        found_id
        -- return
    ),








    /*
    Replaces service data only after full validation and numeric sorting.
    Returns true on atomic in-memory commit, false without changing old entries.
    */
    function setEntries candidate_entries =
    (
        local commit_ok = validateEntries candidate_entries
        if commit_ok then
        (
            local new_entries = for entry_value in candidate_entries collect (copyEntry entry_value)
            qsort new_entries colorPaletteCompareIds
            entries = new_entries
        )
        commit_ok
        -- return
    ),








    /*
    Returns the smallest unassigned positive material ID in a supplied array.
    Never assigns the same ID twice.
    */
    function nextFreeId candidate_entries =
    (
        local taken_ids = for entry_value in candidate_entries collect entry_value.palette_id
        local next_id = 1
        while next_id <= max_material_id and (findItem taken_ids next_id) > 0 do
        (
            next_id += 1
        )
        if next_id <= max_material_id then next_id else undefined
        -- return
    ),








    /*
    Loads a complete palette from an INI into a temporary validated array.
    Returns records or undefined; does not overwrite active entries on failure.
    */
    function readRecords file_path =
    (
        local loaded_entries = undefined
        local initialized_text = toLower (getINISetting file_path "Palette" "Initialized")
        local count_text = getINISetting file_path "Palette" "Count"
        local count_value = parseUnsignedInt count_text max_material_id
        local valid_file = initialized_text == "true" and classOf count_value == Integer
        if valid_file then valid_file = count_value >= 0 and count_value <= max_material_id
        if valid_file then
        (
            local draft_entries = #()
            for entry_index = 1 to count_value while valid_file do
            (
                local section_name = "Color_" + (entry_index as string)
                local palette_id = parseId (getINISetting file_path section_name "Id")
                local name_text = getINISetting file_path section_name "Name"
                local r_value = parseUnsignedInt (getINISetting file_path section_name "R") 255
                local g_value = parseUnsignedInt (getINISetting file_path section_name "G") 255
                local b_value = parseUnsignedInt (getINISetting file_path section_name "B") 255
                local description_text = getINISetting file_path section_name "Description"
                local transparency_text = toLower (getINISetting file_path section_name "Transparent")
                valid_file = palette_id != undefined and name_text != "" and classOf r_value == Integer and classOf g_value == Integer and classOf b_value == Integer and (transparency_text == "true" or transparency_text == "false")
                if valid_file then
                (
                    valid_file = r_value >= 0 and r_value <= 255 and g_value >= 0 and g_value <= 255 and b_value >= 0 and b_value <= 255
                )
                if valid_file then
                (
                    append draft_entries (makeEntry palette_id name_text (color r_value g_value b_value) description_text is_transparent:(transparency_text == "true"))
                )
                else format "PALETTE LOAD ERROR | file:% section:% ID:%\n" file_path section_name palette_id
            )
            if valid_file and validateEntries draft_entries then
            (
                qsort draft_entries colorPaletteCompareIds
                loaded_entries = draft_entries
            )
        )
        if loaded_entries == undefined then format "PALETTE LOAD FAILED | file:% initialized:% count:%\n" file_path initialized_text count_text
        loaded_entries
        -- return
    ),








    /*
    Reloads the canonical palette file, retaining active data if reading fails.
    Returns true only when the complete source file has been validated.
    */
    function reload =
    (
        local source_entries = readRecords ini_path
        local reload_ok = source_entries != undefined
        if reload_ok then entries = source_entries
        reload_ok
        -- return
    ),








    /*
    Saves the fully validated live palette to the single canonical INI file.
    Returns Boolean; errors from native INI writes remain visible.
    */
    function save =
    (
        local save_ok = validateEntries entries
        if save_ok then
        (
            for entry_index = 1 to entries.count do
            (
                local entry_value = entries[entry_index]
                local section_name = "Color_" + (entry_index as string)
                setINISetting ini_path section_name "Id" (entry_value.palette_id as string)
                setINISetting ini_path section_name "Name" entry_value.name_text
                setINISetting ini_path section_name "R" ((entry_value.color_value.r as integer) as string)
                setINISetting ini_path section_name "G" ((entry_value.color_value.g as integer) as string)
                setINISetting ini_path section_name "B" ((entry_value.color_value.b as integer) as string)
                setINISetting ini_path section_name "Description" entry_value.description_text
                setINISetting ini_path section_name "Transparent" (if entry_value.is_transparent then "true" else "false")
            )
            setINISetting ini_path "Palette" "Count" (entries.count as string)
            setINISetting ini_path "Palette" "Version" "0.006"
            setINISetting ini_path "Palette" "Initialized" "true"
        )
        save_ok
        -- return
    ),








    /*
    Builds a Standard material for a palette ID with transparency flag applied.
    Returns StandardMaterial or undefined for an unknown ID; never assigns it.
    */
    function createStandardMaterialById material_id =
    (
        local entry_value = getEntryById material_id
        local new_material = undefined
        if entry_value == undefined then
        (
            format "PALETTE MATERIAL ERROR | unknown Material ID:%\n" material_id
        )
        else
        (
            new_material = standardMaterial()
            new_material.name = (material_id as string) + " - " + entry_value.name_text
            new_material.diffuse = entry_value.color_value
            new_material.opacity = if entry_value.is_transparent then 0.0 else 100.0
        )
        new_material
        -- return
    ),








    /*
    Builds a Multi/Sub-Object material from explicit IDs or all palette IDs.
    Returns MultiMaterial or undefined; creates no scene assignments.
    */
    function createMultiMaterial material_ids:#() =
    (
        local requested_ids = if material_ids.count == 0 then (for entry_value in entries collect entry_value.palette_id) else material_ids
        local valid_request = requested_ids.count > 0
        local checked_ids = #()
        for material_id in requested_ids while valid_request do
        (
            valid_request = classOf material_id == Integer and (getEntryById material_id) != undefined and (findItem checked_ids material_id) == 0
            if valid_request then append checked_ids material_id
            else format "PALETTE MULTI ERROR | invalid or duplicate Material ID:%\n" material_id
        )
        local multi_material = undefined
        if valid_request then
        (
            multi_material = multimaterial numsubs:requested_ids.count
            multi_material.name = "COLOR_PALETTE"
            for slot_index = 1 to requested_ids.count do
            (
                local material_id = requested_ids[slot_index]
                local entry_value = getEntryById material_id
                multi_material.materialIDList[slot_index] = material_id
                multi_material.materialList[slot_index] = createStandardMaterialById material_id
                multi_material.names[slot_index] = entry_value.name_text
            )
        )
        multi_material
        -- return
    ),








    on create do
    (
    )
)








(
    local service_source = getSourceFileName()
    if service_source == undefined or service_source == "" then
    (
        throw "ColorPaletteService.ms must be loaded from its saved Globals path."
    )
    local service_directory = getFilenamePath service_source
    ColorPaletteService = ColorPaletteService_v()
    ColorPaletteService.ini_path = service_directory + "ColorPalette.ini"
    if not (doesFileExist ColorPaletteService.ini_path) then
    (
        throw ("Missing canonical palette: " + ColorPaletteService.ini_path)
    )
    if not (ColorPaletteService.reload()) then
    (
        throw ("Invalid canonical palette: " + ColorPaletteService.ini_path)
    )
)