## 暂停状态下保存测试 (TASK-028)
##
## 复现用户验收失败场景: ESC → 暂停 → 保存 → "保存中..." 永不结束。
## 根因假设: 游戏暂停时 SceneTree.paused=true，HTTPRequest 默认 process_mode
## 继承自父节点（PAUSABLE）→ 暂停期间停止轮询 → request_completed 永不发射 →
## 状态锁永久卡死（LOAD_START op=save 后无 LOAD_SUCCESS/FAILED）。
##
## 本测试在真实暂停场景下调用 SaveService.save_game，验证:
## T1: 暂停状态下保存必须完成（成功或失败均算完成）
## T2: 完成后状态锁必须释放（连续第二次 load_saves 不再被跳过）
##
## 运行前提: 游戏服务端 :8000 与 MySQL 运行中
## 运行方式（无头模式）:
##   Godot_v4.7-stable_win64_console.exe --headless --path client --script res://tests/test_save_paused.gd

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
	var api := root.get_node("ApiClient")
	var svc := root.get_node("SaveService")
	var cfg := root.get_node("APIConfig")

	print("== T0: 登录获取 token ==")
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
		"login succeeded", str(login_box["res"]))

	print("== T1: 暂停状态下保存（真实 ESC→保存场景）==")
	paused = true  # SceneTree.paused —— 模拟 get_tree().paused = true

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
	svc.save_game(1, {
		"save_name": "paused-save-test",
		"current_floor": 1,
		"player_state": {"level": 1, "current_health": 100, "max_health": 100},
		"play_time": 10,
		"kill_count": 0,
		"gold_collected": 0
	})

	# 等待最多 12 秒（HTTP 超时 10 秒 + 余量）
	waited = 0
	while not box["done"] and waited < 120:
		await create_timer(0.1).timeout
		waited += 1
	svc.save_saved.disconnect(on_saved)
	svc.save_error.disconnect(on_error)

	_check(box["done"], "paused save completes (no permanent 保存中...)", str(box["msg"]))
	_check(svc._pending_operation == "" and not svc._is_loading,
		"lock released after paused save", "op=" + str(svc._pending_operation))

	print("== T2: 恢复后连续 load_saves 不被跳过 ==")
	paused = false
	var box2 := {"done": false}
	svc.saves_loaded.connect(func(saves: Array) -> void: box2["done"] = true)
	svc.load_saves()
	waited = 0
	while not box2["done"] and waited < 120:
		await create_timer(0.1).timeout
		waited += 1
	_check(box2["done"], "load_saves works after paused save (no stuck lock)")

	print("")
	print("Results: ", _passed, " passed, ", _failures.size(), " failed")
	for f in _failures:
		print("  FAILED: ", f)
	print("  ✓ all ", _passed + _failures.size(), " checks executed (no runtime aborts)")
	quit(0 if _failures.is_empty() else 1)
