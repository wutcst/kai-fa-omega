extends Node

# ============================================================
# 玩家基础属性
# ============================================================
var max_hp: int = 120
var current_hp: int = 120
var max_mp: int = 60
var current_mp: int = 60

var attack: int = 15
var defense: int = 5
var base_speed: int = 200
var current_speed: int = 200

var level: int = 1
var current_exp: int = 0
var exp_to_next_level: int = 50
var level_up_growth: float = 1.3

# 暴击率（百分比）
var crit: int = 5

# 货币（金币）
var gold: int = 50

var show_village_welcome: bool = false

# ============================================================
# 图片资源路径
# ============================================================
const SPR_ROOT = "res://Asset Bundle/sprites"
const SWORD_ROOT = SPR_ROOT + "/SwordPack"
const ARMOR_ROOT = SPR_ROOT + "/chainmail"
const RING_ROOT = SPR_ROOT + "/ring"
const POTION_ROOT = SPR_ROOT + "/PotionPack"

# 铁剑 / 初始装备使用
const DEFAULT_WEAPON_ICON = SWORD_ROOT + "/SwordPack-IronSword.png"
const DEFAULT_ARMOR_ICON = ARMOR_ROOT + "/wuxia_chainmail_ancient_bronze_32x32.png"
const DEFAULT_ACCESSORY_ICON = RING_ROOT + "/1.png"

# 药水图标
const POTION_HEAL = POTION_ROOT + "/red_potion.png"
const POTION_MANA = POTION_ROOT + "/blue_potion.png"

# ============================================================
# 五套装备（每套：武器 + 护甲 + 饰品）
#   tier 1~5：等级由低到高，数值递增
# ============================================================
const EQUIPMENT_SETS := [
	# 套装 1：生铁套装（入门）
	{
		"name": "生铁套装",
		"tier": 1,
		"weapon":
		{
			"name": "生铁剑",
			"icon": SWORD_ROOT + "/SwordPack-ShortSword.png",
			"attack_bonus": 2,
			"type": "weapon",
			"description": "粗糙的生铁打造的短剑",
			"tier": 1
		},
		"armor":
		{
			"name": "皮甲",
			"icon": ARMOR_ROOT + "/wuxia_chainmail_worn_leather_32x32.png",
			"defense_bonus": 1,
			"type": "armor",
			"description": "磨损的皮甲，聊胜于无",
			"tier": 1
		},
		"accessory":
		{
			"name": "铜戒",
			"icon": RING_ROOT + "/1.png",
			"hp_bonus": 8,
			"type": "accessory",
			"description": "散发微光的铜制戒指",
			"tier": 1
		},
	},
	# 套装 2：寒铁套装
	{
		"name": "寒铁套装",
		"tier": 2,
		"weapon":
		{
			"name": "寒铁长剑",
			"icon": SWORD_ROOT + "/SwordPack-LongSword.png",
			"attack_bonus": 5,
			"type": "weapon",
			"description": "剑刃透出寒气，锋锐非常",
			"tier": 2
		},
		"armor":
		{
			"name": "锻铁甲",
			"icon": ARMOR_ROOT + "/wuxia_chainmail_forged_iron_32x32.png",
			"defense_bonus": 3,
			"type": "armor",
			"description": "反复锤炼的铁甲，坚固耐用",
			"tier": 2
		},
		"accessory":
		{
			"name": "银光戒",
			"icon": RING_ROOT + "/2.png",
			"hp_bonus": 18,
			"type": "accessory",
			"description": "蕴含温厚灵力的银戒",
			"tier": 2
		},
	},
	# 套装 3：烈焰套装
	{
		"name": "烈焰套装",
		"tier": 3,
		"weapon":
		{
			"name": "烈焰剑",
			"icon": SWORD_ROOT + "/SwordPack-FireSword.png",
			"attack_bonus": 9,
			"type": "weapon",
			"description": "燃烧着烈焰的魔剑",
			"tier": 3
		},
		"armor":
		{
			"name": "赤岩甲",
			"icon": ARMOR_ROOT + "/wuxia_chainmail_rusty_stone_32x32.png",
			"defense_bonus": 5,
			"type": "armor",
			"description": "火岩凝成的重甲，抗击打",
			"tier": 3
		},
		"accessory":
		{
			"name": "烈焰戒",
			"icon": RING_ROOT + "/3.png",
			"hp_bonus": 32,
			"type": "accessory",
			"description": "戒指上刻有火焰纹章",
			"tier": 3
		},
	},
	# 套装 4：玄冰套装
	{
		"name": "玄冰套装",
		"tier": 4,
		"weapon":
		{
			"name": "寒冰之刃",
			"icon": SWORD_ROOT + "/SwordPack-IceSword.png",
			"attack_bonus": 14,
			"type": "weapon",
			"description": "永不融化的玄冰铸就",
			"tier": 4
		},
		"armor":
		{
			"name": "玄冰甲",
			"icon": ARMOR_ROOT + "/wuxia_chainmail_icy_frost_steel_32x32.png",
			"defense_bonus": 8,
			"type": "armor",
			"description": "散发寒气的冰霜重甲",
			"tier": 4
		},
		"accessory":
		{
			"name": "寒冰戒",
			"icon": RING_ROOT + "/4.png",
			"hp_bonus": 50,
			"type": "accessory",
			"description": "冷冽彻骨的冰蓝戒指",
			"tier": 4
		},
	},
	# 套装 5：神圣黄金套装（顶级）
	{
		"name": "神圣黄金套装",
		"tier": 5,
		"weapon":
		{
			"name": "黄金圣剑",
			"icon": SWORD_ROOT + "/SwordPack-GoldenSword.png",
			"attack_bonus": 22,
			"type": "weapon",
			"description": "黄金铸就的神圣长剑",
			"tier": 5
		},
		"armor":
		{
			"name": "神圣金甲",
			"icon": ARMOR_ROOT + "/wuxia_chainmail_divine_gold_inlaid_wood_32x32.png",
			"defense_bonus": 14,
			"type": "armor",
			"description": "镶嵌黄金的神圣护甲",
			"tier": 5
		},
		"accessory":
		{
			"name": "神圣戒指",
			"icon": RING_ROOT + "/5.png",
			"hp_bonus": 80,
			"type": "accessory",
			"description": "蕴含神圣之力的至尊戒指",
			"tier": 5
		},
	},
]

