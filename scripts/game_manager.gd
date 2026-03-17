## game_manager.gd — Autoload Singleton
## Quản lý toàn cục: tiền, nâng cấp, dữ liệu upgrade.
extends Node

# ─── SIGNALS ───────────────────────────────────────────────
signal money_changed(new_amount: int)
signal upgrade_purchased(upgrade_id: String)
signal time_changed(hour: int, minute: int)
signal shop_status_changed(is_open: bool)
signal daily_report_ready(data: Dictionary)
signal offline_earnings_ready(amount: int)   # Popup thu nhập offline
signal streak_bonus_ready(streak: int, reward: int)  # Popup streak
signal missions_updated()                    # Daily missions cập nhật
signal mission_completed(mission_id: String) # Hoàn thành 1 mission
signal cart_level_changed(new_level: int)    # Xe Bánh Mì lên đời
signal reputation_changed(new_amount: int)   # Danh tiếng thay đổi
signal menu_unlocked(menu_id: String)        # Mở khóa món mới
signal event_started(event_type: String)     # Sự kiện (Mưa/Rush Hour)
signal tetris_buff_activated()              # Buff tốc độ phục vụ
signal candy_buff_activated()               # Buff tiền tip
signal xiangqi_buff_activated()             # Buff khách VIP

# ─── CURRENCY ──────────────────────────────────────────────
var money: int = 0:
	set(value):
		money = value
		money_changed.emit(money)

# ─── DAILY TRACKING ────────────────────────────────────────
var daily_money: int = 0
var daily_served_count: int = 0
var daily_lost_count: int = 0

# ─── REPUTATION & MENU ─────────────────────────────────────
var reputation: int = 0:
	set(value):
		reputation = value
		reputation_changed.emit(reputation)

var unlocked_menu_items: Array[String] = ["banh_mi_thit"]

## ─── MENU ITEMS DATABASE ─────────────────────────────────────
## Mỗi món có:
##   name        : Tên hiển thị
##   price       : Giá bán (đ)
##   prep_time   : Thời gian chế biến (giây) — ảnh hưởng service_time
##   unlock_level: Cấp độ mở khóa (dùng cho progression gating)
##   rep_cost    : Chi phí Danh tiếng để mở khóa
##   money_cost  : Chi phí Tiền để mở khóa (0 = miễn phí / chỉ cần rep)
##   category    : "food" hoặc "drink"
const MENU_ITEMS = {
	# ─── BÁNH MÌ (Food) ──────────────────────────────────────
	"banh_mi_thit": {
		"name": "Bánh Mì Thịt", "price": 15, "prep_time": 3.0,
		"unlock_level": 0, "rep_cost": 0, "money_cost": 0, "category": "food"
	},
	"banh_mi_pate": {
		"name": "Bánh Mì Pa-tê", "price": 25, "prep_time": 3.5,
		"unlock_level": 2, "rep_cost": 100, "money_cost": 50, "category": "food"
	},
	"banh_mi_heo_quay": {
		"name": "Bánh Mì Heo Quay", "price": 40, "prep_time": 4.0,
		"unlock_level": 5, "rep_cost": 500, "money_cost": 200, "category": "food"
	},
	"banh_mi_cha_ca": {
		"name": "Bánh Mì Chả Cá", "price": 35, "prep_time": 3.8,
		"unlock_level": 4, "rep_cost": 350, "money_cost": 150, "category": "food"
	},
	"banh_mi_bo_kho": {
		"name": "Bánh Mì Bò Kho", "price": 50, "prep_time": 5.0,
		"unlock_level": 7, "rep_cost": 800, "money_cost": 400, "category": "food"
	},
	"banh_mi_ga_xe": {
		"name": "Bánh Mì Gà Xé", "price": 45, "prep_time": 4.2,
		"unlock_level": 6, "rep_cost": 600, "money_cost": 300, "category": "food"
	},
	"banh_mi_xiu_mai": {
		"name": "Bánh Mì Xíu Mại", "price": 55, "prep_time": 4.5,
		"unlock_level": 8, "rep_cost": 1000, "money_cost": 500, "category": "food"
	},
	# ─── ĐỒ UỐNG (Drinks) ───────────────────────────────────
	"tra_da": {
		"name": "Trà Đá", "price": 5, "prep_time": -0.3,
		"unlock_level": 1, "rep_cost": 50, "money_cost": 20, "category": "drink"
	},
	"nuoc_mia": {
		"name": "Nước Mía", "price": 10, "prep_time": -0.5,
		"unlock_level": 3, "rep_cost": 200, "money_cost": 80, "category": "drink"
	},
	"ca_phe_sua_da": {
		"name": "Cà Phê Sữa Đá", "price": 20, "prep_time": -0.8,
		"unlock_level": 5, "rep_cost": 400, "money_cost": 150, "category": "drink"
	},
}

