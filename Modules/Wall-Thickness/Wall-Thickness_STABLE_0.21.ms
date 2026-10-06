/*
Wall Thickness Tool 0.21
Creates wall thickness by translating every copied wall face strictly along its own face normal and stitching the resulting shell.
*/

global wallThicknessRollout
global wall_thickness_ini = (getDir #plugcfg + "\\Wall-Thickness.ini")
global wall_thickness_target = undefined
global wall_thickness_default = 1.0
global wall_thickness_user_prop = "WallThickness"
global wall_thickness_selection_callback_id = #WallThicknessSelectionChanged
global wall_thickness_modifier_name = "WALL THICKNESS"
global wall_thickness_finished_modifier_name = "WALL THICKNESS FINISHED"
global wall_thickness_file_version = 0.21
global wall_thickness_stored_project_version = 0.21
global wall_thickness_project_version

if wall_thickness_project_version == undefined then
(
	wall_thickness_project_version = wall_thickness_stored_project_version
)
else if wall_thickness_stored_project_version > wall_thickness_project_version then
(
	wall_thickness_project_version = wall_thickness_stored_project_version
)

global wall_thickness_ratio_default = 150

/*
Returns a short label for the current 3ds Max display unit.
*/
function getWallThicknessDisplayUnitsLabel =
(
	case units.DisplayType of
	(
		#Metric:
		(
			case units.MetricType of
			(
				#Millimeters: "mm"
				#Centimeters: "cm"
				#Meters: "m"
				#Kilometers: "km"
				default: "units"
			)
		)
		#US:
		(
			case units.USType of
			(
				#Frac_In: "in"
				#Dec_In: "in"
				#Frac_Ft: "ft"
				#Dec_Ft: "ft"
				#Ft_Frac_In: "ft/in"
				#Ft_Dec_In: "ft/in"
				default: "units"
			)
		)
		#Custom:
		(
			if units.CustomName != "" then
				units.CustomName
			else
			(
				unit_text = units.CustomUnit as string
				unit_text = substituteString unit_text "#" ""
				unit_text
			)
		)
		default: "units"
	)
)

function loadWallThicknessRatio =
(
	saved_value = getINISetting wall_thickness_ini "Settings" "ModelRatio"
	if saved_value == "" then wall_thickness_ratio_default else amax 1 (saved_value as integer)
)

function saveWallThicknessRatio ratio_value =
(
	setINISetting wall_thickness_ini "Settings" "ModelRatio" ((amax 1 ratio_value) as string)
	true
)

function loadWallThicknessDialogPos =
(
	x_text = getINISetting wall_thickness_ini "UI" "X"
	y_text = getINISetting wall_thickness_ini "UI" "Y"

	if (x_text == "") or (y_text == "") then
		undefined
	else
		[x_text as integer, y_text as integer]
)

function saveWallThicknessDialogPos =
(
	try
	(
		dialog_pos = getDialogPos wallThicknessRollout
		setINISetting wall_thickness_ini "UI" "X" (dialog_pos.x as string)
		setINISetting wall_thickness_ini "UI" "Y" (dialog_pos.y as string)
	)
	catch
	(
	)
	true
)

/*
Returns a readable metric value and unit for one system-unit distance.
The smallest practical metric unit is millimeters so values such as 0.003 m display as 3 mm.
*/
function getWallThicknessNiceMetricValue system_value =
(
	absolute_value = abs system_value
	unit_scale = 1.0
	unit_label = "mm"

	millimeter_scale = units.decodeValue "1mm"
	centimeter_scale = units.decodeValue "1cm"
	meter_scale = units.decodeValue "1m"
	kilometer_scale = units.decodeValue "1km"

	if absolute_value >= kilometer_scale then
	(
		unit_scale = kilometer_scale
		unit_label = "km"
	)
	else if absolute_value >= meter_scale then
	(
		unit_scale = meter_scale
		unit_label = "m"
	)
	else if absolute_value >= centimeter_scale then
	(
		unit_scale = centimeter_scale
		unit_label = "cm"
	)
	else
	(
		unit_scale = millimeter_scale
		unit_label = "mm"
	)

	#(system_value / unit_scale, unit_label)
	-- return
)

/*
Formats scaled thickness using a compact unit-aware value.
Metric display automatically chooses km, m, cm, or mm; other display systems keep the current 3ds Max unit format.
*/
function getWallThicknessScaledDisplay system_value =
(
	if units.DisplayType == #Metric then
	(
		metric_data = getWallThicknessNiceMetricValue system_value
		#(formattedPrint metric_data[1] format:"0.6g", metric_data[2])
	)
	else
	(
		formatted_value = units.formatValue system_value
		#(formatted_value, getWallThicknessDisplayUnitsLabel())
	)
	-- return
)

/*
Updates the scaled-thickness row from the current thickness and model ratio.
The displayed result is converted to a compact human-readable unit.
*/
function updateWallThicknessScaledLabel =
(
	if wallThicknessRollout != undefined then
	(
		ratio_value = amax 1 wallThicknessRollout.spn_ratio.value
		scaled_value = wallThicknessRollout.spn_thickness.value / ratio_value
		display_data = getWallThicknessScaledDisplay scaled_value
		wallThicknessRollout.lbl_scaled.text = display_data[1]
		wallThicknessRollout.lbl_scaled_units.text = display_data[2]
	)
	true
)


/*
Reads saved thickness from the tool INI file.
Defaults to one current world/display unit.
*/
function loadWallThicknessSetting =
(
	saved_value = getINISetting wall_thickness_ini "Settings" "Thickness"
	if saved_value == "" then (1.0) else (saved_value as float)
	-- return
)

/*
Stores current thickness in the tool INI file.
The value is restored when the UI is opened again.
*/
function saveWallThicknessSetting thickness =
(
	setINISetting wall_thickness_ini "Settings" "Thickness" (thickness as string)
	true
	-- return
)

/*
Reads thickness stored directly on one wall node.
Objects without a stored value use the default one display/world unit.
*/
function getObjectWallThickness source_node =
(
	thickness = wall_thickness_default

	if isValidNode source_node then
	(
		saved_value = getUserProp source_node wall_thickness_user_prop

		if saved_value != undefined then
		(
			if (classOf saved_value == Float) or (classOf saved_value == Integer) then
			(
				thickness = saved_value as float
			)
			else
			(
				saved_text = saved_value as string

				if saved_text != "" then
				(
					thickness = saved_text as float
				)
			)
		)
	)

	thickness
	-- return
)


/*
Stores thickness directly in the selected wall node user properties.
Each wall therefore owns its own independent thickness value.
*/
function setObjectWallThickness source_node thickness =
(
	if isValidNode source_node then
	(
		setUserProp source_node wall_thickness_user_prop thickness
	)

	true
	-- return
)


/*
Updates the UI spinner from the currently selected wall object.
Selection changes also make that node the active dynamic-thickness target.
*/
function syncWallThicknessSpinnerToSelection =
(
	if wallThicknessRollout != undefined then
	(
		if selection.count == 1 then
		(
			source_node = selection[1]
			wall_thickness_target = source_node
			wallThicknessRollout.spn_thickness.value = getObjectWallThickness source_node
		)
		else
		(
			wall_thickness_target = undefined
			wallThicknessRollout.spn_thickness.value = wall_thickness_default
		)
	)

	true
	-- return
)


/*
Returns unique horizontal wall normals around a TriMesh vertex.
Normals are projected to XY so imported face noise cannot create Z displacement.
*/
function getUniqueNormals mesh_data face_ids =
(
	normal_array = #()

	for face_id in face_ids do
	(
		source_normal = getFaceNormal mesh_data face_id
		flat_normal = [source_normal.x, source_normal.y, 0]

		if (length flat_normal) > 0.000001 then
		(
			face_normal = normalize flat_normal
			is_unique = true

			for existing_normal in normal_array while is_unique do
			(
				if (abs (dot face_normal existing_normal)) > 0.99999 then
				(
					is_unique = false
				)
			)

			if is_unique then
			(
				append normal_array face_normal
			)
		)
	)

	normal_array
	-- return
)


/*
Solves the constant-distance intersection offset for two planes.
Both normals are expected to point toward the required inner side.
*/
function solveTwoPlaneOffset normal_a normal_b thickness =
(
	dot_ab = dot normal_a normal_b
	denominator = 1.0 + dot_ab
	if (abs denominator) < 0.000001 then
	(
		normal_a * thickness
	)
	else
	(
		((normal_a + normal_b) / denominator) * thickness
	)
	-- return
)

/*
Solves the constant-distance intersection offset for three planes.
Returns undefined when the planes do not define a stable intersection.
*/
function solveThreePlaneOffset normal_a normal_b normal_c thickness =
(
	cross_bc = cross normal_b normal_c
	cross_ca = cross normal_c normal_a
	cross_ab = cross normal_a normal_b
	determinant = dot normal_a cross_bc
	if (abs determinant) < 0.000001 then
	(
		undefined
	)
	else
	(
		((cross_bc + cross_ca + cross_ab) * thickness) / determinant
	)
	-- return
)

/*
Calculates horizontal inward displacement for one source vertex.
Z displacement is always zero and pathological miters are limited.
*/
function getOffsetDisplacement mesh_data vertex_id thickness =
(
	face_bits = meshop.getFacesUsingVert mesh_data #{vertex_id}
	face_ids = face_bits as array
	normal_array = getUniqueNormals mesh_data face_ids

	for normal_id = 1 to normal_array.count do
	(
		normal_array[normal_id] = -normal_array[normal_id]
	)

	normal_count = normal_array.count
	offset_vector = [0, 0, 0]

	if normal_count == 1 then
	(
		offset_vector = normal_array[1] * thickness
	)
	else if normal_count >= 2 then
	(
		offset_vector = solveTwoPlaneOffset normal_array[1] normal_array[2] thickness
	)

	offset_vector.z = 0
	max_miter_length = thickness * 20.0

	if (length offset_vector) > max_miter_length then
	(
		if normal_count > 0 then
		(
			offset_vector = normal_array[1] * thickness
			offset_vector.z = 0
		)
		else
		(
			offset_vector = [0, 0, 0]
		)
	)

	offset_vector
	-- return
)


/*
Returns the two vertex indices used by one TriMesh edge.
Undefined is returned if the edge does not resolve to exactly two vertices.
*/
function getMeshEdgeVertices mesh_data edge_id =
(
	vertex_bits = meshop.getVertsUsingEdge mesh_data #{edge_id}
	vertex_ids = vertex_bits as array
	if vertex_ids.count == 2 then
	(
		[vertex_ids[1], vertex_ids[2], 0]
	)
	else
	(
		undefined
	)
	-- return
)

/*
Finds the tool-owned Edit Poly modifier on a node.
Only the modifier named WALL THICKNESS is considered.
*/
function getWallThicknessModifier source_node =
(
	found_modifier = undefined
	if isValidNode source_node then
	(
		for modifier_id = 1 to source_node.modifiers.count while found_modifier == undefined do
		(
			test_modifier = source_node.modifiers[modifier_id]
			if (classOf test_modifier == Edit_Poly) and (test_modifier.name == wall_thickness_modifier_name) then
			(
				found_modifier = test_modifier
			)
		)
	)
	found_modifier
	-- return
)

/*
Finds the finalized tool-owned Edit Poly modifier on a node.
Only the modifier named WALL THICKNESS FINISHED is considered.
*/
function getFinishedWallThicknessModifier source_node =
(
	found_modifier = undefined
	if isValidNode source_node then
	(
		for modifier_id = 1 to source_node.modifiers.count while found_modifier == undefined do
		(
			test_modifier = source_node.modifiers[modifier_id]
			if (classOf test_modifier == Edit_Poly) and (test_modifier.name == wall_thickness_finished_modifier_name) then
			(
				found_modifier = test_modifier
			)
		)
	)
	found_modifier
	-- return
)

/*
Removes the finalized thickness modifier from a node.
The source object and every unrelated modifier remain untouched.
*/
function removeFinishedWallThicknessModifier source_node =
(
	finished_modifier = getFinishedWallThicknessModifier source_node
	if finished_modifier != undefined then
	(
		deleteModifier source_node finished_modifier
	)
	true
	-- return
)

/*
Removes the previous generated thickness modifier from a node.
The source object and every other modifier remain untouched.
*/
function removeWallThicknessModifier source_node =
(
	thickness_modifier = getWallThicknessModifier source_node
	if thickness_modifier != undefined then
	(
		deleteModifier source_node thickness_modifier
	)
	true
	-- return
)

/*
Removes every Wall Thickness modifier owned by this tool from one node.
Both live and finished thickness modifiers are removed while unrelated modifiers and source geometry remain untouched.
*/
function resetWallThickness source_node =
(
	if not isValidNode source_node then
	(
		messageBox "Select exactly one wall object." title:"Wall Thickness"
		false
	)
	else
	(
		undo "Reset Wall Thickness" on
		(
			removeWallThicknessModifier source_node
			removeFinishedWallThicknessModifier source_node
		)

		if wall_thickness_target == source_node then
		(
			wall_thickness_target = undefined
		)

		completeRedraw()
		true
	)
	-- return
)

/*
Assigns one material ID to a face bitarray through Edit Poly.
The operation is committed into the modifier.
*/
function setEditPolyMaterialID edit_modifier source_node face_bits material_id =
(
	if face_bits.numberSet > 0 then
	(
		edit_modifier.SetSelection #Face face_bits node:source_node
		edit_modifier.materialIDToSet = material_id
		edit_modifier.SetOperation #SetMaterial
		edit_modifier.Commit()
	)
	true
	-- return
)

/*
Applies native Edit Poly Auto Smooth to the complete result.
The threshold is explicitly set to 45 degrees.
*/
function autoSmoothEditPolyResult edit_modifier source_node =
(
	face_count = edit_modifier.GetNumFaces node:source_node
	if face_count > 0 then
	(
		all_faces = #{1..face_count}
		edit_modifier.SetSelection #Face all_faces node:source_node
		edit_modifier.autoSmoothThreshold = 45.0
		edit_modifier.SetOperation #Autosmooth
		edit_modifier.Commit()
	)
	true
	-- return
)

/*
Applies native Edit Poly Auto Smooth only to generated Finish faces.
The original source-face smoothing groups remain unchanged.
*/
function autoSmoothWallThicknessGeneratedFaces edit_modifier source_node inner_face_ids thickness_face_ids =
(
	generated_face_ids = inner_face_ids + thickness_face_ids
	if generated_face_ids.numberSet > 0 then
	(
		edit_modifier.SetSelection #Face generated_face_ids node:source_node
		edit_modifier.autoSmoothThreshold = 45.0
		edit_modifier.SetOperation #Autosmooth
		edit_modifier.Commit()
	)
	true
	-- return
)

/*
Returns one normalized source-face normal for strict wall extrusion.
No vertex-normal averaging or miter direction is used.
*/
function getWallThicknessStrictFaceNormal mesh_data face_id =
(
	face_normal = getFaceNormal mesh_data face_id
	if (length face_normal) > 0.000001 then
	(
		normalize face_normal
	)
	else
	(
		undefined
	)
	-- return
)

/*
Returns or creates the generated vertex for one source vertex and one face-normal direction.
Coplanar triangles reuse the same generated vertex while sharp wall corners keep separate face-normal copies.
*/
function getOrCreateWallThicknessFaceVertex edit_modifier source_node source_mesh vertex_id face_normal thickness vertex_group_normals vertex_group_ids =
(
	normal_groups = vertex_group_normals[vertex_id]
	id_groups = vertex_group_ids[vertex_id]
	matching_group = 0

	for group_id = 1 to normal_groups.count while matching_group == 0 do
	(
		if (dot normal_groups[group_id] face_normal) > 0.99999 then
		(
			matching_group = group_id
		)
	)

	if matching_group > 0 then
	(
		id_groups[matching_group]
	)
	else
	(
		source_position = getVert source_mesh vertex_id
		offset_position = source_position - (face_normal * thickness)
		new_vertex_id = edit_modifier.CreateVertex offset_position node:source_node
		append normal_groups face_normal
		append id_groups new_vertex_id
		vertex_group_normals[vertex_id] = normal_groups
		vertex_group_ids[vertex_id] = id_groups
		new_vertex_id
	)
	-- return
)

/*
Returns the generated vertex used by one source face at one source vertex.
The face offset array is stored in source-face x/y/z order.
*/
function getWallThicknessFaceVertexId source_mesh face_offset_vertex_ids face_id source_vertex_id =
(
	source_face = getFace source_mesh face_id
	face_vertex_ids = face_offset_vertex_ids[face_id]
	result_id = 0

	if source_face.x == source_vertex_id then
	(
		result_id = face_vertex_ids[1]
	)
	else if source_face.y == source_vertex_id then
	(
		result_id = face_vertex_ids[2]
	)
	else if source_face.z == source_vertex_id then
	(
		result_id = face_vertex_ids[3]
	)

	result_id
	-- return
)

/*
Creates strict face-normal wall thickness in one Edit Poly modifier.
Copied faces stay parallel to the source faces; sharp internal wall edges are stitched instead of moving corner vertices on averaged normals.
*/
function buildWallThicknessModifier source_node thickness =
(
	if not isValidNode source_node then
	(
		undefined
	)
	else
	(
		removeWallThicknessModifier source_node
		removeFinishedWallThicknessModifier source_node
		source_mesh = snapshotAsMesh source_node
		if source_mesh == undefined then
		(
			messageBox "Unable to read source wall geometry." title:"Wall Thickness"
			undefined
		)
		else
		(
			source_vert_count = meshop.getNumVerts source_mesh
			source_tri_face_count = meshop.getNumFaces source_mesh
			source_edge_count = source_tri_face_count * 3
			source_open_edges = meshop.getOpenEdges source_mesh
			source_boundary_vertices = meshop.getVertsUsingEdge source_mesh source_open_edges
			edit_modifier = Edit_Poly()
			edit_modifier.name = wall_thickness_modifier_name
			edit_modifier.showCage = off
			addModifier source_node edit_modifier
			modifier_source_vert_count = edit_modifier.GetNumVertices node:source_node
			modifier_source_face_count = edit_modifier.GetNumFaces node:source_node

			if modifier_source_vert_count != source_vert_count then
			(
				deleteModifier source_node edit_modifier
				free source_mesh
				messageBox "Source topology changed while creating thickness. WALL THICKNESS was not applied." title:"Wall Thickness"
				undefined
			)
			else
			(
				source_faces = #{1..modifier_source_face_count}
				setEditPolyMaterialID edit_modifier source_node source_faces 1
				vertex_group_normals = for vertex_id = 1 to source_vert_count collect #()
				vertex_group_ids = for vertex_id = 1 to source_vert_count collect #()
				face_offset_vertex_ids = for face_id = 1 to source_tri_face_count collect #()
				face_normals = for face_id = 1 to source_tri_face_count collect undefined
				inner_face_ids = #{}
				thickness_face_ids = #{}
				edit_modifier.SetOperation #Create

				for face_id = 1 to source_tri_face_count do
				(
					source_face = getFace source_mesh face_id
					face_normal = getWallThicknessStrictFaceNormal source_mesh face_id
					face_normals[face_id] = face_normal
					if face_normal != undefined then
					(
						vertex_x = getOrCreateWallThicknessFaceVertex edit_modifier source_node source_mesh source_face.x face_normal thickness vertex_group_normals vertex_group_ids
						vertex_y = getOrCreateWallThicknessFaceVertex edit_modifier source_node source_mesh source_face.y face_normal thickness vertex_group_normals vertex_group_ids
						vertex_z = getOrCreateWallThicknessFaceVertex edit_modifier source_node source_mesh source_face.z face_normal thickness vertex_group_normals vertex_group_ids
						face_offset_vertex_ids[face_id] = #(vertex_x, vertex_y, vertex_z)
						new_face_id = edit_modifier.CreateFace #(vertex_z, vertex_y, vertex_x) node:source_node
						if new_face_id != undefined then
						(
							inner_face_ids[new_face_id] = true
						)
					)
				)

				processed_edge_keys = #()
				for edge_id = 1 to source_edge_count do
				(
					edge_vertices = getMeshEdgeVertices source_mesh edge_id
					if edge_vertices != undefined then
					(
						vertex_a = edge_vertices.x as integer
						vertex_b = edge_vertices.y as integer
						if vertex_a < vertex_b then
						(
							edge_key = (vertex_a as string) + "_" + (vertex_b as string)
						)
						else
						(
							edge_key = (vertex_b as string) + "_" + (vertex_a as string)
						)

						if (findItem processed_edge_keys edge_key) == 0 then
						(
							append processed_edge_keys edge_key
							edge_bits = #{edge_id}
							edge_bits += meshop.getEdgesReverseEdge source_mesh edge_bits
							face_ids = (meshop.getFacesUsingEdge source_mesh edge_bits) as array

							if face_ids.count == 1 then
							(
								face_id = face_ids[1]
								offset_a = getWallThicknessFaceVertexId source_mesh face_offset_vertex_ids face_id vertex_a
								offset_b = getWallThicknessFaceVertexId source_mesh face_offset_vertex_ids face_id vertex_b
								if (offset_a > 0) and (offset_b > 0) then
								(
									new_face_id = edit_modifier.CreateFace #(vertex_a, vertex_b, offset_b, offset_a) node:source_node
									if new_face_id != undefined then
									(
										thickness_face_ids[new_face_id] = true
									)
								)
							)
							else if face_ids.count == 2 then
							(
								face_a = face_ids[1]
								face_b = face_ids[2]
								normal_a = face_normals[face_a]
								normal_b = face_normals[face_b]
								if (normal_a != undefined) and (normal_b != undefined) and ((dot normal_a normal_b) < 0.99999) then
								(
									offset_a1 = getWallThicknessFaceVertexId source_mesh face_offset_vertex_ids face_a vertex_a
									offset_b1 = getWallThicknessFaceVertexId source_mesh face_offset_vertex_ids face_a vertex_b
									offset_a2 = getWallThicknessFaceVertexId source_mesh face_offset_vertex_ids face_b vertex_a
									offset_b2 = getWallThicknessFaceVertexId source_mesh face_offset_vertex_ids face_b vertex_b
									if (offset_a1 > 0) and (offset_b1 > 0) and (offset_a2 > 0) and (offset_b2 > 0) then
									(
										new_face_id = edit_modifier.CreateFace #(offset_a1, offset_b1, offset_b2, offset_a2) node:source_node
										if new_face_id != undefined then
										(
											thickness_face_ids[new_face_id] = true
										)

										if source_boundary_vertices[vertex_a] then
										(
											new_face_id = edit_modifier.CreateFace #(vertex_a, offset_a2, offset_a1) node:source_node
											if new_face_id != undefined then
											(
												thickness_face_ids[new_face_id] = true
											)
										)

										if source_boundary_vertices[vertex_b] then
										(
											new_face_id = edit_modifier.CreateFace #(vertex_b, offset_b1, offset_b2) node:source_node
											if new_face_id != undefined then
											(
												thickness_face_ids[new_face_id] = true
											)
										)
									)
								)
							)
						)
					)
				)

				edit_modifier.Commit()
				setEditPolyMaterialID edit_modifier source_node inner_face_ids 2
				setEditPolyMaterialID edit_modifier source_node thickness_face_ids 3
				autoSmoothEditPolyResult edit_modifier source_node
				empty_faces = #{}
				edit_modifier.SetSelection #Face empty_faces node:source_node
				edit_modifier.RefreshScreen()
				free source_mesh
				completeRedraw()
				edit_modifier
			)
		)
	)
	-- return
)

/*
Creates or rebuilds the live thickness modifier on one source wall.
The target is remembered so spinner changes update the same wall.
*/
function applyWallThickness source_node thickness =
(
	if not isValidNode source_node then
	(
		messageBox "Select exactly one wall object." title:"Wall Thickness"
		false
	)
	else if thickness <= 0 then
	(
		messageBox "Thickness must be greater than zero." title:"Wall Thickness"
		false
	)
	else
	(
		wall_thickness_target = source_node
		setObjectWallThickness source_node thickness
		undo "Wall Thickness" on
		(
			buildWallThicknessModifier source_node thickness
		)
		true
	)
	-- return
)

/*
Rebuilds the active WALL THICKNESS modifier after a spinner change.
The original target is used even if viewport selection later changes.
*/
function updateDynamicWallThickness thickness =
(
	if isValidNode wall_thickness_target then
	(
		if getFinishedWallThicknessModifier wall_thickness_target == undefined then
		(
			saveWallThicknessSetting thickness
			with undo off
			(
				buildWallThicknessModifier wall_thickness_target thickness
			)
		)
	)
	true
	-- return
)

/*
Reads the source wall below the live thickness modifier.
The preview modifier is disabled only while the snapshot is taken.
*/
function getWallThicknessSourceMesh source_node =
(
	if not isValidNode source_node then
	(
		undefined
	)
	else
	(
		preview_modifier = getWallThicknessModifier source_node
		if preview_modifier == undefined then
		(
			snapshotAsMesh source_node
		)
		else
		(
			was_enabled = preview_modifier.enabled
			source_mesh = undefined
			try
			(
				preview_modifier.enabled = false
				source_mesh = snapshotAsMesh source_node
				preview_modifier.enabled = was_enabled
			)
			catch
			(
				preview_modifier.enabled = was_enabled
				source_mesh = undefined
			)
			source_mesh
		)
	)
	-- return
)

/*
Returns the current inward-offset position for every source vertex.
The same displacement solver used by Live Preview is reused so Finish starts from identical geometry.
*/
function getWallThicknessOffsetPositions source_mesh thickness =
(
	offset_positions = #()
	source_vert_count = meshop.getNumVerts source_mesh
	for vertex_id = 1 to source_vert_count do
	(
		source_position = getVert source_mesh vertex_id
		offset_vector = getOffsetDisplacement source_mesh vertex_id thickness
		append offset_positions (source_position + offset_vector)
	)
	offset_positions
	-- return
)

/*
Returns the root ID of one overlap-collapse group.
Parent arrays keep topology detection independent from scene modifiers.
*/
function getWallThicknessGroupRoot parent_array vertex_id =
(
	root_id = vertex_id
	while parent_array[root_id] != root_id do
	(
		root_id = parent_array[root_id]
	)
	root_id
	-- return
)

/*
Joins two source vertices into one local overlap-collapse group.
Only the corrected generated positions are grouped; source vertices remain untouched.
*/
function joinWallThicknessGroups parent_array vertex_a vertex_b =
(
	root_a = getWallThicknessGroupRoot parent_array vertex_a
	root_b = getWallThicknessGroupRoot parent_array vertex_b
	if root_a != root_b then
	(
		parent_array[root_b] = root_a
	)
	true
	-- return
)

/*
Calculates where one source edge collapses while thickness grows from zero to the requested value.
The same thickness fraction is applied to both endpoints, which is stable for flat orthogonal wall corners.
*/
function getWallThicknessEdgeCollapsePoint source_a offset_a source_b offset_b tolerance =
(
	source_edge = source_b - source_a
	source_length = length source_edge
	if source_length <= tolerance then
	(
		undefined
	)
	else
	(
		source_direction = source_edge / source_length
		move_a = offset_a - source_a
		move_b = offset_b - source_b
		final_projected_length = dot (offset_b - offset_a) source_direction
		projected_change = final_projected_length - source_length

		if (final_projected_length > tolerance) or (projected_change >= -tolerance) then
		(
			undefined
		)
		else
		(
			collapse_fraction = source_length / (source_length - final_projected_length)
			collapse_fraction = amax 0.0 (amin 1.0 collapse_fraction)
			point_a = source_a + (move_a * collapse_fraction)
			point_b = source_b + (move_b * collapse_fraction)
			(point_a + point_b) / 2.0
		)
	)
	-- return
)

/*
Normalizes every collapse-group parent to its final root ID.
The returned root array is later used to create one welded generated vertex per collapsed group.
*/
function getWallThicknessGroupRoots parent_array =
(
	root_array = #()
	for vertex_id = 1 to parent_array.count do
	(
		append root_array (getWallThicknessGroupRoot parent_array vertex_id)
	)
	root_array
	-- return
)

/*
Detects short generated edges that collapse or reverse under the requested inward thickness.
Collapsed source vertices are grouped and receive one shared generated position and one shared generated vertex ID.
*/
function getWallThicknessCorrectedOffsetPositions source_mesh thickness =
(
	if source_mesh == undefined then
	(
		undefined
	)
	else
	(
		source_vert_count = meshop.getNumVerts source_mesh
		offset_positions = getWallThicknessOffsetPositions source_mesh thickness
		parent_array = for vertex_id = 1 to source_vert_count collect vertex_id
		processed_edge_keys = #()
		collision_events = #()
		collision_tolerance = amax 0.0001 ((abs thickness) * 0.0001)
		edge_count = (meshop.getNumFaces source_mesh) * 3

		for edge_id = 1 to edge_count do
		(
			edge_vertices = getMeshEdgeVertices source_mesh edge_id
			if edge_vertices != undefined then
			(
				vertex_a = edge_vertices.x as integer
				vertex_b = edge_vertices.y as integer
				if vertex_a != vertex_b then
				(
					if vertex_a < vertex_b then
					(
						edge_key = (vertex_a as string) + "_" + (vertex_b as string)
					)
					else
					(
						edge_key = (vertex_b as string) + "_" + (vertex_a as string)
					)

					if (findItem processed_edge_keys edge_key) == 0 then
					(
						append processed_edge_keys edge_key
						source_a = getVert source_mesh vertex_a
						source_b = getVert source_mesh vertex_b
						offset_a = offset_positions[vertex_a]
						offset_b = offset_positions[vertex_b]
						source_edge = source_b - source_a
						source_length = length source_edge

						if source_length > collision_tolerance then
						(
							source_direction = source_edge / source_length
							final_projected_length = dot (offset_b - offset_a) source_direction
							if final_projected_length <= collision_tolerance then
							(
								collapse_point = getWallThicknessEdgeCollapsePoint source_a offset_a source_b offset_b collision_tolerance
								if collapse_point != undefined then
								(
									joinWallThicknessGroups parent_array vertex_a vertex_b
									append collision_events #(vertex_a, vertex_b, collapse_point)
								)
							)
						)
					)
				)
			)
		)

		group_sums = for vertex_id = 1 to source_vert_count collect [0, 0, 0]
		group_counts = for vertex_id = 1 to source_vert_count collect 0
		for collision_event in collision_events do
		(
			root_id = getWallThicknessGroupRoot parent_array collision_event[1]
			group_sums[root_id] += collision_event[3]
			group_counts[root_id] += 1
		)

		group_roots = getWallThicknessGroupRoots parent_array
		for vertex_id = 1 to source_vert_count do
		(
			root_id = group_roots[vertex_id]
			if group_counts[root_id] > 0 then
			(
				offset_positions[vertex_id] = group_sums[root_id] / group_counts[root_id]
			)
		)

		#(offset_positions, collision_events.count, group_roots)
	)
	-- return
)

/*
Removes repeated vertex IDs from one generated polygon while preserving winding order.
This turns a collapsed border quad into a valid triangle instead of leaving a hole.
*/
function getWallThicknessUniqueFaceVertices vertex_ids =
(
	unique_ids = #()
	for vertex_id in vertex_ids do
	(
		if (unique_ids.count == 0) or (unique_ids[unique_ids.count] != vertex_id) then
		(
			append unique_ids vertex_id
		)
	)
	if (unique_ids.count > 1) and (unique_ids[1] == unique_ids[unique_ids.count]) then
	(
		deleteItem unique_ids unique_ids.count
	)
	unique_ids
	-- return
)

/*
Builds the finalized Edit Poly using one generated vertex per collapse group.
Degenerate inner triangles are skipped and collapsed border quads become triangles so the shell can remain closed.
*/
function buildFinishedWallThicknessModifier source_node source_mesh corrected_positions collapse_roots thickness =
(
	preview_modifier = getWallThicknessModifier source_node
	if preview_modifier == undefined then
	(
		#(false, -1, 0, 0)
	)
	else
	(
		preview_was_enabled = preview_modifier.enabled
		final_modifier = undefined
		build_succeeded = false
		open_edge_count = -1
		skipped_inner_faces = 0
		triangular_border_faces = 0
		try
		(
			preview_modifier.enabled = false
			final_modifier = Edit_Poly()
			final_modifier.name = "__WALL THICKNESS FINISH__"
			final_modifier.showCage = off
			addModifier source_node final_modifier

			source_vert_count = meshop.getNumVerts source_mesh
			source_tri_face_count = meshop.getNumFaces source_mesh
			modifier_source_vert_count = final_modifier.GetNumVertices node:source_node
			modifier_source_face_count = final_modifier.GetNumFaces node:source_node
			if (modifier_source_vert_count == source_vert_count) and (corrected_positions.count == source_vert_count) and (collapse_roots.count == source_vert_count) then
			(
				if modifier_source_face_count > 0 then
				(
					setEditPolyMaterialID final_modifier source_node #{1..modifier_source_face_count} 1
				)

				offset_vertex_ids = for vertex_id = 1 to source_vert_count collect 0
				root_vertex_ids = for vertex_id = 1 to source_vert_count collect 0
				inner_face_ids = #{}
				thickness_face_ids = #{}
				final_modifier.SetOperation #Create

				for vertex_id = 1 to source_vert_count do
				(
					root_id = collapse_roots[vertex_id]
					if root_vertex_ids[root_id] == 0 then
					(
						root_vertex_ids[root_id] = final_modifier.CreateVertex corrected_positions[root_id] node:source_node
					)
					offset_vertex_ids[vertex_id] = root_vertex_ids[root_id]
				)

				for face_id = 1 to source_tri_face_count do
				(
					source_face = getFace source_mesh face_id
					vertex_a = offset_vertex_ids[source_face.z]
					vertex_b = offset_vertex_ids[source_face.y]
					vertex_c = offset_vertex_ids[source_face.x]
					if (vertex_a != vertex_b) and (vertex_b != vertex_c) and (vertex_c != vertex_a) then
					(
						new_face_id = final_modifier.CreateFace #(vertex_a, vertex_b, vertex_c) node:source_node
						if new_face_id != undefined then
						(
							inner_face_ids[new_face_id] = true
						)
					)
					else
					(
						skipped_inner_faces += 1
					)
				)

				source_open_edges = meshop.getOpenEdges source_mesh
				for edge_id in source_open_edges do
				(
					edge_vertices = getMeshEdgeVertices source_mesh edge_id
					if edge_vertices != undefined then
					(
						vertex_a = edge_vertices.x as integer
						vertex_b = edge_vertices.y as integer
						offset_a = offset_vertex_ids[vertex_a]
						offset_b = offset_vertex_ids[vertex_b]
						border_vertices = getWallThicknessUniqueFaceVertices #(vertex_a, vertex_b, offset_b, offset_a)
						if border_vertices.count >= 3 then
						(
							new_face_id = final_modifier.CreateFace border_vertices node:source_node
							if new_face_id != undefined then
							(
								thickness_face_ids[new_face_id] = true
								if border_vertices.count == 3 then
								(
									triangular_border_faces += 1
								)
							)
						)
					)
				)

				final_modifier.Commit()
				setEditPolyMaterialID final_modifier source_node inner_face_ids 2
				setEditPolyMaterialID final_modifier source_node thickness_face_ids 3
				autoSmoothWallThicknessGeneratedFaces final_modifier source_node inner_face_ids thickness_face_ids
				empty_faces = #{}
				final_modifier.SetSelection #Face empty_faces node:source_node
				final_modifier.RefreshScreen()

				validation_mesh = snapshotAsMesh source_node
				if validation_mesh != undefined then
				(
					open_edge_count = (meshop.getOpenEdges validation_mesh).numberSet
					free validation_mesh
				)

				deleteModifier source_node preview_modifier
				final_modifier.name = wall_thickness_finished_modifier_name
				final_modifier.showCage = off
				build_succeeded = true
			)

			if not build_succeeded then
			(
				if final_modifier != undefined then
				(
					deleteModifier source_node final_modifier
				)
				preview_modifier.enabled = preview_was_enabled
			)
		)
		catch
		(
			if final_modifier != undefined then
			(
				try
				(
					deleteModifier source_node final_modifier
				)
				catch
				(
				)
			)
			if isValidNode source_node then
			(
				try
				(
					preview_modifier.enabled = preview_was_enabled
				)
				catch
				(
				)
			)
			build_succeeded = false
			open_edge_count = -1
		)
		#(build_succeeded, open_edge_count, skipped_inner_faces, triangular_border_faces)
	)
	-- return
)

/*
Finalizes the strict face-normal live shell without changing its geometry.
Finish only freezes the current generated Edit Poly and reports whether the result has open edges.
*/
function finishWallThickness source_node =
(
	if not isValidNode source_node then
	(
		messageBox "Select exactly one wall object." title:"Wall Thickness"
		false
	)
	else
	(
		preview_modifier = getWallThicknessModifier source_node
		if preview_modifier == undefined then
		(
			messageBox "Create a live thickness preview before using Finish." title:"Wall Thickness"
			false
		)
		else
		(
			open_edge_count = -1
			undo "Finish Wall Thickness" on
			(
				preview_modifier.name = wall_thickness_finished_modifier_name
				preview_modifier.showCage = off
			)

			result_mesh = snapshotAsMesh source_node
			if result_mesh != undefined then
			(
				open_edge_count = (meshop.getOpenEdges result_mesh).numberSet
				free result_mesh
			)

			format "Wall Thickness Finish: strict face-normal shell | open edges: %.\n" open_edge_count
			if open_edge_count > 0 then
			(
				messageBox ("Finished strict face-normal shell has " + (open_edge_count as string) + " open edge(s). The result was kept for inspection.") title:"Wall Thickness"
			)
			completeRedraw()
			true
		)
	)
	-- return
)

/*
Clears smoothing groups non-destructively with a native Edit Poly modifier.
Works on evaluated Editable Poly or Edit Poly wall objects.
*/
function clearWallSmoothingGroups =
(
	if selection.count == 0 then
	(
		messageBox "Select at least one wall object." title:"Wall Thickness"
	)
	else
	(
		undo "Clear Smoothing Groups" on
		(
			for source_node in selection do
			(
				clear_modifier = Edit_Poly()
				clear_modifier.name = "CLEAR SMOOTHING GROUPS"
				clear_modifier.showCage = off
				addModifier source_node clear_modifier
				face_count = clear_modifier.GetNumFaces node:source_node
				if face_count > 0 then
				(
					all_faces = #{1..face_count}
					clear_modifier.SetSelection #Face all_faces node:source_node
					clear_modifier.smoothingGroupsToSet = 0
					clear_modifier.smoothingGroupsToClear = -1
					clear_modifier.SetOperation #SetSmooth
					clear_modifier.Commit()
					empty_faces = #{}
					clear_modifier.SetSelection #Face empty_faces node:source_node
				)
			)
		)
		completeRedraw()
	)
	-- return
)

/*
Creates connected one-sided exterior test walls with varied plan angles.
Includes several orthogonal corners plus sharp and open-angle corners.
*/
function createWallThicknessTest =
(
	wall_height = 100.0
	plan_points = #(
		[0, 0, 0],
		[120, 0, 0],
		[120, 90, 0],
		[200, 90, 0],
		[200, 170, 0],
		[155, 225, 0],
		[75, 190, 0],
		[5, 245, 0],
		[-70, 245, 0],
		[-70, 150, 0],
		[-145, 150, 0]
	)
	test_vertices = #()
	for plan_point in plan_points do
	(
		append test_vertices [plan_point.x, plan_point.y, 0]
		append test_vertices [plan_point.x, plan_point.y, wall_height]
	)
	test_faces = #()
	for segment_id = 1 to (plan_points.count - 1) do
	(
		bottom_a = ((segment_id - 1) * 2) + 1
		top_a = bottom_a + 1
		bottom_b = bottom_a + 2
		top_b = bottom_a + 3
		append test_faces [bottom_a, bottom_b, top_b]
		append test_faces [bottom_a, top_b, top_a]
	)
	test_node = mesh vertices:test_vertices faces:test_faces
	test_node.name = "WallThickness_Angles_TEST"
	convertToPoly test_node
	update test_node
	select test_node
	test_node
	-- return
)

