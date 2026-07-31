extends Node
## Global helper for spoken announcements. Every announcement is first
## attempted through the player's own running screen reader (NVDA, via
## bin/NvdaSpeak.exe - a tiny helper that bridges to NVDA's official
## controller client DLL, since GDScript has no native FFI) so it comes out
## in NVDA's own voice/rate/verbosity the player already has tuned. If NVDA
## isn't running, it falls back to the pre-rendered Windows-SAPI clips
## (see tools/generate_voice.ps1) so the game is still fully voiced without
## a screen reader.

const LINES := {
	"match_start": preload("res://audio/voice/match_start.wav"),
	"you_died": preload("res://audio/voice/you_died.wav"),
	"you_respawned": preload("res://audio/voice/you_respawned.wav"),
	"eliminated_bot_1": preload("res://audio/voice/eliminated_bot_1.wav"),
	"eliminated_bot_2": preload("res://audio/voice/eliminated_bot_2.wav"),
	"eliminated_bot_3": preload("res://audio/voice/eliminated_bot_3.wav"),
	"eliminated_bot_4": preload("res://audio/voice/eliminated_bot_4.wav"),
	"eliminated_generic": preload("res://audio/voice/eliminated_generic.wav"),
	"score_prefix": preload("res://audio/voice/score_prefix.wav"),
	"elim_singular": preload("res://audio/voice/elim_singular.wav"),
	"elim_plural": preload("res://audio/voice/elim_plural.wav"),
	"death_singular": preload("res://audio/voice/death_singular.wav"),
	"death_plural": preload("res://audio/voice/death_plural.wav"),
	"zone_incline": preload("res://audio/voice/zone_incline.wav"),
	"zone_summit": preload("res://audio/voice/zone_summit.wav"),
	"zone_decline": preload("res://audio/voice/zone_decline.wav"),
	"zone_flat": preload("res://audio/voice/zone_flat.wav"),
	"fall_damage": preload("res://audio/voice/fall_damage.wav"),
	"shootout_start": preload("res://audio/voice/shootout_start.wav"),
	"locked_on": preload("res://audio/voice/locked_on.wav"),
	"match_created": preload("res://audio/voice/match_created.wav"),
	"connected": preload("res://audio/voice/connected.wav"),
	"no_match_found": preload("res://audio/voice/no_match_found.wav"),
	"searching_for_match": preload("res://audio/voice/searching_for_match.wav"),
	"match_time_low": preload("res://audio/voice/match_time_low.wav"),
	"match_over": preload("res://audio/voice/match_over.wav"),
	"you_win": preload("res://audio/voice/you_win.wav"),
	"opponent_wins": preload("res://audio/voice/opponent_wins.wav"),
	"match_tie": preload("res://audio/voice/match_tie.wav"),
	"reload_start": preload("res://audio/voice/reload_start.wav"),
	"num_0": preload("res://audio/voice/num_0.wav"),
	"num_1": preload("res://audio/voice/num_1.wav"),
	"num_2": preload("res://audio/voice/num_2.wav"),
	"num_3": preload("res://audio/voice/num_3.wav"),
	"num_4": preload("res://audio/voice/num_4.wav"),
	"num_5": preload("res://audio/voice/num_5.wav"),
	"num_6": preload("res://audio/voice/num_6.wav"),
	"num_7": preload("res://audio/voice/num_7.wav"),
	"num_8": preload("res://audio/voice/num_8.wav"),
	"num_9": preload("res://audio/voice/num_9.wav"),
	"num_10": preload("res://audio/voice/num_10.wav"),
	"num_11": preload("res://audio/voice/num_11.wav"),
	"num_12": preload("res://audio/voice/num_12.wav"),
	"num_13": preload("res://audio/voice/num_13.wav"),
	"num_14": preload("res://audio/voice/num_14.wav"),
	"num_15": preload("res://audio/voice/num_15.wav"),
	"num_16": preload("res://audio/voice/num_16.wav"),
	"num_17": preload("res://audio/voice/num_17.wav"),
	"num_18": preload("res://audio/voice/num_18.wav"),
	"num_19": preload("res://audio/voice/num_19.wav"),
	"num_20": preload("res://audio/voice/num_20.wav"),
	"num_21": preload("res://audio/voice/num_21.wav"),
	"num_22": preload("res://audio/voice/num_22.wav"),
	"num_23": preload("res://audio/voice/num_23.wav"),
	"num_24": preload("res://audio/voice/num_24.wav"),
	"num_25": preload("res://audio/voice/num_25.wav"),
	"num_26": preload("res://audio/voice/num_26.wav"),
	"num_27": preload("res://audio/voice/num_27.wav"),
	"num_28": preload("res://audio/voice/num_28.wav"),
	"num_29": preload("res://audio/voice/num_29.wav"),
	"num_30": preload("res://audio/voice/num_30.wav"),
	"num_31": preload("res://audio/voice/num_31.wav"),
	"num_32": preload("res://audio/voice/num_32.wav"),
	"num_33": preload("res://audio/voice/num_33.wav"),
	"num_34": preload("res://audio/voice/num_34.wav"),
	"num_35": preload("res://audio/voice/num_35.wav"),
	"num_36": preload("res://audio/voice/num_36.wav"),
	"num_37": preload("res://audio/voice/num_37.wav"),
	"num_38": preload("res://audio/voice/num_38.wav"),
	"num_39": preload("res://audio/voice/num_39.wav"),
	"coords_prefix": preload("res://audio/voice/coords_prefix.wav"),
	"coords_row": preload("res://audio/voice/coords_row.wav"),
}

