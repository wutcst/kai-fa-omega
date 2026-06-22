extends CharacterBody2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var hud: Control
var hp_bar: ColorRect
var hp_fill: ColorRect
var mp_bar: ColorRect
var mp_fill: ColorRect
var hp_label: Label
var mp_label: Label

var is_turn: bool = false
var is_dead: bool = false
var in_attack: bool = false
var current_attack_target: Node2D = null
var _original_position: Vector2 = Vector2.ZERO  # 玩家在战斗场景的初始站位
var _original_sprite_offset: Vector2 = Vector2.ZERO  # 脚对齐后的原始 offset
const _APPROACH_SPEED: float = 1000.0  # 走向怪物的速度（像素/秒）
const _STAND_OFF_DIST: float = 80.0  # 与怪物保持的距离（不重合）

const MP_COST_HEAVY: int = 15
const MP_COST_ARMOR_PIERCE: int = 20
const MP_COST_ULTIMATE: int = 30


func get_current_hp() -> int:
	return GameData.current_hp


func set_current_hp(value: int):
	GameData.current_hp = max(0, int(min(float(value), float(get_max_hp()))))
	if hp_fill:
		var ratio = float(GameData.current_hp) / float(max(1, get_max_hp()))
		hp_fill.size.x = hp_bar.size.x * ratio
	if hp_label:
		hp_label.text = str(GameData.current_hp) + "/" + str(get_max_hp())


func get_max_mp() -> int:
	return GameData.max_mp


func get_current_mp() -> int:
	return GameData.current_mp


func set_current_mp(value: int):
	GameData.current_mp = max(0, int(min(float(value), float(get_max_mp()))))
	if mp_fill:
		var ratio = float(GameData.current_mp) / float(max(1, get_max_mp()))
		mp_fill.size.x = mp_bar.size.x * ratio
	if mp_label:
		mp_label.text = str(GameData.current_mp) + "/" + str(get_max_mp())


func get_attack() -> int:
	return GameData.get_total_attack()


func get_defense() -> int:
	return GameData.get_total_defense()


func get_max_hp() -> int:
	return GameData.get_total_max_hp()


func has_enough_mp(cost: int) -> bool:
	return GameData.current_mp >= cost


func consume_mp(cost: int):
	set_current_mp(GameData.current_mp - cost)


func _ready():
	_original_position = global_position
	# 应用脚对齐：自动计算 offset，让角色脚底对齐节点原点
	_apply_foot_alignment()
	create_bars()
	play_anim("idle")


# ============================================================
# 脚对齐：根据动画帧大小自动计算 offset，让角色脚底对齐节点原点
# 与 monster.gd 的对齐方式保持一致，确保战斗中玩家与怪物正确相对
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
	hud.name = "HUD"
	hud.position = Vector2(-60, -80)
	add_child(hud)

	hp_bar = ColorRect.new()
	hp_bar.name = "HPBarBg"
	hp_bar.size = Vector2(120, 14)
	hp_bar.position = Vector2(0, 0)
	hp_bar.color = Color(0.1, 0.1, 0.1)
	hud.add_child(hp_bar)

	hp_fill = ColorRect.new()
	hp_fill.name = "HPFill"
	hp_fill.size = Vector2(120, 14)
	hp_fill.position = Vector2(0, 0)
	hp_fill.color = Color(0.9, 0.15, 0.15)
	hud.add_child(hp_fill)

	hp_label = Label.new()
	hp_label.name = "HPLabel"
	hp_label.position = Vector2(0, -2)
	hp_label.size = Vector2(120, 14)
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_label.add_theme_font_size_override("font_size", 10)
	hp_label.add_theme_color_override("font_color", Color(1, 1, 1))
	hp_label.text = str(get_current_hp()) + "/" + str(get_max_hp())
	hud.add_child(hp_label)

	mp_bar = ColorRect.new()
	mp_bar.name = "MPBarBg"
	mp_bar.size = Vector2(120, 12)
	mp_bar.position = Vector2(0, 18)
	mp_bar.color = Color(0.1, 0.1, 0.1)
	hud.add_child(mp_bar)

	mp_fill = ColorRect.new()
	mp_fill.name = "MPFill"
	mp_fill.size = Vector2(120, 12)
	mp_fill.position = Vector2(0, 18)
	mp_fill.color = Color(0.2, 0.5, 0.9)
	hud.add_child(mp_fill)

	mp_label = Label.new()
	mp_label.name = "MPLabel"
	mp_label.position = Vector2(0, 16)
	mp_label.size = Vector2(120, 12)
	mp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mp_label.add_theme_font_size_override("font_size", 8)
	mp_label.add_theme_color_override("font_color", Color(1, 1, 1))
	mp_label.text = str(get_current_mp()) + "/" + str(get_max_mp())
	hud.add_child(mp_label)

	set_current_hp(get_current_hp())
	set_current_mp(get_current_mp())


# ============================================================
# 三种攻击 — 纯动画，无特效
# ============================================================
func attack_enemy(target: Node2D):
	if in_attack or is_dead:
		return
	await _execute_attack(target, "hit")


func heavy_attack_enemy(target: Node2D):
	if in_attack or is_dead:
		return
	await _execute_attack(target, "heavyhit")


func ultimate_attack_enemy(target: Node2D):
	if in_attack or is_dead:
		return
	await _execute_attack(target, "Sky Cleave")


func armor_pierce_attack_enemy(target: Node2D):
	if in_attack or is_dead:
		return
	await _execute_attack(target, "Armor Break Slash")


