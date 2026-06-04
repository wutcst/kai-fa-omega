extends CharacterBody2D

# ==============================
# 节点引用（固定不变）
# ==============================
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

# ==============================
# 【核心配置】所有怪物都在这里改
# ==============================
@export var monster_name: String = "slime"
@export var max_hp: int = 30
@export var speed: float = 70.0
@export var damage: int = 5
@export var chase_range: float = 200.0
@export var attack_range: float = 40.0
@export var attack_cd: float = 1.0

# ==============================
# 经验
# ==============================
@export var exp_drop: int = 10

# ==============================
# 内部状态
# ==============================
var current_hp: int
var is_dead: bool = false
var player: Node2D = null
var attack_timer: float = 0.0
var is_attacking:bool = false

func _ready():
	current_hp = max_hp
	play_anim("idle")

func _draw():
	draw_circle(animated_sprite.position, chase_range, Color(1,0,0,0.3))
	draw_circle(animated_sprite.position, attack_range, Color(0,1,0,0.3))

func _physics_process(delta: float) -> void:
	if is_dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# 攻击冷却
	if attack_timer > 0:
		attack_timer -= delta
		if attack_timer <= 0:
			is_attacking = false

	# ======================
	# 【自动找玩家】修复点
	# ======================
	if player == null or !is_instance_valid(player):
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player = players[0]
		else:
			velocity = Vector2.ZERO
			play_anim("idle")
			move_and_slide()
			return

	# 距离计算
	var monster_center = animated_sprite.global_position
	var dis: float = monster_center.distance_to(player.global_position)

	# 超出范围
	if dis > chase_range:
		velocity = Vector2.ZERO
		play_anim("idle")
	
	# 追击
	elif dis > attack_range:
		var dir = (player.global_position - monster_center).normalized()
		animated_sprite.flip_h = dir.x < 0
		velocity = dir * speed
		play_anim("walk")
	
	# 攻击
	else:
		velocity = Vector2.ZERO
		if attack_timer <= 0 and not is_attacking:
			perform_attack()

	move_and_slide()

func perform_attack():
	is_attacking = true
	attack_timer = attack_cd
	play_anim("attack")

	if global_position.distance_to(player.global_position) <= attack_range:
		if player.has_method("take_damage"):
			player.take_damage(damage)

# ==============================
# 动画
# ==============================
func play_anim(anim: String):
	var full_name = monster_name + "_" + anim
	var anim_list = animated_sprite.sprite_frames.get_animation_names()
	if !anim_list.has(full_name) and anim == "idle":
		full_name = monster_name + "_walk"

	if anim_list.has(full_name):
		animated_sprite.play(full_name)
	else:
		print("缺失动画：",full_name)

# ==============================
# 受伤
# ==============================
func take_damage(value: int):
	if is_dead:
		return
	current_hp -= value
	play_anim("hurt")
	if current_hp <= 0:
		die()

# ==============================
# 死亡
# ==============================
func die():
	is_dead = true
	play_anim("death")
	collision_shape.set_deferred("disabled", true)

	if player and player.has_method("add_exp"):
		player.add_exp(exp_drop)

	await animated_sprite.animation_finished
	queue_free()

# ==============================
# 动画结束
# ==============================
func _on_animated_sprite_2d_animation_finished(anim_name):
	if is_dead:
		return
	if anim_name.ends_with("_hurt"):
		play_anim("idle")
	if anim_name.ends_with("_attack"):
		is_attacking = false
		play_anim("idle")
