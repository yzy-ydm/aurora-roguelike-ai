## 房间渲染器 (Phase 17.1: 横版Roguelite房间系统)
##
## 负责当前房间的视觉生成
## - 横版平台布局
## - 地面和平台
## - 出口传送门
## - 房间装饰
## - 房间清空反馈
##
## Phase 17.1: 从俯视角改为横版平台

extends Node

## ==================== 配置 ====================

## 房间尺寸 (横版: 宽屏)
const ROOM_WIDTH: int = 1280
const ROOM_HEIGHT: int = 720
const HALF_WIDTH: int = 640
const HALF_HEIGHT: int = 360

## 地面高度 (从底部算起)
const GROUND_HEIGHT: int = 64
const GROUND_Y: int = HALF_HEIGHT - GROUND_HEIGHT / 2

## 平台配置
const PLATFORM_THICKNESS: int = 16

## TASK-002: 当前房间的平台碰撞矩形列表（local 坐标，position=左上角）
## 由 _create_platform 记录，供奖励生成位置避让查询（WorldCoordinate.reward_spawn_pos）
var _platform_rects: Array[Rect2] = []

## Phase 24: 玩家跳跃可达性约束
## 根据 player_controller.gd 的 GRAVITY=980, JUMP_FORCE=-400 计算:
##   最大垂直高度 = JUMP_FORCE² / (2 * GRAVITY) ≈ 65px
##   最大水平距离 (0.4s内) = MOVE_SPEED * 0.4 ≈ 80px
const MAX_JUMP_HEIGHT: float = 70.0      # 玩家最大跳跃高度(px)
const MAX_JUMP_DISTANCE: float = 120.0  # 玩家最大水平跨越(px)

## ==================== 引用 ====================

## 房间容器（GameWorld）
var _room_container: Node2D = null

## 当前房间节点
var _current_room_node: Node2D = null

## 当前房间的怪物容器（子节点）
var _current_monster_container: Node2D = null

## 当前房间的奖励容器（子节点）
var _current_reward_container: Node2D = null

## 出口传送门列表
var _exit_portals: Array[Area2D] = []

## TASK-005: 当前房间是否已创建出口（同房间最多一个出口；clear_exit_portals 时重置）
var _has_exit_portal: bool = false

## 当前房间位置
var _current_room_position: Vector2 = Vector2.ZERO

## 装饰管理器
var _decoration_manager: Node = null

## 清空反馈系统
var _clear_feedback: Node = null

## Phase 17.2: 背景管理器
var _background_manager: Node = null

## ==================== 信号 ====================

signal exit_portal_entered(target_room_id: int)
signal next_floor_portal_entered()


## ==================== 初始化 ====================

func _ready() -> void:
	_decoration_manager = Node.new()
	_decoration_manager.name = "RoomDecorationManager"
	_decoration_manager.set_script(load("res://scripts/world/room_decoration_manager.gd"))
	add_child(_decoration_manager)

	_clear_feedback = Node.new()
	_clear_feedback.name = "RoomClearFeedback"
	_clear_feedback.set_script(load("res://scripts/world/room_clear_feedback.gd"))
	add_child(_clear_feedback)

	# Phase 17.2: 初始化背景管理器
	_background_manager = Node.new()
	_background_manager.name = "BackgroundManager"
	_background_manager.set_script(load("res://scripts/world/background_manager.gd"))
	add_child(_background_manager)

	print("[PlatformRoom] Initialized with background system")


func set_room_container(container: Node2D) -> void:
	_room_container = container
	if _decoration_manager:
		_decoration_manager.set_decoration_container(container)
	if _clear_feedback:
		_clear_feedback.set_feedback_container(container)
	if _background_manager:
		_background_manager.set_room_container(container)


## Phase 26: 获取当前房间的怪物容器（用于RoomSpawner）
func get_monster_container() -> Node2D:
	return _current_monster_container


