extends Node

# ===== QUẢN LÝ CHU KỲ NGÀY/ĐÊM =====
# AutoLoad: DayNightManager

var _time_elapsed: float = 0.0
var _in_night: bool = false
var _night_timer: float = 0.0

# Tham chiếu đến scene (gán runtime)
var _directional_light: DirectionalLight3D = null
var _world_env: WorldEnvironment = null
var _street_lights: Array = []

# Màu ánh sáng theo pha
const PHASE_COLORS = {
	0: Color(1.0, 0.95, 0.8, 1),   # MORNING: vàng ấm
	1: Color(1.0, 1.0, 1.0, 1),    # AFTERNOON: trắng sáng
	2: Color(1.0, 0.6, 0.3, 1),    # EVENING: cam đỏ
	3: Color(0.05, 0.05, 0.15, 1), # NIGHT: xanh đậm tối
}

const PHASE_ENERGY = {
	0: 1.2,  # MORNING
	1: 1.8,  # AFTERNOON
	2: 0.8,  # EVENING
	3: 0.05, # NIGHT
}

# Góc DirectionalLight3D (rotation_degrees.x) theo pha
const PHASE_LIGHT_ANGLE = {
	0: -45.0,  # MORNING: thấp từ đông
	1: -75.0,  # AFTERNOON: cao trên đỉnh
	2: -20.0,  # EVENING: thấp từ tây
	3: -90.0,  # NIGHT: dưới horizon
}

# Sky colors
const SKY_COLORS = {
	0: Color(0.53, 0.81, 0.98),   # MORNING: xanh nhạt
	1: Color(0.25, 0.55, 0.95),   # AFTERNOON: xanh đậm
	2: Color(0.9, 0.45, 0.15),    # EVENING: cam
	3: Color(0.03, 0.03, 0.1),    # NIGHT: xanh đêm
}

func _ready():
	# Chờ scene load xong
	await get_tree().process_frame
	await get_tree().process_frame
	_find_scene_nodes()
	_apply_phase(Global.current_phase)

func _process(delta: float):
	if not Global:
		return

	if Global.is_night_summary:
		# Đang hiện bảng tổng kết — chờ player bấm "Ngày mới"
		return

	if _in_night:
		# Pha đêm — đếm ngược rồi tự chuyển
		_night_timer += delta
		if _night_timer >= Global.NIGHT_DURATION:
			_night_timer = 0.0
			_in_night = false
			Global.start_new_day()
			_apply_phase(Global.TimePhase.MORNING)
		return

	# Đang là ngày
	Global.day_elapsed += delta
	var progress = clamp(Global.day_elapsed / Global.DAY_DURATION, 0.0, 1.0)

	# Xác định pha hiện tại
	var new_phase = _get_phase_from_progress(progress)
	if new_phase != Global.current_phase:
		Global.current_phase = new_phase
		Global.time_phase_changed.emit(new_phase)
		_apply_phase(new_phase)

		# Chiều tối → bật đèn đường
		if new_phase == Global.TimePhase.EVENING:
			_set_street_lights(true)

	# Kết thúc ngày
	if progress >= 1.0:
		_in_night = true
		Global.current_phase = Global.TimePhase.NIGHT
		Global.time_phase_changed.emit(Global.TimePhase.NIGHT)
		_apply_phase(Global.TimePhase.NIGHT)
		Global.end_day()

func _get_phase_from_progress(p: float) -> int:
	if p < Global.MORNING_RATIO:
		return Global.TimePhase.MORNING
	elif p < Global.MORNING_RATIO + Global.AFTERNOON_RATIO:
		return Global.TimePhase.AFTERNOON
	else:
		return Global.TimePhase.EVENING

func _find_scene_nodes():
	var env_node = get_tree().get_first_node_in_group("environment")
	if not env_node:
		# Tìm theo path thông thường
		env_node = get_tree().root.find_child("Environment", true, false)
	if env_node:
		_directional_light = env_node.find_child("DirectionalLight3D", true, false) as DirectionalLight3D
		_world_env = env_node.find_child("WorldEnvironment", true, false) as WorldEnvironment
		# Tìm đèn đường
		for child in env_node.get_children():
			if child is OmniLight3D or child is SpotLight3D:
				_street_lights.append(child)
		# Tắt đèn mặc định
		_set_street_lights(false)

func _apply_phase(phase: int):
	if _directional_light:
		var tween = get_tree().create_tween()
		tween.set_parallel(true)
		tween.tween_property(_directional_light, "light_color", PHASE_COLORS[phase], 3.0)
		tween.tween_property(_directional_light, "light_energy", PHASE_ENERGY[phase], 3.0)
		tween.tween_property(_directional_light, "rotation_degrees:x", PHASE_LIGHT_ANGLE[phase], 3.0)

	if _world_env and _world_env.environment:
		var env = _world_env.environment
		if env.sky and env.sky.sky_material is ProceduralSkyMaterial:
			var mat = env.sky.sky_material as ProceduralSkyMaterial
			var tween2 = get_tree().create_tween()
			tween2.set_parallel(true)
			tween2.tween_property(mat, "sky_top_color", SKY_COLORS[phase], 3.0)
			tween2.tween_property(mat, "sky_horizon_color", SKY_COLORS[phase].lightened(0.2), 3.0)
			tween2.tween_property(mat, "ground_horizon_color", SKY_COLORS[phase].darkened(0.2), 3.0)

func _set_street_lights(on: bool):
	for light in _street_lights:
		if light is OmniLight3D or light is SpotLight3D:
			light.visible = on

func get_day_progress() -> float:
	if Global.is_night_summary:
		return 1.0
	return clamp(Global.day_elapsed / Global.DAY_DURATION, 0.0, 1.0)
