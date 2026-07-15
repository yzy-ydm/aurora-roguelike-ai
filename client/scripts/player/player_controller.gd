## 玩家控制器脚本
##
## 负责玩家节点的输入处理、移动控制和数据显示
## 使用CharacterBody2D实现标准移动和碰撞

extends CharacterBody2D

## 移动速度（像素/秒）
const MOVE_SPEED: float = 200.0

## 玩家数据 (兼容旧系统，由PlayerStats同步)
var _player_data: Dictionary = {}

## 玩家属性系统 (Phase 9.4.1: Source of Truth)
var _stats: PlayerStats = null

## 武器系统
var _weapon: Node = null

## 子弹容器
var _bullet_container: Node2D = null
var _bullet_container_ready: bool = false

## ==================== 受伤系统 ====================

## 是否无敌
var _is_invincible: bool = false

## 无敌时间
const INVINCIBLE_TIME: float = 0.8

## 击退强度
const KNOCKBACK_STRENGTH: float = 150.0

## 击退持续时间
const KNOCKBACK_DURATION: float = 0.15

## 当前击退速度
var _knockback_velocity: Vector2 = Vector2.ZERO

## 击退剩余时间
var _knockback_timer: float = 0.0

## 闪烁计时器
var _flash_timer: float = 0.0
const FLASH_INTERVAL: float = 0.08

## 信号
signal player_damaged(damage: int, current_health: int)
signal player_invincible_started()
signal player_invincible_finished()
signal player_dead()  # Phase 15: 玩家死亡信号

## 节点引用
@onready var sprite: Sprite2D = $Sprite
@onready var collision_shape: CollisionShape2D = $CollisionShape
@onready var camera: Camera2D = $Camera2D


func _ready() -> void:
	# 碰撞层设计:
	# Layer 1: Wall   Layer 2: Player   Layer 3: Enemy
	# Layer 4: PlayerBullet   Layer 5: EnemyBullet
	# Player在Layer 2，检测Wall(1)+Enemy(4)
	collision_layer = 2   # Player在第2层
	collision_mask = 5    # 检测第1层(Wall) + 第3层(Enemy)

	# 渲染层级: 始终在背景之上
	z_index = 10

	# 初始化玩家显示
	_setup_player_display()

	# 初始化武器系统
	_setup_weapon()

	# Phase 9.5: 将PlayerStats链接到GameStateManager
	_link_stats_to_game_state()


## Phase 9.5: 将PlayerStats链接到GameStateManager
func _link_stats_to_game_state() -> void:
	var s = get_stats()
	GameStateManager.set_runtime_stats(s)
	print("[Player] PlayerStats linked to GameStateManager")


## Phase 9.5: 同步PlayerStats到GameStateManager
## 在属性变化后调用，确保保存时获取最新数据
func _sync_stats_to_game_state() -> void:
	GameStateManager.sync_from_runtime_stats()


## 物理帧处理（每帧调用）
func _physics_process(delta: float) -> void:
	# 更新击退
	if _knockback_timer > 0:
		_knockback_timer -= delta
		velocity = _knockback_velocity
		move_and_slide()
		return

	# 获取输入方向
	var input_direction = _get_input_direction()

	# 计算速度
	velocity = input_direction * MOVE_SPEED

	# 移动并处理碰撞
	move_and_slide()


## 输入处理
func _input(event: InputEvent) -> void:
	# 鼠标左键攻击
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_try_attack()


## 获取输入方向
func _get_input_direction() -> Vector2:
	var direction = Vector2.ZERO

	# 水平方向
	if Input.is_action_pressed("move_left"):
		direction.x -= 1
	if Input.is_action_pressed("move_right"):
		direction.x += 1

	# 垂直方向
	if Input.is_action_pressed("move_up"):
		direction.y -= 1
	if Input.is_action_pressed("move_down"):
		direction.y += 1

	# 归一化防止对角线移动速度过快
	if direction.length() > 0:
		direction = direction.normalized()

	return direction


