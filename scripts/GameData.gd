extends Node

# 玩家全部数据
var max_hp: int = 150
var current_hp: int = 150
var max_mp: int = 50
var current_mp: int = 50

var attack: int = 12
var defense: int = 8
var base_speed: int = 200
var current_speed: int = 200

var level: int = 1
var current_exp: int = 0
var exp_to_next_level: int = 50
var level_up_growth: float = 1.2

# 暴击率（百分比）
var crit: int = 5

# 装备栏数据
var weapon: Dictionary = {"name": "铁剑", "icon": "res://Asset Bundle/sprites/SwordPack/SwordPack-IronSword.png", "attack_bonus": 3, "description": "一把普通的铁剑"}
var armor: Dictionary = {"name": "皮甲", "icon": "res://Asset Bundle/sprites/chainmail/wuxia_chainmail_ancient_bronze_32x32.png", "defense_bonus": 2, "description": "轻便的皮甲"}
var accessory: Dictionary = {"name": "无", "icon": "res://Asset Bundle/sprites/ring/1.png", "hp_bonus": 0, "description": "饰品槽位"}

# 道具栏数据 [{name, quantity, icon, description}, ...]
var inventory_items: Array = [
	{"name": "血瓶", "quantity": 3, "icon": "res://Asset Bundle/sprites/PotionPack/red_potion.png", "description": "恢复30点生命值"},
	{"name": "蓝瓶", "quantity": 2, "icon": "res://Asset Bundle/sprites/PotionPack/blue_potion.png", "description": "恢复20点魔法值"},
]

# 已击败的怪物位置列表（用于场景重载后清除怪物）
var defeated_monster_positions: Array = []

# 战斗逃跑/结束后返回地图时的玩家位置
var returning_from_battle: bool = false
var player_return_position: Vector2 = Vector2.ZERO

# 技能解锁等级 [斩击, 重斩, 破甲斩, 怒斩苍穹]
const SKILL_REQ: Array = [1, 2, 4, 7]

func is_skill_unlocked(index: int) -> bool:
	if index < 0 or index >= SKILL_REQ.size():
		return false
	return level >= SKILL_REQ[index]

func get_skill_req_level(index: int) -> int:
	if index < 0 or index >= SKILL_REQ.size():
		return 99
	return SKILL_REQ[index]

# 获取装备加成后的总攻击力
func get_total_attack() -> int:
	var bonus = weapon.get("attack_bonus", 0) if weapon else 0
	if bonus is int:
		return attack + bonus
	return attack

# 获取装备加成后的总防御力
func get_total_defense() -> int:
	var bonus = armor.get("defense_bonus", 0) if armor else 0
	if bonus is int:
		return defense + bonus
	return defense

# 获取装备加成后的总生命值
func get_total_max_hp() -> int:
	var bonus = accessory.get("hp_bonus", 0) if accessory else 0
	if bonus is int:
		return max_hp + bonus
	return max_hp
