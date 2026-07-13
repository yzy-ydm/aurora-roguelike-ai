## 测试宝箱对象
##
## 验证GameObject → InteractiveObject完整流程
## 玩家靠近 → 显示交互提示 → 按E → 触发interaction事件 → 状态变化

class_name TestChest
extends GameObject

## 宝箱是否已打开
var _is_opened: bool = false


## 初始化
func _init() -> void:
	super._init()
	object_type = "chest"
	object_name = "测试宝箱"


## 创建InteractiveObject并关联
func create_interactive_object() -> InteractiveObject:
	var interactive = InteractiveObject.new()
	interactive.object_name = object_name
	interactive.interaction_type = InteractiveObject.InteractionType.EXAMINE
	interactive.interaction_hint = "按 E 打开宝箱"
	interactive.can_repeat = false  # 只能打开一次

	# 关联
	set_interactive_object(interactive)
	interactive.linked_entity_id = object_id

	# 连接信号
	interactive.interaction_completed.connect(_on_interaction_completed)

	return interactive


## 交互完成回调
func _on_interaction_completed(obj_id: int) -> void:
	_is_opened = true
	mark_interacted()
	print("宝箱已打开: ", object_name)


## 检查宝箱是否已打开
func is_opened() -> bool:
	return _is_opened


## 转换为字典
func to_dict() -> Dictionary:
	var data = super.to_dict()
	data["is_opened"] = _is_opened
	return data


## 从字典加载
func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
	_is_opened = data.get("is_opened", false)
