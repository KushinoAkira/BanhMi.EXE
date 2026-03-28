extends Node

enum CustomerState {
	IDLE,
	ARRIVING,
	WAITING,
	LEAVING
}

@export var spawn_interval_min: float = 5.0
@export var spawn_interval_max: float = 12.0
@export var move_speed: float = 1.8
@export var arrive_distance: float = 0.25
@export var leave_distance: float = 0.4
@export var cart_focus_point: Vector3 = Vector3(25.34, 0.35, 9.11)
@export var turn_speed: float = 8.0
@export var cart_avoid_margin: float = 1.4
@export var cart_detour_padding: float = 1.8

const CUSTOMER_SLOT_ANCHOR_NAMES := ["customer", "customer 2", "customer 3"]
const CUSTOMER_SLOT_POSITIONS_LOCAL := [
	Vector3(30.666512, 0.31222248, 9.165287),
	Vector3(32.814922, 0.31184125, 7.560415),
	Vector3(20.030403, 0.24272776, 8.027645)
]
const SOURCE_NPC_NODE_NAMES := ["Character1", "Character2"]
const NPC_VARIANTS := [
	{
		"source_node": "Character1",
		"scene": preload("res://assets/customer/nathan_animated_003_-_walking_3d_man.glb"),
		"scale": Vector3(0.032, 0.032, 0.032),
		"facing_offset_deg": 180.0,
		"y_offset": 0.0
	},
	{
		"source_node": "Character2",
		"scene": preload("res://assets/customer/trump_walking.glb"),
		"scale": Vector3(2.0, 2.0, 2.0),
		"facing_offset_deg": 180.0,
		"y_offset": 0.0
	}
]

var _spawn_timer: float = 0.0
var _slots: Array = []
var _departing_npcs: Array = []
var _spawn_sequence: int = 0
var _is_spawning: bool = false
var _source_nodes_by_name := {}
var _spawn_points: Array[Vector3] = [
	Vector3(30.5, 0.35, -3.0),
	Vector3(19.8, 0.45, -0.2),
	Vector3(35.0, 0.35, 14.0),
	Vector3(18.0, 0.35, 14.0)
]
var _cart_bounds_valid := false
var _cart_min_x := 0.0
var _cart_max_x := 0.0
var _cart_min_z := 0.0
var _cart_max_z := 0.0
var _customer_arrival_sfx := [
	"res://assets/Sounds/sfx/customer_arrive_01.wav",
	"res://assets/Sounds/sfx/customer_arrive_02.wav"
]

var _cart_manager: Node = null
var _banhmi_manager: Node = null

func _ready():
	randomize()
	_cart_manager = get_tree().get_first_node_in_group("CartManager")
	_banhmi_manager = get_node_or_null("/root/Main/BanhMiManager")

	if _banhmi_manager and _banhmi_manager.has_signal("order_finished"):
		_banhmi_manager.order_finished.connect(_on_order_finished)

	_cache_cart_bounds()
	_setup_customer_slots()
	_reset_spawn_timer()

func _process(delta: float):
	_update_departing_npcs(delta)
	_update_customer_movement(delta)

	if not Global.is_shop_open:
		return

	if _active_customer_count() >= _slots.size():
		return
	if _is_spawning:
		return

	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_one_customer()
		_reset_spawn_timer()

