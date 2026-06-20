extends CharacterBody2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

@export var monster_name: String = "necromancer"
@export var max_hp: int = 263
@export var attack: int = 28
@export var defense: int = 10
@export var exp_reward: int = 300
@export var enemy_scene_path: String = "res://scenes/entities/necromancer.tscn"
@export var is_boss: bool = true

@export var speed: float = 70.0
@export var chase_range: float = 250.0
@export var attack_range: float = 45.0
@export var attack_cd: float = 1.0

var current_hp: int
var is_dead: bool = false
var in_battle: bool = false
var is_turn: bool = false
var player: Node2D = null
var attack_timer: float = 0.0
var is_attacking: bool = false
var spawn_position: Vector2 = Vector2.ZERO
var _original_sprite_offset: Vector2 = Vector2.ZERO   # 脚对齐后的原始 offset

var minions: Array = []
var minion_scene: PackedScene = preload("res://scenes/battle/summoned_minion.tscn")
var max_minions: int = 1
var turn_count: int = 0

signal enter_battle(monster)
signal monster_died(monster)

var hud: Control
var hp_bar: ColorRect
var hp_fill: ColorRect
var hp_label: Label

func _ready():
	add_to_group("enemy")
	current_hp = max_hp
	spawn_position = global_position
	_apply_foot_alignment()
	create_bars()
	# 信号已在 necromancer.tscn 中通过编辑器连接，此处不再重复连接

	# 检查是否已被击败（地图重载后自动清除）
	for pos in GameData.defeated_boss_positions:
		if pos is Vector2:
			if spawn_position.distance_to(pos) < chase_range:
				print("→ 首领已被击败，自动清除：", monster_name, " at ", spawn_position)
				is_dead = true
				queue_free()
				return

	play_anim("idle")

# ============================================================
# 脚对齐：根据动画帧大小自动计算 offset，让角色脚底对齐节点原点
# ============================================================
func _get_first_frame_size() -> Vector2:
	if not animated_sprite or not animated_sprite.sprite_frames:
		return Vector2.ZERO
	var anims = animated_sprite.sprite_frames.get_animation_names()
	if anims.size() == 0:
		return Vector2.ZERO
	if animated_sprite.sprite_frames.get_frame_count(anims[0]) == 0:
		return Vector2.ZERO
	var tex = animated_sprite.sprite_frames.get_frame_texture(anims[0], 0)
	if not tex:
		return Vector2.ZERO
	return tex.get_size()

func _apply_foot_alignment():
	var frame_size = _get_first_frame_size()
	if frame_size == Vector2.ZERO:
		_original_sprite_offset = animated_sprite.offset
		return
	animated_sprite.position = Vector2(0, 0)
	var current_scale = animated_sprite.scale.y if animated_sprite else 1.0
	animated_sprite.offset = Vector2(0, -frame_size.y / 2.0 * current_scale)
	_original_sprite_offset = animated_sprite.offset

func create_bars():
	hud = Control.new()
	hud.name = "BossHUD"
	hud.position = Vector2(-60, -90)
	add_child(hud)

	hp_bar = ColorRect.new()
	hp_bar.name = "HPBarBg"
	hp_bar.size = Vector2(120, 16)
	hp_bar.position = Vector2(0, 0)
	hp_bar.color = Color(0.1, 0.1, 0.1)
	hud.add_child(hp_bar)

	hp_fill = ColorRect.new()
	hp_fill.name = "HPFill"
	hp_fill.size = Vector2(120, 16)
	hp_fill.position = Vector2(0, 0)
	hp_fill.color = Color(0.85, 0.1, 0.5)
	hud.add_child(hp_fill)

	hp_label = Label.new()
	hp_label.name = "HPLabel"
	hp_label.position = Vector2(0, -2)
	hp_label.size = Vector2(120, 16)
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_label.add_theme_font_size_override("font_size", 10)
	hp_label.add_theme_color_override("font_color", Color(1, 1, 1))
	hp_label.text = str(current_hp) + "/" + str(max_hp)
	hud.add_child(hp_label)

	var name_label = Label.new()
	name_label.name = "BossName"
	name_label.position = Vector2(0, -18)
	name_label.size = Vector2(120, 16)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.add_theme_color_override("font_color", Color(1, 0.4, 0.2))
	name_label.text = "亡灵法师"
	hud.add_child(name_label)

