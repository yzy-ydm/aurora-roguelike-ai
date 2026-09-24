## 玩家行为数据模型 (Phase 13)
##
## 记录和分析玩家的游戏行为数据
## 用于AI动态调整游戏体验

class_name PlayerBehaviorData
extends RefCounted

## ==================== 战斗数据 ====================

## 总击杀数
var total_kills: int = 0

## 总受到伤害次数
var total_damage_taken: int = 0

## 死亡次数
var death_count: int = 0

## 总战斗时间(秒)
var total_combat_time: float = 0.0

## 战斗次数
var combat_count: int = 0

## 无伤通关次数
var no_hit_clear_count: int = 0

## ==================== 玩法数据 ====================

## 使用武器类型统计 {weapon_type: count}
var weapon_usage: Dictionary = {}

## 属性强化选择历史 [{id, name, type}]
var upgrade_history: Array[Dictionary] = []

## 房间选择路线 [{room_id, room_type}]
var room_route: Array[Dictionary] = []

## 事件选择记录 [{event_id, choice_index, choice_text}]
var event_choices: Array[Dictionary] = []

## ==================== 成长数据 ====================

## 当前等级
var current_level: int = 1

## 当前属性快照
var current_stats: Dictionary = {}

## 最高等级达到
var max_level_reached: int = 1

## ==================== 统计数据 ====================

## 游戏开始时间
var run_start_time: float = 0.0

## 当前楼层
var current_floor: int = 1

## 最高楼层到达
var max_floor_reached: int = 1

## 总游戏时间(秒)
var total_play_time: float = 0.0


## ==================== 方法 ====================

## 记录击杀
func record_kill(count: int = 1) -> void:
	total_kills += count


## 记录受伤
func record_damage_taken(count: int = 1) -> void:
	total_damage_taken += count


## 记录死亡
func record_death() -> void:
	death_count += 1


## 记录战斗
func record_combat(duration: float, no_hit: bool = false) -> void:
	combat_count += 1
	total_combat_time += duration
	if no_hit:
		no_hit_clear_count += 1


## 记录武器使用
func record_weapon_usage(weapon_type: String) -> void:
	if weapon_usage.has(weapon_type):
		weapon_usage[weapon_type] += 1
	else:
		weapon_usage[weapon_type] = 1


## 记录强化选择
func record_upgrade_choice(upgrade_id: String, upgrade_name: String, upgrade_type: String) -> void:
	upgrade_history.append({
		"id": upgrade_id,
		"name": upgrade_name,
		"type": upgrade_type
	})


## 记录房间选择
func record_room_choice(room_id: int, room_type: String) -> void:
	room_route.append({
		"room_id": room_id,
		"room_type": room_type
	})


## 记录事件选择
func record_event_choice(event_id: String, choice_index: int, choice_text: String) -> void:
	event_choices.append({
		"event_id": event_id,
		"choice_index": choice_index,
		"choice_text": choice_text
	})


## 更新等级
func update_level(level: int) -> void:
	current_level = level
	if level > max_level_reached:
		max_level_reached = level


## 更新楼层
func update_floor(floor: int) -> void:
	current_floor = floor
	if floor > max_floor_reached:
		max_floor_reached = floor


## 更新属性快照
func update_stats(stats: Dictionary) -> void:
	current_stats = stats.duplicate()


## ==================== 分析方法 ====================

## 获取平均战斗时间
func get_average_combat_time() -> float:
	if combat_count <= 0:
		return 0.0
	return total_combat_time / combat_count


## 获取受伤率(每次战斗平均受伤次数)
func get_damage_rate() -> float:
	if combat_count <= 0:
		return 0.0
	return float(total_damage_taken) / float(combat_count)


## 获取死亡率(每10次战斗死亡次数)
func get_death_rate() -> float:
	if combat_count <= 0:
		return 0.0
	return float(death_count) / float(combat_count) * 10.0


## 获取无伤通关率
func get_no_hit_rate() -> float:
	if combat_count <= 0:
		return 0.0
	return float(no_hit_clear_count) / float(combat_count)


