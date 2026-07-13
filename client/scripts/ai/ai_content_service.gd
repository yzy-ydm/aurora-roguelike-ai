## AI内容服务
##
## 统一AI内容生成接口
## 管理AI服务调用和降级策略
## 集成验证、缓存、质量检查
## 支持云端AI服务调用

extends Node

## AI服务类型
enum AIServiceType {
	FAKE,       # 本地模拟
	REAL        # 真实AI API
}

## 当前服务类型
var _service_type: AIServiceType = AIServiceType.FAKE

## AI服务引用
var _fake_ai_service: Node = null
var _response_parser: Node = null
var _validator: Node = null
var _cache_manager: Node = null
var _quality_checker: Node = null

## HTTP请求节点
var _http_request: HTTPRequest = null

## AI服务端Token
var _ai_token: String = ""
var _token_loading: bool = false

## 降级策略：是否使用本地随机生成
var _use_fallback: bool = true

## 缓存策略：是否使用缓存
var _use_cache: bool = true

## 质量阈值
var _quality_threshold: float = 0.5

## 信号
signal content_generated(content_type: String, data: Dictionary)
signal content_generation_failed(error: String)
signal content_validated(data_type: String, is_valid: bool)
signal content_cached(data_type: String)
signal content_quality_checked(data_type: String, score: float)


## 初始化
func _ready() -> void:
	# 创建解析器
	_response_parser = Node.new()
	_response_parser.name = "AIResponseParser"
	_response_parser.set_script(load("res://scripts/ai/ai_response_parser.gd"))
	add_child(_response_parser)

	# 创建验证器
	_validator = Node.new()
	_validator.name = "AIValidator"
	_validator.set_script(load("res://scripts/ai/ai_validator.gd"))
	add_child(_validator)

	# 创建缓存管理器
	_cache_manager = Node.new()
	_cache_manager.name = "AICacheManager"
	_cache_manager.set_script(load("res://scripts/ai/ai_cache_manager.gd"))
	add_child(_cache_manager)

	# 创建质量检查器
	_quality_checker = Node.new()
	_quality_checker.name = "AIQualityChecker"
	_quality_checker.set_script(load("res://scripts/ai/ai_quality_checker.gd"))
	add_child(_quality_checker)

	# 创建模拟AI服务
	_fake_ai_service = Node.new()
	_fake_ai_service.name = "FakeAIService"
	_fake_ai_service.set_script(load("res://scripts/ai/fake_ai_service.gd"))
	add_child(_fake_ai_service)

	# 创建HTTP请求节点
	_http_request = HTTPRequest.new()
	_http_request.name = "AIHTTPRequest"
	add_child(_http_request)

	# 加载缓存
	if _use_cache:
		_cache_manager.load_cache()

	print("[AIContentService] Initialized with full quality control pipeline")


## 设置服务类型
func set_service_type(type: AIServiceType) -> void:
	_service_type = type
	print("[AIContentService] Service type set to: ", type)


## 设置是否使用缓存
func set_use_cache(use_cache: bool) -> void:
	_use_cache = use_cache
	print("[AIContentService] Use cache: ", use_cache)


## 设置质量阈值
func set_quality_threshold(threshold: float) -> void:
	_quality_threshold = threshold
	print("[AIContentService] Quality threshold: ", threshold)


## 生成楼层内容
func generate_floor_content(floor_level: int, player_level: int = 1) -> Array[RoomNodeData]:
	print("[AIContentService] Generating floor content for level ", floor_level)

	# 1. 检查缓存
	if _use_cache and _cache_manager.has_floor_cache(floor_level):
		print("[AIContentService] Using cached floor data")
		var cached_data = _cache_manager.get_floor_cache(floor_level)
		var rooms = _response_parser.parse_floor_data(cached_data)
		if rooms.size() > 0:
			return rooms

	# 2. 调用AI服务
	var response = await _call_ai_service_floor(floor_level, player_level)

	if response.is_empty():
		print("[AIContentService] AI service returned empty, using fallback")
		return _generate_fallback_floor(floor_level)

	# 3. 验证响应
	response = _validator.validate_floor_data(response)
	content_validated.emit("floor", true)

	# 4. 质量检查
	var quality_score = _quality_checker.check_floor_quality(response)
	content_quality_checked.emit("floor", quality_score)

	if quality_score < _quality_threshold:
		print("[AIContentService] Quality score below threshold, using fallback")
		return _generate_fallback_floor(floor_level)

	# 5. 缓存结果
	if _use_cache:
		_cache_manager.set_floor_cache(floor_level, response)
		content_cached.emit("floor")

	# 6. 解析响应
	var rooms = _response_parser.parse_floor_data(response)

	if rooms.size() == 0:
		print("[AIContentService] Parsed rooms is empty, using fallback")
		return _generate_fallback_floor(floor_level)

	print("[AIContentService] Generated ", rooms.size(), " rooms from AI")
	content_generated.emit("floor", response)

	return rooms


