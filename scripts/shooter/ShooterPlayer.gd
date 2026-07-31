extends CharacterBody3D
class_name ShooterPlayer
## A player in the Multiplayer Shootout mode. Movement is world-relative
## (left stick / WASD); the gun - and with it the AudioListener3D, since
## "looking around" in this mode means turning your gun - is aimed
## independently by the right stick / arrow keys, snapping instantly to
## whatever compass direction is held (a twin-stick model, matching the
## user's Top Gun radar analogy: you sweep the gun to search, and a lock
## reads back through audio, not sight).
##
## Only the owning peer (is_multiplayer_authority()) reads local input and
## applies movement/aim/shoot/reload; MultiplayerSynchronizer (see the scene)
## replicates `position` and `aim_dir` to everyone else. Footsteps are driven
## by observed position deltas instead of `velocity` so they still fire
## correctly on every peer's copy of a *remote* player, whose movement here
## is just the synchronizer snapping `position` each tick, not a real local
## physics simulation. Death/respawn/kills are decided server-side (see
## ShooterGameManager) and applied everywhere via reliable RPCs so both
## players' state - and the Voice announcements that follow - stay in sync.

signal died(who: ShooterPlayer, attacker_id: int)
signal respawned(who: ShooterPlayer)

@export var move_speed: float = 6.0
@export var jump_velocity: float = 6.0
@export var max_ammo: int = 8
@export var reload_time: float = 1.4
@export var fire_cooldown: float = 0.35
@export var respawn_delay: float = 3.0
@export var invuln_duration: float = 1.5
## Firing while the target is inside this cone is a guaranteed hit - this is
## the same threshold that flips the aim-assist beep into a sustained "Locked
## On" tone, so what you hear is exactly what determines whether you'll hit.
@export var lock_on_angle: float = deg_to_rad(6.0)
## Wider cone the searching beep reacts to before a full lock.
@export var lock_search_angle: float = deg_to_rad(45.0)
@export var lock_max_range: float = 120.0
@export var beacon_max_range: float = 45.0

const GRAVITY := 16.0
const FOOTSTEP_INTERVAL := 0.38
const MOVE_EPSILON := 0.02

@onready var gun_pivot: Node3D = $GunPivot
@onready var audio_listener: AudioListener3D = $GunPivot/AudioListener3D
@onready var sync: MultiplayerSynchronizer = $MultiplayerSynchronizer

var aim_dir: Vector3 = Vector3(0.0, 0.0, -1.0)
var alive: bool = true
var ammo: int

var _reload_timer: float = 0.0
var _reloading: bool = false
var _fire_timer: float = 0.0
var _footstep_timer: float = 0.0
var _invuln_timer: float = 0.0
var _lock_beep_timer: float = 0.0
var _beacon_timer: float = 0.0
var _was_locked: bool = false
var _lock_on_player: AudioStreamPlayer = null
var _prev_position: Vector3

func _ready() -> void:
	add_to_group("shooter_players")
	ammo = max_ammo
	_prev_position = position
	set_multiplayer_authority(str(name).to_int())
	_setup_replication()
	if is_multiplayer_authority():
		audio_listener.make_current()

