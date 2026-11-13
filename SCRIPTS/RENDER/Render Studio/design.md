# Render Studio Design


## Purpose


Render Studio creates a controlled Arnold studio/lightbox around the current object selection for sculpture and product rendering.


The visual target is a neutral gray subject with readable shape definition, soft key/fill lighting, and optional HDRI contribution.


## Architecture


```text
Render Studio.ms
    -> shared UI framework
    -> Render Studio-FN.ms
    -> Render Studio-UI.ms


Render Studio-UI.ms
    -> RenderStudio public backend methods


Render Studio-FN.ms
    -> 3ds Max / MAXtoA APIs only
```


The Tool has no upward dependency on a Toolset or manager.


## Backend


`Render Studio-FN.ms` owns:
- Arnold renderer discovery/activation;
- HDRI enumeration;
- world-space selection bounds;
- Physical Materials;
- Tool-owned scene cleanup;
- Arnold Spot lights;
- Arnold Skydome lighting;
- 3ds Max Environment HDRI mode;
- persistent Tool-owned HDRI BitmapTexture management;
- Physical Camera creation;
- complete studio construction.


The backend receives selected nodes and all UI parameters explicitly. It does not read rollout controls.


## Arnold light types


Current MAXtoA generic Arnold Light values used by the Tool:
- `shapeType:2` — Spot;
- `shapeType:6` — Skydome.


## HDRI


Supported extensions:
- `.hdr`
- `.exr`


The directory scan is non-recursive. The UI displays filenames while retaining full paths internally.


### Shared HDRI map instance


Render Studio owns one `BitmapTexture` named `STUDIO_HDRI`.


```text
selected HDRI file
    -> STUDIO_HDRI.filename
    -> Material Editor slot 1
    -> Dome Light and/or Environment
```


Material Editor slot 1 is the canonical HDRI map owner. Render Studio first creates or updates `STUDIO_HDRI` in `meditMaterials[1]`, then Dome mode assigns `STUDIO_Sky.texmap = meditMaterials[1]` and Environment mode assigns `environmentMap = meditMaterials[1]`. The lighting owner is therefore instanced directly from slot 1.


The selected map is refreshed on tool open, directory browse/refresh, HDRI list selection, and HDRI strength changes. HDRI-change status is intentionally short: `HDRI: <filename>`. The test changes `meditMaterials[1].filename` directly and verifies `STUDIO_Sky.texmap.filename` changes immediately.


### Dome rotation

The Dome Light has a 0-360 degree integer rotation slider with 1-degree steps. Rotation is applied around the dome Z axis.

`STUDIO_Sky` stores one user property named `RS_HDRI_ROTATIONS`. Its value is an array of `[normalized HDRI path, angle]` pairs. Switching HDRIs restores that HDRI's saved angle. Before studio rebuild deletes the dome, the table is captured and then restored onto the recreated dome.

### Dome Light mode


```text
STUDIO_HDRI
    -> STUDIO_Sky.texmap
    -> Arnold Skydome
```


The bitmap uses spherical environment mapping and the UI strength value through `RGB_Level`.


### Environment mode


```text
STUDIO_HDRI
    -> 3ds Max environmentMap
    -> Arnold implicit environment/skydome handling
```


Before Render Studio overrides the Environment Map, it captures the prior map and enabled state. Switching back to Dome/fallback restores the captured state during the same loaded Tool session.


### Viewport HDRI preview


The `VIEWPORT` toggle temporarily previews the same slot-1 `STUDIO_HDRI` through the active viewport's Environment background.


On:
- preserve the current global Environment map/use state when Render Studio Environment mode does not already own it;
- assign `environmentMap = meditMaterials[1]`;
- enable `useEnvironmentMap`;
- enable the active viewport's `Use Environment Background` source and background display.


Off:
- disable the viewport background display;
- restore the preserved Environment map/use state unless Render Studio Environment mode still owns the Environment;
- invalidate viewport backgrounds.


The preview state is runtime-only and is removed when the Render Studio dialog closes.


### Fallback


When HDRI is disabled or no path is supplied, create a weak neutral Arnold Skydome named `STUDIO_Sky`.


## Scene construction


The selected objects define the world-space bounds and overall scale.


Generated scene nodes:


```text
STUDIO_Floor
STUDIO_Backdrop
STUDIO_Key_Light
STUDIO_Key_Light.Target
STUDIO_Fill_Light
STUDIO_Fill_Light.Target
STUDIO_Sky
STUDIO_Camera
STUDIO_Camera.Target
```


Rebuild removes only these Tool-owned nodes.


### Materials


Optional subject material:
- Physical Material;
- neutral medium gray;
- non-metallic;
- moderate roughness;
- reflective enough for shape/HDRI readability.


Studio material:
- Physical Material;
- light neutral gray;
- rougher and less reflective than the subject.


### Key / fill


Key:
- Arnold Spot;
- warm;
- stronger;
- above/left relative to the generated camera-facing setup.


Fill:
- Arnold Spot;
- cooler;
- weaker;
- opposite side.


Both lights use explicit Target helper nodes rather than assuming MAXtoA auto-creates a target.


### Camera


Optional targeted Physical Camera:
- 36 mm film width;
- 70 mm focal length;
- f/8;
- DOF disabled;
- becomes the active viewport camera.


## UI


Native dialog title:


```text
Render Studio - v<global project version>
```


The top `tool title button` text is exactly:


```text
Render Studio
```


Dialog width is fixed at `288 px`. The native dialog is created with `#style_resizing`, `lockWidth:true`, and `lockHeight:false`, so the user can change its height while width remains fixed. Dialog position and height are persisted in `Render Studio.ini`. Because the current registered/floating CUI dialog shifts by `[6,29]` during registration, the entry file subtracts that measured correction before creation so the final registered screen position matches the saved position.


Persistent controls:
- HDRI directory;
- last selected HDRI path when still present;
- Use selected HDRI;
- HDRI mode (`Dome Light`, `Environment`);
- HDRI strength;
- Apply gray Physical Material;
- Create Physical Camera;
- temporary `VIEWPORT` HDRI preview toggle;
- dialog position;
- dialog height.


Primary setup action:


```text
SET UP ARNOLD STUDIO
```


The UI collects state, passes explicit values to `RenderStudio.setupStudio`, and displays the returned status message.


### Render action


A `.NET` button labeled `RENDER` sits directly below the studio setup button. It uses the standard dark .NET button style with orange text, is 32 px high, and calls `RenderStudio.renderCurrentFrame()`. Rendering uses the current production renderer and active camera/view.

`CLONE BUFFER` copies the last rendered bitmap and displays the copy in its own VFB window for comparison with subsequent renders.


## Error handling


Backend failures return `RenderStudioResult_v` with:
- `passed`;
- `message`.


Fatal failures are also printed to the Listener.


Routine validation is displayed in the UI status line rather than modal message boxes.


## Constraints


- Multiple selected objects are supported.
- Source geometry is never deleted by rebuild.
- Material assignment is optional.
- HDRI scanning is non-recursive.
- Studio geometry currently uses a hard floor/backdrop corner.
- Render output defaults to 1024 × 1024.
- Existing unrelated scene nodes are not removed.
- Environment mode intentionally overrides the global Environment Map while active; the prior state is captured for restoration when switching away during the same loaded Tool session.