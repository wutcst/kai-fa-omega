extends CharacterBody2D

# 旅馆老板节点：不移动，玩家按 E 键交互打开旅馆休息界面
# 挂载到 hotel_owner.tscn 的 CharacterBody2D 根节点

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var hotel_panel: CanvasLayer = null
var panel_open: bool = false
var player_nearby: bool = false
var hint_label: Label = null

func _ready():
	add_to_group("hotel_owner")
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
	hint_label.text = "按 E 休息"
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
		open_hotel_panel()

func open_hotel_panel():
	if hotel_panel == null:
		var panel_script = load("res://scripts/HotelPanel.gd")
		if panel_script:
			hotel_panel = CanvasLayer.new()
			hotel_panel.name = "HotelPanel"
			hotel_panel.set_script(panel_script)
			get_tree().current_scene.add_child(hotel_panel)
	panel_open = true
	if hint_label:
		hint_label.visible = false
	if is_instance_valid(hotel_panel):
		if hotel_panel.has_method("set_close_callback"):
			hotel_panel.set_close_callback(_on_panel_closed)

func _on_panel_closed():
	panel_open = false
	if player_nearby and hint_label:
		hint_label.visible = true

func play_anim(anim: String):
	if is_instance_valid(animated_sprite):
		if animated_sprite.sprite_frames.has_animation("hotel owner"):
			animated_sprite.play("hotel owner")
