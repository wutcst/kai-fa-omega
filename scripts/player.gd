extends CharacterBody2D

# ====================== 【节点引用】 ======================
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
# 箭矢预制体
@export var arrow_scene: PackedScene
# ====================== 【基础属性系统】 ======================
@export var max_hp: int = 100    # 最大血量
@export var current_hp: int = 100 # 当前血量
@export var max_mp: int = 50     # 最大蓝量
@export var current_mp: int = 50 # 当前蓝量

@export var attack: int = 10     # 攻击力
@export var defense: int = 5     # 防御力
@export var base_speed: int = 200 # 基础移动速度
var current_speed: int = 200     # 当前移动速度（受职业影响）

# ====================== 【职业枚举】 ======================
enum Job {
	SWORDSMAN,  # 剑士（默认）
	RANGER,     # 游侠（弓箭手）：高速远程
	SHIELD_KNIGHT # 盾骑士：高防近战
}

var current_job: Job = Job.SWORDSMAN
var is_dead: bool = false # 死亡状态控制
var is_attacking: bool = false # 攻击状态锁，防止动画被打断
var attack_timer: float = 0.0 # 攻击超时兜底，防止永久卡死
const ATTACK_MAX_DURATION: float = 0.5 # 攻击最长持续时间（秒）

# ====================== 【游戏初始化】 ======================
func _ready():
	# 初始化职业属性
	update_job_stats()
	# 初始化播放当前职业的待机动画
	play_job_animation("idle")
# 自动连接动画结束信号
	if not animated_sprite.animation_finished.is_connected(_on_animated_sprite_animation_finished):
		animated_sprite.animation_finished.connect(_on_animated_sprite_animation_finished)
	print("玩家初始化完成 | 当前职业：", get_job_name())

# ====================== 【核心：物理帧更新（移动逻辑）】 ======================
func _physics_process(delta: float) -> void:
	# 攻击超时兜底：超过0.5秒强制解锁，防止永久卡死
	if is_attacking:
		attack_timer += delta
		if attack_timer >= ATTACK_MAX_DURATION:
			is_attacking = false
			attack_timer = 0.0
			play_job_animation("idle")
			print("攻击超时，强制解锁")
	
	# 死亡/攻击中 禁止移动动画打断攻击
	if is_dead or is_attacking:
		return
	
	# 1. 获取输入
	var input_dir = Input.get_vector("left", "right", "up", "down")
	
	# 2. 移动
	velocity = input_dir * current_speed
	move_and_slide()

	# 3. 播放动画（攻击中不执行，防止打断）
	if input_dir.length() > 0:
		play_job_animation("walk")
		# 左右翻转
		if input_dir.x > 0:
			animated_sprite.flip_h = false
		else:
			animated_sprite.flip_h = true
	else:
		play_job_animation("idle")

# ====================== 【职业切换核心函数】 ======================
func switch_job(new_job: Job) -> void:
	# 死亡/攻击中 禁止切换职业
	if is_dead or is_attacking:
		return
	
	# 防止重复切换
	if current_job == new_job:
		print("已是该职业！")
		return
	
	# 更新当前职业
	current_job = new_job
	# 刷新职业属性
	update_job_stats()
	# 切换职业后，自动播放新职业的待机动画
	play_job_animation("idle")
	
	print("切换职业为：", get_job_name())
	print("当前属性 → 攻击:", attack, " 防御:", defense, " 速度:", current_speed)

# ====================== 【根据职业刷新属性】 ======================
func update_job_stats() -> void:
	match current_job:
		# 剑士：平衡型近战
		Job.SWORDSMAN:
			max_hp = 120
			max_mp = 40
			attack = 15
			defense = 8
			current_speed = 180
		
		# 游侠：高速远程、低防高机动
		Job.RANGER:
			max_hp = 90
			max_mp = 60
			attack = 12
			defense = 4
			current_speed = 280
		
		# 盾骑士：高防高血量、低速近战
		Job.SHIELD_KNIGHT:
			max_hp = 180
			max_mp = 30
			attack = 8
			defense = 15
			current_speed = 120
	
	# 切换职业后满血满蓝
	current_hp = max_hp
	current_mp = max_mp

