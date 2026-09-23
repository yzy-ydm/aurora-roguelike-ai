## 房间生命周期状态机测试 (TASK-005)
##
## 覆盖内容:
## 1. transition_to 合法/非法转换（真实 NewRoomData + 真实 FloorData）
## 2. 战斗房完整生命周期: 进入→ENTERING→COMBAT(出怪开战)→清怪→REWARD(生成奖励,无出口)
##    →奖励领取完→COMPLETED→唯一出口
## 3. 奖励房生命周期: 进入→REWARD→奖励拾取完成→COMPLETED→唯一出口
## 4. 事件房生命周期: 进入→EVENT→事件完成(1.5s)→COMPLETED→唯一出口（全程无怪无战斗）
## 5. 重复完成保护: 二次完成不重复建出口；已完成房重复进入不生成内容
##
## 运行方式（无头模式，无需启动游戏）:
##   Godot_v4.7-stable_win64_console.exe --headless --path client --script res://tests/test_room_lifecycle.gd

extends SceneTree

var _failures: Array[String] = []
var _passed: int = 0

# 共享测试环境（在 _test_combat_lifecycle 中构建；T3-T5 复用）
var _new_room_script: GDScript = null
var _content_script: GDScript = null
var _floor_script: GDScript = null
var _gs: Node2D = null
var _fm: Node = null
var _spawner: Node = null
var _combat: Node = null
var _renderer: Node = null
var _player: CharacterBody2D = null
var _hud: CanvasLayer = null


func _initialize() -> void:
	_run_tests()


func _run_tests() -> void:
	print("========================================")
	print("  Room Lifecycle State Machine Tests (TASK-005)")
	print("========================================")

	await _test_transition_legality()
	await _test_combat_lifecycle()
	await _test_reward_lifecycle()
	await _test_event_lifecycle()
	await _test_duplicate_protection()

	# 护栏: 若任一测试函数因运行时错误中断，通过数会少于预期
	const EXPECTED_CHECKS: int = 34
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


func _compile_script(source: String) -> GDScript:
	var gd := GDScript.new()
	gd.source_code = source
	if gd.reload() != OK:
		_failures.append("桩脚本编译失败: " + source)
	return gd


## 测试1: transition_to 合法/非法转换（真实 NewRoomData）
## 状态枚举顺序: ENTERING=0 COMBAT=1 REWARD=2 EVENT=3 COMPLETED=4 EXITING=5
func _test_transition_legality() -> void:
	print("\n--- Test 1: transition_to legality (real NewRoomData) ---")
	# 注意: 不能在成员初始化器里 load（autoload 全局名未注册），函数内 load 即可
	_new_room_script = load("res://scripts/models/new_room_data.gd")

	var r = _new_room_script.new(1, 1)  # COMBAT
	var RS = r.RoomState
	_check(r.state == RS.ENTERING, "T1-1: default state ENTERING", "state=" + str(r.state))

	_check(r.transition_to(RS.COMBAT), "T1-2: ENTERING -> COMBAT legal", "state=" + str(r.state))
	_check(r.transition_to(RS.REWARD), "T1-3: COMBAT -> REWARD legal", "state=" + str(r.state))
	_check(r.transition_to(RS.COMPLETED) and r.is_completed() and r.completed,
		"T1-4: REWARD -> COMPLETED legal + compat snapshot synced", "state=" + str(r.state))

	_check(not r.transition_to(RS.REWARD), "T1-5: COMPLETED is terminal (REWARD rejected)", "state=" + str(r.state))

	var r4 = _new_room_script.new(4, 1)
	r4.transition_to(RS.COMBAT)
	_check(r4.transition_to(RS.COMPLETED), "T1-6: COMBAT -> COMPLETED legal (boss-fail exception path)", "state=" + str(r4.state))

	var r2 = _new_room_script.new(2, 1)
	r2.transition_to(RS.COMBAT)
	_check(not r2.transition_to(RS.EVENT) and r2.state == RS.COMBAT,
		"T1-7: COMBAT -> EVENT rejected, state unchanged", "state=" + str(r2.state))

	var r3 = _new_room_script.new(3, 1)
	_check(r3.transition_to(RS.EXITING) and r3.transition_to(RS.ENTERING) and r3.can_enter(),
		"T1-8: ENTERING -> EXITING -> ENTERING legal, can_enter()", "state=" + str(r3.state))

	_check(not r.can_enter(), "T1-9: completed room can_enter() == false", "state=" + str(r.state))


