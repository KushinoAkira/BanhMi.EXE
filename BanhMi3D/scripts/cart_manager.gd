extends Node3D

# Danh sách tên khách hàng
const CUSTOMER_NAMES = ["Khoa", "Hiếu", "Hoàng", "Phương", "Huyền", "Nam", "Lan", "Tuấn", "Linh", "Đức"]

# Mapping các món đồ trong xe
var item_map = {
	"g33": "Sữa đặc", "g34": "Sữa đặc", "g35": "Sữa đặc", "g36": "Sữa đặc", "g37": "Sữa đặc",
	"g40": "Sữa đặc", "g41": "Sữa đặc", "g42": "Sữa đặc", "g51": "Sữa đặc", "g53": "Sữa đặc",
	"g54": "Sữa đặc", "g55": "Sữa đặc", "g56": "Sữa đặc", "g59": "Sữa đặc",
	
	"g52": "Cái thớt", "g60": "Con dao",
	"g61": "Phô mai", "g62": "Phô mai", "g63": "Phô mai", "g64": "Phô mai", "g65": "Phô mai",
	"g66": "Phô mai", "g69": "Phô mai", "g70": "Phô mai", "g71": "Phô mai",
	
	"g67": "Tô pate", "g57": "Tô đồ chua", "g58": "Tô rau thơm",
	"g68": "Dĩa thịt nguội", "g72": "Dĩa chả lụa", "g73": "Dĩa thịt nướng", "g74": "Dĩa trứng ốp la",
	
	"g75": "Dưa leo lát", "g76": "Dưa leo lát", "g77": "Dưa leo lát", 
	"g79": "Dưa leo lát", "g80": "Dưa leo lát", "g78": "Dưa leo nguyên trái"
}

# Mapping các vật phẩm đặt tay bên ngoài
var manual_items_map = {
	"banh_mi": "Bánh mì",
	"to_nuoc_thit": "Tô nước thịt",
	"to_xi_dau": "Tô xì dầu",
	"to_sua": "Tô sữa",
	"trung_op_la": "Dĩa trứng ốp la",
	"hop_pate": "Hộp pate",
	"pate": "Tô pate",
	"rau_thom": "Tô rau thơm",
	"do_chua": "Tô đồ chua",
	"thit_nguoi": "Dĩa thịt nguội",
	"thit_nuong": "Dĩa thịt nướng",
	"cha_lua": "Dĩa chả lụa"
}

var assigned_names = []
var customer_nodes = {} # { name: Node3D }
var customer_names_by_node = {} # { Node3D: String }

func _ready():
	add_to_group("CartManager")
	await get_tree().process_frame
	setup_interactions(self)
	setup_manual_items()
	
	# Kết nối signal để ẩn/hiện khách theo trạng thái mở quán
	Global.day_changed.connect(_on_shop_status_changed)
	# Trạng thái ban đầu
	_on_shop_status_changed(Global.is_shop_open)

func _on_shop_status_changed(_is_open: bool):
	# Khách hàng luôn hiển thị, không ẩn đi nữa
	pass

func find_interaction_collider(node: Node) -> CollisionShape3D:
	if node is CollisionShape3D: return node
	for child in node.get_children():
		var res = find_interaction_collider(child)
		if res: return res
	return null

func set_waiting_indicator(customer_name: String, is_waiting: bool):
	if customer_nodes.has(customer_name):
		var node = customer_nodes[customer_name]
		var alert = node.get_node_or_null("AlertLabel")
		if alert:
			alert.visible = is_waiting

func is_customer_name(customer_name: String) -> bool:
	return customer_nodes.has(customer_name)

func get_customer_name_for_node(customer_node: Node3D) -> String:
	if customer_names_by_node.has(customer_node):
		return customer_names_by_node[customer_node]
	return ""

func assign_customer_to_node(customer_node: Node3D, preferred_name: String = "") -> String:
	if customer_node == null:
		return ""

	var chosen_name = preferred_name.strip_edges()
	if chosen_name != "":
		var existing_node = customer_nodes.get(chosen_name, null)
		if existing_node != null and existing_node != customer_node:
			chosen_name = ""

	if chosen_name == "":
		chosen_name = get_random_customer_name()

	add_customer_ui(customer_node, chosen_name)
	var interaction_body = find_customer_interaction_body(customer_node)
	if interaction_body:
		interaction_body.item_name = chosen_name
	return chosen_name

func remove_customer_registration(customer_node: Node3D):
	if customer_node == null:
		return

	var old_name = get_customer_name_for_node(customer_node)
	if old_name != "":
		if customer_nodes.get(old_name, null) == customer_node:
			customer_nodes.erase(old_name)
		assigned_names.erase(old_name)

	customer_names_by_node.erase(customer_node)
	set_customer_interactable(customer_node, false)

	var alert = customer_node.get_node_or_null("AlertLabel")
	if alert:
		alert.visible = false

func set_customer_interactable(customer_node: Node3D, enabled: bool):
	var interaction_body = find_customer_interaction_body(customer_node)
	if interaction_body:
		interaction_body.set_collision_layer_value(2, enabled)

