extends Node2D

# ============================================================
# 战斗场景的设计分辨率（场景文件中的原始坐标基准）
# ============================================================
const DESIGN_WIDTH = 1152.0
const DESIGN_HEIGHT = 648.0

# 战斗场景中玩家的目标像素高度（设计分辨率内）
const PLAYER_TARGET_HEIGHT = 180.0
# 怪物比玩家大的基础比例（小怪如 bear 帧很小，需要更高比例才显大）
const MONSTER_SIZE_RATIO = 1.4
# 怪物视觉高度上限（玩家高度的倍数，防止 Boss 过大）
const MONSTER_MAX_VISUAL_RATIO = 1.5

# ============================================================
# ★ 战斗场景角色位置（设计分辨率下的坐标，修改这里即可调整位置）
# ============================================================
const PLAYER_BATTLE_X = 378.0  # 玩家 X 坐标
const PLAYER_BATTLE_Y = 649.0  # 玩家 Y 坐标（越大越靠上）
const MONSTER_BATTLE_X = 800.0  # 怪物 X 坐标
const MONSTER_BATTLE_Y = 649.0  # 怪物 Y 坐标（越大越靠上）

# ============================================================
# ★ 每个怪物的 Y 轴微调偏移（正值=下移，负值=上移，单位：像素）
# ============================================================
const MONSTER_Y_OFFSETS = {
	"slime": 85.0,
	"bat": 230,
	"rat": 210,
	"mushroom": -30.0,
	"rock_giant": 55,
	"slime_king": -30,
	"Bringer": 225,
	"bone_knight": 150,
	"necromancer": 250.0,
	"summoned_minion": -300.0
}


func _get_sprite_info(sprite: AnimatedSprite2D) -> Dictionary:
	var result = {"size": Vector2.ZERO, "has_anim": false}
	if not sprite or not sprite.sprite_frames:
		return result
	var anims = sprite.sprite_frames.get_animation_names()
	if anims.size() == 0:
		return result
	if sprite.sprite_frames.get_frame_count(anims[0]) == 0:
		return result
	var tex = sprite.sprite_frames.get_frame_texture(anims[0], 0)

	if not tex:
		return result
	result["size"] = tex.get_size()
	result["has_anim"] = true
	return result


# 根据帧高度和目标高度计算战斗缩放
func _calc_battle_scale(
	sprite: AnimatedSprite2D, target_height: float, scale_factor: float
) -> Vector2:
	var info = _get_sprite_info(sprite)
	if not info["has_anim"] or info["size"].y <= 0:
		return Vector2.ONE * scale_factor
	var s = target_height / info["size"].y * scale_factor
	return Vector2(s, s)


func _position_hud(character: Node2D) -> void:
	var hud = character.get_node_or_null("HUD")
	if not hud:
		hud = character.get_node_or_null("BossHUD")
	if not hud:
		hud = character.get_node_or_null("MinionHUD")
	if not hud:
		return
	var sprite = character.get_node_or_null("AnimatedSprite2D")
	if not sprite or not sprite.sprite_frames:
		return

	var info = _get_sprite_info(sprite)
	var sprite_height: float = info["size"].y if info["has_anim"] else 64.0

	# 精灵视觉顶部 = sprite 原点 + offset（渲染偏移）* 缩放 - 纹理高度*缩放/2
	var visual_top = sprite.position.y + (sprite.offset.y - sprite_height / 2.0) * sprite.scale.y
	# 计算 HUD 总高度（玩家有 HP+MP，怪物只有 HP）
	var hud_height: float = 0.0
	for child in hud.get_children():
		if child is ColorRect or child is Label:
			hud_height = max(hud_height, child.position.y + child.size.y)

	# 血条紧贴精灵顶部，略微重叠 3px
	hud.position.y = visual_top - hud_height + 3.0
	# X 坐标：根据 HUD 内最大元素宽度自动居中
	var hud_width: float = 0.0
	for child in hud.get_children():
		if child is ColorRect or child is Label:
			hud_width = max(hud_width, child.size.x)
	hud.position.x = -hud_width / 2.0 + sprite.position.x


@onready var combat_ui: CombatUI = $CombatUI

