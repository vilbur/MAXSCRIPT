# Main-Toolbar-Extended design 0.001

## Goal
Expose common 3ds Max native Transform Center, Reference Coordinate, Axis Constraint, and Snap settings as immediate actions in a single dockable CUI toolbar.

## Reused dependency
`manageScriptToolbar` is the canonical shared toolbar creation function. It owns CUIX modification/backup, stable action-name generation, and persistence. This project consumes it without modifying or duplicating its implementation.

## Adapter
Toolbar-Creator currently accepts scripts only and emits non-checkable macros. The project installer submits distinct action `.ms` paths; after successful toolbar creation, it reads the macro names from the Creator-generated `.mcr` in order, then emits macros using the same identities with `on isChecked do` and `on execute do`. The resulting `.mcr` persists across 3ds Max restarts.

Source action `.ms` scripts are valid standalone native fallback actions. MacroScript checked-state getters read the actual native MAXScript state, not a separate cached UI variable. Every execute handler calls `updateToolbarButtons()`.

## Project ownership and layout
Only local Main-Toolbar-Extended action contracts and icons are owned here. No shared Function, Operation, or Toolset is edited. The shared creator's 40-pixel macro button width is retained; icons are 24-pixel SVG placeholders.

The repository root holds `Main-Toolbar-Extended.ms` as the unversioned canonical launcher, tests, agent rules, and documentation. Historical numbered scripts are stored in `versions/`. Action scripts live under `Actions/` and both icon themes under `Icons/`. Source code and assets are maintained as individual Drive files, not whole-repository ZIP archives.

`README.md` is restricted to the front-end user purpose and feature overview; architecture, dependencies, version/release details, and technical limitations belong in this file or `AGENTS.md`.

## Compatibility
Target 3ds Max 2026+. The UI has no custom rollout or dialog. Most handlers are valid across older versions; angleSnapActive is a 2026+ requirement. The Pick Object handler uses native `pickObject` + `toolMode.coordsys node`.

## Risks and verification
The CUIX adapter relies on Toolbar-Creator's documented ordered `.mcr` output format. The local package includes a safe native setting test. Actual UI behavior needs 3ds Max runtime validation: check states, icon resolution, icon-only presentation, and CUI persistence after restart. When re-running, choose `#update` explicitly rather than allowing implicit replacement.
