extends Node

# Định nghĩa các loại bánh mì và nguyên liệu cần thiết
const RECIPES = {
	"Bánh mì pate": {
		"ingredients": ["Tô pate", "Tô rau thơm", "Tô đồ chua"],
		"final_asset": "res://assets/banh_mi_items/banhmi_pate/banhmi_pate.glb"
	},
	"Bánh mì thịt nguội": {
		"ingredients": ["Tô pate", "Dĩa thịt nguội", "Tô rau thơm", "Tô đồ chua"],
		"final_asset": "res://assets/banh_mi_items/banhmi_pate/banhmi_pate.glb"
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

func finish_order(customer_name: String):
	if active_orders.has(customer_name):
		active_orders.erase(customer_name)
		if current_working_customer == customer_name:
			current_working_customer = ""
			# Nếu còn đơn khác thì chuyển sang đơn đó
			if active_orders.size() > 0:
				current_working_customer = active_orders.keys()[0]
