## 行为分析器 (Phase 13)
##
## 负责收集和分析玩家行为数据
## 连接游戏信号，自动记录玩家行为

extends Node

## ==================== 数据 ====================

## 当前运行的行为数据
var _behavior_data: PlayerBehaviorData = null

## 战斗计时器
var _combat_start_time: float = 0.0

## 当前战斗是否无伤
var _current_combat_no_hit: bool = true

## ==================== 引用 ====================

## 玩家引用
var _player: CharacterBody2D = null

## ==================== 信号 ====================

## 行为数据更新
signal behavior_data_updated(data: PlayerBehaviorData)


## ==================== 初始化 ====================

func _ready() -> void:
	reset()


## 重置数据(新运行开始)
func reset() -> void:
	_behavior_data = PlayerBehaviorData.new()
	_behavior_data.run_start_time = Time.get_unix_time_from_system()
	print("[BehaviorAnalyzer] Reset for new run")


## 设置玩家引用
func set_player(player: CharacterBody2D) -> void:
	_player = player


## 获取当前行为数据
func get_behavior_data() -> PlayerBehaviorData:
	return _behavior_data


## ==================== 战斗事件记录 ====================

## 战斗开始
func on_combat_started(monster_count: int) -> void:
	_combat_start_time = Time.get_unix_time_from_system()
	_current_combat_no_hit = true
	print("[BehaviorAnalyzer] Combat started: ", monster_count, " monsters")


## 战斗结束
func on_combat_cleared() -> void:
	var duration = Time.get_unix_time_from_system() - _combat_start_time
	_behavior_data.record_combat(duration, _current_combat_no_hit)
	behavior_data_updated.emit(_behavior_data)
	print("[BehaviorAnalyzer] Combat cleared in ", duration, "s, no_hit: ", _current_combat_no_hit)


## 怪物击杀
func on_monster_killed(dead_count: int, total_count: int) -> void:
	_behavior_data.record_kill()
	behavior_data_updated.emit(_behavior_data)


## 玩家受伤
func on_player_damaged(damage: int, current_health: int) -> void:
	_behavior_data.record_damage_taken()
	_current_combat_no_hit = false
	behavior_data_updated.emit(_behavior_data)


## 玩家死亡
func on_player_death() -> void:
	_behavior_data.record_death()
	behavior_data_updated.emit(_behavior_data)
	print("[BehaviorAnalyzer] Player died. Total deaths: ", _behavior_data.death_count)


## ==================== 成长事件记录 ====================

## 强化选择
func on_upgrade_applied(upgrade) -> void:
	if upgrade:
		# 通过UpgradeData已有的type字段获取类型字符串
		# UpgradeData.UpgradeType枚举: 0=STAT_BOOST, 1=ABILITY, 2=WEAPON_MOD, 3=SPECIAL
		var type_names = ["stat_boost", "ability", "weapon_mod", "special"]
		var type_idx = upgrade.type as int
		var type_str = type_names[type_idx] if type_idx >= 0 and type_idx < type_names.size() else "unknown"
		_behavior_data.record_upgrade_choice(upgrade.id, upgrade.name, type_str)
		behavior_data_updated.emit(_behavior_data)


## 等级提升
func on_level_up(new_level: int) -> void:
	_behavior_data.update_level(new_level)
	behavior_data_updated.emit(_behavior_data)


## 经验获取
func on_exp_gained(amount: int, current_exp: int, exp_to_next: int) -> void:
	# 更新玩家属性快照
	_update_player_stats()


## ==================== 世界事件记录 ====================

## 进入房间
func on_room_entered(room) -> void:
	if room:
		_behavior_data.record_room_choice(room.id, room.get_type_string())
		behavior_data_updated.emit(_behavior_data)


## 楼层生成
func on_floor_generated(floor_data) -> void:
	if floor_data:
		_behavior_data.update_floor(floor_data.floor_level)
		behavior_data_updated.emit(_behavior_data)


## 事件选择
func on_event_choice(event_id: String, choice_index: int, choice_text: String) -> void:
	_behavior_data.record_event_choice(event_id, choice_index, choice_text)
	behavior_data_updated.emit(_behavior_data)


## ==================== 工具方法 ====================

## 更新玩家属性快照 (Phase 9.4.1: 使用get_player_data())
func _update_player_stats() -> void:
	if _player:
		_behavior_data.update_stats(_player.get_player_data())


## 获取行为数据字典(用于AI请求)
func get_behavior_dict() -> Dictionary:
	if _behavior_data:
		return _behavior_data.to_dict()
	return {}


## 获取战斗风格
func get_combat_style() -> String:
	if _behavior_data:
		return _behavior_data.get_combat_style()
	return "unknown"


## 获取升级偏好
func get_upgrade_preference() -> String:
	if _behavior_data:
		return _behavior_data.get_upgrade_preference()
	return "unknown"
