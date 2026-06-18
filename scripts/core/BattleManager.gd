extends Node

# ============================================================
# 战斗管理器：处理战斗开始 / 回合 / 结束 / 掉落
# ============================================================

var battle_state: int = 0          # 0=idle, 1=starting, 2=player turn, 3=enemy turn, 4=end
const STATE_IDLE := 0
const STATE_STARTING := 1
const STATE_PLAYER := 2
const STATE_ENEMY := 3
const STATE_END := 4

var player: Node2D = null
var player_battler: Node2D = null
var current_enemy: Node2D = null
var enemies: Array = []
var previous_scene: String = ""
var enemy_scene: String = ""
var enemy_position: Vector2 = Vector2.ZERO
var enemy_data: Dictionary = {}
var enemy_sprite_scale: Vector2 = Vector2.ONE
var player_sprite_scale: Vector2 = Vector2.ONE
var combat_scene: Node2D = null

# 退出战斗标志：战斗结束/逃跑时设为 true，防止异步代码继续执行
var _battle_exiting: bool = false

# 最近一次掉落（供 UI 显示）
var last_drop: Dictionary = {"gold": 0, "items": []}

# 掉落提示面板节点（战斗胜利时显示）
var _reward_panel: CanvasLayer = null

func _ready():
	_connect_to_enemies()
	if not get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.connect(_on_node_added)

func _on_node_added(node):
	if not is_instance_valid(node):
		return
	call_deferred("_try_connect_enemy", node)

func _try_connect_enemy(node):
	if not is_instance_valid(node):
		return
	if not node.is_in_group("enemy"):
		return
	if node.has_signal("enter_battle"):
		if not node.enter_battle.is_connected(_on_enter_battle):
			node.enter_battle.connect(_on_enter_battle)
	if node.has_signal("monster_died"):
		if not node.monster_died.is_connected(_on_monster_died):
			node.monster_died.connect(_on_monster_died)

func _connect_to_enemies():
	for enemy in get_tree().get_nodes_in_group("enemy"):
		_try_connect_enemy(enemy)

func _on_enter_battle(attacking_monster):
	if battle_state != STATE_IDLE:
		return

	# 重置战斗状态标志
	_battle_exiting = false
	battle_state = STATE_STARTING
	current_enemy = attacking_monster

	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]
		if player.has_method("save_data_to_global"):
			player.save_data_to_global()

		GameData.player_return_position = player.global_position
		GameData.returning_from_battle = true

		if player.has_node("AnimatedSprite2D"):
			var player_sprite = player.get_node("AnimatedSprite2D")
			player_sprite_scale = player_sprite.scale

	var scene_path = attacking_monster.get("enemy_scene_path")
	enemy_scene = scene_path if scene_path is String else ""
	var sp = attacking_monster.get("spawn_position")
	enemy_position = sp if sp is Vector2 and sp != Vector2.ZERO else attacking_monster.global_position

	if attacking_monster.has_node("AnimatedSprite2D"):
		var enemy_sprite = attacking_monster.get_node("AnimatedSprite2D")
		enemy_sprite_scale = enemy_sprite.scale

	enemy_data = {
		"monster_name": attacking_monster.get("monster_name") if attacking_monster.get("monster_name") else "bat",
		"max_hp": attacking_monster.get("max_hp") if attacking_monster.get("max_hp") else 80,
		"attack": attacking_monster.get("attack") if attacking_monster.get("attack") else 15,
		"defense": attacking_monster.get("defense") if attacking_monster.get("defense") else 3,
		"exp_reward": attacking_monster.get("exp_reward") if attacking_monster.get("exp_reward") else 20,
		"is_boss": attacking_monster.get("is_boss") if attacking_monster.get("is_boss") else false,
	}

	previous_scene = get_tree().current_scene.scene_file_path if get_tree().current_scene else ""

	get_tree().change_scene_to_file("res://scenes/battle/combat_manager.tscn")

