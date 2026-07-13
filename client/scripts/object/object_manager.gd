## 对象管理器
##
## 统一管理GameObject
## 实现对象注册、查询、删除、生命周期更新

extends Node

## 对象字典（object_id -> GameObject）
var _objects: Dictionary = {}

## 对象类型索引（object_type -> Array[object_id]）
var _type_index: Dictionary = {}

## 信号
signal object_registered(object_id: int)
signal object_unregistered(object_id: int)
signal object_activated(object_id: int)
signal object_state_changed(object_id: int, new_state: int)


func _ready() -> void:
	pass


## 注册对象
func register_object(obj: GameObject) -> void:
	if obj.object_id in _objects:
		push_warning("对象已存在: " + str(obj.object_id))
		return

	_objects[obj.object_id] = obj

	# 更新类型索引
	if obj.object_type != "":
		if not _type_index.has(obj.object_type):
			_type_index[obj.object_type] = []
		_type_index[obj.object_type].append(obj.object_id)

	# 连接对象信号
	obj.state_changed.connect(_on_object_state_changed)

	object_registered.emit(obj.object_id)


## 注销对象
func unregister_object(object_id: int) -> void:
	if not _objects.has(object_id):
		push_warning("对象不存在: " + str(object_id))
		return

	var obj = _objects[object_id]

	# 从类型索引中移除
	if obj.object_type != "" and _type_index.has(obj.object_type):
		_type_index[obj.object_type].erase(object_id)

	# 断开信号
	obj.state_changed.disconnect(_on_object_state_changed)

	_objects.erase(object_id)
	object_unregistered.emit(object_id)


## 获取对象
func get_object(object_id: int) -> GameObject:
	return _objects.get(object_id)


## 根据ID获取对象（别名）
func get_object_by_id(object_id: int) -> GameObject:
	return get_object(object_id)


## 获取所有对象
func get_all_objects() -> Array[GameObject]:
	var result: Array[GameObject] = []
	for obj in _objects.values():
		result.append(obj)
	return result


## 获取所有活跃对象
func get_active_objects() -> Array[GameObject]:
	var result: Array[GameObject] = []
	for obj in _objects.values():
		if obj.is_active():
			result.append(obj)
	return result


## 根据类型获取对象
func get_objects_by_type(object_type: String) -> Array[GameObject]:
	var result: Array[GameObject] = []
	if _type_index.has(object_type):
		for object_id in _type_index[object_type]:
			var obj = _objects.get(object_id)
			if obj:
				result.append(obj)
	return result


## 获取对象数量
func get_object_count() -> int:
	return _objects.size()


## 获取活跃对象数量
func get_active_object_count() -> int:
	var count = 0
	for obj in _objects.values():
		if obj.is_active():
			count += 1
	return count


## 根据类型获取对象数量
func get_object_count_by_type(object_type: String) -> int:
	if _type_index.has(object_type):
		return _type_index[object_type].size()
	return 0


## 检查对象是否存在
func has_object(object_id: int) -> bool:
	return _objects.has(object_id)


## 激活对象
func activate_object(object_id: int) -> void:
	var obj = get_object(object_id)
	if obj:
		obj.activate()
		object_activated.emit(object_id)


## 清除所有对象
func clear_all() -> void:
	for obj in _objects.values():
		obj.state_changed.disconnect(_on_object_state_changed)
	_objects.clear()
	_type_index.clear()


## 清除指定类型的对象
func clear_by_type(object_type: String) -> void:
	if _type_index.has(object_type):
		for object_id in _type_index[object_type]:
			var obj = _objects.get(object_id)
			if obj:
				obj.state_changed.disconnect(_on_object_state_changed)
			_objects.erase(object_id)
		_type_index.erase(object_type)


## 对象状态变化回调
func _on_object_state_changed(object_id: int, new_state: int) -> void:
	object_state_changed.emit(object_id, new_state)
