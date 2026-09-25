## 存档槽位持久化测试 (TASK-029)
##
## 覆盖用户报告: LOAD_SUCCESS count=1（slot1 已有存档）但后续 SAVE START slot=2。
## 规则: 已有 slot1 → 默认继续 slot1，不自动创建 slot2。
##
## 流程: 登录 → resolve_save_slot 规则验证 → 槽位1 真实保存 →
##   模拟退出(统一重置) → 重新加载存档列表 → slot1 仍在、slot2 不存在 →
##   重新进入读取 slot1（楼层/属性恢复）
##
## 运行前提: 游戏服务端 :8000 与 MySQL 运行中; 运行前用清理工具清空 test001 存档
## 运行方式（无头模式）:
##   Godot_v4.7-stable_win64_console.exe --headless --path client --script res://tests/test_save_slot_persistence.gd

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

func _login(api: Node, cfg: Node, tm: Node) -> bool:
	var box := {"done": false, "res": null}
	var handler := func(res: Variant) -> void:
		box["done"] = true
		box["res"] = res
	api.request_completed.connect(handler)
	api.post_request(cfg.AUTH_LOGIN, {"username": cfg.DEV_USERNAME, "password": cfg.DEV_PASSWORD})
	var waited := 0
	while not box["done"] and waited < 300:
		await process_frame
		waited += 1
	api.request_completed.disconnect(handler)
	if box["res"] is Dictionary and box["res"].has("access_token"):
		tm.save_token(str(box["res"]["access_token"]))
		return true
	return false

func _do_save(svc: Node, slot: int) -> Dictionary:
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
	svc.save_game(slot, {
		"save_name": "slot-persist-test",
		"current_floor": 3,
		"player_state": {"level": 2, "current_health": 88, "max_health": 100, "attack": 15},
		"play_time": 240,
		"kill_count": 6,
		"gold_collected": 12
	})
	var waited := 0
	while not box["done"] and waited < 300:
		await process_frame
		waited += 1
	svc.save_saved.disconnect(on_saved)
	svc.save_error.disconnect(on_error)
	return box

func _do_load_saves(svc: Node) -> Dictionary:
	var box := {"done": false}
	var handler := func(saves: Array) -> void:
		box["done"] = true
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

	print("== T1: 登录 ==")
	var login_ok: bool = await _login(api, cfg, tm)
	_check(login_ok, "login succeeded")

	print("== T2: resolve_save_slot 规则 ==")
	_check(gsm.resolve_save_slot(2) == 2, "no current slot + requested 2 -> 2 (explicit choice allowed)", str(gsm.resolve_save_slot(2)))
	gsm.set_current_slot(1)  # 模拟进入新游戏分配槽位1
	_check(gsm.resolve_save_slot(2) == 1, "current slot=1 + clicked 2 -> 1 (不创建 slot2)", str(gsm.resolve_save_slot(2)))
	_check(gsm.resolve_save_slot(3) == 1, "current slot=1 + clicked 3 -> 1", str(gsm.resolve_save_slot(3)))
	_check(gsm.resolve_save_slot(1) == 1, "current slot=1 + clicked 1 -> 1", str(gsm.resolve_save_slot(1)))

	print("== T3: 槽位1 真实保存（floor=3）==")
	var save_box: Dictionary = await _do_save(svc, gsm.resolve_save_slot(2))  # 面板点2 → 实际1
	_check(save_box["ok"], "save to slot 1 succeeded (panel choice overridden)", str(save_box["msg"]))
	_check(gsm.get_current_slot() == 1, "current slot remains 1", str(gsm.get_current_slot()))

	print("== T4: 模拟退出（统一重置）→ 重新加载 → slot1 仍在、slot2 不存在 ==")
	gsm.reset_run_state()
	svc.reset_state()
	var load_box: Dictionary = await _do_load_saves(svc)
	var slot1: Dictionary = svc.get_save_by_slot(1)
	var slot2: Dictionary = svc.get_save_by_slot(2)
	_check(slot1.size() > 0 and int(slot1.get("current_floor", 0)) == 3,
		"slot1 persists with floor=3 after re-load", str(slot1))
	_check(slot2.is_empty(), "slot2 was NOT created (no stray save)", str(slot2))

	print("== T5: 重新进入 → 读取槽位1（楼层/属性恢复）==")
	if slot1.size() > 0:
		gsm.set_current_save(slot1, 1)
		_check(gsm.get_current_slot() == 1, "re-enter uses slot 1", str(gsm.get_current_slot()))
		_check(gsm.get_current_floor() == 3, "floor restored = 3", str(gsm.get_current_floor()))
		_check(int(gsm.get_player_data().get("current_health", 0)) == 88,
			"player hp restored = 88", str(gsm.get_player_data()))

	print("")
	print("Results: ", _passed, " passed, ", _failures.size(), " failed")
	for f in _failures:
		print("  FAILED: ", f)
	print("  ✓ all ", _passed + _failures.size(), " checks executed (no runtime aborts)")
	quit(0 if _failures.is_empty() else 1)
