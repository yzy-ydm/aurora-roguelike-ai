## 层级生成器
##
## 随机生成一层房间结构
## 支持多种房间类型
## Phase 23: 直接生成 NewRoomData，避免旧 RoomNodeData 转换层
## TASK-006: 树形随机生成改为分层DAG（前向无环图）
##   START → 中间层(4~6层, 每层1~3房) → BOSS(唯一最后一层)
##   保证: start→boss 可达(spine主干) / 普通房前向出度>=1(无死胡同) /
##         Boss出度=0 / 禁止回边/自环/重复连接
##   生成后必须通过 validate_floor() 校验，失败自动重试

extends Node

## 生成配置
const ROOM_WIDTH: int = 1280
const HALF_WIDTH: int = 640
const PORTAL_OFFSET_X: int = HALF_WIDTH - 40  # 传送门距房间中心X距离
const ROOM_SPACING_X: int = PORTAL_OFFSET_X + HALF_WIDTH  # 房间中心间距 = 1240
const MAX_GENERATE_ATTEMPTS: int = 5  # TASK-006: 校验失败重试次数
const MAX_LAYER_ROOMS: int = 3  # 每个中间层最大房数
var _min_rooms: int = 8   # TASK-006: 总房间数下限（含 START 与 BOSS；旧语义为偏置计数+1）
var _max_rooms: int = 13  # TASK-006: 总房间数上限（8~13）
var _branch_chance: float = 0.4  # TASK-006: 房间获得第二条前向边的概率


## 生成一层房间结构 (Phase 23: 返回 NewRoomData)
## TASK-006: 分层DAG结构；生成后必须通过 validate_floor，失败重试（最多 MAX_GENERATE_ATTEMPTS 次）
func generate_floor(floor_level: int = 1) -> Array[NewRoomData]:
	print("[Floor] Generating floor ", floor_level)

	for attempt in range(MAX_GENERATE_ATTEMPTS):
		var rooms: Array[NewRoomData] = _generate_layered_floor(floor_level)
		if validate_floor(rooms):
			print("[Floor] Generated ", rooms.size(), " rooms (layered DAG, validated)")
			return rooms
		print("[FloorValidation] Regenerate attempt ", attempt + 1, "/", MAX_GENERATE_ATTEMPTS)

	# 防御兜底: 构造算法是确定性的、理论上校验必过；此处仅防未知回归
	push_error("[Floor] CRITICAL: floor generation failed validation ", MAX_GENERATE_ATTEMPTS, " times")
	return _generate_layered_floor(floor_level)


