extends AnimatedSprite2D

func _ready() -> void:
    var frames = SpriteFrames.new()
    frames.add_animation("idle")
    # Tốc độ animation: 4 frame/giây cho 4 ảnh
    frames.set_animation_speed("idle", 4.0)
    frames.set_animation_loop("idle", true)
    
    # Load 4 ảnh idle (Hayz1.png -> Hayz4.png)
    for i in range(1, 5):
        var tex = load("res://assets/sprites/npc/Hayz%d.png" % i)
        frames.add_frame("idle", tex)
        
    self.sprite_frames = frames
    self.play("idle")
