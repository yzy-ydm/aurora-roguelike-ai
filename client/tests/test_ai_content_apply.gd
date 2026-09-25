## AI 房间内容预取应用测试 (TASK-030)
##
## 覆盖"AI 结果真正进入游戏"的核心修复: _prefetch_ai_room_content
## 在房间被进入前把 AI 内容写入 room.content（消除 finalize 竞态导致的
## "Generated -> IGNORED"）。
##
## 1. 预取: 相邻未访问房间获得 AI 内容（怪物组合/数量/奖励品质真实写入）
## 2. 不覆盖: 已有内容的房间不被第二次预取覆盖
## 3. 跳过: 已访问/已完成房间不预取
## 4. _ensure_room_content: 已有内容仅做规则校验，不重新生成
##
## 运行方式（无头模式）:
##   Godot_v4.7-stable_win64_console.exe --headless --path client --script res://tests/test_ai_content_apply.gd

extends SceneTree

var _failures: Array[String] = []
var _passed: int = 0

const NewRoomDataScript = preload("res://scripts/models/new_room_data.gd")
const RoomContentDataScript = preload("res://scripts/models/room_content_data.gd")

## 桩 AI 服务: 返回带明确标记的内容
class StubAIContentService extends Node:
	var monster_count_value: int = 5
	var reward_quality_value: float = 2.0
	var calls: int = 0
	func generate_room_content_from_new(room, floor_level: int, player_level: int = 1) -> RoomContentData:
		calls += 1
		var c = RoomContentDataScript.new()
		c.room_id = room.id
		c.room_type = room.get_type_string()
		c.monster_count = monster_count_value
		c.monster_level = floor_level
		c.reward_count = 4
		c.reward_quality = reward_quality_value
		var types: Array[String] = ["skeleton"]
		c.monster_types = types
		return c

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
	var stub := StubAIContentService.new()

	# 房间: 0=START, 1=COMBAT, 2=REWARD（0 连 1 和 2）
	var r0 = NewRoomDataScript.new(0, 0)
	var r1 = NewRoomDataScript.new(1, 1)
	var r2 = NewRoomDataScript.new(2, 2)
	r0.add_connection(1)
	r1.add_connection(0)
	r0.add_connection(2)
	r2.add_connection(0)

	var floor = load("res://scripts/models/floor_data.gd").new()
	floor.floor_level = 1
	floor.rooms.append(r0)
	floor.rooms.append(r1)
	floor.rooms.append(r2)

	fm._current_floor = floor
	fm._ai_content_service = stub

	print("== T1: 预取相邻未访问房间的 AI 内容 ==")
	await fm._prefetch_ai_room_content(r0)
	_check(r1.content != null, "room1 (combat) content prefetched")
	_check(r2.content != null, "room2 (reward) content prefetched")
	if r1.content:
		_check(r1.content.monster_count == 5, "AI monster count applied = 5", str(r1.content.monster_count))
		_check(r1.content.reward_quality == 2.0, "AI reward quality applied = 2.0", str(r1.content.reward_quality))
		_check(r1.content.monster_types.has("skeleton"), "AI monster types applied", str(r1.content.monster_types))
	_check(stub.calls == 2, "AI called once per target room", str(stub.calls))

	print("== T2: 已有内容的房间不被覆盖 ==")
	var local_content = RoomContentDataScript.new()
	local_content.room_type = "combat"
	local_content.monster_count = 2
	local_content.reward_quality = 1.0
	r1.content = local_content
	stub.monster_count_value = 99  # 桩返回值变化
	await fm._prefetch_ai_room_content(r0)
	_check(r1.content == local_content and r1.content.monster_count == 2,
		"room1 content NOT overwritten by second prefetch", str(r1.content.monster_count))
	# 奖励房: AI 奖励品质保留；怪物数被规则校验归零（TASK-004 规则正确生效）
	_check(r2.content != null and r2.content.reward_quality == 2.0 and r2.content.monster_count == 0,
		"room2 unchanged (reward quality kept, monsters zeroed by rule validation)",
		"quality=" + str(r2.content.reward_quality if r2.content else -1.0) + " monsters=" + str(r2.content.monster_count if r2.content else -1))

	print("== T3: 已访问房间跳过预取 ==")
	r2.content = null
	r2.visited = true
	await fm._prefetch_ai_room_content(r0)
	_check(r2.content == null, "visited room not prefetched", str(r2.content))

	print("== T4: _ensure_room_content 已有内容只校验不重生成 ==")
	var before = r1.content
	fm._ensure_room_content(r1)
	_check(r1.content == before, "existing content preserved (validate only)", str(r1.content.monster_count))

	print("")
	print("Results: ", _passed, " passed, ", _failures.size(), " failed")
	for f in _failures:
		print("  FAILED: ", f)
	print("  ✓ all ", _passed + _failures.size(), " checks executed (no runtime aborts)")
	quit(0 if _failures.is_empty() else 1)
