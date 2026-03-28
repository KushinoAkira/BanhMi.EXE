extends Control

const NEXT_SCENE := "res://scene/main.tscn"

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var voice_player: AudioStreamPlayer = $VoicePlayer

var _is_transitioning := false
var _last_voice_stream: AudioStream = null

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_last_voice_stream = voice_player.stream
	if _last_voice_stream != null:
		voice_player.play()

	if animation_player != null and animation_player.has_animation("intro"):
		animation_player.play("intro")
		await animation_player.animation_finished

	_go_to_next_scene()

func _process(_delta: float) -> void:
	if _is_transitioning:
		return

	if voice_player.stream != _last_voice_stream:
		_last_voice_stream = voice_player.stream
		if _last_voice_stream != null:
			voice_player.stop()
			voice_player.play()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		_go_to_next_scene()
		return

	if event is InputEventMouseButton and event.pressed:
		_go_to_next_scene()

func _go_to_next_scene() -> void:
	if _is_transitioning:
		return

	_is_transitioning = true
	if voice_player.playing:
		voice_player.stop()
	get_tree().change_scene_to_file(NEXT_SCENE)
