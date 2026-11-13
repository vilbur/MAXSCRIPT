# Color Palette — Changes




2026-10-23 — Project v0.005
- `ColorPaletteService.ms` v0.004: use MAXScript `BooleanClass` when validating each palette entry; include transparency class in error logs. Fixes false invalid-palette rejection.
- `ColorPaletteService-Test.ms` v0.004: add BooleanClass and canonical INI regression (part 8); replace obsolete fixed-color assertions with live INI consistency tests (part 6).
- `Color-Palette-Editor-Test.ms` v0.004: synchronize dialog title with project version 0.005; no data or UI logic changed.
- `ColorPalette.ini` unchanged; ID/color data preserved.


2026-10-23 — Project v0.006
- Renamed Color-Palette-Editor-Test.ms to Color-Palette-Editor.ms (file v0.005), preserving its Drive ID.
- Dialog height now fits all rows where screen space permits and removes the list scrollbar; compact rows are chosen for shorter screens.
- Filled 12 vacant IDs (8, 12, 17, 19, 20, 24–30) with distinct pastels; retained the original 25 palette entries (37 total).
- Updated ColorPaletteService.ms v0.005 to persist data Version 0.006 on Save.
2026-10-23 — Project v0.007
- `Color-Palette-Editor.ms` v0.006: persist the Point2 from the MAXScript `moved` event to `Color-Palette-Editor.ini` (`Dialog/PosX`, `Dialog/PosY`), then restore it through the existing shared `DialogHost` helper.
- Save dialog height before restart or close, without re-reading position while the window is being destroyed. Existing 37 palette entries and `ColorPalette.ini` unchanged.
2026-10-23 — Project v0.008
- `Color-Palette-Editor.ms` v0.007: explicitly bind shared `ColorPaletteService` as global before defining editor functions; use global-qualified service method calls so `getEntries` cannot resolve to an implicit local `undefined`.
- Validate service initialization immediately after `fileIn`, with the dependency filename in the failure message. No palette data, core service, or dialog position settings changed.
2026-10-23 — Project v0.009
- `Color-Palette-Editor.ms` v0.008: correct .NET DataGridView.ScrollBars enum class from nonexistent `System.Windows.Forms.DataGridViewScrollBars` to `System.Windows.Forms.ScrollBars` while retaining None/Vertical automatic behavior.
- `ColorPalette.ini`, shared color service, and dialog-position settings unchanged. Runtime test pending.