# 战斗中引用的节点
@onready var player_team: Node2D = $PlayerTeam
@onready var enemy_team: Node2D = $EnemyTeam
@onready var player_battler: Node2D = get_node("PlayerTeam/Player-Battler")
@onready var monster_battler: Node2D = get_node("EnemyTeam/Monster-Battler")
@onready var bg_sprite: Sprite2D = $Background

# 动态获取当前怪物目标（Boss 战时从 BattleManager 获取）
var _current_monster: Node2D:
	get:
		if is_instance_valid(BattleManager.current_enemy):
			return BattleManager.current_enemy
		return monster_battler

# ============================================================
# 原始状态记录（在任何缩放前保存，用于窗口变化时重新计算）
# ============================================================
var _original_bg_scale: Vector2 = Vector2.ONE
# 动态怪物专用：记录每个动态怪物的原始 global_position
var _dynamic_monster_original_pos: Dictionary = {}  # key: instance_id -> Vector2

# 记录初始位置（用于震动后复位）
var _player_origin: Vector2 = Vector2.ZERO
var _monster_origin: Vector2 = Vector2.ZERO
var _camera_origin: Vector2 = Vector2.ZERO
# 怪物原始 offset（用于翻转时修正位置，如 skull 帧内角色不居中）
var _monster_original_offset: Vector2 = Vector2.ZERO
# 怪物原始 sprite position.x（用于翻转时补偿精灵帧不居中）
var _monster_original_sprite_pos_x: float = NAN

# 动态创建的特效容器
var _fx_layer: Node2D = null
var _bgm_player: AudioStreamPlayer = null

# 当前执行中的技能ID（用于特效守卫，0=无技能，3=破甲斩，4=怒斩苍穹）
var _current_skill_id: int = 0


func _ready():
	combat_ui.skill1_pressed.connect(_on_skill1)
	combat_ui.skill2_pressed.connect(_on_skill2)
	combat_ui.skill3_pressed.connect(_on_skill3)
	combat_ui.skill4_pressed.connect(_on_skill4)
	combat_ui.escape_pressed.connect(_on_player_escape)
	combat_ui.heal_pressed.connect(_on_use_heal_potion)
	combat_ui.mana_pressed.connect(_on_use_mana_potion)

	# ============================================================
	# ★ 设置角色位置（直接使用常量，修改文件顶部常量即可调整）
	# ============================================================
	if bg_sprite:
		_original_bg_scale = bg_sprite.scale

	# 玩家位置：直接应用常量
	if is_instance_valid(player_battler):
		player_battler.position = Vector2(PLAYER_BATTLE_X, PLAYER_BATTLE_Y)
		# 同步更新攻击回归位置（player_battler._ready 先执行，_original_position 记录的是旧位置）
		player_battler._original_position = player_battler.global_position
	# 怪物位置：直接应用常量
	if is_instance_valid(monster_battler):
		monster_battler.position = Vector2(MONSTER_BATTLE_X, MONSTER_BATTLE_Y)

	_update_skill_buttons()
	combat_ui.refresh_skill_locks()
	combat_ui.update_exp_bar()
	_play_bgm()

	# 自动设置角色朝向（spawn point 为锚点，不受朝向影响）
	_auto_face_targets()

	# 初始适配
	_fit_background()

	# 保存初始位置，便于震动后复位
	if is_instance_valid(player_battler):
		_player_origin = player_battler.position
		player_battler._original_position = player_battler.global_position
	if is_instance_valid(_current_monster):
		_monster_origin = _current_monster.position
	_camera_origin = Vector2.ZERO

	# 创建特效层
	_fx_layer = Node2D.new()
	_fx_layer.name = "FXLayer"
	add_child(_fx_layer)

	# 战斗开始时同步玩家当前等级属性到血条UI
	_sync_player_battler_stats()

	# 监听窗口大小变化
	var tree = get_tree()
	if tree and tree.root:
		tree.root.size_changed.connect(_on_window_resized)


func _on_window_resized():
	# 用户手动调整窗口大小时重新适配
	_fit_background()
	# 同时更新震动复位的基准位置
	if is_instance_valid(player_battler):
		_player_origin = player_battler.position
		player_battler._original_position = player_battler.global_position
	if is_instance_valid(_current_monster):
		_monster_origin = _current_monster.position


