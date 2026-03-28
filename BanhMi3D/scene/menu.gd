extends VBoxContainer

const WORLD = preload("res://scene/main.tscn")

@onready var sfx_click = $SfxClick
@onready var sfx_hover = $SfxHover

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	for button in get_children():
		if button is Button:
			button.mouse_entered.connect(_on_button_mouse_entered)

func _on_button_mouse_entered():
	sfx_hover.play()

func _on_play_pressed() -> void:
	sfx_click.play()
	await get_tree().create_timer(0.15).timeout
	get_tree().change_scene_to_packed(WORLD)

func _on_quit_pressed() -> void:
	sfx_click.play()
	await get_tree().create_timer(0.2).timeout
	get_tree().quit()
