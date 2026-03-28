extends Node3D # Hoặc PathFollow3D

const SPEED = 40.0
@onready var anim_player = $AnimationPlayer

func _ready():
	if anim_player.has_animation("Take 001"):
		anim_player.play("Take 001")

func _process(delta):
	# Di chuyển trực tiếp vị trí (tọa độ toàn cục)
	# Vector3.FORWARD là hướng đi thẳng theo trục của model
	var movement = transform.basis.z * SPEED * delta
	global_position += movement
