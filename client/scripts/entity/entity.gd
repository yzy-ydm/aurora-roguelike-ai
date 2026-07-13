## 实体基础类
##
## 负责基础实体定义
## 包含唯一ID、实体名称、实体位置、生命周期状态
## 所有游戏实体的基类

class_name Entity
extends RefCounted

## 实体生命周期状态
enum EntityState {
	CREATED,    # 已创建
	ACTIVE,     # 活跃中
	PAUSED,     # 暂停
	DESTROYED   # 已销毁
}

## 实体唯一ID（自动生成）
var entity_id: int = 0

## 实体名称
var entity_name: String = ""

## 实体类型
var entity_type: String = ""

## 实体位置
var position: Vector2 = Vector2.ZERO

## 实体生命周期状态
var state: EntityState = EntityState.CREATED

## 实体创建时间
var created_at: float = 0.0

## 实体自定义数据
var custom_data: Dictionary = {}

## ID计数器（静态）
static var _id_counter: int = 0


## 初始化实体
func _init() -> void:
	entity_id = _generate_id()
	created_at = Time.get_unix_time_from_system()


## 生成唯一ID
static func _generate_id() -> int:
	_id_counter += 1
	return _id_counter


## 激活实体
func activate() -> void:
	if state == EntityState.CREATED or state == EntityState.PAUSED:
		state = EntityState.ACTIVE


## 暂停实体
func pause() -> void:
	if state == EntityState.ACTIVE:
		state = EntityState.PAUSED


## 销毁实体
func destroy() -> void:
	state = EntityState.DESTROYED


## 检查实体是否活跃
func is_active() -> bool:
	return state == EntityState.ACTIVE


## 检查实体是否已销毁
func is_destroyed() -> bool:
	return state == EntityState.DESTROYED


## 设置位置
func set_position(new_position: Vector2) -> void:
	position = new_position


## 获取位置
func get_position() -> Vector2:
	return position


## 更新位置
func move_to(new_position: Vector2) -> void:
	position = new_position


## 移动偏移量
func move_by(offset: Vector2) -> void:
	position += offset


## 设置自定义数据
func set_data(key: String, value: Variant) -> void:
	custom_data[key] = value


## 获取自定义数据
func get_data(key: String, default_value: Variant = null) -> Variant:
	return custom_data.get(key, default_value)


## 检查自定义数据是否存在
func has_data(key: String) -> bool:
	return custom_data.has(key)


## 转换为字典
func to_dict() -> Dictionary:
	return {
		"entity_id": entity_id,
		"entity_name": entity_name,
		"entity_type": entity_type,
		"position": {"x": position.x, "y": position.y},
		"state": state,
		"created_at": created_at,
		"custom_data": custom_data
	}


## 从字典加载
func from_dict(data: Dictionary) -> void:
	entity_id = data.get("entity_id", entity_id)
	entity_name = data.get("entity_name", entity_name)
	entity_type = data.get("entity_type", entity_type)
	var pos = data.get("position", {})
	position = Vector2(pos.get("x", 0), pos.get("y", 0))
	state = data.get("state", state)
	created_at = data.get("created_at", created_at)
	custom_data = data.get("custom_data", {})
