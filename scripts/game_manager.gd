## game_manager.gd — Autoload Singleton
## Quản lý toàn cục: tiền, nâng cấp, dữ liệu upgrade.
extends Node

# ─── SIGNALS ───────────────────────────────────────────────
signal money_changed(new_amount: int)
signal upgrade_purchased(upgrade_id: String)
signal time_changed(hour: int, minute: int)
signal shop_status_changed(is_open: bool) # Tín hiệu đóng/mở cửa
signal daily_report_ready(data: Dictionary) # Gửi dữ liệu tổng kết

# ─── CURRENCY ──────────────────────────────────────────────
var money: int = 0:
	set(value):
		money = value
		money_changed.emit(money)

# ─── DAILY TRACKING ────────────────────────────────────────
var daily_money: int = 0
var daily_served_count: int = 0
var daily_lost_count: int = 0
var is_shop_open: bool = true
var current_day: int = 1

# ─── TIME & DAY/NIGHT ──────────────────────────────────────
var time_of_day: float = 8.0 # Bắt đầu từ 8:00 sáng
var time_scale: float = 24.0 / 900.0   # 15 phút thực tế = 900 giây = 24 giờ game
var current_hour: int = 8
var current_minute: int = 0

# ─── MINIGAME PROGRESS ───────────────────────────────────────
# Lưu trạng thái xem video intro và hướng dẫn
var has_played_intro: bool = false
var has_played_tutorial: bool = false
# Lưu level Tetris đã đạt và số sao { level_id: stars }
var tetris_progress: Dictionary = {}
# Lưu level Candy Crush đã đạt và số sao { level_id: stars }
var candy_progress: Dictionary = {}
# Lưu level Cờ Tướng đã giải { level_id: bool }
var xiangqi_progress: Dictionary = {}

# ─── UPGRADE DATA ──────────────────────────────────────────
# Mỗi upgrade là một Dictionary chứa thông tin hiển thị + hiệu ứng.
# effect_key: tên thuộc tính bị ảnh hưởng
# effect_value: giá trị thay đổi mỗi cấp
# level: số lần đã mua
const UPGRADES: Array[Dictionary] = [
	# ─── TIER 1: Starter (mua nhiều lần, giá tăng chậm) ─────
	{
		"id": "nuoc_tuong",
		"name": "Nước Tương Đặc Biệt",
		"icon": "🫙",
		"description": "Tăng giá bán thêm 5đ",
		"base_cost": 10,
		"cost_multiplier": 1.15,
		"effect_key": "sell_price",
		"effect_value": 5,
	},
	{
		"id": "intern",
		"name": "Thuê Thực tập sinh",
		"icon": "👨‍💻",
		"description": "Giảm 0.2s thời gian phục vụ",
		"base_cost": 25,
		"cost_multiplier": 1.18,
		"effect_key": "service_time",
		"effect_value": -0.2,
	},
	{
    "id": "tuong_ot_chinsu",
    "name": "Tương ớt thần thánh",
    "icon": "🌶️",
    "description": "Tăng giá bán thêm 5đ",
    "base_cost": 10,
    "cost_multiplier": 1.15,
    "effect_key": "sell_price",
    "effect_value": 5,
	}, 
	# ─── TIER 2: Early-Mid (nền tảng kinh doanh) ────────────
	{
		"id": "banh_mi_premium",
		"name": "Bánh Mì Premium",
		"icon": "🥖",
		"description": "Tăng giá bán thêm 15đ",
		"base_cost": 75,
		"cost_multiplier": 1.35,
		"effect_key": "sell_price",
		"effect_value": 15,
	},
	{
		"id": "facebook_ads",
		"name": "Chạy Ads Facebook",
		"icon": "📱",
		"description": "Tăng tốc độ spawn khách 10%",
		"base_cost": 100,
		"cost_multiplier": 1.40,
		"effect_key": "spawn_rate",
		"effect_value": 0.90,
	},
	{
		"id": "overclock_oven",
		"name": "Lò nướng Overclock",
		"icon": "🔥",
		"description": "Giảm 0.4s thời gian phục vụ",
		"base_cost": 200,
		"cost_multiplier": 1.50,
		"effect_key": "service_time",
		"effect_value": -0.4,
	},
	# ─── TIER 3: Late Game (mạnh, đắt, tăng giá nhanh) ─────
	{
		"id": "seo_web",
		"name": "SEO Web Bán Bánh Mì",
		"icon": "🌐",
		"description": "Tăng tốc độ spawn khách 15%",
		"base_cost": 500,
		"cost_multiplier": 1.60,
		"effect_key": "spawn_rate",
		"effect_value": 0.85,
	},
	{
		"id": "auto_pate",
		"name": "Auto-Patê Python Script",
		"icon": "🐍",
		"description": "Giảm 0.6s thời gian phục vụ",
		"base_cost": 1000,
		"cost_multiplier": 1.75,
		"effect_key": "service_time",
		"effect_value": -0.6,
	},
	{
		"id": "ai_kep_cha",
		"name": "AI Kẹp Chả",
		"icon": "🤖",
		"description": "Giảm 1.0s thời gian phục vụ",
		"base_cost": 2500,
		"cost_multiplier": 2.0,
		"effect_key": "service_time",
		"effect_value": -1.0,
	},
]

