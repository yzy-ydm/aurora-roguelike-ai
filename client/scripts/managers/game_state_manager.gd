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

## Phase 18.2: 三个数据生命周期分离
##   ProfileData: _profile_data —— 账号基线（注册快照），仅 set_player_data 写入
##   SaveData:    _current_save —— 继续游戏快照（set_current_save 写入）
##   RunData:     _runtime_stats —— 当前一次游戏的运行时状态（唯一真相源）
## 规则: 运行时数据禁止回写 _profile_data/_player_data 基线（否则死亡 hp=0 等
## 污染基线 → 重启 run 继承死亡状态）
var _profile_data: Dictionary = {}

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

## TASK-025: 运行时当前楼层（供保存真实楼层进度；加载存档时同步恢复）
var _runtime_floor: int = 1

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


## 设置玩家数据（从API响应——profile 入口）
func set_player_data(data: Dictionary) -> void:
	_player_data = data

	# Phase 18.1: 字段名规整——profile API 返回 "health"/"experience_to_next_level"，
	# 运行时/HUD 统一使用 "current_health"/"experience_to_next"。
	# 不规整会导致 HUD 读取缺失字段得默认值（如 health=0/100 的假象）。
	if not _player_data.has("current_health") and _player_data.has("health"):
		_player_data["current_health"] = _player_data["health"]
	if not _player_data.has("experience_to_next") and _player_data.has("experience_to_next_level"):
		_player_data["experience_to_next"] = _player_data["experience_to_next_level"]

	# 确保关键属性有默认值（API可能不返回这些字段）
	if not _player_data.has("current_health"):
		_player_data["current_health"] = _player_data.get("max_health", 100)
	if not _player_data.has("max_health"):
		_player_data["max_health"] = 100
	if not _player_data.has("level"):
		_player_data["level"] = 1
	if not _player_data.has("gold"):
		_player_data["gold"] = 0
	if not _player_data.has("nickname"):
		_player_data["nickname"] = "冒险者"

	# Phase 18.2: 保存账号基线快照（ProfileData，禁止被运行时覆盖）
	_profile_data = _player_data.duplicate()
	player_data_updated.emit(data)


## Phase 18.2: 获取账号基线数据（仅 set_player_data 写入，运行时永不覆盖）
func get_profile_data() -> Dictionary:
	return _profile_data


## 获取玩家数据（兼容旧系统）
## Phase 18.2: 运行时优先但**不回写基线**（旧实现读取时把 run 数据写回 _player_data
## → 死亡后基线被污染 → 重启 run 继承 hp=0/level/gold）
func get_player_data() -> Dictionary:
	if _runtime_stats:
		return _runtime_stats.to_dict()
	return _player_data


## ==================== Phase 9.5: PlayerStats运行时状态管理 ====================

## 设置运行时PlayerStats引用
## 由PlayerController在初始化时调用
## Phase 18.2: 禁止回写 _player_data 基线（RunData 不得污染 ProfileData/SaveData）
func set_runtime_stats(stats: PlayerStats) -> void:
	_runtime_stats = stats
	if _runtime_stats:
		print("[GameStateManager] Runtime PlayerStats linked")


## 获取运行时PlayerStats引用
func get_runtime_stats() -> PlayerStats:
	return _runtime_stats


