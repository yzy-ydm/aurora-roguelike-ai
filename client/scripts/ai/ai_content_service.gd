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

## TASK-030: AI 运行模式（初始化时探测一次，会话内保持稳定）
enum AIMode {
	UNKNOWN,        # 初始化中
	CLOUD_READY,    # 云端可用（token 获取成功）
	FALLBACK        # 本地降级（token 失败/超时/未启用云端）
}

## 当前服务类型
var _service_type: AIServiceType = AIServiceType.FAKE

## 当前运行模式（TASK-030）
var _mode: AIMode = AIMode.UNKNOWN

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
var _token_failed: bool = false  # Token获取失败标记

## Phase 21.4: 初始化状态
var _initializing: bool = false
var _initialized: bool = false

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


## 初始化 (Phase 21.4.1: 不在_ready中初始化，等待GameScene调用)
func _ready() -> void:
	# Phase 21.4.1: 不自动初始化，等待GameScene调用start_initialization()
	print("[AIContentService] Ready, waiting for initialization call")


## Phase 21.4.1: 由GameScene调用启动初始化
func start_initialization() -> void:
	if _initializing or _initialized:
		return
	# 使用call_deferred避免阻塞GameScene
	call_deferred("_initialize_async")


## 异步初始化
func _initialize_async() -> void:
	# Phase 21.4: 防止重复初始化
	if _initializing or _initialized:
		return

	_initializing = true
	print("[AIContentService] Starting async initialization...")

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

	_initializing = false
	_initialized = true
	print("[AIContentService] Async initialization completed")

	# TASK-030: 云端可用性探测——进入游戏前明确 AI MODE（CLOUD READY / FALLBACK）
	# 保证第一个房间起模式稳定，不再"第一次房间 fallback、后面 cloud"
	if _service_type == AIServiceType.REAL:
		await _ensure_ai_token()
		if _ai_token != "":
			_mode = AIMode.CLOUD_READY
		else:
			_mode = AIMode.FALLBACK
	else:
		_mode = AIMode.FALLBACK
	print("[AIContentService] AI MODE: ", "CLOUD READY" if _mode == AIMode.CLOUD_READY else "FALLBACK")


## TASK-030: 等待初始化完成（含云端探测），返回是否 CLOUD READY
## game_scene 在生成楼层前调用，保证第一个房间就有明确模式
func await_ready(timeout: float = 5.0) -> bool:
	if _mode != AIMode.UNKNOWN:
		return _mode == AIMode.CLOUD_READY
	var waited := 0.0
	while _mode == AIMode.UNKNOWN and waited < timeout:
		await get_tree().create_timer(0.1).timeout
		waited += 0.1
	if _mode == AIMode.UNKNOWN:
		_mode = AIMode.FALLBACK
		print("[AIContentService] AI MODE: FALLBACK (initialization timeout)")
	return _mode == AIMode.CLOUD_READY


## 获取当前运行模式
func get_ai_mode() -> AIMode:
	return _mode


## TASK-030: 云端降级——token 失败后会话内保持 FALLBACK（不再反复尝试云端）
func _downgrade_to_fallback() -> void:
	if _mode == AIMode.CLOUD_READY or _mode == AIMode.UNKNOWN:
		_mode = AIMode.FALLBACK
		print("[AIContentService] AI MODE: FALLBACK (cloud token unavailable)")


## Phase 21.4.1: 检查AI服务是否已初始化
## 不触发初始化，只检查状态
func is_initialized() -> bool:
	return _initialized


## 设置服务类型
func set_service_type(type: AIServiceType) -> void:
	_service_type = type
	print("[AIContentService] Service type set to: ", type)
	# TASK-030: FAKE 模式即为本地降级模式
	if type == AIServiceType.FAKE and _mode == AIMode.UNKNOWN:
		_mode = AIMode.FALLBACK


## 设置是否使用缓存
func set_use_cache(use_cache: bool) -> void:
	_use_cache = use_cache
	print("[AIContentService] Use cache: ", use_cache)


## 设置质量阈值
func set_quality_threshold(threshold: float) -> void:
	_quality_threshold = threshold
	print("[AIContentService] Quality threshold: ", threshold)


