extends CharacterBody2D
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
# 自动创建的节点
var hud: Control
var hp_bar: ProgressBar
var mp_bar: ProgressBar

var is_turn: bool = false
var is_dead: bool = false
var in_attack: bool = false
var current_attack_target: Node2D = null

# ====================== 属性读取 ======================
func get_max_hp() -> int:
	return GameData.max_hp

func get_current_hp() -> int:
	return GameData.current_hp

func set_current_hp(value: int):
	GameData.current_hp = value
	hp_bar.value = value

func get_max_mp() -> int:
	return GameData.max_mp

func get_current_mp() -> int:
	return GameData.current_mp

func set_current_mp(value: int):
	GameData.current_mp = value
	mp_bar.value = value

func get_attack() -> int:
	return GameData.attack

func get_defense() -> int:
	return GameData.defense

func get_current_job() -> GameData.Job:
	return GameData.current_job

# ====================== 自动创建血条蓝条 ======================
func _ready():
	create_bars()  # 自动创建
	play_job_animation("idle")

func create_bars():
	# ========== HUD 容器 ==========
	hud = Control.new()
	hud.name = "HUD"
	add_child(hud)

	hud.anchor_left = 0.0
	hud.anchor_top = 0.5
	hud.anchor_right = 0.0
	hud.anchor_bottom = 0.5
	hud.position = Vector2(-40, 0)

	# ========== 血条（保持粗一点） ==========
	hp_bar = ProgressBar.new()
	hp_bar.name = "HPBar"
	hud.add_child(hp_bar)
	hp_bar.size = Vector2(8, 40)   # 高12，正常
	hp_bar.position = Vector2(0, -22)
	hp_bar.max_value = get_max_hp()
	hp_bar.value = get_current_hp()
	hp_bar.show_percentage = false
	
	var hp_fill = StyleBoxFlat.new()
	hp_fill.bg_color = Color(1, 0.2, 0.2)
	hp_bar.add_theme_stylebox_override("fill", hp_fill)

	var hp_bg = StyleBoxFlat.new()
	hp_bg.bg_color = Color(0.2, 0.2, 0.2)
	hp_bar.add_theme_stylebox_override("background", hp_bg)
	
	# ========== 蓝条（改细+上移） ==========
	mp_bar = ProgressBar.new()
	mp_bar.name = "MPBar"
	hud.add_child(mp_bar)
	mp_bar.size = Vector2(8, 24)    # 高6，变细
	mp_bar.position = Vector2(0, 10)  # 从16改成14，上移一点
	mp_bar.max_value = get_max_mp()
	mp_bar.value = get_current_mp()
	mp_bar.show_percentage = false
	
	var mp_fill = StyleBoxFlat.new()
	mp_fill.bg_color = Color(0.2, 0.6, 1)
	mp_bar.add_theme_stylebox_override("fill", mp_fill)
	
	var mp_bg = StyleBoxFlat.new()
	mp_bg.bg_color = Color(0.2, 0.2, 0.2)
	mp_bar.add_theme_stylebox_override("background", mp_bg)

# ====================== 攻击 ======================
func attack_enemy(target: Node2D):
	if not is_turn or in_attack or is_dead: return
	in_attack = true
	is_turn = false

	current_attack_target = target
	play_job_animation("attack")

	animated_sprite.animation_finished.connect(_on_attack_anim_done)

func _on_attack_anim_done():
	if animated_sprite.animation_finished.is_connected(_on_attack_anim_done):
		animated_sprite.animation_finished.disconnect(_on_attack_anim_done)

	if current_attack_target:
		var damage = max(1, get_attack() - current_attack_target.defense)
		current_attack_target.take_damage(damage)
		current_attack_target = null

	in_attack = false
	play_job_animation("idle")

# ====================== 受伤 ======================
func take_damage(damage: int):
	if is_dead: return
	set_current_hp(get_current_hp() - damage)
	play_job_animation("hurt")

# ====================== 动画 ======================
func play_job_animation(action_name: String):
	var anim_name = get_job_prefix() + "_" + action_name
	if animated_sprite.sprite_frames.has_animation(anim_name):
		animated_sprite.play(anim_name)

func get_job_prefix() -> String:
	match get_current_job():
		GameData.Job.SWORDSMAN: return "swordsman"
		GameData.Job.RANGER: return "ranger"
		GameData.Job.SHIELD_KNIGHT: return "shield_knight"
		_: return "swordsman"
