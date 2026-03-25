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

var umbrella_sprite: Label
var speaker_sprite: Label
var led_bg: ColorRect
var led_text: Label

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
# Dùng Marker2D refs thay vì Vector2 tĩnh — đọc global_position động sau khi xe được dời
var queue_markers: Array[Marker2D] = []

# ─── READY ─────────────────────────────────────────────────
func _ready() -> void:
	# Thu thập Marker2D refs — không lưu global_position tĩnh vì xe chưa được đặt vào đúng chỗ
	for child in queue_positions_node.get_children():
		if child is Marker2D:
			queue_markers.append(child as Marker2D)

	# Cấu hình Timer
	service_timer.one_shot = true
	service_timer.timeout.connect(_on_service_timer_timeout)

	# Lắng nghe sự kiện Level Up xe từ GameManager
	GameManager.cart_level_changed.connect(_on_cart_level_changed)
	GameManager.upgrade_purchased.connect(func(_id): _check_decorations())

	_setup_decorations()
	_check_decorations()

	print("[BanhMiCart] Đã khởi tạo với %d vị trí xếp hàng" % queue_markers.size())

var _decor_nodes: Array[Node] = []  # Tất cả decor node, quản lý show/hide theo level

# ─── ASSET PATHS ─────────────────────────────────────────────
const DECOR_ASSETS = {
	"bonsai":       "res://assets/sprites/props/decor_bonsai.png",
	"chalkboard":   "res://assets/sprites/props/decor_chalkboard.png",
	"speaker":      "res://assets/sprites/props/decor_bonsai.png",    # fallback dùng cây
	"umbrella":     "res://assets/sprites/props/decor_striped_awning.png",
	"flag_banner":  "res://assets/sprites/props/decor_flag_banner.png",
	"lanterns":     "res://assets/sprites/props/decor_lanterns.png",
	"led_sign":     "res://assets/sprites/props/decor_neon_sign.png",
	"awning":       "res://assets/sprites/props/decor_striped_awning.png",
	"fairy_lights": "res://assets/sprites/props/decor_fairy_lights.png",
	"neon_sign":    "res://assets/sprites/props/decor_neon_sign.png",
	"golden_sign":  "res://assets/sprites/props/decor_golden_sign.png",
}

# Danh sách trang trí theo cấp độ (index 0 = cấp 2, index 10 = cấp 12)
# Mỗi entry: [asset_key, position, scale, z_index]
const LEVEL_DECORATIONS: Array[Dictionary] = [
	# Cấp 2 — Cây cảnh bonsai bên trái xe
	{"key": "bonsai",      "pos": Vector2(-55, 15),   "scale": Vector2(0.08, 0.08), "z": 3},
	# Cấp 3 — Bảng hiệu "ĐẶC BIỆT" nhỏ bên phải
	{"key": "chalkboard",  "pos": Vector2(60, 10),    "scale": Vector2(0.06, 0.06), "z": 3},
	# Cấp 4 — Cây bonsai thứ 2 (biểu trưng thêm xanh mát)
	{"key": "bonsai",      "pos": Vector2(-75, 5),    "scale": Vector2(0.06, 0.06), "z": 3},
	# Cấp 5 — Mái che mưa nắng kẻ sọc đỏ trắng (Đứng phía sau xe và nhân vật)
	{"key": "umbrella",    "pos": Vector2(-20, -50),  "scale": Vector2(0.12, 0.12), "z": -1},
	# Cấp 6 — Dây cờ tam giác nhiều màu
	{"key": "flag_banner", "pos": Vector2(-50, -60),  "scale": Vector2(0.12, 0.12), "z": 4},
	# Cấp 7 — Đèn lồng đỏ vàng treo phía trên
	{"key": "lanterns",    "pos": Vector2(-30, -85),  "scale": Vector2(0.10, 0.10), "z": 4},
	# Cấp 8 — Bảng LED neon "BÁNH MÌ"
	{"key": "led_sign",    "pos": Vector2(10, -95),   "scale": Vector2(0.09, 0.09), "z": 5},
	# Cấp 9 — Thêm một cây bonsai lớn hơn bên phải
	{"key": "bonsai",      "pos": Vector2(75, 5),     "scale": Vector2(0.10, 0.10), "z": 3},
	# Cấp 10 — Dây đèn fairy lights lấp lánh
	{"key": "fairy_lights","pos": Vector2(-50, -75),  "scale": Vector2(0.13, 0.13), "z": 4},
	# Cấp 11 — Biển neon sáng đỏ cam "BÁNH MÌ" nổi bật
	{"key": "neon_sign",   "pos": Vector2(-20, -120), "scale": Vector2(0.11, 0.11), "z": 6},
	# Cấp 12 — Biển vàng rồng cao cấp — đỉnh cao thịnh vượng
	{"key": "golden_sign", "pos": Vector2(-15, -145), "scale": Vector2(0.12, 0.12), "z": 7},
]

