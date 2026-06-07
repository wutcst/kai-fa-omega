extends CharacterBody2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var hud: Control
var hp_bar: ColorRect
var hp_fill: ColorRect
var hp_label: Label

@export var monster_name: String = "slime"
@export var max_hp: int = 80
@export var attack: int = 15
@export var defense: int = 3

var current_hp: int
var is_dead: bool = false
var is_attacking: bool = false
var in_battle: bool = false

signal enter_battle(monster)
signal monster_died(monster)

func _ready():
	current_hp = max_hp
	create_bars()
	play_anim("idle")
	connect_signals()

func connect_signals():
	if not animated_sprite.animation_finished.is_connected(_on_animation_finished):
		animated_sprite.animation_finished.connect(_on_animation_finished)

func setup_from_monster(monster_node):
	monster_name = monster_node.get("monster_name") if monster_node.get("monster_name") else monster_name
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
	hp_label.add_theme_color_override("font_color", Color(1, 1, 1))
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
	if is_dead: return
	current_hp -= dmg
	set_current_hp(current_hp)
	play_anim("hurt")
	
	if current_hp <= 0:
		is_dead = true
		die()

func die():
	play_anim("death")
	collision_shape.set_deferred("disabled", true)
	velocity = Vector2.ZERO

func exit_battle():
	in_battle = false

func play_anim(anim: String):
	if is_dead and anim != "death":
		return
	var full_name = monster_name + "_" + anim
	if animated_sprite.sprite_frames.has_animation(full_name):
		animated_sprite.play(full_name)
	elif anim == "idle" and animated_sprite.sprite_frames.has_animation(monster_name + "_walk"):
		animated_sprite.play(monster_name + "_walk")

func _on_animation_finished(anim_name: String):
	if is_dead:
		if anim_name.ends_with("_death"):
			queue_free()
		return
	
	if anim_name.ends_with("_attack"):
		is_attacking = false
		play_anim("idle")
	if anim_name.ends_with("_hurt"):
		play_anim("idle")
