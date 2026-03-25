extends CanvasLayer

signal story_finished

@onready var cloud_left := ColorRect.new()
@onready var cloud_right := ColorRect.new()
@onready var portrait_tex := TextureRect.new()
@onready var dialog_box := PanelContainer.new()
@onready var name_label := Label.new()
@onready var text_label := RichTextLabel.new()

var sfx_boop: AudioStreamPlayer

var dialog_lines = [
	{ "name": "Hayz", "text": "Phù... cuối cùng cũng 'deploy' xong cái xe bánh mì này lên môi trường thực tế." },
	{ "name": "Hayz", "text": "Nghĩ lại thấy đời đúng là không lường trước được điều gì. Mới ngày nào còn ngồi cày cuốc đồ án .NET mỏi tay, cắm mặt vào mớ lý thuyết kiến trúc máy tính..." },
	{ "name": "Hayz", "text": "Thế mà đùng một cái, nguyên dàn nhân sự bị mấy con AI đá văng khỏi công ty. Tối ưu hóa hệ thống thì nhanh đấy..." },
	{ "name": "Hayz", "text": "...Nhưng mấy thuật toán đó có biết pha nước sốt pate không? Có biết canh lửa nướng thịt cho xém cạnh không? Chắc chắn là báo lỗi 'NullReferenceException' ngay!" },
	{ "name": "Hayz", "text": "Được rồi, không code web nữa thì ta code... bánh mì. Đầu tiên phải xây dựng tập khách hàng cốt lõi." },
	{ "name": "Hayz", "text": "Theo 'Business Requirements', mình cần phải thu thập vốn bằng việc cày minigame giải trí ở góc mặt tiền." },
	{ "name": "Hayz", "text": "Sau đó sẽ dùng nguồn vốn (Capital) này để scale-up (nâng cấp) các nguyên liệu thành phần, tối ưu hóa lợi nhuận / giây!" },
	{ "name": "Hayz", "text": "OK, để mình hướng dẫn bạn cách vận hành hệ thống 'Banh Mi.EXE' này nhé. Compile & Run!" }
]
var current_line := 0

func _ready() -> void:
	layer = 90 # Below the absolute top, but above game UI
	
	# Create Clouds for transition
	_setup_clouds()
	_setup_ui()
	
	# Load SFX
	sfx_boop = AudioStreamPlayer.new()
	sfx_boop.stream = load("res://assets/Music/text_boop.mp3")
	add_child(sfx_boop)
	
	# Start transition
	_play_cloud_open()

func _setup_clouds() -> void:
	var screen_size = get_viewport().get_visible_rect().size
	
	# We use white ColorRects to act as clouds for simplicity
	cloud_left.color = Color.WHITE
	cloud_left.size = Vector2(screen_size.x / 2 + 50, screen_size.y)
	cloud_left.position = Vector2(0, 0)
	add_child(cloud_left)
	
	cloud_right.color = Color.WHITE
	cloud_right.size = Vector2(screen_size.x / 2 + 50, screen_size.y)
	cloud_right.position = Vector2(screen_size.x / 2, 0)
	add_child(cloud_right)

func _setup_ui() -> void:
	var screen_size = get_viewport().get_visible_rect().size
	
	# Portrait
	portrait_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait_tex.custom_minimum_size = Vector2(300, 300)
	portrait_tex.position = Vector2(screen_size.x / 2 - 150, screen_size.y / 2 - 250)
	portrait_tex.modulate = Color(1,1,1,0) # Hidden initially
	# Try to load the generated portrait
	var tex = load("res://assets/sprites/ui/hayz_portrait.png")
	if tex: portrait_tex.texture = tex
	add_child(portrait_tex)
	
	# Dialog Box
	dialog_box.size = Vector2(screen_size.x - 40, 250)
	dialog_box.position = Vector2(20, screen_size.y - 280)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.2, 0.9)
	style.border_width_top = 4
	style.border_color = Color(0.4, 0.8, 1.0, 1)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	dialog_box.add_theme_stylebox_override("panel", style)
	dialog_box.modulate = Color(1,1,1,0)
	add_child(dialog_box)
	
	var vbox = VBoxContainer.new()
	dialog_box.add_child(vbox)
	
	name_label.add_theme_font_size_override("font_size", 28)
	name_label.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
	vbox.add_child(name_label)
	
	var sep = HSeparator.new()
	vbox.add_child(sep)
	
	text_label.add_theme_font_size_override("normal_font_size", 24)
	text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_label.bbcode_enabled = true
	vbox.add_child(text_label)
	
	var hint = Label.new()
	hint.text = "Chạm để tiếp tục ▼"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	vbox.add_child(hint)

func _play_cloud_open() -> void:
	var screen_size = get_viewport().get_visible_rect().size
	var tween = create_tween().set_parallel(true)
	# Slide clouds apart
	tween.tween_property(cloud_left, "position:x", -cloud_left.size.x, 1.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(cloud_right, "position:x", screen_size.x + 50, 1.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	
	# Fade in character and dialog box after clouds part
	tween.chain().tween_property(portrait_tex, "modulate:a", 1.0, 0.5)
	tween.parallel().tween_property(dialog_box, "modulate:a", 1.0, 0.5)
	
	tween.tween_callback(_show_current_line)

func _show_current_line() -> void:
	if current_line >= dialog_lines.size():
		_end_story()
		return
		
	var line_data = dialog_lines[current_line]
	name_label.text = line_data["name"]
	text_label.text = line_data["text"]
	
	# Simple pop animation for portrait
	var tween = create_tween()
	tween.tween_property(portrait_tex, "scale", Vector2(1.05, 1.05), 0.1)
	tween.tween_property(portrait_tex, "scale", Vector2(1.0, 1.0), 0.1)

func _input(event: InputEvent) -> void:
	# Ignore input if UI is not fully visible yet
	if dialog_box.modulate.a < 1.0: return
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if sfx_boop: sfx_boop.play()
		current_line += 1
		_show_current_line()
	elif event is InputEventScreenTouch and event.pressed:
		if sfx_boop: sfx_boop.play()
		current_line += 1
		_show_current_line()

func _end_story() -> void:
	# Fade out
	var tween = create_tween().set_parallel(true)
	tween.tween_property(portrait_tex, "modulate:a", 0.0, 0.5)
	tween.tween_property(dialog_box, "modulate:a", 0.0, 0.5)
	tween.chain().tween_callback(func(): 
		story_finished.emit()
		queue_free()
	)