# 其他可选掉落的武器 / 护甲 / 饰品（随机填充背包栏）
const EXTRA_WEAPONS := [
	{
		"name": "暗影刃",
		"icon": SWORD_ROOT + "/SwordPack-ShadowBlade.png",
		"attack_bonus": 18,
		"type": "weapon",
		"description": "隐匿于阴影之中的利刃",
		"tier": 5
	},
	{
		"name": "钻石剑",
		"icon": SWORD_ROOT + "/SwordPack-DiamondSword.png",
		"attack_bonus": 26,
		"type": "weapon",
		"description": "钻石打造的锋利长剑",
		"tier": 5
	},
]
const EXTRA_ARMORS := [
	{
		"name": "乌金钢甲",
		"icon": ARMOR_ROOT + "/wuxia_chainmail_ebony_steel_32x32.png",
		"defense_bonus": 11,
		"type": "armor",
		"description": "乌黑泛光的钢制重甲",
		"tier": 4
	},
	{
		"name": "翡翠甲",
		"icon": ARMOR_ROOT + "/wuxia_chainmail_green_jade_32x32.png",
		"defense_bonus": 9,
		"type": "armor",
		"description": "翡翠镶嵌的玉石甲胄",
		"tier": 4
	},
	{
		"name": "自然木甲",
		"icon": ARMOR_ROOT + "/wuxia_chainmail_natural_wood_32x32.png",
		"defense_bonus": 7,
		"type": "armor",
		"description": "由灵木编织而成的轻甲",
		"tier": 3
	},
]
const EXTRA_RINGS := [
	{
		"name": "力量戒指",
		"icon": RING_ROOT + "/6.png",
		"hp_bonus": 40,
		"type": "accessory",
		"description": "蕴含神秘力量的戒指",
		"tier": 4
	},
	{
		"name": "敏捷戒指",
		"icon": RING_ROOT + "/7.png",
		"hp_bonus": 45,
		"type": "accessory",
		"description": "佩戴者身手敏捷",
		"tier": 4
	},
	{
		"name": "至尊金戒",
		"icon": RING_ROOT + "/10.png",
		"hp_bonus": 75,
		"type": "accessory",
		"description": "至尊奢华的黄金戒指",
		"tier": 5
	},
]

