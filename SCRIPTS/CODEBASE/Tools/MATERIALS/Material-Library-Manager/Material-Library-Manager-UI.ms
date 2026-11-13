/* Material-Library-Manager frontend, adapted from canonical Default-UI-Template.ms.
File version 0.02; shared project version 0.02. Loading this file does not open a dialog.
*/
global mlm_project_version
if mlm_project_version == undefined or mlm_project_version < 0.02 then
(
    mlm_project_version = 0.02
)
global mlm_ui_file_version = 0.02
global mlm_ui_project_version = 0.02
global mlm_ui_entry_file
global mlm_ui_ini_path
global mlm_ui_ini_section
global mlm_ui_tool_key
global mlm_ui_dialog_title
global openMaterialLibraryManager
/* Opens the owning UI using shared title, reload, persistence and dialog helpers.
*/
function openMaterialLibraryManager entry_file =
(
    mlm_ui_entry_file = entry_file
    mlm_ui_ini_path = (getFilenamePath entry_file) + "Material-Library-Manager.ini"
    mlm_ui_ini_section = "MainUI"
    mlm_ui_tool_key = "Material-Library-Manager"
    DialogHost.destroyToolDialogs mlm_ui_tool_key
    mlm_ui_dialog_title = "Material Library Manager - v" + (formattedPrint mlm_project_version format:".2f")
    rollout materialLibraryManagerRollout mlm_ui_dialog_title width:600 height:768
    (
        local all_entries = #()
        local visible_entries = #()
        local custom_node = undefined
        local scanned_root = ""
        local busy_state = false
        dotNetControl btn_tool_title "System.Windows.Forms.Button" pos:[12,12] width:576 height:18
        edittext edt_root "Root" pos:[12,42] width:456 height:24 text:""
        button btn_browse "Browse..." pos:[480,42] width:108 height:24 tooltip:"LMB: Choose the folder containing material folders or categories."
        edittext edt_output "Output" pos:[12,78] width:456 height:24 text:""
        button btn_output "Browse..." pos:[480,78] width:108 height:24 tooltip:"LMB: Choose where MAT libraries and HTML are written."
        button btn_scan "Scan" pos:[12,114] width:132 height:24 tooltip:"LMB: Refresh documents from disk; source files stay untouched."
        button btn_all "Select all" pos:[156,114] width:132 height:24
        button btn_none "Select none" pos:[300,114] width:132 height:24
        checkbox chk_overwrite "Overwrite outputs" pos:[444,118] checked:false tooltip:"Allow existing MAT libraries and HTML catalog to be replaced."
        dropdownlist ddl_category "Category" pos:[12,150] width:576 height:40 items:#("All categories") selection:1
        dotNetControl lst_materials "System.Windows.Forms.ListBox" pos:[12,198] width:576 height:216
        dropdownlist ddl_preview "Preview" pos:[12,426] width:240 height:40 items:#("Sphere", "Teapot", "Knot", "Custom", "Placeholder (box)") selection:1
        pickbutton btn_custom "Pick custom object" pos:[264,444] width:180 height:24 autoDisplay:true tooltip:"LMB: Pick geometry to instance; its material and transform stay unchanged."
        label lbl_placeholder "Placeholder: box (proposed default)." pos:[12,474] width:576 height:18
        spinner spn_size "Size" pos:[12,504] width:156 range:[0.000001,1e9,100] type:#worldunits fieldWidth:84
        label lbl_size_unit "scene units" pos:[180,507] width:72 height:18
        spinner spn_spacing "Spacing" pos:[264,504] width:156 range:[0.000001,1e9,150] type:#worldunits fieldWidth:84
        label lbl_spacing_unit "scene units" pos:[432,507] width:72 height:18
        spinner spn_columns "Columns" pos:[504,504] width:84 range:[1,1000,6] type:#integer fieldWidth:48
        button btn_import "Import selected" pos:[12,540] width:180 height:24 tooltip:"LMB: Import every material in the selected documents and update their previews."
        button btn_save "Save category libraries" pos:[204,540] width:192 height:24 tooltip:"LMB: Save complete imported categories from the current scan."
        button btn_catalog "Export HTML catalog" pos:[408,540] width:180 height:24 tooltip:"LMB: Export all scanned entries with relative links and available previews."
        button btn_select "Select previews" pos:[12,576] width:132 height:24
        button btn_hide "Hide" pos:[156,576] width:132 height:24
        button btn_show "Show" pos:[300,576] width:132 height:24
        button btn_remove "Remove previews" pos:[444,576] width:144 height:24 tooltip:"LMB: Remove only managed previews for selected documents."
        button btn_replace "Replace preview geometry" pos:[12,612] width:276 height:24 tooltip:"LMB: Apply the preview type to selected managed previews, preserving transforms and materials."
        button btn_rebuild "Arrange previews" pos:[300,612] width:288 height:24 tooltip:"LMB: Lay out all managed previews of this library in a grid."
        progressbar prg_batch pos:[12,648] width:576 height:12 value:0
        label lbl_status "Choose a root folder, then Scan." pos:[12,672] width:576 height:72

        /* Saves all user-facing control values beside the entry script.
        */
        function saveUiState =
        (
            RolloutState.saveEditText edt_root mlm_ui_ini_path mlm_ui_ini_section "Root"
            RolloutState.saveEditText edt_output mlm_ui_ini_path mlm_ui_ini_section "Output"
            RolloutState.saveDropdown ddl_preview mlm_ui_ini_path mlm_ui_ini_section "Preview"
            RolloutState.saveCheckbox chk_overwrite mlm_ui_ini_path mlm_ui_ini_section "Overwrite"
            RolloutState.saveSpinner spn_size mlm_ui_ini_path mlm_ui_ini_section "Size"
            RolloutState.saveSpinner spn_spacing mlm_ui_ini_path mlm_ui_ini_section "Spacing"
            RolloutState.saveSpinner spn_columns mlm_ui_ini_path mlm_ui_ini_section "Columns"
            true
            -- return
        )
        /* Restores validated frontend settings through the canonical helpers.
        */
        function loadUiState =
        (
            RolloutState.loadEditText edt_root mlm_ui_ini_path mlm_ui_ini_section "Root"
            RolloutState.loadEditText edt_output mlm_ui_ini_path mlm_ui_ini_section "Output"
            RolloutState.loadDropdown ddl_preview mlm_ui_ini_path mlm_ui_ini_section "Preview" default_value:1
            RolloutState.loadCheckbox chk_overwrite mlm_ui_ini_path mlm_ui_ini_section "Overwrite" default_value:false
            RolloutState.loadSpinner spn_size mlm_ui_ini_path mlm_ui_ini_section "Size" default_value:100.0
            RolloutState.loadSpinner spn_spacing mlm_ui_ini_path mlm_ui_ini_section "Spacing" default_value:150.0
            RolloutState.loadSpinner spn_columns mlm_ui_ini_path mlm_ui_ini_section "Columns" default_value:6
            true
            -- return
        )
        /* Displays entries in the selected category without changing import records.
        */
        function refreshList =
        (
            local category_index = ddl_category.selection
            local category_value = if category_index > 1 then ddl_category.items[category_index] else ""
            visible_entries = for entry_value in all_entries where category_index == 1 or (if entry_value.category == "" then "(Root)" else entry_value.category) == category_value collect entry_value
            lst_materials.Items.Clear()
            for entry_value in visible_entries do
            (
                lst_materials.Items.Add ((if entry_value.category == "" then "(Root)" else entry_value.category) + " | " + entry_value.display_name + " | " + entry_value.import_state)
            )
            true
            -- return
        )
        /* Returns document records selected in the list; empty selection stays empty.
        */
        function selectedEntries =
        (
            for selected_index in lst_materials.SelectedIndices collect visible_entries[selected_index + 1]
            -- return
        )
        /* Rejects stale folder/list combinations before any action.
        */
        function requireCurrentScan =
        (
            if all_entries.count == 0 or scanned_root != edt_root.text then throw "Choose a valid root and Scan before using this action."
            true
            -- return
        )
        /* Updates progress at document boundaries while actions remain locked against re-entry.
        */
        function updateProgress completed_count total_count material_name =
        (
            prg_batch.value = (100.0 * completed_count / total_count)
            lbl_status.text = (completed_count as string) + " / " + (total_count as string) + " documents: " + material_name
            if mod completed_count 10 == 0 then windows.processPostedMessages()
            true
            -- return
        )
        /* Enables user input only outside a running batch operation.
        */
        function setInputEnabled enabled_state =
        (
            for ui_control in #(btn_tool_title, edt_root, btn_browse, edt_output, btn_output, btn_scan, btn_all, btn_none, chk_overwrite, ddl_category, lst_materials, ddl_preview, spn_size, spn_spacing, spn_columns, btn_import, btn_save, btn_catalog, btn_select, btn_hide, btn_show, btn_remove, btn_replace, btn_rebuild) do ui_control.enabled = enabled_state
            btn_custom.enabled = enabled_state and ddl_preview.selection == 4
            true
            -- return
        )
        /* Runs a UI command and presents the original exception without leaving controls busy.
        */
        function runAction action_name =
        (
            if not busy_state then
            (
                busy_state = true
                setInputEnabled false
                prg_batch.value = 0
                try
                (
                    saveUiState()
                    case action_name of
                    (
                        #scan:
                        (
                            lbl_status.text = "Scanning..."
                            all_entries = MaterialLibraryManager.scanLibrary edt_root.text
                            scanned_root = edt_root.text
                            local category_values = #()
                            for entry_value in all_entries do appendIfUnique category_values (if entry_value.category == "" then "(Root)" else entry_value.category)
                            sort category_values
                            ddl_category.items = join #("All categories") category_values
                            ddl_category.selection = 1
                            refreshList()
                            lbl_status.text = (all_entries.count as string) + " MaterialX documents found. Select documents to import."
                        )
                        #import:
                        (
                            requireCurrentScan()
                            local chosen_entries = selectedEntries()
                            if chosen_entries.count == 0 then throw "Select at least one material document."
                            lbl_status.text = "Importing selected documents..."
                            local batch_result = MaterialLibraryManager.importEntries chosen_entries ddl_preview.selection spn_size.value spn_spacing.value spn_columns.value custom_node:custom_node progress_callback:updateProgress
                            refreshList()
                            lbl_status.text = "Documents imported: " + (batch_result[1] as string) + "; failed: " + (batch_result[2] as string) + ". Save category libraries when ready."
                        )
                        #save:
                        (
                            requireCurrentScan()
                            local save_result = MaterialLibraryManager.saveLibraries edt_root.text all_entries edt_output.text overwrite_existing:chk_overwrite.checked
                            lbl_status.text = "Libraries saved: " + (save_result[1].count as string) + "; skipped: " + (save_result[2] as string) + ". Incomplete categories are skipped."
                        )
                        #catalog:
                        (
                            requireCurrentScan()
                            local saved_catalog = MaterialLibraryManager.exportCatalog edt_root.text all_entries output_dir:edt_output.text overwrite_existing:chk_overwrite.checked
                            lbl_status.text = "Catalog saved: " + saved_catalog
                        )
                        #arrange:
                        (
                            requireCurrentScan()
                            local arranged_count = MaterialLibraryManager.arrangePreviews edt_root.text spn_spacing.value spn_columns.value
                            lbl_status.text = "Arranged previews: " + arranged_count as string
                        )
                        default:
                        (
                            requireCurrentScan()
                            local chosen_entries = selectedEntries()
                            if chosen_entries.count == 0 then throw "Select material documents to scope the preview action."
                            local source_files = for entry_value in chosen_entries collect toLower entry_value.source_file
                            local changed_count = if action_name == #replace then MaterialLibraryManager.replacePreviews edt_root.text ddl_preview.selection spn_size.value custom_node:custom_node source_files:source_files else MaterialLibraryManager.managePreviews edt_root.text action_name source_files:source_files
                            lbl_status.text = "Managed previews affected: " + changed_count as string
                        )
                    )
                    prg_batch.value = 100
                )
                catch
                (
                    local exception_text = getCurrentException()
                    lbl_status.text = "ERROR: " + exception_text
                    MaterialLibraryManager.logMessage exception_text
                )
                setInputEnabled true
                busy_state = false
            )
            true
            -- return
        )
        on materialLibraryManagerRollout open do
        (
            ToolTitleButton.setupToolTitleButton btn_tool_title "Material Library Manager"
            ToolTitleButton.resizeToolTitleButton btn_tool_title (materialLibraryManagerRollout.width - 24)
            lst_materials.SelectionMode = (dotNetClass "System.Windows.Forms.SelectionMode").MultiExtended
            lst_materials.IntegralHeight = false
            loadUiState()
            btn_custom.enabled = ddl_preview.selection == 4
        )
        on materialLibraryManagerRollout moved dialog_pos do
        (
            DialogHost.saveDialogPosition materialLibraryManagerRollout mlm_ui_ini_path mlm_ui_ini_section
        )
        on materialLibraryManagerRollout resized dialog_size do
        (
            ToolTitleButton.resizeToolTitleButton btn_tool_title (dialog_size.x - 24)
            local extra_height = amax 0 (dialog_size.y - 768)
            lst_materials.height = 216 + extra_height
            for control_pair in #(#(ddl_preview,426), #(btn_custom,444), #(lbl_placeholder,474), #(spn_size,504), #(lbl_size_unit,507), #(spn_spacing,504), #(lbl_spacing_unit,507), #(spn_columns,504), #(btn_import,540), #(btn_save,540), #(btn_catalog,540), #(btn_select,576), #(btn_hide,576), #(btn_show,576), #(btn_remove,576), #(btn_replace,612), #(btn_rebuild,612), #(prg_batch,648), #(lbl_status,672)) do
            (
                control_pair[1].pos = [control_pair[1].pos.x, control_pair[2] + extra_height]
            )
            DialogHost.saveDialogHeight materialLibraryManagerRollout mlm_ui_ini_path mlm_ui_ini_section min_height:768
        )
        on materialLibraryManagerRollout close do
        (
            saveUiState()
            DialogHost.saveDialogState materialLibraryManagerRollout mlm_ui_ini_path mlm_ui_ini_section min_height:768
        )
        on btn_tool_title Click sender event_args do
        (
            saveUiState()
            restartTool mlm_ui_entry_file "Material-Library-Manager"
        )
        on btn_browse pressed do
        (
            local picked_path = getSavePath caption:"Material library root" initialDir:edt_root.text
            if picked_path != undefined then
            (
                edt_root.text = picked_path
                edt_output.text = picked_path
                saveUiState()
                runAction #scan
            )
        )
        on btn_output pressed do
        (
            local picked_path = getSavePath caption:"MAT and HTML output folder" initialDir:edt_output.text
            if picked_path != undefined then
            (
                edt_output.text = picked_path
                saveUiState()
            )
        )
        on btn_scan pressed do runAction #scan
        on btn_import pressed do runAction #import
        on btn_save pressed do runAction #save
        on btn_catalog pressed do runAction #catalog
        on btn_select pressed do runAction #select
        on btn_hide pressed do runAction #hide
        on btn_show pressed do runAction #show
        on btn_replace pressed do runAction #replace
        on btn_rebuild pressed do runAction #arrange
        on btn_remove pressed do
        (
            if queryBox "Remove managed previews for the selected documents? Materials and source files are retained." title:"Material Library Manager" then runAction #remove
        )
        on btn_all pressed do
        (
            for list_index = 0 to (lst_materials.Items.Count - 1) do lst_materials.SetSelected list_index true
        )
        on btn_none pressed do lst_materials.ClearSelected()
        on ddl_category selected selected_index do refreshList()
        on ddl_preview selected selected_index do
        (
            btn_custom.enabled = selected_index == 4
            saveUiState()
        )
        on btn_custom picked picked_node do
        (
            custom_node = picked_node
        )
        on edt_root entered input_text do saveUiState()
        on edt_output entered input_text do saveUiState()
        on chk_overwrite changed checked_value do saveUiState()
        on spn_size changed numeric_value do saveUiState()
        on spn_spacing changed numeric_value do saveUiState()
        on spn_columns changed numeric_value do saveUiState()
    )
    DialogHost.createManagedDialog materialLibraryManagerRollout mlm_ui_ini_path mlm_ui_ini_section tool_key:mlm_ui_tool_key default_width:600 default_height:768 min_height:768
    windows.processPostedMessages()
    true
    -- return
)

