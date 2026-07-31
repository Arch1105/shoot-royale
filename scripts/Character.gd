extends CharacterBody2D
class_name Character
## Base for anything that walks the field and swings a bat: the human player
## and every bot. Real gravity/jump physics. Hills (see Terrain.gd) are
## raised rock platforms, not ramps - walking into one from ground level
## bumps into solid rock and blocks you (must jump to mount it); walking off
## the top falls, and landing too hard is fatal unless the fall was slowed
## by holding Down (see descend_slow).

signal died(character: Character, attacker: Character, cause: String)
signal respawned(character: Character)

@export var move_speed: float = 330.0
@export var swing_range: float = 80.0
@export var vertical_swing_tolerance: float = 70.0
@export var miss_cooldown: float = 5.0
@export var hit_cooldown: float = 1.0
@export var respawn_delay: float = 3.0
@export var invuln_duration: float = 1.5
@export var jump_velocity: float = -560.0

const GRAVITY: float = 1500.0
const FOOTSTEP_INTERVAL: float = 0.32
const WALL_HIT_COOLDOWN: float = 0.4
## Hilltop points (1600, 4800) sit dead-center on each summit - 400px clear
## of either edge - so a spawn drop never lands someone right at a cliff.
const SPAWN_X_POINTS: Array[float] = [300.0, 1600.0, 2600.0, 3800.0, 4800.0, 5600.0, 6100.0]
const SPAWN_DROP_Y: float = -400.0
const SAFE_FALL_SPEED: float = 260.0 # max downward speed while descend_slow is held
const FALL_DAMAGE_VELOCITY: float = 700.0 # impact speed at landing that kills

var facing: int = 1 # 1 = right, -1 = left
var alive: bool = true
var move_input: float = 0.0 # set by subclass each frame, range -1..1
var jump_requested: bool = false # set by subclass, consumed each physics frame
var descend_slow: bool = false # set by subclass each frame (Down held) to control a fall

@onready var visual: Node2D = $Visual
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var _swing_timer: float = 0.0
var _on_miss_cooldown: bool = false
var _invuln_timer: float = 0.0
var _footstep_timer: float = 0.0
var _wall_cooldown: float = 0.0

func _ready() -> void:
	add_to_group("characters")
	floor_max_angle = deg_to_rad(50.0)

func _physics_process(delta: float) -> void:
	if not alive:
		return
	_apply_gravity_and_jump(delta)
	velocity.x = move_input * move_speed
	var pos_before_x: float = global_position.x
	var was_on_floor: bool = is_on_floor()
	var pre_slide_velocity_y: float = velocity.y
	move_and_slide()
	_check_fall_landing(was_on_floor, pre_slide_velocity_y)
	_handle_facing()
	_handle_footsteps(delta)
	_handle_wall_bump(pos_before_x)
	_handle_timers(delta)
	jump_requested = false

func _apply_gravity_and_jump(delta: float) -> void:
	if not is_on_floor():
		if descend_slow and velocity.y > 0.0:
			velocity.y = min(velocity.y + GRAVITY * delta, SAFE_FALL_SPEED)
		else:
			velocity.y += GRAVITY * delta
	elif jump_requested:
		velocity.y = jump_velocity

func _check_fall_landing(was_on_floor: bool, pre_slide_velocity_y: float) -> void:
	if not alive or is_invulnerable():
		return
	if is_on_floor() and not was_on_floor and pre_slide_velocity_y >= FALL_DAMAGE_VELOCITY:
		die(null, "fall")

func _handle_facing() -> void:
	if move_input != 0.0:
		facing = int(sign(move_input))

func _handle_footsteps(delta: float) -> void:
	if is_on_floor() and move_input != 0.0:
		_footstep_timer -= delta
		if _footstep_timer <= 0.0:
			_footstep_timer = FOOTSTEP_INTERVAL
			Sfx.play_random_footstep(global_position)
	else:
		_footstep_timer = 0.0

func _handle_wall_bump(pos_before_x: float) -> void:
	# Bots have no jump/climb logic, so they bump hills constantly while
	# wandering or chasing - only the human player's own bumps make sound.
	if not (self is PlayerController):
		return
	if move_input == 0.0 or _wall_cooldown > 0.0:
		return
	if abs(global_position.x - pos_before_x) >= 1.0:
		return
	for i in range(get_slide_collision_count()):
		var collision := get_slide_collision(i)
		var normal: Vector2 = collision.get_normal()
		if abs(normal.x) <= 0.6:
			continue # a floor/ceiling surface, not a wall
		_wall_cooldown = WALL_HIT_COOLDOWN
		var collider: Object = collision.get_collider()
		if collider is Node and (collider as Node).is_in_group("incline_wall"):
			Sfx.play_at("rock_bump", global_position, -2.0)
		else:
			Sfx.play_at("wall", global_position, -3.0)
		break

func _handle_timers(delta: float) -> void:
	if _wall_cooldown > 0.0:
		_wall_cooldown -= delta
	if _swing_timer > 0.0:
		_swing_timer -= delta
		if _swing_timer <= 0.0 and _on_miss_cooldown:
			_on_miss_cooldown = false
			Sfx.play_at("cooldown_ready", global_position, -8.0)
	if _invuln_timer > 0.0:
		_invuln_timer -= delta

func can_swing() -> bool:
	return alive and not _on_miss_cooldown

func is_invulnerable() -> bool:
	return _invuln_timer > 0.0

func has_target_in_range() -> bool:
	return alive and _find_target_in_range() != null

func swing() -> void:
	if not can_swing():
		Sfx.play_at("denied", global_position, -10.0)
		return
	Sfx.play_at("swing", global_position, -4.0)
	var target := _find_target_in_range()
	if target:
		_swing_timer = hit_cooldown
		_on_miss_cooldown = false
		Sfx.play_at("hit", target.global_position)
		target.take_hit(self)
	else:
		_swing_timer = miss_cooldown
		_on_miss_cooldown = true
		Sfx.play_at("miss", global_position, -2.0)

func _find_target_in_range() -> Character:
	var best: Character = null
	var best_dist := INF
	for other in get_tree().get_nodes_in_group("characters"):
		if other == self or not (other is Character):
			continue
		var oc: Character = other
		if not oc.alive or oc.is_invulnerable():
			continue
		var dx: float = oc.global_position.x - global_position.x
		var dy: float = oc.global_position.y - global_position.y
		if dx == 0.0 or int(sign(dx)) != facing:
			continue
		if abs(dy) > vertical_swing_tolerance:
			continue
		var dist: float = abs(dx)
		if dist <= swing_range and dist < best_dist:
			best = oc
			best_dist = dist
	return best

func take_hit(attacker: Character) -> void:
	if not alive or is_invulnerable():
		return
	die(attacker, "combat")

func die(attacker: Character = null, cause: String = "combat") -> void:
	alive = false
	if visual:
		visual.visible = false
	if collision_shape:
		collision_shape.disabled = true
	Sfx.play_at("death", global_position)
	died.emit(self, attacker, cause)
	await get_tree().create_timer(respawn_delay).timeout
	respawn()

func respawn() -> void:
	global_position = Vector2(SPAWN_X_POINTS[randi() % SPAWN_X_POINTS.size()], SPAWN_DROP_Y)
	velocity = Vector2.ZERO
	if visual:
		visual.visible = true
	if collision_shape:
		collision_shape.disabled = false
	alive = true
	_invuln_timer = invuln_duration
	_on_miss_cooldown = false
	_swing_timer = 0.0
	_footstep_timer = 0.0
	Sfx.play_at("respawn", global_position)
	respawned.emit(self)
