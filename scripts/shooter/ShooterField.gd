extends Node3D
class_name ShooterField
## Builds the open 40x20 tile grass field for the Multiplayer Shootout mode:
## one flat walkable slab plus boundary walls so a wandering player can't
## walk off into the void. Kept deliberately simple/flat (unlike Terrain.gd's
## hills) - the whole point of this mode is that positioning reads entirely
## through footsteps, the proximity beacon and gunfire, not sightlines.

const TILE_SIZE := 4.0
const LENGTH_TILES := 40 # X axis
const WIDTH_TILES := 20 # Z axis
const FIELD_LENGTH := TILE_SIZE * LENGTH_TILES # 160m
const FIELD_WIDTH := TILE_SIZE * WIDTH_TILES # 80m
const WALL_HEIGHT := 6.0
const WALL_THICKNESS := 1.0

## Fixed, well-spread spawn points (mirrors Character.gd's SPAWN_X_POINTS
## idiom) so respawns land players apart from each other rather than at a
## fully random - possibly adjacent - spot.
const SPAWN_POINTS: Array[Vector3] = [
	Vector3(-60.0, 0.1, -30.0),
	Vector3(60.0, 0.1, 30.0),
	Vector3(-60.0, 0.1, 30.0),
	Vector3(60.0, 0.1, -30.0),
	Vector3(0.0, 0.1, 0.0),
	Vector3(0.0, 0.1, -35.0),
]

func _ready() -> void:
	_build_ground()
	_build_boundary_walls()

func _build_ground() -> void:
	var body := StaticBody3D.new()
	body.name = "Ground"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(FIELD_LENGTH, 1.0, FIELD_WIDTH)
	shape.shape = box
	shape.position = Vector3(0.0, -0.5, 0.0)
	body.add_child(shape)
	add_child(body)

	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(FIELD_LENGTH, 1.0, FIELD_WIDTH)
	mesh_instance.mesh = mesh
	mesh_instance.position = Vector3(0.0, -0.5, 0.0)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.22, 0.5, 0.18)
	mesh_instance.material_override = material
	add_child(mesh_instance)

func _build_boundary_walls() -> void:
	var half_length := FIELD_LENGTH / 2.0
	var half_width := FIELD_WIDTH / 2.0
	_build_wall(Vector3(0.0, WALL_HEIGHT / 2.0, -half_width), Vector3(FIELD_LENGTH + WALL_THICKNESS * 2.0, WALL_HEIGHT, WALL_THICKNESS))
	_build_wall(Vector3(0.0, WALL_HEIGHT / 2.0, half_width), Vector3(FIELD_LENGTH + WALL_THICKNESS * 2.0, WALL_HEIGHT, WALL_THICKNESS))
	_build_wall(Vector3(-half_length, WALL_HEIGHT / 2.0, 0.0), Vector3(WALL_THICKNESS, WALL_HEIGHT, FIELD_WIDTH + WALL_THICKNESS * 2.0))
	_build_wall(Vector3(half_length, WALL_HEIGHT / 2.0, 0.0), Vector3(WALL_THICKNESS, WALL_HEIGHT, FIELD_WIDTH + WALL_THICKNESS * 2.0))

func _build_wall(center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "Wall_%d_%d" % [int(center.x), int(center.z)]
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = center
	body.add_child(shape)
	add_child(body)

func random_spawn_point() -> Vector3:
	return SPAWN_POINTS[randi() % SPAWN_POINTS.size()]
