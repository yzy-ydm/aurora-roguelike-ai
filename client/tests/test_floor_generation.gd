## 楼层生成测试 (TASK-006)
##
## 覆盖"树形→分层DAG地图生成"改造（软锁现场回归）:
## 1. 200 次随机生成，每次 10 项检查:
##    F1 房间数8~13 / F2 START唯一id=0 / F3 BOSS唯一id=最后 / F4 全可达 /
##    F5 Boss可达 / F6 无死胡同(普通房前向出度>=1) / F7 Boss出度=0 /
##    F8 连接合法(无自环/无重复/双向对账/仅相邻层) / F9 validate_floor通过 /
##    F10 遍历模拟(镜像 _create_room_exits 选路策略)必然到达 BOSS
## 2. 统计房间数/层数分布
##
## 运行方式（无头模式，无需启动游戏）:
##   Godot_v4.7-stable_win64_console.exe --headless --path client --script res://tests/test_floor_generation.gd

extends SceneTree

const FLOOR_COUNT: int = 200
const CHECKS_PER_FLOOR: int = 10
const SPACING_X: int = 1240  # floor_generator.ROOM_SPACING_X（层号推算用）

var _failures: Array[String] = []
var _passed: int = 0


func _initialize() -> void:
	_run_tests()


func _run_tests() -> void:
	print("========================================")
	print("  Floor Generation Tests (TASK-006)")
	print("========================================")
	randomize()  # 保证 200 次生成真正随机

	var floor_script: GDScript = load("res://scripts/world/floor_generator.gd")
	var gen: Node = Node.new()
	gen.set_script(floor_script)
	root.add_child(gen)

	var room_dist: Dictionary = {}
	var layer_dist: Dictionary = {}
	for i in range(FLOOR_COUNT):
		var result = _test_floor(gen, i)
		room_dist[result["rooms"]] = room_dist.get(result["rooms"], 0) + 1
		layer_dist[result["layers"]] = layer_dist.get(result["layers"], 0) + 1

	print("\n  Room count distribution: ", room_dist)
	print("  Layer count distribution: ", layer_dist)

	# 护栏: 若测试因运行时错误中断，通过数会少于预期
	# （+1 计入护栏自身；条件在护栏 _check 计数前评估，故比较 _passed + 1）
	const EXPECTED_CHECKS: int = FLOOR_COUNT * CHECKS_PER_FLOOR + 1
	_check(_passed + 1 == EXPECTED_CHECKS,
		"all " + str(EXPECTED_CHECKS) + " checks executed (no runtime aborts)",
		"passed=" + str(_passed))

	print("========================================")
	print("  Results: ", _passed, " passed, ", _failures.size(), " failed")
	for f in _failures:
		print("  FAIL: ", f)
	print("========================================")
	quit(1 if _failures.size() > 0 else 0)


