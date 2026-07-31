extends Node
## Positional-audio counterpart to Sfx.gd for the Multiplayer Shootout mode's
## 3D scene tree. Real AudioStreamPlayer3D panning/attenuation gives genuine
## 360-degree directional cues around whichever AudioListener3D is current
## (see ShooterPlayer.gd, whose listener yaw tracks the gun's aim direction -
## "looking around" in this mode means turning your gun) - no manual
## vertical-pitch trick is needed the way Sfx.gd needs one for its 2D field,
## since real 3D audio already encodes elevation.
##
## lock_beep/lock_on_full are deliberately NOT positional: they describe your
## own weapon's targeting state, not a sound in the world, so they play
## through a plain non-spatial AudioStreamPlayer (see play_ui).

const SOUNDS := {
	"footstep": [
		preload("res://audio/sfx_lib/footstep_grass_00.ogg"),
		preload("res://audio/sfx_lib/footstep_grass_01.ogg"),
		preload("res://audio/sfx_lib/footstep_grass_02.ogg"),
		preload("res://audio/sfx_lib/footstep_grass_03.ogg"),
		preload("res://audio/sfx_lib/footstep_grass_04.ogg"),
		preload("res://audio/sfx_lib/footstep_grass_05.ogg"),
	],
	"gunshot": preload("res://audio/sfx/gunshot.wav"),
	"reload": preload("res://audio/sfx/reload.wav"),
	"jump": preload("res://audio/sfx/jump.wav"),
	"death": preload("res://audio/sfx/death.wav"),
	"respawn": preload("res://audio/sfx/respawn.wav"),
	"proximity_beep": preload("res://audio/sfx/proximity_beep.wav"),
	"lock_beep": preload("res://audio/sfx/lock_beep.wav"),
	"lock_on_full": preload("res://audio/sfx/lock_on_full.wav"),
	"denied": preload("res://audio/sfx/denied.wav"),
}

## Tuned relative to the 40x20 tile field (see ShooterField.TILE_SIZE): wide
## enough that a gunshot carries across most of the map, footsteps/beacon
## read only at real close-to-medium range so distance actually matters.
const DEFAULT_MAX_DISTANCE := 90.0
const DEFAULT_UNIT_SIZE := 8.0
const FOOTSTEP_MAX_DISTANCE := 28.0
const FOOTSTEP_UNIT_SIZE := 3.0
const GUNSHOT_MAX_DISTANCE := 170.0
const GUNSHOT_UNIT_SIZE := 14.0
const BEACON_MAX_DISTANCE := 45.0
const BEACON_UNIT_SIZE := 5.0

func play_at(sound_name: String, global_pos: Vector3, volume_db: float = 0.0, pitch: float = 1.0,
		max_distance: float = DEFAULT_MAX_DISTANCE, unit_size: float = DEFAULT_UNIT_SIZE) -> void:
	var entry = SOUNDS.get(sound_name)
	if entry == null:
		push_warning("Sfx3D: unknown sound '%s'" % sound_name)
		return
	var stream: AudioStream = entry[randi() % entry.size()] if entry is Array else entry
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.global_position = global_pos
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.max_distance = max_distance
	player.unit_size = unit_size
	get_tree().current_scene.add_child(player)
	player.play()
	player.finished.connect(player.queue_free)

func play_random_footstep(global_pos: Vector3, volume_db: float = -2.0) -> void:
	play_at("footstep", global_pos, volume_db, randf_range(0.94, 1.06), FOOTSTEP_MAX_DISTANCE, FOOTSTEP_UNIT_SIZE)

func play_gunshot(global_pos: Vector3) -> void:
	play_at("gunshot", global_pos, 0.0, 1.0, GUNSHOT_MAX_DISTANCE, GUNSHOT_UNIT_SIZE)

func play_proximity_beep(global_pos: Vector3, volume_db: float) -> void:
	play_at("proximity_beep", global_pos, volume_db, 1.0, BEACON_MAX_DISTANCE, BEACON_UNIT_SIZE)

## Non-positional HUD-style cue - your own weapon's aim-assist state, not a
## world sound, so it should read the same regardless of listener rotation.
func play_ui(sound_name: String, volume_db: float = 0.0, pitch: float = 1.0) -> AudioStreamPlayer:
	var entry = SOUNDS.get(sound_name)
	if entry == null:
		push_warning("Sfx3D: unknown sound '%s'" % sound_name)
		return null
	var stream: AudioStream = entry[randi() % entry.size()] if entry is Array else entry
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	get_tree().current_scene.add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
	return player
