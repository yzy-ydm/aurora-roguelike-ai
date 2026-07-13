## 怪物生成器
##
## 负责在指定位置生成怪物
## 管理当前房间的怪物列表
## 与ResourceService集成获取MonsterData
## 支持RoomData驱动的房间怪物生成

extends Node

## 怪物场景路径
const MONSTER_SCENE_PATH = "res://scenes/enemy/monster.tscn"

## 当前房间的怪物列表
var _current_room_monsters: Array[MonsterEntity] = []

## 怪物容器节点（添加到GameWorld下）
var _monster_container: Node2D = null

## RoomManager引用
var _room_manager: Node = null

## 信号
signal monster_spawned(monster_entity: MonsterEntity)
signal all_monsters_dead()
signal monster_died_signal(monster_entity: MonsterEntity)


## 初始化
func _ready() -> void:
	# 创建怪物容器
	_monster_container = Node2D.new()
	_monster_container.name = "MonsterContainer"
	print("[MonsterSpawner] Initialized")


## 设置怪物容器的父节点
func setup_container(parent: Node) -> void:
	if _monster_container and not _monster_container.is_inside_tree():
		parent.add_child(_monster_container)
		print("[MonsterSpawner] MonsterContainer added to: ", parent.name)


## 设置RoomManager引用
func set_room_manager(room_manager: Node) -> void:
	_room_manager = room_manager

	# 连接信号
	if _room_manager:
		all_monsters_dead.connect(_room_manager.on_monster_died.bind(0))
		print("[MonsterSpawner] Connected to RoomManager")


## 在指定位置生成怪物
func spawn_monster(monster_data: MonsterData, position: Vector2) -> MonsterEntity:
	if not monster_data:
		print("[MonsterSpawner] Error: monster_data is null")
		return null

	# 加载怪物场景
	var monster_scene = load(MONSTER_SCENE_PATH)
	if not monster_scene:
		print("[MonsterSpawner] Error: Failed to load monster scene")
		return null

	# 实例化怪物
	var monster_node = monster_scene.instantiate()
	if not monster_node:
		print("[MonsterSpawner] Error: Failed to instantiate monster")
		return null

	# 创建怪物实体
	var monster_entity = MonsterEntity.new()
	monster_entity.set_monster_data(monster_data)
	monster_entity.set_position(position)

	# 绑定节点
	monster_entity.bind_monster_node(monster_node)

	# 设置节点的实体引用
	if monster_node.has_method("set_monster_entity"):
		monster_node.set_monster_entity(monster_entity)

	# 添加到容器
	if _monster_container:
		_monster_container.add_child(monster_node)
		monster_node.position = position

	# 添加到列表
	_current_room_monsters.append(monster_entity)

	# 激活实体
	monster_entity.activate()

	print("[MonsterSpawner] Spawned monster: ", monster_data.name, " at ", position)
	monster_spawned.emit(monster_entity)

	return monster_entity


## 为房间生成怪物
func spawn_monsters_for_current_room(room_data: RoomData) -> int:
	if not room_data:
		print("[MonsterSpawner] Error: room_data is null")
		return 0

	# 清除当前怪物
	clear_all_monsters()

	# 获取房间配置
	var room_type = room_data.room_type
	var room_position = room_data.position
	var room_size = Vector2(room_data.width, room_data.height)

	# 根据房间类型决定怪物数量
	var monster_count = _get_monster_count_for_room(room_type)

	print("[MonsterSpawner] Spawning ", monster_count, " monsters for room: ", room_data.room_name)

	# 获取怪物数据
	var monsters = ResourceService.get_monsters()

	# 生成怪物
	for i in range(monster_count):
		var monster_data = _get_random_monster(monsters)
		if monster_data:
			var spawn_pos = _calculate_spawn_position(room_position, room_size)
			spawn_monster(monster_data, spawn_pos)

	# 返回生成的怪物数量
	return _current_room_monsters.size()


## 根据房间类型获取怪物数量
func _get_monster_count_for_room(room_type: String) -> int:
	match room_type:
		"start":
			return 0
		"normal":
			return 3
		"elite":
			return 5
		"boss":
			return 1
		"treasure":
			return 2
		_:
			return 3


## 获取随机怪物数据
func _get_random_monster(monsters: Array[MonsterData]) -> MonsterData:
	if monsters.size() == 0:
		return null

	# 随机选择一个怪物
	var index = randi() % monsters.size()
	return monsters[index]