/*
Creates a narrow orthogonal wall path with a run shorter than the requested thickness.
The test validates strict face-normal extrusion and corner stitching without averaged vertex motion.
*/
function createWallThicknessOverlapTest =
(
	test_node = undefined
	undo "Create Wall Thickness Overlap Test" on
	(
		wall_height = 100.0
		plan_points = #(
			[0, 0, 0],
			[120, 0, 0],
			[120, 24, 0],
			[35, 24, 0],
			[35, 120, 0]
		)
		test_vertices = #()
		for plan_point in plan_points do
		(
			append test_vertices [plan_point.x, plan_point.y, 0]
			append test_vertices [plan_point.x, plan_point.y, wall_height]
		)
		test_faces = #()
		for segment_id = 1 to (plan_points.count - 1) do
		(
			bottom_a = ((segment_id - 1) * 2) + 1
			top_a = bottom_a + 1
			bottom_b = bottom_a + 2
			top_b = bottom_a + 3
			append test_faces [bottom_a, bottom_b, top_b]
			append test_faces [bottom_a, top_b, top_a]
		)
		test_node = mesh vertices:test_vertices faces:test_faces
		test_node.name = "WallThickness_Overlap_TEST"
		convertToPoly test_node
		update test_node
		select test_node
	)
	applyWallThickness test_node 40.0
	test_node
	-- return
)