func _on_scene_change():
	combat_scene = get_tree().current_scene

	# 重连 enemy 信号（用统一的 try_connect 避免重复连接）
	for enemy_node in get_tree().get_nodes_in_group("enemy"):
		_try_connect_enemy(enemy_node)

	var battlers = get_tree().get_nodes_in_group("player")
	if battlers.size() > 0:
		player_battler = battlers[0]
		if enemy_sprite_scale != Vector2.ONE and is_instance_valid(player_battler) and player_battler.has_node("AnimatedSprite2D"):
			var player_battler_sprite = player_battler.get_node("AnimatedSprite2D")
			player_battler_sprite.scale = player_sprite_scale

	# Boss 战：移除默认 Monster-Battler，替换为 Boss 实例
	var is_boss = enemy_data.get("is_boss", false)
	if is_boss:
		if is_instance_valid(combat_scene):
			var enemy_team = combat_scene.get_node_or_null("EnemyTeam")
			if enemy_team:
				# 保存默认怪物位置，Boss 使用相同位置
				var boss_position = combat_scene.get_original_monster_pos() if combat_scene.has_method("get_original_monster_pos") else Vector2(833, 363)
				# 移除默认的 Monster-Battler
				for child in enemy_team.get_children():
					child.queue_free()

				if enemy_scene != "":
					var boss_resource = load(enemy_scene)
					if boss_resource:
						var boss_instance = boss_resource.instantiate()
						boss_instance.position = boss_position
						boss_instance.in_battle = true
						# Boss 实例化时 _ready() 会自动调用脚对齐（如果脚本支持）
						enemy_team.add_child(boss_instance)
						enemies = [boss_instance]
						current_enemy = boss_instance
						# 连接 Boss 的 monster_died 信号
						if boss_instance.has_signal("monster_died"):
							if not boss_instance.monster_died.is_connected(_on_monster_died):
								boss_instance.monster_died.connect(_on_monster_died)
						# 重置 monster offset，让 combat_manager._auto_face_targets() 重新记录 Boss 的脚对齐 offset
						if combat_scene.has_method("reset_monster_offset"):
							combat_scene.reset_monster_offset()
						print("→ Boss 战：亡灵法师登场！")
	else:
		enemies = []
		for enemy_node in get_tree().get_nodes_in_group("enemy"):
			# 跳过默认的 Monster-Battler 占位符（它只是场景模板，不是实际敌人）
			if is_instance_valid(combat_scene) and enemy_node == combat_scene.monster_battler:
				continue
			enemy_node.in_battle = true
			# 战斗中的怪物统一朝左（面向玩家）
			# 骷髅默认朝左，不需要翻转
			if is_instance_valid(enemy_node) and enemy_node.has_node("AnimatedSprite2D"):
				var m_sprite = enemy_node.get_node("AnimatedSprite2D")
				m_sprite.flip_h = enemy_node.monster_name != "skull" and enemy_node.monster_name != "slime_king"
			enemies.append(enemy_node)

		if enemies.size() == 0 and enemy_scene != "":
			# 没有真实敌人：加载怪物场景的精灵帧复制到 monster_battler
			if is_instance_valid(combat_scene) and is_instance_valid(combat_scene.monster_battler):
				_setup_monster_battler(combat_scene.monster_battler)
				enemies.append(combat_scene.monster_battler)
				current_enemy = combat_scene.monster_battler
		elif enemies.size() > 0:
			# 使用场景中已有的真实怪物
			current_enemy = enemies[0]
			_setup_monster_battler(enemies[0])

	print("战斗开始！")
	# 让战斗场景重新适配（缩放动态创建的怪物、玩家大小等）
	if is_instance_valid(combat_scene) and combat_scene.has_method("refit"):
		combat_scene.refit()
	_start_player_turn()

