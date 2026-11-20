# Blueprint Manager — design v0.039


## Scope


A standalone, left/right dockable 288 px wide 3ds Max rollout. One resizable scrollable image-preview area; five scene views in a cross, TOP above, FRONT/SIDE/BACK across, BOTTOM below. Exact preview width 80 px, with image-proportional height. The image preview is followed by two 126 × 38 px action buttons (ON \ OFF, APPLY/SETUP), the two FREEZE/TWO-SIDED checks, then one `subRollout` slot containing OPTIONS, ALIGNMENT and POSITIONS in that order, without spacer controls. OPTIONS includes RATIO and Opacity on one row (tight mm-label gap) and Layer Name on the next row. Each of the three child headers remains independently collapsible. Each view is an independently assigned image and Plane node.


## Scene-space contract


The virtual box is **not** geometry. Its extents follow the largest projected image dimensions along each axis. When an axis cannot be inferred because there is no applicable orthogonal view, the largest image dimension is used as that axis' fallback extent. The box is centered on origin; each image Plane's centre lies on the opposite wall from its corresponding viewport direction.


Image dimensions in system units are calculated as `(image pixel size) × (mm per pixel) × (units.decodeValue "1mm")`. The actual Plane dimensions follow their own image, even when different view images disagree in scale.


Plane local X is image horizontal, local Y is image vertical, and local Z points towards world origin. Axis assignments:


| Slot | Position | Local X | Local Y | Inward normal |
|---|---|---|---|---|
| TOP | -Z | +X | +Y | +Z |
| BOTTOM | +Z | -X | +Y | -Z |
| FRONT | +Y | +X | +Z | -Y |
| BACK | -Y | -X | +Z | +Y |
| SIDE (`*left*`) | +X | -Y | +Z | -X |
| SIDE (`right` default, `*side*` or `*right*`) | -X | +Y | +Z | +X |


Input filename `*left*` uses the left viewport convention; `*right*` uses the right viewport convention; generic `*side*` defaults to right. Every generated transform is right-handed with a local +Z placement direction pointing inward. SIDE uses its native Plane normals, pointing inward (default RIGHT: +X, explicit LEFT: -X), with no new Normal modifier. For previously managed SIDE planes tagged by the tool, APPLY disables the v0.032 `BM_SIDE_NORMAL_FLIP` modifier’s Flip flag without deleting the modifier or changing unrelated stack items. The Plane transform, bitmap UVs, and local-Z position slider remain unchanged. The TWO-SIDED checkbutton controls both node `backFaceCull` (inverted) for viewport display and Standard material `twoSided`.


## Alignment to world origin


The ALIGNMENT child rollout appears between OPTIONS and POSITIONS inside one shared subrollout slot. It displays three independent vertical radio-button columns (left: Z, centre: Y, right: X), saved in the tool INI as Vertical, Depth and Horizontal (defaults: GROUND on Z, CENTER on Y/X; stored valid preferences are preserved):


- TOP/CENTER/GROUND aligns the group’s maximum/centre/minimum Z to world Z=0.
- FRONT/CENTER/BACK aligns the group’s minimum/centre/maximum Y to world Y=0. This intentionally reverses the previous FRONT/BACK Y-axis alignment mapping without moving or rotating the individual FRONT/BACK plane definitions.
- LEFT/CENTER/RIGHT aligns the group’s maximum/centre/minimum X to world X=0.


The group is the union of world-space bounding boxes (`nodeGetBoundingBox`) of scene Planes tagged with the managed BM_ROLE values, not any unrelated objects. Changing one radio group translates only that world axis. APPLY and image switching reconstruct plane transforms, then reapply the three saved alignments; position slider changes also retain the anchor. ALIGNMENT is independently collapsible.


## Position sliders


The five POSITION sliders move the corresponding Plane **along its local +Z axis (inward normal)**, starting at its initial virtual-box wall (0 mm). Values are absolute, not accumulated drag distances. The values are in millimeters, independent of current system units, and remain attached to the Planes through `BM_OFFSET_MM` as well as the per-tool INI. An APPLY operation rebuilds the base transform and then reapplies the saved offset.


The travel range is image-derived in millimeters using the active `mm / px` setting. FRONT/BACK prefer the SIDE blueprint width; SIDE prefers FRONT width (BACK when FRONT is missing); TOP/BOTTOM use the maximum vertical size among available FRONT/SIDE/BACK images. When a preferred perpendicular image is absent, available TOP/BOTTOM dimensions serve as fallback for FRONT/BACK and SIDE; when no perpendicular image exists, the slider is disabled. If source size or scale reduces a range below a previously stored offset, it is limited to the new maximum and the adjustment is written to the scene.


