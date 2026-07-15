## 强化数据模型 (Phase 12)
##
## 定义玩家升级时可选择的强化项
## 数据驱动设计，支持从配置加载

class_name UpgradeData
extends RefCounted

## 强化类型
enum UpgradeType {
	STAT_BOOST,     # 属性提升
	ABILITY,        # 能力解锁
	WEAPON_MOD,     # 武器改造
	SPECIAL         # 特殊强化
}

## 强化稀有度
enum UpgradeRarity {
	COMMON,         # 普通
	UNCOMMON,       # 优秀
	RARE,           # 稀有
	EPIC,           # 史诗
	LEGENDARY       # 传说
}

## 基础属性
var id: String = ""
var name: String = ""
var description: String = ""
var icon_path: String = ""
var type: UpgradeType = UpgradeType.STAT_BOOST
var rarity: UpgradeRarity = UpgradeRarity.COMMON

## 属性修改器 (key: 属性名, value: 修改值)
var modifiers: Dictionary = {}

## 百分比修改器 (key: 属性名, value: 百分比 0.0-1.0)
var percent_modifiers: Dictionary = {}

## 持续时间 (0 = 永久)
var duration: float = 0.0

## 是否可叠加
var stackable: bool = false

## 最大叠加层数
var max_stacks: int = 1


## 从字典创建
static func from_dict(data: Dictionary) -> UpgradeData:
	var upgrade = UpgradeData.new()
	upgrade.id = data.get("id", "")
	upgrade.name = data.get("name", "")
	upgrade.description = data.get("description", "")
	upgrade.icon_path = data.get("icon_path", "")
	upgrade.type = _parse_type(data.get("type", "stat_boost"))
	upgrade.rarity = _parse_rarity(data.get("rarity", "common"))
	upgrade.modifiers = data.get("modifiers", {})
	upgrade.percent_modifiers = data.get("percent_modifiers", {})
	upgrade.duration = data.get("duration", 0.0)
	upgrade.stackable = data.get("stackable", false)
	upgrade.max_stacks = data.get("max_stacks", 1)
	return upgrade


## 转换为字典
func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"description": description,
		"icon_path": icon_path,
		"type": _type_to_string(type),
		"rarity": _rarity_to_string(rarity),
		"modifiers": modifiers,
		"percent_modifiers": percent_modifiers,
		"duration": duration,
		"stackable": stackable,
		"max_stacks": max_stacks
	}


## 解析强化类型
static func _parse_type(type_str: String) -> UpgradeType:
	match type_str:
		"stat_boost":
			return UpgradeType.STAT_BOOST
		"ability":
			return UpgradeType.ABILITY
		"weapon_mod":
			return UpgradeType.WEAPON_MOD
		"special":
			return UpgradeType.SPECIAL
		_:
			return UpgradeType.STAT_BOOST


## 解析稀有度
static func _parse_rarity(rarity_str: String) -> UpgradeRarity:
	match rarity_str:
		"common":
			return UpgradeRarity.COMMON
		"uncommon":
			return UpgradeRarity.UNCOMMON
		"rare":
			return UpgradeRarity.RARE
		"epic":
			return UpgradeRarity.EPIC
		"legendary":
			return UpgradeRarity.LEGENDARY
		_:
			return UpgradeRarity.COMMON


## 类型转字符串
static func _type_to_string(type: UpgradeType) -> String:
	match type:
		UpgradeType.STAT_BOOST:
			return "stat_boost"
		UpgradeType.ABILITY:
			return "ability"
		UpgradeType.WEAPON_MOD:
			return "weapon_mod"
		UpgradeType.SPECIAL:
			return "special"
		_:
			return "stat_boost"


## 稀有度转字符串
static func _rarity_to_string(rarity: UpgradeRarity) -> String:
	match rarity:
		UpgradeRarity.COMMON:
			return "common"
		UpgradeRarity.UNCOMMON:
			return "uncommon"
		UpgradeRarity.RARE:
			return "rare"
		UpgradeRarity.EPIC:
			return "epic"
		UpgradeRarity.LEGENDARY:
			return "legendary"
		_:
			return "common"


## 获取稀有度颜色
static func get_rarity_color(rarity: UpgradeRarity) -> Color:
	match rarity:
		UpgradeRarity.COMMON:
			return Color(0.7, 0.7, 0.7)  # 灰色
		UpgradeRarity.UNCOMMON:
			return Color(0.2, 0.8, 0.2)  # 绿色
		UpgradeRarity.RARE:
			return Color(0.2, 0.4, 0.9)  # 蓝色
		UpgradeRarity.EPIC:
			return Color(0.7, 0.2, 0.9)  # 紫色
		UpgradeRarity.LEGENDARY:
			return Color(0.9, 0.7, 0.1)  # 金色
		_:
			return Color.WHITE