func _setup_customer_slots():
	var env = get_parent() as Node3D
	if env == null:
		return

	_collect_home_points(env)
	var slot_positions_global: Array[Vector3] = []

	for anchor_name in CUSTOMER_SLOT_ANCHOR_NAMES:
		var anchor_node = env.get_node_or_null(anchor_name) as Node3D
		if anchor_node == null:
			continue

		slot_positions_global.append(anchor_node.global_position)

		if _cart_manager and _cart_manager.has_method("remove_customer_registration"):
			_cart_manager.remove_customer_registration(anchor_node)
		if _cart_manager and _cart_manager.has_method("set_customer_interactable"):
			_cart_manager.set_customer_interactable(anchor_node, false)

		anchor_node.queue_free()

	if slot_positions_global.is_empty():
		for slot_local in CUSTOMER_SLOT_POSITIONS_LOCAL:
			slot_positions_global.append(env.to_global(slot_local))

	# Đảm bảo thứ tự hàng chờ: vị trí gần xe bánh mì nhất là đầu hàng.
	var right_positions: Array[Vector3] = []
	var left_positions: Array[Vector3] = []
	for slot_position in slot_positions_global:
		if _get_side_from_position(slot_position) == "right":
			right_positions.append(slot_position)
		else:
			left_positions.append(slot_position)

	right_positions = _order_positions_by_distance_to_cart(right_positions)
	left_positions = _order_positions_by_distance_to_cart(left_positions)

	for slot_position in right_positions:
		var slot_data = {
			"node": null,
			"slot_position": slot_position,
			"side": "right",
			"state": CustomerState.IDLE,
			"customer_name": "",
			"home_target": Vector3.ZERO,
			"leave_target": Vector3.ZERO,
			"path_points": [],
			"path_index": 0
		}
		_slots.append(slot_data)

	for slot_position in left_positions:
		var slot_data = {
			"node": null,
			"slot_position": slot_position,
			"side": "left",
			"state": CustomerState.IDLE,
			"customer_name": "",
			"home_target": Vector3.ZERO,
			"leave_target": Vector3.ZERO,
			"path_points": [],
			"path_index": 0
		}
		_slots.append(slot_data)

func _collect_home_points(env: Node3D):
	_source_nodes_by_name.clear()

	for source_name in SOURCE_NPC_NODE_NAMES:
		var source_node = env.get_node_or_null(source_name) as Node3D
		if source_node == null:
			continue

		_source_nodes_by_name[source_name] = source_node

func _spawn_one_customer():
	_is_spawning = true
	var env = get_parent() as Node3D
	if env == null:
		_is_spawning = false
		return

	var available_variants: Array = []
	for variant in NPC_VARIANTS:
		var source_name = ""
		if variant.has("source_node"):
			source_name = str(variant["source_node"])
		var source_side = _get_source_side(source_name)
		if _find_idle_slot_for_side(source_side) != -1:
			available_variants.append(variant)

	if available_variants.is_empty():
		_is_spawning = false
		return

	var variant = available_variants[randi() % available_variants.size()]
	var variant_source_name = ""
	if variant.has("source_node"):
		variant_source_name = str(variant["source_node"])
	var lane_side = _get_source_side(variant_source_name)
	var slot_index = _find_idle_slot_for_side(lane_side)
	if slot_index == -1:
		_is_spawning = false
		return

	var customer_node = _instantiate_dynamic_customer_from_variant(variant)
	if customer_node == null:
		_is_spawning = false
		return

	env.add_child(customer_node)
	var slot_data = _slots[slot_index]
	var slot_position = slot_data["slot_position"] as Vector3
	var home_target = _pick_home_point(variant_source_name, slot_position.y)
	customer_node.global_position = home_target

	await _ensure_customer_interaction(customer_node)

	if not is_instance_valid(customer_node):
		_is_spawning = false
		return

	var assigned_name = ""
	if _cart_manager and _cart_manager.has_method("assign_customer_to_node"):
		assigned_name = _cart_manager.assign_customer_to_node(customer_node)
	if _cart_manager and _cart_manager.has_method("set_customer_interactable"):
		_cart_manager.set_customer_interactable(customer_node, false)

	slot_data["customer_name"] = assigned_name
	slot_data["node"] = customer_node
	slot_data["home_target"] = home_target
	slot_data["leave_target"] = home_target
	slot_data["path_points"] = _build_path_avoiding_cart(home_target, slot_position)
	slot_data["path_index"] = 0
	slot_data["state"] = CustomerState.ARRIVING
	_slots[slot_index] = slot_data

	_play_walk_animation(customer_node)
	_is_spawning = false
	return

