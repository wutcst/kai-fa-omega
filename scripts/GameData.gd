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

# 第一个贴图（初始装备使用）
const DEFAULT_WEAPON_ICON = "res://Asset Bundle/sprites/SwordPack/SwordPack-IronSword.png"
const DEFAULT_ARMOR_ICON = "res://Asset Bundle/sprites/chainmail/wuxia_chainmail_ancient_bronze_32x32.png"
const DEFAULT_ACCESSORY_ICON = "res://Asset Bundle/sprites/ring/1.png"

# 第二个贴图（专属背包栏使用）
const SECOND_WEAPON_ICON = "res://Asset Bundle/sprites/SwordPack/SwordPack-FireSword.png"
const SECOND_ARMOR_ICON = "res://Asset Bundle/sprites/chainmail/wuxia_chainmail_divine_gold_inlaid_wood_32x32.png"
const SECOND_ACCESSORY_ICON = "res://Asset Bundle/sprites/ring/2.png"

# 空槽位模板（用于装备被脱下后）
const EMPTY_SLOT_DATA = {"name": "无", "attack_bonus": 0, "defense_bonus": 0, "hp_bonus": 0, "description": "空槽位"}

# 装备栏初始数据（第一个贴图，都有装备）
var weapon: Dictionary = {"name": "铁剑", "icon": DEFAULT_WEAPON_ICON, "attack_bonus": 3, "description": "一把普通的铁剑"}
var armor: Dictionary = {"name": "皮甲", "icon": DEFAULT_ARMOR_ICON, "defense_bonus": 2, "description": "轻便的皮甲"}
var accessory: Dictionary = {"name": "银戒", "icon": DEFAULT_ACCESSORY_ICON, "hp_bonus": 10, "description": "散发微光的银戒"}

# 专属背包栏初始数据（第二个贴图，武器+护甲+饰品各一个）
var exclusive_backpack: Array = [
	{"name": "火焰剑", "icon": SECOND_WEAPON_ICON, "type": "weapon", "attack_bonus": 5, "description": "燃烧着烈焰的魔剑"},
	{"name": "神金甲", "icon": SECOND_ARMOR_ICON, "type": "armor", "defense_bonus": 4, "description": "镶嵌黄金的神圣护甲"},
	{"name": "力量戒指", "icon": SECOND_ACCESSORY_ICON, "type": "accessory", "hp_bonus": 20, "description": "蕴含神秘力量的戒指"},
]

# 道具栏数据
var inventory_items: Array = [
	{"name": "血瓶", "quantity": 3, "icon": "res://Asset Bundle/sprites/PotionPack/red_potion.png", "description": "恢复30点生命值"},
	{"name": "蓝瓶", "quantity": 2, "icon": "res://Asset Bundle/sprites/PotionPack/blue_potion.png", "description": "恢复20点魔法值"},
]

# 已击败的怪物位置列表
var defeated_monster_positions: Array = []

# 战斗逃跑/结束后返回地图时的玩家位置
var returning_from_battle: bool = false
var player_return_position: Vector2 = Vector2.ZERO

# 技能解锁等级
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

# 穿戴饰品：同步生命加成到当前生命值
func equip_accessory(new_accessory: Dictionary):
	var hp_bonus = new_accessory.get("hp_bonus", 0)
	if hp_bonus > 0:
		current_hp += hp_bonus
	accessory = new_accessory.duplicate()

# 卸下饰品：从当前生命值扣除加成
func unequip_accessory():
	var hp_bonus = accessory.get("hp_bonus", 0)
	if hp_bonus > 0:
		current_hp -= hp_bonus
		if current_hp < 1:
			current_hp = 1
	accessory = EMPTY_SLOT_DATA.duplicate()
	accessory["icon"] = DEFAULT_ACCESSORY_ICON

# 等级提升：增加属性
func level_up():
	level += 1
	max_hp += 20
	max_mp += 10
	attack += 3
	defense += 2
	base_speed += 10
	current_speed = base_speed
	current_hp = max_hp
	current_mp = max_mp
	exp_to_next_level = int(exp_to_next_level * level_up_growth)
	current_exp = 0
	print("→ 升级！当前等级：Lv.", level, "  HP:", max_hp, "  MP:", max_mp)