## Phase 26: 获取当前房间的奖励容器（用于RoomSpawner）
func get_reward_container() -> Node2D:
	return _current_reward_container


## Phase 26: 获取当前房间节点（用于BackgroundManager等）
func get_current_room_node() -> Node2D:
	return _current_room_node


## TASK-002: 获取当前房间的平台矩形列表（RoomSpawner/GameScene 奖励避让查询）
func get_platform_rects() -> Array[Rect2]:
	return _platform_rects


## ==================== 横版房间渲染 ====================

## 渲染横版房间
func render_room(room: NewRoomData) -> void:
	clear_room()

	if not _room_container:
		print("[PlatformRoom] Error: No room container")
		return

	# Phase 17.2: 生成视差背景
	if _background_manager:
		_background_manager.spawn_background(room.room_type, room.position)

	# 创建房间根节点
	var room_node = Node2D.new()
	room_node.name = "Room_" + str(room.id)
	room_node.position = room.position

	# Phase 26: 为每个房间创建独立的子容器（使用local coordinates）
	_current_monster_container = Node2D.new()
	_current_monster_container.name = "MonsterContainer"
	room_node.add_child(_current_monster_container)

	_current_reward_container = Node2D.new()
	_current_reward_container.name = "RewardContainer"
	room_node.add_child(_current_reward_container)

	# 根据房间类型生成横版布局
	_create_platform_layout(room_node, room)

	# 添加到容器
	_room_container.add_child(room_node)
	_current_room_node = room_node
	_current_room_position = room.position

	print("[PlatformRoom] Room generated: ", room.id, " (", room.get_type_string(), ") monsters_container=", _current_monster_container.name, " rewards_container=", _current_reward_container.name)


## 创建横版平台布局
func _create_platform_layout(parent: Node2D, room: NewRoomData) -> void:
	# 背景
	var bg = _create_background(room)
	parent.add_child(bg)

	# 地面
	var ground = _create_ground()
	parent.add_child(ground)

	# 左右边界
	var left_wall = _create_boundary(-HALF_WIDTH, ROOM_HEIGHT)
	parent.add_child(left_wall)
	var right_wall = _create_boundary(HALF_WIDTH, ROOM_HEIGHT)
	parent.add_child(right_wall)

	# 根据房间类型添加平台
	match room.room_type:
		NewRoomData.RoomType.START:
			_create_start_room_platforms(parent)
		NewRoomData.RoomType.COMBAT:
			_create_combat_room_platforms(parent)
		NewRoomData.RoomType.ELITE:
			_create_elite_room_platforms(parent)
		NewRoomData.RoomType.BOSS:
			_create_boss_room_platforms(parent)
		NewRoomData.RoomType.REWARD:
			_create_reward_room_platforms(parent)
		NewRoomData.RoomType.SHOP:
			_create_shop_room_platforms(parent)
		NewRoomData.RoomType.EVENT:
			_create_event_room_platforms(parent)
		NewRoomData.RoomType.TREASURE:
			_create_treasure_room_platforms(parent)
		_:
			_create_combat_room_platforms(parent)

	# 房间标签
	var label = _create_label(room)
	parent.add_child(label)


## 创建背景
func _create_background(room: NewRoomData) -> ColorRect:
	var bg = ColorRect.new()
	bg.name = "Background"
	bg.size = Vector2(ROOM_WIDTH, ROOM_HEIGHT)
	bg.position = Vector2(-HALF_WIDTH, -HALF_HEIGHT)
	bg.color = _get_room_color(room.room_type)
	bg.z_index = -10
	return bg


