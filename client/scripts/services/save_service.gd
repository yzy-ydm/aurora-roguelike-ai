## 存档服务模块
##
## 负责游戏存档的加载和保存
## 作为全局单例使用
##
## TASK-028: 状态机重设计
##   根因（真实复现）: 游戏暂停(ESC)时 SceneTree.paused=true，
##   HTTPRequest 默认 process_mode 继承父节点(PAUSABLE) → 暂停期间停止轮询 →
##   request_completed 永不发射 → await 永不恢复 → 状态锁永久卡死
##   （用户症状: 保存中... 永不结束；后续 load_saves 全部 skipped）。
##
##   设计:
##   1. SaveService 与所有 HTTPRequest 子节点 process_mode=ALWAYS
##      → 暂停期间请求照常完成/超时（http.timeout=10s 兜底）
##   2. 每个操作单一入口 + 单一释放出口（GDScript 无 finally，手动收敛）
##   3. 忙时拒绝但通知调用方（不静默跳过 → UI 不再永久"加载存档中"）
##   4. 状态日志: [SAVE] START/REQUEST_SENT/SUCCESS/FAILED/LOCK_RELEASED
##      加载: LOAD_START/LOAD_SUCCESS/LOAD_FAILED/LOAD_RESET
##
## 历史: TASK-020.1 操作分派 / TASK-026 内存列表刷新 / TASK-027 独立 HTTP 层

extends Node

## 操作类型常量
const OP_LOAD_SAVES: String = "load_saves"
const OP_LOAD_SLOT: String = "load_slot"
const OP_SAVE: String = "save"

## HTTP 超时（秒）——信号必然发射，锁必然释放
const HTTP_TIMEOUT: float = 10.0

## 当前存档列表（内存缓存）
var _saves: Array = []

## 忙标志（对外查询接口）
var _is_loading: bool = false

## 当前操作类型（"" 表示空闲）
var _pending_operation: String = ""

## 信号
signal saves_loaded(saves: Array)
signal save_loaded(save_data: Dictionary)
signal save_saved(success: bool, message: String)
signal save_error(error: String)


func _ready() -> void:
	# TASK-028: 存档服务必须在游戏暂停期间继续工作（ESC→保存 的必经路径）
	# 子节点 HTTPRequest 继承 ALWAYS → 暂停时照常轮询完成请求
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("[SaveService] Ready (PROCESS_MODE_ALWAYS)")


## ==================== 公共接口（签名不变，调用方零改动） ====================

## 加载所有存档
func load_saves() -> void:
	if _is_loading:
		# TASK-028: 忙时不静默跳过——直接以内存缓存应答，调用方 UI 不再卡"加载存档中"
		print("[SaveService] LOAD_CACHED (busy with ", _pending_operation, "), serving memory cache (", _saves.size(), " saves)")
		saves_loaded.emit(_saves)
		return

	_is_loading = true
	_pending_operation = OP_LOAD_SAVES
	print("[SaveService] LOAD_START op=", OP_LOAD_SAVES)

	var res: Dictionary = await _http_request(HTTPClient.METHOD_GET, APIConfig.GAME_SAVE, {}, "[LOAD]")

	if res.has("__ok"):
		var data: Variant = res.get("__data", {})
		if data is Array:
			_saves = _normalize_saves(data)
			_release_lock()
			print("[SaveService] LOAD_SUCCESS count=", _saves.size())
			saves_loaded.emit(_saves)
			return
		_release_lock()
		print("[SaveService] LOAD_FAILED reason=format")
		save_error.emit("存档列表响应格式错误")
		return

	_release_lock()
	print("[SaveService] LOAD_FAILED reason=", str(res.get("__error", "unknown")))
	save_error.emit(str(res.get("__error", "加载存档失败")))


