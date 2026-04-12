extends Node
## Windows / macOS：托盘（通知区）图标。左键显示主窗口与毛线球窗口；右键打开菜单（窗口大小、隐藏到托盘、退出）。

const SIZE_PRESETS: Array[Vector2i] = [
	Vector2i(480, 480),
	Vector2i(600, 600),
	Vector2i(720, 720),
	Vector2i(960, 960),
	Vector2i(1080, 1080),
]

var _main_menu_rid: RID
var _size_menu_rid: RID
var _menus_built: bool = false

@onready var _indicator: StatusIndicator = $StatusIndicator


func _ready() -> void:
	if not _tray_platform_supported():
		_indicator.visible = false
		return
	# 由我们处理关闭：任务栏/Alt+F4 等关闭请求走隐藏到托盘，而不是直接退出
	get_tree().auto_accept_quit = false
	_indicator.tooltip = str(ProjectSettings.get_setting("application/config/name", "Cat"))
	_indicator.icon = preload("res://Resources/Sprite/idle_F.png") as Texture2D
	_indicator.pressed.connect(_on_indicator_pressed)
	_build_native_menus()
	get_window().close_requested.connect(_on_main_window_close_requested)


func _tray_platform_supported() -> bool:
	var n := OS.get_name()
	return n == "Windows" or n == "macOS"


func _build_native_menus() -> void:
	if not NativeMenu.has_feature(NativeMenu.FEATURE_POPUP_MENU):
		push_warning("NativeMenu：当前环境不支持 FEATURE_POPUP_MENU，托盘右键菜单不可用。")
		return
	_size_menu_rid = NativeMenu.create_menu()
	for s in SIZE_PRESETS:
		var label: String = "%d × %d" % [s.x, s.y]
		NativeMenu.add_item(_size_menu_rid, label, _on_size_menu_pick, Callable(), s)
	_main_menu_rid = NativeMenu.create_menu()
	NativeMenu.add_item(_main_menu_rid, "显示主窗口", _on_main_menu_command, Callable(), "show")
	NativeMenu.add_item(_main_menu_rid, "隐藏到托盘", _on_main_menu_command, Callable(), "hide_tray")
	NativeMenu.add_separator(_main_menu_rid)
	NativeMenu.add_submenu_item(_main_menu_rid, "窗口大小", _size_menu_rid)
	NativeMenu.add_separator(_main_menu_rid)
	NativeMenu.add_item(_main_menu_rid, "退出", _on_main_menu_command, Callable(), "quit")
	_menus_built = true


func _exit_tree() -> void:
	if not _menus_built:
		return
	if NativeMenu.has_menu(_main_menu_rid):
		NativeMenu.free_menu(_main_menu_rid)
	if NativeMenu.has_menu(_size_menu_rid):
		NativeMenu.free_menu(_size_menu_rid)


func _on_indicator_pressed(mouse_button: int, mouse_position: Vector2i) -> void:
	match mouse_button:
		MOUSE_BUTTON_LEFT:
			_show_main_windows()
		MOUSE_BUTTON_RIGHT:
			if _menus_built and NativeMenu.has_feature(NativeMenu.FEATURE_POPUP_MENU) and NativeMenu.has_menu(_main_menu_rid):
				NativeMenu.popup(_main_menu_rid, mouse_position)


func _on_main_window_close_requested() -> void:
	_hide_to_tray()


func _on_main_menu_command(tag: Variant) -> void:
	match str(tag):
		"show":
			_show_main_windows()
		"hide_tray":
			_hide_to_tray()
		"quit":
			get_tree().quit()


func _on_size_menu_pick(tag: Variant) -> void:
	if tag is Vector2i:
		var cat_root: Node = get_parent()
		if cat_root.has_method("apply_desktop_scale"):
			cat_root.apply_desktop_scale(tag)
		else:
			get_window().size = tag


func _show_main_windows() -> void:
	var w := get_window()
	w.visible = true
	w.show()
	_set_yarn_window_visible(true)


func _hide_to_tray() -> void:
	var w := get_window()
	w.hide()
	w.visible = false
	_set_yarn_window_visible(false)


func _set_yarn_window_visible(visible_: bool) -> void:
	var launcher: Node = get_parent().get_node_or_null("YarnBallLauncher")
	if launcher == null:
		return
	var ball_win: Variant = launcher.yarn_ball_window
	if ball_win is Window and is_instance_valid(ball_win):
		var bw := ball_win as Window
		bw.visible = visible_
		if visible_:
			bw.show()
		else:
			bw.hide()
