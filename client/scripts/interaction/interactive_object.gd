## 交互对象基础类
##
## 负责交互对象身份、交互类型、当前交互状态
## 所有可交互游戏对象的基类

class_name InteractiveObject
extends RefCounted

## 交互类型枚举
enum InteractionType {
	NONE,           # 无交互
	PICKUP,         # 拾取
	USE,            # 使用
	TALK,           # 对话
	EXAMINE,        # 检查
	ENTER,          # 进入
	CUSTOM          # 自定义
}

## 交互状态枚举
enum InteractionState {
	IDLE,           # 空闲
	IN_RANGE,       # 在范围内
	INTERACTING,    # 交互中
	COOLDOWN,       # 冷却中
	DISABLED        # 已禁用
}

## 对象唯一ID
var object_id: int = 0

## 对象名称
var object_name: String = ""

## 交互类型
var interaction_type: InteractionType = InteractionType.NONE

## 交互状态
var interaction_state: InteractionState = InteractionState.IDLE

## 交互提示文本
var interaction_hint: String = "按 E 交互"

## 是否可重复交互
var can_repeat: bool = true

## 交互冷却时间（秒）
var cooldown_time: float = 0.5

## 当前冷却剩余时间
var _cooldown_timer: float = 0.0

## 关联的Entity ID（可选）
var linked_entity_id: int = -1

## 关联的Node引用
var _linked_node: Node2D = null

## 自定义数据
var custom_data: Dictionary = {}

## 信号
signal interaction_started(object_id: int)
signal interaction_completed(object_id: int)
signal interaction_failed(object_id: int, reason: String)
signal state_changed(object_id: int, new_state: InteractionState)

## ID计数器（静态）
static var _id_counter: int = 0


## 初始化
func _init() -> void:
	object_id = _generate_id()


## 生成唯一ID
static func _generate_id() -> int:
	_id_counter += 1
	return _id_counter


## 设置关联Node
func set_linked_node(node: Node2D) -> void:
	_linked_node = node


## 获取关联Node
func get_linked_node() -> Node2D:
	return _linked_node


## 获取对象位置
func get_position() -> Vector2:
	if _linked_node:
		return _linked_node.position
	return Vector2.ZERO


## 设置交互状态
func set_state(new_state: InteractionState) -> void:
	if interaction_state != new_state:
		interaction_state = new_state
		state_changed.emit(object_id, new_state)


## 获取交互状态
func get_state() -> InteractionState:
	return interaction_state


## 检查是否可以交互
func can_interact() -> bool:
	return interaction_state == InteractionState.IN_RANGE and \
		   interaction_type != InteractionType.NONE and \
		   _cooldown_timer <= 0.0


## 进入交互范围
func enter_range() -> void:
	if interaction_state == InteractionState.IDLE or \
	   interaction_state == InteractionState.COOLDOWN:
		set_state(InteractionState.IN_RANGE)


## 离开交互范围
func exit_range() -> void:
	if interaction_state == InteractionState.IN_RANGE:
		set_state(InteractionState.IDLE)


## 开始交互
func start_interaction() -> bool:
	if not can_interact():
		interaction_failed.emit(object_id, "无法交互")
		return false

	set_state(InteractionState.INTERACTING)
	interaction_started.emit(object_id)
	return true


## 完成交互
func complete_interaction() -> void:
	set_state(InteractionState.IDLE)

	if not can_repeat:
		set_state(InteractionState.DISABLED)
	else:
		_cooldown_timer = cooldown_time

	interaction_completed.emit(object_id)


## 取消交互
func cancel_interaction() -> void:
	set_state(InteractionState.IDLE)


## 禁用交互
func disable() -> void:
	set_state(InteractionState.DISABLED)


## 启用交互
func enable() -> void:
	set_state(InteractionState.IDLE)


## 更新冷却时间
func update_cooldown(delta: float) -> void:
	if _cooldown_timer > 0:
		_cooldown_timer -= delta
		if _cooldown_timer <= 0:
			_cooldown_timer = 0
			if interaction_state == InteractionState.IDLE:
				pass  # 保持IDLE状态


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
		"interaction_type": interaction_type,
		"interaction_state": interaction_state,
		"interaction_hint": interaction_hint,
		"can_repeat": can_repeat,
		"cooldown_time": cooldown_time,
		"linked_entity_id": linked_entity_id,
		"custom_data": custom_data
	}


## 从字典加载
func from_dict(data: Dictionary) -> void:
	object_id = data.get("object_id", object_id)
	object_name = data.get("object_name", object_name)
	interaction_type = data.get("interaction_type", interaction_type)
	interaction_state = data.get("interaction_state", interaction_state)
	interaction_hint = data.get("interaction_hint", interaction_hint)
	can_repeat = data.get("can_repeat", can_repeat)
	cooldown_time = data.get("cooldown_time", cooldown_time)
	linked_entity_id = data.get("linked_entity_id", linked_entity_id)
	custom_data = data.get("custom_data", {})
