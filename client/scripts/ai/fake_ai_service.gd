## 模拟AI服务
##
## 模拟云端AI返回数据
## 用于本地测试和开发
## 未来将被真实AI API替换

extends Node

## 模拟延迟（秒）
var _simulated_delay: float = 0.5


## 生成楼层内容（模拟AI响应）
func generate_floor(floor_level: int, player_level: int = 1) -> Dictionary:
	print("[FakeAI] Generating floor ", floor_level, " for player level ", player_level)

	# 模拟AI处理延迟
	await get_tree().create_timer(_simulated_delay).timeout

	# 生成房间数量
	var room_count = randi_range(8, 12)

	# 构建响应数据
	var response = {
		"floor": floor_level,
		"player_level": player_level,
		"room_count": room_count,
		"rooms": []
	}

	# 生成起始房间
	response.rooms.append(_generate_start_room(0))

	# 生成中间房间
	for i in range(1, room_count - 1):
		var room_type = _get_random_room_type(floor_level)
		var room = _generate_room(i, room_type, floor_level, player_level)
		response.rooms.append(room)

	# 生成Boss房间
	response.rooms.append(_generate_boss_room(room_count - 1, floor_level, player_level))

	# 建立连接关系
	_setup_room_connections(response.rooms)

	print("[FakeAI] Generated ", room_count, " rooms")
	return response


## 生成房间内容（模拟AI响应）
func generate_room_content(room_id: int, room_type: String, floor_level: int, player_level: int) -> Dictionary:
	print("[FakeAI] Generating content for room ", room_id, " (", room_type, ")")

	# 模拟AI处理延迟
	await get_tree().create_timer(_simulated_delay * 0.3).timeout

	var response = {
		"room_id": room_id,
		"room_type": room_type,
		"floor_level": floor_level,
		"player_level": player_level,
		"difficulty": _calculate_difficulty(floor_level, room_type),
		"monsters": _generate_monster_config(room_type, floor_level, player_level),
		"rewards": _generate_reward_config(room_type, floor_level),
		"chests": _generate_chest_config(room_type)
	}

	print("[FakeAI] Generated content for room ", room_id)
	return response


## 生成起始房间
func _generate_start_room(room_id: int) -> Dictionary:
	return {
		"id": room_id,
		"type": "start",
		"monsters": [],
		"rewards": [],
		"chests": 0,
		"connections": []
	}


## 生成Boss房间
func _generate_boss_room(room_id: int, floor_level: int, player_level: int) -> Dictionary:
	return {
		"id": room_id,
		"type": "boss",
		"monsters": _generate_boss_monster_config(floor_level, player_level),
		"rewards": _generate_boss_reward_config(floor_level),
		"chests": 2,
		"connections": []
	}


## 生成普通房间
func _generate_room(room_id: int, room_type: String, floor_level: int, player_level: int) -> Dictionary:
	return {
		"id": room_id,
		"type": room_type,
		"monsters": _generate_monster_config(room_type, floor_level, player_level),
		"rewards": _generate_reward_config(room_type, floor_level),
		"chests": _generate_chest_config(room_type),
		"connections": []
	}


## 获取随机房间类型
func _get_random_room_type(floor_level: int) -> String:
	var rand = randf()

	if floor_level <= 2:
		# 前期：更多战斗房间
		if rand < 0.6:
			return "combat"
		elif rand < 0.8:
			return "reward"
		elif rand < 0.9:
			return "event"
		else:
			return "treasure"
	else:
		# 后期：更多精英和事件
		if rand < 0.4:
			return "combat"
		elif rand < 0.6:
			return "reward"
		elif rand < 0.7:
			return "elite"
		elif rand < 0.8:
			return "event"
		elif rand < 0.9:
			return "shop"
		else:
			return "treasure"


## 生成怪物配置
func _generate_monster_config(room_type: String, floor_level: int, player_level: int) -> Array:
	var monsters = []

	match room_type:
		"combat":
			monsters.append({"id": "goblin", "count": randi_range(2, 4)})
			if floor_level > 2:
				monsters.append({"id": "skeleton", "count": randi_range(1, 2)})
		"elite":
			monsters.append({"id": "elite_goblin", "count": randi_range(1, 2)})
			monsters.append({"id": "skeleton", "count": randi_range(1, 3)})
		"treasure":
			if randf() < 0.5:
				monsters.append({"id": "goblin", "count": randi_range(1, 2)})
		"event":
			if randf() < 0.3:
				monsters.append({"id": "goblin", "count": randi_range(1, 2)})

	return monsters


## 生成Boss怪物配置
func _generate_boss_monster_config(floor_level: int, player_level: int) -> Array:
	return [
		{
			"id": "boss_goblin_king",
			"count": 1,
			"level": floor_level + 1
		}
	]


## 生成奖励配置
func _generate_reward_config(room_type: String, floor_level: int) -> Dictionary:
	var quality = 1.0

	match room_type:
		"combat":
			quality = 1.0 + (floor_level - 1) * 0.1
		"elite":
			quality = 1.5 + (floor_level - 1) * 0.15
		"boss":
			quality = 2.0 + (floor_level - 1) * 0.2
		"reward":
			quality = 1.2 + (floor_level - 1) * 0.12
		"treasure":
			quality = 1.3 + (floor_level - 1) * 0.13

	return {
		"count": randi_range(1, 3),
		"quality": quality
	}


## 生成Boss奖励配置
func _generate_boss_reward_config(floor_level: int) -> Dictionary:
	return {
		"count": randi_range(3, 5),
		"quality": 2.0 + (floor_level - 1) * 0.3
	}


## 生成宝箱配置
func _generate_chest_config(room_type: String) -> int:
	match room_type:
		"treasure":
			return randi_range(2, 3)
		"elite":
			return 1
		"boss":
			return 2
		_:
			return 0


## 计算难度
func _calculate_difficulty(floor_level: int, room_type: String) -> int:
	var base_difficulty = floor_level

	match room_type:
		"elite":
			base_difficulty += 1
		"boss":
			base_difficulty += 2

	return base_difficulty


## 设置房间连接关系
func _setup_room_connections(rooms: Array) -> void:
	# 简单的线性连接 + 一些分支
	for i in range(rooms.size() - 1):
		rooms[i].connections.append(i + 1)
		rooms[i + 1].connections.append(i)

	# 添加一些分支连接
	if rooms.size() > 4:
		var branch_count = randi_range(1, 3)
		for _j in range(branch_count):
			var from = randi() % (rooms.size() - 2)
			var to = from + randi_range(2, 3)
			if to < rooms.size():
				if to not in rooms[from].connections:
					rooms[from].connections.append(to)
				if from not in rooms[to].connections:
					rooms[to].connections.append(from)
