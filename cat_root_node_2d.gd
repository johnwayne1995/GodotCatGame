extends Node2D

enum State { IDLE, RUN }

## 设计基准：与 project 窗口默认尺寸一致，用于与毛线球窗口比例、整体缩放
const BASE_CAT_WINDOW := 720.0

# ---------------- 配置 ----------------
var max_speed_x = 10.0
var max_speed_y = 5.0
var slow_down_distance = 150.0
var idle_time_range = Vector2(1.0, 3.0)
# 跟随毛线球（用「球到猫窗矩形」的距离，稳定不抖；resume > stop 做滞后，防止来回切）
var follow_chase_speed = 28.0          # 跟随时的最大速度
var follow_stop_distance = 20.0       # 球到猫窗距离小于此→判定追到、进待机（越小要贴得越近才 idle）
var follow_resume_distance = 50.0    # 待机时球到猫窗距离大于此→再开始追（须 > stop 才有滞后）
# ---------------- 状态 ----------------
var state = State.RUN
var axis = "x"
var direction = 1

var current_speed = 0.0
var target_speed = 0.0

var idle_timer = 0.0

# ---------------- 节点 ----------------
var screen_size: Vector2
var window_size: Vector2
var sprite: AnimatedSprite2D
var yarn_ball_launcher: Node  # 用于获取毛线球中心位置

var _base_follow_stop: float
var _base_follow_resume: float
var _base_slow_down: float
var _base_follow_chase: float
var _base_max_speed_x: float
var _base_max_speed_y: float

# ---------------- 初始化 ----------------
func _ready():
	randomize()

	sprite = get_node("CatSprite_AnimatedSprite2D")
	if sprite == null:
		push_error("节点 CatSprite_AnimatedSprite2D 未找到！")
		return

	yarn_ball_launcher = get_node_or_null("YarnBallLauncher")
	if yarn_ball_launcher == null:
		push_warning("未找到 YarnBallLauncher，猫将不会跟随毛线球")

	_base_follow_stop = follow_stop_distance
	_base_follow_resume = follow_resume_distance
	_base_slow_down = slow_down_distance
	_base_follow_chase = follow_chase_speed
	_base_max_speed_x = max_speed_x
	_base_max_speed_y = max_speed_y

	screen_size = DisplayServer.screen_get_size()
	window_size = Vector2(get_window().size)
	get_window().size_changed.connect(_on_window_size_changed)

	state = State.RUN
	target_speed = follow_chase_speed * 0.5

	# 等毛线球窗口进入场景树并完成 _ready 后再同步比例，避免球脚本物理基准尚未初始化
	call_deferred("apply_desktop_scale", get_window().size)


func apply_desktop_scale(cat_size: Vector2i) -> void:
	var ratio := float(cat_size.x) / BASE_CAT_WINDOW
	ratio = maxf(ratio, 0.05)
	get_window().size = cat_size
	scale = Vector2(ratio, ratio)
	follow_stop_distance = _base_follow_stop * ratio
	follow_resume_distance = _base_follow_resume * ratio
	slow_down_distance = _base_slow_down * ratio
	follow_chase_speed = _base_follow_chase * ratio
	max_speed_x = _base_max_speed_x * ratio
	max_speed_y = _base_max_speed_y * ratio
	window_size = Vector2(cat_size)
	if yarn_ball_launcher != null and yarn_ball_launcher.has_method("apply_ball_scale_ratio"):
		yarn_ball_launcher.apply_ball_scale_ratio(ratio)


func _on_window_size_changed() -> void:
	window_size = Vector2(get_window().size)


func _process(delta):
	update_behavior(delta)
	update_speed(delta)
	update_movement()
	update_animation_speed()
	update_animation()

