# Changes

## 2026-10-06

- `EPoly-Stack-Test.ms` / `EPoly-Stack-Test_1.25.ms`: separated the selected-vertex outward move into reusable `moveEditPolyVerticesOutwardByBBoxFraction(...)` logic.
- `MOVE SELECTED VERTS OUT` now moves selected vertices radially away from the live bounding-box center by 25% of the bounding box's largest dimension.
- Canonical and versioned release are both project/file version `1.25`.
