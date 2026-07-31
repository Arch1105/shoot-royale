extends Node2D
## Builds the 100-tile grass field (~6400px wide) in code: one continuous
## flat ground, plus two raised rock/grass hill platforms the player must
## jump onto - walking into one from ground level bumps into solid rock,
## walking off the top without controlling the descent (see Character.gd's
## descend_slow) means a real fall, possibly fatal. Also places Area2D zones
## that announce incline/summit/decline/flat transitions via Voice.

const GROUND_Y := 600.0
const WALL_HEIGHT := 2000.0
const TILE_SIZE := 64.0
const MAP_LEFT := 0.0
const MAP_RIGHT := 6400.0

## Each hill: x range at ground level, and how tall the platform is.
const HILLS: Array[Dictionary] = [
	{"range": Vector2(1200, 2000), "height": 300.0},
	{"range": Vector2(4400, 5200), "height": 400.0},
]

const ZONE_LEAD_IN := 150.0 # how far before a hill's face the incline/decline warning starts
const ZONE_EDGE_MARGIN := 60.0 # how far inside the summit edge the decline warning starts

func _ready() -> void:
	_build_flat_ground()
	_build_grass_tile_lines()
	_build_boundary_walls()
	for hill in HILLS:
		_build_hill(hill["range"], hill["height"])
	_build_zones()

func _build_flat_ground() -> void:
	var body := StaticBody2D.new()
	body.name = "GroundBody"
	var poly := CollisionPolygon2D.new()
	poly.polygon = PackedVector2Array([
		Vector2(MAP_LEFT, GROUND_Y), Vector2(MAP_RIGHT, GROUND_Y),
		Vector2(MAP_RIGHT, GROUND_Y + WALL_HEIGHT), Vector2(MAP_LEFT, GROUND_Y + WALL_HEIGHT),
	])
	body.add_child(poly)
	add_child(body)

	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array([
		Vector2(MAP_LEFT, GROUND_Y), Vector2(MAP_RIGHT, GROUND_Y),
		Vector2(MAP_RIGHT, GROUND_Y + 60), Vector2(MAP_LEFT, GROUND_Y + 60),
	])
	visual.color = Color(0.22, 0.5, 0.18)
	add_child(visual)

func _build_grass_tile_lines() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	var x: float = MAP_LEFT
	while x < MAP_RIGHT:
		var tile := Polygon2D.new()
		var shade: float = rng.randf_range(-0.04, 0.05)
		tile.color = Color(0.24 + shade, 0.58 + shade, 0.2 + shade)
		tile.polygon = PackedVector2Array([
			Vector2(x + 2, GROUND_Y), Vector2(x + TILE_SIZE - 2, GROUND_Y),
			Vector2(x + TILE_SIZE - 2, GROUND_Y + 10), Vector2(x + 2, GROUND_Y + 10),
		])
		add_child(tile)
		x += TILE_SIZE

func _build_boundary_walls() -> void:
	for edge_x in [MAP_LEFT, MAP_RIGHT]:
		var body := StaticBody2D.new()
		body.name = "Wall_%d" % edge_x
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(20.0, WALL_HEIGHT + 800.0)
		shape.shape = rect
		shape.position = Vector2(edge_x, GROUND_Y - 400.0)
		body.add_child(shape)
		add_child(body)

## A hill is a solid rectangular platform sitting on the ground: its top is
## a walkable summit reached only by jumping, and both of its vertical faces
## block horizontal movement from ground level (bump into rock, must jump).
func _build_hill(x_range: Vector2, height: float) -> void:
	var top_y: float = GROUND_Y - height
	var body := StaticBody2D.new()
	body.name = "Hill_%d" % x_range.x
	body.add_to_group("incline_wall")
	var poly := CollisionPolygon2D.new()
	poly.polygon = PackedVector2Array([
		Vector2(x_range.x, top_y), Vector2(x_range.y, top_y),
		Vector2(x_range.y, GROUND_Y + WALL_HEIGHT), Vector2(x_range.x, GROUND_Y + WALL_HEIGHT),
	])
	body.add_child(poly)
	add_child(body)

	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array([
		Vector2(x_range.x, top_y), Vector2(x_range.y, top_y),
		Vector2(x_range.y, GROUND_Y), Vector2(x_range.x, GROUND_Y),
	])
	visual.color = Color(0.42, 0.38, 0.34)
	add_child(visual)

	var top_strip := Polygon2D.new()
	top_strip.polygon = PackedVector2Array([
		Vector2(x_range.x, top_y), Vector2(x_range.y, top_y),
		Vector2(x_range.y, top_y + 14), Vector2(x_range.x, top_y + 14),
	])
	top_strip.color = Color(0.26, 0.56, 0.2)
	add_child(top_strip)

func _make_zone(x_from: float, x_to: float, y_center: float, voice_key: String) -> void:
	var area := Area2D.new()
	area.name = "Zone_%s_%d" % [voice_key, x_from]
	area.set_script(preload("res://scripts/ZoneAnnouncer.gd"))
	area.voice_key = voice_key
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(x_to - x_from, 250.0)
	shape.shape = rect
	shape.position = Vector2((x_from + x_to) / 2.0, y_center)
	area.add_child(shape)
	add_child(area)

func _build_zones() -> void:
	for hill in HILLS:
		var x_range: Vector2 = hill["range"]
		var height: float = hill["height"]
		var top_y: float = GROUND_Y - height
		# Approaching either face from ground level: warn an incline is ahead.
		_make_zone(x_range.x - ZONE_LEAD_IN, x_range.x, GROUND_Y - 60.0, "zone_incline")
		_make_zone(x_range.y, x_range.y + ZONE_LEAD_IN, GROUND_Y - 60.0, "zone_incline")
		# On the summit, away from either edge.
		_make_zone(x_range.x + ZONE_EDGE_MARGIN, x_range.y - ZONE_EDGE_MARGIN, top_y - 60.0, "zone_summit")
		# On the summit, close to either edge: warn of the drop ahead.
		_make_zone(x_range.x, x_range.x + ZONE_EDGE_MARGIN, top_y - 60.0, "zone_decline")
		_make_zone(x_range.y - ZONE_EDGE_MARGIN, x_range.y, top_y - 60.0, "zone_decline")
