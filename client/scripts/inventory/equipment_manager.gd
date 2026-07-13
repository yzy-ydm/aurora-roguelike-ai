## 装备管理器
##
## 管理当前装备状态
## 负责装备/卸下武器

extends Node

## 当前装备的武器ID
var _equipped_weapon_id: int = -1

## 背包管理器引用
var _inventory_manager: Node = null

## 信号
signal weapon_equipped(weapon_id: int)
signal weapon_unequipped(weapon_id: int)
signal equipment_changed


## 初始化
func initialize(inventory_manager: Node) -> void:
	_inventory_manager = inventory_manager


## 装备武器
func equip_weapon(weapon_id: int) -> bool:
	if not _inventory_manager:
		push_warning("背包管理器未初始化")
		return false

	if not _inventory_manager.has_weapon(weapon_id):
		push_warning("武器不在背包中: " + str(weapon_id))
		return false

	# 如果已有装备，先卸下
	if _equipped_weapon_id > 0:
		unequip_weapon()

	_equipped_weapon_id = weapon_id
	weapon_equipped.emit(weapon_id)
	equipment_changed.emit()
	print("装备武器: ", str(weapon_id))
	return true


## 卸下武器
func unequip_weapon() -> void:
	if _equipped_weapon_id <= 0:
		return

	var old_weapon_id = _equipped_weapon_id
	_equipped_weapon_id = -1
	weapon_unequipped.emit(old_weapon_id)
	equipment_changed.emit()
	print("卸下武器: ", str(old_weapon_id))


## 获取当前装备的武器ID
func get_equipped_weapon_id() -> int:
	return _equipped_weapon_id


## 获取当前装备的武器数据
func get_equipped_weapon() -> WeaponData:
	if _equipped_weapon_id <= 0 or not _inventory_manager:
		return null
	return _inventory_manager.get_weapon(_equipped_weapon_id)


## 检查是否已装备武器
func has_equipped_weapon() -> bool:
	return _equipped_weapon_id > 0


## 检查指定武器是否已装备
func is_weapon_equipped(weapon_id: int) -> bool:
	return _equipped_weapon_id == weapon_id
