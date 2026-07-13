## 游戏对象基础类
##
## 提供所有游戏对象基础能力
## 包含object_id、position、object_state、生命周期管理

class_name GameObject
extends RefCounted

## 对象状态枚举
enum ObjectState {
	CREATED,      # 已创建
	ACTIVE,       # 活跃中
	INTERACTED,   # 已交互
	DISABLED      # 已禁用
}

## 对象唯一ID
var object_id: int = 0

## 对象名称
var object_name: String = ""

## 对象类型
var object_type: String = ""

## 对象位置
var position: Vector2 = Vector2.ZERO

## 对象状态
var state: ObjectState = ObjectState.CREATED

## 对象创建时间
var created_at: float = 0.0

## 关联的InteractiveObject（可选）
var _interactive_object: InteractiveObject = null

## 关联的Node2D（可选）
var _linked_node: Node2D = null

## 自定义数据
var custom_data: Dictionary = {}

## 信号
signal state_changed(object_id: int, new_state: ObjectState)
signal interaction_completed(object_id: int)

## ID计数器（静态）
static var _id_counter: int = 0


## 初始化
func _init() -> void:
	object_id = _generate_id()
	created_at = Time.get_unix_time_from_system()


## 生成唯一ID
static func _generate_id() -> int:
	_id_counter += 1
	return _id_counter


## 激活对象
func activate() -> void:
	if state == ObjectState.CREATED or state == ObjectState.DISABLED:
		state = ObjectState.ACTIVE
		state_changed.emit(object_id, state)


## 禁用对象
func disable() -> void:
	state = ObjectState.DISABLED
	state_changed.emit(object_id, state)


## 标记为已交互
func mark_interacted() -> void:
	if state == ObjectState.ACTIVE:
		state = ObjectState.INTERACTED
		state_changed.emit(object_id, state)
		interaction_completed.emit(object_id)


## 重置状态
func reset() -> void:
	state = ObjectState.CREATED
	state_changed.emit(object_id, state)


## 检查是否活跃
func is_active() -> bool:
	return state == ObjectState.ACTIVE


## 检查是否已交互
func is_interacted() -> bool:
	return state == ObjectState.INTERACTED


## 检查是否已禁用
func is_disabled() -> bool:
	return state == ObjectState.DISABLED


## 设置位置
func set_position(new_position: Vector2) -> void:
	position = new_position
	if _linked_node:
		_linked_node.position = position


## 获取位置
func get_position() -> Vector2:
	return position


## 设置关联Node
func set_linked_node(node: Node2D) -> void:
	_linked_node = node
	if _linked_node:
		position = _linked_node.position


## 获取关联Node
func get_linked_node() -> Node2D:
	return _linked_node


## 设置InteractiveObject
func set_interactive_object(obj: InteractiveObject) -> void:
	_interactive_object = obj


## 获取InteractiveObject
func get_interactive_object() -> InteractiveObject:
	return _interactive_object


## 检查是否有InteractiveObject
func has_interactive_object() -> bool:
	return _interactive_object != null


## 设置自定义数据
func set_data(key: String, value: Variant) -> void:
	custom_data[key] = value


## 获取自定义数据
func get_data(key: String, default_value: Variant = null) -> Variant:
	return custom_data.get(key, default_value)


## 转换为字典
func to_dict() -> Dictionary:
	return {
		"object_id": object_id,
		"object_name": object_name,
		"object_type": object_type,
		"position": {"x": position.x, "y": position.y},
		"state": state,
		"created_at": created_at,
		"custom_data": custom_data
	}


## 从字典加载
func from_dict(data: Dictionary) -> void:
	object_id = data.get("object_id", object_id)
	object_name = data.get("object_name", object_name)
	object_type = data.get("object_type", object_type)
	var pos = data.get("position", {})
	position = Vector2(pos.get("x", 0), pos.get("y", 0))
	state = data.get("state", state)
	created_at = data.get("created_at", created_at)
	custom_data = data.get("custom_data", {})