func _setup_monster_battler(battler):
	if not is_instance_valid(battler):
		return

	battler.monster_name = enemy_data.get("monster_name", "bat")
	battler.max_hp = enemy_data.get("max_hp", 80)
	battler.attack = enemy_data.get("attack", 15)
	battler.defense = enemy_data.get("defense", 3)
	battler.current_hp = battler.max_hp
	# 刷新血条显示
	if battler.has_method("set_current_hp"):
		battler.set_current_hp(battler.current_hp)

	# ============================================================
	# 复制精灵帧 + 脚对齐重算（关键修复）
	# ============================================================
	var source_scale: Vector2 = Vector2.ONE
	if enemy_scene != "":
		var enemy_resource = load(enemy_scene)
		if enemy_resource:
			var temp_instance = enemy_resource.instantiate()
			if temp_instance.has_node("AnimatedSprite2D"):
				var source_sprite = temp_instance.get_node("AnimatedSprite2D")
				if source_sprite and source_sprite.sprite_frames:
					battler.animated_sprite.sprite_frames = source_sprite.sprite_frames.duplicate()
					# 记录源精灵的原始 scale，用于后续缩放计算
					source_scale = source_sprite.scale
			temp_instance.queue_free()

	# ============================================================
	# 脚对齐重算：用新的精灵帧重新计算 offset（不复制 position/offset）
	# ============================================================
	if battler.has_method("reapply_foot_alignment"):
		battler.reapply_foot_alignment(source_scale)
	else:
		# 兼容没有 reapply_foot_alignment 的旧脚本
		if battler.has_node("AnimatedSprite2D"):
			var bsprite = battler.get_node("AnimatedSprite2D")
			bsprite.position = Vector2(0, 0)
			if bsprite.sprite_frames and bsprite.sprite_frames.get_animation_names().size() > 0:
				var first_anim = bsprite.sprite_frames.get_animation_names()[0]
				if bsprite.sprite_frames.get_frame_count(first_anim) > 0:
					var tex = bsprite.sprite_frames.get_frame_texture(first_anim, 0)
					if tex:
						bsprite.offset = Vector2(0, -tex.get_size().y / 2.0)

	# ============================================================
	# 重置 monster offset，确保新怪物翻转时重新计算
	# ============================================================
	if is_instance_valid(combat_scene) and combat_scene.has_method("reset_monster_offset"):
		combat_scene.reset_monster_offset()

	# ============================================================
	# 怪物朝向：不在这里设置 flip_h，让 combat_manager._auto_face_targets() 处理
	# （避免脚对齐后又被翻转逻辑覆盖）
	# ============================================================

	battler.play_anim("idle")
	current_enemy = battler

func _start_player_turn():
	if _battle_exiting:
		return
	battle_state = STATE_PLAYER
	if is_instance_valid(player_battler):
		player_battler.is_turn = true
	if is_instance_valid(combat_scene):
		var ui = combat_scene.get_node_or_null("CombatUI")
		if ui:
			ui.set_buttons_enabled(true)
	print("玩家回合开始")

func _end_player_turn():
	if _battle_exiting:
		return
	if is_instance_valid(player_battler):
		player_battler.is_turn = false
	if is_instance_valid(combat_scene):
		var ui = combat_scene.get_node_or_null("CombatUI")
		if ui:
			ui.set_buttons_enabled(false)
	battle_state = STATE_ENEMY
	_start_enemy_turn()

func _start_enemy_turn():
	if _battle_exiting:
		return
	print("敌人回合开始")

	# Boss 战：委托给 Boss 自己的回合逻辑
	if is_instance_valid(current_enemy) and current_enemy.has_method("execute_turn"):
		battle_state = 5
		await current_enemy.execute_turn()
		if _battle_exiting:
			return
		call_deferred("_check_battle_after_enemy_attack")
		return

	if enemies.size() > 0:
		for enemy in enemies:
			if enemy and is_instance_valid(enemy) and not enemy.is_dead:
				_execute_enemy_attack(enemy)
				break
	else:
		if not _battle_exiting:
			_end_battle(true)

# ============================================================
# 工具函数：在 sprite_frames 中模糊匹配动画名
#   - 先尝试精确匹配 monster_name + "_" + anim
#   - 失败则查找所有以 "_" + anim 结尾的动画
#   - 用于怪物名与动画前缀不一致的情况
#     （如 monster_name="bone_knight" 而动画名是 "Bone Knight_idle"）
# ============================================================
func _find_animation_name(sprite: AnimatedSprite2D, monster_name: String, anim: String) -> String:
	if not sprite or not sprite.sprite_frames:
		return ""
	var exact = monster_name + "_" + anim
	if sprite.sprite_frames.has_animation(exact):
		return exact
	var target = "_" + anim
	for a in sprite.sprite_frames.get_animation_names():
		if a.ends_with(target):
			return a
	return ""

func _wait_for_animation(sprite: AnimatedSprite2D, anim_name: String, max_duration: float = 0.8):
	var duration: float = 0.5
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name):
		var fc = sprite.sprite_frames.get_frame_count(anim_name)
		var spd = max(1.0, sprite.sprite_frames.get_animation_speed(anim_name))
		duration = fc / spd
	duration = min(duration, max_duration)
	await get_tree().create_timer(duration).timeout