# 空槽位模板
const EMPTY_SLOT_DATA = {
	"name": "无",
	"icon": "",
	"type": "",
	"attack_bonus": 0,
	"defense_bonus": 0,
	"hp_bonus": 0,
	"description": "空槽位"
}

# ============================================================
# 当前穿戴的装备（默认空）
# ============================================================
var weapon: Dictionary = EMPTY_SLOT_DATA.duplicate(true)
var armor: Dictionary = EMPTY_SLOT_DATA.duplicate(true)
var accessory: Dictionary = EMPTY_SLOT_DATA.duplicate(true)

# ============================================================
# 背包栏（未装备的装备 + 道具）
#   exclusive_backpack：装备类 + 食物类
#   inventory_items  ：道具类（血瓶/蓝瓶）
# ============================================================
var exclusive_backpack: Array = []

# 食物道具配置表（商人购买后加入专属背包栏，点击使用）
# effect 字段：hp=回血 / mp=回蓝 / atk=永久加攻 / def=永久加防 / speed=永久加速 / crit=永久加暴击
# price 字段：每个食物的独立价格
const FOOD_TABLE: Array = [
	{
		"name": "苹果",
		"icon": "res://Asset Bundle/sprites/food/apple.png",
		"effect": "hp",
		"value": 30,
		"price": 12,
		"description": "恢复30点生命值"
	},
	{
		"name": "西瓜",
		"icon": "res://Asset Bundle/sprites/food/watermelon.png",
		"effect": "hp",
		"value": 60,
		"price": 25,
		"description": "恢复60点生命值"
	},
	{
		"name": "草莓",
		"icon": "res://Asset Bundle/sprites/food/strawberry.png",
		"effect": "mp",
		"value": 20,
		"price": 8,
		"description": "恢复20点魔法值"
	},
	{
		"name": "樱桃",
		"icon": "res://Asset Bundle/sprites/food/cherry.png",
		"effect": "mp",
		"value": 35,
		"price": 15,
		"description": "恢复35点魔法值"
	},
	{
		"name": "胡萝卜",
		"icon": "res://Asset Bundle/sprites/food/carrot.png",
		"effect": "atk",
		"value": 1,
		"price": 40,
		"description": "永久攻击力+1"
	},
	{
		"name": "汉堡",
		"icon": "res://Asset Bundle/sprites/food/burger.png",
		"effect": "def",
		"value": 1,
		"price": 40,
		"description": "永久防御力+1"
	},
	{
		"name": "薯条",
		"icon": "res://Asset Bundle/sprites/food/fries.png",
		"effect": "speed",
		"value": 5,
		"price": 35,
		"description": "永久基础速度+5"
	},
	{
		"name": "披萨",
		"icon": "res://Asset Bundle/sprites/food/pizza.png",
		"effect": "crit",
		"value": 1,
		"price": 30,
		"description": "永久暴击率+1%"
	},
	{
		"name": "火腿",
		"icon": "res://Asset Bundle/sprites/food/ham.png",
		"effect": "atk",
		"value": 2,
		"price": 75,
		"description": "永久攻击力+2"
	},
	{
		"name": "煎蛋",
		"icon": "res://Asset Bundle/sprites/food/egg.png",
		"effect": "hp",
		"value": 40,
		"price": 18,
		"description": "恢复40点生命值"
	},
	{
		"name": "寿司",
		"icon": "res://Asset Bundle/sprites/food/sushi.png",
		"effect": "def",
		"value": 2,
		"price": 75,
		"description": "永久防御力+2"
	},
]
const FOOD_TYPE: String = "food"


# 使用食物：返回是否成功
func use_food(item: Dictionary) -> bool:
	if item.get("type", "") != FOOD_TYPE:
		return false
	var effect = item.get("effect", "")
	var value = item.get("value", 0)
	match effect:
		"hp":
			current_hp = min(current_hp + value, get_total_max_hp())
		"mp":
			current_mp = min(current_mp + value, max_mp)
		"atk":
			attack += value
		"def":
			defense += value
		"speed":
			base_speed += value
			current_speed = base_speed
		"crit":
			crit += value
		_:
			return false
	return true


