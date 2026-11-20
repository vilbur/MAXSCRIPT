# Changes

## 2026-11-18 — v0.039

- ON \ OFF button text is green when any managed blueprint is effectively visible, and red when all are hidden or no planes exist. Layer-hidden blueprints count as hidden.
- Refresh the colour on preview changes and from the existing dialog-state timer to reflect visibility changes made externally. Keep all button click actions and other UI layout unchanged.
- No changes to the shared scene operations module. Static checks passed; runtime UI test pending.

## 2026-11-17 — v0.038

- Added DBL LMB on any blueprint preview button to toggle all managed blueprint plane visibility. Single LMB actions are delayed by Windows' double-click interval to prevent a double-click from performing a single-click action first; CTRL+LMB remains immediate.
- Automatically hide each dedicated blueprint layer when all its managed Plane nodes are hidden, and show the layer when any blueprint becomes visible. Do not hide a layer containing unrelated scene objects.
- Synchronize layer visibility after individual/global visibility actions and APPLY; retain the existing image previews, INI settings and independent visibility controls.
- Static source checks passed; 3ds Max runtime click and scene-layer testing pending.

## 2026-11-16 — v0.037

- Split the single 3ds Max tool file into the unchanged canonical entry `Blueprint-Manager.ms`, scene operations `Blueprint-Manager-FN.ms`, and interface/handlers `Blueprint-Manager-UI.ms`.
- Use documented compile-time `include` in the entry file rather than `fileIn`, preserving lexical state and the original initialization order. Keep all three files in the same repository directory.
- Preserve v0.036 functional/UI logic without modification, including the saved GROUND default and FRONT/BACK Y alignment correction.
- Original full-functionality source was byte-compared against both extracted module bodies. Static split checks passed; native 3ds Max end-to-end testing pending.


## 2026-11-16 — v0.036

- Set GROUND (Z minimum) as the default vertical alignment for missing or invalid INI values; preserve valid saved selections. Y/X defaults remain CENTER.
- Reverse the FRONT/BACK radio alignment mapping on world Y: FRONT uses group minimum Y, BACK uses group maximum Y; CENTER unchanged. Do not alter plane transforms or position sliders.
- Static syntax/delimiter checks passed; 3ds Max runtime test pending.


## 2026-11-16 — v0.035


- Consolidate three separate subRollout slots into one `sr_sections` slot. Add child rollouts in OPTIONS → ALIGNMENT → POSITIONS order and size the slot to the visible child heights without inter-slot padding.
- Make POSITIONS child height follow the visible slider count so APPLY mode stays compact. Keep existing expand/collapse state and dialog fit behaviour.
- Move ALIGNMENT radio columns down 2 px and tighten the OPTIONS spinner unit-label/Opacity slider alignment.
- Stop creating flipped SIDE Normal modifiers; on APPLY disable the previous inversion on the managed SIDE node without deleting unrelated stack items.
- Static structure checks passed; 3ds Max end-to-end test remains pending.


## 2026-11-16 — v0.034


- Add OPTIONS > Layer Name (`_BLUEPRINTS` default), store it in the existing INI, and create/reuse that scene layer when APPLY creates or updates managed Plane nodes. Record BM_LAYER on each managed node.
- Add ON \ OFF before APPLY/SETUP. LMB shows and RMB hides only managed blueprint planes, leaving unrelated scene objects untouched.
- Set both action buttons to 38 px high (+8 px), side by side. Keep the OPTIONS/POSITIONS/ALIGNMENT subrollouts flush beneath the buttons.
- RMB on the SETUP-labelled button prompts before deleting the managed Planes; delete the associated layer only if empty, without deleting unrelated nodes. Keep image assignments for rebuilding.
- Static source checks passed; live Autodesk 3ds Max UI/scene test pending.


## 2026-11-16 — v0.033


- Added collapsible OPTIONS section for the RATIO 1px spinner, mm unit caption and Opacity slider, arranged on a single horizontal row. Preserved their existing persistence and behaviour.
- Moved APPLY/SETUP and FREEZE/TWO-SIDED directly under previews. Placed all subrollouts underneath in the order OPTIONS, POSITIONS, ALIGNMENT with zero spacing between adjacent subrollout slots.
- Updated floating dialog auto-height and collapsible section polling to include OPTIONS while preserving docked CUI behavior.
- Static source checks passed; runtime testing in Autodesk 3ds Max pending.


