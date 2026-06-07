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
var attack_callback_id: int = -1

func get_max_hp() -> int:
	return GameData.max_hp

func get_current_hp() -> int:
	return GameData.current_hp

func set_current_hp(value: int):
	GameData.current_hp = max(0, min(value, get_max_hp()))
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
	GameData.current_mp = max(0, min(value, get_max_mp()))
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

func _process(delta):
	if is_turn and not in_attack and not is_dead:
		if Input.is_action_just_pressed("ui_accept"):
			if Engine.has_singleton("BattleManager") and BattleManager.current_enemy:
				attack_enemy(BattleManager.current_enemy)

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
	if not is_turn or in_attack or is_dead: return
	in_attack = true
	is_turn = false

	current_attack_target = target
	play_job_animation("attack")

	if Engine.has_singleton("BattleManager"):
		BattleManager.battle_state = BattleManager.BattleState.PLAYER_ACTION

	if attack_callback_id == -1:
		attack_callback_id = animated_sprite.animation_finished.connect(_on_attack_anim_done)

func _on_attack_anim_done():
	if attack_callback_id != -1:
		animated_sprite.animation_finished.disconnect(_on_attack_anim_done)
		attack_callback_id = -1

	if current_attack_target and is_instance_valid(current_attack_target):
		var defense_val = current_attack_target.get("defense")
		var defense = defense_val if defense_val is int else 0
		var damage = max(1, get_attack() - defense)
		current_attack_target.take_damage(damage)
		current_attack_target = null

	in_attack = false
	play_job_animation("idle")
	
	if Engine.has_singleton("BattleManager"):
		BattleManager._after_player_attack()

func take_damage(damage: int):
	if is_dead: return
	set_current_hp(get_current_hp() - damage)
	play_job_animation("hurt")
	
	if get_current_hp() <= 0:
		is_dead = true
		play_job_animation("death")

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
