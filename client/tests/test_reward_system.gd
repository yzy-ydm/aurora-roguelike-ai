## 奖励系统回归测试 (TASK-001)
##
## 覆盖 B-01 修复的三个层面:
## 1. 生成位置正确: 奖励出生在地面附近（非房间中心高度），浮动动画不漂移
## 2. 拾取可用: 玩家碰撞拾取触发 body_entered → _collect → 节点销毁
## 3. 信号链完整: RoomSpawner 收集回调精确移除节点 → all_rewards_collected 恰好触发
##
## 运行方式（无头模式，无需启动游戏）:
##   Godot_v4.7-stable_win64_console.exe --headless --path client --script res://tests/test_reward_system.gd
##
## 说明: 本测试用真实物理引擎 + 真实 reward_item.tscn / room_spawner.gd，
## 通过桩节点模拟 GameScene→FloorManager→RoomRenderer 的场景树查找链。

extends SceneTree

## 失败记录
var _failures: Array[String] = []
var _passed: int = 0

## 测试桩引用
var _reward_container: Node2D = null
var _monster_container: Node2D = null
var _spawner: Node = null

## 信号计数
var _collected_count: int = 0
var _all_collected_count: int = 0

## 模拟"非原点房间"的世界偏移（真实楼层中第2间房位置≈(1240, 0)）
const ROOM_OFFSET := Vector2(1240, 0)
## 奖励出生 local 坐标（与 WorldCoordinate.reward_spawn_pos 一致: 地面以上40px）
const REWARD_LOCAL_POS := Vector2(0, 288)


func _initialize() -> void:
	_build_stubs()
	_run_tests()


## 构建桩: GameScene → FloorManager → RoomRenderer（RoomSpawner 依赖此查找链）
func _build_stubs() -> void:
	var game_scene := Node.new()
	game_scene.name = "GameScene"
	root.add_child(game_scene)

	var floor_manager := Node.new()
	floor_manager.name = "FloorManager"
	floor_manager.set_script(_compile_script(
		"extends Node\nvar renderer: Node\nfunc get_room_renderer() -> Node: return renderer\n"))
	game_scene.add_child(floor_manager)

	var renderer := Node.new()
	renderer.name = "RoomRenderer"
	renderer.set_script(_compile_script(
		"extends Node\nvar rc: Node2D\nvar mc: Node2D\n"
		+ "func get_reward_container() -> Node2D: return rc\n"
		+ "func get_monster_container() -> Node2D: return mc\n"))
	floor_manager.add_child(renderer)

	# 房间容器（模拟 Room_N 子树，位于世界偏移处）
	var room_container := Node2D.new()
	room_container.name = "Room_1"
	room_container.position = ROOM_OFFSET
	root.add_child(room_container)

	_reward_container = Node2D.new()
	_reward_container.name = "RewardContainer"
	room_container.add_child(_reward_container)
	_monster_container = Node2D.new()
	_monster_container.name = "MonsterContainer"
	room_container.add_child(_monster_container)

	renderer.rc = _reward_container
	renderer.mc = _monster_container
	floor_manager.renderer = renderer

	# 真实的 RoomSpawner
	_spawner = Node.new()
	_spawner.name = "RoomSpawner"
	_spawner.set_script(load("res://scripts/world/room_spawner.gd"))
	root.add_child(_spawner)
	_spawner.reward_collected.connect(func(_data: RewardData) -> void: _collected_count += 1)
	_spawner.all_rewards_collected.connect(func() -> void: _all_collected_count += 1)


func _compile_script(source: String) -> GDScript:
	var gd := GDScript.new()
	gd.source_code = source
	if gd.reload() != OK:
		_failures.append("桩脚本编译失败: " + source)
	return gd


## 测试主流程
func _run_tests() -> void:
	print("========================================")
	print("  Reward System Regression Tests")
	print("========================================")

	await _test_spawn_position()
	await _test_float_stability()
	await _test_pickup()
	await _test_signal_chain()

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


## 测试1: 生成位置正确（复用 _spawn_single_reward 的调用顺序）
func _test_spawn_position() -> void:
	print("\n--- Test 1: Spawn Position ---")
	var reward_scene = load("res://scenes/drop/reward_item.tscn")
	var reward_data_script = load("res://scripts/models/reward_data.gd")
	var reward = reward_scene.instantiate()

	# 与 room_spawner._spawn_single_reward 完全一致的调用顺序:
	# set_reward_data → set_spawn_position → add_child
	reward.set_reward_data(reward_data_script.generate_random_reward(0))
	reward.set_spawn_position(REWARD_LOCAL_POS)
	_reward_container.add_child(reward)

	for i in range(10):
		await physics_frame

	var expected_world := ROOM_OFFSET + REWARD_LOCAL_POS
	_check(reward.position.distance_to(REWARD_LOCAL_POS) < 6.0,
		"local position stays at spawn point", "pos=" + str(reward.position))
	_check(reward.global_position.distance_to(expected_world) < 6.0,
		"global position equals room offset + local pos", "global=" + str(reward.global_position))

	# 清理（直接释放，不影响后续测试）
	reward.queue_free()
	for i in range(2):
		await physics_frame