## 创建地面
func _create_ground() -> StaticBody2D:
	var ground = StaticBody2D.new()
	ground.name = "Ground"
	ground.position = Vector2(0, GROUND_Y)
	ground.collision_layer = 1  # Wall层
	ground.z_index = 5  # Phase 17.4: 平台z_index

	# 碰撞形状
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(ROOM_WIDTH, GROUND_HEIGHT)
	collision.shape = shape
	ground.add_child(collision)

	# 视觉
	var sprite = ColorRect.new()
	sprite.name = "Sprite"
	sprite.size = Vector2(ROOM_WIDTH, GROUND_HEIGHT)
	sprite.position = Vector2(-HALF_WIDTH, -GROUND_HEIGHT / 2)
	sprite.color = Color(0.3, 0.25, 0.2)  # 棕色地面
	ground.add_child(sprite)

	return ground


## 创建边界墙
func _create_boundary(x_pos: int, height: int) -> StaticBody2D:
	var wall = StaticBody2D.new()
	wall.name = "Boundary_" + str(x_pos)
	wall.position = Vector2(x_pos, 0)
	wall.collision_layer = 1

	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(20, height)
	collision.shape = shape
	wall.add_child(collision)

	return wall


## 创建平台
func _create_platform(pos: Vector2, width: int) -> StaticBody2D:
	var platform = StaticBody2D.new()
	platform.name = "Platform"
	platform.position = pos
	platform.collision_layer = 1
	platform.z_index = 5  # Phase 17.4: 平台z_index

	# 碰撞
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(width, PLATFORM_THICKNESS)
	collision.shape = shape
	platform.add_child(collision)

	# 视觉
	var sprite = ColorRect.new()
	sprite.name = "Sprite"
	sprite.size = Vector2(width, PLATFORM_THICKNESS)
	sprite.position = Vector2(-width / 2, -PLATFORM_THICKNESS / 2)
	sprite.color = Color(0.4, 0.35, 0.3)
	platform.add_child(sprite)

	# TASK-002: 记录平台碰撞矩形（pos 为平台中心 → 换算为左上角矩形）
	_platform_rects.append(Rect2(pos - Vector2(width / 2.0, PLATFORM_THICKNESS / 2.0), Vector2(width, PLATFORM_THICKNESS)))

	return platform


## ==================== 房间类型布局 ====================

## Phase 24: 验证平台间距是否在玩家可达范围内
## 返回 true 表示平台间距合法
func _is_platform_reachable(from_y: float, to_y: float, from_x: float, to_x: float) -> bool:
	var dy = abs(from_y - to_y)
	var dx = abs(from_x - to_x)
	# 垂直高度必须在最大跳跃高度内
	if dy > MAX_JUMP_HEIGHT:
		return false
	# 水平距离必须在最大水平跨越内
	if dx > MAX_JUMP_DISTANCE:
		return false
	return true


## Phase 24: 验证平台与地面的可达性
## ground_y 是地面Y坐标，platform_pos是平台相对房间中心的偏移
func _is_platform_to_ground_reachable(platform_pos: Vector2) -> bool:
	# 玩家从地面起跳，地面Y = GROUND_Y (相对房间中心)
	return _is_platform_reachable(0.0, GROUND_Y - platform_pos.y, 0.0, platform_pos.x)


## Phase 24: 验证平台之间的可达性
func _are_platforms_reachable(p1_pos: Vector2, p2_pos: Vector2) -> bool:
	return _is_platform_reachable(p1_pos.y, p2_pos.y, p1_pos.x, p2_pos.x)


## 起始房间: 简单地面
func _create_start_room_platforms(parent: Node2D) -> void:
	# 无额外平台，玩家出生在地面
	pass


