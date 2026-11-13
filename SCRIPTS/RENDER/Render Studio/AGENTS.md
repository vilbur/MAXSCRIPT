# Render Studio — Local AGENTS


This file applies to `GoogleDrive/CODE/MAXSCRIPT/RENDER/Render Studio/` and all descendants.


Follow the parent MaxScript rules, especially the shared root `AGENTS.md`, `Codebase/Tools/AGENTS.md`, `maxscript-ui-rules.md`, `maxscript-syntax-safety.md`, `maxscript-protected-identifiers.md`, `maxscript-unit-precision.md`, and project settings.


## Protected Tool scope


`Render Studio` is the canonical Render Studio repository. Modify it only when the current user prompt explicitly authorizes this Tool.


## Canonical repository


```text
G:\CODE\MAXSCRIPT\RENDER\Render Studio\
```


The folder name defines the canonical entry filename.


## Required package


The three current source files in the Tool root are:


```text
Render Studio.ms
Render Studio-FN.ms
Render Studio-UI.ms
```


Responsibilities:
- `Render Studio.ms` — stable entry point; resolves shared UI dependencies, loads backend/frontend, and creates the managed dialog.
- `Render Studio-FN.ms` — backend only; renderer, materials, bounds, lights, HDRI, camera, studio ownership, and setup coordination. It must not reference rollout controls or create dialogs.
- `Render Studio-UI.ms` — frontend only; controls, UI persistence, callbacks, status presentation, and restart behavior.


Previous source releases belong in `_Versions/`. Executable test workflows belong in `Tests/`.


## Shared UI framework


Prefer the canonical relative shared UI path:


```text
G:\CODE\MAXSCRIPT\UI\Default\
```


During repository migration, the entry may fall back to:


```text
G:\AI\AGENTS\Maxscript\UI\Default\
```


Do not copy the shared UI helpers into this Tool.


## Versioning


Current project version: `0.13`.

Stable baseline: `0.11`.


Each modified code file stores:
- its own file version;
- the shared project version.


The highest loaded project version wins. The native rollout title displays the global project version. The `tool title button` displays only `Render Studio`.


## Purpose


Render Studio builds a neutral Arnold sculpture/product studio around explicit selected scene nodes.


Core behavior:
- activate Arnold;
- compute world-space selection bounds;
- optionally assign a neutral gray Physical Material;
- create Tool-owned floor and backdrop geometry;
- create two targeted Arnold Spot lights;
- optionally apply an HDRI using one of two modes;
- otherwise create a neutral Arnold Skydome fallback;
- optionally create and activate a targeted Physical Camera;
- set a square 1024 × 1024 render size.


## Arnold light types


For the current MAXtoA generic `Arnold_Light` enum used by this Tool:
- Spot = `shapeType:2`;
- Skydome = `shapeType:6`.


These values were validated against the connected 3ds Max 2026 / TurboSquid Arnold scene. Do not restore the prototype values `3` or `7` without revalidating the MAXtoA enum.


## HDRI modes


Supported files:
- `.hdr`
- `.exr`


Scanning is non-recursive.


Modes:
- `Dome Light` — assign the selected bitmap to `STUDIO_Sky.texmap`.
- `Environment` — assign the selected bitmap to the 3ds Max Environment Map.


Render Studio owns one `BitmapTexture` named `STUDIO_HDRI` in Material Editor slot 1. Slot 1 is the canonical reference: Dome mode assigns `STUDIO_Sky.texmap = meditMaterials[1]` and Environment mode assigns `environmentMap = meditMaterials[1]`. Do not reverse this ownership direction. Viewport HDRI preview temporarily assigns the same slot-1 instance to the Environment map, enables the viewport Environment background, and restores the previous Environment state when disabled.


The Environment mode captures the prior environment state before overriding it and restores that state when the Tool switches away from its Environment override during the same loaded Tool session.


When no valid HDRI is selected, create the neutral `STUDIO_Sky` fallback.


## Ownership and safety


Generated scene nodes use the `STUDIO_` prefix and exact Tool-owned names documented in `design.md`.


Rebuilding may remove only those owned nodes/targets. Never delete unrelated user lights, cameras, geometry, materials, or helpers.


Do not silently substitute another renderer, legacy light type, or legacy material when Arnold/Physical Camera requirements are unavailable.


## UI


Use the shared default UI framework.


Required baseline:
- `tool title button` at the top;
- LMB restart through `restartTool`;
- stable `Render Studio.ini` beside `Render Studio.ms`;
- persistent HDRI directory/file, HDRI enable state, HDRI mode/strength, material option, camera option, dialog position, and dialog height;
- fixed dialog width `288 px`, explicit native `#style_resizing`, vertically resizable height, and position/height persistence; the current registered-dialog position correction is the measured `[6,29]` CUI offset for this 3ds Max/display setup;
- 12 px layout grid and compact native controls;
- native dialog title shows project version; title button does not.
- the `RENDER` action is a standard-styled `.NET` button with orange text and delegates rendering to the backend.
- the `VIEWPORT` toggle adds/removes the current slot-1 HDRI as the active viewport Environment background; this preview is temporary and is removed on tool close.
- dome HDRI rotation uses a 0-360 integer slider (1-degree steps); each HDRI path stores its own angle in the `STUDIO_Sky` user property `RS_HDRI_ROTATIONS`.
- `CLONE BUFFER` clones the last rendered image into a separate VFB window.


## Tests


Keep the executable workflow in `Tests/Render Studio-Test.ms` with numbered `partOfTestN()` stages and an explicit execution queue.


Scene-changing stages require named undo entries. Leave the final tested scene state available for inspection and print the undo order.