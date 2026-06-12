extends Node

# ============================================================
# 玩家基础属性
# ============================================================
var max_hp: int = 150
var current_hp: int = 150
var max_mp: int = 50
var current_mp: int = 50

var attack: int = 12
var defense: int = 5
var base_speed: int = 200
var current_speed: int = 200

var level: int = 1
var current_exp: int = 0
var exp_to_next_level: int = 50
var level_up_growth: float = 1.2

# 暴击率（百分比）
var crit: int = 5

# 货币（金币）
var gold: int = 0

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
		"weapon": {"name": "生铁剑", "icon": SWORD_ROOT + "/SwordPack-ShortSword.png",
					"attack_bonus": 2, "type": "weapon", "description": "粗糙的生铁打造的短剑", "tier": 1},
		"armor":  {"name": "皮甲",   "icon": ARMOR_ROOT + "/wuxia_chainmail_worn_leather_32x32.png",
					"defense_bonus": 1, "type": "armor", "description": "磨损的皮甲，聊胜于无", "tier": 1},
		"accessory": {"name": "铜戒", "icon": RING_ROOT + "/1.png",
					  "hp_bonus": 8, "type": "accessory", "description": "散发微光的铜制戒指", "tier": 1},
	},
	# 套装 2：寒铁套装
	{
		"name": "寒铁套装",
		"tier": 2,
		"weapon": {"name": "寒铁长剑", "icon": SWORD_ROOT + "/SwordPack-LongSword.png",
					"attack_bonus": 5, "type": "weapon", "description": "剑刃透出寒气，锋锐非常", "tier": 2},
		"armor":  {"name": "锻铁甲", "icon": ARMOR_ROOT + "/wuxia_chainmail_forged_iron_32x32.png",
					"defense_bonus": 3, "type": "armor", "description": "反复锤炼的铁甲，坚固耐用", "tier": 2},
		"accessory": {"name": "银光戒", "icon": RING_ROOT + "/2.png",
					  "hp_bonus": 18, "type": "accessory", "description": "蕴含温厚灵力的银戒", "tier": 2},
	},
	# 套装 3：烈焰套装
	{
		"name": "烈焰套装",
		"tier": 3,
		"weapon": {"name": "烈焰剑", "icon": SWORD_ROOT + "/SwordPack-FireSword.png",
					"attack_bonus": 9, "type": "weapon", "description": "燃烧着烈焰的魔剑", "tier": 3},
		"armor":  {"name": "赤岩甲", "icon": ARMOR_ROOT + "/wuxia_chainmail_rusty_stone_32x32.png",
					"defense_bonus": 5, "type": "armor", "description": "火岩凝成的重甲，抗击打", "tier": 3},
		"accessory": {"name": "烈焰戒", "icon": RING_ROOT + "/3.png",
					  "hp_bonus": 32, "type": "accessory", "description": "戒指上刻有火焰纹章", "tier": 3},
	},
	# 套装 4：玄冰套装
	{
		"name": "玄冰套装",
		"tier": 4,
		"weapon": {"name": "寒冰之刃", "icon": SWORD_ROOT + "/SwordPack-IceSword.png",
					"attack_bonus": 14, "type": "weapon", "description": "永不融化的玄冰铸就", "tier": 4},
		"armor":  {"name": "玄冰甲", "icon": ARMOR_ROOT + "/wuxia_chainmail_icy_frost_steel_32x32.png",
					"defense_bonus": 8, "type": "armor", "description": "散发寒气的冰霜重甲", "tier": 4},
		"accessory": {"name": "寒冰戒", "icon": RING_ROOT + "/4.png",
					  "hp_bonus": 50, "type": "accessory", "description": "冷冽彻骨的冰蓝戒指", "tier": 4},
	},
	# 套装 5：神圣黄金套装（顶级）
	{
		"name": "神圣黄金套装",
		"tier": 5,
		"weapon": {"name": "黄金圣剑", "icon": SWORD_ROOT + "/SwordPack-GoldenSword.png",
					"attack_bonus": 22, "type": "weapon", "description": "黄金铸就的神圣长剑", "tier": 5},
		"armor":  {"name": "神圣金甲", "icon": ARMOR_ROOT + "/wuxia_chainmail_divine_gold_inlaid_wood_32x32.png",
					"defense_bonus": 14, "type": "armor", "description": "镶嵌黄金的神圣护甲", "tier": 5},
		"accessory": {"name": "神圣戒指", "icon": RING_ROOT + "/5.png",
					  "hp_bonus": 80, "type": "accessory", "description": "蕴含神圣之力的至尊戒指", "tier": 5},
	},
]