## 生成房间内容
func generate_room_content(room_node: RoomNodeData, floor_level: int, player_level: int = 1) -> RoomContentData:
	print("[AIContentService] Generating content for room ", room_node.id)

	# 1. 检查缓存
	if _use_cache and _cache_manager.has_room_cache(room_node.id):
		print("[AIContentService] Using cached room content")
		var cached_data = _cache_manager.get_room_cache(room_node.id)
		var content = _response_parser.parse_room_content(cached_data)
		return content

	# 2. 调用AI服务
	var response = await _call_ai_service_room(room_node, floor_level, player_level)

	if response.is_empty():
		print("[AIContentService] AI service returned empty, using fallback")
		return _generate_fallback_room_content(room_node, floor_level)

	# 3. 验证响应
	response = _validator.validate_room_content(response)
	content_validated.emit("room_content", true)

	# 4. 质量检查
	var quality_score = _quality_checker.check_room_content_quality(response)
	content_quality_checked.emit("room_content", quality_score)

	if quality_score < _quality_threshold:
		print("[AIContentService] Quality score below threshold, using fallback")
		return _generate_fallback_room_content(room_node, floor_level)

	# 5. 缓存结果
	if _use_cache:
		_cache_manager.set_room_cache(room_node.id, response)
		content_cached.emit("room_content")

	# 6. 解析响应
	var content = _response_parser.parse_room_content(response)

	print("[AIContentService] Generated content for room ", room_node.id)
	content_generated.emit("room", response)

	return content


## 调用AI服务生成楼层
func _call_ai_service_floor(floor_level: int, player_level: int) -> Dictionary:
	match _service_type:
		AIServiceType.FAKE:
			return await _fake_ai_service.generate_floor(floor_level, player_level)
		AIServiceType.REAL:
			return await _call_cloud_ai_floor(floor_level, player_level)
		_:
			return {}


## 调用AI服务生成房间内容
func _call_ai_service_room(room_node: RoomNodeData, floor_level: int, player_level: int) -> Dictionary:
	match _service_type:
		AIServiceType.FAKE:
			return await _fake_ai_service.generate_room_content(
				room_node.id,
				room_node.get_type_string(),
				floor_level,
				player_level
			)
		AIServiceType.REAL:
			return await _call_cloud_ai_room(room_node, floor_level, player_level)
		_:
			return {}


## 调用云端AI生成楼层
func _call_cloud_ai_floor(floor_level: int, player_level: int) -> Dictionary:
	print("[AIContentService] Calling cloud AI for floor generation...")

	# 确保有Token
	await _ensure_ai_token()

	# 构建请求数据
	var request_data = {
		"floor_level": floor_level,
		"player_level": player_level
	}

	# 发送HTTP请求
	var response = await _send_ai_request(APIConfig.AI_GENERATE_FLOOR, request_data)

	if response.is_empty():
		print("[AIContentService] Cloud AI returned empty, will use fallback")
		return {}

	print("[AIContentService] Cloud response received for floor")
	return response


## 调用云端AI生成房间内容
func _call_cloud_ai_room(room_node: RoomNodeData, floor_level: int, player_level: int) -> Dictionary:
	print("[AIContentService] Calling cloud AI for room content...")

	# 确保有Token
	await _ensure_ai_token()

	# 构建请求数据
	var request_data = {
		"room_id": room_node.id,
		"room_type": room_node.get_type_string(),
		"floor_level": floor_level,
		"player_level": player_level
	}

	# 发送HTTP请求
	var response = await _send_ai_request(APIConfig.AI_GENERATE_ROOM, request_data)

	if response.is_empty():
		print("[AIContentService] Cloud AI returned empty, will use fallback")
		return {}

	print("[AIContentService] Cloud response received for room")
	return response


