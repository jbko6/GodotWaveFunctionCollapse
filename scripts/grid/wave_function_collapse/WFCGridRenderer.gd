extends GridRenderer

@export_file("*.json") var prototype_json : String
@export_dir() var mesh_folder : String

var prototype_data : Dictionary
var all_posibilities : Array
var superposition_space : Array
var cell_type_map : Dictionary
var cell_neighbor_map : Dictionary
var grid_size : Vector3i
var prototype_meshes : Dictionary

signal user_input()

var axis_names := {
	Vector3i(-1, 0, 0) : "x-",
	Vector3i(1, 0, 0) : "x+",
	Vector3i(0, -1, 0) : "z-",
	Vector3i(0, 1, 0) : "z+",
	Vector3i(0, 0, -1) : "y-",
	Vector3i(0, 0, 1) : "y+",
}

func initialize_rendering(grid : Array) -> void:
	var json_as_string = FileAccess.get_file_as_string(prototype_json)
	prototype_data = JSON.parse_string(json_as_string)
	if typeof(prototype_data) != TYPE_DICTIONARY:
		push_error("Unexpected JSON Data")
	
	var meshes := DirAccess.open(mesh_folder)
	if meshes:
		meshes.list_dir_begin()
		var file_name := meshes.get_next()
		while file_name != "":
			if not meshes.current_is_dir() and '.import' not in file_name:
				prototype_meshes[file_name] = load(mesh_folder + "/" + file_name)
			file_name = meshes.get_next()

	grid_size = Vector3i(len(grid), len(grid[0]), len(grid[0][0]))
	
	## List of all possible prototype names
	all_posibilities = []
	## Dictionary mapping cell types to their possible prototypes
	cell_type_map = {}
	## Dictionary mapping cell type neighbor types to their possible prototypes
	cell_neighbor_map = {}

	for type in prototype_data:
		cell_type_map[type] = []
		cell_neighbor_map[type] = {}
		for prototype_key in prototype_data[type]:
			all_posibilities.append(prototype_key)
			# if prototype_key != "Empty":
			cell_type_map[type].append(prototype_key)

	for type in prototype_data:
		for prototype_key in prototype_data[type]:
			for d in prototype_data[type][prototype_key]["neighbors"]:
				if d not in cell_neighbor_map[type]:
					cell_neighbor_map[type][d] = {}
				for prototype in prototype_data[type][prototype_key]["neighbors"][d]:
					var prototype_type : String = deep_find_key(cell_type_map, prototype)
					if prototype_type not in cell_neighbor_map[type][d]:
						cell_neighbor_map[type][d][prototype_type] = []
					if prototype_key not in cell_neighbor_map[type][d][prototype_type]:
						cell_neighbor_map[type][d][prototype_type].append(prototype_key)

	reset_superposition_space()

func _input(event):
	if event.is_action_pressed("proceed"):
		user_input.emit()

func deep_find_key(dict : Dictionary, value):
	var key = null
	for list_key in dict:
		for item_index in len(dict[list_key]):
			if dict[list_key][item_index] == value:
				key = list_key
	return key

func render(grid : Array) -> void:
	# reset_superposition_space()
	# cell_type_collapse_superposition_space(grid)
	add_possible_neighbors_to_superposition_space(grid)
	#collapse_edges()

	var iters := 0
	while not is_collapsed() and iters < 1:
		iterate(grid)
		iters += 1
	
	render_superposition_space(grid)

func update_rendering(grid : Array, _cell_pos : Vector3i) -> void:
	render(grid)

func is_collapsed() -> bool:
	var collapsed := true
	for i in range(grid_size.x):
		for j in range(grid_size.y):
			for k in range(grid_size.z):
				if len(superposition_space[i][j][k]) > 1:
					collapsed = false
	return collapsed

func iterate(grid : Array) -> void:
	var coords := get_min_entropy_coords()
	print("Min entropy coords: ", coords)
	# await user_input
	# await get_tree().create_timer(0.2).timeout
	collapse_at(coords)
	# await user_input
	# await get_tree().create_timer(0.2).timeout
	propogate(grid, coords)
	# await user_input
	# await get_tree().create_timer(0.2).timeout

