class_name GridRenderer extends Node3D

func initialize_rendering(_grid : Array):
	pass

## Render entire grid
func render(_grid : Array):
	pass

## Update the rendering at a specific cell.
func update_rendering(_grid : Array, _cell_pos : Vector3i):
	pass

func cleanup_rendering():
	pass
