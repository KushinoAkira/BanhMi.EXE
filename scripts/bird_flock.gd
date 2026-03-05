extends Node2D
## Attach to a Node2D inside SkyLayer to handle bird flocks.

const BIRD_TEX = preload("res://assets/sprites/sky/bird.png")
@export var flock_size: int = 5
@export var base_speed: float = 60.0

var birds: Array[Sprite2D] = []
var speeds: Array[float] = []
var time: float = 0.0

func _ready() -> void:
	for i in range(flock_size):
		var b = Sprite2D.new()
		b.texture = BIRD_TEX
		# Random start positions off-screen left
		b.position = Vector2(randf_range(-400, -50), randf_range(50, 200))
		b.scale = Vector2(0.5, 0.5)
		add_child(b)
		birds.append(b)
		speeds.append(base_speed + randf_range(-15, 15))

func _process(delta: float) -> void:
	time += delta
	var vp_width = get_viewport_rect().size.x

	for i in range(birds.size()):
		var b = birds[i]
		# Move right and slightly up/down in a sine wave
		b.position.x += speeds[i] * delta
		b.position.y += sin(time * 5.0 + i) * 0.5

		# Simple flap animation using Y scale
		b.scale.y = 0.5 + sin(time * 10.0 + i) * 0.2

		# Loop back when off right screen
		if b.position.x > vp_width + 100:
			b.position.x = randf_range(-200, -50)
			b.position.y = randf_range(50, 200)
			speeds[i] = base_speed + randf_range(-15, 15)
