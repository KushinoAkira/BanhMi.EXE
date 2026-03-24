extends CanvasLayer

# Virtual directional state
var _up    := false
var _down  := false
var _left  := false
var _right := false

@onready var btn_w := $Buttons/W
@onready var btn_a := $Buttons/A
@onready var btn_s := $Buttons/S
@onready var btn_d := $Buttons/D

func _ready():
	_connect_btn(btn_w, "ui_up")
	_connect_btn(btn_a, "ui_left")
	_connect_btn(btn_s, "ui_down")
	_connect_btn(btn_d, "ui_right")

func _connect_btn(btn: Button, action: String):
	btn.button_down.connect(func(): _press(action))
	btn.button_up.connect(func(): _release(action))

func _press(action: String):
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)

func _release(action: String):
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = false
	Input.parse_input_event(ev)