# ============================================================
# 对外接口：BattleManager 设置完怪物后调用，让动态创建的怪物也被缩放
# ============================================================
func refit():
	print(
		"[refit] 被调用！_current_monster=",
		_current_monster.name if is_instance_valid(_current_monster) else "无效"
	)
	_auto_face_targets()
	_fit_background()
	if is_instance_valid(player_battler):
		_player_origin = player_battler.position
		player_battler._original_position = player_battler.global_position
	if is_instance_valid(_current_monster):
		_monster_origin = _current_monster.position


func get_original_monster_pos() -> Vector2:
	return Vector2(MONSTER_BATTLE_X, MONSTER_BATTLE_Y)


func reset_monster_offset():
	_monster_original_offset = Vector2.ZERO
	_monster_original_sprite_pos_x = NAN


func _fit_background():
	# 按窗口大小等比例缩放整个战斗场景（背景 + 玩家 + 怪物）
	# 使用保存的原始状态作为基准，支持任意次调用（窗口缩放时重复调用）
	var tree = get_tree()
	if not tree:
		return
	var viewport_size = tree.root.size

	# 计算等比例缩放因子
	var scale_x = viewport_size.x / DESIGN_WIDTH
	var scale_y = viewport_size.y / DESIGN_HEIGHT
	var scale_factor = max(scale_x, scale_y)

	# ============================================================
	# 1. 背景：按缩放因子放大，居中到窗口
	# ============================================================
	if bg_sprite and bg_sprite.texture:
		bg_sprite.scale = _original_bg_scale * scale_factor
		bg_sprite.position = viewport_size / 2.0

	# ============================================================
	# 2. 玩家：根据帧高度和目标高度计算缩放，位置按比例移动
	# ============================================================
	var player_base_scale = Vector2.ONE * scale_factor
	if is_instance_valid(player_battler):
		player_battler.position = Vector2(
			PLAYER_BATTLE_X * scale_factor, PLAYER_BATTLE_Y * scale_factor
		)
		if player_battler.has_node("AnimatedSprite2D"):
			var p_sprite = player_battler.get_node("AnimatedSprite2D")
			var new_scale = _calc_battle_scale(p_sprite, PLAYER_TARGET_HEIGHT, scale_factor)
			p_sprite.scale = new_scale
			player_base_scale = new_scale
			# 重新计算脚对齐（scale 改变后 offset.y 需要重新计算）
			var p_info = _get_sprite_info(p_sprite)
			if p_info["has_anim"] and p_info["size"].y > 0:
				p_sprite.offset = Vector2(
					0, -p_sprite.position.y - p_info["size"].y / 2.0 * new_scale.y
				)
		_position_hud(player_battler)

	# ============================================================
	# 3. 怪物：用玩家缩放 × 1.35，小怪明显比玩家大；帧大的 Boss 自动上限
	# ============================================================
	var actual_monster = _current_monster
	if is_instance_valid(actual_monster) and actual_monster.has_node("AnimatedSprite2D"):
		var m_sprite = actual_monster.get_node("AnimatedSprite2D")
		var mid = actual_monster.get_instance_id()

		# 获取当前怪物的 Y 偏移（查表，未在表中则默认 0）
		var monster_y_offset = MONSTER_Y_OFFSETS.get(actual_monster.monster_name, 0.0)

		# 计算怪物缩放（带上限）
		var monster_scale = player_base_scale * MONSTER_SIZE_RATIO
		var m_info = _get_sprite_info(m_sprite)
		if m_info["has_anim"] and m_info["size"].y > 0:
			var player_h = PLAYER_TARGET_HEIGHT * scale_factor
			var monster_h = m_info["size"].y * monster_scale.x
			var max_h = player_h * MONSTER_MAX_VISUAL_RATIO
			if monster_h > max_h:
				var capped = max_h / m_info["size"].y
				monster_scale = Vector2(capped, capped)

		if actual_monster == monster_battler:
			# a) 默认怪物：直接使用常量位置
			m_sprite.scale = monster_scale
			if m_info["has_anim"] and m_info["size"].y > 0:
				m_sprite.offset = Vector2(
					0, -m_sprite.position.y - m_info["size"].y / 2.0 * monster_scale.y
				)
			actual_monster.position = Vector2(
				MONSTER_BATTLE_X * scale_factor,
				(MONSTER_BATTLE_Y + monster_y_offset) * scale_factor
			)
			_position_hud(actual_monster)
		else:
			# b) 动态怪物（如 Bone Knight、Boss 实例）
			if not (mid in _dynamic_monster_original_pos):
				_dynamic_monster_original_pos[mid] = actual_monster.global_position

			m_sprite.scale = monster_scale
			if m_info["has_anim"] and m_info["size"].y > 0:
				m_sprite.offset = Vector2(
					0, -m_sprite.position.y - m_info["size"].y / 2.0 * monster_scale.y
				)

			var orig_pos: Vector2 = _dynamic_monster_original_pos[mid]
			var parent_node = actual_monster.get_parent()
			var sprite_comp_x = -m_sprite.position.x
			if parent_node and parent_node != self:
				var parent_glob = parent_node.global_position
				actual_monster.position = Vector2(
					(orig_pos.x - parent_glob.x) * scale_factor + sprite_comp_x,
					(orig_pos.y - parent_glob.y + monster_y_offset) * scale_factor
				)
			else:
				actual_monster.position = Vector2(
					orig_pos.x * scale_factor + sprite_comp_x,
					(orig_pos.y + monster_y_offset) * scale_factor
				)
			print(
				"[fit] 动态怪物 pos=", actual_monster.position, " orig=", orig_pos, " sf=", scale_factor
			)
			_position_hud(actual_monster)