# ---------------- 行为控制（跟随毛线球） ----------------
func update_behavior(delta: float) -> void:
	# 球被弹开后等 N 秒才允许追，这段时间猫待机并一直看向球
	if yarn_ball_launcher != null and yarn_ball_launcher.has_method("can_cat_chase") and !yarn_ball_launcher.can_cat_chase():
		state = State.IDLE
		target_speed = 0.0
		_face_ball_idle()
		return

	if state == State.IDLE:
		idle_timer -= delta
		if idle_timer <= 0:
			_try_resume_follow()
		return

	# RUN：球到猫窗矩形距离 < stop → 追到，进待机（用矩形距离，不依赖参考点，不抖）
	if yarn_ball_launcher != null and yarn_ball_launcher.has_method("get_yarn_ball_center"):
		var ball_center: Vector2 = yarn_ball_launcher.get_yarn_ball_center()
		var dist: float = _distance_ball_to_cat_rect(ball_center)
		if dist < follow_stop_distance:
			_start_idle_at_ball()

func _try_resume_follow() -> void:
	if yarn_ball_launcher == null or !yarn_ball_launcher.has_method("get_yarn_ball_center"):
		state = State.RUN
		target_speed = follow_chase_speed * 0.5
		return
	if yarn_ball_launcher.has_method("can_cat_chase") and !yarn_ball_launcher.can_cat_chase():
		return
	var ball_center: Vector2 = yarn_ball_launcher.get_yarn_ball_center()
	var dist: float = _distance_ball_to_cat_rect(ball_center)
	if dist > follow_resume_distance:
		state = State.RUN
		target_speed = follow_chase_speed * 0.5

## 球心到猫窗矩形的最短距离（在矩形内为 0），判定追到/再追只用这一个量，稳定
func _distance_ball_to_cat_rect(ball_center: Vector2) -> float:
	var pos: Vector2 = Vector2(get_window().position)
	var closest_x: float = clampf(ball_center.x, pos.x, pos.x + window_size.x)
	var closest_y: float = clampf(ball_center.y, pos.y, pos.y + window_size.y)
	return ball_center.distance_to(Vector2(closest_x, closest_y))

## 根据球相对猫的位置选朝向并播对应 idle（idle_left / idle_right / idle_up / idle_down）
func _face_ball_idle() -> void:
	if yarn_ball_launcher == null or !yarn_ball_launcher.has_method("get_yarn_ball_center"):
		return
	var ball_center: Vector2 = yarn_ball_launcher.get_yarn_ball_center()
	var cat_center: Vector2 = Vector2(get_window().position) + window_size * 0.5
	var dx: float = ball_center.x - cat_center.x
	var dy: float = ball_center.y - cat_center.y
	if abs(dx) >= abs(dy):
		axis = "x"
		direction = 1 if dx > 0 else -1
		sprite.play("idle_right" if direction > 0 else "idle_left")
	else:
		axis = "y"
		direction = 1 if dy > 0 else -1
		sprite.play("idle_down" if direction > 0 else "idle_up")

## 根据球相对猫的位置返回猫的参考点：球在右→猫右下角，球在左→猫左下角，球在下→猫正下方，球在上→猫正上方
func _get_cat_reference_point(ball_center: Vector2) -> Vector2:
	var pos: Vector2 = Vector2(get_window().position)
	var cat_center: Vector2 = pos + window_size * 0.5
	var dx: float = ball_center.x - cat_center.x
	var dy: float = ball_center.y - cat_center.y
	if abs(dx) > abs(dy):
		if dx > 0:
			return pos + Vector2(window_size.x, window_size.y)
		else:
			return pos + Vector2(0, window_size.y)
	else:
		if dy > 0:
			return pos + Vector2(window_size.x * 0.5, window_size.y)
		else:
			return pos + Vector2(window_size.x * 0.5, 0)

func _start_idle_at_ball() -> void:
	state = State.IDLE
	idle_timer = randf_range(idle_time_range.x, idle_time_range.y)
	target_speed = 0.0
	if axis == "x":
		sprite.play("idle_right" if direction >= 0 else "idle_left")
	else:
		sprite.play("idle_down" if direction >= 0 else "idle_up")

