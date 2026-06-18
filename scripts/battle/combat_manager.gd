extends Node2D

@onready var combat_ui: CombatUI = $CombatUI

# 战斗中引用的节点
@onready var player_team: Node2D = $PlayerTeam
@onready var enemy_team: Node2D = $EnemyTeam
@onready var player_battler: Node2D = get_node("PlayerTeam/Player-Battler")
@onready var monster_battler: Node2D = get_node("EnemyTeam/Monster-Battler")

# 动态获取当前怪物目标（Boss 战时从 BattleManager 获取）
var _current_monster: Node2D:
	get:
		if is_instance_valid(BattleManager.current_enemy):
			return BattleManager.current_enemy
		return monster_battler

# 记录初始位置（用于震动后复位）
var _player_origin: Vector2 = Vector2.ZERO
var _monster_origin: Vector2 = Vector2.ZERO
var _camera_origin: Vector2 = Vector2.ZERO

# 动态创建的特效容器
var _fx_layer: Node2D = null
var _bgm_player: AudioStreamPlayer = null

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
	_play_bgm()

	# 保存初始位置，便于震动后复位
	if is_instance_valid(player_battler):
		_player_origin = player_battler.position
	if is_instance_valid(_current_monster):
		_monster_origin = _current_monster.position
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
	_tween_shake(_current_monster, 4.0, 0.25)
	_tween_shake(player_battler, 2.0, 0.2)

func _on_skill3():
	print("→ 玩家点击了【技能3：破甲斩】")
	BattleManager.use_skill(3)
	var monster_alive = await _wait_for_attack_done()
	if not monster_alive:
		return

	# 破甲斩：短距离弧形重劈 + 盔甲碎裂白光 + 金属冲击感
	_spawn_armor_break_slash()       # 短距离弧形大气刃重劈
	_tween_shake(_current_monster, 12.0, 0.35)  # 怪物厚重震动
	_tween_shake(player_battler, 4.0, 0.2)      # 玩家轻微震动

	await get_tree().create_timer(0.04).timeout
	_spawn_armor_shatter_flash()     # 盔甲碎裂白光

	await get_tree().create_timer(0.06).timeout
	_spawn_metal_sparks()            # 金属碎片飞散

func _on_skill4():
	print("→ 玩家点击了【技能4：怒斩苍穹】 - 攻击动画后播放大招特效")
	BattleManager.use_skill(4)
	var monster_alive = await _wait_for_attack_done()
	if not monster_alive:
		return

	# ── 时间线：怒斩苍穹 ──
	# 0ms    → 全屏纯白强光爆发
	_spawn_intense_flash()

	# 30ms   → 一道弧形气刃从天空劈下
	await get_tree().create_timer(0.03).timeout
	_spawn_sky_slash()

	# 80ms   → 3条弧形斜斩
	await get_tree().create_timer(0.05).timeout
	_spawn_sky_cleave_main()

	# 150ms  → 火焰流光 + 光晕粒子飞散
	await get_tree().create_timer(0.07).timeout
	_spawn_flame_streaks()

	# 200ms  → 十字交叉弧形斩出现
	await get_tree().create_timer(0.05).timeout
	_spawn_sky_cleave_cross()

	# 500ms  → 冲击波扩散 + 怪物剧烈震动
	await get_tree().create_timer(0.30).timeout
	_spawn_shockwave_fx()
	_tween_shake(_current_monster, 20.0, 0.8)
	_tween_shake(player_battler, 8.0, 0.5)

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
	return is_instance_valid(_current_monster) and not _current_monster.is_dead

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
	elif target == _current_monster:
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
	if not is_instance_valid(_current_monster) or not is_instance_valid(_fx_layer):
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
	label.position = _current_monster.global_position - Vector2(100, 100)
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
	if not is_instance_valid(_current_monster) or not is_instance_valid(_fx_layer):
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
	slash.position = _current_monster.global_position - Vector2(150 * scale_val, 10)
	slash.rotation = randf_range(-0.5, 0.5)
	slash.modulate.a = 0.0
	_fx_layer.add_child(slash)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(slash, "modulate:a", 0.9, 0.08)
	tween.tween_property(slash, "scale", Vector2(scale_val, scale_val), 0.15)
	tween.chain().tween_property(slash, "modulate:a", 0.0, 0.3)
	tween.tween_callback(slash.queue_free)

