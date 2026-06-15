extends CharacterBody2D

# 商人节点：不移动，玩家碰撞后打开交易界面
# 需要挂载到 merchant.tscn 的 CharacterBody2D 根节点

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var merchant_panel: CanvasLayer = null
var panel_open: bool = false
var can_trigger: bool = true  # 防止反复触发
const TRIGGER_DISTANCE: float = 55.0  # 触发距离（像素）

func _ready():
	add_to_group("merchant")
	play_anim("idle")

func _physics_process(_delta: float):
	if not can_trigger:
		return
	if panel_open:
		return
	# 按Z键时禁止触发商人界面（Z只用于关闭）
	if Input.is_key_pressed(KEY_Z):
		return
	# 通过距离检测玩家是否接近商人
	var players = get_tree().get_nodes_in_group("player")
	for p in players:
		if global_position.distance_to(p.global_position) < TRIGGER_DISTANCE:
			open_merchant_panel()
			return

# 打开商人界面
func open_merchant_panel():
	if merchant_panel == null:
		var panel_script = load("res://scripts/MerchantPanel.gd")
		if panel_script:
			merchant_panel = CanvasLayer.new()
			merchant_panel.name = "MerchantPanel"
			merchant_panel.set_script(panel_script)
			get_tree().current_scene.add_child(merchant_panel)
	panel_open = true
	can_trigger = false
	if is_instance_valid(merchant_panel):
		if merchant_panel.has_method("set_close_callback"):
			merchant_panel.set_close_callback(_on_panel_closed)

# 关闭商人界面（由面板调用回调）
func _on_panel_closed():
	panel_open = false
	# 短暂延迟后再允许触发，防止还在范围内立即又弹开
	await get_tree().create_timer(0.8).timeout
	can_trigger = true

func play_anim(anim: String):
	if is_instance_valid(animated_sprite):
		var full_name = "merchant_" + anim
		if animated_sprite.sprite_frames.has_animation(full_name):
			animated_sprite.play(full_name)
