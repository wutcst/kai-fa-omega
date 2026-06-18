extends CanvasLayer

# ============================================================
# 物品栏 / 人物信息面板
#   - 使用统一的容器布局，避免图标/文字错位
#   - 装备槽 + 道具栏 + 专属背包栏 都有固定尺寸
# ============================================================

const ICON_SIZE: int = 32
const SLOT_PADDING: int = 4

# 是否显示中
var is_visible: bool = false
var player_ref: Node = null

signal inventory_closed

func _ready():
	setup_ui()
	hide_panel()

# 允许玩家按 Q 键或再次按 ui_inventory 动作关闭
# 注意：主要关闭逻辑由 player.gd 中的 toggle_inventory 驱动，
# 这里额外处理一次以防万一（并使用 set_input_as_handled 避免事件穿透）
func _unhandled_input(event: InputEvent):
	if not is_visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_Q or event.keycode == KEY_Q:
			hide_panel()
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("ui_inventory"):
		hide_panel()
		get_viewport().set_input_as_handled()

# ============================================================
# 创建一个带边框的图标容器（所有图标都用这一套，保证对齐）
# 使用 PanelContainer 让内部 TextureRect 自动居中，避免错位
# ============================================================
func _make_icon_box(icon_path: String, size: int = ICON_SIZE,
					border_color: Color = Color(0.4, 0.35, 0.25, 0.9),
					bg_color: Color = Color(0.15, 0.12, 0.2, 0.9)) -> PanelContainer:
	var box = PanelContainer.new()
	box.custom_minimum_size = Vector2(size + SLOT_PADDING * 2, size + SLOT_PADDING * 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = border_color
	style.set_corner_radius_all(4)
	style.content_margin_left = SLOT_PADDING
	style.content_margin_right = SLOT_PADDING
	style.content_margin_top = SLOT_PADDING
	style.content_margin_bottom = SLOT_PADDING
	box.add_theme_stylebox_override("panel", style)

	# 贴图：居中，保持比例
	var tex_rect = TextureRect.new()
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.custom_minimum_size = Vector2(size, size)
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex_rect.grow_horizontal = Control.GROW_DIRECTION_BOTH
	tex_rect.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.add_child(tex_rect)

	if icon_path and icon_path != "":
		var tex = load(icon_path)
		if tex is Texture2D:
			tex_rect.texture = tex
		else:
			tex_rect.modulate = Color(0.3, 0.25, 0.4, 1)
	else:
		tex_rect.modulate = Color(0.3, 0.25, 0.4, 1)

	return box

# ============================================================
# 可点击图标（用于背包栏里的装备）
# ============================================================
func _make_clickable_icon(icon_path: String, click_callback: Callable,
						  can_equip: bool, size: int = ICON_SIZE) -> PanelContainer:
	var box = _make_icon_box(icon_path, size,
								Color(0.9, 0.75, 0.3, 0.9) if can_equip else Color(0.4, 0.4, 0.4, 0.7),
								Color(0.15, 0.12, 0.2, 0.9))
	box.mouse_filter = Control.MOUSE_FILTER_STOP  # 允许接收鼠标事件
	box.gui_input.connect(click_callback)
	return box

# ============================================================
# 主 UI 构建
# ============================================================
func setup_ui():
	# 背景遮罩
	var mask = ColorRect.new()
	mask.name = "MaskBg"
	mask.color = Color(0, 0, 0, 0.55)
	mask.size = get_viewport().get_visible_rect().size
	mask.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(mask)

# 主面板（用 PanelContainer 确保子元素自动排列）
	var panel_outer = PanelContainer.new()
	panel_outer.name = "MainPanel"
	panel_outer.custom_minimum_size = Vector2(1050, 680)
	panel_outer.position = Vector2(
		(get_viewport().get_visible_rect().size.x - 1050) / 2,
		(get_viewport().get_visible_rect().size.y - 680) / 2
	)
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.10, 0.08, 0.16, 0.96)
	panel_style.set_corner_radius_all(12)
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.7, 0.55, 0.3, 0.85)
	panel_style.content_margin_left = 14
	panel_style.content_margin_right = 14
	panel_style.content_margin_top = 10
	panel_style.content_margin_bottom = 12
	panel_outer.add_theme_stylebox_override("panel", panel_style)
	add_child(panel_outer)

	# 内部垂直布局
	var panel = VBoxContainer.new()
	panel.name = "MainVBox"
	panel.add_theme_constant_override("separation", 4)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel_outer.add_child(panel)

	# 顶部标题栏
	var title_bar = VBoxContainer.new()
	title_bar.name = "TitleBar"
	title_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_bar.add_theme_constant_override("separation", 2)
	panel.add_child(title_bar)

	var title_label = Label.new()
	title_label.text = "⚔ 物品栏 / 人物信息 ⚔"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	title_bar.add_child(title_label)

	# 金币 / 等级信息
	var stats_line = HBoxContainer.new()
	stats_line.alignment = BoxContainer.ALIGNMENT_CENTER
	stats_line.add_theme_constant_override("separation", 30)
	title_bar.add_child(stats_line)

	var gold_lbl = Label.new()
	gold_lbl.text = "金币: %d" % GameData.gold
	gold_lbl.add_theme_font_size_override("font_size", 16)
	gold_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	stats_line.add_child(gold_lbl)

	var lv_lbl = Label.new()
	lv_lbl.text = "等级: Lv.%d" % GameData.level
	lv_lbl.add_theme_font_size_override("font_size", 16)
	lv_lbl.add_theme_color_override("font_color", Color(0.5, 0.9, 1.0))
	stats_line.add_child(lv_lbl)

	# 分隔线
	var sep = HSeparator.new()
	panel.add_child(sep)

	# 主内容：左栏（属性 + 装备槽） + 右栏（道具 + 背包）
	var content = HBoxContainer.new()
	content.name = "ContentContainer"
	content.add_theme_constant_override("separation", 12)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(content)

	# ----------- 左栏 -----------
	var left_col = VBoxContainer.new()
	left_col.name = "LeftColumn"
	left_col.add_theme_constant_override("separation", 8)
	left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_col.custom_minimum_size = Vector2(470, 0)
	content.add_child(left_col)

	_build_attributes_section(left_col)
	_build_equipment_section(left_col)

	# ----------- 右栏 -----------
	var right_col = VBoxContainer.new()
	right_col.name = "RightColumn"
	right_col.add_theme_constant_override("separation", 8)
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_col.custom_minimum_size = Vector2(400, 0)
	content.add_child(right_col)

	_build_items_section(right_col)
	_build_backpack_section(right_col)

	# 底部关闭提示
	var sep2 = HSeparator.new()
	panel.add_child(sep2)

	var hint = Label.new()
	hint.text = "按 Q 键关闭  |  点击右侧背包中的装备图标直接穿戴"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.65, 0.65, 0.7))
	panel.add_child(hint)

	# 窗口大小变化时刷新面板位置
	if not get_tree().root.size_changed.is_connected(_on_window_resized):
		get_tree().root.size_changed.connect(_on_window_resized)

