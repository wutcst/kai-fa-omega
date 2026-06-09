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

func get_max_hp() -> int:
	return GameData.max_hp

func get_current_hp() -> int:
	return GameData.current_hp

func set_current_hp(value: int):
	var old = GameData.current_hp
	GameData.current_hp = max(0, min(value, get_max_hp()))
	print("→ player_battler.set_current_hp(): 旧HP=", old, " → 新HP=", GameData.current_hp)
	if hp_fill:
		var ratio = float(GameData.current_hp) / float(get_max_hp())
		hp_fill.size.x = hp_bar.size.x * ratio
	if hp_label:
		hp_label.text = str(GameData.current_hp) + "/" + str(get_max_hp())

func get_max_mp() -> int:
	return GameData.max_mp

func get_current_mp() -> int:
	return GameData.current_mp

func set_current_mp(value: int):
	var old = GameData.current_mp
	GameData.current_mp = max(0, min(value, get_max_mp()))
	print("→ player_battler.set_current_mp(): 旧MP=", old, " → 新MP=", GameData.current_mp)
	if mp_fill:
		var ratio = float(GameData.current_mp) / float(get_max_mp())
		mp_fill.size.x = mp_bar.size.x * ratio
	if mp_label:
		mp_label.text = str(GameData.current_mp) + "/" + str(get_max_mp())

func get_attack() -> int:
	return GameData.attack

func get_defense() -> int:
	return GameData.defense

func get_current_job() -> GameData.Job:
	return GameData.current_job

func _ready():
	create_bars()
	play_job_animation("idle")
	print("→ player_battler._ready(): 已连接动画完成信号")

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
	mp_bar.size = Vector2(90, 10)
	mp_bar.position = Vector2(15, 18)
	mp_bar.color = Color(0.1, 0.1, 0.1)
	hud.add_child(mp_bar)
	
	mp_fill = ColorRect.new()
	mp_fill.name = "MPFill"
	mp_fill.size = Vector2(90, 10)
	mp_fill.position = Vector2(15, 18)
	mp_fill.color = Color(0.2, 0.5, 0.9)
	hud.add_child(mp_fill)
	
	mp_label = Label.new()
	mp_label.name = "MPLabel"
	mp_label.position = Vector2(15, 16)
	mp_label.size = Vector2(90, 10)
	mp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mp_label.add_theme_font_size_override("font_size", 8)
	mp_label.add_theme_color_override("font_color", Color(1, 1, 1))
	mp_label.text = str(get_current_mp()) + "/" + str(get_max_mp())
	hud.add_child(mp_label)

	set_current_hp(get_current_hp())
	set_current_mp(get_current_mp())

func attack_enemy(target: Node2D):
	if in_attack or is_dead: return
	in_attack = true

	current_attack_target = target
	play_job_animation("attack")
	
	var anim_name = get_job_prefix() + "_attack"
	var duration = 0.4
	if animated_sprite.sprite_frames.has_animation(anim_name):
		var frame_count = animated_sprite.sprite_frames.get_frame_count(anim_name)
		duration = frame_count * 0.15
		print("→ attack 动画时长：", duration)
	
	await get_tree().create_timer(duration).timeout
	
	var hurt_duration = 0.0
	if current_attack_target and is_instance_valid(current_attack_target):
		var defense_val = current_attack_target.get("defense")
		var defense = defense_val if defense_val is int else 0
		var damage = max(1, get_attack() - defense)
		print("→ player_battler.attack_enemy()：造成伤害：", damage)
		current_attack_target.take_damage(damage)
		
		# 算怪物受伤动画时长
		if current_attack_target.has_node("AnimatedSprite2D") and not current_attack_target.is_dead:
			var sprite: AnimatedSprite2D = current_attack_target.get_node("AnimatedSprite2D")
			var hurt_anim_name = current_attack_target.monster_name + "_hurt"
			if sprite.sprite_frames.has_animation(hurt_anim_name):
				hurt_duration = max(0.6, sprite.sprite_frames.get_frame_count(hurt_anim_name) * 0.2)
			else:
				hurt_duration = 0.6
		
		current_attack_target = null
	
	if hurt_duration > 0:
		print("→ 等待怪物受伤动画：", hurt_duration)
		await get_tree().create_timer(hurt_duration).timeout
	
	in_attack = false
	play_job_animation("idle")
	BattleManager._after_player_attack()

func take_damage(damage: int):
	if is_dead: return
	var old_hp = get_current_hp()
	set_current_hp(old_hp - damage)
	print("→ player_battler.take_damage()：受到伤害：", damage, " | 旧HP:", old_hp, " → 新HP:", get_current_hp())
	
	if get_current_hp() <= 0:
		is_dead = true
		play_job_animation("death")
	else:
		play_job_animation("hurt")

func play_job_animation(action_name: String):
	if is_dead and action_name != "death":
		return
	var anim_name = get_job_prefix() + "_" + action_name
	if animated_sprite.sprite_frames.has_animation(anim_name):
		animated_sprite.play(anim_name)

func get_job_prefix() -> String:
	match get_current_job():
		GameData.Job.SWORDSMAN: return "swordsman"
		GameData.Job.RANGER: return "ranger"
		GameData.Job.SHIELD_KNIGHT: return "shield_knight"
		_: return "swordsman"
