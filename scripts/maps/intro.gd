extends Node2D

var _lines = [
	"百年前恶龙被封印于地底深处，大陆恢复和平，人们在平原建起宁静村庄。",
	"地底魔力滋生出四季魔法森林、骸骨遗迹，无数魔物盘踞其中。",
	"如今封印松动，怪物涌出侵扰村落。",
	"身为村中剑士的你，为守护家园，独自踏上深入地下、讨伐恶龙的冒险之路。",
	"前路的战斗、成长与试炼，正等待着你。"
]

const BGM_PATH = "res://Asset Bundle/musictales/the_field_of_dreams.mp3"

var _current_index: int = 0
var _label: Label = null
var _hint_label: Label = null
var _bg: ColorRect = null
var _bgm_player: AudioStreamPlayer = null

func _ready():
	var viewport_size = get_viewport().get_visible_rect().size

	_bg = ColorRect.new()
	_bg.color = Color(0, 0, 0, 1)
	_bg.size = viewport_size
	add_child(_bg)

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 24)
	_label.add_theme_color_override("font_color", Color(1, 0.95, 0.85, 1))
	_label.size = viewport_size
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.text = ""
	add_child(_label)

	_hint_label = Label.new()
	_hint_label.text = "按 E 继续"
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.add_theme_font_size_override("font_size", 16)
	_hint_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_hint_label.position = Vector2(0, viewport_size.y - 60)
	_hint_label.size = Vector2(viewport_size.x, 40)
	add_child(_hint_label)

	_play_bgm()

func _input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E:
			get_viewport().set_input_as_handled()
			if _current_index < _lines.size():
				_label.text = _lines[_current_index]
				_label.modulate.a = 0
				var tween = create_tween()
				tween.tween_property(_label, "modulate:a", 1.0, 0.6)
				_current_index += 1
			else:
				if _bgm_player:
					_bgm_player.stop()
				GameData.show_village_welcome = true
				get_tree().change_scene_to_file("res://scenes/maps/village.tscn")

func _play_bgm():
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.name = "IntroBGM"
	_bgm_player.bus = "Master"
	_bgm_player.volume_db = -8.0
	add_child(_bgm_player)
	var stream = load(BGM_PATH)
	if stream and stream is AudioStream:
		_bgm_player.stream = stream
		_bgm_player.play()