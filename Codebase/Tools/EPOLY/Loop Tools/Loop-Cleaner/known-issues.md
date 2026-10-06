# Loop-Cleaner Known Issues

## T BORDER can miss a T junction at the end of a degenerate inner border

Status: open.

`T BORDER` reliably finds the perpendicular T-stem for the same broken inner-border pattern when the T junction is in the middle of the degenerate border run, but it can still miss the equivalent T junction when it lies on the last edge/end of that broken run.

Current `BLOCK-A-MATERIAL001` diagnostic example: expected T-stem edges `113` and `128` can be missed while comparable middle/run cases such as `122`, `232`, and `236` are found. These IDs are diagnostic for that scene only and must never be hard-coded into production detection.

The intended behavior is still: select the perpendicular T-stem for every T junction that terminates on a broken/degenerate inner border, including the first/last edge of that broken border run.