# 道具栏数据
var inventory_items: Array = [
	{
		"name": "血瓶",
		"quantity": 3,
		"icon": POTION_HEAL,
		"heal": 50,
		"type": "potion",
		"description": "恢复50点生命值"
	},
	{
		"name": "蓝瓶",
		"quantity": 2,
		"icon": POTION_MANA,
		"mana": 30,
		"type": "potion",
		"description": "恢复30点魔法值"
	},
]

# 已击败的怪物位置列表（主场景用）
var defeated_monster_positions: Array = []

# 已击败的首领位置列表（不清除，持久保留）
var defeated_boss_positions: Array = []

# 已击败的首领名称列表（用于解锁场景切换条件）
var defeated_boss_names: Array = []

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


# ============================================================
# 属性计算（含装备加成）
# ============================================================
func get_total_attack() -> int:
	var bonus = weapon.get("attack_bonus", 0) if weapon else 0
	if bonus is int:
		return attack + bonus
	return attack


func get_total_defense() -> int:
	var bonus = armor.get("defense_bonus", 0) if armor else 0
	if bonus is int:
		return defense + bonus
	return defense


func get_total_max_hp() -> int:
	var bonus = accessory.get("hp_bonus", 0) if accessory else 0
	if bonus is int:
		return max_hp + bonus
	return max_hp


# ============================================================
# 装备管理
# ============================================================
func equip_accessory(new_accessory: Dictionary):
	var hp_bonus = new_accessory.get("hp_bonus", 0)
	if hp_bonus > 0:
		current_hp += hp_bonus
	accessory = new_accessory.duplicate(true)
	current_hp = min(current_hp, get_total_max_hp())


func unequip_accessory():
	var hp_bonus = accessory.get("hp_bonus", 0)
	if hp_bonus > 0:
		current_hp -= hp_bonus
		if current_hp < 1:
			current_hp = 1
	accessory = EMPTY_SLOT_DATA.duplicate(true)
	accessory["icon"] = DEFAULT_ACCESSORY_ICON


# ============================================================
# 升级
# ============================================================
func level_up():
	if level >= 16:
		print("→ 已达最高等级 Lv.16，无法继续升级")
		return
	level += 1
	max_hp += 10
	max_mp += 5
	attack += 2
	defense += 1
	base_speed += 5
	current_speed = base_speed
	current_hp = get_total_max_hp()
	current_mp = max_mp
	exp_to_next_level = int(exp_to_next_level * level_up_growth)
	print(
		"→ 升级！当前等级：Lv.",
		level,
		"  HP:",
		get_total_max_hp(),
		"  MP:",
		max_mp,
		"  攻击:",
		attack,
		"  防御:",
		defense
	)


# ============================================================
# 掉落系统
#   输入：monster_name 用于决定掉落池；exp_reward 决定强度
#   输出：{"gold": int, "items": [装备/道具dict...]}
# ============================================================
# 怪物掉落配置表：每个怪物有自己的金币区间和掉落装备层级
const _MONSTER_CONFIG := {
	"rat": {"gold_min": 5, "gold_max": 12, "tier_min": 1, "tier_max": 2},
	"slime": {"gold_min": 3, "gold_max": 8, "tier_min": 1, "tier_max": 1},
	"bat": {"gold_min": 5, "gold_max": 12, "tier_min": 1, "tier_max": 2},
	"mushroom": {"gold_min": 2, "gold_max": 6, "tier_min": 1, "tier_max": 1},
	"goblin": {"gold_min": 15, "gold_max": 35, "tier_min": 2, "tier_max": 3},
	"skull": {"gold_min": 20, "gold_max": 45, "tier_min": 3, "tier_max": 4},
	"rock_giant": {"gold_min": 8, "gold_max": 20, "tier_min": 1, "tier_max": 2},
	"bone_knight": {"gold_min": 12, "gold_max": 28, "tier_min": 2, "tier_max": 3},
	"slime_king": {"gold_min": 15, "gold_max": 35, "tier_min": 2, "tier_max": 2},
	"Bringer": {"gold_min": 30, "gold_max": 60, "tier_min": 3, "tier_max": 4},
	"dragon": {"gold_min": 80, "gold_max": 150, "tier_min": 4, "tier_max": 5},
	"necromancer": {"gold_min": 150, "gold_max": 300, "tier_min": 5, "tier_max": 5},
}

const _DEFAULT_MONSTER_CONFIG := {"gold_min": 10, "gold_max": 25, "tier_min": 1, "tier_max": 3}