/*
Runs the strict face-normal shell test through Finish and reports whether open edges remain.
The finished test object stays in the scene so orthogonal corner stitching can be inspected directly.
*/
function testWallThicknessFinishOverlap =
(
	test_node = createWallThicknessOverlapTest()
	finish_succeeded = finishWallThickness test_node
	open_edge_count = -1
	if finish_succeeded then
	(
		result_mesh = snapshotAsMesh test_node
		if result_mesh != undefined then
		(
			open_edge_count = (meshop.getOpenEdges result_mesh).numberSet
			free result_mesh
		)
	)
	test_passed = finish_succeeded and (open_edge_count == 0)
	format "Wall Thickness STRICT NORMAL TEST: % | open edges: %\n" (if test_passed then "PASS" else "FAIL") open_edge_count
	format "Undo order: Finish Wall Thickness -> Wall Thickness -> Create Wall Thickness Overlap Test.\n"
	test_passed
	-- return
)

/*
Runs a practical validation on the selected generated wall.
Checks the Edit Poly modifier and required material IDs 1, 2 and 3.
*/
function testWallThicknessResult =
(
	if selection.count != 1 then
	(
		format "Wall Thickness TEST: FAIL - select one generated wall.\n"
		false
	)
	else
	(
		source_node = selection[1]
		edit_modifier = getWallThicknessModifier source_node
		if edit_modifier == undefined then
		(
			format "Wall Thickness TEST: FAIL - WALL THICKNESS Edit Poly modifier not found.\n"
			false
		)
		else
		(
			face_count = edit_modifier.GetNumFaces node:source_node
			id_1_count = 0
			id_2_count = 0
			id_3_count = 0
			for face_id = 1 to face_count do
			(
				material_id = edit_modifier.GetFaceMaterial face_id node:source_node
				case material_id of
				(
					1: id_1_count += 1
					2: id_2_count += 1
					3: id_3_count += 1
				)
			)
			test_passed = (id_1_count > 0) and (id_2_count > 0) and (id_3_count > 0)
			format "Wall Thickness TEST:\n"
			format "  Edit Poly: %\n" (classOf edit_modifier == Edit_Poly)
			format "  Material ID 1 source faces: %\n" id_1_count
			format "  Material ID 2 inner faces: %\n" id_2_count
			format "  Material ID 3 thickness faces: %\n" id_3_count
			format "  RESULT: %\n" (if test_passed then "PASS" else "FAIL")
			test_passed
		)
	)
	-- return
)