# ============================================================
# 构建：人物属性区
# ============================================================
func _build_attributes_section(parent: VBoxContainer):
	var section = _make_section_panel(parent, "━━━━━ 人物属性 ━━━━━")

	var grid = VBoxContainer.new()
	grid.add_theme_constant_override("separation", 4)
	section.add_child(grid)

	# 血量
	var total_max_hp = GameData.get_total_max_hp()
	_add_bar_row(grid, "血量", GameData.current_hp, total_max_hp,
				 Color(0.95, 0.25, 0.25), Color(0.2, 0.08, 0.08))

	# 蓝量
	_add_bar_row(grid, "蓝量", GameData.current_mp, GameData.max_mp,
				 Color(0.3, 0.65, 0.95), Color(0.08, 0.12, 0.2))

	# 其他属性
	var attrs = [
		{"label": "攻击", "value": str(GameData.get_total_attack()), "color": Color(1.0, 0.55, 0.2)},
		{"label": "防御", "value": str(GameData.get_total_defense()), "color": Color(0.3, 0.85, 0.45)},
		{"label": "暴击", "value": str(GameData.crit) + "%", "color": Color(1.0, 0.9, 0.3)},
		{"label": "角色", "value": "冒险者", "color": Color(0.9, 0.85, 0.4)},
	]
	for attr in attrs:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var lab = _make_label(attr.label, 120, 16, Color(0.9, 0.9, 0.9))
		row.add_child(lab)
		var val = _make_label(attr.value, -1, 16, attr.color)
		row.add_child(val)
		grid.add_child(row)

