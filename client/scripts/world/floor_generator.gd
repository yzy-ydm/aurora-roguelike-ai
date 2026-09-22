## 层级生成器
##
## 随机生成一层房间结构
## 支持多种房间类型
## Phase 23: 直接生成 NewRoomData，避免旧 RoomNodeData 转换层

extends Node

## 生成配置
const ROOM_WIDTH: int = 1280
const HALF_WIDTH: int = 640
const PORTAL_OFFSET_X: int = HALF_WIDTH - 40  # 传送门距房间中心X距离
const ROOM_SPACING_X: int = PORTAL_OFFSET_X + HALF_WIDTH  # 房间中心间距 = 1240
var _min_rooms: int = 8
var _max_rooms: int = 12
var _branch_chance: float = 0.3  # 分支概率


## 生成一层房间结构 (Phase 23: 返回 NewRoomData)
func generate_floor(floor_level: int = 1) -> Array[NewRoomData]:
	print("[Floor] Generating floor ", floor_level)

	var rooms: Array[NewRoomData] = []
	var room_count = randi_range(_min_rooms, _max_rooms)

	# 创建起始房间
	var start_room = NewRoomData.new(0, NewRoomData.RoomType.START)
	start_room.position = Vector2(0, 0)
	rooms.append(start_room)

	# 创建主路径
	var current_room = start_room
	var main_path_length = randi_range(4, 6)

	for i in range(main_path_length):
		var room_type = _get_random_room_type(floor_level)
		var new_room = NewRoomData.new(rooms.size(), room_type)

		# 计算位置（向右延伸，门对门对齐）
		new_room.position = current_room.position + Vector2(ROOM_SPACING_X, randf_range(-50, 50))

		# 建立连接
		current_room.add_connection(new_room.id)
		new_room.add_connection(current_room.id)

		rooms.append(new_room)
		current_room = new_room

	# 添加分支房间
	var branch_count = room_count - main_path_length - 1
	for i in range(branch_count):
		# 从已有房间中随机选择一个作为分支起点
		var branch_from = rooms[randi() % rooms.size()]

		var room_type = _get_random_room_type(floor_level)
		var new_room = NewRoomData.new(rooms.size(), room_type)

		# 计算位置（从分支起点延伸，X方向一个房间宽）
		var offset = Vector2(
			randf_range(ROOM_SPACING_X * 0.5, ROOM_SPACING_X * 1.5),
			randf_range(-ROOM_SPACING_X * 0.3, ROOM_SPACING_X * 0.3)
		)
		new_room.position = branch_from.position + offset

		# 建立连接
		branch_from.add_connection(new_room.id)
		new_room.add_connection(branch_from.id)

		rooms.append(new_room)

	# 在最后添加Boss房间（紧贴最后一个房间右侧）
	var boss_room = NewRoomData.new(rooms.size(), NewRoomData.RoomType.BOSS)
	boss_room.position = current_room.position + Vector2(ROOM_SPACING_X, 0)

	# 建立连接
	current_room.add_connection(boss_room.id)
	boss_room.add_connection(current_room.id)

	rooms.append(boss_room)

	print("[Floor] Generated ", rooms.size(), " rooms")
	return rooms


## 获取随机房间类型
func _get_random_room_type(floor_level: int) -> NewRoomData.RoomType:
	var rand = randf()

	# 根据楼层调整概率
	if floor_level <= 2:
		# 前期：更多战斗房间
		if rand < 0.6:
			return NewRoomData.RoomType.COMBAT
		elif rand < 0.8:
			return NewRoomData.RoomType.REWARD
		elif rand < 0.9:
			return NewRoomData.RoomType.EVENT
		else:
			return NewRoomData.RoomType.TREASURE
	else:
		# 后期：更多精英和事件
		if rand < 0.4:
			return NewRoomData.RoomType.COMBAT
		elif rand < 0.6:
			return NewRoomData.RoomType.REWARD
		elif rand < 0.7:
			return NewRoomData.RoomType.ELITE
		elif rand < 0.8:
			return NewRoomData.RoomType.EVENT
		elif rand < 0.9:
			return NewRoomData.RoomType.SHOP
		else:
			return NewRoomData.RoomType.TREASURE


## 打印房间图结构
func print_floor_graph(rooms: Array[NewRoomData]) -> void:
	print("[Floor] Floor graph structure:")
	for room in rooms:
		var connections_str = ""
		for conn in room.connections:
			connections_str += str(conn) + " "
		print("  Room ", room.id, " (", room.get_type_string(), ") -> [", connections_str.strip_edges(), "]")


## 获取房间图的字符串表示
func get_floor_graph_string(rooms: Array[NewRoomData]) -> String:
	var result = "Floor Graph:\n"
	for room in rooms:
		var connections_str = ""
		for conn in room.connections:
			connections_str += str(conn) + " "
		result += "  Room " + str(room.id) + " (" + room.get_type_string() + ") -> [" + connections_str.strip_edges() + "]\n"
	return result


## 从AI数据创建房间列表
func create_rooms_from_ai_data(ai_rooms: Array) -> Array[NewRoomData]:
	print("[Floor] Creating rooms from AI data")

	var rooms: Array[NewRoomData] = []

	for room_dict in ai_rooms:
		if room_dict is Dictionary:
			var room_id = room_dict.get("id", -1)
			if room_id < 0:
				continue

			# 解析房间类型
			var type_str = room_dict.get("type", "combat")
			var room_type = _parse_room_type(type_str)

			# 创建房间节点
			var room_node = NewRoomData.new(room_id, room_type)

			# 解析连接
			var connections = room_dict.get("connections", [])
			for conn in connections:
				if conn is int:
					room_node.add_connection(conn)

			# 计算位置
			room_node.position = Vector2(room_id * ROOM_SPACING_X, randf_range(-50, 50))

			rooms.append(room_node)

	print("[Floor] Created ", rooms.size(), " rooms from AI data")
	return rooms


## 解析房间类型字符串
func _parse_room_type(type_str: String) -> NewRoomData.RoomType:
	match type_str:
		"start":
			return NewRoomData.RoomType.START
		"combat":
			return NewRoomData.RoomType.COMBAT
		"reward":
			return NewRoomData.RoomType.REWARD
		"shop":
			return NewRoomData.RoomType.SHOP
		"elite":
			return NewRoomData.RoomType.ELITE
		"boss":
			return NewRoomData.RoomType.BOSS
		"event":
			return NewRoomData.RoomType.EVENT
		"treasure":
			return NewRoomData.RoomType.TREASURE
		_:
			return NewRoomData.RoomType.COMBAT
