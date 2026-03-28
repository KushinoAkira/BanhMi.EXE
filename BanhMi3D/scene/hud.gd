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

# Black Screen UI
var black_overlay: ColorRect
var black_clock_label: Label
var black_quote_label: Label

func _ready():
	add_to_group("HUD")
	item_label.text = ""
	_setup_dynamic_ui()
	_setup_black_screen()

func _process(_delta):
	# Cập nhật thanh tiến trình thời gian mỗi frame
	var dnm = get_node_or_null("/root/DayNightManager")
	if dnm and day_progress_bar:
		day_progress_bar.value = dnm.get_day_progress() * 100.0
		
	# Cập nhật text trạng thái quán
	if day_info_label:
		var global = get_tree().root.get_node_or_null("Global")
		var status = " [MỞ QUÁN]" if global and global.is_shop_open else " [ĐÓNG CỬA]"
		var day_text = "📅 Ngày %d" % (global.day_number if global else 1)
		day_info_label.text = day_text + status
	
	# Cập nhật đồng hồ trên màn hình đen nếu đang active
	if black_overlay and black_overlay.visible and dnm:
		var progress = dnm.get_day_progress()
		var global = get_tree().root.get_node_or_null("Global")
		if global:
			var current_total_hours = global.DAY_START_HOUR + (progress * global.TOTAL_HOURS)
			var hour = int(current_total_hours) % 24
			var minute = int((current_total_hours - int(current_total_hours)) * 60.0)
			black_clock_label.text = "%02d:%02d" % [hour, minute]
			
			# Tự ẩn màn hình đen khi sang ngày mới
			if not global.is_transition_black:
				black_overlay.visible = false

func _setup_dynamic_ui():
	var ui_container = Control.new()
	ui_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui_container)

	# ── Bảng tiền / ngày (Góc trên bên trái) ─────────────
	var info_panel = PanelContainer.new()
	info_panel.position = Vector2(16, 16)
	info_panel.custom_minimum_size = Vector2(280, 0)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.65)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 15
	style.content_margin_right = 15
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	info_panel.add_theme_stylebox_override("panel", style)
	ui_container.add_child(info_panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	info_panel.add_child(vbox)

	# Số ngày
	day_info_label = Label.new()
	day_info_label.add_theme_font_size_override("font_size", 32)
	day_info_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	day_info_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	day_info_label.add_theme_constant_override("outline_size", 4)
	day_info_label.text = "📅 Ngày 1"
	vbox.add_child(day_info_label)

	# Tiền
	money_label = Label.new()
	money_label.add_theme_font_size_override("font_size", 34)
	money_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
	money_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	money_label.add_theme_constant_override("outline_size", 4)
	vbox.add_child(money_label)

	# Thời tiết
	weather_label = Label.new()
	weather_label.add_theme_font_size_override("font_size", 28)
	weather_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	weather_label.add_theme_constant_override("outline_size", 3)
	vbox.add_child(weather_label)

	# ── Thanh tiến trình ngày (Đã xóa theo yêu cầu) ──

	# ── Nút mua đồ ──
	buy_btn = TextureButton.new()
	buy_btn.texture_normal = load("res://assets/buy, bring in out furniture/buy furniture.png")
	buy_btn.ignore_texture_size = true
	buy_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT
	buy_btn.custom_minimum_size = Vector2(250, 150)
	buy_btn.size = Vector2(250, 150)
	buy_btn.position = Vector2(16, 260)
	buy_btn.pressed.connect(_on_buy_pressed)
	buy_btn.focus_mode = Control.FOCUS_NONE
	ui_container.add_child(buy_btn)

	# ── Hướng dẫn Mở/Đóng cửa hàng ──
	var guide_label = Label.new()
	guide_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	guide_label.position = Vector2(20, -180) # Căn tương đối nhưng set bằng top-left position có thể trôi theo resolution nếu ko update, nên dùng anchor + offset
	guide_label.offset_left = 20
	guide_label.offset_top = -180
	guide_label.text = "HƯỚNG DẪN:\n[O] Mở cửa (Từ 5:00 - trước 6:30)\n[C] Đóng cửa (2:30 sáng)\n*Trễ giờ sẽ bị phạt tiền liên tục!*"
	guide_label.add_theme_font_size_override("font_size", 28)
	guide_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	guide_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	guide_label.add_theme_constant_override("outline_size", 4)
	ui_container.add_child(guide_label)

	# ── Kết nối signals ──
	var global = get_tree().root.get_node_or_null("Global")
	if global:
		global.money_changed.connect(_update_money_label)
		global.day_ended.connect(_show_day_summary)
		global.new_day_started.connect(_on_new_day_started)
		global.weather_changed.connect(_update_weather_label)
		_update_money_label(global.money)
		_update_weather_label(global.is_raining)
		_update_day_label(global.day_number)

	_build_summary_panel(ui_container)

func _setup_black_screen():
	black_overlay = ColorRect.new()
	black_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	black_overlay.color = Color(0, 0, 0, 1)
	black_overlay.visible = false
	add_child(black_overlay)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	black_overlay.add_child(center)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 60)
	center.add_child(vbox)

	black_clock_label = Label.new()
	black_clock_label.text = "02:30"
	black_clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	black_clock_label.add_theme_font_size_override("font_size", 120)
	black_clock_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	vbox.add_child(black_clock_label)

	black_quote_label = Label.new()
	black_quote_label.text = "Quote here..."
	black_quote_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	black_quote_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	black_quote_label.custom_minimum_size = Vector2(800, 0)
	black_quote_label.add_theme_font_size_override("font_size", 28)
	black_quote_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(black_quote_label)