The main dialog keeps its 288 px fixed width and is vertically resizable. A single bottom subrollout slot contains OPTIONS, ALIGNMENT, and POSITIONS; its height follows the expanded child heights. The POSITIONS child height also follows the number of visible slider rows in compact mode. The ALIGNMENT radio columns are offset down by 2 px. Default SETUP height is 780 px. The compact floating dialog may shrink below 628 px, with 360 px as its persistence floor. The panel only enables AutoScroll for vertically overflowing previews and avoids horizontal AutoScrollMinSize; docked CUI panels retain their host-managed height.


## Compact preview and display modes (v0.016)


- **APPLY:** creates/updates all assigned Plane nodes, switches to a compact layout, hides unassigned image buttons and matching POSITION sliders, trims the image-button canvas to visible content and closes gaps between absent middle-row images. The action button becomes **SETUP**.
- **SETUP:** returns to the full five-slot cross and shows all five POSITION sliders so more images can be assigned. The action button becomes **APPLY**. Existing right-click **Show Unused Slots** also returns to SETUP.
- The dialog remains 288 px wide; the preview panel is resized and centered inside it. APPLY fits the floating dialog height to its compact content, while SETUP restores the saved editing height; docked CUI frame dimensions are unchanged.
- The APPLY caption is green (RGB 64,212,96), the SETUP caption orange (RGB 255,156,40). The Pixel Scale native spinner numeric field is 64 px wide.
- Layout changes update preview AutoScroll only when overflow or scrollbar limits actually change. Scrollbar state updates occur after control positions and final panel height are resolved.
- **FREEZE:** checked freezes all managed planes; unchecked unfreezes them, preserving `showFrozenInGray = false`.
- **TWO-SIDED:** checked disables viewport backface culling and enables Standard-material two-sided display; unchecked reverses both. These checked states and the setup mode are stored in the existing tool INI.


## Persistence and object ownership


- View assignments, offsets, and UI settings: an INI next to the entry script, shared across code versions.
- Existing scene planes: distinguished by user property `BM_ROLE`, with image path in `BM_FILE` and millimeter local-Z offset in `BM_OFFSET_MM`.
- APPLY works with existing tagged native `Plane` nodes; it does not modify unrelated geometry or create a separate box.
- The default new Plane wirecolor is RGB (128,128,128); it is frozen, but not shown in frozen gray.
- Visibility clicks change only the managed node hidden flags, not global hide/unhide state.
- Standard materials with BitmapTexture are used to expose opacity and viewport texture display.
- Shared UI host, title, restart and INI functions are loaded from canonical `UI/Default` files rather than forked.


## Explicit v0.001 limitations


- No native 3ds Max runtime test has yet been performed.
- If a user replaces a loaded image, the image preview updates immediately; the scene plane is updated by APPLY.
- The script does not automatically solve physical alignment conflicts across reference images of different resolutions.
- No automatic texture-file watcher, mirroring, per-view opacity, or layer integration in this version.
- Scene objects hidden by their layer or by global category filters may not be visible even when their individual hidden flag is off.


## v0.030 — CUI docking and generic SIDE orientation


The owning dialog remains registered as a CUI bar even when floating, using `#(#cui_dock_vert, #cui_floatable, #cui_handles)`. Drag docking works on the left and right only; CUI handles the transition back to floating, while the INI retains the side. Geometry restoration using `setDialogPos` occurs only before CUI registration.


Generic SIDE images without `left` or `right` in their basename now use the RIGHT view: world -X, local +X aligned to world +Y, inward normal +X. An explicit `left` filename retains the LEFT view: world +X, inward normal -X.


## v0.032 — UI terminology and SIDE face normal


- ALIGNMENT Z-axis third choice is displayed as GROUND instead of BOTTOM. The underlying option remains index 3, aligning the managed group's minimum world Z to zero. The BOTTOM blueprint slot, file matching, scene role and position slider remain named BOTTOM for compatibility.
- SIDE face normals are inverted by a named managed Normal modifier, without changing the RIGHT-default orientation, placement, image UVs, or pivot. Existing SIDE Planes receive the modifier on the next APPLY. No other blueprint plane is changed.


## v0.033 — Bottom OPTIONS / POSITIONS / ALIGNMENT stack


- The primary dialog order is: title, image preview canvas, APPLY/SETUP, FREEZE and TWO-SIDED, then the contiguous subrollout stack **OPTIONS → POSITIONS → ALIGNMENT**. There is **0 px** spacing between adjacent subrollout slots.
- OPTIONS contains the RATIO 1px spinner, mm unit caption and Opacity slider on one horizontal row. Both controls retain their existing INI keys and event behavior.
- The main dialog recalculates total height from the final ALIGNMENT section, respecting each subrollout’s collapsed/expanded state and keeping docked height host-managed.
- All three expandable sections remain separately collapsible; only the UI composition changes, not managed plane operations.


## v0.034 — layer ownership and action buttons


