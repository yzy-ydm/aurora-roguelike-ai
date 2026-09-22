## 怪物数据模型
##
## 负责解析和存储怪物资源数据
## 从API JSON响应转换为结构化数据

class_name MonsterData
extends RefCounted

## 怪物属性
var id: int = 0
var name: String = ""
var description: String = ""
var type: String = ""
var level: int = 1
var health: int = 50      # 默认HP，防止为0
var attack: int = 5       # 默认攻击，防止为0
var defense: int = 2      # 默认防御，防止为0
var speed: int = 10
var experience_reward: int = 10
var gold_reward: int = 5
var special_ability: String = ""
var attributes: Variant = null
var icon_path: String = ""
var min_floor: int = 1
var max_floor: int = 999


## 根据楼层调整默认属性（当AI未提供时）
func apply_level_modifiers(floor_level: int) -> void:
	"""当AI生成数据缺失时，使用合理的默认值"""
	if health <= 0:
		health = 30 + floor_level * 15  # 合理HP范围
	if attack <= 0:
		attack = 3 + floor_level * 2    # 合理攻击力
	if defense <= 0:
		defense = 1 + floor_level       # 合理防御力


## 从Dictionary创建MonsterData
static func from_dict(data: Dictionary) -> MonsterData:
	var monster = MonsterData.new()
	monster.id = data.get("id", 0)
	# String 类型字段需要处理 null 值（服务器可能返回 null）
	var name_val = data.get("name")
	monster.name = name_val if name_val != null else ""
	var desc_val = data.get("description")
	monster.description = desc_val if desc_val != null else ""
	var type_val = data.get("type")
	monster.type = type_val if type_val != null else ""
	monster.level = data.get("level", 1)

	# 修复默认值：确保属性不为0
	monster.health = max(data.get("health", 50), 10)  # 最低10HP
	monster.attack = max(data.get("attack", 5), 1)    # 最低1攻击
	monster.defense = max(data.get("defense", 2), 0)  # 最低0防御

	monster.speed = data.get("speed", 10)
	monster.experience_reward = data.get("experience_reward", 10)
	monster.gold_reward = data.get("gold_reward", 5)
	# 特殊能力可能为 null
	var ability_val = data.get("special_ability")
	monster.special_ability = ability_val if ability_val != null else ""
	# attributes 保持 Variant 类型，可以接受 null
	monster.attributes = data.get("attributes", null)
	# 图标路径可能为 null
	var icon_val = data.get("icon_path")
	monster.icon_path = icon_val if icon_val != null else ""
	monster.min_floor = data.get("min_floor", 1)
	monster.max_floor = data.get("max_floor", 999)
	return monster


## 从Dictionary数组创建MonsterData数组
static func from_array(data_array: Array) -> Array[MonsterData]:
	var monsters: Array[MonsterData] = []
	for data in data_array:
		if data is Dictionary:
			monsters.append(from_dict(data))
	return monsters


## 转换为Dictionary
func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"description": description,
		"type": type,
		"level": level,
		"health": health,
		"attack": attack,
		"defense": defense,
		"speed": speed,
		"experience_reward": experience_reward,
		"gold_reward": gold_reward,
		"special_ability": special_ability,
		"attributes": attributes,
		"icon_path": icon_path,
		"min_floor": min_floor,
		"max_floor": max_floor
	}
