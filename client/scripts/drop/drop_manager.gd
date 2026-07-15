## 掉落管理器
##
## 负责监听房间清除信号
## 生成奖励物品
## 管理奖励物品生命周期

extends Node

## 奖励物品场景路径
const REWARD_ITEM_SCENE = "res://scenes/drop/reward_item.tscn"

## 奖励容器节点
var _reward_container: Node2D = null

## 当前房间的奖励物品
var _current_rewards: Array[Node] = []

## 玩家引用
var _player: CharacterBody2D = null

## 信号
signal reward_spawned(reward_data: RewardData)
signal reward_collected(reward_data: RewardData)
signal all_rewards_collected()


## 初始化
func _ready() -> void:
	print("[DropManager] Initialized")


## 设置奖励容器的父节点
func setup_container(parent: Node) -> void:
	_reward_container = Node2D.new()
	_reward_container.name = "RewardContainer"
	parent.add_child(_reward_container)
	print("[DropManager] RewardContainer added to: ", parent.name)


## 设置玩家引用
func set_player(player: CharacterBody2D) -> void:
	_player = player


## 房间清除时生成奖励
func spawn_rewards_for_room(room_position: Vector2, reward_count: int = 3) -> void:
	print("[DropManager] Spawning ", reward_count, " rewards")

	# 清除当前奖励
	clear_current_rewards()

	# 生成奖励
	for i in range(reward_count):
		# 生成随机奖励
		var reward_data = RewardData.generate_random_reward(i)

		# 计算生成位置（在房间内随机）
		var spawn_pos = room_position + Vector2(
			randf_range(-100, 100),
			randf_range(-100, 100)
		)

		# 生成奖励物品
		_spawn_reward_item(reward_data, spawn_pos)


## 生成单个奖励物品
func _spawn_reward_item(reward_data: RewardData, position: Vector2) -> void:
	# 加载场景
	var reward_scene = load(REWARD_ITEM_SCENE)
	if not reward_scene:
		print("[DropManager] Error: Failed to load reward scene")
		return

	# 实例化
	var reward_node = reward_scene.instantiate()
	if not reward_node:
		print("[DropManager] Error: Failed to instantiate reward")
		return

	# 设置奖励数据
	if reward_node.has_method("set_reward_data"):
		reward_node.set_reward_data(reward_data)

	# 设置位置
	reward_node.position = position

	# 添加到容器
	if _reward_container:
		_reward_container.add_child(reward_node)

	# 添加到列表
	_current_rewards.append(reward_node)

	# 连接信号
	if reward_node.has_signal("reward_collected"):
		reward_node.reward_collected.connect(_on_reward_collected)

	print("[DropManager] Spawned reward: ", reward_data.name, " at ", position)
	reward_spawned.emit(reward_data)


## 奖励被拾取时调用
func _on_reward_collected(reward_data: RewardData) -> void:
	print("[DropManager] Reward collected: ", reward_data.name)
	reward_collected.emit(reward_data)

	# 应用奖励到玩家
	if _player:
		reward_data.apply_to_player(_player)


## 清除当前奖励
func clear_current_rewards() -> void:
	for reward in _current_rewards:
		if reward and reward.is_inside_tree():
			reward.queue_free()
	_current_rewards.clear()


## 获取当前奖励数量
func get_reward_count() -> int:
	return _current_rewards.size()


## 检查是否所有奖励都已收集
func are_all_rewards_collected() -> bool:
	return _current_rewards.size() == 0


## 从奖励列表中移除
func remove_reward(reward_node: Node) -> void:
	if reward_node in _current_rewards:
		_current_rewards.erase(reward_node)

	# 检查是否所有奖励都已收集
	if _current_rewards.size() == 0:
		print("[DropManager] All rewards collected!")
		all_rewards_collected.emit()


## 根据RoomContentData生成奖励
func spawn_rewards_from_content(content: RoomContentData, room_position: Vector2) -> void:
	if not content:
		print("[DropManager] Error: content is null")
		return

	var reward_count = content.reward_count
	var reward_quality = content.reward_quality

	print("[DropManager] Spawning ", reward_count, " rewards (quality ", reward_quality, ")")

	# 清除当前奖励
	clear_current_rewards()

	# 检查是否有AI指定的奖励策略
	if content.has_reward_strategy():
		print("[DropManager] Using AI reward strategy: ", content.reward_strategy)
		_spawn_rewards_from_strategy(content, room_position)
	else:
		print("[DropManager] Using random rewards")
		_spawn_random_rewards(reward_count, reward_quality, room_position)


## 根据AI策略生成奖励
func _spawn_rewards_from_strategy(content: RoomContentData, room_position: Vector2) -> void:
	var reward_items = content.reward_items
	var reward_quality = content.reward_quality

	# 如果有指定的奖励物品，按照列表生成
	if reward_items.size() > 0:
		for i in range(reward_items.size()):
			var item_config = reward_items[i]
			var reward_data = _generate_reward_from_config(item_config, reward_quality)

			# 计算生成位置
			var spawn_pos = room_position + Vector2(
				randf_range(-100, 100),
				randf_range(-100, 100)
			)

			_spawn_reward_item(reward_data, spawn_pos)
	else:
		# 如果没有具体物品，根据策略生成随机奖励
		_spawn_rewards_by_strategy(content.reward_strategy, content.reward_count, reward_quality, room_position)


