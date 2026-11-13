# Main-Toolbar-Extended 0.001

Single 3ds Max CUI toolbar providing 27 mutually-aware transform/snap controls. Its toolbar action states use native MAXScript `on isChecked do` callbacks; snap target buttons use real Standard Snaps settings.

## Requirements

- 3ds Max **2026 or later** (the `snapMode.angleSnapActive` property is documented in 2026).
- Evaluated **canonical** `Toolbar-Creator.ms` from the shared MaxScript Functions codebase. This tool **does not change** that source.
- All files in this directory, including `Actions` and `Icons`.

## Install

1. Back up your active CUIX using 3ds Max's UI customization tools.
2. Load the existing canonical `Toolbar-Creator.ms` into 3ds Max via `fileIn @"C:\your-codebase\...\Toolbar-Creator.ms"`.
3. Evaluate `Main-Toolbar-Extended.ms` (from its actual saved location).
4. The new `Main-Toolbar-Extended` toolbar is created as a native dockable toolbar. Dock next to the Main Toolbar.
5. Rerun with `installMainToolbarExtended operation:#update` only after the tool is loaded again and an update is necessary; Creator will replace the toolbar configuration.

The installer uses Toolbar-Creator's `#create` operation and upgrades its generated MacroScript source in `#userMacros\Main-Toolbar-Extended.mcr` so native macro buttons can report checked/unchecked state. Lightweight SVG icons are placed beneath both `#userIcons\Dark` and `#userIcons\Light`.

## Actions

- Centers: Pivot, Selection, Transform Coordinate Center.
- Coordinates: View, World, Local, Gimbal, Parent, Pick Object, Constant Reference System.
- Axis constraints: X, Y, Z, XY, YZ, ZX.
- Snaps: main toggle, 2D, 2.5D, 3D, Grid Points, Vertex, Pivot, Midpoint, Bounding Box, Center Face, Angle Snap.

Multiple positional snap targets may be checked simultaneously. Other groups use native mutually-exclusive state. The icons are placeholders; all Snap buttons are icon-only.

**Limitations:** Live 3ds Max runtime testing is still required. Native Max CUI behavior, icon theme lookup, and macro re-registration after toolbar creation should be confirmed on the target machine. The icon loading may need 3ds Max restart after first install. The current `Pick Object` button shows pressed state only when the reference system points to a live picked node.

## Test

Evaluate `Main-Toolbar-Extended-Test.ms`. It validates one state transition in each group, restoring all changed native settings. The test does not create, delete, or move geometry.

## Uninstall

With canonical Toolbar-Creator loaded, call:

```maxscript
manageScriptToolbar #delete "Main-Toolbar-Extended" macro_file_path:((getDir #userMacros) + "\Main-Toolbar-Extended.mcr")
```

The generated user SVG icons can be removed manually from `#userIcons\[Dark|Light]\MainToolbarExtended`. Keep your CUIX backup until the toolbar has been tested.
