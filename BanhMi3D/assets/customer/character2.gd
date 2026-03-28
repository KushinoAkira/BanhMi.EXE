extends Node3D # Hoặc PathFollow3D

const SPEED = 35.0
@onready var anim_player = $AnimationPlayer

func _ready():
	if anim_player.has_animation("mixamo_com"):
		anim_player.play("mixamo_com")

func _process(delta):
	var movement = transform.basis.z * SPEED * delta
	global_position += movement
