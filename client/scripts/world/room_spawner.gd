## 房间生成器 (Phase 10.1.5)
##
## 根据RoomData生成怪物和奖励
## 解耦MonsterSpawner和DropManager的直接调用
##
## 职责:
## - 根据RoomContentData生成怪物(正确坐标)
## - 根据RoomContentData生成奖励(正确坐标)
## - 管理当前房间的怪物和奖励生命周期

extends Node

## ==================== 引用 ====================

## 怪物容器
var _monster_container: Node2D = null

## 奖励容器
var _reward_container: Node2D = null

## 玩家引用
var _player: CharacterBody2D = null

## ==================== 状态 ====================

## 当前房间的怪物列表
var _current_monsters: Array[MonsterEntity] = []

## 当前房间的奖励列表
var _current_rewards: Array[Node] = []

## ==================== 信号 ====================

## 怪物生成
signal monster_spawned(entity: MonsterEntity)

## 所有怪物死亡
signal all_monsters_dead()

## 怪物死亡
signal monster_died(entity: MonsterEntity)

## 奖励生成
signal reward_spawned(data: RewardData)

## 奖励收集
signal reward_collected(data: RewardData)

## 所有奖励收集
signal all_rewards_collected()


## ==================== 初始化 ====================

func set_monster_container(container: Node2D) -> void:
	_monster_container = container


func set_reward_container(container: Node2D) -> void:
	_reward_container = container


func set_player(player: CharacterBody2D) -> void:
	_player = player


## ==================== 怪物生成 ====================

## 根据房间内容生成怪物
## room_center: 房间中心的世界坐标
func spawn_monsters(content: RoomContentData, room_center: Vector2) -> int:
	if not content or content.monster_count <= 0:
		return 0

	# 清除旧怪物
	clear_monsters()

	var monsters = ResourceService.get_monsters()
	if monsters.size() == 0:
		print("[RoomSpawner] No monster data available")
		return 0

	print("[RoomSpawner] Spawning ", content.monster_count, " monsters")

	for i in range(content.monster_count):
		var monster_data = _get_monster_by_config(monsters, content.monster_types, content.monster_level)
		if monster_data:
			var spawn_pos = WorldCoordinate.monster_spawn_pos(room_center)
			var entity = _spawn_single_monster(monster_data, spawn_pos)
			if entity:
				# 应用等级修正
				if content.monster_level > 1:
					_apply_level_modifier(entity, content.monster_level)
				_current_monsters.append(entity)

	print("[RoomSpawner] Spawned ", _current_monsters.size(), " monsters")
	return _current_monsters.size()


## 生成单个怪物
func _spawn_single_monster(monster_data: MonsterData, pos: Vector2) -> MonsterEntity:
	if not _monster_container:
		print("[RoomSpawner] Error: No monster container")
		return null

	# 加载怪物场景
	var monster_scene = load("res://scenes/enemy/monster.tscn")
	if not monster_scene:
		print("[RoomSpawner] Error: Failed to load monster scene")
		return null

	# 实例化
	var monster_node = monster_scene.instantiate()
	if not monster_node:
		return null

	# 创建实体
	var entity = MonsterEntity.new()
	entity.set_monster_data(monster_data)
	entity.set_position(pos)

	# 绑定节点
	entity.bind_monster_node(monster_node)

	# 添加到场景
	_monster_container.add_child(monster_node)
	monster_node.position = pos

	# 设置节点的实体引用
	if monster_node.has_method("set_monster_entity"):
		monster_node.set_monster_entity(entity)

	# 激活实体
	entity.activate()

	monster_spawned.emit(entity)
	return entity


## 根据配置获取怪物数据
func _get_monster_by_config(monsters: Array[MonsterData], types: Array[String], level: int) -> MonsterData:
	if monsters.size() == 0:
		return null

	# 如果指定了类型, 优先选择
	if types.size() > 0:
		var target_type = types[randi() % types.size()]
		for monster in monsters:
			if monster.type == target_type or monster.name == target_type:
				return monster

	# 否则随机选择
	return monsters[randi() % monsters.size()]


## 应用等级修正
func _apply_level_modifier(entity: MonsterEntity, level: int) -> void:
	if level <= 1:
		return
	var multiplier = 1.0 + (level - 1) * 0.3
	entity.health = int(entity.health * multiplier)
	entity.max_health = int(entity.max_health * multiplier)
	entity.attack = int(entity.attack * multiplier)
	entity.defense = int(entity.defense * multiplier)


