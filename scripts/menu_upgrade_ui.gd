extends Control

@onready var label_rep: Label = $Panel/VBoxContainer/LabelRep
@onready var item_container: VBoxContainer = $Panel/VBoxContainer/ScrollContainer/ItemContainer
@onready var btn_close: Button = $Panel/VBoxContainer/ButtonClose

func _ready() -> void:
	btn_close.pressed.connect(hide)
	
	GameManager.reputation_changed.connect(_on_rep_changed)
	GameManager.menu_unlocked.connect(_on_menu_unlocked)
	
	_populate_list()
	_update_rep_label()

func _on_rep_changed(_new_rep: int) -> void:
	_update_rep_label()

func _on_menu_unlocked(_menu_id: String) -> void:
	_update_rep_label()
	# Refresh UI rows
	_populate_list()

func _update_rep_label() -> void:
	label_rep.text = "⭐ Danh tiếng: %d" % GameManager.reputation

func _populate_list() -> void:
	for child in item_container.get_children():
		child.queue_free()
	
	# Sắp xếp theo thứ tự giá reputation tăng dần (hoặc thứ tự trong Dict)
	var keys = GameManager.MENU_ITEMS.keys()
	keys.sort_custom(func(a, b): return GameManager.MENU_ITEMS[a].rep_cost < GameManager.MENU_ITEMS[b].rep_cost)
	
	var is_even := false
	for m_id in keys:
		var item_data = GameManager.MENU_ITEMS[m_id]
		var is_unlocked = GameManager.unlocked_menu_items.has(m_id)
		
		# Tạo hàng hiển thị
		# Gọi hàm setup raw node
		var row: Control = _create_fallback_row()
		
		item_container.add_child(row)
		
		# Gọi hàm setup trên row
		if row.has_method("setup"):
			row.setup(m_id, item_data.name, item_data.price, item_data.rep_cost, is_unlocked, GameManager.reputation, is_even)
			
		is_even = !is_even

# -- Fallback code trường hợp chưa tạo Menu Item Row --
func _create_fallback_row() -> HBoxContainer:
	var row = HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 50)
	
	var name_lbl = Label.new()
	name_lbl.name = "Name"
	name_lbl.size_flags_horizontal = SIZE_EXPAND_FILL
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(name_lbl)
	
	var price_lbl = Label.new()
	price_lbl.name = "Price"
	price_lbl.custom_minimum_size = Vector2(80, 0)
	price_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(price_lbl)
	
	var buy_btn = Button.new()
	buy_btn.name = "BuyBtn"
	buy_btn.custom_minimum_size = Vector2(100, 40)
	row.add_child(buy_btn)
	
	# Gắn kịch bản inline
	var script = GDScript.new()
	script.source_code = """
extends HBoxContainer
var _id = ""
func setup(m_id: String, m_name: String, price: int, rep_cost: int, is_unlocked: bool, current_rep: int, is_even: bool) -> void:
	_id = m_id
	$Name.text = "  %s" % m_name
	$Price.text = "Giá: %dđ" % price
	
	if is_even:
		var bg = ColorRect.new()
		bg.color = Color(1,1,1, 0.05)
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bg)
		move_child(bg, 0)
	
	var btn = $BuyBtn
	if is_unlocked:
		btn.text = "Đã Mở"
		btn.disabled = true
	else:
		btn.text = "⭐ %d" % rep_cost
		if current_rep >= rep_cost:
			btn.disabled = false
			btn.pressed.connect(func(): GameManager.unlock_menu_item(_id))
		else:
			btn.disabled = true
"""
	script.reload()
	row.set_script(script)
	return row
