extends Node

var furniture_scene = load("res://assets/vietnamese_bamboo_furniture/scene.gltf")
var active_furnitures = []
var current_env = null

var spawn_points = [
	Vector3(29.4, 0.75, 4.9),
	Vector3(23.0, 0.75, 4.9),
	Vector3(16.5, 0.75, 4.9),
	Vector3(10.0, 0.75, 4.9),
	Vector3(3.5,  0.75, 4.9),
	Vector3(29.4, 0.75, -1.0),
	Vector3(23.0, 0.75, -1.0),
	Vector3(16.5, 0.75, -1.0),
	Vector3(10.0, 0.75, -1.0),
	Vector3(3.5,  0.75, -1.0)
]

func _ready():
	Global.day_changed.connect(_on_day_changed)
	Global.furniture_purchased.connect(_on_furniture_purchased)

func _process(delta):
	var main_scene = get_tree().root.get_node_or_null("Main")
	if main_scene:
		var env = main_scene.get_node_or_null("Environment")
		if env and env != current_env:
			current_env = env
			init_scene()

func init_scene():
	if not current_env: return
	
	# Xóa bàn ghế cứng cũ
	var f1 = current_env.get_node_or_null("furniture1")
	if f1: f1.queue_free()
	var f2 = current_env.get_node_or_null("furniture2")
	if f2: f2.queue_free()
	var c1 = current_env.get_node_or_null("Collisions/Furniture1Collision")
	if c1: c1.queue_free()
	var c2 = current_env.get_node_or_null("Collisions/Furniture2Collision")
	if c2: c2.queue_free()
	
	_update_furniture_spawn()

func _on_day_changed(is_day_now):
	_update_furniture_spawn()

func _on_furniture_purchased(count):
	if Global.is_day:
		_update_furniture_spawn()

func clear_furnitures():
	for f in active_furnitures:
		if is_instance_valid(f):
			f.queue_free()
	active_furnitures.clear()

func _update_furniture_spawn():
	clear_furnitures()
	if not Global.is_day: return
	if not is_instance_valid(current_env): return
	
	for i in range(min(Global.furniture_count, spawn_points.size())):
		var inst = furniture_scene.instantiate()
		inst.position = spawn_points[i]
		inst.scale = Vector3(0.14, 0.14, 0.14)
		current_env.add_child(inst)
		active_furnitures.append(inst)
		
		var cols = current_env.get_node_or_null("Collisions")
		if cols:
			var sb = StaticBody3D.new()
			sb.position = spawn_points[i]
			var cs = CollisionShape3D.new()
			var box = BoxShape3D.new()
			box.size = Vector3(2.5, 1.5, 2.5)
			cs.shape = box
			sb.add_child(cs)
			cols.add_child(sb)
			active_furnitures.append(sb)