# 其他可选掉落的武器 / 护甲 / 饰品（随机填充背包栏）
const EXTRA_WEAPONS := [
	{"name": "暗影刃", "icon": SWORD_ROOT + "/SwordPack-ShadowBlade.png",
	 "attack_bonus": 18, "type": "weapon", "description": "隐匿于阴影之中的利刃", "tier": 5},
	{"name": "钻石剑", "icon": SWORD_ROOT + "/SwordPack-DiamondSword.png",
	 "attack_bonus": 26, "type": "weapon", "description": "钻石打造的锋利长剑", "tier": 5},
]
const EXTRA_ARMORS := [
	{"name": "乌金钢甲", "icon": ARMOR_ROOT + "/wuxia_chainmail_ebony_steel_32x32.png",
	 "defense_bonus": 11, "type": "armor", "description": "乌黑泛光的钢制重甲", "tier": 4},
	{"name": "翡翠甲", "icon": ARMOR_ROOT + "/wuxia_chainmail_green_jade_32x32.png",
	 "defense_bonus": 9, "type": "armor", "description": "翡翠镶嵌的玉石甲胄", "tier": 4},
	{"name": "自然木甲", "icon": ARMOR_ROOT + "/wuxia_chainmail_natural_wood_32x32.png",
	 "defense_bonus": 7, "type": "armor", "description": "由灵木编织而成的轻甲", "tier": 3},
]
const EXTRA_RINGS := [
	{"name": "力量戒指", "icon": RING_ROOT + "/6.png", "hp_bonus": 40,
	 "type": "accessory", "description": "蕴含神秘力量的戒指", "tier": 4},
	{"name": "敏捷戒指", "icon": RING_ROOT + "/7.png", "hp_bonus": 45,
	 "type": "accessory", "description": "佩戴者身手敏捷", "tier": 4},
	{"name": "至尊金戒", "icon": RING_ROOT + "/10.png", "hp_bonus": 75,
	 "type": "accessory", "description": "至尊奢华的黄金戒指", "tier": 5},
]

# 空槽位模板
const EMPTY_SLOT_DATA = {"name": "无", "icon": "", "type": "",
						 "attack_bonus": 0, "defense_bonus": 0, "hp_bonus": 0,
						 "description": "空槽位"}

# ============================================================
# 当前穿戴的装备（默认从 套装1 起步）
# ============================================================
var weapon: Dictionary = EQUIPMENT_SETS[0]["weapon"].duplicate(true)
var armor: Dictionary = EQUIPMENT_SETS[0]["armor"].duplicate(true)
var accessory: Dictionary = EQUIPMENT_SETS[0]["accessory"].duplicate(true)

# ============================================================
# 背包栏（未装备的装备 + 道具）
#   exclusive_backpack：装备类
#   inventory_items  ：道具类（血瓶/蓝瓶）
# ============================================================
var exclusive_backpack: Array = []
var inventory_items: Array = [
	{"name": "血瓶", "quantity": 3, "icon": POTION_HEAL, "heal": 50,
	 "type": "potion", "description": "恢复50点生命值"},
	{"name": "蓝瓶", "quantity": 2, "icon": POTION_MANA, "mana": 30,
	 "type": "potion", "description": "恢复30点魔法值"},
]

# 已击败的怪物位置列表（主场景用）
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
	level += 1
	max_hp += 8
	max_mp += 5
	attack += 1
	defense += 1
	base_speed += 5
	current_speed = base_speed
	current_hp = max_hp
	current_mp = max_mp
	exp_to_next_level = int(exp_to_next_level * level_up_growth)
	print("→ 升级！当前等级：Lv.", level, "  HP:", max_hp, "  MP:", max_mp, "  攻击:", attack, "  防御:", defense)

