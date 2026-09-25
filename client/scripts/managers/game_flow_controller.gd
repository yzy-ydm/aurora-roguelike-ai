## 游戏流程控制器
##
## 负责管理游戏生命周期流程
## 作为全局单例使用
##
## TASK-029: 生命周期重设计
##   根因: 单例 _flow_state 在退出游戏/返回登录界面时未重置 →
##   重新登录 start_game() 命中旧状态 IN_GAME(旧枚举5) → ABORT → 无法进入游戏
##
##   新生命周期:
##     IDLE(0) → AUTHENTICATING(1) → LOADING_PLAYER(2) → LOADING_SAVE(3)
##     → LOADING_RESOURCE(4) → READY(5) → PLAYING(6)
##     退出保存: SAVING(7) → reset_flow() → IDLE
##     失败: ERROR(8) → reset_flow() → IDLE
##
##   退出游戏/返回主菜单/重新登录统一调用 reset_flow()（登录场景 _ready 兜底）
##   禁止"if state==X: force continue"式绕过

extends Node

## 当前流程状态
enum FlowState {
	IDLE,               # 未开始（登录界面/主菜单）
	AUTHENTICATING,     # 登录请求进行中
	LOADING_PLAYER,     # 加载玩家数据
	LOADING_SAVE,       # 加载存档列表
	LOADING_RESOURCE,   # 加载游戏资源
	READY,              # 数据加载完成，待进入游戏
	PLAYING,            # 游戏中
	SAVING,             # 退出保存中
	ERROR               # 流程错误
}

## 当前流程状态
var _flow_state: FlowState = FlowState.IDLE

## 错误信息
var _error_message: String = ""

## Phase 21.2.1: 玩家数据缓存
const CACHE_PATH: String = "user://player_cache.json"
var _player_cache: Dictionary = {}

## 信号
signal flow_completed
signal flow_error(error: String)
signal flow_progress(message: String)


func _ready() -> void:
	# 连接信号
	ResourceService.all_resources_loaded.connect(_on_resources_loaded)
	ResourceService.resource_load_error.connect(_on_resource_error)
	SaveService.saves_loaded.connect(_on_saves_loaded)
	SaveService.save_saved.connect(_on_save_saved)
	SaveService.save_error.connect(_on_save_error)
	ApiClient.request_completed.connect(_on_api_success)
	ApiClient.request_failed.connect(_on_api_error)

	# Phase 22.1.1: 不在启动时加载缓存，只在需要时保存
	print("[GameFlow] Ready (state=IDLE)")


## ==================== TASK-029: 统一生命周期入口 ====================

## 统一重置流程状态——退出游戏/返回主菜单/重新登录的必经出口
## 所有状态恢复到 IDLE，清除错误信息（禁止残留状态阻塞下一次流程）
func reset_flow() -> void:
	var old_state: FlowState = _flow_state
	_flow_state = FlowState.IDLE
	_error_message = ""
	print("[GameFlow] reset_flow: ", FlowState.keys()[old_state], " -> IDLE")


## 登录请求开始（login_scene 在发起登录 POST 前调用）
func begin_authentication() -> void:
	if _flow_state == FlowState.ERROR:
		reset_flow()
	_flow_state = FlowState.AUTHENTICATING
	print("[GameFlow] AUTHENTICATING...")


## ==================== 正向流程 ====================

## 开始游戏流程（登录成功后调用）
func start_game() -> void:
	print("[GameFlow] START GAME called, current state: ", _flow_state)

	# 错误状态自动重置（上一次失败不阻塞重试）
	if _flow_state == FlowState.ERROR:
		reset_flow()

	# TASK-029: 合法前置状态 = IDLE / READY / AUTHENTICATING
	# 其它状态（如 PLAYING 残留）说明退出流程未走 reset_flow —— 拒绝并明确日志
	if _flow_state != FlowState.IDLE and _flow_state != FlowState.READY and _flow_state != FlowState.AUTHENTICATING:
		print("[GameFlow] ABORT - unexpected flow_state: ", _flow_state, " (exit paths must call reset_flow())")
		flow_error.emit("游戏流程状态异常，请返回登录界面重试")
		return

	_flow_state = FlowState.LOADING_PLAYER
	flow_progress.emit("正在加载玩家数据...")
	print("[BOOT] Player Load Start: ", Time.get_ticks_msec())

	# 加载玩家数据
	ApiClient.get_request(APIConfig.PLAYER_PROFILE, true)


