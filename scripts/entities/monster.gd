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

func _ready():
	current_hp = max_hp
	spawn_position = global_position
	
	# 检查是否已被击败（地图重载后自动清除）
	for pos in GameData.defeated_monster_positions:
		if pos is Vector2:
			if spawn_position.distance_to(pos) < chase_range:
				print("→ 怪物已被击败，自动清除：", monster_name, " at ", spawn_position)
				queue_free()
				return
	
	play_anim("idle")
	connect_signals()

func safe_move_and_slide():
	if is_inside_tree() and is_instance_valid(collision_shape) and not collision_shape.disabled:
		move_and_slide()

func connect_signals():
	if not animated_sprite.animation_finished.is_connected(_on_animated_sprite_2d_animation_finished):
		animated_sprite.animation_finished.connect(_on_animated_sprite_2d_animation_finished)

func _draw():
	draw_circle(Vector2.ZERO, chase_range, Color(1, 0, 0, 0.3))
	draw_circle(Vector2.ZERO, attack_range, Color(0, 1, 0, 0.3))

func _physics_process(_delta: float) -> void:
	if not is_inside_tree():
		return
	if is_dead || in_battle:
		velocity = Vector2.ZERO
		is_attacking = false
		attack_timer = 0
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
	elif dis > attack_range:
		var dir = (player.global_position - global_position).normalized()
		animated_sprite.flip_h = dir.x < 0
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
	attack_timer = attack_cd
	play_anim("attack")
	emit_signal("enter_battle", self)

func take_damage(dmg: int):
	if is_dead: return
	current_hp -= dmg
	if current_hp <= 0:
		current_hp = 0
		is_dead = true
		emit_signal("monster_died", self)

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
	var full_name = monster_name + "_" + anim
	var anim_list = animated_sprite.sprite_frames.get_animation_names()
	if anim_list.has(full_name):
		animated_sprite.play(full_name)
	elif anim == "idle" and anim_list.has(monster_name + "_walk"):
		animated_sprite.play(monster_name + "_walk")

func _on_animated_sprite_2d_animation_finished(_anim_name: String = ""):
	if is_dead:
		return
	if animated_sprite.animation.ends_with("_attack"):
		is_attacking = false
		attack_timer = 0
		play_anim("idle")
	if animated_sprite.animation.ends_with("_hurt"):
		play_anim("idle")