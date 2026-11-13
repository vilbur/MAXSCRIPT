/*
    WeldVerts.ms

    Welds selected Editable Poly or Edit Poly vertices using the threshold
    supplied to the function in millimeters. The routine intentionally does
    write the UI weld-threshold properties because those values can be stale.

    Return value:
        false - invalid input or unsupported node/modifier
        0+    - number of vertices removed
*/

fn weldSelectedEPolyVerts node threshold editPolyModifier:undefined =
(
    if node == undefined or not isValidNode node do return false
    if not isKindOf threshold Number or threshold <= 0 do return false

    local thresholdInSystemUnits = threshold * (units.decodeValue "1mm")

    local selectedModifier = editPolyModifier

    fn modifierBelongsToNode owner candidate =
    (
        for item in owner.modifiers where item == candidate do return true
        false
    )

    if selectedModifier != undefined then
    (
        if classOf selectedModifier != Edit_Poly do return false
        if not modifierBelongsToNode node selectedModifier do return false
    )
    else
    (
        for index = node.modifiers.count to 1 by -1 while selectedModifier == undefined do
        (
            if classOf node.modifiers[index] == Edit_Poly do
                selectedModifier = node.modifiers[index]
        )
    )

    local useEditPolyModifier = selectedModifier != undefined
    local editablePoly = undefined

    if not useEditPolyModifier then
    (
        if classOf node.baseObject != Editable_Poly do return false
        editablePoly = node.baseObject
    )

    else
    (
        -- Discard any pending UI operation before reading topology. In particular,
        -- committing a pending #WeldVertex operation would reuse the UI threshold
        -- and weld the complete selection instead of only the explicit pair.
        EditPolyMod.Cancel selectedModifier
    )

    fn getSelectedVertices owner modifier useModifier polyObject =
    (
        if useModifier then
            EditPolyMod.GetSelection modifier #Vertex node:owner
        else
            polyOp.getVertSelection polyObject
    )

    fn getWorldPositions owner useModifier polyObject =
    (
        local positions = #()

        if useModifier then
        (
            local evaluatedMesh = snapshotAsMesh owner

            for index = 1 to evaluatedMesh.numVerts do
                append positions ((getVert evaluatedMesh index) * owner.objectTransform)

            delete evaluatedMesh
        )
        else
        (
            local vertexCount = polyOp.getNumVerts polyObject

            for index = 1 to vertexCount do
                append positions ((polyOp.getVert polyObject index) * owner.objectTransform)
        )

        positions
    )

    fn getVertexCount owner useModifier polyObject =
    (
        if useModifier then
        (
            local evaluatedMesh = snapshotAsMesh owner
            local vertexCount = evaluatedMesh.numVerts
            delete evaluatedMesh
            vertexCount
        )
        else
        (
            polyOp.getNumVerts polyObject
        )
    )

    fn pairKey firstIndex secondIndex =
    (
        if firstIndex < secondIndex then
            ((firstIndex as string) + ":" + (secondIndex as string))
        else
            ((secondIndex as string) + ":" + (firstIndex as string))
    )

    fn findClosestPair selectedVertices positions blockedPairs thresholdValue keyFunction =
    (
        local vertexIndices = selectedVertices as array
        local closestPair = undefined
        local closestDistance = thresholdValue

        if vertexIndices.count < 2 do return undefined

        for first = 1 to vertexIndices.count - 1 do
        (
            for second = first + 1 to vertexIndices.count do
            (
                local firstIndex = vertexIndices[first]
                local secondIndex = vertexIndices[second]

                if firstIndex <= positions.count and secondIndex <= positions.count do
                (
                    local key = keyFunction firstIndex secondIndex

                    if findItem blockedPairs key == 0 do
                    (
                        local pairDistance = distance positions[firstIndex] positions[secondIndex]

                        if pairDistance <= thresholdValue and \
                            (closestPair == undefined or pairDistance < closestDistance) do
                        (
                            closestDistance = pairDistance
                            closestPair = #(firstIndex, secondIndex)
                        )
                    )
                )
            )
        )

        closestPair
    )

    local removedCount = 0
    local blockedPairs = #()
    local keepSearching = true

    undo "Weld Selected EPoly Vertices" on
    (
        with redraw off
        (
            while keepSearching do
            (
                local selectedVertices = getSelectedVertices node selectedModifier useEditPolyModifier editablePoly

                if selectedVertices.numberSet < 2 then
                (
                    keepSearching = false
                )
                else
                (
                    local positions = getWorldPositions node useEditPolyModifier editablePoly
                    local closestPair = findClosestPair selectedVertices positions blockedPairs thresholdInSystemUnits pairKey

                    if closestPair == undefined then
                    (
                        keepSearching = false
                    )
                    else
                    (
                        local beforeCount = getVertexCount node useEditPolyModifier editablePoly

                        if useEditPolyModifier then
                        (
                            EditPolyMod.WeldVertices selectedModifier closestPair[1] closestPair[2] node:node

                        )
                        else
                        (
                            local firstPosition = polyOp.getVert editablePoly closestPair[1]
                            local secondPosition = polyOp.getVert editablePoly closestPair[2]
                            local weldPosition = (firstPosition + secondPosition) / 2.0
                            local welded = polyOp.weldVerts editablePoly closestPair[1] closestPair[2] weldPosition

                            if welded == true do polyOp.collapseDeadStructs editablePoly
                        )

                        update node

                        local afterCount = getVertexCount node useEditPolyModifier editablePoly

                        if afterCount < beforeCount then
                        (
                            removedCount += beforeCount - afterCount
                            blockedPairs = #()
                        )
                        else
                        (
                            append blockedPairs (pairKey closestPair[1] closestPair[2])
                        )
                    )
                )
            )
        )
    )

    removedCount
)

