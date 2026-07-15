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

## 战斗属性（用于Weapon系统）
var fire_rate: float = 0.3       # 攻击间隔（秒）
var bullet_speed: float = 500.0  # 子弹速度
var bullet_count: int = 1        # 每次发射子弹数
var range: float = 500.0         # 射程

## 武器成长属性（Phase 9.3.1）
var base_damage: int = 0         # 基础伤害（为0时使用damage字段）
var damage_growth: int = 5       # 每级伤害增长
var max_level: int = 10          # 最大等级


## 从Dictionary创建WeaponData
static func from_dict(data: Dictionary) -> WeaponData:
	var weapon = WeaponData.new()
	weapon.id = data.get("id", 0)
	# String 类型字段需要处理 null 值
	var name_val = data.get("name")
	weapon.name = name_val if name_val != null else ""
	var desc_val = data.get("description")
	weapon.description = desc_val if desc_val != null else ""
	var type_val = data.get("type")
	weapon.type = type_val if type_val != null else ""
	var rarity_val = data.get("rarity")
	weapon.rarity = rarity_val if rarity_val != null else ""
	weapon.damage = data.get("damage", 0)
	weapon.crit_rate_bonus = data.get("crit_rate_bonus", 0.0)
	# 特殊效果可能为 null
	var effect_val = data.get("special_effect")
	weapon.special_effect = effect_val if effect_val != null else ""
	# attributes 保持 Variant 类型，可以接受 null
	weapon.attributes = data.get("attributes", null)
	# 图标路径可能为 null
	var icon_val = data.get("icon_path")
	weapon.icon_path = icon_val if icon_val != null else ""
	weapon.price = data.get("price", 0)

	# 战斗属性
	weapon.fire_rate = data.get("fire_rate", 0.3)
	weapon.bullet_speed = data.get("bullet_speed", 400.0)
	weapon.bullet_count = data.get("bullet_count", 1)
	weapon.range = data.get("range", 500.0)

	# 成长属性
	weapon.base_damage = data.get("base_damage", 0)
	weapon.damage_growth = data.get("damage_growth", 5)
	weapon.max_level = data.get("max_level", 10)

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
		"price": price,
		"fire_rate": fire_rate,
		"bullet_speed": bullet_speed,
		"bullet_count": bullet_count,
		"range": range,
		"base_damage": base_damage,
		"damage_growth": damage_growth,
		"max_level": max_level
	}