func update_hp_bar():
	if hp_fill:
		var ratio = float(current_hp) / float(max_hp)
		hp_fill.size.x = hp_bar.size.x * ratio
	if hp_label:
		hp_label.text = str(current_hp) + "/" + str(max_hp)

func play_anim(anim: String):
	if is_dead and anim != "death":
		return
	if not animated_sprite or not animated_sprite.sprite_frames:
		return
	if animated_sprite.is_playing():
		var current_anim: String = animated_sprite.animation
		if current_anim.ends_with("_attack") or current_anim.ends_with("_hurt") or current_anim.ends_with("_summon") or current_anim.ends_with("_skill"):
			if anim == "walk" or anim == "idle":
				return
	var full_name = "Necromancer_" + anim
	if animated_sprite.sprite_frames.has_animation(full_name):
		animated_sprite.play(full_name)
		return
	# 模糊匹配：以 "_" + anim 结尾的动画
	var target = "_" + anim
	for a in animated_sprite.sprite_frames.get_animation_names():
		if a.ends_with(target):
			animated_sprite.play(a)
			return

func _on_anim_finished():
	if is_dead:
		return
	if animated_sprite.animation.ends_with("_attack"):
		is_attacking = false
		attack_timer = 0
		play_anim("idle")
	if animated_sprite.animation.ends_with("_hurt"):
		play_anim("idle")

func _physics_process(_delta: float) -> void:
	if not is_inside_tree() or get_world_2d() == null:
		return
	if is_dead or in_battle:
		velocity = Vector2.ZERO
		is_attacking = false
		attack_timer = 0
		if get_world_2d() != null:
			move_and_slide()
		return

	if is_attacking:
		velocity = Vector2.ZERO
		if get_world_2d() != null:
			move_and_slide()
		return

	if attack_timer > 0:
		attack_timer -= _delta
		if attack_timer <= 0:
			is_attacking = false

	if player == null or not is_instance_valid(player):
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player = players[0]
		else:
			velocity = Vector2.ZERO
			play_anim("idle")
			if get_world_2d() != null:
				move_and_slide()
			return

	var dis = global_position.distance_to(player.global_position)

	if dis > chase_range:
		velocity = Vector2.ZERO
		play_anim("idle")
	elif dis > attack_range:
		var dir = (player.global_position - global_position).normalized()
		animated_sprite.flip_h = dir.x < 0
		velocity = dir * speed
		play_anim("idle")
	else:
		velocity = Vector2.ZERO
		if attack_timer <= 0 and not is_attacking:
			perform_attack()

	if is_inside_tree():
		move_and_slide()

func perform_attack():
	if is_dead or is_attacking or in_battle:
		return
	in_battle = true
	is_attacking = true
	attack_timer = attack_cd
	play_anim("attack")
	emit_signal("enter_battle", self)

func take_damage(dmg: int):
	if is_dead:
		return

	for minion in minions:
		if is_instance_valid(minion) and not minion.is_dead:
			minion.take_damage(dmg)
			print("→ 随从替亡灵法师抵挡了 ", dmg, " 点伤害！")
			return

	current_hp -= dmg
	update_hp_bar()

	if current_hp <= 0:
		current_hp = 0
		is_dead = true
		emit_signal("monster_died", self)
		die()
	else:
		play_anim("hurt")

func die():
	play_anim("death")
	for minion in minions:
		if is_instance_valid(minion):
			minion.queue_free()
	minions.clear()

# ============================================================
# 3 回合 1 个周期的动作循环：
#   回合 1：召唤随从 (Necromancer_summon)
#   回合 2：普通攻击 (Necromancer_attack)
#   回合 3：技能攻击 (Necromancer_skill) → 固定对玩家造成 40 点伤害
# ============================================================
func execute_turn():
	print("→ execute_turn() 被调用, turn_count=", turn_count, " is_dead=", is_dead)
	if is_dead:
		return

	turn_count += 1

	# 根据 turn_count 实现 3 回合循环
	# turn_count % 3 == 1  → 第 1 回合：召唤
	# turn_count % 3 == 2  → 第 2 回合：普通攻击
	# turn_count % 3 == 0  → 第 3 回合：技能攻击
	var cycle_step = turn_count % 3

	if cycle_step == 1:
		print("→ [周期 回合1] 召唤随从！")
		await summon_minion()
		return
	elif cycle_step == 2:
		print("→ [周期 回合2] 普通攻击！")
		await attack_player()
		return
	else:  # cycle_step == 0
		print("→ [周期 回合3] 技能攻击！")
		await skill_attack()
		return

