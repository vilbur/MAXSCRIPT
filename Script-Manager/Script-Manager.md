# Script-Manager

`Script-Manager/Script-Manager.ms` is the shared generic MaxScript loader and optional rollout host for the MaxScript agent tree.

It is not owned by EPolyTools. When the package lives directly below the shared MaxScript agent root, that parent directory becomes the managed root.

## Version

Production uses one synchronized release number everywhere:

- file version: `1.153`
- project version: `1.153`
- loader dialog title: `Script-Manager 1.153`
- generated host-dialog titles: `<Parent Folder>`
- visible loader version is shown in the main dialog title; the redundant top info/version labels are removed

The production snapshot for this release is `Script-Manager_1.153.ms`.

**Stable MVP baseline:** `1.149`. Version 1.149 is the latest user-confirmed stable baseline. Versions 1.150 through 1.153 are development candidates until explicitly confirmed stable.

## Purpose

Script-Manager manages which parts of the shared MaxScript tree are scanned and which scripts are loaded.

Supported script types are `.ms`, `.mcr`, and `.mse`.

The loader has two TreeViews:

- `SOURCES` — an organizational directory tree below the managed root. A persisted `IGNORE:` edit field above the tree filters directory names before they are added or traversed; the default mask is `.git`. Masks are pipe-separated, case-insensitive regular-expression patterns, with plain names matched literally and `*` accepted as wildcard shorthand (for example `.git|.*-DELETED|*-OLD|`). Press ENTER to apply the edited mask. A directory becomes a display-only hierarchy stopper when it contains an unversioned `.ms` file whose basename exactly matches the directory name, for example `script-name\script-name.ms`, or when the directory is completely empty. Stopper rows stay visible, have no checkbox at any nesting depth, and do not show children. Other directories remain selectable recursive sources with the existing checkbox glyph style. SOURCES reserves image slot 0 as a transparent row image so stopper rows remain visually checkbox-free. The managed root itself is not shown as a redundant source item.
- `SCRIPTS` — scripts found under the checked sources. Script leaves use a persisted tri-state load mode. `LOAD SCRIPTS` LMB performs a soft update and RMB performs a full hard reload.

For display only, `SCRIPTS` flattens redundant terminal tool folders. When a folder has exactly one visible script, has no visible descendant scripts, and that script basename matches the folder name, the folder node is omitted and the script leaf is shown directly in the parent. For example, `Loop Tools > Remove-Verts > Remove-Verts.ms` is displayed as `Loop Tools > Remove-Verts.ms`. The real script path, persisted load mode, and HOST/DIRECT behavior are unchanged.

The loader UI uses two independent collapsible rollouts:

- the main dialog header contains `REFRESH \ RESTART`; LMB refreshes discovery and RMB restarts/version-reloads Script-Manager;
- `SOURCES` contains the `IGNORE:` edit field plus the SOURCES TreeView;
- `SCRIPTS` contains `LOAD SCRIPTS`, both script filters on one row, the named preset controls, and the SCRIPTS TreeView.

The duplicate `SOURCES` / `SCRIPTS` labels above the TreeViews were removed because the rollout titles provide the section names. Each rollout's expanded/collapsed state is stored independently in `script_manager.ini`.

Source checkbox states and script tri-state modes are stored in `script_manager.ini`. Filter states, the SOURCES ignore mask, TreeView expanded/collapsed states, rollout states, dialog geometry, and dock states are also persisted there. If both a parent source and one of its descendants are checked, the descendant is not scanned a second time because the parent already covers that subtree.

When a previously checked hierarchy-stopper folder becomes a display-only no-checkbox row in `SOURCES`, Script-Manager migrates that checked state to its visible selectable parent and clears the stopper-folder source setting. Stopper classification is content-based: `FolderName\FolderName.ms` ends SOURCES hierarchy traversal at `FolderName`, even when helper files or child directories exist below that tool folder. A completely empty directory is also display-only/no-checkbox. A non-empty leaf folder without a same-name `.ms` file remains a selectable source.

A checked SOURCES item can also explicitly define a batch dialog. The first checked ancestor is discovery-only and is ignored for batch ownership; the second checked ancestor owns the complete batch subtree. RMB on that explicit checked dialog item shows `LOAD \ RELOAD DIALOG`, which loads or hard reloads only configured HOST scripts assigned to that one batch dialog. DIRECT and skipped scripts, other batch dialogs, and the first checked discovery source are not affected.


## Hosted tool dialogs

The loader stays in the single `Script-Manager` dialog. Loaded tool UI is no longer routed through one central `Loaded Scripts` dialog.

For a script discovered in a tool folder, Script-Manager uses the tool folder's immediate parent path as the organizational host path. All tool folders that share that parent therefore share one dialog.

