extends CanvasLayer

var dialogues = {
	1: ["Ông Hayz: Chào ngày mới! Hôm nay là ngày đầu mình mở bán.", "Ông Hayz: Hy vọng mọi người sẽ ủng hộ bánh mì của mình!"],
	2: ["Ông Hayz: Thật bất ngờ! Khách có vẻ thích ăn bánh mì Pa-tê.", "Ông Hayz: Mình nên kiếm tiền nhập thêm Bánh Mì để bán cho đủ khách."],
	3: ["Khách quen: Chào chú Hayz! Cho con 1 ổ y như cũ nhé.", "Ông Hayz: Có ngay! Dạo này con đi học sớm thế?"],
	4: ["Ông Hayz: Kinh doanh có vẻ khấm khá, có khi mình nên mua thêm Loa Phóng Thanh để hút khách."],
	5: ["Khách du lịch: Hello! This sandwich is amazing!", "Ông Hayz: Haha, thanks! Cứ từ từ mà thưởng thức nhé."]
}

var current_line: int = 0
var daily_lines: Array = []

var panel: PanelContainer
var lbl_name: Label
var lbl_text: Label

func _ready() -> void:
	layer = 120
	hide()
	
	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(800, 150)
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_bottom = -30
	panel.offset_left = 50
	panel.offset_right = -50
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	style.border_color = Color(0.5, 0.8, 1.0)
	style.set_border_width_all(3)
	style.set_corner_radius_all(12)
	style.content_margin_left = 20
	style.content_margin_top = 20
	style.content_margin_right = 20
	style.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	panel.add_child(vbox)
	
	lbl_name = Label.new()
	lbl_name.add_theme_font_size_override("font_size", 24)
	lbl_name.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
	vbox.add_child(lbl_name)
	
	lbl_text = Label.new()
	lbl_text.add_theme_font_size_override("font_size", 20)
	lbl_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_text.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(lbl_text)
	
	var lbl_prompt = Label.new()
	lbl_prompt.text = "Nhấn để tiếp tục..."
	lbl_prompt.add_theme_font_size_override("font_size", 14)
	lbl_prompt.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	lbl_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vbox.add_child(lbl_prompt)
	
	add_child(panel)
	
	GameManager.time_changed.connect(_on_time_changed)

func _on_time_changed(hour: int, minute: int) -> void:
	# Kích hoạt cốt truyện lúc 05:30 (Mở màn mỗi ngày)
	if hour == 5 and minute == 30:
		_check_day_story(GameManager.current_day)

func _check_day_story(day: int) -> void:
	if dialogues.has(day):
		daily_lines = dialogues[day]
		current_line = 0
		_show_next_line()
		show()
		get_tree().paused = true

func _show_next_line() -> void:
	if current_line >= daily_lines.size():
		hide()
		get_tree().paused = false
		return
		
	var line_raw: String = daily_lines[current_line]
	var parts = line_raw.split(": ", false, 1)
	if parts.size() > 1:
		lbl_name.text = parts[0]
		lbl_text.text = parts[1]
	else:
		lbl_name.text = ""
		lbl_text.text = parts[0]
		
	current_line += 1

func _input(event: InputEvent) -> void:
	if not visible: return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_show_next_line()
		get_viewport().set_input_as_handled()
