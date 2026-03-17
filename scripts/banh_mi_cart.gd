## banh_mi_cart.gd — Quản lý hàng đợi & phục vụ khách
## Gắn vào Node2D BanhMiCart trong Main scene
extends Node2D

# ─── SIGNALS ───────────────────────────────────────────────
signal customer_served(sell_price: int)
signal queue_updated()

# ─── EXPORTS ───────────────────────────────────────────────
@export var max_queue_size: int = 6  ## Số lượng tối đa trong hàng đợi

# ─── VARS ──────────────────────────────────────────────────
var queue: Array = []  # Array of CharacterBody2D (customers)
var is_serving: bool = false

# ─── ONREADY NODES ────────────────────────────────────────
@onready var service_timer: Timer = $ServiceTimer
@onready var queue_positions_node: Node2D = $QueuePositions
@onready var cart_sprite: Sprite2D = $Sprite2D
@onready var cart_light: PointLight2D = $CartLight

# ─── TEXTURES ──────────────────────────────────────────────
var tex_lvl1 = preload("res://assets/sprites/banh_mi_cart.png")
var tex_lvl2 = preload("res://assets/sprites/banh_mi_cart.png") # TODO: Cần người thiết kế cung cấp lvl2
var tex_lvl3 = preload("res://assets/sprites/banh_mi_cart.png") # TODO: Cần người thiết kế cung cấp lvl3

# Mảng vị trí Vector2 lấy từ các Marker2D con
var queue_positions: Array[Vector2] = []

# ─── READY ─────────────────────────────────────────────────
func _ready() -> void:
	# Thu thập tất cả Marker2D con trong QueuePositions
	for child in queue_positions_node.get_children():
		if child is Marker2D:
			queue_positions.append(child.global_position)

	# Cấu hình Timer
	service_timer.one_shot = true
	service_timer.timeout.connect(_on_service_timer_timeout)

	# Lắng nghe sự kiện Level Up xe từ GameManager
	GameManager.cart_level_changed.connect(_on_cart_level_changed)

	print("[BanhMiCart] Đã khởi tạo với %d vị trí xếp hàng" % queue_positions.size())

# ─── VISUAL PROGRESSION ───────────────────────────────────
func _on_cart_level_changed(new_level: int) -> void:
	var decor_lvl2 = get_node_or_null("DecorationsLevel2")
	var decor_lvl3 = get_node_or_null("DecorationsLevel3")
	
	match new_level:
		1:
			cart_sprite.texture = tex_lvl1
			cart_light.energy = 0.0
			if decor_lvl2: decor_lvl2.hide()
			if decor_lvl3: decor_lvl3.hide()
		2:
			cart_sprite.texture = tex_lvl2 # Tạm dùng lvl1
			cart_sprite.modulate = Color(1.1, 1.1, 1.2) # Làm sáng lên xíu
			cart_light.energy = 0.5
			if decor_lvl2: decor_lvl2.show()
			if decor_lvl3: decor_lvl3.hide()
		3:
			cart_sprite.texture = tex_lvl3 # Tạm dùng lvl1
			cart_sprite.modulate = Color(1.2, 1.1, 1.0) # Vàng ấm
			cart_light.energy = 1.0
			cart_light.color = Color(1.0, 0.8, 0.2)
			if decor_lvl2: decor_lvl2.show()
			if decor_lvl3: decor_lvl3.show()
			
	print("[BanhMiCart] Xe Bánh Mì đã được nâng cấp chói lọi lên Cấp %d!" % new_level)
	
	# Hiệu ứng Particle khi nâng cấp
	_spawn_upgrade_particles()

func _spawn_upgrade_particles() -> void:
	var req = CPUParticles2D.new()
	req.emitting = false
	req.one_shot = true
	req.amount = 40
	req.lifetime = 1.0
	req.explosiveness = 0.8
	req.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	req.emission_sphere_radius = 50.0
	req.gravity = Vector2(0, -98)
	req.scale_amount_min = 2.0
	req.scale_amount_max = 6.0
	req.color = Color(1.0, 0.84, 0.0) # Gold
	add_child(req)
	req.emitting = true
	
	await get_tree().create_timer(1.2).timeout
	req.queue_free()

# ─── QUEUE MANAGEMENT ─────────────────────────────────────

## Thêm khách vào hàng đợi. Trả về index, hoặc -1 nếu hàng đầy.
func join_queue(customer: CharacterBody2D) -> int:
	if queue.size() >= max_queue_size or queue.size() >= queue_positions.size():
		print("[BanhMiCart] Hàng đầy! Từ chối khách.")
		return -1

	var index := queue.size()
	queue.append(customer)
	queue_updated.emit()

	print("[BanhMiCart] Khách xếp hàng tại vị trí %d (Tổng: %d)" % [index, queue.size()])

	# Nếu chỉ có 1 người và chưa phục vụ → bắt đầu phục vụ
	if queue.size() == 1 and not is_serving:
		_start_serving()

	return index

