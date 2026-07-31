extends SceneTree
## Smoke-test harness: hosts a match and reports what happens on stdout.
## Run: Godot --headless --path . --script tools/test_lan_host.gd -- [forced_code]

var _host: Node
var _elapsed := 0.0
var _started := false
const TIMEOUT := 12.0

func _process(delta: float) -> bool:
	if not _started:
		_started = true
		_host = preload("res://scripts/net/LanHost.gd").new()
		get_root().add_child(_host)
		_host.client_connected.connect(func(id: int) -> void: print("CLIENT_CONNECTED:%d" % id))
		var args := OS.get_cmdline_user_args()
		var code: int = _host.start_hosting()
		if args.size() > 0 and code >= 0:
			_host.code = int(args[0])
			code = _host.code
		print("CODE:%d" % code)
	_elapsed += delta
	if _elapsed >= TIMEOUT:
		print("HOST_DONE")
		return true
	return false