# ===================== 破甲斩：短距离弧形重劈 =====================
func _spawn_armor_break_slash():
	if not is_instance_valid(_current_monster) or not is_instance_valid(_fx_layer):
		return
	var center = _current_monster.global_position

	# 主气刃：短而厚重，冷灰金属色调
	var blade = _make_qi_blade(
		340, 48, 22,
		Color(0.5, 0.55, 0.65, 0.92),     # 外焰：铁灰蓝
		Color(0.78, 0.82, 0.90, 1.0),      # 内焰：冷银白
		120
	)
	blade.position = center + Vector2(20, 10)
	blade.rotation = -0.3                  # 轻微斜劈
	blade.modulate.a = 0.0
	_fx_layer.add_child(blade)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(blade, "modulate:a", 1.0, 0.03)
	tween.tween_property(blade, "scale", Vector2(1.15, 1.15), 0.08)
	tween.chain().tween_property(blade, "modulate:a", 0.0, 0.35)
	tween.tween_callback(blade.queue_free)

	# 第二道细刃：反向轻劈，增加层次
	var blade2 = _make_qi_blade(
		260, 28, 14,
		Color(0.55, 0.6, 0.72, 0.85),
		Color(0.82, 0.86, 0.94, 1.0),
		118
	)
	blade2.position = center + Vector2(-15, -5)
	blade2.rotation = 0.2
	blade2.modulate.a = 0.0
	_fx_layer.add_child(blade2)

	var tween2 = create_tween()
	tween2.set_parallel(true)
	tween2.tween_interval(0.04)
	tween2.tween_property(blade2, "modulate:a", 0.85, 0.03)
	tween2.tween_property(blade2, "scale", Vector2(1.1, 1.1), 0.08)
	tween2.chain().tween_property(blade2, "modulate:a", 0.0, 0.3)
	tween2.tween_callback(blade2.queue_free)

# ===================== 破甲斩：盔甲碎裂白光（破碎的盾） =====================
func _spawn_armor_shatter_flash():
	if not is_instance_valid(_current_monster) or not is_instance_valid(_fx_layer):
		return
	var center = _current_monster.global_position
	var shield_size = 120.0

	# --- 圆形制式铁盾：哑光灰金属底色 + 盾沿加厚凸起包边 ---
	var shield = Panel.new()
	shield.name = "IronShield"
	var shield_style = StyleBoxFlat.new()
	shield_style.bg_color = Color(0.42, 0.45, 0.52, 0.92)     # 哑光灰金属底色
	shield_style.border_width_left = 10
	shield_style.border_width_right = 10
	shield_style.border_width_top = 10
	shield_style.border_width_bottom = 10
	shield_style.border_color = Color(0.28, 0.31, 0.38, 1.0)   # 盾沿深灰加厚包边
	shield_style.set_corner_radius_all(int(shield_size / 2))     # 正圆形
	shield.add_theme_stylebox_override("panel", shield_style)
	shield.custom_minimum_size = Vector2(shield_size, shield_size)
	shield.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shield.z_index = 126
	shield.position = center - Vector2(shield_size / 2, shield_size / 2)
	shield.modulate.a = 0.0
	_fx_layer.add_child(shield)

	# 盾牌出现 → 碎裂
	var t_shield = create_tween()
	t_shield.set_parallel(true)
	t_shield.tween_property(shield, "modulate:a", 0.95, 0.03)
	t_shield.tween_property(shield, "scale", Vector2(1.0, 1.0), 0.03)
	t_shield.chain().tween_interval(0.04)
	# 碎裂：缩小 + 旋转 + 淡出
	t_shield.set_parallel(true)
	t_shield.tween_property(shield, "modulate:a", 0.0, 0.2)
	t_shield.tween_property(shield, "scale", Vector2(0.3, 0.3), 0.2)
	t_shield.tween_property(shield, "rotation", randf_range(-0.4, 0.4), 0.2)
	t_shield.tween_callback(shield.queue_free)

	# --- 碎裂裂缝线：从盾心向外放射 ---
	for i in range(6):
		var crack = Line2D.new()
		crack.name = "ShieldCrack" + str(i)
		crack.width = randf_range(2, 5)
		crack.default_color = Color(1.0, 1.0, 1.0, 0.85)
		crack.z_index = 125
		crack.z_as_relative = false
		crack.begin_cap_mode = Line2D.LINE_CAP_ROUND
		crack.end_cap_mode = Line2D.LINE_CAP_ROUND
		var ang = i * PI / 3.0 + randf_range(-0.2, 0.2)
		var r = randf_range(35, 75)
		crack.points = PackedVector2Array([
			center,
			center + Vector2(cos(ang) * r * 0.5, sin(ang) * r * 0.5),
			center + Vector2(cos(ang) * r, sin(ang) * r),
		])
		crack.modulate.a = 0.0
		_fx_layer.add_child(crack)

		var t_crack = create_tween()
		t_crack.set_parallel(true)
		t_crack.tween_interval(0.03 + i * 0.01)
		t_crack.tween_property(crack, "modulate:a", 0.9, 0.02)
		t_crack.chain().tween_property(crack, "modulate:a", 0.0, 0.2)
		t_crack.tween_callback(crack.queue_free)

	# --- 盾牌碎片：小块飞散 ---
	for i in range(8):
		var frag = ColorRect.new()
		frag.name = "ShieldFrag" + str(i)
		frag.color = Color(0.4, 0.43, 0.5, 0.9)
		frag.size = Vector2(randf_range(8, 18), randf_range(8, 18))
		frag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frag.z_index = 124
		frag.position = center - frag.size * 0.5
		frag.modulate.a = 0.0
		_fx_layer.add_child(frag)

		var frag_ang = randf_range(-PI, PI)
		var frag_dist = randf_range(40, 100)
		var frag_end = center + Vector2(cos(frag_ang) * frag_dist, sin(frag_ang) * frag_dist) - frag.size * 0.5

		var t_frag = create_tween()
		t_frag.set_parallel(true)
		t_frag.tween_interval(0.05 + randf_range(0.0, 0.04))
		t_frag.tween_property(frag, "modulate:a", 0.85, 0.02)
		t_frag.tween_property(frag, "position", frag_end, 0.3)
		t_frag.tween_property(frag, "rotation", randf_range(-PI, PI), 0.3)
		t_frag.tween_property(frag, "size", Vector2(3, 3), 0.3)
		t_frag.chain().tween_property(frag, "modulate:a", 0.0, 0.2)
		t_frag.tween_callback(frag.queue_free)

