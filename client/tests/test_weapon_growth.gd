## 武器成长系统测试 (Phase 9.3.1)
##
## 测试WeaponInstance的等级成长逻辑
## 运行方式: 在Godot编辑器中附加到任意节点运行
##
## 测试用例:
## 铁剑 Lv1: damage=10
## 升级一次: damage=15
## 升级两次: damage=20

extends Node

## 测试结果
var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	print("========================================")
	print("  Weapon Growth System Tests")
	print("========================================")

	test_iron_sword_growth()
	test_max_level()
	test_damage_formula()
	test_backward_compatibility()

	print("========================================")
	print("  Results: ", _passed, " passed, ", _failed, " failed")
	print("========================================")

	# 测试完成后自动退出
	get_tree().quit()


## 测试铁剑成长 (核心测试用例)
func test_iron_sword_growth() -> void:
	print("\n--- Test: Iron Sword Growth ---")

	# 创建铁剑数据 (base_damage=10, damage_growth=5, max_level=10)
	var iron_sword = _create_iron_sword_data()

	# 创建实例，初始等级1
	var instance = WeaponInstance.create(iron_sword, 1)

	# Lv1: damage should be 10
	_assert_equal("Iron Sword Lv1 damage", 10, instance.get_damage())

	# Upgrade to Lv2: damage should be 15
	instance.upgrade()
	_assert_equal("Iron Sword Lv2 damage", 15, instance.get_damage())

	# Upgrade to Lv3: damage should be 20
	instance.upgrade()
	_assert_equal("Iron Sword Lv3 damage", 20, instance.get_damage())


## 测试最大等级限制
func test_max_level() -> void:
	print("\n--- Test: Max Level ---")

	var sword_data = _create_iron_sword_data()
	sword_data.max_level = 3

	var instance = WeaponInstance.create(sword_data, 1)

	# 升级到Lv3
	instance.upgrade()
	instance.upgrade()
	_assert_equal("At max level", 3, instance.get_level())
	_assert_equal("Is max level", true, instance.is_max_level())

	# 尝试继续升级应该失败
	var result = instance.upgrade()
	_assert_equal("Cannot upgrade past max", false, result)
	_assert_equal("Still at max level", 3, instance.get_level())


## 测试伤害公式
func test_damage_formula() -> void:
	print("\n--- Test: Damage Formula ---")

	var data = WeaponData.new()
	data.name = "test_weapon"
	data.damage = 50        # 旧字段
	data.base_damage = 30   # 新字段（优先使用）
	data.damage_growth = 8
	data.max_level = 5

	var instance = WeaponInstance.create(data, 1)

	# Lv1: base_damage + damage_growth * (1-1) = 30
	_assert_equal("Formula Lv1", 30, instance.get_damage())

	# Lv3: 30 + 8 * 2 = 46
	instance.set_level(3)
	_assert_equal("Formula Lv3", 46, instance.get_damage())

	# Lv5: 30 + 8 * 4 = 62
	instance.set_level(5)
	_assert_equal("Formula Lv5", 62, instance.get_damage())


## 测试向后兼容（base_damage=0时使用damage字段）
func test_backward_compatibility() -> void:
	print("\n--- Test: Backward Compatibility ---")

	var data = WeaponData.new()
	data.name = "old_weapon"
	data.damage = 20        # 旧字段
	data.base_damage = 0    # 未设置
	data.damage_growth = 5
	data.max_level = 10

	var instance = WeaponInstance.create(data, 1)

	# base_damage=0时，使用damage字段作为base
	_assert_equal("Compat Lv1", 20, instance.get_damage())

	# Lv2: 20 + 5 = 25
	instance.upgrade()
	_assert_equal("Compat Lv2", 25, instance.get_damage())


## ==================== 辅助方法 ====================

## 创建铁剑测试数据
func _create_iron_sword_data() -> WeaponData:
	var data = WeaponData.new()
	data.id = 1
	data.name = "iron_sword"
	data.description = "铁剑"
	data.type = "melee"
	data.rarity = "common"
	data.damage = 10
	data.base_damage = 10
	data.damage_growth = 5
	data.max_level = 10
	data.fire_rate = 0.5
	data.bullet_speed = 0.0
	data.bullet_count = 1
	data.range = 50.0
	return data


## 断言相等
func _assert_equal(test_name: String, expected, actual) -> void:
	if expected == actual:
		print("  ✓ ", test_name, ": ", actual)
		_passed += 1
	else:
		print("  ✗ ", test_name, ": expected ", expected, " got ", actual)
		_failed += 1
