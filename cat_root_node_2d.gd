extends Node2D

enum State { IDLE, RUN }

# ---------------- 配置 ----------------
var max_speed_x = 10
var max_speed_y = 5
var slow_down_distance = 150.0
var idle_time_range = Vector2(1.0, 3.0)
var run_time_range = Vector2(2.0, 5.0)

# ---------------- 状态 ----------------
var state = State.RUN
var axis = "x"  # 本次移动轴，"x" 或 "y"
var direction = 1

var current_speed = 0.0
var target_speed = 0.0

var idle_timer = 0.0
var run_timer = 0.0

# ---------------- 节点 ----------------
var screen_size: Vector2
var window_size: Vector2
var sprite: AnimatedSprite2D

# ---------------- 初始化 ----------------
func _ready():
	randomize()
	
	sprite = get_node("CatSprite_AnimatedSprite2D")
	if sprite == null:
		push_error("节点 CatSprite_AnimatedSprite2D 未找到！")
		return

	screen_size = DisplayServer.screen_get_size()
	window_size = Vector2(DisplayServer.window_get_size())

	start_running()

func _process(delta):
	update_behavior(delta)
	update_speed(delta)
	update_movement()
	update_animation_speed()
	update_animation()

# ---------------- 行为控制 ----------------
func update_behavior(delta):
	if state == State.RUN:
		run_timer -= delta
		if run_timer <= 0:
			start_idle()
	elif state == State.IDLE:
		idle_timer -= delta
		if idle_timer <= 0:
			start_running()

func start_running():
	state = State.RUN
	run_timer = randf_range(run_time_range.x, run_time_range.y)

	# 随机选择移动轴
	axis = "x" if randf() > 0.5 else "y"
	direction = 1 if randf() > 0.5 else -1

	# 设置目标速度
	if axis == "x":
		target_speed = randf_range(max_speed_x * 0.6, max_speed_x)
	else:
		target_speed = randf_range(max_speed_y * 0.5, max_speed_y)

	# 播放对应动画
	if axis == "x":
		sprite.play("run_right" if direction >= 0 else "run_left")
	else:
		sprite.play("run_down" if direction >= 0 else "run_up")

func on_tap_cat():
	state = State.IDLE
	idle_timer = randf_range(idle_time_range.x, idle_time_range.y)
	target_speed = 0.0
	run_timer = 0.0   # 清空运行计时
	axis = "y"
	direction = 1
	sprite.play("idle_down")
	

func start_idle():
	state = State.IDLE
	idle_timer = randf_range(idle_time_range.x, idle_time_range.y)
	target_speed = 0.0

	if axis == "x":
		if  direction >= 0:
			sprite.play("idle_right")
		else:
			sprite.play("idle_left")
	else:
		if  direction >= 0:
			sprite.play("idle_down")
		else:
			sprite.play("idle_up")

# ---------------- 平滑加减速 ----------------
func update_speed(delta):
	current_speed = move_toward(current_speed, target_speed, 40.0 * delta)

# ---------------- 移动逻辑 ----------------
func update_movement():
	var pos = Vector2(DisplayServer.window_get_position())

	# ---------------- 计算距离边界 ----------------
	if axis == "x":
		var distance_to_left = pos.x
		var distance_to_right = screen_size.x - (pos.x + window_size.x)

		if direction > 0 and distance_to_right < slow_down_distance:
			target_speed = max_speed_x * (distance_to_right / slow_down_distance)
		elif direction < 0 and distance_to_left < slow_down_distance:
			target_speed = max_speed_x * (distance_to_left / slow_down_distance)

		pos.x += direction * current_speed

		# 到边界掉头
		if pos.x + window_size.x >= screen_size.x:
			pos.x = screen_size.x - window_size.x
			direction = -1
			target_speed = randf_range(max_speed_x * 0.6, max_speed_x)
			sprite.play("run_left")
		elif pos.x <= 0:
			pos.x = 0
			direction = 1
			target_speed = randf_range(max_speed_x * 0.6, max_speed_x)
			sprite.play("run_right")

	else:  # axis == "y"
		var distance_to_top = pos.y
		var distance_to_bottom = screen_size.y - (pos.y + window_size.y)

		if direction > 0 and distance_to_bottom < slow_down_distance:
			target_speed = max_speed_y * (distance_to_bottom / slow_down_distance)
		elif direction < 0 and distance_to_top < slow_down_distance:
			target_speed = max_speed_y * (distance_to_top / slow_down_distance)

		pos.y += direction * current_speed

		# 到边界掉头
		if pos.y + window_size.y >= screen_size.y:
			pos.y = screen_size.y - window_size.y
			direction = -1
			target_speed = randf_range(max_speed_y * 0.5, max_speed_y)
			sprite.play("run_up")
		elif pos.y <= 0:
			pos.y = 0
			direction = 1
			target_speed = randf_range(max_speed_y * 0.5, max_speed_y)
			sprite.play("run_down")

	DisplayServer.window_set_position(pos)

# ---------------- 动画速度同步 ----------------
func update_animation_speed():
	sprite.speed_scale = clamp(
	current_speed / (max_speed_x if axis == "x" else max_speed_y),
	0.5,
	2.0
)

# ---------------- 动画更新 ----------------
func update_animation():
	if current_speed < 0.01:
		if sprite.animation != "idle":
			if axis == "x":
				if  direction >= 0:
					sprite.play("idle_right")
				else:
					sprite.play("idle_left")
			else:
				if  direction >= 0:
					sprite.play("idle_down")
				else:
					sprite.play("idle_up")