## Mirrors the phrases baked into the wav clips above - must match
## tools/generate_voice.ps1's $lines text so NVDA and the fallback clips
## never disagree about what was "said".
const PHRASES := {
	"match_start": "Fight! Bats are up.",
	"you_died": "You were eliminated.",
	"you_respawned": "You respawned.",
	"eliminated_bot_1": "You eliminated Bot 1.",
	"eliminated_bot_2": "You eliminated Bot 2.",
	"eliminated_bot_3": "You eliminated Bot 3.",
	"eliminated_bot_4": "You eliminated Bot 4.",
	"eliminated_generic": "You eliminated an opponent.",
	"zone_incline": "Incline. Climbing up.",
	"zone_summit": "You're at the top.",
	"zone_decline": "Decline. Heading down.",
	"zone_flat": "Flat ground.",
	"fall_damage": "You fell and were eliminated.",
	"shootout_start": "Match started. Six minutes. Most eliminations wins.",
	"locked_on": "Locked on.",
	"match_created": "Match created. Your code is",
	"connected": "Connected.",
	"no_match_found": "No match found with that code.",
	"searching_for_match": "Searching for match.",
	"match_time_low": "One minute remaining.",
	"match_over": "Match over.",
	"you_win": "You win!",
	"opponent_wins": "Opponent wins.",
	"match_tie": "It's a tie.",
	"reload_start": "Reloading.",
}

const NVDA_HELPER_PATH := "res://bin/NvdaSpeak.exe"

var _player: AudioStreamPlayer
var _queue: Array[String] = []

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	add_child(_player)
	_player.bus = "Master"
	_player.finished.connect(_on_finished)

## Speaks a known line: tries the player's running screen reader first,
## falls back to the pre-rendered clip if no screen reader is running.
func say(key: String) -> void:
	var text: String = PHRASES.get(key, "")
	if text != "" and _speak_via_screen_reader(text):
		return
	_play_clip(key)

func say_bot_eliminated(bot_index: int) -> void:
	var key := "eliminated_bot_%d" % bot_index
	if not LINES.has(key):
		key = "eliminated_generic"
	say(key)

## Speaks "Score check. N elimination(s), N death(s)." Numbers above 20 in
## the clip-based fallback just skip the number word rather than crash.
func say_score(kills: int, deaths: int) -> void:
	var kill_word: String = "elimination" if kills == 1 else "eliminations"
	var death_word: String = "death" if deaths == 1 else "deaths"
	var text: String = "Score check. %d %s, %d %s." % [kills, kill_word, deaths, death_word]
	if _speak_via_screen_reader(text):
		return
	_play_clip("score_prefix")
	_say_number(kills)
	_play_clip("elim_singular" if kills == 1 else "elim_plural")
	_say_number(deaths)
	_play_clip("death_singular" if deaths == 1 else "death_plural")

