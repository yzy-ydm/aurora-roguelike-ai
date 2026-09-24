## 怪物AI战斗闭环测试 (TASK-017.7, TASK-017.9, TASK-018.0)
##
## 验证怪物→玩家方向战斗闭环修复:
## 1. 跨房间坐标: 怪物在房间local坐标系、玩家在世界坐标系时，AI距离判断正确（CHASE而非IDLE）
## 2. 追击方向: 追击时 velocity.x 朝向玩家
## 3. 攻击触发: attack_range(60)内 → 前摇0.3s（期间无伤害/停止移动）→ 伤害落地；冷却内不重复
## 4. 伤害来源坐标: DamageSystem路径传递 attacker.global_position（击退方向基准）
## 5. 速度配置: MonsterBalanceConfig 生成速度区间+楼层成长；room_spawner clamp 写入实例
## 6. 出生保护: 生成后0.8s内不决策/不追击/不攻击，保护结束恢复正常AI
##
## 运行方式（无头模式，无需启动游戏）:
##   Godot_v4.7-stable_win64_console.exe --headless --path client --script res://tests/test_monster_ai.gd

extends SceneTree

var _failures: Array[String] = []
var _passed: int = 0

## 场景桩引用
var _game_scene: Node2D = null
var _game_world: Node2D = null
var _player: CharacterBody2D = null
var _room_node: Node2D = null
var _monster_node: CharacterBody2D = null
var _monster_ai: Node = null
var _monster_entity: MonsterEntity = null

## 玩家桩脚本（take_damage 记录伤害与攻击者坐标）
const PLAYER_STUB_SOURCE := "\
extends CharacterBody2D\n\
var health: int = 100\n\
var damage_count: int = 0\n\
var last_attacker_position: Vector2 = Vector2.ZERO\n\
func is_dead() -> bool:\n\
\treturn health <= 0\n\
func take_damage(v: int, attacker_position: Vector2 = Vector2.ZERO) -> void:\n\
\thealth -= v\n\
\tdamage_count += 1\n\
\tlast_attacker_position = attacker_position\n"

## 第1战斗房房间中心（世界坐标，层号1 × 房间间距1240）
const ROOM_OFFSET := Vector2(1240.0, 0.0)
## 怪物房间内local坐标（模拟 room_spawner 生成的出生点）
const MONSTER_LOCAL_POS := Vector2(-300.0, 282.0)
## 玩家进房后世界坐标（怪物左侧 240px → 修复后应为 CHASE）
const PLAYER_WORLD_POS := Vector2(700.0, 280.0)


func _initialize() -> void:
	_run_tests()


func _run_tests() -> void:
	print("========================================")
	print("  Monster AI Combat Loop Tests (TASK-017.7)")
	print("========================================")

	# 先等一帧让 root 完成 ready：此后 add_child 的节点 _ready 同步执行，
	# monster.tscn 的 MonsterAI 会在 set_monster_entity 之前创建并完成 initialize
	await process_frame

	await _test_cross_room_distance()
	await _test_chase_direction()
	await _test_attack_trigger()
	await _test_attacker_position_via_damage_system()
	await _test_speed_config()
	await _test_spawn_protection()

	# 护栏: 若任一测试函数因运行时错误中断，通过数会少于预期
	const EXPECTED_CHECKS: int = 19
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


## 搭建场景桩: GameScene/GameWorld/Player(世界坐标) + Room_<id>(x=1240)/Monster(local坐标)
## 怪物复用 monster.tscn（_ready 自动挂 MonsterAI + 碰撞体 + 血条）
## 注意: _initialize 阶段 root 尚未 ready，子节点 _ready 需 await process_frame 后才执行
func _setup_scene(player_world_pos: Vector2, monster_local_pos: Vector2) -> void:
	# 玩家桩
	var stub_script := GDScript.new()
	stub_script.source_code = PLAYER_STUB_SOURCE
	stub_script.reload()

	_game_scene = Node2D.new()
	_game_scene.name = "GameScene"
	root.add_child(_game_scene)

	_game_world = Node2D.new()
	_game_world.name = "GameWorld"
	_game_scene.add_child(_game_world)

	_player = CharacterBody2D.new()
	_player.name = "Player"
	_player.set_script(stub_script)
	_game_world.add_child(_player)
	_player.global_position = player_world_pos

	# 房间节点（第1战斗房，房间中心世界坐标 ROOM_OFFSET）
	_room_node = Node2D.new()
	_room_node.name = "Room_2"
	_room_node.position = ROOM_OFFSET
	_game_world.add_child(_room_node)

	# 怪物节点（挂房间节点下，local 坐标）
	# 前置条件: root 已 ready（_run_tests 开头 await process_frame），add_child 后 _ready 同步执行
	var monster_scene: PackedScene = load("res://scenes/enemy/monster.tscn")
	_monster_node = monster_scene.instantiate()
	_room_node.add_child(_monster_node)
	_monster_node.position = monster_local_pos
	# 关闭怪物自身的物理帧驱动，AI 由测试手动 update 驱动（避免帧循环并行驱动干扰断言）
	_monster_node.set_physics_process(false)

	# 实体 + 数据（speed=80，attack_range 用 MonsterEntity 默认值 60）
	var monster_data := MonsterData.new()
	monster_data.name = "测试史莱姆"
	monster_data.type = "normal"
	monster_data.health = 100
	monster_data.attack = 10
	monster_data.defense = 2
	monster_data.speed = 80
	_monster_entity = MonsterEntity.new()
	_monster_entity.set_monster_data(monster_data)
	_monster_node.set_monster_entity(_monster_entity)


