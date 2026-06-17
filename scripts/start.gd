extends Node2D

# ============================================================
# 开始界面脚本
# 使用 Node2D + Camera2D + CanvasLayer 架构
# 相机自动缩放以完整显示背景图
# ============================================================

const SAVE_FILE_PATH := "user://rpg_savegame.save"

@onready var bg: Sprite2D = $Background
@onready var camera: Camera2D = $Camera2D
@onready var btn_start: Button = $UI/MenuPanel/MenuContent/btn_start
@onready var btn_load: Button = $UI/MenuPanel/MenuContent/btn_load
@onready var music: AudioStreamPlayer = $Music

func _ready():
	# 让相机自动缩放完整显示背景图
	_fit_camera_to_background()

	if music and music.stream:
		music.volume_db = -10.0
		music.play()

	_update_load_button_state()

	btn_start.pressed.connect(_on_start_pressed)
	btn_load.pressed.connect(_on_load_pressed)

# 将背景图完整显示在视口中
func _fit_camera_to_background():
	if not bg or not bg.texture:
		return

	var img_size: Vector2 = bg.texture.get_size()
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size

	if img_size.x <= 0 or img_size.y <= 0:
		return

	# 计算缩放比例，取两者中较小的，保证图片完整显示
	var zoom_x: float = viewport_size.x / img_size.x
	var zoom_y: float = viewport_size.y / img_size.y
	var zoom: float = min(zoom_x, zoom_y)

	camera.zoom = Vector2(zoom, zoom)

	# 将相机对准图片中心
	camera.position = img_size / 2.0

func _on_start_pressed():
	if music:
		music.stop()
	get_tree().change_scene_to_file("res://scenes/intro.tscn")

func _on_load_pressed():
	if not FileAccess.file_exists(SAVE_FILE_PATH):
		print("[开始界面] 未找到存档文件：", SAVE_FILE_PATH)
		return

	# 【存档系统接入点】
	# 未来实现：
	# 1. var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	# 2. GameData.load_from_file(file)
	# 3. 根据存档记录的 last_scene 跳转

	print("[开始界面] 读取存档成功（占位逻辑）")
	if music:
		music.stop()
	get_tree().change_scene_to_file("res://scenes/village.tscn")

func _update_load_button_state():
	var has_save: bool = FileAccess.file_exists(SAVE_FILE_PATH)
	btn_load.disabled = not has_save
	if not has_save:
		btn_load.modulate.a = 0.5
		print("[开始界面] 未检测到存档，加载按钮已禁用")
	else:
		btn_load.modulate.a = 1.0
		print("[开始界面] 检测到存档，加载按钮已启用")
