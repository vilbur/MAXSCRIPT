/*
    Single-file interactive regression test for WeldVerts.ms.

    Stage queue:
      partOfTest1() - create Editable Poly and Edit Poly fixtures in the XY plane.
      partOfTest2() - select a pair 0.2 mm apart plus a vertex 1 mm away.
      partOfTest3() - weld with threshold 0.3 mm and verify only the near pair welded.

    Undo order after execution:
      1. Restore the Edit Poly weld.
      2. Restore the Editable Poly weld.
      3. Restore the selections.
      4. Restore the scene before test-object creation.
*/

global WeldVertsTestDirectory = getFilenamePath (getSourceFileName())
global WeldVertsTestRoutinePath = WeldVertsTestDirectory + "WeldVerts.ms"
global WeldVertsTestFailures = #()
global WeldVertsTestEditableNode = undefined
global WeldVertsTestModifierNode = undefined
global WeldVertsTestEditPolyModifier = undefined

if not doesFileExist WeldVertsTestRoutinePath do
    throw ("Missing routine: " + WeldVertsTestRoutinePath)

fileIn WeldVertsTestRoutinePath quiet:true

fn weldVertsTestAssert condition message =
(
    if not condition do append WeldVertsTestFailures message
)

fn weldVertsTestDeleteNamedObject objectName =
(
    local existing = getNodeByName objectName exact:true
    if isValidNode existing do delete existing
)

fn weldVertsTestCreateFixture objectName xyOffset =
(
    local nearDistance = units.decodeValue "0.2mm"
    local farDistance = units.decodeValue "1.0mm"
    local supportDistance = units.decodeValue "2.0mm"

    local fixture = mesh \
        name:objectName \
        vertices:#( \
            [0.0, 0.0, 0.0] + xyOffset, \
            [-supportDistance, 0.0, 0.0] + xyOffset, \
            [0.0, -supportDistance, 0.0] + xyOffset, \
            [nearDistance, 0.0, 0.0] + xyOffset, \
            [nearDistance + supportDistance, 0.0, 0.0] + xyOffset, \
            [nearDistance, -supportDistance, 0.0] + xyOffset, \
            [farDistance, 0.0, 0.0] + xyOffset, \
            [farDistance + supportDistance, 0.0, 0.0] + xyOffset, \
            [farDistance, -supportDistance, 0.0] + xyOffset) \
        faces:#([1, 2, 3], [4, 5, 6], [7, 8, 9])

    convertToPoly fixture
)

fn weldVertsTestEvaluatedVertexCount node =
(
    local evaluatedMesh = snapshotAsMesh node
    local vertexCount = evaluatedMesh.numVerts
    delete evaluatedMesh
    vertexCount
)

fn weldVertsTestHasVertexNear node expectedPosition tolerance =
(
    local evaluatedMesh = snapshotAsMesh node
    local found = false

    for index = 1 to evaluatedMesh.numVerts while not found do
    (
        if distance (getVert evaluatedMesh index) expectedPosition <= tolerance do
            found = true
    )

    delete evaluatedMesh
    found
)

fn weldVertsTestIsInXYPlane node =
(
    local evaluatedMesh = snapshotAsMesh node
    local isInPlane = true

    for index = 1 to evaluatedMesh.numVerts while isInPlane do
    (
        if abs (getVert evaluatedMesh index).z > 0.000001 do isInPlane = false
    )

    delete evaluatedMesh
    isInPlane
)

fn partOfTest1 =
(
    local editableName = "WV_TEST_EDITABLE_POLY"
    local modifierName = "WV_TEST_EDIT_POLY"

    undo "Create Weld Test Objects" on
    (
        weldVertsTestDeleteNamedObject editableName
        weldVertsTestDeleteNamedObject modifierName

        WeldVertsTestEditableNode = weldVertsTestCreateFixture editableName [0.0, 0.0, 0.0]
        WeldVertsTestEditableNode.wireColor = color 255 170 0
        WeldVertsTestEditableNode.weldThreshold = 100.0

        WeldVertsTestModifierNode = weldVertsTestCreateFixture modifierName [0.0, 4.0, 0.0]
        WeldVertsTestModifierNode.wireColor = color 0 170 255

        WeldVertsTestEditPolyModifier = Edit_Poly name:"WV_TEST_EDIT_POLY_MOD"
        addModifier WeldVertsTestModifierNode WeldVertsTestEditPolyModifier
        WeldVertsTestEditPolyModifier.weldVertexThreshold = 100.0

        select #(WeldVertsTestEditableNode, WeldVertsTestModifierNode)
    )

    weldVertsTestAssert (weldVertsTestIsInXYPlane WeldVertsTestEditableNode) \
        "Editable Poly fixture is not in the XY plane."
    weldVertsTestAssert (weldVertsTestIsInXYPlane WeldVertsTestModifierNode) \
        "Edit Poly fixture is not in the XY plane."
)

