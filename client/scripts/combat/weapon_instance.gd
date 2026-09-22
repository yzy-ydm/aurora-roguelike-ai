## 武器实例 (Phase 9.3.1)
##
## 运行时武器状态，支持等级成长
## 持有WeaponData引用，计算当前属性
##
## 职责:
## - 追踪武器等级
## - 计算当前伤害（含成长）
## - 提供升级接口
## - 保持与WeaponData的兼容性

class_name WeaponInstance
extends RefCounted

## ==================== 数据 ====================

## 武器基础数据（来自API或默认创建）
var _weapon_data: WeaponData = null

## 当前等级
var _level: int = 1

## ==================== 信号 ====================

## 升级信号
signal level_up(new_level: int, new_damage: int)


## ==================== 初始化 ====================

## 从WeaponData创建实例
static func create(data: WeaponData, start_level: int = 1) -> WeaponInstance:
	var instance = WeaponInstance.new()
	instance._weapon_data = data
	instance._level = clampi(start_level, 1, data.max_level)
	return instance


## ==================== 属性查询 ====================

## 获取当前等级
func get_level() -> int:
	return _level


## 获取最大等级
func get_max_level() -> int:
	if _weapon_data:
		return _weapon_data.max_level
	return 10


## 是否已满级
func is_max_level() -> bool:
	return _level >= get_max_level()


## 获取当前伤害（核心公式: base_damage + damage_growth * (level - 1)）
func get_damage() -> int:
	if not _weapon_data:
		return 0

	# base_damage为0时，使用damage字段作为初始伤害
	var base = _weapon_data.base_damage if _weapon_data.base_damage > 0 else _weapon_data.damage
	return base + _weapon_data.damage_growth * (_level - 1)


## 获取下一级伤害（预览）
func get_next_level_damage() -> int:
	if is_max_level():
		return get_damage()

	var base = _weapon_data.base_damage if _weapon_data.base_damage > 0 else _weapon_data.damage
	return base + _weapon_data.damage_growth * _level


## 获取武器名称
func get_name() -> String:
	if _weapon_data:
		return _weapon_data.name
	return ""


## 获取武器数据引用（供weapon.gd读取其他属性）
func get_weapon_data() -> WeaponData:
	return _weapon_data


## 获取武器类型 (fire/ice/thunder/none)
func get_weapon_type() -> String:
	if _weapon_data:
		return _weapon_data.type
	return ""


## ==================== 升级 ====================

## 尝试升级，返回是否成功
func upgrade() -> bool:
	if is_max_level():
		print("[WeaponInstance] Already max level: ", _level)
		return false

	var old_damage = get_damage()
	_level += 1
	var new_damage = get_damage()

	print("[WeaponInstance] ", get_name(), " Lv", _level, " damage: ", old_damage, " -> ", new_damage)
	level_up.emit(_level, new_damage)
	return true


## 直接设置等级（用于存档加载等）
func set_level(new_level: int) -> void:
	_level = clampi(new_level, 1, get_max_level())
	print("[WeaponInstance] ", get_name(), " level set to ", _level, " damage: ", get_damage())


## ==================== 序列化 ====================

## 导出为Dictionary（用于存档）
func to_dict() -> Dictionary:
	return {
		"weapon_id": _weapon_data.id if _weapon_data else 0,
		"level": _level
	}


## 从Dictionary恢复（需要先通过ResourceService获取WeaponData）
static func from_dict(data: Dictionary, weapon_data: WeaponData) -> WeaponInstance:
	if not weapon_data:
		return null
	return create(weapon_data, data.get("level", 1))