/*
Tests metric scaled-thickness formatting with the requested 0.003 meter example.
The expected compact result is exactly 3 mm.
*/
function testWallThicknessScaledUnits =
(
	test_value = units.decodeValue "0.003m"
	metric_data = getWallThicknessNiceMetricValue test_value
	test_passed = ((abs (metric_data[1] - 3.0)) < 0.0001) and (metric_data[2] == "mm")
	format "Wall Thickness SCALED UNIT TEST: % | value:% %\n" (if test_passed then "PASS" else "FAIL") metric_data[1] metric_data[2]
	test_passed
	-- return
)

/*
Tests RESET by creating a live thickness modifier and removing it again.
The generated test wall stays in the scene so the modifier stack can be inspected after the test.
*/
function testWallThicknessReset =
(
	test_node = createWallThicknessOverlapTest()
	live_before = getWallThicknessModifier test_node
	reset_succeeded = resetWallThickness test_node
	live_after = getWallThicknessModifier test_node
	finished_after = getFinishedWallThicknessModifier test_node
	test_passed = (live_before != undefined) and reset_succeeded and (live_after == undefined) and (finished_after == undefined)
	format "Wall Thickness RESET TEST: %\n" (if test_passed then "PASS" else "FAIL")
	test_passed
	-- return
)

