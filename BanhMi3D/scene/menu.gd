extends VBoxContainer

const WORLD = preload("res://scene/main.tscn")

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_play_pressed() -> void:
	get_tree().change_scene_to_packed(WORLD)

func _on_quit_pressed() -> void:
	get_tree().quit()
