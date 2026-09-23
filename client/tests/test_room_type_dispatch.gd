## 房间类型分发测试 (TASK-004)
##
## 覆盖"事件房错误进入战斗流程"修复:
## 1. 数据层（真实 RoomContentData）:
##    event 房默认内容与规则校验均强制 monsters=0
## 2. 流程层（真实 game_scene.gd 的 _on_fm_room_entered）:
##    - event 房: 即使内容带怪物（模拟AI/旧数据），也不生成怪物、不触发战斗、
##      事件流程完成、出口传送门生成
##    - combat 房回归: 正常生成怪物并进入战斗
##    - reward 房回归: 不生成怪物、正常生成奖励
##
## 运行方式（无头模式，无需启动游戏）:
##   Godot_v4.7-stable_win64_console.exe --headless --path client --script res://tests/test_room_type_dispatch.gd

extends SceneTree

var _failures: Array[String] = []
var _passed: int = 0


func _initialize() -> void:
	_run_tests()


func _run_tests() -> void:
	print("========================================")
	print("  Room Type Dispatch Tests (TASK-004)")
	print("========================================")

	await _test_data_layer_rules()
	await _test_flow_layer_dispatch()

	# 护栏: 若任一测试函数因运行时错误中断，通过数会少于预期
	const EXPECTED_CHECKS: int = 18
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


## 测试1: 数据层规则（真实 RoomContentData）
func _test_data_layer_rules() -> void:
	print("\n--- Test 1: RoomContentData rules (real script) ---")
	# 注意: 不能在成员初始化器里 load（autoload 全局名未注册），函数内 load 即可
	var content_script: GDScript = load("res://scripts/models/room_content_data.gd")

	# 1. event 房默认内容: 不允许生成怪物
	var c_event: RefCounted = content_script.new()
	c_event.setup_defaults_for_type("event")
	_check(c_event.monster_count == 0, "event defaults: monster_count == 0", str(c_event.monster_count))

	# 2. event 房规则校验: AI/随机内容带怪物也被强制归零
	var c_event_ai: RefCounted = content_script.new()
	c_event_ai.room_type = "event"
	c_event_ai.monster_count = 5
	c_event_ai.validate_for_room_type()
	_check(c_event_ai.monster_count == 0, "event validation: monsters forced to 0", str(c_event_ai.monster_count))

	# 3-6. 其他房间类型规则回归
	var c_treasure: RefCounted = content_script.new()
	c_treasure.room_type = "treasure"
	c_treasure.monster_count = 3
	c_treasure.validate_for_room_type()
	_check(c_treasure.monster_count == 0, "treasure validation: monsters == 0", str(c_treasure.monster_count))

	var c_combat: RefCounted = content_script.new()
	c_combat.room_type = "combat"
	c_combat.monster_count = 0
	c_combat.validate_for_room_type()
	_check(c_combat.monster_count >= 1, "combat validation: monsters >= 1 (combat still works)", str(c_combat.monster_count))

	var c_reward: RefCounted = content_script.new()
	c_reward.room_type = "reward"
	c_reward.monster_count = 5
	c_reward.validate_for_room_type()
	_check(c_reward.monster_count == 0, "reward validation: monsters == 0", str(c_reward.monster_count))

	var c_elite: RefCounted = content_script.new()
	c_elite.room_type = "elite"
	c_elite.monster_count = 2
	c_elite.validate_for_room_type()
	_check(c_elite.monster_count >= 1, "elite validation: monsters >= 1", str(c_elite.monster_count))


