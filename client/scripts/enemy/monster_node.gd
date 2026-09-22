## 怪物节点脚本
##
## 挂载到怪物CharacterBody2D节点
## 负责怪物的物理行为、碰撞检测
## 与MonsterEntity和MonsterAI配合工作

extends CharacterBody2D

## 怪物实体引用
var _monster_entity: MonsterEntity = null

## 怪物AI
var _monster_ai: Node = null

## ==================== 受击反馈 ====================

## 是否正在受击反馈
var _is_hit_stunned: bool = false

## Phase 21.1.1: 死亡状态标志（防重复触发）
var _is_dying: bool = false

## 受击硬直时间
const HIT_STUN_DURATION: float = 0.1

## 闪白持续时间
const FLASH_DURATION: float = 0.1

## 原始颜色
var _original_color: Color = Color(0.9, 0.2, 0.2, 1.0)

## 节点引用
@onready var sprite: Sprite2D = $Sprite
@onready var collision_shape: CollisionShape2D = $CollisionShape
@onready var health_bar: ProgressBar = $HealthBar


## 初始化
func _ready() -> void:
	# 碰撞层设计:
	# Layer 1: Wall   Layer 2: Player   Layer 3: Enemy
	# Layer 4: PlayerBullet   Layer 5: EnemyBullet
	# Enemy在Layer 3，检测Wall(1) + Player(2)
	collision_layer = 4  # Enemy在第3层
	collision_mask = 3   # Phase 17.5: 检测第1层(Wall) + 第2层(Player)

	# Phase 17.4: 渲染层级设置
	z_index = 10  # Monster在第10层

	_setup_display()
	_setup_ai()

	# Phase 17.4: 调试日志
	print("[MonsterNode Ready] name=", name, " position=", position, " global_position=", global_position, " parent=", get_parent().name if get_parent() else "none")


## 设置怪物实体
func set_monster_entity(entity: MonsterEntity) -> void:
	_monster_entity = entity
	_update_display()

	# 初始化AI
	if _monster_ai and _monster_ai.has_method("initialize"):
		_monster_ai.initialize(self, _monster_entity)


## 设置显示
func _setup_display() -> void:
	# 创建红色方块作为怪物外观
	var image = Image.create(28, 28, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.9, 0.2, 0.2, 1.0))  # 红色
	var texture = ImageTexture.create_from_image(image)
	sprite.texture = texture

	# Phase 17.4: 确保Sprite z_index正确
	sprite.z_index = 10

	# 创建碰撞形状
	var shape = RectangleShape2D.new()
	shape.size = Vector2(28, 28)
	collision_shape.shape = shape

	# 设置血条
	if health_bar:
		health_bar.visible = true
		# 初始值在 set_monster_entity 中由 _update_display() 覆盖


## 设置AI
func _setup_ai() -> void:
	# 创建AI节点
	_monster_ai = Node.new()
	_monster_ai.name = "MonsterAI"
	_monster_ai.set_script(load("res://scripts/enemy/monster_ai.gd"))
	add_child(_monster_ai)


## ==================== Phase 17.1: 横版重力配置 ====================

## 重力加速度
const GRAVITY: float = 980.0

## 最大下落速度
const MAX_FALL_SPEED: float = 600.0

## Phase 17.6: 掉落保护
var _last_safe_position: Vector2 = Vector2.ZERO
const FALL_LIMIT: float = 1000.0


## 每帧更新 (Phase 17.1: 添加重力, Phase 17.6: 添加掉落保护)
func _physics_process(delta: float) -> void:
	if not _monster_entity or not _monster_entity.is_alive():
		return

	# 受击硬直时不移动
	if _is_hit_stunned:
		velocity = Vector2.ZERO
		return

	# 应用重力
	if not is_on_floor():
		velocity.y += GRAVITY * delta
		velocity.y = min(velocity.y, MAX_FALL_SPEED)
	else:
		# 在地面上时重置垂直速度
		if velocity.y > 0:
			velocity.y = 0
		# 记录安全位置
		_last_safe_position = global_position

	# Phase 17.6: 掉落保护
	if global_position.y > FALL_LIMIT:
		print("[Monster Respawn] name=", name, " y=", global_position.y)
		global_position = _last_safe_position
		velocity = Vector2.ZERO

	# 更新AI
	if _monster_ai and _monster_ai.has_method("update"):
		_monster_ai.update(delta)

	# 确保物理碰撞生效
	move_and_slide()

	# 同步位置到实体
	_monster_entity.sync_position_from_node()


## 更新显示
func _update_display() -> void:
	if not _monster_entity:
		return

	# 安全检查：确保节点已加载
	if not sprite:
		push_warning("[MonsterNode] Missing display node: Sprite")
		return

	# 更新血条
	if health_bar:
		health_bar.max_value = _monster_entity.get_max_health()
		health_bar.value = _monster_entity.get_health()

	# 根据怪物类型设置不同颜色
	var monster_type = _monster_entity.get_monster_type()
	match monster_type:
		"normal":
			sprite.modulate = Color(0.9, 0.2, 0.2, 1.0)  # 红色
		"elite":
			sprite.modulate = Color(0.8, 0.2, 0.8, 1.0)  # 紫色
		"boss":
			sprite.modulate = Color(1.0, 0.5, 0.0, 1.0)  # 橙色


