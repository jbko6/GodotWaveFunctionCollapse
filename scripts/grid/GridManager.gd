class_name GridManager extends Node3D

static var CELL_TYPES = {
	0 : "air",
	1 : "grass",
	2 : "road",
}

static var CELL_COLLISION = {
	0 : false,
	1 : true,
	2 : true
}

@export var GRID_DIMENSIONS = Vector3(5, 5, 5)

@export var renderers : Array[GridRenderer]
@export var collision_manager : GridCollisionManager

var grid = []

func _ready():
	initialize_grid()
	for renderer in renderers:
		renderer.initialize_rendering(grid)
		renderer.render(grid)
	if collision_manager:
		collision_manager.generate(grid)

## Initialize the grid.
## Doing so will erase any current grid data.
func initialize_grid():
	grid = []
	grid.resize(GRID_DIMENSIONS.x)
	for i in GRID_DIMENSIONS.x:
		grid[i] = []
		grid[i].resize(GRID_DIMENSIONS.y)
		for j in GRID_DIMENSIONS.y:
			grid[i][j] = PackedInt32Array()
			grid[i][j].resize(GRID_DIMENSIONS.z)
			for k in GRID_DIMENSIONS.z:
				grid[i][j][k] = 0
	
	for i in GRID_DIMENSIONS.x:
		for k in GRID_DIMENSIONS.z:
			grid[i][0][k] = 1

## Check if a cell position is in the grid
func is_cell_pos_valid(cell_pos : Vector3i) -> bool:
	if cell_pos.x < 0 or cell_pos.x >= GRID_DIMENSIONS.x or cell_pos.y < 0 or cell_pos.y >= GRID_DIMENSIONS.y or cell_pos.z < 0 or cell_pos.z >= GRID_DIMENSIONS.z:
		return false
	return true

## Set a cell's type via its position
func set_cell(cell_pos : Vector3i, cell_type : int):
	if not is_cell_pos_valid(cell_pos):
		push_warning("Cell pos out of range: ", cell_pos)
		return

	grid[cell_pos.x][cell_pos.y][cell_pos.z] = cell_type

	for renderer in renderers:
		renderer.update_rendering(grid, cell_pos)
	if collision_manager:
		collision_manager.update_collision(grid, cell_pos)

func set_cell_world_pos(world_pos : Vector3, cell_type : int):
	var cell_pos = world_pos_to_cell_pos(world_pos)
	set_cell(cell_pos, cell_type)

## Get a cell's type via its position
func get_cell(cell_pos : Vector3i) -> int:
	if not is_cell_pos_valid(cell_pos):
		push_warning("Cell pos out of range: ", cell_pos)
		return 0

	return grid[cell_pos.x][cell_pos.y][cell_pos.z]

## Fill the grid with one cell type.
func fill_grid(cell_type : int):
	for i in GRID_DIMENSIONS.x:
		for j in GRID_DIMENSIONS.y:
			for k in GRID_DIMENSIONS.z:
				set_cell(Vector3i(i, j, k), cell_type)

func world_pos_to_cell_pos(world_pos : Vector3):
	return round(to_local(world_pos))