## 构建共享流程测试环境（真实 game_scene.gd + 桩组件 + 真实 FloorData）
func _setup_flow_env() -> void:
	_content_script = load("res://scripts/models/room_content_data.gd")
	_floor_script = load("res://scripts/models/floor_data.gd")

	# ---- 桩: 玩家（记录控制开关 + 属性变化） ----
	_player = _compile_script(
		"extends CharacterBody2D\n"
		+ "var control_log: Array[bool] = []\n"
		+ "var gold: int = 100\nvar attack: int = 10\nvar max_health: int = 100\nvar health: int = 80\n"
		+ "func set_control_enabled(enabled: bool) -> void: control_log.append(enabled)\n"
		+ "func add_gold(v: int) -> void: gold += v\n"
		+ "func add_attack(v: int) -> void: attack += v\n"
		+ "func add_max_health(v: int) -> void: max_health += v\n"
		+ "func heal(v: int) -> void: health += v\n"
		+ "func take_damage(v: int) -> void: health -= v\n"
		+ "func get_player_data() -> Dictionary: return {\"gold\": gold, \"attack\": attack, \"max_health\": max_health, \"health\": health}\n"
		+ "func set_player_data(d: Dictionary) -> void: pass\n").new()
	_player.name = "Player"
	root.add_child(_player)

	# ---- 桩: HUD ----
	_hud = _compile_script(
		"extends CanvasLayer\n"
		+ "var statuses: Array[String] = []\n"
		+ "func set_status(s: String) -> void: statuses.append(s)\n"
		+ "func update_hud(d: Dictionary) -> void: pass\n"
		+ "func update_floor_info_with_type(level: int, idx: int, name: String) -> void: pass\n"
		+ "func update_combat_status(k: int, t: int) -> void: pass\n").new()
	_hud.name = "HUD"
	root.add_child(_hud)

	# ---- 桩: 房间生成器（记录怪物/奖励生成调用） ----
	_spawner = _compile_script(
		"extends Node\n"
		+ "signal all_rewards_collected\n"
		+ "var spawn_monsters_called: int = 0\n"
		+ "var spawn_rewards_called: int = 0\n"
		+ "func spawn_monsters(content: Variant, room_center: Vector2) -> int:\n"
		+ "	spawn_monsters_called += 1\n"
		+ "	return content.monster_count\n"
		+ "func spawn_rewards(content: Variant, room_center: Vector2) -> void:\n"
		+ "	spawn_rewards_called += 1\n"
		+ "func set_room_center(center: Vector2) -> void: pass\n").new()
	root.add_child(_spawner)

	# ---- 桩: 战斗管理器（complete_reward_phase 发出 room_completed 信号） ----
	_combat = _compile_script(
		"extends Node\n"
		+ "signal room_completed\n"
		+ "var start_combat_called: int = 0\n"
		+ "func reset() -> void: pass\n"
		+ "func start_combat(content: Variant) -> void: start_combat_called += 1\n"
		+ "func is_boss_fight() -> bool: return false\n"
		+ "func get_current_content() -> Variant: return null\n"
		+ "func get_boss_data() -> Variant: return null\n"
		+ "func complete_reward_phase() -> void: room_completed.emit()\n"
		+ "func start_boss_fight(data: Variant) -> void: pass\n").new()
	root.add_child(_combat)

	# ---- 桩: 房间渲染器（记录出口传送门创建） ----
	_renderer = _compile_script(
		"extends Node\n"
		+ "var portal_log: Array[Array] = []\n"
		+ "func create_exit_portal(target_id: int, type_str: String) -> void:\n"
		+ "	portal_log.append([target_id, type_str])\n"
		+ "func show_room_clear_feedback() -> void: pass\n").new()
	root.add_child(_renderer)

	# ---- 桩: 楼层管理器（包裹真实 FloorData，状态转换走真实状态机） ----
	_fm = _compile_script(
		"extends Node\n"
		+ "var _current_floor: Variant = null\n"
		+ "func get_current_room() -> Variant: return _current_floor.get_current_room()\n"
		+ "func get_current_floor() -> Variant: return _current_floor\n"
		+ "func get_available_exit_ids() -> Array[int]: return _current_floor.get_available_exit_ids()\n"
		+ "func get_floor_level() -> int: return 1\n"
		+ "func is_floor_complete() -> bool: return false\n").new()
	root.add_child(_fm)

	# ---- 真实 game_scene.gd 子类 ----
	# Godot 4.7 中父类 @onready 由 implicit_ready 触发，节点缺失报错无害，注入桩在 ready 后覆盖
	_gs = Node2D.new()
	_gs.name = "GameSceneStub"
	_gs.set_script(_compile_script(
		"extends \"res://scenes/game/game_scene.gd\"\n\nfunc _ready() -> void:\n\tpass\n"))
	root.add_child(_gs)
	await process_frame
	await process_frame

	_gs.player = _player
	_gs.hud = _hud
	_gs._floor_manager = _fm
	_gs._room_spawner = _spawner
	_gs._combat_manager = _combat
	_gs._room_renderer = _renderer

	# 真实 game_scene._ready 中的信号连接被测试子类跳过，这里手动连接
	_combat.room_completed.connect(_gs._on_combat_room_completed)