## 确保有AI服务端Token
func _ensure_ai_token() -> void:
	# 如果已有Token，直接返回
	if _ai_token != "":
		return

	# 如果正在加载Token，等待
	if _token_loading:
		print("[AIContentService] Waiting for token...")
		while _token_loading:
			await get_tree().process_frame
		return

	# 获取Token
	_token_loading = true
	print("[AIContentService] Fetching AI service token...")

	var token_url = APIConfig.get_ai_url(APIConfig.AI_AUTH_TOKEN)
	var headers = ["Content-Type: application/json"]

	# 使用HTTPRequest获取Token
	var http = HTTPRequest.new()
	http.timeout = 5.0  # 5秒超时
	add_child(http)

	var error = http.request(token_url + "?client_id=godot_client", headers, HTTPClient.METHOD_GET)
	if error != OK:
		print("[AIContentService] Failed to request token: ", error)
		http.queue_free()
		_token_loading = false
		return

	# 等待响应
	var result = await http.request_completed
	http.queue_free()

	# 检查结果
	if result[0] != HTTPRequest.RESULT_SUCCESS:
		print("[AIContentService] Token request failed: ", result[0])
		_token_loading = false
		return

	if result[1] != 200:
		print("[AIContentService] Token request returned status: ", result[1])
		_token_loading = false
		return

	# 解析响应
	var json = JSON.new()
	var parse_result = json.parse(result[3].get_string_from_utf8())
	if parse_result != OK:
		print("[AIContentService] Failed to parse token response")
		_token_loading = false
		return

	var data = json.data
	if data is Dictionary and data.has("token"):
		_ai_token = data["token"]
		print("[AIContentService] Token acquired successfully")
	else:
		print("[AIContentService] Invalid token response")

	_token_loading = false


## 发送AI请求
func _send_ai_request(endpoint: String, request_data: Dictionary) -> Dictionary:
	var url = APIConfig.get_ai_url(endpoint)
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer " + _ai_token
	]
	var json_string = JSON.stringify(request_data)

	print("[AIContentService] Sending request to: ", url)

	# 创建新的HTTPRequest
	var http = HTTPRequest.new()
	http.timeout = 10.0  # 10秒超时
	add_child(http)

	var error = http.request(url, headers, HTTPClient.METHOD_POST, json_string)
	if error != OK:
		print("[AIContentService] HTTP request failed: ", error)
		http.queue_free()
		return {}

	# 等待响应（带超时检测）
	var result = await http.request_completed
	http.queue_free()

	# 检查结果
	if result[0] != HTTPRequest.RESULT_SUCCESS:
		if result[0] == HTTPRequest.RESULT_TIMEOUT:
			print("[AIContentService] HTTP request timeout, will use fallback")
		else:
			print("[AIContentService] HTTP request failed with result: ", result[0])
		return {}

	var status_code = result[1]
	print("[AIContentService] Response status: ", status_code)

	if status_code != 200:
		print("[AIContentService] Server returned error status: ", status_code)
		return {}

	# 解析JSON响应
	var response_body = result[3].get_string_from_utf8()
	var json = JSON.new()
	var parse_result = json.parse(response_body)

	if parse_result != OK:
		print("[AIContentService] Failed to parse JSON response")
		return {}

	var data = json.data
	if data is Dictionary:
		return data

	print("[AIContentService] Invalid response format")
	return {}


## 降级：生成本地楼层
func _generate_fallback_floor(floor_level: int) -> Array[RoomNodeData]:
	print("[AIContentService] Fallback to fake AI for floor generation")

	# 使用本地FloorGenerator
	var floor_generator = Node.new()
	floor_generator.set_script(load("res://scripts/world/floor_generator.gd"))
	add_child(floor_generator)

	var rooms = floor_generator.generate_floor(floor_level)

	floor_generator.queue_free()

	return rooms


## 降级：生成本地房间内容
func _generate_fallback_room_content(room_node: RoomNodeData, floor_level: int) -> RoomContentData:
	print("[AIContentService] Fallback to fake AI for room content generation")

	# 使用本地RoomContentData
	var content = RoomContentData.from_room_node(room_node, floor_level)

	# 设置默认怪物类型
	var monster_types: Array[String] = ["goblin", "skeleton"]
	content.set_monster_types(monster_types)

	return content


## 获取当前服务类型
func get_service_type() -> AIServiceType:
	return _service_type


## 检查是否使用真实AI
func is_using_real_ai() -> bool:
	return _service_type == AIServiceType.REAL


## 获取缓存统计
func get_cache_stats() -> Dictionary:
	if _cache_manager:
		return _cache_manager.get_cache_stats()
	return {}


## 保存缓存
func save_cache() -> void:
	if _cache_manager:
		_cache_manager.save_cache()


## 清除缓存
func clear_cache() -> void:
	if _cache_manager:
		_cache_manager.clear_cache()


## 打印状态
func print_status() -> void:
	print("[AIContentService] Status:")
	print("  Service type: ", _service_type)
	print("  Use cache: ", _use_cache)
	print("  Quality threshold: ", _quality_threshold)
	print("  Token loaded: ", _ai_token != "")

	if _cache_manager:
		_cache_manager.print_cache_status()
