/*
Render Studio backend.
File version: 0.11
Project version: 0.13
*/




global render_studio_project_version
global render_studio_fn_file_version = 0.11
global render_studio_fn_stored_project_version = 0.13
global render_studio_previous_environment_map
global render_studio_previous_environment_enabled
global render_studio_environment_override_active
global render_studio_viewport_environment_active
global render_studio_viewport_previous_environment_map
global render_studio_viewport_previous_environment_enabled
global render_studio_dome_rotation_data
global render_studio_render_buffer_clones




if render_studio_previous_environment_enabled == undefined then render_studio_previous_environment_enabled = false
if render_studio_environment_override_active == undefined then render_studio_environment_override_active = false
if render_studio_viewport_environment_active == undefined then render_studio_viewport_environment_active = false
if render_studio_viewport_previous_environment_enabled == undefined then render_studio_viewport_previous_environment_enabled = false
if render_studio_dome_rotation_data == undefined then render_studio_dome_rotation_data = #()
if render_studio_render_buffer_clones == undefined then render_studio_render_buffer_clones = #()




if render_studio_project_version == undefined or render_studio_fn_stored_project_version > render_studio_project_version then
(
    render_studio_project_version = render_studio_fn_stored_project_version
)




struct RenderStudioResult_v
(
    passed = false,
    message = ""
)




