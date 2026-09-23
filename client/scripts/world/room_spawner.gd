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

## 怪物容器（当前房间的，由RoomRenderer提供）
var _monster_container: Node2D = null

## 奖励容器（当前房间的，由RoomRenderer提供）
var _reward_container: Node2D = null

## 玩家引用
var _player: CharacterBody2D = null

## Phase 26: 当前房间中心（用于坐标转换）
var _current_room_center: Vector2 = Vector2.ZERO

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


## Phase 26: 设置当前房间中心（用于local/global坐标转换）
func set_room_center(center: Vector2) -> void:
	_current_room_center = center
	print("[RoomSpawner] Room center set to: ", center)


## Phase 26: 获取 RoomRenderer 引用（通过 GameScene→FloorManager 查找链）
func _get_room_renderer() -> Node:
	var root = Engine.get_main_loop().root
	if root:
		var game_scene = root.get_node_or_null("GameScene")
		if game_scene:
			var floor_manager = game_scene.get_node_or_null("FloorManager")
			if floor_manager:
				return floor_manager.get_room_renderer()
	return null


## Phase 26: 获取当前房间的怪物容器（从RoomRenderer获取）
func _get_monster_container() -> Node2D:
	var room_renderer = _get_room_renderer()
	if room_renderer and room_renderer.has_method("get_monster_container"):
		return room_renderer.get_monster_container()
	return null


## Phase 26: 获取当前房间的奖励容器（从RoomRenderer获取）
func _get_reward_container() -> Node2D:
	var room_renderer = _get_room_renderer()
	if room_renderer and room_renderer.has_method("get_reward_container"):
		return room_renderer.get_reward_container()
	return null


## TASK-002: 获取当前房间平台矩形列表（用于奖励生成避让）
func _get_platform_rects() -> Array[Rect2]:
	var room_renderer = _get_room_renderer()
	if room_renderer and room_renderer.has_method("get_platform_rects"):
		return room_renderer.get_platform_rects()
	return []


## ==================== 怪物生成 ====================

## 根据房间内容生成怪物
## room_center: 房间中心的世界坐标
func spawn_monsters(content: RoomContentData, room_center: Vector2) -> int:
	if not content or content.monster_count <= 0:
		return 0

	# Phase 26: 获取房间级容器
	_monster_container = _get_monster_container()
	if not _monster_container:
		print("[RoomSpawner] Error: No monster container for room")
		return 0

	# 清除旧怪物
	clear_monsters()

	# Phase 26: 保存房间中心用于local坐标转换
	_current_room_center = room_center

	var monsters = ResourceService.get_monsters()
	if monsters.size() == 0:
		print("[RoomSpawner] No monster data available")
		return 0

	print("[RoomSpawner] Spawning ", content.monster_count, " monsters")

	# Phase 17.5: 传递index和total参数，避免怪物重叠
	for i in range(content.monster_count):
		var monster_data = _get_monster_by_config(monsters, content.monster_types, content.monster_level)
		if monster_data:
			# Phase 26: 转换为房间内local坐标
			var world_pos = WorldCoordinate.monster_spawn_pos(room_center, i, content.monster_count)
			var local_pos = world_pos - room_center
			var entity = _spawn_single_monster(monster_data, local_pos)
			if entity:
				# MONSTER_BALANCE_ENABLED=true: 服务端已处理楼层缩放
				# 不需要客户端二次倍率修正，避免双重放大
				_current_monsters.append(entity)

	print("[RoomSpawner] Spawned ", _current_monsters.size(), " monsters")
	return _current_monsters.size()


## 生成单个怪物
func _spawn_single_monster(monster_data: MonsterData, pos: Vector2) -> MonsterEntity:
	# Phase 26: pos现在是local坐标（相对于房间中心）
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

	# Phase 26: 添加到房间级容器，使用local坐标
	_monster_container.add_child(monster_node)
	monster_node.position = pos  # local坐标

	# Phase 17.4: 调试日志 - 确认怪物生成
	print("[MonsterSpawn] name=", monster_data.name, " local_position=", pos, " global_position=", monster_node.global_position, " parent=", monster_node.get_parent().name if monster_node.get_parent() else "none")

	# 设置节点的实体引用
	if monster_node.has_method("set_monster_entity"):
		monster_node.set_monster_entity(entity)

	# 激活实体
	entity.activate()

	monster_spawned.emit(entity)
	return entity


## 怪物属性是否由服务端 MonsterBalanceConfig 统一管理
## 为 true 时禁用客户端二次倍率修正
const MONSTER_BALANCE_ENABLED: bool = true


## 根据配置获取怪物数据
## Phase 23: 强制钳制怪物HP，防止AI生成异常高HP值
func _get_monster_by_config(monsters: Array[MonsterData], types: Array[String], level: int) -> MonsterData:
	if monsters.size() == 0:
		return null

	# 如果指定了类型, 优先选择
	if types.size() > 0:
		var target_type = types[randi() % types.size()]
		for monster in monsters:
			if monster.type == target_type or monster.name == target_type:
				# Phase 23: 钳制HP到合理范围
				_apply_monster_clamp(monster, level)
				return monster

	# 否则随机选择
	var idx = randi() % monsters.size()
	_apply_monster_clamp(monsters[idx], level)
	return monsters[idx]


