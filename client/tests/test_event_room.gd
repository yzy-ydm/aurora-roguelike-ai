## 事件房流程测试 (TASK-003)
##
## 覆盖"进入事件房崩溃"修复（Godot 4 不存在 set_physics_processing API）:
## 1. 真实 player_controller.gd 的 set_control_enabled():
##    禁用→物理帧+输入关闭、速度清零、冲刺/击退中断；启用→全部恢复
## 2. 真实 game_scene.gd 事件房流程:
##    _show_event_panel → 控制暂停 → _apply_event_choice → 奖励生效 →
##    控制恢复 → HUD状态 → 1.5s后房间完成
##
## 运行方式（无头模式，无需启动游戏）:
##   Godot_v4.7-stable_win64_console.exe --headless --path client --script res://tests/test_event_room.gd

extends SceneTree

var _failures: Array[String] = []
var _passed: int = 0

## 注意: 不能在这里用成员初始化器 load() —— 测试脚本实例化早于 autoload 注册，
## player_controller.gd 引用的 GameStateManager 等全局名尚不存在，会编译失败。
## 必须在测试函数内（autoload 已加载后）再 load。


func _initialize() -> void:
	_run_tests()


func _run_tests() -> void:
	print("========================================")
	print("  Event Room Flow Tests (TASK-003)")
	print("========================================")

	await _test_control_enabled_on_real_player()
	await _test_event_room_flow_real_game_scene()

	# 护栏: 若任一测试函数因运行时错误中断，通过数会少于预期
	const EXPECTED_CHECKS: int = 15
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


## 测试1: 真实 player_controller 的控制开关（不入树，直接调用）
func _test_control_enabled_on_real_player() -> void:
	print("\n--- Test 1: player_controller.set_control_enabled (real script) ---")
	# 此时 autoload 已注册，真实脚本可正常编译
	var player_script: GDScript = load("res://scripts/player/player_controller.gd")
	var player: CharacterBody2D = player_script.new()

	player.set_control_enabled(true)
	_check(player.is_physics_processing(), "physics processing enabled after enable", "")
	_check(player.is_processing_input(), "input processing enabled after enable", "")

	# 模拟移动/冲刺/击退中弹出面板: 禁用后必须全部清零
	player.velocity = Vector2(226, -100)
	player._is_dashing = true
	player._knockback_velocity = Vector2(50, 0)
	player._knockback_timer = 0.1
	player.set_control_enabled(false)
	_check(not player.is_physics_processing(), "physics processing disabled", "")
	_check(not player.is_processing_input(), "input processing disabled", "")
	_check(player.velocity == Vector2.ZERO, "velocity zeroed on disable", str(player.velocity))
	_check(not player._is_dashing, "dash interrupted on disable", "")
	_check(player._knockback_timer == 0.0, "knockback cleared on disable", "")

	player.set_control_enabled(true)
	_check(player.is_physics_processing(), "physics processing restored", "")
	_check(player.is_processing_input(), "input processing restored", "")

	player.free()


## 测试2: 真实 game_scene.gd 事件房流程（桩: 玩家/HUD/楼层管理器）
func _test_event_room_flow_real_game_scene() -> void:
	print("\n--- Test 2: Event room flow via real game_scene.gd ---")
	# 桩玩家: 记录控制开关调用 + 属性变化（game_scene 只调用这些方法）
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

	# 桩HUD（game_scene.hud 类型为 CanvasLayer）
	var hud: CanvasLayer = _compile_script(
		"extends CanvasLayer\n"
		+ "var statuses: Array[String] = []\n"
		+ "func set_status(s: String) -> void: statuses.append(s)\n"
		+ "func update_hud(d: Dictionary) -> void: pass\n").new()
	hud.name = "HUD"
	root.add_child(hud)

	# 桩楼层: 房间完成计数（game_scene 经 _floor_manager._current_floor.complete_current_room() 调用）
	var floor_stub: Node = _compile_script(
		"extends Node\nvar completed_count: int = 0\n"
		+ "func complete_current_room() -> void: completed_count += 1\n").new()
	root.add_child(floor_stub)

	# 真实 NewRoomData（EVENT 房间，枚举值 6）
	var room_script: GDScript = load("res://scripts/models/new_room_data.gd")
	var room = room_script.new(5, 6)  # id=5, RoomType.EVENT

	var fm: Node = _compile_script(
		"extends Node\nvar _current_floor: Node = null\n"
		+ "var current_room: Variant = null\n"
		+ "func get_current_room() -> Variant: return current_room\n").new()
	fm._current_floor = floor_stub
	fm.current_room = room
	root.add_child(fm)

	# 真实 game_scene.gd 子类: 覆盖 _ready 为空，避免完整场景初始化。
	# Godot 4.7 中父类 @onready 仍由 implicit_ready 触发，但目标节点不存在 → 变量保持 null
	# （测试输出中的 "Node not found" 为无害噪音）；注入桩在 ready 之后覆盖这些 null。
	# 注意: game_scene.gd 继承 Node2D，宿主必须是 Node2D
	var gs: Node2D = Node2D.new()
	gs.name = "GameSceneStub"
	gs.set_script(_compile_script(
		"extends \"res://scenes/game/game_scene.gd\"\n\nfunc _ready() -> void:\n\tpass\n"))
	root.add_child(gs)
	await process_frame
	await process_frame

	# 注入桩（在 ready 之后，保证不被 @onready 初始化覆盖）
	gs.player = player
	gs.hud = hud
	gs._floor_manager = fm
	gs._room_renderer = null  # _create_room_exits 直接返回

	var event: Dictionary = {
		"title": "神秘祭坛",
		"choices": [
			{"text": "请教战斗技巧(+3攻击)", "reward": {"attack": 3}, "risk": {}},
		]
	}
	gs._show_event_panel(event, room)

	_check(player.control_log.size() >= 1 and player.control_log[0] == false,
		"control disabled when panel opens", str(player.control_log))
	_check(hud.statuses.has("神秘祭坛"), "hud shows event title", str(hud.statuses))
	_check(player.attack == 13, "event reward applied (+3 attack)", str(player.attack))
	_check(player.control_log.size() >= 2 and player.control_log[1] == true,
		"control restored after choice applied", str(player.control_log))
	_check(hud.statuses.has("事件完成! 请教战斗技巧(+3攻击)"), "hud shows event completion", str(hud.statuses))

	# _apply_event_choice 内部 await 1.5s 后完成房间
	await create_timer(1.8).timeout
	_check(floor_stub.completed_count == 1, "room completed after delay", str(floor_stub.completed_count))

	# 清理
	gs.queue_free()
	player.queue_free()
	hud.queue_free()
	fm.queue_free()
	floor_stub.queue_free()
	await process_frame
	await process_frame
