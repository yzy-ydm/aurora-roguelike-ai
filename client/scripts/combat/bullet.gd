## 子弹脚本
##
## 负责子弹的移动、碰撞检测
## 命中目标时通知DamageSystem处理伤害

extends Area2D

## 子弹属性
var damage: int = 10
var is_critical: bool = false
var speed: float = 400.0
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


## 初始化
func _ready() -> void:
	# 设置碰撞层
	# 子弹在第2层，检测第3层的怪物
	collision_layer = 2  # 子弹在第2层
	collision_mask = 4   # 检测第3层（怪物）

	# 设置碰撞检测
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

	# 创建外观
	_setup_appearance()

	# 查找DamageSystem
	_find_damage_system()


## 设置子弹属性
func setup(bullet_damage: int, bullet_speed: float, bullet_direction: Vector2, critical: bool = false, bullet_source: Node2D = null) -> void:
	damage = bullet_damage
	speed = bullet_speed
	direction = bullet_direction.normalized()
	is_critical = critical
	source = bullet_source


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

	# 更新生命周期
	_age += delta
	if _age >= lifetime:
		destroy()


## 碰撞检测 - 检测CharacterBody2D
func _on_body_entered(body: Node2D) -> void:
	# 忽略发射者
	if body == source:
		return

	# 检查是否是怪物
	if body.has_method("take_damage") and body.has_method("get_monster_entity"):
		_hit_target(body)


## 碰撞检测 - 检测Area2D
func _on_area_entered(area: Area2D) -> void:
	# 忽略发射者
	if area == source:
		return

	# 检查父节点是否是怪物
	var parent = area.get_parent()
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
	# 禁用碰撞
	if collision_shape:
		collision_shape.disabled = true

	# 从场景树移除
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
