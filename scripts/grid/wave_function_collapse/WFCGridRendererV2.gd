class_name WFCGridRenderer extends GridRenderer

var NO_POSSIBILITY_ERROR := "no_possibilities"

var DIRECTIONS := {
	Vector3i(-1, 0, 0) : "x-",
	Vector3i(1, 0, 0) : "x+",
	Vector3i(0, -1, 0) : "z-",
	Vector3i(0, 1, 0) : "z+",
	Vector3i(0, 0, -1) : "y+",
	Vector3i(0, 0, 1) : "y-",
}

@export_file("*.json") var prototype_data_json : String
@export_file("*.json") var prototype_possibility_data_json : String
@export_dir var mesh_folder : String

var prototype_data : Dictionary
var prototype_possibility_data : Dictionary
var prototype_meshes : Dictionary
var superposition_space : Array
var grid_size : Vector3i

var render_step := 0
var iterate_step := 0
var grid

func _input(event):
	# if event.is_action_pressed("proceed"):
	# 	if render_step < 2:
	# 		render_step += 1
	# 	if render_step == 1:
	# 		identify_all_possiblilities()
	# 	if render_step == 2:
	# 		if not is_collapsed():
	# 			iterate(grid)
	# 		else:
	# 			print("collapsed")
	# 	render_prototypes(grid)
	pass

func initialize_rendering(_grid : Array):
	grid = _grid
	# Load JSON files
	prototype_data = JSON.parse_string(FileAccess.get_file_as_string(prototype_data_json))
	prototype_possibility_data = JSON.parse_string(FileAccess.get_file_as_string(prototype_possibility_data_json))
	if typeof(prototype_data) != TYPE_DICTIONARY:
		push_error("Unexpected prototype data JSON")
	if typeof(prototype_possibility_data) != TYPE_DICTIONARY:
		push_error("Unexpected prototype possibility data JSON")
	
	# Load prototype meshes
	var meshes := DirAccess.open(mesh_folder)
	if meshes:
		meshes.list_dir_begin()
		var file_name := meshes.get_next()
		while file_name != "":
			if not meshes.current_is_dir() and '.import' not in file_name:
				prototype_meshes[file_name] = load(mesh_folder + "/" + file_name)
			file_name = meshes.get_next()

	# Set our grid size
	grid_size = Vector3i(len(grid), len(grid[0]), len(grid[0][0]))

	# Initialize the superposition space based on grid size
	superposition_space = []
	superposition_space.resize(grid_size.x)
	for i in grid_size.x:
		superposition_space[i] = []
		superposition_space[i].resize(grid_size.y)
		for j in grid_size.y:
			superposition_space[i][j] = []
			superposition_space[i][j].resize(grid_size.z)
			for k in grid_size.z:
				superposition_space[i][j][k] = [NO_POSSIBILITY_ERROR]

## Render entire grid
func render(_grid : Array):
	grid = _grid
	#render_step = 0
	identify_all_possiblilities()

	while not is_collapsed():
		iterate(grid)
	
	render_prototypes(grid)

## Update the rendering at a specific voxel.
func update_rendering(_grid : Array, _coord : Vector3i):
	render(grid)

## Cleanup rendering
func cleanup_rendering():
	pass

func iterate(_grid : Array) -> void:
	var coords := get_min_entropy_coord()
	collapse_voxel(coords)
	propagate_voxel(grid, coords)

func is_collapsed() -> bool:
	var collapsed := true
	for i in range(grid_size.x):
		for j in range(grid_size.y):
			for k in range(grid_size.z):
				if typeof(superposition_space[i][j][k]) == TYPE_ARRAY:
					collapsed = false
	return collapsed

## Checks if a coordinate is in the grid boundaries
func is_coord_in_bounds(coord : Vector3i) -> bool:
	if coord.x < 0 or coord.x >= grid_size.x or coord.y < 0 or coord.y >= grid_size.y or coord.z < 0 or coord.z >= grid_size.z:
		return false
	return true

## Identify prototype possibilites for every voxel in the grid based on its own cell type and on the cell types surrounding it. Mutates `superposition_space`.
func identify_all_possiblilities() -> void:
	for i in grid_size.x:
		for j in grid_size.y:
			for k in grid_size.z:
				identify_possibilities(Vector3i(i, j, k), false)

