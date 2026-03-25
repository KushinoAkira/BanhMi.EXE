extends CanvasLayer

@onready var item_label = $ItemLabel
@onready var crosshair = $Crosshair

func _ready():
	# Ban đầu nhãn trống
	item_label.text = ""

func set_item_name(new_name: String):
	item_label.text = new_name

func set_crosshair_highlight(active: bool):
	if active:
		crosshair.color = Color(1, 1, 0, 1.0) # Màu vàng khi nhắm trúng
	else:
		crosshair.color = Color(1, 1, 1, 0.8) # Trở về trắng mờ bình thường
