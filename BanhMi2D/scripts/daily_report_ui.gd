## daily_report_ui.gd — Hiển thị bảng tổng kết cuối ngày
extends CanvasLayer

@onready var panel = $Control/Panel
@onready var title_label = $Control/Panel/VBox/Title
@onready var detail_label = $Control/Panel/VBox/Details

func _ready() -> void:
	panel.visible = false
	GameManager.daily_report_ready.connect(_on_daily_report_ready)
	GameManager.shop_status_changed.connect(_on_shop_status_changed)

func _on_daily_report_ready(data: Dictionary) -> void:
	title_label.text = "TỔNG KẾT NGÀY %d" % data.day
	detail_label.text = "💰 Doanh thu: %dđ\n✅ Phục vụ: %d khách\n❌ Bỏ lỡ: %d khách" % [
		data.money, data.served, data.lost
	]
	panel.visible = true

func _on_shop_status_changed(is_open: bool) -> void:
	if is_open:
		panel.visible = false
