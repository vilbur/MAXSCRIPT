/* Material-Library-Manager staged test workflow. File version 0.02; project version 0.02.
Run in a disposable scene. Objects and temporary fixtures remain for inspection.
*/
global mlm_project_version
if mlm_project_version == undefined or mlm_project_version < 0.02 then
(
    mlm_project_version = 0.02
)
global mlm_test_file_version = 0.02
global mlm_test_project_version = 0.02
global mlm_entry_test_mode
global mlm_test_root
global mlm_test_entries
global mlm_test_other
global mlm_test_nodes
global mlm_test_source
/* Reports an exact assertion failure with its test name.
*/
function assertMlm condition_value test_name =
(
    if not condition_value then
    (
        throw ("MLM TEST FAILED: " + test_name)
    )
    true
    -- return
)
/* Verifies stale dependency settings recover to the canonical AGENTS UI framework.
*/
function partOfTest0 =
(
    local test_source_dir = getFilenamePath (getSourceFileName())
    local entry_file = pathConfig.appendPath test_source_dir @"..\Material-Library-Manager.ms"
    local ui_file = pathConfig.appendPath test_source_dir @"..\Material-Library-Manager-UI.ms"
    mlm_entry_test_mode = true
    fileIn entry_file
    mlm_entry_test_mode = false
    fileIn ui_file

    local resolver_root = (getDir #temp) + "\\MLM-Resolver-Test-" + (((dotNetClass "System.Guid").NewGuid()).ToString()) + "\\"
    local resolver_tool_dir = resolver_root + "CODE\\MAXSCRIPT\\CODEBASE\\Tools\\MATERIALS\\Material-Library-Manager\\"
    local expected_ui_dir = resolver_root + "AI\\AGENTS\\Maxscript\\UI\\Default\\"
    local stale_ui_dir = resolver_root + "LIBRARIES\\MATERIALS\\MaterialX\\"
    local resolver_config = resolver_tool_dir + "Material-Library-Manager.ini"
    makeDir resolver_tool_dir all:true
    makeDir expected_ui_dir all:true
    for helper_name in #("IniSettings.ms", "RolloutState.ms", "DialogHost.ms", "ScriptReload.ms", "ToolTitleButton.ms") do
    (
        (dotNetClass "System.IO.File").WriteAllText (expected_ui_dir + helper_name) ""
    )
    setINISetting resolver_config "Dependencies" "UiFrameworkDir" stale_ui_dir

    local resolved_ui_dir = resolveMlmUiFrameworkDir resolver_tool_dir resolver_config prompt_for_path:false
    local io_path = dotNetClass "System.IO.Path"
    assertMlm ((toLower (io_path.GetFullPath resolved_ui_dir)) == (toLower (io_path.GetFullPath expected_ui_dir))) "stale UI path recovers to canonical AGENTS framework"
    assertMlm ((toLower (io_path.GetFullPath (getINISetting resolver_config "Dependencies" "UiFrameworkDir"))) == (toLower (io_path.GetFullPath expected_ui_dir))) "recovered UI path is persisted"
    true
    -- return
)
/* Loads backend without opening UI and creates isolated filesystem fixtures.
*/
function partOfTest1 =
(
    fileIn ((getFilenamePath (getSourceFileName())) + "..\\Material-Library-Manager-FN.ms")
    mlm_test_root = (getDir #temp) + "\\MLM-Test-" + (((dotNetClass "System.Guid").NewGuid()).ToString()) + "\\"
    makeDir (mlm_test_root + "Metal\\Same") all:true
    makeDir (mlm_test_root + "Plastic\\Same") all:true
    makeDir (mlm_test_root + "Loose") all:true
    local fixture_text = "<?xml version=\"1.0\"?><materialx version=\"1.38\"><standard_surface name=\"surface1\" type=\"surfaceshader\"><input name=\"base_color\" type=\"color3\" value=\"0.8,0.2,0.1\"/></standard_surface><surfacematerial name=\"mat1\" type=\"material\"><input name=\"surfaceshader\" type=\"surfaceshader\" nodename=\"surface1\"/></surfacematerial><surfacematerial name=\"mat2\" type=\"material\"><input name=\"surfaceshader\" type=\"surfaceshader\" nodename=\"surface1\"/></surfacematerial></materialx>"
    for relative_file in #("root.mtlx", "Loose\\one.mtlx", "Metal\\Same\\two.mtlx", "Plastic\\Same\\two.mtlx") do
    (
        (dotNetClass "System.IO.File").WriteAllText (mlm_test_root + relative_file) fixture_text
    )
    mlm_test_entries = MaterialLibraryManager.scanLibrary mlm_test_root
    assertMlm (mlm_test_entries.count == 4) "discovery: four documents"
    assertMlm ((for entry_value in mlm_test_entries where entry_value.category == "Metal" collect entry_value).count == 1) "category ancestry"
    assertMlm ((for entry_value in mlm_test_entries where entry_value.category == "" collect entry_value).count == 2) "optional categories"
    format "MLM discovery fixtures: %\n" mlm_test_root
    true
    -- return
)
/* Creates independent materials on shared geometry and proves repeat identity and scope.
*/
function partOfTest2 =
(
    undo "MLM TEST 1 - managed instances" on
    (
        mlm_test_other = box name:(uniqueName "MLM-Unrelated")
        mlm_test_source = sphere radius:10 name:(uniqueName "MLM-CustomSource")
        local first_material = standardMaterial name:"Test A"
        local second_material = standardMaterial name:"Test B"
        local first_node = MaterialLibraryManager.upsertPreview mlm_test_entries[1] "a" first_material mlm_test_source
        local second_node = MaterialLibraryManager.upsertPreview mlm_test_entries[1] "b" second_material mlm_test_source
        mlm_test_nodes = #(first_node, second_node)
        assertMlm (first_node.baseObject == second_node.baseObject) "geometry instances"
        assertMlm (first_node.material != second_node.material) "independent materials"
        assertMlm (mlm_test_source.material == undefined) "custom source unchanged"
        local repeated_node = MaterialLibraryManager.upsertPreview mlm_test_entries[1] "a" first_material mlm_test_source
        assertMlm (repeated_node == first_node) "repeat import updates original"
        assertMlm ((MaterialLibraryManager.managedNodes mlm_test_root).count == 2) "no duplicate previews"
    )
    true
    -- return
)
/* Exports portable HTML and MAT, then roundtrips the material library.
*/
function partOfTest3 =
(
    local catalog_path = MaterialLibraryManager.exportCatalog mlm_test_root mlm_test_entries overwrite_existing:true
    assertMlm (doesFileExist catalog_path) "HTML output exists"
    local html_text = (dotNetClass "System.IO.File").ReadAllText catalog_path
    assertMlm (findString html_text "Metal/Same/two.mtlx" != undefined) "relative source links"
    local test_library = materialLibrary()
    append test_library mlm_test_nodes[1].material
    append test_library mlm_test_nodes[2].material
    local library_path = mlm_test_root + "roundtrip.mat"
    assertMlm (saveTempMaterialLibrary test_library library_path) "save library"
    local loaded_library = loadTempMaterialLibrary library_path
    assertMlm (loaded_library.count == 2) "library roundtrip count"
    true
    -- return
)
/* Optionally exercises the real Autodesk importer, keeping failures visible.
*/
function partOfTest4 =
(
    if MaterialLibraryManager.importerAvailable() then
    (
        local imported_materials = MaterialLibraryManager.importDocument mlm_test_entries[1].source_file
        assertMlm (imported_materials.count == 2) "general importer retains both materials"
        local import_result = MaterialLibraryManager.importEntries #(mlm_test_entries[1]) 1 20 40 4
        assertMlm (import_result[1] == 1 and import_result[2] == 0) "real import batch"
        local preview_count = (MaterialLibraryManager.managedNodes mlm_test_root).count
        local repeat_result = MaterialLibraryManager.importEntries #(mlm_test_entries[1]) 1 20 40 4
        assertMlm (repeat_result[1] == 1 and (MaterialLibraryManager.managedNodes mlm_test_root).count == preview_count) "real repeat import"
        local rescanned_entries = MaterialLibraryManager.scanLibrary mlm_test_root
        assertMlm ((for entry_value in rescanned_entries where entry_value.import_state == "Imported" collect entry_value).count == 1) "scene recovery after scan"
        local incomplete_result = MaterialLibraryManager.saveLibraries mlm_test_root rescanned_entries mlm_test_root
        assertMlm (incomplete_result[2] > 0) "incomplete categories skipped"
        local missing_file = mlm_test_root + "missing-texture.mtlx"
        (dotNetClass "System.IO.File").WriteAllText missing_file "<materialx version=\"1.38\"><image name=\"test\" type=\"color3\"><input name=\"file\" type=\"filename\" value=\"absent-texture.png\"/></image></materialx>"
        local rejected_missing = false
        try (MaterialLibraryManager.importDocument missing_file) catch
        (
            local exception_text = getCurrentException()
            format "Expected missing-texture failure: %\n" exception_text
            rejected_missing = true
        )
        assertMlm rejected_missing "missing texture rejected"
        local invalid_file = mlm_test_root + "invalid.mtlx"
        (dotNetClass "System.IO.File").WriteAllText invalid_file "not XML"
        local rejected_invalid = false
        try (MaterialLibraryManager.importDocument invalid_file) catch
        (
            local exception_text = getCurrentException()
            format "Expected invalid-document failure: %\n" exception_text
            rejected_invalid = true
        )
        assertMlm rejected_invalid "invalid document rejected"
    )
    else
    (
        format "SKIPPED: real import (Autodesk MaterialX plugin unavailable).\n"
    )
    true
    -- return
)
/* Verifies managed removal never touches unrelated nodes or the custom source.
*/
function partOfTest5 =
(
    undo "MLM TEST 2 - remove managed" on
    (
        MaterialLibraryManager.managePreviews mlm_test_root #remove
        assertMlm (isValidNode mlm_test_other) "unrelated node preserved"
        assertMlm (isValidNode mlm_test_source) "custom source preserved"
        assertMlm ((MaterialLibraryManager.managedNodes mlm_test_root).count == 0) "managed nodes removed"
    )
    format "MLM test stages completed. Undo order: remove managed, managed instances. Fixtures retained: %\n" mlm_test_root
    true
    -- return
)
partOfTest0()
partOfTest1()
partOfTest2()
partOfTest3()
partOfTest4()
partOfTest5()
