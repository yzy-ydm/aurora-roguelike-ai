## AI质量检查器
##
## 评估AI生成内容的质量
## 检查地图连通性、难度合理性、奖励合理性
## 返回质量评分

extends Node

## 评分权重
const WEIGHT_CONNECTIVITY: float = 0.3
const WEIGHT_DIFFICULTY: float = 0.25
const WEIGHT_REWARDS: float = 0.25
const WEIGHT_MONSTERS: float = 0.2

## 评分阈值
const MIN_QUALITY_SCORE: float = 0.5
const MAX_QUALITY_SCORE: float = 1.0

## 信号
signal quality_checked(data_type: String, score: float)


## 检查楼层质量
func check_floor_quality(data: Dictionary) -> float:
	print("[QualityChecker] Checking floor quality")

	var scores = []

	# 检查地图连通性
	var connectivity_score = _check_connectivity(data.get("rooms", []))
	scores.append({"score": connectivity_score, "weight": WEIGHT_CONNECTIVITY})

	# 检查难度合理性
	var difficulty_score = _check_difficulty(data.get("rooms", []))
	scores.append({"score": difficulty_score, "weight": WEIGHT_DIFFICULTY})

	# 检查奖励合理性
	var reward_score = _check_rewards(data.get("rooms", []))
	scores.append({"score": reward_score, "weight": WEIGHT_REWARDS})

	# 检查怪物合理性
	var monster_score = _check_monsters(data.get("rooms", []))
	scores.append({"score": monster_score, "weight": WEIGHT_MONSTERS})

	# 计算总分
	var total_score = _calculate_total_score(scores)

	print("[QualityChecker] Floor quality score: ", total_score)
	quality_checked.emit("floor", total_score)

	return total_score


## 检查房间内容质量
func check_room_content_quality(data: Dictionary) -> float:
	print("[QualityChecker] Checking room content quality")

	var scores = []

	# 检查难度合理性
	var difficulty_score = _check_single_difficulty(data)
	scores.append({"score": difficulty_score, "weight": WEIGHT_DIFFICULTY})

	# 检查奖励合理性
	var reward_score = _check_single_rewards(data)
	scores.append({"score": reward_score, "weight": WEIGHT_REWARDS})

	# 检查怪物合理性
	var monster_score = _check_single_monsters(data)
	scores.append({"score": monster_score, "weight": WEIGHT_MONSTERS})

	# 计算总分
	var total_score = _calculate_total_score(scores)

	print("[QualityChecker] Room content quality score: ", total_score)
	quality_checked.emit("room_content", total_score)

	return total_score


## 检查地图连通性
func _check_connectivity(rooms: Array) -> float:
	if rooms.size() == 0:
		return 0.0

	# 检查是否有起始房间
	var has_start = false
	for room in rooms:
		if room is Dictionary and room.get("type") == "start":
			has_start = true
			break

	if not has_start:
		return 0.3

	# 检查是否有Boss房间
	var has_boss = false
	for room in rooms:
		if room is Dictionary and room.get("type") == "boss":
			has_boss = true
			break

	if not has_boss:
		return 0.5

	# 检查连接有效性
	var valid_connections = 0
	var total_connections = 0

	for room in rooms:
		if not room is Dictionary:
			continue

		var connections = room.get("connections", [])
		for conn in connections:
			total_connections += 1
			if conn is int and conn >= 0 and conn < rooms.size():
				valid_connections += 1

	if total_connections == 0:
		return 0.4

	var connection_ratio = float(valid_connections) / float(total_connections)
	return min(1.0, connection_ratio + 0.3)


## 检查难度合理性
func _check_difficulty(rooms: Array) -> float:
	if rooms.size() == 0:
		return 0.0

	var difficulty_sum = 0
	var room_count = 0

	for room in rooms:
		if not room is Dictionary:
			continue

		var monsters = room.get("monsters", [])
		for monster in monsters:
			if monster is Dictionary:
				var level = monster.get("level", 1)
				difficulty_sum += level
				room_count += 1

	if room_count == 0:
		return 1.0

	var avg_difficulty = float(difficulty_sum) / float(room_count)

	# 检查平均难度是否在合理范围内
	if avg_difficulty < 1.0:
		return 0.5
	elif avg_difficulty > 5.0:
		return 0.6
	else:
		return min(1.0, avg_difficulty / 3.0)


