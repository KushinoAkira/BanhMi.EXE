## customer.gd — NPC Khách hàng với AI State Machine + Walk Animation
## Gắn vào CharacterBody2D trong scene Customer.tscn
extends CharacterBody2D

# ─── STATES ────────────────────────────────────────────────
enum State {
	IDLE,
	WANDERING,
	GOING_TO_SHOP,
	WAITING_IN_LINE,
	BUYING,
	LEAVING,
}

# ─── NPC TYPES — chỉ dùng ảnh walk frames (8 hình mỗi loại) ──
const NPC_WALK_FOLDERS: Array[Dictionary] = [
	{
		"folder": "res://assets/sprites/npc/npc_office_worker_walk",
		"prefix": "npc_office_worker_walk",
	},
	{
		"folder": "res://assets/sprites/npc/npc_student_walk",
		"prefix": "npc_student_walk",
	},
	{
		"folder": "res://assets/sprites/npc/npc_young_woman_walk",
		"prefix": "npc_young_woman_walk",
	},
	{
		"folder": "res://assets/sprites/npc/npc_elderly_man_walk",
		"prefix": "npc_elderly_man_walk",
	},
]

const NPC_TINTS: Array[Color] = [
	Color(1.0, 1.0, 1.0),
	Color(1.0, 0.92, 0.85),
	Color(0.9, 0.95, 1.0),
	Color(0.95, 1.0, 0.9),
	Color(1.0, 0.9, 0.95),
]

# ─── EXPORTS & VARS ───────────────────────────────────────
@export var speed: float = 80.0
@export var wander_count_before_shop: int = 3

## Distance threshold to consider "arrived" at target
const ARRIVE_DISTANCE := 20.0

var current_state: State = State.IDLE
var wander_points_visited: int = 0
var queue_index: int = -1
var target_position: Vector2 = Vector2.ZERO
var _ready_frames: int = 0
var _has_nav_target: bool = false  ## True after we set a navigation target
var is_vip: bool = false
var patience: float = 30.0
var max_patience: float = 30.0
var tip_chance: float = 0.1
var patience_bar: ColorRect

# References (set bởi Spawner)
var banh_mi_cart: Node2D = null
var wander_points: Array[Marker2D] = []

# ─── ONREADY NODES ────────────────────────────────────────
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D

# ─── READY ─────────────────────────────────────────────────
func _ready() -> void:
	nav_agent.path_desired_distance = 4.0
	nav_agent.target_desired_distance = 12.0
	nav_agent.avoidance_enabled = true
	nav_agent.radius = 10.0
	nav_agent.max_speed = speed

	# Connect navigation_finished signal for reliable detection
	nav_agent.navigation_finished.connect(_on_navigation_finished)

	_randomize_appearance()
	_create_shadow()
	_create_patience_bar()

	wander_count_before_shop = randi_range(2, 4)
	current_state = State.IDLE
	_ready_frames = 0

## Tạo shadow đơn giản dưới chân NPC
func _create_shadow() -> void:
	var shadow_tex = load("res://assets/sprites/props/shadow_blob.png")
	if shadow_tex:
		var shadow_sprite := Sprite2D.new()
		shadow_sprite.texture = shadow_tex
		shadow_sprite.scale = Vector2(0.4, 0.25)
		shadow_sprite.z_index = -1
		shadow_sprite.name = "Shadow"
		add_child(shadow_sprite)

## Tạo thanh hiển thị độ kiên nhẫn
func _create_patience_bar() -> void:
	patience_bar = ColorRect.new()
	patience_bar.size = Vector2(30, 3)
	patience_bar.position = Vector2(-15, -45)
	patience_bar.color = Color.GREEN
	patience_bar.visible = false
	add_child(patience_bar)

## Tạo SpriteFrames dynamically — thiết lập chỉ số theo loại NPC
func _randomize_appearance() -> void:
	var npc_data: Dictionary = NPC_WALK_FOLDERS.pick_random()
	
	match npc_data.prefix:
		"npc_student_walk":
			max_patience = randf_range(15.0, 22.0)
			tip_chance = 0.05
			speed = 95.0
		"npc_office_worker_walk":
			max_patience = randf_range(25.0, 35.0)
			tip_chance = 0.20
			speed = 80.0
		"npc_elderly_man_walk":
			max_patience = randf_range(50.0, 75.0)
			tip_chance = 0.10
			speed = 55.0
		"npc_young_woman_walk":
			max_patience = randf_range(30.0, 45.0)
			tip_chance = 0.15
			speed = 75.0
	
	patience = max_patience

	var sprite_frames := SpriteFrames.new()
	var walk_textures: Array[Texture2D] = []
	for i in range(1, 9):
		var frame_path: String = "%s/%s_%d.png" % [
			npc_data.folder, npc_data.prefix, i
		]
		var frame_tex = load(frame_path)
		if frame_tex:
			walk_textures.append(frame_tex)

	sprite_frames.add_animation("idle")
	sprite_frames.set_animation_speed("idle", 1.0)
	sprite_frames.set_animation_loop("idle", true)
	if walk_textures.size() > 0:
		sprite_frames.add_frame("idle", walk_textures[0])

	sprite_frames.add_animation("walk")
	sprite_frames.set_animation_speed("walk", 10.0)
	sprite_frames.set_animation_loop("walk", true)
	for tex in walk_textures:
		sprite_frames.add_frame("walk", tex)

	anim_sprite.sprite_frames = sprite_frames
	
	is_vip = (randf() < 0.15)
	if is_vip:
		anim_sprite.modulate = Color(1.0, 0.8, 0.2)
		speed *= 1.4
		tip_chance += 0.25
	else:
		anim_sprite.modulate = NPC_TINTS.pick_random()
		speed = speed * randf_range(0.9, 1.1)
		
	anim_sprite.play("idle")

