## 房间内容管理器
##
## 根据NewRoomData生成RoomContentData
## 管理房间内容的数据驱动
## 支持AI内容生成

extends Node

## 当前楼层
var _current_floor: int = 1

## 当前玩家等级
var _player_level: int = 1

## 房间内容缓存
var _room_contents: Dictionary = {}  # room_id -> RoomContentData

## 可用怪物类型
var _available_monster_types: Array[String] = []

## AIContentService引用
var _ai_content_service: Node = null

## 是否使用AI生成
var _use_ai: bool = true

## 信号
signal room_content_generated(room_id: int, content: RoomContentData)


## 初始化
func _ready() -> void:
	print("[RoomContentManager] Initialized")


## 设置当前楼层
func set_current_floor(floor: int) -> void:
	_current_floor = floor


## 设置可用怪物类型
func set_available_monster_types(types: Array[String]) -> void:
	_available_monster_types = types


## 设置AIContentService引用
func set_ai_content_service(ai_service: Node) -> void:
	_ai_content_service = ai_service
	print("[RoomContentManager] Connected to AIContentService")


## 设置是否使用AI
func set_use_ai(use_ai: bool) -> void:
	_use_ai = use_ai
	print("[RoomContentManager] Use AI: ", use_ai)


## 设置玩家等级
func set_player_level(level: int) -> void:
	_player_level = level


## 从ResourceService加载怪物类型
func load_monster_types_from_resource() -> void:
	var monsters = ResourceService.get_monsters()
	_available_monster_types.clear()

	for monster in monsters:
		if monster.type not in _available_monster_types:
			_available_monster_types.append(monster.type)

	print("[RoomContentManager] Loaded monster types: ", _available_monster_types)


## 为房间生成内容（永远返回有效的RoomContentData）
func generate_content_for_room(room_node: NewRoomData) -> RoomContentData:
	# 检查缓存
	if _room_contents.has(room_node.id):
		var cached = _room_contents[room_node.id]
		# Phase 9.4: 已锁定的内容不允许被AI异步结果覆盖
		if cached.is_finalized:
			print("[RoomContentManager] Room ", room_node.id, " is finalized, returning cached content")
			return cached
		return cached

	var content: RoomContentData = null

	# 尝试使用AI生成
	if _use_ai and _ai_content_service:
		content = await _ai_content_service.generate_room_content(room_node, _current_floor, _player_level)

	# Phase 9.4: AI返回后再次检查锁定状态（AI是异步的，期间房间可能已finalize）
	if _room_contents.has(room_node.id) and _room_contents[room_node.id].is_finalized:
		print("[RoomContentManager] Room ", room_node.id, " was finalized during AI generation, discarding AI result")
		return _room_contents[room_node.id]

	# 如果AI失败或返回null，使用本地生成
	if content == null:
		print("[RoomContentManager] AI returned null, using local generation for room ", room_node.id)
		content = RoomContentData.from_room_node(room_node, _current_floor)

		# 设置怪物类型
		if _available_monster_types.size() > 0:
			content.set_monster_types(_available_monster_types)

	# 确保content不为null（双重保护）
	if content == null:
		print("[RoomContentManager] Error: content is still null, creating default")
		content = RoomContentData.new()
		content.room_id = room_node.id
		content.room_type = room_node.get_type_string()

	# 缓存内容
	_room_contents[room_node.id] = content

	print("[RoomContentManager] Generated content for room ", room_node.id)
	content.print_info()

	room_content_generated.emit(room_node.id, content)
	return content


## 获取房间内容
func get_room_content(room_id: int) -> RoomContentData:
	return _room_contents.get(room_id)


## 清除缓存
func clear_cache() -> void:
	_room_contents.clear()
	print("[RoomContentManager] Cache cleared")


## 为整层生成所有房间内容
func generate_floor_content(rooms: Array[NewRoomData]) -> void:
	print("[RoomContentManager] Generating content for ", rooms.size(), " rooms")

	for room in rooms:
		generate_content_for_room(room)

	print("[RoomContentManager] Floor content generated")


## 获取房间的怪物配置
func get_monster_config(room_id: int) -> Dictionary:
	var content = _room_contents.get(room_id)
	if not content:
		return {}

	return {
		"count": content.monster_count,
		"level": content.monster_level,
		"types": content.monster_types
	}


## 获取房间的奖励配置
func get_reward_config(room_id: int) -> Dictionary:
	var content = _room_contents.get(room_id)
	if not content:
		return {}

	return {
		"count": content.reward_count,
		"quality": content.reward_quality
	}


## 获取房间的宝箱配置
func get_chest_config(room_id: int) -> Dictionary:
	var content = _room_contents.get(room_id)
	if not content:
		return {}

	return {
		"count": content.chest_count,
		"quality": content.chest_quality
	}
