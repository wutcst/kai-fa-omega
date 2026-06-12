extends Node2D

@onready var combat_ui: CombatUI = $CombatUI

# 战斗中引用的节点
@onready var player_team: Node2D = $PlayerTeam
@onready var enemy_team: Node2D = $EnemyTeam
@onready var player_battler: Node2D = get_node("PlayerTeam/Player-Battler")
@onready var monster_battler: Node2D = get_node("EnemyTeam/Monster-Battler")

# 记录初始位置（用于震动后复位）
var _player_origin: Vector2 = Vector2.ZERO
var _monster_origin: Vector2 = Vector2.ZERO
var _camera_origin: Vector2 = Vector2.ZERO

# 动态创建的特效容器
var _fx_layer: Node2D = null

func _ready():
	combat_ui.skill1_pressed.connect(_on_skill1)
	combat_ui.skill2_pressed.connect(_on_skill2)
	combat_ui.skill3_pressed.connect(_on_skill3)
	combat_ui.skill4_pressed.connect(_on_skill4)
	combat_ui.escape_pressed.connect(_on_player_escape)
	combat_ui.heal_pressed.connect(_on_use_heal_potion)
	combat_ui.mana_pressed.connect(_on_use_mana_potion)

	_update_skill_buttons()
	combat_ui.refresh_skill_locks()
	combat_ui.update_exp_bar()

	# 保存初始位置，便于震动后复位
	if is_instance_valid(player_battler):
		_player_origin = player_battler.position
	if is_instance_valid(monster_battler):
		_monster_origin = monster_battler.position
	_camera_origin = Vector2.ZERO

	# 创建特效层
	_fx_layer = Node2D.new()
	_fx_layer.name = "FXLayer"
	add_child(_fx_layer)

	# 战斗开始时同步玩家当前等级属性到血条UI
	_sync_player_battler_stats()

func _sync_player_battler_stats():
	if not is_instance_valid(player_battler):
		return
	# 强制刷新血条，确保显示升级后的最大生命值
	if player_battler.has_method("set_current_hp"):
		var current_hp = player_battler.call("get_current_hp")
		player_battler.call("set_current_hp", current_hp)
	if player_battler.has_method("set_current_mp"):
		var current_mp = player_battler.call("get_current_mp")
		player_battler.call("set_current_mp", current_mp)

func _update_skill_buttons():
	combat_ui.btn_skill1.text = "斩击"
	combat_ui.btn_skill2.text = "重斩(15MP)"
	combat_ui.btn_skill3.text = "破甲斩(20MP)"
	combat_ui.btn_skill4.text = "怒斩苍穹(30MP)"

func _on_skill1():
	print("→ 玩家点击了【技能1：斩击】 - 无特效")
	BattleManager.use_skill(1)
	var monster_alive = await _wait_for_attack_done()

func _on_skill2():
	print("→ 玩家点击了【技能2：重斩】 - 攻击动画后播放轻微震动")
	BattleManager.use_skill(2)
	var monster_alive = await _wait_for_attack_done()
	if not monster_alive:
		return
	# 重斩：只加入轻微震动
	_tween_shake(monster_battler, 4.0, 0.25)
	_tween_shake(player_battler, 2.0, 0.2)

func _on_skill3():
	print("→ 玩家点击了【技能3：破甲斩】 - 攻击动画后播放震动 + 破甲图标")
	BattleManager.use_skill(3)
	var monster_alive = await _wait_for_attack_done()
	if not monster_alive:
		return
	# 破甲斩：震动特效 + 破甲图标
	_tween_shake(monster_battler, 8.0, 0.4)
	_tween_shake(player_battler, 3.0, 0.25)
	_spawn_armor_break_icon()
	_spawn_slash_fx(Color(0.8, 0.6, 0.2), 1.0)

func _on_skill4():
	print("→ 玩家点击了【技能4：怒斩苍穹】 - 攻击动画后播放大招特效")
	BattleManager.use_skill(4)
	var monster_alive = await _wait_for_attack_done()
	if not monster_alive:
		return
	# 怒斩苍穹：大招，特效要多
	_tween_shake(monster_battler, 15.0, 0.7)
	_tween_shake(player_battler, 6.0, 0.4)
	_spawn_sparks()           # 火花
	_spawn_slash_fx(Color(1.0, 0.3, 0.1), 2.0)  # 红色大斩击
	_spawn_slash_fx(Color(1.0, 0.85, 0.1), 1.8) # 金色斩击
	_spawn_shockwave_fx()     # 冲击波
	_spawn_flash_overlay()    # 屏幕闪光

func _on_player_escape():
	print("→ 玩家点击了【逃跑】")
	BattleManager.try_escape()

# ===================== 辅助：等待攻击动画完成，返回怪物是否存活 =====================
func _wait_for_attack_done() -> bool:
	# 等待攻击开始（in_attack 变为 true）
	while is_instance_valid(player_battler) and not player_battler.in_attack:
		await get_tree().process_frame
	# 等待攻击结束（in_attack 变为 false）
	while is_instance_valid(player_battler) and player_battler.in_attack:
		await get_tree().process_frame
	# 返回怪物是否还活着
	return is_instance_valid(monster_battler) and not monster_battler.is_dead

func _on_use_heal_potion():
	print("→ 玩家使用了【血瓶】，恢复HP")
	BattleManager.use_heal_potion()

func _on_use_mana_potion():
	print("→ 玩家使用了【蓝瓶】，恢复MP")
	BattleManager.use_mana_potion()

