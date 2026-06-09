extends CanvasLayer

var panel_bg: ColorRect
var main_container: VBoxContainer
var title_label: Label
var content_container: HBoxContainer
var left_column: VBoxContainer
var right_column: VBoxContainer
var bottom_section: VBoxContainer
var close_hint: Label

var is_visible: bool = false

func _ready():
	setup_ui()
	hide_panel()

func setup_ui():
	# 半透明遮罩背景
	panel_bg = ColorRect.new()
	panel_bg.name = "PanelBg"
	panel_bg.color = Color(0, 0, 0, 0.6)
	panel_bg.size = get_viewport().get_visible_rect().size
	panel_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel_bg)

	# 主面板容器
	var panel = Panel.new()
	panel.name = "MainPanel"
	panel.custom_minimum_size = Vector2(700, 520)
	panel.size = Vector2(700, 520)
	panel.position = Vector2(
		(get_viewport().get_visible_rect().size.x - 700) / 2,
		(get_viewport().get_visible_rect().size.y - 520) / 2
	)
	
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.1, 0.18, 0.95)
	panel_style.set_corner_radius_all(12)
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.6, 0.5, 0.3, 0.8)
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)

	# 主垂直布局
	main_container = VBoxContainer.new()
	main_container.name = "MainContainer"
	main_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_container.add_theme_constant_override("separation", 8)
	panel.add_child(main_container)

	# 标题栏
	var title_bar = HBoxContainer.new()
	title_bar.name = "TitleBar"
	
	title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = "⚔ 物品栏 / 人物信息 ⚔"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.add_theme_color_override("font_color", Color(0.98, 0.85, 0.4))
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	title_bar.add_child(title_label)
	main_container.add_child(title_bar)

	# 分隔线
	var sep1 = HSeparator.new()
	main_container.add_child(sep1)

	# 中间内容区（左右分栏）
	content_container = HBoxContainer.new()
	content_container.name = "ContentContainer"
	content_container.add_theme_constant_override("separation", 16)
	content_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_container.add_child(content_container)

	# 左侧：属性 + 装备
	left_column = VBoxContainer.new()
	left_column.name = "LeftColumn"
	left_column.add_theme_constant_override("separation", 10)
	left_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_container.add_child(left_column)

	# 右侧：道具栏
	right_column = VBoxContainer.new()
	right_column.name = "RightColumn"
	right_column.add_theme_constant_override("separation", 6)
	right_column.custom_minimum_size = Vector2(320, 0)
	content_container.add_child(right_column)

	# 构建各区域
	build_attributes_section()
	build_equipment_section()
	build_items_section()

	# 分隔线
	var sep2 = HSeparator.new()
	main_container.add_child(sep2)

	# 底部提示
	close_hint = Label.new()
	close_hint.name = "CloseHint"
	close_hint.text = "按 Q 键关闭"
	close_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	close_hint.add_theme_font_size_override("font_size", 14)
	close_hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	main_container.add_child(close_hint)

	if not get_tree().root.size_changed.is_connected(_on_window_resized):
		get_tree().root.size_changed.connect(_on_window_resized)