const MONSTERS_NO_FLIP := ["skull", "slime_king", "Bringer"]


func _auto_face_targets():
	# 玩家朝右（面向怪物方向）
	if is_instance_valid(player_battler) and player_battler.has_node("AnimatedSprite2D"):
		player_battler.get_node("AnimatedSprite2D").flip_h = false
	# 怪物朝左（面向玩家方向）
	if is_instance_valid(_current_monster) and _current_monster.has_node("AnimatedSprite2D"):
		var m_sprite = _current_monster.get_node("AnimatedSprite2D")
		var new_flip = _current_monster.monster_name not in MONSTERS_NO_FLIP

		# 保存原始 offset（首次调用时记录，用于翻转修正）
		if _monster_original_offset == Vector2.ZERO:
			_monster_original_offset = m_sprite.offset

		m_sprite.flip_h = new_flip
		# 记录原始 position.x（首次调用时），然后始终根据朝向设置 position.x
		if is_nan(_monster_original_sprite_pos_x):
			var boss_orig = _current_monster.get("_original_sprite_pos_x")
			_monster_original_sprite_pos_x = boss_orig if boss_orig != null else m_sprite.position.x
		# 每次调用都根据朝向重新设置 position.x
		if new_flip:
			m_sprite.position.x = -_monster_original_sprite_pos_x
		else:
			m_sprite.position.x = _monster_original_sprite_pos_x
		# 对于帧内水平不居中的特殊角色，调整 offset.x
		if _monster_original_offset.x != 0:
			if new_flip:
				var info = _get_sprite_info(m_sprite)
				if info["has_anim"]:
					m_sprite.offset.x = -(info["size"].x + _monster_original_offset.x)
			else:
				m_sprite.offset.x = _monster_original_offset.x
		# 确保 offset.y 始终保持脚对齐
		m_sprite.offset.y = _monster_original_offset.y


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
	await _wait_for_attack_done()
	BattleManager._after_player_attack()


func _on_skill2():
	print("→ 玩家点击了【技能2：重斩】 - 攻击动画后播放轻微震动")
	BattleManager.use_skill(2)
	var monster_alive = await _wait_for_attack_done()
	if not monster_alive:
		BattleManager._after_player_attack()
		return
	# 重斩：只加入轻微震动
	_tween_shake(_current_monster, 4.0, 0.25)
	_tween_shake(player_battler, 2.0, 0.2)
	await get_tree().create_timer(0.3).timeout
	BattleManager._after_player_attack()


