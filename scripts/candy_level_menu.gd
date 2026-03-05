extends Control

signal minigame_closed

const CandyGame = preload("res://scenes/minigames/candy_minigame_cs.tscn")

@onready var grid = $Window/VBox/Scroll/GridContainer
@onready var btn_close = $Window/VBox/HBoxTop/BtnClose

func _ready() -> void:
	btn_close.pressed.connect(_on_close)
	_build_levels()

func _build_levels() -> void:
	for child in grid.get_children():
		child.queue_free()
	
	if not "candy_progress" in GameManager:
		GameManager.set("candy_progress", {})
	
	for i in range(1, 51):
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(80, 80)
		btn.text = str(i)
		
		var stars = GameManager.candy_progress.get(i, 0)
		var is_unlocked = (i == 1) or (GameManager.candy_progress.has(i - 1))
		
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
	var game = CandyGame.instantiate()
	game.set("StartLevel", level_id)
	
	if game.has_signal("MinigameClosed"):
		game.connect("MinigameClosed", _on_game_closed)
	if game.has_signal("MiniGameWon"):
		game.connect("MiniGameWon", _on_game_won)
	
	add_child(game)
	$Window.visible = false

func _on_game_won(_level_id: int, _reward: int) -> void:
	if not "candy_progress" in GameManager:
		GameManager.set("candy_progress", {})
	# Stars saved by the C# code already; we just refresh
	_on_game_closed()

func _on_game_closed() -> void:
	$Window.visible = true
	_build_levels()

func _on_close() -> void:
	emit_signal("minigame_closed")
	queue_free()
