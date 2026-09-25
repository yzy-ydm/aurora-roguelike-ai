## GameFlow 生命周期重置测试 (TASK-029)
##
## 覆盖用户报告 bug: 重新登录时 GameFlow 状态残留（旧 IN_GAME=5）→
## start_game ABORT → 无法进入游戏。
##
## 流程: 登录 → (AUTHENTICATING) → start_game 全链(真实HTTP) → READY
##   → 模拟进入游戏(PLAYING) → 统一退出 reset_flow → IDLE
##   → 重新登录 → start_game 再次成功 READY（旧代码在此 ABORT）
##
## 运行前提: 游戏服务端 :8000 与 MySQL 运行中
## 运行方式（无头模式）:
##   Godot_v4.7-stable_win64_console.exe --headless --path client --script res://tests/test_gameflow_reset.gd

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

## 登录（真实 HTTP，正确写入 TokenManager）
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

## start_game 全链并等待 flow_completed（含真实 profile/存档/资源加载）
func _run_full_flow(gfc: Node) -> bool:
	var box := {"done": false}
	var handler := func() -> void:
		box["done"] = true
	gfc.flow_completed.connect(handler)
	gfc.start_game()
	var waited := 0
	while not box["done"] and waited < 600:
		await process_frame
		waited += 1
	gfc.flow_completed.disconnect(handler)
	return box["done"]

func _run() -> void:
	await process_frame
	var api := root.get_node("ApiClient")
	var tm := root.get_node("TokenManager")
	var gfc := root.get_node("GameFlowController")
	var cfg := root.get_node("APIConfig")

	print("== T1: reset_flow → IDLE ==")
	gfc.reset_flow()
	_check(gfc.get_flow_state() == gfc.FlowState.IDLE, "state = IDLE", str(gfc.get_flow_state()))

	print("== T2: begin_authentication → AUTHENTICATING ==")
	gfc.begin_authentication()
	_check(gfc.get_flow_state() == gfc.FlowState.AUTHENTICATING, "state = AUTHENTICATING", str(gfc.get_flow_state()))

	print("== T3: 登录成功 → start_game 全链 → READY ==")
	var login_ok: bool = await _login(api, cfg, tm)
	_check(login_ok, "login succeeded", str(login_ok))
	var flow_ok: bool = await _run_full_flow(gfc)
	_check(flow_ok, "full loading flow completed", str(flow_ok))
	_check(gfc.get_flow_state() == gfc.FlowState.READY, "state = READY", str(gfc.get_flow_state()))

	print("== T4: 模拟进入游戏(PLAYING) → 统一退出 reset_flow → IDLE ==")
	# 模拟 enter_game 的场景切换副作用（真实 enter_game 会加载 game 场景，测试中直接置状态）
	gfc._flow_state = gfc.FlowState.PLAYING
	_check(gfc.get_flow_state() == gfc.FlowState.PLAYING, "simulated in-game state", str(gfc.get_flow_state()))
	# 退出路径（game_scene._exit_to_menu / 登出 的统一出口）
	gfc.reset_flow()
	_check(gfc.get_flow_state() == gfc.FlowState.IDLE, "exit resets to IDLE", str(gfc.get_flow_state()))

	print("== T5: 重新登录 → 再次进入游戏（旧 bug: ABORT at IN_GAME）==")
	gfc.begin_authentication()
	var login2_ok: bool = await _login(api, cfg, tm)
	_check(login2_ok, "re-login succeeded", str(login2_ok))
	var flow2_ok: bool = await _run_full_flow(gfc)
	_check(flow2_ok, "second full flow completed (no ABORT)", str(flow2_ok))
	_check(gfc.get_flow_state() == gfc.FlowState.READY, "state = READY after re-login", str(gfc.get_flow_state()))

	print("== T6: 收尾重置 ==")
	gfc.reset_flow()
	_check(gfc.get_flow_state() == gfc.FlowState.IDLE, "final state IDLE")

	print("")
	print("Results: ", _passed, " passed, ", _failures.size(), " failed")
	for f in _failures:
		print("  FAILED: ", f)
	print("  ✓ all ", _passed + _failures.size(), " checks executed (no runtime aborts)")
	quit(0 if _failures.is_empty() else 1)
