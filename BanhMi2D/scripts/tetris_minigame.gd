extends Control

signal minigame_closed

const GRID_W = 10
const GRID_H = 20
const CELL_SIZE = 32

const SHAPES = [
	{ "color": Color.CYAN, "blocks": [Vector2i(0,0), Vector2i(-1,0), Vector2i(1,0), Vector2i(2,0)] },
	{ "color": Color.BLUE, "blocks": [Vector2i(0,0), Vector2i(-1,-1), Vector2i(-1,0), Vector2i(1,0)] },
	{ "color": Color.ORANGE, "blocks": [Vector2i(0,0), Vector2i(1,-1), Vector2i(-1,0), Vector2i(1,0)] },
	{ "color": Color.YELLOW, "blocks": [Vector2i(0,0), Vector2i(1,0), Vector2i(0,-1), Vector2i(1,-1)] },
	{ "color": Color.GREEN, "blocks": [Vector2i(0,0), Vector2i(1,0), Vector2i(0,-1), Vector2i(-1,-1)] },
	{ "color": Color.PURPLE, "blocks": [Vector2i(0,-1), Vector2i(-1,0), Vector2i(0,0), Vector2i(1,0)] }, # T rotated
	{ "color": Color.RED, "blocks": [Vector2i(0,0), Vector2i(-1,0), Vector2i(0,-1), Vector2i(1,-1)] }
]

# Config from Menu
var start_level: int = 1
var target_lines: int = 10
var start_speed: float = 1.0
var star_scores: Array = [1000, 2000, 3000]

var grid_data = [] # 2D array [y][x] of Color or null
var active_piece = {}
var active_pos := Vector2i(0, 0)
var active_blocks := []
var next_piece = {}
var hold_piece = {}
var can_hold := true
var piece_bag := []

var score := 0
var lines_cleared := 0
var is_game_over := false
var has_won := false

@onready var game_area = $Window/HBoxContainer/GameArea
@onready var grid_bg = $Window/HBoxContainer/GameArea/GridBackground
@onready var tiles_node = $Window/HBoxContainer/GameArea/Tiles
@onready var lbl_score = $Window/HBoxContainer/RightPanel/LblScore
@onready var lbl_level = $Window/HBoxContainer/RightPanel/LblLevel
@onready var lbl_target = $Window/HBoxContainer/RightPanel/LblTarget
@onready var next_piece_preview = $Window/HBoxContainer/RightPanel/NextPieceBox/Preview
@onready var btn_close = $Window/HBoxContainer/LeftPanel/BtnClose
@onready var hold_piece_preview = $Window/HBoxContainer/LeftPanel/HoldPieceBox/Preview
@onready var fall_timer = $FallTimer

# Victory Popup
@onready var victory_popup = $VictoryPopup
@onready var lbl_vic_stars = $VictoryPopup/Panel/VBox/LblStars
@onready var lbl_vic_score = $VictoryPopup/Panel/VBox/LblScore
@onready var btn_vic_ok = $VictoryPopup/Panel/VBox/BtnOk

func _refill_bag() -> void:
	piece_bag = SHAPES.duplicate()
	piece_bag.shuffle()

func _get_next_bag_piece() -> Dictionary:
	if piece_bag.is_empty(): _refill_bag()
	return piece_bag.pop_back()

func _ready() -> void:
	btn_close.pressed.connect(_on_close)
	btn_vic_ok.pressed.connect(_on_close)
	fall_timer.timeout.connect(_on_fall_tick)
	
	if victory_popup: victory_popup.visible = false
	
	_init_grid()
	_update_ui()
	
	# Generate first piece and next piece
	_refill_bag()
	next_piece = _get_next_bag_piece()
	_spawn_piece()
	
	fall_timer.start(start_speed)

