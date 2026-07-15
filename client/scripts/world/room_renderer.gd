## 房间渲染器 (Phase 10.1.5, Phase 16.1 增强)
##
## 负责当前房间的视觉生成
## - 背景/地板
## - 墙壁碰撞
## - 出口传送门
## - 房间装饰（Phase 16.1）
## - 房间清空反馈（Phase 16.1）
## - 房间清理
##
## 从FloorManager中提取的渲染职责

extends Node

## ==================== 配置 ====================

const WALL_THICKNESS: int = 10

## ==================== 引用 ====================

## 房间容器(渲染节点的父节点)
var _room_container: Node2D = null

## 当前渲染的房间节点
var _current_room_node: Node2D = null

## 当前出口传送门列表
var _exit_portals: Array[Area2D] = []

## 当前房间的世界坐标位置(用于计算出口传送门位置)
var _current_room_position: Vector2 = Vector2.ZERO

## Phase 16.1: 装饰管理器
var _decoration_manager: Node = null

## Phase 16.1: 清空反馈系统
var _clear_feedback: Node = null

## ==================== 信号 ====================

## 出口传送门被触发
signal exit_portal_entered(target_room_id: int)

## 下一层传送门被触发（Phase 10.1.6）
signal next_floor_portal_entered()


## ==================== 初始化 ====================

func _ready() -> void:
	# Phase 16.1: 初始化装饰管理器
	_decoration_manager = Node.new()
	_decoration_manager.name = "RoomDecorationManager"
	_decoration_manager.set_script(load("res://scripts/world/room_decoration_manager.gd"))
	add_child(_decoration_manager)

	# Phase 16.1: 初始化清空反馈系统
	_clear_feedback = Node.new()
	_clear_feedback.name = "RoomClearFeedback"
	_clear_feedback.set_script(load("res://scripts/world/room_clear_feedback.gd"))
	add_child(_clear_feedback)

	print("[RoomRenderer] Phase 16.1 systems initialized")


func set_room_container(container: Node2D) -> void:
	_room_container = container

	# Phase 16.1: 设置装饰和反馈容器
	if _decoration_manager:
		_decoration_manager.set_decoration_container(container)
	if _clear_feedback:
		_clear_feedback.set_feedback_container(container)


## ==================== 房间渲染 ====================

## 渲染单个房间(清除旧房间后)
func render_room(room: NewRoomData) -> void:
	# 清除旧房间
	clear_room()

	if not _room_container:
		print("[RoomRenderer] Error: No room container")
		return

	# 创建房间根节点
	var room_node = Node2D.new()
	room_node.name = "Room_" + str(room.id)
	room_node.position = room.position

	# 背景
	var bg = _create_background(room)
	room_node.add_child(bg)

	# 墙壁碰撞
	var walls = _create_walls()
	room_node.add_child(walls)

	# 房间标签
	var label = _create_label(room)
	room_node.add_child(label)

	# 添加到容器
	_room_container.add_child(room_node)
	_current_room_node = room_node
	_current_room_position = room.position  # 记录房间世界坐标，供出口传送门使用

	# Phase 16.1: 生成房间装饰
	if _decoration_manager:
		_decoration_manager.spawn_decorations(room.room_type, room.position)

	print("[RoomRenderer] Rendered room ", room.id, " (", room.get_type_string(), ")")


## 清除当前房间
func clear_room() -> void:
	# 清除出口传送门
	clear_exit_portals()

	# Phase 16.1: 清除装饰
	if _decoration_manager:
		_decoration_manager.clear_decorations()

	# Phase 16.1: 清除反馈
	if _clear_feedback:
		_clear_feedback.clear_feedback()

	# 清除房间节点
	if _current_room_node and _current_room_node.is_inside_tree():
		_current_room_node.queue_free()
		_current_room_node = null


## Phase 16.1: 显示房间清空反馈
func show_room_clear_feedback() -> void:
	if _clear_feedback:
		_clear_feedback.show_clear_feedback(_current_room_position)


## ==================== 背景 ====================

