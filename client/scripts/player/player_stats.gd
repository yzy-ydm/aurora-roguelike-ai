## 玩家属性系统 (Phase 9.3.2, Phase 9.4.1 增强)
##
## 统一管理玩家属性，替代原始Dictionary
## 提供类型安全的属性访问和修改
## Phase 9.4.1: 成为PlayerController的属性Source of Truth
##
## 职责:
## - 管理基础属性 (生命、攻击、防御等)
## - 管理等级和经验值
## - 管理百分比加成 (暴击率、移动速度等)
## - 提供属性查询接口
## - 支持序列化/反序列化

class_name PlayerStats
extends RefCounted

## ==================== 基础属性 ====================

var max_health: int = 100
var current_health: int = 100
var attack: int = 10
var defense: int = 0
var move_speed: float = 200.0
var gold: int = 0

## ==================== 等级和经验 (Phase 9.4.1) ====================

var level: int = 1
var experience: int = 0
var experience_to_next: int = 100

## ==================== 百分比加成 ====================

var crit_rate_bonus: float = 0.0      # 暴击率加成 (0.0-1.0)
var crit_damage_bonus: float = 0.0    # 暴击伤害加成 (0.0+)
var move_speed_bonus: float = 0.0     # 移动速度加成 (0.0+)
var exp_rate_bonus: float = 0.0       # 经验获取加成 (0.0+)
var heal_on_kill: int = 0             # 击杀回复生命

## ==================== 被动物品 ====================

var passive_items: Array[String] = []

## ==================== 兼容字段 (Phase 9.4.1) ====================

var nickname: String = "未知玩家"

## ==================== 初始化 ====================

## 从Dictionary创建
static func from_dict(data: Dictionary) -> PlayerStats:
	var stats = PlayerStats.new()
	stats.max_health = data.get("max_health", 100)
	stats.current_health = data.get("current_health", stats.max_health)
	stats.attack = data.get("attack", 10)
	stats.defense = data.get("defense", 0)
	stats.move_speed = data.get("move_speed", 200.0)
	stats.gold = data.get("gold", 0)

	stats.level = data.get("level", 1)
	stats.experience = data.get("experience", 0)
	stats.experience_to_next = data.get("experience_to_next", 100)
	stats.nickname = data.get("nickname", "未知玩家")

	stats.crit_rate_bonus = data.get("crit_rate_bonus", 0.0)
	stats.crit_damage_bonus = data.get("crit_damage_bonus", 0.0)
	stats.move_speed_bonus = data.get("move_speed_bonus", 0.0)
	stats.exp_rate_bonus = data.get("exp_rate_bonus", 0.0)
	stats.heal_on_kill = data.get("heal_on_kill", 0)

	var items = data.get("passive_items", [])
	for item in items:
		if item is String:
			stats.passive_items.append(item)

	return stats


## 转换为Dictionary (兼容旧系统)
func to_dict() -> Dictionary:
	return {
		"max_health": max_health,
		"current_health": current_health,
		"attack": attack,
		"defense": defense,
		"move_speed": move_speed,
		"gold": gold,
		"level": level,
		"experience": experience,
		"experience_to_next": experience_to_next,
		# HUD兼容字段 (Phase 9.4.2)
		"current_exp": experience,
		"max_exp": experience_to_next,
		"nickname": nickname,
		"crit_rate_bonus": crit_rate_bonus,
		"crit_damage_bonus": crit_damage_bonus,
		"move_speed_bonus": move_speed_bonus,
		"exp_rate_bonus": exp_rate_bonus,
		"heal_on_kill": heal_on_kill,
		"passive_items": passive_items,
	}


## ==================== 属性修改 ====================

## 添加攻击力
func add_attack(amount: int) -> void:
	attack += amount
	print("[PlayerStats] Attack +", amount, " -> ", attack)


## 添加最大生命值
func add_max_health(amount: int) -> void:
	max_health += amount
	current_health += amount
	print("[PlayerStats] Max Health +", amount, " -> ", max_health)


## 添加防御力
func add_defense(amount: int) -> void:
	defense += amount
	print("[PlayerStats] Defense +", amount, " -> ", defense)


## 添加金币
func add_gold(amount: int) -> void:
	gold += amount
	print("[PlayerStats] Gold +", amount, " -> ", gold)


## 治疗
func heal(amount: int) -> void:
	var old_health = current_health
	current_health = min(current_health + amount, max_health)
	print("[PlayerStats] Heal ", amount, " HP (", old_health, " -> ", current_health, ")")


## 获得经验 (Phase 9.4.1, Phase 9.4.2 增加经验加成)
## 返回是否升级
func gain_exp(amount: int) -> bool:
	# 应用经验加成
	var actual_amount = int(amount * (1.0 + exp_rate_bonus))
	experience += actual_amount
	print("[PlayerStats] EXP +", actual_amount, " (base:", amount, " bonus:", exp_rate_bonus, ") -> ", experience, "/", experience_to_next)

	if experience >= experience_to_next:
		_level_up()
		return true
	return false