func summon_minion():
	play_anim("summon")
	await _wait_anim("Necromancer_summon")

	# 清理已死亡的旧随从
	for i in range(minions.size() - 1, -1, -1):
		if not is_instance_valid(minions[i]) or minions[i].is_dead:
			minions.remove_at(i)

	# 限制随从数量不超过 max_minions
	if minions.size() < max_minions:
		var minion = minion_scene.instantiate()
		minion.position = Vector2(-80, 0)
		add_child(minion)
		# 缩放随从的精灵，使其与战斗场景匹配
		if minion.has_node("AnimatedSprite2D"):
			var m_sprite = minion.get_node("AnimatedSprite2D")
			m_sprite.scale = Vector2(3.5, 3.5)
		minions.append(minion)
		print("→ 亡灵法师召唤了一个随从！")
	else:
		print("→ 随从数量已达上限 (", max_minions, ")，跳过召唤")

	play_anim("idle")

# ============================================================
# Necromancer_skill：技能攻击
#   - 播放 Necromancer_skill 动画
#   - 固定对玩家造成 40 点伤害
# ============================================================
func skill_attack():
	print("→ skill_attack() 被调用！释放技能攻击")

	var pb = BattleManager.player_battler

	# 阶段 1：播放技能动画
	play_anim("skill")
	_spawn_dark_arc_wave()  # 释放黑色弧形波特效
	await _wait_anim("Necromancer_skill")

	# 阶段 2：固定造成 40 点伤害
	if is_instance_valid(pb) and not pb.is_dead:
		var skill_damage: int = 40
		pb.take_damage(skill_damage)
		print("→ 亡灵法师释放技能，固定造成 ", skill_damage, " 点伤害！")

		# 等待玩家 hurt 动画播放完毕
		var hurt_duration: float = 0.3
		if pb.has_node("AnimatedSprite2D"):
			var psprite: AnimatedSprite2D = pb.get_node("AnimatedSprite2D")
			var hurt_anim = "hurt"
			if psprite.sprite_frames.has_animation(hurt_anim):
				var hfc = psprite.sprite_frames.get_frame_count(hurt_anim)
				var hspd = max(1.0, psprite.sprite_frames.get_animation_speed(hurt_anim))
				hurt_duration = hfc / hspd
		await get_tree().create_timer(hurt_duration).timeout

		if is_instance_valid(pb) and not pb.is_dead:
			pb.play_anim("idle")

	play_anim("idle")

func attack_player():
	print("→ attack_player() 被调用！")

	var enemy_home: Vector2 = global_position
	var pb = BattleManager.player_battler
	var target_glob: Vector2 = enemy_home

	if is_instance_valid(pb):
		target_glob = Vector2(
			pb.global_position.x - (-150.0),
			enemy_home.y
		)

	# 阶段2：播放攻击动画
	play_anim("attack")
	_spawn_dark_arc_wave()           # 黑色弧形波飞向玩家
	await _wait_anim("Necromancer_attack")

	# 阶段3：造成伤害 + 玩家 hurt 动画
	if is_instance_valid(pb) and not pb.is_dead:
		var def_val = pb.get_defense() if pb.has_method("get_defense") else 0
		var damage = max(1, attack - def_val / 2)
		pb.take_damage(damage)
		print("→ 亡灵法师攻击玩家，造成 ", damage, " 点伤害！")

		var hurt_duration: float = 0.3
		if pb.has_node("AnimatedSprite2D"):
			var psprite: AnimatedSprite2D = pb.get_node("AnimatedSprite2D")
			var hurt_anim = "hurt"
			if psprite.sprite_frames.has_animation(hurt_anim):
				var hfc = psprite.sprite_frames.get_frame_count(hurt_anim)
				var hspd = max(1.0, psprite.sprite_frames.get_animation_speed(hurt_anim))
				hurt_duration = hfc / hspd
		await get_tree().create_timer(hurt_duration).timeout

		if is_instance_valid(pb) and not pb.is_dead:
			pb.play_anim("idle")

	play_anim("idle")

