## 实体管理器
##
## 负责统一管理实体
## 实现实体注册、查询、删除、生命周期管理

extends Node

## 实体字典（entity_id -> Entity）
var _entities: Dictionary = {}

## 实体类型索引（entity_type -> Array[entity_id]）
var _type_index: Dictionary = {}

## 信号
signal entity_registered(entity: Entity)
signal entity_unregistered(entity_id: int)
signal entity_activated(entity_id: int)
signal entity_destroyed(entity_id: int)


func _ready() -> void:
	pass


## 注册实体
func register_entity(entity: Entity) -> void:
	if entity.entity_id in _entities:
		push_warning("实体已存在: " + str(entity.entity_id))
		return

	_entities[entity.entity_id] = entity

	# 更新类型索引
	if entity.entity_type != "":
		if not _type_index.has(entity.entity_type):
			_type_index[entity.entity_type] = []
		_type_index[entity.entity_type].append(entity.entity_id)

	entity_registered.emit(entity)


## 注销实体
func unregister_entity(entity_id: int) -> void:
	if not _entities.has(entity_id):
		push_warning("实体不存在: " + str(entity_id))
		return

	var entity = _entities[entity_id]

	# 从类型索引中移除
	if entity.entity_type != "" and _type_index.has(entity.entity_type):
		_type_index[entity.entity_type].erase(entity_id)

	_entities.erase(entity_id)
	entity_unregistered.emit(entity_id)


## 激活实体
func activate_entity(entity_id: int) -> void:
	var entity = get_entity(entity_id)
	if entity:
		entity.activate()
		entity_activated.emit(entity_id)


## 销毁实体
func destroy_entity(entity_id: int) -> void:
	var entity = get_entity(entity_id)
	if entity:
		entity.destroy()
		entity_destroyed.emit(entity_id)
		unregister_entity(entity_id)


## 获取实体
func get_entity(entity_id: int) -> Entity:
	return _entities.get(entity_id)


## 根据ID获取实体（别名）
func get_entity_by_id(entity_id: int) -> Entity:
	return get_entity(entity_id)


## 获取所有实体
func get_all_entities() -> Array[Entity]:
	var result: Array[Entity] = []
	for entity in _entities.values():
		result.append(entity)
	return result


## 获取所有活跃实体
func get_active_entities() -> Array[Entity]:
	var result: Array[Entity] = []
	for entity in _entities.values():
		if entity.is_active():
			result.append(entity)
	return result


## 根据类型获取实体
func get_entities_by_type(entity_type: String) -> Array[Entity]:
	var result: Array[Entity] = []
	if _type_index.has(entity_type):
		for entity_id in _type_index[entity_type]:
			var entity = _entities.get(entity_id)
			if entity:
				result.append(entity)
	return result


## 获取实体数量
func get_entity_count() -> int:
	return _entities.size()


## 获取活跃实体数量
func get_active_entity_count() -> int:
	var count = 0
	for entity in _entities.values():
		if entity.is_active():
			count += 1
	return count


## 根据类型获取实体数量
func get_entity_count_by_type(entity_type: String) -> int:
	if _type_index.has(entity_type):
		return _type_index[entity_type].size()
	return 0


## 检查实体是否存在
func has_entity(entity_id: int) -> bool:
	return _entities.has(entity_id)


## 清除所有实体
func clear_all() -> void:
	_entities.clear()
	_type_index.clear()


## 清除指定类型的实体
func clear_by_type(entity_type: String) -> void:
	if _type_index.has(entity_type):
		for entity_id in _type_index[entity_type]:
			_entities.erase(entity_id)
		_type_index.erase(entity_type)


## 更新所有活跃实体
func update_entities(delta: float) -> void:
	for entity in _entities.values():
		if entity.is_active():
			# 子类可以覆盖此方法来处理实体更新
			pass
