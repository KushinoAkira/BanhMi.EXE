extends Control

signal minigame_closed

const XiangqiGame = preload("res://scenes/minigames/xiangqi_minigame.tscn")

@onready var grid = $Window/VBox/Scroll/GridContainer
@onready var btn_close = $Window/VBox/HBoxTop/BtnClose

func _ready() -> void:
	btn_close.pressed.connect(_on_close)
	_build_levels()

func _build_levels() -> void:
	for child in grid.get_children():
		child.queue_free()
	
	for i in range(1, 51):
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(80, 80)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var tier := ""
		if i <= 10:
			tier = "📜"
		elif i <= 25:
			tier = "⚔️"
		elif i <= 40:
			tier = "🐲"
		else:
			tier = "👑"
		
		btn.text = tier + "\n" + str(i)
		
		var is_unlocked = (i == 1) or (GameManager.xiangqi_progress.has(i - 1))
		
		if not is_unlocked:
			btn.disabled = true
			btn.text += "\n🔒"
		else:
			# Show stars if completed
			var star_val = GameManager.xiangqi_progress.get(i, 0)
			var star_count: int = 0
			if typeof(star_val) == TYPE_INT or typeof(star_val) == TYPE_FLOAT:
				star_count = int(star_val)
			elif typeof(star_val) == TYPE_BOOL:
				star_count = 1 if star_val else 0
			
			if star_count > 0:
				var star_str = ""
				for s in range(star_count):
					star_str += "⭐"
				btn.text += "\n" + star_str
			
			btn.pressed.connect(func(): _launch_level(i))
		
		grid.add_child(btn)

func _launch_level(level_id: int) -> void:
	var game = XiangqiGame.instantiate()
	if "StartLevel" in game:
		game.StartLevel = level_id - 1
	if game.has_signal("MiniGameClosed"):
		game.connect("MiniGameClosed", _on_game_closed)
	if game.has_signal("MiniGameWon"):
		game.connect("MiniGameWon", _on_game_won.bind(level_id))
	
	add_child(game)
	$Window.visible = false

func _on_game_won(_level_index: int, _reward: int, stars: int, level_id: int) -> void:
	# Save stars (keep best)
	var old_val = GameManager.xiangqi_progress.get(level_id, 0)
	var old_stars: int = 0
	if typeof(old_val) == TYPE_INT or typeof(old_val) == TYPE_FLOAT:
		old_stars = int(old_val)
	elif typeof(old_val) == TYPE_BOOL:
		old_stars = 1 if old_val else 0
	
	if stars > old_stars:
		GameManager.xiangqi_progress[level_id] = stars
	elif not GameManager.xiangqi_progress.has(level_id):
		GameManager.xiangqi_progress[level_id] = stars
	
	GameManager.add_money(_reward)
	_on_game_closed()

func _on_game_closed() -> void:
	$Window.visible = true
	_build_levels()

func _on_close() -> void:
	emit_signal("minigame_closed")
	queue_free()