func _wait_anim(anim_name: String):
	var duration: float = 0.5
	if animated_sprite.sprite_frames.has_animation(anim_name):
		var fc = animated_sprite.sprite_frames.get_frame_count(anim_name)
		var spd = max(1.0, animated_sprite.sprite_frames.get_animation_speed(anim_name))
		duration = fc / spd
	duration = min(duration, 2.0)
	var should_continue := true
	var max_time := duration + 0.1
	var elapsed := 0.0
	while should_continue and elapsed < max_time:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		if not is_instance_valid(animated_sprite):
			break
		if not animated_sprite.is_playing() and animated_sprite.frame >= animated_sprite.sprite_frames.get_frame_count(animated_sprite.animation) - 1:
			should_continue = false

func exit_battle():
	if is_dead:
		return
	in_battle = false
	is_attacking = false
	attack_timer = 0
	# 战斗结束后重置回合计数，下次战斗从第 1 回合开始
	turn_count = 0
	# 清理所有残留的随从
	for minion in minions:
		if is_instance_valid(minion):
			minion.queue_free()
	minions.clear()
	play_anim("idle")

# ===================== 亡灵法师攻击：全屏蓝紫弧形波 =====================
func _spawn_dark_arc_wave():
	# 战斗场景中玩家是 BattleManager.player_battler
	var target_node = BattleManager.player_battler
	if not is_instance_valid(target_node):
		target_node = player
	if not is_instance_valid(target_node):
		return

	var start = global_position
	var target = target_node.global_position
	var angle = (target - start).angle()
	var dist = start.distance_to(target)
	var root = get_tree().current_scene
	var viewport_size = get_viewport().get_visible_rect().size

	# === 第一层：CanvasLayer 全屏光幕背景 ===
	var canvas = CanvasLayer.new()
	canvas.name = "WaveCanvas"
	canvas.layer = 100
	root.add_child(canvas)

	var overlay = ColorRect.new()
	overlay.name = "WaveBg"
	overlay.color = Color(0.08, 0.12, 0.4, 0.3)
	overlay.size = viewport_size
	canvas.add_child(overlay)

	# === 第二层：Node2D 弧形波（世界空间） ===
	var wave = Node2D.new()
	wave.name = "DarkArcWave"
	wave.z_index = 200
	wave.z_as_relative = false
	wave.global_position = start
	wave.scale = Vector2(0.15, 0.15)
	wave.rotation = angle
	root.add_child(wave)

	var screen_w = viewport_size.x * 1.5
	var screen_h = viewport_size.y * 1.2

	# --- 外层：蓝紫宽波 ---
	var outer = Line2D.new()
	outer.width = screen_h * 0.55
	outer.default_color = Color(0.12, 0.18, 0.65, 0.85)
	outer.begin_cap_mode = Line2D.LINE_CAP_ROUND
	outer.end_cap_mode = Line2D.LINE_CAP_ROUND

	# --- 中层：亮蓝紫波 ---
	var mid = Line2D.new()
	mid.width = screen_h * 0.25
	mid.default_color = Color(0.25, 0.35, 0.85, 0.9)
	mid.begin_cap_mode = Line2D.LINE_CAP_ROUND
	mid.end_cap_mode = Line2D.LINE_CAP_ROUND

	# --- 核心：白蓝线 ---
	var core = Line2D.new()
	core.width = screen_h * 0.06
	core.default_color = Color(0.55, 0.65, 1.0, 0.95)
	core.begin_cap_mode = Line2D.LINE_CAP_ROUND
	core.end_cap_mode = Line2D.LINE_CAP_ROUND

	# 弧形轨迹：跨度整个屏幕，大幅拱起
	var pts = PackedVector2Array()
	var steps = 16
	var half_w = screen_w / 2.0
	var arc_h = screen_h * 0.7
	for s in range(steps + 1):
		var t = float(s) / steps
		var x = lerp(-half_w, half_w, t)
		var y = -arc_h * sin(t * PI)
		pts.append(Vector2(x, y))

	outer.points = pts
	mid.points = pts
	core.points = pts

	wave.add_child(outer)
	wave.add_child(mid)
	wave.add_child(core)

	# 动画：光幕淡出 + 波膨胀飞向玩家
	var tween = get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(overlay, "color:a", 0.0, 0.8)
	tween.tween_property(wave, "modulate:a", 0.95, 0.08)
	tween.tween_property(wave, "scale", Vector2(2.0, 2.0), 0.3)
	tween.tween_property(wave, "global_position", target, 0.4)
	tween.chain().tween_property(wave, "modulate:a", 0.0, 0.5)
	tween.tween_callback(canvas.queue_free)
	tween.tween_callback(wave.queue_free)
