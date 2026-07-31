extends Node
class_name Updater
## Checks GitHub Releases for a newer build of the game and, if found,
## downloads the released .exe and swaps it in for the one currently
## running. This is what lets you send the game to a friend once and both
## keep updating it from the "Update Game" button instead of resending the
## file - see scripts/MainMenu.gd for the button that drives this.
##
## A running .exe can't overwrite itself on Windows, so install_and_restart
## writes a tiny helper batch file that waits for this process to exit,
## moves the downloaded file into place, relaunches it, and deletes itself.

const GITHUB_OWNER := "Arch1105"
const GITHUB_REPO := "shoot-royale"

signal update_available(version: String)
signal up_to_date()
signal check_failed(reason: String)
signal ready_to_restart()

var _http: HTTPRequest
var _download_url: String = ""
var _latest_version: String = ""

func _ready() -> void:
	_http = HTTPRequest.new()
	add_child(_http)

func current_version() -> String:
	var f := FileAccess.open("res://VERSION", FileAccess.READ)
	if f == null:
		return "0.0.0"
	return f.get_as_text().strip_edges()

func check_for_update() -> void:
	if GITHUB_OWNER.begins_with("REPLACE_WITH"):
		check_failed.emit("repo_not_configured")
		return
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
	_download_url = ""
	for asset in data.get("assets", []) as Array:
		var a: Dictionary = asset
		if str(a.get("name", "")).to_lower().ends_with(".exe"):
			_download_url = str(a.get("browser_download_url", ""))
			break
	if _latest_version == "" or _download_url == "":
		check_failed.emit("no_release_asset")
		return
	if _is_newer(_latest_version, current_version()):
		update_available.emit(_latest_version)
	else:
		up_to_date.emit()

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
	if _download_url == "":
		check_failed.emit("no_download_url")
		return
	Voice.speak_text("Downloading update.")
	var download_path: String = OS.get_executable_path().get_base_dir().path_join("ShootRoyale.update.exe")
	_http.download_file = download_path
	_http.request_completed.connect(_on_download_completed, CONNECT_ONE_SHOT)
	var err: int = _http.request(_download_url, ["User-Agent: ShootRoyaleUpdater"])
	if err != OK:
		check_failed.emit("download_request_error")

func _on_download_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	_http.download_file = ""
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		check_failed.emit("download_failed")
		return
	ready_to_restart.emit()

## Writes and launches a helper batch file that waits for this exe to exit,
## replaces it with the downloaded one, relaunches, and deletes itself.
func install_and_restart() -> void:
	var exe_path: String = OS.get_executable_path()
	var dir: String = exe_path.get_base_dir()
	var exe_name: String = exe_path.get_file()
	var new_exe: String = dir.path_join("ShootRoyale.update.exe")
	var bat_path: String = dir.path_join("bash_royale_update.bat")
	var bat_lines: PackedStringArray = [
		"@echo off",
		":wait",
		"timeout /t 1 /nobreak > NUL",
		"tasklist /fi \"imagename eq %s\" | find /i \"%s\" >NUL" % [exe_name, exe_name],
		"if not errorlevel 1 goto wait",
		"move /y \"%s\" \"%s\"" % [new_exe, exe_path],
		"start \"\" \"%s\"" % exe_path,
		"del \"%~f0\"",
	]
	var f := FileAccess.open(bat_path, FileAccess.WRITE)
	f.store_string("\r\n".join(bat_lines) + "\r\n")
	f.close()
	Voice.speak_text("Restarting to install the update.")
	OS.create_process("cmd.exe", ["/c", bat_path])
	get_tree().quit()
