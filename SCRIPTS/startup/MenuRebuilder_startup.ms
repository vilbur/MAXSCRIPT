/*
	Auto generated menu startup loader.
	Compile mode: production
*/

global MenuBuildManager
global MenuRebuilder_qmnx_clear_guard = false

try
(
	fileIn @"C:\GoogleDrive\CODE\MAXSCRIPT\SCRIPTS\GIT\MenuManager\Lib\MenuBuildManager\MenuBuildManager.ms"
)
catch
(
	startup_exception = getCurrentException()
	format "Failed to fileIn MenuBuildManager file.\n%\n" startup_exception
	throw
)

try
(
	MenuBuildManager = MenuBuildManager_v data_file_path:@"C:\GoogleDrive\CODE\MAXSCRIPT\SCRIPTS\startup\MenuRebuilder_data.json" native_data_file_path:@"C:\GoogleDrive\CODE\MAXSCRIPT\SCRIPTS\startup\MenuRebuilder_data.msdata" compile_mode:production merge_existing_data:false qmnx_clear_directory:@"" clear_default_menu:false
	saved_menus_data = MenuBuildManager.loadSavedMenusDataFromJson()
	MenuBuildManager.saved_menus_data = saved_menus_data
	format "MenuBuildManager startup loaded % saved menus.\n" saved_menus_data.count
	MenuBuildManager.registerCallback()
)
catch
(
	startup_exception = getCurrentException()
	format "Menu rebuild from disk failed.\n%\n" startup_exception
	throw
)
