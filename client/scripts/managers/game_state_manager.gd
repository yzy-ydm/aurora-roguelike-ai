## 游戏状态管理器
##
## 负责管理游戏运行时状态
## 包括玩家状态、存档状态、当前运行状态
## 作为全局单例使用
##
## Phase 9.5: PlayerStats作为唯一运行时状态来源
## - API/MySQL Save → GameStateManager → PlayerStats → PlayerController

extends Node

## 游戏状态枚举
enum GameState {
	NOT_STARTED,    # 未开始
	LOGIN,          # 登录中 (Phase 15)
	LOADING,        # 加载中
	EXPLORATION,    # 探索中 (Phase 15)
	PLAYING,        # 游戏中
	PAUSED,         # 暂停
	COMBAT,         # 战斗中
	EVENT,          # 事件选择中
	LEVEL_UP,       # 升级选择中
	BOSS,           # Boss战中
	GAME_OVER,      # 游戏结束
	VICTORY         # 胜利
}

## 当前游戏状态
var _current_state: GameState = GameState.NOT_STARTED

## 玩家数据
var _player_data: Dictionary = {}

## 当前存档数据
var _current_save: Dictionary = {}

## 当前存档槽位
var _current_slot: int = -1

## 游戏运行时间（秒）
var _play_time: float = 0.0

## Phase 9.5: 运行时PlayerStats引用（唯一运行时状态来源）
var _runtime_stats: PlayerStats = null

## Phase 9.5: 扩展存档数据（武器等级、被动物品等）
var _extended_save_data: Dictionary = {}

## 信号
signal state_changed(new_state: GameState)
signal player_data_updated(data: Dictionary)
signal save_loaded(save_data: Dictionary)
signal save_error(error: String)


func _ready() -> void:
	pass


## 获取当前游戏状态
func get_current_state() -> GameState:
	return _current_state


## 设置游戏状态
func set_state(new_state: GameState) -> void:
	if _current_state == new_state:
		return

	# Phase 15: 状态转换验证
	if not _is_valid_transition(_current_state, new_state):
		push_warning("[GameStateManager] Invalid state transition: " +
			str(_current_state) + " -> " + str(new_state))
		return

	var old_state = _current_state
	_current_state = new_state
	state_changed.emit(new_state)
	print("[GameStateManager] State changed: ", _get_state_name(old_state), " -> ", _get_state_name(new_state))


## 验证状态转换是否合法
func _is_valid_transition(from: GameState, to: GameState) -> bool:
	# 任何状态都可以转换到NOT_STARTED（重置）
	if to == GameState.NOT_STARTED:
		return true

	# 任何状态都可以暂停和恢复
	if to == GameState.PAUSED or from == GameState.PAUSED:
		return true

	# GAME_OVER和VICTORY是终态，只能重置
	if from == GameState.GAME_OVER or from == GameState.VICTORY:
		return to == GameState.NOT_STARTED

	match from:
		GameState.NOT_STARTED:
			return to in [GameState.LOGIN, GameState.LOADING]

		GameState.LOGIN:
			return to in [GameState.LOADING, GameState.NOT_STARTED]

		GameState.LOADING:
			return to in [GameState.EXPLORATION, GameState.PLAYING, GameState.NOT_STARTED]

		GameState.EXPLORATION:
			return to in [GameState.COMBAT, GameState.EVENT, GameState.LEVEL_UP, GameState.BOSS,
						  GameState.PLAYING, GameState.GAME_OVER, GameState.VICTORY]

		GameState.PLAYING:
			return to in [GameState.COMBAT, GameState.EVENT, GameState.LEVEL_UP, GameState.BOSS,
						  GameState.EXPLORATION, GameState.GAME_OVER, GameState.VICTORY]

		GameState.COMBAT:
			return to in [GameState.EXPLORATION, GameState.PLAYING, GameState.EVENT,
						  GameState.GAME_OVER, GameState.VICTORY]

		GameState.EVENT:
			return to in [GameState.EXPLORATION, GameState.PLAYING, GameState.GAME_OVER]

		GameState.LEVEL_UP:
			return to in [GameState.EXPLORATION, GameState.PLAYING]

		GameState.BOSS:
			return to in [GameState.EXPLORATION, GameState.PLAYING, GameState.VICTORY,
						  GameState.GAME_OVER]

	return true


## 获取状态名称（用于调试）
func _get_state_name(state: GameState) -> String:
	match state:
		GameState.NOT_STARTED: return "NOT_STARTED"
		GameState.LOGIN: return "LOGIN"
		GameState.LOADING: return "LOADING"
		GameState.EXPLORATION: return "EXPLORATION"
		GameState.PLAYING: return "PLAYING"
		GameState.PAUSED: return "PAUSED"
		GameState.COMBAT: return "COMBAT"
		GameState.EVENT: return "EVENT"
		GameState.LEVEL_UP: return "LEVEL_UP"
		GameState.BOSS: return "BOSS"
		GameState.GAME_OVER: return "GAME_OVER"
		GameState.VICTORY: return "VICTORY"
		_: return "UNKNOWN"


## 检查是否在游戏中
func is_playing() -> bool:
	return _current_state in [GameState.PLAYING, GameState.EXPLORATION]


## 检查是否已开始
func is_started() -> bool:
	return _current_state != GameState.NOT_STARTED and _current_state != GameState.LOGIN


## 检查玩家是否可以移动
func can_player_move() -> bool:
	return _current_state in [GameState.PLAYING, GameState.EXPLORATION, GameState.COMBAT]