func _execute_enemy_attack(enemy):
	if _battle_exiting or battle_state != STATE_ENEMY:
		return

	battle_state = 5  # 内部：敌人行动中

	if not is_instance_valid(enemy) or not is_instance_valid(player_battler):
		return

	# ------------------------------------------------------------
	# 阶段 1：怪物向玩家移动（不重合）
	# ------------------------------------------------------------
	var enemy_home: Vector2 = enemy.global_position
	var player_glob: Vector2 = player_battler.global_position
	# 计算怪物朝玩家的方向（只取水平方向）
	var dir_to_player: Vector2 = Vector2(player_glob.x - enemy.global_position.x, 0)
	var dir_norm: Vector2 = dir_to_player.normalized() if dir_to_player.length() > 0.1 else Vector2.LEFT
	# 目标位置：在玩家前方保持一小段距离，y 保持原值
	var target_glob: Vector2 = Vector2(
		player_glob.x - dir_norm.x * 150.0,
		enemy.global_position.y
	)

	# 播放 walk 动画（如果存在的话）
	if enemy.has_node("AnimatedSprite2D"):
		var e_sprite = enemy.get_node("AnimatedSprite2D")
		var walk_name = _find_animation_name(e_sprite, enemy.monster_name, "walk")
		if walk_name != "":
			e_sprite.play(walk_name)
		else:
			var idle_name = _find_animation_name(e_sprite, enemy.monster_name, "idle")
			if idle_name != "":
				e_sprite.play(idle_name)

	await _move_monster_to(enemy, target_glob)

	if _battle_exiting or not is_instance_valid(enemy) or not is_instance_valid(player_battler):
		return

	# ------------------------------------------------------------
	# 阶段 2：播放攻击动画
	# ------------------------------------------------------------
	if enemy.has_method("play_anim"):
		enemy.play_anim("attack")

	var duration: float = 0.5
	if enemy.has_node("AnimatedSprite2D"):
		var sprite: AnimatedSprite2D = enemy.get_node("AnimatedSprite2D")
		var anim_name = _find_animation_name(sprite, enemy.monster_name, "attack")
		if anim_name != "":
			var fc = sprite.sprite_frames.get_frame_count(anim_name)
			var spd = max(1.0, sprite.sprite_frames.get_animation_speed(anim_name))
			duration = fc / spd
	# 提高上限，让动画能完整播放
	duration = min(duration, 1.5)

	await get_tree().create_timer(duration).timeout

	if _battle_exiting:
		return

	# ------------------------------------------------------------
	# 阶段 3：造成伤害 + 玩家 hurt 动画
	# ------------------------------------------------------------
	if is_instance_valid(player_battler) and not player_battler.is_dead:
		var defense = player_battler.get_defense() if player_battler.has_method("get_defense") else 0
		var damage = max(1, enemy.attack - defense / 2)
		player_battler.take_damage(damage)

		var hurt_duration: float = 0.3
		var hurt_anim = "hurt"
		if player_battler.animated_sprite.sprite_frames.has_animation(hurt_anim):
			var hfc = player_battler.animated_sprite.sprite_frames.get_frame_count(hurt_anim)
			var hspd = max(1.0, player_battler.animated_sprite.sprite_frames.get_animation_speed(hurt_anim))
			hurt_duration = hfc / hspd
		# 提高上限，让受伤动画完整播放
		hurt_duration = min(hurt_duration, 0.6)
		await get_tree().create_timer(hurt_duration).timeout

		if _battle_exiting:
			return

		if is_instance_valid(player_battler) and not player_battler.is_dead:
			player_battler.play_anim("idle")

	# ------------------------------------------------------------
	# 阶段 4：怪物走回原位
	# ------------------------------------------------------------
	if is_instance_valid(enemy) and not enemy.is_dead and not _battle_exiting:
		if enemy.has_node("AnimatedSprite2D"):
			var e_sprite2 = enemy.get_node("AnimatedSprite2D")
			var walk_name2 = _find_animation_name(e_sprite2, enemy.monster_name, "walk")
			if walk_name2 != "":
				e_sprite2.play(walk_name2)
		await _move_monster_to(enemy, enemy_home)

	if not _battle_exiting and is_instance_valid(enemy) and enemy.has_method("play_anim") and not enemy.is_dead:
		enemy.play_anim("idle")

	if not _battle_exiting:
		call_deferred("_check_battle_after_enemy_attack")