## Phase 23: 从 NewRoomData 生成房间内容
## TASK-030: 删除 AI 楼层拓扑生成（generate_floor_content）与旧 RoomNodeData 房间内容路径
## AI 职责边界 = 房间内容增强；地图结构由 FloorGenerator + Validation 负责
func generate_room_content_from_new(room: NewRoomData, floor_level: int, player_level: int = 1) -> RoomContentData:
	print("[AIContentService] Generating content for room (NewRoomData) ", room.id)

	# Phase 21.4.1: 检查是否已初始化，未初始化直接返回fallback
	if not is_initialized():
		print("[AIContentService] Not initialized, using fallback for room ", room.id)
		return _generate_fallback_room_content_from_new(room, floor_level)

	# 1. 检查缓存
	if _use_cache and _cache_manager.has_room_cache(room.id):
		print("[AIContentService] Using cached room content")
		var cached_data = _cache_manager.get_room_cache(room.id)
		return _response_parser.parse_room_content(cached_data)

	# 2. 调用AI服务
	var response = await _call_ai_service_room_from_new(room, floor_level, player_level)

	if response.is_empty():
		print("[AIContentService] AI service returned empty, using fallback")
		return _generate_fallback_room_content_from_new(room, floor_level)

	# 3. 验证响应
	response = _validator.validate_room_content(response)
	content_validated.emit("room_content", true)

	# 4. 质量检查
	var quality_score = _quality_checker.check_room_content_quality(response)
	content_quality_checked.emit("room_content", quality_score)

	if quality_score < _quality_threshold:
		print("[AIContentService] Quality score below threshold, using fallback")
		return _generate_fallback_room_content_from_new(room, floor_level)

	# 5. 缓存结果
	if _use_cache:
		_cache_manager.set_room_cache(room.id, response)
		content_cached.emit("room_content")

	# 6. 解析响应
	var content = _response_parser.parse_room_content(response)

	print("[AIContentService] Generated content for room (NewRoomData) ", room.id)
	content_generated.emit("room", response)

	return content


## Phase 23: 从 NewRoomData 调用AI服务生成房间内容
func _call_ai_service_room_from_new(room: NewRoomData, floor_level: int, player_level: int) -> Dictionary:
	match _service_type:
		AIServiceType.FAKE:
			return await _fake_ai_service.generate_room_content(
				room.id,
				room.get_type_string(),
				floor_level,
				player_level
			)
		AIServiceType.REAL:
			return await _call_cloud_ai_room_from_new(room, floor_level, player_level)
		_:
			return {}


## Phase 23: 从 NewRoomData 调用云端AI生成房间内容
func _call_cloud_ai_room_from_new(room: NewRoomData, floor_level: int, player_level: int) -> Dictionary:
	print("[AIContentService] Calling cloud AI for room content (NewRoomData)...")

	# 确保有Token
	await _ensure_ai_token()

	# 检查Token是否获取失败
	if _token_failed:
		print("[AIContentService] Token failed, skipping cloud AI")
		return {}

	# 构建请求数据
	var request_data = {
		"room_id": room.id,
		"room_type": room.get_type_string(),
		"floor_level": floor_level,
		"player_level": player_level
	}

	# 发送HTTP请求
	var response = await _send_ai_request(APIConfig.AI_GENERATE_ROOM, request_data)

	if response.is_empty():
		print("[AIContentService] Cloud AI returned empty, will use fallback")
		return {}

	print("[AIContentService] Cloud response received for room (NewRoomData)")
	return response


## 确保有AI服务端Token
## TASK-020.2: force=true 时强制刷新（用于401恢复；清空旧token与失败标记）
func _ensure_ai_token(force: bool = false) -> void:
	# 如果已有Token且非强制刷新，直接返回
	if _ai_token != "" and not force:
		return

	# 强制刷新: 清空旧token与失败标记
	if force:
		_ai_token = ""
		_token_failed = false

	# 如果之前获取失败，不再尝试
	if _token_failed:
		_downgrade_to_fallback()
		return

	# 如果正在加载Token，等待
	if _token_loading:
		print("[AIContentService] Waiting for token...")
		var wait_count = 0
		while _token_loading and wait_count < 50:  # 最多等待5秒
			await get_tree().process_frame
			wait_count += 1
		return

	# 获取Token
	_token_loading = true
	_token_failed = false
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
		_token_failed = true
		_downgrade_to_fallback()
		return

	# 等待响应（TASK-021: 用 Godot 4 标准 await 信号替代轮询+Signal.get_value()
	# http.timeout=5.0 保证最终返回——超时时信号以 RESULT_TIMEOUT 发射）
	var result = await http.request_completed
	http.queue_free()

	# 检查结果（超时/网络失败/非200 → 标记失败，不再尝试）
	if result[0] != HTTPRequest.RESULT_SUCCESS:
		print("[AIContentService] Token request failed: ", result[0])
		_token_loading = false
		_token_failed = true
		_downgrade_to_fallback()
		return

	if result[1] != 200:
		print("[AIContentService] Token request returned status: ", result[1])
		_token_loading = false
		_token_failed = true
		_downgrade_to_fallback()
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


