extends Node
## 创建并持有毛线球独立窗口，供猫获取毛线球位置以跟随

const BALL_TEXTURE = preload("res://Resources/Sprite/ball.png")

const YARN_BALL_WINDOW_SIZE = Vector2i(200, 200)

## 球被弹开后，隔几秒才允许猫开始追（秒）
@export var chase_delay_after_kick: float = 1.0

var yarn_ball_window: Window
var chase_allowed_after_time: float = 0.0

func _ready() -> void:
	add_to_group("yarn_ball_launcher")
	_build_yarn_ball_window()

func _build_yarn_ball_window() -> void:
	# 关闭“子窗口嵌入”，这样 Window 会作为独立系统窗口出现，而不是嵌在猫窗口里
	get_viewport().set_embedding_subwindows(false)

	yarn_ball_window = Window.new()
	yarn_ball_window.title = "Yarn"
	yarn_ball_window.borderless = true
	yarn_ball_window.transparent = true
	# 子 Window 不会自动继承主窗口/项目里的 transparent_bg；GL 兼容 + 系统透明窗若不设，会错误清除/混合导致闪烁且精灵 alpha 异常
	yarn_ball_window.transparent_bg = true
	yarn_ball_window.unresizable = true
	yarn_ball_window.size = YARN_BALL_WINDOW_SIZE
	yarn_ball_window.always_on_top = true

	var root := Node2D.new()
	root.set_script(load("res://yarn_ball_controller.gd") as GDScript)

	var sprite := Sprite2D.new()
	sprite.texture = BALL_TEXTURE
	sprite.position = Vector2(YARN_BALL_WINDOW_SIZE.x / 2, YARN_BALL_WINDOW_SIZE.y / 2)
	root.add_child(sprite)

	yarn_ball_window.add_child(root)

	# 初始位置：屏幕中部偏上，避免和猫重叠
	var screen = DisplayServer.screen_get_size()
	yarn_ball_window.position = Vector2i(
		screen.x / 2 - YARN_BALL_WINDOW_SIZE.x / 2,
		screen.y / 4
	)

	# 挂到根视口用 call_deferred，避免父节点正在 setup 时报错；挂上后再 show
	get_tree().root.call_deferred("add_child", yarn_ball_window)
	yarn_ball_window.call_deferred("show")

	# 只设置一次猫窗置顶（毛球窗已在上面设过）；每帧改 always_on_top 在 Windows + GL 透明窗上容易触发合成器闪烁
	var cat_win := get_window()
	if cat_win != null:
		cat_win.always_on_top = true

## 球被鼠标弹开时由毛球脚本调用，开始“几秒内不许猫追”的计时
func on_ball_kicked() -> void:
	chase_allowed_after_time = Time.get_ticks_msec() / 1000.0 + chase_delay_after_kick

## 是否已过“弹开后的等待时间”，允许猫追球
func can_cat_chase() -> bool:
	return (Time.get_ticks_msec() / 1000.0) >= chase_allowed_after_time

## 返回毛线球窗口在屏幕上的中心点（用于猫跟随）
func get_yarn_ball_center() -> Vector2:
	if !is_instance_valid(yarn_ball_window):
		return Vector2.ZERO
	var pos = Vector2(yarn_ball_window.position)
	var size = Vector2(yarn_ball_window.size)
	return pos + size * 0.5