## 释放场景桩（free 立即释放，避免同名 GameScene 残留干扰 _find_player）
func _teardown_scene() -> void:
	_monster_ai = null
	_monster_entity = null
	_monster_node = null
	_room_node = null
	_player = null
	_game_world = null
	if _game_scene and is_instance_valid(_game_scene):
		_game_scene.free()
	_game_scene = null


## 测试1: 跨房间坐标——local怪物 vs world玩家，AI 距离判断正确
func _test_cross_room_distance() -> void:
	print("\n--- Test 1: AI distance across room local/world coordinates ---")
	_setup_scene(PLAYER_WORLD_POS, MONSTER_LOCAL_POS)
	_monster_ai = _monster_node.get_node_or_null("MonsterAI")
	_monster_ai.update(0.81)  # 先过出生保护期（TASK-018.0）
	_monster_ai.update(0.016)

	# 修复前: local(-300) vs world(700) → 距离~1000 → IDLE
	# 修复后: global(940) vs global(700) → 距离~240 → CHASE
	var state: String = _monster_ai.get_ai_state_string()
	_check(state == "chase", "AI enters CHASE (not IDLE) across room coordinates", "state=" + state)
	_check(absf(_monster_node.velocity.x) > 0.0, "monster velocity applied in chase", str(_monster_node.velocity))
	_teardown_scene()


## 测试2: 追击方向——velocity.x 朝向玩家
func _test_chase_direction() -> void:
	print("\n--- Test 2: Chase direction ---")
	# 玩家在怪物左侧（世界700 < 怪物940）→ 怪物应向左（velocity.x < 0）
	_setup_scene(PLAYER_WORLD_POS, MONSTER_LOCAL_POS)
	_monster_ai = _monster_node.get_node_or_null("MonsterAI")
	_monster_ai.update(0.81)  # 先过出生保护期（TASK-018.0）
	_monster_ai.update(0.016)
	_check(_monster_node.velocity.x < 0.0, "player on left -> monster moves left", str(_monster_node.velocity.x))
	_teardown_scene()

	# 玩家在怪物右侧（世界1200 > 怪物940）→ 怪物应向右
	_setup_scene(Vector2(1200.0, 280.0), MONSTER_LOCAL_POS)
	_monster_ai = _monster_node.get_node_or_null("MonsterAI")
	_monster_ai.update(0.81)  # 先过出生保护期（TASK-018.0）
	_monster_ai.update(0.016)
	_check(_monster_node.velocity.x > 0.0, "player on right -> monster moves right", str(_monster_node.velocity.x))
	_teardown_scene()


## 测试3: 攻击触发——attack_range(60) 内 → 前摇0.3s（无伤害/停止移动）→ 伤害落地；冷却内不重复
func _test_attack_trigger() -> void:
	print("\n--- Test 3: Attack windup then damage within attack_range(60) ---")
	# 玩家置于怪物右侧 55px（>50 旧射程、<60 新射程）→ 证明 attack_range=60 生效
	_setup_scene(Vector2(995.0, 282.0), MONSTER_LOCAL_POS)
	_monster_ai = _monster_node.get_node_or_null("MonsterAI")
	_monster_ai.update(0.81)  # 过出生保护期；此帧进入 ATTACK 并开始前摇
	_check(_player.get("damage_count") == 0,
		"windup phase: no damage before windup completes", "count=" + str(_player.get("damage_count")))
	_check(_monster_ai.get_ai_state_string() == "windup",
		"AI state string reports windup", _monster_ai.get_ai_state_string())
	_check(absf(_monster_node.velocity.x) < 1.0,
		"monster stops moving during windup", str(_monster_node.velocity.x))
	_monster_ai.update(0.3)  # 前摇完成 → 执行伤害
	_check(_player.get("damage_count") == 1,
		"damage lands after windup at distance 55", "count=" + str(_player.get("damage_count")))
	_check(_player.get("health") < 100,
		"player took damage", "health=" + str(_player.get("health")))
	# 攻击冷却 1.5s 内不重复攻击
	_monster_ai.update(0.5)
	_check(_player.get("damage_count") == 1,
		"no repeat attack during cooldown", "count=" + str(_player.get("damage_count")))
	_teardown_scene()


