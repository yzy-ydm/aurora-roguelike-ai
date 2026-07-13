## 背包管理器
##
## 管理玩家拥有的武器资源
## 负责添加、删除、查询武器

extends Node

## 玩家武器列表（weapon_id -> weapon_data）
var _weapons: Dictionary = {}

## 信号
signal weapon_added(weapon_id: int)
signal weapon_removed(weapon_id: int)
signal inventory_updated


func _ready() -> void:
	pass


## 添加武器到背包
func add_weapon(weapon_data: WeaponData) -> void:
	if not weapon_data:
		return

	var weapon_id = weapon_data.id
	if _weapons.has(weapon_id):
		push_warning("武器已在背包中: " + str(weapon_id))
		return

	_weapons[weapon_id] = weapon_data
	weapon_added.emit(weapon_id)
	inventory_updated.emit()
	print("武器添加到背包: ", weapon_data.name)


## 从背包移除武器
func remove_weapon(weapon_id: int) -> void:
	if not _weapons.has(weapon_id):
		push_warning("武器不在背包中: " + str(weapon_id))
		return

	_weapons.erase(weapon_id)
	weapon_removed.emit(weapon_id)
	inventory_updated.emit()
	print("武器从背包移除: ", str(weapon_id))


## 获取武器数据
func get_weapon(weapon_id: int) -> WeaponData:
	return _weapons.get(weapon_id)


## 获取所有武器
func get_all_weapons() -> Array[WeaponData]:
	var result: Array[WeaponData] = []
	for weapon in _weapons.values():
		result.append(weapon)
	return result


## 获取武器数量
func get_weapon_count() -> int:
	return _weapons.size()


## 检查是否拥有武器
func has_weapon(weapon_id: int) -> bool:
	return _weapons.has(weapon_id)


## 清空背包
func clear() -> void:
	_weapons.clear()
	inventory_updated.emit()


## 从服务器数据加载背包
func load_from_server_data(server_data: Array) -> void:
	clear()
	for item in server_data:
		if item is Dictionary:
			var weapon_id = item.get("weapon_id", -1)
			if weapon_id > 0:
				# 从ResourceService获取武器数据
				var weapon_data = ResourceService.get_weapon_by_id(weapon_id)
				if weapon_data:
					_weapons[weapon_id] = weapon_data
	inventory_updated.emit()
	print("背包已从服务器数据加载，武器数量: ", get_weapon_count())


## 转换为数组（用于保存）
func to_array() -> Array:
	var result: Array = []
	for weapon_id in _weapons:
		result.append({"weapon_id": weapon_id})
	return result