## 发送AI请求（TASK-020.2: 401 时自动刷新 token 并重试一次，仍失败则归 fallback）
func _send_ai_request(endpoint: String, request_data: Dictionary) -> Dictionary:
	# TASK-030: 非 CLOUD_READY 模式直接走本地降级（不再发起云端请求）
	if _mode != AIMode.CLOUD_READY:
		return {}

	var response = await _do_ai_request(endpoint, request_data)

	# 401: AI服务重启/Token过期 → 清空token → 强制重新获取 → 重试一次
	if response.has("__http_status") and response["__http_status"] == 401:
		print("[AIContentService] AI service returned 401, refreshing token and retrying once")
		await _ensure_ai_token(true)
		if _ai_token != "":
			response = await _do_ai_request(endpoint, request_data)

	# 任何HTTP错误状态统一返回空 → 调用方走 fallback（保持原有契约）
	if response.has("__http_status"):
		return {}
	return response


## 执行单次AI请求（TASK-020.2 从 _send_ai_request 拆分）
## 非200状态时返回 {"__http_status": 状态码}，由 _send_ai_request 统一处理
func _do_ai_request(endpoint: String, request_data: Dictionary) -> Dictionary:
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

	# 等待响应（TASK-021: 用 Godot 4 标准 await 信号替代轮询+Signal.get_value()
	# http.timeout=10.0 保证最终返回——超时时信号以 RESULT_TIMEOUT 发射）
	var result = await http.request_completed
	http.queue_free()

	# 检查结果（网络失败/超时 → 返回空 → 调用方走 fallback）
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
		return {"__http_status": status_code}

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


## Phase 23: 从 NewRoomData 生成本地房间内容
func _generate_fallback_room_content_from_new(room: NewRoomData, floor_level: int) -> RoomContentData:
	print("[AIContentService] Fallback to fake AI for room content generation (NewRoomData)")

	var content = RoomContentData.from_room_node_data(room, floor_level)

	# 设置默认怪物类型
	var monster_types: Array[String] = ["goblin", "skeleton"]
	content.set_monster_types(monster_types)

	return content


## ==================== Phase 11: AI增强功能 ====================
## TASK-030: 删除 generate_room_event（零调用点，事件房用本地事件 + AI context_event）
## 删除 generate_room_strategy / generate_npc_memory_response（零调用点）

## 生成NPC对话(异步，不阻塞)
func generate_npc_dialogue(npc_type: String, room_environment: String, player_state: Dictionary = {}) -> Array[String]:
	print("[AIContentService] Generating NPC dialogue for ", npc_type)

	# 调用AI服务
	var response = await _call_ai_service_dialogue(npc_type, room_environment, player_state)

	if response.is_empty():
		print("[AIContentService] AI dialogue generation failed, using fallback")
		return _generate_mock_dialogue(npc_type)

	# 解析响应（TASK-023: 统一经适配层转换 JSON Array → Array[String]，
	# 禁止未类型化 Array 直接作为类型化返回）
	var dialogue := AIResponseAdapter.to_string_array(response.get("dialogue", []))
	if dialogue.size() > 0:
		content_generated.emit("dialogue", response)
		return dialogue

	return _generate_mock_dialogue(npc_type)


## 调用AI服务生成对话
func _call_ai_service_dialogue(npc_type: String, room_environment: String, player_state: Dictionary) -> Dictionary:
	match _service_type:
		AIServiceType.FAKE:
			return {"dialogue": _generate_mock_dialogue(npc_type)}
		AIServiceType.REAL:
			return await _call_cloud_ai_dialogue(npc_type, room_environment, player_state)
		_:
			return {}


## 生成模拟对话
func _generate_mock_dialogue(npc_type: String) -> Array[String]:
	match npc_type:
		"merchant":
			return ["欢迎，旅行者！", "我这里有些好东西，看看吧。"]
		"sage":
			return ["前方的道路充满危险...", "小心那些暗影生物。"]
		"guard":
			return ["站住！你是谁？", "这里不安全，快离开。"]
		_:
			return ["...", "你好。"]