## 设置玩家显示
func _setup_player_display() -> void:
	# 创建占位矩形纹理
	var image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.2, 0.6, 1.0, 1.0))
	var texture = ImageTexture.create_from_image(image)
	sprite.texture = texture

	# 创建碰撞形状
	var shape = RectangleShape2D.new()
	shape.size = Vector2(32, 32)
	collision_shape.shape = shape


## 设置武器系统
func _setup_weapon() -> void:
	# 创建武器节点
	_weapon = Node.new()
	_weapon.name = "Weapon"
	_weapon.set_script(load("res://scripts/combat/weapon.gd"))
	add_child(_weapon)

	# 设置武器所有者
	_weapon.set_owner_node(self)

	# 加载武器数据
	_load_weapon_data()

	# 创建子弹容器（deferred避免_ready期间add_child冲突）
	_bullet_container = Node2D.new()
	_bullet_container.name = "Bullets"
	call_deferred("_add_bullet_container")


## deferred回调：将子弹容器添加到场景树
func _add_bullet_container() -> void:
	var game_world = get_parent()
	if game_world:
		game_world.add_child(_bullet_container)
		_weapon.set_bullet_container(_bullet_container)
		_bullet_container_ready = true
		print("[Player] BulletContainer ready")


## 加载武器数据
func _load_weapon_data() -> void:
	# 从ResourceService获取武器数据
	var weapons = ResourceService.get_weapons()

	if weapons.size() > 0:
		# 使用第一个武器，创建WeaponInstance
		var weapon_data = weapons[0]
		var weapon_instance = WeaponInstance.create(weapon_data)
		_weapon.set_weapon_instance(weapon_instance)
		print("[Player] Loaded weapon: ", weapon_data.name, " Lv", weapon_instance.get_level())
	else:
		# 创建默认武器数据，创建WeaponInstance
		var default_weapon = _create_default_weapon_data()
		var weapon_instance = WeaponInstance.create(default_weapon)
		_weapon.set_weapon_instance(weapon_instance)
		print("[Player] Using default weapon Lv", weapon_instance.get_level())


## 创建默认武器数据
func _create_default_weapon_data() -> WeaponData:
	var weapon_data = WeaponData.new()
	weapon_data.id = 0
	weapon_data.name = "basic_gun"
	weapon_data.description = "基础手枪"
	weapon_data.type = "gun"
	weapon_data.rarity = "common"
	weapon_data.damage = 20
	weapon_data.base_damage = 20
	weapon_data.damage_growth = 5
	weapon_data.max_level = 10
	weapon_data.fire_rate = 0.2  # 5发/秒
	weapon_data.bullet_speed = 500.0
	weapon_data.bullet_count = 1
	weapon_data.range = 500.0
	return weapon_data


## 尝试攻击
func _try_attack() -> void:
	if not _weapon:
		return

	# BulletContainer未就绪时禁止发射
	if not _bullet_container_ready:
		return

	# 计算攻击方向（朝向鼠标位置）
	var mouse_pos = get_global_mouse_position()
	var attack_direction = (mouse_pos - position)
	if attack_direction.length() < 1.0:
		# 鼠标在玩家位置上，使用默认方向（向右）
		attack_direction = Vector2.RIGHT
	else:
		attack_direction = attack_direction.normalized()

	# 尝试发射
	_weapon.try_attack(attack_direction)


## 获取玩家攻击力（包含武器伤害）(Phase 9.4.1: 从PlayerStats读取)
func get_attack() -> int:
	var s = get_stats()
	var base_attack = s.attack
	# 如果有武器实例，加上武器伤害
	if _weapon and _weapon.has_method("get_weapon_instance"):
		var weapon_instance = _weapon.get_weapon_instance()
		if weapon_instance:
			return base_attack + weapon_instance.get_damage()
	return base_attack


## 获取武器实例（供外部升级调用）
func get_weapon_instance() -> WeaponInstance:
	if _weapon and _weapon.has_method("get_weapon_instance"):
		return _weapon.get_weapon_instance()
	return null


