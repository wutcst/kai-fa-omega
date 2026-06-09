extends Node

# 把 Job 定义移到这里
enum Job {
	SWORDSMAN,
	RANGER,
	SHIELD_KNIGHT
}

# 玩家全部数据
var max_hp: int = 100
var current_hp: int = 100
var max_mp: int = 50
var current_mp: int = 50

var attack: int = 10
var defense: int = 5
var base_speed: int = 180
var current_speed: int = 180

var level: int = 1
var current_exp: int = 0
var exp_to_next_level: int = 50
var level_up_growth: float = 1.2

<<<<<<< HEAD
# 暴击率（百分比）
var crit: int = 5

# 这里直接用 GameData.Job 类型
var current_job: GameData.Job = GameData.Job.SWORDSMAN

# 装备栏数据
var weapon: Dictionary = {"name": "铁剑", "icon": "", "attack_bonus": 3, "description": "一把普通的铁剑"}
var armor: Dictionary = {"name": "皮甲", "icon": "", "defense_bonus": 2, "description": "轻便的皮甲"}
var accessory: Dictionary = {"name": "无", "icon": "", "hp_bonus": 0, "description": "饰品槽位"}

# 道具栏数据 [{name, quantity, icon, description}, ...]
var inventory_items: Array = [
	{"name": "血瓶", "quantity": 3, "icon": "", "description": "恢复30点生命值"},
	{"name": "蓝瓶", "quantity": 2, "icon": "", "description": "恢复20点魔法值"},
]

# 已击败的怪物位置列表（用于场景重载后清除怪物）
var defeated_monster_positions: Array = []
=======
# 这里直接用 GameData.Job 类型
var current_job: GameData.Job = GameData.Job.SWORDSMAN

# 已击败的怪物位置列表（用于场景重载后清除怪物）
var defeated_monster_positions: Array = []
>>>>>>> 0b2bfa1a62c3e00c6bd4d14bcde8261b0e4bb72c
