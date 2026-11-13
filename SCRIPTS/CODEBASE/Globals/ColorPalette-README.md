# Shared Color Palette Service

**Canonical data:** `Codebase/Globals/ColorPalette.ini`  
**Reusable API:** `Codebase/Globals/ColorPaletteService.ms`  
**Editor:** `Codebase/Globals/Color-Palette-Editor.ms`  
**Tests:** `Codebase/Globals/ColorPaletteService-Test.ms`

Numeric palette **ID equals Material ID**. Each entry has `palette_id`, `name_text`, `color_value`, `description_text`, and `is_transparent`. IDs are unique and sorted, valid range **1–60000** for MAXScript Multi/Sub-Object material IDs. The 3ds Max Material Editor UI only permits manually entered IDs up to 1000. The canonical palette defines 37 entries (data version 0.006), including ID 99 as a transparency flag and ID 66 as a destructive-action red.

## Use from any other MaxScript tool

Load `ColorPaletteService.ms` **once** from the canonical shared path (through the owning project's dependency loader). It loads the sibling `ColorPalette.ini`. The service **never** opens UI or changes scene materials, unless a caller asks it to construct a new, unassigned material.

```maxscript
-- First load the real canonical service .ms file with the owning tool's loader.
local display_color = ColorPaletteService.getColorById 66
local entry_info = ColorPaletteService.getEntryById 99
local palette_entries = ColorPaletteService.getEntries()
local single_material = ColorPaletteService.createStandardMaterialById 66
local multi_material = ColorPaletteService.createMultiMaterial material_ids:#(1, 13, 33, 66, 99)
```

The service exposes `getEntries()`, `getEntryById(id)`, `getColorById(id)`, `getNameById(id)`, `findIdByName(name)`, `nextFreeId(entries)`, `parseId(string)`, `validateEntries(entries)`, `setEntries(entries)`, `save()`, `reload()`, `createStandardMaterialById(id)` and `createMultiMaterial material_ids:#()`.

Getters return copies rather than references to mutable service records. `setEntries` rejects duplicate or invalid IDs **before** replacing the in-memory palette. `save` persists to the single shared `ColorPalette.ini`; `reload` re-reads it and refuses invalid data. The editor saves its **UI position and layout settings** to `Color-Palette-Editor-Test.ini` but **all palette entries** to `ColorPalette.ini`.

`COLOR_NAMES.ms` is preserved as the original independent dictionary of **named RGB colors**. It is not the numeric-ID palette; do not use it as a substitute for the shared Material-ID service.

**Material semantics:** a transparent entry becomes a Standard Material with `opacity = 0.0`. This is a plain Standard Material convention for testing and interoperability, not a renderer-specific glass shader. Materials are created unassigned; callers decide whether to apply them to scene nodes.

**Migration caution:** The v0.001 test editor stored all its palette entries in `Color-Palette-Editor-Test.ini`. The current editor reads/writes colors exclusively via `ColorPalette.ini`. If you customized the legacy palette, migrate those palette entries into `ColorPalette.ini` before switching; do not overwrite your edited legacy INI. Editor window position and size are now stored in `Color-Palette-Editor.ini` and can be copied from the old UI INI automatically.

## Test

Run `ColorPaletteService-Test.ms` inside 3ds Max. It checks sorted unique IDs, defensive copies, invalid-input rejection, Standard/Multi material generation, and opacity on the transparent ID. The test does not assign any materials to scene objects. Static source checks do **not** replace a 3ds Max runtime test.

## Canonical material IDs — palette v0.006

IDs 1–30 are all assigned. For example, ID 1 is BRIGHT_GRAY (230,230,230), ID 2 is BLUE_GRAY (135,147,168), ID 6 is CYAN, ID 7 is YELLOW, ID 10 is BLACK, ID 11 is GREEN_LIGHT, ID 14 is BRIGHT_ORANGE, ID 16 is BROWN_DARK, ID 18 is VIOLET, and IDs 21–23 are the existing ice/neon accents. Twelve previously empty IDs received new distinct pastel colors. Existing IDs 31, 33, 45, 66, 99, 100 and 666 remain unchanged. The source of truth is `ColorPalette.ini`; `COLOR_NAMES.ms` is a separate named-color dictionary.

## Palette v0.006 / Editor resize

The shared palette now contains all material IDs 1 through 30, plus the pre-existing higher IDs. New IDs 8, 12, 17, 19, 20, and 24–30 use distinct pastel colors; existing entries are unchanged. The editor calculates its opening height from the number of rows and the current display work area, using compact row heights as needed; scrolling is enabled only if the window cannot fit all rows. The editor is renamed to `Color-Palette-Editor.ms` and saves UI settings in `Color-Palette-Editor.ini`, migrating its previous `-Test.ini` if one is present.
