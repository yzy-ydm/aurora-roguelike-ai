## 死亡流程与 run 生命周期测试 (TASK-027)
##
## 覆盖死亡/退出/新游戏的临时状态清理与存档服务状态锁释放（纯状态逻辑，无 HTTP）:
## 1. reset_run_state: 清空运行时统计/扩展数据/时长/楼层/存档，保留 profile 基线
## 2. reset_run_state: 死亡状态(hp=0)不再泄漏进下一次 run
## 3. SaveService.reset_state: 强制释放状态锁（LOAD_RESET）
##
## 运行方式（无头模式）:
##   Godot_v4.7-stable_win64_console.exe --headless --path client --script res://tests/test_save_death.gd
##
## 脚手架注意: --script 模式下 autoload 全局名不是编译期标识符，
## 需经 root.get_node("GameStateManager") 获取实例

extends SceneTree

var _failures: Array[String] = []
var _passed: int = 0

const PlayerStatsScript = preload("res://scripts/player/player_stats.gd")

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
	var gsm := root.get_node("GameStateManager")
	var svc := root.get_node("SaveService")

	print("== T1: reset_run_state 清理 run 临时状态 ==")
	# 构造一个"运行中"状态
	var stats = PlayerStatsScript.new()
	stats.current_health = 0  # 模拟死亡
	stats.level = 5
	gsm.set_runtime_stats(stats)
	gsm.set_extended_save_data("weapon_id", 3)
	gsm.set_current_floor(4)
	gsm.set_current_save({"current_floor": 4, "player_state": {"level": 5}}, 1)
	gsm.add_play_time(120.0)
	# 保留 profile 基线
	gsm.set_player_data({"nickname": "profile_baseline", "level": 9, "max_health": 100, "current_health": 100})

	gsm.reset_run_state()
	_check(gsm.get_runtime_stats() == null, "runtime stats cleared (dead PlayerStats released)")
	_check(gsm.get_extended_save_data().is_empty(), "extended save data cleared")
	_check(gsm.get_current_floor() == 1, "runtime floor reset to 1", str(gsm.get_current_floor()))
	_check(gsm.get_current_save().is_empty(), "current save cleared")
	_check(gsm.get_player_data().get("nickname", "") == "profile_baseline",
		"profile baseline preserved", str(gsm.get_player_data()))

	print("== T2: 死亡状态不再污染新 run 的玩家数据 ==")
	# reset 后 get_player_data 应返回 profile 基线（而非死亡 stats 的 hp=0）
	var data_after: Dictionary = gsm.get_player_data()
	_check(int(data_after.get("current_health", -1)) > 0,
		"get_player_data after reset has alive health", str(data_after.get("current_health", -1)))
	_check(int(data_after.get("level", -1)) == 9, "profile level used as new run baseline", str(data_after))

	print("== T3: SaveService 状态锁强制释放 ==")
	svc._pending_operation = "load_saves"
	svc._is_loading = true
	svc.reset_state()
	_check(svc._pending_operation == "" and not svc._is_loading,
		"reset_state releases lock (no permanent 加载存档中)")

	print("")
	print("Results: ", _passed, " passed, ", _failures.size(), " failed")
	for f in _failures:
		print("  FAILED: ", f)
	print("  ✓ all ", _passed + _failures.size(), " checks executed (no runtime aborts)")
	quit(0 if _failures.is_empty() else 1)
