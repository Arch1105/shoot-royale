extends Control
## Host / Join screen for the Multiplayer Shootout mode. All critical status
## (the match code, connection state, timeouts) is spoken through Voice, not
## just shown as label text - see the comment in Voice.gd about NVDA vs the
## pre-rendered fallback clips; the on-screen labels are a visual bonus, not
## the primary channel.

@onready var status_label: Label = $VBoxContainer/StatusLabel
@onready var host_button: Button = $VBoxContainer/HostButton
@onready var join_button: Button = $VBoxContainer/JoinButton
@onready var code_input: LineEdit = $VBoxContainer/CodeInput
@onready var join_confirm_button: Button = $VBoxContainer/JoinConfirmButton
@onready var back_button: Button = $VBoxContainer/BackButton

var _host: LanHost
var _client: LanClient

func _ready() -> void:
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	join_confirm_button.pressed.connect(_on_join_confirm_pressed)
	back_button.pressed.connect(_on_back_pressed)
	code_input.text_submitted.connect(func(_t: String) -> void: _on_join_confirm_pressed())
	_set_join_controls_visible(false)
	host_button.grab_focus()

func _set_join_controls_visible(is_visible: bool) -> void:
	code_input.visible = is_visible
	join_confirm_button.visible = is_visible

func _on_host_pressed() -> void:
	host_button.disabled = true
	join_button.disabled = true
	_host = LanHost.new()
	add_child(_host)
	_host.match_code_ready.connect(_on_match_code_ready)
	_host.client_connected.connect(_on_client_connected)
	var code: int = _host.start_hosting()
	if code < 0:
		status_label.text = "Could not start hosting on this network."
		host_button.disabled = false
		join_button.disabled = false

func _on_match_code_ready(code: int) -> void:
	status_label.text = "Match code: %04d. Waiting for opponent..." % code
	Voice.say_match_code(code)

func _on_client_connected(_id: int) -> void:
	Voice.say("connected")
	get_tree().change_scene_to_file("res://scenes/shooter/ShootoutArena.tscn")

func _on_join_pressed() -> void:
	host_button.disabled = true
	join_button.disabled = true
	_set_join_controls_visible(true)
	status_label.text = "Enter the 4-digit match code, then press Enter."
	code_input.grab_focus()

func _on_join_confirm_pressed() -> void:
	var code_text: String = code_input.text.strip_edges()
	if code_text.length() != 4 or not code_text.is_valid_int():
		status_label.text = "Enter a 4-digit code."
		return
	join_confirm_button.disabled = true
	code_input.editable = false
	status_label.text = "Searching for match..."
	Voice.say("searching_for_match")
	_client = LanClient.new()
	add_child(_client)
	_client.connected_to_server.connect(_on_connected_to_server)
	_client.timed_out.connect(_on_search_timed_out)
	_client.connection_failed.connect(_on_search_timed_out)
	_client.start_search(int(code_text))

func _on_connected_to_server() -> void:
	Voice.say("connected")
	get_tree().change_scene_to_file("res://scenes/shooter/ShootoutArena.tscn")

func _on_search_timed_out() -> void:
	status_label.text = "No match found with that code."
	Voice.say("no_match_found")
	join_confirm_button.disabled = false
	code_input.editable = true
	code_input.grab_focus()
	if _client:
		_client.stop()
		_client.queue_free()
		_client = null

func _on_back_pressed() -> void:
	if _host:
		_host.stop()
	if _client:
		_client.stop()
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