func _update_customer_movement(delta: float):
	for i in range(_slots.size()):
		var slot_data = _slots[i]
		var state = int(slot_data["state"])
		var customer_node = slot_data["node"] as Node3D
		if customer_node == null:
			continue

		if state == CustomerState.ARRIVING:
			var path_points = slot_data["path_points"] as Array
			var path_index = int(slot_data["path_index"])
			if path_points.is_empty():
				var slot_position_fallback = slot_data["slot_position"] as Vector3
				path_points = [slot_position_fallback]
				path_index = 0
				slot_data["path_points"] = path_points
				slot_data["path_index"] = path_index
				_slots[i] = slot_data

			var next_target = path_points[min(path_index, path_points.size() - 1)] as Vector3
			_face_target(customer_node, cart_focus_point, delta)
			if _move_towards(customer_node, next_target, move_speed, arrive_distance, delta):
				slot_data["path_index"] = path_index + 1
				if slot_data["path_index"] >= path_points.size():
					var slot_position = slot_data["slot_position"] as Vector3
					customer_node.global_position = slot_position
					_face_target(customer_node, cart_focus_point, delta, true)
					slot_data["state"] = CustomerState.WAITING
					if _cart_manager and _cart_manager.has_method("set_customer_interactable"):
						_cart_manager.set_customer_interactable(customer_node, true)
					_stop_walk_animation(customer_node)
					_play_customer_arrival_sfx(customer_node)
				_slots[i] = slot_data
		elif state == CustomerState.WAITING:
			_face_target(customer_node, cart_focus_point, delta)

func _start_leave_for_customer(customer_name: String):
	for i in range(_slots.size()):
		var slot_data = _slots[i]
		if slot_data["customer_name"] != customer_name:
			continue

		var customer_node = slot_data["node"] as Node3D
		if customer_node == null:
			continue

		if _cart_manager and _cart_manager.has_method("set_customer_interactable"):
			_cart_manager.set_customer_interactable(customer_node, false)
		if _cart_manager and _cart_manager.has_method("remove_customer_registration"):
			_cart_manager.remove_customer_registration(customer_node)

		var home_target = slot_data["home_target"] as Vector3
		if home_target == Vector3.ZERO:
			var source_name = ""
			if customer_node.has_meta("source_node"):
				source_name = str(customer_node.get_meta("source_node"))
			home_target = _pick_home_point(source_name, customer_node.global_position.y)
		var leave_path = _build_path_avoiding_cart(customer_node.global_position, home_target)
		_enqueue_departure(customer_node, leave_path)

		slot_data["node"] = null
		slot_data["state"] = CustomerState.IDLE
		slot_data["customer_name"] = ""
		slot_data["home_target"] = Vector3.ZERO
		slot_data["leave_target"] = Vector3.ZERO
		slot_data["path_points"] = []
		slot_data["path_index"] = 0
		_slots[i] = slot_data

		_compact_queue_toward_front()
		_spawn_immediate_if_possible()
		return

func _enqueue_departure(customer_node: Node3D, path_points: Array):
	var points = path_points
	if points.is_empty():
		points = [customer_node.global_position]

	_departing_npcs.append({
		"node": customer_node,
		"path_points": points,
		"path_index": 0
	})
	_play_walk_animation(customer_node)

func _update_departing_npcs(delta: float):
	for i in range(_departing_npcs.size() - 1, -1, -1):
		var dep = _departing_npcs[i]
		var node = dep["node"] as Node3D
		if node == null or not is_instance_valid(node):
			_departing_npcs.remove_at(i)
			continue

		var points = dep["path_points"] as Array
		var idx = int(dep["path_index"])
		if points.is_empty():
			_finalize_departure_node(node)
			_departing_npcs.remove_at(i)
			continue

		var step = points[min(idx, points.size() - 1)] as Vector3
		_face_target(node, step, delta)
		if _move_towards(node, step, move_speed, leave_distance, delta):
			idx += 1
			if idx >= points.size():
				_finalize_departure_node(node)
				_departing_npcs.remove_at(i)
			else:
				dep["path_index"] = idx
				_departing_npcs[i] = dep

