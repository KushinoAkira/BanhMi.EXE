## main.gd — Isometric City Builder Setup
## Modulo-based 25×25 grid: roads at x%5==0 || y%5==0, sidewalk blocks, dense buildings
extends Node2D

# ─── GRID CONSTANTS ───────────────────────────────────────
const TILE_W := 128
const TILE_H := 64
const GRID_COLS := 31
const GRID_ROWS := 31
const GRID_OFFSET := Vector2(640, 50)

## Road interval — road every N-th row/col (0, 6, 12, 18...)
const ROAD_INTERVAL := 6

## Tile atlas coords
const TILE_ROAD := Vector2i(1, 0)
const TILE_SIDEWALK := Vector2i(2, 0)
const TILE_ROAD_COL := Vector2i(3, 0)
const TILE_ROAD_ROW := Vector2i(4, 0)
const TILE_ROAD_INT := Vector2i(5, 0)

# ─── BUILDING DATA ────────────────────────────────────────
const BUILDING_TEXTURES := [
	"res://assets/sprites/buildings/building_apartment.png",
	"res://assets/sprites/buildings/building_coffee_shop.png",
	"res://assets/sprites/buildings/building_store.png",
	"res://assets/sprites/buildings/building_pharmacy.png",
	"res://assets/sprites/buildings/building_pho_restaurant.png",
	"res://assets/sprites/buildings/building_school.png",
]
const BUILDING_HEIGHTS := [597, 600, 601, 640, 640, 640]
const BUILDING_SCALE := 0.45

# ─── ONREADY NODES ────────────────────────────────────────
@onready var tile_map: TileMapLayer = $GroundTileMap
@onready var city_objects: Node2D = $CityObjects
@onready var banh_mi_cart: Node2D = $CityObjects/BanhMiCart
@onready var customer_spawner: Node = $CustomerSpawner
@onready var wander_points_node: Node2D = $WanderPoints
@onready var spawn_points_node: Node2D = $SpawnPoints
@onready var nav_region: NavigationRegion2D = $NavigationRegion2D
@onready var camera: Camera2D = $Camera2D

@onready var day_night_mod: CanvasModulate = $DayNightModulate
@onready var sky_color: ColorRect = $SkyFill/SkyColor
@onready var day_sky_sprite: Sprite2D = $ParallaxBackground/SkyLayer/SkyBG
@onready var night_sky_sprite: Sprite2D = $ParallaxBackground/SkyLayer/NightSkyBG
@onready var sun_sprite: Sprite2D = $ParallaxBackground/SkyLayer/Sun
@onready var moon_sprite: Sprite2D = $ParallaxBackground/SkyLayer/Moon
@onready var cart_light: PointLight2D = $CityObjects/BanhMiCart/CartLight
@onready var background_music: AudioStreamPlayer = $BackgroundMusic

var shadow_tex: Texture2D
var tree_tex: Texture2D
var lamp_tex: Texture2D
var _cell_type: Dictionary = {}       # Vector2i -> "road" / "sidewalk"
var _building_cells: Dictionary = {}  # Vector2i -> true

var _lamp_lights: Array[PointLight2D] = []
var _lamp_light_tex: GradientTexture2D
var _was_music_paused: bool = false
var _rain_particles: CPUParticles2D
var _event_label: Label

