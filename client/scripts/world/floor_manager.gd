## 楼层管理器 (Phase 13)
##
## 职责:
## - 生成楼层结构(FloorData)
## - 管理房间切换
## - 协调RoomRenderer和RoomSpawner
## - 集成AI上下文系统
##
## 不再负责:
## - 房间视觉渲染(委托RoomRenderer)
## - 怪物/奖励生成(委托RoomSpawner)

extends Node

## ==================== 引用 ====================

## 楼层生成器(本地降级)
var _floor_generator: Node = null

## AI内容服务(后台)
var _ai_content_service: Node = null

## AI上下文管理器
var _ai_context_manager: Node = null

## 房间渲染器
var _room_renderer: Node = null

## 房间生成器
var _room_spawner: Node = null

## 当前楼层数据
var _current_floor: FloorData = null

## 当前难度调整
var _difficulty_adjustment: Dictionary = {
	"enemy_hp_multiplier": 1.0,
	"enemy_damage_multiplier": 1.0,
	"elite_spawn_rate": 0.1,
	"reward_multiplier": 1.0
}

## ==================== 信号 ====================

signal floor_generated(floor_data: FloorData)
signal room_entered(room: NewRoomData)
signal room_exited(room: NewRoomData)
signal floor_completed()
signal ai_event_received(event_data)  # Phase 13: AI事件信号
signal difficulty_adjusted(adjustment: Dictionary)  # Phase 13: 难度调整信号

## Phase 15: AI请求状态信号
signal ai_request_started(request_type: String)
signal ai_request_finished(request_type: String)
signal ai_request_failed(request_type: String, error: String)


## ==================== 初始化 ====================

func _ready() -> void:
	# 创建楼层生成器
	_floor_generator = Node.new()
	_floor_generator.name = "FloorGenerator"
	_floor_generator.set_script(load("res://scripts/world/floor_generator.gd"))
	add_child(_floor_generator)

	# 创建房间渲染器
	_room_renderer = Node.new()
	_room_renderer.name = "RoomRenderer"
	_room_renderer.set_script(load("res://scripts/world/room_renderer.gd"))
	add_child(_room_renderer)

	# 创建房间生成器
	_room_spawner = Node.new()
	_room_spawner.name = "RoomSpawner"
	_room_spawner.set_script(load("res://scripts/world/room_spawner.gd"))
	add_child(_room_spawner)

	print("[FloorManager] Initialized with RoomRenderer and RoomSpawner")


## ==================== 配置 ====================

func set_room_container(container: Node2D) -> void:
	_room_renderer.set_room_container(container)


func set_monster_container(container: Node2D) -> void:
	_room_spawner.set_monster_container(container)


func set_reward_container(container: Node2D) -> void:
	_room_spawner.set_reward_container(container)


func set_player(player: CharacterBody2D) -> void:
	_room_spawner.set_player(player)


func set_ai_content_service(ai_service: Node) -> void:
	_ai_content_service = ai_service


## 设置AI上下文管理器 (Phase 13)
func set_ai_context_manager(context_manager: Node) -> void:
	_ai_context_manager = context_manager


## 获取当前难度调整
func get_difficulty_adjustment() -> Dictionary:
	return _difficulty_adjustment


## 获取RoomSpawner(用于连接信号)
func get_room_spawner() -> Node:
	return _room_spawner


## 获取RoomRenderer(用于连接信号)
func get_room_renderer() -> Node:
	return _room_renderer


## ==================== 楼层生成 ====================

func generate_floor(floor_level: int = 1) -> void:
	print("[FloorManager] Generating floor ", floor_level)

	# Phase 23: FloorGenerator 直接返回 NewRoomData，无需转换
	var rooms: Array[NewRoomData] = _floor_generator.generate_floor(floor_level)

	# 构建 FloorData
	_current_floor = FloorData.new()
	_current_floor.floor_level = floor_level

	for room in rooms:
		_current_floor.rooms.append(room)

	# 分配玩家友好的显示编号
	_current_floor.assign_display_indices()

	# 设置起始房间
	if _current_floor.get_room_count() > 0:
		_current_floor.set_current_room(0)

	_current_floor.print_status()
	floor_generated.emit(_current_floor)

	# 进入第一个房间
	enter_room(0)

	print("[FloorManager] Floor generated: ", _current_floor.get_room_count(), " rooms")

	# 后台请求AI更新(不阻塞)
	_request_ai_background(floor_level)

	# 请求难度调整 (Phase 13)
	_request_difficulty_adjustment()


