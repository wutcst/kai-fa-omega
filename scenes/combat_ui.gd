extends CanvasLayer
class_name CombatUI  # 关键！解决类型找不到问题

# 技能栏（左下4个技能按钮）
@onready var btn_skill1: Button = $SkillBar/btn_skill1
@onready var btn_skill2: Button = $SkillBar/btn_skill2
@onready var btn_skill3: Button = $SkillBar/btn_skill3
@onready var btn_skill4: Button = $SkillBar/btn_skill4

# 主操作栏（右下：道具+逃跑）
@onready var btn_item: Button = $ActionBar/btn_item
@onready var btn_escape: Button = $ActionBar/btn_escape

# 道具展开栏（血瓶+蓝瓶，默认隐藏）
@onready var item_bar: VBoxContainer = $ItemBar
@onready var btn_heal: Button = $ItemBar/btn_heal
@onready var btn_mana: Button = $ItemBar/btn_mana

# 对外信号
signal skill1_pressed()
signal skill2_pressed()
signal skill3_pressed()
signal skill4_pressed()
signal escape_pressed()
signal heal_pressed()
signal mana_pressed()

func _ready():
	btn_skill1.text = "技能1"
	btn_skill2.text = "技能2"
	btn_skill3.text = "技能3"
	btn_skill4.text = "技能4"
	btn_item.text = "道具"
	btn_escape.text = "逃跑"
	btn_heal.text = "血瓶"
	btn_mana.text = "蓝瓶"

	item_bar.visible = false

	_set_button_colors()

	btn_skill1.pressed.connect(skill1_pressed.emit)
	btn_skill2.pressed.connect(skill2_pressed.emit)
	btn_skill3.pressed.connect(skill3_pressed.emit)
	btn_skill4.pressed.connect(skill4_pressed.emit)
	btn_item.pressed.connect(_toggle_item_bar)
	btn_escape.pressed.connect(escape_pressed.emit)
	btn_heal.pressed.connect(_on_heal_clicked)
	btn_mana.pressed.connect(_on_mana_clicked)

func _toggle_item_bar():
	item_bar.visible = !item_bar.visible

func _on_heal_clicked():
	heal_pressed.emit()
	item_bar.visible = false

func _on_mana_clicked():
	mana_pressed.emit()
	item_bar.visible = false

func set_buttons_enabled(enabled: bool):
	btn_skill1.disabled = not enabled
	btn_skill2.disabled = not enabled
	btn_skill3.disabled = not enabled
	btn_skill4.disabled = not enabled
	btn_item.disabled = not enabled
	btn_escape.disabled = not enabled
	btn_heal.disabled = not enabled
	btn_mana.disabled = not enabled

func _set_button_colors():
	var skill_colors = [
		Color(0.27, 0.45, 0.86),
		Color(0.4, 0.73, 0.93),
		Color(0.98, 0.67, 0.27),
		Color(0.44, 0.8, 0.44)
	]
	_set_btn_style(btn_skill1, skill_colors[0])
	_set_btn_style(btn_skill2, skill_colors[1])
	_set_btn_style(btn_skill3, skill_colors[2])
	_set_btn_style(btn_skill4, skill_colors[3])

	_set_btn_style(btn_heal, Color(0.8, 0.2, 0.2))
	_set_btn_style(btn_mana, Color(0.2, 0.5, 0.8))

	var action_color = Color(0.3, 0.3, 0.3)
	_set_btn_style(btn_item, action_color)
	_set_btn_style(btn_escape, action_color)

func _set_btn_style(btn: Button, bg_color: Color):
	var normal = StyleBoxFlat.new()
	normal.bg_color = bg_color
	normal.set_corner_radius_all(6)  # 4.3 用这个方法

	btn.custom_minimum_size = Vector2(150, 60)   # 调这里，数值越大按钮越大
	var hover = normal.duplicate()
	hover.bg_color = bg_color.lightened(0.15)

	var pressed = normal.duplicate()
	pressed.bg_color = bg_color.darkened(0.15)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_color", Color(1, 1, 1))
