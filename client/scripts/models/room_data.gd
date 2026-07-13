## 房间数据模型
##
## 负责保存房间基础数据
## 为未来扩展预留接口

class_name RoomData
extends RefCounted

## 房间属性
var room_id: int = 0
var room_name: String = ""
var room_type: String = ""
var resource_path: String = ""
var width: int = 20
var height: int = 15
var position: Vector2 = Vector2.ZERO

## 房间连接
var connected_rooms: Array[int] = []

## 房间配置
var config: Dictionary = {}


## 从Dictionary创建RoomData
static func from_dict(data: Dictionary) -> RoomData:
	var room = RoomData.new()
	room.room_id = data.get("room_id", 0)
	room.room_name = data.get("room_name", "")
	room.room_type = data.get("room_type", "normal")
	room.resource_path = data.get("resource_path", "")
	room.width = data.get("width", 20)
	room.height = data.get("height", 15)
	room.position = Vector2(data.get("x", 0), data.get("y", 0))
	room.connected_rooms = data.get("connected_rooms", [])
	room.config = data.get("config", {})
	return room


## 从MapData创建房间列表
static func from_map_data(map_data: MapData) -> Array[RoomData]:
	var rooms: Array[RoomData] = []

	if map_data.room_data and map_data.room_data.has("rooms"):
		var room_array = map_data.room_data["rooms"]
		var room_id = 1
		for room_dict in room_array:
			if room_dict is Dictionary:
				var room = RoomData.new()
				room.room_id = room_id
				room.room_name = "Room " + str(room_id)
				room.room_type = room_dict.get("type", "normal")
				room.width = room_dict.get("w", 4)
				room.height = room_dict.get("h", 3)
				room.position = Vector2(room_dict.get("x", 0), room_dict.get("y", 0))
				rooms.append(room)
				room_id += 1

	return rooms


## 转换为Dictionary
func to_dict() -> Dictionary:
	return {
		"room_id": room_id,
		"room_name": room_name,
		"room_type": room_type,
		"resource_path": resource_path,
		"width": width,
		"height": height,
		"x": position.x,
		"y": position.y,
		"connected_rooms": connected_rooms,
		"config": config
	}
