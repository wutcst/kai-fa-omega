extends CanvasLayer
# ============================================================
# 存档 / 读档选择界面
# mode: "save" 或 "load"
# 在 save 模式下，保存后自动跳转回 start 界面
# 在 load 模式下，读取后跳转到存档记录的场景
# ============================================================

var mode: String = "save"  # "save" or "load"
var _slot_buttons: Array = []
var _close_requested: bool = false

signal save_completed(slot: int)
signal load_selected(slot: int)
signal back_pressed()

func _ready():
	_create_ui()

func _create_ui():
	layer = 100

	# 半透明背景遮罩
	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.size = get_viewport().get_visible_rect().size
	dim.name = "DimBg"
	add_child(dim)

	# 主面板
	var panel = Panel.new()
	panel.name = "MainPanel"
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	panel_style.set_corner_radius_all(16)
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.4, 0.35, 0.25)
	panel.add_theme_stylebox_override("panel", panel_style)

	var vs = get_viewport().get_visible_rect().size
	var panel_w = 500
	var panel_h = 420
	panel.position = Vector2((vs.x - panel_w) / 2, (vs.y - panel_h) / 2)
	panel.size = Vector2(panel_w, panel_h)
	add_child(panel)

	# 标题
	var title = Label.new()
	title.text = "📁 存档选择" if mode == "save" else "📂 读取存档"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 16)
	title.size = Vector2(panel_w, 36)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	panel.add_child(title)

	# 提示文字
	if mode == "save":
		var hint = Label.new()
		hint.text = "点击空位存档，点击已有存档覆盖"
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.position = Vector2(0, 52)
		hint.size = Vector2(panel_w, 20)
		hint.add_theme_font_size_override("font_size", 12)
		hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		panel.add_child(hint)

	# 3 个存档槽位
	for i in range(GameData.SAVE_SLOT_COUNT):
		_create_slot_panel(panel, i, 80 + i * 100)

	# 返回按钮
	var btn_back = Button.new()
	btn_back.text = "返回"
	btn_back.position = Vector2((panel_w - 120) / 2, panel_h - 50)
	btn_back.size = Vector2(120, 36)
	btn_back.add_theme_font_size_override("font_size", 14)
	_apply_button_style(btn_back, Color(0.3, 0.3, 0.35))
	btn_back.pressed.connect(_on_back_pressed)
	panel.add_child(btn_back)

