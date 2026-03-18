## cart_manager.gd — Autoload Singleton
## Quản lý hệ thống chuỗi xe Bánh Mì (Multiple Carts)
## Mỗi xe mở rộng hoạt động độc lập, tạo thu nhập bị động (Passive Income)
extends Node

# ─── SIGNALS ───────────────────────────────────────────────
signal cart_activated(cart_id: String)       ## Xe mới được kích hoạt
signal revenue_ready(amount: int)           ## Có tiền chờ thu thập
signal revenue_collected(amount: int)       ## Người chơi đã thu tiền

# ─── CART TIERS DATA ──────────────────────────────────────
## Dữ liệu các cấp xe mở rộng — dễ dàng thêm xe thứ 3, 4, 5...
## Mỗi xe cần:
##   id            : ID duy nhất
##   name          : Tên hiển thị
##   cost          : Chi phí mua (tiền)
##   rep_required  : Danh tiếng tối thiểu để mua
##   income_per_sec: Thu nhập bị động mỗi giây
##   description   : Mô tả vị trí / đặc điểm xe
const CART_TIERS: Array[Dictionary] = [
	{
		"id": "cart_2",
		"name": "Xe Bánh Mì #2",
		"description": "Đặt ở Ngã tư Bình Thạnh — khu vực đông sinh viên",
		"cost": 5000,
		"rep_required": 2000,
		"income_per_sec": 2.0,
	},
	{
		"id": "cart_3",
		"name": "Xe Bánh Mì #3",
		"description": "Đặt ở Chợ Bến Thành — khách du lịch nhiều",
		"cost": 15000,
		"rep_required": 5000,
		"income_per_sec": 5.0,
	},
	{
		"id": "cart_4",
		"name": "Xe Bánh Mì #4",
		"description": "Đặt ở Phú Mỹ Hưng — khu dân cư cao cấp",
		"cost": 50000,
		"rep_required": 10000,
		"income_per_sec": 12.0,
	},
]

# ─── STATE ────────────────────────────────────────────────
## Dictionary lưu trạng thái mỗi xe đã mua
## Key: cart_id, Value: { "active": true, "pending_revenue": float }
var owned_carts: Dictionary = {}

# ─── READY ────────────────────────────────────────────────
func _ready() -> void:
	_load_carts()
	print("[CartManager] Khởi tạo xong. Xe đang hoạt động: %d" % owned_carts.size())

# ─── PROCESS — Tích lũy Passive Income ──────────────────
func _process(delta: float) -> void:
	if owned_carts.is_empty():
		return
	# Chỉ tích lũy khi cửa hàng chính đang mở
	if not GameManager.is_shop_open:
		return
	
	for cart_id in owned_carts:
		var cart_state: Dictionary = owned_carts[cart_id]
		if not cart_state.get("active", false):
			continue
		
		# Tìm tier data để lấy income_per_sec
		var tier = _get_tier_data(cart_id)
		if tier.is_empty():
			continue
		
		# Tích lũy thu nhập
		cart_state["pending_revenue"] = cart_state.get("pending_revenue", 0.0) + tier.income_per_sec * delta
	
	# Phát signal nếu có tiền chờ thu
	var total_pending := _get_total_pending()
	if total_pending >= 1.0:
		revenue_ready.emit(int(total_pending))

# ─── PUBLIC API ──────────────────────────────────────────

## Kiểm tra xem có thể mua xe hay không
func can_purchase_cart(cart_id: String) -> bool:
	if owned_carts.has(cart_id):
		return false  # Đã sở hữu rồi
	
	var tier = _get_tier_data(cart_id)
	if tier.is_empty():
		return false  # ID không hợp lệ
	
	# Kiểm tra đã mua xe trước đó chưa (phải mua theo thứ tự)
	var tier_index = _get_tier_index(cart_id)
	if tier_index > 0:
		var prev_tier = CART_TIERS[tier_index - 1]
		if not owned_carts.has(prev_tier.id):
			return false  # Chưa mua xe trước đó
	
	return GameManager.reputation >= tier.rep_required and GameManager.money >= tier.cost