func _setup_decorations() -> void:
	# Tạo sẵn tất cả decor node, ẩn hết
	for entry in LEVEL_DECORATIONS:
		var spr := Sprite2D.new()
		var tex_path: String = DECOR_ASSETS.get(entry.key, "")
		if tex_path != "" and ResourceLoader.exists(tex_path):
			spr.texture = load(tex_path)
		else:
			# Fallback: Label emoji nếu thiếu asset
			var lbl := Label.new()
			lbl.text = "🎪"
			lbl.add_theme_font_size_override("font_size", 40)
			lbl.position = entry.pos
			lbl.z_index = entry.z
			lbl.hide()
			add_child(lbl)
			_decor_nodes.append(lbl)
			continue
		spr.position = entry.pos
		spr.scale = entry.scale
		spr.z_index = entry.z
		spr.hide()
		add_child(spr)
		_decor_nodes.append(spr)

	var speaker_timer = Timer.new()
	speaker_timer.wait_time = 15.0
	speaker_timer.autostart = true
	speaker_timer.timeout.connect(_on_speaker_timer)
	add_child(speaker_timer)

func _check_decorations() -> void:
	# Không cần kiểm tra từng cái, _on_cart_level_changed quản lý việc show/hide
	pass

func _on_speaker_timer() -> void:
	if GameManager.get_upgrade_level("decor_speaker") > 0:
		var speaker_bubble = Label.new()
		speaker_bubble.text = "🔊 Bánh mì Sài Gòn,\nđặc ruột thơm bơ 15 ngàn!"
		speaker_bubble.add_theme_font_size_override("font_size", 18)
		speaker_bubble.add_theme_color_override("font_color", Color(1, 1, 0))
		speaker_bubble.add_theme_color_override("font_outline_color", Color.BLACK)
		speaker_bubble.add_theme_constant_override("outline_size", 4)
		speaker_bubble.position = Vector2(-180, -150)
		add_child(speaker_bubble)
		
		var tw = create_tween()
		tw.tween_property(speaker_bubble, "position:y", -200.0, 3.0).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(speaker_bubble, "modulate:a", 0.0, 3.0)
		tw.tween_callback(speaker_bubble.queue_free)

# ─── VISUAL PROGRESSION ───────────────────────────────────────
func _on_cart_level_changed(new_level: int) -> void:
	# Hiện tất cả decor đến level hiện tại (cumulative)
	# Index 0 = level 2, index 10 = level 12
	for i in range(_decor_nodes.size()):
		var node = _decor_nodes[i]
		if is_instance_valid(node):
			node.visible = (new_level >= i + 2)

	# Ẩn đồ nội thất cấp thấp của version cũ (nếu có trong scene)
	var decor_lvl2 = get_node_or_null("DecorationsLevel2")
	var decor_lvl3 = get_node_or_null("DecorationsLevel3")
	if decor_lvl2: decor_lvl2.hide()
	if decor_lvl3: decor_lvl3.hide()

	# Điều chỉnh ánh sáng xe theo cấp
	var light_energy := clampf((new_level - 1) * 0.1, 0.0, 1.2)
	cart_light.energy = light_energy

	if new_level >= 8:
		cart_light.color = Color(1.0, 0.7, 0.3)   # Cam ấm — mid-high
	if new_level >= 11:
		cart_light.color = Color(1.0, 0.5, 0.1)   # Cam neon — đỉnh
	if new_level >= 12:
		cart_light.color = Color(1.0, 0.85, 0.2)  # Vàng hoàng kim
		cart_sprite.modulate = Color(1.2, 1.1, 1.0)
	else:
		cart_sprite.modulate = Color(1.0, 1.0, 1.0) # Normal

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
	if queue.size() >= max_queue_size or queue.size() >= queue_markers.size():
		print("[BanhMiCart] Hàng đầy! Từ chối khách.")
		return -1

	var index := queue.size()
	queue.append(customer)
	queue_updated.emit()

	print("[BanhMiCart] Khách xếp hàng tại vị trí %d (Tổng: %d)" % [index, queue.size()])

	# Không phục vụ ngay — chờ NPC đi tới vị trí rồi gọi notify_customer_arrived()
	return index

## Lấy vị trí Vector2 toàn cục của slot trong hàng (đọc động từ Marker2D)
func get_queue_position(index: int) -> Vector2:
	if index >= 0 and index < queue_markers.size():
		return queue_markers[index].global_position
	# Fallback: đứng phía sau marker cuối cùng
	if queue_markers.size() > 0:
		var last_pos: Vector2 = queue_markers[queue_markers.size() - 1].global_position
		# Offset thêm về phía dưới-phải (Isometric)
		return last_pos + Vector2(16, 8) * (index - queue_markers.size() + 1)
	return global_position + Vector2(0, 50)

