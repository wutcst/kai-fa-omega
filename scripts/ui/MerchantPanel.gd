extends CanvasLayer

# 商人交易界面：
# 左栏：出售装备（仅武器/护甲/饰品可以卖，食物不可出售）
# 右栏：购买道具（红瓶、蓝瓶、食物）

var panel_bg: ColorRect = null
var sell_vbox: VBoxContainer = null
var gold_label: Label = null
var hint_label: Label = null
var close_btn: Button = null
var _close_callback: Callable = Callable()

# 道具配置
const RED_POTION = {
	"name": "血瓶",
	"icon": "res://Asset Bundle/sprites/PotionPack/red_potion.png",
	"price": 30,
	"description": "恢复50点生命值",
	"type": "hp_potion"
}
const BLUE_POTION = {
	"name": "蓝瓶",
	"icon": "res://Asset Bundle/sprites/PotionPack/blue_potion.png",
	"price": 10,
	"description": "恢复30点魔法值",
	"type": "mp_potion"
}
const EQUIP_SELL_PRICE = 20


func _ready():
	_setup_ui()


func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Z or event.keycode == KEY_ESCAPE:
			_on_close_pressed()


func set_close_callback(cb: Callable):
	_close_callback = cb


func _setup_ui():
	# 背景半透明遮罩
	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	# 主面板
	panel_bg = ColorRect.new()
	panel_bg.color = Color(0.10, 0.07, 0.05, 0.97)
	panel_bg.size = Vector2(1050, 650)
	panel_bg.position = Vector2(640 - 525, 360 - 325)
	add_child(panel_bg)

	# 顶部装饰横条
	var top_bar = ColorRect.new()
	top_bar.color = Color(0.6, 0.35, 0.1, 0.8)
	top_bar.size = Vector2(1050, 50)
	top_bar.position = Vector2(0, 0)
	panel_bg.add_child(top_bar)

	# 标题
	var title = Label.new()
	title.text = "商人交易"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	title.position = Vector2(1050 / 2 - 100, 6)
	title.custom_minimum_size = Vector2(200, 0)
	panel_bg.add_child(title)

	# 金币显示（右上角）
	gold_label = Label.new()
	gold_label.text = "金币: " + str(GameData.gold)
	gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	gold_label.add_theme_font_size_override("font_size", 16)
	gold_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	gold_label.position = Vector2(1050 - 210, 10)
	gold_label.custom_minimum_size = Vector2(190, 0)
	panel_bg.add_child(gold_label)

	# 顶部装饰线
	var top_line = ColorRect.new()
	top_line.color = Color(0.9, 0.7, 0.2, 0.5)
	top_line.size = Vector2(1050, 1)
	top_line.position = Vector2(0, 50)
	panel_bg.add_child(top_line)

	# 左右分栏的装饰竖线
	var vline = ColorRect.new()
	vline.color = Color(0.75, 0.55, 0.2, 0.5)
	vline.size = Vector2(2, 490)
	vline.position = Vector2(525, 62)
	panel_bg.add_child(vline)

	# ====== 左栏：出售装备 ======
	var sell_header = PanelContainer.new()
	sell_header.position = Vector2(18, 62)
	sell_header.custom_minimum_size = Vector2(490, 28)
	var sell_header_style = StyleBoxFlat.new()
	sell_header_style.bg_color = Color(0.3, 0.15, 0.08, 0.8)
	sell_header_style.set_corner_radius_all(4)
	sell_header_style.border_width_left = 1
	sell_header_style.border_width_right = 1
	sell_header_style.border_width_top = 1
	sell_header_style.border_width_bottom = 1
	sell_header_style.border_color = Color(0.6, 0.4, 0.2, 0.5)
	sell_header.add_theme_stylebox_override("panel", sell_header_style)
	var sell_title = Label.new()
	sell_title.text = "出售装备 (每件 +" + str(EQUIP_SELL_PRICE) + " 金币)"
	sell_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sell_title.add_theme_font_size_override("font_size", 14)
	sell_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.6))
	sell_header.add_child(sell_title)
	panel_bg.add_child(sell_header)

	var sell_scroll = ScrollContainer.new()
	sell_scroll.size = Vector2(490, 450)
	sell_scroll.position = Vector2(18, 96)
	panel_bg.add_child(sell_scroll)

	sell_vbox = VBoxContainer.new()
	sell_vbox.name = "SellList"
	sell_vbox.add_theme_constant_override("separation", 5)
	sell_scroll.add_child(sell_vbox)

	_refresh_sell_list()

	# ====== 右栏：购买道具 ======
	var buy_header = PanelContainer.new()
	buy_header.position = Vector2(542, 62)
	buy_header.custom_minimum_size = Vector2(490, 28)
	var buy_header_style = StyleBoxFlat.new()
	buy_header_style.bg_color = Color(0.15, 0.2, 0.3, 0.8)
	buy_header_style.set_corner_radius_all(4)
	buy_header_style.border_width_left = 1
	buy_header_style.border_width_right = 1
	buy_header_style.border_width_top = 1
	buy_header_style.border_width_bottom = 1
	buy_header_style.border_color = Color(0.3, 0.5, 0.7, 0.5)
	buy_header.add_theme_stylebox_override("panel", buy_header_style)
	var buy_title = Label.new()
	buy_title.text = "购买道具"
	buy_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	buy_title.add_theme_font_size_override("font_size", 14)
	buy_title.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	buy_header.add_child(buy_title)
	panel_bg.add_child(buy_header)

	var buy_scroll = ScrollContainer.new()
	buy_scroll.size = Vector2(490, 450)
	buy_scroll.position = Vector2(542, 96)
	panel_bg.add_child(buy_scroll)

	var buy_vbox = VBoxContainer.new()
	buy_vbox.name = "BuyList"
	buy_vbox.add_theme_constant_override("separation", 5)
	buy_scroll.add_child(buy_vbox)

	# 药水分类标题
	var potion_hdr = _make_section_label("药水补给")
	buy_vbox.add_child(potion_hdr)
	buy_vbox.add_child(_create_buy_row(RED_POTION))
	buy_vbox.add_child(_create_buy_row(BLUE_POTION))

	# 食物分类标题
	var food_hdr = _make_section_label("食物")
	buy_vbox.add_child(food_hdr)
	for food in GameData.FOOD_TABLE:
		var food_item = food.duplicate()
		food_item["type"] = GameData.FOOD_TYPE
		buy_vbox.add_child(_create_food_buy_row(food_item))

	# 底部信息栏
	var bottom_bar = ColorRect.new()
	bottom_bar.color = Color(0.15, 0.1, 0.05, 0.9)
	bottom_bar.size = Vector2(1050, 40)
	bottom_bar.position = Vector2(0, 610)
	panel_bg.add_child(bottom_bar)

	# 提示信息
	hint_label = Label.new()
	hint_label.text = ""
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_size_override("font_size", 13)
	hint_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
	hint_label.position = Vector2(20, 615)
	hint_label.custom_minimum_size = Vector2(890, 28)
	panel_bg.add_child(hint_label)

	# 关闭按钮
	close_btn = Button.new()
	close_btn.text = "关闭 (Z/ESC)"
	close_btn.custom_minimum_size = Vector2(110, 32)
	close_btn.position = Vector2(1050 - 120, 613)
	close_btn.add_theme_font_size_override("font_size", 13)
	close_btn.pressed.connect(_on_close_pressed)
	panel_bg.add_child(close_btn)