## 检查奖励合理性
func _check_rewards(rooms: Array) -> float:
	if rooms.size() == 0:
		return 0.0

	var reward_sum = 0
	var quality_sum = 0.0
	var room_count = 0

	for room in rooms:
		if not room is Dictionary:
			continue

		var rewards = room.get("rewards", {})
		if rewards is Dictionary:
			reward_sum += rewards.get("count", 0)
			quality_sum += rewards.get("quality", 1.0)
			room_count += 1

	if room_count == 0:
		return 1.0

	var avg_rewards = float(reward_sum) / float(room_count)
	var avg_quality = quality_sum / float(room_count)

	# 检查奖励数量是否合理
	var reward_score = 1.0
	if avg_rewards > 5.0:
		reward_score = 0.7
	elif avg_rewards < 1.0:
		reward_score = 0.8

	# 检查奖励品质是否合理
	var quality_score = 1.0
	if avg_quality > 3.0:
		quality_score = 0.7
	elif avg_quality < 0.5:
		quality_score = 0.8

	return (reward_score + quality_score) / 2.0


## 检查怪物合理性
func _check_monsters(rooms: Array) -> float:
	if rooms.size() == 0:
		return 0.0

	var monster_sum = 0
	var room_count = 0

	for room in rooms:
		if not room is Dictionary:
			continue

		var monsters = room.get("monsters", [])
		var room_monsters = 0
		for monster in monsters:
			if monster is Dictionary:
				room_monsters += monster.get("count", 0)

		monster_sum += room_monsters
		room_count += 1

	if room_count == 0:
		return 1.0

	var avg_monsters = float(monster_sum) / float(room_count)

	# 检查怪物数量是否合理
	if avg_monsters > 10.0:
		return 0.6
	elif avg_monsters < 1.0:
		return 0.8
	else:
		return min(1.0, avg_monsters / 5.0)


## 检查单个房间难度
func _check_single_difficulty(data: Dictionary) -> float:
	var difficulty = data.get("difficulty", 1)

	if difficulty < 1:
		return 0.5
	elif difficulty > 10:
		return 0.6
	else:
		return min(1.0, float(difficulty) / 5.0)


## 检查单个房间奖励
func _check_single_rewards(data: Dictionary) -> float:
	var rewards = data.get("rewards", {})
	if not rewards is Dictionary:
		return 0.5

	var count = rewards.get("count", 0)
	var quality = rewards.get("quality", 1.0)

	var score = 1.0

	if count > 10:
		score *= 0.7
	elif count < 1:
		score *= 0.8

	if quality > 5.0:
		score *= 0.7
	elif quality < 0.5:
		score *= 0.8

	return score


## 检查单个房间怪物
func _check_single_monsters(data: Dictionary) -> float:
	var monsters = data.get("monsters", [])
	if not monsters is Array:
		return 0.5

	var total_count = 0
	for monster in monsters:
		if monster is Dictionary:
			total_count += monster.get("count", 0)

	if total_count > 20:
		return 0.6
	elif total_count == 0:
		return 0.9
	else:
		return min(1.0, float(total_count) / 10.0)


## 计算总分
func _calculate_total_score(scores: Array) -> float:
	if scores.size() == 0:
		return 0.0

	var weighted_sum = 0.0
	var total_weight = 0.0

	for item in scores:
		weighted_sum += item.score * item.weight
		total_weight += item.weight

	if total_weight == 0:
		return 0.0

	var final_score = weighted_sum / total_weight

	# 限制在合理范围内
	final_score = max(MIN_QUALITY_SCORE, min(MAX_QUALITY_SCORE, final_score))

	return final_score


## 获取质量等级
func get_quality_grade(score: float) -> String:
	if score >= 0.9:
		return "S"
	elif score >= 0.8:
		return "A"
	elif score >= 0.7:
		return "B"
	elif score >= 0.6:
		return "C"
	else:
		return "D"


## 打印质量报告
func print_quality_report(data_type: String, score: float) -> void:
	var grade = get_quality_grade(score)
	print("[QualityChecker] Quality Report:")
	print("  Type: ", data_type)
	print("  Score: ", score)
	print("  Grade: ", grade)
