## 世界管理器
##
## 负责管理当前世界状态
## 初始化游戏世界
## 加载当前地图资源
## 管理Room生命周期

extends Node

## 当前世界状态
enum WorldState {
	UNINITIALIZED,
	LOADING,
	READY,
	IN_ROOM,
	TRANSITIONING
}

## 当前状态
var _state: WorldState = WorldState.UNINITIALIZED

## 当前地图数据
var _current_map: MapData = null

## 地图渲染器引用
var _map_renderer: Node2D = null

## 房间管理器引用
var _room_manager: Node = null

## 信号
signal world_initialized
signal world_load_error(error: String)
signal map_changed(map_data: MapData)
signal room_changed(room_data: RoomData)


## 初始化世界管理器
func initialize(map_renderer: Node2D, room_manager: Node) -> void:
	_map_renderer = map_renderer
	_room_manager = room_manager

	# 连接房间管理器信号
	if _room_manager:
		_room_manager.room_entered.connect(_on_room_entered)
		_room_manager.room_exited.connect(_on_room_exited)

	_state = WorldState.UNINITIALIZED


## 加载世界
func load_world(map_id: int = -1) -> void:
	_state = WorldState.LOADING

	# 获取地图数据
	var maps = ResourceService.get_maps()

	if maps.size() == 0:
		world_load_error.emit("没有可用的地图数据")
		_state = WorldState.UNINITIALIZED
		return

	# 选择地图
	if map_id >= 0:
		_current_map = ResourceService.get_map_by_id(map_id)
		if not _current_map:
			world_load_error.emit("地图不存在: " + str(map_id))
			_state = WorldState.UNINITIALIZED
			return
	else:
		# 默认使用第一张地图
		_current_map = maps[0]

	# 加载地图
	if _map_renderer:
		_map_renderer.load_map(_current_map)

	# 初始化房间管理器
	if _room_manager:
		var rooms = RoomData.from_map_data(_current_map)
		_room_manager.initialize(rooms)

	_state = WorldState.READY
	map_changed.emit(_current_map)
	world_initialized.emit()

	print("世界加载完成: ", _current_map.name, " (", _current_map.type, ")")


## 进入第一个房间
func enter_first_room() -> void:
	if _state != WorldState.READY:
		push_warning("世界未就绪，无法进入房间")
		return

	if _room_manager:
		_room_manager.enter_first_room()
		_state = WorldState.IN_ROOM


## 进入下一个房间
func enter_next_room() -> void:
	if _state != WorldState.IN_ROOM:
		push_warning("当前不在房间中")
		return

	if _room_manager:
		_room_manager.enter_next_room()


## 进入上一个房间
func enter_prev_room() -> void:
	if _state != WorldState.IN_ROOM:
		push_warning("当前不在房间中")
		return

	if _room_manager:
		_room_manager.enter_prev_room()


## 退出当前房间
func exit_current_room() -> void:
	if _room_manager:
		_room_manager.exit_current_room()
		_state = WorldState.READY


## 清除世界
func clear_world() -> void:
	if _map_renderer:
		_map_renderer.clear_map()

	if _room_manager:
		_room_manager.exit_current_room()

	_current_map = null
	_state = WorldState.UNINITIALIZED


## 房间进入回调
func _on_room_entered(room_data: RoomData) -> void:
	_state = WorldState.IN_ROOM
	room_changed.emit(room_data)
	print("玩家进入房间: ", room_data.room_name)


## 房间退出回调
func _on_room_exited(room_data: RoomData) -> void:
	print("玩家退出房间: ", room_data.room_name)


## 获取当前世界状态
func get_state() -> WorldState:
	return _state


## 获取当前地图
func get_current_map() -> MapData:
	return _current_map


## 获取房间管理器
func get_room_manager() -> Node:
	return _room_manager


## 获取地图渲染器
func get_map_renderer() -> Node2D:
	return _map_renderer


## 检查世界是否就绪
func is_ready() -> bool:
	return _state == WorldState.READY or _state == WorldState.IN_ROOM


## 检查是否在房间中
func is_in_room() -> bool:
	return _state == WorldState.IN_ROOM
