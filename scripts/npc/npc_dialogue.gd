extends CharacterBody2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

@export var npc_name: String = "NPC"
@export_multiline var dialogue_text: String = "..."
@export var interaction_range: float = 120.0

var dialog_panel: CanvasLayer = null
var panel_open: bool = false
var player_nearby: bool = false
var hint_label: Label = null
var _e_was_pressed: bool = false

func _ready():
	add_to_group("npc")
	play_anim()
	_setup_hint_label()

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

func _physics_process(_delta):
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var distance = global_position.distance_to(player.global_position)
		var was_nearby = player_nearby
		player_nearby = distance < interaction_range

		if player_nearby and not was_nearby:
			if hint_label:
				hint_label.visible = true
		elif not player_nearby and was_nearby:
			if hint_label:
				hint_label.visible = false

	var e_pressed = Input.is_key_pressed(KEY_E)
	var e_just_pressed = e_pressed and not _e_was_pressed
	_e_was_pressed = e_pressed

	if e_just_pressed:
		if panel_open:
			close_dialog_panel()
		elif player_nearby:
			open_dialog_panel()

func open_dialog_panel():
	if dialog_panel != null:
		return

	dialog_panel = CanvasLayer.new()
	dialog_panel.name = "NPCDialog"
	dialog_panel.layer = 100
	get_tree().root.add_child(dialog_panel)

	var panel = PanelContainer.new()
	panel.name = "DialogPanel"
	panel.custom_minimum_size = Vector2(460, 240)
	panel.add_theme_stylebox_override("panel", _create_panel_style())
	dialog_panel.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.name = "DialogVBox"
	vbox.add_theme_constant_override("separation", 12)
	vbox.position = Vector2(20, 20)
	vbox.custom_minimum_size = Vector2(420, 200)
	panel.add_child(vbox)

	var title = Label.new()
	title.name = "DialogTitle"
	title.text = npc_name
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.98, 0.85, 0.4))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var separator = HSeparator.new()
	separator.custom_minimum_size = Vector2(420, 4)
	vbox.add_child(separator)

	var dialog_text = Label.new()
	dialog_text.name = "DialogText"
	dialog_text.text = dialogue_text
	dialog_text.add_theme_font_size_override("font_size", 16)
	dialog_text.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	dialog_text.custom_minimum_size = Vector2(420, 80)
	dialog_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialog_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	vbox.add_child(dialog_text)

	var close_hint = Label.new()
	close_hint.name = "CloseHint"
	close_hint.text = "按 E 关闭"
	close_hint.add_theme_font_size_override("font_size", 13)
	close_hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	close_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(close_hint)

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
	style.bg_color = Color(0.12, 0.12, 0.22)
	style.set_corner_radius_all(12)
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.5, 0.4, 0.6)
	return style

func close_dialog_panel():
	if is_instance_valid(dialog_panel):
		dialog_panel.queue_free()
		dialog_panel = null
	panel_open = false
	if player_nearby and hint_label:
		hint_label.visible = true

func play_anim():
	if not is_instance_valid(animated_sprite):
		return
	var names = animated_sprite.sprite_frames.get_animation_names()
	if names.size() > 0:
		animated_sprite.play(names[0])