## 房间怪物选择过滤测试 (TASK-027)
##
## 覆盖怪物选择的房间类型约束与楼层范围过滤:
## 1. combat 房: 只出 normal 型怪物（Boss/精英永不泄漏）
## 2. combat 房 floor1: 属性钳制在 normal 范围 HP 50-150 / ATK 5-15
## 3. elite 房: 只出 elite 型
## 4. boss 房: 只出 boss 型
## 5. min_floor 过滤: 高楼层怪不在低楼层出现（无匹配时回退仅类型约束）
## 6. AI 指定类型: 在过滤后的集合内优先匹配
##
## 运行方式（无头模式）:
##   Godot_v4.7-stable_win64_console.exe --headless --path client --script res://tests/test_monster_selection.gd

extends SceneTree

var _failures: Array[String] = []
var _passed: int = 0

const MonsterDataScript = preload("res://scripts/models/monster_data.gd")
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

func _make_monster(mid: int, mname: String, mtype: String, min_f: int) -> MonsterData:
	var m := MonsterDataScript.new()
	m.id = mid
	m.name = mname
	m.type = mtype
	m.min_floor = min_f
	m.max_floor = 999
	return m

func _make_content(room_type: String, level: int) -> RoomContentData:
	var c := RoomContentDataScript.new()
	c.room_type = room_type
	c.monster_level = level
	c.monster_count = 3
	return c

func _run() -> void:
	await process_frame

	# 构造房间生成器节点（仅调用选择逻辑，无场景树依赖）
	var spawner := Node.new()
	spawner.set_script(load("res://scripts/world/room_spawner.gd"))

	var monsters: Array[MonsterData] = [
		_make_monster(1, "史莱姆", "normal", 1),
		_make_monster(2, "骷髅战士", "normal", 1),
		_make_monster(3, "巨魔", "normal", 5),       # 高层普通怪
		_make_monster(4, "精英卫兵", "elite", 3),
		_make_monster(5, "混沌领主", "boss", 30),    # 第一层泄漏根因案例
	]

	print("== T1: combat 房 floor1 只出 normal 且数值在范围内 ==")
	var combat := _make_content("combat", 1)
	var all_normal := true
	var all_in_range := true
	for i in range(40):
		var picked: MonsterData = spawner._get_monster_by_config(monsters, combat)
		if picked.type != "normal":
			all_normal = false
		# TASK-028: 第一层目标区间 HP 80-150 / ATK 10-20
		if picked.health < 80 or picked.health > 150 or picked.attack < 10 or picked.attack > 20:
			all_in_range = false
	_check(all_normal, "combat room 40 picks: all normal type (no boss/elite leak)")
	_check(all_in_range, "combat floor1 stats clamped: HP 80-150 / ATK 10-20 (TASK-028)")

	print("== T2: combat 房 floor1 高层怪被 min_floor 过滤 ==")
	var saw_high := false
	for i in range(30):
		var picked: MonsterData = spawner._get_monster_by_config(monsters, combat)
		if picked.name == "巨魔":
			saw_high = true
	_check(not saw_high, "floor1 combat never picks min_floor=5 monster (巨魔)")

	print("== T3: elite 房只出 elite（楼层不足时回退仅类型约束）==")
	var elite := _make_content("elite", 2)  # floor2 低于精英卫兵 min_floor=3 → 回退路径
	var all_elite := true
	for i in range(30):
		var picked: MonsterData = spawner._get_monster_by_config(monsters, elite)
		if picked.type != "elite":
			all_elite = false
	_check(all_elite, "elite room 30 picks: all elite (fallback keeps type constraint)")

	print("== T4: boss 房只出 boss ==")
	var boss_room := _make_content("boss", 1)
	var all_boss := true
	for i in range(20):
		var picked: MonsterData = spawner._get_monster_by_config(monsters, boss_room)
		if picked.type != "boss":
			all_boss = false
	_check(all_boss, "boss room 20 picks: all boss type")

	print("== T5: AI 指定类型在过滤后集合内优先匹配 ==")
	var typed := _make_content("combat", 5)
	typed.monster_types = ["巨魔"]  # floor5 时巨魔进入过滤集合
	var got_troll := false
	for i in range(30):
		var picked: MonsterData = spawner._get_monster_by_config(monsters, typed)
		if picked.name == "巨魔":
			got_troll = true
	_check(got_troll, "monster_types preference honored within filtered set")

	print("")
	print("Results: ", _passed, " passed, ", _failures.size(), " failed")
	for f in _failures:
		print("  FAILED: ", f)
	print("  ✓ all ", _passed + _failures.size(), " checks executed (no runtime aborts)")
	quit(0 if _failures.is_empty() else 1)