func _finalize_departure_node(node: Node3D):
	if node and is_instance_valid(node):
		_stop_walk_animation(node)
		node.queue_free()

func _spawn_immediate_if_possible():
	if not Global.is_shop_open:
		return
	if _is_spawning:
		return
	if _active_customer_count() >= _slots.size():
		return

	_spawn_one_customer()
	_reset_spawn_timer()

func _finish_leave(slot_index: int):
	var slot_data = _slots[slot_index]
	var customer_node = slot_data["node"] as Node3D
	if customer_node == null:
		return

	if _cart_manager and _cart_manager.has_method("remove_customer_registration"):
		_cart_manager.remove_customer_registration(customer_node)
	if _cart_manager and _cart_manager.has_method("set_customer_interactable"):
		_cart_manager.set_customer_interactable(customer_node, false)

	customer_node.queue_free()
	_stop_walk_animation(customer_node)

	slot_data["node"] = null
	slot_data["state"] = CustomerState.IDLE
	slot_data["customer_name"] = ""
	slot_data["home_target"] = Vector3.ZERO
	slot_data["leave_target"] = Vector3.ZERO
	slot_data["path_points"] = []
	slot_data["path_index"] = 0
	_slots[slot_index] = slot_data

	_compact_queue_toward_front()

func _compact_queue_toward_front():
	_compact_queue_side("right")
	_compact_queue_side("left")

func _compact_queue_side(side: String):
	var side_indices = _get_slot_indices_for_side(side)
	for k in range(side_indices.size()):
		var idx = side_indices[k]
		if _slots[idx]["node"] != null:
			continue

		var donor_idx = _find_next_occupied_slot_in_indices(side_indices, k + 1)
		if donor_idx == -1:
			break

		_move_slot_occupant(donor_idx, idx)

func _find_next_occupied_slot_in_indices(indices: Array, start_pos: int) -> int:
	for p in range(start_pos, indices.size()):
		var idx = int(indices[p])
		if _slots[idx]["node"] != null:
			return idx
	return -1

func _get_slot_indices_for_side(side: String) -> Array:
	var indices: Array = []
	var distances: Array = []

	for i in range(_slots.size()):
		if _slots[i].get("side", "") != side:
			continue
		indices.append(i)
		distances.append((_slots[i]["slot_position"] as Vector3).distance_to(cart_focus_point))

	# Sắp xếp tăng dần theo khoảng cách tới xe (đầu hàng -> cuối hàng)
	for a in range(indices.size()):
		var best = a
		for b in range(a + 1, indices.size()):
			if float(distances[b]) < float(distances[best]):
				best = b
		if best != a:
			var temp_idx = indices[a]
			indices[a] = indices[best]
			indices[best] = temp_idx

			var temp_dist = distances[a]
			distances[a] = distances[best]
			distances[best] = temp_dist

	return indices

func _find_idle_slot_for_side(side: String) -> int:
	var side_indices = _get_slot_indices_for_side(side)
	for idx in side_indices:
		var i = int(idx)
		if _slots[i]["state"] == CustomerState.IDLE and _slots[i]["node"] == null:
			return i
	return -1

func _order_positions_by_distance_to_cart(positions: Array[Vector3]) -> Array[Vector3]:
	var pool: Array[Vector3] = []
	for p in positions:
		pool.append(p)

	var ordered: Array[Vector3] = []
	while not pool.is_empty():
		var best_idx = 0
		var best_dist = pool[0].distance_to(cart_focus_point)
		for i in range(1, pool.size()):
			var d = pool[i].distance_to(cart_focus_point)
			if d < best_dist:
				best_dist = d
				best_idx = i
		ordered.append(pool[best_idx])
		pool.remove_at(best_idx)
	return ordered