func show_black_screen_quote():
	var global = get_tree().root.get_node_or_null("Global")
	if global:
		black_quote_label.text = global.QUOTES[randi() % global.QUOTES.size()]
		black_overlay.modulate.a = 0.0
		black_overlay.visible = true
		var tween = get_tree().create_tween()
		tween.tween_property(black_overlay, "modulate:a", 1.0, 2.0)

func _build_summary_panel(parent: Control):
	summary_panel = Panel.new()
	summary_panel.set_anchors_preset(Control.PRESET_CENTER)
	summary_panel.custom_minimum_size = Vector2(480, 380)
	summary_panel.offset_left = -240
	summary_panel.offset_top = -190
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

	var title = Label.new()
	title.text = "🌙 Tổng kết cuối ngày"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	vbox.add_child(title)

	var stats_labels = [
		["lbl_day",      "📅 Ngày:          -"],
		["lbl_orders",   "🥖 Số đơn đã bán: -"],
		["lbl_base",     "💵 Doanh thu:      -"],
		["lbl_tips",     "💝 Tiền tip:       -"],
		["lbl_total",    "💰 Tổng cộng:      -"],
	]
	for pair in stats_labels:
		var lbl = Label.new()
		lbl.name = pair[0]
		lbl.text = pair[1]
		lbl.add_theme_font_size_override("font_size", 24)
		vbox.add_child(lbl)

func _show_day_summary(stats: Dictionary):
	if not summary_panel: return
	
	_set_summary_label("lbl_day",     "📅 Ngày:          %d" % stats["day_number"])
	_set_summary_label("lbl_orders",  "🥖 Số đơn đã bán: %d" % stats["orders"])
	_set_summary_label("lbl_base",    "💵 Doanh thu:      %s VND" % _fmt(stats["earnings"] - stats["tips"]))
	_set_summary_label("lbl_tips",    "💝 Tiền tip:       %s VND" % _fmt(stats["tips"]))
	_set_summary_label("lbl_total",   "💰 Tổng cộng:      %s VND" % _fmt(stats["earnings"]))

	summary_panel.modulate.a = 0.0
	summary_panel.visible = true
	var tween = get_tree().create_tween()
	tween.tween_property(summary_panel, "modulate:a", 1.0, 0.5)
	
	# Sau 10 giây (NIGHT_DURATION), tự ẩn bảng tổng kết để DayNightManager hiện màn hình đen
	get_tree().create_timer(Global.NIGHT_DURATION).timeout.connect(func():
		var tw = get_tree().create_tween()	
		tw.tween_property(summary_panel, "modulate:a", 0.0, 0.5)
		tw.tween_callback(func(): summary_panel.visible = false)
	)

func _set_summary_label(node_name: String, text: String):
	var lbl = summary_panel.find_child(node_name, true, false) as Label
	if lbl: lbl.text = text

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

func _on_new_day_started(day_num: int):
	_update_day_label(day_num)
	if black_overlay: black_overlay.visible = false

func _on_buy_pressed():
	var global = get_tree().root.get_node_or_null("Global")
	if not global: return
	if global.money >= 55000 and global.furniture_count < 10:
		global.money -= 55000
		global.furniture_count += 1
		global.money_changed.emit(global.money)
		global.furniture_purchased.emit(global.furniture_count)

func set_item_name(new_name: String):
	if item_label:
		item_label.text = new_name

func set_recipe_text(text: String):
	if recipe_label:
		recipe_label.text = text

func set_crosshair_highlight(active: bool):
	if crosshair:
		crosshair.color = Color(1, 1, 0, 1.0) if active else Color(1, 1, 1, 0.8)

func show_notification(text: String, duration: float = 2.5):
	if not notification_label: return
	notification_label.text = text
	notification_label.modulate.a = 1.0
	var tween = get_tree().create_tween()
	tween.tween_property(notification_label, "modulate:a", 0.0, 1.0).set_delay(duration)

func _fmt(amount: int) -> String:
	var s = str(amount)
	var result = ""
	var count = 0
	for i in range(s.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0: result = "," + result
		result = s[i] + result
		count += 1
	return result
