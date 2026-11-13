# Changes


## 2026-10-06 — 0.02


- Changed the primary preset action to `RESAVE \ REMOVE`.
- LMB resaves the selected preset directly; with `<Preset>` selected it creates a new preset.
- Added `NEW \ RENAME`: LMB always creates a new preset and RMB renames the selected preset.
- Rename starts with the current preset name and refuses to overwrite a different existing preset.
- Extended self-test coverage to include Operation and Tool rename workflows.


## 2026-10-06 — 0.01


- Added the standalone `Preset-Manager` DEV sandbox Tool.
- Added a neutral preset dropdown plus `SAVE \\ REMOVE` interaction.
- Added sample checkbox, spinner, mode, and text values to exercise generic preset storage.
- Added `RUN SELF TEST` covering save, list, load, overwrite, validation, wrapper decode, remove, and cleanup.
- Uses the shared Default UI helpers, dockable dialog host, restart title button, and INI-backed UI persistence.