## AI响应解析器
##
## 负责解析AI返回的JSON数据
## 转换为游戏可用的数据结构
## TASK-030: 删除楼层拓扑解析（parse_floor_data/_parse_room_node/_parse_room_type）
## AI 不再生成地图结构（FloorGenerator + Validation 负责）

extends Node


## 解析房间内容数据
func parse_room_content(data: Dictionary) -> RoomContentData:
	print("[AIParser] Parsing room content")

	var content = RoomContentData.new()

	# 基础属性
	content.room_id = data.get("room_id", 0)
	content.room_type = data.get("room_type", "combat")
	content.difficulty = data.get("difficulty", 1)

	# 解析怪物配置
	var monsters = data.get("monsters", [])
	_parse_monster_config(content, monsters)

	# 解析奖励配置
	var rewards = data.get("rewards", {})
	_parse_reward_config(content, rewards)

	# 解析宝箱配置
	content.chest_count = data.get("chests", 0)

	print("[AIParser] Parsed room content: monsters=", content.monster_count, " rewards=", content.reward_count)
	return content


## 解析怪物配置
func _parse_monster_config(content: RoomContentData, monsters: Array) -> void:
	var total_count = 0
	var monster_types: Array[String] = []

	for monster_dict in monsters:
		if monster_dict is Dictionary:
			var monster_id = monster_dict.get("id", "")
			var count = monster_dict.get("count", 0)
			var level = monster_dict.get("level", 1)

			total_count += count
			if monster_id not in monster_types:
				monster_types.append(monster_id)

			# 更新怪物等级（取最高等级）
			if level > content.monster_level:
				content.monster_level = level

			# Phase 23: 钳制怪物属性到合理范围，防止 AI 生成异常值
			_clamp_monster_attributes(monster_dict, level)

	content.monster_count = total_count
	content.set_monster_types(monster_types)


## Phase 23: 钳制单个怪物字典的属性到合理范围
## 使用 MonsterBalanceConfig 统一管理
func _clamp_monster_attributes(monster: Dictionary, floor_level: int) -> void:
	# 推断怪物类型
	var monster_type: String = "normal"
	var name = monster.get("id", "").to_lower()
	if "elite" in name:
		monster_type = "elite"
	elif "boss" in name:
		monster_type = "boss"

	var stats = MonsterBalanceConfig.clamp_stats(monster, monster_type, floor_level)
	monster["health"] = stats["health"]
	monster["attack"] = stats["attack"]
	monster["defense"] = stats["defense"]
	# Count钳制
	monster["count"] = clampi(monster.get("count", 1), 1, 10)


## 解析奖励配置
func _parse_reward_config(content: RoomContentData, rewards: Dictionary) -> void:
	if rewards is Dictionary:
		content.reward_count = rewards.get("count", 3)
		content.reward_quality = rewards.get("quality", 1.0)
		content.reward_strategy = rewards.get("strategy", "")
		# TASK-022: 未类型化 Array 不能直接赋给 Array[Dictionary] 成员，逐项验证类型
		var raw_items = rewards.get("items", [])
		if raw_items is Array:
			for item in raw_items:
				if item is Dictionary:
					content.reward_items.append(item)
	else:
		content.reward_count = 3
		content.reward_quality = 1.0
		content.reward_strategy = ""
		content.reward_items = []


## TASK-030: validate_floor_response / validate_room_content_response 零调用点，已删除
## 响应验证统一由 AIValidator（ai_validator.gd）负责
