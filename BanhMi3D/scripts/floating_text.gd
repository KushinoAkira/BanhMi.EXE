extends Label3D

func _ready():
	font_size = 32
	outline_size = 8
	scale = Vector3(1.2, 1.2, 1.2)
	
	# Tạo hiệu ứng thu nhỏ và mờ dần (chìm xuống)
	var tween = get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector3.ZERO, 1.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, 1.0)
	
	# Hủy node sau 1 giây
	get_tree().create_timer(1.0).timeout.connect(queue_free)

func show_text(txt: String, color: Color = Color.WHITE):
	text = txt
	modulate = color
