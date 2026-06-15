extends CharacterBody2D

# 商人节点：不移动，玩家按 E 键交互打开交易界面
# 需要挂载到 merchant.tscn 的 CharacterBody2D 根节点

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var merchant_panel: CanvasLayer = null
var panel_open: bool = false
var player_nearby: bool = false
var hint_label: Label = null

func _ready():
	add_to_group("merchant")
	play_anim("idle")
	_setup_interaction_area()
	_setup_hint_label()

func _setup_interaction_area():
	var area = Area2D.new()
	var collision = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 65.0
	collision.shape = circle
	area.add_child(collision)
	add_child(area)
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)

func _setup_hint_label():
	hint_label = Label.new()
	hint_label.text = "按 E 交易"
	hint_label.add_theme_font_size_override("font_size", 12)
	hint_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.position = Vector2(-30, -40)
	hint_label.custom_minimum_size = Vector2(60, 20)
	hint_label.visible = false
	add_child(hint_label)

func _on_body_entered(body):
	if body.is_in_group("player"):
		player_nearby = true
		if hint_label:
			hint_label.visible = true

func _on_body_exited(body):
	if body.is_in_group("player"):
		player_nearby = false
		if hint_label:
			hint_label.visible = false

func _process(_delta):
	if panel_open:
		return
	if player_nearby and Input.is_key_pressed(KEY_E):
		open_merchant_panel()

func open_merchant_panel():
	if merchant_panel == null:
		var panel_script = load("res://scripts/MerchantPanel.gd")
		if panel_script:
			merchant_panel = CanvasLayer.new()
			merchant_panel.name = "MerchantPanel"
			merchant_panel.set_script(panel_script)
			get_tree().current_scene.add_child(merchant_panel)
	panel_open = true
	if hint_label:
		hint_label.visible = false
	if is_instance_valid(merchant_panel):
		if merchant_panel.has_method("set_close_callback"):
			merchant_panel.set_close_callback(_on_panel_closed)

func _on_panel_closed():
	panel_open = false
	merchant_panel = null
	if player_nearby and hint_label:
		hint_label.visible = true

func play_anim(anim: String):
	if is_instance_valid(animated_sprite):
		var full_name = "merchant_" + anim
		if animated_sprite.sprite_frames.has_animation(full_name):
			animated_sprite.play(full_name)
