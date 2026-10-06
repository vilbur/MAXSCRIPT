/*
Convert saved 1 mm System Units scene into a clean 1 meter System Units scene by Merge.
Uses the native Merge dialog so 3ds Max performs its documented unit rescaling.
*/
function convertSystemUnitsMmToMetersByMerge =
(
    source_ready = true
    source_file = ""
    source_size_mm = undefined
    source_object_count = 0

    if maxFileName == "" then
    (
        messageBox "Save the source scene first." title:"MM to Meters by Merge"
        source_ready = false
    )

    if source_ready and getSaveRequired() then
    (
        messageBox "Scene contains unsaved changes.\nSave it first, then run the conversion again." title:"MM to Meters by Merge"
        source_ready = false
    )

    if source_ready and ((units.SystemType != #millimeters) or (units.SystemScale != 1.0)) then
    (
        messageBox
            (
                "Expected source System Units:\n\n" +
                "1 Unit = 1 Millimeter\n\n" +
                "Current:\n" +
                (units.SystemScale as string) + " " +
                (units.SystemType as string)
            )
            title:"MM to Meters by Merge"

        source_ready = false
    )

    if source_ready then
    (
        source_file = maxFilePath + maxFileName
        source_object_count = objects.count

        if objects.count > 0 then
        (
            source_bounds = objects.boundingBox
            source_size_mm = source_bounds.max - source_bounds.min
        )

        continue_conversion = queryBox
            (
                "The current saved scene will be used as SOURCE.\n\n" +
                "3ds Max will reset to an empty scene and set:\n" +
                "System Units = 1 Meter\n" +
                "Display Units = centimeters\n\n" +
                "Then the source MAX file will be opened through Merge.\n\n" +
                "Continue?"
            )
            title:"MM to Meters by Merge"

        if continue_conversion then
        (
            resetMaxFile #noPrompt

            units.SystemScale = 1.0
            units.SystemType = #meters

            units.DisplayType = #custom
            units.CustomName = "cm"
            units.CustomValue = 0.01
            units.CustomUnit = #meters

            format "\n========================================\n"
            format "MM -> METERS | MERGE CONVERSION\n"
            format "========================================\n"
            format "Source: %\n" source_file
            format "Target System Units: 1 meter\n"
            format "Target Display Units: 1 cm\n"
            format "\n"
            format "IN THE MERGE DIALOG:\n"
            format "1. Select ALL objects.\n"
            format "2. KEEP 'Rescale Objects to System Unit Scale' ENABLED.\n"
            format "3. Merge.\n"
            format "========================================\n\n"

            merge_ok = mergeMAXFile source_file #prompt quiet:false

            if merge_ok then
            (
                redrawViews()

                format "\n========================================\n"
                format "MERGE FINISHED\n"
                format "========================================\n"
                format "System Scale:       %\n" units.SystemScale
                format "System Type:        %\n" units.SystemType
                format "Display Type:       %\n" units.DisplayType
                format "Merged objects:     %\n" objects.count
                format "Source objects:     %\n" source_object_count

                if (objects.count > 0) and (source_size_mm != undefined) then
                (
                    target_bounds = objects.boundingBox
                    target_size_m = target_bounds.max - target_bounds.min
                    expected_size_m = source_size_mm / 1000.0

                    format "\nSource size [mm]:   %\n" source_size_mm
                    format "Expected size [m]:  %\n" expected_size_m
                    format "Actual size [m]:    %\n" target_size_m
                )

                format "\nSAVE THIS RESULT UNDER A NEW FILE NAME.\n"
                format "========================================\n\n"
            )
            else
            (
                format "\nMerge cancelled or failed.\n"
            )
        )
    )

    -- return
)