## 构造一个带当前房间与出口目标房间的真实楼层
func _make_floor(current_room: Variant, exit_room: Variant) -> void:
	var floor = _floor_script.new()
	floor.floor_level = 1
	floor.rooms.append(current_room)
	floor.rooms.append(exit_room)
	floor.set_current_room(current_room.id)
	_fm._current_floor = floor


func _reset_flow_counters() -> void:
	_spawner.spawn_monsters_called = 0
	_spawner.spawn_rewards_called = 0
	_combat.start_combat_called = 0
	_renderer.portal_log.clear()


## 测试2: 战斗房完整生命周期
## 进入→ENTERING→COMBAT(出怪开战)→清怪→REWARD(生成奖励,无出口)→奖励领取完→COMPLETED→唯一出口
func _test_combat_lifecycle() -> void:
	print("\n--- Test 2: Combat room full lifecycle ---")
	# 注意: _setup_flow_env 内部有 await，必须 await 调用，
	# 否则桩注入在调用方继续执行之后才完成（T2-T4 会看到 null 桩）
	await _setup_flow_env()

	var room1 = _new_room_script.new(1, 1)  # COMBAT
	room1.room_name = "CombatLifecycle"
	room1.display_index = 1
	room1.position = Vector2(1240, 0)
	var content1 = _content_script.new()
	content1.monster_count = 3
	content1.reward_count = 2
	room1.content = content1

	var exit_room = _new_room_script.new(7, 1)  # COMBAT 出口目标（未访问）
	room1.connections.append(7)
	_make_floor(room1, exit_room)

	# 进入房间
	_gs._on_fm_room_entered(room1)
	var RS = room1.RoomState
	_check(_spawner.spawn_monsters_called == 1, "T2-1: combat room spawns monsters", str(_spawner.spawn_monsters_called))
	_check(_combat.start_combat_called == 1, "T2-2: combat started", str(_combat.start_combat_called))
	_check(room1.state == RS.COMBAT, "T2-3: state == COMBAT after entry", "state=" + str(room1.state))
	_check(_renderer.portal_log.size() == 0, "T2-4: NO portal at room entry", str(_renderer.portal_log))

	# 清怪（怪物全部死亡）
	_gs._on_combat_cleared()
	_check(_spawner.spawn_rewards_called == 1, "T2-5: rewards spawned after clear", str(_spawner.spawn_rewards_called))
	_check(room1.state == RS.REWARD, "T2-6: state == REWARD after clear", "state=" + str(room1.state))
	_check(_renderer.portal_log.size() == 0, "T2-7: still NO portal before rewards collected", str(_renderer.portal_log))

	# 奖励全部领取（complete_reward_phase → room_completed 信号）
	_gs._on_all_rewards_collected()
	_check(room1.state == RS.COMPLETED, "T2-8: state == COMPLETED after rewards collected", "state=" + str(room1.state))
	_check(_renderer.portal_log.size() == 1, "T2-9: exactly ONE exit portal", str(_renderer.portal_log))
	_check(_renderer.portal_log.size() == 1 and _renderer.portal_log[0][0] == 7,
		"T2-10: portal targets room 7", str(_renderer.portal_log))


