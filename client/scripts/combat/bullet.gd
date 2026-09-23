## 子弹脚本
##
## 负责子弹的移动、碰撞检测
## 命中目标时通知DamageSystem处理伤害

extends Area2D

## 子弹属性
var damage: int = 10
var is_critical: bool = false
var speed: float = 500.0
var direction: Vector2 = Vector2.RIGHT
var source: Node2D = null  # 发射者
var weapon_type: String = ""  # fire/ice/thunder/gun

## 生命周期 (Phase 17.2: 优化限制)
var lifetime: float = 2.0  # 最大存活时间
var _age: float = 0.0
var _start_position: Vector2 = Vector2.ZERO  # 起始位置
const MAX_DISTANCE: float = 1200.0  # 最大飞行距离

## Phase 17.3: 房间边界检测
const ROOM_HALF_WIDTH: float = 640.0
const ROOM_HALF_HEIGHT: float = 360.0
var _room_center: Vector2 = Vector2.ZERO

## 节点引用
@onready var sprite: Sprite2D = $Sprite
@onready var collision_shape: CollisionShape2D = $CollisionShape

## DamageSystem引用
var _damage_system: Node = null


## 子弹阵营（false=玩家子弹, true=敌人子弹）
var is_enemy_bullet: bool = false


## 初始化
func _ready() -> void:
	# 碰撞层设计（数值约定: Wall=1, Player=2, Enemy=4, PlayerBullet=8, EnemyBullet=16）:
	# TASK-001 核对: 掩码值按二进制位解释。5 = 1+4 = Wall + Enemy ✓
	# （项目注释中的"第N层"写法与实际位值不一致，请以数值为准）
	if is_enemy_bullet:
		# 敌人子弹: 检测Wall(1) + Player(2)
		collision_layer = 16  # EnemyBullet
		collision_mask = 3    # 1(Wall) + 2(Player)
	else:
		# 玩家子弹: 检测Wall(1) + Enemy(4)
		collision_layer = 8   # PlayerBullet
		collision_mask = 5    # 1(Wall) + 4(Enemy)

	# 渲染层级: 子弹在玩家和敌人之上
	z_index = 20

	# Phase 17.2: 记录起始位置
	_start_position = global_position

	# Phase 17.3: 记录房间中心（用于边界检测）
	_room_center = _get_room_center()

	# 出生保护: 短暂禁用碰撞，防止与发射者重叠时立即销毁
	if collision_shape:
		collision_shape.disabled = true

	# 设置碰撞检测
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

	# 创建外观
	_setup_appearance()

	# 查找DamageSystem
	_find_damage_system()

	print("[Bullet] Created pos:", global_position, " dir:", direction, " speed:", speed)

	# 出生保护: 等待2个物理帧后恢复碰撞
	await get_tree().physics_frame
	await get_tree().physics_frame
	if collision_shape and is_inside_tree():
		collision_shape.disabled = false


## 获取当前房间中心（用于边界检测）
func _get_room_center() -> Vector2:
	var root = Engine.get_main_loop().root
	if root:
		var game_scene = root.get_node_or_null("GameScene")
		if game_scene:
			var floor_manager = game_scene.get_node_or_null("FloorManager")
			if floor_manager and floor_manager.has_method("get_current_room"):
				var current_room = floor_manager.get_current_room()
				if current_room:
					return current_room.position
	return Vector2.ZERO


## 设置子弹属性
func setup(bullet_damage: int, bullet_speed: float, bullet_direction: Vector2, critical: bool = false, bullet_source: Node2D = null, enemy_bullet: bool = false, weapon_type_str: String = "") -> void:
	damage = bullet_damage
	speed = bullet_speed if bullet_speed > 0 else 500.0
	direction = bullet_direction.normalized()
	is_critical = critical
	source = bullet_source
	is_enemy_bullet = enemy_bullet
	weapon_type = weapon_type_str


