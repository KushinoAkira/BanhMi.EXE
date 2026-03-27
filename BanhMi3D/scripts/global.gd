extends Node

# ===== SIGNALS =====
signal money_changed(new_val)
signal day_changed(is_day_now)
signal furniture_purchased(new_count)
signal day_ended(stats: Dictionary)
signal new_day_started(day_number: int)
signal weather_changed(is_raining: bool)
signal time_phase_changed(phase: int)

# ===== THỜI GIAN =====
enum TimePhase { MORNING, AFTERNOON, EVENING, NIGHT }

const DAY_START_HOUR: float = 5.0      # 5:00 AM sáng nay
const DAY_END_HOUR: float = 29.0       # 5:00 AM sáng mai (24 + 5)
const SHOP_CLOSE_HOUR: float = 26.5    # 2:30 AM bắt đầu dọn quán
const TOTAL_HOURS: float = 24.0        # Chu kỳ 24 tiếng thực thụ

const DAY_DURATION: float = 300.0      # 5 phút thực tế = 1 ngày game (Tăng tốc độ gấp đôi)
const NIGHT_DURATION: float = 6.0       # 6 giây thực tế hiện bảng tổng kết

# ===== DANH NGÔN SUY NGẪM =====
const QUOTES = [
	"Nếu cuộc đời là một mã nguồn (source code) đang chạy, tôi đang viết tiếp những tính năng đột phá hay chỉ đang bận rộn 'vá lỗi' cho những sai lầm của ngày hôm qua?",
	"Ngày hôm nay, tôi là người chủ động thiết kế nên giải pháp, hay chỉ là một 'end-user' đang thụ động phản ứng lại những yêu cầu của thế giới xung quanh?",
	"Những gì tôi đang xây dựng hiện tại có đủ ý nghĩa để tồn tại lâu hơn chính bản thân tôi?"
]

# ===== STATE =====
var money: int = 100000
var furniture_count: int = 1
var is_day: bool = true
var is_shop_open: bool = false
var furniture_out: bool = false
var is_overtime: bool = false
var is_night_summary: bool = false  # Đang hiện bảng tổng kết
var is_transition_black: bool = false # Đang hiện màn hình đen suy ngẫm

var day_number: int = 1
var current_phase: int = TimePhase.MORNING
var day_elapsed: float = 0.0   # giây thực tế đã trôi qua

# Thống kê
var daily_earnings: int = 0
var daily_orders_completed: int = 0
var daily_tip_total: int = 0
var is_raining: bool = false

func _ready():
	randomize()

func start_new_day():
	day_number += 1
	day_elapsed = 0.0
	is_day = true
	is_shop_open = false
	furniture_out = false
	is_overtime = false
	is_night_summary = false
	is_transition_black = false
	
	daily_earnings = 0
	daily_orders_completed = 0
	daily_tip_total = 0
	current_phase = TimePhase.MORNING

	var new_is_raining = randf() < 0.3
	if new_is_raining != is_raining:
		is_raining = new_is_raining
		weather_changed.emit(is_raining)
	
	day_changed.emit(false) 
	new_day_started.emit(day_number)
	time_phase_changed.emit(current_phase)

func add_earnings(base_amount: int, tip_amount: int):
	money += base_amount + tip_amount
	daily_earnings += base_amount + tip_amount
	daily_tip_total += tip_amount
	daily_orders_completed += 1
	money_changed.emit(money)

func end_day():
	is_day = false
	is_night_summary = true
	day_changed.emit(false)
	var stats = {
		"day_number": day_number,
		"earnings": daily_earnings,
		"orders": daily_orders_completed,
		"tips": daily_tip_total,
		"is_raining": is_raining
	}
	day_ended.emit(stats)
