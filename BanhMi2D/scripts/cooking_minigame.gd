extends CanvasLayer

signal minigame_completed(won: bool)

var required_sequence: Array[String] = []
var current_step: int = 0
var time_left: float = 6.0

var keys_display: HBoxContainer
var timer_bar: ProgressBar
var lbl_title: Label

const KEY_ICONS = {
	"ui_left": "⬅️",
	"ui_right": "➡️",
	"ui_up": "⬆️",
	"ui_down": "⬇️"
}

func _ready() -> void:
	layer = 100 # On top of everything
	
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	var center_container = CenterContainer.new()
	center_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center_container)
	
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(320, 200) # Nhỏ hơn để vừa màn hình điện thoại
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.15, 0.25, 0.95)
	style.border_color = Color(1.0, 0.8, 0.2, 1.0)
	style.set_border_width_all(4)
	style.set_corner_radius_all(16)
	panel.add_theme_stylebox_override("panel", style)
	center_container.add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)
	
	lbl_title = Label.new()
	lbl_title.text = "CHẾ BIẾN ĐẶC BIỆT!\nBấm phím theo thứ tự để hoàn thành"
	lbl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_title.add_theme_font_size_override("font_size", 16) # Font nhỏ hơn cho Mobile
	lbl_title.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
	vbox.add_child(lbl_title)
	
	vbox.add_spacer(false)
	
	keys_display = HBoxContainer.new()
	keys_display.alignment = BoxContainer.ALIGNMENT_CENTER
	keys_display.add_theme_constant_override("separation", 10) # Khoảng cách phím hẹp hơn
	vbox.add_child(keys_display)
	
	vbox.add_spacer(false)
	
	timer_bar = ProgressBar.new()
	timer_bar.custom_minimum_size = Vector2(280, 15) # Thanh Timer vừa màn hình Mobile
	timer_bar.max_value = time_left
	timer_bar.value = time_left
	timer_bar.show_percentage = false
	
	var style_bg = StyleBoxFlat.new()
	style_bg.bg_color = Color(0.2, 0.2, 0.2)
	style_bg.set_corner_radius_all(10)
	timer_bar.add_theme_stylebox_override("background", style_bg)
	
	var style_fg = StyleBoxFlat.new()
	style_fg.bg_color = Color(1.0, 0.4, 0.0)
	style_fg.set_corner_radius_all(10)
	timer_bar.add_theme_stylebox_override("fill", style_fg)
	
	vbox.add_child(timer_bar)
	vbox.add_spacer(false)
	
	var btn_grid = GridContainer.new()
	btn_grid.columns = 3
	btn_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn_grid.add_theme_constant_override("h_separation", 10)
	btn_grid.add_theme_constant_override("v_separation", 10)
	vbox.add_child(btn_grid)
	
	# Empty slot (top left)
	btn_grid.add_child(Control.new())
	
	var btn_up = _create_mobile_btn("ui_up")
	btn_grid.add_child(btn_up)
	
	# Empty slot (top right)
	btn_grid.add_child(Control.new())
	
	var btn_left = _create_mobile_btn("ui_left")
	btn_grid.add_child(btn_left)
	
	var btn_down = _create_mobile_btn("ui_down")
	btn_grid.add_child(btn_down)
	
	var btn_right = _create_mobile_btn("ui_right")
	btn_grid.add_child(btn_right)
	
	_generate_sequence(6) # 6 keys
	
func _create_mobile_btn(action: String) -> Button:
	var btn = Button.new()
	btn.text = KEY_ICONS[action]
	btn.add_theme_font_size_override("font_size", 24)
	btn.custom_minimum_size = Vector2(60, 60)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.3, 0.9)
	style.set_corner_radius_all(8)
	style.set_border_width_all(2)
	style.border_color = Color(0.5, 0.5, 0.6)
	btn.add_theme_stylebox_override("normal", style)
	
	var style_pressed = style.duplicate()
	style_pressed.bg_color = Color(0.4, 0.4, 0.5, 0.9)
	btn.add_theme_stylebox_override("pressed", style_pressed)
	
	btn.pressed.connect(func(): _handle_input(action))
	return btn

func parent_center(ctrl: Control) -> void:
	ctrl.set_anchors_and_offsets_preset(Control.PRESET_CENTER)

func _generate_sequence(length: int) -> void:
	var possible = ["ui_left", "ui_right", "ui_up", "ui_down"]
	required_sequence.clear()
	for child in keys_display.get_children():
		child.queue_free()
		
	for i in range(length):
		var k = possible.pick_random()
		required_sequence.append(k)
		
		var lbl = Label.new()
		lbl.text = KEY_ICONS[k]
		lbl.add_theme_font_size_override("font_size", 36)
		
		var l_style = StyleBoxFlat.new()
		l_style.bg_color = Color(0, 0, 0, 0.5)
		l_style.set_border_width_all(2)
		l_style.border_color = Color(0.5, 0.5, 0.5)
		l_style.set_corner_radius_all(8)
		l_style.content_margin_left = 6
		l_style.content_margin_right = 6
		l_style.content_margin_top = 4
		l_style.content_margin_bottom = 4
		lbl.add_theme_stylebox_override("normal", l_style)
		
		keys_display.add_child(lbl)

func _process(delta: float) -> void:
	time_left -= delta
	timer_bar.value = time_left
	
	# Change color as time runs out
	if time_left < 2.0:
		var style: StyleBoxFlat = timer_bar.get_theme_stylebox("fill")
		style.bg_color = Color.RED
	
	if time_left <= 0:
		_finish_game(false)

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed: return
	
	if event.is_action_pressed("ui_left"): _handle_input("ui_left")
	elif event.is_action_pressed("ui_right"): _handle_input("ui_right")
	elif event.is_action_pressed("ui_up"): _handle_input("ui_up")
	elif event.is_action_pressed("ui_down"): _handle_input("ui_down")

func _handle_input(action: String) -> void:
	if current_step >= required_sequence.size(): return
	
	var expected_action = required_sequence[current_step]
	
	if action == expected_action:
		# Correct key!
		var lbl: Label = keys_display.get_child(current_step)
		var style: StyleBoxFlat = lbl.get_theme_stylebox("normal")
		style.bg_color = Color(0.2, 0.8, 0.2, 0.8) # Green
		style.border_color = Color(0, 1, 0)
		
		current_step += 1
		
		if current_step >= required_sequence.size():
			_finish_game(true)
	else:
		# Wrong key!
		if current_step < keys_display.get_child_count():
			var lbl: Label = keys_display.get_child(current_step)
			var style: StyleBoxFlat = lbl.get_theme_stylebox("normal")
			style.bg_color = Color(0.8, 0.2, 0.2, 0.8) # Red
			style.border_color = Color(1, 0, 0)
			
		_finish_game(false)

func _finish_game(won: bool) -> void:
	set_process(false)
	set_process_input(false)
	
	if won:
		lbl_title.text = "HOÀN THÀNH!"
		lbl_title.add_theme_color_override("font_color", Color.GREEN)
	else:
		lbl_title.text = "THẤT BẠI!"
		lbl_title.add_theme_color_override("font_color", Color.RED)
		
	# Wait a bit then emit and destroy
	await get_tree().create_timer(0.5).timeout
	minigame_completed.emit(won)
	queue_free()
