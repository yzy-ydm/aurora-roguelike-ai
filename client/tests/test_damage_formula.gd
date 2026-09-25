## 武器伤害公式测试 (TASK-028)
##
## 覆盖:
## 1. WeaponInstance 线性成长公式（无指数叠加）: base + growth*(Lv-1)
## 2. calculate_damage 纯函数: 攻击+武器 → 防御减伤 → 取整
## 3. on_bullet_hit 武器伤害只计一次（修复双重计入）:
##    旧公式 base=(attack+weapon)+weapon；新公式 base=attack(已含weapon)
## 4. 怪物→玩家伤害: 防御百分比减伤只算一次（PlayerStats 二次减伤已移除）
##
## 运行方式（无头模式）:
##   Godot_v4.7-stable_win64_console.exe --headless --path client --script res://tests/test_damage_formula.gd

extends SceneTree

var _failures: Array[String] = []
var _passed: int = 0

const WeaponDataScript = preload("res://scripts/models/weapon_data.gd")
const WeaponInstanceScript = preload("res://scripts/combat/weapon_instance.gd")

## 桩: 玩家源（get_attack 已含武器伤害，与 player_controller.get_attack 契约一致）
class StubSource extends Node2D:
	var attack_value: int = 30
	func get_attack() -> int:
		return attack_value

## 桩: 子弹
class StubBullet extends Node2D:
	var _source: Node2D = null
	var dmg: int = 20
	var crit: bool = false
	func get_damage() -> int:
		return dmg
	func get_is_critical() -> bool:
		return crit
	func get_source() -> Node2D:
		return _source
	func destroy() -> void:
		pass

## 桩: 目标（记录最终伤害）
class StubTarget extends Node2D:
	var recorded: int = -1
	var defense_value: int = 0
	func get_defense() -> int:
		return defense_value
	func take_damage(damage: int, _attacker_position: Vector2 = Vector2.ZERO) -> void:
		recorded = damage

## 桩: 怪物攻击者
class StubMonster extends Node2D:
	var atk: int = 15
	class StubEntity:
		var attack_value: int = 15
		func get_attack() -> int:
			return attack_value
	var entity = StubEntity.new()
	func get_monster_entity():
		return entity

## 桩: 玩家目标（受击方，返回玩家数据）
class StubPlayerTarget extends Node2D:
	var recorded: int = -1
	var defense_value: int = 0
	func get_player_data() -> Dictionary:
		return {"defense": defense_value, "current_health": 100, "max_health": 100}
	func take_damage(damage: int, _attacker_position: Vector2 = Vector2.ZERO) -> void:
		recorded = damage

func _initialize() -> void:
	_run()

func _check(cond: bool, name: String, detail: String = "") -> void:
	if cond:
		_passed += 1
		print("  ✓ ", name)
	else:
		_failures.append(name + ((" | " + detail) if detail != "" else ""))
		print("  ✗ ", name, " | ", detail)

func _make_weapon_data(base: int, growth: int, max_lv: int):
	var wd = WeaponDataScript.new()
	wd.damage = base
	wd.base_damage = base
	wd.damage_growth = growth
	wd.max_level = max_lv
	wd.name = "test_weapon"
	return wd

func _run() -> void:
	await process_frame

	print("== T1: WeaponInstance 线性成长（无指数叠加）==")
	var wd = _make_weapon_data(20, 8, 10)  # TASK-028: 默认武器 growth=8
	var inst = WeaponInstanceScript.create(wd)
	_check(inst.get_damage() == 20, "Lv1 damage = base = 20", str(inst.get_damage()))
	inst.set_level(5)
	_check(inst.get_damage() == 52, "Lv5 = 20 + 8*4 = 52 (linear)", str(inst.get_damage()))
	inst.set_level(10)
	_check(inst.get_damage() == 92, "Lv10 = 20 + 8*9 = 92 (linear, capped)", str(inst.get_damage()))

	print("== T2: calculate_damage 纯函数 ==")
	var ds := Node.new()
	ds.set_script(load("res://scripts/combat/damage_system.gd"))
	var r1: Dictionary = ds.calculate_damage(30, 0, 0, 0.0)
	_check(int(r1["damage"]) == 30, "base 30 def 0 -> 30", str(r1))
	var r2: Dictionary = ds.calculate_damage(30, 0, 5, 0.0)
	_check(int(r2["damage"]) == 28, "base 30 def 5 -> 30*(1-5/105)=28", str(r2))

	print("== T3: 子弹命中——武器伤害只计一次（双重计入修复）==")
	var src := StubSource.new()
	src.attack_value = 30  # = 攻击10 + 武器20（get_attack 契约）
	var bullet := StubBullet.new()
	bullet._source = src
	bullet.dmg = 20  # 旧公式会再加一次 → 50
	var target := StubTarget.new()
	target.defense_value = 0
	ds.on_bullet_hit(bullet, target)
	_check(target.recorded == 30, "bullet hit damage = 30 (weapon counted once, old bug would be 50)", str(target.recorded))

	print("== T4: 怪物→玩家——防御只减伤一次 ==")
	var monster := StubMonster.new()
	monster.entity.attack_value = 15
	var player_target := StubPlayerTarget.new()
	player_target.defense_value = 0
	ds.on_monster_attack_player(monster, player_target)
	_check(player_target.recorded == 15, "monster attack 15 vs def 0 -> 15 (no double reduction)", str(player_target.recorded))
	player_target.recorded = -1
	player_target.defense_value = 5
	ds.on_monster_attack_player(monster, player_target)
	_check(player_target.recorded == 14, "monster attack 15 vs def 5 -> 14 (percent reduction once)", str(player_target.recorded))

	print("")
	print("Results: ", _passed, " passed, ", _failures.size(), " failed")
	for f in _failures:
		print("  FAILED: ", f)
	print("  ✓ all ", _passed + _failures.size(), " checks executed (no runtime aborts)")
	quit(0 if _failures.is_empty() else 1)