## 测试2: 流程层分发（真实 game_scene.gd 的 _on_fm_room_entered）
func _test_flow_layer_dispatch() -> void:
	print("\n--- Test 2: _on_fm_room_entered dispatch (real game_scene.gd) ---")
	var new_room_script: GDScript = load("res://scripts/models/new_room_data.gd")
	var content_script: GDScript = load("res://scripts/models/room_content_data.gd")

	# ---- 桩: 玩家（记录控制开关 + 属性变化） ----
	var player: CharacterBody2D = _compile_script(
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
	player.name = "Player"
	root.add_child(player)

	# ---- 桩: HUD ----
	var hud: CanvasLayer = _compile_script(
		"extends CanvasLayer\n"
		+ "var statuses: Array[String] = []\n"
		+ "func set_status(s: String) -> void: statuses.append(s)\n"
		+ "func update_hud(d: Dictionary) -> void: pass\n"
		+ "func update_floor_info_with_type(level: int, idx: int, name: String) -> void: pass\n").new()
	hud.name = "HUD"
	root.add_child(hud)

	# ---- 桩: 房间生成器（记录怪物/奖励生成调用） ----
	var spawner: Node = _compile_script(
		"extends Node\n"
		+ "signal all_rewards_collected\n"
		+ "var spawn_monsters_called: int = 0\n"
		+ "var spawn_rewards_called: int = 0\n"
		+ "var set_room_center_called: int = 0\n"
		+ "func spawn_monsters(content: Variant, room_center: Vector2) -> int:\n"
		+ "	spawn_monsters_called += 1\n"
		+ "	return content.monster_count\n"
		+ "func spawn_rewards(content: Variant, room_center: Vector2) -> void:\n"
		+ "	spawn_rewards_called += 1\n"
		+ "func set_room_center(center: Vector2) -> void:\n"
		+ "	set_room_center_called += 1\n").new()
	root.add_child(spawner)

	# ---- 桩: 战斗管理器（记录 start_combat 调用） ----
	var combat: Node = _compile_script(
		"extends Node\n"
		+ "var start_combat_called: int = 0\n"
		+ "func reset() -> void: pass\n"
		+ "func start_combat(content: Variant) -> void: start_combat_called += 1\n"
		+ "func is_boss_fight() -> bool: return false\n"
		+ "func get_current_content() -> Variant: return null\n"
		+ "func complete_reward_phase() -> void: pass\n").new()
	root.add_child(combat)

	# ---- 桩: 房间渲染器（记录出口传送门创建） ----
	var renderer: Node = _compile_script(
		"extends Node\n"
		+ "var portal_log: Array[Array] = []\n"
		+ "func create_exit_portal(target_id: int, type_str: String) -> void:\n"
		+ "	portal_log.append([target_id, type_str])\n").new()
	root.add_child(renderer)

	# ---- 桩: 楼层数据（房间完成计数） ----
	var floor_stub: Node = _compile_script(
		"extends Node\n"
		+ "var completed_count: int = 0\n"
		+ "var current_room: Variant = null\n"
		+ "var other_room: Variant = null\n"
		+ "func get_current_room() -> Variant: return current_room\n"
		+ "func get_room(id: int) -> Variant: return other_room if id == other_room.id else null\n"
		+ "func complete_current_room() -> void: completed_count += 1\n"
		+ "func set_current_room_state(s: Variant) -> bool: return true\n").new()
	root.add_child(floor_stub)

	# ---- 桩: 楼层管理器 ----
	var fm: Node = _compile_script(
		"extends Node\n"
		+ "var _current_floor: Node = null\n"
		+ "var current_room: Variant = null\n"
		+ "func get_current_room() -> Variant: return current_room\n"
		+ "func get_current_floor() -> Variant: return _current_floor\n"
		+ "func get_available_exit_ids() -> Array[int]: return [7]\n"
		+ "func get_floor_level() -> int: return 1\n").new()
	fm._current_floor = floor_stub
	root.add_child(fm)

	# ---- 真实 game_scene.gd 子类 ----
	# Godot 4.7 中父类 @onready 由 implicit_ready 触发，节点缺失报错无害，注入桩在 ready 后覆盖
	var gs: Node2D = Node2D.new()
	gs.name = "GameSceneStub"
	gs.set_script(_compile_script(
		"extends \"res://scenes/game/game_scene.gd\"\n\nfunc _ready() -> void:\n\tpass\n"))
	root.add_child(gs)
	await process_frame
	await process_frame

	gs.player = player
	gs.hud = hud
	gs._floor_manager = fm
	gs._room_spawner = spawner
	gs._combat_manager = combat
	gs._room_renderer = renderer

	# 备用的出口目标房间（未访问）
	var other_room = new_room_script.new(7, 1)  # COMBAT
	other_room.room_name = "OtherCombat"
	floor_stub.other_room = other_room

	# ========== B1: 事件房（内容带怪物 —— 最坏情况） ==========
	print("\n--- B1: EVENT room with monster content ---")
	var event_room = new_room_script.new(5, 6)  # EVENT
	event_room.room_name = "EventTest"
	event_room.display_index = 3
	event_room.position = Vector2(1240, 0)
	var event_content = content_script.new()
	event_content.monster_count = 2  # 模拟AI/旧数据带怪物，绕过校验
	event_content.reward_count = 3
	event_room.content = event_content
	fm.current_room = event_room
	floor_stub.current_room = event_room

	gs._on_fm_room_entered(event_room)

	_check(spawner.spawn_monsters_called == 0, "event room: no monsters spawned", str(spawner.spawn_monsters_called))
	_check(combat.start_combat_called == 0, "event room: combat NOT started", str(combat.start_combat_called))
	_check(player.control_log.size() >= 1 and player.control_log[0] == false,
		"event room: control disabled (panel opened)", str(player.control_log))
	_check(player.control_log.size() >= 2 and player.control_log[1] == true,
		"event room: control restored after choice", str(player.control_log))

	# 事件流程 1.5s 后完成房间并创建传送门
	await create_timer(1.8).timeout
	_check(floor_stub.completed_count == 1, "event room: flow completed", str(floor_stub.completed_count))
	_check(renderer.portal_log.size() == 1, "event room: portal generated", str(renderer.portal_log))
	_check(renderer.portal_log.size() == 1 and renderer.portal_log[0][0] == 7,
		"event room: portal targets room 7", str(renderer.portal_log))

	# ========== B2: 战斗房（回归 —— 正常战斗） ==========
	print("\n--- B2: COMBAT room (regression) ---")
	spawner.spawn_monsters_called = 0
	combat.start_combat_called = 0
	renderer.portal_log.clear()
	var combat_room = new_room_script.new(1, 1)  # COMBAT
	combat_room.room_name = "CombatTest"
	combat_room.display_index = 1
	combat_room.position = Vector2(1240, 0)
	var combat_content = content_script.new()
	combat_content.monster_count = 3
	combat_content.reward_count = 2
	combat_room.content = combat_content
	fm.current_room = combat_room
	floor_stub.current_room = combat_room

	gs._on_fm_room_entered(combat_room)

	_check(spawner.spawn_monsters_called == 1, "combat room: monsters spawned", str(spawner.spawn_monsters_called))
	_check(combat.start_combat_called == 1, "combat room: combat started", str(combat.start_combat_called))

	# ========== B3: 奖励房（回归 —— 无怪物、有奖励） ==========
	print("\n--- B3: REWARD room (regression) ---")
	spawner.spawn_monsters_called = 0
	combat.start_combat_called = 0
	renderer.portal_log.clear()
	var reward_room = new_room_script.new(2, 2)  # REWARD
	reward_room.room_name = "RewardTest"
	reward_room.display_index = 2
	reward_room.position = Vector2(1240, 0)
	var reward_content = content_script.new()
	reward_content.monster_count = 0
	reward_content.reward_count = 3
	reward_room.content = reward_content
	fm.current_room = reward_room
	floor_stub.current_room = reward_room

	gs._on_fm_room_entered(reward_room)

	_check(spawner.spawn_monsters_called == 0, "reward room: no monsters spawned", str(spawner.spawn_monsters_called))
	_check(combat.start_combat_called == 0, "reward room: combat NOT started", str(combat.start_combat_called))
	_check(spawner.spawn_rewards_called == 1, "reward room: rewards spawned", str(spawner.spawn_rewards_called))

	# 清理
	gs.queue_free()
	player.queue_free()
	hud.queue_free()
	spawner.queue_free()
	combat.queue_free()
	renderer.queue_free()
	floor_stub.queue_free()
	fm.queue_free()
	await process_frame
	await process_frame