func _make_section_label(text: String) -> Label:
	var lab = Label.new()
	lab.text = "  " + text
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	lab.add_theme_font_size_override("font_size", 13)
	lab.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
	lab.custom_minimum_size = Vector2(480, 22)
	return lab


# —— 刷新出售列表（只显示装备，不显示食物）——
func _refresh_sell_list():
	for child in sell_vbox.get_children():
		child.queue_free()

	# 只挑出 type 为 weapon/armor/accessory 的条目
	var equip_items: Array = []
	for i in range(GameData.exclusive_backpack.size()):
		var item = GameData.exclusive_backpack[i]
		var t = item.get("type", "")
		if t == "weapon" or t == "armor" or t == "accessory":
			equip_items.append({"idx": i, "item": item})

	if equip_items.size() == 0:
		var empty = Label.new()
		empty.text = "（没有可出售的装备）"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_font_size_override("font_size", 14)
		empty.add_theme_color_override("font_color", Color(0.7, 0.6, 0.5))
		empty.custom_minimum_size = Vector2(480, 40)
		sell_vbox.add_child(empty)
		return

	for entry in equip_items:
		var row = _create_equip_sell_row(entry.item, entry.idx)
		sell_vbox.add_child(row)


# 装备出售条目
func _create_equip_sell_row(item: Dictionary, idx: int) -> PanelContainer:
	var panel = PanelContainer.new()
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.22, 0.16, 0.11, 0.9)
	panel_style.set_corner_radius_all(4)
	panel_style.border_width_left = 1
	panel_style.border_width_right = 1
	panel_style.border_width_top = 1
	panel_style.border_width_bottom = 1
	panel_style.border_color = Color(0.6, 0.45, 0.25)
	panel.add_theme_stylebox_override("panel", panel_style)

	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)

	var icon_rect = TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(40, 40)
	icon_rect.size = Vector2(40, 40)
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var icon_path = item.get("icon", "")
	if icon_path != "":
		var tex = load(icon_path)
		if tex:
			icon_rect.texture = tex
	row.add_child(icon_rect)

	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_lbl = Label.new()
	name_lbl.text = item.get("name", "装备")
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	info_vbox.add_child(name_lbl)
	var desc_lbl = Label.new()
	desc_lbl.text = item.get("description", "")
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.add_theme_color_override("font_color", Color(0.85, 0.75, 0.55))
	info_vbox.add_child(desc_lbl)
	row.add_child(info_vbox)

	var sell_btn = Button.new()
	sell_btn.text = "出售+" + str(EQUIP_SELL_PRICE) + "金"
	sell_btn.custom_minimum_size = Vector2(100, 34)
	sell_btn.add_theme_font_size_override("font_size", 12)
	sell_btn.pressed.connect(_on_sell_equip.bind(idx))
	row.add_child(sell_btn)

	return panel


