extends MeshInstance3D

signal user_set_cell(world_pos : Vector3, cell_type : int)

var camera : Camera3D

var last_intersection : Dictionary
var last_down : float

func _ready():
	camera = get_viewport().get_camera_3d()

func _input(event : InputEvent) -> void:
	if event is InputEventMouse or event is InputEventMouseButton:
		update_position()
		if event is InputEventMouseButton:
			if event.is_pressed():
				last_down = Time.get_ticks_msec()
			elif Time.get_ticks_msec() - last_down < 200:
				if event.button_index == MOUSE_BUTTON_LEFT:
					var newCellPos = last_intersection.position + last_intersection.normal / 10.
					user_set_cell.emit(newCellPos, GridManager.CELL_TYPES.find_key("grass"))
				elif event.button_index == MOUSE_BUTTON_RIGHT:
					var delCellPos = last_intersection.position - last_intersection.normal / 10.
					user_set_cell.emit(delCellPos, GridManager.CELL_TYPES.find_key("air"))

func update_position() -> void:
	var mouse_position = get_viewport().get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_position)
	var ray_direction = camera.project_ray_normal(mouse_position)

	var space_state = get_world_3d().direct_space_state
	var ray_length = 10000.0
	var ray_parameters = PhysicsRayQueryParameters3D.new()
	ray_parameters.from = ray_origin
	ray_parameters.to = ray_origin + ray_direction * ray_length
	var ray_result = space_state.intersect_ray(ray_parameters)

	if ray_result:
		global_transform.origin = ray_result.position
		last_intersection = ray_result