## 2026-11-16 — v0.032


- Rename the ALIGNMENT Z-axis third radio label from BOTTOM to GROUND; keep the BOTTOM blueprint slot and saved alignment index unchanged.
- Flip SIDE Plane face normals with a single managed Normal modifier, preserving its image UV orientation, right-view default, pivot, and existing local-Z position slider. Subsequent APPLY operations reuse the modifier, and existing SIDE planes update on APPLY.
- Static source and documentation checks passed; full Autodesk 3ds Max runtime test pending.


## 2026-11-15 — v0.031


- Arrange ALIGNMENT radio choices vertically as three side-by-side columns: TOP/CENTER/BOTTOM at left, FRONT/CENTER/BACK at centre, LEFT/CENTER/RIGHT at right.
- Keep all three independent axis selections, saved values, scene alignment and expandable rollout height unchanged. The new arrangement fits the existing 264 × 112 px ALIGNMENT subrollout.
- Static source checks passed; runtime layout verification in Autodesk 3ds Max pending.


## 2026-11-15 — v0.030


- Keep Blueprint Manager registered as a CUI dialog bar while floating, so users can drag it to dock left/right; retained Dock Left / Dock Right / Float title menu and INI dock-side persistence.
- Use `cui.FloatDialogBar` rather than unregistering on float, remove timer auto-unregister, and keep `setDialogPos` limited to the unregistered startup restoration.
- Generic SIDE blueprint filenames now use the RIGHT view by default; explicit LEFT filenames keep LEFT orientation, explicit RIGHT filenames keep RIGHT orientation.
- Keep v0.029 ALIGNMENT controls, blueprint image management, and unrelated scene settings unchanged.
- Static checks passed; live 3ds Max docking and SIDE transform test pending.


## 2026-11-15 — v0.029


- Added a collapsible ALIGNMENT subrollout directly below POSITIONS with three independent native radiobutton rows: TOP/CENTER/BOTTOM (Z), FRONT/CENTER/BACK (Y), LEFT/CENTER/RIGHT (X).
- Each row shifts only the managed blueprint Plane group along its axis so the selected boundary or bounding-box centre coincides with world zero. Group alignment also reapplies after APPLY, image switching, and position-slider changes.
- Stores each axis selection in the existing Blueprint-Manager.ini [Alignment] section, defaulting to CENTER.
- Reflowed the floating/docked dialog and expand/collapse height calculations for the new section. Did not edit shared UI libraries.
- Static source checks passed; live Autodesk 3ds Max UI and scene testing pending.


## 2026-11-12 — v0.028


- Explicitly left-align the native RATIO 1px spinner with `align:#left offset:[0,0]`.
- Preserve its existing absolute and runtime positions, 88 px width, 36 px field width and adjacent mm label to avoid off-screen regression.
- Static source check passed; 3ds Max runtime test pending.


## 2026-11-12 — v0.027


- Move the ratio spinner and its unit label 12 px right.


## 2026-11-12 — v0.026


- Correct the ratio spinner’s runtime horizontal anchor so the caption and field stay inside the dialog when the row moves vertically.


## 2026-11-12 — v0.025


- Match the fixed-position row in Spinner Layout Test v0.03 for the ratio spinner and unit label.


## 2026-11-12 — v0.024


- Fit the floating dialog to the visible previews and controls. Lock its width and keep the docked preview canvas at 300 px.
- Give the first POSITIONS caption clearance below the header and align the native ratio spinner and unit label.
- Put image filenames first in the preview context menu, prefix the active filename with ✔, and separate filenames from commands.


## 2026-11-12 — v0.023


- Keep multiple image files per blueprint view. Folder imports use the first valid filename in alphabetical order when the view has no active image.
- List candidate filenames in the preview context menu and check the active one. Add individual alternatives with Add Image.
- Save candidate lists in the tool INI. Switching an image updates existing blueprint planes in one undo step.


