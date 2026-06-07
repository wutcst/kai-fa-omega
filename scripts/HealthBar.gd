# 挂在 HUD 或 ProgressBar 父节点
extends Control

@onready var health_bar = $ProgressBar
@onready var player = get_node("res://scenes/player-battler.tscn")  # 你的玩家路径

func _process(delta):
	if player:
		health_bar.max_value = player.max_health
		health_bar.value = player.current_health
