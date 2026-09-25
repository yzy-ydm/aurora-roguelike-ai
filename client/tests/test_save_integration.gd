## 存档真实链路集成测试 (TASK-026)
##
## 用真实 HTTP + 真实服务端 + 真实 MySQL 复现用户手动验收路径:
##   登录 → 保存(slot1 更新) → 新槽位保存(slot3 404→POST) →
##   保存后立即读存档列表(继续游戏按钮的数据源) → load_saves 刷新 → 回读验证
##
## TASK-026 修复回归点:
##   T4: 保存成功后内存列表立即含新档（_refresh_saves_entry）
##   T7: 首次保存(POST 创建)楼层持久化（服务端 create_save 曾硬编码 floor=1）
##
## 运行前提:
##   1. 游戏服务端 :8000 与 MySQL 运行中; 账号 test001/test123456 已注册
##   2. 首次运行前清理 test001 的存档（保证 slot3 走 POST 创建路径）:
##      用服务端 venv 执行 TASK-026 报告中的清理脚本
## 运行方式（无头模式）:
##   Godot_v4.7-stable_win64_console.exe --headless --path client --script res://tests/test_save_integration.gd
##
## 脚手架注意:
##   - --script 模式下 autoload 全局名不是编译期标识符，须经 root.get_node("Xxx") 取实例
##   - 常量经实例访问 (cfg.AUTH_LOGIN)
##   - GDScript lambda 按值捕获局部变量 → 结果必须经 Dictionary 容器传回

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

## 执行一次保存并等待真实结果（box: {done, ok, msg}）
func _do_save(svc: Node, slot: int, data: Dictionary) -> Dictionary:
	var box := {"done": false, "ok": false, "msg": ""}
	var on_saved := func(success: bool, message: String) -> void:
		box["done"] = true
		box["ok"] = success
		box["msg"] = message
	var on_error := func(error: String) -> void:
		box["done"] = true
		box["ok"] = false
		box["msg"] = error
	svc.save_saved.connect(on_saved)
	svc.save_error.connect(on_error)
	svc.save_game(slot, data)
	var waited := 0
	while not box["done"] and waited < 300:
		await process_frame
		waited += 1
	svc.save_saved.disconnect(on_saved)
	svc.save_error.disconnect(on_error)
	return box

## 刷新存档列表并等待结果（box: {done, saves}）
func _do_load_saves(svc: Node) -> Dictionary:
	var box := {"done": false, "saves": []}
	var handler := func(saves: Array) -> void:
		box["done"] = true
		box["saves"] = saves
	svc.saves_loaded.connect(handler)
	svc.load_saves()
	var waited := 0
	while not box["done"] and waited < 300:
		await process_frame
		waited += 1
	svc.saves_loaded.disconnect(handler)
	return box

func _run() -> void:
	await process_frame
	var api := root.get_node("ApiClient")
	var tm := root.get_node("TokenManager")
	var gsm := root.get_node("GameStateManager")
	var svc := root.get_node("SaveService")
	var cfg := root.get_node("APIConfig")

	print("== T1: 真实登录 ==")
	var login_box := {"done": false, "res": null}
	api.request_completed.connect(func(res: Variant) -> void:
		login_box["done"] = true
		login_box["res"] = res
	)
	api.post_request(cfg.AUTH_LOGIN, {"username": cfg.DEV_USERNAME, "password": cfg.DEV_PASSWORD})
	var waited := 0
	while not login_box["done"] and waited < 300:
		await process_frame
		waited += 1
	_check(login_box["done"] and login_box["res"] is Dictionary and login_box["res"].has("access_token"),
		"login succeeded, token acquired", str(login_box["res"]))
	_check(tm.has_token(), "TokenManager has token")

	print("== T2: 槽位1 保存（已有存档 → PUT 200）==")
	var t2_box: Dictionary = await _do_save(svc, 1, {
		"save_name": "integration-slot1",
		"current_floor": 4,
		"player_state": {"level": 3, "attack": 25, "current_health": 77, "max_health": 120, "gold": 66},
		"play_time": 321,
		"kill_count": 9,
		"gold_collected": 40
	})
	_check(t2_box["ok"], "slot1 save success (PUT 200)", str(t2_box["msg"]))

	print("== T3: 槽位3 保存（新槽位 → PUT 404 → POST 201）==")
	var t3_box: Dictionary = await _do_save(svc, 3, {
		"save_name": "integration-slot3",
		"current_floor": 2,
		"player_state": {"level": 2, "attack": 15},
		"play_time": 60,
		"kill_count": 3,
		"gold_collected": 10
	})
	_check(t3_box["ok"], "slot3 fresh save success (404→POST 201)", str(t3_box["msg"]))

	print("== T4: 保存后立即查询（继续游戏按钮的数据源，不刷新列表）==")
	var by_slot3: Dictionary = svc.get_save_by_slot(3)
	_check(by_slot3.size() > 0 and int(by_slot3.get("current_floor", 0)) == 2,
		"get_save_by_slot(3) immediately after save returns fresh record (TASK-026 修复)",
		str(by_slot3))

	print("== T5: load_saves 刷新后回读 ==")
	var load_box: Dictionary = await _do_load_saves(svc)
	var by3_after: Dictionary = svc.get_save_by_slot(3)
	var by1_after: Dictionary = svc.get_save_by_slot(1)
	_check(by3_after.size() > 0 and int(by3_after.get("current_floor", 0)) == 2,
		"slot3 readable after reload", str(by3_after))
	_check(by1_after.size() > 0 and int(by1_after.get("current_floor", 0)) == 4,
		"slot1 floor=4 readable after reload (server persisted update)", str(by1_after))

	print("== T6: set_current_save 恢复链（模拟 enter_game(1) 继续游戏）==")
	if by1_after.size() > 0:
		gsm.set_current_save(by1_after, 1)
		var restored_floor: int = gsm.get_current_floor()
		var restored_level: int = gsm.get_player_data().get("level", -1)
		_check(restored_floor == 4, "floor restored to 4", str(restored_floor))
		_check(restored_level == 3, "player level restored to 3", str(restored_level))

	print("== T7: 首次保存楼层持久化（TASK-026 服务端修复回归）==")
	_check(by3_after.size() > 0 and int(by3_after.get("current_floor", 0)) == 2,
		"fresh-save (POST) floor persisted = 2 (server create_save fix)", str(by3_after))
	_check(by3_after.size() > 0 and int(by3_after.get("play_time", 0)) == 60,
		"fresh-save play_time persisted = 60", str(by3_after))

	print("== T8: 状态锁释放（TASK-027: 连续 load_saves 不卡死）==")
	var box_a: Dictionary = await _do_load_saves(svc)
	var box_b: Dictionary = await _do_load_saves(svc)
	_check(box_a["done"] and box_b["done"],
		"two consecutive load_saves both complete (no stuck LOAD lock)",
		"first=" + str(box_a["done"]) + " second=" + str(box_b["done"]))

	print("")
	print("Results: ", _passed, " passed, ", _failures.size(), " failed")
	for f in _failures:
		print("  FAILED: ", f)
	# 元护栏: 确认无中途 runtime 中止（到达此处即所有检查均执行）
	print("  ✓ all ", _passed + _failures.size(), " checks executed (no runtime aborts)")
	quit(0 if _failures.is_empty() else 1)