# Lưu level hiện tại của từng upgrade
var upgrade_levels: Dictionary = {}

# ─── DERIVED STATS (tính từ upgrades) ────────────────────
var base_service_time: float = 3.0     # giây
var base_spawn_interval: float = 4.0   # giây
var base_sell_price: int = 15          # tiền mỗi ổ bánh mì

func get_service_time() -> float:
	var t := base_service_time
	for upg in UPGRADES:
		if upg.effect_key == "service_time":
			var lvl: int = upgrade_levels.get(upg.id, 0)
			t += upg.effect_value * lvl
	return maxf(t, 0.5)  # tối thiểu 0.5s

func get_spawn_interval() -> float:
	var t := base_spawn_interval
	for upg in UPGRADES:
		if upg.effect_key == "spawn_rate":
			var lvl: int = upgrade_levels.get(upg.id, 0)
			for i in range(lvl):
				t *= upg.effect_value
	return maxf(t, 0.5)

func get_sell_price() -> int:
	var p := base_sell_price
	for upg in UPGRADES:
		if upg.effect_key == "sell_price":
			var lvl: int = upgrade_levels.get(upg.id, 0)
			p += int(upg.effect_value) * lvl
	return p

# ─── FUNCTIONS ─────────────────────────────────────────────
func _ready() -> void:
	# Khởi tạo level = 0 cho tất cả upgrade
	for upg in UPGRADES:
		upgrade_levels[upg.id] = 0

func _process(delta: float) -> void:
	# Cập nhật thời gian
	time_of_day += delta * time_scale
	if time_of_day >= 24.0:
		time_of_day -= 24.0
		current_day += 1
		
	var new_hour: int = int(time_of_day)
	var new_minute: int = int((time_of_day - new_hour) * 60)
	
	if new_minute != current_minute or new_hour != current_hour:
		current_hour = new_hour
		current_minute = new_minute
		time_changed.emit(current_hour, current_minute)
		_check_shop_schedule(current_hour, current_minute)

## Kiểm tra lịch đóng/mở cửa hàng
func _check_shop_schedule(hour: int, minute: int) -> void:
	# ĐÓNG CỬA & TỔNG KẾT: 01:00 Sáng
	if hour == 1 and minute == 0 and is_shop_open:
		is_shop_open = false
		shop_status_changed.emit(false)
		
		var report = {
			"day": current_day,
			"money": daily_money,
			"served": daily_served_count,
			"lost": daily_lost_count
		}
		daily_report_ready.emit(report)
		print("[GameManager] 🌙 Đến 01:00 - Đóng cửa & Tổng kết Ngày %d" % current_day)
	
	# MỞ CỬA NGÀY MỚI: 05:30 Sáng
	if hour == 5 and minute == 30 and not is_shop_open:
		is_shop_open = true
		daily_money = 0
		daily_served_count = 0
		daily_lost_count = 0
		shop_status_changed.emit(true)
		print("[GameManager] ☀️ Đến 05:30 - Bắt đầu Ngày mới!")

func add_money(amount: int) -> void:
	money += amount
	if is_shop_open:
		daily_money += amount

func record_customer_served() -> void:
	daily_served_count += 1

func record_customer_lost() -> void:
	daily_lost_count += 1

func get_upgrade_cost(upgrade_id: String) -> int:
	for upg in UPGRADES:
		if upg.id == upgrade_id:
			var lvl: int = upgrade_levels.get(upgrade_id, 0)
			return int(upg.base_cost * pow(upg.cost_multiplier, lvl))
	return 999999

func buy_upgrade(upgrade_id: String) -> bool:
	var cost := get_upgrade_cost(upgrade_id)
	if money < cost:
		return false
	money -= cost
	upgrade_levels[upgrade_id] = upgrade_levels.get(upgrade_id, 0) + 1
	upgrade_purchased.emit(upgrade_id)
	print("[GameManager] Đã mua '%s' (Lv.%d) — Giá: %d" % [upgrade_id, upgrade_levels[upgrade_id], cost])
	return true

func get_upgrade_level(upgrade_id: String) -> int:
	return upgrade_levels.get(upgrade_id, 0)