func _execute_attack(target: Node2D, action: String, armor_pierce: bool = false):
	in_attack = true
	current_attack_target = target

	# ------------------------------------------------------------
	# 阶段 1：走到怪物面前（不重合）
	# ------------------------------------------------------------
	if not is_instance_valid(target):
		in_attack = false
		return

	var tree = get_tree()
	if not tree:
		in_attack = false
		return

	var home_pos: Vector2 = _original_position  # global
	var enemy_glob: Vector2 = target.global_position
	# 计算玩家朝怪物的方向（只取水平方向，传统回合制只水平移动）
	var dir_to_enemy: Vector2 = Vector2(enemy_glob.x - global_position.x, 0)
	if dir_to_enemy.length() < 0.1:
		dir_to_enemy = Vector2.RIGHT
	var dir_norm: Vector2 = dir_to_enemy.normalized()
	# 目标位置：在怪物前方 _STAND_OFF_DIST 像素处，y 保持原值
	var target_glob: Vector2 = Vector2(
		enemy_glob.x - dir_norm.x * _STAND_OFF_DIST, global_position.y
	)

	# 播放 walk 动画
	play_anim("walk")
	var has_walk = animated_sprite.sprite_frames.has_animation(animated_sprite.animation)

	# 逐帧移动到 target_glob（global 坐标）
	await _move_to_global(target_glob)

	if not is_instance_valid(self) or not get_tree():
		in_attack = false
		current_attack_target = null
		return

	# ------------------------------------------------------------
	# 阶段 2：播放攻击动画
	# ------------------------------------------------------------
	play_anim(action)

	var attack_anim = action
	tree = get_tree()
	if tree and animated_sprite.sprite_frames.has_animation(attack_anim):
		var fc = animated_sprite.sprite_frames.get_frame_count(attack_anim)
		var spd = animated_sprite.sprite_frames.get_animation_speed(attack_anim)
		await tree.create_timer(fc / max(1.0, spd)).timeout
	elif tree:
		await tree.create_timer(0.4).timeout
	else:
		in_attack = false
		current_attack_target = null
		return

	# ------------------------------------------------------------
	# 阶段 3：造成伤害
	# ------------------------------------------------------------
	var enemy_died = false
	if is_instance_valid(current_attack_target):
		var defense_val = current_attack_target.get("defense")
		var defense: int = defense_val if defense_val is int else 0

		var multiplier: float = 1.0
		if action == "heavyhit":
			multiplier = 1.7
		elif action == "Sky Cleave":
			multiplier = 2.1

		var damage: int
		if armor_pierce:
			damage = max(1, int(get_attack() * 1.8))
			damage -= defense / 2
		else:
			damage = max(1, int(get_attack() * multiplier) - defense)

		current_attack_target.take_damage(damage)

		if not is_instance_valid(current_attack_target) or current_attack_target.is_dead:
			enemy_died = true

	# 等怪物 hurt 动画
	if not enemy_died and is_instance_valid(current_attack_target):
		if current_attack_target.has_node("AnimatedSprite2D") and not current_attack_target.is_dead:
			var sprite: AnimatedSprite2D = current_attack_target.get_node("AnimatedSprite2D")
			var mname = current_attack_target.monster_name
			var hurt_name = mname + "_hurt"
			var found_anim = ""
			if sprite and sprite.sprite_frames.has_animation(hurt_name):
				found_anim = hurt_name
			else:
				# 模糊匹配：查找以 "_hurt" 结尾的动画
				for a in sprite.sprite_frames.get_animation_names():
					if a.ends_with("_hurt"):
						found_anim = a
						break
			if found_anim != "" and sprite and sprite.sprite_frames:
				var hfc = sprite.sprite_frames.get_frame_count(found_anim)
				var hspd = sprite.sprite_frames.get_animation_speed(found_anim)
				tree = get_tree()
				if tree:
					var hd = hfc / max(1.0, hspd)
					hd = min(hd, 0.6)
					await tree.create_timer(hd).timeout

	# ------------------------------------------------------------
	# 阶段 4：走回初始位置（敌人没死才走回去
	# ------------------------------------------------------------
	if not is_instance_valid(self) or not get_tree():
		in_attack = false
		current_attack_target = null
		return

	if not enemy_died:
		if has_walk:
			play_anim("walk")
		await _move_to_global(home_pos)
		if not is_instance_valid(self) or not get_tree():
			in_attack = false
			current_attack_target = null
			return

	current_attack_target = null
	in_attack = false

	if enemy_died:
		return

	play_anim("idle")


# 把玩家水平移动到目标 global 位置（匀速
# 使用 get_process_delta_time()（Node 的方法），不依赖 SceneTree 的错误 API
func _move_to_global(target_glob: Vector2):
	var tree = get_tree()
	if not tree:
		return
	var start_glob: Vector2 = global_position
	var dx_total: float = target_glob.x - start_glob.x
	if abs(dx_total) < 1.0:
		global_position = Vector2(target_glob.x, start_glob.y)
		return
	# 需要多少秒走完
	var duration: float = abs(dx_total) / _APPROACH_SPEED
	var elapsed: float = 0.0
	while elapsed < duration and is_instance_valid(self) and get_tree():
		elapsed += get_process_delta_time()
		var k: float = clamp(elapsed / duration, 0.0, 1.0)
		global_position = Vector2(start_glob.x + dx_total * k, start_glob.y)
		await tree.process_frame
	# 保险：对齐到目标
	if is_instance_valid(self):
		global_position = Vector2(target_glob.x, start_glob.y)


func take_damage(damage: int):
	if is_dead:
		return
	set_current_hp(get_current_hp() - damage)
	if get_current_hp() <= 0:
		is_dead = true
		play_anim("death")
	else:
		play_anim("hurt")


func play_anim(action_name: String):
	if is_dead and action_name != "death":
		return
	if animated_sprite.sprite_frames.has_animation(action_name):
		animated_sprite.play(action_name)


func get_battle_crit() -> int:
	return GameData.crit
