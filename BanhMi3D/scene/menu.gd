extends VBoxContainer

const WORLD = preload("res://scene/main.tscn")

# 1. Khai báo các biến âm thanh (Đảm bảo tên sau dấu $ khớp với tên Node trong Scene)
@onready var sfx_click = $SfxClick
@onready var sfx_hover = $SfxHover

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# 2. Tự động kết nối hiệu ứng Hover cho tất cả Button con của VBoxContainer
	for button in get_children():
		if button is Button:
			button.mouse_entered.connect(_on_button_mouse_entered)

# Hàm xử lý khi di chuột vào nút
func _on_button_mouse_entered():
	sfx_hover.play()

func _on_play_pressed() -> void:
	sfx_click.play()
	# Đợi một chút để tiếng click vang lên rồi mới chuyển cảnh
	await get_tree().create_timer(0.15).timeout
	get_tree().change_scene_to_packed(WORLD)

func _on_quit_pressed() -> void:
	sfx_click.play()
	# Đợi tiếng click chạy xong mới thoát game
	await get_tree().create_timer(0.2).timeout
	get_tree().quit()
