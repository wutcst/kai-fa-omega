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
	combat_ui.refresh_skill_locks()
	combat_ui.update_exp_bar()

func _update_skill_buttons():
	combat_ui.btn_skill1.text = "斩击"
	combat_ui.btn_skill2.text = "重斩(15MP)"
	combat_ui.btn_skill3.text = "破甲斩(20MP)"
	combat_ui.btn_skill4.text = "怒斩苍穹(30MP)"

func _on_skill1():
	print("→ 玩家点击了【技能1：斩击】")
	BattleManager.use_skill(1)

func _on_skill2():
	print("→ 玩家点击了【技能2：重斩】")
	BattleManager.use_skill(2)

func _on_skill3():
	print("→ 玩家点击了【技能3：破甲斩】")
	BattleManager.use_skill(3)

func _on_skill4():
	print("→ 玩家点击了【技能4：怒斩苍穹】")
	BattleManager.use_skill(4)

func _on_player_escape():
	print("→ 玩家点击了【逃跑】")
	BattleManager.try_escape()

func _on_use_heal_potion():
	print("→ 玩家使用了【血瓶】，恢复HP")
	BattleManager.use_heal_potion()

func _on_use_mana_potion():
	print("→ 玩家使用了【蓝瓶】，恢复MP")
	BattleManager.use_mana_potion()
