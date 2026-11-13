# Corner Plane — Project Agent Instructions

This folder is the maintained Corner Plane plugin repository. Follow the shared MaxScript agent rules before modifying code:

https://drive.google.com/drive/folders/1RSsBtOAOPHmiT6SeVaYqhuvyqQZ36FFA

Read shared `AGENTS.md` first, followed by applicable syntax, protected-identifier, unit-precision, UI, project-settings, and architecture rules.

## Scope and source of truth

- Treat `Corner-Plane.ms` in this folder as the canonical launch/entry file; its basename must match the parent folder.
- Do not silently overwrite the code or replace it with an unrelated mesh implementation. Preserve the direct `extends:Plane` design unless explicitly changed by the user.
- Read the latest Drive file before changing it, preserve unrelated edits, and update the same canonical file ID.
- Preserve a separate versioned history file when releasing a new code version, incrementing the project version by the shared rules.
- Update `README.md`, `design.md`, and `changes.md` when the feature behavior/contract changes.
- Follow the shared read-only protections for `Functions/`, `Operations/`, `Tools/`, and `Toolsets/`; this folder does not grant permission to alter those shared assets.
- The plugin source is not considered runtime-verified until it has actually been executed and its tests checked in 3ds Max.

## Test

Run `Corner-Plane.ms` before `Corner-Plane-Test.ms` in a disposable 3ds Max scene. The test intentionally retains its final geometry and undo entries for visual inspection.
