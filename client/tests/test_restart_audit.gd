## 重启 run 数据污染修复测试 (Phase 18.2)
##
## 覆盖用户报告: [Player] PlayerStats rebuilt for new run (hp=0 level=3 gold=105)
## 根因: get_player_data/set_runtime_stats/sync_from_runtime_stats 把运行时数据
## 回写 _player_data 基线 → 死亡时基线被污染 → restart 读取死数据。
##
## 1. 运行时读取不回写基线（profile 快照不被污染）
## 2. 死亡 → reset_stats_to(默认+昵称) → 全新对象: hp=100/level=1/gold=0/攻击默认
## 3. 武器重置为默认武器
## 4. get_profile_data 始终保持账号基线
##
## 运行方式（无头模式）:
##   Godot_v4.7-stable_win64_console.exe --headless --path client --script res://tests/test_restart_audit.gd

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

	print("== T1: 运行时数据不回写 profile 基线（污染修复回归）==")
	gsm.reset()
	gsm.set_player_data({
		"nickname": "test001", "level": 1, "experience": 0, "gold": 0,
		"max_health": 100, "health": 100, "attack": 10, "defense": 5
	})
	# 模拟死亡 run 的运行时状态
	var dead = PlayerStatsScript.new()
	dead.current_health = 0
	dead.level = 3
	dead.gold = 105
	gsm.set_runtime_stats(dead)
	# run 中多次读取（旧实现每次读取都会把死数据写回基线）
	var during_run: Dictionary = gsm.get_player_data()
	_check(int(during_run.get("current_health", -1)) == 0, "runtime-first read returns dead hp (expected during run)", str(during_run.get("current_health")))
	# 退出 run（reset_run_state）后基线必须干净
	gsm.reset_run_state()
	var after_reset: Dictionary = gsm.get_player_data()
	_check(int(after_reset.get("current_health", -1)) == 100, "baseline hp=100 after reset (NOT polluted by dead run)", str(after_reset.get("current_health")))
	_check(int(after_reset.get("level", -1)) == 1, "baseline level=1 after reset", str(after_reset.get("level")))
	_check(int(after_reset.get("gold", -1)) == 0, "baseline gold=0 after reset", str(after_reset.get("gold")))

	print("== T2: 死亡 → 重启 → 全新 PlayerStats（默认+昵称）==")
	var player := CharacterBody2D.new()
	player.set_script(load("res://scripts/player/player_controller.gd"))
	# 让玩家进入死亡状态
	var old_stats = player.get_stats()
	old_stats.current_health = 0
	old_stats.level = 3
	old_stats.gold = 105
	old_stats.max_health = 130
	# 重启: reset_stats_to(仅昵称基线)
	player.reset_stats_to({"nickname": "test001"})
	var new_stats = player.get_stats()
	_check(new_stats != old_stats, "NEW PlayerStats instance (old object not reused)")
	_check(new_stats.current_health == 100, "new run hp=100 (NOT 0)", str(new_stats.current_health))
	_check(new_stats.level == 1, "new run level=1 (NOT 3)", str(new_stats.level))
	_check(new_stats.gold == 0, "new run gold=0 (NOT 105)", str(new_stats.gold))
	_check(new_stats.max_health == 100, "new run max_health=100", str(new_stats.max_health))
	_check(new_stats.attack == 10, "new run attack=default 10", str(new_stats.attack))
	_check(new_stats.nickname == "test001", "nickname preserved", str(new_stats.nickname))

	print("== T3: 武器重置为默认 ==")
	player._setup_weapon()
	player.upgrade_weapon()
	player.upgrade_weapon()
	player.reset_weapon_to_default()
	var weapon: Node = player.get_node_or_null("Weapon")
	var inst = weapon.get_weapon_instance() if weapon else null
	_check(inst != null and inst.get_level() == 1 and inst.get_damage() == 20,
		"weapon reset to default Lv1 damage=20", str(inst.get_level() if inst else -1) + "/" + str(inst.get_damage() if inst else -1))

	print("== T4: get_profile_data 始终保持账号基线 ==")
	var profile_snapshot: Dictionary = gsm.get_profile_data()
	_check(profile_snapshot.size() > 0 and int(profile_snapshot.get("level", -1)) == 1,
		"profile snapshot intact after run activity", str(profile_snapshot))

	print("")
	print("Results: ", _passed, " passed, ", _failures.size(), " failed")
	for f in _failures:
		print("  FAILED: ", f)
	print("  ✓ all ", _passed + _failures.size(), " checks executed (no runtime aborts)")
	quit(0 if _failures.is_empty() else 1)
