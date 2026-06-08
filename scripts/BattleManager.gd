extends Node

enum BattleState {
	NONE,
	STARTING,
	PLAYER_TURN,
	ENEMY_TURN,
	PLAYER_ACTION,
	ENEMY_ACTION,
	BATTLE_END
}

var battle_state: BattleState = BattleState.NONE
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

func _ready():
	_connect_to_enemies()

func _connect_to_enemies():
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy.has_signal("enter_battle"):
			if not enemy.enter_battle.is_connected(_on_enter_battle):
				enemy.enter_battle.connect(_on_enter_battle)
		if enemy.has_signal("monster_died"):
			if not enemy.monster_died.is_connected(_on_monster_died):
				enemy.monster_died.connect(_on_monster_died)

func _on_enter_battle(attacking_monster):
	if battle_state != BattleState.NONE:
		return
	
	battle_state = BattleState.STARTING
	current_enemy = attacking_monster
	
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]
		if player.has_method("save_data_to_global"):
			player.save_data_to_global()
		
		if player.has_node("AnimatedSprite2D"):
			var player_sprite = player.get_node("AnimatedSprite2D")
			player_sprite_scale = player_sprite.scale
	
	var scene_path = attacking_monster.get("enemy_scene_path")
	enemy_scene = scene_path if scene_path is String else ""
	enemy_position = attacking_monster.get("spawn_position") if attacking_monster.get("spawn_position") else attacking_monster.global_position
	
	if attacking_monster.has_node("AnimatedSprite2D"):
		var enemy_sprite = attacking_monster.get_node("AnimatedSprite2D")
		enemy_sprite_scale = enemy_sprite.scale
	
	enemy_data = {
		"monster_name": attacking_monster.get("monster_name") if attacking_monster.get("monster_name") else "bat",
		"max_hp": attacking_monster.get("max_hp") if attacking_monster.get("max_hp") else 80,
		"attack": attacking_monster.get("attack") if attacking_monster.get("attack") else 15,
		"defense": attacking_monster.get("defense") if attacking_monster.get("defense") else 3,
	}
	
	previous_scene = get_tree().current_scene.scene_file_path if get_tree().current_scene else ""
	
	get_tree().change_scene_to_file("res://scenes/combat_manager.tscn")

func _on_scene_change():
	combat_scene = get_tree().current_scene

	for enemy_node in get_tree().get_nodes_in_group("enemy"):
		if enemy_node.has_signal("enter_battle"):
			if not enemy_node.enter_battle.is_connected(_on_enter_battle):
				enemy_node.enter_battle.connect(_on_enter_battle)
		if enemy_node.has_signal("monster_died"):
			if not enemy_node.monster_died.is_connected(_on_monster_died):
				enemy_node.monster_died.connect(_on_monster_died)
	
	var battlers = get_tree().get_nodes_in_group("player")
	if battlers.size() > 0:
		player_battler = battlers[0]
		if player_sprite_scale != Vector2.ONE and player_battler.has_node("AnimatedSprite2D"):
			var player_battler_sprite = player_battler.get_node("AnimatedSprite2D")
			player_battler_sprite.scale = player_sprite_scale
	
	enemies = []
	for enemy_node in get_tree().get_nodes_in_group("enemy"):
		enemy_node.in_battle = true
		enemies.append(enemy_node)
	
	if enemies.size() == 0 and current_enemy and enemy_scene != "":
		var enemy_resource = load(enemy_scene)
		if enemy_resource:
			var enemy_instance = enemy_resource.instantiate()
			enemy_instance.global_position = Vector2(800, 322)
			get_tree().current_scene.add_child(enemy_instance)
			enemy_instance.in_battle = true
			enemies.append(enemy_instance)
			current_enemy = enemy_instance
	elif enemies.size() > 0 and current_enemy:
		_setup_monster_battler(enemies[0])
	
	print("战斗开始！")
	_start_player_turn()

