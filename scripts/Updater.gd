extends Node
class_name Updater
## Checks GitHub Releases for a newer build of the game and, if found,
## downloads the released files and swaps them in for the ones currently
## running. This is what lets you send the game to a friend once and both
## keep updating it from the "Update Game" button instead of resending the
## file - see scripts/MainMenu.gd for the button that drives this.
##
## Downloads more than just the main .exe: NvdaSpeak.exe and
## nvdaControllerClient64.dll are real native binaries that can't live inside
## the exported build's embedded .pck (see Voice.gd's
## _resolve_nvda_helper_path), so they're published as their own release
## assets and fetched here too, or NVDA support would quietly break again on
## every update the same way it broke in the very first packaged build.
##
## A running .exe can't overwrite itself on Windows, so install_and_restart
## writes a tiny helper batch file that waits for this process to exit,
## moves the downloaded files into place, relaunches, and deletes itself.

const GITHUB_OWNER := "Arch1105"
const GITHUB_REPO := "shoot-royale"
## Release asset filenames (lowercase) that aren't the main game exe, with
## the relative path (from the exe's folder) they need to end up at.
const SIDE_ASSETS := {
	"nvdaspeak.exe": "bin/NvdaSpeak.exe",
	"nvdacontrollerclient64.dll": "bin/nvdaControllerClient64.dll",
}

signal update_available(version: String)
signal up_to_date()
signal check_failed(reason: String)
signal ready_to_restart()

var _http: HTTPRequest
var _latest_version: String = ""
var _asset_urls: Dictionary = {} # lowercased asset name -> browser_download_url
var _download_order: Array[String] = [] # lowercased asset names, in fetch order
var _download_index: int = 0
var _downloaded_paths: Dictionary = {} # lowercased asset name -> local temp file path

func _ready() -> void:
	_http = HTTPRequest.new()
	add_child(_http)

func current_version() -> String:
	var f := FileAccess.open("res://VERSION", FileAccess.READ)
	if f == null:
		return "0.0.0"
	return f.get_as_text().strip_edges()

func check_for_update() -> void:
	Voice.speak_text("Checking for updates.")
	var url: String = "https://api.github.com/repos/%s/%s/releases/latest" % [GITHUB_OWNER, GITHUB_REPO]
	if not _http.request_completed.is_connected(_on_check_completed):
		_http.request_completed.connect(_on_check_completed, CONNECT_ONE_SHOT)
	var err: int = _http.request(url, ["User-Agent: ShootRoyaleUpdater"])
	if err != OK:
		check_failed.emit("request_error")

func _on_check_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		check_failed.emit("network_error")
		return
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		check_failed.emit("parse_error")
		return
	var data: Dictionary = json.data
	var tag: String = str(data.get("tag_name", ""))
	_latest_version = tag.lstrip("v")
	_asset_urls.clear()
	for asset in data.get("assets", []) as Array:
		var a: Dictionary = asset
		var asset_name: String = str(a.get("name", "")).to_lower()
		_asset_urls[asset_name] = str(a.get("browser_download_url", ""))
	if _latest_version == "" or _main_exe_asset_name() == "":
		check_failed.emit("no_release_asset")
		return
	if _is_newer(_latest_version, current_version()):
		update_available.emit(_latest_version)
	else:
		up_to_date.emit()

## The main game exe's asset name varies (GitHub replaces spaces with dots),
## so it's identified as "any .exe that isn't NvdaSpeak.exe" rather than an
## exact match.
func _main_exe_asset_name() -> String:
	for asset_name in _asset_urls.keys():
		if asset_name.ends_with(".exe") and not SIDE_ASSETS.has(asset_name):
			return asset_name
	return ""

func _is_newer(remote: String, local: String) -> bool:
	var r: PackedStringArray = remote.split(".")
	var l: PackedStringArray = local.split(".")
	for i in range(max(r.size(), l.size())):
		var rv: int = int(r[i]) if i < r.size() else 0
		var lv: int = int(l[i]) if i < l.size() else 0
		if rv != lv:
			return rv > lv
	return false

func start_download() -> void:
	var exe_name: String = _main_exe_asset_name()
	if exe_name == "":
		check_failed.emit("no_download_url")
		return
	_download_order = [exe_name]
	for side_name in SIDE_ASSETS.keys():
		if _asset_urls.has(side_name):
			_download_order.append(side_name)
	_download_index = 0
	_downloaded_paths.clear()
	Voice.speak_text("Downloading update.")
	_download_next()

func _download_next() -> void:
	if _download_index >= _download_order.size():
		ready_to_restart.emit()
		return
	var asset_name: String = _download_order[_download_index]
	var dest_path: String = OS.get_executable_path().get_base_dir().path_join("_update_%d_%s" % [_download_index, asset_name])
	_downloaded_paths[asset_name] = dest_path
	_http.download_file = dest_path
	if not _http.request_completed.is_connected(_on_asset_downloaded):
		_http.request_completed.connect(_on_asset_downloaded, CONNECT_ONE_SHOT)
	var err: int = _http.request(_asset_urls[asset_name], ["User-Agent: ShootRoyaleUpdater"])
	if err != OK:
		check_failed.emit("download_request_error")

func _on_asset_downloaded(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	_http.download_file = ""
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		check_failed.emit("download_failed")
		return
	_download_index += 1
	_download_next()

## Writes and launches a helper batch file that waits for this exe to exit,
## moves every downloaded file into place (creating bin/ if needed),
## relaunches, and deletes itself.
func install_and_restart() -> void:
	var exe_path: String = OS.get_executable_path()
	var dir: String = exe_path.get_base_dir()
	var exe_name: String = exe_path.get_file()
	var bin_dir: String = dir.path_join("bin")
	var bat_path: String = dir.path_join("shoot_royale_update.bat")
	var bat_lines: PackedStringArray = [
		"@echo off",
		":wait",
		"timeout /t 1 /nobreak > NUL",
		"tasklist /fi \"imagename eq %s\" | find /i \"%s\" >NUL" % [exe_name, exe_name],
		"if not errorlevel 1 goto wait",
		"if not exist \"%s\" mkdir \"%s\"" % [bin_dir, bin_dir],
		"move /y \"%s\" \"%s\"" % [_downloaded_paths[_main_exe_asset_name()], exe_path],
	]
	for side_name in SIDE_ASSETS.keys():
		if _downloaded_paths.has(side_name):
			var dest: String = dir.path_join(SIDE_ASSETS[side_name])
			bat_lines.append("move /y \"%s\" \"%s\"" % [_downloaded_paths[side_name], dest])
	bat_lines.append("start \"\" \"%s\"" % exe_path)
	bat_lines.append("del \"%~f0\"")
	var f := FileAccess.open(bat_path, FileAccess.WRITE)
	f.store_string("\r\n".join(bat_lines) + "\r\n")
	f.close()
	Voice.speak_text("Restarting to install the update.")
	OS.create_process("cmd.exe", ["/c", bat_path])
	get_tree().quit()