## 受到伤害
func take_damage(damage: int) -> void:
	if not _monster_entity:
		return

	print("[Monster] ", _monster_entity.get_monster_name(), " took ", damage, " damage")

	_monster_entity.take_damage(damage)

	# 更新血条
	if health_bar:
		health_bar.max_value = _monster_entity.get_max_health()
		health_bar.value = _monster_entity.get_health()

	# 受击反馈
	_play_hit_feedback()

	# 更新显示
	_update_display()

	# Boss受伤通知(让BossController处理阶段转换和信号)
	_notify_boss_controller_damaged(damage)

	# 检查是否死亡
	if not _monster_entity.is_alive():
		# Boss死亡由BossController处理
		if _is_boss() and _find_boss_controller():
			_notify_boss_controller_death()
		else:
			on_death()


## 检查是否是Boss
func _is_boss() -> bool:
	if _monster_entity:
		return _monster_entity.get_monster_type() == "boss"
	return false


## 查找BossController(在兄弟节点中查找)
func _find_boss_controller() -> Node:
	var parent = get_parent()
	if not parent:
		return null
	for child in parent.get_children():
		if child.has_method("get") and child.get("_boss_entity"):
			return child
	return null


## 通知BossController受伤
func _notify_boss_controller_damaged(damage: int) -> void:
	var boss_ctrl = _find_boss_controller()
	if boss_ctrl:
		# boss_damaged是BossController的信号,直接emit
		if "boss_damaged" in boss_ctrl:
			boss_ctrl.boss_damaged.emit(damage, _monster_entity.get_health())


## 通知BossController死亡
func _notify_boss_controller_death() -> void:
	var boss_ctrl = _find_boss_controller()
	if boss_ctrl:
		# 调用BossController的内部死亡处理
		if boss_ctrl.has_method("_on_boss_death"):
			boss_ctrl._on_boss_death()
	# 同时执行MonsterNode的死亡动画
	on_death()


## 攻击玩家(通过DamageSystem计算伤害)
func attack_player(player_node: Node2D) -> void:
	if not _monster_entity or not player_node:
		return

	# 查找DamageSystem
	var damage_system = _find_damage_system()
	if damage_system and damage_system.has_method("on_monster_attack_player"):
		damage_system.on_monster_attack_player(self, player_node)
	else:
		# Fallback: 直接调用take_damage(无防御计算)
		print("[MonsterNode] DamageSystem not found, using fallback")
		if player_node.has_method("take_damage"):
			player_node.take_damage(_monster_entity.get_attack(), position)


## 查找DamageSystem
func _find_damage_system() -> Node:
	var root = Engine.get_main_loop().root
	if root:
		var game_scene = root.get_node_or_null("GameScene")
		if game_scene:
			return game_scene.get_node_or_null("DamageSystem")
	return null


## 播放受击反馈
func _play_hit_feedback() -> void:
	# 闪白效果
	_flash_white()

	# 短暂硬直
	_apply_hit_stun()


## 闪白效果
func _flash_white() -> void:
	if not sprite:
		return
	# 记住原始颜色
	_original_color = sprite.modulate
	# 设置为白色
	sprite.modulate = Color(1, 1, 1, 1)
	# 延迟恢复
	await get_tree().create_timer(FLASH_DURATION).timeout
	if sprite and is_instance_valid(sprite):
		sprite.modulate = _original_color


## 受击硬直
func _apply_hit_stun() -> void:
	_is_hit_stunned = true
	# 停止移动(通过设置速度为0)
	velocity = Vector2.ZERO
	await get_tree().create_timer(HIT_STUN_DURATION).timeout
	_is_hit_stunned = false


## 死亡处理
func on_death() -> void:
	# Phase 21.1.1: 防止重复触发死亡
	if _is_dying:
		return
	_is_dying = true

	print("[Monster] ", _monster_entity.get_monster_name(), " died!")

	# 禁用碰撞（使用set_deferred避免在物理回调期间修改状态）
	if collision_shape:
		collision_shape.set_deferred("disabled", true)

	# 通知死亡系统(优先RoomSpawner, 兼容旧系统)
	var notified = false

	# 方式1: 父节点有on_monster_died方法(旧MonsterSpawner)
	var parent = get_parent()
	if parent and parent.has_method("on_monster_died"):
		parent.on_monster_died(_monster_entity)
		notified = true

	# 方式2: 通过场景树查找RoomSpawner(新系统)
	if not notified:
		var root = get_tree().current_scene
		if root:
			var floor_manager = root.get_node_or_null("FloorManager")
			if floor_manager:
				var room_spawner = floor_manager.get_node_or_null("RoomSpawner")
				if room_spawner and room_spawner.has_method("on_monster_died"):
					room_spawner.on_monster_died(_monster_entity)
					notified = true

	# 延迟销毁
	await get_tree().create_timer(0.5).timeout
	queue_free()


## 获取怪物实体
func get_monster_entity() -> MonsterEntity:
	return _monster_entity


## 获取攻击力(统一接口, 委托MonsterEntity)
func get_attack() -> int:
	if _monster_entity:
		return _monster_entity.get_attack()
	return 10


## 获取防御力(统一接口, 委托MonsterEntity)
func get_defense() -> int:
	if _monster_entity:
		return _monster_entity.get_defense()
	return 0


## 获取AI状态
func get_ai_state() -> String:
	if _monster_ai and _monster_ai.has_method("get_ai_state_string"):
		return _monster_ai.get_ai_state_string()
	return "unknown"