## 调用云端AI生成对话
func _call_cloud_ai_dialogue(npc_type: String, room_environment: String, player_state: Dictionary) -> Dictionary:
	print("[AIContentService] Calling cloud AI for dialogue...")

	await _ensure_ai_token()

	if _token_failed:
		return {}

	var request_data = {
		"npc_type": npc_type,
		"room_environment": room_environment,
		"player_state": player_state
	}

	var response = await _send_ai_request(APIConfig.AI_GENERATE_DIALOGUE, request_data)
	return response


## ==================== 原有方法 ====================

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
	print("  AI MODE: ", "CLOUD READY" if _mode == AIMode.CLOUD_READY else ("FALLBACK" if _mode == AIMode.FALLBACK else "UNKNOWN"))
	print("  Service type: ", _service_type)
	print("  Use cache: ", _use_cache)
	print("  Quality threshold: ", _quality_threshold)
	print("  Token loaded: ", _ai_token != "")

	if _cache_manager:
		_cache_manager.print_cache_status()


## ==================== Phase 12: 升级强化生成 ====================

## 生成升级强化选项(异步，不阻塞)
func generate_upgrade_options(player_level: int, player_stats: Dictionary = {}) -> Array[Dictionary]:
	print("[AIContentService] Generating upgrade options for level ", player_level)

	# 调用AI服务
	var response = await _call_ai_service_upgrade(player_level, player_stats)

	if response.is_empty():
		print("[AIContentService] AI upgrade generation failed, using fallback")
		return _generate_mock_upgrades(player_level)

	# 解析响应（TASK-023: 统一经适配层转换 JSON Array → Array[Dictionary]）
	var upgrades := AIResponseAdapter.to_dictionary_array(response.get("upgrades", []))
	if upgrades.size() > 0:
		content_generated.emit("upgrade", response)
		return upgrades

	return _generate_mock_upgrades(player_level)


## 调用AI服务生成强化
func _call_ai_service_upgrade(player_level: int, player_stats: Dictionary) -> Dictionary:
	match _service_type:
		AIServiceType.FAKE:
			return {"upgrades": _generate_mock_upgrades(player_level)}
		AIServiceType.REAL:
			return await _call_cloud_ai_upgrade(player_level, player_stats)
		_:
			return {}


## 生成模拟强化选项
func _generate_mock_upgrades(player_level: int) -> Array[Dictionary]:
	var upgrades: Array[Dictionary] = []

	# 根据玩家等级调整强化强度
	var power_multiplier = 1.0 + (player_level - 1) * 0.1

	# 攻击类强化
	upgrades.append({
		"id": "ai_attack_boost",
		"name": "暗影力量",
		"description": "攻击力 +" + str(int(10 * power_multiplier)),
		"type": "stat_boost",
		"rarity": "uncommon",
		"modifiers": {"attack": int(10 * power_multiplier)},
		"percent_modifiers": {}
	})

	# 生命类强化
	upgrades.append({
		"id": "ai_health_boost",
		"name": "生命源泉",
		"description": "最大生命 +" + str(int(30 * power_multiplier)),
		"type": "stat_boost",
		"rarity": "uncommon",
		"modifiers": {"max_health": int(30 * power_multiplier)},
		"percent_modifiers": {}
	})

	# 速度类强化
	upgrades.append({
		"id": "ai_speed_boost",
		"name": "疾风步",
		"description": "移动速度 +15%",
		"type": "stat_boost",
		"rarity": "rare",
		"modifiers": {},
		"percent_modifiers": {"move_speed": 0.15}
	})

	# 暴击类强化
	upgrades.append({
		"id": "ai_crit_boost",
		"name": "致命一击",
		"description": "暴击率 +8%",
		"type": "stat_boost",
		"rarity": "rare",
		"modifiers": {},
		"percent_modifiers": {"crit_rate": 0.08}
	})

	# 防御类强化
	upgrades.append({
		"id": "ai_defense_boost",
		"name": "钢铁意志",
		"description": "防御力 +" + str(int(8 * power_multiplier)),
		"type": "stat_boost",
		"rarity": "uncommon",
		"modifiers": {"defense": int(8 * power_multiplier)},
		"percent_modifiers": {}
	})

	# 特殊强化
	upgrades.append({
		"id": "ai_heal_on_kill",
		"name": "嗜血本能",
		"description": "击杀回复 8 生命",
		"type": "ability",
		"rarity": "rare",
		"modifiers": {"heal_on_kill": 8},
		"percent_modifiers": {}
	})

	# 随机选择3个
	upgrades.shuffle()
	return upgrades.slice(0, 3)


