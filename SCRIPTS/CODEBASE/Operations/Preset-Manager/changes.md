# Changes


## 2026-10-06 — 0.02


- Added rollback-safe preset rename support.
- Rename refuses to overwrite a different existing preset.
- Rename preserves the old preset when creating the new section fails and removes the temporary new section if deleting the old section fails.


## 2026-10-06 — 0.01


- Added the reusable `Preset-Manager` Operation.
- Added named INI-backed preset namespaces with save, load, list, existence, overwrite, and remove operations.
- Preset payloads are generic string key/value pairs; the Operation contains no Tool-specific state or UI logic.
- Section replacement removes stale keys and restores the previous preset when a replacement write fails.