# ============================================================
# 掉落系统
#   输入：monster_name 用于决定掉落池；exp_reward 决定强度
#   输出：{"gold": int, "items": [装备/道具dict...]}
# ============================================================
func generate_drop(monster_name: String, _exp_reward: int) -> Dictionary:
	var result = {"gold": 0, "items": []}

	# --- 金币掉落：按怪物名给出不同数值区间 ---
	var gold_min: int = 5
	var gold_max: int = 20
	match monster_name:
		"slime":
			gold_min = 3; gold_max = 10
		"rat":
			gold_min = 5; gold_max = 15
		"bat":
			gold_min = 8; gold_max = 20
		"goblin":
			gold_min = 15; gold_max = 35
		"skull":
			gold_min = 20; gold_max = 45
		"dragon":
			gold_min = 80; gold_max = 150
		_:
			gold_min = 10; gold_max = 25
	result["gold"] = randi_range(gold_min, gold_max)

	# --- 装备/道具掉落概率 ---
	var equip_chance: float = 0.45   # 45% 掉一件装备
	var potion_chance: float = 0.25  # 25% 掉药水

	# 根据怪物名调整掉落强度（tier）
	var min_tier: int = 1
	var max_tier: int = 2
	match monster_name:
		"slime":
			min_tier = 1; max_tier = 1
		"rat":
			min_tier = 1; max_tier = 2
		"bat":
			min_tier = 1; max_tier = 2
		"goblin":
			min_tier = 2; max_tier = 3
		"skull":
			min_tier = 3; max_tier = 4
		"dragon":
			min_tier = 4; max_tier = 5
		_:
			min_tier = 1; max_tier = 3

	# --- 装备掉落 ---
	if randf() < equip_chance:
		var roll = randf()
		var picked_equip: Variant
		if roll < 0.45:
			# 武器
			picked_equip = _pick_equip_from_set("weapon", min_tier, max_tier)
		elif roll < 0.8:
			# 护甲
			picked_equip = _pick_equip_from_set("armor", min_tier, max_tier)
		else:
			# 饰品
			picked_equip = _pick_equip_from_set("accessory", min_tier, max_tier)
		if picked_equip != null:
			result["items"].append(picked_equip.duplicate(true))

	# --- 药水掉落 ---
	if randf() < potion_chance:
		if randf() < 0.5:
			result["items"].append({
				"name": "血瓶", "quantity": 1, "icon": POTION_HEAL,
				"heal": 50, "type": "potion",
				"description": "恢复50点生命值"
			})
		else:
			result["items"].append({
				"name": "蓝瓶", "quantity": 1, "icon": POTION_MANA,
				"mana": 30, "type": "potion",
				"description": "恢复30点魔法值"
			})

	return result

# 从 装备套装 里选一件指定类型、tier 在范围内的装备；
# 如果套装里没有符合要求的，再从 EXTRA_* 里随机选。
func _pick_equip_from_set(slot: String, min_tier: int, max_tier: int) -> Variant:
	var pool: Array = []
	for s in EQUIPMENT_SETS:
		var item = s.get(slot, null)
		if item is Dictionary:
			var t = item.get("tier", 1)
			if t >= min_tier and t <= max_tier:
				pool.append(item)

	# 也把额外池里的装备加进来
	var extras: Array = []
	match slot:
		"weapon":
			extras = EXTRA_WEAPONS
		"armor":
			extras = EXTRA_ARMORS
		"accessory":
			extras = EXTRA_RINGS
	for ex in extras:
		var t = ex.get("tier", 1)
		if t >= min_tier and t <= max_tier:
			pool.append(ex)

	if pool.is_empty():
		# 兜底：直接返回最低 tier 的套装装备
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
	for existing in inventory_items:
		if existing is Dictionary and existing.get("name", "") == pname:
			var qty = existing.get("quantity", 0)
			existing["quantity"] = qty + 1
			print("→ 获得道具：", pname, " x1（合计 x", existing["quantity"], "）")
			return
	# 没找到同名，新增一条
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