# ─── TIME & FEVER ──────────────────────────────────────────
var current_day: int = 1
var time_of_day: float = 5.5  # 5.5 = 05:30
var time_scale: float = 24.0 / 900.0   # 15 phút đời thực = 1 ngày game
var is_shop_open: bool = true
var current_hour: int = 5
var current_minute: int = 30

var boost_energy: float = 0.0
var is_fever_mode: bool = false
var fever_timer: float = 0.0
const MAX_FEVER_TIME: float = 30.0  # Fever kéo dài 30 giây

# ─── DYNAMIC EVENTS ──────────────────────────────────────────
var current_event_type: String = "none" # "none", "rain", "rush_hour"

# ─── MINIGAME PROGRESS ───────────────────────────────────────
var has_played_intro: bool = false
var has_played_tutorial: bool = false
var tetris_progress: Dictionary = {}
var candy_progress: Dictionary = {}
var xiangqi_progress: Dictionary = {}

# ─── STREAK & SAVE ────────────────────────────────────────
var login_streak: int = 0
var last_login_date: String = ""  # format: YYYY-MM-DD
var _save_timestamp: int = 0      # Unix time khi save lần cuối

# ─── DAILY MISSIONS ────────────────────────────────────────
const MISSION_POOL: Array[Dictionary] = [
	{"id": "serve_10",  "desc": "Phục vụ 10 khách",         "type": "serve",  "target": 10,  "reward": 50},
	{"id": "serve_20",  "desc": "Phục vụ 20 khách",         "type": "serve",  "target": 20,  "reward": 120},
	{"id": "earn_200",  "desc": "Kiếm 200đ trong ngày",     "type": "earn",   "target": 200, "reward": 80},
	{"id": "earn_500",  "desc": "Kiếm 500đ trong ngày",     "type": "earn",   "target": 500, "reward": 200},
	{"id": "no_loss",   "desc": "Không để ai bỏ đi (1 ngày)","type": "no_loss","target": 0,   "reward": 150},
	{"id": "serve_vip", "desc": "Phục vụ 3 khách VIP",      "type": "serve_vip","target": 3,  "reward": 100},
]
var active_missions: Array[Dictionary] = []  # 3 missions mỗi ngày
var vip_served_today: int = 0

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

func get_upgrade_effect_sum(effect_key: String) -> float:
	var sum: float = 0.0
	for upg in UPGRADES:
		if upg.effect_key == effect_key:
			var lvl: int = upgrade_levels.get(upg.id, 0)
			sum += upg.effect_value * lvl
	return sum

func get_service_time() -> float:
	var actual_time := base_service_time + get_upgrade_effect_sum("service_time")
	
	# Tetris Buff: Tốc độ phục vụ +20% -> giảm 20% thời gian chờ
	if is_tetris_buff_active():
		actual_time *= 0.8
		
	actual_time = maxf(actual_time, 0.5)  # Cap min
	if is_fever_mode:
		return actual_time / 3.0
	return actual_time

## Tính tổng bonus prep_time từ các đồ uống đã mở khóa
## Đồ uống có prep_time âm → giảm thời gian phục vụ
func get_prep_time_bonus() -> float:
	var bonus: float = 0.0
	for item_id in unlocked_menu_items:
		if MENU_ITEMS.has(item_id):
			var item = MENU_ITEMS[item_id]
			if item.category == "drink":
				bonus += item.prep_time  # prep_time âm cho drink
	return bonus

func get_spawn_interval() -> float:
	var t := base_spawn_interval
	for upg in UPGRADES:
		if upg.effect_key == "spawn_rate":
			var lvl: int = upgrade_levels.get(upg.id, 0)
			for i in range(lvl):
				t *= upg.effect_value
				
	# Áp dụng Event Modifier
	if current_event_type == "rush_hour":
		t *= 0.5 # x2 tốc độ spawn
	elif current_event_type == "rain":
		t *= 2.0 # Giảm một nửa tốc độ (chậm gấp đôi)
		
	return maxf(t, 0.5)

func get_sell_price() -> int:
	# Lấy giá của món đắt nhất đã được unlock (khách auto mua món xịn nhất)
	var max_menu_price: int = base_sell_price
	for item_id in unlocked_menu_items:
		if MENU_ITEMS.has(item_id):
			if MENU_ITEMS[item_id].price > max_menu_price:
				max_menu_price = MENU_ITEMS[item_id].price

	var p: int = max_menu_price
	for upg in UPGRADES:
		if upg.effect_key == "sell_price":
			var lvl: int = upgrade_levels.get(upg.id, 0)
			p += int(upg.effect_value) * lvl
			
	# Event buff giá
	if current_event_type == "rain":
		p += 15 # Mưa thì bán đắt hơn 15đ
		
	return p

