extends Camera2D

# Configurable speed and zoom
@export var zoom_speed: float = 0.1
@export var min_zoom: float = 0.5
@export var max_zoom: float = 2.0

var _is_dragging: bool = false
var _following_customer: Node2D = null

func _ready() -> void:
	# Keep the camera independent of parent positioning if needed, 
	# but for Main it will just start at Main's origin or its own position.
	pass

func _unhandled_input(event: InputEvent) -> void:
	# 1. Panning logic (Mouse Drag)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT or event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				_is_dragging = true
			else:
				_is_dragging = false
				
		# Zoom is locked, ignoring scroll wheel inputs
		pass

	# 2. Panning logic (Touch Drag)
	elif event is InputEventScreenDrag:
		var delta_drag = event.relative
		position -= delta_drag / zoom
		_clamp_camera_position()

	# 3. Handle the mouse dragging motion
	elif event is InputEventMouseMotion and _is_dragging:
		var delta_drag = event.relative
		position -= delta_drag / zoom
		_clamp_camera_position()

func _clamp_camera_position() -> void:
	# Clamp camera position to reasonably match limits so it doesn't drift infinitely
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
