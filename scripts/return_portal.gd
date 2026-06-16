extends Area2D

@export var target_scene: String = "res://scenes/village.tscn"
@export var hint_text: String = "按 E 返回村庄"

var hint_label: Label = null
var player_nearby: bool = false

func _ready():
	add_to_group("return_portal")
	_setup_collision()
	_setup_hint_label()

func _setup_collision():
	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(80, 80)
	shape.shape = rect
	shape.name = "CollisionShape2D"
	add_child(shape)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _setup_hint_label():
	hint_label = Label.new()
	hint_label.text = hint_text
	hint_label.add_theme_font_size_override("font_size", 14)
	hint_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.position = Vector2(-50, -30)
	hint_label.custom_minimum_size = Vector2(100, 24)
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
	if player_nearby and Input.is_key_pressed(KEY_E):
		if target_scene != "":
			get_tree().call_deferred("change_scene_to_file", target_scene)