extends Node2D

# ============================================================
# 通用场景脚本：gamescene / ground1 / ground2 / ground3 共用
# ============================================================

@export var scene_title: String = ""              # 场景标题（可选）
@export var bgm_path: String = ""                 # 背景音乐文件路径
@export var is_village_scene: bool = false            # 是否是村庄场景（在场景文件中勾选）
@export var min_zoom: float = 1.0                 # 相机最小缩放值，防止视角过大（越大视野越小）

var _btn_level_up: Button = null
var _level_up_hint_label: Label = null
var _level_up_info_label: Label = null
var _bgm_player: AudioStreamPlayer = null
var _welcome_canvas: CanvasLayer = null
var _save_load_ui: CanvasLayer = null

# 当前场景缓存标志，避免重复解析路径
var _is_village: bool = false

func _ready():
	# 通过 scene_file_path 或显式标志判断当前场景
	_is_village = _check_is_village_scene()
	# 村庄场景配置标题
	if _is_village:
		if scene_title == "":
			scene_title = "🏘️ 村庄"
	
	# 进入战斗地图时，刷新所有普通怪物（Boss 除外）
	_refresh_regular_monsters()
	
	_setup_scene_nodes()
	
	# 延迟调用确保 viewport 尺寸已正确，并监听窗口大小变化
	call_deferred("_fit_camera_to_limits")
	get_tree().root.size_changed.connect(_fit_camera_to_limits)
	
	_create_level_up_button()
	_update_level_up_info()
	_play_bgm()

	if _is_village and GameData.show_village_welcome:
		_show_village_welcome()

# 判断是否是村庄场景：优先使用显式导出变量，否则通过 scene_file_path 兜底
func _check_is_village_scene() -> bool:
	if is_village_scene:
		return true
	if get_tree() == null:
		return false
	var current = get_tree().current_scene
	if current == null:
		return false
	var path: String = current.scene_file_path
	if path == "":
		return false
	# 大小写不敏感比较，避免不同平台路径分隔符问题
	return "village" in path.to_lower()

# 判断是否是战斗地图（forest / undead / finalbattle）
func _is_battle_map_scene() -> bool:
	if get_tree() == null:
		return false
	var current = get_tree().current_scene
	if current == null:
		return false
	var path: String = current.scene_file_path
	if path == "":
		return false
	var lower = path.to_lower()
	return "forest" in lower or "undead" in lower or "finalbattle" in lower

# 进入战斗地图时，清除普通怪物击败记录（Boss 保留）
func _refresh_regular_monsters():
	if _is_battle_map_scene() and GameData.defeated_monster_positions.size() > 0:
		print("→ 进入战斗地图，刷新所有普通怪物（清除 ", GameData.defeated_monster_positions.size(), " 条击败记录）")
		GameData.defeated_monster_positions.clear()

func _setup_scene_nodes():
	var is_village = _is_village

	# 如果没有玩家，自动创建玩家实例
	var players = get_tree().get_nodes_in_group("player")
	if players.size() == 0:
		var player_scene = load("res://scenes/entities/player.tscn")
		if player_scene:
			var player_instance = player_scene.instantiate()
			player_instance.name = "Player"
			# 如果有 SpawnPoint，使用其位置；否则使用默认位置
			var spawn = get_node_or_null("SpawnPoint")
			if spawn:
				player_instance.global_position = spawn.global_position
			else:
				player_instance.position = Vector2(300, 300)
			add_child(player_instance)

			# 将相机挂载到玩家身上，实现视角跟随
			var camera = get_node_or_null("Camera2D")
			if camera:
				camera.reparent(player_instance)
				camera.position = Vector2.ZERO

	# 重新获取玩家（可能刚创建）
	players = get_tree().get_nodes_in_group("player")

	# 根据相机 limit 生成空气墙，防止玩家走出地图
	_create_boundary_walls()


	# 仅在村庄场景中自动创建 NPC
	if not is_village:
		return

	# 如果没有商人，自动创建商人实例
	var merchants = get_tree().get_nodes_in_group("merchant")
	if merchants.size() == 0:
		var merchant_scene = load("res://scenes/npc/merchant.tscn")
		if merchant_scene:
			var merchant_instance = merchant_scene.instantiate()
			merchant_instance.name = "merchant"
			merchant_instance.position = Vector2(500, 300)
			add_child(merchant_instance)

	# 如果没有旅馆老板，自动创建旅馆老板实例
	var hotel_owners = get_tree().get_nodes_in_group("hotel_owner")
	if hotel_owners.size() == 0:
		var hotel_scene = load("res://scenes/npc/hotel_owner.tscn")
		if hotel_scene:
			var hotel_instance = hotel_scene.instantiate()
			hotel_instance.name = "hotel owner"
			hotel_instance.position = Vector2(378, 209)
			add_child(hotel_instance)

