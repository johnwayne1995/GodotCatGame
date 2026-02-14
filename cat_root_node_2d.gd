extends Node2D

enum State { IDLE, RUN }

var state = State.RUN
var direction = 1
var max_speed = 50.0
var current_speed = 0.0
var target_speed = 0.0

var screen_size
var window_size

var idle_timer = 0.0
var run_timer = 0.0

var slow_down_distance = 150.0


@onready var sprite = $CatSprite_AnimatedSprite2D

func _ready():
	randomize()
	screen_size = DisplayServer.screen_get_size()
	window_size = Vector2(DisplayServer.window_get_size())

	start_running()

func _process(delta):
	current_speed = move_toward(current_speed, target_speed, 40 * delta)
	if max_speed > 0:
		sprite.speed_scale = clamp(current_speed / max_speed, 0.5, 2.0)
		
	update_behavior(delta)
	update_movement()


# ==============================
# 行为逻辑
# ==============================

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
	run_timer = randf_range(2.0, 5.0)

	direction = 1 if randf() > 0.5 else -1
	target_speed = randf_range(6.0, max_speed)

	if direction > 0:
		sprite.play("run_right")
	else:
		sprite.play("run_left")
		
func start_idle():
	state = State.IDLE
	idle_timer = randf_range(1.0, 3.0)
	target_speed = 0
	sprite.play("idle")

# ==============================
# 移动逻辑
# ==============================

func update_movement():
	if state != State.RUN:
		return

	var pos = Vector2(DisplayServer.window_get_position())
	var distance_to_left = pos.x
	var distance_to_right = screen_size.x - (pos.x + window_size.x)

	if direction > 0 and distance_to_right < slow_down_distance:
		target_speed = max_speed * (distance_to_right / slow_down_distance)

	elif direction < 0 and distance_to_left < slow_down_distance:
		target_speed = max_speed * (distance_to_left / slow_down_distance)

	pos.x += direction * current_speed
	
	if pos.x + window_size.x >= screen_size.x:
		direction = -1
		target_speed = randf_range(6.0, max_speed)
		sprite.play("run_left")

	elif pos.x <= 0:
		direction = 1
		target_speed = randf_range(6.0, max_speed)
		sprite.play("run_right")



	DisplayServer.window_set_position(pos)
