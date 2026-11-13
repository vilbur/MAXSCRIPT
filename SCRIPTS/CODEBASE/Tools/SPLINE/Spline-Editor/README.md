# Spline Editor

**Version:** 0.004 | **Type:** MAXScript Tool for Autodesk 3ds Max

A dockable utility for **Editable Spline** base-object editing, visibility, knot tools, Divide, Attach/Detach and Material ID assignment.

## Actions

- **Hide Selected:** native hide at the active Vertex, Segment, or Spline sub-object level.
- **Hide Unselected:** temporarily selects complementary components and hides them, then restores the original selection.
- **Unhide All:** restores all hidden segments, even outside sub-object mode.

At Vertex level, native `hideSelectedVerts` hides *segments attached to selected knots*. Segment or Spline mode is recommended for exact line-section isolation. Nothing is deleted.

## Added controls (v0.003; compact UI in v0.004)

- **Knots:** Fuse selected knots; Weld selected knots with a system-unit distance spinner; start interactive Cross Insert.
- **Cross Insert threshold:** a disabled reference control is visible because the native 3ds Max threshold is not exposed by a documented MAXScript setter. Adjust it in the native Modify panel; the tool does not pretend to control it.
- **Segments:** six division presets (1, 2, 3, 4, 6, 8) plus an integer spinner (1..100). Divide adds that many evenly placed knots to each selected segment.
- **Attach:** Attach Pick mode, native Attach Multiple dialog, and Attach Selected Objects (first selection is target, others are sources).
- **Detach:** native Detach dialog, Detach To Object (move), Object Clone (copy to object), and Spline Copy Inside (duplicate selected whole splines as separate sub-objects).
- **Explode:** native Explode for selected splines; the native UI controls whether to create splines or objects.
- **Spline Material IDs:** assign sequential IDs starting at 1 to selected splines or all splines. All segments in one spline get the same ID.

**Scope:** One Editable Spline base object for most commands; Attach Selected requires two or more Editable Spline objects. This build does not support Edit Spline modifier contexts or segment-based no-dialog Detach. Direct copy/move variants operate on selected whole splines at spline sub-object level. Native dialogs/modes still require user interaction.

**Safety:** The tool validates sub-object levels and checks topology changes where possible. Attach Selected removes source objects only after every add verifies a spline-count increase. If an operation partially fails, use Undo immediately before retrying. Test in a copy of your scene first.

## Files

- `Spline-Editor.ms` — main entry and dependency loader. Run this file.
- `Spline-Editor-FN.ms` — Tool-specific backend only.
- `Spline-Editor-UI.ms` — Tool frontend and managed dialog only.
- `Tests/Spline-Editor-Test.ms` — executable operation smoke tests for v0.003.
- `_Versions/` — previous development code.
- `design.md` — feature contract.
- `changes.md` — development log.

## Dependencies

Uses the **existing**, read-only shared MaxScript UI framework:

`G:\AI\AGENTS\Maxscript\UI\Default\`

Expected files: `IniSettings.ms`, `RolloutState.ms`, `DialogHost.ms`, `ScriptReload.ms`, `ToolTitleButton.ms`.

If your mapped framework path differs, assign the global `spline_editor_ui_framework_path` to its actual path before running the tool. The Tool does not copy or alter shared framework code.

The compact v0.004 UI is **144 px wide** with a section selector (Visibility, Knots, Segments, Splines, Material IDs). All existing operations remain available. The selected section, dialog position, and height are stored in `Spline-Editor.ini` beside its main `.ms` script. The dialog can float or dock left/right. LMB on the title button reloads the tool through the shared restart helper.

## Run

1. Run `Spline-Editor.ms` from 3ds Max **Scripting > Run Script**.
2. Select one **Editable Spline** (not an unconverted Line primitive).
3. Select a tool section from the compact dropdown; choose Vertex, Segment, or Spline sub-object level for Hide actions.
4. Use the appropriate action section; select Vertex, Segment, or Spline mode as labelled.
5. For Attach Selected Objects, select 2+ Editable Spline nodes (selection[1] is the target).

## Test

Load `Spline-Editor-FN.ms`, then run `Tests/Spline-Editor-Test.ms`. Tests create three-curve fixtures and exercise Divide, Material IDs, spline duplication, object clone, object move and attach selection. Interactive commands and docked UI require manual testing. Test geometry and Undo history remain in the scene. Inspect the Listener output and visually verify the result.

**Verification:** Autodesk MAXScript documentation checked; static source checks performed. Runtime verification in 3ds Max is **not completed**.
