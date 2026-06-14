extends Node2D

# ============================================================
# 通用场景脚本：gamescene / ground1 / ground2 / ground3 共用
# 在 scene 文件中配置 next_scene_path 即可让"下一关"按钮跳转到不同场景
# ============================================================

@export var next_scene_path: String = ""          # 为空则不显示跳转按钮（比如 gamescene 主场景）
@export var scene_title: String = ""              # 场景标题（可选）

var _btn_level_up: Button = null
var _level_up_hint_label: Label = null
var _level_up_info_label: Label = null
var _btn_next_scene: Button = null

func _ready():
	_create_level_up_button()
	if next_scene_path != "":
		_create_next_scene_button()
	_update_level_up_info()

# 创建右上角自动升级按钮
func _create_level_up_button():
	# 用 CanvasLayer 让 UI 不跟随玩家移动
	var canvas = CanvasLayer.new()
	canvas.name = "LevelUpCanvas"
	add_child(canvas)

	# VBox：信息标签 + 按钮 + 提示
	var container = VBoxContainer.new()
	container.name = "LevelUpContainer"
	container.add_theme_constant_override("separation", 4)
	canvas.add_child(container)

	# 右上角位置：根据视口宽度计算
	var viewport_size = get_viewport().get_visible_rect().size
	var btn_width = 170
	container.position = Vector2(viewport_size.x - btn_width - 20, 20)

	# 信息标签（显示当前等级）
	_level_up_info_label = Label.new()
	_level_up_info_label.name = "LevelInfoLabel"
	_level_up_info_label.text = "Lv." + str(GameData.level)
	_level_up_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_level_up_info_label.custom_minimum_size = Vector2(btn_width, 0)
	_level_up_info_label.add_theme_font_size_override("font_size", 14)
	_level_up_info_label.add_theme_color_override("font_color", Color(0.98, 0.85, 0.4))
	container.add_child(_level_up_info_label)

	# 升级按钮
	_btn_level_up = Button.new()
	_btn_level_up.name = "BtnLevelUp"
	_btn_level_up.text = "⬆ 自动升级"
	_btn_level_up.custom_minimum_size = Vector2(btn_width, 44)
	_btn_level_up.add_theme_font_size_override("font_size", 16)

	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.78, 0.5, 0.15)
	style_normal.set_corner_radius_all(8)
	style_normal.border_width_left = 2
	style_normal.border_width_right = 2
	style_normal.border_width_top = 2
	style_normal.border_width_bottom = 2
	style_normal.border_color = Color(1.0, 0.85, 0.3)

	var style_hover = style_normal.duplicate()
	style_hover.bg_color = Color(0.95, 0.65, 0.2)

	var style_pressed = style_normal.duplicate()
	style_pressed.bg_color = Color(0.6, 0.35, 0.1)

	_btn_level_up.add_theme_stylebox_override("normal", style_normal)
	_btn_level_up.add_theme_stylebox_override("hover", style_hover)
	_btn_level_up.add_theme_stylebox_override("pressed", style_pressed)
	_btn_level_up.add_theme_color_override("font_color", Color(1, 1, 1))

	container.add_child(_btn_level_up)

	# 提示标签
	_level_up_hint_label = Label.new()
	_level_up_hint_label.name = "LevelHintLabel"
	_level_up_hint_label.text = "按一次直接升一级"
	_level_up_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_level_up_hint_label.custom_minimum_size = Vector2(btn_width, 0)
	_level_up_hint_label.add_theme_font_size_override("font_size", 10)
	_level_up_hint_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	container.add_child(_level_up_hint_label)

	_btn_level_up.pressed.connect(_on_level_up_pressed)

# 创建左上角"下一关"按钮
func _create_next_scene_button():
	var canvas = get_node_or_null("LevelUpCanvas")
	if canvas == null:
		canvas = CanvasLayer.new()
		canvas.name = "LevelUpCanvas"
		add_child(canvas)

	var container = VBoxContainer.new()
	container.name = "NextSceneContainer"
	container.add_theme_constant_override("separation", 4)
	canvas.add_child(container)
	container.position = Vector2(20, 20)

	var btn_width = 170

	# 标题标签（显示场景名）
	if scene_title != "":
		var title = Label.new()
		title.name = "SceneTitle"
		title.text = scene_title
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		title.custom_minimum_size = Vector2(btn_width, 0)
		title.add_theme_font_size_override("font_size", 14)
		title.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
		container.add_child(title)

	# 跳转按钮
	_btn_next_scene = Button.new()
	_btn_next_scene.name = "BtnNextScene"
	_btn_next_scene.text = "→ 前往下一关"
	_btn_next_scene.custom_minimum_size = Vector2(btn_width, 44)
	_btn_next_scene.add_theme_font_size_override("font_size", 16)

	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.15, 0.5, 0.78)
	style_normal.set_corner_radius_all(8)
	style_normal.border_width_left = 2
	style_normal.border_width_right = 2
	style_normal.border_width_top = 2
	style_normal.border_width_bottom = 2
	style_normal.border_color = Color(0.5, 0.85, 1.0)

	var style_hover = style_normal.duplicate()
	style_hover.bg_color = Color(0.25, 0.65, 0.95)

	var style_pressed = style_normal.duplicate()
	style_pressed.bg_color = Color(0.1, 0.35, 0.6)

	_btn_next_scene.add_theme_stylebox_override("normal", style_normal)
	_btn_next_scene.add_theme_stylebox_override("hover", style_hover)
	_btn_next_scene.add_theme_stylebox_override("pressed", style_pressed)
	_btn_next_scene.add_theme_color_override("font_color", Color(1, 1, 1))

	container.add_child(_btn_next_scene)

	_btn_next_scene.pressed.connect(_on_next_scene_pressed)

func _on_next_scene_pressed():
	if next_scene_path == "":
		return
	print("→ 跳转到下一关：", next_scene_path)
	get_tree().change_scene_to_file(next_scene_path)

func _on_level_up_pressed():
	GameData.level_up()
	# 同步玩家节点本地属性，防止进入战斗时 save_data_to_global 覆盖升级后的数据
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var player_node = players[0]
		if player_node.has_method("load_data_from_global"):
			player_node.load_data_from_global()
	_update_level_up_info()
	_show_level_up_flash()

func _update_level_up_info():
	if is_instance_valid(_level_up_info_label):
		_level_up_info_label.text = "Lv." + str(GameData.level) + "  升级自动回满血蓝"

# 升级时的缩放反馈动画
func _show_level_up_flash():
	if not is_instance_valid(_btn_level_up):
		return
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(_btn_level_up, "scale", Vector2(1.15, 1.15), 0.1)
	tween.chain().tween_property(_btn_level_up, "scale", Vector2(1.0, 1.0), 0.15)
