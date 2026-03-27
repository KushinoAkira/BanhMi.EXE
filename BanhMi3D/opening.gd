extends Control

# Danh sách hội thoại
var script_data = [
	"[Sếp]: An này... Check mail chưa?",
	"[Sếp]: Công ty đang tái cấu trúc. Em thuộc diện 'tinh gọn'.",
	"[Sếp]: Cầm 2 tháng lương rồi logout trước 5 giờ nhé.",
	"[An]: ...Vâng. Em hiểu rồi. Coi như 'release' bản thân luôn.",
	" ", # Khoảng lặng (Màn hình trống)
	"............	",
	"[Ba]: Alo, An hả con? Sao, dự án gì đó xong chưa?",
	"[Ba]: Không xong thì thôi, dẹp đi. Về đây với Ba.",
	"[Ba]: Cái xe bánh mì của nội mày tao mới sơn lại, để không cũng uổng...",
	"[An]: Ba à... con mới 'fix bug' xong cuộc đời con rồi. Mai con về."
]

var current_line_index = 0
@onready var label = $DialogueLabel
@onready var sfx = $SfxTyping

func _ready():
	label.text = ""
	play_dialogue()

func play_dialogue():
	if current_line_index < script_data.size():
		var full_text = script_data[current_line_index]
		await type_text(full_text)
		
		# Chờ người chơi đọc xong (1.5 giây) rồi sang câu tiếp theo
		await get_tree().create_timer(1.5).timeout
		current_line_index += 1
		play_dialogue()
	else:
		# Hết thoại, chuyển sang Scene Game chính (Bán bánh mì)
		get_tree().change_scene_to_file("res://scene/main2.tscn")

func type_text(text_to_type: String):
	label.text = "" # Xóa chữ cũ
	
	for i in range(text_to_type.length()):
		label.text += text_to_type[i] # Thêm từng chữ vào Label
		
		# KIỂM TRA: Phát âm thanh NGAY TẠI ĐÂY (trong vòng lặp)
		if text_to_type[i] != " ": # Không phát tiếng khi gặp khoảng trắng cho tự nhiên
			# Nếu sound đang chạy thì dừng và chạy lại ngay (tránh bị nuốt tiếng khi gõ nhanh)
			if sfx.playing:
				sfx.stop() 
			sfx.play(0.08)
			
		# Đợi một khoảng thời gian ngắn rồi mới lặp tiếp chữ sau
		await get_tree().create_timer(0.06).timeout