## ==================== 怪物死亡 ====================

## 怪物死亡时调用(由MonsterNode调用)
func on_monster_died(entity: MonsterEntity) -> void:
	if entity in _current_monsters:
		_current_monsters.erase(entity)
		monster_died.emit(entity)

		if _current_monsters.size() == 0:
			all_monsters_dead.emit()
			print("[RoomSpawner] All monsters dead!")


## 清除所有怪物
func clear_monsters() -> void:
	for entity in _current_monsters:
		var node = entity.get_monster_node()
		if node and node.is_inside_tree():
			node.queue_free()
	_current_monsters.clear()


## 生成Boss
## boss_data: Boss配置数据
## room_center: 房间中心的世界坐标
## 返回: Boss的MonsterEntity，如果失败返回null
func spawn_boss(boss_data: BossData, room_center: Vector2) -> MonsterEntity:
	if not boss_data:
		print("[RoomSpawner] Error: No boss data")
		return null

	print("[BOSS SPAWN] Starting boss spawn: ", boss_data.name)

	# 清除旧怪物
	clear_monsters()

	# 加载怪物场景
	var monster_scene = load("res://scenes/enemy/monster.tscn")
	if not monster_scene:
		print("[RoomSpawner] Error: Failed to load monster scene")
		return null

	# 实例化
	var monster_node = monster_scene.instantiate()
	if not monster_node:
		return null

	# 创建MonsterData从BossData
	var monster_data = MonsterData.new()
	monster_data.id = 9999
	monster_data.name = boss_data.name
	monster_data.type = "boss"
	monster_data.health = boss_data.max_health
	monster_data.attack = boss_data.attack
	monster_data.defense = boss_data.defense
	monster_data.speed = int(boss_data.speed)
	monster_data.experience_reward = boss_data.reward_exp
	monster_data.gold_reward = boss_data.reward_gold

	# 创建实体
	var entity = MonsterEntity.new()
	entity.set_monster_data(monster_data)
	entity.set_position(room_center)

	# 绑定节点
	entity.bind_monster_node(monster_node)

	# 添加到场景
	_monster_container.add_child(monster_node)
	monster_node.position = room_center

	# 设置节点的实体引用
	if monster_node.has_method("set_monster_entity"):
		monster_node.set_monster_entity(entity)

	# 创建BossController
	var boss_controller = _create_boss_controller(monster_node, entity, boss_data)
	if boss_controller:
		print("[BOSS CONTROLLER CREATED] BossController created for: ", boss_data.name)
	else:
		print("[RoomSpawner] Warning: Failed to create BossController")

	# 激活实体
	entity.activate()

	# Boss不需要等级修正，已经是最终属性
	_current_monsters.append(entity)

	print("[BOSS SPAWN] Boss spawned successfully: ", boss_data.name)
	monster_spawned.emit(entity)
	return entity


## 创建BossController
func _create_boss_controller(boss_node: CharacterBody2D, boss_entity: MonsterEntity, boss_data: BossData) -> Node:
	# 加载BossController脚本
	var boss_controller_script = load("res://scripts/boss/boss_controller.gd")
	if not boss_controller_script:
		print("[RoomSpawner] Error: Failed to load BossController script")
		return null

	# 创建BossController实例
	var boss_controller = boss_controller_script.new()
	if not boss_controller:
		print("[RoomSpawner] Error: Failed to create BossController instance")
		return null

	# 设置名称
	boss_controller.name = "BossController"

	# 添加到怪物容器（与MonsterNode同级）
	_monster_container.add_child(boss_controller)

	# 初始化BossController
	boss_controller.initialize(boss_node, boss_entity, boss_data)

	# 连接boss_defeated信号到CombatManager
	_connect_boss_signals(boss_controller)

	return boss_controller


## 连接Boss信号到CombatManager
func _connect_boss_signals(boss_controller: Node) -> void:
	# 获取CombatManager引用
	var combat_manager = _find_combat_manager()
	if not combat_manager:
		print("[RoomSpawner] Warning: CombatManager not found, signals not connected")
		return

	# 连接boss_defeated信号到CombatManager.on_boss_defeated()
	if boss_controller.has_signal("boss_defeated") and combat_manager.has_method("on_boss_defeated"):
		boss_controller.boss_defeated.connect(combat_manager.on_boss_defeated)
		print("[BOSS SIGNAL CONNECTED] boss_defeated -> CombatManager.on_boss_defeated")
	else:
		print("[RoomSpawner] Warning: Failed to connect boss_defeated signal")


