## upgrade_card.gd — Thẻ nâng cấp hiển thị trong Bottom Bar
## Gắn vào PanelContainer tạo bằng code
extends PanelContainer

# ─── VARS ──────────────────────────────────────────────────
var upgrade_data: Dictionary = {}
var upgrade_id: String = ""

# UI Elements (tạo bằng code)
var icon_label: Label
var name_label: Label
var desc_label: Label
var cost_label: Label
var level_label: Label
var buy_button: Button
var purchase_sfx: AudioStreamPlayer

# ─── SETUP ─────────────────────────────────────────────────
func setup(data: Dictionary) -> void:
	upgrade_data = data
	upgrade_id = data.id
	_build_ui()
	_update_display()

	GameManager.money_changed.connect(_on_money_changed)
	GameManager.upgrade_purchased.connect(_on_upgrade_purchased)

	# --- Thêm âm thanh khi mua ---
	purchase_sfx = AudioStreamPlayer.new()
	purchase_sfx.stream = load("res://assets/Music/Purchase_SFX.mp3")
	add_child(purchase_sfx)

func _build_ui() -> void:
	# ── Style cho PanelContainer ──
	custom_minimum_size = Vector2(200, 145)
	mouse_filter = Control.MOUSE_FILTER_PASS

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.14, 0.18, 0.95)
	style.border_color = Color(0.3, 0.5, 0.8, 0.6)
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.content_margin_left = 10
	style.content_margin_right = 10
	add_theme_stylebox_override("panel", style)

	# ── VBoxContainer chứa nội dung ──
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	add_child(vbox)

	# ── Icon + Name (ngang) ──
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	vbox.add_child(header)

	icon_label = Label.new()
	icon_label.text = upgrade_data.get("icon", "❓")
	icon_label.add_theme_font_size_override("font_size", 36)
	header.add_child(icon_label)

	name_label = Label.new()
	name_label.text = upgrade_data.get("name", "???")
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	name_label.custom_minimum_size.x = 100
	header.add_child(name_label)

	# ── Description ──
	desc_label = Label.new()
	desc_label.text = upgrade_data.get("description", "")
	desc_label.add_theme_font_size_override("font_size", 10)
	desc_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(desc_label)

	# ── Level Label ──
	level_label = Label.new()
	level_label.add_theme_font_size_override("font_size", 10)
	level_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
	vbox.add_child(level_label)

	# ── Cost + Buy Button (ngang) ──
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 6)
	vbox.add_child(footer)

	cost_label = Label.new()
	cost_label.add_theme_font_size_override("font_size", 12)
	cost_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	cost_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(cost_label)

	buy_button = Button.new()
	buy_button.text = "MUA"
	buy_button.custom_minimum_size = Vector2(50, 28)
	buy_button.pressed.connect(_on_buy_pressed)

	# Style cho button
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.2, 0.6, 0.3)
	btn_style.corner_radius_top_left = 4
	btn_style.corner_radius_top_right = 4
	btn_style.corner_radius_bottom_left = 4
	btn_style.corner_radius_bottom_right = 4
	buy_button.add_theme_stylebox_override("normal", btn_style)

	var btn_hover := StyleBoxFlat.new()
	btn_hover.bg_color = Color(0.25, 0.7, 0.35)
	btn_hover.corner_radius_top_left = 4
	btn_hover.corner_radius_top_right = 4
	btn_hover.corner_radius_bottom_left = 4
	btn_hover.corner_radius_bottom_right = 4
	buy_button.add_theme_stylebox_override("hover", btn_hover)

	var btn_pressed := StyleBoxFlat.new()
	btn_pressed.bg_color = Color(0.15, 0.5, 0.25)
	btn_pressed.corner_radius_top_left = 4
	btn_pressed.corner_radius_top_right = 4
	btn_pressed.corner_radius_bottom_left = 4
	btn_pressed.corner_radius_bottom_right = 4
	buy_button.add_theme_stylebox_override("pressed", btn_pressed)

	var btn_disabled := StyleBoxFlat.new()
	btn_disabled.bg_color = Color(0.3, 0.3, 0.3, 0.5)
	btn_disabled.corner_radius_top_left = 4
	btn_disabled.corner_radius_top_right = 4
	btn_disabled.corner_radius_bottom_left = 4
	btn_disabled.corner_radius_bottom_right = 4
	buy_button.add_theme_stylebox_override("disabled", btn_disabled)

	footer.add_child(buy_button)

# ─── UPDATE DISPLAY ────────────────────────────────────────
func _update_display() -> void:
	var lvl := GameManager.get_upgrade_level(upgrade_id)
	var cost := GameManager.get_upgrade_cost(upgrade_id)

	level_label.text = "Lv. %d" % lvl
	cost_label.text = "💰 %d" % cost

	# Disable nếu không đủ tiền
	buy_button.disabled = GameManager.money < cost
	if buy_button.disabled:
		buy_button.modulate = Color(0.6, 0.6, 0.6)
	else:
		buy_button.modulate = Color.WHITE

# ─── CALLBACKS ─────────────────────────────────────────────
func _on_buy_pressed() -> void:
	var success := GameManager.buy_upgrade(upgrade_id)
	if success:
		if purchase_sfx:
			purchase_sfx.play()
		_update_display()

func _on_money_changed(_new_amount: int) -> void:
	_update_display()

func _on_upgrade_purchased(_uid: String) -> void:
	if _uid == upgrade_id:
		_update_display()
