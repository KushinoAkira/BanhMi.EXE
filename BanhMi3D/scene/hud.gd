extends CanvasLayer

@onready var item_label = $ItemLabel

func _ready():
	# Ban đầu nhãn trống
	item_label.text = ""

func set_item_name(new_name: String):
	item_label.text = new_name
