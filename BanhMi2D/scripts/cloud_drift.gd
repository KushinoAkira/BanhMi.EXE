extends ParallaxLayer
## Animates cloud Sprite2D children drifting from right to left.
## Attach this script to the CloudLayer ParallaxLayer node.

## Base drift speed in pixels per second.
@export var speed: float = 30.0

## Internal array of per-cloud speed multipliers for variety.
var _speed_multipliers: Array[float] = []

func _ready() -> void:
	# Assign each cloud child a random speed multiplier so they move at
	# slightly different rates, producing a more natural look.
	for child in get_children():
		if child is Sprite2D:
			_speed_multipliers.append(randf_range(0.6, 1.4))


func _process(delta: float) -> void:
	var vp_width: float = get_viewport_rect().size.x
	var idx: int = 0

	for child in get_children():
		if child is Sprite2D:
			var sprite := child as Sprite2D
			var multiplier: float = _speed_multipliers[idx] if idx < _speed_multipliers.size() else 1.0

			# Move cloud to the left.
			sprite.position.x -= speed * multiplier * delta

			# When the cloud fully exits the left edge, wrap it back to the right
			# with a small random Y offset so the pattern never looks repetitive.
			var half_w: float = sprite.texture.get_width() * sprite.scale.x * 0.5
			if sprite.position.x + half_w < 0.0:
				sprite.position.x = vp_width + half_w + randf_range(20.0, 120.0)
				sprite.position.y += randf_range(-15.0, 15.0)
				# Clamp Y so clouds stay in the upper portion of the viewport.
				sprite.position.y = clampf(sprite.position.y, 30.0, 160.0)

			idx += 1
