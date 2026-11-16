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


**ALIGNMENT:** The collapsible section between OPTIONS and POSITIONS has three vertical radio-button columns: TOP / CENTER / GROUND (Z) on the left, FRONT / CENTER / BACK (Y) in the centre, and LEFT / CENTER / RIGHT (X) on the right. The chosen edge or centre of the managed Plane group’s world-space bounds moves to world 0 on that axis; other axes are unaffected. New settings default to GROUND on Z and CENTER on Y/X; previously saved choices remain unchanged. FRONT aligns the minimum Y boundary to world zero; BACK aligns the maximum Y boundary. Choices persist under `[Alignment]` in `Blueprint-Manager.ini` and are applied again on APPLY.


The thumbnail cross contains TOP, FRONT, SIDE, BACK, and BOTTOM. Preview width is 80 px; each preview's height follows its image aspect ratio, with scrolling enabled only when the images overflow the preview canvas. The dialog is registered as a CUI bar while floating, so it can be dragged and docked left or right; its width remains 288 px. The floating preview canvas grows up to 300 px. The docked canvas is 300 px high.


- **LMB, empty preview:** select an image.
- **LMB, assigned preview:** toggle that scene plane's visibility (only after APPLY).
- **CTRL+LMB, any preview:** show all managed planes if any is hidden; otherwise hide all.
- **RMB, any preview:** choose a filename at the top of the menu. The active filename starts with ✔. A separator divides the filenames from **Browse Directory**, **Add Image**, **Reset Blueprint**, and **Show Unused Slots**.
- **Docking:** drag the floating CUI title/gripper to the left or right edge of 3ds Max, or right-click the title button and choose Dock Left / Dock Right / Float. The docking side persists in the INI.
- **SIDE orientation:** unqualified `*side*` files use the RIGHT viewport convention by default. `*left*` uses the left view; `*right*` uses the right view. SIDE face normals use the native Plane direction (inward); APPLY disables the legacy `BM_SIDE_NORMAL_FLIP` inversion on existing managed SIDE planes. Image UVs, position and pivot remain unchanged.
- **POSITIONS:** collapsible rollout below ALIGNMENT and the action buttons, with TOP, FRONT, SIDE, BACK, and BOTTOM millimeter sliders.
- **Position sliders:** offset the matching Plane inward along its local Z (its inward-facing normal), measured from the original virtual-box wall. Each slider runs from 0 to the corresponding neighboring blueprint span. FRONT/BACK primarily use SIDE width; SIDE primarily uses FRONT width; TOP/BOTTOM use the greatest assigned upright-view height. If no perpendicular reference is assigned, the relevant slider is disabled.
- **APPLY (green, right-hand action button):** create/update assigned Plane objects without creating a Box, then hide unassigned image buttons and sliders; trim the preview canvas to the visible images. The same button changes to orange SETUP, and the floating dialog shrinks to fit the compact content.
- **SETUP (orange):** LMB restores all image slots and POSITION sliders for editing. RMB asks for confirmation, deletes only managed blueprint planes and removes their layers only when empty (unrelated nodes are preserved).
- **ON \ OFF (left-hand action button):** LMB shows all managed blueprint planes; RMB hides them. Both action buttons are 38 px high.
- **FREEZE checkbutton:** checked freezes all managed planes; unchecked unfreezes them while preserving image color.
- **TWO-SIDED checkbutton:** checked displays front and back faces, unchecked enables backface culling. It also synchronizes Standard-material two-sided display.
- **OPTIONS:** collapsible section below the action buttons and FREEZE/TWO-SIDED. RATIO 1px (mm per pixel) and Opacity (0–100%) share a single horizontal row; **Layer Name** is a second-row text field, default `_BLUEPRINTS`. APPLY creates or reuses that layer and moves managed blueprint planes into it. Changes persist in `Blueprint-Manager.ini`. One `subRollout` slot contains OPTIONS → ALIGNMENT → POSITIONS, with no inserted spacing. ALIGNMENT radio columns are shifted down 2 px, and OPTIONS uses tighter unit-label/slider spacing.


Automatic filename matching uses case-insensitive wildcards `*top*`, `*bottom*`, `*front*`, `*back*`, and `*side*` / `*left*` / `*right*` for the single SIDE slot. Each slot keeps every matching image. The first valid filename alphabetically is selected when the slot has no active image. A file whose name matches several slots is reported in the Listener and skipped. Candidate lists and active selections are saved in `Blueprint-Manager.ini`.


Plane objects are tagged with `BM_ROLE`, `BM_LAYER`, `BM_FILE`, and `BM_OFFSET_MM` user properties so reopening the UI can find them. New planes are frozen by default, with `showFrozenInGray = false`, gray RGB 128/128/128 wirecolor, a viewport-visible bitmap material, and primitive normals oriented toward the scene origin, including SIDE. Legacy managed SIDE Normal modifiers have Flip disabled on APPLY.


## Test status


**Static checks:** source-level delimiter and syntax-pattern checks; 3ds Max slider and subRollout APIs checked against Autodesk documentation. The offset mathematics were checked independently, but the tool still requires a 3ds Max runtime test.


**Not tested inside 3ds Max.** Running `Blueprint-Manager.ms` in 3ds Max is required to confirm UI behaviour, GDI+ preview display, texture mapping, and scene creation. Report the exact MaxScript Listener error and line number if execution fails.


## Files


- `Blueprint-Manager.ms` — canonical entry script.
- `versions/` — numbered source snapshots for rollback.
- `design.md` — scope, scene-space conventions, and behaviour contract.
- `changes.md` — change log.


The bottom expandable sections are ordered **OPTIONS → ALIGNMENT → POSITIONS**, all inside a single `subRollout` slot.