## 同步运行时PlayerStats到_player_data
## Phase 18.2: no-op 化（保留签名兼容调用方）——运行时读取一律经
## get_player_data() 的 runtime-first 分支实时获取，无需（也禁止）回写缓存
func sync_from_runtime_stats() -> void:
	pass


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

	# TASK-025: 恢复运行时楼层（加载存档即恢复楼层进度）
	_runtime_floor = save_data.get("current_floor", 1)

	# Phase 9.5: 从存档恢复PlayerStats
	if save_data.has("player_state") and save_data["player_state"] is Dictionary:
		var player_state = save_data["player_state"]
		# Phase 18.1: 一律先写入缓存——保证 get_player_data() 在 PlayerStats 链接前
		# 就返回存档数据（旧实现仅 _runtime_stats==null 时写入；
		# 若残留旧运行时引用，缓存会停留在 profile 数据 → HUD 显示登录快照）
		_player_data = player_state
		# Phase 18.2: 关键字段完整性检查——缺失必须 warning 并补默认值
		_player_data = _validate_restored_fields(_player_data)
		if _runtime_stats:
			_runtime_stats.sync_from_dict(player_state)
		print("[GameStateManager] Player state restored from save slot ", slot)

	# 恢复扩展存档数据
	# TASK-030: 武器/被动字段由 get_save_data 合并写入 player_state **内部**，
	# 旧实现从存档记录顶层读取 → 永远读不到 → 继续游戏武器丢失（默认武器覆盖）。
	# 兼容两种位置：优先嵌套 player_state，顶层兜底（旧版存档）。
	var nested: Dictionary = save_data.get("player_state", {}) if save_data.get("player_state") is Dictionary else {}
	if nested.has("weapon_level") or save_data.has("weapon_level"):
		_extended_save_data["weapon_level"] = nested.get("weapon_level", save_data.get("weapon_level", 1))
	if nested.has("weapon_id") or save_data.has("weapon_id"):
		_extended_save_data["weapon_id"] = nested.get("weapon_id", save_data.get("weapon_id", -1))
	if nested.has("passive_items") or save_data.has("passive_items"):
		_extended_save_data["passive_items"] = nested.get("passive_items", save_data.get("passive_items", []))
	if nested.has("upgrade_history") or save_data.has("upgrade_history"):
		_extended_save_data["upgrade_history"] = nested.get("upgrade_history", save_data.get("upgrade_history", []))
	print("[GameStateManager] Extended save data restored: ", _extended_save_data)

	save_loaded.emit(save_data)


## 获取当前存档
func get_current_save() -> Dictionary:
	return _current_save


## 获取当前存档槽位
func get_current_slot() -> int:
	return _current_slot


## Phase 18.2: 恢复字段完整性检查——关键字段缺失必须 warning（禁止默认值静默隐藏错误）
func _validate_restored_fields(player_state: Dictionary) -> Dictionary:
	var defaults := {
		"level": 1,
		"experience": 0,
		"experience_to_next": 100,
		"max_health": 100,
		"current_health": 100,
		"attack": 10,
		"defense": 0,
		"gold": 0,
		"move_speed": 200.0
	}
	for field in defaults:
		if not player_state.has(field):
			push_warning("[StateRestoreWarning] missing field=" + field)
			player_state[field] = defaults[field]
	return player_state


## TASK-025: 设置当前存档槽位（新游戏分配槽位时使用）
func set_current_slot(slot: int) -> void:
	_current_slot = slot
	print("[GameStateManager] Save slot set to ", slot)


## TASK-029: 解析实际保存槽位
## 规则: 已有当前槽位（进入游戏时分配的，默认槽位1）时一律沿用，
## 保存面板点选其它槽位不产生游离存档（已有 slot1 → 默认继续 slot1，不自动创建 slot2）
func resolve_save_slot(requested_slot: int) -> int:
	if _current_slot >= 1:
		return _current_slot
	return requested_slot if requested_slot >= 1 else 1


## TASK-025: 更新运行时楼层（由游戏场景每层生成时调用，保存真实进度）
func set_current_floor(floor_level: int) -> void:
	_runtime_floor = floor_level


## TASK-025: 获取运行时楼层（游戏场景起始楼层/保存数据使用）
func get_current_floor() -> int:
	return _runtime_floor


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
	# Phase 18.2: 运行时优先但不回写基线
	var base: Dictionary = _runtime_stats.to_dict() if _runtime_stats else _player_data

	# 将扩展数据合并到player_state中，确保API存档包含所有数据
	var player_state = base.duplicate()
	for key in _extended_save_data:
		if not player_state.has(key):
			player_state[key] = _extended_save_data[key]

	var save_data = {
		# TASK-025: 楼层取运行时值（暂停保存/退出保存/自动保存统一为真实进度）
		"current_floor": _runtime_floor,
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
	_runtime_floor = 1


## TASK-027: 重置本次运行的临时状态（开始新游戏/死亡退出/回主菜单时调用）
## 背景: _runtime_stats 引用旧场景玩家的 PlayerStats（含 hp=0 死亡状态），
## 若不清理，新游戏 player._ready 会 sync_from_dict 到死数据 → 出生即死。
## 保留 _player_data（登录 profile 基线，作为新 run 的起始属性）。
## 不清理 _current_state（由调用方按需 set_state）。
func reset_run_state() -> void:
	_runtime_stats = null
	_extended_save_data = {}
	_play_time = 0.0
	_runtime_floor = 1
	_current_save = {}
	print("[GameStateManager] Run state reset (profile baseline preserved)")
