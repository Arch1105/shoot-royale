extends SceneTree
## Smoke-test harness: searches for a hosted match by code and reports what
## happens on stdout. Run: Godot --headless --path . --script tools/test_lan_client.gd -- <code>

var _client: Node
var _elapsed := 0.0
var _done := false
const TIMEOUT := 12.0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var code: int = int(args[0]) if args.size() > 0 else 0
	print("JOINING_CODE:%d" % code)
	_client = preload("res://scripts/net/LanClient.gd").new()
	get_root().add_child(_client)
	_client.connected_to_server.connect(func() -> void: print("CONNECTED"); _done = true)
	_client.timed_out.connect(func() -> void: print("TIMED_OUT"); _done = true)
	_client.connection_failed.connect(func() -> void: print("CONNECTION_FAILED"); _done = true)
	_client.start_search(code)

func _process(delta: float) -> bool:
	_elapsed += delta
	if _done or _elapsed >= TIMEOUT:
		print("CLIENT_DONE")
		return true
	return false