func _create_background(room: NewRoomData) -> ColorRect:
	var bg = ColorRect.new()
	bg.name = "Background"
	bg.size = Vector2(WorldCoordinate.ROOM_WIDTH, WorldCoordinate.ROOM_HEIGHT)
	bg.position = Vector2(-WorldCoordinate.HALF_WIDTH, -WorldCoordinate.HALF_HEIGHT)
	bg.color = _get_room_color(room.room_type)
	bg.z_index = -10  # 背景始终在玩家和敌人之下
	return bg


func _get_room_color(room_type: NewRoomData.RoomType) -> Color:
	match room_type:
		NewRoomData.RoomType.START:
			return Color(0.15, 0.25, 0.15, 0.9)
		NewRoomData.RoomType.COMBAT:
			return Color(0.25, 0.15, 0.15, 0.9)
		NewRoomData.RoomType.ELITE:
			return Color(0.25, 0.15, 0.25, 0.9)
		NewRoomData.RoomType.BOSS:
			return Color(0.35, 0.1, 0.1, 0.9)
		NewRoomData.RoomType.REWARD:
			return Color(0.25, 0.25, 0.1, 0.9)
		NewRoomData.RoomType.SHOP:
			return Color(0.1, 0.2, 0.3, 0.9)
		NewRoomData.RoomType.EVENT:
			return Color(0.2, 0.18, 0.12, 0.9)
		NewRoomData.RoomType.TREASURE:
			return Color(0.25, 0.2, 0.1, 0.9)
		_:
			return Color(0.2, 0.2, 0.2, 0.9)


## ==================== 墙壁 ====================

func _create_walls() -> StaticBody2D:
	var walls = StaticBody2D.new()
	walls.name = "Walls"
	walls.collision_layer = 1

	var hw = WorldCoordinate.HALF_WIDTH
	var hh = WorldCoordinate.HALF_HEIGHT

	# 上墙
	_add_wall(walls, Vector2(0, -hh), Vector2(WorldCoordinate.ROOM_WIDTH, WALL_THICKNESS))
	# 下墙
	_add_wall(walls, Vector2(0, hh), Vector2(WorldCoordinate.ROOM_WIDTH, WALL_THICKNESS))
	# 左墙
	_add_wall(walls, Vector2(-hw, 0), Vector2(WALL_THICKNESS, WorldCoordinate.ROOM_HEIGHT))
	# 右墙
	_add_wall(walls, Vector2(hw, 0), Vector2(WALL_THICKNESS, WorldCoordinate.ROOM_HEIGHT))

	return walls


func _add_wall(parent: StaticBody2D, pos: Vector2, size: Vector2) -> void:
	var wall = CollisionShape2D.new()
	wall.position = pos
	var shape = RectangleShape2D.new()
	shape.size = size
	wall.shape = shape
	parent.add_child(wall)


## ==================== 标签 ====================

func _create_label(room: NewRoomData) -> Label:
	var label = Label.new()
	label.name = "RoomLabel"
	label.text = room.room_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(-50, -WorldCoordinate.HALF_HEIGHT - 20)
	return label


## ==================== 出口传送门 ====================

## 创建出口传送门
func create_exit_portal(target_room_id: int, room_type_string: String) -> void:
	if not _room_container:
		return

	# 使用call_deferred避免在物理回调期间添加Area2D+CollisionShape2D
	# 导致"Can't change this state while flushing queries"错误
	call_deferred("_create_exit_portal_deferred", target_room_id, room_type_string)


