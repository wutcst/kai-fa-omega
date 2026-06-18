extends CharacterBody2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

@export var monster_name: String = "slime"
@export var max_hp: int = 60
@export var attack: int = 12
@export var defense: int = 3
@export var speed: float = 70.0
@export var chase_range: float = 200.0
@export var attack_range: float = 40.0
@export var attack_cd: float = 1.0
@export var exp_reward: int = 20
@export var enemy_scene_path: String = ""
@export var is_boss: bool = false
@export var display_name: String = ""

var current_hp: int
var is_dead: bool = false
var player: Node2D = null
var attack_timer: float = 0.0
var is_attacking: bool = false
var in_battle: bool = false

@warning_ignore("unused_signal")
signal enter_battle(monster)
@warning_ignore("unused_signal")
signal monster_died(monster)

var spawn_position: Vector2
var _original_sprite_offset: Vector2 = Vector2.ZERO

# Boss HUD（战斗中 Boss 用）
var hud: Control
var hp_bar: ColorRect
var hp_fill: ColorRect
var hp_label: Label

func _ready():
	current_hp = max_hp
	spawn_position = global_position
	
	# 应用脚对齐：自动计算 offset，让角色脚底对齐节点原点
	_apply_foot_alignment()
	
	# 战斗中 Boss 实例：创建 HUD，不检查击败记录
	if in_battle and is_boss:
		_create_boss_hud()
	else:
		# 检查是否已被击败（地图重载后自动清除）
		for pos in GameData.defeated_monster_positions:
			if pos is Vector2:
				if spawn_position.distance_to(pos) < chase_range:
					print("→ 怪物已被击败，自动清除：", monster_name, " at ", spawn_position)
					# 立即标记死亡并禁用碰撞，防止当前帧内再次触发战斗
					is_dead = true
					if collision_shape:
						collision_shape.disabled = true
					queue_free()
					return
	
	play_anim("idle")
	
	connect_signals()

# ============================================================
# 脚对齐：根据动画帧大小自动计算 offset，让角色脚底对齐节点原点
# 解决不同怪物动画帧大小不同导致的显示不对齐问题
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
	animated_sprite.position = Vector2(animated_sprite.position.x, 0)
	# 脚对齐：在 Godot 4 中，AnimatedSprite2D 将帧渲染在节点位置+offset处，帧为居中绘制
	# 帧底部 = offset.y + frame_height/2，想要帧底部（角色脚底）在节点原点 → offset.y = -frame_height/2
	animated_sprite.offset = Vector2(0, -frame_size.y / 2.0)
	_original_sprite_offset = animated_sprite.offset

func safe_move_and_slide():
	if is_inside_tree() and is_instance_valid(collision_shape) and not collision_shape.disabled:
		move_and_slide()

func connect_signals():
	if animated_sprite.animation_finished.is_connected(_on_animated_sprite_2d_animation_finished):
		return
	animated_sprite.animation_finished.connect(_on_animated_sprite_2d_animation_finished)

func _draw():
	draw_circle(Vector2.ZERO, chase_range, Color(1, 0, 0, 0.3))
	draw_circle(Vector2.ZERO, attack_range, Color(0, 1, 0, 0.3))

func _set_flip_h(new_flip: bool):
	if animated_sprite.flip_h == new_flip:
		return
	animated_sprite.flip_h = new_flip
	# 脚对齐后 offset.x = 0（角色在帧内水平居中），flip_h 会自动镜像翻转
	# 只需要保持 offset.y 不变（脚底仍在节点原点），offset.x 始终为 0
	# 对于少数在帧内不居中的特殊角色，保留原有翻转修正逻辑
	if _original_sprite_offset.x != 0:
		if new_flip:
			var tex = animated_sprite.sprite_frames.get_frame_texture(
				animated_sprite.sprite_frames.get_animation_names()[0], 0)
			if tex:
				animated_sprite.offset.x = -(tex.get_size().x + _original_sprite_offset.x)
		else:
			animated_sprite.offset.x = _original_sprite_offset.x