func _setup_monster_battler(battler):
	if not battler:
		return
	
	battler.monster_name = enemy_data.get("monster_name", "bat")
	battler.max_hp = enemy_data.get("max_hp", 80)
	battler.attack = enemy_data.get("attack", 15)
	battler.defense = enemy_data.get("defense", 3)
	battler.current_hp = battler.max_hp
	
	if enemy_scene != "":
		var enemy_resource = load(enemy_scene)
		if enemy_resource:
			var temp_instance = enemy_resource.instantiate()
			if temp_instance.has_node("AnimatedSprite2D"):
				var source_sprite = temp_instance.get_node("AnimatedSprite2D")
				if source_sprite and source_sprite.sprite_frames:
					battler.animated_sprite.sprite_frames = source_sprite.sprite_frames.duplicate()
			temp_instance.queue_free()
	
	if enemy_sprite_scale != Vector2.ONE and battler.has_node("AnimatedSprite2D"):
		var battler_sprite = battler.get_node("AnimatedSprite2D")
		battler_sprite.scale = enemy_sprite_scale
	
	battler.play_anim("idle")
	
	current_enemy = battler

func _start_player_turn():
	battle_state = BattleState.PLAYER_TURN
	if player_battler:
		player_battler.is_turn = true
	if combat_scene:
		var ui = combat_scene.get_node_or_null("CombatUI")
		if ui:
			ui.set_buttons_enabled(true)
	print("玩家回合开始")

func _end_player_turn():
	if player_battler:
		player_battler.is_turn = false
	if combat_scene:
		var ui = combat_scene.get_node_or_null("CombatUI")
		if ui:
			ui.set_buttons_enabled(false)
	battle_state = BattleState.ENEMY_TURN
	_start_enemy_turn()

func _start_enemy_turn():
	print("敌人回合开始")
	if enemies.size() > 0:
		for enemy in enemies:
			if not enemy.is_dead:
				_execute_enemy_attack(enemy)
				break
	else:
		_end_battle(true)

func _execute_enemy_attack(enemy):
	if battle_state != BattleState.ENEMY_TURN:
		return
	
	battle_state = BattleState.ENEMY_ACTION
	
	print("→ 怪物开始攻击动画...")
	
	if enemy.has_method("play_anim"):
		enemy.play_anim("attack")
	
	var duration = 0.5
	if enemy.has_node("AnimatedSprite2D"):
		var sprite: AnimatedSprite2D = enemy.get_node("AnimatedSprite2D")
		var anim_name = enemy.monster_name + "_attack"
		print("→ 怪物攻击动画名：", anim_name, "，是否存在？", sprite.sprite_frames.has_animation(anim_name))
		duration = get_anim_duration(sprite, anim_name, 0.5)
	
	print("→ 等待怪物攻击动画：", duration, "秒")
	await get_tree().create_timer(duration).timeout
	
	print("→ 怪物攻击结束，造成伤害")
	if player_battler and not player_battler.is_dead and is_instance_valid(player_battler):
		var defense = player_battler.get_defense() if player_battler.has_method("get_defense") else 0
		var damage = max(1, enemy.attack - defense)
		
		# 先造成伤害，触发受伤动画
		player_battler.take_damage(damage)
		
		# 现在等玩家受伤动画播放完
		var hurt_duration = 0.6
		if player_battler.animated_sprite.sprite_frames.has_animation(player_battler.get_job_prefix() + "_hurt"):
			var frame_count = player_battler.animated_sprite.sprite_frames.get_frame_count(player_battler.get_job_prefix() + "_hurt")
			hurt_duration = max(0.6, frame_count * 0.2)
		print("→ 等待玩家受伤动画：", hurt_duration, "秒")
		await get_tree().create_timer(hurt_duration).timeout
		
		# 显式让玩家回到 idle
		if not player_battler.is_dead:
			player_battler.play_job_animation("idle")
			print("→ 玩家回到 idle")
	
	print("→ 怪物回到 idle")
	if enemy.has_method("play_anim") and not enemy.is_dead:
		enemy.play_anim("idle")
	
	call_deferred("_check_battle_after_enemy_attack")

func _check_battle_after_enemy_attack():
	if player_battler and player_battler.is_dead:
		_end_battle(false)
	else:
		battle_state = BattleState.PLAYER_TURN
		_start_player_turn()

func _on_monster_died(monster):
	if monster in enemies:
		enemies.erase(monster)
	
	if enemies.size() == 0:
		_end_battle(true)

func _end_battle(player_won: bool):
	battle_state = BattleState.BATTLE_END
	
	if player_won:
		print("战斗胜利！")
		_reward_player()
		
		# 记录击败怪物的地图位置，让地图重载后自动清除
		if enemy_position != Vector2.ZERO:
			GameData.defeated_monster_positions.append(enemy_position)
			print("→ 记录击败怪物位置：", enemy_position)
	else:
		print("战斗失败！")
	
	call_deferred("_exit_battle")