func on_tap_cat():
	state = State.IDLE
	idle_timer = randf_range(idle_time_range.x, idle_time_range.y)
	target_speed = 0.0
	axis = "y"
	direction = 1
	sprite.play("idle_tap")
	var timer := get_tree().create_timer(2.0)
	timer.timeout.connect(start_idle)

func start_idle():
	state = State.IDLE
	idle_timer = randf_range(idle_time_range.x, idle_time_range.y)
	target_speed = 0.0
	if axis == "x":
		sprite.play("idle_right" if direction >= 0 else "idle_left")
	else:
		sprite.play("idle_down" if direction >= 0 else "idle_up")

# ---------------- 平滑加减速 ----------------
func update_speed(delta: float) -> void:
	current_speed = move_toward(current_speed, target_speed, 40.0 * delta)

# ---------------- 移动逻辑（朝毛线球中心移动） ----------------
func update_movement() -> void:
	var win = get_window()
	var pos = Vector2(win.position)
	var cat_center = pos + window_size * 0.5

	if state == State.IDLE:
		win.position = Vector2i(int(pos.x), int(pos.y))
		return
	if yarn_ball_launcher != null and yarn_ball_launcher.has_method("can_cat_chase") and !yarn_ball_launcher.can_cat_chase():
		win.position = Vector2i(int(pos.x), int(pos.y))
		return

	# 获取毛线球中心；若无则保持原位
	var target_center: Vector2
	if yarn_ball_launcher != null and yarn_ball_launcher.has_method("get_yarn_ball_center"):
		target_center = yarn_ball_launcher.get_yarn_ball_center()
	else:
		win.position = Vector2i(int(pos.x), int(pos.y))
		return

	var to_target = target_center - cat_center
	var dist = to_target.length()
	if dist < 1.0:
		win.position = Vector2i(int(pos.x), int(pos.y))
		return

	# 根据目标方向决定轴与方向、动画
	var dx = to_target.x
	var dy = to_target.y
	if abs(dx) >= abs(dy):
		axis = "x"
		direction = 1 if dx > 0 else -1
		sprite.play("run_right" if direction > 0 else "run_left")
	else:
		axis = "y"
		direction = 1 if dy > 0 else -1
		sprite.play("run_down" if direction > 0 else "run_up")

	# 跟随速度：接近时减速，靠近屏幕边缘也减速
	var max_speed = follow_chase_speed
	if axis == "x":
		var edge = slow_down_distance
		var dist_right = screen_size.x - (pos.x + window_size.x)
		var dist_left = pos.x
		if direction > 0 and dist_right < edge:
			max_speed = follow_chase_speed * (dist_right / edge)
		elif direction < 0 and dist_left < edge:
			max_speed = follow_chase_speed * (dist_left / edge)
	else:
		var edge = slow_down_distance
		var dist_bottom = screen_size.y - (pos.y + window_size.y)
		var dist_top = pos.y
		if direction > 0 and dist_bottom < edge:
			max_speed = follow_chase_speed * (dist_bottom / edge)
		elif direction < 0 and dist_top < edge:
			max_speed = follow_chase_speed * (dist_top / edge)

	target_speed = max_speed

	# 朝目标移动，速度不超过 max_speed
	var move_len = min(current_speed, dist)
	var step = to_target.normalized() * move_len
	pos += step

	# 限制在屏幕内
	pos.x = clampf(pos.x, 0, screen_size.x - window_size.x)
	pos.y = clampf(pos.y, 0, screen_size.y - window_size.y)

	win.position = Vector2i(int(pos.x), int(pos.y))

# ---------------- 动画速度同步 ----------------
func update_animation_speed() -> void:
	var ref_speed = max_speed_x if axis == "x" else max_speed_y
	sprite.speed_scale = clamp(current_speed / ref_speed, 0.5, 2.0)

# ---------------- 动画更新 ----------------
func update_animation() -> void:
	if current_speed < 0.01 and sprite.animation.begins_with("run"):
		if axis == "x":
			sprite.play("idle_right" if direction >= 0 else "idle_left")
		else:
			sprite.play("idle_down" if direction >= 0 else "idle_up")