# ─── READY ─────────────────────────────────────────────────
func _ready() -> void:
	print("═══════════════════════════════════════")
	print("  🥖 BÁNH MÌ .EXE — Isometric City")
	print("═══════════════════════════════════════")

	shadow_tex = load("res://assets/sprites/props/shadow_blob.png")
	tree_tex = load("res://assets/sprites/props/prop_tree.png")
	lamp_tex = load("res://assets/sprites/props/prop_streetlamp.png")

	_classify_cells()
	_create_lamp_texture()
	
	if cart_light:
		cart_light.texture = _lamp_light_tex
	
	tile_map.position = GRID_OFFSET
	city_objects.y_sort_enabled = true
	banh_mi_cart.y_sort_enabled = true
	
	_paint_tilemap()
	_place_street_buildings()
	_place_sidewalk_props()
	_place_cart()
	_create_wander_points()
	_create_spawn_points()
	_setup_navigation()
	_setup_camera_limits()

	# Collect points
	var wps: Array[Marker2D] = []
	for c in wander_points_node.get_children():
		if c is Marker2D: wps.append(c)
	var sps: Array[Marker2D] = []
	for c in spawn_points_node.get_children():
		if c is Marker2D: sps.append(c)

	customer_spawner.spawn_points = sps
	customer_spawner.wander_points = wps
	customer_spawner.banh_mi_cart = banh_mi_cart
	customer_spawner.game_world = city_objects
	banh_mi_cart.customer_served.connect(_on_customer_served)
	GameManager.add_money(100)
	
	if moon_sprite: moon_sprite.visible = true

	# Kết nối quality settings để bật/tắt đèn
	SettingsManager.quality_changed.connect(_on_quality_changed)
	_on_quality_changed(SettingsManager.quality_level)
	
	_setup_event_system()
	GameManager.event_started.connect(_on_event_started)
	
	var story_mgr = CanvasLayer.new()
	var StoryManagerClass = preload("res://scripts/story_manager.gd")
	if StoryManagerClass:
		story_mgr.set_script(StoryManagerClass)
		add_child(story_mgr)
	
	print("[Main] ✅ City ready! %d wander, %d spawn" % [wps.size(), sps.size()])

# ─── EVENT SYSTEM ──────────────────────────────────────────
func _setup_event_system() -> void:
	# Mưa
	_rain_particles = CPUParticles2D.new()
	_rain_particles.emitting = false
	_rain_particles.amount = 500
	_rain_particles.lifetime = 1.5
	_rain_particles.speed_scale = 2.0
	_rain_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_rain_particles.emission_rect_extents = Vector2(1000, 10)
	_rain_particles.direction = Vector2(-0.2, 1) # Mưa chéo
	_rain_particles.spread = 5
	_rain_particles.gravity = Vector2(0, 800)
	_rain_particles.initial_velocity_min = 400
	_rain_particles.initial_velocity_max = 600
	_rain_particles.scale_amount_min = 1.0
	_rain_particles.scale_amount_max = 3.0
	_rain_particles.color = Color(0.6, 0.7, 0.9, 0.4)
	_rain_particles.z_index = 100 # Luôn đè lên trên tất cả
	
	# Gắn mưa dính vào camera
	camera.add_child(_rain_particles)
	_rain_particles.position = Vector2(0, -600) 
	
	# Label thông báo
	_event_label = Label.new()
	var ui_layer = get_node_or_null("UILayer")
	if ui_layer:
		ui_layer.add_child(_event_label)
		_event_label.add_theme_font_size_override("font_size", 32)
		_event_label.add_theme_color_override("font_color", Color(1, 0.9, 0, 1))
		_event_label.add_theme_color_override("font_outline_color", Color.BLACK)
		_event_label.add_theme_constant_override("outline_size", 8)
		_event_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_event_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		_event_label.offset_top = 150 # Dịch xuống dưới một chút để không đè UI mây/options
		_event_label.text = ""
		_event_label.hide()

func _on_event_started(event_type: String) -> void:
	if event_type == "none":
		_rain_particles.emitting = false
		return
		
	if event_type == "rain":
		_rain_particles.emitting = true
		_show_event_popup("🌧️ TRỜI MƯA TO! Khách ít đi, nhưng trả tiền nhiều hơn!")
	elif event_type == "rush_hour":
		_show_event_popup("🏃 GIỜ CAO ĐIỂM! Khách đông nghịt!")

func _show_event_popup(msg: String) -> void:
	if not _event_label: return
	_event_label.text = msg
	_event_label.show()
	_event_label.modulate.a = 0.0
	
	var tw = create_tween()
	tw.tween_property(_event_label, "modulate:a", 1.0, 0.5)
	tw.tween_interval(3.0)
	tw.tween_property(_event_label, "modulate:a", 0.0, 0.5)
	tw.tween_callback(_event_label.hide)

## Bật/tắt đèn đường + đèn xe tùy quality
func _on_quality_changed(level: int) -> void:
	# Ở chế độ Thấp (0): tắt hết PointLight2D để tiết kiệm GPU
	var lights_enabled := level >= 1
	for light in _lamp_lights:
		if is_instance_valid(light):
			light.enabled = lights_enabled
	if cart_light:
		cart_light.enabled = lights_enabled

