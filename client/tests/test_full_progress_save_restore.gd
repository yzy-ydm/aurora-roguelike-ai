## 完整进度保存恢复测试 (Phase 18.1)
##
## 用户指定流程（真实 HTTP）:
##   创建新玩家 → 获得 金币100/等级5/经验300/生命300/攻击50/冰霜法杖Lv3
##   → 保存 → 重新加载 → 断言所有字段一致。
##
## 并完整仿真真实登录流程（含 profile 步骤——profile 响应使用 "health" 字段
## 而 PlayerStats/HUD 读 "current_health"，是"恢复后 HUD 显示 0/100"的根因之一）。
##
## 运行前提: 游戏服务端 :8000 与 MySQL 运行中; 运行前用清理工具清空 test001 存档
## 运行方式（无头模式）:
##   Godot_v4.7-stable_win64_console.exe --headless --path client --script res://tests/test_full_progress_save_restore.gd

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

func _fetch_profile(api: Node, cfg: Node) -> Dictionary:
	var box := {"done": false, "res": null}
	var handler := func(res: Variant) -> void:
		box["done"] = true
		box["res"] = res
	api.request_completed.connect(handler)
	api.get_request(cfg.PLAYER_PROFILE, true)
	var waited := 0
	while not box["done"] and waited < 300:
		await process_frame
		waited += 1
	api.request_completed.disconnect(handler)
	return box["res"] if box["res"] is Dictionary else {}

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

	print("== T1: 登录 + 获取 profile（真实流程第一步）==")
	var login_ok: bool = await _login(api, cfg, tm)
	_check(login_ok, "login succeeded")
	var profile: Dictionary = await _fetch_profile(api, cfg)
	_check(profile.has("nickname"), "profile fetched", str(profile))
	gsm.set_player_data(profile)
	print("  profile 原始形状: health 字段=", str(profile.get("health", "无")), " current_health 字段=", str(profile.get("current_health", "无")))

	print("== T2: 创建目标状态（金币100/等级5/经验300/生命300/攻击50/冰霜法杖Lv3）==")
	var player := CharacterBody2D.new()
	player.set_script(load("res://scripts/player/player_controller.gd"))
	player._setup_weapon()
	player.equip_new_weapon(3)  # 冰霜法杖
	player.upgrade_weapon()
	player.upgrade_weapon()     # Lv3
	var s = player.get_stats()
	s.level = 5
	s.experience = 300
	s.experience_to_next = 506
	s.max_health = 300
	s.current_health = 300
	s.attack = 50
	s.defense = 7
	s.gold = 100
	gsm.set_runtime_stats(s)
	gsm.set_current_slot(1)
	gsm.set_current_floor(4)
	var weapon = player.get_node_or_null("Weapon")
	var wi = weapon.get_weapon_instance()
	_check(wi.get_level() == 3 and wi.get_damage() == 35, "frost staff Lv3 damage=35", str(wi.get_level()) + "/" + str(wi.get_damage()))

	print("== T3: 保存（真实 HTTP）==")
	var save_data: Dictionary = gsm.get_save_data()
	var save_box: Dictionary = await _do_save(svc, 1, save_data)
	_check(save_box["ok"], "save succeeded", str(save_box["msg"]))
	_check(int(save_data.get("player_state", {}).get("level", 0)) == 5, "save data contains level=5")
	_check(int(save_data.get("player_state", {}).get("weapon_id", 0)) == 3, "save data contains weapon_id=3")

	print("== T4: 模拟重新登录（profile 重新写入 → 读取存档 → 恢复）==")
	# 真实流程: 登录后 set_player_data(profile) 会再次执行
	gsm.reset_run_state()
	gsm.set_player_data(profile)
	var load_box: Dictionary = await _do_load_saves(svc)
	var slot1: Dictionary = svc.get_save_by_slot(1)
	_check(slot1.size() > 0, "save readable after re-login")
	gsm.set_current_save(slot1, 1)

	print("== T5: 新玩家初始化（模拟游戏场景 player._ready 链接链）==")
	var player2 := CharacterBody2D.new()
	player2.set_script(load("res://scripts/player/player_controller.gd"))
	# 模拟 _link_stats_to_game_state
	var s2 = player2.get_stats()
	var cached2: Dictionary = gsm.get_player_data()
	if cached2.size() > 0:
		s2.sync_from_dict(cached2)
	gsm.set_runtime_stats(s2)
	player2._setup_weapon()

	print("== T6: 断言所有字段一致 ==")
	var final_data: Dictionary = player2.get_player_data()
	_check(int(final_data.get("level", -1)) == 5, "level restored = 5", str(final_data.get("level")))
	_check(int(final_data.get("experience", -1)) == 300, "experience restored = 300", str(final_data.get("experience")))
	_check(int(final_data.get("max_health", -1)) == 300, "max_health restored = 300", str(final_data.get("max_health")))
	_check(int(final_data.get("current_health", -1)) == 300, "current_health restored = 300", str(final_data.get("current_health")))
	_check(int(final_data.get("attack", -1)) == 50, "attack restored = 50", str(final_data.get("attack")))
	_check(int(final_data.get("gold", -1)) == 100, "gold restored = 100", str(final_data.get("gold")))
	var wi2 = player2.get_node_or_null("Weapon")
	var inst2 = wi2.get_weapon_instance() if wi2 else null
	_check(inst2 != null and inst2.get_name() == "冰霜法杖" and inst2.get_level() == 3 and inst2.get_damage() == 35,
		"weapon restored = 冰霜法杖 Lv3 damage 35",
		str(inst2.get_name() if inst2 else "null") + "/" + str(inst2.get_level() if inst2 else -1) + "/" + str(inst2.get_damage() if inst2 else -1))
	_check(gsm.get_current_floor() == 4, "floor restored = 4", str(gsm.get_current_floor()))
	# HUD 视角: update_hud 读取的字段必须完整
	_check(int(final_data.get("current_health", 0)) > 0, "HUD data source has current_health (non-zero)", str(final_data.get("current_health")))
	_check(final_data.has("experience_to_next"), "HUD data source has experience_to_next")

	print("")
	print("Results: ", _passed, " passed, ", _failures.size(), " failed")
	for f in _failures:
		print("  FAILED: ", f)
	print("  ✓ all ", _passed + _failures.size(), " checks executed (no runtime aborts)")
	quit(0 if _failures.is_empty() else 1)
