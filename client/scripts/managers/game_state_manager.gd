## 游戏状态管理器
##
## 负责管理游戏运行时状态
## 包括玩家状态、存档状态、当前运行状态
## 作为全局单例使用

extends Node

## 游戏状态枚举
enum GameState {
	NOT_STARTED,    # 未开始
	LOADING,        # 加载中
	PLAYING,        # 游戏中
	PAUSED,         # 暂停
	GAME_OVER       # 游戏结束
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
	if _current_state != new_state:
		_current_state = new_state
		state_changed.emit(new_state)


## 检查是否在游戏中
func is_playing() -> bool:
	return _current_state == GameState.PLAYING


## 检查是否已开始
func is_started() -> bool:
	return _current_state != GameState.NOT_STARTED


## 设置玩家数据
func set_player_data(data: Dictionary) -> void:
	_player_data = data
	player_data_updated.emit(data)


## 获取玩家数据
func get_player_data() -> Dictionary:
	return _player_data


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


## 设置当前存档
func set_current_save(save_data: Dictionary, slot: int) -> void:
	_current_save = save_data
	_current_slot = slot
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


## 获取存档数据用于保存
func get_save_data() -> Dictionary:
	return {
		"current_floor": _current_save.get("current_floor", 1),
		"player_state": _player_data,
		"play_time": int(_play_time),
		"kill_count": _current_save.get("kill_count", 0),
		"gold_collected": _current_save.get("gold_collected", 0)
	}


## 重置游戏状态
func reset() -> void:
	_current_state = GameState.NOT_STARTED
	_player_data = {}
	_current_save = {}
	_current_slot = -1
	_play_time = 0.0
