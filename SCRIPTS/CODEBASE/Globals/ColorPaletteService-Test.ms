/*
Tests the reusable ColorPaletteService without changing the 3ds Max scene.
FILE_VERSION: 0.004 | PROJECT_VERSION: 0.005
Run from Codebase/Globals alongside ColorPaletteService.ms and ColorPalette.ini.
*/
(
    local test_source_path = getSourceFileName()
    if test_source_path == undefined or test_source_path == "" then
    (
        throw "Save and run ColorPaletteService-Test.ms from the Globals folder."
    )
    fileIn ((getFilenamePath test_source_path) + "ColorPaletteService.ms")




    /*
    Tests validated loading, positive IDs, and numeric sorting.
    */
    function partOfTest1 =
    (
        local test_entries = ColorPaletteService.getEntries()
        local test_ok = test_entries.count > 0 and ColorPaletteService.validateEntries test_entries
        if test_ok then
        (
            for entry_index = 2 to test_entries.count while test_ok do
            (
                test_ok = test_entries[entry_index - 1].palette_id < test_entries[entry_index].palette_id
            )
        )
        format "PART 1 | unique, sorted material IDs | % | count:%\n" (if test_ok then "PASS" else "FAIL") test_entries.count
        test_ok
        -- return
    )




    /*
    Tests read API and defensive copies without modifying the live records.
    */
    function partOfTest2 =
    (
        local first_entry = (ColorPaletteService.getEntries())[1]
        local material_id = first_entry.palette_id
        local lookup_entry = ColorPaletteService.getEntryById material_id
        local test_ok = lookup_entry != undefined and (ColorPaletteService.getNameById material_id) == first_entry.name_text and (ColorPaletteService.getColorById material_id) == first_entry.color_value
        lookup_entry.name_text = "TEMP_TEST_VALUE"
        test_ok = test_ok and (ColorPaletteService.getNameById material_id) == first_entry.name_text
        test_ok = test_ok and (ColorPaletteService.parseId "0") == undefined and (ColorPaletteService.parseId "1.5") == undefined
        format "PART 2 | defensive lookup and ID parsing | %\n" (if test_ok then "PASS" else "FAIL")
        test_ok
        -- return
    )




    /*
    Tests duplicate-ID rejection without writing or changing service records.
    */
    function partOfTest3 =
    (
        local draft_entries = ColorPaletteService.getEntries()
        local original_count = draft_entries.count
        append draft_entries (ColorPaletteService.copyEntry draft_entries[1])
        local rejected = not (ColorPaletteService.setEntries draft_entries)
        local test_ok = rejected and (ColorPaletteService.getEntries()).count == original_count
        format "PART 3 | reject duplicate Material ID | %\n" (if test_ok then "PASS" else "FAIL")
        test_ok
        -- return
    )




    /*
    Tests Standard and Multi/Sub-Object material construction without scene changes.
    */
    function partOfTest4 =
    (
        local first_entry = (ColorPaletteService.getEntries())[1]
        local material_id = first_entry.palette_id
        local standard_mat = ColorPaletteService.createStandardMaterialById material_id
        local multi_mat = ColorPaletteService.createMultiMaterial material_ids:#(material_id)
        local test_ok = standard_mat != undefined and multi_mat != undefined
        if test_ok then
        (
            test_ok = multi_mat.materialIDList[1] == material_id and multi_mat.materialList[1].diffuse == first_entry.color_value
        )
        format "PART 4 | Standard + Multi/Sub material | %\n" (if test_ok then "PASS" else "FAIL")
        test_ok
        -- return
    )




    /*
    Checks the flag-to-opacity contract for any existing transparent ID.
    */
    function partOfTest5 =
    (
        local transparent_entry = ColorPaletteService.getEntryById 99
        local test_ok = true
        if transparent_entry != undefined and transparent_entry.is_transparent then
        (
            local test_material = ColorPaletteService.createStandardMaterialById 99
            test_ok = test_material != undefined and test_material.opacity == 0.0
        )
        format "PART 5 | transparent material opacity | %\n" (if test_ok then "PASS" else "FAIL")
        test_ok
        -- return
    )








    /*
    Verifies the live source-of-truth INI matches service API records exactly.
    Avoids hardcoded colors or IDs because the palette is editable by design.
    */
    function partOfTest6 =
    (
        local active_entries = ColorPaletteService.getEntries()
        local source_entries = ColorPaletteService.readRecords ColorPaletteService.ini_path
        local test_ok = source_entries != undefined
        if test_ok then test_ok = active_entries.count == source_entries.count


        if test_ok then
        (
            for entry_index = 1 to active_entries.count while test_ok do
            (
                local active_entry = active_entries[entry_index]
                local source_entry = source_entries[entry_index]
                local lookup_entry = ColorPaletteService.getEntryById active_entry.palette_id


                test_ok = lookup_entry != undefined
                if test_ok then
                (
                    test_ok = source_entry.palette_id == active_entry.palette_id
                    test_ok = test_ok and source_entry.name_text == active_entry.name_text
                    test_ok = test_ok and source_entry.color_value == active_entry.color_value
                    test_ok = test_ok and source_entry.description_text == active_entry.description_text
                    test_ok = test_ok and source_entry.is_transparent == active_entry.is_transparent
                    test_ok = test_ok and lookup_entry.name_text == active_entry.name_text
                    test_ok = test_ok and lookup_entry.color_value == active_entry.color_value
                )
                if not test_ok then format "PART 6 FAILURE | source and service disagree at row:%\n" entry_index
            )
        )


        format "PART 6 | current INI / service readback consistency | % | count:%\n" (if test_ok then "PASS" else "FAIL") active_entries.count
        test_ok
        -- return
    )




    /*
    Tests safe decimal parsing for material IDs, zero values, and invalid input.
    Confirms that non-decimal and out-of-range text is rejected without evaluation.
    */
    function partOfTest7 =
    (
        local test_ok = true
        test_ok = test_ok and (ColorPaletteService.parseId "1") == 1
        test_ok = test_ok and (ColorPaletteService.parseId "60000") == 60000
        test_ok = test_ok and (ColorPaletteService.parseId "0") == undefined
        test_ok = test_ok and (ColorPaletteService.parseId "60001") == undefined
        test_ok = test_ok and (ColorPaletteService.parseId "1.5") == undefined
        test_ok = test_ok and (ColorPaletteService.parseId "1e2") == undefined
        test_ok = test_ok and (ColorPaletteService.parseId " 1") == undefined
        test_ok = test_ok and (ColorPaletteService.parseId "-1") == undefined
        test_ok = test_ok and (ColorPaletteService.parseId "invalid") == undefined
        test_ok = test_ok and (ColorPaletteService.parseId undefined) == undefined
        test_ok = test_ok and (ColorPaletteService.parseUnsignedInt "0" 255) == 0
        test_ok = test_ok and (ColorPaletteService.parseUnsignedInt "255" 255) == 255
        test_ok = test_ok and (ColorPaletteService.parseUnsignedInt "256" 255) == undefined
        test_ok = test_ok and (ColorPaletteService.parseUnsignedInt "20" 60000) == 20
        format "PART 7 | strict integer parser | %\n" (if test_ok then "PASS" else "FAIL")
        test_ok
        -- return
    )












    /*
    Regression for BooleanClass verification during canonical INI loading.
    Checks that both true and false flags survive validation and readback.
    */
    function partOfTest8 =
    (
        local candidate_entries = ColorPaletteService.getEntries()
        local has_opaque = false
        local has_transparent = false
        local type_valid = (classOf true == BooleanClass) and (classOf false == BooleanClass)


        for entry_value in candidate_entries do
        (
            type_valid = type_valid and (classOf entry_value.is_transparent == BooleanClass)
            if entry_value.is_transparent then has_transparent = true
            else has_opaque = true
        )


        local reloaded_entries = ColorPaletteService.readRecords ColorPaletteService.ini_path
        local test_ok = type_valid and has_opaque and has_transparent
        test_ok = test_ok and (ColorPaletteService.validateEntries candidate_entries)
        test_ok = test_ok and (reloaded_entries != undefined)
        if test_ok then test_ok = reloaded_entries.count == candidate_entries.count


        format "PART 8 | BooleanClass flags + canonical INI validation | %\n" (if test_ok then "PASS" else "FAIL")
        test_ok
        -- return
    )


    local test_results = #()
    append test_results (partOfTest1())
    append test_results (partOfTest2())
    append test_results (partOfTest3())
    append test_results (partOfTest4())
    append test_results (partOfTest5())
    append test_results (partOfTest6())
    append test_results (partOfTest7())
    append test_results (partOfTest8())
    format "COLOR PALETTE SERVICE TEST | %\n" (if (findItem test_results false) == 0 then "PASS" else "FAIL")
    format "UNDO: None. Materials are unassigned and scene objects were not modified.\n"
)