## Phase 22.1.1: 保存玩家缓存（只保存，不用于自动登录）
func _save_player_cache(data: Dictionary) -> void:
	_player_cache = data
	var json_string = JSON.stringify(data, "\t")
	var file = FileAccess.open(CACHE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
		print("[GameFlow] Player cache saved")


## 加载存档
func load_saves() -> void:
	print("[GameFlow] load_saves() called")
	_flow_state = FlowState.LOADING_SAVE
	flow_progress.emit("加载存档数据...")
	SaveService.load_saves()


## 加载资源 (Phase 21.3: 后台异步加载)
func load_resources() -> void:
	print("[GameFlow] load_resources() called")
	_flow_state = FlowState.LOADING_RESOURCE
	flow_progress.emit("正在加载游戏资源...")

	# Phase 21.3: 后台加载资源，不阻塞游戏启动
	ResourceService.load_all_resources()

	# Phase 21.3: 立即进入游戏，不等待资源加载完成
	print("[ResourceService] Resources loading in background, entering game immediately")
	_on_resources_loaded()


## 进入游戏场景
## 注意：此函数只负责场景切换，不发出 flow_completed 信号
## flow_completed 信号由 _on_resources_loaded() 发出
## TASK-025: 未指定槽位时视为新游戏，自动分配槽位1（保存可写）；
## 指定槽位且存在存档时恢复存档数据（玩家状态/武器/楼层）
func enter_game(save_slot: int = -1) -> void:
	print("[GameFlow] enter_game() called, save_slot: ", save_slot)

	# TASK-027: 先清空上一 run 的临时状态（防死亡状态泄漏进新游戏）
	GameStateManager.reset_run_state()

	# 新游戏: 自动分配槽位1
	if save_slot < 1:
		save_slot = 1

	var save_data = SaveService.get_save_by_slot(save_slot)
	if save_data.is_empty():
		# Phase 18.1: 内存存档列表可能为空/过期（自动进入路径依赖登录流程的加载结果）
		# → 拉取一次最新列表再决定，杜绝"数据库有档却以 profile 数据开新局"
		var box := {"done": false}
		var handler := func(saves: Array) -> void:
			box["done"] = true
		SaveService.saves_loaded.connect(handler)
		SaveService.load_saves()
		var waited := 0
		while not box["done"] and waited < 300:  # 最长约 5 秒
			await get_tree().process_frame
			waited += 1
		SaveService.saves_loaded.disconnect(handler)
		save_data = SaveService.get_save_by_slot(save_slot)

	if save_data.size() > 0:
		# 继续游戏: 恢复存档（玩家数据/扩展数据/楼层）
		print("[GameFlow] Loading save from slot ", save_slot, " (floor ", save_data.get("current_floor", 1), ")")
		GameStateManager.set_current_save(save_data, save_slot)
	else:
		# 新游戏: 仅分配槽位（保存时可写入该槽位）
		print("[GameFlow] No save in slot ", save_slot, ", starting new game")
		GameStateManager.set_current_slot(save_slot)

	GameStateManager.set_state(GameStateManager.GameState.PLAYING)
	_flow_state = FlowState.PLAYING
	print("[GameFlow] Entering game (state=PLAYING)...")
	SceneManager.go_to_game()


## 退出游戏并保存
func exit_game() -> void:
	print("[GameFlow] exit_game() called, current state: ", _flow_state)

	# TASK-027: 死亡状态禁止保存死档（hp=0 不得写入正式存档）
	var runtime_stats = GameStateManager.get_runtime_stats()
	if runtime_stats and runtime_stats.is_dead():
		print("[GameFlow] exit_game SKIPPED save: player is dead")
		GameStateManager.reset_run_state()
		reset_flow()
		SceneManager.go_to_main()
		return

	if not GameStateManager.is_playing():
		# TASK-029: 非游戏状态退出同样走统一重置
		reset_flow()
		SceneManager.go_to_main()
		return

	_flow_state = FlowState.SAVING
	flow_progress.emit("保存游戏数据...")

	var slot = GameStateManager.get_current_slot()
	# Phase 23: slot=-1 时默认使用 slot 1 进行保存
	if slot < 1:
		slot = 1
		print("[GameFlow] No active slot, using default slot 1 for save")
	print("[GameFlow] Save slot: ", slot)
	var save_data = GameStateManager.get_save_data()
	print("[GameFlow] Save data preview: floor=", save_data.get("current_floor", 0), " level=", save_data.get("player_state", {}).get("level", 0))
	SaveService.save_game(slot, save_data)


## ==================== 回调 ====================

## API请求成功回调
func _on_api_success(result: Variant) -> void:
	# 只处理Dictionary类型响应
	if not result is Dictionary:
		return

	# 只在LOADING_PLAYER状态处理玩家数据
	if _flow_state != FlowState.LOADING_PLAYER:
		return

	print("[BOOT] Player Loaded: ", Time.get_ticks_msec())

	# 验证是否是玩家数据响应
	if result.has("nickname"):
		GameStateManager.set_player_data(result)
		_save_player_cache(result)
		load_saves()
	else:
		print("[GameFlow] Result does not have nickname, ignoring")


## 存档加载完成
func _on_saves_loaded(saves: Array) -> void:
	if _flow_state == FlowState.LOADING_SAVE:
		print("[BOOT] Save Loaded: ", Time.get_ticks_msec())
		load_resources()


## 资源加载完成
func _on_resources_loaded() -> void:
	print("[GameFlow] _on_resources_loaded called, flow_state: ", _flow_state)
	if _flow_state == FlowState.LOADING_RESOURCE:
		_flow_state = FlowState.READY
		print("[GameFlow] All resources loaded, emitting flow_completed (state=READY)")
		flow_progress.emit("数据加载完成")
		flow_completed.emit()


## 资源加载失败
func _on_resource_error(error: String) -> void:
	print("[GameFlow] _on_resource_error called: ", error)
	_error_message = error
	_flow_state = FlowState.ERROR
	flow_error.emit(error)


## 存档保存完成
func _on_save_saved(success: bool, message: String) -> void:
	if _flow_state == FlowState.SAVING:
		if success:
			GameStateManager.set_state(GameStateManager.GameState.NOT_STARTED)
			reset_flow()
			SceneManager.go_to_main()
		else:
			_error_message = message
			flow_error.emit(message)


## 存档错误
func _on_save_error(error: String) -> void:
	_error_message = error
	if _flow_state == FlowState.SAVING:
		# 保存失败也返回主界面（不阻塞退出）
		GameStateManager.set_state(GameStateManager.GameState.NOT_STARTED)
		reset_flow()
		SceneManager.go_to_main()
	flow_error.emit(error)


## API请求失败回调
func _on_api_error(error: String, status_code: int) -> void:
	print("[GameFlow] _on_api_error called, flow_state: ", _flow_state, " error: ", error)

	# 只在LOADING_PLAYER状态处理API错误
	if _flow_state != FlowState.LOADING_PLAYER:
		print("[GameFlow] flow_state is not LOADING_PLAYER, ignoring error")
		return

	# 玩家数据加载失败
	print("[GameFlow] Player data loading failed: ", error)
	_error_message = error
	_flow_state = FlowState.ERROR
	flow_error.emit(error)


## ==================== 查询接口 ====================

## 获取当前流程状态
func get_flow_state() -> FlowState:
	return _flow_state


## 获取错误信息
func get_error_message() -> String:
	return _error_message


## 检查是否正在加载
func is_loading() -> bool:
	return _flow_state in [
		FlowState.AUTHENTICATING, FlowState.LOADING_PLAYER,
		FlowState.LOADING_SAVE, FlowState.LOADING_RESOURCE, FlowState.SAVING
	]


## 检查是否就绪
func is_ready() -> bool:
	return _flow_state == FlowState.READY


## 重置流程状态（兼容旧接口——统一转调 reset_flow）
func reset() -> void:
	reset_flow()
