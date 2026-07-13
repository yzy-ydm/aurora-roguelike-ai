## 武器数据模型
##
## 负责解析和存储武器资源数据
## 从API JSON响应转换为结构化数据

class_name WeaponData
extends RefCounted

## 武器属性
var id: int = 0
var name: String = ""
var description: String = ""
var type: String = ""
var rarity: String = ""
var damage: int = 0
var crit_rate_bonus: float = 0.0
var special_effect: String = ""
var attributes: Variant = null
var icon_path: String = ""
var price: int = 0


## 从Dictionary创建WeaponData
static func from_dict(data: Dictionary) -> WeaponData:
	var weapon = WeaponData.new()
	weapon.id = data.get("id", 0)
	weapon.name = data.get("name", "")
	weapon.description = data.get("description", "")
	weapon.type = data.get("type", "")
	weapon.rarity = data.get("rarity", "")
	weapon.damage = data.get("damage", 0)
	weapon.crit_rate_bonus = data.get("crit_rate_bonus", 0.0)
	weapon.special_effect = data.get("special_effect", "")
	weapon.attributes = data.get("attributes", null)
	weapon.icon_path = data.get("icon_path", "")
	weapon.price = data.get("price", 0)
	return weapon


## 从Dictionary数组创建WeaponData数组
static func from_array(data_array: Array) -> Array[WeaponData]:
	var weapons: Array[WeaponData] = []
	for data in data_array:
		if data is Dictionary:
			weapons.append(from_dict(data))
	return weapons


## 转换为Dictionary
func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"description": description,
		"type": type,
		"rarity": rarity,
		"damage": damage,
		"crit_rate_bonus": crit_rate_bonus,
		"special_effect": special_effect,
		"attributes": attributes,
		"icon_path": icon_path,
		"price": price
	}