# ─── FUNCTIONS ─────────────────────────────────────────────
func _ready() -> void:
	for upg in UPGRADES:
		upgrade_levels[upg.id] = 0
	load_game()
	_check_streak()
	_check_offline_earnings()
	_generate_daily_missions()

# ─── MINIGAME BOOST BUFFS ───────────────────────────────────
var tetris_buff_timer: float = 0.0
var candy_buff_timer: float = 0.0
var xiangqi_buff_timer: float = 0.0

func activate_tetris_buff() -> void:
	tetris_buff_timer = 120.0 # 2 minutes
	tetris_buff_activated.emit()
	print("[Buff] Tetris Buff Activated: Service Speed +20%")

func activate_candy_buff() -> void:
	candy_buff_timer = 120.0 # 2 minutes
	candy_buff_activated.emit()
	print("[Buff] Candy Buff Activated: Tips +50%")

func activate_xiangqi_buff() -> void:
	xiangqi_buff_timer = 180.0 # 3 minutes
	xiangqi_buff_activated.emit()
	print("[Buff] Xiangqi Buff Activated: More VIPs (40% chance)")

func is_tetris_buff_active() -> bool: return tetris_buff_timer > 0
func is_candy_buff_active() -> bool: return candy_buff_timer > 0
func is_xiangqi_buff_active() -> bool: return xiangqi_buff_timer > 0

func get_vip_chance() -> float:
	if is_xiangqi_buff_active():
		return 0.40
	return 0.15

func get_tip_multiplier() -> float:
	if is_candy_buff_active():
		return 1.5
	return 1.0

# ─── SAVE / LOAD ───────────────────────────────────────────
const SAVE_PATH = "user://savegame.cfg"

func save_game() -> void:
	var cfg = ConfigFile.new()
	# Currency
	cfg.set_value("Game", "money", money)
	cfg.set_value("Game", "current_day", current_day)
	cfg.set_value("Game", "has_played_intro", has_played_intro)
	cfg.set_value("Game", "has_played_tutorial", has_played_tutorial)
	cfg.set_value("Game", "reputation", reputation)
	cfg.set_value("Game", "unlocked_menu_items", unlocked_menu_items)
	# Upgrades
	for uid in upgrade_levels:
		cfg.set_value("Upgrades", uid, upgrade_levels[uid])
	# Minigame progress
	cfg.set_value("Progress", "tetris", tetris_progress)
	cfg.set_value("Progress", "candy", candy_progress)
	cfg.set_value("Progress", "xiangqi", xiangqi_progress)
	# Streak
	cfg.set_value("Streak", "login_streak", login_streak)
	cfg.set_value("Streak", "last_login_date", last_login_date)
	# Timestamp để tính offline earnings
	cfg.set_value("Meta", "save_timestamp", Time.get_unix_time_from_system())
	cfg.save(SAVE_PATH)

func load_game() -> void:
	var cfg = ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		print("[GameManager] Save mới — không tìm thấy save file")
		return
	# Currency
	money = cfg.get_value("Game", "money", 0)
	current_day = cfg.get_value("Game", "current_day", 1)
	has_played_intro = cfg.get_value("Game", "has_played_intro", false)
	has_played_tutorial = cfg.get_value("Game", "has_played_tutorial", false)
	reputation = cfg.get_value("Game", "reputation", 0)
	var _loaded_menu_items = cfg.get_value("Game", "unlocked_menu_items", null)
	if _loaded_menu_items != null:
		# Ép kiểu an toàn từ Array[Variant] sang Array[String]
		unlocked_menu_items.clear()
		for item in _loaded_menu_items:
			unlocked_menu_items.append(str(item))
	
	# Upgrades
	for upg in UPGRADES:
		upgrade_levels[upg.id] = cfg.get_value("Upgrades", upg.id, 0)
	# Minigame progress
	tetris_progress = cfg.get_value("Progress", "tetris", {})
	candy_progress = cfg.get_value("Progress", "candy", {})
	xiangqi_progress = cfg.get_value("Progress", "xiangqi", {})
	# Streak
	login_streak = cfg.get_value("Streak", "login_streak", 0)
	last_login_date = cfg.get_value("Streak", "last_login_date", "")
	# Timestamp
	_save_timestamp = cfg.get_value("Meta", "save_timestamp", 0)
	print("[GameManager] Load thành công. Tiền: %d, Ngày: %d" % [money, current_day])
	
	# Tính lại tổng cấp độ xe bánh mì sau khi load xong!
	check_cart_level()