try
(
	destroyDialog wallThicknessRollout
)
catch
(
)

rollout wallThicknessRollout "Wall Thickness" width:270
(
	group "Thickness"
	(
		label lbl_thickness_caption "Thickness:" width:92 align:#left across:3
		spinner spn_thickness "" range:[0.001, 1000000.0, 1.0] type:#worldUnits width:92 fieldwidth:72 align:#left
		label lbl_units "" width:42 align:#left

		label lbl_ratio_caption "Model ratio: 1 :" width:92 align:#left across:3
		spinner spn_ratio "" range:[1, 1000000, 150] type:#integer width:92 fieldwidth:72 align:#left
		label lbl_ratio_units "" width:42 align:#left

		label lbl_scaled_caption "Scaled thickness:" width:92 align:#left across:3
		label lbl_scaled "" width:92 align:#left
		label lbl_scaled_units "" width:42 align:#left
	)
	button btn_create "Create / Update Thickness" width:230 height:32 align:#center
	button btn_finish "Finish" width:230 height:32 align:#center tooltip:"Freeze the current strict face-normal wall thickness result."
	button btn_reset "RESET" width:230 height:28 align:#center tooltip:"Remove the WALL THICKNESS or WALL THICKNESS FINISHED modifier from the selected object."
	button btn_clear_smoothing "Clear Smoothing Groups" width:230 height:28 align:#center
	button btn_test "Create Angle Test Walls" width:230 height:28 align:#center

	on wallThicknessRollout open do
	(
		wallThicknessRollout.title = "Wall Thickness " + (wall_thickness_project_version as string)
		lbl_units.text = getWallThicknessDisplayUnitsLabel()
		spn_ratio.value = loadWallThicknessRatio()
		syncWallThicknessSpinnerToSelection()
		updateWallThicknessScaledLabel()
	)

	on spn_thickness changed value do
	(
		updateWallThicknessScaledLabel()

		if selection.count == 1 then
		(
			wall_thickness_target = selection[1]
			if getFinishedWallThicknessModifier wall_thickness_target == undefined then
			(
				updateDynamicWallThickness value
			)
		)
	)

	on spn_ratio changed value do
	(
		saveWallThicknessRatio value
		updateWallThicknessScaledLabel()
	)

	on wallThicknessRollout close do
	(
		saveWallThicknessDialogPos()
	)

	on btn_create pressed do
	(
		if selection.count == 1 then
		(
			applyWallThickness selection[1] spn_thickness.value
		)
		else
		(
			messageBox "Select exactly one wall object." title:"Wall Thickness"
		)
	)

	on btn_finish pressed do
	(
		if selection.count == 1 then
		(
			finishWallThickness selection[1]
		)
		else
		(
			messageBox "Select exactly one wall object." title:"Wall Thickness"
		)
	)

	on btn_reset pressed do
	(
		if selection.count == 1 then
		(
			resetWallThickness selection[1]
		)
		else
		(
			messageBox "Select exactly one wall object." title:"Wall Thickness"
		)
	)

	on btn_clear_smoothing pressed do
	(
		clearWallSmoothingGroups()
	)

	on btn_test pressed do
	(
		createWallThicknessTest()
	)
)

callbacks.removeScripts id:wall_thickness_selection_callback_id
callbacks.addScript #selectionSetChanged "syncWallThicknessSpinnerToSelection()" id:wall_thickness_selection_callback_id

saved_dialog_pos = loadWallThicknessDialogPos()
if saved_dialog_pos == undefined then
(
	createDialog wallThicknessRollout
)
else
(
	createDialog wallThicknessRollout pos:saved_dialog_pos
)