func identify_possibilities(coord : Vector3i, checkPrototype : bool):
	# To find the possibilites at a given cell, we will loop through its 6 sides and 
	# check what prototypes are possible based on its own voxel type and the neighboring 
	# voxel type.
	# A prototype must be possible on every side for it to be possible for the voxel 
	# as a whole.
	# So we count the repetitions each prototype appears in the possibility space of each
	# side. If it appears 6 times, it is valid for the voxel as a whole.

	var current_voxel_type_name : String = GridManager.CELL_TYPES.get(grid[coord.x][coord.y][coord.z])

	var prototype_repetitions := {}

	for d : Vector3i in DIRECTIONS.keys():
		var neighboring_coord := coord + d
		var neighbor_voxel_type_name : String
		var possible_direction_prototypes : Array
		if is_coord_in_bounds(neighboring_coord):
			neighbor_voxel_type_name = GridManager.CELL_TYPES.get(grid[neighboring_coord.x][neighboring_coord.y][neighboring_coord.z])

			# Check if this voxel has collapsed. If it is we can just use its selected prototype's neighbor array.
			# We do not want to do this if we are generating the superposition space after the user has just changed something, because then we make
			# assumptions based on the previous iteration of the superposition space.
			if typeof(superposition_space[neighboring_coord.x][neighboring_coord.y][neighboring_coord.z]) == TYPE_STRING and checkPrototype:
				var neighboring_prototype : String = superposition_space[neighboring_coord.x][neighboring_coord.y][neighboring_coord.z]
				# Check to make sure the neighbor's voxel type has not just changed to make the prototype invalid
				if neighboring_prototype in prototype_data[neighbor_voxel_type_name]:
					# If it has collapsed, just grab the possibilities directly from its neighbor array
					possible_direction_prototypes = prototype_data[neighbor_voxel_type_name][neighboring_prototype]['neighbors'][DIRECTIONS.get(d * -1)]
		else:
			# Coord is on one of the edges of our grid.
			# We'll just assume the edge has the same voxel type as our voxel.
			neighbor_voxel_type_name = current_voxel_type_name
		
		# We retrieve the possible prototypes in this direction from our JSON data
		if len(possible_direction_prototypes) == 0:
			possible_direction_prototypes = prototype_possibility_data[current_voxel_type_name][DIRECTIONS.get(d)][neighbor_voxel_type_name]

		# For every prototype we found, increment one to its repetition counter.
		for prototype in possible_direction_prototypes:
			if prototype in prototype_repetitions:
				prototype_repetitions[prototype] += 1
			else:
				prototype_repetitions[prototype] = 1
	
	# Now that we have the possible prototypes in every direction, we need to check which
	# prototypes got 6 repetitions and then append those prototypes to our final superposition
	# space.

	var possible_prototypes : Array = []

	for prototype in prototype_repetitions:
		if prototype_repetitions[prototype] == 6:
			possible_prototypes.append(prototype)
	
	# If there are more than one possible prototypes, remove empty.
	if len(possible_prototypes) > 1:
		possible_prototypes.erase("Empty")
	elif possible_prototypes == ["Empty"]:
		superposition_space[coord.x][coord.y][coord.z] = "Empty"
		return
	
	# If the prototype is just empty, remove the superposition state and just assign it the prototype.
	# Do later?
	
	superposition_space[coord.x][coord.y][coord.z] = possible_prototypes

## Locate the coordinate with the lowest entropy. Ignores voxels with an entropy of 1 because those voxels are not in a superposition.
func get_min_entropy_coord() -> Vector3i:
	var lowest_entropy := INF
	var lowest_entropy_coord := Vector3i(0, 0, 0)
	for i in range(grid_size.x):
		for j in range(grid_size.y):
			for k in range(grid_size.z):
				if typeof(superposition_space[i][j][k]) == TYPE_ARRAY:
					var entropy = len(superposition_space[i][j][k])
					if entropy < lowest_entropy:
						lowest_entropy = entropy
						lowest_entropy_coord = Vector3i(i, j, k)
	return lowest_entropy_coord

## Collapses the voxels superposition space to just one random prototype.
func collapse_voxel(coord : Vector3i):
	if len(superposition_space[coord.x][coord.y][coord.z]) == 0:
		superposition_space[coord.x][coord.y][coord.z] = [NO_POSSIBILITY_ERROR]
	var random_prototype : String = superposition_space[coord.x][coord.y][coord.z][0]
	superposition_space[coord.x][coord.y][coord.z] = String(random_prototype)
	# print("Collapsed ", coord, " to: ", random_prototype)

