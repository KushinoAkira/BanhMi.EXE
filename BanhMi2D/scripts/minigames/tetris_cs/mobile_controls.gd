extends VBoxContainer

@onready var btn_left: Button = $Row2/BtnLeft
@onready var btn_right: Button = $Row2/BtnRight
@onready var btn_down: Button = $Row2/BtnDown
@onready var btn_up: Button = $Row1/BtnUp
@onready var btn_hard: Button = $Row1/BtnHardDrop
@onready var btn_hold: Button = $Row1/BtnHold

func _ready() -> void:
	# We bind touch down/up to Godot's Input actions
	# This allows BoardManager.cs to read Input.IsActionJustPressed
	
	_bind_button(btn_left, "ui_left")
	_bind_button(btn_right, "ui_right")
	_bind_button(btn_down, "ui_down")
	_bind_button(btn_up, "ui_up")
	
	# Custom actions
	_bind_button(btn_hard, "ui_select") # Spacebar (Hard Drop)
	_bind_button(btn_hold, "ui_left")  # Shift (Hold)

func _bind_button(btn: Button, action_name: String) -> void:
	if not btn: return
	btn.button_down.connect(func(): Input.action_press(action_name))
	btn.button_up.connect(func(): Input.action_release(action_name))
	
	# In case touch is cancelled (dragged outside)
	btn.mouse_exited.connect(func(): Input.action_release(action_name))
