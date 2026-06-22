extends "res://scripts/entities/monster.gd"
class_name Boss

# Boss 专用：精灵帧中角色不居中，position.x 用来补偿偏移
# 翻转时需要对其取反，否则动画像传送
var _original_sprite_pos_x: float = 0.0


func _ready():
	# 在父类 _apply_foot_alignment 运行前保存原始 position.x
	_original_sprite_pos_x = animated_sprite.position.x
	super._ready()


# 重写：翻转时对 position.x 取反，补偿精灵帧不居中
func _set_flip_h(new_flip: bool):
	if animated_sprite.flip_h == new_flip:
		return
	animated_sprite.flip_h = new_flip
	if new_flip:
		animated_sprite.position.x = -_original_sprite_pos_x
	else:
		animated_sprite.position.x = _original_sprite_pos_x


# BattleManager 重设精灵帧后调用，保留 position.x 偏移
func reapply_foot_alignment(source_scale: Vector2 = Vector2.ZERO):
	if source_scale != Vector2.ZERO:
		animated_sprite.scale = source_scale
	_apply_foot_alignment()