func propagate_voxel(_grid : Array, coord : Vector3i):
	var propagation_stack : Array[Vector3i] = [coord]
	var touched_voxels : Array[Vector3i] = []

	while len(propagation_stack) != 0:
		var current_coord : Vector3i = propagation_stack.pop_back()
		if current_coord not in touched_voxels:
			touched_voxels.append(current_coord)

		for d : Vector3i in DIRECTIONS.keys():
			var neighboring_coord = current_coord + d

			if is_coord_in_bounds(neighboring_coord) and typeof(superposition_space[neighboring_coord.x][neighboring_coord.y][neighboring_coord.z]) == TYPE_ARRAY:
				var neighbor_superposition_space : Array = superposition_space[neighboring_coord.x][neighboring_coord.y][neighboring_coord.z]
				var voxel_possible_neighbors = get_possible_neighbors(grid, current_coord, d)
				# print(d, " neighbors: ", voxel_possible_neighbors, ", superposition space: ", neighbor_superposition_space)

				for prototype in neighbor_superposition_space.duplicate():
					# print("Checking ", prototype)
					if prototype not in voxel_possible_neighbors:
						# print("Constraining: ", prototype)
						constrain_superposition_space(neighboring_coord, prototype)

						# Mark this voxel as 'touched' or changed
						if neighboring_coord not in touched_voxels:
							touched_voxels.append(neighboring_coord)
						
						# If the neighbor's superposition space is 0, we have introduced a continuity error due to our current prototype choice.
						# As such we must reset our and our neighbor's superposition spaces, outlaw the prototype we just tried, and regenerate.
						if len(neighbor_superposition_space) == 0:
							# Save the illegal prototype
							var illegal_prototype : String = superposition_space[current_coord.x][current_coord.y][current_coord.z]
							push_warning("Continuity error introduced! Outlawing '", illegal_prototype, "' and regenerating")

							# Reset superposition spaces we touched
							for touched_coord in touched_voxels:
								identify_possibilities(touched_coord, true)
							
							# Outlaw the illegal prototype that caused the continuity error from our set
							superposition_space[current_coord.x][current_coord.y][current_coord.z].erase(illegal_prototype)

						if neighboring_coord not in propagation_stack:
							propagation_stack.append(neighboring_coord)

func get_possible_neighbors(_grid : Array, coord : Vector3i, direction : Vector3i) -> Array[String]:
	var axis_name = DIRECTIONS.get(direction)
	var cell_type_name = GridManager.CELL_TYPES.get(grid[coord.x][coord.y][coord.z])
	var neighbors : Array[String] = []
	var possibilities : Array
	if typeof(superposition_space[coord.x][coord.y][coord.z]) == TYPE_ARRAY:
		possibilities = superposition_space[coord.x][coord.y][coord.z]
	else:
		possibilities = [superposition_space[coord.x][coord.y][coord.z]]
	for possibility in possibilities:  
		for neighbor in prototype_data[cell_type_name][possibility]["neighbors"][axis_name]:
			if neighbor not in neighbors:
				neighbors.append(neighbor)
	return neighbors

func constrain_superposition_space(coord : Vector3i, prototype : String):
	superposition_space[coord.x][coord.y][coord.z].erase(prototype)

func render_prototypes(_grid : Array) -> void:
	var children = get_children()
	for child in children:
		child.queue_free()
	for i in range(len(grid)):
		for j in range(len(grid[i])):
			for k in range(len(grid[i][j])):
				if typeof(superposition_space[i][j][k]) == TYPE_STRING:
					var prototype_name = superposition_space[i][j][k]
					if prototype_name != "Empty":
						var cell_type_name : String = GridManager.CELL_TYPES.get(grid[i][j][k])
						var prototype_dict : Dictionary = prototype_data[cell_type_name][prototype_name]
						var mesh = prototype_meshes[prototype_dict["mesh"]].instantiate()
						add_child(mesh)
						mesh.position = Vector3i(i, j, k)
						if prototype_dict["mesh_rotation"] != -1:
							mesh.rotate_y(0.5 * PI * int(prototype_dict["mesh_rotation"]))
