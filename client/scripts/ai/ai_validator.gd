## AI数据验证器
##
## 验证AI返回的数据
## 自动修正非法数据
## 确保数据安全可靠

extends Node

## 验证限制常量
const MAX_ROOMS: int = 20
const MAX_MONSTERS_PER_ROOM: int = 20
const MAX_REWARDS_PER_ROOM: int = 10
const MAX_DIFFICULTY: int = 10
const MIN_DIFFICULTY: int = 1
const MAX_MONSTER_LEVEL: int = 10
const MAX_REWARD_QUALITY: float = 5.0

## 信号
signal data_validated(data_type: String, is_valid: bool)
signal data_corrected(data_type: String, corrections: Array[String])


## 验证楼层数据
func validate_floor_data(data: Dictionary) -> Dictionary:
	print("[Validator] Validating floor data")

	var corrections: Array[String] = []
	var is_valid = true

	# 验证房间数量
	if data.has("rooms"):
		var rooms = data.get("rooms", [])
		if rooms is Array:
			if rooms.size() > MAX_ROOMS:
				data.rooms = rooms.slice(0, MAX_ROOMS)
				corrections.append("Room count limited to " + str(MAX_ROOMS))
				is_valid = false

			# 验证每个房间
			for i in range(data.rooms.size()):
				data.rooms[i] = _validate_room_node(data.rooms[i], corrections)

	# 验证楼层级别
	if data.has("floor"):
		var floor = data.get("floor", 1)
		if floor < 1:
			data.floor = 1
			corrections.append("Floor level set to 1")

	# 验证玩家等级
	if data.has("player_level"):
		var level = data.get("player_level", 1)
		if level < 1:
			data.player_level = 1
			corrections.append("Player level set to 1")

	# 验证房间连接
	_validate_room_connections(data.get("rooms", []), corrections)

	# 发送信号
	if corrections.size() > 0:
		data_corrected.emit("floor", corrections)
		print("[Validator] Floor data corrected: ", corrections)

	data_validated.emit("floor", is_valid)
	return data


## 验证房间节点
func _validate_room_node(room: Dictionary, corrections: Array[String]) -> Dictionary:
	# 验证房间ID
	if not room.has("id"):
		room.id = 0
		corrections.append("Room ID set to 0")

	# 验证房间类型
	if not room.has("type"):
		room.type = "combat"
		corrections.append("Room type set to combat")

	# 验证怪物配置
	if room.has("monsters"):
		room.monsters = _validate_monsters(room.monsters, corrections)

	# 验证奖励配置
	if room.has("rewards"):
		room.rewards = _validate_rewards(room.rewards, corrections)

	# 验证宝箱数量
	if room.has("chests"):
		var chests = room.get("chests", 0)
		if chests < 0:
			room.chests = 0
			corrections.append("Chest count set to 0")
		elif chests > 5:
			room.chests = 5
			corrections.append("Chest count limited to 5")

	return room


## 验证怪物配置
func _validate_monsters(monsters: Variant, corrections: Array[String]) -> Array:
	if not monsters is Array:
		corrections.append("Monsters data is not array, reset to empty")
		return []

	var validated = []
	var total_count = 0

	for monster in monsters:
		if not monster is Dictionary:
			continue

		# 验证怪物ID
		if not monster.has("id"):
			continue

		# 验证怪物数量
		var count = monster.get("count", 1)
		if count < 1:
			count = 1
			corrections.append("Monster count set to 1")
		elif count > MAX_MONSTERS_PER_ROOM:
			count = MAX_MONSTERS_PER_ROOM
			corrections.append("Monster count limited to " + str(MAX_MONSTERS_PER_ROOM))

		total_count += count

		# 验证怪物等级
		if monster.has("level"):
			var level = monster.get("level", 1)
			if level < 1:
				monster.level = 1
			elif level > MAX_MONSTER_LEVEL:
				monster.level = MAX_MONSTER_LEVEL
				corrections.append("Monster level limited to " + str(MAX_MONSTER_LEVEL))

		monster.count = count
		validated.append(monster)

	# 限制总怪物数量
	if total_count > MAX_MONSTERS_PER_ROOM:
		corrections.append("Total monsters limited to " + str(MAX_MONSTERS_PER_ROOM))

	return validated


