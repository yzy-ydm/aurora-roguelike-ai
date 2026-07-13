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

	# 生成奖励
	for i in range(reward_count):
		# 生成随机奖励，考虑品质倍率
		var reward_data = _generate_quality_reward(i, reward_quality)

		# 计算生成位置（在房间内随机）
		var spawn_pos = room_position + Vector2(
			randf_range(-100, 100),
			randf_range(-100, 100)
		)

		# 生成奖励物品
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