## 升级处理 (Phase 9.4.1)
func _level_up() -> void:
	level += 1
	experience -= experience_to_next
	experience_to_next = _calculate_exp_to_next(level)

	# 升级奖励: 生命全恢复 + 属性提升
	current_health = max_health
	attack += 2
	max_health += 10
	current_health = max_health  # 升级后满血

	print("[PlayerStats] LEVEL UP! Lv", level, " ATK:", attack, " HP:", max_health)


## 计算升级所需经验 (Phase 9.4.1)
static func _calculate_exp_to_next(lvl: int) -> int:
	return int(100 * pow(1.5, lvl - 1))


## 受到伤害
func take_damage(amount: int) -> int:
	var actual_damage = max(1, amount - defense)
	current_health = max(0, current_health - actual_damage)
	print("[PlayerStats] Took ", actual_damage, " damage (", current_health, "/", max_health, ")")
	return actual_damage


## 是否死亡
func is_dead() -> bool:
	return current_health <= 0


## 复活
func revive() -> void:
	current_health = max_health
	print("[PlayerStats] Revived with ", current_health, " HP")


## ==================== 百分比加成 ====================

## 添加暴击率加成
func add_crit_rate_bonus(amount: float) -> void:
	crit_rate_bonus += amount
	print("[PlayerStats] Crit Rate Bonus +", amount, " -> ", crit_rate_bonus)


## 添加暴击伤害加成
func add_crit_damage_bonus(amount: float) -> void:
	crit_damage_bonus += amount
	print("[PlayerStats] Crit Damage Bonus +", amount, " -> ", crit_damage_bonus)


## 添加移动速度加成
func add_move_speed_bonus(amount: float) -> void:
	move_speed_bonus += amount
	print("[PlayerStats] Move Speed Bonus +", amount, " -> ", move_speed_bonus)


## ==================== 查询接口 ====================

## 获取最终移动速度 (含加成)
func get_final_move_speed() -> float:
	return move_speed * (1.0 + move_speed_bonus)


## 获取最终暴击率 (含加成)
func get_crit_rate() -> float:
	return 0.1 + crit_rate_bonus  # 基础10% + 加成


## 获取最终暴击倍率
func get_crit_multiplier() -> float:
	return 1.5 + crit_damage_bonus


## 获取经验加成倍率
func get_exp_multiplier() -> float:
	return 1.0 + exp_rate_bonus


## 是否有指定被动
func has_passive(passive_id: String) -> bool:
	return passive_id in passive_items


## 添加被动 (Phase 9.5.1: 增强日志)
func add_passive(passive_id: String) -> void:
	if passive_id not in passive_items:
		passive_items.append(passive_id)
		print("[PlayerStats] Added passive: ", passive_id, " | Total: ", passive_items.size())


## 移除被动 (Phase 9.5.1)
func remove_passive(passive_id: String) -> void:
	if passive_id in passive_items:
		passive_items.erase(passive_id)
		print("[PlayerStats] Removed passive: ", passive_id, " | Total: ", passive_items.size())


## 获取所有被动物品列表 (Phase 9.5.1)
func get_passive_items() -> Array[String]:
	return passive_items


## ==================== 同步接口 (Phase 9.4.1) ====================

## 从Dictionary增量同步（不覆盖未传入的字段）
func sync_from_dict(data: Dictionary) -> void:
	if data.has("max_health"):
		max_health = data["max_health"]
	if data.has("current_health"):
		current_health = data["current_health"]
	if data.has("attack"):
		attack = data["attack"]
	if data.has("defense"):
		defense = data["defense"]
	if data.has("move_speed"):
		move_speed = data["move_speed"]
	if data.has("gold"):
		gold = data["gold"]
	if data.has("level"):
		level = data["level"]
	if data.has("experience"):
		experience = data["experience"]
	if data.has("experience_to_next"):
		experience_to_next = data["experience_to_next"]
	if data.has("nickname"):
		nickname = data["nickname"]
	if data.has("crit_rate_bonus"):
		crit_rate_bonus = data["crit_rate_bonus"]
	if data.has("crit_damage_bonus"):
		crit_damage_bonus = data["crit_damage_bonus"]
	if data.has("move_speed_bonus"):
		move_speed_bonus = data["move_speed_bonus"]
	if data.has("exp_rate_bonus"):
		exp_rate_bonus = data["exp_rate_bonus"]
	if data.has("heal_on_kill"):
		heal_on_kill = data["heal_on_kill"]
	# Phase 9.5.1: 同步被动物品
	if data.has("passive_items"):
		var items = data["passive_items"]
		if items is Array:
			passive_items.clear()
			for item in items:
				if item is String:
					passive_items.append(item)


## 获取经验百分比 (Phase 9.4.1)
func get_exp_percent() -> float:
	if experience_to_next <= 0:
		return 1.0
	return float(experience) / float(experience_to_next)
