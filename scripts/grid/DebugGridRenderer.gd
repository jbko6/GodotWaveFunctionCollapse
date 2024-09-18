extends GridRenderer

var mesh_instance : MeshInstance3D

func initialize_rendering(_grid : Array):
    if mesh_instance != null:
        cleanup_rendering()

    mesh_instance = MeshInstance3D.new()
    add_child(mesh_instance)

func render(grid : Array):
    render_points(grid)

func update_rendering(grid : Array, _cell_pos : Vector3i):
    render_points(grid)

func render_points(grid):
    var vertices = PackedVector3Array()
    var colors = PackedColorArray()
    for i in range(len(grid)):
        for j in range(len(grid[i])):
            for k in range(len(grid[i][j])):
                vertices.push_back(Vector3(i, j, k))
                if grid[i][j][k] == 0:
                    colors.push_back(Color(255, 255, 255))
                else:
                    colors.push_back(Color(255, 0, 0))

    var debug_mesh = ArrayMesh.new()
    var arrays = []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_COLOR] = colors

    debug_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_POINTS, arrays)
    mesh_instance.mesh = debug_mesh

    var point_material = StandardMaterial3D.new()
    point_material.use_point_size = true
    point_material.point_size = 5
    point_material.vertex_color_use_as_albedo = true
    mesh_instance.material_override = point_material

func cleanup_rendering():
    mesh_instance.queue_free()
    mesh_instance = null
