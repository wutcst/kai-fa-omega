extends Node2D

@onready var combat_ui: CombatUI = $CombatUI

func _ready():
	combat_ui.skill1_pressed.connect(_on_skill1)
	combat_ui.skill2_pressed.connect(_on_skill2)
	combat_ui.skill3_pressed.connect(_on_skill3)
	combat_ui.skill4_pressed.connect(_on_skill4)
	combat_ui.escape_pressed.connect(_on_player_escape)
	combat_ui.heal_pressed.connect(_on_use_heal_potion)
	combat_ui.mana_pressed.connect(_on_use_mana_potion)

func _on_skill1():
	print("玩家点击了【技能1】")

func _on_skill2():
	print("玩家点击了【技能2】")

func _on_skill3():
	print("玩家点击了【技能3】")

func _on_skill4():
	print("玩家点击了【技能4】")

func _on_player_escape():
	print("玩家点击了【逃跑】")

func _on_use_heal_potion():
	print("玩家使用了【血瓶】，恢复HP")

func _on_use_mana_potion():
	print("玩家使用了【蓝瓶】，恢复MP")
