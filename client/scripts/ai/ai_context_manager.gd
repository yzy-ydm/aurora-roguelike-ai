## AI上下文管理器 (Phase 13)
##
## 负责管理游戏上下文信息
## 所有AI请求必须携带context
## 提供统一的上下文构建接口

extends Node

## ==================== 引用 ====================

## 行为分析器引用
var _behavior_analyzer: Node = null

## 玩家引用
var _player: CharacterBody2D = null

## FloorManager引用
var _floor_manager: Node = null

## CombatManager引用
var _combat_manager: Node = null

## UpgradeManager引用
var _upgrade_manager: Node = null

## NPC记忆管理器引用
var _npc_memory_manager: Node = null


## ==================== 初始化 ====================

func _ready() -> void:
	print("[AIContextManager] Initialized")


## 设置引用
func set_behavior_analyzer(analyzer: Node) -> void:
	_behavior_analyzer = analyzer


func set_player(player: CharacterBody2D) -> void:
	_player = player


func set_floor_manager(fm: Node) -> void:
	_floor_manager = fm


func set_combat_manager(cm: Node) -> void:
	_combat_manager = cm


func set_upgrade_manager(um: Node) -> void:
	_upgrade_manager = um


func set_npc_memory_manager(nm: Node) -> void:
	_npc_memory_manager = nm


## ==================== 上下文构建 ====================

## 获取完整游戏上下文
func get_full_context() -> Dictionary:
	var context = {}

	# 玩家信息
	context["player"] = _get_player_context()

	# 楼层信息
	context["floor"] = _get_floor_context()

	# 战斗信息
	context["combat"] = _get_combat_context()

	# 成长信息
	context["progression"] = _get_progression_context()

	# 行为分析
	context["behavior"] = _get_behavior_context()

	# NPC关系
	context["npc_relations"] = _get_npc_relations()

	# 时间信息
	context["timestamp"] = Time.get_unix_time_from_system()

	return context


## 获取玩家上下文 (Phase 9.4.1: 使用get_player_data())
func _get_player_context() -> Dictionary:
	if not _player:
		return {}

	var data = _player.get_player_data()
	return {
		"level": data.get("level", 1),
		"current_health": data.get("current_health", 100),
		"max_health": data.get("max_health", 100),
		"attack": data.get("attack", 10),
		"defense": data.get("defense", 5),
		"gold": data.get("gold", 0),
		"move_speed": data.get("move_speed", 200),
		"crit_rate": data.get("crit_rate", 0.0),
		"crit_damage": data.get("crit_damage", 0.0)
	}


## 获取楼层上下文
func _get_floor_context() -> Dictionary:
	if not _floor_manager:
		return {}

	var current_room = _floor_manager.get_current_room()
	return {
		"floor_level": _floor_manager.get_floor_level(),
		"room_id": current_room.id if current_room else -1,
		"room_type": current_room.get_type_string() if current_room else "unknown",
		"is_floor_complete": _floor_manager.is_floor_complete()
	}


## 获取战斗上下文
func _get_combat_context() -> Dictionary:
	if not _combat_manager:
		return {}

	return {
		"state": _combat_manager.get_state(),
		"is_in_combat": _combat_manager.is_in_combat(),
		"is_boss_fight": _combat_manager.is_boss_fight(),
		"dead_count": _combat_manager.get_dead_count(),
		"total_count": _combat_manager.get_total_count()
	}


## 获取成长上下文
func _get_progression_context() -> Dictionary:
	if not _upgrade_manager:
		return {}

	return {
		"level": _upgrade_manager.get_current_level(),
		"current_exp": _upgrade_manager.get_current_exp(),
		"exp_to_next": _upgrade_manager.get_exp_to_next_level(),
		"applied_upgrades_count": _upgrade_manager.get_applied_upgrades().size()
	}


## 获取行为上下文
func _get_behavior_context() -> Dictionary:
	if not _behavior_analyzer:
		return {}

	return {
		"combat_style": _behavior_analyzer.get_combat_style(),
		"upgrade_preference": _behavior_analyzer.get_upgrade_preference(),
		"behavior_data": _behavior_analyzer.get_behavior_dict()
	}


## 获取NPC关系
func _get_npc_relations() -> Dictionary:
	if not _npc_memory_manager:
		return {}

	return _npc_memory_manager.get_all_memories_dict()


## ==================== 精简上下文 ====================

## 获取精简上下文(用于不需要完整信息的请求)
func get_lightweight_context() -> Dictionary:
	return {
		"player_level": _get_player_level(),
		"floor_level": _get_floor_level(),
		"combat_style": _get_combat_style(),
		"upgrade_preference": _get_upgrade_preference()
	}


## 获取玩家等级 (Phase 9.4.1: 使用get_player_data())
func _get_player_level() -> int:
	if _player:
		return _player.get_player_data().get("level", 1)
	return 1


## 获取楼层等级
func _get_floor_level() -> int:
	if _floor_manager:
		return _floor_manager.get_floor_level()
	return 1


## 获取战斗风格
func _get_combat_style() -> String:
	if _behavior_analyzer:
		return _behavior_analyzer.get_combat_style()
	return "unknown"


## 获取升级偏好
func _get_upgrade_preference() -> String:
	if _behavior_analyzer:
		return _behavior_analyzer.get_upgrade_preference()
	return "unknown"


## ==================== 特定上下文 ====================

## 获取难度调整上下文
func get_difficulty_context() -> Dictionary:
	var context = get_lightweight_context()

	if _behavior_analyzer:
		var behavior = _behavior_analyzer.get_behavior_data()
		if behavior:
			context["damage_rate"] = behavior.get_damage_rate()
			context["death_rate"] = behavior.get_death_rate()
			context["no_hit_rate"] = behavior.get_no_hit_rate()
			context["average_combat_time"] = behavior.get_average_combat_time()
			context["total_kills"] = behavior.total_kills
			context["death_count"] = behavior.death_count

	return context


## 获取房间策略上下文
func get_room_strategy_context() -> Dictionary:
	var context = get_lightweight_context()

	if _behavior_analyzer:
		var behavior = _behavior_analyzer.get_behavior_data()
		if behavior:
			context["preferred_weapon"] = behavior.get_preferred_weapon()
			context["room_route"] = behavior.room_route
			context["current_health_percent"] = _get_health_percent()

	return context


## 获取事件上下文
func get_event_context() -> Dictionary:
	var context = get_full_context()

	if _behavior_analyzer:
		var behavior = _behavior_analyzer.get_behavior_data()
		if behavior:
			context["event_history"] = behavior.event_choices

	return context


## 获取NPC对话上下文
func get_npc_context(npc_id: String) -> Dictionary:
	var context = get_lightweight_context()

	if _npc_memory_manager:
		context["npc_memory"] = _npc_memory_manager.get_memory_dict(npc_id)
		context["relationship"] = _npc_memory_manager.get_relationship(npc_id)

	return context


## ==================== 工具方法 ====================

## 获取玩家生命百分比 (Phase 9.4.1: 使用get_player_data())
func _get_health_percent() -> float:
	if _player:
		var data = _player.get_player_data()
		var current = data.get("current_health", 100)
		var max_hp = data.get("max_health", 100)
		if max_hp > 0:
			return float(current) / float(max_hp)
	return 1.0