# ============================================================
# 构建：装备槽（武器 / 护甲 / 饰品）
# ============================================================
func _build_equipment_section(parent: VBoxContainer):
	var section = _make_section_panel(parent, "━━━━━ 装备栏 ━━━━━")

	var grid = VBoxContainer.new()
	grid.add_theme_constant_override("separation", 6)
	section.add_child(grid)

	var slot_defs := [
		{"label": "武器", "key": "weapon", "bonus_field": "attack_bonus"},
		{"label": "护甲", "key": "armor", "bonus_field": "defense_bonus"},
		{"label": "饰品", "key": "accessory", "bonus_field": "hp_bonus"},
	]

	for slot_def in slot_defs:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)

		# 标签
		var lab = _make_label(slot_def.label + ":", 60, 14, Color(0.8, 0.75, 0.55))
		row.add_child(lab)

		# 数据
		var equip: Dictionary
		match slot_def.key:
			"weapon":    equip = GameData.weapon
			"armor":     equip = GameData.armor
			"accessory": equip = GameData.accessory
			_:           equip = {}
		var name_str: String = equip.get("name", "无")
		var is_empty: bool = (name_str == "无") or name_str == ""
		var icon_path: String = equip.get("icon", "") if not is_empty else ""

		# 图标
		var icon_box = _make_icon_box(icon_path, 28)
		row.add_child(icon_box)

		# 名字面板
		var name_panel = Panel.new()
		name_panel.custom_minimum_size = Vector2(150, 30)
		var ns = StyleBoxFlat.new()
		ns.bg_color = Color(0.18, 0.14, 0.24, 0.9)
		ns.set_corner_radius_all(4)
		ns.border_width_left = 1
		ns.border_width_right = 1
		ns.border_width_top = 1
		ns.border_width_bottom = 1
		ns.border_color = Color(0.4, 0.35, 0.25, 0.6)
		name_panel.add_theme_stylebox_override("panel", ns)
		row.add_child(name_panel)

		var name_lbl = Label.new()
		name_lbl.text = name_str if not is_empty else "（空）"
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		name_lbl.add_theme_font_size_override("font_size", 14)
		name_lbl.add_theme_color_override("font_color",
										  Color(0.95, 0.85, 0.4) if not is_empty else Color(0.4, 0.4, 0.4))
		name_panel.add_child(name_lbl)

		# 加成文字
		var bonus_val: int = equip.get(slot_def.bonus_field, 0)
		var bonus_str: String = ""
		if not is_empty and bonus_val > 0:
			match slot_def.bonus_field:
				"attack_bonus":
					bonus_str = "+%d 攻击" % bonus_val
				"defense_bonus":
					bonus_str = "+%d 防御" % bonus_val
				"hp_bonus":
					bonus_str = "+%d 生命" % bonus_val

		var bonus_lbl = _make_label(bonus_str, -1, 13, Color(0.5, 0.95, 0.55))
		bonus_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(bonus_lbl)

		# 卸下按钮
		var unequip_btn = Button.new()
		unequip_btn.text = "卸下"
		unequip_btn.custom_minimum_size = Vector2(60, 30)
		unequip_btn.add_theme_font_size_override("font_size", 12)
		unequip_btn.disabled = is_empty
		var key_copy: String = slot_def.key
		unequip_btn.pressed.connect(_on_unequip_clicked.bind(key_copy))
		row.add_child(unequip_btn)

		grid.add_child(row)

# ============================================================
# 构建：道具栏（血瓶 / 蓝瓶）
# ============================================================
func _build_items_section(parent: VBoxContainer):
	var section = _make_section_panel(parent, "━━━━━ 道具栏 ━━━━━")

	if GameData.inventory_items.size() == 0:
		var empty = _make_label("（暂无道具）", -1, 14, Color(0.5, 0.5, 0.5))
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		section.add_child(empty)
		return

	for item in GameData.inventory_items:
		if not item is Dictionary:
			continue

		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)

		# 图标
		var icon_box = _make_icon_box(item.get("icon", ""), 28)
		row.add_child(icon_box)

		# 名字
		var name_lbl = _make_label(item.get("name", "???"), 100, 14, Color(1.0, 0.9, 0.8))
		row.add_child(name_lbl)

		# 数量
		var qty_lbl = _make_label("x%d" % item.get("quantity", 0), 60, 14, Color(0.95, 0.85, 0.45))
		row.add_child(qty_lbl)

		# 描述
		var desc = _make_label(item.get("description", ""), -1, 12, Color(0.65, 0.75, 0.85))
		desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(desc)

		section.add_child(row)