func _reward_player():
	GameData.current_exp += 30
	if GameData.current_exp >= GameData.exp_to_next_level:
		GameData.level += 1
		GameData.exp_to_next_level = int(GameData.exp_to_next_level * GameData.level_up_growth)
		print("升级！当前等级: ", GameData.level)

func _exit_battle():
	battle_state = BattleState.NONE
	
	for enemy_node in get_tree().get_nodes_in_group("enemy"):
		if not enemy_node.is_dead and enemy_node.has_method("exit_battle"):
			enemy_node.exit_battle()
	
	current_enemy = null
	enemies.clear()
	
	print("战斗结束，返回地图")
	if previous_scene != "":
		get_tree().change_scene_to_file(previous_scene)

func _after_player_attack():
	if battle_state != BattleState.PLAYER_ACTION:
		return
	
	# 如果怪物没死，让它回 idle
	if current_enemy and is_instance_valid(current_enemy) and not current_enemy.is_dead:
		current_enemy.play_anim("idle")
		print("→ 怪物受伤后回到 idle")
	
	if current_enemy and current_enemy.is_dead:
		current_enemy.die()
	
	_end_player_turn()

func use_skill(skill_index: int):
	if battle_state != BattleState.PLAYER_TURN:
		return

	if not player_battler or player_battler.is_dead or not current_enemy:
		return

	battle_state = BattleState.PLAYER_ACTION
	if combat_scene:
		var ui = combat_scene.get_node_or_null("CombatUI")
		if ui:
			ui.set_buttons_enabled(false)

	match skill_index:
		1:
			print("使用技能1：普通攻击")
			player_battler.attack_enemy(current_enemy)
		2:
			print("使用技能2：强力攻击")
			_skill_power_attack()
		3:
			print("使用技能3：治疗")
			_skill_heal()
		4:
			print("使用技能4：必杀技")
			_skill_ultimate()

func _skill_power_attack():
	if not player_battler or not current_enemy:
		print("→ _skill_power_attack()：没有玩家或敌人")
		return

	print("→ 【强力攻击】开始，玩家攻击力：", player_battler.get_attack())

	player_battler.in_attack = true
	player_battler.is_turn = false
	player_battler.play_job_animation("attack")

	var anim_name = player_battler.get_job_prefix() + "_attack"
	var duration = get_anim_duration(player_battler.animated_sprite, anim_name, 0.4)
	await get_tree().create_timer(duration).timeout

	var hurt_duration = 0.0
	if current_enemy and is_instance_valid(current_enemy):
		var defense_val = current_enemy.get("defense")
		var defense = defense_val if defense_val is int else 0
		var damage = max(1, int(player_battler.get_attack() * 1.5) - defense)
		print("→ 【强力攻击】造成伤害：", damage, "（敌人防御：", defense, "）")
		current_enemy.take_damage(damage)
		
		if current_enemy.has_node("AnimatedSprite2D") and not current_enemy.is_dead:
			var sprite: AnimatedSprite2D = current_enemy.get_node("AnimatedSprite2D")
			var hurt_anim_name = current_enemy.monster_name + "_hurt"
			if sprite.sprite_frames.has_animation(hurt_anim_name):
				hurt_duration = sprite.sprite_frames.get_frame_count(hurt_anim_name) * 0.15
			else:
				hurt_duration = 0.3
	
	if hurt_duration > 0:
		await get_tree().create_timer(hurt_duration).timeout
	
	if current_enemy and is_instance_valid(current_enemy) and not current_enemy.is_dead:
		current_enemy.play_anim("idle")

	player_battler.in_attack = false
	player_battler.play_job_animation("idle")
	_after_player_attack()


func get_anim_duration(sprite: AnimatedSprite2D, anim_name: String, fallback: float) -> float:
	if sprite.sprite_frames.has_animation(anim_name):
		var frame_count = sprite.sprite_frames.get_frame_count(anim_name)
		# Godot 4 用每个动画的 speed 而不是全局的
		var anim_speed = 6.0 # 默认合理速度
		if frame_count > 0:
			# 安全的假设：每帧0.15秒（大概6fps是合理的像素风动画速度）
			var estimate_per_frame = 0.15
			return frame_count * estimate_per_frame
	return fallback


