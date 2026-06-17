extends Area2D

@export var target_scene: String = "res://scenes/maps/undead.tscn"
@export var hint_text: String = "按 E 与树灵对话"
@export var dialog_title: String = "🌳 树灵"
@export var dialog_text_content: String = "年轻的冒险者啊，我是这片森林的守护之灵。\n\n前方是不死族的领地，充满了亡灵的怨念。\n那里的邪恶力量正在不断扩张…\n\n你是否已经准备好，前往那片诅咒之地？"
@export var accept_text: String = "✅ 我已准备好，前往不死族领地"
@export var title_color: Color = Color(0.4, 0.9, 0.5)
@export var panel_bg_color: Color = Color(0.1, 0.2, 0.15)
@export var panel_border_color: Color = Color(0.4, 0.7, 0.5)

var hint_label: Label = null
var player_nearby: bool = false
var dialog_panel: CanvasLayer = null
var panel_open: bool = false

func _ready():
	add_to_group("enter_portal")
	z_index = 100
	_setup_hint_label()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _setup_hint_label():
	hint_label = Label.new()
	hint_label.text = hint_text
	hint_label.add_theme_font_size_override("font_size", 14)
	hint_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_constant_override("outline_size", 2)
	hint_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	hint_label.custom_minimum_size = Vector2(120, 24)
	hint_label.z_index = 100
	hint_label.visible = false
	add_child(hint_label)
	_update_hint_position()

func _update_hint_position():
	if hint_label == null:
		return
	var shape_node = get_node_or_null("CollisionShape2D")
	if shape_node and shape_node.shape:
		var rect: RectangleShape2D = shape_node.shape
		var shape_offset = shape_node.position
		var center = shape_offset + rect.size / 2
		hint_label.position = Vector2(center.x - 80, center.y - 32)
	else:
		hint_label.position = Vector2(-60, -40)

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
	dialog_panel.name = "TreeSpiritDialog"
	dialog_panel.layer = 100
	get_tree().root.add_child(dialog_panel)

	var panel = PanelContainer.new()
	panel.name = "DialogPanel"
	panel.custom_minimum_size = Vector2(520, 340)
	panel.add_theme_stylebox_override("panel", _create_panel_style())
	dialog_panel.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.name = "DialogVBox"
	vbox.add_theme_constant_override("separation", 12)
	vbox.position = Vector2(20, 20)
	vbox.custom_minimum_size = Vector2(480, 300)
	panel.add_child(vbox)

	var title = Label.new()
	title.name = "DialogTitle"
	title.text = dialog_title
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", title_color)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var dialog_text = Label.new()
	dialog_text.name = "DialogText"
	dialog_text.text = dialog_text_content
	dialog_text.add_theme_font_size_override("font_size", 16)
	dialog_text.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	dialog_text.custom_minimum_size = Vector2(480, 140)
	vbox.add_child(dialog_text)

	var hbox = HBoxContainer.new()
	hbox.name = "ButtonHBox"
	hbox.add_theme_constant_override("separation", 16)
	vbox.add_child(hbox)

	var btn_accept = Button.new()
	btn_accept.name = "BtnAccept"
	btn_accept.text = accept_text
	btn_accept.custom_minimum_size = Vector2(230, 44)
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
	btn_refuse.custom_minimum_size = Vector2(230, 44)
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
	style.bg_color = panel_bg_color
	style.set_corner_radius_all(12)
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_color = panel_border_color
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
	close_dialog_panel()
	if target_scene != "":
		get_tree().call_deferred("change_scene_to_file", target_scene)

func _on_refuse_quest():
	close_dialog_panel()

func close_dialog_panel():
	if is_instance_valid(dialog_panel):
		dialog_panel.queue_free()
		dialog_panel = null
	panel_open = false
	if player_nearby and hint_label:
		hint_label.visible = true