# ─── APP LIFECYCLE (Mobile) ────────────────────────────────
## Xử lý khi có cuộc gọi, lock screen, chuyển app
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			# App bị minimize / có cuộc gọi / tắt màn hình
			get_tree().paused = true
			if background_music and background_music.playing:
				_was_music_paused = true
				background_music.stream_paused = true
			SettingsManager.save_settings()  # Lưu settings khi thoát app
			
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN:
			# Quay lại game
			get_tree().paused = false
			if background_music and _was_music_paused and not SettingsManager.music_muted:
				background_music.stream_paused = false
				_was_music_paused = false

		NOTIFICATION_WM_GO_BACK_REQUEST:
			# Nút Back trên Android
			_on_android_back_pressed()

func _on_android_back_pressed() -> void:
	# Nếu settings panel đang mở → đóng lại
	if SettingsUI and SettingsUI.panel.visible:
		SettingsUI.panel.hide()
		return
	# Không làm gì khác (tránh thoát game đột ngột)

func _process(_delta: float) -> void:
	if not day_night_mod or not sky_color or not sun_sprite or not moon_sprite: return
	
	var time: float = GameManager.time_of_day
	
	var daylight_factor: float = 0.0
	if time >= 6.0 and time <= 17.0:
		daylight_factor = 1.0
	elif time >= 5.0 and time < 6.0:
		daylight_factor = time - 5.0
	elif time > 17.0 and time <= 18.0:
		daylight_factor = 18.0 - time
		
	var night_factor: float = 1.0 - daylight_factor
	
	var night_mod := Color(0.3, 0.3, 0.5, 1.0)
	var day_mod := Color(1.0, 1.0, 1.0, 1.0)
	
	# Nếu trời mưa, ban ngày cũng âm u
	if GameManager.current_event_type == "rain" and daylight_factor > 0.0:
		day_mod = Color(0.6, 0.6, 0.7, 1.0)
	
	# Transitioning Modulate
	day_night_mod.color = night_mod.lerp(day_mod, daylight_factor)
	
	# Smoothly crossfade Day Sky and Night Sky background layer
	if day_sky_sprite:
		day_sky_sprite.modulate.a = daylight_factor
	if night_sky_sprite:
		night_sky_sprite.modulate.a = night_factor
		
	# Smoothly crossfade Sun and Moon
	sun_sprite.modulate.a = daylight_factor
	# Moon stays slightly visible at day, but mostly opaque at night.
	moon_sprite.modulate = Color(1.2, 1.2, 1.5, night_factor)
	
	# ─── SUN AND MOON TRAJECTORY ─────────────────────────────
	# Màn hình điện thoại bề ngang 700px (Center = 350)
	var center_x := 350.0
	var center_y := 400.0
	var radius_x := 320.0 # Bán kính ngang thu hẹp lại
	var radius_y := 350.0
	
	# Tính góc cho Mặt Trời (mọc lúc 05:00, lặn lúc 18:00)
	# 05:00 -> góc PI (bên trái), 18:00 -> góc 0 (bên phải)
	if time >= 5.0 and time <= 18.0:
		sun_sprite.visible = true
		var sun_progress = (time - 5.0) / 13.0 # 0.0 to 1.0
		var sun_angle = PI - (sun_progress * PI)
		sun_sprite.position.x = center_x + cos(sun_angle) * radius_x
		sun_sprite.position.y = center_y - sin(sun_angle) * radius_y
	else:
		sun_sprite.visible = false
		
	# Tính góc cho Mặt Trăng (mọc lúc 18:00, lặn lúc 05:00 sáng)
	# 18:00 -> góc PI, 05:00 (+24) -> góc 0
	var moon_time = time
	if moon_time < 5.0:
		moon_time += 24.0 # 0-5h sáng được dời thành 24-29h
		
	if moon_time >= 18.0 and moon_time <= 29.0:
		moon_sprite.visible = true
		var moon_progress = (moon_time - 18.0) / 11.0 # 0.0 to 1.0
		var moon_angle = PI - (moon_progress * PI)
		moon_sprite.position.x = center_x + cos(moon_angle) * radius_x
		moon_sprite.position.y = center_y - sin(moon_angle) * radius_y
	else:
		moon_sprite.visible = false
	
	# Update streetlamp lights (Fade in heavily as night falls)
	var lamp_energy = clampf((night_factor - 0.4) * 2.0, 0.0, 1.0)
	
	# Nếu mưa thì đèn đường cũng bật nhẹ ban ngày
	if GameManager.current_event_type == "rain":
		lamp_energy = maxf(lamp_energy, 0.5)
		
	for light in _lamp_lights:
		if is_instance_valid(light):
			light.energy = lamp_energy * 1.5 # max energy 1.5
	if cart_light:
		cart_light.energy = lamp_energy * 1.5

