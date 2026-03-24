extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5
const MOUSE_SENSITIVITY = 0.002

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var head = $Head
@onready var camera = $Head/Camera3D
@onready var interaction_ray = $Head/Camera3D/RayCast3D

var hud: CanvasLayer
var last_highlighted_target = null

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	# Find HUD node
	hud = get_node_or_null("/root/Main/HUD")
	
	# CHỈ NHÌN LAYER 2 (Đồ tương tác)
	# Việc này cực kỳ quan trọng: Nó giúp tâm ngắm xuyên qua các hộp va chạm của xe
	# để chạm trực tiếp vào bánh mì, tô xì dầu bên trong.
	interaction_ray.collision_mask = 2 # Chỉ nhìn Layer 2

func _unhandled_input(event):
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		head.rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-89), deg_to_rad(89))
	
	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input_dir := Vector2(
		float(Input.is_key_pressed(KEY_D) or Input.is_action_pressed("ui_right")) -
		float(Input.is_key_pressed(KEY_A) or Input.is_action_pressed("ui_left")),
		float(Input.is_key_pressed(KEY_S) or Input.is_action_pressed("ui_down")) -
		float(Input.is_key_pressed(KEY_W) or Input.is_action_pressed("ui_up"))
	).limit_length(1.0)
	
	var direction = (head.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
	
	# Handle Highlight and Interaction
	process_interaction()

func process_interaction():
	var current_target = null
	
	if interaction_ray.is_colliding():
		var collider = interaction_ray.get_collider()
		if collider.has_method("set_highlight"):
			current_target = collider

	# Change highlight target
	if current_target != last_highlighted_target:
		if last_highlighted_target:
			last_highlighted_target.set_highlight(false)
			if hud: hud.set_item_name("")
		
		if current_target:
			current_target.set_highlight(true)
			if hud: hud.set_item_name(current_target.item_name)
		
		last_highlighted_target = current_target

	# Left Mouse Click to Interact
	if current_target and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if not Engine.get_main_loop().has_meta("mouse_clicked"):
			current_target.interact()
			Engine.get_main_loop().set_meta("mouse_clicked", true)
	elif not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if Engine.get_main_loop().has_meta("mouse_clicked"):
			Engine.get_main_loop().remove_meta("mouse_clicked")