# ============================================================
# 构建：专属背包栏（未装备的装备）
# ============================================================
func _build_backpack_section(parent: VBoxContainer):
	var section = _make_section_panel(parent, "━━━━━ 专属背包栏（装备）━━━━━", true)
	section.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var hint = _make_label("（点击图标直接装备或使用，会替换当前装备）",
							-1, 11, Color(0.55, 0.55, 0.6))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	section.add_child(hint)

	if GameData.exclusive_backpack.size() == 0:
		var empty = _make_label("（背包栏为空 - 击败怪物获取装备）", -1, 14, Color(0.5, 0.5, 0.5))
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.size_flags_vertical = Control.SIZE_EXPAND_FILL
		section.add_child(empty)
		return

	for i in range(GameData.exclusive_backpack.size()):
		var item: Dictionary = GameData.exclusive_backpack[i]
		if not item is Dictionary:
			continue

		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)

		# 类型检测 - 支持装备和食物
		var item_type: String = item.get("type", "")

		# 可点击图标
		var icon_path: String = item.get("icon", "")
		var click_cb = func(event: InputEvent, idx: int, itype: String):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				if itype == "food":
					_on_backpack_icon_clicked(event, idx)
				else:
					equip_from_backpack(idx)
		var icon_box = _make_clickable_icon(icon_path, click_cb.bind(i, item_type),
											 true, 28)
		row.add_child(icon_box)

		# 名字
		var name_lbl = _make_label(item.get("name", "???"), 100, 14, Color(1.0, 0.9, 0.8))
		row.add_child(name_lbl)

		# 类型
		var type_str: String = "[" + _type_display(item_type) + "]"
		var type_lbl = _make_label(type_str, 70, 12, Color(0.85, 0.7, 0.45))
		row.add_child(type_lbl)

		# 加成
		var bonus_str: String = _get_item_bonus_text(item)
		var bonus_lbl = _make_label(bonus_str, -1, 13, Color(0.55, 0.95, 0.55))
		bonus_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(bonus_lbl)

		section.add_child(row)

# ============================================================
# 辅助：标签
# ============================================================
func _make_label(text: String, min_width: int, font_size: int, color: Color) -> Label:
	var lab = Label.new()
	lab.text = text
	if min_width > 0:
		lab.custom_minimum_size = Vector2(min_width, 0)
	lab.add_theme_font_size_override("font_size", font_size)
	lab.add_theme_color_override("font_color", color)
	return lab

func _make_section_panel(parent: Control, title: String, expand: bool = false) -> VBoxContainer:
	var outer = PanelContainer.new()
	var pstyle = StyleBoxFlat.new()
	pstyle.bg_color = Color(0.10, 0.08, 0.14, 0.9)
	pstyle.set_corner_radius_all(8)
	pstyle.border_width_left = 1
	pstyle.border_width_right = 1
	pstyle.border_width_top = 1
	pstyle.border_width_bottom = 1
	pstyle.border_color = Color(0.4, 0.35, 0.25, 0.6)
	pstyle.content_margin_left = 12
	pstyle.content_margin_right = 12
	pstyle.content_margin_top = 10
	pstyle.content_margin_bottom = 10
	outer.add_theme_stylebox_override("panel", pstyle)
	parent.add_child(outer)

	var vb = VBoxContainer.new()
	vb.name = "SectionBody"
	vb.add_theme_constant_override("separation", 6)
	if expand:
		vb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(vb)

	var title_lbl = Label.new()
	title_lbl.text = title
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 17)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.82, 0.35))
	vb.add_child(title_lbl)

	return vb

# 添加一行：标签 + 数值 + 进度条
func _add_bar_row(parent: VBoxContainer, label: String, cur: int, maxv: int,
					fg: Color, bg: Color):
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var lab = _make_label(label, 60, 15, Color(0.9, 0.9, 0.9))
	row.add_child(lab)

	var val = _make_label("%d / %d" % [cur, maxv], 110, 15, Color(1.0, 1.0, 0.9))
	row.add_child(val)

	# 进度条用 PanelContainer + ColorRect 自定义实现，避免对齐问题
	var bar_outer = Panel.new()
	bar_outer.custom_minimum_size = Vector2(260, 18)
	var bar_style = StyleBoxFlat.new()
	bar_style.bg_color = bg
	bar_style.set_corner_radius_all(3)
	bar_outer.add_theme_stylebox_override("panel", bar_style)
	row.add_child(bar_outer)

	# 内部填充条
	var fill = ColorRect.new()
	var ratio: float = float(cur) / float(max(1, maxv))
	fill.color = fg
	fill.custom_minimum_size = Vector2(int(260 * ratio), 18)
	fill.size = Vector2(int(260 * ratio), 18)
	bar_outer.add_child(fill)

	parent.add_child(row)

