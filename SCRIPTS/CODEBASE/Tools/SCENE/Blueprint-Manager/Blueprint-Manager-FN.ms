    /*
    Scene operations and BlueprintManager_v. Compile-time included by Blueprint-Manager.ms.
    */
    /*
    Owns blueprint paths and operations without referring to rollout controls.
    Path ordering follows the cross-layout: TOP, FRONT, SIDE, BACK, BOTTOM.
    */
    struct BlueprintManager_v
    (
        role_names = #("TOP", "FRONT", "SIDE", "BACK", "BOTTOM"),
        image_paths = #("", "", "", "", ""),
        image_candidates = #(#(), #(), #(), #(), #()),
        position_offsets_mm = #(0.0, 0.0, 0.0, 0.0, 0.0),
        alignment_modes = #(3, 2, 2),
        layer_name = "_BLUEPRINTS",


        /*
        Returns an index for a named blueprint role, or zero when absent.
        */
        function getRoleIndex role_name =
        (
            findItem role_names role_name
            -- return
        ),


        /*
        Validates image filename extensions supported by both GDI+ and BitmapTexture.
        */
        function isImageFile file_path =
        (
            (findItem #(".png", ".jpg", ".jpeg", ".bmp", ".tif", ".tiff") (toLower (getFilenameType file_path))) > 0
            -- return
        ),


        /*
        Reads the actual image resolution in pixels; returns undefined on no path.
        */
        function readImageSize file_path =
        (
            if file_path == "" or not doesFileExist file_path then
            (
                format "BM ERROR | Missing image: %\n" file_path
                return undefined
            )


            local bitmap_ref = openBitmap file_path
            local image_size = [bitmap_ref.width, bitmap_ref.height]
            close bitmap_ref
            image_size
            -- return
        ),


        /*
        Retrieves the existing tagged Plane for the requested role, if any.
        */
        function getBlueprintNode role_name =
        (
            local result_node = undefined
            for scene_node in geometry while result_node == undefined do
            (
                if (getUserPropVal scene_node "BM_ROLE") == role_name then
                (
                    result_node = scene_node
                )
            )
            result_node
            -- return
        ),


        /*
        Returns or creates the scene layer requested in OPTIONS.
        Rejects empty and default layer names to keep managed planes separate.
        */
        function ensureBlueprintLayer =
        (
            if layer_name == "" or layer_name == "0" or (filterString layer_name " \t\r\n").count == 0 then
            (
                format "BM LAYER ERROR | Invalid blueprint layer name: '%'\n" layer_name
                return undefined
            )


            local target_layer = LayerManager.getLayerFromName layer_name
            if target_layer == undefined then target_layer = LayerManager.newLayerFromName layer_name
            if target_layer == undefined then
            (
                format "BM LAYER ERROR | Cannot create or find layer: '%'\n" layer_name
            )
            target_layer
            -- return
        ),


        /*
        Adds an image to a view and optionally selects it without altering geometry.
        */
        function assignImage role_index file_path activate:true =
        (
            if role_index < 1 or role_index > 5 or not doesFileExist file_path or not isImageFile file_path then
            (
                format "BM ERROR | Invalid image assignment: role:% file:%\n" role_index file_path
                return false
            )
            local image_size = try (readImageSize file_path) catch
            (
                format "BM ERROR | Could not read %: %\n" file_path (getCurrentException())
                undefined
            )
            if image_size == undefined then return false


            local candidate_paths = image_candidates[role_index]
            local path_key = toLower file_path
            local existing_path = undefined
            for candidate_path in candidate_paths while existing_path == undefined do
            (
                if (toLower candidate_path) == path_key then existing_path = candidate_path
            )
            if existing_path == undefined then
            (
                append candidate_paths file_path
                existing_path = file_path
            )
            if activate or image_paths[role_index] == "" then image_paths[role_index] = existing_path
            true
            -- return
        ),


        /*
        Clears an assigned blueprint and removes only its matching managed Plane.
        Returns true only after the managed Plane is absent from the scene.
        */
        function resetBlueprint role_index =
        (
            local reset_ok = false
            if role_index < 1 or role_index > role_names.count then
            (
                format "BM RESET ERROR | Invalid blueprint role index: %\n" role_index
            )
            else
            (
                local role_name = role_names[role_index]
                local target_node = getBlueprintNode role_name
                if target_node != undefined and (classOf target_node.baseObject) != Plane then
                (
                    format "BM RESET ERROR | Managed role is not a Plane | role:% node:% class:%\n" role_name target_node.name (classOf target_node.baseObject)
                )
                else
                (
                    if target_node != undefined then
                    (
                        delete target_node
                    )
                    reset_ok = ((getBlueprintNode role_name) == undefined)
                    if reset_ok then
                    (
                        image_paths[role_index] = ""
                        image_candidates[role_index] = #()
                        position_offsets_mm[role_index] = 0.0
                    )
                    else
                    (
                        format "BM RESET ERROR | Managed Plane was not removed | role:%\n" role_name
                    )
                )
            )
            reset_ok
            -- return
        ),


        /*
        Resolves one file to a role by wildcard matching any part of its basename.
        Returns 0 (unmatched), -1 (ambiguous), or a slot index.
        */
        function classifyFilename file_path =
        (
            local base_name = toLower (getFilenameFile file_path)
            local found_roles = #()
            if matchPattern base_name pattern:"*top*" then append found_roles 1
            if matchPattern base_name pattern:"*front*" then append found_roles 2
            if matchPattern base_name pattern:"*side*" or matchPattern base_name pattern:"*left*" or matchPattern base_name pattern:"*right*" then append found_roles 3
            if matchPattern base_name pattern:"*back*" then append found_roles 4
            if matchPattern base_name pattern:"*bottom*" then append found_roles 5


            if found_roles.count > 1 then -1
            else if found_roles.count == 1 then found_roles[1]
            else 0
            -- return
        ),


        /*
        Adds every unambiguous image to its view in filename order.
        Returns #(views_with_images, ambiguous_files).
        */
        function assignFolder folder_path =
        (
            local imported_views = #(false, false, false, false, false)
            local imported_count = 0
            local conflict_count = 0
            local folder_files = getFiles (folder_path + "\\*.*")
            sort folder_files
            for file_path in folder_files where isImageFile file_path do
            (
                local role_index = classifyFilename file_path
                if role_index == 3 then
                (
                    local base_name = getFilenameFile file_path
                    if (matchPattern base_name pattern:"*left*" ignoreCase:true) and
                        (matchPattern base_name pattern:"*right*" ignoreCase:true) then role_index = -1
                )
                if role_index == -1 then
                (
                    conflict_count += 1
                    format "BM CONFLICT | Multiple role tokens in %\n" file_path
                )
                else if role_index > 0 then
                (
                    if assignImage role_index file_path activate:false then
                    (
                        if not imported_views[role_index] then imported_count += 1
                        imported_views[role_index] = true
                    )
                )
            )
            #(imported_count, conflict_count)
            -- return
        ),


        /*
        Computes the image plane width and height in 3ds Max system units.
        One image pixel is 1 mm by default, independent of display units.
        */
        function getPlaneSize role_index mm_per_pixel =
        (
            local image_size = readImageSize image_paths[role_index]
            if image_size == undefined then return undefined
            local mm_unit = units.decodeValue "1mm"
            [(image_size.x * mm_per_pixel * mm_unit), (image_size.y * mm_per_pixel * mm_unit)]
            -- return
        ),


        /*
        Collects assigned Plane dimensions and the three virtual-box spans.
        Returns #(five plane sizes, span Point3) in current system units.
        */
        function getSceneLayout mm_per_pixel =
        (
            local plane_sizes = #(undefined, undefined, undefined, undefined, undefined)
            local span_x = 0.0
            local span_y = 0.0
            local span_z = 0.0
            local reference_extent = 0.0


            for role_index = 1 to 5 do
            (
                if image_paths[role_index] != "" then
                (
                    local plane_size = getPlaneSize role_index mm_per_pixel
                    plane_sizes[role_index] = plane_size
                    if plane_size != undefined then
                    (
                        if plane_size.x > reference_extent then reference_extent = plane_size.x
                        if plane_size.y > reference_extent then reference_extent = plane_size.y
                        case role_index of
                        (
                            1: (if plane_size.x > span_x then span_x = plane_size.x; if plane_size.y > span_y then span_y = plane_size.y)
                            2: (if plane_size.x > span_x then span_x = plane_size.x; if plane_size.y > span_z then span_z = plane_size.y)
                            3: (if plane_size.x > span_y then span_y = plane_size.x; if plane_size.y > span_z then span_z = plane_size.y)
                            4: (if plane_size.x > span_x then span_x = plane_size.x; if plane_size.y > span_z then span_z = plane_size.y)
                            5: (if plane_size.x > span_x then span_x = plane_size.x; if plane_size.y > span_y then span_y = plane_size.y)
                        )
                    )
                )
            )


            if span_x == 0.0 then span_x = reference_extent
            if span_y == 0.0 then span_y = reference_extent
            if span_z == 0.0 then span_z = reference_extent


            #(plane_sizes, [span_x, span_y, span_z])
            -- return
        ),


        /*
        Returns five slider limits in millimeters, measured from neighboring views.
        A role without a perpendicular reference has no defined travel range.
        */
        function getPositionRangesMm layout_data =
        (
            local plane_sizes = layout_data[1]
            local travel_z = 0.0
            local travel_y = 0.0
            local travel_x = 0.0
            local mm_unit = units.decodeValue "1mm"


            for role_index in #(2, 3, 4) do
            (
                if plane_sizes[role_index] != undefined then
                (
                    if plane_sizes[role_index].y > travel_z then travel_z = plane_sizes[role_index].y
                )
            )


            if plane_sizes[3] != undefined then
            (
                travel_y = plane_sizes[3].x
            )
            else
            (
                for role_index in #(1, 5) do
                (
                    if plane_sizes[role_index] != undefined and plane_sizes[role_index].y > travel_y then travel_y = plane_sizes[role_index].y
                )
            )


            if plane_sizes[2] != undefined then travel_x = plane_sizes[2].x
            else if plane_sizes[4] != undefined then travel_x = plane_sizes[4].x
            else
            (
                for role_index in #(1, 5) do
                (
                    if plane_sizes[role_index] != undefined and plane_sizes[role_index].x > travel_x then travel_x = plane_sizes[role_index].x
                )
            )


            #(travel_z / mm_unit, travel_y / mm_unit, travel_x / mm_unit, travel_y / mm_unit, travel_z / mm_unit)
            -- return
        ),


        /*
        Computes the combined world-space bounds of the managed Plane nodes.
        The bounds are independent of their pivot positions or current selection.
        */
        function getManagedBounds =
        (
            local bounds_min = undefined
            local bounds_max = undefined
            local found_count = 0


            for role_name in role_names do
            (
                local plane_node = getBlueprintNode role_name
                if plane_node != undefined and (classOf plane_node.baseObject) == Plane then
                (
                    local node_bounds = nodeGetBoundingBox plane_node (matrix3 1)
                    if node_bounds != undefined and node_bounds.count == 2 then
                    (
                        if found_count == 0 then
                        (
                            bounds_min = node_bounds[1]
                            bounds_max = node_bounds[2]
                        )
                        else
                        (
                            bounds_min = [
                                (amin bounds_min.x node_bounds[1].x),
                                (amin bounds_min.y node_bounds[1].y),
                                (amin bounds_min.z node_bounds[1].z)]
                            bounds_max = [
                                (amax bounds_max.x node_bounds[2].x),
                                (amax bounds_max.y node_bounds[2].y),
                                (amax bounds_max.z node_bounds[2].z)]
                        )
                        found_count += 1
                    )
                )
            )


            if found_count == 0 then undefined else #(bounds_min, bounds_max)
            -- return
        ),


        /*
        Aligns the managed Plane group on one world axis only.
        For Z and X: 1 = maximum, 2 = centre, 3 = minimum.
        For Y (FRONT/BACK): 1 = minimum, 2 = centre, 3 = maximum.
        */
        function alignBlueprintAxis axis_index align_state =
        (
            if axis_index < 1 or axis_index > 3 or align_state < 1 or align_state > 3 then
            (
                format "BM ALIGN ERROR | Invalid axis:% state:%\n" axis_index align_state
                return false
            )


            local group_bounds = getManagedBounds()
            if group_bounds == undefined then return false


            local min_coord = case axis_index of
            (
                1: group_bounds[1].z
                2: group_bounds[1].y
                3: group_bounds[1].x
            )
            local max_coord = case axis_index of
            (
                1: group_bounds[2].z
                2: group_bounds[2].y
                3: group_bounds[2].x
            )
            local reference_coord = case align_state of
            (
                1: (if axis_index == 2 then min_coord else max_coord)
                2: ((min_coord + max_coord) / 2.0)
                3: (if axis_index == 2 then max_coord else min_coord)
            )
            local shift_value = -reference_coord


            if (abs shift_value) > 0.000001 then
            (
                local shift_vector = case axis_index of
                (
                    1: [0, 0, shift_value]
                    2: [0, shift_value, 0]
                    3: [shift_value, 0, 0]
                )
                for role_name in role_names do
                (
                    local plane_node = getBlueprintNode role_name
                    if plane_node != undefined and (classOf plane_node.baseObject) == Plane then
                    (
                        plane_node.pos = plane_node.pos + shift_vector
                    )
                )
            )
            true
            -- return
        ),


        /*
        Reapplies all three stored axis alignments after rebuilding planes.
        The axes are independent and no unrelated scene nodes are moved.
        */
        function alignBlueprintGroup =
        (
            local aligned_count = 0
            for axis_index = 1 to 3 do
            (
                if alignBlueprintAxis axis_index alignment_modes[axis_index] then aligned_count += 1
            )
            (aligned_count == 3)
            -- return
        ),


        /*
        Moves one managed plane along its current local Z without cumulative drift.
        The offset is measured inward from its virtual-box wall in millimeters.
        */
        function setPositionOffset role_index offset_mm =
        (
            if role_index < 1 or role_index > 5 or offset_mm < 0.0 then
            (
                format "BM ERROR | Invalid position offset | role:% offset_mm:%\n" role_index offset_mm
                return false
            )


            local target_node = getBlueprintNode role_names[role_index]
            if target_node != undefined then
            (
                local old_offset_mm = getUserPropVal target_node "BM_OFFSET_MM"
                if old_offset_mm == undefined then old_offset_mm = 0.0
                local delta_units = (offset_mm - old_offset_mm) * (units.decodeValue "1mm")
                target_node.pos = target_node.pos + (target_node.transform.row3 * delta_units)
                setUserPropVal target_node "BM_OFFSET_MM" offset_mm
                alignBlueprintGroup()
                redrawViews()
            )
            position_offsets_mm[role_index] = offset_mm
            true
            -- return
        ),


        /*
        Computes the orthonormal plane transform from view orientation and box spans.
        Plane +Z normals always face the scene origin.
        */
        function getPlaneTransform role_name span_x span_y span_z image_path =
        (
            case role_name of
            (
                "TOP":    (matrix3 [1,0,0] [0,1,0] [0,0,1] [0,0,(-span_z / 2.0)])
                "BOTTOM": (matrix3 [-1,0,0] [0,1,0] [0,0,-1] [0,0,(span_z / 2.0)])
                "FRONT":  (matrix3 [1,0,0] [0,0,1] [0,-1,0] [0,(span_y / 2.0),0])
                "BACK":   (matrix3 [-1,0,0] [0,0,1] [0,1,0] [0,(-span_y / 2.0),0])
                "SIDE":
                (
                    /* Only an explicit LEFT filename uses the left-view transform. */
                    if matchPattern (getFilenameFile image_path) pattern:"*left*" ignoreCase:true then
                    (
                        matrix3 [0,-1,0] [0,0,1] [-1,0,0] [(span_x / 2.0),0,0]
                    )
                    else
                    (
                        matrix3 [0,1,0] [0,0,1] [1,0,0] [(-span_x / 2.0),0,0]
                    )
                )
            )
            -- return
        ),


        /*
        Creates or updates a managed blueprint plane and its Standard bitmap material.
        Leaves unrelated scene geometry untouched.
        */
        function createOrUpdate role_index plane_size scene_transform opacity_value =
        (
            local role_name = role_names[role_index]
            local file_path = image_paths[role_index]
            local target_node = getBlueprintNode role_name
            local is_new_node = target_node == undefined
            local target_layer = ensureBlueprintLayer()
            if target_layer == undefined then return false


            if is_new_node then
            (
                target_node = Plane name:("BM_" + role_name) width:plane_size.x length:plane_size.y widthsegs:1 lengthsegs:1 mapcoords:true
            )
            else if (classOf target_node.baseObject) != Plane then
            (
                format "BM ERROR | Tagged object is not Plane | role:% node:% class:%\n" role_name target_node.name (classOf target_node.baseObject)
                return false
            )


            target_node.width = plane_size.x
            target_node.length = plane_size.y
            target_node.mapCoords = true
            target_node.realWorldMapSize = false
            target_node.transform = scene_transform
            local offset_mm = position_offsets_mm[role_index]
            target_node.pos = target_node.pos + (scene_transform.row3 * (offset_mm * units.decodeValue "1mm"))
            target_node.wireColor = color 128 128 128
            target_node.showFrozenInGray = false


            local bitmap_map = bitmapTexture filename:file_path
            bitmap_map.coords.realWorldScale = false
            local image_material = standardMaterial name:("BM_MTL_" + role_name) diffuseMap:bitmap_map diffuseMapEnable:true opacity:opacity_value selfIllumAmount:100 twoSided:true
            target_node.material = image_material
            showTextureMap image_material bitmap_map true
            target_layer.addNode target_node


            /*
            Restores the native SIDE face direction on legacy managed Planes.
            Only the tool-tagged SIDE node's v0.032 inversion marker is neutralized.
            */
            if role_name == "SIDE" and not is_new_node and (getUserPropVal target_node "BM_ROLE") == "SIDE" then
            (
                for stack_modifier in target_node.modifiers do
                (
                    if (classOf stack_modifier) == NormalModifier and stack_modifier.name == "BM_SIDE_NORMAL_FLIP" then
                    (
                        stack_modifier.flip = false
                    )
                )
            )


            setUserPropVal target_node "BM_ROLE" role_name
            setUserPropVal target_node "BM_LAYER" layer_name
            setUserPropVal target_node "BM_FILE" file_path
            setUserPropVal target_node "BM_OFFSET_MM" offset_mm
            if is_new_node then
            (
                target_node.isFrozen = true
            )
            true
            -- return
        ),


        /*
        Synchronizes managed blueprint layer visibility with plane visibility.
        Never hides a layer that contains unrelated scene nodes.
        */
        function syncBlueprintLayerVisibility =
        (
            local layer_names = #()
            for role_name in role_names do
            (
                local plane_node = getBlueprintNode role_name
                if plane_node != undefined then
                (
                    local node_layer_name = getUserPropVal plane_node "BM_LAYER"
                    if (isKindOf node_layer_name String) and node_layer_name != "" and (findItem layer_names node_layer_name) == 0 then
                    (
                        append layer_names node_layer_name
                    )
                )
            )

            local changed_count = 0
            for node_layer_name in layer_names do
            (
                local target_layer = LayerManager.getLayerFromName node_layer_name
                if target_layer != undefined then
                (
                    local layer_nodes = #()
                    if target_layer.nodes &layer_nodes then
                    (
                        local managed_count = 0
                        local visible_blueprint_found = false
                        local unrelated_node_found = false
                        for layer_node in layer_nodes do
                        (
                            if isValidNode layer_node then
                            (
                                local node_role = getUserPropVal layer_node "BM_ROLE"
                                if (findItem role_names node_role) > 0 and (classOf layer_node.baseObject) == Plane then
                                (
                                    managed_count += 1
                                    if not layer_node.isNodeHidden then visible_blueprint_found = true
                                )
                                else
                                (
                                    unrelated_node_found = true
                                )
                            )
                        )

                        if managed_count > 0 then
                        (
                            if visible_blueprint_found then
                            (
                                if target_layer.ishidden then
                                (
                                    target_layer.ishidden = false
                                    changed_count += 1
                                )
                            )
                            else if not unrelated_node_found then
                            (
                                if not target_layer.ishidden then
                                (
                                    target_layer.ishidden = true
                                    changed_count += 1
                                )
                            )
                            else
                            (
                                format "BM LAYER INFO | Not hiding layer containing unrelated objects: %\n" node_layer_name
                            )
                        )
                    )
                    else
                    (
                        format "BM LAYER ERROR | Cannot inspect layer nodes: %\n" node_layer_name
                    )
                )
            )
            changed_count
            -- return
        ),


        /*
        Creates only assigned planes; their centres form a virtual box about [0,0,0].
        Updates managed planes without creating duplicates.
        */
        function createAll mm_per_pixel opacity_value existing_only:false =
        (
            local layout_data = getSceneLayout mm_per_pixel
            local plane_sizes = layout_data[1]
            local scene_spans = layout_data[2]
            local created_count = 0


            for role_index = 1 to 5 do
            (
                if plane_sizes[role_index] != undefined and
                    (not existing_only or (getBlueprintNode role_names[role_index]) != undefined) then
                (
                    local plane_transform = getPlaneTransform role_names[role_index] scene_spans.x scene_spans.y scene_spans.z image_paths[role_index]
                    if createOrUpdate role_index plane_sizes[role_index] plane_transform opacity_value then
                    (
                        created_count += 1
                    )
                )
            )
            if created_count > 0 then
            (
                alignBlueprintGroup()
                syncBlueprintLayerVisibility()
            )
            redrawViews()
            created_count
            -- return
        ),


        /*
        Sets all managed blueprint nodes explicitly visible or hidden.
        Does not change other objects in the same scene layer.
        */
        function setVisibilityState show_enabled =
        (
            local updated_count = 0
            for role_name in role_names do
            (
                local target_node = getBlueprintNode role_name
                if target_node != undefined then
                (
                    target_node.isNodeHidden = not show_enabled
                    updated_count += 1
                )
            )
            if updated_count > 0 then
            (
                syncBlueprintLayerVisibility()
                redrawViews()
            )
            updated_count
            -- return
        ),


        /*
        Deletes only managed blueprint Plane nodes and their now-empty layers.
        Returns -1 on validation or deletion failure; other scene nodes are untouched.
        */
        function deleteManagedBlueprints =
        (
            local managed_nodes = #()
            local managed_layer_names = #()
            for role_name in role_names do
            (
                local target_node = getBlueprintNode role_name
                if target_node != undefined then
                (
                    if (classOf target_node.baseObject) != Plane then
                    (
                        format "BM DELETE ERROR | Expected Plane | role:% node:% class:%\n" role_name target_node.name (classOf target_node.baseObject)
                        return -1
                    )
                    append managed_nodes target_node
                    local used_layer_name = getUserPropVal target_node "BM_LAYER"
                    if (isKindOf used_layer_name String) and used_layer_name != "" and used_layer_name != "0" and (findItem managed_layer_names used_layer_name) == 0 then
                    (
                        append managed_layer_names used_layer_name
                    )
                )
            )
            if managed_nodes.count == 0 then return 0


            local deleted_count = 0
            for target_node in managed_nodes do
            (
                local deleted_node_name = target_node.name
                delete target_node
                if not (isValidNode target_node) then
                (
                    deleted_count += 1
                )
                else
                (
                    format "BM DELETE ERROR | Node still exists: %\n" deleted_node_name
                )
            )
            if deleted_count != managed_nodes.count then
            (
                format "BM DELETE ERROR | Expected:% deleted:%\n" managed_nodes.count deleted_count
                return -1
            )


            for used_layer_name in managed_layer_names do
            (
                local managed_layer = LayerManager.getLayerFromName used_layer_name
                if managed_layer != undefined then
                (
                    local remaining_nodes = #()
                    if managed_layer.nodes &remaining_nodes then
                    (
                        if remaining_nodes.count == 0 then
                        (
                            if managed_layer.current then
                            (
                                local default_layer = LayerManager.getLayer 0
                                if default_layer != undefined then default_layer.current = true
                            )
                            if not (LayerManager.deleteLayerByName used_layer_name) then
                            (
                                format "BM LAYER INFO | Empty layer not deleted (possibly contains child layers): %\n" used_layer_name
                            )
                        )
                    )
                    else
                    (
                        format "BM LAYER ERROR | Could not read nodes from layer: %\n" used_layer_name
                    )
                )
            )
            redrawViews()
            deleted_count
            -- return
        ),


        /*
        Toggles one managed plane, returning true only when a plane exists.
        */
        function toggleOne role_name =
        (
            local target_node = getBlueprintNode role_name
            if target_node == undefined then return false
            target_node.isNodeHidden = not target_node.isNodeHidden
            syncBlueprintLayerVisibility()
            redrawViews()
            true
            -- return
        ),


        /*
        Shows all planes if any is hidden; otherwise hides all managed planes.
        */
        function toggleAll =
        (
            local found_nodes = #()
            local any_hidden = false
            for role_name in role_names do
            (
                local target_node = getBlueprintNode role_name
                if target_node != undefined then
                (
                    append found_nodes target_node
                    if target_node.isNodeHidden then any_hidden = true
                )
            )
            for target_node in found_nodes do
            (
                target_node.isNodeHidden = not any_hidden
            )
            if found_nodes.count > 0 then
            (
                syncBlueprintLayerVisibility()
                redrawViews()
            )
            found_nodes.count
            -- return
        ),


        /*
        Updates opacity on each existing managed Standard material.
        */
        function setOpacity opacity_value =
        (
            local updated_count = 0
            for role_name in role_names do
            (
                local target_node = getBlueprintNode role_name
                if target_node != undefined and target_node.material != undefined then
                (
                    if isKindOf target_node.material StandardMaterial then
                    (
                        target_node.material.opacity = opacity_value
                        updated_count += 1
                    )
                )
            )
            if updated_count > 0 then redrawViews()
            updated_count
            -- return
        ),


        /*
        Sets the frozen state of all managed planes from a checked UI toggle.
        Keeps the blueprint image colors while frozen.
        */
        function setFreezeState freeze_enabled =
        (
            local updated_count = 0
            for role_name in role_names do
            (
                local target_node = getBlueprintNode role_name
                if target_node != undefined then
                (
                    target_node.isFrozen = freeze_enabled
                    target_node.showFrozenInGray = false
                    updated_count += 1
                )
            )
            if updated_count > 0 then redrawViews()
            updated_count
            -- return
        ),


        /*
        Sets viewport back-face culling and material two-sided display together.
        Checked TWO-SIDED means back faces remain visible.
        */
        function setTwoSidedState two_sided_enabled =
        (
            local updated_count = 0
            for role_name in role_names do
            (
                local target_node = getBlueprintNode role_name
                if target_node != undefined then
                (
                    target_node.backFaceCull = not two_sided_enabled
                    if target_node.material != undefined and isKindOf target_node.material StandardMaterial then
                    (
                        target_node.material.twoSided = two_sided_enabled
                    )
                    updated_count += 1
                )
            )
            if updated_count > 0 then redrawViews()
            updated_count
            -- return
        ),


        on create do
        (
        )
    )


    global BlueprintManager
    BlueprintManager = BlueprintManager_v()
