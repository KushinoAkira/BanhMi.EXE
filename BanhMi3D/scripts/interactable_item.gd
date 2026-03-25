extends StaticBody3D

signal interacted(item_name: String, sender: Node)

@export var item_name: String = "Item"
var mesh_node: MeshInstance3D
var highlight_material: StandardMaterial3D

func _ready():
	# Tìm mesh node cha nếu chưa được gán từ bên ngoài
	if not mesh_node and get_parent() is MeshInstance3D:
		setup_highlight_material(get_parent())

func setup_highlight_material(target_mesh: MeshInstance3D):
	mesh_node = target_mesh
	highlight_material = StandardMaterial3D.new()
	highlight_material.albedo_color = Color(1, 1, 0, 0.2) # Màu vàng nhạt mờ
	highlight_material.emission_enabled = true
	highlight_material.emission = Color(1, 1, 0) # Màu vàng phát sáng
	highlight_material.emission_energy_multiplier = 2.0 # Tăng độ sáng
	highlight_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED # Không bị ảnh hưởng bởi ánh sáng
	highlight_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

func set_highlight(active: bool):
	if mesh_node:
		if active:
			mesh_node.material_overlay = highlight_material
		else:
			mesh_node.material_overlay = null

func interact():
	print(">>> [HÀNH ĐỘNG] Bạn đã tương tác với: ", item_name)
	interacted.emit(item_name, self)