# ─── NAVIGATION FINISHED SIGNAL ──────────────────────────
## Called by NavigationAgent2D when it reaches the target
func _on_navigation_finished() -> void:
	if not _has_nav_target:
		return
	_has_nav_target = false

	match current_state:
		State.WANDERING:
			wander_points_visited += 1
			if wander_points_visited >= wander_count_before_shop and banh_mi_cart != null:
				_change_state(State.GOING_TO_SHOP)
			else:
				# Pick next wander target after a short pause
				_pick_random_wander_target()
		State.GOING_TO_SHOP:
			# Arrived at queue position → start waiting
			_change_state(State.WAITING_IN_LINE)
		State.WAITING_IN_LINE:
			# Arrived at new queue position after advancing
			_play_animation("idle")
		State.LEAVING:
			queue_free()

# ─── PHYSICS PROCESS ──────────────────────────────────────
func _physics_process(delta: float) -> void:
	match current_state:
		State.IDLE:
			_process_idle()
		State.WANDERING, State.GOING_TO_SHOP, State.LEAVING:
			_process_moving()
		State.WAITING_IN_LINE:
			_process_waiting_in_line(delta)
		State.BUYING:
			pass

# ─── IDLE STATE (chờ nav server) ──────────────────────────
func _process_idle() -> void:
	_ready_frames += 1
	if _ready_frames >= 3:
		_change_state(State.WANDERING)

# ─── GENERIC MOVEMENT — used by WANDERING, GOING_TO_SHOP, LEAVING
func _process_moving() -> void:
	if _has_nav_target and not nav_agent.is_navigation_finished():
		_move_along_path()
	elif not _has_nav_target:
		_play_animation("idle")

# ─── WANDERING ───────────────────────────────────────────
func _pick_random_wander_target() -> void:
	if wander_points.is_empty():
		return
	var wp: Marker2D = wander_points.pick_random()
	target_position = wp.global_position
	nav_agent.target_position = target_position
	_has_nav_target = true

# ─── GOING TO SHOP ───────────────────────────────────────
func _request_queue_slot() -> void:
	if banh_mi_cart == null:
		return
	queue_index = banh_mi_cart.join_queue(self)
	if queue_index == -1:
		# Hàng đầy → quay lại wander
		wander_points_visited = 0
		_change_state(State.WANDERING)
		return
	var pos: Vector2 = banh_mi_cart.get_queue_position(queue_index)
	target_position = pos
	nav_agent.target_position = pos
	_has_nav_target = true

# ─── WAITING IN LINE STATE ────────────────────────────────
func _process_waiting_in_line(delta: float) -> void:
	# Update patience
	patience_bar.visible = true
	patience -= delta
	patience_bar.size.x = (patience / max_patience) * 30.0
	patience_bar.color = Color.GREEN.lerp(Color.RED, 1.0 - (patience / max_patience))
	
	if patience <= 0:
		if banh_mi_cart:
			banh_mi_cart.remove_customer(self)
		GameManager.record_customer_lost()
		_change_state(State.LEAVING)
		return

	if _has_nav_target and not nav_agent.is_navigation_finished():
		_move_along_path()
	else:
		_play_animation("idle")

func advance_to_position(new_index: int) -> void:
	queue_index = new_index
	var pos: Vector2 = banh_mi_cart.get_queue_position(new_index)
	target_position = pos
	nav_agent.target_position = pos
	_has_nav_target = true

func start_buying() -> void:
	_change_state(State.BUYING)

func finish_buying() -> void:
	_change_state(State.LEAVING)

# ─── LEAVING STATE ─────────────────────────────────────────
func _pick_leave_target() -> void:
	var exit_positions: Array[Vector2] = [
		Vector2(-120, global_position.y),
		Vector2(1400, global_position.y),
		Vector2(global_position.x, 540),
	]
	target_position = exit_positions.pick_random()
	nav_agent.target_position = target_position
	_has_nav_target = true

# ─── MOVEMENT ─────────────────────────────────────────────
func _move_along_path() -> void:
	if nav_agent.is_navigation_finished():
		velocity = Vector2.ZERO
		_play_animation("idle")
		return

	var next_pos: Vector2 = nav_agent.get_next_path_position()
	var direction: Vector2 = (next_pos - global_position).normalized()
	velocity = direction * speed

	if direction.x < -0.1:
		anim_sprite.flip_h = true
	elif direction.x > 0.1:
		anim_sprite.flip_h = false

	_play_animation("walk")
	move_and_slide()

# ─── ANIMATION HELPER ─────────────────────────────────────
func _play_animation(anim_name: String) -> void:
	if anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation(anim_name):
		if anim_sprite.animation != anim_name:
			anim_sprite.play(anim_name)

# ─── STATE TRANSITION ─────────────────────────────────────
func _change_state(new_state: State) -> void:
	current_state = new_state
	_has_nav_target = false
	velocity = Vector2.ZERO

	match new_state:
		State.WANDERING:
			_pick_random_wander_target()
		State.GOING_TO_SHOP:
			_request_queue_slot()
		State.WAITING_IN_LINE:
			_play_animation("idle")
		State.BUYING:
			_play_animation("idle")
		State.LEAVING:
			_pick_leave_target()
