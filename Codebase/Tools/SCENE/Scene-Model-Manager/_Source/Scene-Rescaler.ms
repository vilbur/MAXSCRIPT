/*
Scene Rescaler 0.03
Creates a scaled copy of the current 3ds Max scene and restores the source scene afterwards.
*/

global SceneRescaler
global SceneRescalerRollout
global SceneRescalerProjectVersion

if (SceneRescalerProjectVersion == undefined or SceneRescalerProjectVersion < 0.03) then
(
    SceneRescalerProjectVersion = 0.03
)

try
(
    destroyDialog SceneRescalerRollout
)
catch
(
)

struct SceneRescaler_v
(
    version = "0.03",
    project_version = "0.03",
    target_unit_names = #(#Millimeters, #Centimeters, #Meters, #Kilometers, #Inches, #Feet, #Miles),
    display_unit_names = #(
        #CustomMillimeter,
        #Generic,
        #Millimeters,
        #Centimeters,
        #Meters,
        #Kilometers,
        #Frac_In,
        #Dec_In,
        #Frac_Ft,
        #Dec_Ft,
        #Ft_Frac_In,
        #Ft_Dec_In
    ),

    /*
    Convert one named 3ds Max unit to millimeters.
    This is the common physical-unit base used by all scale calculations.
    */
    function getUnitMillimeters unit_name =
    (
        unit_mm = 1.0

        case unit_name of
        (
            #Millimeters: unit_mm = 1.0
            #Centimeters: unit_mm = 10.0
            #Meters: unit_mm = 1000.0
            #Kilometers: unit_mm = 1000000.0
            #Inches: unit_mm = 25.4
            #Feet: unit_mm = 304.8
            #Miles: unit_mm = 1609344.0
            default: unit_mm = 1.0
        )

        unit_mm -- return
    ),

    /*
    Get a readable long name for a 3ds Max unit type.
    The mapping avoids relying on name-to-string formatting details.
    */
    function getUnitText unit_name =
    (
        unit_text = "Unknown"

        case unit_name of
        (
            #Millimeters: unit_text = "Millimeters"
            #Centimeters: unit_text = "Centimeters"
            #Meters: unit_text = "Meters"
            #Kilometers: unit_text = "Kilometers"
            #Inches: unit_text = "Inches"
            #Feet: unit_text = "Feet"
            #Miles: unit_text = "Miles"
            default: unit_text = "Unknown"
        )

        unit_text -- return
    ),

    /*
    Get a short unit suffix suitable for generated output file names.
    These suffixes are presentation strings only.
    */
    function getUnitShortText unit_name =
    (
        unit_text = "unit"

        case unit_name of
        (
            #Millimeters: unit_text = "mm"
            #Centimeters: unit_text = "cm"
            #Meters: unit_text = "m"
            #Kilometers: unit_text = "km"
            #Inches: unit_text = "in"
            #Feet: unit_text = "ft"
            #Miles: unit_text = "mi"
            default: unit_text = "unit"
        )

        unit_text -- return
    ),

    /*
    Format a numeric value compactly for UI text.
    Six significant digits keep large architectural scenes readable.
    */
    function formatNumber number_value =
    (
        number_text = formattedPrint number_value format:".6g"
        number_text -- return
    ),

    /*
    Calculate the world-unit rescale factor for a requested physical ratio.
    Source SystemScale and SystemType are converted into the selected target System Unit.
    */
    function calculateScaleFactor source_scale source_type target_type ratio_value =
    (
        source_mm = source_scale * getUnitMillimeters source_type
        target_mm = getUnitMillimeters target_type
        scale_factor = 0.0

        if (ratio_value > 0 and target_mm > 0.0) then
        (
            scale_factor = source_mm / target_mm / ratio_value
        )

        scale_factor -- return
    ),

    /*
    Collect the world-space bounding size of scene geometry.
    Camera/light TargetObject nodes are excluded because they contain no real geometry.
    */
    function getSceneBoundsSize =
    (
        bounds_min = undefined
        bounds_max = undefined
        node_count = 0
        world_tm = matrix3 1

        for scene_node in objects do
        (
            if (superClassOf scene_node == GeometryClass and classOf scene_node != TargetObject) then
            (
                try
                (
                    node_bounds = nodeGetBoundingBox scene_node world_tm

                    if (node_bounds != undefined and node_bounds.count == 2) then
                    (
                        if bounds_min == undefined then
                        (
                            bounds_min = node_bounds[1]
                            bounds_max = node_bounds[2]
                        )
                        else
                        (
                            bounds_min.x = amin bounds_min.x node_bounds[1].x
                            bounds_min.y = amin bounds_min.y node_bounds[1].y
                            bounds_min.z = amin bounds_min.z node_bounds[1].z

                            bounds_max.x = amax bounds_max.x node_bounds[2].x
                            bounds_max.y = amax bounds_max.y node_bounds[2].y
                            bounds_max.z = amax bounds_max.z node_bounds[2].z
                        )

                        node_count += 1
                    )
                )
                catch
                (
                )
            )
        )

        if bounds_min == undefined then
        (
            #([0.0, 0.0, 0.0], 0)
        )
        else
        (
            #(bounds_max - bounds_min, node_count)
        ) -- return
    ),

    /*
    Describe the current source System Units exactly as stored in the scene.
    SystemScale is included because the scale value is part of the actual system unit.
    */
    function getSourceSystemText =
    (
        "1 system unit = " + formatNumber units.SystemScale + " " + getUnitText units.SystemType -- return
    ),

    /*
    Describe the current source Display Units without changing them.
    Custom display units include their custom physical-unit definition.
    */
    function getSourceDisplayText =
    (
        display_text = "Generic"

        case units.DisplayType of
        (
            #Generic: display_text = "Generic"
            #Metric: display_text = "Metric / " + getUnitText units.MetricType
            #US: display_text = "US / " + (units.USType as string)
            #Custom:
            (
                display_text = "Custom / 1 " + units.CustomName + " = " + formatNumber units.CustomValue + " " + getUnitText units.CustomUnit
            )
            default: display_text = units.DisplayType as string
        )

        display_text -- return
    ),

    /*
    Format model bounds using the scene's current Display Units.
    units.formatValue performs the same display conversion used by 3ds Max UI fields.
    */
    function getSourceSizeText =
    (
        bounds_data = getSceneBoundsSize()
        bounds_size = bounds_data[1]
        node_count = bounds_data[2]
        size_text = ""

        if node_count > 0 then
        (
            try
            (
                size_text = (units.formatValue bounds_size.x) + " x " + (units.formatValue bounds_size.y) + " x " + (units.formatValue bounds_size.z) + "   (" + (node_count as string) + " nodes)"
            )
            catch
            (
                size_text = (formatNumber bounds_size.x) + " x " + (formatNumber bounds_size.y) + " x " + (formatNumber bounds_size.z) + " system units   (" + (node_count as string) + " nodes)"
            )
        )
        else
        (
            size_text = "No geometry found"
        )

        size_text -- return
    ),

    /*
    Calculate the final physical geometry size in millimeters for UI preview.
    The result is independent of which target System Unit is selected.
    */
    function getTargetSizeMillimeters ratio_value =
    (
        bounds_data = getSceneBoundsSize()
        bounds_size = bounds_data[1]
        source_mm_per_unit = units.SystemScale * getUnitMillimeters units.SystemType
        result_size = [0.0, 0.0, 0.0]

        if ratio_value > 0 then
        (
            result_size = bounds_size * source_mm_per_unit / ratio_value
        )

        result_size -- return
    ),

    /*
    Convert the System Units dropdown selection into a valid 3ds Max SystemType name.
    Invalid selections fall back to millimeters.
    */
    function getTargetTypeBySelection selection_index =
    (
        target_type = #Millimeters

        if (selection_index >= 1 and selection_index <= target_unit_names.count) then
        (
            target_type = target_unit_names[selection_index]
        )

        target_type -- return
    ),

    /*
    Convert the Display Units dropdown selection into the internal display option name.
    Invalid selections fall back to the custom one-unit-equals-one-millimeter preset.
    */
    function getDisplayTypeBySelection selection_index =
    (
        display_type = #CustomMillimeter

        if (selection_index >= 1 and selection_index <= display_unit_names.count) then
        (
            display_type = display_unit_names[selection_index]
        )

        display_type -- return
    ),

    /*
    Configure the copied scene's Display Units from the selected UI preset.
    The first preset is Custom with one displayed unit equal to one millimeter.
    */
    function setTargetDisplayUnits display_type =
    (
        case display_type of
        (
            #CustomMillimeter:
            (
                units.CustomName = "unit"
                units.CustomValue = 1.0
                units.CustomUnit = #Millimeters
                units.DisplayType = #Custom
            )
            #Generic:
            (
                units.DisplayType = #Generic
            )
            #Millimeters:
            (
                units.MetricType = #Millimeters
                units.DisplayType = #Metric
            )
            #Centimeters:
            (
                units.MetricType = #Centimeters
                units.DisplayType = #Metric
            )
            #Meters:
            (
                units.MetricType = #Meters
                units.DisplayType = #Metric
            )
            #Kilometers:
            (
                units.MetricType = #Kilometers
                units.DisplayType = #Metric
            )
            #Frac_In:
            (
                units.USType = #Frac_In
                units.DisplayType = #US
            )
            #Dec_In:
            (
                units.USType = #Dec_In
                units.DisplayType = #US
            )
            #Frac_Ft:
            (
                units.USType = #Frac_Ft
                units.DisplayType = #US
            )
            #Dec_Ft:
            (
                units.USType = #Dec_Ft
                units.DisplayType = #US
            )
            #Ft_Frac_In:
            (
                units.USType = #Ft_Frac_In
                units.DisplayType = #US
            )
            #Ft_Dec_In:
            (
                units.USType = #Ft_Dec_In
                units.DisplayType = #US
            )
            default:
            (
                units.CustomName = "unit"
                units.CustomValue = 1.0
                units.CustomUnit = #Millimeters
                units.DisplayType = #Custom
            )
        )

        true -- return
    ),

    /*
    Build the default filename suffix from ratio and target System Units.
    This value can be freely edited in the Output Copy section.
    */
    function getDefaultSuffix ratio_value target_type =
    (
        ratio_text = (ratio_value as integer) as string
        unit_text = getUnitShortText target_type
        "_1-" + ratio_text + "_" + unit_text -- return
    ),

    /*
    Build an output path beside the source file using the user-editable suffix.
    The original source filename is never modified.
    */
    function getSuggestedOutputPath suffix_text =
    (
        target_path = ""

        if (maxFileName != "" and maxFilePath != "") then
        (
            source_name = getFilenameFile maxFileName
            target_path = maxFilePath + source_name + suffix_text + ".max"
        )

        target_path -- return
    ),

    /*
    Normalize path separators and case for a same-file safety check.
    This prevents the generated copy from overwriting the loaded source file.
    */
    function normalizePath file_path =
    (
        normalized_path = toLower (substituteString file_path "/" "\\")
        normalized_path -- return
    ),

    /*
    Sanitize a scene node name for use as an OBJ filename.
    Invalid Windows filename characters are replaced with underscores.
    */
    function getSafeFileName file_name =
    (
        safe_name = file_name
        invalid_chars = #("\\", "/", ":", "*", "?", "\"", "<", ">", "|")

        for invalid_char in invalid_chars do
        (
            safe_name = substituteString safe_name invalid_char "_"
        )

        if safe_name == "" then
        (
            safe_name = "export"
        )

        safe_name -- return
    ),

    /*
    Find the highest group head containing a node.
    A selected nested group or group member is promoted to its outermost group head.
    */
    function getTopGroupHead scene_node =
    (
        current_node = scene_node
        top_group = undefined
        search_done = false

        while (current_node != undefined and search_done == false) do
        (
            if isGroupHead current_node then
            (
                top_group = current_node
            )

            parent_node = current_node.parent

            if parent_node != undefined and (isGroupHead parent_node or isGroupMember current_node) then
            (
                current_node = parent_node
            )
            else
            (
                search_done = true
            )
        )

        top_group -- return
    ),

    /*
    Collect all descendants of a scene node recursively.
    The supplied parent node is not included in the returned array.
    */
    function getNodeDescendants parent_node =
    (
        descendants = #()

        for child_node in parent_node.children do
        (
            append descendants child_node
            join descendants (getNodeDescendants child_node)
        )

        descendants -- return
    ),

    /*
    Collect exportable geometry for one selected export unit.
    Top-level groups export all geometry descendants; standalone nodes export themselves.
    */
    function getExportNodes scene_node =
    (
        top_group = getTopGroupHead scene_node
        export_nodes = #()

        if top_group != undefined then
        (
            group_nodes = getNodeDescendants top_group

            for group_node in group_nodes do
            (
                if superClassOf group_node == GeometryClass then
                (
                    append export_nodes group_node
                )
            )
        )
        else if superClassOf scene_node == GeometryClass then
        (
            append export_nodes scene_node
        )

        export_nodes -- return
    ),

    /*
    Build unique export units from the current selection.
    Multiple selected members of the same nested group resolve to one top-level group export.
    */
    function getSelectedExportUnits =
    (
        export_units = #()

        for scene_node in selection do
        (
            top_group = getTopGroupHead scene_node
            export_unit = if top_group != undefined then top_group else scene_node

            if (findItem export_units export_unit) == 0 then
            (
                append export_units export_unit
            )
        )

        export_units -- return
    ),

    /*
    Create one temporary Editable Poly from geometry nodes for group OBJ export.
    Source nodes are copied first, so attaching never changes the source group.
    */
    function createMergedGroupExportNode source_nodes export_name =
    (
        merged_node = undefined
        temp_nodes = #()

        for source_node in source_nodes do
        (
            temp_node = undefined

            try
            (
                temp_node = copy source_node

                if isGroupMember temp_node then
                (
                    setGroupMember temp_node false
                )

                temp_node.parent = undefined

                if canConvertTo temp_node Editable_Poly then
                (
                    convertTo temp_node Editable_Poly
                    append temp_nodes temp_node
                )
                else
                (
                    delete temp_node
                )
            )
            catch
            (
                if temp_node != undefined then
                (
                    try
                    (
                        delete temp_node
                    )
                    catch
                    (
                    )
                )

                format "Scene Rescaler OBJ temporary copy failed: %\n" source_node.name
            )
        )

        if temp_nodes.count > 0 then
        (
            merged_node = temp_nodes[1]
            merged_node.name = export_name

            if temp_nodes.count > 1 then
            (
                for node_index = temp_nodes.count to 2 by -1 do
                (
                    source_node = temp_nodes[node_index]
                    source_name = source_node.name

                    try
                    (
                        polyop.attach merged_node source_node
                    )
                    catch
                    (
                        try
                        (
                            delete source_node
                        )
                        catch
                        (
                        )

                        format "Scene Rescaler OBJ attach failed: %\n" source_name
                    )
                )
            )
        )

        merged_node -- return
    ),

    /*
    Export each selected object or top-level group to its own OBJ file.
    Top-level groups are merged on temporary Editable Poly copies before export.
    */
    function exportSelectionToObj =
    (
        exported_count = 0
        failed_count = 0

        if maxFilePath == "" then
        (
            messageBox "Save the MAX scene before exporting OBJ files." title:"Scene Rescaler"
        )
        else if selection.count == 0 then
        (
            messageBox "Select at least one object or group to export." title:"Scene Rescaler"
        )
        else
        (
            export_path = maxFilePath + "export\\"
            makeDir export_path all:true
            original_selection = selection as array
            export_units = getSelectedExportUnits()

            for export_unit in export_units do
            (
                export_nodes = getExportNodes export_unit

                if export_nodes.count > 0 then
                (
                    file_name = getSafeFileName export_unit.name
                    obj_path = export_path + file_name + ".obj"
                    temp_export_node = undefined

                    try
                    (
                        if isGroupHead export_unit then
                        (
                            temp_export_node = createMergedGroupExportNode export_nodes export_unit.name

                            if temp_export_node != undefined then
                            (
                                select temp_export_node
                                exportFile obj_path #noPrompt selectedOnly:true using:ObjExp
                                exported_count += 1
                            )
                            else
                            (
                                failed_count += 1
                            )
                        )
                        else
                        (
                            select export_nodes
                            exportFile obj_path #noPrompt selectedOnly:true using:ObjExp
                            exported_count += 1
                        )
                    )
                    catch
                    (
                        failed_count += 1
                        format "Scene Rescaler OBJ export failed: % | %\n" obj_path (getCurrentException())
                    )

                    if temp_export_node != undefined then
                    (
                        try
                        (
                            delete temp_export_node
                        )
                        catch
                        (
                        )
                    )
                )
            )

            select original_selection

            if failed_count == 0 then
            (
                messageBox ((exported_count as string) + " OBJ file(s) exported to:\n\n" + export_path) title:"Scene Rescaler"
            )
            else
            (
                messageBox ((exported_count as string) + " OBJ file(s) exported.\n" + (failed_count as string) + " export(s) failed.\n\n" + export_path) title:"Scene Rescaler"
            )
        )

        #(exported_count, failed_count) -- return
    ),

    /*
    Test group promotion without exporting files.
    Prints each selected node and the export unit it resolves to.
    */
    function testObjExportSelection =
    (
        export_units = getSelectedExportUnits()

        format "Scene Rescaler OBJ test: % export unit(s).\n" export_units.count

        for export_unit in export_units do
        (
            export_nodes = getExportNodes export_unit
            format "  % -> % geometry node(s)\n" export_unit.name export_nodes.count
        )

        export_units.count -- return
    ),

    /*
    Configure the copied scene's target System Units and chosen Display Units.
    Target SystemScale remains 1.0 while SystemType is selectable.
    */
    function setTargetUnits target_type display_type =
    (
        units.SystemType = target_type
        units.SystemScale = 1.0
        setTargetDisplayUnits display_type
        true -- return
    ),

    /*
    Rescale the held scene, save a separate MAX copy, then restore the source scene.
    Hold/Fetch protects the currently loaded source scene and its unsaved in-memory state.
    */
    function createRescaledCopy target_path ratio_value target_type display_type =
    (
        operation_ok = false
        hold_created = false
        fetch_ok = false
        error_text = ""

        if ratio_value <= 0 then
        (
            messageBox "Scale ratio must be greater than zero." title:"Scene Rescaler"
        )
        else if target_path == "" then
        (
            messageBox "Choose an output MAX file first." title:"Scene Rescaler"
        )
        else
        (
            if getFilenameType target_path == "" then
            (
                target_path += ".max"
            )

            source_path = maxFilePath + maxFileName
            same_as_source = false

            if source_path != "" then
            (
                same_as_source = normalizePath source_path == normalizePath target_path
            )

            if same_as_source then
            (
                messageBox "The target file cannot be the currently loaded source MAX file." title:"Scene Rescaler"
            )
            else
            (
                allow_save = true

                if doesFileExist target_path then
                (
                    allow_save = queryBox ("The target file already exists:\n\n" + target_path + "\n\nOverwrite it?") title:"Scene Rescaler"
                )

                if allow_save then
                (
                    source_scale = units.SystemScale
                    source_type = units.SystemType
                    scale_factor = calculateScaleFactor source_scale source_type target_type ratio_value

                    try
                    (
                        holdMaxFile()
                        hold_created = true

                        rescaleWorldUnits scale_factor
                        setTargetUnits target_type display_type

                        operation_ok = saveMaxFile target_path useNewFile:false clearNeedSaveFlag:false quiet:true
                    )
                    catch
                    (
                        error_text = getCurrentException()
                        format "Scene Rescaler error: %\n" error_text
                        operation_ok = false
                    )

                    if hold_created then
                    (
                        try
                        (
                            fetchMaxFile quiet:true
                            fetch_ok = true
                        )
                        catch
                        (
                            fetch_ok = false
                            format "Scene Rescaler Fetch error: %\n" (getCurrentException())
                        )
                    )

                    if (operation_ok and fetch_ok) then
                    (
                        messageBox ("Rescaled copy created:\n\n" + target_path + "\n\nThe original source scene has been restored.") title:"Scene Rescaler"
                    )
                    else if (operation_ok and fetch_ok == false) then
                    (
                        messageBox ("The rescaled copy was saved, but automatic Fetch failed.\n\nUse Edit > Fetch to restore the held source scene before continuing.\n\nSaved copy:\n" + target_path) title:"Scene Rescaler - IMPORTANT"
                    )
                    else
                    (
                        if fetch_ok then
                        (
                            messageBox ("The copy could not be saved. The original source scene was restored.\n\n" + error_text) title:"Scene Rescaler"
                        )
                        else
                        (
                            messageBox ("The copy could not be saved and automatic Fetch also failed.\n\nUse Edit > Fetch to restore the held source scene before continuing.\n\n" + error_text) title:"Scene Rescaler - IMPORTANT"
                        )
                    )
                )
            )
        )

        operation_ok and fetch_ok -- return
    ),

    on create do
    (
    )
)

