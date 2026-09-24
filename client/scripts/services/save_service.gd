## 存档服务模块
##
## 负责游戏存档的加载和保存
## 作为全局单例使用
##
## TASK-020.1: 用 _pending_operation 操作类型分派替代单一 _is_loading 布尔
## 修复三个问题:
##   1. 404创建存档重试后 _is_loading=false → 重试成功响应被丢弃
##   2. 保存/加载响应靠"响应形状"猜测 → 分支混淆（SaveResponse 必含 slot_number）
##   3. 多请求并发时单布尔状态机无法区分请求类型
## 信号名与公共接口保持不变，调用方零改动

extends Node

## 操作类型常量（TASK-020.1）
const OP_LOAD_SAVES: String = "load_saves"
const OP_LOAD_SLOT: String = "load_slot"
const OP_SAVE: String = "save"
const OP_CREATE: String = "create"

## 当前存档列表
var _saves: Array = []

## 加载状态（对外查询接口；响应过滤双保险）
var _is_loading: bool = false

## TASK-020.1: 待处理操作类型（"" 表示非本服务请求）
var _pending_operation: String = ""

## 最后一次保存数据(用于404回退)
var _last_save_data: Dictionary = {}
var _last_save_slot: int = -1

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

	_start_operation(OP_LOAD_SAVES)
	var url = APIConfig.get_full_url(APIConfig.GAME_SAVE)
	print("[SaveService] Requesting saves from API...")
	print("[SaveService] Full URL: ", url)
	print("[SaveService] Token exists: ", TokenManager.has_token())
	ApiClient.get_request(APIConfig.GAME_SAVE, true)


## 加载指定槽位存档
func load_save_by_slot(slot: int) -> void:
	_start_operation(OP_LOAD_SLOT)
	ApiClient.get_request(APIConfig.GAME_SAVE + "/" + str(slot), true)


## 保存存档 (智能模式: PUT更新 or POST创建)
func save_game(slot: int, save_data: Dictionary) -> void:
	var data = {
		"save_name": save_data.get("save_name", "存档" + str(slot)),
		"current_floor": save_data.get("current_floor", 1),
		"player_state": save_data.get("player_state", {}),
		"play_time": save_data.get("play_time", 0),
		"kill_count": save_data.get("kill_count", 0),
		"gold_collected": save_data.get("gold_collected", 0)
	}
	# 保存slot和data用于404回退
	_last_save_slot = slot
	_last_save_data = data.duplicate()
	print("[SaveService] save_game(slot=", slot, ") PUT /api/game/save/", slot)
	print("[SaveService] Save data: floor=", data.current_floor, " level=", data.player_state.get("level", 0), " hp=", data.player_state.get("current_health", 0), "/", data.player_state.get("max_health", 0))
	_start_operation(OP_SAVE)
	ApiClient.put_request(APIConfig.GAME_SAVE + "/" + str(slot), data, true)


## 创建新存档
func create_save(slot: int, save_name: String, player_state: Dictionary) -> void:
	var data = {
		"save_name": save_name,
		"slot_number": slot,
		"player_state": player_state
	}
	_start_operation(OP_CREATE)
	ApiClient.post_request(APIConfig.GAME_SAVE, data, true)


## TASK-020.1: 开始一次操作（设置操作类型与加载状态）
func _start_operation(op: String) -> void:
	_pending_operation = op
	_is_loading = true


## TASK-020.1: 结束当前操作（清空状态）
func _finish_operation() -> void:
	_pending_operation = ""
	_is_loading = false


## API请求成功回调
## TASK-020.1: 按 _pending_operation 分派，不再靠响应形状猜测
func _on_api_success(result: Variant) -> void:
	print("[SaveService] _on_api_success called, op: ", _pending_operation)

	# 非本服务请求（_is_loading 过滤双保险）
	if not _is_loading or _pending_operation == "":
		print("[SaveService] Not loading, ignoring response")
		return

	match _pending_operation:
		OP_LOAD_SAVES:
			_finish_operation()
			if result is Array:
				# 存档列表响应
				print("[SaveService] Received saves array, count: ", result.size())
				_saves = result
				saves_loaded.emit(result)
			else:
				print("[SaveService] Saves list response is not an Array")
				save_error.emit("存档列表响应格式错误")
		OP_LOAD_SLOT:
			_finish_operation()
			if result is Dictionary:
				print("[SaveService] Single save response")
				save_loaded.emit(result)
			else:
				save_error.emit("存档数据响应格式错误")
		OP_SAVE, OP_CREATE:
			# 保存/创建成功响应（PUT 200 / POST 201 均走到这里）
			_finish_operation()
			print("[SaveService] Save success response")
			save_saved.emit(true, "保存成功")
		_:
			# 理论不可达（非本服务请求已被上面过滤）
			_finish_operation()


## API请求失败回调
## TASK-020.1: 404 仅在 OP_SAVE 时转 POST 创建；重试前重新置位防止响应被丢弃
func _on_api_error(error: String, status_code: int) -> void:
	# 非本服务请求
	if _pending_operation == "":
		return

	print("[SaveService] _on_api_error op=", _pending_operation, " status=", status_code)

	if status_code == 401:
		_finish_operation()
		save_error.emit("认证失败，请重新登录")
	elif status_code == 404 and _pending_operation == OP_SAVE:
		# 首次保存: slot不存在 → 转 POST 创建
		print("[SaveService] 404 - archive not found (slot=", _last_save_slot, "), retrying with POST...")
		if _last_save_slot >= 1 and _last_save_data.size() > 0:
			var create_data = {
				"save_name": _last_save_data.get("save_name", "存档" + str(_last_save_slot)),
				"slot_number": _last_save_slot,
				"player_state": _last_save_data.get("player_state", {}),
				"current_floor": _last_save_data.get("current_floor", 1),
				"play_time": _last_save_data.get("play_time", 0),
				"kill_count": _last_save_data.get("kill_count", 0),
				"gold_collected": _last_save_data.get("gold_collected", 0)
			}
			# 关键修复: 重试前重新置位操作状态，防止重试响应被 "Not loading" 丢弃
			_start_operation(OP_CREATE)
			ApiClient.post_request(APIConfig.GAME_SAVE, create_data, true)
		else:
			_finish_operation()
			save_error.emit("存档槽位无效或数据缺失")
	elif status_code == 404 and _pending_operation == OP_LOAD_SLOT:
		_finish_operation()
		save_error.emit("该槽位没有存档")
	else:
		_finish_operation()
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
