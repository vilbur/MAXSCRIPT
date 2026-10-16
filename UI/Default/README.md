# Default MaxScript UI Framework

This folder contains reusable frontend-only helpers and a template for MaxScript tools.

## Purpose

Keep frontend UI concerns separate from feature and geometry-processing code.

Dependency direction:

```text
Feature UI
├─> feature module public functions
└─> shared UI helpers

Feature module
└─> functional/shared non-UI utilities
```

Feature modules must not depend on rollouts, controls, dialog state, or INI UI persistence.

## Files

- `IniSettings.ms` — generic typed INI read/write helpers.
- `RolloutState.ms` — persistence helpers for common rollout controls.
- `DialogHost.ms` — floating-dialog position and vertical-size persistence.
- `ScriptReload.ms` — generic reload helper that prefers a newer matching versioned script.
- `ToolTitleButton.ms` — canonical reusable `tool title button` styling plus the global `restartTool` helper.
- `Default-UI-Template.ms` — frontend-only rollout template showing how the pieces connect.

## Mandatory first-version baseline

Use this framework from the **first runnable UI version** of every new MaxScript tool UI. It is not a final cleanup or polish pass.

Start new UI work from `Default-UI-Template.ms`. From the first version, a standalone tool dialog or owning rollout includes:

- the canonical `.NET tool title button` at the top of the UI, with font size derived from its current height as `button.height - 4`;
- LMB restart through `restartTool`;
- INI persistence for relevant control values, modes, and options;
- one stable, unversioned INI stored beside the owning/main `.ms` script by default;
- remembered dialog position and supported size state through `DialogHost.ms`;
- the shared 12 px sizing/layout defaults from `maxscript-ui-rules.md`.

Embedded child/subrollouts inside one owning dialog do not repeat the tool title button. They still follow the shared layout/state rules and persist their own relevant state. A rollout that is launched as its own dialog receives the full baseline.

Do not create a minimal UI first and plan to retrofit these defaults later. Omit a baseline feature only when the project/user explicitly requires an exception.

## Usage

Load the shared helper files from their canonical location. Do not copy their implementation into every tool.

By default, resolve the tool INI from the owning/main script path and save it in that same folder. Versioned entry scripts share one stable unversioned INI filename. Do not fall back to `#userScripts` or another global folder unless the project explicitly overrides the default.

Load `ScriptReload.ms` before `ToolTitleButton.ms`. The `tool title button` belongs at the top of the owning UI, uses the tool/dialog name only as its label, and its LMB action calls `restartTool`.

Keep project-specific processing in separate feature modules. UI event handlers should gather UI values, call a public feature function, and update displayed state only.

The production UI should be replaceable by a test rollout, macroscript, or direct Listener call without changing the functional module.

The shared framework belongs to the frontend layer only. It must not become a dependency of feature-processing modules.
