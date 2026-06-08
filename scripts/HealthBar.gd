<<<<<<< HEAD
# 挂在 HUD 或 ProgressBar 父节点
extends Control

@onready var health_bar = $ProgressBar
@onready var player = get_node("res://scenes/player-battler.tscn")  # 你的玩家路径

func _process(delta):
	if player:
		health_bar.max_value = player.max_health
		health_bar.value = player.current_health
=======
extends Control

@onready var health_bar = $ProgressBar
var player: Node2D = null

func _ready():
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]

func _process(_delta):
	if player and is_instance_valid(player):
		health_bar.max_value = player.max_hp
		health_bar.value = player.current_hp
>>>>>>> zlfui
