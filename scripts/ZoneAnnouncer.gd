extends Area2D
## Attached at runtime to terrain zone triggers (see Terrain.gd). Announces
## an incline/summit/decline/flat transition via Voice when the human player
## walks in, debounced so straddling the edge doesn't spam the line.

var voice_key: String = ""

const REANNOUNCE_COOLDOWN_MS := 1500

var _last_announce_ms: int = -1000000

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if not (body is PlayerController):
		return
	var now: int = Time.get_ticks_msec()
	if now - _last_announce_ms < REANNOUNCE_COOLDOWN_MS:
		return
	_last_announce_ms = now
	Voice.say(voice_key)
