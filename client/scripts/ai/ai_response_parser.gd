## AI响应解析器
##
## 负责解析AI返回的JSON数据
## 转换为游戏可用的数据结构

extends Node


## 解析楼层数据
func parse_floor_data(data: Dictionary) -> Array[NewRoomData]:
	print("[AIParser] Parsing floor data")

	var rooms: Array[NewRoomData] = []

	# 获取房间数组
	var rooms_array = data.get("rooms", [])

	for room_dict in rooms_array:
		if room_dict is Dictionary:
			var room_node = _parse_room_node(room_dict)
			if room_node:
				rooms.append(room_node)

	print("[AIParser] Parsed ", rooms.size(), " rooms")
	return rooms


## 解析房间节点
func _parse_room_node(data: Dictionary) -> NewRoomData:
	var room_id = data.get("id", -1)
	if room_id < 0:
		print("[AIParser] Warning: Invalid room id")
		return null

	# 解析房间类型
	var type_str = data.get("type", "combat")
	var room_type = _parse_room_type(type_str)

	# 创建房间节点
	var room_node = NewRoomData.new(room_id, room_type)

	# 解析连接
	var connections = data.get("connections", [])
	for conn in connections:
		if conn is int:
			room_node.add_connection(conn)

	# 计算位置（根据ID）
	room_node.position = Vector2(room_id * 200, randf_range(-50, 50))

	return room_node


## 解析房间类型
func _parse_room_type(type_str: String) -> NewRoomData.RoomType:
	match type_str:
		"start":
			return NewRoomData.RoomType.START
		"combat":
			return NewRoomData.RoomType.COMBAT
		"reward":
			return NewRoomData.RoomType.REWARD
		"shop":
			return NewRoomData.RoomType.SHOP
		"elite":
			return NewRoomData.RoomType.ELITE
		"boss":
			return NewRoomData.RoomType.BOSS
		"event":
			return NewRoomData.RoomType.EVENT
		"treasure":
			return NewRoomData.RoomType.TREASURE
		_:
			print("[AIParser] Warning: Unknown room type: ", type_str)
			return NewRoomData.RoomType.COMBAT


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
		content.reward_items = rewards.get("items", [])
	else:
		content.reward_count = 3
		content.reward_quality = 1.0
		content.reward_strategy = ""
		content.reward_items = []


## 验证AI响应数据
func validate_floor_response(data: Dictionary) -> bool:
	# 检查必要字段
	if not data.has("floor"):
		print("[AIParser] Validation failed: missing 'floor'")
		return false

	if not data.has("rooms"):
		print("[AIParser] Validation failed: missing 'rooms'")
		return false

	var rooms = data.get("rooms", [])
	if not rooms is Array:
		print("[AIParser] Validation failed: 'rooms' is not array")
		return false

	# 检查每个房间
	for room in rooms:
		if not room is Dictionary:
			print("[AIParser] Validation failed: room is not dictionary")
			return false

		if not room.has("id"):
			print("[AIParser] Validation failed: room missing 'id'")
			return false

		if not room.has("type"):
			print("[AIParser] Validation failed: room missing 'type'")
			return false

	print("[AIParser] Validation passed")
	return true


## 验证房间内容响应
func validate_room_content_response(data: Dictionary) -> bool:
	# 检查必要字段
	if not data.has("room_id"):
		print("[AIParser] Validation failed: missing 'room_id'")
		return false

	if not data.has("room_type"):
		print("[AIParser] Validation failed: missing 'room_type'")
		return false

	print("[AIParser] Validation passed")
	return true