## 查找CombatManager
func _find_combat_manager() -> Node:
	var root = Engine.get_main_loop().root
	if root:
		var game_scene = root.get_node_or_null("GameScene")
		if game_scene:
			return game_scene.get_node_or_null("CombatManager")
	return null


## ==================== 奖励生成 ====================

## 根据房间内容生成奖励
## room_center: 房间中心的世界坐标
func spawn_rewards(content: RoomContentData, room_center: Vector2) -> void:
	if not _reward_container:
		print("[RoomSpawner] Error: No reward container")
		return

	# 清除旧奖励
	clear_rewards()

	var reward_count = 3  # 默认
	if content:
		reward_count = content.reward_count

	print("[RoomSpawner] Spawning ", reward_count, " rewards")

	for i in range(reward_count):
		var reward_data: RewardData
		if content and content.has_reward_strategy():
			reward_data = _generate_reward_from_strategy(content, i)
		else:
			reward_data = RewardData.generate_random_reward(i)

		var spawn_pos = WorldCoordinate.reward_spawn_pos(room_center)
		_spawn_single_reward(reward_data, spawn_pos)


## 根据策略生成奖励
func _generate_reward_from_strategy(content: RoomContentData, index: int) -> RewardData:
	if content.reward_items.size() > index:
		var config = content.reward_items[index]
		return _reward_from_config(config, content.reward_quality)

	# 默认随机
	var reward = RewardData.generate_random_reward(index)
	reward.value = int(reward.value * content.reward_quality)
	return reward


func _reward_from_config(config: Dictionary, quality: float) -> RewardData:
	var reward_type = config.get("type", "gold")
	var value = config.get("value", 0)
	var reward = RewardData.new()

	match reward_type:
		"gold":
			reward.type = RewardData.RewardType.GOLD
			reward.value = int((value if value > 0 else randi_range(10, 50)) * quality)
		"attack_up":
			reward.type = RewardData.RewardType.ATTACK_UP
			reward.value = int((value if value > 0 else randi_range(1, 5)) * quality)
		"health_up":
			reward.type = RewardData.RewardType.HEALTH_UP
			reward.value = int((value if value > 0 else randi_range(5, 20)) * quality)
		"heal":
			reward.type = RewardData.RewardType.HEAL
			reward.value = int((value if value > 0 else randi_range(10, 30)) * quality)
		_:
			reward.type = RewardData.RewardType.GOLD
			reward.value = int(20 * quality)

	reward._setup_defaults()
	return reward


## 生成单个奖励
func _spawn_single_reward(reward_data: RewardData, pos: Vector2) -> void:
	var reward_scene = load("res://scenes/drop/reward_item.tscn")
	if not reward_scene:
		print("[RoomSpawner] Error: Failed to load reward scene")
		return

	var reward_node = reward_scene.instantiate()
	if not reward_node:
		return

	if reward_node.has_method("set_reward_data"):
		reward_node.set_reward_data(reward_data)

	reward_node.position = pos

	if _reward_container:
		_reward_container.add_child(reward_node)

	_current_rewards.append(reward_node)

	if reward_node.has_signal("reward_collected"):
		reward_node.reward_collected.connect(_on_reward_collected)

	reward_spawned.emit(reward_data)


func _on_reward_collected(data: RewardData) -> void:
	reward_collected.emit(data)

	# 从当前奖励列表中移除已收集的奖励
	# 遍历查找并移除（reward_item在收集后会被销毁）
	for i in range(_current_rewards.size() - 1, -1, -1):
		var reward = _current_rewards[i]
		if not reward or not is_instance_valid(reward) or reward.is_queued_for_deletion():
			_current_rewards.remove_at(i)

	if _current_rewards.size() == 0:
		all_rewards_collected.emit()
		print("[RoomSpawner] All rewards collected!")


## 移除奖励(由RewardItem调用)
func remove_reward(reward_node: Node) -> void:
	if reward_node in _current_rewards:
		_current_rewards.erase(reward_node)
	if _current_rewards.size() == 0:
		all_rewards_collected.emit()


## 清除所有奖励
func clear_rewards() -> void:
	for reward in _current_rewards:
		if reward and reward.is_inside_tree():
			reward.queue_free()
	_current_rewards.clear()


## ==================== 查询 ====================

func get_monster_count() -> int:
	return _current_monsters.size()


func get_reward_count() -> int:
	return _current_rewards.size()


func is_all_dead() -> bool:
	return _current_monsters.size() == 0