## deferred回调：实际创建出口传送门
func _create_exit_portal_deferred(target_room_id: int, room_type_string: String) -> void:
	if not _room_container:
		return

	var pos = WorldCoordinate.exit_portal_pos(_current_room_position)  # 基于当前房间中心计算世界坐标

	var portal = Area2D.new()
	portal.name = "Exit_" + str(target_room_id)
	portal.position = pos
	# 检测Player(Layer 2)进入传送门
	portal.collision_layer = 0  # 传送门本身不需要被检测
	portal.collision_mask = 2   # 检测Player(Layer 2)

	# 碰撞形状
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(40, 40)
	collision.shape = shape
	portal.add_child(collision)

	# 视觉效果
	var sprite = Sprite2D.new()
	var image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(_get_portal_color(room_type_string))
	var texture = ImageTexture.create_from_image(image)
	sprite.texture = texture
	portal.add_child(sprite)

	# 标签
	var label = Label.new()
	label.text = "→ " + room_type_string
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(-30, -30)
	portal.add_child(label)

	# 存储目标房间ID
	portal.set_meta("target_room_id", target_room_id)

	# 连接信号
	portal.body_entered.connect(_on_portal_body_entered.bind(target_room_id))

	_room_container.add_child(portal)
	_exit_portals.append(portal)

	print("[RoomRenderer] Created exit portal to room ", target_room_id, " (", room_type_string, ")")


## 清除所有出口传送门
func clear_exit_portals() -> void:
	for portal in _exit_portals:
		if portal and portal.is_inside_tree():
			portal.queue_free()
	_exit_portals.clear()


func _get_portal_color(room_type: String) -> Color:
	match room_type:
		"start":
			return Color(0.2, 0.8, 0.2, 0.8)
		"combat":
			return Color(0.8, 0.2, 0.2, 0.8)
		"elite":
			return Color(0.8, 0.2, 0.8, 0.8)
		"boss":
			return Color(0.9, 0.1, 0.1, 0.9)
		"treasure":
			return Color(0.9, 0.8, 0.2, 0.8)
		"shop":
			return Color(0.2, 0.6, 0.8, 0.8)
		"event":
			return Color(0.8, 0.6, 0.2, 0.8)
		_:
			return Color(0.5, 0.5, 0.5, 0.8)


func _on_portal_body_entered(body: Node2D, target_room_id: int) -> void:
	if body.name == "Player":
		# 延迟发射信号，避免在物理回调中触发enter_room→clear_room→queue_free
		call_deferred("_emit_exit_portal_signal", target_room_id)


func _emit_exit_portal_signal(target_room_id: int) -> void:
	exit_portal_entered.emit(target_room_id)


## ==================== 下一层传送门（Phase 10.1.6） ====================

## 创建下一层传送门
func create_next_floor_portal() -> void:
	if not _room_container:
		return

	# 使用call_deferred避免物理回调问题
	call_deferred("_create_next_floor_portal_deferred")


## deferred回调：实际创建下一层传送门
func _create_next_floor_portal_deferred() -> void:
	if not _room_container:
		return

	var pos = WorldCoordinate.exit_portal_pos(_current_room_position)

	var portal = Area2D.new()
	portal.name = "NextFloorPortal"
	portal.position = pos
	portal.collision_layer = 0
	portal.collision_mask = 2  # 检测Player(Layer 2)

	# 碰撞形状
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(50, 50)  # 比普通传送门大一点
	collision.shape = shape
	portal.add_child(collision)

	# 视觉效果 - 金色传送门
	var sprite = Sprite2D.new()
	var image = Image.create(48, 48, false, Image.FORMAT_RGBA8)
	image.fill(Color(1.0, 0.84, 0.0, 0.9))  # 金色
	var texture = ImageTexture.create_from_image(image)
	sprite.texture = texture
	portal.add_child(sprite)

	# 标签
	var label = Label.new()
	label.text = "⬇ 下一层"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(-40, -40)
	label.add_theme_color_override("font_color", Color(1, 1, 0))
	portal.add_child(label)

	# 连接信号
	portal.body_entered.connect(_on_next_floor_portal_body_entered)

	_room_container.add_child(portal)
	_exit_portals.append(portal)

	print("[RoomRenderer] Created next floor portal")


## 下一层传送门碰撞检测
func _on_next_floor_portal_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		# 延迟发射信号
		call_deferred("_emit_next_floor_portal_signal")


## 发射下一层传送门信号
func _emit_next_floor_portal_signal() -> void:
	next_floor_portal_entered.emit()
