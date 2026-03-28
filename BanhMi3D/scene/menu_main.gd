extends CanvasLayer

const WORLD := preload("res://scene/main.tscn")

@onready var play_button: Button = $Control/MarginContainer/VBoxContainer/Start
@onready var settings_button: Button = $Control/MarginContainer/VBoxContainer/Settings
@onready var quit_button: Button = $Control/MarginContainer/VBoxContainer/Quit

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	play_button.pressed.connect(_on_play_pressed)
	settings_button.visible = false
	settings_button.disabled = true
	quit_button.pressed.connect(_on_quit_pressed)

func _on_play_pressed() -> void:
	get_tree().change_scene_to_packed(WORLD)

func _on_quit_pressed() -> void:
	get_tree().quit()
