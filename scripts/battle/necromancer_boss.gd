extends CharacterBody2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

@export var monster_name: String = "necromancer"
@export var max_hp: int = 260
@export var attack: int = 20
@export var defense: int = 7
@export var exp_reward: int = 200
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
	create_bars()
	# 信号已在 necromancer.tscn 中通过编辑器连接，此处不再重复连接
	play_anim("idle")

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
	var full_name = "Necromancer_" + anim
	if animated_sprite and animated_sprite.sprite_frames.has_animation(full_name):
		animated_sprite.play(full_name)

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

	if get_world_2d() != null:
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

func execute_turn():
	print("→ execute_turn() 被调用, turn_count=", turn_count, " is_dead=", is_dead)
	if is_dead:
		return

	turn_count += 1

	var has_minion = false
	for minion in minions:
		if is_instance_valid(minion) and not minion.is_dead:
			has_minion = true
			break

	if not has_minion:
		print("→ 无随从，召唤随从")
		await summon_minion()
		return

	if current_hp < max_hp * 0.5:
		print("→ HP低于50%，治疗")
		await heal_skill()
		return

	print("→ 执行攻击！")
	await attack_player()

func summon_minion():
	play_anim("summon")
	await _wait_anim("Necromancer_summon")

	var minion = minion_scene.instantiate()
	minion.position = Vector2(-60, 30)
	add_child(minion)
	minions.append(minion)
	print("→ 亡灵法师召唤了一个随从！")

	play_anim("idle")

func heal_skill():
	play_anim("skill")
	await _wait_anim("Necromancer_skill")

	var heal_amount = int(max_hp * 0.15)
	current_hp = min(current_hp + heal_amount, max_hp)
	update_hp_bar()
	print("→ 亡灵法师使用黑暗治愈，恢复了 ", heal_amount, " 点生命！")

	play_anim("idle")

func attack_player():
	print("→ attack_player() 被调用！")
	play_anim("attack")
	_spawn_dark_arc_wave()           # 黑色弧形波飞向玩家
	await _wait_anim("Necromancer_attack")

	var pb = BattleManager.player_battler
	if pb and not pb.is_dead and is_instance_valid(pb):
		var def_val = pb.get_defense() if pb.has_method("get_defense") else 0
		var damage = max(1, attack - def_val)
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

		if not pb.is_dead:
			pb.play_anim("idle")

	play_anim("idle")

func _wait_anim(anim_name: String):
	var duration: float = 0.5
	if animated_sprite.sprite_frames.has_animation(anim_name):
		var fc = animated_sprite.sprite_frames.get_frame_count(anim_name)
		var spd = max(1.0, animated_sprite.sprite_frames.get_animation_speed(anim_name))
		duration = fc / spd
	await get_tree().create_timer(duration).timeout

func exit_battle():
	if is_dead:
		return
	in_battle = false
	is_attacking = false
	attack_timer = 0
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
