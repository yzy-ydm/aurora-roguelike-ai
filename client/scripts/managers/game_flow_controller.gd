## 游戏流程控制器
##
## 负责管理游戏生命周期流程
## 包括：开始游戏、加载数据、初始化状态、进入游戏、退出保存
## 作为全局单例使用

extends Node

## 当前流程状态
enum FlowState {
	IDLE,
	LOADING_PLAYER,
	LOADING_SAVES,
	LOADING_RESOURCES,
	READY,
	IN_GAME,
	SAVING,
	ERROR
}

## 当前流程状态
var _flow_state: FlowState = FlowState.IDLE

## 错误信息
var _error_message: String = ""

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


## 开始游戏流程
func start_game() -> void:
	print("[GameFlow] START GAME called, current state: ", _flow_state)

	# 如果当前状态是ERROR，自动重置
	if _flow_state == FlowState.ERROR:
		print("[GameFlow] RESET FROM ERROR")
		reset()
		print("[GameFlow] START GAME AFTER RESET, state: ", _flow_state)

	if _flow_state != FlowState.IDLE and _flow_state != FlowState.READY:
		print("[GameFlow] ABORT - flow_state is not IDLE or READY, current: ", _flow_state)
		return

	_flow_state = FlowState.LOADING_PLAYER
	flow_progress.emit("加载玩家数据...")
	print("[GameFlow] Requesting player profile...")

	# 加载玩家数据
	ApiClient.get_request(APIConfig.PLAYER_PROFILE, true)


## 加载存档
func load_saves() -> void:
	print("[GameFlow] load_saves() called")
	_flow_state = FlowState.LOADING_SAVES
	flow_progress.emit("加载存档数据...")
	SaveService.load_saves()


## 加载资源
func load_resources() -> void:
	print("[GameFlow] load_resources() called")
	_flow_state = FlowState.LOADING_RESOURCES
	flow_progress.emit("加载游戏资源...")
	ResourceService.load_all_resources()


## 进入游戏场景
## 注意：此函数只负责场景切换，不发出 flow_completed 信号
## flow_completed 信号由 _on_resources_loaded() 发出
func enter_game(save_slot: int = -1) -> void:
	print("[GameFlow] enter_game() called, save_slot: ", save_slot)

	if save_slot >= 0:
		var save_data = SaveService.get_save_by_slot(save_slot)
		if save_data.size() > 0:
			GameStateManager.set_current_save(save_data, save_slot)

	GameStateManager.set_state(GameStateManager.GameState.PLAYING)
	_flow_state = FlowState.IN_GAME
	print("[GameFlow] Switching to game scene...")
	SceneManager.go_to_game()


## 退出游戏并保存
func exit_game() -> void:
	if not GameStateManager.is_playing():
		SceneManager.go_to_main()
		return

	_flow_state = FlowState.SAVING
	flow_progress.emit("保存游戏数据...")

	var slot = GameStateManager.get_current_slot()
	if slot >= 0:
		var save_data = GameStateManager.get_save_data()
		SaveService.save_game(slot, save_data)
	else:
		# 没有存档槽位，直接返回
		GameStateManager.set_state(GameStateManager.GameState.NOT_STARTED)
		SceneManager.go_to_main()
		_flow_state = FlowState.IDLE


## API请求成功回调
func _on_api_success(result: Variant) -> void:
	print("[GameFlow] _on_api_success called, flow_state: ", _flow_state)

	# 只处理Dictionary类型响应
	if not result is Dictionary:
		print("[GameFlow] Result is not Dictionary, ignoring")
		return

	# 只在LOADING_PLAYER状态处理玩家数据
	if _flow_state != FlowState.LOADING_PLAYER:
		print("[GameFlow] flow_state is not LOADING_PLAYER, ignoring")
		return

	print("[GameFlow] PLAYER DATA RECEIVED")
	# 验证是否是玩家数据响应（必须包含user_id和nickname）
	if result.has("user_id") and result.has("nickname"):
		print("[GameFlow] Valid player data with user_id, calling load_saves()")
		GameStateManager.set_player_data(result)
		# 玩家数据加载完成，开始加载存档
		load_saves()
	elif result.has("nickname"):
		print("[GameFlow] Valid player data with nickname only, calling load_saves()")
		# 兼容没有user_id的情况
		GameStateManager.set_player_data(result)
		load_saves()
	else:
		print("[GameFlow] Result does not have nickname, ignoring")


## 存档加载完成
func _on_saves_loaded(saves: Array) -> void:
	print("[GameFlow] _on_saves_loaded called, flow_state: ", _flow_state)
	if _flow_state == FlowState.LOADING_SAVES:
		print("[GameFlow] Saves loaded, calling load_resources()")
		# 存档加载完成，开始加载资源
		load_resources()


## 资源加载完成
func _on_resources_loaded() -> void:
	print("[GameFlow] _on_resources_loaded called, flow_state: ", _flow_state)
	if _flow_state == FlowState.LOADING_RESOURCES:
		_flow_state = FlowState.READY
		print("[GameFlow] All resources loaded, emitting flow_completed")
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
			SceneManager.go_to_main()
			_flow_state = FlowState.IDLE
		else:
			_error_message = message
			flow_error.emit(message)


## 存档错误
func _on_save_error(error: String) -> void:
	_error_message = error
	if _flow_state == FlowState.SAVING:
		# 保存失败也返回主界面
		GameStateManager.set_state(GameStateManager.GameState.NOT_STARTED)
		SceneManager.go_to_main()
		_flow_state = FlowState.IDLE
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


## 获取当前流程状态
func get_flow_state() -> FlowState:
	return _flow_state


## 获取错误信息
func get_error_message() -> String:
	return _error_message


## 检查是否正在加载
func is_loading() -> bool:
	return _flow_state in [FlowState.LOADING_PLAYER, FlowState.LOADING_SAVES, FlowState.LOADING_RESOURCES, FlowState.SAVING]


## 检查是否就绪
func is_ready() -> bool:
	return _flow_state == FlowState.READY


## 重置流程状态
func reset() -> void:
	print("[GameFlow] RESET called, current state: ", _flow_state)
	_flow_state = FlowState.IDLE
	_error_message = ""
	print("[GameFlow] RESET complete, new state: ", _flow_state)
