## 地图渲染器
##
## 负责根据地图资源显示基础地图
## 管理地图节点
## 提供地图加载入口

extends Node2D

## 地图配置
const TILE_SIZE: int = 32

## 当前地图数据
var _current_map: MapData = null

## 当前房间列表
var _rooms: Array[RoomData] = []

## 地图节点
var _map_node: Node2D = null

## 房间节点字典
var _room_nodes: Dictionary = {}

## 信号
signal map_loaded(map_data: MapData)
signal map_load_error(error: String)


## 加载地图
func load_map(map_data: MapData) -> void:
	# 清除旧地图
	clear_map()

	_current_map = map_data

	# 创建地图根节点
	_map_node = Node2D.new()
	_map_node.name = "Map_" + str(map_data.id)
	add_child(_map_node)

	# 解析房间数据
	_rooms = RoomData.from_map_data(map_data)

	# 渲染房间
	_render_rooms()

	map_loaded.emit(map_data)


## 清除地图
func clear_map() -> void:
	if _map_node:
		_map_node.queue_free()
		_map_node = null

	_room_nodes.clear()
	_rooms.clear()
	_current_map = null


## 渲染房间
func _render_rooms() -> void:
	for room in _rooms:
		_render_room(room)


## 渲染单个房间
func _render_room(room: RoomData) -> void:
	# 创建房间节点
	var room_node = Node2D.new()
	room_node.name = "Room_" + str(room.room_id)
	room_node.position = room.position * TILE_SIZE

	# 创建房间背景
	var bg = ColorRect.new()
	bg.name = "Background"
	bg.size = Vector2(room.width * TILE_SIZE, room.height * TILE_SIZE)
	bg.position = -bg.size / 2
	bg.color = _get_room_color(room.room_type)
	room_node.add_child(bg)

	# 创建房间边框
	var border = _create_room_border(room)
	room_node.add_child(border)

	# 创建房间标签
	var label = Label.new()
	label.name = "Label"
	label.text = room.room_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(-50, -room.height * TILE_SIZE / 2 - 20)
	room_node.add_child(label)

	_map_node.add_child(room_node)
	_room_nodes[room.room_id] = room_node


## 创建房间边框
func _create_room_border(room: RoomData) -> Node2D:
	var border = Node2D.new()
	border.name = "Border"

	var w = room.width * TILE_SIZE
	var h = room.height * TILE_SIZE
	var half_w = w / 2
	var half_h = h / 2

	# 创建四面墙的碰撞形状
	var walls = StaticBody2D.new()
	walls.name = "Walls"

	# 上墙
	var top_wall = _create_wall_segment(Vector2(0, -half_h), Vector2(w, 10))
	walls.add_child(top_wall)

	# 下墙
	var bottom_wall = _create_wall_segment(Vector2(0, half_h), Vector2(w, 10))
	walls.add_child(bottom_wall)

	# 左墙
	var left_wall = _create_wall_segment(Vector2(-half_w, 0), Vector2(10, h))
	walls.add_child(left_wall)

	# 右墙
	var right_wall = _create_wall_segment(Vector2(half_w, 0), Vector2(10, h))
	walls.add_child(right_wall)

	border.add_child(walls)
	return border


## 创建墙段
func _create_wall_segment(pos: Vector2, size: Vector2) -> CollisionShape2D:
	var wall = CollisionShape2D.new()
	wall.position = pos
	var shape = RectangleShape2D.new()
	shape.size = size
	wall.shape = shape
	return wall


## 获取房间颜色
func _get_room_color(room_type: String) -> Color:
	match room_type:
		"start":
			return Color(0.2, 0.6, 0.2, 0.8)
		"normal":
			return Color(0.3, 0.3, 0.4, 0.8)
		"treasure":
			return Color(0.8, 0.7, 0.2, 0.8)
		"monster":
			return Color(0.6, 0.2, 0.2, 0.8)
		"boss":
			return Color(0.8, 0.1, 0.1, 0.8)
		"exit":
			return Color(0.2, 0.5, 0.8, 0.8)
		_:
			return Color(0.4, 0.4, 0.5, 0.8)


## 获取当前地图
func get_current_map() -> MapData:
	return _current_map


## 获取房间列表
func get_rooms() -> Array[RoomData]:
	return _rooms


## 获取房间节点
func get_room_node(room_id: int) -> Node2D:
	return _room_nodes.get(room_id)


## 获取房间数量
func get_room_count() -> int:
	return _rooms.size()