## 验证奖励配置
func _validate_rewards(rewards: Variant, corrections: Array[String]) -> Dictionary:
	if not rewards is Dictionary:
		corrections.append("Rewards data is not dictionary, reset to default")
		return {"count": 3, "quality": 1.0}

	# 验证奖励数量
	var count = rewards.get("count", 3)
	if count < 0:
		count = 0
		corrections.append("Reward count set to 0")
	elif count > MAX_REWARDS_PER_ROOM:
		count = MAX_REWARDS_PER_ROOM
		corrections.append("Reward count limited to " + str(MAX_REWARDS_PER_ROOM))

	# 验证奖励品质
	var quality = rewards.get("quality", 1.0)
	if quality < 0.1:
		quality = 0.1
		corrections.append("Reward quality set to 0.1")
	elif quality > MAX_REWARD_QUALITY:
		quality = MAX_REWARD_QUALITY
		corrections.append("Reward quality limited to " + str(MAX_REWARD_QUALITY))

	rewards.count = count
	rewards.quality = quality

	return rewards


## 验证房间连接
func _validate_room_connections(rooms: Array, corrections: Array[String]) -> void:
	if rooms.size() == 0:
		return

	# 检查每个房间的连接
	for room in rooms:
		if not room is Dictionary:
			continue

		var connections = room.get("connections", [])
		if not connections is Array:
			room.connections = []
			corrections.append("Room connections reset to empty")
			continue

		# 验证连接的房间ID是否存在
		var valid_connections = []
		for conn in connections:
			if conn is int and conn >= 0 and conn < rooms.size():
				valid_connections.append(conn)

		room.connections = valid_connections


## 验证房间内容数据
func validate_room_content(data: Dictionary) -> Dictionary:
	print("[Validator] Validating room content data")

	var corrections: Array[String] = []
	var is_valid = true

	# 验证房间ID
	if not data.has("room_id"):
		data.room_id = 0
		corrections.append("Room ID set to 0")

	# 验证房间类型
	if not data.has("room_type"):
		data.room_type = "combat"
		corrections.append("Room type set to combat")

	# 验证难度
	if data.has("difficulty"):
		var difficulty = data.get("difficulty", 1)
		if difficulty < MIN_DIFFICULTY:
			data.difficulty = MIN_DIFFICULTY
			corrections.append("Difficulty set to " + str(MIN_DIFFICULTY))
		elif difficulty > MAX_DIFFICULTY:
			data.difficulty = MAX_DIFFICULTY
			corrections.append("Difficulty limited to " + str(MAX_DIFFICULTY))

	# 验证怪物配置
	if data.has("monsters"):
		data.monsters = _validate_monsters(data.monsters, corrections)

	# 验证奖励配置
	if data.has("rewards"):
		data.rewards = _validate_rewards(data.rewards, corrections)

	# 验证宝箱数量
	if data.has("chests"):
		var chests = data.get("chests", 0)
		if chests < 0:
			data.chests = 0
		elif chests > 5:
			data.chests = 5
			corrections.append("Chest count limited to 5")

	# 发送信号
	if corrections.size() > 0:
		data_corrected.emit("room_content", corrections)
		print("[Validator] Room content corrected: ", corrections)

	data_validated.emit("room_content", is_valid)
	return data


## 获取验证统计
func get_validation_stats() -> Dictionary:
	return {
		"max_rooms": MAX_ROOMS,
		"max_monsters_per_room": MAX_MONSTERS_PER_ROOM,
		"max_rewards_per_room": MAX_REWARDS_PER_ROOM,
		"max_difficulty": MAX_DIFFICULTY,
		"max_monster_level": MAX_MONSTER_LEVEL,
		"max_reward_quality": MAX_REWARD_QUALITY
	}
