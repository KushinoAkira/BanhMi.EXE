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

var shadow_tex: Texture2D
var tree_tex: Texture2D
var lamp_tex: Texture2D
var _cell_type: Dictionary = {}       # Vector2i -> "road" / "sidewalk"
var _building_cells: Dictionary = {}  # Vector2i -> true

# ─── READY ─────────────────────────────────────────────────
func _ready() -> void:
	print("═══════════════════════════════════════")
	print("  🥖 BÁNH MÌ .EXE — Isometric City")
	print("═══════════════════════════════════════")

	shadow_tex = load("res://assets/sprites/props/shadow_blob.png")
	tree_tex = load("res://assets/sprites/props/prop_tree.png")
	lamp_tex = load("res://assets/sprites/props/prop_streetlamp.png")

	_classify_cells()
	
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
	print("[Main] ✅ City ready! %d wander, %d spawn" % [wps.size(), sps.size()])

# ─── ISO HELPER ───────────────────────────────────────────
func _get_local_pos(col: int, row: int) -> Vector2:
	return tile_map.map_to_local(Vector2i(col, row)) + tile_map.position

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
