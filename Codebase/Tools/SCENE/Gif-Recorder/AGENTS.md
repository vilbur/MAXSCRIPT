# GIF Recorder project instructions

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
