extends CharacterBody2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

@export var max_hp: int = 150
@export var current_hp: int = 150
@export var max_mp: int = 50
@export var current_mp: int = 50

@export var attack: int = 12
@export var defense: int = 8
@export var crit: int = 5
@export var base_speed: int = 200
var current_speed: int = 200

@export var level: int = 1
@export var current_exp: int = 0
@export var exp_to_next_level: int = 50
@export var level_up_growth: float = 1.2

var is_dead: bool = false
var in_battle: bool = false

var inventory_panel: CanvasLayer = null
var inventory_open: bool = false

const ANIM_PREFIX: String = "swordsman"

func _ready():
	add_to_group("player")
	z_index = 100
	load_data_from_global()
	play_anim("idle")
	connect_signals()
	
	if GameData.returning_from_battle:
		global_position = GameData.player_return_position
		GameData.returning_from_battle = false
		print("→ 返回战斗前位置：", global_position)

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
	GameData.crit = crit
	GameData.base_speed = base_speed
	GameData.current_speed = current_speed
	GameData.level = level
	GameData.current_exp = current_exp
	GameData.exp_to_next_level = exp_to_next_level

func load_data_from_global():
	max_hp = GameData.max_hp
	current_hp = min(GameData.current_hp, GameData.get_total_max_hp())
	max_mp = GameData.max_mp
	current_mp = min(GameData.current_mp, GameData.max_mp)
	attack = GameData.attack
	defense = GameData.defense
	crit = GameData.crit
	base_speed = GameData.base_speed
	current_speed = GameData.current_speed
	level = GameData.level
	current_exp = GameData.current_exp
	exp_to_next_level = GameData.exp_to_next_level
	
	if current_hp <= 0:
		current_hp = max_hp
		GameData.current_hp = max_hp
		print("→ 战斗失败，重生并恢复满血")

# 获取装备加成后的战斗用属性
func get_battle_attack() -> int:
	return GameData.get_total_attack()

func get_battle_defense() -> int:
	return GameData.get_total_defense()

func get_battle_max_hp() -> int:
	return GameData.get_total_max_hp()

func get_battle_crit() -> int:
	return crit

func _physics_process(_delta: float) -> void:
	if not is_inside_tree():
		return
	if in_battle || is_dead:
		velocity = Vector2.ZERO
		animated_sprite.stop()
		return

	if Input.is_action_just_pressed("ui_inventory"):
		toggle_inventory()

	if inventory_open:
		velocity = Vector2.ZERO
		if not animated_sprite.animation.ends_with("_idle"):
			play_anim("idle")
		return

	var input_dir = Input.get_vector("left", "right", "up", "down")
	velocity = input_dir * current_speed
	safe_move_and_slide()

	if input_dir.length() > 0:
		play_anim("walk")
		animated_sprite.flip_h = input_dir.x < 0
	else:
		play_anim("idle")

func play_anim(action_name: String) -> void:
	var anim_name = ANIM_PREFIX + "_" + action_name
	if animated_sprite.sprite_frames.has_animation(anim_name):
		animated_sprite.play(anim_name)

func _on_animated_sprite_animation_finished():
	if is_dead:
		return
	var current = animated_sprite.animation
	if current.ends_with("_attack") || current.ends_with("_hurt"):
		play_anim("idle")

func toggle_inventory():
	if inventory_open:
		close_inventory()
	else:
		open_inventory()

func open_inventory():
	if inventory_panel == null:
		var panel_script = load("res://scripts/InventoryPanel.gd")
		if panel_script:
			inventory_panel = CanvasLayer.new()
			inventory_panel.name = "InventoryPanel"
			inventory_panel.set_script(panel_script)
			inventory_panel.set("player_ref", self)
			get_tree().current_scene.add_child(inventory_panel)
			await get_tree().process_frame
	inventory_open = true
	if is_instance_valid(inventory_panel):
		inventory_panel.show_panel()

func close_inventory():
	inventory_open = false
	if is_instance_valid(inventory_panel):
		inventory_panel.hide_panel()