func _move_monster_to(monster: Node2D, target_glob: Vector2):
	# 让怪物水平移动到目标 global 位置
	var tree = get_tree()
	if not tree or not is_instance_valid(monster):
		return
	var start_glob: Vector2 = monster.global_position
	var dx_total: float = target_glob.x - start_glob.x
	if abs(dx_total) < 2.0:
		monster.global_position = Vector2(target_glob.x, start_glob.y)
		return
	var move_speed: float = 1000.0
	var duration: float = abs(dx_total) / move_speed
	var elapsed: float = 0.0
	while elapsed < duration and is_instance_valid(monster) and get_tree():
		elapsed += get_process_delta_time()
		var k: float = clamp(elapsed / duration, 0.0, 1.0)
		monster.global_position = Vector2(start_glob.x + dx_total * k, start_glob.y)
		await tree.process_frame
	if is_instance_valid(monster):
		monster.global_position = Vector2(target_glob.x, start_glob.y)

func _check_battle_after_enemy_attack():
	if _battle_exiting:
		return
	if is_instance_valid(player_battler) and player_battler.is_dead:
		_end_battle(false)
	else:
		battle_state = STATE_PLAYER
		_start_player_turn()

func _on_monster_died(monster):
	if monster in enemies:
		enemies.erase(monster)

	# Boss 战：只有 Boss 死亡才结束战斗
	if enemy_data.get("is_boss", false):
		if monster == current_enemy:
			_end_battle(true)
		return

	if enemies.size() == 0:
		_end_battle(true)

# ============================================================
# 战斗结束：发放奖励 + 掉落
# ============================================================
func _end_battle(player_won: bool):
	_battle_exiting = true
	battle_state = STATE_END

	if player_won:
		print("战斗胜利！")
		_reward_player()

		# --- 怪物掉落 ---
		var mname: String = enemy_data.get("monster_name", "slime")
		var exp_r: int = enemy_data.get("exp_reward", 20)
		last_drop = GameData.generate_drop(mname, exp_r)
		GameData.apply_drop(last_drop)

		# --- 显示掉落提示面板，等面板消失后再退出 ---
		_show_reward_panel(last_drop)
		await _wait_reward_panel_done()
		# 记录击败怪物位置
		if enemy_position != Vector2.ZERO:
			GameData.defeated_monster_positions.append(enemy_position)
			print("→ 记录击败怪物位置：", enemy_position)
	else:
		print("战斗失败！")

	call_deferred("_exit_battle")

func _reward_player():
	var exp_gain = enemy_data.get("exp_reward", 30)
	if exp_gain is not int:
		exp_gain = 30
	GameData.current_exp += exp_gain
	print("→ 获得经验：", exp_gain)

	while GameData.current_exp >= GameData.exp_to_next_level:
		GameData.current_exp -= GameData.exp_to_next_level
		GameData.level_up()
		print("升级！当前等级: ", GameData.level)

	print("→ 经验：", GameData.current_exp, "/", GameData.exp_to_next_level, " | 等级：", GameData.level)

	if is_instance_valid(combat_scene):
		var ui = combat_scene.get_node_or_null("CombatUI")
		if ui:
			ui.update_exp_bar()
			ui.refresh_skill_locks()

func _exit_battle():
	battle_state = STATE_IDLE
	_battle_exiting = true

	for enemy_node in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(enemy_node) and not enemy_node.is_dead and enemy_node.has_method("exit_battle"):
			enemy_node.exit_battle()

	# 清空所有节点引用，防止访问已释放节点
	player_battler = null
	current_enemy = null
	combat_scene = null
	enemies.clear()

	print("战斗结束，返回主界面")
	var tree = get_tree()
	if tree:
		var return_scene = previous_scene if previous_scene != "" else "res://scenes/maps/village.tscn"
		tree.change_scene_to_file(return_scene)

func _after_player_attack():
	if _battle_exiting or battle_state == STATE_END:
		return

	if is_instance_valid(current_enemy) and not current_enemy.is_dead:
		# Boss 战：让 Boss 自己处理 idle
		if current_enemy.has_method("execute_turn"):
			current_enemy.play_anim("idle")
		else:
			current_enemy.play_anim("idle")
		print("→ 怪物受伤后回到 idle")

	_end_player_turn()