## Phase 24: 战斗房间 - 约束算法生成可达平台
func _create_combat_room_platforms(parent: Node2D) -> void:
	# 所有平台必须在地面以上MAX_JUMP_HEIGHT内，水平距离在MAX_JUMP_DISTANCE内
	var platforms: Array[Vector2] = []

	# 从地面向上生成，每层高度差 <= MAX_JUMP_HEIGHT
	var floor_y = GROUND_Y
	var attempts = 0
	while platforms.size() < 3 and attempts < 50:
		attempts += 1
		var px = randf_range(-300, 300)
		var py = floor_y - randf_range(20, float(MAX_JUMP_HEIGHT) * 0.8)
		var width = randf_range(150, 250)
		platforms.append(Vector2(px, py))
		floor_y = py  # 下一层从这个平台起跳

	# 确保所有平台可相互到达（简化：相邻平台间距约束）
	for i in range(platforms.size()):
		if i == 0:
			# 第一个平台必须能到达地面
			if not _is_platform_to_ground_reachable(platforms[i]):
				platforms[i].y = GROUND_Y - randf_range(20, float(MAX_JUMP_HEIGHT) * 0.5)
		else:
			# 与前一个平台检查可达性
			if not _are_platforms_reachable(platforms[i - 1], platforms[i]):
				# 调整到可达范围
				var prev = platforms[i - 1]
				platforms[i].y = clampf(platforms[i].y, prev.y - float(MAX_JUMP_HEIGHT), prev.y + float(MAX_JUMP_HEIGHT))
				platforms[i].x = clampf(platforms[i].x, prev.x - float(MAX_JUMP_DISTANCE), prev.x + float(MAX_JUMP_DISTANCE))

	for p in platforms:
		parent.add_child(_create_platform(p, 200))


## Phase 24: 精英房间 - 约束算法生成
func _create_elite_room_platforms(parent: Node2D) -> void:
	var platforms: Array[Vector2] = []
	var floor_y = GROUND_Y
	for i in range(4):
		var px = randf_range(-250, 250)
		var py = floor_y - randf_range(15, float(MAX_JUMP_HEIGHT) * 0.7)
		# 钳制到可达范围
		if platforms.size() > 0:
			var prev = platforms[-1]
			py = clampf(py, prev.y - float(MAX_JUMP_HEIGHT), prev.y + float(MAX_JUMP_HEIGHT))
			px = clampf(px, prev.x - float(MAX_JUMP_DISTANCE), prev.x + float(MAX_JUMP_DISTANCE))
		platforms.append(Vector2(px, py))
		floor_y = py

	for i in range(platforms.size()):
		var w = randf_range(150, 200)
		parent.add_child(_create_platform(platforms[i], w))


## Phase 24: Boss房间 - 约束算法生成
func _create_boss_room_platforms(parent: Node2D) -> void:
	# 两侧高台必须在玩家跳跃范围内
	var left_x = randf_range(-400, -200)
	var left_y = GROUND_Y - randf_range(20, float(MAX_JUMP_HEIGHT) * 0.6)
	if not _is_platform_to_ground_reachable(Vector2(left_x, left_y)):
		left_y = GROUND_Y - randf_range(10, float(MAX_JUMP_HEIGHT) * 0.4)
	parent.add_child(_create_platform(Vector2(left_x, left_y), 200))

	var right_x = randf_range(200, 400)
	var right_y = GROUND_Y - randf_range(20, float(MAX_JUMP_HEIGHT) * 0.6)
	if not _is_platform_to_ground_reachable(Vector2(right_x, right_y)):
		right_y = GROUND_Y - randf_range(10, float(MAX_JUMP_HEIGHT) * 0.4)
	parent.add_child(_create_platform(Vector2(right_x, right_y), 200))

	# 中央平台
	var center_y = GROUND_Y - randf_range(10, float(MAX_JUMP_HEIGHT) * 0.5)
	parent.add_child(_create_platform(Vector2(0, center_y), 300))


## Phase 24: 奖励房间 - 约束算法生成
func _create_reward_room_platforms(parent: Node2D) -> void:
	var center_y = GROUND_Y - randf_range(10, float(MAX_JUMP_HEIGHT) * 0.5)
	parent.add_child(_create_platform(Vector2(0, center_y), 300))

	for side in [-1, 1]:
		var px = side * randf_range(150, 250)
		var py = center_y - randf_range(10, float(MAX_JUMP_HEIGHT) * 0.5)
		# 确保可达
		if not _are_platforms_reachable(Vector2(0, center_y), Vector2(px, py)):
			py = clampf(py, center_y - float(MAX_JUMP_HEIGHT), center_y + float(MAX_JUMP_HEIGHT))
		parent.add_child(_create_platform(Vector2(px, py), 150))


