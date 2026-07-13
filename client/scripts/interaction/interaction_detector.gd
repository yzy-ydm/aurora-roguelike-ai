## 交互检测器
##
## 负责检测玩家附近InteractiveObject
## 使用Area2D实现交互范围检测

extends Area2D

## 检测范围
@export var detection_radius: float = 64.0

## 关联的InteractionManager
var _interaction_manager: Node = null

## 当前在范围内的对象ID列表
var _detected_objects: Dictionary = {}


func _ready() -> void:
	# 连接信号
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)

	# 创建碰撞形状
	_setup_collision_shape()


## 设置交互管理器
func set_interaction_manager(manager: Node) -> void:
	_interaction_manager = manager


## 设置检测范围
func set_detection_radius(radius: float) -> void:
	detection_radius = radius
	_setup_collision_shape()


## 设置碰撞形状
func _setup_collision_shape() -> void:
	# 清除现有碰撞形状
	for child in get_children():
		if child is CollisionShape2D:
			child.queue_free()

	# 创建新的碰撞形状
	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = detection_radius
	shape.shape = circle
	add_child(shape)


## Body进入检测范围
func _on_body_entered(body: Node2D) -> void:
	# 检查是否是交互对象
	var object_id = _get_object_id_from_node(body)
	if object_id >= 0:
		_detected_objects[object_id] = body
		if _interaction_manager:
			_interaction_manager.object_enter_range(object_id)


## Body离开检测范围
func _on_body_exited(body: Node2D) -> void:
	var object_id = _get_object_id_from_node(body)
	if object_id >= 0:
		_detected_objects.erase(object_id)
		if _interaction_manager:
			_interaction_manager.object_exit_range(object_id)


## Area进入检测范围
func _on_area_entered(area: Area2D) -> void:
	var object_id = _get_object_id_from_node(area)
	if object_id >= 0:
		_detected_objects[object_id] = area
		if _interaction_manager:
			_interaction_manager.object_enter_range(object_id)


## Area离开检测范围
func _on_area_exited(area: Area2D) -> void:
	var object_id = _get_object_id_from_node(area)
	if object_id >= 0:
		_detected_objects.erase(object_id)
		if _interaction_manager:
			_interaction_manager.object_exit_range(object_id)


## 从Node获取交互对象ID
func _get_object_id_from_node(node: Node) -> int:
	# 检查Node是否有interactive_object_id属性
	if node.has_method("get_interactive_object_id"):
		return node.get_interactive_object_id()

	# 检查Node是否有meta数据
	if node.has_meta("interactive_object_id"):
		return node.get_meta("interactive_object_id")

	return -1


## 获取检测到的对象数量
func get_detected_count() -> int:
	return _detected_objects.size()


## 检查是否有对象在范围内
func has_detected_objects() -> bool:
	return _detected_objects.size() > 0