func _skill_heal():
	if not player_battler:
		print("→ _skill_heal()：没有玩家")
		return

	var old_hp = player_battler.get_current_hp()
	var heal_amount = 30
	player_battler.set_current_hp(old_hp + heal_amount)
	var new_hp = player_battler.get_current_hp()
	print("→ 【治疗术】恢复了 ", new_hp - old_hp, " 点HP | 旧HP:", old_hp, " → 新HP:", new_hp)

	await get_tree().create_timer(0.5).timeout
	_end_player_turn()

func _skill_ultimate():
	if not player_battler or not current_enemy:
		print("→ _skill_ultimate()：没有玩家或敌人")
		return

	print("→ 【必杀技】开始，玩家攻击力：", player_battler.get_attack())

	player_battler.in_attack = true
	player_battler.is_turn = false
	player_battler.play_job_animation("attack")

	var anim_name = player_battler.get_job_prefix() + "_attack"
	var duration = get_anim_duration(player_battler.animated_sprite, anim_name, 0.4)
	await get_tree().create_timer(duration).timeout

	var hurt_duration = 0.0
	if current_enemy and is_instance_valid(current_enemy):
		var defense_val = current_enemy.get("defense")
		var defense = defense_val if defense_val is int else 0
		var damage = max(1, int(player_battler.get_attack() * 2.5) - defense)
		print("→ 【必杀技】造成伤害：", damage, "（敌人防御：", defense, "）")
		current_enemy.take_damage(damage)
		
		if current_enemy.has_node("AnimatedSprite2D") and not current_enemy.is_dead:
			var sprite: AnimatedSprite2D = current_enemy.get_node("AnimatedSprite2D")
			var hurt_anim_name = current_enemy.monster_name + "_hurt"
			if sprite.sprite_frames.has_animation(hurt_anim_name):
				hurt_duration = sprite.sprite_frames.get_frame_count(hurt_anim_name) * 0.15
			else:
				hurt_duration = 0.3
	
	if hurt_duration > 0:
		await get_tree().create_timer(hurt_duration).timeout
	
	if current_enemy and is_instance_valid(current_enemy) and not current_enemy.is_dead:
		current_enemy.play_anim("idle")

	player_battler.in_attack = false
	player_battler.play_job_animation("idle")
	_after_player_attack()

func use_heal_potion():
	if battle_state != BattleState.PLAYER_TURN:
		print("→ use_heal_potion()：不在玩家回合")
		return

	if not player_battler or player_battler.is_dead:
		print("→ use_heal_potion()：没有玩家或玩家已死")
		return

	var old_hp = player_battler.get_current_hp()
	var heal_amount = 50
	player_battler.set_current_hp(old_hp + heal_amount)
	var new_hp = player_battler.get_current_hp()
	print("→ 【血瓶】恢复了 ", new_hp - old_hp, " 点HP | 旧HP:", old_hp, " → 新HP:", new_hp)

	await get_tree().create_timer(0.5).timeout
	_end_player_turn()

func use_mana_potion():
	if battle_state != BattleState.PLAYER_TURN:
		print("→ use_mana_potion()：不在玩家回合")
		return

	if not player_battler or player_battler.is_dead:
		print("→ use_mana_potion()：没有玩家或玩家已死")
		return

	var old_mp = player_battler.get_current_mp()
	var mana_amount = 30
	player_battler.set_current_mp(old_mp + mana_amount)
	var new_mp = player_battler.get_current_mp()
	print("→ 【蓝瓶】恢复了 ", new_mp - old_mp, " 点MP | 旧MP:", old_mp, " → 新MP:", new_mp)

	await get_tree().create_timer(0.5).timeout
	_end_player_turn()

func try_escape():
	if battle_state != BattleState.PLAYER_TURN:
		return

	print("尝试逃跑...")
	if randf() < 0.5:
		print("逃跑成功！")
		_end_battle(false)
	else:
		print("逃跑失败！")
		await get_tree().create_timer(0.5).timeout
		_end_player_turn()

func _process(_delta):
	if battle_state != BattleState.STARTING:
		return
	if not get_tree().current_scene:
		return
	if get_tree().current_scene.scene_file_path == "res://scenes/combat_manager.tscn":
		_on_scene_change()