## TASK-006: 分层DAG生成
## 结构: START(层0) → 中间层(4~6层) → BOSS(最后一层)
## 连接: 只加前向边(层l→层l+1)；add_connection 双向对账+自动去重
## 步骤: ① 参数 ② 层容量(每层>=1, 中间层<=3) ③ 建房(id按层顺序, x=层号*间距)
##       ④ 连接(spine主干/入边保证/出边保证/可选第二前向边)
func _generate_layered_floor(floor_level: int) -> Array[NewRoomData]:
	# ① 参数
	var total_rooms = randi_range(_min_rooms, _max_rooms)  # 8~13 总房数（含 START 与 BOSS）
	var mid_layer_count = randi_range(4, 6)                # 中间层数 4~6

	# ② 层容量分配: [START层] + [中间层...] + [BOSS层]，每层>=1
	var layer_sizes: Array[int] = [1]
	for _i in range(mid_layer_count):
		layer_sizes.append(1)
	layer_sizes.append(1)
	var remaining = total_rooms - 2 - mid_layer_count
	var guard := 0
	while remaining > 0 and guard < 1000:
		guard += 1
		var li = randi_range(1, mid_layer_count)  # 只给中间层加
		if layer_sizes[li] < MAX_LAYER_ROOMS:
			layer_sizes[li] += 1
			remaining -= 1

	# ③ 建房间: id 按层顺序 0..total-1; x = 层号 * ROOM_SPACING_X（供校验推层号）
	var rooms: Array[NewRoomData] = []
	var layers: Array = []  # 每层的房间id列表
	for layer_idx in range(layer_sizes.size()):
		var layer_ids: Array[int] = []
		for _slot in range(layer_sizes[layer_idx]):
			var id = rooms.size()
			var room_type: NewRoomData.RoomType = NewRoomData.RoomType.COMBAT
			if layer_idx == 0:
				room_type = NewRoomData.RoomType.START
			elif layer_idx == layer_sizes.size() - 1:
				room_type = NewRoomData.RoomType.BOSS
			else:
				room_type = _get_random_room_type(floor_level)
			var room = NewRoomData.new(id, room_type)
			room.position = Vector2(layer_idx * ROOM_SPACING_X, randf_range(-50, 50))
			rooms.append(room)
			layer_ids.append(id)
		layers.append(layer_ids)

	# ④ 连接
	# 4a spine: 每层第0房连下一层第0房 → start→boss 路径由构造保证
	for l in range(layers.size() - 1):
		_connect_forward(rooms, layers[l][0], layers[l + 1][0])

	# 4b 入边保证: layer[l+1] 每个房 >=1 条来自 layer[l] 的边
	for l in range(layers.size() - 1):
		for t_idx in range(1, layers[l + 1].size()):
			var t_id: int = layers[l + 1][t_idx]
			var s_id: int = layers[l][randi() % layers[l].size()]
			_connect_forward(rooms, s_id, t_id)

	# 4c 出边保证: layer[l] 每个房 >=1 条去往 layer[l+1] 的边（无死胡同）
	for l in range(layers.size() - 1):
		for s_id in layers[l]:
			var has_forward = false
			for t_id in layers[l + 1]:
				if rooms[s_id].is_connected_to(t_id):
					has_forward = true
					break
			if not has_forward:
				_connect_forward(rooms, s_id, layers[l + 1][randi() % layers[l + 1].size()])

	# 4d 可选第二前向边: 概率 _branch_chance，连下一层未连接的房
	for l in range(layers.size() - 1):
		if layers[l + 1].size() <= 1:
			continue
		for s_id in layers[l]:
			if randf() >= _branch_chance:
				continue
			var candidates: Array[int] = []
			for t_id in layers[l + 1]:
				if not rooms[s_id].is_connected_to(t_id):
					candidates.append(t_id)
			if candidates.size() > 0:
				_connect_forward(rooms, s_id, candidates[randi() % candidates.size()])

	return rooms


## TASK-006: 前向连接(层l → 层l+1)；双向对账由 add_connection 完成，重复连接自动去重
func _connect_forward(rooms: Array[NewRoomData], from_id: int, to_id: int) -> void:
	rooms[from_id].add_connection(to_id)
	rooms[to_id].add_connection(from_id)