func get_min_entropy_coords() -> Vector3i:
	var lowest_entropy := INF
	var lowest_entropy_coord := Vector3i(0, 0, 0)
	for i in range(grid_size.x):
		for j in range(grid_size.y):
			for k in range(grid_size.z):
				var entropy = len(superposition_space[i][j][k])
				if entropy < lowest_entropy && entropy != 1:
					lowest_entropy = entropy
					lowest_entropy_coord = Vector3i(i, j, k)
	return lowest_entropy_coord

func collapse_at(cell_pos : Vector3i) -> void:
	var random_prototype : String = get_possibilities(cell_pos).pick_random()
	
	print("Collapsed to: " + random_prototype)
	superposition_space[cell_pos.x][cell_pos.y][cell_pos.z] = [random_prototype]

func propogate(grid : Array, cell_pos : Vector3i) -> void:
	var propogation_stack : Array[Vector3i] = [cell_pos]
	print("Began propogating at: ", cell_pos)

	while len(propogation_stack) > 0:
		var cur_coords : Vector3i = propogation_stack.pop_back()
		print("Evaluating for: ", cur_coords)

		for d in valid_dirs():
			var other_coords := cur_coords + d
			print("Propogating at direction: ", other_coords)
			if not is_cell_pos_valid(other_coords):
				continue
			var other_possible_prototypes := get_possibilities(other_coords)
			print("Possible prototypes: ", len(other_possible_prototypes))

			var possible_neighbors := get_possible_neighbors(grid, cur_coords, d)
			print("Possible neighbors: ", len(possible_neighbors))

			if len(other_possible_prototypes) <= 1:
				continue
			
			for other_prototype in other_possible_prototypes:
				if other_prototype not in possible_neighbors:
					constrain(other_coords, other_prototype)
					if not other_coords in propogation_stack:
						propogation_stack.append(other_coords)
						print("Added to stack: ", other_coords)
			print("Collapsed " , str(other_coords), " to ", len(get_possibilities(other_coords)), " possibilities")
		print("Current stack length: ", len(propogation_stack))

func constrain(cell_pos : Vector3i, prototype : String) -> void:
	superposition_space[cell_pos.x][cell_pos.y][cell_pos.z].erase(prototype)

func get_possibilities(cell_pos : Vector3i) -> Array:
	return superposition_space[cell_pos.x][cell_pos.y][cell_pos.z].duplicate()

func get_possible_neighbors(grid : Array, cell_pos : Vector3i, direction : Vector3i) -> Array[String]:
	var axis_name = axis_names.get(direction)
	var cell_type = get_cell_type_name(grid, cell_pos)
	var neighbors : Array[String] = []
	for possibility in superposition_space[cell_pos.x][cell_pos.y][cell_pos.z]:
		if possibility != "Empty":
			for neighbor in prototype_data[cell_type][possibility]["neighbors"][axis_name]:
				if neighbor not in neighbors:
					neighbors.append(neighbor)
		else:
			for neighbor in prototype_data["air"][possibility]["neighbors"][axis_name]:
				if neighbor not in neighbors:
					neighbors.append(neighbor)
	return neighbors

func valid_dirs() -> Array[Vector3i]:
	return [
		Vector3i(-1, 0, 0),
		Vector3i(1, 0, 0),
		Vector3i(0, -1, 0),
		Vector3i(0, 1, 0),
		Vector3i(0, 0, -1),
		Vector3i(0, 0, 1),
	]

func get_cell_type_name(grid : Array, cell_pos : Vector3i) -> String:
	if not is_cell_pos_valid(cell_pos):
		return "boundary"
	var cell_type_index = grid[cell_pos.x][cell_pos.y][cell_pos.z]
	var cell_type_name = GridManager.CELL_TYPES.get(cell_type_index)
	return cell_type_name

func is_cell_pos_valid(cell_pos : Vector3i) -> bool:
	if cell_pos.x < 0 or cell_pos.x >= grid_size.x or cell_pos.y < 0 or cell_pos.y >= grid_size.y or cell_pos.z < 0 or cell_pos.z >= grid_size.z:
		return false
	return true

