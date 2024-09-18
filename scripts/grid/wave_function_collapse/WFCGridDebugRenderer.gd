extends GridRenderer

@export var wfc : WFCGridRenderer

var debug_labels : Array
var grid_size : Vector3i

func initialize_rendering(grid : Array):
	grid_size = Vector3i(len(grid), len(grid[0]), len(grid[0][0]))
	
	debug_labels = []
	debug_labels.resize(grid_size.x)
	for i in grid_size.x:
		debug_labels[i] = []
		debug_labels[i].resize(grid_size.y)
		for j in grid_size.y:
			debug_labels[i][j] = []
			debug_labels[i][j].resize(grid_size.z)
			for k in grid_size.z:
				var label = Label3D.new()
				label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
				label.position = Vector3(i, j, k)
				add_child(label)
				label.name = str(Vector3(i, j, k))
				debug_labels[i][j][k] = label

func _process(_delta):
	for i in grid_size.x:
		for j in grid_size.y:
			for k in grid_size.z:
				var label = debug_labels[i][j][k]
				var superposition = wfc.superposition_space[i][j][k]
				if typeof(superposition) == TYPE_STRING:
					label.text = "1"
				else:
					label.text = str(len(wfc.superposition_space[i][j][k]))

## Render entire grid
func render(_grid : Array):
	pass

## Update the rendering at a specific cell.
func update_rendering(_grid : Array, _cell_pos : Vector3i):
	render(_grid)

func cleanup_rendering():
	for i in grid_size.x:
		for j in grid_size.y:
			for k in grid_size.z:
				debug_labels[i][j][k].queue_free()