## 2026-11-12 — v0.022


- Open the floating dialog as a native resizable rollout and save its position and height through DialogHost.
- Right-click the title button to dock left, dock right, or return to the resizable floating window. CUI registration is used only for docking.


## 2026-11-12 — v0.021


- Create the floating dialog with a resize border and register it with an explicit CUI minimum size.
- Save floating position and height through the shared DialogHost. Restore them before CUI registration and compensate for the measured registration offset.
- Keep the preview canvas fixed at 300 px when docked or floating.


## 2026-11-12 — v0.020


- Keep the preview canvas at 300 px in both floating and docked dialogs, independent of rollout height or CUI state.
- Allow enough height for the fixed canvas and controls when opening an older compact floating layout or switching modes.
- Give the ratio caption its own label and move the native numeric field away from the left edge.


## 2026-11-12 — v0.019


- Save and restore the floating frame size and position together with the last dock side. Keep the floating geometry when docked.
- Keep the docked preview canvas at 300 px in both modes and scroll previews that exceed it.
- Use the floating frame handle for APPLY and SETUP height changes so registered CUI dialogs can resize.


## 2026-11-12 — v0.018


- Left-align the ratio spinner at the rollout margin with zero offset and the default 36 px numeric field. Use the native RATIO 1px caption and keep the mm label immediately after the control.


## 2026-11-12 — v0.017


- Attach the three preview menu commands through `ToolStripMenuItem.Owner` to avoid the duplicate .NET collection key during dialog startup.


## 2026-11-12 — v0.016


- Prevents preview scrollbar blinking during layout by applying child positions before recalculating scroll limits; scrollbars are enabled only when preview content exceeds its panel, and horizontal AutoScrollMinSize is zero.
- Resizes the floating dialog on APPLY to fit the compact previews and visible POSITION sliders; restores the previously saved editing height on SETUP. Docked CUI panels are left undisturbed.
- Stores the last SETUP height separately as `SetupHeight` in the existing `Blueprint-Manager.ini` and permits compact heights below 628 px.
- Sets the APPLY button font to green (RGB 64,212,96) and SETUP to orange (RGB 255,156,40), preserving its canonical dark button background.
- Sets Pixel Scale spinner `fieldWidth:64`; no changes to the blueprint Plane operations.
- Static structure checks passed; 3ds Max runtime verification is still required.


## 2026-11-12 — v0.015


- Fixed image-button left-click error at v0.014 line 1151 by explicitly calling `blueprintManagerRollout.layoutControls`.
- Fixed the same forward-reference issue in Browse Directory, Reset Blueprint, and Show Unused Slots handlers.
- Qualified `blueprintManagerRollout.updatePlaneCheckStates` in the reset handler, where that method is also declared later.
- No scene processing, UI layout, styling, or existing settings changed.
- Static checks passed; 3ds Max runtime test pending.


## 2026-11-12 — v0.014


- Replaced CREATE / UPDATE with a two-state **APPLY / SETUP** control. APPLY creates/updates blueprint planes, enters compact mode and hides unused image slots and their position sliders; SETUP restores the five-slot editing layout.
- Compact mode trims and centers the image-button canvas, closes gaps between missing middle-row views, and reduces the POSITIONS subrollout height to match visible sliders.
- Converted FREEZE into a checked-state button, alongside the new TWO-SIDED checked-state button. Two-sided mode enables both viewport back faces (`backFaceCull = false`) and Standard-material `twoSided`.
- Persists APPLY/SETUP mode, Freeze and Two-Sided states in the existing per-tool INI; preserves existing scene Plane geometry and other UI features.
- Static syntax and structure checks passed. Real 3ds Max UI and scene behavior still require runtime verification.


## 2026-11-12 — v0.013


- Match FRONT and BACK preview button heights to the SIDE thumbnail when a SIDE image is loaded.
- Lay out the scale row as RATIO 1px, spinner, mm.
- Hide unused preview slots after a successful CREATE / UPDATE. Restore them with Show Unused Slots in the preview context menu.


## 2026-11-12 — v0.012