func _spawn_piece() -> void:
	can_hold = true
	active_piece = next_piece
	active_blocks = active_piece["blocks"].duplicate()
	active_pos = Vector2i(GRID_W / 2 - 1, 1)
	
	next_piece = _get_next_bag_piece()
	_draw_next_piece()
	
	if not _is_valid_pos(active_pos, active_blocks):
		_trigger_game_over(false)
	else:
		_draw_grid()

func _input(event: InputEvent) -> void:
	if is_game_over: return
	if event.is_action_pressed("ui_left"): _move_piece(-1, 0)
	elif event.is_action_pressed("ui_right"): _move_piece(1, 0)
	elif event.is_action_pressed("ui_down"): _move_piece(0, 1)
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("ui_accept"): _rotate_piece()
	elif event.is_action_pressed("ui_select"): _hard_drop()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SHIFT or event.keycode == KEY_C:
			_hold_piece()

func _init_grid() -> void:
	grid_data.clear()
	for y in range(GRID_H):
		var row = []
		for x in range(GRID_W):
			row.append(null)
		grid_data.append(row)

func _hold_piece() -> void:
	if not can_hold or is_dropping: return
	
	can_hold = false
	if hold_piece.is_empty():
		hold_piece = active_piece
		_spawn_piece()
	else:
		var temp = active_piece
		active_piece = hold_piece
		hold_piece = temp
		
		active_blocks = active_piece["blocks"].duplicate()
		active_pos = Vector2i(GRID_W / 2 - 1, 1)
		_draw_grid()
		
	_draw_hold_piece()

func _draw_hold_piece() -> void:
	if not hold_piece_preview: return
	for child in hold_piece_preview.get_children():
		child.queue_free()
	
	# Draw hold piece shifted slightly
	var ox = 2
	var oy = 2
	for b in hold_piece["blocks"]:
		_create_rect_float(hold_piece_preview, float(ox + b.x), float(oy + b.y), hold_piece["color"], 24)

var lock_delay := 0.5
var lock_time_elapsed := 0.0
var lock_resumes := 0
const MAX_LOCK_RESUMES = 15
var is_touching_ground := false

var wall_kicks = [
	Vector2i(-1, 0), Vector2i(1, 0),
	Vector2i(0, -1),
	Vector2i(-1, -1), Vector2i(1, -1),
	Vector2i(-2, 0), Vector2i(2, 0),
	Vector2i(0, -2)
]

func _move_piece(dx: int, dy: int) -> void:
	var new_pos = active_pos + Vector2i(dx, dy)
	if _is_valid_pos(new_pos, active_blocks):
		active_pos = new_pos
		if dy > 0:
			lock_time_elapsed = 0.0
			lock_resumes = 0
		elif is_touching_ground and lock_resumes < MAX_LOCK_RESUMES:
			lock_time_elapsed = 0.0
			lock_resumes += 1
		_draw_grid()

var is_dropping := false

