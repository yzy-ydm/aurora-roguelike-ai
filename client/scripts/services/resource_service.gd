## 资源加载服务
##
## 负责从API加载游戏资源数据并缓存
## 作为全局单例使用
## Phase 15.3: 并行加载优化

extends Node

## 资源数据缓存
var _weapons: Array[WeaponData] = []
var _monsters: Array[MonsterData] = []
var _maps: Array[MapData] = []
var _events: Array[EventData] = []

## 加载状态
var _is_loading: bool = false
var _loaded_count: int = 0
const _TOTAL_RESOURCES: int = 4

## 信号
signal all_resources_loaded
signal resource_load_error(error: String)


func _ready() -> void:
	pass


## 加载所有资源(并行)
func load_all_resources() -> void:
	print("[ResourceService] load_all_resources called (parallel mode)")
	if _is_loading:
		print("[ResourceService] Already loading, skipping")
		return

	_is_loading = true
	_loaded_count = 0

	# 并行发送4个独立HTTP请求
	print("[ResourceService] Sending parallel API requests...")
	_send_resource_request("weapons", APIConfig.WEAPONS_LIST)
	_send_resource_request("monsters", APIConfig.MONSTERS_LIST)
	_send_resource_request("maps", APIConfig.MAPS_LIST)
	_send_resource_request("events", APIConfig.EVENTS_LIST)


## 发送单个资源请求(独立HTTPRequest节点)
func _send_resource_request(resource_type: String, endpoint: String) -> void:
	var url = APIConfig.get_full_url(endpoint)
	var headers: PackedStringArray = ["Content-Type: application/json"]

	var http_request = HTTPRequest.new()
	http_request.name = "ResourceRequest_" + resource_type
	http_request.timeout = 10.0
	add_child(http_request)

	http_request.request_completed.connect(
		_on_resource_loaded.bind(resource_type, http_request)
	)

	var error = http_request.request(url, headers, HTTPClient.METHOD_GET)
	if error != OK:
		print("[ResourceService] Failed to send request for: ", resource_type)
		http_request.queue_free()
		_on_resource_failed(resource_type, "HTTP request failed")


## 单个资源加载完成回调
func _on_resource_loaded(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, resource_type: String, http_request: HTTPRequest) -> void:
	http_request.queue_free()

	if result != HTTPRequest.RESULT_SUCCESS:
		print("[ResourceService] Network error for: ", resource_type)
		_on_resource_failed(resource_type, "Network error")
		return

	if response_code != 200:
		print("[ResourceService] HTTP error for: ", resource_type, " code: ", response_code)
		_on_resource_failed(resource_type, "HTTP " + str(response_code))
		return

	# 解析JSON
	var json = JSON.new()
	var parse_result = json.parse(body.get_string_from_utf8())
	if parse_result != OK:
		print("[ResourceService] JSON parse error for: ", resource_type)
		_on_resource_failed(resource_type, "JSON parse error")
		return

	var data = json.data
	if not data is Array:
		print("[ResourceService] Response is not Array for: ", resource_type)
		_on_resource_failed(resource_type, "Invalid response format")
		return

	print("[ResourceService] Loaded ", resource_type, ": ", data.size(), " items")

	# 分发到对应的解析函数
	match resource_type:
		"weapons":
			_weapons = WeaponData.from_array(data)
		"monsters":
			_monsters = MonsterData.from_array(data)
		"maps":
			_maps = MapData.from_array(data)
		"events":
			_events = EventData.from_array(data)

	_loaded_count += 1
	_check_all_loaded()


## 单个资源加载失败
func _on_resource_failed(resource_type: String, error: String) -> void:
	print("[ResourceService] Resource load failed: ", resource_type, " - ", error)
	# 加载失败时使用默认数据
	_load_default_data(resource_type)
	_loaded_count += 1
	_check_all_loaded()


## 加载默认资源数据（API失败时的fallback）
func _load_default_data(resource_type: String) -> void:
	match resource_type:
		"monsters":
			_load_default_monsters()
		"weapons":
			_load_default_weapons()
		"maps":
			_load_default_maps()
		"events":
			_load_default_events()