# ─── ISO HELPER ───────────────────────────────────────────
func _get_local_pos(col: int, row: int) -> Vector2:
	return tile_map.map_to_local(Vector2i(col, row)) + tile_map.position

func _create_lamp_texture() -> void:
	_lamp_light_tex = GradientTexture2D.new()
	_lamp_light_tex.fill = GradientTexture2D.FILL_RADIAL
	_lamp_light_tex.fill_from = Vector2(0.5, 0.5)
	_lamp_light_tex.fill_to = Vector2(1.0, 0.5)
	_lamp_light_tex.width = 400
	_lamp_light_tex.height = 400
	var grad = Gradient.new()
	grad.set_color(0, Color(1.0, 0.8, 0.4, 0.9)) # Warm yellow light inside
	grad.set_color(1, Color(1.0, 0.8, 0.4, 0.0)) # Transparent outside
	_lamp_light_tex.gradient = grad

# ─── CELL CLASSIFICATION (modulo grid) ───────────────────
func _classify_cells() -> void:
	for col in range(GRID_COLS):
		for row in range(GRID_ROWS):
			var key := Vector2i(col, row)
			if col % ROAD_INTERVAL == 0 or row % ROAD_INTERVAL == 0:
				_cell_type[key] = "road"
			else:
				_cell_type[key] = "sidewalk"
	var rc := 0
	var sc := 0
	for key in _cell_type:
		if _cell_type[key] == "road": rc += 1
		else: sc += 1
	print("[Main] Grid: %d road, %d sidewalk" % [rc, sc])

func _get_type(col: int, row: int) -> String:
	var key := Vector2i(col, row)
	if _cell_type.has(key):
		return _cell_type[key]
	return "road"

func _is_adjacent_to_road(col: int, row: int) -> bool:
	for off in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
		if _get_type(col + off.x, row + off.y) == "road":
			return true
	return false

# ─── PAINT TILEMAP ────────────────────────────────────────
func _paint_tilemap() -> void:
	for col in range(GRID_COLS):
		for row in range(GRID_ROWS):
			if _get_type(col, row) == "road":
				var is_col = (col % ROAD_INTERVAL == 0)
				var is_row = (row % ROAD_INTERVAL == 0)
				
				if is_col and is_row:
					tile_map.set_cell(Vector2i(col, row), 0, TILE_ROAD_INT)
				elif is_col:
					tile_map.set_cell(Vector2i(col, row), 0, TILE_ROAD_COL)
				else:
					tile_map.set_cell(Vector2i(col, row), 0, TILE_ROAD_ROW)
			else:
				tile_map.set_cell(Vector2i(col, row), 0, TILE_SIDEWALK)
	print("[Main] Painted tilemap (%dx%d)" % [GRID_COLS, GRID_ROWS])

# ─── BUILDINGS — perimeter cells only (street-facing) ─
## Buildings go on the edge of each sidewalk block to face streets.
## We pack them densely and leave some gaps for props.
func _place_street_buildings() -> void:
	var placed := 0
	var tex_idx := 0

	for block_col in range(0, GRID_COLS - 1, ROAD_INTERVAL):
		for block_row in range(0, GRID_ROWS - 1, ROAD_INTERVAL):
			var start_c: int = block_col + 1
			var end_c: int = mini(block_col + ROAD_INTERVAL - 1, GRID_COLS - 1)
			var start_r: int = block_row + 1
			var end_r: int = mini(block_row + ROAD_INTERVAL - 1, GRID_ROWS - 1)
			if start_c > end_c or start_r > end_r:
				continue

			for col in range(start_c, end_c + 1):
				for row in range(start_r, end_r + 1):
					if _get_type(col, row) != "sidewalk":
						continue
					
					# Only place buildings internally, leaving the direct edges empty
					var is_inner_edge = (col == start_c + 1 or col == end_c - 1 or row == start_r + 1 or row == end_r - 1)
					
					if not is_inner_edge:
						continue
					
					# Space out buildings to prevent massive sprite overlap
					if (col + row) % 2 != 0:
						continue

					var pos := _get_local_pos(col, row)
					var tex_path: String = BUILDING_TEXTURES[tex_idx % BUILDING_TEXTURES.size()]
					var tex = load(tex_path)
					if tex == null:
						continue
					var bh: int = BUILDING_HEIGHTS[tex_idx % BUILDING_HEIGHTS.size()]

					_add_shadow(pos + Vector2(0, 5), 0.9, 0.45)

					var spr := Sprite2D.new()
					spr.texture = tex
					spr.position = pos
					spr.scale = Vector2(BUILDING_SCALE, BUILDING_SCALE)
					spr.offset = Vector2(0, -bh * 0.5)
					spr.y_sort_enabled = true
					if randf() > 0.6:
						spr.flip_h = true
					city_objects.add_child(spr)
					_building_cells[Vector2i(col, row)] = true

					tex_idx += 1
					placed += 1

	print("[Main] Placed %d buildings along streets" % placed)

