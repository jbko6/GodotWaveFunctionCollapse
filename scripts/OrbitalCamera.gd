extends Camera3D
## This and EasyOrbitalCamera both work the same.
##
## The description of the script, what it can do,
## and any further detail.
##
## @tutorial:            https://the/tutorial1/url.com
## @tutorial(Tutorial2): https://the/tutorial2/url.com
## @experimental


## The target node that the camera will look towards and rotate around.
@export var target_node : Node3D
var target

## The distance at which the camera will be positioned from the target.
@export var radius = 10.0

## Minimum zoom distance. Limits the radius length by clamping it to this value.
@export var zoom_min = 2.5
## Maximum zoom distance. Limits the radius length by clamping it to this value.
@export var zoom_max = 25.0

## The angle at which the camera will view the target from.
@export var angle_deg = 22.5

## The speed at which the camera will orbit around the target on the X axis.
@export var orbit_speed_x = 45.0
## The speed at which the camera will orbit around the target on the Y axis.
@export var orbit_speed_y = 11.25

var y_offset = 0.0
## The lowest point the camera can move to before stopping.
@export var y_offset_min = -10.0
## The highest point the camera can move to before stopping.
@export var y_offset_max = 10.0

## The mouse sensitivity for controlling the camera when pressing the middle mouse button.
@export var mouse_sensitivity = 0.025
## Inverts the mouse's vertical movement, but not the horizontal movement.
@export var mouse_inverted = false

## The speed in which the camera will adjust (lerp), when orbiting around the target.
@export var adjustment_speed = 2.50

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index==5 and event.pressed==true:
			radius = radius * 1.25
		elif event.button_index==4 and event.pressed==true:
			radius = radius / 1.25
		
		radius = clamp(radius, zoom_min, zoom_max)

	if Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		if event is InputEventMouseMotion:
			var mouse_movement = event.relative
			
			if mouse_movement.x < 0:
				angle_deg -= orbit_speed_x * mouse_sensitivity
			elif mouse_movement.x > 0:
				angle_deg += orbit_speed_x * mouse_sensitivity
			
			if not mouse_inverted:
				if mouse_movement.y < 0:
					y_offset += orbit_speed_y * mouse_sensitivity
				elif mouse_movement.y > 0:
					y_offset -= orbit_speed_y * mouse_sensitivity
			else:
				if mouse_movement.y > 0:
					y_offset += orbit_speed_y * mouse_sensitivity
				elif mouse_movement.y < 0:
					y_offset -= orbit_speed_y * mouse_sensitivity
			
			y_offset = clamp(y_offset, y_offset_min, y_offset_max)

func _process(delta):
	key_input(delta)
	if target_node:
		target = target_node.global_position
		orbit_camera(self, target, radius, angle_deg, y_offset)

func key_input(delta):
	if Input.is_action_pressed("ui_left"):
		angle_deg += orbit_speed_x * delta
	elif Input.is_action_pressed("ui_right"):
		angle_deg -= orbit_speed_x * delta

	if Input.is_action_pressed("ui_up"):
		y_offset += orbit_speed_y * delta
	elif Input.is_action_pressed("ui_down"):
		y_offset -= orbit_speed_y * delta
		
	y_offset = clamp(y_offset, y_offset_min, y_offset_max)

func orbit_camera(camera: Camera3D, center: Vector3, radius: float, angle_deg: float, y_offset: float = 0.0, look_at_center: bool = true) -> void:
	var angle_rad = deg_to_rad(angle_deg)
	var orbit_pos = Vector3(
		center.x + radius * cos(angle_rad),
		center.y + y_offset,
		center.z + radius * sin(angle_rad)
	)
	
	camera.global_transform.origin = lerp(camera.global_transform.origin, orbit_pos, get_physics_process_delta_time() * adjustment_speed)

	if look_at_center:
		camera.look_at(center, Vector3.UP)