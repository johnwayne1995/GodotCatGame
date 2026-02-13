extends Node2D

func _ready():
	var window = get_window()

	window.borderless = true
	window.always_on_top = true
	window.transparent = true
	
	RenderingServer.set_default_clear_color(Color(0,0,0,0))

	window.set_flag(Window.FLAG_MOUSE_PASSTHROUGH, true)
	print(Engine.get_version_info())
	print(RenderingServer.get_default_clear_color())