## 单层 10 项检查（静默计数，每层打印一行摘要）
func _test_floor(gen: Node, index: int) -> Dictionary:
	var floor_ok := true
	var rooms = gen.generate_floor(1)
	# 枚举经实例访问（--script 模式下脚本资源上无法直接取枚举）
	var RT = rooms[0].RoomType

	# F1: 房间数 8~13
	var ok1 = rooms.size() >= 8 and rooms.size() <= 13
	floor_ok = _check_quiet(ok1, "F" + str(index) + " room_count in [8,13]", str(rooms.size())) and floor_ok

	# F2: START 恰1个且 id=0
	var ok2 = rooms.size() > 0 and rooms[0].room_type == RT.START and rooms[0].id == 0
	for i in range(1, rooms.size()):
		if rooms[i].room_type == RT.START:
			ok2 = false
	floor_ok = _check_quiet(ok2, "F" + str(index) + " single START at id 0") and floor_ok

	# F3: BOSS 恰1个且 id=最后
	var ok3 = rooms.size() > 0 and rooms[rooms.size() - 1].room_type == RT.BOSS \
		and rooms[rooms.size() - 1].id == rooms.size() - 1
	for i in range(max(0, rooms.size() - 1)):
		if rooms[i].room_type == RT.BOSS:
			ok3 = false
	floor_ok = _check_quiet(ok3, "F" + str(index) + " single BOSS at last id") and floor_ok

	# F4/F5: 从 START 沿前向边 BFS——全部房间可达 + BOSS 可达
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
			if _layer_of(rooms[conn]) == _layer_of(rooms[cur]) + 1:
				queue.append(conn)
	var ok4 = reachable.size() == rooms.size()
	floor_ok = _check_quiet(ok4, "F" + str(index) + " all rooms reachable from START",
		str(reachable.size()) + "/" + str(rooms.size())) and floor_ok
	var ok5 = reachable.has(rooms.size() - 1)
	floor_ok = _check_quiet(ok5, "F" + str(index) + " boss reachable") and floor_ok

	# F6/F7: 无死胡同（普通房前向出度>=1）；Boss 前向出度=0
	var dead_end: Array = []
	var boss_fwd := 0
	for room in rooms:
		var fwd := 0
		for conn in room.connections:
			if conn < 0 or conn >= rooms.size():
				continue
			if _layer_of(rooms[conn]) == _layer_of(room) + 1:
				fwd += 1
		if room.room_type != RT.BOSS and fwd < 1:
			dead_end.append(room.id)
		if room.room_type == RT.BOSS:
			boss_fwd = fwd
	var ok6 = dead_end.size() == 0
	floor_ok = _check_quiet(ok6, "F" + str(index) + " no dead-end room", str(dead_end)) and floor_ok
	var ok7 = boss_fwd == 0
	floor_ok = _check_quiet(ok7, "F" + str(index) + " boss out-degree 0", "fwd=" + str(boss_fwd)) and floor_ok

	# F8: 连接合法性——无自环/无重复/双向对账/仅相邻层（无环/无回边/无跨层）
	var ok8 := true
	for room in rooms:
		var seen: Dictionary = {}
		for conn in room.connections:
			if conn == room.id or conn < 0 or conn >= rooms.size() or seen.has(conn):
				ok8 = false
			elif room.id not in rooms[conn].connections:
				ok8 = false
			elif absi(_layer_of(room) - _layer_of(rooms[conn])) != 1:
				ok8 = false
			else:
				seen[conn] = true
	floor_ok = _check_quiet(ok8, "F" + str(index) + " connections legal (no self/dup/cross-layer, reciprocal)") and floor_ok

	# F9: 生成器自带 validate_floor 通过
	var ok9: bool = gen.validate_floor(rooms)
	floor_ok = _check_quiet(ok9, "F" + str(index) + " validate_floor() == true") and floor_ok

	# F10: 遍历模拟（镜像 _create_room_exits 选路策略）必然到达 BOSS —— 软锁现场回归
	var sim = _simulate_traversal(rooms)
	var ok10: bool = sim["reached_boss"] and not sim["dead_ended"]
	floor_ok = _check_quiet(ok10, "F" + str(index) + " traversal reaches boss",
		"steps=" + str(sim["steps"])) and floor_ok

	var boss_layer = _layer_of(rooms[rooms.size() - 1]) if rooms.size() > 0 else 0
	print("  Floor #", index, ": ", "PASS" if floor_ok else "FAIL",
		" (rooms=", rooms.size(), ", layers=", boss_layer + 1, ")")
	return {"rooms": rooms.size(), "layers": boss_layer + 1}


## 遍历模拟: 镜像 game_scene._create_room_exits 选路策略（TASK-006 软锁现场回归）
## 优先1: 未访问；优先2: 未完成；排除当前房；已完成房不可选
## 旧树形地图下此策略会困死在分支叶子（Room10 现场）；分层DAG下必须一路走到 BOSS
func _simulate_traversal(rooms) -> Dictionary:
	var RT = rooms[0].RoomType  # 枚举经实例访问（--script 模式限制）
	var visited: Dictionary = {0: true}
	var completed: Dictionary = {0: true}  # 起始房进房即完成
	var cur := 0
	var steps := 0
	var reached_boss := false
	var dead_ended := false
	while true:
		if rooms[cur].room_type == RT.BOSS:
			reached_boss = true
			break
		var next := -1
		for conn in rooms[cur].connections:
			if conn == cur:
				continue
			if not visited.has(conn):
				next = conn
				break
		if next == -1:
			for conn in rooms[cur].connections:
				if conn == cur:
					continue
				if not completed.has(conn):
					next = conn
					break
		if next == -1:
			dead_ended = true
			break
		steps += 1
		if steps > rooms.size():
			dead_ended = true  # 步数超出房数：异常循环（理论不可达）
			break
		completed[cur] = true
		visited[next] = true
		cur = next
	return {"reached_boss": reached_boss, "dead_ended": dead_ended, "steps": steps}


## 层号推算（与 floor_generator 校验同一公式: x = 层号 * 1240）
func _layer_of(room) -> int:
	return int(round(room.position.x / float(SPACING_X)))


## 静默检查（仅计数，不逐条打印；每层打印一行摘要）
func _check_quiet(condition: bool, name: String, detail: String = "") -> bool:
	if condition:
		_passed += 1
	else:
		_failures.append(name + ((" | " + detail) if detail != "" else ""))
	return condition


## 响亮检查（元护栏用）
func _check(condition: bool, name: String, detail: String = "") -> void:
	if condition:
		_passed += 1
		print("  ✓ ", name)
	else:
		_failures.append(name + ((" | " + detail) if detail != "" else ""))
