## AI 事件房间门控测试 (TASK-027)
##
## 覆盖 START 房禁止 AI 内容、事件仅 EVENT 房触发的门控逻辑:
## 1. START 房: _room_allows_ai_content = false（禁 AI 事件/NPC 对白）
## 2. EVENT 房: 允许 AI 内容且允许 AI 事件
## 3. COMBAT/REWARD 房: 允许 AI 内容（对白）但不允许 AI 事件
##
## 运行方式（无头模式）:
##   Godot_v4.7-stable_win64_console.exe --headless --path client --script res://tests/test_ai_event_gating.gd
##
## 脚手架注意: 枚举经脚本资源访问受限，用 int 构造房间后经实例字段访问

extends SceneTree

var _failures: Array[String] = []
var _passed: int = 0

const NewRoomDataScript = preload("res://scripts/models/new_room_data.gd")

func _initialize() -> void:
	_run()

func _check(cond: bool, name: String, detail: String = "") -> void:
	if cond:
		_passed += 1
		print("  ✓ ", name)
	else:
		_failures.append(name + ((" | " + detail) if detail != "" else ""))
		print("  ✗ ", name, " | ", detail)

func _run() -> void:
	await process_frame

	var fm := Node.new()
	fm.set_script(load("res://scripts/world/floor_manager.gd"))
	# 注意: 不 add_child——_ready 会创建 FloorGenerator/RoomRenderer/RoomSpawner 子节点，
	# 纯门控函数无场景树依赖

	# RoomType: START=0 COMBAT=1 EVENT=6
	var start_room = NewRoomDataScript.new(0, 0)
	var combat_room = NewRoomDataScript.new(1, 1)
	var event_room = NewRoomDataScript.new(2, 6)
	var reward_room = NewRoomDataScript.new(3, 2)

	print("== T1: START 房禁止一切 AI 内容 ==")
	_check(not fm._room_allows_ai_content(start_room),
		"START room: AI event/dialogue blocked")
	_check(not fm._room_allows_ai_event(start_room),
		"START room: AI event blocked")

	print("== T2: EVENT 房允许 AI 事件 ==")
	_check(fm._room_allows_ai_content(event_room), "EVENT room: AI content allowed")
	_check(fm._room_allows_ai_event(event_room), "EVENT room: AI event allowed")

	print("== T3: 非事件房不触发 AI 事件 ==")
	_check(fm._room_allows_ai_content(combat_room), "COMBAT room: AI content allowed (dialogue)")
	_check(not fm._room_allows_ai_event(combat_room), "COMBAT room: AI event blocked")
	_check(fm._room_allows_ai_content(reward_room), "REWARD room: AI content allowed")
	_check(not fm._room_allows_ai_event(reward_room), "REWARD room: AI event blocked")

	print("")
	print("Results: ", _passed, " passed, ", _failures.size(), " failed")
	for f in _failures:
		print("  FAILED: ", f)
	print("  ✓ all ", _passed + _failures.size(), " checks executed (no runtime aborts)")
	quit(0 if _failures.is_empty() else 1)
