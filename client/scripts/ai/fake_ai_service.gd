## 模拟AI服务
##
## 模拟云端AI返回数据
## 用于本地测试和开发
## 未来将被真实AI API替换
##
## @deprecated: Testing only
## 生产环境请使用真实的AIContentService

extends Node

## 模拟延迟（秒）
var _simulated_delay: float = 0.5


## TASK-030: generate_floor 及楼层辅助函数已删除（AI 不再生成地图结构）


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


## TASK-030: 楼层辅助函数已删除

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
