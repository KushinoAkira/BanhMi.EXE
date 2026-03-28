extends Node3D # Hoặc PathFollow3D

@export var walk_speed: float = 1.8
@export var use_initial_scene_height: bool = true
@export var ground_y: float = 0.0
@onready var anim_player = $AnimationPlayer

func _ready():
	if use_initial_scene_height:
		ground_y = global_position.y
	global_position.y = ground_y
	if anim_player.has_animation("mixamo_com"):
		anim_player.play("mixamo_com")

func _process(delta):
	var forward = transform.basis.z
	forward.y = 0.0
	if forward.length_squared() > 0.0001:
		forward = forward.normalized()
		global_position += forward * walk_speed * delta

	global_position.y = ground_y
