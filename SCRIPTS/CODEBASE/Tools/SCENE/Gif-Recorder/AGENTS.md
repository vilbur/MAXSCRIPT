# GIF Recorder project instructions

## CODEBASE SOURCE-FORK RULE — NO RUNTIME DEPENDENCY

- The shared Codebase is a canonical **source/reference library**, not a runtime dependency location for downstream tools.
- Before implementing equivalent behavior, inspect the relevant Codebase Function, Operation, Tool, or Toolset and use the verified implementation as the starting source.
- When a new or downstream tool uses Codebase behavior, copy/fork the required implementation into that tool's own project files and version. The fork becomes tool-owned source for that tool version.
- Never create a runtime dependency from a downstream tool to the shared Codebase. Do not `fileIn`, import, load, search for, or reference an absolute/relative Codebase path at runtime.
- A delivered tool must continue to run when the shared Codebase folder is unavailable.
- Fork only the minimum required source and its required lower-level behavior. Preserve verified contracts where practical, then adapt the tool-local fork when project-specific behavior is needed.
- Codebase changes do not automatically propagate into existing tools. Updating a tool from newer Codebase source is an explicit, reviewed source-sync/fork operation.
- Promote a generally useful fix back into the canonical Codebase only when the current user prompt explicitly authorizes that protected Codebase change.
- The `Functions -> Operations -> Tools -> Toolsets` hierarchy remains the Codebase's source-organization model. References to lower-layer calls/dependencies inside Codebase documentation describe logical composition; downstream deliverables must vendor/fork the required source locally rather than depend on the central Codebase at runtime.

Follow the shared MaxScript `AGENTS.md` and all relevant shared rules in the parent MaxScript agent repository before changing this project.

## Product contract

- The tool documents modelling/workflow stages by capturing PNG frames from one dedicated camera named `GIF_RECORDER_CAMERA`.
- The camera is the source of truth for view position, orientation, FOV, and projection.
- `Perspective` checked means perspective projection. Unchecked means orthographic projection.
- A camera preset must persist outside the `.max` scene so the same view can be recreated in other scenes.
- Captured images live below the saved scene in `Gif-Recorder\<scene-name>\`.
- Output frame dimensions are explicit and independent from the physical viewport dimensions.
- The UI width is fixed at 288 px. Only vertical resizing is allowed.
- The preview is above the frame list.
- The frame list uses a .NET `DataGridView` because each frame has an editable delay dropdown.
- Supported frame delays are exactly `0.25` through `3.00` seconds in `0.25` second steps. The default is `0.50` seconds.
- Multiple selected frames can receive one delay value together.
- Frames can be captured, refreshed, reordered, deleted, previewed, and assembled into an animated GIF.
- GIF assembly uses `lib\ffmpeg.exe`.
- When FFmpeg is missing, the tool may download and extract the configured Windows FFmpeg build automatically on first GIF build.
- Do not silently change frame timing, camera projection, capture dimensions, or frame order.

## Version baseline

Initial project version: `0.001`.
