## 房间内容数据模型
##
## 定义房间内部的具体内容
## 与RoomNodeData解耦，支持数据驱动

class_name RoomContentData
extends RefCounted

## 房间内容属性
var room_id: int = 0
var room_type: String = "combat"
var difficulty: int = 1

## 怪物配置
var monster_count: int = 3
var monster_level: int = 1
var monster_types: Array[String] = []

## 奖励配置
var reward_count: int = 3
var reward_quality: float = 1.0  # 奖励品质倍率
var reward_strategy: String = ""  # 奖励策略（如 "power_growth", "balanced", "random"）
var reward_items: Array[Dictionary] = []  # AI指定的具体奖励列表

## 宝箱配置
var chest_count: int = 0
var chest_quality: float = 1.0

## 事件配置
var event_id: int = -1
var event_chance: float = 0.0


## 初始化
func _init() -> void:
	pass


## 根据房间类型设置默认值
func setup_defaults_for_type(type: String) -> void:
	room_type = type

	match type:
		"start":
			monster_count = 0
			reward_count = 0
			chest_count = 0
		"combat":
			monster_count = randi_range(2, 4)
			reward_count = randi_range(1, 3)
			chest_count = 0
		"elite":
			monster_count = randi_range(1, 2)
			monster_level = 2
			reward_count = randi_range(2, 4)
			reward_quality = 1.5
			chest_count = 1
		"boss":
			monster_count = 1
			monster_level = 3
			reward_count = randi_range(3, 5)
			reward_quality = 2.0
			chest_count = 2
		"reward":
			monster_count = 0
			reward_count = randi_range(3, 5)
			reward_quality = 1.2
			chest_count = 1
		"treasure":
			monster_count = randi_range(0, 1)
			reward_count = randi_range(2, 4)
			reward_quality = 1.3
			chest_count = randi_range(2, 3)
		"shop":
			monster_count = 0
			reward_count = 0
			chest_count = 0
		"event":
			monster_count = randi_range(0, 2)
			reward_count = randi_range(1, 2)
			event_chance = 1.0


## 根据难度调整数值
func apply_difficulty_modifier(diff: int) -> void:
	difficulty = diff

	# 根据难度调整怪物数量
	var difficulty_mult = 1.0 + (diff - 1) * 0.2
	monster_count = int(monster_count * difficulty_mult)

	# 根据难度调整怪物等级
	monster_level = max(1, diff)

	# 根据难度调整奖励品质
	reward_quality *= (1.0 + (diff - 1) * 0.1)


## 设置怪物类型
func set_monster_types(types: Array[String]) -> void:
	monster_types = types


## 获取怪物类型（随机选择一个）
func get_random_monster_type() -> String:
	if monster_types.size() == 0:
		return ""
	return monster_types[randi() % monster_types.size()]


## 转换为字典
func to_dict() -> Dictionary:
	return {
		"room_id": room_id,
		"room_type": room_type,
		"difficulty": difficulty,
		"monster_count": monster_count,
		"monster_level": monster_level,
		"monster_types": monster_types,
		"reward_count": reward_count,
		"reward_quality": reward_quality,
		"reward_strategy": reward_strategy,
		"reward_items": reward_items,
		"chest_count": chest_count,
		"chest_quality": chest_quality,
		"event_id": event_id,
		"event_chance": event_chance
	}


## 从字典创建
static func from_dict(data: Dictionary) -> RoomContentData:
	var content = RoomContentData.new()
	content.room_id = data.get("room_id", 0)
	content.room_type = data.get("room_type", "combat")
	content.difficulty = data.get("difficulty", 1)
	content.monster_count = data.get("monster_count", 3)
	content.monster_level = data.get("monster_level", 1)
	content.monster_types = data.get("monster_types", [])
	content.reward_count = data.get("reward_count", 3)
	content.reward_quality = data.get("reward_quality", 1.0)
	content.reward_strategy = data.get("reward_strategy", "")
	content.reward_items = data.get("reward_items", [])
	content.chest_count = data.get("chest_count", 0)
	content.chest_quality = data.get("chest_quality", 1.0)
	content.event_id = data.get("event_id", -1)
	content.event_chance = data.get("event_chance", 0.0)
	return content


## 从RoomNodeData创建
static func from_room_node(room_node: RoomNodeData, floor_level: int = 1) -> RoomContentData:
	var content = RoomContentData.new()
	content.room_id = room_node.id
	content.setup_defaults_for_type(room_node.get_type_string())
	content.apply_difficulty_modifier(floor_level)
	return content


## 打印内容信息
func print_info() -> void:
	print("[RoomContent] Room ", room_id, " (", room_type, ")")
	print("  Difficulty: ", difficulty)
	print("  Monsters: ", monster_count, " (level ", monster_level, ")")
	print("  Rewards: ", reward_count, " (quality ", reward_quality, ")")
	if reward_strategy != "":
		print("  Reward Strategy: ", reward_strategy)
	if reward_items.size() > 0:
		print("  Reward Items: ", reward_items.size())
	print("  Chests: ", chest_count)


## 检查是否有AI指定的奖励策略
func has_reward_strategy() -> bool:
	return reward_strategy != "" or reward_items.size() > 0
