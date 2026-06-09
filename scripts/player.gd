extends CharacterBody2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

@export var max_hp: int = 100
@export var current_hp: int = 100
@export var max_mp: int = 50
@export var current_mp: int = 50

@export var attack: int = 10
@export var defense: int = 5
@export var base_speed: int = 180
var current_speed: int = 180

@export var level: int = 1
@export var current_exp: int = 0
@export var exp_to_next_level: int = 50
@export var level_up_growth: float = 1.2

var current_job: GameData.Job = GameData.Job.SWORDSMAN
var is_dead: bool = false
var in_battle: bool = false

func _ready():
	load_data_from_global()
	update_job_stats()
	play_job_animation("idle")
	connect_signals()

func safe_move_and_slide():
	if is_inside_tree() and is_instance_valid(collision_shape) and not collision_shape.disabled:
		move_and_slide()

func connect_signals():
	if not animated_sprite.animation_finished.is_connected(_on_animated_sprite_animation_finished):
		animated_sprite.animation_finished.connect(_on_animated_sprite_animation_finished)

func save_data_to_global():
	GameData.max_hp = max_hp
	GameData.current_hp = current_hp
	GameData.max_mp = max_mp
	GameData.current_mp = current_mp
	GameData.attack = attack
	GameData.defense = defense
	GameData.base_speed = base_speed
	GameData.current_speed = current_speed
	GameData.level = level
	GameData.current_exp = current_exp
	GameData.exp_to_next_level = exp_to_next_level
	GameData.current_job = current_job

func load_data_from_global():
	max_hp = GameData.max_hp
	current_hp = GameData.current_hp
	max_mp = GameData.max_mp
	current_mp = GameData.current_mp
	attack = GameData.attack
	defense = GameData.defense
	base_speed = GameData.base_speed
	current_speed = GameData.current_speed
	level = GameData.level
	current_exp = GameData.current_exp
	exp_to_next_level = GameData.exp_to_next_level
	current_job = GameData.current_job

func _physics_process(_delta: float) -> void:
	if not is_inside_tree():
		return
	if in_battle || is_dead:
		velocity = Vector2.ZERO
		animated_sprite.stop()
		return

	var input_dir = Input.get_vector("left", "right", "up", "down")
	velocity = input_dir * current_speed
	safe_move_and_slide()

	if input_dir.length() > 0:
		play_job_animation("walk")
		animated_sprite.flip_h = input_dir.x < 0
	else:
		play_job_animation("idle")

	if Input.is_action_just_pressed("ui_swordsman"): switch_job(GameData.Job.SWORDSMAN)
	if Input.is_action_just_pressed("ui_ranger"): switch_job(GameData.Job.RANGER)
	if Input.is_action_just_pressed("ui_shield"): switch_job(GameData.Job.SHIELD_KNIGHT)

func switch_job(new_job: GameData.Job) -> void:
	if is_dead || current_job == new_job || in_battle:
		return
	current_job = new_job
	update_job_stats()
	play_job_animation("idle")

func update_job_stats() -> void:
	match current_job:
		GameData.Job.SWORDSMAN:
			max_hp = 120 + level * 15
			max_mp = 40 + level * 6
			attack = 15 + level * 3
			defense = 8 + level * 2
			current_speed = 180
		GameData.Job.RANGER:
			max_hp = 90 + level * 10
			max_mp = 60 + level * 8
			attack = 12 + level * 2
			defense = 4 + level * 1
			current_speed = 280
		GameData.Job.SHIELD_KNIGHT:
			max_hp = 180 + level * 25
			max_mp = 30 + level * 4
			attack = 8 + level * 2
			defense = 15 + level * 3
			current_speed = 120
	current_hp = max_hp
	current_mp = max_mp
	save_data_to_global()

func play_job_animation(action_name: String) -> void:
	var anim_name = get_job_prefix() + "_" + action_name
	if animated_sprite.sprite_frames.has_animation(anim_name):
		animated_sprite.play(anim_name)

func get_job_prefix() -> String:
	match current_job:
		GameData.Job.SWORDSMAN: return "swordsman"
		GameData.Job.RANGER: return "ranger"
		GameData.Job.SHIELD_KNIGHT: return "shield_knight"
		_: return "swordsman"

func get_job_name() -> String:
	match current_job:
		GameData.Job.SWORDSMAN: return "剑士"
		GameData.Job.RANGER: return "游侠"
		GameData.Job.SHIELD_KNIGHT: return "盾骑士"
		_: return "剑士"

func _on_animated_sprite_animation_finished(anim):
	if is_dead:
		return
	if anim.ends_with("_attack") || anim.ends_with("_hurt"):
		play_job_animation("idle")