## 测试2: 浮动动画稳定（30帧内不漂移出 ±6px 范围）
func _test_float_stability() -> void:
	print("\n--- Test 2: Float Animation Stability ---")
	var reward_scene = load("res://scenes/drop/reward_item.tscn")
	var reward_data_script = load("res://scripts/models/reward_data.gd")
	var reward = reward_scene.instantiate()
	reward.set_reward_data(reward_data_script.generate_random_reward(0))
	reward.set_spawn_position(REWARD_LOCAL_POS)
	_reward_container.add_child(reward)

	var max_deviation := 0.0
	for i in range(30):
		await physics_frame
		max_deviation = maxf(max_deviation, absf(reward.position.y - REWARD_LOCAL_POS.y))

	_check(max_deviation <= 6.0,
		"float animation stays within ±6px of spawn height", "max_dev=" + str(max_deviation))
	_check(absf(reward.position.x - REWARD_LOCAL_POS.x) < 0.1,
		"float animation does not move X axis", "x=" + str(reward.position.x))

	reward.queue_free()
	for i in range(2):
		await physics_frame


## 测试3: 物理拾取（玩家碰撞 → body_entered → _collect）
func _test_pickup() -> void:
	print("\n--- Test 3: Physical Pickup ---")
	var reward_scene = load("res://scenes/drop/reward_item.tscn")
	var reward_data_script = load("res://scripts/models/reward_data.gd")
	var reward = reward_scene.instantiate()
	reward.set_reward_data(reward_data_script.generate_random_reward(0))
	reward.set_spawn_position(Vector2(100, REWARD_LOCAL_POS.y))
	_reward_container.add_child(reward)

	var player := CharacterBody2D.new()
	player.name = "Player"
	player.collision_layer = 2   # 与真实玩家一致
	player.collision_mask = 23   # 与真实玩家一致
	var shape_node := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(40, 80)
	shape_node.shape = shape
	player.add_child(shape_node)
	player.position = ROOM_OFFSET + Vector2(-200, REWARD_LOCAL_POS.y)
	root.add_child(player)

	for i in range(3):
		await physics_frame

	# 传送到奖励位置，模拟玩家走过
	player.position = ROOM_OFFSET + Vector2(100, REWARD_LOCAL_POS.y)
	for i in range(5):
		await physics_frame

	_check(reward.is_collected(), "reward collected via physics overlap", "")

	# 等待收集动画结束（queue_free）
	for i in range(40):
		await physics_frame
	_check(not is_instance_valid(reward) or reward.is_queued_for_deletion(),
		"reward node freed after collect animation", "")

	player.queue_free()
	for i in range(2):
		await physics_frame


## 测试4: RoomSpawner 信号链（收集全部奖励 → all_rewards_collected 恰好一次）
func _test_signal_chain() -> void:
	print("\n--- Test 4: RoomSpawner Signal Chain ---")
	var reward_data_script = load("res://scripts/models/reward_data.gd")

	# 通过公开 API 生成两个奖励（房间内 local 坐标）
	_spawner.spawn_reward(reward_data_script.generate_random_reward(0), Vector2(100, REWARD_LOCAL_POS.y))
	_spawner.spawn_reward(reward_data_script.generate_random_reward(1), Vector2(-100, REWARD_LOCAL_POS.y))
	_check(_spawner.get_reward_count() == 2, "two rewards registered in spawner", str(_spawner.get_reward_count()))

	var player := CharacterBody2D.new()
	player.name = "Player"
	player.collision_layer = 2
	player.collision_mask = 23
	var shape_node := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(40, 80)
	shape_node.shape = shape
	player.add_child(shape_node)
	player.position = ROOM_OFFSET + Vector2(-500, REWARD_LOCAL_POS.y)
	root.add_child(player)

	for i in range(3):
		await physics_frame

	# 收集第一个奖励
	player.position = ROOM_OFFSET + Vector2(100, REWARD_LOCAL_POS.y)
	for i in range(5):
		await physics_frame
	_check(_collected_count == 1, "first reward collected", str(_collected_count))
	_check(_all_collected_count == 0, "not all collected yet", str(_all_collected_count))

	# 收集第二个奖励
	player.position = ROOM_OFFSET + Vector2(-100, REWARD_LOCAL_POS.y)
	for i in range(5):
		await physics_frame
	_check(_collected_count == 2, "second reward collected", str(_collected_count))
	_check(_all_collected_count == 1, "all_rewards_collected emitted exactly once", str(_all_collected_count))
	_check(_spawner.get_reward_count() == 0, "reward list cleared after collection", str(_spawner.get_reward_count()))

	player.queue_free()
	for i in range(2):
		await physics_frame