# == 人物属性区域 ==
func build_attributes_section():
	var attr_section = VBoxContainer.new()
	attr_section.name = "AttributesSection"
	attr_section.add_theme_constant_override("separation", 4)

	var attr_title = Label.new()
	attr_title.text = "━━━ 人物属性 ━━━"
	attr_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	attr_title.add_theme_font_size_override("font_size", 18)
	attr_title.add_theme_color_override("font_color", Color(0.9, 0.75, 0.25))
	attr_section.add_child(attr_title)

	# 属性列表容器
	var attr_grid = VBoxContainer.new()
	attr_grid.name = "AttrGrid"
	attr_grid.add_theme_constant_override("separation", 6)

	# HP条
	var hp_row = HBoxContainer.new()
	var hp_label = Label.new()
	hp_label.text = "血量"
	hp_label.custom_minimum_size = Vector2(80, 0)
	hp_label.add_theme_font_size_override("font_size", 15)
	hp_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	hp_row.add_child(hp_label)

	# HP数值
	var hp_value = Label.new()
	hp_value.name = "HPValue"
	hp_value.text = "%d / %d" % [GameData.current_hp, GameData.max_hp]
	hp_value.add_theme_font_size_override("font_size", 15)
	hp_value.add_theme_color_override("font_color", Color(0.95, 0.3, 0.3))
	hp_row.add_child(hp_value)

	# HP进度条
	var hp_bar_bg = ColorRect.new()
	hp_bar_bg.name = "HPBarBg"
	hp_bar_bg.size = Vector2(160, 16)
	hp_bar_bg.color = Color(0.15, 0.15, 0.15)
	hp_row.add_child(hp_bar_bg)

	var hp_bar_fill = ColorRect.new()
	hp_bar_fill.name = "HPBarFill"
	hp_bar_fill.size = Vector2(160 * GameData.current_hp / max(1, GameData.max_hp), 16)
	hp_bar_fill.color = Color(0.9, 0.15, 0.15)
	hp_bar_bg.add_child(hp_bar_fill)

	attr_grid.add_child(hp_row)

	# MP条
	var mp_row = HBoxContainer.new()
	var mp_label = Label.new()
	mp_label.text = "蓝量"
	mp_label.custom_minimum_size = Vector2(80, 0)
	mp_label.add_theme_font_size_override("font_size", 15)
	mp_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	mp_row.add_child(mp_label)

	var mp_value = Label.new()
	mp_value.name = "MPValue"
	mp_value.text = "%d / %d" % [GameData.current_mp, GameData.max_mp]
	mp_value.add_theme_font_size_override("font_size", 15)
	mp_value.add_theme_color_override("font_color", Color(0.25, 0.55, 0.95))
	mp_row.add_child(mp_value)

	var mp_bar_bg = ColorRect.new()
	mp_bar_bg.name = "MPBarBg"
	mp_bar_bg.size = Vector2(160, 16)
	mp_bar_bg.color = Color(0.15, 0.15, 0.15)
	mp_row.add_child(mp_bar_bg)

	var mp_bar_fill = ColorRect.new()
	mp_bar_fill.name = "MPBarFill"
	mp_bar_fill.size = Vector2(160 * GameData.current_mp / max(1, GameData.max_mp), 16)
	mp_bar_fill.color = Color(0.2, 0.5, 0.9)
	mp_bar_bg.add_child(mp_bar_fill)

	attr_grid.add_child(mp_row)

	# 其他属性行
	var other_attrs = [
		{"label": "攻击", "value": str(GameData.attack), "color": Color(0.95, 0.5, 0.2)},
		{"label": "防御", "value": str(GameData.defense), "color": Color(0.3, 0.75, 0.4)},
		{"label": "速度", "value": str(GameData.current_speed), "color": Color(0.3, 0.8, 0.85)},
		{"label": "暴击", "value": str(GameData.crit) + "%", "color": Color(0.95, 0.85, 0.2)},
	]

	for attr in other_attrs:
		var row = HBoxContainer.new()
		var lbl = Label.new()
		lbl.text = attr.label
		lbl.custom_minimum_size = Vector2(80, 0)
		lbl.add_theme_font_size_override("font_size", 15)
		lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
		row.add_child(lbl)

		var val = Label.new()
		val.text = attr.value
		val.add_theme_font_size_override("font_size", 15)
		val.add_theme_color_override("font_color", attr.color)
		row.add_child(val)
		attr_grid.add_child(row)

	# 职业行
	var job_row = HBoxContainer.new()
	var job_lbl = Label.new()
	job_lbl.text = "职业"
	job_lbl.custom_minimum_size = Vector2(80, 0)
	job_lbl.add_theme_font_size_override("font_size", 15)
	job_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	job_row.add_child(job_lbl)

	var job_val = Label.new()
	job_val.name = "JobValue"
	job_val.text = get_job_display_name()
	job_val.add_theme_font_size_override("font_size", 15)
	job_val.add_theme_color_override("font_color", Color(0.98, 0.85, 0.4))
	job_row.add_child(job_val)
	attr_grid.add_child(job_row)

	attr_section.add_child(attr_grid)
	left_column.add_child(attr_section)

# == 装备栏区域 ==
func build_equipment_section():
	var equip_section = VBoxContainer.new()
	equip_section.name = "EquipmentSection"
	equip_section.add_theme_constant_override("separation", 6)

	var equip_title = Label.new()
	equip_title.text = "━━━ 装备栏 ━━━"
	equip_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	equip_title.add_theme_font_size_override("font_size", 18)
	equip_title.add_theme_color_override("font_color", Color(0.9, 0.75, 0.25))
	equip_section.add_child(equip_title)

	# 3个装备槽
	var equip_slots = [
		{"label": "武器", "data": GameData.weapon, "slot_name": "WeaponSlot"},
		{"label": "护甲", "data": GameData.armor, "slot_name": "ArmorSlot"},
		{"label": "饰品", "data": GameData.accessory, "slot_name": "AccessorySlot"},
	]

	for slot in equip_slots:
		var slot_container = HBoxContainer.new()
		slot_container.name = slot.slot_name
		slot_container.add_theme_constant_override("separation", 8)

		# 槽位标签
		var slot_label = Label.new()
		slot_label.text = slot.label + ":"
		slot_label.custom_minimum_size = Vector2(60, 0)
		slot_label.add_theme_font_size_override("font_size", 15)
		slot_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		slot_container.add_child(slot_label)

		# 装备名称（带背景框）
		var equip_panel = Panel.new()
		equip_panel.custom_minimum_size = Vector2(200, 30)
		var equip_style = StyleBoxFlat.new()
		equip_style.bg_color = Color(0.18, 0.15, 0.22, 0.9)
		equip_style.set_corner_radius_all(4)
		equip_style.border_width_left = 1
		equip_style.border_width_right = 1
		equip_style.border_width_top = 1
		equip_style.border_width_bottom = 1
		equip_style.border_color = Color(0.4, 0.35, 0.25, 0.6)
		equip_panel.add_theme_stylebox_override("panel", equip_style)
		slot_container.add_child(equip_panel)

		var equip_name_label = Label.new()
		equip_name_label.name = "NameLabel"
		equip_name_label.text = slot.data.get("name", "无")
		equip_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		equip_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		equip_name_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		equip_name_label.add_theme_font_size_override("font_size", 14)
		equip_name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
		equip_panel.add_child(equip_name_label)

		# 装备加成提示
		var bonus_text = get_equip_bonus_text(slot.label, slot.data)
		var bonus_label = Label.new()
		bonus_label.text = bonus_text
		bonus_label.add_theme_font_size_override("font_size", 12)
		bonus_label.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
		slot_container.add_child(bonus_label)

		equip_section.add_child(slot_container)

	left_column.add_child(equip_section)

