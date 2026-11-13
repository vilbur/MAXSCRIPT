# Blueprint Manager — design v0.016

## Scope

A standalone, left/right dockable 288 px wide 3ds Max rollout. One resizable scrollable image-preview area; five scene views in a cross, TOP above, FRONT/SIDE/BACK across, BOTTOM below. Exact preview width 80 px, with image-proportional height. A collapsible POSITIONS subrollout sits directly under the thumbnail panel and above mm-per-pixel, opacity, APPLY/SETUP, FREEZE and TWO-SIDED controls. It contains a local-Z slider for every view. Each view is an independently assigned image and Plane node.

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
| SIDE (`left` default) | +X | -Y | +Z | -X |
| SIDE (`*right*`) | -X | +Y | +Z | +X |

Input filename `*left*` uses the left viewport convention; `*right*` uses the right viewport convention; generic `*side*` defaults to left. Every generated transform is right-handed with an inward-facing primitive normal. The TWO-SIDED checkbutton controls both node `backFaceCull` (inverted) for viewport display and Standard material `twoSided`.

## Position sliders

The five POSITION sliders move the corresponding Plane **along its local +Z axis (inward normal)**, starting at its initial virtual-box wall (0 mm). Values are absolute, not accumulated drag distances. The values are in millimeters, independent of current system units, and remain attached to the Planes through `BM_OFFSET_MM` as well as the per-tool INI. An APPLY operation rebuilds the base transform and then reapplies the saved offset.

The travel range is image-derived in millimeters using the active `mm / px` setting. FRONT/BACK prefer the SIDE blueprint width; SIDE prefers FRONT width (BACK when FRONT is missing); TOP/BOTTOM use the maximum vertical size among available FRONT/SIDE/BACK images. When a preferred perpendicular image is absent, available TOP/BOTTOM dimensions serve as fallback for FRONT/BACK and SIDE; when no perpendicular image exists, the slider is disabled. If source size or scale reduces a range below a previously stored offset, it is limited to the new maximum and the adjustment is written to the scene.

The main dialog keeps its 288 px fixed width and is vertically resizable, with the thumbnail panel above POSITIONS. Default SETUP height is 780 px. The compact floating dialog may shrink below 628 px, with 360 px as its persistence floor. The panel only enables AutoScroll for vertically overflowing previews and avoids horizontal AutoScrollMinSize; docked CUI panels retain their host-managed height.

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