## TASK-006: 楼层结构合法性校验（生成后必查，失败由 generate_floor 重试）
## 检查: V1数量 V2 START/BOSS V3 全可达 V4 Boss可达 V5 无死胡同 V6 Boss出度=0 V7 连接合法
## 层号由 position.x 推算: layer = round(x / ROOM_SPACING_X)（x 恒为精确整数值）
func validate_floor(rooms: Array[NewRoomData]) -> bool:
	var all_ok := true

	# V1: 房间数在范围内
	all_ok = _log_validation("room_count",
		rooms.size() >= _min_rooms and rooms.size() <= _max_rooms,
		str(rooms.size()) + " rooms (expect " + str(_min_rooms) + "~" + str(_max_rooms) + ")") and all_ok

	# V2: START 恰1个且 id=0；BOSS 恰1个且 id=最后
	var start_ok = rooms.size() > 0 and rooms[0].room_type == NewRoomData.RoomType.START and rooms[0].id == 0
	var boss_ok = rooms.size() > 0 and rooms[rooms.size() - 1].room_type == NewRoomData.RoomType.BOSS \
		and rooms[rooms.size() - 1].id == rooms.size() - 1
	var extra_start := 0
	var extra_boss := 0
	for i in range(1, rooms.size()):
		if rooms[i].room_type == NewRoomData.RoomType.START:
			extra_start += 1
	for i in range(max(0, rooms.size() - 1)):
		if rooms[i].room_type == NewRoomData.RoomType.BOSS:
			extra_boss += 1
	all_ok = _log_validation("start_boss",
		start_ok and boss_ok and extra_start == 0 and extra_boss == 0,
		"START id=0, BOSS id=last, no duplicates") and all_ok

	# V3/V4: 从 START 沿前向边 BFS，全部房间可达（含 BOSS）
	var reachable: Dictionary = {}
	var queue: Array = [0]
	while queue.size() > 0:
		var cur: int = queue.pop_front()
		if reachable.has(cur) or cur < 0 or cur >= rooms.size():
			continue
		reachable[cur] = true
		for conn in rooms[cur].connections:
			if conn < 0 or conn >= rooms.size() or reachable.has(conn):
				continue
			# 前向边: 目标层 = 当前层 + 1
			if _get_room_layer(rooms[conn]) == _get_room_layer(rooms[cur]) + 1:
				queue.append(conn)
	var all_reachable = rooms.size() > 0 and reachable.size() == rooms.size()
	all_ok = _log_validation("reachable_from_start", all_reachable,
		str(reachable.size()) + "/" + str(rooms.size()) + " rooms") and all_ok
	var boss_reachable = reachable.has(rooms.size() - 1)
	all_ok = _log_validation("boss_reachable", boss_reachable, "") and all_ok

	# V5/V6: 普通房前向出度>=1（无死胡同）；Boss 前向出度=0
	var dead_end_ids: Array[int] = []
	var boss_forward_ids: Array[int] = []
	for room in rooms:
		var fwd := 0
		for conn in room.connections:
			if conn < 0 or conn >= rooms.size():
				continue
			if _get_room_layer(rooms[conn]) == _get_room_layer(room) + 1:
				fwd += 1
		if room.room_type != NewRoomData.RoomType.BOSS and fwd < 1:
			dead_end_ids.append(room.id)
		if room.room_type == NewRoomData.RoomType.BOSS and fwd > 0:
			boss_forward_ids.append(room.id)
	all_ok = _log_validation("no_dead_end", dead_end_ids.size() == 0,
		"dead-end rooms: " + str(dead_end_ids)) and all_ok
	all_ok = _log_validation("boss_out_degree_zero", boss_forward_ids.size() == 0, "") and all_ok

	# V7: 连接合法性——无自环/无重复/双向对账/仅相邻层（无环/无回边/无跨层）
	var conn_ok := true
	for room in rooms:
		var seen: Dictionary = {}
		for conn in room.connections:
			if conn == room.id:
				conn_ok = false
				print("[FloorValidation] CHECK connections: FAIL | self-loop in room ", room.id)
			elif conn < 0 or conn >= rooms.size():
				conn_ok = false
				print("[FloorValidation] CHECK connections: FAIL | room ", room.id, " invalid target ", conn)
			elif seen.has(conn):
				conn_ok = false
				print("[FloorValidation] CHECK connections: FAIL | room ", room.id, " duplicate connection ", conn)
			else:
				seen[conn] = true
				var layer_gap = absi(_get_room_layer(room) - _get_room_layer(rooms[conn]))
				if layer_gap != 1:
					conn_ok = false
					print("[FloorValidation] CHECK connections: FAIL | room ", room.id, " -> ", conn, " layer gap ", layer_gap)
				elif room.id not in rooms[conn].connections:
					conn_ok = false
					print("[FloorValidation] CHECK connections: FAIL | room ", room.id, " -> ", conn, " not reciprocal")
	all_ok = _log_validation("connections", conn_ok,
		"no self-loop/duplicate/cross-layer; reciprocal") and all_ok

	if all_ok:
		print("[FloorValidation] ALL CHECKS PASSED (", rooms.size(), " rooms)")
	else:
		print("[FloorValidation] FAILED (see CHECK lines above)")
	return all_ok


## TASK-006: 校验日志助手
func _log_validation(check_name: String, passed: bool, detail: String = "") -> bool:
	var suffix := ""
	if detail != "":
		suffix = " | " + detail
	print("[FloorValidation] CHECK ", check_name, ": ", "PASS" if passed else "FAIL", suffix)
	return passed


## TASK-006: 由房间 x 坐标推算层号（生成时 x 恒为 层号 * ROOM_SPACING_X 的精确整数值）
func _get_room_layer(room: NewRoomData) -> int:
	return int(round(room.position.x / ROOM_SPACING_X))


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


## TASK-030: create_rooms_from_ai_data / _parse_room_type 已删除
## AI 不再生成楼层拓扑（唯一调用方 room_graph.gd 已随旧世界系统删除）；
## 楼层结构由 _generate_layered_floor + validate_floor 负责
