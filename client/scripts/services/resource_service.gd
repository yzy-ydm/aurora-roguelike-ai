## 资源加载服务
##
## 负责从API加载游戏资源数据并缓存
## 作为全局单例使用

extends Node

## 资源数据缓存
var _weapons: Array[WeaponData] = []
var _monsters: Array[MonsterData] = []
var _maps: Array[MapData] = []
var _events: Array[EventData] = []

## 加载状态
var _is_loading: bool = false
var _load_progress: Dictionary = {
	"weapons": false,
	"monsters": false,
	"maps": false,
	"events": false
}

## 信号
signal all_resources_loaded
signal resource_load_error(error: String)


func _ready() -> void:
	# 连接API信号
	ApiClient.request_completed.connect(_on_api_success)
	ApiClient.request_failed.connect(_on_api_error)


## 加载所有资源
func load_all_resources() -> void:
	if _is_loading:
		return

	_is_loading = true
	_load_progress = {
		"weapons": false,
		"monsters": false,
		"maps": false,
		"events": false
	}

	# 开始加载各类资源
	ApiClient.get_request(APIConfig.WEAPONS_LIST)
	ApiClient.get_request(APIConfig.MONSTERS_LIST)
	ApiClient.get_request(APIConfig.MAPS_LIST)
	ApiClient.get_request(APIConfig.EVENTS_LIST)


## API请求成功回调
func _on_api_success(result: Variant) -> void:
	if not result is Array:
		return

	# 根据数据结构判断资源类型
	if result.size() > 0:
		var first_item = result[0]
		if first_item is Dictionary:
			if first_item.has("damage"):
				_parse_weapons(result)
			elif first_item.has("health") and first_item.has("attack") and not first_item.has("floor_level"):
				_parse_monsters(result)
			elif first_item.has("floor_level"):
				_parse_maps(result)
			elif first_item.has("trigger_rate"):
				_parse_events(result)


## 解析武器数据
func _parse_weapons(data: Array) -> void:
	_weapons = WeaponData.from_array(data)
	_load_progress["weapons"] = true
	_check_all_loaded()


## 解析怪物数据
func _parse_monsters(data: Array) -> void:
	_monsters = MonsterData.from_array(data)
	_load_progress["monsters"] = true
	_check_all_loaded()


## 解析地图数据
func _parse_maps(data: Array) -> void:
	_maps = MapData.from_array(data)
	_load_progress["maps"] = true
	_check_all_loaded()


## 解析事件数据
func _parse_events(data: Array) -> void:
	_events = EventData.from_array(data)
	_load_progress["events"] = true
	_check_all_loaded()


## 检查是否所有资源加载完成
func _check_all_loaded() -> void:
	for key in _load_progress:
		if not _load_progress[key]:
			return

	_is_loading = false
	all_resources_loaded.emit()


## API请求失败回调
func _on_api_error(error: String, _status_code: int) -> void:
	_is_loading = false
	resource_load_error.emit(error)


## 获取武器列表
func get_weapons() -> Array[WeaponData]:
	return _weapons


## 获取怪物列表
func get_monsters() -> Array[MonsterData]:
	return _monsters


## 获取地图列表
func get_maps() -> Array[MapData]:
	return _maps


## 获取事件列表
func get_events() -> Array[EventData]:
	return _events


## 获取武器数量
func get_weapon_count() -> int:
	return _weapons.size()


## 获取怪物数量
func get_monster_count() -> int:
	return _monsters.size()


## 获取地图数量
func get_map_count() -> int:
	return _maps.size()


## 获取事件数量
func get_event_count() -> int:
	return _events.size()


## 根据ID获取武器
func get_weapon_by_id(id: int) -> WeaponData:
	for weapon in _weapons:
		if weapon.id == id:
			return weapon
	return null


## 根据ID获取怪物
func get_monster_by_id(id: int) -> MonsterData:
	for monster in _monsters:
		if monster.id == id:
			return monster
	return null


## 根据ID获取地图
func get_map_by_id(id: int) -> MapData:
	for map_data in _maps:
		if map_data.id == id:
			return map_data
	return null


## 根据ID获取事件
func get_event_by_id(id: int) -> EventData:
	for event in _events:
		if event.id == id:
			return event
	return null


## 检查是否正在加载
func is_loading() -> bool:
	return _is_loading


## 检查资源是否已加载
func is_loaded() -> bool:
	return not _is_loading and _weapons.size() > 0