struct RenderStudio_v
(
    file_version = 0.11,
    project_version = 0.13,




    /*
    Finds the installed Arnold renderer class.
    Returns undefined when Arnold is unavailable.
    */
    function findArnoldRendererClass =
    (
        local renderer_class_match = undefined




        for renderer_class_value in RendererClass.classes while renderer_class_match == undefined do
        (
            if matchPattern (renderer_class_value as string) pattern:"*Arnold*" ignoreCase:true then
            (
                renderer_class_match = renderer_class_value
            )
        )




        renderer_class_match
        -- return
    ),




    /*
    Switches the production renderer to Arnold.
    Returns true when the Arnold renderer is available.
    */
    function setArnoldRenderer =
    (
        local arnold_renderer_class = findArnoldRendererClass()
        local renderer_set = arnold_renderer_class != undefined




        if renderer_set then
        (
            renderers.current = arnold_renderer_class()
        )




        renderer_set
        -- return
    ),




    /*
    Sets the first available property from a list of MAXtoA-compatible property names.
    */
    function setFirstExistingProperty owner_value property_names property_value =
    (
        local property_set = false




        for property_name in property_names while not property_set do
        (
            if isProperty owner_value property_name then
            (
                setProperty owner_value property_name property_value
                property_set = true
            )
        )




        property_set
        -- return
    ),




    /*
    Collects HDR and EXR files directly inside one directory.
    */
    function getHdriFiles hdri_dir =
    (
        local hdri_files = #()




        if classOf hdri_dir == String and hdri_dir != "" and doesDirectoryExist hdri_dir then
        (
            join hdri_files (getFiles (hdri_dir + "\\*.hdr"))
            join hdri_files (getFiles (hdri_dir + "\\*.exr"))
            sort hdri_files
        )




        hdri_files
        -- return
    ),




    /*
    Builds listbox display names from full HDRI paths.
    */
    function getHdriDisplayNames hdri_paths =
    (
        local hdri_names = #()




        if classOf hdri_paths == Array then
        (
            hdri_names = for hdri_path in hdri_paths collect ((getFilenameFile hdri_path) + (getFilenameType hdri_path))
        )




        hdri_names
        -- return
    ),




    /*
    Calculates world-space bounds for supplied scene nodes.
    Returns #(minimum, maximum), or undefined when no valid nodes were supplied.
    */
    function getSelectionBounds selected_nodes =
    (
        local bounds_result = undefined
        local bounds_min = undefined
        local bounds_max = undefined
        local valid_node_found = false




        if classOf selected_nodes == Array then
        (
            in coordsys world
            (
                for scene_node in selected_nodes do
                (
                    if isValidNode scene_node then
                    (
                        local node_min = scene_node.min
                        local node_max = scene_node.max




                        if not valid_node_found then
                        (
                            bounds_min = [node_min.x, node_min.y, node_min.z]
                            bounds_max = [node_max.x, node_max.y, node_max.z]
                            valid_node_found = true
                        )
                        else
                        (
                            if node_min.x < bounds_min.x then bounds_min.x = node_min.x
                            if node_min.y < bounds_min.y then bounds_min.y = node_min.y
                            if node_min.z < bounds_min.z then bounds_min.z = node_min.z
                            if node_max.x > bounds_max.x then bounds_max.x = node_max.x
                            if node_max.y > bounds_max.y then bounds_max.y = node_max.y
                            if node_max.z > bounds_max.z then bounds_max.z = node_max.z
                        )
                    )
                )
            )
        )




        if valid_node_found then
        (
            bounds_result = #(bounds_min, bounds_max)
        )




        bounds_result
        -- return
    ),




    /*
    Creates the neutral gray Physical Material for selected sculpture/product objects.
    */
    function createSculptureMaterial =
    (
        local sculpture_material = PhysicalMaterial()




        sculpture_material.name = "STUDIO_Sculpture_Grey"
        sculpture_material.material_mode = 1
        sculpture_material.base_weight = 1.0
        sculpture_material.Base_Color = color 135 135 135
        sculpture_material.Reflectivity = 1.0
        sculpture_material.roughness = 0.38
        sculpture_material.metalness = 0.0
        sculpture_material.trans_ior = 1.5




        sculpture_material
        -- return
    ),




    /*
    Creates the Physical Material for the studio floor and backdrop.
    */
    function createStudioMaterial =
    (
        local studio_material = PhysicalMaterial()




        studio_material.name = "STUDIO_Backdrop_Material"
        studio_material.material_mode = 1
        studio_material.base_weight = 1.0
        studio_material.Base_Color = color 190 190 190
        studio_material.Reflectivity = 0.45
        studio_material.roughness = 0.78
        studio_material.metalness = 0.0




        studio_material
        -- return
    ),




    /*
    Deletes one Tool-owned node and its assigned target when present.
    */
    function deleteOwnedNode node_name =
    (
        local scene_node = getNodeByName node_name
        local target_node = undefined




        if scene_node != undefined and isValidNode scene_node then
        (
            if isProperty scene_node #target then
            (
                target_node = scene_node.target
            )




            delete scene_node




            if target_node != undefined and isValidNode target_node then
            (
                delete target_node
            )
        )




        true
        -- return
    ),




    /*
    Returns the checked state of one Action Manager item when it can be resolved.
    */
    function getActionChecked table_id persistent_id =
    (
        local checked_state = undefined


        for table_index = 1 to actionMan.numActionTables while checked_state == undefined do
        (
            local action_table = actionMan.getActionTable table_index


            if action_table != undefined and action_table.id == table_id then
            (
                for item_index = 1 to action_table.numActionItems while checked_state == undefined do
                (
                    local action_item = action_table.getActionItem item_index
                    local item_id_string = action_item.id as string
                    local persistent_id_string = try (action_item.persistentActionId as string) catch ("")


                    if item_id_string == persistent_id or persistent_id_string == persistent_id then
                    (
                        checked_state = action_item.isChecked
                    )
                )
            )
        )


        checked_state
        -- return
    ),


    /*
    Enables/disables the active viewport's Use Environment Background source.
    Main UI action 619 is the Use Environment Background toggle.
    */
    function setViewportEnvironmentBackgroundEnabled enabled =
    (
        local checked_state = getActionChecked 0 "619"
        local action_ok = true


        if checked_state != undefined then
        (
            if checked_state != enabled then
            (
                action_ok = actionMan.executeAction 0 "619"
            )
        )
        else if enabled then
        (
            action_ok = actionMan.executeAction 0 "619"
        )


        viewport.DispBkgImage = enabled
        InvalidateAllBackgrounds()
        action_ok
        -- return
    ),


    /*
    Normalizes one HDRI path for stable per-map rotation lookup.
    */
    function getHdriRotationKey hdri_path =
    (
        local rotation_key = ""


        if classOf hdri_path == String and hdri_path != "" then
        (
            rotation_key = toLower (substituteString hdri_path "/" "\\")
        )


        rotation_key
        -- return
    ),


    /*
    Reads the per-HDRI dome rotation table from STUDIO_Sky user properties.
    The global copy preserves the table while the Tool rebuilds/recreates the dome.
    */
    function getDomeRotationData =
    (
        local sky_node = getNodeByName "STUDIO_Sky"
        local stored_data = undefined
        local rotation_data = render_studio_dome_rotation_data


        if sky_node != undefined and isValidNode sky_node then
        (
            stored_data = getUserPropVal sky_node "RS_HDRI_ROTATIONS"


            if classOf stored_data == Array then
            (
                rotation_data = stored_data
                render_studio_dome_rotation_data = stored_data
            )
        )


        rotation_data
        -- return
    ),


    /*
    Writes the current per-HDRI rotation table to STUDIO_Sky user properties.
    */
    function saveDomeRotationData rotation_data =
    (
        local sky_node = getNodeByName "STUDIO_Sky"
        local saved_ok = false


        if classOf rotation_data == Array then
        (
            render_studio_dome_rotation_data = rotation_data


            if sky_node != undefined and isValidNode sky_node then
            (
                setUserPropVal sky_node "RS_HDRI_ROTATIONS" rotation_data
                saved_ok = true
            )
        )


        saved_ok
        -- return
    ),


    /*
    Returns the saved 0-360 degree Z rotation for one HDRI path.
    */
    function getDomeHdriRotation hdri_path =
    (
        local rotation_key = getHdriRotationKey hdri_path
        local rotation_data = getDomeRotationData()
        local rotation_value = 0


        if rotation_key != "" then
        (
            for rotation_entry in rotation_data while rotation_value == 0 do
            (
                if classOf rotation_entry == Array and rotation_entry.count >= 2 and rotation_entry[1] == rotation_key then
                (
                    rotation_value = rotation_entry[2]
                )
            )
        )


        rotation_value
        -- return
    ),


    /*
    Applies the saved Z rotation for one HDRI without changing its stored value.
    */
    function applyDomeHdriRotation hdri_path =
    (
        local sky_node = getNodeByName "STUDIO_Sky"
        local rotation_value = getDomeHdriRotation hdri_path
        local applied_ok = false


        if sky_node != undefined and isValidNode sky_node then
        (
            sky_node.rotation = eulerAngles 0 0 rotation_value
            applied_ok = true
            redrawViews()
        )


        applied_ok
        -- return
    ),


    /*
    Saves and applies one 0-360 degree integer dome rotation for the selected HDRI.
    */
    function setDomeHdriRotation hdri_path rotation_value =
    (
        local result_value = RenderStudioResult_v passed:false message:"Dome rotation failed."
        local sky_node = getNodeByName "STUDIO_Sky"
        local rotation_key = getHdriRotationKey hdri_path
        local rotation_data = getDomeRotationData()
        local entry_index = 0
        local clamped_rotation = rotation_value


        if clamped_rotation < 0 then clamped_rotation = 0
        if clamped_rotation > 360 then clamped_rotation = 360


        if rotation_key == "" then
        (
            result_value.message = "Dome: no HDRI."
        )
        else if sky_node == undefined or not isValidNode sky_node then
        (
            result_value.message = "Dome: not created."
        )
        else
        (
            for item_index = 1 to rotation_data.count while entry_index == 0 do
            (
                local rotation_entry = rotation_data[item_index]


                if classOf rotation_entry == Array and rotation_entry.count >= 2 and rotation_entry[1] == rotation_key then
                (
                    entry_index = item_index
                )
            )


            if entry_index == 0 then
            (
                append rotation_data #(rotation_key, clamped_rotation)
            )
            else
            (
                rotation_data[entry_index][2] = clamped_rotation
            )


            saveDomeRotationData rotation_data
            sky_node.rotation = eulerAngles 0 0 clamped_rotation
            redrawViews()


            result_value.passed = true
            result_value.message = "Dome: " + (clamped_rotation as string) + " deg"
        )


        result_value
        -- return
    ),


    /*
    Captures STUDIO_Sky rotation user properties before the Tool deletes/rebuilds the dome.
    */
    function captureDomeRotationData =
    (
        local sky_node = getNodeByName "STUDIO_Sky"
        local stored_data = undefined


        if sky_node != undefined and isValidNode sky_node then
        (
            stored_data = getUserPropVal sky_node "RS_HDRI_ROTATIONS"


            if classOf stored_data == Array then
            (
                render_studio_dome_rotation_data = stored_data
            )
        )


        true
        -- return
    ),


    /*
    Returns whether the Tool-owned Arnold Skydome currently exists.
    */
    function hasDomeLight =
    (
        local sky_node = getNodeByName "STUDIO_Sky"


        sky_node != undefined and isValidNode sky_node
        -- return
    ),


    /*
    Returns whether Render Studio owns the temporary viewport HDRI preview.
    */
    function isViewportHdriEnabled =
    (
        render_studio_viewport_environment_active
        -- return
    ),


    /*
    Adds/removes Material Editor slot 1 as the viewport Environment background.
    */
    function setViewportHdriEnabled enabled =
    (
        local result_value = RenderStudioResult_v passed:false message:"Viewport HDRI failed."
        local hdri_bitmap = meditMaterials[1]
        local background_ok = true


        if enabled then
        (
            if hdri_bitmap == undefined or classOf hdri_bitmap != BitmapTexture or not matchPattern hdri_bitmap.name pattern:"STUDIO_HDRI*" then
            (
                result_value.message = "Viewport HDRI: no map."
            )
            else
            (
                if not render_studio_viewport_environment_active and not render_studio_environment_override_active then
                (
                    render_studio_viewport_previous_environment_map = environmentMap
                    render_studio_viewport_previous_environment_enabled = getUseEnvironmentMap()
                )


                environmentMap = meditMaterials[1]
                setUseEnvironmentMap true
                background_ok = setViewportEnvironmentBackgroundEnabled true


                if background_ok and environmentMap == meditMaterials[1] then
                (
                    render_studio_viewport_environment_active = true
                    result_value.passed = true
                    result_value.message = "Viewport HDRI: ON"
                )
                else
                (
                    result_value.message = "Viewport HDRI: failed."
                )
            )
        )
        else
        (
            setViewportEnvironmentBackgroundEnabled false


            if render_studio_viewport_environment_active and not render_studio_environment_override_active then
            (
                environmentMap = render_studio_viewport_previous_environment_map
                setUseEnvironmentMap render_studio_viewport_previous_environment_enabled
            )


            render_studio_viewport_environment_active = false
            render_studio_viewport_previous_environment_map = undefined
            render_studio_viewport_previous_environment_enabled = false
            result_value.passed = true
            result_value.message = "Viewport HDRI: OFF"
            InvalidateAllBackgrounds()
        )


        result_value
        -- return
    ),


    /*
    Restores the environment state captured before this Tool overrode it.
    */
    function restoreEnvironmentOverride =
    (
        if render_studio_environment_override_active then
        (
            environmentMap = render_studio_previous_environment_map
            setUseEnvironmentMap render_studio_previous_environment_enabled
            render_studio_previous_environment_map = undefined
            render_studio_previous_environment_enabled = false
            render_studio_environment_override_active = false
        )


        if render_studio_viewport_environment_active and meditMaterials[1] != undefined then
        (
            environmentMap = meditMaterials[1]
            setUseEnvironmentMap true
            InvalidateAllBackgrounds()
        )


        true
        -- return
    ),




    /*
    Removes all Tool-owned scene nodes and restores a Tool-owned Environment override.
    */
    function clearStudio =
    (
        captureDomeRotationData()
        restoreEnvironmentOverride()
        deleteOwnedNode "STUDIO_Floor"
        deleteOwnedNode "STUDIO_Backdrop"
        deleteOwnedNode "STUDIO_Key_Light"
        deleteOwnedNode "STUDIO_Fill_Light"
        deleteOwnedNode "STUDIO_Sky"
        deleteOwnedNode "STUDIO_Camera"
        deleteOwnedNode "STUDIO_Camera.Target"
        deleteOwnedNode "STUDIO_Key_Light.Target"
        deleteOwnedNode "STUDIO_Fill_Light.Target"
        true
        -- return
    ),




    /*
    Returns the Tool-owned HDRI BitmapTexture when one is already available.
    Material Editor slot 1 is the preferred persistent owner so the same map instance can be reused and inspected.
    */
    function getHdriBitmap =
    (
        local hdri_bitmap = undefined
        local material_editor_value = meditMaterials[1]
        local sky_node = getNodeByName "STUDIO_Sky"




        if material_editor_value != undefined and classOf material_editor_value == BitmapTexture and matchPattern material_editor_value.name pattern:"STUDIO_HDRI*" then
        (
            hdri_bitmap = material_editor_value
        )
        else if sky_node != undefined and isValidNode sky_node and isProperty sky_node #texmap and sky_node.texmap != undefined and classOf sky_node.texmap == BitmapTexture and matchPattern sky_node.texmap.name pattern:"STUDIO_HDRI*" then
        (
            hdri_bitmap = sky_node.texmap
        )
        else if environmentMap != undefined and classOf environmentMap == BitmapTexture and matchPattern environmentMap.name pattern:"STUDIO_HDRI*" then
        (
            hdri_bitmap = environmentMap
        )




        hdri_bitmap
        -- return
    ),




    /*
    Creates or updates the single Tool-owned HDRI BitmapTexture.
    The Material Editor slot reference becomes the canonical map returned to callers.
    */
    function updateHdriBitmap hdri_path hdri_strength =
    (
        local hdri_bitmap = undefined




        if classOf hdri_path == String and hdri_path != "" and doesFileExist hdri_path then
        (
            hdri_bitmap = getHdriBitmap()




            if hdri_bitmap == undefined then
            (
                hdri_bitmap = BitmapTexture()
            )




            hdri_bitmap.name = "STUDIO_HDRI"
            hdri_bitmap.filename = hdri_path
            hdri_bitmap.coords.mappingType = 1
            hdri_bitmap.coords.mapping = 0
            hdri_bitmap.output.RGB_Level = hdri_strength




            meditMaterials[1] = hdri_bitmap
            hdri_bitmap = meditMaterials[1]
        )




        hdri_bitmap
        -- return
    ),




    /*
    Updates the current Tool-owned HDRI map and reapplies the same instance to any existing Tool-owned dome/environment.
    */
    function updateHdriAssignment hdri_path hdri_strength =
    (
        local hdri_bitmap = updateHdriBitmap hdri_path hdri_strength
        local sky_node = getNodeByName "STUDIO_Sky"
        local assignment_updated = hdri_bitmap != undefined




        if assignment_updated then
        (
            if render_studio_environment_override_active then
            (
                environmentMap = meditMaterials[1]
                setUseEnvironmentMap true
                assignment_updated = environmentMap == meditMaterials[1]
            )
            else if sky_node != undefined and isValidNode sky_node and isProperty sky_node #texmap and isProperty sky_node #useTexmap then
            (
                sky_node.texmap = meditMaterials[1]
                sky_node.useTexmap = true
                assignment_updated = sky_node.texmap == meditMaterials[1]


                if assignment_updated then
                (
                    applyDomeHdriRotation hdri_path
                )
            )
        )




        if render_studio_viewport_environment_active and meditMaterials[1] != undefined then
        (
            environmentMap = meditMaterials[1]
            setUseEnvironmentMap true
            InvalidateAllBackgrounds()
        )


        if not assignment_updated then
        (
            format "RENDER STUDIO | HDRI instance assignment failed | path:% slot:% dome:% environment:%\n" \
                hdri_path meditMaterials[1] \
                (if sky_node != undefined and isValidNode sky_node and isProperty sky_node #texmap then sky_node.texmap else undefined) \
                environmentMap
        )


        assignment_updated
        -- return
    ),




    /*
    Creates a targeted Arnold Spot light.
    MAXtoA shapeType 2 is Spot in the current generic Arnold Light enum.
    */
    function createArnoldSpot light_name light_pos target_pos light_exposure light_color scene_scale =
    (
        local target_node = targetObject \
            name:(light_name + ".Target") \
            pos:target_pos




        local light_node = Arnold_Light \
            name:light_name \
            intensity:1.0 \
            exposure:light_exposure \
            normalize:off \
            shapeType:2 \
            targeted:on \
            pos:light_pos




        light_node.target = target_node




        setFirstExistingProperty light_node #(#color, #rgb) light_color
        setFirstExistingProperty light_node #(#coneAngle, #cone_angle, #spotAngle, #spot_angle) 50.0
        setFirstExistingProperty light_node #(#penumbraAngle, #penumbra_angle) 10.0
        setFirstExistingProperty light_node #(#radius, #lens_radius) (scene_scale * 0.12)
        setFirstExistingProperty light_node #(#samples) 3




        light_node
        -- return
    ),




    /*
    Creates an Arnold Skydome, optionally textured by the selected HDRI.
    MAXtoA shapeType 6 is Skydome in the current generic Arnold Light enum.
    */
    function createArnoldSky hdri_path:undefined hdri_strength:0.35 =
    (
        local sky_node = Arnold_Light \
            name:"STUDIO_Sky" \
            intensity:1.0 \
            exposure:-1.5 \
            normalize:off \
            shapeType:6 \
            targeted:off
        local hdri_bitmap = undefined
        local instance_ok = true




        setFirstExistingProperty sky_node #(#color, #rgb) (color 210 220 235)
        setFirstExistingProperty sky_node #(#samples) 3


        if render_studio_dome_rotation_data.count > 0 then
        (
            setUserPropVal sky_node "RS_HDRI_ROTATIONS" render_studio_dome_rotation_data
        )




        if hdri_path != undefined and hdri_path != "" then
        (
            hdri_bitmap = updateHdriBitmap hdri_path hdri_strength




            if hdri_bitmap != undefined then
            (
                if isProperty sky_node #useTexmap then sky_node.useTexmap = true
                if isProperty sky_node #texmap then sky_node.texmap = meditMaterials[1]




                instance_ok = \
                    sky_node.texmap != undefined and \
                    sky_node.texmap == meditMaterials[1]


                if instance_ok then
                (
                    applyDomeHdriRotation hdri_path
                )
            )
            else
            (
                instance_ok = false
            )
        )




        if not instance_ok then
        (
            format "RENDER STUDIO | Dome HDRI instance bind failed | path:% domeMap:% editorMap:%\n" \
                hdri_path sky_node.texmap meditMaterials[1]
            delete sky_node
            sky_node = undefined
        )




        sky_node
        -- return
    ),




    /*
    Applies one HDRI through the 3ds Max Environment Map while preserving the previous environment for later restoration.
    */
    function setHdriEnvironment hdri_path hdri_strength:0.35 =
    (
        local hdri_bitmap = updateHdriBitmap hdri_path hdri_strength
        local environment_applied = hdri_bitmap != undefined




        if environment_applied then
        (
            if not render_studio_environment_override_active then
            (
                if render_studio_viewport_environment_active then
                (
                    render_studio_previous_environment_map = render_studio_viewport_previous_environment_map
                    render_studio_previous_environment_enabled = render_studio_viewport_previous_environment_enabled
                )
                else
                (
                    render_studio_previous_environment_map = environmentMap
                    render_studio_previous_environment_enabled = getUseEnvironmentMap()
                )
            )




            environmentMap = meditMaterials[1]
            setUseEnvironmentMap true
            environment_applied = environmentMap == meditMaterials[1]




            if environment_applied then
            (
                render_studio_environment_override_active = true
            )
            else
            (
                format "RENDER STUDIO | Environment HDRI instance bind failed | path:% environmentMap:% editorMap:%\n" \
                    hdri_path environmentMap meditMaterials[1]
                restoreEnvironmentOverride()
            )
        )




        environment_applied
        -- return
    ),




    /*
    Creates a targeted Physical Camera looking toward the selected-object center region.
    */
    function createStudioCamera camera_pos camera_target =
    (
        local camera_target_node = targetObject \
            name:"STUDIO_Camera.Target" \
            pos:camera_target




        local camera_node = Physical_Camera \
            name:"STUDIO_Camera" \
            targeted:true \
            target:camera_target_node \
            pos:camera_pos




        camera_node.film_width_mm = 36.0
        camera_node.focal_length_mm = 70.0
        camera_node.f_number = 8.0
        camera_node.use_dof = false




        camera_node
        -- return
    ),




    /*
    Clones the last rendered image into a separate VFB window for visual comparison.
    */
    function cloneRenderBuffer =
    (
        local result_value = RenderStudioResult_v passed:false message:"No render buffer to clone."
        local cloned_bitmap = undefined
        local clone_caption = ""


        cloned_bitmap = try (getLastRenderedImage copy:true) catch (undefined)


        if cloned_bitmap != undefined then
        (
            append render_studio_render_buffer_clones cloned_bitmap
            clone_caption = "Render Studio Clone " + (render_studio_render_buffer_clones.count as string)
            display cloned_bitmap caption:clone_caption
            result_value.passed = true
            result_value.message = "Buffer cloned."
        )


        result_value
        -- return
    ),


    /*
    Renders the current frame with Arnold and reports whether a render result was produced.
    */
    function renderCurrentFrame =
    (
        local result_value = RenderStudioResult_v()
        local rendered_bitmap = undefined




        if not setArnoldRenderer() then
        (
            result_value.message = "Arnold renderer was not found."
        )
        else
        (
            rendered_bitmap = render()




            if rendered_bitmap != undefined then
            (
                result_value.passed = true
                result_value.message = "Render completed."
            )
            else
            (
                result_value.message = "Render cancelled or no render result was produced."
            )
        )




        if not result_value.passed then
        (
            format "RENDER STUDIO RENDER FAILED | %\n" result_value.message
        )




        result_value
        -- return
    ),




    /*
    Builds the complete Arnold studio from explicit scene nodes and UI parameters.
    Returns a stable result struct; it never reports success after a failed precondition.
    */
    function setupStudio \
        selected_nodes \
        hdri_path:undefined \
        hdri_strength:0.35 \
        hdri_mode:#dome \
        apply_material:true \
        create_camera:true =
    (
        local result_value = RenderStudioResult_v()
        local setup_allowed = classOf selected_nodes == Array and selected_nodes.count > 0
        local bounds_data = undefined




        if not setup_allowed then
        (
            result_value.message = "Select at least one sculpture or product object."
        )
        else if hdri_mode != #dome and hdri_mode != #environment then
        (
            result_value.message = "HDRI mode must be Dome Light or Environment."
        )
        else if hdri_path != undefined and hdri_path != "" and not doesFileExist hdri_path then
        (
            result_value.message = "Selected HDRI file does not exist: " + hdri_path
        )
        else if not setArnoldRenderer() then
        (
            result_value.message = "Arnold renderer was not found."
        )
        else
        (
            bounds_data = getSelectionBounds selected_nodes




            if bounds_data == undefined then
            (
                result_value.message = "No valid scene nodes were supplied."
            )
            else
            (
                undo "Create Render Studio" on
                (
                    local bounds_min = bounds_data[1]
                    local bounds_max = bounds_data[2]
                    local sculpture_size = bounds_max - bounds_min
                    local sculpture_center = (bounds_min + bounds_max) / 2.0
                    local scene_scale = sculpture_size.x




                    if sculpture_size.y > scene_scale then scene_scale = sculpture_size.y
                    if sculpture_size.z > scene_scale then scene_scale = sculpture_size.z
                    if scene_scale < 1.0 then scene_scale = 1.0
                    local sculpture_material = undefined
                    local studio_material = createStudioMaterial()
                    local studio_width = scene_scale * 4.0
                    local studio_depth = scene_scale * 4.5
                    local studio_height = scene_scale * 2.8
                    local wall_thickness = scene_scale * 0.04
                    local floor_node = undefined
                    local backdrop_node = undefined
                    local light_target = [sculpture_center.x, sculpture_center.y, bounds_min.z + (sculpture_size.z * 0.58)]
                    local key_pos = [sculpture_center.x - (scene_scale * 1.45), sculpture_center.y - (scene_scale * 1.45), bounds_min.z + (scene_scale * 1.45)]
                    local fill_pos = [sculpture_center.x + (scene_scale * 1.55), sculpture_center.y - (scene_scale * 1.10), bounds_min.z + (scene_scale * 1.10)]
                    local hdri_loaded = false




                    clearStudio()




                    if apply_material then
                    (
                        sculpture_material = createSculptureMaterial()




                        for scene_node in selected_nodes do
                        (
                            if isValidNode scene_node and isProperty scene_node #material then
                            (
                                scene_node.material = sculpture_material
                            )
                        )
                    )




                    floor_node = box \
                        name:"STUDIO_Floor" \
                        width:studio_width \
                        length:studio_depth \
                        height:wall_thickness \
                        pos:[sculpture_center.x, sculpture_center.y, bounds_min.z - wall_thickness]




                    floor_node.material = studio_material




                    backdrop_node = box \
                        name:"STUDIO_Backdrop" \
                        width:studio_width \
                        length:wall_thickness \
                        height:studio_height \
                        pos:[sculpture_center.x, sculpture_center.y + (studio_depth * 0.44), bounds_min.z - wall_thickness]




                    backdrop_node.material = studio_material




                    createArnoldSpot \
                        "STUDIO_Key_Light" \
                        key_pos \
                        light_target \
                        8.0 \
                        (color 255 242 225) \
                        scene_scale




                    createArnoldSpot \
                        "STUDIO_Fill_Light" \
                        fill_pos \
                        light_target \
                        7.0 \
                        (color 225 238 255) \
                        scene_scale




                    if hdri_path != undefined and hdri_path != "" then
                    (
                        if hdri_mode == #environment then
                        (
                            hdri_loaded = setHdriEnvironment hdri_path hdri_strength:hdri_strength
                        )
                        else
                        (
                            local sky_node = undefined




                            restoreEnvironmentOverride()
                            sky_node = createArnoldSky hdri_path:hdri_path hdri_strength:hdri_strength
                            hdri_loaded = sky_node != undefined
                        )
                    )




                    if not hdri_loaded then
                    (
                        restoreEnvironmentOverride()
                        createArnoldSky()
                    )




                    if create_camera then
                    (
                        local camera_pos = [sculpture_center.x, sculpture_center.y - (scene_scale * 3.25), bounds_min.z + (sculpture_size.z * 0.55)]
                        local camera_target = [sculpture_center.x, sculpture_center.y, bounds_min.z + (sculpture_size.z * 0.52)]
                        local camera_node = createStudioCamera camera_pos camera_target




                        viewport.setCamera camera_node
                    )




                    renderWidth = 1024
                    renderHeight = 1024
                    redrawViews()
                )




                result_value.passed = true
                result_value.message = if hdri_path == undefined or hdri_path == "" then "Render Studio created with neutral Skydome fallback." else if hdri_mode == #environment then "Render Studio created with HDRI Environment mode." else "Render Studio created with HDRI Dome Light mode."
            )
        )




        if not result_value.passed then
        (
            format "RENDER STUDIO FAILED | %\n" result_value.message
        )




        result_value
        -- return
    ),




    on create do
    (
    )
)




global RenderStudio
RenderStudio = RenderStudio_v()