func _request_ai_background(floor_level: int) -> void:
	# Phase 25: Floor结构已冻结，禁止AI重新生成楼层拓扑
	# FloorGenerator是唯一生成源，AI只用于room content和难度调整
	# 保留日志能力供调试
	print("[FloorManager] Floor structure LOCKED. AI floor generation disabled.")
	print("[FloorManager] AI will only enhance room content (background task).")
	ai_request_finished.emit("floor_content")


## ==================== 房间切换 ====================

func enter_room(room_id: int) -> bool:
	if not _current_floor:
		print("[FloorManager] Error: No floor data")
		return false

	var room = _current_floor.get_room(room_id)
	if not room:
		print("[FloorManager] Error: Room not found: ", room_id)
		return false

	# Phase 24: 防止重复进入已完成的房间
	if room.enter_count >= 2:
		print("[FloorManager] Room ", room_id, " already entered/completed, skipping")
		return false

	# 退出当前房间
	var old_room = _current_floor.get_current_room()
	if old_room:
		_exit_room(old_room)

	# 设置新房间为当前房间
	_current_floor.set_current_room(room_id)

	# Phase 24: 增加进入计数
	room.enter_count += 1

	# 生成房间内容(如果没有)
	_ensure_room_content(room)

	# 渲染房间(委托RoomRenderer)
	_room_renderer.render_room(room)

	# 发送信号
	room_entered.emit(room)

	print("[FloorManager] Entered room ", room_id, " (", room.get_type_string(), ") enter_count=", room.enter_count)

	# 后台请求AI增强内容(不阻塞)
	_request_ai_room_content(room)

	return true


func _exit_room(room: NewRoomData) -> void:
	# 清除视觉(委托RoomRenderer)
	_room_renderer.clear_room()

	# 清除怪物和奖励(委托RoomSpawner)
	_room_spawner.clear_monsters()
	_room_spawner.clear_rewards()

	room_exited.emit(room)
	print("[FloorManager] Exited room ", room.id)


## ==================== AI增强 ====================

## 请求AI房间内容(后台，不阻塞)
func _request_ai_room_content(room: NewRoomData) -> void:
	if not _ai_content_service:
		return

	# 获取上下文
	var context = {}
	if _ai_context_manager:
		context = _ai_context_manager.get_event_context()
	else:
		context = {"room_id": room.id, "room_type": room.get_type_string()}

	print("[FloorManager] Requesting AI room content in background...")

	# Phase 15: 发送AI请求开始信号
	ai_request_started.emit("room_content")

	# 请求上下文事件 (Phase 13)
	if _ai_content_service.has_method("generate_context_event"):
		var event_data = await _ai_content_service.generate_context_event(context)
		if event_data:
			print("[FloorManager] AI context event received: ", event_data.title)
			ai_event_received.emit(event_data)

	# 请求NPC对话
	if _ai_content_service.has_method("generate_npc_dialogue"):
		var npc_context = {}
		if _ai_context_manager:
			npc_context = _ai_context_manager.get_npc_context("merchant")
		var dialogue = await _ai_content_service.generate_npc_dialogue(
			"merchant",
			room.get_type_string(),
			npc_context
		)
		if dialogue.size() > 0:
			print("[FloorManager] AI dialogue received: ", dialogue.size(), " lines")

	# Phase 15: 发送AI请求完成信号
	ai_request_finished.emit("room_content")