## Phase 23: 钳制怪物属性到合理范围
## 使用 MonsterBalanceConfig 统一管理数值范围
func _apply_monster_clamp(monster: MonsterData, level: int) -> void:
	if not monster:
		return
	# 根据怪物类型确定基础范围（从name/type推断）
	var monster_type: String = "normal"
	if monster.type == "elite" or monster.name.to_lower().contains("elite"):
		monster_type = "elite"
	elif monster.type == "boss" or monster.name.to_lower().contains("boss"):
		monster_type = "boss"

	var stats = MonsterBalanceConfig.generate_monster_stats(monster_type, level)
	monster.health = stats["health"]
	monster.attack = stats["attack"]
	monster.defense = stats["defense"]


## 应用等级修正（已废弃：由 MONSTER_BALANCE_CONFIG 统一在服务器端管理）
## 保留此方法供调试和降级场景使用
func _apply_level_modifier(entity: MonsterEntity, level: int) -> void:
	if not MONSTER_BALANCE_ENABLED or level <= 1:
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

	# Phase 26: 获取房间级容器
	_monster_container = _get_monster_container()
	if not _monster_container:
		print("[RoomSpawner] Error: No monster container for boss room")
		return null

	print("[BOSS SPAWN] Starting boss spawn: ", boss_data.name)

	# 清除旧怪物
	clear_monsters()

	# Phase 26: 保存房间中心用于local坐标转换
	_current_room_center = room_center

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

	# Phase 26: Boss在房间中心，local坐标为(0, 0)
	var boss_local_pos = Vector2.ZERO
	entity.set_position(boss_local_pos)

	# 绑定节点
	entity.bind_monster_node(monster_node)

	# Phase 26: 添加到房间级容器，使用local坐标
	_monster_container.add_child(monster_node)
	monster_node.position = boss_local_pos

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
	# Phase 26: 获取房间级容器
	_reward_container = _get_reward_container()
	if not _reward_container:
		print("[RoomSpawner] Error: No reward container for room")
		return

	# 清除旧奖励
	clear_rewards()

	# Phase 26: 保存房间中心用于local坐标转换
	_current_room_center = room_center

	var reward_count = 3  # 默认
	if content:
		reward_count = maxi(1, content.reward_count)  # TASK-001: 至少生成1个，避免空奖励房无法触发完成信号

	print("[RoomSpawner] Spawning ", reward_count, " rewards")

	for i in range(reward_count):
		var reward_data: RewardData
		if content and content.has_reward_strategy():
			reward_data = _generate_reward_from_strategy(content, i)
		else:
			reward_data = RewardData.generate_random_reward(i)

		# TASK-002: 平台感知采样（避开平台碰撞体，保证玩家可拾取）
		var platform_rects := _get_platform_rects()
		var world_pos = WorldCoordinate.reward_spawn_pos(room_center, platform_rects, i, reward_count)
		var local_pos = world_pos - room_center
		spawn_reward(reward_data, local_pos)


## TASK-001: 生成单个奖励（公开接口，供奖励房/宝箱房/战斗房/未来AI奖励调用）
## local_pos: 房间内local坐标（相对于房间中心）
func spawn_reward(reward_data: RewardData, local_pos: Vector2) -> void:
	_reward_container = _get_reward_container()
	if not _reward_container:
		print("[RoomSpawner] Error: No reward container, cannot spawn reward")
		return
	_spawn_single_reward(reward_data, local_pos)


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
## TASK-001 修复要点:
## - 旧代码 add_child 后才赋值 position，_ready 捕获到 (0,0)，
##   浮动动画每帧把奖励拉回房间中心高度 → 不可见不可拾取
## - 现在改为"先定位后入树"：set_spawn_position 在 add_child 之前设置出生点
## - set_spawn_position 同时校准动画起点，任何调用顺序都安全
func _spawn_single_reward(reward_data: RewardData, pos: Vector2) -> void:
	# Phase 26: pos是local坐标（相对于房间中心）
	var reward_scene = load("res://scenes/drop/reward_item.tscn")
	if not reward_scene:
		print("[RoomSpawner] Error: Failed to load reward scene")
		return

	var reward_node = reward_scene.instantiate()
	if not reward_node:
		return

	if not _reward_container:
		print("[RoomSpawner] Error: No reward container, reward discarded")
		reward_node.free()
		return

	# TASK-001: 先设置数据与出生点，再入树（_ready 中捕获的动画起点即为正确位置）
	if reward_node.has_method("set_reward_data"):
		reward_node.set_reward_data(reward_data)
	if reward_node.has_method("set_spawn_position"):
		reward_node.set_spawn_position(pos)

	# Phase 26: 添加到房间级容器（local坐标系）
	_reward_container.add_child(reward_node)

	_current_rewards.append(reward_node)

	# TASK-001: 绑定节点引用，收集时精确移除对应节点（修复收集后列表不清空 → 出口永不出现）
	if reward_node.has_signal("reward_collected"):
		reward_node.reward_collected.connect(_on_reward_collected.bind(reward_node))

	reward_spawned.emit(reward_data)


## 奖励收集回调
## TASK-001: 携带被收集的节点引用（由 bind 注入），立即精确移除，
## 避免依赖 queue_free 时序导致 all_rewards_collected 永不触发
func _on_reward_collected(data: RewardData, reward_node: Node = null) -> void:
	reward_collected.emit(data)

	# 精确移除被收集的奖励节点
	if reward_node and reward_node in _current_rewards:
		_current_rewards.erase(reward_node)

	# 兜底清理：移除已失效的节点引用
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
