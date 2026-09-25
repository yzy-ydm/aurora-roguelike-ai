## 武器存档恢复测试 (TASK-030)
##
## 真实 HTTP 流程: 获得冰霜法杖 → 保存 → 退出 → 重新加载 → 新玩家初始化
## 验证武器一致（ID/名称/类型/伤害/等级），默认武器不得覆盖保存武器。
##
## 覆盖 TASK-030 修复:
##   - set_current_save 从 player_state 嵌套内恢复 weapon_id/weapon_level
##   - _load_weapon_data 应用保存的武器等级（旧实现恒 Lv1）
##
## 运行前提: 游戏服务端 :8000 与 MySQL 运行中; 运行前用清理工具清空 test001 存档
## 运行方式（无头模式）:
##   Godot_v4.7-stable_win64_console.exe --headless --path client --script res://tests/test_weapon_save_restore.gd

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

	print("== T1: 登录 ==")
	var login_ok: bool = await _login(api, cfg, tm)
	_check(login_ok, "login succeeded")

	print("== T2: 获得冰霜法杖（id=3, damage=25, type=ice）==")
	var player := CharacterBody2D.new()
	player.set_script(load("res://scripts/player/player_controller.gd"))
	player._setup_weapon()
	var equip_ok: bool = player.equip_new_weapon(3)
	_check(equip_ok, "equip 冰霜法杖 succeeded")
	var weapon: Node = player.get_node_or_null("Weapon")
	var inst = weapon.get_weapon_instance() if weapon else null
	_check(inst != null and inst.get_name() == "冰霜法杖", "weapon name = 冰霜法杖", str(inst.get_name() if inst else "null"))
	_check(inst != null and inst.get_weapon_type() == "ice", "weapon type = ice", str(inst.get_weapon_type() if inst else "null"))
	_check(inst != null and inst.get_damage() == 25, "weapon damage = 25 (Lv1)", str(inst.get_damage() if inst else -1))
	_check(int(gsm.get_extended_save_data().get("weapon_id", -1)) == 3,
		"extended save data weapon_id=3", str(gsm.get_extended_save_data()))
	# 升级一次再保存（验证等级恢复）
	player.upgrade_weapon()
	_check(int(gsm.get_extended_save_data().get("weapon_level", -1)) == 2,
		"extended save data weapon_level=2 after upgrade", str(gsm.get_extended_save_data()))

	print("== T3: 保存（真实 HTTP）==")
	gsm.set_runtime_stats(player.get_stats())
	gsm.set_current_slot(1)
	gsm.set_current_floor(2)
	var save_data: Dictionary = gsm.get_save_data()
	var save_box: Dictionary = await _do_save(svc, 1, save_data)
	_check(save_box["ok"], "save succeeded", str(save_box["msg"]))

	print("== T4: 退出 → 重新加载存档 → 扩展数据恢复 ==")
	gsm.reset_run_state()
	var load_box: Dictionary = await _do_load_saves(svc)
	var slot1: Dictionary = svc.get_save_by_slot(1)
	_check(slot1.size() > 0, "slot1 save readable after reload", str(slot1))
	gsm.set_current_save(slot1, 1)
	_check(int(gsm.get_extended_save_data().get("weapon_id", -1)) == 3,
		"weapon_id restored from save (nested player_state)", str(gsm.get_extended_save_data()))
	_check(int(gsm.get_extended_save_data().get("weapon_level", -1)) == 2,
		"weapon_level restored = 2 (TASK-030 fix)", str(gsm.get_extended_save_data()))

	print("== T5: 新玩家初始化 → 恢复冰霜法杖（默认武器不得覆盖）==")
	var player2 := CharacterBody2D.new()
	player2.set_script(load("res://scripts/player/player_controller.gd"))
	player2._setup_weapon()
	var weapon2: Node = player2.get_node_or_null("Weapon")
	var inst2 = weapon2.get_weapon_instance() if weapon2 else null
	_check(inst2 != null and inst2.get_name() == "冰霜法杖",
		"restored weapon = 冰霜法杖 (not default)", str(inst2.get_name() if inst2 else "null"))
	_check(inst2 != null and inst2.get_level() == 2, "restored weapon Lv2", str(inst2.get_level() if inst2 else -1))
	_check(inst2 != null and inst2.get_damage() == 30, "restored damage = 25+5*1 = 30", str(inst2.get_damage() if inst2 else -1))
	_check(inst2 != null and inst2.get_weapon_type() == "ice", "restored type = ice", str(inst2.get_weapon_type() if inst2 else "null"))

	print("")
	print("Results: ", _passed, " passed, ", _failures.size(), " failed")
	for f in _failures:
		print("  FAILED: ", f)
	print("  ✓ all ", _passed + _failures.size(), " checks executed (no runtime aborts)")
	quit(0 if _failures.is_empty() else 1)