## 升级武器
func upgrade_weapon() -> bool:
	var weapon_instance = get_weapon_instance()
	if weapon_instance:
		var success = weapon_instance.upgrade()
		if success:
			# Phase 9.5: 同步武器等级到GameStateManager
			GameStateManager.set_extended_save_data("weapon_level", weapon_instance.get_level())
		return success
	return false


## 设置玩家数据 (Phase 9.4.1: 同步到PlayerStats)
func set_player_data(data: Dictionary) -> void:
	_player_data = data

	# 同步到PlayerStats
	if _stats:
		_stats.sync_from_dict(data)
	else:
		_stats = PlayerStats.from_dict(data)

	# Phase 9.5: 同步到GameStateManager
	_sync_stats_to_game_state()

	_update_display()


## 获取玩家数据 (Phase 9.4.1: 从PlayerStats导出)
func get_player_data() -> Dictionary:
	if _stats:
		_player_data = _stats.to_dict()
	return _player_data


## 获取PlayerStats实例 (Phase 9.4.1)
func get_stats() -> PlayerStats:
	if not _stats:
		_stats = PlayerStats.from_dict(_player_data)
	return _stats


## 更新显示
func _update_display() -> void:
	# 未来可以根据玩家数据更新外观
	# 当前阶段只保存数据
	pass


## 获取玩家昵称 (Phase 9.4.1: 从PlayerStats读取)
func get_nickname() -> String:
	var s = get_stats()
	return s.nickname


## 获取玩家等级 (Phase 9.4.1: 从PlayerStats读取)
func get_level() -> int:
	var s = get_stats()
	return s.level


## 获取玩家位置（避免与Node2D内置方法冲突）
func get_player_position() -> Vector2:
	return position


## 设置玩家位置（避免与Node2D内置方法冲突）
func set_player_position(new_position: Vector2) -> void:
	position = new_position


## 受到伤害（供怪物调用）(Phase 9.4.1: 使用PlayerStats)
func take_damage(damage: int, attacker_position: Vector2 = Vector2.ZERO) -> void:
	# 死亡后不再受伤
	if is_dead():
		return

	# 无敌期间不受伤害
	if _is_invincible:
		return

	print("[Player] Took ", damage, " damage!")

	var s = get_stats()
	var actual_damage = s.take_damage(damage)

	# 同步回_player_data
	_player_data = s.to_dict()
	_sync_stats_to_game_state()

	# 发送受伤信号
	player_damaged.emit(actual_damage, s.current_health)

	# 应用击退
	_apply_knockback(attacker_position)

	# 进入无敌状态
	_start_invincibility()

	# 更新显示
	_update_display()

	# 检查是否死亡
	if s.is_dead():
		print("[Player] Player died!")
		_die()

	print("[Player] current health: ", s.current_health)


## 应用击退效果
func _apply_knockback(attacker_position: Vector2) -> void:
	if attacker_position == Vector2.ZERO:
		# 如果没有攻击者位置，使用随机方向
		_knockback_velocity = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * KNOCKBACK_STRENGTH
	else:
		# 从攻击者方向推开
		var direction = (position - attacker_position).normalized()
		_knockback_velocity = direction * KNOCKBACK_STRENGTH
	_knockback_timer = KNOCKBACK_DURATION


## 开始无敌状态
func _start_invincibility() -> void:
	_is_invincible = true
	_flash_timer = 0.0
	player_invincible_started.emit()

	# 启动闪烁效果
	_start_flash_effect()

	# 无敌时间结束后恢复
	await get_tree().create_timer(INVINCIBLE_TIME).timeout

	_is_invincible = false
	sprite.modulate = Color(1, 1, 1, 1)  # 恢复正常显示
	player_invincible_finished.emit()


## 闪烁效果
func _start_flash_effect() -> void:
	while _is_invincible:
		# 切换透明度
		if sprite.modulate.a > 0.5:
			sprite.modulate.a = 0.3
		else:
			sprite.modulate.a = 1.0
		await get_tree().create_timer(FLASH_INTERVAL).timeout


