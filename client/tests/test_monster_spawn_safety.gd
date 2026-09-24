## 怪物出生点平台感知安全测试 (TASK-017.8, TASK-018.0)
##
## 验证 monster_spawn_pos 的平台避让三级采样:
## 1. combat 房: 2/3/4 怪出生点全部避开真实平台矩形
## 2. elite 房: 1/2 怪出生点全部避开真实平台矩形
## 3. boss 房: Boss 出生点避开真实平台矩形
## 4. 多怪: 同轮生成点两两不重合（第二层扫描按 index 错开相位）
## 5. 向后兼容: 不传 platform_rects 时保持旧槽位行为
## 6. TASK-018.0: 出生点 x ∈ [-330, 550]，绝不进入玩家出生点(-540)附近贴脸区
##
## 运行方式（无头模式，无需启动游戏）:
##   Godot_v4.7-stable_win64_console.exe --headless --path client --script res://tests/test_monster_spawn_safety.gd

extends SceneTree

var _failures: Array[String] = []
var _passed: int = 0

## WorldCoordinate 脚本引用（通过 load 获取，避免依赖全局类缓存）
var _WC: GDScript = load("res://scripts/world/world_coordinate.gd")

## 第1战斗房房间中心（世界坐标）
const ROOM_CENTER := Vector2(1240.0, 0.0)

## 与生产一致的判定容差: 怪物半宽14 + 安全间距4 - 浮点容差0.1
const CLEAR_MARGIN: float = 14.0 + 4.0 - 0.1


func _initialize() -> void:
	_run_tests()


func _run_tests() -> void:
	print("========================================")
	print("  Monster Spawn Safety Tests (TASK-017.8)")
	print("========================================")

	_test_combat_room_avoidance()
	_test_elite_room_avoidance()
	_test_boss_room_avoidance()
	_test_multi_monster_no_overlap()
	_test_backward_compat()

	# 护栏: 若任一测试函数因运行时错误中断，通过数会少于预期
	const EXPECTED_CHECKS: int = 12
	_check(_passed == EXPECTED_CHECKS,
		"all " + str(EXPECTED_CHECKS) + " checks executed (no runtime aborts)",
		"passed=" + str(_passed))

	print("========================================")
	print("  Results: ", _passed, " passed, ", _failures.size(), " failed")
	for f in _failures:
		print("  FAIL: ", f)
	print("========================================")
	quit(1 if _failures.size() > 0 else 0)


func _check(condition: bool, name: String, detail: String = "") -> void:
	if condition:
		_passed += 1
		print("  ✓ ", name)
	else:
		_failures.append(name + ((" | " + detail) if detail != "" else ""))


## 用真实 room_renderer.gd 代码路径生成指定房间类型的平台矩形（local 坐标，position=左上角）
func _build_platform_rects(method_suffix: String) -> Array[Rect2]:
	var renderer_script: GDScript = load("res://scripts/world/room_renderer.gd")
	var renderer: Node = Node.new()
	renderer.set_script(renderer_script)
	var parent := Node2D.new()
	renderer.call("_create_" + method_suffix + "_platforms", parent)
	var rects: Array[Rect2] = renderer.get_platform_rects()
	# 释放测试桩（未入树的节点需显式 free，避免退出时物理 RID 泄漏告警）
	renderer.free()
	parent.free()
	return rects


## 与生产 _monster_pos_clear 一致的判定（矩形向外扩大安全边距后包含该点 → 不安全）
func _is_clear(local_pos: Vector2, rects: Array[Rect2]) -> bool:
	for r in rects:
		if r.grow(CLEAR_MARGIN).has_point(local_pos):
			return false
	return true


## 采样一轮（total 只怪），返回该轮是否全部安全且 y 恒为地面高度
func _sample_round(total: int, rects: Array[Rect2], use_platforms: bool = true) -> bool:
	for i in range(total):
		var world_pos: Vector2
		if use_platforms:
			world_pos = _WC.monster_spawn_pos(ROOM_CENTER, i, total, rects)
		else:
			world_pos = _WC.monster_spawn_pos(ROOM_CENTER, i, total)
		var local_pos: Vector2 = world_pos - ROOM_CENTER
		if use_platforms and not _is_clear(local_pos, rects):
			return false
		# TASK-018.0: 平台感知路径出生点必须远离玩家出生区（x=-540），x ∈ [-330, 550]
		if use_platforms and (local_pos.x < -330.0 or local_pos.x > 550.0):
			return false
		if not is_equal_approx(local_pos.y, 282.0):
			return false
	return true


