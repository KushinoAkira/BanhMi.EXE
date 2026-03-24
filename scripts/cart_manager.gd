extends Node3D

# Mapping các món đồ trong xe (Dùng cho các món có sẵn trong file GLTF của xe)
var item_map = {
	"g33": "Sữa đặc", "g34": "Sữa đặc", "g35": "Sữa đặc", "g36": "Sữa đặc", "g37": "Sữa đặc",
	"g40": "Sữa đặc", "g41": "Sữa đặc", "g42": "Sữa đặc", "g51": "Sữa đặc", "g53": "Sữa đặc",
	"g54": "Sữa đặc", "g55": "Sữa đặc", "g56": "Sữa đặc", "g59": "Sữa đặc",
	
	"g52": "Cái thớt", "g60": "Con dao",
	"g61": "Phô mai", "g62": "Phô mai", "g63": "Phô mai", "g64": "Phô mai", "g65": "Phô mai",
	"g66": "Phô mai", "g69": "Phô mai", "g70": "Phô mai", "g71": "Phô mai",
	
	"g67": "Tô Pate", "g57": "Tô đồ chua", "g58": "Tô rau thơm",
	"g68": "Dĩa thịt nguội", "g72": "Dĩa chả lụa", "g73": "Dĩa thịt nướng", "g74": "Dĩa trứng ốp la",
	
	"g75": "Dưa leo lát", "g76": "Dưa leo lát", "g77": "Dưa leo lát", 
	"g79": "Dưa leo lát", "g80": "Dưa leo lát", "g78": "Dưa leo nguyên trái"
}

# Mapping các vật phẩm đặt tay bên ngoài
var manual_items_map = {
	"banh_mi": "Bánh mì",
	"to_nuoc_thit": "Tô nước thịt",
	"to_xi_dau": "Tô xì dầu"
}

func _ready():
	await get_tree().process_frame
	
	# 1. Quét các món đồ bên trong xe (con của node cart)
	setup_interactions(self)
	
	# 2. Quét các vật phẩm bạn tự đặt bên ngoài (trong node Environment)
	setup_manual_items()

func setup_manual_items():
	var environment = get_parent()
	if environment:
		for child in environment.get_children():
			var display_name = ""
			for key in manual_items_map.keys():
				if child.name.contains(key): # Dùng contains để linh hoạt
					display_name = manual_items_map[key]
					break
			
			if display_name != "":
				var mesh = find_first_mesh(child)
				if mesh:
					# Với cái tô, ta ưu tiên dùng trimesh để va chạm rỗng chính xác lòng tô
					create_precise_interaction_area(mesh, display_name, display_name.contains("Tô"))

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
	# Xóa các va chạm cũ nếu có để tránh trùng lặp
	for c in mesh_node.get_children():
		if c is StaticBody3D: c.queue_free()
	
	# Tạo va chạm
	if is_complex:
		mesh_node.create_trimesh_collision()
	else:
		mesh_node.create_convex_collision()
	
	# Đợi 1 frame để Godot hoàn tất việc tạo node collision
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
		
		# QUAN TRỌNG: Đặt vào Layer 2 (bit 1)
		static_body.set_collision_layer_value(1, false) # Tắt Layer 1
		static_body.set_collision_layer_value(2, true)  # Bật Layer 2
		static_body.set_collision_mask_value(1, false)  # Không va chạm với gì cả
		
		if static_body.has_method("setup_highlight_material"):
			static_body.setup_highlight_material(mesh_node)
		print(">>> Đã kích hoạt [Layer 2] cho: ", item_name, " (Node: ", mesh_node.name, ")")
