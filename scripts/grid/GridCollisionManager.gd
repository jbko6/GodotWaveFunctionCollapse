class_name GridCollisionManager extends StaticBody3D

## Generate collision shapes for grid. 
func generate(grid : Array):
    var children = get_children()
    for child in children:
        if child is CollisionShape3D:
            child.queue_free()
    
    for i in range(len(grid)):
        for j in range(len(grid[i])):
            for k in range(len(grid[i][j])):
                var cell_has_collision = GridManager.CELL_COLLISION.get(grid[i][j][k])
                if cell_has_collision:
                    add_cell_collison(Vector3i(i, j, k))

func update_collision(grid : Array, cell_pos : Vector3i):
    var children = get_children()
    var has_collision = false
    for child in children:
        if child.name == str(cell_pos):
            has_collision = true

    var cell_has_collision = GridManager.CELL_COLLISION.get(grid[cell_pos.x][cell_pos.y][cell_pos.z])
    if cell_has_collision:
        if not has_collision:
            add_cell_collison(cell_pos)
    else:
        if has_collision:
            remove_cell_collision(cell_pos)


func add_cell_collison(pos : Vector3i):
    var collider = CollisionShape3D.new()
    collider.shape = BoxShape3D.new()
    collider.name = str(Vector3i(pos.x, pos.y, pos.z))
    add_child(collider)
    collider.position = pos

func remove_cell_collision(pos : Vector3i):
    var children = get_children()
    for child in children:
        if child.name == str(pos):
            child.queue_free()