## Speaks "Match created. Your code is 4, 7, 2, 1." digit by digit so it
## can't be misheard as a four-digit number (e.g. "four thousand ...").
func say_match_code(code: int) -> void:
	var digits: String = "%04d" % code
	var spoken_digits: Array[String] = []
	for d in digits:
		spoken_digits.append(d)
	var text: String = "Match created. Your code is %s." % ", ".join(spoken_digits)
	if _speak_via_screen_reader(text):
		return
	_play_clip("match_created")
	for d in digits:
		_say_number(int(d))

## Speaks "Match over. You win! N eliminations." (or opponent wins / tie).
func say_match_result(is_winner: bool, is_tie: bool, my_kills: int) -> void:
	var outcome_key: String
	var outcome_text: String
	if is_tie:
		outcome_key = "match_tie"
		outcome_text = "It's a tie."
	elif is_winner:
		outcome_key = "you_win"
		outcome_text = "You win!"
	else:
		outcome_key = "opponent_wins"
		outcome_text = "Opponent wins."
	var kill_word: String = "elimination" if my_kills == 1 else "eliminations"
	var text: String = "Match over. %s %d %s." % [outcome_text, my_kills, kill_word]
	if _speak_via_screen_reader(text):
		return
	_play_clip("match_over")
	_play_clip(outcome_key)
	_say_number(my_kills)
	_play_clip("elim_singular" if my_kills == 1 else "elim_plural")

## Speaks "Your position is column N, row N." for the coordinates hotkey
## (see ShooterPlayer._announce_coordinates).
func say_coordinates(tile_x: int, tile_z: int) -> void:
	var text: String = "Your position is column %d, row %d." % [tile_x, tile_z]
	if _speak_via_screen_reader(text):
		return
	_play_clip("coords_prefix")
	_say_number(tile_x)
	_play_clip("coords_row")
	_say_number(tile_z)

func _say_number(n: int) -> void:
	var key := "num_%d" % n
	if LINES.has(key):
		_play_clip(key)

## Speaks arbitrary dynamic text (e.g. Updater status) through NVDA only -
## there's no pre-rendered fallback clip for text that isn't known in
## advance, so this is silent (beyond any on-screen label) without a screen
## reader running.
func speak_text(text: String) -> void:
	_speak_via_screen_reader(text)

## Returns true if a running screen reader actually spoke the text.
func _speak_via_screen_reader(text: String) -> bool:
	var exe_path: String = _resolve_nvda_helper_path()
	if exe_path == "":
		return false
	var output: Array = []
	var exit_code: int = OS.execute(exe_path, [text], output, false, false)
	return exit_code == 0

## NvdaSpeak.exe is a real native process, not a Godot resource, so it can't
## live inside an exported build's embedded .pck - ProjectSettings.
## globalize_path() only resolves to a real file when running uncompressed
## from the editor/project folder. An exported single-file .exe therefore
## needs bin/ copied as loose files next to it (see tools/build_export.ps1);
## this checks there first and falls back to the res://-relative path so the
## same code works unmodified in the editor during development.
func _resolve_nvda_helper_path() -> String:
	var beside_exe: String = OS.get_executable_path().get_base_dir().path_join("bin/NvdaSpeak.exe")
	if FileAccess.file_exists(beside_exe):
		return beside_exe
	var dev_path: String = ProjectSettings.globalize_path(NVDA_HELPER_PATH)
	if FileAccess.file_exists(dev_path):
		return dev_path
	return ""

func _play_clip(key: String) -> void:
	var stream: AudioStream = LINES.get(key)
	if stream == null:
		return
	if _player.playing:
		_queue.append(key)
	else:
		_player.stream = stream
		_player.play()

func _on_finished() -> void:
	if _queue.size() > 0:
		var key: String = _queue.pop_front()
		_player.stream = LINES[key]
		_player.play()