## 测试4: 伤害来源坐标——DamageSystem 路径传递 attacker.global_position（击退方向基准）
func _test_attacker_position_via_damage_system() -> void:
	print("\n--- Test 4: Attacker position via DamageSystem ---")
	_setup_scene(Vector2(995.0, 282.0), MONSTER_LOCAL_POS)

	# 挂真实 DamageSystem（monster_node 经 GameScene/DamageSystem 查找）
	var ds_script: GDScript = load("res://scripts/combat/damage_system.gd")
	var ds := Node.new()
	ds.name = "DamageSystem"
	ds.set_script(ds_script)
	_game_scene.add_child(ds)

	_monster_ai = _monster_node.get_node_or_null("MonsterAI")
	_monster_ai.update(0.81)  # 过出生保护期，进入前摇
	_monster_ai.update(0.3)   # 前摇完成 → 执行伤害
	var pos: Vector2 = _player.get("last_attacker_position")
	var expected: Vector2 = _monster_node.global_position
	_check(pos.distance_to(expected) < 1.0,
		"attacker_position == monster global_position",
		"got=" + str(pos) + " expected=" + str(expected))
	_check(pos.x > 100.0,
		"position is world-space (not room-local)", "x=" + str(pos.x))
	_teardown_scene()


## 测试5: 速度配置——区间生成 + 楼层成长 + room_spawner clamp 写入实例
func _test_speed_config() -> void:
	print("\n--- Test 5: Speed config (MonsterBalanceConfig + RoomSpawner clamp) ---")
	var config: GDScript = load("res://scripts/models/monster_balance_config.gd")

	var normal_1: Dictionary = config.generate_monster_stats("normal", 1)
	_check(normal_1["speed"] >= 60 and normal_1["speed"] <= 90,
		"normal floor1 speed in [60,90]", str(normal_1["speed"]))

	var elite_1: Dictionary = config.generate_monster_stats("elite", 1)
	_check(elite_1["speed"] >= 70 and elite_1["speed"] <= 120,
		"elite floor1 speed in [70,120]", str(elite_1["speed"]))

	# 楼层成长: floor5 速度因子 = 1 + 4*0.05 = 1.2 → [72,108]
	var normal_5: Dictionary = config.generate_monster_stats("normal", 5)
	_check(normal_5["speed"] >= 72 and normal_5["speed"] <= 108,
		"normal floor5 speed scaled in [72,108]", str(normal_5["speed"]))

	# room_spawner._apply_monster_clamp 真正写入 MonsterData（修复前保持蜗速10）
	var spawner_script: GDScript = load("res://scripts/world/room_spawner.gd")
	var spawner := Node.new()
	spawner.set_script(spawner_script)
	var data := MonsterData.new()
	data.speed = 10  # 旧蜗速值，应被配置覆盖
	spawner._apply_monster_clamp(data, 1)
	_check(data.speed >= 60 and data.speed <= 90,
		"room_spawner clamp writes config speed to MonsterData", str(data.speed))
	spawner.free()


## 测试6: 出生保护期（TASK-018.0）——保护期内不决策/不追击/不攻击，保护结束恢复正常AI
func _test_spawn_protection() -> void:
	print("\n--- Test 6: Spawn protection (0.8s no action) ---")
	# 玩家在攻击射程内（55px），保护期内也不应攻击/移动
	_setup_scene(Vector2(995.0, 282.0), MONSTER_LOCAL_POS)
	_monster_ai = _monster_node.get_node_or_null("MonsterAI")
	_monster_ai.update(0.016)
	_check(_monster_ai.get_ai_state_string() == "idle",
		"protection phase: AI stays IDLE", _monster_ai.get_ai_state_string())
	_check(_player.get("damage_count") == 0 and absf(_monster_node.velocity.x) < 1.0,
		"protection phase: no attack and no movement",
		"dmg=" + str(_player.get("damage_count")) + " vel=" + str(_monster_node.velocity))
	# 保护期结束 → 恢复正常AI（进入攻击前摇）
	_monster_ai.update(0.81)
	_check(_monster_ai.get_ai_state_string() == "windup",
		"after protection: AI resumes attack (windup)", _monster_ai.get_ai_state_string())
	_teardown_scene()
