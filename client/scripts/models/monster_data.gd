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
var health: int = 0
var attack: int = 0
var defense: int = 0
var speed: int = 10
var experience_reward: int = 10
var gold_reward: int = 5
var special_ability: String = ""
var attributes: Variant = null
var icon_path: String = ""
var min_floor: int = 1
var max_floor: int = 999


## 从Dictionary创建MonsterData
static func from_dict(data: Dictionary) -> MonsterData:
	var monster = MonsterData.new()
	monster.id = data.get("id", 0)
	monster.name = data.get("name", "")
	monster.description = data.get("description", "")
	monster.type = data.get("type", "")
	monster.level = data.get("level", 1)
	monster.health = data.get("health", 0)
	monster.attack = data.get("attack", 0)
	monster.defense = data.get("defense", 0)
	monster.speed = data.get("speed", 10)
	monster.experience_reward = data.get("experience_reward", 10)
	monster.gold_reward = data.get("gold_reward", 5)
	monster.special_ability = data.get("special_ability", "")
	monster.attributes = data.get("attributes", null)
	monster.icon_path = data.get("icon_path", "")
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
