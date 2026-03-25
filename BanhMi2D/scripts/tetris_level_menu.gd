extends Control

signal minigame_closed

const TetrisData = preload("res://scripts/tetris_data.gd")
const TetrisGame = preload("res://scenes/minigames/tetris_minigame_cs.tscn")

@onready var grid = $Window/VBox/Scroll/GridContainer
@onready var btn_close = $Window/VBox/HBoxTop/BtnClose

var _data_instance: Node

func _ready() -> void:
	_data_instance = TetrisData.new()
	btn_close.pressed.connect(_on_close)
	_build_levels()

func _build_levels() -> void:
	for child in grid.get_children():
		child.queue_free()
	
	# Default setup if GameManager doesn't have it
	if not "tetris_progress" in GameManager:
		GameManager.set("tetris_progress", {})
	
	for i in range(1, 51):
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(80, 80)
		btn.text = str(i)
		
		var stars = GameManager.tetris_progress.get(i, 0)
		var is_unlocked = (i == 1) or (GameManager.tetris_progress.has(i - 1))
		
		if not is_unlocked:
			btn.disabled = true
			btn.text += "\n🔒"
		else:
			if stars > 0:
				var star_str = ""
				for s in range(stars):
					star_str += "⭐"
				btn.text += "\n" + star_str
			
			btn.pressed.connect(func(): _launch_level(i))
		
		grid.add_child(btn)

func _launch_level(level_id: int) -> void:
	var game = TetrisGame.instantiate()
	
	# The C# LevelManager handles speeds and targets based on level_id.
	game.set("StartLevel", level_id)
	
	if game.has_signal("MiniGameWon"):
		game.connect("MiniGameWon", _on_game_won)
	if game.has_signal("MinigameClosed"):
		game.connect("MinigameClosed", _on_game_closed)
	add_child(game)
	$Window.visible = false

func _on_game_won(_level_id: int, _reward: int) -> void:
	GameManager.activate_tetris_buff()
	_on_game_closed()

func _on_game_closed() -> void:
	$Window.visible = true
	_build_levels() # Refresh stars

func _on_close() -> void:
	_data_instance.free()
	emit_signal("minigame_closed")
	queue_free()
