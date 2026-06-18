
extends Node2D

# ============================================================
# 战斗场景的设计分辨率（场景文件中的原始坐标基准）
# ============================================================
const DESIGN_WIDTH = 1152.0
const DESIGN_HEIGHT = 648.0

# 全局战斗缩放：统一放缩玩家和怪物，保持相对比例
const GLOBAL_SCALE = 1.5

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

func _position_hud(character: Node2D) -> void:
	var hud = character.get_node_or_null("HUD")
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
	# 额外空隙（10px）让血条与精灵之间有间隔
	var gap: float = 10.0
	# 血条完全放在精灵顶部之上，不遮挡人物
	hud.position.y = visual_top - hud_height - gap
	# X 坐标：根据 HUD 内最大元素宽度自动居中
	var hud_width: float = 0.0
	for child in hud.get_children():
		if child is ColorRect or child is Label:
			hud_width = max(hud_width, child.size.x)
	hud.position.x = -hud_width / 2.0

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
var _original_player_pos: Vector2 = Vector2.ZERO
var _original_player_sprite_scale: Vector2 = Vector2.ONE
var _original_monster_pos: Vector2 = Vector2.ZERO      # 默认怪物的原始位置
var _original_monster_sprite_scale: Vector2 = Vector2.ONE
# 当前怪物自己的原始 AnimatedSprite2D scale（由 _setup_monster_battler 设置，不同于默认怪物）
var _custom_monster_sprite_scale: Vector2 = Vector2.ZERO
# 动态怪物专用：记录每个动态怪物的原始 AnimatedSprite2D scale 和 global_position
var _dynamic_monster_original_sprite_scale: Dictionary = {}  # key: instance_id -> Vector2
var _dynamic_monster_original_pos: Dictionary = {}        # key: instance_id -> Vector2

# 记录初始位置（用于震动后复位）
var _player_origin: Vector2 = Vector2.ZERO
var _monster_origin: Vector2 = Vector2.ZERO
var _camera_origin: Vector2 = Vector2.ZERO
# 怪物原始 offset（用于翻转时修正位置，如 skull 帧内角色不居中）
var _monster_original_offset: Vector2 = Vector2.ZERO

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

	# ============================================================
	# 【重要】在任何修改前记录原始状态
	# ============================================================
	if bg_sprite:
		_original_bg_scale = bg_sprite.scale
	if is_instance_valid(player_battler):
		_original_player_pos = player_battler.position
		if player_battler.has_node("AnimatedSprite2D"):
			var ps = player_battler.get_node("AnimatedSprite2D")
			_original_player_sprite_scale = ps.scale
	if is_instance_valid(monster_battler):
		_original_monster_pos = monster_battler.position
		if monster_battler.has_node("AnimatedSprite2D"):
			var ms = monster_battler.get_node("AnimatedSprite2D")
			_original_monster_sprite_scale = ms.scale

	_update_skill_buttons()
	combat_ui.refresh_skill_locks()
	combat_ui.update_exp_bar()
	_play_bgm()

	# 初始适配
	_fit_background()

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

	# 自动设置角色朝向
	_auto_face_targets()

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
	if is_instance_valid(_current_monster):
		_monster_origin = _current_monster.position

# ============================================================
# 对外接口：BattleManager 设置完怪物后调用，让动态创建的怪物也被缩放
# ============================================================
func refit():
	print("[refit] 被调用！_current_monster=", _current_monster.name if is_instance_valid(_current_monster) else "无效")
	# BattleManager 在 _on_scene_change 中已经把玩家/怪物的 AnimatedSprite2D scale 改为外面地图的值
	# 这里重新保存，确保 _fit_background 用外面地图的实际相对比例
	if is_instance_valid(player_battler) and player_battler.has_node("AnimatedSprite2D"):
		var ps = player_battler.get_node("AnimatedSprite2D")
		_original_player_sprite_scale = ps.scale
	if is_instance_valid(monster_battler) and monster_battler.has_node("AnimatedSprite2D"):
		var ms = monster_battler.get_node("AnimatedSprite2D")
		_original_monster_sprite_scale = ms.scale
	_fit_background()
	_auto_face_targets()
	if is_instance_valid(player_battler):
		_player_origin = player_battler.position
	if is_instance_valid(_current_monster):
		_monster_origin = _current_monster.position