## Lấy vị trí Vector2 toàn cục của slot trong hàng
func get_queue_position(index: int) -> Vector2:
	if index >= 0 and index < queue_positions.size():
		return queue_positions[index]
	# Fallback: đứng phía sau vị trí cuối cùng
	if queue_positions.size() > 0:
		var last_pos: Vector2 = queue_positions[queue_positions.size() - 1]
		# Offset thêm về phía dưới-phải (Isometric)
		return last_pos + Vector2(16, 8) * (index - queue_positions.size() + 1)
	return global_position + Vector2(0, 50)

# ─── SERVING LOGIC ────────────────────────────────────────

## NPC gọi hàm này khi họ đã thực sự đi đến vị trí đầu hàng
func notify_customer_arrived() -> void:
	if queue.is_empty() or is_serving:
		return
	
	_start_serving()

func _start_serving() -> void:
	if queue.is_empty():
		is_serving = false
		return

	var front_customer = queue[0]
	if front_customer == null or not is_instance_valid(front_customer):
		queue.pop_front()
		_advance_queue()
		return

	is_serving = true
	front_customer.start_buying()

	var serve_time: float = GameManager.get_service_time()
	service_timer.wait_time = serve_time
	service_timer.start()

	print("[BanhMiCart] Bắt đầu phục vụ (%.1fs)..." % serve_time)

func _on_service_timer_timeout() -> void:
	if queue.is_empty():
		is_serving = false
		return

	var served_customer = queue.pop_front()
	var base_price: int = GameManager.get_sell_price()
	var final_money: int = base_price
	
	if served_customer != null and is_instance_valid(served_customer):
		# 1. Kiểm tra VIP
		var is_vip = served_customer.get("is_vip") == true
		if is_vip:
			final_money *= 3
			print("[BanhMiCart] Phục vụ KHÁCH VIP! Nhân 3 tiền.")
		
		# 2. Tiền Tip dựa trên độ kiên nhẫn còn lại
		var c_tip_chance = served_customer.get("tip_chance")
		if c_tip_chance == null: c_tip_chance = 0.1
		
		var c_patience = served_customer.get("patience")
		var c_max_patience = served_customer.get("max_patience")
		
		# Nếu phục vụ nhanh (kiên nhẫn còn > 70%)
		if c_patience != null and c_max_patience != null and c_patience / c_max_patience > 0.7:
			# Khách VIP luôn cho tip nếu phục vụ nhanh, khách thường thì ngẫu nhiên
			if is_vip or randf() < c_tip_chance:
				var tip_multiplier = GameManager.get_tip_multiplier()
				var tip_amount = int(base_price * randf_range(0.15, 0.20) * tip_multiplier)
				final_money += tip_amount
				if tip_multiplier > 1.0:
					print("[BanhMiCart] Phục vụ nhanh! Nhận Tip (x%.1f Buff): +%dđ" % [tip_multiplier, tip_amount])
				else:
					print("[BanhMiCart] Phục vụ nhanh! Nhận Tip: +%dđ" % tip_amount)
		
		GameManager.add_money(final_money)
		customer_served.emit(final_money)
		
		print("[BanhMiCart] Đã phục vụ xong! +%dđ (Tổng: %dđ)" % [final_money, GameManager.money])
		served_customer.finish_buying()

	_advance_queue()
	
	# Kiểm tra người tiếp theo đã đến nơi chưa để phục vụ tiếp
	if not queue.is_empty():
		_start_serving()
	else:
		is_serving = false

func _advance_queue() -> void:
	for i in range(queue.size()):
		var customer = queue[i]
		if customer != null and is_instance_valid(customer):
			customer.advance_to_position(i)
	queue_updated.emit()

# ─── PUBLIC HELPERS ────────────────────────────────────────

## Xóa một NPC cụ thể khỏi hàng đợi (trường hợp NPC bị xóa bất thường)
func remove_customer(customer: CharacterBody2D) -> void:
	var idx := queue.find(customer)
	if idx == -1:
		return
	queue.remove_at(idx)
	_advance_queue()
	if idx == 0 and not queue.is_empty():
		_start_serving()

func get_queue_size() -> int:
	return queue.size()

func is_queue_full() -> bool:
	return queue.size() >= max_queue_size or queue.size() >= queue_positions.size()
