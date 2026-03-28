extends Node

# ===== QUẢN LÝ CHU KỲ NGÀY/ĐÊM & ÁNH SÁNG VẬT LÝ CHÍNH XÁC =====
# AutoLoad: DayNightManager

var _in_night: bool = false
var _night_timer: float = 0.0

# Timer cho thông báo nhắc nhở
var _last_morning_notif_time: float = -100.0
var _last_night_notif_time: float = -100.0

# Tham chiếu đến scene
var _directional_light: DirectionalLight3D = null
var _world_env: WorldEnvironment = null
var _street_lights: Array = []
var _street_light_energies: Dictionary = {} # Light -> Original Energy
var _cart_timer: Label3D = null
var _active_scene: Node = null
var _next_scene_probe_ms: int = 0

# Cấu hình màu sắc bầu trời
const SKY_COLOR_MORNING = Color(0.53, 0.81, 0.98) # Xanh nhạt
const SKY_COLOR_NOON = Color(0.25, 0.55, 0.95)    # Xanh đậm
const SKY_COLOR_AFTERNOON = Color(0.8, 0.5, 0.2)  # Vàng xế
const SKY_COLOR_EVENING = Color(0.9, 0.3, 0.1)    # Cam đỏ hoàng hôn
const SKY_COLOR_NIGHT = Color(0.01, 0.01, 0.05)   # Đêm tối
const SFX_SHOP_OPEN = "res://assets/Sounds/sfx/shop_open_bell.wav"
const SFX_SHOP_CLOSE = "res://assets/Sounds/sfx/shop_close_bell.wav"

func _ready():
	await get_tree().process_frame
	await get_tree().process_frame
	_refresh_scene_nodes_if_needed(true)
	_update_lighting(Global.DAY_START_HOUR)

func _input(event: InputEvent):
	if Global.is_night_summary or Global.is_transition_black: return
	if event is InputEventKey and event.pressed and not event.echo:
		var progress = clamp(Global.day_elapsed / Global.DAY_DURATION, 0.0, 1.0)
		var current_hour = Global.DAY_START_HOUR + (progress * Global.TOTAL_HOURS)
		
		if event.keycode == KEY_O:
			if current_hour >= Global.SHOP_CLOSE_HOUR:
				_show_hud_notification("💤 Nghỉ ngơi đi! Bán thêm cũng không giàu được đâu!", 3.0)
				return
			if not Global.furniture_out:
				Global.furniture_out = true
				Global.is_shop_open = true
				_play_ui_sfx(SFX_SHOP_OPEN, -8.0, 1.0)
				Global.day_changed.emit(true)
				_show_hud_notification("🥖 Đã dọn bàn ghế ra và MỞ QUÁN!")

		elif event.keycode == KEY_C:
			if current_hour < Global.SHOP_CLOSE_HOUR:
				_show_hud_notification("💪 Cố gắng lên bạn, giàu có đang chờ ta!", 3.0)
				return
			if Global.furniture_out:
				Global.furniture_out = false
				Global.is_shop_open = false
				_play_ui_sfx(SFX_SHOP_CLOSE, -9.0, 0.96)
				Global.day_changed.emit(false)
				_show_hud_notification("🌙 Đã dọn dẹp và ĐÓNG CỬA quán.")
				Global.end_day()

func _process(delta: float):
	_refresh_scene_nodes_if_needed()
	if not Global: return
	var time_multiplier = 1.0
	if Global.is_transition_black: time_multiplier = 0.67
		
	Global.day_elapsed += delta * time_multiplier
	var progress = clamp(Global.day_elapsed / Global.DAY_DURATION, 0.0, 1.0)
	var current_hour = Global.DAY_START_HOUR + (progress * Global.TOTAL_HOURS)
	
	_update_clocks(progress)
	_update_lighting(current_hour)

	if Global.is_night_summary:
		_night_timer += delta
		if _night_timer >= Global.NIGHT_DURATION:
			_night_timer = 0.0
			Global.is_night_summary = false
			Global.is_transition_black = true
			var hud = get_tree().get_first_node_in_group("HUD")
			if hud: hud.show_black_screen_quote()
		return

	if Global.is_transition_black:
		if progress >= 1.0:
			Global.start_new_day()
			_reset_player_position()
			_last_morning_notif_time = -100.0
			_last_night_notif_time = -100.0
		return

	if current_hour > 6.5 and not Global.furniture_out:
		if Global.day_elapsed - _last_morning_notif_time > 10.0:
			_last_morning_notif_time = Global.day_elapsed
			Global.money -= 50
			Global.money_changed.emit(Global.money)
			_show_hud_notification("🚨 TRỄ GIỜ MỞ QUÁN! PHẠT 50 VND", 2.5)

	if current_hour >= Global.SHOP_CLOSE_HOUR and Global.furniture_out:
		if not Global.is_overtime:
			Global.is_overtime = true
			_last_night_notif_time = Global.day_elapsed
			Global.money -= 100
			Global.money_changed.emit(Global.money)
			_show_hud_notification("🚨 QUÁ GIỜ ĐÓNG CỬA! PHẠT 100 VND", 5.0)
		elif Global.day_elapsed - _last_night_notif_time > 10.0:
			_last_night_notif_time = Global.day_elapsed
			Global.money -= 50
			Global.money_changed.emit(Global.money)
			_show_hud_notification("🚨 VẪN CHƯA ĐÓNG CỬA! PHẠT THÊM 50 VND", 2.5)

