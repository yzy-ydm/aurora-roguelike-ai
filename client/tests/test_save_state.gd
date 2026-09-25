## 存档状态往返测试 (TASK-025)
##
## 验证 GameStateManager 存档恢复与保存数据构建（纯状态逻辑，无 HTTP）:
## 1. set_current_save: 玩家状态缓存 / 扩展数据 / 运行时楼层 / 槽位恢复
## 2. get_save_data: current_floor 取运行时值（暂停/退出/自动保存统一真实进度）
## 3. 槽位管理: 默认 -1 → 新游戏分配槽位
## 4. reset: 状态清空
##
## 运行方式（无头模式）:
##   Godot_v4.7-stable_win64_console.exe --headless --path client --script res://tests/test_save_state.gd
##
## 脚手架注意: --script 模式下 autoload 全局名不是编译期标识符，
## 需经 root.get_node("GameStateManager") 获取 autoload 实例

extends SceneTree

var _failures: Array[String] = []
var _passed: int = 0


func _initialize() -> void:
	_run_tests()


## 获取 GameStateManager autoload 实例（--script 模式下经 root 查找）
func _gsm() -> Node:
	return Engine.get_main_loop().root.get_node("GameStateManager")


func _run_tests() -> void:
	print("========================================")
	print("  Save State Roundtrip Tests (TASK-025)")
	print("========================================")

	_test_set_current_save_restores_state()
	_test_get_save_data_runtime_floor()
	_test_slot_management()
	_test_reset()

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


## 测试1: set_current_save 恢复玩家状态/扩展数据/楼层/槽位
func _test_set_current_save_restores_state() -> void:
	print("\n--- Test 1: set_current_save restores state ---")
	_gsm().reset()
	var save = {
		"current_floor": 3,
		"player_state": {
			"level": 5, "current_health": 87, "max_health": 150, "attack": 18
		},
		"weapon_level": 4,
		"weapon_id": 2,
		"passive_items": ["hp_ring"],
		"play_time": 600,
		"kill_count": 12,
		"gold_collected": 55
	}
	_gsm().set_current_save(save, 2)

	var player_data = _gsm().get_player_data()
	_check(player_data.get("level", 0) == 5,
		"player_state cached to _player_data", str(player_data.get("level", 0)))
	_check(player_data.get("current_health", 0) == 87,
		"health restored", str(player_data.get("current_health", 0)))
	_check(_gsm().get_extended_save_data().get("weapon_id", -1) == 2,
		"extended weapon_id restored", str(_gsm().get_extended_save_data().get("weapon_id", -1)))
	_check(_gsm().get_current_floor() == 3,
		"runtime floor restored from save", str(_gsm().get_current_floor()))
	_check(_gsm().get_current_slot() == 2,
		"slot restored", str(_gsm().get_current_slot()))


## 测试2: get_save_data 的 current_floor 取运行时值
func _test_get_save_data_runtime_floor() -> void:
	print("\n--- Test 2: get_save_data uses runtime floor ---")
	_gsm().reset()
	_gsm().set_current_slot(1)
	_gsm().set_current_floor(6)
	var save_data = _gsm().get_save_data()
	_check(save_data.get("current_floor", 0) == 6,
		"save data floor = runtime floor", str(save_data.get("current_floor", 0)))


## 测试3: 槽位管理——默认 -1，新游戏分配槽位
func _test_slot_management() -> void:
	print("\n--- Test 3: slot management ---")
	_gsm().reset()
	_check(_gsm().get_current_slot() == -1,
		"default slot is -1", str(_gsm().get_current_slot()))
	_gsm().set_current_slot(1)
	_check(_gsm().get_current_slot() == 1,
		"new game assigns slot 1", str(_gsm().get_current_slot()))


## 测试4: reset 清空状态
func _test_reset() -> void:
	print("\n--- Test 4: reset clears state ---")
	_gsm().set_current_slot(3)
	_gsm().set_current_floor(9)
	_gsm().reset()
	_check(_gsm().get_current_slot() == -1,
		"reset clears slot", str(_gsm().get_current_slot()))
	_check(_gsm().get_current_floor() == 1,
		"reset restores floor to 1", str(_gsm().get_current_floor()))
