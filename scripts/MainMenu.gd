extends Control
## Main menu. Buttons carry accessibility_name/description (Godot 4.5+
## AccessKit integration) so any running screen reader - NVDA, Narrator,
## JAWS - announces them automatically on focus; no custom plugin needed.

@onready var play_button: Button = $VBoxContainer/PlayButton
@onready var shootout_button: Button = $VBoxContainer/ShootoutButton
@onready var settings_button: Button = $VBoxContainer/SettingsButton
@onready var update_button: Button = $VBoxContainer/UpdateButton
@onready var exit_button: Button = $VBoxContainer/ExitButton
@onready var status_label: Label = $VBoxContainer/StatusLabel

var _updater: Updater

func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	shootout_button.pressed.connect(_on_shootout_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	update_button.pressed.connect(_on_update_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	play_button.grab_focus()

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_shootout_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/shooter/ShootoutMenu.tscn")

func _on_settings_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Settings.tscn")

func _on_exit_pressed() -> void:
	get_tree().quit()

func _on_update_pressed() -> void:
	update_button.disabled = true
	status_label.text = "Checking for updates..."
	_updater = Updater.new()
	add_child(_updater)
	_updater.update_available.connect(_on_update_available)
	_updater.up_to_date.connect(_on_up_to_date)
	_updater.check_failed.connect(_on_update_check_failed)
	_updater.ready_to_restart.connect(_on_ready_to_restart)
	_updater.check_for_update()

func _on_update_available(version: String) -> void:
	status_label.text = "Update %s found. Downloading..." % version
	_updater.start_download()

func _on_up_to_date() -> void:
	status_label.text = "You're already on the latest version."
	Voice.speak_text("You're already on the latest version.")
	update_button.disabled = false

func _on_update_check_failed(reason: String) -> void:
	var message: String = "Could not check for updates."
	if reason == "repo_not_configured":
		message = "Updates aren't set up for this build yet."
	status_label.text = message
	Voice.speak_text(message)
	update_button.disabled = false

func _on_ready_to_restart() -> void:
	status_label.text = "Update downloaded. Restarting..."
	_updater.install_and_restart()
