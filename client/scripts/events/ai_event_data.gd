## AI事件数据模型 (Phase 11)
##
## 保存AI生成的事件信息

class_name AIEventData
extends RefCounted

## 事件标题
var title: String = ""

## 事件描述
var description: String = ""

## 事件选项
var choices: Array[Dictionary] = []

## 事件状态
enum EventState {
	NONE,       # 无事件
	CHOOSING,   # 等待选择
	COMPLETED   # 已完成
}

var state: EventState = EventState.NONE


## 从Dictionary创建
static func from_dict(data: Dictionary) -> AIEventData:
	var event = AIEventData.new()
	event.title = data.get("title", "")
	event.description = data.get("description", "")
	# TASK-022: JSON 解析出的未类型化 Array 不能直接赋给 Array[Dictionary] 成员
	# （Godot 4 运行时拒绝: Invalid assignment of property or key 'choices'）
	# 逐项验证类型后追加，保持类型安全
	var raw_choices = data.get("choices", [])
	if raw_choices is Array:
		for item in raw_choices:
			if item is Dictionary:
				event.choices.append(item)
	if event.title != "":
		event.state = EventState.CHOOSING
	return event


## 转换为Dictionary
func to_dict() -> Dictionary:
	return {
		"title": title,
		"description": description,
		"choices": choices,
		"state": state
	}


## 是否有效
func is_valid() -> bool:
	return title != "" and description != "" and choices.size() > 0


## 获取选项文本
func get_choice_text(index: int) -> String:
	if index >= 0 and index < choices.size():
		return choices[index].get("text", "")
	return ""


## 获取选项奖励
func get_choice_reward(index: int) -> Dictionary:
	if index >= 0 and index < choices.size():
		return choices[index].get("reward", {})
	return {}


## 获取选项风险
func get_choice_risk(index: int) -> Dictionary:
	if index >= 0 and index < choices.size():
		return choices[index].get("risk", {})
	return {}


## 标记为已完成
func complete() -> void:
	state = EventState.COMPLETED
