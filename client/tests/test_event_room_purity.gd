## 事件房纯净性测试 (Phase 18.2)
##
## 覆盖用户报告: Room ID:3 Type:event 但 Finalized room 3 (combat) monsters=3
## 根因: RoomContentData.room_type 取自 AI 响应（可携带错误类型 combat+monsters）
## → 事件房按 combat 规则校验放行怪物。
##
## 修复: 应用层强制 room_type=房间类型 + validate_for_room_type 事件房怪物归零。
##
## 测试: 连续 10 次事件房（随机怪物数量的 AI 内容）→ 全部 monsters=0、无隐藏怪物；
##       combat 房对照不受影响。
##
## 运行方式（无头模式）:
##   Godot_v4.7-stable_win64_console.exe --headless --path client --script res://tests/test_event_room_purity.gd

extends SceneTree

var _failures: Array[String] = []
var _passed: int = 0

const RoomContentDataScript = preload("res://scripts/models/room_content_data.gd")

func _initialize() -> void:
	_run()

func _check(cond: bool, name: String, detail: String = "") -> void:
	if cond:
		_passed += 1
		print("  ✓ ", name)
	else:
		_failures.append(name + ((" | " + detail) if detail != "" else ""))
		print("  ✗ ", name, " | ", detail)

## 模拟 AI 响应解析出的内容（可能携带错误 room_type + monsters）
func _make_ai_content() -> RoomContentData:
	var c = RoomContentDataScript.from_dict({
		"room_id": 3,
		"room_type": "combat",  # AI 返回错误类型（事件房被污染的场景）
		"monsters": [
			{"id": "goblin", "count": randi_range(1, 5), "level": 1},
			{"id": "skeleton", "count": randi_range(0, 3), "level": 1}
		],
		"rewards": {"count": 2, "quality": 1.2}
	})
	return c

func _run() -> void:
	await process_frame

	print("== T1: 连续 10 次事件房——AI 内容怪物全部过滤 ==")
	var all_pure := true
	for i in range(10):
		var content := _make_ai_content()
		# 模拟 floor_manager 应用层修复: room_type 以房间为准
		content.room_type = "event"
		content.validate_for_room_type()
		if content.monster_count != 0:
			all_pure = false
		if content.reward_count < 1:
			all_pure = false  # 事件房奖励应保留
	_check(all_pure, "10 event rooms: monsters=0 every time, rewards preserved")

	print("== T2: 无应用层修复时规则校验兜底也归零 ==")
	var raw := _make_ai_content()
	raw.room_type = "event"  # 假设 AI 正确返回 event 类型
	raw.validate_for_room_type()
	_check(raw.monster_count == 0, "validate zeroes monsters for event rooms", str(raw.monster_count))

	print("== T3: combat 房对照不受影响 ==")
	var combat := _make_ai_content()
	combat.room_type = "combat"
	combat.validate_for_room_type()
	_check(combat.monster_count >= 1, "combat room keeps monsters", str(combat.monster_count))

	print("== T4: 事件房默认内容无怪物（本地生成路径）==")
	var local := RoomContentDataScript.new()
	local.setup_defaults_for_type("event")
	local.validate_for_room_type()
	_check(local.monster_count == 0 and local.event_chance == 1.0,
		"local event content: monsters=0, event_chance=1.0", str(local.monster_count))

	print("")
	print("Results: ", _passed, " passed, ", _failures.size(), " failed")
	for f in _failures:
		print("  FAILED: ", f)
	print("  ✓ all ", _passed + _failures.size(), " checks executed (no runtime aborts)")
	quit(0 if _failures.is_empty() else 1)
