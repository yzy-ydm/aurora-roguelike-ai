## 死亡后重新开始测试 (TASK-028)
##
## 覆盖"死亡 → 重新开始"必须创建全新 run 状态:
## 1. reset_stats_to: 生成全新的 PlayerStats 对象（禁止复用死亡 run 的旧对象）
## 2. 新 run: HP=100 / Level=1 / Gold=0（profile 基线）
## 3. 武器重置: 初始默认武器 Lv1（伤害 20）
## 4. run 临时状态清空（运行时统计/扩展数据/楼层）
##
## 运行方式（无头模式）:
##   Godot_v4.7-stable_win64_console.exe --headless --path client --script res://tests/test_new_run_after_death.gd
##
## 脚手架注意: player_controller 的 _ready 依赖场景子节点，测试中不加入场景树，
## 只调用纯逻辑方法（get_stats/reset_stats_to/_setup_weapon/...）

extends SceneTree

var _failures: Array[String] = []
var _passed: int = 0

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

	print("== T1: 模拟死亡 run 的污染状态 ==")
	var player := CharacterBody2D.new()
	player.set_script(load("res://scripts/player/player_controller.gd"))

	# 模拟 run 中: HP=0(死亡) / Level=5 / Gold=99 / 武器升到 Lv3
	var dead_stats = player.get_stats()
	dead_stats.current_health = 0
	dead_stats.level = 5
	dead_stats.gold = 99
	dead_stats.attack = 20
	dead_stats.max_health = 130
	gsm.set_runtime_stats(dead_stats)
	gsm.set_extended_save_data("weapon_id", 1)
	gsm.set_extended_save_data("weapon_level", 3)
	gsm.set_current_floor(4)

	# 模拟 profile 基线（登录数据）
	gsm.set_player_data({
		"nickname": "test001",
		"level": 1,
		"attack": 10,
		"defense": 0,
		"max_health": 100,
		"current_health": 100,
		"gold": 0,
		"move_speed": 200.0,
		"experience": 0,
		"experience_to_next": 100
	})

	print("== T2: 重新开始 → 全新 PlayerStats（禁止复用旧对象）==")
	gsm.reset_run_state()
	var old_stats_ref = player.get_stats()
	player.reset_stats_to(gsm.get_player_data())
	var new_stats = player.get_stats()
	_check(new_stats != old_stats_ref, "NEW PlayerStats instance created (old object not reused)")
	_check(new_stats.current_health == 100, "HP=100", str(new_stats.current_health))
	_check(new_stats.level == 1, "Level=1", str(new_stats.level))
	_check(new_stats.gold == 0, "Gold=0", str(new_stats.gold))
	_check(new_stats.max_health == 100, "max_health=100", str(new_stats.max_health))

	print("== T3: 武器重置为初始武器 ==")
	player._setup_weapon()  # 创建武器节点（此时 extended 数据已清空 → 默认武器）
	var weapon: Node = player.get_node_or_null("Weapon")
	var instance_before = weapon.get_weapon_instance() if weapon else null
	var dmg_before: int = instance_before.get_damage() if instance_before else -1
	_check(dmg_before == 20, "default weapon Lv1 damage=20", str(dmg_before))
	# 模拟升级后重置
	player.upgrade_weapon()
	player.upgrade_weapon()
	player.reset_weapon_to_default()
	var dmg_after: int = weapon.get_weapon_instance().get_damage()
	var lv_after: int = weapon.get_weapon_instance().get_level()
	_check(dmg_after == 20, "weapon damage reset to 20 (TASK-028 growth irrelevant at Lv1)", str(dmg_after))
	_check(lv_after == 1, "weapon level reset to 1", str(lv_after))

	print("== T4: run 临时状态已清空 ==")
	_check(gsm.get_runtime_stats() == player.get_stats(), "runtime stats re-linked to new instance")
	_check(gsm.get_current_floor() == 1, "runtime floor reset to 1", str(gsm.get_current_floor()))
	_check(gsm.get_extended_save_data().get("weapon_level", -1) == 1,
		"extended weapon_level = 1", str(gsm.get_extended_save_data()))

	print("")
	print("Results: ", _passed, " passed, ", _failures.size(), " failed")
	for f in _failures:
		print("  FAILED: ", f)
	print("  ✓ all ", _passed + _failures.size(), " checks executed (no runtime aborts)")
	quit(0 if _failures.is_empty() else 1)
