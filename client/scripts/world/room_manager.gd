## 房间管理器
##
## 负责管理当前房间状态
## 处理房间进入、退出、切换

extends Node

## 当前房间数据
var _current_room: RoomData = null

## 房间列表
var _rooms: Array[RoomData] = []

## 当前房间索引
var _current_room_index: int = -1

## 信号
signal room_entered(room_data: RoomData)
signal room_exited(room_data: RoomData)
signal room_changed(old_room: RoomData, new_room: RoomData)


## 初始化房间管理器
func initialize(rooms: Array[RoomData]) -> void:
	_rooms = rooms
	_current_room_index = -1
	_current_room = null


## 进入第一个房间
func enter_first_room() -> void:
	if _rooms.size() > 0:
		enter_room(0)


## 进入指定索引的房间
func enter_room(index: int) -> void:
	if index < 0 or index >= _rooms.size():
		push_warning("房间索引超出范围: " + str(index))
		return

	var old_room = _current_room
	var new_room = _rooms[index]

	# 退出当前房间
	if old_room:
		_exit_room(old_room)

	# 进入新房间
	_current_room = new_room
	_current_room_index = index
	_enter_room(new_room)

	# 发送信号
	if old_room:
		room_changed.emit(old_room, new_room)
	room_entered.emit(new_room)


## 退出当前房间
func exit_current_room() -> void:
	if _current_room:
		_exit_room(_current_room)
		room_exited.emit(_current_room)
		_current_room = null
		_current_room_index = -1


## 进入下一个房间
func enter_next_room() -> void:
	var next_index = _current_room_index + 1
	if next_index < _rooms.size():
		enter_room(next_index)
	else:
		print("已经是最后一个房间")


## 进入上一个房间
func enter_prev_room() -> void:
	var prev_index = _current_room_index - 1
	if prev_index >= 0:
		enter_room(prev_index)
	else:
		print("已经是第一个房间")


## 内部方法：进入房间
func _enter_room(room_data: RoomData) -> void:
	print("进入房间: ", room_data.room_name, " (", room_data.room_type, ")")


## 内部方法：退出房间
func _exit_room(room_data: RoomData) -> void:
	print("退出房间: ", room_data.room_name)


## 获取当前房间
func get_current_room() -> RoomData:
	return _current_room


## 获取当前房间索引
func get_current_room_index() -> int:
	return _current_room_index


## 获取房间总数
func get_room_count() -> int:
	return _rooms.size()


## 获取所有房间
func get_all_rooms() -> Array[RoomData]:
	return _rooms


## 根据索引获取房间
func get_room_by_index(index: int) -> RoomData:
	if index >= 0 and index < _rooms.size():
		return _rooms[index]
	return null


## 检查是否有房间
func has_rooms() -> bool:
	return _rooms.size() > 0


## 检查是否在房间中
func is_in_room() -> bool:
	return _current_room != null
