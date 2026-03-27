extends CanvasLayer

@onready var item_label = $ItemLabel
@onready var crosshair = $Crosshair
@onready var recipe_label = $RecipeLabel
@onready var notification_label = $NotificationLabel

var notification_timer: SceneTreeTimer = null

var money_label: Label
var buy_btn: TextureButton
var day_btn: TextureButton

func _ready():
	item_label.text = ""
	
	_setup_dynamic_ui()

func _setup_dynamic_ui():
	# UI container to keep it clean
	var ui_container = Control.new()
	add_child(ui_container)
	
	# Money Label
	money_label = Label.new()
	money_label.position = Vector2(20, 20)
	money_label.add_theme_font_size_override("font_size", 24)
	money_label.add_theme_color_override("font_outline_color", Color.BLACK)
	money_label.add_theme_constant_override("outline_size", 4)
	ui_container.add_child(money_label)
	
	# Buy Furniture Button
	buy_btn = TextureButton.new()
	buy_btn.texture_normal = load("res://assets/buy, bring in out furniture/buy furniture.png")
	buy_btn.ignore_texture_size = true
	buy_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT
	buy_btn.custom_minimum_size = Vector2(200, 120)
	buy_btn.size = Vector2(200, 120)
	buy_btn.position = Vector2(10, 90)
	buy_btn.pressed.connect(_on_buy_pressed)
	# Release focus so it doesn't trap player input
	buy_btn.focus_mode = Control.FOCUS_NONE 
	ui_container.add_child(buy_btn)
	
	# Day Toggle Button
	day_btn = TextureButton.new()
	day_btn.ignore_texture_size = true
	day_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT
	day_btn.custom_minimum_size = Vector2(200, 120)
	day_btn.size = Vector2(200, 120)
	day_btn.position = Vector2(10, 220)
	day_btn.pressed.connect(_on_day_toggle_pressed)
	day_btn.focus_mode = Control.FOCUS_NONE
	ui_container.add_child(day_btn)
	
	if Engine.has_singleton("Global"):
		var glb = Engine.get_singleton("Global")
		pass # Note: AutoLoads are added to Tree, they are accessible globally by name 'Global', not strictly via get_singleton unless registered as such.
	
	# Connect signals from Global script
	var root = get_tree().root
	var global = root.get_node_or_null("Global")
	if global:
		global.money_changed.connect(_update_money_label)
		global.day_changed.connect(_on_day_changed)
		global.furniture_purchased.connect(func(c): _update_money_label(global.money))
		_update_money_label(global.money)
		_on_day_changed(global.is_day)

func _update_money_label(val):
	var global = get_tree().root.get_node_or_null("Global")
	var count = global.furniture_count if global else 1
	money_label.text = "Tiền: " + str(val) + " VND\nSố bàn ghế đang có: " + str(count)

func _on_day_changed(is_day_now):
	if is_day_now:
		day_btn.texture_normal = load("res://assets/buy, bring in out furniture/furniture bring in.png")
	else:
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

func show_notification(text: String, duration: float = 1.5):
	if not notification_label: return
	
	if original_notification_pos == Vector2.ZERO:
		original_notification_pos = notification_label.position
	
	notification_label.text = text
	notification_label.modulate.a = 1.0
	notification_label.scale = Vector2(1.0, 1.0)
	notification_label.position = original_notification_pos
	notification_label.pivot_offset = Vector2(300, 50) # Tâm của label (600x100)
	notification_label.add_theme_font_size_override("font_size", 24)
	
	# Tạo hiệu ứng chìm xuống và mờ dần
	var tween = get_tree().create_tween()
	tween.set_parallel(true)
	# Đợi một chút rồi bắt đầu hiệu ứng biến mất
	tween.tween_property(notification_label, "position:y", original_notification_pos.y + 30.0, 1.0).set_delay(duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(notification_label, "scale", Vector2.ZERO, 1.0).set_delay(duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(notification_label, "modulate:a", 0.0, 1.0).set_delay(duration)
