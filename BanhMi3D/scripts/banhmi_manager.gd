extends Node

signal order_finished(customer_name: String)

# Định nghĩa các loại bánh mì, nguyên liệu và GIÁ BÁN
const RECIPES = {
	"Bánh mì Pate": {
		"ingredients": ["Tô pate", "Tô rau thơm", "Tô đồ chua"],
		"final_asset": "res://assets/banh_mi_items/banhmi_pate/banhmi_pate.glb",
		"price": 15000
	},
	"Bánh mì Thịt nguội": {
		"ingredients": ["Tô pate", "Dĩa thịt nguội", "Tô rau thơm", "Tô đồ chua"],
		"final_asset": "res://assets/banh_mi_items/banhmi_pate/banhmi_pate.glb",
		"price": 25000
	},
	"Bánh mì Chả lụa": {
		"ingredients": ["Tô pate", "Dĩa chả lụa", "Tô rau thơm", "Tô đồ chua"],
		"final_asset": "res://assets/banh_mi_items/banhmi_pate/banhmi_pate.glb",
		"price": 20000
	},
	"Bánh mì Thịt nướng": {
		"ingredients": ["Dĩa thịt nướng", "Tô đồ chua", "Tô rau thơm"],
		"final_asset": "res://assets/banh_mi_items/banhmi_pate/banhmi_pate.glb",
		"price": 25000
	},
	"Bánh mì Trứng ốp la": {
		"ingredients": ["Dĩa trứng ốp la", "Tô pate", "Tô rau thơm"],
		"final_asset": "res://assets/banh_mi_items/banhmi_pate/banhmi_pate.glb",
		"price": 15000
	},
	"Bánh mì Đặc biệt": {
		"ingredients": ["Tô pate", "Dĩa thịt nguội", "Dĩa chả lụa", "Tô đồ chua", "Tô rau thơm"],
		"final_asset": "res://assets/banh_mi_items/banhmi_pate/banhmi_pate.glb",
		"price": 35000
	}
}

# Lưu trữ đơn hàng: { customer_name: { "order_type": String, "ingredients": Array } }
var active_orders = {}

# Đơn hàng mà người chơi đang tập trung làm
var current_working_customer = ""

func _ready():
	pass

func generate_order_for_customer(customer_name: String):
	if active_orders.has(customer_name): return
	
	var keys = RECIPES.keys()
	var order_type = keys[randi() % keys.size()]
	
	active_orders[customer_name] = {
		"order_type": order_type,
		"ingredients": []
	}
	
	# Bật dấu chấm than chờ
	var cart_managers = get_tree().get_nodes_in_group("CartManager")
	if cart_managers.size() > 0:
		cart_managers[0].set_waiting_indicator(customer_name, true)
	
	# Nếu chưa làm cho ai thì tập trung vào người này
	if current_working_customer == "":
		current_working_customer = customer_name
		
	print(">>> [ĐƠN HÀNG] ", customer_name, " muốn một ổ ", order_type)

func add_ingredient(ingredient_name: String) -> bool:
	if current_working_customer == "" or not active_orders.has(current_working_customer):
		print(">>> [!] Hãy nhận đơn hàng từ khách trước!")
		return false
	
	var order = active_orders[current_working_customer]
	var required = RECIPES[order["order_type"]]["ingredients"]
	
	if ingredient_name in required:
		if not ingredient_name in order["ingredients"]:
			order["ingredients"].append(ingredient_name)
			print(">>> [TIẾN ĐỘ] Đã thêm ", ingredient_name, " cho đơn của ", current_working_customer)
			return true
	else:
		print(">>> [CẢNH BÁO] ", ingredient_name, " không có trong đơn của ", current_working_customer)
	return false

func is_finished() -> bool:
	if current_working_customer == "" or not active_orders.has(current_working_customer):
		return false
		
	var order = active_orders[current_working_customer]
	var required = RECIPES[order["order_type"]]["ingredients"]
	for item in required:
		if not item in order["ingredients"]:
			return false
	return true

func get_recipe_info():
	if current_working_customer == "":
		return "Trạng thái: Hãy bấm vào Khách để nhận đơn!"
	
	var order = active_orders[current_working_customer]
	var required = RECIPES[order["order_type"]]["ingredients"]
	var progress = ""
	for item in required:
		if item in order["ingredients"]:
			progress += "[x] " + item + "\n"
		else:
			progress += "[ ] " + item + "\n"
		
	return "Khách hàng: " + current_working_customer + "\n" + \
		   "Yêu cầu: " + order["order_type"] + "\n" + progress

# ===== TÍNH TIỀN & TIP =====
func get_payment(order_type: String) -> Dictionary:
	var base_price: int = 0
	if RECIPES.has(order_type):
		base_price = RECIPES[order_type]["price"]
	
	# Tip ngẫu nhiên 5% đến 20%
	var tip_pct = randf_range(0.05, 0.20)
	var tip_amount = int(base_price * tip_pct)
	# Làm tròn đến 500 VND
	tip_amount = int(tip_amount / 500.0) * 500
	if tip_amount == 0:
		tip_amount = 500
	
	return {
		"base": base_price,
		"tip": tip_amount,
		"total": base_price + tip_amount,
		"order_type": order_type
	}

func finish_order(customer_name: String) -> Dictionary:
	var payment = {}
	if active_orders.has(customer_name):
		var order_type = active_orders[customer_name]["order_type"]
		payment = get_payment(order_type)
		active_orders.erase(customer_name)
		
		# Tắt dấu chấm than chờ
		var cart_managers = get_tree().get_nodes_in_group("CartManager")
		if cart_managers.size() > 0:
			cart_managers[0].set_waiting_indicator(customer_name, false)

		if current_working_customer == customer_name:
			current_working_customer = ""
			# Nếu còn đơn khác thì chuyển sang đơn đó
			if active_orders.size() > 0:
				current_working_customer = active_orders.keys()[0]

		order_finished.emit(customer_name)
	return payment