## Mua xe mới — trừ tiền, kích hoạt xe, emit signal
func purchase_cart(cart_id: String) -> bool:
	if not can_purchase_cart(cart_id):
		print("[CartManager] ❌ Không đủ điều kiện mua xe: %s" % cart_id)
		return false
	
	var tier = _get_tier_data(cart_id)
	GameManager.money -= tier.cost
	
	owned_carts[cart_id] = {
		"active": true,
		"pending_revenue": 0.0,
	}
	
	cart_activated.emit(cart_id)
	_save_carts()
	
	print("[CartManager] 🚗 Đã mua xe mới: %s (-%dđ) — Thu nhập: %.1fđ/s" % [
		tier.name, tier.cost, tier.income_per_sec
	])
	return true

## Thu thập tất cả tiền pending từ các xe đang chạy
## Trả về số tiền đã thu thập
func collect_revenue() -> int:
	var total: int = 0
	for cart_id in owned_carts:
		var cart_state: Dictionary = owned_carts[cart_id]
		var pending: float = cart_state.get("pending_revenue", 0.0)
		if pending >= 1.0:
			var collected: int = int(pending)
			total += collected
			cart_state["pending_revenue"] = pending - collected
	
	if total > 0:
		GameManager.add_money(total)
		revenue_collected.emit(total)
		_save_carts()
		print("[CartManager] 💰 Thu thập: +%dđ từ %d xe" % [total, owned_carts.size()])
	
	return total

## Tính tổng thu nhập bị động mỗi giây từ tất cả xe đang hoạt động
func get_total_passive_income() -> float:
	var total: float = 0.0
	for cart_id in owned_carts:
		var cart_state: Dictionary = owned_carts[cart_id]
		if cart_state.get("active", false):
			var tier = _get_tier_data(cart_id)
			if not tier.is_empty():
				total += tier.income_per_sec
	return total

## Lấy tổng tiền pending chưa thu
func get_total_pending_revenue() -> int:
	return int(_get_total_pending())

## Lấy danh sách xe có thể mua tiếp theo
func get_next_available_cart() -> Dictionary:
	for tier in CART_TIERS:
		if not owned_carts.has(tier.id):
			return tier
	return {}  # Đã mua hết

## Lấy số xe đang sở hữu (+ xe chính = owned + 1)
func get_owned_cart_count() -> int:
	return owned_carts.size()

# ─── PRIVATE HELPERS ─────────────────────────────────────

func _get_total_pending() -> float:
	var total: float = 0.0
	for cart_id in owned_carts:
		total += owned_carts[cart_id].get("pending_revenue", 0.0)
	return total

func _get_tier_data(cart_id: String) -> Dictionary:
	for tier in CART_TIERS:
		if tier.id == cart_id:
			return tier
	return {}

func _get_tier_index(cart_id: String) -> int:
	for i in range(CART_TIERS.size()):
		if CART_TIERS[i].id == cart_id:
			return i
	return -1

# ─── SAVE / LOAD ─────────────────────────────────────────
## Lưu vào cùng savegame.cfg, section "Carts"
func _save_carts() -> void:
	pass # Disabled to not save progress
	# var cfg = ConfigFile.new()
	# # Load file hiện có trước để không ghi đè data khác
	# cfg.load(GameManager.SAVE_PATH)
	# 
	# # Lưu danh sách xe đã mua
	# var cart_ids: Array[String] = []
	# for cart_id in owned_carts:
	# 	cart_ids.append(cart_id)
	# 	cfg.set_value("Carts", cart_id + "_active", owned_carts[cart_id].get("active", false))
	# 	cfg.set_value("Carts", cart_id + "_pending", owned_carts[cart_id].get("pending_revenue", 0.0))
	# cfg.set_value("Carts", "owned_ids", cart_ids)
	# 
	# cfg.save(GameManager.SAVE_PATH)

func _load_carts() -> void:
	pass # Disabled to not load progress
	# var cfg = ConfigFile.new()
	# if cfg.load(GameManager.SAVE_PATH) != OK:
	# 	return
	# 
	# var cart_ids = cfg.get_value("Carts", "owned_ids", [])
	# for cart_id in cart_ids:
	# 	owned_carts[str(cart_id)] = {
	# 		"active": cfg.get_value("Carts", str(cart_id) + "_active", true),
	# 		"pending_revenue": cfg.get_value("Carts", str(cart_id) + "_pending", 0.0),
	# 	}
	# 
	# if not owned_carts.is_empty():
	# 	print("[CartManager] Load xong: %d xe đang hoạt động" % owned_carts.size())
