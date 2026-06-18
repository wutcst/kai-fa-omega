extends CharacterBody2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

@export var max_hp: int = 40

var current_hp: int
var is_dead: bool = false
var _original_sprite_offset: Vector2 = Vector2.ZERO   # 脚对齐后的原始 offset

# HUD
var hud: Control
var hp_bar: ColorRect
var hp_fill: ColorRect

func _ready():
	current_hp = max_hp
	_apply_foot_alignment()
	create_bars()
	play_anim("appear")

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
	animated_sprite.offset = Vector2(0, -frame_size.y / 2.0)
	_original_sprite_offset = animated_sprite.offset

func create_bars():
	hud = Control.new()
	hud.name = "MinionHUD"
	hud.position = Vector2(-25, -40)
	add_child(hud)

	hp_bar = ColorRect.new()
	hp_bar.name = "HPBarBg"
	hp_bar.size = Vector2(50, 8)
	hp_bar.position = Vector2(0, 0)
	hp_bar.color = Color(0.1, 0.1, 0.1)
	hud.add_child(hp_bar)

	hp_fill = ColorRect.new()
	hp_fill.name = "HPFill"
	hp_fill.size = Vector2(50, 8)
	hp_fill.position = Vector2(0, 0)
	hp_fill.color = Color(0.5, 0.3, 0.7)
	hud.add_child(hp_fill)

func update_hp_bar():
	if hp_fill:
		var ratio = float(current_hp) / float(max_hp)
		hp_fill.size.x = hp_bar.size.x * ratio

func play_anim(anim: String):
	if is_dead and anim != "death":
		return
	if not animated_sprite or not animated_sprite.sprite_frames:
		return
	var full_name = "Summoned Minion_" + anim
	if animated_sprite.sprite_frames.has_animation(full_name):
		animated_sprite.play(full_name)
		return
	var target = "_" + anim
	for a in animated_sprite.sprite_frames.get_animation_names():
		if a.ends_with(target):
			animated_sprite.play(a)
			return

func take_damage(dmg: int):
	if is_dead:
		return
	current_hp -= dmg
	update_hp_bar()

	if current_hp <= 0:
		current_hp = 0
		is_dead = true
		die()
	else:
		play_anim("hurt")

func die():
	play_anim("death")
	# 等待死亡动画后自动清除
	var duration: float = 0.5
	if animated_sprite.sprite_frames.has_animation("Summoned Minion_death"):
		var fc = animated_sprite.sprite_frames.get_frame_count("Summoned Minion_death")
		var spd = max(1.0, animated_sprite.sprite_frames.get_animation_speed("Summoned Minion_death"))
		duration = fc / spd
	await get_tree().create_timer(duration).timeout
	queue_free()
