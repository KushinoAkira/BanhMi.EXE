extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5
const MOUSE_SENSITIVITY = 0.002

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var head = $Head
@onready var camera = $Head/Camera3D
@onready var interaction_ray = $Head/Camera3D/RayCast3D
@onready var hand = $Head/Camera3D/Hand

var hud: CanvasLayer
var last_highlighted_target = null
var manager: Node
var cart_manager: Node

var held_item_name: String = ""
var held_item_node: Node3D = null
var current_order_customer: String = "" # Tên khách mà chiếc bánh này thuộc về
var _step_timer: float = 0.0
var _rng := RandomNumberGenerator.new()

var _sfx_banhmi_pick := [
	"res://assets/Sounds/sfx/banhmi_pick_01.wav",
	"res://assets/Sounds/sfx/banhmi_pick_02.wav"
]

var _sfx_ingredient_generic := [
	"res://assets/Sounds/sfx/ingredient_generic_01.wav",
	"res://assets/Sounds/sfx/ingredient_generic_02.wav"
]

var _sfx_ingredient_veg := ["res://assets/Sounds/sfx/ingredient_veg_01.wav"]
var _sfx_ingredient_meat := ["res://assets/Sounds/sfx/ingredient_meat_01.wav"]
var _sfx_ingredient_sauce := ["res://assets/Sounds/sfx/ingredient_sauce_01.wav"]

var _sfx_walk := [
	"res://assets/Sounds/sfx/walk_step_01.wav",
	"res://assets/Sounds/sfx/walk_step_02.wav",
	"res://assets/Sounds/sfx/walk_step_03.wav"
]

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_rng.randomize()
	hud = get_node_or_null("/root/Main/HUD")
	manager = get_node_or_null("/root/Main/BanhMiManager")
	cart_manager = get_tree().get_first_node_in_group("CartManager")
	interaction_ray.collision_mask = 2 # Chỉ nhìn Layer 2
	
	if hud and manager:
		hud.set_recipe_text(manager.get_recipe_info())

func _input(event):
	# 1. Bắt chuột khi nhấn vào màn hình
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
				if not Global.is_night_summary:
					Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
					get_viewport().set_input_as_handled()

	# 2. Xử lý xoay chuột
	if event is InputEventMouseMotion:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
			camera.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
			camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-89), deg_to_rad(89))
			get_viewport().set_input_as_handled()

func _unhandled_input(event):
	# ESC — toggle chuột
	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# Alt — giữ để hiện chuột
	if event is InputEventKey and event.keycode == KEY_ALT:
		if event.pressed and not event.echo:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		elif not event.pressed:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta):
	# Dừng di chuyển và tương tác nếu đang hiện bảng tổng kết hoặc màn hình đen
	if Global.is_night_summary or Global.is_transition_black:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
		move_and_slide()
		return

	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input_dir := Vector2(
		float(Input.is_key_pressed(KEY_D) or Input.is_action_pressed("ui_right")) -
		float(Input.is_key_pressed(KEY_A) or Input.is_action_pressed("ui_left")),
		float(Input.is_key_pressed(KEY_S) or Input.is_action_pressed("ui_down")) -
		float(Input.is_key_pressed(KEY_W) or Input.is_action_pressed("ui_up"))
	).limit_length(1.0)
	
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
		if is_on_floor():
			_step_timer -= delta
			if _step_timer <= 0.0:
				_play_sfx_pool(_sfx_walk, -18.0, 0.96, 1.04)
				_step_timer = 0.34
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
		_step_timer = 0.0

	move_and_slide()
	process_interaction()

func process_interaction():
	var current_target = null
	if interaction_ray.is_colliding():
		var collider = interaction_ray.get_collider()
		if collider.has_method("set_highlight"):
			current_target = collider

	if current_target != last_highlighted_target:
		if last_highlighted_target:
			last_highlighted_target.set_highlight(false)
			if hud:
				hud.set_item_name("")
				hud.set_crosshair_highlight(false)
		
		if current_target:
			current_target.set_highlight(true)
			if hud:
				hud.set_item_name(current_target.item_name)
				hud.set_crosshair_highlight(true)
		
		last_highlighted_target = current_target

	if current_target and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if not Engine.get_main_loop().has_meta("mouse_clicked"):
			handle_interaction(current_target)
			Engine.get_main_loop().set_meta("mouse_clicked", true)
	elif not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if Engine.get_main_loop().has_meta("mouse_clicked"):
			Engine.get_main_loop().remove_meta("mouse_clicked")

