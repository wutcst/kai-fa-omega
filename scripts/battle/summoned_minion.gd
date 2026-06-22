extends CharacterBody2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

@export var monster_name: String = "summoned_minion"

var is_dead: bool = false
var _original_sprite_offset: Vector2 = Vector2.ZERO


func _ready():
	call_deferred("_setup_visuals")


func _setup_visuals():
	_apply_foot_alignment()
	play_anim("appear")


# ============================================================
# 脚对齐
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


# 抵挡一次攻击（任意技能），直接死亡
func take_damage(_dmg: int):
	if is_dead:
		return
	is_dead = true
	die()


func die():
	play_anim("death")
	var duration: float = 0.5
	if animated_sprite.sprite_frames.has_animation("Summoned Minion_death"):
		var fc = animated_sprite.sprite_frames.get_frame_count("Summoned Minion_death")
		var spd = max(
			1.0, animated_sprite.sprite_frames.get_animation_speed("Summoned Minion_death")
		)
		duration = fc / spd
	await get_tree().create_timer(duration + 0.2).timeout
	queue_free()
