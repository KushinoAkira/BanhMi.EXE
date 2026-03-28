extends Node3D # Hoặc PathFollow3D

@export var walk_speed: float = 1.8
@export var use_initial_scene_height: bool = true
@export var ground_y: float = 0.0
@onready var anim_player = $AnimationPlayer

func _ready():
	if use_initial_scene_height:
		ground_y = global_position.y
	global_position.y = ground_y
	if anim_player.has_animation("Take 001"):
		anim_player.play("Take 001")

func _process(delta):
	# Giữ NPC đi ngang mặt đất để tránh lệch cao độ khi xoay model.
	var forward = transform.basis.z
	forward.y = 0.0
	if forward.length_squared() > 0.0001:
		forward = forward.normalized()
		global_position += forward * walk_speed * delta

	global_position.y = ground_y