## 调用云端AI生成强化
func _call_cloud_ai_upgrade(player_level: int, player_stats: Dictionary) -> Dictionary:
	print("[AIContentService] Calling cloud AI for upgrade generation...")

	# 确保有Token
	await _ensure_ai_token()

	if _token_failed:
		print("[AIContentService] Token failed, skipping cloud AI")
		return {}

	# 构建请求数据
	var request_data = {
		"player_level": player_level,
		"player_stats": player_stats
	}

	# 发送HTTP请求
	var response = await _send_ai_request(APIConfig.AI_GENERATE_UPGRADE, request_data)

	if response.is_empty():
		print("[AIContentService] Cloud AI returned empty for upgrade")
		return {}

	print("[AIContentService] Cloud response received for upgrade")
	return response


## ==================== Phase 13: AI自适应智能系统 ====================

## 生成难度调整建议(异步，不阻塞)
func generate_difficulty_adjustment(context: Dictionary = {}) -> Dictionary:
	print("[AIContentService] Generating difficulty adjustment")

	# 调用AI服务
	var response = await _call_ai_service_difficulty(context)

	if response.is_empty():
		print("[AIContentService] AI difficulty adjustment failed, using default")
		return _get_default_difficulty()

	# 解析响应
	var difficulty = _parse_difficulty_response(response)
	content_generated.emit("difficulty", response)
	return difficulty


## 调用AI服务生成难度调整
func _call_ai_service_difficulty(context: Dictionary) -> Dictionary:
	match _service_type:
		AIServiceType.FAKE:
			return _generate_mock_difficulty(context)
		AIServiceType.REAL:
			return await _call_cloud_ai_difficulty(context)
		_:
			return {}


## 生成模拟难度调整
func _generate_mock_difficulty(context: Dictionary) -> Dictionary:
	var combat_style = context.get("combat_style", "balanced")
	var death_rate = context.get("death_rate", 0.0)
	var damage_rate = context.get("damage_rate", 0.0)
	var no_hit_rate = context.get("no_hit_rate", 0.0)

	var difficulty = {
		"enemy_hp_multiplier": 1.0,
		"enemy_damage_multiplier": 1.0,
		"elite_spawn_rate": 0.1,
		"reward_multiplier": 1.0
	}

	# 根据玩家表现调整
	if combat_style == "expert" or no_hit_rate > 0.5:
		# 专家玩家: 增加难度
		difficulty["enemy_hp_multiplier"] = 1.2
		difficulty["enemy_damage_multiplier"] = 1.15
		difficulty["elite_spawn_rate"] = 0.2
		difficulty["reward_multiplier"] = 1.2
	elif combat_style == "struggling" or death_rate > 3.0:
		# 困难玩家: 降低难度
		difficulty["enemy_hp_multiplier"] = 0.8
		difficulty["enemy_damage_multiplier"] = 0.85
		difficulty["elite_spawn_rate"] = 0.05
		difficulty["reward_multiplier"] = 1.3
	elif combat_style == "aggressive" or damage_rate > 5.0:
		# 激进玩家: 稍微增加难度
		difficulty["enemy_hp_multiplier"] = 1.1
		difficulty["enemy_damage_multiplier"] = 1.05
		difficulty["elite_spawn_rate"] = 0.15
		difficulty["reward_multiplier"] = 1.1

	return difficulty


## 获取默认难度
func _get_default_difficulty() -> Dictionary:
	return {
		"enemy_hp_multiplier": 1.0,
		"enemy_damage_multiplier": 1.0,
		"elite_spawn_rate": 0.1,
		"reward_multiplier": 1.0
	}


## 解析难度响应
func _parse_difficulty_response(response: Dictionary) -> Dictionary:
	var default = _get_default_difficulty()
	# TASK-023: 数值字段经适配层规整（AI 可能返回字符串数字/整型）
	return {
		"enemy_hp_multiplier": AIResponseAdapter.to_float(response.get("enemy_hp_multiplier"), default["enemy_hp_multiplier"]),
		"enemy_damage_multiplier": AIResponseAdapter.to_float(response.get("enemy_damage_multiplier"), default["enemy_damage_multiplier"]),
		"elite_spawn_rate": AIResponseAdapter.to_float(response.get("elite_spawn_rate"), default["elite_spawn_rate"]),
		"reward_multiplier": AIResponseAdapter.to_float(response.get("reward_multiplier"), default["reward_multiplier"])
	}


