## 楼层数据模型 (Phase 10.1)
##
## 表示一个完整的Roguelike楼层
## 包含房间列表、当前房间追踪、楼层元数据
##
## 替代旧的RoomGraph中的_rooms字典

class_name FloorData
extends RefCounted

## 楼层属性
var floor_level: int = 1
var floor_theme: String = "dungeon"

## 房间列表
var rooms: Array[NewRoomData] = []

## 当前房间索引
var current_room_id: int = -1


## ==================== 显示索引 ====================

## 分配玩家友好的显示编号
## 按房间在楼层中的顺序递增(1, 2, 3...)
## 不改变房间连接关系和内部ID
func assign_display_indices() -> void:
	for i in range(rooms.size()):
		rooms[i].display_index = i + 1


## ==================== 房间访问 ====================

## 获取当前房间
func get_current_room() -> NewRoomData:
	if current_room_id < 0:
		return null
	return get_room(current_room_id)


## 通过ID获取房间
func get_room(room_id: int) -> NewRoomData:
	for room in rooms:
		if room.id == room_id:
			return room
	return null


## 获取房间数量
func get_room_count() -> int:
	return rooms.size()


## 获取所有房间
func get_all_rooms() -> Array[NewRoomData]:
	return rooms


## ==================== 房间导航 ====================

## 设置当前房间
func set_current_room(room_id: int) -> bool:
	var room = get_room(room_id)
	if room:
		current_room_id = room_id
		room.mark_visited()
		return true
	return false


## 获取当前房间的可选出口
func get_available_exits() -> Array[NewRoomData]:
	var current = get_current_room()
	if not current:
		return []

	var exits: Array[NewRoomData] = []
	for conn_id in current.connections:
		var room = get_room(conn_id)
		if room:
			exits.append(room)
	return exits


## 获取可用出口ID列表
func get_available_exit_ids() -> Array[int]:
	var current = get_current_room()
	if not current:
		return []
	return current.connections.duplicate()


## 移动到下一个房间
func move_to_room(room_id: int) -> bool:
	var current = get_current_room()
	if current and room_id in current.connections:
		return set_current_room(room_id)
	return false


## ==================== 楼层状态 ====================

## 标记当前房间完成
func complete_current_room() -> void:
	var current = get_current_room()
	if current:
		current.mark_completed()


## 检查楼层是否完成(Boss房间清除)
func is_floor_complete() -> bool:
	for room in rooms:
		if room.room_type == NewRoomData.RoomType.BOSS:
			return room.completed
	return false


## 获取已访问房间数
func get_visited_count() -> int:
	var count = 0
	for room in rooms:
		if room.visited:
			count += 1
	return count


## 获取已完成房间数
func get_completed_count() -> int:
	var count = 0
	for room in rooms:
		if room.completed:
			count += 1
	return count


## ==================== 调试 ====================

func print_status() -> void:
	print("[FloorData] Floor ", floor_level, " - ", rooms.size(), " rooms")
	print("  Current room: ", current_room_id)
	for room in rooms:
		var conns_str = ""
		for c in room.connections:
			conns_str += str(c) + " "
		print("  Room ", room.id, " [Display:", room.display_index, "] (", room.get_type_string(), ") -> [", conns_str.strip_edges(), "] visited=", room.visited, " completed=", room.completed)
