extends VBoxContainer

const WORLD = preload("res://scene/main.tscn")

@onready var sfx_click = $SfxClick
@onready var sfx_hover = $SfxHover

func _ready():
	var player = get_tree().root.find_child("Player", true, false)
	if player:
		player.process_mode = Node.PROCESS_MODE_DISABLED
		player.set_process(false)
		player.set_physics_process(false)
		player.set_process_input(false)
		player.set_process_unhandled_input(false)
		player.set_process_unhandled_key_input(false)

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	for button in get_children():
		if button is Button:
			button.disabled = false
			button.mouse_filter = Control.MOUSE_FILTER_STOP
			button.mouse_entered.connect(_on_button_mouse_entered)

func _process(_delta: float) -> void:
	if Input.get_mouse_mode() != Input.MOUSE_MODE_VISIBLE:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

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