# 购买条目（红瓶/蓝瓶）
func _create_buy_row(potion: Dictionary) -> PanelContainer:
	var panel = PanelContainer.new()
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.15, 0.18, 0.22, 0.9)
	panel_style.set_corner_radius_all(4)
	panel_style.border_width_left = 1
	panel_style.border_width_right = 1
	panel_style.border_width_top = 1
	panel_style.border_width_bottom = 1
	panel_style.border_color = Color(0.35, 0.5, 0.65)
	panel.add_theme_stylebox_override("panel", panel_style)

	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)

	var icon_rect = TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(40, 40)
	icon_rect.size = Vector2(40, 40)
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var tex = load(potion.icon)
	if tex:
		icon_rect.texture = tex
	row.add_child(icon_rect)

	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_lbl = Label.new()
	name_lbl.text = potion.name
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", Color(0.9, 1.0, 0.9))
	info_vbox.add_child(name_lbl)
	var desc_lbl = Label.new()
	desc_lbl.text = potion.description
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.add_theme_color_override("font_color", Color(0.75, 0.85, 0.75))
	info_vbox.add_child(desc_lbl)
	row.add_child(info_vbox)

	var buy_btn = Button.new()
	buy_btn.text = str(potion.price) + "金购买"
	buy_btn.custom_minimum_size = Vector2(100, 34)
	buy_btn.add_theme_font_size_override("font_size", 12)
	buy_btn.pressed.connect(_on_buy_potion.bind(potion))
	row.add_child(buy_btn)

	return panel