# ─── SERVING LOGIC ────────────────────────────────────────

## NPC gọi hàm này khi họ đã thực sự đi đến vị trí đầu hàng
func notify_customer_arrived() -> void:
	if queue.is_empty() or is_serving:
		return
	
	_start_serving()

var special_order_timer: float = 10.0

func _process(delta: float) -> void:
	if special_order_timer > 0.0:
		special_order_timer -= delta

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

	# Cứ mỗi 10 giây thì sẽ có một đơn hàng đặc biệt
	if special_order_timer <= 0 and not GameManager.is_fever_mode and not GameManager.is_player_busy():
		print("[BanhMiCart] Khách hàng yêu cầu Đơn Hàng Đặc Biệt!")
		special_order_timer = 10.0 # Reset timer
		_trigger_cooking_minigame()
		return

	var serve_time: float = GameManager.get_service_time()
	service_timer.wait_time = serve_time
	service_timer.start()

	print("[BanhMiCart] Bắt đầu phục vụ (%.1fs)..." % serve_time)

func _trigger_cooking_minigame() -> void:
	var mg = CanvasLayer.new()
	var CookingScript = preload("res://scripts/cooking_minigame.gd")
	mg.set_script(CookingScript)
	
	# Kết nối signal
	mg.minigame_completed.connect(_on_cooking_minigame_completed)
	get_tree().root.add_child(mg)

func _on_cooking_minigame_completed(won: bool) -> void:
	if queue.is_empty():
		is_serving = false
		return
	
	var served_customer = queue.pop_front()
	if won:
		print("[BanhMiCart] Hoàn thành Đơn Đặc Biệt! Thưởng cực lớn!")
		var base_price = GameManager.get_sell_price()
		var final_money = base_price * 5 # x5 tiền
		
		# Tính thêm nếu là VIP để tránh mất quyền lợi
		if is_instance_valid(served_customer) and served_customer.get("is_vip") == true:
			final_money *= 3
			
		GameManager.add_money(final_money) 
		GameManager.add_boost_energy(50.0)    # Tăng thanh Fever
		GameManager.record_customer_served(true)
		if is_instance_valid(served_customer):
			served_customer.finish_buying()
		customer_served.emit(final_money)
	else:
		print("[BanhMiCart] Làm hỏng Đơn Đặc Biệt! Khách bỏ đi.")
		GameManager.record_customer_lost()
		if is_instance_valid(served_customer):
			if served_customer.has_method("fail_buying"):
				served_customer.fail_buying()
			
	_advance_queue()
	if not queue.is_empty():
		_start_serving()
	else:
		is_serving = false

func _on_service_timer_timeout() -> void:
	if queue.is_empty():
		is_serving = false
		return

	var served_customer = queue.pop_front()
	
	# Consume ingredient first
	if not GameManager.consume_ingredient():
		print("[BanhMiCart] Hết nguyên liệu! Khách tức giận bỏ đi.")
		GameManager.record_customer_lost()
		if is_instance_valid(served_customer):
			if served_customer.has_method("fail_buying"):
				served_customer.fail_buying()
		
		_advance_queue()
		if not queue.is_empty():
			_start_serving()
		else:
			is_serving = false
		return
		
	var base_price: int = GameManager.get_sell_price()
	var final_money: int = base_price
	
	if served_customer != null and is_instance_valid(served_customer):
		# 1. Kiểm tra VIP & Customer Type
		var is_vip = served_customer.get("is_vip") == true
		var c_type = served_customer.get("customer_type")
		
		if c_type != null:
			if c_type == 0: # STUDENT
				final_money = GameManager.base_sell_price
			elif c_type == 3: # TOURIST
				final_money *= 2
				print("[BanhMiCart] Khách du lịch! Giá bán nhân đôi.")
				
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
		# Thợ văn phòng vội vàng (OFFICE_WORKER = 1), tip rất cao nếu phục vụ cực nhanh (kiên nhẫn > 80%)
		var fast_threshold = 0.7
		if c_type == 1: fast_threshold = 0.8
		
		# Nếu phục vụ nhanh
		if c_patience != null and c_max_patience != null and c_patience / c_max_patience > fast_threshold:
			# Khách VIP và Du lịch luôn cho tip nếu phục vụ nhanh, khách thường thì ngẫu nhiên
			if is_vip or c_type == 3 or randf() < c_tip_chance:
				# Tỉ lệ tip riêng, thợ văn phòng tip siêu cao nếu chờ ít
				var tip_multiplier = randf_range(0.3, 0.6)
				if c_type == 1: tip_multiplier = randf_range(0.8, 1.5)
				elif c_type == 3: tip_multiplier = randf_range(0.5, 1.0)
				
				var tip_amount = int(base_price * tip_multiplier)
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
	return queue.size() >= max_queue_size or queue.size() >= queue_markers.size()
