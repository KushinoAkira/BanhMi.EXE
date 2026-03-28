extends Node

# ===== QUẢN LÝ CHU KỲ NGÀY/ĐÊM & ÁNH SÁNG =====
# AutoLoad: DayNightManager

var _in_night: bool = false
var _night_timer: float = 0.0

# Timer cho thông báo nhắc nhở
var _last_morning_notif_time: float = -100.0
var _last_night_notif_time: float = -100.0

# Tham chiếu đến scene
var _directional_light: DirectionalLight3D = null
var _world_env: WorldEnvironment = null
var _cart_timer: Label3D = null

# Danh sách đèn (Nếu bạn tự thêm thủ công vào scene)
var _managed_lights: Array = []
var _light_max_energies: Dictionary = {}

const SKY_COLOR_MORNING = Color(0.53, 0.81, 0.98)
const SKY_COLOR_NOON = Color(0.25, 0.55, 0.95)
const SKY_COLOR_AFTERNOON = Color(0.8, 0.5, 0.2)
const SKY_COLOR_EVENING = Color(0.9, 0.3, 0.1)
const SKY_COLOR_NIGHT = Color(0.01, 0.01, 0.05)

func _ready():
	await get_tree().create_timer(1.0).timeout 
	_find_scene_nodes()
	_update_lighting(Global.DAY_START_HOUR)

func _input(event: InputEvent):
	if Global.is_night_summary or Global.is_transition_black: return
	if event is InputEventKey and event.pressed and not event.echo:
		var progress = clamp(Global.day_elapsed / Global.DAY_DURATION, 0.0, 1.0)
		var current_hour = Global.DAY_START_HOUR + (progress * Global.TOTAL_HOURS)
		
		if event.keycode == KEY_O:
			if current_hour >= Global.SHOP_CLOSE_HOUR:
				_show_hud_notification("💤 Nghỉ ngơi đi!", 3.0); return
			if not Global.furniture_out:
				Global.furniture_out = true; Global.is_shop_open = true; Global.day_changed.emit(true)
				_show_hud_notification("🥖 MỞ QUÁN!")

		elif event.keycode == KEY_C:
			if current_hour < Global.SHOP_CLOSE_HOUR:
				_show_hud_notification("💪 Cố gắng lên!", 3.0); return
			if Global.furniture_out:
				Global.furniture_out = false; Global.is_shop_open = false; Global.day_changed.emit(false)
				_show_hud_notification("🌙 ĐÓNG CỬA quán."); Global.end_day()

func _process(delta: float):
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
			_night_timer = 0.0; Global.is_night_summary = false; Global.is_transition_black = true
			var hud = get_tree().get_first_node_in_group("HUD")
			if hud: hud.show_black_screen_quote()
		return

	if Global.is_transition_black:
		if progress >= 1.0:
			Global.start_new_day(); _reset_player_position()
			_last_morning_notif_time = -100.0; _last_night_notif_time = -100.0
		return

	if current_hour > 6.5 and not Global.furniture_out:
		Global.money -= 1; Global.money_changed.emit(Global.money)
		if Global.day_elapsed - _last_morning_notif_time > 10.0:
			_last_morning_notif_time = Global.day_elapsed; _show_hud_notification("🚨 TRỄ GIỜ MỞ QUÁN!", 2.5)

	if current_hour >= Global.SHOP_CLOSE_HOUR and Global.furniture_out:
		if not Global.is_overtime: Global.is_overtime = true; _show_hud_notification("🚨 QUÁ GIỜ ĐÓNG CỬA!", 5.0)
		Global.money -= 3; Global.money_changed.emit(Global.money)
		if Global.day_elapsed - _last_night_notif_time > 10.0:
			_last_night_notif_time = Global.day_elapsed; _show_hud_notification("🚨 QUÁ GIỜ ĐÓNG CỬA!", 2.5)