# 购买条目（食物）
func _create_food_buy_row(food: Dictionary) -> PanelContainer:
	var panel = PanelContainer.new()
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.25, 0.18, 0.10, 0.9)
	panel_style.set_corner_radius_all(4)
	panel_style.border_width_left = 1
	panel_style.border_width_right = 1
	panel_style.border_width_top = 1
	panel_style.border_width_bottom = 1
	panel_style.border_color = Color(0.75, 0.55, 0.25)
	panel.add_theme_stylebox_override("panel", panel_style)

	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)

	var icon_rect = TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(40, 40)
	icon_rect.size = Vector2(40, 40)
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var icon_path = food.get("icon", "")
	if icon_path != "":
		var tex = load(icon_path)
		if tex:
			icon_rect.texture = tex
	row.add_child(icon_rect)

	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_lbl = Label.new()
	name_lbl.text = food.get("name", "食物")
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
	info_vbox.add_child(name_lbl)
	var desc_lbl = Label.new()
	desc_lbl.text = food.get("description", "")
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.add_theme_color_override("font_color", Color(0.85, 0.7, 0.45))
	info_vbox.add_child(desc_lbl)
	row.add_child(info_vbox)

	var buy_btn = Button.new()
	buy_btn.text = str(food.get("price", 0)) + "金购买"
	buy_btn.custom_minimum_size = Vector2(100, 34)
	buy_btn.add_theme_font_size_override("font_size", 12)
	buy_btn.pressed.connect(_on_buy_food.bind(food))
	row.add_child(buy_btn)

	return panel


# —— 出售装备 ——
func _on_sell_equip(idx: int):
	if idx < 0 or idx >= GameData.exclusive_backpack.size():
		return
	var item = GameData.exclusive_backpack[idx]
	var t = item.get("type", "")
	if t != "weapon" and t != "armor" and t != "accessory":
		return
	GameData.exclusive_backpack.remove_at(idx)
	GameData.gold += EQUIP_SELL_PRICE
	_show_hint("出售了 " + item.get("name", "装备") + "，获得 " + str(EQUIP_SELL_PRICE) + " 金币")
	_refresh_gold_label()
	_refresh_sell_list()


# —— 购买红瓶/蓝瓶（加入 inventory_items 道具栏）——
func _on_buy_potion(potion: Dictionary):
	if GameData.gold < potion.price:
		_show_hint("金币不足，需要 " + str(potion.price) + " 金币")
		return
	GameData.gold -= potion.price
	# 加入 inventory_items（道具栏）
	var found = false
	for i in range(GameData.inventory_items.size()):
		if GameData.inventory_items[i].get("name", "") == potion.name:
			GameData.inventory_items[i]["quantity"] = (
				GameData.inventory_items[i].get("quantity", 0) + 1
			)
			found = true
			break
	if not found:
		var new_potion = {
			"name": potion.name,
			"quantity": 1,
			"icon": potion.icon,
			"description": potion.description,
			"type": "potion"
		}
		if potion.name == "血瓶":
			new_potion["heal"] = 50
		elif potion.name == "蓝瓶":
			new_potion["mana"] = 30
		GameData.inventory_items.append(new_potion)
	_show_hint("购买了 " + potion.name)
	_refresh_gold_label()


# —— 购买食物（加入 exclusive_backpack 专属背包栏）——
func _on_buy_food(food: Dictionary):
	var price: int = food.get("price", 0)
	if GameData.gold < price:
		_show_hint("金币不足，需要 " + str(price) + " 金币")
		return
	GameData.gold -= price
	var new_food = food.duplicate()
	new_food["type"] = GameData.FOOD_TYPE
	GameData.exclusive_backpack.append(new_food)
	_show_hint("购买了 " + food.get("name", "食物") + "，已放入专属背包栏")
	_refresh_gold_label()


func _refresh_gold_label():
	if is_instance_valid(gold_label):
		gold_label.text = "金币: " + str(GameData.gold)


func _show_hint(msg: String):
	if is_instance_valid(hint_label):
		hint_label.text = msg


func _on_close_pressed():
	if _close_callback.is_valid():
		_close_callback.call()
	queue_free()