## 获取偏好武器类型
func get_preferred_weapon() -> String:
	var max_count = 0
	var preferred = ""
	for weapon_type in weapon_usage:
		if weapon_usage[weapon_type] > max_count:
			max_count = weapon_usage[weapon_type]
			preferred = weapon_type
	return preferred


## 获取战斗风格评估
func get_combat_style() -> String:
	var damage_rate = get_damage_rate()
	var death_rate = get_death_rate()
	var no_hit_rate = get_no_hit_rate()

	if no_hit_rate > 0.5:
		return "expert"  # 专家: 高无伤率
	elif death_rate > 3.0:
		return "struggling"  # 困难: 高死亡率
	elif damage_rate > 5.0:
		return "aggressive"  # 激进: 高受伤率
	else:
		return "balanced"  # 平衡


## 获取升级偏好
func get_upgrade_preference() -> String:
	var attack_count = 0
	var health_count = 0
	var defense_count = 0

	for upgrade in upgrade_history:
		match upgrade.get("type", ""):
			"attack":
				attack_count += 1
			"health":
				health_count += 1
			"defense":
				defense_count += 1

	if attack_count > health_count and attack_count > defense_count:
		return "attack"
	elif health_count > attack_count and health_count > defense_count:
		return "health"
	elif defense_count > attack_count and defense_count > health_count:
		return "defense"
	else:
		return "balanced"


## ==================== 序列化 ====================

## 转换为字典
func to_dict() -> Dictionary:
	return {
		"combat": {
			"total_kills": total_kills,
			"total_damage_taken": total_damage_taken,
			"death_count": death_count,
			"total_combat_time": total_combat_time,
			"combat_count": combat_count,
			"no_hit_clear_count": no_hit_clear_count
		},
		"gameplay": {
			"weapon_usage": weapon_usage,
			"upgrade_history": upgrade_history,
			"room_route": room_route,
			"event_choices": event_choices
		},
		"progression": {
			"current_level": current_level,
			"current_stats": current_stats,
			"max_level_reached": max_level_reached,
			"current_floor": current_floor,
			"max_floor_reached": max_floor_reached
		},
		"analysis": {
			"average_combat_time": get_average_combat_time(),
			"damage_rate": get_damage_rate(),
			"death_rate": get_death_rate(),
			"no_hit_rate": get_no_hit_rate(),
			"combat_style": get_combat_style(),
			"upgrade_preference": get_upgrade_preference(),
			"preferred_weapon": get_preferred_weapon()
		},
		"timing": {
			"run_start_time": run_start_time,
			"total_play_time": total_play_time
		}
	}


## 从字典创建
static func from_dict(data: Dictionary) -> PlayerBehaviorData:
	var behavior = PlayerBehaviorData.new()

	var combat = data.get("combat", {})
	behavior.total_kills = combat.get("total_kills", 0)
	behavior.total_damage_taken = combat.get("total_damage_taken", 0)
	behavior.death_count = combat.get("death_count", 0)
	behavior.total_combat_time = combat.get("total_combat_time", 0.0)
	behavior.combat_count = combat.get("combat_count", 0)
	behavior.no_hit_clear_count = combat.get("no_hit_clear_count", 0)

	var gameplay = data.get("gameplay", {})
	behavior.weapon_usage = gameplay.get("weapon_usage", {})
	# TASK-022: 未类型化 Array 不能直接赋给类型化数组成员，逐项验证类型
	for key in ["upgrade_history", "room_route", "event_choices"]:
		var raw_arr = gameplay.get(key, [])
		if raw_arr is Array:
			for item in raw_arr:
				if item is Dictionary:
					match key:
						"upgrade_history":
							behavior.upgrade_history.append(item)
						"room_route":
							behavior.room_route.append(item)
						"event_choices":
							behavior.event_choices.append(item)

	var progression = data.get("progression", {})
	behavior.current_level = progression.get("current_level", 1)
	behavior.current_stats = progression.get("current_stats", {})
	behavior.max_level_reached = progression.get("max_level_reached", 1)
	behavior.current_floor = progression.get("current_floor", 1)
	behavior.max_floor_reached = progression.get("max_floor_reached", 1)

	var timing = data.get("timing", {})
	behavior.run_start_time = timing.get("run_start_time", 0.0)
	behavior.total_play_time = timing.get("total_play_time", 0.0)

	return behavior
