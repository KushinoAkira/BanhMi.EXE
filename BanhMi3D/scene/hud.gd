extends CanvasLayer

@onready var item_label = $ItemLabel
@onready var crosshair = $Crosshair
@onready var recipe_label = $RecipeLabel
@onready var notification_label = $NotificationLabel

var notification_timer: SceneTreeTimer = null

# Dynamic UI nodes
var money_label: Label
var buy_btn: TextureButton
var day_btn: TextureButton
var day_progress_bar: ProgressBar
var day_info_label: Label
var weather_label: Label
var summary_panel: Panel

func _ready():
	item_label.text = ""
	_setup_dynamic_ui()

func _process(_delta):
	# Cập nhật thanh tiến trình thời gian mỗi frame
	var dnm = get_node_or_null("/root/DayNightManager")
	if dnm and day_progress_bar:
		day_progress_bar.value = dnm.get_day_progress() * 100.0

func _setup_dynamic_ui():
	var ui_container = Control.new()
	ui_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui_container)

	# ── Bảng tiền / ngày ──────────────────────────────
	var info_panel = PanelContainer.new()
	info_panel.position = Vector2(12, 12)
	info_panel.custom_minimum_size = Vector2(220, 0)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.55)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	info_panel.add_theme_stylebox_override("panel", style)
	ui_container.add_child(info_panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	info_panel.add_child(vbox)

	# Số ngày
	day_info_label = Label.new()
	day_info_label.add_theme_font_size_override("font_size", 26)
	day_info_label.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	day_info_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	day_info_label.add_theme_constant_override("outline_size", 3)
	day_info_label.text = "📅 Ngày 1"
	vbox.add_child(day_info_label)

	# Tiền
	money_label = Label.new()
	money_label.add_theme_font_size_override("font_size", 28)
	money_label.add_theme_color_override("font_color", Color(0.3, 1, 0.4))
	money_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	money_label.add_theme_constant_override("outline_size", 3)
	vbox.add_child(money_label)

	# Thời tiết
	weather_label = Label.new()
	weather_label.add_theme_font_size_override("font_size", 22)
	weather_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	weather_label.add_theme_constant_override("outline_size", 2)
	vbox.add_child(weather_label)

	# ── Thanh tiến trình ngày ──────────────────────────
	var progress_container = VBoxContainer.new()
	progress_container.position = Vector2(12, 130)
	progress_container.custom_minimum_size = Vector2(220, 0)
	ui_container.add_child(progress_container)

	var progress_label = Label.new()
	progress_label.text = "⏳ Thời gian trong ngày"
	progress_label.add_theme_font_size_override("font_size", 17)
	progress_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	progress_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	progress_label.add_theme_constant_override("outline_size", 2)
	progress_container.add_child(progress_label)

	day_progress_bar = ProgressBar.new()
	day_progress_bar.min_value = 0
	day_progress_bar.max_value = 100
	day_progress_bar.value = 0
	day_progress_bar.custom_minimum_size = Vector2(220, 14)
	day_progress_bar.show_percentage = false
	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = Color(1.0, 0.75, 0.2)
	fill_style.corner_radius_top_left = 6
	fill_style.corner_radius_top_right = 6
	fill_style.corner_radius_bottom_left = 6
	fill_style.corner_radius_bottom_right = 6
	day_progress_bar.add_theme_stylebox_override("fill", fill_style)
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0, 0, 0, 0.5)
	bg_style.corner_radius_top_left = 6
	bg_style.corner_radius_top_right = 6
	bg_style.corner_radius_bottom_left = 6
	bg_style.corner_radius_bottom_right = 6
	day_progress_bar.add_theme_stylebox_override("background", bg_style)
	progress_container.add_child(day_progress_bar)

	# ── Nút mua đồ + ngày đêm ────────────────────────
	buy_btn = TextureButton.new()
	buy_btn.texture_normal = load("res://assets/buy, bring in out furniture/buy furniture.png")
	buy_btn.ignore_texture_size = true
	buy_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT
	buy_btn.custom_minimum_size = Vector2(200, 120)
	buy_btn.size = Vector2(200, 120)
	buy_btn.position = Vector2(10, 160)
	buy_btn.pressed.connect(_on_buy_pressed)
	buy_btn.focus_mode = Control.FOCUS_NONE
	ui_container.add_child(buy_btn)

	day_btn = TextureButton.new()
	day_btn.ignore_texture_size = true
	day_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT
	day_btn.custom_minimum_size = Vector2(200, 120)
	day_btn.size = Vector2(200, 120)
	day_btn.position = Vector2(10, 290)
	day_btn.pressed.connect(_on_day_toggle_pressed)
	day_btn.focus_mode = Control.FOCUS_NONE
	ui_container.add_child(day_btn)

	# ── Kết nối signals ───────────────────────────────
	var global = get_tree().root.get_node_or_null("Global")
	if global:
		global.money_changed.connect(_update_money_label)
		global.day_changed.connect(_on_day_changed)
		global.furniture_purchased.connect(func(c): _update_money_label(global.money))
		global.day_ended.connect(_show_day_summary)
		global.new_day_started.connect(_on_new_day_started)
		global.weather_changed.connect(_update_weather_label)
		_update_money_label(global.money)
		_on_day_changed(global.is_day)
		_update_weather_label(global.is_raining)
		_update_day_label(global.day_number)

	# ── Bảng tổng kết cuối ngày ───────────────────────
	_build_summary_panel(ui_container)