## 添加金币 (Phase 9.4.1: 委托PlayerStats)
func add_gold(amount: int) -> void:
	var s = get_stats()
	s.add_gold(amount)
	_player_data = s.to_dict()
	_sync_stats_to_game_state()


## 添加攻击力 (Phase 9.4.1: 委托PlayerStats)
func add_attack(amount: int) -> void:
	var s = get_stats()
	s.add_attack(amount)
	_player_data = s.to_dict()
	_sync_stats_to_game_state()


## 添加最大生命值 (Phase 9.4.1: 委托PlayerStats)
func add_max_health(amount: int) -> void:
	var s = get_stats()
	s.add_max_health(amount)
	_player_data = s.to_dict()
	_sync_stats_to_game_state()


## 治疗 (Phase 9.4.1: 委托PlayerStats)
func heal(amount: int) -> void:
	var s = get_stats()
	s.heal(amount)
	_player_data = s.to_dict()
	_sync_stats_to_game_state()


## 获得经验 (Phase 9.4.1: 委托PlayerStats)
## 返回是否升级
func gain_exp(amount: int) -> bool:
	var s = get_stats()
	var leveled = s.gain_exp(amount)
	_player_data = s.to_dict()
	_sync_stats_to_game_state()
	return leveled


## ==================== 被动物品系统 (Phase 9.5.1) ====================

## 添加被动物品
func add_passive_item(passive_id: String) -> void:
	var s = get_stats()
	s.add_passive(passive_id)
	_player_data = s.to_dict()
	_sync_stats_to_game_state()
	# 同步到扩展存档数据
	GameStateManager.set_extended_save_data("passive_items", s.get_passive_items())
	print("[Player] Passive item added: ", passive_id)


## 移除被动物品
func remove_passive_item(passive_id: String) -> void:
	var s = get_stats()
	s.remove_passive(passive_id)
	_player_data = s.to_dict()
	_sync_stats_to_game_state()
	# 同步到扩展存档数据
	GameStateManager.set_extended_save_data("passive_items", s.get_passive_items())
	print("[Player] Passive item removed: ", passive_id)


## 检查是否拥有指定被动物品
func has_passive_item(passive_id: String) -> bool:
	var s = get_stats()
	return s.has_passive(passive_id)


## 获取所有被动物品列表
func get_passive_items() -> Array[String]:
	var s = get_stats()
	return s.get_passive_items()


## Phase 15: 玩家死亡处理
var _is_dying: bool = false  # 死亡锁，防止重复触发

func _die() -> void:
	# 防止重复触发死亡
	if _is_dying:
		return
	_is_dying = true

	print("[Player] Player death sequence started")

	# 同步_player_data (Phase 9.4.1)
	if _stats:
		_player_data = _stats.to_dict()

	# 发送死亡信号
	player_dead.emit()

	# 设置游戏状态为GAME_OVER
	GameStateManager.set_state(GameStateManager.GameState.GAME_OVER)

	# 禁用玩家输入
	set_physics_process(false)
	set_process_input(false)

	# 禁用碰撞
	if collision_shape:
		collision_shape.set_deferred("disabled", true)

	# 视觉反馈：变灰
	if sprite:
		sprite.modulate = Color(0.5, 0.5, 0.5, 0.8)

	print("[Player] Player death sequence completed")


## 检查玩家是否死亡 (Phase 9.4.1: 委托PlayerStats)
func is_dead() -> bool:
	var s = get_stats()
	return s.is_dead()


## 重置玩家状态（用于重生）(Phase 9.4.1: 委托PlayerStats)
func revive() -> void:
	var s = get_stats()
	s.revive()
	_player_data = s.to_dict()

	_is_invincible = false
	_is_dying = false
	_knockback_timer = 0.0

	# 恢复输入
	set_physics_process(true)
	set_process_input(true)

	# 恢复碰撞
	if collision_shape:
		collision_shape.disabled = false

	# 恢复视觉
	if sprite:
		sprite.modulate = Color(1, 1, 1, 1)

	print("[Player] Player revived")
