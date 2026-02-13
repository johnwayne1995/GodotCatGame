extends Node2D

func _ready():
	var window = get_window()
	
	window.borderless = true
	window.always_on_top = true
	window.transparent = true
	
	# 让背景真正透明
	RenderingServer.set_default_clear_color(Color(0,0,0,0))
	# 获取屏幕尺寸
	screen_size = DisplayServer.screen_get_size()
	# 获取窗口尺寸
	window_size = Vector2(DisplayServer.window_get_size())
	# 初始化窗口位置
	DisplayServer.window_set_position(Vector2(100, 300))

# ===================== 配置 =====================
var speed = Vector2(5, 3)         # 窗口每帧移动速度
var follow_mouse = false           # 是否跟随鼠标
var sprite_frames: SpriteFrames    # 可选动画帧资源
# ============================================

var direction = Vector2(1, 1)      # 初始方向
var screen_size: Vector2
var window_size: Vector2
var sprite: AnimatedSprite2D

func _process(delta):
	var pos = Vector2(DisplayServer.window_get_position())

	if follow_mouse:
		# 窗口跟随鼠标
		pos = get_global_mouse_position() - window_size / 2
	else:
		# 自动移动
		pos += direction * speed

		# 碰到屏幕边缘反弹
		if pos.x + window_size.x > screen_size.x:
			direction.x = -1
			pos.x = screen_size.x - window_size.x
		elif pos.x < 0:
			direction.x = 1
			pos.x = 0

		if pos.y + window_size.y > screen_size.y:
			direction.y = -1
			pos.y = screen_size.y - window_size.y
		elif pos.y < 0:
			direction.y = 1
			pos.y = 0

	DisplayServer.window_set_position(pos)