Example:

```text
Wall Tools/
├─ Wall-Cleaner/
│  └─ Wall-Cleaner.ms
└─ Wall-Thickness/
   └─ Wall-Thickness.ms
```

creates one `Wall Tools` dialog. The declared rollout from `Wall-Cleaner` and the declared rollout from `Wall-Thickness` are added directly to that dialog's single subrollout slot. No generated intermediate category rollout exists between the dialog and the tool rollout.

Host dialogs are created lazily only when a successfully executed script exposes at least one rollout. Scripts without UI do not create empty dialogs. Failed embedding removes any newly empty host dialog.

Every organizational host dialog persists its own floating position, height, and left/right dock state in `script_manager.ini`. Tool rollout open/closed state remains persisted as well.

Host dialogs use a fixed 336 px dialog width with a 312 px content width, leaving enough room for the standard 288 px tool rollout plus native borders/scrollbar allowance.

Before an embedded HOST load redefines a script's rollout globals, Script-Manager closes any already-open standalone rollout instances resolved from the script source declarations or runtime registry. This prevents an old standalone window from surviving beside the newly embedded rollout after a batch load/reload.

Each generated host dialog has a full-width .NET button above the tool subrollout. Production host dialogs intentionally omit the Script-Manager version from both the native dialog caption and this button label; both show only the organizational parent-folder name. The button is flat and borderless, keeps the dark host background, and uses light-blue text `RGB 62,158,255`. LMB reloads only the HOST-mode scripts currently represented by that dialog; other host dialogs and DIRECT scripts are left untouched.
## Version filtering

`SHOW VERSIONED FILES` is off by default.

With the filter off, files in each directory are grouped by filename family:

- when an unversioned canonical file exists, only that file is shown;
- when no unversioned file exists, only the highest numeric `_version` file is shown;
- older versioned files stay hidden.

Example:

```text
Tool.ms
Tool_0.01.ms
Tool_0.02.ms
Only_0.01.ms
Only_0.03.ms
```

Default visible result:

```text
Tool.ms
Only_0.03.ms
```

Enable `SHOW VERSIONED FILES` to expose all versions.

`CLEAN SCRIPTS ONLY` is a second persisted filter. When enabled it takes priority over the version filter and keeps only an unversioned script whose basename exactly matches its parent folder name, for example `MyTool\MyTool.ms`. Helper files, versioned files, UI companions, debug/test files, and other differently named scripts are hidden from this clean view.

For `.ms` files, an optional sibling `<ScriptName>-UI.ms` companion is loaded automatically when present. Paired UI companions stay hidden as separate manual-load targets.

## Tree layout and ordering

The `SOURCES` TreeView has a fixed working height of 512 px for clearer source-tree navigation.

The `SCRIPTS` TreeView has a minimum working height of 1032 px so large source sets can remain visible with much less scrolling. The floating manager dialog opens tall enough to expose both tree viewports by default.

Inside each script folder, visible script files are ordered by filesystem last-write time with the newest files at the top. Folder hierarchy ordering remains alphabetical.

HOST script-file items are color-coded by their resolved batch dialog so scripts assigned to the same dialog share one color. DIRECT/standalone items use orange `RGB 255,165,60`; skipped files and folders keep the standard dark-UI foreground color.

`.ms` script leaves use three always-visible checkbox glyphs drawn by Script-Manager instead of the Windows themed checkbox renderer:

- empty box — do not load;
- checked box — load in embedded mode and add declared rollouts to the shared parent-folder dialog;
- box with `-` — load only the selected script in standalone mode and run it normally without adding its rollouts to a shared dialog.

The glyph is rendered through the TreeView image column so it remains visible in 3ds Max dark UI.

Legacy INI values remain compatible: `0`/missing means unchecked, `1` means checked/hosted, and the new direct mode is stored as `2`.

RMB behavior is context-sensitive. Folder items keep the tree navigation commands (`EXPAND`, `COLLAPSE`, `EXPAND ALL`, `COLLAPSE ALL`). A script leaf instead shows `LOAD SCRIPT`. This command force-runs only the selected script in standalone/direct mode regardless of its saved OFF/HOST/DIRECT mode or current-running state. It never embeds the script or its rollout into a Script-Manager batch/host dialog, never host-loads an optional `-UI.ms` companion, does not clear or rebuild existing batch dialogs, and leaves the saved tri-state mode unchanged. Manual or menu-driven expansion state is stored in `script_manager.ini` and restored when the loader is rebuilt.

## Loading behavior

`RELOAD` is discovery-only:

