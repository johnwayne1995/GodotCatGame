extends Node2D

func _ready():
	var window = get_window()
	
	window.borderless = true
	window.always_on_top = true
	window.transparent = true
	
	# 让背景真正透明
	RenderingServer.set_default_clear_color(Color(0,0,0,0))