func _update_lighting(hour: float):
	if not _directional_light: return
	
	var energy: float = 0.0
	var rot_x: float = 0.0
	var rot_y: float = -90.0 # Mặc định hướng Đông
	var light_color: Color = Color.WHITE
	var sky_color: Color = SKY_COLOR_NIGHT
	
	# Quỹ đạo vòng cung: 5:00 (Y=-90) -> 12:00 (Y=0) -> 19:00 (Y=90)
	var day_t = clamp((hour - 5.0) / 14.0, 0.0, 1.0)
	rot_y = lerp(-90.0, 90.0, day_t)
	
	if hour >= 5.0 and hour < 8.5: # 5:00 - 8:30: Bình minh
		var t = (hour - 5.0) / 3.5
		energy = lerp(0.05, 1.0, t)
		rot_x = lerp(-2.0, -35.0, t)
		light_color = Color(1.0, 0.7, 0.4).lerp(Color(1.0, 0.9, 0.7), t)
		sky_color = SKY_COLOR_NIGHT.lerp(SKY_COLOR_MORNING, t)
		Global.current_phase = Global.TimePhase.MORNING
		
	elif hour >= 8.5 and hour < 12.0: # 8:30 - 12:00: Lên đỉnh
		var t = (hour - 8.5) / 3.5
		energy = lerp(1.0, 1.8, t)
		rot_x = lerp(-35.0, -90.0, t)
		light_color = Color(1.0, 0.9, 0.7).lerp(Color(1.0, 1.0, 1.0), t)
		sky_color = SKY_COLOR_MORNING.lerp(SKY_COLOR_NOON, t)
		Global.current_phase = Global.TimePhase.AFTERNOON
		
	elif hour >= 12.0 and hour < 16.5: # 12:00 - 16:30: Xuống dần (Nắng xế)
		var t = (hour - 12.0) / 4.5
		energy = lerp(1.8, 0.7, t) # Hạ thấp energy dần
		rot_x = lerp(-90.0, -30.0, t)
		light_color = Color(1.0, 1.0, 1.0).lerp(Color(1.0, 0.8, 0.4), t) # Ngả vàng
		sky_color = SKY_COLOR_NOON.lerp(SKY_COLOR_AFTERNOON, t)
		Global.current_phase = Global.TimePhase.AFTERNOON
		
	elif hour >= 16.5 and hour < 19.0: # 16:30 - 19:00: Hoàng hôn (Ánh sáng thấp)
		var t = (hour - 16.5) / 2.5
		energy = lerp(0.7, 0.0, t) # Xuống gần như thấp
		rot_x = lerp(-30.0, 2.0, t)
		light_color = Color(1.0, 0.6, 0.2).lerp(Color(0.3, 0.1, 0.05), t) # Đỏ thẫm dần
		sky_color = SKY_COLOR_AFTERNOON.lerp(SKY_COLOR_EVENING, t)
		if hour > 18.5: sky_color = SKY_COLOR_EVENING.lerp(SKY_COLOR_NIGHT, (hour-18.5)/0.5)
		Global.current_phase = Global.TimePhase.EVENING
		
	else: # 19:00 - 5:00: Tối hoàn toàn
		energy = 0.0
		rot_x = 10.0 # Dưới chân trời
		sky_color = SKY_COLOR_NIGHT
		Global.current_phase = Global.TimePhase.NIGHT

	# Áp dụng
	_directional_light.light_energy = energy
	_directional_light.rotation_degrees.x = rot_x
	_directional_light.rotation_degrees.y = rot_y
	_directional_light.light_color = light_color
	
	if _world_env and _world_env.environment:
		var mat = _world_env.environment.sky.sky_material as ProceduralSkyMaterial
		if mat:
			mat.sky_top_color = sky_color
			mat.sky_horizon_color = sky_color.lightened(0.1)
			mat.ground_horizon_color = sky_color.darkened(0.1)

	# --- Logic đèn đường (Street Lights) với hiệu ứng fade ---
	var street_light_factor = 0.0
	var h = hour
	if h >= 24.0: h -= 24.0 # Đưa về dải 0-24
	
	if h >= 18.0 and h < 19.0: # 18h - 19h: Sáng dần
		street_light_factor = (h - 18.0) / 1.0
	elif h >= 19.0 or h < 5.0: # 19h - 5h: Sáng tối đa
		street_light_factor = 1.0
	elif h >= 5.0 and h < 6.0: # 5h - 6h: Tắt dần
		street_light_factor = 1.0 - (h - 5.0) / 1.0
	else:
		street_light_factor = 0.0
		
	_set_street_lights_energy(street_light_factor)

