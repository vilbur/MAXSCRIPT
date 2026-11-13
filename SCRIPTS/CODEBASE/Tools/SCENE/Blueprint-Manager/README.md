# Blueprint Manager

First MaxScript implementation of the scene blueprint reference manager for Autodesk 3ds Max.

## Run

Open `Blueprint-Manager.ms` in 3ds Max and run it with **Scripting > Run Script**. The script is not a standalone Windows application.

The canonical shared UI framework is a **runtime dependency**. The script searches these local Windows folders in order:

- `G:\AI\AGENTS\Maxscript\UI\Default\`
- `C:\GoogleDrive\AI\AGENTS\Maxscript\UI\Default\`
- `D:\GoogleDrive\AI\AGENTS\Maxscript\UI\Default\`

These folders must contain `IniSettings.ms`, `RolloutState.ms`, `DialogHost.ms`, `ScriptReload.ms`, and `ToolTitleButton.ms`. If your actual synced-drive path differs, change the candidate list near the top of `Blueprint-Manager.ms` to point to the existing canonical framework. Shared UI code is not duplicated in this repository.

The UI state (including APPLY/SETUP, FREEZE and TWO-SIDED), blueprint paths, and per-view position offsets (in millimeters) are saved to `Blueprint-Manager.ini` next to the entry script. Scene offsets take precedence when reopening a scene containing tagged blueprint planes. The `.ini` is created by the running tool.

## Controls

The thumbnail cross contains TOP, FRONT, SIDE, BACK, and BOTTOM. Preview width is 80 px; each preview's height follows its image aspect ratio, with scrolling enabled only when the images overflow the preview canvas. The floating dialog has a fixed width and fits its height to the visible controls. The floating preview canvas grows up to 300 px. The docked canvas is 300 px high.

- **LMB, empty preview:** select an image.
- **LMB, assigned preview:** toggle that scene plane's visibility (only after APPLY).
- **CTRL+LMB, any preview:** show all managed planes if any is hidden; otherwise hide all.
- **RMB, any preview:** choose a filename at the top of the menu. The active filename starts with ✔. A separator divides the filenames from **Browse Directory**, **Add Image**, **Reset Blueprint**, and **Show Unused Slots**.
- **POSITIONS:** collapsible rollout immediately below thumbnails, with TOP, FRONT, SIDE, BACK, and BOTTOM millimeter sliders.
- **Position sliders:** offset the matching Plane inward along its local Z (its inward-facing normal), measured from the original virtual-box wall. Each slider runs from 0 to the corresponding neighboring blueprint span. FRONT/BACK primarily use SIDE width; SIDE primarily uses FRONT width; TOP/BOTTOM use the greatest assigned upright-view height. If no perpendicular reference is assigned, the relevant slider is disabled.
- **APPLY (green):** create/update assigned Plane objects without creating a Box, then hide unassigned image buttons and sliders; trim the preview canvas to the visible images. The same button changes to orange SETUP, and the floating dialog shrinks to fit the compact content.
- **SETUP (orange):** restore all five image slots and POSITION sliders for editing, including the hidden unassigned slots, and fit the floating dialog to the editing controls.
- **FREEZE checkbutton:** checked freezes all managed planes; unchecked unfreezes them while preserving image color.
- **TWO-SIDED checkbutton:** checked displays front and back faces, unchecked enables backface culling. It also synchronizes Standard-material two-sided display.
- **Opacity:** change Standard-material opacity in the scene (0–100%).
- **RATIO 1px [spinner] mm:** physical millimeters per image pixel, default 1.0 mm/px, with a 36 px numeric field. Apply with APPLY.

Automatic filename matching uses case-insensitive wildcards `*top*`, `*bottom*`, `*front*`, `*back*`, and `*side*` / `*left*` / `*right*` for the single SIDE slot. Each slot keeps every matching image. The first valid filename alphabetically is selected when the slot has no active image. A file whose name matches several slots is reported in the Listener and skipped. Candidate lists and active selections are saved in `Blueprint-Manager.ini`.

Plane objects are tagged with `BM_ROLE`, `BM_FILE`, and `BM_OFFSET_MM` user properties so reopening the UI can find them. New planes are frozen by default, with `showFrozenInGray = false`, gray RGB 128/128/128 wirecolor, a viewport-visible bitmap material, and normals oriented toward scene origin.

## Test status

**Static checks:** source-level delimiter and syntax-pattern checks; 3ds Max slider and subRollout APIs checked against Autodesk documentation. The offset mathematics were checked independently, but the tool still requires a 3ds Max runtime test.

**Not tested inside 3ds Max.** Running `Blueprint-Manager.ms` in 3ds Max is required to confirm UI behaviour, GDI+ preview display, texture mapping, and scene creation. Report the exact MaxScript Listener error and line number if execution fails.

## Files

- `Blueprint-Manager.ms` — canonical entry script.
- `versions/` — numbered source snapshots for rollback.
- `design.md` — scope, scene-space conventions, and behaviour contract.
- `changes.md` — change log.