- Move the floating CUI frame through its Windows handle. The MAXScript rollout position setter throws once CUI owns the dialog.
- Use the same unscaled screen coordinates for position reads, writes, and monitor checks. Preserve the frame size when moving it.


## 2026-11-12 — v0.011


- Corrected the closing delimiter of the floating-position restore function so the rollout can parse.


## 2026-11-12 — v0.010


- Restore and check the floating position after CUI registration, using screen pixels for the monitor bounds check. Read legacy position settings on first run.
- Draw each preview shortcut on its own line with a blank line between shortcuts. Keep the dark tooltip style.
- Align the Pixel Scale label and native spinner on one row and let the preview panel shrink when the dialog is resized.
- Store numbered snapshots in `versions/`. Run the root `Blueprint-Manager.ms` as the entry point.
- Source checks passed. Dialog behavior still requires a live 3ds Max test.


## 2026-11-12 — v0.009


- Removed redundant `windows.setWindowPos` / `windows.getWindowPos` logic, which mixed UI-scaled and unscaled coordinates and could push the dialog outside the visible desktop.
- Reused the canonical shared `DialogHost.createManagedDialog` and `DialogHost.saveDialogPosition` instead of duplicating position persistence.
- Closed previous Blueprint Manager dialog instances **before** validating saved coordinates, preventing their close handlers from overwriting the recovered position.
- Validated stored position against each connected monitor's working area. Missing or out-of-bounds positions now reset to a safe location on the primary screen.
- Retained floating/dock-left/dock-right behavior and left all blueprint functions and menus unchanged.
- Static delimiter checks and focused assertions passed. Runtime behavior in Autodesk 3ds Max **not tested**.


## 2026-11-12 — v0.008


- Added a dark WinForms right-click context menu to all five blueprint image buttons.
- Browse Directory imports images across slots using existing filename matching and conflict reporting.
- Reset Blueprint clears the clicked assignment and position offset, and deletes its managed Plane after confirmation when present.
- Updated image-button tooltip instructions.
- Kept existing left-click visibility and image-browse actions unchanged.




## 2026-11-12 — v0.007


- Fixed the Pixel Scale spinner escaping the left dialog edge: restored absolute x=12 placement, removed conflicting `align:#left`, and used a compact 160 px control width.
- Reformatted preview tooltips into short, separate LMB/RMB/CTRL + LMB paragraphs with Windows CRLF line breaks; tightened other control descriptions.
- Fixed floating-dialog position persistence using the documented `windows.getWindowPos` / `windows.setWindowPos` API when CUI dialog-bar registration is active.
- Avoided saving a transient position while the CUI host is being initialized; preserve the last floating position while docked.
- Saved floating position before dialog teardown; added readback diagnostics if INI position write or restoration fails.
- Did not modify shared UI helpers or scene-geometry operations.


## 2026-11-11 — v0.004


- Applied canonical dark WinForms button styling to CREATE / UPDATE, FREEZE, and all five image buttons.
- Set WinForms tooltips to owner-drawn dark backgrounds and light text.
- Preserved the dark title button and image panel; native MaxScript sliders, spinner and subrollout retain the host 3ds Max theme.
- No geometry, slider, visibility, image-import, persistence or layout behavior changed.


## 2026-11-11 — v0.003


- Added tooltips for all five image buttons, five POSITIONS sliders, Pixel Scale, Opacity, CREATE / UPDATE, FREEZE and the title/restart button.
- Described LMB, RMB and CTRL+LMB shortcuts, folder filename matching and position slider travel limits.
- No functional scene operations or UI layout changed.




## 2026-11-10 — v0.002


- Added collapsible **POSITIONS** rollout immediately beneath blueprint image previews.
- Added five millimeter sliders with bounds from perpendicular assigned blueprint dimensions.
- Applied absolute inward local-Z offsets to managed Plane nodes and preserved them on CREATE / UPDATE.
- Persisted each offset in the scene (`BM_OFFSET_MM`) and tool INI.
- Increased default/minimum dialog height to accommodate the new rollout.
- Preserved v0.001 source as a separate versioned snapshot.