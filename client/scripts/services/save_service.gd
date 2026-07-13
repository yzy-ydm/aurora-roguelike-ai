## 存档服务模块
##
## 负责游戏存档的加载和保存
## 作为全局单例使用

extends Node

## 当前存档列表
var _saves: Array = []

## 加载状态
var _is_loading: bool = false

## 信号
signal saves_loaded(saves: Array)
signal save_loaded(save_data: Dictionary)
signal save_saved(success: bool, message: String)
signal save_error(error: String)


func _ready() -> void:
	# 连接API信号
	ApiClient.request_completed.connect(_on_api_success)
	ApiClient.request_failed.connect(_on_api_error)


## 加载所有存档
func load_saves() -> void:
	print("[SaveService] load_saves() called")
	if _is_loading:
		print("[SaveService] Already loading, skipping")
		return

	_is_loading = true
	var url = APIConfig.get_full_url(APIConfig.GAME_SAVE)
	print("[SaveService] Requesting saves from API...")
	print("[SaveService] Full URL: ", url)
	print("[SaveService] Token exists: ", TokenManager.has_token())
	ApiClient.get_request(APIConfig.GAME_SAVE, true)


## 加载指定槽位存档
func load_save_by_slot(slot: int) -> void:
	_is_loading = true
	ApiClient.get_request(APIConfig.GAME_SAVE + "/" + str(slot), true)


## 保存存档
func save_game(slot: int, save_data: Dictionary) -> void:
	_is_loading = true
	var data = {
		"save_name": save_data.get("save_name", "存档" + str(slot)),
		"current_floor": save_data.get("current_floor", 1),
		"player_state": save_data.get("player_state", {}),
		"play_time": save_data.get("play_time", 0),
		"kill_count": save_data.get("kill_count", 0),
		"gold_collected": save_data.get("gold_collected", 0)
	}
	ApiClient.put_request(APIConfig.GAME_SAVE + "/" + str(slot), data, true)


## 创建新存档
func create_save(slot: int, save_name: String, player_state: Dictionary) -> void:
	_is_loading = true
	var data = {
		"save_name": save_name,
		"slot_number": slot,
		"player_state": player_state
	}
	ApiClient.post_request(APIConfig.GAME_SAVE, data, true)


## API请求成功回调
func _on_api_success(result: Variant) -> void:
	print("[SaveService] _on_api_success called, _is_loading: ", _is_loading)
	print("[SaveService] Result: ", result)

	# 只在正在加载时处理响应
	if not _is_loading:
		print("[SaveService] Not loading, ignoring response")
		return

	_is_loading = false

	if result is Array:
		# 存档列表响应
		print("[SaveService] Received saves array, count: ", result.size())
		_saves = result
		saves_loaded.emit(result)
	elif result is Dictionary:
		print("[SaveService] Received Dictionary response")
		if result.has("slot_number"):
			# 单个存档响应
			print("[SaveService] Single save response")
			save_loaded.emit(result)
		elif result.has("id") and result.has("save_name"):
			# 保存成功响应
			print("[SaveService] Save success response")
			save_saved.emit(true, "保存成功")
		else:
			print("[SaveService] Unknown Dictionary response, ignoring")
		# 其他Dictionary响应不处理（如登录响应、玩家数据等）


## API请求失败回调
func _on_api_error(error: String, status_code: int) -> void:
	_is_loading = false

	if status_code == 401:
		save_error.emit("认证失败，请重新登录")
	elif status_code == 404:
		save_error.emit("存档不存在")
	else:
		save_error.emit(error)


## 获取存档列表
func get_saves() -> Array:
	return _saves


## 检查是否有存档
func has_saves() -> bool:
	return _saves.size() > 0


## 获取指定槽位存档
func get_save_by_slot(slot: int) -> Dictionary:
	for save in _saves:
		if save is Dictionary and save.get("slot_number", -1) == slot:
			return save
	return {}


## 检查是否正在加载
func is_loading() -> bool:
	return _is_loading
