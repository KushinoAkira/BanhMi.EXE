## ui_manager.gd — Quản lý UI Bottom Bar + Money Display
## Gắn vào CanvasLayer UILayer trong Main scene
extends CanvasLayer

# ─── PRELOAD ───────────────────────────────────────────────
const UpgradeCardScript = preload("res://scripts/upgrade_card.gd")

# ─── ONREADY NODES ────────────────────────────────────────
@onready var money_label: Label = $MoneyLabel
@onready var time_label: Label = $TimeLabel
@onready var bottom_bar: MarginContainer = $BottomBar
@onready var panel_bg: Panel = $BottomBar/PanelBG
@onready var scroll_container: ScrollContainer = $BottomBar/ScrollContainer
@onready var card_container: HBoxContainer = $BottomBar/ScrollContainer/HBoxContainer

var last_money: int = 0
var _bar_open := false
var _bar_height: float = 0.0
var _toggle_btn: Button

# ─── TUTORIAL STATE ───────────────────────────────────────
var tutorial_bg: ColorRect
var tutorial_arrow: TextureRect
var tutorial_label: Label
var tutorial_step: int = -1
var tutorial_tween: Tween

@onready var background_music: AudioStreamPlayer = $"../BackgroundMusic"

# ─── READY ─────────────────────────────────────────────────
func _ready() -> void:
	_setup_money_label()
	_setup_time_label()
	_setup_bottom_bar()
	_populate_upgrade_cards()

	GameManager.money_changed.connect(_on_money_changed)
	_update_money_display(GameManager.money)
	GameManager.time_changed.connect(_on_time_changed)
	_update_time_display(GameManager.current_hour, GameManager.current_minute)
	
	_setup_minigames()
	_create_toggle_button()
	
	# Start with bar hidden
	_bar_open = false
	# Defer the hide so the bar is fully laid out first
	call_deferred("_hide_bar_instant")
	
	if not GameManager.has_played_intro:
		SettingsUI.btn_gear.hide()
		call_deferred("_play_intro_video")
	elif not GameManager.has_played_tutorial:
		SettingsUI.btn_gear.show()
		call_deferred("_start_tutorial")
	else:
		SettingsUI.btn_gear.show()
		if background_music:
			background_music.play()

func _play_intro_video() -> void:
	GameManager.has_played_intro = true
	
	var video_layer := CanvasLayer.new()
	video_layer.layer = 100 # Always on top
	get_tree().root.add_child(video_layer)
	
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	video_layer.add_child(bg)
	var player := VideoStreamPlayer.new()
	player.expand = false # Allow it to use its native texture size
	
	# Create an inline script to force STRETCH_COVER behavior dynamically
	var script := GDScript.new()
	script.source_code = """
extends VideoStreamPlayer
func _process(_delta: float) -> void:
    var vp_size = get_viewport().get_visible_rect().size
    var tex = get_video_texture()
    var vid_size = tex.get_size() if tex else Vector2(1920, 1080)
    if vid_size.x == 0 or vid_size.y == 0:
        return
    
    # Calculate scale factor to COVER the entire viewport
    var scale_factor = maxf(vp_size.x / vid_size.x, vp_size.y / vid_size.y)
    scale = Vector2(scale_factor, scale_factor)
    
    # Center the scaled video
    position = (vp_size - (vid_size * scale_factor)) / 2.0
"""
	script.reload()
	player.set_script(script)

	# Attempt to load the OGV file.
	var stream_res = load("res://assets/Video/BanhMi.EXE.ogv")
	if stream_res:
		player.stream = stream_res
	else:
		push_warning("Could not load intro video stream.")
	video_layer.add_child(player)
	
	var skip_btn := Button.new()
	skip_btn.text = " Bỏ qua >> "
	skip_btn.add_theme_font_size_override("font_size", 24)
	skip_btn.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	skip_btn.offset_left = -160 # Push leftwards exactly 160px from the right edge
	skip_btn.offset_right = -10 # 10px padding from right edge
	skip_btn.offset_top = 20    # 20px padding from top edge
	skip_btn.offset_bottom = 70
	var on_video_end = func():
		# Spawn the story dialog
		var IntroStory = load("res://scripts/intro_story.gd")
		var story_node = CanvasLayer.new()
		story_node.set_script(IntroStory)
		get_tree().root.add_child(story_node)
		
		# Once the story finishes, free the video layer entirely and start tutorial
		story_node.story_finished.connect(func(): 
			video_layer.queue_free()
			SettingsUI.btn_gear.show()
			call_deferred("_start_tutorial")
		)
		
		# Hide and stop video player so we only see clouds and story on top
		player.hide()
		player.stop()
		bg.hide()
		skip_btn.hide()

	skip_btn.pressed.connect(on_video_end)
	video_layer.add_child(skip_btn)
	
	player.finished.connect(on_video_end)
	player.play()