## 默认怪物数据
func _load_default_monsters() -> void:
	print("[ResourceService] Loading default monsters...")
	var defaults = [
		{
			"id": 1, "name": "史莱姆", "description": "最基础的怪物，由粘液构成，行动缓慢。",
			"type": "normal", "level": 1, "health": 20, "attack": 5, "defense": 2,
			"speed": 3, "experience_reward": 10, "gold_reward": 5,
			"special_ability": null, "attributes": null, "icon_path": null,
			"min_floor": 1, "max_floor": 999
		},
		{
			"id": 2, "name": "哥布林", "description": "小型人形怪物，喜欢成群结队。",
			"type": "normal", "level": 1, "health": 30, "attack": 8, "defense": 3,
			"speed": 5, "experience_reward": 15, "gold_reward": 8,
			"special_ability": null, "attributes": null, "icon_path": null,
			"min_floor": 1, "max_floor": 999
		},
		{
			"id": 3, "name": "骷髅战士", "description": "被复活的亡灵，手持生锈的武器。",
			"type": "normal", "level": 2, "health": 40, "attack": 10, "defense": 5,
			"speed": 4, "experience_reward": 20, "gold_reward": 12,
			"special_ability": null, "attributes": null, "icon_path": null,
			"min_floor": 1, "max_floor": 999
		},
		{
			"id": 4, "name": "蝙蝠", "description": "快速飞行的黑暗生物。",
			"type": "normal", "level": 1, "health": 15, "attack": 6, "defense": 1,
			"speed": 10, "experience_reward": 8, "gold_reward": 3,
			"special_ability": null, "attributes": null, "icon_path": null,
			"min_floor": 1, "max_floor": 999
		},
		{
			"id": 5, "name": "精英卫兵", "description": "经过严格训练的精英战士。",
			"type": "elite", "level": 3, "health": 80, "attack": 15, "defense": 10,
			"speed": 6, "experience_reward": 40, "gold_reward": 25,
			"special_ability": "重击", "attributes": null, "icon_path": null,
			"min_floor": 2, "max_floor": 999
		},
		{
			"id": 6, "name": "暗影刺客", "description": "来自暗影世界的致命刺客。",
			"type": "elite", "level": 3, "health": 60, "attack": 20, "defense": 4,
			"speed": 12, "experience_reward": 35, "gold_reward": 20,
			"special_ability": "隐身突袭", "attributes": null, "icon_path": null,
			"min_floor": 2, "max_floor": 999
		},
		{
			"id": 7, "name": "巨魔", "description": "体型巨大的怪物，力量惊人。",
			"type": "normal", "level": 2, "health": 50, "attack": 12, "defense": 8,
			"speed": 2, "experience_reward": 25, "gold_reward": 15,
			"special_ability": null, "attributes": null, "icon_path": null,
			"min_floor": 1, "max_floor": 999
		},
		{
			"id": 8, "name": "火焰精灵", "description": "掌控火焰的元素精灵。",
			"type": "normal", "level": 2, "health": 25, "attack": 14, "defense": 2,
			"speed": 8, "experience_reward": 18, "gold_reward": 10,
			"special_ability": "火球术", "attributes": null, "icon_path": null,
			"min_floor": 1, "max_floor": 999
		}
	]
	_monsters = MonsterData.from_array(defaults)
	print("[ResourceService] Loaded ", _monsters.size(), " default monsters")


## 默认武器数据
func _load_default_weapons() -> void:
	print("[ResourceService] Loading default weapons...")
	var defaults = [
		{
			"id": 1, "name": "铁剑", "description": "最基础的近战武器。",
			"type": "melee", "rarity": "common", "damage": 10,
			"fire_rate": 0.5, "bullet_speed": 0.0, "bullet_count": 1, "range": 50.0,
			"crit_rate_bonus": 0.0, "special_effect": null, "attributes": null,
			"icon_path": null, "price": 0
		},
		{
			"id": 2, "name": "短弓", "description": "简易的远程武器。",
			"type": "ranged", "rarity": "common", "damage": 8,
			"fire_rate": 0.8, "bullet_speed": 400.0, "bullet_count": 1, "range": 200.0,
			"crit_rate_bonus": 0.0, "special_effect": null, "attributes": null,
			"icon_path": null, "price": 0
		}
	]
	_weapons = WeaponData.from_array(defaults)
	print("[ResourceService] Loaded ", _weapons.size(), " default weapons")


## 默认地图数据
func _load_default_maps() -> void:
	print("[ResourceService] Loading default maps...")
	_maps = []
	print("[ResourceService] No default maps available")


## 默认事件数据
func _load_default_events() -> void:
	print("[ResourceService] Loading default events...")
	_events = []
	print("[ResourceService] No default events available")


## 检查是否所有资源加载完成
func _check_all_loaded() -> void:
	print("[ResourceService] Loaded ", _loaded_count, "/", _TOTAL_RESOURCES)
	if _loaded_count >= _TOTAL_RESOURCES:
		_is_loading = false
		print("[ResourceService] All resources loaded!")
		all_resources_loaded.emit()


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
