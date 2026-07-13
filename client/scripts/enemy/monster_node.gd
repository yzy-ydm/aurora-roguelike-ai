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

## 节点引用
@onready var sprite: Sprite2D = $Sprite
@onready var collision_shape: CollisionShape2D = $CollisionShape
@onready var health_bar: ProgressBar = $HealthBar


## 初始化
func _ready() -> void:
	# 设置碰撞层
	# 怪物在第3层，检测第1层（玩家）和第2层（子弹）
	collision_layer = 4  # 怪物在第3层
	collision_mask = 1   # 检测第1层（玩家）

	_setup_display()
	_setup_ai()


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

	# 创建碰撞形状
	var shape = RectangleShape2D.new()
	shape.size = Vector2(28, 28)
	collision_shape.shape = shape

	# 设置血条
	if health_bar:
		health_bar.max_value = 100
		health_bar.value = 100
		health_bar.visible = true


## 设置AI
func _setup_ai() -> void:
	# 创建AI节点
	_monster_ai = Node.new()
	_monster_ai.name = "MonsterAI"
	_monster_ai.set_script(load("res://scripts/enemy/monster_ai.gd"))
	add_child(_monster_ai)


## 每帧更新
func _physics_process(delta: float) -> void:
	if not _monster_entity or not _monster_entity.is_alive():
		return

	# 更新AI
	if _monster_ai and _monster_ai.has_method("update"):
		_monster_ai.update(delta)

	# 同步位置到实体
	_monster_entity.sync_position_from_node()


## 更新显示
func _update_display() -> void:
	if not _monster_entity:
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
		print("[Monster] Health: ", _monster_entity.get_health(), "/", _monster_entity.get_max_health())

	# 更新显示
	_update_display()

	# 检查是否死亡
	if not _monster_entity.is_alive():
		on_death()


## 死亡处理
func on_death() -> void:
	print("[Monster] ", _monster_entity.get_monster_name(), " died!")

	# 禁用碰撞
	if collision_shape:
		collision_shape.disabled = true

	# 通知Spawner
	var spawner = get_parent()
	if spawner and spawner.has_method("on_monster_died"):
		spawner.on_monster_died(_monster_entity)

	# 延迟销毁
	await get_tree().create_timer(0.5).timeout
	queue_free()


## 获取怪物实体
func get_monster_entity() -> MonsterEntity:
	return _monster_entity


## 获取AI状态
func get_ai_state() -> String:
	if _monster_ai and _monster_ai.has_method("get_ai_state_string"):
		return _monster_ai.get_ai_state_string()
	return "unknown"