func _build_summary_panel(parent: Control):
	summary_panel = Panel.new()
	summary_panel.set_anchors_preset(Control.PRESET_CENTER)
	summary_panel.custom_minimum_size = Vector2(480, 380)
	summary_panel.offset_left = -240
	summary_panel.offset_top = -190
	summary_panel.offset_right = 240
	summary_panel.offset_bottom = 190
	summary_panel.visible = false

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.07, 0.07, 0.12, 0.97)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(1.0, 0.75, 0.2, 0.9)
	panel_style.corner_radius_top_left = 16
	panel_style.corner_radius_top_right = 16
	panel_style.corner_radius_bottom_left = 16
	panel_style.corner_radius_bottom_right = 16
	summary_panel.add_theme_stylebox_override("panel", panel_style)
	parent.add_child(summary_panel)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 30
	vbox.offset_right = -30
	vbox.offset_top = 20
	vbox.offset_bottom = -20
	vbox.add_theme_constant_override("separation", 14)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	summary_panel.add_child(vbox)

	# Tiêu đề
	var title = Label.new()
	title.text = "🌙 Tổng kết cuối ngày"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	vbox.add_child(title)

	var sep = HSeparator.new()
	sep.add_theme_color_override("color", Color(1, 0.75, 0.2, 0.4))
	vbox.add_child(sep)

	# Các dòng thống kê — dùng tên node để tìm lại sau
	var stats_labels = [
		["lbl_day",      "📅 Ngày:          -"],
		["lbl_orders",   "🥖 Số đơn đã bán: -"],
		["lbl_base",     "💵 Doanh thu:      -"],
		["lbl_tips",     "💝 Tiền tip:       -"],
		["lbl_total",    "💰 Tổng cộng:      -"],
		["lbl_weather",  "🌤️ Thời tiết:      -"],
	]
	for pair in stats_labels:
		var lbl = Label.new()
		lbl.name = pair[0]
		lbl.text = pair[1]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		lbl.add_theme_font_size_override("font_size", 24)
		lbl.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
		lbl.add_theme_color_override("font_outline_color", Color(0,0,0))
		lbl.add_theme_constant_override("outline_size", 2)
		vbox.add_child(lbl)

	var sep2 = HSeparator.new()
	sep2.add_theme_color_override("color", Color(1, 0.75, 0.2, 0.4))
	vbox.add_child(sep2)

	# Nút bắt đầu ngày mới
	var new_day_btn = Button.new()
	new_day_btn.text = "☀️  Bắt đầu ngày mới!"
	new_day_btn.custom_minimum_size = Vector2(280, 50)
	new_day_btn.add_theme_font_size_override("font_size", 26)
	new_day_btn.focus_mode = Control.FOCUS_NONE
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.95, 0.65, 0.1)
	btn_style.corner_radius_top_left = 10
	btn_style.corner_radius_top_right = 10
	btn_style.corner_radius_bottom_left = 10
	btn_style.corner_radius_bottom_right = 10
	btn_style.content_margin_left = 20
	btn_style.content_margin_right = 20
	new_day_btn.add_theme_stylebox_override("normal", btn_style)
	var btn_hover = btn_style.duplicate() as StyleBoxFlat
	btn_hover.bg_color = Color(1.0, 0.75, 0.2)
	new_day_btn.add_theme_stylebox_override("hover", btn_hover)
	new_day_btn.add_theme_color_override("font_color", Color(0.1, 0.05, 0))
	new_day_btn.pressed.connect(_on_new_day_pressed)

	var btn_center = CenterContainer.new()
	btn_center.add_child(new_day_btn)
	vbox.add_child(btn_center)