func _type_display(t: String) -> String:
	match t:
		"weapon": return "武器"
		"armor": return "护甲"
		"accessory": return "饰品"
		"food": return "食物"
		_: return t

func can_equip_type(t: String) -> bool:
	return t in ["weapon", "armor", "accessory"]

func _get_item_bonus_text(item: Dictionary) -> String:
	var t = item.get("type", "")
	if t == "food":
		return item.get("description", "点击使用")
	var atk = item.get("attack_bonus", 0)
	var def_ = item.get("defense_bonus", 0)
	var hp = item.get("hp_bonus", 0)
	if atk > 0:
		return "+" + str(atk) + " 攻击"
	if def_ > 0:
		return "+" + str(def_) + " 防御"
	if hp > 0:
		return "+" + str(hp) + " 生命"
	return ""

# ============================================================
# 操作：卸下装备 / 从背包装备
# ============================================================
func _on_unequip_clicked(slot_type: String):
	var old_item: Dictionary
	match slot_type:
		"weapon":
			old_item = GameData.weapon.duplicate(true)
			GameData.weapon = GameData.EMPTY_SLOT_DATA.duplicate(true)
			GameData.weapon["icon"] = GameData.DEFAULT_WEAPON_ICON
			GameData.weapon["type"] = "weapon"
		"armor":
			old_item = GameData.armor.duplicate(true)
			GameData.armor = GameData.EMPTY_SLOT_DATA.duplicate(true)
			GameData.armor["icon"] = GameData.DEFAULT_ARMOR_ICON
			GameData.armor["type"] = "armor"
		"accessory":
			old_item = GameData.accessory.duplicate(true)
			GameData.unequip_accessory()
			GameData.accessory["type"] = "accessory"
		_:
			return
	old_item["type"] = slot_type
	GameData.exclusive_backpack.append(old_item)
	_sync_game_data_to_players()
	refresh_ui()

# == 点击专属背包栏图标使用食物/装备 ==
func _on_backpack_icon_clicked(event: InputEvent, item_index: int):
	if not (event is InputEventMouseButton):
		return
	var mb = event as InputEventMouseButton
	if not mb.pressed:
		return
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return

	if item_index < 0 or item_index >= GameData.exclusive_backpack.size():
		return
	var item = GameData.exclusive_backpack[item_index]
	var item_type = item.get("type", "")

	# 食物：弹出确认窗口
	if item_type == "food":
		_show_food_confirm_popup(item, item_index)
		return

	# 装备：使用原有的穿戴逻辑
	equip_from_backpack(item_index)