func _get_side_from_position(position: Vector3) -> String:
	return "right" if position.x >= cart_focus_point.x else "left"

func _get_source_side(source_name: String) -> String:
	if source_name != "" and _source_nodes_by_name.has(source_name):
		var source_node = _source_nodes_by_name[source_name] as Node3D
		if is_instance_valid(source_node):
			return _get_side_from_position(source_node.global_position)
	return "right"

func _move_slot_occupant(from_index: int, to_index: int):
	var donor_slot = _slots[from_index]
	var node = donor_slot["node"] as Node3D
	if node == null:
		return

	if _cart_manager and _cart_manager.has_method("set_customer_interactable"):
		_cart_manager.set_customer_interactable(node, false)

	var target_slot = _slots[to_index]
	var target_position = target_slot["slot_position"] as Vector3

	target_slot["node"] = node
	target_slot["customer_name"] = donor_slot["customer_name"]
	target_slot["home_target"] = donor_slot["home_target"]
	target_slot["leave_target"] = donor_slot["leave_target"]
	target_slot["state"] = CustomerState.ARRIVING
	target_slot["path_points"] = _build_path_avoiding_cart(node.global_position, target_position)
	target_slot["path_index"] = 0
	_slots[to_index] = target_slot

	donor_slot["node"] = null
	donor_slot["customer_name"] = ""
	donor_slot["home_target"] = Vector3.ZERO
	donor_slot["leave_target"] = Vector3.ZERO
	donor_slot["state"] = CustomerState.IDLE
	donor_slot["path_points"] = []
	donor_slot["path_index"] = 0
	_slots[from_index] = donor_slot

	_play_walk_animation(node)

func _on_order_finished(customer_name: String):
	_start_leave_for_customer(customer_name)

func _move_towards(node: Node3D, target: Vector3, speed: float, stop_distance: float, delta: float) -> bool:
	var direction = target - node.global_position
	direction.y = 0.0
	var distance = direction.length()
	if distance <= stop_distance:
		return true

	var travel = min(speed * delta, distance)
	node.global_position += direction.normalized() * travel
	return false

func _face_target(node: Node3D, target: Vector3, delta: float, snap: bool = false):
	var flat_target = Vector3(target.x, node.global_position.y, target.z)
	var to_target = flat_target - node.global_position
	to_target.y = 0.0
	if to_target.length_squared() <= 0.0001:
		return

	var desired_transform = node.global_transform.looking_at(flat_target, Vector3.UP)
	var desired_y = desired_transform.basis.get_euler().y + _get_facing_offset_rad(node)
	if snap:
		node.global_rotation.y = desired_y
		return

	var t = clamp(turn_speed * delta, 0.0, 1.0)
	node.global_rotation.y = lerp_angle(node.global_rotation.y, desired_y, t)

func _get_facing_offset_rad(node: Node3D) -> float:
	if node.has_meta("facing_offset_deg"):
		return deg_to_rad(float(node.get_meta("facing_offset_deg")))
	return 0.0

func _pick_spawn_point(target_y: float = 0.35) -> Vector3:
	if _spawn_points.is_empty():
		return Vector3(0, target_y, 0)
	var p = _spawn_points[randi() % _spawn_points.size()]
	p.y = target_y
	return p

func _pick_home_point(source_name: String, target_y: float = 0.35) -> Vector3:
	if source_name != "" and _source_nodes_by_name.has(source_name):
		var source_node = _source_nodes_by_name[source_name] as Node3D
		if is_instance_valid(source_node):
			var p = source_node.global_position
			p.y = target_y
			return p

	if not _source_nodes_by_name.is_empty():
		var first_key = _source_nodes_by_name.keys()[0]
		var fallback_node = _source_nodes_by_name[first_key] as Node3D
		if is_instance_valid(fallback_node):
			var fallback = fallback_node.global_position
			fallback.y = target_y
			return fallback

	return _pick_spawn_point(target_y)