func collapse_edges() -> void:
	for axis in range(3):
		for axis_sign in [-1, 1]:
			var inverse_direction_vector = Vector3i(0, 0, 0)
			inverse_direction_vector[axis] = -axis_sign
			var axis_name = axis_names.get(inverse_direction_vector)

			var constValue = 0 if axis_sign == -1 else grid_size[axis] - 1
			var edge_neighbors = prototype_data["air"]["Empty"]["neighbors"][axis_name]
			for i in range(grid_size[(axis + 1) % 3]):
				for j in range(grid_size[(axis + 2) % 3]):
					var current_coords = Vector3i()
					current_coords[axis] = constValue
					current_coords[(axis + 1) % 3] = i
					current_coords[(axis + 2) % 3] = j

					var current_possibilities = get_possibilities(current_coords)

					for possibility in current_possibilities:
						if possibility not in edge_neighbors:
							constrain(current_coords, possibility)

func add_possible_neighbors_to_superposition_space(grid : Array) -> void:
	for i in range(len(grid)):
		for j in range(len(grid[i])):
			for k in range(len(grid[i][j])):
				var possible_prototypes = {}
				var cell_type := get_cell_type_name(grid, Vector3i(i, j, k))

				for d in valid_dirs():
					var dir_key = axis_names.get(d)
					var neighbor_cell_pos = Vector3i(i, j, k) + d
					var neighbor_cell_type = get_cell_type_name(grid, neighbor_cell_pos)
					var prototypes
					if neighbor_cell_type == "boundary":
						prototypes = all_posibilities
					else:
						prototypes = cell_neighbor_map[cell_type][dir_key][neighbor_cell_type]
					for prototype in prototypes:
						if prototype not in possible_prototypes:
							possible_prototypes[prototype] = 0
						else:
							possible_prototypes[prototype] += 1
				
				var combined_prototypes = []
				for prototype in possible_prototypes:
					if possible_prototypes[prototype] == 5:
						combined_prototypes.append(prototype)
				superposition_space[i][j][k] = combined_prototypes
				print(possible_prototypes)

func render_superposition_space(grid : Array) -> void:
	# print(superposition_space)
	var children = get_children()
	for child in children:
		child.queue_free()
	for i in range(len(grid)):
		for j in range(len(grid[i])):
			for k in range(len(grid[i][j])):
				if superposition_space[i][j][k] != ["Empty"]:
					if len(superposition_space[i][j][k]) > 0:
						var prototype_name = superposition_space[i][j][k][0]
						if prototype_name != "Empty":
							var cell_type = get_cell_type_name(grid, Vector3i(i, j, k))
							var prototype_dict = prototype_data[cell_type][prototype_name]
							var mesh = prototype_meshes[prototype_dict["mesh"]].instantiate()
							add_child(mesh)
							mesh.position = Vector3i(i, j, k)
							if prototype_dict["mesh_rotation"] != -1:
								mesh.rotate_y(0.5 * PI * int(prototype_dict["mesh_rotation"]))

## Collapse superposition space of each cell to only the prototypes of its cell type.
func cell_type_collapse_superposition_space(grid : Array) -> void:
	for i in range(len(grid)):
		for j in range(len(grid[i])):
			for k in range(len(grid[i][j])):
				var cell_type = get_cell_type_name(grid, Vector3i(i, j, k))
				var cell_type_prototypes = cell_type_map[cell_type]
				superposition_space[i][j][k] = cell_type_prototypes.duplicate()

## Reset superposition space so that every cell could be every possible prototype
func reset_superposition_space() -> void:
	superposition_space = []
	superposition_space.resize(grid_size.x)
	for i in range(grid_size.x):
		superposition_space[i] = []
		superposition_space[i].resize(grid_size.y)
		for j in range(grid_size.y):
			superposition_space[i][j] = []
			superposition_space[i][j].resize(grid_size.z)
			for k in range(grid_size.z):
				superposition_space[i][j][k] = all_posibilities.duplicate()


## potential solution:
## as a voxel is placed, identify possible prototypes based on the voxel types around it so that an incompatible voxel type is never selected
