/* Compare native MAXScript spinner placement in a standalone dialog. */
try (destroyDialog spinner_layout_test) catch ()

rollout spinner_layout_test "Spinner Layout Test v0.04"
(
    label alignment_left "align:#left" across:3 align:#left
    label alignment_center "align:#center" align:#center
    label alignment_right "align:#right" align:#right

    spinner spinner_left "Spinner 01" across:3 align:#left width:88 fieldwidth:36 type:#float range:[0,100,1]
    spinner spinner_center "Spinner 02" align:#center width:88 fieldwidth:36 type:#float range:[0,100,1]
    spinner spinner_right "Spinner 03" align:#right width:88 fieldwidth:36 type:#float range:[0,100,1]

    label offset_zero_label "offset:[0,0]" across:3 align:#left
    label offset_middle_label "offset:[12,0]" align:#left
    label offset_shift_label "offset:[24,0]" align:#left

    spinner spinner_offset_zero "Spinner 04" across:3 align:#left offset:[0,0] width:88 fieldwidth:36 type:#float range:[0,100,1]
    spinner spinner_offset_middle "Spinner 05" align:#left offset:[12,0] width:88 fieldwidth:36 type:#float range:[0,100,1]
    spinner spinner_offset_shift "Spinner 06" align:#left offset:[24,0] width:88 fieldwidth:36 type:#float range:[0,100,1]

    label fixed_row_label "Fixed pos: spinner + unit label" pos:[12,112]
    spinner spinner_ratio "Spinner 07" pos:[12,134] width:88 fieldwidth:36 type:#float range:[0,100,1]
    label ratio_right_label "mm" pos:[106,136] width:24
)

createDialog spinner_layout_test 384 166
