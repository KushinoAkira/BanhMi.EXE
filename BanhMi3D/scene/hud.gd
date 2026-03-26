extends CanvasLayer

@onready var item_label = $ItemLabel
@onready var crosshair = $Crosshair
@onready var recipe_label = $RecipeLabel
@onready var notification_label = $NotificationLabel

var notification_timer: SceneTreeTimer = null

func _ready():
	item_label.text = ""
	if recipe_label:
		recipe_label.text = ""
	if notification_label:
		notification_label.text = ""
		notification_label.modulate.a = 0 # Ẩn đi lúc đầu

func set_item_name(new_name: String):
	item_label.text = new_name

func set_recipe_text(text: String):
	if recipe_label:
		recipe_label.text = text

func set_crosshair_highlight(active: bool):
	if active:
		crosshair.color = Color(1, 1, 0, 1.0)
	else:
		crosshair.color = Color(1, 1, 1, 0.8)

func show_notification(text: String, duration: float = 3.0):
	if not notification_label: return
	
	notification_label.text = text
	notification_label.modulate.a = 1.0
	
	# Tạo hiệu ứng mờ dần sau một khoảng thời gian
	var tween = get_tree().create_tween()
	tween.tween_interval(duration)
	tween.tween_property(notification_label, "modulate:a", 0.0, 1.0)
