/*
Render Studio executable test workflow.
File version: 0.13
Project version: 0.13


Run from the Tests folder. The test leaves its final scene state for inspection.
Undo order is printed at the end.
*/




global render_studio_test_project_version = 0.13
global render_studio_test_source_path = getSourceFileName()
global render_studio_test_dir = if render_studio_test_source_path != undefined and render_studio_test_source_path != "" then getFilenamePath render_studio_test_source_path else ""
global render_studio_test_tool_dir = render_studio_test_dir + "..\\"
global render_studio_test_hdri_path = undefined




if render_studio_test_dir == "" then
(
    throw "Render Studio Test: run the test from its saved Tests folder."
)




fileIn (render_studio_test_tool_dir + "Render Studio-FN.ms")




/*
PART 1: Creates one isolated source object for the test.
*/
function partOfTest1 =
(
    undo "RS TEST 1 | Create source" on
    (
        local old_test_node = getNodeByName "RS_TEST_Source"




        if old_test_node != undefined and isValidNode old_test_node then delete old_test_node




        local test_node = box name:"RS_TEST_Source" width:100.0 length:100.0 height:160.0 pos:[0,0,80]
        select test_node
    )




    true
    -- return
)




/*
PART 2: Resolves one HDRI beside the current .max file when available and builds Dome Light mode.
*/
function partOfTest2 =
(
    local hdri_dir = maxFilePath + "HDRIs\\"
    local hdri_files = RenderStudio.getHdriFiles hdri_dir
    local test_ok = true




    render_studio_test_hdri_path = if hdri_files.count > 0 then hdri_files[1] else undefined




    undo "RS TEST 2 | Dome mode" on
    (
        local setup_result = RenderStudio.setupStudio \
            #((getNodeByName "RS_TEST_Source")) \
            hdri_path:render_studio_test_hdri_path \
            hdri_mode:#dome \
            create_camera:true




        local sky_node = getNodeByName "STUDIO_Sky"




        test_ok = setup_result.passed and sky_node != undefined and sky_node.shapeType == 6




        if render_studio_test_hdri_path != undefined then
        (
            local slot_map = meditMaterials[1]
            test_ok = test_ok and sky_node.useTexmap and sky_node.texmap != undefined
            test_ok = test_ok and slot_map == sky_node.texmap
            test_ok = test_ok and slot_map.name == "STUDIO_HDRI"
            test_ok = test_ok and slot_map.filename == render_studio_test_hdri_path




            if hdri_files.count > 1 then
            (
                local second_hdri_path = hdri_files[2]
                local same_map = slot_map
                local update_ok = false




                slot_map.filename = second_hdri_path
                test_ok = test_ok and sky_node.texmap.filename == second_hdri_path




                update_ok = RenderStudio.updateHdriAssignment second_hdri_path 0.35
                test_ok = test_ok and update_ok
                test_ok = test_ok and meditMaterials[1] == same_map
                test_ok = test_ok and sky_node.texmap == same_map
                test_ok = test_ok and sky_node.texmap.filename == second_hdri_path
                render_studio_test_hdri_path = second_hdri_path
            )
        )
    )




    format "PART 2 | DOME MODE | PASS:% HDRI:%\n" test_ok render_studio_test_hdri_path
    test_ok
    -- return
)




/*
PART 3: Builds Environment mode when an HDRI is available and verifies the owned Environment bitmap.
*/
function partOfTest3 =
(
    local test_ok = true




    if render_studio_test_hdri_path == undefined then
    (
        format "PART 3 | ENVIRONMENT MODE | SKIP: no HDRI found beside current .max file.\n"
    )
    else
    (
        undo "RS TEST 3 | Environment mode" on
        (
            local setup_result = RenderStudio.setupStudio \
                (selection as array) \
                hdri_path:render_studio_test_hdri_path \
                hdri_mode:#environment \
                create_camera:true




            test_ok = setup_result.passed and environmentMap != undefined and environmentMap.name == "STUDIO_HDRI" and environmentMap == meditMaterials[1] and environmentMap.filename == render_studio_test_hdri_path
        )




        format "PART 3 | ENVIRONMENT MODE | PASS:%\n" test_ok
    )




    test_ok
    -- return
)








/*
PART 4: Verifies dialog height can change and the changed height persists across a restart.
*/
function partOfTest4 =
(
    local entry_path = render_studio_test_tool_dir + "Render Studio.ms"
    local original_pos = undefined
    local original_size = undefined
    local changed_size = undefined
    local reopened_pos = undefined
    local reopened_size = undefined
    local requested_height = 780
    local test_ok = false




    fileIn entry_path
    windows.processPostedMessages()
    original_pos = getDialogPos render_studio_rollout
    original_size = getDialogSize render_studio_rollout




    setDialogSize render_studio_rollout [288, requested_height]
    windows.processPostedMessages()
    changed_size = getDialogSize render_studio_rollout
    DialogHost.saveDialogState render_studio_rollout render_studio_ini_path "MainUI" min_height:744




    fileIn entry_path
    windows.processPostedMessages()
    reopened_pos = getDialogPos render_studio_rollout
    reopened_size = getDialogSize render_studio_rollout




    test_ok = \
        changed_size.x == 288 and \
        changed_size.y == requested_height and \
        reopened_pos == original_pos and \
        reopened_size == changed_size




    format "PART 4 | DIALOG HEIGHT PERSISTENCE | PASS:% original:% changed:% reopened:%\n" \
        test_ok original_size changed_size reopened_size
    test_ok
    -- return
)




