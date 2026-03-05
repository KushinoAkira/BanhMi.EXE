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

	print("[BanhMiCart] Đã khởi tạo với %d vị trí xếp hàng" % queue_positions.size())

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

func _start_serving() -> void:
	if queue.is_empty():
		is_serving = false
		return

	is_serving = true
	var front_customer = queue[0]

	# Thông báo customer chuyển sang trạng thái BUYING
	if front_customer != null and is_instance_valid(front_customer):
		front_customer.start_buying()

	# Thời gian phục vụ lấy từ GameManager (bị ảnh hưởng bởi upgrades)
	var serve_time: float = GameManager.get_service_time()
	service_timer.wait_time = serve_time
	service_timer.start()

	print("[BanhMiCart] Bắt đầu phục vụ (%.1fs)..." % serve_time)

func _on_service_timer_timeout() -> void:
	if queue.is_empty():
		is_serving = false
		return

	# Lấy khách đầu tiên ra
	var served_customer = queue.pop_front()

	# Cộng tiền
	var price: int = GameManager.get_sell_price()
	GameManager.add_money(price)
	customer_served.emit(price)

	print("[BanhMiCart] Đã phục vụ xong! +%dđ (Tổng: %dđ)" % [price, GameManager.money])

	# Yêu cầu khách rời đi
	if served_customer != null and is_instance_valid(served_customer):
		served_customer.finish_buying()

	# Dịch chuyển tất cả NPC còn lại lên một bước
	_advance_queue()

	# Phục vụ người tiếp theo
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
