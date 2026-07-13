## 房间管理器
##
## 负责管理当前房间状态
## 处理房间进入、退出、切换
## 支持房间战斗流程和房间图系统

extends Node

## 房间状态枚举
enum RoomState {
	EMPTY,      # 空房间
	SPAWNING,   # 生成怪物中
	COMBAT,     # 战斗中
	CLEARED,    # 已清除
	REWARD      # 奖励阶段
}

## 当前房间数据
var _current_room: RoomData = null

## 房间列表
var _rooms: Array[RoomData] = []

## 当前房间索引
var _current_room_index: int = -1

## 当前房间状态
var _current_state: RoomState = RoomState.EMPTY

## 当前房间怪物数量
var _current_monster_count: int = 0

## RoomGraph引用
var _room_graph: Node = null

## RoomContentManager引用
var _room_content_manager: Node = null

## 当前房间内容数据
var _current_content: RoomContentData = null

## 信号
signal room_entered(room_data: RoomData)
signal room_exited(room_data: RoomData)
signal room_changed(old_room: RoomData, new_room: RoomData)
signal room_state_changed(new_state: RoomState)
signal room_combat_started()
signal room_combat_ended()
signal room_cleared()
signal monster_count_changed(count: int)


## 初始化房间管理器
func initialize(rooms: Array[RoomData]) -> void:
	_rooms = rooms
	_current_room_index = -1
	_current_room = null
	_current_state = RoomState.EMPTY
	_current_monster_count = 0


## 设置RoomGraph引用
func set_room_graph(room_graph: Node) -> void:
	_room_graph = room_graph

	# 连接信号
	if _room_graph:
		_room_graph.current_room_changed.connect(_on_room_graph_changed)
		print("[RoomManager] Connected to RoomGraph")


## 设置RoomContentManager引用
func set_room_content_manager(content_manager: Node) -> void:
	_room_content_manager = content_manager
	print("[RoomManager] Connected to RoomContentManager")


## RoomGraph房间变化回调
func _on_room_graph_changed(old_id: int, new_id: int) -> void:
	print("[RoomManager] Room graph changed: ", old_id, " -> ", new_id)

	# 获取新的房间节点
	if _room_graph:
		var room_node = _room_graph.get_room(new_id)
		if room_node:
			# 根据房间节点类型创建或获取RoomData
			var room_data = _get_or_create_room_data(room_node)
			if room_data:
				# 生成房间内容
				if _room_content_manager:
					_current_content = _room_content_manager.generate_content_for_room(room_node)
					print("[RoomManager] Room content generated for room ", new_id)

				# 进入房间
				var old_room = _current_room
				_current_room = room_data
				_current_room_index = new_id
				_current_monster_count = 0

				# 设置房间状态
				_set_room_state(RoomState.EMPTY)

				# 进入房间
				_enter_room(room_data)

				# 发送信号
				if old_room:
					room_changed.emit(old_room, room_data)
				room_entered.emit(room_data)


## 获取或创建RoomData
func _get_or_create_room_data(room_node: RoomNodeData) -> RoomData:
	# 检查是否已有对应的RoomData
	for room in _rooms:
		if room.room_name == "Room " + str(room_node.id):
			return room

	# 创建新的RoomData
	var room_data = RoomData.new()
	room_data.room_id = room_node.id
	room_data.room_name = "Room " + str(room_node.id)
	room_data.room_type = room_node.get_type_string()
	room_data.width = 20
	room_data.height = 15
	room_data.position = room_node.position

	# 添加到列表
	_rooms.append(room_data)

	return room_data


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
	_current_monster_count = 0

	# 设置房间状态
	_set_room_state(RoomState.EMPTY)

	# 进入房间
	_enter_room(new_room)

	# 发送信号
	if old_room:
		room_changed.emit(old_room, new_room)
	room_entered.emit(new_room)


## 进入指定ID的房间（通过RoomGraph）
func enter_room_by_id(room_id: int) -> bool:
	if not _room_graph:
		print("[RoomManager] RoomGraph not set")
		return false

	# 移动到指定房间
	return _room_graph.move_to_room(room_id)