const _EQUIP_CHANCE := 0.45
const _POTION_CHANCE := 0.25


func _get_monster_config(name: String) -> Dictionary:
	if _MONSTER_CONFIG.has(name):
		return _MONSTER_CONFIG[name]
	return _DEFAULT_MONSTER_CONFIG


func generate_drop(monster_name: String, _exp_reward: int, is_boss: bool = false) -> Dictionary:
	var result = {"gold": 0, "items": []}
	var cfg = _get_monster_config(monster_name)

	result["gold"] = randi_range(int(cfg.get("gold_min", 10)), int(cfg.get("gold_max", 25)))
	var min_tier = int(cfg.get("tier_min", 1))
	var max_tier = int(cfg.get("tier_max", 3))

	# --- 装备掉落 ---
	# Boss 保证必掉一件装备，还有 50% 概率再掉一件
	var equip_rolls := 1 if is_boss else 0
	if is_boss:
		pass  # boss 强制掉落
	elif randf() < _EQUIP_CHANCE:
		equip_rolls = 1

	for _i in range(equip_rolls):
		var slot: String
		var roll = randf()
		if roll < 0.45:
			slot = "weapon"
		elif roll < 0.8:
			slot = "armor"
		else:
			slot = "accessory"
		var picked = _pick_equip_from_set(slot, min_tier, max_tier)
		if picked != null:
			result["items"].append(picked.duplicate(true))

	# Boss 额外 50% 概率再掉一件（不同部位的）
	if is_boss and randf() < 0.5:
		var slot2: String
		var r2 = randf()
		if r2 < 0.45:
			slot2 = "weapon"
		elif r2 < 0.8:
			slot2 = "armor"
		else:
			slot2 = "accessory"
		var picked2 = _pick_equip_from_set(slot2, min_tier, max_tier)
		if picked2 != null:
			result["items"].append(picked2.duplicate(true))

	# --- 药水掉落 ---
	if randf() < _POTION_CHANCE:
		if randf() < 0.5:
			result["items"].append(
				{
					"name": "血瓶",
					"quantity": 1,
					"icon": POTION_HEAL,
					"heal": 50,
					"type": "potion",
					"description": "恢复50点生命值"
				}
			)
		else:
			result["items"].append(
				{
					"name": "蓝瓶",
					"quantity": 1,
					"icon": POTION_MANA,
					"mana": 30,
					"type": "potion",
					"description": "恢复30点魔法值"
				}
			)

	return result


# 从 装备套装 里选一件指定类型、tier 在范围内的装备；
# 如果套装里没有符合要求的，再从 EXTRA_* 里随机选。
func _get_extras_for_slot(slot: String) -> Array:
	match slot:
		"weapon":
			return EXTRA_WEAPONS
		"armor":
			return EXTRA_ARMORS
		"accessory":
			return EXTRA_RINGS
	return []


func _pick_equip_from_set(slot: String, min_tier: int, max_tier: int) -> Variant:
	var pool: Array = []
	# 套装池
	for s in EQUIPMENT_SETS:
		var item = s.get(slot, null)
		if item is Dictionary:
			var t = item.get("tier", 1)
			if t >= min_tier and t <= max_tier:
				pool.append(item)
	# 额外装备池
	for ex in _get_extras_for_slot(slot):
		var t = ex.get("tier", 1)
		if t >= min_tier and t <= max_tier:
			pool.append(ex)
	# 兜底
	if pool.is_empty():
		for s in EQUIPMENT_SETS:
			var item = s.get(slot, null)
			if item is Dictionary:
				return item
		return null
	var idx: int = randi() % pool.size()
	return pool[idx]


# 把掉落物添加到玩家数据（金币+背包）
func apply_drop(drop: Dictionary):
	var g: int = drop.get("gold", 0)
	if g > 0:
		gold += g
		print("→ 获得金币：", g, "（合计：", gold, "）")

	var items: Array = drop.get("items", [])
	for it in items:
		if it is Dictionary:
			var tp: String = it.get("type", "")
			if tp == "potion":
				_add_potion(it)
			else:
				# 装备直接进专属背包栏
				exclusive_backpack.append(it.duplicate(true))
				print("→ 获得装备：", it.get("name", "?"))