func _cache_cart_bounds():
	_cart_bounds_valid = false
	var env = get_parent() as Node3D
	if env == null:
		return

	var cart_collision = env.get_node_or_null("Collisions/CartCollision") as StaticBody3D
	if cart_collision == null:
		return

	var shape_node = cart_collision.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape_node == null:
		return

	var box = shape_node.shape as BoxShape3D
	if box == null:
		return

	var center = cart_collision.global_position
	var half_x = (box.size.x * 0.5) + cart_avoid_margin
	var half_z = (box.size.z * 0.5) + cart_avoid_margin

	_cart_min_x = center.x - half_x
	_cart_max_x = center.x + half_x
	_cart_min_z = center.z - half_z
	_cart_max_z = center.z + half_z
	_cart_bounds_valid = true

func _build_path_avoiding_cart(start: Vector3, target: Vector3) -> Array:
	if not _cart_bounds_valid:
		return [target]

	var direct_path: Array = [target]
	if _is_path_clear(start, direct_path):
		return direct_path

	var y = target.y
	var left_x = _cart_min_x - cart_detour_padding
	var right_x = _cart_max_x + cart_detour_padding
	var back_z = _cart_min_z - cart_detour_padding
	var front_z = _cart_max_z + cart_detour_padding

	var candidates: Array = [
		[Vector3(left_x, y, start.z), Vector3(left_x, y, target.z), target],
		[Vector3(right_x, y, start.z), Vector3(right_x, y, target.z), target],
		[Vector3(start.x, y, back_z), Vector3(target.x, y, back_z), target],
		[Vector3(start.x, y, front_z), Vector3(target.x, y, front_z), target],
		[Vector3(left_x, y, start.z), Vector3(left_x, y, back_z), Vector3(target.x, y, back_z), target],
		[Vector3(left_x, y, start.z), Vector3(left_x, y, front_z), Vector3(target.x, y, front_z), target],
		[Vector3(right_x, y, start.z), Vector3(right_x, y, back_z), Vector3(target.x, y, back_z), target],
		[Vector3(right_x, y, start.z), Vector3(right_x, y, front_z), Vector3(target.x, y, front_z), target],
		[Vector3(start.x, y, back_z), Vector3(left_x, y, back_z), Vector3(left_x, y, target.z), target],
		[Vector3(start.x, y, back_z), Vector3(right_x, y, back_z), Vector3(right_x, y, target.z), target],
		[Vector3(start.x, y, front_z), Vector3(left_x, y, front_z), Vector3(left_x, y, target.z), target],
		[Vector3(start.x, y, front_z), Vector3(right_x, y, front_z), Vector3(right_x, y, target.z), target]
	]

	var best_path: Array = []
	var best_len = INF
	for candidate in candidates:
		if not _is_path_clear(start, candidate):
			continue

		var candidate_len = _path_length(start, candidate)
		if candidate_len < best_len:
			best_len = candidate_len
			best_path = candidate

	if not best_path.is_empty():
		return _squash_duplicate_points(best_path)

	# Fallback bảo thủ: luôn lách sang một cạnh dọc theo trục X.
	var left_cost = abs(start.x - left_x) + abs(target.x - left_x)
	var right_cost = abs(start.x - right_x) + abs(target.x - right_x)
	var detour_x = left_x if left_cost <= right_cost else right_x
	return [Vector3(detour_x, y, start.z), Vector3(detour_x, y, target.z), target]

func _is_path_clear(start: Vector3, points: Array) -> bool:
	var prev = start
	for p in points:
		var next_p = p as Vector3
		if _segment_intersects_cart(prev, next_p):
			return false
		prev = next_p
	return true

func _path_length(start: Vector3, points: Array) -> float:
	var total = 0.0
	var prev = start
	for p in points:
		var next_p = p as Vector3
		total += prev.distance_to(next_p)
		prev = next_p
	return total