## 退出当前房间
func exit_current_room() -> void:
	if _current_room:
		_exit_room(_current_room)
		room_exited.emit(_current_room)
		_current_room = null
		_current_room_index = -1
		_current_monster_count = 0
		_set_room_state(RoomState.EMPTY)


## 进入下一个房间
func enter_next_room() -> void:
	# 如果有RoomGraph，使用房间图系统
	if _room_graph:
		var available = _room_graph.get_available_room_ids()
		if available.size() > 0:
			# 进入第一个可用房间
			enter_room_by_id(available[0])
			return

	# 否则使用线性系统
	var next_index = _current_room_index + 1
	if next_index < _rooms.size():
		enter_room(next_index)
	else:
		print("[RoomManager] 已经是最后一个房间")


## 进入上一个房间
func enter_prev_room() -> void:
	var prev_index = _current_room_index - 1
	if prev_index >= 0:
		enter_room(prev_index)
	else:
		print("[RoomManager] 已经是第一个房间")


## 内部方法：进入房间
func _enter_room(room_data: RoomData) -> void:
	print("[Room] 进入房间: ", room_data.room_name, " (", room_data.room_type, ")")


## 内部方法：退出房间
func _exit_room(room_data: RoomData) -> void:
	print("[Room] 退出房间: ", room_data.room_name)


## 设置房间状态
func _set_room_state(new_state: RoomState) -> void:
	if _current_state == new_state:
		return

	_current_state = new_state
	room_state_changed.emit(new_state)

	match new_state:
		RoomState.EMPTY:
			print("[Room] State: EMPTY")
		RoomState.SPAWNING:
			print("[Room] State: SPAWNING")
		RoomState.COMBAT:
			print("[Room] Combat Started")
			room_combat_started.emit()
		RoomState.CLEARED:
			print("[Room] Room Cleared")
			room_cleared.emit()
		RoomState.REWARD:
			print("[Room] State: REWARD")


## 开始房间战斗
func start_room_combat(monster_count: int) -> void:
	if not _current_room:
		return

	_current_monster_count = monster_count
	_set_room_state(RoomState.SPAWNING)

	# 延迟设置为战斗状态
	await get_tree().create_timer(0.1).timeout
	_set_room_state(RoomState.COMBAT)

	print("[Room] Monsters Remaining: ", _current_monster_count)
	monster_count_changed.emit(_current_monster_count)


## 怪物死亡时调用
func on_monster_died() -> void:
	_current_monster_count -= 1

	if _current_monster_count < 0:
		_current_monster_count = 0

	print("[Room] Monsters Remaining: ", _current_monster_count)
	monster_count_changed.emit(_current_monster_count)

	# 检查是否所有怪物都死了
	if _current_monster_count <= 0:
		_on_room_cleared()


## 房间清除完成
func _on_room_cleared() -> void:
	_set_room_state(RoomState.CLEARED)
	room_combat_ended.emit()

	# 标记RoomGraph中的房间为已完成
	if _room_graph:
		_room_graph.complete_current_room()

	# 延迟进入奖励阶段
	await get_tree().create_timer(1.0).timeout
	_set_room_state(RoomState.REWARD)


## 获取当前房间
func get_current_room() -> RoomData:
	return _current_room


## 获取当前房间内容
func get_current_content() -> RoomContentData:
	return _current_content


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


## 获取当前房间状态
func get_room_state() -> RoomState:
	return _current_state


## 获取当前怪物数量
func get_monster_count() -> int:
	return _current_monster_count


## 检查房间是否已清除
func is_room_cleared() -> bool:
	return _current_state == RoomState.CLEARED or _current_state == RoomState.REWARD


## 检查是否在战斗中
func is_in_combat() -> bool:
	return _current_state == RoomState.COMBAT or _current_state == RoomState.SPAWNING


## 获取RoomGraph引用
func get_room_graph() -> Node:
	return _room_graph