func _on_skill3():
	_current_skill_id = 3
	print("→ 玩家点击了【技能3：破甲斩】")
	BattleManager.use_skill(3)
	var monster_alive = await _wait_for_attack_done()
	if not monster_alive:
		BattleManager._after_player_attack()
		return

	# 破甲斩：短距离弧形重劈 + 盔甲碎裂白光 + 金属冲击感
	_spawn_armor_break_slash()  # 短距离弧形大气刃重劈
	_tween_shake(_current_monster, 12.0, 0.35)  # 怪物厚重震动
	_tween_shake(player_battler, 4.0, 0.2)  # 玩家轻微震动

	await get_tree().create_timer(0.04).timeout
	_spawn_armor_shatter_flash()  # 盔甲碎裂白光

	await get_tree().create_timer(0.06).timeout
	_spawn_metal_sparks()  # 金属碎片飞散

	await get_tree().create_timer(0.3).timeout
	BattleManager._after_player_attack()


func _on_skill4():
	_current_skill_id = 4
	print("→ 玩家点击了【技能4：怒斩苍穹】 - 攻击动画后播放大招特效")
	BattleManager.use_skill(4)
	var monster_alive = await _wait_for_attack_done()
	if not monster_alive:
		BattleManager._after_player_attack()
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

	await get_tree().create_timer(0.5).timeout
	BattleManager._after_player_attack()


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
	var steps = int(duration / 0.04)
	for i in range(steps):
		var offset_x = randf_range(-intensity, intensity)
		var offset_y = randf_range(-intensity, intensity)
		tween.tween_property(target, "position", origin + Vector2(offset_x, offset_y), 0.04)
	# 最后复位
	tween.tween_property(target, "position", origin, 0.06)


