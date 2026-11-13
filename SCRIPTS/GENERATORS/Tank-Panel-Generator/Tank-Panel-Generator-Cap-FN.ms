/*
Tank Panel Generator - Cap Hatch functional module v0.089.
A profile SplineShape is revolved by an owned Lathe modifier. Every
consecutive spline segment receives an independent Standard material ID.
Chamfer is always a fresh, explicitly configured modifier that only filters
edges between DIFFERENT material IDs. No user modifier is cleared or reused.
*/


global SurfacePanelGenerator


struct SurfacePanelCapGenerator_v
(
    file_version = "0.005",
    project_version = "0.089",
    last_node = undefined,
    last_lathe_mod = undefined,
    last_chamfer_mod = undefined,
    last_module = undefined,


    /*
    Returns 1 + seams radii moving strictly from outside towards the center.
    Invalid profiles return undefined with a diagnostic instead of clamping.
    */
    function makeSeamRadii outer_radius end_radius seam_count first_offset seam_spacing =
    (
        if end_radius >= outer_radius then
            format "TPG HATCH | End radius must be smaller than Radius + Inset Radius. End:% outer:%\n" end_radius outer_radius
        if outer_radius <= 0.0 or end_radius < 0.0 or end_radius >= outer_radius or seam_count < 0 or seam_count > 32 or first_offset <= 0.0 or seam_spacing <= 0.0 then
        (
            format "TPG CAP ERROR | Invalid radii/spacing | outer:% end:% seams:% first:% spacing:%\n" outer_radius end_radius seam_count first_offset seam_spacing
            undefined
        )
        else
        (
            local seam_radii = #()
            seam_radii.count = seam_count
            local valid_values = true
            for seam_id = 1 to seam_count do
            (
                local seam_radius = outer_radius - first_offset - ((seam_id - 1) * seam_spacing)
                if seam_radius <= end_radius or seam_radius >= outer_radius then
                (
                    format "TPG CAP ERROR | Seam outside profile | seam:% radius:% end:% outer:%\n" seam_id seam_radius end_radius outer_radius
                    valid_values = false
                )
                seam_radii[seam_id] = seam_radius
            )
            if valid_values then seam_radii else undefined
        )
        -- return
    ),


    /*
    Build an open cross-section in the XY plane (Y is the axial coordinate).
    Material IDs increase from outer cylindrical lip towards inner radius.
    */
    function createProfile outer_radius end_radius depth_value seam_radii =
    (
        local profile_node = splineShape name:"TPG_CapHatch"
        addNewSpline profile_node
        if depth_value != 0.0 then addKnot profile_node 1 #corner #line [outer_radius,0.0,0.0]
        addKnot profile_node 1 #corner #line [outer_radius,depth_value,0.0]
        for seam_radius in seam_radii do
        (
            addKnot profile_node 1 #corner #line [seam_radius,depth_value,0.0]
        )
        addKnot profile_node 1 #corner #line [end_radius,depth_value,0.0]
        updateShape profile_node
        local segment_count = numSegments profile_node 1
        /* The outer axial lip and first radial band share an ID, excluding
           their radius corner from different-material seam chamfer selection.
        */
        local lip_offset = if depth_value != 0.0 then 1 else 0
        for segment_id = 1 to segment_count do setMaterialID profile_node 1 segment_id (amax 1 (segment_id - lip_offset))
        profile_node
        -- return
    ),


    /* Find one generated child cap and validate its saved settings and exact stack.
    */
    function readModuleCap module_node default_seam_depth:5.0 =
    (
        local cap_nodes = #()
        for child_node in module_node.children do
        (
            local owner_text = getUserPropVal child_node "SPG_CapOwner" asString:true
            if owner_text == "Tank-Panel-Generator" or owner_text == "Surface-Panel-Generator" then append cap_nodes child_node
        )
        if cap_nodes.count > 2 then throw "TPG LOAD | More than two generated module Hatches are ambiguous."
        local cap_data = #()
        local cap_records = #()
        local found_enter = false
        local found_exit = false
        for cap_node in cap_nodes do
        (
            local side_text = getUserPropVal cap_node "SPG_CapSide" asString:true
            local end_side = if side_text == undefined or side_text == "Exit" then #exit else if side_text == "Enter" then #enter else undefined
            if end_side == undefined or (end_side == #enter and found_enter) or (end_side == #exit and found_exit) then
                throw "TPG LOAD | Duplicate or invalid Hatch end ownership."
            if end_side == #enter then found_enter = true else found_exit = true
            if cap_node.modifiers.count != 2 then throw "TPG LOAD | Cap has foreign or missing modifiers."
            local cap_chamfer = cap_node.modifiers[1]
            local cap_lathe = cap_node.modifiers[2]
            if classOf cap_chamfer != Chamfer or classOf cap_lathe != Lathe then throw "TPG LOAD | Cap stack is not generated Chamfer/Lathe."
            local schema_text = getUserPropVal cap_node "SPG_CapDataSchema" asString:true
            if schema_text != undefined then
            (
                if schema_text != "1" then throw "TPG LOAD | Unsupported cap data schema."
                if (getAppData cap_lathe 1847365210) != "TPG:Lathe" or (getAppData cap_chamfer 1847365210) != "TPG:Chamfer" then
                    throw "TPG LOAD | Cannot establish cap modifier ownership."
            )
            local cap_values = #()
            for property_key in #("SPG_CapEndRadius","SPG_CapThickness","SPG_CapDepth","SPG_CapSeams","SPG_CapFirstSeam","SPG_CapSeamSpacing","SPG_CapChamferAmount","SPG_CapChamferDepth","SPG_CapChamferInset") do
            (
                local raw_text = getUserPropVal cap_node property_key asString:true
                if raw_text == undefined then throw ("TPG LOAD | Missing cap property: " + property_key)
                local number_value = raw_text as float
                if number_value == undefined then throw ("TPG LOAD | Invalid cap property: " + property_key)
                append cap_values number_value
            )
            for property_default in #(#("SPG_CapSeamDepth",default_seam_depth),#("SPG_CapSeamSegments",0),#("SPG_CapTopSegments",0),#("SPG_CapSeamMaterial",99)) do
            (
                local property_text = getUserPropVal cap_node property_default[1] asString:true
                append cap_values (if property_text == undefined then property_default[2] else property_text as float)
            )
            append cap_records #(cap_node,cap_lathe,cap_chamfer,end_side)
            if cap_data.count == 0 or end_side == #exit then cap_data = #(cap_node,cap_lathe,cap_chamfer,cap_values)
        )
        if cap_data.count > 0 then
        (
            append cap_data[4] (if found_enter then 1 else 0)
            append cap_data[4] (if found_exit then 1 else 0)
            append cap_data cap_records
        )
        cap_data
        -- return
    ),


    /*
    Only exact modifier instances owned by this generator are eligible for
    replacement. An unrelated user modifier blocks the update.
    */
    function canReplaceCap target_node owned_lathe owned_chamfer =
    (
        if not isValidNode target_node then false
        else if (getUserProp target_node "SPG_CapOwner") != "Tank-Panel-Generator" and (getUserProp target_node "SPG_CapOwner") != "Surface-Panel-Generator" then
        (
            format "TPG CAP ERROR | Not a tool-owned cap node:%\n" target_node.name
            false
        )
        else
        (
            local owned_valid = (owned_lathe != undefined and owned_chamfer != undefined and target_node.modifiers.count == 2)
            for stack_mod in target_node.modifiers do
            (
                if stack_mod != owned_lathe and stack_mod != owned_chamfer then owned_valid = false
            )
            if owned_valid and (target_node.modifiers[1] != owned_chamfer or target_node.modifiers[2] != owned_lathe) then owned_valid = false
            if not owned_valid then format "TPG CAP ERROR | Modifier stack has unowned instances | node:%\n" target_node.name
            owned_valid
        )
        -- return
    ),


    /*
    Instantiate a completely new Chamfer: explicitly set all important
    behaviours rather than borrowing parameters from any existing modifier.
    Different-material filtering restricts the chamfer to material boundaries;
    individual selected-ID edge groups will be added after runtime validation.
    */
    function createCleanChamfer amount_value depth_value inset_value seam_depth:5.0 seam_segments:0 top_segments:0 seam_material:99 =
    (
        if amount_value < 0.0 or seam_segments < 0 or seam_segments > 100 or seam_segments != (seam_segments as integer) or top_segments < 0 or top_segments > 100 or top_segments != (top_segments as integer) or seam_material < 1 or seam_material > 65535 or seam_material != (seam_material as integer) then
            throw "TPG HATCH | Invalid seam width, segment count or material ID."
        local chamfer_mod = Chamfer()
        chamfer_mod.name = "TPG Cap - Material Seams"
        chamfer_mod.chamfertype = 0
        chamfer_mod.amountType = 0
        chamfer_mod.amount = amount_value
        chamfer_mod.segments = top_segments
        chamfer_mod.selectionoption = 5
        chamfer_mod.materialoption = 1
        chamfer_mod.smoothingoption = 0
        chamfer_mod.useminangle = false
        chamfer_mod.usemaxangle = false
        chamfer_mod.openchamfer = false
        chamfer_mod.limiteffect = true
        chamfer_mod.depthType = 0
        chamfer_mod.depth = depth_value
        chamfer_mod.addinset = true
        chamfer_mod.insetamount = abs inset_value
        chamfer_mod.insetsegments = seam_segments
        chamfer_mod.insetoffset = seam_depth
        chamfer_mod.setmaterial = true
        chamfer_mod.materialid = seam_material
        chamfer_mod.smooth = true
        chamfer_mod
        -- return
    ),


    /* Reuse the panel palette and add only one slot for an extra seam ID.
       Material ID 99 does not require allocating 99 separate materials.
    */
    function makeHatchMaterial band_count seam_material =
    (
        local slot_count = band_count + (if seam_material > band_count then 1 else 0)
        local palette_material = SurfacePanelGenerator.makePaletteMaterial 1 slot_count rule_count:slot_count
        if seam_material > band_count then
        (
            palette_material.materialIDList[slot_count] = seam_material
            palette_material.names[slot_count] = "Seam Material"
            palette_material.materialList[slot_count].name = "Hatch Seam Material"
        )
        palette_material
        -- return
    ),

    /*
    Regenerate one independent cap that follows its source module. This
    preserves the cap node's identity on updates and rejects unowned stacks.
    */
    function generateCap module_node module_radius module_length end_radius radial_thickness axial_depth seam_count first_offset seam_spacing chamfer_amount chamfer_depth chamfer_inset lathe_segments:64 target_node:undefined owned_lathe:undefined owned_chamfer:undefined seam_depth:5.0 seam_segments:0 top_segments:0 seam_material:99 end_side:#exit =
    (
        local result_node = undefined
        if end_side != #enter and end_side != #exit then throw "TPG HATCH | Invalid module end."
        if not isValidNode module_node or module_radius <= 0.0 or module_length <= 0.0 or radial_thickness < 0.0 or chamfer_amount < 0.0 or lathe_segments < 3 then
        (
            format "TPG CAP ERROR | Bad input/module | module:% radius:% length:% thickness:% depth:% chamfer:% segments:%\n" module_node module_radius module_length radial_thickness axial_depth chamfer_amount lathe_segments
            undefined
        )
        else if target_node != undefined and (not (canReplaceCap target_node owned_lathe owned_chamfer)) then
        (
            undefined
        )
        else
        (
            local outer_radius = module_radius + radial_thickness
            local seam_radii = makeSeamRadii outer_radius end_radius seam_count first_offset seam_spacing
            if seam_radii == undefined then
            (
                undefined
            )
            else
            (
                local profile_node = createProfile outer_radius end_radius axial_depth seam_radii
                local cap_band_count = numSegments profile_node 1
                local lathe_mod = Lathe()
                lathe_mod.name = "TPG Cap - Lathe"
                lathe_mod.degrees = 360.0
                lathe_mod.segs = lathe_segments
                lathe_mod.weldCore = (end_radius == 0.0)
                lathe_mod.mapCoords = true
                lathe_mod.matIDs = true
                lathe_mod.useShapeIDs = true
                lathe_mod.smooth = true
                addModifier profile_node lathe_mod
                lathe_mod.axis.position = [0,0,0]
                lathe_mod.axis.rotation = (quat -90 [1,0,0])
                lathe_mod.axis.scale = [1,1,1]


                local chamfer_mod = createCleanChamfer chamfer_amount chamfer_depth chamfer_inset seam_depth:seam_depth seam_segments:seam_segments top_segments:top_segments seam_material:seam_material
                addModifier profile_node chamfer_mod


                if isValidNode target_node then
                (
                    instanceReplace target_node profile_node
                    delete profile_node
                    result_node = target_node
                )
                else
                (
                    result_node = profile_node
                )


                if not isValidNode result_node or result_node.modifiers.count != 2 then
                (
                    format "TPG CAP ERROR | Cap stack replacement failed | target:%\n" target_node
                    throw "TPG cap modifier stack replacement failed."
                )
                else
                (
                    -- The profile's Y axis is the axial direction; match the
                    -- owning cylindrical module transform before linking.
                    /* TPG's bent local cylinder axis is Y through Z=-Radius.
                       Include the module's object offset, rotation and scale.
                       Enter reverses the profile normal so thickness points out.
                    */
                    local end_sign = if end_side == #enter then -1.0 else 1.0
                    local hatch_frame = matrix3 [1,0,0] [0,end_sign,0] [0,0,end_sign] [0,end_sign * module_length * 0.5,-module_radius]
                    result_node.transform = hatch_frame * module_node.objectTransform
                    result_node.parent = module_node
                    setUserProp result_node "SPG_CapSide" (if end_side == #enter then "Enter" else "Exit")
                    result_node.material = makeHatchMaterial (cap_band_count - (if axial_depth != 0.0 then 1 else 0)) seam_material
                    setAppData result_node.modifiers[2] 1847365210 "TPG:Lathe"
                    setAppData result_node.modifiers[1] 1847365210 "TPG:Chamfer"
                    setUserProp result_node "SPG_CapDataSchema" 1
                    setUserProp result_node "SPG_CapOwner" "Tank-Panel-Generator"
                    setUserProp result_node "SPG_CapEndRadius" (formattedPrint end_radius format:".9g")
                    setUserProp result_node "SPG_CapThickness" (formattedPrint radial_thickness format:".9g")
                    setUserProp result_node "SPG_CapDepth" (formattedPrint axial_depth format:".9g")
                    setUserProp result_node "SPG_CapSeams" seam_count
                    setUserProp result_node "SPG_CapFirstSeam" (formattedPrint first_offset format:".9g")
                    setUserProp result_node "SPG_CapSeamSpacing" (formattedPrint seam_spacing format:".9g")
                    setUserProp result_node "SPG_CapChamferAmount" (formattedPrint chamfer_amount format:".9g")
                    setUserProp result_node "SPG_CapChamferDepth" (formattedPrint chamfer_depth format:".9g")
                    setUserProp result_node "SPG_CapChamferInset" (formattedPrint chamfer_inset format:".9g")
                    setUserProp result_node "SPG_CapSeamDepth" (formattedPrint seam_depth format:".9g")
                    setUserProp result_node "SPG_CapSeamSegments" seam_segments
                    setUserProp result_node "SPG_CapTopSegments" top_segments
                    setUserProp result_node "SPG_CapSeamMaterial" seam_material
                    last_node = result_node
                    last_lathe_mod = result_node.modifiers[2]
                    last_chamfer_mod = result_node.modifiers[1]
                    last_module = module_node
                    format "TPG CAP | Node:% | seam bands:% | Lathe:% Chamfer:%\n" result_node.name cap_band_count last_lathe_mod last_chamfer_mod
                    result_node
                )
            )
        )
        -- return
    ),


    /* Generate/update the requested module ends and delete only owned disabled ends.
       Each end has its own side marker; legacy single caps are treated as Exit.
    */
    function generateModuleHatches module_node module_radius module_length settings_value lathe_segments:64 =
    (
        local old_data = readModuleCap module_node
        setUserProp module_node "SPG_HatchManaged" 1
        local old_records = if old_data.count > 0 then old_data[5] else #()
        local primary_node = undefined
        for end_side in #(#enter,#exit) do
        (
            local old_record = undefined
            for cap_record in old_records where cap_record[4] == end_side do old_record = cap_record
            local end_setting_index = if end_side == #enter then 14 else 15
            local end_enabled = settings_value[end_setting_index] == 1
            if end_enabled then
            (
                local target_node = if old_record == undefined then undefined else old_record[1]
                local owned_lathe = if old_record == undefined then undefined else old_record[2]
                local owned_chamfer = if old_record == undefined then undefined else old_record[3]
                primary_node = generateCap module_node module_radius module_length settings_value[1] settings_value[2] settings_value[3] (settings_value[4] as integer) settings_value[5] settings_value[6] settings_value[7] settings_value[8] settings_value[9] lathe_segments:lathe_segments target_node:target_node owned_lathe:owned_lathe owned_chamfer:owned_chamfer seam_depth:settings_value[10] seam_segments:(settings_value[11] as integer) top_segments:(settings_value[12] as integer) seam_material:(settings_value[13] as integer) end_side:end_side
                if not isValidNode primary_node then throw "TPG HATCH | Requested module end could not be generated."
            )
            else if old_record != undefined then
            (
                if not (canReplaceCap old_record[1] old_record[2] old_record[3]) then throw "TPG HATCH | Disabled end is not safely owned."
                delete old_record[1]
            )
        )
        last_node = primary_node
        last_lathe_mod = if isValidNode primary_node then primary_node.modifiers[2] else undefined
        last_chamfer_mod = if isValidNode primary_node then primary_node.modifiers[1] else undefined
        last_module = module_node
        primary_node
        -- return
    ),

    /*
    Generates a standalone editable spline with owned Lathe and seam Chamfer.
    No module is required. A previously generated standalone Hatch is
    updated only if its own ownership marker and Lathe instance match.
    */
    function generateStandaloneHatch module_radius end_radius radial_thickness axial_depth seam_count first_offset seam_spacing lathe_segments:64 target_node:undefined owned_lathe:undefined owned_chamfer:undefined chamfer_amount:1.0 chamfer_depth:0.5 stitch_width:0.0 seam_depth:5.0 seam_segments:0 top_segments:0 seam_material:99 =
    (
        if module_radius <= 0.0 or radial_thickness < 0.0 or lathe_segments < 3 then
            throw "TPG HATCH | Invalid radius, thickness or Lathe segment count."
        local outer_radius = module_radius + radial_thickness
        local seam_radii = makeSeamRadii outer_radius end_radius seam_count first_offset seam_spacing
        if seam_radii == undefined then throw "TPG HATCH | Invalid radial seam profile."
        if isValidNode target_node then
        (
            if (getUserPropVal target_node "SPG_StandaloneHatch" asString:true) != "1" or
                (target_node.modifiers.count != 1 and target_node.modifiers.count != 2) or
                target_node.modifiers[target_node.modifiers.count] != owned_lathe or
                classOf owned_lathe != Lathe or
                (getAppData owned_lathe 1847365210) != "TPG:Lathe" then
                throw "TPG HATCH | Refusing to overwrite a foreign or modified spline."
            if target_node.modifiers.count == 2 then
            (
                if target_node.modifiers[1] != owned_chamfer or classOf owned_chamfer != Chamfer or (getAppData owned_chamfer 1847365210) != "TPG:Chamfer" then
                    throw "TPG HATCH | Refusing to overwrite an unowned seam modifier."
            )
        )
        local profile_node = createProfile outer_radius end_radius axial_depth seam_radii
        local band_count = numSegments profile_node 1
        local lathe_mod = Lathe()
        lathe_mod.name = "TPG Hatch - Lathe"
        lathe_mod.degrees = 360.0
        lathe_mod.segs = lathe_segments
        lathe_mod.weldCore = (end_radius == 0.0)
        lathe_mod.mapCoords = true
        lathe_mod.matIDs = true
        lathe_mod.useShapeIDs = true
        lathe_mod.smooth = true
        addModifier profile_node lathe_mod
        lathe_mod.axis.position = [0,0,0]
        lathe_mod.axis.rotation = (quat -90 [1,0,0])
        lathe_mod.axis.scale = [1,1,1]
        if profile_node.modifiers.count != 1 or classOf profile_node.modifiers[1] != Lathe then
        (
            delete profile_node
            throw "TPG HATCH | Native Lathe modifier was not added to the spline."
        )
        local chamfer_mod = createCleanChamfer chamfer_amount chamfer_depth stitch_width seam_depth:seam_depth seam_segments:seam_segments top_segments:top_segments seam_material:seam_material
        addModifier profile_node chamfer_mod
        local result_node = profile_node
        if isValidNode target_node then
        (
            instanceReplace target_node profile_node
            delete profile_node
            result_node = target_node
        )
        if not isValidNode result_node or result_node.modifiers.count != 2 or classOf result_node.modifiers[2] != Lathe or classOf result_node.modifiers[1] != Chamfer then
            throw "TPG HATCH | The standalone spline/Lathe stack was not preserved."
        setAppData result_node.modifiers[2] 1847365210 "TPG:Lathe"
        setAppData result_node.modifiers[1] 1847365210 "TPG:Chamfer"
        result_node.material = makeHatchMaterial (band_count - (if axial_depth != 0.0 then 1 else 0)) seam_material
        setUserProp result_node "SPG_StandaloneHatch" 1
        setUserProp result_node "SPG_CapOwner" "Tank-Panel-Generator"
        setUserProp result_node "SPG_CapEndRadius" (formattedPrint end_radius format:".9g")
        setUserProp result_node "SPG_CapThickness" (formattedPrint radial_thickness format:".9g")
        setUserProp result_node "SPG_CapDepth" (formattedPrint axial_depth format:".9g")
        setUserProp result_node "SPG_CapSeams" seam_count
        setUserProp result_node "SPG_CapFirstSeam" (formattedPrint first_offset format:".9g")
        setUserProp result_node "SPG_CapSeamSpacing" (formattedPrint seam_spacing format:".9g")
        setUserProp result_node "SPG_CapChamferAmount" (formattedPrint chamfer_amount format:".9g")
        setUserProp result_node "SPG_CapChamferDepth" (formattedPrint chamfer_depth format:".9g")
        setUserProp result_node "SPG_CapChamferInset" (formattedPrint stitch_width format:".9g")
        setUserProp result_node "SPG_CapSeamDepth" (formattedPrint seam_depth format:".9g")
        setUserProp result_node "SPG_CapSeamSegments" seam_segments
        setUserProp result_node "SPG_CapTopSegments" top_segments
        setUserProp result_node "SPG_CapSeamMaterial" seam_material
        last_node = result_node
        last_lathe_mod = result_node.modifiers[2]
        last_chamfer_mod = result_node.modifiers[1]
        last_module = undefined
        format "TPG HATCH | Standalone spline:% | profile segments:% | native Lathe:%\n" result_node.name band_count last_lathe_mod
        result_node
        -- return
    ),


    on create do ()


)


global CapHatchGenerator
CapHatchGenerator = SurfacePanelCapGenerator_v()