1. restores `SHOW VERSIONED FILES` and `CLEAN SCRIPTS ONLY` from `script_manager.ini`;
2. reads checked `SOURCES`;
3. scans only those source trees using the restored filter state;
4. rebuilds the `SCRIPTS` tree;
5. restores the persisted tri-state display;
6. does not execute discovered scripts.

The same filter restore happens during initial dialog creation, so the first `SCRIPTS` tree already matches the saved INI filter settings without requiring a manual filter toggle or extra reload.

`LOAD SCRIPTS` has two related load modes on one button.

LMB performs a soft update of the configured scripts:

1. skips unchecked scripts;
2. checks whether each configured script is actually running before executing it;
3. first treats an open standalone rollout/dialog owned by the script as running;
4. then treats a live Script-Manager HOST/batch dialog containing that script as running;
5. for scripts with no detectable UI, treats one successful load in the current manager session as running;
6. loads only scripts that are not currently running.

This means closing a standalone tool dialog makes only that tool eligible for the next soft update. Closing one HOST/batch dialog similarly makes only scripts represented by that closed host eligible for recovery. Scripts whose dialogs/hosts are still live are not re-executed.

RMB performs the hard reload behavior:

1. clears manager-hosted rollouts/dialogs from the previous hosted load set;
2. skips unchecked scripts;
3. re-executes every configured HOST/DIRECT script regardless of current running state;
4. recreates required organizational host dialogs and embeds exposed rollouts.

Changing a script state updates only the persistent load mode. It does not immediately execute the script. `LOAD SCRIPTS` LMB applies it softly; RMB forces a complete reload.

LMB on a script row only selects it. LMB on its checkbox glyph cycles the persisted load mode. RMB `LOAD SCRIPT` on a script leaf is a forced direct execution path: it re-runs that script immediately, bypasses batch hosting, and does not change the persisted checkbox mode.

A script with no rollout is still a successful load when `fileIn` succeeds, but it does not create an empty host dialog. Soft update remembers that no-UI script as loaded for the current Script-Manager session so it is not executed repeatedly.

## Refresh / Load Scripts / Restart

The loader exposes these primary actions:

- `REFRESH \ RESTART` in the main dialog header — `LMB` rescans selected sources and rebuilds the loader trees without executing scripts.
- `REFRESH \ RESTART` — `RMB` restarts Script-Manager by loading the newest numeric `Script-Manager_*.ms` release when available, otherwise reloads the currently running source.
- `LOAD SCRIPTS` in the `SCRIPTS` rollout — `LMB` soft-updates only configured scripts that are not currently running.
- `LOAD SCRIPTS` — `RMB` hard-reloads every configured script, rebuilding manager-hosted UI as needed.

F1 still performs the same restart action.

Restart uses quiet `fileIn` loading.

## Listener output

Normal discovery, reload stages, successful script loads, source paths, and per-file scan messages are quiet by default because heavy Listener output significantly slows large scans.

Detailed success tracing remains behind the internal `debug_logging` flag. Errors continue to report normally.

## Runtime modes

The generic runtime modes are:

- `#standalone`
- `#library`
- `#embedded`

The generic globals are:

```maxscript
global SCRIPT_MANAGER_RUNTIME_MODE
global SCRIPT_MANAGER_REGISTRY
global script_manager_project_version
global ScriptManagerIntegration
```

Existing EPoly tools remain compatible through the `EPolyToolsIntegration` and `EPOLY_TOOLS_RUNTIME_MODE` compatibility aliases.

## Package

```text
Maxscript/
├─ Script-Manager/
│  ├─ Script-Manager.ms
│  ├─ Script-Manager_1.153.ms
│  ├─ Script-Manager.md
│  ├─ changes.md
│  └─ tests/
│     ├─ Script-Manager-test.ms
│     └─ Script-Manager-test_1.139.ms
├─ Epoly/
├─ Modules/
├─ UI/
└─ ...
```

The canonical regression test is `tests/Script-Manager-test.ms`. This release advances its internal file version to `1.152`, stores project version `1.153`, and creates no new versioned test snapshot; the existing `Script-Manager-test_1.139.ms` snapshot remains unchanged.

## Safety

- Unchecked source trees are not recursively scanned.
- Display-only `SOURCES` tool-directory rows have no checkbox and are never treated as selectable source roots.
- Script discovery does not execute files by itself.
- Runtime rollout/dialog titles are resolved before declaration and are never mutated after creation.
- Load failures remain failures.
- Failed rollout embedding is never recorded as a loaded script.
- Script-Manager does not prune unrelated entries from the shared registry.
- Generic and EPoly compatibility runtime modes are restored after managed loads.
- Soft update checks live standalone/host dialog state instead of trusting only a historical loaded flag.
- Scripts with detectable UI are eligible for recovery when that UI is closed; no-UI scripts are executed only once per manager session unless a hard reload is requested.