- OPTIONS stores `LayerName` under `[MainUI]`; default `_BLUEPRINTS`. APPLY uses `LayerManager.getLayerFromName` / `newLayerFromName` and `LayerProperties.addNode` for each managed Plane. A user may type another scene-layer name; existing nodes move to that layer on the next APPLY. No unrelated nodes are moved.
- Each applied Plane receives `BM_LAYER` as its associated layer name. Managed scene-plane lookup continues to use `BM_ROLE`, so preexisting tagged Planes remain compatible.
- ON \ OFF performs explicit per-node show (LMB) or hide (RMB), without toggling unrelated nodes sharing the chosen layer. Existing preview visibility shortcuts are retained.
- SETUP RMB acts only when the button displays SETUP, asks for confirmation, and deletes all `BM_ROLE` Plane nodes. Candidate layer names come from the managed nodes' `BM_LAYER` properties. After deletion, a candidate layer is removed only if it is empty; nonempty layers are preserved. The tool returns to editing mode without clearing assigned image paths. The operation has an Undo label.
- Action buttons are both 38 px high, arranged horizontally above the freeze/two-sided row. The three subrollout slots remain contiguous; OPTIONS expansion height accommodates the layer-name field.


## v0.035 — shared section slot and SIDE normal correction


- One `sr_sections` slot hosts OPTIONS → ALIGNMENT → POSITIONS. Height is calculated as the sum of the open child rollout heights plus their native headers; closed children retain only their headers. No inter-slot padding is inserted.
- OPTIONS repositions the `mm` unit label to x=118 and the Opacity slider to x=146, retaining the first-row RATIO/Opacity and second-row Layer Name controls.
- ALIGNMENT native radio columns start at y=16 (+2 px), without changing saved selections or axis logic.
- SIDE no longer creates inverted Normal modifiers. On APPLY, the legacy tool-created named Normal modifier on a tagged SIDE Plane has `flip=false`, restoring the native inward-facing normal without mirroring UVs. No unrelated modifiers are deleted.

## v0.036 — Default ground alignment and Y-axis alignment inversion

- Default `[Alignment] Vertical` to option 3 (GROUND, minimum world Z = 0) when the INI value is missing or invalid. Keep saved valid alignment settings; Y and X still default to CENTER.
- Invert only the Y-axis alignment selection: FRONT aligns the minimum Y group boundary to 0; BACK aligns the maximum Y group boundary to 0; CENTER is unchanged. The FRONT and BACK scene Plane transforms, filenames and position sliders are unchanged.


## v0.037 — entry, scene functions and UI modules

- `Blueprint-Manager.ms` is the only runnable entry file. It resolves `getSourceFileName()` and the shared UI/Default framework, then compiles `Blueprint-Manager-FN.ms` and `Blueprint-Manager-UI.ms` with literal `include` statements. Dialog construction and CUI registration stay in the entry script.
- `Blueprint-Manager-FN.ms` contains the complete `BlueprintManager_v` struct and instance. It has no UI rollout definitions.
- `Blueprint-Manager-UI.ms` contains the existing four rollouts and their handlers, including OPTIONS → ALIGNMENT → POSITIONS within one `sr_sections` subrollout slot.
- MAXScript compile-time `include` retains the entry file lexical scope, unlike `fileIn`. This preserves existing local state, INI paths, rollout references, event handlers, object lifetime and scene operations without new globals or duplicate helpers.
- Both included modules must be beside the entry file. The runtime dependency on canonical shared UI/Default remains unchanged; `Blueprint-Manager.ini` stays beside the entry file. No scene or UI behaviour is intentionally changed by the split.

## v0.038 — Preview double-click and automatic layer visibility

- `Blueprint-Manager-UI.ms` uses a short native timer based on `System.Windows.Forms.SystemInformation.DoubleClickTime` and the OS double-click size to distinguish two left mouse-downs on the same preview button. This avoids relying on an unsupported WinForms Button `DoubleClick` event and defers the existing single-click image-selection or individual visibility action until the double-click interval expires. CTRL+LMB is immediate.
- DBL LMB toggles all managed blueprint planes using the existing `toggleAll()` semantics (show all if any is hidden; otherwise hide all); the preview refresh runs once after the action.
- `Blueprint-Manager-FN.ms` synchronizes each layer referenced by managed Plane `BM_LAYER` user properties. It sets `LayerProperties.ishidden = true` when the layer contains managed blueprints and all those nodes have `isNodeHidden = true`, then restores the layer when any managed blueprint becomes visible. The tool does not hide a layer that contains unrelated nodes, protecting unrelated scene content.
- Automatic sync runs on APPLY and both single-node and all-node visibility changes; no new scene objects or separate INI keys are introduced.


## v0.039 — ON \ OFF state colour

- ON \ OFF foreground is green RGB (64,212,96) while at least one managed Plane is effectively visible (node and layer shown), otherwise red RGB (255,76,76). No managed planes means red.
- Refresh colour on each preview layout update (including APPLY, SETUP, single/double-click and ON \ OFF commands) and on the existing dialog-state timer for external scene/layer visibility changes. Keep shared dark button background and style unchanged.