## 根据MonsterData列表批量生成怪物
func spawn_monsters_for_room(monsters_config: Array, room_position: Vector2, room_size: Vector2) -> void:
	print("[MonsterSpawner] Spawning monsters for room")

	for config in monsters_config:
		var monster_type = config.get("type", "")
		var count = config.get("count", 1)

		# 从ResourceService获取MonsterData
		var monster_data = _get_monster_data_by_type(monster_type)
		if not monster_data:
			print("[MonsterSpawner] Warning: Monster type not found: ", monster_type)
			continue

		# 生成指定数量的怪物
		for i in range(count):
			var spawn_pos = _calculate_spawn_position(room_position, room_size)
			spawn_monster(monster_data, spawn_pos)


## 根据类型获取MonsterData
func _get_monster_data_by_type(monster_type: String) -> MonsterData:
	var monsters = ResourceService.get_monsters()
	for monster in monsters:
		if monster.type == monster_type or monster.name == monster_type:
			return monster

	# 如果没找到，返回第一个怪物
	if monsters.size() > 0:
		return monsters[0]

	return null


## 计算生成位置（在房间内随机）
func _calculate_spawn_position(room_position: Vector2, room_size: Vector2) -> Vector2:
	var x = room_position.x + randf_range(-room_size.x / 2, room_size.x / 2)
	var y = room_position.y + randf_range(-room_size.y / 2, room_size.y / 2)
	return Vector2(x, y)


## 怪物死亡时调用
func on_monster_died(monster_entity: MonsterEntity) -> void:
	if monster_entity in _current_room_monsters:
		_current_room_monsters.erase(monster_entity)
		print("[MonsterSpawner] Monster died, remaining: ", _current_room_monsters.size())

		# 发送信号
		monster_died_signal.emit(monster_entity)

		# 通知RoomManager
		if _room_manager and _room_manager.has_method("on_monster_died"):
			_room_manager.on_monster_died()

		# 检查是否所有怪物都死了
		if _current_room_monsters.size() == 0:
			print("[MonsterSpawner] All monsters dead!")
			all_monsters_dead.emit()


## 获取当前房间怪物数量
func get_monster_count() -> int:
	return _current_room_monsters.size()


## 获取所有存活的怪物
func get_alive_monsters() -> Array[MonsterEntity]:
	var alive: Array[MonsterEntity] = []
	for monster in _current_room_monsters:
		if monster.is_alive():
			alive.append(monster)
	return alive


## 清除所有怪物
func clear_all_monsters() -> void:
	for monster in _current_room_monsters:
		var node = monster.get_monster_node()
		if node and node.is_inside_tree():
			node.queue_free()
	_current_room_monsters.clear()
	print("[MonsterSpawner] All monsters cleared")


## 清除容器
func clear_container() -> void:
	if _monster_container:
		for child in _monster_container.get_children():
			child.queue_free()
	_current_room_monsters.clear()


## 根据RoomContentData生成怪物
func spawn_monsters_from_content(content: RoomContentData, room_position: Vector2, room_size: Vector2) -> int:
	if not content:
		print("[MonsterSpawner] Error: content is null")
		return 0

	# 清除当前怪物
	clear_all_monsters()

	var monster_count = content.monster_count
	var monster_level = content.monster_level
	var monster_types = content.monster_types

	print("[MonsterSpawner] Spawning ", monster_count, " monsters (level ", monster_level, ")")

	# 获取怪物数据
	var monsters = ResourceService.get_monsters()

	# 生成怪物
	for i in range(monster_count):
		var monster_data = _get_monster_by_config(monsters, monster_types, monster_level)
		if monster_data:
			var spawn_pos = _calculate_spawn_position(room_position, room_size)
			var entity = spawn_monster(monster_data, spawn_pos)

			# 根据等级调整怪物属性
			if entity:
				_apply_level_modifier(entity, monster_level)

	# 返回生成的怪物数量
	return _current_room_monsters.size()


## 根据配置获取怪物数据
func _get_monster_by_config(monsters: Array[MonsterData], types: Array[String], level: int) -> MonsterData:
	if monsters.size() == 0:
		return null

	# 如果指定了类型，优先选择指定类型的怪物
	if types.size() > 0:
		var target_type = types[randi() % types.size()]
		for monster in monsters:
			if monster.type == target_type or monster.name == target_type:
				return monster

	# 否则随机选择一个怪物
	return monsters[randi() % monsters.size()]


## 应用等级修正
func _apply_level_modifier(entity: MonsterEntity, level: int) -> void:
	if level <= 1:
		return

	# 根据等级提升怪物属性
	var multiplier = 1.0 + (level - 1) * 0.3
	entity.health = int(entity.health * multiplier)
	entity.max_health = int(entity.max_health * multiplier)
	entity.attack = int(entity.attack * multiplier)
	entity.defense = int(entity.defense * multiplier)

	print("[MonsterSpawner] Applied level ", level, " modifier (x", multiplier, ")")