## 调用云端AI生成难度调整
func _call_cloud_ai_difficulty(context: Dictionary) -> Dictionary:
	print("[AIContentService] Calling cloud AI for difficulty adjustment...")

	await _ensure_ai_token()

	if _token_failed:
		print("[AIContentService] Token failed, skipping cloud AI")
		return {}

	var request_data = {
		"context": context
	}

	var response = await _send_ai_request(APIConfig.AI_GENERATE_DIFFICULTY, request_data)

	if response.is_empty():
		print("[AIContentService] Cloud AI returned empty for difficulty")
		return {}

	print("[AIContentService] Cloud response received for difficulty")
	return response


## 生成上下文事件(增强版)
func generate_context_event(context: Dictionary = {}) -> AIEventData:
	print("[AIContentService] Generating context event")

	var response = await _call_ai_service_context_event(context)

	if response.is_empty():
		print("[AIContentService] AI context event generation failed, using fallback")
		return null

	var event_data = AIEventData.from_dict(AIResponseAdapter.to_safe_dictionary(response))
	if event_data.is_valid():
		content_generated.emit("context_event", response)
		return event_data

	return null


## 调用AI服务生成上下文事件
func _call_ai_service_context_event(context: Dictionary) -> Dictionary:
	match _service_type:
		AIServiceType.FAKE:
			return _generate_mock_context_event(context)
		AIServiceType.REAL:
			return await _call_cloud_ai_context_event(context)
		_:
			return {}


## 生成模拟上下文事件
func _generate_mock_context_event(context: Dictionary) -> Dictionary:
	var player_level = context.get("player_level", 1)
	var combat_style = context.get("combat_style", "balanced")
	var upgrade_preference = context.get("upgrade_preference", "balanced")
	var health_percent = context.get("current_health_percent", 1.0)

	var events = []

	# 根据玩家状态生成不同事件
	if health_percent < 0.3:
		events.append({
			"title": "紧急治疗站",
			"description": "你发现了一个废弃的治疗站，但似乎有危险。",
			"choices": [
				{"text": "冒险治疗", "reward": {"health": 50}, "risk": {"damage": 20}},
				{"text": "小心使用", "reward": {"health": 25}, "risk": {}},
				{"text": "离开", "reward": {}, "risk": {}}
			]
		})
	elif combat_style == "expert":
		events.append({
			"title": "挑战之门",
			"description": "一扇神秘的门出现在你面前，上面刻着挑战的符文。",
			"choices": [
				{"text": "接受挑战", "reward": {"attack": 10, "gold": 100}, "risk": {"damage": 50}},
				{"text": "研究符文", "reward": {"attack": 3}, "risk": {}},
				{"text": "忽略", "reward": {}, "risk": {}}
			]
		})
	elif upgrade_preference == "attack":
		events.append({
			"title": "武器大师",
			"description": "一位年迈的武器大师愿意传授你技巧。",
			"choices": [
				{"text": "学习攻击技巧", "reward": {"attack": 8}, "risk": {}},
				{"text": "学习防御技巧", "reward": {"defense": 5}, "risk": {}},
				{"text": "离开", "reward": {}, "risk": {}}
			]
		})
	else:
		# 默认事件
		events.append({
			"title": "神秘宝箱",
			"description": "你发现了一个发光的宝箱。",
			"choices": [
				{"text": "打开", "reward": {"gold": 50}, "risk": {"damage": 15}},
				{"text": "检查陷阱", "reward": {"gold": 20}, "risk": {}},
				{"text": "离开", "reward": {}, "risk": {}}
			]
		})

	return events[0]


## 调用云端AI生成上下文事件
func _call_cloud_ai_context_event(context: Dictionary) -> Dictionary:
	print("[AIContentService] Calling cloud AI for context event...")

	await _ensure_ai_token()

	if _token_failed:
		return {}

	var request_data = {
		"context": context
	}

	var response = await _send_ai_request(APIConfig.AI_GENERATE_CONTEXT_EVENT, request_data)

	if response.is_empty():
		print("[AIContentService] Cloud AI returned empty for context event")
		return {}

	print("[AIContentService] Cloud response received for context event")
	return response