# ─── 根据视口大小和相机 limits 自动调整 zoom，确保地图填满屏幕不留空白 ───
func _fit_camera_to_limits():
	var camera = _find_camera()
	if not camera:
		return

	# 检查相机 limits 是否有效（未设置时为超大默认值）
	var limit_w = camera.limit_right - camera.limit_left
	var limit_h = camera.limit_bottom - camera.limit_top
	if limit_w <= 0 or limit_h <= 0 or limit_w >= 1000000 or limit_h >= 1000000:
		return

	var viewport_size = get_viewport().get_visible_rect().size
	if viewport_size.x <= 0 or viewport_size.y <= 0:
		return

	# 计算缩放比例，取 max 确保可见区域不超出相机 limits，填满屏幕
	var zoom_x = viewport_size.x / float(limit_w)
	var zoom_y = viewport_size.y / float(limit_h)
	var zoom = max(zoom_x, zoom_y, min_zoom)
	camera.zoom = Vector2(zoom, zoom)

# 查找相机节点（可能在根节点或玩家节点下）
func _find_camera() -> Camera2D:
	var camera = get_node_or_null("Camera2D")
	if camera and camera is Camera2D:
		return camera
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		camera = players[0].get_node_or_null("Camera2D")
		if camera and camera is Camera2D:
			return camera
	return null

# ─── 空气墙：根据相机 limit 生成四边不可见碰撞墙 ───
func _create_boundary_walls():
	# 找到相机（可能在根节点或在玩家节点下）
	var camera = get_node_or_null("Camera2D")
	if not camera:
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			camera = players[0].get_node_or_null("Camera2D")
	if not camera or not (camera is Camera2D):
		return

	var c: Camera2D = camera
	var l: int = c.limit_left
	var r: int = c.limit_right
	var t: int = c.limit_top
	var b: int = c.limit_bottom

	# 如果 limit 没设置（默认超大值），跳过
	if l <= -1000000 or r >= 1000000 or t <= -1000000 or b >= 1000000:
		return
	if r <= l or b <= t:
		return

	var wall_thickness := 10.0  # 墙的厚度（像素）
	var inward := 15.0           # 向内收缩量（像素），越大越靠里

	# 左墙：从 limit_left 向内缩 inward
	_create_wall("BoundaryWall_Left", Vector2(l + inward, (t + b) / 2.0),
		Vector2(wall_thickness, b - t + wall_thickness * 2))

	# 右墙：从 limit_right 向内缩 inward
	_create_wall("BoundaryWall_Right", Vector2(r - inward, (t + b) / 2.0),
		Vector2(wall_thickness, b - t + wall_thickness * 2))

	# 上墙：贴紧 limit_top，不缩
	_create_wall("BoundaryWall_Top", Vector2((l + r) / 2.0, t - wall_thickness / 2),
		Vector2(r - l + wall_thickness * 2, wall_thickness))

	# 下墙：从 limit_bottom 向内缩 inward
	_create_wall("BoundaryWall_Bottom", Vector2((l + r) / 2.0, b - inward),
		Vector2(r - l + wall_thickness * 2, wall_thickness))

	print("✅ 空气墙已生成: (", l, ",", t, ") 到 (", r, ",", b, ")")