## 加载指定槽位存档
func load_save_by_slot(slot: int) -> void:
	if _is_loading:
		print("[SaveService] LOAD_CACHED (busy with ", _pending_operation, "), serving memory cache for slot ", slot)
		var cached: Dictionary = get_save_by_slot(slot)
		if cached.size() > 0:
			save_loaded.emit(cached)
		else:
			save_error.emit("该槽位没有存档")
		return

	_is_loading = true
	_pending_operation = OP_LOAD_SLOT
	print("[SaveService] LOAD_START op=", OP_LOAD_SLOT, " slot=", slot)

	var res: Dictionary = await _http_request(HTTPClient.METHOD_GET, APIConfig.GAME_SAVE + "/" + str(slot), {}, "[LOAD]")

	if res.has("__ok"):
		var data: Variant = res.get("__data", {})
		if data is Dictionary:
			_release_lock()
			print("[SaveService] LOAD_SUCCESS slot=", slot)
			save_loaded.emit(data)
			return
		_release_lock()
		print("[SaveService] LOAD_FAILED reason=format")
		save_error.emit("存档数据响应格式错误")
		return

	_release_lock()
	print("[SaveService] LOAD_FAILED reason=", str(res.get("__error", "unknown")))
	save_error.emit(str(res.get("__error", "加载存档失败")))


## 保存存档 (智能模式: PUT更新 or 404→POST创建)
## TASK-028: 单一释放出口——任何失败（超时/HTTP错误/解析错误/网络故障）都走同一释放点
func save_game(slot: int, save_data: Dictionary) -> void:
	if _is_loading:
		# 忙时拒绝并明确通知（pause_menu 显示错误而非永久"保存中..."）
		print("[SAVE] BUSY_REJECT other_op=", _pending_operation)
		save_error.emit("另一存档操作正在进行，请稍后重试")
		return

	_is_loading = true
	_pending_operation = OP_SAVE
	print("[SAVE] START slot=", slot)

	var data := {
		"save_name": save_data.get("save_name", "存档" + str(slot)),
		"current_floor": save_data.get("current_floor", 1),
		"player_state": save_data.get("player_state", {}),
		"play_time": save_data.get("play_time", 0),
		"kill_count": save_data.get("kill_count", 0),
		"gold_collected": save_data.get("gold_collected", 0)
	}

	# 1. 尝试更新
	var res: Dictionary = await _http_request(HTTPClient.METHOD_PUT, APIConfig.GAME_SAVE + "/" + str(slot), data, "[SAVE]")
	if res.has("__ok"):
		var resp_data: Variant = res.get("__data", {})
		if resp_data is Dictionary:
			_refresh_saves_entry(resp_data)
		_release_lock()
		print("[SAVE] SUCCESS slot=", slot)
		save_saved.emit(true, "保存成功")
		return

	# 2. 404 → 首次保存，转 POST 创建
	if res.get("__status", 0) == 404:
		print("[SAVE] PUT_404 -> POST create slot=", slot)
		var create_data := {
			"save_name": data["save_name"],
			"slot_number": slot,
			"player_state": data["player_state"],
			"current_floor": data["current_floor"],
			"play_time": data["play_time"],
			"kill_count": data["kill_count"],
			"gold_collected": data["gold_collected"]
		}
		var res2: Dictionary = await _http_request(HTTPClient.METHOD_POST, APIConfig.GAME_SAVE, create_data, "[SAVE]")
		if res2.has("__ok"):
			var resp_data2: Variant = res2.get("__data", {})
			if resp_data2 is Dictionary:
				_refresh_saves_entry(resp_data2)
			_release_lock()
			print("[SAVE] SUCCESS slot=", slot, " (created)")
			save_saved.emit(true, "保存成功")
			return
		var msg2: String = str(res2.get("__error", "创建存档失败"))
		_release_lock()
		print("[SAVE] FAILED reason=", msg2)
		save_error.emit(msg2)
		return

	var msg: String = str(res.get("__error", "保存失败"))
	_release_lock()
	print("[SAVE] FAILED reason=", msg)
	save_error.emit(msg)


## 创建新存档（兼容旧接口）
func create_save(slot: int, save_name: String, player_state: Dictionary) -> void:
	save_game(slot, {
		"save_name": save_name,
		"player_state": player_state,
		"current_floor": 1,
		"play_time": 0,
		"kill_count": 0,
		"gold_collected": 0
	})


## ==================== 查询接口 ====================

## 获取存档列表
func get_saves() -> Array:
	return _saves