# ===================== 破甲斩：金属碎片飞散 =====================
func _spawn_metal_sparks():
	if not is_instance_valid(_current_monster) or not is_instance_valid(_fx_layer):
		return
	var center = _current_monster.global_position

	for i in range(16):
		var spark = ColorRect.new()
		spark.name = "MetalSpark" + str(i)
		# 冷灰金属色调：银灰 → 铁灰 → 钢蓝
		var brightness = randf_range(0.5, 0.95)
		spark.color = Color(brightness, brightness + 0.05, brightness + 0.12, 1.0)
		spark.size = Vector2(randf_range(4, 10), randf_range(4, 10))
		spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spark.z_index = 122
		spark.position = center - spark.size * 0.5
		spark.modulate.a = 0.0
		_fx_layer.add_child(spark)

		var angle = randf_range(-PI, PI)
		var dist = randf_range(40, 130)
		var end_pos = center + Vector2(cos(angle) * dist, sin(angle) * dist) - spark.size * 0.5

		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_interval(randf_range(0.0, 0.08))
		tween.tween_property(spark, "modulate:a", 0.9, 0.03)
		tween.tween_property(spark, "position", end_pos, 0.35)
		tween.tween_property(spark, "size", Vector2(2, 2), 0.35)
		tween.chain().tween_interval(0.05)
		tween.tween_property(spark, "modulate:a", 0.0, 0.2)
		tween.tween_callback(spark.queue_free)

# ===================== 特效：火花（多个小圆点飞散）=====================
func _spawn_sparks():
	if not is_instance_valid(_current_monster) or not is_instance_valid(_fx_layer):
		return
	var center = _current_monster.global_position
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
	if not is_instance_valid(_current_monster) or not is_instance_valid(_fx_layer):
		return
	var center = _current_monster.global_position

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

