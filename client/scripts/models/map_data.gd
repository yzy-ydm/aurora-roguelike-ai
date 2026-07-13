## 地图数据模型
##
## 负责解析和存储地图资源数据
## 从API JSON响应转换为结构化数据

class_name MapData
extends RefCounted

## 地图属性
var id: int = 0
var name: String = ""
var description: String = ""
var type: String = ""
var floor_level: int = 1
var width: int = 20
var height: int = 15
var room_count: int = 8
var room_data: Variant = null
var monster_spawn_config: Variant = null
var event_spawn_config: Variant = null
var difficulty: int = 1


## 从Dictionary创建MapData
static func from_dict(data: Dictionary) -> MapData:
	var map_data = MapData.new()
	map_data.id = data.get("id", 0)
	map_data.name = data.get("name", "")
	map_data.description = data.get("description", "")
	map_data.type = data.get("type", "")
	map_data.floor_level = data.get("floor_level", 1)
	map_data.width = data.get("width", 20)
	map_data.height = data.get("height", 15)
	map_data.room_count = data.get("room_count", 8)
	map_data.room_data = data.get("room_data", null)
	map_data.monster_spawn_config = data.get("monster_spawn_config", null)
	map_data.event_spawn_config = data.get("event_spawn_config", null)
	map_data.difficulty = data.get("difficulty", 1)
	return map_data


## 从Dictionary数组创建MapData数组
static func from_array(data_array: Array) -> Array[MapData]:
	var maps: Array[MapData] = []
	for data in data_array:
		if data is Dictionary:
			maps.append(from_dict(data))
	return maps


## 转换为Dictionary
func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"description": description,
		"type": type,
		"floor_level": floor_level,
		"width": width,
		"height": height,
		"room_count": room_count,
		"room_data": room_data,
		"monster_spawn_config": monster_spawn_config,
		"event_spawn_config": event_spawn_config,
		"difficulty": difficulty
	}