# ============================================================
# 技能：使用
# ============================================================
func use_skill(skill_index: int):
	if _battle_exiting or battle_state != STATE_PLAYER:
		return

	if not is_instance_valid(player_battler) or player_battler.is_dead or not is_instance_valid(current_enemy):
		return

	var skill_idx: int = skill_index - 1
	if not GameData.is_skill_unlocked(skill_idx):
		print("→ 技能未解锁！需要 Lv.", GameData.get_skill_req_level(skill_idx))
		return

	match skill_index:
		2:
			if not player_battler.has_enough_mp(player_battler.MP_COST_HEAVY):
				print("→ MP不足！重斩需要", player_battler.MP_COST_HEAVY)
				return
		3:
			if not player_battler.has_enough_mp(player_battler.MP_COST_ARMOR_PIERCE):
				print("→ MP不足！破甲斩需要", player_battler.MP_COST_ARMOR_PIERCE)
				return
		4:
			if not player_battler.has_enough_mp(player_battler.MP_COST_ULTIMATE):
				print("→ MP不足！怒斩苍穹需要", player_battler.MP_COST_ULTIMATE)
				return

	battle_state = 6  # 玩家行动中
	if is_instance_valid(combat_scene):
		var ui = combat_scene.get_node_or_null("CombatUI")
		if ui:
			ui.set_buttons_enabled(false)

	match skill_index:
		1:
			print("使用技能1：斩击")
			player_battler.attack_enemy(current_enemy)
		2:
			player_battler.consume_mp(player_battler.MP_COST_HEAVY)
			print("使用技能2：重斩")
			_skill_power_attack()
		3:
			player_battler.consume_mp(player_battler.MP_COST_ARMOR_PIERCE)
			print("使用技能3：破甲斩")
			_skill_armor_pierce()
		4:
			player_battler.consume_mp(player_battler.MP_COST_ULTIMATE)
			print("使用技能4：怒斩苍穹")
			_skill_ultimate()

func _skill_power_attack():
	if not is_instance_valid(player_battler) or not is_instance_valid(current_enemy):
		return
	player_battler.heavy_attack_enemy(current_enemy)

func _skill_armor_pierce():
	if not is_instance_valid(player_battler) or not is_instance_valid(current_enemy):
		return
	player_battler.armor_pierce_attack_enemy(current_enemy)

func _skill_ultimate():
	if not is_instance_valid(player_battler) or not is_instance_valid(current_enemy):
		return
	player_battler.ultimate_attack_enemy(current_enemy)

# ============================================================
# 药水 / 逃跑
# ============================================================
func use_heal_potion():
	if _battle_exiting or battle_state != STATE_PLAYER:
		return
	if not is_instance_valid(player_battler) or player_battler.is_dead:
		return

	var old_hp = player_battler.get_current_hp()
	if GameData.consume_potion("血瓶"):
		player_battler.set_current_hp(GameData.current_hp)
		var new_hp = player_battler.get_current_hp()
		print("→ 【血瓶】恢复 HP | 旧:", old_hp, " → 新:", new_hp)
		await get_tree().create_timer(0.5).timeout
		if not _battle_exiting:
			_end_player_turn()
	else:
		print("→ 没有可用的血瓶")

func use_mana_potion():
	if _battle_exiting or battle_state != STATE_PLAYER:
		return
	if not is_instance_valid(player_battler) or player_battler.is_dead:
		return

	var old_mp = player_battler.get_current_mp()
	if GameData.consume_potion("蓝瓶"):
		player_battler.set_current_mp(GameData.current_mp)
		var new_mp = player_battler.get_current_mp()
		print("→ 【蓝瓶】恢复 MP | 旧:", old_mp, " → 新:", new_mp)
		await get_tree().create_timer(0.5).timeout
		if not _battle_exiting:
			_end_player_turn()
	else:
		print("→ 没有可用的蓝瓶")

func try_escape():
	if _battle_exiting or battle_state != STATE_PLAYER:
		return

	battle_state = STATE_END
	print("尝试逃跑...")
	if randf() < 0.5:
		print("逃跑成功！")
		_end_battle(false)
	else:
		print("逃跑失败！")
		battle_state = STATE_PLAYER
		await get_tree().create_timer(0.5).timeout
		if not _battle_exiting and battle_state == STATE_PLAYER:
			_end_player_turn()

func _process(_delta):
	if battle_state != STATE_STARTING:
		return
	if not get_tree().current_scene:
		return
	if get_tree().current_scene.scene_file_path == "res://scenes/battle/combat_manager.tscn":
		_on_scene_change()