func _hide_bar_instant() -> void:
	# Reset anchors so we can control position.y directly
	bottom_bar.anchor_top = 0
	bottom_bar.anchor_bottom = 0
	bottom_bar.anchor_left = 0
	bottom_bar.anchor_right = 1.0
	bottom_bar.offset_top = 0
	bottom_bar.offset_bottom = bottom_bar.size.y
	_bar_height = bottom_bar.size.y
	bottom_bar.position.y = get_viewport().get_visible_rect().size.y

func _create_toggle_button() -> void:
	_toggle_btn = Button.new()
	_toggle_btn.text = "🛒"
	_toggle_btn.size = Vector2(56, 56)
	_toggle_btn.add_theme_font_size_override("font_size", 24)
	
	# Style the button
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.14, 0.22, 0.95)
	style.border_color = Color(0.3, 0.6, 1.0, 0.7)
	style.set_border_width_all(2)
	style.set_corner_radius_all(28)
	_toggle_btn.add_theme_stylebox_override("normal", style)
	
	var hover_style := style.duplicate()
	hover_style.bg_color = Color(0.18, 0.22, 0.35, 0.98)
	hover_style.border_color = Color(0.4, 0.7, 1.0, 1.0)
	_toggle_btn.add_theme_stylebox_override("hover", hover_style)
	
	var pressed_style := style.duplicate()
	pressed_style.bg_color = Color(0.25, 0.30, 0.45, 1.0)
	_toggle_btn.add_theme_stylebox_override("pressed", pressed_style)
	
	_toggle_btn.pressed.connect(_on_toggle_pressed)
	add_child(_toggle_btn)
	_update_toggle_position()
	get_viewport().size_changed.connect(_update_toggle_position)

func _update_toggle_position() -> void:
	var screen = get_viewport().get_visible_rect().size
	_toggle_btn.position = Vector2(screen.x - 66, screen.y - 66)

func _on_toggle_pressed() -> void:
	if _bar_open:
		_slide_bar_down()
	else:
		_slide_bar_up()