func _update_lighting(hour: float):
	if not _directional_light: return
	var energy: float = 0.0; var rot_x: float = 0.0; var rot_y: float = -90.0
	var light_color: Color = Color.WHITE; var sky_color: Color = SKY_COLOR_NIGHT
	var day_t = clamp((hour - 5.0) / 14.0, 0.0, 1.0)
	rot_y = lerp(-90.0, 90.0, day_t)
	if hour >= 5.0 and hour < 8.5:
		var t = (hour - 5.0) / 3.5; energy = lerp(0.05, 1.0, t); rot_x = lerp(-2.0, -35.0, t)
		light_color = Color(1.0, 0.7, 0.4).lerp(Color(1.0, 0.9, 0.7), t); sky_color = SKY_COLOR_NIGHT.lerp(SKY_COLOR_MORNING, t)
	elif hour >= 8.5 and hour < 12.0:
		var t = (hour - 8.5) / 3.5; energy = lerp(1.0, 1.8, t); rot_x = lerp(-35.0, -90.0, t)
		light_color = Color(1.0, 0.9, 0.7).lerp(Color(1.0, 1.0, 1.0), t); sky_color = SKY_COLOR_MORNING.lerp(SKY_COLOR_NOON, t)
	elif hour >= 12.0 and hour < 16.5:
		var t = (hour - 12.0) / 4.5; energy = lerp(1.8, 0.7, t); rot_x = lerp(-90.0, -30.0, t)
		light_color = Color(1.0, 1.0, 1.0).lerp(Color(1.0, 0.8, 0.4), t); sky_color = SKY_COLOR_NOON.lerp(SKY_COLOR_AFTERNOON, t)
	elif hour >= 16.5 and hour < 19.0:
		var t = (hour - 16.5) / 2.5; energy = lerp(0.7, 0.0, t); rot_x = lerp(-30.0, 2.0, t)
		light_color = Color(1.0, 0.6, 0.2).lerp(Color(0.3, 0.1, 0.05), t); sky_color = SKY_COLOR_AFTERNOON.lerp(SKY_COLOR_EVENING, t)
		if hour > 18.5: sky_color = SKY_COLOR_EVENING.lerp(SKY_COLOR_NIGHT, (hour-18.5)/0.5)
	else: energy = 0.0; rot_x = 10.0; sky_color = SKY_COLOR_NIGHT
	_directional_light.light_energy = energy; _directional_light.rotation_degrees.x = rot_x
	_directional_light.rotation_degrees.y = rot_y; _directional_light.light_color = light_color
	if _world_env and _world_env.environment:
		var mat = _world_env.environment.sky.sky_material as ProceduralSkyMaterial
		if mat: mat.sky_top_color = sky_color; mat.sky_horizon_color = sky_color.lightened(0.1); mat.ground_horizon_color = sky_color.darkened(0.1)

	# Quản lý bật/tắt đèn (chỉ quản lý đèn đã có sẵn)
	var light_intensity: float = 0.0
	if hour >= 5.0 and hour < 7.5: light_intensity = lerp(1.0, 0.0, (hour - 5.0) / 2.5)
	elif hour >= 17.5 and hour < 19.0: light_intensity = lerp(0.0, 1.0, (hour - 17.5) / 1.5)
	elif hour >= 19.0 or hour < 5.0: light_intensity = 1.0
	
	for light in _managed_lights:
		if is_instance_valid(light):
			var max_e = _light_max_energies.get(light.get_instance_id(), light.light_energy)
			light.light_energy = light_intensity * max_e
			light.visible = light_intensity > 0.01

func _find_scene_nodes():
	_directional_light = get_tree().root.find_child("DirectionalLight3D", true, false)
	_world_env = get_tree().root.find_child("WorldEnvironment", true, false)
	var cart_node = get_tree().root.find_child("cart", true, false)
	if cart_node and not _cart_timer:
		_cart_timer = Label3D.new(); cart_node.add_child(_cart_timer)
		_cart_timer.text = "05:00"; _cart_timer.font_size = 20; _cart_timer.outline_size = 6
		_cart_timer.position = Vector3(0, 0.8, 0.5); _cart_timer.modulate = Color(1, 0.8, 0.2)
	
	_managed_lights.clear()
	# Tìm tất cả đèn có sẵn trong scene
	_find_existing_lights(get_tree().root)

func _find_existing_lights(node: Node):
	if node is OmniLight3D or node is SpotLight3D:
		_managed_lights.append(node)
		# Tăng độ sáng đặc biệt cho đèn bạn vừa thêm (den_duong_42)
		if node.get_parent() and node.get_parent().name == "den_duong_42":
			node.light_energy = 50.0 # Độ sáng cực mạnh
			node.shadow_enabled = true # Bật đổ bóng
			node.spot_range = 20.0 # Tăng tầm chiếu xa
			node.spot_angle = 45.0 # Chỉnh góc chiếu vừa phải
		
		_light_max_energies[node.get_instance_id()] = node.light_energy
	for child in node.get_children():
		_find_existing_lights(child)

func _reset_player_position():
	var player = get_tree().root.find_child("Player", true, false)
	if player: player.global_position = Vector3(25.0, 1.0, 10.5); player.rotation_degrees = Vector3(0, 90, 0)

func _show_hud_notification(text: String, duration: float = 2.5):
	var hud = get_tree().get_first_node_in_group("HUD")
	if hud and hud.has_method("show_notification"): hud.show_notification(text, duration)

func _update_clocks(progress: float):
	var current_total_hours = Global.DAY_START_HOUR + (progress * Global.TOTAL_HOURS)
	var hour = int(current_total_hours) % 24; var minute = int((current_total_hours - int(current_total_hours)) * 60.0)
	if _cart_timer: _cart_timer.text = "%02d:%02d" % [hour, minute]; _cart_timer.modulate = Color(2.5, 1.5, 0.5) if (hour >= 18 or hour < 6) else Color(1.2, 0.9, 0.2)

func get_day_progress() -> float: return clamp(Global.day_elapsed / Global.DAY_DURATION, 0.0, 1.0)
