/* Material-Library-Manager backend. File version 0.02; project version 0.02.
Autodesk source verified: USD 0.16.2 MaterialX material calls MtlXIOUtil.importMtlx path.
*/
global mlm_project_version
if mlm_project_version == undefined or mlm_project_version < 0.02 then
(
    mlm_project_version = 0.02
)
struct MlmEntry_v
(
    source_file = "", root_path = "", category = "", display_name = "",
    preview_file = "", imported_materials = #(), material_keys = #(), import_state = "Not imported",
    on create do
    (
    )
)
struct MaterialLibraryManager_v
(
    file_version = 0.02, project_version = 0.02, log_path = "",
    /* Prints source-specific diagnostics and optionally appends to the project log.
    */
    function logMessage message_text =
    (
        format "MLM | %\n" message_text
        if log_path != "" then
        (
            try
            (
                (dotNetClass "System.IO.Directory").CreateDirectory (getFilenamePath log_path)
                (dotNetClass "System.IO.File").AppendAllText log_path (message_text + "\r\n")
            )
            catch
            (
                local exception_text = getCurrentException()
                format "MLM | Log write failed: % | %\n" log_path exception_text
            )
        )
        true
        -- return
    ),
    /* Finds only this tool's preview nodes for the exact selected library root.
    */
    function managedNodes root_path =
    (
        local normalized_root = toLower ((trimRight ((dotNetClass "System.IO.Path").GetFullPath root_path) "\\/") + "\\")
        for scene_node in objects where (getUserProp scene_node "MLM_Owner") == "Material-Library-Manager" and (getUserProp scene_node "MLM_Root") == normalized_root collect scene_node
        -- return
    ),
    /* Discovers MaterialX documents and derives category ancestry from their material folders.
    */
    function scanLibrary root_path =
    (
        local io_path = dotNetClass "System.IO.Path"
        local io_dir = dotNetClass "System.IO.Directory"
        local full_root = (trimRight (io_path.GetFullPath root_path) "\\/") + "\\"
        if not io_dir.Exists full_root then
        (
            throw ("Library root does not exist: " + full_root)
        )
        local source_files = #()
        local pending_dirs = #(full_root)
        local folder_index = 1
        while folder_index <= pending_dirs.count do
        (
            local current_dir = pending_dirs[folder_index]
            join source_files (getFiles (current_dir + "*.mtlx"))
            local sub_dirs = getDirectories (current_dir + "*")
            for sub_dir in sub_dirs do
            (
                local attr_value = (dotNetClass "System.IO.File").GetAttributes sub_dir
                local reparse_flag = (dotNetClass "System.IO.FileAttributes").ReparsePoint
                if not (attr_value.HasFlag reparse_flag) then append pending_dirs sub_dir
            )
            folder_index += 1
        )
        sort source_files
        local result_entries = for source_file in source_files collect
        (
            local full_source = io_path.GetFullPath source_file
            local material_dir = trimRight (getFilenamePath full_source) "\\/"
            local relative_dir = if material_dir.count < full_root.count then "" else substring material_dir (full_root.count + 1) (material_dir.count - full_root.count)
            local folder_parts = filterString relative_dir "\\/"
            local category_name = ""
            if folder_parts.count > 1 then
            (
                for part_index = 1 to (folder_parts.count - 1) do
                (
                    if category_name != "" then category_name += "/"
                    category_name += folder_parts[part_index]
                )
            )
            local material_name = if folder_parts.count == 0 then getFilenameFile full_source else folder_parts[folder_parts.count]
            local sibling_files = getFiles ((getFilenamePath full_source) + "*.mtlx")
            if sibling_files.count > 1 then material_name += (" - " + getFilenameFile full_source)
            local image_files = #()
            local image_patterns = #()
            for base_name in #((getFilenameFile full_source), material_name) do
            (
                for extension_value in #(".png", ".jpg", ".jpeg", ".webp") do append image_patterns (base_name + extension_value)
            )
            join image_patterns #("*preview*.png", "*preview*.jpg", "*preview*.jpeg", "*thumbnail*.png", "*thumbnail*.jpg", "*render*.png", "*render*.jpg")
            for image_pattern in image_patterns while image_files.count == 0 do
            (
                image_files = getFiles ((getFilenamePath full_source) + image_pattern)
            )
            sort image_files
            MlmEntry_v source_file:full_source root_path:full_root category:category_name display_name:material_name preview_file:(if image_files.count > 0 then image_files[1] else "")
        )
        local existing_nodes = managedNodes full_root
        for entry_value in result_entries do
        (
            local document_nodes = for managed_node in existing_nodes where (getUserProp managed_node "MLM_Source") == toLower entry_value.source_file collect managed_node
            if document_nodes.count > 0 then
            (
                local expected_count = getUserProp document_nodes[1] "MLM_Count"
                local complete_state = expected_count == document_nodes.count
                local seen_keys = #()
                for managed_node in document_nodes do
                (
                    local material_key = getUserProp managed_node "MLM_Key"
                    if material_key == undefined or (findItem seen_keys material_key) != 0 then complete_state = false
                    append seen_keys material_key
                    if (getUserProp managed_node "MLM_Count") != expected_count or managed_node.material == undefined or (getUserProp managed_node "MLM_Complete") != true then complete_state = false
                )
                if complete_state then
                (
                    entry_value.imported_materials = for managed_node in document_nodes collect managed_node.material
                    entry_value.material_keys = for managed_node in document_nodes collect getUserProp managed_node "MLM_Key"
                    entry_value.import_state = "Imported"
                )
            )
        )
        result_entries
        -- return
    ),
    /* Detects the general Autodesk importer without invoking an Arnold fallback.
    */
    function importerAvailable =
    (
        globalVars.isGlobal #MtlXIOUtil and (globalVars.get #MtlXIOUtil) != undefined
        -- return
    ),
    /* Validates XML and local filename inputs, imports all materials, or raises a source-specific failure.
    */
    function importDocument source_file =
    (
        if not importerAvailable() then throw "Autodesk MaterialX importer is unavailable. Install/enable USD for 3ds Max with MaterialX."
        local xml_settings = dotNetObject "System.Xml.XmlReaderSettings"
        xml_settings.DtdProcessing = (dotNetClass "System.Xml.DtdProcessing").Prohibit
        xml_settings.XmlResolver = undefined
        local xml_reader = (dotNetClass "System.Xml.XmlReader").Create source_file xml_settings
        local xml_doc = dotNetObject "System.Xml.XmlDocument"
        try (xml_doc.Load xml_reader) catch
        (
            local exception_text = getCurrentException()
            xml_reader.Close()
            logMessage (source_file + " | " + exception_text)
            throw()
        )
        xml_reader.Close()
        for input_element in (xml_doc.SelectNodes "//*[@type='filename' and @value]") do
        (
            local texture_value = input_element.GetAttribute "value"
            local path_prefix = ""
            local parent_element = input_element
            while parent_element != undefined do
            (
                if parent_element.NodeType == (dotNetClass "System.Xml.XmlNodeType").Element then
                (
                    path_prefix = (parent_element.GetAttribute "fileprefix") + path_prefix
                )
                parent_element = parent_element.ParentNode
            )
            if texture_value != "" then
            (
                local texture_path = path_prefix + texture_value
                if not (dotNetClass "System.IO.Path").IsPathRooted texture_path then texture_path = (getFilenamePath source_file) + texture_path
                if findString texture_path "<UDIM>" != undefined then
                (
                    local tiled_pattern = substituteString texture_path "<UDIM>" "????"
                    if (getFiles tiled_pattern).count == 0 then throw (source_file + " | Missing texture tiles: " + texture_path)
                )
                else if not doesFileExist texture_path then throw (source_file + " | Missing texture: " + texture_path)
            )
        )
        local imported_values = MtlXIOUtil.importMtlx source_file
        if imported_values == undefined or imported_values.count == 0 then throw (source_file + " | Autodesk importer returned no convertible materials.")
        for material_value in imported_values do
        (
            if not isKindOf material_value Material then throw (source_file + " | Importer returned a non-material value.")
        )
        local expected_count = (xml_doc.SelectNodes "/materialx/surfacematerial").Count
        if expected_count > 0 and imported_values.count != expected_count then
        (
            throw (source_file + " | Partial import. Expected: " + (expected_count as string) + "; actual: " + (imported_values.count as string))
        )
        imported_values as array
        -- return
    ),
    /* Updates the same source/material node or creates one geometry instance, retaining per-node materials.
    */
    function upsertPreview entry_value material_key material_value template_node =
    (
        local matching_nodes = for managed_node in (managedNodes entry_value.root_path) where (getUserProp managed_node "MLM_Source") == (toLower entry_value.source_file) and (getUserProp managed_node "MLM_Key") == material_key collect managed_node
        if matching_nodes.count > 1 then throw ("Duplicate managed identity: " + entry_value.source_file + " | " + material_key)
        local preview_node = if matching_nodes.count == 1 then matching_nodes[1] else instance template_node
        preview_node.name = uniqueName ("MLM - " + entry_value.category + " - " + material_value.name)
        preview_node.material = material_value
        setUserProp preview_node "MLM_Owner" "Material-Library-Manager"
        setUserProp preview_node "MLM_Root" (toLower entry_value.root_path)
        setUserProp preview_node "MLM_Source" (toLower entry_value.source_file)
        setUserProp preview_node "MLM_Key" material_key
        setUserProp preview_node "MLM_Category" entry_value.category
        preview_node
        -- return
    ),
    /* Creates a temporary primitive template or uses an unmodified custom scene node.
    */
    function createTemplate preview_type preview_size custom_node:undefined =
    (
        if preview_type == 4 then
        (
            if not isValidNode custom_node or superClassOf custom_node != GeometryClass then throw "Custom preview requires a picked geometry node."
            if (getUserProp custom_node "MLM_Owner") == "Material-Library-Manager" then throw "Pick an unmanaged custom source object so preview actions cannot replace or delete the source."
            custom_node
        )
        else
        (
            case preview_type of
            (
                1: sphere radius:(preview_size / 2) segs:32 mapCoords:true
                2: teapot radius:(preview_size / 2) segs:8 mapCoords:true
                3: torus_knot radius:(preview_size / 2) radius2:(preview_size / 10) Gen_UV:1
                5: box length:preview_size width:preview_size height:preview_size mapCoords:true
                default: throw "Invalid preview type."
            )
        )
        -- return
    ),
    /* Imports chosen documents with per-document errors and updates managed previews in one undo step.
    */
    function importEntries entry_values preview_type preview_size preview_spacing column_count custom_node:undefined progress_callback:undefined =
    (
        if not importerAvailable() then throw "Autodesk MaterialX importer is unavailable. Install/enable USD for 3ds Max with MaterialX."
        local template_node = undefined
        local succeeded_count = 0
        local failed_count = 0
        local grid_index = 0
        undo "MLM - import materials and previews" on
        (
            template_node = createTemplate preview_type preview_size custom_node:custom_node
            local document_index = 0
            for entry_value in entry_values do
            (
                try
                (
                    local prior_nodes = for managed_node in (managedNodes entry_value.root_path) where (getUserProp managed_node "MLM_Source") == toLower entry_value.source_file collect managed_node
                    for managed_node in prior_nodes do setUserProp managed_node "MLM_Complete" false
                    local imported_values = importDocument entry_value.source_file
                    local key_values = #()
                    for material_index = 1 to imported_values.count do
                    (
                        local material_value = imported_values[material_index]
                        local original_name = material_value.name
                        local duplicate_rank = 1
                        for previous_index = 1 to (material_index - 1) do
                        (
                            if imported_values[previous_index].name == original_name then duplicate_rank += 1
                        )
                        local material_key = original_name + "|" + (duplicate_rank as string)
                        append key_values material_key
                    )
                    for material_index = 1 to imported_values.count do
                    (
                        local material_value = imported_values[material_index]
                        material_value.name = (if entry_value.category != "" then entry_value.category + " / " else "") + entry_value.display_name + (if imported_values.count > 1 then (" - " + key_values[material_index]) else "")
                        local existing_values = for managed_node in (managedNodes entry_value.root_path) where (getUserProp managed_node "MLM_Source") == toLower entry_value.source_file and (getUserProp managed_node "MLM_Key") == key_values[material_index] collect managed_node
                        local preview_node = upsertPreview entry_value key_values[material_index] material_value template_node
                        if existing_values.count == 0 then
                        (
                            preview_node.pos = [(mod grid_index column_count) * preview_spacing, -(grid_index / column_count) * preview_spacing, 0]
                        )
                        local layer_name = "MLM | " + (filenameFromPath (trimRight entry_value.root_path "\\/")) + " | " + (if entry_value.category == "" then "(Root)" else entry_value.category)
                        local category_layer = LayerManager.getLayerFromName layer_name
                        if category_layer == undefined then category_layer = LayerManager.newLayerFromName layer_name
                        category_layer.addNode preview_node
                        setUserProp preview_node "MLM_Count" imported_values.count
                        grid_index += 1
                    )
                    local stale_nodes = for managed_node in (managedNodes entry_value.root_path) where (getUserProp managed_node "MLM_Source") == toLower entry_value.source_file and (findItem key_values (getUserProp managed_node "MLM_Key")) == 0 collect managed_node
                    if stale_nodes.count > 0 then delete stale_nodes
                    local completed_nodes = for managed_node in (managedNodes entry_value.root_path) where (getUserProp managed_node "MLM_Source") == toLower entry_value.source_file collect managed_node
                    for managed_node in completed_nodes do setUserProp managed_node "MLM_Complete" true
                    entry_value.imported_materials = imported_values
                    entry_value.material_keys = key_values
                    entry_value.import_state = "Imported"
                    succeeded_count += 1
                )
                catch
                (
                    local exception_text = getCurrentException()
                    entry_value.import_state = "FAILED: " + exception_text
                    entry_value.imported_materials = #()
                    failed_count += 1
                    logMessage (entry_value.source_file + " | " + exception_text)
                )
                document_index += 1
                if progress_callback != undefined then
                (
                    try (progress_callback document_index entry_values.count entry_value.display_name) catch
                    (
                        local exception_text = getCurrentException()
                        logMessage ("Progress display failed: " + exception_text)
                        progress_callback = undefined
                    )
                )
            )
            if preview_type != 4 and isValidNode template_node then delete template_node
        )
        #(succeeded_count, failed_count)
        -- return
    ),
    /* Applies a scoped scene action to managed previews, optionally filtering source documents.
    */
    function managePreviews root_path action_name source_files:#() =
    (
        local target_nodes = for managed_node in (managedNodes root_path) where source_files.count == 0 or (findItem source_files (getUserProp managed_node "MLM_Source")) > 0 collect managed_node
        undo "MLM - manage previews" on
        (
            case action_name of
            (
                #select: select target_nodes
                #hide: hide target_nodes
                #show: unhide target_nodes
                #remove: delete target_nodes
                default: throw "Unknown preview action."
            )
        )
        target_nodes.count
        -- return
    ),
    /* Replaces only scoped managed preview geometry while preserving transforms and material references.
    */
    function replacePreviews root_path preview_type preview_size custom_node:undefined source_files:#() =
    (
        local target_nodes = for managed_node in (managedNodes root_path) where source_files.count == 0 or (findItem source_files (getUserProp managed_node "MLM_Source")) > 0 collect managed_node
        undo "MLM - replace preview geometry" on
        (
            local template_node = createTemplate preview_type preview_size custom_node:custom_node
            for preview_node in target_nodes do
            (
                local replacement_node = instance template_node
                replacement_node.transform = preview_node.transform
                replacement_node.material = preview_node.material
                preview_node.layer.addNode replacement_node
                replacement_node.name = preview_node.name
                setUserPropBuffer replacement_node (getUserPropBuffer preview_node)
                replacement_node.isHidden = preview_node.isHidden
                delete preview_node
            )
            if preview_type != 4 then delete template_node
        )
        target_nodes.count
        -- return
    ),
    /* Arranges only the current root's managed previews; no position-based identity matching is used.
    */
    function arrangePreviews root_path preview_spacing column_count =
    (
        local target_nodes = managedNodes root_path
        undo "MLM - arrange previews" on
        (
            for node_index = 1 to target_nodes.count do
            (
                local grid_index = node_index - 1
                target_nodes[node_index].pos = [(mod grid_index column_count) * preview_spacing, -(grid_index / column_count) * preview_spacing, 0]
            )
        )
        target_nodes.count
        -- return
    ),
    /* Saves complete scanned categories only, refusing overwrite unless explicitly enabled.
    */
    function saveLibraries root_path all_entries output_dir overwrite_existing:false =
    (
        (dotNetClass "System.IO.Directory").CreateDirectory output_dir
        local category_values = #()
        for entry_value in all_entries do appendIfUnique category_values entry_value.category
        local saved_paths = #()
        local skipped_count = 0
        local used_paths = #()
        for category_value in category_values do
        (
            local category_entries = for entry_value in all_entries where entry_value.category == category_value collect entry_value
            local category_ready = category_entries.count > 0
            for entry_value in category_entries do
            (
                if entry_value.import_state != "Imported" or entry_value.imported_materials.count == 0 then category_ready = false
            )
            local root_name = filenameFromPath (trimRight root_path "\\/")
            local library_name = if category_value == "" then root_name else ("Category--" + (dotNetClass "System.Uri").EscapeDataString category_value)
            local library_path = (dotNetClass "System.IO.Path").Combine output_dir (library_name + ".mat")
            if findItem used_paths (toLower library_path) != 0 then throw ("Output name collision: " + library_path)
            append used_paths (toLower library_path)
            if category_ready and (overwrite_existing or not doesFileExist library_path) then
            (
                local category_library = materialLibrary()
                for entry_value in category_entries do
                (
                    for material_value in entry_value.imported_materials do append category_library material_value
                )
                if not saveTempMaterialLibrary category_library library_path then throw ("Could not save material library: " + library_path)
                append saved_paths library_path
            )
            else
            (
                skipped_count += 1
                logMessage ("Library skipped (incomplete category or existing output): " + library_path)
            )
        )
        #(saved_paths, skipped_count)
        -- return
    ),
    /* Writes a standalone portable catalog with collapsible categories, search and optional previews.
    */
    function exportCatalog root_path all_entries output_dir:undefined overwrite_existing:false =
    (
        if output_dir == undefined then output_dir = root_path
        (dotNetClass "System.IO.Directory").CreateDirectory output_dir
        local catalog_path = (dotNetClass "System.IO.Path").Combine output_dir "Material-Library-Catalog.html"
        if doesFileExist catalog_path and not overwrite_existing then throw ("Catalog exists; enable overwrite to replace it: " + catalog_path)
        local output_uri = dotNetObject "System.Uri" ((trimRight ((dotNetClass "System.IO.Path").GetFullPath output_dir) "\\/") + "\\")
        local html_stream = stringStream ""
        format "%" "<!doctype html><html lang='en'><meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'><title>Material Library</title><style>body{background:#101722;color:#dce4ef;font:16px system-ui;margin:20px}input{padding:12px;width:90%;background:#202c3c;color:inherit;border:1px solid #52647e}summary{cursor:pointer;padding:18px;font-size:20px}.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(180px,1fr));gap:16px}article{background:#1b2636;padding:12px;border-radius:8px;overflow-wrap:anywhere}img,.missing{width:100%;aspect-ratio:1;object-fit:contain;background:#111925}.missing{display:grid;place-items:center;color:#8a9bb1}a{color:#64afff}details{margin:12px 0}small{color:#a3b2c7}</style><h1>Material Library</h1><input id='search' placeholder='Search materials' aria-label='Search materials'>\n" to:html_stream
        local category_values = #()
        for entry_value in all_entries do appendIfUnique category_values entry_value.category
        sort category_values
        for category_value in category_values do
        (
            local category_label = if category_value == "" then filenameFromPath (trimRight root_path "\\/") else category_value
            format "<details open><summary>%</summary><div class='grid'>\n" ((dotNetClass "System.Security.SecurityElement").Escape category_label) to:html_stream
            for entry_value in all_entries where entry_value.category == category_value do
            (
                local safe_name = (dotNetClass "System.Security.SecurityElement").Escape entry_value.display_name
                local source_uri = dotNetObject "System.Uri" entry_value.source_file
                local relative_source = (output_uri.MakeRelativeUri source_uri).ToString()
                format "<article><h3>%</h3>" safe_name to:html_stream
                if entry_value.preview_file != "" then
                (
                    local preview_uri = dotNetObject "System.Uri" entry_value.preview_file
                    local relative_preview = (output_uri.MakeRelativeUri preview_uri).ToString()
                    format "<img loading='lazy' src='%' alt='%'>" ((dotNetClass "System.Security.SecurityElement").Escape relative_preview) safe_name to:html_stream
                )
                else format "<div class='missing'>No preview</div>" to:html_stream
                format "<p><a href='%'>MaterialX</a></p><small>%</small></article>\n" ((dotNetClass "System.Security.SecurityElement").Escape relative_source) ((dotNetClass "System.Security.SecurityElement").Escape entry_value.import_state) to:html_stream
            )
            format "</div></details>\n" to:html_stream
        )
        format "<script>document.getElementById('search').addEventListener('input',function(){const q=this.value.toLowerCase();document.querySelectorAll('article').forEach(function(a){a.hidden=!a.textContent.toLowerCase().includes(q)});document.querySelectorAll('details').forEach(function(d){d.hidden=!Array.from(d.querySelectorAll('article')).some(function(a){return !a.hidden});if(q)d.open=true})});</script></html>" to:html_stream
        (dotNetClass "System.IO.File").WriteAllText catalog_path (html_stream as string) (dotNetObject "System.Text.UTF8Encoding" false)
        close html_stream
        catalog_path
        -- return
    ),
    on create do
    (
    )
)
global MaterialLibraryManager
MaterialLibraryManager = MaterialLibraryManager_v()

