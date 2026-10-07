# Loop-Cleaner Known Issues

## BROKEN T DIVIDE: later target-edge IDs can become stale after an earlier group splits

Status: open; `1.189` is the semi-stable reference point.

Runtime on `BLOCK-A-MATERIAL001` with `postion preccision = 1mm` shows that the first original target-edge group can complete its full split sequence: 5 vertices were inserted and 5 move pairs were stored. The following group then failed before its first split because stored target edge ID `138` was no longer live (`liveEdgeCount:0`), even though its preserved endpoint vertex IDs were `14` and `86`.

The current failure is therefore not the native `DivideEdge` operation itself. Earlier committed splits can invalidate the original edge ID cached for a later independent target group. Future work must re-resolve each not-yet-started group against the current live Edit Poly topology after previous groups have finished, without losing the proven 1.189 split behavior inside a group.

## T BORDER can miss a T junction at the end of a degenerate inner border

Status: open.

`T BORDER` reliably finds the perpendicular T-stem for the same broken inner-border pattern when the T junction is in the middle of the degenerate border run, but it can still miss the equivalent T junction when it lies on the last edge/end of that broken run.

Current `BLOCK-A-MATERIAL001` diagnostic example: expected T-stem edges `113` and `128` can be missed while comparable middle/run cases such as `122`, `232`, and `236` are found. These IDs are diagnostic for that scene only and must never be hard-coded into production detection.

The intended behavior is still: select the perpendicular T-stem for every T junction that terminates on a broken/degenerate inner border, including the first/last edge of that broken border run.