# ─── OFFLINE EARNINGS ──────────────────────────────────────
const MAX_OFFLINE_SECONDS := 28800  # 8 giờ tối đa

func _check_offline_earnings() -> void:
	if _save_timestamp <= 0:
		return
	var now: int = int(Time.get_unix_time_from_system())
	var offline_secs: int = int(min(now - _save_timestamp, MAX_OFFLINE_SECONDS))
	if offline_secs < 60:  # Dưới 1 phút thì bỏ qua
		return
	# Tính earn rate: tiền/giây = giá bán / thời gian phục vụ
	var earn_rate: float = get_sell_price() / max(get_service_time(), 0.5)
	# Offline chỉ hiệu quả 30% so với online (không có upgrade effect đầy đủ)
	var offline_amount := int(earn_rate * offline_secs * 0.30)
	if offline_amount > 0:
		money += offline_amount
		print("[GameManager] 💤 Offline %ds → +%dđ" % [offline_secs, offline_amount])
		offline_earnings_ready.emit(offline_amount)

# ─── STREAK ────────────────────────────────────────────────
func _check_streak() -> void:
	var today := Time.get_date_string_from_system()  # "YYYY-MM-DD"
	if last_login_date == today:
		return  # Đã login hôm nay rồi
	var yesterday := _date_yesterday()
	if last_login_date == yesterday:
		login_streak += 1  # Streak tiếp tục
	else:
		login_streak = 1  # Reset streak
	last_login_date = today
	# Phần thưởng tăng dần theo streak
	var reward := 50 + login_streak * 25
	money += reward
	streak_bonus_ready.emit(login_streak, reward)
	print("[GameManager] 🔥 Streak x%d — Thưởng %dđ" % [login_streak, reward])

func _date_yesterday() -> String:
	var unix_yesterday := int(Time.get_unix_time_from_system()) - 86400
	var dict := Time.get_date_dict_from_unix_time(unix_yesterday)
	return "%04d-%02d-%02d" % [dict.year, dict.month, dict.day]

# ─── DAILY MISSIONS ────────────────────────────────────────
func _generate_daily_missions() -> void:
	active_missions.clear()
	var pool := MISSION_POOL.duplicate()
	pool.shuffle()
	for i in range(min(3, pool.size())):
		var m: Dictionary = pool[i].duplicate()
		m["progress"] = 0
		m["completed"] = false
		active_missions.append(m)
	missions_updated.emit()

func _update_mission_progress(type: String, amount: int = 1) -> void:
	for m in active_missions:
		if m.completed:
			continue
		var matched := false
		match type:
			"serve":    matched = (m.type == "serve")
			"earn":     matched = (m.type == "earn")
			"serve_vip":matched = (m.type == "serve_vip")
			"no_loss":  matched = (m.type == "no_loss")  # checked differently
		if matched:
			m["progress"] = m.get("progress", 0) + amount
			if m.type != "no_loss" and m.progress >= m.target:
				_complete_mission(m)
	missions_updated.emit()

func _complete_mission(m: Dictionary) -> void:
	m["completed"] = true
	money += m.reward
	mission_completed.emit(m.id)
	print("[GameManager] ✅ Mission xong: %s → +%dđ" % [m.desc, m.reward])

func check_no_loss_mission() -> void:
	# Gọi khi đóng cửa và daily_lost_count == 0
	for m in active_missions:
		if m.type == "no_loss" and not m.completed:
			if daily_lost_count == 0:
				_complete_mission(m)


func _process(delta: float) -> void:
	# Cập nhật Buff Timers
	if tetris_buff_timer > 0: tetris_buff_timer -= delta
	if candy_buff_timer > 0: candy_buff_timer -= delta
	if xiangqi_buff_timer > 0: xiangqi_buff_timer -= delta

	# Fever timer
	if is_fever_mode:
		fever_timer -= delta
		if fever_timer <= 0:
			is_fever_mode = false
			boost_energy = 0.0
			print("[GameManager] 📉 Fever Mode kết thúc.")
			
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
		_check_events(current_hour, current_minute)

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
		check_no_loss_mission()  # Kiểm tra mission "không để ai bỏ đi"
		save_game()              # Lưu khi kết thúc ngày
		print("[GameManager] 🌙 Đến 01:00 - Đóng cửa & Tổng kết Ngày %d" % current_day)
	
	# MỞ CỬA NGÀY MỚI: 05:30 Sáng
	if hour == 5 and minute == 30 and not is_shop_open:
		is_shop_open = true
		daily_money = 0
		daily_served_count = 0
		daily_lost_count = 0
		vip_served_today = 0
		current_event_type = "none" # Reset event đầu ngày
		shop_status_changed.emit(true)
		_generate_daily_missions()  # Tạo mission mới cho ngày mới
		print("[GameManager] ☀️ Đến 05:30 - Bắt đầu Ngày mới!")