SceneRescaler = SceneRescaler_v()

rollout SceneRescalerRollout "Scene Rescaler 0.03"
(
    groupBox grp_source "SOURCE SCENE" pos:[10,8] width:540 height:132
    label lbl_source_file_title "File:" pos:[24,31] width:90 height:18
    label lbl_source_file "" pos:[122,31] width:408 height:18
    label lbl_source_system_title "System units:" pos:[24,55] width:90 height:18
    label lbl_source_system "" pos:[122,55] width:408 height:18
    label lbl_source_display_title "Display units:" pos:[24,79] width:90 height:18
    label lbl_source_display "" pos:[122,79] width:408 height:18
    label lbl_source_size_title "Model size:" pos:[24,103] width:90 height:18
    label lbl_source_size "" pos:[122,103] width:408 height:18

    groupBox grp_target "RESCALE TARGET" pos:[10,150] width:540 height:178
    label lbl_ratio "Desired ratio" pos:[24,178] width:90 height:18
    label lbl_ratio_prefix "1 :" pos:[122,178] width:24 height:18
    spinner spn_ratio "" pos:[148,175] width:98 height:20 type:#integer range:[1,1000000,150] scale:1

    label lbl_target_system "System units:" pos:[275,178] width:82 height:18
    dropdownList ddl_target_units "" pos:[358,175] width:172 items:#("Millimeters", "Centimeters", "Meters", "Kilometers", "Inches", "Feet", "Miles") selection:1

    label lbl_target_display "Display units:" pos:[24,210] width:90 height:18
    dropdownList ddl_display_units "" pos:[122,207] width:408 items:#(
        "Custom - 1 unit = 1 Millimeter",
        "Generic Units",
        "Metric - Millimeters",
        "Metric - Centimeters",
        "Metric - Meters",
        "Metric - Kilometers",
        "US - Fractional Inches",
        "US - Decimal Inches",
        "US - Fractional Feet",
        "US - Decimal Feet",
        "US - Feet + Fractional Inches",
        "US - Feet + Decimal Inches"
    ) selection:1

    label lbl_scale_factor_title "World scale factor:" pos:[24,242] width:110 height:18
    label lbl_scale_factor "" pos:[142,242] width:388 height:18
    label lbl_target_size_title "Result size:" pos:[24,266] width:110 height:18
    label lbl_target_size "" pos:[142,266] width:388 height:18
    label lbl_target_note "Target SystemScale is 1.0. Result size preview is physical millimeters." pos:[24,298] width:500 height:18

    groupBox grp_output "OUTPUT COPY" pos:[10,338] width:540 height:144
    label lbl_suffix "Suffix:" pos:[24,365] width:90 height:18
    editText edt_suffix "" pos:[122,362] width:408 height:20
    label lbl_output "MAX file:" pos:[24,395] width:90 height:18
    editText edt_output "" pos:[122,392] width:320 height:20
    button btn_browse "Browse..." pos:[450,391] width:80 height:22
    label lbl_copy_note "The current source scene is restored after the copy is written." pos:[24,422] width:500 height:18
    button btn_create "CREATE RESCALED COPY" pos:[24,447] width:506 height:26

    groupBox grp_obj_export "OBJ EXPORT" pos:[10,492] width:540 height:82
    label lbl_obj_export "Export selected objects to the scene folder\\export." pos:[24,518] width:330 height:18
    button btn_export_obj "EXPORT SELECTED *.OBJ" pos:[362,513] width:168 height:26 toolTip:"Export each selected object to the scene export folder.\n\nSelected group members are promoted to the highest group head and exported with all geometry children."

    label lbl_status "Ready." pos:[12,584] width:536 height:18

    /*
    Refresh source-scene labels from the currently loaded scene.
    Model size is formatted through the active 3ds Max Display Units.
    */
    function refreshSourceData =
    (
        if maxFileName == "" then
        (
            lbl_source_file.text = "(Untitled scene)"
        )
        else
        (
            lbl_source_file.text = maxFilePath + maxFileName
        )

        lbl_source_system.text = SceneRescaler.getSourceSystemText()
        lbl_source_display.text = SceneRescaler.getSourceDisplayText()
        lbl_source_size.text = SceneRescaler.getSourceSizeText()
    )

    /*
    Refresh the world-scale factor and target physical-size preview.
    Preview calculations do not modify the scene.
    */
    function refreshTargetPreview =
    (
        ratio_value = spn_ratio.value as integer
        target_type = SceneRescaler.getTargetTypeBySelection ddl_target_units.selection
        scale_factor = SceneRescaler.calculateScaleFactor units.SystemScale units.SystemType target_type ratio_value
        target_size_mm = SceneRescaler.getTargetSizeMillimeters ratio_value

        lbl_scale_factor.text = SceneRescaler.formatNumber scale_factor
        lbl_target_size.text = (SceneRescaler.formatNumber target_size_mm.x) + " x " + (SceneRescaler.formatNumber target_size_mm.y) + " x " + (SceneRescaler.formatNumber target_size_mm.z) + " mm"
        lbl_status.text = "Preview only - source scene has not been changed."
    )

    /*
    Replace the output suffix with the default generated from current ratio and System Units.
    This function is used only when target settings change, not when the user edits the suffix.
    */
    function refreshDefaultSuffix =
    (
        target_type = SceneRescaler.getTargetTypeBySelection ddl_target_units.selection
        edt_suffix.text = SceneRescaler.getDefaultSuffix (spn_ratio.value as integer) target_type
    )

    /*
    Regenerate the output path from the source filename and current suffix text.
    Untitled scenes leave an existing manually entered path unchanged.
    */
    function refreshOutputPath =
    (
        suggested_path = SceneRescaler.getSuggestedOutputPath edt_suffix.text

        if suggested_path != "" then
        (
            edt_output.text = suggested_path
        )
    )

    on SceneRescalerRollout open do
    (
        refreshSourceData()
        refreshTargetPreview()
        refreshDefaultSuffix()
        refreshOutputPath()
    )

    on spn_ratio changed ratio_value do
    (
        refreshTargetPreview()
        refreshDefaultSuffix()
        refreshOutputPath()
    )

    on ddl_target_units selected selection_index do
    (
        refreshTargetPreview()
        refreshDefaultSuffix()
        refreshOutputPath()
    )

    on ddl_display_units selected selection_index do
    (
        lbl_status.text = "Target Display Units changed - source scene has not been modified."
    )

    on edt_suffix changed suffix_text do
    (
        refreshOutputPath()
    )

    on btn_browse pressed do
    (
        seed_path = edt_output.text

        if seed_path == "" then
        (
            seed_path = SceneRescaler.getSuggestedOutputPath edt_suffix.text
        )

        selected_path = getMAXSaveFileName filename:seed_path

        if selected_path != undefined then
        (
            edt_output.text = selected_path
        )
    )

    on btn_export_obj pressed do
    (
        lbl_status.text = "Exporting selected OBJ files..."
        windows.processPostedMessages()

        export_result = SceneRescaler.exportSelectionToObj()
        lbl_status.text = ((export_result[1] as string) + " OBJ file(s) exported, " + (export_result[2] as string) + " failed.")
    )

    on btn_create pressed do
    (
        target_type = SceneRescaler.getTargetTypeBySelection ddl_target_units.selection
        display_type = SceneRescaler.getDisplayTypeBySelection ddl_display_units.selection
        lbl_status.text = "Creating rescaled copy..."
        windows.processPostedMessages()

        copy_ok = SceneRescaler.createRescaledCopy edt_output.text (spn_ratio.value as integer) target_type display_type

        refreshSourceData()
        refreshTargetPreview()

        if copy_ok then
        (
            lbl_status.text = "Finished - original scene restored."
        )
        else
        (
            lbl_status.text = "Operation did not complete successfully."
        )
    )
)

macroScript SceneRescalerMacro
category:"vilbur Tools"
toolTip:"Scene Rescaler"
buttonText:"Scene Rescaler"
(
    on execute do
    (
        try
        (
            destroyDialog SceneRescalerRollout
        )
        catch
        (
        )

        createDialog SceneRescalerRollout 560 612
    )
)