# ─── SIDEWALK PROPS — edge gaps directly adjacent to roads ───────
## Trees and streetlamps on sidewalk cells directly touching roads where buildings are not present.
func _place_sidewalk_props() -> void:
	var trees := 0
	var lamps := 0

	for col in range(GRID_COLS):
		for row in range(GRID_ROWS):
			if _get_type(col, row) != "sidewalk":
				continue
			if _building_cells.has(Vector2i(col, row)):
				continue
			if not _is_adjacent_to_road(col, row):
				continue

			var pos := _get_local_pos(col, row)

			if (col + row) % 2 == 0:
				_add_shadow(pos + Vector2(0, 3), 0.5, 0.25)
				var t := Sprite2D.new()
				t.texture = tree_tex
				t.position = pos
				t.scale = Vector2(0.22, 0.22)
				t.offset = Vector2(0, -259)
				t.y_sort_enabled = true
				city_objects.add_child(t)
				trees += 1
			else:
				_add_shadow(pos + Vector2(0, 2), 0.3, 0.18)
				var l := Sprite2D.new()
				l.texture = lamp_tex
				l.position = pos
				l.scale = Vector2(0.15, 0.15)
				l.offset = Vector2(0, -268)
				l.y_sort_enabled = true
				
				var light := PointLight2D.new()
				light.texture = _lamp_light_tex
				light.position = Vector2(0, -450) # Tương đương đầu cột đèn
				light.energy = 0.0
				light.blend_mode = Light2D.BLEND_MODE_ADD
				light.z_index = 2
				l.add_child(light)
				_lamp_lights.append(light)
				
				city_objects.add_child(l)
				lamps += 1

	print("[Main] Props: %d trees, %d lamps" % [trees, lamps])

# ─── SHADOW HELPER ────────────────────────────────────────
func _add_shadow(pos: Vector2, sx: float, sy: float) -> void:
	var sh := Sprite2D.new()
	sh.texture = shadow_tex
	sh.position = pos
	sh.scale = Vector2(sx, sy)
	sh.z_index = -1
	city_objects.add_child(sh)

# ─── CART PLACEMENT ───────────────────────────────────────
func _place_cart() -> void:
	var cart_col := 6
	var cart_row := 5
	var cart_pos := _get_local_pos(cart_col, cart_row)
	banh_mi_cart.position = cart_pos
	print("[Main] Cart at (%d,%d)" % [cart_col, cart_row])

# ─── WANDER POINTS — road tiles only ─────────────────────
func _create_wander_points() -> void:
	var count := 0
	for col in range(GRID_COLS):
		for row in range(GRID_ROWS):
			if _get_type(col, row) != "road":
				continue
			if (col + row) % 2 != 0:
				continue
			var wp := Marker2D.new()
			wp.position = _get_local_pos(col, row)
			wp.name = "WP_%d" % count
			wander_points_node.add_child(wp)
			count += 1
	print("[Main] %d wander points (road only)" % count)

# ─── SPAWN POINTS — road edges ───────────────────────────
func _create_spawn_points() -> void:
	var count := 0
	for col in range(0, GRID_COLS, ROAD_INTERVAL):
		for edge_row in [0, GRID_ROWS - 1]:
			var sp := Marker2D.new()
			sp.position = _get_local_pos(col, edge_row)
			sp.name = "SP_%d" % count
			spawn_points_node.add_child(sp)
			count += 1
	for row in range(0, GRID_ROWS, ROAD_INTERVAL):
		for edge_col in [0, GRID_COLS - 1]:
			var sp := Marker2D.new()
			sp.position = _get_local_pos(edge_col, row)
			sp.name = "SP_%d" % count
			spawn_points_node.add_child(sp)
			count += 1
	print("[Main] %d spawn points" % count)