## 根据配置生成单个奖励
func _generate_reward_from_config(config: Dictionary, quality: float) -> RewardData:
	var reward_type = config.get("type", "gold")
	var rarity = config.get("rarity", "common")
	var value = config.get("value", 0)

	# 创建奖励数据
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
		"weapon":
			reward.type = RewardData.RewardType.WEAPON_UPGRADE
			reward.value = 1
			reward.name = "武器升级 (" + rarity + ")"
		"attribute_boost":
			reward.type = RewardData.RewardType.ATTRIBUTE_BOOST
			reward.stat_key = config.get("stat_key", "attack")
			reward.value = int((value if value > 0 else 5) * quality)
		"new_weapon":
			reward.type = RewardData.RewardType.NEW_WEAPON
			reward.weapon_id = config.get("weapon_id", 0)
		"passive_item":
			reward.type = RewardData.RewardType.PASSIVE_ITEM
			reward.passive_id = config.get("passive_id", "")
			reward.name = config.get("name", "被动物品")
			reward.description = config.get("description", "获得被动效果")
		_:
			reward.type = RewardData.RewardType.GOLD
			reward.value = int(20 * quality)

	# 设置奖励属性
	reward._setup_defaults()

	# 根据稀有度调整数值
	var rarity_multiplier = _get_rarity_multiplier(rarity)
	reward.value = int(reward.value * rarity_multiplier)

	return reward


## 根据策略生成随机奖励
func _spawn_rewards_by_strategy(strategy: String, count: int, quality: float, room_position: Vector2) -> void:
	for i in range(count):
		var reward_data: RewardData

		match strategy:
			"power_growth":
				# 力量成长策略：更多攻击奖励
				if randf() < 0.6:
					reward_data = _create_reward(RewardData.RewardType.ATTACK_UP, quality)
				else:
					reward_data = RewardData.generate_random_reward(i)
			"survival":
				# 生存策略：更多生命奖励
				if randf() < 0.6:
					reward_data = _create_reward(RewardData.RewardType.HEALTH_UP, quality)
				else:
					reward_data = RewardData.generate_random_reward(i)
			"balanced":
				# 平衡策略：均匀分布
				reward_data = RewardData.generate_random_reward(i)
			_:
				reward_data = RewardData.generate_random_reward(i)

		# 调整品质
		reward_data.value = int(reward_data.value * quality)

		# 计算生成位置
		var spawn_pos = room_position + Vector2(
			randf_range(-100, 100),
			randf_range(-100, 100)
		)

		_spawn_reward_item(reward_data, spawn_pos)


## 创建指定类型的奖励
func _create_reward(type: RewardData.RewardType, quality: float) -> RewardData:
	var reward = RewardData.new()
	reward.type = type

	match type:
		RewardData.RewardType.GOLD:
			reward.value = int(randi_range(20, 50) * quality)
		RewardData.RewardType.ATTACK_UP:
			reward.value = int(randi_range(2, 5) * quality)
		RewardData.RewardType.HEALTH_UP:
			reward.value = int(randi_range(10, 25) * quality)
		RewardData.RewardType.HEAL:
			reward.value = int(randi_range(15, 40) * quality)

	reward._setup_defaults()
	return reward


## 获取稀有度倍率
func _get_rarity_multiplier(rarity: String) -> float:
	match rarity:
		"common":
			return 1.0
		"uncommon":
			return 1.3
		"rare":
			return 1.6
		"epic":
			return 2.0
		"legendary":
			return 3.0
		_:
			return 1.0


## 生成随机奖励（保持兼容）
func _spawn_random_rewards(reward_count: int, reward_quality: float, room_position: Vector2) -> void:
	for i in range(reward_count):
		var reward_data = _generate_quality_reward(i, reward_quality)

		var spawn_pos = room_position + Vector2(
			randf_range(-100, 100),
			randf_range(-100, 100)
		)

		_spawn_reward_item(reward_data, spawn_pos)


## 生成品质奖励
func _generate_quality_reward(index: int, quality: float) -> RewardData:
	var reward = RewardData.generate_random_reward(index)

	# 根据品质倍率调整奖励数值
	reward.value = int(reward.value * quality)

	# 更新描述
	match reward.type:
		RewardData.RewardType.GOLD:
			reward.description = "获得 " + str(reward.value) + " 金币"
		RewardData.RewardType.ATTACK_UP:
			reward.description = "攻击力 +" + str(reward.value)
		RewardData.RewardType.HEALTH_UP:
			reward.description = "最大生命值 +" + str(reward.value)
		RewardData.RewardType.HEAL:
			reward.description = "恢复 " + str(reward.value) + " 生命值"

	return reward