func _squash_duplicate_points(points: Array) -> Array:
	var out: Array = []
	for p in points:
		var v = p as Vector3
		if out.is_empty() or (out[out.size() - 1] as Vector3).distance_to(v) > 0.05:
			out.append(v)
	return out

func _segment_intersects_cart(a: Vector3, b: Vector3) -> bool:
	var p1 = Vector2(a.x, a.z)
	var p2 = Vector2(b.x, b.z)
	return _segment_intersects_aabb_2d(p1, p2, Vector2(_cart_min_x, _cart_min_z), Vector2(_cart_max_x, _cart_max_z))

func _segment_intersects_aabb_2d(a: Vector2, b: Vector2, min_v: Vector2, max_v: Vector2) -> bool:
	var d = b - a
	var t_min = 0.0
	var t_max = 1.0

	for axis in range(2):
		var a_axis = a[axis]
		var d_axis = d[axis]
		var min_axis = min_v[axis]
		var max_axis = max_v[axis]

		if abs(d_axis) < 0.00001:
			if a_axis < min_axis or a_axis > max_axis:
				return false
		else:
			var inv = 1.0 / d_axis
			var t1 = (min_axis - a_axis) * inv
			var t2 = (max_axis - a_axis) * inv
			if t1 > t2:
				var temp = t1
				t1 = t2
				t2 = temp

			t_min = max(t_min, t1)
			t_max = min(t_max, t2)
			if t_min > t_max:
				return false

	return true

func _active_customer_count() -> int:
	var count = 0
	for slot_data in _slots:
		if int(slot_data["state"]) != CustomerState.IDLE:
			count += 1
	return count

func _reset_spawn_timer():
	_spawn_timer = randf_range(spawn_interval_min, spawn_interval_max)

func _instantiate_dynamic_customer_from_variant(variant: Dictionary) -> Node3D:
	if variant.is_empty():
		return null

	var packed_scene = variant["scene"] as PackedScene
	if packed_scene == null:
		return null

	var customer_node = packed_scene.instantiate() as Node3D
	if customer_node == null:
		return null

	customer_node.name = "QueueNPC_%d" % _spawn_sequence
	_spawn_sequence += 1
	customer_node.scale = variant["scale"] as Vector3
	if variant.has("source_node"):
		customer_node.set_meta("source_node", str(variant["source_node"]))
	if variant.has("facing_offset_deg"):
		customer_node.set_meta("facing_offset_deg", float(variant["facing_offset_deg"]))

	return customer_node

func _ensure_customer_interaction(customer_node: Node3D):
	if _cart_manager == null:
		return
	if not _cart_manager.has_method("find_first_mesh"):
		return
	if not _cart_manager.has_method("create_precise_interaction_area"):
		return

	var mesh = _cart_manager.find_first_mesh(customer_node)
	if mesh == null:
		return

	await _cart_manager.create_precise_interaction_area(mesh, "Khách hàng")

func _play_walk_animation(node: Node):
	var anim_player = node.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim_player == null:
		return

	if anim_player.has_animation("Take 001"):
		anim_player.play("Take 001")
		return
	if anim_player.has_animation("mixamo_com"):
		anim_player.play("mixamo_com")
		return

	var animations = anim_player.get_animation_list()
	if animations.size() > 0:
		anim_player.play(animations[0])

func _stop_walk_animation(node: Node):
	var anim_player = node.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim_player:
		anim_player.stop()

func _play_customer_arrival_sfx(customer_node: Node3D):
	if customer_node == null:
		return
	if _customer_arrival_sfx.is_empty():
		return

	var path = _customer_arrival_sfx[randi() % _customer_arrival_sfx.size()]
	var stream = load(path)
	if stream == null:
		return

	var player = AudioStreamPlayer3D.new()
	player.stream = stream
	player.volume_db = -11.0
	player.pitch_scale = randf_range(0.97, 1.03)
	customer_node.add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
