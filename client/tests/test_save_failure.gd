## 保存失败释放锁测试 (TASK-028)
##
## 覆盖"任何失败都必须释放锁"要求:
## T1: 登录获取 token
## T2: 清空 token → 保存 → 服务端 401 → save_error + 锁释放（FAILED + LOCK_RELEASED）
## T3: 重新登录 → 再次保存 → SUCCESS（证明锁在失败后可复用）
##
## 运行前提: 游戏服务端 :8000 与 MySQL 运行中
## 运行方式（无头模式）:
##   Godot_v4.7-stable_win64_console.exe --headless --path client --script res://tests/test_save_failure.gd

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

## 执行一次保存并等待结果（box: {done, ok, msg}）
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
		"save_name": "failure-test",
		"current_floor": 1,
		"player_state": {"level": 1, "current_health": 100, "max_health": 100},
		"play_time": 5,
		"kill_count": 0,
		"gold_collected": 0
	})
	var waited := 0
	while not box["done"] and waited < 300:
		await process_frame
		waited += 1
	svc.save_saved.disconnect(on_saved)
	svc.save_error.disconnect(on_error)
	return box

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

func _run() -> void:
	await process_frame
	var api := root.get_node("ApiClient")
	var tm := root.get_node("TokenManager")
	var svc := root.get_node("SaveService")
	var cfg := root.get_node("APIConfig")

	print("== T1: 登录 ==")
	var t1_ok: bool = await _login(api, cfg, tm)
	_check(t1_ok and tm.has_token(), "token acquired", str(t1_ok))

	print("== T2: 401 失败路径 → 释放锁 ==")
	tm.clear_token()  # 模拟 token 失效
	var fail_box: Dictionary = await _do_save(svc, 1)
	_check(fail_box["done"], "save failure reported (not hanging)", str(fail_box["msg"]))
	_check(not fail_box["ok"], "save reported as failed (401)", str(fail_box["msg"]))
	_check(svc._pending_operation == "" and not svc._is_loading,
		"lock released after failure", "op=" + str(svc._pending_operation))

	print("== T3: 重新登录后保存成功（锁可复用）==")
	var t3_login_ok: bool = await _login(api, cfg, tm)
	_check(t3_login_ok, "re-login succeeded", str(t3_login_ok))
	var ok_box: Dictionary = await _do_save(svc, 1)
	_check(ok_box["done"] and ok_box["ok"], "save succeeds after re-login", str(ok_box["msg"]))
	_check(svc._pending_operation == "" and not svc._is_loading,
		"lock released after success", "op=" + str(svc._pending_operation))

	print("")
	print("Results: ", _passed, " passed, ", _failures.size(), " failed")
	for f in _failures:
		print("  FAILED: ", f)
	print("  ✓ all ", _passed + _failures.size(), " checks executed (no runtime aborts)")
	quit(0 if _failures.is_empty() else 1)