func _show_day_summary(stats: Dictionary):
	if not summary_panel:
		return
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# Điền số liệu
	var earnings_no_tip = stats["earnings"] - stats["tips"]
	
	_set_summary_label("lbl_day",     "📅 Ngày:          %d" % stats["day_number"])
	_set_summary_label("lbl_orders",  "🥖 Số đơn đã bán: %d" % stats["orders"])
	_set_summary_label("lbl_base",    "💵 Doanh thu:      %s VND" % _fmt(earnings_no_tip))
	_set_summary_label("lbl_tips",    "💝 Tiền tip:       %s VND" % _fmt(stats["tips"]))
	_set_summary_label("lbl_total",   "💰 Tổng cộng:      %s VND" % _fmt(stats["earnings"]))
	var wx = "🌧️ Có mưa" if stats.get("is_raining", false) else "☀️ Nắng đẹp"
	_set_summary_label("lbl_weather", "🌤️ Thời tiết:      " + wx)

	# Animate panel hiện ra
	summary_panel.modulate.a = 0.0
	summary_panel.visible = true
	var tween = get_tree().create_tween()
	tween.tween_property(summary_panel, "modulate:a", 1.0, 0.5)

func _set_summary_label(node_name: String, text: String):
	var lbl = summary_panel.find_child(node_name, true, false) as Label
	if lbl:
		lbl.text = text

func _on_new_day_pressed():
	if summary_panel:
		var tween = get_tree().create_tween()
		tween.tween_property(summary_panel, "modulate:a", 0.0, 0.3)
		tween.tween_callback(func(): summary_panel.visible = false)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	Global.start_new_day()

func _update_money_label(val):
	var global = get_tree().root.get_node_or_null("Global")
	var count = global.furniture_count if global else 1
	if money_label:
		money_label.text = "💰 %s VND\n🪑 Bàn ghế: %d" % [_fmt(val), count]

func _update_day_label(day_num: int):
	if day_info_label:
		day_info_label.text = "📅 Ngày %d" % day_num

func _update_weather_label(raining: bool):
	if weather_label:
		weather_label.text = "🌧️ Hôm nay có mưa" if raining else "☀️ Hôm nay nắng đẹp"
		weather_label.add_theme_color_override("font_color",
			Color(0.5, 0.8, 1.0) if raining else Color(1.0, 0.95, 0.5))

func _on_new_day_started(day_num: int):
	_update_day_label(day_num)
	var global = get_tree().root.get_node_or_null("Global")
	if global:
		_update_weather_label(global.is_raining)
		_update_money_label(global.money)

func _on_day_changed(is_day_now):
	if is_day_now:
		if day_btn:
			day_btn.texture_normal = load("res://assets/buy, bring in out furniture/furniture bring in.png")
	else:
		if day_btn:
			day_btn.texture_normal = load("res://assets/buy, bring in out furniture/furniture bring out.png")

func _on_buy_pressed():
	var global = get_tree().root.get_node_or_null("Global")
	if not global: return
	if global.money >= 55000 and global.furniture_count < 10:
		global.money -= 55000
		global.furniture_count += 1
		global.money_changed.emit(global.money)
		global.furniture_purchased.emit(global.furniture_count)

func _on_day_toggle_pressed():
	var global = get_tree().root.get_node_or_null("Global")
	if not global: return
	global.is_day = !global.is_day
	global.day_changed.emit(global.is_day)

func set_item_name(new_name: String):
	item_label.text = new_name

func set_recipe_text(text: String):
	if recipe_label:
		recipe_label.text = text

func set_crosshair_highlight(active: bool):
	if active:
		crosshair.color = Color(1, 1, 0, 1.0)
	else:
		crosshair.color = Color(1, 1, 1, 0.8)

var original_notification_pos: Vector2 = Vector2.ZERO

func show_notification(text: String, duration: float = 2.5):
	if not notification_label: return
	
	if original_notification_pos == Vector2.ZERO:
		original_notification_pos = notification_label.position
	
	notification_label.text = text
	notification_label.modulate.a = 1.0
	notification_label.scale = Vector2(1.0, 1.0)
	notification_label.position = original_notification_pos
	notification_label.pivot_offset = Vector2(300, 50) # Tâm của label (600x100)
	notification_label.add_theme_font_size_override("font_size", 24)
	
	# Hiển thị rõ trong duration giây, sau đó biến mất trong 1 giây
	var tween = get_tree().create_tween()
	tween.set_parallel(true)
	# Đợi một chút rồi bắt đầu hiệu ứng biến mất
	tween.tween_property(notification_label, "position:y", original_notification_pos.y + 30.0, 1.0).set_delay(duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(notification_label, "scale", Vector2.ZERO, 1.0).set_delay(duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(notification_label, "modulate:a", 0.0, 1.0).set_delay(duration)

func _fmt(amount: int) -> String:
	var s = str(amount)
	var result = ""
	var count = 0
	for i in range(s.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "," + result
		result = s[i] + result
		count += 1
	return result