# 创建单面空气墙
func _create_wall(wall_name: String, pos: Vector2, size: Vector2):
	var wall := StaticBody2D.new()
	wall.name = wall_name
	wall.collision_layer = 1
	wall.collision_mask = 0
	add_child(wall)

	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position = Vector2.ZERO
	wall.add_child(shape)

	wall.position = pos

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

	# 分隔间距
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	container.add_child(spacer)

	# 存档按钮
	var btn_save = Button.new()
	btn_save.name = "BtnSave"
	btn_save.text = "💾 存档"
	btn_save.custom_minimum_size = Vector2(btn_width, 38)
	btn_save.add_theme_font_size_override("font_size", 14)

	var save_style_normal = StyleBoxFlat.new()
	save_style_normal.bg_color = Color(0.2, 0.5, 0.7)
	save_style_normal.set_corner_radius_all(8)
	save_style_normal.border_width_left = 2
	save_style_normal.border_width_right = 2
	save_style_normal.border_width_top = 2
	save_style_normal.border_width_bottom = 2
	save_style_normal.border_color = Color(0.4, 0.7, 1.0)

	var save_style_hover = save_style_normal.duplicate()
	save_style_hover.bg_color = Color(0.3, 0.6, 0.85)

	var save_style_pressed = save_style_normal.duplicate()
	save_style_pressed.bg_color = Color(0.15, 0.35, 0.5)

	btn_save.add_theme_stylebox_override("normal", save_style_normal)
	btn_save.add_theme_stylebox_override("hover", save_style_hover)
	btn_save.add_theme_stylebox_override("pressed", save_style_pressed)
	btn_save.add_theme_color_override("font_color", Color(1, 1, 1))
	btn_save.pressed.connect(_on_save_pressed)
	container.add_child(btn_save)

	_btn_level_up.pressed.connect(_on_level_up_pressed)

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

func _play_bgm():
	if bgm_path == "":
		return
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.name = "BGMMusic"
	_bgm_player.bus = "Master"
	_bgm_player.volume_db = -8.0
	add_child(_bgm_player)
	var stream = load(bgm_path)
	if stream and stream is AudioStream:
		_bgm_player.stream = stream
		# AudioStream 基类没有 loop 属性，需要用 audio_stream 自身的循环接口
		# 如 AudioStreamMP3.loop_mode 等，这里直接播放，由引擎默认循环处理
		_bgm_player.play()

func _show_village_welcome():
	GameData.show_village_welcome = false
	var canvas = CanvasLayer.new()
	canvas.name = "VillageWelcomeCanvas"
	canvas.layer = 100
	add_child(canvas)
	_welcome_canvas = canvas

	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.size = get_viewport().get_visible_rect().size
	canvas.add_child(dim)

	var label = Label.new()
	label.text = "拯救世界的勇者已经到来"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", Color(1, 0.9, 0.5, 1))
	label.size = get_viewport().get_visible_rect().size
	canvas.add_child(label)

	var hint = Label.new()
	hint.text = "按 E 继续"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	var vs = get_viewport().get_visible_rect().size
	hint.position = Vector2(0, vs.y - 60)
	hint.size = Vector2(vs.x, 40)
	canvas.add_child(hint)

func _dismiss_welcome():
	if is_instance_valid(_welcome_canvas):
		_welcome_canvas.queue_free()
		_welcome_canvas = null

func _input(event):
	if _welcome_canvas and is_instance_valid(_welcome_canvas):
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_E:
				get_viewport().set_input_as_handled()
				_dismiss_welcome()
	elif _save_load_ui and is_instance_valid(_save_load_ui):
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_ESCAPE:
				get_viewport().set_input_as_handled()
				_save_load_ui.queue_free()
				_save_load_ui = null

# 存档按钮回调
func _on_save_pressed():
	if _save_load_ui and is_instance_valid(_save_load_ui):
		return

	# 先同步玩家数据到全局
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var player_node = players[0]
		if player_node.has_method("save_data_to_global"):
			player_node.save_data_to_global()

	var save_ui = load("res://scripts/ui/SaveLoadUI.gd").new()
	save_ui.mode = "save"
	save_ui.name = "SaveLoadUI"
	add_child(save_ui)
	_save_load_ui = save_ui
	save_ui.back_pressed.connect(_on_save_ui_back)
	save_ui.save_completed.connect(_on_save_ui_save_completed)

func _on_save_ui_back():
	_save_load_ui = null

func _on_save_ui_save_completed(slot: int):
	_save_load_ui = null
