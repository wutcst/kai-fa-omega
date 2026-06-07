extends Node2D

# 当场景加载好后，自动监听所有怪物
func _ready():
	# 找到所有怪物，监听它们的进入战斗信号
	for enemy in get_tree().get_nodes_in_group("enemy"):
		enemy.enter_battle.connect(_on_enter_battle)

# 一旦任何怪物触发战斗 → 全场静止
func _on_enter_battle(attacking_monster):
	# 1. 让玩家静止
	var player = get_tree().get_nodes_in_group("player")[0]
	player.in_battle = true

	# 2. 让所有怪物静止
	for monster in get_tree().get_nodes_in_group("monster"):
		monster.in_battle = true

	print("战斗开始！全场静止！")
