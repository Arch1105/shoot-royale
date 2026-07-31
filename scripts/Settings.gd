extends Control

const MASTER_BUS := "Master"

@onready var volume_slider: HSlider = $VBoxContainer/VolumeSlider
@onready var back_button: Button = $VBoxContainer/BackButton

func _ready() -> void:
	var bus_idx := AudioServer.get_bus_index(MASTER_BUS)
	volume_slider.value = clamp(db_to_linear(AudioServer.get_bus_volume_db(bus_idx)) * 100.0, 0.0, 100.0)
	volume_slider.value_changed.connect(_on_volume_changed)
	back_button.pressed.connect(_on_back_pressed)
	volume_slider.grab_focus()

func _on_volume_changed(value: float) -> void:
	var bus_idx := AudioServer.get_bus_index(MASTER_BUS)
	AudioServer.set_bus_volume_db(bus_idx, linear_to_db(max(value, 0.001) / 100.0))

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
