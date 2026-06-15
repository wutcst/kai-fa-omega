extends Control

@onready var bg: TextureRect = $Background
@onready var btn_start: Button = $CenterContainer/VBoxContainer/btn_start
@onready var music: AudioStreamPlayer = $Music

func _ready():
	# 让界面尺寸 = 图片实际尺寸，蓝色框刚好包住整张图
	if bg and bg.texture:
		var img_size = bg.texture.get_size()
		custom_minimum_size = img_size
		size = img_size

	# 播放背景音乐（循环）
	if music and music.stream:
		music.volume_db = -10.0  # 调低音量避免太响，可自行调整（-60~0）
		music.play()

	btn_start.pressed.connect(_on_start_pressed)

func _on_start_pressed():
	# 切场景前停止音乐
	if music:
		music.stop()
	get_tree().change_scene_to_file("res://scenes/village.tscn")
