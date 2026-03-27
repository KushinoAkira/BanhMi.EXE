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

const DAY_DURATION: float = 240.0    # 4 phút = 1 ngày game (MORNING + AFTERNOON + EVENING)
const NIGHT_DURATION: float = 30.0   # 30 giây đêm (tổng kết)

const MORNING_RATIO: float = 0.25    # 25% ngày = sáng
const AFTERNOON_RATIO: float = 0.50  # 50% ngày = trưa/chiều
const EVENING_RATIO: float = 0.25    # 25% ngày = chiều tối

# ===== STATE =====
var money: int = 100000
var furniture_count: int = 1
var is_day: bool = true

# Ngày / Thời gian
var day_number: int = 1
var current_phase: int = TimePhase.MORNING
var day_elapsed: float = 0.0   # giây đã trôi qua trong ngày
var is_night_summary: bool = false  # đang hiện bảng tổng kết đêm

# Thống kê ngày hiện tại
var daily_earnings: int = 0
var daily_orders_completed: int = 0
var daily_tip_total: int = 0

# Thời tiết
var is_raining: bool = false

func _ready():
	randomize()

func start_new_day():
	day_number += 1
	day_elapsed = 0.0
	is_day = true
	is_night_summary = false
	daily_earnings = 0
	daily_orders_completed = 0
	daily_tip_total = 0
	current_phase = TimePhase.MORNING

	# Thời tiết ngẫu nhiên: 30% khả năng mưa
	var new_is_raining = randf() < 0.3
	if new_is_raining != is_raining:
		is_raining = new_is_raining
		weather_changed.emit(is_raining)
	
	day_changed.emit(true)
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
