extends Node

# ===== HỆ THỐNG MƯA =====
# AutoLoad: RainSystem
# Tạo GPUParticles3D gắn vào camera player

var _particles: GPUParticles3D = null
var _overlay: ColorRect = null
var _rain_canvas: CanvasLayer = null
var _initialized: bool = false

func _ready():
	Global.weather_changed.connect(_on_weather_changed)
	Global.new_day_started.connect(_on_new_day)
	await get_tree().process_frame
	await get_tree().process_frame
	_setup_rain()
	# Áp dụng thời tiết hiện tại
	_on_weather_changed(Global.is_raining)

func _setup_rain():
	# Canvas overlay mờ khi mưa
	_rain_canvas = CanvasLayer.new()
	_rain_canvas.layer = 5
	add_child(_rain_canvas)

	# Overlay tối mờ
	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(0.05, 0.07, 0.15, 0.0)
	_rain_canvas.add_child(_overlay)

	# Tìm camera để gắn particles
	var camera = get_tree().root.find_child("Camera3D", true, false) as Camera3D
	if not camera:
		# Thử tìm player
		var player = get_tree().root.find_child("Player", true, false)
		if player:
			camera = player.find_child("Camera3D", true, false) as Camera3D

	if camera:
		_particles = GPUParticles3D.new()
		camera.add_child(_particles)
		_setup_particle_params()
		_initialized = true

func _setup_particle_params():
	if not _particles:
		return
	
	_particles.amount = 800
	_particles.lifetime = 1.2
	_particles.preprocess = 0.5
	_particles.emitting = false
	_particles.transform = Transform3D.IDENTITY
	_particles.transform.origin = Vector3(0, 5, -5)
	_particles.visibility_aabb = AABB(Vector3(-20, -20, -20), Vector3(40, 40, 40))

	var pm = ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(15, 0.1, 15)
	pm.direction = Vector3(0.1, -1, 0)
	pm.spread = 5.0
	pm.gravity = Vector3(0, -18, 0)
	pm.initial_velocity_min = 8.0
	pm.initial_velocity_max = 12.0
	pm.scale_min = 0.03
	pm.scale_max = 0.06
	pm.color = Color(0.7, 0.85, 1.0, 0.6)

	_particles.process_material = pm

	# Mesh cho hạt mưa (capsule dài)
	var mesh_inst = MeshInstance3D.new()
	var cap = CapsuleMesh.new()
	cap.radius = 0.015
	cap.height = 0.25
	_particles.draw_pass_1 = cap

func _on_weather_changed(raining: bool):
	if _particles:
		_particles.emitting = raining
	if _overlay:
		var tween = get_tree().create_tween()
		tween.tween_property(_overlay, "color:a", 0.3 if raining else 0.0, 2.0)

func _on_new_day(_day_num: int):
	# Thời tiết đã được set trong Global.start_new_day(), chỉ áp dụng lại
	_on_weather_changed(Global.is_raining)
