extends CanvasLayer

# 旅馆休息界面：
# 支付金币恢复全部 HP 和 MP

var panel_bg: ColorRect = null
var gold_label: Label = null
var stats_label: Label = null
var hint_label: Label = null
var rest_btn: Button = null
var _close_callback: Callable = Callable()
var _hp_fill: ColorRect = null
var _mp_fill: ColorRect = null

const REST_PRICE: int = 25


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
	panel_bg.color = Color(0.08, 0.06, 0.14, 0.97)
	panel_bg.size = Vector2(480, 360)
	panel_bg.position = Vector2(640 - 240, 360 - 180)
	add_child(panel_bg)

	# 顶部横条
	var top_bar = ColorRect.new()
	top_bar.color = Color(0.25, 0.18, 0.35, 0.9)
	top_bar.size = Vector2(480, 48)
	panel_bg.add_child(top_bar)

	# 标题
	var title = Label.new()
	title.text = "旅馆 · 休息"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.9, 0.8, 1.0))
	title.position = Vector2(0, 8)
	title.custom_minimum_size = Vector2(480, 0)
	panel_bg.add_child(title)

	# 顶部装饰线
	var top_line = ColorRect.new()
	top_line.color = Color(0.7, 0.5, 0.9, 0.5)
	top_line.size = Vector2(480, 1)
	top_line.position = Vector2(0, 48)
	panel_bg.add_child(top_line)

	# 金币显示
	gold_label = Label.new()
	gold_label.text = "当前金币: " + str(GameData.gold)
	gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	gold_label.add_theme_font_size_override("font_size", 16)
	gold_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	gold_label.position = Vector2(280, 58)
	gold_label.custom_minimum_size = Vector2(180, 0)
	panel_bg.add_child(gold_label)

	# 玩家状态显示
	stats_label = Label.new()
	stats_label.text = _make_stats_text()
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.add_theme_font_size_override("font_size", 15)
	stats_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	stats_label.position = Vector2(0, 130)
	stats_label.custom_minimum_size = Vector2(480, 0)
	panel_bg.add_child(stats_label)

	# HP/MP 进度条背景
	var hp_bar_bg = ColorRect.new()
	hp_bar_bg.color = Color(0.2, 0.1, 0.1, 0.8)
	hp_bar_bg.size = Vector2(300, 18)
	hp_bar_bg.position = Vector2(90, 160)
	panel_bg.add_child(hp_bar_bg)

	var hp_ratio: float = float(GameData.current_hp) / max(GameData.get_total_max_hp(), 1)
	_hp_fill = ColorRect.new()
	_hp_fill.color = Color(0.8, 0.2, 0.2, 0.9)
	_hp_fill.size = Vector2(300 * hp_ratio, 18)
	_hp_fill.position = Vector2(90, 160)
	panel_bg.add_child(_hp_fill)

	var mp_bar_bg = ColorRect.new()
	mp_bar_bg.color = Color(0.1, 0.1, 0.2, 0.8)
	mp_bar_bg.size = Vector2(300, 18)
	mp_bar_bg.position = Vector2(90, 184)
	panel_bg.add_child(mp_bar_bg)

	var mp_ratio: float = float(GameData.current_mp) / max(GameData.max_mp, 1)
	_mp_fill = ColorRect.new()
	_mp_fill.color = Color(0.2, 0.3, 0.8, 0.9)
	_mp_fill.size = Vector2(300 * mp_ratio, 18)
	_mp_fill.position = Vector2(90, 184)
	panel_bg.add_child(_mp_fill)

	# HP/MP 标签
	var hp_label = Label.new()
	hp_label.text = "HP"
	hp_label.add_theme_font_size_override("font_size", 13)
	hp_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
	hp_label.position = Vector2(55, 160)
	hp_label.custom_minimum_size = Vector2(30, 18)
	panel_bg.add_child(hp_label)

	var mp_label = Label.new()
	mp_label.text = "MP"
	mp_label.add_theme_font_size_override("font_size", 13)
	mp_label.add_theme_color_override("font_color", Color(0.5, 0.5, 1.0))
	mp_label.position = Vector2(55, 184)
	mp_label.custom_minimum_size = Vector2(30, 18)
	panel_bg.add_child(mp_label)

	# 休息按钮
	rest_btn = Button.new()
	rest_btn.text = "休息恢复全部状态 - " + str(REST_PRICE) + " 金币"
	rest_btn.custom_minimum_size = Vector2(320, 48)
	rest_btn.position = Vector2(80, 220)
	rest_btn.add_theme_font_size_override("font_size", 15)
	rest_btn.pressed.connect(_on_rest_pressed)
	panel_bg.add_child(rest_btn)

	# 描述文字
	var desc = Label.new()
	desc.text = "好好睡一觉，恢复所有生命值和魔法值"
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))
	desc.position = Vector2(0, 275)
	desc.custom_minimum_size = Vector2(480, 0)
	panel_bg.add_child(desc)

	# 提示信息
	hint_label = Label.new()
	hint_label.text = ""
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_size_override("font_size", 13)
	hint_label.add_theme_color_override("font_color", Color(0.7, 1.0, 0.7))
	hint_label.position = Vector2(0, 295)
	hint_label.custom_minimum_size = Vector2(480, 0)
	panel_bg.add_child(hint_label)

	# 关闭按钮
	var close_btn = Button.new()
	close_btn.text = "离开 (Z/ESC)"
	close_btn.custom_minimum_size = Vector2(130, 32)
	close_btn.position = Vector2(175, 322)
	close_btn.add_theme_font_size_override("font_size", 13)
	close_btn.pressed.connect(_on_close_pressed)
	panel_bg.add_child(close_btn)


func _make_stats_text() -> String:
	return (
		"HP: "
		+ str(GameData.current_hp)
		+ "/"
		+ str(GameData.get_total_max_hp())
		+ "    MP: "
		+ str(GameData.current_mp)
		+ "/"
		+ str(GameData.max_mp)
	)


func _on_rest_pressed():
	if (
		GameData.current_hp == GameData.get_total_max_hp()
		and GameData.current_mp == GameData.max_mp
	):
		if hint_label:
			hint_label.text = "状态已满，无需休息"
		return
	if GameData.gold < REST_PRICE:
		if hint_label:
			hint_label.text = "金币不足！需要 " + str(REST_PRICE) + " 金币"
		return
	GameData.gold -= REST_PRICE
	GameData.current_hp = GameData.get_total_max_hp()
	GameData.current_mp = GameData.max_mp
	_sync_player_stats()
	_refresh_ui()
	if hint_label:
		hint_label.text = "休息完毕！HP 和 MP 已完全恢复～"


func _refresh_ui():
	if is_instance_valid(gold_label):
		gold_label.text = "当前金币: " + str(GameData.gold)
	if is_instance_valid(stats_label):
		stats_label.text = _make_stats_text()
	if is_instance_valid(_hp_fill):
		var hp_ratio: float = float(GameData.current_hp) / max(GameData.get_total_max_hp(), 1)
		_hp_fill.size.x = 300 * hp_ratio
	if is_instance_valid(_mp_fill):
		var mp_ratio: float = float(GameData.current_mp) / max(GameData.max_mp, 1)
		_mp_fill.size.x = 300 * mp_ratio


func _sync_player_stats():
	var players = get_tree().get_nodes_in_group("player")
	for p in players:
		if is_instance_valid(p) and p.has_method("load_data_from_global"):
			p.load_data_from_global()
			break


func _on_close_pressed():
	if _close_callback.is_valid():
		_close_callback.call()
	queue_free()