## 测试1: combat 房平台避让（真实平台矩形，2/3/4 怪各 20 轮）
func _test_combat_room_avoidance() -> void:
	print("\n--- Test 1: Combat room avoidance (real platform rects) ---")
	var rects := _build_platform_rects("combat_room")
	_check(rects.size() == 3, "combat room has 3 platform rects", str(rects.size()))
	for total in [2, 3, 4]:
		var fail_rounds := 0
		for round_idx in range(20):
			if not _sample_round(total, rects):
				fail_rounds += 1
		_check(fail_rounds == 0,
			"combat total=" + str(total) + ": all 20 rounds clear of platforms",
			str(fail_rounds) + " failed rounds")


## 测试2: elite 房平台避让（真实平台矩形，1/2 怪各 20 轮）
func _test_elite_room_avoidance() -> void:
	print("\n--- Test 2: Elite room avoidance (real platform rects) ---")
	var rects := _build_platform_rects("elite_room")
	_check(rects.size() == 4, "elite room has 4 platform rects", str(rects.size()))
	for total in [1, 2]:
		var fail_rounds := 0
		for round_idx in range(20):
			if not _sample_round(total, rects):
				fail_rounds += 1
		_check(fail_rounds == 0,
			"elite total=" + str(total) + ": all 20 rounds clear of platforms",
			str(fail_rounds) + " failed rounds")


## 测试3: boss 房平台避让（真实平台矩形，Boss 单怪 20 轮）
func _test_boss_room_avoidance() -> void:
	print("\n--- Test 3: Boss room avoidance (real platform rects) ---")
	var rects := _build_platform_rects("boss_room")
	_check(rects.size() == 3, "boss room has 3 platform rects", str(rects.size()))
	var fail_rounds := 0
	for round_idx in range(20):
		if not _sample_round(1, rects):
			fail_rounds += 1
	_check(fail_rounds == 0,
		"boss spawn: all 20 rounds clear of platforms",
		str(fail_rounds) + " failed rounds")


## 测试4: 多怪同轮生成点两两不重合（第二层扫描按 index 错开相位）
func _test_multi_monster_no_overlap() -> void:
	print("\n--- Test 4: Multi-monster no overlap ---")
	var rects := _build_platform_rects("combat_room")
	var fail_rounds := 0
	for round_idx in range(20):
		var xs: Array[float] = []
		for i in range(4):
			var world_pos: Vector2 = _WC.monster_spawn_pos(ROOM_CENTER, i, 4, rects)
			xs.append((world_pos - ROOM_CENTER).x)
		var unique := true
		for a in range(xs.size()):
			for b in range(a + 1, xs.size()):
				if absf(xs[a] - xs[b]) < 1.0:
					unique = false
		if not unique:
			fail_rounds += 1
	_check(fail_rounds == 0,
		"total=4: all 20 rounds have distinct spawn x",
		str(fail_rounds) + " failed rounds")


## 测试5: 向后兼容——不传 platform_rects 保持旧槽位行为
func _test_backward_compat() -> void:
	print("\n--- Test 5: Backward compat (no platform_rects argument) ---")
	# total=1: 旧逻辑 x ∈ [-400,-200] ∪ [200,400]
	var fail_rounds := 0
	for round_idx in range(20):
		var world_pos: Vector2 = _WC.monster_spawn_pos(ROOM_CENTER, 0, 1)
		var local_pos: Vector2 = world_pos - ROOM_CENTER
		if absf(local_pos.x) < 200.0 or absf(local_pos.x) > 400.0:
			fail_rounds += 1
		if not is_equal_approx(local_pos.y, 282.0):
			fail_rounds += 1
	_check(fail_rounds == 0,
		"total=1 legacy range x in [200,400] abs, y=282", str(fail_rounds) + " failed rounds")

	# total=3: 旧逻辑槽位 -150/0/150 ±30 → x ∈ [-180,180]
	fail_rounds = 0
	for round_idx in range(20):
		for i in range(3):
			var world_pos: Vector2 = _WC.monster_spawn_pos(ROOM_CENTER, i, 3)
			var local_pos: Vector2 = world_pos - ROOM_CENTER
			if absf(local_pos.x) > 180.0:
				fail_rounds += 1
	_check(fail_rounds == 0,
		"total=3 legacy range x in [-180,180]", str(fail_rounds) + " failed points")
