extends Camera2D

# Configurable speed and zoom
@export var zoom_speed: float = 0.1
@export var max_zoom: float = 3.0
@export var min_zoom: float = 1.5

var _is_dragging: bool = false
var _initial_zoom: float = 1.0  # Zoom ban đầu = giới hạn zoom nhỏ nhất

# ─── Pinch-to-zoom (mobile) ───────────────────────────────
var _touch_points: Dictionary = {}   # index -> position
var _pinch_distance: float = 0.0

func _ready() -> void:
	_initial_zoom = maxf(zoom.x, min_zoom)

func _unhandled_input(_event: InputEvent) -> void:
	pass  # Zoom và di chuyển map đã bị khoá

func _clamp_camera_position() -> void:
	var vp_size = get_viewport_rect().size / zoom
	if limit_left > -10000000:
		var min_x = limit_left + vp_size.x / 2.0
		var max_x = maxf(min_x, limit_right - vp_size.x / 2.0)
		position.x = clampf(position.x, min_x, max_x)
	if limit_top > -10000000:
		var min_y = limit_top + vp_size.y / 2.0
		var max_y = maxf(min_y, limit_bottom - vp_size.y / 2.0)
		position.y = clampf(position.y, min_y, max_y)

func _zoom_camera(amount: float) -> void:
	var new_zoom = zoom.x + amount
	new_zoom = clamp(new_zoom, min_zoom, max_zoom)
	zoom = Vector2(new_zoom, new_zoom)
	_clamp_camera_position()

## Gọi từ ngoài để đặt vị trí + zoom và clamped ngay
func focus_on(world_pos: Vector2, zoom_level: float) -> void:
	zoom = Vector2(zoom_level, zoom_level)
	position = world_pos
	_clamp_camera_position()