# ===================== 怒斩苍穹：3条弧形斜斩（80ms） =====================
func _spawn_sky_cleave_main():
	if not is_instance_valid(_current_monster) or not is_instance_valid(_fx_layer):
		return
	var center = _current_monster.global_position

	for i in range(3):
		var blade = _make_qi_blade(
			520 + i * 100, 38 + i * 6, 18 + i * 8,
			Color(1.0, 0.5 + i * 0.15, 0.03, 0.95),
			Color(1.0, 0.85 + i * 0.05, 0.3, 1.0),
			120 - i
		)
		blade.position = center
		blade.rotation = PI * 0.25 + i * 0.15
		blade.modulate.a = 0.0
		_fx_layer.add_child(blade)

		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_interval(i * 0.06)
		tween.tween_property(blade, "modulate:a", 1.0, 0.04)
		tween.tween_property(blade, "scale", Vector2(1.3, 1.3), 0.12)
		tween.chain().tween_property(blade, "modulate:a", 0.0, 0.4)
		tween.tween_callback(blade.queue_free)

# ===================== 怒斩苍穹：十字交叉弧形斩（200ms） =====================
func _spawn_sky_cleave_cross():
	if not is_instance_valid(_current_monster) or not is_instance_valid(_fx_layer):
		return
	var center = _current_monster.global_position

	for i in range(2):
		var ang = -PI * 0.25 + i * PI * 0.5
		var cross = _make_qi_blade(
			440, 30, 14,
			Color(1.0, 0.85, 0.2, 0.92) if i == 0 else Color(1.0, 0.45, 0.0, 0.88),
			Color(1.0, 0.95, 0.5, 1.0) if i == 0 else Color(1.0, 0.7, 0.2, 1.0),
			113 - i
		)
		cross.position = center
		cross.rotation = ang
		cross.modulate.a = 0.0
		_fx_layer.add_child(cross)

		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_interval(i * 0.05)
		tween.tween_property(cross, "modulate:a", 1.0, 0.04)
		tween.tween_property(cross, "scale", Vector2(1.2, 1.2), 0.10)
		tween.chain().tween_property(cross, "modulate:a", 0.0, 0.35)
		tween.tween_callback(cross.queue_free)

# ===================== 气刃工厂：生成弧线梭形气刃 =====================
func _make_qi_blade(length: float, max_width: float, curve_offset: float,
					 outer_color: Color, inner_color: Color, z: int) -> Node2D:
	var blade = Node2D.new()
	blade.name = "QiBlade"
	blade.z_index = z
	blade.z_as_relative = false

	# --- 外层气刃（宽） ---
	var outer = Line2D.new()
	outer.name = "OuterEdge"
	outer.z_index = 0
	outer.z_as_relative = false
	outer.width = max_width
	outer.width_curve = _make_blade_width_curve()
	outer.gradient = _make_blade_gradient(outer_color, outer_color.lightened(0.15))
	outer.begin_cap_mode = Line2D.LINE_CAP_ROUND
	outer.end_cap_mode = Line2D.LINE_CAP_ROUND

	# --- 内层气刃（窄，更亮） ---
	var inner = Line2D.new()
	inner.name = "InnerCore"
	inner.z_index = 1
	inner.z_as_relative = false
	inner.width = max_width * 0.45
	inner.width_curve = _make_blade_width_curve()
	inner.gradient = _make_blade_gradient(inner_color, Color.WHITE)
	inner.begin_cap_mode = Line2D.LINE_CAP_ROUND
	inner.end_cap_mode = Line2D.LINE_CAP_ROUND

	# --- 核心白线（最细最亮） ---
	var core = Line2D.new()
	core.name = "CoreLine"
	core.z_index = 2
	core.z_as_relative = false
	core.width = max_width * 0.12
	core.width_curve = _make_blade_width_curve()
	core.default_color = Color(1.0, 1.0, 1.0, 0.9)
	core.begin_cap_mode = Line2D.LINE_CAP_ROUND
	core.end_cap_mode = Line2D.LINE_CAP_ROUND

	# 气刃轨迹点：带弧线，让刀刃有弯曲感
	var half_len = length / 2.0
	var pts = PackedVector2Array()
	var segs = 8
	for s in range(segs + 1):
		var t = float(s) / segs
		var x = lerp(-half_len, half_len, t)
		var y = curve_offset * sin(t * PI)   # 中间拱起，两端平
		pts.append(Vector2(x, y))

	outer.points = pts
	inner.points = pts
	core.points = pts

	blade.add_child(outer)
	blade.add_child(inner)
	blade.add_child(core)

	return blade

