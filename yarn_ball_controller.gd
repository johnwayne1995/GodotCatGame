extends Node2D
## 毛线球：不自动动。鼠标放到球上时（猫窗在上且可穿透时也能触发）随机快速弹开，速度可配置；之后摩擦力减速至停止。

# 鼠标悬停弹开时的初速（像素/秒），可调
@export var kick_speed: float = 2000.0
# 物理
@export var friction: float = 95.0
## 撞墙后反弹保留的速度比例（0~1），越小越容易停
@export var bounce_factor: float = 0.25
var speed_stop_threshold: float = 2.0
## 用于滚动角速度的等效半径（像素），速度 v 时角速度 = v / roll_radius
@export var roll_radius: float = 70.0

var velocity := Vector2.ZERO
var was_mouse_over := false

var screen_size: Vector2
var window_size: Vector2
var _sprite: Node2D
## 顶端反弹时至少保留的向下速度（像素/秒）。需足够大才能在被摩擦减到 0 前滚出顶部禁区（≈720px）
@export var min_bounce_down_speed: float = 400.0
## 顶部禁区高度（球心 y 小于此即算在顶部），随猫窗高度同步
var _top_zone_height: float = 720.0

var _roll_radius_base: float
var _min_bounce_base: float
var _kick_speed_base: float
var _friction_base: float
var _speed_stop_base: float

func _enter_tree() -> void:
	# 尽早启用，避免首帧以不透明背景清除再与系统透明窗叠加（GL 兼容下常见闪烁）
	get_viewport().transparent_bg = true

func _ready() -> void:
	randomize()
	screen_size = DisplayServer.screen_get_size()
	var win = get_window()
	window_size = Vector2(win.size)
	win.size_changed.connect(_on_ball_window_size_changed)
	_roll_radius_base = roll_radius
	_min_bounce_base = min_bounce_down_speed
	_kick_speed_base = kick_speed
	_friction_base = friction
	_speed_stop_base = speed_stop_threshold
	if get_tree().root != null:
		_top_zone_height = float(get_tree().root.size.y)
	if get_child_count() > 0:
		_sprite = get_child(0)


func _on_ball_window_size_changed() -> void:
	window_size = Vector2(get_window().size)


func apply_physics_scale(ratio: float) -> void:
	ratio = maxf(ratio, 0.05)
	roll_radius = _roll_radius_base * ratio
	min_bounce_down_speed = _min_bounce_base * ratio
	kick_speed = _kick_speed_base * ratio
	friction = _friction_base * ratio
	speed_stop_threshold = maxf(_speed_stop_base * ratio, 0.5)
	window_size = Vector2(get_window().size)


func set_top_zone_from_cat_height(cat_height: float) -> void:
	_top_zone_height = cat_height

func _process(delta: float) -> void:
	_check_mouse_hover_kick()

	if velocity.length() < speed_stop_threshold:
		velocity = Vector2.ZERO
		_update_roll(velocity.length(), delta)
		if velocity.length() >= speed_stop_threshold:
			_update_window_position(delta)
	else:
		var v_len := velocity.length()
		var drag := friction * delta
		if drag >= v_len:
			velocity = Vector2.ZERO
			_update_roll(0.0, delta)
		else:
			velocity.x = move_toward(velocity.x, 0.0, friction * delta)
			_update_roll(v_len, delta)
		_update_window_position(delta)

func _check_mouse_hover_kick() -> void:
	var win = get_window()
	var win_pos := Vector2(win.position)
	var win_size := Vector2(win.size)
	var mouse := DisplayServer.mouse_get_position()
	var over := (
		mouse.x >= win_pos.x and mouse.x < win_pos.x + win_size.x and
		mouse.y >= win_pos.y and mouse.y < win_pos.y + win_size.y
	)
	if over and !was_mouse_over:
		_kick_ball(kick_speed)
		_notify_ball_kicked()
	was_mouse_over = over

func _kick_ball(speed: float) -> void:
	# 避免 angle 太接近 0 或 π，否则 velocity.y ≈ 0，且左右墙反弹不会改 y，会一直水平
	var angle := randf() * TAU
	if abs(sin(angle)) < 0.15:
		angle += 0.25
	velocity = Vector2.from_angle(angle) * speed

func _notify_ball_kicked() -> void:
	var launcher = get_tree().get_first_node_in_group("yarn_ball_launcher")
	if launcher != null and launcher.has_method("on_ball_kicked"):
		launcher.on_ball_kicked()

## 根据线速度更新旋转，模拟滚动：角速度 = 线速度/半径，速度越小转得越慢
func _update_roll(linear_speed: float, delta: float) -> void:
	if _sprite == null or roll_radius <= 0.0:
		return
	if linear_speed < speed_stop_threshold:
		return
	var angular_speed: float = linear_speed / roll_radius
	var dir: float = sign(velocity.x) if abs(velocity.x) > 0.01 else sign(velocity.y)
	_sprite.rotation -= dir * angular_speed * delta

func _update_window_position(delta: float) -> void:
	var win = get_window()
	var pos := Vector2(win.position)
	pos += velocity * delta
	if pos.x < 0:
		pos.x = 0
		velocity.x = -velocity.x * bounce_factor
	if pos.x + window_size.x > screen_size.x:
		pos.x = screen_size.x - window_size.x
		velocity.x = -velocity.x * bounce_factor
	# 顶端：屏幕 y 向下为正，撞顶时 velocity.y 为负（向上），反射后应为正（向下）
	if pos.y < 0:
		pos.y = 0
		velocity.y = -velocity.y * bounce_factor
		# 反射后应为向下；若未大于 0 或过小，强制为最小向下速度（避免符号/精度问题）
		if velocity.y <= 0 or velocity.y < min_bounce_down_speed:
			velocity.y = min_bounce_down_speed
	# 底端：撞底时 velocity.y 为正（向下），反射后应为负（向上）
	if pos.y + window_size.y > screen_size.y:
		pos.y = screen_size.y - window_size.y
		velocity.y = -velocity.y * bounce_factor
	win.position = Vector2i(int(round(pos.x)), int(round(pos.y)))
