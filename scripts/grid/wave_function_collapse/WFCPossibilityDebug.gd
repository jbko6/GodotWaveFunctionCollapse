extends Node3D

var DIRECTIONS := {
	Vector3i(-1, 0, 0) : "x-",
	Vector3i(1, 0, 0) : "x+",
	Vector3i(0, -1, 0) : "z-",
	Vector3i(0, 1, 0) : "z+",
	Vector3i(0, 0, -1) : "y+",
	Vector3i(0, 0, 1) : "y-",
}

@export_file("*.json") var prototype_data_json : String
@export_file("*.json") var possibility_data_json : String
@export_dir() var mesh_folder : String

var possibility_data : Dictionary
var prototype_data : Dictionary
var prototype_meshes : Dictionary
var side_data = {0:0, 1:0, 2:0, 3:0, 4:0, 5:0}
var current_possibilities : Array = []
var current_possibility_index : int = 0
var current_prototype : String
var prototype_mesh

func _ready():
	prototype_data = JSON.parse_string(FileAccess.get_file_as_string(prototype_data_json))
	possibility_data = JSON.parse_string(FileAccess.get_file_as_string(possibility_data_json))
	identify_possibilities()

	var meshes := DirAccess.open(mesh_folder)
	if meshes:
		meshes.list_dir_begin()
		var file_name := meshes.get_next()
		while file_name != "":
			if not meshes.current_is_dir() and '.import' not in file_name:
				prototype_meshes[file_name] = load(mesh_folder + "/" + file_name)
			file_name = meshes.get_next()

	while true:
		await get_tree().create_timer(1).timeout
		if current_possibility_index >= len(current_possibilities):
			current_possibility_index = 0
		if prototype_mesh:
			prototype_mesh.queue_free()
		current_prototype = current_possibilities[current_possibility_index]
		print(current_possibility_index, " : ", current_prototype)
		var cell_type_name : String = GridManager.CELL_TYPES.get(1)
		var prototype_dict : Dictionary = prototype_data[cell_type_name][current_prototype]
		if prototype_dict["mesh"] != "":
			prototype_mesh = prototype_meshes[prototype_dict["mesh"]].instantiate()
			add_child(prototype_mesh)
			if prototype_dict["mesh_rotation"] != -1:
				prototype_mesh.rotate_y(-0.5 * PI * int(prototype_dict["mesh_rotation"]))
		current_possibility_index += 1

func identify_possibilities():
	var current_voxel_type_name : String = GridManager.CELL_TYPES.get(1)

	var prototype_repetitions := {}

	for d : Vector3i in DIRECTIONS.keys():
		var neighbor_voxel_type_name : String
		neighbor_voxel_type_name = GridManager.CELL_TYPES.get(side_data[DIRECTIONS.keys().find(d)])
		
		var possible_direction_prototypes : Array = possibility_data[current_voxel_type_name][DIRECTIONS.get(d)][neighbor_voxel_type_name]

		for prototype in possible_direction_prototypes:
			if prototype in prototype_repetitions:
				prototype_repetitions[prototype] += 1
			else:
				prototype_repetitions[prototype] = 1
	
	var possible_prototypes : Array[String] = []

	for prototype in prototype_repetitions:
		if prototype_repetitions[prototype] == 6:
			possible_prototypes.append(prototype)
	
	if len(possible_prototypes) > 1:
		possible_prototypes.erase("Empty")
	
	current_possibilities = possible_prototypes

func _input(event):
	if event.is_action_pressed("debug_side_0"):
		side_data[0] = 1 if side_data[0] == 0 else 0
		identify_possibilities()
	if event.is_action_pressed("debug_side_1"):
		side_data[1] = 1 if side_data[1] == 0 else 0
		identify_possibilities()
	if event.is_action_pressed("debug_side_2"):
		side_data[2] = 1 if side_data[2] == 0 else 0
		identify_possibilities()
	if event.is_action_pressed("debug_side_3"):
		side_data[3] = 1 if side_data[3] == 0 else 0
		identify_possibilities()
	if event.is_action_pressed("debug_side_4"):
		side_data[4] = 1 if side_data[4] == 0 else 0
		identify_possibilities()
	if event.is_action_pressed("debug_side_5"):
		side_data[5] = 1 if side_data[5] == 0 else 0
		identify_possibilities()