func _hard_drop() -> void:
	if is_dropping: return
	
	var drop_y = active_pos.y
	while _is_valid_pos(Vector2i(active_pos.x, drop_y + 1), active_blocks):
		drop_y += 1
		
	if drop_y == active_pos.y:
		_lock_piece()
		return
		
	is_dropping = true
	var distance = drop_y - active_pos.y
	# 0.02s per block, max 0.15s
	var duration = minf(0.15, distance * 0.02)
	
	# We temporarily disable standard tick falling while gliding down
	fall_timer.stop()
	
	# We'll use a local var to track position smoothly just for drawing
	var tween = create_tween()
	
	# Tween a "visual_y" property on self (requires a dummy setter or straight var if Godot 4)
	# For simplicity without a dedicated property, we can just tween a dummy value and call _draw_grid manually
	var start_y = active_pos.y
	active_pos.y = drop_y # Logical position updates instantly so input stops
	
	# Tween the visual offset of active piece during _draw_grid
	visual_drop_offset = float(start_y - drop_y)
	
	tween.tween_property(self, "visual_drop_offset", 0.0, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(func():
		is_dropping = false
		_lock_piece()
		_shake_board()
	)

func _shake_board() -> void:
	var shake_tween = create_tween()
	var og_pos = game_area.position
	# Quick down and up shake
	shake_tween.tween_property(game_area, "position:y", og_pos.y + 10, 0.05)
	shake_tween.tween_property(game_area, "position:y", og_pos.y, 0.05)
	shake_tween.tween_property(game_area, "position:y", og_pos.y + 4, 0.04)
	shake_tween.tween_property(game_area, "position:y", og_pos.y, 0.04)

var visual_drop_offset := 0.0

func _rotate_piece() -> void:
	if active_piece["color"] == Color.YELLOW: return
	
	var new_blocks = []
	for b in active_blocks:
		new_blocks.append(Vector2i(-b.y, b.x))
	
	if _is_valid_pos(active_pos, new_blocks):
		_apply_rotation(new_blocks, active_pos)
		return
	
	# Wall kicks
	for kick in wall_kicks:
		if _is_valid_pos(active_pos + kick, new_blocks):
			_apply_rotation(new_blocks, active_pos + kick)
			return

func _apply_rotation(new_blocks: Array, new_pos: Vector2i) -> void:
	active_blocks = new_blocks
	active_pos = new_pos
	if is_touching_ground and lock_resumes < MAX_LOCK_RESUMES:
		lock_time_elapsed = 0.0
		lock_resumes += 1
	_draw_grid()

func _is_valid_pos(pos: Vector2i, blocks: Array) -> bool:
	for b in blocks:
		var check_x = pos.x + b.x
		var check_y = pos.y + b.y
		if check_x < 0 or check_x >= GRID_W or check_y < 0 or check_y >= GRID_H:
			return false
		if check_y >= 0 and grid_data[check_y][check_x] != null:
			return false
	return true

func _lock_piece() -> void:
	for b in active_blocks:
		var bx = active_pos.x + b.x
		var by = active_pos.y + b.y
		if by >= 0 and by < GRID_H and bx >= 0 and bx < GRID_W:
			grid_data[by][bx] = active_piece["color"]
	
	_clear_lines()
	if not is_game_over:
		_spawn_piece()

func _clear_lines() -> void:
	var lines_to_clear = []
	for y in range(GRID_H):
		var is_full = true
		for x in range(GRID_W):
			if grid_data[y][x] == null:
				is_full = false
				break
		if is_full:
			lines_to_clear.append(y)
	
	var num_cleared = lines_to_clear.size()
	if num_cleared > 0:
		for y in lines_to_clear:
			grid_data.remove_at(y)
			var empty_row = []
			empty_row.resize(GRID_W)
			empty_row.fill(null)
			grid_data.push_front(empty_row)
		
		lines_cleared += num_cleared
		
		var reward = 0
		if num_cleared == 1: reward = 100
		elif num_cleared == 2: reward = 300
		elif num_cleared == 3: reward = 500
		elif num_cleared == 4: reward = 800
		
		# Combo / level multiplier could go here, for now flat score
		score += reward
		
		_update_ui()
		_draw_grid()
		
		if lines_cleared >= target_lines:
			_trigger_game_over(true)

func _on_fall_tick() -> void:
	if is_dropping or is_game_over: return
	
	if not _is_valid_pos(active_pos + Vector2i(0, 1), active_blocks):
		pass # Lock delay is now handling this inside _process
	else:
		active_pos.y += 1
		lock_time_elapsed = 0.0
		lock_resumes = 0
		_draw_grid()

func _trigger_game_over(win: bool) -> void:
	is_game_over = true
	has_won = win
	fall_timer.stop()
	
	_draw_grid() # One last draw to be sure everything is stable
	
	if not win:
		var lbl = $Window/HBoxContainer/GameArea/LblGameOver
		if lbl: lbl.visible = true
	else:
		_calculate_victory()

func _calculate_victory() -> void:
	var stars = 0
	if score >= star_scores[2]: stars = 3
	elif score >= star_scores[1]: stars = 2
	elif score >= star_scores[0]: stars = 1
	else: stars = 1 # Minimum 1 star for finishing
	
	# Update GameManager Progress
	var prev_stars = GameManager.tetris_progress.get(start_level, 0)
	if stars > prev_stars:
		GameManager.tetris_progress[start_level] = stars
	
	# Give reward
	var reward = (stars * 50) + (score / 10)
	GameManager.add_money(reward)
	
	# Show Popup
	if victory_popup:
		var star_str = ""
		for i in range(stars):
			star_str += "⭐"
		lbl_vic_stars.text = star_str
		lbl_vic_score.text = "Score: %d\nReward: +%dđ" % [score, reward]
		victory_popup.visible = true

func _draw_grid() -> void:
	for child in tiles_node.get_children():
		child.queue_free()
	
	# Draw locked blocks
	for y in range(GRID_H):
		for x in range(GRID_W):
			if grid_data[y][x] != null:
				_create_rect(tiles_node, x, y, grid_data[y][x])
	
	if not is_game_over:
		# Draw Ghost Piece (only if not currently hard-dropping)
		if not is_dropping:
			var ghost_y = active_pos.y
			while _is_valid_pos(Vector2i(active_pos.x, ghost_y + 1), active_blocks):
				ghost_y += 1
			var ghost_color = active_piece["color"]
			ghost_color.a = 0.3
			for b in active_blocks:
				_create_rect(tiles_node, active_pos.x + b.x, ghost_y + b.y, ghost_color)
		
		# Draw active piece
		# If dropping, we subtract the visual_drop_offset from its logical final Y
		for b in active_blocks:
			var draw_y_offset = -visual_drop_offset if is_dropping else 0.0
			_create_rect_float(tiles_node, float(active_pos.x + b.x), float(active_pos.y + b.y) + draw_y_offset, active_piece["color"])

func _process(delta: float) -> void:
	if is_dropping:
		_draw_grid()
		return
		
	if is_game_over: return
	
	is_touching_ground = not _is_valid_pos(active_pos + Vector2i(0, 1), active_blocks)
	
	if is_touching_ground:
		lock_time_elapsed += delta
		if lock_time_elapsed >= lock_delay:
			_lock_piece()
	else:
		lock_time_elapsed = 0.0

func _create_rect(parent: Node, x: int, y: int, color: Color, size: int = CELL_SIZE) -> void:
	_create_rect_float(parent, float(x), float(y), color, size)

func _create_rect_float(parent: Node, x: float, y: float, color: Color, size: int = CELL_SIZE) -> void:
	# Main colored block
	var rect = ColorRect.new()
	rect.color = color
	rect.size = Vector2(size, size)
	rect.position = Vector2(x * size, y * size)
	parent.add_child(rect)
	
	# Inner darker border for modern Tetr.io look
	var inner_rect = ColorRect.new()
	inner_rect.color = color.darkened(0.4)
	inner_rect.size = Vector2(size - 4, size - 4)
	inner_rect.position = Vector2(2, 2)
	rect.add_child(inner_rect)
	
	# Bright center
	var center_rect = ColorRect.new()
	center_rect.color = color.lightened(0.1)
	center_rect.size = Vector2(size - 8, size - 8)
	center_rect.position = Vector2(4, 4)
	rect.add_child(center_rect)

func _draw_next_piece() -> void:
	if not next_piece_preview: return
	for child in next_piece_preview.get_children():
		child.queue_free()
	
	var ox = 2
	var oy = 2
	for b in next_piece["blocks"]:
		_create_rect(next_piece_preview, ox + b.x, oy + b.y, next_piece["color"], 24)

func _update_ui() -> void:
	if lbl_score: lbl_score.text = "Score: %d" % score
	if lbl_level: lbl_level.text = "Level: %d" % start_level
	if lbl_target: lbl_target.text = "Lines: %d/%d" % [lines_cleared, target_lines]

func _on_close() -> void:
	emit_signal("minigame_closed")
	queue_free()