func handle_interaction(target):
	var item_name = target.item_name
	var interaction_point = interaction_ray.get_collision_point()
	
	# Kiểm tra nếu là Khách hàng
	var is_customer = false
	if cart_manager and cart_manager.has_method("is_customer_name"):
		is_customer = cart_manager.is_customer_name(item_name)
	else:
		is_customer = manager != null and (item_name in ["Khoa", "Hiếu", "Hoàng", "Phương", "Huyền", "Nam", "Lan", "Tuấn", "Linh", "Đức", "Khách hàng 1", "Khách hàng 2", "Khách hàng 3"])
	
	# 1. Lấy bánh mì
	if item_name == "Bánh mì" and held_item_name == "":
		if not Global.is_shop_open:
			if hud: hud.show_notification("Hãy bấm phím O để mở quán trước khi nhận đơn!")
			return
		if manager and manager.current_working_customer != "":
			pick_up_item("res://assets/banh_mi_items/banh_mi.glb", "Bánh mì đang làm")
			_play_sfx_pool(_sfx_banhmi_pick, -9.0, 0.97, 1.03)
			current_order_customer = manager.current_working_customer
			show_floating_text(interaction_point, "Đang làm bánh...", Color.WHITE, 0.5)
		else:
			if hud:
				hud.show_notification("Hãy nhận đơn hàng từ khách trước!")
		return
	
	# 2. Thêm nguyên liệu
	if held_item_name == "Bánh mì đang làm":
		if manager and manager.add_ingredient(item_name):
			_play_ingredient_sfx(item_name)
			hud.set_recipe_text(manager.get_recipe_info())
			show_floating_text(interaction_point, "+ " + item_name, Color.GREEN, 0.5)
			if manager.is_finished():
				var finished_asset = manager.RECIPES[manager.active_orders[current_order_customer]["order_type"]]["final_asset"]
				pick_up_item(finished_asset, "Bánh mì hoàn chỉnh")
		return
	
	# 3. Giao cho khách hoặc Nhận đơn
	if is_customer:
		if held_item_name == "Bánh mì hoàn chỉnh":
			if item_name == current_order_customer:
				# ===== THANH TOÁN & PHẢN HỒI =====
				show_floating_text(interaction_point + Vector3(0, 1, 0), "Cảm ơn nhé!", Color.GREEN, 2.0)
				
				var payment = manager.finish_order(item_name)
				drop_held_item()
				
				if payment.size() > 0:
					# Cộng tiền vào Global
					Global.add_earnings(payment["base"], payment["tip"])
					
					# Phát tiếng máy tính tiền
					var cash_sound = AudioStreamPlayer.new()
					cash_sound.stream = load("res://assets/Sounds/Cash Register.wav")
					get_tree().root.add_child(cash_sound)
					cash_sound.play()
					cash_sound.finished.connect(cash_sound.queue_free)
					
					# Thông báo chi tiết
					var msg = "✓ Giao hàng cho %s!\n+%s VND (tip: +%s VND)" % [
						item_name,
						_format_money(payment["base"]),
						_format_money(payment["tip"])
					]
					if hud:
						hud.show_notification(msg, 3.0)
						hud.set_recipe_text(manager.get_recipe_info())
			else:
				show_floating_text(interaction_point + Vector3(0, 1, 0), "Ơ kìa, đây không phải bánh mì của tôi!", Color.RED, 2.0)
				if hud:
					hud.show_notification("Ơ kìa, đây không phải bánh mì của tôi!\n(Bánh này của " + current_order_customer + ")")
		elif held_item_name == "":
			if not Global.is_shop_open:
				if hud: hud.show_notification("Xin lỗi, Bánh Mì EXE chưa mở cửa ạ")
				return
			if manager:
				if manager.active_orders.has(item_name):
					manager.current_working_customer = item_name
					hud.set_recipe_text(manager.get_recipe_info())
					show_floating_text(interaction_point + Vector3(0, 1, 0), "Đang chờ: " + manager.active_orders[item_name]["order_type"], Color.YELLOW, 1.5)
				else:
					manager.generate_order_for_customer(item_name)
					hud.set_recipe_text(manager.get_recipe_info())
					var order_type = manager.active_orders[item_name]["order_type"]
					show_floating_text(interaction_point + Vector3(0, 1, 0), order_type, Color.CYAN, 1.5)
		return

func show_floating_text(pos: Vector3, text_content: String, color: Color = Color.WHITE, duration: float = 1.0):
	var label = Label3D.new()
	label.text = text_content
	label.modulate = color
	label.billboard = StandardMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 100
	label.font_size = 32
	label.outline_size = 8
	
	get_tree().root.add_child(label)
	label.global_position = pos + Vector3(0, 0.5, 0)
	label.scale = Vector3(1.2, 1.2, 1.2)
	
	var tween = get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "scale", Vector3.ZERO, 0.5).set_delay(duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(label, "modulate:a", 0.0, 0.5).set_delay(duration)
	
	get_tree().create_timer(duration + 0.5).timeout.connect(label.queue_free)

func _format_money(amount: int) -> String:
	var s = str(amount)
	var result = ""
	var count = 0
	for i in range(s.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "," + result
		result = s[i] + result
		count += 1
	return result

func pick_up_item(asset_path: String, type_name: String):
	if held_item_node:
		held_item_node.queue_free()
	
	var scene = load(asset_path)
	if scene:
		held_item_node = scene.instantiate()
		hand.add_child(held_item_node)
		held_item_node.scale = Vector3(0.5, 0.5, 0.5) 
	
	held_item_name = type_name

func drop_held_item():
	if held_item_node:
		held_item_node.queue_free()
		held_item_node = null
	held_item_name = ""
	current_order_customer = ""

func _play_sfx_pool(paths: Array, volume_db: float = -10.0, pitch_min: float = 0.97, pitch_max: float = 1.03):
	if paths.is_empty():
		return

	var idx = _rng.randi_range(0, paths.size() - 1)
	var stream = load(paths[idx])
	if stream == null:
		return

	var player = AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = _rng.randf_range(pitch_min, pitch_max)
	get_tree().root.add_child(player)
	player.play()
	player.finished.connect(player.queue_free)

func _play_ingredient_sfx(item_name: String):
	var normalized = item_name.to_lower()

	if "rau" in normalized or "đồ chua" in normalized:
		_play_sfx_pool(_sfx_ingredient_veg, -11.0, 0.98, 1.04)
		return

	if "thịt" in normalized or "chả" in normalized or "trứng" in normalized:
		_play_sfx_pool(_sfx_ingredient_meat, -10.0, 0.95, 1.02)
		return

	if "pate" in normalized or "sốt" in normalized:
		_play_sfx_pool(_sfx_ingredient_sauce, -10.0, 0.98, 1.03)
		return

	_play_sfx_pool(_sfx_ingredient_generic, -11.0, 0.98, 1.03)
