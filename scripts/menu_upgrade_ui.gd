## menu_upgrade_ui.gd — UI Mở khóa Thực đơn
## Hiển thị danh sách món ăn + đồ uống, nhóm theo category
extends Control

@onready var label_rep: Label = $Panel/VBoxContainer/LabelRep
@onready var item_container: VBoxContainer = $Panel/VBoxContainer/ScrollContainer/ItemContainer
@onready var btn_close: Button = $Panel/VBoxContainer/ButtonClose

func _ready() -> void:
	btn_close.pressed.connect(hide)
	
	GameManager.reputation_changed.connect(_on_rep_changed)
	GameManager.money_changed.connect(_on_money_changed)
	GameManager.menu_unlocked.connect(_on_menu_unlocked)
	
	_populate_list()
	_update_header()

func _on_rep_changed(_new_rep: int) -> void:
	_update_header()

func _on_money_changed(_new_money: int) -> void:
	_update_header()

func _on_menu_unlocked(_menu_id: String) -> void:
	_update_header()
	_populate_list()

func _update_header() -> void:
	label_rep.text = "⭐ Danh tiếng: %d  |  💰 %dđ" % [GameManager.reputation, GameManager.money]

# ─── POPULATE LIST ─────────────────────────────────────────
func _populate_list() -> void:
	for child in item_container.get_children():
		child.queue_free()
	
	# Sắp xếp theo unlock_level tăng dần
	var keys = GameManager.MENU_ITEMS.keys()
	keys.sort_custom(func(a, b):
		return GameManager.MENU_ITEMS[a].unlock_level < GameManager.MENU_ITEMS[b].unlock_level
	)
	
	# Nhóm theo category
	var food_items: Array = []
	var drink_items: Array = []
	for m_id in keys:
		var item_data = GameManager.MENU_ITEMS[m_id]
		if item_data.category == "drink":
			drink_items.append(m_id)
		else:
			food_items.append(m_id)
	
	# Thêm header "BÁNH MÌ"
	_add_category_header("🥖 BÁNH MÌ")
	var is_even := false
	for m_id in food_items:
		_add_item_row(m_id, is_even)
		is_even = !is_even
	
	# Thêm header "ĐỒ UỐNG"
	_add_category_header("🧃 ĐỒ UỐNG")
	is_even = false
	for m_id in drink_items:
		_add_item_row(m_id, is_even)
		is_even = !is_even

func _add_category_header(title_text: String) -> void:
	var header = Label.new()
	header.text = title_text
	header.add_theme_font_size_override("font_size", 22)
	header.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.custom_minimum_size = Vector2(0, 40)
	header.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	item_container.add_child(header)

func _add_item_row(m_id: String, is_even: bool) -> void:
	var item_data = GameManager.MENU_ITEMS[m_id]
	var is_unlocked = GameManager.unlocked_menu_items.has(m_id)
	
	var row: Control = _create_item_row()
	item_container.add_child(row)
	
	if row.has_method("setup"):
		row.setup(m_id, item_data, is_unlocked, GameManager.reputation, GameManager.money, is_even)

# ─── ITEM ROW (Script động) ────────────────────────────────
func _create_item_row() -> HBoxContainer:
	var row = HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 60)
	
	# Cột thông tin (tên + chi tiết)
	var info_vbox = VBoxContainer.new()
	info_vbox.name = "Info"
	info_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(info_vbox)
	
	var name_lbl = Label.new()
	name_lbl.name = "Name"
	name_lbl.add_theme_font_size_override("font_size", 16)
	info_vbox.add_child(name_lbl)
	
	var detail_lbl = Label.new()
	detail_lbl.name = "Detail"
	detail_lbl.add_theme_font_size_override("font_size", 12)
	detail_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	info_vbox.add_child(detail_lbl)
	
	# Nút mua
	var buy_btn = Button.new()
	buy_btn.name = "BuyBtn"
	buy_btn.custom_minimum_size = Vector2(110, 45)
	row.add_child(buy_btn)
	
	# Gắn kịch bản inline cho row
	var script = GDScript.new()
	script.source_code = """
extends HBoxContainer
var _id = ""
func setup(m_id: String, data: Dictionary, is_unlocked: bool, current_rep: int, current_money: int, is_even: bool) -> void:
	_id = m_id
	
	# Tên món
	var emoji = "🍞" if data.category == "food" else "🥤"
	$Info/Name.text = "  %s %s" % [emoji, data.name]
	
	# Chi tiết: Giá bán + Thời gian chế biến
	if data.category == "food":
		$Info/Detail.text = "    Giá: %dđ  |  ⏱ %.1fs  |  Lv.%d" % [data.price, data.prep_time, data.unlock_level]
	else:
		# Đồ uống hiển thị bonus giảm thời gian
		$Info/Detail.text = "    Giá: %dđ  |  ⏱ %.1fs bonus  |  Lv.%d" % [data.price, data.prep_time, data.unlock_level]
	
	# Nền xen kẽ
	if is_even:
		var bg = ColorRect.new()
		bg.color = Color(1, 1, 1, 0.05)
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bg)
		move_child(bg, 0)
	
	var btn = $BuyBtn
	if is_unlocked:
		btn.text = "✅ Đã Mở"
		btn.disabled = true
	else:
		# Hiển thị chi phí mở khóa
		var cost_text = ""
		if data.rep_cost > 0:
			cost_text += "⭐%d" % data.rep_cost
		if data.money_cost > 0:
			if cost_text != "":
				cost_text += " "
			cost_text += "💰%d" % data.money_cost
		btn.text = cost_text
		
		if current_rep >= data.rep_cost and current_money >= data.money_cost:
			btn.disabled = false
			btn.pressed.connect(func(): GameManager.unlock_menu_item(_id))
		else:
			btn.disabled = true
"""
	script.reload()
	row.set_script(script)
	return row