func _check_events(hour: int, minute: int) -> void:
	if not is_shop_open: return
	
	# Event "Trời Mưa": 20% mỗi ngày, bắt đầu từ 08:00
	if hour == 8 and minute == 0 and current_event_type == "none":
		if randf() < 0.2:
			current_event_type = "rain"
			event_started.emit("rain")
			print("[GameManager] 🌧️ Bắt đầu mưa! Khách ít đi nhưng trả nhiều tiền.")
	
	# Event "Giờ Cao Điểm": Cố định 17:00 lúc đi làm về
	if hour == 17 and minute == 0 and current_event_type != "rush_hour":
		current_event_type = "rush_hour"
		event_started.emit("rush_hour")
		print("[GameManager] 🏃 Giờ cao điểm bắt đầu! Khách ra đông nhưng vội vàng.")
		
	# Hết giờ cao điểm: 19:00
	if hour == 19 and minute == 0 and current_event_type == "rush_hour":
		current_event_type = "none"
		event_started.emit("none")
		print("[GameManager] 🚶 Hết giờ cao điểm.")

func add_money(amount: int) -> void:
	money += amount
	if is_shop_open:
		daily_money += amount
		_update_mission_progress("earn", amount)

func record_customer_served(is_vip: bool = false) -> void:
	daily_served_count += 1
	_update_mission_progress("serve", 1)
	
	# Tính điểm reputation
	if is_vip:
		vip_served_today += 1
		reputation += 5
		_update_mission_progress("serve_vip", 1)
	else:
		reputation += 1

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
	check_cart_level() # Check xe sau khi mua
	save_game()  # Lưu sau mỗi lần mua upgrade
	print("[GameManager] Đã mua '%s' (Lv.%d) — Giá: %d" % [upgrade_id, upgrade_levels[upgrade_id], cost])
	return true

func get_upgrade_level(upgrade_id: String) -> int:
	return upgrade_levels.get(upgrade_id, 0)

func get_total_upgrade_level() -> int:
	var total: int = 0
	for lvl in upgrade_levels.values():
		total += lvl
	return total

func check_cart_level() -> void:
	var total := get_total_upgrade_level()
	var new_cart_lvl := 1
	if total >= 12: new_cart_lvl = 3
	elif total >= 5: new_cart_lvl = 2
	
	# Gọi tính năng này mỗi khi Upgrade được mua, hoặc game được Load
	cart_level_changed.emit(new_cart_lvl)

# ─── FEVER MODE ────────────────────────────────────────────
func add_boost_energy(amount: float) -> void:
	if is_fever_mode or not is_shop_open:
		return
	boost_energy = minf(boost_energy + amount, 100.0)
	if boost_energy >= 100.0:
		start_fever_mode()

func start_fever_mode() -> void:
	if is_fever_mode: return
	is_fever_mode = true
	fever_timer = MAX_FEVER_TIME
	print("[GameManager] 🔥 KÍCH HOẠT FEVER MODE! 🔥 Tốc độ x3 trong 30s")

# ─── REPUTATION & MENU CONTROLS ─────────────────────────────

## Kiểm tra xem món ăn có thể mở khóa hay chưa (đủ rep + tiền)
func can_unlock_item(menu_id: String) -> bool:
	if not MENU_ITEMS.has(menu_id): return false
	if unlocked_menu_items.has(menu_id): return false
	var item = MENU_ITEMS[menu_id]
	return reputation >= item.rep_cost and money >= item.money_cost

## Mở khóa món mới — kiểm tra cả Danh tiếng + Tiền
## Trả về true nếu mở khóa thành công
func unlock_menu_item(menu_id: String) -> bool:
	if not can_unlock_item(menu_id):
		return false
	
	var item = MENU_ITEMS[menu_id]
	# Trừ chi phí
	reputation -= item.rep_cost
	money -= item.money_cost
	
	unlocked_menu_items.append(menu_id)
	menu_unlocked.emit(menu_id)
	save_game()
	print("[GameManager] ⭐ Đã mở khóa món: %s (Rep -%d, Tiền -%dđ)" % [
		item.name, item.rep_cost, item.money_cost
	])
	return true