# ============================================================
# 掉落提示面板：战斗胜利后显示获得的金币 + 装备
# ============================================================
func _show_reward_panel(drop: Dictionary):
	# 创建面板（挂载到当前战斗场景，让玩家能看到）
	var tree = get_tree()
	if tree == null:
		return

	_reward_panel = CanvasLayer.new()
	_reward_panel.name = "RewardPanel"
	_reward_panel.layer = 100  # 显示在最上层
	if is_instance_valid(combat_scene):
		combat_scene.add_child(_reward_panel)
	else:
		tree.root.add_child(_reward_panel)

	var gold_amount: int = drop.get("gold", 0)
	var items: Array = drop.get("items", [])
	var item_count: int = items.size()

	# 主面板
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(520, 180 + item_count * 36)
	panel.size = Vector2(520, 180 + item_count * 36)
	panel.position = Vector2(
		(tree.root.size.x - panel.custom_minimum_size.x) / 2.0,
		tree.root.size.y / 4.0
	)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.08, 0.18, 0.95)
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_color = Color(1.0, 0.85, 0.35)
	style.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", style)
	_reward_panel.add_child(panel)

	# 标题
	var title = Label.new()
	title.text = "⚔ 战斗胜利！获得奖励 ⚔"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	title.custom_minimum_size = Vector2(480, 40)
	title.position = Vector2(20, 15)
	panel.add_child(title)

	# 金币行
	var gold_y: float = 65
	if gold_amount > 0:
		var gold_label = Label.new()
		gold_label.text = "  💰 金币：+%d" % gold_amount
		gold_label.add_theme_font_size_override("font_size", 18)
		gold_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
		gold_label.custom_minimum_size = Vector2(480, 30)
		gold_label.position = Vector2(20, gold_y)
		panel.add_child(gold_label)
		gold_y += 30

	# 经验奖励
	var exp_gain: int = enemy_data.get("exp_reward", 20)
	var exp_label = Label.new()
	exp_label.text = "  ✨ 经验：+%d" % exp_gain
	exp_label.add_theme_font_size_override("font_size", 18)
	exp_label.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0))
	exp_label.custom_minimum_size = Vector2(480, 30)
	exp_label.position = Vector2(20, gold_y)
	panel.add_child(exp_label)
	gold_y += 30

	# 物品 / 装备
	if item_count > 0:
		var items_title = Label.new()
		items_title.text = "  ⚔ 获得物品："
		items_title.add_theme_font_size_override("font_size", 18)
		items_title.add_theme_color_override("font_color", Color(0.9, 0.75, 0.6))
		items_title.custom_minimum_size = Vector2(480, 30)
		items_title.position = Vector2(20, gold_y)
		panel.add_child(items_title)
		gold_y += 30

		for it in items:
			if it is Dictionary:
				var iname: String = it.get("name", "???")
				var ibonus: String = ""
				var itype: String = it.get("type", "")
				if itype == "potion":
					ibonus = "（药水 x1）"
				else:
					var atk = it.get("attack_bonus", 0)
					var defv = it.get("defense_bonus", 0)
					var hpv = it.get("hp_bonus", 0)
					if atk > 0: ibonus = "（+%d 攻击）" % atk
					elif defv > 0: ibonus = "（+%d 防御）" % defv
					elif hpv > 0: ibonus = "（+%d 生命）" % hpv

				var item_lbl = Label.new()
				item_lbl.text = "        · %s  %s" % [iname, ibonus]
				item_lbl.add_theme_font_size_override("font_size", 16)
				item_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
				item_lbl.custom_minimum_size = Vector2(480, 26)
				item_lbl.position = Vector2(20, gold_y)
				panel.add_child(item_lbl)
				gold_y += 28
	else:
		# 没有物品掉落
		var no_items = Label.new()
		no_items.text = "     （本次没有物品掉落）"
		no_items.add_theme_font_size_override("font_size", 14)
		no_items.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
		no_items.custom_minimum_size = Vector2(480, 30)
		no_items.position = Vector2(20, gold_y)
		panel.add_child(no_items)
		gold_y += 30

	# 提示
	var hint = Label.new()
	hint.text = "（返回主场景后可按 Q 键打开物品栏查看）"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	hint.custom_minimum_size = Vector2(480, 25)
	hint.position = Vector2(20, gold_y)
	panel.add_child(hint)

func _wait_reward_panel_done():
	await get_tree().create_timer(3.0).timeout
	_hide_reward_panel()

func _hide_reward_panel():
	if is_instance_valid(_reward_panel):
		_reward_panel.queue_free()
	_reward_panel = null