func _add_potion(potion: Dictionary):
	var pname: String = potion.get("name", "")
	# 已存在则数量+1
	for existing in inventory_items:
		if existing is Dictionary and existing.get("name", "") == pname:
			existing["quantity"] = int(existing.get("quantity", 0)) + 1
			print("→ 获得道具：", pname, " x1（合计 x", existing["quantity"], "）")
			return
	# 否则新增一条
	var p = potion.duplicate(true)
	p["quantity"] = 1
	inventory_items.append(p)
	print("→ 获得道具：", pname, " x1")


# 消耗一瓶指定名字的药水（成功返回 true）
func consume_potion(potion_name: String) -> bool:
	for i in range(inventory_items.size()):
		var it = inventory_items[i]
		if it is Dictionary and it.get("name", "") == potion_name:
			var qty = it.get("quantity", 0)
			if qty <= 0:
				continue
			var heal: int = it.get("heal", 0)
			var mana: int = it.get("mana", 0)
			if heal > 0:
				current_hp = min(get_total_max_hp(), current_hp + heal)
			if mana > 0:
				current_mp = min(max_mp, current_mp + mana)
			it["quantity"] = qty - 1
			if it["quantity"] <= 0:
				inventory_items.remove_at(i)
			var remaining: int = 0
			if it["quantity"] > 0:
				remaining = it["quantity"]
			print("→ 使用药水：", potion_name, "（剩余 x", remaining, "）")
			return true
	return false


# ============================================================
# 存档系统
# ============================================================
const SAVE_SLOT_COUNT := 3
const SAVE_DIR := "user://saves/"


func _get_save_path(slot: int) -> String:
	return SAVE_DIR + "save_slot_" + str(slot) + ".json"


func save_game(slot: int) -> bool:
	if slot < 0 or slot >= SAVE_SLOT_COUNT:
		return false

	DirAccess.make_dir_recursive_absolute(SAVE_DIR)

	var data := {}

	# 玩家基础属性
	data["max_hp"] = max_hp
	data["current_hp"] = current_hp
	data["max_mp"] = max_mp
	data["current_mp"] = current_mp
	data["attack"] = attack
	data["defense"] = defense
	data["base_speed"] = base_speed
	data["current_speed"] = current_speed
	data["level"] = level
	data["current_exp"] = current_exp
	data["exp_to_next_level"] = exp_to_next_level
	data["crit"] = crit
	data["gold"] = gold

	# 装备
	data["weapon"] = weapon.duplicate(true)
	data["armor"] = armor.duplicate(true)
	data["accessory"] = accessory.duplicate(true)

	# 背包
	data["exclusive_backpack"] = _deep_copy_array(exclusive_backpack)
	data["inventory_items"] = _deep_copy_array(inventory_items)

	# 玩家位置和场景
	var players = Engine.get_main_loop().get_root().get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		data["player_position"] = {
			"x": players[0].global_position.x, "y": players[0].global_position.y
		}
	else:
		data["player_position"] = {"x": 0, "y": 0}

	var current_scene = Engine.get_main_loop().get_root().get_tree().current_scene
	if current_scene:
		data["last_scene"] = current_scene.scene_file_path
	else:
		data["last_scene"] = ""

	# 已击败怪物位置
	data["defeated_monster_positions"] = []
	for pos in defeated_monster_positions:
		if pos is Vector2:
			data["defeated_monster_positions"].append({"x": pos.x, "y": pos.y})

	# 已击败首领位置
	data["defeated_boss_positions"] = []
	for pos in defeated_boss_positions:
		if pos is Vector2:
			data["defeated_boss_positions"].append({"x": pos.x, "y": pos.y})

	# 已击败首领名称
	data["defeated_boss_names"] = defeated_boss_names.duplicate()

	# 时间戳
	data["timestamp"] = Time.get_unix_time_from_system()
	data["play_time"] = Time.get_ticks_msec() / 1000.0

	var file = FileAccess.open(_get_save_path(slot), FileAccess.WRITE)
	if not file:
		print("[存档] 无法写入存档文件：", _get_save_path(slot))
		return false

	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	print("[存档] 存档成功！槽位：", slot + 1, "  场景：", data["last_scene"])
	return true