func _physics_process(_delta: float) -> void:
	if not is_inside_tree():
		return
	if is_dead || in_battle:
		velocity = Vector2.ZERO
		is_attacking = false
		attack_timer = 0
		safe_move_and_slide()
		return

	# 攻击动画播放中：禁止移动和状态切换，让攻击动画完整播完
	if is_attacking:
		velocity = Vector2.ZERO
		safe_move_and_slide()
		return

	if attack_timer > 0:
		attack_timer -= _delta
		if attack_timer <= 0:
			is_attacking = false

	if player == null or !is_instance_valid(player):
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player = players[0]
		else:
			velocity = Vector2.ZERO
			play_anim("idle")
			safe_move_and_slide()
			return

	var dis = global_position.distance_to(player.global_position)

	if dis > chase_range:
		velocity = Vector2.ZERO
		play_anim("idle")
		# 仍然面向玩家
		var dir = (player.global_position - global_position).normalized()
		_set_flip_h((dir.x < 0) != (monster_name == "skull" or monster_name == "slime_king" or monster_name == "Bringer"))
	elif dis > attack_range:
		var dir = (player.global_position - global_position).normalized()
		_set_flip_h((dir.x < 0) != (monster_name == "skull" or monster_name == "slime_king" or monster_name == "Bringer"))
		velocity = dir * speed
		play_anim("walk")
	else:
		velocity = Vector2.ZERO
		if attack_timer <= 0 and not is_attacking:
			perform_attack()

	safe_move_and_slide()

func perform_attack():
	if is_dead or is_attacking or in_battle:
		return
	# 先标记进入战斗，再触发，避免重复发出信号
	in_battle = true
	is_attacking = true
	play_anim("attack")
	emit_signal("enter_battle", self)

# ============================================================
# Boss HUD：战斗中 Boss 的血条创建和更新
# ============================================================
func _create_boss_hud():
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
	name_label.position = Vector2(0, -14)
	name_label.size = Vector2(120, 16)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.add_theme_color_override("font_color", Color(1, 0.4, 0.2))
	name_label.text = display_name if display_name != "" else monster_name
	hud.add_child(name_label)

func update_hp_bar():
	if hp_fill:
		var ratio = float(current_hp) / float(max_hp)
		hp_fill.size.x = hp_bar.size.x * ratio
	if hp_label:
		hp_label.text = str(current_hp) + "/" + str(max_hp)

func take_damage(dmg: int):
	if is_dead: return
	current_hp -= dmg
	if is_boss and in_battle:
		update_hp_bar()
	if current_hp <= 0:
		current_hp = 0
		is_dead = true
		emit_signal("monster_died", self)
		die()
	else:
		play_anim("hurt")

func die():
	if is_dead == false: return
	play_anim("death")
	collision_shape.set_deferred("disabled", true)
	velocity = Vector2.ZERO

func exit_battle():
	if is_dead: return
	in_battle = false
	is_attacking = false
	attack_timer = 0
	play_anim("idle")

func play_anim(anim: String):
	if is_dead and anim != "death":
		return
	if not animated_sprite or not animated_sprite.sprite_frames:
		return
	# 高优先级动画播放中：禁止低优先级动画（walk/idle）打断，让攻击/受伤动画完整播完
	if animated_sprite.is_playing():
		var current_anim: String = animated_sprite.animation
		if current_anim.ends_with("_attack") or current_anim.ends_with("_hurt"):
			if anim == "walk" or anim == "idle":
				return
	var full_name = monster_name + "_" + anim
	if animated_sprite.sprite_frames.has_animation(full_name):
		animated_sprite.play(full_name)
		return
	# 模糊匹配：以 "_" + anim 结尾的动画
	var target = "_" + anim
	for a in animated_sprite.sprite_frames.get_animation_names():
		if a.ends_with(target):
			animated_sprite.play(a)
			return
	# idle 备用：如果是 idle 但没找到，尝试 walk
	if anim == "idle":
		for a in animated_sprite.sprite_frames.get_animation_names():
			if a.ends_with("_walk"):
				animated_sprite.play(a)
				return

func _on_animated_sprite_2d_animation_finished(_anim_name: String = ""):
	if is_dead:
		return
	if animated_sprite.animation.ends_with("_attack"):
		is_attacking = false
		attack_timer = 0
		play_anim("idle")
	if animated_sprite.animation.ends_with("_hurt"):
		play_anim("idle")