func _slide_bar_up() -> void:
	_bar_open = true
	_toggle_btn.text = "✕"
	var screen_h = get_viewport().get_visible_rect().size.y
	var bar_h = bottom_bar.size.y
	var target_y = screen_h - bar_h
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(bottom_bar, "position:y", target_y, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_toggle_btn, "position:y", target_y - 66, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _slide_bar_down() -> void:
	_bar_open = false
	_toggle_btn.text = "🛒"
	var screen_h = get_viewport().get_visible_rect().size.y
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(bottom_bar, "position:y", screen_h, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(_toggle_btn, "position:y", screen_h - 66, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

# ─── INTERACTIVE TUTORIAL ─────────────────────────────────
func _start_tutorial() -> void:
	if GameManager.has_played_tutorial: return
	tutorial_step = 0
	
	tutorial_bg = ColorRect.new()
	tutorial_bg.color = Color(0, 0, 0, 0.6)
	tutorial_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# IMPORTANT: Change to ignore pass so input can reach underneath if needed (or handle manually)
	tutorial_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	tutorial_bg.gui_input.connect(_on_tutorial_input)
	add_child(tutorial_bg)
	
	tutorial_arrow = TextureRect.new()
	tutorial_arrow.texture = load("res://assets/sprites/ui/tutorial_arrow.png")
	tutorial_arrow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tutorial_arrow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tutorial_arrow.custom_minimum_size = Vector2(80, 80)
	tutorial_arrow.pivot_offset = Vector2(40, 40)
	tutorial_arrow.z_index = 101 # Keep arrow above button
	
	# Apply a shader to key out the gray/white checkerboard background
	var sh_code = """
	shader_type canvas_item;
	void fragment() {
		vec4 c = texture(TEXTURE, UV);
		float avg = (c.r + c.g + c.b) / 3.0;
		float diff = abs(c.r - avg) + abs(c.g - avg) + abs(c.b - avg);
		// Checkerboard is completely grayscale and light
		if (diff < 0.05 && avg > 0.5) {
			COLOR = vec4(0.0);
		} else {
			COLOR = c;
		}
	}
	"""
	var sh = Shader.new()
	sh.code = sh_code
	var mat = ShaderMaterial.new()
	mat.shader = sh
	tutorial_arrow.material = mat
	
	add_child(tutorial_arrow)
	
	tutorial_label = Label.new()
	tutorial_label.add_theme_font_size_override("font_size", 28)
	tutorial_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tutorial_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tutorial_label.custom_minimum_size = Vector2(400, 0)
	tutorial_label.z_index = 101
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.2, 0.95)
	style.border_color = Color(1.0, 0.8, 0.2)
	style.set_border_width_all(3)
	style.set_corner_radius_all(12)
	style.content_margin_top = 15
	style.content_margin_bottom = 15
	style.content_margin_left = 15
	style.content_margin_right = 15
	tutorial_label.add_theme_stylebox_override("normal", style)
	add_child(tutorial_label)
	
	_show_tutorial_step()

func _show_tutorial_step() -> void:
	if tutorial_tween: tutorial_tween.kill()
	tutorial_tween = create_tween().set_loops()
	
	var screen_size = get_viewport().get_visible_rect().size
	
	if tutorial_step == 0:
		tutorial_label.text = "Bấm vào nút này để mở Cửa Hàng Nâng Cấp!"
		var btn_pos = _toggle_btn.global_position
		tutorial_arrow.rotation_degrees = 0
		tutorial_arrow.flip_h = false
		tutorial_arrow.flip_v = false
		
		# Move the arrow UP slightly by subtracting Y (btn_pos.y) instead of adding
		tutorial_arrow.position = btn_pos - Vector2(100, 10)
		tutorial_tween.tween_property(tutorial_arrow, "position:x", btn_pos.x - 70, 0.5).set_trans(Tween.TRANS_SINE)
		tutorial_tween.tween_property(tutorial_arrow, "position:x", btn_pos.x - 100, 0.5).set_trans(Tween.TRANS_SINE)
		tutorial_label.position = Vector2(screen_size.x / 2 - 200, btn_pos.y - 120)
		
		# Put target button above mask
		_toggle_btn.z_index = 100
		
		if not _toggle_btn.pressed.is_connected(_on_tutorial_advanced):
			_toggle_btn.pressed.connect(_on_tutorial_advanced)
			
	elif tutorial_step == 1:
		_toggle_btn.z_index = 0
		bottom_bar.z_index = 100
		tutorial_label.text = "Nâng cấp vật liệu ở đây để tăng mạnh giá bán ổ Bánh mì! (Chạm để tiếp tục)"
		tutorial_arrow.rotation_degrees = 90
		tutorial_arrow.flip_h = false
		tutorial_arrow.flip_v = false
		
		# The bottom bar is animating UP, so we calculate its final open Y value
		var bar_target_y = screen_size.y - _bar_height
		var bar_pos = Vector2(screen_size.x / 2 - 30, bar_target_y - 70)
		
		tutorial_arrow.position = bar_pos
		tutorial_tween.tween_property(tutorial_arrow, "position:y", bar_pos.y + 30, 0.5).set_trans(Tween.TRANS_SINE)
		tutorial_tween.tween_property(tutorial_arrow, "position:y", bar_pos.y, 0.5).set_trans(Tween.TRANS_SINE)
		tutorial_label.position = Vector2(screen_size.x/2 - 200, bar_pos.y - 120)
		
	elif tutorial_step == 2:
		bottom_bar.z_index = 0
		if _bar_open: _slide_bar_down()
		
		var mg_box = get_node("MinigamesBox")
		mg_box.z_index = 100
		tutorial_label.text = "Hết tiền? Tranh thủ chơi vài ván Minigame kiếm lúa nhé! Chúc may mắn! (Chạm kết thúc)"
		
		# Box is on the right. Arrow should point RIGHT at it.
		tutorial_arrow.rotation_degrees = 0
		tutorial_arrow.flip_h = false
		tutorial_arrow.flip_v = false
		
		var mg_pos = mg_box.global_position
		# Place arrow to the LEFT of the minigame box
		var target_x = mg_pos.x - 70
		tutorial_arrow.position = Vector2(target_x - 30, mg_pos.y + 60)
		tutorial_tween.tween_property(tutorial_arrow, "position:x", target_x, 0.5).set_trans(Tween.TRANS_SINE)
		tutorial_tween.tween_property(tutorial_arrow, "position:x", target_x - 30, 0.5).set_trans(Tween.TRANS_SINE)
		tutorial_label.position = Vector2(20, mg_pos.y + 200)
		
	else:
		GameManager.has_played_tutorial = true
		var mg_box = get_node("MinigamesBox")
		mg_box.z_index = 0
		
		tutorial_bg.queue_free()
		tutorial_arrow.queue_free()
		tutorial_label.queue_free()
		tutorial_tween.kill()
		if background_music:
			background_music.play()

func _on_tutorial_advanced() -> void:
	if tutorial_step == 0:
		if _toggle_btn.pressed.is_connected(_on_tutorial_advanced):
			_toggle_btn.pressed.disconnect(_on_tutorial_advanced)
	tutorial_step += 1
	_show_tutorial_step()

func _on_tutorial_input(event: InputEvent) -> void:
	# Only listen to left mouse clicks (which Touch emulation also triggers).
	# Do NOT listen to both Touch and Mouse concurrently or it will double-fire and skip steps.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if tutorial_step == 0:
			# If we clicked INSIDE the button area, let the button handle it
			var btn_rect = _toggle_btn.get_global_rect()
			if btn_rect.has_point(event.global_position):
				_toggle_btn.pressed.emit()
				return
		else:
			tutorial_step += 1
			_show_tutorial_step()

# ─── MINIGAME POPUPS ───────────────────────────────────────
@onready var popup_node: Control = $MinigamePopup
@onready var popup_title: Label = $MinigamePopup/Window/VBox/Title
@onready var btn_win: Button = $MinigamePopup/Window/VBox/HBox/BtnWin
@onready var btn_close: Button = $MinigamePopup/Window/VBox/HBox/BtnClose

@onready var btn_chess: TextureButton = $MinigamesBox/BtnChess
@onready var btn_candy: TextureButton = $MinigamesBox/BtnCandy
@onready var btn_tetris: TextureButton = $MinigamesBox/BtnTetris

func _setup_minigames() -> void:
	if not popup_node: return
	
	popup_node.visible = false
	
	# Preload minigame scenes
	var tetris_menu  = preload("res://scenes/minigames/tetris_level_menu.tscn")
	var candy_menu   = preload("res://scenes/minigames/candy_level_menu.tscn")
	var xiangqi_menu = preload("res://scenes/minigames/xiangqi_level_menu.tscn")
	
	# Connect Open Buttons
	if btn_chess:  btn_chess.pressed.connect(func(): _launch_scene_minigame(xiangqi_menu))
	if btn_candy:  btn_candy.pressed.connect(func(): _launch_scene_minigame(candy_menu))
	if btn_tetris: btn_tetris.pressed.connect(func(): _launch_scene_minigame(tetris_menu))
	
	# Connect Popup Actions (used by chess placeholder only)
	if btn_close: btn_close.pressed.connect(_close_minigame)
	if btn_win: btn_win.pressed.connect(_win_minigame)

func _open_minigame(game_name: String) -> void:
	if popup_node:
		popup_title.text = game_name
		popup_node.visible = true

func _close_minigame() -> void:
	if popup_node:
		popup_node.visible = false

func _win_minigame() -> void:
	GameManager.add_money(500)
	_close_minigame()

func _launch_scene_minigame(scene_resource: PackedScene) -> void:
	if not scene_resource: return
	var instance = scene_resource.instantiate()
	add_child(instance)
	
	if background_music:
		background_music.stream_paused = true
	
	# If the minigame has a closed signal, we can listen to it if needed
	if instance.has_signal("minigame_closed"):
		instance.connect("minigame_closed", func(): 
			if background_music:
				background_music.stream_paused = false
		)

# ─── SETUP FUNCTIONS ──────────────────────────────────────
func _setup_money_label() -> void:
	money_label.text = "💰 0đ"
	money_label.add_theme_font_size_override("font_size", 22)
	money_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
	money_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	money_label.add_theme_constant_override("shadow_offset_x", 2)
	money_label.add_theme_constant_override("shadow_offset_y", 2)

	money_label.anchors_preset = Control.PRESET_TOP_RIGHT
	money_label.offset_left = -200
	money_label.offset_top = 10
	money_label.offset_right = -10
	money_label.offset_bottom = 40
	money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func _setup_time_label() -> void:
	if not time_label: return
	time_label.add_theme_font_size_override("font_size", 24)
	time_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	time_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	time_label.add_theme_constant_override("shadow_offset_x", 2)
	time_label.add_theme_constant_override("shadow_offset_y", 2)

func _update_time_display(hour: int, minute: int) -> void:
	if not time_label: return
	time_label.text = "🕒 %02d:%02d" % [hour, minute]

func _on_time_changed(hour: int, minute: int) -> void:
	_update_time_display(hour, minute)

func _setup_bottom_bar() -> void:
	# Áp dụng style cho PanelBG (fallback nếu texture không load)
	if panel_bg and not panel_bg.has_theme_stylebox_override("panel"):
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.08, 0.10, 0.16, 0.92)
		style.border_color = Color(0.2, 0.5, 0.9, 0.4)
		style.border_width_top = 2
		style.border_width_bottom = 0
		style.border_width_left = 0
		style.border_width_right = 0
		style.corner_radius_top_left = 12
		style.corner_radius_top_right = 12
		panel_bg.add_theme_stylebox_override("panel", style)

	# ScrollContainer chỉ cuộn ngang
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	# Khoảng cách giữa các card
	card_container.add_theme_constant_override("separation", 10)

# ─── POPULATE CARDS ────────────────────────────────────────
func _populate_upgrade_cards() -> void:
	for child in card_container.get_children():
		child.queue_free()

	for upg_data in GameManager.UPGRADES:
		var card := PanelContainer.new()
		card.set_script(UpgradeCardScript)
		card_container.add_child(card)
		card.setup(upg_data)

	print("[UIManager] Đã tạo %d thẻ nâng cấp" % GameManager.UPGRADES.size())

# ─── MONEY DISPLAY ─────────────────────────────────────────
func _on_money_changed(new_amount: int) -> void:
	var delta_money: int = new_amount - last_money
	if delta_money > 0:
		_spawn_money_popup(delta_money)
	last_money = new_amount
	_update_money_display(new_amount)

func _update_money_display(amount: int) -> void:
	money_label.text = "💰 %dđ" % amount

	# Hiệu ứng bounce khi nhận tiền
	var tween := create_tween()
	tween.tween_property(money_label, "scale", Vector2(1.2, 1.2), 0.1)
	tween.tween_property(money_label, "scale", Vector2(1.0, 1.0), 0.15)

## Tạo popup "+Xđ" nổi lên rồi biến mất
func _spawn_money_popup(amount: int) -> void:
	var popup := Label.new()
	popup.text = "+%dđ" % amount
	popup.add_theme_font_size_override("font_size", 18)
	popup.add_theme_color_override("font_color", Color(0.2, 1.0, 0.3))
	popup.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	popup.add_theme_constant_override("shadow_offset_x", 1)
	popup.add_theme_constant_override("shadow_offset_y", 1)
	popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	# Đặt vị trí dưới MoneyLabel
	popup.position = Vector2(money_label.position.x + 50, money_label.position.y + 30)
	add_child(popup)

	# Animation: bay lên + fade out
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(popup, "position:y", popup.position.y - 40, 0.8).set_ease(Tween.EASE_OUT)
	tween.tween_property(popup, "modulate:a", 0.0, 0.8).set_delay(0.3)
	tween.set_parallel(false)
	tween.tween_callback(popup.queue_free)