func _create_slot_panel(parent: Panel, slot: int, y_pos: float):
	var panel_w = 500.0
	var info = GameData.get_save_slot_info(slot)

	# 槽位背景
	var slot_bg = Panel.new()
	slot_bg.name = "SlotBg_" + str(slot)
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.18, 0.18, 0.22, 0.9)
	bg_style.set_corner_radius_all(8)
	slot_bg.add_theme_stylebox_override("panel", bg_style)
	slot_bg.position = Vector2(25, y_pos)
	slot_bg.size = Vector2(panel_w - 50, 88)
	parent.add_child(slot_bg)

	# 槽位编号
	var slot_label = Label.new()
	slot_label.text = "存档 " + str(slot + 1)
	slot_label.position = Vector2(12, 8)
	slot_label.size = Vector2(60, 20)
	slot_label.add_theme_font_size_override("font_size", 14)
	slot_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.4))
	slot_bg.add_child(slot_label)

	if info.get("exists", false):
		# 存档信息
		var info_text = "Lv.%d  |  %s  |  💰%d" % [info.get("level", 1), info.get("scene", "?"), info.get("gold", 0)]
		var info_label = Label.new()
		info_label.text = info_text
		info_label.position = Vector2(80, 8)
		info_label.size = Vector2(300, 20)
		info_label.add_theme_font_size_override("font_size", 13)
		info_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		slot_bg.add_child(info_label)

		# 时间戳
		var ts = info.get("timestamp", 0)
		var time_str = _format_timestamp(ts)
		var time_label = Label.new()
		time_label.text = "保存时间：" + time_str
		time_label.position = Vector2(12, 32)
		time_label.size = Vector2(250, 18)
		time_label.add_theme_font_size_override("font_size", 11)
		time_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		slot_bg.add_child(time_label)

		# 操作按钮
		var btn_w = 100
		if mode == "save":
			# 覆盖按钮
			var btn_overwrite = Button.new()
			btn_overwrite.text = "覆盖存档"
			btn_overwrite.position = Vector2(panel_w - 50 - btn_w - 110, 50)
			btn_overwrite.size = Vector2(btn_w, 28)
			btn_overwrite.add_theme_font_size_override("font_size", 12)
			_apply_button_style(btn_overwrite, Color(0.85, 0.55, 0.15))
			btn_overwrite.pressed.connect(_on_save_slot.bind(slot))
			slot_bg.add_child(btn_overwrite)

			# 删除按钮
			var btn_delete = Button.new()
			btn_delete.text = "删除"
			btn_delete.position = Vector2(panel_w - 50 - btn_w + 10, 50)
			btn_delete.size = Vector2(60, 28)
			btn_delete.add_theme_font_size_override("font_size", 12)
			_apply_button_style(btn_delete, Color(0.7, 0.2, 0.2))
			btn_delete.pressed.connect(_on_delete_slot.bind(slot, parent))
			slot_bg.add_child(btn_delete)
		else:
			# 读取按钮
			var btn_load = Button.new()
			btn_load.text = "读取进度"
			btn_load.position = Vector2(panel_w - 50 - btn_w - 110, 50)
			btn_load.size = Vector2(btn_w, 28)
			btn_load.add_theme_font_size_override("font_size", 12)
			_apply_button_style(btn_load, Color(0.2, 0.6, 0.3))
			btn_load.pressed.connect(_on_load_slot.bind(slot))
			slot_bg.add_child(btn_load)

			# 删除按钮
			var btn_delete = Button.new()
			btn_delete.text = "删除"
			btn_delete.position = Vector2(panel_w - 50 - btn_w + 10, 50)
			btn_delete.size = Vector2(60, 28)
			btn_delete.add_theme_font_size_override("font_size", 12)
			_apply_button_style(btn_delete, Color(0.7, 0.2, 0.2))
			btn_delete.pressed.connect(_on_delete_slot.bind(slot, parent))
			slot_bg.add_child(btn_delete)
	else:
		# 空槽位
		var empty_label = Label.new()
		empty_label.text = "（空）"
		empty_label.position = Vector2(80, 8)
		empty_label.size = Vector2(100, 20)
		empty_label.add_theme_font_size_override("font_size", 13)
		empty_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
		slot_bg.add_child(empty_label)

		if mode == "save":
			var btn_save = Button.new()
			btn_save.text = "保存到此"
			btn_save.position = Vector2(panel_w - 50 - 100, 52)
			btn_save.size = Vector2(100, 28)
			btn_save.add_theme_font_size_override("font_size", 12)
			_apply_button_style(btn_save, Color(0.2, 0.5, 0.7))
			btn_save.pressed.connect(_on_save_slot.bind(slot))
			slot_bg.add_child(btn_save)

func _on_save_slot(slot: int):
	if GameData.save_game(slot):
		emit_signal("save_completed", slot)
		# 回到 start 界面
		_close_requested = true
		var tree = get_tree()
		if tree:
			# 停止所有音乐
			var music_players = tree.get_nodes_in_group("music")
			for mp in music_players:
				if mp is AudioStreamPlayer:
					mp.stop()
			tree.call_deferred("change_scene_to_file", "res://scenes/maps/start.tscn")

func _on_load_slot(slot: int):
	var info = GameData.get_save_slot_info(slot)
	if not info.get("exists", false):
		return

	if GameData.load_game(slot):
		emit_signal("load_selected", slot)
		_close_requested = true
		var tree = get_tree()
		if tree:
			var music_players = tree.get_nodes_in_group("music")
			for mp in music_players:
				if mp is AudioStreamPlayer:
					mp.stop()
			var scene_path = info.get("last_scene", "res://scenes/maps/village.tscn")
			tree.call_deferred("change_scene_to_file", scene_path)

func _on_delete_slot(slot: int, parent: Panel):
	GameData.delete_save(slot)
	# 刷新界面
	for child in get_children():
		child.queue_free()
	call_deferred("_create_ui")

func _on_back_pressed():
	emit_signal("back_pressed")
	_close_requested = true
	queue_free()

func _apply_button_style(btn: Button, bg_color: Color):
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = bg_color
	style_normal.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("normal", style_normal)

	var style_hover = style_normal.duplicate()
	style_hover.bg_color = bg_color.lightened(0.2)
	btn.add_theme_stylebox_override("hover", style_hover)

	var style_pressed = style_normal.duplicate()
	style_pressed.bg_color = bg_color.darkened(0.2)
	btn.add_theme_stylebox_override("pressed", style_pressed)

	btn.add_theme_color_override("font_color", Color(1, 1, 1))

func _format_timestamp(ts: int) -> String:
	var dt = Time.get_datetime_dict_from_unix_time(ts)
	return "%d-%02d-%02d %02d:%02d:%02d" % [dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second]