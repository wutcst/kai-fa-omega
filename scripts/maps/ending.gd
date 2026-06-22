extends Node2D

var _lines = [
	"亡灵法师的身躯在光芒中消散，地底的黑暗魔力随之溃散。",
	"封印重新稳固，盘踞地下的魔物失去力量源泉，纷纷化为尘土。",
	"你拖着疲惫的身躯走出地牢，阳光洒在铠甲上，温暖而明亮。",
	"村庄的钟声响起，人们涌出家门，迎接归来的英雄。",
	"从此，大陆重归和平，而你的名字，将永远铭刻在村落的石碑之上。",
	"— 感谢游玩 —"
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
				get_tree().change_scene_to_file("res://scenes/maps/start.tscn")


func _play_bgm():
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.name = "EndingBGM"
	_bgm_player.bus = "Master"
	_bgm_player.volume_db = -8.0
	add_child(_bgm_player)
	var stream = load(BGM_PATH)
	if stream and stream is AudioStream:
		_bgm_player.stream = stream
		_bgm_player.play()