# ====================== 【核心：播放当前职业的动画】 ======================
func play_job_animation(action_name: String) -> void:
	var full_animation_name = get_job_prefix() + "_" + action_name
	if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(full_animation_name):
		animated_sprite.play(full_animation_name)

# ====================== 【核心：攻击函数】 ======================
func perform_attack() -> void:
	# 死亡/攻击中 禁止重复攻击
	if is_dead or is_attacking:
		print("攻击被锁定：死亡或正在攻击中")
		return
	
	# 开启攻击锁
	is_attacking = true
	attack_timer = 0.0
	# 播放攻击动画（所有职业通用）
	play_job_animation("attack")
	print("触发攻击！职业：", get_job_name())
	#攻击代码内部
	


	# 游侠专属：生成箭矢
	if current_job == Job.RANGER and arrow_scene != null:
		# 实例化箭矢
		var arrow = arrow_scene.instantiate()
		arrow.damage = attack

		# 适配人物朝向
		var shoot_dir = Vector2.RIGHT
		if animated_sprite.flip_h:
			shoot_dir = Vector2.LEFT

		# 箭矢生成在人物前方，避免贴脸
		arrow.global_position = global_position + shoot_dir * 30
		arrow.dir = shoot_dir

		# 添加到场景
		get_parent().add_child(arrow)
# ====================== 【工具函数】 ======================
# 获取职业动画前缀（完美匹配你的ranger动画）
func get_job_prefix() -> String:
	match current_job:
		Job.SWORDSMAN: return "swordsman"
		Job.RANGER: return "ranger"
		Job.SHIELD_KNIGHT: return "shield_knight"
		_: return "swordsman" # 默认兜底：返回剑士前缀，避免报错

# 获取职业名称
func get_job_name() -> String:
	match current_job:
		Job.SWORDSMAN: return "剑士"
		Job.RANGER: return "游侠"
		Job.SHIELD_KNIGHT: return "盾骑士"
		_: return "剑士" # 默认兜底：返回剑士名称，避免报错

# ====================== 【战斗系统通用函数】 ======================
# 受伤函数
func take_damage(raw_damage: int) -> int:
	if is_dead:
		return 0
	
	var real_damage = max(raw_damage - defense, 1)
	current_hp = max(current_hp - real_damage, 0)
	# 受伤时播放受伤动画
	play_job_animation("hurt")
	print("受到伤害：", real_damage, " | 剩余血量：", current_hp)
	
	# 血量为0时触发死亡
	if current_hp <= 0:
		die()
	return real_damage

# 死亡函数
func die() -> void:
	is_dead = true
	# 播放死亡动画
	play_job_animation("death")
	# 禁用碰撞，防止后续交互
	collision_shape.set_deferred("disabled", true)
	print("玩家已死亡！")

# 回血函数
func heal_hp(amount: int) -> void:
	current_hp = min(current_hp + amount, max_hp)

# 回蓝函数
func heal_mp(amount: int) -> void:
	current_mp = min(current_mp + amount, max_mp)

# ====================== 【测试按键】 ======================
func _process(delta: float) -> void:
	# 职业切换
	if Input.is_action_just_pressed("ui_swordsman"):
		switch_job(Job.SWORDSMAN)
	if Input.is_action_just_pressed("ui_ranger"):
		switch_job(Job.RANGER)
	if Input.is_action_just_pressed("ui_shield"):
		switch_job(Job.SHIELD_KNIGHT)
	if Input.is_action_just_pressed("ui_attack"):
		perform_attack()

# ====================== 【动画结束自动处理】 ======================

func _on_animated_sprite_animation_finished(animation_name: String) -> void:
	print("动画结束：", animation_name)
	# 攻击动画播完：解锁攻击状态，切回待机
	if animation_name.ends_with("_attack"):
		is_attacking = false
		attack_timer = 0.0
		play_job_animation("idle")
	
	# 受伤动画播完：切回待机
	if animation_name.ends_with("_hurt"):
		play_job_animation("idle")
