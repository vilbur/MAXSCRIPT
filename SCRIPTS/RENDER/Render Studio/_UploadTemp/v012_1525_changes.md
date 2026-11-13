# Render Studio Changes

## 2026-10-27 — v0.12


- Continued development from stable v0.11.
- Added a `VIEWPORT` toggle beside HDRI Strength.
- `VIEWPORT` ON temporarily assigns `meditMaterials[1]` to the global Environment map and enables the active viewport's `Use Environment Background` display.
- `VIEWPORT` OFF removes the preview and restores the previous Environment map/use state when Render Studio Environment mode does not own it.
- Viewport preview is runtime-only and is removed when the Render Studio dialog closes.
- Shortened HDRI-change status to `HDRI: <filename>`.
- Added viewport-preview backend/UI test coverage.



## 2026-10-27 — v0.11 — STABLE


- Corrected HDRI ownership direction: Material Editor slot 1 is now the canonical `STUDIO_HDRI` reference.
- Dome mode now assigns exactly `STUDIO_Sky.texmap = meditMaterials[1]`.
- Environment mode now assigns exactly `environmentMap = meditMaterials[1]`.
- Removed the reverse dome/environment-to-editor rebinding logic from v0.10.
- Tests use `meditMaterials[1]` directly and verify the dome shares that exact map instance.


## 2026-10-27 — v0.10


- Fixed Dome Light HDRI instancing by reading back `STUDIO_Sky.texmap` after assignment and placing that exact map reference into Material Editor slot 1.
- Applied the same readback-and-instance rule to Environment mode.
- Switched Material Editor access to `getMeditMaterial` / `setMeditMaterial`.
- Added explicit diagnostics if Material Editor slot 1 is not the same map reference as the active dome/environment map.
- Strengthened the Dome test: it changes `slot 1.filename` directly and verifies `STUDIO_Sky.texmap.filename` changes immediately, proving a shared map instance.


## 2026-10-27 — v0.09


- Explicitly enabled native vertical dialog resizing with `#style_resizing`.
- Kept dialog width locked at `288 px` while height remains unlocked.
- Existing resize/close handlers continue saving the current height and screen position to `Render Studio.ini`.
- Updated the persistence test to change the dialog height to `720 px`, save it, reopen the tool, and verify the changed height is restored.
- Corrected the canonical repository path to `G:\CODE\MAXSCRIPT\RENDER\Render Studio\` and the preferred relative shared-UI path for the moved repository.


## 2026-10-27 — v0.08


- Added a `.NET` `RENDER` button below the studio setup action.
- Styled the Render button with the standard dark button appearance and orange text (`RGB 255,165,0`).
- Added backend `RenderStudio.renderCurrentFrame()` so the UI callback stays thin.
- Increased the minimum persisted dialog height to `648 px` while keeping width locked at `288 px`.
- Added a non-rendering UI test for Render button text, color, size, and background.


## 2026-10-27 — v0.07


- Fixed registered-dialog position drift on reopen. The current 3ds Max/display setup adds a repeatable `[6,29]` CUI offset, so Render Studio now compensates before dialog registration.
- Added a dialog persistence test that verifies position and size remain unchanged across consecutive reloads.


## 2026-10-27 — v0.06


- Reduced the fixed dialog width to `288 px`; dialog position and vertically resizable height remain persisted in `Render Studio.ini` through `DialogHost`.
- Reworked HDRI handling around one persistent `STUDIO_HDRI` BitmapTexture.
- Instanced the active HDRI map into Material Editor slot 1.
- Dome Light and Environment modes now reuse the same Tool-owned map instance.
- Fixed stale dome HDRI files by updating `STUDIO_HDRI.filename` whenever the selected HDRI changes.
- Added immediate HDRI map refresh on tool open, directory browse/refresh, list selection, and strength changes.
- Expanded tests to verify Material Editor slot 1 shares the same map instance as the dome/environment and that changing HDRI updates the dome texture filename.


## 2026-10-27 — v0.05


- Refactored the monolithic prototype into the canonical Tool package: `Render Studio.ms`, `Render Studio-FN.ms`, and `Render Studio-UI.ms`.
- Added shared project/file version handling.
- Adopted the shared UI framework, tool title button, managed dialog, local INI state, dialog position/height persistence, and restart behavior.
- Preserved both HDRI application modes: Arnold Dome Light and 3ds Max Environment.
- Fixed MAXtoA generic light enum values: Spot `shapeType:2`, Skydome `shapeType:6`.
- Added explicit Arnold Spot target helpers instead of relying on auto-created targets.
- Added Environment override capture/restore to avoid discarding unrelated Environment state when switching away from Tool-owned Environment mode in the same session.
- Added a rules-compliant executable test workflow under `Tests/`.
- Updated local `AGENTS.md` and `design.md` for the renamed/moved repository.