func find_customer_interaction_body(node: Node) -> StaticBody3D:
	if node is StaticBody3D and node.get_script() != null:
		if node.get_script().resource_path == "res://scripts/interactable_item.gd":
			return node

	for child in node.get_children():
		var found = find_customer_interaction_body(child)
		if found:
			return found

	return null

func setup_manual_items():
	var environment = get_parent()
	if environment:
		for child in environment.get_children():
			var display_name = ""
			
			# Kiểm tra xem có phải khách hàng không
			if child.name.contains("customer"):
				display_name = get_random_customer_name()
				add_customer_ui(child, display_name)
			else:
				for key in manual_items_map.keys():
					if child.name.contains(key):
						display_name = manual_items_map[key]
						break
			
			if display_name != "":
				var mesh = find_first_mesh(child)
				if mesh:
					create_precise_interaction_area(mesh, display_name, display_name.contains("Tô"))

func add_customer_ui(customer_node: Node3D, customer_name: String):
	var old_name = get_customer_name_for_node(customer_node)
	if old_name != "" and old_name != customer_name:
		if customer_nodes.get(old_name, null) == customer_node:
			customer_nodes.erase(old_name)
		assigned_names.erase(old_name)

	customer_nodes[customer_name] = customer_node
	customer_names_by_node[customer_node] = customer_name
	if not assigned_names.has(customer_name):
		assigned_names.append(customer_name)

	# Thêm Nhãn tên
	var name_label = customer_node.get_node_or_null("NameLabel") as Label3D
	if name_label == null:
		name_label = Label3D.new()
		name_label.font_size = 12 # Cực nhỏ
		name_label.outline_size = 4
		name_label.billboard = StandardMaterial3D.BILLBOARD_ENABLED
		name_label.position = Vector3(0, 1.3, 0) # Thấp hẳn xuống
		name_label.name = "NameLabel"
		customer_node.add_child(name_label)
	name_label.text = customer_name
	
	# Thêm Dấu chấm than (thông báo chờ)
	var alert_label = customer_node.get_node_or_null("AlertLabel") as Label3D
	if alert_label == null:
		alert_label = Label3D.new()
		alert_label.text = "!"
		alert_label.font_size = 24 # Nhỏ hơn
		alert_label.modulate = Color.RED
		alert_label.outline_size = 8
		alert_label.billboard = StandardMaterial3D.BILLBOARD_ENABLED
		alert_label.position = Vector3(0, 1.55, 0) # Thấp hơn
		alert_label.name = "AlertLabel"
		alert_label.visible = false # Mặc định ẩn
		customer_node.add_child(alert_label)

		# Hiệu ứng di chuyển lên xuống cho dấu chấm than (Bobbing)
		var tween = customer_node.get_tree().create_tween().set_loops()
		tween.tween_property(alert_label, "position:y", 1.65, 0.6).set_trans(Tween.TRANS_SINE)
		tween.tween_property(alert_label, "position:y", 1.55, 0.6).set_trans(Tween.TRANS_SINE)

func get_random_customer_name() -> String:
	var available_names = []
	for n in CUSTOMER_NAMES:
		if not n in assigned_names:
			available_names.append(n)
	
	if available_names.size() == 0:
		assigned_names.clear()
		available_names = CUSTOMER_NAMES.duplicate()
	
	var picked = available_names[randi() % available_names.size()]
	if not assigned_names.has(picked):
		assigned_names.append(picked)
	return picked

func setup_interactions(node):
	for child in node.get_children():
		var item_name_found = ""
		for key in item_map.keys():
			if child.name == key or child.name.contains(key + "_"):
				item_name_found = item_map[key]
				break
		
		if item_name_found != "" and child is MeshInstance3D:
			create_precise_interaction_area(child, item_name_found)
		
		if child.get_child_count() > 0:
			setup_interactions(child)

func find_first_mesh(node):
	if node is MeshInstance3D: return node
	for child in node.get_children():
		var res = find_first_mesh(child)
		if res: return res
	return null

func create_precise_interaction_area(mesh_node: MeshInstance3D, item_name: String, is_complex: bool = false):
	for c in mesh_node.get_children():
		if c is StaticBody3D: c.queue_free()
	
	if is_complex:
		mesh_node.create_trimesh_collision()
	else:
		mesh_node.create_convex_collision()
	
	await get_tree().process_frame
	
	var static_body = null
	for i in range(mesh_node.get_child_count() - 1, -1, -1):
		if mesh_node.get_child(i) is StaticBody3D:
			static_body = mesh_node.get_child(i)
			break
	
	if static_body:
		static_body.name = "Interaction_" + mesh_node.name
		static_body.set_script(load("res://scripts/interactable_item.gd"))
		static_body.item_name = item_name
		static_body.set_collision_layer_value(1, false)
		static_body.set_collision_layer_value(2, true)
		static_body.set_collision_mask_value(1, false)
		
		if static_body.has_method("setup_highlight_material"):
			static_body.setup_highlight_material(mesh_node)
		print(">>> Đã kích hoạt [Layer 2] cho: ", item_name)
