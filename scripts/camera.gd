extends Camera2D

# Configurable speed and zoom
@export var zoom_speed: float = 0.1
@export var max_zoom: float = 2.0

var _is_dragging: bool = false
var _initial_zoom: float = 1.0  # Zoom ban đầu = giới hạn zoom nhỏ nhất

# ─── Pinch-to-zoom (mobile) ───────────────────────────────
var _touch_points: Dictionary = {}   # index -> position
var _pinch_distance: float = 0.0

func _ready() -> void:
	_initial_zoom = zoom.x

func _unhandled_input(event: InputEvent) -> void:
	# ── Touch: theo dõi điểm chạm ──────────────────────────
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_points[event.index] = event.position
		else:
			_touch_points.erase(event.index)
			if _touch_points.size() < 2:
				_pinch_distance = 0.0  # reset khi ngón tay rời

	elif event is InputEventScreenDrag:
		_touch_points[event.index] = event.position

		if _touch_points.size() == 2:
			# Pinch-to-zoom: 2 ngón
			var pts = _touch_points.values()
			var dist = pts[0].distance_to(pts[1])
			if _pinch_distance > 0.0:
				var delta = (dist - _pinch_distance) * 0.003
				_zoom_camera(delta)
			_pinch_distance = dist
		elif _touch_points.size() == 1:
			# Single finger pan
			position -= event.relative / zoom
			_clamp_camera_position()

	# ── Mouse Drag (desktop / editor) ──────────────────────
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT or \
		   event.button_index == MOUSE_BUTTON_RIGHT or \
		   event.button_index == MOUSE_BUTTON_MIDDLE:
			_is_dragging = event.pressed

		# Scroll wheel zoom (desktop)
		if event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_zoom_camera(zoom_speed)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_zoom_camera(-zoom_speed)

	elif event is InputEventMouseMotion and _is_dragging:
		position -= event.relative / zoom
		_clamp_camera_position()

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
	new_zoom = clamp(new_zoom, _initial_zoom, max_zoom)
	zoom = Vector2(new_zoom, new_zoom)
	_clamp_camera_position()