# ===================== 气刃宽度曲线：两端尖、中间宽 =====================
func _make_blade_width_curve() -> Curve:
	var curve = Curve.new()
	curve.add_point(Vector2(0.0, 0.0), 0, 1.5)       # 尖端：宽度 0
	curve.add_point(Vector2(0.15, 0.25), 0, 0)        # 加速变宽
	curve.add_point(Vector2(0.5, 1.0), 0, 0)          # 中心：最宽
	curve.add_point(Vector2(0.85, 0.25), 0, 0)        # 加速收窄
	curve.add_point(Vector2(1.0, 0.0), -1.5, 0)       # 尖端：宽度 0
	return curve

# ===================== 气刃颜色渐变：中心白热 → 边缘色 → 外焰色 =====================
func _make_blade_gradient(edge_color: Color, hot_color: Color) -> Gradient:
	var grad = Gradient.new()
	grad.add_point(0.0, edge_color)        # 尖端：边缘色
	grad.add_point(0.15, hot_color)         # 过渡：热色
	grad.add_point(0.5, Color.WHITE)        # 中心：白热
	grad.add_point(0.85, hot_color)         # 过渡：热色
	grad.add_point(1.0, edge_color)         # 尖端：边缘色
	return grad

# ===================== 怒斩苍穹：金/橙火焰流光 =====================
func _spawn_flame_streaks():
	if not is_instance_valid(_current_monster) or not is_instance_valid(_fx_layer):
		return
	var center = _current_monster.global_position

	# 20道弧形火焰剑气：从怪物中心向外飞散
	for i in range(20):
		var angle = randf_range(-PI, PI)
		var dist = randf_range(60, 220)
		var hue = randf_range(0.07, 0.16)   # 金 → 橙 → 红

		var blade = _make_qi_blade(
			randf_range(80, 180),           # 长度：短剑气
			randf_range(8, 18),             # 宽度：窄
			randf_range(6, 20),             # 弧度
			Color.from_hsv(hue, 1.0, randf_range(0.6, 1.0), 0.85),  # 外焰
			Color.from_hsv(hue, 0.7, 1.0, 1.0),                     # 内焰
			105
		)
		blade.rotation = angle             # 指向发射方向
		blade.position = center + Vector2(cos(angle) * 20, sin(angle) * 20)
		blade.modulate.a = 0.0
		_fx_layer.add_child(blade)

		var target = center + Vector2(cos(angle) * dist, sin(angle) * dist)
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_interval(randf_range(0.0, 0.15))
		tween.tween_property(blade, "modulate:a", 0.9, 0.05)
		tween.tween_property(blade, "position", target, 0.4)
		tween.chain().tween_property(blade, "modulate:a", 0.0, 0.3)
		tween.tween_callback(blade.queue_free)

	# 火焰光晕粒子
	for i in range(12):
		var glow = ColorRect.new()
		glow.name = "FlameGlow" + str(i)
		glow.color = Color(1.0, randf_range(0.5, 0.8), randf_range(0.0, 0.2), 0.8)
		glow.size = Vector2(randf_range(20, 50), randf_range(20, 50))
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glow.z_index = 100
		glow.position = center - glow.size * 0.5
		glow.modulate.a = 0.0
		_fx_layer.add_child(glow)

		var tween2 = create_tween()
		tween2.set_parallel(true)
		tween2.tween_interval(randf_range(0.05, 0.2))
		tween2.tween_property(glow, "modulate:a", 0.7, 0.08)
		tween2.tween_property(glow, "size", glow.size * 2.5, 0.5)
		tween2.tween_property(glow, "position", center - glow.size * 2.5 * 0.5, 0.5)
		tween2.chain().tween_property(glow, "modulate:a", 0.0, 0.3)
		tween2.tween_callback(glow.queue_free)