## 检查是否有存档
func has_saves() -> bool:
	return _saves.size() > 0


## 获取指定槽位存档
func get_save_by_slot(slot: int) -> Dictionary:
	for save in _saves:
		if save is Dictionary and int(save.get("slot_number", -1)) == slot:
			return save
	return {}


## 检查是否正在加载
func is_loading() -> bool:
	return _is_loading


## ==================== 内部: 状态机 ====================

## TASK-028: 单一释放出口（所有操作的所有失败路径都收敛到这里）
func _release_lock() -> void:
	_pending_operation = ""
	_is_loading = false
	print("[SaveService] LOCK_RELEASED")


## 强制重置操作状态（场景切换/异常兜底）
func reset_state() -> void:
	_pending_operation = ""
	_is_loading = false
	print("[SaveService] LOAD_RESET")


## ==================== 内部: HTTP 层 ====================

## 独立 HTTP 请求：返回 {"__ok":true,"__data":...} 或 {"__error":...,"__status":...}
## TASK-028: 节点 process_mode=ALWAYS（暂停期间照常轮询）+ timeout 兜底
## log_prefix: 请求发送后输出 "<prefix> REQUEST_SENT" 日志
func _http_request(method: int, endpoint: String, body: Dictionary = {}, log_prefix: String = "") -> Dictionary:
	var url = APIConfig.get_full_url(endpoint)
	var headers: PackedStringArray = ["Content-Type: application/json"]
	if TokenManager.has_token():
		headers.append(TokenManager.get_auth_header())

	var http = HTTPRequest.new()
	http.timeout = HTTP_TIMEOUT
	http.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(http)

	var body_string: String = JSON.stringify(body) if method != HTTPClient.METHOD_GET else ""
	var error = http.request(url, headers, method, body_string)
	if error != OK:
		http.queue_free()
		return {"__error": "HTTP请求创建失败", "__status": 0}

	if log_prefix != "":
		print(log_prefix, " REQUEST_SENT url=", url)

	var result: Array = await http.request_completed
	http.queue_free()

	if result[0] != HTTPRequest.RESULT_SUCCESS:
		# 超时/网络失败——此处返回后由调用方统一走释放出口
		return {"__error": "网络请求失败或超时", "__status": 0}

	var status_code: int = result[1]
	var json := JSON.new()
	var parse_result = json.parse(result[3].get_string_from_utf8())
	var data: Variant = json.data if parse_result == OK else {}

	if status_code >= 200 and status_code < 300:
		return {"__ok": true, "__status": status_code, "__data": data}

	var err_msg := "未知错误"
	if data is Dictionary:
		err_msg = str(data.get("detail", data.get("message", err_msg)))
	return {"__error": err_msg, "__status": status_code, "__data": data}


## ==================== 内部: 数据规整 ====================

## 服务器 JSON 数值为 float，规整为 int 存储（下游显示/比较隐患）
func _normalize_saves(raw: Array) -> Array:
	var result: Array = []
	for item in raw:
		if item is Dictionary:
			result.append(_normalize_entry(item))
	return result


func _normalize_entry(entry: Dictionary) -> Dictionary:
	var clean: Dictionary = entry.duplicate()
	for key in ["slot_number", "current_floor", "play_time", "kill_count", "gold_collected", "id", "user_id", "is_active"]:
		if clean.has(key) and clean[key] is float:
			clean[key] = int(clean[key])
	return clean


## TASK-026: 保存/创建成功后更新内存存档列表（同槽位替换，新槽位追加）
func _refresh_saves_entry(record: Dictionary) -> void:
	if record.is_empty():
		return
	var entry: Dictionary = _normalize_entry(record)
	var slot := int(entry.get("slot_number", -1))
	if slot < 1:
		return
	for i in range(_saves.size()):
		if _saves[i] is Dictionary and int(_saves[i].get("slot_number", -1)) == slot:
			_saves[i] = entry
			print("[SaveService] Memory save list refreshed (slot ", slot, " updated)")
			return
	_saves.append(entry)
	print("[SaveService] Memory save list refreshed (slot ", slot, " appended)")