## 测试3: 奖励房生命周期 进入→REWARD→奖励拾取完成→COMPLETED→唯一出口
func _test_reward_lifecycle() -> void:
	print("\n--- Test 3: Reward room lifecycle ---")
	_reset_flow_counters()

	var room2 = _new_room_script.new(2, 2)  # REWARD
	room2.room_name = "RewardLifecycle"
	room2.display_index = 2
	room2.position = Vector2(1240, 0)
	var content2 = _content_script.new()
	content2.monster_count = 0
	content2.reward_count = 3
	room2.content = content2

	var exit_room = _new_room_script.new(8, 1)  # COMBAT 出口目标（未访问）
	room2.connections.append(8)
	_make_floor(room2, exit_room)

	_gs._on_fm_room_entered(room2)
	var RS = room2.RoomState
	_check(_spawner.spawn_monsters_called == 0, "T3-1: reward room spawns NO monsters", str(_spawner.spawn_monsters_called))
	_check(_combat.start_combat_called == 0, "T3-2: reward room NO combat", str(_combat.start_combat_called))
	_check(_spawner.spawn_rewards_called == 1, "T3-3: rewards spawned", str(_spawner.spawn_rewards_called))
	_check(room2.state == RS.REWARD, "T3-4: state == REWARD after entry", "state=" + str(room2.state))

	_gs._on_reward_room_cleared()
	_check(room2.state == RS.COMPLETED, "T3-5: state == COMPLETED after collected", "state=" + str(room2.state))
	_check(_renderer.portal_log.size() == 1, "T3-6: exactly ONE exit portal", str(_renderer.portal_log))


## 测试4: 事件房生命周期 进入→EVENT→事件完成(1.5s)→COMPLETED→唯一出口（全程无怪无战斗）
func _test_event_lifecycle() -> void:
	print("\n--- Test 4: Event room lifecycle ---")
	_reset_flow_counters()

	var room5 = _new_room_script.new(5, 6)  # EVENT
	room5.room_name = "EventLifecycle"
	room5.display_index = 3
	room5.position = Vector2(1240, 0)
	var content5 = _content_script.new()
	content5.monster_count = 2  # 最坏情况（模拟旧数据/AI注入）
	content5.reward_count = 3
	room5.content = content5

	var exit_room = _new_room_script.new(9, 1)  # COMBAT 出口目标（未访问）
	room5.connections.append(9)
	_make_floor(room5, exit_room)

	_gs._on_fm_room_entered(room5)
	var RS = room5.RoomState
	_check(_spawner.spawn_monsters_called == 0, "T4-1: event room spawns NO monsters", str(_spawner.spawn_monsters_called))
	_check(_combat.start_combat_called == 0, "T4-2: event room NO combat", str(_combat.start_combat_called))
	_check(room5.state == RS.EVENT, "T4-3: state == EVENT after entry", "state=" + str(room5.state))
	_check(_player.control_log.size() >= 1 and _player.control_log[0] == false,
		"T4-4: control disabled (event panel opened)", str(_player.control_log))

	# 事件流程 1.5s 后完成房间并创建传送门
	await create_timer(1.8).timeout
	_check(room5.state == RS.COMPLETED, "T4-5: state == COMPLETED after event", "state=" + str(room5.state))
	_check(_renderer.portal_log.size() == 1, "T4-6: exactly ONE exit portal", str(_renderer.portal_log))


## 测试5: 重复完成保护 + 已完成房重复进入保护（沿用测试4的房间）
func _test_duplicate_protection() -> void:
	print("\n--- Test 5: Duplicate completion & re-enter protection ---")

	# 直接再次调用完成逻辑：状态机终态拦截，不产生第二个出口
	_gs._complete_current_room("duplicate_call")
	_check(_renderer.portal_log.size() == 1, "T5-1: duplicate completion creates NO extra portal", str(_renderer.portal_log))

	# 重复进入已完成房间：入口防护直接拦截，不生成任何内容
	var room5 = _fm.get_current_room()
	_gs._on_fm_room_entered(room5)
	_check(_spawner.spawn_monsters_called == 0, "T5-2: re-enter completed room spawns NO monsters", str(_spawner.spawn_monsters_called))
	_check(_renderer.portal_log.size() == 1, "T5-3: re-enter creates NO new portal", str(_renderer.portal_log))

	# 清理
	_gs.queue_free()
	_player.queue_free()
	_hud.queue_free()
	_spawner.queue_free()
	_combat.queue_free()
	_renderer.queue_free()
	_fm.queue_free()
	await process_frame
	await process_frame
