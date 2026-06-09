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

# 这里直接用 GameData.Job 类型
var current_job: GameData.Job = GameData.Job.SWORDSMAN

# 已击败的怪物位置列表（用于场景重载后清除怪物）
var defeated_monster_positions: Array = []
