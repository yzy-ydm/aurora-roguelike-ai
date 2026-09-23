## 奖励生成位置系统测试 (TASK-002)
##
## 验证平台感知采样算法:
## 1. RoomRenderer 真实代码路径记录平台矩形
## 2. 奖励房几何: 采样点永不落入平台矩形（碰撞区域检测）
## 3. 地面带被平台完全覆盖时回落平台顶面（Y轴安全偏移 + 最低高度限制）
## 4. 多奖励槽位分布互不重叠
## 5. 旧调用方式（无平台信息）保持地面带行为
##
## 运行方式（无头模式，无需启动游戏）:
##   Godot_v4.7-stable_win64_console.exe --headless --path client --script res://tests/test_reward_spawn_position.gd

extends SceneTree

var _failures: Array[String] = []
var _passed: int = 0

## WorldCoordinate 脚本引用（通过 load 获取，避免依赖全局类缓存）
var _WC: GDScript = load("res://scripts/world/world_coordinate.gd")

## 真实 RoomRenderer 生成的奖励房平台矩形（local 坐标）
var _reward_room_rects: Array[Rect2] = []


func _initialize() -> void:
	_run_tests()


func _run_tests() -> void:
	print("========================================")
	print("  Reward Spawn Position Tests (TASK-002)")
	print("========================================")

	_test_renderer_records_rects()
	_test_reward_room_avoidance()
	_test_fully_blocked_fallback()
	_test_slot_distribution()
	_test_backward_compat()

	# 护栏: 若任一测试函数因运行时错误中断，通过数会少于预期
	const EXPECTED_CHECKS: int = 10
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


## 用真实 room_renderer.gd 代码路径生成奖励房平台并记录矩形
func _build_reward_room_rects() -> Array[Rect2]:
	var renderer_script: GDScript = load("res://scripts/world/room_renderer.gd")
	var renderer: Node = Node.new()
	renderer.set_script(renderer_script)
	var parent := Node2D.new()
	renderer._create_reward_room_platforms(parent)
	var rects: Array[Rect2] = renderer.get_platform_rects()
	# 释放测试桩（未入树的节点需显式 free，避免退出时物理 RID 泄漏告警）
	renderer.free()
	parent.free()
	return rects


## 测试1: RoomRenderer 真实代码路径记录平台矩形
func _test_renderer_records_rects() -> void:
	print("\n--- Test 1: RoomRenderer records platform rects ---")
	_reward_room_rects = _build_reward_room_rects()
	_check(_reward_room_rects.size() == 3, "reward room has 3 platform rects", str(_reward_room_rects.size()))
	var shape_ok: bool = true
	for r in _reward_room_rects:
		if r.size.y != 16.0 or r.size.x <= 0.0:
			shape_ok = false
	_check(shape_ok, "rects have platform shape (thickness 16)", str(_reward_room_rects))


## 测试2: 奖励房几何避让（300 轮种子采样 × 3 槽位 = 900 点全部安全）
func _test_reward_room_avoidance() -> void:
	print("\n--- Test 2: Reward-room geometry avoidance (900 seeded points) ---")
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260923
	var margin: float = _WC.REWARD_COLLISION_RADIUS + _WC.REWARD_PLATFORM_CLEARANCE - 0.1
	var min_y: float = _WC.REWARD_PLATFORM_TOP_MIN_Y - _WC.REWARD_COLLISION_RADIUS - _WC.REWARD_PLATFORM_CLEARANCE - 0.5
	var bad: int = 0
	var bad_detail: String = ""
	for trial in range(300):
		for i in range(3):
			var world: Vector2 = _WC.reward_spawn_pos(Vector2(1240, 0), _reward_room_rects, i, 3, rng)
			var local: Vector2 = world - Vector2(1240, 0)
			# 碰撞区域检测: 不落入任何平台扩边矩形
			for r in _reward_room_rects:
				if r.grow(margin).has_point(local):
					bad += 1
					bad_detail = str(local) + " inside " + str(r)
			# 墙体/房间边界保护
			if absf(local.x) > _WC.HALF_WIDTH - 40.0 or absf(local.y) > _WC.HALF_HEIGHT - 40.0:
				bad += 1
				bad_detail = "out of bounds: " + str(local)
			# 高度可达性: 地面带或可达平台顶面（最低高度限制）
			if local.y < min_y or local.y > float(_WC.GROUND_Y):
				bad += 1
				bad_detail = "unreachable height: " + str(local)
	_check(bad == 0, "900 spawn points never inside platforms / out of reach", bad_detail)


## 测试3: 地面带被平台完全覆盖 → 回落平台顶面（y = 顶面 - 半径 - 间隙）
func _test_fully_blocked_fallback() -> void:
	print("\n--- Test 3: Fully-blocked ground band falls back to platform tops ---")
	# 三个平台矩形覆盖整个地面带 x∈[-400,400]（顶面 y=280，扩边后覆盖 [254.1, 321.9]）
	var blockers: Array[Rect2] = [
		Rect2(-420, 280, 300, 16),
		Rect2(-120, 280, 300, 16),
		Rect2(180, 280, 300, 16),
	]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var expected_y: float = 280.0 - _WC.REWARD_COLLISION_RADIUS - _WC.REWARD_PLATFORM_CLEARANCE
	var margin: float = _WC.REWARD_COLLISION_RADIUS + _WC.REWARD_PLATFORM_CLEARANCE - 0.1
	for i in range(3):
		var world: Vector2 = _WC.reward_spawn_pos(Vector2.ZERO, blockers, i, 3, rng)
		var local: Vector2 = world
		var on_top: bool = absf(local.y - expected_y) < 0.5
		var clear: bool = true
		for r in blockers:
			if r.grow(margin).has_point(local):
				clear = false
		_check(on_top and clear, "slot " + str(i) + " falls back to platform top", str(local))


## 测试4: 无平台时多奖励槽位分布（左→右，全部在地面带）
func _test_slot_distribution() -> void:
	print("\n--- Test 4: Multi-reward slot distribution (no platforms) ---")
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var pts: Array[Vector2] = []
	# 注意: 必须传类型化空数组（Godot 运行时会拒绝非类型化 [] 传给 Array[Rect2] 形参）
	var no_platforms: Array[Rect2] = []
	for i in range(3):
		pts.append(_WC.reward_spawn_pos(Vector2.ZERO, no_platforms, i, 3, rng))
	_check(pts[0].x < pts[1].x and pts[1].x < pts[2].x, "slots ordered left→right", str(pts))
	var band_ok: bool = true
	for p in pts:
		if p.y < 272.0 or p.y > 296.0 or absf(p.x) > _WC.REWARD_GROUND_BAND_X:
			band_ok = false
	_check(band_ok, "all slots in ground band", str(pts))


## 测试5: 旧调用方式（无平台信息）保持地面带行为
func _test_backward_compat() -> void:
	print("\n--- Test 5: Backward compatibility (no platform info) ---")
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var world: Vector2 = _WC.reward_spawn_pos(Vector2(1240, 0))
	var local: Vector2 = world - Vector2(1240, 0)
	_check(local.y >= 272.0 and local.y <= 296.0, "central ground band height", str(local))
	_check(absf(local.x) <= _WC.REWARD_GROUND_BAND_X, "central ground band X range", str(local))
