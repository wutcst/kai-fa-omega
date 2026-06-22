extends CharacterBody2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var hud: Control
var hp_bar: ColorRect
var hp_fill: ColorRect
var hp_label: Label

@export var monster_name: String = "slime"
@export var max_hp: int = 60
@export var attack: int = 15
@export var defense: int = 3

var current_hp: int
var is_dead: bool = false
var is_attacking: bool = false
var in_battle: bool = false
var _original_sprite_offset: Vector2 = Vector2.ZERO  # 脚对齐后的原始 offset

@warning_ignore("unused_signal")
signal enter_battle(monster)
@warning_ignore("unused_signal")
signal monster_died(monster)


func _ready():
	current_hp = max_hp
	_apply_foot_alignment()
	create_bars()
	play_anim("idle")


# ============================================================
# 公开接口：重新应用脚对齐（用于精灵帧动态更换后）
# 外部调用：battler.reapply_foot_alignment(new_source_scale)
#   source_scale: 源怪物的 AnimatedSprite2D scale，不传则保持当前 scale
# ============================================================
func reapply_foot_alignment(source_scale: Vector2 = Vector2.ZERO):
	if source_scale != Vector2.ZERO:
		animated_sprite.scale = source_scale
	_apply_foot_alignment()


# ============================================================
# 脚对齐：根据动画帧大小自动计算 offset，让角色脚底对齐节点原点
# ============================================================
func _get_first_frame_size() -> Vector2:
	if not animated_sprite or not animated_sprite.sprite_frames:
		return Vector2.ZERO
	var anims = animated_sprite.sprite_frames.get_animation_names()
	if anims.size() == 0:
		return Vector2.ZERO
	var first_anim = anims[0]
	if animated_sprite.sprite_frames.get_frame_count(first_anim) == 0:
		return Vector2.ZERO
	var tex = animated_sprite.sprite_frames.get_frame_texture(first_anim, 0)
	if not tex:
		return Vector2.ZERO
	return tex.get_size()


func _apply_foot_alignment():
	var frame_size = _get_first_frame_size()
	if frame_size == Vector2.ZERO:
		_original_sprite_offset = animated_sprite.offset
		return
	# 脚对齐：只调整 offset.y 实现脚对齐，不改变 position.y
	# 目的：让精灵底部（y = position.y + offset.y + frame_size.y/2 * scale.y）对齐节点原点 y=0
	# 推导：offset.y = -position.y - frame_size.y/2 * scale.y
	var current_scale = animated_sprite.scale.y if animated_sprite else 1.0
	animated_sprite.offset = Vector2(
		0, -animated_sprite.position.y - frame_size.y / 2.0 * current_scale
	)
	_original_sprite_offset = animated_sprite.offset


func setup_from_monster(monster_node):
	monster_name = (
		monster_node.get("monster_name") if monster_node.get("monster_name") else monster_name
	)
	max_hp = monster_node.get("max_hp") if monster_node.get("max_hp") else max_hp
	attack = monster_node.get("attack") if monster_node.get("attack") else attack
	defense = monster_node.get("defense") if monster_node.get("defense") else defense
	current_hp = max_hp

	if hp_fill:
		hp_fill.size.x = hp_bar.size.x
	if hp_label:
		hp_label.text = str(current_hp) + "/" + str(max_hp)

	if monster_node.has_node("AnimatedSprite2D"):
		var source_sprite = monster_node.get_node("AnimatedSprite2D")
		if source_sprite and source_sprite.sprite_frames:
			animated_sprite.sprite_frames = source_sprite.sprite_frames.duplicate()

	play_anim("idle")


func create_bars():
	hud = Control.new()
	hud.name = "HUD"
	hud.position = Vector2(-50, -80)
	add_child(hud)

	hp_bar = ColorRect.new()
	hp_bar.name = "HPBarBg"
	hp_bar.size = Vector2(100, 14)
	hp_bar.position = Vector2(0, 0)
	hp_bar.color = Color(0.1, 0.1, 0.1)
	hud.add_child(hp_bar)

	hp_fill = ColorRect.new()
	hp_fill.name = "HPFill"
	hp_fill.size = Vector2(100, 14)
	hp_fill.position = Vector2(0, 0)
	hp_fill.color = Color(0.9, 0.15, 0.15)
	hud.add_child(hp_fill)

	hp_label = Label.new()
	hp_label.name = "HPLabel"
	hp_label.position = Vector2(0, -2)
	hp_label.size = Vector2(100, 14)
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_label.add_theme_font_size_override("font_size", 10)
	hp_label.text = str(current_hp) + "/" + str(max_hp)
	hud.add_child(hp_label)

	set_current_hp(current_hp)


func get_max_hp() -> int:
	return max_hp


func get_current_hp() -> int:
	return current_hp


func set_current_hp(value: int):
	current_hp = max(0, min(value, max_hp))
	if hp_fill:
		var ratio = float(current_hp) / float(max_hp)
		hp_fill.size.x = hp_bar.size.x * ratio
	if hp_label:
		hp_label.text = str(current_hp) + "/" + str(max_hp)


func get_attack() -> int:
	return attack


func get_defense() -> int:
	return defense


func take_damage(dmg: int):
	if is_dead:
		return
	current_hp -= dmg
	set_current_hp(current_hp)

	if current_hp <= 0:
		is_dead = true
		emit_signal("monster_died", self)
		die()
	else:
		play_anim("hurt")


func die():
	play_anim("death")
	if is_instance_valid(collision_shape):
		collision_shape.set_deferred("disabled", true)
	velocity = Vector2.ZERO
	# 不做异步淡出 — 避免与场景切换并发导致 get_tree() 为 null
	queue_free()


func _fade_out():
	pass


func exit_battle():
	in_battle = false


func play_anim(anim: String):
	if is_dead and anim != "death":
		return
	if not animated_sprite or not animated_sprite.sprite_frames:
		return

	# 1. 精确匹配：monster_name + "_" + anim
	var exact_name = monster_name + "_" + anim
	if animated_sprite.sprite_frames.has_animation(exact_name):
		animated_sprite.play(exact_name)
		return

	# 2. 模糊匹配：以 "_" + anim 结尾的动画
	var target_suffix = "_" + anim
	for a in animated_sprite.sprite_frames.get_animation_names():
		if a.ends_with(target_suffix):
			animated_sprite.play(a)
			return

	# 3. idle 备用：如果是 idle 但没找到，尝试 walk
	if anim == "idle":
		for a in animated_sprite.sprite_frames.get_animation_names():
			if a.ends_with("_walk"):
				animated_sprite.play(a)
				return


func _on_animation_finished(_anim_name: String = ""):
	if is_dead:
		return
	if animated_sprite.animation.find("_attack") != -1:
		is_attacking = false
		play_anim("idle")
	elif animated_sprite.animation.find("_hurt") != -1:
		play_anim("idle")


func _on_animated_sprite_2d_animation_finished(_anim_name: String = ""):
	_on_animation_finished(_anim_name)
