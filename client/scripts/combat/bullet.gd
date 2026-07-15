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

## 生命周期
var lifetime: float = 3.0
var _age: float = 0.0

## 节点引用
@onready var sprite: Sprite2D = $Sprite
@onready var collision_shape: CollisionShape2D = $CollisionShape

## DamageSystem引用
var _damage_system: Node = null


## 子弹阵营（false=玩家子弹, true=敌人子弹）
var is_enemy_bullet: bool = false


## 初始化
func _ready() -> void:
	# 碰撞层设计:
	# Layer 1: Wall   Layer 2: Player   Layer 3: Enemy
	# Layer 4: PlayerBullet   Layer 5: EnemyBullet
	if is_enemy_bullet:
		# 敌人子弹: 检测Wall(1) + Player(2)
		collision_layer = 0   # 敌人子弹不需要被检测
		collision_mask = 3    # 检测第1层(Wall) + 第2层(Player)
	else:
		# 玩家子弹: 检测Wall(1) + Enemy(4)
		collision_layer = 16  # PlayerBullet在第4层
		collision_mask = 5    # 检测第1层(Wall) + 第3层(Enemy)

	# 渲染层级: 子弹在玩家和敌人之上
	z_index = 20

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


## 设置子弹属性
func setup(bullet_damage: int, bullet_speed: float, bullet_direction: Vector2, critical: bool = false, bullet_source: Node2D = null, enemy_bullet: bool = false) -> void:
	damage = bullet_damage
	speed = bullet_speed if bullet_speed > 0 else 500.0
	direction = bullet_direction.normalized()
	is_critical = critical
	source = bullet_source
	is_enemy_bullet = enemy_bullet


## 设置外观
func _setup_appearance() -> void:
	# 创建白色圆形子弹
	var image = Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
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


## 每帧更新
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
		_hit_target(body)
	elif body.has_method("take_damage") and not body.has_method("get_player_data"):
		# 兼容：有take_damage但不是玩家的节点
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
	else:
		# 如果没有DamageSystem，直接调用take_damage
		if target.has_method("take_damage"):
			target.take_damage(damage)
		destroy()


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