## Built in code rather than as a hand-authored SceneReplicationConfig
## sub-resource in the .tscn - fewer places to get the serialized format
## subtly wrong.
func _setup_replication() -> void:
	var config := SceneReplicationConfig.new()
	config.add_property(NodePath(".:position"))
	config.property_set_replication_mode(NodePath(".:position"), SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	config.add_property(NodePath(".:aim_dir"))
	config.property_set_replication_mode(NodePath(".:aim_dir"), SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	sync.replication_config = config

func peer_id() -> int:
	return str(name).to_int()

func _physics_process(delta: float) -> void:
	if is_multiplayer_authority() and alive:
		_handle_move(delta)
		_handle_jump()
		_handle_aim_input()
		_handle_shoot(delta)
		_handle_reload(delta)
		_handle_proximity_beacon(delta)
		_handle_aim_assist(delta)
		if _invuln_timer > 0.0:
			_invuln_timer -= delta
	gun_pivot.look_at(gun_pivot.global_position + aim_dir, Vector3.UP)
	_handle_footsteps(delta)
	_prev_position = position

func _handle_move(delta: float) -> void:
	var move_x := Input.get_axis("shooter_move_left", "shooter_move_right")
	var move_z := Input.get_axis("shooter_move_up", "shooter_move_down")
	velocity.x = move_x * move_speed
	velocity.z = move_z * move_speed
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	move_and_slide()

func _handle_jump() -> void:
	if Input.is_action_just_pressed("shooter_jump") and is_on_floor():
		velocity.y = jump_velocity
		rpc("_broadcast_positional_sfx", "jump", global_position)

func _handle_aim_input() -> void:
	var aim_x := Input.get_axis("shooter_aim_left", "shooter_aim_right")
	var aim_z := Input.get_axis("shooter_aim_up", "shooter_aim_down")
	var input_vec := Vector2(aim_x, aim_z)
	if input_vec.length() > 0.15:
		aim_dir = Vector3(aim_x, 0.0, aim_z).normalized()

func _handle_shoot(delta: float) -> void:
	if _fire_timer > 0.0:
		_fire_timer -= delta
	if _reloading:
		return
	if Input.is_action_pressed("shooter_shoot") and _fire_timer <= 0.0:
		_fire_timer = fire_cooldown
		if ammo <= 0:
			_start_reload()
			return
		ammo -= 1
		rpc("_broadcast_fire_shot")

func _handle_reload(delta: float) -> void:
	if Input.is_action_just_pressed("shooter_reload") and not _reloading and ammo < max_ammo:
		_start_reload()
	if _reloading:
		_reload_timer -= delta
		if _reload_timer <= 0.0:
			_reloading = false
			ammo = max_ammo

func _start_reload() -> void:
	_reloading = true
	_reload_timer = reload_time
	rpc("_broadcast_positional_sfx", "reload", global_position)
	Voice.say("reload_start")

func _handle_footsteps(delta: float) -> void:
	var moved: float = Vector2(position.x - _prev_position.x, position.z - _prev_position.z).length()
	if alive and is_on_floor() and moved > MOVE_EPSILON:
		_footstep_timer -= delta
		if _footstep_timer <= 0.0:
			_footstep_timer = FOOTSTEP_INTERVAL
			Sfx3D.play_random_footstep(global_position)
	else:
		_footstep_timer = 0.0

func _handle_proximity_beacon(delta: float) -> void:
	var nearest: ShooterPlayer = null
	var nearest_dist := INF
	for node in get_tree().get_nodes_in_group("shooter_players"):
		var p: ShooterPlayer = node
		if p == self or not p.alive:
			continue
		var dist: float = global_position.distance_to(p.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = p
	if nearest == null or nearest_dist > beacon_max_range:
		_beacon_timer = 0.0
		return
	_beacon_timer -= delta
	if _beacon_timer <= 0.0:
		var t: float = clamp(1.0 - (nearest_dist / beacon_max_range), 0.0, 1.0)
		_beacon_timer = lerp(1.1, 0.2, t)
		Sfx3D.play_proximity_beep(nearest.global_position, lerp(-18.0, 0.0, t))

func _find_nearest_in_lock_cone() -> ShooterPlayer:
	var best: ShooterPlayer = null
	var best_dist := INF
	for node in get_tree().get_nodes_in_group("shooter_players"):
		var p: ShooterPlayer = node
		if p == self or not p.alive:
			continue
		var to_target: Vector3 = p.global_position - gun_pivot.global_position
		to_target.y = 0.0
		var dist: float = to_target.length()
		if dist > lock_max_range or dist < 0.001:
			continue
		var angle: float = aim_dir.angle_to(to_target.normalized())
		if angle <= lock_search_angle and dist < best_dist:
			best = p
			best_dist = dist
	return best

func _handle_aim_assist(delta: float) -> void:
	var target := _find_nearest_in_lock_cone()
	if target == null:
		_end_lock()
		return
	var to_target: Vector3 = target.global_position - gun_pivot.global_position
	to_target.y = 0.0
	var dist: float = to_target.length()
	var angle: float = aim_dir.angle_to(to_target.normalized())
	if angle <= lock_on_angle:
		if not _was_locked:
			_was_locked = true
			Voice.say("locked_on")
			_lock_on_player = Sfx3D.play_ui("lock_on_full", -4.0)
			if _lock_on_player and _lock_on_player.stream is AudioStreamWAV:
				var looped: AudioStreamWAV = (_lock_on_player.stream as AudioStreamWAV).duplicate()
				looped.loop_mode = AudioStreamWAV.LOOP_FORWARD
				_lock_on_player.stream = looped
				_lock_on_player.play()
		_lock_beep_timer = 0.0
		return
	_end_lock()
	var angle_t: float = clamp(1.0 - (angle / lock_search_angle), 0.0, 1.0)
	var dist_t: float = clamp(1.0 - (dist / lock_max_range), 0.0, 1.0)
	var closeness: float = angle_t * 0.7 + dist_t * 0.3
	_lock_beep_timer -= delta
	if _lock_beep_timer <= 0.0:
		_lock_beep_timer = lerp(0.9, 0.08, closeness)
		Sfx3D.play_ui("lock_beep", lerp(-16.0, 0.0, closeness), lerp(0.9, 1.6, closeness))

func _end_lock() -> void:
	if _was_locked and _lock_on_player:
		_lock_on_player.stop()
		_lock_on_player.queue_free()
		_lock_on_player = null
	_was_locked = false

@rpc("any_peer", "call_local", "reliable")
func _broadcast_positional_sfx(sound_name: String, pos: Vector3) -> void:
	Sfx3D.play_at(sound_name, pos)

@rpc("any_peer", "call_local", "reliable")
func _broadcast_fire_shot() -> void:
	Sfx3D.play_gunshot(global_position)
	if not multiplayer.is_server():
		return
	var target := _find_locked_target()
	if target != null:
		target.rpc("die", peer_id())

## Server-side hit check: reuses the same search cone as the aim-assist beep,
## then narrows to the tight lock threshold - firing while the "Locked On"
## tone is sounding is what a hit actually means, so the audio a player
## relies on to aim is exactly what decides the outcome.
func _find_locked_target() -> ShooterPlayer:
	var target := _find_nearest_in_lock_cone()
	if target == null:
		return null
	var to_target: Vector3 = target.global_position - gun_pivot.global_position
	to_target.y = 0.0
	var angle: float = aim_dir.angle_to(to_target.normalized())
	if angle <= lock_on_angle:
		return target
	return null

## Server-authoritative: called only by ShooterGameManager on the host.
@rpc("any_peer", "call_local", "reliable")
func die(attacker_id: int) -> void:
	if not _is_call_from_server():
		return
	alive = false
	_end_lock()
	Sfx3D.play_at("death", global_position)
	died.emit(self, attacker_id)

@rpc("any_peer", "call_local", "reliable")
func respawn_at(spawn_pos: Vector3) -> void:
	if not _is_call_from_server():
		return
	position = spawn_pos
	velocity = Vector3.ZERO
	alive = true
	ammo = max_ammo
	_reloading = false
	_invuln_timer = invuln_duration
	Sfx3D.play_at("respawn", spawn_pos)
	respawned.emit(self)

func _is_call_from_server() -> bool:
	var sender: int = multiplayer.get_remote_sender_id()
	if sender == 1:
		return true
	return sender == 0 and multiplayer.is_server()