## 商店房间: 平整布局
func _create_shop_room_platforms(parent: Node2D) -> void:
	var p1 = _create_platform(Vector2(-200, 20), 200)
	parent.add_child(p1)

	var p2 = _create_platform(Vector2(200, 20), 200)
	parent.add_child(p2)


## 事件房间: 中央平台
func _create_event_room_platforms(parent: Node2D) -> void:
	var p1 = _create_platform(Vector2(0, 15), 250)
	parent.add_child(p1)


## 宝箱房间: 平台
func _create_treasure_room_platforms(parent: Node2D) -> void:
	var p1 = _create_platform(Vector2(0, 20), 200)
	parent.add_child(p1)

	var p2 = _create_platform(Vector2(0, -20), 150)
	parent.add_child(p2)


## ==================== 工具函数 ====================

func _get_room_color(room_type: NewRoomData.RoomType) -> Color:
	match room_type:
		NewRoomData.RoomType.START:
			return Color(0.1, 0.15, 0.1)
		NewRoomData.RoomType.COMBAT:
			return Color(0.15, 0.08, 0.08)
		NewRoomData.RoomType.ELITE:
			return Color(0.15, 0.08, 0.15)
		NewRoomData.RoomType.BOSS:
			return Color(0.2, 0.05, 0.05)
		NewRoomData.RoomType.REWARD:
			return Color(0.15, 0.15, 0.05)
		NewRoomData.RoomType.SHOP:
			return Color(0.05, 0.1, 0.15)
		NewRoomData.RoomType.EVENT:
			return Color(0.12, 0.1, 0.08)
		NewRoomData.RoomType.TREASURE:
			return Color(0.15, 0.12, 0.05)
		_:
			return Color(0.1, 0.1, 0.1)


func _create_label(room: NewRoomData) -> Label:
	var label = Label.new()
	label.name = "RoomLabel"
	label.text = room.room_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(-50, -HALF_HEIGHT - 20)
	return label


## ==================== 清理 ====================

func clear_room() -> void:
	clear_exit_portals()
	# TASK-002: 房间销毁时清空平台矩形记录（新房间会重新生成）
	_platform_rects.clear()
	if _decoration_manager:
		_decoration_manager.clear_decorations()
	if _clear_feedback:
		_clear_feedback.clear_feedback()
	# Phase 17.2: 清除背景
	if _background_manager:
		_background_manager.clear_background()
	if _current_room_node and _current_room_node.is_inside_tree():
		_current_monster_container = null
		_current_reward_container = null
		_current_room_node.queue_free()
		_current_room_node = null


func show_room_clear_feedback() -> void:
	if _clear_feedback:
		_clear_feedback.show_clear_feedback(_current_room_position)


## ==================== 出口传送门 ====================

func create_exit_portal(target_room_id: int, room_type_string: String) -> void:
	if not _room_container:
		return
	call_deferred("_create_exit_portal_deferred", target_room_id, room_type_string)


