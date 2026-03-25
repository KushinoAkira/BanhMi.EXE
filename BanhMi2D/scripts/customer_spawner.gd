## customer_spawner.gd — Sinh NPC khách hàng ngẫu nhiên
extends Node

# ─── EXPORTS ───────────────────────────────────────────────
@export var customer_scene: PackedScene
@export var max_customers: int = 12

# ─── REFERENCES (set bởi main.gd) ─────────────────────────
var spawn_points: Array[Marker2D] = []
var wander_points: Array[Marker2D] = []
var banh_mi_cart: Node2D = null
var game_world: Node2D = null

# ─── ONREADY ──────────────────────────────────────────────
@onready var spawn_timer: Timer = $SpawnTimer

# ─── TRACKING & POOLING ─────────────────────────────────────
var active_customers: int = 0
var npc_pool: Array[CharacterBody2D] = []
@export var pool_size: int = 15

# ─── READY ─────────────────────────────────────────────────
func _ready() -> void:
	spawn_timer.wait_time = GameManager.get_spawn_interval()
	spawn_timer.one_shot = false
	spawn_timer.autostart = false  # Không auto-start, đợi main.gd setup xong
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	GameManager.upgrade_purchased.connect(_on_upgrade_purchased)

	# Đợi 1 frame để main.gd truyền references xong mới bắt đầu spawn
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Khởi tạo Object Pool
	_initialize_pool()
	
	spawn_timer.start()
	print("[Spawner] ✅ Pool initialized (%d) & Spawning started" % pool_size)

	# Spawn ngay 2-3 NPC ban đầu từ pool
	for i in range(randi_range(2, 3)):
		_spawn_customer()
		await get_tree().create_timer(0.2).timeout

func _initialize_pool() -> void:
	if not customer_scene: return
	for i in range(pool_size):
		var npc = customer_scene.instantiate()
		npc.hide()
		npc.process_mode = Node.PROCESS_MODE_DISABLED
		npc.returned_to_pool.connect(_on_npc_returned_to_pool)
		
		# Add to game world (or self) to keep in tree
		if game_world:
			game_world.add_child(npc)
		else:
			add_child(npc)
		npc_pool.append(npc)

func _process(_delta: float) -> void:
	# Cập nhật liên tục tốc độ spawn theo Fever Mode
	var current_req_time: float = GameManager.get_spawn_interval()
	if spawn_timer.wait_time != current_req_time:
		spawn_timer.wait_time = current_req_time

# ─── SPAWN LOGIC ──────────────────────────────────────────
func _on_spawn_timer_timeout() -> void:
	if not GameManager.is_shop_open:
		return
	if active_customers >= max_customers:
		return
	_spawn_customer()

func _spawn_customer() -> void:
	if npc_pool.is_empty():
		# Nếu pool hết (hiếm khi xảy ra với 12 max), tạo thêm 1 cái
		_add_new_to_pool()
	
	var customer = npc_pool.pop_back()
	if not customer: return

	if spawn_points.is_empty():
		push_warning("[Spawner] Thiếu spawn_points!")
		npc_pool.append(customer)
		return

	var sp: Marker2D = spawn_points.pick_random()
	
	# Reset NPC state
	customer.position = sp.global_position
	customer.banh_mi_cart = banh_mi_cart
	customer.wander_points = wander_points
	customer.prepare_for_reuse() # Reset AI & Graphics

	active_customers += 1
	print("[Spawner] 👤 NPC lấy từ Pool #%d. Active: %d" % [
		npc_pool.size(), active_customers
	])

func _add_new_to_pool() -> void:
	var npc = customer_scene.instantiate()
	npc.hide()
	npc.process_mode = Node.PROCESS_MODE_DISABLED
	npc.returned_to_pool.connect(_on_npc_returned_to_pool)
	if game_world:
		game_world.add_child(npc)
	else:
		add_child(npc)
	npc_pool.append(npc)

func _on_npc_returned_to_pool(npc: CharacterBody2D) -> void:
	active_customers = maxi(active_customers - 1, 0)
	npc_pool.append(npc)
	print("[Spawner] 🔄 NPC trả về Pool. Active: %d" % active_customers)

# Xóa các hàm cũ không còn dùng
func _on_customer_removed() -> void:
	pass

# ─── UPGRADE RESPONSE ─────────────────────────────────────
func _on_upgrade_purchased(_upgrade_id: String) -> void:
	var new_interval: float = GameManager.get_spawn_interval()
	spawn_timer.wait_time = new_interval
	print("[Spawner] ⏱️ Spawn interval: %.1fs" % new_interval)
