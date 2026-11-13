/*
Modifier Manager shared scene preset engine.
File version: 0.011 | Project version: 0.011.
*/
global modifierPresetManager
global modifier_manager_project_version
if modifier_manager_project_version == undefined or modifier_manager_project_version < 0.011 then modifier_manager_project_version = 0.011

/*
The same preset-list backend serves the MeshSmooth and Chamfer child rollouts.
Scene-root properties store values even when no modifier instance is attached.
*/
struct modifierPresetManager_v
(
    last_error = "",
    appdata_id = 1763145907,

    /*
    Return the stable scene-property prefix for one supported native type.
    Unknown types have no preset namespace.
    */
    function getPrefix type_id =
    (
        case type_id of
        (
            #meshsmooth: "MMPS_SM_"
            #chamfer: "MMPS_CH_"
            default: ""
        )
        -- return
    ),

    /*
    Return the documented native MAXScript property names in snapshot order.
    The order is also the serialized scene-preset schema.
    */
    function getProperties type_id =
    (
        case type_id of
        (
            #meshsmooth: #(#iterations, #renderIterations, #useRenderIterations, #sepByMats, #sepBySmGroups, #Apply_To_Whole_Mesh, #enabled)
            #chamfer: #(#amount, #segments, #openchamfer, #enabled, #selectionoption, #chamfertype, #tension, #materialoption, #smoothingoption, #addinset, #insetamount, #insetoffset, #insetsegments)
            default: #()
        )
        -- return
    ),

    /*
    Verify a native modifier has the requested class.
    A matching display name alone is never considered ownership.
    */
    function matchesType type_id target_mod =
    (
        if target_mod == undefined then false
        else
        (
            case type_id of
            (
                #meshsmooth: (classOf target_mod == MeshSmooth)
                #chamfer: (classOf target_mod == Chamfer)
                default: false
            )
        )
        -- return
    ),

    /*
    Read a complete supported native modifier property snapshot.
    Return undefined if the instance/type is invalid.
    */
    function readSettings type_id target_mod =
    (
        setting_values = undefined
        property_names = this.getProperties type_id
        if this.matchesType type_id target_mod and property_names.count > 0 then
        (
            setting_values = for prop_name in property_names collect (getProperty target_mod prop_name)
        )
        else
        (
            this.last_error = "Unsupported preset modifier type or instance."
            format "Modifier Manager | readSettings | type:% instance:%\n" type_id target_mod
        )
        setting_values -- return Array or undefined
    ),

    /*
    Produce a readable name using native values rather than a remembered label.
    MeshSmooth abbreviations: Mat, SG and A (whole mesh).
    */
    function makePresetName type_id setting_values =
    (
        result_name = ""
        if type_id == #meshsmooth and setting_values.count >= 7 then
        (
            result_name = "Smooth " + (setting_values[1] as string)
            if setting_values[4] then result_name += " Mat"
            if setting_values[5] then result_name += " SG"
            if setting_values[6] then result_name += "A"
            if setting_values[3] then result_name += (" R" + (setting_values[2] as string))
        )
        else if type_id == #chamfer and setting_values.count >= 13 then
        (
            result_name = "Chamfer " + (setting_values[1] as string) + " x" + (setting_values[2] as string)
            if setting_values[8] == 1 then result_name += " MatDiff"
            if setting_values[8] == 2 then result_name += " MatSame"
            if setting_values[9] == 1 then result_name += " SGSm"
            if setting_values[9] == 2 then result_name += " SGUn"
            if setting_values[10] then result_name += " Inset"
        )
        result_name -- return
    ),

    /*
    Return the number of entries in the scene-local catalog for this type.
    Missing root data means a new empty scene catalog.
    */
    function getPresetCount type_id =
    (
        prefix_text = this.getPrefix type_id
        preset_count = 0
        if prefix_text != "" then
        (
            saved_count = getUserPropVal rootNode (prefix_text + "COUNT")
            if classOf saved_count == Integer and saved_count > 0 then preset_count = saved_count
        )
        preset_count -- return
    ),

    /*
    Load one typed scene snapshot by its ordinal preset ID.
    A missing property is a corrupt/incomplete preset, not an empty preset.
    */
    function getPresetSettings type_id preset_id =
    (
        setting_values = undefined
        prefix_text = this.getPrefix type_id
        property_names = this.getProperties type_id
        if preset_id > 0 and preset_id <= this.getPresetCount type_id and prefix_text != "" then
        (
            loaded_values = #()
            data_valid = true
            for prop_index = 1 to property_names.count while data_valid do
            (
                prop_key = prefix_text + (preset_id as string) + "_" + (prop_index as string)
                prop_value = getUserPropVal rootNode prop_key
                if prop_value == undefined then
                (
                    this.last_error = "Missing scene preset property " + prop_key
                    format "Modifier Manager | preset read | missing:%\n" prop_key
                    data_valid = false
                )
                else
                (
                    append loaded_values prop_value
                )
            )
            if data_valid then setting_values = loaded_values
        )
        setting_values -- return Array or undefined
    ),

    /*
    Write the complete snapshot under one existing/new scene preset ID.
    Updating the COUNT key last prevents partial new entries from appearing.
    */
    function storePresetSettings type_id preset_id setting_values =
    (
        stored_ok = false
        prefix_text = this.getPrefix type_id
        property_names = this.getProperties type_id
        if prefix_text != "" and preset_id > 0 and classOf setting_values == Array and setting_values.count == property_names.count then
        (
            for prop_index = 1 to property_names.count do
            (
                prop_key = prefix_text + (preset_id as string) + "_" + (prop_index as string)
                setUserPropVal rootNode prop_key setting_values[prop_index]
            )
            if preset_id > this.getPresetCount type_id then setUserPropVal rootNode (prefix_text + "COUNT") preset_id
            stored_ok = true
        )
        else
        (
            this.last_error = "Invalid preset property count or type."
            format "Modifier Manager | store preset | type:% id:% length:% expected:%\n" type_id preset_id (if classOf setting_values == Array then setting_values.count else undefined) property_names.count
        )
        stored_ok -- return
    ),

    /*
    Return an identity tag that is stored directly on the native modifier.
    Names do not define preset ownership.
    */
    function getIdentityTag type_id preset_id =
    (
        (this.getPrefix type_id) + (preset_id as string) -- return
    ),

    /*
    Register a new scene preset from a complete setting snapshot.
    An optional already-attached instance becomes the preferred live instance.
    */
    function savePreset type_id setting_values source_mod =
    (
        saved_id = 0
        property_names = this.getProperties type_id
        source_ok = source_mod == undefined or this.matchesType type_id source_mod
        if source_ok and property_names.count > 0 and classOf setting_values == Array and setting_values.count == property_names.count then
        (
            candidate_id = (this.getPresetCount type_id) + 1
            if this.storePresetSettings type_id candidate_id setting_values then
            (
                saved_id = candidate_id
                if source_mod != undefined then
                (
                    source_mod.name = this.makePresetName type_id setting_values
                    setAppData source_mod this.appdata_id (this.getIdentityTag type_id saved_id)
                )
            )
        )
        else
        (
            this.last_error = "Cannot save mismatched native modifier or settings."
            format "Modifier Manager | save preset | type:% source:% values:%\n" type_id source_mod setting_values
        )
        saved_id -- return
    ),

    /*
    Enumerate the saved scene presets for exactly one modifier class.
    Each row holds #(preset_id, generated_label).
    */
    function getPresetRows type_id =
    (
        rows = #()
        for preset_id = 1 to this.getPresetCount type_id do
        (
            values = this.getPresetSettings type_id preset_id
            if values != undefined then append rows #(preset_id, this.makePresetName type_id values)
        )
        rows -- return
    ),

    /*
    Find the actual tagged native instance on any scene object.
    A catalog record without a live modifier is still a valid preset.
    */
    function getLiveInstance type_id preset_id =
    (
        found_mod = undefined
        identity_tag = this.getIdentityTag type_id preset_id
        if preset_id > 0 then
        (
            for scene_node in objects while found_mod == undefined do
            (
                if isValidNode scene_node then
                (
                    for target_mod in scene_node.modifiers while found_mod == undefined do
                    (
                        if this.matchesType type_id target_mod and (getAppData target_mod this.appdata_id) == identity_tag then found_mod = target_mod
                    )
                )
            )
        )
        found_mod -- return native modifier or undefined
    ),

    /*
    Apply the stored values to a matching native modifier instance.
    No scene data is touched for an invalid type or property count.
    */
    function writeSettings type_id target_mod setting_values =
    (
        applied_ok = false
        property_names = this.getProperties type_id
        if this.matchesType type_id target_mod and classOf setting_values == Array and setting_values.count == property_names.count then
        (
            for prop_index = 1 to property_names.count do
            (
                setProperty target_mod property_names[prop_index] setting_values[prop_index]
            )
            target_mod.name = this.makePresetName type_id setting_values
            applied_ok = true
        )
        else
        (
            this.last_error = "Target class does not match the complete preset snapshot."
            format "Modifier Manager | writeSettings | type:% instance:% values:%\n" type_id target_mod setting_values
        )
        applied_ok -- return
    ),

    /*
    Create a native modifier without creating any scripted modifier dependency.
    The instance is not attached until a subsequent Add operation.
    */
    function createModifier type_id setting_values =
    (
        new_mod = case type_id of
        (
            #meshsmooth: (MeshSmooth())
            #chamfer: (Chamfer())
            default: undefined
        )
        if new_mod != undefined then
        (
            if not (this.writeSettings type_id new_mod setting_values) then new_mod = undefined
        )
        new_mod -- return
    ),

    /*
    Use a tagged, currently attached preset instance when available.
    Otherwise build exactly one new instance from the saved scene values.
    */
    function resolveSharedInstance type_id preset_id =
    (
        found_mod = this.getLiveInstance type_id preset_id
        if found_mod == undefined then
        (
            values = this.getPresetSettings type_id preset_id
            if values != undefined then
            (
                found_mod = this.createModifier type_id values
                if found_mod != undefined then setAppData found_mod this.appdata_id (this.getIdentityTag type_id preset_id)
            )
        )
        found_mod -- return
    ),

    /*
    Return the matching modifier nearest the top of one live modifier stack.
    Other same-type occurrences are intentionally not chosen.
    */
    function findTopmost scene_node type_id =
    (
        found_mod = undefined
        if isValidNode scene_node then
        (
            for target_mod in scene_node.modifiers while found_mod == undefined do
            (
                if this.matchesType type_id target_mod then found_mod = target_mod
            )
        )
        found_mod -- return
    ),

    /*
    Preflight the selected scene nodes before writing any modifier stack.
    Invalid targets abort the entire operation rather than silently skipping.
    */
    function selectedValidNodes type_id =
    (
        selected_nodes = for scene_node in selection where isValidNode scene_node collect scene_node
        type_class = case type_id of
        (
            #meshsmooth: MeshSmooth
            #chamfer: Chamfer
            default: undefined
        )
        valid_selection = selected_nodes.count > 0 and type_class != undefined
        for scene_node in selected_nodes while valid_selection do
        (
            if not validModifier scene_node type_class then
            (
                valid_selection = false
                this.last_error = "Modifier cannot be applied to " + scene_node.name
                format "Modifier Manager | selection preflight | node:% type:%\n" scene_node.name type_id
            )
        )
        if not valid_selection then
        (
            if this.last_error == "" then this.last_error = "Select one or more compatible scene objects."
            format "Modifier Manager | selection invalid | type:% selection:%\n" type_id selection.count
            selected_nodes = #()
        )
        selected_nodes -- return
    ),

    /*
    Add one tagged live instance to all selected nodes, or a new copy per node.
    Existing modifier stacks are not deleted or reordered.
    */
    function addToSelection type_id preset_id unique_mode =
    (
        added_count = 0
        this.last_error = ""
        selected_nodes = this.selectedValidNodes type_id
        values = this.getPresetSettings type_id preset_id
        if selected_nodes.count > 0 and values != undefined then
        (
            shared_mod = if unique_mode then undefined else (this.resolveSharedInstance type_id preset_id)
            with redraw off
            (
                undo "Modifier Manager | Add Preset" on
                (
                    for scene_node in selected_nodes do
                    (
                        target_mod = if unique_mode then (this.createModifier type_id values) else shared_mod
                        if target_mod == undefined then
                        (
                            format "Modifier Manager | add failed | node:% type:% preset:%\n" scene_node.name type_id preset_id
                            throw "Failed to create preset modifier."
                        )
                        addModifier scene_node target_mod
                        added_count += 1
                    )
                )
            )
            if added_count > 0 then redrawViews()
        )
        added_count -- return
    ),

    /*
    Replace only the topmost same-type occurrence on each selected object.
    Insert above the exact old modifier, verify adjacency, then delete it.
    */
    function reinstanceSelection type_id preset_id =
    (
        replaced_count = 0
        this.last_error = ""
        selected_nodes = this.selectedValidNodes type_id
        if selected_nodes.count > 0 then
        (
            source_mod = this.resolveSharedInstance type_id preset_id
            if source_mod != undefined then
            (
                targets = #()
                for scene_node in selected_nodes do
                (
                    old_mod = this.findTopmost scene_node type_id
                    if old_mod != undefined and old_mod != source_mod then append targets #(scene_node, old_mod)
                )
                with redraw off
                (
                    undo "Modifier Manager | Re-instance Preset" on
                    (
                        for item_pair in targets do
                        (
                            scene_node = item_pair[1]
                            old_mod = item_pair[2]
                            old_index = modifierManager.getStackIndex scene_node old_mod
                            if old_index == 0 then
                            (
                                format "Modifier Manager | re-instance missing target | node:% modifier:%\n" scene_node.name old_mod
                                throw "Exact old modifier no longer exists on target node."
                            )
                            if old_index == 1 then addModifier scene_node source_mod
                            else addModifier scene_node source_mod before:(old_index - 1)
                            new_index = modifierManager.getStackIndex scene_node source_mod
                            shifted_index = modifierManager.getStackIndex scene_node old_mod
                            if shifted_index != new_index + 1 then
                            (
                                format "Modifier Manager | re-instance placement failed | node:% old:% new:% expected:%\n" scene_node.name shifted_index new_index (new_index + 1)
                                throw "The exact modifier was not inserted immediately above its target."
                            )
                            deleteModifier scene_node old_mod
                            replaced_count += 1
                        )
                    )
                )
                if replaced_count > 0 then redrawViews()
            )
        )
        replaced_count -- return
    ),

    /*
    Persist a tagged native instance's latest settings after remote edits.
    Updates only its existing exact scene preset entry.
    */
    function refreshTaggedPreset type_id target_mod =
    (
        changed_count = 0
        if this.matchesType type_id target_mod then
        (
            for preset_id = 1 to this.getPresetCount type_id while changed_count == 0 do
            (
                if (getAppData target_mod this.appdata_id) == (this.getIdentityTag type_id preset_id) then
                (
                    values = this.readSettings type_id target_mod
                    if values != undefined and (this.storePresetSettings type_id preset_id values) then
                    (
                        target_mod.name = this.makePresetName type_id values
                        changed_count = 1
                    )
                )
            )
        )
        changed_count -- return
    ),

    on create do
    (
        last_error = ""
    )
)

modifierPresetManager = modifierPresetManager_v()
