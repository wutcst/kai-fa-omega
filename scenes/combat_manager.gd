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

	_update_skill_buttons()

func _update_skill_buttons():
	combat_ui.btn_skill1.text = "普通攻击"
	combat_ui.btn_skill2.text = "强力攻击"
	combat_ui.btn_skill3.text = "治疗术"
	combat_ui.btn_skill4.text = "必杀技"

func _on_skill1():
	print("→ 玩家点击了【技能1：普通攻击】")
	BattleManager.use_skill(1)

func _on_skill2():
	print("→ 玩家点击了【技能2：强力攻击】")
	BattleManager.use_skill(2)

func _on_skill3():
	print("→ 玩家点击了【技能3：治疗术】")
	BattleManager.use_skill(3)

func _on_skill4():
	print("→ 玩家点击了【技能4：必杀技】")
	BattleManager.use_skill(4)

func _on_player_escape():
	print("→ 玩家点击了【逃跑】")
	BattleManager.try_escape()

func _on_use_heal_potion():
	print("→ 玩家使用了【血瓶】，恢复HP")
	BattleManager.use_heal_potion()

func _on_use_mana_potion():
	print("→ 玩家使用了【蓝瓶】，恢复MP")
<<<<<<< HEAD
	BattleManager.use_mana_potion()
=======
	BattleManager.use_mana_potion()
>>>>>>> 0b2bfa1a62c3e00c6bd4d14bcde8261b0e4bb72c