## 检查玩家是否可以攻击
func can_player_attack() -> bool:
	return _current_state in [GameState.PLAYING, GameState.EXPLORATION, GameState.COMBAT, GameState.BOSS]


## 检查是否在战斗中
func is_in_combat() -> bool:
	return _current_state in [GameState.COMBAT, GameState.BOSS]


## 检查是否可以暂停
func can_pause() -> bool:
	return _current_state in [GameState.PLAYING, GameState.EXPLORATION, GameState.COMBAT]


## 设置玩家数据（从API响应）
func set_player_data(data: Dictionary) -> void:
	_player_data = data

	# 确保关键属性有默认值（API可能不返回这些字段）
	if not _player_data.has("current_health"):
		_player_data["current_health"] = _player_data.get("max_health", 100)
	if not _player_data.has("max_health"):
		_player_data["max_health"] = 100
	if not _player_data.has("level"):
		_player_data["level"] = 1
	if not _player_data.has("gold"):
		_player_data["gold"] = 0

	player_data_updated.emit(data)


## 获取玩家数据（兼容旧系统）
func get_player_data() -> Dictionary:
	# Phase 9.5: 优先从运行时PlayerStats获取最新数据
	if _runtime_stats:
		_player_data = _runtime_stats.to_dict()
	return _player_data


## ==================== Phase 9.5: PlayerStats运行时状态管理 ====================

## 设置运行时PlayerStats引用
## 由PlayerController在初始化时调用
func set_runtime_stats(stats: PlayerStats) -> void:
	_runtime_stats = stats
	if _runtime_stats:
		# 同步到_player_data
		_player_data = _runtime_stats.to_dict()
		print("[GameStateManager] Runtime PlayerStats linked")


## 获取运行时PlayerStats引用
func get_runtime_stats() -> PlayerStats:
	return _runtime_stats


## 同步运行时PlayerStats到_player_data
## 由PlayerController在属性变化时调用
func sync_from_runtime_stats() -> void:
	if _runtime_stats:
		_player_data = _runtime_stats.to_dict()


## 获取玩家昵称
func get_player_nickname() -> String:
	return _player_data.get("nickname", "未知玩家")


## 获取玩家等级
func get_player_level() -> int:
	return _player_data.get("level", 1)


## 获取玩家生命值
func get_player_health() -> int:
	return _player_data.get("current_health", 0)


## 获取玩家最大生命值
func get_player_max_health() -> int:
	return _player_data.get("max_health", 100)


## 获取玩家金币
func get_player_gold() -> int:
	return _player_data.get("gold", 0)


## 设置当前存档（Phase 9.5: 同时恢复PlayerStats）
func set_current_save(save_data: Dictionary, slot: int) -> void:
	_current_save = save_data
	_current_slot = slot

	# Phase 9.5: 从存档恢复PlayerStats
	if save_data.has("player_state") and save_data["player_state"] is Dictionary:
		var player_state = save_data["player_state"]
		if _runtime_stats:
			_runtime_stats.sync_from_dict(player_state)
		else:
			# 如果PlayerStats还未初始化，先缓存到_player_data
			_player_data = player_state
		print("[GameStateManager] Player state restored from save slot ", slot)

	# 恢复扩展存档数据
	if save_data.has("weapon_level"):
		_extended_save_data["weapon_level"] = save_data["weapon_level"]
	if save_data.has("passive_items"):
		_extended_save_data["passive_items"] = save_data["passive_items"]
	if save_data.has("upgrade_history"):
		_extended_save_data["upgrade_history"] = save_data["upgrade_history"]

	save_loaded.emit(save_data)


## 获取当前存档
func get_current_save() -> Dictionary:
	return _current_save


## 获取当前存档槽位
func get_current_slot() -> int:
	return _current_slot


## 检查是否有存档
func has_save() -> bool:
	return _current_save.size() > 0


## 更新游戏运行时间
func add_play_time(delta: float) -> void:
	if _current_state == GameState.PLAYING:
		_play_time += delta


## 获取游戏运行时间
func get_play_time() -> float:
	return _play_time


## 获取存档数据用于保存（Phase 9.5: 从PlayerStats获取最新数据）
## Phase 9.5.1: 将扩展数据合并到player_state中，确保存档完整性
func get_save_data() -> Dictionary:
	# Phase 9.5: 确保_player_data是最新的
	if _runtime_stats:
		_player_data = _runtime_stats.to_dict()

	# 将扩展数据合并到player_state中，确保API存档包含所有数据
	var player_state = _player_data.duplicate()
	for key in _extended_save_data:
		if not player_state.has(key):
			player_state[key] = _extended_save_data[key]

	var save_data = {
		"current_floor": _current_save.get("current_floor", 1),
		"player_state": player_state,
		"play_time": int(_play_time),
		"kill_count": _current_save.get("kill_count", 0),
		"gold_collected": _current_save.get("gold_collected", 0)
	}

	return save_data


## 更新扩展存档数据（Phase 9.5）
## 由PlayerController/UpgradeManager调用，保存武器等级、被动物品等
func set_extended_save_data(key: String, value: Variant) -> void:
	_extended_save_data[key] = value


## 获取扩展存档数据
func get_extended_save_data() -> Dictionary:
	return _extended_save_data


## 重置游戏状态
func reset() -> void:
	_current_state = GameState.NOT_STARTED
	_player_data = {}
	_current_save = {}
	_current_slot = -1
	_play_time = 0.0
	_runtime_stats = null
	_extended_save_data = {}