func _update_clocks(progress: float):
	var current_total_hours = Global.DAY_START_HOUR + (progress * Global.TOTAL_HOURS)
	var hour = int(current_total_hours) % 24
	var minute = int((current_total_hours - int(current_total_hours)) * 60.0)
	if _cart_timer:
		_cart_timer.text = "%02d:%02d" % [hour, minute]
		if hour >= 18 or hour < 6: _cart_timer.modulate = Color(2.5, 1.5, 0.5)
		else: _cart_timer.modulate = Color(1.2, 0.9, 0.2)

func _find_scene_nodes():
	var env_node = get_tree().get_first_node_in_group("environment")
	if not env_node: env_node = get_tree().root.find_child("Environment", true, false)
	if env_node:
		_directional_light = env_node.find_child("DirectionalLight3D", true, false)
		_world_env = env_node.find_child("WorldEnvironment", true, false)
		var cart_node = env_node.find_child("cart", true, false)
		if cart_node and not _cart_timer:
			_cart_timer = Label3D.new()
			cart_node.add_child(_cart_timer)
			_cart_timer.text = "05:00"; _cart_timer.font_size = 20; _cart_timer.outline_size = 6
			_cart_timer.position = Vector3(0, 0.8, 0.5); _cart_timer.modulate = Color(1, 0.8, 0.2)
		
		_street_lights.clear()
		_street_light_energies.clear()
		for child in env_node.get_children():
			if child is OmniLight3D or child is SpotLight3D: 
				_street_lights.append(child)
				_street_light_energies[child] = child.light_energy

func _refresh_scene_nodes_if_needed(force: bool = false):
	var current_scene = get_tree().current_scene
	var same_scene = current_scene == _active_scene

	if same_scene and is_instance_valid(_directional_light) and not force:
		return

	if same_scene and not force:
		var now_ms = Time.get_ticks_msec()
		if now_ms < _next_scene_probe_ms:
			return
		_next_scene_probe_ms = now_ms + 500
	else:
		_next_scene_probe_ms = 0

	_active_scene = current_scene
	_directional_light = null
	_world_env = null
	_cart_timer = null
	_street_lights.clear()
	_street_light_energies.clear()
	_find_scene_nodes()

func _set_street_lights_energy(factor: float):
	for light in _street_lights:
		var original_energy = _street_light_energies.get(light, 1.0)
		light.light_energy = original_energy * factor
		light.visible = factor > 0.001

func _reset_player_position():
	var player = get_tree().root.find_child("Player", true, false)
	if player:
		player.global_position = Vector3(25.0, 1.0, 10.5)
		player.rotation_degrees = Vector3(0, 90, 0)

func _show_hud_notification(text: String, duration: float = 2.5):
	var hud = get_tree().get_first_node_in_group("HUD")
	if hud and hud.has_method("show_notification"): hud.show_notification(text, duration)

func _play_ui_sfx(path: String, volume_db: float = -8.0, pitch: float = 1.0):
	var stream = load(path)
	if stream == null:
		return

	var player = AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	get_tree().root.add_child(player)
	player.play()
	player.finished.connect(player.queue_free)

func get_day_progress() -> float:
	return clamp(Global.day_elapsed / Global.DAY_DURATION, 0.0, 1.0)