func load_game(slot: int) -> bool:
	if slot < 0 or slot >= SAVE_SLOT_COUNT:
		return false

	var path = _get_save_path(slot)
	if not FileAccess.file_exists(path):
		print("[读档] 存档文件不存在：", path)
		return false

	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		print("[读档] 无法读取存档文件：", path)
		return false

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		print("[读档] JSON 解析失败：", json.get_error_message())
		return false

	var data = json.get_data()
	if not data is Dictionary:
		print("[读档] 存档数据格式错误")
		return false

	# 恢复玩家基础属性
	max_hp = data.get("max_hp", 120)
	current_hp = data.get("current_hp", 120)
	max_mp = data.get("max_mp", 60)
	current_mp = data.get("current_mp", 60)
	attack = data.get("attack", 15)
	defense = data.get("defense", 5)
	base_speed = data.get("base_speed", 200)
	current_speed = data.get("current_speed", 200)
	level = data.get("level", 1)
	current_exp = data.get("current_exp", 0)
	exp_to_next_level = data.get("exp_to_next_level", 50)
	crit = data.get("crit", 5)
	gold = data.get("gold", 50)

	# 恢复装备
	var w = data.get("weapon", {})
	if w is Dictionary:
		weapon = w.duplicate(true)
	var a = data.get("armor", {})
	if a is Dictionary:
		armor = a.duplicate(true)
	var acc = data.get("accessory", {})
	if acc is Dictionary:
		accessory = acc.duplicate(true)

	# 恢复背包
	exclusive_backpack.clear()
	var eb = data.get("exclusive_backpack", [])
	if eb is Array:
		for item in eb:
			if item is Dictionary:
				exclusive_backpack.append(item.duplicate(true))

	inventory_items.clear()
	var inv = data.get("inventory_items", [])
	if inv is Array:
		for item in inv:
			if item is Dictionary:
				inventory_items.append(item.duplicate(true))

	# 恢复已击败怪物位置
	defeated_monster_positions.clear()
	var dmp = data.get("defeated_monster_positions", [])
	if dmp is Array:
		for pos in dmp:
			if pos is Dictionary:
				defeated_monster_positions.append(Vector2(pos.get("x", 0), pos.get("y", 0)))

	# 恢复已击败首领位置
	defeated_boss_positions.clear()
	var dbp = data.get("defeated_boss_positions", [])
	if dbp is Array:
		for pos in dbp:
			if pos is Dictionary:
				defeated_boss_positions.append(Vector2(pos.get("x", 0), pos.get("y", 0)))

	# 恢复已击败首领名称
	defeated_boss_names.clear()
	var dbn = data.get("defeated_boss_names", [])
	if dbn is Array:
		defeated_boss_names = dbn.duplicate()

	# 恢复玩家位置
	var pp = data.get("player_position", {})
	if pp is Dictionary:
		player_return_position = Vector2(pp.get("x", 0), pp.get("y", 0))
		returning_from_battle = true

	print("[读档] 读档成功！槽位：", slot + 1, "  等级：Lv.", level)
	return true


func get_save_slot_info(slot: int) -> Dictionary:
	if slot < 0 or slot >= SAVE_SLOT_COUNT:
		return {"exists": false}

	var path = _get_save_path(slot)
	if not FileAccess.file_exists(path):
		return {"exists": false, "slot": slot}

	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return {"exists": false, "slot": slot}

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		return {"exists": false, "slot": slot}

	var data = json.get_data()
	if not data is Dictionary:
		return {"exists": false, "slot": slot}

	var scene_name = ""
	var scene_path = data.get("last_scene", "")
	if scene_path != "":
		scene_name = scene_path.get_file().trim_suffix(".tscn")

	return {
		"exists": true,
		"slot": slot,
		"level": data.get("level", 1),
		"scene": scene_name,
		"gold": data.get("gold", 0),
		"timestamp": data.get("timestamp", 0),
		"last_scene": data.get("last_scene", ""),
	}


func delete_save(slot: int) -> bool:
	if slot < 0 or slot >= SAVE_SLOT_COUNT:
		return false

	var path = _get_save_path(slot)
	if not FileAccess.file_exists(path):
		return false

	DirAccess.remove_absolute(path)
	print("[存档] 删除存档！槽位：", slot + 1)
	return true


func _deep_copy_array(arr: Array) -> Array:
	var result: Array = []
	for item in arr:
		if item is Dictionary:
			result.append(item.duplicate(true))
		elif item is Array:
			result.append(_deep_copy_array(item))
		else:
			result.append(item)
	return result