## 请求AI难度调整 (Phase 13)
func _request_difficulty_adjustment() -> void:
	if not _ai_content_service:
		return

	if not _ai_content_service.has_method("generate_difficulty_adjustment"):
		return

	# 获取上下文
	var context = {}
	if _ai_context_manager:
		context = _ai_context_manager.get_difficulty_context()

	print("[FloorManager] Requesting difficulty adjustment...")

	# Phase 15: 发送AI请求开始信号
	ai_request_started.emit("difficulty")

	var adjustment = await _ai_content_service.generate_difficulty_adjustment(context)
	if adjustment and not adjustment.is_empty():
		_difficulty_adjustment = adjustment
		print("[FloorManager] Difficulty adjusted: HP=", adjustment.get("enemy_hp_multiplier", 1.0))
		difficulty_adjusted.emit(adjustment)
		ai_request_finished.emit("difficulty")
	else:
		ai_request_failed.emit("difficulty", "No adjustment data")


## ==================== 房间内容 ====================

func _ensure_room_content(room: NewRoomData) -> void:
	if room.content:
		# Phase 9.3: 即使已有内容(如AI生成)，也要执行规则校验
		room.content.validate_for_room_type()
		return

	# Phase 23: 本地生成默认内容，直接传入 NewRoomData
	room.content = RoomContentData.from_room_node_data(room, _current_floor.floor_level)

	# Phase 9.3: 执行房间规则校验，防止AI/随机生成违反类型约束
	room.content.validate_for_room_type()

	# 后台请求AI内容(不阻塞)
	if _ai_content_service and _ai_content_service.has_method("generate_room_content"):
		_request_room_content_ai(room)


func _request_room_content_ai(room: NewRoomData) -> void:
	var content = await _ai_content_service.generate_room_content_from_new(
		room,
		_current_floor.floor_level,
		1
	)
	if content:
		# Phase 22.7.1: 检查房间内容是否已被锁定（防止覆盖已激活房间）
		if room.content and room.content.is_finalized:
			print("[FloorManager] AI content IGNORED for room ", room.id, " (content already finalized)")
			return

		# Phase 23: 额外检查 - 如果房间已经有怪物生成过，不覆盖
		# 防止AI异步结果覆盖正在进行的战斗
		if room.content and room.content.monster_count > 0:
			print("[FloorManager] AI content IGNORED for room ", room.id, " (monsters already spawning)")
			return

		# Phase 9.3: AI生成的内容也要经过规则校验
		content.validate_for_room_type()
		room.content = content
		print("[FloorManager] AI content applied for room ", room.id, " monsters=", content.monster_count)


## ==================== 查询接口 ====================

func get_current_floor() -> FloorData:
	return _current_floor


func get_current_room() -> NewRoomData:
	if _current_floor:
		return _current_floor.get_current_room()
	return null


func get_current_content() -> RoomContentData:
	var room = get_current_room()
	if room:
		return room.content
	return null


func get_available_exit_ids() -> Array[int]:
	if _current_floor:
		return _current_floor.get_available_exit_ids()
	return []


func is_floor_complete() -> bool:
	if _current_floor:
		return _current_floor.is_floor_complete()
	return false


func get_floor_level() -> int:
	if _current_floor:
		return _current_floor.floor_level
	return 1


## ==================== 下一层生成 ====================

## 生成下一层（Phase 10.1.6）
## 保留玩家状态，清理旧房间，生成新楼层
func generate_next_floor() -> void:
	var current_level = get_floor_level()
	var next_level = current_level + 1
	print("[FloorManager] Generating next floor: ", current_level, " -> ", next_level)

	# 清理旧房间
	_cleanup_current_floor()

	# 生成新楼层
	generate_floor(next_level)

	print("[FloorManager] Next floor generated: ", next_level)


## 清理当前楼层
func _cleanup_current_floor() -> void:
	# 清理房间渲染
	if _room_renderer:
		_room_renderer.clear_room()

	# 清理怪物和奖励
	if _room_spawner:
		_room_spawner.clear_monsters()
		_room_spawner.clear_rewards()

	# 清理楼层数据
	_current_floor = null

	print("[FloorManager] Current floor cleaned up")
