## popup_manager.gd — Autoload Popup System
## Bắt signals từ GameManager và hiển thị popup cho:
## - Offline Earnings (mở game sau giờ offline)
## - Streak Bonus (login ngày mới)
## - Mission Completed (hoàn thành nhiệm vụ)
## - Daily Missions Panel (button mở/đóng)
extends CanvasLayer

# ─── SIGNALS KẾT NỐI ─────────────────────────────────────
func _ready() -> void:
	GameManager.offline_earnings_ready.connect(_on_offline_earnings)
	GameManager.streak_bonus_ready.connect(_on_streak_bonus)
	GameManager.mission_completed.connect(_on_mission_completed)
	GameManager.missions_updated.connect(_refresh_missions)
	layer = 10  # Hiển thị trên tất cả UI khác

# ─── POPUP OFFLINE EARNINGS ──────────────────────────────
func _on_offline_earnings(amount: int) -> void:
	_show_popup("💤 Trong lúc offline...", "Bạn đã kiếm được\n+%dđ!" % amount, Color(0.2, 0.6, 1.0))

# ─── POPUP STREAK BONUS ──────────────────────────────────
func _on_streak_bonus(streak: int, reward: int) -> void:
	var title := "🔥 Ngày %d liên tiếp!" % streak
	var body := "+%dđ phần thưởng chuyên cần!" % reward
	_show_popup(title, body, Color(1.0, 0.5, 0.1))

# ─── POPUP MISSION COMPLETED ─────────────────────────────
func _on_mission_completed(mission_id: String) -> void:
	# Tìm mission đã hoàn thành
	for m in GameManager.active_missions:
		if m.id == mission_id:
			_show_popup("✅ Nhiệm vụ hoàn thành!", "%s\n+%dđ" % [m.desc, m.reward], Color(0.2, 0.8, 0.3))
			return

# ─── GENERIC POPUP ───────────────────────────────────────
func _show_popup(title: String, body: String, accent: Color) -> void:
	var panel := _build_popup(title, body, accent)
	add_child(panel)
	# Auto dismiss sau 3s
	var tween := create_tween()
	tween.tween_interval(2.5)
	tween.tween_property(panel, "modulate:a", 0.0, 0.5)
	tween.tween_callback(panel.queue_free)

func _build_popup(title: String, body: String, accent: Color) -> Control:
	# Container căn giữa trên màn hình
	var container := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.1, 0.95)
	style.border_color = accent
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	container.add_theme_stylebox_override("panel", style)
	
	# Vị trí căn giữa trên
	container.set_anchors_preset(Control.PRESET_TOP_WIDE)
	container.offset_top = 80
	container.offset_left = 60
	container.offset_right = -60
	container.offset_bottom = 200
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	
	var title_lbl := Label.new()
	title_lbl.text = title
	title_lbl.add_theme_font_size_override("font_size", 18)
	title_lbl.add_theme_color_override("font_color", accent)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	var body_lbl := Label.new()
	body_lbl.text = body
	body_lbl.add_theme_font_size_override("font_size", 15)
	body_lbl.add_theme_color_override("font_color", Color.WHITE)
	body_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	
	vbox.add_child(title_lbl)
	vbox.add_child(body_lbl)
	container.add_child(vbox)
	
	# Slide in từ trên xuống
	container.modulate.a = 0.0
	container.position.y -= 20
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(container, "modulate:a", 1.0, 0.3)
	tween.tween_property(container, "position:y", container.position.y + 20, 0.3).set_trans(Tween.TRANS_BACK)
	
	return container

# ─── MISSIONS PANEL ──────────────────────────────────────
var _missions_panel: Control = null

func toggle_missions_panel() -> void:
	if _missions_panel and is_instance_valid(_missions_panel):
		_missions_panel.queue_free()
		_missions_panel = null
	else:
		_missions_panel = _build_missions_panel()
		add_child(_missions_panel)

func _refresh_missions() -> void:
	if _missions_panel and is_instance_valid(_missions_panel):
		_missions_panel.queue_free()
		_missions_panel = _build_missions_panel()
		add_child(_missions_panel)

func _build_missions_panel() -> Control:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.95)
	style.border_color = Color(1.0, 0.7, 0.2)
	style.border_width_left = 2; style.border_width_right = 2
	style.border_width_top = 2; style.border_width_bottom = 2
	style.corner_radius_top_left = 10; style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10; style.corner_radius_bottom_right = 10
	panel.add_theme_stylebox_override("panel", style)
	
	# Vị trí: cạnh trái, giữa màn hình
	panel.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	panel.offset_left = 10
	panel.offset_top = -120
	panel.offset_right = 260
	panel.offset_bottom = 120
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	
	var header := Label.new()
	header.text = "📋 Nhiệm vụ hôm nay"
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(header)
	
	for m in GameManager.active_missions:
		var row := HBoxContainer.new()
		
		var check := Label.new()
		check.text = "✅" if m.completed else "🔲"
		check.add_theme_font_size_override("font_size", 14)
		check.custom_minimum_size.x = 28
		
		var desc := Label.new()
		var progress_text := ""
		if m.type != "no_loss":
			progress_text = " (%d/%d)" % [m.get("progress", 0), m.target]
		desc.text = m.desc + progress_text
		desc.add_theme_font_size_override("font_size", 13)
		desc.add_theme_color_override("font_color", Color(0.7, 1.0, 0.7) if m.completed else Color.WHITE)
		desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var reward_lbl := Label.new()
		reward_lbl.text = "+%dđ" % m.reward
		reward_lbl.add_theme_font_size_override("font_size", 13)
		reward_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		
		row.add_child(check)
		row.add_child(desc)
		row.add_child(reward_lbl)
		vbox.add_child(row)
	
	panel.add_child(vbox)
	return panel
