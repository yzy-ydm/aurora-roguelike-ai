## 武器对象类
##
## 代表游戏世界中的武器对象
## 继承GameObject，接入InteractiveObject
## 负责武器拾取流程

class_name WeaponObject
extends GameObject

## 武器数据（来自ResourceService）
var _weapon_data: WeaponData = null

## 是否已被拾取
var _is_picked_up: bool = false


## 初始化
func _init() -> void:
	super._init()
	object_type = "weapon"


## 设置武器数据
func set_weapon_data(data: WeaponData) -> void:
	_weapon_data = data
	if data:
		object_name = data.name
		set_data("weapon_id", data.id)
		set_data("weapon_name", data.name)
		set_data("weapon_type", data.type)
		set_data("weapon_rarity", data.rarity)
		set_data("weapon_damage", data.damage)


## 获取武器数据
func get_weapon_data() -> WeaponData:
	return _weapon_data


## 获取武器ID
func get_weapon_id() -> int:
	if _weapon_data:
		return _weapon_data.id
	return -1


## 创建InteractiveObject并关联
func create_interactive_object() -> InteractiveObject:
	var interactive = InteractiveObject.new()
	interactive.object_name = object_name
	interactive.interaction_type = InteractiveObject.InteractionType.PICKUP
	interactive.interaction_hint = "按 E 拾取 " + object_name
	interactive.can_repeat = false  # 只能拾取一次

	# 关联
	set_interactive_object(interactive)
	interactive.linked_entity_id = object_id

	# 连接信号
	interactive.interaction_completed.connect(_on_interaction_completed)

	return interactive


## 交互完成回调
func _on_interaction_completed(obj_id: int) -> void:
	_is_picked_up = true
	mark_interacted()
	print("武器已拾取: ", object_name)


## 检查是否已拾取
func is_picked_up() -> bool:
	return _is_picked_up


## 转换为字典
func to_dict() -> Dictionary:
	var data = super.to_dict()
	data["weapon_id"] = get_weapon_id()
	data["is_picked_up"] = _is_picked_up
	if _weapon_data:
		data["weapon_data"] = _weapon_data.to_dict()
	return data


## 从字典加载
func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
	_is_picked_up = data.get("is_picked_up", false)
	if data.has("weapon_data"):
		_weapon_data = WeaponData.from_dict(data["weapon_data"])
