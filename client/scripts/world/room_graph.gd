## 房间图管理器
##
## 管理房间节点和连接关系
## 追踪当前房间和可访问房间
## 支持AI楼层生成（带本地降级）
##
## @deprecated: Replaced by FloorManager
## 保留用于fallback，新代码请使用FloorManager

extends Node

## 房间节点字典
var _rooms: Dictionary = {}  # id -> RoomNodeData

## 当前房间ID
var _current_room_id: int = -1

## 当前楼层
var _current_floor: int = 1

## 当前玩家等级
var _player_level: int = 1

## FloorGenerator引用（本地降级）
var _floor_generator: Node = null

## AIContentService引用
var _ai_content_service: Node = null

## 信号
signal room_graph_generated()
signal current_room_changed(old_id: int, new_id: int)
signal room_visited(room_id: int)
signal room_completed(room_id: int)
signal floor_completed()


## 初始化
func _ready() -> void:
	# 创建FloorGenerator（本地降级用）
	_floor_generator = Node.new()
	_floor_generator.name = "FloorGenerator"
	_floor_generator.set_script(load("res://scripts/world/floor_generator.gd"))
	add_child(_floor_generator)

	print("[RoomGraph] Initialized")


## 设置AIContentService引用
func set_ai_content_service(ai_service: Node) -> void:
	_ai_content_service = ai_service
	print("[RoomGraph] Connected to AIContentService")


## 设置玩家等级
func set_player_level(level: int) -> void:
	_player_level = level


## 生成新的楼层（非阻塞：先用本地生成，AI结果后台更新）
func generate_new_floor(floor_level: int = 1) -> void:
	print("[RoomGraph] Generating new floor: ", floor_level)

	# 清除旧数据
	_rooms.clear()
	_current_room_id = -1
	_current_floor = floor_level

	# 第一步：立即使用本地FloorGenerator（同步，不阻塞）
	print("[RoomGraph] Using local FloorGenerator for immediate start")
	var rooms: Array[RoomNodeData] = _floor_generator.generate_floor(floor_level)

	# 添加到字典
	for room in rooms:
		_rooms[room.id] = room

	# 设置起始房间为当前房间
	if rooms.size() > 0:
		_current_room_id = 0
		_rooms[0].mark_visited()

	# 打印房间图
	_floor_generator.print_floor_graph(rooms)

	# 立即发射信号，让游戏可以开始
	room_graph_generated.emit()
	print("[RoomGraph] Floor generated locally: ", rooms.size(), " rooms")

	# 第二步：后台请求AI生成楼层结构（不阻塞游戏）
	if _ai_content_service:
		print("[RoomGraph] Requesting AI floor in background...")
		_request_ai_floor_async(floor_level)


## 后台请求AI楼层（不阻塞游戏流程）
func _request_ai_floor_async(floor_level: int) -> void:
	var ai_rooms: Array[RoomNodeData] = await _ai_content_service.generate_floor_content(floor_level, _player_level)

	if ai_rooms.size() > 0:
		print("[RoomGraph] AI floor received: ", ai_rooms.size(), " rooms, updating...")
		# 更新房间数据（保留当前房间状态）
		for room in ai_rooms:
			if _rooms.has(room.id):
				# 保留已访问/已完成状态
				var old_room = _rooms[room.id]
				room.visited = old_room.visited
				room.completed = old_room.completed
			_rooms[room.id] = room
		print("[RoomGraph] AI floor data updated")
	else:
		print("[RoomGraph] AI floor generation failed, keeping local data")


## 获取当前房间
func get_current_room() -> RoomNodeData:
	if _current_room_id >= 0 and _rooms.has(_current_room_id):
		return _rooms[_current_room_id]
	return null


## 获取当前房间ID
func get_current_room_id() -> int:
	return _current_room_id


## 获取指定ID的房间
func get_room(room_id: int) -> RoomNodeData:
	return _rooms.get(room_id)


## 获取所有房间
func get_all_rooms() -> Array[RoomNodeData]:
	var result: Array[RoomNodeData] = []
	for room in _rooms.values():
		result.append(room)
	return result


## 获取房间数量
func get_room_count() -> int:
	return _rooms.size()


## 获取当前房间的可访问房间
func get_available_rooms() -> Array[RoomNodeData]:
	var current_room = get_current_room()
	if not current_room:
		return []

	var available: Array[RoomNodeData] = []
	for conn_id in current_room.connections:
		var room = _rooms.get(conn_id)
		if room:
			available.append(room)

	return available


## 获取可访问房间的ID列表
func get_available_room_ids() -> Array[int]:
	var current_room = get_current_room()
	if not current_room:
		return []

	return current_room.connections.duplicate()


## 移动到指定房间
func move_to_room(room_id: int) -> bool:
	# 检查房间是否存在
	if not _rooms.has(room_id):
		print("[RoomGraph] Room not found: ", room_id)
		return false

	# 检查是否可以从当前房间到达
	var current_room = get_current_room()
	if current_room and room_id not in current_room.connections:
		print("[RoomGraph] Room ", room_id, " is not connected to current room")
		return false

	# 移动到新房间
	var old_id = _current_room_id
	_current_room_id = room_id

	# 标记为已访问
	_rooms[room_id].mark_visited()

	print("[RoomGraph] Current room: ", room_id)
	current_room_changed.emit(old_id, room_id)
	room_visited.emit(room_id)

	return true


## 标记房间为已访问
func visit_room(room_id: int) -> void:
	if _rooms.has(room_id):
		_rooms[room_id].mark_visited()
		room_visited.emit(room_id)


## 完成当前房间
func complete_current_room() -> void:
	var current_room = get_current_room()
	if current_room:
		current_room.mark_completed()
		print("[RoomGraph] Room completed: ", current_room.id)
		room_completed.emit(current_room.id)

		# 检查是否完成Boss房间
		if current_room.room_type == RoomNodeData.RoomType.BOSS:
			print("[RoomGraph] Floor completed!")
			floor_completed.emit()


## 检查房间是否已访问
func is_room_visited(room_id: int) -> bool:
	var room = _rooms.get(room_id)
	if room:
		return room.visited
	return false


## 检查房间是否已完成
func is_room_completed(room_id: int) -> bool:
	var room = _rooms.get(room_id)
	if room:
		return room.completed
	return false


## 获取当前楼层
func get_current_floor() -> int:
	return _current_floor


## 获取房间图的字符串表示
func get_graph_string() -> String:
	var result = "Room Graph (Floor " + str(_current_floor) + "):\n"
	result += "Current Room: " + str(_current_room_id) + "\n"
	result += "Available Rooms: "

	var available = get_available_room_ids()
	for i in range(available.size()):
		if i > 0:
			result += ", "
		result += str(available[i])

	result += "\n\n"
	result += _floor_generator.get_floor_graph_string(get_all_rooms())
	return result


## 打印当前状态
func print_status() -> void:
	print("[RoomGraph] Current room: ", _current_room_id)
	print("[RoomGraph] Available rooms: ", get_available_room_ids())