func _create_exit_portal_deferred(target_room_id: int, room_type_string: String) -> void:
	if not _room_container:
		return

	# TASK-005: 同房间最多一个出口（状态机 + 渲染层双保险，防重复建门）
	if _has_exit_portal:
		print("[PlatformRoom] Exit portal already exists for this room, skip duplicate")
		return

	# Phase 26: 出口应该在当前房间内，使用local坐标
	var pos = Vector2(HALF_WIDTH - 40, GROUND_Y - 30)  # local坐标（相对于房间中心）

	var portal = Area2D.new()
	portal.name = "Exit_" + str(target_room_id)
	portal.position = pos
	portal.collision_layer = 0
	portal.collision_mask = 2

	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(40, 60)
	collision.shape = shape
	portal.add_child(collision)

	# 视觉
	var sprite = Sprite2D.new()
	var image = Image.create(32, 48, false, Image.FORMAT_RGBA8)
	image.fill(_get_portal_color(room_type_string))
	var texture = ImageTexture.create_from_image(image)
	sprite.texture = texture
	portal.add_child(sprite)

	# 标签
	var label = Label.new()
	label.text = "→"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(-10, -40)
	portal.add_child(label)

	portal.set_meta("target_room_id", target_room_id)
	portal.body_entered.connect(_on_portal_body_entered.bind(target_room_id))

	# Phase 26: 添加到当前房间节点（而非GameWorld）
	if _current_room_node:
		_current_room_node.add_child(portal)
	else:
		_room_container.add_child(portal)  # fallback
	_exit_portals.append(portal)
	_has_exit_portal = true

	print("[PlatformRoom] Created exit portal to room ", target_room_id, " at local pos=", pos)


func clear_exit_portals() -> void:
	for portal in _exit_portals:
		if portal and portal.is_inside_tree():
			portal.queue_free()
	_exit_portals.clear()
	_has_exit_portal = false


func _get_portal_color(room_type: String) -> Color:
	match room_type:
		"start": return Color(0.2, 0.8, 0.2, 0.8)
		"combat": return Color(0.8, 0.2, 0.2, 0.8)
		"elite": return Color(0.8, 0.2, 0.8, 0.8)
		"boss": return Color(0.9, 0.1, 0.1, 0.9)
		"treasure": return Color(0.9, 0.8, 0.2, 0.8)
		"shop": return Color(0.2, 0.6, 0.8, 0.8)
		"event": return Color(0.8, 0.6, 0.2, 0.8)
		_: return Color(0.5, 0.5, 0.5, 0.8)


func _on_portal_body_entered(body: Node2D, target_room_id: int) -> void:
	if body.name == "Player":
		call_deferred("_emit_exit_portal_signal", target_room_id)


func _emit_exit_portal_signal(target_room_id: int) -> void:
	exit_portal_entered.emit(target_room_id)


## ==================== 下一层传送门 ====================

func create_next_floor_portal() -> void:
	if not _room_container:
		return
	call_deferred("_create_next_floor_portal_deferred")


func _create_next_floor_portal_deferred() -> void:
	if not _room_container:
		return

	# Phase 26: 下一层传送门也在当前房间内，使用local坐标
	var pos = Vector2(HALF_WIDTH - 40, GROUND_Y - 30)  # local坐标

	var portal = Area2D.new()
	portal.name = "NextFloorPortal"
	portal.position = pos
	portal.collision_layer = 0
	portal.collision_mask = 2

	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(50, 70)
	collision.shape = shape
	portal.add_child(collision)

	# 金色传送门
	var sprite = Sprite2D.new()
	var image = Image.create(40, 56, false, Image.FORMAT_RGBA8)
	image.fill(Color(1.0, 0.84, 0.0, 0.9))
	var texture = ImageTexture.create_from_image(image)
	sprite.texture = texture
	portal.add_child(sprite)

	var label = Label.new()
	label.text = "下一层"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(-20, -50)
	label.add_theme_color_override("font_color", Color(1, 1, 0))
	portal.add_child(label)

	portal.body_entered.connect(_on_next_floor_portal_body_entered)

	# Phase 26: 添加到当前房间节点（而非GameWorld）
	if _current_room_node:
		_current_room_node.add_child(portal)
	else:
		_room_container.add_child(portal)  # fallback
	_exit_portals.append(portal)

	print("[PlatformRoom] Created next floor portal at local pos=", pos)


func _on_next_floor_portal_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		call_deferred("_emit_next_floor_portal_signal")


func _emit_next_floor_portal_signal() -> void:
	next_floor_portal_entered.emit()