# ─── NAVIGATION — road-only mesh with building block holes ─
## Outer diamond covers the whole map; holes carve out each sidewalk block.
## NPCs can only navigate on road tiles.
func _setup_navigation() -> void:
	var nav_poly := NavigationPolygon.new()

	# Outer boundary (counter-clockwise in screen coords = solid)
	var m := 80.0
	var outer_top := _get_local_pos(0, 0) + Vector2(0, -TILE_H * 0.5 - m)
	var outer_left := _get_local_pos(0, GRID_ROWS - 1) + Vector2(-TILE_W * 0.5 - m, 0)
	var outer_bottom := _get_local_pos(GRID_COLS - 1, GRID_ROWS - 1) + Vector2(0, TILE_H * 0.5 + m)
	var outer_right := _get_local_pos(GRID_COLS - 1, 0) + Vector2(TILE_W * 0.5 + m, 0)
	# CCW order: Top → Left → Bottom → Right
	nav_poly.add_outline(PackedVector2Array([outer_top, outer_left, outer_bottom, outer_right]))

	# Hole for each sidewalk block (clockwise in screen coords = hole)
	for block_col in range(0, GRID_COLS - 1, ROAD_INTERVAL):
		for block_row in range(0, GRID_ROWS - 1, ROAD_INTERVAL):
			var sc: int = block_col + 1
			var ec: int = mini(block_col + ROAD_INTERVAL - 1, GRID_COLS - 1)
			var sr: int = block_row + 1
			var er: int = mini(block_row + ROAD_INTERVAL - 1, GRID_ROWS - 1)
			if sc > ec or sr > er:
				continue

			# Diamond corners of this block (CW = hole)
			var hole_top := _get_local_pos(sc, sr) + Vector2(0, -TILE_H * 0.5)
			var hole_right := _get_local_pos(ec, sr) + Vector2(TILE_W * 0.5, 0)
			var hole_bottom := _get_local_pos(ec, er) + Vector2(0, TILE_H * 0.5)
			var hole_left := _get_local_pos(sc, er) + Vector2(-TILE_W * 0.5, 0)
			# CW order: Top → Right → Bottom → Left
			nav_poly.add_outline(PackedVector2Array([hole_top, hole_right, hole_bottom, hole_left]))

	var source_geom_data = NavigationMeshSourceGeometryData2D.new()
	NavigationServer2D.parse_source_geometry_data(nav_poly, source_geom_data, self)
	NavigationServer2D.bake_from_source_geometry_data(nav_poly, source_geom_data)
	nav_region.navigation_polygon = nav_poly
	print("[Main] ✅ Navigation ready — road-only with %d block holes" % (
		nav_poly.get_outline_count() - 1
	))

# ─── CAMERA LIMITS ─────────────────────────────────────────
func _setup_camera_limits() -> void:
	if not camera: return
	# Bounding box of the grid with a tighter margin to not show too much empty space
	# Horizontal needs more space to see the left/right edges properly, Vertical needs less space
	var margin_x := -70.0
	var margin_y := 230.0
	
	var top := _get_local_pos(0, 0) + Vector2(0, -TILE_H * 0.5)
	var left := _get_local_pos(0, GRID_ROWS - 1) + Vector2(-TILE_W * 0.5, 0)
	var bottom := _get_local_pos(GRID_COLS - 1, GRID_ROWS - 1) + Vector2(0, TILE_H * 0.5)
	var right := _get_local_pos(GRID_COLS - 1, 0) + Vector2(TILE_W * 0.5, 0)
	
	camera.limit_left = int(left.x - margin_x)
	camera.limit_top = int(top.y - margin_y)
	camera.limit_right = int(right.x + margin_x)
	camera.limit_bottom = int(bottom.y + margin_y)
	print("[Main] ✅ Camera limits set to: Left: %d, Top: %d, Right: %d, Bottom: %d" % [
		camera.limit_left, camera.limit_top, camera.limit_right, camera.limit_bottom
	])

func _on_customer_served(price: int) -> void:
	print("[Main] 🥖 +%dđ! Tổng: %dđ" % [price, GameManager.money])