/*
PART 5: Verifies the production Render button style and backend render entry without starting a render.
*/
function partOfTest5 =
(
    local color_type = dotNetClass "System.Drawing.Color"
    local expected_orange = color_type.FromArgb 255 165 0
    local test_ok = true




    if render_studio_rollout == undefined then
    (
        test_ok = false
    )
    else
    (
        test_ok = test_ok and render_studio_rollout.btn_render.Text == "RENDER"
        test_ok = test_ok and render_studio_rollout.btn_render.width == 264
        test_ok = test_ok and render_studio_rollout.btn_render.height == 32
        test_ok = test_ok and render_studio_rollout.btn_render.ForeColor.ToArgb() == expected_orange.ToArgb()
        test_ok = test_ok and render_studio_rollout.btn_viewport_hdri.text == "VIEWPORT"
        test_ok = test_ok and render_studio_rollout.btn_clone_buffer.text == "CLONE BUFFER"
        test_ok = test_ok and render_studio_rollout.sld_hdri_rotation.range.x == 0
        test_ok = test_ok and render_studio_rollout.sld_hdri_rotation.range.y == 360
        test_ok = test_ok and isProperty RenderStudio #renderCurrentFrame
        test_ok = test_ok and isProperty RenderStudio #cloneRenderBuffer
        test_ok = test_ok and isProperty RenderStudio #setViewportHdriEnabled
        test_ok = test_ok and isProperty RenderStudio #setDomeHdriRotation
        test_ok = test_ok and isProperty RenderStudio #getDomeHdriRotation
    )




    format "PART 5 | RENDER BUTTON | PASS:%\n" test_ok
    test_ok
    -- return
)




/*
PART 6: Verifies viewport HDRI preview uses Material Editor slot 1 and can be removed.
*/
function partOfTest6 =
(
    local test_ok = true
    local preview_on = undefined
    local preview_off = undefined


    if meditMaterials[1] == undefined or classOf meditMaterials[1] != BitmapTexture then
    (
        format "PART 6 | VIEWPORT HDRI | SKIP: no STUDIO_HDRI in slot 1.\n"
    )
    else
    (
        preview_on = RenderStudio.setViewportHdriEnabled true
        test_ok = preview_on.passed and RenderStudio.isViewportHdriEnabled()
        test_ok = test_ok and environmentMap == meditMaterials[1]


        preview_off = RenderStudio.setViewportHdriEnabled false
        test_ok = test_ok and preview_off.passed and not RenderStudio.isViewportHdriEnabled()


        format "PART 6 | VIEWPORT HDRI | PASS:%\n" test_ok
    )


    test_ok
    -- return
)


/*
PART 7: Verifies per-HDRI dome rotation is stored on STUDIO_Sky and restored per HDRI.
*/
function partOfTest7 =
(
    local test_ok = true
    local sky_node = getNodeByName "STUDIO_Sky"
    local hdri_path = render_studio_test_hdri_path
    local rotation_result = undefined
    local stored_data = undefined


    if sky_node == undefined or not isValidNode sky_node or hdri_path == undefined then
    (
        format "PART 7 | DOME ROTATION | SKIP: dome or HDRI unavailable.\n"
    )
    else
    (
        rotation_result = RenderStudio.setDomeHdriRotation hdri_path 137
        stored_data = getUserPropVal sky_node "RS_HDRI_ROTATIONS"


        test_ok = rotation_result.passed
        test_ok = test_ok and RenderStudio.getDomeHdriRotation hdri_path == 137
        test_ok = test_ok and classOf stored_data == Array
        test_ok = test_ok and ((sky_node.rotation as eulerAngles).z as integer) == 137


        format "PART 7 | DOME ROTATION | PASS:%\n" test_ok
    )


    test_ok
    -- return
)


partOfTest1()
partOfTest2()
partOfTest7()
partOfTest3()
partOfTest4()
partOfTest5()
partOfTest6()




format "RENDER STUDIO TEST COMPLETE.\n"
format "UNDO ORDER:\n"
format "1. RS TEST 3 | Environment mode\n"
format "2. RS TEST 2 | Dome mode\n"
format "3. RS TEST 1 | Create source\n"
format "Dialog persistence, Render/Clone buttons, Viewport HDRI, and Dome Rotation tests do not add undo steps.\n"