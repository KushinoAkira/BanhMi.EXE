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

# ─── TRACKING ─────────────────────────────────────────────
var active_customers: int = 0

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
	spawn_timer.start()
	print("[Spawner] ✅ Bắt đầu spawn — interval: %.1fs" % spawn_timer.wait_time)

	# Spawn ngay 2-3 NPC ban đầu
	for i in range(randi_range(2, 3)):
		_spawn_customer()
		await get_tree().create_timer(0.2).timeout

# ─── SPAWN LOGIC ──────────────────────────────────────────
func _on_spawn_timer_timeout() -> void:
	if active_customers >= max_customers:
		return
	if spawn_points.is_empty() or customer_scene == null:
		return
	_spawn_customer()

func _spawn_customer() -> void:
	if spawn_points.is_empty() or customer_scene == null:
		push_warning("[Spawner] Thiếu spawn_points hoặc customer_scene!")
		return

	var sp: Marker2D = spawn_points.pick_random()
	var customer: CharacterBody2D = customer_scene.instantiate()

	# Set position TRƯỚC khi add_child
	customer.position = sp.global_position

	# Truyền references TRƯỚC khi add_child (vì _ready chạy khi add_child)
	customer.banh_mi_cart = banh_mi_cart
	customer.wander_points = wander_points

	# Lắng nghe khi NPC bị xóa
	customer.tree_exiting.connect(_on_customer_removed)

	# Thêm vào scene tree → _ready() của customer chạy ở đây
	if game_world != null:
		game_world.add_child(customer)
	else:
		get_tree().current_scene.add_child(customer)

	active_customers += 1
	print("[Spawner] 👤 Spawn khách #%d tại (%.0f, %.0f)" % [
		active_customers, sp.global_position.x, sp.global_position.y
	])

func _on_customer_removed() -> void:
	active_customers = maxi(active_customers - 1, 0)

# ─── UPGRADE RESPONSE ─────────────────────────────────────
func _on_upgrade_purchased(_upgrade_id: String) -> void:
	var new_interval: float = GameManager.get_spawn_interval()
	spawn_timer.wait_time = new_interval
	print("[Spawner] ⏱️ Spawn interval: %.1fs" % new_interval)
