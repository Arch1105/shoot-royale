extends Node
## Global helper for one-shot positional sound effects. Footsteps/hit/swing/
## wall/rock-bump use real CC0 recordings (OpenGameArt's "Swishes" pack -
## real wooden objects swung past a mic - for the swing whoosh, Kenney's
## Impact Sounds for hit/wall/rock-bump, Fantozzi's Freesound-sourced pack
## for footsteps - see tools/swish_src, tools/sfx_src, tools/footsteps_src);
## the rest are procedurally synthesized UI-style cues (tools/generate_sfx.py)
## since they're meant to read as signals, not real-world sounds.
##
## Every sound plays through a throwaway AudioStreamPlayer2D so it's panned
## by the active AudioListener2D (set on the human player - see
## PlayerController.gd), additionally pitch-shifted up/down based on
## vertical offset from the listener (above/below cue), and attenuated by
## distance - footsteps use a tighter falloff than combat/UI sounds so
## nearby footsteps read clearly over far-off ones.

const SOUNDS := {
	"footstep": [
		preload("res://audio/sfx_lib/footstep_grass_00.ogg"),
		preload("res://audio/sfx_lib/footstep_grass_01.ogg"),
		preload("res://audio/sfx_lib/footstep_grass_02.ogg"),
		preload("res://audio/sfx_lib/footstep_grass_03.ogg"),
		preload("res://audio/sfx_lib/footstep_grass_04.ogg"),
		preload("res://audio/sfx_lib/footstep_grass_05.ogg"),
	],
	"rock_bump": [
		preload("res://audio/sfx_lib/rock_bump_00.ogg"),
		preload("res://audio/sfx_lib/rock_bump_01.ogg"),
	],
	"swing": [
		preload("res://audio/sfx_lib/swing_00.wav"),
		preload("res://audio/sfx_lib/swing_01.wav"),
	],
	"hit": preload("res://audio/sfx_lib/hit.ogg"),
	"wall": preload("res://audio/sfx_lib/wall.ogg"),
	"miss": preload("res://audio/sfx/miss.wav"),
	"cooldown_ready": preload("res://audio/sfx/cooldown_ready.wav"),
	"death": preload("res://audio/sfx/death.wav"),
	"respawn": preload("res://audio/sfx/respawn.wav"),
	"denied": preload("res://audio/sfx/denied.wav"),
	"range_beep": preload("res://audio/sfx/range_beep.wav"),
}

const DEFAULT_MAX_DISTANCE := 3000.0
const DEFAULT_ATTENUATION := 1.3
## Footsteps fall off much faster than combat/UI cues so distance actually reads.
const FOOTSTEP_MAX_DISTANCE := 1100.0
const FOOTSTEP_ATTENUATION := 2.4

const VERTICAL_PITCH_RANGE := 400.0 # px of vertical offset for the full pitch swing below
const VERTICAL_PITCH_SPREAD := 0.35 # +/- 35% pitch at VERTICAL_PITCH_RANGE or beyond

## Updated every frame by the human player's controller; everything else in
## this file treats it as "where the listener's ears are" for pitch cues.
var listener_y: float = 0.0

func play_at(sound_name: String, global_pos: Vector2, volume_db: float = 0.0, pitch: float = 1.0,
		max_distance: float = DEFAULT_MAX_DISTANCE, attenuation: float = DEFAULT_ATTENUATION) -> void:
	var entry = SOUNDS.get(sound_name)
	if entry == null:
		push_warning("Sfx: unknown sound '%s'" % sound_name)
		return
	var stream: AudioStream = entry[randi() % entry.size()] if entry is Array else entry
	var player := AudioStreamPlayer2D.new()
	player.stream = stream
	player.global_position = global_pos
	player.volume_db = volume_db
	player.pitch_scale = pitch * vertical_pitch_multiplier(global_pos.y)
	player.max_distance = max_distance
	player.attenuation = attenuation
	get_tree().current_scene.add_child(player)
	player.play()
	player.finished.connect(player.queue_free)

func play_random_footstep(global_pos: Vector2, volume_db: float = -2.0) -> void:
	play_at("footstep", global_pos, volume_db, randf_range(0.94, 1.06), FOOTSTEP_MAX_DISTANCE, FOOTSTEP_ATTENUATION)

## +1.0 = full pitch-up (source well above the listener), -1.0 = full
## pitch-down (source well below). Godot's y axis increases downward.
func vertical_pitch_multiplier(source_y: float) -> float:
	var dy: float = listener_y - source_y
	var ratio: float = clamp(dy / VERTICAL_PITCH_RANGE, -1.0, 1.0)
	return 1.0 + ratio * VERTICAL_PITCH_SPREAD
