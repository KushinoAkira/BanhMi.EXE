## game_manager.gd — Autoload Singleton
## Quản lý toàn cục: tiền, nâng cấp, dữ liệu upgrade.
extends Node

# ─── SIGNALS ───────────────────────────────────────────────
signal money_changed(new_amount: int)
signal upgrade_purchased(upgrade_id: String)

# ─── CURRENCY ──────────────────────────────────────────────
var money: int = 0:
	set(value):
		money = value
		money_changed.emit(money)

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

func add_money(amount: int) -> void:
	money += amount

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