func get_original_monster_pos() -> Vector2:
	return _original_monster_pos

func set_custom_monster_sprite_scale(s: Vector2):
	_custom_monster_sprite_scale = s

func reset_monster_offset():
	_monster_original_offset = Vector2.ZERO

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
	# 2. 玩家：AnimatedSprite2D 放大 + 位置按比例移动
	# ============================================================
	if is_instance_valid(player_battler):
		# 位置按比例缩放（从原始设计坐标映射到新窗口大小）
		player_battler.position = _original_player_pos * scale_factor

	# AnimatedSprite2D：用原始scale统一放大，保持与外面地图相同的相对比例
		if player_battler.has_node("AnimatedSprite2D"):
			var p_sprite = player_battler.get_node("AnimatedSprite2D")
			p_sprite.scale = _original_player_sprite_scale * scale_factor * GLOBAL_SCALE

		# 血条位置：根据精灵实际渲染高度，放在头顶上方
		_position_hud(player_battler)

	# ============================================================
	# 3. 怪物：使用 _current_monster 动态获取当前实际战斗的怪物
	# ============================================================
	var actual_monster = _current_monster
	if is_instance_valid(actual_monster) and actual_monster.has_node("AnimatedSprite2D"):
		var m_sprite = actual_monster.get_node("AnimatedSprite2D")
		var mid = actual_monster.get_instance_id()

		if actual_monster == monster_battler:
			# a) 默认怪物：使用保存的原始 AnimatedSprite2D scale + 位置
			# 如果当前怪物有自己的原始 scale（如 slime 的 (1,1)），优先使用它
			var base_scale = _custom_monster_sprite_scale if _custom_monster_sprite_scale != Vector2.ZERO else _original_monster_sprite_scale
			m_sprite.scale = base_scale * scale_factor * GLOBAL_SCALE
			# Y 对齐玩家，确保脚底在同一水平线上
			var player_y = _original_player_pos.y * scale_factor
			actual_monster.position = Vector2(_original_monster_pos.x * scale_factor, player_y)
			# 血条位置：根据精灵实际渲染高度，放在头顶上方
			_position_hud(actual_monster)
		else:
			# b) 动态怪物（如 Bone Knight）：
			#    - 第一次遇到时记录原始 AnimatedSprite2D scale 和 global_position
			#    - 之后每次用自己的原始值重新计算（避免叠加缩放）
			if not (mid in _dynamic_monster_original_sprite_scale):
				_dynamic_monster_original_sprite_scale[mid] = m_sprite.scale
			if not (mid in _dynamic_monster_original_pos):
				_dynamic_monster_original_pos[mid] = actual_monster.global_position

			# 用自己的原始 AnimatedSprite2D scale 来缩放（而不是默认怪物的）
			var orig_sprite_scale: Vector2 = _dynamic_monster_original_sprite_scale[mid]
			m_sprite.scale = orig_sprite_scale * scale_factor * GLOBAL_SCALE

			# 位置：x 按原始位置缩放，y 对齐玩家（使用 local position 保持一致性）
			var orig_pos: Vector2 = _dynamic_monster_original_pos[mid]
			var player_y_scaled = _original_player_pos.y * scale_factor
			# 如果父节点有偏移，将 global_x 转为 local 坐标，或直接用 combat_manager 的相对位置
			var parent_node = actual_monster.get_parent()
			if parent_node and parent_node != self:
				# 有中间父节点，用 local position 更安全
				var parent_glob = parent_node.global_position
				actual_monster.position = Vector2(
					(orig_pos.x - parent_glob.x) * scale_factor,
					(_original_player_pos.y) * scale_factor
				)
			else:
				actual_monster.position = Vector2(orig_pos.x * scale_factor, player_y_scaled)
			# 血条位置
			_position_hud(actual_monster)

const MONSTERS_NO_FLIP := ["skull", "slime_king"]

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
	print("→ 玩家点击了【技能3：破甲斩】 - 攻击动画后播放震动 + 破甲图标")
	BattleManager.use_skill(3)
	var monster_alive = await _wait_for_attack_done()
	if not monster_alive:
		return
	# 破甲斩：震动特效 + 破甲图标
	_tween_shake(_current_monster, 8.0, 0.4)
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
	_tween_shake(_current_monster, 15.0, 0.7)
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
