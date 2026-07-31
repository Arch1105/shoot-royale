extends Character
class_name BotAI
## Simple opponent: wanders when the player is out of earshot range, closes
## in once it notices them (walking straight up/down slopes - no jump logic
## needed since floor_max_angle already lets move_and_slide climb them),
## and swings once in melee range with a small human-like reaction delay.

@export var bot_index: int = 1
@export var awareness_range: float = 700.0
@export var react_delay_min: float = 0.15
@export var react_delay_max: float = 0.55
@export var wander_change_interval: float = 2.0

const HUM_SOUNDS := {
	1: preload("res://audio/sfx/hum_bot1.wav"),
	2: preload("res://audio/sfx/hum_bot2.wav"),
	3: preload("res://audio/sfx/hum_bot3.wav"),
	4: preload("res://audio/sfx/hum_bot4.wav"),
}

@onready var hum_player: AudioStreamPlayer2D = $Hum

var _react_timer: float = 0.0
var _wander_timer: float = 0.0
var _wander_dir: float = 0.0

func _ready() -> void:
	super._ready()
	add_to_group("bots")
	if hum_player:
		var base_wav: AudioStreamWAV = HUM_SOUNDS.get(bot_index, HUM_SOUNDS[1])
		var wav: AudioStreamWAV = base_wav.duplicate()
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		hum_player.stream = wav
		hum_player.play()
	died.connect(_on_died)
	respawned.connect(_on_respawned)

func _physics_process(delta: float) -> void:
	if alive:
		_think(delta)
		if hum_player:
			hum_player.pitch_scale = Sfx.vertical_pitch_multiplier(global_position.y)
	super._physics_process(delta)

func _think(delta: float) -> void:
	var target := _find_player()
	if target:
		var dx: float = target.global_position.x - global_position.x
		if abs(dx) > swing_range * 0.85:
			move_input = sign(dx)
		else:
			move_input = 0.0
			facing = int(sign(dx)) if dx != 0.0 else facing
			_react_timer -= delta
			if _react_timer <= 0.0:
				if can_swing():
					swing()
				_react_timer = randf_range(react_delay_min, react_delay_max)
	else:
		_wander_timer -= delta
		if _wander_timer <= 0.0:
			_wander_timer = wander_change_interval
			_wander_dir = [-1.0, 0.0, 1.0][randi() % 3]
		move_input = _wander_dir

func _find_player() -> Character:
	for c in get_tree().get_nodes_in_group("characters"):
		if c is PlayerController:
			var pc: PlayerController = c
			if pc.alive and global_position.distance_to(pc.global_position) <= awareness_range:
				return pc
	return null

func _on_died(_who: Character, _attacker: Character, _cause: String) -> void:
	if hum_player:
		hum_player.stop()

func _on_respawned(_who: Character) -> void:
	if hum_player:
		hum_player.play()