# ===================== 怒斩苍穹：天空劈下弧形气刃（30ms） =====================
func _spawn_sky_slash():
	if not is_instance_valid(_current_monster) or not is_instance_valid(_fx_layer):
		return
	var center = _current_monster.global_position

	# 从屏幕上方劈下的弧形气刃，带轨迹拖尾
	var blade = _make_qi_blade(
		600, 44, 30,
		Color(1.0, 0.9, 0.2, 0.92),
		Color(1.0, 0.95, 0.6, 1.0),
		115
	)
	blade.rotation = 0.25    # 带一点倾斜
	blade.position = Vector2(center.x, center.y - 350)   # 从天空开始
	blade.modulate.a = 0.0
	_fx_layer.add_child(blade)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(blade, "modulate:a", 1.0, 0.04)
	tween.tween_property(blade, "position", center, 0.25)   # 劈到怪物身上
	tween.chain().tween_property(blade, "modulate:a", 0.0, 0.25)
	tween.tween_callback(blade.queue_free)

	# 伴随的拖尾裂缝（细线跟随）
	for i in range(3):
		var trail = Line2D.new()
		trail.name = "SkyTrail" + str(i)
		trail.width = 6 - i * 1.5
		trail.default_color = Color(1.0, 0.9 - i * 0.15, 0.3, 0.7 - i * 0.15)
		trail.z_index = 112 - i
		trail.z_as_relative = false
		trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
		trail.end_cap_mode = Line2D.LINE_CAP_ROUND
		trail.points = PackedVector2Array([
			Vector2(center.x + i * 30 - 45, center.y - 350),
			Vector2(center.x + i * 20 - 30, center.y - 200),
			Vector2(center.x + i * 10 - 15, center.y),
		])
		trail.modulate.a = 0.0
		_fx_layer.add_child(trail)

		var t2 = create_tween()
		t2.set_parallel(true)
		t2.tween_interval(i * 0.03)
		t2.tween_property(trail, "modulate:a", 0.8, 0.04)
		t2.chain().tween_property(trail, "modulate:a", 0.0, 0.2)
		t2.tween_callback(trail.queue_free)

# ===================== 怒斩苍穹：全屏强光（0ms 白 / 60ms 金 / 120ms 橙） =====================
func _spawn_intense_flash():
	if not is_instance_valid(_fx_layer):
		return

	# 阶段1（0ms）：纯白强光瞬间爆发
	var flash1 = ColorRect.new()
	flash1.name = "FlashWhite"
	flash1.color = Color(1.0, 1.0, 1.0, 1.0)
	flash1.size = Vector2(2000, 1500)
	flash1.position = Vector2(-500, -300)
	flash1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash1.z_index = 200
	flash1.modulate.a = 0.0
	_fx_layer.add_child(flash1)

	var t1 = create_tween()
	t1.tween_property(flash1, "modulate:a", 0.95, 0.02)
	t1.tween_property(flash1, "modulate:a", 0.0, 0.12)
	t1.tween_callback(flash1.queue_free)

	# 阶段2（60ms）：金色余光，之后消失
	var flash2 = ColorRect.new()
	flash2.name = "FlashGold"
	flash2.color = Color(1.0, 0.8, 0.1, 1.0)
	flash2.size = Vector2(2000, 1500)
	flash2.position = Vector2(-500, -300)
	flash2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash2.z_index = 199
	flash2.modulate.a = 0.0
	_fx_layer.add_child(flash2)

	var t2 = create_tween()
	t2.tween_interval(0.06)
	t2.tween_property(flash2, "modulate:a", 0.7, 0.04)
	t2.tween_property(flash2, "modulate:a", 0.0, 0.35)
	t2.tween_callback(flash2.queue_free)

	# 阶段3（120ms）：橙色光晕，之后消失
	var flash3 = ColorRect.new()
	flash3.name = "FlashOrange"
	flash3.color = Color(1.0, 0.4, 0.05, 1.0)
	flash3.size = Vector2(2000, 1500)
	flash3.position = Vector2(-500, -300)
	flash3.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash3.z_index = 198
	flash3.modulate.a = 0.0
	_fx_layer.add_child(flash3)

	var t3 = create_tween()
	t3.tween_interval(0.12)
	t3.tween_property(flash3, "modulate:a", 0.5, 0.06)
	t3.tween_property(flash3, "modulate:a", 0.0, 0.45)
	t3.tween_callback(flash3.queue_free)

func _play_bgm():
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.name = "BGMMusic"
	_bgm_player.bus = "Master"
	add_child(_bgm_player)
	var stream = load("res://Asset Bundle/battle/raging-battlefield-anime-theme-stocktune.mp3")
	if stream and stream is AudioStream:
		_bgm_player.stream = stream
		stream.loop = true
		_bgm_player.play()
