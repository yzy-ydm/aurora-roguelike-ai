## AI内容服务
##
## 统一AI内容生成接口
## 管理AI服务调用和降级策略
## 集成验证、缓存、质量检查

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
			# TODO: 调用真实AI API
			print("[AIContentService] Real AI not implemented yet")
			return {}
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
			# TODO: 调用真实AI API
			print("[AIContentService] Real AI not implemented yet")
			return {}
		_:
			return {}


## 降级：生成本地楼层
func _generate_fallback_floor(floor_level: int) -> Array[RoomNodeData]:
	print("[AIContentService] Using fallback floor generation")

	# 使用本地FloorGenerator
	var floor_generator = Node.new()
	floor_generator.set_script(load("res://scripts/world/floor_generator.gd"))
	add_child(floor_generator)

	var rooms = floor_generator.generate_floor(floor_level)

	floor_generator.queue_free()

	return rooms


## 降级：生成本地房间内容
func _generate_fallback_room_content(room_node: RoomNodeData, floor_level: int) -> RoomContentData:
	print("[AIContentService] Using fallback room content generation")

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

	if _cache_manager:
		_cache_manager.print_cache_status()
