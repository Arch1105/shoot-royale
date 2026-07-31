extends Character
class_name PlayerController
## The human player. Left/Right (or A/D) to move, Up arrow to jump, Down
## arrow to control a fall (caps fall speed so you can land safely off a
## cliff), Space to swing the bat, K to hear a spoken score check any time.
## A repeating beep confirms whenever an opponent is within bat range.

const RANGE_BEEP_INTERVAL := 0.4

@onready var audio_listener: AudioListener2D = $AudioListener2D

var _range_beep_timer: float = 0.0

func _ready() -> void:
	super._ready()
	audio_listener.make_current()

func _physics_process(delta: float) -> void:
	move_input = Input.get_axis("move_left", "move_right")
	descend_slow = Input.is_action_pressed("move_down")
	if Input.is_action_just_pressed("jump"):
		jump_requested = true
	super._physics_process(delta)
	if alive:
		Sfx.listener_y = global_position.y
		if Input.is_action_just_pressed("swing"):
			swing()
		_update_range_beep(delta)

func _update_range_beep(delta: float) -> void:
	if has_target_in_range():
		_range_beep_timer -= delta
		if _range_beep_timer <= 0.0:
			_range_beep_timer = RANGE_BEEP_INTERVAL
			Sfx.play_at("range_beep", global_position, -6.0)
	else:
		_range_beep_timer = 0.0
