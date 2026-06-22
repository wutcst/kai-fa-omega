extends Node2D

# ============================================================
# 开始界面脚本
# 使用 Node2D + Camera2D + CanvasLayer 架构
# 相机自动缩放以完整显示背景图
# ============================================================

@onready var bg: Sprite2D = $Background
@onready var camera: Camera2D = $Camera2D
@onready var btn_start: Button = $UI/MenuPanel/MenuContent/btn_start
@onready var btn_load: Button = $UI/MenuPanel/MenuContent/btn_load
@onready var btn_exit: Button = $UI/MenuPanel/MenuContent/btn_exit
@onready var music: AudioStreamPlayer = $Music

var _save_load_ui: CanvasLayer = null


func _ready():
	# 延迟调用确保 viewport 尺寸已正确（特别是全屏启动时）
	call_deferred("_fit_camera_to_background")

	# 监听窗口大小变化，实时调整背景
	get_tree().root.size_changed.connect(_fit_camera_to_background)

	if music and music.stream:
		music.volume_db = -10.0
		music.play()

	_update_load_button_state()

	btn_start.pressed.connect(_on_start_pressed)
	btn_load.pressed.connect(_on_load_pressed)
	btn_exit.pressed.connect(_on_exit_pressed)


# 将背景图缩放以填满整个视口（裁剪多余部分，不留空白）
func _fit_camera_to_background():
	if not bg or not bg.texture:
		return

	var img_size: Vector2 = bg.texture.get_size()
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size

	if img_size.x <= 0 or img_size.y <= 0:
		return

	# 重置背景精灵的变换，由相机统一控制缩放
	bg.position = Vector2.ZERO
	bg.scale = Vector2.ONE

	# 计算缩放比例，取两者中较大的，保证图片填满屏幕无空白
	var zoom_x: float = viewport_size.x / img_size.x
	var zoom_y: float = viewport_size.y / img_size.y
	var zoom: float = max(zoom_x, zoom_y)

	camera.zoom = Vector2(zoom, zoom)

	# 将相机对准图片中心
	camera.position = img_size / 2.0


func _on_start_pressed():
	if music:
		music.stop()
	get_tree().change_scene_to_file("res://scenes/maps/intro.tscn")


func _on_exit_pressed():
	# 保存存档（如果有需要）
	# 直接退出游戏
	if music:
		music.stop()
	get_tree().quit()


func _on_load_pressed():
	if _save_load_ui and is_instance_valid(_save_load_ui):
		return

	var save_ui = load("res://scripts/ui/SaveLoadUI.gd").new()
	save_ui.mode = "load"
	save_ui.name = "SaveLoadUI"
	add_child(save_ui)
	_save_load_ui = save_ui
	save_ui.back_pressed.connect(_on_save_ui_back)
	save_ui.load_selected.connect(_on_save_ui_load_selected)


func _on_save_ui_back():
	_save_load_ui = null


func _on_save_ui_load_selected(slot: int):
	_save_load_ui = null
	if music:
		music.stop()


func _update_load_button_state():
	var has_save: bool = false
	for i in range(GameData.SAVE_SLOT_COUNT):
		if GameData.get_save_slot_info(i).get("exists", false):
			has_save = true
			break
	btn_load.disabled = not has_save
	if not has_save:
		btn_load.modulate.a = 0.5
		print("[开始界面] 未检测到存档，加载按钮已禁用")
	else:
		btn_load.modulate.a = 1.0
		print("[开始界面] 检测到存档，加载按钮已启用")


func _input(event):
	if _save_load_ui and is_instance_valid(_save_load_ui):
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_ESCAPE:
				get_viewport().set_input_as_handled()
				_save_load_ui.queue_free()
				_save_load_ui = null