## 设置外观
func _setup_appearance() -> void:
	# 根据武器类型设置子弹颜色
	var color = Color.WHITE
	match weapon_type:
		"fire":
			color = Color(1.0, 0.3, 0.1, 1.0)
		"ice":
			color = Color(0.2, 0.7, 1.0, 1.0)
		"thunder":
			color = Color(0.9, 0.8, 0.1, 1.0)
		_:
			color = Color.WHITE

	var image = Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(color)
	var texture = ImageTexture.create_from_image(image)
	sprite.texture = texture

	# 创建碰撞形状
	var shape = CircleShape2D.new()
	shape.radius = 4.0
	collision_shape.shape = shape


## 查找DamageSystem
func _find_damage_system() -> void:
	# 在场景树中查找DamageSystem
	var root = Engine.get_main_loop().root
	if root:
		var game_scene = root.get_node_or_null("GameScene")
		if game_scene:
			_damage_system = game_scene.get_node_or_null("DamageSystem")

	if not _damage_system:
		print("[Bullet] Warning: DamageSystem not found")


## 每帧更新 (Phase 17.2: 添加距离限制, Phase 17.3: 添加边界检测)
func _process(delta: float) -> void:
	# 移动子弹
	position += direction * speed * delta

	# 调试: 首帧输出移动日志
	if _age == 0.0:
		print("[Bullet] Moving pos:", global_position, " vel:", direction * speed)

	# 更新生命周期
	_age += delta
	if _age >= lifetime:
		destroy()
		return

	# Phase 17.2: 距离检查
	var distance_traveled = global_position.distance_to(_start_position)
	if distance_traveled >= MAX_DISTANCE:
		destroy()
		return

	# Phase 17.3: 房间边界检查
	if _is_outside_room():
		destroy()


## 碰撞检测 - 检测CharacterBody2D
func _on_body_entered(body: Node2D) -> void:
	# 忽略发射者（防止极端情况下的自伤）
	if body == source:
		return

	# 墙壁碰撞 → 销毁子弹
	if body is StaticBody2D:
		destroy()
		return

	# 怪物碰撞 → 造成伤害
	# 检查是否是MonsterNode（有take_damage和get_monster_entity）
	if body.has_method("take_damage") and body.has_method("get_monster_entity"):
		print("[Bullet] Hit monster: ", body.name)
		_hit_target(body)
	elif body.has_method("take_damage") and not body.has_method("get_player_data"):
		# 兼容：有take_damage但不是玩家的节点
		print("[Bullet] Hit target: ", body.name)
		_hit_target(body)


## 碰撞检测 - 检测Area2D
func _on_area_entered(area: Area2D) -> void:
	# 忽略发射者
	if area == source:
		return

	# 检查父节点是否是发射者（防止通过子Area2D误伤发射者）
	var parent = area.get_parent()
	if parent == source:
		return

	# 检查父节点是否是可伤害目标（怪物的子Area2D等）
	if parent and parent.has_method("take_damage"):
		_hit_target(parent)


## 命中目标
func _hit_target(target: Node2D) -> void:
	if _damage_system and _damage_system.has_method("on_bullet_hit"):
		_damage_system.on_bullet_hit(self, target)
		return  # Phase 21.1.1: DamageSystem内部会调用destroy()，避免重复执行

	# 如果没有DamageSystem，直接调用take_damage
	if target.has_method("take_damage"):
		target.take_damage(damage)
	destroy()


## Phase 17.3: 检查子弹是否在房间边界外
func _is_outside_room() -> bool:
	var local_pos = global_position - _room_center
	return (
		local_pos.x < -ROOM_HALF_WIDTH - 50 or
		local_pos.x > ROOM_HALF_WIDTH + 50 or
		local_pos.y < -ROOM_HALF_HEIGHT - 50 or
		local_pos.y > ROOM_HALF_HEIGHT + 50
	)


## 销毁子弹
func destroy() -> void:
	# 禁用碰撞（使用set_deferred避免在物理回调期间修改状态）
	if collision_shape:
		collision_shape.set_deferred("disabled", true)

	# 从场景树移除（queue_free本身就是延迟的，但配合set_deferred使用更安全）
	if is_inside_tree():
		queue_free()


## 获取子弹伤害
func get_damage() -> int:
	return damage


## 获取是否暴击
func get_is_critical() -> bool:
	return is_critical


## 获取发射者
func get_source() -> Node2D:
	return source
