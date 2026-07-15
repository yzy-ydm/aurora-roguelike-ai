## 数据统计管理器 (Phase 13)
##
## 记录游戏局数据用于毕业论文分析
## 保存到 user://analytics/

extends Node

## ==================== 配置 ====================

## 分析数据目录
const ANALYTICS_DIR: String = "user://analytics/"

## ==================== 当前运行数据 ====================

## 运行ID
var _run_id: String = ""

## 开始时间
var _start_time: float = 0.0

## 当前运行数据
var _current_run: Dictionary = {}


## ==================== 初始化 ====================

func _ready() -> void:
	_ensure_analytics_dir()


## 确保分析目录存在
func _ensure_analytics_dir() -> void:
	if not DirAccess.dir_exists_absolute(ANALYTICS_DIR):
		DirAccess.make_dir_recursive_absolute(ANALYTICS_DIR)
		print("[Analytics] Created analytics directory")


## ==================== 运行生命周期 ====================

## 开始新运行
func start_run() -> void:
	_run_id = _generate_run_id()
	_start_time = Time.get_unix_time_from_system()

	_current_run = {
		"run_id": _run_id,
		"start_time": _start_time,
		"end_time": 0.0,
		"duration": 0.0,
		"death_cause": "",
		"max_level": 1,
		"max_floor": 1,
		"total_kills": 0,
		"total_deaths": 0,
		"room_route": [],
		"upgrade_choices": [],
		"event_choices": [],
		"ai_generated_count": 0,
		"combat_stats": {
			"total_combat_time": 0.0,
			"average_combat_time": 0.0,
			"no_hit_clears": 0
		},
		"player_stats_snapshot": {}
	}

	print("[Analytics] Run started: ", _run_id)


## 结束当前运行
func end_run(death_cause: String = "completed") -> void:
	if _run_id == "":
		return

	_current_run["end_time"] = Time.get_unix_time_from_system()
	_current_run["duration"] = _current_run["end_time"] - _start_time
	_current_run["death_cause"] = death_cause

	# 保存到文件
	_save_run_data()

	print("[Analytics] Run ended: ", _run_id, ", cause: ", death_cause)


## ==================== 数据记录 ====================

## 记录击杀
func record_kill(count: int = 1) -> void:
	_current_run["total_kills"] = _current_run.get("total_kills", 0) + count


## 记录死亡
func record_death(cause: String = "unknown") -> void:
	_current_run["total_deaths"] = _current_run.get("total_deaths", 0) + 1
	_current_run["death_cause"] = cause


## 记录等级
func record_level(level: int) -> void:
	if level > _current_run.get("max_level", 1):
		_current_run["max_level"] = level


## 记录楼层
func record_floor(floor: int) -> void:
	if floor > _current_run.get("max_floor", 1):
		_current_run["max_floor"] = floor


## 记录房间选择
func record_room_choice(room_id: int, room_type: String) -> void:
	var route = _current_run.get("room_route", [])
	route.append({
		"room_id": room_id,
		"room_type": room_type,
		"timestamp": Time.get_unix_time_from_system()
	})
	_current_run["room_route"] = route


## 记录强化选择
func record_upgrade_choice(upgrade_id: String, upgrade_name: String) -> void:
	var choices = _current_run.get("upgrade_choices", [])
	choices.append({
		"upgrade_id": upgrade_id,
		"upgrade_name": upgrade_name,
		"timestamp": Time.get_unix_time_from_system()
	})
	_current_run["upgrade_choices"] = choices


## 记录事件选择
func record_event_choice(event_id: String, choice_index: int, choice_text: String) -> void:
	var choices = _current_run.get("event_choices", [])
	choices.append({
		"event_id": event_id,
		"choice_index": choice_index,
		"choice_text": choice_text,
		"timestamp": Time.get_unix_time_from_system()
	})
	_current_run["event_choices"] = choices


## 记录AI生成内容
func record_ai_generation() -> void:
	_current_run["ai_generated_count"] = _current_run.get("ai_generated_count", 0) + 1


## 记录战斗统计
func record_combat(duration: float, no_hit: bool = false) -> void:
	var stats = _current_run.get("combat_stats", {})
	stats["total_combat_time"] = stats.get("total_combat_time", 0.0) + duration
	var combat_count = _current_run.get("room_route", []).size()
	if combat_count > 0:
		stats["average_combat_time"] = stats["total_combat_time"] / combat_count
	if no_hit:
		stats["no_hit_clears"] = stats.get("no_hit_clears", 0) + 1
	_current_run["combat_stats"] = stats


## 更新玩家属性快照
func update_player_stats(stats: Dictionary) -> void:
	_current_run["player_stats_snapshot"] = stats.duplicate()


## 从行为数据更新
func update_from_behavior(behavior_data) -> void:
	if not behavior_data:
		return

	_current_run["total_kills"] = behavior_data.total_kills
	_current_run["total_deaths"] = behavior_data.death_count
	_current_run["max_level"] = behavior_data.max_level_reached
	_current_run["max_floor"] = behavior_data.max_floor_reached

	_current_run["combat_stats"] = {
		"total_combat_time": behavior_data.total_combat_time,
		"average_combat_time": behavior_data.get_average_combat_time(),
		"no_hit_clears": behavior_data.no_hit_clear_count
	}

	_current_run["room_route"] = behavior_data.room_route
	_current_run["upgrade_choices"] = behavior_data.upgrade_history
	_current_run["event_choices"] = behavior_data.event_choices


## ==================== 数据保存 ====================

## 保存运行数据
func _save_run_data() -> void:
	var file_path = ANALYTICS_DIR + "run_" + _run_id + ".json"
	var json_string = JSON.stringify(_current_run, "\t")

	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
		print("[Analytics] Saved run data to: ", file_path)
	else:
		print("[Analytics] Failed to save run data")


## 获取所有运行数据
func get_all_runs() -> Array[Dictionary]:
	var runs: Array[Dictionary] = []

	var dir = DirAccess.open(ANALYTICS_DIR)
	if not dir:
		return runs

	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		if file_name.begins_with("run_") and file_name.ends_with(".json"):
			var file_path = ANALYTICS_DIR + file_name
			var file = FileAccess.open(file_path, FileAccess.READ)
			if file:
				var json_string = file.get_as_text()
				file.close()

				var json = JSON.new()
				if json.parse(json_string) == OK:
					runs.append(json.data)

		file_name = dir.get_next()

	return runs


## 获取运行统计摘要
func get_runs_summary() -> Dictionary:
	var runs = get_all_runs()

	if runs.size() == 0:
		return {
			"total_runs": 0,
			"average_duration": 0.0,
			"average_kills": 0,
			"average_max_level": 0,
			"average_max_floor": 0
		}

	var total_duration = 0.0
	var total_kills = 0
	var total_max_level = 0
	var total_max_floor = 0

	for run in runs:
		total_duration += run.get("duration", 0.0)
		total_kills += run.get("total_kills", 0)
		total_max_level += run.get("max_level", 1)
		total_max_floor += run.get("max_floor", 1)

	return {
		"total_runs": runs.size(),
		"average_duration": total_duration / runs.size(),
		"average_kills": total_kills / runs.size(),
		"average_max_level": total_max_level / runs.size(),
		"average_max_floor": total_max_floor / runs.size()
	}


## ==================== 工具方法 ====================

## 生成运行ID
func _generate_run_id() -> String:
	var time = Time.get_datetime_string_from_system()
	var random = randi() % 10000
	return time.replace(":", "-").replace(" ", "_") + "_" + str(random)
