extends Node3D

@export var wfc : WFCGridRenderer

var camera : Camera3D

var last_intersection : Dictionary

func _ready():
	camera = get_viewport().get_camera_3d()

func _input(event : InputEvent) -> void:
	if event.is_action_pressed("interact"):
		update_position()
		var newCellPos = round(last_intersection.position - last_intersection.normal / 10.)
		print(wfc.superposition_space[newCellPos.x][newCellPos.y][newCellPos.z])

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
		last_intersection = ray_result