# == 食物使用确认弹窗 ==
func _show_food_confirm_popup(food_item: Dictionary, item_index: int):
	# 遮罩层
	var overlay = ColorRect.new()
	overlay.name = "FoodConfirmOverlay"
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.size = get_viewport().get_visible_rect().size
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	# 确认面板
	var popup = PanelContainer.new()
	popup.name = "FoodConfirmPopup"
	popup.custom_minimum_size = Vector2(360, 200)
	popup.position = Vector2(
		(get_viewport().get_visible_rect().size.x - 360) / 2,
		(get_viewport().get_visible_rect().size.y - 200) / 2
	)
	var popup_style = StyleBoxFlat.new()
	popup_style.bg_color = Color(0.08, 0.06, 0.12, 0.97)
	popup_style.set_corner_radius_all(12)
	popup_style.border_width_left = 2
	popup_style.border_width_right = 2
	popup_style.border_width_top = 2
	popup_style.border_width_bottom = 2
	popup_style.border_color = Color(0.9, 0.7, 0.3, 0.8)
	popup_style.content_margin_left = 16
	popup_style.content_margin_right = 16
	popup_style.content_margin_top = 14
	popup_style.content_margin_bottom = 14
	popup.add_theme_stylebox_override("panel", popup_style)
	overlay.add_child(popup)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	popup.add_child(vbox)

	# 标题行（图标 + 名字）
	var title_row = HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 10)

	var icon_box = _make_icon_box(food_item.get("icon", ""), 36,
								   Color(0.9, 0.7, 0.3, 0.9),
								   Color(0.12, 0.08, 0.16, 0.9))
	title_row.add_child(icon_box)

	var name_lbl = Label.new()
	name_lbl.text = food_item.get("name", "食物")
	name_lbl.add_theme_font_size_override("font_size", 20)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_row.add_child(name_lbl)

	vbox.add_child(title_row)

	# 效果描述
	var effect_lbl = Label.new()
	effect_lbl.text = "效果： " + food_item.get("description", "点击使用")
	effect_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	effect_lbl.add_theme_font_size_override("font_size", 14)
	effect_lbl.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
	vbox.add_child(effect_lbl)

	# 提示文字
	var tip_lbl = Label.new()
	tip_lbl.text = "确定要使用这个食物吗？"
	tip_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip_lbl.add_theme_font_size_override("font_size", 12)
	tip_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	vbox.add_child(tip_lbl)

	# 按钮行
	var btn_row = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 20)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	# 确认按钮
	var confirm_btn = Button.new()
	confirm_btn.text = "确认使用"
	confirm_btn.custom_minimum_size = Vector2(120, 36)
	confirm_btn.add_theme_font_size_override("font_size", 14)
	confirm_btn.pressed.connect(func():
		overlay.queue_free()
		_do_use_food(food_item, item_index)
	)
	btn_row.add_child(confirm_btn)

	# 取消按钮
	var cancel_btn = Button.new()
	cancel_btn.text = "取消"
	cancel_btn.custom_minimum_size = Vector2(120, 36)
	cancel_btn.add_theme_font_size_override("font_size", 14)
	cancel_btn.pressed.connect(func():
		overlay.queue_free()
	)
	btn_row.add_child(cancel_btn)

	# 按 Z 或 ESC 取消
	overlay.gui_input.connect(func(event: InputEvent):
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_Z or event.keycode == KEY_ESCAPE:
				overlay.queue_free()
	)

# == 实际执行食物使用 ==
func _do_use_food(food_item: Dictionary, item_index: int):
	if item_index < 0 or item_index >= GameData.exclusive_backpack.size():
		return
	var ok = GameData.use_food(food_item)
	if ok:
		GameData.exclusive_backpack.remove_at(item_index)
		_sync_game_data_to_players()
	refresh_ui()

func equip_from_backpack(idx: int):
	if idx < 0 or idx >= GameData.exclusive_backpack.size():
		return
	var item: Dictionary = GameData.exclusive_backpack[idx]
	var itype: String = item.get("type", "")
	if not itype in ["weapon", "armor", "accessory"]:
		return

	# 获取当前装备并收回背包
	var cur: Dictionary = {}
	match itype:
		"weapon": cur = GameData.weapon
		"armor": cur = GameData.armor
		"accessory": cur = GameData.accessory
	if cur.get("name", "") not in ["", "无"]:
		GameData.exclusive_backpack.append(cur.duplicate(true))

	# 装备新物品
	if itype == "accessory":
		GameData.unequip_accessory()
		GameData.equip_accessory(item.duplicate(true))
	else:
		match itype:
			"weapon": GameData.weapon = item.duplicate(true)
			"armor": GameData.armor = item.duplicate(true)

	GameData.exclusive_backpack.remove_at(idx)
	_sync_game_data_to_players()
	refresh_ui()

# ============================================================
# 刷新 / 显示 / 关闭
# ============================================================
func refresh_ui():
	for child in get_children():
		child.queue_free()
	setup_ui()

func show_panel():
	is_visible = true
	refresh_ui()
	show()

func hide_panel():
	is_visible = false
	hide()

func _on_window_resized():
	if is_visible:
		refresh_ui()

func _sync_game_data_to_players():
	if not is_instance_valid(player_ref):
		return
	player_ref.max_hp = GameData.get_total_max_hp()
	player_ref.current_hp = min(GameData.current_hp, GameData.get_total_max_hp())
	player_ref.max_mp = GameData.max_mp
	player_ref.current_mp = GameData.current_mp
	player_ref.attack = GameData.attack
	player_ref.defense = GameData.defense
	player_ref.crit = GameData.crit
	player_ref.base_speed = GameData.base_speed
	player_ref.current_speed = GameData.current_speed