# ===================== 特效：破甲图标 =====================
func _spawn_armor_break_icon():
	if _current_skill_id != 3:
		return
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
	if _current_skill_id != 3:
		return
	if not is_instance_valid(_current_monster) or not is_instance_valid(_fx_layer):
		return
	var center = _current_monster.global_position

	# 主气刃：短而厚重，冷灰金属色调
	var blade = _make_qi_blade(
		340, 48, 22, Color(0.5, 0.55, 0.65, 0.92), Color(0.78, 0.82, 0.90, 1.0), 120  # 外焰：铁灰蓝  # 内焰：冷银白
	)
	blade.position = center + Vector2(20, 10)
	blade.rotation = -0.3  # 轻微斜劈
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
		260, 28, 14, Color(0.55, 0.6, 0.72, 0.85), Color(0.82, 0.86, 0.94, 1.0), 118
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
	if _current_skill_id != 3:
		return
	if not is_instance_valid(_current_monster) or not is_instance_valid(_fx_layer):
		return
	var center = _current_monster.global_position
	var shield_size = 120.0

	# --- 圆形制式铁盾：哑光灰金属底色 + 盾沿加厚凸起包边 ---
	var shield = Panel.new()
	shield.name = "IronShield"
	var shield_style = StyleBoxFlat.new()
	shield_style.bg_color = Color(0.42, 0.45, 0.52, 0.92)  # 哑光灰金属底色
	shield_style.border_width_left = 10
	shield_style.border_width_right = 10
	shield_style.border_width_top = 10
	shield_style.border_width_bottom = 10
	shield_style.border_color = Color(0.28, 0.31, 0.38, 1.0)  # 盾沿深灰加厚包边
	shield_style.set_corner_radius_all(int(shield_size / 2))  # 正圆形
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
		crack.points = PackedVector2Array(
			[
				center,
				center + Vector2(cos(ang) * r * 0.5, sin(ang) * r * 0.5),
				center + Vector2(cos(ang) * r, sin(ang) * r),
			]
		)
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
		var frag_end = (
			center + Vector2(cos(frag_ang) * frag_dist, sin(frag_ang) * frag_dist) - frag.size * 0.5
		)

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
	if _current_skill_id != 3:
		return
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
	if _current_skill_id != 4:
		return
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
		tween.tween_interval(ring * 0.08)
		tween.set_parallel(true)
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
	if _current_skill_id != 4:
		return
	if not is_instance_valid(_current_monster) or not is_instance_valid(_fx_layer):
		return
	var center = _current_monster.global_position

	for i in range(3):
		var blade = _make_qi_blade(
			520 + i * 100,
			38 + i * 6,
			18 + i * 8,
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
	if _current_skill_id != 4:
		return
	if not is_instance_valid(_current_monster) or not is_instance_valid(_fx_layer):
		return
	var center = _current_monster.global_position

	for i in range(2):
		var ang = -PI * 0.25 + i * PI * 0.5
		var cross = _make_qi_blade(
			440,
			30,
			14,
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
func _make_qi_blade(
	length: float,
	max_width: float,
	curve_offset: float,
	outer_color: Color,
	inner_color: Color,
	z: int
) -> Node2D:
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
		var y = curve_offset * sin(t * PI)  # 中间拱起，两端平
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
	curve.add_point(Vector2(0.0, 0.0), 0, 1.5)  # 尖端：宽度 0
	curve.add_point(Vector2(0.15, 0.25), 0, 0)  # 加速变宽
	curve.add_point(Vector2(0.5, 1.0), 0, 0)  # 中心：最宽
	curve.add_point(Vector2(0.85, 0.25), 0, 0)  # 加速收窄
	curve.add_point(Vector2(1.0, 0.0), -1.5, 0)  # 尖端：宽度 0
	return curve


# ===================== 气刃颜色渐变：中心白热 → 边缘色 → 外焰色 =====================
func _make_blade_gradient(edge_color: Color, hot_color: Color) -> Gradient:
	var grad = Gradient.new()
	grad.add_point(0.0, edge_color)  # 尖端：边缘色
	grad.add_point(0.15, hot_color)  # 过渡：热色
	grad.add_point(0.5, Color.WHITE)  # 中心：白热
	grad.add_point(0.85, hot_color)  # 过渡：热色
	grad.add_point(1.0, edge_color)  # 尖端：边缘色
	return grad


# ===================== 怒斩苍穹：金/橙火焰流光 =====================
func _spawn_flame_streaks():
	if _current_skill_id != 4:
		return
	if not is_instance_valid(_current_monster) or not is_instance_valid(_fx_layer):
		return
	var center = _current_monster.global_position

	# 20道弧形火焰剑气：从怪物中心向外飞散
	for i in range(20):
		var angle = randf_range(-PI, PI)
		var dist = randf_range(60, 220)
		var hue = randf_range(0.07, 0.16)  # 金 → 橙 → 红

		var blade = _make_qi_blade(
			randf_range(80, 180),  # 长度：短剑气
			randf_range(8, 18),  # 宽度：窄
			randf_range(6, 20),  # 弧度
			Color.from_hsv(hue, 1.0, randf_range(0.6, 1.0), 0.85),  # 外焰
			Color.from_hsv(hue, 0.7, 1.0, 1.0),  # 内焰
			105
		)
		blade.rotation = angle  # 指向发射方向
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
	if _current_skill_id != 4:
		return
	if not is_instance_valid(_current_monster) or not is_instance_valid(_fx_layer):
		return
	var center = _current_monster.global_position

	# 从屏幕上方劈下的弧形气刃，带轨迹拖尾
	var blade = _make_qi_blade(
		600, 44, 30, Color(1.0, 0.9, 0.2, 0.92), Color(1.0, 0.95, 0.6, 1.0), 115
	)
	blade.rotation = 0.25  # 带一点倾斜
	blade.position = Vector2(center.x, center.y - 350)  # 从天空开始
	blade.modulate.a = 0.0
	_fx_layer.add_child(blade)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(blade, "modulate:a", 1.0, 0.04)
	tween.tween_property(blade, "position", center, 0.25)  # 劈到怪物身上
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
		trail.points = PackedVector2Array(
			[
				Vector2(center.x + i * 30 - 45, center.y - 350),
				Vector2(center.x + i * 20 - 30, center.y - 200),
				Vector2(center.x + i * 10 - 15, center.y),
			]
		)
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
	if _current_skill_id != 4:
		return
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