fn partOfTest2 =
(
    if not isValidNode WeldVertsTestEditableNode or not isValidNode WeldVertsTestModifierNode do
        throw "partOfTest1() must create the fixtures before partOfTest2()."

    undo "Select Weld Test Vertices" on
    (
        polyOp.setVertSelection WeldVertsTestEditableNode.baseObject #{1, 4, 7}

        select WeldVertsTestModifierNode
        max modify mode
        modPanel.setCurrentObject WeldVertsTestEditPolyModifier
        subObjectLevel = 1
        EditPolyMod.SetEPolySelLevel WeldVertsTestEditPolyModifier #Vertex

        local selectedVerts = #{1, 4, 7}
        selectedVerts.count = 9

        if not EditPolyMod.SetSelection WeldVertsTestEditPolyModifier #Vertex &selectedVerts node:WeldVertsTestModifierNode do
            throw "Could not set the Edit Poly vertex selection."

        EditPolyMod.SetOperation WeldVertsTestEditPolyModifier #WeldVertex
    )

    weldVertsTestAssert ((polyOp.getVertSelection WeldVertsTestEditableNode.baseObject) == #{1, 4, 7}) \
        "Editable Poly vertices 1, 4, and 7 were not selected."
    weldVertsTestAssert ((EditPolyMod.GetSelection WeldVertsTestEditPolyModifier #Vertex node:WeldVertsTestModifierNode) == #{1, 4, 7}) \
        "Edit Poly vertices 1, 4, and 7 were not selected."
)

fn partOfTest3 =
(
    local editableRemoved = weldSelectedEPolyVerts WeldVertsTestEditableNode 0.3
    local modifierRemoved = weldSelectedEPolyVerts WeldVertsTestModifierNode 0.3 editPolyModifier:WeldVertsTestEditPolyModifier
    local oneMillimeter = units.decodeValue "1.0mm"
    local testTolerance = units.decodeValue "0.001mm"

    weldVertsTestAssert (editableRemoved == 1) "Editable Poly did not remove exactly the 0.2 mm pair."
    weldVertsTestAssert (modifierRemoved == 1) "Edit Poly did not remove exactly the 0.2 mm pair."
    weldVertsTestAssert ((polyOp.getNumVerts WeldVertsTestEditableNode.baseObject) == 8) \
        "Editable Poly welded the selected vertex 1 mm away with threshold 0.3 mm."
    weldVertsTestAssert ((weldVertsTestEvaluatedVertexCount WeldVertsTestModifierNode) == 8) \
        "Edit Poly welded the selected vertex 1 mm away with threshold 0.3 mm."
    weldVertsTestAssert (weldVertsTestHasVertexNear WeldVertsTestEditableNode [oneMillimeter, 0.0, 0.0] testTolerance) \
        "Editable Poly lost the selected vertex 1 mm away."
    weldVertsTestAssert (weldVertsTestHasVertexNear WeldVertsTestModifierNode [oneMillimeter, 4.0, 0.0] testTolerance) \
        "Edit Poly lost the selected vertex 1 mm away."
    weldVertsTestAssert (WeldVertsTestEditableNode.weldThreshold == 100.0) \
        "Editable Poly cached UI threshold changed."
    weldVertsTestAssert (WeldVertsTestEditPolyModifier.weldVertexThreshold == 100.0) \
        "Edit Poly cached UI threshold changed."

    redrawViews()

    if WeldVertsTestFailures.count > 0 then
    (
        format "WeldVerts test: % failure(s).\n" WeldVertsTestFailures.count
        for failure in WeldVertsTestFailures do format "FAIL: %\n" failure
        throw ("WeldVerts test failed: " + (WeldVertsTestFailures.count as string))
    )
    else
    (
        format "WeldVerts test: PASS. Threshold 0.3 mm welded 0.2 mm and preserved 1.0 mm.\n"
        format "Undo: Edit Poly weld, Editable Poly weld, selection, then object creation.\n"
    )
)

-- EXECUTION QUEUE
partOfTest1()

partOfTest2()

partOfTest3()
