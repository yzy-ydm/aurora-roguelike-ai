## 交互管理器
##
## 负责管理所有可交互对象
## 实现交互对象注册、查询、事件分发

extends Node

## 交互对象字典（object_id -> InteractiveObject）
var _objects: Dictionary = {}

## 当前在范围内的对象列表
var _objects_in_range: Array[int] = []

## 当前最近的交互对象
var _nearest_object: InteractiveObject = null

## 信号
signal object_registered(object_id: int)
signal object_unregistered(object_id: int)
signal object_in_range(object_id: int)
signal object_out_of_range(object_id: int)
signal interaction_triggered(object_id: int)
signal nearest_object_changed(object: InteractiveObject)


func _ready() -> void:
	pass


## 每帧更新
func _process(delta: float) -> void:
	# 更新所有对象的冷却时间
	for obj in _objects.values():
		obj.update_cooldown(delta)


## 注册交互对象
func register_object(obj: InteractiveObject) -> void:
	if obj.object_id in _objects:
		push_warning("交互对象已存在: " + str(obj.object_id))
		return

	_objects[obj.object_id] = obj
	object_registered.emit(obj.object_id)


## 注销交互对象
func unregister_object(object_id: int) -> void:
	if not _objects.has(object_id):
		push_warning("交互对象不存在: " + str(object_id))
		return

	_objects.erase(object_id)
	_objects_in_range.erase(object_id)

	# 如果是最近对象，清除
	if _nearest_object and _nearest_object.object_id == object_id:
		_nearest_object = null
		nearest_object_changed.emit(null)

	object_unregistered.emit(object_id)


## 获取交互对象
func get_object(object_id: int) -> InteractiveObject:
	return _objects.get(object_id)


## 获取所有交互对象
func get_all_objects() -> Array[InteractiveObject]:
	var result: Array[InteractiveObject] = []
	for obj in _objects.values():
		result.append(obj)
	return result


## 获取对象数量
func get_object_count() -> int:
	return _objects.size()


## 对象进入范围
func object_enter_range(object_id: int) -> void:
	if not _objects.has(object_id):
		return

	if object_id not in _objects_in_range:
		_objects_in_range.append(object_id)

	var obj = _objects[object_id]
	obj.enter_range()
	object_in_range.emit(object_id)

	# 更新最近对象
	_update_nearest_object()


## 对象离开范围
func object_exit_range(object_id: int) -> void:
	if not _objects.has(object_id):
		return

	_objects_in_range.erase(object_id)

	var obj = _objects[object_id]
	obj.exit_range()
	object_out_of_range.emit(object_id)

	# 更新最近对象
	_update_nearest_object()


## 触发交互
func trigger_interaction(object_id: int = -1) -> bool:
	# 如果没有指定ID，使用最近的对象
	if object_id < 0:
		if _nearest_object:
			object_id = _nearest_object.object_id
		else:
			return false

	var obj = get_object(object_id)
	if not obj:
		return false

	if obj.start_interaction():
		interaction_triggered.emit(object_id)
		return true

	return false


## 完成交互
func complete_interaction(object_id: int) -> void:
	var obj = get_object(object_id)
	if obj:
		obj.complete_interaction()


## 获取最近的交互对象
func get_nearest_object() -> InteractiveObject:
	return _nearest_object


## 获取在范围内的对象列表
func get_objects_in_range() -> Array[InteractiveObject]:
	var result: Array[InteractiveObject] = []
	for object_id in _objects_in_range:
		var obj = get_object(object_id)
		if obj:
			result.append(obj)
	return result


## 检查是否有可交互对象
func has_interactable() -> bool:
	return _nearest_object != null and _nearest_object.can_interact()


## 更新最近对象
func _update_nearest_object() -> void:
	var old_nearest = _nearest_object
	_nearest_object = null

	if _objects_in_range.size() > 0:
		# 找到最近的对象（简单实现：取第一个）
		# 未来可以根据距离排序
		for object_id in _objects_in_range:
			var obj = get_object(object_id)
			if obj and obj.can_interact():
				_nearest_object = obj
				break

	if old_nearest != _nearest_object:
		nearest_object_changed.emit(_nearest_object)


## 清除所有对象
func clear_all() -> void:
	_objects.clear()
	_objects_in_range.clear()
	_nearest_object = null
