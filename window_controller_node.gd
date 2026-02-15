extends Node

@export var enable_drag := true
@export var enable_topmost := true
@onready var cat_root = get_parent()


var dragging := false
var drag_offset := Vector2.ZERO
var mouse_passthrough := false


func _ready():
	_setup_window()
	set_mouse_passthrough(false)



func _setup_window():
	var window = get_window()

	window.borderless = true
	window.always_on_top = enable_topmost
	window.transparent = true

	RenderingServer.set_default_clear_color(Color(0, 0, 0, 0))

	# 限制帧率（桌宠不需要高帧率）
	Engine.max_fps = 30


# ===============================
# 拖动逻辑（只在点到猫时触发）
# ===============================

#func _on_hit_area_input_event(viewport, event, shape_idx):
#
	#if mouse_passthrough:
		#return
#
	#if not enable_drag:
		#return
#
	#if event is InputEventMouseButton:
		#if event.button_index == MOUSE_BUTTON_LEFT:
			#dragging = event.pressed
#
	#if event is InputEventMouseMotion and dragging:
		#get_window().position += event.relative


# ===============================
# 鼠标穿透控制
# ===============================

func set_mouse_passthrough(enable: bool):
	mouse_passthrough = enable
	var window = get_window()
	window.set_flag(Window.FLAG_MOUSE_PASSTHROUGH, enable)



func toggle_mouse_passthrough():
	set_mouse_passthrough(!mouse_passthrough)


# ===============================
# 屏幕边界限制
# ===============================

func _process(_delta):
	_clamp_to_screen()


func _clamp_to_screen():
	var window = get_window()
	var screen_size = DisplayServer.screen_get_size()

	window.position.x = clamp(
		window.position.x,
		0,
		screen_size.x - window.size.x
	)

	window.position.y = clamp(
		window.position.y,
		0,
		screen_size.y - window.size.y
	)


func _on_hit_area_area_2d_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if cat_root.has_method("start_idle"):
			print("tap")
			cat_root.on_tap_cat()
	
	
func _input(event):
	if event.is_action_pressed("toggle_passthrough"):
		toggle_mouse_passthrough()