func get_equip_bonus_text(slot_type: String, data: Dictionary) -> String:
	match slot_type:
		"武器":
			return "+" + str(data.get("attack_bonus", 0)) + " 攻击"
		"护甲":
			return "+" + str(data.get("defense_bonus", 0)) + " 防御"
		"饰品":
			var hp_bonus = data.get("hp_bonus", 0)
			if hp_bonus > 0:
				return "+" + str(hp_bonus) + " 生命"
			return ""
		_:
			return ""

# == 道具栏区域 ==
func build_items_section():
	var items_section = VBoxContainer.new()
	items_section.name = "ItemsSection"
	items_section.add_theme_constant_override("separation", 4)

	var items_title = Label.new()
	items_title.text = "━━━ 道具栏 ━━━"
	items_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	items_title.add_theme_font_size_override("font_size", 18)
	items_title.add_theme_color_override("font_color", Color(0.9, 0.75, 0.25))
	items_section.add_child(items_title)

	# 道具列表容器
	var items_container = VBoxContainer.new()
	items_container.name = "ItemsContainer"
	items_container.add_theme_constant_override("separation", 4)
	items_container.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# 道具列表背景
	var items_bg = Panel.new()
	items_bg.custom_minimum_size = Vector2(300, 280)
	items_bg.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var items_bg_style = StyleBoxFlat.new()
	items_bg_style.bg_color = Color(0.08, 0.06, 0.12, 0.8)
	items_bg_style.set_corner_radius_all(8)
	items_bg_style.border_width_left = 1
	items_bg_style.border_width_right = 1
	items_bg_style.border_width_top = 1
	items_bg_style.border_width_bottom = 1
	items_bg_style.border_color = Color(0.35, 0.3, 0.2, 0.5)
	items_bg.add_theme_stylebox_override("panel", items_bg_style)
	items_section.add_child(items_bg)

	var items_inner = VBoxContainer.new()
	items_inner.name = "ItemsInner"
	items_inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	items_inner.add_theme_constant_override("separation", 2)
	items_bg.add_child(items_inner)

	# 渲染每个道具
	for item in GameData.inventory_items:
		var item_row = HBoxContainer.new()
		item_row.add_theme_constant_override("separation", 8)

		var item_icon = ColorRect.new()
		item_icon.custom_minimum_size = Vector2(32, 32)
		item_icon.color = Color(0.25, 0.2, 0.35)
		item_row.add_child(item_icon)

		var item_name = Label.new()
		item_name.text = item.get("name", "???")
		item_name.custom_minimum_size = Vector2(130, 0)
		item_name.add_theme_font_size_override("font_size", 14)
		item_name.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
		item_row.add_child(item_name)

		var item_qty = Label.new()
		item_qty.text = "x" + str(item.get("quantity", 0))
		item_qty.add_theme_font_size_override("font_size", 14)
		item_qty.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		item_row.add_child(item_qty)

		var item_desc = Label.new()
		item_desc.text = item.get("description", "")
		item_desc.add_theme_font_size_override("font_size", 11)
		item_desc.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		item_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item_row.add_child(item_desc)

		items_inner.add_child(item_row)

	# 如果没有道具，显示空提示
	if GameData.inventory_items.is_empty():
		var empty_label = Label.new()
		empty_label.text = "（道具栏为空）"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_font_size_override("font_size", 14)
		empty_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
		empty_label.set_anchors_preset(Control.PRESET_CENTER)
		items_bg.add_child(empty_label)

	right_column.add_child(items_section)

func get_job_display_name() -> String:
	match GameData.current_job:
		GameData.Job.SWORDSMAN: return "剑士"
		GameData.Job.RANGER: return "游侠"
		GameData.Job.SHIELD_KNIGHT: return "盾骑士"
		_: return "剑士"

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
	if panel_bg:
		panel_bg.size = get_viewport().get_visible_rect().size