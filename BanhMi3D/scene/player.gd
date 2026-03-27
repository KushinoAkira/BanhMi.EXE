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

var held_item_name: String = ""
var held_item_node: Node3D = null
var current_order_customer: String = "" # Tên khách mà chiếc bánh này thuộc về

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	hud = get_node_or_null("/root/Main/HUD")
	manager = get_node_or_null("/root/Main/BanhMiManager")
	interaction_ray.collision_mask = 2 # Chỉ nhìn Layer 2
	
	if hud and manager:
		hud.set_recipe_text(manager.get_recipe_info())

func _input(event):
	# 1. Bắt chuột khi nhấn vào màn hình
	# -- Không re-capture khi đang hiện bảng tổng kết cuối ngày
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

	# Alt — giữ để hiện chuột bấm HUD, thả lại để ẩn
	if event is InputEventKey and event.keycode == KEY_ALT:
		if event.pressed and not event.echo:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		elif not event.pressed:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta):
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
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

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
	
	# Kiểm tra nếu là Khách hàng
	var is_customer = manager != null and (item_name in ["Khoa", "Hiếu", "Hoàng", "Phương", "Huyền", "Nam", "Lan", "Tuấn", "Linh", "Đức"])
	
	# 1. Lấy bánh mì
	if item_name == "Bánh mì" and held_item_name == "":
		if manager and manager.current_working_customer != "":
			pick_up_item("res://assets/banh_mi_items/banh_mi.glb", "Bánh mì đang làm")
			current_order_customer = manager.current_working_customer
			print(">>> [LÀM BÁNH] Đang làm cho ", current_order_customer)
		else:
			if hud:
				hud.show_notification("Hãy nhận đơn hàng từ khách trước!")
			print(">>> [!] Hãy nhận đơn hàng từ khách trước!")
		return
	
	# 2. Thêm nguyên liệu
	if held_item_name == "Bánh mì đang làm":
		if manager and manager.add_ingredient(item_name):
			hud.set_recipe_text(manager.get_recipe_info())
			if manager.is_finished():
				var finished_asset = manager.RECIPES[manager.active_orders[current_order_customer]["order_type"]]["final_asset"]
				pick_up_item(finished_asset, "Bánh mì hoàn chỉnh")
				print(">>> [XONG] Đã hoàn thành bánh mì cho ", current_order_customer)
		return
	
	# 3. Giao cho khách hoặc Nhận đơn
	if is_customer:
		if held_item_name == "Bánh mì hoàn chỉnh":
			if item_name == current_order_customer:
				# ===== THANH TOÁN =====
				var payment = manager.finish_order(item_name)
				drop_held_item()
				
				if payment.size() > 0:
					# Cộng tiền vào Global
					Global.add_earnings(payment["base"], payment["tip"])
					
					# Thông báo chi tiết
					var msg = "✓ Giao hàng cho %s!\n+%s VND (tip: +%s VND)" % [
						item_name,
						_format_money(payment["base"]),
						_format_money(payment["tip"])
					]
					if hud:
						hud.show_notification(msg, 3.0)
						hud.set_recipe_text(manager.get_recipe_info())
					print(">>> [THANH TOÁN] ", payment["order_type"], 
						" - Giá: ", payment["base"], 
						" + Tip: ", payment["tip"])
			else:
				if hud:
					hud.show_notification("Ơ kìa, đây không phải bánh mì của tôi!\n(Bánh này của " + current_order_customer + ")")
				print(">>> [NHẦM KHÁCH] Bánh này là của ", current_order_customer, " mà!")
		elif held_item_name == "":
			if manager:
				if manager.active_orders.has(item_name):
					manager.current_working_customer = item_name
					hud.set_recipe_text(manager.get_recipe_info())
					if hud:
						hud.show_notification("Đang tập trung làm cho " + item_name, 1.5)
					print(">>> [TẬP TRUNG] Quay lại làm bánh cho ", item_name)
				else:
					manager.generate_order_for_customer(item_name)
					hud.set_recipe_text(manager.get_recipe_info())
					if hud:
						hud.show_notification(item_name + " muốn 1 ổ " + manager.active_orders[item_name]["order_type"])
		return

func _format_money(amount: int) -> String:
	# Format: 15000 -> "15,000"
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
