extends CharacterBody2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var dialog_panel: CanvasLayer = null
var panel_open: bool = false
var player_nearby: bool = false
var hint_label: Label = null

@export var destination_scene: String = "res://scenes/forest.tscn"

func _ready():
	add_to_group("village_head")
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
	hint_label.text = "按 E 对话"
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
		open_dialog_panel()

func open_dialog_panel():
	if dialog_panel != null:
		return

	dialog_panel = CanvasLayer.new()
	dialog_panel.name = "VillageHeadDialog"
	dialog_panel.layer = 100
	get_tree().root.add_child(dialog_panel)

	var panel = PanelContainer.new()
	panel.name = "DialogPanel"
	panel.custom_minimum_size = Vector2(500, 320)
	panel.add_theme_stylebox_override("panel", _create_panel_style())
	dialog_panel.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.name = "DialogVBox"
	vbox.add_theme_constant_override("separation", 12)
	vbox.position = Vector2(20, 20)
	vbox.custom_minimum_size = Vector2(460, 280)
	panel.add_child(vbox)

	var title = Label.new()
	title.name = "DialogTitle"
	title.text = "🏰 村长"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.98, 0.85, 0.4))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var dialog_text = Label.new()
	dialog_text.name = "DialogText"
	dialog_text.text = "勇敢的冒险者啊，森林深处最近出现了一些魔物，\n村庄的安全受到了威胁。\n\n你愿意前往森林调查并清除这些威胁吗？"
	dialog_text.add_theme_font_size_override("font_size", 16)
	dialog_text.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	dialog_text.custom_minimum_size = Vector2(460, 120)
	vbox.add_child(dialog_text)

	var hbox = HBoxContainer.new()
	hbox.name = "ButtonHBox"
	hbox.add_theme_constant_override("separation", 16)
	vbox.add_child(hbox)

	var btn_accept = Button.new()
	btn_accept.name = "BtnAccept"
	btn_accept.text = "✅ 接受任务，前往森林"
	btn_accept.custom_minimum_size = Vector2(220, 44)
	btn_accept.add_theme_font_size_override("font_size", 14)
	btn_accept.add_theme_stylebox_override("normal", _create_button_style(Color(0.2, 0.6, 0.3)))
	btn_accept.add_theme_stylebox_override("hover", _create_button_style(Color(0.25, 0.7, 0.35)))
	btn_accept.add_theme_stylebox_override("pressed", _create_button_style(Color(0.15, 0.45, 0.25)))
	btn_accept.add_theme_color_override("font_color", Color(1, 1, 1))
	btn_accept.pressed.connect(_on_accept_quest)
	hbox.add_child(btn_accept)

	var btn_refuse = Button.new()
	btn_refuse.name = "BtnRefuse"
	btn_refuse.text = "❌ 我还需要准备一下"
	btn_refuse.custom_minimum_size = Vector2(220, 44)
	btn_refuse.add_theme_font_size_override("font_size", 14)
	btn_refuse.add_theme_stylebox_override("normal", _create_button_style(Color(0.6, 0.2, 0.2)))
	btn_refuse.add_theme_stylebox_override("hover", _create_button_style(Color(0.7, 0.25, 0.25)))
	btn_refuse.add_theme_stylebox_override("pressed", _create_button_style(Color(0.45, 0.15, 0.15)))
	btn_refuse.add_theme_color_override("font_color", Color(1, 1, 1))
	btn_refuse.pressed.connect(_on_refuse_quest)
	hbox.add_child(btn_refuse)

	var viewport_size = get_viewport().get_visible_rect().size
	panel.position = Vector2(
		(viewport_size.x - panel.custom_minimum_size.x) / 2,
		(viewport_size.y - panel.custom_minimum_size.y) / 2
	)

	panel_open = true
	if hint_label:
		hint_label.visible = false

func _create_panel_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.25)
	style.set_corner_radius_all(12)
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.6, 0.5, 0.7)
	return style

func _create_button_style(color: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(8)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = color.lightened(0.2)
	return style

func _on_accept_quest():
	if destination_scene != "":
		close_dialog_panel()
		get_tree().call_deferred("change_scene_to_file", destination_scene)

func _on_refuse_quest():
	close_dialog_panel()

func close_dialog_panel():
	if is_instance_valid(dialog_panel):
		dialog_panel.queue_free()
		dialog_panel = null
	panel_open = false
	if player_nearby and hint_label:
		hint_label.visible = true

func play_anim(anim: String):
	if not is_instance_valid(animated_sprite):
		return
	var candidates: Array = [
		"village_head_" + anim,
		"village head_" + anim,
		"merchant_" + anim,
		"merchant",
		anim,
	]
	for name in candidates:
		if animated_sprite.sprite_frames.has_animation(name):
			animated_sprite.play(name)
			return