# ===================== 特效：震动 =====================
func _tween_shake(target: Node2D, intensity: float, duration: float):
	if not is_instance_valid(target):
		return
	var origin: Vector2 = Vector2.ZERO
	if target == player_battler:
		origin = _player_origin
	elif target == monster_battler:
		origin = _monster_origin
	else:
		origin = target.position

	var tween = create_tween()
	tween.set_parallel(true)
	var steps = int(duration / 0.04)
	for i in range(steps):
		var offset_x = randf_range(-intensity, intensity)
		var offset_y = randf_range(-intensity, intensity)
		tween.tween_property(target, "position", origin + Vector2(offset_x, offset_y), 0.04)
	# 最后复位
	tween.tween_property(target, "position", origin, 0.06)

# ===================== 特效：破甲图标 =====================
func _spawn_armor_break_icon():
	if not is_instance_valid(monster_battler) or not is_instance_valid(_fx_layer):
		return
	# 用 Label 模拟"破甲"图标（大字，金色）
	var label = Label.new()
	label.name = "ArmorBreakIcon"
	label.text = "⚔ 破甲!"
	label.add_theme_font_size_override("font_size", 48)
	label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.1, 1.0))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(200, 60)
	label.position = monster_battler.global_position - Vector2(100, 100)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 100
	label.modulate.a = 0.0
	_fx_layer.add_child(label)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "modulate:a", 1.0, 0.1)
	tween.tween_property(label, "position:y", label.position.y - 30, 0.4)
	tween.chain().tween_interval(0.3)
	tween.tween_property(label, "modulate:a", 0.0, 0.3)
	tween.tween_callback(label.queue_free)

# ===================== 特效：斩击（斜线）=====================
func _spawn_slash_fx(col: Color, scale_val: float):
	if not is_instance_valid(monster_battler) or not is_instance_valid(_fx_layer):
		return
	# 用 Panel + stylebox 画一个大斜线/半透明遮罩模拟斩击光
	var slash = Panel.new()
	slash.name = "SlashFX"
	var style = StyleBoxFlat.new()
	style.bg_color = col
	style.border_width_left = 0
	style.border_width_right = 0
	style.border_width_top = 0
	style.border_width_bottom = 0
	style.set_corner_radius_all(12)
	slash.add_theme_stylebox_override("panel", style)
	slash.custom_minimum_size = Vector2(300 * scale_val, 18)
	slash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slash.z_index = 99
	slash.position = monster_battler.global_position - Vector2(150 * scale_val, 10)
	slash.rotation = randf_range(-0.5, 0.5)
	slash.modulate.a = 0.0
	_fx_layer.add_child(slash)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(slash, "modulate:a", 0.9, 0.08)
	tween.tween_property(slash, "scale", Vector2(scale_val, scale_val), 0.15)
	tween.chain().tween_property(slash, "modulate:a", 0.0, 0.3)
	tween.tween_callback(slash.queue_free)

# ===================== 特效：火花（多个小圆点飞散）=====================
func _spawn_sparks():
	if not is_instance_valid(monster_battler) or not is_instance_valid(_fx_layer):
		return
	var center = monster_battler.global_position
	for i in range(14):
		var spark = ColorRect.new()
		spark.name = "Spark" + str(i)
		spark.size = Vector2(10, 10)
		spark.color = Color(1.0, randf_range(0.4, 0.9), 0.0, 1.0)
		spark.position = center - Vector2(5, 5)
		spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spark.z_index = 95
		_fx_layer.add_child(spark)

		var angle = randf_range(-PI, PI)
		var distance = randf_range(80, 180)
		var end_pos = center + Vector2(cos(angle) * distance, sin(angle) * distance) - Vector2(5, 5)

		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(spark, "position", end_pos, 0.5)
		tween.tween_property(spark, "size", Vector2(2, 2), 0.5)
		tween.chain().tween_interval(0.05)
		tween.tween_property(spark, "modulate:a", 0.0, 0.2)
		tween.tween_callback(spark.queue_free)

# ===================== 特效：冲击波（圆圈扩散）=====================
func _spawn_shockwave_fx():
	if not is_instance_valid(monster_battler) or not is_instance_valid(_fx_layer):
		return
	var center = monster_battler.global_position

	for ring in range(2):
		var shock = Panel.new()
		shock.name = "Shockwave" + str(ring)
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
		style.border_width_left = 4
		style.border_width_right = 4
		style.border_width_top = 4
		style.border_width_bottom = 4
		style.border_color = Color(1.0, 0.6, 0.1, 0.9)
		style.set_corner_radius_all(80)
		shock.add_theme_stylebox_override("panel", style)
		shock.custom_minimum_size = Vector2(40, 40)
		shock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shock.z_index = 90
		shock.position = center - Vector2(20, 20)
		_fx_layer.add_child(shock)

		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_interval(ring * 0.08)
		tween.tween_property(shock, "custom_minimum_size", Vector2(240, 240), 0.5)
		tween.tween_property(shock, "position", center - Vector2(120, 120), 0.5)
		tween.tween_property(shock, "modulate:a", 0.0, 0.5)
		tween.chain().tween_callback(shock.queue_free)

# ===================== 特效：屏幕闪光 =====================
func _spawn_flash_overlay():
	if not is_instance_valid(_fx_layer):
		return
	var flash = ColorRect.new()
	flash.name = "ScreenFlash"
	flash.color = Color(1.0, 0.95, 0.5, 0.7)
	flash.size = Vector2(2000, 1500)
	flash.position = Vector2(-500, -300)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.z_index = 50
	flash.modulate.a = 0.0
	_fx_layer.add_child(flash)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "modulate:a", 0.6, 0.06)
	tween.chain().tween_property(flash, "modulate:a", 0.0, 0.25)
	tween.tween_callback(flash.queue_free)
